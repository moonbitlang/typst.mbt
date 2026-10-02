// Port of `usvg` 0.47.0 `src/parser/svgtree/names.rs` (generated from it).
// Element and attribute IDs.

///|
/// An element ID.
pub(all) enum EId {
  A
  Circle
  ClipPath
  Defs
  Ellipse
  FeBlend
  FeColorMatrix
  FeComponentTransfer
  FeComposite
  FeConvolveMatrix
  FeDiffuseLighting
  FeDisplacementMap
  FeDistantLight
  FeDropShadow
  FeFlood
  FeFuncA
  FeFuncB
  FeFuncG
  FeFuncR
  FeGaussianBlur
  FeImage
  FeMerge
  FeMergeNode
  FeMorphology
  FeOffset
  FePointLight
  FeSpecularLighting
  FeSpotLight
  FeTile
  FeTurbulence
  Filter
  G
  Image
  Line
  LinearGradient
  Marker
  Mask
  Path
  Pattern
  Polygon
  Polyline
  RadialGradient
  Rect
  Stop
  Style
  Svg
  Switch
  Symbol
  Text
  TextPath
  Tref
  Tspan
  Use
} derive(Eq, Hash)

///|
/// Returns the ID for an element/attribute name.
pub fn EId::from_str(text : String) -> EId? {
  match text {
    "a" => Some(A)
    "circle" => Some(Circle)
    "clipPath" => Some(ClipPath)
    "defs" => Some(Defs)
    "ellipse" => Some(Ellipse)
    "feBlend" => Some(FeBlend)
    "feColorMatrix" => Some(FeColorMatrix)
    "feComponentTransfer" => Some(FeComponentTransfer)
    "feComposite" => Some(FeComposite)
    "feConvolveMatrix" => Some(FeConvolveMatrix)
    "feDiffuseLighting" => Some(FeDiffuseLighting)
    "feDisplacementMap" => Some(FeDisplacementMap)
    "feDistantLight" => Some(FeDistantLight)
    "feDropShadow" => Some(FeDropShadow)
    "feFlood" => Some(FeFlood)
    "feFuncA" => Some(FeFuncA)
    "feFuncB" => Some(FeFuncB)
    "feFuncG" => Some(FeFuncG)
    "feFuncR" => Some(FeFuncR)
    "feGaussianBlur" => Some(FeGaussianBlur)
    "feImage" => Some(FeImage)
    "feMerge" => Some(FeMerge)
    "feMergeNode" => Some(FeMergeNode)
    "feMorphology" => Some(FeMorphology)
    "feOffset" => Some(FeOffset)
    "fePointLight" => Some(FePointLight)
    "feSpecularLighting" => Some(FeSpecularLighting)
    "feSpotLight" => Some(FeSpotLight)
    "feTile" => Some(FeTile)
    "feTurbulence" => Some(FeTurbulence)
    "filter" => Some(Filter)
    "g" => Some(G)
    "image" => Some(Image)
    "line" => Some(Line)
    "linearGradient" => Some(LinearGradient)
    "marker" => Some(Marker)
    "mask" => Some(Mask)
    "path" => Some(Path)
    "pattern" => Some(Pattern)
    "polygon" => Some(Polygon)
    "polyline" => Some(Polyline)
    "radialGradient" => Some(RadialGradient)
    "rect" => Some(Rect)
    "stop" => Some(Stop)
    "style" => Some(Style)
    "svg" => Some(Svg)
    "switch" => Some(Switch)
    "symbol" => Some(Symbol)
    "text" => Some(Text)
    "textPath" => Some(TextPath)
    "tref" => Some(Tref)
    "tspan" => Some(Tspan)
    "use" => Some(Use)
    _ => None
  }
}

///|
/// Returns the original string.
pub fn EId::to_str(self : EId) -> String {
  match self {
    A => "a"
    Circle => "circle"
    ClipPath => "clipPath"
    Defs => "defs"
    Ellipse => "ellipse"
    FeBlend => "feBlend"
    FeColorMatrix => "feColorMatrix"
    FeComponentTransfer => "feComponentTransfer"
    FeComposite => "feComposite"
    FeConvolveMatrix => "feConvolveMatrix"
    FeDiffuseLighting => "feDiffuseLighting"
    FeDisplacementMap => "feDisplacementMap"
    FeDistantLight => "feDistantLight"
    FeDropShadow => "feDropShadow"
    FeFlood => "feFlood"
    FeFuncA => "feFuncA"
    FeFuncB => "feFuncB"
    FeFuncG => "feFuncG"
    FeFuncR => "feFuncR"
    FeGaussianBlur => "feGaussianBlur"
    FeImage => "feImage"
    FeMerge => "feMerge"
    FeMergeNode => "feMergeNode"
    FeMorphology => "feMorphology"
    FeOffset => "feOffset"
    FePointLight => "fePointLight"
    FeSpecularLighting => "feSpecularLighting"
    FeSpotLight => "feSpotLight"
    FeTile => "feTile"
    FeTurbulence => "feTurbulence"
    Filter => "filter"
    G => "g"
    Image => "image"
    Line => "line"
    LinearGradient => "linearGradient"
    Marker => "marker"
    Mask => "mask"
    Path => "path"
    Pattern => "pattern"
    Polygon => "polygon"
    Polyline => "polyline"
    RadialGradient => "radialGradient"
    Rect => "rect"
    Stop => "stop"
    Style => "style"
    Svg => "svg"
    Switch => "switch"
    Symbol => "symbol"
    Text => "text"
    TextPath => "textPath"
    Tref => "tref"
    Tspan => "tspan"
    Use => "use"
  }
}

