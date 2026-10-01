// Port of the eval-level parts of `typst-library/src/visualize/image/mod.rs`
// and `raster.rs`: the `ImageElem` field hooks and the format, fit and
// scaling types. Decoding (`RasterImage`, `SvgImage`, `PdfImage`) is a
// layout concern and not ported yet.

// ImageElem field hooks.

///|
/// `#[parse]` of `ImageElem::source`: the source is loaded eagerly so that
/// missing files are reported at construction.
///
/// The field stores the source (the user-visible part of
/// `Derived<DataSource, Loaded>`); the loaded data is not kept.
fn image_elem_source_parse(
  engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let source : @syntax.Spanned[DataSource] = args.expect_spanned("source")
  let _loaded = source.v.load(source.span, engine.world)
  Some(source.v.into_value())
}

///|
/// `#[parse]` of `ImageElem::icc`.
fn image_elem_icc_parse(
  engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let icc : @syntax.Spanned[Smart[DataSource]]? = args.named_spanned("icc")
  match icc {
    Some({ v: Custom(source), span, }) => {
      let _loaded = source.load(span, engine.world)
      Some(source.into_value())
    }
    Some({ v: Auto, .. }) => Some(Auto)
    None => None
  }
}

///|
fn image_elem_height_default() -> Value {
  Sizing::default().into_value()
}

///|
fn image_elem_fit_default() -> Value {
  ImageFit::Cover.into_value()
}

