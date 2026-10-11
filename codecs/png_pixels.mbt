// Port of the `png` crate (v0.18.1) `src/decoder/transform.rs` and
// `src/decoder/transform/palette.rs` for `Transformations::EXPAND` (the
// expansion of palettes, sub-byte samples and `tRNS` transparency) with or
// without `STRIP_16` (the more significant byte of a 16-bit sample), and of
// what upstream `image::codecs::png::PngDecoder` and
// `DynamicImage::from_decoder` add to the `png` crate's `Reader`
// (`png_reader.mbt`): 16-bit samples are returned in native (little-endian)
// byte order like `PngDecoder::read_image`. Only the default image is
// decoded (APNG frames are not).

///|
/// The functions of upstream's `transform.rs` for `Transformations::EXPAND`
/// with or without `STRIP_16`.
priv enum PngTransformKind {
  /// `palette::create_expansion_into_rgba8`
  ExpandPalettedIntoRgba8
  /// `palette::create_expansion_into_rgb8` for a bit depth of eight
  Expand8bitIntoRgb8
  /// `palette::create_expansion_into_rgb8` for the other bit depths
  ExpandIntoRgb8
  ExpandGrayU8WithTrns
  ExpandGrayU8
  ExpandTrnsLine
  ExpandTrnsLine16
  ExpandTrnsAndStripLine16
  TransformRowStrip16
  CopyRow
}

///|
/// A function that can transform a decompressed, unfiltered row into the
/// final pixels (upstream `TransformFn`).
priv struct PngTransform {
  kind : PngTransformKind
  /// The RGBA palette, four bytes per entry (upstream `create_rgba_palette`).
  rgba_palette : FixedArray[Byte]
}

///|
/// Returns a transformation function that should be applied to image rows
/// based on decoded image metadata (`info`), for the transformation
/// `Transformations::EXPAND`, with `STRIP_16` if `strip16` (upstream
/// `create_transform_fn`).
fn PngTransform::new(
  info : StreamInfo,
  strip16 : Bool,
) -> PngTransform raise DecodingError {
  let trns = info.trns is Some(_)
  let strip16 = info.bit_depth == 16 && strip16
  let kind = match info.color_type {
    Indexed => {
      guard info.palette is Some(palette) else {
        raise Format("Missing palette of indexed image.")
      }
      // (A bit depth of sixteen was caught earlier.)
      return {
        kind: if trns {
          ExpandPalettedIntoRgba8
        } else if info.bit_depth == 8 {
          Expand8bitIntoRgb8
        } else {
          ExpandIntoRgb8
        },
        rgba_palette: create_rgba_palette(palette, info.trns),
      }
    }
    Grayscale | GrayscaleAlpha if info.bit_depth < 8 =>
      if trns {
        ExpandGrayU8WithTrns
      } else {
        ExpandGrayU8
      }
    Grayscale | Rgb if trns =>
      if info.bit_depth == 8 {
        ExpandTrnsLine
      } else if strip16 {
        ExpandTrnsAndStripLine16
      } else {
        ExpandTrnsLine16
      }
    _ => if strip16 { TransformRowStrip16 } else { CopyRow }
  }
  { kind, rgba_palette: [], }
}

///|
/// Upstream `create_rgba_palette`.
///
/// Upstream panics here (an index out of range) if the length of the
/// palette is not a multiple of three, which the decoder accepts for a
/// `PLTE` chunk (any length from 3 to 768). That is an error here, the one
/// that a `PLTE` chunk of any other wrong length is.
fn create_rgba_palette(
  palette : Bytes,
  trns : Bytes?,
) -> FixedArray[Byte] raise DecodingError {
  if palette.length() % 3 != 0 {
    raise Format("Chunk length wrong: \{chunk_type_debug(PNG_PLTE)}")
  }
  let trns = match trns {
    Some(trns) if trns.length() <= palette.length() / 3 => trns
    _ => b""
  }
  let rgba_palette = FixedArray::make(4 * 256, b'\x00')
  for i in 0..<256 {
    rgba_palette[4 * i + 3] = b'\xFF'
  }
  for i in 0..<(palette.length() / 3) {
    rgba_palette[4 * i] = palette[3 * i]
    rgba_palette[4 * i + 1] = palette[3 * i + 1]
    rgba_palette[4 * i + 2] = palette[3 * i + 2]
  }
  for i in 0..<trns.length() {
    rgba_palette[4 * i + 3] = trns[i]
  }
  rgba_palette
}

