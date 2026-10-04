// Port of `wasmi_core/src/simd.rs`: the entire Wasm `simd` proposal API.
//
// Lane types: `i8`/`u8`/`i16`/`u16` lane values are `Int` (only the low
// lane bits are used), `i32` -> `Int`, `u32` -> `UInt`, `i64` -> `Int64`,
// `f32` -> `Float`, `f64` -> `Double`.

///|
/// Executes a Wasm `i64x2_splat` instruction.
pub fn i64x2_splat(value : Int64) -> V128 {
  let v = value.reinterpret_as_uint64()
  { lo: v, hi: v, }
}

///|
/// Executes a Wasm `i32x4_splat` instruction.
pub fn i32x4_splat(value : Int) -> V128 {
  i32x4_from(value, value, value, value)
}

///|
/// Executes a Wasm `i16x8_splat` instruction.
pub fn i16x8_splat(value : Int) -> V128 {
  let v = (value & 0xFFFF).to_uint64() * 0x0001_0001_0001_0001UL
  { lo: v, hi: v, }
}

///|
/// Executes a Wasm `i8x16_splat` instruction.
pub fn i8x16_splat(value : Int) -> V128 {
  let v = (value & 0xFF).to_uint64() * 0x0101_0101_0101_0101UL
  { lo: v, hi: v, }
}

///|
/// Executes a Wasm `f32x4_splat` instruction.
pub fn f32x4_splat(value : Float) -> V128 {
  i32x4_splat(value.reinterpret_as_int())
}

///|
/// Executes a Wasm `f64x2_splat` instruction.
pub fn f64x2_splat(value : Double) -> V128 {
  let v = value.reinterpret_as_uint64()
  { lo: v, hi: v, }
}

///|
/// Executes a Wasm `i64x2_extract_lane` instruction.
pub fn i64x2_extract_lane(v128 : V128, lane : ImmLaneIdx2) -> Int64 {
  v128.lane_bits(64, lane.to_u8().to_int()).reinterpret_as_int64()
}

///|
/// Executes a Wasm `i32x4_extract_lane` instruction.
pub fn i32x4_extract_lane(v128 : V128, lane : ImmLaneIdx4) -> Int {
  v128.i32_lane(lane.to_u8().to_int())
}

///|
/// Executes a Wasm `f64x2_extract_lane` instruction.
pub fn f64x2_extract_lane(v128 : V128, lane : ImmLaneIdx2) -> Double {
  v128.lane_bits(64, lane.to_u8().to_int()).reinterpret_as_double()
}

///|
/// Executes a Wasm `f32x4_extract_lane` instruction.
pub fn f32x4_extract_lane(v128 : V128, lane : ImmLaneIdx4) -> Float {
  v128.f32_lane(lane.to_u8().to_int())
}

///|
/// Executes a Wasm `i8x16_extract_lane_s` instruction.
pub fn i8x16_extract_lane_s(v128 : V128, lane : ImmLaneIdx16) -> Int {
  ext_small(v128.lane_bits(8, lane.to_u8().to_int()), 8, true)
}

///|
/// Executes a Wasm `i8x16_extract_lane_u` instruction.
pub fn i8x16_extract_lane_u(v128 : V128, lane : ImmLaneIdx16) -> UInt {
  v128.lane_bits(8, lane.to_u8().to_int()).to_uint()
}

///|
/// Executes a Wasm `i16x8_extract_lane_s` instruction.
pub fn i16x8_extract_lane_s(v128 : V128, lane : ImmLaneIdx8) -> Int {
  ext_small(v128.lane_bits(16, lane.to_u8().to_int()), 16, true)
}

///|
/// Executes a Wasm `i16x8_extract_lane_u` instruction.
pub fn i16x8_extract_lane_u(v128 : V128, lane : ImmLaneIdx8) -> UInt {
  v128.lane_bits(16, lane.to_u8().to_int()).to_uint()
}

///|
/// Executes a Wasm `i64x2_replace_lane` instruction.
pub fn i64x2_replace_lane(
  v128 : V128,
  lane : ImmLaneIdx2,
  item : Int64,
) -> V128 {
  v128.with_lane_bits(64, lane.to_u8().to_int(), item.reinterpret_as_uint64())
}

///|
/// Executes a Wasm `i32x4_replace_lane` instruction.
pub fn i32x4_replace_lane(v128 : V128, lane : ImmLaneIdx4, item : Int) -> V128 {
  v128.with_lane_bits(
    32,
    lane.to_u8().to_int(),
    item.reinterpret_as_uint().to_uint64(),
  )
}

///|
/// Executes a Wasm `i16x8_replace_lane` instruction.
pub fn i16x8_replace_lane(v128 : V128, lane : ImmLaneIdx8, item : Int) -> V128 {
  v128.with_lane_bits(16, lane.to_u8().to_int(), (item & 0xFFFF).to_uint64())
}

///|
/// Executes a Wasm `i8x16_replace_lane` instruction.
pub fn i8x16_replace_lane(v128 : V128, lane : ImmLaneIdx16, item : Int) -> V128 {
  v128.with_lane_bits(8, lane.to_u8().to_int(), (item & 0xFF).to_uint64())
}

///|
/// Executes a Wasm `f64x2_replace_lane` instruction.
pub fn f64x2_replace_lane(
  v128 : V128,
  lane : ImmLaneIdx2,
  item : Double,
) -> V128 {
  v128.with_lane_bits(64, lane.to_u8().to_int(), item.reinterpret_as_uint64())
}

///|
/// Executes a Wasm `f32x4_replace_lane` instruction.
pub fn f32x4_replace_lane(
  v128 : V128,
  lane : ImmLaneIdx4,
  item : Float,
) -> V128 {
  v128.with_lane_bits(
    32,
    lane.to_u8().to_int(),
    item.reinterpret_as_uint().to_uint64(),
  )
}

///|
/// Executes a Wasm `i8x16.shuffle` instruction.
///
/// `s` must have 16 lane selectors.
pub fn i8x16_shuffle(a : V128, b : V128, s : FixedArray[ImmLaneIdx32]) -> V128 {
  small_from_fn(8, i => {
    let i = s[i].to_u8().to_int()
    if i < 16 {
      a.lane_bits(8, i).to_int()
    } else {
      b.lane_bits(8, i - 16).to_int()
    }
  })
}

///|
/// Executes a Wasm `i8x16.swizzle` instruction.
pub fn i8x16_swizzle(a : V128, s : V128) -> V128 {
  small_from_fn(8, i => {
    let i = s.lane_bits(8, i).to_int()
    if i < 16 {
      a.lane_bits(8, i).to_int()
    } else {
      0
    }
  })
}

