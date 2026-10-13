// The subsets of fonts that are kept between exports
// (`subset_font_memoized`, `library/memo_content.mbt`): what a subset is
// found by, that a file is the same bytes with and without what is kept,
// and how long a subset stays.

///|
/// An empty cache, memoization on.
fn subset_test_reset() -> Unit {
  @library.set_layout_memo_enabled(true)
  @library.evict(0)
}

///|
/// A font of the engine from the embedded fonts (a new object in every
/// call), with its instance.
fn subset_test_instance(n : Int32) -> @library.FontInstance raise {
  let data = @assets_fonts.fonts()[n]
  guard @library.Font::from_data(data, 0) is Some(font) else {
    fail("not a font")
  }
  font.instantiate_with(@library.FontVariations::default())
}

///|
/// A file of one page with the glyphs `ids` of each font, drawn in the
/// order of the fonts; `fonts` is the table of the export (the exporter's
/// font and the engine's).
fn subset_test_file(
  fonts : Array[(@export.Font, @library.FontInstance)],
  ids : Array[Int32],
  drawn~ : Array[@export.Font] = fonts.map(f => f.0),
) -> Result[Bytes, String] {
  let settings : @export.SerializeSettings = {
    ..@export.SerializeSettings::default(),
    enable_tagging: false,
  }
  let document = @export.Document::new_with(settings, memo=export_memo(fonts))
  let page = document.start_page_with(
    @export.PageSettings::from_wh(300.0, 300.0).unwrap(),
  )
  let surface = page.surface()
  surface.set_fill(Some(@export.Fill::default()))
  for n, font in drawn {
    let glyphs : Array[@export.Glyph] = ids.mapi((i, id) => {
      glyph_id: id,
      text_start: i,
      text_end: i + 1,
      x_advance: 0.5,
      x_offset: 0.0,
      y_advance: 0.0,
      y_offset: 0.0,
      location: None,
    })
    surface.draw_glyphs(
      @export.Point::from_xy(10.0, 20.0 * (n + 1).to_double()),
      glyphs[:],
      font,
      "abcdefgh".unsafe_substring(start=0, end=ids.length()),
      10.0,
    )
  }
  surface.finish()
  page.finish()
  try document.finish() catch {
    FontError(_, message) => Err("font: \{message}")
    _ => Err("another error")
  } noraise {
    bytes => Ok(bytes)
  }
}

///|
/// The file without anything kept.
fn subset_test_plain(
  fonts : Array[(@export.Font, @library.FontInstance)],
  ids : Array[Int32],
  drawn~ : Array[@export.Font] = fonts.map(f => f.0),
) -> Result[Bytes, String] {
  @library.set_layout_memo_enabled(false)
  defer @library.set_layout_memo_enabled(true)
  subset_test_file(fonts, ids, drawn~)
}

///|
test "subset: a font is subset once for the glyphs it has, in their order" {
  subset_test_reset()
  let instance = subset_test_instance(0)
  let fonts = [(build_font(instance), instance)]
  let (found, computed) = subset_memo_stats()
  let first = subset_test_file(fonts, [40, 41, 42])
  assert_true(first is Ok(_))
  assert_eq(subset_cache.length(), 1)
  assert_eq(subset_memo_stats(), (found, computed + 1))
  // The same glyphs again: found, and the file is the same bytes; so it is
  // for another exporter's font of the same font of the engine (every
  // export makes its own).
  assert_true(subset_test_file(fonts, [40, 41, 42]) == first)
  let again = [(build_font(instance), instance)]
  assert_false(physical_equal(again[0].0, fonts[0].0))
  assert_true(subset_test_file(again, [40, 41, 42]) == first)
  assert_eq(subset_memo_stats(), (found + 2, computed + 1))
  // A glyph that is used twice is in the subset once.
  assert_true(subset_test_file(fonts, [40, 41, 40, 42]) is Ok(_))
  assert_eq(subset_memo_stats(), (found + 3, computed + 1))
  // Other glyphs are other subsets: one more, one less, another one, the
  // same in another order.
  let variants = [[40, 41, 42, 43], [40, 41], [40, 41, 44], [42, 41, 40]]
  for i, ids in variants {
    let file = subset_test_file(fonts, ids)
    assert_true(file is Ok(_) && file != first)
    assert_eq(subset_cache.length(), i + 2)
    assert_true(subset_test_file(fonts, ids) == file)
    assert_true(subset_test_plain(fonts, ids) == file)
  }
  assert_eq(
    subset_memo_stats(),
    (found + 3 + variants.length(), computed + 1 + variants.length()),
  )
  // The first is still what it was, and what it is without anything kept.
  assert_true(subset_test_file(fonts, [40, 41, 42]) == first)
  assert_true(subset_test_plain(fonts, [40, 41, 42]) == first)
  assert_eq(subset_cache.length(), 5)
}

