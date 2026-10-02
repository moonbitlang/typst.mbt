// A [Glyph Data Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/glyf) implementation.

///|
priv struct GlyfBuilder {
  builder : &OutlineBuilder
  transform : Transform
  is_default_ts : Bool // `bool` is faster than `Option` or `is_default`.
  // We have to always calculate the bbox, because `gvar` doesn't store one
  // and in case of a malformed bbox in `glyf`.
  mut bbox : RectF
  mut first_on_curve : GlyfPoint?
  mut first_off_curve : GlyfPoint?
  mut last_off_curve : GlyfPoint?
}

///|
fn GlyfBuilder::new(
  transform : Transform,
  bbox : RectF,
  builder : &OutlineBuilder,
) -> GlyfBuilder {
  {
    builder,
    transform,
    is_default_ts: transform.is_default(),
    bbox,
    first_on_curve: None,
    first_off_curve: None,
    last_off_curve: None,
  }
}

///|
fn GlyfBuilder::move_to(self : GlyfBuilder, x : Float, y : Float) -> Unit {
  let (x, y) = if !self.is_default_ts {
    self.transform.apply_to(x, y)
  } else {
    (x, y)
  }
  self.bbox.extend_by(x, y)
  self.builder.move_to(x, y)
}

///|
fn GlyfBuilder::line_to(self : GlyfBuilder, x : Float, y : Float) -> Unit {
  let (x, y) = if !self.is_default_ts {
    self.transform.apply_to(x, y)
  } else {
    (x, y)
  }
  self.bbox.extend_by(x, y)
  self.builder.line_to(x, y)
}

///|
fn GlyfBuilder::quad_to(
  self : GlyfBuilder,
  x1 : Float,
  y1 : Float,
  x : Float,
  y : Float,
) -> Unit {
  let (x1, y1, x, y) = if !self.is_default_ts {
    let (x1, y1) = self.transform.apply_to(x1, y1)
    let (x, y) = self.transform.apply_to(x, y)
    (x1, y1, x, y)
  } else {
    (x1, y1, x, y)
  }
  self.bbox.extend_by(x1, y1)
  self.bbox.extend_by(x, y)
  self.builder.quad_to(x1, y1, x, y)
}

///|
// Useful links:
//
// - https://developer.apple.com/fonts/TrueType-Reference-Manual/RM01/Chap1.html
// - https://stackoverflow.com/a/20772557
fn GlyfBuilder::push_point(
  self : GlyfBuilder,
  x : Float,
  y : Float,
  on_curve_point : Bool,
  last_point : Bool,
) -> Unit {
  let p : GlyfPoint = { x, y, }
  if self.first_on_curve is None {
    if on_curve_point {
      self.first_on_curve = Some(p)
      self.move_to(p.x, p.y)
    } else if self.first_off_curve is Some(offcurve) {
      let mid = offcurve.lerp(p, 0.5)
      self.first_on_curve = Some(mid)
      self.last_off_curve = Some(p)
      self.move_to(mid.x, mid.y)
    } else {
      self.first_off_curve = Some(p)
    }
  } else {
    match (self.last_off_curve, on_curve_point) {
      (Some(offcurve), true) => {
        self.last_off_curve = None
        self.quad_to(offcurve.x, offcurve.y, p.x, p.y)
      }
      (Some(offcurve), false) => {
        self.last_off_curve = Some(p)
        let mid = offcurve.lerp(p, 0.5)
        self.quad_to(offcurve.x, offcurve.y, mid.x, mid.y)
      }
      (None, true) => self.line_to(p.x, p.y)
      (None, false) => self.last_off_curve = Some(p)
    }
  }
  if last_point {
    self.finish_contour()
  }
}

