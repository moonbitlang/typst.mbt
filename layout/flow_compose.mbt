// Port of `typst-layout/src/flow/compose.rs`.
//
// Upstream models the control flow events of composition and distribution
// with the result types `RelayoutStop<R>`, `InsertionStop<R, M>` and the
// distributor's `Stop`. Here they are raised as a single error type,
// [FlowStop], next to the fatal `SourceError`:
//
// - `RelayoutStop::Relayout(scope)`, `InsertionStop::Relayout(scope)` and
//   `Stop::Relayout(scope)` are `FlowStop::Relayout(scope)` (the statically
//   known `ParentScope`/`ColumnScope` become `Parent`/`Column`).
// - `InsertionStop::MigrateOrigin(())` is `FlowStop::MigrateOrigin`. It is
//   only raised when migration is allowed ([Migration] set to `ALLOW`); the
//   distributor converts it into `Stop::Finish(Finish::Soft)`.
// - `Stop::Finish(finish)` is `FlowStop::Finish(forced)` and never leaves
//   distribution.

///|
/// A control flow event during composition and distribution.
priv suberror FlowStop {
  /// Indicates that the given scope should be relayouted.
  Relayout(@library.PlacementScope)
  /// The footnote did not fit with its origin frame.
  MigrateOrigin
  /// Indicates that the current subregion should be finished, either due to
  /// a lack of space (`false`, upstream `Finish::Soft`) or due to an
  /// explicit break (`true`, upstream `Finish::Forced`).
  Finish(Bool)
}

///|
/// Whether a footnote's origin frame may migrate to the next region
/// (upstream `Migration<M>`; `ALLOW` is `Migration(Some(()))`, `FORBID` is
/// `Migration(None)`).
priv struct Migration {
  mut allowed : Bool
}

///|
/// Allow the origin frame to migrate.
fn Migration::allow() -> Migration {
  { allowed: true, }
}

///|
/// Forbid the origin frame from migrating.
fn Migration::forbid_() -> Migration {
  { allowed: false, }
}

///|
/// Forbid the origin frame from migrating.
fn Migration::forbid(self : Migration) -> Unit {
  self.allowed = false
}

///|
/// Disable migration and return the previous setting.
fn Migration::take(self : Migration) -> Migration {
  let prev = { allowed: self.allowed, }
  self.allowed = false
  prev
}

///|
/// Composes the contents of a single page/region. A region can have multiple
/// columns/subregions.
///
/// The composer is primarily concerned with layout of out-of-flow insertions
/// (floats and footnotes). It does this in per-page and per-column loops
/// that rerun when an insertion affects the regions available to the
/// distributor, or when balancing columns.
///
/// To lay out the in-flow contents of individual subregions, the composer
/// invokes [distribution](distribute()).
fn compose(
  engine : @library.Engine,
  work : Work,
  config : Config,
  locator : @library.Locator,
  regions : @library.Regions,
) -> @library.Frame raise @library.SourceError {
  let composer : Composer = {
    engine,
    config,
    page_base: regions.base(),
    column: 0,
    page_insertions: Insertions::new(),
    column_insertions: Insertions::new(),
    column_balancing_height: None,
    work,
    footnote_spill: None,
    footnote_queue: [],
  }
  composer.page(locator, regions)
}

///|
/// State for composition.
priv struct Composer {
  engine : @library.Engine
  work : Work
  config : Config
  mut column : Int
  page_base : @library.Axes[@library.Abs]
  page_insertions : Insertions
  mut column_insertions : Insertions
  mut column_balancing_height : @library.Abs?
  // These are here because they have to survive relayout (we could lose the
  // footnotes otherwise). For floats, we revisit them anyway, so it's okay
  // to use `work.floats` directly. This is not super clean; probably there's
  // a better way.
  mut footnote_spill : Array[@library.Frame]?
  mut footnote_queue : Array[@library.FootnoteElem]
}

///|
/// Lay out a container/page region, including container/page insertions.
fn Composer::page(
  self : Composer,
  locator : @library.Locator,
  regions : @library.Regions,
) -> @library.Frame raise @library.SourceError {
  // This loop can restart region layout when requested to do so by a
  // `RelayoutStop::Relayout(ParentScope)`. This happens when there is a
  // parent-scoped float or when balancing columns.
  let checkpoint = self.work.clone()
  let mut output = None
  while output is None {
    // Shrink the available space by the space used by page insertions.
    let pod = {
      ..regions,
      size: {
        ..regions.size,
        y: regions.size.y - self.page_insertions.height(),
      },
    }
    try self.page_contents(locator.relayout(), pod) catch {
      Relayout(Parent) => self.work.restore(checkpoint.clone())
      @library.SourceError(_) as err => raise err
      err => abort("unexpected flow stop in page: \{err}")
    } noraise {
      frame => output = Some(frame)
    }
  }
  let output = output.unwrap()
  self.page_insertions.finalize(self.work, self.config, output, None)
}

