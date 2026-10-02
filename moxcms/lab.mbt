// Port of `moxcms::lab` (PCS Lab -> XYZ) and
// `moxcms::conversions::xyz_lab::StageLabToXyz`.

///|
/// `Chromaticity::D50.to_xyz()` (computed in `f32`).
fn d50_xyz() -> (Float, Float, Float) {
  let x : Float = Float::from_double(0.34567)
  let y : Float = Float::from_double(0.35850)
  let reciprocal = if y != 0.0 { Float::from_int(1) / y } else { 0.0 }
  (x * reciprocal, 1.0, (Float::from_int(1) - x - y) * reciprocal)
}

///|
fn lab_f_1(t : Float) -> Float {
  if t <= Float::from_double(24.0) / Float::from_double(116.0) {
    Float::from_double(108.0) /
    Float::from_double(841.0) *
    (t - Float::from_double(16.0) / Float::from_double(116.0))
  } else {
    t * t * t
  }
}

///|
/// Converts CIE Lab into CIE XYZ for PCS encoding (`Lab::to_pcs_xyz`).
fn lab_to_pcs_xyz(l : Float, a : Float, b : Float) -> (Float, Float, Float) {
  let device_l = l * 100.0
  let device_a = fmla(a, 255.0, -128.0)
  let device_b = fmla(b, 255.0, -128.0)
  let y = (device_l + 16.0) / 116.0
  let (wp_x, wp_y, wp_z) = d50_xyz()
  let x = lab_f_1(mlaf(y, 0.002, device_a)) * wp_x
  let y1 = lab_f_1(y) * wp_y
  let z = lab_f_1(mlaf(y, -0.005, device_b)) * wp_z
  let scale = 1.0 + 32767.0 / 32768.0
  (
    Float::from_double(x.to_double() / scale),
    Float::from_double(y1.to_double() / scale),
    Float::from_double(z.to_double() / scale),
  )
}

///|
/// `StageLabToXyz::transform`.
fn stage_lab_to_xyz(dst : FixedArray[Float]) -> Unit {
  let n = dst.length() / 3
  for p in 0..<n {
    let (x, y, z) = lab_to_pcs_xyz(dst[3 * p], dst[3 * p + 1], dst[3 * p + 2])
    dst[3 * p] = x
    dst[3 * p + 1] = y
    dst[3 * p + 2] = z
  }
}
