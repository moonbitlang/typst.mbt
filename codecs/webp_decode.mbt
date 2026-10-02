// Port of the decoding of image-webp 0.2.4: `WebPDecoder::new` +
// `read_image` (`src/decoder.rs`), the extended format helpers
// (`src/extended.rs`) and `src/alpha_blending.rs`. Lossy frames are
// converted with the default (bilinear) upsampling.

///|
/// A decoded WebP image: `width * height` RGBA pixels when `has_alpha`,
/// RGB pixels otherwise (upstream `read_image`'s buffer layout).
pub(all) struct WebpImage {
  width : Int
  height : Int
  has_alpha : Bool
  data : Bytes
}

///|
/// A chunk of the RIFF container: its fourcc and data range.
priv struct WebpChunk {
  fourcc : Bytes
  start : Int64
  end : Int64
}

///|
priv struct WebpExtendedInfo {
  alpha : Bool
  canvas_width : Int
  canvas_height : Int
  exif_metadata : Bool
  xmp_metadata : Bool
  animation : Bool
  background_color : FixedArray[Byte]?
}

///|
priv struct WebpParser {
  data : BytesView
  mut pos : Int64
  chunks : Array[WebpChunk]
  mut width : Int
  mut height : Int
  mut extended : WebpExtendedInfo?
  mut is_lossy : Bool
  mut has_alpha : Bool
  mut num_frames : Int
}

///|
let webp_eof : String = "IO Error: failed to fill whole buffer"

///|
fn WebpParser::read_u8(self : WebpParser) -> Int raise ImageError {
  if self.pos < 0L || self.pos + 1L > self.data.length().to_int64() {
    raise ImageError(webp_eof)
  }
  let v = self.data[self.pos.to_int()].to_int()
  self.pos += 1L
  v
}

///|
fn WebpParser::read_bytes(
  self : WebpParser,
  n : Int,
) -> BytesView raise ImageError {
  if self.pos < 0L || self.pos + n.to_int64() > self.data.length().to_int64() {
    raise ImageError(webp_eof)
  }
  let p = self.pos.to_int()
  self.pos += n.to_int64()
  self.data[p:p + n]
}

///|
fn WebpParser::read_u16(self : WebpParser) -> Int raise ImageError {
  let b = self.read_bytes(2)
  b[0].to_int() | (b[1].to_int() << 8)
}

///|
fn WebpParser::read_u24(self : WebpParser) -> Int raise ImageError {
  let b = self.read_bytes(3)
  b[0].to_int() | (b[1].to_int() << 8) | (b[2].to_int() << 16)
}

///|
fn WebpParser::read_u32(self : WebpParser) -> UInt raise ImageError {
  let b = self.read_bytes(4)
  b[0].to_uint() |
  (b[1].to_uint() << 8) |
  (b[2].to_uint() << 16) |
  (b[3].to_uint() << 24)
}

///|
/// `read_chunk_header`: fourcc, size and size rounded up to even.
fn WebpParser::read_chunk_header(
  self : WebpParser,
) -> (Bytes, Int64, Int64) raise ImageError {
  let fourcc = self.read_bytes(4).to_bytes()
  let chunk_size = self.read_u32()
  let chunk_size_rounded = if chunk_size == 0xFFFFFFFFU {
    chunk_size
  } else {
    chunk_size + (chunk_size & 1)
  }
  (
    fourcc,
    chunk_size.to_uint64().reinterpret_as_int64(),
    chunk_size_rounded.to_uint64().reinterpret_as_int64(),
  )
}

///|
fn is_known_chunk(fourcc : Bytes) -> Bool {
  fourcc == b"RIFF" ||
  fourcc == b"WEBP" ||
  fourcc == b"VP8 " ||
  fourcc == b"VP8L" ||
  fourcc == b"VP8X" ||
  fourcc == b"ANIM" ||
  fourcc == b"ANMF" ||
  fourcc == b"ALPH" ||
  fourcc == b"ICCP" ||
  fourcc == b"EXIF" ||
  fourcc == b"XMP "
}

///|
fn WebpParser::chunk(self : WebpParser, fourcc : Bytes) -> WebpChunk? {
  for c in self.chunks {
    if c.fourcc == fourcc {
      return Some(c)
    }
  }
  None
}

