// Sine and cosine of the `libm` crate (0.2, a port of musl), which upstream
// uses for `Angle::sin`/`cos` (typst-library/src/layout/angle.rs). On native
// targets, `@math.sin`/`cos` call the C library, and the fdlibm port of
// `moonbitlang/core` differs from musl in the argument reduction and the
// cosine kernel; both deviate in the last place for some arguments, which is
// visible e.g. in hash-derived SVG IDs.
//
// The reduction of huge arguments (`rem_pio2_large`) is the fdlibm
// `__kernel_rem_pio2` copied from `moonbitlang/core/math` (Apache-2.0), which
// musl's is derived from.

///|
const LIBM_TO_INT : Double = 6755399441055744.0 // 1.5 / EPSILON

///|
const LIBM_INV_PIO2 : Double = 6.36619772367581382433e-01 // 0x3FE45F30, 0x6DC9C883

///|
const LIBM_PIO2_1 : Double = 1.57079632673412561417e+00 // 0x3FF921FB, 0x54400000

///|
const LIBM_PIO2_1T : Double = 6.07710050650619224932e-11 // 0x3DD0B461, 0x1A626331

///|
const LIBM_PIO2_2 : Double = 6.07710050630396597660e-11 // 0x3DD0B461, 0x1A600000

///|
const LIBM_PIO2_2T : Double = 2.02226624879595063154e-21 // 0x3BA3198A, 0x2E037073

///|
const LIBM_PIO2_3 : Double = 2.02226624871116645580e-21 // 0x3BA3198A, 0x2E000000

///|
const LIBM_PIO2_3T : Double = 8.47842766036889956997e-32 // 0x397B839A, 0x252049C1

///|
/// The high word of a double's bits (sign cleared by callers as needed).
fn libm_high_word(x : Double) -> UInt {
  (x.reinterpret_as_uint64() >> 32).to_uint()
}

///|
/// `rem_pio2::medium`.
fn libm_rem_pio2_medium(x : Double, ix : UInt) -> (Int, Double, Double) {
  // rint(x/(pi/2)), Assume round-to-nearest.
  let tmp = x * LIBM_INV_PIO2 + LIBM_TO_INT
  let f_n = tmp - LIBM_TO_INT
  let n = f_n.to_int()
  let mut r = x - f_n * LIBM_PIO2_1
  let mut w = f_n * LIBM_PIO2_1T // 1st round, good to 85 bits
  let mut y0 = r - w
  let ey = (y0.reinterpret_as_uint64() >> 52).to_int() & 0x7ff
  let ex = (ix >> 20).reinterpret_as_int()
  if ex - ey > 16 {
    // 2nd round, good to 118 bits
    let t = r
    w = f_n * LIBM_PIO2_2
    r = t - w
    w = f_n * LIBM_PIO2_2T - (t - r - w)
    y0 = r - w
    let ey = (y0.reinterpret_as_uint64() >> 52).to_int() & 0x7ff
    if ex - ey > 49 {
      // 3rd round, good to 151 bits, covers all cases
      let t = r
      w = f_n * LIBM_PIO2_3
      r = t - w
      w = f_n * LIBM_PIO2_3T - (t - r - w)
      y0 = r - w
    }
  }
  let y1 = r - y0 - w
  (n, y0, y1)
}

