// Snapshot tests: glyph outlines recorded from upstream `ttf-parser` (0.25)
// and their rasterizations by upstream `pixglyph` (0.6.1).

///|
priv enum Cmd {
  M(Float, Float)
  L(Float, Float)
  Q(Float, Float, Float, Float)
  C(Float, Float, Float, Float, Float, Float)
  Z
}

///|
/// Replay a recorded outline like `Glyph::load` does.
fn replay(upem : UInt16, bbox : @otf.Rect, cmds : Array[Cmd]) -> Glyph {
  let b = Builder::default()
  for cmd in cmds {
    match cmd {
      M(x, y) => @otf.OutlineBuilder::move_to(b, x, y)
      L(x, y) => @otf.OutlineBuilder::line_to(b, x, y)
      Q(x1, y1, x, y) => @otf.OutlineBuilder::quad_to(b, x1, y1, x, y)
      C(x1, y1, x2, y2, x, y) =>
        @otf.OutlineBuilder::curve_to(b, x1, y1, x2, y2, x, y)
      Z => @otf.OutlineBuilder::close(b)
    }
  }
  b.close_path()
  { units_per_em: upem, bbox, segments: b.segments, }
}

///|
fn fnv1a(data : Bytes) -> UInt64 {
  let mut h : UInt64 = 0xcbf29ce484222325
  for byte in data {
    h = (h ^ byte.to_uint64()) * 0x100000001b3
  }
  h
}

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
fn summary(b : Bitmap) -> String {
  "\{b.left} \{b.top} \{b.width} \{b.height}"
}

///|
/// DejaVuSans `a` (glyf, quadratic).
fn dejavu_sans_a() -> Glyph {
  replay(2048, { x_min: 123, y_min: -29, x_max: 1069, y_max: 1147, }, [
    M(702.0, 563.0),
    Q(479.0, 563.0, 393.0, 512.0),
    Q(307.0, 461.0, 307.0, 338.0),
    Q(307.0, 240.0, 371.5, 182.5),
    Q(436.0, 125.0, 547.0, 125.0),
    Q(700.0, 125.0, 792.5, 233.5),
    Q(885.0, 342.0, 885.0, 522.0),
    L(885.0, 563.0),
    L(702.0, 563.0),
    Z,
    M(1069.0, 639.0),
    L(1069.0, 0.0),
    L(885.0, 0.0),
    L(885.0, 170.0),
    Q(822.0, 68.0, 728.0, 19.5),
    Q(634.0, -29.0, 498.0, -29.0),
    Q(326.0, -29.0, 224.5, 67.5),
    Q(123.0, 164.0, 123.0, 326.0),
    Q(123.0, 515.0, 249.5, 611.0),
    Q(376.0, 707.0, 627.0, 707.0),
    L(885.0, 707.0),
    L(885.0, 725.0),
    Q(885.0, 852.0, 801.5, 921.5),
    Q(718.0, 991.0, 567.0, 991.0),
    Q(471.0, 991.0, 380.0, 968.0),
    Q(289.0, 945.0, 205.0, 899.0),
    L(205.0, 1069.0),
    Q(306.0, 1108.0, 401.0, 1127.5),
    Q(496.0, 1147.0, 586.0, 1147.0),
    Q(829.0, 1147.0, 949.0, 1021.0),
    Q(1069.0, 895.0, 1069.0, 639.0),
    Z,
  ])
}

///|
test "rasterize dejavu_sans_a" {
  let g = dejavu_sans_a()
  let b = g.rasterize(0.3, 0.7, 7.5)
  assert_eq(summary(b), "0 -4 5 5")
  assert_eq(
    hex(b.coverage),
    "0054773400003822b21200818abf34248801b3360189988026",
  )
  let b = g.rasterize(123.456, 789.012, 40.0)
  assert_eq(summary(b), "125 766 20 24")
  assert_eq(
    hex(b.coverage),
    "00000000000008223d58553d23000000000000000000002d79c5fcffffffffffffdd861c00000000000082fefefefefefefefefefefefeec4c000000000089fefefefde7c7afc7e8fefefefefd480000000089f7a5410800000000002eb1fefefee3100000002f120000000000000000000086fefefe7300000000000000000000000000000004cbfefec30000000000000000000000000000000081fefefc0f00000000000000000000000000000053fefefe2900000000000c4786a4b5c6cbcbcbcbd8fefefe3e000000138ef7fefefefefefefefefefefefefe52000027e8fefefefefefefefefefefefefefefe550011e2fefefedc7f4c25160b04040445fefefe550078fefefea90200000000000000005afefefe5500dafefedd050000000000000000007ffefefe5504fbfefea200000000000000000000a3fefefe551bfefefe7f00000000000000000010ecfefefe550bfefefea60000000000000000008afefefefe5500e8fefeed1b0000000000000035f7fefefefe550092fefefec52200000000035cf4fef5fefefe550022f0fefefef7ac857999defefef069fefefe5500004ef8fefefefefefefefefeec4442fefefe550000002fc8fefefefefefef8ab1c0042fefefe5500000000002868828a7356100000000003030301",
  )
  let b = g.rasterize(-5.25, 10.5, 99.9)
  assert_eq(summary(b), "0 -46 47 58")
  assert_eq(fnv1a(b.coverage), 0x65ed9f632c29adad)
}

