// Port of `typst-pdf/src/convert.rs`.

///|
fn convert(
  typst_document : @layout.PagedDocument,
  options : PdfOptions,
  anchors : Array[(@library.Location, String)],
  link_resolver : @library.LateLinkResolver?,
  warnings : Array[@library.SourceDiagnostic],
) -> Result[Bytes, Array[@library.SourceDiagnostic]] {
  convert_impl(typst_document, options, anchors, link_resolver, warnings) catch {
    @library.SourceError(diags) => Err(diags)
  }
}

///|
fn convert_impl(
  typst_document : @layout.PagedDocument,
  options : PdfOptions,
  anchors : Array[(@library.Location, String)],
  link_resolver : @library.LateLinkResolver?,
  warnings : Array[@library.SourceDiagnostic],
) -> Result[Bytes, Array[@library.SourceDiagnostic]] raise @library.SourceError {
  let options = options.resolve(
    PdfFormatOptions::get(typst_document.options()),
    warnings,
  )
  let tags = tags_init(typst_document, options)
  let settings : @export.SerializeSettings = {
    pretty: options.format.pretty.v,
    compress_content_streams: !options.format.pretty.v,
    no_device_cs: true,
    ascii_compatible: options.format.pretty.v,
    xmp_metadata: true,
    configuration: {
      version: options.version(),
      validators: options.validators(),
    },
    enable_tagging: options.tagged(),
  }
  let document = @export.Document::new_with(settings)
  let page_index_converter = PageIndexConverter::new(typst_document, options)
  let named_destinations = collect_named_destinations(
    document, typst_document, anchors, page_index_converter,
  )
  let gc = GlobalContext::new(
    typst_document, options, link_resolver, named_destinations, page_index_converter,
    tags,
  )
  convert_pages(gc, document)
  attach_files(gc, document)
  let (doc_lang, tree) = tags_resolve(gc)
  document.set_outline(build_outline(gc))
  document.set_metadata(build_metadata(gc, doc_lang))
  document.set_tag_tree(tree)
  Ok(finish(document, gc))
}

///|
fn convert_pages(
  gc : GlobalContext,
  document : @export.Document,
) -> Unit raise @library.SourceError {
  for i, typst_page in gc.document.pages() {
    if gc.page_index_converter.pdf_page_index(i) is None {
      // Don't export this page.
      continue
    }
    // PDF 1.4 upwards to 1.7 specifies a minimum page size of 3x3 units.
    // PDF 2.0 doesn't define an explicit limit, but krilla and probably
    // some viewers won't handle pages that have zero sized pages.
    let bleed = typst_page.bleed
    let width = to_f32(typst_page.frame.width() + bleed.left + bleed.right)
    let height = to_f32(typst_page.frame.height() + bleed.top + bleed.bottom)
    guard @export.PageSettings::from_wh(
        @math.maximum(width, 3.0),
        @math.maximum(height, 3.0),
      )
      is Some(settings) else {
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "internal error: invalid page size (occurred at \{source_location()})",
        ),
      ])
    }
    let mut settings = settings
    if !bleed.is_zero() {
      if @export.Rect::from_ltrb(
          to_f32(bleed.left),
          to_f32(bleed.top),
          to_f32(bleed.left + typst_page.frame.width()),
          to_f32(bleed.top + typst_page.frame.height()),
        )
        is Some(trim) {
        settings = settings.with_trim_box(trim)
      }
    }
    let label = match typst_page.numbering {
      Some(num) => page_label_generate(num, typst_page.number)
      None => None
    }
    // When some pages were ignored from export, we show a page label with
    // the correct real (not logical) page number.
    let label = match label {
      Some(l) => Some(l)
      None =>
        if gc.page_index_converter.has_skipped_pages() {
          Some(page_label_arabic((i + 1).to_uint64()))
        } else {
          None
        }
    }
    if label is Some(label) {
      settings = settings.with_page_label(label)
    }
    let page = document.start_page_with(settings)
    let surface = page.surface()
    let page_idx = gc.page_index_converter.pdf_page_index(i)
    let fc = FrameContext::new(
      page_idx,
      typst_page.frame.size().add_size(bleed.sum_by_axis()),
    )
    tags_page(gc, surface, () => {
      handle_frame(
        fc,
        typst_page.frame,
        bleed,
        typst_page.fill_or_transparent(),
        surface,
        gc,
      )
    })
    surface.finish()
    let link_annotations = []
    for entry in fc.link_annotations {
      for a in entry.1 {
        link_annotations.push(a)
      }
    }
    tags_add_link_annotations(gc, page, link_annotations)
    page.finish()
  }
}

