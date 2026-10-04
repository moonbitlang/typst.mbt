// Helpers for Rust `str` semantics.

///|
fn is_ws(c : Int) -> Bool {
  @unicode.is_whitespace(c.unsafe_to_char())
}

///|
/// Rust's `str::trim` (Unicode `White_Space`).
pub fn rust_trim(s : StringView) -> StringView {
  let mut start = 0
  while start < s.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(s, start)
    if !is_ws(c) {
      break
    }
    start = next
  }
  let mut end = s.length()
  while end > start {
    let { cp: c, idx: prev, } = @unicode.decode_before(s, end)
    if !is_ws(c) {
      break
    }
    end = prev
  }
  s[start:end]
}

///|
/// The UTF-8 length of a string.
pub fn utf8_len(s : StringView) -> Int {
  let mut n = 0
  let mut i = 0
  while i < s.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    n += utf8_char_len(c)
    i = next
  }
  n
}

///|
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
/// Maps UTF-8 byte offsets of a string to UTF-16 indices. Offsets that are
/// not on a char boundary map to -1.
pub struct ByteIndex {
  priv text : String
  priv map : FixedArray[Int]
}

///|
pub fn ByteIndex::new(text : String) -> ByteIndex {
  let map = FixedArray::make(utf8_len(text) + 1, -1)
  let mut b = 0
  let mut i = 0
  while i < text.length() {
    map[b] = i
    let { cp: c, idx: next, } = @unicode.decode_at(text, i)
    b += utf8_char_len(c)
    i = next
  }
  map[b] = text.length()
  { text, map, }
}

///|
/// The text.
pub fn ByteIndex::text(self : ByteIndex) -> String {
  self.text
}

///|
/// The UTF-8 length of the text.
pub fn ByteIndex::len(self : ByteIndex) -> Int {
  self.map.length() - 1
}

///|
/// The UTF-16 index of a UTF-8 offset.
pub fn ByteIndex::utf16(self : ByteIndex, byte : Int) -> Int {
  self.map[byte]
}

///|
/// Slice the text by UTF-8 offsets (`&text[start..end]`).
pub fn ByteIndex::slice(self : ByteIndex, start : Int, end : Int) -> String {
  self.text.unsafe_substring(start=self.map[start], end=self.map[end])
}