///|
fn GlyfBuilder::finish_contour(self : GlyfBuilder) -> Unit {
  if (self.first_off_curve, self.last_off_curve)
    is (Some(offcurve1), Some(offcurve2)) {
    self.last_off_curve = None
    let mid = offcurve2.lerp(offcurve1, 0.5)
    self.quad_to(offcurve2.x, offcurve2.y, mid.x, mid.y)
  }
  if (self.first_on_curve, self.first_off_curve) is (Some(p), Some(offcurve1)) {
    self.quad_to(offcurve1.x, offcurve1.y, p.x, p.y)
  } else if (self.first_on_curve, self.last_off_curve)
    is (Some(p), Some(offcurve2)) {
    self.quad_to(offcurve2.x, offcurve2.y, p.x, p.y)
  } else if self.first_on_curve is Some(p) {
    self.line_to(p.x, p.y)
  }
  self.first_on_curve = None
  self.first_off_curve = None
  self.last_off_curve = None
  self.builder.close()
}

///|
priv struct CompositeGlyphInfo {
  glyph_id : GlyphId
  transform : Transform
  flags : CompositeGlyphFlags
}

///|
priv struct CompositeGlyphIter {
  stream : Stream
}

///|
fn CompositeGlyphIter::new(data : BytesView) -> CompositeGlyphIter {
  { stream: Stream::new(data), }
}

///|
fn CompositeGlyphIter::copy(self : CompositeGlyphIter) -> CompositeGlyphIter {
  { stream: self.stream.copy(), }
}

///|
fn CompositeGlyphIter::next(self : CompositeGlyphIter) -> CompositeGlyphInfo? {
  try {
    let flags = CompositeGlyphFlags(self.stream.read_u16())
    let glyph_id : GlyphId = self.stream.read()
    let mut ts = Transform::default()
    if flags.args_are_xy_values() {
      if flags.arg_1_and_2_are_words() {
        let e = Float::from_int(self.stream.read_i16().to_int())
        let f = Float::from_int(self.stream.read_i16().to_int())
        ts = { ..ts, e, f, }
      } else {
        let e = Float::from_int(self.stream.read_i8())
        let f = Float::from_int(self.stream.read_i8())
        ts = { ..ts, e, f, }
      }
    }
    if flags.we_have_a_two_by_two() {
      let a = self.stream.read_f2dot14().to_f32()
      let b = self.stream.read_f2dot14().to_f32()
      let c = self.stream.read_f2dot14().to_f32()
      let d = self.stream.read_f2dot14().to_f32()
      ts = { ..ts, a, b, c, d, }
    } else if flags.we_have_an_x_and_y_scale() {
      let a = self.stream.read_f2dot14().to_f32()
      let d = self.stream.read_f2dot14().to_f32()
      ts = { ..ts, a, d, }
    } else if flags.we_have_a_scale() {
      let a = self.stream.read_f2dot14().to_f32()
      ts = { ..ts, a, d: a, }
    }
    if !flags.more_components() {
      // Finish the iterator even if stream still has some data.
      self.stream.jump_to_end()
    }
    Some({ glyph_id, transform: ts, flags, })
  } catch {
    _ => None
  }
}

///|
fn CompositeGlyphIter::count(self : CompositeGlyphIter) -> Int {
  let mut n = 0
  while self.next() is Some(_) {
    n += 1
  }
  n
}

///|
/// Reads an `i8`.
pub fn Stream::read_i8(self : Stream) -> Int raise Malformed {
  let b = self.read_u8().to_int()
  if b >= 128 {
    b - 256
  } else {
    b
  }
}

///|
/// Reads an `F2DOT14`.
pub fn Stream::read_f2dot14(self : Stream) -> F2DOT14 raise Malformed {
  F2DOT14(self.read_i16())
}

///|
// Due to some optimization magic, using f32 instead of i16
// makes the code ~10% slower. At least on my machine.
// I guess it's due to the fact that with i16 the struct
// fits into the machine word.
priv struct GlyphPoint {
  x : Int16
  y : Int16
  /// Indicates that a point is a point on curve
  /// and not a control point.
  on_curve_point : Bool
  last_point : Bool
}

