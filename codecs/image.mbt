// Shared types of the image codecs: a port of the parts of the `image` crate
// (v0.25.10) that Typst's raster image handling observes without decoding
// pixels: `ColorType`, the decoder error messages and the header metadata
// (`ImageDecoder::dimensions`, `color_type`, `icc_profile`).

///|
/// An image decoding error. The payload is the `Display` output of upstream
/// `image::ImageError`, e.g. `Format error decoding Png: Invalid PNG
/// signature.`.
pub(all) suberror ImageError {
  ImageError(String)
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImageError with @debug.Debug::{to_repr}

///|
/// Raise a decoding error for the given format (upstream
/// `ImageError::Decoding(DecodingError::new(format.into(), err))`).
fn[T] decoding_error(format : String, message : String) -> T raise ImageError {
  raise ImageError("Format error decoding \{format}: \{message}")
}

///|
/// The color type of a decoded image (upstream `image::ColorType`).
pub(all) enum ColorType {
  L8
  La8
  Rgb8
  Rgba8
  L16
  La16
  Rgb16
  Rgba16
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorType with @debug.Debug::{to_repr}

///|
/// The number of channels of the color type.
pub fn ColorType::channel_count(self : ColorType) -> Int {
  match self {
    L8 | L16 => 1
    La8 | La16 => 2
    Rgb8 | Rgb16 => 3
    Rgba8 | Rgba16 => 4
  }
}

///|
/// The header information of an image that is obtained without decoding the
/// pixel data.
pub(all) struct ImageInfo {
  /// The pixel width (upstream `ImageDecoder::dimensions().0`).
  width : UInt
  /// The pixel height.
  height : UInt
  /// The color type of the decoded image.
  color : ColorType
  /// The embedded ICC profile, if any (upstream `ImageDecoder::icc_profile`).
  icc : Bytes?
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImageInfo with @debug.Debug::{to_repr}

///|
/// A big-endian 16-bit load.
fn u16_be(data : BytesView, i : Int) -> Int {
  (data[i].to_int() << 8) | data[i + 1].to_int()
}

///|
/// A big-endian 32-bit load.
fn u32_be(data : BytesView, i : Int) -> UInt {
  (data[i].to_uint() << 24) |
  (data[i + 1].to_uint() << 16) |
  (data[i + 2].to_uint() << 8) |
  data[i + 3].to_uint()
}

///|
/// A little-endian 16-bit load.
fn u16_le(data : BytesView, i : Int) -> Int {
  data[i].to_int() | (data[i + 1].to_int() << 8)
}

///|
/// A little-endian 24-bit load.
fn u24_le(data : BytesView, i : Int) -> UInt {
  data[i].to_uint() |
  (data[i + 1].to_uint() << 8) |
  (data[i + 2].to_uint() << 16)
}

///|
/// A little-endian 32-bit load.
fn u32_le(data : BytesView, i : Int) -> UInt {
  data[i].to_uint() |
  (data[i + 1].to_uint() << 8) |
  (data[i + 2].to_uint() << 16) |
  (data[i + 3].to_uint() << 24)
}

///|
/// Whether `data` starts with `prefix`.
fn starts_with(data : BytesView, prefix : BytesView) -> Bool {
  if data.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if data[i] != prefix[i] {
      return false
    }
  }
  true
}
