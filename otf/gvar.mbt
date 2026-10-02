// A [Glyph Variations Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/gvar) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/gvar.rs` (with the `gvar-alloc`
// feature, which Typst's dependency graph enables: the number of tuples is
// unbounded).

// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#tuple-variation-store

///|
/// 'The TrueType rasterizer dynamically generates 'phantom' points for each glyph
/// that represent horizontal and vertical advance widths and side bearings,
/// and the variation data within the `gvar` table includes data for these phantom points.'
///
/// We don't actually use them, but they are required during deltas parsing.
let phantom_points_len : UInt16 = 4

///|
priv enum GlyphVariationDataOffsets {
  Short(LazyArray16[Offset16])
  Long(LazyArray16[Offset32])
}

///|
priv struct PointAndDelta {
  x : Int16
  y : Int16
  x_delta : Float
  y_delta : Float
}

///|
priv struct VariationTuple {
  set_points : SetPointsIter?
  deltas : PackedDeltasIter
  /// The last parsed point with delta in the contour.
  /// Used during delta resolving.
  mut prev_point : PointAndDelta?
}

///|
/// A list of variation tuples.
priv struct VariationTuples {
  vec : Array[VariationTuple]
}

///|
fn VariationTuples::new() -> VariationTuples {
  { vec: [], }
}

///|
fn VariationTuples::push(
  self : VariationTuples,
  header : VariationTuple,
) -> Unit {
  self.vec.push(header)
}

///|
fn VariationTuples::clear(self : VariationTuples) -> Unit {
  self.vec.clear()
}

///|
fn VariationTuples::apply(
  self : VariationTuples,
  all_points : GlyphPointsIter,
  points : GlyphPointsIter,
  point : GlyphPoint,
) -> PointF? {
  let mut x = Float::from_int(point.x.to_int())
  let mut y = Float::from_int(point.y.to_int())
  for tuple in self.vec {
    if tuple.set_points is Some(set_points) {
      if set_points.next() {
        if tuple.deltas.next() is Some((x_delta, y_delta)) {
          // Remember the last set point and delta.
          tuple.prev_point = Some({ x: point.x, y: point.y, x_delta, y_delta, })
          x += x_delta
          y += y_delta
        } else {
          // If there are no more deltas, we have to resolve them manually.
          let set_points = set_points.copy()
          let (x_delta, y_delta) = infer_deltas(
            tuple,
            set_points,
            points.copy(),
            all_points.copy(),
            point,
          )
          x += x_delta
          y += y_delta
        }
      } else {
        // Point is not referenced, so we have to resolve it.
        let set_points = set_points.copy()
        let (x_delta, y_delta) = infer_deltas(
          tuple,
          set_points,
          points.copy(),
          all_points.copy(),
          point,
        )
        x += x_delta
        y += y_delta
      }
      if point.last_point {
        tuple.prev_point = None
      }
    } else if tuple.deltas.next() is Some((x_delta, y_delta)) {
      x += x_delta
      y += y_delta
    }
  }
  Some({ x, y, })
}

///|
// This is just like `apply()`, but without `infer_deltas`,
// since we use it only for component points and not a contour.
// And since there are no contour and no points, `infer_deltas()` will do nothing.
fn VariationTuples::apply_null(self : VariationTuples) -> PointF? {
  let mut x : Float = 0.0
  let mut y : Float = 0.0
  for tuple in self.vec {
    if tuple.set_points is Some(set_points) {
      if set_points.next() {
        if tuple.deltas.next() is Some((x_delta, y_delta)) {
          x += x_delta
          y += y_delta
        }
      }
    } else if tuple.deltas.next() is Some((x_delta, y_delta)) {
      x += x_delta
      y += y_delta
    }
  }
  Some({ x, y, })
}

