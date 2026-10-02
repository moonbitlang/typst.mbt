// Port of the painters of `vello_cpu/src/fine/`: `common/gradient/`,
// `lowp/gradient.rs`, `common/image.rs` and `lowp/image.rs`.
//
// Painters write `n` bytes (`n / 16` columns of 4 pixels, column major)
// into `buf` starting at `off`.

///|
/// `PosExt::splat_pos` for one lane: the position of row `row` in a column.
fn splat_pos_lane(pos : Float, y_advance : Float, row : Int) -> Float {
  madd(Float::from_int(row), y_advance, pos)
}

///|
/// Compute the gradient parameters of the first `len` pixels of the span.
fn calculate_t_vals(
  gradient : EncodedGradient,
  buf : FixedArray[Float],
  len : Int,
  start_x : Double,
  start_y : Double,
) -> Unit {
  let mut cur_pos = gradient.transform.apply(@kurbo.Point::new(start_x, start_y))
  let x_advances = (f32(gradient.x_advance.x), f32(gradient.x_advance.y))
  let y_advances = (f32(gradient.y_advance.x), f32(gradient.y_advance.y))
  let kind = gradient.kind
  let mut i = 0
  while i + 8 <= len {
    let px = f32(cur_pos.x)
    let py = f32(cur_pos.y)
    for col in 0..<2 {
      let pos_x = if col == 0 { px } else { px + x_advances.0 }
      let pos_y = if col == 0 { py } else { py + x_advances.1 }
      for row in 0..<4 {
        let x_pos = splat_pos_lane(pos_x, y_advances.0, row)
        let y_pos = splat_pos_lane(pos_y, y_advances.1, row)
        buf[i + col * 4 + row] = gradient_cur_pos(kind, x_pos, y_pos)
      }
    }
    cur_pos = @kurbo.Point::new(
      cur_pos.x + 2.0 * gradient.x_advance.x,
      cur_pos.y + 2.0 * gradient.x_advance.y,
    )
    i += 8
  }
}

///|
/// `SimdGradientKind::cur_pos` for one lane.
fn gradient_cur_pos(kind : EncodedKind, x_pos : Float, y_pos : Float) -> Float {
  match kind {
    Linear => x_pos
    Radial(Radial(bias~, scale~)) => {
      let radius = (x_pos * x_pos + y_pos * y_pos).sqrt()
      bias + radius * scale
    }
    Radial(Strip(scaled_r0_squared~)) => {
      let p1 = scaled_r0_squared - y_pos * y_pos
      if p1 < 0.0 {
        @float.not_a_number
      } else {
        x_pos + p1.sqrt()
      }
    }
    Radial(Focal(focal_data~, fp0~, fp1~)) => {
      let mut t = if focal_data.is_focal_on_circle() {
        x_pos + y_pos * y_pos / x_pos
      } else if focal_data.is_well_behaved() {
        (x_pos * x_pos + y_pos * y_pos).sqrt() - x_pos * fp0
      } else if focal_data.is_swapped() ||
        (1.0 : Float) - focal_data.f_focal_x < 0.0 {
        (-1.0 : Float) * (x_pos * x_pos - y_pos * y_pos).sqrt() - x_pos * fp0
      } else {
        (x_pos * x_pos - y_pos * y_pos).sqrt() - x_pos * fp0
      }
      if !focal_data.is_well_behaved() {
        // Radii < 0 should be masked out, too.
        if t <= 0.0 {
          t = @float.not_a_number
        }
      }
      if (1.0 : Float) - focal_data.f_focal_x < 0.0 {
        t = (-1.0 : Float) * t
      }
      if !focal_data.is_natively_focal() {
        t = t + fp1
      }
      if focal_data.is_swapped() {
        t = (1.0 : Float) - t
      }
      t
    }
  }
}

///|
/// `vcvtq_s32_f32` followed by `vcvtq_f32_s32`: the `fract` of
/// `fearless_simd` (`x - trunc(x)` through a saturating integer conversion).
fn simd_fract(x : Float) -> Float {
  x - Float::from_int(f32_as_i32(x))
}

///|
/// `apply_extend` for one lane.
fn gradient_apply_extend(val : Float, extend : Extend) -> Float {
  match extend {
    Pad => vmin(vmax(val, 0.0), 1.0)
    Repeat => simd_fract(val - val.floor())
    // See Skia's `SkRasterPipeline_opts.h`.
    Reflect => {
      let v1 = val - 1.0
      vmin(
        vmax((v1 - (2.0 : Float) * (v1 * 0.5).floor() - 1.0).abs(), 0.0),
        1.0,
      )
    }
  }
}

