// Port of the export option parts of `typst-pdf/src/format.rs`
// (`PdfFormatOptions`). The `pdf` format element and `PdfStandards` live in
// the library (`library/pdf_standard.mbt`).

///|
/// Document settings for PDF export (upstream `PdfFormatOptions<Complete>`).
pub(all) struct PdfFormatOptions {
  /// Specifies which ranges of pages should be included in the PDF. When
  /// `None`, all pages should be exported.
  pages : @library.SpannedValue[@library.PageRanges?]
  /// A list of PDF standards that Typst will enforce conformance with.
  standard : @library.SpannedValue[@library.PdfStandards]
  /// Whether to produce a tagged PDF document.
  tagged : @library.SpannedValue[@library.Smart[Bool]]
  /// Wether to format the PDF in a human readable way.
  pretty : @library.SpannedValue[Bool]
}

///|
/// The PDF format options configured by a document (upstream
/// `options.get::<PdfFormat>()`).
pub fn PdfFormatOptions::get(
  options : @library.DocumentFormatOptions,
) -> PdfFormatOptions {
  let o = options.get(@library.pdf_format_elem())
  let pages = o.get(@library.pdf_format_elem_pages)
  let standard = o.get(@library.pdf_format_elem_standard)
  let tagged = o.get(@library.pdf_format_elem_tagged)
  let pretty = o.get(@library.pdf_format_elem_pretty)
  {
    pages: {
      v: match pages.v {
        None => None
        v => {
          let ranges : @library.PageRanges = @library.FromValue::from_value(v) catch {
            _ => return default_format_options(standard, tagged, pretty)
          }
          Some(ranges)
        }
      },
      span: pages.span,
    },
    standard: {
      v: @library.FromValue::from_value(standard.v) catch {
        _ => @library.PdfStandards::default()
      },
      span: standard.span,
    },
    tagged: {
      v: match tagged.v {
        Bool(b) => Custom(b)
        _ => Auto
      },
      span: tagged.span,
    },
    pretty: { v: pretty.v is Bool(true), span: pretty.span, },
  }
}

///|
/// Partially specified document settings for PDF export (upstream
/// `PdfFormatOptions<Partial>`).
pub(all) struct PartialPdfFormatOptions {
  pages : @library.PageRanges??
  standard : @library.PdfStandards?
  tagged : @library.Smart[Bool]?
  pretty : Bool?
}

///|
pub fn PartialPdfFormatOptions::default() -> PartialPdfFormatOptions {
  { pages: None, standard: None, tagged: None, pretty: None, }
}

///|
/// Resolves the partial options to complete ones, given defaults.
pub fn PartialPdfFormatOptions::resolve(
  self : PartialPdfFormatOptions,
  default : PdfFormatOptions,
) -> PdfFormatOptions {
  {
    pages: match self.pages {
      Some(v) => @library.SpannedValue::detached(v)
      None => default.pages
    },
    standard: match self.standard {
      Some(v) => @library.SpannedValue::detached(v)
      None => default.standard
    },
    tagged: match self.tagged {
      Some(v) => @library.SpannedValue::detached(v)
      None => default.tagged
    },
    pretty: match self.pretty {
      Some(v) => @library.SpannedValue::detached(v)
      None => default.pretty
    },
  }
}

///|
fn default_format_options(
  standard : @library.SpannedValue[@library.Value],
  tagged : @library.SpannedValue[@library.Value],
  pretty : @library.SpannedValue[@library.Value],
) -> PdfFormatOptions {
  {
    pages: @library.SpannedValue::detached(None),
    standard: {
      v: @library.FromValue::from_value(standard.v) catch {
        _ => @library.PdfStandards::default()
      },
      span: standard.span,
    },
    tagged: {
      v: match tagged.v {
        Bool(b) => Custom(b)
        _ => Auto
      },
      span: tagged.span,
    },
    pretty: { v: pretty.v is Bool(true), span: pretty.span, },
  }
}
