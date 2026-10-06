// Port of `kurbo` 0.13 `common.rs` (`solve_quadratic`) and the stroke style
// enums of `stroke.rs`.

///|
/// Rust's `f64::copysign`.
fn copysign(x : Double, sign : Double) -> Double {
  let mag = x.reinterpret_as_uint64() & 0x7FFF_FFFF_FFFF_FFFFUL
  let s = sign.reinterpret_as_uint64() & 0x8000_0000_0000_0000UL
  (mag | s).reinterpret_as_double()
}

///|
fn is_finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
/// Find real roots of cubic equation.
///
/// The implementation is not (yet) fully robust, but it does handle the case
/// where `c3` is zero (in that case, solving the quadratic equation).
///
/// See: <https://momentsingraphics.de/CubicRoots.html>
///
/// That implementation is in turn based on Jim Blinn's "How to Solve a Cubic
/// Equation", which is masterful.
///
/// Return values of x for which c0 + c1 x + c2 x² + c3 x³ = 0.
pub fn solve_cubic(
  c0 : Double,
  c1 : Double,
  c2 : Double,
  c3 : Double,
) -> Array[Double] {
  let result = []
  let c3_recip = 1.0 / c3
  let onethird = 1.0 / 3.0
  let scaled_c2 = c2 * (onethird * c3_recip)
  let scaled_c1 = c1 * (onethird * c3_recip)
  let scaled_c0 = c0 * c3_recip
  if !(is_finite(scaled_c0) && is_finite(scaled_c1) && is_finite(scaled_c2)) {
    // cubic coefficient is zero or nearly so.
    return solve_quadratic(c0, c1, c2)
  }
  let (c0, c1, c2) = (scaled_c0, scaled_c1, scaled_c2)
  // (d0, d1, d2) is called "Delta" in article
  let d0 = libm_fma(-c2, c2, c1)
  let d1 = libm_fma(-c1, c2, c0)
  let d2 = c2 * c0 - c1 * c1
  // d is called "Discriminant"
  let d = 4.0 * d0 * d2 - d1 * d1
  // de is called "Depressed.x", Depressed.y = d0
  let de = libm_fma(-2.0 * c2, d0, d1)
  // TODO: handle the cases where these intermediate results overflow.
  if d < 0.0 {
    let sq = (-0.25 * d).sqrt()
    let r = -0.5 * de
    let t1 = libm_cbrt(r + sq) + libm_cbrt(r - sq)
    result.push(t1 - c2)
  } else if d == 0.0 {
    let t1 = copysign((-d0).sqrt(), de)
    result.push(t1 - c2)
    result.push(-2.0 * t1 - c2)
  } else {
    let th = libm_atan2(d.sqrt(), -de) * onethird
    // (th_cos, th_sin) is called "CubicRoot"
    let (th_sin, th_cos) = sin_cos(th)
    // (r0, r1, r2) is called "Root"
    let r0 = th_cos
    let ss3 = th_sin * 3.0.sqrt()
    let r1 = 0.5 * (-th_cos + ss3)
    let r2 = 0.5 * (-th_cos - ss3)
    let t = 2.0 * (-d0).sqrt()
    result.push(libm_fma(t, r0, -c2))
    result.push(libm_fma(t, r1, -c2))
    result.push(libm_fma(t, r2, -c2))
  }
  result
}

///|
/// Find real roots of quadratic equation.
///
/// Return values of x for which c0 + c1 x + c2 x² = 0.
///
/// This function tries to be quite numerically robust. If the equation
/// is nearly linear, it will return the root ignoring the quadratic term;
/// the other root might be out of representable range. In the degenerate
/// case where all coefficients are zero, so that all values of x satisfy
/// the equation, a single `0.0` is returned.
pub fn solve_quadratic(c0 : Double, c1 : Double, c2 : Double) -> Array[Double] {
  let result = []
  let sc0 = c0 * (1.0 / c2)
  let sc1 = c1 * (1.0 / c2)
  if !is_finite(sc0) || !is_finite(sc1) {
    // c2 is zero or very small, treat as linear eqn
    let root = -c0 / c1
    if is_finite(root) {
      result.push(root)
    } else if c0 == 0.0 && c1 == 0.0 {
      // Degenerate case
      result.push(0.0)
    }
    return result
  }
  let arg = sc1 * sc1 - 4.0 * sc0
  let root1 = if !is_finite(arg) {
    // Likely, calculation of sc1 * sc1 overflowed. Find one root
    // using sc1 x + x² = 0, other root as sc0 / root1.
    -sc1
  } else {
    if arg < 0.0 {
      return result
    } else if arg == 0.0 {
      result.push(-0.5 * sc1)
      return result
    }
    // See https://math.stackexchange.com/questions/866331
    -0.5 * (sc1 + copysign(arg.sqrt(), sc1))
  }
  let root2 = sc0 / root1
  if is_finite(root2) {
    // Sort just to be friendly and make results deterministic.
    if root2 > root1 {
      result.push(root1)
      result.push(root2)
    } else {
      result.push(root2)
      result.push(root1)
    }
  } else {
    result.push(root1)
  }
  result
}

