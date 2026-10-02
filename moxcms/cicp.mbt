// Port of the parts of `moxcms::cicp` used for ICC parsing and transforms.

///|
/// See Rec. ITU-T H.273 (12/2016) Table 2.
pub(all) enum CicpColorPrimaries {
  Reserved
  Bt709
  Unspecified
  Bt470M
  Bt470Bg
  Bt601
  Smpte240
  GenericFilm
  Bt2020
  Xyz
  Smpte431
  Smpte432
  Ebu3213
} derive(Eq, Debug)

///|
fn CicpColorPrimaries::try_from(value : Int) -> CicpColorPrimaries {
  // Values 0, 3, 13–21, 23–255 are all reserved so all map to the same
  // variant.
  match value {
    1 => Bt709
    2 => Unspecified
    4 => Bt470M
    5 => Bt470Bg
    6 => Bt601
    7 => Smpte240
    8 => GenericFilm
    9 => Bt2020
    10 => Xyz
    11 => Smpte431
    12 => Smpte432
    22 => Ebu3213
    _ => Reserved
  }
}

///|
/// See Rec. ITU-T H.273 (12/2016) Table 3.
pub(all) enum TransferCharacteristics {
  Reserved
  Bt709
  Unspecified
  Bt470M
  Bt470Bg
  Bt601
  Smpte240
  Linear
  Log100
  Log100sqrt10
  Iec61966
  Bt1361
  Srgb
  Bt202010bit
  Bt202012bit
  Smpte2084
  Smpte428
  Hlg
} derive(Eq, Debug)

///|
fn TransferCharacteristics::try_from(value : Int) -> TransferCharacteristics {
  match value {
    1 => Bt709
    2 => Unspecified
    4 => Bt470M
    5 => Bt470Bg
    6 => Bt601
    7 => Smpte240
    8 => Linear
    9 => Log100
    10 => Log100sqrt10
    11 => Iec61966
    12 => Bt1361
    13 => Srgb
    14 => Bt202010bit
    15 => Bt202012bit
    16 => Smpte2084
    17 => Smpte428
    18 => Hlg
    _ => Reserved
  }
}

///|
fn TransferCharacteristics::has_transfer_curve(
  self : TransferCharacteristics,
) -> Bool {
  self != Reserved && self != Unspecified
}

///|
/// Matrix Coefficients Enum (from ISO/IEC 23091-4 / MPEG CICP).
pub(all) enum MatrixCoefficients {
  Identity
  Bt709
  Unspecified
  Reserved
  Fcc
  Bt470Bg
  Smpte170m
  Smpte240m
  YCgCo
  Bt2020Ncl
  Bt2020Cl
  Smpte2085
  ChromaticityDerivedNCL
  ChromaticityDerivedCL
  ICtCp
} derive(Eq, Debug)

///|
fn MatrixCoefficients::try_from(
  value : Int,
) -> MatrixCoefficients raise CmsError {
  match value {
    0 => Identity
    1 => Bt709
    2 => Unspecified
    3 => Reserved
    4 => Fcc
    5 => Bt470Bg
    6 => Smpte170m
    7 => Smpte240m
    8 => YCgCo
    9 => Bt2020Ncl
    10 => Bt2020Cl
    11 => Smpte2085
    12 => ChromaticityDerivedNCL
    13 => ChromaticityDerivedCL
    14 => ICtCp
    _ => raise InvalidCicp
  }
}

///|
fn create_rec709_parametric() -> FixedArray[Float] {
  let pow_exp : Float = 0.45
  let g = Float::from_int(1) / pow_exp
  let b = Float::from_double(0.09929682680944 / 1.09929682680944)
  let c = Float::from_int(1) / Float::from_double(4.5)
  let d = Float::from_double(4.5 * 0.018053968510807)
  let a = Float::from_double(1.0 / 1.09929682680944)
  [g, a, b, c, d]
}
