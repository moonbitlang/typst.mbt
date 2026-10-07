// Port of `fdeflate` 0.3.7 `src/decompress.rs`: the streaming zlib
// decompressor that the `png` crate decodes `IDAT` data and `iCCP` profiles
// with. Its errors and the amount of input it consumes and of output it
// produces per call are part of what a damaged PNG decodes to (which error
// comes first), so this follows upstream's control flow exactly.
//
// Differences that cannot be observed: the output is a `FixedArray[Byte]`
// with the bounds of upstream's slice (`out_start`, `out_end`) and absolute
// indices; a back-reference is copied bytewise or with one `blit` where
// upstream copies 16 bytes at a time past its end; the checksum is not
// computed at all when it is ignored (upstream still hashes the last chunk).

///|
/// An error encountered while decompressing a deflate stream.
// `InputStartsWithRun` and `ExtraInput` are never made, like upstream
// (fdeflate 0.3.7 src/decompress.rs:40 and :46).
#warnings("-unused_constructor")
priv suberror DecompressionError {
  /// The zlib header is corrupt.
  BadZlibHeader
  /// All input was consumed, but the end of the stream hasn't been reached.
  InsufficientInput
  /// A block header specifies an invalid block type.
  InvalidBlockType
  /// An uncompressed block's NLEN value is invalid.
  InvalidUncompressedBlockLength
  /// Too many literals were specified.
  InvalidHlit
  /// Too many distance codes were specified.
  InvalidHdist
  /// Attempted to repeat a previous code before reading any codes, or past the end of the code
  /// lengths.
  InvalidCodeLengthRepeat
  /// The stream doesn't specify a valid huffman tree.
  BadCodeLengthHuffmanTree
  /// The stream doesn't specify a valid huffman tree.
  BadLiteralLengthHuffmanTree
  /// The stream doesn't specify a valid huffman tree.
  BadDistanceHuffmanTree
  /// The stream contains a literal/length code that was not allowed by the header.
  InvalidLiteralLengthCode
  /// The stream contains a distance code that was not allowed by the header.
  InvalidDistanceCode
  /// The stream contains contains back-reference as the first symbol.
  InputStartsWithRun
  /// The stream contains a back-reference that is too far back.
  DistanceTooFarBack
  /// The deflate stream checksum is incorrect.
  WrongChecksum
  /// Extra input data.
  ExtraInput
}

///|
/// The `Debug` output of the error (upstream `#[derive(Debug)]`).
fn DecompressionError::debug(self : DecompressionError) -> String {
  match self {
    BadZlibHeader => "BadZlibHeader"
    InsufficientInput => "InsufficientInput"
    InvalidBlockType => "InvalidBlockType"
    InvalidUncompressedBlockLength => "InvalidUncompressedBlockLength"
    InvalidHlit => "InvalidHlit"
    InvalidHdist => "InvalidHdist"
    InvalidCodeLengthRepeat => "InvalidCodeLengthRepeat"
    BadCodeLengthHuffmanTree => "BadCodeLengthHuffmanTree"
    BadLiteralLengthHuffmanTree => "BadLiteralLengthHuffmanTree"
    BadDistanceHuffmanTree => "BadDistanceHuffmanTree"
    InvalidLiteralLengthCode => "InvalidLiteralLengthCode"
    InvalidDistanceCode => "InvalidDistanceCode"
    InputStartsWithRun => "InputStartsWithRun"
    DistanceTooFarBack => "DistanceTooFarBack"
    WrongChecksum => "WrongChecksum"
    ExtraInput => "ExtraInput"
  }
}

///|
priv enum FdeflateState {
  ZlibHeader
  BlockHeader
  CodeLengthCodes
  CodeLengths
  CompressedData
  UncompressedData
  Checksum
  Done
} derive(Eq)

///|
/// Decompressor for arbitrary zlib streams (upstream `Decompressor`, with
/// its `CompressedBlock` and `BlockHeader` inlined).
priv struct Decompressor {
  // State for decoding a compressed block (`CompressedBlock`).
  litlen_table : FixedArray[UInt]
  secondary_table : Array[UInt]
  dist_table : FixedArray[UInt]
  dist_secondary_table : Array[UInt]
  mut eof_code : UInt
  mut eof_mask : UInt
  mut eof_bits : Int
  // State for decoding a block header (`BlockHeader`).
  mut hlit : Int
  mut hdist : Int
  mut hclen : Int
  mut num_lengths_read : Int
  /// Low 3-bits are code length code length, high 5-bits are code length code.
  table : FixedArray[UInt]
  code_lengths : FixedArray[Int]
  // Number of bytes left for uncompressed block.
  mut uncompressed_bytes_left : Int
  mut buffer : UInt64
  mut nbits : Int
  /// `queued_rle: Option<(u8, usize)>`; a length of zero is `None`.
  mut queued_rle_data : Byte
  mut queued_rle_len : Int
  /// `queued_backref: Option<(usize, usize)>`; a length of zero is `None`.
  mut queued_backref_dist : Int
  mut queued_backref_len : Int
  mut last_block : Bool
  mut fixed_table : Bool
  mut state : FdeflateState
  mut checksum : UInt
  mut ignore_adler32 : Bool
  /// The input of the current `read` call that has not been read yet
  /// (upstream's `remaining_input`): `input[in_pos..in_end]`.
  mut input : Bytes
  mut in_pos : Int
  mut in_end : Int
  /// The first element of the result of `read`: the number of bytes read
  /// from the input.
  mut in_consumed : Int
}