///|
/// The source location used in internal error messages.
fn source_location() -> String {
  "crates/typst-pdf/src/convert.rs"
}

///|
/// A state allowing us to keep track of transforms and container sizes,
/// which is mainly needed to resolve gradients and patterns correctly.
priv struct State {
  /// The current transform.
  mut transform : @library.Transform
  /// The transform of first hard frame in the hierarchy.
  mut container_transform : @library.Transform
  /// The size of the first hard frame in the hierarchy.
  mut container_size : @library.Axes[@library.Abs]
}

///|
fn State::new(size : @library.Axes[@library.Abs]) -> State {
  {
    transform: @library.Transform::identity(),
    container_transform: @library.Transform::identity(),
    container_size: size,
  }
}

///|
fn State::copy(self : State) -> State {
  {
    transform: self.transform,
    container_transform: self.container_transform,
    container_size: self.container_size,
  }
}

///|
fn State::register_container(
  self : State,
  size : @library.Axes[@library.Abs],
) -> Unit {
  self.container_transform = self.transform
  self.container_size = size
}

///|
fn State::pre_concat(self : State, transform : @library.Transform) -> Unit {
  self.transform = self.transform.pre_concat(transform)
}

///|
/// Context needed for converting a single frame.
priv struct FrameContext {
  /// The logical page index. This might be `None` if the page isn't
  /// exported, or if the context has been built to convert a pattern.
  page_idx : Int?
  states : Array[State]
  /// The link annotations belonging to a Link tag (in insertion order).
  link_annotations : Array[(Int, Array[LinkAnnotation])]
}

///|
fn FrameContext::new(
  page_idx : Int?,
  size : @library.Axes[@library.Abs],
) -> FrameContext {
  { page_idx, states: [State::new(size)], link_annotations: [], }
}

///|
fn FrameContext::push(self : FrameContext) -> Unit {
  self.states.push(self.states[self.states.length() - 1].copy())
}

///|
fn FrameContext::pop(self : FrameContext) -> Unit {
  self.states.pop() |> ignore
}

///|
fn FrameContext::state(self : FrameContext) -> State {
  self.states[self.states.length() - 1]
}

///|
fn FrameContext::page_size(self : FrameContext) -> @library.Axes[@library.Abs]? {
  if self.page_idx is Some(_) {
    Some(self.states[0].container_size)
  } else {
    None
  }
}

///|
fn FrameContext::get_link_annotation(
  self : FrameContext,
  id : Int,
) -> LinkAnnotation? {
  for entry in self.link_annotations {
    if entry.0 == id {
      return entry.1.last()
    }
  }
  None
}

///|
fn FrameContext::push_link_annotation(
  self : FrameContext,
  id : Int,
  annotation : LinkAnnotation,
) -> Unit {
  for entry in self.link_annotations {
    if entry.0 == id {
      entry.1.push(annotation)
      return
    }
  }
  self.link_annotations.push((id, [annotation]))
}

///|
/// Globally needed context for converting a Typst document.
priv struct GlobalContext {
  /// Cache the conversion between export and Typst fonts.
  fonts_forward : Map[@library.FontInstance, @export.Font]
  fonts_backward : Array[(@export.Font, @library.FontInstance)]
  /// The fonts shared between Typst text and SVG images.
  svg_fonts : SvgFontCache
  /// The extraction state of each embedded PDF document (by data key).
  pdf_extractions : Map[String, @hayro_write.ExtractionContext]
  /// Mapping between images and their span.
  image_to_spans : Map[String, @syntax.Span]
  /// The spans of all images that appear in the document.
  image_spans : Map[@syntax.Span, Unit]
  /// The document to convert.
  document : @layout.PagedDocument
  /// Options for PDF export.
  options : CompletePdfOptions
  /// Used to resolve cross-document links in bundle export.
  link_resolver : @library.LateLinkResolver?
  /// Mapping between locations in the document and named destinations.
  loc_to_names : Map[@library.Location, @export.NamedDestination]
  page_index_converter : PageIndexConverter
  /// Tagged PDF context.
  tags : Tags
}