///|
/// `self.chunks.entry(chunk).or_insert(range)`.
fn WebpParser::insert_chunk(
  self : WebpParser,
  fourcc : Bytes,
  start : Int64,
  end : Int64,
) -> Unit {
  if self.chunk(fourcc) is None {
    self.chunks.push({ fourcc, start, end, })
  }
}

///|
/// The bytes of a range (`range_reader`: reads past the end of the data
/// just see fewer bytes).
fn WebpParser::range(
  self : WebpParser,
  start : Int64,
  end : Int64,
) -> BytesView {
  let len = self.data.length().to_int64()
  let s = if start > len { len } else { start }
  let e = if end > len { len } else { end }
  let e = if e < s { s } else { e }
  self.data[s.to_int():e.to_int()]
}

///|
/// `WebPDecoder::read_data`.
fn WebpParser::read_data(self : WebpParser) -> Unit raise ImageError {
  let (riff, riff_size, _) = self.read_chunk_header()
  if riff != b"RIFF" {
    raise ImageError("Invalid Chunk header: \{fourcc_debug(b"RIFF"[:])}")
  }
  let webp = self.read_bytes(4)
  if webp != b"WEBP" {
    raise ImageError("Invalid WebP signature: \{fourcc_debug(webp)}")
  }
  let (chunk, chunk_size, chunk_size_rounded) = self.read_chunk_header()
  let start = self.pos
  if chunk == b"VP8 " {
    let tag = self.read_u24()
    let keyframe = (tag & 1) == 0
    if !keyframe {
      raise ImageError("Unsupported feature: Non-keyframe frames")
    }
    let magic = self.read_bytes(3)
    if magic != b"\x9d\x01\x2a" {
      raise ImageError("Invalid VP8 magic: \{fourcc_debug(magic)}")
    }
    let w = self.read_u16()
    let h = self.read_u16()
    self.width = w & 0x3FFF
    self.height = h & 0x3FFF
    if self.width == 0 || self.height == 0 {
      raise ImageError("Inconsistent image sizes")
    }
    self.insert_chunk(b"VP8 ", start, start + chunk_size)
    self.is_lossy = true
  } else if chunk == b"VP8L" {
    let signature = self.read_u8()
    if signature != 0x2f {
      raise ImageError(
        "Invalid lossless signature: \{signature.to_string(radix=16)}",
      )
    }
    let header = self.read_u32()
    let version = header >> 29
    if version != 0 {
      raise ImageError("Invalid lossless version number: \{version}")
    }
    self.width = ((1U + header) & 0x3FFF).reinterpret_as_int()
    self.height = ((1U + (header >> 14)) & 0x3FFF).reinterpret_as_int()
    self.insert_chunk(b"VP8L", start, start + chunk_size)
    self.has_alpha = ((header >> 28) & 1) != 0
  } else if chunk == b"VP8X" {
    let info = self.read_extended_header()
    self.width = info.canvas_width
    self.height = info.canvas_height
    let mut position = start + chunk_size_rounded
    let riff_rest = riff_size - 12L
    let max_position = position + (if riff_rest > 0L { riff_rest } else { 0L })
    self.pos = position
    while position < max_position {
      let (chunk, chunk_size, chunk_size_rounded) = self.read_chunk_header() catch {
        ImageError(msg) =>
          if msg == webp_eof {
            break
          } else {
            raise ImageError(msg)
          }
      }
      let range_start = position + 8L
      let range_end = position + 8L + chunk_size
      position += 8L + chunk_size_rounded
      if is_known_chunk(chunk) {
        self.insert_chunk(chunk, range_start, range_end)
      }
      if chunk == b"ANMF" {
        self.num_frames += 1
        if chunk_size < 24L {
          raise ImageError("Invalid chunk size")
        }
        self.pos += 12L
        let _duration = self.read_u32() & 0xffffff
        if !self.is_lossy {
          let (subchunk, _, _) = self.read_chunk_header()
          if subchunk == b"VP8 " || subchunk == b"ALPH" {
            self.is_lossy = true
          }
          self.pos += chunk_size_rounded - 24L
        } else {
          self.pos += chunk_size_rounded - 16L
        }
        continue
      }
      self.pos += chunk_size_rounded
    }
    self.is_lossy = self.is_lossy || self.chunk(b"VP8 ") is Some(_)
    let has = (f : Bytes) => self.chunk(f) is Some(_)
    if (info.animation && (!has(b"ANIM") || !has(b"ANMF"))) ||
      (info.exif_metadata && !has(b"EXIF")) ||
      (info.xmp_metadata && !has(b"XMP ")) ||
      (!info.animation && has(b"VP8 ") == has(b"VP8L")) {
      raise ImageError("An expected chunk was missing")
    }
    if info.animation {
      // `read_chunk(ANIM, 6)`.
      let anim = self.chunk(b"ANIM").unwrap()
      if anim.end - anim.start > 6L {
        raise ImageError("Invalid chunk size")
      }
      let len = (anim.end - anim.start).to_int()
      self.pos = anim.start
      let anim_data = self.read_bytes(len)
      if anim_data.length() < 6 {
        raise ImageError(webp_eof)
      }
    }
    if self.chunk(b"ANMF") is Some(range) {
      let mut position = range.start + 16L
      self.pos = position
      for _ in 0..<2 {
        let (subchunk, subchunk_size, subchunk_size_rounded) = self.read_chunk_header()
        self.insert_chunk(
          subchunk,
          position + 8L,
          position + 8L + subchunk_size,
        )
        position += 8L + subchunk_size_rounded
        if position + 8L > range.end {
          break
        }
      }
    }
    self.has_alpha = info.alpha
    self.extended = Some(info)
  } else {
    raise ImageError("Invalid Chunk header: \{fourcc_debug(chunk)}")
  }
}

