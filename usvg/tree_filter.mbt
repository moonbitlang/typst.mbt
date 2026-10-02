// Port of `usvg` 0.47.0 `src/tree/filter.rs`: SVG filter types.
//
// Upstream's `filter::Kind`, `filter::Input`, `filter::Image`, ... are named
// `FilterKind`, `FilterInput`, `FeImage`, ... here.

///|
/// A filter element.
///
/// `filter` element in the SVG.
pub struct Filter {
  priv uid : Int
  priv id : NonEmptyString
  priv rect : NonZeroRect
  priv primitives : Array[Primitive]
}

///|
/// Element's ID.
pub fn Filter::id(self : Filter) -> String {
  self.id.get()
}

///|
/// Filter region.
pub fn Filter::rect(self : Filter) -> NonZeroRect {
  self.rect
}

///|
/// A list of filter primitives.
pub fn Filter::primitives(self : Filter) -> Array[Primitive] {
  self.primitives
}

///|
/// A filter primitive element.
pub struct Primitive {
  priv rect : NonZeroRect
  priv color_interpolation : ColorInterpolation
  priv result : String
  priv kind : FilterKind
}

///|
/// Filter subregion.
pub fn Primitive::rect(self : Primitive) -> NonZeroRect {
  self.rect
}

///|
/// Color interpolation mode.
pub fn Primitive::color_interpolation(self : Primitive) -> ColorInterpolation {
  self.color_interpolation
}

///|
/// Assigned name for this filter primitive.
pub fn Primitive::result(self : Primitive) -> String {
  self.result
}

///|
/// Filter primitive kind.
pub fn Primitive::kind(self : Primitive) -> FilterKind {
  self.kind
}

///|
/// A filter kind.
pub(all) enum FilterKind {
  Blend(FeBlend)
  ColorMatrix(FeColorMatrix)
  ComponentTransfer(FeComponentTransfer)
  Composite(FeComposite)
  ConvolveMatrix(FeConvolveMatrix)
  DiffuseLighting(FeDiffuseLighting)
  DisplacementMap(FeDisplacementMap)
  DropShadow(FeDropShadow)
  Flood(FeFlood)
  GaussianBlur(FeGaussianBlur)
  Image(FeImage)
  Merge(FeMerge)
  Morphology(FeMorphology)
  Offset(FeOffset)
  SpecularLighting(FeSpecularLighting)
  Tile(FeTile)
  Turbulence(FeTurbulence)
}

///|
/// Checks that `FilterKind` has a specific input.
pub fn FilterKind::has_input(self : FilterKind, input : FilterInput) -> Bool {
  match self {
    Blend(fe) => fe.input1 == input || fe.input2 == input
    ColorMatrix(fe) => fe.input == input
    ComponentTransfer(fe) => fe.input == input
    Composite(fe) => fe.input1 == input || fe.input2 == input
    ConvolveMatrix(fe) => fe.input == input
    DiffuseLighting(fe) => fe.input == input
    DisplacementMap(fe) => fe.input1 == input || fe.input2 == input
    DropShadow(fe) => fe.input == input
    Flood(_) => false
    GaussianBlur(fe) => fe.input == input
    Image(_) => false
    Merge(fe) => fe.inputs.iter().any(i => i == input)
    Morphology(fe) => fe.input == input
    Offset(fe) => fe.input == input
    SpecularLighting(fe) => fe.input == input
    Tile(fe) => fe.input == input
    Turbulence(_) => false
  }
}

///|
/// Identifies input for a filter primitive.
pub(all) enum FilterInput {
  SourceGraphic
  SourceAlpha
  Reference(String)
} derive(Eq)

///|
/// A color interpolation mode.
///
/// The default is `ColorInterpolation::LinearRGB`.
pub(all) enum ColorInterpolation {
  SRGB
  LinearRGB
} derive(Eq)

///|
pub impl Default for ColorInterpolation with fn default() {
  LinearRGB
}

///|
/// A blend filter primitive.
///
/// `feBlend` element in the SVG.
pub(all) struct FeBlend {
  input1 : FilterInput
  input2 : FilterInput
  mode : BlendMode
}

///|
/// A color matrix filter primitive.
///
/// `feColorMatrix` element in the SVG.
pub(all) struct FeColorMatrix {
  input : FilterInput
  kind : ColorMatrixKind
}

