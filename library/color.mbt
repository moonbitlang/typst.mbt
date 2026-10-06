// Port of `typst-library/src/visualize/color.rs`.
//
// The color math follows the `palette` crate (see `palette.mbt`); all color
// components are `f32` (MoonBit `Float`) like upstream.

///|
/// A color in a specific color space.
///
/// Typst supports sRGB, device CMYK, D65 gray, Oklab, Oklch, linear RGB, HSL,
/// HSV and color spaces described by spot colorants.
pub(all) enum Color {
  /// A process color.
  Process(ProcessColor)
  /// A spot color.
  Spot(SpotColor)
}

///|
/// Colors with a well-defined color space.
pub(all) enum ProcessColor {
  /// A 32-bit luma color.
  Luma(Luma)
  /// A 32-bit L\*a\*b\* color in the Oklab color space.
  Oklab(Oklab)
  /// A 32-bit LCh color in the Oklab color space.
  Oklch(Oklch)
  /// A 32-bit RGB color.
  Rgb(Rgb)
  /// A 32-bit linear RGB color.
  LinearRgb(LinearRgb)
  /// A 32-bit CMYK color.
  Cmyk(Cmyk)
  /// A 32-bit HSL color.
  Hsl(Hsl)
  /// A 32-bit HSV color.
  Hsv(Hsv)
}

///|
/// An 8-bit CMYK color.
pub(all) struct Cmyk {
  /// The cyan component.
  c : Float
  /// The magenta component.
  m : Float
  /// The yellow component.
  y : Float
  /// The key (black) component.
  k : Float
} derive(Eq, Debug)

///|
/// A spot color.
pub(all) struct SpotColor {
  /// Which colorant to apply.
  colorant : SpotColorant
  /// How much of the colorant to apply to the medium.
  tint : Ratio
} derive(Eq)

///|
/// A spot colorant from which spot colors can be created.
pub(all) struct SpotColorant {
  /// Name of the spot colorant to use, if any.
  name : SpotColorantName?
  /// How to render this color if the specified colorant is not available.
  fallback : ProcessColor
} derive(Eq)

///|
/// The name of a spot colorant.
pub(all) enum SpotColorantName {
  /// The special `"all"` colorant that applies to all separation colorants.
  All
  /// A custom colorant name (e.g., `"PANTONE 2221 C"`).
  Custom(String)
} derive(Eq)

///|
/// A color space for color manipulation.
pub(all) enum ColorSpace {
  /// A mixable color space with a well-defined color model.
  Process(ProcessColorSpace)
  /// A spot colorant.
  Spot(SpotColorant)
} derive(Eq)

///|
/// A color space for color manipulation.
pub(all) enum ProcessColorSpace {
  /// The perceptual Oklab color space.
  Oklab
  /// The perceptual Oklch color space.
  Oklch
  /// The standard RGB color space.
  Srgb
  /// The D65-gray color space.
  D65Gray
  /// The linear RGB color space.
  LinearRgb
  /// The HSL color space.
  Hsl
  /// The HSV color space.
  Hsv
  /// The CMYK color space.
  Cmyk
} derive(Eq, Debug)

// Constants.

///|
fn luma_const(l : Float) -> Color {
  Process(Luma({ luma: l, alpha: 1.0, }))
}

///|
fn rgb_const(r : Float, g : Float, b : Float) -> Color {
  Process(Rgb({ red: r, green: g, blue: b, alpha: 1.0, }))
}

///|
pub let color_black : Color = luma_const(0.0)

///|
pub let color_gray : Color = luma_const(0.6666666)

///|
pub let color_white : Color = luma_const(1.0)

///|
pub let color_silver : Color = luma_const(0.8666667)

///|
pub let color_navy : Color = rgb_const(0.0, 0.121569, 0.247059)

///|
pub let color_blue : Color = rgb_const(0.0, 0.454902, 0.85098)

///|
pub let color_aqua : Color = rgb_const(0.4980392, 0.858823, 1.0)

///|
pub let color_teal : Color = rgb_const(0.223529, 0.8, 0.8)

///|
pub let color_eastern : Color = rgb_const(0.13725, 0.615686, 0.678431)

///|
pub let color_purple : Color = rgb_const(0.694118, 0.050980, 0.788235)

///|
pub let color_fuchsia : Color = rgb_const(0.941177, 0.070588, 0.745098)

///|
pub let color_maroon : Color = rgb_const(0.521569, 0.078431, 0.294118)

///|
pub let color_red : Color = rgb_const(1.0, 0.254902, 0.211765)

///|
pub let color_orange : Color = rgb_const(1.0, 0.521569, 0.105882)

///|
pub let color_yellow : Color = rgb_const(1.0, 0.8627451, 0.0)

///|
pub let color_olive : Color = rgb_const(0.239216, 0.6, 0.4392157)

///|
pub let color_green : Color = rgb_const(0.1803922, 0.8, 0.2509804)

///|
pub let color_lime : Color = rgb_const(0.0039216, 1.0, 0.4392157)

///|
fn impl_color_const_black() -> Value {
  Color(color_black)
}

///|
fn impl_color_const_gray() -> Value {
  Color(color_gray)
}

///|
fn impl_color_const_white() -> Value {
  Color(color_white)
}

///|
fn impl_color_const_silver() -> Value {
  Color(color_silver)
}

///|
fn impl_color_const_navy() -> Value {
  Color(color_navy)
}

///|
fn impl_color_const_blue() -> Value {
  Color(color_blue)
}

///|
fn impl_color_const_aqua() -> Value {
  Color(color_aqua)
}

///|
fn impl_color_const_teal() -> Value {
  Color(color_teal)
}

///|
fn impl_color_const_eastern() -> Value {
  Color(color_eastern)
}

///|
fn impl_color_const_purple() -> Value {
  Color(color_purple)
}

///|
fn impl_color_const_fuchsia() -> Value {
  Color(color_fuchsia)
}

///|
fn impl_color_const_maroon() -> Value {
  Color(color_maroon)
}

///|
fn impl_color_const_red() -> Value {
  Color(color_red)
}

///|
fn impl_color_const_orange() -> Value {
  Color(color_orange)
}

///|
fn impl_color_const_yellow() -> Value {
  Color(color_yellow)
}

///|
fn impl_color_const_olive() -> Value {
  Color(color_olive)
}

///|
fn impl_color_const_green() -> Value {
  Color(color_green)
}

///|
fn impl_color_const_lime() -> Value {
  Color(color_lime)
}

///|
let color_map_cell : Ref[Module?] = { val: None, }

///|
/// A collection of preset color maps that can be used for gradients.
fn impl_color_const_map() -> Value {
  match color_map_cell.val {
    Some(m) => Module(m)
    None => {
      let m = color_map()
      color_map_cell.val = Some(m)
      Module(m)
    }
  }
}

// Constructors.

///|
/// Create a grayscale color.
fn impl_color_luma(args : Args) -> Color raise SourceError {
  Process(
    Luma(
      match args.find() {
        Some((color : Color)) => color.to_luma()
        None => {
          let missing_lightness = args.is_empty()
          let Component(l) : Component = args.expect("lightness component") catch {
            SourceError(errs) => {
              if missing_lightness {
                // Before 0.16, lightness accidentally defaulted to `100%`,
                // so this should help with breakage.
                errs[errs.length() - 1].hint(
                  "try writing `white` or `luma(100%)`",
                )
              }
              raise SourceError(errs)
            }
          }
          let Component(alpha) : Component = args
            .eat()
            .unwrap_or(Component(Ratio::one()))
          { luma: f32_(l.get()), alpha: f32_(alpha.get()), }
        }
      },
    ),
  )
}

///|
/// Create an Oklab color.
fn impl_color_oklab(args : Args) -> Color raise SourceError {
  Process(
    Oklab(
      match args.find() {
        Some((color : Color)) => color.to_oklab()
        None => {
          let RatioComponent(l) : RatioComponent = args.expect(
            "lightness component",
          )
          let ChromaComponent(a) : ChromaComponent = args.expect("A component")
          let ChromaComponent(b) : ChromaComponent = args.expect("B component")
          let RatioComponent(alpha) : RatioComponent = args
            .eat()
            .unwrap_or(RatioComponent(Ratio::one()))
          { l: f32_(l.get()), a, b, alpha: f32_(alpha.get()), }
        }
      },
    ),
  )
}

///|
/// Create an Oklch color.
fn impl_color_oklch(args : Args) -> Color raise SourceError {
  Process(
    Oklch(
      match args.find() {
        Some((color : Color)) => color.to_oklch()
        None => {
          let RatioComponent(l) : RatioComponent = args.expect(
            "lightness component",
          )
          let ChromaComponent(c) : ChromaComponent = args.expect(
            "chroma component",
          )
          let h : Angle = args.expect("hue component")
          let RatioComponent(alpha) : RatioComponent = args
            .eat()
            .unwrap_or(RatioComponent(Ratio::one()))
          {
            l: f32_(l.get()),
            chroma: c,
            hue: f32_(h.to_deg()),
            alpha: f32_(alpha.get()),
          }
        }
      },
    ),
  )
}

