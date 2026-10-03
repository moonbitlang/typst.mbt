// Port of `hayro-jbig2/src/reader.rs`.

///|
/// A reader for reading bits and bytes from a byte stream.
///
/// (A mutable object: upstream's `&mut Reader` borrows become shared
/// references; `clone` copies it explicitly.)
priv struct Reader {
  /// The underlying data.
  data : BytesView
  /// The position in bits.
  mut cur_pos : Int
}

///|
fn Reader::new(data : BytesView) -> Reader {
  { data, cur_pos: 0, }
}

///|
fn Reader::clone(self : Reader) -> Reader {
  { data: self.data, cur_pos: self.cur_pos, }
}

///|
fn Reader::align(self : Reader) -> Unit {
  let bit_pos = self.bit_pos()
  if bit_pos % 8 != 0 {
    self.cur_pos += 8 - bit_pos
  }
}

///|
fn Reader::at_end(self : Reader) -> Bool {
  self.byte_pos() >= self.data.length()
}

///|
fn Reader::tail(self : Reader) -> BytesView? {
  let pos = self.byte_pos()
  if pos > self.data.length() {
    None
  } else {
    Some(self.data[pos:])
  }
}

///|
/// Read the given number of bytes.
///
/// Assumes that the reader is currently byte-aligned.
///
/// (`len` is upstream's `usize`; negative values stand for lengths that
/// don't fit into the data, e.g. negative `i32`s cast to `usize`.)
fn Reader::read_bytes(self : Reader, len : Int64) -> BytesView? {
  guard self.peek_bytes(len) is Some(bytes) else { return None }
  self.cur_pos += bytes.length() * 8
  Some(bytes)
}

///|
/// Read a single byte.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::read_byte(self : Reader) -> Byte? {
  guard self.peek_byte() is Some(byte) else { return None }
  self.cur_pos += 8
  Some(byte)
}

///|
/// Read a single byte, returning `None` if it's zero.
fn Reader::read_nonzero_byte(self : Reader) -> Byte? {
  guard self.read_byte() is Some(byte) else { return None }
  if byte == 0 {
    None
  } else {
    Some(byte)
  }
}

///|
/// Skip the given number of bytes.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::skip_bytes(self : Reader, len : Int64) -> Unit? {
  self.read_bytes(len).map(_ => ())
}

///|
/// Peek the given number of bytes.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::peek_bytes(self : Reader, len : Int64) -> BytesView? {
  let start = self.byte_pos()
  if len < 0 || start.to_int64() + len > self.data.length().to_int64() {
    return None
  }
  Some(self.data[start:start + len.to_int()])
}

///|
/// Peek the next byte.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::peek_byte(self : Reader) -> Byte? {
  let pos = self.byte_pos()
  if pos < self.data.length() {
    Some(self.data[pos])
  } else {
    None
  }
}

///|
/// Read an u16 number.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::read_u16(self : Reader) -> UInt? {
  guard self.read_bytes(2) is Some(b) else { return None }
  Some((b[0].to_uint() << 8) | b[1].to_uint())
}

///|
/// Read an u32 number.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::read_u32(self : Reader) -> UInt? {
  guard self.read_bytes(4) is Some(b) else { return None }
  Some(
    (b[0].to_uint() << 24) |
    (b[1].to_uint() << 16) |
    (b[2].to_uint() << 8) |
    b[3].to_uint(),
  )
}

///|
/// Read an i32 number.
///
/// Assumes that the reader is currently byte-aligned.
fn Reader::read_i32(self : Reader) -> Int? {
  self.read_u32().map(v => v.reinterpret_as_int())
}

///|
fn Reader::read_bit(self : Reader) -> Int? {
  guard self.cur_byte() is Some(byte) else { return None }
  let shift = 7 - self.bit_pos()
  self.cur_pos += 1
  Some((byte.to_int() >> shift) & 1)
}

///|
fn Reader::read_bits(self : Reader, count : Int) -> UInt? {
  let mut value = 0U
  let mut remaining = count
  while remaining > 0 {
    let bit_offset = self.bit_pos()
    guard self.cur_byte() is Some(byte) else { return None }
    let byte = byte.to_uint()
    let available = 8 - bit_offset
    let take = if remaining < available { remaining } else { available }
    let shift = available - take
    let mask = (1U << take) - 1
    let bits = (byte >> shift) & mask
    // (`take` is at most 8; a shift by 32 can't happen.)
    value = (value << take) | bits
    self.cur_pos += take
    remaining -= take
  }
  Some(value)
}

///|
fn Reader::byte_pos(self : Reader) -> Int {
  self.cur_pos >> 3
}

///|
fn Reader::cur_byte(self : Reader) -> Byte? {
  self.peek_byte()
}

///|
fn Reader::bit_pos(self : Reader) -> Int {
  self.cur_pos & 7
}
