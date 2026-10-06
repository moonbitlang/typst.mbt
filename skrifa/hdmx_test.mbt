// The hdmx advance override of hinted TrueType outlines (skrifa 0.42.1
// `src/outline/glyf/mod.rs:462-489` and `outline.rs:161-169`).
//
// The font is synthetic: 1000 units per em, an empty glyph 0 and a triangle
// as glyph 1 (hmtx advances 500 and 600), and an `hdmx` table with one record
// for 16 ppem (widths 7 and 12). The expected values are those of skrifa
// 0.42.1 on the same bytes.

///|
let hdmx_test_font : Bytes = b"\x00\x01\x00\x00\x00\x07\x00\x40\x00\x02\x00\x30\x67\x6c\x79\x66" +
  b"\x00\x00\x00\x00\x00\x00\x00\x7c\x00\x00\x00\x1e\x68\x64\x6d\x78" +
  b"\x00\x00\x00\x00\x00\x00\x00\x9c\x00\x00\x00\x0c\x68\x65\x61\x64" +
  b"\x00\x00\x00\x00\x00\x00\x00\xa8\x00\x00\x00\x36\x68\x68\x65\x61" +
  b"\x00\x00\x00\x00\x00\x00\x00\xe0\x00\x00\x00\x24\x68\x6d\x74\x78" +
  b"\x00\x00\x00\x00\x00\x00\x01\x04\x00\x00\x00\x08\x6c\x6f\x63\x61" +
  b"\x00\x00\x00\x00\x00\x00\x01\x0c\x00\x00\x00\x06\x6d\x61\x78\x70" +
  b"\x00\x00\x00\x00\x00\x00\x01\x14\x00\x00\x00\x20\x00\x01\x00\x32" +
  b"\x00\x00\x01\xc2\x02\xbc\x00\x02\x00\x00\x01\x01\x01\x00\x32\x01" +
  b"\x90\xff\x38\x00\x00\x00\x00\x02\xbc\x00\x00\x00\x00\x00\x00\x01" +
  b"\x00\x00\x00\x04\x10\x0c\x07\x0c\x00\x01\x00\x00\x00\x01\x00\x00" +
  b"\x00\x00\x00\x00\x5f\x0f\x3c\xf5\x00\x0b\x03\xe8\x00\x00\x00\x00" +
  b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" +
  b"\x01\xf4\x02\xbc\x00\x00\x00\x08\x00\x02\x00\x00\x00\x00\x00\x00" +
  b"\x00\x01\x00\x00\x03\x20\xff\x38\x00\x00\x02\x58\x00\x00\x00\x00" +
  b"\x01\xf4\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" +
  b"\x00\x00\x00\x02\x01\xf4\x00\x00\x02\x58\x00\x32\x00\x00\x00\x00" +
  b"\x00\x0f\x00\x00\x00\x01\x00\x00\x00\x02\x00\x03\x00\x01\x00\x00" +
  b"\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x40\x00\x00" +
  b"\x00\x00\x00\x00"

///|
priv struct NullPen {}

///|
impl @skrifa.OutlinePen for NullPen with fn move_to(_, _, _) {

}

///|
impl @skrifa.OutlinePen for NullPen with fn line_to(_, _, _) {

}

///|
impl @skrifa.OutlinePen for NullPen with fn quad_to(_, _, _, _, _) {

}

///|
impl @skrifa.OutlinePen for NullPen with fn curve_to(_, _, _, _, _, _, _) {

}

///|
impl @skrifa.OutlinePen for NullPen with fn close(_) {

}

///|
/// The adjusted advance of a glyph: unhinted if `target` is `None`.
fn hdmx_test_advance(
  ppem : Float,
  gid : UInt,
  target : @skrifa.Target?,
) -> Float? raise {
  let font = @skrifa.FontRef::new(hdmx_test_font[:])
  let glyphs = @skrifa.OutlineGlyphCollection::new(font)
  guard glyphs.get(@skrifa.GlyphId::new(gid)) is Some(glyph) else {
    fail("missing glyph")
  }
  let size = @skrifa.Size::new(ppem)
  let location = @skrifa.LocationRef::default()
  let settings = match target {
    None => @skrifa.DrawSettings::unhinted(size, location)
    Some(target) => {
      let instance = @skrifa.HintingInstance::new(glyphs, size, location, {
        engine: Interpreter,
        target,
      })
      @skrifa.DrawSettings::hinted(instance, false)
    }
  }
  glyph.draw(settings, NullPen::{ }).advance_width
}

///|
test "hinted advance comes from hdmx when a record matches the size" {
  let smooth : @skrifa.Target = Smooth(
    mode=Normal,
    symmetric_rendering=true,
    preserve_linear_metrics=false,
  )
  // The record for 16 ppem applies to the mono target (no backward
  // compatibility mode).
  assert_eq(hdmx_test_advance(16.0, 0, Some(Mono)), Some(7.0))
  assert_eq(hdmx_test_advance(16.0, 1, Some(Mono)), Some(12.0))
  // Smooth hinting runs in backward compatibility mode: no override.
  assert_eq(hdmx_test_advance(16.0, 0, Some(smooth)), Some(8.0))
  assert_eq(hdmx_test_advance(16.0, 1, Some(smooth)), Some(10.0))
  // Unhinted outlines never use hdmx.
  assert_eq(hdmx_test_advance(16.0, 0, None), Some(8.0))
  assert_eq(hdmx_test_advance(16.0, 1, None), Some(9.59375))
  // No record for 15 ppem, and 16.5 is not integral.
  assert_eq(hdmx_test_advance(15.0, 0, Some(Mono)), Some(8.0))
  assert_eq(hdmx_test_advance(15.0, 1, Some(Mono)), Some(9.0))
  assert_eq(hdmx_test_advance(16.5, 0, Some(Mono)), Some(9.0))
  assert_eq(hdmx_test_advance(16.5, 1, Some(Mono)), Some(10.0))
}
