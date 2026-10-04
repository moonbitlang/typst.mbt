// Helpers mirroring Rust's `str`/`char` methods with Unicode semantics, as
// used by the ports of `biblatex`, `citationberg` and `hayagriva`.

///|
/// Rust's `char::is_whitespace` (Unicode `White_Space`).
pub fn is_whitespace(c : Char) -> Bool {
  @unicode.is_whitespace(c)
}

///|
/// Rust's `char::is_numeric`.
pub fn is_numeric(c : Char) -> Bool {
  @unicode.is_numeric(c)
}

///|
/// Rust's `char::is_alphanumeric`.
pub fn is_alphanumeric(c : Char) -> Bool {
  @unicode.is_alphanumeric(c)
}

///|
/// Rust's `char::is_alphabetic`.
pub fn is_alphabetic(c : Char) -> Bool {
  @unicode.is_alphabetic(c)
}

///|
/// Rust's `char::is_uppercase`.
pub fn is_uppercase(c : Char) -> Bool {
  @unicode.is_uppercase(c)
}

///|
/// Rust's `char::is_lowercase`.
pub fn is_lowercase(c : Char) -> Bool {
  @unicode.is_lowercase(c)
}

///|
/// Rust's `char::is_control`.
pub fn is_control(c : Char) -> Bool {
  @unicode.is_control(c)
}

///|
/// Rust's `str::trim`.
pub fn trim(s : StringView) -> String {
  trim_end(trim_start(s))
}

///|
/// Rust's `str::trim_start`.
pub fn trim_start(s : StringView) -> String {
  let mut i = 0
  let n = s.length()
  while i < n {
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    if !is_whitespace(Int::unsafe_to_char(c)) {
      break
    }
    i = next
  }
  s[i:].to_owned()
}

///|
/// Rust's `str::trim_end`.
pub fn trim_end(s : StringView) -> String {
  let mut j = s.length()
  while j > 0 {
    let { cp: c, idx: prev, } = @unicode.decode_before(s, j)
    if !is_whitespace(Int::unsafe_to_char(c)) {
      break
    }
    j = prev
  }
  s[:j].to_owned()
}

///|
/// Rust's `str::to_lowercase`.
pub fn to_lowercase(s : StringView) -> String {
  @unicode.to_lowercase(s)
}

///|
/// Rust's `str::to_uppercase`.
pub fn to_uppercase(s : StringView) -> String {
  @unicode.to_uppercase(s)
}

///|
/// Rust's `char::to_lowercase`, as a string.
pub fn char_to_lowercase(c : Char) -> String {
  @unicode.char_to_lowercase(c)
}

///|
/// Rust's `char::to_uppercase`, as a string.
pub fn char_to_uppercase(c : Char) -> String {
  @unicode.char_to_uppercase(c)
}

///|
/// Rust's `str::to_ascii_lowercase`.
pub fn to_ascii_lowercase(s : StringView) -> String {
  let buf = StringBuilder()
  for c in s {
    buf.write_char(c.to_ascii_lowercase())
  }
  buf.to_string()
}

///|
/// Rust's `str::to_ascii_uppercase`.
pub fn to_ascii_uppercase(s : StringView) -> String {
  let buf = StringBuilder()
  for c in s {
    buf.write_char(c.to_ascii_uppercase())
  }
  buf.to_string()
}

///|
/// The chars of a string.
pub fn chars(s : StringView) -> Array[Char] {
  let out = []
  for c in s {
    out.push(c)
  }
  out
}

///|
/// The number of chars of a string (Rust's `s.chars().count()`).
pub fn char_count(s : StringView) -> Int {
  let mut n = 0
  for _ in s {
    n += 1
  }
  n
}

///|
/// The first char of a string.
pub fn first_char(s : StringView) -> Char? {
  for c in s {
    return Some(c)
  }
  None
}

///|
/// The last char of a string.
pub fn last_char(s : StringView) -> Char? {
  if s.length() == 0 {
    return None
  }
  let { cp: c, .. } = @unicode.decode_before(s, s.length())
  Some(Int::unsafe_to_char(c))
}

