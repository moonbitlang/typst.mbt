// Port of `hayro-jpeg2000/src/j2c/codestream.rs`: read and decode a JPEG2000
// codestream, as described in Annex A.

///|
const MAX_LAYER_COUNT : Int = 32

///|
const MAX_RESOLUTION_COUNT : Int = 32

///|
const MAX_PRECINCT_EXPONENT : Int = 31

///|
priv struct Header {
  size_data : SizeData
  global_coding_style : CodingStyleDefault
  component_infos : Array[ComponentInfo]
  ppm_packets : Array[PpmPacket]
  skipped_resolution_levels : Int
  /// Whether strict mode is enabled for decoding.
  strict : Bool
}

///|
priv struct PpmMarkerData {
  sequence_idx : Int
  packets : Array[PpmPacket]
}

///|
priv struct PpmPacket {
  data : BytesView
}

///|
fn read_header(
  reader : BitReader,
  settings : DecodeSettings,
) -> Header raise DecodeError {
  if reader.read_marker() != SIZ {
    raise Marker(Expected("SIZ"))
  }
  let size_data = size_marker(reader)
  let mut cod = None
  let mut qcd = None
  let num_components = size_data.component_sizes.length() & 0xFFFF
  let cod_components : Array[CodingStyleComponent?] = Array::make(
    num_components,
    None,
  )
  let qcd_components : Array[QuantizationInfo?] = Array::make(
    num_components,
    None,
  )
  let ppm_markers : Array[PpmMarkerData] = []
  while true {
    guard reader.peek_marker() is Some(marker) else { raise Marker(Invalid) }
    match marker {
      SOT => break
      COD => {
        reader.read_marker() |> ignore
        guard cod_marker(reader) is Some(c) else {
          raise Marker(ParseFailure("COD"))
        }
        cod = Some(c)
      }
      COC => {
        reader.read_marker() |> ignore
        guard coc_marker(reader, num_components) is Some((component_index, coc)) else {
          raise Marker(ParseFailure("COC"))
        }
        if component_index >= cod_components.length() {
          raise Marker(ParseFailure("COC"))
        }
        cod_components[component_index] = Some(coc)
      }
      QCD => {
        reader.read_marker() |> ignore
        guard qcd_marker(reader) is Some(q) else {
          raise Marker(ParseFailure("QCD"))
        }
        qcd = Some(q)
      }
      QCC => {
        reader.read_marker() |> ignore
        guard qcc_marker(reader, num_components) is Some((component_index, qcc)) else {
          raise Marker(ParseFailure("QCC"))
        }
        if component_index >= qcd_components.length() {
          raise Marker(ParseFailure("QCC"))
        }
        qcd_components[component_index] = Some(qcc)
      }
      RGN => {
        reader.read_marker() |> ignore
        guard rgn_marker(reader) is Some(_) else {
          raise Marker(ParseFailure("RGN"))
        }
      }
      TLM => {
        reader.read_marker() |> ignore
        guard tlm_marker(reader) is Some(_) else {
          raise Marker(ParseFailure("TLM"))
        }
      }
      COM => {
        reader.read_marker() |> ignore
        guard com_marker(reader) is Some(_) else {
          raise Marker(ParseFailure("COM"))
        }
      }
      PPM => {
        reader.read_marker() |> ignore
        guard ppm_marker(reader) is Some(p) else {
          raise Marker(ParseFailure("PPM"))
        }
        ppm_markers.push(p)
      }
      CRG => {
        reader.read_marker() |> ignore
        skip_marker_segment(reader) |> ignore
      }
      0x30..=0x3F =>
        // "All markers with the marker code between 0xFF30 and 0xFF3F
        // have no marker segment parameters. They shall be skipped by
        // the decoder."
        reader.read_marker() |> ignore
      // skip_marker_segment(reader);
      _ => raise Marker(Unsupported)
    }
  }
  guard cod is Some(cod) else { raise Marker(Missing("COD")) }
  guard qcd is Some(qcd) else { raise Marker(Missing("QCD")) }
  let component_infos : Array[ComponentInfo] = []
  for idx, csi in size_data.component_sizes {
    let coding_style = match cod_components[idx] {
      Some(c) => {
        let c = c.clone()
        c.flags.raw = c.flags.raw | cod.component_parameters.flags.raw
        c
      }
      None => cod.component_parameters.clone()
    }
    component_infos.push({
      size_info: csi,
      coding_style,
      quantization_info: match qcd_components[idx] {
        Some(q) => q
        None => qcd
      },
    })
  }

  // Components can have different number of resolution levels. In that case, we
  // can only skip as many resolution levels as the component with the smallest
  // number of resolution levels.
  let mut min_num_resolution_levels = component_infos[0].num_resolution_levels()
  for c in component_infos {
    if c.num_resolution_levels() < min_num_resolution_levels {
      min_num_resolution_levels = c.num_resolution_levels()
    }
  }
  let skipped = match settings.target_resolution {
    Some((target_width, target_height)) => {
      let width_log = checked_ilog2_div(size_data.image_width(), target_width)
      let height_log = checked_ilog2_div(
        size_data.image_height(),
        target_height,
      )
      (if width_log < height_log { width_log } else { height_log }) & 0xFF
    }
    None => 0
  }
  let max_skipped = (min_num_resolution_levels - 1) & 0xFF
  let skipped_resolution_levels = if skipped < max_skipped {
    skipped
  } else {
    max_skipped
  }

  // If the user defined a maximum resolution level that is lower than the
  // maximum available one, the final image needs to be shrinked further.
  size_data.x_resolution_shrink_factor = size_data.x_resolution_shrink_factor *
    shl_u32(1, skipped_resolution_levels)
  size_data.y_resolution_shrink_factor = size_data.y_resolution_shrink_factor *
    shl_u32(1, skipped_resolution_levels)
  let ppm_markers = stable_sort_by_key(ppm_markers, p => p.sequence_idx)
  let ppm_packets = []
  for i in ppm_markers {
    for p in i.packets {
      if p.data.length() != 0 {
        ppm_packets.push(p)
      }
    }
  }
  let header = {
    size_data,
    global_coding_style: cod.clone(),
    component_infos,
    ppm_packets,
    skipped_resolution_levels,
    strict: settings.strict,
  }
  validate(header)
  header
}

