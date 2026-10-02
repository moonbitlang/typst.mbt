// Port of `kurbo` 0.13 `param_curve.rs` (the parts used by stroke
// expansion: `Nearest` and the default `ParamCurveArclen::inv_arclen`).

///|
/// The default accuracy for parameterized curve methods
/// (`DEFAULT_ACCURACY`).
pub const DEFAULT_ACCURACY : Double = 1.0e-6

///|
/// The nearest position on a curve to some point.
///
/// This is returned by `nearest`.
pub(all) struct Nearest {
  /// The square of the distance from the nearest position on the curve
  /// to the given point.
  distance_sq : Double
  /// The position on the curve of the nearest point, as a parameter.
  ///
  /// To resolve this to a [`Point`], use `eval`.
  t : Double
} derive(Eq, Debug)

///|
/// The default `ParamCurveArclen::inv_arclen`: solve for the parameter that
/// has the given arclength from the start, by ITP root finding on the
/// arclengths of subsegments.
///
/// `total` computes `self.arclen(accuracy)`; `sub_arclen(t0, t1, acc)`
/// computes `self.subsegment(t0..t1).arclen(acc)`.
fn inv_arclen_default(
  arclen : Double,
  accuracy : Double,
  total : () -> Double,
  sub_arclen : (Double, Double, Double) -> Double,
) -> Double {
  if arclen <= 0.0 {
    return 0.0
  }
  let total_arclen = total()
  if arclen >= total_arclen {
    return 1.0
  }
  let t_last : Ref[Double] = { val: 0.0, }
  let arclen_last : Ref[Double] = { val: 0.0, }
  let epsilon = accuracy / total_arclen
  let n = 1.0 - fmin(fceil(libm_log2(epsilon)), 0.0)
  let inner_accuracy = accuracy / n
  let f = fn(t : Double) -> Double {
    let (t0, t1, dir) = if t > t_last.val {
      (t_last.val, t, 1.0)
    } else {
      (t, t_last.val, -1.0)
    }
    let arc = sub_arclen(t0, t1, inner_accuracy)
    arclen_last.val += arc * dir
    t_last.val = t
    arclen_last.val - arclen
  }
  solve_itp(f, 0.0, 1.0, epsilon, 1, 0.2, -arclen, total_arclen - arclen)
}