///|
priv struct GlyphPointsIter {
  endpoints : EndpointsIter
  flags : FlagsIter
  x_coords : CoordsIter
  y_coords : CoordsIter
  mut points_left : UInt16 // Number of points left in the glyph.
}

///|
fn GlyphPointsIter::default() -> GlyphPointsIter {
  {
    endpoints: { endpoints: LazyArray16::default(), index: 0, left: 0, },
    flags: FlagsIter::new(empty_data),
    x_coords: CoordsIter::new(empty_data),
    y_coords: CoordsIter::new(empty_data),
    points_left: 0,
  }
}

///|
fn GlyphPointsIter::copy(self : GlyphPointsIter) -> GlyphPointsIter {
  {
    endpoints: { ..self.endpoints, },
    flags: {
      stream: self.flags.stream.copy(),
      repeats: self.flags.repeats,
      flags: self.flags.flags,
    },
    x_coords: { stream: self.x_coords.stream.copy(), prev: self.x_coords.prev, },
    y_coords: { stream: self.y_coords.stream.copy(), prev: self.y_coords.prev, },
    points_left: self.points_left,
  }
}

///|
fn GlyphPointsIter::current_contour(self : GlyphPointsIter) -> UInt16 {
  self.endpoints.index - 1
}

///|
fn GlyphPointsIter::next(self : GlyphPointsIter) -> GlyphPoint? {
  guard u16_checked_sub(self.points_left, 1) is Some(left) else { return None }
  self.points_left = left

  // TODO: skip empty contours

  let last_point = self.endpoints.next()
  let flags = self.flags.next()
  Some({
    x: self.x_coords.next(flags.x_short(), flags.x_is_same_or_positive_short()),
    y: self.y_coords.next(flags.y_short(), flags.y_is_same_or_positive_short()),
    on_curve_point: flags.on_curve_point(),
    last_point,
  })
}

///|
/// A simple flattening iterator for glyph's endpoints.
///
/// Translates endpoints like: 2 4 7
/// into flags: 0 0 1 0 1 0 0 1
priv struct EndpointsIter {
  endpoints : LazyArray16[UInt16] // Each endpoint indicates a contour end.
  mut index : UInt16
  mut left : UInt16
}

///|
fn EndpointsIter::new(endpoints : LazyArray16[UInt16]) -> EndpointsIter? {
  guard endpoints.get(0) is Some(left) else { return None }
  Some({ endpoints, index: 1, left, })
}

///|
fn u16_saturating_sub(a : UInt16, b : UInt16) -> UInt16 {
  if a >= b {
    a - b
  } else {
    0
  }
}

///|
fn EndpointsIter::next(self : EndpointsIter) -> Bool {
  if self.left == 0 {
    if self.endpoints.get(self.index) is Some(end) {
      let prev = self.endpoints.get(self.index - 1).unwrap_or(0)
      // Malformed font can have endpoints not in increasing order,
      // so we have to use checked_sub.
      self.left = u16_saturating_sub(end, prev)
      self.left = u16_saturating_sub(self.left, 1)
    }

    // Always advance the index, so we can check the current contour number.
    if u16_checked_add(self.index, 1) is Some(n) {
      self.index = n
    }
    true
  } else {
    self.left -= 1
    false
  }
}

///|
priv struct FlagsIter {
  stream : Stream
  // Number of times the `flags` should be used
  // before reading the next one from `stream`.
  mut repeats : Byte
  mut flags : SimpleGlyphFlags
}

///|
fn FlagsIter::new(data : BytesView) -> FlagsIter {
  { stream: Stream::new(data), repeats: 0, flags: SimpleGlyphFlags(0), }
}

