// Ports of the `libm` 0.2.16 routines that `wasmi_core` uses without its
// `std` feature (`impl_wasm_float!` for `not(feature = "std")`), as they
// are compiled for aarch64 with neon:
//
// - `fabs`, `copysign`, `floor`, `ceil`, `trunc`, `round`: the generic
//   bit-manipulation algorithms (`libm/src/math/generic`);
// - `sqrt`, `fma`: the `fsqrt` / `fmadd` instructions (`arch/aarch64.rs`),
//   emulated with correctly rounded software algorithms (the generic `fma`
//   ports below) plus the Arm NaN rules of `arm_nan.mbt`.

///|
fn libm_fabsf(x : Float) -> Float {
  Float::reinterpret_from_uint(x.reinterpret_as_uint() & 0x7FFF_FFFF)
}

///|
fn libm_fabs(x : Double) -> Double {
  (x.reinterpret_as_uint64() & 0x7FFF_FFFF_FFFF_FFFF).reinterpret_as_double()
}

///|
fn libm_copysignf(x : Float, y : Float) -> Float {
  let ux = x.reinterpret_as_uint() & 0x7FFF_FFFF
  Float::reinterpret_from_uint(ux | (y.reinterpret_as_uint() & 0x8000_0000))
}

///|
fn libm_copysign(x : Double, y : Double) -> Double {
  let ux = x.reinterpret_as_uint64() & 0x7FFF_FFFF_FFFF_FFFF
  (ux | (y.reinterpret_as_uint64() & 0x8000_0000_0000_0000)).reinterpret_as_double()
}

///|
fn f32_exp_unbiased(ix : UInt) -> Int {
  ((ix >> 23) & 0xFF).reinterpret_as_int() - 127
}

///|
fn f64_exp_unbiased(ix : UInt64) -> Int {
  ((ix >> 52) & 0x7FF).to_int() - 1023
}

///|
fn libm_floorf(x : Float) -> Float {
  let mut ix = x.reinterpret_as_uint()
  let e = f32_exp_unbiased(ix)
  // If the represented value has no fractional part, no truncation is needed.
  if e >= 23 {
    return x
  }
  if e >= 0 {
    // |x| >= 1.0
    let m = 0x7F_FFFFU >> e
    if (ix & m) == 0 {
      // Portion to be masked is already zero; no adjustment needed.
      return x
    }
    if ix >> 31 != 0 {
      ix += m
    }
    ix = ix & m.lnot()
    Float::reinterpret_from_uint(ix)
  } else if ix >> 31 == 0 {
    // 0.0 <= x < 1.0; rounding down goes toward +0.0.
    0.0
  } else if ix << 1 != 0 {
    // -1.0 < x < 0.0; rounding down goes toward -1.0.
    -1.0
  } else {
    // -0.0 remains unchanged
    x
  }
}

///|
fn libm_floor(x : Double) -> Double {
  let mut ix = x.reinterpret_as_uint64()
  let e = f64_exp_unbiased(ix)
  if e >= 52 {
    return x
  }
  if e >= 0 {
    let m = 0xF_FFFF_FFFF_FFFFUL >> e
    if (ix & m) == 0 {
      return x
    }
    if ix >> 63 != 0 {
      ix += m
    }
    ix = ix & m.lnot()
    ix.reinterpret_as_double()
  } else if ix >> 63 == 0 {
    0.0
  } else if ix << 1 != 0 {
    -1.0
  } else {
    x
  }
}

///|
fn libm_ceilf(x : Float) -> Float {
  let mut ix = x.reinterpret_as_uint()
  let e = f32_exp_unbiased(ix)
  if e >= 23 {
    return x
  }
  if e >= 0 {
    // |x| >= 1.0
    let m = 0x7F_FFFFU >> e
    if (ix & m) == 0 {
      return x
    }
    if ix >> 31 == 0 {
      ix += m
    }
    ix = ix & m.lnot()
    Float::reinterpret_from_uint(ix)
  } else if ix >> 31 != 0 {
    // -1.0 < x <= -0.0; rounding up goes toward -0.0.
    Float::reinterpret_from_uint(0x8000_0000)
  } else if ix << 1 != 0 {
    // 0.0 < x < 1.0; rounding up goes toward +1.0.
    1.0
  } else {
    // +0.0 remains unchanged
    x
  }
}