///|
/// Upstream's `Debug` (the variant name).
pub fn EId::debug_name(self : EId) -> String {
  match self {
    A => "A"
    Circle => "Circle"
    ClipPath => "ClipPath"
    Defs => "Defs"
    Ellipse => "Ellipse"
    FeBlend => "FeBlend"
    FeColorMatrix => "FeColorMatrix"
    FeComponentTransfer => "FeComponentTransfer"
    FeComposite => "FeComposite"
    FeConvolveMatrix => "FeConvolveMatrix"
    FeDiffuseLighting => "FeDiffuseLighting"
    FeDisplacementMap => "FeDisplacementMap"
    FeDistantLight => "FeDistantLight"
    FeDropShadow => "FeDropShadow"
    FeFlood => "FeFlood"
    FeFuncA => "FeFuncA"
    FeFuncB => "FeFuncB"
    FeFuncG => "FeFuncG"
    FeFuncR => "FeFuncR"
    FeGaussianBlur => "FeGaussianBlur"
    FeImage => "FeImage"
    FeMerge => "FeMerge"
    FeMergeNode => "FeMergeNode"
    FeMorphology => "FeMorphology"
    FeOffset => "FeOffset"
    FePointLight => "FePointLight"
    FeSpecularLighting => "FeSpecularLighting"
    FeSpotLight => "FeSpotLight"
    FeTile => "FeTile"
    FeTurbulence => "FeTurbulence"
    Filter => "Filter"
    G => "G"
    Image => "Image"
    Line => "Line"
    LinearGradient => "LinearGradient"
    Marker => "Marker"
    Mask => "Mask"
    Path => "Path"
    Pattern => "Pattern"
    Polygon => "Polygon"
    Polyline => "Polyline"
    RadialGradient => "RadialGradient"
    Rect => "Rect"
    Stop => "Stop"
    Style => "Style"
    Svg => "Svg"
    Switch => "Switch"
    Symbol => "Symbol"
    Text => "Text"
    TextPath => "TextPath"
    Tref => "Tref"
    Tspan => "Tspan"
    Use => "Use"
  }
}