///|
/// Parse a decimal integer like Rust's `str::parse::<i64>()` (optional `+`
/// or `-` sign followed by ASCII digits, no whitespace).
pub fn parse_i64(s : StringView) -> Int64? {
  let n = s.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  let c0 = s.get_char(0).unwrap()
  if c0 == '+' || c0 == '-' {
    neg = c0 == '-'
    i = 1
    if n == 1 {
      return None
    }
  }
  let mut v : Int64 = 0
  while i < n {
    let c = s.get_char(i).unwrap()
    if c < '0' || c > '9' {
      return None
    }
    let d = (c.to_int() - '0'.to_int()).to_int64()
    // Overflow checks for i64.
    if neg {
      if v < (-9223372036854775807L - 1L + d) / 10L {
        return None
      }
      v = v * 10L - d
    } else {
      if v > (9223372036854775807L - d) / 10L {
        return None
      }
      v = v * 10L + d
    }
    i += 1
  }
  Some(v)
}

///|
/// Parse an integer within `[min, max]` like Rust's `str::parse` for
/// fixed-size integer types.
pub fn parse_int_in(s : StringView, min : Int64, max : Int64) -> Int64? {
  match parse_i64(s) {
    Some(v) if v >= min && v <= max => Some(v)
    _ => None
  }
}

///|
/// Rust's `str::parse::<i32>()`.
pub fn parse_i32(s : StringView) -> Int? {
  parse_int_in(s, -2147483648L, 2147483647L).map(v => v.to_int())
}

///|
/// Rust's `str::parse::<u8>()`.
pub fn parse_u8(s : StringView) -> Int? {
  if s.has_prefix("-") {
    return None
  }
  parse_int_in(s, 0L, 255L).map(v => v.to_int())
}

///|
/// Rust's `str::parse::<u32>()`.
pub fn parse_u32(s : StringView) -> Int64? {
  if s.has_prefix("-") {
    return None
  }
  parse_int_in(s, 0L, 4294967295L)
}

///|
/// Rust's `str::split` on a string pattern, as owned strings.
pub fn split(s : StringView, sep : StringView) -> Array[String] {
  let out = []
  if sep.is_empty() {
    out.push("")
    for c in s {
      out.push(c.to_string())
    }
    out.push("")
    return out
  }
  let mut rest = s
  while true {
    match rest.find(sep) {
      Some(i) => {
        out.push(rest[:i].to_owned())
        rest = rest[i + sep.length():]
      }
      None => {
        out.push(rest.to_owned())
        break
      }
    }
  }
  out
}

///|
/// Rust's `str::split` on a char predicate, as owned strings.
pub fn split_by(s : StringView, f : (Char) -> Bool) -> Array[String] {
  let out = []
  let buf = StringBuilder()
  for c in s {
    if f(c) {
      out.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(c)
    }
  }
  out.push(buf.to_string())
  out
}

///|
/// Rust's `str::split_whitespace`.
pub fn split_whitespace(s : StringView) -> Array[String] {
  split_by(s, is_whitespace).filter(x => !x.is_empty())
}

///|
/// The byte offset of the first occurrence of `pat` (Rust's `str::find`).
pub fn find_byte(s : StringView, pat : StringView) -> Int? {
  match s.find(pat) {
    Some(i) => Some(len_utf8(s[:i]))
    None => None
  }
}

///|
/// Rust's `str::matches(c).count()`.
pub fn count_char(s : StringView, c : Char) -> Int {
  let mut n = 0
  for x in s {
    if x == c {
      n += 1
    }
  }
  n
}

///|
/// Rust's `char::compose` (canonical composition of a pair of chars), via
/// NFC.
pub fn compose(a : Char, b : Char) -> Char? {
  let s = a.to_string() + b.to_string()
  let composed = @unicode.nfc(s)
  let cs = chars(composed)
  if cs.length() == 1 {
    // NFC may also reorder/compose differently than the pairwise
    // composition; only accept a single resulting char.
    Some(cs[0])
  } else {
    None
  }
}

///|
/// Compare strings by code points like Rust's `str` ordering.
pub fn compare_str(a : StringView, b : StringView) -> Int {
  let ai = a.iter()
  let bi = b.iter()
  while true {
    match (ai.next(), bi.next()) {
      (None, None) => return 0
      (None, Some(_)) => return -1
      (Some(_), None) => return 1
      (Some(x), Some(y)) =>
        if x != y {
          return if x.to_int() < y.to_int() { -1 } else { 1 }
        }
    }
  }
  0
}
