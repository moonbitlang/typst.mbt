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
/// A version. (placeholder; see foundations/version.rs)
pub(all) struct Version(Array[Int]) derive(Eq, Hash)

///|
pub fn Version::repr(self : Version) -> String {
  "version(" + self.0.map(c => c.to_string()).join(", ") + ")"
}

///|
pub fn Version::to_string(self : Version) -> String {
  self.0.map(c => c.to_string()).join(".")
}

///|
pub fn Version::component(
  self : Version,
  field : String,
) -> Int64 raise HintedError {
  let idx = match field {
    "major" => 0
    "minor" => 1
    "patch" => 2
    _ => bail("unknown version component")
  }
  self.0.get(idx).unwrap_or(0).to_int64()
}

///|
/// Raw bytes. (placeholder; see foundations/bytes.rs)
pub(all) struct BytesValue(Bytes) derive(Eq, Hash)

///|
pub fn BytesValue::repr(self : BytesValue) -> String {
  "bytes(\{self.0.length()})"
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
/// A decimal number. (placeholder; see foundations/decimal.rs)
pub(all) struct Decimal {
  priv text : String
} derive(Eq, Hash)

///|
pub fn Decimal::repr(self : Decimal) -> String {
  "decimal(" + repr_str(self.text) + ")"
}

///|
pub fn Decimal::to_string(self : Decimal) -> String {
  self.text
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
/// Internal native values stored in `Value::Dyn` (upstream `Dynamic`).
pub(all) enum DynValue {
  /// Placeholder until the first internal types are ported.
  Placeholder
} derive(Eq, Hash)

///|
pub fn DynValue::ty(self : DynValue) -> Type {
  match self {
    Placeholder => Type::none()
  }
}

///|
pub fn DynValue::repr(self : DynValue) -> String {
  match self {
    Placeholder => ".."
  }
}

///|
pub fn Symbol::func(self : Symbol) -> Func raise HintedError {
  bail("symbol \{self.repr()} is not callable")
}

///|
pub impl Compare for Version with fn compare(self, other) {
  let n = if self.0.length() > other.0.length() {
    self.0.length()
  } else {
    other.0.length()
  }
  for i in 0..<n {
    let a = self.0.get(i).unwrap_or(0)
    let b = other.0.get(i).unwrap_or(0)
    if a != b {
      return a.compare(b)
    }
  }
  0
}

///|
pub fn BytesValue::concat(self : BytesValue, other : BytesValue) -> BytesValue {
  let buf = @buffer.new()
  buf.write_bytes(self.0)
  buf.write_bytes(other.0)
  BytesValue(buf.to_bytes())
}

///|
pub fn Decimal::from_int(i : Int64) -> Decimal {
  { text: i.to_string(), }
}

///|
pub fn Decimal::neg(self : Decimal) -> Decimal {
  self
}

///|
pub fn Decimal::is_zero(self : Decimal) -> Bool {
  self.text == "0"
}

///|
pub fn Decimal::checked_add(
  self : Decimal,
  _other : Decimal,
) -> Decimal raise HintedError {
  bail("decimal arithmetic is not ported yet") |> ignore
  self
}

///|
pub fn Decimal::checked_sub(
  self : Decimal,
  _other : Decimal,
) -> Decimal raise HintedError {
  bail("decimal arithmetic is not ported yet") |> ignore
  self
}

///|
pub fn Decimal::checked_mul(
  self : Decimal,
  _other : Decimal,
) -> Decimal raise HintedError {
  bail("decimal arithmetic is not ported yet") |> ignore
  self
}

///|
pub fn Decimal::checked_div(
  self : Decimal,
  _other : Decimal,
) -> Decimal raise HintedError {
  bail("decimal arithmetic is not ported yet") |> ignore
  self
}

///|
pub impl Compare for Decimal with fn compare(self, other) {
  self.text.compare(other.text)
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
pub fn DynValue::is_alignment(self : DynValue) -> Bool {
  ignore(self)
  false
}

///|
pub fn DynValue::add_dyn(
  self : DynValue,
  _other : DynValue,
) -> Value? raise HintedError {
  ignore(self)
  None
}

///|
pub fn DynValue::regex_is_match(self : DynValue, _s : String) -> Bool? {
  ignore(self)
  None
}

///|
/// Access a field on a dynamic value: `None` if the type has no fields,
/// `Some(None)` if the field is missing.
pub fn DynValue::field(self : DynValue, _field : String) -> Value?? {
  ignore(self)
  None
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