///|
/// Lay out the inner contents of a container/page.
///
/// Raises `FlowStop::Relayout(Parent)` (upstream
/// `RelayoutStop<ParentScope>`) or a `SourceError`.
fn Composer::page_contents(
  self : Composer,
  locator : @library.Locator,
  regions : @library.Regions,
) -> @library.Frame raise {
  // No point in create column regions, if there's just one!
  if self.config.columns.count == 1 {
    return self.column(locator, regions).0
  }

  // Create a backlog for multi-column layout.
  let column_height = regions.size.y
  let backlog = []
  let mut skip = true
  let heights = [column_height]
  heights.append(regions.backlog.to_array())
  for h in heights {
    for _ in 0..<self.config.columns.count {
      if skip {
        skip = false
        continue
      }
      backlog.push(h)
    }
  }

  // Subregions for column layout.
  let mut inner : @library.Regions = {
    ..regions,
    size: @library.Axes::new(self.config.columns.width, column_height),
    backlog: backlog[:],
    expand: @library.Axes::new(true, regions.expand.y),
  }

  // The size of the merged frame hosting multiple columns.
  let size = @library.Axes::new(
    regions.size.x,
    if regions.expand.y {
      regions.size.y
    } else {
      @library.Abs::zero()
    },
  )
  let output = @library.Frame::hard(size)
  let mut offset = @library.Abs::zero()
  let locator = locator.split()
  let mut total_used_height = @library.Abs::zero()
  let mut last_column_separator_height = None

  // Lay out the columns and stitch them together.
  for i in 0..<self.config.columns.count {
    self.column = i
    let (frame, used_height, column_separator_height) = self.column(
      locator.next(()),
      inner,
    )
    total_used_height = total_used_height + used_height
    if !regions.expand.y {
      output.set_size({
        ..output.size(),
        y: output.size().y.max(frame.height()),
      })
    }

    // Column separator between this and the previous column.
    if self.config.columns.separator is Some(separator) &&
      last_column_separator_height is Some(last_separator_height) &&
      !column_separator_height.min(last_separator_height).is_zero() {
      let mid = offset + self.config.columns.gutter.times(0.5)
      let x = if self.config.columns.dir == LTR {
        mid
      } else {
        regions.size.x - mid
      }
      let height = column_separator_height.max(last_separator_height)
      let frame = layout_column_separator(
        self.engine,
        separator,
        self.config,
        @library.Axes::new(self.config.columns.gutter, height),
      )
      output.prepend_frame(
        // Prepend so it's behind both adjacent columns.
        @library.Point::with_x(x - frame.width().times(0.5)),
        frame,
      )
    }
    last_column_separator_height = Some(column_separator_height)
    if i > 0 {
      offset = offset + self.config.columns.gutter
    }
    let width = frame.width()
    let x = if self.config.columns.dir == LTR {
      offset
    } else {
      regions.size.x - offset - width
    }
    offset = offset + width

    // During distribution, the baseline of the region is set to the
    // baseline of the first frame - e.g., the first paragraph line. However,
    // this does not propagate outwards unless we also update the baseline of
    // the column that region is in.
    if i == 0 && frame.has_baseline() {
      output.set_baseline(frame.baseline())
    }
    output.push_frame(@library.Point::with_x(x), frame)
    inner = inner.next()
  }

  // Column balancing with re-layout
  if self.config.columns.balanced && self.work.done() {
    let height = total_used_height.div_by(self.config.columns.count.to_double())
    let below = match self.column_balancing_height {
      None => true
      Some(h) => h.to_raw() < height.to_raw()
    }
    if below {
      self.column_balancing_height = Some(height)
      raise Relayout(Parent)
    }
  }
  output
}

