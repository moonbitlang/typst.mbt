// Port of `moxcms::conversions::{mab, mab4x3}` (lutAtoBType / lutBtoAType
// pipelines) for the default (`Linear`) interpolation.

///|
let mab_lerp_depth : Int = 65536

///|
let mab_depth : Int = 8192

///|
/// `T = u16`, `BIT_DEPTH = 13` for the A/M/B curve tables.
let depth_u16_13 : Depth = {
  finite: true,
  bit_depth: 13,
  linear_cap: 65536,
  gamma_cap: 0,
}

///|
fn build_curve_tables(
  curves : Array[ToneReprCurve],
) -> Array[FixedArray[Float]] raise CmsError {
  curves.map(c => {
    guard c.build_linearize_table(depth_u16_13, mab_lerp_depth) is Some(t) else {
      raise InvalidTrcCurve
    }
    t
  })
}

///|
/// `(v * scale_value).round().min(scale_value) as u16`
fn curve_index(v : Float, scale_value : Float) -> Int {
  @pxfm.f32_as_u16(@pxfm.min_f32(@pxfm.round_f32(v * scale_value), scale_value))
}

///|
/// `MCurves3::execute_matrix_stage`.
fn execute_matrix_stage(
  m : Matrix3f,
  b : Vector3f,
  dst : FixedArray[Float],
) -> Unit {
  if !m.test_equality(Matrix3f::identity()) ||
    b != (Default::default() : Vector3f) {
    let n = dst.length() / 3
    for p in 0..<n {
      let x = dst[3 * p]
      let y = dst[3 * p + 1]
      let z = dst[3 * p + 2]
      dst[3 * p] = mlaf(
        mlaf(mlaf(b.v0, x, m.at(0, 0)), y, m.at(0, 1)),
        z,
        m.at(0, 2),
      )
      dst[3 * p + 1] = mlaf(
        mlaf(mlaf(b.v1, x, m.at(1, 0)), y, m.at(1, 1)),
        z,
        m.at(1, 2),
      )
      dst[3 * p + 2] = mlaf(
        mlaf(mlaf(b.v2, x, m.at(2, 0)), y, m.at(2, 1)),
        z,
        m.at(2, 2),
      )
    }
  }
}

///|
/// Applies three curve tables (`BCurves3` / the curve part of `MCurves3`).
fn apply_curves3(
  curves : Array[FixedArray[Float]],
  dst : FixedArray[Float],
) -> Unit {
  let scale_value = Float::from_int(mab_depth - 1)
  let n = dst.length() / 3
  for p in 0..<n {
    let a0 = curve_index(dst[3 * p], scale_value)
    let a1 = curve_index(dst[3 * p + 1], scale_value)
    let a2 = curve_index(dst[3 * p + 2], scale_value)
    dst[3 * p] = curves[0][a0]
    dst[3 * p + 1] = curves[1][a1]
    dst[3 * p + 2] = curves[2][a2]
  }
}

///|
/// `MCurves3::transform`.
fn m_curves3(
  curves : Array[FixedArray[Float]],
  matrix : Matrix3f,
  bias : Vector3f,
  inverse : Bool,
  dst : FixedArray[Float],
) -> Unit {
  if inverse {
    execute_matrix_stage(matrix, bias, dst)
  }
  apply_curves3(curves, dst)
  if !inverse {
    execute_matrix_stage(matrix, bias, dst)
  }
}

///|
fn all_curves_linear(curves : Array[ToneReprCurve]) -> Bool {
  curves.iter().all(c => c.is_linear())
}

///|
fn apply_m_curves(
  mab : LutMultidimensionalType,
  lut : FixedArray[Float],
  inverse : Bool,
) -> Unit raise CmsError {
  if mab.m_curves.length() == 3 {
    if !all_curves_linear(mab.m_curves) ||
      !mab.matrix.test_equality(Matrix3d::identity()) ||
      mab.bias != (Default::default() : Vector3d) {
      let curves = build_curve_tables(mab.m_curves)
      let matrix = mab.matrix.to_f32()
      let bias = mab.bias.cast()
      m_curves3(curves, matrix, bias, inverse, lut)
    }
  }
}

///|
fn apply_b_curves(
  mab : LutMultidimensionalType,
  lut : FixedArray[Float],
) -> Unit raise CmsError {
  if mab.b_curves.length() == 3 {
    if !all_curves_linear(mab.b_curves) {
      let curves = build_curve_tables(mab.b_curves)
      apply_curves3(curves, lut)
    }
  } else {
    raise InvalidAtoBLut
  }
}

