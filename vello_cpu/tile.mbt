// Port of `vello_common/src/tile.rs` (analytic anti-aliasing only).

///|
/// W-inding bit
const W_BIT : UInt = 0b10000

///|
/// Shift amount corresponding to the winding bit.
const WINDING_SHIFT : Int = 4

///|
/// Shift amount corresponding to the intersection bits.
const INT_MASK_SHIFT : Int = 5

///|
/// The max number of lines per path.
const MAX_LINES_PER_PATH : Int = 134217728

///|
/// The width of a tile in pixels.
const TILE_WIDTH : Int = 4

///|
/// The height of a tile in pixels.
const TILE_HEIGHT : Int = 4

// A tile represents an aligned area on the pixmap (4x4). Tiles are stored as
// their `u64` representation `(y << 48) | (x << 32) | packed_winding_line_idx`
// (`Tile::to_bits`), which is also their sort order.

///|
/// A special tile used to signal the end of a tile stream during rendering.
const TILE_SENTINEL : UInt64 = 0xFFFFFFFF00000000

///|
fn tile_new(
  x : Int,
  y : Int,
  line_idx : Int,
  intersection_mask : UInt,
) -> UInt64 {
  (y.to_uint64() << 48) |
  (x.to_uint64() << 32) |
  ((line_idx.reinterpret_as_uint() << INT_MASK_SHIFT) | intersection_mask).to_uint64()
}

///|
/// Create a new tile, clamping `x` and `y` to the largest possible
/// coordinate.
fn tile_new_clamped(
  x : Int,
  y : Int,
  line_idx : Int,
  intersection_mask : UInt,
) -> UInt64 {
  tile_new(
    if x < 65535 / TILE_WIDTH {
      x
    } else {
      65535 / TILE_WIDTH
    },
    if y < 65535 / TILE_HEIGHT {
      y
    } else {
      65535 / TILE_HEIGHT
    },
    line_idx,
    intersection_mask,
  )
}

///|
fn tile_x(t : UInt64) -> Int {
  ((t >> 32) & 0xFFFF).to_int()
}

///|
fn tile_y(t : UInt64) -> Int {
  (t >> 48).to_int()
}

///|
fn tile_line_idx(t : UInt64) -> Int {
  ((t & 0xFFFFFFFF).to_uint() >> INT_MASK_SHIFT).reinterpret_as_int()
}

///|
/// Whether the line crosses the top edge of the tile.
fn tile_winding(t : UInt64) -> Bool {
  (t.to_uint() & W_BIT) != 0
}

///|
fn tile_same_loc(a : UInt64, b : UInt64) -> Bool {
  tile_y(a) == tile_y(b) && tile_x(a) == tile_x(b)
}

///|
fn tile_prev_loc(a : UInt64, b : UInt64) -> Bool {
  tile_y(a) == tile_y(b) && tile_x(a) + 1 == tile_x(b)
}

///|
fn tile_same_row(a : UInt64, b : UInt64) -> Bool {
  tile_y(a) == tile_y(b)
}

///|
/// A logical grouping of arrays used for culled tile processing.
priv struct CulledWindings {
  /// Fractional winding coverage for each individual scanline in a row
  /// (`Tile::HEIGHT` floats per row).
  partial : FixedArray[Float]
  /// Accumulated integer winding deltas for each tile row (`i16`).
  coarse : FixedArray[Int]
  /// Bitmask tracking which rows contain active geometry or winding data.
  active : FixedArray[UInt]
  /// Flag indicating if any geometry was early-culled outside the viewport.
  mut culled : Bool
}

///|
fn CulledWindings::new(height : Int) -> CulledWindings {
  let num_rows = div_ceil(height, TILE_HEIGHT)
  let num_bits = div_ceil(num_rows, 32)
  {
    partial: FixedArray::make(num_rows * TILE_HEIGHT, 0.0),
    coarse: FixedArray::make(num_rows, 0),
    active: FixedArray::make(num_bits, 0),
    culled: false,
  }
}