///|
/// `a.checked_div(b).and_then(|v| v.checked_ilog2()).unwrap_or(0)`.
fn checked_ilog2_div(a : UInt, b : UInt) -> Int {
  if b == 0 {
    return 0
  }
  let v = a / b
  if v == 0 {
    0
  } else {
    31 - v.clz()
  }
}

///|
/// A stable sort by an integer key (Rust's `sort_by` is stable).
fn[T] stable_sort_by_key(items : Array[T], key : (T) -> Int) -> Array[T] {
  let indices = Array::makei(items.length(), i => i)
  indices.sort_by((a, b) => {
    let c = key(items[a]).compare(key(items[b]))
    if c != 0 {
      c
    } else {
      a.compare(b)
    }
  })
  indices.map(i => items[i])
}

///|
fn validate(header : Header) -> Unit raise DecodeError {
  for info in header.component_infos {
    let max_resolution_idx = (
        info.coding_style.parameters.num_resolution_levels - 1
      ) &
      0xFF
    let quantization_style = info.quantization_info.quantization_style
    let num_precinct_exponents = info.quantization_info.step_sizes.length()
    if num_precinct_exponents == 0 {
      raise Validation(MissingPrecinctExponents)
    } else if quantization_style is (NoQuantization | ScalarExpounded) {
      // See the accesses in the `exponent_mantissa` method. The largest
      // access is 1 + (max_resolution_idx - 1) * 3 + 2.

      if max_resolution_idx == 0 {
        if num_precinct_exponents == 0 {
          raise Validation(InsufficientExponents)
        }
      } else if 1 + (max_resolution_idx - 1) * 3 + 2 >= num_precinct_exponents {
        raise Validation(InsufficientExponents)
      }
    }
  }
}

///|
priv struct ComponentInfo {
  size_info : ComponentSizeInfo
  coding_style : CodingStyleComponent
  mut quantization_info : QuantizationInfo
}

///|
fn ComponentInfo::clone(self : ComponentInfo) -> ComponentInfo {
  {
    size_info: self.size_info,
    coding_style: self.coding_style.clone(),
    quantization_info: self.quantization_info,
  }
}

