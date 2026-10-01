// Port of `typst-library/src/foundations/selector.rs` (core definition; the
// `selector` type's scope methods are ported separately).

///|
/// A filter for selecting elements within the document.
pub(all) enum Selector {
  /// Matches a specific type of element, optionally with field values.
  Elem(Element, Array[(Int, Value)]?)
  /// Matches the element at the specified location.
  Location(Location)
  /// Matches elements with a specific label.
  Label(Label)
  /// Matches text elements through a regular expression.
  Regex(String)
  /// Matches elements with a specific capability.
  Can(String)
  /// Matches if any of the subselectors match.
  Or(Array[Selector])
  /// Matches if all of the subselectors match.
  And(Array[Selector])
  /// Matches all matches of `selector` before `end`.
  Before(selector~ : Selector, end~ : Selector, inclusive~ : Bool)
  /// Matches all matches of `selector` after `start`.
  After(selector~ : Selector, start~ : Selector, inclusive~ : Bool)
  /// Matches all matches of `selector` within `ancestor`.
  Within(selector~ : Selector, ancestor~ : Selector)
} derive(Eq)
