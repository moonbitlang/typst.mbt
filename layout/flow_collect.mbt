// Port of `typst-layout/src/flow/collect.rs`.

///|
/// Collects all elements of the flow into prepared children. These are much
/// simpler to handle than the raw elements.
fn collect(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.Locator,
  base : @library.Axes[@library.Abs],
  expand : Bool,
  mode : FlowMode,
) -> Array[Child] raise @library.SourceError {
  let collector : Collector = {
    engine,
    locator: locator.split(),
    base,
    expand,
    output: [],
    par_situation: First,
  }
  collector.run(children, mode)
}

///|
/// State for collection.
priv struct Collector {
  engine : @library.Engine
  base : @library.Axes[@library.Abs]
  expand : Bool
  locator : @library.SplitLocator
  output : Array[Child]
  mut par_situation : ParSituation
}

///|
/// Perform the collection.
fn Collector::run(
  self : Collector,
  children : ArrayView[@library.Pair],
  mode : FlowMode,
) -> Array[Child] raise @library.SourceError {
  // Extract leading and trailing tags.
  let (start, end) = split_prefix_suffix(children, pair => {
    pair.0.is_(@library.tag_elem())
  })
  let inner = children[start:end]
  for pair in children[:start] {
    let elem = @library.TagElem::of(pair.0).unwrap()
    self.output.push(Tag(elem.tag()))
  }
  match mode {
    Root | Block => self.run_block(inner)
    Inline => self.run_inline(inner)
  }
  for pair in children[end:] {
    let elem = @library.TagElem::of(pair.0).unwrap()
    self.output.push(Tag(elem.tag()))
  }
  self.output
}

///|
/// Perform collection for block-level children.
fn Collector::run_block(
  self : Collector,
  children : ArrayView[@library.Pair],
) -> Unit raise @library.SourceError {
  for pair in children {
    let (child, styles) = pair
    if @library.TagElem::of(child) is Some(elem) {
      self.output.push(Tag(elem.tag()))
    } else if @library.VElem::of(child) is Some(elem) {
      self.v(elem, styles)
    } else if @library.ParElem::of(child) is Some(elem) {
      self.par(elem, styles)
    } else if @library.BlockElem::of(child) is Some(elem) {
      let alone = children.length() == 1
      self.block(elem, styles, alone)
    } else if @library.PlaceElem::of(child) is Some(elem) {
      self.place(elem, styles)
    } else if child.is_(@library.flush_elem()) {
      self.output.push(Flush)
    } else if @library.ColbreakElem::of(child) is Some(elem) {
      self.output.push(Break(elem.weak(styles)))
      self.par_situation = First
    } else if child.is_(@library.pagebreak_elem()) {
      @library.bail_at(
        child.span(),
        "pagebreaks are not allowed inside of containers",
        hints=["try using a `#colbreak()` instead"],
      )
    } else {
      self.engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          child.span(),
          "\{child.func().name()} was ignored during paged export",
        ),
      )
    }
  }
}

///|
/// Perform collection for inline-level children.
fn Collector::run_inline(
  self : Collector,
  children : ArrayView[@library.Pair],
) -> Unit raise @library.SourceError {
  // Compute the shared styles.
  let styles = @library.StyleChain::trunk_from_pairs(children).unwrap_or(
    @library.StyleChain::empty(),
  )

  // Layout the lines.
  let lines = layout_inline(
    self.engine,
    children,
    self.locator,
    styles,
    self.base,
    self.expand,
  ).into_frames()
  let leading = @library.ParElem::leading_in(styles).resolve(styles)
  self.lines(lines, leading, styles)
}

///|
/// Collect vertical spacing into a relative or fractional child.
fn Collector::v(
  self : Collector,
  elem : @library.VElem,
  styles : @library.StyleChain,
) -> Unit {
  let weakness = if elem.weak(styles) { 1 } else { 0 }
  self.output.push(
    match elem.amount() {
      Rel(rel) => Rel(rel.resolve(styles), weakness)
      Fr(fr) => Fr(fr, weakness)
    },
  )
}