///|
fn ComponentInfo::exponent_mantissa(
  self : ComponentInfo,
  sub_band_type : SubBandType,
  resolution : Int,
) -> (Int, Int) raise DecodeError {
  let n_ll = self.coding_style.parameters.num_decomposition_levels
  let sb_index = match sub_band_type {
    // TODO: Shouldn't be reached.
    LowLow => 0xFFFF
    HighLow => 0
    LowHigh => 1
    HighHigh => 2
  }
  let step_sizes = self.quantization_info.step_sizes
  match self.quantization_info.quantization_style {
    NoQuantization | ScalarExpounded => {
      let idx = if resolution == 0 {
        0
      } else {
        1 + (resolution - 1) * 3 + sb_index
      }
      guard idx < step_sizes.length() else { raise Validation(MissingStepSize) }
      (step_sizes[idx].exponent, step_sizes[idx].mantissa)
    }
    ScalarDerived => {
      guard step_sizes.length() > 0 else { raise Validation(MissingStepSize) }
      let e_0 = step_sizes[0].exponent
      let mantissa = step_sizes[0].mantissa
      let n_b = if resolution == 0 {
        n_ll
      } else {
        (n_ll + 1 - resolution) & 0xFFFF
      }
      if e_0 < n_ll {
        raise Validation(InvalidExponents)
      }
      let exponent = e_0 - n_ll + n_b
      if exponent > 0xFFFF {
        raise Validation(InvalidExponents)
      }
      (exponent, mantissa)
    }
  }
}

///|
fn ComponentInfo::wavelet_transform(self : ComponentInfo) -> WaveletTransform {
  self.coding_style.parameters.transformation
}

///|
fn ComponentInfo::num_resolution_levels(self : ComponentInfo) -> Int {
  self.coding_style.parameters.num_resolution_levels
}

///|
fn ComponentInfo::num_decomposition_levels(self : ComponentInfo) -> Int {
  self.coding_style.parameters.num_decomposition_levels
}

///|
fn ComponentInfo::code_block_style(self : ComponentInfo) -> CodeBlockStyle {
  self.coding_style.parameters.code_block_style
}

///|
/// Progression order (Table A.16).
priv enum ProgressionOrder {
  LayerResolutionComponentPosition
  ResolutionLayerComponentPosition
  ResolutionPositionComponentLayer
  PositionComponentResolutionLayer
  ComponentPositionResolutionLayer
}

///|
fn ProgressionOrder::from_u8(value : Int) -> ProgressionOrder? {
  match value {
    0 => Some(LayerResolutionComponentPosition)
    1 => Some(ResolutionLayerComponentPosition)
    2 => Some(ResolutionPositionComponentLayer)
    3 => Some(PositionComponentResolutionLayer)
    4 => Some(ComponentPositionResolutionLayer)
    // err!(ValidationError::InvalidProgressionOrder)
    _ => None
  }
}

///|
/// Wavelet transformation type (Table A.20).
priv enum WaveletTransform {
  Irreversible97
  Reversible53
} derive(Eq)

///|
fn WaveletTransform::from_u8(value : Int) -> WaveletTransform? {
  match value {
    0 => Some(Irreversible97)
    1 => Some(Reversible53)
    // err!(ValidationError::InvalidTransformation)
    _ => None
  }
}

///|
/// Coding style flags (Table A.13).
priv struct CodingStyleFlags {
  mut raw : Int
}

///|
fn CodingStyleFlags::from_u8(value : Int) -> CodingStyleFlags {
  { raw: value, }
}

///|
fn CodingStyleFlags::has_precincts(self : CodingStyleFlags) -> Bool {
  (self.raw & 0x01) != 0
}

///|
fn CodingStyleFlags::may_use_sop_markers(self : CodingStyleFlags) -> Bool {
  (self.raw & 0x02) != 0
}

///|
fn CodingStyleFlags::uses_eph_marker(self : CodingStyleFlags) -> Bool {
  (self.raw & 0x04) != 0
}

///|
/// Code-block style flags (Table A.19).
priv struct CodeBlockStyle {
  selective_arithmetic_coding_bypass : Bool
  reset_context_probabilities : Bool
  termination_on_each_pass : Bool
  vertically_causal_context : Bool
  segmentation_symbols : Bool
}

