// Port of `typst-library/src/math/ir/resolve.rs` and `ir/mod.rs`.

///|
/// Base styles chained to the style chain for text items.
let text_base_local_styles : Styles = Styles::from_array([
  TextElem::set_top_edge(Metric(Bounds)),
  TextElem::set_bottom_edge(Metric(Bounds)),
  TextElem::set_overhang(false),
])

///|
/// Resolves an equation's body into a `MathItem`.
pub fn resolve_equation(
  elem : EquationElem,
  engine : Engine,
  locator : Locator,
  styles : StyleChain,
) -> MathItem raise SourceError {
  let context = MathResolver::new(engine, locator)
  context.resolve_into_item(elem.body(), styles)
}

///|
/// The math IR builder.
priv struct MathResolver {
  /// External engine.
  engine : Engine
  /// External locator.
  locator : SplitLocator
  /// The working buffer of resolved items.
  items : Array[RawMathItem]
}

///|
/// Create a new math builder.
fn MathResolver::new(engine : Engine, locator : Locator) -> MathResolver {
  { engine, locator: locator.split(), items: [], }
}

///|
/// Push an item.
fn MathResolver::push(self : MathResolver, item : MathItem) -> Unit {
  self.items.push(Item(item))
}

///|
/// Push a raw item.
fn MathResolver::push_raw(self : MathResolver, item : RawMathItem) -> Unit {
  self.items.push(item)
}

///|
/// Removes and returns the items from `start` on (upstream `drain(start..)`).
fn MathResolver::drain_from(
  self : MathResolver,
  start : Int,
) -> Array[RawMathItem] {
  let drained = self.items[start:].iter().collect()
  self.items.truncate(start)
  drained
}

///|
/// Resolve the given element and return the start index of the resulting
/// `RawMathItem`s.
fn MathResolver::resolve_into_items(
  self : MathResolver,
  elem : Content,
  styles : StyleChain,
) -> Int raise SourceError {
  let start = self.items.length()
  self.resolve_into_self(elem, styles)
  start
}

///|
/// Resolve the given element and return the result as a `MathItem`.
fn MathResolver::resolve_into_item(
  self : MathResolver,
  elem : Content,
  styles : StyleChain,
) -> MathItem raise SourceError {
  let start = self.resolve_into_items(elem, styles)
  let len = self.items.length() - start

  // Don't emit standalone linebreaks or alignment points.
  if len == 1 && self.items.last() is Some(Item(_)) {
    return self.items.pop().unwrap().into_item().unwrap()
  }
  match process_group(self.drain_from(start)[:], styles, false, true, false) {
    Multiline(rows) => MultilineItem::create(rows, styles)
    Flat(items) => MathItem::wrap(items, styles)
  }
}

///|
/// Resolve arbitrary content.
fn MathResolver::resolve_into_self(
  self : MathResolver,
  content : Content,
  styles : StyleChain,
) -> Unit raise SourceError {
  let pairs = (self.engine.routines().realize)(
    Math,
    self.engine,
    self.locator,
    content,
    styles,
  )
  for pair in pairs {
    resolve_realized(pair.0, self, pair.1)
  }
}

///|
/// Resolves a symbol given as a character with the given span into an item.
fn MathResolver::resolve_char(
  self : MathResolver,
  c : Char,
  span : @syntax.Span,
  styles : StyleChain,
) -> MathItem raise SourceError {
  self.resolve_into_item(
    SymbolElem::packed(c.to_string()).spanned(span),
    styles,
  )
}

