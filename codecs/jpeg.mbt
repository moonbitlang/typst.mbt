// Port of the header parsing of the `zune-jpeg` crate (v0.5.15,
// `JpegDecoder::decode_headers` in `src/decoder.rs` and `src/headers.rs`) as
// used by upstream `image::codecs::jpeg::JpegDecoder::new`: the markers up to
// the start of scan, yielding the dimensions, the color space and the ICC
// profile. The quantization/Huffman tables and the scan header are skipped
// without validation; pixel decoding is not ported.

///|
/// A zune-jpeg header decoding error (upstream `DecodeErrors`), rendered
/// with its `Display` output.
priv suberror JpegError {
  JpegError(String)
}

///|
priv struct JpegReader {
  data : BytesView
  mut pos : Int
}

///|
fn JpegReader::exhausted(self : JpegReader) -> Unit raise JpegError {
  raise JpegError(
    "I/O errors NotEnoughBytes(\{self.data.length() - self.pos}, \{self.data.length()})",
  )
}

///|
fn JpegReader::read_u8(self : JpegReader) -> Int raise JpegError {
  if self.pos >= self.data.length() {
    self.exhausted()
  }
  let v = self.data[self.pos].to_int()
  self.pos += 1
  v
}

///|
fn JpegReader::read_u16(self : JpegReader) -> Int raise JpegError {
  if self.pos + 2 > self.data.length() {
    self.exhausted()
  }
  let v = u16_be(self.data, self.pos)
  self.pos += 2
  v
}

///|
fn JpegReader::skip(self : JpegReader, n : Int) -> Unit raise JpegError {
  if self.pos + n > self.data.length() {
    self.exhausted()
  }
  self.pos += n
}

///|
fn JpegReader::peek(self : JpegReader, n : Int) -> BytesView raise JpegError {
  if self.pos + n > self.data.length() {
    self.exhausted()
  }
  self.data[self.pos:self.pos + n]
}

///|
priv enum JpegColorSpace {
  YCbCr
  Luma
  Rgb
  Cmyk
  Ycck
}

///|
priv struct IccChunk {
  seq_no : Int
  num_markers : Int
  data : Bytes
}

