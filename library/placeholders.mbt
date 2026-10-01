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
  _guard : BindingGuard,
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
pub fn Version::component(self : Version, field : String) -> Int64 raise HintedError {
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
pub(all) struct Bytes(@builtin.Bytes) derive(Eq, Hash)

///|
pub fn Bytes::repr(self : Bytes) -> String {
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