///|
priv struct TupleVariationHeaderData {
  mut scalar : Float
  has_private_point_numbers : Bool
  serialized_data_len : UInt16
}

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#tuplevariationheader
fn parse_variation_tuples(
  count : UInt16,
  coordinates : ArrayView[NormalizedCoordinate],
  shared_tuple_records : LazyArray16[F2DOT14],
  shared_point_numbers : PackedPointsIter?,
  points_len : UInt16,
  main_s : Stream,
  serialized_s : Stream,
  tuples : VariationTuples,
) -> Unit raise Malformed {
  // `TupleVariationHeader` has a variable size, so we cannot use a `LazyArray`.
  for _ in 0..<count.to_int() {
    let header = parse_tuple_variation_header(
      coordinates, shared_tuple_records, main_s,
    )
    if !(header.scalar > 0.0) {
      // Serialized data for headers with non-positive scalar should be skipped.
      serialized_s.advance(header.serialized_data_len.to_int())
      continue
    }
    let serialized_data_start = serialized_s.offset()

    // Resolve point numbers source.
    let point_numbers = if header.has_private_point_numbers {
      PackedPointsIter::new(serialized_s)
    } else {
      shared_point_numbers.map(p => p.copy())
    }

    // TODO: this
    // Since the packed representation can include zero values,
    // it is possible for a given point number to be repeated in the derived point number list.
    // In that case, there will be multiple delta values in the deltas data
    // associated with that point number. All of these deltas must be applied
    // cumulatively to the given point.
    let deltas_count = if point_numbers is Some(point_numbers) {
      req(u16_try_from_int(point_numbers.copy().count()))
    } else {
      points_len
    }
    let deltas = {
      // Use `checked_sub` in case we went over the `serialized_data_len`.
      let left = req(
        usize_checked_sub(
          header.serialized_data_len.to_int(),
          serialized_s.offset() - serialized_data_start,
        ),
      )
      let deltas_data = serialized_s.read_bytes(left)
      PackedDeltasIter::new(header.scalar, deltas_count, deltas_data)
    }
    let tuple : VariationTuple = {
      set_points: point_numbers.map(SetPointsIter::new),
      deltas,
      prev_point: None,
    }
    tuples.push(tuple)
  }
}

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#tuplevariationheader
fn parse_tuple_variation_header(
  coordinates : ArrayView[NormalizedCoordinate],
  shared_tuple_records : LazyArray16[F2DOT14],
  s : Stream,
) -> TupleVariationHeaderData raise Malformed {
  let embedded_peak_tuple_flag : UInt16 = 0x8000
  let intermediate_region_flag : UInt16 = 0x4000
  let private_point_numbers_flag : UInt16 = 0x2000
  let tuple_index_mask : UInt16 = 0x0FFF
  let serialized_data_size = s.read_u16()
  let tuple_index = s.read_u16()
  let has_embedded_peak_tuple = (tuple_index & embedded_peak_tuple_flag) != 0
  let has_intermediate_region = (tuple_index & intermediate_region_flag) != 0
  let has_private_point_numbers = (tuple_index & private_point_numbers_flag) !=
    0
  let tuple_index = tuple_index & tuple_index_mask
  let axis_count = coordinates.length().to_uint16()
  let peak_tuple : LazyArray16[F2DOT14] = if has_embedded_peak_tuple {
    s.read_array16(axis_count)
  } else {
    // Use shared tuples.
    let start = req(u16_checked_mul(tuple_index, axis_count))
    let end = req(u16_checked_add(start, axis_count))
    req(shared_tuple_records.slice(start, end))
  }
  let (start_tuple, end_tuple) : (LazyArray16[F2DOT14], LazyArray16[F2DOT14]) = if has_intermediate_region {
    let a = s.read_array16(axis_count)
    let b = s.read_array16(axis_count)
    (a, b)
  } else {
    (LazyArray16::default(), LazyArray16::default())
  }
  let header : TupleVariationHeaderData = {
    scalar: 0.0,
    has_private_point_numbers,
    serialized_data_len: serialized_data_size,
  }

  // Calculate the scalar value according to the pseudo-code described at:
  // https://docs.microsoft.com/en-us/typography/opentype/spec/otvaroverview#algorithm-for-interpolation-of-instance-values
  let mut scalar : Float = 1.0
  for i in 0..<axis_count.to_int() {
    let v = coordinates[i].get()
    let peak = req(peak_tuple.get(i.to_uint16())).0
    if peak == 0 || v == peak {
      continue
    }
    if has_intermediate_region {
      let start = req(start_tuple.get(i.to_uint16())).0
      let end = req(end_tuple.get(i.to_uint16())).0
      if start > peak || peak > end || (start < 0 && end > 0 && peak != 0) {
        continue
      }
      if v < start || v > end {
        return header
      }
      if v < peak {
        if peak != start {
          scalar *= Float::from_int((v - start).to_int()) /
            Float::from_int((peak - start).to_int())
        }
      } else if peak != end {
        scalar *= Float::from_int((end - v).to_int()) /
          Float::from_int((end - peak).to_int())
      }
    } else if v == 0 ||
      v < (if peak < 0 { peak } else { 0 }) ||
      v > (if peak > 0 { peak } else { 0 }) {
      // 'If the instance coordinate is out of range for some axis, then the
      // region and its associated deltas are not applicable.'
      return header
    } else {
      scalar *= Float::from_int(v.to_int()) / Float::from_int(peak.to_int())
    }
  }
  header.scalar = scalar
  header
}