///|
/// `read_extended_header`.
fn WebpParser::read_extended_header(
  self : WebpParser,
) -> WebpExtendedInfo raise ImageError {
  let chunk_flags = self.read_u8()
  let alpha = (chunk_flags & 0b00010000) != 0
  let exif_metadata = (chunk_flags & 0b00001000) != 0
  let xmp_metadata = (chunk_flags & 0b00000100) != 0
  let animation = (chunk_flags & 0b00000010) != 0
  let _reserved_bytes = self.read_u24()
  let canvas_width = self.read_u24() + 1
  let canvas_height = self.read_u24() + 1
  if canvas_width.to_int64() * canvas_height.to_int64() > 0xFFFFFFFFL {
    raise ImageError("Image too large")
  }
  {
    alpha,
    canvas_width,
    canvas_height,
    exif_metadata,
    xmp_metadata,
    animation,
    background_color: None,
  }
}

///|
/// The alpha filtering methods (`FilteringMethod`): none, horizontal,
/// vertical, gradient.
fn get_alpha_predictor(
  x : Int,
  y : Int,
  width : Int,
  filtering_method : Int,
  image_slice : FixedArray[Byte],
) -> Int {
  let alpha = (index : Int) => image_slice[index * 4 + 3].to_int()
  match filtering_method {
    0 => 0
    1 =>
      if x == 0 && y == 0 {
        0
      } else if x == 0 {
        alpha((y - 1) * width + x)
      } else {
        alpha(y * width + x - 1)
      }
    2 =>
      if x == 0 && y == 0 {
        0
      } else if y == 0 {
        alpha(y * width + x - 1)
      } else {
        alpha((y - 1) * width + x)
      }
    _ => {
      let (left, top, top_left) = if x == 0 && y == 0 {
        (0, 0, 0)
      } else if x == 0 {
        let val = alpha((y - 1) * width + x)
        (val, val, val)
      } else if y == 0 {
        let val = alpha(y * width + x - 1)
        (val, val, val)
      } else {
        (
          alpha(y * width + x - 1),
          alpha((y - 1) * width + x),
          alpha((y - 1) * width + x - 1),
        )
      }
      clamp(left + top - top_left, 0, 255)
    }
  }
}

