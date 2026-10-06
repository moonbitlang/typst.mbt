///|
/// A string scanner (port of the `unscanny` crate) over UTF-16 indices.
///
/// The cursor is always on a scalar-value boundary.
priv struct Scanner {
  text : String
  mut cursor : Int
}

///|
fn Scanner::new(text : String) -> Scanner {
  { text, cursor: 0, }
}

///|
fn Scanner::copy(self : Scanner) -> Scanner {
  { text: self.text, cursor: self.cursor, }
}

///|
fn Scanner::done(self : Scanner) -> Bool {
  self.cursor >= self.text.length()
}

///|
fn Scanner::jump(self : Scanner, i : Int) -> Unit {
  self.cursor = if i < 0 {
    0
  } else if i > self.text.length() {
    self.text.length()
  } else {
    i
  }
}

///|
/// The char right after the cursor.
fn Scanner::peek(self : Scanner) -> Char? {
  if self.done() {
    None
  } else {
    let { cp: c, .. } = @unicode.decode_at(self.text, self.cursor)
    Some(Int::unsafe_to_char(c))
  }
}

///|
/// The char at relative char offset `n` from the cursor (`-1` is the char
/// before the cursor, `0` the char after it).
fn Scanner::scout(self : Scanner, n : Int) -> Char? {
  if n >= 0 {
    let mut i = self.cursor
    for _ in 0..<n {
      if i >= self.text.length() {
        return None
      }
      let { idx: next, .. } = @unicode.decode_at(self.text, i)
      i = next
    }
    if i >= self.text.length() {
      None
    } else {
      let { cp: c, .. } = @unicode.decode_at(self.text, i)
      Some(Int::unsafe_to_char(c))
    }
  } else {
    let mut i = self.cursor
    for _ in 0..<(-n - 1) {
      if i <= 0 {
        return None
      }
      let { idx: prev, .. } = @unicode.decode_before(self.text, i)
      i = prev
    }
    if i <= 0 {
      None
    } else {
      let { cp: c, .. } = @unicode.decode_before(self.text, i)
      Some(Int::unsafe_to_char(c))
    }
  }
}

///|
/// Consume and return the next char.
fn Scanner::eat(self : Scanner) -> Char? {
  if self.done() {
    None
  } else {
    let { cp: c, idx: next, } = @unicode.decode_at(self.text, self.cursor)
    self.cursor = next
    Some(Int::unsafe_to_char(c))
  }
}

///|
/// Un-consume the char before the cursor.
fn Scanner::uneat(self : Scanner) -> Unit {
  if self.cursor > 0 {
    let { idx: prev, .. } = @unicode.decode_before(self.text, self.cursor)
    self.cursor = prev
  }
}

///|
fn Scanner::at_char(self : Scanner, c : Char) -> Bool {
  self.peek() is Some(d) && d == c
}

///|
fn Scanner::at_str(self : Scanner, s : String) -> Bool {
  let n = s.length()
  if self.cursor + n > self.text.length() {
    return false
  }
  for i in 0..<n {
    if self.text.code_unit_at(self.cursor + i) != s.code_unit_at(i) {
      return false
    }
  }
  true
}

///|
fn Scanner::at_pred(self : Scanner, f : (Char) -> Bool) -> Bool {
  self.peek() is Some(c) && f(c)
}

///|
fn Scanner::eat_if_char(self : Scanner, c : Char) -> Bool {
  if self.at_char(c) {
    self.cursor += c.len_utf16()
    true
  } else {
    false
  }
}

///|
fn Scanner::eat_if_str(self : Scanner, s : String) -> Bool {
  if self.at_str(s) {
    self.cursor += s.length()
    true
  } else {
    false
  }
}

///|
fn Scanner::eat_if_pred(self : Scanner, f : (Char) -> Bool) -> Bool {
  match self.peek() {
    Some(c) if f(c) => {
      self.cursor += c.len_utf16()
      true
    }
    _ => false
  }
}

///|
/// Consume chars while `f` holds and return the consumed slice.
fn Scanner::eat_while(self : Scanner, f : (Char) -> Bool) -> String {
  let start = self.cursor
  while self.peek() is Some(c) && f(c) {
    self.cursor += c.len_utf16()
  }
  self.from(start)
}

///|
/// Consume chars until `f` holds and return the consumed slice.
fn Scanner::eat_until(self : Scanner, f : (Char) -> Bool) -> String {
  let start = self.cursor
  while self.peek() is Some(c) && !f(c) {
    self.cursor += c.len_utf16()
  }
  self.from(start)
}

///|
/// The text from `start` to the cursor.
fn Scanner::from(self : Scanner, start : Int) -> String {
  self.get(start, self.cursor)
}

///|
/// The text in the range, clamped to the string.
fn Scanner::get(self : Scanner, start : Int, end : Int) -> String {
  let len = self.text.length()
  let end = if end > len { len } else { end }
  let start = if start > end { end } else { start }
  self.text.unsafe_substring(start~, end~)
}

///|
fn Scanner::before(self : Scanner) -> String {
  self.get(0, self.cursor)
}

///|
fn Scanner::after(self : Scanner) -> String {
  self.get(self.cursor, self.text.length())
}

///|
/// The number of UTF-16 code units of a char (like Rust's `char::len_utf16`).
/// Not the core `Char::utf16_len`: core methods are not inlined into the
/// scanner's loops.
fn Char::len_utf16(self : Char) -> Int {
  if self.to_int() >= 0x10000 {
    2
  } else {
    1
  }
}
