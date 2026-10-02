// Port of `typst-layout/src/flow/distribute.rs`.

///|
/// Distributes as many children as fit from `composer.work` into the first
/// region and returns the resulting frame and the height actually used by
/// the inner contents (for column balancing).
///
/// Raises `FlowStop::Relayout(..)` (upstream `RelayoutStop`) or a
/// `SourceError`.
fn distribute(
  composer : Composer,
  regions : @library.Regions,
  balancing_target : @library.Abs?,
) -> (@library.Frame, @library.Abs) raise {
  let distributor : Distributor = {
    composer,
    regions,
    items: [],
    used: @library.Axes::zero_size(),
    target: balancing_target,
    sticky: None,
    stickable: None,
  }
  let init = distributor.snapshot()
  let forced = try distributor.run() catch {
    Finish(forced) => forced
    Relayout(scope) => raise Relayout(scope)
    MigrateOrigin => abort("migration must be handled by the distributor")
    err => raise err
  } noraise {
    _ => distributor.composer.work.done()
  }
  let region = @library.LayoutRegion::new(regions.size, regions.expand)
  distributor.finalize(region, init, forced)
}

///|
/// State for distribution.
priv struct Distributor {
  /// The composer that is used to handle insertions.
  composer : Composer
  /// Regions which are continuously shrunk as new items are added.
  mut regions : @library.Regions
  /// Already laid out items, not yet aligned.
  items : Array[Item]
  /// Size used by laid out items.
  mut used : @library.Axes[@library.Abs]
  /// The target height for column balancing.
  target : @library.Abs?
  /// A snapshot which can be restored to migrate a suffix of sticky blocks to
  /// the next region.
  mut sticky : DistributionSnapshot?
  /// Whether the current group of consecutive sticky blocks are still sticky
  /// and may migrate with the attached frame. This is `None` while we aren't
  /// processing sticky blocks. On the first sticky block, this will become
  /// `Some(true)` if migrating sticky blocks as usual would make a
  /// difference - this is given by `regions.may_progress()`. Otherwise, it
  /// is set to `Some(false)`, which is usually the case when the first
  /// sticky block in the group is at the very top of the page (then,
  /// migrating it would just lead us back to the top of the page, leading to
  /// an infinite loop). In that case, all sticky blocks of the group are also
  /// disabled, until this is reset to `None` on the first non-sticky frame
  /// we find.
  ///
  /// While this behavior of disabling stickiness of sticky blocks at the
  /// very top of the page may seem non-ideal, it is only problematic (that
  /// is, may lead to orphaned sticky blocks / headings) if the combination
  /// of 'sticky blocks + attached frame' doesn't fit in one page, in which
  /// case there is nothing Typst can do to improve the situation, as sticky
  /// blocks are supposed to always be in the same page as the subsequent
  /// frame, but that is impossible in that case, which is thus pathological.
  mut stickable : Bool?
}

///|
/// A snapshot of the distribution state.
priv struct DistributionSnapshot {
  work : Work
  items : Int
  used : @library.Axes[@library.Abs]
}

///|
/// A laid out item in a distribution.
priv enum Item {
  /// An introspection tag.
  Tag(@library.Tag)
  /// Absolute spacing and its weakness level.
  Abs(@library.Abs, Int)
  /// Fractional spacing or a fractional block.
  Fr(@library.Fr, Int, SingleChild?)
  /// A frame for a laid out line or block.
  Frame(@library.Frame, @library.Axes[@library.FixedAlignment])
  /// A frame for an absolutely (not floatingly) placed child.
  Placed(@library.Frame, PlacedChild)
}

///|
/// Whether this item should be migrated to the next region if the region
/// consists solely of such items.
fn Item::migratable(self : Item) -> Bool {
  match self {
    Tag(_) => true
    Frame(frame, _) =>
      frame.size().is_zero_size() &&
      frame.items().iter().all(entry => entry.1 is (Link(_, _) | Tag(_)))
    Placed(_, placed) => !placed.float
    _ => false
  }
}

