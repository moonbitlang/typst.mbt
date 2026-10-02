// Port of `vello_common/src/strip.rs`.

///|
/// A strip.
struct Strip {
  /// The x coordinate of the strip, in user coordinates.
  x : Int
  /// The y coordinate of the strip, in user coordinates.
  y : Int
  /// Packed alpha index (bits 0..=30) and fill gap flag (bit 31).
  packed_alpha_idx_fill_gap : UInt
} derive(Eq)

///|
/// The bit mask for `fill_gap` packed into `packed_alpha_idx_fill_gap`.
const FILL_GAP_MASK : UInt = 0x80000000

///|
/// Creates a new strip.
fn Strip::new(x : Int, y : Int, alpha_idx : Int, fill_gap : Bool) -> Strip {
  let alpha_idx = alpha_idx.reinterpret_as_uint()
  guard (alpha_idx & FILL_GAP_MASK) == 0 else { abort("`alpha_idx` too large") }
  let fill_gap : UInt = if fill_gap { FILL_GAP_MASK } else { 0 }
  { x, y, packed_alpha_idx_fill_gap: alpha_idx | fill_gap, }
}

///|
/// Return whether the strip is a sentinel strip.
fn Strip::is_sentinel(self : Strip) -> Bool {
  self.x == 65535
}

///|
/// Return the y coordinate of the strip, in strip units.
fn Strip::strip_y(self : Strip) -> Int {
  self.y / TILE_HEIGHT
}

///|
/// Returns the horizontal pixel width of this strip.
///
/// This assumes that `next` is actually the next adjacent strip to `self`.
fn Strip::width_to(self : Strip, next : Strip) -> Int {
  let col = self.alpha_idx() / TILE_HEIGHT
  let next_col = next.alpha_idx() / TILE_HEIGHT
  (if next_col > col { next_col - col } else { 0 }) & 0xFFFF
}

///|
/// Returns the alpha index.
fn Strip::alpha_idx(self : Strip) -> Int {
  (self.packed_alpha_idx_fill_gap & FILL_GAP_MASK.lnot()).reinterpret_as_int()
}

///|
/// Returns whether the gap that lies between this strip and the previous in
/// the same row should be filled.
fn Strip::fill_gap(self : Strip) -> Bool {
  (self.packed_alpha_idx_fill_gap & FILL_GAP_MASK) != 0
}

///|
/// When early culling is active, geometry fully to the left of the viewport
/// creates no tiles. However, if that geometry has a non-zero winding, we
/// must output strips for those fills.
fn emit_culled_background(
  start : Int,
  end : Int,
  strips : Array[Strip],
  alphas : Array[Byte],
  windings : CulledWindings,
  should_fill : (Int) -> Bool,
) -> Unit {
  windings.for_active_rows_in_range(start, end, row => {
    if should_fill(windings.coarse[row]) {
      let y_pos = (row * TILE_HEIGHT) & 0xFFFF
      strips.push(Strip::new(0, y_pos, alphas.length(), false))
      for _ in 0..<(TILE_HEIGHT * TILE_WIDTH) {
        alphas.push(b'\xFF')
      }
      strips.push(Strip::new(65535, y_pos, alphas.length(), true))
    }
  })
}