///|
/// Lanewise operation for the Wasm `q15mulr_sat` SIMD operation.
fn q15mulr_sat(x : Int, y : Int) -> Int {
  let q15mulr = (x * y + (1 << 14)) >> 15
  sat(q15mulr, -32768, 32767)
}

///|
/// `avgr!(u8 as u16)` / `avgr!(u16 as u32)`: `a.wrapping_add(b).div_ceil(2)`.
fn avgr(a : Int, b : Int) -> Int {
  (a + b + 1) >> 1
}

///|
fn wrapping_neg_small(x : Int) -> Int {
  -x
}

///|
fn wrapping_abs_small(x : Int) -> Int {
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
/// Saturates `x` to the range `min..=max`.
fn sat(x : Int, min : Int, max : Int) -> Int {
  if x < min {
    min
  } else if x > max {
    max
  } else {
    x
  }
}

///|
/// Executes a Wasm `i64x2_add` instruction.
pub fn i64x2_add(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i64(lhs, rhs, (a, b) => a + b)
}

///|
/// Executes a Wasm `i32x4_add` instruction.
pub fn i32x4_add(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, (a, b) => a + b)
}

///|
/// Executes a Wasm `i16x8_add` instruction.
pub fn i16x8_add(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, (a, b) => a + b)
}

///|
/// Executes a Wasm `i8x16_add` instruction.
pub fn i8x16_add(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, (a, b) => a + b)
}

///|
/// Executes a Wasm `i64x2_sub` instruction.
pub fn i64x2_sub(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i64(lhs, rhs, (a, b) => a - b)
}

///|
/// Executes a Wasm `i32x4_sub` instruction.
pub fn i32x4_sub(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, (a, b) => a - b)
}

///|
/// Executes a Wasm `i16x8_sub` instruction.
pub fn i16x8_sub(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, (a, b) => a - b)
}

///|
/// Executes a Wasm `i8x16_sub` instruction.
pub fn i8x16_sub(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, (a, b) => a - b)
}

///|
/// Executes a Wasm `i64x2_mul` instruction.
pub fn i64x2_mul(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i64(lhs, rhs, (a, b) => a * b)
}

///|
/// Executes a Wasm `i32x4_mul` instruction.
pub fn i32x4_mul(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, (a, b) => a * b)
}

///|
/// Executes a Wasm `i16x8_mul` instruction.
pub fn i16x8_mul(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, (a, b) => a * b)
}

///|
/// Executes a Wasm `i8x16_mul` instruction.
pub fn i8x16_mul(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, (a, b) => a * b)
}

///|
/// Executes a Wasm `i8x16_add_sat_s` instruction.
pub fn i8x16_add_sat_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, true, (a, b) => sat(a + b, -128, 127))
}

///|
/// Executes a Wasm `i8x16_add_sat_u` instruction.
pub fn i8x16_add_sat_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, (a, b) => sat(a + b, 0, 255))
}

///|
/// Executes a Wasm `i16x8_add_sat_s` instruction.
pub fn i16x8_add_sat_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, true, (a, b) => sat(a + b, -32768, 32767))
}

///|
/// Executes a Wasm `i16x8_add_sat_u` instruction.
pub fn i16x8_add_sat_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, (a, b) => sat(a + b, 0, 65535))
}

///|
/// Executes a Wasm `i8x16_sub_sat_s` instruction.
pub fn i8x16_sub_sat_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, true, (a, b) => sat(a - b, -128, 127))
}

///|
/// Executes a Wasm `i8x16_sub_sat_u` instruction.
pub fn i8x16_sub_sat_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, (a, b) => sat(a - b, 0, 255))
}

///|
/// Executes a Wasm `i16x8_sub_sat_s` instruction.
pub fn i16x8_sub_sat_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, true, (a, b) => sat(a - b, -32768, 32767))
}

///|
/// Executes a Wasm `i16x8_sub_sat_u` instruction.
pub fn i16x8_sub_sat_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, (a, b) => sat(a - b, 0, 65535))
}

///|
/// Executes a Wasm `i16x8_q15mulr_sat_s` instruction.
pub fn i16x8_q15mulr_sat_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, true, q15mulr_sat)
}

///|
/// Executes a Wasm `i8x16_min_s` instruction.
pub fn i8x16_min_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, true, Int::min)
}

///|
/// Executes a Wasm `i8x16_min_u` instruction.
pub fn i8x16_min_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, Int::min)
}

///|
/// Executes a Wasm `i16x8_min_s` instruction.
pub fn i16x8_min_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, true, Int::min)
}

///|
/// Executes a Wasm `i16x8_min_u` instruction.
pub fn i16x8_min_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, Int::min)
}

///|
/// Executes a Wasm `i32x4_min_s` instruction.
pub fn i32x4_min_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, Int::min)
}

///|
/// Executes a Wasm `i32x4_min_u` instruction.
pub fn i32x4_min_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, (a, b) => {
    if a.reinterpret_as_uint() < b.reinterpret_as_uint() {
      a
    } else {
      b
    }
  })
}

///|
/// Executes a Wasm `i8x16_max_s` instruction.
pub fn i8x16_max_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, true, Int::max)
}

///|
/// Executes a Wasm `i8x16_max_u` instruction.
pub fn i8x16_max_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, Int::max)
}

///|
/// Executes a Wasm `i16x8_max_s` instruction.
pub fn i16x8_max_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, true, Int::max)
}

///|
/// Executes a Wasm `i16x8_max_u` instruction.
pub fn i16x8_max_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, Int::max)
}

///|
/// Executes a Wasm `i32x4_max_s` instruction.
pub fn i32x4_max_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, Int::max)
}

///|
/// Executes a Wasm `i32x4_max_u` instruction.
pub fn i32x4_max_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_i32(lhs, rhs, (a, b) => {
    if a.reinterpret_as_uint() > b.reinterpret_as_uint() {
      a
    } else {
      b
    }
  })
}

///|
/// Executes a Wasm `i8x16_avgr_u` instruction.
pub fn i8x16_avgr_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 8, false, avgr)
}

///|
/// Executes a Wasm `i16x8_avgr_u` instruction.
pub fn i16x8_avgr_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_small(lhs, rhs, 16, false, avgr)
}

///|
/// Executes a Wasm `v128_and` instruction.
pub fn v128_and(lhs : V128, rhs : V128) -> V128 {
  { lo: lhs.lo & rhs.lo, hi: lhs.hi & rhs.hi, }
}

///|
/// Executes a Wasm `v128_or` instruction.
pub fn v128_or(lhs : V128, rhs : V128) -> V128 {
  { lo: lhs.lo | rhs.lo, hi: lhs.hi | rhs.hi, }
}

