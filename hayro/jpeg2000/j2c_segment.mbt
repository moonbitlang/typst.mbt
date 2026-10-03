// Port of `hayro-jpeg2000/src/j2c/segment.rs`: parsing of layers and their
// segments, as specified in Annex B.

///|
const MAX_BITPLANE_COUNT : Int = 32

///|
fn parse_segments(
  tile : Tile,
  progression_iterator : () -> ProgressionData?,
  header : Header,
  storage : DecompositionStorage,
) -> Unit raise DecodeError {
  for tile_part in tile.tile_parts {
    if parse_inner(
        tile_part.clone(),
        progression_iterator,
        tile.component_infos,
        storage,
      )
      is None &&
      header.strict {
      raise Tile(Invalid)
    }
  }
}

///|
fn parse_inner(
  tile_part : TilePart,
  progression_iterator : () -> ProgressionData?,
  component_infos : Array[ComponentInfo],
  storage : DecompositionStorage,
) -> Unit? {
  while !tile_part.header().at_end() {
    guard progression_iterator() is Some(progression_data) else { return None }
    let resolution = progression_data.resolution
    let component_info = component_infos[progression_data.component]
    let tile_decompositions = storage.tile_decompositions[progression_data.component]
    let sub_band_iter = tile_decompositions.sub_band_iter(
      resolution,
      storage.decompositions,
    )
    let body_reader = tile_part.body()
    if component_info.coding_style.flags.may_use_sop_markers() &&
      body_reader.peek_marker() == Some(SOP) {
      let _ = body_reader.read_marker() catch { _ => return None }
      guard body_reader.skip_bytes(4) is Some(_) else { return None }
    }
    let header_reader = tile_part.header()
    guard header_reader.read_bits_with_stuffing(1) is Some(first_bit) else {
      return None
    }
    let zero_length = first_bit == 0

    // B.10.3 Zero length packet
    // "The first bit in the packet header denotes whether the packet has a length of zero
    // (empty packet). The value 0 indicates a zero length; no code-blocks are included in this
    // case. The value 1 indicates a non-zero length."
    if !zero_length {
      for sub_band in sub_band_iter {
        guard resolve_segments(
            sub_band, progression_data, header_reader, storage, component_info,
          )
          is Some(_) else {
          return None
        }
      }
    }
    header_reader.align()
    if component_info.coding_style.flags.uses_eph_marker() {
      let marker = header_reader.read_marker() catch { _ => return None }
      if marker != EPH {
        return None
      }
    }

    // Now read the packet body.
    let body_reader = tile_part.body()
    if !zero_length {
      for sub_band in sub_band_iter {
        let sub_band = storage.sub_bands[sub_band]
        let precinct = storage.precincts[sub_band.precincts_start +
          progression_data.precinct.to_int()]
        for cb in precinct.code_blocks_start..<precinct.code_blocks_end {
          let code_block = storage.code_blocks[cb]
          let layer = storage.layers[code_block.layers_start +
            progression_data.layer_num]
          if layer.segments is Some((start, end)) {
            for s in start..<end {
              let segment = storage.segments[s]
              guard body_reader.read_bytes(
                  segment.data_length.reinterpret_as_int(),
                )
                is Some(data) else {
                return None
              }
              segment.data = data
            }
          }
        }
      }
    }
  }
  Some(())
}

