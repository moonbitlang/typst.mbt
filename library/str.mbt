// Port of `typst-library/src/foundations/str.rs`.
//
// Typst strings are stored as MoonBit `String`s (UTF-16), but all indices
// are UTF-8 byte offsets like upstream.

// UTF-8 helpers.

///|
/// The UTF-8 length of a string (upstream `Str::len`).
fn str_len(s : String) -> Int {
  @syntax.utf8_len(s)
}

///|
/// The UTF-16 index of a UTF-8 byte offset, if it is a char boundary within
/// the string (upstream `str::is_char_boundary`).
fn str_byte_to_utf16(s : String, byte : Int) -> Int? {
  let mut bytes = 0
  let mut i = 0
  while bytes < byte {
    if i >= s.length() {
      return None
    }
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    bytes += if c < 0x80 {
      1
    } else if c < 0x800 {
      2
    } else if c < 0x10000 {
      3
    } else {
      4
    }
    i = next
  }
  if bytes == byte {
    Some(i)
  } else {
    None
  }
}

///|
/// The UTF-8 byte offset of a UTF-16 index.
fn str_utf16_to_byte(s : String, i : Int) -> Int {
  @syntax.utf8_len(s.view(end_offset=i))
}

///|
/// Resolve an index or throw an out of bounds error. Returns the byte offset
/// and the UTF-16 index.
fn str_locate(s : String, index : Int64) -> (Int, Int) raise HintedError {
  match str_locate_opt(s, index) {
    Some(r) => r
    None => bail(str_out_of_bounds(index, str_len(s)))
  }
}

///|
/// Resolve an index, if it is within bounds and on a valid char boundary.
///
/// `index == len` is considered in bounds.
fn str_locate_opt(s : String, index : Int64) -> (Int, Int)? raise HintedError {
  let len = str_len(s).to_int64()
  let wrapped = if index >= 0L { index } else { len + index }
  if wrapped < 0L || wrapped > len {
    return None
  }
  match str_byte_to_utf16(s, wrapped.to_int()) {
    Some(u) => Some((wrapped.to_int(), u))
    None => bail(str_not_a_char_boundary(index))
  }
}

///|
/// Converts a value to a string.
fn impl_str_construct(
  value_ : ToStr,
  base_ : @syntax.Spanned[Base],
) -> String raise SourceError {
  match value_ {
    ToStr::Str(s) => {
      if base_.v is User(_) {
        bail_at(base_.span, "base is only supported for integers")
      }
      s
    }
    Int(n) => {
      let b = base_.v.value()
      if b == 1L && n > 0L {
        bail_at(base_.span, "base must be between 2 and 36", hints=[
          "generate a unary representation with `\"1\" * \{n}`",
        ])
      }
      if b < 2L || b > 36L {
        bail_at(base_.span, "base must be between 2 and 36")
      }
      format_int_with_base(n, b)
    }
  }
}

///|
/// Default of `str(base:)`: `Spanned::detached(Base::Default)`.
fn impl_str_construct__base_default() -> @syntax.Spanned[Base] {
  { v: Default, span: @syntax.Span::detached(), }
}

///|
/// The length of the string in UTF-8 encoded bytes.
fn impl_str_len(self_ : String) -> USize {
  USize(str_len(self_).to_int64())
}

///|
/// Extracts the first grapheme cluster of the string.
fn impl_str_first(
  self_ : String,
  default_ : String?,
) -> String raise HintedError {
  let graphemes = @unicode.graphemes(self_)
  match graphemes.get(0) {
    Some(g) => g.to_owned()
    None =>
      match default_ {
        Some(d) => d
        None => bail(str_string_is_empty())
      }
  }
}

///|
/// Extracts the last grapheme cluster of the string.
fn impl_str_last(
  self_ : String,
  default_ : String?,
) -> String raise HintedError {
  let graphemes = @unicode.graphemes(self_)
  match graphemes.last() {
    Some(g) => g.to_owned()
    None =>
      match default_ {
        Some(d) => d
        None => bail(str_string_is_empty())
      }
  }
}

