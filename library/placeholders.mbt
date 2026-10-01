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
/// A symbol. (placeholder; see foundations/symbol.rs)
pub(all) struct Symbol {
  priv text : String
} derive(Eq, Hash)

///|
pub fn Symbol::repr(self : Symbol) -> String {
  "symbol(" + repr_str(self.text) + ")"
}

///|
pub fn Symbol::get(self : Symbol) -> String {
  self.text
}

///|
pub fn Symbol::modified(
  self : Symbol,
  _guard_ : BindingGuard,
  field : String,
) -> Symbol raise HintedError {
  bail("unknown symbol modifier: \{field}") |> ignore
  self
}

///|
/// A label. (placeholder; see foundations/label.rs)
pub(all) struct Label(String) derive(Eq, Hash, Compare)

///|
pub fn Label::repr(self : Label) -> String {
  "<" + self.0 + ">"
}

///|
/// A datetime. (placeholder; see foundations/datetime.rs)
pub(all) struct Datetime {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Datetime::repr(self : Datetime) -> String {
  self.repr_
}

///|
/// A duration. (placeholder; see foundations/duration.rs)
pub(all) struct Duration {
  priv seconds : Int64
} derive(Eq, Hash)

///|
pub fn Duration::repr(self : Duration) -> String {
  "duration(seconds: \{self.seconds})"
}

///|
pub fn Symbol::func(self : Symbol) -> Func raise HintedError {
  bail("symbol \{self.repr()} is not callable")
}

///|
pub fn Duration::neg(self : Duration) -> Duration {
  { seconds: -self.seconds, }
}

///|
pub fn Duration::is_zero(self : Duration) -> Bool {
  self.seconds == 0L
}

///|
pub fn Duration::add(self : Duration, other : Duration) -> Duration {
  { seconds: self.seconds + other.seconds, }
}

///|
pub fn Duration::sub(self : Duration, other : Duration) -> Duration {
  { seconds: self.seconds - other.seconds, }
}

///|
pub fn Duration::mul(self : Duration, f : Double) -> Duration {
  { seconds: (self.seconds.to_double() * f).to_int64(), }
}

///|
pub fn Duration::div(self : Duration, f : Double) -> Duration {
  { seconds: (self.seconds.to_double() / f).to_int64(), }
}

///|
pub fn Duration::div_duration(self : Duration, other : Duration) -> Double {
  self.seconds.to_double() / other.seconds.to_double()
}

///|
pub impl Compare for Duration with fn compare(self, other) {
  self.seconds.compare(other.seconds)
}

///|
pub fn Datetime::add_duration(
  self : Datetime,
  _d : Duration,
) -> Datetime raise HintedError {
  bail("datetime arithmetic is not ported yet") |> ignore
  self
}

///|
pub fn Datetime::sub_duration(
  self : Datetime,
  _d : Duration,
) -> Datetime raise HintedError {
  bail("datetime arithmetic is not ported yet") |> ignore
  self
}

///|
pub fn Datetime::sub_datetime(
  self : Datetime,
  _d : Datetime,
) -> Duration raise HintedError {
  bail("datetime arithmetic is not ported yet")
}

///|
pub fn Datetime::partial_cmp(self : Datetime, _other : Datetime) -> Int? {
  ignore(self)
  None
}

///|
pub fn Datetime::kind(self : Datetime) -> String {
  ignore(self)
  "datetime"
}

///|
/// Create a stroke from a paint and a thickness (upstream
/// `Stroke::from_pair`).
pub fn stroke_from_pair(_a : Value, _b : Value) -> Value raise HintedError {
  bail("strokes are not ported yet")
}

///|
/// A symbol for a single character at runtime (upstream
/// `Symbol::runtime_char`).
pub fn Symbol::runtime_char(c : Char) -> Symbol {
  { text: c.to_string(), }
}

// Placeholders for dynamic types (see `dyn.mbt`). Each owner replaces its
// section with the real port, keeping the methods used by `dyn.mbt`.

///|
/// An alignment. (placeholder; see layout/align.rs)
pub(all) struct Alignment {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Alignment::repr(self : Alignment) -> String {
  self.repr_
}

///|
/// Sum two alignments (upstream `Add for Alignment`).
pub fn Alignment::add(
  self : Alignment,
  _other : Alignment,
) -> Alignment raise HintedError {
  bail("alignments are not ported yet") |> ignore
  self
}

///|
/// The fields of an alignment (`x`, `y`); `None` if missing.
pub fn Alignment::field(self : Alignment, _field : String) -> Value? {
  ignore(self)
  None
}

///|
/// A direction. (placeholder; see layout/dir.rs)
pub(all) struct Dir {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Dir::repr(self : Dir) -> String {
  self.repr_
}

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

///|
/// A counter. (placeholder; see introspection/counter.rs)
pub(all) struct Counter {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn Counter::repr(self : Counter) -> String {
  self.repr_
}

///|
/// A state. (placeholder; see introspection/state.rs)
pub(all) struct State {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn State::repr(self : State) -> String {
  self.repr_
}

///|
/// A path rooted in a project or package. (placeholder; see
/// foundations/path.rs)
pub(all) struct RootedPath {
  priv repr_ : String
} derive(Eq, Hash)

///|
pub fn RootedPath::repr(self : RootedPath) -> String {
  self.repr_
}

///|
/// The repr of a location. (placeholder; see introspection/location.rs)
pub fn Location::repr(self : Location) -> String {
  ignore(self)
  "location(..)"
}

///|
/// The repr of a selector. (placeholder; see foundations/selector.rs)
pub fn Selector::repr(self : Selector) -> String {
  ignore(self)
  "selector(..)"
}
