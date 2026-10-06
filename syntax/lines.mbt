// Port of `crates/typst-syntax/src/lines.rs`.
//
// Upstream `Lines<S>` is generic over the text buffer and reference-counted
// (copy-on-write on `edit`). Here the text is always a `String` and `Lines` is
// a mutable object: `edit` and `replace` update it in place.
//
// All indices are UTF-8 byte offsets, UTF-16 code unit offsets, line and
// column numbers exactly like upstream. Upstream takes `usize`; negative
// arguments are out of range here and yield `None`.

///|
/// A text buffer and metadata about lines.
pub struct Lines {
  /// The text.
  priv mut text : String
  /// The UTF-8 byte length of the text.
  priv mut len : Int
  /// The start of every line.
  priv lines : Array[Line]
}

///|
/// Metadata about a line.
priv struct Line {
  /// The UTF-8 byte offset where the line starts.
  byte_idx : Int
  /// The UTF-16 codepoint offset where the line starts.
  utf16_idx : Int
}

///|
/// Create from the text buffer and compute the line metadata.
pub fn Lines::new(text : String) -> Lines {
  { text, len: utf8_len(text), lines: compute_lines(text), }
}

///|
/// The text as a string.
pub fn Lines::text(self : Lines) -> String {
  self.text
}

///|
/// Get the length of the file in UTF-8 encoded bytes.
pub fn Lines::len_bytes(self : Lines) -> Int {
  self.len
}

///|
/// Get the length of the file in UTF-16 code units.
pub fn Lines::len_utf16(self : Lines) -> Int {
  // The text is stored as UTF-16, so this is simply its length.
  self.text.length()
}

///|
/// Get the length of the file in lines.
pub fn Lines::len_lines(self : Lines) -> Int {
  self.lines.length()
}

///|
/// Return the index of the UTF-16 code unit at the byte index.
pub fn Lines::byte_to_utf16(self : Lines, byte_idx : Int) -> Int? {
  guard self.byte_to_line(byte_idx) is Some(line_idx) else { return None }
  guard self.lines.get(line_idx) is Some(line) else { return None }
  self.advance_bytes(line, byte_idx)
}

///|
/// Walk from the start of `line` to the UTF-8 offset `byte_idx` and return
/// the UTF-16 index there, or `None` if `byte_idx` is not a char boundary
/// (or lies before the line).
fn Lines::advance_bytes(self : Lines, line : Line, byte_idx : Int) -> Int? {
  let text = self.text
  let mut b = line.byte_idx
  let mut u = line.utf16_idx
  while b < byte_idx && u < text.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(text, u)
    b += utf8_char_len(c)
    u = next
  }
  if b == byte_idx {
    Some(u)
  } else {
    None
  }
}

///|
/// Return the index of the line that contains the given byte index.
pub fn Lines::byte_to_line(self : Lines, byte_idx : Int) -> Int? {
  guard byte_idx >= 0 && byte_idx <= self.len else { return None }
  match self.lines.binary_search_by(line => line.byte_idx.compare(byte_idx)) {
    Ok(i) => Some(i)
    Err(i) => Some(i - 1)
  }
}

///|
/// Return the index of the column at the byte index.
///
/// The column is defined as the number of characters in the line before the
/// byte index.
pub fn Lines::byte_to_column(self : Lines, byte_idx : Int) -> Int? {
  guard self.byte_to_line(byte_idx) is Some(line) else { return None }
  self.column_in(line, byte_idx)
}

///|
/// The number of characters in `line` before `byte_idx`.
fn Lines::column_in(self : Lines, line_idx : Int, byte_idx : Int) -> Int? {
  guard self.lines.get(line_idx) is Some(line) else { return None }
  guard self.advance_bytes(line, byte_idx) is Some(end) else { return None }
  let mut count = 0
  let mut u = line.utf16_idx
  while u < end {
    let { idx: next, .. } = @unicode.decode_at(self.text, u)
    count += 1
    u = next
  }
  Some(count)
}

///|
/// Return the index of the line and column at the byte index.
pub fn Lines::byte_to_line_column(self : Lines, byte_idx : Int) -> (Int, Int)? {
  guard self.byte_to_line(byte_idx) is Some(line) else { return None }
  guard self.column_in(line, byte_idx) is Some(col) else { return None }
  Some((line, col))
}

///|
/// Return the byte index at the UTF-16 code unit.
pub fn Lines::utf16_to_byte(self : Lines, utf16_idx : Int) -> Int? {
  guard utf16_idx >= 0 else { return None }
  let line_idx = match
    self.lines.binary_search_by(line => line.utf16_idx.compare(utf16_idx)) {
    Ok(i) => i
    Err(i) => i - 1
  }
  guard self.lines.get(line_idx) is Some(line) else { return None }
  let text = self.text
  let mut k = line.utf16_idx
  let mut b = line.byte_idx
  let mut u = line.utf16_idx
  while u < text.length() {
    if k >= utf16_idx {
      return Some(b)
    }
    let { cp: c, idx: next, } = @unicode.decode_at(text, u)
    k += next - u
    b += utf8_char_len(c)
    u = next
  }
  if k == utf16_idx {
    Some(self.len)
  } else {
    None
  }
}

///|
/// Return the byte position at which the given line starts.
pub fn Lines::line_to_byte(self : Lines, line_idx : Int) -> Int? {
  guard line_idx >= 0 else { return None }
  self.lines.get(line_idx).map(line => line.byte_idx)
}

