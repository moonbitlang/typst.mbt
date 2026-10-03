// Port of `hayro-jbig2/src/decode/halftone.rs`: halftone region segment
// parsing and decoding (7.4.5, 6.6).

///|
/// Decode a halftone region segment (7.4.5.2, 6.6).
fn halftone_decode(
  header : HalftoneRegionHeader,
  pattern_dict : PatternDictionary,
  ctx : ScratchBuffers,
) -> RegionBitmap raise DecodeError {
  let region = header.region_info
  let htreg = Bitmap::new_with(
    region.width,
    region.height,
    region.x_location,
    region.y_location,
    header.flags.initial_pixel_color,
  )
  halftone_decode_into(header, pattern_dict, htreg, ctx)
  { bitmap: htreg, combination_operator: region.combination_operator, }
}

///|
fn halftone_decode_into(
  header : HalftoneRegionHeader,
  pattern_dict : PatternDictionary,
  htreg : Bitmap,
  ctx : ScratchBuffers,
) -> Unit raise DecodeError {
  let skip_bitmap = if header.flags.enable_skip {
    Some(compute_skip_bitmap(header, pattern_dict, htreg))
  } else {
    None
  }

  // "3) Set HBPP to ⌈log₂(HNUMPATS)⌉." (6.6.5)
  let n = pattern_dict.patterns.length().reinterpret_as_uint()
  let n1 = if n == 0 { 0U } else { n - 1 }
  let bits_per_pixel = if n1 == 0 {
    1U
  } else {
    // `checked_ilog2() + 1`
    (31 - n1.clz()).reinterpret_as_uint() + 1
  }

  // "4) Decode an image GI of size HGW by HGH with HBPP bits per pixel using
  // the gray-scale image decoding procedure as described in Annex C." (6.6.5)
  let gs_params : GrayScaleParams = {
    use_mmr: header.flags.mmr,
    bits_per_pixel,
    width: header.grid_position_and_size.width,
    height: header.grid_position_and_size.height,
    template: header.flags.template,
    skip_mask: skip_bitmap,
  }
  let gi = decode_gray_scale_image(header.data, gs_params, ctx)

  // "5) Place sequentially the patterns corresponding to the values in GI into
  // HTREG by the procedure described in 6.6.5.2." (6.6.5)
  render_patterns(htreg, gi, header, pattern_dict)
}

///|
/// Parse a halftone region segment header (7.4.5.1).
fn halftone_parse(reader : Reader) -> HalftoneRegionHeader raise DecodeError {
  let region_info = parse_region_segment_info(reader)
  let flags_byte = ok_or(reader.read_byte(), eof).to_int()
  let mmr = (flags_byte & 0x01) != 0
  let template = Template::from_byte(flags_byte >> 1)
  let enable_skip = (flags_byte & 0x08) != 0
  let combination_operator = CombinationOperator::from_value(flags_byte >> 4)
  let initial_pixel_color = (flags_byte & 0x80) != 0
  let flags : HalftoneRegionFlags = {
    mmr,
    template,
    enable_skip,
    combination_operator,
    initial_pixel_color,
  }
  let grid_width = ok_or(reader.read_u32(), eof)
  let grid_height = ok_or(reader.read_u32(), eof)
  if grid_width > MAX_DIMENSION || grid_height > MAX_DIMENSION {
    raise Overflow(GridDimension)
  }

  // TODO: Check grid offsets as well.

  let grid_horizontal_offset = ok_or(reader.read_i32(), eof)
  let grid_vertical_offset = ok_or(reader.read_i32(), eof)
  let grid_position_and_size : HalftoneGridPositionAndSize = {
    width: grid_width,
    height: grid_height,
    horizontal_offset: grid_horizontal_offset,
    vertical_offset: grid_vertical_offset,
  }
  let grid_x_vector = ok_or(reader.read_u16(), eof)
  let grid_y_vector = ok_or(reader.read_u16(), eof)
  let grid_vector : HalftoneGridVector = {
    x_vector: grid_x_vector,
    y_vector: grid_y_vector,
  }
  let data = ok_or(reader.tail(), eof)
  { region_info, flags, grid_position_and_size, grid_vector, data, }
}

