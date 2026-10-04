// Port of `hayro-syntax/src/crypto/md5.rs`.
//
// Ported from <https://github.com/mozilla/pdf.js/blob/master/src/core/calculate_md5.js>.

///|
let md5_shift_amounts : ReadOnlyArray[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
  14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

///|
let md5_constants : ReadOnlyArray[UInt] = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613,
  0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193,
  0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d,
  0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122,
  0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
  0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244,
  0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb,
  0xeb86d391,
]

///|
/// Upstream `md5::calculate`. Returns 16 bytes.
fn md5_calculate(data : BytesView) -> Bytes {
  let state : FixedArray[UInt] = [
    0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476,
  ]
  let original_len = data.length()
  let message : Array[Byte] = Array::new(capacity=original_len + 72)
  for b in data {
    message.push(b)
  }
  message.push(0x80)
  while message.length() % 64 != 56 {
    message.push(0)
  }
  write_u64_le(message, original_len.to_uint64() * 8)
  let words : FixedArray[UInt] = FixedArray::make(16, 0)
  for chunk = 0; chunk + 64 <= message.length(); chunk = chunk + 64 {
    for j in 0..<16 {
      words[j] = read_u32_le(message, chunk + j * 4)
    }
    let working_vars = state.copy()
    for i in 0..<64 {
      let (f, g) = if i <= 15 {
        (
          (working_vars[1] & working_vars[2]) |
          (working_vars[1].lnot() & working_vars[3]),
          i,
        )
      } else if i <= 31 {
        (
          (working_vars[3] & working_vars[1]) |
          (working_vars[3].lnot() & working_vars[2]),
          (5 * i + 1) % 16,
        )
      } else if i <= 47 {
        (working_vars[1] ^ working_vars[2] ^ working_vars[3], (3 * i + 5) % 16)
      } else {
        (
          working_vars[2] ^ (working_vars[1] | working_vars[3].lnot()),
          7 * i % 16,
        )
      }
      let temp = working_vars[3]
      working_vars[3] = working_vars[2]
      working_vars[2] = working_vars[1]
      working_vars[1] = working_vars[1] +
        rotl32(
          working_vars[0] + f + md5_constants[i] + words[g],
          md5_shift_amounts[i],
        )
      working_vars[0] = temp
    }
    for i in 0..<4 {
      state[i] = state[i] + working_vars[i]
    }
  }
  let result : Array[Byte] = Array::new(capacity=16)
  for word in state {
    write_u32_le(result, word)
  }
  Bytes::from_array(result[:])
}

// Byte/word helpers shared by the crypto modules (upstream uses
// `from_le_bytes`/`to_be_bytes`/`rotate_left`/... of the Rust integer types;
// MoonBit's `UInt`/`UInt64` arithmetic wraps like Rust's `wrapping_*`).

///|
fn rotl32(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

///|
fn rotr32(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

///|
fn rotr64(x : UInt64, n : Int) -> UInt64 {
  (x >> n) | (x << (64 - n))
}

///|
fn read_u32_le(data : Array[Byte], i : Int) -> UInt {
  data[i].to_uint() |
  (data[i + 1].to_uint() << 8) |
  (data[i + 2].to_uint() << 16) |
  (data[i + 3].to_uint() << 24)
}

///|
fn read_u32_be(data : FixedArray[Byte], i : Int) -> UInt {
  (data[i].to_uint() << 24) |
  (data[i + 1].to_uint() << 16) |
  (data[i + 2].to_uint() << 8) |
  data[i + 3].to_uint()
}

///|
fn read_u64_be(data : FixedArray[Byte], i : Int) -> UInt64 {
  let mut v = 0UL
  for j in 0..<8 {
    v = (v << 8) | data[i + j].to_uint64()
  }
  v
}

///|
fn write_u32_le(out : Array[Byte], v : UInt) -> Unit {
  for j in 0..<4 {
    out.push((v >> (8 * j)).to_byte())
  }
}

///|
fn write_u64_le(out : Array[Byte], v : UInt64) -> Unit {
  for j in 0..<8 {
    out.push((v >> (8 * j)).to_byte())
  }
}

///|
fn write_u32_be(out : Array[Byte], v : UInt) -> Unit {
  for j in 0..<4 {
    out.push((v >> (8 * (3 - j))).to_byte())
  }
}

///|
fn write_u64_be(out : Array[Byte], v : UInt64) -> Unit {
  for j in 0..<8 {
    out.push((v >> (8 * (7 - j))).to_byte())
  }
}
