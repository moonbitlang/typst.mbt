// Port of `hayro-jpeg2000/src/j2c/mct.rs`: the irreversible multi-component
// transformation, as specified in Annex G.2 and G.3.

///|
/// Apply the inverse multi-component transform, as specified in G.2 and G.3.
fn mct_apply_inverse(
  components : Array[ComponentData],
  component_infos : Array[ComponentInfo],
  header : Header,
) -> Unit raise DecodeError {
  if components.length() < 3 {
    return if header.strict { raise Color(Mct) } else { () }
  }
  let s0 = components[0]
  let s1 = components[1]
  let s2 = components[2]
  let transform = component_infos[0].wavelet_transform()
  if transform != component_infos[1].wavelet_transform() ||
    component_infos[1].wavelet_transform() !=
    component_infos[2].wavelet_transform() {
    raise Color(Mct)
  }
  if s0.container.len() != s1.container.len() ||
    s1.container.len() != s2.container.len() {
    raise Color(Mct)
  }
  apply_inner(
    transform,
    s0.container.data,
    s1.container.data,
    s2.container.data,
  )
}

///|
/// The `f32x8` code over `chunks_exact_mut(8)`, lane by lane.
fn apply_inner(
  transform : WaveletTransform,
  s0 : FixedArray[Float],
  s1 : FixedArray[Float],
  s2 : FixedArray[Float],
) -> Unit {
  let len = s0.length() / 8 * 8
  // (The lengths are checked to be equal by the caller.)
  if s1.length() < len || s2.length() < len {
    abort("index out of bounds")
  }
  match transform {
    // Irreversible MCT, specified in G.3.
    Irreversible97 => {
      let c_1_402 = Float::reinterpret_from_uint(0x3FB374BC) // 1.402
      let c_m0_71414 = Float::reinterpret_from_uint(0xBF36D1E1) // -0.71414
      let c_m0_34413 = Float::reinterpret_from_uint(0xBEB031CF) // -0.34413
      let c_1_772 = Float::reinterpret_from_uint(0x3FE2D0E5) // 1.772
      for i in 0..<len {
        let y_0 = s0.unsafe_get(i)
        let y_1 = s1.unsafe_get(i)
        let y_2 = s2.unsafe_get(i)
        let i0 = fmaf(y_2, c_1_402, y_0)
        let i1 = fmaf(y_2, c_m0_71414, fmaf(y_1, c_m0_34413, y_0))
        let i2 = fmaf(y_1, c_1_772, y_0)
        s0.unsafe_set(i, i0)
        s1.unsafe_set(i, i1)
        s2.unsafe_set(i, i2)
      }
    }
    // Reversible MCT, specified in G.2.
    Reversible53 =>
      for i in 0..<len {
        let y_0 = s0.unsafe_get(i)
        let y_1 = s1.unsafe_get(i)
        let y_2 = s2.unsafe_get(i)
        let i1 = y_0 - floor_f32((y_2 + y_1) * 0.25)
        let i0 = y_2 + i1
        let i2 = y_1 + i1
        s0.unsafe_set(i, i0)
        s1.unsafe_set(i, i1)
        s2.unsafe_set(i, i2)
      }
  }
}
