// Expected outputs of upstream `flate2::write::ZlibEncoder` (flate2 1.1.10,
// zlib-rs 0.6.8) and `png::Encoder` (png 0.18.1, default settings), produced
// with a Rust probe.

///|
fn hex_of(data : Bytes) -> String {
  let sb = StringBuilder()
  let digits = "0123456789abcdef"
  for b in data {
    sb.write_char(digits.get_char(b.to_int() >> 4).unwrap())
    sb.write_char(digits.get_char(b.to_int() & 15).unwrap())
  }
  sb.to_string()
}

///|
/// LCG-based test data: literals mixed with repetitive runs.
fn gen_data(n : Int) -> Bytes {
  let mut x = 1U
  Bytes::makei(n, i => {
    x = x * 1103515245U + 12345U
    if x % 4 == 0 {
      (x >> 16).to_byte()
    } else {
      ((i / 7) ^ (i >> 11)).to_byte()
    }
  })
}

///|
fn zlib_chunked(data : Bytes, level : Int, chunk : Int) -> Bytes {
  let enc = @codecs.ZlibEncoder::new(level)
  let mut off = 0
  while off < data.length() {
    let n = @cmp.minimum(chunk, data.length() - off)
    enc.write_all(data[off:off + n])
    off += n
  }
  enc.finish()
}

///|
test "zlib level 6 small inputs" {
  inspect(hex_of(@codecs.zlib_compress(b""[:])), content="789c030000000001")
  inspect(
    hex_of(@codecs.zlib_compress(b"hello hello hello hello world"[:])),
    content="789ccb48cdc9c957c8c020cbf38b725200a38a0af9",
  )
}

///|
test "zlib levels and write patterns" {
  let data = gen_data(70000)
  for
    vector in [
      (6, 70000, 67030, 0x9D01591DU),
      (6, 1000, 67031, 0xAD42A917U),
      (3, 70000, 67039, 0xD31CDE96U),
      (4, 4096, 67039, 0xD31CDE96U),
      (5, 70000, 67030, 0xE41165F0U),
    ] {
    let (level, chunk, len, crc) = vector
    let z = zlib_chunked(data, level, chunk)
    assert_eq(z.length(), len)
    assert_eq(@codecs.crc32([z[:]]), crc)
  }
}

///|
test "encode_png_balanced matches png::Encoder defaults" {
  let px = Bytes::makei(3 * 2 * 4, i => (i * 37 % 256).to_byte())
  inspect(
    hex_of(@codecs.encode_png_balanced(px[:], 3, 2, Rgba)),
    content="89504e470d0a1a0a0000000d49484452000000030000000208060000009d74661a0000002149444154789c636650f5ca9fb27ce7997b1f99a731ef39fff0cb8a151a2b400000a75c0e2d4fb3c9550000000049454e44ae426082",
  )
  let (w, h) = (97, 61)
  let g = gen_data(w * h * 4)
  let px = FixedArray::make(w * h * 4, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let i = (y * w + x) * 4
      px[i] = (x * 2).to_byte()
      px[i + 1] = (y * 4).to_byte()
      px[i + 2] = if (x / 8 + y / 8) % 2 == 0 { g[i] } else { b'\x80' }
      px[i + 3] = b'\xff'
    }
  }
  let png = @codecs.encode_png_balanced(Bytes::from_array(px)[:], w, h, Rgba)
  assert_eq(png.length(), 2293)
  assert_eq(@codecs.crc32([png[:]]), 0xB74FAA93U)
}
