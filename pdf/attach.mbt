// Port of `typst-pdf/src/attach.rs`.

///|
fn attach_files(
  gc : GlobalContext,
  document : @export.Document,
) -> Unit raise @library.SourceError {
  let elements = gc.document
    .introspector()
    .query(@library.pdf_attach_elem().select())
  for content in elements {
    guard @library.PdfAttachElem::of(content) is Some(elem) else { continue }
    let span = content.span()
    let styles = @library.StyleChain::empty()
    let derived_path = elem.path().resolve_if_some(span.id()) catch {
        _ => continue
      }
    let derived_path = derived_path.vpath().get_without_slash()
    let path = derived_path
    let mime_type = match elem.mime_type(styles) {
      Some(s) =>
        if valid_mime_type(s) {
          Some(s)
        } else {
          raise @library.SourceError([
            @library.SourceDiagnostic::error_at(span, "invalid mime type"),
          ])
        }
      None => None
    }
    let description = elem.description(styles)
    let association_kind : @export.AssociationKind = match
      elem.relationship(styles) {
      None => Unspecified
      Some(Source) => Source
      Some(Data) => Data
      Some(Alternative) => Alternative
      Some(Supplement) => Supplement
    }
    let data = elem.data().as_slice()
    let file : @export.EmbeddedFile = {
      path,
      mime_type,
      description,
      association_kind,
      data,
      compress: should_compress(data),
      location: Some(span.0),
      modification_date: creation_date(gc),
    }
    if document.embed_file(file) is None {
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          span,
          "attempted to attach file \{derived_path} twice",
        ),
      ])
    }
  }
}

///|
/// Whether a mime type is valid (krilla `MimeType::new`).
fn valid_mime_type(mime_type : String) -> Bool {
  let parts = mime_type.split("/").collect()
  if parts.length() != 2 {
    return false
  }
  let valid_part = (part : StringView) => {
    if part.is_empty() {
      return false
    }
    for c in part {
      if !((c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-' ||
        c == '+' ||
        c == '.') {
        return false
      }
    }
    true
  }
  valid_part(parts[0]) && valid_part(parts[1])
}

///|
fn has_prefix(data : Bytes, prefix : Array[Int]) -> Bool {
  if data.length() < prefix.length() {
    return false
  }
  for i, b in prefix {
    if data[i].to_int() != b {
      return false
    }
  }
  true
}

///|
/// Whether to compress an attachment: already compressed archives, audio
/// and video are stored as is (a subset of the `infer` matchers upstream
/// uses).
fn should_compress(data : Bytes) -> Bool? {
  let incompressible = [
    [0x50, 0x4B, 0x03, 0x04], // zip
    [0x1F, 0x8B], // gzip
    [0x42, 0x5A, 0x68], // bzip2
    [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C], // 7z
    [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00], // xz
    [0x28, 0xB5, 0x2F, 0xFD], // zstd
    [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07], // rar
    [0x49, 0x44, 0x33], // mp3 (ID3)
    [0x4F, 0x67, 0x67, 0x53], // ogg
    [0x66, 0x4C, 0x61, 0x43], // flac
    [0x1A, 0x45, 0xDF, 0xA3], // matroska/webm
  ]
  for p in incompressible {
    if has_prefix(data, p) {
      return Some(false)
    }
  }
  None
}
