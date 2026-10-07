// Port of `fdeflate` 0.3.7 `src/huffman.rs` and of the decoding tables of
// `src/tables.rs`: the Huffman tables of the decompressor
// (`fdeflate_decompress.mbt`).

///|
const LITERAL_ENTRY : UInt = 0x8000

///|
const EXCEPTIONAL_ENTRY : UInt = 0x4000

///|
const SECONDARY_TABLE_ENTRY : UInt = 0x2000

///|
/// Order of the length code length alphabet (derived from deflate spec).
let fdeflate_clcl_order : ReadOnlyArray[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
/// Number of extra bits for each length code (derived from deflate spec).
let fdeflate_len_sym_to_len_extra : ReadOnlyArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
/// The base length for each length code (derived from deflate spec).
let fdeflate_len_sym_to_len_base : ReadOnlyArray[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
/// Number of extra bits for each distance code (derived from deflate spec.)
let fdeflate_dist_sym_to_dist_extra : ReadOnlyArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
/// The base distance for each distance code (derived from deflate spec).
let fdeflate_dist_sym_to_dist_base : ReadOnlyArray[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
/// Which table of entries `build_table` fills the primary table from
/// (upstream passes a slice: `&[]`, `LITLEN_TABLE_ENTRIES` or
/// `DISTANCE_TABLE_ENTRIES`).
priv enum HuffmanEntries {
  /// `&[]`: the entry of a symbol is `symbol << 16`.
  Plain
  Litlen
  Distance
}

///|
/// Upstream `entries.get(symbol).cloned().unwrap_or((symbol as u32) << 16)`.
///
/// The main litlen_table uses a 12-bit input to lookup the meaning of the
/// symbol. The table is split into 4 sections:
///
///   aaaaaaaa_bbbbbbbb_1000yyyy_0000xxxx  x = input_advance_bits, y = output_advance_bytes (literal)
///   0000000z_zzzzzzzz_00000yyy_0000xxxx  x = input_advance_bits, y = extra_bits, z = distance_base (length)
///   00000000_00000000_01000000_0000xxxx  x = input_advance_bits (EOF)
///   0000xxxx_xxxxxxxx_01100000_00000000  x = secondary_table_index
///   00000000_00000000_01000000_00000000  invalid code
///
/// The distance table is a 512-entry table that maps 9 bits of distance
/// symbols to their meaning.
///
///   00000000_00000000_00000000_00000000     symbol is more than 9 bits
///   zzzzzzzz_zzzzzzzz_0000yyyy_0000xxxx     x = input_advance_bits, y = extra_bits, z = distance_base
fn HuffmanEntries::get(self : HuffmanEntries, symbol : Int) -> UInt {
  match self {
    Plain => symbol.reinterpret_as_uint() << 16
    Litlen =>
      // `LITLEN_TABLE_ENTRIES` (288 entries; symbols are below 288)
      if symbol < 256 {
        (symbol.reinterpret_as_uint() << 16) | LITERAL_ENTRY | (1U << 8)
      } else if symbol >= 257 && symbol < 286 {
        (fdeflate_len_sym_to_len_base[symbol - 257].reinterpret_as_uint() << 16) |
        (fdeflate_len_sym_to_len_extra[symbol - 257].reinterpret_as_uint() << 8)
      } else {
        EXCEPTIONAL_ENTRY
      }
    Distance =>
      // `DISTANCE_TABLE_ENTRIES` (32 entries; symbols are below 32)
      if symbol < 30 {
        (fdeflate_dist_sym_to_dist_base[symbol].reinterpret_as_uint() << 16) |
        (fdeflate_dist_sym_to_dist_extra[symbol].reinterpret_as_uint() << 8) |
        LITERAL_ENTRY
      } else {
        0
      }
  }
}

///|
/// Return the next code, or if the codeword is already all ones (which is the
/// final code), return the same code again.
fn next_codeword(codeword : Int, table_size : Int) -> Int {
  if codeword == table_size - 1 {
    return codeword
  }
  // `(u16::BITS - 1) - (codeword ^ (table_size - 1)).leading_zeros()`
  let adv = 31 - (codeword ^ (table_size - 1)).clz()
  let bit = 1 << adv
  (codeword & (bit - 1)) | bit
}

///|
/// Upstream `build_table`. `lengths` is `code_lengths[lengths_start..
/// lengths_start + lengths_len]`; `codes` is indexed by symbol; the primary
/// table has `1 << primary_table_bits` entries.
fn build_table(
  code_lengths : FixedArray[Int],
  lengths_start : Int,
  lengths_len : Int,
  entries : HuffmanEntries,
  codes : FixedArray[Int],
  primary_table : FixedArray[UInt],
  primary_table_bits : Int,
  secondary_table : Array[UInt],
  is_distance_table : Bool,
  double_literal : Bool,
) -> Bool {
  // Count the number of symbols with each code length.
  let histogram = FixedArray::make(16, 0)
  for i in 0..<lengths_len {
    let length = code_lengths[lengths_start + i]
    histogram[length] += 1
  }

  // Determine the maximum code length.
  let mut max_length = 15
  while max_length > 1 && histogram[max_length] == 0 {
    max_length -= 1
  }

  // Handle zero and one symbol huffman codes (which are only allowed for distance codes).
  if is_distance_table {
    if max_length == 0 {
      primary_table.fill(0)
      secondary_table.clear()
      return true
    } else if max_length == 1 && histogram[1] == 1 {
      let mut symbol = 0
      while code_lengths[lengths_start + symbol] != 1 {
        symbol += 1
      }
      codes[symbol] = 0
      let entry = entries.get(symbol) | 1
      for i = 0; i < primary_table.length(); i = i + 2 {
        primary_table[i] = entry
        if i + 1 < primary_table.length() {
          primary_table[i + 1] = 0
        }
      }
      return true
    }
  }

  // Sort symbols by code length. Given the histogram, we can determine the starting offset
  // for each code length.
  let offsets = FixedArray::make(16, 0)
  let mut codespace_used = 0
  offsets[1] = histogram[0]
  for i in 1..<max_length {
    offsets[i + 1] = offsets[i] + histogram[i]
    codespace_used = (codespace_used << 1) + histogram[i]
  }
  codespace_used = (codespace_used << 1) + histogram[max_length]

  // Check that the provided lengths form a valid Huffman tree.
  if codespace_used != 1 << max_length {
    return false
  }

  // Sort the symbols by code length.
  let next_index = offsets.copy()
  let sorted_symbols = FixedArray::make(288, 0)
  for symbol in 0..<lengths_len {
    let length = code_lengths[lengths_start + symbol]
    sorted_symbols[next_index[length]] = symbol
    next_index[length] += 1
  }
  let mut codeword = 0
  let mut i = histogram[0]

  // Populate the primary decoding table
  let primary_table_mask = (1 << primary_table_bits) - 1
  for length in 1..<=primary_table_bits {
    let current_table_end = 1 << length

    // Loop over all symbols with the current code length and set their table entries.
    for _ in 0..<histogram[length] {
      let symbol = sorted_symbols[i]
      i += 1
      primary_table[codeword] = entries.get(symbol) |
        length.reinterpret_as_uint()
      codes[symbol] = codeword
      codeword = next_codeword(codeword, current_table_end)
    }
    if double_literal {
      for len1 in 1..<(length - 1) {
        let len2 = length - len1
        for sym1_index in offsets[len1]..<next_index[len1] {
          for sym2_index in offsets[len2]..<next_index[len2] {
            let sym1 = sorted_symbols[sym1_index]
            let sym2 = sorted_symbols[sym2_index]
            if sym1 < 256 && sym2 < 256 {
              let codeword1 = codes[sym1]
              let codeword2 = codes[sym2]
              let codeword = codeword1 | (codeword2 << len1)
              let entry = (sym1.reinterpret_as_uint() << 16) |
                (sym2.reinterpret_as_uint() << 24) |
                LITERAL_ENTRY |
                (2U << 8)
              primary_table[codeword] = entry | length.reinterpret_as_uint()
            }
          }
        }
      }
    }

    // If we aren't at the maximum table size, double the size of the table.
    if length < primary_table_bits {
      primary_table.unsafe_blit(
        current_table_end, primary_table, 0, current_table_end,
      )
    }
  }

  // Populate the secondary decoding table.
  secondary_table.clear()
  if max_length > primary_table_bits {
    let mut subtable_start = 0
    // `!0` as a `u16`
    let mut subtable_prefix = 0xFFFF
    for length in (primary_table_bits + 1)..<=max_length {
      let subtable_size = 1 << (length - primary_table_bits)
      for _ in 0..<histogram[length] {
        // If the codeword's prefix doesn't match the current subtable, create a new
        // subtable.
        if (codeword & primary_table_mask) != subtable_prefix {
          subtable_prefix = codeword & primary_table_mask
          subtable_start = secondary_table.length()
          primary_table[subtable_prefix] = (
              subtable_start.reinterpret_as_uint() << 16
            ) |
            EXCEPTIONAL_ENTRY |
            SECONDARY_TABLE_ENTRY |
            (subtable_size - 1).reinterpret_as_uint()
          for _ in 0..<subtable_size {
            secondary_table.push(0)
          }
        }

        // Lookup the symbol.
        let symbol = sorted_symbols[i]
        i += 1

        // Insert the symbol into the secondary table and advance to the next codeword.
        codes[symbol] = codeword
        secondary_table[subtable_start + (codeword >> primary_table_bits)] = ((
          symbol << 4
        ) |
        length).reinterpret_as_uint()
        codeword = next_codeword(codeword, 1 << length)
      }

      // If there are more codes with the same subtable prefix, extend the subtable.
      if length < max_length &&
        (codeword & primary_table_mask) == subtable_prefix {
        // `secondary_table.extend_from_within(subtable_start..)`
        let end = secondary_table.length()
        for k in subtable_start..<end {
          secondary_table.push(secondary_table[k])
        }
        let subtable_size = secondary_table.length() - subtable_start
        primary_table[subtable_prefix] = (
            subtable_start.reinterpret_as_uint() << 16
          ) |
          EXCEPTIONAL_ENTRY |
          SECONDARY_TABLE_ENTRY |
          (subtable_size - 1).reinterpret_as_uint()
      }
    }
  }
  true
}
