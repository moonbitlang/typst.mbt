// Port of `hayro-jpeg2000/src/j2c/build.rs`: building and setting up
// decompositions, sub-bands, precincts and code-blocks.

///|
/// Build and allocate all necessary structures to process the code-blocks
/// for a specific tile. Also parses the segments for each code-block.
fn build(tile : Tile, storage : DecompositionStorage) -> Unit raise DecodeError {
  build_decompositions(tile, storage)
}

///|
fn build_decompositions(
  tile : Tile,
  storage : DecompositionStorage,
) -> Unit raise DecodeError {
  let mut total_coefficients = 0
  let component_tiles = tile.component_tiles()
  for component_tile in component_tiles {
    total_coefficients += component_tile.rect.width().reinterpret_as_int() *
      component_tile.rect.height().reinterpret_as_int()
  }

  // (Upstream requests pre-zeroed memory if the buffer is empty.)
  storage.coefficients.resize(total_coefficients)
  let mut coefficient_counter = 0
  for component_tile in component_tiles {
    let d_start = storage.decompositions.length()
    let resolution_tiles = component_tile.resolution_tiles()
    fn build_sub_band(
      sub_band_type : SubBandType,
      resolution_tile : ResolutionTile,
    ) -> Int raise DecodeError {
      let sub_band_rect = resolution_tile.sub_band_rect(sub_band_type)
      let (precincts_start, precincts_end) = build_precincts(
        resolution_tile, sub_band_rect, tile, storage,
      )
      let added_coefficients = (sub_band_rect.width() * sub_band_rect.height()).reinterpret_as_int()
      let coefficients_start = coefficient_counter
      let coefficients_end = coefficient_counter + added_coefficients
      coefficient_counter += added_coefficients
      let idx = storage.sub_bands.length()
      storage.sub_bands.push({
        sub_band_type,
        rect: sub_band_rect,
        precincts_start,
        precincts_end,
        coefficients_start,
        coefficients_end,
      })
      idx
    }

    // Resolution 0 always is the LL sub-band.
    let ll_resolution_tile = resolution_tiles[0]
    let first_ll_sub_band = build_sub_band(LowLow, ll_resolution_tile)
    for resolution_tile in resolution_tiles[1:] {
      let hl = build_sub_band(HighLow, resolution_tile)
      let lh = build_sub_band(LowHigh, resolution_tile)
      let hh = build_sub_band(HighHigh, resolution_tile)
      let decomposition = {
        sub_bands: [hl, lh, hh],
        rect: resolution_tile.rect,
      }
      storage.decompositions.push(decomposition)
    }
    let d_end = storage.decompositions.length()
    storage.tile_decompositions.push({
      decompositions_start: d_start,
      decompositions_end: d_end,
      first_ll_sub_band,
    })
  }
  if coefficient_counter != storage.coefficients.len {
    abort("assertion failed: coefficient_counter == storage.coefficients.len()")
  }
}

///|
fn build_precincts(
  resolution_tile : ResolutionTile,
  sub_band_rect : IntRect,
  tile : Tile,
  storage : DecompositionStorage,
) -> (Int, Int) raise DecodeError {
  let start = storage.precincts.length()
  guard resolution_tile.precincts() is Some(precincts) else {
    raise Decoding(InvalidPrecinct)
  }
  for precinct_data in precincts {
    let precinct_rect = precinct_data.rect
    let cb_width = resolution_tile.code_block_width()
    let cb_height = resolution_tile.code_block_height()

    // See Figure B.9. Conceptually, the area of code-blocks is aligned
    // to the width/height of a code block.
    let cb_x0 = max_u32(precinct_rect.x0, sub_band_rect.x0) /
      cb_width *
      cb_width
    let cb_y0 = max_u32(precinct_rect.y0, sub_band_rect.y0) /
      cb_height *
      cb_height
    let cb_x1 = div_ceil_u32(
        min_u32(precinct_rect.x1, sub_band_rect.x1),
        cb_width,
      ) *
      cb_width
    let cb_y1 = div_ceil_u32(
        min_u32(precinct_rect.y1, sub_band_rect.y1),
        cb_height,
      ) *
      cb_height
    let code_block_area = IntRect::from_ltrb(cb_x0, cb_y0, cb_x1, cb_y1)

    // If the sub-band is empty, there are no code-blocks, but due to our
    // flooring/ceiling above, we would get 1 code-block in each direction.
    // Because of this, we need to special-case this.
    let code_blocks_x : UInt = if sub_band_rect.width() == 0 {
      0
    } else {
      code_block_area.width() / cb_width
    }
    let code_blocks_y : UInt = if sub_band_rect.height() == 0 {
      0
    } else {
      code_block_area.height() / cb_height
    }
    let (blocks_start, blocks_end) = build_code_blocks(
      code_block_area, sub_band_rect, resolution_tile, code_blocks_x, code_blocks_y,
      tile, storage,
    )
    let code_inclusion_tree = TagTree::new(
      code_blocks_x,
      code_blocks_y,
      storage.tag_tree_nodes,
    )
    let zero_bitplane_tree = TagTree::new(
      code_blocks_x,
      code_blocks_y,
      storage.tag_tree_nodes,
    )
    storage.precincts.push({
      code_blocks_start: blocks_start,
      code_blocks_end: blocks_end,
      code_inclusion_tree,
      zero_bitplane_tree,
    })
  }
  let end = storage.precincts.length()
  (start, end)
}

