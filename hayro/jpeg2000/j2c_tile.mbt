// Port of `hayro-jpeg2000/src/j2c/tile.rs`: creating tiles and parsing their
// constituent tile parts.

///|
/// A single tile in the image.
// `idx` is only read by upstream's `trace!` logging
// (hayro-jpeg2000/src/j2c/decode.rs:47); logging is not ported.
#warnings("-unused_field")
priv struct Tile {
  /// The index of the tile, in row-major order.
  idx : UInt
  /// The concatenated tile parts that contain all the information for all
  /// constituent codeblocks.
  tile_parts : Array[TilePart]
  /// Parameters for each component. In most cases, those are directly
  /// inherited from the main header. But in some cases, individual tiles
  /// might override them.
  component_infos : Array[ComponentInfo]
  /// The rectangle making up the area of the tile. `x1` and `y1` are
  /// exclusive.
  rect : IntRect
  mut progression_order : ProgressionOrder
  mut num_layers : Int
  mut mct : Bool
}

///|
/// A tile part where packet headers and packet data are separated.
priv struct SeparatedTilePart {
  headers : Array[BitReader]
  mut active_header_reader : Int
  body : BitReader
}

///|
priv enum TilePart {
  /// A tile part where packet headers and packet data are interleaved.
  Merged(BitReader)
  Separated(SeparatedTilePart)
}

///|
fn TilePart::clone(self : TilePart) -> TilePart {
  match self {
    Merged(m) => Merged(m.clone())
    Separated(s) =>
      Separated({
        headers: s.headers.map(h => h.clone()),
        active_header_reader: s.active_header_reader,
        body: s.body.clone(),
      })
  }
}

///|
fn TilePart::header(self : TilePart) -> BitReader {
  match self {
    Merged(m) => m
    Separated(s) => {
      if s.headers[s.active_header_reader].at_end() &&
        s.headers.length() - 1 > s.active_header_reader {
        s.active_header_reader += 1
      }
      s.headers[s.active_header_reader]
    }
  }
}

///|
fn TilePart::body(self : TilePart) -> BitReader {
  match self {
    Merged(m) => m
    Separated(s) => s.body
  }
}

///|
fn Tile::new(idx : UInt, header : Header) -> Tile {
  let rect = {
    let size_data = header.size_data
    let x_coord = size_data.tile_x_coord(idx)
    let y_coord = size_data.tile_y_coord(idx)

    // See B-7, B-8, B-9 and B-10.
    let x0 = max_u32(
      size_data.tile_x_offset + x_coord * size_data.tile_width,
      size_data.image_area_x_offset,
    )
    let y0 = max_u32(
      size_data.tile_y_offset + y_coord * size_data.tile_height,
      size_data.image_area_y_offset,
    )

    // Note that `x1` and `y1` are exclusive.
    let x1 = min_u32(
      size_data.tile_x_offset + (x_coord + 1) * size_data.tile_width,
      size_data.reference_grid_width,
    )
    let y1 = min_u32(
      size_data.tile_y_offset + (y_coord + 1) * size_data.tile_height,
      size_data.reference_grid_height,
    )
    IntRect::from_ltrb(x0, y0, x1, y1)
  }
  {
    idx,
    // Will be filled once we start parsing.
    tile_parts: [],
    rect,
    // By default, each tile inherits the settings from the main
    // header. When parsing the tile parts, some of these settings
    // might be overridden.
    component_infos: header.component_infos.map(c => c.clone()),
    progression_order: header.global_coding_style.progression_order,
    mct: header.global_coding_style.mct,
    num_layers: header.global_coding_style.num_layers,
  }
}

///|
fn Tile::component_tiles(self : Tile) -> Array[ComponentTile] {
  self.component_infos.map(i => ComponentTile::new(self, i))
}

