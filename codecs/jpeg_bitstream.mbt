// Port of `zune-jpeg` (v0.5.15) `src/bitstream.rs`: a bit by bit reader of a
// Huffman encoded JPEG bitstream.
//
// `bits_left` is a `u8` upstream; it is kept in 0..=255 with the same
// wrapping/saturating arithmetic. Coefficients are `i16` values stored as
// `Int`.

///|
/// A `BitStream` struct, a bit by bit reader with super powers.
priv struct BitStream {
  /// A MSB type buffer that is used for some certain operations
  mut buffer : UInt64
  /// A TOP aligned MSB type buffer that is used to accelerate some
  /// operations like peek_bits and get_bits.
  mut aligned_buffer : UInt64
  /// Tell us the bits left the two buffer
  mut bits_left : Int
  /// Did we find a marker(RST/EOF) during decoding?
  mut marker : Marker?
  /// An i16 with the bit corresponding to successive_low set to 1, others 0.
  mut successive_low_mask : Int
  mut spec_start : Int
  mut spec_end : Int
  mut eob_run : Int
  mut overread_by : Int
  /// True if we have seen end of image marker.
  /// Don't read anything after that.
  mut seen_eoi : Bool
}

///|
/// Create a new BitStream.
fn BitStream::new() -> BitStream {
  {
    buffer: 0,
    aligned_buffer: 0,
    bits_left: 0,
    marker: None,
    successive_low_mask: 1,
    spec_start: 0,
    spec_end: 0,
    eob_run: 0,
    overread_by: 0,
    seen_eoi: false,
  }
}

///|
/// Create a new Bitstream for progressive decoding.
fn BitStream::new_progressive(
  al : Int,
  spec_start : Int,
  spec_end : Int,
) -> BitStream {
  {
    buffer: 0,
    aligned_buffer: 0,
    bits_left: 0,
    marker: None,
    successive_low_mask: i16(1 << al),
    spec_start,
    spec_end,
    eob_run: 0,
    overread_by: 0,
    seen_eoi: false,
  }
}

///|
/// `u64 << n` with Rust release semantics (the shift amount is masked).
fn shl64(x : UInt64, n : Int) -> UInt64 {
  x << (n & 63)
}

///|
/// Refill the bit buffer by (a maximum of) 32 bits.
///
/// This function will only refill if `self.bits_left` is less than 32.
fn BitStream::refill(
  self : BitStream,
  reader : ZReader,
) -> Bool raise DecodeErrors {
  // 32 bits is enough for a decode(16 bits) and receive_extend(max 16 bits)
  if self.bits_left < 32 {
    if self.marker is Some(_) || self.seen_eoi {
      // found a marker, or we are in EOI
      // also we are in over-reading mode, where we fill it with zeroes
      self.buffer = self.buffer << 32
      self.bits_left += 32
      self.aligned_buffer = shl64(self.buffer, 64 - self.bits_left)
      return true
    }
    if self.overread_by > 0 {
      if self.bits_left == 0 {
        raise ExhaustedData
      }
      // We already hit EOF while refilling. Continue consuming the buffered
      // bits but don't synthesize additional bytes from zero-fill.
      return true
    }
    // we optimize for the case where we don't have 255 in the stream and
    // have 4 bytes left as it is the common case
    if reader.available(4) == 4 {
      let p = reader.position
      let d = reader.data
      let msb_buf = (d[p].to_uint() << 24) |
        (d[p + 1].to_uint() << 16) |
        (d[p + 2].to_uint() << 8) |
        d[p + 3].to_uint()
      reader.position += 4
      // check if we have 0xff
      if !has_byte(msb_buf, 255) {
        self.bits_left += 32
        self.buffer = self.buffer << 32
        self.buffer = self.buffer | msb_buf.to_uint64()
        self.aligned_buffer = shl64(self.buffer, 64 - self.bits_left)
        return true
      }
      reader.rewind(4)
    }
    // 4 refills, if all succeed the stream should contain enough bits to
    // decode a value
    for _ in 0..<4 {
      if !self.refill_byte(reader) {
        return false
      }
    }
    // Construct an MSB buffer whose top bits are the bitstream we are
    // currently holding.
    self.aligned_buffer = shl64(self.buffer, 64 - self.bits_left)
  }
  true
}

