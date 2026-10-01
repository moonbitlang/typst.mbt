// Port of `typst-library/src/text/case.rs`.

///|
/// Converts a string or content to lowercase.
fn impl_lower(text_ : Caseable) -> Caseable raise HintedError {
  case_(text_, Lower)
}

///|
/// Converts a string or content to uppercase.
fn impl_upper(text_ : Caseable) -> Caseable raise HintedError {
  case_(text_, Upper)
}

///|
/// Change the case of text.
fn case_(text : Caseable, case : Case) -> Caseable {
  match text {
    Str(v) => Str(case.apply(v))
    Content(v) =>
      Content(
        v.set(text_elem(), text_elem_case, IntoValue::into_value(Some(case))),
      )
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
  CastInfo::Type(Type::str()).union_with(Type(Type::content()))
}

///|
pub impl Reflect for Caseable with fn output() {
  Caseable::input()
}

///|
pub impl Reflect for Caseable with fn castable(v) {
  str_castable(v) || v is (Content(_) | None)
}

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
    return Str(FromValue::from_value(v))
  }
  match v {
    Content(_) | None => Content(FromValue::from_value(v))
    v => raise HintedError(Caseable::input().error(v))
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
let case_names : Array[String] = ["lower", "upper"]

///|
pub impl Reflect for Case with fn input() {
  str_names_input(case_names)
}

///|
pub impl Reflect for Case with fn output() {
  Case::input()
}

///|
pub impl Reflect for Case with fn castable(v) {
  str_names_find(case_names, v) is Some(_)
}

///|
pub impl IntoValue for Case with fn into_value(self) {
  match self {
    Lower => Str("lower")
    Upper => Str("upper")
  }
}

///|
pub impl FromValue for Case with fn from_value(v) {
  match str_names_find(case_names, v) {
    Some(0) => Lower
    Some(_) => Upper
    None => raise HintedError(Case::input().error(v))
  }
}

///|
/// Apply the case to a string.
///
/// TODO: upstream uses Rust's full Unicode case mapping
/// (`str::to_lowercase`/`to_uppercase`); MoonBit's `to_lower`/`to_upper`
/// only map ASCII. Needs case mapping tables in the `unicode` package.
pub fn Case::apply(self : Case, text : String) -> String {
  match self {
    Lower => text.to_lower()
    Upper => text.to_upper()
  }
}
