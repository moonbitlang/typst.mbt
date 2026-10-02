// Port of the `flate::fallback` module of
// `hayro-syntax/src/filter/lzw_flate.rs`, itself ported from pdf.js'
// `flate_stream.js`: a lenient flate decoder that returns what it could
// decode.

///|
fn flate_fallback_decode(data : BytesView) -> Bytes? {
  if data.length() >= 2 {
    let cmf = data[0].to_int()
    let flg = data[1].to_int()
    if (cmf & 0x0f) == 0x08 && ((cmf << 8) | flg) % 31 == 0 && (flg & 0x20) == 0 {
      let stream = FlateStream::new(data[2:])
      return stream.decode()
    }
  }
  let stream = FlateStream::new(data)
  stream.decode()
}

///|
priv struct FlateStream {
  data : BytesView
  mut pos : Int
  mut code_buf : UInt
  mut code_size : Int
  output : Array[Byte]
  mut eof : Bool
}

///|
fn FlateStream::new(data : BytesView) -> FlateStream {
  { data, pos: 0, code_buf: 0, code_size: 0, output: [], eof: false, }
}

///|
fn FlateStream::decode(self : FlateStream) -> Bytes? {
  while !self.eof && self.pos < self.data.length() {
    self.read_block()
  }
  Some(Bytes::from_array(self.output[:]))
}

///|
fn FlateStream::get_byte(self : FlateStream) -> Byte? {
  if self.pos >= self.data.length() {
    None
  } else {
    let byte = self.data[self.pos]
    self.pos += 1
    Some(byte)
  }
}

///|
fn FlateStream::peek_byte(self : FlateStream) -> Byte? {
  if self.pos >= self.data.length() {
    None
  } else {
    Some(self.data[self.pos])
  }
}

///|
fn FlateStream::get_bytes(self : FlateStream, n : Int) -> BytesView {
  let end = @cmp.minimum(self.pos + n, self.data.length())
  let bytes = self.data[self.pos:end]
  self.pos = end
  bytes
}

///|
fn FlateStream::get_bits(self : FlateStream, bits : Int) -> UInt? {
  while self.code_size < bits {
    guard self.get_byte() is Some(b) else { return None }
    self.code_buf = self.code_buf | (b.to_uint() << self.code_size)
    self.code_size += 8
  }
  let result = self.code_buf & ((1U << bits) - 1)
  self.code_buf = self.code_buf >> bits
  self.code_size -= bits
  Some(result)
}

///|
fn FlateStream::get_code(self : FlateStream, table : HuffmanTable) -> Int? {
  let codes = table.codes
  let max_len = table.max_len
  while self.code_size < max_len {
    if self.get_byte() is Some(b) {
      self.code_buf = self.code_buf | (b.to_uint() << self.code_size)
      self.code_size += 8
    } else {
      // Premature end of stream
      break
    }
  }
  let index = (self.code_buf & ((1U << max_len) - 1)).reinterpret_as_int()
  guard index < codes.length() else { return None }
  let code = codes[index]
  let code_len = (code >> 16).reinterpret_as_int() & 0xff
  let code_val = (code & 0xffff).reinterpret_as_int()
  if code_len < 1 || self.code_size < code_len {
    return None
  }
  self.code_buf = self.code_buf >> code_len
  self.code_size -= code_len
  Some(code_val)
}

///|
fn FlateStream::read_block(self : FlateStream) -> Unit {
  // Read block header
  let hdr = match self.get_bits(3) {
    Some(h) => h
    None => {
      // bad block header in flate stream
      self.eof = true
      return
    }
  }
  if (hdr & 1) != 0 {
    self.eof = true
  }
  let hdr = hdr >> 1
  match hdr {
    0 => self.read_uncompressed_block()
    1 => self.read_compressed_block(true)
    2 => self.read_compressed_block(false)
    _ =>
      // unknown block type in flate stream
      self.eof = true
  }
}

