// Port of `typst-layout/src/flow/mod.rs`.
//
// Layout of content into a [Frame] or [Fragment].
//
// Upstream memoizes `layout_fragment_impl` with comemo; here it is always
// computed, but the locator link across the (former) memoization boundary
// is kept since it determines the locations.

///|
/// Lays out content into a single region, producing a single frame.
pub fn layout_frame(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  layout_fragment(
    engine,
    content,
    locator,
    styles,
    @library.Regions::from_region(region),
  ).into_frame()
}

///|
/// Lays out content into multiple regions.
///
/// When laying out into just one region, prefer [layout_frame].
pub fn layout_fragment(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  layout_fragment_impl(engine, content, locator, styles, regions, {
    count: 1,
    balanced: false,
    gutter: @library.Rel::zero(),
    separator: None,
  })
}

///|
/// Layout the columns.
///
/// This is different from just laying out into column-sized regions as the
/// columns can interact due to parent-scoped placed elements.
pub fn layout_columns(
  elem : @library.ColumnsElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  layout_fragment_impl(engine, elem.body(), locator, styles, regions, {
    count: elem.count(styles).0.to_int(),
    balanced: elem.balanced(styles),
    gutter: elem.gutter(styles).resolve(styles),
    separator: elem.separator(styles),
  })
}

///|
/// The internal implementation of [layout_fragment] (memoized like
/// upstream's `#[comemo::memoize]`; see `library/memo.mbt`).
fn layout_fragment_impl(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
  column : ColumnOptions,
) -> @library.Fragment raise @library.SourceError {
  if !@library.layout_memo_active() {
    return layout_fragment_compute(
      engine, content, locator, styles, regions, column,
    )
  }
  let key = @library.memo_fingerprint(state => {
    state.write_str("layout_fragment")
    state.write(content)
    state.write_u128(styles.memo_hash())
    state.write_f64(regions.size.x.to_raw())
    state.write_f64(regions.size.y.to_raw())
    state.write_bool(regions.expand.x)
    state.write_bool(regions.expand.y)
    state.write_f64(regions.full.to_raw())
    state.write_usize(regions.backlog.length())
    for height in regions.backlog {
      state.write_f64(height.to_raw())
    }
    match regions.last {
      Some(last) => {
        state.write_discriminant(1)
        state.write_f64(last.to_raw())
      }
      None => state.write_discriminant(0)
    }
    state.write_usize(column.count)
    state.write_bool(column.balanced)
    state.write_f64(column.gutter.rel.get())
    state.write_f64(column.gutter.abs.to_raw())
    state.write(column.separator)
    state.write_u128(locator.memo_hash())
    state.write_u128(engine.route.memo_hash())
  })
  guard key is Some(key) else {
    return layout_fragment_compute(
      engine, content, locator, styles, regions, column,
    )
  }
  @library.memoized_layout(engine, key, engine => {
    layout_fragment_compute(engine, content, locator, styles, regions, column)
  })
}

///|
/// The uncached body of [layout_fragment_impl].
fn layout_fragment_compute(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
  column : ColumnOptions,
) -> @library.Fragment raise @library.SourceError {
  if !regions.size.x.is_finite() && regions.expand.x {
    @library.bail_at(content.span(), "cannot expand into infinite width")
  }
  if !regions.size.y.is_finite() && regions.expand.y {
    @library.bail_at(content.span(), "cannot expand into infinite height")
  }
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link).split()
  let engine = engine.with_route(@library.Route::extend(engine.route))
  @library.at(content.span(), () => engine.route.check_layout_depth())
  let kind = Ref::new(@library.FragmentKind::Block)
  let children = (engine.library.routines.realize)(
    Fragment(kind~),
    engine,
    locator,
    content,
    styles,
  )
  layout_flow(
    engine,
    children[:],
    locator,
    styles,
    regions,
    column,
    FlowMode::from_kind(kind.val),
  )
}

///|
/// The mode a flow can be laid out in.
pub(all) enum FlowMode {
  /// A root flow with block-level elements. Like `FlowMode::Block`, but can
  /// additionally host footnotes and line numbers.
  Root
  /// A flow whose children are block-level elements.
  Block
  /// A flow whose children are inline-level elements.
  Inline
} derive(Eq, Debug)

///|
/// Upstream `From<FragmentKind> for FlowMode`.
pub fn FlowMode::from_kind(value : @library.FragmentKind) -> FlowMode {
  match value {
    Inline => Inline
    Block => Block
  }
}

