// The UTF-8 text source of the bidi algorithm (`TextSource for str` in
// upstream `lib.rs`). MoonBit strings are UTF-16, but all indices of this
// package are UTF-8 byte offsets, exactly like the Rust crate's.

///|
/// The number of UTF-8 bytes of a code point.
pub fn utf8_char_len(c : Int) -> Int {
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
/// A string together with its code points indexed by UTF-8 byte offset.
pub struct Utf8Text {
  /// The text.
  text : String
  /// `cps[i]` is the code point starting at byte `i`, or `-1` if byte `i` is
  /// not a char boundary.
  cps : FixedArray[Int]
}

///|
/// Index a string by UTF-8 byte offsets.
pub fn Utf8Text::new(text : String) -> Utf8Text {
  let mut len = 0
  for i = 0; i < text.length(); {
    let (c, next) = @unicode.decode_at(text, i)
    len += utf8_char_len(c)
    continue next
  }
  let cps = FixedArray::make(len, -1)
  let mut pos = 0
  for i = 0; i < text.length(); {
    let (c, next) = @unicode.decode_at(text, i)
    cps[pos] = c
    pos += utf8_char_len(c)
    continue next
  }
  { text, cps, }
}

///|
/// The length of the text in UTF-8 bytes.
pub fn Utf8Text::len(self : Utf8Text) -> Int {
  self.cps.length()
}

///|
/// Whether byte `i` is a char boundary (`i == len` counts as one).
pub fn Utf8Text::is_char_boundary(self : Utf8Text, i : Int) -> Bool {
  i == self.cps.length() ||
  (i >= 0 && i < self.cps.length() && self.cps[i] >= 0)
}

///|
/// The code point starting at byte `i`, if `i` is a char boundary.
pub fn Utf8Text::char_at(self : Utf8Text, i : Int) -> Int? {
  if i >= 0 && i < self.cps.length() && self.cps[i] >= 0 {
    Some(self.cps[i])
  } else {
    None
  }
}

///|
/// The `(byte index, code point)` pairs of the text.
pub fn Utf8Text::char_indices(self : Utf8Text) -> Array[(Int, Int)] {
  self.view().char_indices()
}

///|
/// Slice the text by UTF-8 byte offsets.
pub fn Utf8Text::slice(self : Utf8Text, start : Int, end : Int) -> String {
  let buf = StringBuilder()
  for i in start..<end {
    let c = self.cps[i]
    if c >= 0 {
      buf.write_char(Int::unsafe_to_char(c))
    }
  }
  buf.to_string()
}

///|
fn Utf8Text::view(self : Utf8Text) -> TextSlice {
  { cps: self.cps, start: 0, end: self.cps.length(), }
}

///|
/// A subrange of a `Utf8Text`, indexed relative to its start.
priv struct TextSlice {
  cps : FixedArray[Int]
  start : Int
  end : Int
}

///|
fn TextSlice::len(self : TextSlice) -> Int {
  self.end - self.start
}

///|
/// Get the character at a given code unit index, along with its length in
/// code units. Returns None if index is out of range, or points inside a
/// multi-code-unit character.
fn TextSlice::char_at(self : TextSlice, index : Int) -> (Int, Int)? {
  if index >= 0 && index < self.len() {
    let c = self.cps[self.start + index]
    if c >= 0 {
      return Some((c, utf8_char_len(c)))
    }
  }
  None
}

///|
fn TextSlice::subrange(self : TextSlice, start : Int, end : Int) -> TextSlice {
  guard start >= 0 && start <= end && end <= self.len() else {
    abort("byte index out of range")
  }
  { cps: self.cps, start: self.start + start, end: self.start + end, }
}

///|
fn TextSlice::char_indices(self : TextSlice) -> Array[(Int, Int)] {
  let out = []
  for i in self.start..<self.end {
    let c = self.cps[i]
    if c >= 0 {
      out.push((i - self.start, c))
    }
  }
  out
}

///|
fn TextSlice::chars(self : TextSlice) -> Array[Int] {
  let out = []
  for i in self.start..<self.end {
    let c = self.cps[i]
    if c >= 0 {
      out.push(c)
    }
  }
  out
}

///|
/// The first char of the slice.
fn TextSlice::first_char(self : TextSlice) -> Int? {
  for i in self.start..<self.end {
    let c = self.cps[i]
    if c >= 0 {
      return Some(c)
    }
  }
  None
}
