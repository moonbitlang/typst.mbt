// Port of `tiny-skia/src/math.rs` and `fixed_point.rs`.
//
// Skia uses fixed points pretty chaotically, therefore we cannot use
// strongly typed wrappers. FDot6, FDot8 and FDot16 are all `Int`.

///|
fn left_shift(value : Int, shift : Int) -> Int {
  (value.reinterpret_as_uint() << shift).reinterpret_as_int()
}

///|
fn left_shift64(value : Int64, shift : Int) -> Int64 {
  (value.reinterpret_as_uint64() << shift).reinterpret_as_int64()
}

///|
/// Skia cites
/// http://www.machinedlearnings.com/2011/06/fast-approximate-logarithm-exponential.html
fn approx_powf(x : Float, y : Float) -> Float {
  if x == 0.0 || x == 1.0 {
    return x
  }
  let e = Float::from_uint(x.reinterpret_as_uint()) *
    ((1.0 : Float) / Float::from_int(1 << 23))
  let m = Float::reinterpret_from_uint(
    (x.reinterpret_as_uint() & 0x007fffff) | 0x3f000000,
  )
  let log2_x = e -
    (124.225514990 : Float) -
    (1.498030302 : Float) * m -
    (1.725879990 : Float) / ((0.3520887068 : Float) + m)
  let x = log2_x * y
  let f = x - @path.floorf(x)
  let mut a = x + (121.274057500 : Float)
  a -= f * (1.490129070 : Float)
  a += (27.728023300 : Float) / ((4.84252568 : Float) - f)
  a *= Float::from_int(1 << 23)
  if a < Float::from_uint(@path.f32_infinity.reinterpret_as_uint()) {
    if a > 0.0 {
      Float::reinterpret_from_uint(@path.f32_to_u32(@path.roundf(a)))
    } else {
      0.0
    }
  } else {
    @path.f32_infinity
  }
}

// fdot6

///|
let fdot6_one : Int = 64

///|
fn fdot6_from_i32(n : Int) -> Int {
  n << 6
}

///|
fn fdot6_from_f32(n : Float) -> Int {
  @path.f32_to_i32(n * 64.0)
}

///|
fn fdot6_floor(n : Int) -> Int {
  n >> 6
}

///|
fn fdot6_ceil(n : Int) -> Int {
  (n + 63) >> 6
}

///|
fn fdot6_round(n : Int) -> Int {
  (n + 32) >> 6
}

///|
fn fdot6_to_fdot16(n : Int) -> Int {
  left_shift(n, 10)
}

///|
fn fdot6_div(a : Int, b : Int) -> Int {
  if a >= -32768 && a <= 32767 {
    left_shift(a, 16) / b
  } else {
    fdot16_div(a, b)
  }
}

///|
fn fdot6_can_convert_to_fdot16(n : Int) -> Bool {
  let max_dot6 = 0x7FFFFFFF >> (16 - 6)
  n.abs() <= max_dot6
}

///|
fn fdot6_small_scale(value : Int, dot6 : Int) -> Int {
  ((value * dot6) >> 6) & 0xFF
}

// fdot8 (extracted from SkScan_Antihair.cpp)

///|
fn fdot8_from_fdot16(x : Int) -> Int {
  (x + 0x80) >> 8
}

// fdot16

///|
let fdot16_half : Int = (1 << 16) / 2

///|
let fdot16_one : Int = 1 << 16

///|
/// `from_f32` seems to lack a rounding step. For all fixed-point values, this
/// version is as accurate as possible for (fixed -> float -> fixed).
fn fdot16_from_f32(x : Float) -> Int {
  @path.i32_saturate_from(x * Float::from_int(fdot16_one))
}

///|
fn fdot16_floor_to_i32(x : Int) -> Int {
  x >> 16
}

///|
fn fdot16_ceil_to_i32(x : Int) -> Int {
  (x + fdot16_one - 1) >> 16
}

///|
fn fdot16_round_to_i32(x : Int) -> Int {
  (x + fdot16_half) >> 16
}

///|
/// The divide may exceed 32 bits. Clamp to a signed 32 bit result.
fn fdot16_mul(a : Int, b : Int) -> Int {
  ((a.to_int64() * b.to_int64()) >> 16).to_int()
}

///|
/// The divide may exceed 32 bits. Clamp to a signed 32 bit result.
fn fdot16_div(numer : Int, denom : Int) -> Int {
  let v = left_shift64(numer.to_int64(), 16) / denom.to_int64()
  let n = if v > 2147483647L {
    2147483647L
  } else if v < -2147483648L {
    -2147483648L
  } else {
    v
  }
  n.to_int()
}

///|
fn fdot16_fast_div(a : Int, b : Int) -> Int {
  left_shift(a, 16) / b
}
