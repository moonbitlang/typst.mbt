// Port of `typst-library/src/introspection/position.rs`.

///|
/// A position in a document.
pub(all) enum DocumentPosition {
  /// A position in a paged document.
  Paged(PagedPosition)
  /// A position in an HTML document.
  Html(HtmlPosition)
} derive(Eq)

///|
/// Returns the paged position, if this is one.
pub fn DocumentPosition::as_paged(self : DocumentPosition) -> PagedPosition? {
  match self {
    Paged(position) => Some(position)
    Html(_) => None
  }
}

///|
/// Returns the paged position or the origin of the first page.
pub fn DocumentPosition::as_paged_or_default(
  self : DocumentPosition,
) -> PagedPosition {
  self.as_paged().unwrap_or(PagedPosition::origin())
}

///|
/// Returns the HTML position, if this is one.
pub fn DocumentPosition::as_html(self : DocumentPosition) -> HtmlPosition? {
  match self {
    Html(position) => Some(position)
    Paged(_) => None
  }
}

///|
/// Converts the position into the dictionary returned by
/// `location.position()`.
pub fn DocumentPosition::into_dict(self : DocumentPosition) -> Dict? {
  match self {
    Paged(pos) => Some(pos.to_dict())
    // HTML documents have no pages, so there is no `page` key. Coordinates
    // are only known inside frames, see `Location::position`.
    Html(pos) =>
      match pos.details() {
        Some(Frame(point)) => {
          let dict = Dict::new()
          dict.insert("x", Length(Length::from_abs(point.x)))
          dict.insert("y", Length(Length::from_abs(point.y)))
          Some(dict)
        }
        Some(Character(_)) | None => None
      }
  }
}

///|
pub impl Fingerprint for DocumentPosition with fn fingerprint(self, state) {
  match self {
    Paged(pos) => {
      state.write_discriminant(0)
      state.write(pos)
    }
    Html(pos) => {
      state.write_discriminant(1)
      state.write(pos)
    }
  }
}

///|
/// A physical position in a paged document.
pub(all) struct PagedPosition {
  /// The page, starting at 1.
  page : NonZeroUSize
  /// The exact coordinates on the page (from the top left, as usual).
  point : Point
} derive(Eq)

///|
/// The origin of the first page.
pub fn PagedPosition::origin() -> PagedPosition {
  { page: NonZeroUSize(1L), point: Point::zero(), }
}

///|
/// Upstream `From<PagedPosition> for Dict`.
pub fn PagedPosition::to_dict(self : PagedPosition) -> Dict {
  let dict = Dict::new()
  dict.insert("page", self.page.into_value())
  dict.insert("x", Length(Length::from_abs(self.point.x)))
  dict.insert("y", Length(Length::from_abs(self.point.y)))
  dict
}

///|
pub impl Fingerprint for PagedPosition with fn fingerprint(self, state) {
  state.write_i64(self.page.0)
  state.write(self.point)
}

// cast! {
//     PagedPosition,
//     self => Value::Dict(self.into()),
//     mut dict: Dict => {
//         let page = dict.take("page")?.cast()?;
//         let x: Length = dict.take("x")?.cast()?;
//         let y: Length = dict.take("y")?.cast()?;
//         dict.finish(&["page", "x", "y"])?;
//         Self { page, point: Point::new(x.abs, y.abs) }
//     },
// }

///|
pub impl Reflect for PagedPosition with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for PagedPosition with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for PagedPosition with fn castable(v) {
  v is Dict(_)
}

///|
pub extend PagedPosition with Reflect::{output, input, castable}

///|
pub impl IntoValue for PagedPosition with fn into_value(self) {
  Dict(self.to_dict())
}

///|
pub impl FromValue for PagedPosition with fn from_value(v) {
  match v {
    Dict(dict) => {
      let dict = dict.copy()
      let page : NonZeroUSize = dict.take("page").cast()
      let x : Length = dict.take("x").cast()
      let y : Length = dict.take("y").cast()
      dict.finish(["page", "x", "y"])
      { page, point: Point::new(x.abs, y.abs), }
    }
    v => raise HintedError(PagedPosition::input().error(v))
  }
}

///|
/// A position in an HTML document.
pub(all) struct HtmlPosition {
  /// Indices that can be used to traverse the tree from the root to the
  /// element at this position.
  priv element : Array[Int]
  /// A more precise position inside of the element.
  priv inner : InnerHtmlPosition?
} derive(Eq)

///|
/// Create a position pointing to an element.
pub fn HtmlPosition::new(element : Array[Int]) -> HtmlPosition {
  { element, inner: None, }
}

///|
/// Specify a character offset inside of the element.
pub fn HtmlPosition::at_char(self : HtmlPosition, offset : Int) -> HtmlPosition {
  { element: self.element, inner: Some(Character(offset)), }
}

///|
/// Specify a point in a frame inside of the element.
pub fn HtmlPosition::in_frame(
  self : HtmlPosition,
  point : Point,
) -> HtmlPosition {
  { element: self.element, inner: Some(Frame(point)), }
}

///|
/// Extra details about the position inside of the element.
pub fn HtmlPosition::details(self : HtmlPosition) -> InnerHtmlPosition? {
  self.inner
}

///|
/// The indices to traverse the tree from the root to the element.
pub fn HtmlPosition::element(self : HtmlPosition) -> ArrayView[Int] {
  self.element
}

///|
pub impl Fingerprint for HtmlPosition with fn fingerprint(self, state) {
  state.write(self.element)
  state.write(self.inner)
}

///|
/// A precise position inside of an HTML element.
pub(all) enum InnerHtmlPosition {
  /// If the element is a frame, this specifies the position inside of the
  /// frame.
  Frame(Point)
  /// If the element is a text node, this specifies the character offset.
  Character(Int)
} derive(Eq)

///|
pub impl Fingerprint for InnerHtmlPosition with fn fingerprint(self, state) {
  match self {
    Frame(point) => {
      state.write_discriminant(0)
      state.write(point)
    }
    Character(offset) => {
      state.write_discriminant(1)
      state.write_usize(offset)
    }
  }
}
