// Port of `hayro-ccitt/src/bit_reader.rs`: bit-level reader for CCITT
// encoded data streams.

///|
priv struct BitReader {
  data : BytesView
  /// (upstream `usize`, 64 bits)
  mut bit_offset : Int64
}

///|
fn BitReader::new(data : BytesView) -> BitReader {
  { data, bit_offset: 0L, }
}

///|
fn BitReader::clone(self : BitReader) -> BitReader {
  { data: self.data, bit_offset: self.bit_offset, }
}

///|
fn BitReader::read_bit(self : BitReader) -> UInt raise DecodeError {
  let byte_pos = self.byte_pos()
  guard byte_pos < self.data.length() else { raise UnexpectedEof }
  let byte = self.data[byte_pos].to_uint()
  let shift = 7 - self.bit_pos()
  self.bit_offset += 1L
  (byte >> shift) & 1
}

///|
fn BitReader::read_bits(
  self : BitReader,
  num_bits : Int,
) -> UInt raise DecodeError {
  let mut result = 0U
  for i = num_bits - 1; i >= 0; i = i - 1 {
    result = result | (self.read_bit() << i)
  }
  result
}

///|
/// Peek the given number of bits (upstream `peak_bits`); `None` on EOF.
fn BitReader::peak_bits(self : BitReader, num_bits : Int) -> UInt? {
  Some(self.clone().read_bits(num_bits)) catch {
    _ => None
  }
}

///|
fn BitReader::align(self : BitReader) -> Unit {
  let bit_pos = self.bit_pos()
  if bit_pos % 8 != 0 {
    self.bit_offset += (8 - bit_pos).to_int64()
  }
}

///|
fn BitReader::at_end(self : BitReader) -> Bool {
  self.byte_pos() >= self.data.length()
}

///|
fn BitReader::byte_pos(self : BitReader) -> Int {
  (self.bit_offset >> 3).to_int()
}

///|
fn BitReader::bit_pos(self : BitReader) -> Int {
  (self.bit_offset & 7L).to_int()
}
