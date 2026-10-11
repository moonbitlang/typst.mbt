// Lane helpers of `wasmi_core/src/simd.rs` (`ImmLaneIdx`, `Lanes`,
// `FromNarrow`, `FromWide`).
//
// Upstream transmutes a `V128` into arrays of lane values (`I8x16`,
// `U32x4`, `F64x2`, ...) and applies closures lanewise. Here lanes are
// extracted from and inserted into the two 64-bit halves directly; 8- and
// 16-bit lanes are passed to the lanewise functions as `Int` (sign- or
// zero-extended as the upstream lane type) and truncated back to the lane
// width.

///|
/// An error that may occur when constructing an out of bounds lane index.
pub(all) suberror OutOfBoundsLaneIdx derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend OutOfBoundsLaneIdx with @debug.Debug::{to_repr}

///|
/// A byte with values in the range 0–1 identifying a lane.
///
/// Upstream `ImmLaneIdx<2>`. Values are masked to the valid range when used
/// (like upstream's `From<ImmLaneIdx<N>> for u8`).
pub(all) struct ImmLaneIdx2(Byte) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx2 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx2 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx2 with @debug.Debug::{to_repr}

///|
/// A byte with values in the range 0–3 identifying a lane.
pub(all) struct ImmLaneIdx4(Byte) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx4 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx4 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx4 with @debug.Debug::{to_repr}

///|
/// A byte with values in the range 0–7 identifying a lane.
pub(all) struct ImmLaneIdx8(Byte) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx8 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx8 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx8 with @debug.Debug::{to_repr}

///|
/// A byte with values in the range 0–15 identifying a lane.
pub(all) struct ImmLaneIdx16(Byte) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx16 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx16 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx16 with @debug.Debug::{to_repr}

///|
/// A byte with values in the range 0–31 identifying a lane.
pub(all) struct ImmLaneIdx32(Byte) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx32 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx32 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImmLaneIdx32 with @debug.Debug::{to_repr}

///|
/// `TryFrom<u8> for ImmLaneIdx<2>`
pub fn ImmLaneIdx2::try_from(
  lane : Byte,
) -> ImmLaneIdx2 raise OutOfBoundsLaneIdx {
  if lane > 1 {
    raise OutOfBoundsLaneIdx
  }
  ImmLaneIdx2(lane)
}

///|
/// `From<ImmLaneIdx<2>> for u8`
pub fn ImmLaneIdx2::to_u8(self : ImmLaneIdx2) -> Byte {
  self.0 & 1
}

///|
/// `TryFrom<u8> for ImmLaneIdx<4>`
pub fn ImmLaneIdx4::try_from(
  lane : Byte,
) -> ImmLaneIdx4 raise OutOfBoundsLaneIdx {
  if lane > 3 {
    raise OutOfBoundsLaneIdx
  }
  ImmLaneIdx4(lane)
}

///|
/// `From<ImmLaneIdx<4>> for u8`
pub fn ImmLaneIdx4::to_u8(self : ImmLaneIdx4) -> Byte {
  self.0 & 3
}

///|
/// `TryFrom<u8> for ImmLaneIdx<8>`
pub fn ImmLaneIdx8::try_from(
  lane : Byte,
) -> ImmLaneIdx8 raise OutOfBoundsLaneIdx {
  if lane > 7 {
    raise OutOfBoundsLaneIdx
  }
  ImmLaneIdx8(lane)
}

///|
/// `From<ImmLaneIdx<8>> for u8`
pub fn ImmLaneIdx8::to_u8(self : ImmLaneIdx8) -> Byte {
  self.0 & 7
}

///|
/// `TryFrom<u8> for ImmLaneIdx<16>`
pub fn ImmLaneIdx16::try_from(
  lane : Byte,
) -> ImmLaneIdx16 raise OutOfBoundsLaneIdx {
  if lane > 15 {
    raise OutOfBoundsLaneIdx
  }
  ImmLaneIdx16(lane)
}

///|
/// `From<ImmLaneIdx<16>> for u8`
pub fn ImmLaneIdx16::to_u8(self : ImmLaneIdx16) -> Byte {
  self.0 & 15
}

///|
/// `TryFrom<u8> for ImmLaneIdx<32>`
pub fn ImmLaneIdx32::try_from(
  lane : Byte,
) -> ImmLaneIdx32 raise OutOfBoundsLaneIdx {
  if lane > 31 {
    raise OutOfBoundsLaneIdx
  }
  ImmLaneIdx32(lane)
}