// ---------------------------------------------------------------------------
// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#packed-point-numbers

///|
let points_are_words_flag : Int = 0x80

///|
let point_run_count_mask : Int = 0x7F

///|
priv enum PackedPointsState {
  Control
  ShortPoint
  LongPoint
} derive(Eq)

///|
// This structure will be used by the `VariationTuples` stack buffer,
// so it has to be as small as possible.
// Therefore we cannot use `Stream` and other abstractions.
priv struct PackedPointsIter {
  data : BytesView
  // u16 is enough, since the maximum number of points is 32767.
  mut offset : UInt16
  mut state : PackedPointsState
  mut points_left : Byte
}

///|
fn PackedPointsIter::copy(self : PackedPointsIter) -> PackedPointsIter {
  {
    data: self.data,
    offset: self.offset,
    state: self.state,
    points_left: self.points_left,
  }
}

///|
// Raises on a parsing error; `None` indicates "no points".
fn PackedPointsIter::new(s : Stream) -> PackedPointsIter? raise Malformed {
  // The total amount of points can be set as one or two bytes
  // depending on the first bit.
  let b1 = s.read_u8().to_int()
  let mut count = b1
  if (b1 & points_are_words_flag) != 0 {
    let b2 = s.read_u8().to_int()
    count = ((b1 & point_run_count_mask) << 8) | b2
  }
  if count == 0 {
    // No points is not an error.
    return None
  }
  let start = s.offset()
  let tail = s.tail_r()

  // The actual packed points data size is not stored,
  // so we have to parse the points first to advance the provided stream.
  // Since deltas will be right after points.
  let mut i = 0
  while i < count {
    let control = s.read_u8().to_int()
    let run_count = (control & point_run_count_mask) + 1
    let is_points_are_words = (control & points_are_words_flag) != 0
    // Do not actually parse the number, simply advance.
    s.advance_checked((if is_points_are_words { 2 } else { 1 }) * run_count)
    i += run_count
  }
  if i == 0 {
    // No points is not an error.
    return None
  }
  if i > count {
    // Malformed font.
    raise Malformed
  }

  // Check that points data size is smaller than the storage type
  // used by the iterator.
  let data_len = s.offset() - start
  if data_len > 0xFFFF {
    raise Malformed
  }
  Some({ data: tail[0:data_len], offset: 0, state: Control, points_left: 0, })
}

///|
fn PackedPointsIter::next(self : PackedPointsIter) -> UInt16? {
  if self.offset.to_int() >= self.data.length() {
    return None
  }
  if self.state == Control {
    let control = self.data[self.offset.to_int()].to_int()
    self.offset += 1
    self.points_left = ((control & point_run_count_mask) + 1).to_byte()
    self.state = if (control & points_are_words_flag) != 0 {
      LongPoint
    } else {
      ShortPoint
    }
    self.next()
  } else {
    guard Stream::new_at(self.data, self.offset.to_int()) is Some(s) else {
      return None
    }
    let point = if self.state == LongPoint {
      self.offset += 2
      s.read_u16() catch {
        _ => return None
      }
    } else {
      self.offset += 1
      u16_from_u8(s.read_u8() catch { _ => return None })
    }
    self.points_left -= 1
    if self.points_left == 0 {
      self.state = Control
    }
    Some(point)
  }
}