///|
/// Create the tiles and parse their constituent tile parts.
fn parse_tiles(
  reader : BitReader,
  main_header : Header,
) -> Array[Tile] raise DecodeError {
  let num_tiles = main_header.size_data.num_tiles()
  let tiles = []
  for idx in 0U..<num_tiles {
    tiles.push(Tile::new(idx, main_header))
  }
  let mut tile_part_idx = 0
  parse_tile_part(reader, main_header, tiles, tile_part_idx)
  tile_part_idx += 1
  while reader.peek_marker() == Some(SOT) {
    parse_tile_part(reader, main_header, tiles, tile_part_idx)
    tile_part_idx += 1
  }
  if main_header.strict && reader.read_marker() != EOC {
    raise Marker(Expected("EOC"))
  }
  tiles
}

///|
fn parse_tile_part(
  reader : BitReader,
  main_header : Header,
  tiles : Array[Tile],
  tile_part_idx : Int,
) -> Unit raise DecodeError {
  if reader.read_marker() != SOT {
    raise Marker(Expected("SOT"))
  }
  guard sot_marker(reader) is Some(tile_part_header) else {
    raise Marker(ParseFailure("SOT"))
  }
  if tile_part_header.tile_index.reinterpret_as_uint() >=
    main_header.size_data.num_tiles() {
    raise Tile(InvalidIndex)
  }
  let data_len : Int64 = if tile_part_header.tile_part_length == 0 {
    match reader.tail() {
      Some(d) => d.length().to_int64()
      None => 0
    }
  } else {
    // Subtract 12 to account for the marker length.
    let len = tile_part_header.tile_part_length
      .to_uint64()
      .reinterpret_as_int64()
    if len < 12 {
      raise Tile(Invalid)
    }
    len - 12
  }
  let start = reader.offset()
  let tile = tiles[tile_part_header.tile_index]
  let num_components = tile.component_infos.length()
  let ppt_headers : Array[PptMarkerData] = []
  while true {
    guard reader.peek_marker() is Some(marker) else {
      return if main_header.strict { raise Marker(Invalid) } else { () }
    }
    match marker {
      SOD => {
        reader.read_marker() |> ignore
        break
      }
      // COD, COC, QCD and QCC should only be used in the _first_
      // tile-part header, if they appear at all.
      COD => {
        reader.read_marker() |> ignore
        guard cod_marker(reader) is Some(cod) else {
          raise Marker(ParseFailure("COD"))
        }
        tile.mct = cod.mct
        tile.num_layers = cod.num_layers
        tile.progression_order = cod.progression_order
        for component in tile.component_infos {
          component.coding_style.flags.raw = component.coding_style.flags.raw |
            cod.component_parameters.flags.raw
          component.coding_style.parameters = cod.component_parameters.parameters
        }
      }
      COC => {
        reader.read_marker() |> ignore
        guard coc_marker(reader, num_components & 0xFFFF)
          is Some((component_index, coc)) else {
          raise Marker(ParseFailure("COC"))
        }
        guard component_index < tile.component_infos.length() else {
          raise Validation(InvalidComponentMetadata)
        }
        let old = tile.component_infos[component_index]
        old.coding_style.parameters = coc.parameters
        old.coding_style.flags.raw = old.coding_style.flags.raw | coc.flags.raw
      }
      QCD => {
        reader.read_marker() |> ignore
        guard qcd_marker(reader) is Some(qcd) else {
          raise Marker(ParseFailure("QCD"))
        }
        for component_info in tile.component_infos {
          component_info.quantization_info = qcd
        }
      }
      QCC => {
        reader.read_marker() |> ignore
        guard qcc_marker(reader, num_components & 0xFFFF)
          is Some((component_index, qcc)) else {
          raise Marker(ParseFailure("QCC"))
        }
        guard component_index < tile.component_infos.length() else {
          raise Validation(InvalidComponentMetadata)
        }
        tile.component_infos[component_index].quantization_info = qcc
      }
      EOC => break
      PPT => {
        if main_header.ppm_packets.length() != 0 {
          raise Tile(PpmPptConflict)
        }
        reader.read_marker() |> ignore
        guard ppt_marker(reader) is Some(p) else {
          raise Marker(ParseFailure("PPT"))
        }
        ppt_headers.push(p)
      }
      PLT => {
        // Can be inferred ourselves.
        reader.read_marker() |> ignore
        guard skip_marker_segment(reader) is Some(_) else {
          raise Marker(ParseFailure("PLT"))
        }
      }
      COM => {
        reader.read_marker() |> ignore
        guard skip_marker_segment(reader) is Some(_) else {
          raise Marker(ParseFailure("COM"))
        }
      }
      0x30..<=0x3F =>
        // "All markers with the marker code between 0xFF30 and 0xFF3F
        // have no marker segment parameters. They shall be skipped by
        // the decoder."
        reader.read_marker() |> ignore
      // skip_marker_segment(reader);
      _ => raise Marker(Unsupported)
    }
  }
  let consumed = (reader.offset() - start).to_int64()
  if data_len < consumed {
    return if main_header.strict { raise Tile(Invalid) } else { () }
  }
  let remaining_bytes = data_len - consumed
  let ppt_headers = stable_sort_by_key(ppt_headers, p => p.sequence_idx)
  let headers = ppt_headers.map(i => BitReader::new(i.data))
  if tile_part_idx < main_header.ppm_packets.length() {
    headers.push(BitReader::new(main_header.ppm_packets[tile_part_idx].data))
  }
  guard remaining_bytes <= 0x7FFFFFFFL &&
    reader.read_bytes(remaining_bytes.to_int()) is Some(data) else {
    raise Tile(Invalid)
  }
  let tile_part = if headers.length() != 0 {
    Separated({ headers, active_header_reader: 0, body: BitReader::new(data), })
  } else {
    Merged(BitReader::new(data))
  }
  tile.tile_parts.push(tile_part)
}