///|
/// `From<ImmLaneIdx<32>> for u8`
pub fn ImmLaneIdx32::to_u8(self : ImmLaneIdx32) -> Byte {
  self.0 & 31
}

// Raw lane access.

///|
/// Returns the raw bits of the `bits`-wide lane `i` (zero-extended).
fn V128Value::lane_bits(self : V128Value, bits : Int, i : Int) -> UInt64 {
  let per_word = 64 / bits
  let w = if i < per_word { self.lo } else { self.hi }
  let s = i % per_word * bits
  if bits == 64 {
    w
  } else {
    (w >> s) & ((1UL << bits) - 1)
  }
}

///|
/// Returns `self` with the `bits`-wide lane `i` replaced by the low bits of `value`.
fn V128Value::with_lane_bits(
  self : V128Value,
  bits : Int,
  i : Int,
  value : UInt64,
) -> V128Value {
  let per_word = 64 / bits
  let s = i % per_word * bits
  let mask = if bits == 64 {
    0xFFFF_FFFF_FFFF_FFFFUL
  } else {
    (1UL << bits) - 1
  }
  let v = (value & mask) << s
  if i < per_word {
    { lo: (self.lo & (mask << s).lnot()) | v, hi: self.hi, }
  } else {
    { lo: self.lo, hi: (self.hi & (mask << s).lnot()) | v, }
  }
}

///|
/// Extends the raw lane bits `raw` of a `bits`-wide lane to `Int`.
fn ext_small(raw : UInt64, bits : Int, signed : Bool) -> Int {
  let x = raw.to_int()
  if signed {
    x << (32 - bits) >> (32 - bits)
  } else {
    x
  }
}

///|
/// Builds a [`V128Value`] of `bits`-wide lanes from `f(i)`, truncating each value.
fn small_from_fn(bits : Int, f : (Int) -> Int) -> V128Value {
  let per_word = 64 / bits
  let mask = (1UL << bits) - 1
  let mut lo = 0UL
  let mut hi = 0UL
  for j in 0..<per_word {
    let s = j * bits
    lo = lo | ((f(j).to_uint64() & mask) << s)
    hi = hi | ((f(j + per_word).to_uint64() & mask) << s)
  }
  { lo, hi, }
}

// Lanewise operations on 8- and 16-bit lanes (as `Int`).

///|
fn lanewise_unary_small(
  v : V128Value,
  bits : Int,
  signed : Bool,
  f : (Int) -> Int,
) -> V128Value {
  small_from_fn(bits, i => f(ext_small(v.lane_bits(bits, i), bits, signed)))
}

///|
fn lanewise_binary_small(
  lhs : V128Value,
  rhs : V128Value,
  bits : Int,
  signed : Bool,
  f : (Int, Int) -> Int,
) -> V128Value {
  small_from_fn(bits, i => {
    f(
      ext_small(lhs.lane_bits(bits, i), bits, signed),
      ext_small(rhs.lane_bits(bits, i), bits, signed),
    )
  })
}

///|
fn lanewise_comparison_small(
  lhs : V128Value,
  rhs : V128Value,
  bits : Int,
  signed : Bool,
  f : (Int, Int) -> Bool,
) -> V128Value {
  small_from_fn(bits, i => {
    if f(
        ext_small(lhs.lane_bits(bits, i), bits, signed),
        ext_small(rhs.lane_bits(bits, i), bits, signed),
      ) {
      -1
    } else {
      0
    }
  })
}

// 32-bit lanes (as `Int`; unsigned operations reinterpret).

///|
fn V128Value::i32_lane(self : V128Value, i : Int) -> Int {
  let w = if i < 2 { self.lo } else { self.hi }
  (w >> ((i & 1) * 32)).to_int()
}

///|
fn i32x4_from(a : Int, b : Int, c : Int, d : Int) -> V128Value {
  {
    lo: a.reinterpret_as_uint().to_uint64() |
    (b.reinterpret_as_uint().to_uint64() << 32),
    hi: c.reinterpret_as_uint().to_uint64() |
    (d.reinterpret_as_uint().to_uint64() << 32),
  }
}

///|
fn lanewise_unary_i32(v : V128Value, f : (Int) -> Int) -> V128Value {
  i32x4_from(
    f(v.i32_lane(0)),
    f(v.i32_lane(1)),
    f(v.i32_lane(2)),
    f(v.i32_lane(3)),
  )
}

