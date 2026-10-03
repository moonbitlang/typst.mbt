// Port of `typst-layout/src/inline/prepare.rs`.

///|
/// A representation in which children are already layouted and text is
/// already preshaped.
///
/// In many cases, we can directly reuse these results when constructing a
/// line. Only when a line break falls onto a text index that is not
/// safe-to-break per rustybuzz, we have to reshape that portion.
priv struct Preparation {
  /// The full text.
  text : Utf8Slice
  /// Configuration for inline layout.
  config : InlineConfig
  /// Bidirectional text embedding levels.
  ///
  /// This is `None` if all text directions are uniform (all the base
  /// direction).
  bidi : @bidi.BidiInfo?
  /// Text runs, spacing and layouted elements, with their text ranges.
  items : Array[(Int, Int, InlineItem)]
  /// Maps from byte indices to item indices.
  indices : Array[Int]
  /// The span mapper.
  spans : SpanMapper
  /// The breakpoints of `text` (computed on first use). Not upstream:
  /// upstream recomputes them for each line breaking pass; they only depend
  /// on the preparation, so they are cached here (performance).
  mut breakpoints : Array[(Int, @linebreak.Breakpoint)]?
}

///|
/// Get the item that contains the given `text_offset`.
fn Preparation::get(self : Preparation, offset : Int) -> (Int, Int, InlineItem) {
  let idx = self.indices.get(offset).unwrap_or(0)
  self.items[idx]
}

///|
/// The items that intersect the given `sliced` range alongside their
/// indices in `self.items` (upstream `Preparation::slice`).
fn Preparation::slice(self : Preparation, start : Int, end : Int) -> Array[Int] {
  // Usually, we don't want empty-range items at the start of the line
  // (because they will be part of the previous line), but for the first
  // line, we need to keep them.
  let first = match start {
    0 => 0
    n => self.indices.get(n).unwrap_or(0)
  }
  let out = []
  for i in first..<self.items.length() {
    let (s, e, _) = self.items[i]
    if !(s < end || e <= end) {
      break
    }
    out.push(i)
  }
  out
}

///|
/// Performs BiDi analysis and then prepares further layout by building a
/// representation on which we can do line breaking without layouting each
/// and every line from scratch.
fn prepare(
  engine : @library.Engine,
  config : InlineConfig,
  text : Utf8Slice,
  segments : Array[Segment],
  spans : SpanMapper,
) -> Preparation {
  let default_level = match config.dir {
    RTL => @bidi.Level::rtl()
    _ => @bidi.Level::ltr()
  }
  let bidi = @bidi.BidiInfo::new(text.to_string(), Some(default_level))
  let is_bidi = bidi.levels
    .iter()
    .any(level => level.is_ltr() != default_level.is_ltr())
  let mut cursor = 0
  let items = []

  // Shape the text to finalize the items.
  for segment in segments {
    let len = segment.textual_len()
    let end = cursor + len
    match segment {
      Text(_, styles) =>
        shape_range(items, engine, text, bidi, cursor, end, styles)
      Item(item) => items.push((cursor, end, item))
    }
    cursor = end
  }

  // Build the mapping from byte to item indices.
  let indices = Array::new(capacity=text.len())
  for i, entry in items {
    let (s, e, _) = entry
    for _ in s..<e {
      indices.push(i)
    }
  }
  if config.cjk_latin_spacing {
    add_cjk_latin_spacing(items)
  }
  {
    config,
    text,
    bidi: if is_bidi {
      Some(bidi)
    } else {
      None
    },
    items,
    indices,
    spans,
    breakpoints: None,
  }
}

///|
/// Add some spacing between Han characters and western characters. See
/// Requirements for Chinese Text Layout, Section 3.2.2 Mixed Text
/// Composition in Horizontal Written Mode
fn add_cjk_latin_spacing(items : Array[(Int, Int, InlineItem)]) -> Unit {
  let flat : Array[(ShapedGlyph, @library.ScriptKind?)?] = []
  for entry in items {
    match entry.2 {
      Tag(_) => ()
      Text(text) => {
        // Check whether the text is normal, sub- or superscript. At
        // boundaries between these three, we do not want to insert
        // CJK-Latin-Spacing.
        let shift = @library.TextElem::shift_settings_in(text.styles).map(shift => {
          shift.kind
        })

        // Since we only call this function in [`prepare`], we can assume
        // that the glyphs are owned.
        for g in text.glyphs.to_mut() {
          flat.push(Some((g, shift)))
        }
      }
      _ => flat.push(None)
    }
  }
  let mut prev : (ShapedGlyph, @library.ScriptKind?)? = None
  for i, item in flat {
    if item is Some((glyph, shift)) {
      // Case 1: CJ followed by a Latin character
      if glyph.is_cj_script() &&
        flat.get(i + 1) is Some(Some((next_glyph, next_shift))) &&
        next_glyph.is_letter_or_number() &&
        shift == next_shift {
        // The spacing defaults to 1/4 em, and can be shrunk to 1/8 em.
        glyph.x_advance = glyph.x_advance + @library.Em::new(0.25)
        let (l, r) = glyph.adjustability.shrinkability
        glyph.adjustability = {
          ..glyph.adjustability,
          shrinkability: (l, r + @library.Em::new(0.125)),
        }
      }

      // Case 2: Latin followed by a CJ character
      if glyph.is_cj_script() &&
        prev is Some((prev_glyph, prev_shift)) &&
        prev_glyph.is_letter_or_number() &&
        shift == prev_shift {
        glyph.x_advance = glyph.x_advance + @library.Em::new(0.25)
        glyph.x_offset = glyph.x_offset + @library.Em::new(0.25)
        let (l, r) = glyph.adjustability.shrinkability
        glyph.adjustability = {
          ..glyph.adjustability,
          shrinkability: (l + @library.Em::new(0.125), r),
        }
        prev_glyph.is_justifiable = true
      }
    }
    prev = item
  }
}
