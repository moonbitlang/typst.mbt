// Port of `typst-pdf/src/lib.rs`: exporting Typst documents to PDF.
//
// The PDF objects are written by pdflite's `export` package (a port of the
// parts of krilla that Typst uses) instead of krilla.

///|
/// Export a document into a PDF file.
///
/// Returns the raw bytes making up the PDF file.
pub fn pdf(
  document : @layout.PagedDocument,
  options : PdfOptions,
) -> @library.Warned[Result[Bytes, Array[@library.SourceDiagnostic]]] {
  let warnings = []
  let output = convert(document, options, [], None, warnings)
  { output, warnings, }
}

///|
/// Export a document into a PDF file as part of a bundle.
///
/// Takes additional `anchor` locations that will be serialized as named
/// destinations. This enables other documents in the bundle to link into the
/// resulting PDF. Also takes a `link_resolver` for resolving cross-document
/// links.
pub fn pdf_in_bundle(
  document : @layout.PagedDocument,
  options : PdfOptions,
  anchors : Array[(@library.Location, String)],
  link_resolver : @library.LateLinkResolver,
) -> @library.Warned[Result[Bytes, Array[@library.SourceDiagnostic]]] {
  let warnings = []
  let output = convert(
    document,
    options,
    anchors,
    Some(link_resolver),
    warnings,
  )
  { output, warnings, }
}

///|
/// A timestamp with timezone information.
pub(all) struct Timestamp {
  /// The datetime of the timestamp.
  datetime : @library.Datetime
  /// The timezone of the timestamp.
  timezone : Timezone
}

///|
/// Create a new timestamp with a given datetime and UTC suffix.
pub fn Timestamp::new_utc(datetime : @library.Datetime) -> Timestamp {
  { datetime, timezone: UTC, }
}

///|
/// Create a new timestamp with a given datetime, and a local timezone
/// offset.
pub fn Timestamp::new_local(
  datetime : @library.Datetime,
  whole_minute_offset : Int,
) -> Timestamp? {
  let hour_offset = whole_minute_offset / 60
  // Note: the `%` operator is the remainder operator, which can be
  // negative; the minute offset has the same sign as the hour offset.
  let minute_offset = (whole_minute_offset % 60).abs()
  if hour_offset >= -23 && hour_offset <= 23 && minute_offset <= 59 {
    Some({ datetime, timezone: Local(hour_offset, minute_offset), })
  } else {
    None
  }
}