///|
fn build_code_blocks(
  code_block_area : IntRect,
  sub_band_rect : IntRect,
  tile_instance : ResolutionTile,
  code_blocks_x : UInt,
  code_blocks_y : UInt,
  tile : Tile,
  storage : DecompositionStorage,
) -> (Int, Int) {
  let mut y = code_block_area.y0
  let code_block_width = tile_instance.code_block_width()
  let code_block_height = tile_instance.code_block_height()
  let start = storage.code_blocks.length()
  let mut y_idx = 0U
  while y_idx < code_blocks_y {
    let mut x = code_block_area.x0
    let mut x_idx = 0U
    while x_idx < code_blocks_x {
      // "Code-blocks in the partition may extend beyond the boundaries of
      // the sub-band coefficients. When this happens, only the
      // coefficients lying within the sub-band are coded using the method
      // described in Annex D."
      let area = IntRect::from_xywh(x, y, code_block_width, code_block_height).intersect(
        sub_band_rect,
      )
      let start = storage.layers.length()
      for _ in 0..<tile.num_layers {
        // This will be updated once we actually read the
        // layer segments.
        storage.layers.push({ segments: None, })
      }
      let end = storage.layers.length()
      storage.code_blocks.push({
        x_idx,
        y_idx,
        rect: area,
        has_been_included: false,
        missing_bit_planes: 0,
        l_block: 3,
        number_of_coding_passes: 0,
        layers_start: start,
        layers_end: end,
        non_empty_layer_count: 0,
      })
      x = x + code_block_width
      x_idx += 1
    }
    y = y + code_block_height
    y_idx += 1
  }
  let end = storage.code_blocks.length()
  (start, end)
}

///|
priv struct Decomposition {
  /// In the order low-high, high-low and high-high.
  sub_bands : FixedArray[Int]
  /// The rectangle of the decomposition.
  rect : IntRect
}

///|
priv struct SubBand {
  sub_band_type : SubBandType
  rect : IntRect
  precincts_start : Int
  precincts_end : Int
  coefficients_start : Int
  coefficients_end : Int
}

///|
priv enum SubBandType {
  LowLow
  HighLow
  LowHigh
  HighHigh
} derive(Eq)

///|
priv struct Precinct {
  code_blocks_start : Int
  code_blocks_end : Int
  code_inclusion_tree : TagTree
  zero_bitplane_tree : TagTree
}

///|
priv struct PrecinctData {
  /// The x coordinate mapped back to the reference grid.
  r_x : UInt
  /// The y coordinate mapped back to the reference grid.
  r_y : UInt
  /// The actual rectangle of the precinct (in the sub-band coordinate
  /// system).
  rect : IntRect
  /// The index of the precinct in the sub-band.
  idx : UInt64
}

///|
priv struct CodeBlock {
  rect : IntRect
  x_idx : UInt
  y_idx : UInt
  layers_start : Int
  layers_end : Int
  mut has_been_included : Bool
  mut missing_bit_planes : Int
  mut number_of_coding_passes : Int
  mut l_block : UInt
  mut non_empty_layer_count : Int
}

///|
priv struct Segment {
  idx : Int
  coding_pases : Int
  data_length : UInt
  mut data : BytesView
}

///|
priv struct Layer {
  mut segments : (Int, Int)?
}
