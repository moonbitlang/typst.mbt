// Fallbacks for `math_native.mbt` on non-native targets, exact like the C
// functions.

///|
/// A correctly rounded `f32` fused multiply-add (musl's `fmaf`): the product
/// is exact in `f64`, and the double rounding of the sum is corrected in the
/// half-way cases.
fn fmaf(x : Float, y : Float, z : Float) -> Float {
  let xy = x.to_double() * y.to_double()
  let zd = z.to_double()
  let result = xy + zd
  let u = result.reinterpret_as_uint64()
  let e = (u >> 52) & 0x7ff
  // Common case: The double precision result is fine.
  if (u & 0x1fffffff) != 0x10000000 || // not a halfway case
    e == 0x7ff || // NaN
    (result - xy == zd && result - zd == xy) { // exact
    return Float::from_double(result)
  }
  // `result` is a halfway case: adjust it in the direction of the error.
  let neg = u >> 63 != 0
  let err = if neg == (zd > xy) { xy - result + zd } else { zd - result + xy }
  let u = if neg == (err < 0.0) { u + 1 } else { u - 1 }
  Float::from_double(UInt64::reinterpret_as_double(u))
}

///|
fn floorf(x : Float) -> Float {
  x.floor()
}

///|
fn roundf(x : Float) -> Float {
  let t = x.trunc()
  // Exact: for |x| >= 2^23, `x` is already integral.
  let diff = x - t
  if diff >= 0.5 {
    t + 1.0
  } else if diff <= -0.5 {
    t - 1.0
  } else {
    t
  }
}