///|
fn CodeBlockStyle::default() -> CodeBlockStyle {
  {
    selective_arithmetic_coding_bypass: false,
    reset_context_probabilities: false,
    termination_on_each_pass: false,
    vertically_causal_context: false,
    segmentation_symbols: false,
  }
}

///|
fn CodeBlockStyle::from_u8(value : Int) -> CodeBlockStyle {
  {
    selective_arithmetic_coding_bypass: (value & 0x01) != 0,
    reset_context_probabilities: (value & 0x02) != 0,
    termination_on_each_pass: (value & 0x04) != 0,
    vertically_causal_context: (value & 0x08) != 0,
    // The predictable termination flag is only informative and
    // can therefore be ignored.
    segmentation_symbols: (value & 0x20) != 0,
  }
}

///|
/// Quantization style (Table A.28).
priv enum QuantizationStyle {
  NoQuantization
  ScalarDerived
  ScalarExpounded
} derive(Eq)

///|
fn QuantizationStyle::from_u8(value : Int) -> QuantizationStyle? {
  match value & 0x1F {
    0 => Some(NoQuantization)
    1 => Some(ScalarDerived)
    2 => Some(ScalarExpounded)
    // err!(ValidationError::InvalidQuantizationStyle)
    _ => None
  }
}

///|
priv struct StepSize {
  mantissa : Int
  exponent : Int
}

///|
/// Quantization properties, from the QCD and QCC markers (A.6.4 and A.6.5).
priv struct QuantizationInfo {
  quantization_style : QuantizationStyle
  mut guard_bits : Int
  step_sizes : Array[StepSize]
}

///|
/// Default values for coding style, from the COD marker (A.6.1).
priv struct CodingStyleDefault {
  progression_order : ProgressionOrder
  num_layers : Int
  mct : Bool
  // This is the default used for all components, if not overridden by COC.
  component_parameters : CodingStyleComponent
}

///|
fn CodingStyleDefault::clone(self : CodingStyleDefault) -> CodingStyleDefault {
  { ..self, component_parameters: self.component_parameters.clone(), }
}

///|
/// Values of coding style for each component, from the COC marker (A.6.2).
priv struct CodingStyleComponent {
  flags : CodingStyleFlags
  mut parameters : CodingStyleParameters
}

///|
fn CodingStyleComponent::clone(
  self : CodingStyleComponent,
) -> CodingStyleComponent {
  { flags: { raw: self.flags.raw, }, parameters: self.parameters, }
}

///|
/// Shared parameters between the COC and COD marker (A.6.1 and A.6.2).
priv struct CodingStyleParameters {
  num_decomposition_levels : Int
  num_resolution_levels : Int
  code_block_width : Int
  code_block_height : Int
  code_block_style : CodeBlockStyle
  transformation : WaveletTransform
  precinct_exponents : Array[(Int, Int)]
}

///|
priv struct SizeData {
  /// Width of the reference grid (Xsiz).
  reference_grid_width : UInt
  /// Height of the reference grid (Ysiz).
  reference_grid_height : UInt
  /// Horizontal offset from the origin of the reference grid to the
  /// left side of the image area (`XOsiz`).
  image_area_x_offset : UInt
  /// Vertical offset from the origin of the reference grid to the top side of the image area (`YOsiz`).
  image_area_y_offset : UInt
  /// Width of one reference tile with respect to the reference grid (`XTSiz`).
  tile_width : UInt
  /// Height of one reference tile with respect to the reference grid (`YTSiz`).
  tile_height : UInt
  /// Horizontal offset from the origin of the reference grid to the left side of the first tile (`XTOSiz`).
  tile_x_offset : UInt
  /// Vertical offset from the origin of the reference grid to the top side of the first tile (`YTOSiz`).
  tile_y_offset : UInt
  /// Component information (SSiz/XRSiz/YRSiz).
  component_sizes : Array[ComponentSizeInfo]
  /// Shrink factor in the x direction. See the comment in the parsing method.
  x_shrink_factor : UInt
  /// Shrink factor in the y direction. See the comment in the parsing method.
  y_shrink_factor : UInt
  /// Shrink factor in the x direction due to requesting a lower resolution level.
  mut x_resolution_shrink_factor : UInt
  /// Shrink factor in the y direction due to requesting a lower resolution level.
  mut y_resolution_shrink_factor : UInt
}