///|
/// Return the range which encloses the given line.
pub fn Lines::line_to_range(self : Lines, line_idx : Int) -> (Int, Int)? {
  guard self.line_to_byte(line_idx) is Some(start) else { return None }
  let end = self.line_to_byte(line_idx + 1).unwrap_or(self.len)
  Some((start, end))
}

///|
/// Return the byte index of the given (line, column) pair, or `None` if
/// either is out-of-range.
///
/// The column defines the number of characters to go beyond the start of
/// the line.
pub fn Lines::line_column_to_byte(
  self : Lines,
  line_idx : Int,
  column_idx : Int,
) -> Int? {
  guard self.line_to_range(line_idx) is Some((start, end)) else { return None }
  guard column_idx >= 0 else { return None }
  let line = self.lines[line_idx]
  let text = self.text
  let mut b = start
  let mut u = line.utf16_idx
  for _ in 0..<column_idx {
    guard b < end else { return None }
    let { cp: c, idx: next, } = @unicode.decode_at(text, u)
    b += utf8_char_len(c)
    u = next
  }
  Some(b)
}

///|
/// Fully replace the source text.
///
/// This performs a naive (suffix/prefix-based) diff of the old and new text
/// to produce the smallest single edit that transforms old into new and
/// then calls [`edit`](Self::edit) with it.
///
/// Returns whether any changes were made.
pub fn Lines::replace(self : Lines, new : String) -> Bool {
  guard self.replacement_range(new) is Some((prefix, suffix)) else {
    return false
  }
  let old_len = self.len
  let new_len = utf8_len(new)
  let replacement = utf8_slice(new, prefix, new_len - suffix)
  self.edit(prefix, old_len - suffix, replacement)
  true
}

///|
/// Returns the common prefix and suffix lengths.
/// Returns [`None`] if the old and new strings are equal.
pub fn Lines::replacement_range(self : Lines, new : String) -> (Int, Int)? {
  let old = @utf8.encode(self.text)
  let new = @utf8.encode(new)
  let mut prefix = 0
  while prefix < old.length() &&
        prefix < new.length() &&
        old[prefix] == new[prefix] {
    prefix += 1
  }
  if prefix == old.length() && prefix == new.length() {
    return None
  }
  while !is_char_boundary(old, prefix) || !is_char_boundary(new, prefix) {
    prefix -= 1
  }
  let mut suffix = 0
  while prefix + suffix < old.length() &&
        prefix + suffix < new.length() &&
        old[old.length() - 1 - suffix] == new[new.length() - 1 - suffix] {
    suffix += 1
  }
  while !is_char_boundary(old, old.length() - suffix) ||
        !is_char_boundary(new, new.length() - suffix) {
    suffix += 1
  }
  Some((prefix, suffix))
}

///|
/// Edit the source file by replacing the given byte range `start..end` with
/// `replacement`.
///
/// Aborts if the range is out of bounds or not on char boundaries.
pub fn Lines::edit(
  self : Lines,
  start : Int,
  end : Int,
  replacement : String,
) -> Unit {
  let start_byte = start
  guard self.byte_to_utf16(start_byte) is Some(start_utf16) &&
    self.byte_to_line(start_byte) is Some(line) &&
    end >= start &&
    self.byte_to_utf16(end) is Some(end_utf16) else {
    abort("invalid edit range")
  }

  // Update the text itself.
  let text = self.text
  self.text = text.unsafe_substring(start=0, end=start_utf16) +
    replacement +
    text.unsafe_substring(start=end_utf16, end=text.length())
  self.len = self.len - (end - start) + utf8_len(replacement)

  // Remove invalidated line starts.
  self.lines.truncate(line + 1)

  // Handle adjoining of \r and \n.
  if start_utf16 > 0 &&
    self.text.code_unit_at(start_utf16 - 1) == '\r' &&
    replacement.has_prefix("\n") {
    self.lines.unsafe_pop() |> ignore
  }

  // Recalculate the line starts after the edit.
  lines_from(self.lines, self.text, start_byte, start_utf16)
}

///|
pub impl Hash for Lines with fn hash_combine(self, hasher) {
  hasher.combine(self.text)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lines with Hash::{hash, hash_combine}

///|
/// Create a line vector.
fn compute_lines(text : String) -> Array[Line] {
  let lines = [{ byte_idx: 0, utf16_idx: 0, }]
  lines_from(lines, text, 0, 0)
  lines
}

///|
/// Push the starts of all lines that begin after the given offset (which must
/// be a char boundary) to `out`.
fn lines_from(
  out : Array[Line],
  text : String,
  byte_offset : Int,
  utf16_offset : Int,
) -> Unit {
  let mut b = byte_offset
  let mut u = utf16_offset
  while u < text.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(text, u)
    b += utf8_char_len(c)
    u = next
    if is_newline(Int::unsafe_to_char(c)) {
      if c == '\r' && u < text.length() && text.code_unit_at(u) == '\n' {
        b += 1
        u += 1
      }
      out.push({ byte_idx: b, utf16_idx: u, })
    }
  }
}

///|
/// The UTF-8 length of a scalar value.
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
/// Whether `i` is a char boundary of the UTF-8 encoded `bytes`.
fn is_char_boundary(bytes : Bytes, i : Int) -> Bool {
  i == 0 ||
  i == bytes.length() ||
  (i > 0 && i < bytes.length() && (bytes[i].to_int() & 0xC0) != 0x80)
}
