// Port of `typst-library/src/visualize/image/svg.rs`: `SvgImage`.
//
// Upstream builds a `usvg::Tree`. This port only reproduces what Typst
// observes before rendering: XML parsing (`data/xml`, a port of roxmltree),
// usvg's root checks and size resolution (`resolve_svg_size` in usvg 0.47's
// `parser/converter.rs`, including its `f32` arithmetic), the linked image
// resolution errors and the `<foreignObject>` warning. Not ported:
// - the usvg tree itself (needed for SVG rendering in layout/export);
// - font resolution (`FontResolver`, only affects rendering and the font
//   hash);
// - CSS-provided root sizes and `em` units relative to inherited CSS font
//   sizes (only a plain `font-size` attribute on the root is considered).
// Linked images are resolved for every `<image>` element, whereas usvg only
// resolves the ones it converts (i.e. that are rendered).

///|
/// A decoded SVG.
pub struct SvgImage {
  priv data : Bytes
  priv width : Double
  priv height : Double
}

///|
/// An SVG is identified by its data (upstream also hashes the used fonts).
pub impl Eq for SvgImage with fn equal(self, other) {
  self.data == other.data
}

///|
pub impl Hash for SvgImage with fn hash_combine(self, hasher) {
  hasher.combine(self.data)
}

///|
/// Decode an SVG image without fonts.
pub fn SvgImage::new(data : Bytes) -> SvgImage raise LoadErr {
  let document = svg_parse_document(data)
  let (width, height) = svg_tree_size(document) catch {
    err => raise LoadErr(format_usvg_error(err))
  }
  { data, width, height, }
}

///|
/// Decode an SVG image with access to fonts and linked images.
///
/// Returns the image and the warnings.
pub fn SvgImage::with_fonts_images(
  data : Bytes,
  world : &World,
  _families : Array[String],
  svg_file : @syntax.FileId?,
) -> (SvgImage, Array[HintedString]) raise LoadErr {
  // We parse the XML outside of `usvg::Tree` as we use it both for checking
  // the warnings and as the source of the usvg tree.
  let document = svg_parse_document(data)
  let (width, height) = svg_tree_size(document) catch {
    err => raise LoadErr(format_usvg_error(err))
  }
  let image_resolver = SvgImageResolver::new(world, svg_file)
  for node in document.descendants() {
    if node.is_element() &&
      node.tag_name().name() == "image" &&
      node.tag_name().namespace() == Some(svg_ns) {
      let href = match node.attribute("href", ns=xlink_ns) {
        Some(href) => Some(href)
        None => node.attribute("href")
      }
      if href is Some(href) && !href.has_prefix("data:") {
        image_resolver.load(href)
      }
    }
  }
  if image_resolver.error is Some(err) {
    raise LoadErr(err)
  }
  let warnings = match svg_foreign_object_warning(document) {
    Some(warning) => [warning]
    None => []
  }
  ({ data, width, height, }, warnings)
}

///|
/// The raw image data.
pub fn SvgImage::data(self : SvgImage) -> Bytes {
  self.data
}

///|
/// The SVG's width in pixels.
pub fn SvgImage::width(self : SvgImage) -> Double {
  self.width
}

///|
/// The SVG's height in pixels.
pub fn SvgImage::height(self : SvgImage) -> Double {
  self.height
}

///|
let svg_ns = "http://www.w3.org/2000/svg"

///|
let xlink_ns = "http://www.w3.org/1999/xlink"

///|
/// A usvg error (upstream `usvg::Error`).
priv suberror UsvgError {
  NotAnUtf8Str
  MalformedGZip
  InvalidSize
  ParsingFailed(@xml.XmlError)
}

///|
/// Format the user-facing SVG decoding error message.
fn format_usvg_error(error : UsvgError) -> LoadError {
  let error = match error {
    NotAnUtf8Str => "file is not valid UTF-8"
    MalformedGZip => "file is not compressed correctly"
    InvalidSize => "width, height, or viewbox is invalid"
    ParsingFailed(error) => return format_xml_like_error("SVG", error)
  }
  LoadError::text(NoPos, "failed to parse SVG", error)
}

