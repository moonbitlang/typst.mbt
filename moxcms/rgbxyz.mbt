// Port of `moxcms::conversions::{rgbxyz, rgbxyz_fixed, rgb_xyz_factory}` and
// the aarch64 executors `neon::{rgb_xyz, rgb_xyz_q2_13_opt,
// rgb_xyz_q1_30_opt}` (emulated lane by lane).

///|
priv struct TransformMatrixShaper {
  r_linear : FixedArray[Float]
  g_linear : FixedArray[Float]
  b_linear : FixedArray[Float]
  r_gamma : FixedArray[Float]
  g_gamma : FixedArray[Float]
  b_gamma : FixedArray[Float]
  adaptation_matrix : Matrix3f
}

///|
/// Low memory footprint optimized routine for matrix shaper profiles with the
/// same Gamma and linear curves.
priv struct TransformMatrixShaperOptimized {
  linear : FixedArray[Float]
  gamma : FixedArray[Float]
  adaptation_matrix : Matrix3f
}

///|
/// Saturating `f32 as i16`.
fn f32_to_i16(v : Float) -> Int {
  @pxfm.f32_as_i16(v)
}

///|
/// `RgbXyzFactoryOpt::make_optimized_transform` for `u8` and `f32` with
/// `prefer_fixed_point` on aarch64 (`rdm` available).
fn[T : Sample] make_optimized_transform(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  profile : TransformMatrixShaperOptimized,
  options : TransformOptions,
) -> Kernel[T] raise CmsError {
  guard options.prefer_fixed_point else {
    // `make_rgb_xyz_rgb_transform_opt` (`neon_shaper_optimized_paths` is not a
    // default feature, so this is the scalar executor).
    return make_rgb_xyz_rgb_transform_opt_scalar(
      depth, src_layout, dst_layout, profile,
    )
  }
  if depth.finite {
    make_rgb_xyz_q2_13_opt(depth, src_layout, dst_layout, profile)
  } else {
    make_rgb_xyz_q1_30_opt(depth, src_layout, dst_layout, profile)
  }
}

///|
fn check_rgb_layouts(
  src_layout : Layout,
  dst_layout : Layout,
) -> Unit raise CmsError {
  if !((src_layout == Rgb || src_layout == Rgba) &&
    (dst_layout == Rgb || dst_layout == Rgba)) {
    raise UnsupportedProfileConnection
  }
}

///|
/// `TransformShaperQ2_13NeonOpt` (8-bit Q2.13 fixed point).
fn[T : Sample] make_rgb_xyz_q2_13_opt(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  profile : TransformMatrixShaperOptimized,
) -> Kernel[T] raise CmsError {
  let precision = 13
  let gamma_lut = depth.gamma_cap
  let bit_depth = depth.bit_depth
  // `to_q2_13_i`
  let linear_scale = if depth.finite {
    let lut_scale = Float::from_int(gamma_lut - 1) /
      Float::from_int((1 << bit_depth) - 1)
    Float::from_int((1 << bit_depth) - 1) * lut_scale
  } else {
    let lut_scale = Float::from_int(gamma_lut - 1) /
      Float::from_int(not_finite_linear_table_size - 1)
    Float::from_int(not_finite_linear_table_size - 1) * lut_scale
  }
  let linear = profile.linear.map(x => {
    f32_to_i16(@pxfm.round_f32(x * linear_scale))
  })
  let scale = Float::from_int(1 << precision)
  let m = profile.adaptation_matrix.v.map(x => f32_to_i16(x * scale))
  check_rgb_layouts(src_layout, dst_layout)
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  let gamma = profile.gamma
  let v_max_value = gamma_lut - 1
  let rnd = 1 << (precision - 1)
  (src, dst) => {
    check_lanes(src.length(), src_channels, dst.length(), dst_channels)
    let max_colors : T = T::max_colors()
    let n = src.length() / src_channels
    for p in 0..<n {
      let s = p * src_channels
      let d = p * dst_channels
      let r = linear[src[s].as_usize()]
      let g = linear[src[s + 1].as_usize()]
      let b = linear[src[s + 2].as_usize()]
      let a = if src_channels == 4 { src[s + 3] } else { max_colors }
      for i in 0..<3 {
        // vmlal_s16(rnd, r, m0) + g * m1 + b * m2 (i32 accumulation)
        let acc = rnd + r * m[3 * i] + g * m[3 * i + 1] + b * m[3 * i + 2]
        // vqshrun_n_s32::<13>
        let mut v = acc >> precision
        v = if v < 0 { 0 } else if v > 65535 { 65535 } else { v }
        // vmin_u16
        if v > v_max_value {
          v = v_max_value
        }
        dst[d + i] = T::from_table(gamma[v])
      }
      if dst_channels == 4 {
        dst[d + 3] = a
      }
    }
  }
}