///|
/// Reads the JPEG headers (upstream `zune_jpeg::JpegDecoder::
/// decode_headers`).
fn decode_jpeg_headers(
  data : BytesView,
) -> (Int, Int, JpegColorSpace, Array[IccChunk]) raise JpegError {
  let r = { data, pos: 0, }
  let magic = r.read_u16()
  if magic != 0xffd8 {
    raise JpegError(
      "Error parsing image. Illegal start bytes:\{magic.to_string(radix=16).to_upper()}",
    )
  }
  let mut width = 0
  let mut height = 0
  let mut components = 0
  let mut component_ids = []
  let mut seen_sof = false
  let mut colorspace = YCbCr
  let icc : Array[IccChunk] = []
  let mut last_byte = 0
  while true {
    let mut m = r.read_u8()
    if (m == 0xFF || m == 0) && last_byte == 0xFF {
      while m == 0xFF || m == 0 {
        last_byte = m
        m = r.read_u8()
      }
    }
    if last_byte == 0xFF {
      match m {
        // SOF(0..=2)
        0xC0 | 0xC1 | 0xC2 => {
          if seen_sof {
            raise JpegError(
              "Error parsing SOF segment. Reason:Two Start of Frame Markers",
            )
          }
          let length = r.read_u16()
          let precision = r.read_u8()
          if precision != 8 {
            raise JpegError(
              "Error parsing SOF segment. Reason:The library can only parse 8-bit images, the image has \{precision} bits of precision",
            )
          }
          height = r.read_u16()
          width = r.read_u16()
          if width == 0 || height == 0 {
            raise JpegError(
              "Image width or height is set to zero, cannot continue",
            )
          }
          components = r.read_u8()
          if components == 0 {
            raise JpegError(
              "Error parsing SOF segment. Reason:Number of components cannot be zero.",
            )
          }
          let expected = 8 + 3 * components
          if length != expected {
            raise JpegError(
              "Error parsing SOF segment. Reason:Length of start of frame differs from expected \{expected},value is \{length}",
            )
          }
          if components == 1 {
            colorspace = Luma
          }
          if components == 4 && colorspace is YCbCr {
            colorspace = Cmyk
          }
          component_ids = []
          for _ in 0..<components {
            let comp = r.peek(3)
            component_ids.push(comp[0].to_int())
            r.skip(3)
          }
          seen_sof = true
        }
        // DHT, DQT, COM, APP(0), APP(1), DRI, RST, UNKNOWN: skip the segment.
        // Upstream validates the tables; this port only skips them.
        0xC4 | 0xDB | 0xFE | 0xE0 | 0xE1 | 0xDD => {
          let length = r.read_u16()
          if length < 2 {
            raise JpegError(
              "\"Found a marker with invalid length:\{length}\\n\"",
            )
          }
          r.skip(length - 2)
        }
        // APP(2): ICC profile chunks.
        0xE2 => {
          let mut length = r.read_u16()
          if length < 2 {
            raise JpegError("\"Too small app2 segment\"")
          }
          length -= 2
          if length > 14 && r.peek(12) == b"ICC_PROFILE\x00" {
            length -= 12
            r.skip(12)
            let seq_no = r.read_u8()
            let num_markers = r.read_u8()
            length -= 2
            icc.push({ seq_no, num_markers, data: r.peek(length).to_owned(), })
          }
          r.skip(length)
        }
        // APP(14): Adobe color transform.
        0xEE => {
          let mut length = r.read_u16()
          if length < 2 {
            raise JpegError("\"Too small APP14 length\"")
          }
          if r.peek(5) == b"Adobe" {
            if length < 14 {
              raise JpegError("\"Too short of a length for App14 segment\"")
            }
            r.skip(11)
            let transform = r.read_u8()
            colorspace = match transform {
              0 => Cmyk
              1 => YCbCr
              2 => Ycck
              _ => raise JpegError("\"Unknown Adobe colorspace \{transform}\"")
            }
            length = @cmp.maximum(length - 14, 0)
          } else {
            length = @cmp.maximum(length - 2, 0)
          }
          r.skip(length)
        }
        // SOS: the image data follows.
        0xDA => {
          if components == 0 {
            raise JpegError(
              "\"Error decoding SOF Marker, Number of components cannot be zero.\"",
            )
          }
          if component_ids == [b'R'.to_int(), b'G'.to_int(), b'B'.to_int()] {
            colorspace = Rgb
          }
          return (width, height, colorspace, icc)
        }
        // EOI
        0xD9 => raise JpegError("\"Premature End of image\"")
        // DAC, DNL
        0xCC | 0xDC =>
          raise JpegError(
            "\"Parsing of the following header `\{if m == 0xCC { "DAC" } else { "DNL" }}` is not supported,cannot continue\"",
          )
        // Other SOF markers.
        0xC3 | 0xC5 | 0xC6 | 0xC7 | 0xC9 | 0xCA | 0xCB | 0xCD | 0xCE | 0xCF => {
          // These are `UNKNOWN` markers upstream and are skipped.
          let length = r.read_u16()
          if length < 2 {
            raise JpegError(
              "\"Found a marker with invalid length:\{length}\\n\"",
            )
          }
          r.skip(length - 2)
        }
        // SOI
        0xD8 | 0xD0 | 0xD1 | 0xD2 | 0xD3 | 0xD4 | 0xD5 | 0xD6 | 0xD7 | _ => {
          let length = r.read_u16()
          if length < 2 {
            raise JpegError(
              "\"Found a marker with invalid length:\{length}\\n\"",
            )
          }
          r.skip(length - 2)
        }
      }
    }
    last_byte = m
  }
  abort("unreachable")
}

///|
/// Assembles the ICC profile from its chunks (upstream `zune_jpeg::
/// JpegDecoder::icc_profile`).
fn assemble_icc(chunks : Array[IccChunk]) -> Bytes? {
  let num_markers = chunks.length()
  if num_markers == 0 || num_markers >= 255 {
    return None
  }
  let present : FixedArray[IccChunk?] = FixedArray::make(256, None)
  for chunk in chunks {
    if chunk.num_markers != num_markers {
      return None
    }
    if chunk.seq_no == 0 {
      return None
    }
    if present[chunk.seq_no] is Some(_) {
      return None
    }
    present[chunk.seq_no] = Some(chunk)
  }
  let buf = Buffer()
  for i in 1..<=num_markers {
    guard present[i] is Some(chunk) else { return None }
    buf.write_bytes(chunk.data)
  }
  Some(buf.to_bytes())
}

///|
/// Header information as reported by upstream `image::codecs::jpeg::
/// JpegDecoder`.
pub fn jpeg_image_info(data : BytesView) -> ImageInfo raise ImageError {
  let (width, height, colorspace, icc) = decode_jpeg_headers(data) catch {
    JpegError(msg) => decoding_error("Jpeg", msg)
  }
  {
    width: width.reinterpret_as_uint(),
    height: height.reinterpret_as_uint(),
    // Upstream `ColorType::from_jpeg`: color spaces other than luma and RGB
    // are converted to RGB.
    color: match colorspace {
      Luma => L8
      YCbCr | Rgb | Cmyk | Ycck => Rgb8
    },
    icc: assemble_icc(icc),
  }
}
