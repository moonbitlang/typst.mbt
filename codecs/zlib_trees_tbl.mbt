// Port of zlib-rs 0.6.8 `src/deflate/trees_tbl.rs`. Upstream spells the
// tables out; they are the standard zlib tables, computed here the way zlib's
// `tr_static_init` builds them.

///|
/// Number of length codes, not counting the special END_BLOCK code.
const LENGTH_CODES : Int = 29

///|
/// Number of literal bytes 0..255.
const LITERALS : Int = 256

///|
/// Number of Literal or Length codes, including the END_BLOCK code.
const L_CODES : Int = 286 // LITERALS + 1 + LENGTH_CODES

///|
/// Number of distance codes.
const D_CODES : Int = 30

///|
/// Number of codes used to transfer the bit lengths.
const BL_CODES : Int = 19

///|
/// Maximum heap size.
const HEAP_SIZE : Int = 573 // 2 * L_CODES + 1

///|
/// All codes must not exceed MAX_BITS bits.
const MAX_BITS : Int = 15

///|
/// Bit length codes must not exceed MAX_BL_BITS bits.
const MAX_BL_BITS : Int = 7

///|
/// Extra bits for each length code.
let extra_lbits : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
/// Extra bits for each distance code.
let extra_dbits : FixedArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
/// Extra bits for each bit length code.
let extra_blbits : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 7,
]

///|
/// The lengths of the bit length codes are sent in order of decreasing
/// probability, to avoid transmitting the lengths for unused bit length codes.
let bl_order : FixedArray[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
/// Reverses the first `len` bits of a code.
fn bi_reverse(code : Int, len : Int) -> Int {
  let mut code = code
  let mut res = 0
  for _ in 0..<len {
    res = (res << 1) | (code & 1)
    code = code >> 1
  }
  res
}

///|
/// Length code for each normalized match length (0 == STD_MIN_MATCH).
let length_code : FixedArray[Int] = {
  let table = FixedArray::make(256, 0)
  let mut length = 0
  for code in 0..<(LENGTH_CODES - 1) {
    for _ in 0..<(1 << extra_lbits[code]) {
      table[length] = code
      length += 1
    }
  }
  // Note that the length 255 (match length 258) can be represented in two
  // different ways: code 284 + 5 bits or code 285, so we overwrite
  // length_code[255] to use the best encoding.
  table[length - 1] = LENGTH_CODES - 1
  table
}

///|
/// First normalized length for each code (0 = STD_MIN_MATCH).
let base_length : FixedArray[Int] = {
  let table = FixedArray::make(LENGTH_CODES, 0)
  let mut length = 0
  for code in 0..<(LENGTH_CODES - 1) {
    table[code] = length
    length += 1 << extra_lbits[code]
  }
  table
}

///|
/// Distance codes. The first 256 values correspond to the distances 3 ..
/// 258, the last 256 values correspond to the top 8 bits of the 15 bit
/// distances.
let dist_code : FixedArray[Int] = {
  let table = FixedArray::make(512, 0)
  let mut dist = 0
  for code in 0..<16 {
    for _ in 0..<(1 << extra_dbits[code]) {
      table[dist] = code
      dist += 1
    }
  }
  dist = dist >> 7 // from now on, all distances are divided by 128
  for code in 16..<D_CODES {
    for _ in 0..<(1 << (extra_dbits[code] - 7)) {
      table[256 + dist] = code
      dist += 1
    }
  }
  table
}

///|
/// First normalized distance for each code (0 = distance of 1).
let base_dist : FixedArray[Int] = {
  let table = FixedArray::make(D_CODES, 0)
  let mut dist = 0
  for code in 0..<16 {
    table[code] = dist
    dist += 1 << extra_dbits[code]
  }
  dist = dist >> 7
  for code in 16..<D_CODES {
    table[code] = dist << 7
    dist += 1 << (extra_dbits[code] - 7)
  }
  table
}

///|
/// The static literal tree (codes and lengths). Since the bit lengths are
/// imposed, there is no need for the L_CODES extra codes used during heap
/// construction. However the codes 286 and 287 are needed to build a
/// canonical tree.
let static_ltree : (FixedArray[Int], FixedArray[Int]) = {
  let codes = FixedArray::make(L_CODES + 2, 0)
  let lens = FixedArray::make(L_CODES + 2, 0)
  let bl_count = FixedArray::make(MAX_BITS + 1, 0)
  for n in 0..<(L_CODES + 2) {
    let len = if n <= 143 {
      8
    } else if n <= 255 {
      9
    } else if n <= 279 {
      7
    } else {
      8
    }
    lens[n] = len
    bl_count[len] += 1
  }
  gen_codes(codes, lens, L_CODES + 1, bl_count)
  (codes, lens)
}

///|
/// The static distance tree. (Actually a trivial tree since all codes use 5
/// bits.)
let static_dtree : (FixedArray[Int], FixedArray[Int]) = (
  FixedArray::makei(D_CODES, n => bi_reverse(n, 5)),
  FixedArray::make(D_CODES, 5),
)
