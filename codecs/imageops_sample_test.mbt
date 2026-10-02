// Snapshot tests: `DynamicImage::resize_exact` and the `Rgba<u8>` pixel view
// of upstream `image` (0.25.10).

///|
fn hex(data : Bytes) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder()
  for byte in data {
    buf.write_char(digits[byte.to_int() >> 4].unsafe_to_char())
    buf.write_char(digits[byte.to_int() & 15].unsafe_to_char())
  }
  buf.to_string()
}

///|
fn u16s(values : Array[Int]) -> Bytes {
  Bytes::from_array(
    values.map(v => [v.to_byte(), (v >> 8).to_byte()]).flatten(),
  )
}

///|
test "resize la8 3x2 to 4x3" {
  let buf = Bytes::from_array([0, 255, 50, 128, 200, 0, 255, 255, 10, 30, 99, 1])
  let r = @codecs.resize_exact(3, 2, La8, buf, 4, 3, Nearest)
  assert_eq(hex(r), "00ff32803280c800ffff0a1e0a1e6301ffff0a1e0a1e6301")
  assert_eq(
    hex(@codecs.to_rgba8(4, 3, La8, r)),
    "000000ff3232328032323280c8c8c800ffffffff0a0a0a1e0a0a0a1e63636301ffffffff0a0a0a1e0a0a0a1e63636301",
  )
  let r = @codecs.resize_exact(3, 2, La8, buf, 4, 3, Triangle)
  assert_eq(hex(r), "00ff1fb06a50c80080ff43914b329601ffff66722b136301")
  assert_eq(
    hex(@codecs.to_rgba8(4, 3, La8, r)),
    "000000ff1f1f1fb06a6a6a50c8c8c800808080ff434343914b4b4b3296969601ffffffff666666722b2b2b1363636301",
  )
  let r = @codecs.resize_exact(3, 2, La8, buf, 4, 3, CatmullRom)
  assert_eq(hex(r), "00ff10bd734cd70085ff3a9644259c00ffff647015006100")
  assert_eq(
    hex(@codecs.to_rgba8(4, 3, La8, r)),
    "000000ff101010bd7373734cd7d7d700858585ff3a3a3a96444444259c9c9c00ffffffff646464701515150061616100",
  )
  let r = @codecs.resize_exact(3, 2, La8, buf, 4, 3, Gaussian)
  assert_eq(hex(r), "13f527a9654fb60978f2448f4c358c06ddee6275331b6304")
  assert_eq(
    hex(@codecs.to_rgba8(4, 3, La8, r)),
    "131313f5272727a96565654fb6b6b609787878f24444448f4c4c4c358c8c8c06ddddddee626262753333331b63636304",
  )
  let r = @codecs.resize_exact(3, 2, La8, buf, 4, 3, Lanczos3)
  assert_eq(hex(r), "00ff00cf8442de0089ff36a34216a000ffff6f7700006305")
  assert_eq(
    hex(@codecs.to_rgba8(4, 3, La8, r)),
    "000000ff000000cf84848442dedede00898989ff363636a342424216a0a0a000ffffffff6f6f6f770000000063636305",
  )
}

///|
test "resize rgb16 2x2 to 1x3" {
  let buf = u16s([
    0, 65535, 1000, 40000, 300, 65000, 12345, 54321, 0, 7, 65534, 32768,
  ])
  let r = @codecs.resize_exact(2, 2, Rgb16, buf, 1, 3, Nearest)
  assert_eq(hex(r), "409c2c01e8fd0700feff00800700feff0080")
  assert_eq(hex(@codecs.to_rgba8(1, 3, Rgb16, r)), "9c01fdff00ff80ff00ff80ff")
  let r = @codecs.resize_exact(2, 2, Rgb16, buf, 1, 3, CatmullRom)
  assert_eq(hex(r), "ad51a5792d85203357b57460931408f1bb3b")
  assert_eq(hex(@codecs.to_rgba8(1, 3, Rgb16, r)), "517985ff33b560ff14f03bff")
  let r = @codecs.resize_exact(2, 2, Rgb16, buf, 1, 3, Lanczos3)
  assert_eq(hex(r), "d4547c73f788203357b574606c1131f7f137")
  assert_eq(hex(@codecs.to_rgba8(1, 3, Rgb16, r)), "547388ff33b560ff11f638ff")
}
