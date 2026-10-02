// Port of `moxcms::conversions::lut_transforms::make_lut_transform` (without
// the `any_to_any` feature) and the aarch64 `NeonLut4x3Factory` /
// `NeonLut3x3Factory`.
//
// Deviations: RGB/Lab -> CMYK (`make_transform_3x4`) and PCS XYZ -> Lab
// (`StageXyzToLab`, needs `f_cbrtf`) are not ported and raise
// `UnsupportedProfileConnection`; the LUT executors require
// `prefer_fixed_point` (the default).

///|
fn pcs_lab_v4_to_v2(profile : ColorProfile, lut : FixedArray[Float]) -> Unit {
  if profile.pcs == Lab &&
    profile.version_internal < V4_0 &&
    lut.length() % 3 == 0 {
    matrix_stage(
      [diagonal(Float::from_int(65280) / Float::from_int(65535))],
      lut,
    )
  }
}

///|
fn pcs_lab_v2_to_v4(profile : ColorProfile, lut : FixedArray[Float]) -> Unit {
  if profile.pcs == Lab &&
    profile.version_internal < V4_0 &&
    lut.length() % 3 == 0 {
    matrix_stage(
      [diagonal(Float::from_int(65535) / Float::from_int(65280))],
      lut,
    )
  }
}

///|
fn[T : Sample] make_lut_transform(
  depth : Depth,
  src_layout : Layout,
  source : ColorProfile,
  dst_layout : Layout,
  dest : ColorProfile,
  options : TransformOptions,
) -> Kernel[T] raise CmsError {
  if (source.color_space == Cmyk || source.color_space == Color4) &&
    (dest.color_space == Rgb || dest.color_space == Lab) {
    source.color_space.check_layout(src_layout)
    dest.color_space.check_layout(dst_layout)
    if source.pcs != Xyz && source.pcs != Lab {
      raise UnsupportedProfileConnection
    }
    if dest.pcs != Lab && dest.pcs != Xyz {
      raise UnsupportedProfileConnection
    }
    let grid_size = 17
    guard source.get_device_to_pcs(options.rendering_intent)
      is Some(device_to_pcs) else {
      raise UnsupportedLutRenderingIntent(source.rendering_intent)
    }
    let lut = match device_to_pcs {
      Lut(lut) => create_lut4(grid_size, lut, source.pcs)
      Multidimensional(m_curves) => {
        let samples = create_lut4_norm_samples(grid_size)
        prepare_mab_4x3(m_curves, samples, source.pcs)
      }
    }
    pcs_lab_v2_to_v4(source, lut)
    if source.pcs == Lab {
      stage_lab_to_xyz(lut)
    }
    if dest.pcs == Lab {
      // `StageXyzToLab` is not ported.
      raise UnsupportedProfileConnection
    }
    pcs_lab_v4_to_v2(dest, lut)
    if dest.pcs == Xyz {
      if dest.is_matrix_shaper() {
        prepare_inverse_lut_rgb_xyz(depth, dest, lut, options)
      } else {
        raise UnsupportedProfileConnection
      }
    }
    let is_dest_linear_profile = dest.color_space == Rgb &&
      dest.is_matrix_shaper() &&
      dest.is_linear_matrix_shaper()
    make_transformer_4x3(
      depth,
      grid_size,
      dst_layout,
      lut,
      options,
      dest.color_space,
      is_dest_linear_profile,
    )
  } else if (source.color_space == Rgb || source.color_space == Lab) &&
    (dest.color_space == Cmyk || dest.color_space == Color4) {
    source.color_space.check_layout(src_layout)
    dest.color_space.check_layout(dst_layout)
    if source.pcs != Xyz && source.pcs != Lab {
      raise UnsupportedProfileConnection
    }
    // `make_transform_3x4` is not ported.
    raise UnsupportedProfileConnection
  } else if source.color_space.is_three_channels() &&
    dest.color_space.is_three_channels() {
    source.color_space.check_layout(src_layout)
    dest.color_space.check_layout(dst_layout)
    let grid_size = 33
    let lut = if source.has_device_to_pcs_lut() {
      guard source.get_device_to_pcs(options.rendering_intent)
        is Some(device_to_pcs) else {
        raise UnsupportedProfileConnection
      }
      let lut = create_lut3_samples_norm(grid_size)
      match device_to_pcs {
        Lut(lut_data_type) => create_lut3x3(lut_data_type, lut, source.pcs)
        Multidimensional(mab) => {
          prepare_mab_3x3(mab, lut, source.pcs)
          lut
        }
      }
    } else if source.is_matrix_shaper() {
      create_rgb_lin_lut(depth, grid_size, source, options)
    } else {
      raise UnsupportedProfileConnection
    }
    pcs_lab_v2_to_v4(source, lut)
    if source.pcs == Xyz && dest.pcs == Lab {
      // `StageXyzToLab` is not ported.
      raise UnsupportedProfileConnection
    } else if source.pcs == Lab && dest.pcs == Xyz {
      stage_lab_to_xyz(lut)
    }
    pcs_lab_v4_to_v2(dest, lut)
    let lut = if dest.has_pcs_to_device_lut() {
      guard dest.get_pcs_to_device(options.rendering_intent)
        is Some(pcs_to_device) else {
        raise UnsupportedProfileConnection
      }
      match pcs_to_device {
        Lut(lut_data_type) => create_lut3x3(lut_data_type, lut, dest.pcs)
        Multidimensional(mab) => {
          prepare_mba_3x3(mab, lut, dest.pcs)
          lut
        }
      }
    } else if dest.is_matrix_shaper() {
      prepare_inverse_lut_rgb_xyz(depth, dest, lut, options)
      lut
    } else {
      raise UnsupportedProfileConnection
    }
    let is_dest_linear_profile = dest.color_space == Rgb &&
      dest.is_matrix_shaper() &&
      dest.is_linear_matrix_shaper()
    make_transformer_3x3(
      depth,
      grid_size,
      src_layout,
      dst_layout,
      lut,
      options,
      dest.color_space,
      is_dest_linear_profile,
    )
  } else {
    raise UnsupportedProfileConnection
  }
}

