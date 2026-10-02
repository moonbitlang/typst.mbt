// A DEFLATE (RFC 1951) decompressor with zlib (RFC 1950) and gzip (RFC 1952)
// framing. Upstream uses `fdeflate::decompress_to_vec_bounded` (for PNG
// `iCCP` chunks) and `flate2`'s `GzDecoder` (for SVGZ files); decompression
// is deterministic, so any conforming implementation yields the same bytes.

///|
/// A decompression error.
pub(all) suberror InflateError {
  InflateError(String)
} derive(Debug)

///|
priv struct BitReader {
  data : BytesView
  mut pos : Int
  mut bit_buf : UInt
  mut bit_count : Int
}

///|
fn BitReader::bits(self : BitReader, n : Int) -> Int raise InflateError {
  while self.bit_count < n {
    if self.pos >= self.data.length() {
      raise InflateError("unexpected end of stream")
    }
    self.bit_buf = self.bit_buf |
      (self.data[self.pos].to_uint() << self.bit_count)
    self.pos += 1
    self.bit_count += 8
  }
  let v = self.bit_buf & ((1U << n) - 1)
  self.bit_buf = if n == 32 { 0 } else { self.bit_buf >> n }
  self.bit_count -= n
  v.reinterpret_as_int()
}

///|
/// A canonical Huffman decoding table: symbol counts per length and the
/// symbols sorted by code.
priv struct Huffman {
  counts : FixedArray[Int]
  symbols : FixedArray[Int]
}

///|
fn Huffman::new(lengths : ArrayView[Int]) -> Huffman raise InflateError {
  let counts = FixedArray::make(16, 0)
  for len in lengths {
    counts[len] += 1
  }
  counts[0] = 0
  let offs = FixedArray::make(16, 0)
  let mut left = 1
  for len in 1..<16 {
    left = left * 2 - counts[len]
    if left < 0 {
      raise InflateError("invalid Huffman code lengths")
    }
    if len < 15 {
      offs[len + 1] = offs[len] + counts[len]
    }
  }
  let symbols = FixedArray::make(lengths.length(), 0)
  for sym, len in lengths {
    if len != 0 {
      symbols[offs[len]] = sym
      offs[len] += 1
    }
  }
  { counts, symbols, }
}

///|
fn BitReader::decode(self : BitReader, h : Huffman) -> Int raise InflateError {
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for len in 1..<16 {
    code = code | self.bits(1)
    let count = h.counts[len]
    if code - count < first {
      return h.symbols[index + (code - first)]
    }
    index += count
    first += count
    first = first << 1
    code = code << 1
  }
  raise InflateError("invalid Huffman code")
}