///|
/// Transforms the row `row[row_start..row_start + row_len]` into
/// `output[start..start + len]`.
fn PngTransform::apply(
  self : PngTransform,
  row : FixedArray[Byte],
  row_start : Int,
  row_len : Int,
  output : FixedArray[Byte],
  start : Int,
  len : Int,
  info : StreamInfo,
) -> Unit {
  // The accesses below are within these ranges.
  guard! row_start >= 0 &&
    row_len >= 0 &&
    row_start <= row.length() - row_len &&
    start >= 0 &&
    len >= 0 &&
    start <= output.length() - len
  let bit_depth = info.bit_depth
  match self.kind {
    CopyRow => {
      // `output_buffer.copy_from_slice(row)`
      guard! row_len == len
      output.unsafe_blit(start, row, row_start, len)
    }
    TransformRowStrip16 => {
      let samples = @cmp.minimum(row_len / 2, len)
      for i in 0..<samples {
        output.unsafe_set(start + i, row.unsafe_get(row_start + 2 * i))
      }
    }
    ExpandTrnsAndStripLine16 => {
      // A pixel is transparent if its samples of 16 bits are the `tRNS`
      // chunk.
      let channels = info.color_type.samples()
      let size = 2 * channels
      let trns = info.trns.unwrap_or(b"")
      let pixels = @cmp.minimum(row_len / size, len / (channels + 1))
      for x in 0..<pixels {
        let src = row_start + x * size
        let dst = start + x * (channels + 1)
        let mut transparent = trns.length() == size
        for k in 0..<size {
          if transparent && row.unsafe_get(src + k) != trns[k] {
            transparent = false
          }
        }
        for i in 0..<channels {
          output.unsafe_set(dst + i, row.unsafe_get(src + 2 * i))
        }
        output.unsafe_set(dst + channels, if transparent { 0x00 } else { 0xFF })
      }
    }
    ExpandTrnsLine | ExpandTrnsLine16 => {
      // Upstream `expand_trns_line` and `expand_trns_line16`: a pixel is
      // transparent if its samples are the `tRNS` chunk.
      let alpha_size = if self.kind is ExpandTrnsLine16 { 2 } else { 1 }
      let size = info.color_type.samples() * alpha_size
      let trns = info.trns.unwrap_or(b"")
      let pixels = @cmp.minimum(row_len / size, len / (size + alpha_size))
      for x in 0..<pixels {
        let src = row_start + x * size
        let dst = start + x * (size + alpha_size)
        let mut transparent = trns.length() == size
        for k in 0..<size {
          let v = row.unsafe_get(src + k)
          output.unsafe_set(dst + k, v)
          if transparent && v != trns[k] {
            transparent = false
          }
        }
        let alpha : Byte = if transparent { 0x00 } else { 0xFF }
        for k in 0..<alpha_size {
          output.unsafe_set(dst + size + k, alpha)
        }
      }
    }
    ExpandGrayU8 => {
      let scaling_factor = 255 / ((1 << bit_depth) - 1)
      let pixels = unpack_bits_pixels(row_len, len, 1, bit_depth)
      for x in 0..<pixels {
        let val = unpack_bits_sample(row, row_start, x, bit_depth)
        output.unsafe_set(start + x, (val * scaling_factor).to_byte())
      }
    }
    ExpandGrayU8WithTrns => {
      let scaling_factor = 255 / ((1 << bit_depth) - 1)
      // (`tRNS` of a grayscale image of less than sixteen bits is one byte.)
      let trns = match info.trns {
        Some(trns) => trns[0].to_int()
        None => -1
      }
      let pixels = unpack_bits_pixels(row_len, len, 2, bit_depth)
      for x in 0..<pixels {
        let pixel = unpack_bits_sample(row, row_start, x, bit_depth)
        output.unsafe_set(
          start + 2 * x + 1,
          if pixel == trns {
            0x00
          } else {
            0xFF
          },
        )
        output.unsafe_set(start + 2 * x, (pixel * scaling_factor).to_byte())
      }
    }
    ExpandPalettedIntoRgba8 => {
      let palette = self.rgba_palette
      guard! palette.length() == 1024
      let pixels = unpack_bits_pixels(row_len, len, 4, bit_depth)
      for x in 0..<pixels {
        let i = 4 * unpack_bits_sample(row, row_start, x, bit_depth)
        let dst = start + 4 * x
        output.unsafe_set(dst, palette.unsafe_get(i))
        output.unsafe_set(dst + 1, palette.unsafe_get(i + 1))
        output.unsafe_set(dst + 2, palette.unsafe_get(i + 2))
        output.unsafe_set(dst + 3, palette.unsafe_get(i + 3))
      }
    }
    Expand8bitIntoRgb8 | ExpandIntoRgb8 => {
      // (`expand_8bit_into_rgb8` writes four bytes of an entry and the
      // next pixel over the fourth; the result is the same.)
      let palette = self.rgba_palette
      guard! palette.length() == 1024
      let pixels = unpack_bits_pixels(row_len, len, 3, bit_depth)
      for x in 0..<pixels {
        let i = 4 * unpack_bits_sample(row, row_start, x, bit_depth)
        let dst = start + 3 * x
        output.unsafe_set(dst, palette.unsafe_get(i))
        output.unsafe_set(dst + 1, palette.unsafe_get(i + 1))
        output.unsafe_set(dst + 2, palette.unsafe_get(i + 2))
      }
    }
  }
}