///|
/// Create an RGB(A) color with linear luma.
fn impl_color_linear_rgb(args : Args) -> Color raise SourceError {
  Process(
    LinearRgb(
      match args.find() {
        Some((color : Color)) => color.to_linear_rgb()
        None => {
          let Component(r) : Component = args.expect("red component")
          let Component(g) : Component = args.expect("green component")
          let Component(b) : Component = args.expect("blue component")
          let Component(a) : Component = args
            .eat()
            .unwrap_or(Component(Ratio::one()))
          {
            red: f32_(r.get()),
            green: f32_(g.get()),
            blue: f32_(b.get()),
            alpha: f32_(a.get()),
          }
        }
      },
    ),
  )
}

///|
/// Create an RGB(A) color.
fn impl_color_rgb(args : Args) -> Color raise SourceError {
  match args_find_spanned_str(args) {
    Some(string) =>
      match ProcessColor::from_str(string.v) {
        Ok(c) => Process(c)
        Err(msg) => bail_at(string.span, msg)
      }
    None =>
      match args.find() {
        Some((color : Color)) => Process(Rgb(color.to_rgb()))
        None => {
          let Component(r) : Component = args.expect("red component")
          let Component(g) : Component = args.expect("green component")
          let Component(b) : Component = args.expect("blue component")
          let Component(a) : Component = args
            .eat()
            .unwrap_or(Component(Ratio::one()))
          Process(
            Rgb({
              red: f32_(r.get()),
              green: f32_(g.get()),
              blue: f32_(b.get()),
              alpha: f32_(a.get()),
            }),
          )
        }
      }
  }
}

///|
/// Create a CMYK color.
fn impl_color_cmyk(args : Args) -> Color raise SourceError {
  Process(
    Cmyk(
      match args.find() {
        Some((color : Color)) => color.to_cmyk()
        None => {
          let RatioComponent(c) : RatioComponent = args.expect("cyan component")
          let RatioComponent(m) : RatioComponent = args.expect(
            "magenta component",
          )
          let RatioComponent(y) : RatioComponent = args.expect(
            "yellow component",
          )
          let RatioComponent(k) : RatioComponent = args.expect(
            "key/black component",
          )
          {
            c: f32_(c.get()),
            m: f32_(m.get()),
            y: f32_(y.get()),
            k: f32_(k.get()),
          }
        }
      },
    ),
  )
}

///|
/// Create an HSL color.
fn impl_color_hsl(args : Args) -> Color raise SourceError {
  Process(
    Hsl(
      match args.find() {
        Some((color : Color)) => color.to_hsl()
        None => {
          let h : Angle = args.expect("hue component")
          let Component(s) : Component = args.expect("saturation component")
          let Component(l) : Component = args.expect("lightness component")
          let Component(a) : Component = args
            .eat()
            .unwrap_or(Component(Ratio::one()))
          {
            hue: f32_(h.to_deg()),
            saturation: f32_(s.get()),
            lightness: f32_(l.get()),
            alpha: f32_(a.get()),
          }
        }
      },
    ),
  )
}

///|
/// Create an HSV color.
fn impl_color_hsv(args : Args) -> Color raise SourceError {
  Process(
    Hsv(
      match args.find() {
        Some((color : Color)) => color.to_hsv()
        None => {
          let h : Angle = args.expect("hue component")
          let Component(s) : Component = args.expect("saturation component")
          let Component(v) : Component = args.expect("value component")
          let Component(a) : Component = args
            .eat()
            .unwrap_or(Component(Ratio::one()))
          {
            hue: f32_(h.to_deg()),
            saturation: f32_(s.get()),
            value: f32_(v.get()),
            alpha: f32_(a.get()),
          }
        }
      },
    ),
  )
}

// Methods.

///|
/// Extracts the components of this color.
fn impl_color_components(self_ : Color, alpha_ : Bool) -> Arr {
  match self_ {
    Process(c) => c.components(alpha_)
    Spot(c) => Arr::from_array([Ratio(c.tint)])
  }
}

///|
/// Returns the constructor function for this color's space.
fn impl_color_space(self_ : Color) -> ColorSpace {
  self_.space()
}

///|
/// Returns the color's RGB(A) hex representation.
fn impl_color_to_hex(self_ : Color) -> String {
  match self_ {
    Process(c) => c.to_hex()
    Spot(c) => c.fallback().to_hex()
  }
}

///|
/// Lightens a color by a given factor.
fn impl_color_lighten(self_ : Color, factor_ : Ratio) -> Color {
  match self_ {
    Process(c) => Process(c.lighten(factor_))
    Spot(c) => Spot(c.lighten(factor_))
  }
}

///|
/// Darkens a color by a given factor.
fn impl_color_darken(self_ : Color, factor_ : Ratio) -> Color {
  match self_ {
    Process(c) => Process(c.darken(factor_))
    Spot(c) => Spot(c.darken(factor_))
  }
}

///|
/// Increases the saturation of a color by a given factor.
fn impl_color_saturate(
  self_ : Color,
  span : @syntax.Span,
  factor_ : Ratio,
) -> Color raise SourceError {
  match self_ {
    Process(c) => Process(c.saturate(span, factor_))
    Spot(_) =>
      bail_at(span, "cannot saturate spot color", hints=[
        "try using the fallback color instead",
      ])
  }
}

///|
/// Decreases the saturation of a color by a given factor.
fn impl_color_desaturate(
  self_ : Color,
  span : @syntax.Span,
  factor_ : Ratio,
) -> Color raise SourceError {
  match self_ {
    Process(c) => Process(c.desaturate(span, factor_))
    Spot(_) =>
      bail_at(span, "cannot desaturate spot color", hints=[
        "try using the fallback color instead",
      ])
  }
}

///|
fn impl_color_negate__space_default() -> Smart[ColorSpace] {
  Auto
}

///|
/// Produces the complementary color using a provided color space.
fn impl_color_negate(
  self_ : Color,
  space_ : Smart[ColorSpace],
) -> Color raise HintedError {
  let target_space = space_.unwrap_or_else(() => {
    match self_.space() {
      Process(_) => Process(Oklab)
      Spot(s) => Spot(s)
    }
  })
  let result = match self_.to_space(target_space) {
    Process(c) => Color::Process(c.negate(c.space()))
    Spot(c) => Color::Spot(c.negate())
  }
  result.to_space(self_.space())
}

///|
fn impl_color_rotate__space_default() -> ProcessColorSpace {
  Oklch
}

///|
/// Rotates the hue of the color by a given angle.
fn impl_color_rotate(
  self_ : Color,
  span : @syntax.Span,
  angle_ : Angle,
  space_ : ProcessColorSpace,
) -> Color raise SourceError {
  let amount = f32_(angle_.to_deg())
  match space_ {
    Oklch => {
      let oklch = self_.to_oklch()
      let rotated = { ..oklch, hue: oklch.hue + amount, }
      at(span, () => Color::Process(Oklch(rotated)).to_space(self_.space()))
    }
    Hsl => {
      let hsl = self_.to_hsl()
      let rotated = { ..hsl, hue: hsl.hue + amount, }
      at(span, () => Color::Process(Hsl(rotated)).to_space(self_.space()))
    }
    Hsv => {
      let hsv = self_.to_hsv()
      let rotated = { ..hsv, hue: hsv.hue + amount, }
      at(span, () => Color::Process(Hsv(rotated)).to_space(self_.space()))
    }
    _ => bail_at(span, "this color space does not support hue rotation")
  }
}

///|
fn impl_color_mix__space_default() -> Smart[ColorSpace] {
  Auto
}

///|
/// Create a color by mixing two or more colors.
fn impl_color_mix(
  colors_ : Array[WeightedColor],
  space_ : Smart[ColorSpace],
) -> Color raise HintedError {
  Color::mix_iter(colors_, space_)
}

///|
/// Makes a color more transparent by a given factor.
fn impl_color_transparentize(
  self_ : Color,
  scale_ : Ratio,
) -> Color raise HintedError {
  self_.scale_alpha(Ratio::new(-scale_.get()))
}

///|
/// Makes a color more opaque by a given scale.
fn impl_color_opacify(self_ : Color, scale_ : Ratio) -> Color raise HintedError {
  self_.scale_alpha(scale_)
}

