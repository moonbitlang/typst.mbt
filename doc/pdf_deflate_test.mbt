// The content streams of an exported PDF, end to end: what an export keeps
// of them between exports (`pdf/deflate.mbt`: the compressed stream, by the
// bytes of the stream, `library/memo_content.mbt`) does not change a byte
// of a file, and a page that is what it was is not compressed again.

///|
/// Three pages of text, a formula, a gradient and a tiling, with headings
/// (the document is tagged); `last` is text of the last page.
fn deflate_test_source(last : String) -> String {
  let head =
    #|#set page(width: 220pt, height: 160pt, margin: 12pt)
    #|#set document(date: datetime(year: 2026, month: 10, day: 12))
    #|#set heading(numbering: "1.")
    #|= First
    #|#lorem(40)
    #|$ sum_(k=0)^n k = (n (n + 1)) / 2 $
    #|#rect(width: 60pt, height: 12pt, fill: gradient.conic(red, blue))
    #|#pagebreak()
    #|= Second
    #|#lorem(35)
    #|#rect(
    #|  width: 60pt,
    #|  height: 12pt,
    #|  fill: tiling(size: (6pt, 6pt), square(size: 3pt, fill: green)),
    #|)
    #|#pagebreak()
    #|= Third
    #|#lorem(30)
    #|
    #|
  head + last + "\n"
}

///|
/// The file of [deflate_test_source].
fn deflate_test_file(
  last : String,
  standards~ : Array[@library.PdfStandard] = [],
  pretty~ : Bool = false,
  world~ : @doc.DocWorld = @doc.DocWorld::in_memory(),
) -> Bytes raise {
  let options = @pdf.PdfOptions::{
    ..@pdf.PdfOptions::default(),
    format: {
      ..@pdf.PartialPdfFormatOptions::default(),
      standard: Some(@library.PdfStandards::new(standards)),
      pretty: Some(pretty),
    },
  }
  @doc.Document([@doc.Markup(deflate_test_source(last))])
  .compile_paged(world)
  .pdf(options~)
  .unwrap()
}

///|
test "pdf: the content streams of an export are kept for the next, and its bytes are the same" {
  // The words of the last page in two orders: the same glyphs (so the same
  // fonts and ToUnicode CMaps), another content stream.
  let before = "alpha beta gamma delta"
  let after = "delta gamma beta alpha"
  // The reference: every file from nothing and without memoization.
  @library.evict(0)
  @library.set_layout_memo_enabled(false)
  let (plain_before, plain_after, plain_v2, plain_pretty) = {
    defer @library.set_layout_memo_enabled(true)
    let stats = @pdf.deflate_memo_stats()
    let files = (
      deflate_test_file(before),
      deflate_test_file(after),
      deflate_test_file(before, standards=[V_2_0]),
      deflate_test_file(before, pretty=true),
    )
    // Nothing was looked up.
    assert_eq(@pdf.deflate_memo_stats(), stats)
    files
  }
  assert_true(plain_before != plain_after)
  // The first export compresses every content stream: three pages, the
  // tile, the function of the gradient, and the ToUnicode CMaps of the
  // fonts.
  @library.evict(0)
  let (found, computed) = @pdf.deflate_memo_stats()
  assert_true(deflate_test_file(before) == plain_before)
  let (found_1, computed_1) = @pdf.deflate_memo_stats()
  assert_eq(found_1, found)
  let streams = computed_1 - computed
  assert_true(streams >= 6)
  // The second finds all of them.
  assert_true(deflate_test_file(before) == plain_before)
  assert_eq(@pdf.deflate_memo_stats(), (found + streams, computed_1))
  // After an edit of the last page, one stream is compressed.
  assert_true(deflate_test_file(after) == plain_after)
  assert_eq(
    @pdf.deflate_memo_stats(),
    (found + 2 * streams - 1, computed_1 + 1),
  )
  // And back: nothing is.
  assert_true(deflate_test_file(before) == plain_before)
  assert_eq(
    @pdf.deflate_memo_stats(),
    (found + 3 * streams - 1, computed_1 + 1),
  )
  // What is kept is not a document's: another standard writes its own
  // file, with the page streams of this one where they are the same bytes.
  let stats = @pdf.deflate_memo_stats()
  assert_true(deflate_test_file(before, standards=[V_2_0]) == plain_v2)
  assert_true(plain_v2 != plain_before)
  assert_true(@pdf.deflate_memo_stats().0 > stats.0)
  // A pretty file has its content streams as they are: nothing is looked
  // up, and nothing that was kept is written.
  let stats = @pdf.deflate_memo_stats()
  assert_true(deflate_test_file(before, pretty=true) == plain_pretty)
  assert_eq(@pdf.deflate_memo_stats(), stats)
  // After `evict` dropped everything the file is the same bytes again.
  @library.evict(0)
  let stats = @pdf.deflate_memo_stats()
  assert_true(deflate_test_file(after) == plain_after)
  assert_eq(@pdf.deflate_memo_stats(), (stats.0, stats.1 + streams))
  // One compilation exported twice.
  let report = compile([@doc.Markup(deflate_test_source(before))])
  let stats = @pdf.deflate_memo_stats()
  assert_true(report.pdf().unwrap() == plain_before)
  assert_true(report.pdf().unwrap() == plain_before)
  assert_eq(@pdf.deflate_memo_stats().1, stats.1 + 1)
}
