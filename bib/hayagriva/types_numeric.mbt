// Port of `hayagriva/src/types/numeric.rs`.

///|
/// A numeric value that can be pluralized.
pub(all) struct Numeric {
  /// The numeric value.
  value : NumericValue
  /// A string that is prepended to the value.
  prefix : String?
  /// A string that is appended to the value.
  suffix : String?
} derive(Eq, Hash, Debug)

///|
/// Creates a new `Numeric` from a number.
pub fn Numeric::new(value : Int) -> Numeric {
  { value: Number(value), prefix: None, suffix: None }
}

///|
/// Creates a new `Numeric` from a range.
pub fn Numeric::from_range(start : Int, end : Int) -> Numeric {
  { value: Set([(start, Some(Hyphen)), (end, None)]), prefix: None, suffix: None }
}

///|
/// Whether the numeric value contains only numbers.
pub fn Numeric::will_transform(self : Numeric) -> Bool {
  self.prefix is None && self.suffix is None
}

///|
/// Format the value without the prefix and suffix.
pub fn[W : FmtWrite] Numeric::fmt_value(
  self : Numeric,
  buf : W,
  machine_readable : Bool,
) -> Unit {
  match self.value {
    Number(n) => fmt_int(buf, n.to_int64())
    Set(s) =>
      for item in s {
        let (n, sep) = item
        fmt_int(buf, n.to_int64())
        if sep is Some(sep) {
          if machine_readable {
            buf.write_char(sep.as_char())
          } else {
            sep.fmt(buf)
          }
        }
      }
  }
}

///|
fn[W : FmtWrite] Numeric::fmt_custom(
  self : Numeric,
  buf : W,
  machine_readable : Bool,
) -> Unit {
  if self.prefix is Some(prefix) {
    buf.write_str(prefix)
  }
  self.fmt_value(buf, machine_readable)
  if self.suffix is Some(suffix) {
    buf.write_str(suffix)
  }
}

///|
/// `Display for Numeric` into a writer.
pub fn[W : FmtWrite] Numeric::fmt(self : Numeric, buf : W) -> Unit {
  self.fmt_custom(buf, false)
}

///|
pub impl Show for Numeric with output(self, logger) {
  logger.write_string(fmt_to_string(b => self.fmt(b)))
}

///|
/// Format the value with a given form.
pub fn[W : FmtWrite] Numeric::with_form(
  self : Numeric,
  buf : W,
  form : @citationberg.NumberForm,
  gender : @citationberg.GrammarGender?,
  ords : @citationberg.OrdinalLookup,
) -> Unit {
  let format = (n : Int) => match form {
    Ordinal => {
      fmt_int(buf, n.to_int64())
      buf.write_str(ords.lookup(n, gender).unwrap_or(""))
    }
    LongOrdinal =>
      match ords.lookup_long(n) {
        Some(s) => buf.write_str(s)
        None => {
          fmt_int(buf, n.to_int64())
          buf.write_str(ords.lookup(n, gender).unwrap_or(""))
        }
      }
    Roman =>
      if n >= 1 && n <= 3999 {
        buf.write_str(roman_lower(n))
      } else {
        fmt_int(buf, n.to_int64())
      }
    Numeric => fmt_int(buf, n.to_int64())
  }
  match self.value {
    Number(n) => format(n)
    Set(s) =>
      for item in s {
        let (n, sep) = item
        format(n)
        if sep is Some(sep) {
          sep.fmt(buf)
        }
      }
  }
}

///|
/// `format!("{:x}", RomanNumeral)`: the lowercase Roman numeral.
fn roman_lower(n : Int) -> String {
  let table : Array[(Int, String)] = [
    (1000, "m"),
    (900, "cm"),
    (500, "d"),
    (400, "cd"),
    (100, "c"),
    (90, "xc"),
    (50, "l"),
    (40, "xl"),
    (10, "x"),
    (9, "ix"),
    (5, "v"),
    (4, "iv"),
    (1, "i"),
  ]
  let out = StringBuilder()
  let mut n = n
  for pair in table {
    while n >= pair.0 {
      n -= pair.0
      out.write_string(pair.1)
    }
  }
  out.to_string()
}