///|
/// How many pixels upstream `unpack_bits` writes: the chunks of `channels`
/// bytes of the output (for which the input has samples, which upstream
/// asserts).
fn unpack_bits_pixels(
  input_len : Int,
  output_len : Int,
  channels : Int,
  bit_depth : Int,
) -> Int {
  let per_byte = 8 / bit_depth
  let pixels = output_len / channels
  // (Not `input_len * per_byte`, which does not fit an `Int` for a row of
  // 2^28 bytes.)
  if input_len >=
    pixels / per_byte + (if pixels % per_byte > 0 { 1 } else { 0 }) {
    pixels
  } else {
    input_len * per_byte
  }
}

///|
/// The sample `i` of a row of samples of `bit_depth` bits (1, 2, 4 or 8)
/// that starts at `input[start]`: upstream `unpack_bits` shifts through
/// `[7, 6, 5, 4, 3, 2, 1, 0]`, `[6, 4, 2, 0]`, `[4, 0]` or `[0]`. The byte is
/// in bounds for the pixels of `unpack_bits_pixels`.
fn unpack_bits_sample(
  input : FixedArray[Byte],
  start : Int,
  i : Int,
  bit_depth : Int,
) -> Int {
  if bit_depth == 8 {
    return input.unsafe_get(start + i).to_int()
  }
  let per_byte = 8 / bit_depth
  let curr = input.unsafe_get(start + i / per_byte).to_int()
  let shift = 8 - bit_depth * (i % per_byte + 1)
  (curr >> shift) & ((1 << bit_depth) - 1)
}

///|
/// The limit on the bytes that the decoder allocates besides the frame
/// (upstream `png::Limits::bytes`): chunk data, text chunks, the ICC
/// profile and the buffer of an output row.
pub(all) enum PngLimits {
  /// No limit (`usize::MAX`): `image::codecs::png::PngDecoder::new`, which
  /// passes `image::Limits::no_limits()`.
  Unlimited
  /// `png::Limits::default()`, 64 MiB: `png::Decoder::new`, as krilla and
  /// tiny-skia call it.
  Default
}

///|
fn PngLimits::limits(self : PngLimits) -> Limits {
  match self {
    Unlimited => { bytes: 0xFFFFFFFFFFFFFFFFUL, }
    Default => { bytes: 1024UL * 1024UL * 64UL, }
  }
}

///|
/// Upstream `ImageError::from_png` followed by `impl Display for
/// ImageError`.
fn image_error_from_png(err : DecodingError) -> ImageError {
  match err {
    // `ImageError::IoError(err)`
    IoError(_) => ImageError(err.to_string())
    // The input image was not a valid PNG.
    Format(_) => ImageError("Format error decoding Png: \{err.to_string()}")
    // Other is used when:
    // - The decoder is polled for more animation frames despite being done (or not being animated
    //   in the first place).
    // - The output buffer does not have the required size.
    Parameter(_) => ImageError("The parameter is malformed: \{err.to_string()}")
    // `ImageError::Limits(LimitError::from_kind(LimitErrorKind::
    // InsufficientMemory))`
    LimitsExceeded => ImageError(limit_error_insufficient_memory)
  }
}

///|
/// The `Display` output of upstream's `LimitErrorKind::InsufficientMemory`.
let limit_error_insufficient_memory : String = "Memory limit exceeded"

