// Port of rustybuzz 0.20.1 `src/hb/text_parser.rs`.
//
// Works on the UTF-8 bytes of the text, like upstream.

///|
priv struct TextParser {
  mut pos : Int
  text : Bytes
}

///|
fn TextParser::new(text : String) -> TextParser {
  { pos: 0, text: @utf8.encode(text), }
}

///|
fn TextParser::at_end(self : TextParser) -> Bool {
  self.pos >= self.text.length()
}

///|
fn TextParser::curr_byte(self : TextParser) -> Int? {
  if !self.at_end() {
    Some(self.curr_byte_unchecked())
  } else {
    None
  }
}

///|
fn TextParser::curr_byte_unchecked(self : TextParser) -> Int {
  self.text[self.pos].to_int()
}

///|
fn TextParser::advance(self : TextParser, n : Int) -> Unit {
  self.pos += n
}

///|
fn TextParser::consume_byte(self : TextParser, c : Int) -> Unit? {
  guard self.curr_byte() is Some(curr) else { return None }
  if curr != c {
    return None
  }
  self.advance(1)
  Some(())
}

///|
fn is_ascii_whitespace(c : Int) -> Bool {
  // Unlike harfbuzz::ISSPACE, is_ascii_whitespace doesn't includes `\v`, but whatever.
  c == ' ' || c == '\t' || c == '\n' || c == 0x0C || c == '\r'
}

///|
fn TextParser::skip_spaces(self : TextParser) -> Unit {
  while !self.at_end() && is_ascii_whitespace(self.curr_byte_unchecked()) {
    self.advance(1)
  }
}

///|
fn TextParser::consume_quote(self : TextParser) -> Int? {
  guard self.curr_byte() is Some(c) else { return None }
  if c == '\'' || c == '"' {
    self.advance(1)
    Some(c)
  } else {
    None
  }
}

///|
fn TextParser::consume_bytes(self : TextParser, f : (Int) -> Bool) -> BytesView {
  let start = self.pos
  self.skip_bytes(f)
  self.text[start:self.pos]
}

///|
fn TextParser::skip_bytes(self : TextParser, f : (Int) -> Bool) -> Unit {
  while !self.at_end() && f(self.curr_byte_unchecked()) {
    self.advance(1)
  }
}

///|
fn is_ascii_digit(c : Int) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_ascii_alphabetic(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn TextParser::consume_tag(self : TextParser) -> @otf.Tag? {
  let tag = self.consume_bytes(c => {
    is_ascii_digit(c) || is_ascii_alphabetic(c) || c == '_'
  })
  if tag.length() > 4 {
    return None
  }
  Some(@otf.Tag::from_bytes_lossy(tag))
}

///|
/// Rust's `str::parse::<i32>`: an optional sign followed by at least one
/// digit, in range.
fn parse_i32(s : BytesView) -> Int? {
  let mut i = 0
  let mut neg = false
  if s.length() > 0 && (s[0] == b'-' || s[0] == b'+') {
    neg = s[0] == b'-'
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut v = 0L
  while i < s.length() {
    let c = s[i].to_int()
    if !is_ascii_digit(c) {
      return None
    }
    v = v * 10 + (c - '0').to_int64()
    if v > 2147483648L {
      return None
    }
    i += 1
  }
  if neg {
    v = -v
  }
  if v > 2147483647L {
    return None
  }
  Some(v.to_int())
}

///|
fn TextParser::consume_i32(self : TextParser) -> Int? {
  let start = self.pos
  if self.curr_byte() is Some('-' | '+') {
    self.advance(1)
  }
  self.skip_bytes(is_ascii_digit)
  parse_i32(self.text[start:self.pos])
}

///|
fn TextParser::consume_f32(self : TextParser) -> Float? {
  let start = self.pos

  // TODO: does number like 1-e2 required?

  if self.curr_byte() is Some('-' | '+') {
    self.advance(1)
  }
  self.skip_bytes(is_ascii_digit)
  if self.consume_byte('.') is Some(_) {
    self.skip_bytes(is_ascii_digit)
  }
  // Rust's `str::parse::<f32>` on `[+-]digits[.digits]`: needs a digit.
  let s = self.text[start:self.pos]
  let mut neg = false
  let mut i = 0
  if s.length() > 0 && (s[0] == b'-' || s[0] == b'+') {
    neg = s[0] == b'-'
    i = 1
  }
  let mut mantissa = 0.0
  let mut digits = 0
  let mut scale = 1.0
  let mut frac = false
  while i < s.length() {
    let c = s[i].to_int()
    if c == '.' {
      frac = true
    } else {
      mantissa = mantissa * 10.0 + (c - '0').to_double()
      if frac {
        scale = scale * 10.0
      }
      digits += 1
    }
    i += 1
  }
  if digits == 0 {
    return None
  }
  let v = mantissa / scale
  Some(Float::from_double(if neg { -v } else { v }))
}

///|
fn TextParser::consume_bool(self : TextParser) -> Bool? {
  self.skip_spaces()
  let value = self.consume_bytes(is_ascii_alphabetic)
  let lower = (b : Byte) => if b >= b'A' && b <= b'Z' { b + 32 } else { b }
  if value.length() == 2 {
    if lower(value[0]) == b'o' && lower(value[1]) == b'n' {
      return Some(true)
    }
  } else if value.length() == 3 {
    if lower(value[0]) == b'o' &&
      lower(value[1]) == b'f' &&
      lower(value[2]) == b'f' {
      return Some(false)
    }
  }
  None
}