///|
/// `read_alpha_chunk`: the filtering method and the alpha values.
fn read_alpha_chunk(
  data : BytesView,
  width : Int,
  height : Int,
) -> (Int, FixedArray[Byte]) raise ImageError {
  if data.length() < 1 {
    raise ImageError(webp_eof)
  }
  let info_byte = data[0].to_int()
  let preprocessing = (info_byte & 0b00110000) >> 4
  let filtering = (info_byte & 0b00001100) >> 2
  let compression = info_byte & 0b00000011
  if preprocessing > 1 {
    raise ImageError("Alpha chunk preprocessing flag invalid")
  }
  let lossless_compression = match compression {
    0 => false
    1 => true
    _ => raise ImageError("Invalid compression method")
  }
  let n = width * height
  let alpha = if lossless_compression {
    let decoder = LosslessDecoder::new(data[1:])
    let rgba = FixedArray::make(n * 4, b'\x00')
    decoder.decode_frame(width, height, true, rgba)
    FixedArray::makei(n, i => rgba[i * 4 + 1])
  } else {
    if data.length() - 1 < n {
      raise ImageError(webp_eof)
    }
    FixedArray::makei(n, i => data[1 + i])
  }
  (filtering, alpha)
}

///|
/// Applies the alpha values of an ALPH chunk to an RGBA buffer.
fn apply_alpha(
  buf : FixedArray[Byte],
  width : Int,
  height : Int,
  filtering : Int,
  alpha : FixedArray[Byte],
) -> Unit {
  for y in 0..<height {
    for x in 0..<width {
      let predictor = get_alpha_predictor(x, y, width, filtering, buf)
      let alpha_index = y * width + x
      buf[alpha_index * 4 + 3] = (predictor + alpha[alpha_index].to_int()).to_byte()
    }
  }
}

///|
fn div_by_255(v : UInt) -> UInt {
  (((v + 0x80) >> 8) + v + 0x80) >> 8
}

///|
fn blend_channel_nonpremult(
  src : UInt,
  src_a : UInt,
  dst : UInt,
  dst_a : UInt,
  scale : UInt,
  shift : Int,
) -> UInt {
  let src_channel = (src >> shift) & 0xff
  let dst_channel = (dst >> shift) & 0xff
  let blend_unscaled = src_channel * src_a + dst_channel * dst_a
  ((blend_unscaled * scale) >> 24) & 0xff
}

///|
/// `do_alpha_blending` on little-endian packed RGBA.
fn blend_pixel_nonpremult(src : UInt, dst : UInt) -> UInt {
  let src_a = (src >> 24) & 0xff
  if src_a == 0 {
    dst
  } else {
    let dst_a = (dst >> 24) & 0xff
    let dst_factor_a = div_by_255(dst_a * (255 - src_a))
    let blend_a = src_a + dst_factor_a
    let scale = (1U << 24) / blend_a
    let dfa = dst_factor_a & 0xff
    let blend_r = blend_channel_nonpremult(src, src_a, dst, dfa, scale, 0)
    let blend_g = blend_channel_nonpremult(src, src_a, dst, dfa, scale, 8)
    let blend_b = blend_channel_nonpremult(src, src_a, dst, dfa, scale, 16)
    blend_r | (blend_g << 8) | (blend_b << 16) | (blend_a << 24)
  }
}

///|
fn load_rgba(b : FixedArray[Byte], i : Int) -> UInt {
  b[i].to_uint() |
  (b[i + 1].to_uint() << 8) |
  (b[i + 2].to_uint() << 16) |
  (b[i + 3].to_uint() << 24)
}

