// Port of the pixel decoding of the `png` crate (v0.18.1) with
// `Transformations::EXPAND` as used by upstream `image::codecs::png::
// PngDecoder` (`src/decoder/stream.rs`, `src/decoder/unfiltering_buffer.rs`,
// `src/decoder/transform.rs`, `src/decoder/transform/palette.rs`,
// `src/adam7.rs`): IDAT decompression, unfiltering, Adam7 deinterlacing and
// the expansion of palettes, sub-byte samples and `tRNS` transparency.
// 16-bit samples are returned in native (little-endian) byte order like
// `PngDecoder::read_image`. Only the default image is decoded (APNG frames
// are not).

///|
/// The chunks needed to decode the pixels.
priv struct PngData {
  palette : Bytes?
  /// The `tRNS` chunk, normalized like upstream `parse_trns`.
  trns : Bytes?
  idat : Bytes
}

///|
fn read_png_data(data : BytesView, info : PngInfo) -> PngData raise ImageError {
  let mut pos = 8
  let mut palette = None
  let mut trns = None
  let idat = Buffer()
  let mut seen_idat = false
  while pos + 8 <= data.length() {
    let len = u32_be(data, pos).reinterpret_as_int()
    let ty = data[pos + 4:pos + 8]
    let start = pos + 8
    if len < 0 || start + len + 4 > data.length() {
      decoding_error("Png", "Unexpected end of data within a chunk.")
    }
    let chunk = data[start:start + len]
    if ty == b"IDAT" {
      idat.write_bytesview(chunk)
      seen_idat = true
    } else if seen_idat {
      // The image data ends with the first non-IDAT chunk.
      break
    } else if ty == b"PLTE" {
      palette = Some(chunk.to_owned())
    } else if ty == b"tRNS" && trns is None {
      let sixteen = info.bit_depth == 16
      trns = match info.color_type {
        Grayscale => {
          if len < 2 {
            decoding_error(
              "Png",
              "Not enough palette entries, expect 2 got \{len}.",
            )
          }
          Some(if sixteen { chunk.to_owned() } else { chunk[1:2].to_owned() })
        }
        Rgb => {
          if len < 6 {
            decoding_error(
              "Png",
              "Not enough palette entries, expect 6 got \{len}.",
            )
          }
          Some(
            if sixteen {
              chunk.to_owned()
            } else {
              Bytes::from_array([chunk[1], chunk[3], chunk[5]])
            },
          )
        }
        Indexed => Some(chunk.to_owned())
        _ =>
          decoding_error(
            "Png",
            "Transparency chunk found for color type \{info.color_type.code()}.",
          )
      }
    }
    pos = start + len + 4
  }
  if !seen_idat {
    decoding_error("Png", "Unexpected end of data before image end.")
  }
  { palette, trns, idat: idat.to_bytes(), }
}

///|
/// Reverses a row filter in place (upstream `unfilter`).
fn unfilter_row(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
) -> Unit raise ImageError {
  let len = current.length()
  match filter {
    0 => ()
    1 =>
      for i in bpp..<len {
        current[i] = current[i] + current[i - bpp]
      }
    2 =>
      for i in 0..<len {
        current[i] = current[i] + previous[i]
      }
    3 =>
      for i in 0..<len {
        let a = if i >= bpp { current[i - bpp].to_int() } else { 0 }
        current[i] = current[i] + ((a + previous[i].to_int()) / 2).to_byte()
      }
    4 =>
      for i in 0..<len {
        let a = if i >= bpp { current[i - bpp].to_int() } else { 0 }
        let c = if i >= bpp { previous[i - bpp].to_int() } else { 0 }
        current[i] = current[i] +
          filter_paeth(a, previous[i].to_int(), c).to_byte()
      }
    _ => decoding_error("Png", "Unknown filter method (\{filter}).")
  }
}

///|
/// The Adam7 passes: (x start, y start, x step, y step).
let adam7_passes : ReadOnlyArray[(Int, Int, Int, Int)] = [
  (0, 0, 8, 8),
  (4, 0, 8, 8),
  (0, 4, 4, 8),
  (2, 0, 4, 4),
  (0, 2, 2, 4),
  (1, 0, 2, 2),
  (0, 1, 1, 2),
]

