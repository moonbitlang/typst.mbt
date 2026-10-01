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
    Union(infos) =>
      for child in infos {
        child.walk(f)
      }
    other => f(other)
  }
}

///|
/// Produce an error message describing what was expected and what was found.
pub fn CastInfo::error(self : CastInfo, found : Value) -> HintedString {
  let mut matching_type = false
  let parts : Array[String] = []
  self.walk(info => {
    match info {
      Any => parts.push("anything")
      Value(value, _) => {
        parts.push(value.repr())
        if value.ty() == found.ty() {
          matching_type = true
        }
      }
      Type(ty) => parts.push(ty.to_string())
      Union(_) => ()
    }
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
  fn input() -> CastInfo
  /// Describe what this value can be cast into.
  fn output() -> CastInfo
  /// Whether the given value can be converted to `T`.
  fn castable(Value) -> Bool
}

///|
/// Cast a Rust value into a Typst [Value] (upstream `IntoValue`).
pub(open) trait IntoValue {
  fn into_value(Self) -> Value
}

///|
/// Try to cast a Typst [Value] into a value (upstream `FromValue`).
pub(open) trait FromValue: Reflect {
  fn from_value(Value) -> Self raise HintedError
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
pub fn[T : Reflect] cast_error(_ty : Ty[T], found : Value) -> HintedString {
  T::input().error(found)
}

///|
/// Try to cast the value into a specific type.
pub fn[T : FromValue] Value::cast(self : Value) -> T raise HintedError {
  T::from_value(self)
}

// Value itself.

///|
pub impl Reflect for Value with fn input() {
  Any
}

///|
pub impl Reflect for Value with fn output() {
  Any
}

///|
pub impl Reflect for Value with fn castable(_) {
  true
}

///|
pub impl IntoValue for Value with fn into_value(self) {
  self
}

///|
pub impl FromValue for Value with fn from_value(v) {
  v
}

// Primitive types.

///|
pub impl Reflect for Bool with fn input() {
  Type(Type::bool())
}

///|
pub impl Reflect for Bool with fn output() {
  Type(Type::bool())
}

///|
pub impl Reflect for Bool with fn castable(v) {
  v is Bool(_)
}

///|
pub impl IntoValue for Bool with fn into_value(self) {
  Bool(self)
}

///|
pub impl FromValue for Bool with fn from_value(v) {
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
pub impl Reflect for Int64 with fn input() {
  Type(Type::int())
}

///|
pub impl Reflect for Int64 with fn output() {
  Type(Type::int())
}

///|
pub impl Reflect for Int64 with fn castable(v) {
  v is Int(_)
}

///|
pub impl IntoValue for Int64 with fn into_value(self) {
  Int(self)
}

///|
pub impl FromValue for Int64 with fn from_value(v) {
  match v {
    Int(i) => i
    v => cast_fail_with(Type(Type::int()), v)
  }
}

///|
pub impl Reflect for Double with fn input() {
  Type(Type::float())
}

///|
pub impl Reflect for Double with fn output() {
  Type(Type::float())
}

///|
pub impl Reflect for Double with fn castable(v) {
  v is (Float(_) | Int(_))
}

///|
pub impl IntoValue for Double with fn into_value(self) {
  Float(self)
}

///|
pub impl FromValue for Double with fn from_value(v) {
  match v {
    Float(f) => f
    Int(i) => i.to_double()
    v => cast_fail_with(Type(Type::float()), v)
  }
}

///|
pub impl Reflect for String with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for String with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for String with fn castable(v) {
  v is (Str(_) | Symbol(_))
}

///|
pub impl IntoValue for String with fn into_value(self) {
  Str(self)
}

///|
pub impl FromValue for String with fn from_value(v) {
  match v {
    Str(s) => s
    Symbol(s) => s.get()
    v => cast_fail_with(Type(Type::str()), v)
  }
}

///|
pub impl Reflect for Length with fn input() {
  Type(Type::length())
}

///|
pub impl Reflect for Length with fn output() {
  Type(Type::length())
}

///|
pub impl Reflect for Length with fn castable(v) {
  v is Length(_)
}

///|
pub impl IntoValue for Length with fn into_value(self) {
  Length(self)
}

///|
pub impl FromValue for Length with fn from_value(v) {
  match v {
    Length(l) => l
    v => cast_fail_with(Type(Type::length()), v)
  }
}

///|
pub impl Reflect for Angle with fn input() {
  Type(Type::angle())
}

///|
pub impl Reflect for Angle with fn output() {
  Type(Type::angle())
}

///|
pub impl Reflect for Angle with fn castable(v) {
  v is Angle(_)
}

///|
pub impl IntoValue for Angle with fn into_value(self) {
  Angle(self)
}

///|
pub impl FromValue for Angle with fn from_value(v) {
  match v {
    Angle(a) => a
    v => cast_fail_with(Type(Type::angle()), v)
  }
}

///|
pub impl Reflect for Ratio with fn input() {
  Type(Type::ratio())
}

///|
pub impl Reflect for Ratio with fn output() {
  Type(Type::ratio())
}

///|
pub impl Reflect for Ratio with fn castable(v) {
  v is Ratio(_)
}

///|
pub impl IntoValue for Ratio with fn into_value(self) {
  Ratio(self)
}

///|
pub impl FromValue for Ratio with fn from_value(v) {
  match v {
    Ratio(r) => r
    v => cast_fail_with(Type(Type::ratio()), v)
  }
}

///|
pub impl Reflect for Fr with fn input() {
  Type(Type::fraction())
}

///|
pub impl Reflect for Fr with fn output() {
  Type(Type::fraction())
}

///|
pub impl Reflect for Fr with fn castable(v) {
  v is Fraction(_)
}

///|
pub impl IntoValue for Fr with fn into_value(self) {
  Fraction(self)
}

///|
pub impl FromValue for Fr with fn from_value(v) {
  match v {
    Fraction(f) => f
    v => cast_fail_with(Type(Type::fraction()), v)
  }
}

///|
/// `Rel<Length>` accepts lengths, ratios and relative lengths.
pub impl Reflect for Rel[Length] with fn input() {
  Type(Type::relative())
}

///|
pub impl Reflect for Rel[Length] with fn output() {
  Type(Type::relative())
}

///|
pub impl Reflect for Rel[Length] with fn castable(v) {
  v is (Relative(_) | Length(_) | Ratio(_))
}

///|
pub impl IntoValue for Rel[Length] with fn into_value(self) {
  Relative(self)
}

///|
pub impl FromValue for Rel[Length] with fn from_value(v) {
  match v {
    Relative(r) => r
    Length(l) => Rel::from_abs(l)
    Ratio(r) => Rel::from_ratio(r)
    v => cast_fail_with(Type(Type::relative()), v)
  }
}

///|
pub impl Reflect for Content with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for Content with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for Content with fn castable(v) {
  v is (Content(_) | None | Str(_) | Symbol(_))
}

///|
pub impl IntoValue for Content with fn into_value(self) {
  Content(self)
}

///|
pub impl FromValue for Content with fn from_value(v) {
  match v {
    Content(c) => c
    None => Content::empty()
    Str(s) => TextElem::packed(s)
    Symbol(s) => SymbolElem::packed(s.get())
    v => cast_fail_with(Type(Type::content()), v)
  }
}

///|
pub impl Reflect for Func with fn input() {
  Type(Type::func())
}

///|
pub impl Reflect for Func with fn output() {
  Type(Type::func())
}

///|
pub impl Reflect for Func with fn castable(v) {
  v is (Func(_) | Type(_) | Symbol(_))
}

///|
pub impl IntoValue for Func with fn into_value(self) {
  Func(self)
}

///|
pub impl FromValue for Func with fn from_value(v) {
  match v {
    Func(f) => f
    Type(ty) => ty.constructor()
    Symbol(symbol) => symbol.func()
    v => cast_fail_with(Type(Type::func()), v)
  }
}

///|
pub impl Reflect for Type with fn input() {
  Type(Type::type_())
}

///|
pub impl Reflect for Type with fn output() {
  Type(Type::type_())
}

///|
pub impl Reflect for Type with fn castable(v) {
  v is Type(_)
}

///|
pub impl IntoValue for Type with fn into_value(self) {
  Type(self)
}

///|
pub impl FromValue for Type with fn from_value(v) {
  match v {
    Type(t) => t
    v => cast_fail_with(Type(Type::type_()), v)
  }
}

///|
pub impl Reflect for Arr with fn input() {
  Type(Type::array())
}

///|
pub impl Reflect for Arr with fn output() {
  Type(Type::array())
}

///|
pub impl Reflect for Arr with fn castable(v) {
  v is Array(_)
}

///|
pub impl IntoValue for Arr with fn into_value(self) {
  Array(self)
}

///|
pub impl FromValue for Arr with fn from_value(v) {
  match v {
    Array(a) => a
    v => cast_fail_with(Type(Type::array()), v)
  }
}

///|
pub impl Reflect for Dict with fn input() {
  Type(Type::dict())
}

///|
pub impl Reflect for Dict with fn output() {
  Type(Type::dict())
}

///|
pub impl Reflect for Dict with fn castable(v) {
  v is Dict(_)
}

///|
pub impl IntoValue for Dict with fn into_value(self) {
  Dict(self)
}

///|
pub impl FromValue for Dict with fn from_value(v) {
  match v {
    Dict(d) => d
    v => cast_fail_with(Type(Type::dict()), v)
  }
}

///|
pub impl Reflect for Args with fn input() {
  Type(Type::args())
}

///|
pub impl Reflect for Args with fn output() {
  Type(Type::args())
}

///|
pub impl Reflect for Args with fn castable(v) {
  v is Args(_)
}

///|
pub impl IntoValue for Args with fn into_value(self) {
  Args(self)
}

///|
pub impl FromValue for Args with fn from_value(v) {
  match v {
    Args(a) => a
    v => cast_fail_with(Type(Type::args()), v)
  }
}

///|
pub impl Reflect for Label with fn input() {
  Type(Type::label())
}

///|
pub impl Reflect for Label with fn output() {
  Type(Type::label())
}

///|
pub impl Reflect for Label with fn castable(v) {
  v is Label(_)
}

///|
pub impl IntoValue for Label with fn into_value(self) {
  Label(self)
}

///|
pub impl FromValue for Label with fn from_value(v) {
  match v {
    Label(l) => l
    v => cast_fail_with(Type(Type::label()), v)
  }
}

// Generic containers.

///|
/// `Option<T>`: `none` or a `T`.
pub impl[T : Reflect] Reflect for T? with fn input() {
  T::input().union_with(Type(Type::none()))
}

///|
pub impl[T : Reflect] Reflect for T? with fn output() {
  T::output().union_with(Type(Type::none()))
}

///|
pub impl[T : Reflect] Reflect for T? with fn castable(v) {
  v is None || T::castable(v)
}

///|
pub impl[T : IntoValue] IntoValue for T? with fn into_value(self) {
  match self {
    Some(v) => v.into_value()
    None => None
  }
}

///|
pub impl[T : FromValue] FromValue for T? with fn from_value(v) {
  match v {
    None => None
    v if T::castable(v) => Some(T::from_value(v))
    v => cast_fail_with(T::input().union_with(Type(Type::none())), v)
  }
}

///|
/// `Vec<T>`: an array of `T`.
pub impl[T : Reflect] Reflect for Array[T] with fn input() {
  ignore(T::input)
  Type(Type::array())
}

///|
pub impl[T : Reflect] Reflect for Array[T] with fn output() {
  ignore(T::output)
  Type(Type::array())
}

///|
pub impl[T : Reflect] Reflect for Array[T] with fn castable(v) {
  ignore(T::castable)
  v is Array(_)
}

///|
pub impl[T : IntoValue] IntoValue for Array[T] with fn into_value(self) {
  Array(Arr::from_array(self.map(x => x.into_value())))
}

///|
pub impl[T : FromValue] FromValue for Array[T] with fn from_value(v) {
  match v {
    Array(a) => a.items.map(x => T::from_value(x))
    v => cast_fail_with(Type(Type::array()), v)
  }
}
