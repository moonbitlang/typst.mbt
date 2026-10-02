// Constructors for images with given metadata, without decoding. Only for
// building synthetic frames in tests (e.g. the frame dump encoder tests);
// real images come from the decoders.

///|
/// A raster image with the given metadata (not decoded; test use only).
pub fn RasterImage::synthetic(
  data : Bytes,
  format : RasterFormat,
  width~ : UInt,
  height~ : UInt,
  dpi? : Double,
) -> RasterImage {
  {
    data,
    format,
    width,
    height,
    color: Rgba8,
    dynamic: None,
    exif_rotation: None,
    icc: None,
    dpi,
  }
}

///|
/// An SVG image with the given size (not parsed; test use only).
pub fn SvgImage::synthetic(
  data : Bytes,
  width : Double,
  height : Double,
) -> SvgImage {
  let tree = @usvg.Tree::from_str(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>",
    @usvg.Options::default(),
  ) catch {
    _ => abort("unreachable")
  }
  { data, width, height, fonts: [], tree }
}

///|
/// A PDF image of a document with the given page sizes (not parsed; test use
/// only).
pub fn PdfImage::synthetic(
  data : Bytes,
  pages : Array[(Float, Float)],
  page_index : Int,
) -> PdfImage {
  let document = { data, pages, optional_content_groups: false, }
  let (width, height) = pages[page_index]
  { document, page_index, width, height, }
}