///|
/// NEON `SQRDMLAH` on one 32-bit lane: saturate((acc << 32) + 2 * a * b +
/// 2^31) >> 32.
fn qrdmlah_s32(acc : Int, a : Int, b : Int) -> Int {
  let r = acc.to_int64() + ((a.to_int64() * b.to_int64() + (1L << 30)) >> 31)
  if r > 2147483647L {
    2147483647
  } else if r < -2147483648L {
    -2147483648
  } else {
    r.to_int()
  }
}

///|
/// `TransformShaperQ1_30NeonOpt` (Q1.30 fixed point, used for `f32`).
fn[T : Sample] make_rgb_xyz_q1_30_opt(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  profile : TransformMatrixShaperOptimized,
) -> Kernel[T] raise CmsError {
  let precision = 30
  let gamma_lut = depth.gamma_cap
  let bit_depth = depth.bit_depth
  // `to_q1_30_n`: it is important to scale 1 bit more to compensate vqrdmlah
  // Q0.31, because we're going to use Q1.30
  let table_size = if depth.finite {
    (1 << bit_depth) - 1
  } else {
    not_finite_linear_table_size - 1
  }
  let ext_bp = if depth.finite {
    bit_depth + 1
  } else {
    (not_finite_linear_table_size - 1).popcnt() + 1
  }
  let linear_scale = {
    let lut_scale = (gamma_lut - 1).to_double() / table_size.to_double()
    ((1 << ext_bp) - 1).to_double() * lut_scale
  }
  let linear = profile.linear.map(v => {
    @pxfm.f64_as_i32(@pxfm.round_f64(v.to_double() * linear_scale))
  })
  let scale = (1L << precision).to_double()
  let m = profile.adaptation_matrix.v.map(x => {
    @pxfm.f64_as_i32(x.to_double() * scale)
  })
  check_rgb_layouts(src_layout, dst_layout)
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  let gamma = profile.gamma
  let v_max_value = gamma_lut - 1
  (src, dst) => {
    check_lanes(src.length(), src_channels, dst.length(), dst_channels)
    let max_colors : T = T::max_colors()
    let n = src.length() / src_channels
    for p in 0..<n {
      let s = p * src_channels
      let d = p * dst_channels
      let r = linear[src[s].as_usize()]
      let g = linear[src[s + 1].as_usize()]
      let b = linear[src[s + 2].as_usize()]
      let a = if src_channels == 4 { src[s + 3] } else { max_colors }
      for i in 0..<3 {
        // vqrdmulhq_s32(r, m0), then vqrdmlahq_s32 for g and b
        let v0 = qrdmlah_s32(0, r, m[3 * i])
        let v1 = qrdmlah_s32(v0, g, m[3 * i + 1])
        let vr = qrdmlah_s32(v1, b, m[3 * i + 2])
        // vqmovun_s32
        let mut v = if vr < 0 { 0 } else if vr > 65535 { 65535 } else { vr }
        // vmin_u16
        if v > v_max_value {
          v = v_max_value
        }
        dst[d + i] = T::from_table(gamma[v])
      }
      if dst_channels == 4 {
        dst[d + 3] = a
      }
    }
  }
}