///|
fn PackedPointsIter::count(self : PackedPointsIter) -> Int {
  let mut n = 0
  while self.next() is Some(_) {
    n += 1
  }
  n
}

///|
// The `PackedPointsIter` will return referenced point numbers as deltas.
// i.e. 1 2 4 is actually 1 3 7
// But this is not very useful in our current algorithm,
// so we will convert it once again into:
// false true false true false false false true
// This way we can iterate glyph points and point numbers in parallel.
priv struct SetPointsIter {
  iter : PackedPointsIter
  mut unref_count : UInt16
}

///|
fn SetPointsIter::new(iter : PackedPointsIter) -> SetPointsIter {
  let unref_count = iter.next().unwrap_or(0)
  { iter, unref_count, }
}

///|
fn SetPointsIter::copy(self : SetPointsIter) -> SetPointsIter {
  { iter: self.iter.copy(), unref_count: self.unref_count, }
}

///|
fn SetPointsIter::restart(self : SetPointsIter) -> SetPointsIter {
  let iter = self.iter.copy()
  iter.offset = 0
  iter.state = Control
  iter.points_left = 0
  let unref_count = iter.next().unwrap_or(0)
  { iter, unref_count, }
}

///|
/// Always returns a value (`Some(true)` after the end), like upstream.
fn SetPointsIter::next(self : SetPointsIter) -> Bool {
  if self.unref_count != 0 {
    self.unref_count -= 1
    return false
  }
  if self.iter.next() is Some(unref_count) {
    self.unref_count = unref_count
    if self.unref_count != 0 {
      self.unref_count -= 1
    }
  }

  // Iterator will be returning `Some(true)` after "finished".
  // This is because this iterator will be zipped with the `glyf::GlyphPointsIter`
  // and the number of glyph points can be larger than the amount of set points.
  // Anyway, this is a non-issue in a well-formed font.
  true
}

// ---------------------------------------------------------------------------
// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#packed-deltas

///|
let deltas_are_zero_flag : Int = 0x80

///|
let deltas_are_words_flag : Int = 0x40

///|
let delta_run_count_mask : Int = 0x3F

///|
priv enum PackedDeltasState {
  Control
  ZeroDelta
  ShortDelta
  LongDelta
} derive(Eq)

///|
priv struct RunState {
  mut data_offset : UInt16
  mut state : PackedDeltasState
  mut run_deltas_left : Byte
}

///|
fn RunState::default() -> RunState {
  { data_offset: 0, state: Control, run_deltas_left: 0, }
}

///|
fn RunState::copy(self : RunState) -> RunState {
  {
    data_offset: self.data_offset,
    state: self.state,
    run_deltas_left: self.run_deltas_left,
  }
}

///|
fn RunState::next(self : RunState, data : BytesView, scalar : Float) -> Float? {
  if self.state == Control {
    if self.data_offset.to_int() == data.length() {
      return None
    }
    let control : Byte = Stream::read_at(data, self.data_offset.to_int()) catch {
      _ => return None
    }
    let control = control.to_int()
    self.data_offset += 1
    self.run_deltas_left = ((control & delta_run_count_mask) + 1).to_byte()
    self.state = if (control & deltas_are_zero_flag) != 0 {
      ZeroDelta
    } else if (control & deltas_are_words_flag) != 0 {
      LongDelta
    } else {
      ShortDelta
    }
    self.next(data, scalar)
  } else {
    guard Stream::new_at(data, self.data_offset.to_int()) is Some(s) else {
      return None
    }
    let delta : Float = if self.state == LongDelta {
      self.data_offset += 2
      Float::from_int((s.read_i16() catch { _ => return None }).to_int()) *
      scalar
    } else if self.state == ZeroDelta {
      0.0
    } else {
      self.data_offset += 1
      Float::from_int(s.read_i8() catch { _ => return None }) * scalar
    }
    self.run_deltas_left -= 1
    if self.run_deltas_left == 0 {
      self.state = Control
    }
    Some(delta)
  }
}

