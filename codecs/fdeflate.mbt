// Port of the compressors of the `fdeflate` crate (v0.3.7, `src/compress.rs`
// and `compute_codes` from `src/lib.rs`), used by the `png` crate's encoder.

///|
let fdeflate_huffman_codes : FixedArray[Int] = compute_codes(
  fdeflate_huffman_lengths,
)

///|
let fdeflate_bitmasks : FixedArray[UInt] = [
  0x0000, 0x0001, 0x0003, 0x0007, 0x000F, 0x001F, 0x003F, 0x007F, 0x00FF, 0x01FF,
  0x03FF, 0x07FF, 0x0FFF, 0x1FFF, 0x3FFF, 0x7FFF, 0xFFFF,
]

///|
/// Computes canonical (bit-reversed) Huffman codes from code lengths.
fn compute_codes(lengths : FixedArray[Int]) -> FixedArray[Int] {
  let codes = FixedArray::make(lengths.length(), 0)
  let mut code = 0U
  for len in 1..<=16 {
    for i in 0..<lengths.length() {
      if lengths[i] == len {
        codes[i] = (reverse_bits16(code & 0xFFFF) >> (16 - len)).reinterpret_as_int()
        code += 1
      }
    }
    code = code << 1
  }
  guard code == 2U << 16 else { abort("HUFFMAN_LENGTHS is invalid") }
  codes
}

///|
/// Upstream `u16::reverse_bits`.
fn reverse_bits16(v : UInt) -> UInt {
  let mut out = 0U
  for i in 0..<16 {
    if ((v >> i) & 1) != 0 {
      out = out | (1U << (15 - i))
    }
  }
  out
}

///|
/// An Adler-32 checksum (upstream `simd_adler32::Adler32`).
struct Adler32 {
  mut a : UInt
  mut b : UInt
}

///|
fn Adler32::new() -> Adler32 {
  { a: 1, b: 0, }
}

///|
fn Adler32::write(self : Adler32, data : BytesView) -> Unit {
  let v = adler32((self.b << 16) | self.a, data)
  self.a = v & 0xffff
  self.b = v >> 16
}

///|
fn Adler32::finish(self : Adler32) -> UInt {
  (self.b << 16) | self.a
}

///|
fn write_u32_be(w : Buffer, v : UInt) -> Unit {
  w.write_byte((v >> 24).to_byte())
  w.write_byte((v >> 16).to_byte())
  w.write_byte((v >> 8).to_byte())
  w.write_byte(v.to_byte())
}

///|
/// Compressor that produces fdeflate compressed streams.
pub struct Compressor {
  priv checksum : Adler32
  priv mut buffer : UInt64
  priv mut nbits : Int
  priv writer : Buffer
}

///|
fn Compressor::write_bits(
  self : Compressor,
  bits : UInt64,
  nbits : Int,
) -> Unit {
  self.buffer = self.buffer | (bits << self.nbits)
  self.nbits += nbits
  if self.nbits >= 64 {
    self.writer.write_uint64_le(self.buffer)
    self.nbits -= 64
    let shift = nbits - self.nbits
    self.buffer = if shift >= 64 { 0 } else { bits >> shift }
  }
}

///|
fn Compressor::flush(self : Compressor) -> Unit {
  if self.nbits % 8 != 0 {
    self.write_bits(0, 8 - self.nbits % 8)
  }
  if self.nbits > 0 {
    for i in 0..<(self.nbits / 8) {
      self.writer.write_byte((self.buffer >> (8 * i)).to_byte())
    }
    self.buffer = 0
    self.nbits = 0
  }
}

///|
fn Compressor::write_code(self : Compressor, sym : Int) -> Unit {
  self.write_bits(
    fdeflate_huffman_codes[sym].to_uint64(),
    fdeflate_huffman_lengths[sym],
  )
}

///|
fn Compressor::write_run(self : Compressor, run : Int) -> Unit {
  let mut run = run
  self.write_code(0)
  run -= 1
  while run >= 258 {
    self.write_bits(
      fdeflate_huffman_codes[285].to_uint64(),
      fdeflate_huffman_lengths[285] + 1,
    )
    run -= 258
  }
  if run > 4 {
    let sym = fdeflate_length_to_symbol[run - 3]
    self.write_code(sym)
    let len_extra = fdeflate_length_to_len_extra[run - 3]
    let extra = ((run - 3).reinterpret_as_uint() & fdeflate_bitmasks[len_extra]).to_uint64()
    self.write_bits(extra, len_extra + 1)
  } else {
    self.write_bits(0, run * fdeflate_huffman_lengths[0])
  }
}

///|
/// Create a new Compressor.
pub fn Compressor::new() -> Compressor {
  let compressor = {
    checksum: Adler32::new(),
    buffer: 0,
    nbits: 0,
    writer: Buffer(),
  }
  compressor.write_headers()
  compressor
}

///|
let fdeflate_header : FixedArray[Int] = [
  120, 1, 237, 192, 3, 160, 36, 89, 150, 198, 241, 255, 119, 238, 141, 200, 204,
  167, 114, 75, 99, 174, 109, 219, 182, 109, 219, 182, 109, 219, 182, 109, 105, 140,
  158, 150, 74, 175, 158, 50, 51, 34, 238, 249, 118, 183, 106, 122, 166, 135, 59,
  107, 213, 15,
]

///|
fn Compressor::write_headers(self : Compressor) -> Unit {
  for i in 0..<53 {
    self.writer.write_byte(fdeflate_header[i].to_byte())
  }
  self.write_bits(fdeflate_header[53].to_uint64(), 5)
}