///|
/// A color matrix filter primitive kind.
pub(all) enum ColorMatrixKind {
  Matrix(Array[Float]) // Guarantee to have 20 numbers.
  Saturate(PositiveF32)
  HueRotate(Float)
  LuminanceToAlpha
}

///|
pub impl Default for ColorMatrixKind with fn default() {
  Matrix([
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ])
}

///|
/// A component-wise remapping filter primitive.
///
/// `feComponentTransfer` element in the SVG.
pub(all) struct FeComponentTransfer {
  input : FilterInput
  func_r : TransferFunction
  func_g : TransferFunction
  func_b : TransferFunction
  func_a : TransferFunction
}

///|
/// A transfer function used by `FeComponentTransfer`.
///
/// <https://www.w3.org/TR/SVG11/filters.html#transferFuncElements>
pub(all) enum TransferFunction {
  /// Keeps a component as is.
  Identity
  /// Applies a linear interpolation to a component.
  ///
  /// The number list can be empty.
  Table(Array[Float])
  /// Applies a step function to a component.
  ///
  /// The number list can be empty.
  Discrete(Array[Float])
  /// Applies a linear shift to a component.
  Linear(slope~ : Float, intercept~ : Float)
  /// Applies an exponential shift to a component.
  Gamma(amplitude~ : Float, exponent~ : Float, offset~ : Float)
}

///|
/// A composite filter primitive.
///
/// `feComposite` element in the SVG.
pub(all) struct FeComposite {
  input1 : FilterInput
  input2 : FilterInput
  operator : CompositeOperator
}

///|
/// An images compositing operation.
pub(all) enum CompositeOperator {
  Over
  In
  Out
  Atop
  Xor
  Arithmetic(k1~ : Float, k2~ : Float, k3~ : Float, k4~ : Float)
} derive(Eq)

///|
/// A non-zero `f32`.
///
/// Just like `f32` but immutable and guarantee to never be zero.
pub struct NonZeroF32(Float)

///|
/// Creates a new `NonZeroF32` value.
pub fn NonZeroF32::new(n : Float) -> NonZeroF32? {
  if approx_eq_ulps(n, 0.0, 4) {
    None
  } else {
    Some(NonZeroF32(n))
  }
}

///|
/// Returns an underlying value.
pub fn NonZeroF32::get(self : NonZeroF32) -> Float {
  self.0
}

///|
/// A matrix convolution filter primitive.
///
/// `feConvolveMatrix` element in the SVG.
pub(all) struct FeConvolveMatrix {
  input : FilterInput
  matrix : ConvolveMatrixData
  divisor : NonZeroF32
  bias : Float
  edge_mode : EdgeMode
  preserve_alpha : Bool
}

///|
/// A convolve matrix representation.
pub(all) struct ConvolveMatrixData {
  target_x : UInt
  target_y : UInt
  columns : UInt
  rows : UInt
  data : Array[Float]
}

///|
/// Creates a new `ConvolveMatrixData`.
///
/// Returns `None` when:
///
/// - `columns` * `rows` != `data.len()`
/// - `target_x` >= `columns`
/// - `target_y` >= `rows`
fn ConvolveMatrixData::new(
  target_x : UInt,
  target_y : UInt,
  columns : UInt,
  rows : UInt,
  data : Array[Float],
) -> ConvolveMatrixData? {
  if (columns * rows).reinterpret_as_int() != data.length() ||
    target_x >= columns ||
    target_y >= rows {
    return None
  }
  Some({ target_x, target_y, columns, rows, data, })
}

///|
/// Returns a matrix value at the specified position.
pub fn ConvolveMatrixData::get(
  self : ConvolveMatrixData,
  x : UInt,
  y : UInt,
) -> Float {
  self.data[(y * self.columns + x).reinterpret_as_int()]
}

///|
/// An edges processing mode.
pub(all) enum EdgeMode {
  EdgeNone
  Duplicate
  Wrap
} derive(Eq)

///|
/// A displacement map filter primitive.
///
/// `feDisplacementMap` element in the SVG.
pub(all) struct FeDisplacementMap {
  input1 : FilterInput
  input2 : FilterInput
  scale : Float
  x_channel_selector : ColorChannel
  y_channel_selector : ColorChannel
}