///|
/// Clears but does not resize
fn CulledWindings::reset(self : CulledWindings) -> Unit {
  if self.culled {
    self.partial.fill(0.0)
    self.coarse.fill(0)
    self.active.fill(0)
    self.culled = false
  }
}

///|
/// `i16 += i16` (wrapping).
fn CulledWindings::add_coarse(
  self : CulledWindings,
  row : Int,
  d : Int,
) -> Unit {
  let v = (self.coarse[row] + d) & 0xFFFF
  self.coarse[row] = if v >= 0x8000 { v - 0x10000 } else { v }
}

///|
/// Marks if a row was culled early for faster traversal in strip generation.
fn CulledWindings::mark_row_active(
  self : CulledWindings,
  row_idx : Int,
) -> Unit {
  self.active[row_idx >> 5] = self.active[row_idx >> 5] | (1U << (row_idx & 31))
}

///|
/// Bulk marks a range of rows as active [`start_row`, `end_row`).
fn CulledWindings::mark_row_range_active(
  self : CulledWindings,
  start_row : Int,
  end_row : Int,
) -> Unit {
  if start_row >= end_row {
    return
  }
  let start_word = start_row >> 5
  let end_word = (end_row - 1) >> 5
  if start_word == end_word {
    let shift = start_row & 31
    let count = end_row - start_row
    let mask = if count == 32 {
      0xFFFFFFFFU
    } else {
      ((1U << count) - 1) << shift
    }
    self.active[start_word] = self.active[start_word] | mask
  } else {
    self.active[start_word] = self.active[start_word] |
      (0xFFFFFFFFU << (start_row & 31))
    for w in (start_word + 1)..<end_word {
      self.active[w] = 0xFFFFFFFFU
    }
    let end_shift = ((end_row - 1) & 31) + 1
    let mask = if end_shift == 32 { 0xFFFFFFFFU } else { (1U << end_shift) - 1 }
    self.active[end_word] = self.active[end_word] | mask
  }
}

///|
/// Calls `f` on active rows in the range [`start`, `end`).
fn CulledWindings::for_active_rows_in_range(
  self : CulledWindings,
  start : Int,
  end : Int,
  f : (Int) -> Unit,
) -> Unit {
  if start >= end {
    return
  }
  let start_word = start >> 5
  let end_word = (end - 1) >> 5
  let process_word = (word : UInt, word_idx : Int) => {
    let mut word = word
    while word != 0 {
      let bit = word.ctz()
      word = word & (1U << bit).lnot()
      f((word_idx << 5) + bit)
    }
  }
  let end_limit = ((end - 1) & 31) + 1
  let end_mask = if end_limit == 32 {
    0xFFFFFFFFU
  } else {
    (1U << end_limit) - 1
  }
  {
    let start_bit = start & 31
    let mut word = self.active[start_word] & ((1U << start_bit) - 1).lnot()
    if start_word == end_word {
      word = word & end_mask
    }
    process_word(word, start_word)
  }
  if start_word < end_word {
    for word_idx in (start_word + 1)..<end_word {
      process_word(self.active[word_idx], word_idx)
    }
    process_word(self.active[end_word] & end_mask, end_word)
  }
}

///|
/// Handles the tiling of paths.
priv struct Tiles {
  tile_buf : Array[UInt64]
  mut sorted : Bool
  /// Auxiliary data tracking row windings and active rows for early culling.
  windings : CulledWindings
}

///|
fn Tiles::new(height : Int) -> Tiles {
  { tile_buf: [], sorted: false, windings: CulledWindings::new(height), }
}

///|
fn Tiles::len(self : Tiles) -> Int {
  self.tile_buf.length()
}

///|
fn Tiles::is_empty(self : Tiles) -> Bool {
  self.tile_buf.is_empty()
}

///|
fn Tiles::has_culled_tiles(self : Tiles) -> Bool {
  self.windings.culled
}

///|
fn Tiles::reset(self : Tiles) -> Unit {
  self.windings.reset()
  self.tile_buf.clear()
  self.sorted = false
}