///|
/// Converts the insertion stops raised by the composer into distribution
/// stops (upstream `From<InsertionStop<R, ()>> for Stop`): a requested
/// migration of the origin finishes the region.
fn[T] insertion(f : () -> T raise) -> T raise {
  f() catch {
    MigrateOrigin => raise Finish(false)
    err => raise err
  }
}

///|
/// Distributes content into the region.
fn Distributor::run(self : Distributor) -> Unit raise {
  // First, handle spill of a breakable block.
  if self.composer.work.spill is Some(spill) {
    self.composer.work.spill = None
    self.multi_spill(spill)
  }

  // If spill are taken care of, process children until no space is left or
  // no children are left.
  while self.composer.work.head() is Some(child) {
    self.child(child)
    self.composer.work.advance()
  }
}

///|
/// Processes a single child.
///
/// - Returns normally if the child was successfully processed.
/// - Raises `Finish(_)` if a region break should be triggered.
/// - Raises `Relayout(_)` if the region needs to be relayouted due to an
///   insertion (float/footnote).
/// - Raises a `SourceError` if there was a fatal error.
fn Distributor::child(self : Distributor, child : Child) -> Unit raise {
  match child {
    Tag(tag) => self.tag(tag)
    Rel(amount, weakness) => self.rel(amount, weakness)
    Fr(fr, weakness) => self.fr(fr, weakness)
    Line(line) => self.line(line)
    Single(single) => self.single(single)
    Multi(multi) => self.multi(multi)
    Placed(placed) => self.placed(placed)
    Flush => self.flush()
    Break(weak) => self.break_(weak)
  }
}

///|
/// Processes a tag.
fn Distributor::tag(self : Distributor, tag : @library.Tag) -> Unit {
  self.composer.work.tags.push(tag)
}

///|
/// Generate items for pending tags.
fn Distributor::flush_tags(self : Distributor) -> Unit {
  if !self.composer.work.tags.is_empty() {
    let tags = self.composer.work.tags
    for tag in tags {
      self.items.push(Tag(tag))
    }
    self.composer.work.tags = []
  }
}

///|
/// Mark the amount of height used and reduce the region height accordingly.
fn Distributor::use_height(self : Distributor, amount : @library.Abs) -> Unit {
  self.regions = {
    ..self.regions,
    size: { ..self.regions.size, y: self.regions.size.y - amount, },
  }
  self.used = { ..self.used, y: self.used.y + amount, }
}

///|
/// Processes relative spacing.
fn Distributor::rel(
  self : Distributor,
  amount : @library.Rel[@library.Abs],
  weakness : Int,
) -> Unit {
  let amount = amount.relative_to(self.regions.base().y)
  if weakness > 0 && !self.keep_weak_rel_spacing(amount, weakness) {
    return
  }
  self.use_height(amount)
  self.items.push(Abs(amount, weakness))
}

///|
/// Processes fractional spacing.
fn Distributor::fr(
  self : Distributor,
  fr : @library.Fr,
  weakness : Int,
) -> Unit {
  if weakness > 0 && !self.keep_weak_fr_spacing(fr, weakness) {
    return
  }

  // If we decided to keep the fr spacing, it's safe to trim previous spacing
  // as no stronger fr spacing can exist.
  self.trim_spacing()
  self.items.push(Fr(fr, weakness, None))
}

///|
/// Decides whether to keep weak spacing based on previous items. If there is
/// a preceding weak spacing, it might be patched in place.
fn Distributor::keep_weak_rel_spacing(
  self : Distributor,
  amount : @library.Abs,
  weakness : Int,
) -> Bool {
  for i = self.items.length() - 1; i >= 0; i = i - 1 {
    match self.items[i] {
      // When previous weak relative spacing exists that's at most as weak,
      // we reuse the old item, set it to the maximum of both, and discard the
      // new item.
      Abs(prev_amount, prev_weakness) if prev_weakness >= 1 => {
        if weakness <= prev_weakness &&
          (weakness < prev_weakness || amount.to_raw() > prev_amount.to_raw()) {
          self.items[i] = Abs(amount, weakness)
          self.use_height(amount - prev_amount)
        }
        return false
      }
      // These are "peeked beyond" for spacing collapsing purposes.
      Tag(_) | Abs(_, 0) | Placed(_, _) => ()
      // Any kind of fractional spacing destructs weak relative spacing.
      Fr(_, _, None) => return false
      // These naturally support the spacing.
      Frame(_, _) | Fr(_, _, Some(_)) => return true
      Abs(_, _) => ()
    }
  }
  false
}

