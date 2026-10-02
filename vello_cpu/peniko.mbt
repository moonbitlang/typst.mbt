// The subset of `peniko` 0.6 and `color` 0.3 vello_cpu uses: fill rules,
// extends, image samplers, blend modes, gradients and colors (always sRGB).

///|
/// Describes the rule that determines the interior portion of a shape.
pub(all) enum Fill {
  NonZero
  EvenOdd
} derive(Eq)

///|
/// Describes how a paint is extended beyond its natural bounds.
pub(all) enum Extend {
  Pad
  Repeat
  Reflect
} derive(Eq)

///|
/// Image quality for the sampler.
pub(all) enum ImageQuality {
  Low
  Medium
  High
} derive(Eq)

///|
/// Parameters which specify how to sample an image.
pub(all) struct ImageSampler {
  x_extend : Extend
  y_extend : Extend
  quality : ImageQuality
  alpha : Float
} derive(Eq)

///|
/// Defines the color mixing function for a blend operation.
pub(all) enum Mix {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  Color
  Luminosity
} derive(Eq)

///|
/// Defines the layer composition function for a blend operation.
pub(all) enum Compose {
  Clear
  Copy
  Dest
  SrcOver
  DestOver
  SrcIn
  DestIn
  SrcOut
  DestOut
  SrcAtop
  DestAtop
  Xor
  Plus
  PlusLighter
} derive(Eq)

///|
/// Blend mode consisting of color mixing and composition functions.
pub(all) struct BlendMode {
  mix : Mix
  compose : Compose
} derive(Eq)

///|
pub fn BlendMode::new(mix : Mix, compose : Compose) -> BlendMode {
  { mix, compose, }
}

///|
pub impl Default for BlendMode with fn default() {
  { mix: Normal, compose: SrcOver, }
}

///|
fn BlendMode::is_default(self : BlendMode) -> Bool {
  self.mix == Normal && self.compose == SrcOver
}

///|
/// Destructive blend modes disallow certain optimizations, such as skipping
/// transparent paints.
pub fn BlendMode::is_destructive(self : BlendMode) -> Bool {
  match self.compose {
    Clear | Copy | SrcIn | DestIn | SrcOut | DestAtop => true
    _ => false
  }
}

///|
/// An sRGB color with separate alpha (`AlphaColor<Srgb>`), components in
/// `[r, g, b, a]` order.
pub(all) struct AlphaColor {
  components : FixedArray[Float]
}

///|
pub fn AlphaColor::new(components : FixedArray[Float]) -> AlphaColor {
  { components: [components[0], components[1], components[2], components[3]], }
}

///|
/// `AlphaColor::from_rgba8`.
pub fn AlphaColor::from_rgba8(r : Int, g : Int, b : Int, a : Int) -> AlphaColor {
  {
    components: [
      u8_to_unit_color(r),
      u8_to_unit_color(g),
      u8_to_unit_color(b),
      u8_to_unit_color(a),
    ],
  }
}

///|
/// `color`'s `u8` to `f32` conversion: `x as f32 * (1.0 / 255.0)`.
fn u8_to_unit_color(x : Int) -> Float {
  Float::from_int(x) * ((1.0 : Float) / 255.0)
}

///|
/// The fully transparent color.
pub let transparent : AlphaColor = { components: [0.0, 0.0, 0.0, 0.0], }

///|
/// Opaque black.
pub let black : AlphaColor = { components: [0.0, 0.0, 0.0, 1.0], }

///|
/// Opaque white.
pub let white : AlphaColor = { components: [1.0, 1.0, 1.0, 1.0], }

///|
/// `AlphaColor::premultiply`, giving the components of a `PremulColor`.
pub fn AlphaColor::premultiply(self : AlphaColor) -> FixedArray[Float] {
  let c = self.components
  let a = c[3]
  [c[0] * a, c[1] * a, c[2] * a, a]
}

///|
/// `AlphaColor::to_rgba8` / `PremulColor::to_rgba8` on raw components:
/// `fast_round_to_u8(x * 255.)`.
pub fn components_to_rgba8(c : FixedArray[Float]) -> FixedArray[Int] {
  [
    fast_round_to_u8(c[0] * 255.0),
    fast_round_to_u8(c[1] * 255.0),
    fast_round_to_u8(c[2] * 255.0),
    fast_round_to_u8(c[3] * 255.0),
  ]
}

///|
/// Fast rounding of `f32` to integer `u8`, rounding ties up.
fn fast_round_to_u8(a : Float) -> Int {
  // This does not need clamping as the behavior of a `f32` to `u8` cast in
  // Rust is to saturate.
  f32_as_u8(a + 0.5)
}

///|
/// Offset and color of a transition point in a gradient.
pub(all) struct ColorStop {
  offset : Float
  color : AlphaColor
}

///|
/// The kind of a gradient.
pub(all) enum GradientKind {
  /// Gradient that transitions between two or more colors along a line.
  Linear(start~ : @kurbo.Point, end~ : @kurbo.Point)
  /// Gradient that transitions between two or more colors that radiate from
  /// an origin.
  Radial(
    start_center~ : @kurbo.Point,
    start_radius~ : Float,
    end_center~ : @kurbo.Point,
    end_radius~ : Float
  )
}

///|
/// Definition of a gradient that transitions between two or more colors.
///
/// Gradients are always interpolated in sRGB with premultiplied alpha (the
/// `peniko` defaults, which is all hayro uses).
pub(all) struct Gradient {
  kind : GradientKind
  extend_mode : Extend
  stops : Array[ColorStop]
}

///|
/// `Gradient::new_linear`.
pub fn Gradient::new_linear(
  start : @kurbo.Point,
  end : @kurbo.Point,
) -> Gradient {
  { kind: Linear(start~, end~), extend_mode: Pad, stops: [], }
}

///|
/// `Gradient::new_two_point_radial`.
pub fn Gradient::new_two_point_radial(
  start_center : @kurbo.Point,
  start_radius : Float,
  end_center : @kurbo.Point,
  end_radius : Float,
) -> Gradient {
  {
    kind: Radial(start_center~, start_radius~, end_center~, end_radius~),
    extend_mode: Pad,
    stops: [],
  }
}

///|
pub fn Gradient::with_extend(self : Gradient, extend_mode : Extend) -> Gradient {
  { ..self, extend_mode, }
}

///|
pub fn Gradient::with_stops(
  self : Gradient,
  stops : Array[ColorStop],
) -> Gradient {
  { ..self, stops: stops.copy(), }
}