///|
/// Collect a paragraph into [LineChild]ren. This already performs line
/// layout since it is not dependent on the concrete regions.
fn Collector::par(
  self : Collector,
  elem : @library.ParElem,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  let lines = layout_par(
    elem,
    self.engine,
    self.locator.next(elem.pack().span()),
    styles,
    self.base,
    self.expand,
    self.par_situation,
  ).into_frames()
  let spacing = elem.spacing(styles).resolve(styles)
  let leading = elem.leading(styles).resolve(styles)
  self.output.push(Rel(@library.Rel::from_abs(spacing), 4))
  self.lines(lines, leading, styles)
  self.output.push(Rel(@library.Rel::from_abs(spacing), 4))
  self.par_situation = Consecutive
}

///|
/// Collect laid-out lines.
fn Collector::lines(
  self : Collector,
  lines : Array[@library.Frame],
  leading : @library.Abs,
  styles : @library.StyleChain,
) -> Unit {
  let align = @library.AlignElem::alignment_in(styles).resolve(styles)
  let costs = @library.TextElem::costs_in(styles)

  // Determine whether to prevent widow and orphans.
  let len = lines.length()
  let prevent_orphans = costs.orphan().get() > 0.0 &&
    len >= 2 &&
    !lines[1].is_empty()
  let prevent_widows = costs.widow().get() > 0.0 &&
    len >= 2 &&
    !lines[len - 2].is_empty()
  let prevent_all = len == 3 && prevent_orphans && prevent_widows

  // Store the heights of lines at the edges because we'll potentially need
  // these later when `lines` is already moved.
  let height_at = (i : Int) => {
    match lines.get(i) {
      Some(frame) => frame.height()
      None => @library.Abs::zero()
    }
  }
  let front_1 = height_at(0)
  let front_2 = height_at(1)
  let back_2 = height_at(if len >= 2 { len - 2 } else { 0 })
  let back_1 = height_at(if len >= 1 { len - 1 } else { 0 })
  for i, frame in lines {
    if i > 0 {
      self.output.push(Rel(@library.Rel::from_abs(leading), 5))
    }

    // To prevent widows and orphans, we require enough space for
    // - all lines if it's just three
    // - the first two lines if we're at the first line
    // - the last two lines if we're at the second to last line
    let need = if prevent_all && i == 0 {
      front_1 + leading + front_2 + leading + back_1
    } else if prevent_orphans && i == 0 {
      front_1 + leading + front_2
    } else if prevent_widows && i >= 2 && i + 2 == len {
      back_2 + leading + back_1
    } else {
      frame.height()
    }
    self.output.push(Line({ frame, align, need, }))
  }
}

///|
/// Collect a block into a [SingleChild] or [MultiChild] depending on whether
/// it is breakable.
fn Collector::block(
  self : Collector,
  elem : @library.BlockElem,
  styles : @library.StyleChain,
  alone : Bool,
) -> Unit {
  let locator = self.locator.next(elem.pack().span())
  let align = @library.AlignElem::alignment_in(styles).resolve(styles)
  let sticky = elem.sticky(styles)
  let breakable = elem.breakable(styles)
  let fr = match elem.height(styles) {
    Fr(fr) => Some(fr)
    _ => None
  }
  let mut fallback : @library.Abs? = None
  let spacing = (amount : @library.Smart[@library.Spacing]) => {
    match amount {
      Auto => {
        let value = match fallback {
          Some(v) => v
          None => {
            let v = @library.ParElem::spacing_in(styles).resolve(styles)
            fallback = Some(v)
            v
          }
        }
        Child::Rel(@library.Rel::from_abs(value), 4)
      }
      Custom(Rel(rel)) => Child::Rel(rel.resolve(styles), 3)
      Custom(Fr(fr)) => Child::Fr(fr, 2)
    }
  }
  self.output.push(spacing(elem.above(styles)))
  if !breakable || fr is Some(_) {
    self.output.push(
      Single({
        align,
        sticky,
        alone,
        fr,
        elem,
        styles,
        locator,
        cell: CachedCell::new(),
      }),
    )
  } else {
    self.output.push(
      Multi({
        align,
        sticky,
        alone,
        elem,
        styles,
        locator,
        cell: CachedCell::new(),
      }),
    )
  }
  self.output.push(spacing(elem.below(styles)))
  self.par_situation = Other
}