///|
/// Lays out realized content into regions, potentially with columns.
pub fn layout_flow(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.SplitLocator,
  shared : @library.StyleChain,
  regions : @library.Regions,
  column : ColumnOptions,
  mode : FlowMode,
) -> @library.Fragment raise @library.SourceError {
  // Prepare configuration that is shared across the whole flow.
  let config = configuration(shared, regions, column, mode)

  // Collect the elements into pre-processed children. These are much easier
  // to handle than the raw elements.
  let children = collect(
    engine,
    children,
    locator.next(()),
    @library.Axes::new(config.columns.width, regions.full),
    regions.expand.x,
    mode,
  )
  let work = Work::new(children)
  let finished = []
  let mut regions = regions

  // This loop runs once per region produced by the flow layout.
  while true {
    let frame = compose(engine, work, config, locator.next(()), regions)
    finished.push(frame)

    // Terminate the loop when everything is processed, though draining the
    // backlog if necessary.
    if work.done() && (!regions.expand.y || regions.backlog.is_empty()) {
      break
    }
    regions = regions.next()
  }
  @library.Fragment::frames(finished)
}

///|
/// Determine the flow's configuration.
fn configuration(
  shared : @library.StyleChain,
  regions : @library.Regions,
  column : ColumnOptions,
  mode : FlowMode,
) -> Config {
  let columns : ColumnConfig = {
    let mut count = column.count
    if !regions.size.x.is_finite() {
      count = 1
    }
    let gutter = column.gutter.relative_to(regions.base().x)
    let width = (regions.size.x - gutter.times((count - 1).to_double())).div_by(
      count.to_double(),
    )
    let dir = @library.TextElem::dir_in(shared).resolve(shared)
    {
      count,
      width,
      gutter,
      dir,
      balanced: column.balanced,
      separator: column.separator.map(separator => {
        separator
        .styled(@library.LineElem::set_length(@library.Rel::one()))
        .styled(@library.LineElem::set_angle(@library.Angle::deg(90.0)))
        .aligned(Both(Center, Horizon))
      }),
    }
  }
  let footnote : FootnoteConfig = {
    separator: @library.FootnoteEntry::separator_in(shared).artifact(Other),
    clearance: @library.FootnoteEntry::clearance_in(shared).resolve(shared),
    gap: @library.FootnoteEntry::gap_in(shared).resolve(shared),
    expand: regions.expand.x,
  }
  let line_numbers = if mode == Root {
    Some({
      scope: @library.ParLine::numbering_scope_in(shared),
      default_clearance: {
        let width = if @library.PageElem::flipped_in(shared) {
          @library.PageElem::height_in(shared).map(l => l.resolve(shared))
        } else {
          @library.PageElem::width_in(shared).map(l => l.resolve(shared))
        }

        // Clamp below is safe (min <= max): if the font size is negative, we
        // set min = max = 0; otherwise, `0.75 * size <= 2.5 * size` for zero
        // and positive sizes.
        width
        .unwrap_or(@library.Abs::zero())
        .times(0.026)
        .clamp(
          @library.Em::new(0.75).resolve(shared).max(@library.Abs::zero()),
          @library.Em::new(2.5).resolve(shared).max(@library.Abs::zero()),
        )
      },
    })
  } else {
    None
  }
  { mode, shared, columns, footnote, line_numbers, }
}

///|
/// The work that is left to do by flow layout.
priv struct Work {
  /// Children that we haven't processed yet. The `children[pos:]` slice
  /// shrinks over time.
  children : Array[Child]
  mut pos : Int
  /// Leftovers from a breakable block.
  mut spill : MultiSpill?
  /// Queued floats that didn't fit in previous regions.
  mut floats : Array[PlacedChild]
  /// Queued footnotes that didn't fit in previous regions.
  mut footnotes : Array[@library.FootnoteElem]
  /// Spilled frames of a footnote that didn't fully fit. Similar to `spill`.
  mut footnote_spill : Array[@library.Frame]?
  /// Queued tags that will be attached to the next frame.
  mut tags : Array[@library.Tag]
  /// Identifies floats and footnotes that can be skipped if visited because
  /// they were already handled and incorporated as column or page level
  /// insertions. (Shared between clones; replaced on extension.)
  mut skips : @hashset.HashSet[@library.Location]
}