///|
fn lanewise_binary_i32(
  lhs : V128Value,
  rhs : V128Value,
  f : (Int, Int) -> Int,
) -> V128Value {
  i32x4_from(
    f(lhs.i32_lane(0), rhs.i32_lane(0)),
    f(lhs.i32_lane(1), rhs.i32_lane(1)),
    f(lhs.i32_lane(2), rhs.i32_lane(2)),
    f(lhs.i32_lane(3), rhs.i32_lane(3)),
  )
}

///|
fn bool_mask32(b : Bool) -> Int {
  if b {
    -1
  } else {
    0
  }
}

///|
fn lanewise_comparison_i32(
  lhs : V128Value,
  rhs : V128Value,
  f : (Int, Int) -> Bool,
) -> V128Value {
  lanewise_binary_i32(lhs, rhs, (a, b) => bool_mask32(f(a, b)))
}

///|
fn lanewise_comparison_u32(
  lhs : V128Value,
  rhs : V128Value,
  f : (UInt, UInt) -> Bool,
) -> V128Value {
  lanewise_binary_i32(lhs, rhs, (a, b) => {
    bool_mask32(f(a.reinterpret_as_uint(), b.reinterpret_as_uint()))
  })
}

// 64-bit lanes.

///|
fn lanewise_unary_i64(v : V128Value, f : (Int64) -> Int64) -> V128Value {
  {
    lo: f(v.lo.reinterpret_as_int64()).reinterpret_as_uint64(),
    hi: f(v.hi.reinterpret_as_int64()).reinterpret_as_uint64(),
  }
}

///|
fn lanewise_binary_i64(
  lhs : V128Value,
  rhs : V128Value,
  f : (Int64, Int64) -> Int64,
) -> V128Value {
  {
    lo: f(lhs.lo.reinterpret_as_int64(), rhs.lo.reinterpret_as_int64()).reinterpret_as_uint64(),
    hi: f(lhs.hi.reinterpret_as_int64(), rhs.hi.reinterpret_as_int64()).reinterpret_as_uint64(),
  }
}

///|
fn bool_mask64(b : Bool) -> UInt64 {
  if b {
    0xFFFF_FFFF_FFFF_FFFF
  } else {
    0
  }
}

///|
fn lanewise_comparison_i64(
  lhs : V128Value,
  rhs : V128Value,
  f : (Int64, Int64) -> Bool,
) -> V128Value {
  {
    lo: bool_mask64(
      f(lhs.lo.reinterpret_as_int64(), rhs.lo.reinterpret_as_int64()),
    ),
    hi: bool_mask64(
      f(lhs.hi.reinterpret_as_int64(), rhs.hi.reinterpret_as_int64()),
    ),
  }
}

// `f32` lanes.

///|
fn V128Value::f32_lane(self : V128Value, i : Int) -> Float {
  Float::reinterpret_from_int(self.i32_lane(i))
}

///|
fn lanewise_unary_f32(v : V128Value, f : (Float) -> Float) -> V128Value {
  lanewise_unary_i32(v, x => {
    f(Float::reinterpret_from_int(x)).reinterpret_as_int()
  })
}

///|
fn lanewise_binary_f32(
  lhs : V128Value,
  rhs : V128Value,
  f : (Float, Float) -> Float,
) -> V128Value {
  lanewise_binary_i32(lhs, rhs, (a, b) => {
    f(Float::reinterpret_from_int(a), Float::reinterpret_from_int(b)).reinterpret_as_int()
  })
}

///|
fn lanewise_ternary_f32(
  a : V128Value,
  b : V128Value,
  c : V128Value,
  f : (Float, Float, Float) -> Float,
) -> V128Value {
  let r = i => {
    f(a.f32_lane(i), b.f32_lane(i), c.f32_lane(i)).reinterpret_as_int()
  }
  i32x4_from(r(0), r(1), r(2), r(3))
}

///|
fn lanewise_comparison_f32(
  lhs : V128Value,
  rhs : V128Value,
  f : (Float, Float) -> Bool,
) -> V128Value {
  lanewise_binary_i32(lhs, rhs, (a, b) => {
    bool_mask32(
      f(Float::reinterpret_from_int(a), Float::reinterpret_from_int(b)),
    )
  })
}

// `f64` lanes.

///|
fn lanewise_unary_f64(v : V128Value, f : (Double) -> Double) -> V128Value {
  {
    lo: f(v.lo.reinterpret_as_double()).reinterpret_as_uint64(),
    hi: f(v.hi.reinterpret_as_double()).reinterpret_as_uint64(),
  }
}