///|
/// A single byte refill (upstream `refill!` macro). Returns `false` if a
/// marker was found (upstream returns `Ok(false)` from `refill`).
fn BitStream::refill_byte(
  self : BitStream,
  reader : ZReader,
) -> Bool raise DecodeErrors {
  // read a byte from the stream
  let byte = reader.read_u8()
  if reader.eof() {
    self.overread_by += 1
  }
  // append to the buffer
  self.buffer = (self.buffer << 8) | byte.to_uint64()
  // Increment bits left
  self.bits_left += 8
  // Check for special case of OxFF, to see if it's a stream or a marker
  if byte == 0xff {
    // read next byte
    let mut next_byte = reader.read_u8()
    // Byte snuffing, if we encounter byte snuff, we skip the byte
    if next_byte != 0x00 {
      // skip that byte we read
      while next_byte == 0xFF {
        next_byte = reader.read_u8()
      }
      if next_byte != 0x00 {
        // Undo the byte append and return
        self.buffer = self.buffer >> 8
        self.bits_left -= 8
        if self.bits_left != 0 {
          self.aligned_buffer = shl64(self.buffer, 64 - self.bits_left)
        }
        let marker = Marker::from_u8(next_byte)
        self.marker = Some(marker)
        if marker is UNKNOWN(_) {
          raise Format("Unknown marker in bit stream")
        }
        if next_byte == 0xD9 {
          // special handling for eoi, fill some bytes,even if its zero,
          // removes some panics
          self.buffer = self.buffer << 8
          self.bits_left += 8
          self.aligned_buffer = shl64(self.buffer, 64 - self.bits_left)
        }
        return false
      }
    }
  }
  true
}

///|
/// Peek `n` bits ahead without discarding them from the buffer.
fn BitStream::peek_bits(self : BitStream, n : Int) -> Int {
  (self.aligned_buffer >> (64 - n)).to_int()
}

///|
/// Discard the next `n` bits without checking.
fn BitStream::drop_bits(self : BitStream, n : Int) -> Unit {
  self.bits_left = @cmp.maximum(self.bits_left - n, 0)
  self.aligned_buffer = shl64(self.aligned_buffer, n)
}

///|
/// Read `n_bits` from the buffer and discard them.
fn BitStream::get_bits(self : BitStream, n_bits : Int) -> Int {
  let mask = (1UL << n_bits) - 1
  let n = n_bits & 63
  if n != 0 {
    self.aligned_buffer = (self.aligned_buffer << n) |
      (self.aligned_buffer >> (64 - n))
  }
  let bits = (self.aligned_buffer & mask).to_int()
  self.bits_left = (self.bits_left - n_bits) & 0xFF
  bits
}

///|
/// Get a single bit from the bitstream.
fn BitStream::get_bit(self : BitStream) -> Int {
  let k = (self.aligned_buffer >> 63).to_int()
  // discard a bit
  self.drop_bits(1)
  k
}

///|
/// Decode a Huffman symbol (upstream `decode_huff!`): `symbol` is the lookup
/// table entry of the next `HUFF_LOOKAHEAD` bits.
fn BitStream::decode_huff(
  self : BitStream,
  symbol0 : Int,
  table : HuffmanTable,
) -> Int raise DecodeErrors {
  let mut symbol = symbol0
  let mut code_length = symbol >> HUFF_LOOKAHEAD
  symbol = symbol & ((1 << HUFF_LOOKAHEAD) - 1)
  if code_length > HUFF_LOOKAHEAD {
    // if the symbol cannot be resolved in the first HUFF_LOOKAHEAD bits, we
    // know it lies somewhere between HUFF_LOOKAHEAD and 16 bits since jpeg
    // imposes 16 bit limit, we can therefore look 16 bits ahead and try to
    // resolve the symbol starting from 1+HUFF_LOOKAHEAD bits.
    symbol = self.peek_bits(16)
    // maxcode is pre-shifted 16 bytes long so that it has (16-code_length)
    // zeroes at the end hence we do not need to shift in the inner loop.
    while code_length < 17 {
      if symbol < table.maxcode[code_length] {
        break
      }
      code_length += 1
    }
    if code_length == 17 {
      // symbol could not be decoded.
      raise Format(
        "Bad Huffman Code 0x\{symbol.to_string(radix=16).to_upper()}, corrupt JPEG",
      )
    }
    symbol = symbol >> (16 - code_length)
    symbol = table.values[(symbol + table.offset[code_length]) & 0xFF]
  }
  if code_length > self.bits_left {
    raise Format(
      "Code length \{code_length}  more than bits left \{self.bits_left}",
    )
  }
  // drop bits read
  self.drop_bits(code_length)
  symbol
}