///|
/// Extracts the first grapheme cluster after the specified index.
fn impl_str_at(
  self_ : String,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  let len = str_len(self_)
  let found = match str_locate_opt(self_, index_) {
    Some((_, u)) if u < self_.length() => {
      let end = @unicode.grapheme_end(self_, u)
      Some(Value::Str(self_.unsafe_substring(start=u, end~)))
    }
    _ => None
  }
  match
    (match found {
      Some(v) => Some(v)
      None => default_
    }) {
    Some(v) => v
    None => bail(str_no_default_and_out_of_bounds(index_, len))
  }
}

///|
/// Default of `slice(end:)`: none.
fn impl_str_slice__end_default() -> Int64? {
  None
}

///|
/// Extracts a substring of the string.
fn impl_str_slice(
  self_ : String,
  start_ : Int64,
  end_ : Int64?,
  count_ : Int64?,
) -> String raise HintedError {
  if end_ is Some(_) && count_ is Some(_) {
    bail("`end` and `count` are mutually exclusive")
  }
  let (start_byte, start) = str_locate(self_, start_)
  let end = match end_ {
    Some(e) => e
    None =>
      match count_ {
        Some(c) => start_byte.to_int64() + c
        None => str_len(self_).to_int64()
      }
  }
  let (_, end) = str_locate(self_, end)
  let end = if end > start { end } else { start }
  self_.unsafe_substring(start~, end~)
}

///|
/// Returns the grapheme clusters of the string as an array of substrings.
fn impl_str_clusters(self_ : String) -> Arr {
  Arr::from_array(@unicode.graphemes(self_).map(g => Value::Str(g.to_owned())))
}

///|
/// Returns the Unicode codepoints of the string as an array of substrings.
fn impl_str_codepoints(self_ : String) -> Arr {
  let out = []
  for c in self_ {
    out.push(Value::Str(c.to_string()))
  }
  Arr::from_array(out)
}

///|
/// Converts a character into its corresponding code point.
fn impl_str_to_unicode(character_ : Char) -> U32 {
  U32(character_.to_int().to_int64())
}

///|
/// Converts a unicode code point into its corresponding string.
fn impl_str_from_unicode(value_ : U32) -> String raise HintedError {
  let v = value_.get()
  if v > 0x10FFFFL || (v >= 0xD800L && v <= 0xDFFFL) {
    bail("0x\{rust_hex(v)} is not a valid codepoint")
  }
  v.to_int().unsafe_to_char().to_string()
}

///|
/// Lowercase hexadecimal formatting of a non-negative number.
fn rust_hex(v : Int64) -> String {
  if v == 0L {
    return "0"
  }
  let digits = "0123456789abcdef"
  let buf = []
  let mut n = v
  while n > 0L {
    buf.push(digits[(n % 16L).to_int()])
    n = n / 16L
  }
  let out = StringBuilder()
  for i = buf.length() - 1; i >= 0; i = i - 1 {
    out.write_char(buf[i].unsafe_to_char())
  }
  out.to_string()
}

///|
/// Default of `normalize(form:)`: `UnicodeNormalForm::Nfc`.
fn impl_str_normalize__form_default() -> UnicodeNormalForm {
  Nfc
}

///|
/// Normalizes the string to the given Unicode normal form.
fn impl_str_normalize(self_ : String, form_ : UnicodeNormalForm) -> String {
  match form_ {
    Nfc => @unicode.nfc(self_)
    Nfd => @unicode.nfd(self_)
    Nfkc => @unicode.nfkc(self_)
    Nfkd => @unicode.nfkd(self_)
  }
}

///|
/// Whether the string contains the specified pattern.
fn impl_str_contains(self_ : String, pattern_ : StrPattern) -> Bool {
  match pattern_ {
    Str(pat) => self_.contains(pat)
    Regex(re) => re.is_match(self_)
  }
}

///|
/// Whether the string starts with the specified pattern.
fn impl_str_starts_with(self_ : String, pattern_ : StrPattern) -> Bool {
  match pattern_ {
    Str(pat) => self_.has_prefix(pat)
    Regex(re) =>
      match re.inner.find(self_) {
        Some(m) => m.start == 0
        None => false
      }
  }
}

