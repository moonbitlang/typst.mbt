// Port of `moxcms::conversions::prelude_lut_xyz_rgb` and the `MatrixStage`
// of `lut_transforms`.

///|
/// `MatrixStage::transform`: applies the matrices in order.
fn matrix_stage(matrices : Array[Matrix3f], dst : FixedArray[Float]) -> Unit {
  let n = dst.length() / 3
  for m in matrices {
    for p in 0..<n {
      let x = dst[3 * p]
      let y = dst[3 * p + 1]
      let z = dst[3 * p + 2]
      dst[3 * p] = mlaf(mlaf(x * m.at(0, 0), y, m.at(0, 1)), z, m.at(0, 2))
      dst[3 * p + 1] = mlaf(mlaf(x * m.at(1, 0), y, m.at(1, 1)), z, m.at(1, 2))
      dst[3 * p + 2] = mlaf(mlaf(x * m.at(2, 0), y, m.at(2, 1)), z, m.at(2, 2))
    }
  }
}

///|
fn diagonal(v : Float) -> Matrix3f {
  { v: [v, 0.0, 0.0, 0.0, v, 0.0, 0.0, 0.0, v], }
}

///|
/// `XyzToRgbStage::transform`.
fn xyz_to_rgb_stage(
  depth : Depth,
  r_gamma : FixedArray[Float],
  g_gamma : FixedArray[Float],
  b_gamma : FixedArray[Float],
  matrices : Array[Matrix3f],
  dst : FixedArray[Float],
) -> Unit {
  matrix_stage(matrices, dst)
  let max_colors = (1 << depth.bit_depth) - 1
  let color_scale = Float::from_int(1) / Float::from_int(max_colors)
  let lut_cap = Float::from_int(depth.gamma_cap - 1)
  let n = dst.length() / 3
  for p in 0..<n {
    let idx = (v : Float) => {
      @pxfm.f32_as_u16(
        @pxfm.max_f32(@pxfm.min_f32(mlaf(0.5, v, lut_cap), lut_cap), 0.0),
      )
    }
    let r = idx(dst[3 * p])
    let g = idx(dst[3 * p + 1])
    let b = idx(dst[3 * p + 2])
    dst[3 * p] = r_gamma[r] * color_scale
    dst[3 * p + 1] = g_gamma[g] * color_scale
    dst[3 * p + 2] = b_gamma[b] * color_scale
  }
}

///|
fn create_rgb_lin_lut(
  depth : Depth,
  samples : Int,
  source : ColorProfile,
  opts : TransformOptions,
) -> FixedArray[Float] raise CmsError {
  let lin_r = source.build_r_linearize_table(
    depth,
    depth.linear_cap,
    opts.allow_use_cicp_transfer,
  )
  let lin_g = source.build_g_linearize_table(
    depth,
    depth.linear_cap,
    opts.allow_use_cicp_transfer,
  )
  let lin_b = source.build_b_linearize_table(
    depth,
    depth.linear_cap,
    opts.allow_use_cicp_transfer,
  )
  // `RgbLinearizationStage` on `create_lut3_samples::<T, SAMPLES>()`.
  let scale = if depth.finite {
    Float::from_int((1 << depth.bit_depth) - 1) /
    (Float::from_int(samples) - 1.0)
  } else {
    Float::from_int(not_finite_linear_table_size - 1) /
    (Float::from_int(samples) - 1.0)
  }
  let capped_value = if depth.finite {
    (1 << depth.bit_depth) - 1
  } else {
    not_finite_linear_table_size - 1
  }
  let lut = FixedArray::make(
    3 * samples * samples * samples,
    Float::from_int(0),
  )
  let lookup = (table : FixedArray[Float], v : Int) => {
    // `src.as_() as f32`: the integer sample converted to `T` and back.
    let t = if depth.finite {
      Float::from_int(v & 0xff)
    } else {
      Float::from_int(v)
    }
    let j = t * scale
    table[@pxfm.f32_as_u16(
      @pxfm.min_f32(
        @pxfm.max_f32(@pxfm.round_f32(j), 0.0),
        Float::from_int(capped_value),
      ),
    )]
  }
  let mut i = 0
  for x in 0..<samples {
    for y in 0..<samples {
      for z in 0..<samples {
        lut[i] = lookup(lin_r, x)
        lut[i + 1] = lookup(lin_g, y)
        lut[i + 2] = lookup(lin_b, z)
        i += 3
      }
    }
  }
  let xyz_to_rgb = source.rgb_to_xyz_matrix()
  matrix_stage(
    [
      xyz_to_rgb.to_f32(),
      diagonal(Float::from_int(32768) / Float::from_int(65535)),
    ],
    lut,
  )
  lut
}

///|
fn prepare_inverse_lut_rgb_xyz(
  depth : Depth,
  dest : ColorProfile,
  lut : FixedArray[Float],
  options : TransformOptions,
) -> Unit raise CmsError {
  let gamma_map_r = dest.build_gamma_table(
    dest.red_trc,
    depth,
    depth.gamma_cap,
    options.allow_use_cicp_transfer,
  )
  let gamma_map_g = dest.build_gamma_table(
    dest.green_trc,
    depth,
    depth.gamma_cap,
    options.allow_use_cicp_transfer,
  )
  let gamma_map_b = dest.build_gamma_table(
    dest.blue_trc,
    depth,
    depth.gamma_cap,
    options.allow_use_cicp_transfer,
  )
  let xyz_to_rgb = dest.rgb_to_xyz_matrix().inverse()
  let matrices = [
    diagonal(Float::from_int(65535) / Float::from_int(32768)),
    xyz_to_rgb.to_f32(),
  ]
  xyz_to_rgb_stage(depth, gamma_map_r, gamma_map_g, gamma_map_b, matrices, lut)
}