///|
fn Tiles::sort_tiles(self : Tiles) -> Unit {
  self.sorted = true
  self.tile_buf.sort()
}

///|
fn Tiles::get(self : Tiles, index : Int) -> UInt64 {
  guard self.sorted else {
    abort("attempted to call `get` before sorting the tile container.")
  }
  self.tile_buf[index]
}

///|
/// Accumulates fractional coverage into a row of `partial` windings
/// (`calc_fractional_coverage!` followed by the `mul_add` into the row).
fn CulledWindings::add_partial(
  self : CulledWindings,
  y_idx : Int,
  segment_top_y : Float,
  segment_bottom_y : Float,
  f_dir : Float,
  double_count : Float,
) -> Unit {
  let y_idx_f32 = Float::from_int(y_idx)
  let tile_height_f32 = Float::from_int(TILE_HEIGHT)
  let local_y_start = (segment_top_y - y_idx_f32) * tile_height_f32
  let local_y_end = (segment_bottom_y - y_idx_f32) * tile_height_f32
  for l in 0..<4 {
    let px_top = Float::from_int(l)
    let px_bottom = px_top + 1.0
    let fractional_coverage = vmax(
      vmin(px_bottom, local_y_end) - vmax(px_top, local_y_start),
      0.0,
    )
    let idx = y_idx * TILE_HEIGHT + l
    let current = self.partial[idx]
    self.partial[idx] = madd(fractional_coverage, f_dir, current - double_count)
  }
}

