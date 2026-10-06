// Port of `typst-library/src/text/case.rs`.

///|
/// Converts a string or content to lowercase.
fn impl_lower(text_ : Caseable) -> Caseable {
  case_(text_, Lower)
}

///|
/// Converts a string or content to uppercase.
fn impl_upper(text_ : Caseable) -> Caseable {
  case_(text_, Upper)
}

///|
/// Change the case of text.
fn case_(text : Caseable, case : Case) -> Caseable {
  match text {
    Str(v) => Str(case.apply(v))
    Content(v) => {
      let value = IntoValue::into_value(Some(case))
      Content(
        v.styled(Property(Property::new(text_elem(), text_elem_case, value))),
      )
    }
  }
}

///|
/// A value whose case can be changed.
pub(all) enum Caseable {
  Str(String)
  Content(Content)
}

///|
pub impl Reflect for Caseable with fn input() {
  Union([Type(Type::str()), Type(Type::content())])
}

///|
pub impl Reflect for Caseable with fn output() {
  Caseable::input()
}

///|
pub impl Reflect for Caseable with fn castable(v) {
  str_castable(v) || castable_of((Ty::new() : Ty[Content]), v)
}

///|
pub extend Caseable with Reflect::{output, input, castable}

///|
pub impl IntoValue for Caseable with fn into_value(self) {
  match self {
    Str(v) => Str(v)
    Content(v) => Content(v)
  }
}

///|
pub impl FromValue for Caseable with fn from_value(v) {
  if str_castable(v) {
    Str(v.cast())
  } else if castable_of((Ty::new() : Ty[Content]), v) {
    Content(v.cast())
  } else {
    raise HintedError(Caseable::input().error(v))
  }
}

///|
/// A case transformation on text.
pub(all) enum Case {
  /// Everything is lowercased.
  Lower
  /// Everything is uppercased.
  Upper
} derive(Eq, Hash, Debug)

///|
/// Apply the case to a string.
pub fn Case::apply(self : Case, text : String) -> String {
  match self {
    Lower => @unicode.to_lowercase(text)
    Upper => @unicode.to_uppercase(text)
  }
}

///|
pub impl Reflect for Case with fn input() {
  Union([
    Value(Str("lower"), "Everything is lowercased."),
    Value(Str("upper"), "Everything is uppercased."),
  ])
}

///|
pub impl Reflect for Case with fn output() {
  Case::input()
}

///|
pub impl Reflect for Case with fn castable(v) {
  v is Str("lower" | "upper")
}

///|
pub extend Case with Reflect::{output, input, castable}

///|
pub impl IntoValue for Case with fn into_value(self) {
  match self {
    Lower => Str("lower")
    Upper => Str("upper")
  }
}

///|
pub impl FromValue for Case with fn from_value(v) {
  match v {
    Str("lower") => Lower
    Str("upper") => Upper
    v => raise HintedError(Case::input().error(v))
  }
}
