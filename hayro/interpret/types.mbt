// Port of `hayro-interpret/src/types.rs`.

///|
/// A clip path.
pub(all) struct ClipPath {
  /// The clipping path.
  path : @kurbo.BezPath
  /// The fill rule.
  fill : FillRule
}

///|
pub impl CacheKey for ClipPath with fn cache_key(self) {
  // Upstream hashes `(path.to_svg(), fill)`; hashing the coordinates' bits is
  // equivalent for identity purposes.
  hash128(h => {
    for el in self.path.elements() {
      match el {
        MoveTo(p) => {
          h.write_u8(b'M')
          h.write_f64(p.x)
          h.write_f64(p.y)
        }
        LineTo(p) => {
          h.write_u8(b'L')
          h.write_f64(p.x)
          h.write_f64(p.y)
        }
        QuadTo(p1, p2) => {
          h.write_u8(b'Q')
          h.write_f64(p1.x)
          h.write_f64(p1.y)
          h.write_f64(p2.x)
          h.write_f64(p2.y)
        }
        CurveTo(p1, p2, p3) => {
          h.write_u8(b'C')
          h.write_f64(p1.x)
          h.write_f64(p1.y)
          h.write_f64(p2.x)
          h.write_f64(p2.y)
          h.write_f64(p3.x)
          h.write_f64(p3.y)
        }
        ClosePath => h.write_u8(b'Z')
      }
    }
    h.write_u8(
      match self.fill {
        NonZero => b'\x00'
        EvenOdd => b'\x01'
      },
    )
  })
}

///|
/// A stencil image.
pub struct StencilImage {
  priv paint : Paint
  priv image_xobject : ImageXObject
}

///|
/// Perform some operation with the stencil data of the image.
///
/// The second argument allows you to give the image decoder a hint for
/// what resolution of the image you want to have. Note that this does not
/// mean that the resulting image will have that dimension. Instead, it allows
/// the image decoder to extract a lower-resolution version of the image in
/// certain cases.
pub fn StencilImage::with_stencil(
  self : StencilImage,
  func : (LumaData, Paint) -> Unit,
  target_dimension : (Int, Int)?,
) -> Unit {
  if self.image_xobject.decoded_mask(target_dimension) is Some(decoded) {
    func(decoded.luma, self.paint)
  }
}

///|
#doc(hidden)
pub fn StencilImage::width(self : StencilImage) -> Int {
  self.image_xobject.width()
}

///|
#doc(hidden)
pub fn StencilImage::height(self : StencilImage) -> Int {
  self.image_xobject.height()
}

///|
pub impl CacheKey for StencilImage with fn cache_key(self) {
  CacheKey::cache_key(self.image_xobject)
}

///|
/// A raster image.
pub struct RasterImage {
  priv obj : ImageXObject
}

///|
/// Perform some operation with the RGB and alpha channel of the image.
///
/// The second argument allows you to give the image decoder a hint for
/// what resolution of the image you want to have (see
/// [StencilImage::with_stencil]).
pub fn RasterImage::with_rgba(
  self : RasterImage,
  func : (ImageData, LumaData?) -> Unit,
  target_dimension : (Int, Int)?,
) -> Unit {
  if self.obj.decoded_raster(target_dimension) is Some(decoded) {
    func(decoded.image, decoded.alpha)
  }
}

///|
/// Return the underlying stream object.
///
/// This allows you to get access to the raw encoded image data, without
/// doing any decoding.
pub fn RasterImage::stream(self : RasterImage) -> @hayro_syntax.Stream {
  self.obj.stream()
}

///|
#doc(hidden)
pub fn RasterImage::width(self : RasterImage) -> Int {
  self.obj.width()
}

///|
#doc(hidden)
pub fn RasterImage::height(self : RasterImage) -> Int {
  self.obj.height()
}

///|
pub impl CacheKey for RasterImage with fn cache_key(self) {
  CacheKey::cache_key(self.obj)
}

///|
/// A type of image.
pub enum Image {
  /// A stencil image.
  Stencil(StencilImage)
  /// A normal raster image.
  Raster(RasterImage)
}

///|
#doc(hidden)
pub fn Image::width(self : Image) -> Int {
  match self {
    Stencil(s) => s.width()
    Raster(r) => r.width()
  }
}

///|
#doc(hidden)
pub fn Image::height(self : Image) -> Int {
  match self {
    Stencil(s) => s.height()
    Raster(r) => r.height()
  }
}

///|
pub impl CacheKey for Image with fn cache_key(self) {
  match self {
    Stencil(i) => CacheKey::cache_key(i)
    Raster(i) => CacheKey::cache_key(i)
  }
}

///|
/// A structure holding 3-channel RGB data.
pub(all) struct RgbData {
  /// The actual data. It is guaranteed to have the length width * height * 3.
  data : Bytes
  /// The width.
  width : Int
  /// The height.
  height : Int
  /// Whether the image should be interpolated.
  interpolate : Bool
  /// Additional scaling factors to apply to the image.
  ///
  /// In most cases, those factors will just be 1.0, and you can
  /// ignore them. There are two situations in which they will not be equal
  /// to 1:
  /// 1) The PDF provided wrong metadata about the width/height of the image,
  ///    which needs to be corrected
  /// 2) A lower resolution of the image was requested, in which case it needs
  ///    to be scaled up so that it still covers the same area.
  ///
  /// The first number indicates the x scaling factor, the second number the
  /// y scaling factor.
  scale_factors : (Float, Float)
}

