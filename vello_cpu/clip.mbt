// Port of `vello_common/src/clip.rs` (managing clipping state and
// intersecting sparse strip paths) and `vello_cpu/src/clip.rs` (the clip
// state of the render context; filter surfaces are not supported, so the
// active shift is always the identity).

///|
priv struct ClipData {
  alpha_start : Int
  strip_start : Int
  /// A coarse bounding box of the clip path in pixel coordinates, already
  /// intersected with the viewport.
  bbox : RectU16
}

///|
/// Borrowed data of a stripped path.
priv struct PathDataRef {
  strips : Array[Strip]
  strip_start : Int
  strip_end : Int
  alphas : Array[Byte]
  alpha_start : Int
  /// A coarse bounding box of the clip path in pixel coordinates.
  bbox : RectU16
}

///|
fn PathDataRef::strip(self : PathDataRef, i : Int) -> Strip {
  self.strips[self.strip_start + i]
}

///|
fn PathDataRef::strips_len(self : PathDataRef) -> Int {
  self.strip_end - self.strip_start
}

///|
fn ClipData::to_path_data_ref(
  self : ClipData,
  storage : StripStorage,
) -> PathDataRef {
  {
    strips: storage.strips,
    strip_start: min_int(self.strip_start, storage.strips.length()),
    strip_end: storage.strips.length(),
    alphas: storage.alphas,
    alpha_start: min_int(self.alpha_start, storage.alphas.length()),
    bbox: self.bbox,
  }
}

///|
/// A context for managing clip stacks.
priv struct ClipContext {
  storage : StripStorage
  temp_storage : StripStorage
  clip_stack : Array[ClipData]
}

///|
fn ClipContext::new() -> ClipContext {
  {
    storage: StripStorage::new(Append),
    temp_storage: StripStorage::new(Replace),
    clip_stack: [],
  }
}

///|
/// Get the data of the current clip path.
fn ClipContext::get(self : ClipContext) -> PathDataRef? {
  match self.clip_stack.last() {
    Some(c) => Some(c.to_path_data_ref(self.storage))
    None => None
  }
}

///|
/// Push a new clip path to the stack.
fn ClipContext::push_clip(
  self : ClipContext,
  clip_path : Array[@kurbo.PathEl],
  strip_generator : StripGenerator,
  fill_rule : Fill,
  transform : @kurbo.Affine,
  aliasing_threshold : Int?,
) -> Unit {
  self.temp_storage.clear()
  let alpha_start = self.storage.alphas.length()
  let strip_start = self.storage.strips.length()
  // Calculate a coarse bounding box of the path.
  let bbox = control_point_bbox_u16(clip_path, transform)
  // Intersect with the existing clip bounding box, or the viewport if this
  // is the outermost clip.
  let bbox = match self.clip_stack.last() {
    Some(existing) => bbox.intersect(existing.bbox)
    None => {
      bbox.x1 = min_int(bbox.x1, strip_generator.width)
      bbox.y1 = min_int(bbox.y1, strip_generator.height)
      bbox
    }
  }
  let clip_data = { alpha_start, strip_start, bbox, }
  let existing_clip = self.get()
  strip_generator.generate_filled_path(
    clip_path,
    fill_rule,
    transform,
    aliasing_threshold,
    self.temp_storage,
    existing_clip,
  )
  self.storage.append(self.temp_storage)
  self.clip_stack.push(clip_data)
}

///|
/// Pop the least recent clip path.
fn ClipContext::pop_clip(self : ClipContext) -> Unit {
  guard self.clip_stack.pop() is Some(data) else {
    abort("clip stack underflowed")
  }
  self.storage.strips.truncate(data.strip_start)
  self.storage.alphas.truncate(data.alpha_start)
}