///|
/// Decode the DC coefficient in a MCU block, updating the DC prediction.
fn BitStream::decode_dc(
  self : BitStream,
  reader : ZReader,
  dc_table : HuffmanTable,
  dc_prediction : Int,
) -> Int raise DecodeErrors {
  if self.bits_left < 32 {
    let _ = self.refill(reader)
  }
  // look a head HUFF_LOOKAHEAD bits into the bitstream
  let mut symbol = self.peek_bits(HUFF_LOOKAHEAD)
  symbol = dc_table.lookup[symbol]
  symbol = self.decode_huff(symbol, dc_table)
  if symbol != 0 {
    let r = self.get_bits(symbol)
    symbol = huff_extend(r, symbol)
  }
  // Update DC prediction
  dc_prediction + symbol
}

///|
/// Like `decode_dc` but we do not need the result of the component, we only
/// want to remove it from the bitstream of the MCU.
fn BitStream::discard_dc(
  self : BitStream,
  reader : ZReader,
  dc_table : HuffmanTable,
) -> Unit raise DecodeErrors {
  if self.bits_left < 32 {
    let _ = self.refill(reader)
  }
  // look a head HUFF_LOOKAHEAD bits into the bitstream
  let mut symbol = self.peek_bits(HUFF_LOOKAHEAD)
  symbol = dc_table.lookup[symbol]
  symbol = self.decode_huff(symbol, dc_table)
  if symbol != 0 {
    let _ = self.get_bits(symbol)
  }
}

///|
/// Decode a Minimum Code Unit(MCU) block into `block` (dequantized, natural
/// order). Returns the zig-zag position after the last decoded coefficient.
fn BitStream::decode_mcu_block(
  self : BitStream,
  reader : ZReader,
  dc_table : HuffmanTable,
  ac_table : HuffmanTable,
  qt_table : FixedArray[Int],
  block : FixedArray[Int],
  component : Components,
) -> Int raise DecodeErrors {
  // Get fast AC table as a reference before we enter the hot path
  let ac_lookup = ac_table.ac_lookup.unwrap()
  // Decode AC coefficients
  let mut pos = 1
  if self.bits_left < 1 && self.marker is Some(_) {
    raise Format("No more bytes left in stream before marker")
  }
  // decode DC, dc prediction will contain the value
  component.dc_pred = self.decode_dc(reader, dc_table, component.dc_pred)
  // set dc to be the dc prediction.
  block[0] = component.dc_pred * qt_table[0]
  while pos < 64 {
    let _ = self.refill(reader)
    let mut symbol = self.peek_bits(HUFF_LOOKAHEAD)
    let fast_ac = ac_lookup[symbol]
    symbol = ac_table.lookup[symbol]
    if fast_ac != 0 {
      //  FAST AC path
      pos += (fast_ac >> 4) & 15 // run
      let t_pos = un_zigzag[@cmp.minimum(pos, 63)] & 63
      block[t_pos] = (fast_ac >> 8) * qt_table[t_pos] // Value
      self.drop_bits(fast_ac & 15)
      pos += 1
    } else {
      symbol = self.decode_huff(symbol, ac_table)
      let mut r = symbol >> 4
      symbol = symbol & 15
      if symbol != 0 {
        pos += r
        r = self.get_bits(symbol)
        symbol = huff_extend(r, symbol)
        let t_pos = un_zigzag[pos & 63] & 63
        block[t_pos] = symbol * qt_table[t_pos]
        pos += 1
      } else if r != 15 {
        return pos
      } else {
        pos += 16
      }
    }
  }
  64
}