///|
/// A structure holding 1-channel luma data.
pub(all) struct LumaData {
  /// The actual data. It is guaranteed to have the length width * height.
  data : Bytes
  /// The width.
  width : Int
  /// The height.
  height : Int
  /// Whether the image should be interpolated.
  interpolate : Bool
  /// Additional scaling factors to apply to the image (see [RgbData]).
  scale_factors : (Float, Float)
}

///|
/// The color data of a raster image, either 3-channel RGB or 1-channel luma.
pub(all) enum ImageData {
  /// 3-channel RGB data.
  Rgb(RgbData)
  /// 1-channel grayscale data.
  Luma(LumaData)
}

///|
/// The width of the image.
pub fn ImageData::width(self : ImageData) -> Int {
  match self {
    Rgb(d) => d.width
    Luma(d) => d.width
  }
}

///|
/// The height of the image.
pub fn ImageData::height(self : ImageData) -> Int {
  match self {
    Rgb(d) => d.height
    Luma(d) => d.height
  }
}

///|
/// Whether the image should be interpolated.
pub fn ImageData::interpolate(self : ImageData) -> Bool {
  match self {
    Rgb(d) => d.interpolate
    Luma(d) => d.interpolate
  }
}

///|
/// The scaling factors of the image.
pub fn ImageData::scale_factors(self : ImageData) -> (Float, Float) {
  match self {
    Rgb(d) => d.scale_factors
    Luma(d) => d.scale_factors
  }
}

///|
/// A type of paint.
pub(all) enum Paint {
  /// A solid RGBA color.
  Color(Color)
  /// A PDF pattern.
  Pattern(Pattern)
}

///|
pub impl CacheKey for Paint with fn cache_key(self) {
  match self {
    Color(c) => {
      // TODO: We should actually cache the color with color space etc., not
      // just the RGBA8 version.
      let rgba8 = c.to_rgba().to_rgba8()
      hash128(h => {
        for b in rgba8 {
          h.write_u8(b)
        }
      })
    }
    Pattern(p) => CacheKey::cache_key(p)
  }
}

///|
/// Properties for a painted drawing operation.
pub(all) struct DrawProps {
  /// The transform.
  transform : @kurbo.Affine
  /// The paint.
  paint : Paint
  /// The soft mask.
  soft_mask : SoftMask?
  /// The blend mode.
  blend_mode : BlendMode
}

///|
/// Properties for an image drawing operation.
pub(all) struct ImageDrawProps {
  /// The transform.
  transform : @kurbo.Affine
  /// The soft mask.
  soft_mask : SoftMask?
  /// The blend mode.
  blend_mode : BlendMode
}

///|
/// The draw mode.
pub(all) enum DrawMode {
  /// Draw using a fill.
  Fill(FillRule)
  /// Draw using a stroke.
  Stroke(StrokeProps)
  /// Draw using both fill and stroke.
  FillAndStroke(FillRule, StrokeProps)
  /// Invisible text (for text extraction but not visual rendering).
  Invisible
}

///|
/// Stroke properties.
pub(all) struct StrokeProps {
  /// The line width.
  line_width : Float
  /// The line cap.
  line_cap : @kurbo.Cap
  /// The line join.
  line_join : @kurbo.Join
  /// The miter limit.
  miter_limit : Float
  /// The dash array.
  dash_array : Array[Float]
  /// The dash offset.
  dash_offset : Float
}

///|
pub impl Default for StrokeProps with fn default() {
  {
    line_width: 1.0,
    line_cap: Butt,
    line_join: Miter,
    miter_limit: 10.0,
    dash_array: [],
    dash_offset: 0.0,
  }
}

///|
pub extend StrokeProps with Default::{default}

///|
/// A fill rule.
pub(all) enum FillRule {
  /// Non-zero filling.
  NonZero
  /// Even-odd filling.
  EvenOdd
} derive(Eq, Hash, Debug)

///|
/// A blend mode.
pub(all) enum BlendMode {
  /// Normal blend mode (default).
  Normal
  /// Multiply blend mode.
  Multiply
  /// Screen blend mode.
  Screen
  /// Overlay blend mode.
  Overlay
  /// Darken blend mode.
  Darken
  /// Lighten blend mode.
  Lighten
  /// `ColorDodge` blend mode.
  ColorDodge
  /// `ColorBurn` blend mode.
  ColorBurn
  /// `HardLight` blend mode.
  HardLight
  /// `SoftLight` blend mode.
  SoftLight
  /// Difference blend mode.
  Difference
  /// Exclusion blend mode.
  Exclusion
  /// Hue blend mode.
  Hue
  /// Saturation blend mode.
  Saturation
  /// Color blend mode.
  Color
  /// Luminosity blend mode.
  Luminosity
} derive(Eq, Hash, Debug)

///|
pub impl Default for BlendMode with fn default() {
  Normal
}