///|
/// Collects a placed element into a [PlacedChild].
fn Collector::place(
  self : Collector,
  elem : @library.PlaceElem,
  styles : @library.StyleChain,
) -> Unit raise @library.SourceError {
  let alignment = elem.alignment(styles)
  let align_x : @library.FixedAlignment = match alignment {
    Auto => Center
    Custom(align) => align.x().unwrap_or(Start).resolve(styles)
  }
  let align_y : @library.Smart[@library.FixedAlignment?] = alignment.map(align => {
    align.y().map(y => y.resolve(styles))
  })
  let scope = elem.scope(styles)
  let float = elem.float(styles)
  match (float, align_y) {
    (true, Custom(None | Some(Center))) =>
      @library.bail_at(
        elem.pack().span(),
        "vertical floating placement must be `auto`, `top`, or `bottom`",
      )
    (false, Auto) =>
      @library.bail_at(
        elem.pack().span(),
        "automatic positioning is only available for floating placement",
        hints=[
          "you can enable floating placement with `place(float: true, ..)`",
        ],
      )
    _ => ()
  }
  if !float && scope == Parent {
    @library.bail_at(
      elem.pack().span(),
      "parent-scoped positioning is currently only available for floating placement",
      hints=["you can enable floating placement with `place(float: true, ..)`"],
    )
  }
  let locator = self.locator.next(elem.pack().span())
  let clearance = elem.clearance(styles).resolve(styles)
  let delta = @library.Axes::new(elem.dx(styles), elem.dy(styles)).map(rel => {
    rel.resolve(styles)
  })
  self.output.push(
    Placed({
      align_x,
      align_y,
      scope,
      float,
      clearance,
      delta,
      elem,
      styles,
      locator,
      alignment,
      cell: CachedCell::new(),
    }),
  )
}

///|
/// A prepared child in flow layout.
priv enum Child {
  /// An introspection tag.
  Tag(@library.Tag)
  /// Relative spacing with a specific weakness level.
  Rel(@library.Rel[@library.Abs], Int)
  /// Fractional spacing with a specific weakness level.
  Fr(@library.Fr, Int)
  /// An already layouted line of a paragraph.
  Line(LineChild)
  /// An unbreakable block.
  Single(SingleChild)
  /// A breakable block.
  Multi(MultiChild)
  /// An absolutely or floatingly placed element.
  Placed(PlacedChild)
  /// A place flush.
  Flush
  /// An explicit column break.
  Break(Bool)
}

///|
/// A child that encapsulates a layouted line of a paragraph.
priv struct LineChild {
  frame : @library.Frame
  align : @library.Axes[@library.FixedAlignment]
  need : @library.Abs
}

///|
/// A child that encapsulates a prepared unbreakable block.
priv struct SingleChild {
  align : @library.Axes[@library.FixedAlignment]
  sticky : Bool
  alone : Bool
  fr : @library.Fr?
  elem : @library.BlockElem
  styles : @library.StyleChain
  locator : @library.Locator
  cell : CachedCell[@library.LayoutRegion, @library.Frame]
}

///|
/// Build the child's frame given the region's base size.
fn SingleChild::layout(
  self : SingleChild,
  engine : @library.Engine,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let cached = self.cell.get_or_init(region, region_eq, region => {
    // Vertical expansion is only kept if this block is the only child.
    let region = {
      ..region,
      expand: { ..region.expand, y: region.expand.y && self.alone, },
    }
    layout_single_impl(engine, self.elem, self.locator, self.styles, region)
  })
  cached.clone()
}

///|
/// The internal implementation of [SingleChild::layout].
fn layout_single_impl(
  engine : @library.Engine,
  elem : @library.BlockElem,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link)
  let engine = engine.with_route(@library.Route::extend_(engine.route))
  layout_and_modify(styles, styles => {
    layout_single_block(elem, engine, locator, styles, region)
  })
}

///|
/// A child that encapsulates a prepared breakable block.
priv struct MultiChild {
  align : @library.Axes[@library.FixedAlignment]
  sticky : Bool
  alone : Bool
  elem : @library.BlockElem
  styles : @library.StyleChain
  locator : @library.Locator
  cell : CachedCell[@library.Regions, @library.Fragment]
}

///|
/// Build the child's frames given regions.
fn MultiChild::layout(
  self : MultiChild,
  engine : @library.Engine,
  regions : @library.Regions,
) -> (@library.Frame, MultiSpill?) raise @library.SourceError {
  let fragment = self.layout_full(engine, regions)
  let exist_non_empty_frame = fragment.iter().any(f => !f.is_empty())

  // Extract the first frame.
  let frames = fragment.into_frames()
  let frame = frames[0]

  // If there's more, return a `spill`.
  let mut spill = None
  if frames.length() > 1 {
    spill = Some({
      exist_non_empty_frame,
      multi: self,
      full: regions.full,
      first: regions.size.y,
      backlog: [],
      min_backlog_len: regions.backlog.length(),
    })
  }
  (frame, spill)
}