///|
/// Parsed halftone region segment flags (7.4.5.1.1).
priv struct HalftoneRegionFlags {
  mmr : Bool
  template : Template
  enable_skip : Bool
  combination_operator : CombinationOperator
  initial_pixel_color : Bool
}

///|
/// Halftone grid position and size (7.4.5.1.2).
priv struct HalftoneGridPositionAndSize {
  width : UInt
  height : UInt
  horizontal_offset : Int
  vertical_offset : Int
}

///|
/// Halftone grid vector (7.4.5.1.3).
priv struct HalftoneGridVector {
  /// `HRX` - 256 times the horizontal coordinate of the halftone grid vector.
  x_vector : UInt
  /// `HRY` - 256 times the vertical coordinate of the halftone grid vector.
  y_vector : UInt
}

///|
/// Parsed halftone region segment header (7.4.5.1).
priv struct HalftoneRegionHeader {
  region_info : RegionSegmentInfo
  flags : HalftoneRegionFlags
  grid_position_and_size : HalftoneGridPositionAndSize
  grid_vector : HalftoneGridVector
  data : BytesView
}

///|
priv struct GridCoords {
  mut x : Int64
  mut y : Int64
  mut row_x : Int64
  mut row_y : Int64
  hrx : Int64
  hry : Int64
}

///|
fn GridCoords::new(
  grid : HalftoneGridPositionAndSize,
  vector : HalftoneGridVector,
) -> GridCoords {
  {
    x: grid.horizontal_offset.to_int64(),
    y: grid.vertical_offset.to_int64(),
    row_x: grid.horizontal_offset.to_int64(),
    row_y: grid.vertical_offset.to_int64(),
    hrx: vector.x_vector.to_int64(),
    hry: vector.y_vector.to_int64(),
  }
}

///|
#inline
fn GridCoords::get(self : GridCoords) -> (Int, Int) {
  ((self.x >> 8).to_int(), (self.y >> 8).to_int())
}

///|
#inline
fn GridCoords::advance_col(self : GridCoords) -> Unit {
  self.x += self.hrx
  self.y -= self.hry
}

///|
#inline
fn GridCoords::advance_row(self : GridCoords) -> Unit {
  self.row_x += self.hry
  self.row_y += self.hrx
  self.x = self.row_x
  self.y = self.row_y
}

///|
/// Compute the HSKIP bitmap (6.6.5.1).
fn compute_skip_bitmap(
  header : HalftoneRegionHeader,
  pattern_dict : PatternDictionary,
  htreg : Bitmap,
) -> FixedArray[UInt] raise DecodeError {
  let grid = header.grid_position_and_size
  let pattern_width = pattern_dict.pattern_width.reinterpret_as_int()
  let pattern_height = pattern_dict.pattern_height.reinterpret_as_int()
  let region_width = htreg.width.reinterpret_as_int()
  let region_height = htreg.height.reinterpret_as_int()
  let stride = stride_of(grid.width)
  let len = stride.to_uint64() * grid.height.to_uint64()
  if len > 0xFFFFFFFFUL {
    raise Overflow(BitmapDimension)
  }
  let hskip = FixedArray::make(len.to_int(), 0U)
  let coords = GridCoords::new(grid, header.grid_vector)
  for m_g in 0U..<grid.height {
    for n_g in 0U..<grid.width {
      let (x, y) = coords.get()
      let skip = x + pattern_width <= 0 ||
        x >= region_width ||
        y + pattern_height <= 0 ||
        y >= region_height
      if skip {
        let word_idx = (m_g * stride + n_g / 32).reinterpret_as_int()
        let bit_pos = (31U - n_g % 32).reinterpret_as_int()
        hskip[word_idx] = hskip[word_idx] | (1U << bit_pos)
      }
      coords.advance_col()
    }
    coords.advance_row()
  }
  hskip
}