///|
/// Create the initial work state from a list of children.
fn Work::new(children : Array[Child]) -> Work {
  {
    children,
    pos: 0,
    spill: None,
    floats: [],
    footnotes: [],
    footnote_spill: None,
    tags: [],
    skips: @hashset.HashSet::new(),
  }
}

///|
/// A copy of the work state (upstream `Clone`).
fn Work::clone(self : Work) -> Work {
  {
    children: self.children,
    pos: self.pos,
    spill: self.spill,
    floats: self.floats.copy(),
    footnotes: self.footnotes.copy(),
    footnote_spill: self.footnote_spill.map(frames => frames.map(f => f.clone())),
    tags: self.tags.copy(),
    skips: self.skips,
  }
}

///|
/// Restore the state from a checkpoint (upstream `*work = checkpoint`).
fn Work::restore(self : Work, other : Work) -> Unit {
  self.pos = other.pos
  self.spill = other.spill
  self.floats = other.floats
  self.footnotes = other.footnotes
  self.footnote_spill = other.footnote_spill
  self.tags = other.tags
  self.skips = other.skips
}

///|
/// Get the first unprocessed child, from the start of the slice.
fn Work::head(self : Work) -> Child? {
  self.children.get(self.pos)
}

///|
/// Mark the `head()` child as processed, advancing the slice by one.
fn Work::advance(self : Work) -> Unit {
  self.pos += 1
}

///|
/// Whether all work is done. This means we can terminate flow layout.
fn Work::done(self : Work) -> Bool {
  self.pos >= self.children.length() &&
  self.spill is None &&
  self.floats.is_empty() &&
  self.footnote_spill is None &&
  self.footnotes.is_empty()
}

///|
/// Add skipped floats and footnotes from the insertion areas to the skip
/// set.
fn Work::extend_skips(self : Work, skips : Array[@library.Location]) -> Unit {
  if !skips.is_empty() {
    let set = @hashset.HashSet::new()
    for loc in self.skips {
      set.add(loc)
    }
    for loc in skips {
      set.add(loc)
    }
    self.skips = set
  }
}

///|
/// Options defining the column layout.
pub(all) struct ColumnOptions {
  /// The number of columns.
  count : Int
  /// Whether column heights are to be equalized.
  balanced : Bool
  /// The spacing between columns.
  gutter : @library.Rel[@library.Abs]
  /// The separator between columns.
  separator : @library.Content?
}

///|
/// Shared configuration for the whole flow.
priv struct Config {
  /// Whether this is the root flow, which can host footnotes and line
  /// numbers.
  mode : FlowMode
  /// The styles shared by the whole flow. This is used for footnotes and
  /// line numbers.
  shared : @library.StyleChain
  /// Settings for columns.
  columns : ColumnConfig
  /// Settings for footnotes.
  footnote : FootnoteConfig
  /// Settings for line numbers.
  line_numbers : LineNumberConfig?
}

///|
/// Configuration of footnotes.
priv struct FootnoteConfig {
  /// The separator between flow content and footnotes. Typically a line.
  separator : @library.Content
  /// The amount of space left above the separator.
  clearance : @library.Abs
  /// The gap between footnote entries.
  gap : @library.Abs
  /// Whether horizontal expansion is enabled for footnotes.
  expand : Bool
}

///|
/// Configuration of columns.
priv struct ColumnConfig {
  /// The number of columns.
  count : Int
  /// The width of each column.
  width : @library.Abs
  /// The amount of space between columns.
  gutter : @library.Abs
  /// The horizontal direction in which columns progress. Defined by
  /// `text.dir`.
  dir : @library.Dir
  /// Whether to equalize the height of columns by breaking columns early.
  balanced : Bool
  /// The separator between columns.
  separator : @library.Content?
}

///|
/// Configuration of line numbers.
priv struct LineNumberConfig {
  /// Where line numbers are reset.
  scope : @library.LineNumberingScope
  /// The default clearance for `auto`.
  ///
  /// This value should be relative to the page's width, such that the
  /// clearance between line numbers and text is small when the page is,
  /// itself, small. However, that could cause the clearance to be too small
  /// or too large when considering the current text size; in particular, a
  /// larger text size would require more clearance to be able to tell line
  /// numbers apart from text, whereas a smaller text size requires less
  /// clearance so they aren't way too far apart. Therefore, the default
  /// value is a percentage of the page width clamped between `0.75em` and
  /// `2.5em`.
  default_clearance : @library.Abs
}
