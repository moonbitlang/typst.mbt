// Port of `moxcms::profile`.

///|
/// 10 MB max, for Fogra39 etc.
let max_profile_size : Int = 1024 * 1024 * 10

///|
pub(all) enum ProfileVersion {
  V2_0
  V2_1
  V2_2
  V2_3
  V2_4
  V4_0
  V4_1
  V4_2
  V4_3
  V4_4
  Unknown
} derive(Eq, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileVersion with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileVersion with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileVersion with @debug.Debug::{to_repr}

///|
fn ProfileVersion::try_from(value : UInt) -> ProfileVersion raise CmsError {
  // First try exact match for known versions
  match value {
    0x02000000U => return V2_0
    0x02100000U => return V2_1
    0x02200000U => return V2_2
    0x02300000U => return V2_3
    0x02400000U => return V2_4
    0x04000000U => return V4_0
    0x04100000U => return V4_1
    0x04200000U => return V4_2
    0x04300000U => return V4_3
    0x04400000U => return V4_4
    _ => ()
  }
  // Extract major version (first byte) for range matching
  let major = (value >> 24) & 0xffU
  let minor = (value >> 20) & 0x0fU
  match major {
    // Version 0.x is invalid - reject
    0U => raise InvalidProfile
    2U =>
      match minor {
        0U => V2_0
        1U => V2_1
        2U => V2_2
        3U => V2_3
        _ => V2_4
      }
    // v3.x (rare but exists) - treat as v2.4 (functionally similar)
    3U => V2_4
    4U =>
      match minor {
        0U => V4_0
        1U => V4_1
        2U => V4_2
        3U => V4_3
        _ => V4_4
      }
    // v5.x+ (ICC MAX) and other unknown versions - reject
    _ => raise InvalidProfile
  }
}

///|
pub(all) enum DataColorSpace {
  Xyz
  Lab
  Luv
  YCbr
  Yxy
  Rgb
  Gray
  Hsv
  Hls
  Cmyk
  Cmy
  Color2
  Color3
  Color4
  Color5
  Color6
  Color7
  Color8
  Color9
  Color10
  Color11
  Color12
  Color13
  Color14
  Color15
} derive(Eq, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataColorSpace with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataColorSpace with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DataColorSpace with @debug.Debug::{to_repr}

///|
pub fn DataColorSpace::check_layout(
  self : DataColorSpace,
  layout : Layout,
) -> Unit raise CmsError {
  let unsupported = match self {
    Xyz => layout != Rgb
    Lab => layout != Rgb && layout != Rgba
    Luv => layout != Rgb
    YCbr => layout != Rgb
    Yxy => layout != Rgb
    Rgb => layout != Rgb && layout != Rgba
    Gray => layout != Gray && layout != GrayAlpha
    Hsv => layout != Rgb
    Hls => layout != Rgb
    Cmyk => layout != Rgba
    Cmy => layout != Rgb
    Color2 => layout != GrayAlpha
    Color3 => layout != Rgb
    Color4 => layout != Rgba
    Color5 => layout != Inks5
    Color6 => layout != Inks6
    Color7 => layout != Inks7
    Color8 => layout != Inks8
    Color9 => layout != Inks9
    Color10 => layout != Inks10
    Color11 => layout != Inks11
    Color12 => layout != Inks12
    Color13 => layout != Inks13
    Color14 => layout != Inks14
    Color15 => layout != Inks15
  }
  if unsupported {
    raise InvalidLayout
  }
}

///|
fn DataColorSpace::is_three_channels(self : DataColorSpace) -> Bool {
  self is (Xyz | Lab | Luv | YCbr | Yxy | Rgb | Hsv | Hls | Cmy | Color3)
}

///|
fn DataColorSpace::try_from(value : UInt) -> DataColorSpace raise CmsError {
  let spaces : Array[(String, DataColorSpace)] = [
    ("XYZ ", Xyz),
    ("Lab ", Lab),
    ("Luv ", Luv),
    ("YCbr", YCbr),
    ("Yxy ", Yxy),
    ("RGB ", Rgb),
    ("GRAY", Gray),
    ("HSV ", Hsv),
    ("HLS ", Hls),
    ("CMYK", Cmyk),
    ("CMY ", Cmy),
    ("2CLR", Color2),
    ("3CLR", Color3),
    ("4CLR", Color4),
    ("5CLR", Color5),
    ("6CLR", Color6),
    ("7CLR", Color7),
    ("8CLR", Color8),
    ("9CLR", Color9),
    ("ACLR", Color10),
    ("BCLR", Color11),
    ("CCLR", Color12),
    ("DCLR", Color13),
    ("ECLR", Color14),
    ("FCLR", Color15),
  ]
  for s in spaces {
    if sig(s.0) == value {
      return s.1
    }
  }
  raise InvalidProfile
}

///|
pub(all) enum ProfileClass {
  InputDevice
  DisplayDevice
  OutputDevice
  DeviceLink
  ColorSpace
  Abstract
  Named
} derive(Eq, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileClass with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileClass with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileClass with @debug.Debug::{to_repr}

///|
fn ProfileClass::try_from(value : UInt) -> ProfileClass raise CmsError {
  let classes : Array[(String, ProfileClass)] = [
    ("scnr", InputDevice),
    ("mntr", DisplayDevice),
    ("prtr", OutputDevice),
    ("link", DeviceLink),
    ("spac", ColorSpace),
    ("abst", Abstract),
    ("nmcl", Named),
  ]
  for c in classes {
    if sig(c.0) == value {
      return c.1
    }
  }
  raise InvalidProfile
}

///|
pub(all) enum LutStore {
  /// 8-bit entries.
  Store8(FixedArray[Int])
  /// 16-bit entries.
  Store16(FixedArray[Int])
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutStore with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutStore with @debug.Debug::{to_repr}

///|
pub(all) enum LutType {
  Lut8
  Lut16
  LutMab
  LutMba
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutType with @debug.Debug::{to_repr}

///|
fn LutType::try_from(value : UInt) -> LutType raise CmsError {
  if value == sig("mft1") {
    Lut8
  } else if value == sig("mft2") {
    Lut16
  } else if value == sig("mAB ") {
    LutMab
  } else if value == sig("mBA ") {
    LutMba
  } else {
    raise InvalidProfile
  }
}

///|
pub(all) enum LutWarehouse {
  Lut(LutDataType)
  Multidimensional(LutMultidimensionalType)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutWarehouse with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutWarehouse with @debug.Debug::{to_repr}

///|
pub(all) struct LutDataType {
  // used by lut8Type/lut16Type (mft2) only
  num_input_channels : Int
  num_output_channels : Int
  num_clut_grid_points : Int
  matrix : Matrix3d
  num_input_table_entries : Int
  num_output_table_entries : Int
  input_table : LutStore
  clut_table : LutStore
  output_table : LutStore
  lut_type : LutType
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutDataType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutDataType with @debug.Debug::{to_repr}

///|
pub(all) struct LutMultidimensionalType {
  num_input_channels : Int
  num_output_channels : Int
  grid_points : FixedArray[Int]
  clut : LutStore?
  a_curves : Array[ToneReprCurve]
  b_curves : Array[ToneReprCurve]
  m_curves : Array[ToneReprCurve]
  matrix : Matrix3d
  bias : Vector3d
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutMultidimensionalType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LutMultidimensionalType with @debug.Debug::{to_repr}

///|
pub(all) enum RenderingIntent {
  AbsoluteColorimetric
  Saturation
  RelativeColorimetric
  Perceptual
} derive(Eq, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RenderingIntent with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RenderingIntent with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RenderingIntent with @debug.Debug::{to_repr}

///|
pub impl Show for RenderingIntent with fn output(self, logger) {
  logger.write_string(
    match self {
      AbsoluteColorimetric => "AbsoluteColorimetric"
      Saturation => "Saturation"
      RelativeColorimetric => "RelativeColorimetric"
      Perceptual => "Perceptual"
    },
  )
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RenderingIntent with Show::{to_string, output}

///|
pub impl Default for RenderingIntent with fn default() {
  Perceptual
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RenderingIntent with Default::{default}

///|
fn RenderingIntent::try_from(value : UInt) -> RenderingIntent {
  // Non-conforming profiles may have invalid values; default to Perceptual.
  match value {
    0U => Perceptual
    1U => RelativeColorimetric
    2U => Saturation
    3U => AbsoluteColorimetric
    _ => Perceptual
  }
}

///|
pub(all) struct ColorDateTime {
  year : Int
  month : Int
  day_of_the_month : Int
  hours : Int
  minutes : Int
  seconds : Int
} derive(Eq, Debug, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorDateTime with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorDateTime with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorDateTime with Default::{default}

///|
fn ColorDateTime::new_from_slice(
  slice : BytesView,
) -> ColorDateTime raise CmsError {
  if slice.length() != 12 {
    raise InvalidProfile
  }
  let u16 = (i : Int) => (slice[i].to_int() << 8) | slice[i + 1].to_int()
  {
    year: u16(0),
    month: u16(2),
    day_of_the_month: u16(4),
    hours: u16(6),
    minutes: u16(8),
    seconds: u16(10),
  }
}

///|
/// A Coding Independent Code Point.
pub(all) struct CicpProfile {
  color_primaries : CicpColorPrimaries
  transfer_characteristics : TransferCharacteristics
  matrix_coefficients : MatrixCoefficients
  full_range : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CicpProfile with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CicpProfile with @debug.Debug::{to_repr}

///|
pub(all) struct LocalizableString {
  language : String
  country : String
  value : String
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LocalizableString with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LocalizableString with @debug.Debug::{to_repr}

///|
pub(all) struct DescriptionString {
  ascii_string : String
  unicode_language_code : UInt
  unicode_string : String
  script_code_code : Int
  mac_string : String
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DescriptionString with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DescriptionString with @debug.Debug::{to_repr}

///|
pub(all) enum ProfileText {
  PlainString(String)
  Localizable(Array[LocalizableString])
  Description(DescriptionString)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileText with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ProfileText with @debug.Debug::{to_repr}

///|
pub(all) enum StandardObserver {
  D50
  D65
  Unknown
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StandardObserver with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StandardObserver with @debug.Debug::{to_repr}

///|
fn StandardObserver::from(value : UInt) -> StandardObserver {
  if value == 1U {
    D50
  } else if value == 2U {
    D65
  } else {
    Unknown
  }
}

///|
pub(all) struct ViewingConditions {
  illuminant : Xyz
  surround : Xyz
  observer : StandardObserver
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ViewingConditions with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ViewingConditions with @debug.Debug::{to_repr}

///|
pub(all) enum MeasurementGeometry {
  Unknown
  /// 0°:45° or 45°:0°
  D45to45
  /// 0°:d or d:0°
  D0to0
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MeasurementGeometry with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MeasurementGeometry with @debug.Debug::{to_repr}

///|
fn MeasurementGeometry::from(value : UInt) -> MeasurementGeometry {
  if value == 1U {
    D45to45
  } else if value == 2U {
    D0to0
  } else {
    Unknown
  }
}

///|
pub(all) enum StandardIlluminant {
  Unknown
  D50
  D65
  D93
  F2
  D55
  A
  EquiPower
  F8
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StandardIlluminant with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StandardIlluminant with @debug.Debug::{to_repr}

///|
fn StandardIlluminant::from(value : UInt) -> StandardIlluminant {
  match value {
    1U => D50
    2U => D65
    3U => D93
    4U => F2
    5U => D55
    6U => A
    7U => EquiPower
    8U => F8
    _ => Unknown
  }
}

///|
pub(all) struct Measurement {
  observer : StandardObserver
  backing : Xyz
  geometry : MeasurementGeometry
  flare : Float
  illuminant : StandardIlluminant
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Measurement with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Measurement with @debug.Debug::{to_repr}

///|
/// Technology signature (`TechnologySignatures`), kept as the raw signature.
pub(all) struct TechnologySignatures {
  signature : UInt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TechnologySignatures with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TechnologySignatures with @debug.Debug::{to_repr}

///|
/// ICC Profile representation.
pub(all) struct ColorProfile {
  mut pcs : DataColorSpace
  mut color_space : DataColorSpace
  mut profile_class : ProfileClass
  mut rendering_intent : RenderingIntent
  mut red_colorant : Xyzd
  mut green_colorant : Xyzd
  mut blue_colorant : Xyzd
  mut white_point : Xyzd
  mut black_point : Xyzd?
  mut media_white_point : Xyzd?
  mut luminance : Xyzd?
  mut measurement : Measurement?
  mut red_trc : ToneReprCurve?
  mut green_trc : ToneReprCurve?
  mut blue_trc : ToneReprCurve?
  mut gray_trc : ToneReprCurve?
  mut cicp : CicpProfile?
  mut chromatic_adaptation : Matrix3d?
  mut lut_a_to_b_perceptual : LutWarehouse?
  mut lut_a_to_b_colorimetric : LutWarehouse?
  mut lut_a_to_b_saturation : LutWarehouse?
  mut lut_b_to_a_perceptual : LutWarehouse?
  mut lut_b_to_a_colorimetric : LutWarehouse?
  mut lut_b_to_a_saturation : LutWarehouse?
  mut gamut : LutWarehouse?
  mut copyright : ProfileText?
  mut description : ProfileText?
  mut device_manufacturer : ProfileText?
  mut device_model : ProfileText?
  mut char_target : ProfileText?
  mut viewing_conditions : ViewingConditions?
  mut viewing_conditions_description : ProfileText?
  mut technology : TechnologySignatures?
  mut calibration_date : ColorDateTime?
  mut creation_date_time : ColorDateTime
  /// Version for internal and viewing purposes only.
  mut version_internal : ProfileVersion
}

///|
fn ColorProfile::default() -> ColorProfile {
  {
    pcs: Xyz,
    color_space: Xyz,
    profile_class: DisplayDevice,
    rendering_intent: Perceptual,
    red_colorant: (Default::default() : Xyzd),
    green_colorant: (Default::default() : Xyzd),
    blue_colorant: (Default::default() : Xyzd),
    white_point: (Default::default() : Xyzd),
    black_point: None,
    media_white_point: None,
    luminance: None,
    measurement: None,
    red_trc: None,
    green_trc: None,
    blue_trc: None,
    gray_trc: None,
    cicp: None,
    chromatic_adaptation: None,
    lut_a_to_b_perceptual: None,
    lut_a_to_b_colorimetric: None,
    lut_a_to_b_saturation: None,
    lut_b_to_a_perceptual: None,
    lut_b_to_a_colorimetric: None,
    lut_b_to_a_saturation: None,
    gamut: None,
    copyright: None,
    description: None,
    device_manufacturer: None,
    device_model: None,
    char_target: None,
    viewing_conditions: None,
    viewing_conditions_description: None,
    technology: None,
    calibration_date: None,
    creation_date_time: (Default::default() : ColorDateTime),
    version_internal: V4_4,
  }
}

///|
/// Returns profile version.
pub fn ColorProfile::version(self : ColorProfile) -> ProfileVersion {
  self.version_internal
}

///|
/// Size of the ICC header plus the tag count (`size_of::<ProfileHeader>()`).
let profile_header_size : Int = 132

///|
fn be_u32(s : BytesView, i : Int) -> UInt {
  (s[i].to_uint() << 24) |
  (s[i + 1].to_uint() << 16) |
  (s[i + 2].to_uint() << 8) |
  s[i + 3].to_uint()
}

///|
fn be_i32(s : BytesView, i : Int) -> Int {
  be_u32(s, i).reinterpret_as_int()
}

///|
fn be_u16(s : BytesView, i : Int) -> Int {
  (s[i].to_int() << 8) | s[i + 1].to_int()
}

///|
/// Creates profile from the buffer.
pub fn ColorProfile::new_from_slice(
  slice : BytesView,
) -> ColorProfile raise CmsError {
  // `ProfileHeader::new_from_slice`.
  if slice.length() < profile_header_size {
    raise InvalidProfile
  }
  let version = ProfileVersion::try_from(be_u32(slice, 8))
  let profile_class = ProfileClass::try_from(be_u32(slice, 12))
  let data_color_space = DataColorSpace::try_from(be_u32(slice, 16))
  let pcs = DataColorSpace::try_from(be_u32(slice, 20))
  let creation_date_time = ColorDateTime::new_from_slice(slice[24:36])
  if be_u32(slice, 36) != sig("acsp") {
    raise InvalidProfile
  }
  let rendering_intent = RenderingIntent::try_from(be_u32(slice, 64))
  let illuminant = Xyz::new(
    s15_fixed16_number_to_float(be_i32(slice, 68)),
    s15_fixed16_number_to_float(be_i32(slice, 72)),
    s15_fixed16_number_to_float(be_i32(slice, 76)),
  )
  let tags_count = be_u32(slice, 128).to_uint64()
  if slice.length() >= max_profile_size {
    raise InvalidProfile
  }
  let tags_end = tags_count * tag_size_const.to_uint64() +
    profile_header_size.to_uint64()
  if slice.length().to_uint64() < tags_end {
    raise InvalidProfile
  }
  let tags_end = tags_end.to_int()
  let profile = ColorProfile::default()
  profile.rendering_intent = rendering_intent
  profile.pcs = pcs
  profile.profile_class = profile_class
  profile.color_space = data_color_space
  profile.white_point = illuminant.to_xyzd()
  profile.version_internal = version
  profile.creation_date_time = creation_date_time
  let color_space = profile.color_space
  let mut offset = profile_header_size
  while offset + tag_size_const <= tags_end {
    let tag_value = be_u32(slice, offset)
    let tag_entry = be_u32(slice, offset + 4).to_uint64()
    let tag_size = be_u32(slice, offset + 8).to_uint64()
    offset += tag_size_const
    // Just ignore unknown tags
    guard Tag::try_from(tag_value) is Some(tag) else { continue }
    match tag {
      RedXyz =>
        if color_space == Rgb {
          profile.red_colorant = read_xyz_tag(slice, tag_entry, tag_size)
        }
      GreenXyz =>
        if color_space == Rgb {
          profile.green_colorant = read_xyz_tag(slice, tag_entry, tag_size)
        }
      BlueXyz =>
        if color_space == Rgb {
          profile.blue_colorant = read_xyz_tag(slice, tag_entry, tag_size)
        }
      RedToneReproduction =>
        if color_space == Rgb {
          profile.red_trc = read_trc_tag_s(slice, tag_entry, tag_size)
        }
      GreenToneReproduction =>
        if color_space == Rgb {
          profile.green_trc = read_trc_tag_s(slice, tag_entry, tag_size)
        }
      BlueToneReproduction =>
        if color_space == Rgb {
          profile.blue_trc = read_trc_tag_s(slice, tag_entry, tag_size)
        }
      GreyToneReproduction =>
        if color_space == Gray {
          profile.gray_trc = read_trc_tag_s(slice, tag_entry, tag_size)
        }
      MediaWhitePoint =>
        profile.media_white_point = Some(
          read_xyz_tag(slice, tag_entry, tag_size),
        )
      Luminance =>
        profile.luminance = Some(read_xyz_tag(slice, tag_entry, tag_size))
      Measurement =>
        profile.measurement = read_meas_tag(slice, tag_entry, tag_size)
      CodeIndependentPoints =>
        // This tag may be present when the data colour space in the profile
        // header is RGB, YCbCr, or XYZ, and the profile class in the profile
        // header is Input or Display.
        if (
            profile.profile_class == InputDevice ||
            profile.profile_class == DisplayDevice
          ) &&
          (
            profile.color_space == Rgb ||
            profile.color_space == YCbr ||
            profile.color_space == Xyz
          ) {
          profile.cicp = read_cicp_tag(slice, tag_entry, tag_size)
        }
      ChromaticAdaptation =>
        profile.chromatic_adaptation = read_chad_tag(slice, tag_entry, tag_size)
      BlackPoint =>
        profile.black_point = Some(read_xyz_tag(slice, tag_entry, tag_size))
      DeviceToPcsLutPerceptual =>
        profile.lut_a_to_b_perceptual = read_lut_tag(slice, tag_entry, tag_size)
      DeviceToPcsLutColorimetric =>
        profile.lut_a_to_b_colorimetric = read_lut_tag(
          slice, tag_entry, tag_size,
        )
      DeviceToPcsLutSaturation =>
        profile.lut_a_to_b_saturation = read_lut_tag(slice, tag_entry, tag_size)
      PcsToDeviceLutPerceptual =>
        profile.lut_b_to_a_perceptual = read_lut_tag(slice, tag_entry, tag_size)
      PcsToDeviceLutColorimetric =>
        profile.lut_b_to_a_colorimetric = read_lut_tag(
          slice, tag_entry, tag_size,
        )
      PcsToDeviceLutSaturation =>
        profile.lut_b_to_a_saturation = read_lut_tag(slice, tag_entry, tag_size)
      Gamut => profile.gamut = read_lut_tag(slice, tag_entry, tag_size)
      Copyright =>
        profile.copyright = read_string_tag(slice, tag_entry, tag_size)
      ProfileDescription =>
        profile.description = read_string_tag(slice, tag_entry, tag_size)
      ViewingConditionsDescription =>
        profile.viewing_conditions_description = read_string_tag(
          slice, tag_entry, tag_size,
        )
      DeviceModel =>
        profile.device_model = read_string_tag(slice, tag_entry, tag_size)
      DeviceManufacturer =>
        profile.device_manufacturer = read_string_tag(
          slice, tag_entry, tag_size,
        )
      CharTarget =>
        profile.char_target = read_string_tag(slice, tag_entry, tag_size)
      Chromaticity => ()
      ObserverConditions =>
        profile.viewing_conditions = read_viewing_conditions(
          slice, tag_entry, tag_size,
        )
      Technology =>
        profile.technology = read_tech_tag(slice, tag_entry, tag_size)
      CalibrationDateTime =>
        profile.calibration_date = read_date_time_tag(
          slice, tag_entry, tag_size,
        )
    }
  }
  profile
}

///|
pub fn ColorProfile::colorant_matrix(self : ColorProfile) -> Matrix3d {
  {
    v: [
      self.red_colorant.x,
      self.green_colorant.x,
      self.blue_colorant.x,
      self.red_colorant.y,
      self.green_colorant.y,
      self.blue_colorant.y,
      self.red_colorant.z,
      self.green_colorant.z,
      self.blue_colorant.z,
    ],
  }
}

///|
/// Returns the RGB to XYZ transformation matrix (the colorant matrix, see
/// ICC.1:2022-05 Section F.3).
pub fn ColorProfile::rgb_to_xyz_matrix(self : ColorProfile) -> Matrix3d {
  self.colorant_matrix()
}

///|
/// Computes transform matrix RGB -> XYZ -> RGB.
/// Current profile is used as source, other as destination.
pub fn ColorProfile::transform_matrix(
  self : ColorProfile,
  dest : ColorProfile,
) -> Matrix3d {
  let source = self.rgb_to_xyz_matrix()
  let dst = dest.rgb_to_xyz_matrix()
  let dest_inverse = dst.inverse()
  dest_inverse.mat_mul(source)
}

///|
fn ColorProfile::has_device_to_pcs_lut(self : ColorProfile) -> Bool {
  self.lut_a_to_b_perceptual is Some(_) ||
  self.lut_a_to_b_saturation is Some(_) ||
  self.lut_a_to_b_colorimetric is Some(_)
}

///|
fn ColorProfile::has_pcs_to_device_lut(self : ColorProfile) -> Bool {
  self.lut_b_to_a_perceptual is Some(_) ||
  self.lut_b_to_a_saturation is Some(_) ||
  self.lut_b_to_a_colorimetric is Some(_)
}
