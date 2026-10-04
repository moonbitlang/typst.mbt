// Port of `typst-layout/src/math/mod.rs`.
//
// The math layout modules live in `math_*.mbt`; functions whose upstream
// names clash with other layouters of this package carry a `math` infix
// (e.g. `layout_math_table` for upstream `math::table::layout_table`).

///|
/// Layout an inline equation (in a paragraph).
pub fn layout_equation_inline(
  elem : @library.EquationElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
) -> Array[@library.InlineItem] raise @library.SourceError {
  guard !elem.block(styles) else {
    abort("assertion failed: !elem.block.get(styles)")
  }
  let span = elem.pack().span()
  let font = get_font(engine.world, styles, span)
  warn_non_math_font(font.font(), engine, span)
  let scale_style = style_for_script_scale(font)
  let styles = styles.chain_one(scale_style)
  let item = @library.resolve_equation(elem, engine, locator, styles)
  let ctx = MathContext::new(engine, region, font)
  let items = if !item.is_multiline() {
    math_run_into_par_items(ctx.layout_into_fragments(item, styles))
  } else {
    [Frame(ctx.layout_into_fragment(item, styles).into_frame())]
  }

  // An empty equation should have a height, so we still create a frame
  // (which is then resized in the loop).
  if items.is_empty() {
    items.push(Frame(@library.Frame::soft(@library.Axes::zero_size())))
  }
  for item in items {
    guard item is Frame(frame) else { continue }
    let slack = @library.ParElem::leading_in(styles).resolve(styles).times(0.7)
    let { top: t, bottom: b, } = font.edges(
      @library.TextElem::top_edge_in(styles),
      @library.TextElem::bottom_edge_in(styles),
      @library.TextElem::size_in(styles).resolve(styles),
      Frame(frame),
    )
    let ascent = t.max(frame.ascent() - slack)
    let descent = b.max(frame.descent() - slack)
    frame.translate(@library.Point::with_y(ascent - frame.baseline()))
    frame.set_size({ ..frame.size(), y: ascent + descent, })
  }
  items
}

