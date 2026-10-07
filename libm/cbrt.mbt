// Port of the `libm` crate's `cbrt` (0.2.16, `src/math/cbrt.rs`): the
// correctly rounded cube root after CORE-MATH. It is the `cbrt` that Rust's
// `f64::cbrt` reaches on every target whose `compiler-builtins` defines the
// symbol (see `f64_native.mbt`), and what `libm::cbrt` is everywhere.
//
// Deviations from the Rust source: the tables that upstream declares inside
// the function (`ESCALE`, `C`, `rsc`, `off`, `wlist`) are top-level
// `ReadOnlyArray`s (static data, no allocation per call); `hf64!("0x1p-53")`
// is written `0x1.0p-53` (MoonBit's hexadecimal float literals need the
// point).
//
// Like every port of floating-point code here, it relies on the C compiler
// of the native backend rounding each product and sum on its own: Apple
// clang and compilers for x86_64 without FMA instructions do, gcc for
// aarch64 would have to be told (`-ffp-contract=off`). `cbrt_wbtest.mbt`
// fails where that does not hold.

// SPDX-License-Identifier: MIT
// origin: core-math/src/binary64/cbrt/cbrt.c
// Copyright (c) 2021-2022 Alexei Sibidanov.
// Ported to Rust in 2025 by Trevor Gross.

///|
/// `1`, `2^(1/3)`, `2^(2/3)`.
let cbrt_escale : ReadOnlyArray[Double] = [
  1.0, 0x1.428a2f98d728bp+0, 0x1.965fea53d6e3dp+0,
]

///|
/// the polynomial c0+c1*x+c2*x^2+c3*x^3 approximates x^(1/3) on [1,2]
/// with maximal error < 9.2e-5 (attained at x=2)
let cbrt_c : ReadOnlyArray[Double] = [
  0x1.1b0babccfef9cp-1, 0x1.2c9a3e94d1da5p-1, -0x1.4dc30b1a1ddbap-3, 0x1.7a8d3e4ec9b07p-6,
]

///|
let cbrt_rsc : ReadOnlyArray[Double] = [1.0, -1.0, 0.5, -0.5, 0.25, -0.25]

///|
let cbrt_off : ReadOnlyArray[Double] = [0x1.0p-53, 0.0, 0.0, 0.0]

///|
let cbrt_wlist : ReadOnlyArray[(Double, Double)] = [
  (0x1.3a9ccd7f022dbp+0, 0x1.1236160ba9b93p+0), // ~ 0x1.1236160ba9b930000000000001e7e8fap+0
  (0x1.7845d2faac6fep+0, 0x1.23115e657e49cp+0), // ~ 0x1.23115e657e49c0000000000001d7a799p+0
  (0x1.d1ef81cbbbe71p+0, 0x1.388fb44cdcf5ap+0), // ~ 0x1.388fb44cdcf5a0000000000002202c55p+0
  (0x1.0a2014f62987cp+1, 0x1.46bcbf47dc1e8p+0), // ~ 0x1.46bcbf47dc1e8000000000000303aa2dp+0
  (0x1.fe18a044a5501p+1, 0x1.95decfec9c904p+0), // ~ 0x1.95decfec9c9040000000000000159e8ep+0
  (0x1.a6bb8c803147bp+2, 0x1.e05335a6401dep+0), // ~ 0x1.e05335a6401de00000000000027ca017p+0
  (0x1.ac8538a031cbdp+2, 0x1.e281d87098de8p+0), // ~ 0x1.e281d87098de80000000000000ee9314p+0
]

///|
/// Compute the cube root of the argument.
pub fn cbrt(x : Double) -> Double {
  cbrt_round(x, Round::Nearest).val
}