///|
/// Create a new decompressor.
fn Decompressor::new() -> Decompressor {
  {
    buffer: 0,
    nbits: 0,
    litlen_table: FixedArray::make(4096, 0),
    dist_table: FixedArray::make(512, 0),
    secondary_table: [],
    dist_secondary_table: [],
    eof_code: 0,
    eof_mask: 0,
    eof_bits: 0,
    hlit: 0,
    hdist: 0,
    hclen: 0,
    table: FixedArray::make(128, 0),
    num_lengths_read: 0,
    code_lengths: FixedArray::make(320, 0),
    uncompressed_bytes_left: 0,
    queued_rle_data: 0,
    queued_rle_len: 0,
    queued_backref_dist: 0,
    queued_backref_len: 0,
    checksum: ADLER32_INITIAL_VALUE,
    state: ZlibHeader,
    last_block: false,
    ignore_adler32: false,
    fixed_table: false,
    input: b"",
    in_pos: 0,
    in_end: 0,
    in_consumed: 0,
  }
}

///|
fn Decompressor::fill_buffer(self : Decompressor) -> Unit {
  let len = self.in_end - self.in_pos
  if len >= 8 {
    // In bounds: `in_pos + 8 <= in_end <= input.length()`.
    self.buffer = self.buffer |
      (self.input.unsafe_read_uint64_le(self.in_pos) << self.nbits)
    self.in_pos += (63 - self.nbits) / 8
    self.nbits = self.nbits | 56
  } else {
    let nbytes = @cmp.minimum(len, (63 - self.nbits) / 8)
    let mut input_data = 0UL
    for k in 0..<nbytes {
      input_data = input_data |
        (
          UInt64::extend_uint(
            self.input[self.in_pos + k].to_int().reinterpret_as_uint(),
          ) <<
          (8 * k)
        )
    }
    // `checked_shl(nbits)`: `nbits` is at most 63.
    self.buffer = self.buffer | (input_data << self.nbits)
    self.nbits += nbytes * 8
    self.in_pos += nbytes
  }
}

///|
fn Decompressor::peak_bits(self : Decompressor, nbits : Int) -> UInt64 {
  self.buffer & ((1UL << nbits) - 1)
}

///|
fn Decompressor::consume_bits(self : Decompressor, nbits : Int) -> Unit {
  self.buffer = self.buffer >> nbits
  self.nbits -= nbits
}

///|
/// The state after the end of a block.
fn Decompressor::end_of_block(self : Decompressor) -> FdeflateState {
  if self.last_block {
    Checksum
  } else {
    BlockHeader
  }
}

///|
fn Decompressor::read_block_header(
  self : Decompressor,
) -> Unit raise DecompressionError {
  self.fill_buffer()
  if self.nbits < 10 {
    return
  }
  let start = self.peak_bits(3).to_int()
  self.last_block = (start & 1) != 0
  match start >> 1 {
    0b00 => {
      let align_bits = (self.nbits - 3) % 8
      let header_bits = 3 + 32 + align_bits
      if self.nbits < header_bits {
        return
      }
      let len = (self.peak_bits(align_bits + 19) >> (align_bits + 3)).to_int() &
        0xFFFF
      let nlen = (self.peak_bits(header_bits) >> (align_bits + 19)).to_int() &
        0xFFFF
      if nlen != (len ^ 0xFFFF) {
        raise InvalidUncompressedBlockLength
      }
      self.state = UncompressedData
      self.uncompressed_bytes_left = len
      self.consume_bits(header_bits)
    }
    0b01 => {
      self.consume_bits(3)

      // Check for an entirely empty blocks which can happen if there are "partial
      // flushes" in the deflate stream. With fixed huffman codes, the EOF symbol is
      // 7-bits of zeros so we peak ahead and see if the next 7-bits are all zero.
      if self.peak_bits(7) == 0 {
        self.consume_bits(7)
        if self.last_block {
          self.state = Checksum
          return
        }

        // At this point we've consumed the entire block and need to read the next block
        // header. If tail call optimization were guaranteed, we could just recurse
        // here. But without it, a long sequence of empty fixed-blocks might cause a
        // stack overflow. Instead, we consume all empty blocks in a loop and then
        // recurse. This is the only recursive call this function, and thus is safe.
        while self.nbits >= 10 && self.peak_bits(10) == 0b010 {
          self.consume_bits(10)
          self.fill_buffer()
        }
        return self.read_block_header()
      }

      // Build decoding tables if the previous block wasn't also a fixed block.
      if !self.fixed_table {
        self.fixed_table = true
        let fixed = fdeflate_fixed_tables()
        fixed.litlen_table.blit_to(self.litlen_table, len=4096)
        fixed.dist_table.blit_to(self.dist_table, len=512)
        self.eof_bits = 7
        self.eof_code = 0
        self.eof_mask = 0x7f
      }
      self.state = CompressedData
    }
    0b10 => {
      if self.nbits < 17 {
        return
      }
      self.hlit = (self.peak_bits(8) >> 3).to_int() + 257
      self.hdist = (self.peak_bits(13) >> 8).to_int() + 1
      self.hclen = (self.peak_bits(17) >> 13).to_int() + 4
      if self.hlit > 286 {
        raise InvalidHlit
      }
      if self.hdist > 30 {
        raise InvalidHdist
      }
      self.consume_bits(17)
      self.state = CodeLengthCodes
      self.fixed_table = false
    }
    _ => raise InvalidBlockType
  }
}