///|
/// Little-endian 64-bit load of `data[i..i + 8]`.
fn load_u64_le(data : BytesView, i : Int) -> UInt64 {
  let mut v = 0UL
  for k in 0..<8 {
    v = v | (data[i + k].to_uint64() << (8 * k))
  }
  v
}

///|
/// Write data to the compressor.
pub fn Compressor::write_data(self : Compressor, data : BytesView) -> Unit {
  self.checksum.write(data)
  let mut run = 0
  let full = data.length() / 8 * 8
  for i = 0; i < full; i = i + 8 {
    let ichunk = load_u64_le(data, i)
    if ichunk == 0 {
      run += 8
      continue
    } else if run > 0 {
      let run_extra = ichunk.ctz() / 8
      self.write_run(run + run_extra)
      run = 0
      if run_extra > 0 {
        run = ichunk.clz() / 8
        for j in run_extra..<(8 - run) {
          self.write_code(data[i + j].to_int())
        }
        continue
      }
    }
    let run_start = ichunk.clz() / 8
    if run_start > 0 {
      for j in 0..<(8 - run_start) {
        self.write_code(data[i + j].to_int())
      }
      run = run_start
      continue
    }
    let c0 = data[i].to_int()
    let c1 = data[i + 1].to_int()
    let c2 = data[i + 2].to_int()
    let c3 = data[i + 3].to_int()
    let n0 = fdeflate_huffman_lengths[c0]
    let n1 = fdeflate_huffman_lengths[c1]
    let n2 = fdeflate_huffman_lengths[c2]
    let n3 = fdeflate_huffman_lengths[c3]
    let bits = fdeflate_huffman_codes[c0].to_uint64() |
      (fdeflate_huffman_codes[c1].to_uint64() << n0) |
      (fdeflate_huffman_codes[c2].to_uint64() << (n0 + n1)) |
      (fdeflate_huffman_codes[c3].to_uint64() << (n0 + n1 + n2))
    self.write_bits(bits, n0 + n1 + n2 + n3)
    let c4 = data[i + 4].to_int()
    let c5 = data[i + 5].to_int()
    let c6 = data[i + 6].to_int()
    let c7 = data[i + 7].to_int()
    let n4 = fdeflate_huffman_lengths[c4]
    let n5 = fdeflate_huffman_lengths[c5]
    let n6 = fdeflate_huffman_lengths[c6]
    let n7 = fdeflate_huffman_lengths[c7]
    let bits2 = fdeflate_huffman_codes[c4].to_uint64() |
      (fdeflate_huffman_codes[c5].to_uint64() << n4) |
      (fdeflate_huffman_codes[c6].to_uint64() << (n4 + n5)) |
      (fdeflate_huffman_codes[c7].to_uint64() << (n4 + n5 + n6))
    self.write_bits(bits2, n4 + n5 + n6 + n7)
  }
  if run > 0 {
    self.write_run(run)
  }
  for i in full..<data.length() {
    self.write_code(data[i].to_int())
  }
}

///|
/// Write the remainder of the stream and return the compressed bytes.
pub fn Compressor::finish(self : Compressor) -> Bytes {
  // Write end of block
  self.write_code(256)
  self.flush()

  // Write Adler32 checksum
  write_u32_be(self.writer, self.checksum.finish())
  self.writer.to_bytes()
}

///|
/// Compressor that only writes the stored blocks.
///
/// This is useful for writing files that are not compressed, but still need
/// to be wrapped in a zlib stream.
pub struct StoredOnlyCompressor {
  priv checksum : Adler32
  priv data : Buffer
}

///|
/// Creates a new `StoredOnlyCompressor`.
pub fn StoredOnlyCompressor::new() -> StoredOnlyCompressor {
  { checksum: Adler32::new(), data: Buffer(), }
}

///|
/// Writes the given data.
pub fn StoredOnlyCompressor::write_data(
  self : StoredOnlyCompressor,
  data : BytesView,
) -> Unit {
  self.checksum.write(data)
  self.data.write_bytesview(data)
}

///|
/// Finish writing the final block and return the compressed bytes.
///
/// Upstream writes placeholder block headers and seeks back to fill them in;
/// here the (identical) blocks are written at the end: stored blocks of
/// `u16::MAX` bytes, the last one flagged as final (an empty input yields a
/// single empty final block).
pub fn StoredOnlyCompressor::finish(self : StoredOnlyCompressor) -> Bytes {
  let data = self.data.to_bytes()
  let w = Buffer(size_hint=StoredOnlyCompressor::compressed_size(data.length()))
  w.write_byte(0x78) // zlib header
  w.write_byte(0x01)
  let max = 65535
  let mut start = 0
  while true {
    let size = @cmp.minimum(max, data.length() - start)
    let last = start + size >= data.length()
    w.write_byte(if last { 1 } else { 0 })
    w.write_byte((size & 0xFF).to_byte())
    w.write_byte(((size >> 8) & 0xFF).to_byte())
    w.write_byte((size.lnot() & 0xFF).to_byte())
    w.write_byte(((size.lnot() >> 8) & 0xFF).to_byte())
    w.write_bytesview(data[start:start + size])
    start += size
    if last {
      break
    }
  }

  // Write Adler32 checksum
  write_u32_be(w, self.checksum.finish())
  w.to_bytes()
}

///|
/// Return the number of bytes that will be written to the output stream for
/// the given input size. Because this compressor only writes stored blocks,
/// the output size is always slightly *larger* than the input size.
pub fn StoredOnlyCompressor::compressed_size(raw_size : Int) -> Int {
  let max = 65535
  @cmp.maximum(raw_size - 1, 0) / max * (max + 5) + (raw_size % max + 5) + 6
}
