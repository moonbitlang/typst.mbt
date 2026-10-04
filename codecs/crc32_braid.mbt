// Port of zlib-rs 0.6.8 `src/crc32/braid.rs` (`crc32_braid::<5>` with
// `usize` words, W = 8): the table-driven CRC-32 that zlib-rs uses without
// carry-less multiplication. The png crate's crc32fast computes the same
// checksum (with CRC instructions on aarch64). The input is processed from its
// start as if it were word aligned; upstream's alignment prefix only changes
// which bytes go through the byte-wise loop, not the result.

///|
/// The number of braids (upstream's `N`).
const CRC_BRAID_N : Int = 5

///|
/// The word size in bytes (upstream's `W`).
const CRC_WORD : Int = 8

///|
/// Offsets of the tables in [crc32_tables]: `CRC32_BYTE_TABLE`, then
/// `CRC32_WORD_TABLE[0..W]`, then `Crc32BraidTable::<5>::TABLE[0..W]`, 256
/// entries each.
const CRC_WORD_TABLE : Int = 256

///|
const CRC_BRAID_TABLE : Int = 256 + 8 * 256

///|
let crc32_tables_cell : Ref[FixedArray[UInt]?] = { val: None, }

///|
/// The CRC-32 tables, built on first use (upstream evaluates
/// `build_crc32_table` at compile time).
fn crc32_tables() -> FixedArray[UInt] {
  match crc32_tables_cell.val {
    Some(tables) => tables
    None => {
      let tables = build_crc32_tables()
      crc32_tables_cell.val = Some(tables)
      tables
    }
  }
}

///|
/// Upstream `build_crc32_table::<256, W, N>` sets `arr[i][j]` to `j` shifted
/// through the polynomial `8 * (W * N - i)` times. Shifting by eight bits maps
/// `c` to `(c >> 8) ^ CRC32_BYTE_TABLE[c & 0xff]`, so the tables follow from
/// `shifted[m][j]` (`j` shifted `8 * m` times) for `m <= W * N`.
fn build_crc32_tables() -> FixedArray[UInt] {
  let max_shift = CRC_WORD * CRC_BRAID_N
  let shifted = FixedArray::make((max_shift + 1) * 256, 0U)
  for j in 0..<256 {
    let mut c = j.reinterpret_as_uint()
    for _ in 0..<8 {
      c = if (c & 1) != 0 { 0xEDB88320U ^ (c >> 1) } else { c >> 1 }
    }
    shifted[256 + j] = c
  }
  for m in 2..<=max_shift {
    for j in 0..<256 {
      let c = shifted[(m - 1) * 256 + j]
      shifted[m * 256 + j] = (c >> 8) ^
        shifted[256 + (c & 0xff).reinterpret_as_int()]
    }
  }
  let tables = FixedArray::make(CRC_BRAID_TABLE + CRC_WORD * 256, 0U)
  shifted.blit_to(tables, len=256, src_offset=256)
  for i in 0..<CRC_WORD {
    // `build_crc32_table::<256, W, 1>` and `build_crc32_table::<256, W, N>`
    shifted.blit_to(
      tables,
      len=256,
      src_offset=(CRC_WORD - i) * 256,
      dst_offset=CRC_WORD_TABLE + i * 256,
    )
    shifted.blit_to(
      tables,
      len=256,
      src_offset=(max_shift - i) * 256,
      dst_offset=CRC_BRAID_TABLE + i * 256,
    )
  }
  tables
}

///|
/// Upstream `crc32_braid::<5>(start, data)`.
fn crc32_braid(start : UInt, data : BytesView) -> UInt {
  // Unchecked accesses: the table indices are `offset + byte` within the
  // checked table length; the word reads `bytes[base + 8 * w..+ 8]` for `w <
  // words` and the byte reads stay within the view (`base + len <=
  // bytes.length()`).
  let t = crc32_tables()
  guard t.length() == CRC_BRAID_TABLE + CRC_WORD * 256 else {
    abort("bad CRC-32 tables")
  }
  let bytes = data.data()
  let base = data.start_offset()
  let len = data.length()
  let words = len / CRC_WORD
  let mut crc = start.lnot()

  // The last full block goes through `crc32_words_inner` (which rolls the
  // partial CRCs into the final value), hence `saturating_sub(1)`.
  let blocks = @cmp.maximum(words / CRC_BRAID_N - 1, 0)
  let mut crc0 = crc
  let mut crc1 = 0U
  let mut crc2 = 0U
  let mut crc3 = 0U
  let mut crc4 = 0U
  for i in 0..<blocks {
    // Load the next N words.
    let p = base + i * CRC_BRAID_N * CRC_WORD
    let mut b0 = bytes.unsafe_read_uint64_le(p) ^ crc0.to_uint64()
    let mut b1 = bytes.unsafe_read_uint64_le(p + 8) ^ crc1.to_uint64()
    let mut b2 = bytes.unsafe_read_uint64_le(p + 16) ^ crc2.to_uint64()
    let mut b3 = bytes.unsafe_read_uint64_le(p + 24) ^ crc3.to_uint64()
    let mut b4 = bytes.unsafe_read_uint64_le(p + 32) ^ crc4.to_uint64()
    crc0 = 0
    crc1 = 0
    crc2 = 0
    crc3 = 0
    crc4 = 0
    for j in 0..<CRC_WORD {
      // `braid_core`
      let tj = CRC_BRAID_TABLE + j * 256
      crc0 = crc0 ^ t.unsafe_get(tj + (b0 & 0xff).to_int())
      b0 = b0 >> 8
      crc1 = crc1 ^ t.unsafe_get(tj + (b1 & 0xff).to_int())
      b1 = b1 >> 8
      crc2 = crc2 ^ t.unsafe_get(tj + (b2 & 0xff).to_int())
      b2 = b2 >> 8
      crc3 = crc3 ^ t.unsafe_get(tj + (b3 & 0xff).to_int())
      b3 = b3 >> 8
      crc4 = crc4 ^ t.unsafe_get(tj + (b4 & 0xff).to_int())
      b4 = b4 >> 8
    }
  }

  // `crc32_words_inner(&words[blocks * N..], crcs[0], &crcs)` with `crcs[0]`
  // taken (zero).
  crc = crc0
  for i in (blocks * CRC_BRAID_N)..<words {
    let per_word = match i - blocks * CRC_BRAID_N {
      1 => crc1
      2 => crc2
      3 => crc3
      4 => crc4
      _ => 0
    }
    let mut value = bytes.unsafe_read_uint64_le(base + i * CRC_WORD) ^
      (crc ^ per_word).to_uint64()
    crc = 0
    for k in 0..<CRC_WORD {
      crc = crc ^
        t.unsafe_get(CRC_WORD_TABLE + k * 256 + (value & 0xff).to_int())
      value = value >> 8
    }
  }

  // `crc32_naive_inner` over the remaining bytes
  for i in (words * CRC_WORD)..<len {
    let b = bytes.unsafe_get(base + i).to_uint()
    crc = t.unsafe_get(((crc ^ b) & 0xff).reinterpret_as_int()) ^ (crc >> 8)
  }
  crc.lnot()
}