///|
/// Return the remainder of x rem pi/2 in y0+y1 (`libm::rem_pio2`).
fn libm_rem_pio2(x : Double) -> (Int, Double, Double) {
  let sign = (x.reinterpret_as_uint64() >> 63).to_int()
  let ix = libm_high_word(x) & 0x7fffffff
  let small = (k : Double) => {
    if sign == 0 {
      let z = x - k * LIBM_PIO2_1
      let y0 = z - k * LIBM_PIO2_1T
      let y1 = z - y0 - k * LIBM_PIO2_1T
      (k.to_int(), y0, y1)
    } else {
      let z = x + k * LIBM_PIO2_1
      let y0 = z + k * LIBM_PIO2_1T
      let y1 = z - y0 + k * LIBM_PIO2_1T
      (-k.to_int(), y0, y1)
    }
  }
  if ix <= 0x400f6a7a {
    // |x| ~<= 5pi/4
    if (ix & 0xfffff) == 0x921fb {
      // |x| ~= pi/2 or 2pi/2
      return libm_rem_pio2_medium(x, ix) // cancellation -- use medium case
    }
    if ix <= 0x4002d97c {
      // |x| ~<= 3pi/4
      return small(1.0)
    } else {
      return small(2.0)
    }
  }
  if ix <= 0x401c463b {
    // |x| ~<= 9pi/4
    if ix <= 0x4015fdbc {
      // |x| ~<= 7pi/4
      if ix == 0x4012d97c {
        // |x| ~= 3pi/2
        return libm_rem_pio2_medium(x, ix)
      }
      return small(3.0)
    } else {
      if ix == 0x401921fb {
        // |x| ~= 4pi/2
        return libm_rem_pio2_medium(x, ix)
      }
      return small(4.0)
    }
  }
  if ix < 0x413921fb {
    // |x| ~< 2^20*(pi/2), medium size
    return libm_rem_pio2_medium(x, ix)
  }
  // all other (large) arguments
  if ix >= 0x7ff00000 {
    // x is inf or NaN
    let y0 = x - x
    return (0, y0, y0)
  }
  // set z = @math.scalbn(|x|,-ilogb(x)+23)
  let mut ui = x.reinterpret_as_uint64()
  ui = ui & (1UL.lnot() >> 12)
  ui = ui | ((0x3ffUL + 23) << 52)
  let mut z = ui.reinterpret_as_double()
  let tx = [0.0, 0.0, 0.0]
  for i in 0..<2 {
    tx[i] = z.to_int().to_double()
    z = (z - tx[i]) * 16777216.0
  }
  tx[2] = z
  // skip zero terms, first term is non-zero
  let mut i = 2
  while i != 0 && tx[i] == 0.0 {
    i -= 1
  }
  let ty = [0.0, 0.0, 0.0]
  let n = libm_kernel_rem_pio2(
    tx,
    ty,
    (ix.reinterpret_as_int() >> 20) - (0x3ff + 23),
    i + 1,
    1,
  )
  if sign != 0 {
    (-n, -ty[0], -ty[1])
  } else {
    (n, ty[0], ty[1])
  }
}

///|
/// `libm::k_sin`.
fn libm_k_sin(x : Double, y : Double, iy : Int) -> Double {
  let s1 = -1.66666666666666324348e-01 // 0xBFC55555, 0x55555549
  let s2 = 8.33333333332248946124e-03 // 0x3F811111, 0x1110F8A6
  let s3 = -1.98412698298579493134e-04 // 0xBF2A01A0, 0x19C161D5
  let s4 = 2.75573137070700676789e-06 // 0x3EC71DE3, 0x57B1FE7D
  let s5 = -2.50507602534068634195e-08 // 0xBE5AE5E6, 0x8A2B9CEB
  let s6 = 1.58969099521155010221e-10 // 0x3DE5D93A, 0x5ACFD57C
  let z = x * x
  let w = z * z
  let r = s2 + z * (s3 + z * s4) + z * w * (s5 + z * s6)
  let v = z * x
  if iy == 0 {
    x + v * (s1 + z * r)
  } else {
    x - (z * (0.5 * y - v * r) - y - v * s1)
  }
}