///|
/// Compute a conservative bounding box for the transformed path by computing
/// the bounding box of the transformed control points.
fn control_point_bbox(
  path : Array[@kurbo.PathEl],
  transform : @kurbo.Affine,
) -> @kurbo.Rect {
  let inf = @double.infinity
  let mut x0 = inf
  let mut y0 = inf
  let mut x1 = -inf
  let mut y1 = -inf
  let add = (p : @kurbo.Point) => {
    let p = transform.apply(p)
    // `Rect::union_pt`.
    x0 = @kurbo.f64_min(x0, p.x)
    y0 = @kurbo.f64_min(y0, p.y)
    x1 = @kurbo.f64_max(x1, p.x)
    y1 = @kurbo.f64_max(y1, p.y)
  }
  for el in path {
    match el {
      MoveTo(p) | LineTo(p) => add(p)
      QuadTo(p1, p2) => {
        add(p1)
        add(p2)
      }
      CurveTo(p1, p2, p3) => {
        add(p1)
        add(p2)
        add(p3)
      }
      ClosePath => ()
    }
  }
  @kurbo.Rect::new(x0, y0, x1, y1)
}

///|
/// Compute a conservative bounding box for the transformed path in pixel
/// coordinates.
fn control_point_bbox_u16(
  path : Array[@kurbo.PathEl],
  transform : @kurbo.Affine,
) -> RectU16 {
  let bbox = control_point_bbox(path, transform)
  RectU16::new(
    f64_as_u16(bbox.x0),
    f64_as_u16(bbox.y0),
    f64_as_u16(bbox.x1.ceil()),
    f64_as_u16(bbox.y1.ceil()),
  )
}

///|
/// Compute the sparse strips representation of a path that results from
/// intersecting the two input paths. This can be used to implement clip
/// paths.
fn intersect(
  path_1 : PathDataRef,
  path_2 : PathDataRef,
  target : StripStorage,
) -> Unit {
  // In case either path is empty, the clip path should be empty.
  if path_1.strips_len() == 0 || path_2.strips_len() == 0 {
    return
  }
  // Ignore any y values that are outside the bounding box of either of the
  // two paths.
  let path_1_start_y = path_1.strip(0).strip_y()
  let path_2_start_y = path_2.strip(0).strip_y()
  let mut cur_y = max_int(path_1_start_y, path_2_start_y)
  let end_y = min_int(
    path_1.strip(path_1.strips_len() - 1).strip_y(),
    path_2.strip(path_2.strips_len() - 1).strip_y(),
  )
  let path_1_idx = Ref::new(0)
  let path_2_idx = Ref::new(0)
  // Use binary search to determine the first index of whichever path has a
  // smaller y.
  if path_1_start_y < cur_y {
    path_1_idx.val = first_strip_at_or_after(path_1, cur_y)
  } else if path_2_start_y < cur_y {
    path_2_idx.val = first_strip_at_or_after(path_2, cur_y)
  }
  let strip_state : Ref[StripState?] = Ref::new(None)
  // Iterate over each strip row and handle them.
  while cur_y <= end_y {
    let p1_iter = RowIterator::new(path_1, path_1_idx, cur_y)
    let p2_iter = RowIterator::new(path_2, path_2_idx, cur_y)
    let mut p1_region = p1_iter.next()
    let mut p2_region = p2_iter.next()
    while true {
      guard p1_region is Some(region_1) && p2_region is Some(region_2) else {
        break
      }
      match region_1.overlap_relationship(region_2) {
        // No overlap; advance the iterator of the region further behind.
        Advance(advance) => {
          match advance {
            Left => p1_region = p1_iter.next()
            Right => p2_region = p2_iter.next()
          }
          continue
        }
        Overlap(start~, end~, advance~) => {
          match (region_1, region_2) {
            // Both regions are a fill.
            (FillRegion(_), FillRegion(_)) => {
              flush_strip(strip_state, target.strips, cur_y)
              start_strip(strip_state, target.alphas, end, true)
            }
            // One fill one strip, so we simply use the alpha mask from the
            // strip region.
            (StripRegion(s_start, _, s_alphas, s_alpha_off), FillRegion(_))
            | (FillRegion(_), StripRegion(s_start, _, s_alphas, s_alpha_off)) => {
              if should_create_new_strip(strip_state, target.alphas, start) {
                flush_strip(strip_state, target.strips, cur_y)
                start_strip(strip_state, target.alphas, start, false)
              }
              let off = s_alpha_off + (start - s_start) * 4
              for k in 0..<((end - start) * 4) {
                target.alphas.push(s_alphas[off + k])
              }
            }
            // Two strips, we need to multiply the opacity masks from both
            // paths.
            (
              StripRegion(s1_start, _, s1_alphas, s1_off),
              StripRegion(s2_start, _, s2_alphas, s2_off),
            ) => {
              if should_create_new_strip(strip_state, target.alphas, start) {
                flush_strip(strip_state, target.strips, cur_y)
                start_strip(strip_state, target.alphas, start, false)
              }
              let num_blocks = (end - start) / TILE_HEIGHT
              let o1 = s1_off + (start - s1_start) * 4
              let o2 = s2_off + (start - s2_start) * 4
              for k in 0..<(num_blocks * 16) {
                let a = s1_alphas[o1 + k].to_int()
                let b = s2_alphas[o2 + k].to_int()
                target.alphas.push((norm_mul(a, b) & 0xFF).to_byte())
              }
            }
          }
          // Advance the iterator of the path whose region's end is further
          // behind.
          match advance {
            Left => p1_region = p1_iter.next()
            Right => p2_region = p2_iter.next()
          }
        }
      }
    }
    // Flush the strip before advancing to the next strip row.
    flush_strip(strip_state, target.strips, cur_y)
    cur_y += 1
  }
  // Push the sentinel strip, if one wasn't already pushed.
  let has_sentinel = match target.strips.last() {
    Some(s) => s.is_sentinel()
    None => false
  }
  if !has_sentinel {
    target.strips.push(
      Strip::new(
        65535,
        (end_y * TILE_HEIGHT) & 0xFFFF,
        target.alphas.length(),
        false,
      ),
    )
  }
}