///|
/// Executes a Wasm `v128_xor` instruction.
pub fn v128_xor(lhs : V128, rhs : V128) -> V128 {
  { lo: lhs.lo ^ rhs.lo, hi: lhs.hi ^ rhs.hi, }
}

///|
/// Executes a Wasm `v128_andnot` instruction.
pub fn v128_andnot(lhs : V128, rhs : V128) -> V128 {
  { lo: lhs.lo & rhs.lo.lnot(), hi: lhs.hi & rhs.hi.lnot(), }
}

///|
/// Executes a Wasm `f32x4_min` instruction.
pub fn f32x4_min(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, f32_min)
}

///|
/// Executes a Wasm `f64x2_min` instruction.
pub fn f64x2_min(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, f64_min)
}

///|
/// Executes a Wasm `f32x4_max` instruction.
pub fn f32x4_max(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, f32_max)
}

///|
/// Executes a Wasm `f64x2_max` instruction.
pub fn f64x2_max(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, f64_max)
}

///|
/// Wasm SIMD `pmin` (pseudo-min) definition.
fn pmin_f32(lhs : Float, rhs : Float) -> Float {
  if rhs < lhs {
    rhs
  } else {
    lhs
  }
}

///|
/// Wasm SIMD `pmin` (pseudo-min) definition.
fn pmin_f64(lhs : Double, rhs : Double) -> Double {
  if rhs < lhs {
    rhs
  } else {
    lhs
  }
}

///|
/// Wasm SIMD `pmax` (pseudo-max) definition.
fn pmax_f32(lhs : Float, rhs : Float) -> Float {
  if lhs < rhs {
    rhs
  } else {
    lhs
  }
}

///|
/// Wasm SIMD `pmax` (pseudo-max) definition.
fn pmax_f64(lhs : Double, rhs : Double) -> Double {
  if lhs < rhs {
    rhs
  } else {
    lhs
  }
}

///|
/// Executes a Wasm `f32x4_pmin` instruction.
pub fn f32x4_pmin(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, pmin_f32)
}

///|
/// Executes a Wasm `f64x2_pmin` instruction.
pub fn f64x2_pmin(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, pmin_f64)
}

///|
/// Executes a Wasm `f32x4_pmax` instruction.
pub fn f32x4_pmax(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, pmax_f32)
}

///|
/// Executes a Wasm `f64x2_pmax` instruction.
pub fn f64x2_pmax(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, pmax_f64)
}

///|
/// Executes a Wasm `f32x4_add` instruction.
pub fn f32x4_add(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, f32_add)
}

///|
/// Executes a Wasm `f64x2_add` instruction.
pub fn f64x2_add(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, f64_add)
}

///|
/// Executes a Wasm `f32x4_sub` instruction.
pub fn f32x4_sub(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, f32_sub)
}

///|
/// Executes a Wasm `f64x2_sub` instruction.
pub fn f64x2_sub(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, f64_sub)
}

///|
/// Executes a Wasm `f32x4_div` instruction.
pub fn f32x4_div(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, f32_div)
}

///|
/// Executes a Wasm `f64x2_div` instruction.
pub fn f64x2_div(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, f64_div)
}

///|
/// Executes a Wasm `f32x4_mul` instruction.
pub fn f32x4_mul(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f32(lhs, rhs, f32_mul)
}

///|
/// Executes a Wasm `f64x2_mul` instruction.
pub fn f64x2_mul(lhs : V128, rhs : V128) -> V128 {
  lanewise_binary_f64(lhs, rhs, f64_mul)
}

///|
/// Executes a Wasm `i64x2_neg` instruction.
pub fn i64x2_neg(v128 : V128) -> V128 {
  lanewise_unary_i64(v128, x => -x)
}

///|
/// Executes a Wasm `i32x4_neg` instruction.
pub fn i32x4_neg(v128 : V128) -> V128 {
  lanewise_unary_i32(v128, x => -x)
}

///|
/// Executes a Wasm `i16x8_neg` instruction.
pub fn i16x8_neg(v128 : V128) -> V128 {
  lanewise_unary_small(v128, 16, true, wrapping_neg_small)
}

///|
/// Executes a Wasm `i8x16_neg` instruction.
pub fn i8x16_neg(v128 : V128) -> V128 {
  lanewise_unary_small(v128, 8, true, wrapping_neg_small)
}

///|
/// Executes a Wasm `i8x16_abs` instruction.
pub fn i8x16_abs(v128 : V128) -> V128 {
  lanewise_unary_small(v128, 8, true, wrapping_abs_small)
}

///|
/// Executes a Wasm `i16x8_abs` instruction.
pub fn i16x8_abs(v128 : V128) -> V128 {
  lanewise_unary_small(v128, 16, true, wrapping_abs_small)
}

///|
/// Executes a Wasm `i32x4_abs` instruction.
pub fn i32x4_abs(v128 : V128) -> V128 {
  lanewise_unary_i32(v128, wrapping_abs_small)
}

///|
/// Executes a Wasm `i64x2_abs` instruction.
pub fn i64x2_abs(v128 : V128) -> V128 {
  lanewise_unary_i64(v128, x => if x < 0 { -x } else { x })
}

///|
/// Executes a Wasm `v128_not` instruction.
pub fn v128_not(v128 : V128) -> V128 {
  { lo: v128.lo.lnot(), hi: v128.hi.lnot(), }
}

///|
/// Executes a Wasm `i8x16_popcnt` instruction.
pub fn i8x16_popcnt(v128 : V128) -> V128 {
  lanewise_unary_small(v128, 8, false, Int::popcnt)
}

///|
/// Executes a Wasm `f32x4_neg` instruction.
pub fn f32x4_neg(v128 : V128) -> V128 {
  { lo: v128.lo ^ 0x8000_0000_8000_0000, hi: v128.hi ^ 0x8000_0000_8000_0000, }
}

///|
/// Executes a Wasm `f64x2_neg` instruction.
pub fn f64x2_neg(v128 : V128) -> V128 {
  { lo: v128.lo ^ 0x8000_0000_0000_0000, hi: v128.hi ^ 0x8000_0000_0000_0000, }
}

///|
/// Executes a Wasm `f32x4_abs` instruction.
pub fn f32x4_abs(v128 : V128) -> V128 {
  { lo: v128.lo & 0x7FFF_FFFF_7FFF_FFFF, hi: v128.hi & 0x7FFF_FFFF_7FFF_FFFF, }
}

///|
/// Executes a Wasm `f64x2_abs` instruction.
pub fn f64x2_abs(v128 : V128) -> V128 {
  { lo: v128.lo & 0x7FFF_FFFF_FFFF_FFFF, hi: v128.hi & 0x7FFF_FFFF_FFFF_FFFF, }
}