///|
// This structure will be used by the `VariationTuples` stack buffer,
// so it has to be as small as possible.
// Therefore we cannot use `Stream` and other abstractions.
priv struct PackedDeltasIter {
  data : BytesView
  x_run : RunState
  y_run : RunState
  /// A total number of deltas per axis.
  ///
  /// Required only by restart()
  total_count : UInt16
  scalar : Float
}

///|
/// `count` indicates a number of delta pairs.
fn PackedDeltasIter::new(
  scalar : Float,
  count : UInt16,
  data : BytesView,
) -> PackedDeltasIter {
  let iter : PackedDeltasIter = {
    data,
    total_count: count,
    scalar,
    x_run: RunState::default(),
    y_run: RunState::default(),
  }

  // 'The packed deltas are arranged with all of the deltas for X coordinates first,
  // followed by the deltas for Y coordinates.'
  // So we have to skip X deltas in the Y deltas iterator.
  //
  // Note that Y deltas doesn't necessarily start with a Control byte
  // and can actually start in the middle of the X run.
  // So we can't simply split the input data in half
  // and process those chunks separately.
  for _ in 0..<count.to_int() {
    iter.y_run.next(data, scalar) |> ignore
  }
  iter
}

///|
fn PackedDeltasIter::copy(self : PackedDeltasIter) -> PackedDeltasIter {
  {
    data: self.data,
    x_run: self.x_run.copy(),
    y_run: self.y_run.copy(),
    total_count: self.total_count,
    scalar: self.scalar,
  }
}

///|
fn PackedDeltasIter::restart(self : PackedDeltasIter) -> PackedDeltasIter {
  PackedDeltasIter::new(self.scalar, self.total_count, self.data)
}

///|
fn PackedDeltasIter::next(self : PackedDeltasIter) -> (Float, Float)? {
  guard self.x_run.next(self.data, self.scalar) is Some(x) else { return None }
  guard self.y_run.next(self.data, self.scalar) is Some(y) else { return None }
  Some((x, y))
}

///|
/// Infer unreferenced deltas.
///
/// A font can define deltas only for specific points, to reduce the file size.
/// In this case, we have to infer undefined/unreferenced deltas manually,
/// depending on the context.
///
/// This is already a pretty complex task, since deltas should be resolved
/// only inside the current contour (do not confuse with component).
/// And during resolving we can actually wrap around the contour.
/// So if there is no deltas after the current one, we have to use
/// the first delta of the current contour instead.
/// Same goes for the previous delta. If there are no deltas
/// before the current one, we have to use the last one in the current contour.
///
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gvar#inferred-deltas-for-un-referenced-point-numbers
fn infer_deltas(
  tuple : VariationTuple,
  points_set : SetPointsIter,
  // A points iterator that starts after the current point.
  points : GlyphPointsIter,
  // A points iterator that starts from the first point in the glyph.
  all_points : GlyphPointsIter,
  curr_point : GlyphPoint,
) -> (Float, Float) {
  let mut current_contour = points.current_contour()
  if curr_point.last_point && current_contour != 0 {
    // When we parsed the last point of a contour,
    // an iterator had switched to the next contour.
    // So we have to move to the previous one.
    current_contour -= 1
  }
  let prev_point = match tuple.prev_point {
    // If a contour already had a delta - just use it.
    Some(prev_point) => prev_point
    None => {
      // If not, find the last point with delta in the current contour.
      let mut last_point = None
      let deltas = tuple.deltas.copy()
      let pts = points.copy()
      let set = points_set.copy()
      while pts.next() is Some(point) {
        let is_set = set.next()
        if is_set {
          if deltas.next() is Some((x_delta, y_delta)) {
            last_point = Some({ x: point.x, y: point.y, x_delta, y_delta, })
          }
        }
        if point.last_point {
          break
        }
      }

      // If there is no last point, there are no deltas.
      match last_point {
        Some(p) => p
        None => return (0.0, 0.0)
      }
    }
  }
  let mut next_point : PointAndDelta? = None
  if !curr_point.last_point {
    // If the current point is not the last one in the contour,
    // find the first set delta in the current contour.
    let deltas = tuple.deltas.copy()
    let pts = points.copy()
    let set = points_set.copy()
    while pts.next() is Some(point) {
      let is_set = set.next()
      if is_set {
        if deltas.next() is Some((x_delta, y_delta)) {
          next_point = Some({ x: point.x, y: point.y, x_delta, y_delta, })
        }
        break
      }
      if point.last_point {
        break
      }
    }
  }
  if next_point is None {
    // If there were no deltas after the current point,
    // restart from the start of the contour.
    //
    // This is probably the most expensive branch,
    // but nothing we can do about it since `glyf`/`gvar` data structure
    // doesn't allow implementing a reverse iterator.
    // So we have to parse everything once again.
    let all_points = all_points.copy()
    let deltas = tuple.deltas.copy().restart()
    let points_set = points_set.copy().restart()
    let mut contour : UInt16 = 0
    while true {
      let p = all_points.next()
      let is_set = points_set.next()
      guard p is Some(point) else { break }
      // First, we have to skip already processed contours.
      if contour != current_contour {
        if is_set {
          let _ = deltas.next()
        }
        contour = all_points.current_contour()
        continue
      }
      if is_set {
        let (x_delta, y_delta) = deltas.next().unwrap_or((0.0, 0.0))
        next_point = Some({ x: point.x, y: point.y, x_delta, y_delta, })
        break
      }
      if point.last_point {
        break
      }
    }
  }

  // If there is no next point, there are no deltas.
  let next_point = match next_point {
    Some(p) => p
    None => return (0.0, 0.0)
  }
  let dx = infer_delta(
    prev_point.x,
    curr_point.x,
    next_point.x,
    prev_point.x_delta,
    next_point.x_delta,
  )
  let dy = infer_delta(
    prev_point.y,
    curr_point.y,
    next_point.y,
    prev_point.y_delta,
    next_point.y_delta,
  )
  (dx, dy)
}