///|
/// Advance the bitstream over a block but ignore the data contained.
fn BitStream::discard_mcu_block(
  self : BitStream,
  reader : ZReader,
  dc_table : HuffmanTable,
  ac_table : HuffmanTable,
) -> Int raise DecodeErrors {
  // Get fast AC table as a reference before we enter the hot path
  let ac_lookup = ac_table.ac_lookup.unwrap()
  // Decode AC coefficients
  let mut pos = 1
  // decode DC, dc prediction will contain the value
  self.discard_dc(reader, dc_table)
  while pos < 64 {
    let _ = self.refill(reader)
    let mut symbol = self.peek_bits(HUFF_LOOKAHEAD)
    let fast_ac = ac_lookup[symbol]
    symbol = ac_table.lookup[symbol]
    if fast_ac != 0 {
      //  FAST AC path
      pos += (fast_ac >> 4) & 15 // run
      self.drop_bits(fast_ac & 15)
      pos += 1
    } else {
      symbol = self.decode_huff(symbol, ac_table)
      let r = symbol >> 4
      symbol = symbol & 15
      if symbol != 0 {
        pos += r
        // Advance over bits but ignore.
        let _ = self.get_bits(symbol)
        pos += 1
      } else if r != 15 {
        return pos
      } else {
        pos += 16
      }
    }
  }
  64
}

///|
/// Decode a progressive DC block (first scan).
fn BitStream::decode_prog_dc_first(
  self : BitStream,
  reader : ZReader,
  dc_table : HuffmanTable,
  block : FixedArray[Int],
  idx : Int,
  component : Components,
) -> Unit raise DecodeErrors {
  component.dc_pred = self.decode_dc(reader, dc_table, component.dc_pred)
  block[idx] = i16(i16(component.dc_pred) * self.successive_low_mask)
}

///|
/// Decode a progressive DC block (refinement scan).
fn BitStream::decode_prog_dc_refine(
  self : BitStream,
  reader : ZReader,
  block : FixedArray[Int],
  idx : Int,
) -> Unit raise DecodeErrors {
  // refinement scan
  if self.bits_left < 1 {
    let _ = self.refill(reader)
    // if we find a marker, it may happens we don't refill.
    // So let's confirm again that refill worked
    if self.bits_left < 1 {
      raise Format("Marker found where not expected in refine bit")
    }
  }
  if self.get_bit() == 1 {
    block[idx] = i16(block[idx] + self.successive_low_mask)
  }
}

///|
/// Decode the AC coefficients of a block (first progressive scan).
fn BitStream::decode_mcu_ac_first(
  self : BitStream,
  reader : ZReader,
  ac_table : HuffmanTable,
  block : FixedArray[Int],
  base : Int,
) -> Unit raise DecodeErrors {
  let fast_ac = ac_table.ac_lookup.unwrap()
  let bit = self.successive_low_mask
  let mut k = self.spec_start
  // EOB runs are handled in mcu_prog.rs
  while true {
    let _ = self.refill(reader)
    // Check for marker in the stream
    let mut symbol = self.peek_bits(HUFF_LOOKAHEAD)
    let fac = fast_ac[symbol]
    symbol = ac_table.lookup[symbol]
    if fac != 0 {
      // fast ac path
      k += (fac >> 4) & 15 // run
      block[base + (un_zigzag[@cmp.minimum(k, 63)] & 63)] = i16(
        (fac >> 8) * bit,
      ) // value
      self.drop_bits(fac & 15)
      k += 1
    } else {
      symbol = self.decode_huff(symbol, ac_table)
      let mut r = symbol >> 4
      symbol = symbol & 15
      if symbol != 0 {
        k += r
        r = self.get_bits(symbol)
        symbol = huff_extend(r, symbol)
        block[base + (un_zigzag[k & 63] & 63)] = i16(i16(symbol) * bit)
        k += 1
      } else {
        if r != 15 {
          self.eob_run = 1 << r
          self.eob_run += self.get_bits(r)
          self.eob_run -= 1
          break
        }
        k += 16
      }
    }
    if k > self.spec_end {
      break
    }
  }
}