///|
fn SizeData::tile_x_coord(self : SizeData, idx : UInt) -> UInt {
  // See B-6.
  idx % self.num_x_tiles()
}

///|
fn SizeData::tile_y_coord(self : SizeData, idx : UInt) -> UInt {
  // See B-6.
  idx / self.num_x_tiles()
}

///|
/// Component information (A.5.1 and Table A.11).
priv struct ComponentSizeInfo {
  precision : Int
  horizontal_resolution : Int
  vertical_resolution : Int
}

///|
/// The number of tiles in the x direction.
fn SizeData::num_x_tiles(self : SizeData) -> UInt {
  // See formula B-5.
  div_ceil_u32(self.reference_grid_width - self.tile_x_offset, self.tile_width)
}

///|
/// The number of tiles in the y direction.
fn SizeData::num_y_tiles(self : SizeData) -> UInt {
  // See formula B-5.
  div_ceil_u32(
    self.reference_grid_height - self.tile_y_offset,
    self.tile_height,
  )
}

///|
/// The total number of tiles.
fn SizeData::num_tiles(self : SizeData) -> UInt {
  self.num_x_tiles() * self.num_y_tiles()
}

///|
/// Return the overall width of the image.
fn SizeData::image_width(self : SizeData) -> UInt {
  div_ceil_u32(
    self.reference_grid_width - self.image_area_x_offset,
    self.x_shrink_factor * self.x_resolution_shrink_factor,
  )
}

///|
/// Return the overall height of the image.
fn SizeData::image_height(self : SizeData) -> UInt {
  div_ceil_u32(
    self.reference_grid_height - self.image_area_y_offset,
    self.y_shrink_factor * self.y_resolution_shrink_factor,
  )
}

///|
/// SIZ marker (A.5.1).
fn size_marker(reader : BitReader) -> SizeData raise DecodeError {
  guard size_marker_inner(reader) is Some(size_data) else {
    raise Marker(ParseFailure("SIZ"))
  }
  if size_data.tile_width == 0 ||
    size_data.tile_height == 0 ||
    size_data.reference_grid_width == 0 ||
    size_data.reference_grid_height == 0 {
    raise Validation(InvalidDimensions)
  }
  if size_data.tile_x_offset >= size_data.reference_grid_width ||
    size_data.tile_y_offset >= size_data.reference_grid_height {
    raise Validation(InvalidDimensions)
  }

  // The tile grid offsets (XTOsiz, YTOsiz) are constrained to be no greater than the
  // image area offsets (B-3).
  if size_data.tile_x_offset > size_data.image_area_x_offset ||
    size_data.tile_y_offset > size_data.image_area_y_offset {
    raise Tile(InvalidOffsets)
  }

  // Also, the tile size plus the tile offset shall be greater than the image area offset.
  // This ensures that the first tile (tile 0) will contain at least one reference grid point
  // from the image area (B-4).
  let x_end = size_data.tile_x_offset.to_uint64() +
    size_data.tile_width.to_uint64()
  if x_end > 0xFFFFFFFFUL {
    raise Tile(InvalidOffsets)
  }
  if x_end <= size_data.image_area_x_offset.to_uint64() {
    raise Tile(InvalidOffsets)
  }
  let y_end = size_data.tile_y_offset.to_uint64() +
    size_data.tile_height.to_uint64()
  if y_end > 0xFFFFFFFFUL {
    raise Tile(InvalidOffsets)
  }
  if y_end <= size_data.image_area_y_offset.to_uint64() {
    raise Tile(InvalidOffsets)
  }
  for comp in size_data.component_sizes {
    if comp.precision == 0 ||
      comp.vertical_resolution == 0 ||
      comp.horizontal_resolution == 0 {
      raise Validation(InvalidComponentMetadata)
    }
  }
  let max_dimensions : UInt = 60000
  if size_data.image_width() > max_dimensions ||
    size_data.image_height() > max_dimensions {
    raise Validation(ImageTooLarge)
  }
  size_data
}

