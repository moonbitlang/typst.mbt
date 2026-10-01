// Placeholder definitions for types used by the `Routines` contracts whose
// ports are pending. Each is replaced wholesale by its real port (in its own
// file named after the upstream module).

///|
/// A finished layout with items at fixed positions. (placeholder; see
/// layout/frame.rs)
pub struct Frame {
  /// The size of the frame.
  size : Axes[Abs]
}

///|
/// Create a new, empty frame.
pub fn Frame::new(size : Axes[Abs]) -> Frame {
  { size, }
}

///|
/// The size of the frame.
pub fn Frame::size(self : Frame) -> Axes[Abs] {
  self.size
}

///|
/// A single region to layout into. (placeholder; see layout/regions.rs)
pub(all) struct Region {
  /// The size of the region.
  size : Axes[Abs]
  /// Whether elements should expand to fill the regions instead of shrinking
  /// to fit the content.
  expand : Axes[Bool]
}

///|
/// Create a new region.
pub fn Region::new(size : Axes[Abs], expand : Axes[Bool]) -> Region {
  { size, expand, }
}

///|
/// Details about the document. (placeholder; see model/document.rs)
pub(all) struct DocumentInfo {
  /// The document's title.
  mut title : String?
  /// The document's author(s).
  mut author : Array[String]
  /// The document's description.
  mut description : String?
  /// The document's keywords.
  mut keywords : Array[String]
  /// The document's creation date.
  mut date : Smart[Datetime?]
  /// The document's language (`Smart<Locale>`; locales are not ported yet).
  mut locale : Smart[Value]
}

///|
/// Default document info.
pub fn DocumentInfo::new() -> DocumentInfo {
  {
    title: None,
    author: [],
    description: None,
    keywords: [],
    date: Auto,
    locale: Auto,
  }
}

///|
/// A list of format options that have been configured by the document.
/// (placeholder; see format.rs)
pub struct DocumentFormatOptions {
  /// The options, by format element.
  options : Map[String, Value]
}

///|
/// Empty format options.
pub fn DocumentFormatOptions::new() -> DocumentFormatOptions {
  { options: {}, }
}