///|
fn infer_delta(
  prev_point : Int16,
  target_point : Int16,
  next_point : Int16,
  prev_delta : Float,
  next_delta : Float,
) -> Float {
  let min = if prev_point < next_point { prev_point } else { next_point }
  let max = if prev_point > next_point { prev_point } else { next_point }
  if prev_point == next_point {
    if prev_delta == next_delta {
      prev_delta
    } else {
      0.0
    }
  } else if target_point <= min {
    if prev_point < next_point {
      prev_delta
    } else {
      next_delta
    }
  } else if target_point >= max {
    if prev_point > next_point {
      prev_delta
    } else {
      next_delta
    }
  } else {
    // 'Target point coordinate is between adjacent point coordinates.'
    //
    // 'Target point delta is derived from the adjacent point deltas
    // using linear interpolation.'
    let target_sub = i16_try_from_int(
      target_point.to_int() - prev_point.to_int(),
    )
    let next_sub = i16_try_from_int(next_point.to_int() - prev_point.to_int())
    let d = if (target_sub, next_sub) is (Some(target_sub), Some(next_sub)) {
      Float::from_int(target_sub.to_int()) / Float::from_int(next_sub.to_int())
    } else {
      return 0.0
    }
    (1.0 - d) * prev_delta + d * next_delta
  }
}

///|
/// A [Glyph Variations Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gvar).
struct GvarTable {
  axis_count : UInt16
  shared_tuple_records : LazyArray16[F2DOT14]
  offsets : GlyphVariationDataOffsets
  glyphs_variation_data : BytesView
}

///|
/// Parses a table from raw data.
pub fn GvarTable::parse(data : BytesView) -> GvarTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let axis_count = s.read_u16()
    let shared_tuple_count = s.read_u16()
    let shared_tuples_offset : Offset32 = s.read()
    let glyph_count = s.read_u16()
    let flags = s.read_u16()
    let glyph_variation_data_array_offset : Offset32 = s.read()

    // The axis count cannot be zero.
    if axis_count == 0 {
      return None
    }
    let shared_tuple_records = {
      let sub_s = Stream::new_at_r(data, shared_tuples_offset.to_usize())
      sub_s.read_array16(req(u16_checked_mul(shared_tuple_count, axis_count)))
    }
    let glyphs_variation_data = slice_from_r(
      data,
      glyph_variation_data_array_offset.to_usize(),
    )
    let offsets = {
      let offsets_count = req(u16_checked_add(glyph_count, 1))
      let is_long_format = (flags & 1) == 1 // The first bit indicates a long format.
      if is_long_format {
        GlyphVariationDataOffsets::Long(s.read_array16(offsets_count))
      } else {
        GlyphVariationDataOffsets::Short(s.read_array16(offsets_count))
      }
    }
    Some({ axis_count, shared_tuple_records, offsets, glyphs_variation_data, })
  } catch {
    _ => None
  }
}