///|
test "subset: the font is part of what a subset is found by" {
  subset_test_reset()
  // Two fonts of the engine and the same glyph IDs in both.
  let a = subset_test_instance(0)
  let b = subset_test_instance(1)
  let fonts = [(build_font(a), a), (build_font(b), b)]
  let ids = [40, 41, 42]
  let (found, computed) = subset_memo_stats()
  let both = subset_test_file(fonts, ids)
  assert_eq(subset_memo_stats(), (found, computed + 2))
  assert_true(both is Ok(_))
  assert_true(subset_test_plain(fonts, ids) == both)
  // Each alone, from what the file of both kept: the subset of its font.
  let only_a = subset_test_file([fonts[0]], ids)
  let only_b = subset_test_file([fonts[1]], ids)
  assert_eq(subset_memo_stats(), (found + 2, computed + 2))
  assert_true(only_a != only_b)
  assert_true(subset_test_plain([fonts[0]], ids) == only_a)
  assert_true(subset_test_plain([fonts[1]], ids) == only_b)
  // Another font object of the same data is another font here (the engine
  // identifies a font by its object): subset again, to the same bytes.
  let c = subset_test_instance(0)
  assert_true(c.font().serial() != a.font().serial())
  assert_true(subset_test_file([(build_font(c), c)], ids) == only_a)
  assert_eq(subset_memo_stats(), (found + 2, computed + 3))
  // The variation coordinates of the exporter's font are part of it too.
  let data = a.font().data()
  let wght = @subsetter.Tag::from_str("wght").unwrap()
  let light = @export.Font::new_variable(data, 0, [(wght, 300.0)]).unwrap()
  let heavy = @export.Font::new_variable(data, 0, [(wght, 900.0)]).unwrap()
  assert_true(subset_test_file([(light, a)], ids) is Ok(_))
  assert_eq(subset_memo_stats(), (found + 2, computed + 4))
  assert_true(subset_test_file([(heavy, a)], ids) is Ok(_))
  assert_eq(subset_memo_stats(), (found + 2, computed + 5))
  assert_true(subset_test_file([(light, a)], ids) is Ok(_))
  assert_eq(subset_memo_stats(), (found + 3, computed + 5))
}

///|
test "subset: a font that the engine does not know is subset for every export" {
  subset_test_reset()
  let instance = subset_test_instance(0)
  let font = build_font(instance)
  let stats = subset_memo_stats()
  // The table of the export does not have the font (a font that only the
  // text of an SVG image uses).
  let first = subset_test_file([], [40, 41], drawn=[font])
  assert_true(first is Ok(_))
  assert_true(subset_test_file([], [40, 41], drawn=[font]) == first)
  assert_eq(subset_memo_stats(), stats)
  assert_eq(subset_cache.length(), 0)
  // It is the file of the font that the engine knows.
  assert_true(subset_test_file([(font, instance)], [40, 41]) == first)
  assert_eq(subset_cache.length(), 1)
}

///|
test "subset: with memoization off nothing is looked up or kept" {
  subset_test_reset()
  let instance = subset_test_instance(0)
  let fonts = [(build_font(instance), instance)]
  let kept = subset_test_file(fonts, [40, 41, 42])
  let stats = subset_memo_stats()
  assert_true(subset_test_plain(fonts, [40, 41, 42]) == kept)
  assert_true(subset_test_plain(fonts, [50, 51]) is Ok(_))
  assert_eq(subset_memo_stats(), stats)
  assert_eq(subset_cache.length(), 1)
}

///|
test "subset: a kept subset has comemo's age" {
  subset_test_reset()
  let instance = subset_test_instance(0)
  let fonts = [(build_font(instance), instance)]
  let a = [40, 41, 42]
  let b = [50, 51]
  let file_a = subset_test_file(fonts, a)
  let file_b = subset_test_file(fonts, b)
  assert_eq(subset_cache.length(), 2)
  // `a` is found after every eviction, `b` never: it survives ten and goes
  // with the eleventh.
  for i in 0..<10 {
    @library.evict(10)
    assert_true(subset_test_file(fonts, a) == file_a)
    assert_eq(subset_cache.length(), 2, msg="eviction \{i + 1}")
  }
  @library.evict(10)
  assert_eq(subset_cache.length(), 1)
  let computed = subset_memo_stats().1
  assert_true(subset_test_file(fonts, a) == file_a)
  assert_eq(subset_memo_stats().1, computed)
  // What was dropped is made again, to the same bytes.
  assert_true(subset_test_file(fonts, b) == file_b)
  assert_eq(subset_memo_stats().1, computed + 1)
  @library.evict(0)
  assert_eq(subset_cache.length(), 0)
}

///|
test "subset: a font that cannot be subset fails in every export, and nothing is kept" {
  subset_test_reset()
  // A font without its glyphs: the outlines that the subset needs are not
  // there. (The table says it is a font of the engine, so it is looked up.)
  let instance = subset_test_instance(0)
  let data = instance.font().data()
  let broken = Bytes::makei(data.length(), i => {
    if i >= data.length() / 2 {
      b'\xff'
    } else {
      data[i]
    }
  })
  guard @export.Font::new(broken, 0) is Some(font) else {
    fail("the exporter does not take it for a font")
  }
  let stats = subset_memo_stats()
  let first = subset_test_file([(font, instance)], [40, 41])
  let second = subset_test_file([(font, instance)], [40, 41])
  assert_true(
    first == Err("font: failed to subset font: processing CFF table failed"),
  )
  assert_true(first == second)
  // Asked twice, made twice, kept never.
  assert_eq(subset_memo_stats(), (stats.0, stats.1 + 2))
  assert_eq(subset_cache.length(), 0)
  assert_true(subset_test_plain([(font, instance)], [40, 41]) == first)
}