///|
fn libm_ceil(x : Double) -> Double {
  let mut ix = x.reinterpret_as_uint64()
  let e = f64_exp_unbiased(ix)
  if e >= 52 {
    return x
  }
  if e >= 0 {
    let m = 0xF_FFFF_FFFF_FFFFUL >> e
    if (ix & m) == 0 {
      return x
    }
    if ix >> 63 == 0 {
      ix += m
    }
    ix = ix & m.lnot()
    ix.reinterpret_as_double()
  } else if ix >> 63 != 0 {
    0x8000_0000_0000_0000UL.reinterpret_as_double()
  } else if ix << 1 != 0 {
    1.0
  } else {
    x
  }
}

///|
fn libm_truncf(x : Float) -> Float {
  let xi = x.reinterpret_as_uint()
  let e = f32_exp_unbiased(xi)
  // C1: The represented value has no fractional part, so no truncation is needed
  if e >= 23 {
    return x
  }
  let mask = if e < 0 {
    // C2: If the exponent is negative, the result will be zero so we mask out
    // everything except the sign.
    0x8000_0000U
  } else {
    // C3: Otherwise, we mask out the last `e` bits of the significand.
    (0x7F_FFFFU >> e).lnot()
  }
  // C4: If the to-be-masked-out portion is already zero, we have an exact result
  if (xi & mask.lnot()) == 0 {
    return x
  }
  // C5: Otherwise the result is inexact and we will truncate.
  Float::reinterpret_from_uint(xi & mask)
}

///|
fn libm_trunc(x : Double) -> Double {
  let xi = x.reinterpret_as_uint64()
  let e = f64_exp_unbiased(xi)
  if e >= 52 {
    return x
  }
  let mask = if e < 0 {
    0x8000_0000_0000_0000UL
  } else {
    (0xF_FFFF_FFFF_FFFFUL >> e).lnot()
  }
  if (xi & mask.lnot()) == 0 {
    return x
  }
  (xi & mask).reinterpret_as_double()
}

///|
fn libm_roundf(x : Float) -> Float {
  // `f0p5 - f0p25 * F::EPSILON`
  let c = Float::reinterpret_from_uint(0x3EFF_FFFF)
  libm_truncf(f32_hw_add(x, libm_copysignf(c, x)))
}

///|
fn libm_round(x : Double) -> Double {
  // `f0p5 - f0p25 * F::EPSILON`
  let c = 0x3FDF_FFFF_FFFF_FFFFUL.reinterpret_as_double()
  libm_trunc(f64_hw_add(x, libm_copysign(c, x)))
}

///|
/// `x % 2.0` for an integral `x` (exact, like `fmod`; the sign of a zero
/// result is irrelevant to the callers).
fn f32_rem2_integral(x : Float) -> Float {
  x - 2.0 * libm_truncf(x * 0.5)
}

///|
/// `x % 2.0` for an integral `x` (exact, like `fmod`; the sign of a zero
/// result is irrelevant to the callers).
fn f64_rem2_integral(x : Double) -> Double {
  x - 2.0 * libm_trunc(x * 0.5)
}

///|
/// `WasmFloatExt::nearest` (`not(feature = "std")`).
fn libm_nearestf(x : Float) -> Float {
  let round = libm_roundf(x)
  if libm_fabsf(x - libm_truncf(x)) != 0.5 {
    return round
  }
  let rem = f32_rem2_integral(round)
  if rem == 1.0 {
    libm_floorf(x)
  } else if rem == -1.0 {
    libm_ceilf(x)
  } else {
    round
  }
}

