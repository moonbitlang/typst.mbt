// Port of `resvg/src/filter/color_matrix.rs`.

///|
/// Applies a color matrix filter.
///
/// Input image pixels should have an **unpremultiplied alpha**.
fn color_matrix_apply(
  matrix : @usvg.ColorMatrixKind,
  data : FixedArray[UInt],
) -> Unit {
  match matrix {
    Matrix(m) =>
      for i in 0..<data.length() {
        let (r, g, b, a) = to_normalized_components(data[i])
        let new_r = r * m[0] + g * m[1] + b * m[2] + a * m[3] + m[4]
        let new_g = r * m[5] + g * m[6] + b * m[7] + a * m[8] + m[9]
        let new_b = r * m[10] + g * m[11] + b * m[12] + a * m[13] + m[14]
        let new_a = r * m[15] + g * m[16] + b * m[17] + a * m[18] + m[19]
        data[i] = px_pack(
          from_normalized(new_r),
          from_normalized(new_g),
          from_normalized(new_b),
          from_normalized(new_a),
        )
      }
    Saturate(v) => {
      let v = @skia.fmax(v.get(), 0.0)
      let m : FixedArray[Float] = [
        0.213 + 0.787 * v,
        0.715 - 0.715 * v,
        0.072 - 0.072 * v,
        0.213 - 0.213 * v,
        0.715 + 0.285 * v,
        0.072 - 0.072 * v,
        0.213 - 0.213 * v,
        0.715 - 0.715 * v,
        0.072 + 0.928 * v,
      ]
      apply_rgb_matrix(m, data)
    }
    HueRotate(angle) => {
      let angle = @skia.to_radians(angle)
      let a1 = sincosf_cos(angle)
      let a2 = sincosf_sin(angle)
      let m : FixedArray[Float] = [
        0.213 + 0.787 * a1 - 0.213 * a2,
        0.715 - 0.715 * a1 - 0.715 * a2,
        0.072 - 0.072 * a1 + 0.928 * a2,
        0.213 - 0.213 * a1 + 0.143 * a2,
        0.715 + 0.285 * a1 + 0.140 * a2,
        0.072 - 0.072 * a1 - 0.283 * a2,
        0.213 - 0.213 * a1 - 0.787 * a2,
        0.715 - 0.715 * a1 + 0.715 * a2,
        0.072 + 0.928 * a1 + 0.072 * a2,
      ]
      apply_rgb_matrix(m, data)
    }
    LuminanceToAlpha =>
      for i in 0..<data.length() {
        let (r, g, b, _) = to_normalized_components(data[i])
        let new_a = r * 0.2125 + g * 0.7154 + b * 0.0721
        data[i] = px_pack(0, 0, 0, from_normalized(new_a))
      }
  }
}

///|
fn apply_rgb_matrix(m : FixedArray[Float], data : FixedArray[UInt]) -> Unit {
  for i in 0..<data.length() {
    let p = data[i]
    let (r, g, b, _) = to_normalized_components(p)
    let new_r = r * m[0] + g * m[1] + b * m[2]
    let new_g = r * m[3] + g * m[4] + b * m[5]
    let new_b = r * m[6] + g * m[7] + b * m[8]
    data[i] = px_pack(
      from_normalized(new_r),
      from_normalized(new_g),
      from_normalized(new_b),
      px_a(p),
    )
  }
}

///|
fn to_normalized_components(pixel : UInt) -> (Float, Float, Float, Float) {
  (
    Float::from_int(px_r(pixel)) / 255.0,
    Float::from_int(px_g(pixel)) / 255.0,
    Float::from_int(px_b(pixel)) / 255.0,
    Float::from_int(px_a(pixel)) / 255.0,
  )
}

///|
fn from_normalized(c : Float) -> Int {
  f32_to_u8(f32_bound(0.0, c, 1.0) * 255.0)
}