///|
/// An attribute ID.
pub(all) enum AId {
  AlignmentBaseline
  Amplitude
  Azimuth
  BackgroundColor
  BaseFrequency
  BaselineShift
  Bias
  Class
  Clip
  ClipPath
  ClipRule
  ClipPathUnits
  Color
  ColorInterpolation
  ColorInterpolationFilters
  ColorProfile
  ColorRendering
  Cx
  Cy
  D
  DiffuseConstant
  Direction
  Display
  Divisor
  DominantBaseline
  Dx
  Dy
  EdgeMode
  Elevation
  EnableBackground
  Exponent
  Fill
  FillOpacity
  FillRule
  Filter
  FilterUnits
  FloodColor
  FloodOpacity
  Font
  FontFamily
  FontFeatureSettings
  FontKerning
  FontOpticalSizing
  FontSize
  FontSizeAdjust
  FontStretch
  FontStyle
  FontSynthesis
  FontVariant
  FontVariantCaps
  FontVariantEastAsian
  FontVariantLigatures
  FontVariantNumeric
  FontVariantPosition
  FontVariationSettings
  FontWeight
  Fr
  Fx
  Fy
  GlyphOrientationHorizontal
  GlyphOrientationVertical
  GradientTransform
  GradientUnits
  Height
  Href
  Id
  ImageRendering
  In
  In2
  InlineSize
  Intercept
  Isolation
  K1
  K2
  K3
  K4
  KernelMatrix
  KernelUnitLength
  Kerning
  LengthAdjust
  LetterSpacing
  LightingColor
  LimitingConeAngle
  LineHeight
  MarkerEnd
  MarkerMid
  MarkerStart
  MarkerHeight
  MarkerUnits
  MarkerWidth
  Mask
  MaskBorder
  MaskBorderMode
  MaskBorderOutset
  MaskBorderRepeat
  MaskBorderSlice
  MaskBorderSource
  MaskBorderWidth
  MaskClip
  MaskComposite
  MaskImage
  MaskMode
  MaskOrigin
  MaskPosition
  MaskSize
  MaskType
  MaskContentUnits
  MaskUnits
  MixBlendMode
  Mode
  NumOctaves
  Offset
  Opacity
  Operator
  Order
  Orient
  Overflow
  PaintOrder
  Path
  PathLength
  PatternContentUnits
  PatternTransform
  PatternUnits
  Points
  PointsAtX
  PointsAtY
  PointsAtZ
  PreserveAlpha
  PreserveAspectRatio
  PrimitiveUnits
  R
  Radius
  RefX
  RefY
  RequiredExtensions
  RequiredFeatures
  Result
  Rotate
  Rx
  Ry
  Scale
  Seed
  ShapeImageThreshold
  ShapeInside
  ShapeMargin
  ShapePadding
  ShapeRendering
  ShapeSubtract
  Side
  Slope
  Space
  SpecularConstant
  SpecularExponent
  SpreadMethod
  StartOffset
  StdDeviation
  StitchTiles
  StopColor
  StopOpacity
  Stroke
  StrokeDasharray
  StrokeDashoffset
  StrokeLinecap
  StrokeLinejoin
  StrokeMiterlimit
  StrokeOpacity
  StrokeWidth
  Style
  SurfaceScale
  SystemLanguage
  TableValues
  TargetX
  TargetY
  TextAlign
  TextAlignLast
  TextAnchor
  TextDecoration
  TextDecorationColor
  TextDecorationFill
  TextDecorationLine
  TextDecorationStroke
  TextDecorationStyle
  TextIndent
  TextOrientation
  TextOverflow
  TextRendering
  TextUnderlinePosition
  TextLength
  Transform
  TransformBox
  TransformOrigin
  Type
  UnicodeBidi
  UnicodeRange
  Values
  VectorEffect
  ViewBox
  Visibility
  WhiteSpace
  Width
  WordSpacing
  WritingMode
  X
  X1
  X2
  XChannelSelector
  Y
  Y1
  Y2
  YChannelSelector
  Z
} derive(Eq, Hash)