///|
/// A tile, instantiated to a specific component.
priv struct ComponentTile {
  tile : Tile
  /// The information of the component of the tile.
  component_info : ComponentInfo
  /// The rectangle of the component tile.
  rect : IntRect
}

///|
fn ComponentTile::new(
  tile : Tile,
  component_info : ComponentInfo,
) -> ComponentTile {
  let tile_rect = tile.rect
  let rect = if component_info.size_info.horizontal_resolution == 1 &&
    component_info.size_info.vertical_resolution == 1 {
    tile_rect
  } else {
    // As described in B-12.
    let hr = component_info.size_info.horizontal_resolution.reinterpret_as_uint()
    let vr = component_info.size_info.vertical_resolution.reinterpret_as_uint()
    let t_x0 = div_ceil_u32(tile_rect.x0, hr)
    let t_y0 = div_ceil_u32(tile_rect.y0, vr)
    let t_x1 = div_ceil_u32(tile_rect.x1, hr)
    let t_y1 = div_ceil_u32(tile_rect.y1, vr)
    IntRect::from_ltrb(t_x0, t_y0, t_x1, t_y1)
  }
  { tile, component_info, rect, }
}

///|
fn ComponentTile::resolution_tiles(
  self : ComponentTile,
) -> Array[ResolutionTile] {
  Array::makei(
    self.component_info.coding_style.parameters.num_resolution_levels,
    r => ResolutionTile::new(self, r),
  )
}

///|
/// A tile instantiated to a specific resolution of a component tile.
priv struct ResolutionTile {
  /// The resolution of the tile.
  resolution : Int
  /// The decomposition level of the tile.
  decomposition_level : Int
  /// The underlying component tile.
  component_tile : ComponentTile
  /// The rectangle of the resolution tile.
  rect : IntRect
}

