// Port of the `unscanny` crate (0.1.0): painless string scanning.
//
// Like upstream, all indices (`cursor`, `from`, `jump`, ...) are UTF-8 byte
// offsets into the scanned string, so that spans computed by the ports of
// `biblatex` and `hayagriva` match upstream byte for byte. Internally, the
// string is stored as an array of chars with their byte offsets.

///|
/// A string scanner.
pub struct Scanner {
  priv chars : Array[Char]
  /// `offs[i]` is the byte offset of `chars[i]`; `offs[chars.length()]` is
  /// the total byte length.
  priv offs : Array[Int]
  /// The cursor as a char index.
  priv mut idx : Int
}

///|
/// The UTF-8 length of a char.
pub fn char_len_utf8(c : Char) -> Int {
  let n = c.to_int()
  if n < 0x80 {
    1
  } else if n < 0x800 {
    2
  } else if n < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// The UTF-8 length of a string.
pub fn len_utf8(s : StringView) -> Int {
  let mut n = 0
  for c in s {
    n += char_len_utf8(c)
  }
  n
}

///|
/// Create a new string scanner, starting with a cursor position of `0`.
pub fn Scanner::new(string : StringView) -> Scanner {
  let chars = []
  let offs = []
  let mut off = 0
  for c in string {
    chars.push(c)
    offs.push(off)
    off += char_len_utf8(c)
  }
  offs.push(off)
  { chars, offs, idx: 0, }
}

///|
/// The full source string.
pub fn Scanner::string(self : Scanner) -> String {
  String::from_array(self.chars)
}

///|
/// The current cursor position (a byte offset).
pub fn Scanner::cursor(self : Scanner) -> Int {
  self.offs[self.idx]
}

///|
/// Whether the scanner has fully consumed the string.
pub fn Scanner::done(self : Scanner) -> Bool {
  self.idx >= self.chars.length()
}

///|
fn Scanner::slice(self : Scanner, start : Int, end : Int) -> String {
  if start >= end {
    return ""
  }
  String::from_array(self.chars[start:end])
}

///|
/// The subslice before the cursor.
pub fn Scanner::before(self : Scanner) -> String {
  self.slice(0, self.idx)
}

///|
/// The subslice after the cursor.
pub fn Scanner::after(self : Scanner) -> String {
  self.slice(self.idx, self.chars.length())
}

///|
/// Snap a byte index to a char index (in bounds, on a codepoint boundary,
/// rounding down like upstream).
fn Scanner::snap(self : Scanner, index : Int) -> Int {
  let n = self.chars.length()
  if index >= self.offs[n] {
    return n
  }
  if index <= 0 {
    return 0
  }
  // Binary search for the largest `i` with `offs[i] <= index`.
  let mut lo = 0
  let mut hi = n
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if self.offs[mid] <= index {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  lo
}

///|
/// The subslice from `start` to the cursor.
///
/// Snaps `start` into the bounds of the string and to the next previous char
/// boundary.
pub fn Scanner::from(self : Scanner, start : Int) -> String {
  let s = self.snap(start)
  let s = if s < self.idx { s } else { self.idx }
  self.slice(s, self.idx)
}

///|
/// The subslice from the cursor to `end`.
pub fn Scanner::to(self : Scanner, end : Int) -> String {
  let e = self.snap(end)
  let e = if e > self.idx { e } else { self.idx }
  self.slice(self.idx, e)
}

///|
/// The subslice from `start` to `end`.
pub fn Scanner::get(self : Scanner, start : Int, end : Int) -> String {
  let s = self.snap(start)
  let e = self.snap(end)
  let e = if e > s { e } else { s }
  self.slice(s, e)
}

///|
/// The character right behind the cursor.
pub fn Scanner::peek(self : Scanner) -> Char? {
  if self.idx < self.chars.length() {
    Some(self.chars[self.idx])
  } else {
    None
  }
}

///|
/// Look at the n-th character relative to the cursor without changing the
/// cursor.
///
/// - `scout(-1)` is the character before the cursor.
/// - `scout(0)` is the same as `peek()`.
pub fn Scanner::scout(self : Scanner, n : Int) -> Char? {
  let i = self.idx + n
  if i >= 0 && i < self.chars.length() {
    Some(self.chars[i])
  } else {
    None
  }
}

///|
/// The byte index of the n-th character relative to the cursor.
pub fn Scanner::locate(self : Scanner, n : Int) -> Int {
  let mut i = self.idx + n
  if i < 0 {
    i = 0
  }
  if i > self.chars.length() {
    i = self.chars.length()
  }
  self.offs[i]
}

///|
/// Consume and return the character right behind the cursor.
pub fn Scanner::eat(self : Scanner) -> Char? {
  let peeked = self.peek()
  if peeked is Some(_) {
    self.idx += 1
  }
  peeked
}

///|
/// Un-consume and return the character right before the cursor.
pub fn Scanner::uneat(self : Scanner) -> Char? {
  if self.idx > 0 {
    self.idx -= 1
    Some(self.chars[self.idx])
  } else {
    None
  }
}

///|
/// Whether the part right behind the cursor starts with the given char.
pub fn Scanner::at_char(self : Scanner, c : Char) -> Bool {
  self.peek() == Some(c)
}

///|
/// Whether the part right behind the cursor starts with the given string.
pub fn Scanner::at_str(self : Scanner, s : StringView) -> Bool {
  self.match_str(s) is Some(_)
}

///|
/// Whether the char right behind the cursor matches the predicate.
pub fn Scanner::at_fn(self : Scanner, f : (Char) -> Bool) -> Bool {
  match self.peek() {
    Some(c) => f(c)
    None => false
  }
}

///|
/// How many chars the string `s` covers if the part after the cursor starts
/// with it.
fn Scanner::match_str(self : Scanner, s : StringView) -> Int? {
  let mut i = self.idx
  for c in s {
    if i >= self.chars.length() || self.chars[i] != c {
      return None
    }
    i += 1
  }
  Some(i - self.idx)
}

///|
/// Consume the given char if it's next.
pub fn Scanner::eat_if(self : Scanner, c : Char) -> Bool {
  if self.peek() == Some(c) {
    self.idx += 1
    true
  } else {
    false
  }
}

///|
/// Consume the given string if it's next.
pub fn Scanner::eat_if_str(self : Scanner, s : StringView) -> Bool {
  match self.match_str(s) {
    Some(n) => {
      self.idx += n
      true
    }
    None => false
  }
}

///|
/// Consume the next char if it is one of the given chars.
pub fn Scanner::eat_if_any(self : Scanner, cs : Array[Char]) -> Bool {
  match self.peek() {
    Some(c) if cs.contains(c) => {
      self.idx += 1
      true
    }
    _ => false
  }
}

///|
/// Consume the next char if it matches the predicate.
pub fn Scanner::eat_if_fn(self : Scanner, f : (Char) -> Bool) -> Bool {
  match self.peek() {
    Some(c) if f(c) => {
      self.idx += 1
      true
    }
    _ => false
  }
}

///|
/// Consume while the next char matches the predicate and return the
/// consumed substring.
pub fn Scanner::eat_while(self : Scanner, f : (Char) -> Bool) -> String {
  let start = self.idx
  while self.idx < self.chars.length() && f(self.chars[self.idx]) {
    self.idx += 1
  }
  self.slice(start, self.idx)
}

///|
/// Consume while the given char is next.
pub fn Scanner::eat_while_char(self : Scanner, c : Char) -> String {
  self.eat_while(x => x == c)
}

///|
/// Consume while the given string is next.
pub fn Scanner::eat_while_str(self : Scanner, s : StringView) -> String {
  let start = self.idx
  if s.is_empty() {
    return ""
  }
  while self.match_str(s) is Some(n) {
    self.idx += n
  }
  self.slice(start, self.idx)
}

///|
/// Consume until the next char matches the predicate and return the
/// consumed substring.
pub fn Scanner::eat_until(self : Scanner, f : (Char) -> Bool) -> String {
  self.eat_while(c => !f(c))
}

///|
/// Consume until the given char is next.
pub fn Scanner::eat_until_char(self : Scanner, c : Char) -> String {
  self.eat_while(x => x != c)
}

///|
/// Consume until one of the given chars is next.
pub fn Scanner::eat_until_any(self : Scanner, cs : Array[Char]) -> String {
  self.eat_while(x => !cs.contains(x))
}

///|
/// Consume until the given string is next.
pub fn Scanner::eat_until_str(self : Scanner, s : StringView) -> String {
  let start = self.idx
  while !self.done() && self.match_str(s) is None {
    self.idx += 1
  }
  self.slice(start, self.idx)
}

///|
/// Consume all whitespace until the next non-whitespace character.
pub fn Scanner::eat_whitespace(self : Scanner) -> String {
  self.eat_while(is_whitespace)
}

///|
/// Jump to a byte position in the source string.
///
/// Snaps into the bounds of the string and to the next previous char
/// boundary.
pub fn Scanner::jump(self : Scanner, target : Int) -> Unit {
  self.idx = self.snap(target)
}