///|
/// How an image should adjust itself to a given area,
pub(all) enum ImageFit {
  /// The image should completely cover the area (preserves aspect ratio by
  /// cropping the image only horizontally or vertically). This is the
  /// default.
  Cover
  /// The image should be fully contained in the area (preserves aspect
  /// ratio; doesn't crop the image; one dimension can be narrower than
  /// specified).
  Contain
  /// The image should be stretched so that it exactly fills the area, even if
  /// this means that the image will be distorted (doesn't preserve aspect
  /// ratio and doesn't crop the image).
  Stretch
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for ImageFit with fn input() {
  Union([
    Value(
      Str("cover"),
      "The image should completely cover the area (preserves aspect ratio by cropping the image only horizontally or vertically). This is the default.",
    ),
    Value(
      Str("contain"),
      "The image should be fully contained in the area (preserves aspect ratio; doesn't crop the image; one dimension can be narrower than specified).",
    ),
    Value(
      Str("stretch"),
      "The image should be stretched so that it exactly fills the area, even if this means that the image will be distorted (doesn't preserve aspect ratio and doesn't crop the image).",
    ),
  ])
}

///|
pub impl Reflect for ImageFit with fn output() {
  ImageFit::input()
}

///|
pub impl Reflect for ImageFit with fn castable(v) {
  v is Str("cover" | "contain" | "stretch")
}

///|
pub impl IntoValue for ImageFit with fn into_value(self) {
  match self {
    Cover => Str("cover")
    Contain => Str("contain")
    Stretch => Str("stretch")
  }
}

///|
pub impl FromValue for ImageFit with fn from_value(v) {
  match v {
    Str("cover") => Cover
    Str("contain") => Contain
    Str("stretch") => Stretch
    v => raise HintedError(ImageFit::input().error(v))
  }
}

///|
/// A raster or vector image format.
pub(all) enum ImageFormat {
  /// A raster graphics format.
  Raster(RasterFormat)
  /// A vector graphics format.
  Vector(VectorFormat)
} derive(Eq, Hash, Debug)

///|
/// Try to detect the format of an image from data.
pub fn ImageFormat::detect(data : Bytes) -> ImageFormat? {
  if ExchangeFormat::detect(data) is Some(format) {
    return Some(Raster(Exchange(format)))
  }
  if image_is_svg(data) {
    return Some(Vector(Svg))
  }
  if image_is_pdf(data) {
    return Some(Vector(Pdf))
  }
  None
}

///|
/// The first (at most) 2048 bytes of the data.
fn image_head(data : Bytes) -> BytesView {
  data[:@cmp.minimum(data.length(), 2048)]
}

///|
/// Whether `needle` occurs in `haystack` (upstream `memchr::memmem::find`).
fn bytes_contains(haystack : BytesView, needle : Bytes) -> Bool {
  let n = needle.length()
  for i = 0; i + n <= haystack.length(); i = i + 1 {
    let mut matches = true
    for j = 0; j < n; j = j + 1 {
      if haystack[i + j] != needle[j] {
        matches = false
        break
      }
    }
    if matches {
      return true
    }
  }
  false
}

///|
/// Checks whether the data looks like a PDF file.
fn image_is_pdf(data : Bytes) -> Bool {
  bytes_contains(image_head(data), b"%PDF-")
}

///|
/// Checks whether the data looks like an SVG or a compressed SVG.
fn image_is_svg(data : Bytes) -> Bool {
  // Check for the gzip magic bytes. This check is perhaps a bit too
  // permissive as other formats than SVGZ could use gzip.
  if data.length() >= 2 && data[0] == b'\x1f' && data[1] == b'\x8b' {
    return true
  }

  // If the first 2048 bytes contain the SVG namespace declaration, we assume
  // that it's an SVG. Note that, if the SVG does not contain a namespace
  // declaration, usvg will reject it.
  bytes_contains(image_head(data), b"http://www.w3.org/2000/svg")
}

///|
/// Derive the image format from the file extension of a path.
pub fn determine_format_from_path(path : @syntax.VirtualPath) -> ImageFormat? {
  match path.extension() {
    // Raster formats
    Some("png") => Some(Raster(Exchange(Png)))
    Some("jpg" | "jpeg") => Some(Raster(Exchange(Jpg)))
    Some("gif") => Some(Raster(Exchange(Gif)))
    Some("webp") => Some(Raster(Exchange(Webp)))
    // Vector formats
    Some("svg" | "svgz") => Some(Vector(Svg))
    Some("pdf") => Some(Vector(Pdf))
    _ => None
  }
}

///|
pub impl Reflect for ImageFormat with fn input() {
  RasterFormat::input().union_with(VectorFormat::input())
}

///|
pub impl Reflect for ImageFormat with fn output() {
  RasterFormat::output().union_with(VectorFormat::output())
}

///|
pub impl Reflect for ImageFormat with fn castable(v) {
  RasterFormat::castable(v) || VectorFormat::castable(v)
}

///|
pub impl IntoValue for ImageFormat with fn into_value(self) {
  match self {
    Raster(v) => v.into_value()
    Vector(v) => v.into_value()
  }
}

///|
pub impl FromValue for ImageFormat with fn from_value(v) {
  if RasterFormat::castable(v) {
    Raster(RasterFormat::from_value(v))
  } else if VectorFormat::castable(v) {
    Vector(VectorFormat::from_value(v))
  } else {
    raise HintedError(ImageFormat::input().error(v))
  }
}

///|
/// A vector graphics format.
pub(all) enum VectorFormat {
  /// The vector graphics format of the web.
  Svg
  /// High-fidelity document and graphics format, with focus on exact
  /// reproduction in print.
  Pdf
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for VectorFormat with fn input() {
  Union([
    Value(Str("svg"), "The vector graphics format of the web."),
    Value(
      Str("pdf"),
      "High-fidelity document and graphics format, with focus on exact reproduction in print.",
    ),
  ])
}

///|
pub impl Reflect for VectorFormat with fn output() {
  VectorFormat::input()
}

///|
pub impl Reflect for VectorFormat with fn castable(v) {
  v is Str("svg" | "pdf")
}

///|
pub impl IntoValue for VectorFormat with fn into_value(self) {
  match self {
    Svg => Str("svg")
    Pdf => Str("pdf")
  }
}

///|
pub impl FromValue for VectorFormat with fn from_value(v) {
  match v {
    Str("svg") => Svg
    Str("pdf") => Pdf
    v => raise HintedError(VectorFormat::input().error(v))
  }
}

///|
/// The image scaling algorithm a viewer should use.
pub(all) enum ImageScaling {
  /// Scale with a smoothing algorithm such as bilinear interpolation.
  Smooth
  /// Scale with nearest neighbor or a similar algorithm to preserve the
  /// pixelated look of the image.
  Pixelated
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for ImageScaling with fn input() {
  Union([
    Value(
      Str("smooth"),
      "Scale with a smoothing algorithm such as bilinear interpolation.",
    ),
    Value(
      Str("pixelated"),
      "Scale with nearest neighbor or a similar algorithm to preserve the pixelated look of the image.",
    ),
  ])
}

///|
pub impl Reflect for ImageScaling with fn output() {
  ImageScaling::input()
}

///|
pub impl Reflect for ImageScaling with fn castable(v) {
  v is Str("smooth" | "pixelated")
}

///|
pub impl IntoValue for ImageScaling with fn into_value(self) {
  match self {
    Smooth => Str("smooth")
    Pixelated => Str("pixelated")
  }
}

///|
pub impl FromValue for ImageScaling with fn from_value(v) {
  match v {
    Str("smooth") => Smooth
    Str("pixelated") => Pixelated
    v => raise HintedError(ImageScaling::input().error(v))
  }
}

// raster.rs

///|
/// A raster graphics format.
pub(all) enum RasterFormat {
  /// A format typically used in image exchange.
  Exchange(ExchangeFormat)
  /// A format of raw pixel data.
  Pixel(PixelFormat)
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for RasterFormat with fn input() {
  ExchangeFormat::input().union_with(PixelFormat::input())
}

///|
pub impl Reflect for RasterFormat with fn output() {
  ExchangeFormat::output().union_with(PixelFormat::output())
}

///|
pub impl Reflect for RasterFormat with fn castable(v) {
  ExchangeFormat::castable(v) || PixelFormat::castable(v)
}

///|
pub impl IntoValue for RasterFormat with fn into_value(self) {
  match self {
    Exchange(v) => v.into_value()
    Pixel(v) => v.into_value()
  }
}

///|
pub impl FromValue for RasterFormat with fn from_value(v) {
  if ExchangeFormat::castable(v) {
    Exchange(ExchangeFormat::from_value(v))
  } else if PixelFormat::castable(v) {
    Pixel(PixelFormat::from_value(v))
  } else {
    raise HintedError(RasterFormat::input().error(v))
  }
}

///|
/// A raster format typically used in image exchange, with efficient encoding.
pub(all) enum ExchangeFormat {
  /// Raster format for illustrations and transparent graphics.
  Png
  /// Lossy raster format suitable for photos.
  Jpg
  /// Raster format that is typically used for short animated clips. Typst can
  /// load GIFs, but they will become static.
  Gif
  /// Raster format that supports both lossy and lossless compression.
  Webp
} derive(Eq, Hash, Debug)

///|
/// Try to detect the format of data in a buffer (upstream: `image`'s
/// `guess_format` restricted to the exchange formats).
pub fn ExchangeFormat::detect(data : Bytes) -> ExchangeFormat? {
  let starts_with = (magic : Bytes) => {
    if data.length() < magic.length() {
      return false
    }
    for i in 0..<magic.length() {
      if data[i] != magic[i] {
        return false
      }
    }
    true
  }
  if starts_with(b"\x89PNG\r\n\x1a\n") {
    Some(Png)
  } else if starts_with(b"\xff\xd8\xff") {
    Some(Jpg)
  } else if starts_with(b"GIF89a") || starts_with(b"GIF87a") {
    Some(Gif)
  } else if data.length() >= 12 &&
    starts_with(b"RIFF") &&
    data[8] == b'W' &&
    data[9] == b'E' &&
    data[10] == b'B' &&
    data[11] == b'P' {
    Some(Webp)
  } else {
    None
  }
}

///|
pub impl Reflect for ExchangeFormat with fn input() {
  Union([
    Value(
      Str("png"),
      "Raster format for illustrations and transparent graphics.",
    ),
    Value(Str("jpg"), "Lossy raster format suitable for photos."),
    Value(
      Str("gif"),
      "Raster format that is typically used for short animated clips. Typst can load GIFs, but they will become static.",
    ),
    Value(
      Str("webp"),
      "Raster format that supports both lossy and lossless compression.",
    ),
  ])
}

///|
pub impl Reflect for ExchangeFormat with fn output() {
  ExchangeFormat::input()
}

///|
pub impl Reflect for ExchangeFormat with fn castable(v) {
  v is Str("png" | "jpg" | "gif" | "webp")
}

///|
pub impl IntoValue for ExchangeFormat with fn into_value(self) {
  match self {
    Png => Str("png")
    Jpg => Str("jpg")
    Gif => Str("gif")
    Webp => Str("webp")
  }
}

///|
pub impl FromValue for ExchangeFormat with fn from_value(v) {
  match v {
    Str("png") => Png
    Str("jpg") => Jpg
    Str("gif") => Gif
    Str("webp") => Webp
    v => raise HintedError(ExchangeFormat::input().error(v))
  }
}

///|
/// Information that is needed to understand a pixmap buffer.
pub(all) struct PixelFormat {
  /// The channel encoding.
  encoding : PixelEncoding
  /// The pixel width.
  width : U32
  /// The pixel height.
  height : U32
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for PixelFormat with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for PixelFormat with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for PixelFormat with fn castable(v) {
  v is Dict(_)
}

///|
pub impl IntoValue for PixelFormat with fn into_value(self) {
  Dict(
    Dict::from_pairs([
      ("encoding", self.encoding.into_value()),
      ("width", self.width.into_value()),
      ("height", self.height.into_value()),
    ]),
  )
}

///|
pub impl FromValue for PixelFormat with fn from_value(v) {
  match v {
    Dict(dict) => {
      let dict = dict.copy()
      let format = {
        encoding: dict.take("encoding").cast(),
        width: dict.take("width").cast(),
        height: dict.take("height").cast(),
      }
      dict.finish(["encoding", "width", "height"])
      format
    }
    v => raise HintedError(PixelFormat::input().error(v))
  }
}

///|
/// Determines the channel encoding of raw pixel data.
pub(all) enum PixelEncoding {
  /// Three 8-bit channels: Red, green, blue.
  Rgb8
  /// Four 8-bit channels: Red, green, blue, alpha.
  Rgba8
  /// One 8-bit channel.
  Luma8
  /// Two 8-bit channels: Luma and alpha.
  Lumaa8
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for PixelEncoding with fn input() {
  Union([
    Value(Str("rgb8"), "Three 8-bit channels: Red, green, blue."),
    Value(Str("rgba8"), "Four 8-bit channels: Red, green, blue, alpha."),
    Value(Str("luma8"), "One 8-bit channel."),
    Value(Str("lumaa8"), "Two 8-bit channels: Luma and alpha."),
  ])
}

///|
pub impl Reflect for PixelEncoding with fn output() {
  PixelEncoding::input()
}

///|
pub impl Reflect for PixelEncoding with fn castable(v) {
  v is Str("rgb8" | "rgba8" | "luma8" | "lumaa8")
}

///|
pub impl IntoValue for PixelEncoding with fn into_value(self) {
  match self {
    Rgb8 => Str("rgb8")
    Rgba8 => Str("rgba8")
    Luma8 => Str("luma8")
    Lumaa8 => Str("lumaa8")
  }
}

///|
pub impl FromValue for PixelEncoding with fn from_value(v) {
  match v {
    Str("rgb8") => Rgb8
    Str("rgba8") => Rgba8
    Str("luma8") => Luma8
    Str("lumaa8") => Lumaa8
    v => raise HintedError(PixelEncoding::input().error(v))
  }
}