///|
/// `libm::k_cos`.
fn libm_k_cos(x : Double, y : Double) -> Double {
  let c1 = 4.16666666666666019037e-02 // 0x3FA55555, 0x5555554C
  let c2 = -1.38888888888741095749e-03 // 0xBF56C16C, 0x16C15177
  let c3 = 2.48015872894767294178e-05 // 0x3EFA01A0, 0x19CB1590
  let c4 = -2.75573143513906633035e-07 // 0xBE927E4F, 0x809C52AD
  let c5 = 2.08757232129817482790e-09 // 0x3E21EE9E, 0xBDB4B1C4
  let c6 = -1.13596475577881948265e-11 // 0xBDA8FAE9, 0xBE8838D4
  let z = x * x
  let w = z * z
  let r = z * (c1 + z * (c2 + z * c3)) + w * w * (c4 + z * (c5 + z * c6))
  let hz = 0.5 * z
  let w = 1.0 - hz
  w + (1.0 - w - hz + (z * r - x * y))
}

///|
/// `libm::sin`.
fn libm_sin(x : Double) -> Double {
  let ix = libm_high_word(x) & 0x7fffffff
  // |x| ~< pi/4
  if ix <= 0x3fe921fb {
    if ix < 0x3e500000 {
      // |x| < 2**-26
      return x
    }
    return libm_k_sin(x, 0.0, 0)
  }
  // sin(Inf or NaN) is NaN
  if ix >= 0x7ff00000 {
    return x - x
  }
  // argument reduction needed
  let (n, y0, y1) = libm_rem_pio2(x)
  match n & 3 {
    0 => libm_k_sin(y0, y1, 1)
    1 => libm_k_cos(y0, y1)
    2 => -libm_k_sin(y0, y1, 1)
    _ => -libm_k_cos(y0, y1)
  }
}

///|
/// `libm::cos`.
fn libm_cos(x : Double) -> Double {
  let ix = libm_high_word(x) & 0x7fffffff
  // |x| ~< pi/4
  if ix <= 0x3fe921fb {
    if ix < 0x3e46a09e {
      // if x < 2**-27 * sqrt(2)
      if x.to_int() == 0 {
        return 1.0
      }
    }
    return libm_k_cos(x, 0.0)
  }
  // cos(Inf or NaN) is NaN
  if ix >= 0x7ff00000 {
    return x - x
  }
  // argument reduction needed
  let (n, y0, y1) = libm_rem_pio2(x)
  match n & 3 {
    0 => libm_k_cos(y0, y1)
    1 => -libm_k_sin(y0, y1, 1)
    2 => -libm_k_cos(y0, y1)
    _ => libm_k_sin(y0, y1, 1)
  }
}

///|
let libm_two_over_pi : ReadOnlyArray[Int] = [
  0xA2F983, 0x6E4E44, 0x1529FC, 0x2757D1, 0xF534DD, 0xC0DB62, 0x95993C, 0x439041,
  0xFE5163, 0xABDEBB, 0xC561B7, 0x246E3A, 0x424DD2, 0xE00649, 0x2EEA09, 0xD1921C,
  0xFE1DEB, 0x1CB129, 0xA73EE8, 0x8235F5, 0x2EBB44, 0x84E99C, 0x7026B4, 0x5F7E41,
  0x3991D6, 0x398353, 0x39F49C, 0x845F8B, 0xBDF928, 0x3B1FF8, 0x97FFDE, 0x05980F,
  0xEF2F11, 0x8B5A0A, 0x6D1F6D, 0x367ECF, 0x27CB09, 0xB74F46, 0x3F669E, 0x5FEA2D,
  0x7527BA, 0xC7EBE5, 0xF17B3D, 0x0739F7, 0x8A5292, 0xEA6BFB, 0x5FB11F, 0x8D5D08,
  0x560330, 0x46FC7B, 0x6BABF0, 0xCFBC20, 0x9AF436, 0x1DA9E3, 0x91615E, 0xE61B08,
  0x659985, 0x5F14A0, 0x68408D, 0xFFD880, 0x4D7327, 0x310606, 0x1556CA, 0x73A8C9,
  0x60E27B, 0xC08C6B,
]

