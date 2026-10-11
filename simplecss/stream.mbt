// Port of `simplecss` 0.2.2 `src/stream.rs`.
//
// The stream works on the UTF-8 bytes of the text (like upstream), so byte
// offsets and the reported `TextPos`es are identical to upstream's.

///|
fn is_name_start(c : Int) -> Bool {
  match c {
    '_' | 'a'..<='z' | 'A'..<='Z' => true
    _ => is_non_ascii(c) || is_escape(c)
  }
}

///|
fn is_name_char(c : Int) -> Bool {
  match c {
    '_' | 'a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' => true
    _ => is_non_ascii(c) || is_escape(c)
  }
}

///|
fn is_non_ascii(c : Int) -> Bool {
  c > 237
}

///|
fn is_escape(_c : Int) -> Bool {
  // TODO: this
  false
}

///|
priv struct Stream {
  text : BytesView
  mut pos : Int
  end : Int
}

///|
fn Stream::new(text : BytesView) -> Stream {
  { text, pos: 0, end: text.length(), }
}

///|
fn Stream::from_string(text : String) -> Stream {
  Stream::new(@utf8.encode(text))
}

///|
fn Stream::pos(self : Stream) -> Int {
  self.pos
}

///|
fn Stream::jump_to_end(self : Stream) -> Unit {
  self.pos = self.end
}

///|
fn Stream::at_end(self : Stream) -> Bool {
  self.pos >= self.end
}

///|
fn Stream::curr_byte(self : Stream) -> Byte raise CssError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  self.curr_byte_unchecked()
}

///|
/// `curr_byte().ok()`.
fn Stream::curr_byte_ok(self : Stream) -> Byte? {
  if self.at_end() {
    None
  } else {
    Some(self.curr_byte_unchecked())
  }
}

///|
fn Stream::curr_byte_unchecked(self : Stream) -> Byte {
  self.text[self.pos]
}

///|
/// `next_byte().ok()`.
fn Stream::next_byte_ok(self : Stream) -> Byte? {
  if self.pos + 1 >= self.end {
    None
  } else {
    Some(self.text[self.pos + 1])
  }
}

///|
fn Stream::advance(self : Stream, n : Int) -> Unit {
  self.pos += n
}

///|
fn Stream::consume_byte(self : Stream, c : Byte) -> Unit raise CssError {
  if self.curr_byte() != c {
    raise InvalidByte(
      expected=c,
      actual=self.curr_byte(),
      pos=self.gen_text_pos(),
    )
  }
  self.advance(1)
}

///|
fn Stream::try_consume_byte(self : Stream, c : Byte) -> Unit {
  if self.curr_byte_ok() == Some(c) {
    self.advance(1)
  }
}

///|
fn Stream::consume_bytes(self : Stream, f : (Byte) -> Bool) -> String {
  let start = self.pos
  self.skip_bytes(f)
  self.slice_back(start)
}

///|
fn Stream::skip_bytes(self : Stream, f : (Byte) -> Bool) -> Unit {
  while !self.at_end() && f(self.curr_byte_unchecked()) {
    self.advance(1)
  }
}

///|
/// Decodes the UTF-8 char starting at byte `pos`: `(code point, len_utf8)`.
fn Stream::char_at(self : Stream, pos : Int) -> (Int, Int) {
  let b0 = self.text[pos].to_int()
  if b0 < 0x80 {
    (b0, 1)
  } else if b0 < 0xE0 {
    (((b0 & 0x1F) << 6) | (self.text[pos + 1].to_int() & 0x3F), 2)
  } else if b0 < 0xF0 {
    (
      ((b0 & 0x0F) << 12) |
      ((self.text[pos + 1].to_int() & 0x3F) << 6) |
      (self.text[pos + 2].to_int() & 0x3F),
      3,
    )
  } else {
    (
      ((b0 & 0x07) << 18) |
      ((self.text[pos + 1].to_int() & 0x3F) << 12) |
      ((self.text[pos + 2].to_int() & 0x3F) << 6) |
      (self.text[pos + 3].to_int() & 0x3F),
      4,
    )
  }
}