///|
/// Decode the AC coefficients of a block (refinement progressive scan).
fn BitStream::decode_mcu_ac_refine(
  self : BitStream,
  reader : ZReader,
  table : HuffmanTable,
  block : FixedArray[Int],
  base : Int,
) -> Unit raise DecodeErrors {
  let bit = self.successive_low_mask
  // `k` is a `u8` upstream
  let mut k = self.spec_start
  if self.eob_run == 0 {
    while true {
      // Decode a coefficient from the bit stream
      let _ = self.refill(reader)
      let mut symbol = self.peek_bits(HUFF_LOOKAHEAD)
      symbol = table.lookup[symbol]
      symbol = self.decode_huff(symbol, table)
      let mut r = symbol >> 4
      symbol = symbol & 15
      if symbol == 0 {
        if r != 15 {
          // EOB run is 2^r + bits
          self.eob_run = 1 << r
          self.eob_run += self.get_bits(r)
          // EOB runs are handled by the eob logic
          break
        }
        // get sign bit
      } else if self.get_bit() == 1 {
        symbol = bit
      } else {
        symbol = i16(-bit)
      }

      // Advance over already nonzero coefficients appending correction bits
      // to the non-zeroes.
      if k <= self.spec_end {
        while true {
          let idx = base + (un_zigzag[k & 63] & 63)
          let coefficient = block[idx]
          if coefficient != 0 {
            if self.bits_left < 1 {
              let _ = self.refill(reader)
              if self.bits_left < 1 && self.marker is Some(_) {
                raise Format("Marker found where not expected in refine bit")
              }
            }
            if self.get_bit() == 1 && (coefficient & bit) == 0 {
              if coefficient > 0 {
                block[idx] = i16(coefficient + bit)
              } else {
                block[idx] = i16(coefficient - bit)
              }
            }
          } else {
            r -= 1
            if r < 0 {
              // reached target zero coefficient.
              break
            }
          }
          if k == self.spec_end {
            break
          }
          k = (k + 1) & 0xFF
        }
      }
      if symbol != 0 {
        let pos = un_zigzag[k & 63]
        // output new non-zero coefficient.
        block[base + (pos & 63)] = i16(symbol)
      }
      k = (k + 1) & 0xFF
      if k > self.spec_end {
        break
      }
    }
  }
  if self.eob_run > 0 {
    // only run if block does not consists of purely zeroes
    let mut nonzero = false
    for i in 1..<64 {
      if block[base + i] != 0 {
        nonzero = true
        break
      }
    }
    if nonzero {
      let _ = self.refill(reader)
      while k <= self.spec_end {
        let idx = base + (un_zigzag[k & 63] & 63)
        let coefficient = block[idx]
        if coefficient != 0 && self.get_bit() == 1 {
          // check if we already modified it, if so do nothing, otherwise
          // append the correction bit.
          if (coefficient & bit) == 0 {
            if coefficient >= 0 {
              block[idx] = i16(coefficient + bit)
            } else {
              block[idx] = i16(coefficient - bit)
            }
          }
        }
        if self.bits_left < 1 {
          // refill at the last possible moment
          let _ = self.refill(reader)
        }
        k = (k + 1) & 0xFF
      }
    }
    // count a block completed in EOB run
    self.eob_run -= 1
  }
}

///|
fn BitStream::update_progressive_params(
  self : BitStream,
  _ah : Int,
  al : Int,
  spec_start : Int,
  spec_end : Int,
) -> Unit {
  self.successive_low_mask = i16(1 << al)
  self.spec_start = spec_start
  self.spec_end = spec_end
}

///|
/// Reset the stream if we have a restart marker.
fn BitStream::reset(self : BitStream) -> Unit {
  self.bits_left = 0
  self.marker = None
  self.buffer = 0
  self.aligned_buffer = 0
  self.eob_run = 0
}

///|
/// Do the equivalent of JPEG HUFF_EXTEND.
fn huff_extend(x : Int, s : Int) -> Int {
  // if x<s return x else return x+offset[s] where offset[s] = ( (-1<<s)+1)
  x + (((x - (1 << (s - 1))) >> 31) & ((-1 << s) + 1))
}

///|
fn has_zero(v : UInt) -> Bool {
  // Retrieved from Stanford bithacks
  (((v & 0x7F7F_7F7F) + 0x7F7F_7F7F) | v | 0x7F7F_7F7F) != 0xFFFF_FFFF
}

///|
fn has_byte(b : UInt, val : Int) -> Bool {
  has_zero(b ^ (0x0101_0101U * val.reinterpret_as_uint()))
}
