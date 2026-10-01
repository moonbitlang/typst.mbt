// Port of `typst-library/src/foundations/cast.rs`.

///|
/// Describes a possible value for a cast.
pub(all) enum CastInfo {
  /// Any value is okay.
  Any
  /// A specific value, plus short documentation for that value.
  Value(Value, String)
  /// Any value of a type.
  Type(Type)
  /// Multiple alternatives.
  Union(Array[CastInfo])
} derive(Eq)

///|
/// Walk all contained non-union infos.
pub fn CastInfo::walk(self : CastInfo, f : (CastInfo) -> Unit) -> Unit {
  match self {
    Union(infos) => for child in infos { child.walk(f) }
    other => f(other)
  }
}

///|
/// Produce an error message describing what was expected and what was found.
pub fn CastInfo::error(self : CastInfo, found : Value) -> HintedString {
  let mut matching_type = false
  let parts : Array[String] = []
  self.walk(info => match info {
    Any => parts.push("anything")
    Value(value, _) => {
      parts.push(value.repr())
      if value.ty() == found.ty() {
        matching_type = true
      }
    }
    Type(ty) => parts.push(ty.to_string())
    Union(_) => ()
  })
  let msg = StringBuilder()
  msg.write_string("expected ")
  if parts.is_empty() {
    msg.write_string(" nothing")
  }
  msg.write_string(separated_list(parts, "or"))
  if !matching_type {
    msg.write_string(", found ")
    msg.write_string(found.ty().to_string())
  }
  let msg = HintedString::new(msg.to_string())
  match found {
    Int(i) =>
      if !matching_type && parts.contains("length") {
        msg.hint("a length needs a unit - did you mean \{i}pt?")
      }
    Str(s) =>
      if !matching_type && parts.contains("label") {
        if @syntax.is_valid_label_literal_id(s) {
          msg.hint("use `<\{s}>` or `label(\{repr_str(s)})` to create a label")
        } else {
          msg.hint("use `label(\{repr_str(s)})` to create a label")
        }
      }
    Decimal(_) =>
      if !matching_type && parts.contains("float") {
        msg.hint(
          "if loss of precision is acceptable, explicitly cast the decimal to a float with `float(value)`",
        )
      }
    _ => ()
  }
  msg
}

///|
/// Combine two cast infos (upstream `Add for CastInfo`).
pub fn CastInfo::union_with(self : CastInfo, rhs : CastInfo) -> CastInfo {
  match (self, rhs) {
    (Union(lhs), Union(rhs)) => {
      let out = lhs.copy()
      for cast in rhs {
        if !out.contains(cast) {
          out.push(cast)
        }
      }
      Union(out)
    }
    (Union(lhs), rhs) => {
      let out = lhs.copy()
      if !out.contains(rhs) {
        out.push(rhs)
      }
      Union(out)
    }
    (lhs, Union(rhs)) => {
      let out = rhs.copy()
      if !out.contains(lhs) {
        out.insert(0, lhs)
      }
      Union(out)
    }
    (lhs, rhs) => Union([lhs, rhs])
  }
}

///|
/// Determine details of a type (upstream `Reflect`).
pub(open) trait Reflect {
  /// Describe what can be cast into this value.
  input() -> CastInfo
  /// Describe what this value can be cast into.
  output() -> CastInfo
  /// Whether the given value can be converted to `T`.
  castable(Value) -> Bool
}

///|
/// Cast a Rust value into a Typst [Value] (upstream `IntoValue`).
pub(open) trait IntoValue {
  into_value(Self) -> Value
}

///|
/// Try to cast a Typst [Value] into a value (upstream `FromValue`).
pub(open) trait FromValue: Reflect {
  from_value(Value) -> Self raise HintedError
}

///|
/// A phantom handle to call static trait methods for a concrete type:
/// `input_of((Ty::new() : Ty[Smart[Length]]))`.
pub struct Ty[T](Unit)

///|
pub fn[T] Ty::new() -> Ty[T] {
  Ty(())
}

///|
/// The input cast info of `T`.
pub fn[T : Reflect] input_of(_ : Ty[T]) -> CastInfo {
  T::input()
}

///|
/// The output cast info of `T`.
pub fn[T : Reflect] output_of(_ : Ty[T]) -> CastInfo {
  T::output()
}

///|
/// The error for a value that could not be cast into `T`.
pub fn[T : Reflect] cast_error(found : Value) -> HintedString {
  T::input().error(found)
}

///|
/// Raise the cast error of `T`.
pub fn[T : Reflect, R] cast_fail(found : Value) -> R raise HintedError {
  raise HintedError(T::input().error(found))
}

///|
/// Try to cast the value into a specific type.
pub fn[T : FromValue] Value::cast(self : Value) -> T raise HintedError {
  T::from_value(self)
}

// Value itself.

///|
pub impl Reflect for Value with input() {
  Any
}

///|
pub impl Reflect for Value with output() {
  Any
}

///|
pub impl Reflect for Value with castable(_) {
  true
}