///|
fn first_strip_at_or_after(path : PathDataRef, strip_y : Int) -> Int {
  // Strips are guaranteed to be sorted in ascending y (and ascending x).
  let mut lo = 0
  let mut hi = path.strips_len()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if path.strip(mid).strip_y() < strip_y {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
priv enum Advance {
  Left
  Right
}

///|
/// The relationship between two regions.
priv enum OverlapRelationship {
  /// There is no overlap between the regions, advance the region iterator
  /// on the given side.
  Advance(Advance)
  /// There is an overlap between the regions.
  Overlap(start~ : Int, end~ : Int, advance~ : Advance)
}

///|
priv enum ClipRegion {
  /// A fill region (start in the low, width in the high 16 bits).
  FillRegion(Int)
  /// A strip region (start, width, alphas, alpha offset).
  StripRegion(Int, Int, Array[Byte], Int)
}

///|
fn ClipRegion::overlap_relationship(
  self : ClipRegion,
  other : ClipRegion,
) -> OverlapRelationship {
  let (s_start, s_width) = region_dims(self)
  let (o_start, o_width) = region_dims(other)
  let s_end = (s_start + s_width) & 0xFFFF
  let o_end = (o_start + o_width) & 0xFFFF
  if s_end <= o_start {
    Advance(Left)
  } else if s_start >= o_end {
    Advance(Right)
  } else {
    let start = max_int(s_start, o_start)
    let end = min_int(s_end, o_end)
    let shift = if s_end <= o_end { Left } else { Right }
    Overlap(start~, end~, advance=shift)
  }
}

///|
/// The start and width of a region. Fill regions store their start in the
/// low and their width in the high 16 bits.
fn region_dims(r : ClipRegion) -> (Int, Int) {
  match r {
    FillRegion(packed) => (packed & 0xFFFF, packed >> 16)
    StripRegion(start, width, _, _) => (start, width)
  }
}

///|
/// An iterator of strip and fill regions of a single strip row.
priv struct RowIterator {
  /// The path in question.
  input : PathDataRef
  /// The strip row we want to iterate over.
  strip_y : Int
  /// The index of the current strip.
  cur_idx : Ref[Int]
  /// Whether the iterator should yield a strip next or not.
  mut on_strip : Bool
}

///|
fn RowIterator::new(
  input : PathDataRef,
  cur_idx : Ref[Int],
  strip_y : Int,
) -> RowIterator {
  // Forward the index until we have found the right strip.
  while input.strip(cur_idx.val).strip_y() < strip_y {
    cur_idx.val += 1
  }
  { input, cur_idx, strip_y, on_strip: true, }
}

///|
fn RowIterator::cur_strip(self : RowIterator) -> Strip {
  self.input.strip(self.cur_idx.val)
}

///|
fn RowIterator::next_strip(self : RowIterator) -> Strip {
  self.input.strip(self.cur_idx.val + 1)
}

///|
fn RowIterator::cur_strip_width(self : RowIterator) -> Int {
  let cur = self.cur_strip()
  let next = self.next_strip()
  ((next.alpha_idx() - cur.alpha_idx()) / TILE_HEIGHT) & 0xFFFF
}

///|
fn RowIterator::cur_strip_fill_area(self : RowIterator) -> Int? {
  let next = self.next_strip()
  // Note that if the next strip happens to be on the next line, it will
  // always have zero winding so we don't need to special case this.
  if next.fill_gap() {
    let cur = self.cur_strip()
    let x = (cur.x + self.cur_strip_width()) & 0xFFFF
    let width = (next.x - x) & 0xFFFF
    if width > 0 {
      Some(x | (width << 16))
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn RowIterator::next(self : RowIterator) -> ClipRegion? {
  // If we are currently not on a strip, we want to yield a filled region in
  // case there is one.
  if !self.on_strip {
    self.on_strip = true
    if self.cur_strip_fill_area() is Some(fill_area) {
      self.cur_idx.val += 1
      return Some(FillRegion(fill_area))
    } else {
      self.cur_idx.val += 1
    }
  }
  self.on_strip = false
  // If the current strip is sentinel or not within our target row,
  // terminate.
  let cur = self.cur_strip()
  if cur.is_sentinel() || cur.strip_y() != self.strip_y {
    return None
  }
  let x = cur.x
  let width = self.cur_strip_width()
  Some(
    StripRegion(
      x,
      width,
      self.input.alphas,
      self.input.alpha_start + cur.alpha_idx(),
    ),
  )
}

///|
/// The data of the current strip we are building.
priv struct StripState {
  x : Int
  alpha_idx : Int
  fill_gap : Bool
}

///|
fn flush_strip(
  strip_state : Ref[StripState?],
  strips : Array[Strip],
  cur_y : Int,
) -> Unit {
  if strip_state.val is Some(state) {
    strip_state.val = None
    strips.push(
      Strip::new(
        state.x,
        (cur_y * TILE_HEIGHT) & 0xFFFF,
        state.alpha_idx,
        state.fill_gap,
      ),
    )
  }
}

///|
fn start_strip(
  strip_data : Ref[StripState?],
  alphas : Array[Byte],
  x : Int,
  fill_gap : Bool,
) -> Unit {
  strip_data.val = Some({ x, alpha_idx: alphas.length(), fill_gap, })
}

///|
fn should_create_new_strip(
  strip_state : Ref[StripState?],
  alphas : Array[Byte],
  overlap_start : Int,
) -> Bool {
  // Returns false in case we can append to the currently built strip.
  match strip_state.val {
    None => true
    Some(state) => {
      let width = ((alphas.length() - state.alpha_idx) / TILE_HEIGHT) & 0xFFFF
      let strip_end = (state.x + width) & 0xFFFF
      strip_end < ((overlap_start - 1) & 0xFFFF)
    }
  }
}

///|
/// State for managing clip paths (`vello_cpu::clip::ClipState`).
///
/// Filter surfaces are not supported, so the raw clip paths that upstream
/// keeps to rebuild the clip context for a shifted viewport are not needed.
priv struct ClipState {
  /// The currently active clip context.
  context : ClipContext
}

///|
fn ClipState::new() -> ClipState {
  { context: ClipContext::new(), }
}

///|
fn ClipState::get(self : ClipState) -> PathDataRef? {
  self.context.get()
}

///|
fn ClipState::push_clip(
  self : ClipState,
  path : @kurbo.BezPath,
  strip_generator : StripGenerator,
  fill_rule : Fill,
  transform : @kurbo.Affine,
  aliasing_threshold : Int?,
) -> Unit {
  // `self.active_shift() * transform`, with the identity shift.
  let clip_transform = @kurbo.Affine::identity() * transform
  self.context.push_clip(
    path.elements(),
    strip_generator,
    fill_rule,
    clip_transform,
    aliasing_threshold,
  )
}

///|
fn ClipState::pop_clip(self : ClipState) -> Unit {
  self.context.pop_clip()
}
