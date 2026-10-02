// Port of `moxcms::mlaf`. On aarch64 (`target_feature = "neon"`) `mlaf` is a
// fused multiply-add.

///|
/// `mlaf(acc, a, b) = a * b + acc` (fused, `f32`).
fn mlaf(acc : Float, a : Float, b : Float) -> Float {
  @pxfm.fmaf(a, b, acc)
}

///|
/// `neg_mlaf(acc, a, b) = acc - a * b` (fused, `f32`).
fn neg_mlaf(acc : Float, a : Float, b : Float) -> Float {
  @pxfm.fmaf(a, -b, acc)
}

///|
/// `fmla(a, b, acc) = a * b + acc` (fused, `f32`).
fn fmla(a : Float, b : Float, acc : Float) -> Float {
  @pxfm.fmaf(a, b, acc)
}

///|
/// `mlaf(acc, a, b) = a * b + acc` (fused, `f64`).
fn mlaf_d(acc : Double, a : Double, b : Double) -> Double {
  @pxfm.fma(a, b, acc)
}

///|
/// `fmla(a, b, acc) = a * b + acc` (fused, `f64`).
fn fmla_d(a : Double, b : Double, acc : Double) -> Double {
  @pxfm.fma(a, b, acc)
}

///|
/// `mlaf` on `u32` (wrapping).
fn mlaf_u32(acc : UInt, a : UInt, b : UInt) -> UInt {
  a * b + acc
}