///|
/// Decides whether to keep weak fractional spacing based on previous items.
/// If there is a preceding weak spacing, it might be patched in place.
fn Distributor::keep_weak_fr_spacing(
  self : Distributor,
  fr : @library.Fr,
  weakness : Int,
) -> Bool {
  for i = self.items.length() - 1; i >= 0; i = i - 1 {
    match self.items[i] {
      // When previous weak fr spacing exists that's at most as weak, we reuse
      // the old item, set it to the maximum of both, and discard the new
      // item.
      Fr(prev_fr, prev_weakness, None) if prev_weakness >= 1 => {
        if weakness <= prev_weakness &&
          (weakness < prev_weakness || fr.get() > prev_fr.get()) {
          self.items[i] = Fr(fr, weakness, None)
        }
        return false
      }
      // These are "peeked beyond" for spacing collapsing purposes. Weak
      // absolute spacing, in particular, will be trimmed once we push the
      // fractional spacing.
      Tag(_) | Abs(_, _) | Placed(_, _) => ()
      // For weak + strong fr spacing, we keep both, same as for weak +
      // strong rel spacing.
      Fr(_, _, None) => return true
      // These naturally support the spacing.
      Frame(_, _) | Fr(_, _, Some(_)) => return true
    }
  }
  false
}

///|
/// Trims trailing weak spacing from the items.
fn Distributor::trim_spacing(self : Distributor) -> Unit {
  for i = self.items.length() - 1; i >= 0; i = i - 1 {
    match self.items[i] {
      Abs(amount, weakness) if weakness >= 1 => {
        self.use_height(-amount)
        self.items.remove(i) |> ignore
        break
      }
      Fr(_, weakness, None) if weakness >= 1 => {
        self.items.remove(i) |> ignore
        break
      }
      Tag(_) | Abs(_, _) | Placed(_, _) => ()
      Frame(_, _) | Fr(_, _, _) => break
    }
  }
}

///|
/// The amount of trailing weak spacing.
fn Distributor::weak_spacing(self : Distributor) -> @library.Abs {
  for i = self.items.length() - 1; i >= 0; i = i - 1 {
    match self.items[i] {
      Abs(amount, weakness) if weakness >= 1 => return amount
      Tag(_) | Abs(_, _) | Placed(_, _) => ()
      Frame(_, _) | Fr(_, _, _) => break
    }
  }
  @library.Abs::zero()
}

///|
/// Whether the amount fits into the remaining region, taking into account
/// column balancing limits.
fn Distributor::fits(self : Distributor, amount : @library.Abs) -> Bool {
  self.regions.size.y.fits(amount) &&
  (match self.target {
    // Add elements as long as the balancing target is not reached. By not
    // including the amount itself here, we avoid protruding items to
    // cumulate in the last column.
    None => true
    Some(target) => target.fits(self.used.y)
  })
}

///|
/// Processes a line of a paragraph.
fn Distributor::line(self : Distributor, line : LineChild) -> Unit raise {
  // If the line doesn't fit and a followup region may improve things,
  // finish the region.
  if !self.fits(line.frame.height()) && self.regions.may_progress() {
    raise Finish(false)
  }

  // If the line's need, which includes its own height and that of following
  // lines grouped by widow/orphan prevention, does not fit into the current
  // region, but does fit into the next region, finish the region.
  if !self.fits(line.need) &&
    (match self.regions.iter().drop(1).head() {
      Some(region) => region.y.fits(line.need)
      None => false
    }) {
    raise Finish(false)
  }
  self.frame(line.frame.clone(), line.align, false, false)
}