///|
pub impl IntoValue for Value with into_value(self) {
  self
}

///|
pub impl FromValue for Value with from_value(v) {
  v
}

// Primitive types.

///|
pub impl Reflect for Bool with input() {
  Type(Type::bool())
}

///|
pub impl Reflect for Bool with output() {
  Type(Type::bool())
}

///|
pub impl Reflect for Bool with castable(v) {
  v is Bool(_)
}

///|
pub impl IntoValue for Bool with into_value(self) {
  Bool(self)
}

///|
pub impl FromValue for Bool with from_value(v) {
  match v {
    Bool(b) => b
    v => cast_fail_with(Type(Type::bool()), v)
  }
}

///|
fn[R] cast_fail_with(info : CastInfo, found : Value) -> R raise HintedError {
  raise HintedError(info.error(found))
}

///|
pub impl Reflect for Int64 with input() {
  Type(Type::int())
}

///|
pub impl Reflect for Int64 with output() {
  Type(Type::int())
}

///|
pub impl Reflect for Int64 with castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for Int64 with into_value(self) {
  Int(self)
}

///|
pub impl FromValue for Int64 with from_value(v) {
  match v {
    Int(i) => i
    v => cast_fail_with(Type(Type::int()), v)
  }
}

///|
pub impl Reflect for Double with input() {
  Type(Type::float())
}

///|
pub impl Reflect for Double with output() {
  Type(Type::float())
}

///|
pub impl Reflect for Double with castable(v) {
  v is (Float(_) | Int(_))
}

///|
pub impl IntoValue for Double with into_value(self) {
  Float(self)
}

///|
pub impl FromValue for Double with from_value(v) {
  match v {
    Float(f) => f
    Int(i) => i.to_double()
    v => cast_fail_with(Type(Type::float()), v)
  }
}

///|
pub impl Reflect for String with input() {
  Type(Type::str())
}

///|
pub impl Reflect for String with output() {
  Type(Type::str())
}

///|
pub impl Reflect for String with castable(v) {
  v is (Str(_) | Symbol(_))
}

///|
pub impl IntoValue for String with into_value(self) {
  Str(self)
}

///|
pub impl FromValue for String with from_value(v) {
  match v {
    Str(s) => s
    Symbol(s) => s.get()
    v => cast_fail_with(Type(Type::str()), v)
  }
}

///|
pub impl Reflect for Length with input() {
  Type(Type::length())
}

///|
pub impl Reflect for Length with output() {
  Type(Type::length())
}

///|
pub impl Reflect for Length with castable(v) {
  v is Length(_)
}

///|
pub impl IntoValue for Length with into_value(self) {
  Length(self)
}

///|
pub impl FromValue for Length with from_value(v) {
  match v {
    Length(l) => l
    v => cast_fail_with(Type(Type::length()), v)
  }
}

///|
pub impl Reflect for Angle with input() {
  Type(Type::angle())
}

///|
pub impl Reflect for Angle with output() {
  Type(Type::angle())
}

///|
pub impl Reflect for Angle with castable(v) {
  v is Angle(_)
}

///|
pub impl IntoValue for Angle with into_value(self) {
  Angle(self)
}

///|
pub impl FromValue for Angle with from_value(v) {
  match v {
    Angle(a) => a
    v => cast_fail_with(Type(Type::angle()), v)
  }
}

///|
pub impl Reflect for Ratio with input() {
  Type(Type::ratio())
}

///|
pub impl Reflect for Ratio with output() {
  Type(Type::ratio())
}

///|
pub impl Reflect for Ratio with castable(v) {
  v is Ratio(_)
}

///|
pub impl IntoValue for Ratio with into_value(self) {
  Ratio(self)
}

///|
pub impl FromValue for Ratio with from_value(v) {
  match v {
    Ratio(r) => r
    v => cast_fail_with(Type(Type::ratio()), v)
  }
}

///|
pub impl Reflect for Fr with input() {
  Type(Type::fraction())
}

///|
pub impl Reflect for Fr with output() {
  Type(Type::fraction())
}

///|
pub impl Reflect for Fr with castable(v) {
  v is Fraction(_)
}

///|
pub impl IntoValue for Fr with into_value(self) {
  Fraction(self)
}

///|
pub impl FromValue for Fr with from_value(v) {
  match v {
    Fraction(f) => f
    v => cast_fail_with(Type(Type::fraction()), v)
  }
}

///|
/// `Rel<Length>` accepts lengths, ratios and relative lengths.
pub impl Reflect for Rel[Length] with input() {
  Type(Type::relative())
}

///|
pub impl Reflect for Rel[Length] with output() {
  Type(Type::relative())
}

///|
pub impl Reflect for Rel[Length] with castable(v) {
  v is (Relative(_) | Length(_) | Ratio(_))
}

///|
pub impl IntoValue for Rel[Length] with into_value(self) {
  Relative(self)
}

