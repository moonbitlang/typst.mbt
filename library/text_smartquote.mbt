// Port of the castable value types of `typst-library/src/text/smartquote.rs`
// (`SmartQuoteSet`, `SmartQuoteDict`). The quoting logic used during
// realization is not ported here.

///|
/// An opening and closing quote.
pub(all) struct SmartQuoteSet {
  open : String
  close : String
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for SmartQuoteSet with fn input() {
  CastInfo::Type(Type::array()).union_with(Type(Type::str()))
}

///|
pub impl Reflect for SmartQuoteSet with fn output() {
  SmartQuoteSet::input()
}

///|
pub impl Reflect for SmartQuoteSet with fn castable(v) {
  v is Array(_) || str_castable(v)
}

///|
pub impl IntoValue for SmartQuoteSet with fn into_value(self) {
  Array(Arr::from_array([Str(self.open), Str(self.close)]))
}

///|
pub impl FromValue for SmartQuoteSet with fn from_value(v) {
  match v {
    Array(value) => {
      let (open, close) = array_to_set(value)
      { open, close, }
    }
    v if str_castable(v) => {
      let (open, close) = str_to_set(FromValue::from_value(v))
      { open, close, }
    }
    v => raise HintedError(SmartQuoteSet::input().error(v))
  }
}

///|
fn str_to_set(value : String) -> (String, String) raise HintedError {
  let clusters = @unicode.graphemes(value)
  if clusters.length() == 2 {
    (clusters[0].to_owned(), clusters[1].to_owned())
  } else {
    let count = clusters.length()
    bail(
      "expected 2 characters, found \{count} character\{if count > 1 { "s" } else { "" }}",
    )
  }
}

///|
fn array_to_set(value : Arr) -> (String, String) raise HintedError {
  let value = value.items
  if value.length() != 2 {
    bail(
      "expected 2 quotes, found \{value.length()} quote\{if value.length() > 1 { "s" } else { "" }}",
    )
  }
  let open : String = FromValue::from_value(value[0])
  let close : String = FromValue::from_value(value[1])
  (open, close)
}

///|
/// A dict of single and double quotes.
pub(all) struct SmartQuoteDict {
  double : Smart[SmartQuoteSet]
  single : Smart[SmartQuoteSet]
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for SmartQuoteDict with fn input() {
  CastInfo::Type(Type::dict()).union_with(SmartQuoteSet::input())
}

///|
pub impl Reflect for SmartQuoteDict with fn output() {
  SmartQuoteDict::input()
}

///|
pub impl Reflect for SmartQuoteDict with fn castable(v) {
  v is Dict(_) || SmartQuoteSet::castable(v)
}

///|
pub impl IntoValue for SmartQuoteDict with fn into_value(self) {
  Dict(
    Dict::from_pairs([
      ("double", self.double.into_value()),
      ("single", self.single.into_value()),
    ]),
  )
}

///|
pub impl FromValue for SmartQuoteDict with fn from_value(v) {
  match v {
    Dict(value) => {
      let value = value.copy()
      let keys = ["double", "single"]
      let double : Smart[SmartQuoteSet] = dict_take_cast(value, "double").unwrap_or(
        Auto,
      )
      let single : Smart[SmartQuoteSet] = dict_take_cast(value, "single").unwrap_or(
        Auto,
      )
      value.finish(keys)
      { double, single, }
    }
    v if SmartQuoteSet::castable(v) =>
      { double: Custom(SmartQuoteSet::from_value(v)), single: Auto, }
    v => raise HintedError(SmartQuoteDict::input().error(v))
  }
}
