// Port of `hayro-jpeg2000/src/j2c/decode.rs`: decoding JPEG2000 code streams.
//
// This is the "core" module of the crate that orchestrates all
// stages in such a way that a given codestream is decoded into its
// component channels.

///|
fn decode_codestream(
  data : BytesView,
  header : Header,
  ctx : DecoderContext,
) -> Unit raise DecodeError {
  let reader = BitReader::new(data)
  let tiles = parse_tiles(reader, header)
  if tiles.length() == 0 {
    raise Tile(Invalid)
  }
  ctx.reset(header, tiles[0])
  for tile in tiles {
    let iter_input = IteratorInput::new(tile)
    let progression_iterator : () -> ProgressionData? = match
      tile.progression_order {
      LayerResolutionComponentPosition =>
        layer_resolution_component_position_progression(iter_input)
      ResolutionLayerComponentPosition =>
        resolution_layer_component_position_progression(iter_input)
      ResolutionPositionComponentLayer =>
        match resolution_position_component_layer_progression(iter_input) {
          Some(i) => i
          None => raise Decoding(InvalidProgressionIterator)
        }
      PositionComponentResolutionLayer =>
        match position_component_resolution_layer_progression(iter_input) {
          Some(i) => i
          None => raise Decoding(InvalidProgressionIterator)
        }
      ComponentPositionResolutionLayer =>
        match component_position_resolution_layer_progression(iter_input) {
          Some(i) => i
          None => raise Decoding(InvalidProgressionIterator)
        }
    }
    decode_tile(
      tile,
      header,
      progression_iterator,
      ctx.tile_decode_context,
      ctx.channel_data,
      ctx.storage,
    )
  }

  // Note that this assumes that either all tiles have MCT or none of them.
  // In theory, only some could have it... But hopefully no such cursed
  // images exist!
  if tiles[0].mct {
    mct_apply_inverse(ctx.channel_data, tiles[0].component_infos, header)
  }
  apply_sign_shift(ctx.channel_data, header.component_infos)
}

///|
/// A decoder context for decoding JPEG2000 images.
pub struct DecoderContext {
  priv tile_decode_context : TileDecodeContext
  /// The raw, decoded samples for each channel.
  priv channel_data : Array[ComponentData]
  priv storage : DecompositionStorage
}

///|
/// Create a new decoder context.
pub fn DecoderContext::new() -> DecoderContext {
  {
    tile_decode_context: TileDecodeContext::default(),
    channel_data: [],
    storage: DecompositionStorage::default(),
  }
}

///|
pub impl Default for DecoderContext with fn default() {
  DecoderContext::new()
}

///|
pub extend DecoderContext with Default::{default}

///|
fn DecoderContext::reset(
  self : DecoderContext,
  header : Header,
  initial_tile : Tile,
) -> Unit {
  self.tile_decode_context.reset()
  self.storage.reset()
  self.channel_data.clear()
  // TODO: SIMD Buffers should be reused across runs!
  for info in initial_tile.component_infos {
    self.channel_data.push({
      container: SimdBuffer::zeros(
        header.size_data.image_width().reinterpret_as_int() *
        header.size_data.image_height().reinterpret_as_int(),
      ),
      bit_depth: info.size_info.precision,
    })
  }
}

///|
fn decode_tile(
  tile : Tile,
  header : Header,
  progression_iterator : () -> ProgressionData?,
  tile_ctx : TileDecodeContext,
  channel_data : Array[ComponentData],
  storage : DecompositionStorage,
) -> Unit raise DecodeError {
  storage.reset()

  // This is the method that orchestrates all steps.

  // First, we build the decompositions, including their sub-bands, precincts
  // and code blocks.
  build(tile, storage)
  // Next, we parse the layers/segments for each code block.
  parse_segments(tile, progression_iterator, header, storage)
  // We then decode the bitplanes of each code block, yielding the
  // (possibly dequantized) coefficients of each code block.
  decode_component_tile_bit_planes(tile, tile_ctx, storage, header)

  // Unlike before, we interleave the apply_idwt and store stages
  // for each component tile so we can reuse allocations better.
  for idx, component_info in header.component_infos {
    // Next, we apply the inverse discrete wavelet transform.
    idwt_apply(
      storage,
      tile_ctx,
      idx,
      header,
      component_info.wavelet_transform(),
    )
    // Finally, we store the raw samples for the tile area in the correct
    // location. Note that in case we have MCT, we are not applying it yet.
    // It will be applied in the very end once all tiles have been processed.
    // The reason we do this is that applying MCT requires access to the
    // data from _all_ components. If we didn't defer this until the end
    // we would have to collect the IDWT outputs of all components before
    // applying it. By not applying MCT here, we can get away with doing
    // IDWT and store on a per-component basis. Thus, we only need to
    // store one IDWT output at a time, allowing for better reuse of
    // allocations.
    store(tile, header, tile_ctx, channel_data[idx], component_info)
  }
}