///|
fn Stream::slice_range(self : Stream, start : Int, end : Int) -> String {
  @utf8.decode_lossy(self.text[start:end])
}

///|
fn Stream::slice_back(self : Stream, pos : Int) -> String {
  self.slice_range(pos, self.pos)
}

///|
fn Stream::slice_tail(self : Stream) -> BytesView {
  self.text[self.pos:]
}

///|
fn Stream::skip_spaces(self : Stream) -> Unit {
  while !self.at_end() {
    match self.curr_byte_unchecked() {
      b' ' | b'\t' | b'\n' | b'\r' | b'\x0C' => self.advance(1)
      _ => break
    }
  }
}

///|
fn Stream::skip_spaces_and_comments(self : Stream) -> Unit raise CssError {
  self.skip_spaces()
  while self.curr_byte_ok() == Some(b'/') && self.next_byte_ok() == Some(b'*') {
    self.skip_comment()
    self.skip_spaces()
  }
}

///|
fn Stream::consume_ident(self : Stream) -> String raise CssError {
  let start = self.pos
  if self.curr_byte_ok() == Some(b'-') {
    self.advance(1)
  }
  if self.pos < self.end {
    let (c, len) = self.char_at(self.pos)
    if is_name_start(c) {
      self.advance(len)
    } else {
      raise InvalidIdent(self.gen_text_pos_from(start))
    }
    while self.pos < self.end {
      let (c, len) = self.char_at(self.pos)
      if is_name_char(c) {
        self.advance(len)
      } else {
        break
      }
    }
  }
  if start == self.pos {
    raise InvalidIdent(self.gen_text_pos_from(start))
  }
  self.slice_back(start)
}

///|
fn Stream::consume_string(self : Stream) -> String raise CssError {
  // Check for opening quote.
  let quote = self.curr_byte()
  if quote == b'\'' || quote == b'"' {
    let mut prev = quote
    self.advance(1)
    let start = self.pos
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
  } else {
    self.consume_ident()
  }
}

///|
fn Stream::skip_comment(self : Stream) -> Unit raise CssError {
  let start = self.pos
  self.skip_comment_impl() catch {
    _ => raise InvalidComment(self.gen_text_pos_from(start))
  }
}

///|
fn Stream::skip_comment_impl(self : Stream) -> Unit raise CssError {
  self.consume_byte(b'/')
  self.consume_byte(b'*')
  while !self.at_end() {
    let curr = self.curr_byte_unchecked()
    if curr == b'*' && self.next_byte_ok() == Some(b'/') {
      break
    }
    self.advance(1)
  }
  self.consume_byte(b'*')
  self.consume_byte(b'/')
}

///|
fn Stream::gen_text_pos(self : Stream) -> TextPos {
  let row = calc_curr_row(self.text, self.pos)
  let col = calc_curr_col(self.text, self.pos)
  TextPos::new(row, col)
}

///|
fn Stream::gen_text_pos_from(self : Stream, pos : Int) -> TextPos {
  let pos = if pos < self.text.length() { pos } else { self.text.length() }
  TextPos::new(calc_curr_row(self.text, pos), calc_curr_col(self.text, pos))
}

///|
fn calc_curr_row(text : BytesView, end : Int) -> UInt {
  let mut row = 1U
  for i in 0..<end {
    if text[i] == b'\n' {
      row += 1
    }
  }
  row
}

///|
fn calc_curr_col(text : BytesView, end : Int) -> UInt {
  // Counts the chars (non-continuation bytes) back to the previous newline.
  let mut col = 1U
  for i = end - 1; i >= 0; i = i - 1 {
    let c = text[i]
    if c == b'\n' {
      break
    } else if (c.to_int() & 0xC0) != 0x80 {
      col += 1
    }
  }
  col
}

///|
/// Rust's `str::trim` (Unicode `White_Space`).
fn rust_trim(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @unicode.is_whitespace(chars[start]) {
    start += 1
  }
  while end > start && @unicode.is_whitespace(chars[end - 1]) {
    end -= 1
  }
  if start == 0 && end == chars.length() {
    s
  } else {
    String::from_array(chars[start:end])
  }
}
