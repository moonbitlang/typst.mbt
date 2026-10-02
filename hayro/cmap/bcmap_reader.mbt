// Port of `hayro-cmap/src/bcmap/reader.rs`.

///|
priv struct BReader {
  data : BytesView
  mut byte_pos : Int
  mut bit_pos : Int
}

///|
fn BReader::new(data : BytesView) -> BReader {
  { data, byte_pos: 0, bit_pos: 0, }
}

///|
fn BReader::read_bit(self : BReader) -> Int? {
  guard self.byte_pos < self.data.length() else { return None }
  let byte = self.data[self.byte_pos].to_int()
  let bit = (byte >> (7 - self.bit_pos)) & 1
  self.bit_pos += 1
  if self.bit_pos == 8 {
    self.bit_pos = 0
    self.byte_pos += 1
  }
  Some(bit)
}

///|
fn BReader::read_u16(self : BReader) -> Int? {
  guard self.read_bytes(2) is Some(b) else { return None }
  Some((b[0].to_int() << 8) | b[1].to_int())
}

///|
fn BReader::read_u32(self : BReader) -> UInt? {
  guard self.read_bytes(4) is Some(b) else { return None }
  Some(
    (b[0].to_uint() << 24) |
    (b[1].to_uint() << 16) |
    (b[2].to_uint() << 8) |
    b[3].to_uint(),
  )
}

///|
fn BReader::read_u8(self : BReader) -> Int? {
  guard self.byte_pos < self.data.length() else { return None }
  let val = self.data[self.byte_pos].to_int()
  self.byte_pos += 1
  Some(val)
}

///|
fn BReader::read_n_bytes(self : BReader, n : Int) -> UInt? {
  match n {
    1 => self.read_u8().map(v => v.reinterpret_as_uint())
    2 => self.read_u16().map(v => v.reinterpret_as_uint())
    3 => {
      guard self.read_bytes(3) is Some(bytes) else { return None }
      Some(
        (bytes[0].to_uint() << 16) |
        (bytes[1].to_uint() << 8) |
        bytes[2].to_uint(),
      )
    }
    4 => self.read_u32()
    _ => None
  }
}

///|
fn BReader::read_bytes(self : BReader, n : Int) -> BytesView? {
  let end = self.byte_pos.to_int64() + n.to_int64()
  guard n >= 0 && end <= self.data.length().to_int64() else { return None }
  let bytes = self.data[self.byte_pos:end.to_int()]
  self.byte_pos = end.to_int()
  Some(bytes)
}

///|
fn BReader::position(self : BReader) -> Int {
  self.byte_pos
}

///|
fn BReader::at_end(self : BReader) -> Bool {
  self.byte_pos >= self.data.length()
}

///|
fn BReader::eat_until(self : BReader, f : (Byte) -> Bool) -> BytesView {
  let start = self.byte_pos
  while self.byte_pos < self.data.length() {
    if f(self.data[self.byte_pos]) {
      break
    }
    self.byte_pos += 1
  }
  self.data[start:self.byte_pos]
}