///|
/// All decompositions for a single tile.
priv struct TileDecompositions {
  first_ll_sub_band : Int
  decompositions_start : Int
  decompositions_end : Int
}

///|
/// The sub-band indices of the given resolution (`SubBandIter`).
fn TileDecompositions::sub_band_iter(
  self : TileDecompositions,
  resolution : Int,
  decompositions : Array[Decomposition],
) -> FixedArray[Int] {
  if resolution == 0 {
    [self.first_ll_sub_band]
  } else {
    let idx = self.decompositions_start + resolution - 1
    if idx >= self.decompositions_end {
      abort("index out of bounds")
    }
    decompositions[idx].sub_bands
  }
}

///|
/// A buffer so that we can reuse allocations for layers/code blocks/etc.
/// across different tiles.
priv struct DecompositionStorage {
  segments : Array[Segment]
  layers : Array[Layer]
  code_blocks : Array[CodeBlock]
  precincts : Array[Precinct]
  tag_tree_nodes : Array[TagNode]
  coefficients : FloatVec
  sub_bands : Array[SubBand]
  decompositions : Array[Decomposition]
  tile_decompositions : Array[TileDecompositions]
}

///|
fn DecompositionStorage::default() -> DecompositionStorage {
  {
    segments: [],
    layers: [],
    code_blocks: [],
    precincts: [],
    tag_tree_nodes: [],
    coefficients: FloatVec::new(),
    sub_bands: [],
    decompositions: [],
    tile_decompositions: [],
  }
}

///|
fn DecompositionStorage::reset(self : DecompositionStorage) -> Unit {
  self.segments.clear()
  self.layers.clear()
  self.code_blocks.clear()
  // No need to clear the coefficients, as they will be resized
  // and then overridden.
  // self.coefficients.clear();
  self.precincts.clear()
  self.sub_bands.clear()
  self.decompositions.clear()
  self.tile_decompositions.clear()
  self.tag_tree_nodes.clear()
}

///|
/// A reusable context used during the decoding of a single tile.
///
/// Some of the fields are temporary in nature and reset after moving on to the
/// next tile, some contain global state.
priv struct TileDecodeContext {
  /// A reusable buffer for the IDWT output.
  idwt_output : IDWTOutput
  /// A scratch buffer used during IDWT.
  idwt_scratch_buffer : FloatVec
  /// A reusable context for decoding code blocks.
  bit_plane_decode_context : BitPlaneDecodeContext
  /// Reusable buffers for decoding bitplanes.
  bit_plane_decode_buffers : BitPlaneDecodeBuffers
}

///|
fn TileDecodeContext::default() -> TileDecodeContext {
  {
    idwt_output: IDWTOutput::default(),
    idwt_scratch_buffer: FloatVec::new(),
    bit_plane_decode_context: BitPlaneDecodeContext::default(),
    bit_plane_decode_buffers: BitPlaneDecodeBuffers::default(),
  }
}

///|
fn TileDecodeContext::reset(self : TileDecodeContext) -> Unit {
  // This method doesn't do anything, just keeping it there in case
  // it's needed in the future.
  // Bitplane decode context and buffers will be reset in the
  // corresponding methods. IDWT output and scratch buffer will be
  // overridden on demand, so those don't need to be reset either.
  ignore(self)
}

///|
fn decode_component_tile_bit_planes(
  tile : Tile,
  tile_ctx : TileDecodeContext,
  storage : DecompositionStorage,
  header : Header,
) -> Unit raise DecodeError {
  for tile_decompositions_idx, component_info in tile.component_infos {
    // Only decode the resolution levels we actually care about.
    let end = (
        component_info.num_resolution_levels() -
        header.skipped_resolution_levels
      ) &
      0xFF
    for resolution in 0..<end {
      let tile_composition = storage.tile_decompositions[tile_decompositions_idx]
      let sub_band_iter = tile_composition.sub_band_iter(
        resolution,
        storage.decompositions,
      )
      for sub_band_idx in sub_band_iter {
        decode_sub_band_bitplanes(
          sub_band_idx, resolution, component_info, tile_ctx, storage, header,
        )
      }
    }
  }
}