///|
/// Lay out a column, including column insertions.
///
/// On success, returns a tuple of
/// - `0`: The laid out frame.
/// - `1`: The height actually used by the inner contents (used for column
///   balancing logic).
/// - `2`: The height the column separator (if any) should have.
///
/// Raises `FlowStop::Relayout(Parent)` or a `SourceError`.
fn Composer::column(
  self : Composer,
  locator : @library.Locator,
  regions : @library.Regions,
) -> (@library.Frame, @library.Abs, @library.Abs) raise {
  // Reset column insertion when starting a new column.
  self.column_insertions = Insertions::new()

  // Process footnote spill.
  if self.work.footnote_spill is Some(spill) {
    self.work.footnote_spill = None
    self.footnote_spill(spill, regions.base())
  }

  // This loop can restart column layout when requested to do so by a
  // `RelayoutStop::Relayout(PlacementScope::Column)`. This happens when a
  // column-scoped float or footnote is added.
  let checkpoint = self.work.clone()
  let mut result = None
  while result is None {
    // Shrink the available space by the space used by column insertions.
    let pod = {
      ..regions,
      size: {
        ..regions.size,
        y: regions.size.y - self.column_insertions.height(),
      },
    }

    // For column balancing, only consider space taken by floats, not
    // footnotes
    let float_height = self.column_insertions.float_height()
    let balancing_target = if self.column < self.config.columns.count - 1 {
      self.column_balancing_height.map(h => h - float_height)
    } else {
      None
    }
    try self.column_contents(pod, balancing_target) catch {
      Relayout(Column) => self.work.restore(checkpoint.clone())
      err => raise err
    } noraise {
      (frame, used_height) => result = Some((frame, used_height + float_height))
    }
  }
  let (inner, used_height) = result.unwrap()
  let column_separator_height = if self.column_insertions.bottom_floats.is_empty() {
    used_height
  } else {
    self.column_balancing_height.unwrap_or(
      inner.height() + self.column_insertions.float_height(),
    )
  }
  self.work.footnotes.append(self.footnote_queue)
  self.footnote_queue = []
  if self.footnote_spill is Some(spill) {
    self.footnote_spill = None
    self.work.footnote_spill = Some(spill)
  }
  let insertions = self.column_insertions
  self.column_insertions = Insertions::new()
  let output = insertions.finalize(
    self.work,
    self.config,
    inner,
    self.column_balancing_height,
  )

  // Lay out per-column line numbers.
  if self.config.line_numbers is Some(line_config) {
    layout_line_numbers(
      self.engine,
      self.config,
      line_config,
      locator,
      self.column,
      output,
    )
  }
  (output, used_height, column_separator_height)
}

///|
/// Lay out the inner contents of a column.
///
/// Pending floats and footnotes are also laid out at this step. For those,
/// however, we forbid footnote migration (moving the frame containing the
/// footnote reference if the corresponding entry doesn't fit), allowing the
/// footnote invariant to be broken, as it would require handling a
/// [`FootnoteStop::MigrateOrigin`] at this point, but that is exclusively
/// handled by the distributor.
fn Composer::column_contents(
  self : Composer,
  regions : @library.Regions,
  balancing_target : @library.Abs?,
) -> (@library.Frame, @library.Abs) raise {
  // Process pending footnotes.
  let footnotes = self.work.footnotes
  self.work.footnotes = []
  for note in footnotes {
    self.footnote(
      note,
      Ref::new(regions),
      @library.Abs::zero(),
      Migration::forbid_(),
    )
  }

  // Process pending floats.
  let floats = self.work.floats
  self.work.floats = []
  for placed in floats {
    self.float(placed, regions, false, Migration::forbid_())
  }
  distribute(self, regions, balancing_target)
}

///|
/// Lays out an item with floating placement.
///
/// This is called from within [`distribute()`]. When the float fits, this
/// raises a `FlowStop::Relayout(..)`, which bubbles all the way through
/// distribution and is handled in [Composer::page] or [Composer::column]
/// (depending on `placed.scope`).
///
/// When the float does not fit, it is queued into `work.floats`. The value
/// of `clearance` indicates that between the float and flow content is
/// needed --- it is set if there are already distributed items.
///
/// The value of `migration` determines whether footnotes within the float
/// should be allowed to prompt its migration if they don't fit in order to
/// respect the footnote invariant (entries in the same page as the
/// references), triggering `FlowStop::MigrateOrigin`. This is usually
/// allowed within the distributor, as it can handle that particular flow
/// event, and forbidden elsewhere.
fn Composer::float(
  self : Composer,
  placed : PlacedChild,
  regions : @library.Regions,
  clearance : Bool,
  migration : Migration,
) -> Unit raise {
  // If the float is already processed, skip it.
  let loc = placed.location()
  if self.skipped(loc) {
    return
  }

  // If there is already a queued float, queue this one as well. We don't
  // want to disrupt the order.
  if !self.work.floats.is_empty() {
    self.work.floats.push(placed)
    return
  }

  // Determine the base size of the chosen scope.
  let base = match placed.scope {
    Column => regions.base()
    Parent => self.page_base
  }

  // Lay out the placed element.
  let frame = placed.layout(self.engine, base)

  // Determine the remaining space in the scope. This is exact for column
  // placement, but only an approximation for page placement.
  let remaining = match placed.scope {
    Column => regions.size.y
    Parent => {
      let remaining = @library.Abs::sum(
        regions
        .iter()
        .map(size => size.y)
        .take(self.config.columns.count - self.column),
      )
      remaining.div_by(self.config.columns.count.to_double())
    }
  }

  // We only require clearance if there is other content.
  let clearance = if clearance {
    placed.clearance
  } else {
    @library.Abs::zero()
  }
  let need = frame.height() + clearance

  // If the float doesn't fit, queue it for the next region.
  if !remaining.fits(need) && regions.may_progress() {
    self.work.floats.push(placed)
    return
  }

  // Handle footnotes in the float.
  self.footnotes(regions, frame, need, false, migration)

  // Determine the float's vertical alignment. We can unwrap the inner
  // `Option` because `Custom(None)` is checked for during collection.
  let align_y : @library.FixedAlignment = match placed.align_y {
    Custom(align) => align.unwrap()
    Auto => {
      // When the float's vertical midpoint would be above the middle of the
      // page if it were layouted in-flow, we use top alignment. Otherwise,
      // we use bottom alignment.
      let used = base.y - remaining
      let half = need.div_by(2.0)
      let ratio = (used + half).ratio_to(base.y)
      if ratio <= 0.5 {
        Start
      } else {
        End
      }
    }
  }

  // Select the insertion area where we'll put this float.
  let area = match placed.scope {
    Column => self.column_insertions
    Parent => self.page_insertions
  }

  // Put the float there.
  area.push_float(placed, frame, align_y)
  area.skips.push(loc)

  // Trigger relayout.
  raise Relayout(placed.scope)
}

