// Port of `typst-layout/src/pages/run.rs`.

///|
/// A mostly finished layout for one page. Needs only knowledge of its exact
/// page number to be finalized into a `Page`. (Because the margins can
/// depend on the page number.)
priv struct LayoutedPage {
  inner : @library.Frame
  margin : @library.Sides[@library.Abs]
  margin_two_sided : Bool
  bleed : @library.Sides[@library.Abs]
  bleed_two_sided : Bool
  binding : @library.PageBinding
  header : @library.Frame?
  footer : @library.Frame?
  background : @library.Frame?
  foreground : @library.Frame?
  fill : @library.Smart[@library.Paint?]
  numbering : @library.Numbering?
  supplement : @library.Content
}

///|
/// Layout a single page suitable for parity adjustment.
fn layout_blank_page(
  engine : @library.Engine,
  locator : @library.Locator,
  initial : @library.StyleChain,
) -> LayoutedPage raise @library.SourceError {
  let layouted = layout_page_run(engine, [][:], locator, initial)
  layouted[0]
}

///|
/// Layout a page run with uniform properties.
fn layout_page_run(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.Locator,
  initial : @library.StyleChain,
) -> Array[LayoutedPage] raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link).split()
  let engine = engine.with_route(@library.Route::extend(engine.route))

  // Determine the page-wide styles.
  let styles = @library.StyleChain::new(
    @library.Styles::root(children, initial),
  )

  // When one of the lengths is infinite the page fits its content along that
  // axis.
  let width = match @library.PageElem::width_in(styles) {
    Custom(l) => l.resolve(styles)
    Auto => @library.Abs::inf()
  }
  let height = match @library.PageElem::height_in(styles) {
    Custom(l) => l.resolve(styles)
    Auto => @library.Abs::inf()
  }
  let mut size = @library.Axes::new(width, height)
  if @library.PageElem::flipped_in(styles) {
    size = @library.Axes::new(size.y, size.x)
  }
  let mut min = width.min(height)
  if !min.is_finite() {
    min = @library.Paper::a4().width()
  }

  // Determine the margins.
  let default : @library.Rel[@library.Length] = @library.Rel::from_abs(
    @library.Length::from_abs(min.times(2.5 / 21.0)),
  )
  let margin = match @library.PageElem::margin_in(styles) {
    Custom(margin) => margin
    Auto => @library.Margin::splat(None)
  }
  let margin_two_sided = margin.two_sided.unwrap_or(false)
  let margin = margin.sides
    .map(side => {
      match side {
        Some(Custom(rel)) => rel
        _ => default
      }
    })
    .map(rel => rel.resolve(styles))
    .relative_to(size)
  let bleed = @library.PageElem::bleed_in(styles)
  let bleed_two_sided = bleed.two_sided.unwrap_or(false)
  let bleed = bleed.sides
    .map(side => side.unwrap_or(@library.Rel::zero()))
    .map(rel => rel.resolve(styles))
    .relative_to(size)
  let fill = @library.PageElem::fill_in(styles)
  let foreground = @library.PageElem::foreground_in(styles)
  let background = @library.PageElem::background_in(styles)
  let header_ascent = @library.PageElem::header_ascent_in(styles)
    .resolve(styles)
    .relative_to(margin.top)
  let footer_descent = @library.PageElem::footer_descent_in(styles)
    .resolve(styles)
    .relative_to(margin.bottom)
  let numbering = @library.PageElem::numbering_in(styles)
  let supplement = match @library.PageElem::supplement_in(styles) {
    Auto =>
      @library.TextElem::packed(@library.page_elem().local_name_in(styles))
    Custom(content) => content.unwrap_or(@library.Content::empty())
  }
  let number_align = @library.PageElem::number_align_in(styles)
  let binding : @library.PageBinding = match
    @library.PageElem::binding_in(styles) {
    Custom(binding) => binding
    Auto =>
      match @library.TextElem::dir_in(styles).resolve(styles) {
        LTR => Left
        _ => Right
      }
  }

  // Construct the numbering (for header or footer).
  let numbering_marginal = numbering.map(numbering => {
    let both = match numbering {
      Pattern(pattern) => pattern.pieces.length() >= 2
      Func(_) => true
    }
    let mut counter = @library.CounterDisplayElem::new(
      @library.Counter::new(Page),
      Custom(numbering),
      both,
    ).pack()

    // We interpret the Y alignment as selecting header or footer and then
    // ignore it for aligning the actual number.
    match number_align {
      H(x) | Both(x, _) => counter = counter.aligned(H(x))
      V(_) => ()
    }
    counter
  })
  let header = @library.PageElem::header_in(styles)
  let footer = @library.PageElem::footer_in(styles)
  let number_align_top = match number_align {
    V(Top) | Both(_, Top) => true
    _ => false
  }
  let (header, footer) = if number_align_top {
    (header.unwrap_or(numbering_marginal), footer.unwrap_or(None))
  } else {
    (header.unwrap_or(None), footer.unwrap_or(numbering_marginal))
  }

  // Layout the children.
  let area = size.sub_size(margin.sum_by_axis())
  let fragment = layout_flow(
    engine,
    children,
    locator,
    styles,
    @library.Regions::repeat(area, area.map(@library.Abs::is_finite)),
    {
      count: @library.PageElem::columns_in(styles).0.to_int(),
      balanced: @library.ColumnsElem::balanced_in(styles),
      gutter: @library.ColumnsElem::gutter_in(styles).resolve(styles),
      separator: @library.ColumnsElem::separator_in(styles),
    },
    Root,
  )

  // Layouts a single marginal.
  let layout_marginal = (
    content : @library.Content?,
    area : @library.Axes[@library.Abs],
    align : @library.Alignment,
  ) => {
    guard content is Some(content) else { return None }
    let aligned = content.aligned(align)
    Some(
      layout_frame(
        engine,
        aligned,
        locator.next(content.span()),
        styles,
        @library.LayoutRegion::new(area, @library.Axes::splat(true)),
      ),
    )
  }

  // Layout marginals.
  let layouted = []
  let header = header.map(h => h.artifact(Header))
  let footer = footer.map(f => f.artifact(Footer))
  let background = background.map(b => b.artifact(Background))
  for inner in fragment.into_frames() {
    let header_size = @library.Axes::new(
      inner.width(),
      margin.top - header_ascent,
    )
    let footer_size = @library.Axes::new(
      inner.width(),
      margin.bottom - footer_descent,
    )
    let full_size = inner
      .size()
      .add_size(margin.sum_by_axis())
      .add_size(bleed.sum_by_axis())
    let mid : @library.Alignment = Both(Center, Horizon)
    let header = layout_marginal(header, header_size, V(Bottom))
    let footer = layout_marginal(footer, footer_size, V(Top))
    let background = layout_marginal(background, full_size, mid)
    let foreground = layout_marginal(foreground, full_size, mid)
    layouted.push({
      inner,
      fill,
      numbering,
      supplement,
      header,
      footer,
      background,
      foreground,
      margin,
      margin_two_sided,
      bleed,
      bleed_two_sided,
      binding,
    })
  }
  layouted
}