///|
let inflate_len_base : FixedArray[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let inflate_len_extra : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let inflate_dist_base : FixedArray[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let inflate_dist_extra : FixedArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
/// The order of the code length code lengths.
let inflate_clcl_order : FixedArray[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
/// Decompresses a raw DEFLATE stream starting at `pos`. Returns the output
/// and the position after the stream.
fn inflate_raw(data : BytesView, pos : Int) -> (Bytes, Int) raise InflateError {
  let r = { data, pos, bit_buf: 0, bit_count: 0, }
  let out : Array[Byte] = []
  let mut last = false
  while !last {
    last = r.bits(1) == 1
    match r.bits(2) {
      0 => {
        // Stored block.
        r.bit_buf = 0
        r.bit_count = 0
        if r.pos + 4 > data.length() {
          raise InflateError("unexpected end of stream")
        }
        let len = data[r.pos].to_int() | (data[r.pos + 1].to_int() << 8)
        let nlen = data[r.pos + 2].to_int() | (data[r.pos + 3].to_int() << 8)
        if len != (nlen ^ 0xFFFF) {
          raise InflateError("invalid stored block length")
        }
        r.pos += 4
        if r.pos + len > data.length() {
          raise InflateError("unexpected end of stream")
        }
        for i in 0..<len {
          out.push(data[r.pos + i])
        }
        r.pos += len
      }
      1 => {
        let lengths = Array::make(288, 8)
        for i in 144..<256 {
          lengths[i] = 9
        }
        for i in 256..<280 {
          lengths[i] = 7
        }
        let litlen = Huffman::new(lengths[:])
        let dist = Huffman::new(Array::make(30, 5)[:])
        inflate_block(r, out, litlen, dist)
      }
      2 => {
        let hlit = r.bits(5) + 257
        let hdist = r.bits(5) + 1
        let hclen = r.bits(4) + 4
        let cl_lengths = Array::make(19, 0)
        for i in 0..<hclen {
          cl_lengths[inflate_clcl_order[i]] = r.bits(3)
        }
        let cl = Huffman::new(cl_lengths[:])
        let lengths = Array::make(hlit + hdist, 0)
        let mut i = 0
        while i < hlit + hdist {
          let sym = r.decode(cl)
          if sym < 16 {
            lengths[i] = sym
            i += 1
          } else {
            let (value, repeat) = match sym {
              16 => {
                if i == 0 {
                  raise InflateError("invalid code length repeat")
                }
                (lengths[i - 1], 3 + r.bits(2))
              }
              17 => (0, 3 + r.bits(3))
              _ => (0, 11 + r.bits(7))
            }
            if i + repeat > hlit + hdist {
              raise InflateError("invalid code length repeat")
            }
            for _ in 0..<repeat {
              lengths[i] = value
              i += 1
            }
          }
        }
        let litlen = Huffman::new(lengths[0:hlit])
        let dist = Huffman::new(lengths[hlit:])
        inflate_block(r, out, litlen, dist)
      }
      _ => raise InflateError("invalid block type")
    }
  }
  (Bytes::from_array(out[:]), r.pos)
}

///|
fn inflate_block(
  r : BitReader,
  out : Array[Byte],
  litlen : Huffman,
  dist : Huffman,
) -> Unit raise InflateError {
  while true {
    let sym = r.decode(litlen)
    if sym < 256 {
      out.push(sym.to_byte())
    } else if sym == 256 {
      return
    } else {
      let sym = sym - 257
      if sym >= 29 {
        raise InflateError("invalid length symbol")
      }
      let len = inflate_len_base[sym] + r.bits(inflate_len_extra[sym])
      let dsym = r.decode(dist)
      if dsym >= 30 {
        raise InflateError("invalid distance symbol")
      }
      let d = inflate_dist_base[dsym] + r.bits(inflate_dist_extra[dsym])
      if d > out.length() {
        raise InflateError("invalid distance")
      }
      let start = out.length() - d
      for i in 0..<len {
        out.push(out[start + i])
      }
    }
  }
}

///|
/// Decompresses a zlib stream, validating the header and the Adler-32
/// checksum.
pub fn zlib_decompress(data : BytesView) -> Bytes raise InflateError {
  if data.length() < 2 {
    raise InflateError("unexpected end of stream")
  }
  let cmf = data[0].to_int()
  let flg = data[1].to_int()
  if (cmf & 0x0F) != 8 || (cmf * 256 + flg) % 31 != 0 || (flg & 0x20) != 0 {
    raise InflateError("invalid zlib header")
  }
  let (out, pos) = inflate_raw(data, 2)
  if pos + 4 > data.length() {
    raise InflateError("unexpected end of stream")
  }
  let checksum = Adler32::new()
  checksum.write(out[:])
  if checksum.finish() != u32_be(data, pos) {
    raise InflateError("wrong checksum")
  }
  out
}

///|
/// Decompresses a gzip stream (a single member), validating the CRC-32 and
/// the size.
pub fn gzip_decompress(data : BytesView) -> Bytes raise InflateError {
  if data.length() < 10 || data[0] != b'\x1f' || data[1] != b'\x8b' {
    raise InflateError("invalid gzip header")
  }
  if data[2] != b'\x08' {
    raise InflateError("unsupported compression method")
  }
  let flags = data[3].to_int()
  let mut pos = 10
  if (flags & 0x04) != 0 {
    // FEXTRA
    if pos + 2 > data.length() {
      raise InflateError("unexpected end of stream")
    }
    pos += 2 + (data[pos].to_int() | (data[pos + 1].to_int() << 8))
  }
  for flag in [0x08, 0x10] {
    // FNAME, FCOMMENT: zero-terminated strings.
    if (flags & flag) != 0 {
      while pos < data.length() && data[pos] != b'\x00' {
        pos += 1
      }
      pos += 1
    }
  }
  if (flags & 0x02) != 0 {
    // FHCRC
    pos += 2
  }
  if pos > data.length() {
    raise InflateError("unexpected end of stream")
  }
  let (out, pos) = inflate_raw(data, pos)
  if pos + 8 > data.length() {
    raise InflateError("unexpected end of stream")
  }
  if crc32([out[:]]) != u32_le(data, pos) ||
    out.length().reinterpret_as_uint() != u32_le(data, pos + 4) {
    raise InflateError("corrupt gzip stream")
  }
  out
}