///|
/// Same as `color.mix`, but takes an array of weighted colors.
pub fn Color::mix_iter(
  colors : Array[WeightedColor],
  space : Smart[ColorSpace],
) -> Color raise HintedError {
  let space = resolve_color_space(space, colors.map(wc => wc.color))
  let hue_index = space.hue_index()
  if hue_index is Some(_) && colors.length() > 2 {
    bail("cannot mix more than two colors in a hue-based space")
  }
  let m : FixedArray[Float] = if hue_index is Some(index) &&
    colors.length() == 2 {
    let m : FixedArray[Float] = FixedArray::make(4, 0.0)
    let { color: c0, weight: w0, } = colors[0]
    let { color: c1, weight: w1, } = colors[1]
    let c0 = c0.to_space(space).to_vec4()
    let c1 = c1.to_space(space).to_vec4()
    let w0 = f32_(w0)
    let w1 = f32_(w1)
    if w0 + w1 <= 0.0 {
      bail("sum of weights must be positive")
    }
    for i in 0..<4 {
      m[i] = (w0 * c0[i] + w1 * c1[i]) / (w0 + w1)
    }
    // Ensure that the hue circle is traversed in the short direction.
    if (c0[index] - c1[index]).abs() > 180.0 {
      let (h0, h1) = if c0[index] < c1[index] {
        (c0[index] + 360.0, c1[index])
      } else {
        (c0[index], c1[index] + 360.0)
      }
      m[index] = (w0 * h0 + w1 * h1) / (w0 + w1)
    }
    m
  } else {
    let mut total : Float = 0.0
    let acc : FixedArray[Float] = FixedArray::make(4, 0.0)
    for wc in colors {
      let weight = f32_(wc.weight)
      let v = wc.color.to_space(space).to_vec4()
      acc[0] += weight * v[0]
      acc[1] += weight * v[1]
      acc[2] += weight * v[2]
      acc[3] += weight * v[3]
      total += weight
    }
    if total <= 0.0 {
      bail("sum of weights must be positive")
    }
    FixedArray::makei(4, i => acc[i] / total)
  }
  match space {
    Process(Oklab) =>
      Process(Oklab({ l: m[0], a: m[1], b: m[2], alpha: m[3], }))
    Process(Oklch) =>
      Process(Oklch({ l: m[0], chroma: m[1], hue: m[2], alpha: m[3], }))
    Process(Srgb) =>
      Process(Rgb({ red: m[0], green: m[1], blue: m[2], alpha: m[3], }))
    Process(LinearRgb) =>
      Process(LinearRgb({ red: m[0], green: m[1], blue: m[2], alpha: m[3], }))
    Process(Hsl) =>
      Process(
        Hsl({ hue: m[0], saturation: m[1], lightness: m[2], alpha: m[3], }),
      )
    Process(Hsv) =>
      Process(Hsv({ hue: m[0], saturation: m[1], value: m[2], alpha: m[3], }))
    Process(Cmyk) => Process(Cmyk({ c: m[0], m: m[1], y: m[2], k: m[3], }))
    Process(D65Gray) => Process(Luma({ luma: m[0], alpha: m[3], }))
    Spot(colorant) =>
      Spot({
        colorant,
        tint: Ratio::new(f32_clamp(m[0], 0.0, 1.0).to_double()),
      })
  }
}

///|
/// Construct a new RGBA color from 8-bit values.
pub fn Color::from_u8(r : Int, g : Int, b : Int, a : Int) -> Color {
  Process(ProcessColor::from_u8(r, g, b, a))
}

///|
/// Converts a 32-bit integer to an RGBA color.
pub fn Color::from_u32(color : UInt) -> Color {
  Process(ProcessColor::from_u32(color))
}

///|
/// Returns the alpha channel of the color, if it has one.
pub fn Color::alpha(self : Color) -> Float? {
  match self {
    Process(c) => c.alpha()
    Spot(_) => None
  }
}

///|
/// Sets the alpha channel of the color, if it has one.
pub fn Color::with_alpha(self : Color, alpha : Float) -> Color {
  match self {
    Process(c) => Process(c.with_alpha(alpha))
    Spot(_) => self
  }
}

///|
/// Scales the alpha value of a color by a given amount.
fn Color::scale_alpha(self : Color, scale : Ratio) -> Color raise HintedError {
  match self {
    Process(c) => Process(c.scale_alpha(scale))
    Spot(_) => bail("spot colors do not have an alpha component")
  }
}

///|
/// Converts the color to a vec of four floats.
pub fn Color::to_vec4(self : Color) -> FixedArray[Float] {
  match self {
    Process(c) => c.to_vec4()
    Spot(c) => {
      let t = f32_(c.tint.get())
      [t, t, t, t]
    }
  }
}

///|
/// Converts the color to a vec of four `u8`s.
pub fn Color::to_vec4_u8(self : Color) -> FixedArray[Int] {
  self.to_vec4().map(f32_to_u8_round)
}

///|
/// Convert the color into another color space.
pub fn Color::to_space(
  self : Color,
  space : ColorSpace,
) -> Color raise HintedError {
  match (space, self) {
    (Process(s), Process(c)) => Process(c.to_space(s))
    (Process(s), Spot(c)) => Process(c.fallback().to_space(s))
    (Spot(s), Spot(c)) =>
      if s == c.colorant {
        self
      } else {
        bail_hinted("cannot convert spot color to different spot colorant", [
          "colorant of the color is `\{repr_opt_spot_name(c.colorant.name)}`",
          "colorant of the color space is `\{repr_opt_spot_name(s.name)}`",
        ])
      }
    (Spot(s), Process(_)) =>
      bail_hinted("cannot convert process color to spot colorant space", [
        "process color cannot be expressed in spot colorant `\{repr_opt_spot_name(s.name)}`",
        "try converting the spot color to the process space instead",
      ])
  }
}

///|
/// Convert the color into a process color space.
pub fn Color::to_process_space(
  self : Color,
  space : ProcessColorSpace,
) -> Color {
  Process(self.to_process().to_space(space))
}

///|
pub fn Color::to_luma(self : Color) -> Luma {
  self.to_process().to_luma()
}

///|
pub fn Color::to_oklab(self : Color) -> Oklab {
  self.to_process().to_oklab()
}

///|
pub fn Color::to_oklch(self : Color) -> Oklch {
  self.to_process().to_oklch()
}

///|
pub fn Color::to_rgb(self : Color) -> Rgb {
  self.to_process().to_rgb()
}

///|
pub fn Color::to_linear_rgb(self : Color) -> LinearRgb {
  self.to_process().to_linear_rgb()
}

///|
pub fn Color::to_cmyk(self : Color) -> Cmyk {
  self.to_process().to_cmyk()
}

///|
pub fn Color::to_hsl(self : Color) -> Hsl {
  self.to_process().to_hsl()
}

///|
pub fn Color::to_hsv(self : Color) -> Hsv {
  self.to_process().to_hsv()
}

///|
/// Convert to `ProcessColor`, using the fallback for spot colors.
pub fn Color::to_process(self : Color) -> ProcessColor {
  match self {
    Process(c) => c
    Spot(c) => c.fallback()
  }
}

///|
/// Returns the color space of this color.
pub fn Color::space(self : Color) -> ColorSpace {
  match self {
    Process(c) => Process(c.space())
    Spot(c) => Spot(c.colorant)
  }
}

///|
pub fn Color::repr(self : Color) -> String {
  match self {
    Process(c) => c.repr()
    Spot(c) => c.repr()
  }
}

///|
pub impl Eq for Color with fn equal(self, other) {
  match (self, other) {
    (Process(a), Process(b)) => a == b
    (Spot(a), Spot(b)) => a == b
    _ => false
  }
}

///|
pub impl Hash for Color with fn hash_combine(self, hasher) {
  match self {
    Process(c) => {
      hasher.combine_int(0)
      c.hash_combine(hasher)
    }
    Spot(c) => {
      hasher.combine_int(1)
      c.colorant.hash_combine(hasher)
      hasher.combine_double(c.tint.get())
    }
  }
}

///|
/// Constructs a new color from hex strings like `#aef`, `7a03c2` or
/// `abcdefff`.
pub fn Color::from_str(s : String) -> Result[Color, String] {
  match ProcessColor::from_str(s) {
    Ok(c) => Ok(Process(c))
    Err(e) => Err(e)
  }
}

// ProcessColor.

///|
/// Extracts the components of this color.
pub fn ProcessColor::components(self : ProcessColor, alpha : Bool) -> Arr {
  let ratio = (x : Float) => Value::Ratio(Ratio::new(x.to_double()))
  let components : Array[Value] = match self {
    Luma(c) => [ratio(c.luma), ratio(c.alpha)]
    Oklab(c) =>
      [
        ratio(c.l),
        Float(c.a.to_double()),
        Float(c.b.to_double()),
        ratio(c.alpha),
      ]
    Oklch(c) =>
      [
        ratio(c.l),
        Float(c.chroma.to_double()),
        Angle(hue_angle(normalize_signed_angle(c.hue))),
        ratio(c.alpha),
      ]
    LinearRgb(c) =>
      [ratio(c.red), ratio(c.green), ratio(c.blue), ratio(c.alpha)]
    Rgb(c) => [ratio(c.red), ratio(c.green), ratio(c.blue), ratio(c.alpha)]
    Cmyk(c) => [ratio(c.c), ratio(c.m), ratio(c.y), ratio(c.k)]
    Hsl(c) =>
      [
        Angle(hue_angle(normalize_signed_angle(c.hue))),
        ratio(c.saturation),
        ratio(c.lightness),
        ratio(c.alpha),
      ]
    Hsv(c) =>
      [
        Angle(hue_angle(normalize_signed_angle(c.hue))),
        ratio(c.saturation),
        ratio(c.value),
        ratio(c.alpha),
      ]
  }
  // Remove the alpha component if the corresponding argument was set.
  if !alpha && !(self is Cmyk(_)) {
    components.pop() |> ignore
  }
  Arr::from_array(components)
}