///|
/// Parses the SVG's XML, with usvg's check that the root element is an
/// `<svg>` element.
fn svg_parse_document(data : Bytes) -> @xml.Document raise LoadErr {
  let data = if data.length() >= 2 && data[0] == b'\x1f' && data[1] == b'\x8b' {
    @codecs.gzip_decompress(data[:]) catch {
      _ => raise LoadErr(format_usvg_error(MalformedGZip))
    }
  } else {
    data
  }
  guard bytes_to_str(data[:]) is Some(text) else {
    raise LoadErr(format_usvg_error(NotAnUtf8Str))
  }
  let xml_options = { ..@xml.ParsingOptions::default(), allow_dtd: true, }
  let document = @xml.Document::parse_with_options(text, xml_options) catch {
    err => raise LoadErr(format_usvg_error(ParsingFailed(err)))
  }

  // Check that the root element is `svg`.
  match document.root().first_element_child() {
    Some(child) =>
      if !child.has_tag_name("svg", ns=svg_ns) {
        raise LoadErr(format_usvg_error(ParsingFailed(NoRootNode)))
      }
    None => raise LoadErr(format_usvg_error(ParsingFailed(NoRootNode)))
  }
  document
}

///|
/// The default DPI of usvg (`usvg::Options::dpi`).
let usvg_dpi : Float = 96.0

///|
/// A length unit (upstream `svgtypes::LengthUnit`).
priv enum SvgLengthUnit {
  UnitNone
  UnitEm
  UnitEx
  UnitPx
  UnitIn
  UnitCm
  UnitMm
  UnitPt
  UnitPc
  UnitPercent
} derive(Eq)

///|
/// Parses a number like `svgtypes::Stream::parse_number` at `pos`, returning
/// the number and the position after it.
fn svg_parse_number(s : Array[Char], pos : Int) -> (Double, Int)? {
  let len = s.length()
  let mut i = pos
  while i < len && s[i] is (' ' | '\t' | '\n' | '\r') {
    i += 1
  }
  let start = i
  if i >= len {
    return None
  }
  if s[i] is ('+' | '-') {
    i += 1
    if i >= len {
      return None
    }
  }
  let skip_digits = () => {
    while i < len && s[i] is ('0'..='9') {
      i += 1
    }
  }
  match s[i] {
    '0'..='9' => skip_digits()
    '.' => ()
    _ => return None
  }
  if i < len && s[i] == '.' {
    i += 1
    skip_digits()
  }
  if i < len && s[i] is ('e' | 'E') {
    if i + 1 >= len {
      return None
    }
    let c2 = s[i + 1]
    if c2 != 'm' && c2 != 'x' {
      i += 1
      match s[i] {
        '+' | '-' => {
          i += 1
          skip_digits()
        }
        '0'..='9' => skip_digits()
        _ => return None
      }
    }
  }
  guard rust_parse_f64(String::from_array(s[start:i])) is Some(n) else {
    return None
  }
  if n.is_nan() || n.is_inf() {
    return None
  }
  Some((n, i))
}

///|
/// Parses a length (upstream `svgtypes::Length::from_str`).
fn svg_parse_length(text : String) -> (Double, SvgLengthUnit)? {
  let s = text.to_array()
  guard svg_parse_number(s, 0) is Some((n, i)) else { return None }
  let rest = String::from_array(s[i:])
  let (unit, used) = if rest.has_prefix("%") {
    (UnitPercent, 1)
  } else if rest.has_prefix("em") {
    (UnitEm, 2)
  } else if rest.has_prefix("ex") {
    (UnitEx, 2)
  } else if rest.has_prefix("px") {
    (UnitPx, 2)
  } else if rest.has_prefix("in") {
    (UnitIn, 2)
  } else if rest.has_prefix("cm") {
    (UnitCm, 2)
  } else if rest.has_prefix("mm") {
    (UnitMm, 2)
  } else if rest.has_prefix("pt") {
    (UnitPt, 2)
  } else if rest.has_prefix("pc") {
    (UnitPc, 2)
  } else {
    (UnitNone, 0)
  }
  if i + used != s.length() {
    return None
  }
  Some((n, unit))
}