///|
/// Processes an unbreakable block.
fn Distributor::single(self : Distributor, single : SingleChild) -> Unit raise {
  // Lay out the block.
  let frame = single.layout(
    self.composer.engine,
    @library.LayoutRegion::new(self.regions.base(), self.regions.expand),
  )

  // Handle fractionally sized blocks.
  if single.fr is Some(fr) {
    insertion(() => {
      self.composer.footnotes(
        self.regions,
        frame,
        @library.Abs::zero(),
        false,
        Migration::allow(),
      )
    })
    self.flush_tags()
    self.items.push(Fr(fr, 0, Some(single)))
    return
  }

  // If the block doesn't fit and a followup region may improve things,
  // finish the region.
  if !self.fits(frame.height()) && self.regions.may_progress() {
    raise Finish(false)
  }
  self.frame(frame, single.align, single.sticky, false)
}

///|
/// Processes a breakable block.
fn Distributor::multi(self : Distributor, multi : MultiChild) -> Unit raise {
  let mut pod = self.regions

  // For column balancing, reduce the region size for layout.
  if self.target is Some(lim) {
    let remaining = lim - self.used.y
    pod = { ..pod, size: { ..pod.size, y: pod.size.y.min(remaining), }, }
  }

  // Skip directly if the region is already (over)full. `line` and `single`
  // implicitly do this through their `fits` checks.
  if pod.is_full() {
    raise Finish(false)
  }

  // Lay out the block.
  let (frame, spill) = multi.layout(self.composer.engine, pod)
  if frame.is_empty() &&
    (match spill {
      Some(s) => s.exist_non_empty_frame
      None => false
    }) &&
    self.regions.may_progress() {
    // If the first frame is empty, but there are non-empty frames in the
    // spill, the whole child should be put in the next region to avoid any
    // invisible orphans at the end of this region.
    raise Finish(false)
  }
  self.frame(frame, multi.align, multi.sticky, true)

  // If the block didn't fully fit into the current region, save it into the
  // `spill` and finish the region.
  if spill is Some(spill) {
    self.composer.work.spill = Some(spill)
    self.composer.work.advance()
    raise Finish(false)
  }
}

///|
/// Processes spillover from a breakable block.
fn Distributor::multi_spill(
  self : Distributor,
  spill : MultiSpill,
) -> Unit raise {
  let mut pod = self.regions

  // For column balancing, reduce the region size for layout.
  if self.target is Some(lim) {
    let remaining = lim - self.used.y
    pod = { ..pod, size: { ..pod.size, y: pod.size.y.min(remaining), }, }
  }

  // Skip directly if the region is already (over)full.
  if pod.is_full() {
    self.composer.work.spill = Some(spill)
    raise Finish(false)
  }

  // Lay out the spilled remains.
  let align = spill.align()
  let (frame, spill) = spill.layout(self.composer.engine, pod)
  self.frame(frame, align, false, true)

  // If there's still more, save it into the `spill` and finish the region.
  if spill is Some(spill) {
    self.composer.work.spill = Some(spill)
    raise Finish(false)
  }
}