///|
fn ResolutionTile::new(
  component_tile : ComponentTile,
  resolution : Int,
) -> ResolutionTile {
  if !(component_tile.component_info.coding_style.parameters.num_resolution_levels >
    resolution) {
    abort(
      "assertion failed: component_tile.component_info.coding_style.parameters.num_resolution_levels > resolution",
    )
  }
  let rect = {
    // See formula B-14.
    let n_l = component_tile.component_info.coding_style.parameters.num_decomposition_levels
    let div = 1UL << (n_l - resolution)
    let tx0 = div_ceil_u64(component_tile.rect.x0.to_uint64(), div).to_uint()
    let ty0 = div_ceil_u64(component_tile.rect.y0.to_uint64(), div).to_uint()
    let tx1 = div_ceil_u64(component_tile.rect.x1.to_uint64(), div).to_uint()
    let ty1 = div_ceil_u64(component_tile.rect.y1.to_uint64(), div).to_uint()
    IntRect::from_ltrb(tx0, ty0, tx1, ty1)
  }

  // Decomposition level and resolution level are inversely related
  // to each other. In addition to that, there is always one more
  // resolution than decomposition levels (resolution level 0 only
  // include the LL subband of the N_L decomposition, resolution level
  // 1 includes the HL, LH and HH subbands of the N_L decomposition.
  let decomposition_level = if resolution == 0 {
    component_tile.component_info.coding_style.parameters.num_decomposition_levels
  } else {
    (
      component_tile.component_info.coding_style.parameters.num_decomposition_levels -
      (resolution - 1)
    ) &
    0xFF
  }
  { resolution, decomposition_level, component_tile, rect, }
}

///|
fn ResolutionTile::sub_band_rect(
  self : ResolutionTile,
  sub_band_type : SubBandType,
) -> IntRect {
  // This is the only permissible sub-band type for the given resolution.
  if self.resolution == 0 && sub_band_type != LowLow {
    abort("assertion failed: sub_band_type == SubBandType::LowLow")
  }

  // Formula B-15.

  let xo_b : UInt64 = if sub_band_type is (HighLow | HighHigh) { 1 } else { 0 }
  let yo_b : UInt64 = if sub_band_type is (LowHigh | HighHigh) { 1 } else { 0 }
  let mut numerator_x = 0UL
  let mut numerator_y = 0UL

  // If decomposition level is 0, xo_b and yo_b are 0 as well.
  if self.decomposition_level > 0 {
    numerator_x = pow2_u64(self.decomposition_level - 1) * xo_b
    numerator_y = pow2_u64(self.decomposition_level - 1) * yo_b
  }
  let denominator = pow2_u64(self.decomposition_level)
  let tbx_0 = div_ceil_u64(
    saturating_sub_u64(self.component_tile.rect.x0.to_uint64(), numerator_x),
    denominator,
  ).to_uint()
  let tbx_1 = div_ceil_u64(
    saturating_sub_u64(self.component_tile.rect.x1.to_uint64(), numerator_x),
    denominator,
  ).to_uint()
  let tby_0 = div_ceil_u64(
    saturating_sub_u64(self.component_tile.rect.y0.to_uint64(), numerator_y),
    denominator,
  ).to_uint()
  let tby_1 = div_ceil_u64(
    saturating_sub_u64(self.component_tile.rect.y1.to_uint64(), numerator_y),
    denominator,
  ).to_uint()
  IntRect::from_ltrb(tbx_0, tby_0, tbx_1, tby_1)
}

///|
/// `2_u64.pow(n)` (wrapping, as in a release build).
fn pow2_u64(n : Int) -> UInt64 {
  if n >= 64 {
    0
  } else {
    1UL << n
  }
}

///|
/// `2_u32.pow(n)` (wrapping, as in a release build).
fn pow2_u32(n : Int) -> UInt {
  if n >= 32 {
    0
  } else {
    1U << n
  }
}

///|
fn saturating_sub_u64(a : UInt64, b : UInt64) -> UInt64 {
  if a > b {
    a - b
  } else {
    0
  }
}

///|
/// The exponent for determining the horizontal size of a precinct.
///
/// `PPx` in the specification.
fn ResolutionTile::precinct_exponent_x(self : ResolutionTile) -> Int {
  self.component_tile.component_info.coding_style.parameters.precinct_exponents[self.resolution].0
}

///|
/// The exponent for determining the vertical size of a precinct.
///
/// `PPx` in the specification.
fn ResolutionTile::precinct_exponent_y(self : ResolutionTile) -> Int {
  self.component_tile.component_info.coding_style.parameters.precinct_exponents[self.resolution].1
}

