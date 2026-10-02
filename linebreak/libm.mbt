// Port of the `f32` math routines of `libm 0.2` (`expf`, `expm1f`, `tanhf`,
// `scalbnf`), which `icu_segmenter`'s LSTM uses through `core_maths` (the
// crate is `no_std`). They are musl/FreeBSD ports; bit-exact results matter
// because the LSTM's break decisions are argmax comparisons.

///|
fn f32(bits : UInt) -> Float {
  Float::reinterpret_from_uint(bits)
}

///|
fn bits(x : Float) -> UInt {
  x.reinterpret_as_uint()
}

// expf.rs (origin: FreeBSD /usr/src/lib/msun/src/e_expf.c)

///|
let exp_ln2_hi : Float = f32(0x3f317200) // 6.9314575195e-01

///|
let exp_ln2_lo : Float = f32(0x35bfbe8e) // 1.4286067653e-06

///|
let inv_ln2 : Float = f32(0x3fb8aa3b) // 1.4426950216e+00

///|
// Domain [-0.34568, 0.34568], range ~[-4.278e-9, 4.447e-9]:
// |x*(exp(x)+1)/(exp(x)-1) - p(x)| < 2**-27.74
let exp_p1 : Float = f32(0x3e2aaa8f) //  0xaaaa8f.0p-26

///|
let exp_p2 : Float = f32(0xbb355215) // -0xb55215.0p-32

///|
/// Exponential, base *e* (f32)
fn expf(x : Float) -> Float {
  let mut x = x
  let x1p127 = f32(0x7f000000) // 0x1p127f === 2 ^ 127
  let mut hx = bits(x)
  let sign = (hx >> 31).reinterpret_as_int() // sign bit of x
  let signb = sign != 0
  hx = hx & 0x7fffffff // high word of |x|

  // special cases
  if hx >= 0x42aeac50 {
    // if |x| >= -87.33655f or NaN
    if hx > 0x7f800000 {
      // NaN
      return x
    }
    if hx >= 0x42b17218 && !signb {
      // x >= 88.722839f
      // overflow
      x = x * x1p127
      return x
    }
    if signb {
      // underflow
      if hx >= 0x42cff1b5 {
        // x <= -103.972084f
        return 0.0
      }
    }
  }

  // argument reduction
  let mut k : Int = 0
  let mut hi : Float = 0.0
  let mut lo : Float = 0.0
  if hx > 0x3eb17218 {
    // if |x| > 0.5 ln2
    if hx > 0x3f851592 {
      // if |x| > 1.5 ln2
      let half : Float = if sign == 0 { 0.5 } else { -0.5 }
      k = (inv_ln2 * x + half).to_int()
    } else {
      k = 1 - sign - sign
    }
    let kf = Float::from_int(k)
    hi = x - kf * exp_ln2_hi // k*ln2hi is exact here
    lo = kf * exp_ln2_lo
    x = hi - lo
  } else if hx > 0x39000000 {
    // |x| > 2**-14
    k = 0
    hi = x
    lo = 0.0
  } else {
    // raise inexact
    return (1.0 : Float) + x
  }

  // x is now in primary range
  let xx = x * x
  let c = x - xx * (exp_p1 + xx * exp_p2)
  let y = (1.0 : Float) + (x * c / ((2.0 : Float) - c) - lo + hi)
  if k == 0 {
    y
  } else {
    scalbnf(y, k)
  }
}

///|
/// `scalbn` for f32 (libm's generic implementation).
fn scalbnf(x : Float, n : Int) -> Float {
  let mut x = x
  let mut n = n
  let exp_max = 127
  let exp_min = -126
  let sig_total_bits = 24
  let exp_bias = 127
  // 2 ^ Emax, maximum positive with null significand
  let f_exp_max = f32((exp_bias << 1).reinterpret_as_uint() << 23)
  // 2 ^ Emin, minimum positive normal with null significand
  let f_exp_min = f32(1U << 23)
  // 2 ^ sig_total_bits, moltiplier to normalize subnormals
  let f_pow_subnorm = f32(
    (sig_total_bits + exp_bias).reinterpret_as_uint() << 23,
  )
  if n > exp_max {
    x = x * f_exp_max
    n -= exp_max
    if n > exp_max {
      x = x * f_exp_max
      n -= exp_max
      if n > exp_max {
        n = exp_max
      }
    }
  } else if n < exp_min {
    // `mul` s.t. `!(x * mul).is_subnormal() ∀ x`
    let mul = f_exp_min * f_pow_subnorm
    let add = -exp_min - sig_total_bits
    x = x * mul
    n += add
    if n < exp_min {
      x = x * mul
      n += add
      if n < exp_min {
        n = exp_min
      }
    }
  }
  let scale = f32((exp_bias + n).reinterpret_as_uint() << 23)
  x * scale
}

// expm1f.rs (origin: FreeBSD /usr/src/lib/msun/src/s_expm1f.c)

///|
let expm1_ln2_hi : Float = f32(0x3f317180) // 6.9313812256e-01

