// Port of `tiny-skia/src/shaders/mod.rs` and `shaders/pattern.rs`.

///|
/// A shader spreading mode.
pub(all) enum SpreadMode {
  /// Replicate the edge color if the shader draws outside of its original
  /// bounds.
  Pad
  /// Repeat the shader's image horizontally and vertically, alternating
  /// mirror images so that adjacent images always seam.
  Reflect
  /// Repeat the shader's image horizontally and vertically.
  Repeat
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpreadMode with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpreadMode with @debug.Debug::{to_repr}

///|
pub impl Default for SpreadMode with fn default() {
  Pad
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpreadMode with Default::{default}

///|
/// A shader specifies the source color(s) for what is being drawn.
///
/// If a paint has no shader, then the paint's color is used. If the paint
/// has a shader, then the shader's color(s) are use instead, but they are
/// modulated by the paint's alpha.
pub(all) enum Shader {
  /// A solid color shader.
  SolidColor(Color)
  /// A linear gradient shader.
  LinearGradient(LinearGradient)
  /// A radial gradient shader.
  RadialGradient(RadialGradient)
  /// A sweep gradient shader.
  SweepGradient(SweepGradient)
  /// A pattern shader.
  Pattern(Pattern)
}

///|
/// Checks if the shader is guaranteed to produce only opaque colors.
pub fn Shader::is_opaque(self : Shader) -> Bool {
  match self {
    SolidColor(c) => c.is_opaque()
    LinearGradient(g) => g.base.colors_are_opaque
    // A radial gradient may have points that are "undefined" so we just
    // assume that it is not opaque.
    RadialGradient(_) => false
    SweepGradient(g) => g.base.colors_are_opaque
    Pattern(_) => false
  }
}

///|
/// Unlike Skia, we do not have is_constant, because we don't have Color
/// shaders.
fn Shader::push_stages(
  self : Shader,
  cs : ColorSpace,
  p : RasterPipelineBuilder,
) -> Bool {
  match self {
    SolidColor(color) => {
      let color = cs.expand_color(color).premultiply()
      p.push_uniform_color(color)
      true
    }
    LinearGradient(g) => g.push_stages(cs, p)
    RadialGradient(g) => g.push_stages(cs, p)
    SweepGradient(g) => g.push_stages(cs, p)
    Pattern(patt) => patt.push_stages(cs, p)
  }
}

///|
/// Transforms the shader (`post_concat`); upstream mutates in place.
pub fn Shader::transform(self : Shader, ts : @path.Transform) -> Shader {
  match self {
    SolidColor(_) => self
    LinearGradient(g) =>
      LinearGradient({
        base: { ..g.base, transform: g.base.transform.post_concat(ts), },
      })
    RadialGradient(g) =>
      RadialGradient({
        ..g,
        base: { ..g.base, transform: g.base.transform.post_concat(ts), },
      })
    SweepGradient(g) =>
      SweepGradient({
        ..g,
        base: { ..g.base, transform: g.base.transform.post_concat(ts), },
      })
    Pattern(p) => Pattern({ ..p, transform: p.transform.post_concat(ts), })
  }
}

///|
/// Shifts shader's opacity. `opacity` will be clamped to the 0..=1 range.
///
/// This is roughly the same as Skia's `SkPaint::setAlpha`.
///
/// Unlike Skia, we do not support global alpha/opacity, which is in Skia is
/// set via the alpha channel of the `SkPaint::fColor`.
pub fn Shader::apply_opacity(self : Shader, opacity : Float) -> Shader {
  match self {
    SolidColor(c) => SolidColor(c.apply_opacity(opacity))
    LinearGradient(g) =>
      LinearGradient({ base: g.base.apply_opacity(opacity), })
    RadialGradient(g) =>
      RadialGradient({ ..g, base: g.base.apply_opacity(opacity), })
    SweepGradient(g) =>
      SweepGradient({ ..g, base: g.base.apply_opacity(opacity), })
    Pattern(p) =>
      Pattern({
        ..p,
        opacity: normalized_f32(p.opacity * bound(opacity, 0.0, 1.0)).unwrap(),
      })
  }
}

// pattern.rs

///|
/// Controls how much filtering to be done when transforming images.
pub(all) enum FilterQuality {
  /// Nearest-neighbor. Low quality, but fastest.
  Nearest
  /// Bilinear.
  Bilinear
  /// Bicubic. High quality, but slow.
  Bicubic
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FilterQuality with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FilterQuality with @debug.Debug::{to_repr}

///|
/// Controls how a pixmap should be blended.
///
/// Like `Paint`, but for `Pixmap`.
pub(all) struct PixmapPaint {
  /// Pixmap opacity. Must be in 0..=1 range. Default: 1.0
  opacity : Float
  /// Pixmap blending mode. Default: SourceOver
  blend_mode : BlendMode
  /// Specifies how much filtering to be done when transforming images.
  /// Default: Nearest
  quality : FilterQuality
}

///|
pub impl Default for PixmapPaint with fn default() {
  { opacity: 1.0, blend_mode: SourceOver, quality: Nearest, }
}

///|
pub extend PixmapPaint with Default::{default}

///|
/// A pattern shader.
///
/// Essentially a `SkImageShader`.
///
/// Unlike Skia, we do not support FilterQuality::Medium, because it
/// involves mipmap generation, which adds too much complexity.
pub(all) struct Pattern {
  pixmap : Pixmap
  quality : FilterQuality
  spread_mode : SpreadMode
  opacity : Float
  transform : @path.Transform
}

///|
/// Creates a new pattern shader.
///
/// `opacity` will be clamped to the 0..=1 range.
pub fn Pattern::new(
  pixmap : Pixmap,
  spread_mode : SpreadMode,
  quality : FilterQuality,
  opacity : Float,
  transform : @path.Transform,
) -> Shader {
  Pattern({
    pixmap,
    spread_mode,
    quality,
    opacity: normalized_f32_clamped(opacity),
    transform,
  })
}

///|
fn Pattern::push_stages(
  self : Pattern,
  cs : ColorSpace,
  p : RasterPipelineBuilder,
) -> Bool {
  guard self.transform.invert() is Some(ts) else {
    // failed to invert a pattern transform. Nothing will be rendered
    return false
  }
  p.push(SeedShader)
  p.push_transform(ts)
  let mut quality = self.quality
  if ts.is_identity() || ts.is_translate() {
    quality = Nearest
  }
  if quality == Bilinear {
    if ts.is_translate() {
      if ts.tx == truncf(ts.tx) && ts.ty == truncf(ts.ty) {
        // When the matrix is just an integer translate, bilerp == nearest
        // neighbor.
        quality = Nearest
      }
    }
  }

  // TODO: minimizing scale via mipmap
  let w = Float::from_int(self.pixmap.width())
  let h = Float::from_int(self.pixmap.height())
  match quality {
    Nearest => {
      p.ctx.limit_x.scale = w
      p.ctx.limit_x.inv_scale = (1.0 : Float) / w
      p.ctx.limit_y.scale = h
      p.ctx.limit_y.inv_scale = (1.0 : Float) / h
      match self.spread_mode {
        Pad => () // The gather() stage will clamp for us.
        Repeat => p.push(Repeat)
        Reflect => p.push(Reflect)
      }
      p.push(Gather)
    }
    Bilinear => {
      p.ctx.sampler.spread_mode = self.spread_mode
      p.ctx.sampler.inv_width = (1.0 : Float) / w
      p.ctx.sampler.inv_height = (1.0 : Float) / h
      p.push(Bilinear)
    }
    Bicubic => {
      p.ctx.sampler.spread_mode = self.spread_mode
      p.ctx.sampler.inv_width = (1.0 : Float) / w
      p.ctx.sampler.inv_height = (1.0 : Float) / h
      p.push(Bicubic)

      // Bicubic filtering naturally produces out of range values on both
      // sides of [0,1].
      p.push(Clamp0)
      p.push(ClampA)
    }
  }

  // Unlike Skia, we do not support global opacity and only Pattern allows
  // it.
  if self.opacity != 1.0 {
    p.ctx.current_coverage = self.opacity
    p.push(Scale1Float)
  }
  if cs.expand_stage() is Some(stage) {
    // TODO: it would be better to gamma-expand prior to sampling, but
    // there isn't currently an intermediate pipeline stage for that.
    p.push(stage)
  }
  true
}