///|
fn decode_sub_band_bitplanes(
  sub_band_idx : Int,
  resolution : Int,
  component_info : ComponentInfo,
  tile_ctx : TileDecodeContext,
  storage : DecompositionStorage,
  header : Header,
) -> Unit raise DecodeError {
  let sub_band = storage.sub_bands[sub_band_idx]
  let dequantization_step : Float = if component_info.quantization_info.quantization_style ==
    NoQuantization {
    1.0
  } else {
    let (exponent, mantissa) = component_info.exponent_mantissa(
      sub_band.sub_band_type,
      resolution,
    )
    let r_b = {
      let log_gain = match sub_band.sub_band_type {
        LowLow => 0
        LowHigh => 1
        HighLow => 1
        HighHigh => 2
      }
      component_info.size_info.precision + log_gain
    }
    pow2i(r_b - exponent) * ((1.0 : Float) + Float::from_int(mantissa) / 2048.0)
  }
  let num_bitplanes = {
    let (exponent, _) = component_info.exponent_mantissa(
      sub_band.sub_band_type,
      resolution,
    )
    // Equation (E-2)
    let sum = component_info.quantization_info.guard_bits + exponent
    if sum > 0xFFFF || sum < 1 {
      raise Decoding(InvalidBitplaneCount)
    }
    let num_bitplanes = sum - 1
    if num_bitplanes > MAX_BITPLANE_COUNT {
      raise Decoding(TooManyBitplanes)
    }
    num_bitplanes
  }
  let coefficients = storage.coefficients.data
  let sb_width = sub_band.rect.width()
  let base_end = sub_band.coefficients_end
  for p in sub_band.precincts_start..<sub_band.precincts_end {
    let precinct = storage.precincts[p]
    for cb in precinct.code_blocks_start..<precinct.code_blocks_end {
      let code_block = storage.code_blocks[cb]
      bitplane_decode(
        code_block,
        sub_band.sub_band_type,
        num_bitplanes,
        component_info.coding_style.parameters.code_block_style,
        tile_ctx,
        storage,
        header.strict,
      )

      // Turn the signs and magnitudes into singular coefficients and
      // copy them into the sub-band.

      let x_offset = code_block.rect.x0 - sub_band.rect.x0
      let y_offset = code_block.rect.y0 - sub_band.rect.y0
      let mut base_idx = sub_band.coefficients_start +
        (y_offset * sb_width).reinterpret_as_int() +
        x_offset.reinterpret_as_int()
      let bp = tile_ctx.bit_plane_decode_context
      let width = bp.width
      let padded_width = bp.padded_width
      let decoded = bp.coefficients
      for row in 0..<bp.height {
        if base_idx > base_end {
          abort("slice index out of range")
        }
        let n = if base_end - base_idx < width {
          base_end - base_idx
        } else {
          width
        }
        let src = (row + COEFFICIENTS_PADDING) * padded_width +
          COEFFICIENTS_PADDING
        if n > 0 &&
          (src + n > decoded.length() || base_idx + n > coefficients.length()) {
          abort("index out of bounds")
        }
        for i in 0..<n {
          let output = Float::from_int(
            coefficient_get(decoded.unsafe_get(src + i)),
          )
          coefficients.unsafe_set(base_idx + i, output * dequantization_step)
        }
        base_idx += sb_width.reinterpret_as_int()
      }
    }
  }
}

///|
fn apply_sign_shift(
  channel_data : Array[ComponentData],
  component_infos : Array[ComponentInfo],
) -> Unit {
  let n = if channel_data.length() < component_infos.length() {
    channel_data.length()
  } else {
    component_infos.length()
  }
  for i in 0..<n {
    let channel = channel_data[i]
    let component_info = component_infos[i]
    let offset = Float::from_uint(
      shl_u32(1, component_info.size_info.precision - 1),
    )
    let data = channel.container.data
    // `chunks_exact_mut(8)` over the padded buffer.
    let len = data.length() / 8 * 8
    for j in 0..<len {
      data[j] = data[j] + offset
    }
  }
}

