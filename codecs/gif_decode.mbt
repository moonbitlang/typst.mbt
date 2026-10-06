// Frame decoding of the `gif` crate (v0.14.2, `src/reader/decoder.rs`,
// `src/reader/converter.rs` and `Decoder::read_next_frame` in
// `src/reader/mod.rs`) with `DecodeOptions::new()` (50 MB memory limit, no
// frame consistency check, no end code check, unknown blocks rejected) and
// `ColorOutput::RGBA`, plus the LZW decoder of `weezl` (v0.1.12, LSB bit
// order) that it drives.
//
// Only the first frame is decoded, as `resvg` does. The streaming state
// machine is collapsed into a sequential parser over the whole file; it
// reports the same errors for the same files.

///|
/// The first frame of a GIF image: its descriptor and RGBA pixels (palette
/// colors, alpha 0 for the transparent index, zero for indices outside the
/// palette).
pub(all) struct GifFrame {
  /// The logical screen size.
  screen_width : Int
  screen_height : Int
  left : Int
  top : Int
  width : Int
  height : Int
  /// `width * height * 4` bytes.
  rgba : Bytes
}

///|
priv struct GifReader {
  data : BytesView
  mut pos : Int
}

///|
fn GifReader::byte(self : GifReader) -> Int raise ImageError {
  if self.pos >= self.data.length() {
    decoding_error("Gif", "Unexpected End of File")
  }
  let b = self.data[self.pos].to_int()
  self.pos += 1
  b
}

///|
fn GifReader::bytes(self : GifReader, n : Int) -> BytesView raise ImageError {
  if self.pos + n > self.data.length() {
    decoding_error("Gif", "Unexpected End of File")
  }
  let v = self.data[self.pos:self.pos + n]
  self.pos += n
  v
}

///|
/// Decodes the first frame (`DecodeOptions::read_info` followed by
/// `read_next_frame`). Returns `None` when the file has no frame.
pub fn decode_gif_first_frame(data : BytesView) -> GifFrame? raise ImageError {
  gif_decode_first(data, image_crate=false).frame
}

///|
/// The logical screen, the ICC profile read by `read_info` and the first
/// frame of a GIF.
priv struct GifFirst {
  screen_width : Int
  screen_height : Int
  icc : Bytes?
  frame : GifFrame?
}

///|
/// Decodes the header and the first frame. With `image_crate`, the frame is
/// read like `image::codecs::gif::GifDecoder::read_image` does
/// (`next_frame_info` + `read_into_buffer`, so without the `gif` crate's
/// memory limit, but with the `image` crate's default allocation limit for
/// frames that do not span the logical screen); otherwise like
/// `read_next_frame`.
fn gif_decode_first(
  data : BytesView,
  image_crate~ : Bool,
) -> GifFirst raise ImageError {
  let err = (msg : String) => decoding_error("Gif", msg)
  let r = { data, pos: 0, }
  let version = r.bytes(6)
  if version != b"GIF87a" && version != b"GIF89a" {
    err("malformed GIF header")
  }
  let desc = r.bytes(7)
  let screen_width = u16_le(desc, 0)
  let screen_height = u16_le(desc, 2)
  let global_flags = desc[4].to_int()
  let global_palette = if (global_flags & 0x80) != 0 {
    let len = 3 * (1 << ((global_flags & 0b111) + 1))
    Some(r.bytes(len))
  } else {
    None
  }
  // `set_global_palette` ignores an empty palette (impossible here).

  // The frame being described (created by a control extension or an image
  // descriptor).
  let mut transparent : Int? = None
  let mut has_frame = false
  let mut icc : Buffer? = None
  let first = (frame : GifFrame?) => {
    screen_width,
    screen_height,
    icc: icc.map(buf => buf.to_bytes()),
    frame,
  }
  while true {
    // The streaming decoder needs a byte at every block start, so the end of
    // the stream there is an `UnexpectedEof` (in `read_info` or
    // `next_frame_info`).
    let block = r.byte()
    match block {
      0x21 => {
        has_frame = true
        let label = r.byte()
        // Text, control, comment and application extensions.
        if label != 0x01 && label != 0xF9 && label != 0xFE && label != 0xFF {
          err("unknown extension block encountered")
        }
        let mut last : BytesView = b""[:]
        // Application extensions before the first image are read by
        // `read_info` (`read_application_extension`), which collects the
        // ICC profile.
        let mut first_block = true
        let mut is_icc = false
        while true {
          let len = r.byte()
          if len == 0 {
            break
          }
          last = r.bytes(len)
          if label == 0xFF {
            if first_block {
              is_icc = last == b"ICCRGBG1012"
              if is_icc {
                icc = Some(Buffer())
              }
            } else if is_icc && icc is Some(buf) {
              buf.write_bytesview(last)
            }
          }
          first_block = false
        }
        if label == 0xF9 {
          // `read_control_extension` on the last sub-block.
          if last.length() != 4 {
            err("control extension has wrong length")
          }
          let flags = last[0].to_int()
          transparent = if (flags & 1) != 0 {
            Some(last[3].to_int())
          } else {
            None
          }
        }
      }
      0x2C => {
        let header = r.bytes(9)
        let left = u16_le(header, 0)
        let top = u16_le(header, 2)
        let width = u16_le(header, 4)
        let height = u16_le(header, 6)
        let flags = header[8].to_int()
        let interlaced = (flags & 0b0100_0000) != 0
        let local_palette = if (flags & 0b1000_0000) != 0 {
          Some(r.bytes(3 * (1 << ((flags & 0b111) + 1))))
        } else {
          None
        }
        let min_code_size = r.byte()
        if min_code_size > 11 || min_code_size < 1 {
          err("invalid minimal code size")
        }
        let palette = match local_palette {
          Some(p) => p
          None =>
            match global_palette {
              Some(p) => p
              None =>
                decoding_error(
                  "Gif", "no color table available for current frame",
                )
            }
        }
        let pixel_bytes = width.to_int64() * height.to_int64() * 4L
        if image_crate {
          // `GifDecoder::read_image` decodes frames that do not span the
          // logical screen into a separate buffer, reserved against the
          // default allocation limit (512 MiB) of `Limits::default()`.
          let spans = left == 0 &&
            width == screen_width &&
            top + height <= screen_height
          if !spans && pixel_bytes > 512L * 1024L * 1024L {
            raise ImageError("Memory limit exceeded")
          }
        } else if pixel_bytes > 50_000_000L {
          // `check_buffer_size` against the 50 MB memory limit.
          raise ImageError("Memory limit reached")
        }
        // `fill_buffer` rejects empty buffers; an interlaced frame without
        // rows reads nothing.
        if pixel_bytes == 0L && !(interlaced && height == 0) {
          err("odd-sized buffer")
        }
        let rgba = gif_decode_pixels(
          r, min_code_size, width, height, interlaced, palette, transparent,
        )
        return first(
          Some({ screen_width, screen_height, left, top, width, height, rgba, }),
        )
      }
      0x3B => {
        // Right after the header (whose last state consumes the block type),
        // the `BlockStart` state that emits `HeaderEnd` needs one more byte.
        // After an extension, the trailer is not consumed before.
        if !has_frame && r.pos >= r.data.length() {
          err("Unexpected End of File")
        }
        return first(None)
      }
      _ => {
        // `BlockStart` needs a byte before it rejects the block.
        if r.pos >= r.data.length() {
          err("Unexpected End of File")
        }
        err("unknown block type encountered")
      }
    }
  }
  first(None)
}