///|
fn GlobalContext::new(
  document : @layout.PagedDocument,
  options : CompletePdfOptions,
  link_resolver : @library.LateLinkResolver?,
  loc_to_names : Map[@library.Location, @export.NamedDestination],
  page_index_converter : PageIndexConverter,
  tags : Tags,
) -> GlobalContext {
  {
    fonts_forward: {},
    fonts_backward: [],
    svg_fonts: SvgFontCache::new(),
    pdf_extractions: {},
    image_to_spans: {},
    image_spans: {},
    document,
    options,
    link_resolver,
    loc_to_names,
    page_index_converter,
    tags,
  }
}

///|
fn GlobalContext::font_backward(
  self : GlobalContext,
  font : @export.Font,
) -> @library.FontInstance? {
  for entry in self.fonts_backward {
    if physical_equal(entry.0, font) {
      return Some(entry.1)
    }
  }
  None
}

///|
fn handle_frame(
  fc : FrameContext,
  frame : @library.Frame,
  padding : @library.Sides[@library.Abs],
  fill : @library.Paint?,
  surface : @export.Surface,
  gc : GlobalContext,
) -> Unit raise @library.SourceError {
  fc.push()
  if frame.kind().is_hard() {
    fc.state().register_container(frame.size())
  }
  if fill is Some(fill) {
    let shape = @library.Geometry::Rect(
      frame.size().add_size(padding.sum_by_axis()),
    ).filled(fill)
    handle_shape(
      fc,
      shape,
      surface,
      gc,
      @syntax.Span::detached(),
      Custom(@export.ArtifactType::Background),
    )
  }
  fc.push()
  fc
  .state()
  .pre_concat(@library.Transform::translate(padding.left, padding.top))
  for entry in frame.items() {
    let (point, item) = entry
    fc.push()
    fc.state().pre_concat(@library.Transform::translate(point.x, point.y))
    match item {
      Group(g) => handle_group(fc, g, surface, gc)
      Text(t) => handle_text(fc, t, surface, gc)
      Shape(s, span) => handle_shape(fc, s, surface, gc, span, Auto)
      Image(image, size, span) =>
        handle_image(gc, fc, image, size, surface, span)
      Link(dest, size) => handle_link(fc, gc, dest, size)
      Tag(Start(_, flags)) =>
        if flags.tagged {
          tags_handle_start(gc, fc, surface)
        }
      Tag(End(_, _, flags)) =>
        if flags.tagged {
          tags_handle_end(gc, fc, surface)
        }
    }
    fc.pop()
  }
  fc.pop()
  fc.pop()
}

///|
fn handle_group(
  fc : FrameContext,
  group : @library.GroupItem,
  surface : @export.Surface,
  gc : GlobalContext,
) -> Unit raise @library.SourceError {
  fc.push()
  fc.state().pre_concat(group.transform)
  tags_group(gc, fc, surface, group.parent, () => {
    let clip_path = match group.clip {
      Some(p) => {
        let builder = @export.PathBuilder::new()
        convert_path(p, builder)
        match builder.finish() {
          Some(path) =>
            Some(path.transform(to_export_transform(fc.state().transform)))
          None => None
        }
      }
      None => None
    }
    if clip_path is Some(clip_path) {
      surface.push_clip_path(clip_path, NonZero)
    }
    handle_frame(
      fc,
      group.frame,
      @library.Sides::splat(@library.Abs::zero()),
      None,
      surface,
      gc,
    )
    if clip_path is Some(_) {
      surface.pop()
    }
  })
  fc.pop()
}

///|
/// Finish a document and handle export errors.
fn finish(
  document : @export.Document,
  gc : GlobalContext,
) -> Bytes raise @library.SourceError {
  document.finish() catch {
    FontError(f, err) =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "failed to process \{display_font(gc.font_backward(f))} (\{err})",
        ).with_hints([
          "make sure the font is valid", "the used font might be unsupported by Typst",
        ]),
      ])
    Validation(ve) =>
      raise @library.SourceError(
        ve.map(e => convert_validation_error(gc, e.0, e.1)),
      )
    ImageError(loc, err) =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          to_span(loc),
          "failed to process image (\{err})",
        ),
      ])
    DuplicateTagId(_, loc) =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(to_span(loc), "duplicate tag id").with_hint(
          "please report this as a bug",
        ),
      ])
    UnknownTagId(_, loc) =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(to_span(loc), "unknown tag id").with_hint(
          "please report this as a bug",
        ),
      ])
    DuplicateNamedDestination(_) =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "duplicate named destination",
        ).with_hint("please report this as a bug"),
      ])
  }
}