///|
/// A timezone.
pub(all) enum Timezone {
  /// The UTC timezone.
  UTC
  /// The local timezone offset from UTC (hours and minutes; the minute
  /// offset has the same sign as the hour offset).
  Local(Int, Int)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Timezone with Eq::{not_equal, equal}

///|
/// Settings for PDF export.
pub(all) struct PdfOptions {
  /// If not `Auto`, shall be a string that uniquely and stably identifies
  /// the document. It should not change between compilations of the same
  /// document.
  ident : @library.Smart[String]
  /// Configures the `/Creator` metadata in the resulting PDF. When set to
  /// `Auto`, defaults to `Typst $version`.
  creator : @library.Smart[String?]
  /// If not `None`, shall be the creation timestamp of the document. It will
  /// only be used if `set document(date: ..)` is `auto`.
  timestamp : Timestamp?
  /// Format options that override the defaults set by the document.
  format : PartialPdfFormatOptions
}

///|
pub fn PdfOptions::default() -> PdfOptions {
  {
    ident: Auto,
    creator: Auto,
    timestamp: None,
    format: PartialPdfFormatOptions::default(),
  }
}

///|
/// Settings for PDF export, resolved against the document's options
/// (upstream `PdfOptions<Complete>`).
pub(all) struct CompletePdfOptions {
  ident : @library.Smart[String]
  creator : @library.Smart[String?]
  timestamp : Timestamp?
  format : PdfFormatOptions
}

///|
/// Resolves the final options given those set by the document.
pub fn PdfOptions::resolve(
  self : PdfOptions,
  doc : PdfFormatOptions,
  warnings : Array[@library.SourceDiagnostic],
) -> CompletePdfOptions raise @library.SourceError {
  let format = self.format.resolve(doc)
  if format.pages.v is Some(_) {
    if format.tagged.v == Custom(true) {
      let span = or_span(format.tagged.span, format.pages.span)
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          span, "cannot enable tagged PDF and export a page range",
        ),
      ])
    } else if format.tagged.v is Auto {
      warnings.push(
        @library.SourceDiagnostic::warning_at(
          format.tagged.span,
          "exporting a page range disables PDF tagging",
        ).with_hints([
          "the resulting PDF will be inaccessible", "set `pdf(tagged: false)` to silence this warning",
        ]),
      )
    }
  }
  let accessible : Array[(@library.PdfStandard, String)] = [
    (A_1a, "PDF/A-1a"),
    (A_2a, "PDF/A-2a"),
    (A_3a, "PDF/A-3a"),
    (UA_1, "PDF/UA-1"),
  ]
  for entry in accessible {
    let (standard, name) = entry
    if format.standard.v.standards().contains(standard) {
      if format.tagged.v == Custom(false) {
        let span = or_span(format.standard.span, format.tagged.span)
        raise @library.SourceError([
          @library.SourceDiagnostic::error_at(
            span,
            "cannot set `pdf(tagged: false)` when exporting a \{name} document",
          ),
        ])
      } else if format.pages.v is Some(_) {
        let span = or_span(format.standard.span, format.pages.span)
        raise @library.SourceError([
          @library.SourceDiagnostic::error_at(
            span,
            "cannot set `pdf(tagged: false)` when exporting a \{name} document",
          ).with_hint("using `pdf(pages: ...)` implies `pdf(tagged: false)`"),
        ])
      }
    }
  }
  {
    ident: self.ident,
    creator: self.creator,
    timestamp: self.timestamp,
    format,
  }
}

///|
/// `span.or(other)`: the first span unless it is detached.
fn or_span(a : @syntax.Span, b : @syntax.Span) -> @syntax.Span {
  if a.is_detached() {
    b
  } else {
    a
  }
}

///|
/// The PDF version to export.
fn CompletePdfOptions::version(self : CompletePdfOptions) -> @export.PdfVersion {
  convert_version(self.format.standard.v.config.version)
}

///|
/// Returns whether to produce a tagged PDF document. By default unless
/// explicitly disabled or when only exporting a page range, tagging is
/// enabled.
fn CompletePdfOptions::tagged(self : CompletePdfOptions) -> Bool {
  self.format.pages.v is None &&
  (match self.format.tagged.v {
    Custom(b) => b
    Auto => true
  })
}

///|
/// Returns the validators.
fn CompletePdfOptions::validators(
  self : CompletePdfOptions,
) -> @export.Validators {
  convert_validators(self.format.standard.v.config.validators)
}

///|
fn convert_version(v : @library.PdfVersion) -> @export.PdfVersion {
  match v {
    Pdf14 => Pdf14
    Pdf15 => Pdf15
    Pdf16 => Pdf16
    Pdf17 => Pdf17
    Pdf20 => Pdf20
  }
}

///|
fn convert_validators(v : @library.Validators) -> @export.Validators {
  {
    a: match v.a {
      None => None
      Some(a) =>
        Some(
          match a {
            A1_A => A1_A
            A1_B => A1_B
            A2_A => A2_A
            A2_B => A2_B
            A2_U => A2_U
            A3_A => A3_A
            A3_B => A3_B
            A3_U => A3_U
            A4 => A4
            A4F => A4F
            A4E => A4E
          },
        )
    },
    ua: match v.ua {
      None => None
      Some(_) => Some(UA1)
    },
  }
}