///|
fn FlagsIter::next(self : FlagsIter) -> SimpleGlyphFlags {
  if self.repeats == 0 {
    self.flags = SimpleGlyphFlags(self.stream.read_u8() catch { _ => 0 })
    if self.flags.repeat_flag() {
      self.repeats = self.stream.read_u8() catch { _ => 0 }
    }
  } else {
    self.repeats -= 1
  }
  self.flags
}

///|
priv struct CoordsIter {
  stream : Stream
  mut prev : Int16 // Points are stored as deltas, so we have to keep the previous one.
}

///|
fn CoordsIter::new(data : BytesView) -> CoordsIter {
  { stream: Stream::new(data), prev: 0, }
}

///|
fn CoordsIter::next(
  self : CoordsIter,
  is_short : Bool,
  is_same_or_short : Bool,
) -> Int16 {
  // See https://docs.microsoft.com/en-us/typography/opentype/spec/glyf#simple-glyph-description
  // for details about Simple Glyph Flags processing.

  // We've already checked the coords data, so it's safe to fallback to 0.

  let mut n : Int16 = 0
  if is_short {
    n = Int16::from_int((self.stream.read_u8() catch { _ => 0 }).to_int())
    if !is_same_or_short {
      n = -n
    }
  } else if !is_same_or_short {
    n = self.stream.read_i16() catch { _ => 0 }
  }
  self.prev = self.prev + n
  self.prev
}

///|
priv struct GlyfPoint {
  x : Float
  y : Float
}

///|
fn GlyfPoint::lerp(self : GlyfPoint, other : GlyfPoint, t : Float) -> GlyfPoint {
  { x: self.x + t * (other.x - self.x), y: self.y + t * (other.y - self.y), }
}

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/glyf#simple-glyph-description
priv struct SimpleGlyphFlags(Byte)

///|
fn SimpleGlyphFlags::on_curve_point(self : SimpleGlyphFlags) -> Bool {
  (self.0 & 0x01) != 0
}

///|
fn SimpleGlyphFlags::x_short(self : SimpleGlyphFlags) -> Bool {
  (self.0 & 0x02) != 0
}

///|
fn SimpleGlyphFlags::y_short(self : SimpleGlyphFlags) -> Bool {
  (self.0 & 0x04) != 0
}

///|
fn SimpleGlyphFlags::repeat_flag(self : SimpleGlyphFlags) -> Bool {
  (self.0 & 0x08) != 0
}

///|
fn SimpleGlyphFlags::x_is_same_or_positive_short(
  self : SimpleGlyphFlags,
) -> Bool {
  (self.0 & 0x10) != 0
}

///|
fn SimpleGlyphFlags::y_is_same_or_positive_short(
  self : SimpleGlyphFlags,
) -> Bool {
  (self.0 & 0x20) != 0
}

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/glyf#composite-glyph-description
priv struct CompositeGlyphFlags(UInt16)

///|
fn CompositeGlyphFlags::arg_1_and_2_are_words(
  self : CompositeGlyphFlags,
) -> Bool {
  (self.0 & 0x0001) != 0
}

///|
fn CompositeGlyphFlags::args_are_xy_values(self : CompositeGlyphFlags) -> Bool {
  (self.0 & 0x0002) != 0
}

///|
fn CompositeGlyphFlags::we_have_a_scale(self : CompositeGlyphFlags) -> Bool {
  (self.0 & 0x0008) != 0
}

///|
fn CompositeGlyphFlags::more_components(self : CompositeGlyphFlags) -> Bool {
  (self.0 & 0x0020) != 0
}

///|
fn CompositeGlyphFlags::we_have_an_x_and_y_scale(
  self : CompositeGlyphFlags,
) -> Bool {
  (self.0 & 0x0040) != 0
}

///|
fn CompositeGlyphFlags::we_have_a_two_by_two(
  self : CompositeGlyphFlags,
) -> Bool {
  (self.0 & 0x0080) != 0
}

///|
// It's not defined in the spec, so we are using our own value.
let glyf_max_components : Int = 32