///|
fn ResolutionTile::num_precincts_x(self : ResolutionTile) -> UInt {
  // See B-16.
  let { x0, x1, .. } = self.rect
  if x0 == x1 {
    0
  } else {
    let p = pow2_u32(self.precinct_exponent_x())
    div_ceil_u32(x1, p) - x0 / p
  }
}

///|
fn ResolutionTile::num_precincts_y(self : ResolutionTile) -> UInt {
  // See B-16.
  let { y0, y1, .. } = self.rect
  if y0 == y1 {
    0
  } else {
    let p = pow2_u32(self.precinct_exponent_y())
    div_ceil_u32(y1, p) - y0 / p
  }
}

///|
fn ResolutionTile::num_precincts(self : ResolutionTile) -> UInt64 {
  self.num_precincts_x().to_uint64() * self.num_precincts_y().to_uint64()
}

///|
/// `u32::checked_next_multiple_of`.
fn checked_next_multiple_of_u32(v : UInt, rhs : UInt) -> UInt? {
  if rhs == 0 {
    return None
  }
  let r = v % rhs
  if r == 0 {
    Some(v)
  } else {
    let res = v.to_uint64() + (rhs - r).to_uint64()
    if res > 0xFFFFFFFFUL {
      None
    } else {
      Some(res.to_uint())
    }
  }
}

///|
/// `u32::next_multiple_of` (wrapping, as in a release build).
fn next_multiple_of_u32(v : UInt, rhs : UInt) -> UInt {
  let r = v % rhs
  if r == 0 {
    v
  } else {
    v + (rhs - r)
  }
}

///|
/// `u32::is_multiple_of`.
fn is_multiple_of_u32(v : UInt, rhs : UInt) -> Bool {
  if rhs == 0 {
    v == 0
  } else {
    v % rhs == 0
  }
}

///|
/// Return the data of the precincts in this resolution tile.
fn ResolutionTile::precincts(self : ResolutionTile) -> Array[PrecinctData]? {
  let num_precincts_y = self.num_precincts_y()
  let num_precincts_x = self.num_precincts_x()
  let mut ppx = self.precinct_exponent_x()
  let mut ppy = self.precinct_exponent_y()
  let mut y_start = self.rect.y0 / shl_u32(1, ppy) * shl_u32(1, ppy)
  let mut x_start = self.rect.x0 / shl_u32(1, ppx) * shl_u32(1, ppx)

  // It is unclear why this is necessary, but it is. The spec only
  // mentions that ppx/ppy must be decreased when calculating codeblock
  // dimensions, but not that it's necessary for precincts as well.
  if self.resolution > 0 {
    if ppx == 0 || ppy == 0 {
      return None
    }
    ppx = ppx - 1
    ppy = ppy - 1
    x_start = x_start / 2
    y_start = y_start / 2
  }
  let ppx_pow2 = shl_u32(1, ppx)
  let ppy_pow2 = shl_u32(1, ppy)
  let nl_minus_r = (
      self.component_tile.component_info.num_decomposition_levels() -
      self.resolution
    ) &
    0xFF
  let ex = self.precinct_exponent_x() + nl_minus_r
  if ex > 0xFF || ex >= 32 {
    return None
  }
  let x_stride = 1U << ex
  let ey = self.precinct_exponent_y() + nl_minus_r
  if ey > 0xFF || ey >= 32 {
    return None
  }
  let y_stride = 1U << ey
  let hx = self.component_tile.component_info.size_info.horizontal_resolution.to_uint64() *
    x_stride.to_uint64()
  if hx > 0xFFFFFFFFUL {
    return None
  }
  let precinct_x_step = hx.to_uint()
  let vy = self.component_tile.component_info.size_info.vertical_resolution.to_uint64() *
    y_stride.to_uint64()
  if vy > 0xFFFFFFFFUL {
    return None
  }
  let precinct_y_step = vy.to_uint()

  // These variables are used to map the start coordinates of each
  // precinct _on the reference grid_. Remember that the first
  // precinct in each row/column is at the start position of the tile
  // which might not be a multiple of precinct exponent, but all subsequent
  // precincts are at a multiple of the exponent.
  let mut r_x = self.component_tile.tile.rect.x0
  let mut r_y = self.component_tile.tile.rect.y0

  // The second part of the condition in the formula in B.12.1.3. If it
  // is divisible, then we can't take the x/y position of the tile
  // as the start of the precinct, but instead have to advance to the
  // next multiple.
  if !is_multiple_of_u32(r_x, precinct_x_step) &&
    is_multiple_of_u32(self.rect.x0 * shl_u32(1, nl_minus_r), precinct_x_step) {
    guard checked_next_multiple_of_u32(r_x, precinct_x_step) is Some(v) else {
      return None
    }
    r_x = v
  }

  // Same as above.
  if !is_multiple_of_u32(r_y, precinct_y_step) &&
    is_multiple_of_u32(self.rect.y0 * shl_u32(1, nl_minus_r), precinct_y_step) {
    guard checked_next_multiple_of_u32(r_y, precinct_y_step) is Some(v) else {
      return None
    }
    r_y = v
  }
  let out = []
  for y in 0U..<num_precincts_y {
    let y0 = y * ppy_pow2 + y_start
    let mut r_x = r_x
    for x in 0U..<num_precincts_x {
      let x0 = x * ppx_pow2 + x_start
      out.push({
        r_x,
        r_y,
        rect: IntRect::from_xywh(x0, y0, ppx_pow2, ppy_pow2),
        idx: num_precincts_x.to_uint64() * y.to_uint64() + x.to_uint64(),
      })

      // If r_x is already aligned, we simply step by `precinct_x_step`.
      // Otherwise (can only be the case for precincts in the first
      // row or column), align to the next multiple.
      r_x = next_multiple_of_u32(r_x + 1, precinct_x_step)
    }

    // Same as for r_x.
    r_y = next_multiple_of_u32(r_y + 1, precinct_y_step)
  }
  Some(out)
}