///|
/// `extended::composite_frame`.
fn composite_frame(
  canvas : FixedArray[Byte],
  canvas_width : Int,
  canvas_height : Int,
  clear_color : FixedArray[Byte]?,
  frame : FixedArray[Byte],
  frame_offset_x : Int,
  frame_offset_y : Int,
  frame_width : Int,
  frame_height : Int,
  frame_has_alpha : Bool,
  frame_use_alpha_blending : Bool,
  previous_frame_width : Int,
  previous_frame_height : Int,
  previous_frame_offset_x : Int,
  previous_frame_offset_y : Int,
) -> Unit {
  let frame_is_full_size = frame_offset_x == 0 &&
    frame_offset_y == 0 &&
    frame_width == canvas_width &&
    frame_height == canvas_height
  if frame_is_full_size && !frame_use_alpha_blending {
    if frame_has_alpha {
      for i in 0..<canvas.length() {
        canvas[i] = frame[i]
      }
    } else {
      let n = imin3(
        frame.length() / 3,
        canvas.length() / 4,
        canvas.length() / 4,
      )
      for p in 0..<n {
        canvas[p * 4] = frame[p * 3]
        canvas[p * 4 + 1] = frame[p * 3 + 1]
        canvas[p * 4 + 2] = frame[p * 3 + 2]
        canvas[p * 4 + 3] = b'\xff'
      }
    }
    return
  }
  if clear_color is Some(clear_color) {
    match (frame_is_full_size, frame_has_alpha) {
      (true, true) =>
        for p = 0; p + 4 <= canvas.length(); p = p + 4 {
          for k in 0..<4 {
            canvas[p + k] = clear_color[k]
          }
        }
      (true, false) =>
        for p = 0; p + 3 <= canvas.length(); p = p + 3 {
          for k in 0..<3 {
            canvas[p + k] = clear_color[k]
          }
        }
      (false, true) =>
        for y in 0..<previous_frame_height {
          for x in 0..<previous_frame_width {
            let canvas_index = (
                x +
                previous_frame_offset_x +
                (y + previous_frame_offset_y) * canvas_width
              ) *
              4
            for k in 0..<4 {
              canvas[canvas_index + k] = clear_color[k]
            }
          }
        }
      (false, false) =>
        for y in 0..<previous_frame_height {
          for x in 0..<previous_frame_width {
            let canvas_index = (
                x +
                previous_frame_offset_x +
                (y + previous_frame_offset_y) * canvas_width
              ) *
              3
            for k in 0..<3 {
              canvas[canvas_index + k] = clear_color[k]
            }
          }
        }
    }
  }
  let sat_sub = (a : Int, b : Int) => if a > b { a - b } else { 0 }
  let width = imin3(
    frame_width,
    sat_sub(canvas_width, frame_offset_x),
    frame_width,
  )
  let height = imin3(
    frame_height,
    sat_sub(canvas_height, frame_offset_y),
    frame_height,
  )
  if frame_has_alpha && frame_use_alpha_blending {
    for y in 0..<height {
      for x in 0..<width {
        let frame_index = (x + y * frame_width) * 4
        let canvas_index = (
            x + frame_offset_x + (y + frame_offset_y) * canvas_width
          ) *
          4
        let blended = blend_pixel_nonpremult(
          load_rgba(frame, frame_index),
          load_rgba(canvas, canvas_index),
        )
        for k in 0..<4 {
          canvas[canvas_index + k] = ((blended >> (8 * k)) & 0xff)
            .reinterpret_as_int()
            .to_byte()
        }
      }
    }
  } else if frame_has_alpha {
    for y in 0..<height {
      let frame_index = y * frame_width * 4
      let canvas_index = (frame_offset_x + (y + frame_offset_y) * canvas_width) *
        4
      for i in 0..<(width * 4) {
        canvas[canvas_index + i] = frame[frame_index + i]
      }
    }
  } else {
    for y in 0..<height {
      let index = y * frame_width * 3
      let canvas_index = (frame_offset_x + (y + frame_offset_y) * canvas_width) *
        4
      for x in 0..<width {
        canvas[canvas_index + x * 4] = frame[index + x * 3]
        canvas[canvas_index + x * 4 + 1] = frame[index + x * 3 + 1]
        canvas[canvas_index + x * 4 + 2] = frame[index + x * 3 + 2]
        canvas[canvas_index + x * 4 + 3] = b'\xff'
      }
    }
  }
}

