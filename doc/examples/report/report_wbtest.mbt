// The two versions of the report are the same pages.

///|
test "the report compiles in both versions, without warnings" {
  let world = @doc.DocWorld::in_memory()
  for version in versions() {
    let compiled : @doc.CompileReport[@layout.PagedDocument] = (version.1)().compile_paged(
      world,
    )
    assert_eq(compiled.errors.map(e => e.message), [])
    assert_eq(compiled.warnings.map(w => w.message), [])
    assert_eq(compiled.lints.map(l => l.message), [])
    // One page: the cards and tiles are not as high as the page.
    assert_eq(compiled.unwrap().pages().length(), 1)
  }
}

///|
test "the hand-written cards and the kit's are the same pages" {
  let world = @doc.DocWorld::in_memory()
  let svg = (build : () -> Document) => {
    build().compile_paged(world).svg_pages().unwrap()
  }
  let pages_before = svg(before)
  let pages_after = svg(after)
  assert_eq(pages_before.length(), pages_after.length())
  for i, page in pages_before {
    assert_true(page == pages_after[i])
  }
  // And the PDF, byte for byte.
  let pdf = (build : () -> Document) => {
    build().compile_paged(world).pdf().unwrap()
  }
  assert_true(pdf(before) == pdf(after))
}