///|
fn ResolutionTile::code_block_width(self : ResolutionTile) -> UInt {
  // See B-17.
  let xcb = self.component_tile.component_info.coding_style.parameters.code_block_width
  let limit = if self.resolution > 0 {
    (self.precinct_exponent_x() - 1) & 0xFF
  } else {
    self.precinct_exponent_x()
  }
  pow2_u32(if xcb < limit { xcb } else { limit })
}

///|
fn ResolutionTile::code_block_height(self : ResolutionTile) -> UInt {
  // See B-18.
  let ycb = self.component_tile.component_info.coding_style.parameters.code_block_height
  let limit = if self.resolution > 0 {
    (self.precinct_exponent_y() - 1) & 0xFF
  } else {
    self.precinct_exponent_y()
  }
  pow2_u32(if ycb < limit { ycb } else { limit })
}

///|
priv struct TilePartHeader {
  tile_index : Int
  tile_part_length : UInt
}

///|
priv struct PptMarkerData {
  data : BytesView
  sequence_idx : Int
}

///|
/// PPT marker (A.7.5).
fn ppt_marker(reader : BitReader) -> PptMarkerData? {
  guard reader.read_u16() is Some(len) && len >= 2 else { return None }
  let length = len - 2
  guard length >= 1 else { return None }
  let header_len = length - 1
  guard reader.read_byte() is Some(sequence_idx) else { return None }
  guard reader.read_bytes(header_len) is Some(data) else { return None }
  Some({ data, sequence_idx, })
}

///|
/// SOT marker (A.4.2).
fn sot_marker(reader : BitReader) -> TilePartHeader? {
  // Length.
  guard reader.read_u16() is Some(_) else { return None }
  guard reader.read_u16() is Some(tile_index) else { return None }
  guard reader.read_u32() is Some(tile_part_length) else { return None }

  // We infer those ourselves.
  guard reader.read_byte() is Some(_tile_part_index) else { return None }
  guard reader.read_byte() is Some(_num_tile_parts) else { return None }
  Some({ tile_index, tile_part_length, })
}
