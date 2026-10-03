// Port of `hayro-syntax/src/bit_reader.rs`: a simple bit reader and writer.

///|
/// A bit reader.
pub struct BitReader {
  /// The underlying bytes of the bit reader.
  data : BytesView
  priv mut cur_pos : Int
}

///|
/// Create a new bit reader.
pub fn BitReader::new(data : BytesView) -> BitReader {
  BitReader::new_with(data, 0)
}

///|
/// Create a new bit reader, and start at a specific bit offset.
pub fn BitReader::new_with(data : BytesView, cur_pos : Int) -> BitReader {
  { data, cur_pos, }
}

///|
pub fn BitReader::clone(self : BitReader) -> BitReader {
  { data: self.data, cur_pos: self.cur_pos, }
}

///|
/// Align the reader to the next byte boundary.
pub fn BitReader::align(self : BitReader) -> Unit {
  let bit_pos = self.bit_pos()
  if bit_pos % 8 != 0 {
    self.cur_pos += 8 - bit_pos
  }
}

///|
/// Read the given number of bits from the byte stream.
///
/// Returns `None` if `bit_size` > 32.
pub fn BitReader::read(self : BitReader, bit_size : Int) -> UInt? {
  if bit_size < 1 || bit_size > 32 {
    return None
  }
  let byte_pos = self.byte_pos()
  if byte_pos >= self.data.length() {
    return None
  }
  if bit_size == 8 {
    let item = self.data[byte_pos].to_uint()
    self.cur_pos += 8
    return Some(item)
  }
  let bit_pos = self.bit_pos()
  let end_byte_pos = (bit_pos + bit_size - 1) / 8
  let mut read : UInt64 = 0
  for i in 0..<8 {
    let byte : UInt64 = if i <= end_byte_pos {
      if byte_pos + i < self.data.length() {
        self.data[byte_pos + i].to_uint64()
      } else {
        return None
      }
    } else {
      0
    }
    read = read | (byte << (56 - 8 * i))
  }
  let item = (read >> (64 - bit_pos - bit_size)).to_uint() & bit_mask(bit_size)
  self.cur_pos += bit_size
  Some(item)
}

///|
/// Peak the given number of bits.
pub fn BitReader::peak(self : BitReader, bit_size : Int) -> UInt? {
  self.clone().read(bit_size)
}

///|
/// Whether the bit reader has read all bytes.
pub fn BitReader::at_end(self : BitReader) -> Bool {
  self.byte_pos() >= self.data.length()
}

///|
/// Get the current byte position.
pub fn BitReader::byte_pos(self : BitReader) -> Int {
  self.cur_pos / 8
}

///|
/// Get the current position within the byte.
pub fn BitReader::bit_pos(self : BitReader) -> Int {
  self.cur_pos % 8
}

///|
/// Get the current position in bits.
pub fn BitReader::cur_pos(self : BitReader) -> Int {
  self.cur_pos
}

///|
/// Get the tail (aligned to the current byte position) of the data.
pub fn BitReader::tail(self : BitReader) -> BytesView {
  self.data[self.byte_pos():]
}

///|
/// Get the full byte (aligned to the byte boundary) of the current position.
pub fn BitReader::cur_byte(self : BitReader) -> Byte? {
  if self.byte_pos() < self.data.length() {
    Some(self.data[self.byte_pos()])
  } else {
    None
  }
}

///|
/// Get the mask for the given bit size.
pub fn bit_mask(bit_size : Int) -> UInt {
  if bit_size <= 0 {
    0
  } else if bit_size <= 31 {
    (1U << bit_size) - 1
  } else {
    0xFFFFFFFFU
  }
}

///|
/// A bit writer over a buffer, starting at byte `base`.
pub struct BitWriter {
  priv data : FixedArray[Byte]
  priv base : Int
  priv mut cur_pos : Int
  priv bit_size : Int
}

///|
/// Create a new bit writer for a fixed bit size between 1 and 32
/// (inclusive), writing into `data` from bit `start_bit` on (which must be
/// byte aligned).
pub fn BitWriter::new(
  data : FixedArray[Byte],
  start_bit : Int,
  bit_size : Int,
) -> BitWriter {
  { data, base: start_bit / 8, cur_pos: 0, bit_size, }
}

///|
/// Return the number of written bits.
pub fn BitWriter::cur_pos(self : BitWriter) -> Int {
  self.cur_pos
}

///|
/// Align the writer to the next byte boundary.
pub fn BitWriter::align(self : BitWriter) -> Unit {
  let bit_pos = self.cur_pos % 8
  if bit_pos != 0 {
    self.cur_pos += 8 - bit_pos
  }
}

///|
/// Write the given number into the buffer.
pub fn BitWriter::write(self : BitWriter, val : UInt) -> Unit? {
  let bit_size = self.bit_size
  let mut bits_left = bit_size
  let value = val & bit_mask(bit_size)
  while bits_left > 0 {
    let already_advanced = bit_size - bits_left
    let absolute_pos = self.cur_pos + already_advanced
    let byte_pos = self.base + absolute_pos / 8
    let bit_pos = absolute_pos % 8
    let bits_in_byte = if 8 - bit_pos < bits_left {
      8 - bit_pos
    } else {
      bits_left
    }
    let shift = bits_left - bits_in_byte
    let chunk_mask = bit_mask(bits_in_byte)
    let chunk = ((value >> shift) & chunk_mask).reinterpret_as_int()
    let shift_in_byte = 8 - bits_in_byte - bit_pos
    if byte_pos >= self.data.length() {
      return None
    }
    let byte = self.data[byte_pos].to_int()
    let byte_mask = (chunk_mask.reinterpret_as_int() << shift_in_byte) & 0xff
    self.data[byte_pos] = ((byte & (byte_mask ^ 0xff)) |
    ((chunk << shift_in_byte) & byte_mask)).to_byte()
    bits_left -= bits_in_byte
  }
  self.cur_pos += bit_size
  Some(())
}

///|
/// Fill bytes with a repeated value when at a byte boundary.
pub fn BitWriter::fill_bytes(
  self : BitWriter,
  byte : Byte,
  count : Int,
) -> Unit? {
  // (upstream: `debug_assert_eq!(self.cur_pos % 8, 0)`)
  let start = self.base + self.cur_pos / 8
  let end = start + count
  if count < 0 || end > self.data.length() {
    return None
  }
  self.data.fill(byte, start~, end~)
  self.cur_pos += count * 8
  Some(())
}
