// Port of `hayro-syntax/src/pdf.rs`: the starting point for reading PDF
// files.

///|
/// A PDF file.
pub struct Pdf {
  priv xref : XRef
  priv header_version : PdfVersion
  priv pages : Pages
  priv data : Bytes
}

///|
/// An error that occurred while loading a PDF file.
pub(all) enum LoadPdfError {
  /// An error occurred while processing an encrypted document.
  Decryption(DecryptionError)
  /// The PDF was invalid or could not be parsed due to some other unknown reason.
  Invalid
} derive(Eq, Debug)

///|
/// Try to read the given PDF file.
///
/// Returns `Err` if it was unable to read it.
pub fn Pdf::new(data : Bytes) -> Result[Pdf, LoadPdfError] {
  Pdf::new_with_password(data, "")
}

///|
/// Try to read the given PDF file with a password.
pub fn Pdf::new_with_password(
  data : Bytes,
  password : String,
) -> Result[Pdf, LoadPdfError] {
  let password = @utf8.encode(password)
  let version = find_version(data[:]).unwrap_or(Pdf10)
  let xref = match root_xref(data, password) {
    Ok(x) => x
    Err(Unknown) =>
      match fallback(data, password) {
        Some(x) => x
        None => return Err(Invalid)
      }
    Err(Encryption(e)) => return Err(Decryption(e))
  }
  let ctx = ReaderContext::new(xref, false)
  let pages_dict : Dict? = xref.get_with(xref.trailer_data().pages_ref, ctx)
  let pages = match pages_dict.bind(p => Pages::new(p, ctx, xref)) {
    Some(p) => p
    None =>
      match Pages::new_brute_force(ctx, xref) {
        Some(p) => p
        None => return Err(Invalid)
      }
  }
  Ok({ xref, header_version: version, pages, data, })
}

///|
/// Return the number of objects present in the PDF file.
pub fn Pdf::len(self : Pdf) -> Int {
  self.xref.len()
}

///|
/// Return all objects defined in the PDF file.
pub fn Pdf::objects(self : Pdf) -> Array[Object] {
  self.xref.objects()
}

///|
/// Return the version of the PDF file.
pub fn Pdf::version(self : Pdf) -> PdfVersion {
  self.xref.trailer_data().version.unwrap_or(self.header_version)
}

///|
/// Return the underlying data of the PDF file.
pub fn Pdf::data(self : Pdf) -> Bytes {
  self.data
}

///|
/// Return the pages of the PDF file.
pub fn Pdf::pages(self : Pdf) -> Pages {
  self.pages
}

///|
/// Return the xref of the PDF file.
pub fn Pdf::xref(self : Pdf) -> XRef {
  self.xref
}

///|
fn find_version(data : BytesView) -> PdfVersion? {
  let data = data[:@cmp.minimum(data.length(), 2000)]
  let r = Reader::new(data)
  while r.forward_tag(b"%PDF-") is None {
    guard r.read_byte() is Some(_) else { return None }
  }
  guard r.tail() is Some(tail) else { return None }
  PdfVersion::from_bytes(tail)
}

///|
/// The version of a PDF document.
pub(all) enum PdfVersion {
  /// PDF 1.0.
  Pdf10
  /// PDF 1.1.
  Pdf11
  /// PDF 1.2.
  Pdf12
  /// PDF 1.3.
  Pdf13
  /// PDF 1.4.
  Pdf14
  /// PDF 1.5.
  Pdf15
  /// PDF 1.6.
  Pdf16
  /// PDF 1.7.
  Pdf17
  /// PDF 2.0.
  Pdf20
} derive(Eq, Compare, Debug)

///|
pub fn PdfVersion::as_str(self : PdfVersion) -> String {
  match self {
    Pdf10 => "1.0"
    Pdf11 => "1.1"
    Pdf12 => "1.2"
    Pdf13 => "1.3"
    Pdf14 => "1.4"
    Pdf15 => "1.5"
    Pdf16 => "1.6"
    Pdf17 => "1.7"
    Pdf20 => "2.0"
  }
}

///|
pub fn PdfVersion::from_bytes(bytes : BytesView) -> PdfVersion? {
  if bytes.length() < 3 {
    return None
  }
  match bytes[0:3] {
    [b'1', b'.', b'0'] => Some(Pdf10)
    [b'1', b'.', b'1'] => Some(Pdf11)
    [b'1', b'.', b'2'] => Some(Pdf12)
    [b'1', b'.', b'3'] => Some(Pdf13)
    [b'1', b'.', b'4'] => Some(Pdf14)
    [b'1', b'.', b'5'] => Some(Pdf15)
    [b'1', b'.', b'6'] => Some(Pdf16)
    [b'1', b'.', b'7'] => Some(Pdf17)
    [b'2', b'.', b'0'] => Some(Pdf20)
    _ => None
  }
}