///|
fn GvarTable::parse_variation_data(
  self : GvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
  points_len : UInt16,
  tuples : VariationTuples,
) -> Unit raise Malformed {
  tuples.clear()
  if coordinates.length() != self.axis_count.to_int() {
    raise Malformed
  }
  let next_glyph_id = req(u16_checked_add(glyph_id.0, 1))
  let (start, end) = match self.offsets {
    Short(array) =>
      // 'If the short format (Offset16) is used for offsets,
      // the value stored is the offset divided by 2.'
      (
        array.get_r(glyph_id.0).to_usize() * 2,
        array.get_r(next_glyph_id).to_usize() * 2,
      )
    Long(array) =>
      (
        array.get_r(glyph_id.0).to_usize(),
        array.get_r(next_glyph_id).to_usize(),
      )
  }

  // Ignore empty data.
  if start == end {
    return
  }
  let data = slice_r(self.glyphs_variation_data, start, end)
  gvar_parse_variation_data(
    coordinates,
    self.shared_tuple_records,
    points_len,
    data,
    tuples,
  )
}

///|
/// Outlines a glyph.
pub fn GvarTable::outline(
  self : GvarTable,
  glyf_table : GlyfTable,
  coordinates : ArrayView[NormalizedCoordinate],
  glyph_id : GlyphId,
  builder : &OutlineBuilder,
) -> Rect? {
  let b = GlyfBuilder::new(Transform::default(), RectF::new(), builder)
  guard glyf_table.get(glyph_id) is Some(glyph_data) else { return None }
  outline_var_impl(glyf_table, self, glyph_id, glyph_data, coordinates, 0, b) catch {
    _ => ()
  }
  b.bbox.to_rect()
}

///|
/// Parses glyph's phantom points.
pub fn GvarTable::phantom_points(
  self : GvarTable,
  glyf_table : GlyfTable,
  coordinates : ArrayView[NormalizedCoordinate],
  glyph_id : GlyphId,
) -> PhantomPoints? {
  let outline_points = glyf_table.outline_points(glyph_id)
  let tuples = VariationTuples::new()
  self.parse_variation_data(glyph_id, coordinates, outline_points, tuples) catch {
    _ => return None
  }

  // Skip all outline deltas.
  for _ in 0..<outline_points.to_int() {
    guard tuples.apply_null() is Some(_) else { return None }
  }
  guard tuples.apply_null() is Some(left) else { return None }
  guard tuples.apply_null() is Some(right) else { return None }
  guard tuples.apply_null() is Some(top) else { return None }
  guard tuples.apply_null() is Some(bottom) else { return None }
  Some({ left, right, top, bottom, })
}