///|
/// Whether the string ends with the specified pattern.
fn impl_str_ends_with(self_ : String, pattern_ : StrPattern) -> Bool {
  match pattern_ {
    Str(pat) => self_.has_suffix(pat)
    Regex(re) => {
      let len = str_len(self_)
      let mut start_byte = 0
      while re.inner.find_at(self_, start_byte) is Some(mat) {
        if mat.end == len {
          return true
        }
        // There might still be a match overlapping this one, so restart at
        // the next code point.
        guard str_byte_to_utf16(self_, mat.start) is Some(u) else { break }
        if u >= self_.length() {
          break
        }
        let { cp: c, .. } = @unicode.decode_at(self_, u)
        start_byte = mat.start + utf8_char_len(c)
      }
      false
    }
  }
}

///|
/// The UTF-8 length of a code point.
fn utf8_char_len(c : Int) -> Int {
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// Searches for the specified pattern in the string and returns the first
/// match as a string or `none` if there is no match.
fn impl_str_find(self_ : String, pattern_ : StrPattern) -> String? {
  match pattern_ {
    Str(pat) => if self_.contains(pat) { Some(pat) } else { None }
    Regex(re) => re.inner.find(self_).map(m => m.text)
  }
}

///|
/// Searches for the specified pattern in the string and returns the index of
/// the first match as an integer or `none` if there is no match.
fn impl_str_position(self_ : String, pattern_ : StrPattern) -> USize? {
  match pattern_ {
    Str(pat) =>
      self_.find(pat).map(i => USize(str_utf16_to_byte(self_, i).to_int64()))
    Regex(re) => re.inner.find(self_).map(m => USize(m.start.to_int64()))
  }
}

///|
/// Rust's `str::match_indices` for a string pattern: the byte offsets and
/// UTF-16 ranges of all non-overlapping matches. An empty pattern matches at
/// every char boundary.
fn str_match_indices(s : String, pat : String) -> Array[(Int, Int, Int)] {
  let out = []
  if pat.is_empty() {
    let mut i = 0
    let mut b = 0
    while true {
      out.push((b, i, i))
      if i >= s.length() {
        break
      }
      let { cp: c, idx: next, } = @unicode.decode_at(s, i)
      b += utf8_char_len(c)
      i = next
    }
    return out
  }
  let mut i = 0
  while i + pat.length() <= s.length() {
    match s.view(start_offset=i).find(pat) {
      Some(j) => {
        let start = i + j
        out.push((str_utf16_to_byte(s, start), start, start + pat.length()))
        i = start + pat.length()
      }
      None => break
    }
  }
  out
}

///|
/// Searches for the specified pattern in the string and returns a
/// dictionary with details about the first match or `none` if there is no
/// match.
fn impl_str_match(self_ : String, pattern_ : StrPattern) -> Dict? {
  match pattern_ {
    Str(pat) =>
      str_match_indices(self_, pat).get(0).map(m => match_to_dict(m.0, pat))
    Regex(re) => re.inner.captures(self_).map(captures_to_dict)
  }
}

///|
/// Searches for the specified pattern in the string and returns an array of
/// dictionaries with details about all matches.
fn impl_str_matches(self_ : String, pattern_ : StrPattern) -> Arr {
  match pattern_ {
    Str(pat) =>
      Arr::from_array(
        str_match_indices(self_, pat).map(m => {
          Value::Dict(match_to_dict(m.0, pat))
        }),
      )
    Regex(re) =>
      Arr::from_array(
        re.inner.captures_iter(self_).map(c => Value::Dict(captures_to_dict(c))),
      )
  }
}

///|
/// Replace at most `count` occurrences of the given pattern with a
/// replacement string or function (beginning from the start).
fn impl_str_replace(
  self_ : String,
  engine : Engine,
  context : Context,
  pattern_ : StrPattern,
  replacement_ : Replacement,
  count_ : USize?,
) -> String raise SourceError {
  let output = StringBuilder()
  // The UTF-16 end of the last match.
  let mut last_match = 0
  let handle_match = (start : Int, end : Int, dict : Dict) => {
    // Push everything until the match.
    output.write_string(self_.unsafe_substring(start=last_match, end=start))
    last_match = end
    // Determine and push the replacement.
    match replacement_ {
      Str(s) => output.write_string(s)
      Func(func) => {
        let piece = func.call_values(engine, context, [Dict(dict)])
        let piece : String = at(func.span(), () => piece.cast())
        output.write_string(piece)
      }
    }
  }
  // Iterate over the matches of the `pattern`.
  let count = match count_ {
    Some(c) => c.get()
    None => @int64.MAX_VALUE
  }
  match pattern_ {
    Str(pat) => {
      let mut n = 0L
      for m in str_match_indices(self_, pat) {
        if n >= count {
          break
        }
        n += 1L
        handle_match(m.1, m.2, match_to_dict(m.0, pat))
      }
    }
    Regex(re) => {
      let mut n = 0L
      for caps in re.inner.captures_iter(self_) {
        if n >= count {
          break
        }
        n += 1L
        // Extract the entire match over all capture groups.
        let m = caps.get(0).unwrap()
        let start = str_byte_to_utf16(self_, m.start).unwrap()
        let end = str_byte_to_utf16(self_, m.end).unwrap()
        handle_match(start, end, captures_to_dict(caps))
      }
    }
  }
  // Push the remainder.
  output.write_string(
    self_.unsafe_substring(start=last_match, end=self_.length()),
  )
  output.to_string()
}

///|
/// Default of `trim(pattern)`: none.
fn impl_str_trim__pattern_default() -> StrPattern? {
  None
}

///|
/// Removes matches of a pattern from one or both sides of the string, once or
/// repeatedly and returns the resulting string.
fn impl_str_trim(
  self_ : String,
  pattern_ : StrPattern?,
  at_ : StrSide?,
  repeat_ : Bool,
) -> String {
  let mut start = at_ is (Some(Start) | None)
  let end = at_ is (Some(End) | None)
  match pattern_ {
    None =>
      match at_ {
        None => rust_trim(self_)
        Some(Start) => rust_trim_start(self_)
        Some(End) => rust_trim_end(self_)
      }
    Some(Str(pat)) => {
      let mut s = self_
      if repeat_ {
        if start && !pat.is_empty() {
          while s.has_prefix(pat) {
            s = s.unsafe_substring(start=pat.length(), end=s.length())
          }
        }
        if end && !pat.is_empty() {
          while s.has_suffix(pat) {
            s = s.unsafe_substring(start=0, end=s.length() - pat.length())
          }
        }
      } else {
        if start && s.has_prefix(pat) {
          s = s.unsafe_substring(start=pat.length(), end=s.length())
        }
        if end && s.has_suffix(pat) {
          s = s.unsafe_substring(start=0, end=s.length() - pat.length())
        }
      }
      s
    }
    Some(Regex(re)) => {
      let s = self_
      let mut last : Int? = None
      let mut range_start = 0
      let mut range_end = str_len(s)
      for m in re.inner.find_iter(s) {
        // Does this match follow directly after the last one?
        let consecutive = last == Some(m.start)
        // As long as we're at the beginning or in a consecutive run of
        // matches, and we're still trimming at the start, trim.
        start = start && (m.start == 0 || consecutive)
        if start {
          range_start = m.end
          start = start && repeat_
        }
        // Reset end trim if we aren't consecutive anymore or aren't
        // repeating.
        if end && (!consecutive || !repeat_) {
          range_end = m.start
        }
        last = Some(m.end)
      }
      // Is the last match directly at the end?
      if last is Some(last) && last < str_len(s) {
        range_end = str_len(s)
      }
      let range_end = if range_end > range_start {
        range_end
      } else {
        range_start
      }
      @syntax.utf8_slice(s, range_start, range_end)
    }
  }
}

///|
/// Default of `split(pattern)`: none.
fn impl_str_split__pattern_default() -> StrPattern? {
  None
}

///|
/// Splits a string at matches of a specified pattern and returns an array of
/// the resulting parts.
fn impl_str_split(self_ : String, pattern_ : StrPattern?) -> Arr {
  let s = self_
  match pattern_ {
    None => Arr::from_array(rust_split_whitespace(s).map(v => Value::Str(v)))
    Some(Str(pat)) => {
      let out = []
      let mut last = 0
      for m in str_match_indices(s, pat) {
        out.push(Value::Str(s.unsafe_substring(start=last, end=m.1)))
        last = m.2
      }
      out.push(Value::Str(s.unsafe_substring(start=last, end=s.length())))
      Arr::from_array(out)
    }
    Some(Regex(re)) =>
      Arr::from_array(re.inner.split(s).map(v => Value::Str(v)))
  }
}

///|
/// Rust's `str::split_whitespace`.
fn rust_split_whitespace(s : String) -> Array[String] {
  let out = []
  let mut start = -1
  let mut i = 0
  while i < s.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    if @unicode.is_whitespace(c.unsafe_to_char()) {
      if start >= 0 {
        out.push(s.unsafe_substring(start~, end=i))
        start = -1
      }
    } else if start < 0 {
      start = i
    }
    i = next
  }
  if start >= 0 {
    out.push(s.unsafe_substring(start~, end=s.length()))
  }
  out
}

