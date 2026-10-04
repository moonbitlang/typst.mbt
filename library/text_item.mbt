// Port of `typst-library/src/text/item.rs`.

///|
/// A run of shaped text.
pub(all) struct TextItem {
  /// The font the glyphs are contained in.
  font : FontInstance
  /// The font size.
  size : Abs
  /// Glyph color.
  fill : Paint
  /// Glyph stroke.
  stroke : FixedStroke?
  /// The natural language of the text.
  lang : Lang
  /// The region of the text.
  region : Region?
  /// The item's plain text.
  text : String
  /// The glyphs. The number of glyphs may be different from the number of
  /// characters in the plain text due to e.g. ligatures.
  glyphs : Array[Glyph]
} derive(Eq)

///|
/// The width of the text run.
pub fn TextItem::width(self : TextItem) -> Abs {
  sum_em(self.glyphs, g => g.x_advance).at(self.size)
}

///|
/// The height of the text run.
pub fn TextItem::height(self : TextItem) -> Abs {
  sum_em(self.glyphs, g => g.y_advance).at(self.size)
}

///|
/// The bounding box of the text run.
pub fn TextItem::bbox(self : TextItem) -> Rect {
  let mut min = Point::splat(Abs::inf())
  let mut max = Point::splat(-Abs::inf())
  let mut cursor = Point::zero()
  for glyph in self.glyphs {
    let advance = Point::new(
      glyph.x_advance.at(self.size),
      glyph.y_advance.at(self.size),
    )
    let offset = Point::new(
      glyph.x_offset.at(self.size),
      glyph.y_offset.at(self.size),
    )
    if self.font.glyph_bounding_box(glyph.id) is Some(rect) {
      let pos = cursor + offset
      let a = pos +
        Point::new(
          self.font.to_em(rect.x_min.to_double()).at(self.size),
          self.font.to_em(rect.y_min.to_double()).at(self.size),
        )
      let b = pos +
        Point::new(
          self.font.to_em(rect.x_max.to_double()).at(self.size),
          self.font.to_em(rect.y_max.to_double()).at(self.size),
        )
      min = min.min(a).min(b)
      max = max.max(a).max(b)
    }
    cursor = cursor + advance
  }

  // Text runs use a y-up coordinate system, in contrast to the default
  // frame orientation.
  min = { ..min, y: min.y.times(-1.0), }
  max = { ..max, y: max.y.times(-1.0), }
  Rect::new(min, max)
}

///|
/// Upstream `Debug for TextItem`.
pub impl Show for TextItem with fn output(self, logger) {
  logger.write_string("Text(\{@unicode.rust_debug_str(self.text)})")
}

///|
/// The sum of the given em values of some glyphs.
fn sum_em(glyphs : ArrayView[Glyph], f : (Glyph) -> Em) -> Em {
  let mut sum = Em::zero()
  for glyph in glyphs {
    sum = sum + f(glyph)
  }
  sum
}

///|
/// A glyph in a run of shaped text.
#valtype
pub(all) struct Glyph {
  /// The glyph's index in the font.
  id : UInt16
  /// The advance width of the glyph.
  x_advance : Em
  /// The horizontal offset of the glyph.
  x_offset : Em
  /// The advance height (Y-up) of the glyph.
  y_advance : Em
  /// The vertical offset (Y-up) of the glyph.
  y_offset : Em
  /// The start of the range of the glyph in its item's text (UTF-8 bytes).
  /// The range's length may be more than one due to multi-byte UTF-8
  /// encoding or ligatures.
  range_start : UInt16
  /// The end of the range of the glyph in its item's text (UTF-8 bytes).
  range_end : UInt16
  /// The source code location of the text (upstream `span: (Span, u16)`,
  /// flattened into `span` and `span_offset` so that a glyph needs no
  /// boxed tuple).
  span : @syntax.Span
  /// The offset within the span.
  span_offset : UInt16
} derive(Eq, Hash)

///|
/// The range of the glyph in its item's text (UTF-8 bytes).
pub fn Glyph::range(self : Glyph) -> (Int, Int) {
  (self.range_start.to_int(), self.range_end.to_int())
}

///|
/// A slice of a [TextItem].
pub(all) struct TextItemView {
  /// The whole item this is a part of
  item : TextItem
  /// The start of the glyph range of this slice.
  glyph_start : Int
  /// The end of the glyph range of this slice.
  glyph_end : Int
}

///|
/// Build a [TextItemView] for the whole contents of a [TextItem].
pub fn TextItemView::full(text : TextItem) -> TextItemView {
  TextItemView::from_glyph_range(text, 0, text.glyphs.length())
}

///|
/// Build a new [TextItemView] from a [TextItem] and a range of glyphs.
pub fn TextItemView::from_glyph_range(
  text : TextItem,
  start : Int,
  end : Int,
) -> TextItemView {
  { item: text, glyph_start: start, glyph_end: end, }
}

///|
/// Returns the glyphs of the slice.
///
/// Note that the ranges are not remapped. They still point into the original
/// text.
pub fn TextItemView::glyphs(self : TextItemView) -> ArrayView[Glyph] {
  self.item.glyphs[self.glyph_start:self.glyph_end]
}

///|
/// The plain text for the given glyph from `glyphs()`. This is an
/// approximation since glyphs do not correspond 1-1 with codepoints.
pub fn TextItemView::glyph_text(self : TextItemView, glyph : Glyph) -> String {
  // Trim default ignorables which might have ended up in the glyph's
  // cluster. Keep interior ones so that joined emojis work. All of this is a
  // hack and needs to be reworked. See https://github.com/typst/typst/pull/5099
  let (start, end) = glyph.range()
  let chars = @syntax.utf8_slice(self.item.text, start, end).to_array()
  let mut lo = 0
  let mut hi = chars.length()
  while lo < hi && @unicode.is_default_ignorable(chars[lo]) {
    lo += 1
  }
  while hi > lo && @unicode.is_default_ignorable(chars[hi - 1]) {
    hi -= 1
  }
  String::from_array(chars[lo:hi])
}

///|
/// The total width of this text slice
pub fn TextItemView::width(self : TextItemView) -> Abs {
  sum_em(self.glyphs(), g => g.x_advance).at(self.item.size)
}

///|
/// The total height of this text slice
pub fn TextItemView::height(self : TextItemView) -> Abs {
  sum_em(self.glyphs(), g => g.y_advance).at(self.item.size)
}
