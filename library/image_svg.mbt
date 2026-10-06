// Port of `typst-library/src/visualize/image/svg.rs`: `SvgImage`.

///|
/// A decoded SVG.
pub struct SvgImage {
  priv data : Bytes
  priv width : Double
  priv height : Double
  /// The fonts used by the SVG (upstream hashes them into `font_hash`).
  priv fonts : Array[Font]
  /// Whether the SVG was decoded with a font resolver (upstream's
  /// `font_hash` is zero without one and the hash of the used fonts, also
  /// of none, with one).
  priv resolved : Bool
  priv tree : @usvg.Tree
}

///|
/// An SVG is identified by its data and the used fonts (upstream: "We
/// can't hash a usvg tree directly, but the raw SVG data + a hash of all
/// used fonts gives us something similar.").
pub impl Eq for SvgImage with fn equal(self, other) {
  self.data == other.data &&
  self.resolved == other.resolved &&
  self.fonts == other.fonts
}

///|
pub impl Hash for SvgImage with fn hash_combine(self, hasher) {
  hasher.combine(self.data)
  hasher.combine(self.resolved)
  for font in self.fonts {
    hasher.combine(font)
  }
}

///|
/// Decode an SVG image without fonts.
pub fn SvgImage::new(data : Bytes) -> SvgImage raise LoadErr {
  let tree = @usvg.Tree::from_data(data, base_options()) catch {
    e => raise LoadErr(format_usvg_error(e))
  }
  let (width, height) = tree_size(tree)
  { data, width, height, fonts: [], resolved: false, tree, }
}

