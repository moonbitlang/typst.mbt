// Port of `moxcms::tag`.

///|
let tag_size_const : Int = 12

///|
priv enum Tag {
  RedXyz
  GreenXyz
  BlueXyz
  RedToneReproduction
  GreenToneReproduction
  BlueToneReproduction
  GreyToneReproduction
  MediaWhitePoint
  CodeIndependentPoints
  ChromaticAdaptation
  BlackPoint
  DeviceToPcsLutPerceptual
  DeviceToPcsLutColorimetric
  DeviceToPcsLutSaturation
  PcsToDeviceLutPerceptual
  PcsToDeviceLutColorimetric
  PcsToDeviceLutSaturation
  ProfileDescription
  Copyright
  ViewingConditionsDescription
  DeviceManufacturer
  DeviceModel
  Gamut
  Luminance
  Measurement
  Chromaticity
  ObserverConditions
  CharTarget
  Technology
  CalibrationDateTime
}

///|
/// Big-endian four character signature.
fn sig(s : String) -> UInt {
  let mut v = 0U
  for c in s {
    v = (v << 8) | c.to_int().reinterpret_as_uint()
  }
  v
}

///|
fn Tag::try_from(value : UInt) -> Tag? {
  let tags : Array[(String, Tag)] = [
    ("rXYZ", RedXyz),
    ("gXYZ", GreenXyz),
    ("bXYZ", BlueXyz),
    ("rTRC", RedToneReproduction),
    ("gTRC", GreenToneReproduction),
    ("bTRC", BlueToneReproduction),
    ("kTRC", GreyToneReproduction),
    ("wtpt", MediaWhitePoint),
    ("cicp", CodeIndependentPoints),
    ("chad", ChromaticAdaptation),
    ("bkpt", BlackPoint),
    ("A2B0", DeviceToPcsLutPerceptual),
    ("A2B1", DeviceToPcsLutColorimetric),
    ("A2B2", DeviceToPcsLutSaturation),
    ("B2A0", PcsToDeviceLutPerceptual),
    ("B2A1", PcsToDeviceLutColorimetric),
    ("B2A2", PcsToDeviceLutSaturation),
    ("desc", ProfileDescription),
    ("cprt", Copyright),
    ("vued", ViewingConditionsDescription),
    ("dmnd", DeviceManufacturer),
    ("dmdd", DeviceModel),
    ("gamt", Gamut),
    ("lumi", Luminance),
    ("meas", Measurement),
    ("chrm", Chromaticity),
    ("view", ObserverConditions),
    ("targ", CharTarget),
    ("tech", Technology),
    ("calt", CalibrationDateTime),
  ]
  for t in tags {
    if sig(t.0) == value {
      return Some(t.1)
    }
  }
  None
}

///|
priv enum TagTypeDefinition {
  Text
  MultiLocalizedUnicode
  Description
  MabLut
  MbaLut
  ParametricToneCurve
  LutToneCurve
  Xyz
  MultiProcessElement
  DefViewingConditions
  Signature
  Cicp
  DateTime
  S15Fixed16Array
  U8Array
  U16Fixed16Array
  U16Array
  U32Array
  U64Array
  Measurement
  NotAllowed
} derive(Eq)

///|
fn TagTypeDefinition::from(value : UInt) -> TagTypeDefinition {
  let defs : Array[(String, TagTypeDefinition)] = [
    ("mluc", MultiLocalizedUnicode),
    ("desc", Description),
    ("text", Text),
    ("mAB ", MabLut),
    ("mBA ", MbaLut),
    ("para", ParametricToneCurve),
    ("curv", LutToneCurve),
    ("XYZ ", Xyz),
    ("mpet", MultiProcessElement),
    ("view", DefViewingConditions),
    ("sig ", Signature),
    ("cicp", Cicp),
    ("dtim", DateTime),
    ("meas", Measurement),
    ("sf32", S15Fixed16Array),
    ("uf32", U16Fixed16Array),
    ("ui16", U16Array),
    ("ui32", U32Array),
    ("ui64", U64Array),
    ("ui08", U8Array),
  ]
  for d in defs {
    if sig(d.0) == value {
      return d.1
    }
  }
  NotAllowed
}