///|
/// Processes an in-flow frame, generated from a line or block.
fn Distributor::frame(
  self : Distributor,
  frame : @library.Frame,
  align : @library.Axes[@library.FixedAlignment],
  sticky : Bool,
  breakable : Bool,
) -> Unit raise {
  // If the frame is sticky and we haven't remembered a preceding sticky
  // element, make a checkpoint which we can restore should we end on this
  // sticky element.
  //
  // The first sticky block within consecutive sticky blocks determines
  // whether this group of sticky blocks has stickiness disabled or not.
  //
  // The criteria used here is: if migrating this group of sticky blocks
  // together with the "attached" block can't improve the lack of space,
  // since we're at the start of the region, then we don't do so, and
  // stickiness is disabled (at least, for this region). Otherwise, migration
  // is allowed.
  //
  // Note that, since the whole region is checked, this ensures sticky blocks
  // at the top of a block - but not necessarily of the page - can still be
  // migrated.
  if sticky && self.sticky is None {
    let stickable = match self.stickable {
      Some(v) => v
      None => {
        let v = self.regions.may_progress()
        self.stickable = Some(v)
        v
      }
    }
    if stickable {
      self.sticky = Some(self.snapshot())
    }
  }

  // Handle footnotes.
  //
  // This must happen before we forget a previous sticky snapshot below. If a
  // non-sticky frame's footnote doesn't fit, the frame and any preceding
  // sticky blocks attached to it need to migrate to the next region
  // together. Resetting the sticky state first would then strand those
  // sticky blocks in this region.
  insertion(() => {
    self.composer.footnotes(
      self.regions,
      frame,
      frame.height(),
      breakable,
      Migration::allow(),
    )
  })
  if !sticky && !frame.is_empty() {
    // If the frame isn't sticky, we can forget a previous snapshot. We
    // interrupt a group of sticky blocks, if there was one, so we reset the
    // saved stickable check for the next group of sticky blocks.
    self.sticky = None
    self.stickable = None
  }

  // Push an item for the frame.
  self.use_height(frame.height())
  self.used = { ..self.used, x: self.used.x.max(frame.width()), }
  self.flush_tags()
  self.items.push(Frame(frame, align))
}

///|
/// Processes an absolutely or floatingly placed child.
fn Distributor::placed(self : Distributor, placed : PlacedChild) -> Unit raise {
  if placed.float {
    // If the element is floatingly placed, let the composer handle it. It
    // might require relayout because the area available for distribution
    // shrinks. We make the spacing occupied by weak spacing temporarily
    // available again because it can collapse if it ends up at a break due
    // to the float.
    let weak_spacing = self.weak_spacing()
    self.use_height(-weak_spacing)
    insertion(() => {
      self.composer.float(
        placed,
        self.regions,
        self.items.iter().any(item => item is Frame(_, _)),
        Migration::allow(),
      )
    })
    self.use_height(weak_spacing)
  } else {
    let frame = placed.layout(self.composer.engine, self.regions.base())
    insertion(() => {
      self.composer.footnotes(
        self.regions,
        frame,
        @library.Abs::zero(),
        true,
        Migration::allow(),
      )
    })
    self.flush_tags()
    self.items.push(Placed(frame, placed))
  }
}

///|
/// Processes a float flush.
fn Distributor::flush(self : Distributor) -> Unit raise {
  // If there are still pending floats, finish the region instead of adding
  // more content to it.
  if !self.composer.work.floats.is_empty() {
    raise Finish(false)
  }
}

///|
/// Processes a column break.
fn Distributor::break_(self : Distributor, weak : Bool) -> Unit raise {
  // If there is a region to break into, break into it.
  if (!weak || !self.items.is_empty()) &&
    (!self.regions.backlog.is_empty() || self.regions.last is Some(_)) {
    self.composer.work.advance()
    raise Finish(true)
  }
}