///|
fn Decompressor::read_code_length_codes(
  self : Decompressor,
) -> Unit raise DecompressionError {
  self.fill_buffer()
  if self.nbits + (self.in_end - self.in_pos) * 8 < 3 * self.hclen {
    return
  }
  let code_length_lengths = FixedArray::make(19, 0)
  for i in 0..<self.hclen {
    code_length_lengths[fdeflate_clcl_order[i]] = self.peak_bits(3).to_int()
    self.consume_bits(3)

    // We need to refill the buffer after reading 3 * 18 = 54 bits since the buffer holds
    // between 56 and 63 bits total.
    if i == 17 {
      self.fill_buffer()
    }
  }
  let codes = FixedArray::make(19, 0)
  if !build_table(
      code_length_lengths,
      0,
      19,
      Plain,
      codes,
      self.table,
      7,
      [],
      false,
      false,
    ) {
    raise BadCodeLengthHuffmanTree
  }
  self.state = CodeLengths
  self.num_lengths_read = 0
}

///|
fn Decompressor::read_code_lengths(
  self : Decompressor,
) -> Unit raise DecompressionError {
  let total_lengths = self.hlit + self.hdist
  while self.num_lengths_read < total_lengths {
    self.fill_buffer()
    if self.nbits < 7 {
      return
    }
    let code = self.peak_bits(7).to_int()
    let entry = self.table[code]
    let length = (entry & 0x7).reinterpret_as_int()
    let symbol = (entry >> 16).reinterpret_as_int() & 0xFF
    if symbol <= 15 {
      self.code_lengths[self.num_lengths_read] = symbol
      self.num_lengths_read += 1
      self.consume_bits(length)
    } else {
      // 16..=18 (the table holds no other symbol)
      let (base_repeat, extra_bits) = match symbol {
        16 => (3, 2)
        17 => (3, 3)
        _ => (11, 7)
      }
      if self.nbits < length + extra_bits {
        return
      }
      let value = if symbol == 16 {
        if self.num_lengths_read == 0 {
          raise InvalidCodeLengthRepeat
        }
        self.code_lengths[self.num_lengths_read - 1]
        // TODO: is this right?
      } else {
        0
      }
      let repeat = (self.peak_bits(length + extra_bits) >> length).to_int() +
        base_repeat
      if self.num_lengths_read + repeat > total_lengths {
        raise InvalidCodeLengthRepeat
      }
      for i in 0..<repeat {
        self.code_lengths[self.num_lengths_read + i] = value
      }
      self.num_lengths_read += repeat
      self.consume_bits(length + extra_bits)
    }
  }

  // `code_lengths.copy_within(hlit..total_lengths, 288)`
  self.code_lengths.unsafe_blit(
    288,
    self.code_lengths,
    self.hlit,
    total_lengths - self.hlit,
  )
  for i in self.hlit..<288 {
    self.code_lengths[i] = 0
  }
  for i in (288 + self.hdist)..<320 {
    self.code_lengths[i] = 0
  }
  self.eof_code = build_tables(
    self.hlit,
    self.code_lengths,
    self.litlen_table,
    self.secondary_table,
    self.dist_table,
    self.dist_secondary_table,
  )
  self.eof_mask = (1U << self.code_lengths[256]) - 1
  self.eof_bits = self.code_lengths[256]
  self.state = CompressedData
}