///|
/// Reverse the string.
fn impl_str_rev(self_ : String) -> String {
  let s = StringBuilder()
  let graphemes = @unicode.graphemes(self_)
  for i = graphemes.length() - 1; i >= 0; i = i - 1 {
    s.write_view(graphemes[i])
  }
  s.to_string()
}

// Casts.

///|
/// Whether `v` can be cast to a string (upstream `Str::castable`).
fn str_castable(v : Value) -> Bool {
  castable_of((Ty::new() : Ty[String]), v)
}

///|
/// `char` from a string with exactly one character.
pub impl Reflect for Char with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for Char with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for Char with fn castable(v) {
  str_castable(v)
}

///|
pub impl IntoValue for Char with fn into_value(self) {
  Str(self.to_string())
}

///|
pub impl FromValue for Char with fn from_value(v) {
  if str_castable(v) {
    let string : String = v.cast()
    let chars = string.iter()
    match (chars.next(), chars.next()) {
      (Some(c), None) => c
      _ => bail("expected exactly one character")
    }
  } else {
    raise HintedError(input_of((Ty::new() : Ty[Char])).error(v))
  }
}

///|
/// A value that can be cast to a string.
pub(all) enum ToStr {
  /// A string value ready to be used as-is.
  Str(String)
  /// An integer about to be formatted in a given base.
  Int(Int64)
}

