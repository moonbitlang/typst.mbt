// Placeholder definitions for value types whose full ports are pending.
// Each is replaced wholesale by its real port (in its own file).

///|
/// A color. (placeholder; see visualize/color.rs)
pub(all) struct Color {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Color::repr(self : Color) -> String {
  self.repr_
}

///|
/// A gradient. (placeholder; see visualize/gradient.rs)
pub(all) struct Gradient {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Gradient::repr(self : Gradient) -> String {
  self.repr_
}

///|
/// A tiling fill. (placeholder; see visualize/tiling.rs)
pub(all) struct Tiling {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Tiling::repr(self : Tiling) -> String {
  self.repr_
}

///|
/// A label. (placeholder; see foundations/label.rs)
pub(all) struct Label(String) derive(Eq, Hash, Compare)

///|
pub fn Label::repr(self : Label) -> String {
  "<" + self.0 + ">"
}

///|
/// Create a stroke from a paint and a thickness (upstream
/// `Stroke::from_pair`).
pub fn stroke_from_pair(_a : Value, _b : Value) -> Value raise HintedError {
  bail("strokes are not ported yet")
}

// Placeholders for dynamic types (see `dyn.mbt`). Each owner replaces its
// section with the real port, keeping the methods used by `dyn.mbt`.

///|
/// A regular expression. (placeholder; see foundations/str.rs)
pub(all) struct Regex {
  priv pattern : String
} derive(Eq, Hash)

///|
pub fn Regex::repr(self : Regex) -> String {
  "regex(" + repr_str(self.pattern) + ")"
}

///|
/// Whether the regex matches somewhere in the string.
pub fn Regex::is_match(self : Regex, _s : String) -> Bool {
  ignore(self)
  false
}

///|
/// A spot colorant. (placeholder; see visualize/color.rs)
pub(all) struct SpotColorant {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn SpotColorant::repr(self : SpotColorant) -> String {
  self.repr_
}

///|
/// A stroke. (placeholder; see visualize/stroke.rs)
pub(all) struct Stroke {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Stroke::repr(self : Stroke) -> String {
  self.repr_
}

///|
/// The fields of a stroke; `None` if missing.
pub fn Stroke::field(self : Stroke, _field : String) -> Value? {
  ignore(self)
  None
}
