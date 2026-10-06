// Port of `usvg` 0.47.0 `src/parser/mod.rs` and `src/parser/options.rs`:
// parsing entry points and processing options.
//
// `usvg` (micro SVG) is an SVG parser that tries to solve most of SVG
// complexity: it parses an input SVG into a strongly-typed tree structure
// were all the elements, attributes, references and other SVG features are
// already resolved and presented in the simplest way possible.
//
// Logging (`log::warn!`) is dropped.

///|
/// List of all errors.
pub(all) suberror UsvgError {
  /// Only UTF-8 content are supported.
  NotAnUtf8Str
  /// Compressed SVG must use the GZip algorithm.
  MalformedGZip
  /// We do not allow SVG with more than 1_000_000 elements for security reasons.
  ElementsLimitReached
  /// SVG doesn't have a valid size.
  ///
  /// Occurs when width and/or height are <= 0.
  ///
  /// Also occurs if width, height and viewBox are not set.
  InvalidSize
  /// Failed to parse an SVG data.
  ParsingFailed(@xml.XmlError)
}

///|
pub impl Show for UsvgError with fn output(self, logger) {
  match self {
    NotAnUtf8Str =>
      logger.write_string("provided data has not an UTF-8 encoding")
    MalformedGZip =>
      logger.write_string("provided data has a malformed GZip content")
    ElementsLimitReached =>
      logger.write_string("the maximum number of SVG elements has been reached")
    InvalidSize => logger.write_string("SVG has an invalid size")
    ParsingFailed(e) =>
      logger.write_string("SVG data parsing failed cause \{e.to_string()}")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UsvgError with Show::{to_string, output}

///|
/// Processing options.
pub(all) struct Options {
  /// Directory that will be used during relative paths resolving.
  ///
  /// Default: `None`
  resources_dir : String?
  /// Target DPI.
  ///
  /// Impacts units conversion.
  ///
  /// Default: 96.0
  dpi : Float
  /// A default font family.
  ///
  /// Will be used when no `font-family` attribute is set in the SVG.
  ///
  /// Default: Times New Roman
  font_family : String
  /// A default font size.
  ///
  /// Will be used when no `font-size` attribute is set in the SVG.
  ///
  /// Default: 12
  font_size : Float
  /// A list of languages.
  ///
  /// Will be used to resolve a `systemLanguage` conditional attribute.
  ///
  /// Format: en, en-US.
  ///
  /// Default: `[en]`
  languages : Array[String]
  /// Specifies the default shape rendering method.
  ///
  /// Default: GeometricPrecision
  shape_rendering : ShapeRendering
  /// Specifies the default text rendering method.
  ///
  /// Default: OptimizeLegibility
  text_rendering : TextRendering
  /// Specifies the default image rendering method.
  ///
  /// Default: OptimizeQuality
  image_rendering : ImageRendering
  /// Default viewport size to assume if there is no `viewBox` attribute and
  /// the `width` or `height` attributes are relative.
  ///
  /// Default: `(100, 100)`
  default_size : Size
  /// Specifies the way `xlink:href` in `<image>` elements should be handled.
  image_href_resolver : ImageHrefResolver
  /// Specifies how fonts should be resolved and loaded.
  font_resolver : FontResolver
  /// A database of fonts usable by text.
  ///
  /// This is a base database. If a custom `font_resolver` is specified,
  /// additional fonts can be loaded during parsing. Those will be added to a
  /// copy of this database.
  fontdb : FontDatabase
  /// A CSS stylesheet that should be injected into the SVG. Can be used to overwrite
  /// certain attributes.
  style_sheet : String?
}

///|
pub impl Default for Options with fn default() {
  {
    resources_dir: None,
    dpi: 96.0,
    // Default font is user-agent dependent so we can use whichever we like.
    font_family: "Times New Roman",
    font_size: 12.0,
    languages: ["en"],
    shape_rendering: ShapeRendering::default(),
    text_rendering: TextRendering::default(),
    image_rendering: ImageRendering::default(),
    default_size: Size::from_wh(100.0, 100.0).unwrap(),
    image_href_resolver: ImageHrefResolver::default(),
    font_resolver: FontResolver::default(),
    fontdb: FontDatabase::new(),
    style_sheet: None,
  }
}

///|
pub extend Options with Default::{default}

///|
/// Parses `Tree` from an SVG data.
///
/// Can contain an SVG string or a gzip compressed data.
pub fn Tree::from_data(data : Bytes, opt : Options) -> Tree raise UsvgError {
  if data.length() >= 2 && data[0] == b'\x1f' && data[1] == b'\x8b' {
    let data = decompress_svgz(data)
    guard utf8_decode_strict(data) is Some(text) else { raise NotAnUtf8Str }
    Tree::from_str(text, opt)
  } else {
    guard utf8_decode_strict(data) is Some(text) else { raise NotAnUtf8Str }
    Tree::from_str(text, opt)
  }
}

///|
/// Similar to the `from_data` method, except that it ignores all `image` elements linking to
/// external files, as required by the SVG specification when SVG files are loaded
/// for `<image href="..." />` tags.
pub fn Tree::from_data_nested(
  data : Bytes,
  opt : Options,
) -> Tree raise UsvgError {
  let nested_opt = {
    ..Options::default(),
    resources_dir: None,
    dpi: opt.dpi,
    font_size: opt.font_size,
    languages: opt.languages,
    shape_rendering: opt.shape_rendering,
    text_rendering: opt.text_rendering,
    image_rendering: opt.image_rendering,
    default_size: opt.default_size,
    image_href_resolver: {
      resolve_data: opt.image_href_resolver.resolve_data,
      // External images should be ignored.
      resolve_string: (_, _) => None,
    },
    // In the referenced SVG, we start with the unmodified user-provided
    // fontdb, not the one from the cache.
    fontdb: opt.fontdb,
    font_resolver: opt.font_resolver,
  }
  Tree::from_data(data, nested_opt)
}

///|
/// Parses `Tree` from an SVG string.
pub fn Tree::from_str(text : String, opt : Options) -> Tree raise UsvgError {
  let xml_opt = { ..@xml.ParsingOptions::default(), allow_dtd: true, }
  let doc = @xml.Document::parse_with_options(text, xml_opt) catch {
    e => raise ParsingFailed(e)
  }
  Tree::from_xmltree(doc, opt)
}

///|
/// Parses `Tree` from `roxmltree::Document`.
pub fn Tree::from_xmltree(
  doc : @xml.Document,
  opt : Options,
) -> Tree raise UsvgError {
  let doc = Document::parse_tree(doc, injected_stylesheet?=opt.style_sheet) catch {
    e => raise ParsingFailed(e)
  }
  convert_doc(doc, opt)
}

///|
/// Decompresses an SVGZ file.
pub fn decompress_svgz(data : Bytes) -> Bytes raise UsvgError {
  @codecs.gzip_decompress(data[:]) catch {
    _ => raise MalformedGZip
  }
}

///|
/// `std::str::from_utf8`.
fn utf8_decode_strict(data : Bytes) -> String? {
  Some(@utf8.decode(data[:])) catch {
    _ => None
  }
}
