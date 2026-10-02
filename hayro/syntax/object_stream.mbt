// Port of `hayro-syntax/src/object/stream.rs`: streams.

///|
/// A stream of arbitrary data.
pub struct Stream {
  priv dict : Dict
  priv data : BytesView
}

///|
pub impl Eq for Stream with fn equal(a, b) {
  a.dict == b.dict && a.data == b.data
}

///|
pub impl Show for Stream with fn output(self, logger) {
  logger.write_string("Stream (len: \{self.data.length()})")
}

///|
/// Additional parameters for decoding images.
pub(all) struct ImageDecodeParams {
  /// Whether the color space of the image is an indexed color space.
  is_indexed : Bool
  /// The bits per component of the image, if that information is available.
  bpc : Int?
  /// The components per channel of the image, if that information is available.
  num_components : Int?
  /// A target resolution for the image.
  target_dimension : (Int, Int)?
  /// The width of the image as indicated by the image dictionary.
  width : Int
  /// The height of the image as indicated by the image dictionary.
  height : Int
}

///|
pub fn ImageDecodeParams::default() -> ImageDecodeParams {
  {
    is_indexed: false,
    bpc: None,
    num_components: None,
    target_dimension: None,
    width: 0,
    height: 0,
  }
}

///|
/// A failure that can occur during decoding a data stream.
pub(all) enum DecodeFailure {
  /// An image stream failed to decode.
  ImageDecode
  /// A data stream failed to decode.
  StreamDecode
  /// A failure occurred while decrypting a file.
  Decryption
  /// An unknown failure occurred.
  Unknown
} derive(Eq, Debug)

///|
/// An image color space.
pub(all) enum ImageColorSpace {
  /// Grayscale color space.
  Gray
  /// RGB color space.
  Rgb
  /// CMYK color space.
  Cmyk
  /// An unknown color space.
  Unknown(Int)
} derive(Eq, Debug)

///|
/// Additional data that is extracted from some image streams.
pub(all) struct ImageData {
  /// An optional alpha channel of the image.
  alpha : Bytes?
  /// The color space of the image.
  color_space : ImageColorSpace?
  /// The bits per component of the image.
  bits_per_component : Int
  /// The width of the image.
  width : Int
  /// The height of the image.
  height : Int
}

///|
/// The result of applying a filter.
pub(all) struct FilterResult {
  /// The decoded data.
  data : BytesView
  /// Additional data that is extracted from JPX image streams.
  image_data : ImageData?
}

///|
pub fn FilterResult::from_data(data : Bytes) -> FilterResult {
  { data: data[:], image_data: None, }
}

///|
pub fn Stream::new(data : BytesView, dict : Dict) -> Stream {
  { dict, data, }
}

///|
fn Stream::filters_and_params(self : Stream) -> (Array[Filter], Array[Dict]) {
  let collected_filters = []
  let collected_params = []
  let single : Name? = match self.dict.get("F") {
    Some(n) => Some(n)
    None => self.dict.get("Filter")
  }
  if single.bind(Filter::from_name) is Some(filter) {
    let params : Dict = match self.dict.get("DP") {
      Some(d) => d
      None => self.dict.get("DecodeParms").unwrap_or_default()
    }
    collected_filters.push(filter)
    collected_params.push(params)
  } else {
    let filters : PdfArray? = match self.dict.get("F") {
      Some(a) => Some(a)
      None => self.dict.get("Filter")
    }
    if filters is Some(filters) {
      let params_arr : PdfArray? = match self.dict.get("DP") {
        Some(a) => Some(a)
        None => self.dict.get("DecodeParms")
      }
      let params : Iter[Object]? = params_arr.map(a => a.iter())
      for name in (filters.iter() : Iter[Name]) {
        let filter = Filter::from_name(name)
        let p : Dict = match params {
          Some(it) =>
            match it.next() {
              Some(o) => o.into_dict().unwrap_or_default()
              None => Dict::empty()
            }
          None => Dict::empty()
        }
        if filter is Some(filter) {
          collected_filters.push(filter)
          collected_params.push(p)
        }
      }
    }
  }
  (collected_filters, collected_params)
}

///|
/// Return the raw, decrypted data of the stream.
///
/// Stream filters will not be applied.
pub fn Stream::raw_data(self : Stream) -> BytesView {
  let ctx = self.dict.ctx()
  let is_xref = match (self.dict.get("Type") : PdfString?) {
    Some(t) => t.as_bytes() == b"XRef"
    None => false
  }
  if ctx.xref().needs_decryption(ctx) && !is_xref {
    match ctx.xref().decrypt(self.obj_id(), self.data, Stream) {
      Some(d) => d[:]
      None => b""[:]
    }
  } else {
    self.data
  }
}

