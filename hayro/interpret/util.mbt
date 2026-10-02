// Port of `hayro-interpret/src/util.rs`: a number of utility methods.

///|
/// An unsigned 128-bit integer (upstream `u128`), used for cache keys.
pub(all) struct U128 {
  /// The upper 64 bits.
  hi : UInt64
  /// The lower 64 bits.
  lo : UInt64
} derive(Eq, Hash, Compare, Default, Debug)

///|
/// A SipHash-1-3 hasher with 128-bit output and zero keys (upstream
/// `siphasher::sip128::SipHasher13::new()`).
pub struct Hasher128 {
  priv mut v0 : UInt64
  priv mut v1 : UInt64
  priv mut v2 : UInt64
  priv mut v3 : UInt64
  priv mut tail : UInt64
  priv mut ntail : Int
  priv mut length : UInt64
}

///|
/// Create a new hasher.
pub fn Hasher128::new() -> Hasher128 {
  {
    v0: 0x736f6d6570736575UL,
    v1: 0x646f72616e646f6dUL ^ 0xeeUL,
    v2: 0x6c7967656e657261UL,
    v3: 0x7465646279746573UL,
    tail: 0,
    ntail: 0,
    length: 0,
  }
}

///|
fn rotl(x : UInt64, b : Int) -> UInt64 {
  (x << b) | (x >> (64 - b))
}

///|
fn Hasher128::round(self : Hasher128) -> Unit {
  self.v0 = self.v0 + self.v1
  self.v1 = rotl(self.v1, 13)
  self.v1 = self.v1 ^ self.v0
  self.v0 = rotl(self.v0, 32)
  self.v2 = self.v2 + self.v3
  self.v3 = rotl(self.v3, 16)
  self.v3 = self.v3 ^ self.v2
  self.v0 = self.v0 + self.v3
  self.v3 = rotl(self.v3, 21)
  self.v3 = self.v3 ^ self.v0
  self.v2 = self.v2 + self.v1
  self.v1 = rotl(self.v1, 17)
  self.v1 = self.v1 ^ self.v2
  self.v2 = rotl(self.v2, 32)
}

///|
fn Hasher128::compress(self : Hasher128, m : UInt64) -> Unit {
  self.v3 = self.v3 ^ m
  self.round()
  self.v0 = self.v0 ^ m
}

///|
/// Write a single byte.
pub fn Hasher128::write_u8(self : Hasher128, b : Byte) -> Unit {
  self.tail = self.tail | (b.to_uint64() << (8 * self.ntail))
  self.ntail += 1
  self.length += 1
  if self.ntail == 8 {
    self.compress(self.tail)
    self.tail = 0
    self.ntail = 0
  }
}

///|
/// Write a 64-bit integer (little endian).
pub fn Hasher128::write_u64(self : Hasher128, v : UInt64) -> Unit {
  for i in 0..<8 {
    self.write_u8((v >> (8 * i)).to_byte())
  }
}

///|
/// Write a 32-bit integer (little endian).
pub fn Hasher128::write_u32(self : Hasher128, v : UInt) -> Unit {
  for i in 0..<4 {
    self.write_u8((v >> (8 * i)).to_byte())
  }
}

///|
/// Write a `usize`.
pub fn Hasher128::write_usize(self : Hasher128, v : Int) -> Unit {
  self.write_u64(v.to_int64().reinterpret_as_uint64())
}

///|
/// Write a 128-bit integer.
pub fn Hasher128::write_u128(self : Hasher128, v : U128) -> Unit {
  self.write_u64(v.lo)
  self.write_u64(v.hi)
}

///|
/// Write a byte slice (length-prefixed, like Rust's `[u8]` hash).
pub fn Hasher128::write_bytes(self : Hasher128, bytes : BytesView) -> Unit {
  self.write_usize(bytes.length())
  for b in bytes {
    self.write_u8(b)
  }
}

///|
/// Write a string (its chars, terminated by `0xff`).
pub fn Hasher128::write_str(self : Hasher128, s : StringView) -> Unit {
  for c in s {
    self.write_u32(c.to_uint())
  }
  self.write_u8(b'\xff')
}

///|
/// Write a double by its bits.
pub fn Hasher128::write_f64(self : Hasher128, v : Double) -> Unit {
  self.write_u64(v.reinterpret_as_uint64())
}

///|
/// Write a float by its bits.
pub fn Hasher128::write_f32(self : Hasher128, v : Float) -> Unit {
  self.write_u32(v.reinterpret_as_uint())
}

///|
/// Finish the hash.
pub fn Hasher128::finish128(self : Hasher128) -> U128 {
  let b = ((self.length & 0xff) << 56) | self.tail
  self.compress(b)
  self.v2 = self.v2 ^ 0xee
  self.round()
  self.round()
  self.round()
  let h1 = self.v0 ^ self.v1 ^ self.v2 ^ self.v3
  self.v1 = self.v1 ^ 0xdd
  self.round()
  self.round()
  self.round()
  let h2 = self.v0 ^ self.v1 ^ self.v2 ^ self.v3
  { hi: h2, lo: h1, }
}

///|
/// Calculate a 128-bit siphash of a value, written by `f`.
pub fn hash128(f : (Hasher128) -> Unit) -> U128 {
  let h = Hasher128::new()
  f(h)
  h.finish128()
}

///|
/// Hash a sequence of 128-bit keys (upstream `hash128(&(a, b, ...))`).
pub fn hash128_keys(keys : Array[U128]) -> U128 {
  hash128(h => {
    for k in keys {
      h.write_u128(k)
    }
  })
}

///|
const SCALAR_NEARLY_ZERO : Float = 0.00390625 // 1.0 / (1 << 8)