///|
fn outline_var_impl(
  glyf_table : GlyfTable,
  gvar_table : GvarTable,
  glyph_id : GlyphId,
  data : BytesView,
  coordinates : ArrayView[NormalizedCoordinate],
  depth : Int,
  builder : GlyfBuilder,
) -> Unit raise Malformed {
  if depth >= glyf_max_components {
    raise Malformed
  }
  let s = Stream::new(data)
  let number_of_contours = s.read_i16()

  // Skip bbox.
  //
  // In case of a variable font, a bounding box defined in the `glyf` data
  // refers to the default variation values. Which is not what we want.
  // Instead, we have to manually calculate outline's bbox.
  s.advance(8)

  // TODO: This is the most expensive part. Find a way to allocate it only once.
  // `VariationTuples` is a very large struct, so allocate it once.
  let tuples = VariationTuples::new()
  if number_of_contours > 0 {
    // Simple glyph.
    let number_of_contours = i16_as_u16(number_of_contours)
    let glyph_points = req(parse_simple_outline(s.tail_r(), number_of_contours))
    let all_glyph_points = glyph_points.copy()
    let points_len = glyph_points.points_left
    gvar_table.parse_variation_data(glyph_id, coordinates, points_len, tuples)
    while glyph_points.next() is Some(point) {
      let p = req(
        tuples.apply(all_glyph_points.copy(), glyph_points.copy(), point),
      )
      builder.push_point(p.x, p.y, point.on_curve_point, point.last_point)
    }
  } else if number_of_contours < 0 {
    // Composite glyph.

    // In case of a composite glyph, `gvar` data contains position adjustments
    // for each component.
    // Basically, an additional translation used during transformation.
    // So we have to push zero points manually, instead of parsing the `glyf` data.
    //
    // Details:
    // https://docs.microsoft.com/en-us/typography/opentype/spec/gvar#point-numbers-and-processing-for-composite-glyphs
    let components = CompositeGlyphIter::new(s.tail_r())
    let components_count = components.copy().count().to_uint16()
    gvar_table.parse_variation_data(
      glyph_id, coordinates, components_count, tuples,
    )
    while components.next() is Some(component) {
      let t = req(tuples.apply_null())
      let mut transform = builder.transform

      // Variation component offset should be applied only when
      // the ARGS_ARE_XY_VALUES flag is set.
      if component.flags.args_are_xy_values() {
        transform = Transform::combine(
          transform,
          Transform::new_translate(t.x, t.y),
        )
      }
      transform = Transform::combine(transform, component.transform)
      let b = GlyfBuilder::new(transform, builder.bbox.copy(), builder.builder)
      if glyf_table.get(component.glyph_id) is Some(glyph_data) {
        outline_var_impl(
          glyf_table,
          gvar_table,
          component.glyph_id,
          glyph_data,
          coordinates,
          depth + 1,
          b,
        )

        // Take updated bbox.
        builder.bbox = b.bbox
      }
    }
  } else {
    // An empty glyph.
    raise Malformed
  }
}

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#tuple-variation-store-header
fn gvar_parse_variation_data(
  coordinates : ArrayView[NormalizedCoordinate],
  shared_tuple_records : LazyArray16[F2DOT14],
  points_len : UInt16,
  data : BytesView,
  tuples : VariationTuples,
) -> Unit raise Malformed {
  let shared_point_numbers_flag : UInt16 = 0x8000
  let count_mask : UInt16 = 0x0FFF
  let main_stream = Stream::new(data)
  let tuple_variation_count = main_stream.read_u16()
  let data_offset : Offset16 = main_stream.read()

  // 'The high 4 bits are flags, and the low 12 bits
  // are the number of tuple variation tables for this glyph.'
  let has_shared_point_numbers = (
      tuple_variation_count & shared_point_numbers_flag
    ) !=
    0
  let tuple_variation_count = tuple_variation_count & count_mask

  // 'The number of tuple variation tables can be any number between 1 and 4095.'
  // No need to check for 4095, because this is 0x0FFF that we masked before.
  if tuple_variation_count == 0 {
    raise Malformed
  }

  // A glyph variation data consists of three parts: header + variation tuples + serialized data.
  // Each tuple has it's own chunk in the serialized data.
  // Because of that, we are using two parsing streams: one for tuples and one for serialized data.
  // So we can parse them in parallel and avoid needless allocations.
  let serialized_stream = Stream::new_at_r(data, data_offset.to_usize())

  // All tuples in the variation data can reference the same point numbers,
  // which are defined at the start of the serialized data.
  let mut shared_point_numbers = None
  if has_shared_point_numbers {
    shared_point_numbers = PackedPointsIter::new(serialized_stream)
  }
  parse_variation_tuples(
    tuple_variation_count,
    coordinates,
    shared_tuple_records,
    shared_point_numbers,
    req(u16_checked_add(points_len, phantom_points_len)),
    main_stream,
    serialized_stream,
    tuples,
  )
}