///|
/// Upstream `Decompressor::build_tables`, which fills a `CompressedBlock`:
/// here the tables, and the result is its `eof_code` (the caller sets
/// `eof_mask` and `eof_bits`).
fn build_tables(
  hlit : Int,
  code_lengths : FixedArray[Int],
  litlen_table : FixedArray[UInt],
  secondary_table : Array[UInt],
  dist_table : FixedArray[UInt],
  dist_secondary_table : Array[UInt],
) -> UInt raise DecompressionError {
  // If there is no code assigned for the EOF symbol then the bitstream is invalid.
  if code_lengths[256] == 0 {
    // TODO: Return a dedicated error in this case.
    raise BadLiteralLengthHuffmanTree
  }
  let codes = FixedArray::make(288, 0)
  secondary_table.clear()
  if !build_table(
      code_lengths,
      0,
      hlit,
      Litlen,
      codes,
      litlen_table,
      12,
      secondary_table,
      false,
      true,
    ) {
    raise BadCodeLengthHuffmanTree
  }
  let eof_code = codes[256].reinterpret_as_uint()

  // Build the distance code table.
  let mut all_zero = true
  for i in 288..<320 {
    if code_lengths[i] != 0 {
      all_zero = false
      break
    }
  }
  if all_zero {
    dist_table.fill(0)
  } else {
    let dist_codes = FixedArray::make(32, 0)
    if !build_table(
        code_lengths,
        288,
        32,
        Distance,
        dist_codes,
        dist_table,
        9,
        dist_secondary_table,
        true,
        false,
      ) {
      raise BadDistanceHuffmanTree
    }
  }
  eof_code
}

///|
/// The tables of a block with fixed Huffman codes.
priv struct FixedTables {
  litlen_table : FixedArray[UInt]
  dist_table : FixedArray[UInt]
}

///|
let fdeflate_fixed_tables_cell : Ref[FixedTables?] = { val: None, }

///|
/// Upstream's `FIXED_LITLEN_TABLE` and `FIXED_DIST_TABLE`, repeated to the
/// sizes of the decoding tables. They are what `build_tables` makes of the
/// fixed code lengths (upstream's test `fixed_tables`), built on first use.
fn fdeflate_fixed_tables() -> FixedTables {
  if fdeflate_fixed_tables_cell.val is Some(tables) {
    return tables
  }
  // `FIXED_CODE_LENGTHS`
  let lengths = FixedArray::make(320, 0)
  for i in 0..<320 {
    lengths[i] = if i < 144 {
      8
    } else if i < 256 {
      9
    } else if i < 280 {
      7
    } else if i < 288 {
      8
    } else {
      5
    }
  }
  let tables = {
    litlen_table: FixedArray::make(4096, 0U),
    dist_table: FixedArray::make(512, 0U),
  }
  // The code of the end-of-block symbol is zero (seven bits).
  let eof_code = build_tables(
    288,
    lengths,
    tables.litlen_table,
    [],
    tables.dist_table,
    [],
  ) catch {
    _ => abort("the fixed code lengths are valid")
  }
  guard! eof_code == 0
  fdeflate_fixed_tables_cell.val = Some(tables)
  tables
}

///|
/// Copies a back-reference of `len` bytes at distance `dist` to
/// `output[output_index..]` (`dist <= output_index`, `output_index + len <=
/// output.length()`).
fn copy_backref(
  output : FixedArray[Byte],
  output_index : Int,
  dist : Int,
  len : Int,
) -> Unit {
  if dist >= len {
    output.unsafe_blit(output_index, output, output_index - dist, len)
  } else {
    for i in 0..<len {
      output[output_index + i] = output[output_index + i - dist]
    }
  }
}