///|
/// Lays out footnotes in the `frame` if this is the root flow and there are
/// any. The value of `breakable` indicates whether the element that produced
/// the frame is breakable. If not, the frame is treated as atomic.
///
/// The value of `migration` indicates whether footnote migration should be
/// possible (at least for the first footnote found in the frame, as it is
/// forbidden for the second footnote onwards). It is usually allowed within
/// the distributor and forbidden elsewhere, as the distributor can handle
/// `FlowStop::MigrateOrigin` which is raised when migration is requested.
fn Composer::footnotes(
  self : Composer,
  regions : @library.Regions,
  frame : @library.Frame,
  flow_need : @library.Abs,
  breakable : Bool,
  migration : Migration,
) -> Unit raise {
  // Footnotes are only supported at the root level.
  if self.config.mode != Root {
    return
  }

  // Search for footnotes.
  let notes : Array[(@library.Abs, @library.FootnoteElem)] = []
  for tag in self.work.tags {
    guard tag is Start(elem, _) else { continue }
    guard @library.FootnoteElem::of(elem) is Some(note) else { continue }
    notes.push((@library.Abs::zero(), note))
  }
  find_in_frame_impl(
    notes,
    frame,
    @library.Abs::zero(),
    @library.FootnoteElem::of,
  )
  if notes.is_empty() {
    return
  }
  let mut relayout = false
  let regions = Ref::new(regions)
  let migration = { allowed: migration.allowed, }

  // The first footnote's origin frame should be migratable if the region may
  // progress (already checked by the footnote function) and if the origin
  // frame isn't breakable (checked here).
  if breakable {
    migration.forbid()
  }
  for note in notes {
    let (y, elem) = note
    // The amount of space used by the in-flow content that contains the
    // footnote marker. For a breakable frame, it's the y position of the
    // marker. For an unbreakable frame, it's the full height.
    let flow_need = if breakable { y } else { flow_need }

    // We only migrate the origin frame if the first footnote's first line
    // didn't fit.
    let migration = migration.take()

    // Process the footnote.
    self.footnote(elem, regions, flow_need, migration) catch {
      // First handle more footnotes before relayouting.
      Relayout(Column) => relayout = true
      // Either of
      // - A `FootnoteStop::MigrateOrigin` indicating that the frame's origin
      //   element should migrate to uphold the footnote invariant.
      // - A fatal error.
      err => raise err
    }
  }

  // If this is set, we laid out at least one footnote, so we need a
  // relayout.
  if relayout {
    raise Relayout(Column)
  }
}