///|
/// Returns `Some(None)` for an empty glyph, raises on error.
fn glyf_outline_impl(
  loca_table : LocaTable,
  glyf_table : BytesView,
  data : BytesView,
  depth : Int,
  builder : GlyfBuilder,
) -> Rect? raise Malformed {
  if depth >= glyf_max_components {
    raise Malformed
  }
  let s = Stream::new(data)
  let number_of_contours = s.read_i16()
  s.advance(8) // Skip bbox. We use calculated one.
  if number_of_contours > 0 {
    // Simple glyph.

    // u16 casting is safe, since we already checked that the value is positive.
    let number_of_contours = i16_as_u16(number_of_contours)
    let points = req(parse_simple_outline(s.tail_r(), number_of_contours))
    while points.next() is Some(point) {
      builder.push_point(
        Float::from_int(point.x.to_int()),
        Float::from_int(point.y.to_int()),
        point.on_curve_point,
        point.last_point,
      )
    }
  } else if number_of_contours < 0 {
    // Composite glyph.
    let iter = CompositeGlyphIter::new(s.tail_r())
    while iter.next() is Some(comp) {
      if loca_table.glyph_range(comp.glyph_id) is Some((start, end)) {
        if slice_get(glyf_table, start, end) is Some(glyph_data) {
          let transform = Transform::combine(builder.transform, comp.transform)
          let b = GlyfBuilder::new(
            transform,
            builder.bbox.copy(),
            builder.builder,
          )
          glyf_outline_impl(loca_table, glyf_table, glyph_data, depth + 1, b)
          |> ignore

          // Take updated bbox.
          builder.bbox = b.bbox
        }
      }
    }
  }
  if builder.bbox.is_default() {
    return None
  }
  match builder.bbox.to_rect() {
    Some(r) => Some(r)
    None => None
  }
}

///|
fn RectF::copy(self : RectF) -> RectF {
  {
    x_min: self.x_min,
    y_min: self.y_min,
    x_max: self.x_max,
    y_max: self.y_max,
  }
}

///|
fn parse_simple_outline(
  glyph_data : BytesView,
  number_of_contours : UInt16,
) -> GlyphPointsIter? {
  try {
    if number_of_contours == 0 {
      return None
    }
    let s = Stream::new(glyph_data)
    let endpoints : LazyArray16[UInt16] = s.read_array16(number_of_contours)
    let points_total = req(u16_checked_add(req(endpoints.last()), 1))

    // Contours with a single point should be ignored.
    // But this is not an error, so we should return an "empty" iterator.
    if points_total == 1 {
      return Some(GlyphPointsIter::default())
    }

    // Skip instructions byte code.
    let instructions_len = s.read_u16()
    s.advance(instructions_len.to_int())
    let flags_offset = s.offset()
    let (x_coords_len, y_coords_len) = resolve_coords_len(s, points_total)
    let x_coords_offset = s.offset()
    let y_coords_offset = x_coords_offset + x_coords_len
    let y_coords_end = y_coords_offset + y_coords_len
    Some({
      endpoints: req(EndpointsIter::new(endpoints)),
      flags: FlagsIter::new(slice_r(glyph_data, flags_offset, x_coords_offset)),
      x_coords: CoordsIter::new(
        slice_r(glyph_data, x_coords_offset, y_coords_offset),
      ),
      y_coords: CoordsIter::new(
        slice_r(glyph_data, y_coords_offset, y_coords_end),
      ),
      points_left: points_total,
    })
  } catch {
    _ => None
  }
}