///|
/// Whether the numeric value is plural.
pub fn Numeric::is_plural(self : Numeric, is_number_of : Bool) -> Bool {
  match self.value {
    Number(n) if is_number_of => n != 1
    Number(_) => false
    Set(vec) => vec.length() != 1
  }
}

///|
/// Whether the value is a single number with no prefix or suffix.
pub fn Numeric::single_number(self : Numeric) -> Int? {
  if self.prefix is None && self.suffix is None {
    match self.value {
      Number(n) => Some(n)
      _ => None
    }
  } else {
    None
  }
}

///|
/// Returns the nth number in the set.
pub fn Numeric::nth(self : Numeric, n : Int) -> Int? {
  self.value.nth(n)
}

///|
/// Order the values according to CSL rules (lexicographic over the
/// numbers).
pub fn Numeric::csl_cmp(self : Numeric, other : Numeric) -> Int {
  let a = self.value.numbers()
  let b = other.value.numbers()
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return if a[i] < b[i] { -1 } else { 1 }
    }
  }
  compare_int(a.length(), b.length())
}

///|
fn compare_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// `impl FromStr for Numeric`.
pub fn Numeric::from_str(value : String) -> Result[Numeric, NumericError] {
  let s = @unscanny.Scanner::new(value)
  s.eat_whitespace() |> ignore
  let prefix = {
    // Eat non-numeric characters and leading zeros.
    let start = s.cursor()
    s.eat_while(c => !@unscanny.is_numeric(c) && c != '-') |> ignore
    let zeros = s.eat_while_char('0')
    if !zeros.is_empty() &&
      (match s.peek() {
        None => true
        Some(c) => !@unscanny.is_numeric(c)
      }) {
      // Uneat the last zero if the value is just zero.
      s.uneat() |> ignore
    }
    s.from(start)
  }
  let value = match number(s) {
    Some(v) => v
    None => return Err(NoNumber)
  }
  let space_after_value = s.eat_whitespace()
  let value : NumericValue = match s.peek() {
    Some(c) if is_delimiter(c) => {
      s.eat() |> ignore
      s.eat_until(c => !is_delimiter(c)) |> ignore
      let first_delim = match NumericDelimiter::try_from_char(c) {
        Ok(d) => d
        Err(e) => return Err(e)
      }
      let items = [(value, Some(first_delim))]
      while true {
        s.eat_whitespace() |> ignore
        let num = match number(s) {
          Some(n) => n
          None => return Err(NoNumber)
        }
        s.eat_whitespace() |> ignore
        match NumericDelimiter::from_str(s.eat_while(is_delimiter)) {
          Ok(d) => items.push((num, Some(d)))
          Err(_) => {
            items.push((num, None))
            break
          }
        }
      }
      Set(items)
    }
    _ => Number(value)
  }
  s.eat_whitespace() |> ignore
  let post = s.eat_while(c => !@unscanny.is_numeric(c) && !@unscanny.is_whitespace(c))
  if !s.after().is_empty() {
    return Err(UnexpectedCharactersAfterPostfix)
  }
  Ok({
    value,
    prefix: if prefix.is_empty() { None } else { Some(prefix) },
    suffix: if post.is_empty() { None } else { Some(space_after_value + post) },
  })
}

///|
/// Error when parsing a numeric value.
pub(all) enum NumericError {
  /// No number was found.
  NoNumber
  /// Unexpected characters after the postfix. It must not contain any
  /// non-whitespace characters.
  UnexpectedCharactersAfterPostfix
  /// The string is not a delimiter.
  NotADelimiter
  /// The string does not contain a delimiter.
  MissingDelimiter
} derive(Eq, Debug)