///|
/// Generates tile commands for Analytic Anti-Aliasing rasterization.
fn Tiles::make_tiles_analytic_aa(
  self : Tiles,
  lines : Array[Line],
  width : Int,
  height : Int,
) -> Bool {
  self.reset()
  if width == 0 || height == 0 {
    return self.windings.culled
  }
  let tile_columns = div_ceil(width, TILE_WIDTH)
  let tile_rows = div_ceil(height, TILE_HEIGHT)
  let n_lines = if lines.length() < MAX_LINES_PER_PATH {
    lines.length()
  } else {
    MAX_LINES_PER_PATH
  }
  let tile_buf = self.tile_buf
  let windings = self.windings
  for line_idx in 0..<n_lines {
    let line = lines[line_idx]
    let p0_x = line.p0.x / Float::from_int(TILE_WIDTH)
    let p0_y = line.p0.y / Float::from_int(TILE_HEIGHT)
    let p1_x = line.p1.x / Float::from_int(TILE_WIDTH)
    let p1_y = line.p1.y / Float::from_int(TILE_HEIGHT)
    let (line_left_x, line_right_x) = if p0_x < p1_x {
      (p0_x, p1_x)
    } else {
      (p1_x, p0_x)
    }
    if line_left_x > Float::from_int(tile_columns) {
      continue
    }
    let (line_top_y, line_top_x, line_bottom_y, line_bottom_x) = if p0_y < p1_y {
      (p0_y, p0_x, p1_y, p1_x)
    } else {
      (p1_y, p1_x, p0_y, p0_x)
    }
    let y_top_tiles = min_int(f32_as_u16(line_top_y), tile_rows)
    let line_bottom_y_ceil = line_bottom_y.ceil()
    let y_bottom_tiles = min_int(f32_as_u16(line_bottom_y_ceil), tile_rows)
    if y_top_tiles >= y_bottom_tiles {
      continue
    }
    let dir = if p0_y >= p1_y { 1 } else { -1 }
    let f_dir = Float::from_int(dir)
    if line_right_x < 0.0 {
      let is_start_culled = line_top_y < 0.0
      if !is_start_culled {
        windings.mark_row_active(y_top_tiles)
        let at_top_of_tile = line_top_y <= Float::from_int(y_top_tiles)
        if at_top_of_tile {
          windings.add_coarse(y_top_tiles, dir)
        }
        windings.add_partial(
          y_top_tiles,
          line_top_y,
          line_bottom_y,
          f_dir,
          if at_top_of_tile {
            f_dir
          } else {
            0.0
          },
        )
      }
      let y_start_middle = if is_start_culled {
        y_top_tiles
      } else {
        y_top_tiles + 1
      }
      let line_bottom_floor = line_bottom_y.floor()
      let y_end_middle = min_int(f32_as_u16(line_bottom_floor), tile_rows)
      for y_idx in y_start_middle..<y_end_middle {
        windings.add_coarse(y_idx, dir)
      }
      windings.mark_row_range_active(y_start_middle, y_end_middle)
      if line_bottom_y != line_bottom_floor &&
        y_end_middle < tile_rows &&
        (is_start_culled || y_end_middle != y_top_tiles) {
        windings.mark_row_active(y_end_middle)
        windings.add_coarse(y_end_middle, dir)
        windings.add_partial(
          y_end_middle, line_top_y, line_bottom_y, f_dir, f_dir,
        )
      }
      windings.culled = true
      continue
    }
    let p0_tile_x = f32_as_i32(line_top_x.floor())
    let p0_tile_y = f32_as_i32(line_top_y.floor())
    let p1_tile_x = f32_as_i32(line_bottom_x.floor())
    let p1_tile_y = f32_as_i32(line_bottom_y.floor())
    let not_same_tile = p0_tile_y != p1_tile_y || p0_tile_x != p1_tile_x
    if not_same_tile {
      if line_left_x == line_right_x {
        let x = min_int(f32_as_u16(line_left_x), u16_sat_sub(tile_columns, 1))
        let is_start_culled = line_top_y < 0.0
        if !is_start_culled {
          let winding = if Float::from_int(y_top_tiles) >= line_top_y {
            W_BIT
          } else {
            0
          }
          tile_buf.push(tile_new_clamped(x, y_top_tiles, line_idx, winding))
        }
        let y_start = if is_start_culled {
          y_top_tiles
        } else {
          y_top_tiles + 1
        }
        for y_idx in y_start..<y_bottom_tiles {
          tile_buf.push(tile_new_clamped(x, y_idx, line_idx, W_BIT))
        }
      } else {
        let dx = p1_x - p0_x
        let dy = p1_y - p0_y
        let x_slope = dx / dy
        let dx_dir : UInt = if line_bottom_x >= line_top_x { 1 } else { 0 }
        let not_dx_dir = dx_dir ^ 1
        let w_start_base = dx_dir << WINDING_SHIFT
        let w_end_base = not_dx_dir << WINDING_SHIFT
        let push_row_extents = (
          y_idx : Int,
          row_left_x : Float,
          row_right_x : Float,
          w_start : UInt,
          w_end : UInt,
          w_single : UInt,
        ) => {
          let x_start = f32_as_u16(row_left_x)
          let x_end = min_int(f32_as_u16(row_right_x), tile_columns - 1)
          if x_start <= x_end {
            let winding = if x_start == x_end { w_single } else { w_start }
            tile_buf.push(tile_new(x_start, y_idx, line_idx, winding))
            for x_idx in u16_sat_add(x_start, 1)..<x_end {
              tile_buf.push(tile_new(x_idx, y_idx, line_idx, 0))
            }
            if x_start < x_end {
              tile_buf.push(tile_new(x_end, y_idx, line_idx, w_end))
            }
          }
        }
        let push_row = (
          y_idx : Int,
          row_top_y : Float,
          row_bottom_y : Float,
          w_start : UInt,
          w_end : UInt,
          w_single : UInt,
        ) => {
          let row_top_x = p0_x + (row_top_y - p0_y) * x_slope
          let row_bottom_x = p0_x + (row_bottom_y - p0_y) * x_slope
          let row_left_x = fmaxnm(fminnm(row_top_x, row_bottom_x), line_left_x)
          let row_right_x = fminnm(
            fmaxnm(row_top_x, row_bottom_x),
            line_right_x,
          )
          if row_left_x < 0.0 {
            windings.culled = true
            if row_right_x < 0.0 {
              windings.mark_row_active(y_idx)
              let crosses_top = (w_single & W_BIT) != 0
              if crosses_top {
                windings.add_coarse(y_idx, dir)
              }
              windings.add_partial(
                y_idx,
                row_top_y,
                row_bottom_y,
                f_dir,
                if crosses_top {
                  f_dir
                } else {
                  0.0
                },
              )
              return
            } else {
              let y_slope = dy / dx
              let y_intersect = row_top_y - row_top_x * y_slope
              let (off_screen_top_y, off_screen_bottom_y) = if row_top_x < 0.0 {
                (row_top_y, fminnm(row_bottom_y, y_intersect))
              } else {
                (fmaxnm(row_top_y, y_intersect), row_bottom_y)
              }
              if off_screen_top_y < off_screen_bottom_y {
                windings.mark_row_active(y_idx)
                windings.add_partial(
                  y_idx, off_screen_top_y, off_screen_bottom_y, f_dir, 0.0,
                )
              }
            }
          }
          push_row_extents(
            y_idx, row_left_x, row_right_x, w_start, w_end, w_single,
          )
        }
        let is_start_culled = line_top_y < 0.0
        if line_left_x >= 0.0 && line_right_x < Float::from_int(tile_columns) {
          if !is_start_culled {
            let y = Float::from_int(y_top_tiles)
            let row_bottom_y = fminnm(y + 1.0, line_bottom_y)
            let row_bottom_x = if row_bottom_y == line_bottom_y {
              line_bottom_x
            } else {
              p0_x + (row_bottom_y - p0_y) * x_slope
            }
            let mask : UInt = if y >= line_top_y { W_BIT } else { 0 }
            push_row_extents(
              y_top_tiles,
              fminnm(line_top_x, row_bottom_x),
              fmaxnm(line_top_x, row_bottom_x),
              w_start_base & mask,
              w_end_base & mask,
              W_BIT & mask,
            )
          }
          let y_start = if is_start_culled {
            y_top_tiles
          } else {
            y_top_tiles + 1
          }
          if y_start < y_bottom_tiles {
            let mut row_top_x = p0_x +
              (Float::from_int(y_start) - p0_y) * x_slope
            for y_idx in y_start..<y_bottom_tiles {
              let y = Float::from_int(y_idx)
              let row_bottom_x = if line_bottom_y < y + 1.0 {
                line_bottom_x
              } else {
                p0_x + (y + 1.0 - p0_y) * x_slope
              }
              push_row_extents(
                y_idx,
                fminnm(row_top_x, row_bottom_x),
                fmaxnm(row_top_x, row_bottom_x),
                w_start_base,
                w_end_base,
                W_BIT,
              )
              row_top_x = row_bottom_x
            }
          }
        } else {
          if !is_start_culled {
            let y = Float::from_int(y_top_tiles)
            let row_bottom_y = fminnm(y + 1.0, line_bottom_y)
            let mask : UInt = if y >= line_top_y { W_BIT } else { 0 }
            push_row(
              y_top_tiles,
              line_top_y,
              row_bottom_y,
              w_start_base & mask,
              w_end_base & mask,
              W_BIT & mask,
            )
          }
          let y_start = if is_start_culled {
            y_top_tiles
          } else {
            y_top_tiles + 1
          }
          for y_idx in y_start..<y_bottom_tiles {
            let y = Float::from_int(y_idx)
            let row_bottom_y = fminnm(y + 1.0, line_bottom_y)
            push_row(y_idx, y, row_bottom_y, w_start_base, w_end_base, W_BIT)
          }
        }
      }
    } else {
      let tile = tile_new_clamped(
        min_int(f32_as_u16(line_left_x), tile_columns + 1),
        y_top_tiles,
        line_idx,
        if Float::from_int(y_top_tiles) >= line_top_y {
          W_BIT
        } else {
          0
        },
      )
      tile_buf.push(tile)
    }
  }
  self.windings.culled
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
