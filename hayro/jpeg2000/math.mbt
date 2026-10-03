// Port of `hayro-jpeg2000/src/math.rs`.
//
// hayro builds the crate with the `std` and `simd` features on aarch64, so
// `f32x8` is fearless_simd's NEON vector: its operations are ported lane by
// lane where they are used (`mul_add` is a fused `vfmaq_f32`, `floor` is
// exact, `min`/`max` are `vminq_f32`/`vmaxq_f32`, which propagate NaN), and
// the scalar `mul_add` is `f32::mul_add` (a fused multiply-add as well).

///|
const SIMD_WIDTH : Int = 8

// Note that these polyfills can be very imprecise, but hopefully good enough
// for the vast majority of cases.

///|
fn mul_add(a : Float, b : Float, c : Float) -> Float {
  fmaf(a, b, c)
}

///|
fn floor_f32(x : Float) -> Float {
  floorf(x)
}

///|
/// `f32::round`: rounds half-way cases away from zero.
fn round_f32(x : Float) -> Float {
  roundf(x)
}

///|
fn pow2i(exp : Int) -> Float {
  if exp >= 0 {
    shl_u32(1, exp).to_float()
  } else {
    (1.0 : Float) / shl_u32(1, -exp).to_float()
  }
}

///|
/// `vminq_f32` (one lane): NaN if either operand is NaN.
fn neon_min(a : Float, b : Float) -> Float {
  if a.is_nan() {
    quiet_nan(a)
  } else if b.is_nan() {
    quiet_nan(b)
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// `vmaxq_f32` (one lane): NaN if either operand is NaN.
fn neon_max(a : Float, b : Float) -> Float {
  if a.is_nan() {
    quiet_nan(a)
  } else if b.is_nan() {
    quiet_nan(b)
  } else if a > b {
    a
  } else {
    b
  }
}

///|
fn quiet_nan(a : Float) -> Float {
  Float::reinterpret_from_uint(a.reinterpret_as_uint() | 0x400000)
}

///|
/// Rust's `x << n` for `u32` without overflow checks (the shift amount is
/// masked).
fn shl_u32(x : UInt, n : Int) -> UInt {
  x << (n & 31)
}

///|
/// Rust's `x << n` for `i32` without overflow checks.
fn shl_i32(x : Int, n : Int) -> Int {
  x << (n & 31)
}

///|
fn div_ceil_u32(a : UInt, b : UInt) -> UInt {
  let d = a / b
  if a % b != 0 {
    d + 1
  } else {
    d
  }
}

///|
fn div_ceil_u64(a : UInt64, b : UInt64) -> UInt64 {
  let d = a / b
  if a % b != 0 {
    d + 1
  } else {
    d
  }
}

///|
fn min_u32(a : UInt, b : UInt) -> UInt {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_u32(a : UInt, b : UInt) -> UInt {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// `x as u8` for an `f32` (saturating, NaN maps to 0).
fn f32_to_u8(x : Float) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 255.0 {
    255
  } else {
    x.to_int()
  }
}

///|
/// `x as i64` for an `f32` (saturating, NaN maps to 0).
fn f32_to_i64(x : Float) -> Int64 {
  if x.is_nan() {
    0
  } else if x >= 9223372036854775807.0 {
    9223372036854775807L
  } else if x <= -9223372036854775808.0 {
    -9223372036854775808L
  } else {
    x.to_double().to_int64()
  }
}

///|
/// A wrapper around `Vec<f32>` that pads the vector to a multiple of `N`
/// elements. This allows SIMD operations to safely process the data without
/// bounds checking at the end of the buffer. (`N` is always `SIMD_WIDTH`.)
priv struct SimdBuffer {
  data : FixedArray[Float]
  original_len : Int
}

///|
/// Create a new `SimdBuffer` from a `Vec<f32>`, padding it to a multiple of
/// `N`.
fn SimdBuffer::new(data : Array[Float]) -> SimdBuffer {
  let original_len = data.length()
  let padded_len = SimdBuffer::padded_len(original_len)
  let out = FixedArray::make(padded_len, (0.0 : Float))
  for i in 0..<original_len {
    out[i] = data[i]
  }
  { data: out, original_len, }
}

///|
/// Create a new `SimdBuffer` filled with zeros.
fn SimdBuffer::zeros(original_len : Int) -> SimdBuffer {
  let padded_len = SimdBuffer::padded_len(original_len)
  { data: FixedArray::make(padded_len, (0.0 : Float)), original_len, }
}

///|
/// Returns only the original (non-padded) data as an immutable slice.
fn SimdBuffer::truncated(self : SimdBuffer) -> ArrayView[Float] {
  self.data.exact_view(end=self.original_len)
}

///|
/// The length of the (padded) data, like `Deref` upstream.
fn SimdBuffer::len(self : SimdBuffer) -> Int {
  self.data.length()
}

///|
fn SimdBuffer::clone(self : SimdBuffer) -> SimdBuffer {
  { data: self.data.copy(), original_len: self.original_len, }
}

///|
/// Returns the length padded to a multiple of `N`
fn SimdBuffer::padded_len(original_len : Int) -> Int {
  let remainder = original_len % SIMD_WIDTH
  let padding = SIMD_WIDTH - remainder
  original_len + padding
}

///|
/// A growable `Vec<f32>` whose contents survive `resize`/`clear` like
/// upstream's reused buffers (elements past the length are zeroed when the
/// vector grows again).
priv struct FloatVec {
  mut data : FixedArray[Float]
  mut len : Int
}

///|
fn FloatVec::new() -> FloatVec {
  { data: FixedArray::make(0, (0.0 : Float)), len: 0, }
}

///|
fn FloatVec::reserve(self : FloatVec, capacity : Int) -> Unit {
  if self.data.length() < capacity {
    let data = FixedArray::make(capacity, (0.0 : Float))
    self.data.blit_to(data, len=self.len)
    self.data = data
  }
}

///|
/// `Vec::resize(new_len, 0.0)`.
fn FloatVec::resize(self : FloatVec, new_len : Int) -> Unit {
  if new_len > self.len {
    if new_len > self.data.length() {
      let cap = if self.data.length() * 2 > new_len {
        self.data.length() * 2
      } else {
        new_len
      }
      self.reserve(cap)
    }
    self.data.fill(0.0, start=self.len, end=new_len)
  }
  self.len = new_len
}