///|
/// Whether `message`, the payload of an [ImageError], is the `Display`
/// output of an upstream `image::ImageError::Limits(_)` (of its kinds
/// `InsufficientMemory` and `DimensionError`; no other variant of
/// `ImageError` prints these). Upstream's callers match on the variant:
/// Typst reports "file is too large" for it.
pub fn is_limit_error(message : String) -> Bool {
  message == limit_error_insufficient_memory ||
  message == "Image size exceeds limit"
}

///|
/// Decodes the pixels of a PNG image (upstream `PngDecoder::new` followed by
/// `DynamicImage::from_decoder`). Returns the header information and the
/// samples in row-major order.
///
/// What a damaged file gives is what upstream gives: the same error or the
/// same pixels (see `png_stream.mbt`). No input makes this allocate for
/// more rows than the file has data for.
pub fn decode_png(data : BytesView) -> (ImageInfo, Bytes) raise ImageError {
  // `PngDecoder::new` passes `Limits::no_limits()`.
  let reader = PngReader::read_info(data, PngLimits::Unlimited.limits(), false) catch {
    err => raise image_error_from_png(err)
  }
  // `decoder_to_vec`: `total_bytes()` (the dimensions times the bytes of a
  // pixel) is more than `isize::MAX`.
  if reader.output_buffer_size() is None {
    raise image_error_from_png(LimitsExceeded)
  }
  // `PngDecoder::read_image`
  read_png_frame(reader, data.length()) catch {
    err => raise image_error_from_png(err)
  }
}

///|
/// What decoding a PNG with the `png` crate itself fails with
/// ([decode_png_frame]).
pub(all) suberror PngFrameError {
  /// A `png::DecodingError` of `read_info` or `next_frame`: its `Display`
  /// output.
  Decoding(String)
  /// `Reader::output_buffer_size()` is `None`: the frame has more than
  /// `isize::MAX` bytes. (krilla reports "image is too large", tiny-skia
  /// `DecodingError::LimitsExceeded`.)
  OutputBufferSize
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PngFrameError with @debug.Debug::{to_repr}

///|
/// Decodes the pixels of a PNG image with the `png` crate as krilla and
/// tiny-skia call it: `png::Decoder::new` (the default limits),
/// `set_transformations(Transformations::EXPAND)` (with `strip16`:
/// `normalize_to_color8()`, the more significant byte of a 16-bit sample),
/// `read_info`, a buffer of `output_buffer_size()` bytes and `next_frame`.
/// Returns what [decode_png] returns (16-bit samples in little-endian
/// order; the `png` crate's are big-endian).
pub fn decode_png_frame(
  data : BytesView,
  strip16~ : Bool = false,
) -> (ImageInfo, Bytes) raise PngFrameError {
  let reader = PngReader::read_info(data, PngLimits::Default.limits(), strip16) catch {
    err => raise Decoding(err.to_string())
  }
  if reader.output_buffer_size() is None {
    raise OutputBufferSize
  }
  read_png_frame(reader, data.length()) catch {
    err => raise Decoding(err.to_string())
  }
}

///|
/// Reads the frame of a reader whose frame has a size.
fn read_png_frame(
  reader : PngReader,
  input_len : Int,
) -> (ImageInfo, Bytes) raise DecodingError {
  let info = reader.info()
  let (color_type, bits) = reader.output_color_type()
  let sixteen = bits == 16
  let color : ColorType = match color_type {
    Grayscale => if sixteen { L16 } else { L8 }
    GrayscaleAlpha => if sixteen { La16 } else { La8 }
    Rgb => if sixteen { Rgb16 } else { Rgb8 }
    Rgba => if sixteen { Rgba16 } else { Rgba8 }
    // (Expanded to RGB or RGBA.)
    Indexed => abort("unreachable")
  }
  // `ImageDecoder::icc_profile`
  let icc = info.icc_profile
  let buf = reader.next_frame(input_len)
  // PNG images are big endian. For 16 bit per channel and larger types,
  // the buffer may need to be reordered to native endianness per the
  // contract of `read_image`.
  if sixteen {
    for i = 0; i + 1 < buf.length(); i = i + 2 {
      let hi = buf.unsafe_get(i)
      buf.unsafe_set(i, buf.unsafe_get(i + 1))
      buf.unsafe_set(i + 1, hi)
    }
  }
  let image_info = { width: info.width, height: info.height, color, icc, }
  (image_info, Bytes::from_array(buf[:]))
}
