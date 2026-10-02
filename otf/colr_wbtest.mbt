///|
priv struct LogPainter {
  log : Array[String]
}

///|
impl ColrPainter for LogPainter with fn outline_glyph(self, g) {
  self.log.push("outline \{g.0}")
}

///|
impl ColrPainter for LogPainter with fn paint(self, p) {
  match p {
    Solid(c) =>
      self.log.push(
        "solid \{c.red.to_int()} \{c.green.to_int()} \{c.blue.to_int()} \{c.alpha.to_int()}",
      )
    _ => self.log.push("gradient")
  }
}

///|
impl ColrPainter for LogPainter with fn push_clip(self) {
  self.log.push("push_clip")
}

///|
impl ColrPainter for LogPainter with fn push_clip_box(self, _) {
  self.log.push("push_clip_box")
}

///|
impl ColrPainter for LogPainter with fn pop_clip(self) {
  self.log.push("pop_clip")
}

///|
impl ColrPainter for LogPainter with fn push_layer(self, _) {
  self.log.push("push_layer")
}

///|
impl ColrPainter for LogPainter with fn pop_layer(self) {
  self.log.push("pop_layer")
}

///|
impl ColrPainter for LogPainter with fn push_transform(self, _) {
  self.log.push("push_transform")
}

///|
impl ColrPainter for LogPainter with fn pop_transform(self) {
  self.log.push("pop_transform")
}

///|
let test_cpal_data : Bytes = b"\x00\x00\x00\x02\x00\x01\x00\x02\x00\x00\x00\x0e\x00\x00\x10\x20\x30\xff\x01\x02\x03\x04"

///|
test "cpal" {
  let cpal = CpalTable::parse(test_cpal_data[:]).unwrap()
  assert_eq(cpal.palettes(), 1)
  let c = cpal.get(0, 0).unwrap()
  assert_eq((c.red, c.green, c.blue, c.alpha), (0x30, 0x20, 0x10, 0xff))
  let c = cpal.get(0, 1).unwrap()
  assert_eq((c.red, c.green, c.blue, c.alpha), (3, 2, 1, 4))
  assert_true(cpal.get(0, 2) is None)
  assert_true(cpal.get(1, 0) is None)
}

///|
test "colr v0" {
  let cpal = CpalTable::parse(test_cpal_data[:]).unwrap()
  let data = b"\x00\x00\x00\x01\x00\x00\x00\x0e\x00\x00\x00\x14\x00\x02\x00\x05\x00\x00\x00\x02\x00\x07\x00\x01\x00\x08\xff\xff"
  let colr = ColrTable::parse(cpal, data[:]).unwrap()
  assert_true(colr.is_simple())
  assert_true(colr.contains(GlyphId(5)))
  assert_true(!colr.contains(GlyphId(6)))
  let painter = LogPainter::{ log: [], }
  let fg = RgbaColor::new(9, 9, 9, 255)
  assert_true(colr.paint(GlyphId(5), 0, painter, [], fg) is Some(_))
  assert_eq(painter.log, [
    "outline 7", "solid 3 2 1 4", "outline 8", "solid 9 9 9 255",
  ])
  // The foreground color must not be mutated.
  assert_eq(fg.alpha, 255)
}

///|
test "colr v1" {
  let cpal = CpalTable::parse(test_cpal_data[:]).unwrap()
  let data = b"\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x22\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x09\x00\x00\x00\x0a\x0a\x00\x00\x06\x00\x0b\x02\x00\x00\x20\x00"
  let colr = ColrTable::parse(cpal, data[:]).unwrap()
  assert_true(!colr.is_simple())
  assert_true(colr.contains(GlyphId(9)))
  let painter = LogPainter::{ log: [], }
  let fg = RgbaColor::new(0, 0, 0, 255)
  assert_true(colr.paint(GlyphId(9), 0, painter, [], fg) is Some(_))
  assert_eq(painter.log, [
    "outline 11", "push_clip", "solid 48 32 16 127", "pop_clip",
  ])
}