///|
/// Decodes the pixels of a PNG image (upstream `PngDecoder::new` followed by
/// `DynamicImage::from_decoder`). Returns the header information and the
/// samples in row-major order.
pub fn decode_png(data : BytesView) -> (ImageInfo, Bytes) raise ImageError {
  let info = read_png_info(data)
  let chunks = read_png_data(data, info)
  if info.color_type is Indexed && chunks.palette is None {
    decoding_error("Png", "Palette required, but not found.")
  }
  let raw = zlib_decompress(chunks.idat[:], verify_checksum=false) catch {
    InflateError(err) => decoding_error("Png", "Corrupt deflate stream. \{err}")
  }
  let width = info.width.reinterpret_as_int()
  let height = info.height.reinterpret_as_int()
  let depth = info.bit_depth
  let samples = info.color_type.samples()
  let bits_per_pixel = samples * depth
  let bpp = @cmp.maximum(1, bits_per_pixel / 8)
  let color = info.output_color_type()
  let out_bpp = color.channel_count() * (if depth == 16 { 2 } else { 1 })
  let out = FixedArray::make(width * height * out_bpp, b'\x00')
  let expand = PngExpander::new(info, chunks)
  let mut pos = 0
  let passes = if info.interlaced { adam7_passes } else { [(0, 0, 1, 1)] }
  for pass in passes {
    let (x0, y0, dx, dy) = pass
    let pass_width = if width > x0 { (width - x0 + dx - 1) / dx } else { 0 }
    let pass_height = if height > y0 { (height - y0 + dy - 1) / dy } else { 0 }
    if pass_width == 0 || pass_height == 0 {
      continue
    }
    let row_len = (pass_width * bits_per_pixel + 7) / 8
    let mut previous = FixedArray::make(row_len, b'\x00')
    let expanded = FixedArray::make(pass_width * out_bpp, b'\x00')
    for py in 0..<pass_height {
      if pos + 1 + row_len > raw.length() {
        decoding_error("Png", "Unexpected end of data before image end.")
      }
      let filter = raw[pos].to_int()
      let current = FixedArray::makei(row_len, i => raw[pos + 1 + i])
      pos += 1 + row_len
      unfilter_row(filter, bpp, previous, current)
      expand.row(current, pass_width, expanded)
      let y = y0 + py * dy
      for px in 0..<pass_width {
        let x = x0 + px * dx
        let dst = (y * width + x) * out_bpp
        for k in 0..<out_bpp {
          out[dst + k] = expanded[px * out_bpp + k]
        }
      }
      previous = current
    }
  }

  // PNG images are big endian; the samples are returned in native (little)
  // endian order.
  if depth == 16 {
    for i = 0; i + 1 < out.length(); i = i + 2 {
      let hi = out[i]
      out[i] = out[i + 1]
      out[i + 1] = hi
    }
  }
  let image_info = {
    width: info.width,
    height: info.height,
    color,
    icc: info.icc_profile,
  }
  (image_info, Bytes::makei(out.length(), i => out[i]))
}

///|
/// Expands the samples of a row (upstream `create_transform_fn` with
/// `Transformations::EXPAND`).
priv struct PngExpander {
  info : PngInfo
  trns : Bytes?
  /// The RGBA palette (upstream `create_rgba_palette`).
  rgba_palette : FixedArray[(Byte, Byte, Byte, Byte)]
}

///|
fn PngExpander::new(info : PngInfo, chunks : PngData) -> PngExpander {
  let rgba_palette = FixedArray::make(256, (b'\x00', b'\x00', b'\x00', b'\xFF'))
  if chunks.palette is Some(palette) {
    let entries = palette.length() / 3
    let trns = match chunks.trns {
      Some(trns) if trns.length() <= entries => trns
      _ => b""
    }
    for i in 0..<@cmp.minimum(entries, 256) {
      let alpha = if i < trns.length() { trns[i] } else { b'\xFF' }
      rgba_palette[i] = (
        palette[3 * i],
        palette[3 * i + 1],
        palette[3 * i + 2],
        alpha,
      )
    }
  }
  { info, trns: chunks.trns, rgba_palette, }
}

///|
/// Unpacks the `i`-th sample of a row with sub-byte (or 8-bit) samples
/// (upstream `unpack_bits`).
fn unpack_sample(row : FixedArray[Byte], i : Int, depth : Int) -> Int {
  if depth == 8 {
    return row[i].to_int()
  }
  let per_byte = 8 / depth
  let byte = row[i / per_byte].to_int()
  let shift = 8 - depth * (i % per_byte + 1)
  (byte >> shift) & ((1 << depth) - 1)
}

///|
fn PngExpander::row(
  self : PngExpander,
  row : FixedArray[Byte],
  width : Int,
  out : FixedArray[Byte],
) -> Unit {
  let info = self.info
  let depth = info.bit_depth
  match info.color_type {
    Indexed => {
      let alpha = self.trns is Some(_)
      let n = if alpha { 4 } else { 3 }
      for x in 0..<width {
        let (r, g, b, a) = self.rgba_palette[unpack_sample(row, x, depth)]
        out[n * x] = r
        out[n * x + 1] = g
        out[n * x + 2] = b
        if alpha {
          out[n * x + 3] = a
        }
      }
    }
    Grayscale if depth < 8 => {
      let scaling_factor = 255 / ((1 << depth) - 1)
      match self.trns {
        Some(trns) =>
          for x in 0..<width {
            let pixel = unpack_sample(row, x, depth)
            out[2 * x + 1] = if pixel == trns[0].to_int() {
              b'\x00'
            } else {
              b'\xFF'
            }
            out[2 * x] = (pixel * scaling_factor).to_byte()
          }
        None =>
          for x in 0..<width {
            out[x] = (unpack_sample(row, x, depth) * scaling_factor).to_byte()
          }
      }
    }
    Grayscale | Rgb if self.trns is Some(trns) => {
      // Upstream `expand_trns_line` / `expand_trns_line16`.
      let size = info.color_type.samples() * (if depth == 16 { 2 } else { 1 })
      let alpha_size = if depth == 16 { 2 } else { 1 }
      for x in 0..<width {
        let mut transparent = trns.length() == size
        for k in 0..<size {
          let v = row[x * size + k]
          out[x * (size + alpha_size) + k] = v
          if transparent && v != trns[k] {
            transparent = false
          }
        }
        for k in 0..<alpha_size {
          out[x * (size + alpha_size) + size + k] = if transparent {
            b'\x00'
          } else {
            b'\xFF'
          }
        }
      }
    }
    _ =>
      for i in 0..<out.length() {
        out[i] = row[i]
      }
  }
}