///|
/// The shared internal implementation of [MultiChild::layout] and
/// [MultiSpill::layout].
fn MultiChild::layout_full(
  self : MultiChild,
  engine : @library.Engine,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let cached = self.cell.get_or_init(regions, regions_eq, regions => {
    // Vertical expansion is only kept if this block is the only child.
    let regions = {
      ..regions,
      expand: { ..regions.expand, y: regions.expand.y && self.alone, },
    }
    layout_multi_impl(engine, self.elem, self.locator, self.styles, regions)
  })
  @library.Fragment::frames(cached.iter().map(f => f.clone()).collect())
}

///|
/// The internal implementation of [MultiChild::layout_full].
fn layout_multi_impl(
  engine : @library.Engine,
  elem : @library.BlockElem,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link)
  let engine = engine.with_route(@library.Route::extend_(engine.route))
  layout_and_modify(styles, styles => {
    layout_multi_block(elem, engine, locator, styles, regions)
  })
}

///|
/// The spilled remains of a `MultiChild` that broke across two regions.
priv struct MultiSpill {
  exist_non_empty_frame : Bool
  multi : MultiChild
  first : @library.Abs
  full : @library.Abs
  backlog : Array[@library.Abs]
  min_backlog_len : Int
}

///|
/// Build the spill's frames given regions.
fn MultiSpill::layout(
  self : MultiSpill,
  engine : @library.Engine,
  regions : @library.Regions,
) -> (@library.Frame, MultiSpill?) raise @library.SourceError {
  // The first region becomes unchangeable and committed to our backlog.
  let committed = self.backlog.copy()
  committed.push(regions.size.y)

  // The remaining regions are ephemeral and may be replaced.
  let backlog = committed.copy()
  backlog.append(regions.backlog.to_owned())

  // Remove unnecessary backlog items to prevent it from growing
  // unnecessarily, changing the region's hash.
  while backlog.length() > self.min_backlog_len &&
        backlog.last() == regions.last {
    backlog.pop() |> ignore
  }

  // Build the pod with the merged regions.
  let pod : @library.Regions = {
    size: @library.Axes::new(regions.size.x, self.first),
    expand: regions.expand,
    full: self.full,
    backlog: backlog[:],
    last: regions.last,
  }

  // Extract the not-yet-processed frames.
  let frames = self.multi.layout_full(engine, pod).into_frames()
  let rest = frames[committed.length():]

  // Ensure that the backlog never shrinks, so that unwrapping below is at
  // least fairly safe. Note that the whole region juggling here is
  // fundamentally not ideal: It is a compatibility layer between the old
  // (all regions provided upfront) & new (each region provided on-demand,
  // like an iterator) layout model. This approach is not 100% correct, as in
  // the old model later regions could have an effect on earlier frames, but
  // it's the best we can do for now, until the multi layouters are
  // refactored to the new model.
  let min_backlog_len = if backlog.length() > self.min_backlog_len {
    backlog.length()
  } else {
    self.min_backlog_len
  }

  // Save the first frame.
  let frame = rest[0]

  // If there's more, return a `spill`.
  let mut spill = None
  if rest.length() > 1 {
    spill = Some({ ..self, backlog: committed, min_backlog_len, })
  }
  (frame, spill)
}

///|
/// The alignment of the breakable block.
fn MultiSpill::align(
  self : MultiSpill,
) -> @library.Axes[@library.FixedAlignment] {
  self.multi.align
}

///|
/// A child that encapsulates a prepared placed element.
priv struct PlacedChild {
  align_x : @library.FixedAlignment
  align_y : @library.Smart[@library.FixedAlignment?]
  scope : @library.PlacementScope
  float : Bool
  clearance : @library.Abs
  delta : @library.Axes[@library.Rel[@library.Abs]]
  elem : @library.PlaceElem
  styles : @library.StyleChain
  locator : @library.Locator
  alignment : @library.Smart[@library.Alignment]
  cell : CachedCell[@library.Axes[@library.Abs], @library.Frame]
}