///|
/// Whether the number is approximately 0 (`Float32Ext::is_nearly_zero`).
pub fn f32_is_nearly_zero(x : Float) -> Bool {
  x.abs() <= SCALAR_NEARLY_ZERO
}

///|
/// Whether the number is nearly equal to another number.
pub fn f32_is_nearly_equal(x : Float, other : Float) -> Bool {
  f32_is_nearly_zero(x - other)
}

///|
/// Whether the number is nearly less or equal to another number.
pub fn f32_is_nearly_less_or_equal(x : Float, other : Float) -> Bool {
  f32_is_nearly_zero(x - other) || x < other
}

///|
/// Whether the number is nearly greater or equal to another number.
pub fn f32_is_nearly_greater_or_equal(x : Float, other : Float) -> Bool {
  f32_is_nearly_zero(x - other) || x > other
}

///|
/// Whether the number is approximately 0 (`Float64Ext::is_nearly_zero`).
pub fn f64_is_nearly_zero(x : Double) -> Bool {
  x.abs() <= SCALAR_NEARLY_ZERO.to_double()
}

///|
/// Whether the number is nearly equal to another number.
pub fn f64_is_nearly_equal(x : Double, other : Double) -> Bool {
  f64_is_nearly_zero(x - other)
}

///|
/// Whether the number is nearly less or equal to another number.
pub fn f64_is_nearly_less_or_equal(x : Double, other : Double) -> Bool {
  f64_is_nearly_zero(x - other) || x < other
}

///|
/// Whether the number is nearly greater or equal to another number.
pub fn f64_is_nearly_greater_or_equal(x : Double, other : Double) -> Bool {
  f64_is_nearly_zero(x - other) || x > other
}

///|
/// `PointExt::nearly_same`.
fn point_nearly_same(a : @kurbo.Point, b : @kurbo.Point) -> Bool {
  f32_is_nearly_equal(a.x.to_float(), b.x.to_float()) &&
  f32_is_nearly_equal(a.y.to_float(), b.y.to_float())
}

///|
/// A fast bounding box of a path, only considering the control points
/// (`BezPathExt::fast_bounding_box`).
pub fn fast_bounding_box(path : @kurbo.BezPath) -> @kurbo.Rect {
  let mut min_x = @double.infinity
  let mut min_y = @double.infinity
  let mut max_x = @double.neg_infinity
  let mut max_y = @double.neg_infinity
  let include = (x : Double, y : Double) => {
    min_x = @kurbo.f64_min(min_x, x)
    min_y = @kurbo.f64_min(min_y, y)
    max_x = @kurbo.f64_max(max_x, x)
    max_y = @kurbo.f64_max(max_y, y)
  }
  for el in path.elements() {
    match el {
      MoveTo(p) | LineTo(p) => include(p.x, p.y)
      QuadTo(p1, p2) => {
        include(p1.x, p1.y)
        include(p2.x, p2.y)
      }
      CurveTo(p1, p2, p3) => {
        include(p1.x, p1.y)
        include(p2.x, p2.y)
        include(p3.x, p3.y)
      }
      ClosePath => ()
    }
  }
  if min_x > max_x {
    @kurbo.rect_zero
  } else {
    @kurbo.Rect::new(min_x, min_y, max_x, max_y)
  }
}

///|
/// Convert a `hayro_syntax` transform to a `kurbo::Affine`
/// (`TransformExt::to_kurbo`).
pub fn transform_to_kurbo(t : @hayro_syntax.Transform) -> @kurbo.Affine {
  @kurbo.Affine::new(t.as_coeffs())
}

///|
/// Convert a `hayro_syntax` rectangle to a `kurbo` rectangle
/// (`RectExt::to_kurbo`).
pub fn rect_to_kurbo(r : @hayro_syntax.Rect) -> @kurbo.Rect {
  @kurbo.Rect::new(r.x0, r.y0, r.x1, r.y1)
}

///|
/// Rust's saturating `f32 as u8` cast.
pub fn f32_as_u8(x : Float) -> Byte {
  if x.is_nan() || x <= 0.0 {
    b'\x00'
  } else if x >= 255.0 {
    b'\xff'
  } else {
    x.to_int().to_byte()
  }
}

///|
/// Rust's saturating `f32 as u32` cast (as `Int`, saturating at `Int` max).
pub fn f32_as_u32(x : Float) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// Rust's saturating `f64 as u32` cast (as `Int`, saturating at `Int` max).
pub fn f64_as_u32(x : Double) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// Rust's `f32::min` (NaN-ignoring).
pub fn f32_min(a : Float, b : Float) -> Float {
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
/// Rust's `f32::max` (NaN-ignoring).
pub fn f32_max(a : Float, b : Float) -> Float {
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
/// Rust's `f32::powf` (computed in double precision and rounded, like the
/// platform libm).
pub fn powf(x : Float, y : Float) -> Float {
  Float::from_double(@math.pow(x.to_double(), y.to_double()))
}

///|
/// Rust's `f32::powi` (compiler-rt `__powisf2`).
pub fn powi(a : Float, b : Int) -> Float {
  let recip = b < 0
  let mut a = a
  let mut b = b
  let mut r : Float = 1.0
  while true {
    if (b & 1) != 0 {
      r = r * a
    }
    b = b / 2
    if b == 0 {
      break
    }
    a = a * a
  }
  if recip {
    1.0 / r
  } else {
    r
  }
}

///|
/// Rust's `f32::clamp`.
pub fn f32_clamp(x : Float, min : Float, max : Float) -> Float {
  let mut x = x
  if x < min {
    x = min
  }
  if x > max {
    x = max
  }
  x
}