///|
fn prepare_mab_4x3(
  mab : LutMultidimensionalType,
  lut : FixedArray[Float],
  pcs : DataColorSpace,
) -> FixedArray[Float] raise CmsError {
  if mab.num_input_channels != 4 || mab.num_output_channels != 3 {
    raise UnsupportedProfileConnection
  }
  ignore(pcs)
  let new_lut = FixedArray::make(lut.length() / 4 * 3, Float::from_int(0))
  if mab.a_curves.length() == 4 && mab.clut is Some(clut_store) {
    let clut = clut_store.to_clut_f32()
    let gp = mab.grid_points
    let lut_grid = gp[0] * gp[1] * gp[2] * gp[3] * mab.num_output_channels
    if clut.length() != lut_grid {
      raise MalformedClut({ size: clut.length(), expected: lut_grid, })
    }
    let grid_size : FixedArray[Int] = [gp[0], gp[1], gp[2], gp[3]]
    let n = lut.length() / 4
    if all_curves_linear(mab.a_curves) {
      // `ACurves4x3Optimized`
      let hypercube = Hypercube::new_hypercube(clut, grid_size, 3)
      for p in 0..<n {
        let r = hypercube.quadlinear_vec3(
          lut[4 * p],
          lut[4 * p + 1],
          lut[4 * p + 2],
          lut[4 * p + 3],
        )
        new_lut[3 * p] = r.0
        new_lut[3 * p + 1] = r.1
        new_lut[3 * p + 2] = r.2
      }
    } else {
      // `ACurves4x3`
      let curves = build_curve_tables(mab.a_curves)
      let hypercube = Hypercube::new_hypercube(clut, grid_size, 3)
      let scale_value = Float::from_int(mab_depth - 1)
      for p in 0..<n {
        let c = curves[0][curve_index(lut[4 * p], scale_value)]
        let m = curves[1][curve_index(lut[4 * p + 1], scale_value)]
        let y = curves[2][curve_index(lut[4 * p + 2], scale_value)]
        let k = curves[3][curve_index(lut[4 * p + 3], scale_value)]
        let r = hypercube.quadlinear_vec3(c, m, y, k)
        new_lut[3 * p] = r.0
        new_lut[3 * p + 1] = r.1
        new_lut[3 * p + 2] = r.2
      }
    }
  } else {
    // Not supported
    raise UnsupportedProfileConnection
  }
  apply_m_curves(mab, new_lut, false)
  apply_b_curves(mab, new_lut)
  new_lut
}

///|
/// `ACurves3` / `ACurves3Optimized` / `ACurves3Inverse` with trilinear
/// interpolation.
fn apply_a_curves3(
  mab : LutMultidimensionalType,
  lut : FixedArray[Float],
  inverse : Bool,
) -> Unit raise CmsError {
  if mab.a_curves.length() == 3 && mab.clut is Some(clut_store) {
    let clut = clut_store.to_clut_f32()
    let gp = mab.grid_points
    let lut_grid = gp[0] * gp[1] * gp[2] * mab.num_output_channels
    if clut.length() != lut_grid {
      raise MalformedCurveLutTable({ size: clut.length(), expected: lut_grid, })
    }
    let grid_size : FixedArray[Int] = [gp[0], gp[1], gp[2]]
    let n = lut.length() / 3
    if all_curves_linear(mab.a_curves) {
      let cube = Cube::new_cube(clut, grid_size, 3)
      for p in 0..<n {
        let r = cube.trilinear_vec3(lut[3 * p], lut[3 * p + 1], lut[3 * p + 2])
        lut[3 * p] = r.0
        lut[3 * p + 1] = r.1
        lut[3 * p + 2] = r.2
      }
    } else {
      let curves = build_curve_tables(mab.a_curves)
      let cube = Cube::new_cube(clut, grid_size, 3)
      let scale_value = Float::from_int(mab_depth - 1)
      for p in 0..<n {
        if inverse {
          let r = cube.trilinear_vec3(
            lut[3 * p],
            lut[3 * p + 1],
            lut[3 * p + 2],
          )
          lut[3 * p] = curves[0][curve_index(r.0, scale_value)]
          lut[3 * p + 1] = curves[1][curve_index(r.1, scale_value)]
          lut[3 * p + 2] = curves[2][curve_index(r.2, scale_value)]
        } else {
          let b0 = curves[0][curve_index(lut[3 * p], scale_value)]
          let b1 = curves[1][curve_index(lut[3 * p + 1], scale_value)]
          let b2 = curves[2][curve_index(lut[3 * p + 2], scale_value)]
          let r = cube.trilinear_vec3(b0, b1, b2)
          lut[3 * p] = r.0
          lut[3 * p + 1] = r.1
          lut[3 * p + 2] = r.2
        }
      }
    }
  }
}

///|
fn prepare_mab_3x3(
  mab : LutMultidimensionalType,
  lut : FixedArray[Float],
  pcs : DataColorSpace,
) -> Unit raise CmsError {
  if mab.num_input_channels != 3 || mab.num_output_channels != 3 {
    raise UnsupportedProfileConnection
  }
  ignore(pcs)
  apply_a_curves3(mab, lut, false)
  apply_m_curves(mab, lut, false)
  apply_b_curves(mab, lut)
}

///|
fn prepare_mba_3x3(
  mab : LutMultidimensionalType,
  lut : FixedArray[Float],
  pcs : DataColorSpace,
) -> Unit raise CmsError {
  if mab.num_input_channels != 3 || mab.num_output_channels != 3 {
    raise UnsupportedProfileConnection
  }
  ignore(pcs)
  apply_b_curves(mab, lut)
  apply_m_curves(mab, lut, true)
  apply_a_curves3(mab, lut, true)
}