///|
/// Returns the color's RGB(A) hex representation.
pub fn ProcessColor::to_hex(self : ProcessColor) -> String {
  let c = self.to_rgb()
  let r = f32_to_u8_stimulus(c.red)
  let g = f32_to_u8_stimulus(c.green)
  let b = f32_to_u8_stimulus(c.blue)
  let a = f32_to_u8_stimulus(c.alpha)
  if a != 255 {
    "#" + hex2(r) + hex2(g) + hex2(b) + hex2(a)
  } else {
    "#" + hex2(r) + hex2(g) + hex2(b)
  }
}

///|
fn hex2(x : Int) -> String {
  let digits = "0123456789abcdef"
  let s = StringBuilder()
  s.write_char(digits[x / 16].unsafe_to_char())
  s.write_char(digits[x % 16].unsafe_to_char())
  s.to_string()
}

///|
/// Palette's `f32` to `u8` stimulus conversion (`into_format`): scales by
/// 255, clamps and rounds half to even.
fn f32_to_u8_stimulus(x : Float) -> Int {
  let max : Float = 255.0
  let scaled = f32_min(x * max, max)
  let f = scaled + Float::reinterpret_from_uint(0x4b00_0000)
  let bits = f.reinterpret_as_uint()
  let c23 : UInt = 0x4b00_0000
  let v = if bits < c23 { 0U } else { bits - c23 }
  (v & 0xff).reinterpret_as_int()
}

///|
/// Rust `(x * 255.0).round() as u8`.
fn f32_to_u8_round(x : Float) -> Int {
  let v = rust_round((x * 255.0).to_double())
  if v.is_nan() || v <= 0.0 {
    0
  } else if v >= 255.0 {
    255
  } else {
    v.to_int()
  }
}

///|
/// Returns the constructor function for this color's space.
pub fn ProcessColor::space(self : ProcessColor) -> ProcessColorSpace {
  match self {
    Luma(_) => D65Gray
    Oklab(_) => Oklab
    Oklch(_) => Oklch
    LinearRgb(_) => LinearRgb
    Rgb(_) => Srgb
    Cmyk(_) => Cmyk
    Hsl(_) => Hsl
    Hsv(_) => Hsv
  }
}

///|
/// Lightens a color by a given factor.
pub fn ProcessColor::lighten(
  self : ProcessColor,
  factor : Ratio,
) -> ProcessColor {
  let factor = f32_(factor.get())
  match self {
    Luma(c) => Luma(c.lighten(factor))
    Oklab(c) => Oklab(c.lighten(factor))
    Oklch(c) => Oklch(c.lighten(factor))
    LinearRgb(c) => LinearRgb(c.lighten(factor))
    Rgb(c) => Rgb(c.lighten(factor))
    Cmyk(c) => Cmyk(c.lighten(factor))
    Hsl(c) => Hsl(c.lighten(factor))
    Hsv(c) => Hsv(c.lighten(factor))
  }
}

///|
/// Darkens a color by a given factor.
pub fn ProcessColor::darken(
  self : ProcessColor,
  factor : Ratio,
) -> ProcessColor {
  let factor = f32_(factor.get())
  match self {
    Luma(c) => Luma(c.lighten(-factor))
    Oklab(c) => Oklab(c.lighten(-factor))
    Oklch(c) => Oklch(c.lighten(-factor))
    LinearRgb(c) => LinearRgb(c.lighten(-factor))
    Rgb(c) => Rgb(c.lighten(-factor))
    Cmyk(c) => Cmyk(c.darken(factor))
    Hsl(c) => Hsl(c.lighten(-factor))
    Hsv(c) => Hsv(c.lighten(-factor))
  }
}

///|
/// Increases the saturation of a color by a given factor.
pub fn ProcessColor::saturate(
  self : ProcessColor,
  span : @syntax.Span,
  factor : Ratio,
) -> ProcessColor raise SourceError {
  let f = f32_(factor.get())
  match self {
    Luma(_) =>
      bail_at(span, "cannot saturate grayscale color", hints=[
        "try converting your color to RGB first",
      ])
    Hsl(c) => Hsl(c.saturate(f))
    Hsv(c) => Hsv(c.saturate(f))
    Oklab(_) | Oklch(_) | LinearRgb(_) | Rgb(_) | Cmyk(_) =>
      ProcessColor::Hsv(self.to_hsv().saturate(f)).to_space(self.space())
  }
}

///|
/// Decreases the saturation of a color by a given factor.
pub fn ProcessColor::desaturate(
  self : ProcessColor,
  span : @syntax.Span,
  factor : Ratio,
) -> ProcessColor raise SourceError {
  let f = f32_(factor.get())
  match self {
    Luma(_) =>
      bail_at(span, "cannot desaturate grayscale color", hints=[
        "try converting your color to RGB first",
      ])
    Hsl(c) => Hsl(c.saturate(-f))
    Hsv(c) => Hsv(c.saturate(-f))
    Oklab(_) | Oklch(_) | LinearRgb(_) | Rgb(_) | Cmyk(_) =>
      ProcessColor::Hsv(self.to_hsv().saturate(-f)).to_space(self.space())
  }
}

///|
/// Produces the complementary color using a provided color space.
pub fn ProcessColor::negate(
  self : ProcessColor,
  space : ProcessColorSpace,
) -> ProcessColor {
  let result : ProcessColor = match self.to_space(space) {
    Luma(c) => Luma({ luma: 1.0 - c.luma, alpha: c.alpha, })
    Oklab(c) => Oklab({ l: 1.0 - c.l, a: -c.a, b: -c.b, alpha: c.alpha, })
    Oklch(c) =>
      Oklch({
        l: 1.0 - c.l,
        chroma: c.chroma,
        hue: normalize_signed_angle(c.hue) + 180.0,
        alpha: c.alpha,
      })
    LinearRgb(c) =>
      LinearRgb({
        red: 1.0 - c.red,
        green: 1.0 - c.green,
        blue: 1.0 - c.blue,
        alpha: c.alpha,
      })
    Rgb(c) =>
      Rgb({
        red: 1.0 - c.red,
        green: 1.0 - c.green,
        blue: 1.0 - c.blue,
        alpha: c.alpha,
      })
    Cmyk(c) => Cmyk({ c: 1.0 - c.c, m: 1.0 - c.m, y: 1.0 - c.y, k: c.k, })
    Hsl(c) =>
      Hsl({
        hue: normalize_signed_angle(c.hue) + 180.0,
        saturation: c.saturation,
        lightness: c.lightness,
        alpha: c.alpha,
      })
    Hsv(c) =>
      Hsv({
        hue: normalize_signed_angle(c.hue) + 180.0,
        saturation: c.saturation,
        value: c.value,
        alpha: c.alpha,
      })
  }
  result.to_space(self.space())
}