///|
/// The `u8` gradient painter (`lowp::gradient::GradientPainter`), assuming
/// that the gradient has no undefined positions.
fn paint_gradient_u8(
  gradient : EncodedGradient,
  t_vals : FixedArray[Float],
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let lut = gradient.u8_lut()
  let scale_factor = lut.scale
  let extend = gradient.extend
  let lut_u8 = lut.lut_u8
  // 64 bytes (16 pixels) per iteration.
  let mut p = 0
  while (p + 16) * 4 <= n {
    for k in 0..<16 {
      let t = gradient_apply_extend(t_vals[p + k], extend)
      let idx = f32_as_u32(t * scale_factor).reinterpret_as_int()
      let o = off + (p + k) * 4
      buf[o] = lut_u8[idx * 4]
      buf[o + 1] = lut_u8[idx * 4 + 1]
      buf[o + 2] = lut_u8[idx * 4 + 2]
      buf[o + 3] = lut_u8[idx * 4 + 3]
    }
    p += 16
  }
}

///|
/// The generic gradient painter (`common::gradient::GradientPainter`) used
/// for gradients with undefined positions, sampling the `f32` lookup table.
fn paint_gradient_f32_lut(
  gradient : EncodedGradient,
  t_vals : FixedArray[Float],
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let lut = gradient.f32_lut()
  let scale_factor = lut.scale
  let max_index = lut.len - 1
  let extend = gradient.extend
  let lut_f32 = lut.lut_f32
  // 32 bytes (8 pixels) per iteration.
  let mut p = 0
  while (p + 8) * 4 <= n {
    for k in 0..<8 {
      let pos = t_vals[p + k]
      let t = gradient_apply_extend(pos, extend)
      let valid = pos == pos
      let o = off + (p + k) * 4
      if valid {
        let index = f32_as_u32(t * scale_factor)
        let idx = if index.reinterpret_as_int() > max_index || index > 0x7FFFFFFFU {
          max_index
        } else {
          index.reinterpret_as_int()
        }
        for c in 0..<4 {
          buf[o + c] = unit_to_u8(lut_f32[idx * 4 + c]).to_byte()
        }
      } else {
        // Mask any potential NaN positions.
        for c in 0..<4 {
          buf[o + c] = b'\x00'
        }
      }
    }
    p += 8
  }
}

///|
/// Common data used by different image painters.
priv struct ImagePainterData {
  mut cur_pos : @kurbo.Point
  image : EncodedImage
  pixmap : Pixmap
  x_advances : (Float, Float)
  y_advances : (Float, Float)
  height : Float
  height_inv : Float
  width : Float
  width_inv : Float
  width_u32 : UInt
}

///|
fn ImagePainterData::new(
  image : EncodedImage,
  pixmap : Pixmap,
  start_x : Double,
  start_y : Double,
) -> ImagePainterData {
  let width = Float::from_int(pixmap.width)
  let height = Float::from_int(pixmap.height)
  let start_pos = image.transform.apply(@kurbo.Point::new(start_x, start_y))
  {
    cur_pos: start_pos,
    image,
    pixmap,
    x_advances: (f32(image.x_advance.x), f32(image.x_advance.y)),
    y_advances: (f32(image.y_advance.x), f32(image.y_advance.y)),
    width,
    height,
    width_inv: (1.0 : Float) / width,
    height_inv: (1.0 : Float) / height,
    width_u32: pixmap.width.reinterpret_as_uint(),
  }
}

///|
/// `sample` for one lane: the packed pixel at the (already extended)
/// position.
fn ImagePainterData::sample(self : ImagePainterData, x : Float, y : Float) -> UInt {
  let idx = f32_as_u32(x) + f32_as_u32(y) * self.width_u32
  self.pixmap.sample_idx(idx)
}

