// A high-level, safe, zero-allocation font parser for TrueType, OpenType
// and AAT fonts.
//
// Port of `ttf-parser` 0.25.1 (`src/lib.rs`, common types). Font parsing
// starts with a `Face` (see face.mbt).
//
// Upstream modules map onto prefixed names in this single package, e.g.
// `cmap::Subtable` -> `CmapSubtable`, `glyf::Table` -> `GlyfTable`.

///|
/// A type-safe wrapper for glyph ID.
pub(all) struct GlyphId(UInt16) derive(Eq, Compare, Hash, Default, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphId with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphId with Hash::{hash, hash_combine}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphId with Default::{default}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphId with @debug.Debug::{to_repr}

///|
pub impl FromData for GlyphId with fn size() {
  2
}

///|
pub impl FromData for GlyphId with fn parse(data) {
  GlyphId(FromData::parse(data))
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphId with FromData::{size, parse}

///|
/// A TrueType font magic.
///
/// https://docs.microsoft.com/en-us/typography/opentype/spec/otff#organization-of-an-opentype-font
priv enum Magic {
  TrueType
  OpenType
  FontCollection
} derive(Eq)

///|
impl FromData for Magic with fn size() {
  4
}

///|
impl FromData for Magic with fn parse(data) {
  let n : UInt = FromData::parse(data)
  match n {
    0x00010000 | 0x74727565 => TrueType
    0x4F54544F => OpenType
    0x74746366 => FontCollection
    _ => raise Malformed
  }
}

///|
/// A variation coordinate in a normalized coordinate system.
///
/// Basically any number in a -1.0..1.0 range.
/// Where 0 is a default value.
///
/// The number is stored as f2.16
pub struct NormalizedCoordinate(Int16) derive(Eq, Default, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedCoordinate with Eq::{not_equal, equal}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedCoordinate with Default::{default}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedCoordinate with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedCoordinate with Hash::{hash, hash_combine}

///|
/// Creates a new coordinate.
///
/// The provided number will be clamped to the -16384..16384 range.
pub fn NormalizedCoordinate::from_i16(n : Int16) -> NormalizedCoordinate {
  NormalizedCoordinate(i16_bound(-16384, n, 16384))
}

///|
/// Creates a new coordinate.
///
/// The provided number will be clamped to the -1.0..1.0 range.
pub fn NormalizedCoordinate::from_f32(n : Float) -> NormalizedCoordinate {
  NormalizedCoordinate(f32_as_i16(f32_bound(-1.0, n, 1.0) * 16384.0))
}

///|
/// Returns the coordinate value as f2.14.
pub fn NormalizedCoordinate::get(self : NormalizedCoordinate) -> Int16 {
  self.0
}

///|
/// Rust's `f32 as i16` cast (saturating, NaN -> 0).
pub fn f32_as_i16(v : Float) -> Int16 {
  let i = f32_as_i32(v)
  if i > 32767 {
    32767
  } else if i < -32768 {
    -32768
  } else {
    Int16::from_int(i)
  }
}

///|
/// Rust's `f32 as u16` cast (saturating, NaN -> 0).
pub fn f32_as_u16(v : Float) -> UInt16 {
  let i = f32_as_i32(v)
  if i > 65535 {
    65535
  } else if i < 0 {
    0
  } else {
    i.to_uint16()
  }
}

///|
/// Rust's `f32 as u8` cast (saturating, NaN -> 0).
pub fn f32_as_u8(v : Float) -> Byte {
  let i = f32_as_i32(v)
  if i > 255 {
    b'\xFF'
  } else if i < 0 {
    b'\x00'
  } else {
    i.to_byte()
  }
}

///|
/// A font variation value.
pub(all) struct Variation {
  /// An axis tag name.
  axis : Tag
  /// An axis value.
  value : Float
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Variation with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Variation with @debug.Debug::{to_repr}

///|
/// A 4-byte tag.
pub(all) struct Tag(UInt) derive(Eq, Compare, Hash, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with Eq::{not_equal, equal}

///|
pub extend Tag with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with Hash::{hash, hash_combine}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with Default::{default}

///|
/// Creates a `Tag` from bytes.
pub fn Tag::from_bytes(bytes : Bytes) -> Tag {
  Tag(
    (bytes[0].to_uint() << 24) |
    (bytes[1].to_uint() << 16) |
    (bytes[2].to_uint() << 8) |
    bytes[3].to_uint(),
  )
}

///|
/// Creates a `Tag` from a 4-character ASCII string.
pub fn Tag::from_str(s : String) -> Tag {
  let mut n : UInt = 0
  for i in 0..<4 {
    let c = if i < s.length() { s.code_unit_at(i).to_uint() & 0xFF } else { 32 }
    n = (n << 8) | c
  }
  Tag(n)
}

///|
/// Creates a `Tag` from bytes.
///
/// In case of empty data will return `Tag` set to 0.
///
/// When `bytes` are shorter than 4, will set missing bytes to ` `.
///
/// Data after first 4 bytes is ignored.
pub fn Tag::from_bytes_lossy(bytes : BytesView) -> Tag {
  if bytes.length() == 0 {
    return Tag(0)
  }
  let mut n : UInt = 0
  for i in 0..<4 {
    let c = if i < bytes.length() { bytes[i].to_uint() } else { 32 }
    n = (n << 8) | c
  }
  Tag(n)
}

///|
/// Returns tag as 4-element byte array.
pub fn Tag::to_bytes(self : Tag) -> Bytes {
  Bytes::makei(4, i => ((self.0 >> (24 - 8 * i)) & 0xff).to_byte())
}

///|
/// Returns tag as 4-element char array.
pub fn Tag::to_chars(self : Tag) -> Array[Char] {
  Array::makei(4, i => {
    ((self.0 >> (24 - 8 * i)) & 0xff).reinterpret_as_int().unsafe_to_char()
  })
}

///|
/// Checks if tag is null / `[0, 0, 0, 0]`.
pub fn Tag::is_null(self : Tag) -> Bool {
  self.0 == 0
}

///|
/// Returns tag value as `u32` number.
pub fn Tag::as_u32(self : Tag) -> UInt {
  self.0
}

///|
pub impl Show for Tag with fn output(self, logger) {
  for c in self.to_chars() {
    logger.write_char(c)
  }
}

///|
pub extend Tag with Show::{to_string, output}

///|
pub impl Debug for Tag with fn to_repr(self) {
  Repr::literal("Tag(\{self})")
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with @debug.Debug::{to_repr}

///|
pub impl FromData for Tag with fn size() {
  4
}

///|
pub impl FromData for Tag with fn parse(data) {
  Tag(FromData::parse(data))
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Tag with FromData::{size, parse}

///|
/// A line metrics.
///
/// Used for underline and strikeout.
pub(all) struct LineMetrics {
  /// Line position.
  mut position : Int16
  /// Line thickness.
  mut thickness : Int16
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LineMetrics with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LineMetrics with @debug.Debug::{to_repr}

///|
/// A rectangle.
///
/// Doesn't guarantee that `x_min` <= `x_max` and/or `y_min` <= `y_max`.
pub(all) struct Rect {
  x_min : Int16
  y_min : Int16
  x_max : Int16
  y_max : Int16
} derive(Eq, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Hash::{hash, hash_combine}

///|
fn Rect::zero() -> Rect {
  { x_min: 0, y_min: 0, x_max: 0, y_max: 0, }
}

///|
/// Returns rect's width.
pub fn Rect::width(self : Rect) -> Int16 {
  self.x_max - self.x_min
}

///|
/// Returns rect's height.
pub fn Rect::height(self : Rect) -> Int16 {
  self.y_max - self.y_min
}

///|
/// A rectangle described by the left-lower and upper-right points.
pub(all) struct RectF {
  /// The horizontal minimum of the rect.
  mut x_min : Float
  /// The vertical minimum of the rect.
  mut y_min : Float
  /// The horizontal maximum of the rect.
  mut x_max : Float
  /// The vertical maximum of the rect.
  mut y_max : Float
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RectF with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RectF with @debug.Debug::{to_repr}

///|
let f32_max : Float = Float::reinterpret_from_uint(0x7f7fffff)

///|
let f32_min : Float = Float::reinterpret_from_uint(0xff7fffff)

///|
fn RectF::new() -> RectF {
  { x_min: f32_max, y_min: f32_max, x_max: f32_min, y_max: f32_min, }
}

///|
fn RectF::is_default(self : RectF) -> Bool {
  self.x_min == f32_max &&
  self.y_min == f32_max &&
  self.x_max == f32_min &&
  self.y_max == f32_min
}

///|
/// Rust's `f32::min` (ignores NaN).
pub fn f32_min_of(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// Rust's `f32::max` (ignores NaN).
pub fn f32_max_of(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
fn RectF::extend_by(self : RectF, x : Float, y : Float) -> Unit {
  self.x_min = f32_min_of(self.x_min, x)
  self.y_min = f32_min_of(self.y_min, y)
  self.x_max = f32_max_of(self.x_max, x)
  self.y_max = f32_max_of(self.y_max, y)
}

///|
fn RectF::to_rect(self : RectF) -> Rect? {
  guard try_i16_from_f32(self.x_min) is Some(x_min) else { return None }
  guard try_i16_from_f32(self.y_min) is Some(y_min) else { return None }
  guard try_i16_from_f32(self.x_max) is Some(x_max) else { return None }
  guard try_i16_from_f32(self.y_max) is Some(y_max) else { return None }
  Some({ x_min, y_min, x_max, y_max, })
}

///|
/// An affine transform.
pub(all) struct Transform {
  /// The 'a' component of the transform.
  a : Float
  /// The 'b' component of the transform.
  b : Float
  /// The 'c' component of the transform.
  c : Float
  /// The 'd' component of the transform.
  d : Float
  /// The 'e' component of the transform.
  e : Float
  /// The 'f' component of the transform.
  f : Float
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Transform with Eq::{not_equal, equal}

///|
/// Creates a new transform with the specified components.
pub fn Transform::new(
  a : Float,
  b : Float,
  c : Float,
  d : Float,
  e : Float,
  f : Float,
) -> Transform {
  { a, b, c, d, e, f, }
}

///|
/// Creates a new translation transform.
pub fn Transform::new_translate(tx : Float, ty : Float) -> Transform {
  Transform::new(1.0, 0.0, 0.0, 1.0, tx, ty)
}

///|
let f32_pi : Float = Float::reinterpret_from_uint(0x40490fdb)

///|
/// Creates a new rotation transform.
pub fn Transform::new_rotate(angle : Float) -> Transform {
  let cc = @math.cosf(angle * f32_pi)
  let ss = @math.sinf(angle * f32_pi)
  Transform::new(cc, ss, -ss, cc, 0.0, 0.0)
}

///|
/// Creates a new skew transform.
pub fn Transform::new_skew(skew_x : Float, skew_y : Float) -> Transform {
  let x = @math.tanf(skew_x * f32_pi)
  let y = @math.tanf(skew_y * f32_pi)
  Transform::new(1.0, y, -x, 1.0, 0.0, 0.0)
}

///|
/// Creates a new scale transform.
pub fn Transform::new_scale(sx : Float, sy : Float) -> Transform {
  Transform::new(sx, 0.0, 0.0, sy, 0.0, 0.0)
}

///|
/// Combines two transforms with each other.
pub fn Transform::combine(ts1 : Transform, ts2 : Transform) -> Transform {
  {
    a: ts1.a * ts2.a + ts1.c * ts2.b,
    b: ts1.b * ts2.a + ts1.d * ts2.b,
    c: ts1.a * ts2.c + ts1.c * ts2.d,
    d: ts1.b * ts2.c + ts1.d * ts2.d,
    e: ts1.a * ts2.e + ts1.c * ts2.f + ts1.e,
    f: ts1.b * ts2.e + ts1.d * ts2.f + ts1.f,
  }
}

///|
fn Transform::apply_to(
  self : Transform,
  x : Float,
  y : Float,
) -> (Float, Float) {
  let tx = x
  let ty = y
  (self.a * tx + self.c * ty + self.e, self.b * tx + self.d * ty + self.f)
}

///|
/// Checks whether a transform is the identity transform.
pub fn Transform::is_default(self : Transform) -> Bool {
  // A direct float comparison is fine in our case.
  self.a == 1.0 &&
  self.b == 0.0 &&
  self.c == 0.0 &&
  self.d == 1.0 &&
  self.e == 0.0 &&
  self.f == 0.0
}

///|
pub impl Default for Transform with fn default() {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0, }
}

///|
pub extend Transform with Default::{default}

///|
pub impl Debug for Transform with fn to_repr(self) {
  Repr::literal(
    "Transform(\{self.a} \{self.b} \{self.c} \{self.d} \{self.e} \{self.f})",
  )
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Transform with @debug.Debug::{to_repr}

///|
/// A float point.
pub(all) struct PointF {
  /// The X-axis coordinate.
  mut x : Float
  /// The Y-axis coordinate.
  mut y : Float
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PointF with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PointF with @debug.Debug::{to_repr}

///|
/// Phantom points.
///
/// Available only for variable fonts with the `gvar` table.
pub(all) struct PhantomPoints {
  /// Left side bearing point.
  left : PointF
  /// Right side bearing point.
  right : PointF
  /// Top side bearing point.
  top : PointF
  /// Bottom side bearing point.
  bottom : PointF
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PhantomPoints with @debug.Debug::{to_repr}

///|
/// A RGBA color in the sRGB color space.
pub(all) struct RgbaColor {
  mut red : Byte
  mut green : Byte
  mut blue : Byte
  mut alpha : Byte
} derive(Eq, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RgbaColor with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RgbaColor with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RgbaColor with Hash::{hash, hash_combine}

///|
/// Creates a new `RgbaColor`.
pub fn RgbaColor::new(
  red : Byte,
  green : Byte,
  blue : Byte,
  alpha : Byte,
) -> RgbaColor {
  { blue, green, red, alpha, }
}

///|
fn RgbaColor::apply_alpha(self : RgbaColor, alpha : Float) -> Unit {
  self.alpha = f32_as_u8(
    Float::from_int(self.alpha.to_int()) / 255.0 * alpha * 255.0,
  )
}

///|
/// A trait for glyph outline construction.
pub(open) trait OutlineBuilder {
  /// Appends a MoveTo segment.
  ///
  /// Start of a contour.
  fn move_to(Self, Float, Float) -> Unit
  /// Appends a LineTo segment.
  fn line_to(Self, Float, Float) -> Unit
  /// Appends a QuadTo segment.
  fn quad_to(Self, Float, Float, Float, Float) -> Unit
  /// Appends a CurveTo segment.
  fn curve_to(Self, Float, Float, Float, Float, Float, Float) -> Unit
  /// Appends a ClosePath segment.
  ///
  /// End of a contour.
  fn close(Self) -> Unit
}

///|
priv struct DummyOutline {}

///|
impl OutlineBuilder for DummyOutline with fn move_to(_, _, _) {
  ()
}

///|
impl OutlineBuilder for DummyOutline with fn line_to(_, _, _) {
  ()
}

///|
impl OutlineBuilder for DummyOutline with fn quad_to(_, _, _, _, _) {
  ()
}

///|
impl OutlineBuilder for DummyOutline with fn curve_to(_, _, _, _, _, _, _) {
  ()
}

///|
impl OutlineBuilder for DummyOutline with fn close(_) {
  ()
}

///|
/// A glyph raster image format.
pub(all) enum RasterImageFormat {
  PNG
  /// A monochrome bitmap.
  BitmapMono
  /// A packed monochrome bitmap.
  BitmapMonoPacked
  /// A grayscale bitmap with 2 bits per pixel.
  BitmapGray2
  /// A packed grayscale bitmap with 2 bits per pixel.
  BitmapGray2Packed
  /// A grayscale bitmap with 4 bits per pixel.
  BitmapGray4
  /// A packed grayscale bitmap with 4 bits per pixel.
  BitmapGray4Packed
  /// A grayscale bitmap with 8 bits per pixel.
  BitmapGray8
  /// A color bitmap with 32 bits per pixel (premultiplied BGRA).
  BitmapPremulBgra32
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RasterImageFormat with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RasterImageFormat with @debug.Debug::{to_repr}

///|
/// A glyph's raster image.
///
/// Note, that glyph metrics are in pixels and not in font units.
pub(all) struct RasterGlyphImage {
  /// Horizontal offset.
  x : Int16
  /// Vertical offset.
  y : Int16
  /// Image width.
  ///
  /// It doesn't guarantee that this value is the same as set in the `data`.
  width : UInt16
  /// Image height.
  ///
  /// It doesn't guarantee that this value is the same as set in the `data`.
  height : UInt16
  /// A pixels per em of the selected strike.
  pixels_per_em : UInt16
  /// An image format.
  format : RasterImageFormat
  /// A raw image data. It's up to the caller to decode it.
  data : BytesView
}

///|
/// A raw table record.
pub(all) struct TableRecord {
  tag : Tag
  check_sum : UInt
  offset : UInt
  length : UInt
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TableRecord with @debug.Debug::{to_repr}

///|
pub impl FromData for TableRecord with fn size() {
  16
}

///|
pub impl FromData for TableRecord with fn parse(data) {
  let s = Stream::new(data)
  { tag: s.read(), check_sum: s.read(), offset: s.read(), length: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TableRecord with FromData::{size, parse}

///|
/// A list of font face parsing errors.
pub(all) suberror FaceParsingError {
  /// An attempt to read out of bounds detected.
  ///
  /// Should occur only on malformed fonts.
  MalformedFont
  /// Face data must start with `0x00010000`, `0x74727565`, `0x4F54544F` or `0x74746366`.
  UnknownMagic
  /// The face index is larger than the number of faces in the font.
  FaceIndexOutOfBounds
  /// The `head` table is missing or malformed.
  NoHeadTable
  /// The `hhea` table is missing or malformed.
  NoHheaTable
  /// The `maxp` table is missing or malformed.
  NoMaxpTable
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FaceParsingError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FaceParsingError with @debug.Debug::{to_repr}

///|
pub impl Show for FaceParsingError with fn output(self, logger) {
  logger.write_string(
    match self {
      MalformedFont => "malformed font"
      UnknownMagic => "unknown magic"
      FaceIndexOutOfBounds => "face index is out of bounds"
      NoHeadTable => "the head table is missing or malformed"
      NoHheaTable => "the hhea table is missing or malformed"
      NoMaxpTable => "the maxp table is missing or malformed"
    },
  )
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FaceParsingError with Show::{to_string, output}