///|
/// Upstream `read_compressed`; `output_index` and the result are absolute
/// indices into `output`, whose slice is `output[out_start..out_end]`.
fn Decompressor::read_compressed(
  self : Decompressor,
  output : FixedArray[Byte],
  out_start : Int,
  out_end : Int,
  output_index : Int,
) -> Int raise DecompressionError {
  let mut output_index = output_index
  let litlen_table = self.litlen_table
  let dist_table = self.dist_table
  // Fast decoding loop.
  //
  // This loop is optimized for speed and is the main decoding loop for the decompressor,
  // which is used when there are at least 8 bytes of input and output data available. It
  // assumes that the bitbuffer is full (nbits >= 56) and that litlen_entry has been loaded.
  //
  // These assumptions enable a few optimizations:
  // - Nearly all checks for nbits are avoided.
  // - Checking the input size is optimized out in the refill function call.
  // - The litlen_entry for the next loop iteration can be loaded in parallel with refilling
  //   the bit buffer. This is because when the input is non-empty, the bit buffer actually
  //   has 64-bits of valid data (even though nbits will be in 56..=63).
  self.fill_buffer()
  let mut litlen_entry = litlen_table[(self.buffer & 0xfff).to_int()]
  while self.state is CompressedData &&
        output_index + 8 <= out_end &&
        self.in_end - self.in_pos >= 8 {
    // First check whether the next symbol is a literal. This code does up to 2 additional
    // table lookups to decode more literals.
    let mut bits : UInt64 = 0
    let mut litlen_code_bits = (litlen_entry & 0xff).reinterpret_as_int()
    if (litlen_entry & LITERAL_ENTRY) != 0 {
      let litlen_entry2 = litlen_table[((self.buffer >> litlen_code_bits) &
        0xfff).to_int()]
      let litlen_code_bits2 = (litlen_entry2 & 0xff).reinterpret_as_int()
      let litlen_entry3 = litlen_table[((
          self.buffer >> (litlen_code_bits + litlen_code_bits2)
        ) &
        0xfff).to_int()]
      let litlen_code_bits3 = (litlen_entry3 & 0xff).reinterpret_as_int()
      let litlen_entry4 = litlen_table[((
          self.buffer >>
          (litlen_code_bits + litlen_code_bits2 + litlen_code_bits3)
        ) &
        0xfff).to_int()]
      let advance_output_bytes = ((litlen_entry & 0xf00) >> 8).reinterpret_as_int()
      output[output_index] = (litlen_entry >> 16).to_byte()
      output[output_index + 1] = (litlen_entry >> 24).to_byte()
      output_index += advance_output_bytes
      if (litlen_entry2 & LITERAL_ENTRY) != 0 {
        let advance_output_bytes2 = ((litlen_entry2 & 0xf00) >> 8).reinterpret_as_int()
        output[output_index] = (litlen_entry2 >> 16).to_byte()
        output[output_index + 1] = (litlen_entry2 >> 24).to_byte()
        output_index += advance_output_bytes2
        if (litlen_entry3 & LITERAL_ENTRY) != 0 {
          let advance_output_bytes3 = ((litlen_entry3 & 0xf00) >> 8).reinterpret_as_int()
          output[output_index] = (litlen_entry3 >> 16).to_byte()
          output[output_index + 1] = (litlen_entry3 >> 24).to_byte()
          output_index += advance_output_bytes3
          litlen_entry = litlen_entry4
          self.consume_bits(
            litlen_code_bits + litlen_code_bits2 + litlen_code_bits3,
          )
          self.fill_buffer()
          continue
        } else {
          self.consume_bits(litlen_code_bits + litlen_code_bits2)
          litlen_entry = litlen_entry3
          litlen_code_bits = litlen_code_bits3
          self.fill_buffer()
          bits = self.buffer
        }
      } else {
        self.consume_bits(litlen_code_bits)
        bits = self.buffer
        litlen_entry = litlen_entry2
        litlen_code_bits = litlen_code_bits2
        if self.nbits < 48 {
          self.fill_buffer()
        }
      }
    } else {
      bits = self.buffer
    }

    // The next symbol is either a 13+ bit literal, back-reference, or an EOF symbol.
    let mut length_base = 0
    let mut length_extra_bits = 0
    if (litlen_entry & EXCEPTIONAL_ENTRY) == 0 {
      length_base = (litlen_entry >> 16).reinterpret_as_int()
      length_extra_bits = ((litlen_entry >> 8) & 0xff).reinterpret_as_int()
    } else if (litlen_entry & SECONDARY_TABLE_ENTRY) != 0 {
      let secondary_table_index = (litlen_entry >> 16) +
        ((bits >> 12).to_uint() & (litlen_entry & 0xff))
      let secondary_entry = self.secondary_table[secondary_table_index.reinterpret_as_int()]
      let litlen_symbol = (secondary_entry >> 4).reinterpret_as_int()
      litlen_code_bits = (secondary_entry & 0xf).reinterpret_as_int()
      if litlen_symbol <= 255 {
        self.consume_bits(litlen_code_bits)
        litlen_entry = litlen_table[(self.buffer & 0xfff).to_int()]
        self.fill_buffer()
        output[output_index] = litlen_symbol.to_byte()
        output_index += 1
        continue
      } else if litlen_symbol == 256 {
        self.consume_bits(litlen_code_bits)
        self.state = self.end_of_block()
        break
      } else {
        length_base = fdeflate_len_sym_to_len_base[litlen_symbol - 257]
        length_extra_bits = fdeflate_len_sym_to_len_extra[litlen_symbol - 257]
      }
    } else if litlen_code_bits == 0 {
      raise InvalidLiteralLengthCode
    } else {
      self.consume_bits(litlen_code_bits)
      self.state = self.end_of_block()
      break
    }
    bits = bits >> litlen_code_bits
    let length_extra_mask = (1UL << length_extra_bits) - 1
    let length = length_base + (bits & length_extra_mask).to_int()
    bits = bits >> length_extra_bits
    let dist_entry = dist_table[(bits & 0x1ff).to_int()]
    let mut dist_base = 0
    let mut dist_extra_bits = 0
    let mut dist_code_bits = 0
    if (dist_entry & LITERAL_ENTRY) != 0 {
      dist_base = (dist_entry >> 16).reinterpret_as_int()
      dist_extra_bits = ((dist_entry >> 8) & 0xf).reinterpret_as_int()
      dist_code_bits = (dist_entry & 0xff).reinterpret_as_int()
    } else if dist_entry >> 8 == 0 {
      raise InvalidDistanceCode
    } else {
      let secondary_table_index = (dist_entry >> 16) +
        ((bits >> 9).to_uint() & (dist_entry & 0xff))
      let secondary_entry = self.dist_secondary_table[secondary_table_index.reinterpret_as_int()]
      let dist_symbol = (secondary_entry >> 4).reinterpret_as_int()
      if dist_symbol >= 30 {
        raise InvalidDistanceCode
      }
      dist_base = fdeflate_dist_sym_to_dist_base[dist_symbol]
      dist_extra_bits = fdeflate_dist_sym_to_dist_extra[dist_symbol]
      dist_code_bits = (secondary_entry & 0xf).reinterpret_as_int()
    }
    bits = bits >> dist_code_bits
    let dist = dist_base + (bits & ((1UL << dist_extra_bits) - 1)).to_int()
    if dist > output_index - out_start {
      raise DistanceTooFarBack
    }
    self.consume_bits(
      litlen_code_bits + length_extra_bits + dist_code_bits + dist_extra_bits,
    )
    self.fill_buffer()
    litlen_entry = litlen_table[(self.buffer & 0xfff).to_int()]
    let copy_length = @cmp.minimum(length, out_end - output_index)
    if dist == 1 {
      let last = output[output_index - 1]
      output.fill(last, start=output_index, end=output_index + copy_length)
      if copy_length < length {
        self.queued_rle_data = last
        self.queued_rle_len = length - copy_length
        output_index = out_end
        break
      }
    } else if output_index + length + 15 <= out_end {
      // Upstream copies 16 bytes at a time here, up to 15 bytes past the
      // end of the back-reference (bytes that are written again later or
      // are never read).
      copy_backref(output, output_index, dist, length)
    } else {
      copy_backref(output, output_index, dist, copy_length)
      if copy_length < length {
        self.queued_backref_dist = dist
        self.queued_backref_len = length - copy_length
        output_index = out_end
        break
      }
    }
    output_index += copy_length
  }

  // Careful decoding loop.
  //
  // This loop processes the remaining input when we're too close to the end of the input or
  // output to use the fast loop.
  while self.state is CompressedData {
    self.fill_buffer()
    if output_index == out_end {
      break
    }
    let mut bits = self.buffer
    let litlen_entry = litlen_table[(bits & 0xfff).to_int()]
    let mut litlen_code_bits = (litlen_entry & 0xff).reinterpret_as_int()
    if (litlen_entry & LITERAL_ENTRY) != 0 {
      // Fast path: the next symbol is <= 12 bits and a literal, the table specifies the
      // output bytes and we can directly write them to the output buffer.
      let advance_output_bytes = ((litlen_entry & 0xf00) >> 8).reinterpret_as_int()
      if self.nbits < litlen_code_bits {
        break
      } else if output_index + 1 < out_end {
        output[output_index] = (litlen_entry >> 16).to_byte()
        output[output_index + 1] = (litlen_entry >> 24).to_byte()
        output_index += advance_output_bytes
        self.consume_bits(litlen_code_bits)
        continue
      } else if output_index + advance_output_bytes == out_end {
        output[output_index] = (litlen_entry >> 16).to_byte()
        output_index += 1
        self.consume_bits(litlen_code_bits)
        break
      } else {
        output[output_index] = (litlen_entry >> 16).to_byte()
        self.queued_rle_data = (litlen_entry >> 24).to_byte()
        self.queued_rle_len = 1
        output_index += 1
        self.consume_bits(litlen_code_bits)
        break
      }
    }
    let mut length_base = 0
    let mut length_extra_bits = 0
    if (litlen_entry & EXCEPTIONAL_ENTRY) == 0 {
      length_base = (litlen_entry >> 16).reinterpret_as_int()
      length_extra_bits = ((litlen_entry >> 8) & 0xff).reinterpret_as_int()
    } else if (litlen_entry & SECONDARY_TABLE_ENTRY) != 0 {
      let secondary_table_index = (litlen_entry >> 16) +
        ((bits >> 12).to_uint() & (litlen_entry & 0xff))
      let secondary_entry = self.secondary_table[secondary_table_index.reinterpret_as_int()]
      let litlen_symbol = (secondary_entry >> 4).reinterpret_as_int()
      litlen_code_bits = (secondary_entry & 0xf).reinterpret_as_int()
      if self.nbits < litlen_code_bits {
        break
      } else if litlen_symbol < 256 {
        self.consume_bits(litlen_code_bits)
        output[output_index] = litlen_symbol.to_byte()
        output_index += 1
        continue
      } else if litlen_symbol == 256 {
        self.consume_bits(litlen_code_bits)
        self.state = self.end_of_block()
        break
      }
      length_base = fdeflate_len_sym_to_len_base[litlen_symbol - 257]
      length_extra_bits = fdeflate_len_sym_to_len_extra[litlen_symbol - 257]
    } else if litlen_code_bits == 0 {
      raise InvalidLiteralLengthCode
    } else {
      if self.nbits < litlen_code_bits {
        break
      }
      self.consume_bits(litlen_code_bits)
      self.state = self.end_of_block()
      break
    }
    bits = bits >> litlen_code_bits
    let length_extra_mask = (1UL << length_extra_bits) - 1
    let length = length_base + (bits & length_extra_mask).to_int()
    bits = bits >> length_extra_bits
    let dist_entry = dist_table[(bits & 0x1ff).to_int()]
    let mut dist_base = 0
    let mut dist_extra_bits = 0
    let mut dist_code_bits = 0
    if (dist_entry & LITERAL_ENTRY) != 0 {
      dist_base = (dist_entry >> 16).reinterpret_as_int()
      dist_extra_bits = ((dist_entry >> 8) & 0xf).reinterpret_as_int()
      dist_code_bits = (dist_entry & 0xff).reinterpret_as_int()
    } else if self.nbits > litlen_code_bits + length_extra_bits + 9 {
      if dist_entry >> 8 == 0 {
        raise InvalidDistanceCode
      }
      let secondary_table_index = (dist_entry >> 16) +
        ((bits >> 9).to_uint() & (dist_entry & 0xff))
      let secondary_entry = self.dist_secondary_table[secondary_table_index.reinterpret_as_int()]
      let dist_symbol = (secondary_entry >> 4).reinterpret_as_int()
      if dist_symbol >= 30 {
        raise InvalidDistanceCode
      }
      dist_base = fdeflate_dist_sym_to_dist_base[dist_symbol]
      dist_extra_bits = fdeflate_dist_sym_to_dist_extra[dist_symbol]
      dist_code_bits = (secondary_entry & 0xf).reinterpret_as_int()
    } else {
      break
    }
    bits = bits >> dist_code_bits
    let dist = dist_base + (bits & ((1UL << dist_extra_bits) - 1)).to_int()
    let total_bits = litlen_code_bits +
      length_extra_bits +
      dist_code_bits +
      dist_extra_bits
    if self.nbits < total_bits {
      break
    } else if dist > output_index - out_start {
      raise DistanceTooFarBack
    }
    self.consume_bits(total_bits)
    let copy_length = @cmp.minimum(length, out_end - output_index)
    if dist == 1 {
      let last = output[output_index - 1]
      output.fill(last, start=output_index, end=output_index + copy_length)
      if copy_length < length {
        self.queued_rle_data = last
        self.queued_rle_len = length - copy_length
        output_index = out_end
        break
      }
    } else if output_index + length + 15 <= out_end {
      copy_backref(output, output_index, dist, length)
    } else {
      copy_backref(output, output_index, dist, copy_length)
      if copy_length < length {
        self.queued_backref_dist = dist
        self.queued_backref_len = length - copy_length
        output_index = out_end
        break
      }
    }
    output_index += copy_length
  }
  if self.state is CompressedData &&
    self.queued_backref_len == 0 &&
    self.queued_rle_len == 0 &&
    self.nbits >= 15 &&
    (self.peak_bits(15).to_uint() & self.eof_mask) == self.eof_code {
    self.consume_bits(self.eof_bits)
    self.state = self.end_of_block()
  }
  output_index
}

