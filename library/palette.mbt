// Port of the parts of the `palette` crate (0.7.7) that Typst's colors use:
// the `f32` color types with alpha (`Lumaa<Srgb>`, `Oklaba`, `Oklcha`,
// `Srgba`, `LinSrgba`, `Hsla<Srgb>`, `Hsva<Srgb>`), their conversions
// (`FromColor`, i.e. unclamped conversion along palette's derived conversion
// graph followed by clamping), and the `Lighten`, `Saturate` and `ShiftHue`
// operations.
//
// All arithmetic is done in `Float` (f32) exactly like upstream. Transcendental
// functions are evaluated in double precision and rounded to `Float`.

///|
/// Rust `x as f32` for an `f64` (palette's `T::from_f64`).
fn f32_(x : Double) -> Float {
  Float::from_double(x)
}

///|
fn f32_floor(x : Float) -> Float {
  Float::from_double(x.to_double().floor())
}

///|
fn f32_ceil(x : Float) -> Float {
  Float::from_double(x.to_double().ceil())
}

///|
/// Rust `f32::max` (IEEE `maxNum`: a NaN operand is ignored).
fn f32_max(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// Rust `f32::min` (IEEE `minNum`).
fn f32_min(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// Rust `f32::clamp`.
fn f32_clamp(x : Float, min : Float, max : Float) -> Float {
  let mut x = x
  if x < min {
    x = min
  }
  if x > max {
    x = max
  }
  x
}

///|
/// Rust `f32::rem_euclid`.
fn f32_rem_euclid(x : Float, rhs : Float) -> Float {
  let r = Float::from_double(x.to_double() % rhs.to_double())
  if r < 0.0 {
    r + rhs.abs()
  } else {
    r
  }
}

///|
/// Rust `f32::is_normal`.
fn f32_is_normal(x : Float) -> Bool {
  let exp = (x.reinterpret_as_uint() >> 23) & 0xff
  exp != 0 && exp != 0xff
}

///|
/// Rust `f32::is_subnormal`.
fn f32_is_subnormal(x : Float) -> Bool {
  let bits = x.reinterpret_as_uint()
  ((bits >> 23) & 0xff) == 0 && (bits & 0x7fffff) != 0
}

///|
/// Rust `f32::to_radians`.
fn f32_to_radians(x : Float) -> Float {
  let rads_per_deg : Float = f32_(@math.PI) / 180.0
  x * rads_per_deg
}

///|
/// Rust `f32::to_degrees`.
fn f32_to_degrees(x : Float) -> Float {
  let pis_in_180 : Float = f32_(57.2957795130823208767981548141051703)
  x * pis_in_180
}

///|
/// Normalize an angle in degrees to `(-180, 180]` (palette
/// `SignedAngle::normalize_signed_angle`).
fn normalize_signed_angle(x : Float) -> Float {
  x - f32_ceil((x + 180.0) / 360.0 - 1.0) * 360.0
}

///|
/// Normalize an angle in degrees to `[0, 360)` (palette
/// `UnsignedAngle::normalize_unsigned_angle`).
fn normalize_unsigned_angle(x : Float) -> Float {
  let normalized = x - f32_floor(x / 360.0) * 360.0
  // Check for issues with very small numbers
  if f32_is_subnormal(normalized) || normalized >= 360.0 {
    0.0
  } else {
    normalized
  }
}

///|
/// Palette hue equality (`AngleEq`): angles are compared normalized.
fn hue_eq(a : Float, b : Float) -> Bool {
  normalize_unsigned_angle(a) == normalize_unsigned_angle(b)
}

///|
/// The hue in degrees of a cartesian `(a, b)` pair (palette
/// `OklabHue::from_cartesian`, which returns raw degrees).
fn hue_from_cartesian(a : Float, b : Float) -> Float {
  // atan2 returns values in the interval [-π, π]; use negative a and b and
  // rotate to ensure the hue is normalized.
  let hue_rad = f32_(@math.PI) + f32_atan2(-b, -a)
  f32_to_degrees(hue_rad)
}

///|
/// Palette `into_cartesian` of a raw hue in degrees: `(cos, sin)`.
fn hue_into_cartesian(hue : Float) -> (Float, Float) {
  let rad = f32_to_radians(hue)
  (f32_cos(rad), f32_sin(rad))
}

// Color types (all with alpha, upstream `Alpha<C, f32>`).

///|
/// A grayscale color in sRGB encoding with alpha (palette `Lumaa<Srgb, f32>`).
pub(all) struct Luma {
  luma : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Luma with @debug.Debug::{to_repr}

///|
/// An Oklab color with alpha (palette `Oklaba<f32>`).
pub(all) struct Oklab {
  l : Float
  a : Float
  b : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Oklab with @debug.Debug::{to_repr}

///|
/// An Oklch color with alpha (palette `Oklcha<f32>`). The hue is stored in
/// raw (unnormalized) degrees like palette's `OklabHue`.
pub(all) struct Oklch {
  l : Float
  chroma : Float
  hue : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Oklch with @debug.Debug::{to_repr}

///|
/// An sRGB color with alpha (palette `Srgba<f32>`).
pub(all) struct Rgb {
  red : Float
  green : Float
  blue : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rgb with @debug.Debug::{to_repr}

///|
/// A linear sRGB color with alpha (palette `LinSrgba<f32>`).
pub(all) struct LinearRgb {
  red : Float
  green : Float
  blue : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinearRgb with @debug.Debug::{to_repr}

///|
/// An HSL color with alpha (palette `Hsla<Srgb, f32>`). The hue is stored in
/// raw degrees like palette's `RgbHue`.
pub(all) struct Hsl {
  hue : Float
  saturation : Float
  lightness : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Hsl with @debug.Debug::{to_repr}

///|
/// An HSV color with alpha (palette `Hsva<Srgb, f32>`).
pub(all) struct Hsv {
  hue : Float
  saturation : Float
  value : Float
  alpha : Float
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Hsv with @debug.Debug::{to_repr}

///|
/// A CIE XYZ color with D65 white point (palette `Xyz<D65, f32>`, internal).
priv struct Xyz {
  x : Float
  y : Float
  z : Float
}

// Equality (palette `PartialEq`: hues are compared as angles).

///|
pub impl Eq for Luma with fn equal(self, other) {
  self.luma == other.luma && self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Luma with Eq::{not_equal, equal}

///|
pub impl Eq for Oklab with fn equal(self, other) {
  self.l == other.l &&
  self.a == other.a &&
  self.b == other.b &&
  self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Oklab with Eq::{not_equal, equal}

///|
pub impl Eq for Oklch with fn equal(self, other) {
  self.l == other.l &&
  self.chroma == other.chroma &&
  hue_eq(self.hue, other.hue) &&
  self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Oklch with Eq::{not_equal, equal}

///|
pub impl Eq for Rgb with fn equal(self, other) {
  self.red == other.red &&
  self.green == other.green &&
  self.blue == other.blue &&
  self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rgb with Eq::{not_equal, equal}

///|
pub impl Eq for LinearRgb with fn equal(self, other) {
  self.red == other.red &&
  self.green == other.green &&
  self.blue == other.blue &&
  self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LinearRgb with Eq::{not_equal, equal}

///|
pub impl Eq for Hsl with fn equal(self, other) {
  hue_eq(self.hue, other.hue) &&
  self.saturation == other.saturation &&
  self.lightness == other.lightness &&
  self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Hsl with Eq::{not_equal, equal}

///|
pub impl Eq for Hsv with fn equal(self, other) {
  hue_eq(self.hue, other.hue) &&
  self.saturation == other.saturation &&
  self.value == other.value &&
  self.alpha == other.alpha
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Hsv with Eq::{not_equal, equal}

// The sRGB transfer function (palette `encoding::Srgb`).

///|
fn srgb_into_linear(x : Float) -> Float {
  if x <= f32_(0.04045) {
    f32_(1.0 / 12.92) * x
  } else {
    // `mul_add` is fused (`libm::fmaf`).
    f32_powf(f32_fma(x, f32_(1.0 / 1.055), f32_(0.055 / 1.055)), f32_(2.4))
  }
}

///|
fn srgb_from_linear(x : Float) -> Float {
  if x <= f32_(0.0031308) {
    f32_(12.92) * x
  } else {
    f32_powf(x, f32_(1.0 / 2.4)) * f32_(1.055) - f32_(0.055)
  }
}

// Matrices.

///|
/// Multiply a 3x3 matrix (given as `f64`s, cast to `f32`) and a vector
/// (palette `multiply_3x3_and_vec3`).
fn mul3(
  m : ReadOnlyArray[Double],
  v : (Float, Float, Float),
) -> (Float, Float, Float) {
  let (x, y, z) = v
  let x1 = f32_(m[0]) * x
  let x2 = f32_(m[1]) * y
  let x3 = f32_(m[2]) * z
  let y1 = f32_(m[3]) * x
  let y2 = f32_(m[4]) * y
  let y3 = f32_(m[5]) * z
  let z1 = f32_(m[6]) * x
  let z2 = f32_(m[7]) * y
  let z3 = f32_(m[8]) * z
  (x1 + x2 + x3, y1 + y2 + y3, z1 + z2 + z3)
}

///|
let srgb_rgb_to_xyz : ReadOnlyArray[Double] = [
  0.4124564, 0.3575761, 0.1804375, 0.2126729, 0.7151522, 0.0721750, 0.0193339, 0.1191920,
  0.9503041,
]

///|
let srgb_xyz_to_rgb : ReadOnlyArray[Double] = [
  3.2404542, -1.5371385, -0.4985314, -0.9692660, 1.8760108, 0.0415560, 0.0556434,
  -0.2040259, 1.0572252,
]

///|
let oklab_m1 : ReadOnlyArray[Double] = [
  0.8190224432164319, 0.3619062562801221, -0.12887378261216414, 0.0329836671980271,
  0.9292868468965546, 0.03614466816999844, 0.048177199566046255, 0.26423952494422764,
  0.6335478258136937,
]

///|
let oklab_m1_inv : ReadOnlyArray[Double] = [
  1.2268798733741557, -0.5578149965554813, 0.28139105017721583, -0.04057576262431372,
  1.1122868293970594, -0.07171106666151701, -0.07637294974672142, -0.4214933239627914,
  1.5869240244272418,
]

///|
let oklab_m2 : ReadOnlyArray[Double] = [
  0.2104542553, 0.7936177850, -0.0040720468, 1.9779984951, -2.4285922050, 0.4505937099,
  0.0259040371, 0.7827717662, -0.8086757660,
]

///|
let oklab_m2_inv : ReadOnlyArray[Double] = [
  0.99999999845051981432, 0.39633779217376785678, 0.21580375806075880339, 1.0000000088817607767,
  -0.1055613423236563494, -0.063854174771705903402, 1.0000000546724109177, -0.089484182094965759684,
  -1.2914855378640917399,
]

// Unclamped conversions between the color types (palette
// `FromColorUnclamped`). Alpha is passed through by the caller.

///|
fn Xyz::from_linear_rgb(r : Float, g : Float, b : Float) -> Xyz {
  let (x, y, z) = mul3(srgb_rgb_to_xyz, (r, g, b))
  { x, y, z, }
}

///|
// palette's `FromColorUnclamped<Xyz> for Rgb` (src/rgb/rgb.rs:845) is only
// reached for RGB spaces other than sRGB (rgb.rs:840, :1025), which Typst
// does not use.
#warnings("-unused_value")
fn Xyz::to_linear_rgb(self : Xyz) -> (Float, Float, Float) {
  mul3(srgb_xyz_to_rgb, (self.x, self.y, self.z))
}

///|
fn Xyz::from_luma(luma : Float) -> Xyz {
  let l = srgb_into_linear(luma)
  { x: f32_(0.95047) * l, y: f32_(1.0) * l, z: f32_(1.08883) * l, }
}

///|
fn Xyz::to_luma(self : Xyz) -> Float {
  srgb_from_linear(self.y)
}

///|
fn Xyz::from_oklab(l : Float, a : Float, b : Float) -> Xyz {
  let (l, m, s) = mul3(oklab_m2_inv, (l, a, b))
  let (x, y, z) = mul3(oklab_m1_inv, (l * l * l, m * m * m, s * s * s))
  { x, y, z, }
}

///|
fn Xyz::to_oklab(self : Xyz) -> (Float, Float, Float) {
  let (l, m, s) = mul3(oklab_m1, (self.x, self.y, self.z))
  mul3(oklab_m2, (f32_cbrt(l), f32_cbrt(m), f32_cbrt(s)))
}

///|
fn linear_srgb_to_oklab(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float) {
  let l = f32_(0.4122214708) * r +
    f32_(0.5363325363) * g +
    f32_(0.0514459929) * b
  let m = f32_(0.2119034982) * r +
    f32_(0.6806995451) * g +
    f32_(0.1073969566) * b
  let s = f32_(0.0883024619) * r +
    f32_(0.2817188376) * g +
    f32_(0.6299787005) * b
  let l_ = f32_cbrt(l)
  let m_ = f32_cbrt(m)
  let s_ = f32_cbrt(s)
  (
    f32_(0.2104542553) * l_ + f32_(0.7936177850) * m_ - f32_(0.0040720468) * s_,
    f32_(1.9779984951) * l_ - f32_(2.4285922050) * m_ + f32_(0.4505937099) * s_,
    f32_(0.0259040371) * l_ + f32_(0.7827717662) * m_ - f32_(0.8086757660) * s_,
  )
}

///|
fn oklab_to_linear_srgb(
  l : Float,
  a : Float,
  b : Float,
) -> (Float, Float, Float) {
  let l_ = l + f32_(0.3963377774) * a + f32_(0.2158037573) * b
  let m_ = l - f32_(0.1055613458) * a - f32_(0.0638541728) * b
  let s_ = l - f32_(0.0894841775) * a - f32_(1.2914855480) * b
  let l = l_ * l_ * l_
  let m = m_ * m_ * m_
  let s = s_ * s_ * s_
  (
    f32_(4.0767416621) * l - f32_(3.3077115913) * m + f32_(0.2309699292) * s,
    f32_(-1.2684380046) * l + f32_(2.6097574011) * m - f32_(0.3413193965) * s,
    f32_(-0.0041960863) * l - f32_(0.7034186147) * m + f32_(1.7076147010) * s,
  )
}

///|
/// Oklch from Oklab (unclamped).
fn oklab_to_oklch_raw(l : Float, a : Float, b : Float) -> (Float, Float, Float) {
  let hue = hue_from_cartesian(a, b)
  let chroma = f32_hypot(a, b)
  (l, chroma, hue)
}

///|
/// Oklab from Oklch (unclamped).
fn oklch_to_oklab_raw(
  l : Float,
  chroma : Float,
  hue : Float,
) -> (Float, Float, Float) {
  let (a, b) = hue_into_cartesian(hue)
  let chroma = f32_max(chroma, 0.0)
  (l, a * chroma, b * chroma)
}

///|
/// HSL from RGB (unclamped; palette `FromColorUnclamped<Rgb> for Hsl`).
fn rgb_to_hsl_raw(r : Float, g : Float, b : Float) -> (Float, Float, Float) {
  // Avoid negative numbers
  let red = f32_max(r, 0.0)
  let green = f32_max(g, 0.0)
  let blue = f32_max(b, 0.0)
  let (max, min, sep, coeff) = rgb_max_min_sep(red, green, blue)
  let mut h : Float = 0.0
  let mut s : Float = 0.0
  let sum = max + min
  let l = sum / 2.0
  if max != min {
    let d = max - min
    s = if sum > 1.0 { d / (2.0 - sum) } else { d / sum }
    h = (sep / d + coeff) * 60.0
  }
  (h, s, l)
}

///|
fn rgb_max_min_sep(
  red : Float,
  green : Float,
  blue : Float,
) -> (Float, Float, Float, Float) {
  let (max, min, sep, coeff) = if red > green {
    (red, green, green - blue, (0.0 : Float))
  } else {
    (green, red, blue - red, (2.0 : Float))
  }
  if blue > max {
    (blue, min, red - green, 4.0)
  } else {
    let min_val = if blue < min { blue } else { min }
    (max, min_val, sep, coeff)
  }
}

///|
/// HSV from RGB (unclamped).
fn rgb_to_hsv_raw(r : Float, g : Float, b : Float) -> (Float, Float, Float) {
  // Avoid negative numbers
  let red = f32_max(r, 0.0)
  let green = f32_max(g, 0.0)
  let blue = f32_max(b, 0.0)
  let (max, min, sep, coeff) = rgb_max_min_sep(red, green, blue)
  let (h, s) = if max != min {
    let d = max - min
    let h = (sep / d + coeff) * 60.0
    let s = d / max
    (h, s)
  } else {
    (0.0, 0.0)
  }
  (h, s, max)
}

///|
/// The zone-based conversion shared by HSL and HSV to RGB.
fn hue_zones_to_rgb(hue : Float, c : Float, m : Float) -> (Float, Float, Float) {
  let h = normalize_unsigned_angle(hue) / 60.0
  // We avoid using %, since it's not always (or never?) supported in SIMD
  let h_mod_two = h - f32_floor(h * 0.5) * 2.0
  let x = c * (1.0 - (h_mod_two - 1.0).abs())
  let is_zone0 = h >= 0.0 && h < 1.0
  let is_zone1 = h >= 1.0 && h < 2.0
  let is_zone2 = h >= 2.0 && h < 3.0
  let is_zone3 = h >= 3.0 && h < 4.0
  let is_zone4 = h >= 4.0 && h < 5.0
  let red : Float = if is_zone1 || is_zone4 {
    x
  } else if is_zone2 || is_zone3 {
    0.0
  } else {
    c
  }
  let green : Float = if is_zone0 || is_zone3 {
    x
  } else if is_zone1 || is_zone2 {
    c
  } else {
    0.0
  }
  let blue : Float = if is_zone0 || is_zone1 {
    0.0
  } else if is_zone3 || is_zone4 {
    c
  } else {
    x
  }
  (red + m, green + m, blue + m)
}

///|
/// RGB from HSL (unclamped).
fn hsl_to_rgb_raw(
  hue : Float,
  saturation : Float,
  lightness : Float,
) -> (Float, Float, Float) {
  let c = ((1.0 : Float) - (lightness * 2.0 - 1.0).abs()) * saturation
  let m = lightness - c * 0.5
  hue_zones_to_rgb(hue, c, m)
}

///|
/// RGB from HSV (unclamped).
fn hsv_to_rgb_raw(
  hue : Float,
  saturation : Float,
  value : Float,
) -> (Float, Float, Float) {
  let c = value * saturation
  let m = value - c
  hue_zones_to_rgb(hue, c, m)
}

///|
/// HSV from HSL (unclamped).
fn hsl_to_hsv_raw(
  hue : Float,
  saturation : Float,
  lightness : Float,
) -> (Float, Float, Float) {
  let x = (if lightness < 0.5 { lightness } else { 1.0 - lightness }) *
    saturation
  let value = lightness + x
  // avoid divide by zero
  let saturation = if f32_is_normal(value) { x * 2.0 / value } else { 0.0 }
  (hue, saturation, value)
}

///|
/// HSL from HSV (unclamped).
fn hsv_to_hsl_raw(
  hue : Float,
  saturation : Float,
  value : Float,
) -> (Float, Float, Float) {
  let x = ((2.0 : Float) - saturation) * value
  let saturation : Float = if !f32_is_normal(value) {
    0.0
  } else if x < 1.0 {
    if f32_is_normal(x) {
      saturation * value / x
    } else {
      0.0
    }
  } else {
    let denom = (2.0 : Float) - x
    if f32_is_normal(denom) {
      saturation * value / denom
    } else {
      0.0
    }
  }
  (hue, saturation, x / 2.0)
}

// Clamping (palette `Clamp`).

///|
fn clamp01(x : Float) -> Float {
  f32_clamp(x, 0.0, 1.0)
}

///|
fn Luma::clamp(self : Luma) -> Luma {
  { luma: clamp01(self.luma), alpha: clamp01(self.alpha), }
}

///|
fn Oklab::clamp(self : Oklab) -> Oklab {
  { l: clamp01(self.l), a: self.a, b: self.b, alpha: clamp01(self.alpha), }
}

///|
fn Oklch::clamp(self : Oklch) -> Oklch {
  {
    l: clamp01(self.l),
    chroma: f32_max(self.chroma, 0.0),
    hue: self.hue,
    alpha: clamp01(self.alpha),
  }
}

///|
fn Rgb::clamp(self : Rgb) -> Rgb {
  {
    red: clamp01(self.red),
    green: clamp01(self.green),
    blue: clamp01(self.blue),
    alpha: clamp01(self.alpha),
  }
}

///|
fn LinearRgb::clamp(self : LinearRgb) -> LinearRgb {
  {
    red: clamp01(self.red),
    green: clamp01(self.green),
    blue: clamp01(self.blue),
    alpha: clamp01(self.alpha),
  }
}

///|
fn Hsl::clamp(self : Hsl) -> Hsl {
  {
    hue: self.hue,
    saturation: clamp01(self.saturation),
    lightness: clamp01(self.lightness),
    alpha: clamp01(self.alpha),
  }
}

///|
fn Hsv::clamp(self : Hsv) -> Hsv {
  {
    hue: self.hue,
    saturation: clamp01(self.saturation),
    value: clamp01(self.value),
    alpha: clamp01(self.alpha),
  }
}

// Unclamped conversions between the alpha types, following palette's
// conversion graph.

///|
fn Rgb::into_linear(self : Rgb) -> LinearRgb {
  {
    red: srgb_into_linear(self.red),
    green: srgb_into_linear(self.green),
    blue: srgb_into_linear(self.blue),
    alpha: self.alpha,
  }
}

///|
/// Convert linear RGB to non-linear RGB (palette `Rgb::from_linear`).
pub fn Rgb::from_linear(c : LinearRgb) -> Rgb {
  {
    red: srgb_from_linear(c.red),
    green: srgb_from_linear(c.green),
    blue: srgb_from_linear(c.blue),
    alpha: c.alpha,
  }
}

///|
fn Rgb::to_xyz(self : Rgb) -> Xyz {
  let lin = self.into_linear()
  Xyz::from_linear_rgb(lin.red, lin.green, lin.blue)
}

///|
fn LinearRgb::to_xyz(self : LinearRgb) -> Xyz {
  Xyz::from_linear_rgb(self.red, self.green, self.blue)
}

///|
fn Oklab::to_xyz(self : Oklab) -> Xyz {
  Xyz::from_oklab(self.l, self.a, self.b)
}

///|
fn Oklab::from_oklch_raw(c : Oklch) -> Oklab {
  let (l, a, b) = oklch_to_oklab_raw(c.l, c.chroma, c.hue)
  { l, a, b, alpha: c.alpha, }
}

///|
fn Oklab::from_xyz_raw(xyz : Xyz, alpha : Float) -> Oklab {
  let (l, a, b) = xyz.to_oklab()
  { l, a, b, alpha, }
}

///|
fn Oklab::from_rgb_raw(c : Rgb) -> Oklab {
  let lin = c.into_linear()
  let (l, a, b) = linear_srgb_to_oklab(lin.red, lin.green, lin.blue)
  { l, a, b, alpha: c.alpha, }
}

///|
fn Oklab::from_linear_rgb_raw(c : LinearRgb) -> Oklab {
  let (l, a, b) = linear_srgb_to_oklab(c.red, c.green, c.blue)
  { l, a, b, alpha: c.alpha, }
}

///|
fn Oklch::from_oklab_raw(c : Oklab) -> Oklch {
  let (l, chroma, hue) = oklab_to_oklch_raw(c.l, c.a, c.b)
  { l, chroma, hue, alpha: c.alpha, }
}

///|
fn LinearRgb::from_oklab_raw(c : Oklab) -> LinearRgb {
  let (red, green, blue) = oklab_to_linear_srgb(c.l, c.a, c.b)
  { red, green, blue, alpha: c.alpha, }
}

///|
fn Rgb::from_oklab_raw(c : Oklab) -> Rgb {
  Rgb::from_linear(LinearRgb::from_oklab_raw(c))
}

///|
fn Rgb::from_luma_raw(c : Luma) -> Rgb {
  { red: c.luma, green: c.luma, blue: c.luma, alpha: c.alpha, }
}

///|
fn Rgb::from_hsl_raw(c : Hsl) -> Rgb {
  let (red, green, blue) = hsl_to_rgb_raw(c.hue, c.saturation, c.lightness)
  { red, green, blue, alpha: c.alpha, }
}

///|
fn Rgb::from_hsv_raw(c : Hsv) -> Rgb {
  let (red, green, blue) = hsv_to_rgb_raw(c.hue, c.saturation, c.value)
  { red, green, blue, alpha: c.alpha, }
}

///|
fn Hsl::from_rgb_raw(c : Rgb) -> Hsl {
  let (hue, saturation, lightness) = rgb_to_hsl_raw(c.red, c.green, c.blue)
  { hue, saturation, lightness, alpha: c.alpha, }
}

///|
fn Hsv::from_rgb_raw(c : Rgb) -> Hsv {
  let (hue, saturation, value) = rgb_to_hsv_raw(c.red, c.green, c.blue)
  { hue, saturation, value, alpha: c.alpha, }
}

///|
fn Luma::from_xyz_raw(xyz : Xyz, alpha : Float) -> Luma {
  { luma: xyz.to_luma(), alpha, }
}

// `FromColor` conversions (unclamped conversion, then clamping).

///|
pub fn Luma::from_oklab(c : Oklab) -> Luma {
  Luma::from_xyz_raw(c.to_xyz(), c.alpha).clamp()
}

///|
pub fn Luma::from_oklch(c : Oklch) -> Luma {
  Luma::from_xyz_raw(Oklab::from_oklch_raw(c).to_xyz(), c.alpha).clamp()
}

///|
pub fn Luma::from_rgb(c : Rgb) -> Luma {
  Luma::from_xyz_raw(c.to_xyz(), c.alpha).clamp()
}

///|
pub fn Luma::from_linear_rgb(c : LinearRgb) -> Luma {
  Luma::from_xyz_raw(c.to_xyz(), c.alpha).clamp()
}

///|
pub fn Luma::from_hsl(c : Hsl) -> Luma {
  Luma::from_xyz_raw(Rgb::from_hsl_raw(c).to_xyz(), c.alpha).clamp()
}

///|
pub fn Luma::from_hsv(c : Hsv) -> Luma {
  Luma::from_xyz_raw(Rgb::from_hsv_raw(c).to_xyz(), c.alpha).clamp()
}

///|
pub fn Oklab::from_luma(c : Luma) -> Oklab {
  Oklab::from_xyz_raw(Xyz::from_luma(c.luma), c.alpha).clamp()
}

///|
pub fn Oklab::from_oklch(c : Oklch) -> Oklab {
  Oklab::from_oklch_raw(c).clamp()
}

///|
pub fn Oklab::from_rgb(c : Rgb) -> Oklab {
  Oklab::from_rgb_raw(c).clamp()
}

///|
pub fn Oklab::from_linear_rgb(c : LinearRgb) -> Oklab {
  Oklab::from_linear_rgb_raw(c).clamp()
}

///|
pub fn Oklab::from_hsl(c : Hsl) -> Oklab {
  Oklab::from_rgb_raw(Rgb::from_hsl_raw(c)).clamp()
}

///|
pub fn Oklab::from_hsv(c : Hsv) -> Oklab {
  Oklab::from_rgb_raw(Rgb::from_hsv_raw(c)).clamp()
}

///|
pub fn Oklch::from_luma(c : Luma) -> Oklch {
  Oklch::from_oklab_raw(Oklab::from_xyz_raw(Xyz::from_luma(c.luma), c.alpha)).clamp()
}

///|
pub fn Oklch::from_oklab(c : Oklab) -> Oklch {
  Oklch::from_oklab_raw(c).clamp()
}

///|
pub fn Oklch::from_rgb(c : Rgb) -> Oklch {
  Oklch::from_oklab_raw(Oklab::from_rgb_raw(c)).clamp()
}

///|
pub fn Oklch::from_linear_rgb(c : LinearRgb) -> Oklch {
  Oklch::from_oklab_raw(Oklab::from_linear_rgb_raw(c)).clamp()
}

///|
pub fn Oklch::from_hsl(c : Hsl) -> Oklch {
  Oklch::from_oklab_raw(Oklab::from_rgb_raw(Rgb::from_hsl_raw(c))).clamp()
}

///|
pub fn Oklch::from_hsv(c : Hsv) -> Oklch {
  Oklch::from_oklab_raw(Oklab::from_rgb_raw(Rgb::from_hsv_raw(c))).clamp()
}

///|
pub fn Rgb::from_luma(c : Luma) -> Rgb {
  Rgb::from_luma_raw(c).clamp()
}

///|
pub fn Rgb::from_oklab(c : Oklab) -> Rgb {
  Rgb::from_oklab_raw(c).clamp()
}

///|
pub fn Rgb::from_oklch(c : Oklch) -> Rgb {
  Rgb::from_oklab_raw(Oklab::from_oklch_raw(c)).clamp()
}

///|
pub fn Rgb::from_rgb(c : Rgb) -> Rgb {
  c.clamp()
}

///|
pub fn Rgb::from_hsl(c : Hsl) -> Rgb {
  Rgb::from_hsl_raw(c).clamp()
}

///|
pub fn Rgb::from_hsv(c : Hsv) -> Rgb {
  Rgb::from_hsv_raw(c).clamp()
}

///|
/// Convert to linear RGB (palette `Rgb::into_linear`, unclamped).
pub fn Rgb::to_linear(self : Rgb) -> LinearRgb {
  self.into_linear()
}

///|
pub fn LinearRgb::from_luma(c : Luma) -> LinearRgb {
  let l = srgb_into_linear(c.luma)
  ({ red: l, green: l, blue: l, alpha: c.alpha, } : LinearRgb).clamp()
}

///|
pub fn LinearRgb::from_oklab(c : Oklab) -> LinearRgb {
  LinearRgb::from_oklab_raw(c).clamp()
}

///|
pub fn LinearRgb::from_oklch(c : Oklch) -> LinearRgb {
  LinearRgb::from_oklab_raw(Oklab::from_oklch_raw(c)).clamp()
}

///|
pub fn LinearRgb::from_rgb(c : Rgb) -> LinearRgb {
  c.into_linear().clamp()
}

///|
pub fn Hsl::from_luma(c : Luma) -> Hsl {
  Hsl::from_rgb_raw(Rgb::from_luma_raw(c)).clamp()
}

///|
pub fn Hsl::from_oklab(c : Oklab) -> Hsl {
  Hsl::from_rgb_raw(Rgb::from_oklab_raw(c)).clamp()
}

///|
pub fn Hsl::from_oklch(c : Oklch) -> Hsl {
  Hsl::from_rgb_raw(Rgb::from_oklab_raw(Oklab::from_oklch_raw(c))).clamp()
}

///|
pub fn Hsl::from_rgb(c : Rgb) -> Hsl {
  Hsl::from_rgb_raw(c).clamp()
}

///|
pub fn Hsl::from_hsv(c : Hsv) -> Hsl {
  let (hue, saturation, lightness) = hsv_to_hsl_raw(
    c.hue,
    c.saturation,
    c.value,
  )
  { hue, saturation, lightness, alpha: c.alpha, }.clamp()
}

///|
pub fn Hsv::from_luma(c : Luma) -> Hsv {
  Hsv::from_rgb_raw(Rgb::from_luma_raw(c)).clamp()
}

///|
pub fn Hsv::from_oklab(c : Oklab) -> Hsv {
  Hsv::from_rgb_raw(Rgb::from_oklab_raw(c)).clamp()
}

///|
pub fn Hsv::from_oklch(c : Oklch) -> Hsv {
  Hsv::from_rgb_raw(Rgb::from_oklab_raw(Oklab::from_oklch_raw(c))).clamp()
}

///|
pub fn Hsv::from_rgb(c : Rgb) -> Hsv {
  Hsv::from_rgb_raw(c).clamp()
}

///|
pub fn Hsv::from_hsl(c : Hsl) -> Hsv {
  let (hue, saturation, value) = hsl_to_hsv_raw(
    c.hue,
    c.saturation,
    c.lightness,
  )
  { hue, saturation, value, alpha: c.alpha, }.clamp()
}

// Lighten (palette `impl_lighten!`), darken is lightening by `-factor`.

///|
/// Palette's relative increase of a component within `[0, max]`.
fn increase(c : Float, factor : Float, max : Float) -> Float {
  let difference = if factor >= 0.0 { max - c } else { c }
  let delta = f32_max(difference, 0.0) * factor
  f32_clamp(c + delta, 0.0, max)
}

///|
pub fn Luma::lighten(self : Luma, factor : Float) -> Luma {
  { ..self, luma: increase(self.luma, factor, 1.0), }
}

///|
pub fn Oklab::lighten(self : Oklab, factor : Float) -> Oklab {
  { ..self, l: increase(self.l, factor, 1.0), }
}

///|
pub fn Oklch::lighten(self : Oklch, factor : Float) -> Oklch {
  { ..self, l: increase(self.l, factor, 1.0), }
}

///|
pub fn Rgb::lighten(self : Rgb, factor : Float) -> Rgb {
  {
    red: increase(self.red, factor, 1.0),
    green: increase(self.green, factor, 1.0),
    blue: increase(self.blue, factor, 1.0),
    alpha: self.alpha,
  }
}

///|
pub fn LinearRgb::lighten(self : LinearRgb, factor : Float) -> LinearRgb {
  {
    red: increase(self.red, factor, 1.0),
    green: increase(self.green, factor, 1.0),
    blue: increase(self.blue, factor, 1.0),
    alpha: self.alpha,
  }
}

///|
pub fn Hsl::lighten(self : Hsl, factor : Float) -> Hsl {
  { ..self, lightness: increase(self.lightness, factor, 1.0), }
}

///|
pub fn Hsv::lighten(self : Hsv, factor : Float) -> Hsv {
  { ..self, value: increase(self.value, factor, 1.0), }
}

///|
pub fn Hsl::saturate(self : Hsl, factor : Float) -> Hsl {
  { ..self, saturation: increase(self.saturation, factor, 1.0), }
}

///|
pub fn Hsv::saturate(self : Hsv, factor : Float) -> Hsv {
  { ..self, saturation: increase(self.saturation, factor, 1.0), }
}