///|
/// Handles a single footnote.
fn Composer::footnote(
  self : Composer,
  elem : @library.FootnoteElem,
  regions : Ref[@library.Regions],
  flow_need : @library.Abs,
  migration : Migration,
) -> Unit raise {
  // Ignore reference footnotes and already processed ones.
  let loc = elem.pack().location().unwrap()
  if elem.is_ref() || self.skipped(loc) {
    return
  }

  // If there is already a queued spill or footnote, queue this one as well.
  // We don't want to disrupt the order.
  let area = self.column_insertions
  if self.footnote_spill is Some(_) || !self.footnote_queue.is_empty() {
    self.footnote_queue.push(elem)
    return
  }

  // If there weren't any footnotes so far, account for the footnote
  // separator.
  let mut separator = None
  let mut separator_need = @library.Abs::zero()
  if area.footnotes.is_empty() {
    let frame = layout_footnote_separator(
      self.engine,
      self.config,
      regions.val.base(),
    )
    separator_need = separator_need +
      self.config.footnote.clearance +
      frame.height()
    separator = Some(frame)
  }

  // Prepare regions for the footnote.
  let r = regions.val
  let pod = {
    ..r,
    expand: { ..r.expand, y: false, },
    size: {
      ..r.size,
      y: r.size.y - (flow_need + separator_need + self.config.footnote.gap),
    },
  }

  // Layout the footnote entry.
  let frames = layout_footnote(self.engine, self.config, elem, pod).into_frames()

  // Find nested footnotes in the entry.
  let nested = find_in_frames(frames, @library.FootnoteElem::of)

  // Check if there are any non-empty frames.
  let exist_non_empty_frame = frames.iter().any(f => !f.is_empty())

  // Extract the first frame.
  let first = frames[0]
  let rest = frames[1:].to_array()
  let note_need = self.config.footnote.gap + first.height()

  // If the first frame is empty, then none of its content fit. If possible,
  // we then migrate the origin frame to the next region to uphold the
  // footnote invariant (that marker and entry are on the same page). If
  // not, we just queue the footnote for the next page, but only if that
  // would actually make a difference (that is, if the footnote isn't alone
  // in the page after not fitting in any previous pages, as it probably
  // won't ever fit then).
  //
  // Note that a non-zero flow need also indicates that queueing would make
  // a difference, because the flow need is subtracted from the available
  // height in the entry's pod even if what caused that need wasn't
  // considered for the input `regions`. For example, floats just pass the
  // `regions` they received along to their footnotes, which don't take into
  // account the space occupied by the floats themselves, but they do
  // indicate their footnotes have a non-zero flow need, so queueing them
  // can matter as, in the following pages, the flow need will be set to
  // zero and the footnote will be alone in the page. Then, `may_progress()`
  // will also be false (this time, correctly) and the footnote is laid out,
  // as queueing wouldn't improve the lack of space anymore and would result
  // in an infinite loop.
  //
  // However, it is worth noting that migration does take into account the
  // original region, before inserting what prompted the flow need.
  // Logically, if moving the original frame can't improve the lack of
  // space, then migration should be inhibited. The space occupied by the
  // original frame is not relevant for that check. Therefore,
  // `regions.may_progress()` must still be checked separately for
  // migration, regardless of the presence of flow need.
  if first.is_empty() && exist_non_empty_frame {
    if migration.allowed && regions.val.may_progress() {
      raise MigrateOrigin
    } else if regions.val.may_progress() || !flow_need.is_zero() {
      self.footnote_queue.push(elem)
      return
    }
  }

  // Save the separator.
  if separator is Some(frame) {
    area.push_footnote_separator(self.config, frame)
    regions.val = {
      ..regions.val,
      size: { ..regions.val.size, y: regions.val.size.y - separator_need, },
    }
  }

  // Save the footnote's frame.
  area.push_footnote(self.config, first)
  area.skips.push(loc)
  regions.val = {
    ..regions.val,
    size: { ..regions.val.size, y: regions.val.size.y - note_need, },
  }

  // Save the spill.
  if !rest.is_empty() {
    self.footnote_spill = Some(rest)
  }

  // Lay out nested footnotes.
  for pair in nested {
    let (_, note) = pair
    self.footnote(note, regions, flow_need, migration) catch {
      // This footnote was already processed or queued.
      // Footnotes always request a relayout when processed for the first
      // time, so we ignore a relayout request since we're about to do so
      // afterwards. Without this check, the first inner footnote interrupts
      // processing of the following ones.
      Relayout(Column) => ()
      // Either of
      // - A `FootnoteStop::MigrateOrigin` indicating that the frame's origin
      //   element should migrate to uphold the footnote invariant.
      // - A fatal error.
      err => raise err
    }
  }

  // Since we laid out a footnote, we need a relayout.
  raise Relayout(Column)
}

///|
/// Handles spillover from a footnote.
fn Composer::footnote_spill(
  self : Composer,
  frames : Array[@library.Frame],
  base : @library.Axes[@library.Abs],
) -> Unit raise @library.SourceError {
  let area = self.column_insertions

  // Create and save the separator.
  let separator = layout_footnote_separator(self.engine, self.config, base)
  area.push_footnote_separator(self.config, separator)

  // Save the footnote's frame.
  let frame = frames[0]
  area.push_footnote(self.config, frame)

  // Save the spill.
  if frames.length() > 1 {
    self.footnote_spill = Some(frames[1:].to_array())
  }
}

///|
/// Checks whether an insertion was already processed and doesn't need to be
/// handled again.
fn Composer::skipped(self : Composer, loc : @library.Location) -> Bool {
  self.work.skips.contains(loc) ||
  self.page_insertions.skips.contains(loc) ||
  self.column_insertions.skips.contains(loc)
}

///|
/// The amount of width needed by insertions.
fn Composer::insertion_width(self : Composer) -> @library.Abs {
  self.column_insertions.width.max(self.page_insertions.width)
}

///|
/// Lay out the footnote separator, typically a line.
fn layout_footnote_separator(
  engine : @library.Engine,
  config : Config,
  base : @library.Axes[@library.Abs],
) -> @library.Frame raise @library.SourceError {
  layout_frame(
    engine,
    config.footnote.separator,
    @library.Locator::root(),
    config.shared,
    @library.LayoutRegion::new(
      base,
      @library.Axes::new(config.footnote.expand, false),
    ),
  )
}

