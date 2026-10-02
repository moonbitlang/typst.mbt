// Port of `tiny-skia/src/color.rs`.
//
// `ColorU8` and `PremultipliedColorU8` are packed into a `UInt` in memory
// order (little-endian RGBA: red in the lowest byte), like `bytemuck::cast`
// of the upstream `[u8; 4]`.

///|
pub let alpha_u8_transparent : Int = 0x00

///|
pub let alpha_u8_opaque : Int = 0xFF

///|
/// An 8-bit RGBA color value (`r | g << 8 | b << 16 | a << 24`).
pub(all) struct ColorU8(UInt) derive(Eq, Debug)

///|
/// Creates a new color.
pub fn ColorU8::from_rgba(r : Int, g : Int, b : Int, a : Int) -> ColorU8 {
  ColorU8(pack_rgba(r, g, b, a))
}

///|
pub fn ColorU8::red(self : ColorU8) -> Int {
  (self.0 & 0xFF).reinterpret_as_int()
}

///|
pub fn ColorU8::green(self : ColorU8) -> Int {
  ((self.0 >> 8) & 0xFF).reinterpret_as_int()
}

///|
pub fn ColorU8::blue(self : ColorU8) -> Int {
  ((self.0 >> 16) & 0xFF).reinterpret_as_int()
}

///|
pub fn ColorU8::alpha(self : ColorU8) -> Int {
  (self.0 >> 24).reinterpret_as_int()
}

///|
/// Check that color is opaque.
pub fn ColorU8::is_opaque(self : ColorU8) -> Bool {
  self.alpha() == alpha_u8_opaque
}

///|
/// Converts into a premultiplied color.
pub fn ColorU8::premultiply(self : ColorU8) -> PremultipliedColorU8 {
  let a = self.alpha()
  if a != alpha_u8_opaque {
    PremultipliedColorU8::from_rgba_unchecked(
      premultiply_u8(self.red(), a),
      premultiply_u8(self.green(), a),
      premultiply_u8(self.blue(), a),
      a,
    )
  } else {
    PremultipliedColorU8(self.0)
  }
}

///|
/// An 8-bit, premultiplied RGBA color value.
pub(all) struct PremultipliedColorU8(UInt) derive(Eq, Debug)

///|
pub let premultiplied_color_u8_transparent : PremultipliedColorU8 = PremultipliedColorU8(
  0,
)

///|
fn pack_rgba(r : Int, g : Int, b : Int, a : Int) -> UInt {
  (r & 0xFF).reinterpret_as_uint() |
  ((g & 0xFF).reinterpret_as_uint() << 8) |
  ((b & 0xFF).reinterpret_as_uint() << 16) |
  ((a & 0xFF).reinterpret_as_uint() << 24)
}

