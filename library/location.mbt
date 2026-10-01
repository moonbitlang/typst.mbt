// Port of `typst-library/src/introspection/location.rs` (the `Location`
// struct itself lives in `engine.mbt`).

///|
pub fn Location::repr(self : Location) -> String {
  ignore(self)
  "location(..)"
}

///|
pub impl Reflect for Location with fn input() {
  Type(Type::location())
}

///|
pub impl Reflect for Location with fn output() {
  Type(Type::location())
}

///|
pub impl Reflect for Location with fn castable(v) {
  v is Dyn(Location(_))
}

///|
pub impl IntoValue for Location with fn into_value(self) {
  Dyn(Location(self))
}

///|
pub impl FromValue for Location with fn from_value(v) {
  match v {
    Dyn(Location(loc)) => loc
    v => raise HintedError(CastInfo::Type(Type::location()).error(v))
  }
}

///|
/// Returns the page number for this location.
///
/// Note that this does not return the value of the @counter[page counter]
/// at this location, but the true page number (starting from one).
fn impl_location_page(
  self_ : Location,
  engine : Engine,
  span : @syntax.Span,
) -> NonZeroUSize? raise HintedError {
  ignore(span)
  engine.introspector.page(self_)
}

///|
/// Returns the page numbering pattern of the page at this location.
fn impl_location_page_numbering(
  self_ : Location,
  engine : Engine,
  span : @syntax.Span,
) -> Numbering? raise HintedError {
  ignore(span)
  engine.introspector.page_numbering(self_)
}

///|
/// Returns a dictionary with the page number and the x, y position for this
/// location.
fn impl_location_position(
  self_ : Location,
  engine : Engine,
  span : @syntax.Span,
) -> Dict? raise HintedError {
  ignore(span)
  engine.introspector.position_dict(self_)
}

///|
/// The location of the content. This is only available on content returned
/// by @query or provided by a @reference:styling:show-rules[show rule], for
/// other content it will be `{none}`.
fn impl_content_location(self_ : Content) -> Location? raise HintedError {
  self_.location()
}
