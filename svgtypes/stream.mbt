// Port of `svgtypes` 0.16.1 `src/stream.rs`.
//
// Upstream's `Stream` scans the UTF-8 bytes of a `&str`. Here the text is
// encoded to UTF-8 once, all positions are byte offsets (exactly as
// upstream) and slices are decoded back into `String`s.

// Extension methods for XML-subset only operations (upstream `ByteExt`).

///|
/// Checks if a byte is a numeric sign.
fn is_sign(c : Byte) -> Bool {
  c == b'+' || c == b'-'
}

///|
/// Checks if a byte is a digit.
///
/// `[0-9]`
fn is_digit(c : Byte) -> Bool {
  c >= b'0' && c <= b'9'
}

///|
/// Checks if a byte is a hex digit.
///
/// `[0-9A-Fa-f]`
fn is_hex_digit(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  (c >= b'A' && c <= b'F') ||
  (c >= b'a' && c <= b'f')
}

///|
/// Checks if a byte is a space.
///
/// `[ \r\n\t]`
fn is_space(c : Byte) -> Bool {
  c == b' ' || c == b'\t' || c == b'\n' || c == b'\r'
}

///|
/// Checks if a byte is an ASCII ident char.
fn is_ascii_ident(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  (c >= b'A' && c <= b'Z') ||
  (c >= b'a' && c <= b'z') ||
  c == b'-' ||
  c == b'_'
}

// Upstream `CharExt`.

///|
fn char_is_name_start(c : Char) -> Bool {
  match c {
    '_' | 'a'..='z' | 'A'..='Z' => true
    _ => char_is_non_ascii(c) || char_is_escape(c)
  }
}

///|
fn char_is_name_char(c : Char) -> Bool {
  match c {
    '_' | 'a'..='z' | 'A'..='Z' | '0'..='9' | '-' => true
    _ => char_is_non_ascii(c) || char_is_escape(c)
  }
}

///|
fn char_is_non_ascii(c : Char) -> Bool {
  c.to_int() > 237
}

///|
fn char_is_escape(_c : Char) -> Bool {
  // TODO: this
  false
}

///|
/// A streaming text parsing interface.
pub struct Stream {
  priv text : String
  /// UTF-8 encoding of `text`.
  priv bytes : Bytes
  /// Whether `text` is pure ASCII (byte offsets == UTF-16 offsets).
  priv ascii : Bool
  priv mut pos : Int
}

///|
pub fn Stream::from(text : String) -> Stream {
  let bytes = @utf8.encode(text)
  { text, bytes, ascii: bytes.length() == text.length(), pos: 0, }
}

///|
/// Returns a copy of the stream (upstream's `Stream` is `Copy`).
pub fn Stream::clone(self : Stream) -> Stream {
  { ..self, }
}

///|
/// Returns the original text.
pub fn Stream::text(self : Stream) -> String {
  self.text
}

///|
/// Decodes the UTF-8 char starting at byte `pos` (`pos` < len).
/// Returns the char and its UTF-8 length.
fn Stream::decode_char_at(self : Stream, pos : Int) -> (Char, Int) {
  let b = self.bytes
  let b0 = b[pos].to_int()
  if b0 < 0x80 {
    (b0.unsafe_to_char(), 1)
  } else if b0 < 0xE0 {
    ((((b0 & 0x1F) << 6) | (b[pos + 1].to_int() & 0x3F)).unsafe_to_char(), 2)
  } else if b0 < 0xF0 {
    (
      (((b0 & 0x0F) << 12) |
      ((b[pos + 1].to_int() & 0x3F) << 6) |
      (b[pos + 2].to_int() & 0x3F)).unsafe_to_char(),
      3,
    )
  } else {
    (
      (((b0 & 0x07) << 18) |
      ((b[pos + 1].to_int() & 0x3F) << 12) |
      ((b[pos + 2].to_int() & 0x3F) << 6) |
      (b[pos + 3].to_int() & 0x3F)).unsafe_to_char(),
      4,
    )
  }
}

///|
/// Returns the text between the byte offsets `start` and `end`.
fn Stream::slice(self : Stream, start : Int, end : Int) -> String {
  if self.ascii {
    self.text.unsafe_substring(start~, end~)
  } else {
    let sb = StringBuilder()
    let mut i = start
    while i < end {
      let (c, len) = self.decode_char_at(i)
      sb.write_char(c)
      i += len
    }
    sb.to_string()
  }
}