///|
/// Returns the ID for an element/attribute name.
pub fn AId::from_str(text : String) -> AId? {
  match text {
    "alignment-baseline" => Some(AlignmentBaseline)
    "amplitude" => Some(Amplitude)
    "azimuth" => Some(Azimuth)
    "background-color" => Some(BackgroundColor)
    "baseFrequency" => Some(BaseFrequency)
    "baseline-shift" => Some(BaselineShift)
    "bias" => Some(Bias)
    "class" => Some(Class)
    "clip" => Some(Clip)
    "clip-path" => Some(ClipPath)
    "clip-rule" => Some(ClipRule)
    "clipPathUnits" => Some(ClipPathUnits)
    "color" => Some(Color)
    "color-interpolation" => Some(ColorInterpolation)
    "color-interpolation-filters" => Some(ColorInterpolationFilters)
    "color-profile" => Some(ColorProfile)
    "color-rendering" => Some(ColorRendering)
    "cx" => Some(Cx)
    "cy" => Some(Cy)
    "d" => Some(D)
    "diffuseConstant" => Some(DiffuseConstant)
    "direction" => Some(Direction)
    "display" => Some(Display)
    "divisor" => Some(Divisor)
    "dominant-baseline" => Some(DominantBaseline)
    "dx" => Some(Dx)
    "dy" => Some(Dy)
    "edgeMode" => Some(EdgeMode)
    "elevation" => Some(Elevation)
    "enable-background" => Some(EnableBackground)
    "exponent" => Some(Exponent)
    "fill" => Some(Fill)
    "fill-opacity" => Some(FillOpacity)
    "fill-rule" => Some(FillRule)
    "filter" => Some(Filter)
    "filterUnits" => Some(FilterUnits)
    "flood-color" => Some(FloodColor)
    "flood-opacity" => Some(FloodOpacity)
    "font" => Some(Font)
    "font-family" => Some(FontFamily)
    "font-feature-settings" => Some(FontFeatureSettings)
    "font-kerning" => Some(FontKerning)
    "font-optical-sizing" => Some(FontOpticalSizing)
    "font-size" => Some(FontSize)
    "font-size-adjust" => Some(FontSizeAdjust)
    "font-stretch" => Some(FontStretch)
    "font-style" => Some(FontStyle)
    "font-synthesis" => Some(FontSynthesis)
    "font-variant" => Some(FontVariant)
    "font-variant-caps" => Some(FontVariantCaps)
    "font-variant-east-asian" => Some(FontVariantEastAsian)
    "font-variant-ligatures" => Some(FontVariantLigatures)
    "font-variant-numeric" => Some(FontVariantNumeric)
    "font-variant-position" => Some(FontVariantPosition)
    "font-variation-settings" => Some(FontVariationSettings)
    "font-weight" => Some(FontWeight)
    "fr" => Some(Fr)
    "fx" => Some(Fx)
    "fy" => Some(Fy)
    "glyph-orientation-horizontal" => Some(GlyphOrientationHorizontal)
    "glyph-orientation-vertical" => Some(GlyphOrientationVertical)
    "gradientTransform" => Some(GradientTransform)
    "gradientUnits" => Some(GradientUnits)
    "height" => Some(Height)
    "href" => Some(Href)
    "id" => Some(Id)
    "image-rendering" => Some(ImageRendering)
    "in" => Some(In)
    "in2" => Some(In2)
    "inline-size" => Some(InlineSize)
    "intercept" => Some(Intercept)
    "isolation" => Some(Isolation)
    "k1" => Some(K1)
    "k2" => Some(K2)
    "k3" => Some(K3)
    "k4" => Some(K4)
    "kernelMatrix" => Some(KernelMatrix)
    "kernelUnitLength" => Some(KernelUnitLength)
    "kerning" => Some(Kerning)
    "lengthAdjust" => Some(LengthAdjust)
    "letter-spacing" => Some(LetterSpacing)
    "lighting-color" => Some(LightingColor)
    "limitingConeAngle" => Some(LimitingConeAngle)
    "line-height" => Some(LineHeight)
    "marker-end" => Some(MarkerEnd)
    "marker-mid" => Some(MarkerMid)
    "marker-start" => Some(MarkerStart)
    "markerHeight" => Some(MarkerHeight)
    "markerUnits" => Some(MarkerUnits)
    "markerWidth" => Some(MarkerWidth)
    "mask" => Some(Mask)
    "mask-border" => Some(MaskBorder)
    "mask-border-mode" => Some(MaskBorderMode)
    "mask-border-outset" => Some(MaskBorderOutset)
    "mask-border-repeat" => Some(MaskBorderRepeat)
    "mask-border-slice" => Some(MaskBorderSlice)
    "mask-border-source" => Some(MaskBorderSource)
    "mask-border-width" => Some(MaskBorderWidth)
    "mask-clip" => Some(MaskClip)
    "mask-composite" => Some(MaskComposite)
    "mask-image" => Some(MaskImage)
    "mask-mode" => Some(MaskMode)
    "mask-origin" => Some(MaskOrigin)
    "mask-position" => Some(MaskPosition)
    "mask-size" => Some(MaskSize)
    "mask-type" => Some(MaskType)
    "maskContentUnits" => Some(MaskContentUnits)
    "maskUnits" => Some(MaskUnits)
    "mix-blend-mode" => Some(MixBlendMode)
    "mode" => Some(Mode)
    "numOctaves" => Some(NumOctaves)
    "offset" => Some(Offset)
    "opacity" => Some(Opacity)
    "operator" => Some(Operator)
    "order" => Some(Order)
    "orient" => Some(Orient)
    "overflow" => Some(Overflow)
    "paint-order" => Some(PaintOrder)
    "path" => Some(Path)
    "pathLength" => Some(PathLength)
    "patternContentUnits" => Some(PatternContentUnits)
    "patternTransform" => Some(PatternTransform)
    "patternUnits" => Some(PatternUnits)
    "points" => Some(Points)
    "pointsAtX" => Some(PointsAtX)
    "pointsAtY" => Some(PointsAtY)
    "pointsAtZ" => Some(PointsAtZ)
    "preserveAlpha" => Some(PreserveAlpha)
    "preserveAspectRatio" => Some(PreserveAspectRatio)
    "primitiveUnits" => Some(PrimitiveUnits)
    "r" => Some(R)
    "radius" => Some(Radius)
    "refX" => Some(RefX)
    "refY" => Some(RefY)
    "requiredExtensions" => Some(RequiredExtensions)
    "requiredFeatures" => Some(RequiredFeatures)
    "result" => Some(Result)
    "rotate" => Some(Rotate)
    "rx" => Some(Rx)
    "ry" => Some(Ry)
    "scale" => Some(Scale)
    "seed" => Some(Seed)
    "shape-image-threshold" => Some(ShapeImageThreshold)
    "shape-inside" => Some(ShapeInside)
    "shape-margin" => Some(ShapeMargin)
    "shape-padding" => Some(ShapePadding)
    "shape-rendering" => Some(ShapeRendering)
    "shape-subtract" => Some(ShapeSubtract)
    "side" => Some(Side)
    "slope" => Some(Slope)
    "space" => Some(Space)
    "specularConstant" => Some(SpecularConstant)
    "specularExponent" => Some(SpecularExponent)
    "spreadMethod" => Some(SpreadMethod)
    "startOffset" => Some(StartOffset)
    "stdDeviation" => Some(StdDeviation)
    "stitchTiles" => Some(StitchTiles)
    "stop-color" => Some(StopColor)
    "stop-opacity" => Some(StopOpacity)
    "stroke" => Some(Stroke)
    "stroke-dasharray" => Some(StrokeDasharray)
    "stroke-dashoffset" => Some(StrokeDashoffset)
    "stroke-linecap" => Some(StrokeLinecap)
    "stroke-linejoin" => Some(StrokeLinejoin)
    "stroke-miterlimit" => Some(StrokeMiterlimit)
    "stroke-opacity" => Some(StrokeOpacity)
    "stroke-width" => Some(StrokeWidth)
    "style" => Some(Style)
    "surfaceScale" => Some(SurfaceScale)
    "systemLanguage" => Some(SystemLanguage)
    "tableValues" => Some(TableValues)
    "targetX" => Some(TargetX)
    "targetY" => Some(TargetY)
    "text-align" => Some(TextAlign)
    "text-align-last" => Some(TextAlignLast)
    "text-anchor" => Some(TextAnchor)
    "text-decoration" => Some(TextDecoration)
    "text-decoration-color" => Some(TextDecorationColor)
    "text-decoration-fill" => Some(TextDecorationFill)
    "text-decoration-line" => Some(TextDecorationLine)
    "text-decoration-stroke" => Some(TextDecorationStroke)
    "text-decoration-style" => Some(TextDecorationStyle)
    "text-indent" => Some(TextIndent)
    "text-orientation" => Some(TextOrientation)
    "text-overflow" => Some(TextOverflow)
    "text-rendering" => Some(TextRendering)
    "text-underline-position" => Some(TextUnderlinePosition)
    "textLength" => Some(TextLength)
    "transform" => Some(Transform)
    "transform-box" => Some(TransformBox)
    "transform-origin" => Some(TransformOrigin)
    "type" => Some(Type)
    "unicode-bidi" => Some(UnicodeBidi)
    "unicode-range" => Some(UnicodeRange)
    "values" => Some(Values)
    "vector-effect" => Some(VectorEffect)
    "viewBox" => Some(ViewBox)
    "visibility" => Some(Visibility)
    "white-space" => Some(WhiteSpace)
    "width" => Some(Width)
    "word-spacing" => Some(WordSpacing)
    "writing-mode" => Some(WritingMode)
    "x" => Some(X)
    "x1" => Some(X1)
    "x2" => Some(X2)
    "xChannelSelector" => Some(XChannelSelector)
    "y" => Some(Y)
    "y1" => Some(Y1)
    "y2" => Some(Y2)
    "yChannelSelector" => Some(YChannelSelector)
    "z" => Some(Z)
    _ => None
  }
}