///|
/// `read_frame` for the first frame of an animation (as `read_image` does),
/// into `buf`.
fn WebpParser::read_first_frame(
  self : WebpParser,
  buf : FixedArray[Byte],
) -> Unit raise ImageError {
  guard self.extended is Some(info) else { abort("not animated") }
  if self.num_frames == 0 {
    raise ImageError("No more frames")
  }
  self.pos = self.chunk(b"ANMF").unwrap().start - 8L
  let anmf_size = match self.read_chunk_header() {
    (fourcc, size, _) if fourcc == b"ANMF" && size >= 32L => size
    _ => raise ImageError("Invalid Chunk header: \{fourcc_debug(b"ANMF"[:])}")
  }
  let frame_x = self.read_u24() * 2
  let frame_y = self.read_u24() * 2
  let frame_width = self.read_u24() + 1
  let frame_height = self.read_u24() + 1
  if frame_width > 16384 || frame_height > 16384 {
    raise ImageError("Image too large")
  }
  if frame_x + frame_width > self.width || frame_y + frame_height > self.height {
    raise ImageError("Frame outside image")
  }
  let _duration = self.read_u24()
  let frame_info = self.read_u8()
  let use_alpha_blending = (frame_info & 0b00000010) == 0
  // The first frame: `dispose_next_frame` is initially true.
  let clear_color = info.background_color
  let (chunk, chunk_size, chunk_size_rounded) = self.read_chunk_header()
  if chunk_size_rounded + 24L > anmf_size {
    raise ImageError("Invalid Chunk header: \{fourcc_debug(chunk)}")
  }
  let n = frame_width * frame_height
  let (frame, frame_has_alpha) = if chunk == b"VP8 " {
    let raw_frame = vp8_decode_frame(
      self.range(self.pos, self.pos + chunk_size),
    )
    if raw_frame.width != frame_width || raw_frame.height != frame_height {
      raise ImageError("Inconsistent image sizes")
    }
    let rgb_frame = FixedArray::make(n * 3, b'\x00')
    raw_frame.fill_rgb(rgb_frame, 3)
    (rgb_frame, false)
  } else if chunk == b"VP8L" {
    let lossless_decoder = LosslessDecoder::new(
      self.range(self.pos, self.pos + chunk_size),
    )
    let rgba_frame = FixedArray::make(n * 4, b'\x00')
    lossless_decoder.decode_frame(frame_width, frame_height, false, rgba_frame)
    (rgba_frame, true)
  } else if chunk == b"ALPH" {
    if chunk_size_rounded + 32L > anmf_size {
      raise ImageError("Invalid Chunk header: \{fourcc_debug(chunk)}")
    }
    let next_chunk_start = self.pos + chunk_size_rounded
    let (filtering, alpha) = read_alpha_chunk(
      self.range(self.pos, self.pos + chunk_size),
      frame_width & 0xFFFF,
      frame_height & 0xFFFF,
    )
    self.pos = next_chunk_start
    let (next_chunk, next_chunk_size, _) = self.read_chunk_header()
    if chunk_size + next_chunk_size + 32L > anmf_size {
      raise ImageError("Invalid Chunk header: \{fourcc_debug(next_chunk)}")
    }
    let frame = vp8_decode_frame(
      self.range(self.pos, self.pos + next_chunk_size),
    )
    let rgba_frame = FixedArray::make(n * 4, b'\x00')
    frame.fill_rgb(rgba_frame, 4)
    apply_alpha(rgba_frame, frame.width, frame.height, filtering, alpha)
    (rgba_frame, true)
  } else {
    raise ImageError("Invalid Chunk header: \{fourcc_debug(chunk)}")
  }
  let canvas = FixedArray::make(self.width * self.height * 4, b'\x00')
  if info.background_color is Some(color) {
    for p = 0; p + 4 <= canvas.length(); p = p + 4 {
      for k in 0..<4 {
        canvas[p + k] = color[k]
      }
    }
  }
  composite_frame(
    canvas,
    self.width,
    self.height,
    clear_color,
    frame,
    frame_x,
    frame_y,
    frame_width,
    frame_height,
    frame_has_alpha,
    use_alpha_blending,
    0,
    0,
    0,
    0,
  )
  if self.has_alpha {
    for i in 0..<buf.length() {
      buf[i] = canvas[i]
    }
  } else {
    let pixels = imin3(
      buf.length() / 3,
      canvas.length() / 4,
      canvas.length() / 4,
    )
    for p in 0..<pixels {
      buf[p * 3] = canvas[p * 4]
      buf[p * 3 + 1] = canvas[p * 4 + 1]
      buf[p * 3 + 2] = canvas[p * 4 + 2]
    }
  }
}

