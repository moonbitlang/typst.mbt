// Port of the header parsing of the `gif` crate (v0.14.2,
// `Decoder::read_info` in `src/reader/mod.rs` and the `Magic`,
// `ScreenDescriptor`, `GlobalPalette` and extension states of
// `src/reader/decoder.rs`) as used by upstream `image::codecs::gif::
// GifDecoder::new`. Frame decoding is not ported.

///|
/// Header information as reported by upstream `image::codecs::gif::
/// GifDecoder` (the logical screen size; the output is always RGBA).
pub fn gif_image_info(data : BytesView) -> ImageInfo raise ImageError {
  let err = (msg : String) => decoding_error("Gif", msg)
  if data.length() < 6 {
    err("unexpected EOF")
  }
  let version = data[0:6]
  if version != b"GIF87a" && version != b"GIF89a" {
    err("malformed GIF header")
  }
  if data.length() < 13 {
    err("unexpected EOF")
  }
  let width = u16_le(data, 6)
  let height = u16_le(data, 8)
  let global_flags = data[10].to_int()
  let mut pos = 13
  if (global_flags & 0x80) != 0 {
    pos += 3 * (1 << ((global_flags & 0b111) + 1))
  }

  // Scan the extension blocks before the first image for an ICC profile
  // application extension.
  let mut icc : Buffer? = None
  while true {
    if pos >= data.length() {
      err("file does not contain any image data")
    }
    let block = data[pos]
    if block != b'\x21' {
      // Image (0x2C), trailer or anything else ends the header.
      break
    }
    if pos + 2 > data.length() {
      err("unexpected EOF")
    }
    let label = data[pos + 1]
    pos += 2
    let mut first = true
    let mut is_icc = false
    while true {
      if pos >= data.length() {
        err("unexpected EOF")
      }
      let len = data[pos].to_int()
      pos += 1
      if len == 0 {
        break
      }
      if pos + len > data.length() {
        err("unexpected EOF")
      }
      let sub = data[pos:pos + len]
      pos += len
      if label == b'\xFF' {
        if first {
          if sub == b"ICCRGBG1012" {
            is_icc = true
            icc = Some(Buffer())
          }
        } else if is_icc && icc is Some(buf) {
          buf.write_bytesview(sub)
        }
      }
      first = false
    }
  }
  {
    width: width.reinterpret_as_uint(),
    height: height.reinterpret_as_uint(),
    color: Rgba8,
    icc: icc.map(buf => buf.to_bytes()),
  }
}
