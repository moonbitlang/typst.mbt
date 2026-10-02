// Port of `typst-library/src/visualize/image/pdf.rs`: `PdfDocument` and
// `PdfImage`.
//
// TODO: Upstream reads PDFs with `hayro-syntax`. No PDF reader is ported
// yet, so `PdfDocument::new` fails with a "not yet ported" error. A port
// needs the page count, each page's render dimensions (crop box within the
// media box, rotated) and whether the document has optional content groups.

///|
/// An error while loading a PDF (upstream `hayro_syntax::LoadPdfError`).
pub(all) suberror LoadPdfError {
  /// The PDF is encrypted and could not be decrypted.
  Decryption
  /// The PDF is invalid.
  Invalid
  /// Loading needs functionality that is not ported yet.
  Unported(String)
} derive(Debug)

///|
/// A PDF document.
pub struct PdfDocument {
  priv data : Bytes
  /// The render dimensions (width, height) of each page.
  priv pages : Array[(Float, Float)]
  priv optional_content_groups : Bool
}

///|
/// A PDF document is identified by its data.
pub impl Eq for PdfDocument with fn equal(self, other) {
  self.data == other.data
}

///|
pub impl Hash for PdfDocument with fn hash_combine(self, hasher) {
  hasher.combine(self.data)
}

///|
/// Loads a PDF document.
pub fn PdfDocument::new(data : Bytes) -> PdfDocument raise LoadPdfError {
  ignore(data)
  raise Unported("PDF images are not yet ported (needs a PDF reader)")
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
  self.optional_content_groups
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
  if page_index < 0 || page_index >= document.pages.length() {
    return None
  }
  let (width, height) = document.pages[page_index]
  Some({ document, page_index, width, height, })
}

///|
/// Returns the underlying Typst PDF document.
pub fn PdfImage::document(self : PdfImage) -> PdfDocument {
  self.document
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