///|
/// `read_image` into `buf` (`output_buffer_size` bytes).
fn WebpParser::read_image(
  self : WebpParser,
  buf : FixedArray[Byte],
) -> Unit raise ImageError {
  if self.extended is Some(info) && info.animation {
    self.read_first_frame(buf)
  } else if self.chunk(b"VP8L") is Some(range) {
    let decoder = LosslessDecoder::new(self.range(range.start, range.end))
    if self.has_alpha {
      decoder.decode_frame(self.width, self.height, false, buf)
    } else {
      let data = FixedArray::make(self.width * self.height * 4, b'\x00')
      decoder.decode_frame(self.width, self.height, false, data)
      for p in 0..<(self.width * self.height) {
        buf[p * 3] = data[p * 4]
        buf[p * 3 + 1] = data[p * 4 + 1]
        buf[p * 3 + 2] = data[p * 4 + 2]
      }
    }
  } else {
    guard self.chunk(b"VP8 ") is Some(range) else {
      raise ImageError("An expected chunk was missing")
    }
    let frame = vp8_decode_frame(self.range(range.start, range.end))
    if frame.width != self.width || frame.height != self.height {
      raise ImageError("Inconsistent image sizes")
    }
    if self.has_alpha {
      frame.fill_rgb(buf, 4)
      guard self.chunk(b"ALPH") is Some(range) else {
        raise ImageError("An expected chunk was missing")
      }
      let (filtering, alpha) = read_alpha_chunk(
        self.range(range.start, range.end),
        self.width & 0xFFFF,
        self.height & 0xFFFF,
      )
      apply_alpha(buf, frame.width, frame.height, filtering, alpha)
    } else {
      frame.fill_rgb(buf, 3)
    }
  }
}

///|
fn WebpParser::new(data : BytesView) -> WebpParser {
  {
    data,
    pos: 0L,
    chunks: [],
    width: 0,
    height: 0,
    extended: None,
    is_lossy: false,
    has_alpha: false,
    num_frames: 0,
  }
}

///|
/// Decodes a WebP image like `WebPDecoder::new` followed by `read_image`
/// (the first frame of an animation, composited on a transparent canvas).
pub fn decode_webp(data : BytesView) -> WebpImage raise ImageError {
  let parser = WebpParser::new(data)
  try {
    parser.read_data()
    let bpp = if parser.has_alpha { 4 } else { 3 }
    let buf = FixedArray::make(parser.width * parser.height * bpp, b'\x00')
    parser.read_image(buf)
    {
      width: parser.width,
      height: parser.height,
      has_alpha: parser.has_alpha,
      data: Bytes::from_fixedarray(buf),
    }
  } catch {
    ImageError(msg) => decoding_error("WebP", msg)
  }
}

///|
/// Decodes a WebP image like upstream `image::DynamicImage::from_decoder`
/// with an `image::codecs::webp::WebPDecoder`: RGBA pixels if the image has
/// alpha, RGB pixels otherwise, plus the ICC profile (`icc_profile`, whose
/// errors upstream `RasterImage::new` ignores). I/O errors are reported as
/// is and other errors as WebP decoding errors
/// (`ImageError::from_webp_decode`).
pub fn decode_webp_image(
  data : BytesView,
) -> (ImageInfo, Bytes) raise ImageError {
  let parser = WebpParser::new(data)
  try {
    parser.read_data()
    // `read_chunk(ICCP, ..)`: `read_exact` of the chunk's range.
    let icc = match parser.chunk(b"ICCP") {
      Some(range) if range.end <= data.length().to_int64() =>
        Some(data[range.start.to_int():range.end.to_int()].to_owned())
      _ => None
    }
    let bpp = if parser.has_alpha { 4 } else { 3 }
    let buf = FixedArray::make(parser.width * parser.height * bpp, b'\x00')
    parser.read_image(buf)
    let info = {
      width: parser.width.reinterpret_as_uint(),
      height: parser.height.reinterpret_as_uint(),
      color: if parser.has_alpha {
        Rgba8
      } else {
        Rgb8
      },
      icc,
    }
    (info, Bytes::from_fixedarray(buf))
  } catch {
    ImageError(msg) =>
      if msg == webp_eof {
        raise ImageError("failed to fill whole buffer")
      } else {
        decoding_error("WebP", msg)
      }
  }
}
