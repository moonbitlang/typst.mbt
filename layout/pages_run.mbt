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
  layout_page_run_impl(engine, children, locator, initial)
}

///|
/// The kept page runs ([layout_page_run_impl]).
let page_run_memo : @library.PageMemo[Array[LayoutedPage]] = @library.PageMemo::new(
  "layout of a page run",
)

///|
/// How many page runs were answered by a kept layout and how many were
/// laid out since the process started (for tests and measurements, like
/// `@library.closure_memo_stats`).
pub fn page_run_memo_stats() -> (Int, Int) {
  page_run_memo.stats()
}

///|
/// The number of page runs that are kept (for tests and measurements).
pub fn page_run_memo_entries() -> Int {
  page_run_memo.entries()
}

///|
/// The internal implementation of `layout_page_run` (memoized like
/// upstream's `#[comemo::memoize]`, `typst-layout/src/pages/run.rs:78`;
/// see `library/memo_pages.mbt`).
///
/// Upstream hashes the library, the children and the initial styles, and
/// tracks the world, the introspector, the traced span, the sink (mutably),
/// the route and the locator. Here the children and the initial styles
/// are the key, with the resolved locator and the route (which the keys of
/// all layouts hold in full, `library/memo.mbt`) and the traced span; the
/// library is compared, the world and the introspector are tracked, and
/// the sink is replayed.
fn layout_page_run_impl(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.Locator,
  initial : @library.StyleChain,
) -> Array[LayoutedPage] raise @library.SourceError {
  if !@library.layout_memo_active() {
    return layout_page_run_compute(engine, children, locator, initial)
  }
  let key = @library.memo_fingerprint(state => {
    state.write_str("layout_page_run")
    state.write_usize(children.length())
    for i in 0..<children.length() {
      let (child, styles) = children[i]
      state.write(child)
      state.write_u128(styles.memo_hash())
    }
    state.write_u128(initial.memo_hash())
    state.write_u128(locator.memo_hash())
    state.write_u128(engine.route.memo_hash())
  })
  @library.memoized_pages(
    page_run_memo,
    engine,
    key,
    None,
    children,
    initial,
    copy_layouted_pages,
    layouted_pages_cacheable,
    engine => layout_page_run_compute(engine, children, locator, initial),
  )
}

///|
/// The pages of a run as an entry keeps them and as it hands them out:
/// other objects with copy-on-write clones of the frames, which
/// `finalize_page` moves into the frame of the page (upstream:
/// `Vec<LayoutedPage>: Clone`, with frames whose items are shared).
fn copy_layouted_pages(pages : Array[LayoutedPage]) -> Array[LayoutedPage] {
  pages.map(LayoutedPage::kept)
}

///|
/// The page with clones of its frames (see [copy_layouted_pages]).
fn LayoutedPage::kept(self : LayoutedPage) -> LayoutedPage {
  {
    ..self,
    inner: self.inner.clone(),
    header: clone_frame(self.header),
    footer: clone_frame(self.footer),
    background: clone_frame(self.background),
    foreground: clone_frame(self.foreground),
  }
}

///|
fn clone_frame(frame : @library.Frame?) -> @library.Frame? {
  match frame {
    Some(frame) => Some(frame.clone())
    None => None
  }
}

///|
/// Whether the pages of a run may be kept: no frame of them holds a host
/// closure in its tags or in the frame of a tiling, nor does the fill
/// (`@library.frame_cacheable`, the rule of every kept layout).
fn layouted_pages_cacheable(pages : Array[LayoutedPage]) -> Bool {
  for page in pages {
    if !@library.frame_cacheable(page.inner) ||
      !frame_option_cacheable(page.header) ||
      !frame_option_cacheable(page.footer) ||
      !frame_option_cacheable(page.background) ||
      !frame_option_cacheable(page.foreground) ||
      !fill_cacheable(page.fill) {
      return false
    }
  }
  true
}

///|
fn frame_option_cacheable(frame : @library.Frame?) -> Bool {
  match frame {
    Some(frame) => @library.frame_cacheable(frame)
    None => true
  }
}

///|
/// Whether the fill of a page may be kept (see [layouted_pages_cacheable]).
fn fill_cacheable(fill : @library.Smart[@library.Paint?]) -> Bool {
  match fill {
    Custom(Some(paint)) => @library.paint_cacheable(paint)
    _ => true
  }
}

///|
/// The uncached body of [layout_page_run_impl].
fn layout_page_run_compute(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.Locator,
  initial : @library.StyleChain,
) -> Array[LayoutedPage] raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link).split()
  let engine = engine.with_route(@library.Route::extend_(engine.route))

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