///|
/// NewCM10-Regular `g` (CFF, cubic).
fn newcm10_g() -> Glyph {
  replay(1000, { x_min: 28, y_min: -206, x_max: 485, y_max: 453, }, [
    M(433.0, 453.0),
    C(397.0, 453.0, 354.0, 434.0, 328.0, 406.0),
    C(302.0, 426.0, 268.0, 442.0, 221.0, 442.0),
    C(123.0, 442.0, 60.0, 369.0, 60.0, 295.0),
    C(60.0, 252.0, 81.0, 220.0, 105.0, 192.0),
    C(88.0, 167.0, 76.0, 140.0, 76.0, 109.0),
    C(76.0, 55.0, 111.0, 24.0, 120.0, 21.0),
    C(42.744034, -4.7519836, 28.0, -48.98265, 28.0, -79.0),
    C(28.0, -145.0, 115.0, -206.0, 250.0, -206.0),
    C(383.29785, -206.0, 471.0, -146.3802, 471.0, -77.0),
    C(471.0, -38.0, 457.0, -7.0, 434.0, 16.0),
    C(383.0, 65.0, 301.0, 66.0, 223.0, 66.0),
    L(163.0, 66.0),
    C(132.0, 66.0, 106.0, 97.0, 106.0, 134.0),
    C(106.0, 151.0, 113.0, 168.0, 123.0, 179.0),
    C(149.0, 163.0, 178.0, 149.0, 221.0, 149.0),
    C(313.0, 149.0, 384.0, 215.0, 384.0, 295.0),
    C(384.0, 330.0, 370.0, 366.0, 343.0, 392.0),
    C(358.12054, 407.12054, 394.08704, 431.0, 432.0, 431.0),
    C(437.0, 431.0, 443.0, 430.0, 443.0, 430.0),
    C(434.0, 427.0, 427.0, 418.0, 427.0, 402.0),
    C(427.0, 386.0, 441.0, 374.0, 455.0, 374.0),
    C(475.0, 374.0, 485.0, 388.0, 485.0, 404.0),
    C(485.0, 422.7586, 471.49973, 453.0, 433.0, 453.0),
    Z,
    M(309.0, 295.0),
    C(309.0, 244.0, 301.0, 218.0, 281.0, 197.0),
    C(266.0, 184.0, 249.0, 172.0, 221.0, 172.0),
    C(146.54988, 172.0, 135.0, 247.89995, 135.0, 295.0),
    C(135.0, 346.0, 142.0, 372.0, 162.0, 393.0),
    C(176.0, 407.0, 195.0, 419.0, 224.0, 419.0),
    C(298.38464, 419.0, 309.0, 340.0619, 309.0, 295.0),
    Z,
    M(419.0, -79.0),
    C(419.0, -127.0, 358.0, -182.0, 249.0, -182.0),
    C(159.0, -182.0, 80.0, -140.0, 80.0, -80.0),
    C(80.0, -32.0, 115.0, -2.0, 157.0, 6.0),
    L(273.0, 6.0),
    C(320.0, 6.0, 419.0, -2.0, 419.0, -79.0),
    Z,
  ])
}