///|
/// Lay out a footnote.
fn layout_footnote(
  engine : @library.Engine,
  config : Config,
  elem : @library.FootnoteElem,
  pod : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  let loc = elem.pack().location().unwrap()
  let fragment = layout_fragment(
    engine,
    @library.FootnoteEntry::new(elem)
    .pack()
    .spanned(elem.pack().span())
    // We attach a well-known derived location to the entry so that the note
    // can link to this entry without first querying for it.
    .located(loc.variant(1)),
    @library.Locator::synthesize(loc),
    config.shared,
    pod,
  )
  for frame in fragment.iter() {
    frame.set_parent(@library.FrameParent::new(loc, No))
  }
  fragment
}

///|
/// Lay out the column separator, typically a line.
fn layout_column_separator(
  engine : @library.Engine,
  separator : @library.Content,
  config : Config,
  base : @library.Axes[@library.Abs],
) -> @library.Frame raise @library.SourceError {
  layout_frame(
    engine,
    separator,
    @library.Locator::root(),
    config.shared,
    @library.LayoutRegion::new(base, @library.Axes::splat(true)),
  )
}

///|
/// An additive list of insertions.
priv struct Insertions {
  top_floats : Array[(PlacedChild, @library.Frame)]
  bottom_floats : Array[(PlacedChild, @library.Frame)]
  footnotes : Array[@library.Frame]
  mut footnote_separator : @library.Frame?
  mut top_size : @library.Abs
  mut bottom_size : @library.Abs
  mut footnote_size : @library.Abs
  mut width : @library.Abs
  skips : Array[@library.Location]
}

///|
fn Insertions::new() -> Insertions {
  {
    top_floats: [],
    bottom_floats: [],
    footnotes: [],
    footnote_separator: None,
    top_size: @library.Abs::zero(),
    bottom_size: @library.Abs::zero(),
    footnote_size: @library.Abs::zero(),
    width: @library.Abs::zero(),
    skips: [],
  }
}

///|
/// Add a float to the top or bottom area.
fn Insertions::push_float(
  self : Insertions,
  placed : PlacedChild,
  frame : @library.Frame,
  align_y : @library.FixedAlignment,
) -> Unit {
  self.width = self.width.max(frame.width())
  let amount = frame.height() + placed.clearance
  let pair = (placed, frame)
  if align_y == Start {
    self.top_size = self.top_size + amount
    self.top_floats.push(pair)
  } else {
    self.bottom_size = self.bottom_size + amount
    self.bottom_floats.push(pair)
  }
}

///|
/// Add a footnote to the bottom area.
fn Insertions::push_footnote(
  self : Insertions,
  config : Config,
  frame : @library.Frame,
) -> Unit {
  self.width = self.width.max(frame.width())
  self.footnote_size = self.footnote_size +
    (config.footnote.gap + frame.height())
  self.footnotes.push(frame)
}

///|
/// Add a footnote separator to the bottom area.
fn Insertions::push_footnote_separator(
  self : Insertions,
  config : Config,
  frame : @library.Frame,
) -> Unit {
  self.width = self.width.max(frame.width())
  self.footnote_size = self.footnote_size +
    (config.footnote.clearance + frame.height())
  self.footnote_separator = Some(frame)
}

///|
/// The combined height of the top and bottom area (including clearances).
/// Subtracting this from the total region size yields the available space
/// for distribution.
fn Insertions::height(self : Insertions) -> @library.Abs {
  self.top_size + self.bottom_size + self.footnote_size
}

///|
/// The combined height of the top and bottom area for floats (including
/// clearances) but excluding footnotes.
fn Insertions::float_height(self : Insertions) -> @library.Abs {
  self.top_size + self.bottom_size
}

///|
/// Produce a frame for the full region based on the `inner` frame produced
/// by distribution or column layout.
fn Insertions::finalize(
  self : Insertions,
  work : Work,
  config : Config,
  inner : @library.Frame,
  column_height : @library.Abs?,
) -> @library.Frame {
  work.extend_skips(self.skips)
  if self.top_floats.is_empty() &&
    self.bottom_floats.is_empty() &&
    self.footnote_separator is None &&
    self.footnotes.is_empty() {
    return inner
  }
  let size = inner
    .size()
    .add_size(@library.Axes::new(@library.Abs::zero(), self.height()))
  let output = @library.Frame::soft(size)
  let mut offset_top = @library.Abs::zero()
  for pair in self.top_floats {
    let (placed, frame) = pair
    let x = placed.align_x.position(size.x - frame.width())
    let y = offset_top
    let delta = placed.delta.relative_to(size).to_point()
    offset_top = offset_top + (frame.height() + placed.clearance)
    output.push_frame(@library.Point::new(x, y) + delta, frame)
  }

  // Technically, if the flow has floats and footnotes, it's probably not
  // going to be within a block but correspond to the main page flow, where
  // the baseline doesn't matter. However, we'd keep the baseline correct
  // anyways in case future enhancements enable deeper manipulation of this
  // flow.
  if inner.has_baseline() {
    output.set_baseline(self.top_size + inner.baseline())
  }
  output.push_frame(@library.Point::with_y(self.top_size), inner)

  // We put floats first and then footnotes. This differs from what LaTeX
  // does and is a little inconsistent w.r.t column vs page floats (page
  // floats are below footnotes because footnotes are per column), but it's
  // what most people (including myself) seem to intuitively expect. We
  // experimented with the LaTeX ordering in 0.12.0-rc1, but folks were
  // surprised and considered this strange. In LaTeX, it can be changed with
  // `\usepackage[bottom]{footmisc}`. We could also consider adding
  // configuration in the future.
  let mut float_offset_bottom = column_height.unwrap_or(
      size.y - self.footnote_size,
    ) -
    self.bottom_size
  for pair in self.bottom_floats {
    let (placed, frame) = pair
    float_offset_bottom = float_offset_bottom + placed.clearance
    let x = placed.align_x.position(size.x - frame.width())
    let y = float_offset_bottom
    let delta = placed.delta.relative_to(size).to_point()
    float_offset_bottom = float_offset_bottom + frame.height()
    output.push_frame(@library.Point::new(x, y) + delta, frame)
  }
  let mut footnote_offset_bottom = size.y - self.footnote_size
  if self.footnote_separator is Some(frame) {
    footnote_offset_bottom = footnote_offset_bottom + config.footnote.clearance
    let y = footnote_offset_bottom
    footnote_offset_bottom = footnote_offset_bottom + frame.height()
    output.push_frame(@library.Point::with_y(y), frame)
  }
  for frame in self.footnotes {
    footnote_offset_bottom = footnote_offset_bottom + config.footnote.gap
    let y = footnote_offset_bottom
    footnote_offset_bottom = footnote_offset_bottom + frame.height()
    output.push_frame(@library.Point::with_y(y), frame)
  }
  output
}

