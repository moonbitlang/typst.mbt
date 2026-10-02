///|
fn hex_bytes(s : String) -> Bytes {
  let digit = (c : Char) => {
    let c = c.to_int()
    if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else {
      c - 'a'.to_int() + 10
    }
  }
  let chars = s.to_array()
  Bytes::makei(chars.length() / 2, i => {
    (digit(chars[2 * i]) * 16 + digit(chars[2 * i + 1])).to_byte()
  })
}

///|
let inflate_sample : String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"10\"><rect width=\"20\" height=\"10\" fill=\"red\"/><rect width=\"20\" height=\"10\" fill=\"blue\"/></svg>"

///|
test "zlib_decompress: dynamic Huffman blocks (zlib level 9)" {
  let data = hex_bytes(
    "78da8dcddb0d80200c40d1554807b055ff8c388c5a81041f816a1d5f19c0c4ef7b92dbe7cb997b8d5bb6e0458e0e51552b6dab3d396c88085f0146c32cde4243603c07e7c5424d30f48927f9886609315a483c03fe81633cb9c8321c1e54fc2f0d",
  )
  let out = @codecs.zlib_decompress(data[:])
  assert_eq(out, @utf8.encode(inflate_sample))
}

///|
test "gzip_decompress" {
  let data = hex_bytes(
    "1f8b08000000000002ff8dcddb0d80200c40d1554807b055ff8c388c5a81041f816a1d5f19c0c4ef7b92dbe7cb997b8d5bb6e0458e0e51552b6dab3d396c88085f0146c32cde4243603c07e7c5424d30f48927f9886609315a483c03fe81633cb9c8321c1ea3307b4198000000",
  )
  let out = @codecs.gzip_decompress(data[:])
  assert_eq(out, @utf8.encode(inflate_sample))
  // A corrupted stream is rejected.
  let corrupted = Bytes::makei(data.length(), i => {
    if i == 30 {
      data[i] ^ 0xFF
    } else {
      data[i]
    }
  })
  let failed = try {
    @codecs.gzip_decompress(corrupted[:]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "zlib_decompress roundtrips the fdeflate compressors" {
  let data = Bytes::makei(70000, i => (i * i / 7 % 251).to_byte())
  let compressor = @codecs.Compressor::new()
  compressor.write_data(data[0:1000])
  compressor.write_data(data[1000:])
  assert_eq(@codecs.zlib_decompress(compressor.finish()[:]), data)
  let stored = @codecs.StoredOnlyCompressor::new()
  stored.write_data(data[:])
  assert_eq(@codecs.zlib_decompress(stored.finish()[:]), data)
}
