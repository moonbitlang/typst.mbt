// The pieces of `kurbo` 0.13.1 that usvg's text-on-path layout uses:
// `Line`, `QuadBez::raise`, `CubicBez` evaluation, derivative, subdivision,
// arc length (`src/cubicbez.rs`) and its inverse (`ParamCurveArclen`'s
// default `inv_arclen` with `common::solve_itp`).

///|
/// A cubic Bézier segment.
priv struct KCubicBez {
  p0 : KPoint
  p1 : KPoint
  p2 : KPoint
  p3 : KPoint
}

///|
/// A quadratic Bézier segment.
priv struct KQuadBez {
  p0 : KPoint
  p1 : KPoint
  p2 : KPoint
}

///|
fn KPoint::hypot2(self : KPoint) -> Double {
  self.x * self.x + self.y * self.y
}

///|
fn KPoint::hypot(self : KPoint) -> Double {
  // Avoid f64::hypot as it calls a slow library function.
  self.hypot2().sqrt()
}

///|
fn KPoint::lerp(self : KPoint, other : KPoint, t : Double) -> KPoint {
  self.add(other.sub(self).scale(t))
}

///|
fn KPoint::midpoint(self : KPoint, other : KPoint) -> KPoint {
  { x: 0.5 * (self.x + other.x), y: 0.5 * (self.y + other.y), }
}

///|
/// `Line::eval`.
fn kline_eval(p0 : KPoint, p1 : KPoint, t : Double) -> KPoint {
  p0.lerp(p1, t)
}

///|
/// Raise the order by 1.
fn KQuadBez::raise_(self : KQuadBez) -> KCubicBez {
  {
    p0: self.p0,
    p1: self.p0.add(self.p1.sub(self.p0).scale(2.0 / 3.0)),
    p2: self.p2.add(self.p1.sub(self.p2).scale(2.0 / 3.0)),
    p3: self.p2,
  }
}

///|
fn KQuadBez::eval(self : KQuadBez, t : Double) -> KPoint {
  let mt = 1.0 - t
  self.p0
  .scale(mt * mt)
  .add(self.p1.scale(mt * 2.0).add(self.p2.scale(t)).scale(t))
}

///|
fn KCubicBez::eval(self : KCubicBez, t : Double) -> KPoint {
  let mt = 1.0 - t
  self.p0
  .scale(mt * mt * mt)
  .add(
    self.p1
    .scale(mt * mt * 3.0)
    .add(self.p2.scale(mt * 3.0).add(self.p3.scale(t)).scale(t))
    .scale(t),
  )
}

///|
fn KCubicBez::deriv(self : KCubicBez) -> KQuadBez {
  {
    p0: self.p1.sub(self.p0).scale(3.0),
    p1: self.p2.sub(self.p1).scale(3.0),
    p2: self.p3.sub(self.p2).scale(3.0),
  }
}

///|
fn KCubicBez::subsegment(
  self : KCubicBez,
  t0 : Double,
  t1 : Double,
) -> KCubicBez {
  let p0 = self.eval(t0)
  let p3 = self.eval(t1)
  let d = self.deriv()
  let scale = (t1 - t0) * (1.0 / 3.0)
  let p1 = p0.add(d.eval(t0).scale(scale))
  let p2 = p3.sub(d.eval(t1).scale(scale))
  { p0, p1, p2, p3, }
}

///|
/// Subdivide into halves, using de Casteljau.
fn KCubicBez::subdivide(self : KCubicBez) -> (KCubicBez, KCubicBez) {
  let pm = self.eval(0.5)
  (
    {
      p0: self.p0,
      p1: self.p0.midpoint(self.p1),
      p2: self.p0.add(self.p1.scale(2.0)).add(self.p2).scale(0.25),
      p3: pm,
    },
    {
      p0: pm,
      p1: self.p1.add(self.p2.scale(2.0)).add(self.p3).scale(0.25),
      p2: self.p2.midpoint(self.p3),
      p3: self.p3,
    },
  )
}

///|
/// Rust's `f64::powi` (LLVM's `__powidf2`).
fn powi_f64(a : Double, b : Int) -> Double {
  let recip = b < 0
  let mut r = 1.0
  let mut a = a
  let mut b = b
  while true {
    if (b & 1) != 0 {
      r = r * a
    }
    b = b / 2
    if b == 0 {
      break
    }
    a = a * a
  }
  if recip {
    1.0 / r
  } else {
    r
  }
}