///|
/// Render the tiles stored in `tiles` into the strip and alpha buffer.
fn render_strips(
  tiles : Tiles,
  strip_buf : Array[Strip],
  alpha_buf : Array[Byte],
  fill_rule : Fill,
  aliasing_threshold : Int?,
  lines : Array[Line],
) -> Unit {
  let row_windings = tiles.windings.coarse
  let has_culled_tiles = tiles.has_culled_tiles()
  // If no tiles were culled and the tile buffer is empty, we can simply
  // exit.
  if !has_culled_tiles && tiles.is_empty() {
    return
  }
  let should_fill = (winding : Int) => {
    match fill_rule {
      NonZero => winding != 0
      EvenOdd => winding % 2 != 0
    }
  }
  // Helper to handle "captive strips".
  let emit_captive_strip = (
    y : Int,
    is_left_viewport : Bool,
    acc : FixedArray[Float],
  ) => {
    let coarse_wd = tiles.windings.coarse[y]
    if should_fill(coarse_wd) && !is_left_viewport {
      strip_buf.push(
        Strip::new(0, (y * TILE_HEIGHT) & 0xFFFF, alpha_buf.length(), false),
      )
      for _ in 0..<(TILE_HEIGHT * TILE_WIDTH) {
        alpha_buf.push(b'\xFF')
      }
    }
    for l in 0..<4 {
      acc[l] = Float::from_int(coarse_wd)
      if is_left_viewport {
        acc[l] = acc[l] + tiles.windings.partial[y * TILE_HEIGHT + l]
      }
    }
    coarse_wd
  }
  // The accumulated tile winding delta.
  let mut winding_delta = 0
  // The previous tile visited.
  let mut prev_tile = if has_culled_tiles && tiles.is_empty() {
    TILE_SENTINEL
  } else {
    tiles.get(0)
  }
  // The accumulated (fractional) winding of the tile-sized location we're
  // currently at (`[f32x4; Tile::WIDTH]`, indexed `x * 4 + y`).
  let location_winding = FixedArray::make(16, (0.0 : Float))
  // The accumulated (fractional) windings at this location's right edge.
  let accumulated_winding = FixedArray::make(4, (0.0 : Float))
  let left_viewport = tile_x(prev_tile) == 0
  if has_culled_tiles {
    let row_max = min_int(tile_y(prev_tile), row_windings.length() & 0xFFFF)
    emit_culled_background(
      0,
      row_max,
      strip_buf,
      alpha_buf,
      tiles.windings,
      should_fill,
    )
    if tiles.is_empty() {
      return
    }
    winding_delta = emit_captive_strip(
      tile_y(prev_tile),
      left_viewport,
      accumulated_winding,
    )
    for x in 0..<4 {
      for l in 0..<4 {
        location_winding[x * 4 + l] = accumulated_winding[l]
      }
    }
  }
  // The strip we're building.
  let mut strip = Strip::new(
    (tile_x(prev_tile) * TILE_WIDTH) & 0xFFFF,
    (tile_y(prev_tile) * TILE_HEIGHT) & 0xFFFF,
    alpha_buf.length(),
    should_fill(winding_delta) && !left_viewport,
  )
  let n_tiles = tiles.len()
  let acc = FixedArray::make(4, (0.0 : Float))
  for tile_idx in 0..<=n_tiles {
    let tile = if tile_idx < n_tiles {
      tiles.tile_buf[tile_idx]
    } else {
      TILE_SENTINEL
    }
    let line = lines[tile_line_idx(tile)]
    let tile_left_x = Float::from_int(tile_x(tile)) *
      Float::from_int(TILE_WIDTH)
    let tile_top_y = Float::from_int(tile_y(tile)) *
      Float::from_int(TILE_HEIGHT)
    let p0_x = line.p0.x - tile_left_x
    let p0_y = line.p0.y - tile_top_y
    let p1_x = line.p1.x - tile_left_x
    let p1_y = line.p1.y - tile_top_y
    // Push out the winding as an alpha mask when we move to the next
    // location (i.e., a tile without the same location).
    if !tile_same_loc(prev_tile, tile) {
      match fill_rule {
        NonZero =>
          for i in 0..<16 {
            let area = location_winding[i]
            let coverage = area.abs()
            let mulled = madd(coverage, 255.0, 0.5)
            // Note that we are not storing the location winding here but the
            // actual alpha value as f32.
            location_winding[i] = vmin(mulled, 255.0)
          }
        EvenOdd =>
          for i in 0..<16 {
            let area = location_winding[i]
            let im1 = madd(area, 0.5, 0.5).floor()
            let coverage = madd(-2.0, im1, area).abs()
            let mulled = madd(255.0, coverage, 0.5)
            location_winding[i] = vmin(mulled, 255.0)
          }
      }
      for i in 0..<16 {
        let mut u8_val = f32_to_u8_lane(location_winding[i])
        if aliasing_threshold is Some(aliasing_threshold) {
          u8_val = if u8_val >= aliasing_threshold { 255 } else { 0 }
        }
        alpha_buf.push(u8_val.to_byte())
      }
      for i in 0..<16 {
        location_winding[i] = accumulated_winding[i % 4]
      }
    }
    // Push out the strip if we're moving to a next strip.
    if !tile_same_loc(prev_tile, tile) && !tile_prev_loc(prev_tile, tile) {
      strip_buf.push(strip)
      let is_sentinel = tile_idx == n_tiles
      let left_viewport = tile_x(tile) == 0
      if !tile_same_row(prev_tile, tile) {
        // Emit a final strip in the row if there is non-zero winding for the
        // sparse fill, or unconditionally if we've reached the sentinel tile
        // to end the path.
        if winding_delta != 0 || is_sentinel {
          strip_buf.push(
            Strip::new(
              65535,
              (tile_y(prev_tile) * TILE_HEIGHT) & 0xFFFF,
              alpha_buf.length(),
              should_fill(winding_delta),
            ),
          )
        }
        // Fill any vertical gaps (empty rows) between the previous and
        // current tile using the row windings.
        if has_culled_tiles && !is_sentinel {
          emit_culled_background(
            tile_y(prev_tile) + 1,
            tile_y(tile),
            strip_buf,
            alpha_buf,
            tiles.windings,
            should_fill,
          )
          winding_delta = emit_captive_strip(
            tile_y(tile),
            left_viewport,
            accumulated_winding,
          )
        } else {
          winding_delta = 0
          accumulated_winding.fill(0.0)
        }
        for i in 0..<16 {
          location_winding[i] = accumulated_winding[i % 4]
        }
      } else {
        // Note: this fill is mathematically not necessary. It provides a way
        // to reduce accumulation of float rounding errors.
        accumulated_winding.fill(Float::from_int(winding_delta))
      }
      if is_sentinel {
        break
      }
      strip = Strip::new(
        (tile_x(tile) * TILE_WIDTH) & 0xFFFF,
        (tile_y(tile) * TILE_HEIGHT) & 0xFFFF,
        alpha_buf.length(),
        should_fill(winding_delta) && !left_viewport,
      )
    }
    prev_tile = tile
    // Horizontal geometry has no impact on winding.
    if p0_y == p1_y {
      continue
    }
    // Lines moving upwards (in a y-down coordinate system) add to winding;
    // lines moving downwards subtract from winding.
    let sign = f32_signum(p0_y - p1_y)
    let (line_top_y, line_top_x, line_bottom_y, line_bottom_x) = if p0_y < p1_y {
      (p0_y, p0_x, p1_y, p1_x)
    } else {
      (p1_y, p1_x, p0_y, p0_x)
    }
    let y_slope = (line_bottom_y - line_top_y) / (line_bottom_x - line_top_x)
    let x_slope = (1.0 : Float) / y_slope
    winding_delta += f32_as_i32(sign) * (if tile_winding(tile) { 1 } else { 0 })
    let line_px_base_yx = madd(line_top_y, -x_slope, line_top_x)
    acc.fill(0.0)
    for x_idx in 0..<TILE_WIDTH {
      let px_left_x = Float::from_int(x_idx)
      let px_right_x = (1.0 : Float) + px_left_x
      for l in 0..<4 {
        let px_top_y = Float::from_int(l)
        let px_bottom_y = (1.0 : Float) + px_top_y
        let ymin = vmax(line_top_y, px_top_y)
        let ymax = vmin(line_bottom_y, px_bottom_y)
        // We require the `max` operation to pick `ymin` if its first operand
        // is NaN (`max_precise` on AArch64); `min` then uses the relaxed
        // version.
        let line_px_left_y = vmin(
          fmaxnm(madd(px_left_x - line_top_x, y_slope, line_top_y), ymin),
          ymax,
        )
        let line_px_right_y = vmin(
          fmaxnm(madd(px_right_x - line_top_x, y_slope, line_top_y), ymin),
          ymax,
        )
        let line_px_left_yx = madd(line_px_left_y, x_slope, line_px_base_yx)
        let line_px_right_yx = madd(line_px_right_y, x_slope, line_px_base_yx)
        let h = (line_px_right_y - line_px_left_y).abs()
        // The trapezoidal area enclosed between the line and the right edge
        // of the pixel square.
        let area = h *
          madd(line_px_right_yx + line_px_left_yx, -0.5, px_right_x)
        let i = x_idx * 4 + l
        location_winding[i] = location_winding[i] + madd(area, sign, acc[l])
        acc[l] = madd(h, sign, acc[l])
      }
    }
    for l in 0..<4 {
      accumulated_winding[l] = accumulated_winding[l] + acc[l]
    }
  }
  if has_culled_tiles {
    emit_culled_background(
      min_int(tile_y(prev_tile) + 1, row_windings.length() & 0xFFFF),
      row_windings.length() & 0xFFFF,
      strip_buf,
      alpha_buf,
      tiles.windings,
      should_fill,
    )
  }
}

///|
/// Rust's `f32::signum`.
fn f32_signum(x : Float) -> Float {
  if x != x {
    x
  } else if is_sign_negative(x) {
    -1.0
  } else {
    1.0
  }
}
