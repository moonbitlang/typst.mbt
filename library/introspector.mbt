// Port of the eval-level parts of
// `typst-library/src/introspection/introspector.rs`.
//
// Before layout there is no document to introspect: the `Introspector`
// behaves like upstream's `EmptyIntrospector`. The element introspector built
// from laid-out documents is ported together with layout.

///|
/// Retrieves all matches of the selector in the document.
pub fn Introspector::query(
  self : Introspector,
  _selector : Selector,
) -> Array[Content] {
  ignore(self)
  []
}

///|
/// Retrieves the first match of the selector.
pub fn Introspector::query_first(
  self : Introspector,
  _selector : Selector,
) -> Content? {
  ignore(self)
  None
}

///|
/// Retrieves the single match of the selector, failing if there are none or
/// multiple matches.
pub fn Introspector::query_unique(
  self : Introspector,
  _selector : Selector,
) -> Content raise HintedError {
  ignore(self)
  bail("selector does not match any element")
}

///|
/// Retrieves the single element with the given label, failing if there are
/// none or multiple elements with that label.
pub fn Introspector::query_label(
  self : Introspector,
  label : Label,
) -> Content raise HintedError {
  ignore(self)
  bail("label `\{label.repr()}` does not exist in the document")
}

///|
/// Retrieves all elements that have a label.
pub fn Introspector::query_labelled(self : Introspector) -> Array[Content] {
  ignore(self)
  []
}

///|
/// Retrieves the number of matches of the selector before the location.
pub fn Introspector::query_count_before(
  self : Introspector,
  _selector : Selector,
  _end : Location,
) -> Int {
  ignore(self)
  0
}

///|
/// The number of elements with the given label.
pub fn Introspector::label_count(self : Introspector, _label : Label) -> Int {
  ignore(self)
  0
}

///|
/// The total number of pages of the document the location belongs to.
pub fn Introspector::pages(
  self : Introspector,
  _location : Location,
) -> NonZeroUSize? {
  ignore(self)
  None
}

///|
/// The page number of the location.
pub fn Introspector::page(
  self : Introspector,
  _location : Location,
) -> NonZeroUSize? {
  ignore(self)
  None
}

///|
/// The position of the location as a dictionary (upstream
/// `position(..).and_then(DocumentPosition::into_dict)`).
pub fn Introspector::position_dict(
  self : Introspector,
  _location : Location,
) -> Dict? {
  ignore(self)
  None
}

///|
/// The page numbering of the page the location is on.
pub fn Introspector::page_numbering(
  self : Introspector,
  _location : Location,
) -> Numbering? {
  ignore(self)
  None
}

///|
/// The page supplement of the page the location is on.
pub fn Introspector::page_supplement(
  self : Introspector,
  _location : Location,
) -> Content? {
  ignore(self)
  None
}

///|
/// The document the location belongs to (in bundle export).
pub fn Introspector::document(
  self : Introspector,
  _location : Location,
) -> Location? {
  ignore(self)
  None
}
