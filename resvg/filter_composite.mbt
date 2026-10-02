// Port of `resvg/src/filter/composite.rs`.

///|
/// Performs an arithmetic composition.
///
/// - `src1` and `src2` image pixels should have a **premultiplied alpha**.
/// - `dest` image pixels will have a **premultiplied alpha**.
///
/// # Panics
///
/// When `src1`, `src2` and `dest` have different sizes.
fn composite_arithmetic(
  k1 : Float,
  k2 : Float,
  k3 : Float,
  k4 : Float,
  src1 : @skia.Pixmap,
  src2 : @skia.Pixmap,
  dest : @skia.Pixmap,
) -> Unit {
  guard! src1.width() == src2.width() && src1.width() == dest.width()
  guard! src1.height() == src2.height() && src1.height() == dest.height()
  let calc = fn(i1 : Int, i2 : Int, max : Float) -> Float {
    let i1 = Float::from_int(i1) / 255.0
    let i2 = Float::from_int(i2) / 255.0
    let result = k1 * i1 * i2 + k2 * i1 + k3 * i2 + k4
    f32_bound(0.0, result, max)
  }
  let d1 = src1.pixels()
  let d2 = src2.pixels()
  let out = dest.pixels()
  for i in 0..<d1.length() {
    let c1 = d1[i]
    let c2 = d2[i]
    let a = calc(px_a(c1), px_a(c2), 1.0)
    if @path.approx_eq_ulps(a, 0.0, 4) {
      continue
    }
    let r = f32_to_u8(calc(px_r(c1), px_r(c2), a) * 255.0)
    let g = f32_to_u8(calc(px_g(c1), px_g(c2), a) * 255.0)
    let b = f32_to_u8(calc(px_b(c1), px_b(c2), a) * 255.0)
    let a = f32_to_u8(a * 255.0)
    out[i] = px_pack(r, g, b, a)
  }
}