///|
/// Parses a view box (upstream `svgtypes::ViewBox::from_str` followed by
/// `NonZeroRect::from_xywh`), returning its width and height.
fn svg_parse_viewbox(text : String) -> (Float, Float)? {
  let s = text.to_array()
  let nums = []
  let mut pos = 0
  for _ in 0..<4 {
    guard svg_parse_number(s, pos) is Some((n, i)) else { return None }
    nums.push(n)
    pos = i
    while pos < s.length() && s[pos] is (' ' | '\t' | '\n' | '\r') {
      pos += 1
    }
    if pos < s.length() && s[pos] == ',' {
      pos += 1
    }
  }
  if nums[2] <= 0.0 || nums[3] <= 0.0 {
    return None
  }
  // `NonZeroRect` stores the edges in `f32`.
  let x = Float::from_double(nums[0])
  let y = Float::from_double(nums[1])
  let right = x + Float::from_double(nums[2])
  let bottom = y + Float::from_double(nums[3])
  let w = right - x
  let h = bottom - y
  if !(w > 0.0) ||
    !(h > 0.0) ||
    w.to_double().is_inf() ||
    h.to_double().is_inf() {
    return None
  }
  Some((w, h))
}

///|
/// The font size used for `em`/`ex` units on the root element.
fn svg_root_font_size(svg : @xml.Node) -> Float {
  match svg.attribute("font-size").bind(svg_parse_length) {
    Some((n, UnitNone | UnitPx)) => Float::from_double(n)
    _ => 12.0
  }
}

///|
/// Converts a user length (upstream `units::convert_length` with
/// `Units::UserSpaceOnUse`); percentages are relative to `base`.
fn svg_convert_length(
  length : (Double, SvgLengthUnit),
  svg : @xml.Node,
  base : Float,
) -> Float {
  let (number, unit) = length
  let n = Float::from_double(number)
  match unit {
    UnitNone | UnitPx => n
    UnitEm => n * svg_root_font_size(svg)
    UnitEx => n * svg_root_font_size(svg) / 2.0
    UnitIn => n * usvg_dpi
    UnitCm => n * usvg_dpi / 2.54
    UnitMm => n * usvg_dpi / 25.4
    UnitPt => n * usvg_dpi / 72.0
    UnitPc => n * usvg_dpi / 6.0
    UnitPercent => base * n / 100.0
  }
}

///|
/// The pixel size of an SVG (upstream `tree_size` after usvg's
/// `resolve_svg_size`).
fn svg_tree_size(document : @xml.Document) -> (Double, Double) raise UsvgError {
  let svg = document.root_element()
  let def = (100.0, UnitPercent)
  let width = svg.attribute("width").bind(svg_parse_length).unwrap_or(def)
  let height = svg.attribute("height").bind(svg_parse_length).unwrap_or(def)
  let view_box = svg.attribute("viewBox").bind(svg_parse_viewbox)
  let (w, h) = match view_box {
    Some((vw, vh)) => {
      let w = if width.1 == UnitPercent {
        vw * (Float::from_double(width.0) / 100.0)
      } else {
        svg_convert_length(width, svg, vw)
      }
      let h = if height.1 == UnitPercent {
        vh * (Float::from_double(height.0) / 100.0)
      } else {
        svg_convert_length(height, svg, vh)
      }
      (w, h)
    }
    // Percentages are relative to the default view box (0 0 100 100).
    None =>
      (
        svg_convert_length(width, svg, 100.0),
        svg_convert_length(height, svg, 100.0),
      )
  }
  let w = w.to_double()
  let h = h.to_double()
  if !(w > 0.0) || !(h > 0.0) || w.is_inf() || h.is_inf() {
    raise InvalidSize
  }
  (w, h)
}

///|
/// Produce a warning if the SVG embeds a `<foreignObject>` element without a
/// surrounding `<switch>` and a non-`<foreignObject>` sibling.
///
/// Foreign objects contain XHTML elements that may not be supported by the
/// user agent. To provide fallback representations in such a case, there are
/// two styles of idioms in use, both based on a `<switch>` element with a
/// `<foreignObject>` and a fallback representation. An idiom works under usvg
/// when the foreign object has a `requiredExtensions` or `requiredFeatures`
/// attribute (and thus loses the switch) and a non-`<foreignObject>` sibling
/// follows. See upstream for details.
fn svg_foreign_object_warning(document : @xml.Document) -> HintedString? {
  let uncovered = document
    .root()
    .descendants()
    .iter()
    .any(node => {
      node.tag_name().name() == "foreignObject" &&
      !foreign_object_covered_by_switch(node)
    })
  if uncovered {
    Some({
      message: "image contains foreign object",
      hints: [
        "its content will be omitted because Typst cannot render embedded HTML",
        "see https://github.com/typst/typst/issues/1421 for more information",
      ],
    })
  } else {
    None
  }
}