///|
pub impl Reflect for ToStr with fn input() {
  Union([
    Type(Type::int()),
    Type(Type::float()),
    Type(Type::decimal()),
    Type(Type::version()),
    Type(Type::bytes()),
    Type(Type::label()),
    Type(Type::type_()),
    Type(Type::str()),
  ])
}

///|
pub impl Reflect for ToStr with fn output() {
  ToStr::input()
}

///|
pub impl Reflect for ToStr with fn castable(v) {
  v
  is (Int(_)
  | Float(_)
  | Decimal(_)
  | Version(_)
  | Bytes(_)
  | Label(_)
  | Type(_)
  | Str(_)
  | Symbol(_))
}

///|
pub extend ToStr with Reflect::{output, input, castable}

///|
pub impl FromValue for ToStr with fn from_value(v) {
  match v {
    Int(n) => Int(n)
    Float(f) => Str(display_float(f))
    Decimal(d) => Str(d.to_string())
    Version(v) => Str(v.to_string())
    Bytes(b) =>
      match b.to_str() {
        Some(s) => Str(s)
        None => bail("bytes are not valid UTF-8")
      }
    Label(l) => Str(l.resolve())
    Type(t) => Str(t.long_name())
    Str(s) => Str(s)
    Symbol(s) => Str(s.get())
    v => raise HintedError(ToStr::input().error(v))
  }
}

///|
/// A Unicode normalization form.
pub(all) enum UnicodeNormalForm {
  /// Canonical composition where e.g. accented letters are turned into a
  /// single Unicode codepoint.
  Nfc
  /// Canonical decomposition where e.g. accented letters are split into a
  /// separate base and diacritic.
  Nfd
  /// Like NFC, but using the Unicode compatibility decompositions.
  Nfkc
  /// Like NFD, but using the Unicode compatibility decompositions.
  Nfkd
} derive(Eq, Hash)

