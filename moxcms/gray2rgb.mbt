// Port of `moxcms::conversions::gray2rgb`.

///|
/// `make_gray_to_x` (`TransformGray2RgbFusedExecutor`).
fn[T : Sample] make_gray_to_x(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  gray_linear : FixedArray[Float],
  gray_gamma : FixedArray[Float],
) -> Kernel[T] raise CmsError {
  if src_layout != Gray && src_layout != GrayAlpha {
    raise UnsupportedProfileConnection
  }
  let fused_gamma = FixedArray::make(65536, Float::from_int(0))
  let max_lut_size = Float::from_int(depth.gamma_cap - 1)
  let max_lut_size_u32 = @pxfm.f32_as_u32(max_lut_size)
  for i in 0..<@cmp.minimum(gray_linear.length(), 65536) {
    let src = gray_linear[i]
    let r = @pxfm.f32_as_u32(@pxfm.round_f32(src * max_lut_size))
    let possible_value = (if r < max_lut_size_u32 {
        r
      } else {
        max_lut_size_u32
      }).to_int() &
      0xffff
    fused_gamma[i] = gray_gamma[possible_value]
  }
  guard dst_layout is (Rgb | Rgba | Gray | GrayAlpha) else {
    raise UnsupportedProfileConnection
  }
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  let is_gray_alpha = src_layout == GrayAlpha
  (src, dst) => {
    check_lanes(src.length(), src_channels, dst.length(), dst_channels)
    let max_value : T = T::max_colors()
    let n = src.length() / src_channels
    for p in 0..<n {
      let s = p * src_channels
      let d = p * dst_channels
      let g = T::from_table(fused_gamma[src[s].as_usize()])
      let a = if is_gray_alpha { src[s + 1] } else { max_value }
      dst[d] = g
      if dst_layout == GrayAlpha {
        dst[d + 1] = a
      } else if dst_layout == Rgb {
        dst[d + 1] = g
        dst[d + 2] = g
      } else if dst_layout == Rgba {
        dst[d + 1] = g
        dst[d + 2] = g
        dst[d + 3] = a
      }
    }
  }
}

///|
/// `make_gray_to_unfused` (`TransformGrayToRgbExecutor`).
fn[T : Sample] make_gray_to_unfused(
  depth : Depth,
  src_layout : Layout,
  dst_layout : Layout,
  gray_linear : FixedArray[Float],
  red_gamma : FixedArray[Float],
  green_gamma : FixedArray[Float],
  blue_gamma : FixedArray[Float],
) -> Kernel[T] raise CmsError {
  if src_layout != Gray && src_layout != GrayAlpha {
    raise UnsupportedProfileConnection
  }
  if dst_layout != Rgb && dst_layout != Rgba {
    raise UnsupportedProfileConnection
  }
  let src_channels = src_layout.channels()
  let dst_channels = dst_layout.channels()
  let is_gray_alpha = src_layout == GrayAlpha
  let max_lut_size = Float::from_int(depth.gamma_cap - 1)
  (src, dst) => {
    check_lanes(src.length(), src_channels, dst.length(), dst_channels)
    let max_value : T = T::max_colors()
    let n = src.length() / src_channels
    for p in 0..<n {
      let s = p * src_channels
      let d = p * dst_channels
      let g = gray_linear[src[s].as_usize()]
      let a = if is_gray_alpha { src[s + 1] } else { max_value }
      let possible_value = @pxfm.f32_as_u16(@pxfm.round_f32(g * max_lut_size))
      dst[d] = T::from_table(red_gamma[possible_value])
      dst[d + 1] = T::from_table(green_gamma[possible_value])
      dst[d + 2] = T::from_table(blue_gamma[possible_value])
      if dst_layout == Rgba {
        dst[d + 3] = a
      }
    }
  }
}