///|
/// Construct a new RGBA color from 8-bit values.
pub fn ProcessColor::from_u8(
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> ProcessColor {
  Rgb({
    red: Float::from_int(r) / 255.0,
    green: Float::from_int(g) / 255.0,
    blue: Float::from_int(b) / 255.0,
    alpha: Float::from_int(a) / 255.0,
  })
}

///|
/// Converts a 32-bit integer to an RGBA color.
pub fn ProcessColor::from_u32(color : UInt) -> ProcessColor {
  ProcessColor::from_u8(
    ((color >> 24) & 0xFF).reinterpret_as_int(),
    ((color >> 16) & 0xFF).reinterpret_as_int(),
    ((color >> 8) & 0xFF).reinterpret_as_int(),
    (color & 0xFF).reinterpret_as_int(),
  )
}

///|
/// Returns the alpha channel of the color, if it has one.
pub fn ProcessColor::alpha(self : ProcessColor) -> Float? {
  match self {
    Cmyk(_) => None
    Luma(c) => Some(c.alpha)
    Oklab(c) => Some(c.alpha)
    Oklch(c) => Some(c.alpha)
    Rgb(c) => Some(c.alpha)
    LinearRgb(c) => Some(c.alpha)
    Hsl(c) => Some(c.alpha)
    Hsv(c) => Some(c.alpha)
  }
}

///|
/// Sets the alpha channel of the color, if it has one.
pub fn ProcessColor::with_alpha(
  self : ProcessColor,
  alpha : Float,
) -> ProcessColor {
  match self {
    Cmyk(_) => self
    Luma(c) => Luma({ ..c, alpha, })
    Oklab(c) => Oklab({ ..c, alpha, })
    Oklch(c) => Oklch({ ..c, alpha, })
    Rgb(c) => Rgb({ ..c, alpha, })
    LinearRgb(c) => LinearRgb({ ..c, alpha, })
    Hsl(c) => Hsl({ ..c, alpha, })
    Hsv(c) => Hsv({ ..c, alpha, })
  }
}

///|
/// Scales the alpha value of a color by a given amount.
///
/// For positive scales, computes `alpha + scale - alpha * scale`.
/// For non-positive scales, computes `alpha + alpha * scale`.
fn ProcessColor::scale_alpha(
  self : ProcessColor,
  scale : Ratio,
) -> ProcessColor raise HintedError {
  let transform = (alpha : Float) => {
    let scale = f32_(scale.get())
    let factor = if scale > 0.0 { (1.0 : Float) - alpha } else { alpha }
    f32_clamp(alpha + scale * factor, 0.0, 1.0)
  }
  match self {
    Cmyk(_) => bail("CMYK does not have an alpha component")
    Luma(c) => Luma({ ..c, alpha: transform(c.alpha), })
    Oklab(c) => Oklab({ ..c, alpha: transform(c.alpha), })
    Oklch(c) => Oklch({ ..c, alpha: transform(c.alpha), })
    Rgb(c) => Rgb({ ..c, alpha: transform(c.alpha), })
    LinearRgb(c) => LinearRgb({ ..c, alpha: transform(c.alpha), })
    Hsl(c) => Hsl({ ..c, alpha: transform(c.alpha), })
    Hsv(c) => Hsv({ ..c, alpha: transform(c.alpha), })
  }
}

///|
/// Converts the color to a vec of four floats.
pub fn ProcessColor::to_vec4(self : ProcessColor) -> FixedArray[Float] {
  match self {
    Luma(c) => [c.luma, c.luma, c.luma, c.alpha]
    Oklab(c) => [c.l, c.a, c.b, c.alpha]
    Oklch(c) =>
      [
        c.l,
        c.chroma,
        f32_rem_euclid(normalize_signed_angle(c.hue), 360.0),
        c.alpha,
      ]
    Rgb(c) => [c.red, c.green, c.blue, c.alpha]
    LinearRgb(c) => [c.red, c.green, c.blue, c.alpha]
    Cmyk(c) => [c.c, c.m, c.y, c.k]
    Hsl(c) =>
      [
        f32_rem_euclid(normalize_signed_angle(c.hue), 360.0),
        c.saturation,
        c.lightness,
        c.alpha,
      ]
    Hsv(c) =>
      [
        f32_rem_euclid(normalize_signed_angle(c.hue), 360.0),
        c.saturation,
        c.value,
        c.alpha,
      ]
  }
}

///|
/// Converts the color to a vec of four `u8`s.
pub fn ProcessColor::to_vec4_u8(self : ProcessColor) -> FixedArray[Int] {
  self.to_vec4().map(f32_to_u8_round)
}

///|
/// Convert the color into a color space.
pub fn ProcessColor::to_space(
  self : ProcessColor,
  space : ProcessColorSpace,
) -> ProcessColor {
  match space {
    D65Gray => Luma(self.to_luma())
    Oklab => Oklab(self.to_oklab())
    Oklch => Oklch(self.to_oklch())
    Srgb => Rgb(self.to_rgb())
    LinearRgb => LinearRgb(self.to_linear_rgb())
    Cmyk => Cmyk(self.to_cmyk())
    Hsl => Hsl(self.to_hsl())
    Hsv => Hsv(self.to_hsv())
  }
}

///|
pub fn ProcessColor::to_luma(self : ProcessColor) -> Luma {
  match self {
    Luma(c) => c
    Oklab(c) => Luma::from_oklab(c)
    Oklch(c) => Luma::from_oklch(c)
    Rgb(c) => Luma::from_rgb(c)
    LinearRgb(c) => Luma::from_linear_rgb(c)
    Cmyk(c) => Luma::from_rgb(c.to_rgba())
    Hsl(c) => Luma::from_hsl(c)
    Hsv(c) => Luma::from_hsv(c)
  }
}

///|
pub fn ProcessColor::to_oklab(self : ProcessColor) -> Oklab {
  match self {
    Luma(c) => Oklab::from_luma(c)
    Oklab(c) => c
    Oklch(c) => Oklab::from_oklch(c)
    Rgb(c) => Oklab::from_rgb(c)
    LinearRgb(c) => Oklab::from_linear_rgb(c)
    Cmyk(c) => Oklab::from_rgb(c.to_rgba())
    Hsl(c) => Oklab::from_hsl(c)
    Hsv(c) => Oklab::from_hsv(c)
  }
}

///|
pub fn ProcessColor::to_oklch(self : ProcessColor) -> Oklch {
  match self {
    Luma(c) => Oklch::from_luma(c)
    Oklab(c) => Oklch::from_oklab(c)
    Oklch(c) => c
    Rgb(c) => Oklch::from_rgb(c)
    LinearRgb(c) => Oklch::from_linear_rgb(c)
    Cmyk(c) => Oklch::from_rgb(c.to_rgba())
    Hsl(c) => Oklch::from_hsl(c)
    Hsv(c) => Oklch::from_hsv(c)
  }
}

///|
pub fn ProcessColor::to_rgb(self : ProcessColor) -> Rgb {
  match self {
    Luma(c) => Rgb::from_luma(c)
    Oklab(c) => Rgb::from_oklab(c)
    Oklch(c) => Rgb::from_oklch(c)
    Rgb(c) => c
    LinearRgb(c) => Rgb::from_linear(c)
    Cmyk(c) => Rgb::from_rgb(c.to_rgba())
    Hsl(c) => Rgb::from_hsl(c)
    Hsv(c) => Rgb::from_hsv(c)
  }
}

///|
pub fn ProcessColor::to_linear_rgb(self : ProcessColor) -> LinearRgb {
  match self {
    Luma(c) => LinearRgb::from_luma(c)
    Oklab(c) => LinearRgb::from_oklab(c)
    Oklch(c) => LinearRgb::from_oklch(c)
    Rgb(c) => LinearRgb::from_rgb(c)
    LinearRgb(c) => c
    Cmyk(c) => LinearRgb::from_rgb(c.to_rgba())
    Hsl(c) => Rgb::from_hsl(c).to_linear()
    Hsv(c) => Rgb::from_hsv(c).to_linear()
  }
}

///|
pub fn ProcessColor::to_cmyk(self : ProcessColor) -> Cmyk {
  match self {
    Luma(c) => Cmyk::from_luma(c)
    Oklab(c) => Cmyk::from_rgba(Rgb::from_oklab(c))
    Oklch(c) => Cmyk::from_rgba(Rgb::from_oklch(c))
    Rgb(c) => Cmyk::from_rgba(c)
    LinearRgb(c) => Cmyk::from_rgba(Rgb::from_linear(c))
    Cmyk(c) => c
    Hsl(c) => Cmyk::from_rgba(Rgb::from_hsl(c))
    Hsv(c) => Cmyk::from_rgba(Rgb::from_hsv(c))
  }
}

///|
pub fn ProcessColor::to_hsl(self : ProcessColor) -> Hsl {
  match self {
    Luma(c) => Hsl::from_luma(c)
    Oklab(c) => Hsl::from_oklab(c)
    Oklch(c) => Hsl::from_oklch(c)
    Rgb(c) => Hsl::from_rgb(c)
    LinearRgb(c) => Hsl::from_rgb(Rgb::from_linear(c))
    Cmyk(c) => Hsl::from_rgb(c.to_rgba())
    Hsl(c) => c
    Hsv(c) => Hsl::from_hsv(c)
  }
}

///|
pub fn ProcessColor::to_hsv(self : ProcessColor) -> Hsv {
  match self {
    Luma(c) => Hsv::from_luma(c)
    Oklab(c) => Hsv::from_oklab(c)
    Oklch(c) => Hsv::from_oklch(c)
    Rgb(c) => Hsv::from_rgb(c)
    LinearRgb(c) => Hsv::from_rgb(Rgb::from_linear(c))
    Cmyk(c) => Hsv::from_rgb(c.to_rgba())
    Hsl(c) => Hsv::from_hsl(c)
    Hsv(c) => c
  }
}

///|
/// The ratio repr of an `f32` component.
fn ratio_repr32(x : Float) -> String {
  Ratio::new(x.to_double()).repr()
}

///|
/// The repr of an `f32` hue in degrees.
fn hue_repr32(hue : Float) -> String {
  hue_angle(normalize_signed_angle(hue)).repr()
}

///|
pub fn ProcessColor::repr(self : ProcessColor) -> String {
  match self {
    Luma(c) =>
      if c.alpha == 1.0 {
        "luma(\{ratio_repr32(c.luma)})"
      } else {
        "luma(\{ratio_repr32(c.luma)}, \{ratio_repr32(c.alpha)})"
      }
    Rgb(_) => "rgb(\{repr_str(self.to_hex())})"
    LinearRgb(c) =>
      if c.alpha == 1.0 {
        "color.linear-rgb(\{ratio_repr32(c.red)}, \{ratio_repr32(c.green)}, \{ratio_repr32(c.blue)})"
      } else {
        "color.linear-rgb(\{ratio_repr32(c.red)}, \{ratio_repr32(c.green)}, \{ratio_repr32(c.blue)}, \{ratio_repr32(c.alpha)})"
      }
    Cmyk(c) =>
      "cmyk(\{ratio_repr32(c.c)}, \{ratio_repr32(c.m)}, \{ratio_repr32(c.y)}, \{ratio_repr32(c.k)})"
    Oklab(c) =>
      if c.alpha == 1.0 {
        "oklab(\{ratio_repr32(c.l)}, \{format_float_component(c.a.to_double())}, \{format_float_component(c.b.to_double())})"
      } else {
        "oklab(\{ratio_repr32(c.l)}, \{format_float_component(c.a.to_double())}, \{format_float_component(c.b.to_double())}, \{ratio_repr32(c.alpha)})"
      }
    Oklch(c) =>
      if c.alpha == 1.0 {
        "oklch(\{ratio_repr32(c.l)}, \{format_float_component(c.chroma.to_double())}, \{hue_repr32(c.hue)})"
      } else {
        "oklch(\{ratio_repr32(c.l)}, \{format_float_component(c.chroma.to_double())}, \{hue_repr32(c.hue)}, \{ratio_repr32(c.alpha)})"
      }
    Hsl(c) =>
      if c.alpha == 1.0 {
        "color.hsl(\{hue_repr32(c.hue)}, \{ratio_repr32(c.saturation)}, \{ratio_repr32(c.lightness)})"
      } else {
        "color.hsl(\{hue_repr32(c.hue)}, \{ratio_repr32(c.saturation)}, \{ratio_repr32(c.lightness)}, \{ratio_repr32(c.alpha)})"
      }
    Hsv(c) =>
      if c.alpha == 1.0 {
        "color.hsv(\{hue_repr32(c.hue)}, \{ratio_repr32(c.saturation)}, \{ratio_repr32(c.value)})"
      } else {
        "color.hsv(\{hue_repr32(c.hue)}, \{ratio_repr32(c.saturation)}, \{ratio_repr32(c.value)}, \{ratio_repr32(c.alpha)})"
      }
  }
}

///|
pub impl Eq for ProcessColor with fn equal(self, other) {
  match (self, other) {
    // Lower precision for comparison to avoid rounding errors.
    // Keeps backward compatibility with previous versions of Typst.
    (Rgb(_), Rgb(_)) => {
      let a = self.to_vec4_u8()
      let b = other.to_vec4_u8()
      a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3]
    }
    (Luma(a), Luma(b)) => f32_to_u8_round(a.luma) == f32_to_u8_round(b.luma)
    (Oklab(a), Oklab(b)) => a == b
    (Oklch(a), Oklch(b)) => a == b
    (LinearRgb(a), LinearRgb(b)) => a == b
    (Cmyk(a), Cmyk(b)) => a == b
    (Hsl(a), Hsl(b)) => a == b
    (Hsv(a), Hsv(b)) => a == b
    _ => false
  }
}