///|
/// Layout a block-level equation (in a flow).
pub fn layout_equation_block(
  elem : @library.EquationElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  guard elem.block(styles) else {
    abort("assertion failed: elem.block.get(styles)")
  }
  let span = elem.pack().span()
  let font = get_font(engine.world, styles, span)
  warn_non_math_font(font.font(), engine, span)
  let scale_style = style_for_script_scale(font)
  let styles = styles.chain_one(scale_style)
  let item = @library.resolve_equation(elem, engine, locator.relayout(), styles)
  let ctx = MathContext::new(engine, regions.base(), font)
  let full_equation_builder = match item {
    Comp({ kind: Multiline(multi), styles, .. }) =>
      layout_multiline(multi, ctx, styles)
    _ =>
      MathRunFrameBuilder::from_frame(
        math_run_into_frame(ctx.layout_into_fragments(item, styles)),
      )
  }
  let width = full_equation_builder.size.x
  let equation_builders = if @library.BlockElem::breakable_in(styles) {
    let rows = full_equation_builder.frames
    let mut next_row = 0
    let equation_builders : Array[MathRunFrameBuilder] = []
    let mut last_first_pos = @library.Point::zero()
    let mut regions = regions

    // Keep track of the position of the first row in this region,
    // so that the offset can be reverted later.
    while rows.get(next_row) is Some((_, first_pos)) {
      last_first_pos = first_pos
      let frames = []
      let mut height = @library.Abs::zero()
      while rows.get(next_row) is Some((sub, pos)) {
        let pos = { ..pos, y: pos.y - first_pos.y, }

        // Finish this region if the line doesn't fit. Only do it if
        // we placed at least one line _or_ we still have non-last
        // regions. Crucially, we don't want to infinitely create
        // new regions which are too small.
        if !regions.size.y.fits(sub.height() + pos.y) &&
          (
            regions.may_progress() ||
            (regions.may_break() && !frames.is_empty())
          ) {
          break
        }
        next_row += 1
        height = height.max(pos.y + sub.height())
        frames.push((sub, pos))
      }
      equation_builders.push({
        frames,
        size: @library.Axes::new(width, height),
      })
      regions = regions.next()
    }

    // Append remaining rows to the equation builder of the last region.
    if equation_builders.last() is Some(equation_builder) {
      for row in rows[next_row:] {
        let (frame, pos) = row
        equation_builder.frames.push(
          (frame, { ..pos, y: pos.y - last_first_pos.y, }),
        )
      }
      let mut height : @library.Abs? = None
      for entry in equation_builder.frames {
        let (frame, pos) = entry
        let h = frame.height() + pos.y
        height = match height {
          None => Some(h)
          Some(m) => Some(m.max(h))
        }
      }
      equation_builder.size = {
        ..equation_builder.size,
        y: height.unwrap_or(equation_builder.size.y),
      }
    }

    // Ensure that there is at least one frame, even for empty equations.
    if equation_builders.is_empty() {
      equation_builders.push({ frames: [], size: @library.Axes::zero_size(), })
    }
    equation_builders
  } else {
    [full_equation_builder]
  }
  guard elem.numbering(styles) is Some(numbering) else {
    let frames = equation_builders.map(b => b.build_aligned())
    return @library.Fragment::frames(frames)
  }
  let pod = @library.LayoutRegion::new(
    regions.base(),
    @library.Axes::splat(false),
  )
  let counter = @library.Counter::of(@library.equation_elem())
    .display_at(
      engine,
      elem.pack().location().unwrap(),
      styles,
      numbering,
      span,
    )
    .spanned(span)
  let locator = locator.split()
  let number = layout_frame(engine, counter, locator.next(()), styles, pod)
  let number_gutter = @library.Em::new(0.5)
  let full_number_width = number.width() + number_gutter.resolve(styles)
  let number_align : @library.SpecificAlignment[
    @library.OuterHAlignment,
    @library.VAlignment,
  ] = match elem.number_align(styles) {
    H(h) => Both(h, Horizon)
    V(v) => Both(End, v)
    Both(h, v) => Both(h, v)
  }
  let number_align = match number_align {
    Both(h, v) => @library.Axes::new(h.resolve(styles), v.resolve(styles))
    _ => abort("unreachable")
  }

  // Add equation numbers to each equation region.
  let region_count = equation_builders.length()
  let frames = equation_builders.map(builder => {
    if builder.frames.is_empty() && region_count > 1 {
      // Don't number empty regions, but do number empty equations.
      return builder.build_aligned()
    }
    add_equation_number(
      builder,
      number.clone(),
      number_align,
      @library.AlignElem::alignment_in(styles).resolve(styles).x,
      regions.size.x,
      full_number_width,
    )
  })
  @library.Fragment::frames(frames)
}

///|
fn add_equation_number(
  equation_builder : MathRunFrameBuilder,
  number : @library.Frame,
  number_align : @library.Axes[@library.FixedAlignment],
  equation_align : @library.FixedAlignment,
  region_size_x : @library.Abs,
  full_number_width : @library.Abs,
) -> @library.Frame {
  let first = match equation_builder.frames.get(0) {
    None =>
      (equation_builder.size, @library.Point::zero(), @library.Abs::zero())
    Some((frame, pos)) => (frame.size(), pos, frame.baseline())
  }
  let last = match equation_builder.frames.last() {
    None =>
      (equation_builder.size, @library.Point::zero(), @library.Abs::zero())
    Some((frame, pos)) => (frame.size(), pos, frame.baseline())
  }
  let line_count = equation_builder.frames.length()
  let equation = equation_builder.build_aligned()
  let width = if region_size_x.is_finite() {
    region_size_x
  } else {
    equation.width() + full_number_width.times(2.0)
  }
  let is_multiline = line_count >= 2
  let resizing_offset = resize_equation(
    equation, number, number_align, equation_align, width, is_multiline, first, last,
  )
  equation.translate(
    @library.Point::with_x(
      match (equation_align, number_align.x) {
        (Start, Start) => full_number_width
        (End, End) => -full_number_width
        _ => @library.Abs::zero()
      },
    ),
  )
  let x = match number_align.x {
    Start => @library.Abs::zero()
    End => equation.width() - number.width()
    Center => abort("unreachable")
  }
  let y = {
    let align_baselines = (
      line : (@library.Axes[@library.Abs], @library.Point, @library.Abs),
      number : @library.Frame,
    ) => {
      let (_, pos, baseline) = line
      resizing_offset.y + pos.y + baseline - number.baseline()
    }
    match number_align.y {
      Start => align_baselines(first, number)
      Center if !is_multiline => align_baselines(first, number)
      // In this case, the center lines (not baselines) of the number frame
      // and the equation frame shall be aligned.
      Center => (equation.height() - number.height()).div_by(2.0)
      End => align_baselines(last, number)
    }
  }
  equation.push_frame(@library.Point::new(x, y), number)
  equation
}

