// Port of `typst-library/src/text/smartquote.rs`: the quoting logic
// (`SmartQuoter`, `SmartQuotes`) and the castable value types
// (`SmartQuoteSet`, `SmartQuoteDict`).

///|
/// A smart quote substitutor with zero lookahead.
pub struct SmartQuoter {
  /// The amount of quotes that have been opened.
  priv mut depth : Int
  /// Each bit indicates whether the quote at this nesting depth is a double.
  /// Maximum supported depth is thus 32.
  priv mut kinds : UInt
}

///|
/// Start quoting.
pub fn SmartQuoter::new() -> SmartQuoter {
  { depth: 0, kinds: 0, }
}

///|
/// Reset to the initial state (upstream `*quoter = SmartQuoter::new()`).
pub fn SmartQuoter::reset(self : SmartQuoter) -> Unit {
  self.depth = 0
  self.kinds = 0
}

///|
/// Determine which smart quote to substitute given this quoter's nesting
/// state and the character immediately preceding the quote.
pub fn SmartQuoter::quote(
  self : SmartQuoter,
  before : Char?,
  quotes : SmartQuotes,
  double : Bool,
) -> String {
  let opened = self.top()
  let before = before.unwrap_or(' ')

  // If we are after a number and haven't most recently opened a quote of
  // this kind, produce a prime. Otherwise, we prefer a closing quote.
  if @unicode.is_numeric(before) && opened != Some(double) {
    return if double { "″" } else { "′" }
  }

  // If we have a single smart quote, didn't recently open a single
  // quotation, and are after an alphabetic char or an object (e.g. a
  // math equation), interpret this as an apostrophe.
  if !double &&
    opened != Some(false) &&
    (@unicode.is_alphabetic(before) || before == '\u{FFFC}') {
    return "’"
  }

  // If the most recently opened quotation is of this kind and the
  // previous char does not indicate a nested quotation, close it.
  if opened == Some(double) &&
    !@unicode.is_whitespace(before) &&
    !@syntax.is_newline(before) &&
    !is_opening_bracket(before) {
    self.pop()
    return quotes.close(double)
  }

  // Otherwise, open a new the quotation.
  self.push(double)
  quotes.open(double)
}

///|
/// The top of our quotation stack. Returns `Some(double)` for the most
/// recently opened quote or `None` if we didn't open one.
fn SmartQuoter::top(self : SmartQuoter) -> Bool? {
  if self.depth == 0 {
    None
  } else {
    Some(((self.kinds >> (self.depth - 1)) & 1) == 1)
  }
}

///|
/// Push onto the quotation stack.
fn SmartQuoter::push(self : SmartQuoter, double : Bool) -> Unit {
  if self.depth < 32 {
    self.kinds = self.kinds | ((if double { 1U } else { 0U }) << self.depth)
    self.depth += 1
  }
}

///|
/// Pop from the quotation stack.
fn SmartQuoter::pop(self : SmartQuoter) -> Unit {
  self.depth -= 1
  self.kinds = self.kinds & ((1U << self.depth) - 1)
}

///|
/// Whether the character is an opening bracket, parenthesis, or brace.
fn is_opening_bracket(c : Char) -> Bool {
  c is ('(' | '{' | '[')
}

///|
/// Decides which quotes to substitute smart quotes with.
pub(all) struct SmartQuotes {
  /// The opening single quote.
  single_open : String
  /// The closing single quote.
  single_close : String
  /// The opening double quote.
  double_open : String
  /// The closing double quote.
  double_close : String
}

///|
/// Retrieve the smart quotes as configured by the current styles.
pub fn SmartQuotes::get_in(styles : StyleChain) -> SmartQuotes {
  SmartQuotes::get(
    SmartQuoteElem::quotes_in(styles),
    TextElem::lang_in(styles),
    TextElem::region_in(styles),
    SmartQuoteElem::alternative_in(styles),
  )
}

///|
/// Create a new `Quotes` struct with the given quotes, optionally falling
/// back to the defaults for a language and region.
///
/// For unknown languages, the English quotes are used as fallback.
pub fn SmartQuotes::get(
  quotes : Smart[SmartQuoteDict],
  lang : Lang,
  region : Region?,
  alternative : Bool,
) -> SmartQuotes {
  let region = region.map(r => r.as_str())
  let default = ("‘", "’", "“", "”")
  let low_high = ("‚", "‘", "„", "“")
  let (single_open, single_close, double_open, double_close) = match
    lang.as_str() {
    "de" if region is Some("CH" | "LI") =>
      if alternative {
        low_high
      } else {
        ("‹", "›", "«", "»")
      }
    "fr" if region is Some("CH") =>
      if alternative {
        default
      } else {
        ("‹\u{202F}", "\u{202F}›", "«\u{202F}", "\u{202F}»")
      }
    "cs" | "da" | "de" | "sk" | "sl" if alternative =>
      ("›", "‹", "»", "«")
    "cs" | "de" | "et" | "is" | "lt" | "lv" | "sk" | "sl" => low_high
    "da" => ("‘", "’", "“", "”")
    "fr" if alternative => default
    "fr" => ("“", "”", "«\u{202F}", "\u{202F}»")
    "fi" | "sv" if alternative => ("’", "’", "»", "»")
    "gl" => ("“", "”", "«", "»")
    "bs" | "fi" | "sv" => ("’", "’", "”", "”")
    "it" if alternative => default
    "la" if alternative => ("“", "”", "«\u{202F}", "\u{202F}»")
    "it" | "la" => ("“", "”", "«", "»")
    "es" if region is (Some("ES") | None) => ("“", "”", "«", "»")
    "hu" | "pl" | "ro" => ("’", "’", "„", "”")
    "no" | "nb" | "nn" if alternative => low_high
    "no" | "nb" | "nn" => ("’", "’", "«", "»")
    "ru" => ("„", "“", "«", "»")
    "uk" => ("“", "”", "«", "»")
    "el" => ("‘", "’", "«", "»")
    "he" => ("’", "’", "”", "”")
    "hr" => ("‘", "’", "„", "”")
    "bg" => ("’", "’", "„", "“")
    "ar" if !alternative => ("’", "‘", "«", "»")
    _ if lang.dir() == RTL => ("’", "‘", "”", "“")
    _ => default
  }
  fn inner_or_default(
    set : Smart[SmartQuoteSet],
    default : (String, String),
  ) -> (String, String) {
    match set {
      Auto => default
      Custom(set) => (set.open, set.close)
    }
  }

  let (single_open, single_close) = match quotes {
    Auto => (single_open, single_close)
    Custom(q) => inner_or_default(q.single, (single_open, single_close))
  }
  let (double_open, double_close) = match quotes {
    Auto => (double_open, double_close)
    Custom(q) => inner_or_default(q.double, (double_open, double_close))
  }
  { single_open, single_close, double_open, double_close, }
}

///|
/// The opening quote.
pub fn SmartQuotes::open(self : SmartQuotes, double : Bool) -> String {
  if double {
    self.double_open
  } else {
    self.single_open
  }
}

///|
/// The closing quote.
pub fn SmartQuotes::close(self : SmartQuotes, double : Bool) -> String {
  if double {
    self.double_close
  } else {
    self.single_close
  }
}

///|
/// Get the fallback "dumb" quotes for when smart quotes are disabled.
pub fn SmartQuotes::fallback(double : Bool) -> String {
  if double {
    "\""
  } else {
    "'"
  }
}

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