///|
pub impl Hash for ProcessColor with fn hash_combine(self, hasher) {
  hasher.combine_int(
    match self {
      Luma(_) => 0
      Oklab(_) => 1
      Oklch(_) => 2
      Rgb(_) => 3
      LinearRgb(_) => 4
      Cmyk(_) => 5
      Hsl(_) => 6
      Hsv(_) => 7
    },
  )
  for x in self.to_vec4() {
    hasher.combine_uint(x.reinterpret_as_uint())
  }
}

///|
/// Constructs a new color from hex strings like the following:
/// - `#aef` (shorthand, with leading hash),
/// - `7a03c2` (without alpha),
/// - `abcdefff` (with alpha).
///
/// The hash is optional and both lower and upper case are fine.
pub fn ProcessColor::from_str(hex_str : String) -> Result[ProcessColor, String] {
  let hex_str = if hex_str.has_prefix("#") {
    hex_str.unsafe_substring(start=1, end=hex_str.length())
  } else {
    hex_str
  }
  for ch in hex_str {
    if !(ch is ('0'..='9' | 'a'..='f' | 'A'..='F')) {
      return Err("color string contains non-hexadecimal letters")
    }
  }
  let len = hex_str.length()
  let long = len == 6 || len == 8
  let short = len == 3 || len == 4
  let alpha = len == 4 || len == 8
  if !long && !short {
    return Err("color string has wrong length")
  }
  let values : FixedArray[Int] = [255, 255, 255, 255]
  let digit = (i : Int) => {
    let ch = hex_str[i].to_int()
    if ch >= '0'.to_int() && ch <= '9'.to_int() {
      ch - '0'.to_int()
    } else if ch >= 'a'.to_int() && ch <= 'f'.to_int() {
      ch - 'a'.to_int() + 10
    } else {
      ch - 'A'.to_int() + 10
    }
  }
  for elem in 0..<(if alpha { 4 } else { 3 }) {
    let item_len = if long { 2 } else { 1 }
    let pos = elem * item_len
    values[elem] = if long {
      digit(pos) * 16 + digit(pos + 1)
    } else {
      digit(pos)
    }
    if short {
      // Duplicate number for shorthand notation, i.e. `a` -> `aa`
      values[elem] += values[elem] * 16
    }
  }
  Ok(ProcessColor::from_u8(values[0], values[1], values[2], values[3]))
}

///|
/// The hue as an angle in `[0deg, 360deg)` (upstream `hue_angle`).
fn hue_angle(degrees : Float) -> Angle {
  let d = degrees.to_double()
  let r = d % 360.0
  Angle::deg(if r < 0.0 { r + 360.0 } else { r })
}

// Cmyk.

///|
fn Cmyk::from_luma(luma : Luma) -> Cmyk {
  let l = (1.0 : Float) - luma.luma
  { c: l * 0.75, m: l * 0.68, y: l * 0.67, k: l * 0.90, }
}

///|
// This still uses naive conversion, because the profile doesn't support
// converting _to_ CMYK.
fn Cmyk::from_rgba(rgba : Rgb) -> Cmyk {
  let r = rgba.red
  let g = rgba.green
  let b = rgba.blue
  let k = (1.0 : Float) - f32_max(f32_max(r, g), b)
  if k == 1.0 {
    return { c: 0.0, m: 0.0, y: 0.0, k: 1.0, }
  }
  let one : Float = 1.0
  let c = (one - r - k) / (one - k)
  let m = (one - g - k) / (one - k)
  let y = (one - b - k) / (one - k)
  { c, m, y, k, }
}

///|
/// Convert to sRGB through the CMYK ICC profile.
fn Cmyk::to_rgba(self : Cmyk) -> Rgb {
  let (r, g, b) = cmyk_to_srgb8(
    f32_to_u8_round_raw(self.c),
    f32_to_u8_round_raw(self.m),
    f32_to_u8_round_raw(self.y),
    f32_to_u8_round_raw(self.k),
  )
  {
    red: Float::from_int(r) / 255.0,
    green: Float::from_int(g) / 255.0,
    blue: Float::from_int(b) / 255.0,
    alpha: 1.0,
  }
}

///|
/// Rust `(x * 255.0).round() as u8` for a component.
fn f32_to_u8_round_raw(x : Float) -> Int {
  f32_to_u8_round(x)
}

///|
fn Cmyk::lighten(self : Cmyk, factor : Float) -> Cmyk {
  let lighten = (u : Float) => f32_clamp(u - u * factor, 0.0, 1.0)
  {
    c: lighten(self.c),
    m: lighten(self.m),
    y: lighten(self.y),
    k: lighten(self.k),
  }
}

///|
fn Cmyk::darken(self : Cmyk, factor : Float) -> Cmyk {
  let darken = (u : Float) => f32_clamp(u + (1.0 - u) * factor, 0.0, 1.0)
  {
    c: darken(self.c),
    m: darken(self.m),
    y: darken(self.y),
    k: darken(self.k),
  }
}

// Spot colors.

///|
/// Lightens the spot color by a given factor.
pub fn SpotColor::lighten(self : SpotColor, factor : Ratio) -> SpotColor {
  let tint = self.tint.get()
  {
    colorant: self.colorant,
    tint: Ratio::new(clamp_f64(tint - tint * factor.get(), 0.0, 1.0)),
  }
}