///|
/// `extend` for one lane.
fn image_extend(val : Float, extend : Extend, max : Float, inv_max : Float) -> Float {
  match extend {
    // Note that max should be exclusive, so subtract one to enforce that.
    Pad => vmax(vmin(val, max - 1.0), 0.0)
    Repeat =>
      // floor := (val * inv_max).floor() * max is the nearest multiple of
      // `max` below val.
      vmin(madd(max, -(val * inv_max).floor(), val), max - 1.0)
    Reflect => {
      let u = val - (val * inv_max * 0.5).floor() * 2.0 * max
      let s = (u * inv_max).floor()
      let m = u - (2.0 : Float) * s * (u - max)
      let bias_in_ulps = s.trunc()
      let m_bits = m.reinterpret_as_uint()
      // Note that this is a wrapping sub!
      let biased_bits = m_bits - f32_as_u32(bias_in_ulps)
      vmin(Float::reinterpret_from_uint(biased_bits), max - 1.0)
    }
  }
}

///|
/// Store a packed pixel at a byte offset.
fn store_pixel(buf : FixedArray[Byte], o : Int, px : UInt) -> Unit {
  buf[o] = (px & 0xFF).to_byte()
  buf[o + 1] = ((px >> 8) & 0xFF).to_byte()
  buf[o + 2] = ((px >> 16) & 0xFF).to_byte()
  buf[o + 3] = (px >> 24).to_byte()
}

///|
/// A painter for nearest-neighbor images with no skewing.
fn paint_plain_nn(
  image : EncodedImage,
  pixmap : Pixmap,
  start_x : Double,
  start_y : Double,
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let data = ImagePainterData::new(image, pixmap, start_x, start_y)
  let y_positions = FixedArray::make(4, (0.0 : Float))
  let cur_x_pos = FixedArray::make(4, (0.0 : Float))
  for r in 0..<4 {
    y_positions[r] = image_extend(
      splat_pos_lane(f32(data.cur_pos.y), data.y_advances.1, r),
      image.sampler.y_extend,
      data.height,
      data.height_inv,
    )
    cur_x_pos[r] = splat_pos_lane(f32(data.cur_pos.x), data.y_advances.0, r)
  }
  let advance = f32(image.x_advance.x)
  for col in 0..<(n / 16) {
    for r in 0..<4 {
      let x_pos = image_extend(
        cur_x_pos[r],
        image.sampler.x_extend,
        data.width,
        data.width_inv,
      )
      store_pixel(buf, off + col * 16 + r * 4, data.sample(x_pos, y_positions[r]))
      cur_x_pos[r] = cur_x_pos[r] + advance
    }
  }
}

///|
/// A painter for nearest-neighbor images with arbitrary transforms.
fn paint_nn(
  image : EncodedImage,
  pixmap : Pixmap,
  start_x : Double,
  start_y : Double,
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let data = ImagePainterData::new(image, pixmap, start_x, start_y)
  for col in 0..<(n / 16) {
    let px = f32(data.cur_pos.x)
    let py = f32(data.cur_pos.y)
    for r in 0..<4 {
      let x_pos = image_extend(
        splat_pos_lane(px, data.y_advances.0, r),
        image.sampler.x_extend,
        data.width,
        data.width_inv,
      )
      let y_pos = image_extend(
        splat_pos_lane(py, data.y_advances.1, r),
        image.sampler.y_extend,
        data.height,
        data.height_inv,
      )
      store_pixel(buf, off + col * 16 + r * 4, data.sample(x_pos, y_pos))
    }
    data.cur_pos = data.cur_pos.add_vec(image.x_advance)
  }
}

///|
/// Positive fractional part `val - val.floor()`.
fn fract_floor(val : Float) -> Float {
  val - val.floor()
}

///|
/// Bilinear interpolation of 4 packed pixels with `u8` weights
/// (`lowp::image`).
fn bilinear_u8(
  p00 : UInt,
  p10 : UInt,
  p01 : UInt,
  p11 : UInt,
  fx : Int,
  fy : Int,
  buf : FixedArray[Byte],
  o : Int,
) -> Unit {
  let fx_inv = (255 - fx) & 0xFFFF
  let fy_inv = (255 - fy) & 0xFFFF
  for c in 0..<4 {
    let sh = c * 8
    let c00 = ((p00 >> sh) & 0xFF).reinterpret_as_int()
    let c10 = ((p10 >> sh) & 0xFF).reinterpret_as_int()
    let c01 = ((p01 >> sh) & 0xFF).reinterpret_as_int()
    let c11 = ((p11 >> sh) & 0xFF).reinterpret_as_int()
    let ip1 = div_255((c00 * fx_inv + c10 * fx) & 0xFFFF)
    let ip2 = div_255((c01 * fx_inv + c11 * fx) & 0xFFFF)
    buf[o + c] = (div_255((ip1 * fy_inv + ip2 * fy) & 0xFFFF) & 0xFF).to_byte()
  }
}

