// Port of `zune-jpeg` (v0.5.15) `src/huffman.rs`: the Huffman tables needed
// during bitstream decoding.

///|
/// Determines how many bits of lookahead we have for our bitstream decoder.
const HUFF_LOOKAHEAD : Int = 9

///|
/// A struct which contains necessary tables for decoding a JPEG Huffman
/// encoded bitstream.
priv struct HuffmanTable {
  /// Largest code of length k (pre-shifted to 16 bits); element 0 unused.
  maxcode : FixedArray[Int]
  /// Offset for codes of length k.
  offset : FixedArray[Int]
  /// Lookup table for fast decoding: the bits above `HUFF_LOOKAHEAD` contain
  /// the code length, the lower 8 bits the symbol.
  lookup : FixedArray[Int]
  /// A table which can be used to decode small AC coefficients and do an
  /// equivalent of receive_extend (`i16` values).
  mut ac_lookup : FixedArray[Int]?
  /// Symbols in order of increasing code length.
  values : FixedArray[Int]
}

///|
fn HuffmanTable::new(
  codes : FixedArray[Int],
  values : FixedArray[Int],
  is_dc : Bool,
  is_progressive : Bool,
) -> HuffmanTable raise DecodeErrors {
  let too_long_code = (HUFF_LOOKAHEAD + 1) << HUFF_LOOKAHEAD
  let p = {
    maxcode: FixedArray::make(18, 0),
    offset: FixedArray::make(18, 0),
    lookup: FixedArray::make(1 << HUFF_LOOKAHEAD, too_long_code),
    values,
    ac_lookup: None,
  }
  p.make_derived_table(is_dc, is_progressive, codes)
  p
}

///|
/// Create a new Huffman table with values that aren't fixed (used by
/// `fill_default_mjpeg_tables`).
fn HuffmanTable::new_unfilled(
  codes : FixedArray[Int],
  values : Array[Int],
  is_dc : Bool,
  is_progressive : Bool,
) -> HuffmanTable raise DecodeErrors {
  let buf = FixedArray::make(256, 0)
  for i, v in values {
    buf[i] = v
  }
  HuffmanTable::new(codes, buf, is_dc, is_progressive)
}

///|
/// Compute derived values for a Huffman table.
///
/// This routine performs some validation checks on the table.
fn HuffmanTable::make_derived_table(
  self : HuffmanTable,
  is_dc : Bool,
  _is_progressive : Bool,
  bits : FixedArray[Int],
) -> Unit raise DecodeErrors {
  // build a list of code size
  let huff_size = FixedArray::make(257, 0)
  // Huffman code lengths (`u32`)
  let huff_code : FixedArray[UInt] = FixedArray::make(257, 0)
  // figure C.1 make table of Huffman code length for each symbol
  let mut p = 0
  for l in 1..<=16 {
    let mut i = bits[l]
    while i != 0 {
      huff_size[p] = l
      p += 1
      i -= 1
    }
  }
  huff_size[p] = 0
  let num_symbols = p
  // Generate the codes themselves
  // We also validate that the counts represent a legal Huffman code tree
  let mut code : UInt = 0
  let mut si = huff_size[0]
  p = 0
  while huff_size[p] != 0 {
    while huff_size[p] == si {
      huff_code[p] = code
      code += 1
      p += 1
    }
    // maximum code of length si, pre-shifted by 16-k bits
    self.maxcode[si] = (code << (16 - si)).reinterpret_as_int()
    // code is now 1 more than the last code used for code-length si; but
    // it must still fit in si bits, since no code is allowed to be all ones.
    if code.reinterpret_as_int() >= 1 << si {
      raise HuffmanDecode("Bad Huffman Table")
    }
    code = code << 1
    si += 1
  }

  // Figure F.15 generate decoding tables for bit-sequential decoding
  p = 0
  for l in 0..<=16 {
    if bits[l] == 0 {
      // -1 if no codes of this length
      self.maxcode[l] = -1
    } else {
      // offset[l]=codes[index of 1st symbol of code length l
      // minus minimum code of length l]
      self.offset[l] = p - huff_code[p].reinterpret_as_int()
      p += bits[l]
    }
  }
  self.offset[17] = 0
  // we ensure that decode terminates
  self.maxcode[17] = 0x000F_FFFF

  // Compute lookahead tables to speed up decoding.
  p = 0
  for l in 1..<=HUFF_LOOKAHEAD {
    for _ in 1..<=bits[l] {
      // Generate left justified code followed by all possible bit sequences
      let mut look_bits = huff_code[p].reinterpret_as_int() <<
        (HUFF_LOOKAHEAD - l)
      for _ in 0..<(1 << (HUFF_LOOKAHEAD - l)) {
        self.lookup[look_bits] = (l << HUFF_LOOKAHEAD) | self.values[p]
        look_bits += 1
      }
      p += 1
    }
  }
  // build an ac table that does an equivalent of decode and receive_extend
  if !is_dc {
    let fast = FixedArray::make(1 << HUFF_LOOKAHEAD, 255)
    // Iterate over number of symbols
    for i in 0..<num_symbols {
      // get code size for an item
      let s = huff_size[i]
      if s <= HUFF_LOOKAHEAD {
        // if it's lower than what we need for our lookup table create the table
        let c = (huff_code[i] << (HUFF_LOOKAHEAD - s)).reinterpret_as_int()
        let m = 1 << (HUFF_LOOKAHEAD - s)
        for j in 0..<m {
          fast[c + j] = i
        }
      }
    }
    // build a table that decodes both magnitude and value of small ACs in
    // one go.
    let fast_ac = FixedArray::make(1 << HUFF_LOOKAHEAD, 0)
    for i in 0..<(1 << HUFF_LOOKAHEAD) {
      let fast_v = fast[i]
      if fast_v < 255 {
        // get symbol value from AC table
        let rs = self.values[fast_v]
        // shift by 4 to get run length
        let run = (rs >> 4) & 15
        // get magnitude bits stored at the lower 3 bits
        let mag_bits = rs & 15
        // length of the bit we've read
        let len = huff_size[fast_v]
        if mag_bits != 0 && len + mag_bits <= HUFF_LOOKAHEAD {
          // magnitude code followed by receive_extend code
          let mut k = i16((i << len) & ((1 << HUFF_LOOKAHEAD) - 1)) >>
            (HUFF_LOOKAHEAD - mag_bits)
          let m = 1 << (mag_bits - 1)
          if k < m {
            k += i16((-1 << mag_bits) + 1)
          }
          // if result is small enough fit into fast ac table
          if k >= -128 && k <= 127 {
            fast_ac[i] = i16((k << 8) + (run << 4) + (len + mag_bits))
          }
        }
      }
    }
    self.ac_lookup = Some(fast_ac)
  }

  // Validate symbols as being reasonable
  // For AC tables, we make no check, but accept all byte values 0..255
  // For DC tables, we require symbols to be in range 0..15
  if is_dc {
    for i in 0..<num_symbols {
      let sym = self.values[i]
      if sym > 15 {
        raise HuffmanDecode("Bad Huffman Table")
      }
    }
  }
}

///|
/// Truncate to a signed 16-bit value (Rust `as i16`).
fn i16(x : Int) -> Int {
  x << 16 >> 16
}