///|
fn store(
  tile : Tile,
  header : Header,
  tile_ctx : TileDecodeContext,
  channel_data : ComponentData,
  component_info : ComponentInfo,
) -> Unit {
  let idwt_output = tile_ctx.idwt_output
  let component_tile = ComponentTile::new(tile, component_info)
  let resolution_tile = ResolutionTile::new(
    component_tile,
    (
      component_info.num_resolution_levels() -
      1 -
      header.skipped_resolution_levels
    ) &
    0xFF,
  )
  let scale_x = component_info.size_info.horizontal_resolution
  let scale_y = component_info.size_info.vertical_resolution
  let image_x_offset = header.size_data.image_area_x_offset
  let image_y_offset = header.size_data.image_area_y_offset
  let container = channel_data.container.data
  let coefficients = idwt_output.coefficients.data
  if scale_x == 1 && scale_y == 1 {
    // If no sub-sampling, use a fast path where we copy rows of coefficients
    // at once.

    // The rect of the IDWT output corresponds to the rect of the highest
    // decomposition level of the tile, which is usually not 1:1 aligned
    // with the actual tile rectangle. We also need to account for the
    // offset of the reference grid.

    let skip_x = saturating_sub_u32(image_x_offset, idwt_output.rect.x0).reinterpret_as_int()
    let skip_y = saturating_sub_u32(image_y_offset, idwt_output.rect.y0).reinterpret_as_int()
    let in_width = idwt_output.rect.width().reinterpret_as_int()
    let in_rows = idwt_output.coefficients.len / in_width
    let in_take = idwt_output.rect.height().reinterpret_as_int()
    let image_width = header.size_data.image_width().reinterpret_as_int()
    let out_rows = container.length() / image_width
    let out_skip = saturating_sub_u32(resolution_tile.rect.y0, image_y_offset).reinterpret_as_int()
    let out_x = saturating_sub_u32(resolution_tile.rect.x0, image_x_offset).reinterpret_as_int()
    let mut in_row = skip_y
    let mut out_row = out_skip
    let mut taken = 0
    while in_row < in_rows && taken < in_take && out_row < out_rows {
      if skip_x > in_width {
        abort("slice index out of range")
      }
      let len = in_width - skip_x
      if out_x + len > image_width {
        abort("slice index out of range")
      }
      coefficients.blit_to(
        container,
        len~,
        src_offset=in_row * in_width + skip_x,
        dst_offset=out_row * image_width + out_x,
      )
      in_row += 1
      out_row += 1
      taken += 1
    }
  } else {
    let image_width = header.size_data.image_width()
    let image_height = header.size_data.image_height()
    let x_shrink_factor = header.size_data.x_shrink_factor
    let y_shrink_factor = header.size_data.y_shrink_factor
    let x_offset = div_ceil_u32(
      header.size_data.image_area_x_offset,
      x_shrink_factor,
    )
    let y_offset = div_ceil_u32(
      header.size_data.image_area_y_offset,
      y_shrink_factor,
    )
    let in_width = idwt_output.rect.width().reinterpret_as_int()
    let scale_x = scale_x.reinterpret_as_uint()
    let scale_y = scale_y.reinterpret_as_uint()

    // Otherwise, copy sample by sample.
    let mut y = resolution_tile.rect.y0
    while y < resolution_tile.rect.y1 {
      let relative_y = (y - component_tile.rect.y0).reinterpret_as_int()
      let reference_grid_y = scale_y * y / y_shrink_factor
      let mut x = resolution_tile.rect.x0
      while x < resolution_tile.rect.x1 {
        let relative_x = (x - component_tile.rect.x0).reinterpret_as_int()
        let reference_grid_x = scale_x * x / x_shrink_factor
        let sample = coefficients[relative_y * in_width + relative_x]
        let x_end = min_u32(reference_grid_x + scale_x, image_width + x_offset)
        let mut x_position = max_u32(reference_grid_x, x_offset)
        while x_position < x_end {
          let y_end = min_u32(
            reference_grid_y + scale_y,
            image_height + y_offset,
          )
          let mut y_position = max_u32(reference_grid_y, y_offset)
          while y_position < y_end {
            let pos = (y_position - y_offset).reinterpret_as_int() *
              image_width.reinterpret_as_int() +
              (x_position - x_offset).reinterpret_as_int()
            container[pos] = sample
            y_position += 1
          }
          x_position += 1
        }
        x += 1
      }
      y += 1
    }
  }
}

///|
fn saturating_sub_u32(a : UInt, b : UInt) -> UInt {
  if a > b {
    a - b
  } else {
    0
  }
}
