// Port of `vello_common/src/rect.rs`: fast pixel-aligned rectangle rendering
// directly into strips.

///|
/// Generates strip data for an axis-aligned rectangle.
///
/// The rect bounds should already be clamped to the viewport.
fn render_rect(
  rect : @kurbo.Rect,
  strip_buf : Array[Strip],
  alpha_buf : Array[Byte],
) -> Unit {
  if rect.is_zero_area() {
    return
  }
  let rect_x0 = f32(rect.x0)
  let rect_y0 = f32(rect.y0)
  let rect_x1 = f32(rect.x1)
  let rect_y1 = f32(rect.y1)
  // Integer pixel bounds.
  let px_x0 = f32_as_u16(rect_x0.floor())
  let px_y0 = f32_as_u16(rect_y0.floor())
  let px_y1 = f32_as_u16(rect_y1.ceil())
  let left_tile_x = px_x0 / TILE_WIDTH * TILE_WIDTH
  // Inclusive, so don't use `ceil` here but just `rect_x1` directly.
  let right_tile_x = f32_as_u16(rect_x1) / TILE_WIDTH * TILE_WIDTH
  let y0 = px_y0 / TILE_HEIGHT * TILE_HEIGHT
  let y1 = u16_sat_add(px_y1, TILE_HEIGHT - 1) / TILE_HEIGHT * TILE_HEIGHT
  // Include one tile past the right edge so the right-edge tile column is
  // covered by the edge-row wide-strip loop.
  let x_end = u16_sat_add(right_tile_x, TILE_WIDTH)
  if x_end <= left_tile_x || y1 <= y0 {
    return
  }
  let tile_start_y = y0 / TILE_HEIGHT
  let tile_end_y = y1 / TILE_HEIGHT
  // A right strip is only needed when the rect spans more than one tile
  // column.
  let needs_right_strip = right_tile_x > left_tile_x
  let left_x_cov = rect_coverage(left_tile_x, rect_x0, rect_x1)
  let right_x_cov = rect_coverage(right_tile_x, rect_x0, rect_x1)
  let left_x_mask = alpha_mask_from_x_coverage(left_x_cov)
  let right_x_mask = alpha_mask_from_x_coverage(right_x_cov)
  for tile_y in tile_start_y..<tile_end_y {
    let strip_y = tile_y * TILE_HEIGHT
    let strip_y_f = Float::from_int(strip_y)
    let strip_y_end_f = Float::from_int(strip_y) + Float::from_int(TILE_HEIGHT)
    // A row is an "edge" if the rect's top or bottom boundary falls *inside*
    // it (i.e. partial vertical coverage).
    let is_top_edge = strip_y_f < rect_y0 && rect_y0 < strip_y_end_f
    let is_bottom_edge = strip_y_f < rect_y1 && rect_y1 < strip_y_end_f
    if is_top_edge || is_bottom_edge {
      let alpha_start = alpha_buf.length()
      let y_cov = rect_coverage(strip_y, rect_y0, rect_y1)
      let mut col = left_tile_x
      while col + TILE_WIDTH <= x_end {
        let x_cov = rect_coverage(col, rect_x0, rect_x1)
        for c in 0..<4 {
          for r in 0..<4 {
            alpha_buf.push(
              f32_as_u8(x_cov[c] * y_cov[r] * 255.0 + 0.5).to_byte(),
            )
          }
        }
        col += TILE_WIDTH
      }
      strip_buf.push(Strip::new(left_tile_x, strip_y, alpha_start, false))
    } else {
      let alpha_start = alpha_buf.length()
      for b in left_x_mask {
        alpha_buf.push(b)
      }
      strip_buf.push(Strip::new(left_tile_x, strip_y, alpha_start, false))
      if needs_right_strip {
        // `fill_gap = true` tells the renderer to fill solid 0xFF between the
        // previous strip's end and this strip's start.
        let alpha_start = alpha_buf.length()
        for b in right_x_mask {
          alpha_buf.push(b)
        }
        strip_buf.push(Strip::new(right_tile_x, strip_y, alpha_start, true))
      }
    }
  }
  // Sentinel strip: marks the end of the strip list for this shape.
  let last_strip_y = (tile_end_y - 1) * TILE_HEIGHT
  strip_buf.push(Strip::new(65535, last_strip_y, alpha_buf.length(), false))
}

///|
/// Compute fractional pixel coverage for 4 consecutive pixels starting at
/// `start`.
fn rect_coverage(
  start : Int,
  rect_lo : Float,
  rect_hi : Float,
) -> FixedArray[Float] {
  let cov = FixedArray::make(4, (0.0 : Float))
  for i in 0..<4 {
    let px = Float::from_int(start + i)
    cov[i] = fclamp(fminnm(rect_hi, px + 1.0) - fmaxnm(rect_lo, px), 0.0, 1.0)
  }
  cov
}

///|
/// Build an alpha mask for the 4x4 tile from the given horizontal
/// coverages, splatting them across the other dimension.
fn alpha_mask_from_x_coverage(cov : FixedArray[Float]) -> FixedArray[Byte] {
  let buf = FixedArray::make(16, b'\x00')
  for col in 0..<4 {
    let alpha = f32_as_u8(cov[col] * 255.0 + 0.5).to_byte()
    for r in 0..<4 {
      buf[col * 4 + r] = alpha
    }
  }
  buf
}