///|
/// `WasmFloatExt::nearest` (`not(feature = "std")`).
fn libm_nearest(x : Double) -> Double {
  let round = libm_round(x)
  if libm_fabs(x - libm_trunc(x)) != 0.5 {
    return round
  }
  let rem = f64_rem2_integral(round)
  if rem == 1.0 {
    libm_floor(x)
  } else if rem == -1.0 {
    libm_ceil(x)
  } else {
    round
  }
}

///|
/// `fsqrt`
fn libm_sqrtf(x : Float) -> Float {
  if x != x {
    return f32_quiet(x)
  }
  let r = x.sqrt()
  if r != r {
    Float::reinterpret_from_uint(f32_default_nan_bits)
  } else {
    r
  }
}

///|
/// `fsqrt`
fn libm_sqrt(x : Double) -> Double {
  if x != x {
    return f64_quiet(x)
  }
  let r = x.sqrt()
  if r != r {
    f64_default_nan_bits.reinterpret_as_double()
  } else {
    r
  }
}

///|
/// `fmadd`: `x * y + z` with a single rounding.
fn libm_fmaf(x : Float, y : Float, z : Float) -> Float {
  let r = fma_wide_round(x, y, z)
  if r != r {
    f32_nan_mul_add(x, y, z)
  } else {
    r
  }
}

///|
/// `fmadd`: `x * y + z` with a single rounding.
fn libm_fma(x : Double, y : Double, z : Double) -> Double {
  let r = fma_round(x, y, z)
  if r != r {
    f64_nan_mul_add(x, y, z)
  } else {
    r
  }
}

///|
/// `libm::generic::fma_wide_round` for `f32` (via `f64`), round to nearest.
fn fma_wide_round(x : Float, y : Float, z : Float) -> Float {
  let xy = x.to_double() * y.to_double()
  let result = xy + z.to_double()
  let mut ui = result.reinterpret_as_uint64()
  let re = (ui >> 52) & 0x7FF
  let zb = z.to_double()
  // prec_diff = 52 - 23
  let excess_prec = ui & ((1UL << 29) - 1)
  let halfway = 1UL << 28
  // Common case: the larger precision is fine if...
  if excess_prec != halfway ||
    // Or the result is NaN
    re == 0x7FF ||
    // Or the result is exact
    (result - xy == zb && result - zb == xy) {
    return Float::from_double(result)
  }
  let neg = ui >> 63 != 0
  let err = if neg == (zb > xy) { xy - result + zb } else { zb - result + xy }
  if neg == (err < 0.0) {
    ui += 1
  } else {
    ui -= 1
  }
  Float::from_double(ui.reinterpret_as_double())
}

///|
/// Representation of `f64` that has handled subnormals (`libm::generic::fma::Norm`).
priv struct Norm {
  /// Normalized significand with one guard bit, unsigned.
  m : UInt64
  /// Exponent of the mantissa such that `m * 2^e = x`.
  e : Int
  neg : Bool
}

///|
/// `EXP_UNBIAS = EXP_BIAS + SIG_BITS + 1`
let norm_exp_unbias : Int = 1023 + 52 + 1

///|
/// `ZERO_INF_NAN = EXP_SAT - EXP_UNBIAS`
let norm_zero_inf_nan : Int = 2047 - norm_exp_unbias

///|
fn Norm::from_float(x : Double) -> Norm {
  let mut ix = x.reinterpret_as_uint64()
  let mut e = ((ix >> 52) & 0x7FF).to_int()
  let neg = ix >> 63 != 0
  if e == 0 {
    // Normalize subnormals by multiplication
    let scale_i = 63
    let scale_f = ((scale_i + 1023).to_uint64() << 52).reinterpret_as_double()
    let scaled = x * scale_f
    ix = scaled.reinterpret_as_uint64()
    e = ((ix >> 52) & 0x7FF).to_int()
    e = if e == 0 {
      // If the exponent is still zero, the input was zero. Artifically set this
      // value such that the final `e` will exceed `ZERO_INF_NAN`.
      1 << 11
    } else {
      // Otherwise, account for the scaling we just did.
      e - scale_i
    }
  }
  e -= norm_exp_unbias
  // Absolute value, set the implicit bit, and shift to create a guard bit
  ix = ix & 0xF_FFFF_FFFF_FFFFUL
  ix = ix | 0x10_0000_0000_0000UL
  ix = ix << 1
  { m: ix, e, neg, }
}

