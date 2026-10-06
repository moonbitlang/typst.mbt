// Port of `hayro-syntax/src/page.rs`: reading the pages of a PDF document.

///|
/// Attributes that can be inherited.
priv struct PagesContext {
  media_box : Rect?
  crop_box : Rect?
  rotate : Int?
}

///|
/// A PDF rectangle.
pub(all) struct Rect {
  /// The minimum x coordinate.
  x0 : Double
  /// The minimum y coordinate.
  y0 : Double
  /// The maximum x coordinate.
  x1 : Double
  /// The maximum y coordinate.
  y1 : Double
} derive(Eq, Debug)

///|
/// A new rectangle from minimum and maximum coordinates.
pub fn Rect::new(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Rect {
  { x0, y0, x1, y1, }
}

///|
/// The intersection of two rectangles.
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect {
  let x0 = @cmp.maximum(self.x0, other.x0)
  let y0 = @cmp.maximum(self.y0, other.y0)
  let x1 = @cmp.minimum(self.x1, other.x1)
  let y1 = @cmp.minimum(self.y1, other.y1)
  Rect::new(x0, y0, @cmp.maximum(x1, x0), @cmp.maximum(y1, y0))
}

///|
/// The width of the rectangle.
pub fn Rect::width(self : Rect) -> Double {
  self.x1 - self.x0
}

///|
/// The height of the rectangle.
pub fn Rect::height(self : Rect) -> Double {
  self.y1 - self.y0
}

///|
fn rect_from_arr(array : PdfArray) -> Rect? {
  let iter : Iter[Float] = array.iter()
  guard iter.next() is Some(x0) else { return None }
  guard iter.next() is Some(y0) else { return None }
  guard iter.next() is Some(x1) else { return None }
  guard iter.next() is Some(y1) else { return None }
  let (x0, y0, x1, y1) = (
    x0.to_double(),
    y0.to_double(),
    x1.to_double(),
    y1.to_double(),
  )
  Some(
    Rect::new(
      @cmp.minimum(x0, x1),
      @cmp.minimum(y0, y1),
      @cmp.maximum(x1, x0),
      @cmp.maximum(y1, y0),
    ),
  )
}

///|
pub impl Readable for Rect with fn read(r, ctx) {
  guard (r.read(ctx) : PdfArray?) is Some(arr) else { return None }
  rect_from_arr(arr)
}

///|
pub impl ObjectLike for Rect with fn from_object(o) {
  match o {
    Array(arr) => rect_from_arr(arr)
    _ => None
  }
}

///|
// <https://github.com/apache/pdfbox/blob/a53a70db16ea3133994120bcf1e216b9e760c05b/pdfbox/src/main/java/org/apache/pdfbox/pdmodel/common/PDRectangle.java#L38>
const POINTS_PER_INCH : Double = 72.0

///|
let points_per_mm : Double = 1.0 / (10.0 * 2.54) * POINTS_PER_INCH

///|
/// The dimension of an A4 page.
pub let a4 : Rect = {
  x0: 0.0,
  y0: 0.0,
  x1: 210.0 * points_per_mm,
  y1: 297.0 * points_per_mm,
}

///|
/// The rotation of the page.
pub(all) enum Rotation {
  /// No rotation (upstream `Rotation::None`).
  NoRotation
  /// A rotation of 90 degrees.
  Horizontal
  /// A rotation of 180 degrees.
  Flipped
  /// A rotation of 270 degrees.
  FlippedHorizontal
} derive(Eq, Debug)

///|
/// A PDF page.
pub struct Page {
  priv inner : Dict
  priv media_box : Rect
  priv crop_box : Rect
  priv rotation : Rotation
  priv mut page_streams : BytesView?? // None = not yet computed
  priv resources : Resources
  priv ctx : ReaderContext
}

///|
fn Page::new(
  dict : Dict,
  ctx : PagesContext,
  resources : Resources,
  brute_force : Bool,
) -> Page? {
  // In general, pages without content are allowed, but in case we are brute-forcing
  // we ignore them.
  if brute_force && !dict.contains_key("Contents") {
    return None
  }
  let media_box = match (dict.get("MediaBox") : Rect?) {
    Some(m) => m
    None => ctx.media_box.unwrap_or(a4)
  }
  let crop_box = match (dict.get("CropBox") : Rect?) {
    Some(c) => c
    None => ctx.crop_box.unwrap_or(media_box)
  }
  let rotate = match (dict.get("Rotate") : Int?) {
    Some(r) => r
    None => ctx.rotate.unwrap_or(0)
  }
  let rem = rotate % 360
  let rem = if rem < 0 { rem + 360 } else { rem }
  let rotation : Rotation = match rem {
    0 => NoRotation
    90 => Horizontal
    180 => Flipped
    270 => FlippedHorizontal
    _ => NoRotation
  }
  let ctx = resources.ctx
  let resources = Resources::from_parent(
    dict.get("Resources").unwrap_or_default(),
    resources,
  )
  Some({
    inner: dict,
    media_box,
    crop_box,
    rotation,
    page_streams: None,
    resources,
    ctx,
  })
}

///|
/// Return the decoded content stream of the page.
pub fn Page::page_stream(self : Page) -> BytesView? {
  match self.page_streams {
    Some(s) => s
    None => {
      let convert_single = (s : Stream) => s.decoded().to_option()
      let computed : BytesView? = match (self.inner.get("Contents") : Stream?) {
        Some(stream) => convert_single(stream).map(d => d.to_owned()[:])
        None =>
          match (self.inner.get("Contents") : PdfArray?) {
            Some(array) => {
              let collected = Buffer()
              for stream in (array.iter() : Iter[Stream]) {
                if convert_single(stream) is Some(data) {
                  collected.write_bytesview(data)
                  // Streams must have at least one whitespace in-between.
                  collected.write_byte(b' ')
                }
              }
              Some(collected.to_bytes()[:])
            }
            None =>
              // contents entry of page was neither stream nor array of streams
              None
          }
      }
      self.page_streams = Some(computed)
      computed
    }
  }
}

///|
/// Get the resources of the page.
pub fn Page::resources(self : Page) -> Resources {
  self.resources
}

///|
/// Get the media box of the page.
pub fn Page::media_box(self : Page) -> Rect {
  self.media_box
}

///|
/// Get the rotation of the page.
pub fn Page::rotation(self : Page) -> Rotation {
  self.rotation
}

///|
/// Get the crop box of the page.
pub fn Page::crop_box(self : Page) -> Rect {
  self.crop_box
}

///|
/// Return the intersection of crop box and media box.
pub fn Page::intersected_crop_box(self : Page) -> Rect {
  self.crop_box().intersect(self.media_box())
}

///|
/// Return the base dimensions of the page (same as `intersected_crop_box`,
/// but with special handling applied for zero-area pages).
pub fn Page::base_dimensions(self : Page) -> (Float, Float) {
  let crop_box = self.intersected_crop_box()
  if is_nearly_zero(Float::from_double(crop_box.width())) ||
    is_nearly_zero(Float::from_double(crop_box.height())) {
    (Float::from_double(a4.width()), Float::from_double(a4.height()))
  } else {
    (
      Float::from_double(@cmp.maximum(crop_box.width(), 1.0)),
      Float::from_double(@cmp.maximum(crop_box.height(), 1.0)),
    )
  }
}

///|
/// Return the with and height of the page that should be assumed when
/// rendering the page.
pub fn Page::render_dimensions(self : Page) -> (Float, Float) {
  let (base_width, base_height) = self.base_dimensions()
  if self.rotation() is (Horizontal | FlippedHorizontal) {
    (base_height, base_width)
  } else {
    (base_width, base_height)
  }
}

///|
/// Return an untyped iterator over the operators of the page's content
/// stream.
pub fn Page::operations(self : Page) -> UntypedIter {
  match self.page_stream() {
    Some(stream) => UntypedIter::new(stream)
    None => UntypedIter::empty()
  }
}

///|
/// Return a typed iterator over the operators of the page's content stream.
pub fn Page::typed_operations(self : Page) -> TypedIter {
  TypedIter::from_untyped(self.operations())
}

///|
/// Get the raw dictionary of the page.
pub fn Page::raw(self : Page) -> Dict {
  self.inner
}

///|
/// Get the xref table (of the document the page belongs to).
pub fn Page::xref(self : Page) -> XRef {
  self.ctx.xref()
}

///|
/// Return the initial transform that should be applied when rendering.
///
/// This accounts for the mismatch between PDF's y-up and most renderers'
/// y-down coordinate system, the rotation of the page and the offset of
/// the crop box.
pub fn Page::initial_transform(self : Page, invert_y : Bool) -> Transform {
  let crop_box = self.intersected_crop_box()
  let (_, base_height) = self.base_dimensions()
  let (width, height) = self.render_dimensions()
  let horizontal_t = Transform::rotate_cw_90() *
    Transform::translate(0.0, -width.to_double())
  let flipped_horizontal_t = Transform::translate(0.0, height.to_double()) *
    Transform::rotate_ccw_90()
  let rotation_transform = match self.rotation() {
    NoRotation => Transform::identity()
    Horizontal => if invert_y { horizontal_t } else { flipped_horizontal_t }
    Flipped =>
      Transform::scale(-1.0) *
      Transform::translate(-width.to_double(), -height.to_double())
    FlippedHorizontal =>
      if invert_y {
        flipped_horizontal_t
      } else {
        horizontal_t
      }
  }
  let inversion_transform = if invert_y {
    Transform::new([1.0, 0.0, 0.0, -1.0, 0.0, base_height.to_double()])
  } else {
    Transform::identity()
  }
  rotation_transform *
  inversion_transform *
  Transform::translate(-crop_box.x0, -crop_box.y0)
}

///|
/// A structure keeping track of the resources of a page.
pub struct Resources {
  priv parent : Resources?
  priv ctx : ReaderContext
  /// The raw dictionary of external graphics states.
  ext_g_states : Dict
  /// The raw dictionary of fonts.
  fonts : Dict
  /// The raw dictionary of properties.
  properties : Dict
  /// The raw dictionary of color spaces.
  color_spaces : Dict
  /// The raw dictionary of x objects.
  x_objects : Dict
  /// The raw dictionary of patterns.
  patterns : Dict
  /// The raw dictionary of shadings.
  shadings : Dict
}

///|
/// Create a new `Resources` object from a dictionary with a parent.
pub fn Resources::from_parent(
  resources : Dict,
  parent : Resources,
) -> Resources {
  let ctx = parent.ctx
  Resources::new(resources, Some(parent), ctx)
}

///|
/// Create a new `Resources` object.
pub fn Resources::new(
  resources : Dict,
  parent : Resources?,
  ctx : ReaderContext,
) -> Resources {
  let get = (key : String) => (resources.get(key) : Dict?).unwrap_or_default()
  {
    parent,
    ext_g_states: get("ExtGState"),
    fonts: get("Font"),
    color_spaces: get("ColorSpace"),
    properties: get("Properties"),
    x_objects: get("XObject"),
    patterns: get("Pattern"),
    shadings: get("Shading"),
    ctx,
  }
}

///|
/// Get the parent in the resource, chain, if available.
pub fn Resources::parent(self : Resources) -> Resources? {
  self.parent
}

///|
/// Get an external graphics state by name.
pub fn Resources::get_ext_g_state(self : Resources, name : Name) -> Dict? {
  match (self.ext_g_states.get(name.0) : Dict?) {
    Some(d) => Some(d)
    None => self.parent.bind(p => p.get_ext_g_state(name))
  }
}

///|
/// Get a color space by name.
pub fn Resources::get_color_space(self : Resources, name : Name) -> Object? {
  match (self.color_spaces.get(name.0) : Object?) {
    Some(d) => Some(d)
    None => self.parent.bind(p => p.get_color_space(name))
  }
}

///|
/// Get a font by name.
pub fn Resources::get_font(self : Resources, name : Name) -> Dict? {
  match (self.fonts.get(name.0) : Dict?) {
    Some(d) => Some(d)
    None => self.parent.bind(p => p.get_font(name))
  }
}

///|
/// Get a pattern by name.
pub fn Resources::get_pattern(self : Resources, name : Name) -> Object? {
  match (self.patterns.get(name.0) : Object?) {
    Some(d) => Some(d)
    None => self.parent.bind(p => p.get_pattern(name))
  }
}

///|
/// Get an x object by name.
pub fn Resources::get_x_object(self : Resources, name : Name) -> Stream? {
  match (self.x_objects.get(name.0) : Stream?) {
    Some(d) => Some(d)
    None => self.parent.bind(p => p.get_x_object(name))
  }
}

///|
/// Get a shading by name.
pub fn Resources::get_shading(self : Resources, name : Name) -> Object? {
  match (self.shadings.get(name.0) : Object?) {
    Some(d) => Some(d)
    None => self.parent.bind(p => p.get_shading(name))
  }
}

///|
/// A structure holding the pages of a PDF document.
pub struct Pages {
  priv pages : Array[Page]
  priv xref : XRef
}

///|
fn Pages::new(pages_dict : Dict, ctx : ReaderContext, xref : XRef) -> Pages? {
  let pages = []
  let pages_ctx : PagesContext = {
    media_box: None,
    crop_box: None,
    rotate: None,
  }
  let resources = Resources::new(Dict::empty(), None, ctx)
  guard resolve_pages(pages_dict, pages, pages_ctx, resources) is Some(_) else {
    return None
  }
  Some({ pages, xref, })
}

///|
/// Create a new `Pages` object by bruteforce-searching.
///
/// Of course this could result in the order of pages being messed up, but
/// this is still better than nothing.
fn Pages::new_brute_force(ctx : ReaderContext, xref : XRef) -> Pages? {
  let pages = []
  for object in xref.objects() {
    if object.into_dict() is Some(dict) &&
      Page::new(
        dict,
        { media_box: None, crop_box: None, rotate: None, },
        Resources::new(Dict::empty(), None, ctx),
        true,
      )
      is Some(page) {
      pages.push(page)
    }
  }
  if pages.is_empty() {
    return None
  }
  Some({ pages, xref, })
}

///|
/// Return the xref table (of the document the pages belong to).
pub fn Pages::xref(self : Pages) -> XRef {
  self.xref
}

///|
/// The number of pages.
pub fn Pages::length(self : Pages) -> Int {
  self.pages.length()
}

///|
/// The page at `index`.
pub fn Pages::get(self : Pages, index : Int) -> Page? {
  self.pages.get(index)
}

///|
pub fn Pages::iter(self : Pages) -> Iter[Page] {
  self.pages.iter()
}

///|
#alias("_[_]")
pub fn Pages::at(self : Pages, index : Int) -> Page {
  self.pages[index]
}

///|
fn resolve_pages(
  pages_dict : Dict,
  entries : Array[Page],
  ctx : PagesContext,
  resources : Resources,
) -> Unit? {
  let mut ctx = ctx
  if (pages_dict.get("MediaBox") : Rect?) is Some(media_box) {
    ctx = { ..ctx, media_box: Some(media_box), }
  }
  if (pages_dict.get("CropBox") : Rect?) is Some(crop_box) {
    ctx = { ..ctx, crop_box: Some(crop_box), }
  }
  if (pages_dict.get("Rotate") : Int?) is Some(rotate) {
    ctx = { ..ctx, rotate: Some(rotate), }
  }
  let resources = Resources::from_parent(
    pages_dict.get("Resources").unwrap_or_default(),
    resources,
  )
  guard (pages_dict.get("Kids") : PdfArray?) is Some(kids) else { return None }
  for dict in (kids.iter() : Iter[Dict]) {
    match (dict.get("Type") : Name?) {
      Some(Name("Pages")) =>
        resolve_pages(dict, entries, ctx, resources) |> ignore
      // Let's be lenient and assume it's a `Page` in case it's `None` or something else
      // (see corpus test case 0083781).
      _ =>
        if Page::new(dict, ctx, resources, false) is Some(page) {
          entries.push(page)
        }
    }
  }
  Some(())
}