///|
/// Rust's `Iterator::sum` for `f64` (a fold starting at `-0.0`).
fn sum_f64(values : Array[Double]) -> Double {
  let mut acc = -0.0
  for v in values {
    acc = acc + v
  }
  acc
}

///|
fn arclen_quadrature_core(
  coeffs : ReadOnlyArray[(Double, Double)],
  dm : KPoint,
  dm1 : KPoint,
  dm2 : KPoint,
) -> Double {
  sum_f64(
    coeffs[:].map(c => {
      let (wi, xi) = c
      let d = dm.add(dm2.scale(xi * xi))
      let dpx = d.add(dm1.scale(xi)).hypot()
      let dmx = d.sub(dm1.scale(xi)).hypot()
      1.5 * wi * (dpx + dmx)
    }),
  )
}

///|
fn arclen_rec(c : KCubicBez, accuracy : Double, depth : Int) -> Double {
  let d03 = c.p3.sub(c.p0)
  let d01 = c.p1.sub(c.p0)
  let d12 = c.p2.sub(c.p1)
  let d23 = c.p3.sub(c.p2)
  let lp_lc = d01.hypot() + d12.hypot() + d23.hypot() - d03.hypot()
  let dd1 = d12.sub(d01)
  let dd2 = d23.sub(d12)
  // It might be faster to do direct multiplies, the data dependencies would be shorter.
  // The following values don't have the factor of 3 for first deriv
  let dm = d01.add(d23).scale(0.25).add(d12.scale(0.5)) // first derivative at midpoint
  let dm1 = dd2.add(dd1).scale(0.5) // second derivative at midpoint
  let dm2 = dd2.sub(dd1).scale(0.25) // 0.5 * (third derivative at midpoint)
  let est = sum_f64(
    gauss_legendre_coeffs_8[:].map(c => {
      let (wi, xi) = c
      wi *
      ({
        let d_norm2 = dm.add(dm1.scale(xi)).add(dm2.scale(xi * xi)).hypot2()
        let dd_norm2 = dm1.add(dm2.scale(2.0 * xi)).hypot2()
        dd_norm2 / d_norm2
      })
    }),
  )
  let est_gauss8_error = (powi_f64(est, 3) * 2.5e-6).min(3.0e-2) * lp_lc
  if est_gauss8_error < accuracy {
    return arclen_quadrature_core(gauss_legendre_coeffs_8_half, dm, dm1, dm2)
  }
  let est_gauss16_error = (powi_f64(est, 6) * 1.5e-11).min(9.0e-3) * lp_lc
  if est_gauss16_error < accuracy {
    return arclen_quadrature_core(gauss_legendre_coeffs_16_half, dm, dm1, dm2)
  }
  let est_gauss24_error = (powi_f64(est, 9) * 3.5e-16).min(3.5e-3) * lp_lc
  if est_gauss24_error < accuracy || depth >= 20 {
    return arclen_quadrature_core(gauss_legendre_coeffs_24_half, dm, dm1, dm2)
  }
  let (c0, c1) = c.subdivide()
  arclen_rec(c0, accuracy * 0.5, depth + 1) +
  arclen_rec(c1, accuracy * 0.5, depth + 1)
}

///|
/// Arclength of a cubic Bézier segment.
fn KCubicBez::arclen(self : KCubicBez, accuracy : Double) -> Double {
  arclen_rec(self, accuracy, 0)
}

///|
/// Solve for parameter value given arclength (`ParamCurveArclen::inv_arclen`).
fn KCubicBez::inv_arclen(
  self : KCubicBez,
  arclen : Double,
  accuracy : Double,
) -> Double {
  if arclen <= 0.0 {
    return 0.0
  }
  let total_arclen = self.arclen(accuracy)
  if arclen >= total_arclen {
    return 1.0
  }
  let mut t_last = 0.0
  let mut arclen_last = 0.0
  let epsilon = accuracy / total_arclen
  let n = 1.0 - libm_log2(epsilon).ceil().min(0.0)
  let inner_accuracy = accuracy / n
  let f = (t : Double) => {
    let (t0, t1, dir) = if t > t_last {
      (t_last, t, 1.0)
    } else {
      (t, t_last, -1.0)
    }
    let arc = self.subsegment(t0, t1).arclen(inner_accuracy)
    arclen_last += arc * dir
    t_last = t
    arclen_last - arclen
  }
  solve_itp(f, 0.0, 1.0, epsilon, 1, 0.2, -arclen, total_arclen - arclen)
}