///|
/// NEON `FMIN` (propagates NaN).
fn fmin_neon(a : Float, b : Float) -> Float {
  if a.is_nan() || b.is_nan() {
    Float::from_double(0.0 / 0.0)
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// NEON `FCVTAU` (round to nearest with ties away from zero, saturating to
/// `u32`, NaN to 0).
fn fcvtau_u32(v : Float) -> Int64 {
  @pxfm.f32_as_u32(@pxfm.round_f32(v))
}

///|
/// `make_rgb_xyz_rgb_transform` with the aarch64 `TransformShaperRgbNeon`
/// executor (used when the curves differ).
fn[T : Sample] make_rgb_xyz_rgb_transform(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  profile : TransformMatrixShaper,
) -> Kernel[T] raise CmsError {
  check_rgb_layouts(src_layout, dst_layout)
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  let m = profile.adaptation_matrix.v
  let scale = Float::from_int(depth.gamma_cap - 1)
  let r_lin = profile.r_linear
  let g_lin = profile.g_linear
  let b_lin = profile.b_linear
  let gammas : ReadOnlyArray[_] = [
    profile.r_gamma,
    profile.g_gamma,
    profile.b_gamma,
  ]
  (src, dst) => {
    check_lanes(src.length(), src_channels, dst.length(), dst_channels)
    let max_colors : T = T::max_colors()
    let n = src.length() / src_channels
    for p in 0..<n {
      let s = p * src_channels
      let d = p * dst_channels
      let r = r_lin[src[s].as_usize()]
      let g = g_lin[src[s + 1].as_usize()]
      let b = b_lin[src[s + 2].as_usize()]
      let a = if src_channels == 4 { src[s + 3] } else { max_colors }
      for i in 0..<3 {
        let v0 = r * m[3 * i]
        let v1 = @pxfm.fmaf(g, m[3 * i + 1], v0)
        let mut v = @pxfm.fmaf(b, m[3 * i + 2], v1)
        v = @pxfm.fmaf(v, scale, 0.5)
        v = fmin_neon(v, scale)
        let idx = (fcvtau_u32(v) & 0xffffL).to_int()
        dst[d + i] = T::from_table(gammas[i][idx])
      }
      if dst_channels == 4 {
        dst[d + 3] = a
      }
    }
  }
}

///|
/// `TransformMatrixShaperOptScalar` (only used without `prefer_fixed_point`).
fn[T : Sample] make_rgb_xyz_rgb_transform_opt_scalar(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  profile : TransformMatrixShaperOptimized,
) -> Kernel[T] raise CmsError {
  check_rgb_layouts(src_layout, dst_layout)
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  let m = profile.adaptation_matrix.v
  let scale = Float::from_int(depth.gamma_cap - 1)
  let linear = profile.linear
  let gamma = profile.gamma
  (src, dst) => {
    check_lanes(src.length(), src_channels, dst.length(), dst_channels)
    let max_colors : T = T::max_colors()
    let n = src.length() / src_channels
    for p in 0..<n {
      let s = p * src_channels
      let d = p * dst_channels
      let r = linear[src[s].as_usize()]
      let g = linear[src[s + 1].as_usize()]
      let b = linear[src[s + 2].as_usize()]
      let a = if src_channels == 4 { src[s + 3] } else { max_colors }
      for i in 0..<3 {
        let v = mlaf(mlaf(r * m[3 * i], g, m[3 * i + 1]), b, m[3 * i + 2])
        let new_v = mlaf(0.5, @pxfm.min_f32(@pxfm.max_f32(v, 0.0), 1.0), scale)
        dst[d + i] = T::from_table(gamma[@pxfm.f32_as_u16(new_v)])
      }
      if dst_channels == 4 {
        dst[d + 3] = a
      }
    }
  }
}