///|
/// True if the value was zero, infinity, or NaN.
fn Norm::is_zero_nan_inf(self : Norm) -> Bool {
  self.e >= norm_zero_inf_nan
}

///|
fn Norm::is_zero(self : Norm) -> Bool {
  self.e > norm_zero_inf_nan
}

///|
/// Full `64 x 64 -> 128` bit product as `(lo, hi)`.
fn widen_mul(a : UInt64, b : UInt64) -> (UInt64, UInt64) {
  let mask = 0xFFFF_FFFFUL
  let a0 = a & mask
  let a1 = a >> 32
  let b0 = b & mask
  let b1 = b >> 32
  let p00 = a0 * b0
  let p01 = a0 * b1
  let p10 = a1 * b0
  let p11 = a1 * b1
  let mid = (p00 >> 32) + (p01 & mask) + (p10 & mask)
  let lo = (p00 & mask) | (mid << 32)
  let hi = p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32)
  (lo, hi)
}

///|
fn u64_from_bool(b : Bool) -> UInt64 {
  if b {
    1
  } else {
    0
  }
}

///|
/// `libm::generic::fma_round` for `f64`, round to nearest.
fn fma_round(x : Double, y : Double, z : Double) -> Double {
  // Normalize such that the top of the mantissa is zero and we have a guard bit.
  let nx = Norm::from_float(x)
  let ny = Norm::from_float(y)
  let nz = Norm::from_float(z)
  if nx.is_zero_nan_inf() || ny.is_zero_nan_inf() {
    // Value will overflow, defer to non-fused operations.
    return x * y + z
  }
  if nz.is_zero_nan_inf() {
    if nz.is_zero() {
      // Empty add component means we only need to multiply.
      return x * y
    }
    // `z` is NaN or infinity, which sets the result.
    return z
  }
  // multiply: r = x * y
  let mut zhi = 0UL
  let mut zlo = 0UL
  let (rlo0, rhi0) = widen_mul(nx.m, ny.m)
  let mut rlo = rlo0
  let mut rhi = rhi0
  // Exponent result of multiplication
  let mut e = nx.e + ny.e
  // Needed shift to align `z` to the multiplication result
  let mut d = nz.e - e
  let sbits = 64
  // Scale `z`. Shift `z <<= kz`, `r >>= kr`, so `kz+kr == d`, set `e = e+kr` (== ez-kz)
  if d > 0 {
    // The magnitude of `z` is larger than `x * y`
    if d < sbits {
      zlo = nz.m << d
      zhi = nz.m >> (sbits - d)
    } else {
      zlo = 0
      zhi = nz.m
      d -= sbits
      // `z`'s exponent is large enough that it now needs to be taken into account.
      e = nz.e - sbits
      if d == 0 {
        // Exactly `sbits`, nothing to do
      } else if d < sbits {
        // Remaining shift fits within `sbits`. Leave `z` in place, shift `x * y`
        rlo = (rhi << (sbits - d)) | (rlo >> d)
        // Set the sticky bit
        rlo = rlo | u64_from_bool(rlo << (sbits - d) != 0)
        rhi = rhi >> d
      } else {
        // `z`'s magnitude is enough that `x * y` is irrelevant. It was nonzero,
        // so set the sticky bit.
        rlo = 1
        rhi = 0
      }
    }
  } else {
    // `z`'s magnitude once shifted fits entirely within `zlo`
    zhi = 0
    d = -d
    if d == 0 {
      // No shift needed
      zlo = nz.m
    } else if d < sbits {
      // Shift s.t. `nz.m` fits into `zlo`
      let sticky = u64_from_bool(nz.m << (sbits - d) != 0)
      zlo = (nz.m >> d) | sticky
    } else {
      // Would be entirely shifted out, only set the sticky bit
      zlo = 1
    }
  }

  // addition
  let mut neg = nx.neg != ny.neg
  let samesign = !neg != nz.neg
  let mut rhi_nonzero = true
  if samesign {
    // r += z
    rlo = rlo + zlo
    rhi += zhi + u64_from_bool(rlo < zlo)
  } else {
    // r -= z
    let borrow = rlo < zlo
    rlo = rlo - zlo
    rhi = rhi - (zhi + u64_from_bool(borrow))
    if rhi >> 63 != 0 {
      rlo = 0UL - rlo
      rhi = 0UL - rhi - u64_from_bool(rlo != 0)
      neg = !neg
    }
    rhi_nonzero = rhi != 0
  }

  // Construct result

  // Shift result into `rhi`, left-aligned. Last bit is sticky
  if rhi_nonzero {
    // `d` > 0, need to shift both `rhi` and `rlo` into result
    e += sbits
    d = rhi.clz() - 1
    rhi = (rhi << d) | (rlo >> (sbits - d))
    // Update sticky
    rhi = rhi | u64_from_bool(rlo << d != 0)
  } else if rlo != 0 {
    // `rhi` is zero, `rlo` is the entire result and needs to be shifted
    d = rlo.clz() - 1
    if d < 0 {
      // Shift and set sticky
      rhi = (rlo >> 1) | (rlo & 1)
    } else {
      rhi = rlo << d
    }
  } else {
    // exact +/- 0.0
    return x * y + z
  }
  e -= d

  // Use int->float conversion to populate the significand.
  let mut i = rhi.reinterpret_as_int64()
  if neg {
    i = -i
  }
  let mut r = i.to_double()

  // Account for subnormal and rounding

  // Unbiased exponent for the maximum value of `r`
  let max_pow = 64 - 1 + 1023
  if e < -(max_pow - 2) {
    // Result is subnormal before rounding
    if e == -(max_pow - 1) {
      let mut c = (max_pow.to_uint64() << 52).reinterpret_as_double()
      if neg {
        c = -c
      }
      if r == c {
        // Min normal after rounding,
        return libm_copysign(0x0010_0000_0000_0000UL.reinterpret_as_double(), r)
      }
      if rhi << (52 + 1) != 0 {
        // Account for truncated bits. One bit will be lost in the `scalbn`
        // call, add another top bit to avoid double rounding if inexact.
        let iu = (rhi >> 1) | (rhi & 1) | (1UL << 62)
        i = iu.reinterpret_as_int64()
        if neg {
          i = -i
        }
        r = i.to_double()
        // Remove the top bit
        r = 2.0 * r - c
      }
    } else {
      // Only round once when scaled
      d = 11 - 1
      let sticky = u64_from_bool(rhi << (64 - d) != 0)
      i = (((rhi >> d) | sticky) << d).reinterpret_as_int64()
      if neg {
        i = -i
      }
      r = i.to_double()
    }
  }
  // Use our exponent to scale the final value.
  libm_scalbn(r, e)
}

///|
/// `libm::generic::scalbn` for `f64`.
fn libm_scalbn(x : Double, n : Int) -> Double {
  let mut x = x
  let mut n = n
  let exp_max = 1023
  let exp_min = -1022
  // 2 ^ Emax
  let f_exp_max = 0x7FE0_0000_0000_0000UL.reinterpret_as_double()
  if n > exp_max {
    x *= f_exp_max
    n -= exp_max
    if n > exp_max {
      x *= f_exp_max
      n -= exp_max
      if n > exp_max {
        n = exp_max
      }
    }
  } else if n < exp_min {
    // `mul = f_exp_min * f_pow_subnorm` = 2^-1022 * 2^53
    let mul = ((1 + 53).to_uint64() << 52).reinterpret_as_double()
    let add = -exp_min - 53
    x *= mul
    n += add
    if n < exp_min {
      x *= mul
      n += add
      if n < exp_min {
        n = exp_min
      }
    }
  }
  let scale = ((1023 + n).to_uint64() << 52).reinterpret_as_double()
  x * scale
}