///|
/// Resize the equation's frame accordingly so that it encompasses the number.
fn resize_equation(
  equation : @library.Frame,
  number : @library.Frame,
  number_align : @library.Axes[@library.FixedAlignment],
  equation_align : @library.FixedAlignment,
  width : @library.Abs,
  is_multiline : Bool,
  first : (@library.Axes[@library.Abs], @library.Point, @library.Abs),
  last : (@library.Axes[@library.Abs], @library.Point, @library.Abs),
) -> @library.Point {
  if number_align.y is Center && is_multiline {
    // In this case, the center lines (not baselines) of the number frame
    // and the equation frame shall be aligned.
    return equation.resize(
      @library.Axes::new(width, equation.height().max(number.height())),
      @library.Axes::new(equation_align, Center),
    )
  }
  let excess_above = @library.Abs::zero().max(
    if !is_multiline || number_align.y is Start {
      let (_, _, baseline) = first
      number.baseline() - baseline
    } else {
      @library.Abs::zero()
    },
  )
  let excess_below = @library.Abs::zero().max(
    if !is_multiline || number_align.y is End {
      let (size, _, baseline) = last
      number.height() - number.baseline() - (size.y - baseline)
    } else {
      @library.Abs::zero()
    },
  )

  // The vertical expansion is asymmetric on the top and bottom edges, so we
  // first align at the top then translate the content downward later.
  let resizing_offset = equation.resize(
    @library.Axes::new(width, equation.height() + excess_above + excess_below),
    @library.Axes::new(equation_align, Start),
  )
  equation.translate(@library.Point::with_y(excess_above))
  resizing_offset + @library.Point::with_y(excess_above)
}

///|
/// The context for math layout.
priv struct MathContext {
  // External.
  engine : @library.Engine
  region : @library.LayoutRegion
  // Mutable.
  fonts_stack : Array[@library.FontInstance]
  fragments : Array[MathFragment]
}

///|
/// Create a new math context.
fn MathContext::new(
  engine : @library.Engine,
  base : @library.Axes[@library.Abs],
  font : @library.FontInstance,
) -> MathContext {
  {
    engine,
    region: @library.LayoutRegion::new(base, @library.Axes::splat(false)),
    fonts_stack: [font],
    fragments: [],
  }
}

///|
/// Get the current base font.
fn MathContext::font(self : MathContext) -> @library.FontInstance {
  // Will always be at least one font in the stack.
  self.fonts_stack.last().unwrap()
}

///|
/// Push a fragment.
fn MathContext::push(self : MathContext, fragment : MathFragment) -> Unit {
  self.fragments.push(fragment)
}

///|
/// Push multiple fragments.
fn MathContext::extend_with(
  self : MathContext,
  fragments : Array[MathFragment],
) -> Unit {
  self.fragments.append(fragments)
}

///|
/// Layout the given math item and return the resulting [`MathFragment`]s.
fn MathContext::layout_into_fragments(
  self : MathContext,
  item : @library.MathItem,
  styles : @library.StyleChain,
) -> Array[MathFragment] raise @library.SourceError {
  let start = self.fragments.length()
  self.layout_into_self(item, styles)
  let out = self.fragments[start:].to_owned()
  self.fragments.truncate(start)
  out
}