///|
/// A faster bilinear image renderer for the u8 pipeline.
fn paint_bilinear(
  image : EncodedImage,
  pixmap : Pixmap,
  start_x : Double,
  start_y : Double,
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let data = ImagePainterData::new(image, pixmap, start_x, start_y)
  for col in 0..<(n / 16) {
    let px = f32(data.cur_pos.x)
    let py = f32(data.cur_pos.y)
    for r in 0..<4 {
      let x_position = splat_pos_lane(px, data.y_advances.0, r)
      let y_position = splat_pos_lane(py, data.y_advances.1, r)
      let fx = f32_to_u8_lane(madd(fract_floor(x_position + 0.5), 255.0, 0.5))
      let fy = f32_to_u8_lane(madd(fract_floor(y_position + 0.5), 255.0, 0.5))
      let x_pos1 = image_extend(
        x_position - 0.5,
        image.sampler.x_extend,
        data.width,
        data.width_inv,
      )
      let x_pos2 = image_extend(
        x_position + 0.5,
        image.sampler.x_extend,
        data.width,
        data.width_inv,
      )
      let y_pos1 = image_extend(
        y_position - 0.5,
        image.sampler.y_extend,
        data.height,
        data.height_inv,
      )
      let y_pos2 = image_extend(
        y_position + 0.5,
        image.sampler.y_extend,
        data.height,
        data.height_inv,
      )
      bilinear_u8(
        data.sample(x_pos1, y_pos1),
        data.sample(x_pos2, y_pos1),
        data.sample(x_pos1, y_pos2),
        data.sample(x_pos2, y_pos2),
        fx,
        fy,
        buf,
        off + col * 16 + r * 4,
      )
    }
    data.cur_pos = data.cur_pos.add_vec(image.x_advance)
  }
}

///|
/// A faster bilinear image renderer for axis-aligned images (no skew) in the
/// u8 pipeline.
fn paint_plain_bilinear(
  image : EncodedImage,
  pixmap : Pixmap,
  start_x : Double,
  start_y : Double,
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let data = ImagePainterData::new(image, pixmap, start_x, start_y)
  let y_pos1 = FixedArray::make(4, (0.0 : Float))
  let y_pos2 = FixedArray::make(4, (0.0 : Float))
  let fy = FixedArray::make(4, 0)
  let cur_x_pos = FixedArray::make(4, (0.0 : Float))
  for r in 0..<4 {
    // For axis-aligned images, y doesn't change across the strip.
    let y_position = splat_pos_lane(f32(data.cur_pos.y), data.y_advances.1, r)
    y_pos1[r] = image_extend(
      y_position - 0.5,
      image.sampler.y_extend,
      data.height,
      data.height_inv,
    )
    y_pos2[r] = image_extend(
      y_position + 0.5,
      image.sampler.y_extend,
      data.height,
      data.height_inv,
    )
    fy[r] = f32_to_u8_lane(madd(fract_floor(y_position + 0.5), 255.0, 0.5))
    cur_x_pos[r] = splat_pos_lane(f32(data.cur_pos.x), data.y_advances.0, r)
  }
  let advance = f32(image.x_advance.x)
  for col in 0..<(n / 16) {
    for r in 0..<4 {
      let x_minus_half = cur_x_pos[r] - 0.5
      let x_plus_half = cur_x_pos[r] + 0.5
      // Only x needs to be extended per-iteration.
      let x_pos1 = image_extend(
        x_minus_half,
        image.sampler.x_extend,
        data.width,
        data.width_inv,
      )
      let x_pos2 = image_extend(
        x_plus_half,
        image.sampler.x_extend,
        data.width,
        data.width_inv,
      )
      let fx = f32_to_u8_lane(madd(fract_floor(x_plus_half), 255.0, 0.5))
      bilinear_u8(
        data.sample(x_pos1, y_pos1[r]),
        data.sample(x_pos2, y_pos1[r]),
        data.sample(x_pos1, y_pos2[r]),
        data.sample(x_pos2, y_pos2[r]),
        fx,
        fy[r],
        buf,
        off + col * 16 + r * 4,
      )
      cur_x_pos[r] = cur_x_pos[r] + advance
    }
  }
}