///|
test "rasterize newcm10_g" {
  let g = newcm10_g()
  let b = g.rasterize(0.3, 0.7, 7.5)
  assert_eq(summary(b), "0 -3 4 6")
  assert_eq(hex(b.coverage), "00404b34245e6f12096639001791714e48240b6500152401")
  let b = g.rasterize(123.456, 789.012, 40.0)
  assert_eq(summary(b), "124 770 19 28")
  assert_eq(
    hex(b.coverage),
    "000000000000000000000000000000000a00000000000000083e7a9c754702000883ced5d83f0000000160e9d77157b8fdd061ca6f1856ffc60000009effcf0a0000005dfbfe67000033ed87000057feff45000000000096ffe511000001000000c3fffe0700000000003dffff77000000000005f6ffec00000000000030ffffab000000000011feffdb00000000000037ffffba000000000000d6ffde00000000000052ffff7d0000000000008bfffb1c000000000076fffd330000000000000cdcffa0020000000be5ff8a00000000000000007ff7ffb0320027bbfb9505000000000000000cd91767c1ebe9cb962f00000000000000000049bf000000000300000000000000000000000072e600000000000000000000000000000000004aff6b000000000000000000000000000000000df3fecaa0a09f9e9d96632600000000000000007dfeffffffffffffffffffd95501000000000366f4dec4c4c4c4c4c2d2feffffc60a000023d1e841010000000000000025bbffff910014ddfe370000000000000000000005b9fff80553ffd900000000000000000000000029fbff2f4dffc800000000000000000000000000e3fe2706eefe2c000000000000000000000035ffcf00005efad91f0000000000000000002be4f14100000048e1ea8625000000000f46a9f9d83200000000000244a1d4ead2bee2f5d49c3c0000000000000000000000011d371b0100000000000000",
  )
  let b = g.rasterize(-5.25, 10.5, 99.9)
  assert_eq(summary(b), "-3 -35 47 67")
  assert_eq(fnv1a(b.coverage), 0xe4a12e794cbb7d8f)
}

///|
/// SourceSerif4Variable-Roman `S` (CFF2, cubic, no explicit close).
fn source_serif4_var_S() -> Glyph {
  replay(1000, { x_min: 40, y_min: -15, x_max: 472, y_max: 685, }, [
    M(235.0, -15.0),
    C(374.0, -15.0, 472.0, 57.0, 472.0, 175.0),
    C(472.0, 270.0, 421.0, 328.0, 290.0, 379.0),
    L(250.0, 394.0),
    C(178.0, 422.0, 137.0, 460.0, 137.0, 522.0),
    C(137.0, 596.0, 196.0, 635.0, 272.0, 635.0),
    C(325.0, 635.0, 362.0, 618.0, 412.0, 570.0),
    L(412.0, 620.0),
    L(347.0, 653.0),
    L(375.0, 502.0),
    L(436.0, 502.0),
    L(442.0, 633.0),
    C(399.0, 665.0, 345.0, 685.0, 278.0, 685.0),
    C(150.0, 685.0, 53.0, 615.0, 53.0, 500.0),
    C(53.0, 398.0, 122.0, 338.0, 225.0, 298.0),
    L(264.0, 282.0),
    C(349.0, 249.0, 387.0, 220.0, 387.0, 156.0),
    C(387.0, 79.0, 326.0, 35.0, 232.0, 35.0),
    C(164.0, 35.0, 130.0, 55.0, 68.0, 100.0),
    L(68.0, 52.0),
    L(134.0, 24.0),
    L(108.0, 178.0),
    L(46.0, 178.0),
    L(40.0, 38.0),
    C(86.0, 8.0, 160.0, -15.0, 235.0, -15.0),
  ])
}

///|
test "rasterize source_serif4_var_S" {
  let g = source_serif4_var_S()
  let b = g.rasterize(0.3, 0.7, 7.5)
  assert_eq(summary(b), "0 -5 4 6")
  assert_eq(hex(b.coverage), "00285b1c1c7c13a41ab92100002dae643c1a00a03f8c6235")
  let b = g.rasterize(123.456, 789.012, 40.0)
  assert_eq(summary(b), "125 761 18 29")
  assert_eq(
    hex(b.coverage),
    "0000000000000421405b492e08000000000000000000389bf1fefefefefef6ab470000000000038ffefefedcb8a4bfecffffffaf0b000000acffffca3c0000000009c9fffffe1900004ffefede100000000000002effffff0d0000d5fefe5a0000000000000005f8fffe020017fefffe180000000000000000cefff500004ffffffb0c000000000000000095edda000052ffffff47000000000000000000000000001dffffffaf0100000000000000000000000000e4ffffff8c0000000000000000000000000067fffffffebd3b000000000000000000000002cdfffffffffebe5a080000000000000000001bceffffffffffffe7780f00000000000000000baafefffffffffffff07500000000000000000031a6fbffffffffffffa90a0000000000000000001e84e7ffffffffffc302000000000000000000000659d4ffffffff66000000000000000000000000099dffffffec0300000000000000000000000002c3ffffff21131b150000000000000000000049ffffff43baffe0000000000000000000001effffff3bc5fffd0d0000000000000000003cfffffa09d0ffff370000000000000000007affffc800daffff62000000000000000024eefefe4800e5ffffff120000000000004ad9fefeab0000adfffffff6ad886c7c9ed2fefefe960500000036a6ecfefefefefefefefab24c0000000000000002335e789288694b16000000000000",
  )
  let b = g.rasterize(-5.25, 10.5, 99.9)
  assert_eq(summary(b), "-2 -58 44 70")
  assert_eq(fnv1a(b.coverage), 0x31a701a64d8e240e)
}