///|
/// Executes a Wasm `f32x4_sqrt` instruction.
pub fn f32x4_sqrt(v128 : V128) -> V128 {
  lanewise_unary_f32(v128, f32_sqrt)
}

///|
/// Executes a Wasm `f64x2_sqrt` instruction.
pub fn f64x2_sqrt(v128 : V128) -> V128 {
  lanewise_unary_f64(v128, f64_sqrt)
}

///|
/// Executes a Wasm `f32x4_ceil` instruction.
pub fn f32x4_ceil(v128 : V128) -> V128 {
  lanewise_unary_f32(v128, f32_ceil)
}

///|
/// Executes a Wasm `f64x2_ceil` instruction.
pub fn f64x2_ceil(v128 : V128) -> V128 {
  lanewise_unary_f64(v128, f64_ceil)
}

///|
/// Executes a Wasm `f32x4_floor` instruction.
pub fn f32x4_floor(v128 : V128) -> V128 {
  lanewise_unary_f32(v128, f32_floor)
}

///|
/// Executes a Wasm `f64x2_floor` instruction.
pub fn f64x2_floor(v128 : V128) -> V128 {
  lanewise_unary_f64(v128, f64_floor)
}

///|
/// Executes a Wasm `f32x4_trunc` instruction.
pub fn f32x4_trunc(v128 : V128) -> V128 {
  lanewise_unary_f32(v128, f32_trunc)
}

///|
/// Executes a Wasm `f64x2_trunc` instruction.
pub fn f64x2_trunc(v128 : V128) -> V128 {
  lanewise_unary_f64(v128, f64_trunc)
}

///|
/// Executes a Wasm `f32x4_nearest` instruction.
pub fn f32x4_nearest(v128 : V128) -> V128 {
  lanewise_unary_f32(v128, f32_nearest)
}

///|
/// Executes a Wasm `f64x2_nearest` instruction.
pub fn f64x2_nearest(v128 : V128) -> V128 {
  lanewise_unary_f64(v128, f64_nearest)
}

///|
/// Executes a Wasm `f32x4_convert_i32x4_s` instruction.
pub fn f32x4_convert_i32x4_s(v128 : V128) -> V128 {
  lanewise_unary_i32(v128, x => f32_convert_i32_s(x).reinterpret_as_int())
}

///|
/// Executes a Wasm `f32x4_convert_i32x4_u` instruction.
pub fn f32x4_convert_i32x4_u(v128 : V128) -> V128 {
  lanewise_unary_i32(v128, x => {
    f32_convert_i32_u(x.reinterpret_as_uint()).reinterpret_as_int()
  })
}

///|
/// Executes a Wasm `i32x4_trunc_sat_f32x4_s` instruction.
pub fn i32x4_trunc_sat_f32x4_s(v128 : V128) -> V128 {
  lanewise_unary_i32(v128, x => {
    i32_trunc_sat_f32_s(Float::reinterpret_from_int(x))
  })
}

///|
/// Executes a Wasm `i32x4_trunc_sat_f32x4_u` instruction.
pub fn i32x4_trunc_sat_f32x4_u(v128 : V128) -> V128 {
  lanewise_unary_i32(v128, x => {
    i32_trunc_sat_f32_u(Float::reinterpret_from_int(x)).reinterpret_as_int()
  })
}

///|
/// Executes a Wasm `i8x16_eq` instruction.
pub fn i8x16_eq(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, true, (a, b) => a == b)
}

///|
/// Executes a Wasm `i16x8_eq` instruction.
pub fn i16x8_eq(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, true, (a, b) => a == b)
}

///|
/// Executes a Wasm `i32x4_eq` instruction.
pub fn i32x4_eq(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i32(lhs, rhs, (a, b) => a == b)
}

///|
/// Executes a Wasm `i64x2_eq` instruction.
pub fn i64x2_eq(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i64(lhs, rhs, (a, b) => a == b)
}

///|
/// Executes a Wasm `f32x4_eq` instruction.
pub fn f32x4_eq(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f32(lhs, rhs, (a, b) => a == b)
}

///|
/// Executes a Wasm `f64x2_eq` instruction.
pub fn f64x2_eq(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f64(lhs, rhs, (a, b) => a == b)
}

///|
/// Executes a Wasm `i8x16_ne` instruction.
pub fn i8x16_ne(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, true, (a, b) => a != b)
}

///|
/// Executes a Wasm `i16x8_ne` instruction.
pub fn i16x8_ne(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, true, (a, b) => a != b)
}

///|
/// Executes a Wasm `i32x4_ne` instruction.
pub fn i32x4_ne(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i32(lhs, rhs, (a, b) => a != b)
}

///|
/// Executes a Wasm `i64x2_ne` instruction.
pub fn i64x2_ne(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i64(lhs, rhs, (a, b) => a != b)
}

///|
/// Executes a Wasm `f32x4_ne` instruction.
pub fn f32x4_ne(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f32(lhs, rhs, (a, b) => a != b)
}

///|
/// Executes a Wasm `f64x2_ne` instruction.
pub fn f64x2_ne(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f64(lhs, rhs, (a, b) => a != b)
}

///|
/// Executes a Wasm `i8x16_lt_s` instruction.
pub fn i8x16_lt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, true, (a, b) => a < b)
}

///|
/// Executes a Wasm `i8x16_lt_u` instruction.
pub fn i8x16_lt_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, false, (a, b) => a < b)
}

///|
/// Executes a Wasm `i16x8_lt_s` instruction.
pub fn i16x8_lt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, true, (a, b) => a < b)
}

///|
/// Executes a Wasm `i16x8_lt_u` instruction.
pub fn i16x8_lt_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, false, (a, b) => a < b)
}

///|
/// Executes a Wasm `i32x4_lt_s` instruction.
pub fn i32x4_lt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i32(lhs, rhs, (a, b) => a < b)
}

///|
/// Executes a Wasm `i32x4_lt_u` instruction.
pub fn i32x4_lt_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_u32(lhs, rhs, (a, b) => a < b)
}

///|
/// Executes a Wasm `i64x2_lt_s` instruction.
pub fn i64x2_lt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i64(lhs, rhs, (a, b) => a < b)
}

///|
/// Executes a Wasm `f32x4_lt` instruction.
pub fn f32x4_lt(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f32(lhs, rhs, (a, b) => a < b)
}

///|
/// Executes a Wasm `f64x2_lt` instruction.
pub fn f64x2_lt(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f64(lhs, rhs, (a, b) => a < b)
}