///|
/// Returns the original string.
pub fn AId::to_str(self : AId) -> String {
  match self {
    AlignmentBaseline => "alignment-baseline"
    Amplitude => "amplitude"
    Azimuth => "azimuth"
    BackgroundColor => "background-color"
    BaseFrequency => "baseFrequency"
    BaselineShift => "baseline-shift"
    Bias => "bias"
    Class => "class"
    Clip => "clip"
    ClipPath => "clip-path"
    ClipRule => "clip-rule"
    ClipPathUnits => "clipPathUnits"
    Color => "color"
    ColorInterpolation => "color-interpolation"
    ColorInterpolationFilters => "color-interpolation-filters"
    ColorProfile => "color-profile"
    ColorRendering => "color-rendering"
    Cx => "cx"
    Cy => "cy"
    D => "d"
    DiffuseConstant => "diffuseConstant"
    Direction => "direction"
    Display => "display"
    Divisor => "divisor"
    DominantBaseline => "dominant-baseline"
    Dx => "dx"
    Dy => "dy"
    EdgeMode => "edgeMode"
    Elevation => "elevation"
    EnableBackground => "enable-background"
    Exponent => "exponent"
    Fill => "fill"
    FillOpacity => "fill-opacity"
    FillRule => "fill-rule"
    Filter => "filter"
    FilterUnits => "filterUnits"
    FloodColor => "flood-color"
    FloodOpacity => "flood-opacity"
    Font => "font"
    FontFamily => "font-family"
    FontFeatureSettings => "font-feature-settings"
    FontKerning => "font-kerning"
    FontOpticalSizing => "font-optical-sizing"
    FontSize => "font-size"
    FontSizeAdjust => "font-size-adjust"
    FontStretch => "font-stretch"
    FontStyle => "font-style"
    FontSynthesis => "font-synthesis"
    FontVariant => "font-variant"
    FontVariantCaps => "font-variant-caps"
    FontVariantEastAsian => "font-variant-east-asian"
    FontVariantLigatures => "font-variant-ligatures"
    FontVariantNumeric => "font-variant-numeric"
    FontVariantPosition => "font-variant-position"
    FontVariationSettings => "font-variation-settings"
    FontWeight => "font-weight"
    Fr => "fr"
    Fx => "fx"
    Fy => "fy"
    GlyphOrientationHorizontal => "glyph-orientation-horizontal"
    GlyphOrientationVertical => "glyph-orientation-vertical"
    GradientTransform => "gradientTransform"
    GradientUnits => "gradientUnits"
    Height => "height"
    Href => "href"
    Id => "id"
    ImageRendering => "image-rendering"
    In => "in"
    In2 => "in2"
    InlineSize => "inline-size"
    Intercept => "intercept"
    Isolation => "isolation"
    K1 => "k1"
    K2 => "k2"
    K3 => "k3"
    K4 => "k4"
    KernelMatrix => "kernelMatrix"
    KernelUnitLength => "kernelUnitLength"
    Kerning => "kerning"
    LengthAdjust => "lengthAdjust"
    LetterSpacing => "letter-spacing"
    LightingColor => "lighting-color"
    LimitingConeAngle => "limitingConeAngle"
    LineHeight => "line-height"
    MarkerEnd => "marker-end"
    MarkerMid => "marker-mid"
    MarkerStart => "marker-start"
    MarkerHeight => "markerHeight"
    MarkerUnits => "markerUnits"
    MarkerWidth => "markerWidth"
    Mask => "mask"
    MaskBorder => "mask-border"
    MaskBorderMode => "mask-border-mode"
    MaskBorderOutset => "mask-border-outset"
    MaskBorderRepeat => "mask-border-repeat"
    MaskBorderSlice => "mask-border-slice"
    MaskBorderSource => "mask-border-source"
    MaskBorderWidth => "mask-border-width"
    MaskClip => "mask-clip"
    MaskComposite => "mask-composite"
    MaskImage => "mask-image"
    MaskMode => "mask-mode"
    MaskOrigin => "mask-origin"
    MaskPosition => "mask-position"
    MaskSize => "mask-size"
    MaskType => "mask-type"
    MaskContentUnits => "maskContentUnits"
    MaskUnits => "maskUnits"
    MixBlendMode => "mix-blend-mode"
    Mode => "mode"
    NumOctaves => "numOctaves"
    Offset => "offset"
    Opacity => "opacity"
    Operator => "operator"
    Order => "order"
    Orient => "orient"
    Overflow => "overflow"
    PaintOrder => "paint-order"
    Path => "path"
    PathLength => "pathLength"
    PatternContentUnits => "patternContentUnits"
    PatternTransform => "patternTransform"
    PatternUnits => "patternUnits"
    Points => "points"
    PointsAtX => "pointsAtX"
    PointsAtY => "pointsAtY"
    PointsAtZ => "pointsAtZ"
    PreserveAlpha => "preserveAlpha"
    PreserveAspectRatio => "preserveAspectRatio"
    PrimitiveUnits => "primitiveUnits"
    R => "r"
    Radius => "radius"
    RefX => "refX"
    RefY => "refY"
    RequiredExtensions => "requiredExtensions"
    RequiredFeatures => "requiredFeatures"
    Result => "result"
    Rotate => "rotate"
    Rx => "rx"
    Ry => "ry"
    Scale => "scale"
    Seed => "seed"
    ShapeImageThreshold => "shape-image-threshold"
    ShapeInside => "shape-inside"
    ShapeMargin => "shape-margin"
    ShapePadding => "shape-padding"
    ShapeRendering => "shape-rendering"
    ShapeSubtract => "shape-subtract"
    Side => "side"
    Slope => "slope"
    Space => "space"
    SpecularConstant => "specularConstant"
    SpecularExponent => "specularExponent"
    SpreadMethod => "spreadMethod"
    StartOffset => "startOffset"
    StdDeviation => "stdDeviation"
    StitchTiles => "stitchTiles"
    StopColor => "stop-color"
    StopOpacity => "stop-opacity"
    Stroke => "stroke"
    StrokeDasharray => "stroke-dasharray"
    StrokeDashoffset => "stroke-dashoffset"
    StrokeLinecap => "stroke-linecap"
    StrokeLinejoin => "stroke-linejoin"
    StrokeMiterlimit => "stroke-miterlimit"
    StrokeOpacity => "stroke-opacity"
    StrokeWidth => "stroke-width"
    Style => "style"
    SurfaceScale => "surfaceScale"
    SystemLanguage => "systemLanguage"
    TableValues => "tableValues"
    TargetX => "targetX"
    TargetY => "targetY"
    TextAlign => "text-align"
    TextAlignLast => "text-align-last"
    TextAnchor => "text-anchor"
    TextDecoration => "text-decoration"
    TextDecorationColor => "text-decoration-color"
    TextDecorationFill => "text-decoration-fill"
    TextDecorationLine => "text-decoration-line"
    TextDecorationStroke => "text-decoration-stroke"
    TextDecorationStyle => "text-decoration-style"
    TextIndent => "text-indent"
    TextOrientation => "text-orientation"
    TextOverflow => "text-overflow"
    TextRendering => "text-rendering"
    TextUnderlinePosition => "text-underline-position"
    TextLength => "textLength"
    Transform => "transform"
    TransformBox => "transform-box"
    TransformOrigin => "transform-origin"
    Type => "type"
    UnicodeBidi => "unicode-bidi"
    UnicodeRange => "unicode-range"
    Values => "values"
    VectorEffect => "vector-effect"
    ViewBox => "viewBox"
    Visibility => "visibility"
    WhiteSpace => "white-space"
    Width => "width"
    WordSpacing => "word-spacing"
    WritingMode => "writing-mode"
    X => "x"
    X1 => "x1"
    X2 => "x2"
    XChannelSelector => "xChannelSelector"
    Y => "y"
    Y1 => "y1"
    Y2 => "y2"
    YChannelSelector => "yChannelSelector"
    Z => "z"
  }
}

