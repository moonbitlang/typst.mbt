// The fonts of an exported PDF, end to end: what an export keeps of them
// between exports (`pdf/subset.mbt`: the subset of a font, by the font and
// the glyphs, `library/memo_content.mbt`) does not change a byte of a file,
// and a font whose glyphs are what they were is not subset again.

///|
test "pdf: the font subsets of an export are kept for the next, and its bytes are the same" {
  // One world for all exports: a font is found again as the font object
  // of the engine, and a world has its own.
  let world = @doc.DocWorld::in_memory()
  // The words of the last page in two orders (the same glyphs, and all of
  // them were used on the pages before), and with a letter that the
  // document does not have yet.
  let before = "alpha beta gamma delta"
  let after = "delta gamma beta alpha"
  let more = "alpha beta gamma delta \u{00df}"
  // The reference: every file from nothing and without memoization.
  @library.evict(0)
  @library.set_layout_memo_enabled(false)
  let (plain_before, plain_after, plain_more, plain_v2, plain_pretty) = {
    defer @library.set_layout_memo_enabled(true)
    let stats = @pdf.subset_memo_stats()
    let files = (
      deflate_test_file(before, world~),
      deflate_test_file(after, world~),
      deflate_test_file(more, world~),
      deflate_test_file(before, standards=[V_2_0], world~),
      deflate_test_file(before, pretty=true, world~),
    )
    // Nothing was looked up.
    assert_eq(@pdf.subset_memo_stats(), stats)
    files
  }
  assert_true(plain_before != plain_after && plain_before != plain_more)
  // The first export subsets every font: the text, its bold, the math.
  @library.evict(0)
  let (found, computed) = @pdf.subset_memo_stats()
  assert_true(deflate_test_file(before, world~) == plain_before)
  let (found_1, computed_1) = @pdf.subset_memo_stats()
  assert_eq(found_1, found)
  let fonts = computed_1 - computed
  assert_true(fonts >= 3)
  // The second finds all of them.
  assert_true(deflate_test_file(before, world~) == plain_before)
  assert_eq(@pdf.subset_memo_stats(), (found + fonts, computed_1))
  // So does an export after an edit that brings no glyph.
  assert_true(deflate_test_file(after, world~) == plain_after)
  assert_eq(@pdf.subset_memo_stats(), (found + 2 * fonts, computed_1))
  // A new glyph: its font is subset again, the others are found.
  assert_true(deflate_test_file(more, world~) == plain_more)
  assert_eq(@pdf.subset_memo_stats(), (found + 3 * fonts - 1, computed_1 + 1))
  // What is kept is not a document's: another standard and a pretty file
  // embed the same subsets.
  assert_true(deflate_test_file(before, standards=[V_2_0], world~) == plain_v2)
  assert_true(deflate_test_file(before, pretty=true, world~) == plain_pretty)
  assert_eq(@pdf.subset_memo_stats(), (found + 5 * fonts - 1, computed_1 + 1))
  // Another world has other font objects: its fonts are subset for it.
  assert_true(deflate_test_file(before) == plain_before)
  assert_eq(
    @pdf.subset_memo_stats(),
    (found + 5 * fonts - 1, computed_1 + 1 + fonts),
  )
  // After `evict` dropped everything the file is the same bytes again.
  @library.evict(0)
  assert_true(deflate_test_file(after, world~) == plain_after)
  assert_eq(
    @pdf.subset_memo_stats(),
    (found + 5 * fonts - 1, computed_1 + 1 + 2 * fonts),
  )
}
