// `pow` of the `libm` crate (0.2, a port of musl), which upstream uses for
// `calc.pow`, `calc.root` and `calc.norm`
// (typst-library/src/foundations/calc.rs). `@math.pow` is a port of the same
// FreeBSD source with the same polynomial, but not bit-identical to it for
// all arguments (`#calc.root(18, 3)`); see `libm_wbtest.mbt`.

// origin: FreeBSD /usr/src/lib/msun/src/e_pow.c
// ====================================================
// Copyright (C) 2004 by Sun Microsystems, Inc. All rights reserved.
//
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

// pow(x,y) return x**y
//
//                    n
// Method:  Let x =  2   * (1+f)
//      1. Compute and return log2(x) in two pieces:
//              log2(x) = w1 + w2,
//         where w1 has 53-24 = 29 bit trailing zeros.
//      2. Perform y*log2(x) = n+y' by simulating multi-precision
//         arithmetic, where |y'|<=0.5.
//      3. Return x**y = 2**n*exp(y'*log2)
//
// Special cases:
//      1.  (anything) ** 0  is 1
//      2.  1 ** (anything)  is 1
//      3.  (anything except 1) ** NAN is NAN
//      4.  NAN ** (anything except 0) is NAN
//      5.  +-(|x| > 1) **  +INF is +INF
//      6.  +-(|x| > 1) **  -INF is +0
//      7.  +-(|x| < 1) **  +INF is +0
//      8.  +-(|x| < 1) **  -INF is +INF
//      9.  -1          ** +-INF is 1
//      10. +0 ** (+anything except 0, NAN)               is +0
//      11. -0 ** (+anything except 0, NAN, odd integer)  is +0
//      12. +0 ** (-anything except 0, NAN)               is +INF, raise divbyzero
//      13. -0 ** (-anything except 0, NAN, odd integer)  is +INF, raise divbyzero
//      14. -0 ** (+odd integer) is -0
//      15. -0 ** (-odd integer) is -INF, raise divbyzero
//      16. +INF ** (+anything except 0,NAN) is +INF
//      17. +INF ** (-anything except 0,NAN) is +0
//      18. -INF ** (+odd integer) is -INF
//      19. -INF ** (anything) = -0 ** (-anything), (anything except odd integer)
//      20. (anything) ** 1 is (anything)
//      21. (anything) ** -1 is 1/(anything)
//      22. (-anything) ** (integer) is (-1)**(integer)*(+anything**integer)
//      23. (-anything except 0 and inf) ** (non-integer) is NAN
//
// Accuracy:
//      pow(x,y) returns x**y nearly rounded. In particular
//                      pow(integer,integer)
//      always returns the correct integer provided it is
//      representable.