///|
/// Executes a Wasm `i8x16_le_s` instruction.
pub fn i8x16_le_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, true, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i8x16_le_u` instruction.
pub fn i8x16_le_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, false, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i16x8_le_s` instruction.
pub fn i16x8_le_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, true, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i16x8_le_u` instruction.
pub fn i16x8_le_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, false, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i32x4_le_s` instruction.
pub fn i32x4_le_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i32(lhs, rhs, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i32x4_le_u` instruction.
pub fn i32x4_le_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_u32(lhs, rhs, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i64x2_le_s` instruction.
pub fn i64x2_le_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i64(lhs, rhs, (a, b) => a <= b)
}

///|
/// Executes a Wasm `f32x4_le` instruction.
pub fn f32x4_le(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f32(lhs, rhs, (a, b) => a <= b)
}

///|
/// Executes a Wasm `f64x2_le` instruction.
pub fn f64x2_le(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f64(lhs, rhs, (a, b) => a <= b)
}

///|
/// Executes a Wasm `i8x16_gt_s` instruction.
pub fn i8x16_gt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, true, (a, b) => a > b)
}

///|
/// Executes a Wasm `i8x16_gt_u` instruction.
pub fn i8x16_gt_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, false, (a, b) => a > b)
}

///|
/// Executes a Wasm `i16x8_gt_s` instruction.
pub fn i16x8_gt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, true, (a, b) => a > b)
}

///|
/// Executes a Wasm `i16x8_gt_u` instruction.
pub fn i16x8_gt_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, false, (a, b) => a > b)
}

///|
/// Executes a Wasm `i32x4_gt_s` instruction.
pub fn i32x4_gt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i32(lhs, rhs, (a, b) => a > b)
}

///|
/// Executes a Wasm `i32x4_gt_u` instruction.
pub fn i32x4_gt_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_u32(lhs, rhs, (a, b) => a > b)
}

///|
/// Executes a Wasm `i64x2_gt_s` instruction.
pub fn i64x2_gt_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i64(lhs, rhs, (a, b) => a > b)
}

///|
/// Executes a Wasm `f32x4_gt` instruction.
pub fn f32x4_gt(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f32(lhs, rhs, (a, b) => a > b)
}

///|
/// Executes a Wasm `f64x2_gt` instruction.
pub fn f64x2_gt(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f64(lhs, rhs, (a, b) => a > b)
}

///|
/// Executes a Wasm `i8x16_ge_s` instruction.
pub fn i8x16_ge_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, true, (a, b) => a >= b)
}

///|
/// Executes a Wasm `i8x16_ge_u` instruction.
pub fn i8x16_ge_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 8, false, (a, b) => a >= b)
}

///|
/// Executes a Wasm `i16x8_ge_s` instruction.
pub fn i16x8_ge_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, true, (a, b) => a >= b)
}

///|
/// Executes a Wasm `i16x8_ge_u` instruction.
pub fn i16x8_ge_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_small(lhs, rhs, 16, false, (a, b) => a >= b)
}

///|
/// Executes a Wasm `i32x4_ge_s` instruction.
pub fn i32x4_ge_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i32(lhs, rhs, (a, b) => a >= b)
}

///|
/// Executes a Wasm `i32x4_ge_u` instruction.
pub fn i32x4_ge_u(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_u32(lhs, rhs, (a, b) => a >= b)
}

///|
/// Executes a Wasm `i64x2_ge_s` instruction.
pub fn i64x2_ge_s(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_i64(lhs, rhs, (a, b) => a >= b)
}

///|
/// Executes a Wasm `f32x4_ge` instruction.
pub fn f32x4_ge(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f32(lhs, rhs, (a, b) => a >= b)
}

///|
/// Executes a Wasm `f64x2_ge` instruction.
pub fn f64x2_ge(lhs : V128, rhs : V128) -> V128 {
  lanewise_comparison_f64(lhs, rhs, (a, b) => a >= b)
}

///|
fn identity_int(x : Int) -> Int {
  x
}

///|
/// Executes a Wasm `i16x8_extend_low_i8x16_s` instruction.
pub fn i16x8_extend_low_i8x16_s(v128 : V128) -> V128 {
  widen_unary_small(v128, 8, true, false, identity_int)
}

///|
/// Executes a Wasm `i16x8_extend_low_i8x16_u` instruction.
pub fn i16x8_extend_low_i8x16_u(v128 : V128) -> V128 {
  widen_unary_small(v128, 8, false, false, identity_int)
}

///|
/// Executes a Wasm `i32x4_extend_low_i16x8_s` instruction.
pub fn i32x4_extend_low_i16x8_s(v128 : V128) -> V128 {
  widen_unary_small(v128, 16, true, false, identity_int)
}

///|
/// Executes a Wasm `i32x4_extend_low_i16x8_u` instruction.
pub fn i32x4_extend_low_i16x8_u(v128 : V128) -> V128 {
  widen_unary_small(v128, 16, false, false, identity_int)
}

///|
/// Executes a Wasm `i64x2_extend_low_i32x4_s` instruction.
pub fn i64x2_extend_low_i32x4_s(v128 : V128) -> V128 {
  {
    lo: v128.i32_lane(0).to_int64().reinterpret_as_uint64(),
    hi: v128.i32_lane(1).to_int64().reinterpret_as_uint64(),
  }
}

///|
/// Executes a Wasm `i64x2_extend_low_i32x4_u` instruction.
pub fn i64x2_extend_low_i32x4_u(v128 : V128) -> V128 {
  { lo: v128.lo & 0xFFFF_FFFF, hi: v128.lo >> 32, }
}

///|
/// Executes a Wasm `f64x2_convert_low_i32x4_s` instruction.
pub fn f64x2_convert_low_i32x4_s(v128 : V128) -> V128 {
  {
    lo: f64_convert_i32_s(v128.i32_lane(0)).reinterpret_as_uint64(),
    hi: f64_convert_i32_s(v128.i32_lane(1)).reinterpret_as_uint64(),
  }
}

///|
/// Executes a Wasm `f64x2_convert_low_i32x4_u` instruction.
pub fn f64x2_convert_low_i32x4_u(v128 : V128) -> V128 {
  {
    lo: f64_convert_i32_u(v128.i32_lane(0).reinterpret_as_uint()).reinterpret_as_uint64(),
    hi: f64_convert_i32_u(v128.i32_lane(1).reinterpret_as_uint()).reinterpret_as_uint64(),
  }
}

///|
/// Executes a Wasm `f64x2_promote_low_f32x4` instruction.
pub fn f64x2_promote_low_f32x4(v128 : V128) -> V128 {
  {
    lo: f64_promote_f32(v128.f32_lane(0)).reinterpret_as_uint64(),
    hi: f64_promote_f32(v128.f32_lane(1)).reinterpret_as_uint64(),
  }
}

