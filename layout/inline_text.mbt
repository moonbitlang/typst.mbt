// UTF-8 indexed strings for the inline layout port.
//
// Upstream slices the paragraph's `&str` by UTF-8 byte offsets everywhere.
// MoonBit strings are UTF-16, so the full text of an inline layout is stored
// once together with byte -> UTF-16 and byte -> code point tables, and
// substrings are `Utf8Slice`s into it (cheap, like upstream's `&str`).

///|
/// A string indexed by UTF-8 byte offsets.
priv struct Utf8Str {
  /// The text.
  s : String
  /// `u16[i]` is the UTF-16 index of byte offset `i` if it is a char
  /// boundary, otherwise `-1`. Has length `len + 1`.
  u16 : FixedArray[Int]
  /// `cps[i]` is the code point starting at byte `i`, or `-1`.
  cps : FixedArray[Int]
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
/// The UTF-8 length of a string.
fn utf8_str_len(s : StringView) -> Int {
  let mut n = 0
  for i = 0; i < s.length(); {
    let (c, next) = @unicode.decode_at(s, i)
    n += utf8_char_len(c)
    continue next
  }
  n
}

///|
fn Utf8Str::new(s : String) -> Utf8Str {
  let len = utf8_str_len(s)
  let u16 = FixedArray::make(len + 1, -1)
  let cps = FixedArray::make(len, -1)
  let mut pos = 0
  for i = 0; i < s.length(); {
    let (c, next) = @unicode.decode_at(s, i)
    u16[pos] = i
    cps[pos] = c
    pos += utf8_char_len(c)
    continue next
  }
  u16[len] = s.length()
  { s, u16, cps, }
}

///|
fn Utf8Str::len(self : Utf8Str) -> Int {
  self.cps.length()
}

///|
/// The whole string as a slice.
fn Utf8Str::full(self : Utf8Str) -> Utf8Slice {
  { src: self, start: 0, end: self.len(), }
}

///|
/// A substring of a `Utf8Str` (upstream `&str`). All offsets of its methods
/// are relative to its start.
priv struct Utf8Slice {
  src : Utf8Str
  start : Int
  end : Int
}

///|
/// A slice of a fresh string.
fn Utf8Slice::from_string(s : String) -> Utf8Slice {
  Utf8Str::new(s).full()
}

///|
let empty_slice : Utf8Slice = Utf8Slice::from_string("")

///|
/// The length in UTF-8 bytes.
fn Utf8Slice::len(self : Utf8Slice) -> Int {
  self.end - self.start
}

///|
fn Utf8Slice::is_empty(self : Utf8Slice) -> Bool {
  self.end == self.start
}

///|
/// The slice as a MoonBit string.
fn Utf8Slice::to_string(self : Utf8Slice) -> String {
  let a = self.src.u16[self.start]
  let b = self.src.u16[self.end]
  if a == 0 && b == self.src.s.length() {
    self.src.s
  } else {
    self.src.s.unsafe_substring(start=a, end=b)
  }
}

///|
/// Slice by relative byte offsets (must be char boundaries).
fn Utf8Slice::slice(self : Utf8Slice, a : Int, b : Int) -> Utf8Slice {
  { src: self.src, start: self.start + a, end: self.start + b, }
}

///|
/// Whether the relative offset `i` is a char boundary.
fn Utf8Slice::is_char_boundary(self : Utf8Slice, i : Int) -> Bool {
  i == 0 || i == self.len() || self.src.u16[self.start + i] >= 0
}

///|
/// The code point starting at relative offset `i`, or `-1`.
fn Utf8Slice::char_at(self : Utf8Slice, i : Int) -> Int {
  if i >= 0 && i < self.len() {
    self.src.cps[self.start + i]
  } else {
    -1
  }
}

///|
/// The first char, if any.
fn Utf8Slice::first_char(self : Utf8Slice) -> Int? {
  if self.is_empty() {
    None
  } else {
    Some(self.src.cps[self.start])
  }
}

///|
/// The relative start offset of the char ending at relative offset `i`.
fn Utf8Slice::char_start_before(self : Utf8Slice, i : Int) -> Int {
  let mut j = i - 1
  while j > 0 && self.src.cps[self.start + j] < 0 {
    j -= 1
  }
  j
}

///|
/// The last char, if any.
fn Utf8Slice::last_char(self : Utf8Slice) -> Int? {
  if self.is_empty() {
    None
  } else {
    Some(self.src.cps[self.start + self.char_start_before(self.len())])
  }
}

///|
/// The `(relative byte offset, code point)` pairs.
fn Utf8Slice::char_indices(self : Utf8Slice) -> Array[(Int, Int)] {
  let out = []
  for i in self.start..<self.end {
    let c = self.src.cps[i]
    if c >= 0 {
      out.push((i - self.start, c))
    }
  }
  out
}

///|
/// Whether the slice ends with the given char.
fn Utf8Slice::ends_with_char(self : Utf8Slice, c : Char) -> Bool {
  self.last_char() == Some(c.to_int())
}

///|
/// Whether the slice starts with the given char.
fn Utf8Slice::starts_with_char(self : Utf8Slice, c : Char) -> Bool {
  self.first_char() == Some(c.to_int())
}

///|
/// Whether the slice starts with the given ASCII string.
fn Utf8Slice::starts_with_ascii(self : Utf8Slice, prefix : String) -> Bool {
  let n = prefix.length()
  if n > self.len() {
    return false
  }
  for i in 0..<n {
    if self.src.cps[self.start + i] != prefix.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
/// Whether the slice ends with the given ASCII string.
fn Utf8Slice::ends_with_ascii(self : Utf8Slice, suffix : String) -> Bool {
  let n = suffix.length()
  if n > self.len() {
    return false
  }
  let base = self.end - n
  for i in 0..<n {
    if self.src.cps[base + i] != suffix.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
/// The relative length after trimming trailing chars matching `pred`.
fn Utf8Slice::trim_end_len(self : Utf8Slice, pred : (Int) -> Bool) -> Int {
  let mut end = self.len()
  while end > 0 {
    let start = self.char_start_before(end)
    if !pred(self.src.cps[self.start + start]) {
      break
    }
    end = start
  }
  end
}

///|
/// `self.slice(start, end).trim_end_len(c => is_whitespace(c))` without
/// allocating the slice and the closure (performance).
fn Utf8Slice::trim_end_whitespace_len(
  self : Utf8Slice,
  start : Int,
  end : Int,
) -> Int {
  let base = self.start + start
  let mut len = end - start
  while len > 0 {
    // `char_start_before` on the sub-slice.
    let mut j = len - 1
    while j > 0 && self.src.cps[base + j] < 0 {
      j -= 1
    }
    if !@unicode.is_whitespace(char_of(self.src.cps[base + j])) {
      break
    }
    len = j
  }
  len
}

///|
fn char_of(c : Int) -> Char {
  Int::unsafe_to_char(c)
}
