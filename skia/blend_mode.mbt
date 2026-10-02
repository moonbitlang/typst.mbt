// Port of `tiny-skia/src/blend_mode.rs`.

///|
/// A blending mode.
pub(all) enum BlendMode {
  /// Replaces destination with zero: fully transparent.
  Clear
  /// Replaces destination.
  Source
  /// Preserves destination.
  Destination
  /// Source over destination.
  SourceOver
  /// Destination over source.
  DestinationOver
  /// Source trimmed inside destination.
  SourceIn
  /// Destination trimmed by source.
  DestinationIn
  /// Source trimmed outside destination.
  SourceOut
  /// Destination trimmed outside source.
  DestinationOut
  /// Source inside destination blended with destination.
  SourceAtop
  /// Destination inside source blended with source.
  DestinationAtop
  /// Each of source and destination trimmed outside the other.
  Xor
  /// Sum of colors.
  Plus
  /// Product of premultiplied colors; darkens destination.
  Modulate
  /// Multiply inverse of pixels, inverting result; brightens destination.
  Screen
  /// Multiply or screen, depending on destination.
  Overlay
  /// Darker of source and destination.
  Darken
  /// Lighter of source and destination.
  Lighten
  /// Brighten destination to reflect source.
  ColorDodge
  /// Darken destination to reflect source.
  ColorBurn
  /// Multiply or screen, depending on source.
  HardLight
  /// Lighten or darken, depending on source.
  SoftLight
  /// Subtract darker from lighter with higher contrast.
  Difference
  /// Subtract darker from lighter with lower contrast.
  Exclusion
  /// Multiply source with destination, darkening image.
  Multiply
  /// Hue of source with saturation and luminosity of destination.
  Hue
  /// Saturation of source with hue and luminosity of destination.
  Saturation
  /// Hue and saturation of source with luminosity of destination.
  Color
  /// Luminosity of source with hue and saturation of destination.
  Luminosity
} derive(Eq, Debug)

///|
pub impl Default for BlendMode with fn default() {
  SourceOver
}

///|
fn BlendMode::should_pre_scale_coverage(self : BlendMode) -> Bool {
  // The most important things we do here are:
  //   1) never pre-scale with rgb coverage if the blend mode involves a
  //      source-alpha term;
  //   2) always pre-scale Plus.
  //
  // When we pre-scale with rgb coverage, we scale each of source r,g,b, with
  // a distinct value, and source alpha with one of those three values. This
  // process destructively updates the source-alpha term, so we can't
  // evaluate blend modes that need its original value.
  //
  // Plus always requires pre-scaling as a specific quirk of its
  // implementation in RasterPipeline. This lets us put the clamp inside the
  // blend mode itself rather than as a separate stage that'd come after the
  // lerp.
  //
  // This function is a finer-grained breakdown of
  // SkBlendMode_SupportsCoverageAsAlpha().
  self
  is (Destination
  // d              --> no sa term, ok!
  | DestinationOver
  // d + s*inv(da)  --> no sa term, ok!
  | Plus
  // clamp(s+d)     --> no sa term, ok!
  | DestinationOut
  // d * inv(sa)
  | SourceAtop
  // s*da + d*inv(sa)
  | SourceOver
  // s + d*inv(sa)
  | Xor) // s*inv(da) + d*inv(sa)
}

///|
fn BlendMode::to_stage(self : BlendMode) -> Stage? {
  match self {
    Clear => Some(Clear)
    Source => None // This stage is a no-op.
    Destination => Some(MoveDestinationToSource)
    SourceOver => Some(SourceOver)
    DestinationOver => Some(DestinationOver)
    SourceIn => Some(SourceIn)
    DestinationIn => Some(DestinationIn)
    SourceOut => Some(SourceOut)
    DestinationOut => Some(DestinationOut)
    SourceAtop => Some(SourceAtop)
    DestinationAtop => Some(DestinationAtop)
    Xor => Some(Xor)
    Plus => Some(Plus)
    Modulate => Some(Modulate)
    Screen => Some(Screen)
    Overlay => Some(Overlay)
    Darken => Some(Darken)
    Lighten => Some(Lighten)
    ColorDodge => Some(ColorDodge)
    ColorBurn => Some(ColorBurn)
    HardLight => Some(HardLight)
    SoftLight => Some(SoftLight)
    Difference => Some(Difference)
    Exclusion => Some(Exclusion)
    Multiply => Some(Multiply)
    Hue => Some(Hue)
    Saturation => Some(Saturation)
    Color => Some(Color)
    Luminosity => Some(Luminosity)
  }
}