///|
pub impl Show for NumericError with output(self, logger) {
  logger.write_string(
    match self {
      NoNumber => "no number found"
      UnexpectedCharactersAfterPostfix => "unexpected characters after postfix"
      NotADelimiter => "not a delimiter"
      MissingDelimiter => "missing delimiter"
    },
  )
}

///|
/// Eat a number from the scanner, assuming leading whitespaces and zeros
/// have already been eaten.
///
/// The number can be positive, negative, or zero.
fn number(s : @unscanny.Scanner) -> Int? {
  let negative = s.eat_if('-')
  let num = s.eat_while(@unscanny.is_numeric)
  if num.is_empty() {
    return None
  }
  match @unscanny.parse_i32(num) {
    Some(n) => Some(if negative { -n } else { n })
    None => None
  }
}

///|
/// The numeric value.
pub(all) enum NumericValue {
  /// A single number.
  Number(Int)
  /// A set of numbers.
  Set(Array[(Int, NumericDelimiter?)])
} derive(Eq, Hash, Debug)

///|
/// Return the length of the numeric value.
pub fn NumericValue::len(self : NumericValue) -> Int {
  match self {
    Number(_) => 1
    Set(vec) => vec.length()
  }
}

///|
/// Returns the nth number in the set.
fn NumericValue::nth(self : NumericValue, n : Int) -> Int? {
  match self {
    Number(val) if n == 0 => Some(val)
    Number(_) => None
    Set(vec) =>
      match vec.get(n) {
        Some(item) => Some(item.0)
        None => None
      }
  }
}

///|
/// The numbers of the value (upstream `NumIterator`).
fn NumericValue::numbers(self : NumericValue) -> Array[Int] {
  match self {
    Number(v) => [v]
    Set(vec) => vec.map(item => item.0)
  }
}

///|
/// Delimits individual numbers in a numeric value.
pub(all) enum NumericDelimiter {
  /// A comma.
  Comma
  /// An ampersand.
  Ampersand
  /// A hyphen. Will be converted to an en dash for display.
  Hyphen
} derive(Eq, Hash, Debug)

///|
/// Get the character representation of the delimiter.
pub fn NumericDelimiter::as_char(self : NumericDelimiter) -> Char {
  match self {
    Comma => ','
    Ampersand => '&'
    Hyphen => '-'
  }
}

///|
/// `Display for NumericDelimiter` into a writer.
pub fn[W : FmtWrite] NumericDelimiter::fmt(self : NumericDelimiter, f : W) -> Unit {
  match self {
    Comma => f.write_str(", ")
    Ampersand => f.write_str(" & ")
    Hyphen => f.write_char('–')
  }
}

///|
pub impl Show for NumericDelimiter with output(self, logger) {
  logger.write_string(fmt_to_string(b => self.fmt(b)))
}

///|
fn is_delimiter(c : Char) -> Bool {
  c == ',' || c == '&' || c == '-' || c == '–'
}

///|
/// `impl FromStr for NumericDelimiter`.
pub fn NumericDelimiter::from_str(s : String) -> Result[NumericDelimiter, NumericError] {
  guard @unscanny.first_char(s) is Some(first_char) else {
    return Err(MissingDelimiter)
  }
  if first_char != '-' &&
    @unscanny.len_utf8(s) > @unscanny.char_len_utf8(first_char) {
    return Err(NotADelimiter)
  }
  NumericDelimiter::try_from_char(first_char)
}

///|
/// `impl TryFrom<char> for NumericDelimiter`.
pub fn NumericDelimiter::try_from_char(c : Char) -> Result[NumericDelimiter, NumericError] {
  match c {
    ',' => Ok(Comma)
    '&' => Ok(Ampersand)
    '-' | '–' => Ok(Hyphen)
    _ => Err(NotADelimiter)
  }
}