///|
fn cbrt_round(x : Double, round : Round) -> FpResult {
  let u0 : Double = 0x1.5555555555555p-2
  let u1 : Double = 0x1.c71c71c71c71cp-3

  // rm=0 for rounding to nearest, and other values for directed roundings
  let hx : UInt64 = x.reinterpret_as_uint64()
  let mut mant : UInt64 = hx & F64_SIG_MASK
  let sign : UInt64 = hx >> 63

  let mut e : UInt = (hx >> F64_SIG_BITS).to_uint() & F64_EXP_SAT

  if ((e + 1) & F64_EXP_SAT) < 2 {
    cold_path()

    let ix : UInt64 = hx & F64_SIGN_MASK.lnot()

    // 0, inf, nan: we return x + x instead of simply x,
    // to that for x a signaling NaN, it correctly triggers
    // the invalid exception.
    if e == F64_EXP_SAT || ix == 0 {
      return FpResult::ok(x + x)
    }

    let nz : UInt = ix.clz().reinterpret_as_uint() - 11 // subnormal
    mant = mant << nz.reinterpret_as_int()
    mant = mant & F64_SIG_MASK
    e = e - (nz - 1)
  }

  e = e + 3072
  let cvt1 : UInt64 = mant | (0x3ffUL << 52)
  let mut cvt5 : UInt64 = cvt1

  let et : UInt = e / 3
  let it : UInt = e % 3

  // 2^(3k+it) <= x < 2^(3k+it+1), with 0 <= it <= 3
  cvt5 = cvt5 + (it.to_uint64() << F64_SIG_BITS)
  cvt5 = cvt5 | (sign << 63)
  let zz : Double = cvt5.reinterpret_as_double()

  // cbrt(x) = cbrt(zz)*2^(et-1365) where 1 <= zz < 8
  let mut isc : UInt64 = cbrt_escale[it.reinterpret_as_int()].reinterpret_as_uint64() // todo: index
  isc = isc | (sign << 63)
  let cvt2 : UInt64 = isc
  let z : Double = cvt1.reinterpret_as_double()

  // cbrt(zz) = cbrt(z)*isc, where isc encodes 1, 2^(1/3) or 2^(2/3),
  // and 1 <= z < 2
  let r : Double = 1.0 / z
  let rr : Double = r * cbrt_rsc[(it.reinterpret_as_int() << 1) | sign.to_int()]
  let z2 : Double = z * z
  let c0 : Double = cbrt_c[0] + z * cbrt_c[1]
  let c2 : Double = cbrt_c[2] + z * cbrt_c[3]
  let mut y : Double = c0 + z2 * c2
  let mut y2 : Double = y * y

  // y is an approximation of z^(1/3)
  let mut h : Double = y2 * (y * r) - 1.0

  // h determines the error between y and z^(1/3)
  y = y - h * y * (u0 - u1 * h)

  // The correction y -= (h*y)*(u0 - u1*h) corresponds to a cubic variant
  // of Newton's method, with the function f(y) = 1-z/y^3.
  y = y * cvt2.reinterpret_as_double()

  // Now y is an approximation of zz^(1/3),
  // and rr an approximation of 1/zz. We now perform another iteration of
  // Newton-Raphson, this time with a linear approximation only.
  y2 = y * y
  let mut y2l : Double = fma(y, y, -y2)

  // y2 + y2l = y^2 exactly
  let mut y3 : Double = y2 * y
  let mut y3l : Double = fma(y, y2, -y3) + y * y2l

  // y3 + y3l approximates y^3 with about 106 bits of accuracy
  h = (y3 - zz + y3l) * rr
  let mut dy : Double = h * (y * u0)

  // the approximation of zz^(1/3) is y - dy
  let mut y1 : Double = y - dy
  dy = y - y1 - dy

  // the approximation of zz^(1/3) is now y1 + dy, where |dy| < 1/2 ulp(y)
  // (for rounding to nearest)
  let mut ady : Double = dy.abs()

  // For directed roundings, ady0 is tiny when dy is tiny, or ady0 is near
  // from ulp(1);
  // for rounding to nearest, ady0 is tiny when dy is near from 1/2 ulp(1),
  // or from 3/2 ulp(1).
  let mut ady0 : Double = (ady - cbrt_off[round.to_int()]).abs()
  let mut ady1 : Double = (ady - (0x1.0p-52 + cbrt_off[round.to_int()])).abs()

  if ady0 < 0x1.0p-75 || ady1 < 0x1.0p-75 {
    cold_path()

    y2 = y1 * y1
    y2l = fma(y1, y1, -y2)
    y3 = y2 * y1
    y3l = fma(y1, y2, -y3) + y1 * y2l
    h = (y3 - zz + y3l) * rr
    dy = h * (y1 * u0)
    y = y1 - dy
    dy = y1 - y - dy
    y1 = y
    ady = dy.abs()
    ady0 = (ady - cbrt_off[round.to_int()]).abs()
    ady1 = (ady - (0x1.0p-52 + cbrt_off[round.to_int()])).abs()

    if ady0 < 0x1.0p-98 || ady1 < 0x1.0p-98 {
      cold_path()
      let azz : Double = zz.abs()

      // ~ 0x1.79d15d0e8d59b80000000000000ffc3dp+0
      if azz == 0x1.9b78223aa307cp+1 {
        y1 = copysign(0x1.79d15d0e8d59cp+0, zz)
      }

      // ~ 0x1.de87aa837820e80000000000001c0f08p+0
      if azz == 0x1.a202bfc89ddffp+2 {
        y1 = copysign(0x1.de87aa837820fp+0, zz)
      }

      if round != Round::Nearest {
        for entry in cbrt_wlist[:] {
          let (a, b) = entry
          if azz == a {
            let tmp = if round.to_int().to_uint64() + sign == 2 {
              0x1.0p-52
            } else {
              0.0
            }
            y1 = copysign(b + tmp, zz)
          }
        }
      }
    }
  }

  let mut cvt3 : UInt64 = y1.reinterpret_as_uint64()
  cvt3 = cvt3 + ((et - 342 - 1023).to_uint64() << 52)
  let m0 : UInt64 = cvt3 << 30
  let m1 = m0 >> 63

  if (m0 ^ m1) <= 1UL << 30 {
    cold_path()

    let mut cvt4 : UInt64 = y1.reinterpret_as_uint64()
    cvt4 = (cvt4 + (164UL << 15)) & 0xffffffffffff0000UL

    if (cvt4.reinterpret_as_double() - y1 - dy).abs() < 0x1.0p-60 ||
      zz.abs() == 1.0 {
      cvt3 = (cvt3 + (1UL << 15)) & 0xffffffffffff0000UL
    }
  }

  FpResult::ok(cvt3.reinterpret_as_double())
}