///|
fn validators_to_comma_list(v : @export.Validators) -> String {
  let sb = StringBuilder::new()
  for i, val in v.to_array() {
    if i != 0 {
      sb.write_string(", ")
    }
    sb.write_string(val.as_str())
  }
  sb.to_string()
}

///|
fn validators_to_and_list(v : @export.Validators) -> String {
  let names = v.to_array().map(x => x.as_str())
  match names.length() {
    0 => ""
    1 => names[0]
    2 => "\{names[0]} and \{names[1]}"
    _ => {
      let sb = StringBuilder::new()
      for i in 0..<(names.length() - 1) {
        sb.write_string("\{names[i]}, ")
      }
      sb.write_string("and \{names[names.length() - 1]}")
      sb.to_string()
    }
  }
}

///|
fn diag(
  span : @syntax.Span,
  msg : String,
  hints : Array[String],
) -> @library.SourceDiagnostic {
  @library.SourceDiagnostic::error_at(span, msg).with_hints(hints)
}

///|
/// Converts a validation error into a Typst error.
fn convert_validation_error(
  gc : GlobalContext,
  error : @export.ValidationError,
  failing_validators : @export.Validators,
) -> @library.SourceDiagnostic {
  let pdf_version = gc.options.version().as_str()
  let prefix = "\{validators_to_comma_list(failing_validators)} error:"
  let detached = @syntax.Span::detached()
  match error {
    TooLongString =>
      diag(detached, "\{prefix} a PDF string is longer than 32767 characters", [
        "ensure title and author names are short enough",
      ])
    TooLongName =>
      diag(detached, "\{prefix} a PDF name is longer than 127 characters", [
        "perhaps a font name is too long",
      ])
    TooLongArray =>
      diag(detached, "\{prefix} a PDF array is longer than 8191 elements", [
        "this can happen if you have a very long text in a single line",
      ])
    TooLongDictionary =>
      diag(detached, "\{prefix} a PDF dictionary has more than 4095 entries", [
        "try reducing the complexity of your document",
      ])
    TooLargeFloat =>
      diag(
        detached,
        "\{prefix} a PDF floating point number is larger than the allowed limit",
        ["try exporting with a higher PDF version"],
      )
    TooManyIndirectObjects =>
      diag(detached, "\{prefix} the PDF has too many indirect objects", [
        "reduce the size of your document",
      ])
    TooHighQNestingLevel =>
      diag(detached, "\{prefix} the PDF has too high q nesting", [
        "reduce the number of nested containers",
      ])
    ContainsPostScript(loc) =>
      diag(to_span(loc), "\{prefix} the PDF contains PostScript code", [
        "conic gradients are not supported in this PDF standard",
      ])
    MissingCMYKProfile =>
      diag(detached, "\{prefix} the PDF is missing a CMYK profile", [
        "CMYK colors are not yet supported in this export mode",
      ])
    InconsistentSeparationFallback(colorant) => {
      let repr = match colorant {
        AllColorants => @library.SpotColorantName::All.repr()
        Custom(c) => @library.SpotColorantName::Custom(c).repr()
        NoColorant => "none"
      }
      diag(
        detached,
        "spot colorant `\{repr}` appeared with multiple distinct fallback colors",
        [
          "define a particular spot colorant once and store it in a variable to reuse it later",
        ],
      )
    }
    ContainsNotDefGlyph(f, loc, text) =>
      diag(
        to_span(loc),
        "\{prefix} the text `\{@library.repr_str(text)}` could not be displayed with \{display_font(gc.font_backward(f))}",
        ["try using a different font"],
      )
    NoCodepointMapping(_, _, loc) => {
      let msg = if loc is Some(_) {
        "the text was not mapped to a code point"
      } else {
        "the PDF contains text with missing codepoints"
      }
      diag(to_span(loc), "\{prefix} \{msg}", [
        "for complex scripts like Arabic, it might not be possible to produce a compliant document",
      ])
    }
    InvalidCodepointMapping(_, _, c, loc) => {
      let msg = if loc is Some(_) {
        "the text contains"
      } else {
        "the PDF contains text with"
      }
      diag(
        to_span(loc),
        "\{prefix} \{msg} the disallowed codepoint `\{char_repr(c)}`",
        [],
      )
    }
    UnicodePrivateArea(_, _, c, loc) => {
      let msg = if loc is Some(_) { "the PDF" } else { "the text" }
      diag(
        to_span(loc),
        "\{prefix} \{msg} contains the codepoint `\{char_repr(c)}`",
        [
          "codepoints from the Unicode private area are forbidden in this export mode",
        ],
      )
    }
    RestrictedLicense(f) =>
      diag(
        detached,
        "\{prefix} license of \{display_font(gc.font_backward(f))} is too restrictive",
        [
          "the font has specified \"Restricted License embedding\" in its metadata",
          "restrictive font licenses are prohibited by \{validators_to_and_list(failing_validators)} because they limit the suitability for archival",
        ],
      )
    Transparency(loc) => {
      let span = to_span(loc)
      let hint1 = "try exporting with a different standard that supports transparency"
      if loc is Some(_) {
        if gc.image_spans.contains(span) {
          diag(span, "\{prefix} the image contains transparency", [
            hint1, "or convert the image to a non-transparent one", "you might have to convert SVGs into non-transparent bitmap images",
          ])
        } else {
          diag(span, "\{prefix} the used fill or stroke has transparency", [
            hint1, "or don't use colors with transparency in this export mode",
          ])
        }
      } else {
        diag(span, "\{prefix} the PDF contains transparency", [hint1])
      }
    }
    ImageInterpolation(loc) => {
      let span = to_span(loc)
      if loc is Some(_) {
        diag(span, "\{prefix} the image has smooth scaling", [
          "set the `scaling` attribute to `pixelated`",
        ])
      } else {
        diag(span, "\{prefix} an image in the PDF has smooth scaling", [
          "set the `scaling` attribute of all images to `pixelated`",
        ])
      }
    }
    EmbeddedFile(e, s) => {
      // We always set the span for attached files, so it cannot be detached.
      let span = to_span(s)
      match e {
        Existence =>
          diag(span, "\{prefix} document contains an attached file", [
            "file attachments are not supported in this export mode",
          ])
        MissingDate =>
          diag(span, "\{prefix} document date is missing", [
            "the document must have a date when attaching files", "`set document(date: none)` must not be used in this case",
          ])
        MissingDescription =>
          diag(span, "\{prefix} the file description is missing", [])
        MissingMimeType =>
          diag(span, "\{prefix} the file mime type is missing", [])
      }
    }
    MissingAnnotationAltText(loc) =>
      diag(to_span(loc), "\{prefix} missing annotation alt text", [
        "please report this as a bug",
      ])
    MissingAltText(loc) =>
      diag(to_span(loc), "\{prefix} missing alt text", [
        "make sure your images and equations have alt text",
      ])
    NoDocumentLanguage =>
      diag(detached, "\{prefix} missing document language", [
        "set the language of the document",
      ])
    MissingHeadingTitle =>
      diag(detached, "\{prefix} missing heading title", [
        "please report this as a bug",
      ])
    MissingDocumentOutline =>
      diag(detached, "\{prefix} missing document outline", [
        "please report this as a bug",
      ])
    MissingTagging =>
      diag(detached, "\{prefix} missing document tags", [
        "please report this as a bug",
      ])
    NoDocumentTitle =>
      diag(detached, "\{prefix} missing document title", [
        "set the title with `set document(title: [...])`",
      ])
    MissingDocumentDate =>
      diag(detached, "\{prefix} missing document date", [
        "set the date of the document",
      ])
    EmbeddedPDF(loc) =>
      diag(
        to_span(loc),
        "embedding PDFs is currently not supported in this export mode",
        ["try converting the PDF to an SVG before embedding it"],
      )
    RequiresNewerPdfVersion(feature, loc) => {
      let span = to_span(loc)
      let message = match feature {
        StructureOrderTabbing =>
          "\{prefix} links and other annotations cannot be navigated accessibly in \{pdf_version} files"
        HeaderFooterArtifactSubtypes =>
          "\{prefix} headers and footers cannot be made accessible in \{pdf_version} files"
        TableHeaderScope =>
          "\{prefix} table header cell cannot be accessibly tagged in \{pdf_version} files"
      }
      let diagnostic = @library.SourceDiagnostic::error_at(span, message)
      let min_version = feature.minimum_pdf_version()
      let mut most_restrictive : (@export.Validator, @export.PdfVersion)? = None
      for validator in gc.options.validators().to_array() {
        let max = validator.max()
        match most_restrictive {
          None => most_restrictive = Some((validator, max))
          Some((_, prev_max)) =>
            if prev_max > max {
              most_restrictive = Some((validator, max))
            }
        }
      }
      guard most_restrictive is Some((restrictive_validator, max_version)) else {
        return diagnostic
      }
      if min_version < max_version {
        diagnostic.with_hint(
          "select a version between \{min_version.as_str()} and \{max_version.as_str()}",
        )
      } else if min_version == max_version {
        diagnostic.with_hint("set the version to \{min_version.as_str()}")
      } else {
        diagnostic
        .with_hint(
          "PDF version must be at least \{min_version.as_str()} to satisfy \{validators_to_and_list(failing_validators)}",
        )
        .with_hint(
          "remove or replace the \{restrictive_validator.as_str()} standard, as it prevents PDF versions beyond \{max_version.as_str()}",
        )
      }
    }
  }
}