///|
/// Resolves coordinate arrays length.
///
/// The length depends on *Simple Glyph Flags*, so we have to process them all to find it.
fn resolve_coords_len(
  s : Stream,
  points_total : UInt16,
) -> (Int, Int) raise Malformed {
  let mut flags_left = points_total.to_int()
  let mut x_coords_len = 0
  let mut y_coords_len = 0
  while flags_left > 0 {
    let flags = s.read_u8().to_int()

    // The number of times a glyph point repeats.
    let repeats = if (flags & 0x08) != 0 {
      let repeats = s.read_u8()
      repeats.to_int() + 1
    } else {
      1
    }
    if repeats > flags_left {
      raise Malformed
    }
    if (flags & 0x02) != 0 {
      // Coordinate is 1 byte long.
      x_coords_len += repeats
    } else if (flags & 0x10) == 0 {
      // Coordinate is 2 bytes long.
      x_coords_len += repeats * 2
    }
    if (flags & 0x04) != 0 {
      // Coordinate is 1 byte long.
      y_coords_len += repeats
    } else if (flags & 0x20) == 0 {
      // Coordinate is 2 bytes long.
      y_coords_len += repeats * 2
    }
    flags_left -= repeats
  }
  (x_coords_len, y_coords_len)
}

///|
/// A [Glyph Data Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/glyf).
pub struct GlyfTable {
  data : BytesView
  loca_table : LocaTable
}

///|
/// Parses a table from raw data.
pub fn GlyfTable::parse(loca_table : LocaTable, data : BytesView) -> GlyfTable? {
  Some({ loca_table, data, })
}

///|
/// Outlines a glyph.
pub fn GlyfTable::outline(
  self : GlyfTable,
  glyph_id : GlyphId,
  builder : &OutlineBuilder,
) -> Rect? {
  let b = GlyfBuilder::new(Transform::default(), RectF::new(), builder)
  guard self.get(glyph_id) is Some(glyph_data) else { return None }
  glyf_outline_impl(self.loca_table, self.data, glyph_data, 0, b) catch {
    _ => None
  }
}

///|
/// The bounding box of the glyph. Unlike the `outline` method, this method does not
/// calculate the bounding box manually by outlining the glyph, but instead uses the
/// bounding box in the `glyf` program. As a result, this method will be much faster,
/// but the bounding box could be more inaccurate.
pub fn GlyfTable::bbox(self : GlyfTable, glyph_id : GlyphId) -> Rect? {
  guard self.get(glyph_id) is Some(glyph_data) else { return None }
  let s = Stream::new(glyph_data)
  try {
    // number of contours
    let _ = s.read_i16()
    let x_min = s.read_i16()
    let y_min = s.read_i16()
    let x_max = s.read_i16()
    let y_max = s.read_i16()
    Some({ x_min, y_min, x_max, y_max, })
  } catch {
    _ => None
  }
}

///|
/// Returns the data of a glyph.
pub fn GlyfTable::get(self : GlyfTable, glyph_id : GlyphId) -> BytesView? {
  guard self.loca_table.glyph_range(glyph_id) is Some((start, end)) else {
    return None
  }
  slice_get(self.data, start, end)
}

///|
/// Returns the number of points in this outline.
fn GlyfTable::outline_points(self : GlyfTable, glyph_id : GlyphId) -> UInt16 {
  self.outline_points_impl(glyph_id).unwrap_or(0)
}

///|
fn GlyfTable::outline_points_impl(
  self : GlyfTable,
  glyph_id : GlyphId,
) -> UInt16? {
  guard self.get(glyph_id) is Some(data) else { return None }
  let s = Stream::new(data)
  try {
    let number_of_contours = s.read_i16()

    // Skip bbox.
    s.advance(8)
    if number_of_contours > 0 {
      // Simple glyph.
      let number_of_contours = i16_as_u16(number_of_contours)
      let glyph_points = req(
        parse_simple_outline(s.tail_r(), number_of_contours),
      )
      Some(glyph_points.points_left)
    } else if number_of_contours < 0 {
      // Composite glyph.
      let components = CompositeGlyphIter::new(s.tail_r())
      Some(components.copy().count().to_uint16())
    } else {
      // An empty glyph.
      None
    }
  } catch {
    _ => None
  }
}