///|
/// Decodes a GIF like upstream `image::DynamicImage::from_decoder` with an
/// `image::codecs::gif::GifDecoder` (`ColorOutput::RGBA`): an RGBA image of
/// the logical screen size with the first frame placed at its position
/// (pixels outside the frame are transparent black, parts of the frame
/// outside the screen are cut off), plus the ICC profile (upstream
/// `GifDecoder::icc_profile`).
pub fn decode_gif_image(
  data : BytesView,
) -> (ImageInfo, Bytes) raise ImageError {
  let first = gif_decode_first(data, image_crate=true)
  guard first.frame is Some(frame) else {
    // `ParameterErrorKind::NoMoreData`.
    raise ImageError("The end of the image has been reached")
  }
  let width = first.screen_width
  let height = first.screen_height
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<frame.height {
    let sy = frame.top + y
    if sy >= height {
      break
    }
    for x in 0..<frame.width {
      let sx = frame.left + x
      if sx >= width {
        break
      }
      let src = (y * frame.width + x) * 4
      let dst = (sy * width + sx) * 4
      for k in 0..<4 {
        buf[dst + k] = frame.rgba[src + k]
      }
    }
  }
  let info = {
    width: width.reinterpret_as_uint(),
    height: height.reinterpret_as_uint(),
    color: Rgba8,
    icc: first.icc,
  }
  (info, Bytes::from_array(buf))
}

///|
/// The LZW sub-block data stream of a frame.
priv struct GifLzwInput {
  r : GifReader
  /// Bytes left in the current sub-block; `-1` after the terminator.
  mut left : Int
}

///|
fn GifLzwInput::next_byte(self : GifLzwInput) -> Int? raise ImageError {
  while self.left == 0 {
    let len = self.r.byte()
    if len == 0 {
      self.left = -1
      return None
    }
    self.left = len
  }
  if self.left < 0 {
    return None
  }
  self.left -= 1
  Some(self.r.byte())
}