///|
fn FlateStream::read_uncompressed_block(self : FlateStream) -> Unit {
  // Skip any remaining bits in current byte
  self.code_buf = 0
  self.code_size = 0
  let bytes = []
  for _ in 0..<4 {
    match self.get_byte() {
      Some(b) => bytes.push(b.to_int())
      None => {
        // bad block header in flate stream
        self.eof = true
        return
      }
    }
  }
  let block_len = bytes[0] | (bytes[1] << 8)
  let check = bytes[2] | (bytes[3] << 8)
  if check != (block_len ^ 0xffff) && (block_len != 0 || check != 0) {
    // Ignoring error for bad "empty" block
    // bad uncompressed block length in flate stream
    ()
  }
  if block_len == 0 {
    if self.peek_byte() is None {
      self.eof = true
    }
  } else {
    let block = self.get_bytes(block_len)
    for b in block {
      self.output.push(b)
    }
    if block.length() < block_len {
      self.eof = true
    }
  }
}

///|
fn FlateStream::read_compressed_block(self : FlateStream, fixed : Bool) -> Unit {
  let (lit_code_table, dist_code_table) = if fixed {
    (fixed_lit_table, fixed_dist_table)
  } else {
    match self.read_dynamic_tables() {
      Some(tables) => tables
      None => {
        self.eof = true
        return
      }
    }
  }
  while true {
    let code1 = match self.get_code(lit_code_table) {
      Some(c) => c
      None => {
        self.eof = true
        return
      }
    }
    if code1 < 256 {
      self.output.push(code1.to_byte())
    } else if code1 == 256 {
      return
    } else {
      let code1 = code1 - 257
      let length_info = if code1 < length_decode.length() {
        length_decode[code1]
      } else {
        0
      }
      let extra_bits = length_info >> 16
      let mut length = length_info & 0xffff
      if extra_bits > 0 {
        if self.get_bits(extra_bits) is Some(extra) {
          length += extra.reinterpret_as_int()
        } else {
          self.eof = true
          return
        }
      }
      let dist_code = match self.get_code(dist_code_table) {
        Some(c) => c
        None => {
          self.eof = true
          return
        }
      }
      guard dist_code < dist_decode.length() else {
        // invalid distance code in flate stream
        self.eof = true
        return
      }
      let dist_info = dist_decode[dist_code]
      let extra_bits = dist_info >> 16
      let mut distance = dist_info & 0xffff
      if extra_bits > 0 {
        if self.get_bits(extra_bits) is Some(extra) {
          distance += extra.reinterpret_as_int()
        } else {
          self.eof = true
          return
        }
      }

      // Copy from previous output
      let start_valid = distance <= self.output.length()
      for _ in 0..<length {
        if start_valid {
          let byte = self.output[self.output.length() - distance]
          self.output.push(byte)
        }
      }
    }
  }
}

///|
fn FlateStream::read_dynamic_tables(
  self : FlateStream,
) -> (HuffmanTable, HuffmanTable)? {
  guard self.get_bits(5) is Some(n) else { return None }
  let num_lit_codes = n.reinterpret_as_int() + 257
  guard self.get_bits(5) is Some(n) else { return None }
  let num_dist_codes = n.reinterpret_as_int() + 1
  guard self.get_bits(4) is Some(n) else { return None }
  let num_code_len_codes = n.reinterpret_as_int() + 4

  // Build code length code table
  let code_len_code_lengths = FixedArray::make(19, 0)
  for i in 0..<num_code_len_codes {
    guard self.get_bits(3) is Some(b) else { return None }
    code_len_code_lengths[code_len_code_map[i]] = b.reinterpret_as_int()
  }
  let code_len_table = generate_huffman_table(code_len_code_lengths[:])

  // Read code lengths
  let total_codes = num_lit_codes + num_dist_codes
  let code_lengths = FixedArray::make(total_codes, 0)
  let mut i = 0
  while i < total_codes {
    guard self.get_code(code_len_table) is Some(code) else { return None }
    match code {
      0..=15 => {
        code_lengths[i] = code
        i += 1
      }
      16 => {
        // Repeat previous
        guard self.get_bits(2) is Some(b) else { return None }
        let repeat_count = b.reinterpret_as_int() + 3
        let prev = if i > 0 { code_lengths[i - 1] } else { 0 }
        for _ in 0..<repeat_count {
          if i < total_codes {
            code_lengths[i] = prev
            i += 1
          }
        }
      }
      17 => {
        // Repeat zero 3-10 times
        guard self.get_bits(3) is Some(b) else { return None }
        let repeat_count = b.reinterpret_as_int() + 3
        for _ in 0..<repeat_count {
          if i < total_codes {
            code_lengths[i] = 0
            i += 1
          }
        }
      }
      18 => {
        // Repeat zero 11-138 times
        guard self.get_bits(7) is Some(b) else { return None }
        let repeat_count = b.reinterpret_as_int() + 11
        for _ in 0..<repeat_count {
          if i < total_codes {
            code_lengths[i] = 0
            i += 1
          }
        }
      }
      _ => return None
    }
  }
  let lit_table = generate_huffman_table(code_lengths[:num_lit_codes])
  let dist_table = generate_huffman_table(code_lengths[num_lit_codes:])
  Some((lit_table, dist_table))
}