///|
/// Checks whether a `<foreignObject>` node has a parent switch and a sibling.
fn foreign_object_covered_by_switch(node : @xml.Node) -> Bool {
  let skipped_by_switch = node.has_attribute("requiredFeatures") ||
    node.has_attribute("requiredExtensions")
  if !skipped_by_switch {
    return false
  }
  guard node.parent() is Some(parent) && parent.tag_name().name() == "switch" else {
    return false
  }
  let mut next = node.next_sibling_element()
  while next is Some(n) {
    if n.tag_name().name() != "foreignObject" {
      return true
    }
    next = n.next_sibling_element()
  }
  false
}

///|
/// Resolves linked images in an SVG.
/// (Linked SVG images from an SVG are not supported yet.)
priv struct SvgImageResolver {
  /// The world used to load linked images.
  world : &World
  /// Parent folder of the SVG file, used to resolve hrefs to linked images,
  /// if any.
  svg_file : @syntax.FileId?
  /// The first error that occurred when loading a linked image, if any.
  mut error : LoadError?
}

///|
fn SvgImageResolver::new(
  world : &World,
  svg_file : @syntax.FileId?,
) -> SvgImageResolver {
  { world, svg_file, error: None, }
}

///|
/// Load a linked image, unless a previous image caused an error. Only the
/// first error message is retained.
fn SvgImageResolver::load(self : SvgImageResolver, href : String) -> Unit {
  if self.error is Some(_) {
    return
  }
  self.load_or_error(href) catch {
    HintedError(err) =>
      self.error = Some(
        LoadError::text(
          NoPos,
          "failed to load linked image \{href} in SVG",
          err.message,
        ),
      )
  }
}

///|
/// Load a linked image or return an error message string.
fn SvgImageResolver::load_or_error(
  self : SvgImageResolver,
  href : String,
) -> Unit raise HintedError {
  // If the href starts with "file://", strip this prefix to construct an
  // ordinary path.
  let href = if href.has_prefix("file://") {
    href.unsafe_substring(start=7, end=href.length())
  } else {
    href
  }

  // Do not accept absolute hrefs. They would be parsed in Typst in a way
  // that is not compatible with their interpretation in the SVG standard.
  if href.has_prefix("/") {
    bail("absolute paths are not allowed")
  }

  // Exit early if the href is an URL.
  if href.find("://") is Some(pos) {
    let scheme = href.unsafe_substring(start=0, end=pos)
    if scheme
      .iter()
      .all(c => {
        c.is_ascii_alphabetic() ||
        c.is_ascii_digit() ||
        c == '+' ||
        c == '-' ||
        c == '.'
      }) {
      bail("URLs are not allowed")
    }
  }

  // Resolve the path to the linked image.
  let href_file = PathOrStr::Str(href).resolve_if_some(self.svg_file) catch {
    HintedError(hinted) => bail(hinted.message)
  }
  let href_file = href_file.intern()

  // Load image if file can be accessed.
  let bytes = self.world.file(href_file) catch {
    // TODO: Somehow unify this with `impl Display for FileError`.
    NotFound(path) => bail("file not found, searched at \{path}")
    AccessDenied => bail("access denied")
    IsDirectory => bail("is a directory")
    Other(Some(msg)) => bail(msg)
    Other(None) => bail("unspecified error")
    err => bail("unexpected error: \{err}")
  }
  let format = match determine_format_from_path(href_file.vpath()) {
    Some(format) => Some(format)
    None => ImageFormat::detect(bytes)
  }
  match format {
    Some(Vector(Svg)) => {
      // Upstream parses the nested SVG with `usvg::Tree::from_data_nested`.
      let _ = SvgImage::new(bytes) catch { _ => bail("failed to parse SVG") }
    }
    Some(Vector(Pdf)) => bail("PDF documents are not supported")
    Some(Raster(Exchange(_))) => ()
    Some(Raster(Pixel(_))) => bail("pixel formats are not supported")
    None => bail("unknown image format")
  }
}