///|
/// LZW-decodes the frame indices and expands them to RGBA, deinterlacing
/// rows like `PixelConverter::read_into_buffer`.
fn gif_decode_pixels(
  r : GifReader,
  min_code_size : Int,
  width : Int,
  height : Int,
  interlaced : Bool,
  palette : BytesView,
  transparent : Int?,
) -> Bytes raise ImageError {
  let n = width * height
  let indices = FixedArray::make(n, b'\x00')
  let input = { r, left: 0, }
  let count = lzw_decode_into(input, min_code_size, indices)
  if count < n {
    decoding_error("Gif", "image truncated")
  }
  let out = FixedArray::make(n * 4, b'\x00')
  let row_order = if interlaced {
    gif_interlaced_rows(height)
  } else {
    Array::makei(height, i => i)
  }
  for i, row in row_order {
    for x in 0..<width {
      let idx = indices[i * width + x].to_int()
      let o = (row * width + x) * 4
      let plte = idx * 3
      if plte + 3 <= palette.length() {
        out[o] = palette[plte]
        out[o + 1] = palette[plte + 1]
        out[o + 2] = palette[plte + 2]
        out[o + 3] = if transparent == Some(idx) { b'\x00' } else { b'\xFF' }
      }
    }
  }
  Bytes::from_array(out)
}

///|
/// The row order of an interlaced frame (`InterlaceIterator`).
fn gif_interlaced_rows(len : Int) -> Array[Int] {
  let rows = []
  if len == 0 {
    return rows
  }
  let steps : ReadOnlyArray[_] = [8, 8, 4, 2]
  let starts : ReadOnlyArray[_] = [4, 2, 1, 0]
  let mut cur = 0
  let mut pass = 0
  while pass < 4 {
    let mut n = cur + steps[pass]
    while n >= len {
      if pass >= 4 {
        return rows
      }
      n = starts[pass]
      pass += 1
    }
    rows.push(cur)
    cur = n
  }
  rows
}

///|
/// Decodes LZW codes (LSB first, GIF variant) into `out` until it is full,
/// the end code is reached or the input ends. Returns the number of bytes
/// written. Invalid codes raise `weezl`'s `InvalidCode` error.
fn lzw_decode_into(
  input : GifLzwInput,
  min_code_size : Int,
  out : FixedArray[Byte],
) -> Int raise ImageError {
  let clear = 1 << min_code_size
  let end = clear + 1
  // Each entry: (prefix code, last byte, length).
  let prefix = FixedArray::make(4096, 0)
  let suffix = FixedArray::make(4096, b'\x00')
  let lengths = FixedArray::make(4096, 0)
  for i in 0..<clear {
    prefix[i] = -1
    suffix[i] = i.to_byte()
    lengths[i] = 1
  }
  let mut next = clear + 2
  let mut size = min_code_size + 1
  let mut prev = -1
  let mut bits = 0
  let mut nbits = 0
  let mut written = 0
  let total = out.length()
  let scratch = FixedArray::make(4096, b'\x00')
  while written < total {
    while nbits < size {
      match input.next_byte() {
        Some(b) => {
          bits = bits | (b << nbits)
          nbits += 8
        }
        None => return written
      }
    }
    let code = bits & ((1 << size) - 1)
    bits = bits >> size
    nbits -= size
    if code == clear {
      next = clear + 2
      size = min_code_size + 1
      prev = -1
      continue
    }
    if code == end {
      return written
    }
    // Determine the string for `code`.
    let (string_code, extra) = if code < next && (code < clear || code > end) {
      (code, -1)
    } else if code == next && prev >= 0 {
      // KwKwK: the previous string plus its first byte.
      (prev, first_byte(prefix, suffix, prev))
    } else {
      raise ImageError("invalid code")
    }
    if prev < 0 && code >= clear {
      raise ImageError("invalid code")
    }
    // Write the string (in reverse into scratch).
    let len = lengths[string_code]
    let mut c = string_code
    for k = len - 1; k >= 0; k = k - 1 {
      scratch[k] = suffix[c]
      c = prefix[c]
    }
    let full_len = if extra >= 0 {
      scratch[len] = extra.to_byte()
      len + 1
    } else {
      len
    }
    let m = if written + full_len > total { total - written } else { full_len }
    for k in 0..<m {
      out[written + k] = scratch[k]
    }
    written += m
    // Add the new table entry.
    if prev >= 0 && next < 4096 {
      prefix[next] = prev
      suffix[next] = scratch[0]
      lengths[next] = lengths[prev] + 1
      next += 1
      if next == 1 << size && size < 12 {
        size += 1
      }
    }
    prev = code
  }
  written
}

///|
fn first_byte(
  prefix : FixedArray[Int],
  suffix : FixedArray[Byte],
  code : Int,
) -> Int {
  let mut c = code
  while prefix[c] >= 0 {
    c = prefix[c]
  }
  suffix[c].to_int()
}

///|
test "gif interlaced rows" {
  @debug.debug_inspect(gif_interlaced_rows(0), content="[]")
  @debug.debug_inspect(gif_interlaced_rows(1), content="[0]")
  @debug.debug_inspect(gif_interlaced_rows(5), content="[0, 4, 2, 1, 3]")
  @debug.debug_inspect(
    gif_interlaced_rows(17),
    content="[0, 8, 16, 4, 12, 2, 6, 10, 14, 1, 3, 5, 7, 9, 11, 13, 15]",
  )
}