///|
/// `libm::pow`: `x` to the power of `y`.
fn libm_pow(x : Double, y : Double) -> Double {
  let dp_h1 = 5.84962487220764160156e-01 // 0x3fe2b803_40000000
  let dp_l1 = 1.35003920212974897128e-08 // 0x3E4CFDEB, 0x43CFD006
  let two53 = 9007199254740992.0 // 0x43400000_00000000
  let huge = 1.0e300
  let tiny = 1.0e-300
  // poly coefs for (3/2)*(log(x)-2s-2/3*s**3:
  let l1 = 5.99999999999994648725e-01 // 0x3fe33333_33333303
  let l2 = 4.28571428578550184252e-01 // 0x3fdb6db6_db6fabff
  let l3 = 3.33333329818377432918e-01 // 0x3fd55555_518f264d
  let l4 = 2.72728123808534006489e-01 // 0x3fd17460_a91d4101
  let l5 = 2.30660745775561754067e-01 // 0x3fcd864a_93c9db65
  let l6 = 2.06975017800338417784e-01 // 0x3fca7e28_4a454eef
  let lg2 = 6.93147180559945286227e-01 // 0x3fe62e42_fefa39ef
  let lg2_h = 6.93147182464599609375e-01 // 0x3fe62e43_00000000
  let lg2_l = -1.90465429995776804525e-09 // 0xbe205c61_0ca86c39
  let ovt = 8.0085662595372944372e-017 // -(1024-log2(ovfl+.5ulp))
  let cp = 9.61796693925975554329e-01 // 0x3feec709_dc3a03fd =2/(3ln2)
  let cp_h = 9.61796700954437255859e-01 // 0x3feec709_e0000000 =(float)cp
  let cp_l = -7.02846165095275826516e-09 // 0xbe3e2fe0_145b01f5 =tail of cp_h
  let ivln2 = 1.44269504088896338700e+00 // 0x3ff71547_652b82fe =1/ln2
  let ivln2_h = 1.44269502162933349609e+00 // 0x3ff71547_60000000 =24b 1/ln2
  let ivln2_l = 1.92596299112661746887e-08 // 0x3e54ae0b_f85ddf44 =1/ln2 tail
  let mut t1 = 0.0
  let mut t2 = 0.0
  let hx = (x.reinterpret_as_uint64() >> 32).to_uint().reinterpret_as_int()
  let lx = x.reinterpret_as_uint64().to_uint()
  let hy = (y.reinterpret_as_uint64() >> 32).to_uint().reinterpret_as_int()
  let ly = y.reinterpret_as_uint64().to_uint()
  let mut ix = hx & 0x7fffffff
  let iy = hy & 0x7fffffff
  // x**0 = 1, even if x is NaN
  if (iy.reinterpret_as_uint() | ly) == 0 {
    return 1.0
  }
  // 1**y = 1, even if y is NaN
  if hx == 0x3ff00000 && lx == 0 {
    return 1.0
  }
  // NaN if either arg is NaN
  if ix > 0x7ff00000 ||
    (ix == 0x7ff00000 && lx != 0) ||
    iy > 0x7ff00000 ||
    (iy == 0x7ff00000 && ly != 0) {
    return x + y
  }
  // determine if y is an odd int when x < 0
  // yisint = 0       ... y is not an integer
  // yisint = 1       ... y is an odd int
  // yisint = 2       ... y is an even int
  let mut yisint = 0
  if hx < 0 {
    if iy >= 0x43400000 {
      yisint = 2 // even integer y
    } else if iy >= 0x3ff00000 {
      let k = (iy >> 20) - 0x3ff // exponent
      if k > 20 {
        let j = (ly >> (52 - k)).reinterpret_as_int()
        if j << (52 - k) == ly.reinterpret_as_int() {
          yisint = 2 - (j & 1)
        }
      } else if ly == 0 {
        let j = iy >> (20 - k)
        if j << (20 - k) == iy {
          yisint = 2 - (j & 1)
        }
      }
    }
  }
  if ly == 0 {
    // special value of y
    if iy == 0x7ff00000 {
      // y is +-inf
      return if ((ix - 0x3ff00000) | lx.reinterpret_as_int()) == 0 {
        // (-1)**+-inf is 1
        1.0
      } else if ix >= 0x3ff00000 {
        // (|x|>1)**+-inf = inf,0
        if hy >= 0 {
          y
        } else {
          0.0
        }
      } else if hy >= 0 {
        // (|x|<1)**+-inf = 0,inf
        0.0
      } else {
        -y
      }
    }
    if iy == 0x3ff00000 {
      // y is +-1
      return if hy >= 0 { x } else { 1.0 / x }
    }
    if hy == 0x40000000 {
      // y is 2
      return x * x
    }
    if hy == 0x3fe00000 {
      // y is 0.5
      if hx >= 0 {
        // x >= +0
        return x.sqrt()
      }
    }
  }
  let mut ax = x.abs()
  if lx == 0 {
    // special value of x
    if ix == 0x7ff00000 || ix == 0 || ix == 0x3ff00000 {
      // x is +-0,+-inf,+-1
      let mut z = ax
      if hy < 0 {
        // z = (1/|x|)
        z = 1.0 / z
      }
      if hx < 0 {
        if ((ix - 0x3ff00000) | yisint) == 0 {
          z = (z - z) / (z - z) // (-1)**non-int is NaN
        } else if yisint == 1 {
          z = -z // (x<0)**odd = -(|x|**odd)
        }
      }
      return z
    }
  }
  let mut s = 1.0 // sign of result
  if hx < 0 {
    if yisint == 0 {
      // (x<0)**(non-int) is NaN
      return (x - x) / (x - x)
    }
    if yisint == 1 {
      // (x<0)**(odd int)
      s = -1.0
    }
  }
  // |y| is HUGE
  if iy > 0x41e00000 {
    // if |y| > 2**31
    if iy > 0x43f00000 {
      // if |y| > 2**64, must o/uflow
      if ix <= 0x3fefffff {
        return if hy < 0 { huge * huge } else { tiny * tiny }
      }
      if ix >= 0x3ff00000 {
        return if hy > 0 { huge * huge } else { tiny * tiny }
      }
    }
    // over/underflow if x is not close to one
    if ix < 0x3fefffff {
      return if hy < 0 { s * huge * huge } else { s * tiny * tiny }
    }
    if ix > 0x3ff00000 {
      return if hy > 0 { s * huge * huge } else { s * tiny * tiny }
    }
    // now |1-x| is TINY <= 2**-20, suffice to compute
    // log(x) by x-x^2/2+x^3/3-x^4/4
    let t = ax - 1.0 // t has 20 trailing zeros
    let w = t * t * (0.5 - t * (0.3333333333333333333333 - t * 0.25))
    let u = ivln2_h * t // ivln2_h has 21 sig. bits
    let v = t * ivln2_l - w * ivln2
    t1 = libm_with_set_low_word(u + v, 0)
    t2 = v - (t1 - u)
  } else {
    // double ss,s2,s_h,s_l,t_h,t_l;
    let mut n = 0
    if ix < 0x00100000 {
      // take care subnormal number
      ax = ax * two53
      n -= 53
      ix = libm_high_word(ax).reinterpret_as_int()
    }
    n += (ix >> 20) - 0x3ff
    let j = ix & 0x000fffff
    // determine interval
    let mut k = 0
    ix = j | 0x3ff00000 // normalize ix
    if j <= 0x3988E {
      // |x|<sqrt(3/2)
      k = 0
    } else if j < 0xBB67A {
      // |x|<sqrt(3)
      k = 1
    } else {
      k = 0
      n += 1
      ix -= 0x00100000
    }
    ax = libm_with_set_high_word(ax, ix.reinterpret_as_uint())
    // bp[0]=1.0, bp[1]=1.5; dp_h[0]=dp_l[0]=0.0
    let bp_k = if k == 0 { 1.0 } else { 1.5 }
    let dp_h_k = if k == 0 { 0.0 } else { dp_h1 }
    let dp_l_k = if k == 0 { 0.0 } else { dp_l1 }
    // compute ss = s_h+s_l = (x-1)/(x+1) or (x-1.5)/(x+1.5)
    let u = ax - bp_k
    let v = 1.0 / (ax + bp_k)
    let ss = u * v
    let s_h = libm_with_set_low_word(ss, 0)
    // t_h=ax+bp[k] High
    let t_h = libm_with_set_high_word(
      0.0,
      ((ix.reinterpret_as_uint() >> 1) | 0x20000000) +
      0x00080000 +
      (k.reinterpret_as_uint() << 18),
    )
    let t_l = ax - (t_h - bp_k)
    let s_l = v * (u - s_h * t_h - s_h * t_l)
    // compute log(ax)
    let s2 = ss * ss
    let mut r = s2 *
      s2 *
      (l1 + s2 * (l2 + s2 * (l3 + s2 * (l4 + s2 * (l5 + s2 * l6)))))
    r = r + s_l * (s_h + ss)
    let s2 = s_h * s_h
    let t_h = libm_with_set_low_word(3.0 + s2 + r, 0)
    let t_l = r - (t_h - 3.0 - s2)
    // u+v = ss*(1+...)
    let u = s_h * t_h
    let v = s_l * t_h + t_l * ss
    // 2/(3log2)*(ss+...)
    let p_h = libm_with_set_low_word(u + v, 0)
    let p_l = v - (p_h - u)
    let z_h = cp_h * p_h // cp_h+cp_l = 2/(3*log2)
    let z_l = cp_l * p_h + p_l * cp + dp_l_k
    // log2(ax) = (ss+..)*2/(3*log2) = n + dp_h + z_h + z_l
    let t = n.to_double()
    t1 = libm_with_set_low_word(z_h + z_l + dp_h_k + t, 0)
    t2 = z_l - (t1 - t - dp_h_k - z_h)
  }
  // split up y into y1+y2 and compute (y1+y2)*(t1+t2)
  let y1 = libm_with_set_low_word(y, 0)
  let p_l = (y - y1) * t1 + y * t2
  let mut p_h = y1 * t1
  let z = p_l + p_h
  let mut j = (z.reinterpret_as_uint64() >> 32).to_uint().reinterpret_as_int()
  let i = z.reinterpret_as_uint64().to_uint().reinterpret_as_int()
  if j >= 0x40900000 {
    // z >= 1024
    if ((j - 0x40900000) | i) != 0 {
      // if z > 1024
      return s * huge * huge // overflow
    }
    if p_l + ovt > z - p_h {
      return s * huge * huge // overflow
    }
  } else if (j & 0x7fffffff) >= 0x4090cc00 {
    // z <= -1075
    // FIXME: instead of abs(j) use unsigned j
    if ((j.reinterpret_as_uint() - 0xc090cc00) | i.reinterpret_as_uint()) != 0 {
      // z < -1075
      return s * tiny * tiny // underflow
    }
    if p_l <= z - p_h {
      return s * tiny * tiny // underflow
    }
  }
  // compute 2**(p_h+p_l)
  let i = j & 0x7fffffff
  let mut k = (i >> 20) - 0x3ff
  let mut n = 0
  if i > 0x3fe00000 {
    // if |z| > 0.5, set n = [z+0.5]
    n = j + (0x00100000 >> (k + 1))
    k = ((n & 0x7fffffff) >> 20) - 0x3ff // new k for n
    let t = libm_with_set_high_word(
      0.0,
      (n & ((0x000fffff >> k) ^ -1)).reinterpret_as_uint(),
    )
    n = ((n & 0x000fffff) | 0x00100000) >> (20 - k)
    if j < 0 {
      n = -n
    }
    p_h = p_h - t
  }
  let t = libm_with_set_low_word(p_l + p_h, 0)
  let u = t * lg2_h
  let v = (p_l - (t - p_h)) * lg2 + t * lg2_l
  let mut z = u + v
  let w = v - (z - u)
  let t = z * z
  let t1 = z -
    t * (LIBM_P1 + t * (LIBM_P2 + t * (LIBM_P3 + t * (LIBM_P4 + t * LIBM_P5))))
  let r = z * t1 / (t1 - 2.0) - (w + z * w)
  z = 1.0 - (r - z)
  j = libm_high_word(z).reinterpret_as_int()
  j += n << 20
  if j >> 20 <= 0 {
    // subnormal output
    z = libm_scalbn(z, n)
  } else {
    z = libm_with_set_high_word(z, j.reinterpret_as_uint())
  }
  s * z
}