///|
/// Upstream's `Debug` (the variant name).
pub fn AId::debug_name(self : AId) -> String {
  match self {
    AlignmentBaseline => "AlignmentBaseline"
    Amplitude => "Amplitude"
    Azimuth => "Azimuth"
    BackgroundColor => "BackgroundColor"
    BaseFrequency => "BaseFrequency"
    BaselineShift => "BaselineShift"
    Bias => "Bias"
    Class => "Class"
    Clip => "Clip"
    ClipPath => "ClipPath"
    ClipRule => "ClipRule"
    ClipPathUnits => "ClipPathUnits"
    Color => "Color"
    ColorInterpolation => "ColorInterpolation"
    ColorInterpolationFilters => "ColorInterpolationFilters"
    ColorProfile => "ColorProfile"
    ColorRendering => "ColorRendering"
    Cx => "Cx"
    Cy => "Cy"
    D => "D"
    DiffuseConstant => "DiffuseConstant"
    Direction => "Direction"
    Display => "Display"
    Divisor => "Divisor"
    DominantBaseline => "DominantBaseline"
    Dx => "Dx"
    Dy => "Dy"
    EdgeMode => "EdgeMode"
    Elevation => "Elevation"
    EnableBackground => "EnableBackground"
    Exponent => "Exponent"
    Fill => "Fill"
    FillOpacity => "FillOpacity"
    FillRule => "FillRule"
    Filter => "Filter"
    FilterUnits => "FilterUnits"
    FloodColor => "FloodColor"
    FloodOpacity => "FloodOpacity"
    Font => "Font"
    FontFamily => "FontFamily"
    FontFeatureSettings => "FontFeatureSettings"
    FontKerning => "FontKerning"
    FontOpticalSizing => "FontOpticalSizing"
    FontSize => "FontSize"
    FontSizeAdjust => "FontSizeAdjust"
    FontStretch => "FontStretch"
    FontStyle => "FontStyle"
    FontSynthesis => "FontSynthesis"
    FontVariant => "FontVariant"
    FontVariantCaps => "FontVariantCaps"
    FontVariantEastAsian => "FontVariantEastAsian"
    FontVariantLigatures => "FontVariantLigatures"
    FontVariantNumeric => "FontVariantNumeric"
    FontVariantPosition => "FontVariantPosition"
    FontVariationSettings => "FontVariationSettings"
    FontWeight => "FontWeight"
    Fr => "Fr"
    Fx => "Fx"
    Fy => "Fy"
    GlyphOrientationHorizontal => "GlyphOrientationHorizontal"
    GlyphOrientationVertical => "GlyphOrientationVertical"
    GradientTransform => "GradientTransform"
    GradientUnits => "GradientUnits"
    Height => "Height"
    Href => "Href"
    Id => "Id"
    ImageRendering => "ImageRendering"
    In => "In"
    In2 => "In2"
    InlineSize => "InlineSize"
    Intercept => "Intercept"
    Isolation => "Isolation"
    K1 => "K1"
    K2 => "K2"
    K3 => "K3"
    K4 => "K4"
    KernelMatrix => "KernelMatrix"
    KernelUnitLength => "KernelUnitLength"
    Kerning => "Kerning"
    LengthAdjust => "LengthAdjust"
    LetterSpacing => "LetterSpacing"
    LightingColor => "LightingColor"
    LimitingConeAngle => "LimitingConeAngle"
    LineHeight => "LineHeight"
    MarkerEnd => "MarkerEnd"
    MarkerMid => "MarkerMid"
    MarkerStart => "MarkerStart"
    MarkerHeight => "MarkerHeight"
    MarkerUnits => "MarkerUnits"
    MarkerWidth => "MarkerWidth"
    Mask => "Mask"
    MaskBorder => "MaskBorder"
    MaskBorderMode => "MaskBorderMode"
    MaskBorderOutset => "MaskBorderOutset"
    MaskBorderRepeat => "MaskBorderRepeat"
    MaskBorderSlice => "MaskBorderSlice"
    MaskBorderSource => "MaskBorderSource"
    MaskBorderWidth => "MaskBorderWidth"
    MaskClip => "MaskClip"
    MaskComposite => "MaskComposite"
    MaskImage => "MaskImage"
    MaskMode => "MaskMode"
    MaskOrigin => "MaskOrigin"
    MaskPosition => "MaskPosition"
    MaskSize => "MaskSize"
    MaskType => "MaskType"
    MaskContentUnits => "MaskContentUnits"
    MaskUnits => "MaskUnits"
    MixBlendMode => "MixBlendMode"
    Mode => "Mode"
    NumOctaves => "NumOctaves"
    Offset => "Offset"
    Opacity => "Opacity"
    Operator => "Operator"
    Order => "Order"
    Orient => "Orient"
    Overflow => "Overflow"
    PaintOrder => "PaintOrder"
    Path => "Path"
    PathLength => "PathLength"
    PatternContentUnits => "PatternContentUnits"
    PatternTransform => "PatternTransform"
    PatternUnits => "PatternUnits"
    Points => "Points"
    PointsAtX => "PointsAtX"
    PointsAtY => "PointsAtY"
    PointsAtZ => "PointsAtZ"
    PreserveAlpha => "PreserveAlpha"
    PreserveAspectRatio => "PreserveAspectRatio"
    PrimitiveUnits => "PrimitiveUnits"
    R => "R"
    Radius => "Radius"
    RefX => "RefX"
    RefY => "RefY"
    RequiredExtensions => "RequiredExtensions"
    RequiredFeatures => "RequiredFeatures"
    Result => "Result"
    Rotate => "Rotate"
    Rx => "Rx"
    Ry => "Ry"
    Scale => "Scale"
    Seed => "Seed"
    ShapeImageThreshold => "ShapeImageThreshold"
    ShapeInside => "ShapeInside"
    ShapeMargin => "ShapeMargin"
    ShapePadding => "ShapePadding"
    ShapeRendering => "ShapeRendering"
    ShapeSubtract => "ShapeSubtract"
    Side => "Side"
    Slope => "Slope"
    Space => "Space"
    SpecularConstant => "SpecularConstant"
    SpecularExponent => "SpecularExponent"
    SpreadMethod => "SpreadMethod"
    StartOffset => "StartOffset"
    StdDeviation => "StdDeviation"
    StitchTiles => "StitchTiles"
    StopColor => "StopColor"
    StopOpacity => "StopOpacity"
    Stroke => "Stroke"
    StrokeDasharray => "StrokeDasharray"
    StrokeDashoffset => "StrokeDashoffset"
    StrokeLinecap => "StrokeLinecap"
    StrokeLinejoin => "StrokeLinejoin"
    StrokeMiterlimit => "StrokeMiterlimit"
    StrokeOpacity => "StrokeOpacity"
    StrokeWidth => "StrokeWidth"
    Style => "Style"
    SurfaceScale => "SurfaceScale"
    SystemLanguage => "SystemLanguage"
    TableValues => "TableValues"
    TargetX => "TargetX"
    TargetY => "TargetY"
    TextAlign => "TextAlign"
    TextAlignLast => "TextAlignLast"
    TextAnchor => "TextAnchor"
    TextDecoration => "TextDecoration"
    TextDecorationColor => "TextDecorationColor"
    TextDecorationFill => "TextDecorationFill"
    TextDecorationLine => "TextDecorationLine"
    TextDecorationStroke => "TextDecorationStroke"
    TextDecorationStyle => "TextDecorationStyle"
    TextIndent => "TextIndent"
    TextOrientation => "TextOrientation"
    TextOverflow => "TextOverflow"
    TextRendering => "TextRendering"
    TextUnderlinePosition => "TextUnderlinePosition"
    TextLength => "TextLength"
    Transform => "Transform"
    TransformBox => "TransformBox"
    TransformOrigin => "TransformOrigin"
    Type => "Type"
    UnicodeBidi => "UnicodeBidi"
    UnicodeRange => "UnicodeRange"
    Values => "Values"
    VectorEffect => "VectorEffect"
    ViewBox => "ViewBox"
    Visibility => "Visibility"
    WhiteSpace => "WhiteSpace"
    Width => "Width"
    WordSpacing => "WordSpacing"
    WritingMode => "WritingMode"
    X => "X"
    X1 => "X1"
    X2 => "X2"
    XChannelSelector => "XChannelSelector"
    Y => "Y"
    Y1 => "Y1"
    Y2 => "Y2"
    YChannelSelector => "YChannelSelector"
    Z => "Z"
  }
}
