// Port of `hayro-jpeg2000/src/reader.rs`: combined byte and bit reader
// utilities.

///|
priv struct BitReader {
  data : BytesView
  /// The position in bits (upstream `usize`, 64 bits).
  mut cur_pos : Int64
}

///|
fn BitReader::new(data : BytesView) -> BitReader {
  { data, cur_pos: 0L, }
}

///|
fn BitReader::clone(self : BitReader) -> BitReader {
  { data: self.data, cur_pos: self.cur_pos, }
}

///|
fn BitReader::align(self : BitReader) -> Unit {
  let bit_pos = self.bit_pos()
  if bit_pos % 8 != 0 {
    self.cur_pos += (8 - bit_pos).to_int64()
  }
}

///|
fn BitReader::at_end(self : BitReader) -> Bool {
  self.byte_pos() >= self.data.length()
}

///|
fn BitReader::jump_to_end(self : BitReader) -> Unit {
  self.cur_pos = self.data.length().to_int64() * 8L
}

///|
fn BitReader::tail(self : BitReader) -> BytesView? {
  let start = self.byte_pos()
  if start > self.data.length() {
    None
  } else {
    Some(self.data[start:])
  }
}

///|
fn BitReader::offset(self : BitReader) -> Int {
  self.byte_pos()
}

///|
fn BitReader::read_bytes(self : BitReader, len : Int) -> BytesView? {
  guard self.peek_bytes(len) is Some(bytes) else { return None }
  self.cur_pos += len.to_int64() * 8L
  Some(bytes)
}

///|
fn BitReader::read_byte(self : BitReader) -> Int? {
  guard self.peek_byte() is Some(byte) else { return None }
  self.cur_pos += 8L
  Some(byte)
}

///|
fn BitReader::skip_bytes(self : BitReader, len : Int) -> Unit? {
  self.read_bytes(len).map(_ => ())
}

///|
fn BitReader::peek_bytes(self : BitReader, len : Int) -> BytesView? {
  let start = self.byte_pos()
  // `start.checked_add(len)` cannot overflow for the lengths we read.
  let end = start.to_int64() + len.to_int64()
  if len < 0 || end > self.data.length().to_int64() {
    return None
  }
  Some(self.data[start:end.to_int()])
}

///|
fn BitReader::peek_byte(self : BitReader) -> Int? {
  let pos = self.byte_pos()
  if pos < self.data.length() {
    Some(self.data[pos].to_int())
  } else {
    None
  }
}

///|
fn BitReader::read_u16(self : BitReader) -> Int? {
  guard self.read_bytes(2) is Some(bytes) else { return None }
  Some((bytes[0].to_int() << 8) | bytes[1].to_int())
}

///|
fn BitReader::read_u32(self : BitReader) -> UInt? {
  guard self.read_bytes(4) is Some(bytes) else { return None }
  Some(
    (bytes[0].to_uint() << 24) |
    (bytes[1].to_uint() << 16) |
    (bytes[2].to_uint() << 8) |
    bytes[3].to_uint(),
  )
}

///|
fn BitReader::read_u64(self : BitReader) -> UInt64? {
  guard self.read_bytes(8) is Some(bytes) else { return None }
  let mut v = 0UL
  for i in 0..<8 {
    v = (v << 8) | bytes[i].to_uint64()
  }
  Some(v)
}

///|
fn BitReader::read_bit(self : BitReader) -> UInt? {
  let byte_pos = self.byte_pos()
  if byte_pos >= self.data.length() {
    return None
  }
  let byte = self.data[byte_pos].to_uint()
  let shift = 7 - self.bit_pos()
  self.cur_pos += 1L
  Some((byte >> shift) & 1)
}

///|
fn BitReader::byte_pos(self : BitReader) -> Int {
  (self.cur_pos / 8L).to_int()
}

///|
fn BitReader::bit_pos(self : BitReader) -> Int {
  (self.cur_pos % 8L).to_int()
}

///|
/// Like the normal `read_bits` method, but accounts for stuffing bits
/// in addition.
fn BitReader::read_bits_with_stuffing(
  self : BitReader,
  bit_size : Int,
) -> UInt? {
  let mut bit = 0U
  for _ in 0..<bit_size {
    let needs_stuff_bit = self.needs_to_read_stuff_bit()
    guard self.read_bit() is Some(b) else { return None }
    bit = (bit << 1) | b
    if needs_stuff_bit {
      guard self.read_stuff_bit() is Some(_) else { return None }
    }
  }
  Some(bit)
}

///|
fn BitReader::needs_to_read_stuff_bit(self : BitReader) -> Bool {
  // B.10.1: "If the value of the byte is 0xFF, the next byte includes an extra zero bit
  // stuffed into the MSB."
  self.bit_pos() == 7 && self.data[self.byte_pos()] == 0xff
}

///|
fn BitReader::read_stuff_bit(self : BitReader) -> Unit? {
  guard self.read_bit() is Some(stuff_bit) else { return None }
  if stuff_bit != 0 {
    return None
  }
  Some(())
}

///|
fn BitReader::peak_bits_with_stuffing(
  self : BitReader,
  bit_size : Int,
) -> UInt? {
  let pos = self.cur_pos
  let res = self.read_bits_with_stuffing(bit_size)
  self.cur_pos = pos
  res
}

///|
fn BitReader::read_marker(self : BitReader) -> Int raise DecodeError {
  guard self.peek_byte() is Some(b) else { raise Marker(Invalid) }
  if b != 0xFF {
    raise Marker(Invalid)
  }
  self.read_byte() |> ignore
  guard self.read_byte() is Some(m) else { raise Marker(Invalid) }
  m
}

///|
fn BitReader::peek_marker(self : BitReader) -> Int? {
  let pos = self.cur_pos
  let res = self.read_marker() catch { _ => -1 }
  self.cur_pos = pos
  if res < 0 {
    None
  } else {
    Some(res)
  }
}