///|
/// Rust's `f64::copysign`.
fn copysign_f64(x : Double, sign : Double) -> Double {
  let bits = (x.reinterpret_as_uint64() & 0x7FFFFFFFFFFFFFFFUL) |
    (sign.reinterpret_as_uint64() & 0x8000000000000000UL)
  bits.reinterpret_as_double()
}

///|
/// Find a root with the ITP method (`kurbo::common::solve_itp`).
fn solve_itp(
  f : (Double) -> Double,
  a : Double,
  b : Double,
  epsilon : Double,
  n0 : Int,
  k1 : Double,
  ya : Double,
  yb : Double,
) -> Double {
  let mut a = a
  let mut b = b
  let mut ya = ya
  let mut yb = yb
  let n1_2 = f64_as_usize((libm_log2((b - a) / epsilon).ceil() - 1.0).max(0.0))
  let nmax = n0 + n1_2
  let mut scaled_epsilon = epsilon * (1UL << nmax).to_double()
  while b - a > 2.0 * epsilon {
    let x1_2 = 0.5 * (a + b)
    let r = scaled_epsilon - 0.5 * (b - a)
    let xf = (yb * a - ya * b) / (yb - ya)
    let sigma = x1_2 - xf
    // This has k2 = 2 hardwired for efficiency.
    let delta = k1 * powi_f64(b - a, 2)
    let xt = if delta <= (x1_2 - xf).abs() {
      xf + copysign_f64(delta, sigma)
    } else {
      x1_2
    }
    let xitp = if (xt - x1_2).abs() <= r {
      xt
    } else {
      x1_2 - copysign_f64(r, sigma)
    }
    let yitp = f(xitp)
    if yitp > 0.0 {
      b = xitp
      yb = yitp
    } else if yitp < 0.0 {
      a = xitp
      ya = yitp
    } else {
      a = xitp
      b = xitp
      break
    }
    scaled_epsilon *= 0.5
  }
  0.5 * (a + b)
}

///|
let gauss_legendre_coeffs_8 : ReadOnlyArray[(Double, Double)] = [
  (0.3626837833783620, -0.1834346424956498),
  (0.3626837833783620, 0.1834346424956498),
  (0.3137066458778873, -0.5255324099163290),
  (0.3137066458778873, 0.5255324099163290),
  (0.2223810344533745, -0.7966664774136267),
  (0.2223810344533745, 0.7966664774136267),
  (0.1012285362903763, -0.9602898564975363),
  (0.1012285362903763, 0.9602898564975363),
]

///|
let gauss_legendre_coeffs_8_half : ReadOnlyArray[(Double, Double)] = [
  (0.3626837833783620, 0.1834346424956498),
  (0.3137066458778873, 0.5255324099163290),
  (0.2223810344533745, 0.7966664774136267),
  (0.1012285362903763, 0.9602898564975363),
]

///|
let gauss_legendre_coeffs_16_half : ReadOnlyArray[(Double, Double)] = [
  (0.1894506104550685, 0.0950125098376374),
  (0.1826034150449236, 0.2816035507792589),
  (0.1691565193950025, 0.4580167776572274),
  (0.1495959888165767, 0.6178762444026438),
  (0.1246289712555339, 0.7554044083550030),
  (0.0951585116824928, 0.8656312023878318),
  (0.0622535239386479, 0.9445750230732326),
  (0.0271524594117541, 0.9894009349916499),
]

///|
let gauss_legendre_coeffs_24_half : ReadOnlyArray[(Double, Double)] = [
  (0.1279381953467522, 0.0640568928626056),
  (0.1258374563468283, 0.1911188674736163),
  (0.1216704729278034, 0.3150426796961634),
  (0.1155056680537256, 0.4337935076260451),
  (0.1074442701159656, 0.5454214713888396),
  (0.0976186521041139, 0.6480936519369755),
  (0.0861901615319533, 0.7401241915785544),
  (0.0733464814110803, 0.8200019859739029),
  (0.0592985849154368, 0.8864155270044011),
  (0.0442774388174198, 0.9382745520027328),
  (0.0285313886289337, 0.9747285559713095),
  (0.0123412297999872, 0.9951872199970213),
]