///|
pub impl Reflect for UnicodeNormalForm with fn input() {
  Union([
    Value(
      Str("nfc"),
      "Canonical composition where e.g. accented letters are turned into a single Unicode codepoint.",
    ),
    Value(
      Str("nfd"),
      "Canonical decomposition where e.g. accented letters are split into a separate base and diacritic.",
    ),
    Value(
      Str("nfkc"),
      "Like NFC, but using the Unicode compatibility decompositions.",
    ),
    Value(
      Str("nfkd"),
      "Like NFD, but using the Unicode compatibility decompositions.",
    ),
  ])
}

///|
pub impl Reflect for UnicodeNormalForm with fn output() {
  UnicodeNormalForm::input()
}

///|
pub impl Reflect for UnicodeNormalForm with fn castable(v) {
  v is Str("nfc" | "nfd" | "nfkc" | "nfkd")
}

///|
pub extend UnicodeNormalForm with Reflect::{output, input, castable}

///|
pub impl IntoValue for UnicodeNormalForm with fn into_value(self) {
  match self {
    Nfc => Str("nfc")
    Nfd => Str("nfd")
    Nfkc => Str("nfkc")
    Nfkd => Str("nfkd")
  }
}

///|
pub impl FromValue for UnicodeNormalForm with fn from_value(v) {
  match v {
    Str("nfc") => Nfc
    Str("nfd") => Nfd
    Str("nfkc") => Nfkc
    Str("nfkd") => Nfkd
    v => raise HintedError(UnicodeNormalForm::input().error(v))
  }
}

///|
/// Converts a match of a string pattern into a dictionary.
fn match_to_dict(start : Int, text : String) -> Dict {
  Dict::from_pairs([
    ("start", Int(start.to_int64())),
    ("end", Int((start + str_len(text)).to_int64())),
    ("text", Str(text)),
    ("captures", Array(Arr::new())),
  ])
}

///|
/// Converts regex captures into a dictionary.
fn captures_to_dict(cap : @regex.Captures) -> Dict {
  let m = cap.get(0).unwrap()
  let captures = []
  for i in 1..<cap.len() {
    captures.push(
      match cap.get(i) {
        Some(m) => Value::Str(m.text)
        None => Value::None
      },
    )
  }
  Dict::from_pairs([
    ("start", Int(m.start.to_int64())),
    ("end", Int(m.end.to_int64())),
    ("text", Str(m.text)),
    ("captures", Array(Arr::from_array(captures))),
  ])
}

///|
fn str_out_of_bounds(index : Int64, len : Int) -> String {
  "string index out of bounds (index: \{index}, len: \{len})"
}

///|
fn str_no_default_and_out_of_bounds(index : Int64, len : Int) -> String {
  "no default value was specified and string index out of bounds (index: \{index}, len: \{len})"
}

///|
fn str_not_a_char_boundary(index : Int64) -> String {
  "string index \{index} is not a character boundary"
}

///|
fn str_string_is_empty() -> String {
  "string is empty"
}

///|
/// A regular expression.
///
/// Can be used as a show rule selector and with string methods like `find`,
/// `split`, and `replace`.
pub struct Regex {
  inner : @regex.Regex
} derive(Eq, Hash)

///|
/// Create a new regular expression.
pub fn Regex::new(re : String) -> Regex raise HintedError {
  { inner: @regex.Regex::new(re) catch { RegexError(msg) => bail(msg) }, }
}

///|
/// Create a regular expression from a string.
fn impl_regex_construct(
  regex_ : @syntax.Spanned[String],
) -> Regex raise SourceError {
  at(regex_.span, () => Regex::new(regex_.v))
}

///|
/// The pattern of the regular expression.
pub fn Regex::as_str(self : Regex) -> String {
  self.inner.as_str()
}

///|
pub fn Regex::repr(self : Regex) -> String {
  "regex(" + repr_str(self.inner.as_str()) + ")"
}

///|
/// Whether the regex matches somewhere in the string.
pub fn Regex::is_match(self : Regex, s : String) -> Bool {
  self.inner.is_match(s)
}

