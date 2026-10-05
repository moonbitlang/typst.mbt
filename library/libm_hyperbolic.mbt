// Hyperbolic functions of the `libm` crate (0.2, a port of musl), which
// upstream uses for `calc.sinh`/`cosh`/`tanh`/`asinh`/`acosh`/`atanh`
// (typst-library/src/foundations/calc.rs). musl computes them from `expm1`,
// `exp`, `log` and `log1p` with other formulas than the fdlibm versions
// ported in `@math`; see `libm_wbtest.mbt`.

///|
const LIBM_LN2 : Double = 0.693147180559945309417232121458176568 // 0x3fe62e42,  0xfefa39ef

///|
/// `libm::sinh`: the hyperbolic sine of `x`.
///
/// sinh(x) = (exp(x) - 1/exp(x))/2
///         = (exp(x)-1 + (exp(x)-1)/exp(x))/2
///         = x + x^3/6 + o(x^5)
fn libm_sinh(x : Double) -> Double {
  let mut ui = x.reinterpret_as_uint64()
  let mut h = 0.5
  if ui >> 63 != 0 {
    h = -h
  }
  // |x|
  ui = ui & 0x7fffffffffffffffUL
  let absx = ui.reinterpret_as_double()
  let w = (ui >> 32).to_uint()
  // |x| < log(DBL_MAX)
  if w < 0x40862e42 {
    let t = libm_expm1(absx)
    if w < 0x3ff00000 {
      if w < 0x3ff00000 - (26 << 20) {
        // note: inexact and underflow are raised by expm1
        // note: this branch avoids spurious underflow
        return x
      }
      return h * (2.0 * t - t * t / (t + 1.0))
    }
    // note: |x|>log(0x1p26)+eps could be just h*exp(x)
    return h * (t + t / (t + 1.0))
  }
  // |x| > log(DBL_MAX) or nan
  // note: the result is stored to handle overflow
  2.0 * h * libm_expo2(absx)
}

///|
/// `libm::cosh`: the hyperbolic cosine of `x`, `(exp(x) + exp(-x))/2`.
fn libm_cosh(x : Double) -> Double {
  // |x|
  let mut ix = x.reinterpret_as_uint64()
  ix = ix & 0x7fffffffffffffffUL
  let x = ix.reinterpret_as_double()
  let w = (ix >> 32).to_uint()
  // |x| < log(2)
  if w < 0x3fe62e42 {
    if w < 0x3ff00000 - (26 << 20) {
      return 1.0
    }
    let t = libm_expm1(x) // exponential minus 1
    return 1.0 + t * t / (2.0 * (1.0 + t))
  }
  // |x| < log(DBL_MAX)
  if w < 0x40862e42 {
    let t = libm_exp(x)
    // note: if x>log(0x1p26) then the 1/t is not needed
    return 0.5 * (t + 1.0 / t)
  }
  // |x| > log(DBL_MAX) or nan
  libm_expo2(x)
}

///|
/// `libm::tanh`: the hyperbolic tangent of `x`.
///
/// tanh(x) = (exp(x) - exp(-x))/(exp(x) + exp(-x))
///         = (exp(2*x) - 1)/(exp(2*x) - 1 + 2)
///         = (1 - exp(-2*x))/(exp(-2*x) - 1 + 2)
fn libm_tanh(x : Double) -> Double {
  let mut ui = x.reinterpret_as_uint64()
  // x = |x|
  let sign = ui >> 63 != 0
  ui = ui & 0x7fffffffffffffffUL
  let x = ui.reinterpret_as_double()
  let w = (ui >> 32).to_uint()
  let mut t = 0.0
  if w > 0x3fe193ea {
    // |x| > log(3)/2 ~= 0.5493 or nan
    if w > 0x40340000 {
      // |x| > 20 or nan
      // note: this branch avoids raising overflow
      t = 1.0 - 0.0 / x
    } else {
      t = libm_expm1(2.0 * x)
      t = 1.0 - 2.0 / (t + 2.0)
    }
  } else if w > 0x3fd058ae {
    // |x| > log(5/3)/2 ~= 0.2554
    t = libm_expm1(2.0 * x)
    t = t / (t + 2.0)
  } else if w >= 0x00100000 {
    // |x| >= 0x1p-1022, up to 2ulp error in [0.1,0.2554]
    t = libm_expm1(-2.0 * x)
    t = -t / (t + 2.0)
  } else {
    // |x| is subnormal
    // note: the branch above would not raise underflow in [0x1p-1023,0x1p-1022)
    t = x
  }
  if sign {
    -t
  } else {
    t
  }
}