///|
/// Render patterns into the target region (6.6.5.2).
fn render_patterns(
  region : Bitmap,
  gi : FixedArray[UInt],
  header : HalftoneRegionHeader,
  pattern_dict : PatternDictionary,
) -> Unit raise DecodeError {
  let grid = header.grid_position_and_size
  let op = header.flags.combination_operator
  let pw = pattern_dict.pattern_width
  let ph = pattern_dict.pattern_height
  let region_w = region.width.reinterpret_as_int()
  let region_h = region.height.reinterpret_as_int()
  let stride = region.stride
  let num_patterns = pattern_dict.patterns.length()

  // The original pattern mask has 1s in the top `pw` bits.
  let original_mask = if pw >= WORD_BITS {
    0xFFFFFFFFU
  } else {
    0xFFFFFFFFU << (WORD_BITS - pw).reinterpret_as_int()
  }
  let data = region.data
  let shifted_all = pattern_dict.shifted_patterns
  let coords = GridCoords::new(grid, header.grid_vector)
  let mut gi_idx = 0
  for _ in 0U..<grid.height {
    for _ in 0U..<grid.width {
      let (x, y) = coords.get()
      let pattern_index = gi[gi_idx]
      gi_idx += 1
      if pattern_index >= num_patterns.reinterpret_as_uint() {
        raise Region(GrayScaleOutOfRange)
      }
      let pattern_index = pattern_index.reinterpret_as_int()

      // Check whether we can use the blit fast path.
      let shifted = if x >= 0 &&
        y >= 0 &&
        x + pw.reinterpret_as_int() <= region_w &&
        y + ph.reinterpret_as_int() <= region_h {
        pattern_dict.shifted_pattern(
          pattern_index,
          x.reinterpret_as_uint() % WORD_BITS,
        )
      } else {
        None
      }
      match shifted {
        Some(s) => {
          let xu = x.reinterpret_as_uint()
          let yu = y.reinterpret_as_uint()
          let first_word = xu / WORD_BITS
          let offset = xu % WORD_BITS
          let two = offset != 0 && first_word + 1 < stride
          let offset_i = offset.reinterpret_as_int()

          // TODO: It seems our current test suite only triggers for
          // `Or`.

          // (The `blit_rows!` macro, with the operator-specific masks.)
          let (mask0, mask1) = if offset == 0 {
            (original_mask, 0U)
          } else {
            (original_mask >> offset_i, original_mask << (32 - offset_i))
          }
          let inv_mask0 = mask0.lnot()
          let inv_mask1 = if offset == 0 { 0xFFFFFFFFU } else { mask1.lnot() }
          for row in 0U..<ph {
            let base = ((yu + row) * stride + first_word).reinterpret_as_int()
            let si = s + row.reinterpret_as_int() * 2
            let d0 = data[base]
            let s0 = shifted_all[si]
            data[base] = blit_op(op, d0, s0, mask0, inv_mask0)
            if two {
              let d1 = data[base + 1]
              let s1 = shifted_all[si + 1]
              data[base + 1] = blit_op(op, d1, s1, mask1, inv_mask1)
            }
          }
        }
        None => {
          let pattern = pattern_dict.patterns[pattern_index]
          region.combine(pattern, x, y, op)
        }
      }
      coords.advance_col()
    }
    coords.advance_row()
  }
}

///|
/// The per-word operations of `render_patterns`' fast path.
#inline
fn blit_op(
  op : CombinationOperator,
  d : UInt,
  s : UInt,
  mask : UInt,
  inv_mask : UInt,
) -> UInt {
  match op {
    Or => d | s
    Xor => d ^ s
    And => d & (s | inv_mask)
    Replace => (d & inv_mask) | s
    Xnor => (d & inv_mask) | ((d ^ s).lnot() & mask)
  }
}