///|
pub impl FromValue for Rel[Length] with from_value(v) {
  match v {
    Relative(r) => r
    Length(l) => Rel::from_abs(l)
    Ratio(r) => Rel::from_ratio(r)
    v => cast_fail_with(Type(Type::relative()), v)
  }
}

///|
pub impl Reflect for Content with input() {
  Type(Type::content())
}

///|
pub impl Reflect for Content with output() {
  Type(Type::content())
}

///|
pub impl Reflect for Content with castable(v) {
  v is (Content(_) | None | Str(_) | Symbol(_))
}

///|
pub impl IntoValue for Content with into_value(self) {
  Content(self)
}

///|
pub impl FromValue for Content with from_value(v) {
  match v {
    Content(c) => c
    None => Content::empty()
    Str(s) => TextElem::packed(s)
    Symbol(s) => SymbolElem::packed(s.get())
    v => cast_fail_with(Type(Type::content()), v)
  }
}

///|
pub impl Reflect for Func with input() {
  Type(Type::func())
}

///|
pub impl Reflect for Func with output() {
  Type(Type::func())
}

///|
pub impl Reflect for Func with castable(v) {
  v is (Func(_) | Type(_) | Symbol(_))
}

///|
pub impl IntoValue for Func with into_value(self) {
  Func(self)
}

///|
pub impl FromValue for Func with from_value(v) {
  match v {
    Func(f) => f
    Type(ty) => ty.constructor()
    Symbol(symbol) => symbol.func()
    v => cast_fail_with(Type(Type::func()), v)
  }
}

///|
pub impl Reflect for Type with input() {
  Type(Type::type_())
}

///|
pub impl Reflect for Type with output() {
  Type(Type::type_())
}

///|
pub impl Reflect for Type with castable(v) {
  v is Type(_)
}

///|
pub impl IntoValue for Type with into_value(self) {
  Type(self)
}

///|
pub impl FromValue for Type with from_value(v) {
  match v {
    Type(t) => t
    v => cast_fail_with(Type(Type::type_()), v)
  }
}

///|
pub impl Reflect for Arr with input() {
  Type(Type::array())
}

///|
pub impl Reflect for Arr with output() {
  Type(Type::array())
}

///|
pub impl Reflect for Arr with castable(v) {
  v is Array(_)
}

///|
pub impl IntoValue for Arr with into_value(self) {
  Array(self)
}

///|
pub impl FromValue for Arr with from_value(v) {
  match v {
    Array(a) => a
    v => cast_fail_with(Type(Type::array()), v)
  }
}

///|
pub impl Reflect for Dict with input() {
  Type(Type::dict())
}

///|
pub impl Reflect for Dict with output() {
  Type(Type::dict())
}

///|
pub impl Reflect for Dict with castable(v) {
  v is Dict(_)
}

///|
pub impl IntoValue for Dict with into_value(self) {
  Dict(self)
}

///|
pub impl FromValue for Dict with from_value(v) {
  match v {
    Dict(d) => d
    v => cast_fail_with(Type(Type::dict()), v)
  }
}

///|
pub impl Reflect for Label with input() {
  Type(Type::label())
}

///|
pub impl Reflect for Label with output() {
  Type(Type::label())
}

///|
pub impl Reflect for Label with castable(v) {
  v is Label(_)
}

///|
pub impl IntoValue for Label with into_value(self) {
  Label(self)
}

///|
pub impl FromValue for Label with from_value(v) {
  match v {
    Label(l) => l
    v => cast_fail_with(Type(Type::label()), v)
  }
}

// Generic containers.

///|
/// `Option<T>`: `none` or a `T`.
pub impl[T : Reflect] Reflect for T? with input() {
  T::input().union_with(Type(Type::none()))
}

///|
pub impl[T : Reflect] Reflect for T? with output() {
  T::output().union_with(Type(Type::none()))
}

///|
pub impl[T : Reflect] Reflect for T? with castable(v) {
  v is None || T::castable(v)
}

///|
pub impl[T : IntoValue] IntoValue for T? with into_value(self) {
  match self {
    Some(v) => v.into_value()
    None => None
  }
}

///|
pub impl[T : FromValue] FromValue for T? with from_value(v) {
  match v {
    None => None
    v if T::castable(v) => Some(T::from_value(v))
    v => cast_fail_with(T::input().union_with(Type(Type::none())), v)
  }
}

///|
/// `Vec<T>`: an array of `T`.
pub impl[T : Reflect] Reflect for Array with input() {
  Type(Type::array())
}

///|
pub impl[T : Reflect] Reflect for Array with output() {
  Type(Type::array())
}

///|
pub impl[T : Reflect] Reflect for Array with castable(v) {
  v is Array(_)
}

///|
pub impl[T : IntoValue] IntoValue for Array with into_value(self) {
  Array(Arr::from_array(self.map(x => x.into_value())))
}

///|
pub impl[T : FromValue] FromValue for Array with from_value(v) {
  match v {
    Array(a) => a.items.map(x => T::from_value(x))
    v => cast_fail_with(Type(Type::array()), v)
  }
}