///|
/// Creates a new premultiplied color. RGB components must be <= alpha.
pub fn PremultipliedColorU8::from_rgba(
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> PremultipliedColorU8? {
  if r <= a && g <= a && b <= a {
    Some(PremultipliedColorU8(pack_rgba(r, g, b, a)))
  } else {
    None
  }
}

///|
pub fn PremultipliedColorU8::from_rgba_unchecked(
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> PremultipliedColorU8 {
  PremultipliedColorU8(pack_rgba(r, g, b, a))
}

///|
pub fn PremultipliedColorU8::red(self : PremultipliedColorU8) -> Int {
  (self.0 & 0xFF).reinterpret_as_int()
}

///|
pub fn PremultipliedColorU8::green(self : PremultipliedColorU8) -> Int {
  ((self.0 >> 8) & 0xFF).reinterpret_as_int()
}

///|
pub fn PremultipliedColorU8::blue(self : PremultipliedColorU8) -> Int {
  ((self.0 >> 16) & 0xFF).reinterpret_as_int()
}

///|
pub fn PremultipliedColorU8::alpha(self : PremultipliedColorU8) -> Int {
  (self.0 >> 24).reinterpret_as_int()
}

///|
/// Check that color is opaque.
pub fn PremultipliedColorU8::is_opaque(self : PremultipliedColorU8) -> Bool {
  self.alpha() == alpha_u8_opaque
}

///|
/// Returns a demultiplied color.
pub fn PremultipliedColorU8::demultiply(self : PremultipliedColorU8) -> ColorU8 {
  let alpha = self.alpha()
  if alpha == alpha_u8_opaque {
    ColorU8(self.0)
  } else {
    let a = alpha.to_double() / 255.0
    ColorU8::from_rgba(
      f64_to_u8(self.red().to_double() / a + 0.5),
      f64_to_u8(self.green().to_double() / a + 0.5),
      f64_to_u8(self.blue().to_double() / a + 0.5),
      alpha,
    )
  }
}

///|
/// `x as u8` for an `f64` (saturating, NaN maps to 0).
fn f64_to_u8(x : Double) -> Int {
  if x != x {
    0
  } else if x >= 255.0 {
    255
  } else if x <= 0.0 {
    0
  } else {
    x.to_int()
  }
}

///|
/// `x as u8` for an `f32` (saturating, NaN maps to 0).
pub fn f32_to_u8(x : Float) -> Int {
  if x != x {
    0
  } else if x >= 255.0 {
    255
  } else if x <= 0.0 {
    0
  } else {
    x.to_int()
  }
}

///|
/// `x as u16` for an `f32` (saturating, NaN maps to 0).
pub fn f32_to_u16(x : Float) -> Int {
  if x != x {
    0
  } else if x >= 65535.0 {
    65535
  } else if x <= 0.0 {
    0
  } else {
    x.to_int()
  }
}

///|
/// An RGBA color value, holding four floating point components.
///
/// # Guarantees
///
/// - All values are in 0..=1 range.
pub(all) struct Color {
  r : Float
  g : Float
  b : Float
  a : Float
} derive(Eq, Debug)

///|
/// A transparent color.
pub let color_transparent : Color = { r: 0.0, g: 0.0, b: 0.0, a: 0.0, }

///|
/// A black color.
pub let color_black : Color = { r: 0.0, g: 0.0, b: 0.0, a: 1.0, }

///|
/// A white color.
pub let color_white : Color = { r: 1.0, g: 1.0, b: 1.0, a: 1.0, }

///|
/// Creates a new color from 4 components. All values must be in 0..=1 range.
pub fn Color::from_rgba(r : Float, g : Float, b : Float, a : Float) -> Color? {
  guard @path.normalized_f32(r) is Some(r) else { return None }
  guard @path.normalized_f32(g) is Some(g) else { return None }
  guard @path.normalized_f32(b) is Some(b) else { return None }
  guard @path.normalized_f32(a) is Some(a) else { return None }
  Some({ r, g, b, a, })
}

///|
/// Creates a new color from 4 components without checks.
pub fn Color::from_rgba_unchecked(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
) -> Color {
  { r, g, b, a, }
}

///|
/// `NormalizedF32::new_u8`.
fn normalized_u8(n : Int) -> Float {
  Float::from_int(n) / 255.0
}

///|
/// Creates a new color from 4 components (u8 values).
pub fn Color::from_rgba8(r : Int, g : Int, b : Int, a : Int) -> Color {
  {
    r: normalized_u8(r),
    g: normalized_u8(g),
    b: normalized_u8(b),
    a: normalized_u8(a),
  }
}

///|
pub fn Color::red(self : Color) -> Float {
  self.r
}

///|
pub fn Color::green(self : Color) -> Float {
  self.g
}

///|
pub fn Color::blue(self : Color) -> Float {
  self.b
}

///|
pub fn Color::alpha(self : Color) -> Float {
  self.a
}

///|
/// Returns the color with the alpha set (clamped to 0..=1).
pub fn Color::with_alpha(self : Color, c : Float) -> Color {
  { ..self, a: @path.normalized_f32_clamped(c), }
}

///|
/// Shifts color's opacity. Essentially, multiplies color's alpha by opacity.
pub fn Color::apply_opacity(self : Color, opacity : Float) -> Color {
  {
    ..self,
    a: @path.normalized_f32_clamped(self.a * @path.bound(opacity, 0.0, 1.0)),
  }
}

///|
/// Check that color is opaque.
pub fn Color::is_opaque(self : Color) -> Bool {
  self.a == 1.0
}

///|
/// Converts into a premultiplied color.
pub fn Color::premultiply(self : Color) -> PremultipliedColor {
  if self.is_opaque() {
    { r: self.r, g: self.g, b: self.b, a: self.a, }
  } else {
    {
      r: @path.normalized_f32_clamped(self.r * self.a),
      g: @path.normalized_f32_clamped(self.g * self.a),
      b: @path.normalized_f32_clamped(self.b * self.a),
      a: self.a,
    }
  }
}

///|
/// Converts into `ColorU8`.
pub fn Color::to_color_u8(self : Color) -> ColorU8 {
  ColorU8(color_f32_to_u8(self.r, self.g, self.b, self.a))
}

///|
/// A premultiplied RGBA color value, holding four floating point components.
pub(all) struct PremultipliedColor {
  r : Float
  g : Float
  b : Float
  a : Float
} derive(Eq, Debug)

///|
pub fn PremultipliedColor::red(self : PremultipliedColor) -> Float {
  self.r
}

///|
pub fn PremultipliedColor::green(self : PremultipliedColor) -> Float {
  self.g
}

///|
pub fn PremultipliedColor::blue(self : PremultipliedColor) -> Float {
  self.b
}

///|
pub fn PremultipliedColor::alpha(self : PremultipliedColor) -> Float {
  self.a
}

///|
/// Returns a demultiplied color.
pub fn PremultipliedColor::demultiply(self : PremultipliedColor) -> Color {
  let a = self.a
  if a == 0.0 {
    color_transparent
  } else {
    {
      r: @path.normalized_f32_clamped(self.r / a),
      g: @path.normalized_f32_clamped(self.g / a),
      b: @path.normalized_f32_clamped(self.b / a),
      a,
    }
  }
}

///|
/// Converts into `PremultipliedColorU8`.
pub fn PremultipliedColor::to_color_u8(
  self : PremultipliedColor,
) -> PremultipliedColorU8 {
  PremultipliedColorU8(color_f32_to_u8(self.r, self.g, self.b, self.a))
}

///|
/// Return a*b/255, rounding any fractional bits.
pub fn premultiply_u8(c : Int, a : Int) -> Int {
  let prod = c * a + 128
  ((prod + (prod >> 8)) >> 8) & 0xFF
}

///|
fn color_f32_to_u8(r : Float, g : Float, b : Float, a : Float) -> UInt {
  pack_rgba(
    f32_to_u8(r * 255.0 + 0.5),
    f32_to_u8(g * 255.0 + 0.5),
    f32_to_u8(b * 255.0 + 0.5),
    f32_to_u8(a * 255.0 + 0.5),
  )
}

///|
/// The colorspace used to interpret pixel values.
pub(all) enum ColorSpace {
  /// Linear RGB. The default.
  Linear
  /// Approximation of sRGB using a gamma of 2.0.
  Gamma2
  /// Approximation of sRGB using a gamma of 2.2.
  SimpleSRGB
  /// Full sRGB transfer function.
  FullSRGBGamma
} derive(Eq, Debug)

///|
pub impl Default for ColorSpace with fn default() {
  Linear
}

///|
fn ColorSpace::expand_channel(self : ColorSpace, x : Float) -> Float {
  match self {
    Linear => x
    // `NormalizedF32 * NormalizedF32` clamps.
    Gamma2 => @path.normalized_f32_clamped(x * x)
    SimpleSRGB => @path.normalized_f32_clamped(approx_powf(x, 2.2))
    FullSRGBGamma => {
      let x = if x <= 0.04045 {
        x / 12.92
      } else {
        approx_powf((x + 0.055) / 1.055, 2.4)
      }
      @path.normalized_f32_clamped(x)
    }
  }
}

///|
fn ColorSpace::expand_color(self : ColorSpace, color : Color) -> Color {
  {
    r: self.expand_channel(color.r),
    g: self.expand_channel(color.g),
    b: self.expand_channel(color.b),
    a: color.a,
  }
}

///|
fn ColorSpace::expand_stage(self : ColorSpace) -> Stage? {
  match self {
    Linear => None
    Gamma2 => Some(GammaExpand2)
    SimpleSRGB => Some(GammaExpand22)
    FullSRGBGamma => Some(GammaExpandSrgb)
  }
}

///|
fn ColorSpace::expand_dest_stage(self : ColorSpace) -> Stage? {
  match self {
    Linear => None
    Gamma2 => Some(GammaExpandDestination2)
    SimpleSRGB => Some(GammaExpandDestination22)
    FullSRGBGamma => Some(GammaExpandDestinationSrgb)
  }
}

///|
fn ColorSpace::compress_stage(self : ColorSpace) -> Stage? {
  match self {
    Linear => None
    Gamma2 => Some(GammaCompress2)
    SimpleSRGB => Some(GammaCompress22)
    FullSRGBGamma => Some(GammaCompressSrgb)
  }
}
