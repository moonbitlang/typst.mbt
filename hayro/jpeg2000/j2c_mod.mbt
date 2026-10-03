// Port of `hayro-jpeg2000/src/j2c/mod.rs`.

///|
priv struct ParsedCodestream {
  header : Header
  data : BytesView
}

///|
/// Decoded data for one JPEG2000 component.
pub struct ComponentData {
  priv container : SimdBuffer
  priv bit_depth : Int
}

///|
fn ComponentData::clone(self : ComponentData) -> ComponentData {
  { container: self.container.clone(), bit_depth: self.bit_depth, }
}

///|
/// The bit depth of this component.
pub fn ComponentData::bit_depth(self : ComponentData) -> Int {
  self.bit_depth
}

///|
/// The decoded samples of this component.
pub fn ComponentData::samples(self : ComponentData) -> ArrayView[Float] {
  self.container.truncated()
}

///|
fn j2c_parse(
  stream : BytesView,
  settings : DecodeSettings,
) -> Image raise DecodeError {
  let parsed_codestream = parse_raw(stream, settings)
  let header = parsed_codestream.header
  let boxes = ImageBoxes::default()

  // If we are just decoding a raw codestream, we assume greyscale or
  // RGB.
  let cs = if header.component_infos.length() < 3 {
    ColrColorSpace::Enumerated(Greyscale)
  } else {
    ColrColorSpace::Enumerated(Srgb)
  }
  boxes.color_specification = Some({ color_space: cs, })
  let (color_space, has_alpha) = resolve_alpha_and_color_space(
    boxes,
    parsed_codestream.header,
    settings,
  )
  {
    codestream: parsed_codestream.data,
    header: parsed_codestream.header,
    boxes,
    settings,
    color_space,
    has_alpha,
  }
}

///|
fn parse_raw(
  stream : BytesView,
  settings : DecodeSettings,
) -> ParsedCodestream raise DecodeError {
  let reader = BitReader::new(stream)
  let marker = reader.read_marker()
  if marker != SOC {
    raise Marker(Expected("SOC"))
  }
  let header = read_header(reader, settings)
  guard reader.tail() is Some(code_stream_data) else {
    raise Format(MissingCodestream)
  }
  { header, data: code_stream_data, }
}
