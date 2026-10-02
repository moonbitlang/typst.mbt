// Port of the JPEG decoding of the `image` crate (v0.25.10,
// `src/codecs/jpeg/decoder.rs`), which drives `zune-jpeg` (v0.5.15, ported
// in the `jpeg_*.mbt` files) with non-strict decoder options and no
// dimension limits, and requests RGB output for every color space other
// than RGB and luma (e.g. YCbCr, CMYK and YCCK are converted to RGB by the
// decoder).

///|
/// Upstream `ImageError::from_jpeg` rendered with its `Display` output.
/// (`Unsupported` and `LargeDimensions` are never produced by the decoder.)
fn from_jpeg(err : DecodeErrors) -> ImageError {
  ImageError("Format error decoding Jpeg: \{err.display()}")
}

///|
/// Upstream `to_supported_color_space`: the rest is not supported by `image`
/// so it will be converted to RGB during decoding.
fn to_supported_color_space(orig : ColorSpace) -> ColorSpace {
  match orig {
    RGB | Luma => orig
    _ => RGB
  }
}

///|
/// Upstream `ColorType::from_jpeg`.
fn color_type_from_jpeg(colorspace : ColorSpace) -> ColorType {
  match to_supported_color_space(colorspace) {
    Luma => L8
    _ => Rgb8
  }
}

///|
/// Decode the headers like upstream `JpegDecoder::new`.
fn jpeg_decode_headers(
  data : BytesView,
) -> (JpegDecoder, ImageInfo) raise ImageError {
  let decoder = JpegDecoder::new(data, RGB)
  decoder.decode_headers() catch {
    e => raise from_jpeg(e)
  }
  let info = {
    width: decoder.width.reinterpret_as_uint(),
    height: decoder.height.reinterpret_as_uint(),
    color: color_type_from_jpeg(decoder.input_colorspace),
    icc: decoder.icc_profile(),
  }
  (decoder, info)
}

///|
/// Header information as reported by upstream `image::codecs::jpeg::
/// JpegDecoder`.
pub fn jpeg_image_info(data : BytesView) -> ImageInfo raise ImageError {
  jpeg_decode_headers(data).1
}

///|
/// Decode a JPEG image like upstream `DynamicImage::from_decoder(
/// JpegDecoder::new(..)?)`: returns the header information and the 8-bit
/// samples (row-major, `info.color.channel_count()` channels per pixel).
pub fn decode_jpeg(data : BytesView) -> (ImageInfo, Bytes) raise ImageError {
  let (header, info) = jpeg_decode_headers(data)
  // `read_image` decodes with a fresh decoder whose output colorspace is the
  // supported one.
  let decoder = JpegDecoder::new(
    data,
    to_supported_color_space(header.input_colorspace),
  )
  let len = info.width.reinterpret_as_int() *
    info.height.reinterpret_as_int() *
    info.color.channel_count()
  let buf : FixedArray[Byte] = FixedArray::make(len, b'\x00')
  decoder.decode_into(buf) catch {
    e => raise from_jpeg(e)
  }
  (info, Bytes::from_array(buf))
}
