// Port of the parts of `moxcms::defaults` used here (`ColorProfile::new_srgb`).
//
// The sRGB colorants and white points are `const` computations upstream
// (Bradford adaptation of the BT.709 primaries, white points from color
// temperatures); their exact `f64` values are reproduced bit for bit.

///|
fn xyzd_bits(x : UInt64, y : UInt64, z : UInt64) -> Xyzd {
  {
    x: x.reinterpret_as_double(),
    y: y.reinterpret_as_double(),
    z: z.reinterpret_as_double(),
  }
}

///|
/// Creates new sRGB profile.
pub fn ColorProfile::new_srgb() -> ColorProfile {
  // `basic_rgb_profile`
  let profile = ColorProfile::default()
  profile.profile_class = DisplayDevice
  profile.rendering_intent = Perceptual
  profile.color_space = Rgb
  profile.pcs = Xyz
  // `BRADFORD_D` (unused by the transforms).
  profile.chromatic_adaptation = Some({
    v: [
      0.8951, 0.2664, -0.1614, -0.7502, 1.7135, 0.0367, 0.0389, -0.0685, 1.0296,
    ],
  })
  // `WHITE_POINT_D50.to_xyzd()`
  profile.white_point = xyzd_bits(
    0x3feed851bd9e048bUL, 0x3ff0000000000000UL, 0x3fea6451f9a346c4UL,
  )
  // `update_colorants(SRGB_COLORANTS)`
  profile.red_colorant = xyzd_bits(
    0x3fdbe4dcfb99356aUL, 0x3fcc76bbde88e5daUL, 0x3f8c86ba94661e1dUL,
  )
  profile.green_colorant = xyzd_bits(
    0x3fd8a8e6491c7081UL, 0x3fe6f1e505fb9864UL, 0x3fb8df43d581e71cUL,
  )
  profile.blue_colorant = xyzd_bits(
    0x3fc24fc63b68bcb5UL, 0x3faf06c023e3fd97UL, 0x3fe6d9ededb36a57UL,
  )
  let curve = Parametric(srgb_parametric())
  profile.red_trc = Some(curve)
  profile.blue_trc = Some(curve)
  profile.green_trc = Some(curve)
  // `WHITE_POINT_D65.to_xyzd()`
  profile.media_white_point = Some(
    xyzd_bits(
      4606733452195659113UL, 4607182418800017408UL, 4607579902304298209UL,
    ),
  )
  profile.cicp = Some({
    color_primaries: CicpColorPrimaries::Bt709,
    transfer_characteristics: TransferCharacteristics::Srgb,
    matrix_coefficients: MatrixCoefficients::Bt709,
    full_range: false,
  })
  profile.description = Some(
    Localizable([{ language: "en", country: "US", value: "sRGB IEC61966-2.1", }]),
  )
  profile.copyright = Some(
    Localizable([{ language: "en", country: "US", value: "Public Domain", }]),
  )
  profile
}

///|
/// Checks if profile is valid *Matrix Shaper* profile.
pub fn ColorProfile::is_matrix_shaper(self : ColorProfile) -> Bool {
  let zero = (Default::default() : Xyzd)
  self.color_space == Rgb &&
  !xyzd_eq(self.red_colorant, zero) &&
  !xyzd_eq(self.green_colorant, zero) &&
  !xyzd_eq(self.blue_colorant, zero) &&
  self.red_trc is Some(_) &&
  self.green_trc is Some(_) &&
  self.blue_trc is Some(_)
}

///|
/// `PartialEq` for `Xyzd` (IEEE comparison of the components).
fn xyzd_eq(a : Xyzd, b : Xyzd) -> Bool {
  a.x == b.x && a.y == b.y && a.z == b.z
}