///|
/// Layout the given math item and return the resulting [`MathFragment`]s.
fn MathContext::layout_into_fragment(
  self : MathContext,
  item : @library.MathItem,
  styles : @library.StyleChain,
) -> MathFragment raise @library.SourceError {
  let fragments = self.layout_into_fragments(item, styles)
  if fragments.length() == 1 {
    return fragments[0]
  }

  // Fragments without a math_size are ignored: the notion of size does
  // not apply to them, so their text-likeness is meaningless.
  let text_like = fragments
    .iter()
    .filter(e => e.math_size() is Some(_))
    .all(e => e.is_text_like())
  let styles = item.styles().unwrap_or(styles)
  let props = @library.MathProperties::default(styles, @syntax.Span::detached())
  let frame = math_run_into_frame(fragments)
  Frame(FrameFragment::new(props, styles, frame).with_text_like(text_like))
}

///|
fn MathContext::layout_into_self(
  self : MathContext,
  item : @library.MathItem,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  let outer_styles = item.styles().unwrap_or(styles)
  let outer_font = @library.TextElem::font_in(outer_styles)
  for item in item.as_slice() {
    let styles = item.styles().unwrap_or(outer_styles)

    // Whilst this check isn't exact, it more or less suffices as a
    // change in font variant probably won't have an effect on metrics.
    if styles != outer_styles &&
      @library.TextElem::font_in(styles) != outer_font {
      self.fonts_stack.push(get_font(self.engine.world, styles, item.span()))
      let scale_style = style_for_script_scale(self.font())
      layout_realized(item, self, styles.chain_one(scale_style))
      self.fonts_stack.pop() |> ignore
    } else {
      layout_realized(item, self, styles)
    }
  }
}

///|
/// Lays out a single math item.
fn layout_realized(
  item : @library.MathItem,
  ctx : MathContext,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  // Handle non-component items first.
  let comp = match item {
    Comp(comp) => comp
    Spacing(amount, font_size, _) => {
      ctx.push(Space(amount.at(font_size)))
      return
    }
    Space => {
      ctx.push(Space(ctx.font().math().space_width.resolve(styles)))
      return
    }
    Tag(tag) => {
      ctx.push(Tag(tag))
      return
    }
  }
  let props = comp.props

  // Insert left spacing. Items with an alignment form get their spacing
  // handled by the multiline layout instead.
  if props.lspace is Some(lspace) &&
    !props.align_form_infix &&
    !lspace.is_zero() {
    let width = lspace.at(@library.TextElem::size_in(styles).resolve(styles))
    ctx.push(Space(width))
  }

  // Dispatch based on item kind to the appropriate layout function.
  match comp.kind {
    Box(item) => layout_math_box(item, ctx, styles, props)
    Mathml(item) => layout_mathml(item, ctx, styles, props)
    External(item) => layout_external(item, ctx, styles, props)
    Glyph(item) => layout_math_glyph(item, ctx, styles, props)
    Cancel(item) => layout_cancel(item, ctx, styles, props)
    Radical(item) => layout_radical(item, ctx, styles, props)
    Line(item) => layout_math_line(item, ctx, styles, props)
    Accented(item) => layout_accent(item, ctx, styles, props)
    Scripts(item) => layout_scripts(item, ctx, styles, props)
    Primes(item) => layout_primes(item, ctx, styles, props)
    Table(item) => layout_math_table(item, ctx, styles, props)
    Fraction(item) => layout_fraction(item, ctx, styles, props)
    SkewedFraction(item) => layout_skewed_fraction(item, ctx, styles, props)
    Text(item) => layout_math_text(item, ctx, styles, props)
    Number(item) => layout_math_number(item, ctx, styles, props)
    Fenced(item) => layout_fenced(item, ctx, styles, props)
    Multiline(item) => {
      // Don't set the baseline by default, unless the item is centered.
      let frame = layout_multiline(item, ctx, styles).build_unaligned()
      if item.centered {
        let axis = ctx.font().math().axis_height.resolve(styles)
        frame.set_baseline(frame.height().div_by(2.0) + axis)
      }
      ctx.push(Frame(FrameFragment::new(props, styles, frame)))
    }
    Group(_) => {
      let fragment = ctx.layout_into_fragment(item, styles)
      let italics = fragment.italics_correction()
      let accent_attach = fragment.accent_attach()
      ctx.push(
        Frame(
          FrameFragment::new(props, styles, fragment.into_frame())
          .with_italics_correction(italics)
          .with_accent_attach(accent_attach),
        ),
      )
    }
  }

  // Insert right spacing.
  if props.rspace is Some(rspace) && !rspace.is_zero() {
    let width = rspace.at(@library.TextElem::size_in(styles).resolve(styles))
    ctx.push(Space(width))
  }
}