///|
let expm1_ln2_lo : Float = f32(0x3717f7d1) // 9.0580006145e-06

///|
// Domain [-0.34568, 0.34568], range ~[-6.694e-10, 6.696e-10]:
// |6 / x * (1 + 2 * (1 / (exp(x) - 1) - 1 / x)) - q(x)| < 2**-30.04
// Scaled coefficients: Qn_here = 2**n * Qn_for_q (see s_expm1.c):
let expm1_q1 : Float = f32(0xbd088868) // -0x888868.0p-28

///|
let expm1_q2 : Float = f32(0x3acf3010) //  0xcf3010.0p-33

///|
/// Exponential, base *e*, of x-1 (f32)
fn expm1f(x : Float) -> Float {
  let mut x = x
  let x1p127 = f32(0x7f000000) // 0x1p127f === 2 ^ 127
  let mut hx = bits(x)
  let sign = hx >> 31 != 0
  hx = hx & 0x7fffffff

  // filter out huge and non-finite argument
  if hx >= 0x4195b844 {
    // if |x|>=27*ln2
    if hx > 0x7f800000 {
      // NaN
      return x
    }
    if sign {
      return -1.0
    }
    if hx > 0x42b17217 {
      // x > log(FLT_MAX)
      x = x * x1p127
      return x
    }
  }
  let mut k : Int = 0
  let mut hi : Float = 0.0
  let mut lo : Float = 0.0
  let mut c : Float = 0.0
  // argument reduction
  if hx > 0x3eb17218 {
    // if  |x| > 0.5 ln2
    if hx < 0x3F851592 {
      // and |x| < 1.5 ln2
      if !sign {
        hi = x - expm1_ln2_hi
        lo = expm1_ln2_lo
        k = 1
      } else {
        hi = x + expm1_ln2_hi
        lo = -expm1_ln2_lo
        k = -1
      }
    } else {
      let half : Float = if sign { -0.5 } else { 0.5 }
      k = (inv_ln2 * x + half).to_int()
      let t = Float::from_int(k)
      hi = x - t * expm1_ln2_hi // t*ln2_hi is exact here
      lo = t * expm1_ln2_lo
    }
    x = hi - lo
    c = hi - x - lo
  } else if hx < 0x33000000 {
    // when |x|<2**-25, return x
    return x
  } else {
    k = 0
  }

  // x is now in primary range
  let hfx = (0.5 : Float) * x
  let hxs = x * hfx
  let r1 = (1.0 : Float) + hxs * (expm1_q1 + hxs * expm1_q2)
  let t = (3.0 : Float) - r1 * hfx
  let mut e = hxs * ((r1 - t) / ((6.0 : Float) - x * t))
  if k == 0 {
    // c is 0
    return x - (x * e - hxs)
  }
  e = x * (e - c) - c
  e = e - hxs
  // exp(x) ~ 2^k (x_reduced - e + 1)
  if k == -1 {
    return (0.5 : Float) * (x - e) - (0.5 : Float)
  }
  if k == 1 {
    if x < -0.25 {
      return (-2.0 : Float) * (e - (x + (0.5 : Float)))
    }
    return (1.0 : Float) + (2.0 : Float) * (x - e)
  }
  let twopk = f32(((0x7f + k) << 23).reinterpret_as_uint()) // 2^k
  if k < 0 || k > 56 {
    // suffice to return exp(x)-1
    let mut y = x - e + (1.0 : Float)
    if k == 128 {
      y = y * (2.0 : Float) * x1p127
    } else {
      y = y * twopk
    }
    return y - (1.0 : Float)
  }
  let uf = f32(((0x7f - k) << 23).reinterpret_as_uint()) // 2^-k
  if k < 23 {
    (x - e + ((1.0 : Float) - uf)) * twopk
  } else {
    (x - (e + uf) + (1.0 : Float)) * twopk
  }
}

// tanhf.rs

///|
/// The hyperbolic tangent of `x` (f32).
fn tanhf(x : Float) -> Float {
  // x = |x|
  let mut ix = bits(x)
  let sign = ix >> 31 != 0
  ix = ix & 0x7fffffff
  let x = f32(ix)
  let w = ix
  let tt = if w > 0x3f0c9f54 {
    // |x| > log(3)/2 ~= 0.5493 or nan
    if w > 0x41200000 {
      // |x| > 10
      (1.0 : Float) + (0.0 : Float) / x
    } else {
      let t = expm1f((2.0 : Float) * x)
      (1.0 : Float) - (2.0 : Float) / (t + (2.0 : Float))
    }
  } else if w > 0x3e82c578 {
    // |x| > log(5/3)/2 ~= 0.2554
    let t = expm1f((2.0 : Float) * x)
    t / (t + (2.0 : Float))
  } else if w >= 0x00800000 {
    // |x| >= 0x1p-126
    let t = expm1f((-2.0 : Float) * x)
    -t / (t + (2.0 : Float))
  } else {
    // |x| is subnormal
    x
  }
  if sign {
    -tt
  } else {
    tt
  }
}