///|
/// Executes a Wasm `i16x8_extend_high_i8x16_s` instruction.
pub fn i16x8_extend_high_i8x16_s(v128 : V128) -> V128 {
  widen_unary_small(v128, 8, true, true, identity_int)
}

///|
/// Executes a Wasm `i16x8_extend_high_i8x16_u` instruction.
pub fn i16x8_extend_high_i8x16_u(v128 : V128) -> V128 {
  widen_unary_small(v128, 8, false, true, identity_int)
}

///|
/// Executes a Wasm `i32x4_extend_high_i16x8_s` instruction.
pub fn i32x4_extend_high_i16x8_s(v128 : V128) -> V128 {
  widen_unary_small(v128, 16, true, true, identity_int)
}

///|
/// Executes a Wasm `i32x4_extend_high_i16x8_u` instruction.
pub fn i32x4_extend_high_i16x8_u(v128 : V128) -> V128 {
  widen_unary_small(v128, 16, false, true, identity_int)
}

///|
/// Executes a Wasm `i64x2_extend_high_i32x4_s` instruction.
pub fn i64x2_extend_high_i32x4_s(v128 : V128) -> V128 {
  {
    lo: v128.i32_lane(2).to_int64().reinterpret_as_uint64(),
    hi: v128.i32_lane(3).to_int64().reinterpret_as_uint64(),
  }
}

///|
/// Executes a Wasm `i64x2_extend_high_i32x4_u` instruction.
pub fn i64x2_extend_high_i32x4_u(v128 : V128) -> V128 {
  { lo: v128.hi & 0xFFFF_FFFF, hi: v128.hi >> 32, }
}

///|
fn mul_int(a : Int, b : Int) -> Int {
  a * b
}

///|
/// Executes a Wasm `i16x8_extmul_low_i8x16_s` instruction.
pub fn i16x8_extmul_low_i8x16_s(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 8, true, false, mul_int)
}

///|
/// Executes a Wasm `i16x8_extmul_low_i8x16_u` instruction.
pub fn i16x8_extmul_low_i8x16_u(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 8, false, false, mul_int)
}

///|
/// Executes a Wasm `i32x4_extmul_low_i16x8_s` instruction.
pub fn i32x4_extmul_low_i16x8_s(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 16, true, false, mul_int)
}

///|
/// Executes a Wasm `i32x4_extmul_low_i16x8_u` instruction.
pub fn i32x4_extmul_low_i16x8_u(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 16, false, false, mul_int)
}

///|
/// `extmul!(i32 => i64)` / `extmul!(u32 => u64)` of the 32-bit lanes `i`
/// and `i + 1` into a `i64x2`.
fn extmul_32(lhs : V128, rhs : V128, i : Int, signed : Bool) -> V128 {
  let wide = (v : V128, j : Int) => {
    if signed {
      v.i32_lane(j).to_int64().reinterpret_as_uint64()
    } else {
      v.i32_lane(j).reinterpret_as_uint().to_uint64()
    }
  }
  { lo: wide(lhs, i) * wide(rhs, i), hi: wide(lhs, i + 1) * wide(rhs, i + 1), }
}

///|
/// Executes a Wasm `i64x2_extmul_low_i32x4_s` instruction.
pub fn i64x2_extmul_low_i32x4_s(lhs : V128, rhs : V128) -> V128 {
  extmul_32(lhs, rhs, 0, true)
}

///|
/// Executes a Wasm `i64x2_extmul_low_i32x4_u` instruction.
pub fn i64x2_extmul_low_i32x4_u(lhs : V128, rhs : V128) -> V128 {
  extmul_32(lhs, rhs, 0, false)
}

///|
/// Executes a Wasm `i16x8_extmul_high_i8x16_s` instruction.
pub fn i16x8_extmul_high_i8x16_s(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 8, true, true, mul_int)
}

///|
/// Executes a Wasm `i16x8_extmul_high_i8x16_u` instruction.
pub fn i16x8_extmul_high_i8x16_u(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 8, false, true, mul_int)
}

///|
/// Executes a Wasm `i32x4_extmul_high_i16x8_s` instruction.
pub fn i32x4_extmul_high_i16x8_s(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 16, true, true, mul_int)
}

///|
/// Executes a Wasm `i32x4_extmul_high_i16x8_u` instruction.
pub fn i32x4_extmul_high_i16x8_u(lhs : V128, rhs : V128) -> V128 {
  widen_binary_small(lhs, rhs, 16, false, true, mul_int)
}

///|
/// Executes a Wasm `i64x2_extmul_high_i32x4_s` instruction.
pub fn i64x2_extmul_high_i32x4_s(lhs : V128, rhs : V128) -> V128 {
  extmul_32(lhs, rhs, 2, true)
}

///|
/// Executes a Wasm `i64x2_extmul_high_i32x4_u` instruction.
pub fn i64x2_extmul_high_i32x4_u(lhs : V128, rhs : V128) -> V128 {
  extmul_32(lhs, rhs, 2, false)
}

///|
fn add_int(a : Int, b : Int) -> Int {
  a + b
}

///|
/// Executes a Wasm `i16x8_extadd_pairwise_i8x16_s` instruction.
pub fn i16x8_extadd_pairwise_i8x16_s(v128 : V128) -> V128 {
  pairwise_unary_small(v128, 8, true, add_int)
}

///|
/// Executes a Wasm `i16x8_extadd_pairwise_i8x16_u` instruction.
pub fn i16x8_extadd_pairwise_i8x16_u(v128 : V128) -> V128 {
  pairwise_unary_small(v128, 8, false, add_int)
}

///|
/// Executes a Wasm `i32x4_extadd_pairwise_i16x8_s` instruction.
pub fn i32x4_extadd_pairwise_i16x8_s(v128 : V128) -> V128 {
  pairwise_unary_small(v128, 16, true, add_int)
}

///|
/// Executes a Wasm `i32x4_extadd_pairwise_i16x8_u` instruction.
pub fn i32x4_extadd_pairwise_i16x8_u(v128 : V128) -> V128 {
  pairwise_unary_small(v128, 16, false, add_int)
}

///|
/// Executes a Wasm `i8x16_shl` instruction.
pub fn i8x16_shl(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 7
  lanewise_unary_small(v128, 8, false, v => v << n)
}

///|
/// Executes a Wasm `i16x8_shl` instruction.
pub fn i16x8_shl(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 15
  lanewise_unary_small(v128, 16, false, v => v << n)
}

///|
/// Executes a Wasm `i32x4_shl` instruction.
pub fn i32x4_shl(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 31
  lanewise_unary_i32(v128, v => v << n)
}

///|
/// Executes a Wasm `i64x2_shl` instruction.
pub fn i64x2_shl(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 63
  { lo: v128.lo << n, hi: v128.hi << n, }
}