///|
/// Decompresses a chunk of data.
///
/// Returns the number of bytes written to `output` (and sets `in_consumed`
/// to the number of bytes read from `input`), or an error if the deflate
/// stream is not valid. `input` is the compressed data. `output[out_start..
/// out_end]` is the buffer to write the decompressed data to, starting at
/// index `output_position` of that slice. `end_of_input` indicates whether
/// more data may be available in the future.
///
/// The contents of `output` after `output_position` are ignored. However,
/// this function may write additional data to `output` past what is
/// indicated by the return value.
///
/// When this function returns, at least one of the following is true:
/// - The input is fully consumed.
/// - The output is full but there are more bytes to output.
/// - The deflate stream is complete (and `is_done` will return true).
fn Decompressor::read(
  self : Decompressor,
  input : BytesView,
  output : FixedArray[Byte],
  out_start : Int,
  out_end : Int,
  output_position : Int,
  end_of_input : Bool,
) -> Int raise DecompressionError {
  self.in_consumed = 0
  if self.state is Done {
    return 0
  }
  guard! out_start >= 0 &&
    out_start <= out_end &&
    out_end <= output.length() &&
    output_position >= 0 &&
    output_position <= out_end - out_start
  self.input = input.data()
  self.in_pos = input.start_offset()
  self.in_end = self.in_pos + input.length()
  let in_start = self.in_pos
  let output_position = out_start + output_position
  let mut output_index = output_position
  if self.queued_rle_len > 0 {
    let data = self.queued_rle_data
    let len = self.queued_rle_len
    self.queued_rle_len = 0
    let n = @cmp.minimum(len, out_end - output_index)
    output.fill(data, start=output_index, end=output_index + n)
    output_index += n
    if n < len {
      self.queued_rle_len = len - n
      self.input = b""
      return n
    }
  }
  if self.queued_backref_len > 0 {
    let dist = self.queued_backref_dist
    let len = self.queued_backref_len
    self.queued_backref_len = 0
    let n = @cmp.minimum(len, out_end - output_index)
    for i in 0..<n {
      output[output_index + i] = output[output_index + i - dist]
    }
    output_index += n
    if n < len {
      self.queued_backref_len = len - n
      self.input = b""
      return output_index - output_position
    }
  }

  // Main decoding state machine.
  let mut first = true
  let mut last_state = self.state
  while first || last_state != self.state {
    first = false
    last_state = self.state
    match self.state {
      ZlibHeader => {
        self.fill_buffer()
        if self.nbits < 16 {
          break
        }
        let input0 = self.peak_bits(8).to_int()
        let input1 = (self.peak_bits(16) >> 8).to_int() & 0xff
        if (input0 & 0x0f) != 0x08 ||
          (input0 & 0xf0) > 0x70 ||
          (input1 & 0x20) != 0 ||
          ((input0 << 8) | input1) % 31 != 0 {
          raise BadZlibHeader
        }
        self.consume_bits(16)
        self.state = BlockHeader
      }
      BlockHeader => self.read_block_header()
      CodeLengthCodes => self.read_code_length_codes()
      CodeLengths => self.read_code_lengths()
      CompressedData =>
        output_index = self.read_compressed(
          output, out_start, out_end, output_index,
        )
      UncompressedData => {
        // Drain any bytes from our buffer.
        while self.nbits > 0 &&
              self.uncompressed_bytes_left > 0 &&
              output_index < out_end {
          output[output_index] = self.peak_bits(8).to_byte()
          self.consume_bits(8)
          output_index += 1
          self.uncompressed_bytes_left -= 1
        }
        // Buffer may contain one additional byte. Clear it to avoid confusion.
        if self.nbits == 0 {
          self.buffer = 0
        }

        // Copy subsequent bytes directly from the input.
        let copy_bytes = @cmp.minimum(
          @cmp.minimum(self.uncompressed_bytes_left, self.in_end - self.in_pos),
          out_end - output_index,
        )
        output.blit_from_bytes(
          output_index,
          self.input,
          self.in_pos,
          copy_bytes,
        )
        self.in_pos += copy_bytes
        output_index += copy_bytes
        self.uncompressed_bytes_left -= copy_bytes
        if self.uncompressed_bytes_left == 0 {
          self.state = self.end_of_block()
        }
      }
      Checksum => {
        self.fill_buffer()
        let align_bits = self.nbits % 8
        if self.nbits >= 32 + align_bits {
          if !self.ignore_adler32 {
            self.checksum = adler32_fixed(
              self.checksum,
              output,
              output_position,
              output_index - output_position,
            )
          }
          if align_bits != 0 {
            self.consume_bits(align_bits)
          }
          if !self.ignore_adler32 &&
            swap_bytes32(self.peak_bits(32).to_uint()) != self.checksum {
            raise WrongChecksum
          }
          self.state = Done
          self.consume_bits(32)
          break
        }
      }
      Done => panic()
    }
  }
  if !self.ignore_adler32 && !(self.state is Done) {
    self.checksum = adler32_fixed(
      self.checksum,
      output,
      output_position,
      output_index - output_position,
    )
  }
  if self.state is Done || !end_of_input || output_index == out_end {
    self.in_consumed = self.in_pos - in_start
    self.input = b""
    output_index - output_position
  } else {
    raise InsufficientInput
  }
}