///|
/// Build the child's frame given the region's base size.
fn PlacedChild::layout(
  self : PlacedChild,
  engine : @library.Engine,
  base : @library.Axes[@library.Abs],
) -> @library.Frame raise @library.SourceError {
  let cached = self.cell.get_or_init(base, size_eq, base => {
    let align = self.alignment.unwrap_or(Both(Center, Horizon))
    let aligned = @library.Styles::from_array([
      @library.AlignElem::set_alignment(align),
    ])
    let styles = self.styles.chain(aligned)
    let frame = layout_and_modify(styles, styles => {
      layout_frame(
        engine,
        self.elem.body(),
        self.locator.relayout(),
        styles,
        @library.LayoutRegion::new(base, @library.Axes::splat(false)),
      )
    })
    if self.float {
      frame.set_parent(
        @library.FrameParent::new(self.elem.pack().location().unwrap(), Yes),
      )
    }
    frame
  })
  cached.clone()
}

///|
/// The element's location.
fn PlacedChild::location(self : PlacedChild) -> @library.Location {
  self.elem.pack().location().unwrap()
}

///|
/// Wraps a parameterized computation and caches its latest output.
///
/// - When the computation is performed multiple times consecutively with the
///   same argument, reuses the cache.
/// - When the argument changes, the new output is cached.
///
/// Upstream compares the hashes of the inputs; here they are compared with
/// a bitwise equality (so that signed zeros differ, like their hashes).
/// Cached frames are handed out as copy-on-write clones by the callers.
priv struct CachedCell[I, T] {
  mut slot : (I, Result[T, Array[@library.SourceDiagnostic]])?
}

///|
/// Create an empty cached cell.
fn[I, T] CachedCell::new() -> CachedCell[I, T] {
  { slot: None, }
}

///|
/// Perform the computation `f` with caching.
fn[I, T] CachedCell::get_or_init(
  self : CachedCell[I, T],
  input : I,
  eq : (I, I) -> Bool,
  f : (I) -> T raise @library.SourceError,
) -> T raise @library.SourceError {
  if self.slot is Some((prev, output)) && eq(prev, input) {
    match output {
      Ok(v) => return v
      Err(errors) => raise @library.SourceError(errors)
    }
  }
  let output = try f(input) catch {
    @library.SourceError(errors) => Err(errors)
  } noraise {
    v => Ok(v)
  }
  self.slot = Some((input, output))
  match output {
    Ok(v) => v
    Err(errors) => raise @library.SourceError(errors)
  }
}

///|
/// Bitwise equality of absolute lengths (upstream hashes `to_bits`).
fn abs_bits_eq(a : @library.Abs, b : @library.Abs) -> Bool {
  a.to_raw().reinterpret_as_uint64() == b.to_raw().reinterpret_as_uint64()
}

///|
fn size_eq(
  a : @library.Axes[@library.Abs],
  b : @library.Axes[@library.Abs],
) -> Bool {
  abs_bits_eq(a.x, b.x) && abs_bits_eq(a.y, b.y)
}

///|
fn region_eq(a : @library.LayoutRegion, b : @library.LayoutRegion) -> Bool {
  size_eq(a.size, b.size) && a.expand == b.expand
}

///|
fn regions_eq(a : @library.Regions, b : @library.Regions) -> Bool {
  size_eq(a.size, b.size) &&
  a.expand == b.expand &&
  abs_bits_eq(a.full, b.full) &&
  a.backlog.length() == b.backlog.length() &&
  a.backlog.iter().zip(b.backlog.iter()).all(p => abs_bits_eq(p.0, p.1)) &&
  (match (a.last, b.last) {
    (None, None) => true
    (Some(x), Some(y)) => abs_bits_eq(x, y)
    _ => false
  })
}

///|
/// Upstream `SliceExt::split_prefix_suffix`: the end of the prefix and the
/// start of the suffix of elements matching `f`.
fn[T] split_prefix_suffix(slice : ArrayView[T], f : (T) -> Bool) -> (Int, Int) {
  let len = slice.length()
  let mut start = len
  for i in 0..<len {
    if !f(slice[i]) {
      start = i
      break
    }
  }
  let mut end = start
  for i = len - 1; i >= start; i = i - 1 {
    if !f(slice[i]) {
      end = i + 1
      break
    }
  }
  (start, end)
}
