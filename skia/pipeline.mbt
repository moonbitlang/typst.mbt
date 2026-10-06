// Port of `tiny-skia/src/pipeline/mod.rs`.
//
// A raster pipeline implementation.
//
// 1. A pipeline consists of stages.
// 1. A pipeline has a global context shared by all stages.
// 1. Each stage has a high precision implementation. See `pipeline_highp.mbt`.
// 1. Some stages have a low precision implementation. See
//    `pipeline_lowp.mbt`.
// 1. Each stage calls the "next" stage after its done.
// 1. During pipeline "compilation", if **all** stages have a lowp
//    implementation, the lowp pipeline will be used. Otherwise, the highp
//    variant will be used.
//
// Upstream compiles the stages into function pointers that call each other;
// here the stages are interpreted in a loop, a stage returning `false` stops
// the run (like a stage that does not call `next_stage`). Upstream's
// separate "tail" programs only differ in their load/store functions, which
// here use the current tail length.

///|
// `MoveSourceToDestination` is never pushed upstream either (tiny-skia
// 0.12.0 src/pipeline/mod.rs:71); it has its entry in both stage tables.
#warnings("-unused_constructor")
enum Stage {
  MoveSourceToDestination
  MoveDestinationToSource
  Clamp0
  ClampA
  Premultiply
  UniformColor
  SeedShader
  LoadDestination
  Store
  LoadDestinationU8
  StoreU8
  Gather
  LoadMaskU8
  MaskU8
  ScaleU8
  LerpU8
  Scale1Float
  Lerp1Float
  DestinationAtop
  DestinationIn
  DestinationOut
  DestinationOver
  SourceAtop
  SourceIn
  SourceOut
  SourceOver
  Clear
  Modulate
  Multiply
  Plus
  Screen
  Xor
  ColorBurn
  ColorDodge
  Darken
  Difference
  Exclusion
  HardLight
  Lighten
  Overlay
  SoftLight
  Hue
  Saturation
  Color
  Luminosity
  SourceOverRgba
  Transform
  Reflect
  Repeat
  Bilinear
  Bicubic
  PadX1
  ReflectX1
  RepeatX1
  Gradient
  EvenlySpaced2StopGradient
  XYToUnitAngle
  XYToRadius
  XYTo2PtConicalFocalOnCircle
  XYTo2PtConicalWellBehaved
  XYTo2PtConicalSmaller
  XYTo2PtConicalGreater
  XYTo2PtConicalStrip
  Mask2PtConicalNan
  Mask2PtConicalDegenerates
  ApplyVectorMask
  Alter2PtConicalCompensateFocal
  Alter2PtConicalUnswap
  NegateX
  ApplyConcentricScaleBias
  GammaExpand2
  GammaExpandDestination2
  GammaCompress2
  GammaExpand22
  GammaExpandDestination22
  GammaCompress22
  GammaExpandSrgb
  GammaExpandDestinationSrgb
  GammaCompressSrgb
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stage with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stage with @debug.Debug::{to_repr}

///|
/// Whether the stage has a lowp implementation (upstream: its entry in
/// `lowp::STAGES` is not `null_fn`).
fn Stage::has_lowp(self : Stage) -> Bool {
  match self {
    Clamp0
    | ClampA
    | Gather
    | ColorBurn
    | ColorDodge
    | SoftLight
    | Hue
    | Saturation
    | Color
    | Luminosity
    | Reflect
    | Repeat
    | Bilinear
    | Bicubic
    | XYToUnitAngle
    | XYTo2PtConicalFocalOnCircle
    | XYTo2PtConicalWellBehaved
    | XYTo2PtConicalSmaller
    | XYTo2PtConicalGreater
    | XYTo2PtConicalStrip
    | Mask2PtConicalNan
    | Mask2PtConicalDegenerates
    | ApplyVectorMask
    | Alter2PtConicalCompensateFocal
    | Alter2PtConicalUnswap
    | NegateX
    | ApplyConcentricScaleBias
    | GammaExpand2
    | GammaExpandDestination2
    | GammaCompress2
    | GammaExpand22
    | GammaExpandDestination22
    | GammaCompress22
    | GammaExpandSrgb
    | GammaExpandDestinationSrgb
    | GammaCompressSrgb => false
    _ => true
  }
}

///|
priv struct AAMaskCtx {
  pixels : FixedArray[Int] // [u8; 2]
  stride : Int // can be zero
  shift : Int // mask offset/position in pixmap coordinates
}

///|
fn AAMaskCtx::default() -> AAMaskCtx {
  { pixels: [0, 0], stride: 0, shift: 0, }
}

///|
/// Returns the two mask values.
fn AAMaskCtx::copy_at_xy(
  self : AAMaskCtx,
  dx : Int,
  dy : Int,
  tail : Int,
) -> (Int, Int) {
  let offset = self.stride * dy + dx - self.shift
  // We have only 3 variants, so unroll them.
  match (offset, tail) {
    (0, 1) => (self.pixels[0], 0)
    (0, 2) => (self.pixels[0], self.pixels[1])
    (1, 1) => (self.pixels[1], 0)
    _ => (0, 0) // unreachable
  }
}

///|
priv struct MaskCtx {
  data : FixedArray[Byte]
  offset : Int
  real_width : Int
}

///|
fn MaskCtx::default() -> MaskCtx {
  { data: empty_bytes, offset: 0, real_width: 0, }
}

///|
fn MaskCtx::offset_of(self : MaskCtx, dx : Int, dy : Int) -> Int {
  self.offset + self.real_width * dy + dx
}

///|
priv struct SamplerCtx {
  mut spread_mode : SpreadMode
  mut inv_width : Float
  mut inv_height : Float
}

///|
priv struct UniformColorCtx {
  mut r : Float
  mut g : Float
  mut b : Float
  mut a : Float
  rgba : FixedArray[Int] // [0,255] in a 16-bit lane.
}

///|
/// A gradient color is an unpremultiplied RGBA not in a 0..1 range.
/// It basically can have any float value.
struct GradientColor {
  r : Float
  g : Float
  b : Float
  a : Float
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GradientColor with Eq::{not_equal, equal}

///|
fn GradientColor::new(
  r : Float,
  g : Float,
  b : Float,
  a : Float,
) -> GradientColor {
  { r, g, b, a, }
}

///|
fn GradientColor::from_color(c : Color) -> GradientColor {
  { r: c.r, g: c.g, b: c.b, a: c.a, }
}

///|
priv struct EvenlySpaced2StopGradientCtx {
  mut factor : GradientColor
  mut bias : GradientColor
}

///|
priv struct GradientCtx {
  mut len : Int
  factors : Array[GradientColor]
  biases : Array[GradientColor]
  t_values : Array[Float]
}

///|
fn GradientCtx::default() -> GradientCtx {
  { len: 0, factors: [], biases: [], t_values: [], }
}

///|
fn GradientCtx::push_const_color(
  self : GradientCtx,
  color : GradientColor,
) -> Unit {
  self.factors.push(GradientColor::new(0.0, 0.0, 0.0, 0.0))
  self.biases.push(color)
}

///|
priv struct TwoPointConicalGradientCtx {
  // This context is used only in highp, where we use Tx4.
  mask : FixedArray[UInt] // u32x8
  mut p0 : Float
  mut p1 : Float
}

///|
priv struct TileCtx {
  mut scale : Float
  mut inv_scale : Float // cache of 1/scale
}

///|
priv struct Context {
  mut current_coverage : Float
  sampler : SamplerCtx
  uniform_color : UniformColorCtx
  evenly_spaced_2_stop_gradient : EvenlySpaced2StopGradientCtx
  mut gradient : GradientCtx
  two_point_conical_gradient : TwoPointConicalGradientCtx
  limit_x : TileCtx
  limit_y : TileCtx
  mut transform : @path.Transform
}

///|
fn Context::default() -> Context {
  let zero = GradientColor::new(0.0, 0.0, 0.0, 0.0)
  {
    current_coverage: 0.0,
    sampler: { spread_mode: Pad, inv_width: 0.0, inv_height: 0.0, },
    uniform_color: { r: 0.0, g: 0.0, b: 0.0, a: 0.0, rgba: [0, 0, 0, 0], },
    evenly_spaced_2_stop_gradient: { factor: zero, bias: zero, },
    gradient: GradientCtx::default(),
    two_point_conical_gradient: {
      mask: FixedArray::make(8, 0),
      p0: 0.0,
      p1: 0.0,
    },
    limit_x: { scale: 0.0, inv_scale: 0.0, },
    limit_y: { scale: 0.0, inv_scale: 0.0, },
    transform: @path.Transform::identity(),
  }
}

///|
priv struct RasterPipelineBuilder {
  stages : Array[Stage]
  mut force_hq_pipeline : Bool
  ctx : Context
}

///|
fn RasterPipelineBuilder::new() -> RasterPipelineBuilder {
  { stages: [], force_hq_pipeline: false, ctx: Context::default(), }
}

///|
fn RasterPipelineBuilder::set_force_hq_pipeline(
  self : RasterPipelineBuilder,
  hq : Bool,
) -> Unit {
  self.force_hq_pipeline = hq
}

///|
fn RasterPipelineBuilder::push(
  self : RasterPipelineBuilder,
  stage : Stage,
) -> Unit {
  self.stages.push(stage)
}

///|
fn RasterPipelineBuilder::push_transform(
  self : RasterPipelineBuilder,
  ts : @path.Transform,
) -> Unit {
  if ts.is_finite() && !ts.is_identity() {
    self.stages.push(Transform)
    self.ctx.transform = ts
  }
}

///|
fn RasterPipelineBuilder::push_uniform_color(
  self : RasterPipelineBuilder,
  c : PremultipliedColor,
) -> Unit {
  let r = c.r
  let g = c.g
  let b = c.b
  let a = c.a
  let ctx = self.ctx.uniform_color
  ctx.r = r
  ctx.g = g
  ctx.b = b
  ctx.a = a
  ctx.rgba[0] = f32_to_u16(r * 255.0 + 0.5)
  ctx.rgba[1] = f32_to_u16(g * 255.0 + 0.5)
  ctx.rgba[2] = f32_to_u16(b * 255.0 + 0.5)
  ctx.rgba[3] = f32_to_u16(a * 255.0 + 0.5)
  self.stages.push(UniformColor)
}

///|
fn RasterPipelineBuilder::compile(
  self : RasterPipelineBuilder,
) -> RasterPipeline {
  if self.stages.is_empty() {
    return { lowp: false, stages: [], ctx: Context::default(), }
  }
  let is_lowp_compatible = self.stages.iter().all(s => s.has_lowp())
  {
    lowp: !self.force_hq_pipeline && is_lowp_compatible,
    stages: self.stages,
    ctx: self.ctx,
  }
}

///|
priv struct RasterPipeline {
  lowp : Bool
  stages : Array[Stage]
  ctx : Context
}

///|
fn RasterPipeline::run(
  self : RasterPipeline,
  rect : ScreenIntRect,
  aa_mask_ctx : AAMaskCtx,
  mask_ctx : MaskCtx,
  pixmap_src : Pixmap,
  pixmap_dst : SubPixmapMut,
) -> Unit {
  if self.stages.is_empty() {
    return
  }
  if self.lowp {
    // lowp doesn't support pattern, so no `pixmap_src` for it.
    lowp_start(self.stages, rect, aa_mask_ctx, mask_ctx, self.ctx, pixmap_dst)
  } else {
    highp_start(
      self.stages,
      rect,
      aa_mask_ctx,
      mask_ctx,
      self.ctx,
      pixmap_src,
      pixmap_dst,
    )
  }
}