///|
/// Arranges the produced items into an output frame.
///
/// This performs alignment and resolves fractional spacing and blocks.
fn Distributor::finalize(
  self : Distributor,
  region : @library.LayoutRegion,
  init : DistributionSnapshot,
  forced : Bool,
) -> (@library.Frame, @library.Abs) raise @library.SourceError {
  if forced {
    // If this is the very end of the flow, flush pending tags.
    self.flush_tags()
  } else if !self.items.is_empty() && self.items.iter().all(Item::migratable) {
    // Restore the initial state of all items are migratable.
    self.restore(init)
  } else if self.sticky is Some(snapshot) {
    // If we ended on a sticky block, but are not yet at the end of the flow,
    // restore the saved checkpoint to move the sticky suffix to the next
    // region.
    self.sticky = None
    self.restore(snapshot)
  }
  self.trim_spacing()
  let used_height_without_fr = self.used.y

  // Determine the sum of fractionals.
  let mut frs = @library.Fr::zero()
  let mut has_fr_child = false
  for item in self.items {
    if item is Fr(v, _, child) {
      frs = frs + v
      has_fr_child = has_fr_child || child is Some(_)
    }
  }

  // When we have fractional spacing, occupy the remaining space with it.
  let mut fr_space = @library.Abs::zero()
  if frs.get() > 0.0 && region.size.y.is_finite() {
    fr_space = region.size.y - self.used.y
    self.used = { ..self.used, y: region.size.y, }
  }

  // Lay out fractionally sized blocks.
  let fr_frames = []
  if has_fr_child {
    for item in self.items {
      guard item is Fr(v, _, Some(single)) else { continue }
      let length = v.share(frs, fr_space)
      let pod = @library.LayoutRegion::new(
        @library.Axes::new(region.size.x, length),
        region.expand,
      )
      let frame = single.layout(self.composer.engine, pod)
      self.used = { ..self.used, x: self.used.x.max(frame.width()), }
      fr_frames.push(frame)
    }
  }

  // Also consider the width of insertions for alignment.
  if !region.expand.x {
    self.used = {
      ..self.used,
      x: self.used.x.max(self.composer.insertion_width()),
    }
  }

  // Determine the region's size.
  let size = region.expand.select(region.size, self.used.min(region.size))
  let free = size.y - self.used.y
  let output = @library.Frame::soft(size)
  let mut ruler : @library.FixedAlignment = Start
  let mut offset = @library.Abs::zero()
  let mut fr_index = 0

  // Position all items.
  let mut baseline_set = false
  for item in self.items {
    match item {
      Tag(tag) => {
        let y = offset + ruler.position(free)
        let pos = @library.Point::with_y(y)
        output.push(pos, Tag(tag))
      }
      Abs(v, _) => offset = offset + v
      Fr(v, _, single) => {
        let length = v.share(frs, fr_space)
        if single is Some(single) {
          let frame = fr_frames[fr_index]
          fr_index += 1
          let x = single.align.x.position(size.x - frame.width())
          let pos = @library.Point::new(x, offset)
          output.push_frame(pos, frame)
        }
        offset = offset + length
      }
      Frame(frame, align) => {
        ruler = fixed_align_max(ruler, align.y)
        let x = align.x.position(size.x - frame.width())
        let y = offset + ruler.position(free)
        let pos = @library.Point::new(x, y)
        offset = offset + frame.height()

        // The baseline of the whole region will be the set to the baseline
        // of the first in-flow frame. For example, of the first paragraph, if
        // there is more than one. But also, inside the paragraph itself, this
        // will be the first line (since each line is laid out as a separate
        // frame).
        if !baseline_set {
          if frame.has_baseline() {
            output.set_baseline(y + frame.baseline())
          }
          baseline_set = true
        }
        output.push_frame(pos, frame)
      }
      Placed(frame, placed) => {
        let x = placed.align_x.position(size.x - frame.width())
        let y = match placed.align_y.unwrap_or(None) {
          Some(align) => align.position(size.y - frame.height())
          _ => offset + ruler.position(free)
        }
        let pos = @library.Point::new(x, y) +
          placed.delta.relative_to(size).to_point()
        output.push_frame(pos, frame)
      }
    }
  }
  (output, used_height_without_fr)
}

///|
/// Create a snapshot of the work and items.
fn Distributor::snapshot(self : Distributor) -> DistributionSnapshot {
  {
    work: self.composer.work.clone(),
    items: self.items.length(),
    used: self.used,
  }
}

///|
/// Restore a snapshot of the work and items.
fn Distributor::restore(
  self : Distributor,
  snapshot : DistributionSnapshot,
) -> Unit {
  self.composer.work.restore(snapshot.work)
  self.items.truncate(snapshot.items)
  self.used = snapshot.used
}

///|
/// Upstream `Ord::max` of fixed alignments (`Start < Center < End`).
fn fixed_align_max(
  a : @library.FixedAlignment,
  b : @library.FixedAlignment,
) -> @library.FixedAlignment {
  if a.compare(b) > 0 {
    a
  } else {
    b
  }
}

///|
/// Upstream `Ord::min` of fixed alignments.
fn fixed_align_min(
  a : @library.FixedAlignment,
  b : @library.FixedAlignment,
) -> @library.FixedAlignment {
  if a.compare(b) <= 0 {
    a
  } else {
    b
  }
}