///|
/// Resolves a leaf element resulting from realization.
fn resolve_realized(
  elem : Content,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  if SymbolElem::of(elem) is Some(elem) {
    resolve_symbol(elem, ctx, styles)
  } else if elem.is_(space_elem()) {
    ctx.push(Space)
  } else if TextElem::of(elem) is Some(elem) {
    resolve_text(elem, ctx, styles)
  } else if MathAttachElem::of(elem) is Some(elem) {
    resolve_attach(elem, ctx, styles)
  } else if LrElem::of(elem) is Some(elem) {
    resolve_lr(elem, ctx, styles)
  } else if OpElem::of(elem) is Some(elem) {
    resolve_op(elem, ctx, styles)
  } else if HElem::of(elem) is Some(elem) {
    resolve_h(elem, ctx, styles)
  } else if MathOverlineElem::of(elem) is Some(elem) {
    resolve_overline(elem, ctx, styles)
  } else if elem.is_(align_point_elem()) {
    ctx.push_raw(Align)
  } else if PrimesElem::of(elem) is Some(elem) {
    resolve_primes(elem, ctx, styles)
  } else if TagElem::of(elem) is Some(elem) {
    ctx.push(Tag(elem.tag()))
  } else if ClassElem::of(elem) is Some(elem) {
    resolve_class(elem, ctx, styles)
  } else if elem.is_(linebreak_elem()) {
    ctx.push_raw(Linebreak)
  } else if FracElem::of(elem) is Some(elem) {
    resolve_frac(elem, ctx, styles)
  } else if AccentElem::of(elem) is Some(elem) {
    resolve_accent(elem, ctx, styles)
  } else if LimitsElem::of(elem) is Some(elem) {
    resolve_limits(elem, ctx, styles)
  } else if StretchElem::of(elem) is Some(elem) {
    resolve_stretch(elem, ctx, styles)
  } else if RootElem::of(elem) is Some(elem) {
    resolve_root(elem, ctx, styles)
  } else if BoxElem::of(elem) is Some(elem) {
    let locator = ctx.locator.next(elem.pack().span())
    ctx.push(BoxItem::create(elem, styles, locator))
  } else if MatElem::of(elem) is Some(elem) {
    resolve_mat(elem, ctx, styles)
  } else if MidElem::of(elem) is Some(elem) {
    resolve_mid(elem, ctx, styles)
  } else if MathUnderlineElem::of(elem) is Some(elem) {
    resolve_underline(elem, ctx, styles)
  } else if CasesElem::of(elem) is Some(elem) {
    resolve_cases(elem, ctx, styles)
  } else if UnderbraceElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⏟',
      Below,
      elem.pack().span(),
    )
  } else if ScriptsElem::of(elem) is Some(elem) {
    resolve_scripts(elem, ctx, styles)
  } else if CancelElem::of(elem) is Some(elem) {
    resolve_cancel(elem, ctx, styles)
  } else if UnderbracketElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⎵',
      Below,
      elem.pack().span(),
    )
  } else if VecElem::of(elem) is Some(elem) {
    resolve_vec(elem, ctx, styles)
  } else if OverbraceElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⏞',
      Above,
      elem.pack().span(),
    )
  } else if BinomElem::of(elem) is Some(elem) {
    resolve_binom(elem, ctx, styles)
  } else if OverbracketElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⎴',
      Above,
      elem.pack().span(),
    )
  } else if UnderparenElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⏝',
      Below,
      elem.pack().span(),
    )
  } else if OverparenElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⏜',
      Above,
      elem.pack().span(),
    )
  } else if UndershellElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⏡',
      Below,
      elem.pack().span(),
    )
  } else if OvershellElem::of(elem) is Some(elem) {
    resolve_underoverspreader(
      ctx,
      styles,
      elem.body(),
      elem.annotation(styles),
      '⏠',
      Above,
      elem.pack().span(),
    )
  } else if (ctx.engine.routines().html_mathml_body)(elem, styles) is Some(body) {
    resolve_mathml(elem, body, ctx, styles)
  } else {
    let locator = ctx.locator.next(elem.span())
    ctx.push(ExternalItem::create(elem, styles, locator))
  }
}

///|
/// Resolves a MathML HTML element.
fn resolve_mathml(
  elem : Content,
  body : Content?,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let body = if TargetElem::target_in(styles).is_html() {
    match body {
      Some(body) => Some(ctx.resolve_into_item(body, styles))
      None => None
    }
  } else {
    None
  }
  ctx.push(MathmlItem::create(elem, body, styles))
}

///|
/// Resolves horizontal spacing.
fn resolve_h(elem : HElem, ctx : MathResolver, styles : StyleChain) -> Unit {
  if elem.amount() is Rel(rel) && rel.rel.is_zero() {
    ctx.push(
      Spacing(
        rel.abs,
        TextElem::size_in(styles).resolve(styles),
        elem.weak(styles),
      ),
    )
  }
}

///|
/// Applies the math styling (variant, bold, italic) to each character of the
/// text.
fn math_styled_text(
  text : StringView,
  variant : MathVariant?,
  bold : Bool,
  italic : Bool?,
) -> String {
  let buf = StringBuilder()
  for c in text {
    buf.write_string(to_style(c, MathStyle::select(c, variant, bold, italic)))
  }
  buf.to_string()
}

