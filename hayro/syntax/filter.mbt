// Port of `hayro-syntax/src/filter/mod.rs`: results from decoding filtered
// data streams. The image filters (with upstream's `images` feature) are in
// `filter_dct.mbt`, `filter_ccitt.mbt`, `filter_jbig2.mbt` and
// `filter_jpx.mbt`.

///|
/// A data filter.
pub(all) enum Filter {
  /// ASCII hexadecimal encoding.
  AsciiHexDecode
  /// ASCII base-85 encoding.
  Ascii85Decode
  /// Lempel-Ziv-Welch (LZW) compression.
  LzwDecode
  /// DEFLATE compression (zlib/gzip).
  FlateDecode
  /// Run-length encoding compression.
  RunLengthDecode
  /// CCITT Group 3 or Group 4 fax compression.
  CcittFaxDecode
  /// JBIG2 compression for bi-level images.
  Jbig2Decode
  /// JPEG (DCT) compression.
  DctDecode
  /// JPEG 2000 compression.
  JpxDecode
  /// Encryption filter.
  Crypt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Filter with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Filter with @debug.Debug::{to_repr}

///|
pub fn Filter::from_name(name : Name) -> Filter? {
  match name.0 {
    "ASCIIHexDecode" | "AHx" => Some(AsciiHexDecode)
    "ASCII85Decode" | "A85" => Some(Ascii85Decode)
    "LZWDecode" | "LZW" => Some(LzwDecode)
    "FlateDecode" | "Fl" => Some(FlateDecode)
    "RunLengthDecode" | "RL" => Some(RunLengthDecode)
    "CCITTFaxDecode" | "CCF" => Some(CcittFaxDecode)
    "JBIG2Decode" => Some(Jbig2Decode)
    "DCTDecode" | "DCT" => Some(DctDecode)
    "JPXDecode" => Some(JpxDecode)
    "Crypt" => Some(Crypt)
    _ => None
  }
}

///|
/// `.ok_or(DecodeFailure::ImageDecode)`
fn image_ok_or(r : FilterResult?) -> Result[FilterResult, DecodeFailure] {
  match r {
    Some(r) => Ok(r)
    None => Err(ImageDecode)
  }
}

///|
pub fn Filter::apply(
  self : Filter,
  data : BytesView,
  params : Dict,
  image_params : ImageDecodeParams,
) -> Result[FilterResult, DecodeFailure] {
  let ok_or = (r : Bytes?) => {
    match r {
      Some(d) => Ok(FilterResult::from_data(d))
      None => Err(StreamDecode)
    }
  }
  match self {
    AsciiHexDecode => ok_or(ascii_hex_decode(data))
    Ascii85Decode => ok_or(ascii_85_decode(data))
    RunLengthDecode => ok_or(run_length_decode(data))
    LzwDecode => ok_or(lzw_decode(data, params))
    FlateDecode => ok_or(flate_decode(data, params))
    DctDecode => image_ok_or(dct_decode(data, params, image_params))
    CcittFaxDecode => image_ok_or(ccitt_decode(data, params, image_params))
    Jbig2Decode => image_ok_or(jbig2_decode(data, params, image_params))
    JpxDecode => image_ok_or(jpx_decode(data, image_params))
    _ => Err(StreamDecode)
  }
}

///|
// ---- ASCIIHex (`filter/ascii_hex.rs`) ----

///|
pub fn ascii_hex_decode(data : BytesView) -> Bytes? {
  // Find end (at `>` or end of data).
  let mut end = data.length()
  for idx in 0..<data.length() {
    if data[idx] == b'>' {
      end = idx
      break
    }
  }
  let data = data[:end]
  let decoded = Buffer(size_hint=(data.length() + 1) / 2)
  let mut hi : Int? = None
  for b in data {
    if is_white_space_character(b) {
      continue
    }
    guard decode_hex_digit(b) is Some(d) else { return None }
    let d = d.to_int()
    match hi {
      None => hi = Some(d)
      Some(h) => {
        decoded.write_byte(((h << 4) | d).to_byte())
        hi = None
      }
    }
  }
  if hi is Some(h) {
    decoded.write_byte((h << 4).to_byte())
  }
  Some(decoded.to_bytes())
}

///|
pub fn decode_hex_digit(c : Byte) -> Byte? {
  match c {
    b'0'..<=b'9' => Some(c - b'0')
    b'A'..<=b'F' => Some(c - b'A' + 10)
    b'a'..<=b'f' => Some(c - b'a' + 10)
    _ => None
  }
}

///|
// ---- ASCII85 (`filter/ascii_85.rs`) ----

///|
pub fn ascii_85_decode(data : BytesView) -> Bytes? {
  let pow_85 : FixedArray[UInt64] = [52200625, 614125, 7225, 85, 1]
  let reader = Reader::new(data)
  let read_byte = () => {
    while true {
      guard reader.read_byte() is Some(b) else { return None }
      // White space characters should be ignored.
      if !is_white_space_character(b) {
        return Some(b)
      }
    }
    None
  }
  let decoded = Buffer(size_hint=data.length() * 4 / 5)
  let group : Array[Byte] = []
  let flush_group = () => {
    let n = group.length()
    if n == 0 {
      return Some(())
    }
    if n == 1 {
      // A single character is not valid.
      return None
    }
    let mut value : UInt64 = 0
    for i in 0..<5 {
      let b = if i < n { group[i] } else { b'u' }
      value = value + (b - b'!').to_uint64() * pow_85[i]
    }
    if value > 0xFFFFFFFFUL {
      return None
    }
    let output_len = n - 1
    for i in 0..<output_len {
      decoded.write_byte((value >> (24 - 8 * i)).to_byte())
    }
    group.clear()
    Some(())
  }
  while true {
    guard read_byte() is Some(b) else {
      // Be lenient and accept what we have (see PDFBOX-5910).
      guard flush_group() is Some(_) else { return None }
      return Some(decoded.to_bytes())
    }
    match b {
      b'!'..<=b'u' => {
        group.push(b)
        if group.length() == 5 {
          guard flush_group() is Some(_) else { return None }
        }
      }
      b'z' => {
        guard flush_group() is Some(_) else { return None }
        decoded.write_bytes(b"\x00\x00\x00\x00")
      }
      b'~' => {
        // Technically requires a '>', but there is a PDF where it isn't
        // appended and decodes fine in other viewers.
        guard flush_group() is Some(_) else { return None }
        return Some(decoded.to_bytes())
      }
      _ => return None // Invalid character.
    }
  }
  None
}

///|
// ---- RunLength (`filter/run_length.rs`) ----

///|
pub fn run_length_decode(data : BytesView) -> Bytes? {
  let reader = Reader::new(data)
  let decoded = Buffer()
  while true {
    guard reader.read_byte() is Some(length) else { return None }
    let length = length.to_int()
    if length == 128 {
      break
    } else if length <= 127 {
      // PDFBOX-3990, just abort early if stream is invalid.
      guard reader.read_bytes(length + 1) is Some(bytes) else { break }
      decoded.write_bytesview(bytes)
    } else {
      let length = 257 - length
      guard reader.read_byte() is Some(b) else { return None }
      for _ in 0..<length {
        decoded.write_byte(b)
      }
    }
  }
  Some(decoded.to_bytes())
}