///|
fn size_marker_inner(reader : BitReader) -> SizeData? {
  // Length.
  guard reader.read_u16() is Some(_) else { return None }
  // Decoder capabilities.
  guard reader.read_u16() is Some(_) else { return None }
  guard reader.read_u32() is Some(xsiz) else { return None }
  guard reader.read_u32() is Some(ysiz) else { return None }
  guard reader.read_u32() is Some(x_osiz) else { return None }
  guard reader.read_u32() is Some(y_osiz) else { return None }
  guard reader.read_u32() is Some(xt_siz) else { return None }
  guard reader.read_u32() is Some(yt_siz) else { return None }
  guard reader.read_u32() is Some(xto_siz) else { return None }
  guard reader.read_u32() is Some(yto_siz) else { return None }
  guard reader.read_u16() is Some(csiz) else { return None }
  if x_osiz >= xsiz || y_osiz >= ysiz {
    return None
  }
  if csiz == 0 {
    return None
  }
  let components = []
  for _ in 0..<csiz {
    guard reader.read_byte() is Some(ssiz) else { return None }
    guard reader.read_byte() is Some(x_rsiz) else { return None }
    guard reader.read_byte() is Some(y_rsiz) else { return None }
    let precision = (ssiz & 0x7F) + 1
    // No idea how to process signed images, but as far as I can tell
    // openjpeg and others just accept it as is, so let's do the same.
    let _is_signed = (ssiz & 0x80) != 0

    // In theory up to 38 is allowed, but we don't support more than that.
    if precision > BITPLANE_BIT_SIZE {
      return None
    }
    components.push({
      precision,
      horizontal_resolution: x_rsiz,
      vertical_resolution: y_rsiz,
    })
  }

  // In case all components are sub-sampled at the same level, we
  // don't want to render them at the original resolution but instead
  // reduce their dimension so that we can assume a resolution of 1 for
  // all components. This makes the images much smaller.

  let mut x_shrink_factor : UInt = 1
  let mut y_shrink_factor : UInt = 1
  let hr = components[0].horizontal_resolution
  let vr = components[0].vertical_resolution
  let mut same_resolution = true
  for component in components[1:] {
    same_resolution = same_resolution && component.horizontal_resolution == hr
    same_resolution = same_resolution && component.vertical_resolution == vr
  }
  if same_resolution {
    x_shrink_factor = hr.reinterpret_as_uint()
    y_shrink_factor = vr.reinterpret_as_uint()
  }
  Some({
    reference_grid_width: xsiz,
    reference_grid_height: ysiz,
    image_area_x_offset: x_osiz,
    image_area_y_offset: y_osiz,
    tile_width: xt_siz,
    tile_height: yt_siz,
    tile_x_offset: xto_siz,
    tile_y_offset: yto_siz,
    component_sizes: components,
    x_shrink_factor,
    y_shrink_factor,
    x_resolution_shrink_factor: 1,
    y_resolution_shrink_factor: 1,
  })
}

///|
fn coding_style_parameters(
  reader : BitReader,
  coding_style : CodingStyleFlags,
) -> CodingStyleParameters? {
  guard reader.read_byte() is Some(num_decomposition_levels) else {
    return None
  }
  if num_decomposition_levels > MAX_RESOLUTION_COUNT {
    return None
  }
  let num_resolution_levels = num_decomposition_levels + 1
  guard reader.read_byte() is Some(cbw) else { return None }
  guard cbw + 2 <= 0xFF else { return None }
  let code_block_width = cbw + 2
  guard reader.read_byte() is Some(cbh) else { return None }
  guard cbh + 2 <= 0xFF else { return None }
  let code_block_height = cbh + 2
  guard reader.read_byte() is Some(style) else { return None }
  let code_block_style = CodeBlockStyle::from_u8(style)
  guard reader.read_byte() is Some(t) else { return None }
  guard WaveletTransform::from_u8(t) is Some(transformation) else {
    return None
  }
  let precinct_exponents = []
  if coding_style.has_precincts() {
    // "Entropy coder with precincts defined below."
    for _ in 0..<num_resolution_levels {
      // Table A.21.
      guard reader.read_byte() is Some(precinct_size) else { return None }
      let width_exp = precinct_size & 0xF
      let height_exp = precinct_size >> 4
      if width_exp > MAX_PRECINCT_EXPONENT || height_exp > MAX_PRECINCT_EXPONENT {
        return None
      }
      precinct_exponents.push((width_exp, height_exp))
    }
  } else {
    // "Entropy coder, precincts with PPx = 15 and PPy = 15"
    for _ in 0..<num_resolution_levels {
      precinct_exponents.push((15, 15))
    }
  }
  Some({
    num_decomposition_levels,
    num_resolution_levels,
    code_block_width,
    code_block_height,
    code_block_style,
    transformation,
    precinct_exponents,
  })
}