///|
priv struct HuffmanTable {
  codes : FixedArray[UInt]
  max_len : Int
}

///|
fn generate_huffman_table(lengths : ArrayView[Int]) -> HuffmanTable {
  // Find max code length
  let mut max_len = 0
  for l in lengths {
    if l > max_len {
      max_len = l
    }
  }
  if max_len == 0 {
    return { codes: FixedArray::make(1, 0), max_len: 1, }
  }

  // Build the table
  let size = 1 << max_len
  let codes = FixedArray::make(size, 0U)
  let mut code = 0U
  for len in 1..<=max_len {
    for val, length in lengths {
      if length == len {
        // Bit-reverse the code
        let mut code2 = 0U
        let mut t = code
        for _ in 0..<len {
          code2 = (code2 << 1) | (t & 1)
          t = t >> 1
        }

        // Fill the table entries
        let skip = 1 << len
        let mut i = code2.reinterpret_as_int()
        while i < size {
          codes[i] = (len.reinterpret_as_uint() << 16) |
            val.reinterpret_as_uint()
          i += skip
        }
        code += 1
      }
    }
    code = code << 1
  }
  { codes, max_len, }
}

///|
/// The fixed literal/length table (pdf.js' `fixedLitCodeTab`, which is the
/// table generated from the fixed code lengths).
let fixed_lit_table : HuffmanTable = {
  let lengths = Array::makei(288, i => {
    if i < 144 {
      8
    } else if i < 256 {
      9
    } else if i < 280 {
      7
    } else {
      8
    }
  })
  generate_huffman_table(lengths[:])
}

///|
/// The fixed distance table (pdf.js' `fixedDistCodeTab`).
let fixed_dist_table : HuffmanTable = generate_huffman_table(
  Array::make(30, 5)[:],
)

///|
let code_len_code_map : FixedArray[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
let length_decode : FixedArray[Int] = [
  0x00003, 0x00004, 0x00005, 0x00006, 0x00007, 0x00008, 0x00009, 0x0000a, 0x1000b,
  0x1000d, 0x1000f, 0x10011, 0x20013, 0x20017, 0x2001b, 0x2001f, 0x30023, 0x3002b,
  0x30033, 0x3003b, 0x40043, 0x40053, 0x40063, 0x40073, 0x50083, 0x500a3, 0x500c3,
  0x500e3, 0x00102,
]

///|
let dist_decode : FixedArray[Int] = [
  0x00001, 0x00002, 0x00003, 0x00004, 0x10005, 0x10007, 0x20009, 0x2000d, 0x30011,
  0x30019, 0x40021, 0x40031, 0x50041, 0x50061, 0x60081, 0x600c1, 0x70101, 0x70181,
  0x80201, 0x80301, 0x90401, 0x90601, 0xa0801, 0xa0c01, 0xb1001, 0xb1801, 0xc2001,
  0xc3001, 0xd4001, 0xd6001,
]
