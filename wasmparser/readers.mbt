// Port of wasmparser 0.228.0 `src/readers.rs`.

///|
/// A trait implemented for items that can be decoded directly from a
/// `BinaryReader`, or that which can be parsed from the WebAssembly binary
/// format.
pub(open) trait FromReader {
  /// Attempts to read `Self` from the provided binary reader, returning an
  /// error if it is unable to do so.
  fn from_reader(BinaryReader) -> Self raise BinaryReaderError
}

///|
pub impl FromReader for Bool with fn from_reader(reader) {
  match reader.read_u8() {
    0 => false
    1 => true
    _ =>
      raise BinaryReaderError::new(
        "invalid boolean value",
        reader.original_position() - 1,
      )
  }
}

///|
pub impl FromReader for UInt with fn from_reader(reader) {
  reader.read_var_u32()
}

///|
pub impl FromReader for String with fn from_reader(reader) {
  reader.read_string()
}

///|
/// Reads a value of type `T` from this binary reader, advancing the
/// internal position in this reader forward as data is read.
pub fn[T : FromReader] BinaryReader::read(
  self : BinaryReader,
) -> T raise BinaryReaderError {
  T::from_reader(self)
}

///|
/// A generic structure for reading a section of a WebAssembly binary which has
/// a limited number of items within it.
///
/// Many WebAssembly sections are a count of items followed by that many items.
/// This helper structure can be used to parse these sections and provides
/// an iteration-based API for reading the contents.
///
/// Iterating does not consume the section: `into_iter` starts from a copy of
/// the reader (upstream's `Clone`).
pub struct SectionLimited[T] {
  priv reader : BinaryReader
  priv count : UInt
}

///|
/// Creates a new section reader from the provided contents.
///
/// # Errors
///
/// Returns an error if a 32-bit count couldn't be read from the `data`.
pub fn[T] SectionLimited::new(
  reader : BinaryReader,
) -> SectionLimited[T] raise BinaryReaderError {
  let count = reader.read_var_u32()
  { reader, count, }
}

///|
/// Returns the count of total items within this section.
pub fn[T] SectionLimited::count(self : SectionLimited[T]) -> UInt {
  self.count
}

///|
/// Returns whether the original byte offset of this section.
pub fn[T] SectionLimited::original_position(self : SectionLimited[T]) -> Int {
  self.reader.original_position()
}

///|
/// Returns the range, as byte offsets, of this section within the original
/// wasm binary.
pub fn[T] SectionLimited::range(self : SectionLimited[T]) -> Range {
  self.reader.range()
}

///|
/// `Clone`.
pub fn[T] SectionLimited::clone(self : SectionLimited[T]) -> SectionLimited[T] {
  { reader: self.reader.clone(), count: self.count, }
}

///|
/// An iterator over the items of a [`SectionLimited`] (upstream
/// `SectionLimitedIntoIter`). `next` returns `None` at the end, and reports
/// trailing data at the end of the section as an error.
pub struct SectionLimitedIntoIter[T] {
  priv section : SectionLimited[T]
  priv mut remaining : UInt
  priv mut end : Bool
}

///|
/// `IntoIterator::into_iter` (from a copy of the section's reader).
pub fn[T] SectionLimited::into_iter(
  self : SectionLimited[T],
) -> SectionLimitedIntoIter[T] {
  { remaining: self.count, section: self.clone(), end: false, }
}

///|
/// Returns the current byte offset of the section within this iterator.
pub fn[T] SectionLimitedIntoIter::original_position(
  self : SectionLimitedIntoIter[T],
) -> Int {
  self.section.reader.original_position()
}

///|
pub fn[T : FromReader] SectionLimitedIntoIter::next(
  self : SectionLimitedIntoIter[T],
) -> T? raise BinaryReaderError {
  if self.end {
    return None
  }
  if self.remaining == 0 {
    self.end = true
    if self.section.reader.eof() {
      return None
    }
    raise BinaryReaderError::new(
      "section size mismatch: unexpected data at the end of the section",
      self.section.reader.original_position(),
    )
  }
  self.remaining -= 1
  let result = T::from_reader(self.section.reader) catch {
    e => {
      self.end = true
      raise e
    }
  }
  Some(result)
}

///|
/// `SectionLimitedIntoIterWithOffsets::next`: the item along with its offset.
pub fn[T : FromReader] SectionLimitedIntoIter::next_with_offset(
  self : SectionLimitedIntoIter[T],
) -> (Int, T)? raise BinaryReaderError {
  let pos = self.section.reader.original_position()
  match self.next() {
    Some(item) => Some((pos, item))
    None => None
  }
}

///|
/// Returns the number of items left (`size_hint`).
pub fn[T] SectionLimitedIntoIter::remaining(
  self : SectionLimitedIntoIter[T],
) -> UInt {
  self.remaining
}

///|
/// Reads all items (stopping at the first error).
pub fn[T : FromReader] SectionLimited::collect(
  self : SectionLimited[T],
) -> Array[T] raise BinaryReaderError {
  let iter = self.into_iter()
  let out = []
  while iter.next() is Some(item) {
    out.push(item)
  }
  out
}