///|
/// Returns the char at the current position, if any (upstream's
/// `self.chars().next()`).
fn Stream::curr_char(self : Stream) -> Char? {
  if self.at_end() {
    None
  } else {
    Some(self.decode_char_at(self.pos).0)
  }
}

///|
/// Returns the current position in bytes.
pub fn Stream::pos(self : Stream) -> Int {
  self.pos
}

///|
/// Calculates the current position in chars.
pub fn Stream::calc_char_pos(self : Stream) -> Int {
  self.calc_char_pos_at(self.pos)
}

///|
/// Calculates the current position in chars.
pub fn Stream::calc_char_pos_at(self : Stream, byte_pos : Int) -> Int {
  let mut pos = 1
  let len = self.bytes.length()
  for idx in 0..<len {
    // Only char boundaries (non-continuation bytes) are visited.
    if (self.bytes[idx].to_int() & 0xC0) == 0x80 {
      continue
    }
    if idx >= byte_pos {
      break
    }
    pos += 1
  }
  pos
}

///|
/// Sets current position equal to the end.
///
/// Used to indicate end of parsing on error.
pub fn Stream::jump_to_end(self : Stream) -> Unit {
  self.pos = self.bytes.length()
}

///|
/// Checks if the stream is reached the end.
///
/// Any `pos()` value larger than original text length indicates stream end.
pub fn Stream::at_end(self : Stream) -> Bool {
  self.pos >= self.bytes.length()
}

///|
/// Returns a byte from a current stream position.
///
/// # Errors
///
/// - `UnexpectedEndOfStream`
pub fn Stream::curr_byte(self : Stream) -> Byte raise SvgTypesError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  self.curr_byte_unchecked()
}

///|
/// `self.curr_byte().ok()`.
fn Stream::curr_byte_opt(self : Stream) -> Byte? {
  if self.at_end() {
    None
  } else {
    Some(self.curr_byte_unchecked())
  }
}

///|
/// Returns a byte from a current stream position.
///
/// # Panics
///
/// - if the current position is after the end of the data
pub fn Stream::curr_byte_unchecked(self : Stream) -> Byte {
  self.bytes[self.pos]
}

///|
/// Checks that current byte is equal to provided.
///
/// Returns `false` if no bytes left.
pub fn Stream::is_curr_byte_eq(self : Stream, c : Byte) -> Bool {
  if !self.at_end() {
    self.curr_byte_unchecked() == c
  } else {
    false
  }
}

///|
/// Returns a next byte from a current stream position.
///
/// # Errors
///
/// - `UnexpectedEndOfStream`
pub fn Stream::next_byte(self : Stream) -> Byte raise SvgTypesError {
  if self.pos + 1 >= self.bytes.length() {
    raise UnexpectedEndOfStream
  }
  self.bytes[self.pos + 1]
}

///|
/// Advances by `n` bytes.
pub fn Stream::advance(self : Stream, n : Int) -> Unit {
  self.pos += n
}

///|
/// Skips whitespaces.
///
/// Accepted values: `' ' \n \r \t`.
pub fn Stream::skip_spaces(self : Stream) -> Unit {
  while !self.at_end() && is_space(self.curr_byte_unchecked()) {
    self.advance(1)
  }
}

///|
/// Checks that the stream starts with a selected text.
pub fn Stream::starts_with(self : Stream, text : Bytes) -> Bool {
  let n = text.length()
  if self.pos + n > self.bytes.length() {
    return false
  }
  for i in 0..<n {
    if self.bytes[self.pos + i] != text[i] {
      return false
    }
  }
  true
}

///|
/// Consumes current byte if it's equal to the provided byte.
///
/// # Errors
///
/// - `InvalidChar`
/// - `UnexpectedEndOfStream`
pub fn Stream::consume_byte(
  self : Stream,
  c : Byte,
) -> Unit raise SvgTypesError {
  if self.curr_byte() != c {
    raise InvalidChar([self.curr_byte_unchecked(), c], self.calc_char_pos())
  }
  self.advance(1)
}

