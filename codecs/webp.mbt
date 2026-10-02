// Port of the header parsing of the `image-webp` crate (v0.2.4,
// `WebPDecoder::read_data` in `src/decoder.rs` and `read_extended_header`
// in `src/extended.rs`) as used by upstream `image::codecs::webp::
// WebPDecoder::new`. Bitstream decoding is not ported.

///|
/// Formats a fourcc like Rust's `{:x?}` of a `[u8; 4]`.
fn fourcc_debug(b : BytesView) -> String {
  let parts = b.iter().map(x => x.to_int().to_string(radix=16)).collect()
  "[" + parts.join(", ") + "]"
}

///|
/// Header information as reported by upstream `image::codecs::webp::
/// WebPDecoder`.
pub fn webp_image_info(data : BytesView) -> ImageInfo raise ImageError {
  let err = (msg : String) => decoding_error("WebP", msg)
  let eof = () => err("IO Error: failed to fill whole buffer")
  if data.length() < 12 {
    eof()
  }
  if data[0:4] != b"RIFF" {
    err("Invalid Chunk header: \{fourcc_debug(b"RIFF"[:])}")
  }
  let riff_size = u32_le(data, 4).to_int64()
  if data[8:12] != b"WEBP" {
    err("Invalid WebP signature: \{fourcc_debug(data[8:12])}")
  }
  if data.length() < 20 {
    eof()
  }
  let chunk = data[12:16]
  let chunk_size = u32_le(data, 16).to_int64()
  let chunk_size_rounded = chunk_size + (chunk_size & 1)
  let start = 20
  let mut width = 0U
  let mut height = 0U
  let mut has_alpha = false
  let mut icc = None
  match chunk {
    b"VP8 " => {
      if data.length() < start + 10 {
        eof()
      }
      let tag = u24_le(data, start)
      if (tag & 1) != 0 {
        err("Unsupported feature: Non-keyframe frames")
      }
      let magic = data[start + 3:start + 6]
      if magic != b"\x9d\x01\x2a" {
        let parts = magic
          .iter()
          .map(x => x.to_int().to_string(radix=16))
          .collect()
        err("Invalid VP8 magic: [\{parts.join(", ")}]")
      }
      width = (u16_le(data, start + 6) & 0x3FFF).reinterpret_as_uint()
      height = (u16_le(data, start + 8) & 0x3FFF).reinterpret_as_uint()
      if width == 0 || height == 0 {
        err("Inconsistent image sizes")
      }
    }
    b"VP8L" => {
      if data.length() < start + 5 {
        eof()
      }
      let signature = data[start].to_int()
      if signature != 0x2f {
        err("Invalid lossless signature: \{signature.to_string(radix=16)}")
      }
      let header = u32_le(data, start + 1)
      let version = header >> 29
      if version != 0 {
        err("Invalid lossless version number: \{version}")
      }
      width = (1 + header) & 0x3FFF
      height = (1 + (header >> 14)) & 0x3FFF
      has_alpha = ((header >> 28) & 1) != 0
    }
    b"VP8X" => {
      if data.length() < start + 10 {
        eof()
      }
      let flags = data[start].to_int()
      has_alpha = (flags & 0b00010000) != 0
      width = u24_le(data, start + 4) + 1
      height = u24_le(data, start + 7) + 1
      if width.to_uint64() * height.to_uint64() > 0xFFFFFFFFUL {
        err("Image too large")
      }

      // Find the ICCP chunk among the following chunks.
      let mut position = start.to_int64() + chunk_size_rounded
      let max_position = position + @cmp.maximum(riff_size - 12, 0L)
      while position < max_position {
        let pos = position.to_int()
        if pos + 8 > data.length() {
          break
        }
        let name = data[pos:pos + 4]
        let size = u32_le(data, pos + 4).to_int64()
        let rounded = size + (size & 1)
        if name == b"ICCP" && icc is None {
          let end = @cmp.minimum((position + 8 + size).to_int(), data.length())
          icc = Some(data[pos + 8:end].to_owned())
        }
        position += 8 + rounded
      }
    }
    _ => err("Invalid Chunk header: \{fourcc_debug(chunk)}")
  }
  ignore(chunk_size)
  { width, height, color: if has_alpha { Rgba8 } else { Rgb8 }, icc, }
}