///|
/// COM Marker (A.9.2).
fn com_marker(reader : BitReader) -> Unit? {
  skip_marker_segment(reader)
}

///|
/// TLM marker (A.7.1).
fn tlm_marker(reader : BitReader) -> Unit? {
  skip_marker_segment(reader)
}

///|
/// PPM marker (A.7.4).
fn ppm_marker(reader : BitReader) -> PpmMarkerData? {
  guard reader.read_u16() is Some(len) && len >= 2 else { return None }
  let segment_len = len - 2
  guard reader.read_bytes(segment_len) is Some(ppm_data) else { return None }
  let packets = []
  let reader = BitReader::new(ppm_data)
  guard reader.read_byte() is Some(sequence_idx) else { return None }

  // TODO: Handle case where next packet doesn't have nppm parameter.

  while !reader.at_end() {
    guard reader.read_u16() is Some(packet_len) else { return None }
    guard reader.read_bytes(packet_len) is Some(data) else { return None }
    packets.push({ data, })
  }
  Some({ sequence_idx, packets, })
}

///|
/// RGN marker (A.6.3).
fn rgn_marker(reader : BitReader) -> Unit? {
  skip_marker_segment(reader)
}

///|
fn skip_marker_segment(reader : BitReader) -> Unit? {
  guard reader.read_u16() is Some(len) && len >= 2 else { return None }
  let length = len - 2
  guard reader.skip_bytes(length) is Some(_) else { return None }
  Some(())
}

///|
/// COD marker (A.6.1).
fn cod_marker(reader : BitReader) -> CodingStyleDefault? {
  // Length.
  guard reader.read_u16() is Some(_) else { return None }
  guard reader.read_byte() is Some(flags) else { return None }
  let coding_style_flags = CodingStyleFlags::from_u8(flags)
  guard reader.read_byte() is Some(po) else { return None }
  guard ProgressionOrder::from_u8(po) is Some(progression_order) else {
    return None
  }
  guard reader.read_u16() is Some(num_layers) else { return None }

  // We don't support more than 32-bit (and thus 32 layers).
  if num_layers == 0 || num_layers > MAX_LAYER_COUNT {
    return None
  }
  guard reader.read_byte() is Some(mct) else { return None }
  let mct = mct == 1
  guard coding_style_parameters(reader, coding_style_flags)
    is Some(coding_style_parameters) else {
    return None
  }
  Some({
    progression_order,
    num_layers,
    mct,
    component_parameters: {
      flags: coding_style_flags,
      parameters: coding_style_parameters,
    },
  })
}

///|
/// COC marker (A.6.2).
fn coc_marker(reader : BitReader, csiz : Int) -> (Int, CodingStyleComponent)? {
  // Length.
  guard reader.read_u16() is Some(_) else { return None }
  let component_index = if csiz < 257 {
    guard reader.read_byte() is Some(v) else { return None }
    v
  } else {
    guard reader.read_u16() is Some(v) else { return None }
    v
  }
  guard reader.read_byte() is Some(flags) else { return None }
  let coding_style = CodingStyleFlags::from_u8(flags)
  guard coding_style_parameters(reader, coding_style) is Some(parameters) else {
    return None
  }
  let coc = { flags: coding_style, parameters, }
  Some((component_index, coc))
}