///|
/// Defines the connection between two segments of a stroke.
pub(all) enum Join {
  /// A straight line connecting the segments.
  Bevel
  /// The segments are extended to their natural intersection point.
  Miter
  /// An arc between the segments.
  Round
} derive(Eq, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Join with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Join with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Join with Hash::{hash, hash_combine}

///|
/// Defines the shape to be drawn at the ends of a stroke.
pub(all) enum Cap {
  /// Flat cap.
  Butt
  /// Square cap with dimensions equal to half the stroke width.
  Square
  /// Rounded cap with radius equal to half the stroke width.
  Round
} derive(Eq, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Cap with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Cap with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Cap with Hash::{hash, hash_combine}

///|
/// Solve an arbitrary function for a zero-crossing.
///
/// This uses the [ITP method], as described in the paper
/// [An Enhancement of the Bisection Method Average Performance Preserving
/// Minmax Optimality].
///
/// The values of `ya` and `yb` are given as arguments rather than computed
/// from `f`, as the values may already be known, or they may be less
/// expensive to compute as special cases.
///
/// It is assumed that `ya < 0.0` and `yb > 0.0`, otherwise unexpected
/// results may occur.
///
/// The value of `epsilon` must be larger than 2^-63 times `b - a`,
/// otherwise integer overflow may occur. The `a` and `b` parameters
/// represent the lower and upper bounds of the bracket searched for a
/// solution.
///
/// The ITP method has tuning parameters. This implementation hardwires
/// k2 to 2, both because it avoids an expensive floating point
/// exponentiation, and because this value has been tested to work well
/// with curve fitting problems.
///
/// The `n0` parameter controls the relative impact of the bisection and
/// secant components. When it is 0, the number of iterations is
/// guaranteed to be no more than the number required by bisection (thus,
/// this method is strictly superior to bisection). However, when the
/// function is smooth, a value of 1 gives the secant method more of a
/// chance to engage, so the average number of iterations is likely
/// lower, though there can be one more iteration than bisection in the
/// worst case.
///
/// The `k1` parameter is harder to characterize, and interested users
/// are referred to the paper, as well as encouraged to do empirical
/// testing. To match the paper, a value of `0.2 / (b - a)` is
/// suggested, and this is confirmed to give good results.
///
/// When the function is monotonic, the returned result is guaranteed to
/// be within `epsilon` of the zero crossing. For more detailed analysis,
/// again see the paper.
///
/// [ITP method]: https://en.wikipedia.org/wiki/ITP_Method
/// [An Enhancement of the Bisection Method Average Performance Preserving Minmax Optimality]: https://dl.acm.org/doi/10.1145/3423597
pub fn solve_itp(
  f : (Double) -> Double,
  a : Double,
  b : Double,
  epsilon : Double,
  n0 : Int,
  k1 : Double,
  ya : Double,
  yb : Double,
) -> Double {
  let (a, b) = solve_itp_bracket(f, a, b, epsilon, n0, k1, ya, yb)
  // Return the midpoint of the bracket returned by `solve_itp_fallible`. If
  // that found an exact zero, it returns `(a, a)`, and the following will
  // result in exactly `a` (except for harmless negative zero subtlety or
  // when `a + b` overflows ~1e308).
  0.5 * (a + b)
}

///|
/// `solve_itp_fallible` with an infallible `f`: returns the bracket that
/// contains the root.
fn solve_itp_bracket(
  f : (Double) -> Double,
  a : Double,
  b : Double,
  epsilon : Double,
  n0 : Int,
  k1 : Double,
  ya : Double,
  yb : Double,
) -> (Double, Double) {
  let mut a = a
  let mut b = b
  let mut ya = ya
  let mut yb = yb
  let n1_2 = f64_to_u64_sat(
    fmax(fceil(libm_log2((b - a) / epsilon)) - 1.0, 0.0),
  )
  // `usize` arithmetic wraps and `<<` masks its shift amount in release
  // builds.
  let nmax = n0.to_uint64() + n1_2
  let mut scaled_epsilon = epsilon * (1UL << (nmax & 63UL).to_int()).to_double()
  while b - a > 2.0 * epsilon {
    let x1_2 = 0.5 * (a + b)
    let r = scaled_epsilon - 0.5 * (b - a)
    let xf = (yb * a - ya * b) / (yb - ya)
    let sigma = x1_2 - xf
    // This has k2 = 2 hardwired for efficiency.
    let delta = k1 * powi(b - a, 2)
    let xt = if delta <= fabs(x1_2 - xf) {
      xf + copysign(delta, sigma)
    } else {
      x1_2
    }
    let xitp = if fabs(xt - x1_2) <= r { xt } else { x1_2 - copysign(r, sigma) }
    let yitp = f(xitp)
    if yitp > 0.0 {
      b = xitp
      yb = yitp
    } else if yitp < 0.0 {
      a = xitp
      ya = yitp
    } else {
      return (xitp, xitp)
    }
    scaled_epsilon *= 0.5
  }
  (a, b)
}

// Tables of Legendre-Gauss quadrature coefficients, adapted from:
// <https://pomax.github.io/bezierinfo/legendre-gauss.html>

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
// Just the positive x_i values.
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