///|
fn resolve_segments(
  sub_band_dx : Int,
  progression_data : ProgressionData,
  reader : BitReader,
  storage : DecompositionStorage,
  component_info : ComponentInfo,
) -> Unit? {
  // We don't support more than 32-bit precision.
  let max_coding_passes = 1 + 3 * (MAX_BITPLANE_COUNT - 1)
  let sub_band = storage.sub_bands[sub_band_dx]
  let num_precincts = sub_band.precincts_end - sub_band.precincts_start
  if progression_data.precinct >= num_precincts.to_uint64() {
    // An invalid file could trigger this code path.
    // warn!("progression data yielded invalid precinct index");

    return None
  }
  let precinct = storage.precincts[sub_band.precincts_start +
    progression_data.precinct.to_int()]
  for cb in precinct.code_blocks_start..<precinct.code_blocks_end {
    let code_block = storage.code_blocks[cb]
    // B.10.4 Code-block inclusion
    let is_included = if code_block.has_been_included {
      // "For code-blocks that have been included in a previous packet,
      // a single bit is used to represent the information, where a 1
      // means that the code-block is included in this layer and a 0 means
      // that it is not."
      guard reader.read_bits_with_stuffing(1) is Some(b) else { return None }
      b == 1
    } else {
      // "For code-blocks that have not been previously included in any packet,
      // this information is signalled with a separate tag tree code for each precinct
      // as confined to a sub-band. The values in this tag tree are the number of the
      // layer in which the current code-block is first included. Although the exact
      // sequence of bits that represent the inclusion tag tree appears in the bit
      // stream, only the bits needed for determining whether the code-block is
      // included are placed in the packet header. If some of the tag tree is already
      // known from previous code-blocks or previous layers, it is not repeated.
      // Likewise, only as much of the tag tree as is needed to determine inclusion in
      // the current layer is included. If a code-block is not included until a later
      // layer, then only a partial tag tree is included at that point in the bit
      // stream."
      guard precinct.code_inclusion_tree.read(
          code_block.x_idx,
          code_block.y_idx,
          reader,
          progression_data.layer_num.reinterpret_as_uint() + 1,
          storage.tag_tree_nodes,
        )
        is Some(v) else {
        return None
      }
      v <= progression_data.layer_num.reinterpret_as_uint()
    }
    if !is_included {
      continue
    }
    let layer = storage.layers[code_block.layers_start +
      progression_data.layer_num]
    let included_first_time = is_included && !code_block.has_been_included

    // B.10.5 Zero bit-plane information
    // "If a code-block is included for the first time, the packet header contains
    // information identifying the actual number of bit-planes used to represent
    // coefficients from the code-block. The maximum number of bit-planes available
    // for the representation of coefficients in any sub-band, b, is given by Mb as
    // defined in Equation (E-2). In general, however, the
    // number of actual bit-planes for which coding passes are generated is Mb – P,
    // where the number of missing most significant bit-planes, P, may vary from
    // code-block to code-block; these missing bit-planes are all taken to be zero. The
    // value of P is coded in the packet header with a separate tag tree for every
    // precinct, in the same manner as the code block inclusion information."
    if included_first_time {
      guard precinct.zero_bitplane_tree.read(
          code_block.x_idx,
          code_block.y_idx,
          reader,
          0xFFFFFFFF,
          storage.tag_tree_nodes,
        )
        is Some(v) else {
        return None
      }
      code_block.missing_bit_planes = (v & 0xFF).reinterpret_as_int()
    }
    code_block.has_been_included = code_block.has_been_included || is_included

    // B.10.6 Number of coding passes
    // "The number of coding passes included in this packet from each code-block is
    // identified in the packet header using the codewords shown in Table B.4. This
    // table provides for the possibility of signalling up to 164 coding passes."
    let added_coding_passes = if reader.peak_bits_with_stuffing(9) ==
      Some(0x1ff) {
      guard reader.read_bits_with_stuffing(9) is Some(_) else { return None }
      guard reader.read_bits_with_stuffing(7) is Some(v) else { return None }
      v.reinterpret_as_int() + 37
    } else if reader.peak_bits_with_stuffing(4) == Some(0x0f) {
      guard reader.read_bits_with_stuffing(4) is Some(_) else { return None }
      guard reader.read_bits_with_stuffing(5) is Some(v) else { return None }
      v.reinterpret_as_int() + 6
    } else if reader.peak_bits_with_stuffing(4) == Some(0b1110) {
      guard reader.read_bits_with_stuffing(4) is Some(_) else { return None }
      5
    } else if reader.peak_bits_with_stuffing(4) == Some(0b1101) {
      guard reader.read_bits_with_stuffing(4) is Some(_) else { return None }
      4
    } else if reader.peak_bits_with_stuffing(4) == Some(0b1100) {
      guard reader.read_bits_with_stuffing(4) is Some(_) else { return None }
      3
    } else if reader.peak_bits_with_stuffing(2) == Some(0b10) {
      guard reader.read_bits_with_stuffing(2) is Some(_) else { return None }
      2
    } else if reader.peak_bits_with_stuffing(1) == Some(0) {
      guard reader.read_bits_with_stuffing(1) is Some(_) else { return None }
      1
    } else {
      return None
    }
    let mut k = 0U
    while true {
      guard reader.read_bits_with_stuffing(1) is Some(b) else { return None }
      if b != 1 {
        break
      }
      k += 1
    }
    code_block.l_block = code_block.l_block + k
    let previous_layers_passes = code_block.number_of_coding_passes
    let cumulative_passes = previous_layers_passes + added_coding_passes
    if cumulative_passes > 0xFF {
      return None
    }
    if cumulative_passes > max_coding_passes {
      return None
    }
    let style = component_info.code_block_style()
    fn get_segment_idx(pass_idx : Int) -> Int {
      if style.termination_on_each_pass {
        // If we terminate on each pass, the segment is just the index
        // of the pass.
        pass_idx
      } else if style.selective_arithmetic_coding_bypass {
        // Use the formula derived from the table in the spec.
        segment_idx_for_bypass(pass_idx)
      } else {
        // If none of the above flags is activated, the number of
        // segments just corresponds to the number of layers.
        code_block.non_empty_layer_count
      }
    }

    let start = storage.segments.length()
    fn push_segment(segment : Int, coding_passes_for_segment : Int) -> Unit? {
      if !(coding_passes_for_segment > 0) {
        abort("assertion failed: coding_passes_for_segment > 0")
      }

      // "A codeword segment is the number of bytes contributed to a packet by a
      // code-block. The length of a codeword segment is represented by a binary number of length:
      // bits = Lblock + floor(log_2(coding passes added))
      // where Lblock is a code-block state variable. A separate Lblock is used for each
      // code-block in the precinct. The value of Lblock is initially set to three. The
      // number of bytes contributed by each code-block is preceded by signalling bits
      // that increase the value of Lblock, as needed. A signalling bit of zero indicates
      // the current value of Lblock is sufficient. If there are k ones followed by a
      // zero, the value of Lblock is incremented by k. While Lblock can only increase,
      // the number of bits used to signal the length of the code-block contribution can
      // increase or decrease depending on the number of coding passes included."
      let length_bits = code_block.l_block +
        ilog2_u32(coding_passes_for_segment.reinterpret_as_uint()).reinterpret_as_uint()
      guard reader.read_bits_with_stuffing(
          (length_bits & 0xFF).reinterpret_as_int(),
        )
        is Some(length) else {
        return None
      }
      storage.segments.push({
        idx: segment,
        data_length: length,
        coding_pases: coding_passes_for_segment,
        // Will be set later.
        data: b""[:],
      })
      Some(())
    }

    let mut last_segment = get_segment_idx(previous_layers_passes)
    let mut coding_passes_for_segment = 0
    for coding_pass in previous_layers_passes..<cumulative_passes {
      let segment = get_segment_idx(coding_pass)
      if segment != last_segment {
        guard push_segment(last_segment, coding_passes_for_segment) is Some(_) else {
          return None
        }
        last_segment = segment
        coding_passes_for_segment = 1
      } else {
        coding_passes_for_segment += 1
      }
    }

    // Flush the final segment if applicable.
    if coding_passes_for_segment > 0 {
      guard push_segment(last_segment, coding_passes_for_segment) is Some(_) else {
        return None
      }
    }
    let end = storage.segments.length()
    layer.segments = Some((start, end))
    code_block.number_of_coding_passes = code_block.number_of_coding_passes +
      added_coding_passes
    code_block.non_empty_layer_count = (code_block.non_empty_layer_count + 1) &
      0xFF
  }
  Some(())
}

///|
/// Calculate the segment index for the given pass in arithmetic decoder
/// bypass (see section D.6, Table D.9).
fn segment_idx_for_bypass(pass_idx : Int) -> Int {
  if pass_idx < 10 {
    0
  } else {
    1 +
    2 * ((pass_idx - 10) / 3) +
    (if (pass_idx - 10) % 3 == 2 { 1 } else { 0 })
  }
}