///|
let libm_pi_over_2 : ReadOnlyArray[Double] = [
  1.57079625129699707031e+00, // 0x3FF921FB, 0x40000000 */
   7.54978941586159635335e-08, // 0x3E74442D, 0x00000000 */
   5.39030252995776476554e-15, // 0x3CF84698, 0x80000000 */
   3.28200341580791294123e-22, // 0x3B78CC51, 0x60000000 */
   1.27065575308067607349e-29, // 0x39F01B83, 0x80000000 */
   1.22933308981111328932e-36, // 0x387A2520, 0x40000000 */
   2.73370053816464559624e-44, // 0x36E38222, 0x80000000 */
   2.16741683877804819444e-51, // 0x3569F31D, 0x00000000 */
]

///|
fn libm_kernel_rem_pio2(
  x : Array[Double],
  y : Array[Double],
  e0 : Int,
  nx : Int,
  prec : Int,
) -> Int {
  let init_jk : ReadOnlyArray[Int] = [2, 3, 4, 6]
  let two24 : Double = 16777216.0 // 0x41700000, 0x00000000
  let twon24 : Double = 5.96046447753906250000e-08 // 0x3E700000, 0x00000000

  // Declare variables at the beginning, as in the original C code
  let mut jz : Int = 0
  let mut jx : Int = 0
  let mut jv : Int = 0
  let mut jp : Int = 0
  let mut jk : Int = 0
  let mut carry : Int = 0
  let mut n : Int = 0
  let iq : Array[Int] = Array::make(20, 0)
  let mut i : Int = 0
  let mut j : Int = 0
  let mut k : Int = 0
  let mut m : Int = 0
  let mut q0 : Int = 0
  let mut ih : Int = 0
  let mut z : Double = 0
  let mut fw : Double = 0
  let f : Array[Double] = Array::make(20, 0.0)
  let fq : Array[Double] = Array::make(20, 0.0)
  let q : Array[Double] = Array::make(20, 0.0)

  // initialize jk
  jk = init_jk[prec]
  jp = jk

  // determine jx, jv, q0, note that 3 > q0
  jx = nx - 1
  jv = (e0 - 3) / 24
  if jv < 0 {
    jv = 0
  }
  q0 = e0 - 24 * (jv + 1)

  // set up f[0] to f[jx+jk] where f[jx+jk] = ipio2[jv+jk]
  j = jv - jx
  m = jx + jk
  i = 0
  while i <= m {
    f[i] = if j < 0 { 0.0 } else { libm_two_over_pi[j].to_double() }
    i += 1
    j += 1
  }

  // compute q[0], q[1], ... q[jk]
  i = 0
  while i <= jk {
    j = 0
    fw = 0.0
    while j <= jx {
      fw += x[j] * f[jx + i - j]
      j += 1
    }
    q[i] = fw
    i += 1
  }
  jz = jk

  // Use a loop to replace the `goto` logic
  let mut recompute = true
  while recompute {
    recompute = false

    // distill q[] into iq[] reversingly
    i = 0
    j = jz
    z = q[jz]
    while j > 0 {
      fw = (twon24 * z).floor()
      iq[i] = (z - two24 * fw).to_int()
      z = q[j - 1] + fw
      i += 1
      j -= 1
    }

    // compute n
    z = @math.scalbn(z, q0) // actual value of z
    z -= 8.0 * (z * 0.125).floor() // trim off integer >= 8
    n = z.to_int()
    z -= n.to_double()
    ih = 0
    if q0 > 0 {
      // need iq[jz-1] to determine n
      i = iq[jz - 1] >> (24 - q0)
      n += i
      iq[jz - 1] -= i << (24 - q0)
      ih = iq[jz - 1] >> (23 - q0)
    } else if q0 == 0 {
      ih = iq[jz - 1] >> 23
    } else if z >= 0.5 {
      ih = 2
    }
    if ih > 0 {
      // q > 0.5
      n += 1
      carry = 0
      i = 0
      while i < jz {
        j = iq[i]
        if carry == 0 {
          if j != 0 {
            carry = 1
            iq[i] = 0x1000000 - j
          }
        } else {
          iq[i] = 0xffffff - j
        }
        i += 1
      }
      if q0 > 0 {
        // rare case: chance is 1 in 12
        match q0 {
          1 => iq[jz - 1] = iq[jz - 1] & 0x7fffff
          2 => iq[jz - 1] = iq[jz - 1] & 0x3fffff
          _ => ()
        }
      }
      if ih == 2 {
        z = 1.0 - z
        if carry != 0 {
          z -= @math.scalbn(1.0, q0)
        }
      }
    }

    // check if recomputation is needed
    if z == 0.0 {
      j = 0
      i = jz - 1
      while i >= jk {
        j = j | iq[i]
        i -= 1
      }
      if j == 0 {
        // need recomputation
        k = 1
        while iq[jk - k] == 0 {
          k += 1
        }
        i = jz + 1
        while i <= jz + k {
          f[jx + i] = libm_two_over_pi[jv + i].to_double()
          j = 0
          fw = 0.0
          while j <= jx {
            fw += x[j] * f[jx + i - j]
            j += 1
          }
          q[i] = fw
          i += 1
        }
        jz += k
        recompute = true // Continue to recompute
        continue
      }
    } // Skip the rest of the loop and recompute

    // chop off zero terms
    if z == 0.0 {
      jz -= 1
      q0 -= 24
      while iq[jz] == 0 {
        jz -= 1
        q0 -= 24
      }
    } else {
      // break z into 24-bit if necessary
      z = @math.scalbn(z, -q0)
      if z >= two24 {
        fw = (twon24 * z).floor()
        iq[jz] = (z - two24 * fw).to_int()
        jz += 1
        q0 += 24
        iq[jz] = fw.to_int()
      } else {
        iq[jz] = z.to_int()
      }
    }

    // convert integer "bit" chunk to floating-point value
    fw = @math.scalbn(1.0, q0)
    i = jz
    while i >= 0 {
      q[i] = fw * iq[i].to_double()
      fw *= twon24
      i -= 1
    }

    // compute PIo2[0,...,jp] * q[jz,...,0]
    i = jz
    while i >= 0 {
      fw = 0.0
      k = 0
      while k <= jp && k <= jz - i {
        fw += libm_pi_over_2[k] * q[i + k]
        k += 1
      }
      fq[jz - i] = fw
      i -= 1
    }

    // compress fq[] into y[]
    match prec {
      0 => {
        fw = 0.0
        i = jz
        while i >= 0 {
          fw += fq[i]
          i -= 1
        }
        y[0] = if ih == 0 { fw } else { -fw }
      }
      1 | 2 => {
        fw = 0.0
        i = jz
        while i >= 0 {
          fw += fq[i]
          i -= 1
        }
        y[0] = if ih == 0 { fw } else { -fw }
        fw = fq[0] - fw
        i = 1
        while i <= jz {
          fw += fq[i]
          i += 1
        }
        y[1] = if ih == 0 { fw } else { -fw }
      }
      3 => {
        i = jz
        while i > 0 {
          fw = fq[i - 1] + fq[i]
          fq[i] += fq[i - 1] - fw
          fq[i - 1] = fw
          i -= 1
        }
        i = jz
        while i > 1 {
          fw = fq[i - 1] + fq[i]
          fq[i] += fq[i - 1] - fw
          fq[i - 1] = fw
          i -= 1
        }
        fw = 0.0
        i = jz
        while i >= 2 {
          fw += fq[i]
          i -= 1
        }
        if ih == 0 {
          y[0] = fq[0]
          y[1] = fq[1]
          y[2] = fw
        } else {
          y[0] = -fq[0]
          y[1] = -fq[1]
          y[2] = -fw
        }
      }
      _ => ()
    }
  }
  n & 7
}