///|
/// Cubic resampling coefficients (`mf_resampler`: Mitchell filter with
/// B = 1/3 and C = 1/3), computed with `f32` arithmetic like the upstream
/// `const fn`.
let mf : FixedArray[FixedArray[Float]] = {
  let b : Float = (1.0 : Float) / 3.0
  let c : Float = (1.0 : Float) / 3.0
  [
    [
      (1.0 : Float) / 6.0 * b,
      -((3.0 : Float) / 6.0) * b - c,
      (3.0 : Float) / 6.0 * b + (2.0 : Float) * c,
      -((1.0 : Float) / 6.0) * b - c,
    ],
    [
      (1.0 : Float) - (2.0 : Float) / 6.0 * b,
      0.0,
      (-3.0 : Float) + (12.0 : Float) / 6.0 * b + c,
      (2.0 : Float) - (9.0 : Float) / 6.0 * b - c,
    ],
    [
      (1.0 : Float) / 6.0 * b,
      (3.0 : Float) / 6.0 * b + c,
      (3.0 : Float) - (15.0 : Float) / 6.0 * b - (2.0 : Float) * c,
      (-2.0 : Float) + (9.0 : Float) / 6.0 * b + c,
    ],
    [0.0, 0.0, -c, (1.0 : Float) / 6.0 * b + c],
  ]
}

///|
/// Calculate a weight based on the fractional value t and the cubic
/// coefficients.
fn single_weight(t : Float, a : Float, b : Float, c : Float, d : Float) -> Float {
  madd(madd(madd(t, d, c), t, b), t, a)
}

///|
/// A painter for images with bicubic filtering (`FilteredImagePainter<2>`).
fn paint_bicubic(
  image : EncodedImage,
  pixmap : Pixmap,
  start_x : Double,
  start_y : Double,
  buf : FixedArray[Byte],
  off : Int,
  n : Int,
) -> Unit {
  let data = ImagePainterData::new(image, pixmap, start_x, start_y)
  let offsets : FixedArray[Float] = [-1.5, -0.5, 0.5, 1.5]
  let cx = FixedArray::make(4, (0.0 : Float))
  let cy = FixedArray::make(4, (0.0 : Float))
  let xs = FixedArray::make(4, (0.0 : Float))
  let ys = FixedArray::make(4, (0.0 : Float))
  let color = FixedArray::make(4, (0.0 : Float))
  for col in 0..<(n / 16) {
    let px = f32(data.cur_pos.x)
    let py = f32(data.cur_pos.y)
    for r in 0..<4 {
      let x_position = splat_pos_lane(px, data.y_advances.0, r)
      let y_position = splat_pos_lane(py, data.y_advances.1, r)
      let x_fract = fract_floor(x_position + 0.5)
      let y_fract = fract_floor(y_position + 0.5)
      for k in 0..<4 {
        cx[k] = single_weight(x_fract, mf[k][0], mf[k][1], mf[k][2], mf[k][3])
        cy[k] = single_weight(y_fract, mf[k][0], mf[k][1], mf[k][2], mf[k][3])
        // Note: upstream extends the x positions with the y extend.
        xs[k] = image_extend(
          x_position + offsets[k],
          image.sampler.y_extend,
          data.width,
          data.width_inv,
        )
        ys[k] = image_extend(
          y_position + offsets[k],
          image.sampler.y_extend,
          data.height,
          data.height_inv,
        )
      }
      color.fill(0.0)
      for x_idx in 0..<4 {
        for y_idx in 0..<4 {
          let s = data.sample(xs[x_idx], ys[y_idx])
          let w = cx[x_idx] * cy[y_idx]
          for c in 0..<4 {
            let v = Float::from_uint((s >> (c * 8)) & 0xFF)
            color[c] = madd(w, v, color[c])
          }
        }
      }
      for c in 0..<4 {
        color[c] = color[c] * ((1.0 : Float) / 255.0)
      }
      let alpha = color[3]
      let o = off + col * 16 + r * 4
      for c in 0..<4 {
        // Due to the nature of the cubic filter, a color component can end
        // up higher than the alpha component; clamp to the alpha value.
        let v = vmax(vmin(vmin(color[c], alpha), 1.0), 0.0)
        buf[o + c] = unit_to_u8(v).to_byte()
      }
    }
    data.cur_pos = data.cur_pos.add_vec(image.x_advance)
  }
}
