// Port of the parts of `serde_json` 1.0.151 (`de.rs`, `read.rs`,
// `error.rs`) that `serde_json::from_slice::<Value>` exercises for Typst
// values (`deserialize_any` with `SliceRead`, without the `float_roundtrip`
// and `arbitrary_precision` features).

///|
/// The kind of a JSON syntax error (upstream `ErrorCode`).
pub(all) enum ErrorCode {
  EofWhileParsingList
  EofWhileParsingObject
  EofWhileParsingString
  EofWhileParsingValue
  ExpectedColon
  ExpectedListCommaOrEnd
  ExpectedObjectCommaOrEnd
  ExpectedSomeIdent
  ExpectedSomeValue
  InvalidEscape
  InvalidNumber
  NumberOutOfRange
  InvalidUnicodeCodePoint
  ControlCharacterWhileParsingString
  KeyMustBeAString
  LoneLeadingSurrogateInHexEscape
  TrailingComma
  TrailingCharacters
  UnexpectedEndOfHexEscape
  RecursionLimitExceeded
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ErrorCode with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ErrorCode with @debug.Debug::{to_repr}

///|
pub impl Show for ErrorCode with fn output(self, logger) {
  logger.write_string(
    match self {
      EofWhileParsingList => "EOF while parsing a list"
      EofWhileParsingObject => "EOF while parsing an object"
      EofWhileParsingString => "EOF while parsing a string"
      EofWhileParsingValue => "EOF while parsing a value"
      ExpectedColon => "expected `:`"
      ExpectedListCommaOrEnd => "expected `,` or `]`"
      ExpectedObjectCommaOrEnd => "expected `,` or `}`"
      ExpectedSomeIdent => "expected ident"
      ExpectedSomeValue => "expected value"
      InvalidEscape => "invalid escape"
      InvalidNumber => "invalid number"
      NumberOutOfRange => "number out of range"
      InvalidUnicodeCodePoint => "invalid unicode code point"
      ControlCharacterWhileParsingString =>
        "control character (\\u0000-\\u001F) found while parsing a string"
      KeyMustBeAString => "key must be a string"
      LoneLeadingSurrogateInHexEscape => "lone leading surrogate in hex escape"
      TrailingComma => "trailing comma"
      TrailingCharacters => "trailing characters"
      UnexpectedEndOfHexEscape => "unexpected end of hex escape"
      RecursionLimitExceeded => "recursion limit exceeded"
    },
  )
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ErrorCode with Show::{to_string, output}

///|
/// A JSON syntax error with its 1-based line and 0-based byte column
/// (upstream `serde_json::Error`).
pub(all) suberror JsonError {
  JsonError(code~ : ErrorCode, line~ : Int, column~ : Int)
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend JsonError with @debug.Debug::{to_repr}

///|
/// The line at which the error occurred (1-based).
pub fn JsonError::line(self : JsonError) -> Int {
  let JsonError(line~, ..) = self
  line
}

///|
/// The column at which the error occurred (as reported by serde_json).
pub fn JsonError::column(self : JsonError) -> Int {
  let JsonError(column~, ..) = self
  column
}

///|
/// The error's `Display` output: `"{code} at line {line} column {column}"`.
pub fn JsonError::message(self : JsonError) -> String {
  let JsonError(code~, line~, column~) = self
  if line == 0 {
    Show::to_string(code)
  } else {
    "\{code} at line \{line} column \{column}"
  }
}

///|
/// A JSON deserializer reading from a byte slice.
priv struct Deserializer {
  slice : Bytes
  mut index : Int
  mut remaining_depth : Int
}

///|
/// Deserialize a value from JSON bytes (upstream
/// `serde_json::from_slice::<Value>`).
pub fn from_slice(bytes : Bytes) -> @serde.Data raise JsonError {
  let de : Deserializer = { slice: bytes, index: 0, remaining_depth: 128, }
  let value = de.deserialize_any()
  de.end()
  value
}

///|
fn Deserializer::position_of_index(self : Deserializer, i : Int) -> (Int, Int) {
  let mut start_of_line = 0
  let mut line = 1
  for j in 0..<i {
    if self.slice[j] == b'\n' {
      start_of_line = j + 1
      line += 1
    }
  }
  (line, i - start_of_line)
}

///|
/// Error caused by a byte from `next_char()`.
fn Deserializer::error(self : Deserializer, code : ErrorCode) -> JsonError {
  let (line, column) = self.position_of_index(self.index)
  JsonError(code~, line~, column~)
}

///|
/// Error caused by a byte from `peek()`.
fn Deserializer::peek_error(self : Deserializer, code : ErrorCode) -> JsonError {
  let i = if self.index + 1 < self.slice.length() {
    self.index + 1
  } else {
    self.slice.length()
  }
  let (line, column) = self.position_of_index(i)
  JsonError(code~, line~, column~)
}

///|
fn Deserializer::peek(self : Deserializer) -> Byte? {
  if self.index < self.slice.length() {
    Some(self.slice[self.index])
  } else {
    None
  }
}

///|
fn Deserializer::peek_or_null(self : Deserializer) -> Byte {
  self.peek().unwrap_or(b'\x00')
}

///|
fn Deserializer::eat_char(self : Deserializer) -> Unit {
  self.index += 1
}

///|
fn Deserializer::next_char(self : Deserializer) -> Byte? {
  if self.index < self.slice.length() {
    let ch = self.slice[self.index]
    self.index += 1
    Some(ch)
  } else {
    None
  }
}

///|
/// Validate that the input is at the end or that it only has trailing
/// whitespace.
fn Deserializer::end(self : Deserializer) -> Unit raise JsonError {
  match self.parse_whitespace() {
    Some(_) => raise self.peek_error(TrailingCharacters)
    None => ()
  }
}

///|
/// Returns the first non-whitespace byte without consuming it, or `None` if
/// EOF is encountered.
fn Deserializer::parse_whitespace(self : Deserializer) -> Byte? {
  while true {
    match self.peek() {
      Some(b' ' | b'\n' | b'\t' | b'\r') => self.eat_char()
      other => return other
    }
  }
  None
}

///|
fn Deserializer::parse_ident(
  self : Deserializer,
  ident : String,
) -> Unit raise JsonError {
  for expected in ident {
    match self.next_char() {
      None => raise self.error(EofWhileParsingValue)
      Some(next) =>
        if next.to_int() != expected.to_int() {
          raise self.error(ExpectedSomeIdent)
        }
    }
  }
}

///|
fn overflow_u64(a : UInt64, b : UInt64) -> Bool {
  let c = 0xFFFF_FFFF_FFFF_FFFFUL
  a >= c / 10 && (a > c / 10 || b > c % 10)
}

///|
fn overflow_i32(a : Int, b : Int) -> Bool {
  let c = 0x7FFF_FFFF
  a >= c / 10 && (a > c / 10 || b > c % 10)
}

///|
fn is_digit(c : Byte) -> Bool {
  c >= b'0' && c <= b'9'
}

///|
fn Deserializer::parse_integer(
  self : Deserializer,
  positive : Bool,
) -> @serde.Data raise JsonError {
  let next = match self.next_char() {
    Some(b) => b
    None => raise self.error(EofWhileParsingValue)
  }
  if next == b'0' {
    // There can be only one leading '0'.
    if is_digit(self.peek_or_null()) {
      raise self.peek_error(InvalidNumber)
    }
    self.parse_number(positive, 0)
  } else if next >= b'1' && next <= b'9' {
    let mut significand = (next - b'0').to_uint64()
    while true {
      let c = self.peek_or_null()
      if is_digit(c) {
        let digit = (c - b'0').to_uint64()
        // We need to be careful with overflow. If we can, try to keep the
        // number as a `u64` until we grow too large. At that point, switch to
        // parsing the value as a `f64`.
        if overflow_u64(significand, digit) {
          return Float(self.parse_long_integer(positive, significand))
        }
        self.eat_char()
        significand = significand * 10 + digit
      } else {
        return self.parse_number(positive, significand)
      }
    }
    panic()
  } else {
    raise self.error(InvalidNumber)
  }
}

///|
fn Deserializer::parse_number(
  self : Deserializer,
  positive : Bool,
  significand : UInt64,
) -> @serde.Data raise JsonError {
  match self.peek_or_null() {
    b'.' => Float(self.parse_decimal(positive, significand, 0))
    b'e' | b'E' => Float(self.parse_exponent(positive, significand, 0))
    _ =>
      if positive {
        @serde.Data::from_u64(significand)
      } else {
        let neg = -significand.reinterpret_as_int64()
        // Convert into a float if we underflow, or on `-0`.
        if neg >= 0L {
          Float(-significand.to_double())
        } else {
          Int(neg)
        }
      }
  }
}

///|
fn Deserializer::parse_decimal(
  self : Deserializer,
  positive : Bool,
  significand : UInt64,
  exponent_before_decimal_point : Int,
) -> Double raise JsonError {
  self.eat_char()
  let mut significand = significand
  let mut exponent_after_decimal_point = 0
  while is_digit(self.peek_or_null()) {
    let c = self.peek_or_null()
    let digit = (c - b'0').to_uint64()
    if overflow_u64(significand, digit) {
      let exponent = exponent_before_decimal_point +
        exponent_after_decimal_point
      return self.parse_decimal_overflow(positive, significand, exponent)
    }
    self.eat_char()
    significand = significand * 10 + digit
    exponent_after_decimal_point -= 1
  }

  // Error if there is not at least one digit after the decimal point.
  if exponent_after_decimal_point == 0 {
    match self.peek() {
      Some(_) => raise self.peek_error(InvalidNumber)
      None => raise self.peek_error(EofWhileParsingValue)
    }
  }
  let exponent = exponent_before_decimal_point + exponent_after_decimal_point
  match self.peek_or_null() {
    b'e' | b'E' => self.parse_exponent(positive, significand, exponent)
    _ => self.f64_from_parts(positive, significand, exponent)
  }
}

///|
fn Deserializer::parse_exponent(
  self : Deserializer,
  positive : Bool,
  significand : UInt64,
  starting_exp : Int,
) -> Double raise JsonError {
  self.eat_char()
  let positive_exp = match self.peek_or_null() {
    b'+' => {
      self.eat_char()
      true
    }
    b'-' => {
      self.eat_char()
      false
    }
    _ => true
  }
  let next = match self.next_char() {
    Some(b) => b
    None => raise self.error(EofWhileParsingValue)
  }

  // Make sure a digit follows the exponent place.
  if !is_digit(next) {
    raise self.error(InvalidNumber)
  }
  let mut exp = (next - b'0').to_int()
  while is_digit(self.peek_or_null()) {
    let c = self.peek_or_null()
    self.eat_char()
    let digit = (c - b'0').to_int()
    if overflow_i32(exp, digit) {
      let zero_significand = significand == 0
      return self.parse_exponent_overflow(
        positive, zero_significand, positive_exp,
      )
    }
    exp = exp * 10 + digit
  }
  let final_exp = if positive_exp {
    saturating_add_i32(starting_exp, exp)
  } else {
    saturating_add_i32(starting_exp, -exp)
  }
  self.f64_from_parts(positive, significand, final_exp)
}

///|
fn saturating_add_i32(a : Int, b : Int) -> Int {
  let r = a.to_int64() + b.to_int64()
  if r > 0x7FFF_FFFFL {
    0x7FFF_FFFF
  } else if r < -0x8000_0000L {
    -0x8000_0000
  } else {
    r.to_int()
  }
}

///|
/// The powers of ten `1e0..=1e308` (upstream `POW10`).
let pow10 : FixedArray[Double] = {
  let arr = FixedArray::make(309, 0.0)
  for i in 0..<309 {
    arr[i] = @string.parse_double("1e\{i}") catch { _ => 0.0 }
  }
  arr
}

///|
fn Deserializer::f64_from_parts(
  self : Deserializer,
  positive : Bool,
  significand : UInt64,
  exponent : Int,
) -> Double raise JsonError {
  let mut f = significand.to_double()
  let mut exponent = exponent
  while true {
    let abs = if exponent < 0 { -exponent } else { exponent }
    if abs >= 0 && abs < 309 {
      let pow = pow10[abs]
      if exponent >= 0 {
        f = f * pow
        if f.is_inf() {
          raise self.error(NumberOutOfRange)
        }
      } else {
        f = f / pow
      }
      break
    } else {
      if f == 0.0 {
        break
      }
      if exponent >= 0 {
        raise self.error(NumberOutOfRange)
      }
      f = f / 1.0e308
      exponent += 308
    }
  }
  if positive {
    f
  } else {
    -f
  }
}

///|
fn Deserializer::parse_long_integer(
  self : Deserializer,
  positive : Bool,
  significand : UInt64,
) -> Double raise JsonError {
  let mut exponent = 0
  while true {
    match self.peek_or_null() {
      b'0'..<=b'9' => {
        self.eat_char()
        // This could overflow... if your integer is gigabytes long. Ignore
        // that possibility.
        exponent += 1
      }
      b'.' => return self.parse_decimal(positive, significand, exponent)
      b'e' | b'E' => return self.parse_exponent(positive, significand, exponent)
      _ => return self.f64_from_parts(positive, significand, exponent)
    }
  }
  panic()
}

///|
fn Deserializer::parse_decimal_overflow(
  self : Deserializer,
  positive : Bool,
  significand : UInt64,
  exponent : Int,
) -> Double raise JsonError {
  // The next multiply/add would overflow, so just ignore all further digits.
  while is_digit(self.peek_or_null()) {
    self.eat_char()
  }
  match self.peek_or_null() {
    b'e' | b'E' => self.parse_exponent(positive, significand, exponent)
    _ => self.f64_from_parts(positive, significand, exponent)
  }
}

///|
fn Deserializer::parse_exponent_overflow(
  self : Deserializer,
  positive : Bool,
  zero_significand : Bool,
  positive_exp : Bool,
) -> Double raise JsonError {
  // Error instead of +/- infinity.
  if !zero_significand && positive_exp {
    raise self.error(NumberOutOfRange)
  }
  while is_digit(self.peek_or_null()) {
    self.eat_char()
  }
  if positive {
    0.0
  } else {
    -0.0
  }
}

///|
fn Deserializer::end_seq(self : Deserializer) -> Unit raise JsonError {
  match self.parse_whitespace() {
    Some(b']') => self.eat_char()
    Some(b',') => {
      self.eat_char()
      match self.parse_whitespace() {
        Some(b']') => raise self.peek_error(TrailingComma)
        _ => raise self.peek_error(TrailingCharacters)
      }
    }
    Some(_) => raise self.peek_error(TrailingCharacters)
    None => raise self.peek_error(EofWhileParsingList)
  }
}

///|
fn Deserializer::end_map(self : Deserializer) -> Unit raise JsonError {
  match self.parse_whitespace() {
    Some(b'}') => self.eat_char()
    Some(b',') => raise self.peek_error(TrailingComma)
    Some(_) => raise self.peek_error(TrailingCharacters)
    None => raise self.peek_error(EofWhileParsingObject)
  }
}

///|
fn Deserializer::parse_object_colon(
  self : Deserializer,
) -> Unit raise JsonError {
  match self.parse_whitespace() {
    Some(b':') => self.eat_char()
    Some(_) => raise self.peek_error(ExpectedColon)
    None => raise self.peek_error(EofWhileParsingObject)
  }
}

///|
/// Upstream `deserialize_any` driving Typst's `ValueVisitor`.
fn Deserializer::deserialize_any(
  self : Deserializer,
) -> @serde.Data raise JsonError {
  let peek = match self.parse_whitespace() {
    Some(b) => b
    None => raise self.peek_error(EofWhileParsingValue)
  }
  match peek {
    b'n' => {
      self.eat_char()
      self.parse_ident("ull")
      None
    }
    b't' => {
      self.eat_char()
      self.parse_ident("rue")
      Bool(true)
    }
    b'f' => {
      self.eat_char()
      self.parse_ident("alse")
      Bool(false)
    }
    b'-' => {
      self.eat_char()
      self.parse_integer(false)
    }
    b'0'..<=b'9' => self.parse_integer(true)
    b'"' => {
      self.eat_char()
      Str(self.parse_str())
    }
    b'[' => {
      self.remaining_depth -= 1
      if self.remaining_depth == 0 {
        raise self.peek_error(RecursionLimitExceeded)
      }
      self.eat_char()
      // (Upstream also runs `end_seq` when this fails, but reports this
      // error.)
      let ret = self.visit_seq()
      self.remaining_depth += 1
      self.end_seq()
      Seq(ret)
    }
    b'{' => {
      self.remaining_depth -= 1
      if self.remaining_depth == 0 {
        raise self.peek_error(RecursionLimitExceeded)
      }
      self.eat_char()
      // (Upstream also runs `end_map` when this fails, but reports this
      // error.)
      let ret = self.visit_map()
      self.remaining_depth += 1
      self.end_map()
      Map(ret)
    }
    _ => raise self.peek_error(ExpectedSomeValue)
  }
}

///|
/// Upstream `SeqAccess::next_element_seed` loop.
fn Deserializer::visit_seq(
  self : Deserializer,
) -> Array[@serde.Data] raise JsonError {
  let items = []
  let mut first = true
  while true {
    let peek = match self.parse_whitespace() {
      Some(b) => b
      None => raise self.peek_error(EofWhileParsingList)
    }
    if peek == b']' {
      break
    } else if first {
      first = false
    } else if peek == b',' {
      self.eat_char()
      match self.parse_whitespace() {
        Some(b']') => raise self.peek_error(TrailingComma)
        Some(_) => ()
        None => raise self.peek_error(EofWhileParsingValue)
      }
    } else {
      raise self.peek_error(ExpectedListCommaOrEnd)
    }
    items.push(self.deserialize_any())
  }
  items
}

///|
/// Upstream `MapAccess::next_key_seed` / `next_value_seed` loop.
fn Deserializer::visit_map(
  self : Deserializer,
) -> Array[(String, @serde.Data)] raise JsonError {
  let entries = []
  let mut first = true
  while true {
    let peek = match self.parse_whitespace() {
      Some(b) => b
      None => raise self.peek_error(EofWhileParsingObject)
    }
    if peek == b'}' {
      break
    } else if first {
      first = false
      if peek != b'"' {
        raise self.peek_error(KeyMustBeAString)
      }
    } else if peek == b',' {
      self.eat_char()
      match self.parse_whitespace() {
        Some(b'"') => ()
        Some(b'}') => raise self.peek_error(TrailingComma)
        Some(_) => raise self.peek_error(KeyMustBeAString)
        None => raise self.peek_error(EofWhileParsingValue)
      }
    } else {
      raise self.peek_error(ExpectedObjectCommaOrEnd)
    }
    // `MapKey::deserialize_any`: a string key.
    self.eat_char()
    let key = self.parse_str()
    self.parse_object_colon()
    let value = self.deserialize_any()
    entries.push((key, value))
  }
  entries
}

///|
fn is_escape(ch : Byte) -> Bool {
  ch == b'"' || ch == b'\\' || ch < b'\x20'
}

///|
/// Parse a string after the opening quote (upstream `SliceRead::parse_str`).
fn Deserializer::parse_str(self : Deserializer) -> String raise JsonError {
  let scratch = Buffer()
  let mut start = self.index
  while true {
    while self.index < self.slice.length() && !is_escape(self.slice[self.index]) {
      self.index += 1
    }
    if self.index == self.slice.length() {
      raise self.error(EofWhileParsingString)
    }
    match self.slice[self.index] {
      b'"' => {
        scratch.write_bytesview(self.slice[start:self.index])
        self.index += 1
        let bytes = scratch.to_bytes()
        guard valid_utf8(bytes) else {
          raise self.error(InvalidUnicodeCodePoint)
        }
        return @utf8.decode(bytes) catch { _ => panic() }
      }
      b'\\' => {
        scratch.write_bytesview(self.slice[start:self.index])
        self.index += 1
        self.parse_escape(scratch)
        start = self.index
      }
      _ => {
        self.index += 1
        raise self.error(ControlCharacterWhileParsingString)
      }
    }
  }
  panic()
}

///|
fn Deserializer::next_or_eof(self : Deserializer) -> Byte raise JsonError {
  match self.next_char() {
    Some(b) => b
    None => raise self.error(EofWhileParsingString)
  }
}

///|
fn Deserializer::peek_or_eof(self : Deserializer) -> Byte raise JsonError {
  match self.peek() {
    Some(b) => b
    None => raise self.error(EofWhileParsingString)
  }
}

///|
/// Parses a JSON escape sequence and appends it into the scratch space.
/// Assumes the previous byte read was a backslash.
fn Deserializer::parse_escape(
  self : Deserializer,
  scratch : Buffer,
) -> Unit raise JsonError {
  let ch = self.next_or_eof()
  match ch {
    b'"' => scratch.write_byte(b'"')
    b'\\' => scratch.write_byte(b'\\')
    b'/' => scratch.write_byte(b'/')
    b'b' => scratch.write_byte(b'\x08')
    b'f' => scratch.write_byte(b'\x0c')
    b'n' => scratch.write_byte(b'\n')
    b'r' => scratch.write_byte(b'\r')
    b't' => scratch.write_byte(b'\t')
    b'u' => self.parse_unicode_escape(scratch)
    _ => raise self.error(InvalidEscape)
  }
}

///|
fn hex_val(b : Byte) -> Int? {
  if b >= b'0' && b <= b'9' {
    Some((b - b'0').to_int())
  } else if b >= b'A' && b <= b'F' {
    Some((b - b'A').to_int() + 10)
  } else if b >= b'a' && b <= b'f' {
    Some((b - b'a').to_int() + 10)
  } else {
    None
  }
}

///|
fn Deserializer::decode_hex_escape(self : Deserializer) -> Int raise JsonError {
  if self.index + 4 > self.slice.length() {
    self.index = self.slice.length()
    raise self.error(EofWhileParsingString)
  }
  let mut n = 0
  let mut ok = true
  for k in 0..<4 {
    match hex_val(self.slice[self.index + k]) {
      Some(v) => n = n * 16 + v
      None => ok = false
    }
  }
  self.index += 4
  if !ok {
    raise self.error(InvalidEscape)
  }
  n
}

///|
/// Parses a JSON `\u` escape and appends it into the scratch space. Assumes
/// `\u` has just been read.
fn Deserializer::parse_unicode_escape(
  self : Deserializer,
  scratch : Buffer,
) -> Unit raise JsonError {
  let n = self.decode_hex_escape()

  // Non-BMP characters are encoded as a sequence of two hex escapes,
  // representing UTF-16 surrogates. When deserializing a UTF-8 string the
  // surrogates are required to be paired.
  if n >= 0xDC00 && n <= 0xDFFF {
    raise self.error(LoneLeadingSurrogateInHexEscape)
  }
  if n < 0xD800 || n > 0xDBFF {
    push_codepoint(n, scratch)
    return
  }

  // n is a leading surrogate, we now expect a trailing surrogate.
  let n1 = n
  if self.peek_or_eof() == b'\\' {
    self.eat_char()
  } else {
    self.eat_char()
    raise self.error(UnexpectedEndOfHexEscape)
  }
  if self.peek_or_eof() == b'u' {
    self.eat_char()
  } else {
    self.eat_char()
    raise self.error(UnexpectedEndOfHexEscape)
  }
  let n2 = self.decode_hex_escape()
  if n2 < 0xDC00 || n2 > 0xDFFF {
    raise self.error(LoneLeadingSurrogateInHexEscape)
  }
  let n = (((n1 - 0xD800) << 10) | (n2 - 0xDC00)) + 0x1_0000
  push_codepoint(n, scratch)
}

///|
/// Adds a codepoint to the end of the buffer as UTF-8.
fn push_codepoint(n : Int, scratch : Buffer) -> Unit {
  if n < 0x80 {
    scratch.write_byte(n.to_byte())
  } else if n < 0x800 {
    scratch.write_byte((((n >> 6) & 0x1F) | 0xC0).to_byte())
    scratch.write_byte(((n & 0x3F) | 0x80).to_byte())
  } else if n < 0x10000 {
    scratch.write_byte((((n >> 12) & 0x0F) | 0xE0).to_byte())
    scratch.write_byte((((n >> 6) & 0x3F) | 0x80).to_byte())
    scratch.write_byte(((n & 0x3F) | 0x80).to_byte())
  } else {
    scratch.write_byte((((n >> 18) & 0x07) | 0xF0).to_byte())
    scratch.write_byte((((n >> 12) & 0x3F) | 0x80).to_byte())
    scratch.write_byte((((n >> 6) & 0x3F) | 0x80).to_byte())
    scratch.write_byte(((n & 0x3F) | 0x80).to_byte())
  }
}

///|
/// Whether the bytes are valid UTF-8 (like Rust's `str::from_utf8`).
pub fn valid_utf8(bytes : BytesView) -> Bool {
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let first = bytes[i].to_int()
    if first < 0x80 {
      i += 1
      continue
    }
    let width = if first >= 0xC2 && first <= 0xDF {
      2
    } else if first >= 0xE0 && first <= 0xEF {
      3
    } else if first >= 0xF0 && first <= 0xF4 {
      4
    } else {
      return false
    }
    if i + width > n {
      return false
    }
    let second = bytes[i + 1].to_int()
    let second_ok = match width {
      2 => second >= 0x80 && second <= 0xBF
      3 =>
        (first == 0xE0 && second >= 0xA0 && second <= 0xBF) ||
        (first >= 0xE1 && first <= 0xEC && second >= 0x80 && second <= 0xBF) ||
        (first == 0xED && second >= 0x80 && second <= 0x9F) ||
        (first >= 0xEE && first <= 0xEF && second >= 0x80 && second <= 0xBF)
      _ =>
        (first == 0xF0 && second >= 0x90 && second <= 0xBF) ||
        (first >= 0xF1 && first <= 0xF3 && second >= 0x80 && second <= 0xBF) ||
        (first == 0xF4 && second >= 0x80 && second <= 0x8F)
    }
    if !second_ok {
      return false
    }
    for k in 2..<width {
      let b = bytes[i + k].to_int()
      if b < 0x80 || b > 0xBF {
        return false
      }
    }
    i += width
  }
  true
}