///|
/// `libm::asinh`: the inverse hyperbolic sine of `x`.
///
/// asinh(x) = sign(x)*log(|x|+sqrt(x*x+1)) ~= x - x^3/6 + o(x^5)
fn libm_asinh(x : Double) -> Double {
  let mut u = x.reinterpret_as_uint64()
  let e = (u >> 52).to_int() & 0x7ff
  let sign = u >> 63 != 0
  // |x|
  u = u & 0x7fffffffffffffffUL
  let mut x = u.reinterpret_as_double()
  if e >= 0x3ff + 26 {
    // |x| >= 0x1p26 or inf or nan
    x = libm_log(x) + LIBM_LN2
  } else if e >= 0x3ff + 1 {
    // |x| >= 2
    x = libm_log(2.0 * x + 1.0 / ((x * x + 1.0).sqrt() + x))
  } else if e >= 0x3ff - 26 {
    // |x| >= 0x1p-26, up to 1.6ulp error in [0.125,0.5]
    x = libm_log1p(x + x * x / ((x * x + 1.0).sqrt() + 1.0))
  } else {
    // |x| < 0x1p-26, raise inexact if x != 0
    ()
  }
  if sign {
    -x
  } else {
    x
  }
}

///|
/// `libm::acosh`: the inverse hyperbolic cosine of `x`,
/// `log(x + sqrt(x*x-1))`. `x` must be a number greater than or equal to 1.
fn libm_acosh(x : Double) -> Double {
  let u = x.reinterpret_as_uint64()
  let e = (u >> 52).to_int() & 0x7ff
  // x < 1 domain error is handled in the called functions
  if e < 0x3ff + 1 {
    // |x| < 2, up to 2ulp error in [1,1.125]
    return libm_log1p(
      x - 1.0 + ((x - 1.0) * (x - 1.0) + 2.0 * (x - 1.0)).sqrt(),
    )
  }
  if e < 0x3ff + 26 {
    // |x| < 0x1p26
    return libm_log(2.0 * x - 1.0 / (x + (x * x - 1.0).sqrt()))
  }
  // |x| >= 0x1p26 or nan
  libm_log(x) + LIBM_LN2
}

///|
/// `libm::atanh`: the inverse hyperbolic tangent of `x`.
///
/// atanh(x) = log((1+x)/(1-x))/2 = log1p(2x/(1-x))/2 ~= x + x^3/3 + o(x^5)
fn libm_atanh(x : Double) -> Double {
  let u = x.reinterpret_as_uint64()
  let e = (u >> 52).to_int() & 0x7ff
  let sign = u >> 63 != 0
  // |x|
  let mut y = (u & 0x7fffffffffffffffUL).reinterpret_as_double()
  if e < 0x3ff - 1 {
    if e < 0x3ff - 32 {
      // handle underflow
      ()
    } else {
      // |x| < 0.5, up to 1.7ulp error
      y = 0.5 * libm_log1p(2.0 * y + 2.0 * y * y / (1.0 - y))
    }
  } else {
    // avoid overflow
    y = 0.5 * libm_log1p(2.0 * (y / (1.0 - y)))
  }
  if sign {
    -y
  } else {
    y
  }
}