///|
pub impl Reflect for Regex with fn input() {
  Type(Type::regex())
}

///|
pub impl Reflect for Regex with fn output() {
  Type(Type::regex())
}

///|
pub impl Reflect for Regex with fn castable(v) {
  v is Dyn(Regex(_))
}

///|
pub extend Regex with Reflect::{output, input, castable}

///|
pub impl IntoValue for Regex with fn into_value(self) {
  Dyn(Regex(self))
}

///|
pub extend Regex with IntoValue::{into_value}

///|
pub impl FromValue for Regex with fn from_value(v) {
  match v {
    Dyn(Regex(re)) => re
    v => raise HintedError(Regex::input().error(v))
  }
}

///|
/// A pattern which can be searched for in a string.
pub(all) enum StrPattern {
  /// Just a string.
  Str(String)
  /// A regular expression.
  Regex(Regex)
}

///|
pub impl Reflect for StrPattern with fn input() {
  Union([Type(Type::str()), Type(Type::regex())])
}

///|
pub impl Reflect for StrPattern with fn output() {
  StrPattern::input()
}

///|
pub impl Reflect for StrPattern with fn castable(v) {
  str_castable(v) || Regex::castable(v)
}

///|
pub extend StrPattern with Reflect::{output, input, castable}

///|
pub impl IntoValue for StrPattern with fn into_value(self) {
  match self {
    Str(v) => Str(v)
    Regex(v) => v.into_value()
  }
}

///|
pub impl FromValue for StrPattern with fn from_value(v) {
  if str_castable(v) {
    Str(v.cast())
  } else if Regex::castable(v) {
    Regex(v.cast())
  } else {
    raise HintedError(StrPattern::input().error(v))
  }
}

///|
/// A side of a string.
pub(all) enum StrSide {
  /// The logical start of the string, may be left or right depending on the
  /// language.
  Start
  /// The logical end of the string.
  End
} derive(Eq)

///|
pub impl Reflect for StrSide with fn input() {
  input_of((Ty::new() : Ty[Alignment]))
}

///|
pub impl Reflect for StrSide with fn output() {
  output_of((Ty::new() : Ty[Alignment]))
}

///|
pub impl Reflect for StrSide with fn castable(v) {
  castable_of((Ty::new() : Ty[Alignment]), v)
}

///|
pub extend StrSide with Reflect::{output, input, castable}

///|
pub impl FromValue for StrSide with fn from_value(v) {
  if !castable_of((Ty::new() : Ty[Alignment]), v) {
    raise HintedError(StrSide::input().error(v))
  }
  let align : Alignment = v.cast()
  if align == alignment_start {
    Start
  } else if align == alignment_end {
    End
  } else {
    bail("expected either `start` or `end`")
  }
}

///|
pub impl IntoValue for StrSide with fn into_value(self) {
  match self {
    Start => alignment_start.into_value()
    End => alignment_end.into_value()
  }
}

///|
/// A replacement for a matched string.
pub(all) enum Replacement {
  /// A string a match is replaced with.
  Str(String)
  /// Function of type Dict -> Str (see `captures_to_dict` or
  /// `match_to_dict`) whose output is inserted for the match.
  Func(Func)
}

///|
pub impl Reflect for Replacement with fn input() {
  Union([Type(Type::str()), Type(Type::func())])
}

///|
pub impl Reflect for Replacement with fn output() {
  Replacement::input()
}

///|
pub impl Reflect for Replacement with fn castable(v) {
  str_castable(v) || castable_of((Ty::new() : Ty[Func]), v)
}

///|
pub extend Replacement with Reflect::{output, input, castable}

///|
pub impl IntoValue for Replacement with fn into_value(self) {
  match self {
    Str(v) => Str(v)
    Func(v) => Func(v)
  }
}

///|
pub impl FromValue for Replacement with fn from_value(v) {
  if str_castable(v) {
    Str(v.cast())
  } else if castable_of((Ty::new() : Ty[Func]), v) {
    Func(v.cast())
  } else {
    raise HintedError(Replacement::input().error(v))
  }
}