///|
/// Upstream `u32::swap_bytes`.
fn swap_bytes32(v : UInt) -> UInt {
  (v >> 24) | ((v >> 8) & 0xff00) | ((v << 8) & 0xff0000) | (v << 24)
}

///|
/// Returns true if the decompressor has finished decompressing the input.
fn Decompressor::is_done(self : Decompressor) -> Bool {
  self.state is Done
}

///|
/// The result of `decompress_to_vec_bounded` when it is not the output.
priv suberror BoundedDecompressionError {
  /// The input is not a valid deflate stream.
  Invalid(DecompressionError)
  /// The output is too large.
  OutputTooLarge
}

///|
/// Decompress the given data, returning an error if the output is larger
/// than `maxlen` bytes (upstream `decompress_to_vec_bounded`). Upstream's
/// `Vec` is a buffer of at least its length here.
fn decompress_to_vec_bounded(
  input : BytesView,
  maxlen : Int,
) -> Bytes raise BoundedDecompressionError {
  let decoder = Decompressor::new()
  let mut output_len = @cmp.minimum(1024, maxlen)
  let mut output = FixedArray::make(output_len, b'\x00')
  let mut input_index = 0
  let mut output_index = 0
  while true {
    let produced = decoder.read(
      input[input_index:],
      output,
      0,
      output_len,
      output_index,
      true,
    ) catch {
      err => raise Invalid(err)
    }
    input_index += decoder.in_consumed
    output_index += produced
    if decoder.is_done() || output_index == maxlen {
      break
    }
    // `output.resize((output_index + 32 * 1024).min(maxlen), 0)`
    output_len = if maxlen - output_index < 32 * 1024 {
      maxlen
    } else {
      output_index + 32 * 1024
    }
    if output_len > output.length() {
      let capacity = if output.length() > maxlen / 2 {
        maxlen
      } else {
        @cmp.maximum(output_len, 2 * output.length())
      }
      let grown = FixedArray::make(capacity, b'\x00')
      output.blit_to(grown, len=output_index)
      output = grown
    }
  }
  if decoder.is_done() {
    Bytes::from_array(output[:output_index])
  } else {
    raise OutputTooLarge
  }
}
