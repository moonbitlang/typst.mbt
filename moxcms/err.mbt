// Port of `moxcms::err`.

///|
pub(all) struct MalformedSize {
  size : Int
  expected : Int
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MalformedSize with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MalformedSize with @debug.Debug::{to_repr}

///|
pub(all) suberror CmsError {
  LaneSizeMismatch
  LaneMultipleOfChannels
  InvalidProfile
  InvalidTrcCurve
  InvalidCicp
  CurveLutIsTooLarge
  ParametricCurveZeroDivision
  InvalidRenderingIntent
  DivisionByZero
  UnsupportedColorPrimaries(Int)
  UnsupportedTrc(Int)
  InvalidLayout
  UnsupportedProfileConnection
  BuildTransferFunction
  UnsupportedChannelConfiguration
  UnknownTag(UInt)
  UnknownTagTypeDefinition(UInt)
  UnsupportedLutRenderingIntent(RenderingIntent)
  InvalidAtoBLut
  OverflowingError
  LUTTablesInvalidKind
  MalformedClut(MalformedSize)
  MalformedCurveLutTable(MalformedSize)
  InvalidInksCountForProfile
  MalformedTrcCurve(String)
  OutOfMemory(Int)
  IncorrectlyFormedLut(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CmsError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CmsError with @debug.Debug::{to_repr}

///|
pub impl Show for CmsError with fn output(self, logger) {
  let s = match self {
    LaneSizeMismatch => "Lanes length must match"
    LaneMultipleOfChannels =>
      "Lane length must not be multiple of channel count"
    InvalidProfile => "Invalid ICC profile"
    InvalidCicp => "Invalid Code Independent point (CICP) in ICC profile"
    InvalidTrcCurve => "Invalid TRC curve"
    CurveLutIsTooLarge => "Curve Lut is too large"
    ParametricCurveZeroDivision =>
      "Parametric Curve definition causes division by zero"
    InvalidRenderingIntent => "Invalid rendering intent"
    DivisionByZero => "Division by zero"
    UnsupportedColorPrimaries(value) => "Unsupported color primaries, \{value}"
    UnsupportedTrc(value) => "Unsupported TRC \{value}"
    InvalidLayout => "Invalid layout"
    UnsupportedProfileConnection => "Unsupported profile connection"
    BuildTransferFunction => "Can't reconstruct transfer function"
    UnsupportedChannelConfiguration => "Can't reconstruct channel configuration"
    UnknownTag(t) => "Unknown tag: \{t}"
    UnknownTagTypeDefinition(t) => "Unknown tag type definition: \{t}"
    UnsupportedLutRenderingIntent(intent) =>
      "Can't find LUT for rendering intent: \{intent}"
    InvalidAtoBLut => "Invalid A to B Lut"
    OverflowingError => "Overflowing was happen, that is not allowed"
    LUTTablesInvalidKind => "All LUT curves must have same kind"
    MalformedClut(size) =>
      "Invalid CLUT size: MalformedSize { size: \{size.size}, expected: \{size.expected} }"
    MalformedCurveLutTable(size) =>
      "Malformed curve LUT size: MalformedSize { size: \{size.size}, expected: \{size.expected} }"
    InvalidInksCountForProfile => "Invalid inks count for profile was provided"
    MalformedTrcCurve(str) => str
    OutOfMemory(capacity) =>
      "There is no enough memory to allocate \{capacity} bytes"
    IncorrectlyFormedLut(str) => str
  }
  logger.write_string(s)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CmsError with Show::{to_string, output}
