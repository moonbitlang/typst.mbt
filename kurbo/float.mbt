// Rust `f64` method semantics (as compiled for aarch64) used by the stroke
// expansion code, for bit-identical results with upstream.

///|
/// `core::f64::consts::PI`.
const PI : Double = 3.141592653589793

///|
/// `core::f64::consts::FRAC_PI_2`.
const FRAC_PI_2 : Double = 1.5707963267948966

///|
/// Rust's `f64::max` (IEEE maxNum, `fmaxnm` on aarch64): if one argument is
/// NaN, the other is returned; `-0.0 < +0.0`.
fn fmax(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else {
    // Equal: only signed zeros can differ.
    (a.reinterpret_as_uint64() & b.reinterpret_as_uint64()).reinterpret_as_double()
  }
}

///|
/// Rust's `f64::min` (IEEE minNum, `fminnm` on aarch64): if one argument is
/// NaN, the other is returned; `-0.0 < +0.0`.
fn fmin(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else {
    (a.reinterpret_as_uint64() | b.reinterpret_as_uint64()).reinterpret_as_double()
  }
}

///|
/// Rust's `f64::signum`.
fn signum(x : Double) -> Double {
  if x.is_nan() {
    x
  } else {
    copysign(1.0, x)
  }
}

///|
/// Rust's `f64::abs`.
fn fabs(x : Double) -> Double {
  (x.reinterpret_as_uint64() & 0x7FFF_FFFF_FFFF_FFFFUL).reinterpret_as_double()
}

///|
/// Rust's `f64::powi` with a constant exponent, as lowered by LLVM
/// (binary decomposition: `powi(x, 6) = (x*x) * ((x*x)*(x*x))`).
fn powi(x : Double, n : Int) -> Double {
  let mut res : Double? = None
  let mut cur = x
  let mut n = n
  while n != 0 {
    if (n & 1) != 0 {
      res = match res {
        Some(r) => Some(r * cur)
        None => Some(cur)
      }
    }
    n = n >> 1
    if n != 0 {
      cur = cur * cur
    }
  }
  res.unwrap_or(1.0)
}

///|
/// Rust's `f64::rem_euclid`.
fn rem_euclid(x : Double, rhs : Double) -> Double {
  let r = libm_fmod(x, rhs)
  if r < 0.0 {
    r + fabs(rhs)
  } else {
    r
  }
}

///|
/// Rust's `f64::ceil`.
fn fceil(x : Double) -> Double {
  @math.ceil(x)
}

///|
/// Rust's `f64::sin_cos` (merged by LLVM into one `sincos` call).
fn sin_cos(x : Double) -> (Double, Double) {
  (libm_sincos_sin(x), libm_sincos_cos(x))
}

///|
/// Rust's saturating `f64 as u64` cast.
fn f64_to_u64_sat(x : Double) -> UInt64 {
  if x.is_nan() || x <= 0.0 {
    0UL
  } else if x >= 18446744073709551615.0 {
    0xFFFF_FFFF_FFFF_FFFFUL
  } else {
    x.to_uint64()
  }
}

///|
/// Rust's saturating `f64 as usize` cast, clamped to the `Int` range (used
/// for loop counts only).
fn f64_to_count(x : Double) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// `-0.0`, the neutral element of Rust's `<f64 as Sum>`.
let neg_zero : Double = 0x8000_0000_0000_0000UL.reinterpret_as_double()