///|
/// Decode an SVG image with access to fonts and linked images.
///
/// Returns the image and the warnings.
pub fn SvgImage::with_fonts_images(
  data : Bytes,
  world : &World,
  families : Array[String],
  svg_file : @syntax.FileId?,
) -> (SvgImage, Array[HintedString]) raise LoadErr {
  // We parse the XML outside of `usvg::Tree` as we use it both for
  // checking the warnings and as the source of the usvg tree.
  let decoded = if data.length() >= 2 &&
    data[0] == b'\x1f' &&
    data[1] == b'\x8b' {
    @usvg.decompress_svgz(data) catch {
      e => raise LoadErr(format_usvg_error(e))
    }
  } else {
    data
  }
  guard bytes_to_str(decoded[:]) is Some(text) else {
    raise LoadErr(format_usvg_error(NotAnUtf8Str))
  }
  let xml_options = { ..@xml.ParsingOptions::default(), allow_dtd: true, }
  let document = @xml.Document::parse_with_options(text, xml_options) catch {
    err => raise LoadErr(format_usvg_error(ParsingFailed(err)))
  }
  let book = world.book()
  let font_resolver = SvgFontResolver::new(world, book, families)
  let image_resolver = SvgImageResolver::new(world, svg_file)
  let tree = @usvg.Tree::from_xmltree(document, {
    ..base_options(),
    font_resolver: {
      select_font: (font, db) => font_resolver.select_font(font, db),
      select_fallback: (c, exclude_fonts, db) => {
        font_resolver.select_fallback(c, exclude_fonts, db)
      },
    },
    image_href_resolver: {
      resolve_data: @usvg.ImageHrefResolver::default_data_resolver(),
      resolve_string: (href, opts) => image_resolver.load(href, opts),
    },
  }) catch {
    e => raise LoadErr(format_usvg_error(e))
  }
  if image_resolver.error is Some(err) {
    raise LoadErr(err)
  }
  let warnings = match svg_foreign_object_warning(document) {
    Some(warning) => [warning]
    None => []
  }
  let (width, height) = tree_size(tree)
  (
    { data, width, height, fonts: font_resolver.used, resolved: true, tree, },
    warnings,
  )
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
/// Accesses the usvg tree.
pub fn SvgImage::tree(self : SvgImage) -> @usvg.Tree {
  self.tree
}

///|
/// The base conversion options, to be extended with font-related options
/// because those can change across the document.
fn base_options() -> @usvg.Options {
  {
    ..@usvg.Options::default(),
    // Disable usvg's default to "Times New Roman".
    font_family: "",

    // We don't override the DPI here, because we already
    // force the image into the corresponding DPI by setting
    // the width and height. Changing the DPI only trips up
    // the logic in `resvg`.

    // Override usvg's resource loading defaults.
    resources_dir: None,
    image_href_resolver: {
      resolve_data: @usvg.ImageHrefResolver::default_data_resolver(),
      resolve_string: (_, _) => None,
    },
  }
}

///|
/// The pixel size of an SVG.
fn tree_size(tree : @usvg.Tree) -> (Double, Double) {
  (tree.size().width().to_double(), tree.size().height().to_double())
}

///|
/// Format the user-facing SVG decoding error message.
fn format_usvg_error(error : @usvg.UsvgError) -> LoadError {
  let error = match error {
    NotAnUtf8Str => "file is not valid UTF-8"
    MalformedGZip => "file is not compressed correctly"
    ElementsLimitReached => "file is too large"
    InvalidSize => "width, height, or viewbox is invalid"
    ParsingFailed(error) => return format_xml_like_error("SVG", error)
  }
  LoadError::text(NoPos, "failed to parse SVG", error)
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
/// Provides Typst's fonts to usvg.
priv struct SvgFontResolver {
  /// Typst's font book.
  book : FontBook
  /// The world we use to load fonts.
  world : &World
  /// The active list of font families at the location of the SVG.
  families : Array[String]
  /// A mapping from Typst font indices to fontdb IDs.
  to_id : Map[Int, @usvg.FontId?]
  /// The reverse mapping.
  from_id : Map[@usvg.FontId, Font]
  /// All used fonts (upstream accumulates their hash).
  used : Array[Font]
}

///|
/// Create a new font provider.
fn SvgFontResolver::new(
  world : &World,
  book : FontBook,
  families : Array[String],
) -> SvgFontResolver {
  { book, world, families, to_id: {}, from_id: {}, used: [], }
}

///|
/// Select a font.
fn SvgFontResolver::select_font(
  self : SvgFontResolver,
  font : @usvg.Font,
  db : @usvg.FontDatabase,
) -> @usvg.FontId? {
  let variant = FontVariant::new(
    match font.style() {
      Normal => FontStyle::Normal
      Italic => FontStyle::Italic
      Oblique => FontStyle::Oblique
    },
    FontWeight::from_number(font.weight()),
    font_stretch_from_usvg(font.stretch()),
  )

  // Find a family that is available.
  let names = []
  for family in font.families() {
    match family {
      Named(named) => names.push(named)
      // We don't support generic families at the moment.
      _ => ()
    }
  }
  names.append(self.families)
  for named in names {
    if self.book.select(named.to_lower(), variant) is Some(index) {
      if self.get_or_load(index, db) is Some(id) {
        return Some(id)
      }
    }
  }
  None
}

///|
/// Select a fallback font.
fn SvgFontResolver::select_fallback(
  self : SvgFontResolver,
  c : Char,
  exclude_fonts : Array[@usvg.FontId],
  db : @usvg.FontDatabase,
) -> @usvg.FontId? {
  // Get the font info of the originally selected font.
  let like = match exclude_fonts.get(0) {
    Some(first) => self.from_id.get(first).map(font => font.info())
    None => None
  }

  // usvg doesn't provide a variant in the fallback handler, but
  // `exclude_fonts` is actually never empty in practice. Still, we
  // prefer to fall back to the default variant rather than panicking
  // in case that changes in the future.
  let variant = match like {
    Some(info) => info.variant
    None => FontVariant::default()
  }

  // Select the font.
  guard self.book.select_fallback(like, variant, c.to_string()) is Some(index) else {
    return None
  }
  match self.get_or_load(index, db) {
    Some(id) if !exclude_fonts.contains(id) => Some(id)
    _ => None
  }
}

///|
/// Tries to retrieve the ID for the index or loads the font, allocating
/// a new ID.
fn SvgFontResolver::get_or_load(
  self : SvgFontResolver,
  index : Int,
  db : @usvg.FontDatabase,
) -> @usvg.FontId? {
  match self.to_id.get(index) {
    Some(id) => id
    None => self.load(index, db)
  }
}

///|
/// Tries to load the font with the given index in the font book into the
/// database and returns its ID.
fn SvgFontResolver::load(
  self : SvgFontResolver,
  index : Int,
  db : @usvg.FontDatabase,
) -> @usvg.FontId? {
  guard self.world.font(index) is Some(font) else { return None }
  let info = font.info()
  let variant = info.variant
  let id = db.push_face_info({
    id: 0,
    source: font.data(),
    index: font.index(),
    families: [(info.family, English_UnitedStates)],
    post_script_name: "",
    style: match variant.style {
      Normal => @usvg.DbStyle::Normal
      Italic => @usvg.DbStyle::Italic
      Oblique => @usvg.DbStyle::Oblique
    },
    weight: variant.weight.to_number(),
    stretch: match variant.stretch.round().0 {
      500 => UltraCondensed
      625 => ExtraCondensed
      750 => Condensed
      875 => SemiCondensed
      1000 => Normal
      1125 => SemiExpanded
      1250 => Expanded
      1500 => ExtraExpanded
      2000 => UltraExpanded
      _ => abort("unreachable")
    },
    monospaced: info.flags.contains(font_flags_monospace),
  })
  self.used.push(font)
  self.to_id[index] = Some(id)
  self.from_id[id] = font
  Some(id)
}

///|
/// Converts a usvg font stretch (upstream `From<usvg::FontStretch> for
/// FontStretch`).
fn font_stretch_from_usvg(stretch : @usvg.FontStretch) -> FontStretch {
  FontStretch(
    match stretch {
      UltraCondensed => 500
      ExtraCondensed => 625
      Condensed => 750
      SemiCondensed => 875
      Normal => 1000
      SemiExpanded => 1125
      Expanded => 1250
      ExtraExpanded => 1500
      UltraExpanded => 2000
    },
  )
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
/// Load a linked image or return None if a previous image caused an error,
/// or if the linked image failed to load.
/// Only the first error message is retained.
fn SvgImageResolver::load(
  self : SvgImageResolver,
  href : String,
  opts : @usvg.Options,
) -> @usvg.ImageKind? {
  if self.error is Some(_) {
    return None
  }
  Some(self.load_or_error(href, opts)) catch {
    HintedError(err) => {
      self.error = Some(
        LoadError::text(
          NoPos,
          "failed to load linked image \{href} in SVG",
          err.message,
        ),
      )
      None
    }
  }
}

///|
/// Load a linked image or return an error message string.
fn SvgImageResolver::load_or_error(
  self : SvgImageResolver,
  href : String,
  opts : @usvg.Options,
) -> @usvg.ImageKind raise HintedError {
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
      let tree = @usvg.Tree::from_data_nested(bytes, opts) catch {
        _ => bail("failed to parse SVG")
      }
      SVG(tree)
    }
    Some(Vector(Pdf)) => bail("PDF documents are not supported")
    Some(Raster(Exchange(exchange_format))) =>
      match exchange_format {
        Gif => GIF(bytes)
        Jpg => JPEG(bytes)
        Png => PNG(bytes)
        Webp => WEBP(bytes)
      }
    Some(Raster(Pixel(_))) => bail("pixel formats are not supported")
    None => bail("unknown image format")
  }
}
