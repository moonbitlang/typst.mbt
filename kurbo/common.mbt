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
/// Defines the shape to be drawn at the ends of a stroke.
pub(all) enum Cap {
  /// Flat cap.
  Butt
  /// Square cap with dimensions equal to half the stroke width.
  Square
  /// Rounded cap with radius equal to half the stroke width.
  Round
} derive(Eq, Debug, Hash)
