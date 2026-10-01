// Port of `PagedPosition` of `typst-library/src/introspection/position.rs`
// (and the minimal `Point` of `typst-library/src/layout/point.rs` it needs).
//
// NOTE: a fuller port of this module (with `DocumentPosition`,
// `HtmlPosition`, fingerprints) lives on the introspection branch; this file
// is the API-compatible subset needed by link destinations and should be
// replaced by it on merge.

///|
/// A point in 2D (upstream `layout::Point`; minimal port).
pub(all) struct Point {
  /// The x coordinate.
  x : Abs
  /// The y coordinate.
  y : Abs
} derive(Eq, Hash, Default)

///|
/// Create a new point from x and y coordinates.
pub fn Point::new(x : Abs, y : Abs) -> Point {
  { x, y, }
}

///|
/// The origin point.
pub fn Point::zero() -> Point {
  { x: Abs::zero(), y: Abs::zero(), }
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