///|
/// The repr of a character (Rust `char::repr` in Typst: quoted).
fn char_repr(c : Char) -> String {
  @library.repr_str(c.to_string())
}

///|
/// Convert a location to a span.
fn to_span(loc : @export.Location?) -> @syntax.Span {
  match loc {
    Some(raw) => @syntax.Span(raw)
    None => @syntax.Span::detached()
  }
}

///|
fn collect_named_destinations(
  document : @export.Document,
  typst_document : @layout.PagedDocument,
  anchors : Array[(@library.Location, String)],
  pic : PageIndexConverter,
) -> Map[@library.Location, @export.NamedDestination] {
  let locs_to_names : Map[@library.Location, @export.NamedDestination] = Map([])
  // Find all headings that have a label and are the first among other
  // headings with the same label.
  let seen : Map[String, Unit] = Map([])
  let headings = typst_document
    .introspector()
    .query(@library.heading_elem().select())
  let matches = []
  for entry in anchors {
    matches.push(entry)
  }
  for elem in headings {
    if elem.location() is Some(loc) && elem.label() is Some(label) {
      matches.push((loc, label.resolve()))
    }
  }
  for entry in matches {
    let (loc, name) = entry
    if seen.contains(name) {
      continue
    }
    seen[name] = ()
    // Only add named destination if page belonging to the position is
    // exported.
    let pos = typst_document
      .paged_introspector()
      .position(loc)
      .unwrap_or(@library.PagedPosition::origin())
    if pos_to_xyz(pic, pos) is Some(dest) {
      let named = @export.NamedDestination::new(name, dest)
      document.register_named_destination(named) |> ignore
      locs_to_names[loc] = named
    }
  }
  locs_to_names
}

///|
priv struct PageIndexConverter {
  page_indices : Map[Int, Int]
  skipped_pages : Int
}

///|
fn PageIndexConverter::new(
  document : @layout.PagedDocument,
  options : CompletePdfOptions,
) -> PageIndexConverter {
  let page_indices : Map[Int, Int] = Map([])
  let mut skipped_pages = 0
  for i in 0..<document.pages().length() {
    match options.format.pages.v {
      Some(ranges) if !ranges.includes_page(i + 1) => skipped_pages += 1
      _ => page_indices[i] = i - skipped_pages
    }
  }
  { page_indices, skipped_pages, }
}

///|
fn PageIndexConverter::has_skipped_pages(self : PageIndexConverter) -> Bool {
  self.skipped_pages > 0
}

///|
/// Get the PDF page index of a page index, if it's not excluded.
fn PageIndexConverter::pdf_page_index(
  self : PageIndexConverter,
  page_index : Int,
) -> Int? {
  self.page_indices.get(page_index)
}