///|
/// Executes a Wasm `i8x16_shr_s` instruction.
pub fn i8x16_shr_s(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 7
  lanewise_unary_small(v128, 8, true, v => v >> n)
}

///|
/// Executes a Wasm `i8x16_shr_u` instruction.
pub fn i8x16_shr_u(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 7
  lanewise_unary_small(v128, 8, false, v => v >> n)
}

///|
/// Executes a Wasm `i16x8_shr_s` instruction.
pub fn i16x8_shr_s(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 15
  lanewise_unary_small(v128, 16, true, v => v >> n)
}

///|
/// Executes a Wasm `i16x8_shr_u` instruction.
pub fn i16x8_shr_u(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 15
  lanewise_unary_small(v128, 16, false, v => v >> n)
}

///|
/// Executes a Wasm `i32x4_shr_s` instruction.
pub fn i32x4_shr_s(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 31
  lanewise_unary_i32(v128, v => v >> n)
}

///|
/// Executes a Wasm `i32x4_shr_u` instruction.
pub fn i32x4_shr_u(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 31
  lanewise_unary_i32(v128, v => {
    (v.reinterpret_as_uint() >> n).reinterpret_as_int()
  })
}

///|
/// Executes a Wasm `i64x2_shr_s` instruction.
pub fn i64x2_shr_s(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 63
  lanewise_unary_i64(v128, v => v >> n)
}

///|
/// Executes a Wasm `i64x2_shr_u` instruction.
pub fn i64x2_shr_u(v128 : V128, rhs : UInt) -> V128 {
  let n = rhs.reinterpret_as_int() & 63
  { lo: v128.lo >> n, hi: v128.hi >> n, }
}

///|
/// Narrows `value` from type `i16` to type `i8`.
fn narrow_i16_to_i8(value : Int) -> Int {
  sat(value, -128, 127)
}

///|
/// Narrows `value` from type `u16` (as `i16`) to type `u8`.
fn narrow_u16_to_u8(value : Int) -> Int {
  sat(value, 0, 255)
}

///|
/// Narrows `value` from type `i32` to type `i16`.
fn narrow_i32_to_i16(value : Int) -> Int {
  sat(value, -32768, 32767)
}

///|
/// Narrows `value` from type `u32` (as `i32`) to type `u16`.
fn narrow_u32_to_u16(value : Int) -> Int {
  sat(value, 0, 65535)
}

///|
/// Executes a Wasm `i8x16_narrow_i16x8_s` instruction.
pub fn i8x16_narrow_i16x8_s(low : V128, high : V128) -> V128 {
  narrow_low_high(low, high, 16, narrow_i16_to_i8)
}

///|
/// Executes a Wasm `i8x16_narrow_i16x8_u` instruction.
pub fn i8x16_narrow_i16x8_u(low : V128, high : V128) -> V128 {
  narrow_low_high(low, high, 16, narrow_u16_to_u8)
}

///|
/// Executes a Wasm `i16x8_narrow_i32x4_s` instruction.
pub fn i16x8_narrow_i32x4_s(low : V128, high : V128) -> V128 {
  narrow_low_high(low, high, 32, narrow_i32_to_i16)
}

///|
/// Executes a Wasm `i16x8_narrow_i32x4_u` instruction.
pub fn i16x8_narrow_i32x4_u(low : V128, high : V128) -> V128 {
  narrow_low_high(low, high, 32, narrow_u32_to_u16)
}

///|
/// Executes a Wasm `i32x4_trunc_sat_f64x2_s_zero` instruction.
pub fn i32x4_trunc_sat_f64x2_s_zero(low : V128) -> V128 {
  i32x4_from(
    i32_trunc_sat_f64_s(low.lo.reinterpret_as_double()),
    i32_trunc_sat_f64_s(low.hi.reinterpret_as_double()),
    0,
    0,
  )
}

///|
/// Executes a Wasm `i32x4_trunc_sat_f64x2_u_zero` instruction.
pub fn i32x4_trunc_sat_f64x2_u_zero(low : V128) -> V128 {
  i32x4_from(
    i32_trunc_sat_f64_u(low.lo.reinterpret_as_double()).reinterpret_as_int(),
    i32_trunc_sat_f64_u(low.hi.reinterpret_as_double()).reinterpret_as_int(),
    0,
    0,
  )
}

///|
/// Executes a Wasm `f32x4_demote_f64x2_zero` instruction.
pub fn f32x4_demote_f64x2_zero(low : V128) -> V128 {
  i32x4_from(
    f32_demote_f64(low.lo.reinterpret_as_double()).reinterpret_as_int(),
    f32_demote_f64(low.hi.reinterpret_as_double()).reinterpret_as_int(),
    0,
    0,
  )
}

///|
/// `all_true!` for `bits`-wide lanes.
fn all_true(v128 : V128, bits : Int) -> Bool {
  for i in 0..<(128 / bits) {
    if v128.lane_bits(bits, i) == 0 {
      return false
    }
  }
  true
}

///|
/// Executes a Wasm `i8x16_all_true` instruction.
pub fn i8x16_all_true(v128 : V128) -> Bool {
  all_true(v128, 8)
}

///|
/// Executes a Wasm `i16x8_all_true` instruction.
pub fn i16x8_all_true(v128 : V128) -> Bool {
  all_true(v128, 16)
}

///|
/// Executes a Wasm `i32x4_all_true` instruction.
pub fn i32x4_all_true(v128 : V128) -> Bool {
  all_true(v128, 32)
}

///|
/// Executes a Wasm `i64x2_all_true` instruction.
pub fn i64x2_all_true(v128 : V128) -> Bool {
  all_true(v128, 64)
}

///|
/// `bitmask!` for `bits`-wide lanes: bit `n` is set if lane `n` is negative.
fn bitmask(v128 : V128, bits : Int) -> UInt {
  let mut acc = 0U
  for n in 0..<(128 / bits) {
    if v128.lane_bits(bits, n) >> (bits - 1) != 0 {
      acc = acc | (1U << n)
    }
  }
  acc
}

///|
/// Executes a Wasm `i8x16_bitmask` instruction.
pub fn i8x16_bitmask(v128 : V128) -> UInt {
  bitmask(v128, 8)
}

///|
/// Executes a Wasm `i16x8_bitmask` instruction.
pub fn i16x8_bitmask(v128 : V128) -> UInt {
  bitmask(v128, 16)
}

///|
/// Executes a Wasm `i32x4_bitmask` instruction.
pub fn i32x4_bitmask(v128 : V128) -> UInt {
  bitmask(v128, 32)
}