///|
/// Ignore a MathML HTML element during paged export.
fn layout_mathml(
  item : @library.MathmlItem,
  ctx : MathContext,
  _styles : @library.StyleChain,
  _props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  ctx.engine.sink.warn(
    @library.SourceDiagnostic::warning_at(
      item.elem.span(),
      "MathML element was ignored during paged export",
    ),
  )
}

///|
/// Lays out a [`BoxItem`].
fn layout_math_box(
  item : @library.BoxItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let frame = layout_box(
    item.elem,
    ctx.engine,
    item.locator.relayout(),
    styles,
    ctx.region.size,
  )
  ctx.push(Frame(FrameFragment::new(props, styles, frame)))
}

///|
/// Layout into a frame with normal layout.
fn layout_external(
  item : @library.ExternalItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let frame = layout_frame(
    ctx.engine,
    item.content,
    item.locator.relayout(),
    styles,
    ctx.region,
  )
  if !frame.has_baseline() {
    let axis = ctx.font().math().axis_height.resolve(styles)
    frame.set_baseline(frame.height().div_by(2.0) + axis)
  }
  ctx.push(Frame(FrameFragment::new(props, styles, frame)))
}

///|
/// Styles to add font constants to the style chain.
fn style_for_script_scale(font : @library.FontInstance) -> @library.Style {
  @library.EquationElem::set_script_scale(
    (
      @library.I16(font.math().script_percent_scale_down.to_int64()),
      @library.I16(font.math().script_script_percent_scale_down.to_int64()),
    ),
  )
}

///|
/// The font families for math (upstream `typst_library::math::families`).
fn math_families(styles : @library.StyleChain) -> Array[@library.FontFamily] {
  let fallbacks = [
    "new computer modern math", "libertinus serif", "twitter color emoji", "noto color emoji",
    "apple color emoji", "segoe ui emoji",
  ]
  let out = @library.TextElem::font_in(styles).0.copy()
  if @library.TextElem::fallback_in(styles) {
    for family in fallbacks {
      out.push(@library.FontFamily::new(family))
    }
  }
  out
}

///|
/// Get the current base font.
fn get_font(
  world : &@library.World,
  styles : @library.StyleChain,
  span : @syntax.Span,
) -> @library.FontInstance raise @library.SourceError {
  let variant = @library.variant(styles)
  let size = @library.TextElem::size_in(styles).resolve(styles)
  let variations = @library.TextElem::variations_in(styles)
  for family in math_families(styles) {
    guard world.book().select(family.as_str(), variant) is Some(id) else {
      continue
    }
    guard world.font(id) is Some(font) else { continue }
    guard family.covers is None else { continue }
    return font.instantiate(variant, size, variations)
  }
  @library.bail_at(span, "no font could be found")
}

///|
/// Check if the top-level base font has a MATH table.
fn warn_non_math_font(
  font : @library.Font,
  engine : @library.Engine,
  span : @syntax.Span,
) -> Unit {
  if !font.info().flags.contains(@library.font_flags_math) {
    engine.sink.warn(
      @library.SourceDiagnostic::warning_at(
        span,
        "font family is not designed for math: \{font.info().family}",
      ).with_hint("rendering may be poor"),
    )
  }
}