///|
/// QCD marker (A.6.4).
fn qcd_marker(reader : BitReader) -> QuantizationInfo? {
  // Length.
  guard reader.read_u16() is Some(length) else { return None }
  guard reader.read_byte() is Some(sqcd_val) else { return None }
  guard QuantizationStyle::from_u8(sqcd_val & 0x1F) is Some(quantization_style) else {
    return None
  }
  let guard_bits = (sqcd_val >> 5) & 0x07
  guard length >= 3 else { return None }
  let remaining_bytes = length - 3
  guard quantization_parameters(reader, quantization_style, remaining_bytes)
    is Some(parameters) else {
    return None
  }
  parameters.guard_bits = guard_bits
  Some(parameters)
}

///|
/// QCC marker (A.6.5).
fn qcc_marker(reader : BitReader, csiz : Int) -> (Int, QuantizationInfo)? {
  guard reader.read_u16() is Some(length) else { return None }
  let component_index = if csiz < 257 {
    guard reader.read_byte() is Some(v) else { return None }
    v
  } else {
    guard reader.read_u16() is Some(v) else { return None }
    v
  }
  guard reader.read_byte() is Some(sqcc_val) else { return None }
  guard QuantizationStyle::from_u8(sqcc_val & 0x1F) is Some(quantization_style) else {
    return None
  }
  let guard_bits = (sqcc_val >> 5) & 0x07
  let component_index_size = if csiz < 257 { 1 } else { 2 }
  guard length >= 2 + component_index_size + 1 else { return None }
  let remaining_bytes = length - 2 - component_index_size - 1
  guard quantization_parameters(reader, quantization_style, remaining_bytes)
    is Some(parameters) else {
    return None
  }
  parameters.guard_bits = guard_bits
  Some((component_index, parameters))
}

///|
fn quantization_parameters(
  reader : BitReader,
  quantization_style : QuantizationStyle,
  remaining_bytes : Int,
) -> QuantizationInfo? {
  let step_sizes = []
  fn irreversible(val : Int) -> StepSize {
    let exponent = val >> 11
    let mantissa = val & ((1 << 11) - 1)
    { exponent, mantissa, }
  }

  match quantization_style {
    NoQuantization =>
      // 8 bits per band (5 bits exponent, 3 bits reserved)
      for _ in 0..<remaining_bytes {
        guard reader.read_byte() is Some(value) else { return None }
        step_sizes.push({
          // Unused.
          mantissa: 0,
          exponent: value >> 3,
        })
      }
    ScalarDerived => {
      guard reader.read_u16() is Some(value) else { return None }
      step_sizes.push(irreversible(value))
    }
    ScalarExpounded => {
      let num_bands = remaining_bytes / 2
      for _ in 0..<num_bands {
        guard reader.read_u16() is Some(value) else { return None }
        step_sizes.push(irreversible(value))
      }
    }
  }
  Some({ quantization_style, guard_bits: 0, step_sizes, })
}

// Marker codes (Table A.2).

///|
/// Start of codestream - 'SOC'.
const SOC : Int = 0x4F

///|
/// Start of tile-part - 'SOT'.
const SOT : Int = 0x90

///|
/// Start of data - 'SOD'.
const SOD : Int = 0x93

///|
/// End of codestream - 'EOC'.
const EOC : Int = 0xD9

///|
/// Image and tile size - 'SIZ'.
const SIZ : Int = 0x51

///|
/// Coding style default - 'COD'.
const COD : Int = 0x52

///|
/// Coding component - 'COC'.
const COC : Int = 0x53

///|
/// Region-of-interest - 'RGN'.
const RGN : Int = 0x5E

///|
/// Quantization default - 'QCD'.
const QCD : Int = 0x5C

///|
/// Quantization component - 'QCC'.
const QCC : Int = 0x5D

///|
/// Tile-part lengths - 'TLM'.
const TLM : Int = 0x55

///|
/// Packet length, tile-part header - 'PLT'.
const PLT : Int = 0x58

///|
/// Packed packet headers, main header - 'PPM'.
const PPM : Int = 0x60

///|
/// Packed packet headers, tile-part header - 'PPT'.
const PPT : Int = 0x61

///|
/// Start of packet - 'SOP'.
const SOP : Int = 0x91

///|
/// End of packet header - 'EPH'.
const EPH : Int = 0x92

///|
/// Component registration - 'CRG'.
const CRG : Int = 0x63

///|
/// Comment - 'COM'.
const COM : Int = 0x64
// (POC, PLM and `markers::to_string` are unused upstream and not ported.)