///|
/// Lay out the given collected lines' line numbers to an output frame.
///
/// The numbers are placed either on the left margin (left border of the
/// frame) or on the right margin (right border). Before they are placed, a
/// line number counter reset is inserted if we're in the first column of the
/// page being currently laid out and the user requested for line numbers to
/// be reset at the start of every page.
fn layout_line_numbers(
  engine : @library.Engine,
  config : Config,
  line_config : LineNumberConfig,
  locator : @library.Locator,
  column : Int,
  output : @library.Frame,
) -> Unit raise @library.SourceError {
  let locator = locator.split()

  // Reset page-scoped line numbers if currently at the first column.
  if column == 0 && line_config.scope == Page {
    let reset = layout_line_number_reset(engine, config, locator)
    output.push_frame(@library.Point::zero(), reset)
  }

  // Find all line markers.
  let lines = find_in_frame(output, @library.ParLineMarker::of)
  if lines.is_empty() {
    return
  }

  // Assume the line numbers aren't sorted by height. They must be sorted so
  // we can deduplicate line numbers below based on vertical proximity.
  stable_sort_by(lines, (a, b) => a.0.compare(b.0))

  // Used for horizontal alignment.
  let mut max_number_width = @library.Abs::zero()

  // This is used to skip lines that are too close together.
  let mut prev_bottom : @library.Abs? = None

  // Buffer line number frames so we can align them horizontally later before
  // placing, based on the width of the largest line number.
  let line_numbers = []

  // Layout the lines.
  for line in lines {
    let (y, marker) = line
    if prev_bottom is Some(bottom) && y.to_raw() < bottom.to_raw() {
      // Lines are too close together. Display as the same line number.
      continue
    }

    // Layout the number and record its width in search of the maximum.
    let frame = layout_line_number(engine, config, locator, marker.numbering())

    // Note that this line.y is larger than the previous due to sorting.
    // Therefore, the check at the top of the loop ensures no line numbers
    // will reasonably intersect with each other. We enforce a minimum
    // spacing of 1pt between consecutive line numbers in case a zero-height
    // frame is used.
    prev_bottom = Some(y + frame.height().max(@library.Abs::pt(1.0)))
    max_number_width = max_number_width.max(frame.width())
    line_numbers.push((y, marker, frame))
  }
  for entry in line_numbers {
    let (y, marker, frame) = entry
    // The last column will always place line numbers at the end margin. This
    // should become configurable in the future.
    let margin = {
      let opposite = config.columns.count >= 2 &&
        column + 1 == config.columns.count
      let m : @library.OuterHAlignment = if opposite {
        End
      } else {
        marker.number_margin()
      }
      m.resolve(config.shared)
    }

    // Determine how much space to leave between the column and the number.
    let clearance = match marker.number_clearance() {
      Auto => line_config.default_clearance
      Custom(rel) => rel.resolve(config.shared)
    }

    // Compute the base X position.
    let x = match margin {
      // Move the number to the left of the left edge (at 0pt) by the maximum
      // width and the clearance.
      Start => -max_number_width - clearance
      // Move the number to the right edge and add clearance.
      End => output.width() + clearance
      // Can't happen due to `OuterHAlignment`.
      Center => abort("unreachable")
    }

    // Determine how much to shift the number due to its alignment.
    let shift = {
      let align = match marker.number_align() {
        Custom(align) => align.resolve(config.shared)
        Auto => margin.inv()
      }
      align.position(max_number_width - frame.width())
    }

    // Compute the final position of the number and add it to the output.
    let pos = @library.Point::new(x + shift, y)
    output.push_frame(pos, frame)
  }
}

