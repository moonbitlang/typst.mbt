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
  Regex(Regex)
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

///|
/// Define a simple text selector.
pub fn Selector::text(text : String) -> Selector raise HintedError {
  if text.is_empty() {
    bail("text selector is empty")
  }
  Regex(Regex::new(regex_escape(text)))
}

///|
/// Define a regex selector.
pub fn Selector::regex(regex : Regex) -> Selector raise HintedError {
  if regex.as_str().is_empty() {
    bail("regex selector is empty")
  }
  if regex.is_match("") {
    bail("regex matches empty text")
  }
  Regex(regex)
}
