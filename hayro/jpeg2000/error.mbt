// Port of `hayro-jpeg2000/src/error.rs` (hayro rev d8e24e2, hayro-jpeg2000
// 0.4.0): error types for JPEG 2000 decoding.

///|
/// Errors related to JP2 file format and box parsing.
pub(all) enum FormatError {
  /// Invalid JP2 signature.
  InvalidSignature
  /// Invalid JP2 file type.
  InvalidFileType
  /// Invalid or malformed JP2 box.
  InvalidBox
  /// Missing codestream data.
  MissingCodestream
  /// Unsupported JP2 image format.
  Unsupported
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FormatError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FormatError with @debug.Debug::{to_repr}

///|
/// Errors related to codestream markers.
pub(all) enum MarkerError {
  /// Invalid marker encountered.
  Invalid
  /// Unsupported marker encountered.
  Unsupported
  /// Expected a specific marker.
  Expected(String)
  /// Missing a required marker.
  Missing(String)
  /// Failed to read or parse a marker.
  ParseFailure(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MarkerError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MarkerError with @debug.Debug::{to_repr}

///|
/// Errors related to tile processing.
pub(all) enum TileError {
  /// Invalid image tile was encountered.
  Invalid
  /// Invalid tile index in tile-part header.
  InvalidIndex
  /// Invalid tile or image offsets.
  InvalidOffsets
  /// PPT marker present when PPM marker exists in main header.
  PpmPptConflict
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TileError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TileError with @debug.Debug::{to_repr}

///|
/// Errors related to image dimensions and validation.
pub(all) enum ValidationError {
  /// Invalid image dimensions.
  InvalidDimensions
  /// Image dimensions exceed supported limits.
  ImageTooLarge
  /// Image has too many channels.
  TooManyChannels
  /// Invalid component metadata.
  InvalidComponentMetadata
  /// Invalid progression order.
  InvalidProgressionOrder
  /// Invalid transformation type.
  InvalidTransformation
  /// Invalid quantization style.
  InvalidQuantizationStyle
  /// Missing exponents for precinct sizes.
  MissingPrecinctExponents
  /// Not enough exponents provided in header.
  InsufficientExponents
  /// Missing exponent step size.
  MissingStepSize
  /// Invalid quantization exponents.
  InvalidExponents
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValidationError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValidationError with @debug.Debug::{to_repr}

///|
/// Errors related to decoding operations.
pub(all) enum DecodingError {
  /// An error occurred while decoding a code-block.
  CodeBlockDecodeFailure
  /// Number of bitplanes in a code-block is too large.
  TooManyBitplanes
  /// A code-block contains too many coding passes.
  TooManyCodingPasses
  /// Invalid number of bitplanes in a code-block.
  InvalidBitplaneCount
  /// A precinct was invalid.
  InvalidPrecinct
  /// A progression iterator ver invalid.
  InvalidProgressionIterator
  /// Unexpected end of data.
  UnexpectedEof
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecodingError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecodingError with @debug.Debug::{to_repr}

///|
/// Errors related to color space and component handling.
pub(all) enum ColorError {
  /// Multi-component transform failed.
  Mct
  /// Failed to resolve palette indices.
  PaletteResolutionFailed
  /// Failed to convert from sYCC to RGB.
  SyccConversionFailed
  /// Failed to convert from LAB to RGB.
  LabConversionFailed
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorError with @debug.Debug::{to_repr}

///|
/// The main error type for JPEG 2000 decoding operations.
pub(all) suberror DecodeError {
  /// Errors related to JP2 file format and box parsing.
  Format(FormatError)
  /// Errors related to codestream markers.
  Marker(MarkerError)
  /// Errors related to tile processing.
  Tile(TileError)
  /// Errors related to image dimensions and validation.
  Validation(ValidationError)
  /// Errors related to decoding operations.
  Decoding(DecodingError)
  /// Errors related to color space and component handling.
  Color(ColorError)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecodeError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecodeError with @debug.Debug::{to_repr}

///|
pub impl Show for DecodeError with fn output(self, logger) {
  match self {
    Format(e) => e.output(logger)
    Marker(e) => e.output(logger)
    Tile(e) => e.output(logger)
    Validation(e) => e.output(logger)
    Decoding(e) => e.output(logger)
    Color(e) => e.output(logger)
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DecodeError with Show::{to_string, output}

///|
pub impl Show for FormatError with fn output(self, logger) {
  logger.write_string(
    match self {
      InvalidSignature => "invalid JP2 signature"
      InvalidFileType => "invalid JP2 file type"
      InvalidBox => "invalid JP2 box"
      MissingCodestream => "missing codestream data"
      Unsupported => "unsupported JP2 image"
    },
  )
}

///|
pub extend FormatError with Show::{to_string, output}

///|
pub impl Show for MarkerError with fn output(self, logger) {
  match self {
    Invalid => logger.write_string("invalid marker")
    Unsupported => logger.write_string("unsupported marker")
    Expected(marker) => logger.write_string("expected \{marker} marker")
    Missing(marker) => logger.write_string("missing \{marker} marker")
    ParseFailure(marker) =>
      logger.write_string("failed to parse \{marker} marker")
  }
}

///|
pub extend MarkerError with Show::{to_string, output}

///|
pub impl Show for TileError with fn output(self, logger) {
  logger.write_string(
    match self {
      Invalid => "image contains no tiles"
      InvalidIndex => "invalid tile index in tile-part header"
      InvalidOffsets => "invalid tile offsets"
      PpmPptConflict =>
        "PPT marker present when PPM marker exists in main header"
    },
  )
}

///|
pub extend TileError with Show::{to_string, output}

///|
pub impl Show for ValidationError with fn output(self, logger) {
  logger.write_string(
    match self {
      InvalidDimensions => "invalid image dimensions"
      ImageTooLarge => "image is too large"
      TooManyChannels => "image has too many channels"
      InvalidComponentMetadata => "invalid component metadata"
      InvalidProgressionOrder => "invalid progression order"
      InvalidTransformation => "invalid transformation type"
      InvalidQuantizationStyle => "invalid quantization style"
      MissingPrecinctExponents => "missing exponents for precinct sizes"
      InsufficientExponents => "not enough exponents provided in header"
      MissingStepSize => "missing exponent step size"
      InvalidExponents => "invalid quantization exponents"
    },
  )
}

///|
pub extend ValidationError with Show::{to_string, output}

///|
pub impl Show for DecodingError with fn output(self, logger) {
  logger.write_string(
    match self {
      CodeBlockDecodeFailure => "failed to decode code-block"
      TooManyBitplanes => "number of bitplanes is too large"
      TooManyCodingPasses => "code-block contains too many coding passes"
      InvalidBitplaneCount => "invalid number of bitplanes"
      InvalidPrecinct => "a precinct was invalid"
      InvalidProgressionIterator => "a progression iterator was invalid"
      UnexpectedEof => "unexpected end of data"
    },
  )
}

///|
pub extend DecodingError with Show::{to_string, output}

///|
pub impl Show for ColorError with fn output(self, logger) {
  logger.write_string(
    match self {
      Mct => "multi-component transform failed"
      PaletteResolutionFailed => "failed to resolve palette indices"
      SyccConversionFailed => "failed to convert from sYCC to RGB"
      LabConversionFailed => "failed to convert from LAB to RGB"
    },
  )
}

///|
pub extend ColorError with Show::{to_string, output}