///|
test "canvas rows past a wrapped allocation are skipped" {
  // 65538 x 65536: upstream's `u32` `w * h + 4` wraps to 131076 entries, and
  // the `usize` row offsets put every row but the first two out of range
  // (skipped like upstream's `get_mut`, never written).
  let canvas = Canvas::new(65538U, 65536U)
  assert_eq(canvas.a.length(), 131076)
  canvas.line(point(1.5, 0.0), point(1.5, 65536.0))
  let mut nonzero = 0
  for i in 0..<canvas.a.length() {
    if canvas.a[i] != 0.0 {
      nonzero += 1
      assert_true(i == 1 || i == 2 || i == 65539 || i == 65540)
    }
  }
  assert_eq(nonzero, 4)
}

///|
test "panic rasterize with a canvas past its wrapped allocation" {
  // Upstream panics slicing `a[..w * h]` in `accumulate`.
  let b = Builder::default()
  @otf.OutlineBuilder::move_to(b, 0.0, 0.0)
  @otf.OutlineBuilder::line_to(b, 0.0, 1.0)
  @otf.OutlineBuilder::line_to(b, 1.0, 1.0)
  @otf.OutlineBuilder::close(b)
  let g : Glyph = {
    units_per_em: 1000,
    bbox: { x_min: 0, y_min: 0, x_max: 1, y_max: 1, },
    segments: b.segments,
  }
  ignore(g.rasterize(0.0, 0.0, 65536000.0))
}

///|
test "float helpers match the core functions on special values" {
  let values : Array[Float] = [
    0.0,
    -0.0,
    1.5,
    -1.5,
    0.5,
    -0.5,
    2147483520.0,
    2147483648.0,
    -2147483648.0,
    -2147483904.0,
    1.0e30,
    -1.0e30,
    Float::reinterpret_from_uint(0x7f800000), // inf
    Float::reinterpret_from_uint(0xff800000), // -inf
    Float::reinterpret_from_uint(0x7fc00000), // NaN
    Float::reinterpret_from_uint(0x7f812345), // signaling NaN
    Float::reinterpret_from_uint(0x00000001), // smallest subnormal
    Float::reinterpret_from_uint(0x80000001),
  ]
  let same = (a : Float, b : Float) => {
    (a != a && b != b) || a.reinterpret_as_uint() == b.reinterpret_as_uint()
  }
  for a in values {
    assert_true(same(f32_floor(a), a.floor()))
    assert_true(same(f32_ceil(a), a.ceil()))
    assert_eq(f32_to_i32(a), a.to_int())
    for b in values {
      assert_true(same(f32_min(a, b), a.min(b)))
      assert_true(same(f32_max(a, b), a.max(b)))
    }
  }
}

///|
test "canvas coverage length of overflowing dimensions" {
  // `w * h` beyond the (wrapping `u32`) allocation, also beyond `Int64`:
  // `accumulate` aborts like upstream's slice.
  assert_eq(Canvas::new(0xC0000000U, 0xC0000000U).coverage_len(), -1)
  assert_eq(Canvas::new(65538U, 65536U).coverage_len(), -1)
  assert_eq(Canvas::new(0xFFFFFFFFU, 1U).coverage_len(), -1)
  assert_eq(Canvas::new(7U, 9U).coverage_len(), 63)
  assert_eq(Canvas::new(0U, 9U).coverage_len(), 0)
}

///|
test "panic accumulate with overflowing dimensions" {
  ignore(Canvas::new(0xC0000000U, 0xC0000000U).accumulate())
}
