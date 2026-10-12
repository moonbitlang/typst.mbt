// The glyphs of a text item as the exporter is given them (`convert_glyphs`):
// the ranges of a glyph are UTF-8 byte offsets into the text of its item,
// the exporter wants UTF-16 offsets, and every glyph has the location of
// its span.

///|
/// A text item of the text with the glyphs `(id, start, end, span)`, the
/// ranges in UTF-8 bytes.
fn text_test_item(
  text : String,
  glyphs : Array[(Int32, Int32, Int32, UInt64)],
) -> @library.TextItem raise {
  guard @library.Font::from_data(@assets_fonts.fonts()[0], 0) is Some(font) else {
    fail("not a font")
  }
  {
    font: font.instantiate_with(@library.FontVariations::default()),
    size: @library.Abs::pt(10.0),
    fill: Solid(@library.color_black),
    stroke: None,
    lang: @library.lang_english,
    region: None,
    text,
    glyphs: glyphs.mapi((i, g) => {
      id: g.0.to_uint16(),
      x_advance: @library.Em::new(0.5 + i.to_double() / 16.0),
      x_offset: @library.Em::new(i.to_double() / 32.0),
      y_advance: @library.Em::zero(),
      y_offset: @library.Em::new(-i.to_double() / 64.0),
      range_start: g.1.to_uint16(),
      range_end: g.2.to_uint16(),
      span: @syntax.Span(g.3),
      span_offset: i.to_uint16(),
    }),
  }
}

///|
/// The array that every conversion of these tests writes to, as an export
/// has one for all its text items.
let text_test_glyphs : Array[@export.Glyph] = []

///|
/// The converted glyphs of a text item (a copy: the caller keeps them).
fn text_test_converted(t : @library.TextItem) -> Array[@export.Glyph] {
  convert_glyphs(t, text_test_glyphs)
  text_test_glyphs.copy()
}

///|
/// The glyphs as `id start..end @location`, one per line.
fn text_test_summary(glyphs : Array[@export.Glyph]) -> String {
  glyphs
  .map(g => {
    let location = match g.location {
      Some(location) => location.to_string()
      None => "-"
    }
    "\{g.glyph_id} \{g.text_start}..\{g.text_end} @\{location}"
  })
  .join("\n")
}

///|
test "convert_glyphs: ASCII text keeps its offsets" {
  let item = text_test_item("Hello, fi!", [
    (40, 0, 1, 7UL),
    (41, 1, 2, 7UL),
    (42, 2, 3, 7UL),
    (42, 3, 4, 7UL),
    (43, 4, 5, 7UL),
    (44, 5, 6, 8UL),
    (45, 6, 7, 8UL),
    // A ligature of two characters.
    (300, 7, 9, 9UL),
    (46, 9, 10, 9UL),
  ])
  let glyphs = text_test_converted(item)
  inspect(
    text_test_summary(glyphs),
    content=(
      #|40 0..1 @7
      #|41 1..2 @7
      #|42 2..3 @7
      #|42 3..4 @7
      #|43 4..5 @7
      #|44 5..6 @8
      #|45 6..7 @8
      #|300 7..9 @9
      #|46 9..10 @9
    ),
  )
  // The advances and offsets are the glyph's.
  assert_eq(glyphs[3].x_advance, 0.5 + 3.0 / 16.0)
  assert_eq(glyphs[3].x_offset, 3.0 / 32.0)
  assert_eq(glyphs[3].y_advance, 0.0)
  assert_eq(glyphs[3].y_offset, -3.0 / 64.0)
}

///|
test "convert_glyphs: UTF-8 ranges become UTF-16 offsets" {
  // One, two, three and four bytes per character: "a", "é", "€", "𝄞"
  // (two UTF-16 code units), then "z".
  let item = text_test_item("a\u{e9}\u{20ac}\u{1d11e}z", [
    (1, 0, 1, 1UL),
    (2, 1, 3, 1UL),
    (3, 3, 6, 2UL),
    (4, 6, 10, 2UL),
    (5, 10, 11, 3UL),
    // A glyph for two characters, and one inside a character.
    (6, 1, 6, 3UL),
    (7, 7, 9, 3UL),
  ])
  inspect(
    text_test_summary(text_test_converted(item)),
    content=(
      #|1 0..1 @1
      #|2 1..2 @1
      #|3 2..3 @2
      #|4 3..5 @2
      #|5 5..6 @3
      #|6 1..3 @3
      #|7 3..3 @3
    ),
  )
}

///|
test "convert_glyphs: ranges beyond the text end at its end" {
  let ascii = text_test_item("abc", [
    (1, 0, 3, 1UL),
    (2, 3, 4, 1UL),
    (3, 9, 12, 1UL),
  ])
  inspect(
    text_test_summary(text_test_converted(ascii)),
    content=(
      #|1 0..3 @1
      #|2 3..3 @1
      #|3 3..3 @1
    ),
  )
  let wide = text_test_item("\u{e9}b", [
    (1, 0, 3, 1UL),
    (2, 3, 4, 1UL),
    (3, 9, 12, 1UL),
  ])
  inspect(
    text_test_summary(text_test_converted(wide)),
    content=(
      #|1 0..2 @1
      #|2 2..2 @1
      #|3 2..2 @1
    ),
  )
  // An item without glyphs, and one without text.
  assert_eq(text_test_converted(text_test_item("abc", [])).length(), 0)
  inspect(
    text_test_summary(text_test_converted(text_test_item("", [(1, 0, 0, 5UL)]))),
    content="1 0..0 @5",
  )
}

///|
test "convert_glyphs: every text item has its own glyphs" {
  // The glyphs of an item are what they were after another item was
  // converted (the caller draws an item before it converts the next).
  let first = text_test_item("ab", [(1, 0, 1, 1UL), (2, 1, 2, 1UL)])
  let second = text_test_item("xyz", [
    (7, 0, 1, 2UL),
    (8, 1, 2, 2UL),
    (9, 2, 3, 3UL),
  ])
  let a = text_test_converted(first)
  let b = text_test_converted(second)
  inspect(
    text_test_summary(a),
    content=(
      #|1 0..1 @1
      #|2 1..2 @1
    ),
  )
  inspect(
    text_test_summary(b),
    content=(
      #|7 0..1 @2
      #|8 1..2 @2
      #|9 2..3 @3
    ),
  )
  // An item after a longer one, in the array of the longer one.
  assert_eq(text_test_summary(text_test_converted(first)), text_test_summary(a))
  assert_eq(text_test_glyphs.length(), 2)
  assert_eq(text_test_converted(text_test_item("abc", [])).length(), 0)
}