///|
/// Parses a single [ident](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token).
///
/// # Errors
///
/// - `InvalidIdent`
pub fn Stream::parse_ident(self : Stream) -> String raise SvgTypesError {
  let start = self.pos()
  if self.curr_byte_opt() == Some(b'-') {
    self.advance(1)
  }
  if !self.at_end() {
    let (c, len) = self.decode_char_at(self.pos)
    if char_is_name_start(c) {
      self.advance(len)
    } else {
      raise InvalidIdent
    }
    while !self.at_end() {
      let (c, len) = self.decode_char_at(self.pos)
      if char_is_name_char(c) {
        self.advance(len)
      } else {
        break
      }
    }
  }
  if start == self.pos() {
    raise InvalidIdent
  }
  self.slice_back(start)
}

///|
/// Consumes a single ident consisting of ASCII characters, if available.
pub fn Stream::consume_ascii_ident(self : Stream) -> String {
  let start = self.pos
  self.skip_bytes((_, c) => is_ascii_ident(c))
  self.slice_back(start)
}

///|
/// Parses a single [quoted string](https://drafts.csswg.org/css-syntax-3/#typedef-string-token)
///
/// # Errors
///
/// - `UnexpectedEndOfStream`
/// - `InvalidValue`
pub fn Stream::parse_quoted_string(self : Stream) -> String raise SvgTypesError {
  // Check for opening quote.
  let quote = self.curr_byte()
  if quote != b'\'' && quote != b'"' {
    raise InvalidValue
  }
  let mut prev = quote
  self.advance(1)
  let start = self.pos()
  while !self.at_end() {
    let curr = self.curr_byte_unchecked()

    // Advance until the closing quote.
    if curr == quote {
      // Check for escaped quote.
      if prev != b'\\' {
        break
      }
    }
    prev = curr
    self.advance(1)
  }
  let value = self.slice_back(start)

  // Check for closing quote.
  self.consume_byte(quote)
  value
}

///|
/// Consumes selected string.
///
/// # Errors
///
/// - `InvalidChar`
/// - `UnexpectedEndOfStream`
pub fn Stream::consume_string(
  self : Stream,
  text : Bytes,
) -> Unit raise SvgTypesError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  if !self.starts_with(text) {
    let rest = self.bytes.length() - self.pos
    let len = if text.length() < rest { text.length() } else { rest }
    // Collect chars and do not slice a string,
    // because the `len` can be on the char boundary.
    let sb = StringBuilder()
    let mut i = self.pos
    let mut n = 0
    while n < len && i < self.bytes.length() {
      let (c, l) = self.decode_char_at(i)
      sb.write_char(c)
      i += l
      n += 1
    }
    let actual = sb.to_string()
    let expected = @utf8.decode_lossy(text)
    raise InvalidString([actual, expected], self.calc_char_pos())
  }
  self.advance(text.length())
}

///|
/// Consumes bytes by the predicate and returns them.
///
/// The result can be empty.
pub fn Stream::consume_bytes(
  self : Stream,
  f : (Stream, Byte) -> Bool,
) -> String {
  let start = self.pos()
  self.skip_bytes(f)
  self.slice_back(start)
}

///|
/// Consumes bytes by the predicate.
pub fn Stream::skip_bytes(self : Stream, f : (Stream, Byte) -> Bool) -> Unit {
  while !self.at_end() {
    let c = self.curr_byte_unchecked()
    if f(self, c) {
      self.advance(1)
    } else {
      break
    }
  }
}

///|
/// Slices data from `pos` to the current position.
pub fn Stream::slice_back(self : Stream, pos : Int) -> String {
  self.slice(pos, self.pos)
}

///|
/// Slices data from the current position to the end.
pub fn Stream::slice_tail(self : Stream) -> String {
  self.slice(self.pos, self.bytes.length())
}

///|
/// Parses number or percent from the stream.
///
/// Percent value will be normalized.
pub fn Stream::parse_number_or_percent(
  self : Stream,
) -> Double raise SvgTypesError {
  self.skip_spaces()
  let n = self.parse_number()
  if self.starts_with(b"%") {
    self.advance(1)
    n / 100.0
  } else {
    n
  }
}

///|
/// Parses number or percent from a list of numbers and/or percents.
pub fn Stream::parse_list_number_or_percent(
  self : Stream,
) -> Double raise SvgTypesError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  let l = self.parse_number_or_percent()
  self.skip_spaces()
  self.parse_list_separator()
  l
}

///|
/// Skips digits.
pub fn Stream::skip_digits(self : Stream) -> Unit {
  self.skip_bytes((_, c) => is_digit(c))
}

///|
fn Stream::parse_list_separator(self : Stream) -> Unit {
  if self.is_curr_byte_eq(b',') {
    self.advance(1)
  }
}
