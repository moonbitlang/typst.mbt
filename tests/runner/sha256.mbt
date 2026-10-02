// SHA-256 (FIPS 180-4), used to identify font and image assets in the
// `typst-frame-v1` dump like the oracle does (`sha2::Sha256`).

///|
let sha256_k : FixedArray[UInt] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

///|
/// The lowercase hex SHA-256 digest of some bytes.
fn sha256_hex(data : BytesView) -> String {
  let h : FixedArray[UInt] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
    0x5be0cd19,
  ]
  let len = data.length()
  // Message plus 0x80, padding and the 64-bit bit length.
  let total = (len + 9 + 63) / 64 * 64
  let w : FixedArray[UInt] = FixedArray::make(64, 0)
  fn byte_at(i : Int) -> UInt {
    if i < len {
      data[i].to_uint()
    } else if i == len {
      0x80
    } else if i >= total - 8 {
      let bits = len.to_uint64() * 8
      let shift = (total - 1 - i) * 8
      ((bits >> shift) & 0xff).to_uint()
    } else {
      0
    }
  }
  for block = 0; block < total; block = block + 64 {
    for t in 0..<16 {
      let i = block + t * 4
      // Fast path for full blocks inside the message.
      w[t] = if i + 3 < len {
        (data[i].to_uint() << 24) |
        (data[i + 1].to_uint() << 16) |
        (data[i + 2].to_uint() << 8) |
        data[i + 3].to_uint()
      } else {
        (byte_at(i) << 24) |
        (byte_at(i + 1) << 16) |
        (byte_at(i + 2) << 8) |
        byte_at(i + 3)
      }
    }
    for t in 16..<64 {
      let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
      let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
      w[t] = w[t - 16] + s0 + w[t - 7] + s1
    }
    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut hh = h[7]
    for t in 0..<64 {
      let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ (e.lnot() & g)
      let t1 = hh + s1 + ch + sha256_k[t] + w[t]
      let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let t2 = s0 + maj
      hh = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    }
    h[0] = h[0] + a
    h[1] = h[1] + b
    h[2] = h[2] + c
    h[3] = h[3] + d
    h[4] = h[4] + e
    h[5] = h[5] + f
    h[6] = h[6] + g
    h[7] = h[7] + hh
  }
  let out = StringBuilder()
  for word in h {
    out.write_string(hex_padded(word.to_uint64(), 8))
  }
  out.to_string()
}

///|
/// `v` in lowercase hex, zero-padded to `width` digits.
fn hex_padded(v : UInt64, width : Int) -> String {
  let s = v.to_string(radix=16)
  "0".repeat(width - s.length()) + s
}

///|
test "sha256" {
  inspect(
    sha256_hex(b""[:]),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  inspect(
    sha256_hex(b"abc"[:]),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  // Two blocks (56 bytes).
  inspect(
    sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"[:]),
    content="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}
