// Port of `hayro-syntax/src/byte_reader.rs`: a byte reader.

///|
/// A reader for reading bytes and PDF objects.
pub struct Reader {
  /// The underlying data of the reader.
  data : BytesView
  /// The current byte-offset.
  mut offset : Int
}

///|
/// Create a new reader.
pub fn Reader::new(data : BytesView) -> Reader {
  { data, offset: 0, }
}

///|
/// Create a new reader at the given offset.
pub fn Reader::new_with(data : BytesView, offset : Int) -> Reader {
  { data, offset, }
}

///|
/// Clone the reader (the data is shared, the offset is copied).
pub fn Reader::clone(self : Reader) -> Reader {
  { data: self.data, offset: self.offset, }
}

///|
/// Returns `true` if the reader has reached the end of the data.
pub fn Reader::at_end(self : Reader) -> Bool {
  self.offset >= self.data.length()
}

///|
/// Moves the reader offset to the end of the data.
pub fn Reader::jump_to_end(self : Reader) -> Unit {
  self.offset = self.data.length()
}

///|
/// Moves the reader to the specified offset.
pub fn Reader::jump(self : Reader, offset : Int) -> Unit {
  self.offset = offset
}

///|
/// Returns the remaining data from the current offset to the end.
pub fn Reader::tail(self : Reader) -> BytesView? {
  if self.offset >= 0 && self.offset <= self.data.length() {
    Some(self.data[self.offset:])
  } else {
    None
  }
}

///|
/// Returns the total length of the underlying data.
pub fn Reader::len(self : Reader) -> Int {
  self.data.length()
}

///|
/// Returns `true` if the underlying data is empty.
pub fn Reader::is_empty(self : Reader) -> Bool {
  self.data.length() == 0
}

///|
/// Returns a slice of the data for the specified range.
pub fn Reader::range(self : Reader, start : Int, end : Int) -> BytesView? {
  if start >= 0 && start <= end && end <= self.data.length() {
    Some(self.data[start:end])
  } else {
    None
  }
}

///|
/// Returns the current offset of the reader.
pub fn Reader::offset(self : Reader) -> Int {
  self.offset
}

///|
/// Reads the specified number of bytes and advances the offset.
pub fn Reader::read_bytes(self : Reader, len : Int) -> BytesView? {
  guard self.peek_bytes(len) is Some(v) else { return None }
  self.offset += len
  Some(v)
}

///|
/// Reads a single byte and advances the offset.
pub fn Reader::read_byte(self : Reader) -> Byte? {
  guard self.peek_byte() is Some(v) else { return None }
  self.offset += 1
  Some(v)
}

///|
/// Skips the specified number of bytes by advancing the offset.
pub fn Reader::skip_bytes(self : Reader, len : Int) -> Unit? {
  self.read_bytes(len).map(_ => ())
}

///|
/// Peeks the specified number of bytes.
pub fn Reader::peek_bytes(self : Reader, len : Int) -> BytesView? {
  if len < 0 {
    return None
  }
  let end = self.offset.to_int64() + len.to_int64()
  if self.offset >= 0 && end <= self.data.length().to_int64() {
    Some(self.data[self.offset:end.to_int()])
  } else {
    None
  }
}

///|
/// Peeks a single byte.
pub fn Reader::peek_byte(self : Reader) -> Byte? {
  if self.offset >= 0 && self.offset < self.data.length() {
    Some(self.data[self.offset])
  } else {
    None
  }
}

///|
/// Eat the next byte if it satisfies the condition.
pub fn Reader::eat(self : Reader, f : (Byte) -> Bool) -> Byte? {
  guard self.peek_byte() is Some(val) else { return None }
  if f(val) {
    self.forward()
    Some(val)
  } else {
    None
  }
}

///|
/// Advances the offset by one byte.
pub fn Reader::forward(self : Reader) -> Unit {
  self.offset += 1
}

///|
/// Advances the offset by one byte if the current byte satisfies the predicate.
pub fn Reader::forward_if(self : Reader, f : (Byte) -> Bool) -> Unit? {
  guard self.peek_byte() is Some(b) else { return None }
  if f(b) {
    self.forward()
    Some(())
  } else {
    None
  }
}

///|
/// Advances the offset while bytes satisfy the predicate, at least one time.
pub fn Reader::forward_while_1(self : Reader, f : (Byte) -> Bool) -> Unit? {
  guard self.eat(f) is Some(_) else { return None }
  self.forward_while(f)
  Some(())
}

///|
/// Advances the offset if the next bytes match the specified tag.
pub fn Reader::forward_tag(self : Reader, tag : Bytes) -> Unit? {
  guard self.peek_tag(tag) is Some(_) else { return None }
  self.offset += tag.length()
  Some(())
}

///|
/// Advances the offset while the given byte satisfies the predicate.
pub fn Reader::forward_while(self : Reader, f : (Byte) -> Bool) -> Unit {
  while self.peek_byte() is Some(b) {
    if f(b) {
      self.forward()
    } else {
      break
    }
  }
}

///|
/// Checks if the next bytes match the specified tag.
pub fn Reader::peek_tag(self : Reader, tag : Bytes) -> Unit? {
  let mut pos = self.offset
  for b in tag {
    if pos >= 0 && pos < self.data.length() && self.data[pos] == b {
      pos += 1
    } else {
      return None
    }
  }
  Some(())
}

///|
/// Read a u16 integer (in big endian order).
pub fn Reader::read_u16(self : Reader) -> Int? {
  guard self.read_bytes(2) is Some(bytes) else { return None }
  Some((bytes[0].to_int() << 8) | bytes[1].to_int())
}

///|
/// Read a u32 integer (in big endian order).
pub fn Reader::read_u32(self : Reader) -> UInt? {
  guard self.read_bytes(4) is Some(bytes) else { return None }
  Some(
    (bytes[0].to_uint() << 24) |
    (bytes[1].to_uint() << 16) |
    (bytes[2].to_uint() << 8) |
    bytes[3].to_uint(),
  )
}