///|
/// Quantizes the LUT to Q0.15 (`NeonAlignedI16x4`): `(x * q).round() as i16`.
fn quantize_lut(depth : Depth, lut : FixedArray[Float]) -> FixedArray[Int] {
  let q = if depth.finite {
    Float::from_int((1 << depth.bit_depth) - 1)
  } else {
    Float::from_int((1 << 14) - 1)
  }
  lut.map(x => @pxfm.f32_as_i16(@pxfm.round_f32(x * q)))
}

///|
/// `NeonLut4x3Factory::make_transform_4x3` (Q0.15 path,
/// `TransformLut4To3NeonQ0_15`).
fn[T : Sample] make_transformer_4x3(
  depth : Depth,
  grid_size : Int,
  dst_layout : Layout,
  lut : FixedArray[Float],
  options : TransformOptions,
  color_space : DataColorSpace,
  is_linear : Bool,
) -> Kernel[T] raise CmsError {
  guard dst_layout is (Rgb | Rgba) else { abort("unimplemented") }
  guard options.prefer_fixed_point else { raise UnsupportedProfileConnection }
  // Every interpolation method is trilinear without the `options` feature.
  ignore(color_space)
  ignore(is_linear)
  let lut = quantize_lut(depth, lut)
  let weights = create_ranged_256_q0_15(grid_size)
  let channels = dst_layout.channels()
  let grid_size3 = grid_size * grid_size * grid_size
  let v_max_scale = if depth.finite {
    (1 << depth.bit_depth) - 1
  } else {
    (1 << 14) - 1
  }
  ignore(v_max_scale)
  (src, dst) => {
    if src.length() % 4 != 0 {
      raise LaneMultipleOfChannels
    }
    if dst.length() % channels != 0 {
      raise LaneMultipleOfChannels
    }
    let src_chunks = src.length() / 4
    let dst_chunks = dst.length() / channels
    if src_chunks != dst_chunks {
      raise LaneSizeMismatch
    }
    let max_value : T = T::max_colors()
    for p in 0..<src_chunks {
      let c = src[4 * p].reduce_u8()
      let m = src[4 * p + 1].reduce_u8()
      let y = src[4 * p + 2].reduce_u8()
      let k = src[4 * p + 3].reduce_u8()
      let k_weights = weights[k]
      let table1 = k_weights.x * grid_size3
      let table2 = k_weights.x_n * grid_size3
      let t = k_weights.w
      let d = p * channels
      for ch in 0..<3 {
        let a0 = trilinear_q0_15(lut, table1, grid_size, weights, c, m, y, ch)
        let b0 = trilinear_q0_15(lut, table2, grid_size, weights, c, m, y, ch)
        let hp = qrdmlsh_s16(a0, a0, t)
        let v = qrdmlah_s16(hp, b0, t)
        dst[d + ch] = T::from_q0_15(v)
      }
      if channels == 4 {
        dst[d + 3] = max_value
      }
    }
  }
}

///|
/// `NeonLut3x3Factory::make_transform_3x3` (Q0.15 path,
/// `TransformLut3x3NeonQ0_15`).
fn[T : Sample] make_transformer_3x3(
  depth : Depth,
  grid_size : Int,
  src_layout : Layout,
  dst_layout : Layout,
  lut : FixedArray[Float],
  options : TransformOptions,
  color_space : DataColorSpace,
  is_linear : Bool,
) -> Kernel[T] raise CmsError {
  guard src_layout is (Rgb | Rgba) && dst_layout is (Rgb | Rgba) else {
    abort("unimplemented")
  }
  guard options.prefer_fixed_point else { raise UnsupportedProfileConnection }
  ignore(color_space)
  ignore(is_linear)
  let lut = quantize_lut(depth, lut)
  let weights = create_ranged_256_q0_15(grid_size)
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  (src, dst) => {
    if src.length() % src_channels != 0 {
      raise LaneMultipleOfChannels
    }
    if dst.length() % dst_channels != 0 {
      raise LaneMultipleOfChannels
    }
    let src_chunks = src.length() / src_channels
    let dst_chunks = dst.length() / dst_channels
    if src_chunks != dst_chunks {
      raise LaneSizeMismatch
    }
    let max_value : T = T::max_colors()
    for p in 0..<src_chunks {
      let s = p * src_channels
      let x = src[s].reduce_u8()
      let y = src[s + 1].reduce_u8()
      let z = src[s + 2].reduce_u8()
      let a = if src_channels == 4 { src[s + 3] } else { max_value }
      let d = p * dst_channels
      for ch in 0..<3 {
        let v = trilinear_q0_15(lut, 0, grid_size, weights, x, y, z, ch)
        dst[d + ch] = T::from_q0_15(v)
      }
      if dst_channels == 4 {
        dst[d + 3] = a
      }
    }
  }
}
