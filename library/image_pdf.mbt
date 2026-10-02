// Port of `typst-library/src/visualize/image/pdf.rs`: `PdfDocument` and
// `PdfImage`, on top of the `hayro-syntax` port.

///|
/// An error while loading a PDF (upstream `hayro_syntax::LoadPdfError`).
pub(all) suberror LoadPdfError {
  /// The PDF is encrypted and could not be decrypted.
  Decryption
  /// The PDF is invalid.
  Invalid
} derive(Debug)

///|
/// A PDF document.
pub struct PdfDocument {
  /// The parsed document (`None` only for synthetic test documents).
  priv pdf : @hayro_syntax.Pdf?
  priv data : Bytes
  /// The render dimensions of the pages.
  priv pages : Array[(Float, Float)]
}

///|
/// A PDF document is identified by its data.
pub impl Eq for PdfDocument with fn equal(self, other) {
  physical_equal(self.data, other.data) || self.data == other.data
}

///|
pub impl Hash for PdfDocument with fn hash_combine(self, hasher) {
  hasher.combine(self.data)
}

///|
/// Cache of loaded documents (upstream memoizes `PdfDocument::new`).
let pdf_document_cache : Map[Bytes, PdfDocument] = Map::new()

///|
/// Loads a PDF document.
pub fn PdfDocument::new(data : Bytes) -> PdfDocument raise LoadPdfError {
  if pdf_document_cache.get(data) is Some(doc) {
    return doc
  }
  let pdf = match @hayro_syntax.Pdf::new(data) {
    Ok(pdf) => pdf
    Err(Decryption(_)) => raise Decryption
    Err(Invalid) => raise Invalid
  }
  let pages = pdf.pages().iter().map(p => p.render_dimensions()).collect()
  let doc = { pdf: Some(pdf), data, pages, }
  pdf_document_cache[data] = doc
  doc
}

///|
/// A document with the given page sizes that is not parsed (test use only).
pub fn PdfDocument::synthetic(
  data : Bytes,
  pages : Array[(Float, Float)],
) -> PdfDocument {
  { pdf: None, data, pages, }
}

///|
/// Returns the underlying PDF document.
pub fn PdfDocument::pdf(self : PdfDocument) -> @hayro_syntax.Pdf {
  match self.pdf {
    Some(pdf) => pdf
    None => abort("synthetic PDF document")
  }
}

///|
/// The raw data of the PDF.
pub fn PdfDocument::data(self : PdfDocument) -> Bytes {
  self.data
}

///|
/// Return the number of pages in the PDF.
pub fn PdfDocument::num_pages(self : PdfDocument) -> Int {
  self.pages.length()
}

///|
/// Whether the document has optional content groups (upstream
/// `pdf.xref().has_optional_content_groups()`).
pub fn PdfDocument::has_optional_content_groups(self : PdfDocument) -> Bool {
  self.pdf is Some(pdf) && pdf.xref().has_optional_content_groups()
}

///|
/// A specific page of a PDF acting as an image.
pub struct PdfImage {
  priv document : PdfDocument
  priv page_index : Int
  priv width : Float
  priv height : Float
}

///|
pub impl Eq for PdfImage with fn equal(self, other) {
  self.document == other.document && self.page_index == other.page_index
}

///|
pub impl Hash for PdfImage with fn hash_combine(self, hasher) {
  hasher.combine(self.document)
  hasher.combine(self.page_index)
}

///|
/// Creates a new PDF image.
///
/// Returns `None` if the page index is not valid.
pub fn PdfImage::new(document : PdfDocument, page_index : Int) -> PdfImage? {
  guard document.pages.get(page_index) is Some((width, height)) else {
    return None
  }
  Some({ document, page_index, width, height, })
}

///|
/// Returns the underlying Typst PDF document.
pub fn PdfImage::document(self : PdfImage) -> PdfDocument {
  self.document
}

///|
/// Returns the PDF page of the image.
pub fn PdfImage::page(self : PdfImage) -> @hayro_syntax.Page {
  self.document.pdf().pages()[self.page_index]
}

///|
/// Returns the width of the image.
pub fn PdfImage::width(self : PdfImage) -> Float {
  self.width
}

///|
/// Returns the height of the image.
pub fn PdfImage::height(self : PdfImage) -> Float {
  self.height
}

///|
/// Returns the page index of the image.
pub fn PdfImage::page_index(self : PdfImage) -> Int {
  self.page_index
}
