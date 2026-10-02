// Rust never fuses `a * b + c` (no `mul_add` call), so neither may the
// generated C: the weights depend on unfused `f32` arithmetic.

///|
fn mul_add_unfused(a : Float, b : Float, c : Float) -> Float {
  a * b + c
}

///|
test "float mul-add is not contracted into an FMA" {
  // a * b = 1 + 2^-11 + 2^-24 exactly; rounded to f32 it is 1 + 2^-11 (tie
  // to even), so the unfused result is 0 while an FMA gives 2^-24.
  let e : Float = Float::from_int(1) / Float::from_int(4096)
  let a : Float = Float::from_int(1) + e
  let c : Float = -(Float::from_int(1) + e * Float::from_int(2))
  inspect(mul_add_unfused(a, a, c) == Float::from_int(0), content="true")
  let d : Double = 1.0 + 1.0 / 134217728.0
  let r : Double = d * d - (1.0 + 2.0 / 134217728.0)
  inspect(r == 0.0, content="true")
}