///|
fn lanewise_binary_f64(
  lhs : V128Value,
  rhs : V128Value,
  f : (Double, Double) -> Double,
) -> V128Value {
  {
    lo: f(lhs.lo.reinterpret_as_double(), rhs.lo.reinterpret_as_double()).reinterpret_as_uint64(),
    hi: f(lhs.hi.reinterpret_as_double(), rhs.hi.reinterpret_as_double()).reinterpret_as_uint64(),
  }
}

///|
fn lanewise_ternary_f64(
  a : V128Value,
  b : V128Value,
  c : V128Value,
  f : (Double, Double, Double) -> Double,
) -> V128Value {
  {
    lo: f(
      a.lo.reinterpret_as_double(),
      b.lo.reinterpret_as_double(),
      c.lo.reinterpret_as_double(),
    ).reinterpret_as_uint64(),
    hi: f(
      a.hi.reinterpret_as_double(),
      b.hi.reinterpret_as_double(),
      c.hi.reinterpret_as_double(),
    ).reinterpret_as_uint64(),
  }
}

///|
fn lanewise_comparison_f64(
  lhs : V128Value,
  rhs : V128Value,
  f : (Double, Double) -> Bool,
) -> V128Value {
  {
    lo: bool_mask64(
      f(lhs.lo.reinterpret_as_double(), rhs.lo.reinterpret_as_double()),
    ),
    hi: bool_mask64(
      f(lhs.hi.reinterpret_as_double(), rhs.hi.reinterpret_as_double()),
    ),
  }
}

// `FromNarrow`: lanes of twice the width built from narrow lanes.

///|
/// `low_unary` / `high_unary` for narrow lanes of `bits` < 32 bits: the
/// wide lane `i` is `f(narrow[i + base])` with `base` = 0 (low) or the
/// number of wide lanes (high).
fn widen_unary_small(
  v : V128Value,
  bits : Int,
  signed : Bool,
  high : Bool,
  f : (Int) -> Int,
) -> V128Value {
  let wide_bits = bits * 2
  let base = if high { 128 / wide_bits } else { 0 }
  small_from_fn(wide_bits, i => {
    f(ext_small(v.lane_bits(bits, i + base), bits, signed))
  })
}

///|
/// `low_binary` / `high_binary` for narrow lanes of `bits` < 32 bits.
fn widen_binary_small(
  lhs : V128Value,
  rhs : V128Value,
  bits : Int,
  signed : Bool,
  high : Bool,
  f : (Int, Int) -> Int,
) -> V128Value {
  let wide_bits = bits * 2
  let base = if high { 128 / wide_bits } else { 0 }
  small_from_fn(wide_bits, i => {
    f(
      ext_small(lhs.lane_bits(bits, i + base), bits, signed),
      ext_small(rhs.lane_bits(bits, i + base), bits, signed),
    )
  })
}

///|
/// `pairwise_unary` for narrow lanes of `bits` < 32 bits: the wide lane `i`
/// is `f(narrow[2 * i], narrow[2 * i + 1])`.
fn pairwise_unary_small(
  v : V128Value,
  bits : Int,
  signed : Bool,
  f : (Int, Int) -> Int,
) -> V128Value {
  small_from_fn(bits * 2, i => {
    f(
      ext_small(v.lane_bits(bits, 2 * i), bits, signed),
      ext_small(v.lane_bits(bits, 2 * i + 1), bits, signed),
    )
  })
}

///|
/// `pairwise_binary` for narrow lanes of `bits` < 32 bits.
fn pairwise_binary_small(
  lhs : V128Value,
  rhs : V128Value,
  bits : Int,
  signed : Bool,
  f : (Int, Int, Int, Int) -> Int,
) -> V128Value {
  small_from_fn(bits * 2, i => {
    f(
      ext_small(lhs.lane_bits(bits, 2 * i), bits, signed),
      ext_small(lhs.lane_bits(bits, 2 * i + 1), bits, signed),
      ext_small(rhs.lane_bits(bits, 2 * i), bits, signed),
      ext_small(rhs.lane_bits(bits, 2 * i + 1), bits, signed),
    )
  })
}

// `FromWide`: narrow lanes built from lanes of twice the width.

///|
/// `from_low_high` for wide lanes of `bits` <= 32 bits (as `Int`): narrow
/// lanes `0..n` come from `low`, `n..2n` from `high`.
fn narrow_low_high(
  low : V128Value,
  high : V128Value,
  bits : Int,
  f : (Int) -> Int,
) -> V128Value {
  let n = 128 / bits
  small_from_fn(bits / 2, i => {
    if i < n {
      f(ext_small(low.lane_bits(bits, i), bits, true))
    } else {
      f(ext_small(high.lane_bits(bits, i - n), bits, true))
    }
  })
}