///|
/// A color channel.
pub(all) enum ColorChannel {
  R
  G
  B
  A
} derive(Eq)

///|
/// A drop shadow filter primitive.
///
/// This is essentially `feGaussianBlur`, `feOffset` and `feFlood` joined together.
///
/// `feDropShadow` element in the SVG.
pub(all) struct FeDropShadow {
  input : FilterInput
  dx : Float
  dy : Float
  std_dev_x : PositiveF32
  std_dev_y : PositiveF32
  color : Color
  opacity : Opacity
}

///|
/// A flood filter primitive.
///
/// `feFlood` element in the SVG.
pub(all) struct FeFlood {
  color : Color
  opacity : Opacity
}

///|
/// A Gaussian blur filter primitive.
///
/// `feGaussianBlur` element in the SVG.
pub(all) struct FeGaussianBlur {
  input : FilterInput
  std_dev_x : PositiveF32
  std_dev_y : PositiveF32
}

///|
/// An image filter primitive.
///
/// `feImage` element in the SVG.
pub(all) struct FeImage {
  root : Group
}

///|
/// `feImage` children.
pub fn FeImage::root(self : FeImage) -> Group {
  self.root
}

///|
/// A diffuse lighting filter primitive.
///
/// `feDiffuseLighting` element in the SVG.
pub(all) struct FeDiffuseLighting {
  input : FilterInput
  surface_scale : Float
  diffuse_constant : Float
  lighting_color : Color
  light_source : LightSource
}

///|
/// A specular lighting filter primitive.
///
/// `feSpecularLighting` element in the SVG.
pub(all) struct FeSpecularLighting {
  input : FilterInput
  surface_scale : Float
  specular_constant : Float
  specular_exponent : Float
  lighting_color : Color
  light_source : LightSource
}

///|
/// A light source kind.
pub(all) enum LightSource {
  DistantLight(DistantLight)
  PointLight(PointLight)
  SpotLight(SpotLight)
}

///|
/// A distant light source.
///
/// `feDistantLight` element in the SVG.
pub(all) struct DistantLight {
  /// Direction angle for the light source on the XY plane (clockwise),
  /// in degrees from the x axis.
  azimuth : Float
  /// Direction angle for the light source from the XY plane towards the z axis, in degrees.
  elevation : Float
}

///|
/// A point light source.
///
/// `fePointLight` element in the SVG.
pub(all) struct PointLight {
  x : Float
  y : Float
  z : Float
}

///|
/// A spot light source.
///
/// `feSpotLight` element in the SVG.
pub(all) struct SpotLight {
  x : Float
  y : Float
  z : Float
  points_at_x : Float
  points_at_y : Float
  points_at_z : Float
  specular_exponent : PositiveF32
  limiting_cone_angle : Float?
}

///|
/// A merge filter primitive.
///
/// `feMerge` element in the SVG.
pub(all) struct FeMerge {
  inputs : Array[FilterInput]
}

///|
/// A morphology filter primitive.
///
/// `feMorphology` element in the SVG.
pub(all) struct FeMorphology {
  input : FilterInput
  operator : MorphologyOperator
  radius_x : PositiveF32
  radius_y : PositiveF32
}

///|
/// A morphology operation.
pub(all) enum MorphologyOperator {
  Erode
  Dilate
} derive(Eq)

///|
/// An offset filter primitive.
///
/// `feOffset` element in the SVG.
pub(all) struct FeOffset {
  input : FilterInput
  dx : Float
  dy : Float
}

///|
/// A tile filter primitive.
///
/// `feTile` element in the SVG.
pub(all) struct FeTile {
  input : FilterInput
}

///|
/// A turbulence generation filter primitive.
///
/// `feTurbulence` element in the SVG.
pub(all) struct FeTurbulence {
  base_frequency_x : PositiveF32
  base_frequency_y : PositiveF32
  num_octaves : UInt
  seed : Int
  stitch_tiles : Bool
  kind : TurbulenceKind
}

///|
/// A turbulence kind for the `feTurbulence` filter.
pub(all) enum TurbulenceKind {
  FractalNoise
  Turbulence
} derive(Eq)