///|
/// Creates a frame that resets the line number counter.
fn layout_line_number_reset(
  engine : @library.Engine,
  config : Config,
  locator : @library.SplitLocator,
) -> @library.Frame raise @library.SourceError {
  let counter = @library.Counter::of(@library.par_line_marker_elem())
  let update = @library.CounterUpdate::Set(@library.CounterState::init(false))
  let content = counter.update(@syntax.Span::detached(), update)
  layout_frame(
    engine,
    content,
    locator.next(()),
    config.shared,
    @library.LayoutRegion::new(
      @library.Axes::splat(@library.Abs::zero()),
      @library.Axes::splat(false),
    ),
  )
}

///|
/// Layout the line number associated with the given line marker.
///
/// Produces a counter update and counter display with counter key
/// `ParLineMarker`. We use `ParLineMarker` as it is an element which is not
/// exposed to the user and we don't want to expose the line number counter
/// at the moment, given that its semantics are inconsistent with that of
/// normal counters (the counter is updated based on height and not on frame
/// order / layer). When we find a solution to this, we should switch to a
/// counter on `ParLine` instead, thus exposing the counter as
/// `counter(par.line)` to the user.
fn layout_line_number(
  engine : @library.Engine,
  config : Config,
  locator : @library.SplitLocator,
  numbering : @library.Numbering,
) -> @library.Frame raise @library.SourceError {
  let counter = @library.Counter::of(@library.par_line_marker_elem())
  let update = @library.CounterUpdate::Step(@library.NonZeroUSize(1L))
  let numbering : @library.Smart[@library.Numbering] = Custom(numbering)

  // Combine counter update and display into the content we'll layout.
  let content = @library.Content::sequence([
    counter.update(@syntax.Span::detached(), update),
    @library.CounterDisplayElem::new(counter, numbering, false).pack(),
  ])
  let content = content.artifact(LineNumber)

  // Layout the number.
  let frame = layout_frame(
    engine,
    content,
    locator.next(()),
    config.shared,
    @library.LayoutRegion::new(
      @library.Axes::splat(@library.Abs::inf()),
      @library.Axes::splat(false),
    ),
  )

  // Ensure the baseline of the line number aligns with the line's baseline.
  frame.translate(@library.Point::with_y(-frame.baseline()))
  frame
}

///|
/// Collect all matching elements and their vertical positions in the frame.
///
/// On each subframe we encounter, we add that subframe's position to
/// `prev_y`, until we reach a tag, at which point we add the tag's position
/// and finish. That gives us the absolute height of the tag from the start
/// of the root frame.
fn[T] find_in_frame(
  frame : @library.Frame,
  of : (@library.Content) -> T?,
) -> Array[(@library.Abs, T)] {
  let output = []
  find_in_frame_impl(output, frame, @library.Abs::zero(), of)
  output
}

///|
/// Collect all matching elements and their vertical positions in the frames.
fn[T] find_in_frames(
  frames : Array[@library.Frame],
  of : (@library.Content) -> T?,
) -> Array[(@library.Abs, T)] {
  let output = []
  for frame in frames {
    find_in_frame_impl(output, frame, @library.Abs::zero(), of)
  }
  output
}

///|
fn[T] find_in_frame_impl(
  output : Array[(@library.Abs, T)],
  frame : @library.Frame,
  y_offset : @library.Abs,
  of : (@library.Content) -> T?,
) -> Unit {
  for entry in frame.items() {
    let (pos, item) = entry
    let y = y_offset + pos.y
    match item {
      Group(group) => find_in_frame_impl(output, group.frame, y, of)
      Tag(Start(elem, _)) =>
        if of(elem) is Some(elem) {
          output.push((y, elem))
        }
      _ => ()
    }
  }
}

///|
/// A stable sort (upstream `slice::sort_by`), implemented as a merge sort.
fn[T] stable_sort_by(array : Array[T], cmp : (T, T) -> Int) -> Unit {
  let n = array.length()
  if n < 2 {
    return
  }
  let mut src = array.copy()
  let mut dst = array.copy()
  let mut width = 1
  while width < n {
    let mut lo = 0
    while lo < n {
      let mid = if lo + width < n { lo + width } else { n }
      let hi = if lo + 2 * width < n { lo + 2 * width } else { n }
      let mut i = lo
      let mut j = mid
      let mut k = lo
      while k < hi {
        if i < mid && (j >= hi || cmp(src[i], src[j]) <= 0) {
          dst[k] = src[i]
          i += 1
        } else {
          dst[k] = src[j]
          j += 1
        }
        k += 1
      }
      lo = hi
    }
    let tmp = src
    src = dst
    dst = tmp
    width *= 2
  }
  for i in 0..<n {
    array[i] = src[i]
  }
}