///|
/// Darkens the spot color by a given factor.
pub fn SpotColor::darken(self : SpotColor, factor : Ratio) -> SpotColor {
  let tint = self.tint.get()
  {
    colorant: self.colorant,
    tint: Ratio::new(clamp_f64(tint + (1.0 - tint) * factor.get(), 0.0, 1.0)),
  }
}

///|
/// Rust `f64::clamp`.
fn clamp_f64(x : Double, min : Double, max : Double) -> Double {
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
/// Negates the spot color (inverts the tint).
pub fn SpotColor::negate(self : SpotColor) -> SpotColor {
  { colorant: self.colorant, tint: Ratio::new(1.0 - self.tint.get()), }
}

///|
/// Returns the fallback process color with the tint applied.
pub fn SpotColor::fallback(self : SpotColor) -> ProcessColor {
  self.colorant.fallback.lighten(Ratio::new(1.0 - self.tint.get()))
}

///|
pub fn SpotColor::repr(self : SpotColor) -> String {
  "\{self.colorant.repr()}.tint(\{self.tint.repr()})"
}

///|
pub fn SpotColorant::repr(self : SpotColorant) -> String {
  "color.spot(\{repr_opt_spot_name(self.name)}, \{self.fallback.repr()})"
}

///|
pub impl Hash for SpotColorant with fn hash_combine(self, hasher) {
  match self.name {
    None => hasher.combine_int(0)
    Some(All) => hasher.combine_int(1)
    Some(Custom(s)) => {
      hasher.combine_int(2)
      hasher.combine_string(s)
    }
  }
  self.fallback.hash_combine(hasher)
}

///|
fn repr_opt_spot_name(name : SpotColorantName?) -> String {
  match name {
    None => "none"
    Some(n) => n.repr()
  }
}

///|
pub fn SpotColorantName::repr(self : SpotColorantName) -> String {
  match self {
    All => repr_str("all")
    Custom(name) => repr_str(name)
  }
}

///|
/// Create a new spot colorant.
// Cannot fail; upstream returns `SourceResult` and only `Ok`
// (typst-library/src/visualize/color.rs:2347).
#warnings("-unused_error_type")
fn impl_spot_colorant_construct(
  name_ : SpotColorantName?,
  fallback_ : ProcessColor,
) -> SpotColorant raise SourceError {
  { name: name_, fallback: fallback_, }
}

///|
/// Create a spot color at a specific tint of this colorant.
fn impl_spot_colorant_tint(
  self_ : SpotColorant,
  value_ : @syntax.Spanned[Ratio],
) -> Color raise SourceError {
  if value_.v.get() < 0.0 {
    bail_at(value_.span, "spot color tint must be positive")
  }
  if value_.v.get() > 1.0 {
    bail_at(value_.span, "spot color tint must not exceed 100%")
  }
  Spot({ colorant: self_, tint: value_.v, })
}

///|
/// A color with a weight.
pub(all) struct WeightedColor {
  color : Color
  weight : Double
}

///|
/// Create a new weighted color.
pub fn WeightedColor::new(color : Color, weight : Double) -> WeightedColor {
  { color, weight, }
}

///|
/// Resolves `space` against the participating colors. If the space is
/// custom, it is returned immediately. Otherwise, if all colors are of the
/// same spot colorant, that is returned and Oklab otherwise.
pub fn resolve_color_space(
  space : Smart[ColorSpace],
  colors : Array[Color],
) -> ColorSpace {
  match space {
    Custom(s) => return s
    Auto => ()
  }
  // `None`: initial auto; `Some(Ok(space))`: decided; `Some(Err(colorant))`:
  // may be spot.
  let mut verdict : Result[ColorSpace, SpotColorant]? = None
  let fallback : ColorSpace = Process(Oklab)
  for color in colors {
    match verdict {
      None =>
        verdict = match color.space() {
          Process(_) => Some(Ok(fallback))
          Spot(colorant) => Some(Err(colorant))
        }
      Some(Err(colorant)) =>
        verdict = match color.space() {
          Spot(other) if other == colorant => verdict
          _ => Some(Ok(fallback))
        }
      Some(Ok(_)) => break
    }
  }
  match verdict {
    None => fallback
    Some(Ok(s)) => s
    Some(Err(colorant)) => Spot(colorant)
  }
}

///|
/// Returns the index of the hue component in this color space, if it has
/// one.
pub fn ColorSpace::hue_index(self : ColorSpace) -> Int? {
  match self {
    Process(s) => s.hue_index()
    Spot(_) => None
  }
}

///|
/// Returns the index of the hue component in this color space, if it has
/// one.
pub fn ProcessColorSpace::hue_index(self : ProcessColorSpace) -> Int? {
  match self {
    Hsl | Hsv => Some(0)
    Oklch => Some(2)
    _ => None
  }
}

///|
/// Return the value for each variant's constructor.
fn ProcessColorSpace::variant_constructor(self : ProcessColorSpace) -> Value {
  Func(
    Func::native(
      match self {
        Oklab => native_color_oklab()
        Oklch => native_color_oklch()
        Srgb => native_color_rgb()
        D65Gray => native_color_luma()
        LinearRgb => native_color_linear_rgb()
        Hsl => native_color_hsl()
        Hsv => native_color_hsv()
        Cmyk => native_color_cmyk()
      },
    ),
  )
}

///|
/// Given a constructor, return the matching variant.
fn ProcessColorSpace::try_from_constructor(func : Func) -> ProcessColorSpace? {
  let data = match func.to_native() {
    Some(d) if func.inner is Native(_) => d
    _ => return None
  }
  let candidates : Array[(NativeFuncData, ProcessColorSpace)] = [
    (native_color_oklab(), Oklab),
    (native_color_oklch(), Oklch),
    (native_color_rgb(), Srgb),
    (native_color_luma(), D65Gray),
    (native_color_linear_rgb(), LinearRgb),
    (native_color_hsl(), Hsl),
    (native_color_hsv(), Hsv),
    (native_color_cmyk(), Cmyk),
  ]
  for pair in candidates {
    if physical_equal(pair.0, data) {
      return Some(pair.1)
    }
  }
  None
}

// Casting.

///|
pub impl Reflect for Color with fn input() {
  Type(Type::color())
}

///|
pub impl Reflect for Color with fn output() {
  Type(Type::color())
}

///|
pub impl Reflect for Color with fn castable(v) {
  v is Color(_)
}

///|
pub extend Color with Reflect::{output, input, castable}

///|
pub impl IntoValue for Color with fn into_value(self) {
  Color(self)
}

///|
pub impl FromValue for Color with fn from_value(v) {
  match v {
    Color(c) => c
    v => raise HintedError(Color::input().error(v))
  }
}

///|
pub impl Reflect for ProcessColor with fn input() {
  Color::input()
}

///|
pub impl Reflect for ProcessColor with fn output() {
  Color::input()
}

///|
pub impl Reflect for ProcessColor with fn castable(v) {
  Color::castable(v)
}

///|
pub extend ProcessColor with Reflect::{output, input, castable}

///|
pub impl IntoValue for ProcessColor with fn into_value(self) {
  Color(Process(self))
}

///|
pub impl FromValue for ProcessColor with fn from_value(v) {
  if Color::castable(v) {
    match Color::from_value(v) {
      Process(c) => return c
      Spot(_) => bail("spot color found where process color is required")
    }
  }
  raise HintedError(ProcessColor::input().error(v))
}

///|
pub impl Reflect for SpotColorant with fn input() {
  Type(Type::spot())
}

///|
pub impl Reflect for SpotColorant with fn output() {
  Type(Type::spot())
}

///|
pub impl Reflect for SpotColorant with fn castable(v) {
  v is Dyn(SpotColorant(_))
}

///|
pub extend SpotColorant with Reflect::{output, input, castable}

///|
pub impl IntoValue for SpotColorant with fn into_value(self) {
  Dyn(SpotColorant(self))
}

///|
pub impl FromValue for SpotColorant with fn from_value(v) {
  match v {
    Dyn(SpotColorant(c)) => c
    v => raise HintedError(SpotColorant::input().error(v))
  }
}

///|
pub impl Reflect for SpotColorantName with fn input() {
  CastInfo::Value(
    Str("all"),
    "Use all available color plates instead of only a specific colorant.",
  ).union_with(Type(Type::str()))
}

///|
pub impl Reflect for SpotColorantName with fn output() {
  SpotColorantName::input()
}

///|
pub impl Reflect for SpotColorantName with fn castable(v) {
  v is (Str(_) | Symbol(_))
}

///|
pub extend SpotColorantName with Reflect::{output, input, castable}

///|
pub impl IntoValue for SpotColorantName with fn into_value(self) {
  match self {
    All => Str("all")
    Custom(name) => Str(name)
  }
}

///|
pub impl FromValue for SpotColorantName with fn from_value(v) {
  match v {
    Str("all") => All
    Str(s) => Custom(s)
    Symbol(s) => Custom(s.get())
    v => raise HintedError(SpotColorantName::input().error(v))
  }
}

///|
pub impl Reflect for ColorSpace with fn input() {
  SpotColorant::input().union_with(Any)
}

///|
pub impl Reflect for ColorSpace with fn output() {
  ColorSpace::input()
}

///|
pub impl Reflect for ColorSpace with fn castable(_) {
  true
}

///|
pub extend ColorSpace with Reflect::{output, input, castable}

///|
pub impl IntoValue for ColorSpace with fn into_value(self) {
  match self {
    Process(s) => s.variant_constructor()
    Spot(s) => s.into_value()
  }
}

///|
pub impl FromValue for ColorSpace with fn from_value(v) {
  if SpotColorant::castable(v) {
    return Spot(SpotColorant::from_value(v))
  }
  let expected = "expected `rgb`, `luma`, `cmyk`, `oklab`, `oklch`, `color.linear-rgb`, `color.hsl`, `color.hsv`, or spot colorant"
  let func = match v {
    Func(func) => func
    _ => bail("\{expected}, found \{v.ty()}")
  }
  match ProcessColorSpace::try_from_constructor(func) {
    Some(space) => Process(space)
    None => bail(expected)
  }
}

///|
pub impl Reflect for ProcessColorSpace with fn input() {
  Any
}

///|
pub impl Reflect for ProcessColorSpace with fn output() {
  Any
}

///|
pub impl Reflect for ProcessColorSpace with fn castable(_) {
  true
}

///|
pub impl IntoValue for ProcessColorSpace with fn into_value(self) {
  self.variant_constructor()
}

///|
pub impl FromValue for ProcessColorSpace with fn from_value(v) {
  let expected = "expected `rgb`, `luma`, `cmyk`, `oklab`, `oklch`, `color.linear-rgb`, `color.hsl`, or `color.hsv`"
  let func = match v {
    Func(func) => func
    _ => bail("\{expected}, found \{v.ty()}")
  }
  match ProcessColorSpace::try_from_constructor(func) {
    Some(space) => space
    None => bail(expected)
  }
}

///|
pub impl Reflect for WeightedColor with fn input() {
  Color::input().union_with(Type(Type::array()))
}

///|
pub impl Reflect for WeightedColor with fn output() {
  WeightedColor::input()
}

///|
pub impl Reflect for WeightedColor with fn castable(v) {
  Color::castable(v) || v is Array(_)
}

///|
pub extend WeightedColor with Reflect::{output, input, castable}

///|
pub impl IntoValue for WeightedColor with fn into_value(self) {
  Array(Arr::from_array([Color(self.color), Float(self.weight)]))
}

///|
pub impl FromValue for WeightedColor with fn from_value(v) {
  match v {
    Color(color) => { color, weight: 1.0, }
    Array(arr) =>
      if arr.items.length() == 2 {
        {
          color: Color::from_value(arr.items[0]),
          weight: weight_from_value(arr.items[1]),
        }
      } else {
        bail("expected a color or color-weight pair")
      }
    v => raise HintedError(WeightedColor::input().error(v))
  }
}

///|
/// A weight for color mixing (upstream `Weight`): a float or a ratio.
fn weight_from_value(v : Value) -> Double raise HintedError {
  match v {
    Int(i) => i.to_double()
    Float(f) => f
    Ratio(r) => r.get()
    v =>
      raise HintedError(
        CastInfo::Type(Type::float()).union_with(Type(Type::ratio())).error(v),
      )
  }
}

///|
/// A component that must be a ratio.
pub(all) struct RatioComponent(Ratio)

///|
pub impl Reflect for RatioComponent with fn input() {
  Type(Type::ratio())
}

///|
pub impl Reflect for RatioComponent with fn output() {
  Type(Type::ratio())
}

///|
pub impl Reflect for RatioComponent with fn castable(v) {
  v is Ratio(_)
}

///|
pub extend RatioComponent with Reflect::{output, input, castable}

///|
pub impl IntoValue for RatioComponent with fn into_value(self) {
  Ratio(self.0)
}

///|
pub impl FromValue for RatioComponent with fn from_value(v) {
  match v {
    Ratio(r) =>
      if r.get() >= 0.0 && r.get() <= 1.0 {
        RatioComponent(r)
      } else {
        bail("ratio must be between 0% and 100%")
      }
    v => raise HintedError(RatioComponent::input().error(v))
  }
}

///|
/// A chroma color component: a ratio (relative to 0.4) or a float.
pub(all) struct ChromaComponent(Float)

///|
pub impl Reflect for ChromaComponent with fn input() {
  CastInfo::Type(Type::float()).union_with(Type(Type::ratio()))
}

///|
pub impl Reflect for ChromaComponent with fn output() {
  ChromaComponent::input()
}

///|
pub impl Reflect for ChromaComponent with fn castable(v) {
  v is (Int(_) | Float(_) | Ratio(_))
}

///|
pub extend ChromaComponent with Reflect::{output, input, castable}

///|
pub impl IntoValue for ChromaComponent with fn into_value(self) {
  Float(self.0.to_double())
}

///|
pub impl FromValue for ChromaComponent with fn from_value(v) {
  match v {
    Int(i) => ChromaComponent(f32_(i.to_double()))
    Float(f) => ChromaComponent(f32_(f))
    Ratio(r) => ChromaComponent(f32_(r.get() * 0.4))
    v => raise HintedError(ChromaComponent::input().error(v))
  }
}

///|
/// An integer or ratio component.
pub(all) struct Component(Ratio)

///|
pub impl Reflect for Component with fn input() {
  CastInfo::Type(Type::int()).union_with(Type(Type::ratio()))
}

///|
pub impl Reflect for Component with fn output() {
  Component::input()
}

///|
pub impl Reflect for Component with fn castable(v) {
  v is (Int(_) | Ratio(_))
}

///|
pub extend Component with Reflect::{output, input, castable}

///|
pub impl IntoValue for Component with fn into_value(self) {
  Ratio(self.0)
}

///|
pub impl FromValue for Component with fn from_value(v) {
  match v {
    Int(i) =>
      if i >= 0L && i <= 255L {
        Component(Ratio::new(i.to_double() / 255.0))
      } else {
        bail("number must be between 0 and 255")
      }
    Ratio(r) =>
      if r.get() >= 0.0 && r.get() <= 1.0 {
        Component(r)
      } else {
        bail("ratio must be between 0% and 100%")
      }
    v => raise HintedError(Component::input().error(v))
  }
}

// Preset color maps.

///|
/// A module with all preset color maps.
fn color_map() -> Module {
  let scope = Scope::new()
  scope.define_("turbo", Array(color_preset(color_map_turbo))) |> ignore
  scope.define_("cividis", Array(color_preset(color_map_cividis))) |> ignore
  scope.define_("rainbow", Array(color_preset(color_map_rainbow))) |> ignore
  scope.define_("spectral", Array(color_preset(color_map_spectral))) |> ignore
  scope.define_("viridis", Array(color_preset(color_map_viridis))) |> ignore
  scope.define_("inferno", Array(color_preset(color_map_inferno))) |> ignore
  scope.define_("magma", Array(color_preset(color_map_magma))) |> ignore
  scope.define_("plasma", Array(color_preset(color_map_plasma))) |> ignore
  scope.define_("rocket", Array(color_preset(color_map_rocket))) |> ignore
  scope.define_("mako", Array(color_preset(color_map_mako))) |> ignore
  scope.define_("coolwarm", Array(color_preset(color_map_coolwarm))) |> ignore
  scope.define_("vlag", Array(color_preset(color_map_vlag))) |> ignore
  scope.define_("icefire", Array(color_preset(color_map_icefire))) |> ignore
  scope.define_("flare", Array(color_preset(color_map_flare))) |> ignore
  scope.define_("crest", Array(color_preset(color_map_crest))) |> ignore
  Module::new("map", scope)
}

///|
/// Defines a gradient preset as a series of colors expressed as u32s.
fn color_preset(colors : ReadOnlyArray[UInt]) -> Arr {
  Arr::from_array(
    Array::makei(colors.length(), i => Value::Color(Color::from_u32(colors[i]))),
  )
}

///|
/// Find and consume the first positional argument castable to a string,
/// keeping its span (upstream `args.find::<Spanned<Str>>()`).
fn args_find_spanned_str(args : Args) -> @syntax.Spanned[String]? {
  for i, slot in args.items {
    if slot.name is None && slot.value.v is (Str(_) | Symbol(_)) {
      let value = args.items.remove(i).value
      let s = match value.v {
        Str(s) => s
        Symbol(s) => s.get()
        _ => abort("unreachable")
      }
      return Some({ v: s, span: value.span, })
    }
  }
  None
}