///|
/// Resolves text content.
fn resolve_text(
  elem : TextElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit {
  let variant = EquationElem::variant_in(styles)
  let bold = EquationElem::bold_in(styles)
  // Disable auto-italic.
  let italic = match EquationElem::italic_in(styles) {
    Some(italic) => Some(italic)
    None => Some(false)
  }

  // Create item with correct styles and properties.
  let local_styles = styles.chain(text_base_local_styles)
  let span = elem.pack().span()
  let create_item = (text : String) => {
    let mut decimal_count = 0
    let mut all = true
    for c in text {
      if c == '.' {
        decimal_count += 1
      }
      if !(c is ('0'..<='9') || c == '.') {
        all = false
        break
      }
    }
    let num = all &&
      decimal_count != @syntax.utf8_len(text) && // at least one digit
      decimal_count <= 1 // at most one dot
    let styled_text = math_styled_text(text, variant, bold, italic)
    if num {
      NumberItem::create(styled_text, styles, span)
    } else {
      MathTextItem::create(
        styled_text,
        local_styles,
        span,
        ctx.locator.next(span),
      )
    }
  }

  // Strip a single trailing newline.
  let lines = @syntax.split_newlines(elem.text())
  if lines.last() is Some("") {
    lines.pop() |> ignore
  }
  let item = if lines.length() == 1 {
    create_item(lines[0])
  } else {
    let rows = lines.map(line => AlignedRow::new([create_item(line)]))
    MultilineItem::create(rows, styles).with_multiline_centering()
  }
  ctx.push(item)
}

///|
/// Resolves a symbol element into glyph items.
///
/// Each grapheme cluster in the symbol becomes a separate glyph item.
fn resolve_symbol(
  elem : SymbolElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit {
  let variant = EquationElem::variant_in(styles)
  let bold = EquationElem::bold_in(styles)
  let italic = EquationElem::italic_in(styles)
  let span = elem.pack().span()
  for cluster in @unicode.graphemes(elem.text()) {
    if cluster.iter().all(@unicode.is_default_ignorable) {
      continue
    }
    let text = math_styled_text(cluster, variant, bold, italic)
    let item = GlyphItem::create(text, styles, span)
    if item.class() == Large && item.size().unwrap() == MathSize::Display {
      let stretch = Stretch::new().with_y(StretchInfo::default())
      item.replace_stretch(stretch)
    }
    ctx.push(item)
  }
}

///|
/// Resolves an accent element.
///
/// The base is resolved in cramped style if the accent is above.
fn resolve_accent(
  elem : AccentElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let accent = elem.accent()
  let position : MathPosition = if accent.is_bottom() { Below } else { Above }
  let new_styles = Styles::new()
  if position == Above {
    new_styles.apply_one(style_cramped())

    // Try to replace the base glyph with its dotless variant.
    if elem.dotless(styles) {
      new_styles.apply_one(style_dtls())
    }
  }
  let base_styles = styles.chain(new_styles)
  let base = ctx.resolve_into_item(elem.base(), base_styles)
  let span = elem.pack().span()
  let accent = ctx.resolve_char(accent.0, span, styles)
  accent.set_class(Diacritic)
  let width = elem.size(styles).map(l => l.resolve(styles))
  accent.set_stretch(
    Stretch::new().with_x(StretchInfo::new(width, accent_short_fall)),
  )
  ctx.push(
    AccentItem::create(
      base,
      accent,
      position,
      elem.dotless(styles),
      false,
      styles,
    ),
  )
}

///|
/// Resolves an attach element.
///
/// Deals with primes, merges nested attachements, and decides the final
/// positioning based on limits/scripts.
fn resolve_attach(
  elem : MathAttachElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let outer_attachments : Array[AttachmentList?] = Array::make(6, None)
  let item = resolve_inner_attach(elem, outer_attachments, false, ctx, styles)
  ctx.push(item)
}

///|
/// A node of a mutable linked list used for attachment merging (upstream
/// `AttachmentList`, with `None` playing the role of `End`).
///
/// Consider: `attach(attach(attach(a, t: 1), b: 2), t: 3, b: 4)`. We would
/// like this to become `attach(attach(a, t: 1, b: 2), t: 3, b: 4)`.
///
/// However if we only consider attachments in adjacent levels, we won't
/// merge `b:4` inward because `b:2` is already present (but we will merge
/// `t:3` in). But at the next step `b:2` would merge inwards, leaving us
/// with the sorry state of `attach(attach(attach(a, t: 1, b: 2), t: 3), b:
/// 4)` with `t:3` and `b:4` separated, despite originally starting at the
/// same level!
///
/// So for correct handling we need a proper list of attachments.
priv struct AttachmentList {
  /// We use `Content?` instead of just `Content` to allow for the
  /// "unmerging" operation used by primes in tr position.
  mut data : Content?
  outer : AttachmentList?
}

///|
fn AttachmentList::inner(
  content : Content?,
  outer : AttachmentList?,
) -> AttachmentList {
  fn merge_inward(list : AttachmentList?) -> Content? {
    match list {
      Some(node) => {
        let merged = merge_inward(node.outer)
        let old = node.data
        node.data = merged
        old
      }
      None => None
    }
  }

  let data = match content {
    Some(c) => Some(c)
    None => merge_inward(outer)
  }
  { data, outer, }
}

///|
fn attachment_list_unmerge(list : AttachmentList?, content : Content) -> Unit {
  let mut data : Content? = Some(content)
  let mut cur = list
  while data is Some(_) && cur is Some(node) {
    let old = node.data
    node.data = data
    data = old
    cur = node.outer
  }
  if data is Some(_) {
    abort("only called if we previously merged inward")
  }
}

///|
/// Recursively resolve the base of an `AttachElem`, merging outer
/// attachments inwards.
fn resolve_inner_attach(
  elem : MathAttachElem,
  outer_attachments : Array[AttachmentList?],
  outer_t_inside_tr : Bool,
  ctx : MathResolver,
  styles : StyleChain,
) -> MathItem raise SourceError {
  // The super/subscript styles.
  let sup_style_chain = styles.chain_one(style_for_superscript(styles))
  let sub_style_chain = styles.chain(style_for_subscript(styles))

  // Get the merged attachments without resolving them to items yet.
  let o_t = outer_attachments[0]
  let o_b = outer_attachments[1]
  let o_tl = outer_attachments[2]
  let o_tr = outer_attachments[3]
  let o_bl = outer_attachments[4]
  let o_br = outer_attachments[5]
  let tl = AttachmentList::inner(elem.tl(sup_style_chain), o_tl)
  // We remember the status of t and tr for correct prime handling below.
  let elem_t = elem.t(sup_style_chain)
  let elem_tr = elem.tr(sup_style_chain)
  let no_inner_tr = elem_tr is None
  let t_inside_tr = no_inner_tr && (elem_t is Some(_) || outer_t_inside_tr)
  let t = AttachmentList::inner(elem_t, o_t)
  let tr = AttachmentList::inner(elem_tr, o_tr)
  let b = AttachmentList::inner(elem.b(sub_style_chain), o_b)
  let bl = AttachmentList::inner(elem.bl(sub_style_chain), o_bl)
  let br = AttachmentList::inner(elem.br(sub_style_chain), o_br)
  let attachments : Array[AttachmentList?] = [
    Some(t),
    Some(b),
    Some(tl),
    Some(tr),
    Some(bl),
    Some(br),
  ]

  // Extract from a nested EquationElem.
  let mut base_elem = elem.base()
  while EquationElem::of(base_elem) is Some(equation) {
    base_elem = equation.body()
  }

  // Resolve the base and recursively merge outer attachments inwards.
  let base = if MathAttachElem::of(base_elem) is Some(base_elem) {
    resolve_inner_attach(base_elem, attachments, t_inside_tr, ctx, styles)
  } else {
    ctx.resolve_into_item(base_elem, styles)
  }

  // We can now take our inner attachments back out of the list.
  let t = t.data
  let b = b.data
  let tl = tl.data
  let tr = tr.data
  let bl = bl.data
  let br = br.data

  // If we're not actually attaching anything, just return the base.
  if t is None &&
    b is None &&
    tl is None &&
    tr is None &&
    bl is None &&
    br is None {
    return base
  }

  // Apply limits, potentially joining top-right primes with the top
  // attachment.
  let limits = base.limits().active(styles)
  let (t, tr) : (Content?, Content?) = match (t, tr) {
    (Some(t), Some(tr)) if !limits => {
      let primed = tr.is_(primes_elem())
      if primed && no_inner_tr && t_inside_tr {
        // If we brought a primed tr inward, yield it back to the outer
        // attachment to avoid inverting the order with `tr + t`. And note
        // that `t + tr` would just look bad.
        attachment_list_unmerge(o_tr, tr)
        (None, Some(t))
      } else if primed {
        // This makes `x'^2` look better than `x^'^2`.
        (None, Some(tr.add(t)))
      } else {
        (Some(t), Some(tr))
      }
    }
    (Some(t), None) if !limits => (None, Some(t))
    (t, tr) => (t, tr)
  }
  let (b, br) : (Content?, Content?) = if limits || br is Some(_) {
    (b, br)
  } else {
    (None, b)
  }

  // Finally, resolve the attachments themselves from content to items.
  let resolve = (content : Content?, chain : StyleChain) => {
    match content {
      Some(elem) => Some(ctx.resolve_into_item(elem, chain))
      None => None
    }
  }
  let top = resolve(t, sup_style_chain)
  let bottom = resolve(b, sub_style_chain)
  let top_left = resolve(tl, sup_style_chain)
  let bottom_left = resolve(bl, sub_style_chain)
  let top_right = resolve(tr, sup_style_chain)
  let bottom_right = resolve(br, sub_style_chain)
  ScriptsItem::create(
    base, top, bottom, top_left, bottom_left, top_right, bottom_right, styles,
  )
}

///|
/// Resolves grouped primes.
fn resolve_primes(
  elem : PrimesElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let count = elem.count().0.to_int()
  match count {
    1 | 2 | 3 | 4 => {
      let c = match count {
        1 => '′'
        2 => '″'
        3 => '‴'
        _ => '⁗'
      }
      let f = ctx.resolve_char(c, elem.pack().span(), styles)
      ctx.push(f)
    }
    // Custom amount of primes
    count => ctx.push(PrimesItem::create(count, styles))
  }
}

///|
/// Resolves a scripts element.
fn resolve_scripts(
  elem : ScriptsElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let item = ctx.resolve_into_item(elem.body(), styles)
  item.set_limits(Never)
  ctx.push(item)
}

///|
/// Resolves a limits element.
fn resolve_limits(
  elem : LimitsElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let item = ctx.resolve_into_item(elem.body(), styles)
  let limits : MathLimits = if elem.inline(styles) { Always } else { Display }
  item.set_limits(limits)
  ctx.push(item)
}

///|
/// Resolves a stretch element.
fn resolve_stretch(
  elem : StretchElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let item = ctx.resolve_into_item(elem.body(), styles)
  let size = elem.size(styles)
  let font_size = TextElem::size_in(styles).resolve(styles)
  item.update_stretch(StretchInfo::from_size(size, Em::zero(), font_size))
  ctx.push(item)
}

///|
/// Resolves a cancel element.
fn resolve_cancel(
  elem : CancelElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let body = ctx.resolve_into_item(elem.body(), styles)
  let length = elem.length(styles).map(l => l.resolve(styles))
  let stroke = elem
    .stroke(styles)
    .resolve(styles)
    .unwrap_or({
      ..FixedStroke::default(),
      paint: TextElem::fill_in(styles).as_decoration(),
    })
  let invert = elem.inverted(styles)
  let cross = elem.cross(styles)
  let angle = elem.angle(styles)
  let invert_first_line = !cross && invert
  let background = elem.background(styles)
  ctx.push(
    CancelItem::create(
      body,
      length,
      stroke,
      cross,
      invert_first_line,
      background,
      angle,
      styles,
      elem.pack().span(),
    ),
  )
}

///|
/// Resolves a fraction element.
fn resolve_frac(
  elem : FracElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let span = elem.pack().span()
  match elem.style(styles) {
    Skewed => resolve_skewed_frac(ctx, styles, elem.num(), elem.denom(), span)
    Horizontal =>
      resolve_horizontal_frac(
        ctx,
        styles,
        elem.num(),
        elem.denom(),
        span,
        elem.num_deparenthesized(styles),
        elem.denom_deparenthesized(styles),
      )
    Vertical =>
      resolve_vertical_frac_like(
        ctx,
        styles,
        elem.num(),
        [elem.denom()],
        false,
        span,
      )
  }
}

///|
/// Resolves a binomial element.
fn resolve_binom(
  elem : BinomElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  resolve_vertical_frac_like(
    ctx,
    styles,
    elem.upper(),
    elem.lower(),
    true,
    elem.pack().span(),
  )
}

///|
/// Resolve a vertical fraction or binomial.
fn resolve_vertical_frac_like(
  ctx : MathResolver,
  styles : StyleChain,
  num : Content,
  denom : Array[Content],
  binom : Bool,
  span : @syntax.Span,
) -> Unit raise SourceError {
  let numerator = ctx.resolve_into_item(
    num,
    styles.chain_one(style_for_numerator(styles)),
  )

  // Add a comma between each element.
  let children = []
  for i, a in denom {
    if i > 0 {
      children.push(SymbolElem::packed(",").spanned(span))
    }
    children.push(a)
  }
  let denominator = ctx.resolve_into_item(
    Content::sequence(children),
    styles.chain(style_for_denominator(styles)),
  )
  let frac = FractionItem::create(
    numerator,
    denominator,
    !binom,
    frac_padding,
    styles,
    span,
  )
  if binom {
    let stretch = Stretch::new().with_y(
      StretchInfo::new(Rel::one(), delim_short_fall),
    )
    let open = ctx.resolve_char('(', span, styles)
    open.set_stretch(stretch)
    let close = ctx.resolve_char(')', span, styles)
    close.set_stretch(stretch)
    ctx.push(
      FencedItem::create(
        Some(open),
        Some(close),
        Owned(frac),
        false,
        styles,
        span,
      ),
    )
  } else {
    ctx.push(frac)
  }
}

///|
/// Wraps content in parentheses with an `LrElem`.
fn math_deparenthesized(body : Content) -> Content {
  LrElem::new(
    Content::sequence([SymbolElem::packed("("), body, SymbolElem::packed(")")]),
  ).pack()
}

///|
/// Resolve a horizontal (inline) fraction.
fn resolve_horizontal_frac(
  ctx : MathResolver,
  styles : StyleChain,
  num : Content,
  denom : Content,
  span : @syntax.Span,
  num_deparen : Bool,
  denom_deparen : Bool,
) -> Unit raise SourceError {
  let num = if num_deparen { math_deparenthesized(num) } else { num }
  let num = ctx.resolve_into_item(num, styles)
  ctx.push(num)
  let slash = ctx.resolve_char('/', span, styles)
  slash.set_class(Binary)
  slash.set_lspace(Some(Em::zero()))
  slash.set_rspace(Some(Em::zero()))
  ctx.push(slash)
  let denom = if denom_deparen { math_deparenthesized(denom) } else { denom }
  let denom = ctx.resolve_into_item(denom, styles)
  ctx.push(denom)
}

///|
/// Resolves a skewed (inline) fraction.
fn resolve_skewed_frac(
  ctx : MathResolver,
  styles : StyleChain,
  num : Content,
  denom : Content,
  span : @syntax.Span,
) -> Unit raise SourceError {
  let numerator = ctx.resolve_into_item(
    num,
    styles.chain_one(style_for_numerator(styles)),
  )
  let denominator = ctx.resolve_into_item(
    denom,
    styles.chain(style_for_denominator(styles)),
  )
  let slash = ctx.resolve_char('\u{2044}', span, styles)
  slash.set_stretch(
    Stretch::new().with_y(StretchInfo::new(Rel::one(), delim_short_fall)),
  )
  ctx.push(
    SkewedFractionItem::create(numerator, denominator, slash, styles, span),
  )
}

///|
/// Resolves a left/right element.
fn resolve_lr(
  elem : LrElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  // Extract from an EquationElem.
  let mut body = elem.body()
  if EquationElem::of(body) is Some(equation) {
    body = equation.body()
  }

  // Extract implicit LrElem.
  if LrElem::of(body) is Some(lr) && lr.size(styles).is_one() {
    body = lr.body()
  }
  let start = ctx.resolve_into_items(body, styles)

  // Ignore leading and trailing ignorant items.
  let (start_idx, end_idx) = split_prefix_suffix(ctx.items[start:], item => {
    item.is_ignorant()
  })
  let inner_start = start + start_idx
  let inner_end = start + end_idx
  let inner_items = ctx.items[inner_start:inner_end]
  let size = elem.size(styles)
  let font_size = TextElem::size_in(styles).resolve(styles)
  let stretch = Stretch::new().with_y(
    StretchInfo::from_size(size, delim_short_fall, font_size),
  )
  let scale_if_delimiter = (item : MathItem, apply : @unicode.MathClass?) => {
    if item.class() is (Opening | Closing | Fence) {
      item.set_stretch(stretch)
      if apply is Some(class) {
        item.set_class(class)
      }
    }
  }

  // Scale up items at both ends.
  match inner_items {
    [one] => {
      if one is Item(one) {
        if one is Comp({ kind: Fenced(fenced), .. }) {
          if fenced.open is Some(open) {
            open.set_stretch(stretch)
          }
          if fenced.close is Some(close) {
            close.set_stretch(stretch)
          }
          for item in fenced.body.item().as_slice() {
            if item.mid_stretched() == Some(true) {
              item.set_stretch(stretch)
            }
          }
        } else {
          let mut info = StretchInfo::new(
            Rel::from_abs(size.abs.at(font_size)),
            delim_short_fall,
          )
          if !size.is_one() {
            info = { ..info, requested_target: Some(size), }
          }
          one.set_y_stretch(info)
        }
      }
      return
    }
    [first, .., last] => {
      if first is Item(first) {
        scale_if_delimiter(first, Some(Opening))
      }
      if last is Item(last) {
        scale_if_delimiter(last, Some(Closing))
      }
    }
    [] => ()
  }

  // Handle MathItem::Glyph items that should be scaled up.
  for item in inner_items {
    if item is Item(item) && item.mid_stretched() == Some(false) {
      item.set_mid_stretched(Some(true))
      item.set_stretch(stretch)
    }
  }
  let suffix = ctx.items[inner_end:].iter().collect()
  let inner_items = ctx.items[inner_start:inner_end].iter().collect()
  ctx.items.truncate(inner_start)

  // Remove weak Spacing immediately after the opening or immediately before
  // the closing.
  let len = inner_items.length()
  let opening_exists = inner_items.get(0) is Some(Item(item)) &&
    item.class() == Opening
  let closing_exists = inner_items.last() is Some(Item(item)) &&
    item.class() == Closing
  let retained = []
  for index, item in inner_items {
    let discard = (
        (index == 1 && opening_exists) || (index + 2 == len && closing_exists)
      ) &&
      item is Item(Spacing(_, _, true))
    if !discard {
      retained.push(item)
    }
  }
  let inner_items = retained
  let open = if opening_exists {
    inner_items.remove(0).into_item()
  } else {
    None
  }
  let close = if closing_exists {
    inner_items.pop().unwrap().into_item()
  } else {
    None
  }
  let span = elem.pack().span()
  match process_group(inner_items[:], styles, close is Some(_), false, true) {
    Multiline(rows) => {
      let items = expand_multiline_fence(rows, open, close, styles, span)
      ctx.items.append(items)
    }
    Flat(items) => {
      let body = MathGroupItem::create(items, styles)
      let item = FencedItem::create(
        open,
        close,
        Owned(body),
        true,
        styles,
        span,
      )
      ctx.items.push(Item(item))
    }
  }
  ctx.items.append(suffix)
}

///|
/// Returns the indices at which the inner portion and the suffix start
/// (upstream `SliceExt::split_prefix_suffix`).
fn[T] split_prefix_suffix(slice : ArrayView[T], f : (T) -> Bool) -> (Int, Int) {
  let mut start = slice.length()
  for i, v in slice {
    if !f(v) {
      start = i
      break
    }
  }
  let mut end = start
  for i = slice.length() - 1; i >= start; i = i - 1 {
    if !f(slice[i]) {
      end = i + 1
      break
    }
  }
  (start, end)
}

///|
/// Resolves a middle element (in a left/right element).
fn resolve_mid(
  elem : MidElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let start = ctx.resolve_into_items(elem.body(), styles)
  for item in ctx.items[start:] {
    if item is Item(item) {
      item.set_mid_stretched(Some(false))
      item.set_class(Relation)
    }
  }
}

///|
/// Resolves a vector element.
fn resolve_vec(
  elem : VecElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let span = elem.pack().span()
  let rows = elem.children().map(child => [child])
  let cells = resolve_cells(
    ctx,
    styles,
    rows,
    span,
    elem.align(styles).fix(resolve_text_dir(styles)),
    Right,
    None,
    Axes::new(Rel::zero(), elem.gap(styles).map(l => l.resolve(styles))),
    "elements",
  )
  let delim = elem.delim(styles)
  resolve_delimiters(ctx, styles, cells, delim.open(), delim.close(), span)
}

///|
/// Resolves a matrix element.
fn resolve_mat(
  elem : MatElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let span = elem.pack().span()
  let rows = elem.rows()
  let nrows = rows.length()
  let ncols = match rows.get(0) {
    Some(row) => row.length()
    None => 0
  }
  let augment = elem.augment(styles).map(a => a.resolve(styles))
  if augment is Some(aug) {
    for offset in aug.hline.0 {
      if offset > nrows.to_int64() || offset.abs() > nrows.to_int64() {
        bail_at(
          span,
          "cannot draw a horizontal line at offset \{offset} in a matrix with \{nrows} rows",
        )
      }
    }
    for offset in aug.vline.0 {
      if offset > ncols.to_int64() || offset.abs() > ncols.to_int64() {
        bail_at(
          span,
          "cannot draw a vertical line at offset \{offset} in a matrix with \{ncols} columns",
        )
      }
    }
  }
  let cells = resolve_cells(
    ctx,
    styles,
    rows,
    span,
    elem.align(styles).fix(resolve_text_dir(styles)),
    Right,
    augment,
    Axes::new(
      elem.column_gap(styles).map(l => l.resolve(styles)),
      elem.row_gap(styles).map(l => l.resolve(styles)),
    ),
    "cells",
  )
  let delim = elem.delim(styles)
  resolve_delimiters(ctx, styles, cells, delim.open(), delim.close(), span)
}

///|
/// Resolves a cases element.
fn resolve_cases(
  elem : CasesElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let span = elem.pack().span()
  let rows = elem.children().map(child => [child])
  let cells = resolve_cells(
    ctx,
    styles,
    rows,
    span,
    Start,
    None_,
    None,
    Axes::new(Rel::zero(), elem.gap(styles).map(l => l.resolve(styles))),
    "branches",
  )
  let delim = elem.delim(styles)
  let (open, close) : (Char?, Char?) = if elem.reverse(styles) {
    (None, delim.close())
  } else {
    (delim.open(), None)
  }
  resolve_delimiters(ctx, styles, cells, open, close, span)
}

///|
/// Resolves the inner contents of a matrix, vector, or cases.
///
/// The contents of the cells are resolved in denominator style.
fn resolve_cells(
  ctx : MathResolver,
  styles : StyleChain,
  rows : Array[Array[Content]],
  span : @syntax.Span,
  align : FixedAlignment,
  alternator : LeftRightAlternator,
  augment : ResolvedAugment?,
  gap : Axes[Rel[Abs]],
  children : String,
) -> MathItem raise SourceError {
  let cell_styles = styles.chain(style_for_denominator(styles))
  let cells : Array[Array[AlignedRow]] = []
  for row in rows {
    let resolved_row = []
    for cell in row {
      let start = ctx.resolve_into_items(cell, cell_styles)
      let processed = process_table_cell(ctx.drain_from(start)[:], cell_styles)

      // We strip linebreaks in the cells as we can't differentiate alignment
      // points for the whole body from ones for a specific cell, and
      // multiline cells don't quite make sense at the moment.
      if processed.had_linebreaks {
        ctx.engine.sink.warn(
          SourceDiagnostic::warning_at(
            cell.span(),
            "linebreaks are ignored in \{children}",
          ).with_hint("use commas instead to separate each line"),
        )
      }
      resolved_row.push(processed.sub_columns)
    }
    cells.push(resolved_row)
  }

  // Pad sub-columns so that every row has the same length.
  let ncols = match cells.get(0) {
    Some(row) => row.length()
    None => 0
  }
  for c in 0..<ncols {
    let mut max = 0
    for row in cells {
      if row[c].len() > max {
        max = row[c].len()
      }
    }
    for row in cells {
      row[c].pad_to(max, cell_styles)
    }
  }
  MathTableItem::create(cells, gap, augment, align, alternator, styles, span)
}

///|
/// Resolves the delimiters around the body of a vector, matrix, or cases.
fn resolve_delimiters(
  ctx : MathResolver,
  styles : StyleChain,
  cells : MathItem,
  left : Char?,
  right : Char?,
  span : @syntax.Span,
) -> Unit raise SourceError {
  let target = Rel::new(Ratio::new(1.1), Abs::zero())
  let stretch = Stretch::new().with_y(
    StretchInfo::new(target, delim_short_fall),
  )
  let open = match left {
    Some(c) => {
      let x = ctx.resolve_char(c, span, styles)
      x.set_stretch(stretch)
      Some(x)
    }
    None => None
  }
  let close = match right {
    Some(c) => {
      let x = ctx.resolve_char(c, span, styles)
      x.set_stretch(stretch)
      Some(x)
    }
    None => None
  }
  ctx.push(FencedItem::create(open, close, Owned(cells), false, styles, span))
}

///|
/// Resolves a class element.
fn resolve_class(
  elem : ClassElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let item = ctx.resolve_into_item(elem.body(), styles)
  item.set_explicit_class(elem.class())
  item.set_limits(MathLimits::for_class(elem.class()))
  ctx.push(item)
}

///|
/// Resolves an operator element.
fn resolve_op(
  elem : OpElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let item = ctx.resolve_into_item(elem.text(), styles)
  item.set_class(Large)
  item.set_limits(if elem.limits(styles) { Display } else { Never })
  ctx.push(item)
}

///|
/// Resolves a root (radical) element.
///
/// The radicand is resolved in cramped style, and the index in scriptscript
/// size and cramped style.
fn resolve_root(
  elem : RootElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let cramped_styles = styles.chain_one(style_cramped())
  let radicand = ctx
    .resolve_into_item(elem.radicand(), cramped_styles)
    .with_multiline_centering()
  let index = match elem.index(styles) {
    Some(index) => {
      let sscript = EquationElem::set_size(ScriptScript)
      Some(ctx.resolve_into_item(index, cramped_styles.chain_one(sscript)))
    }
    None => None
  }
  let span = elem.pack().span()
  let sqrt = ctx.resolve_char('√', span, styles)
  sqrt.set_stretch(
    Stretch::new().with_y(StretchInfo::new(Rel::one(), Em::zero())),
  )
  ctx.push(RadicalItem::create(radicand, index, sqrt, styles, span))
}

///|
/// Resolves an under line element.
fn resolve_underline(
  elem : MathUnderlineElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let base = ctx.resolve_into_item(elem.body(), styles)
  ctx.push(LineItem::create(base, Below, styles, elem.pack().span()))
}

///|
/// Resolves an over line element.
///
/// The base is resolved in cramped style.
fn resolve_overline(
  elem : MathOverlineElem,
  ctx : MathResolver,
  styles : StyleChain,
) -> Unit raise SourceError {
  let cramped_styles = styles.chain_one(style_cramped())
  let base = ctx.resolve_into_item(elem.body(), cramped_styles)
  ctx.push(LineItem::create(base, Above, styles, elem.pack().span()))
}

///|
/// Resolves an over- or underbrace-like object.
///
/// It is resolved as an accent, nested inside a scripts item if there is an
/// annotation.
fn resolve_underoverspreader(
  ctx : MathResolver,
  styles : StyleChain,
  body : Content,
  annotation : Content?,
  c : Char,
  position : MathPosition,
  span : @syntax.Span,
) -> Unit raise SourceError {
  let base = ctx.resolve_into_item(body, styles)
  let accent = ctx.resolve_char(c, span, styles)
  accent.set_class(Diacritic)
  accent.set_stretch(
    Stretch::new().with_x(StretchInfo::new(Rel::one(), Em::zero())),
  )
  let base = AccentItem::create(base, accent, position, false, true, styles)
  guard annotation is Some(annotation) else {
    ctx.push(base)
    return
  }
  let base = match position {
    Below => {
      let under_styles = styles.chain(style_for_subscript(styles))
      let annotation = ctx.resolve_into_item(annotation, under_styles)
      ScriptsItem::create(
        base,
        None,
        Some(annotation),
        None,
        None,
        None,
        None,
        styles,
      )
    }
    Above => {
      let over_styles = styles.chain_one(style_for_superscript(styles))
      let annotation = ctx.resolve_into_item(annotation, over_styles)
      ScriptsItem::create(
        base,
        Some(annotation),
        None,
        None,
        None,
        None,
        None,
        styles,
      )
    }
  }
  ctx.push(base)
}