///|
/// Executes a Wasm `i64x2_bitmask` instruction.
pub fn i64x2_bitmask(v128 : V128) -> UInt {
  bitmask(v128, 64)
}

///|
/// Executes a Wasm `v128.any_true` instruction.
pub fn v128_any_true(v128 : V128) -> Bool {
  (v128.lo | v128.hi) != 0
}

///|
/// Executes a Wasm `i32x4.dot_i16x8_s` instruction.
pub fn i32x4_dot_i16x8_s(lhs : V128, rhs : V128) -> V128 {
  let dot = i => {
    let a0 = ext_small(lhs.lane_bits(16, 2 * i), 16, true)
    let a1 = ext_small(lhs.lane_bits(16, 2 * i + 1), 16, true)
    let b0 = ext_small(rhs.lane_bits(16, 2 * i), 16, true)
    let b1 = ext_small(rhs.lane_bits(16, 2 * i + 1), 16, true)
    a0 * b0 + a1 * b1
  }
  i32x4_from(dot(0), dot(1), dot(2), dot(3))
}

///|
/// Executes a Wasm `i16x8.relaxed_dot_i8x16_i7x16_s` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i16x8_relaxed_dot_i8x16_i7x16_s(lhs : V128, rhs : V128) -> V128 {
  pairwise_binary_small(lhs, rhs, 8, true, (a0, a1, b0, b1) => a0 * b0 + a1 * b1)
}

///|
/// Executes a Wasm `i32x4.relaxed_dot_i8x16_i7x16_add_s` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i32x4_relaxed_dot_i8x16_i7x16_add_s(
  lhs : V128,
  rhs : V128,
  c : V128,
) -> V128 {
  let dot = i16x8_relaxed_dot_i8x16_i7x16_s(lhs, rhs)
  let ext = i32x4_extadd_pairwise_i16x8_s(dot)
  i32x4_add(ext, c)
}

///|
/// Executes a Wasm `v128.bitselect` instruction.
pub fn v128_bitselect(v1 : V128, v2 : V128, c : V128) -> V128 {
  v128_or(v128_and(v1, c), v128_andnot(v2, c))
}

///|
/// Computes the negative `mul_add`: `-(a * b) + c`
fn neg_mul_add_f32(a : Float, b : Float, c : Float) -> Float {
  libm_fmaf(f32_hw_neg(a), b, c)
}

///|
/// Computes the negative `mul_add`: `-(a * b) + c`
fn neg_mul_add_f64(a : Double, b : Double, c : Double) -> Double {
  libm_fma(f64_hw_neg(a), b, c)
}

///|
/// Executes a Wasm `f32x4_relaxed_madd` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f32x4_relaxed_madd(a : V128, b : V128, c : V128) -> V128 {
  lanewise_ternary_f32(a, b, c, libm_fmaf)
}

///|
/// Executes a Wasm `f32x4_relaxed_nmadd` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f32x4_relaxed_nmadd(a : V128, b : V128, c : V128) -> V128 {
  lanewise_ternary_f32(a, b, c, neg_mul_add_f32)
}

///|
/// Executes a Wasm `f64x2_relaxed_madd` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f64x2_relaxed_madd(a : V128, b : V128, c : V128) -> V128 {
  lanewise_ternary_f64(a, b, c, libm_fma)
}

///|
/// Executes a Wasm `f64x2_relaxed_nmadd` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f64x2_relaxed_nmadd(a : V128, b : V128, c : V128) -> V128 {
  lanewise_ternary_f64(a, b, c, neg_mul_add_f64)
}

// Relaxed SIMD operations forwarding to their deterministic counterparts.

///|
/// Executes a Wasm `i8x16_relaxed_swizzle` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i8x16_relaxed_swizzle(a : V128, s : V128) -> V128 {
  i8x16_swizzle(a, s)
}

///|
/// Executes a Wasm `i8x16_relaxed_laneselect` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i8x16_relaxed_laneselect(a : V128, b : V128, c : V128) -> V128 {
  v128_bitselect(a, b, c)
}

///|
/// Executes a Wasm `i16x8_relaxed_laneselect` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i16x8_relaxed_laneselect(a : V128, b : V128, c : V128) -> V128 {
  v128_bitselect(a, b, c)
}

///|
/// Executes a Wasm `i32x4_relaxed_laneselect` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i32x4_relaxed_laneselect(a : V128, b : V128, c : V128) -> V128 {
  v128_bitselect(a, b, c)
}

///|
/// Executes a Wasm `i64x2_relaxed_laneselect` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i64x2_relaxed_laneselect(a : V128, b : V128, c : V128) -> V128 {
  v128_bitselect(a, b, c)
}

///|
/// Executes a Wasm `f32x4_relaxed_min` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f32x4_relaxed_min(lhs : V128, rhs : V128) -> V128 {
  f32x4_min(lhs, rhs)
}

///|
/// Executes a Wasm `f32x4_relaxed_max` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f32x4_relaxed_max(lhs : V128, rhs : V128) -> V128 {
  f32x4_max(lhs, rhs)
}

///|
/// Executes a Wasm `f64x2_relaxed_min` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f64x2_relaxed_min(lhs : V128, rhs : V128) -> V128 {
  f64x2_min(lhs, rhs)
}

///|
/// Executes a Wasm `f64x2_relaxed_max` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn f64x2_relaxed_max(lhs : V128, rhs : V128) -> V128 {
  f64x2_max(lhs, rhs)
}

///|
/// Executes a Wasm `i16x8_relaxed_q15mulr_s` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i16x8_relaxed_q15mulr_s(a : V128, b : V128) -> V128 {
  i16x8_q15mulr_sat_s(a, b)
}

///|
/// Executes a Wasm `i32x4_relaxed_trunc_f32x4_s` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i32x4_relaxed_trunc_f32x4_s(input : V128) -> V128 {
  i32x4_trunc_sat_f32x4_s(input)
}

///|
/// Executes a Wasm `i32x4_relaxed_trunc_f32x4_u` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i32x4_relaxed_trunc_f32x4_u(input : V128) -> V128 {
  i32x4_trunc_sat_f32x4_u(input)
}

///|
/// Executes a Wasm `i32x4_relaxed_trunc_f64x2_s_zero` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i32x4_relaxed_trunc_f64x2_s_zero(input : V128) -> V128 {
  i32x4_trunc_sat_f64x2_s_zero(input)
}

///|
/// Executes a Wasm `i32x4_relaxed_trunc_f64x2_u_zero` instruction.
///
/// # Note
///
/// This is part of the `relaxed-simd` Wasm proposal.
pub fn i32x4_relaxed_trunc_f64x2_u_zero(input : V128) -> V128 {
  i32x4_trunc_sat_f64x2_u_zero(input)
}