///|
/// Return the raw, underlying dictionary of the stream.
pub fn Stream::dict(self : Stream) -> Dict {
  self.dict
}

///|
/// Return the object identifier of the stream.
pub fn Stream::obj_id(self : Stream) -> ObjectIdentifier {
  // In theory shouldn't ever happen, but could theoretically be
  // triggered in a crafted PDF.
  self.dict.obj_id().unwrap_or(ObjectIdentifier::new(0, 0))
}

///|
/// Return the filters that are applied to the stream.
pub fn Stream::filters(self : Stream) -> Array[Filter] {
  self.filters_and_params().0
}

///|
/// Return the decoded data of the stream.
pub fn Stream::decoded(self : Stream) -> Result[BytesView, DecodeFailure] {
  self.decoded_image(ImageDecodeParams::default()).map(r => r.data)
}

///|
/// Return the decoded data of the stream, and return image metadata
/// if available.
pub fn Stream::decoded_image(
  self : Stream,
  image_params : ImageDecodeParams,
) -> Result[FilterResult, DecodeFailure] {
  let data = self.raw_data()
  let (filters, params) = self.filters_and_params()
  let mut current : FilterResult? = None
  for i in 0..<filters.length() {
    let input = match current {
      Some(c) => c.data
      None => data
    }
    match filters[i].apply(input, params[i], image_params) {
      Ok(new) => current = Some(new)
      Err(e) => return Err(e)
    }
  }
  Ok(current.unwrap_or({ data, image_data: None, }))
}

///|
pub impl Skippable for Stream with fn skip(_, _) {
  // A stream can never appear in a dict/array, so it should never be skipped.
  None
}

///|
pub impl Readable for Stream with fn read(r, ctx) {
  guard (r.read_with_context(ctx) : Dict?) is Some(dict) else { return None }
  if dict.contains_key("F") {
    // encountered stream referencing external file, which is unsupported
    return None
  }
  let offset = r.offset()
  match parse_proper(r, dict) {
    Some(s) => Some(s)
    None => {
      // failed to parse stream, trying to parse it manually
      r.jump(offset)
      parse_fallback(r, dict)
    }
  }
}

///|
pub impl ObjectLike for Stream with fn from_object(o) {
  match o {
    Stream(s) => Some(s)
    _ => None
  }
}

///|
fn parse_proper(r : Reader, dict : Dict) -> Stream? {
  guard (dict.get("Length") : UInt?) is Some(length) else { return None }
  r.skip_white_spaces_and_comments()
  guard r.forward_tag(b"stream") is Some(_) else { return None }
  if r.forward_tag(b"\n") is None &&
    r.forward_tag(b"\r\n") is None &&
    r.forward_tag(b"\r") is None {
    return None
  }
  if length.reinterpret_as_int() < 0 {
    return None
  }
  guard r.read_bytes(length.reinterpret_as_int()) is Some(data) else {
    return None
  }
  r.skip_white_spaces()
  guard r.forward_tag(b"endstream") is Some(_) else { return None }
  Some(Stream::new(data, dict))
}

///|
fn parse_fallback(r : Reader, dict : Dict) -> Stream? {
  guard r.tail() is Some(t) && find_needle(t, b"stream") is Some(stream_offset) else {
    return None
  }
  guard r.read_bytes(stream_offset) is Some(_) else { return None }
  guard r.forward_tag(b"stream") is Some(_) else { return None }
  if r.forward_tag(b"\n") is None &&
    r.forward_tag(b"\r\n") is None &&
    // Technically not allowed, but no reason to not try it.
    r.forward_tag(b"\r") is None {
    return None
  }
  guard r.tail() is Some(tail) else { return None }
  guard find_needle(tail, b"endstream") is Some(endstream_offset) else {
    return None
  }
  let data_end = trim_trailing_ascii_whitespace(tail[:endstream_offset])
  let data = tail[:data_end]
  guard r.read_bytes(endstream_offset) is Some(_) else { return None }
  r.skip_white_spaces()
  guard r.forward_tag(b"endstream") is Some(_) else { return None }
  Some(Stream::new(data, dict))
}

///|
fn trim_trailing_ascii_whitespace(data : BytesView) -> Int {
  let mut end = data.length()
  while end > 0 && is_white_space_character(data[end - 1]) {
    end -= 1
  }
  end
}
