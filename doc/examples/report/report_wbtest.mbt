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
    // Two pages: the tiles and the cards on the first, the table of the
    // beds, which is not as high as a page, on the second.
    assert_eq(compiled.unwrap().pages().length(), 2)
  }
}

///|
test "the hand-written helpers and the kit's elements are the same pages" {
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

///|
/// The straight lines of a frame, and its text runs, counted.
fn count(frame : @library.Frame, lines : Ref[Int], runs : Ref[Int]) -> Unit {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => count(group.frame, lines, runs)
      Shape({ geometry: Line(_), .. }, _) => lines.val += 1
      Text(_) => runs.val += 1
      _ => ()
    }
  }
}

///|
test "where the table continues on the next page, the two differ by one rule" {
  // The table of the beds alone, on a page that holds its header and seven
  // of its ten rows.
  let world = @doc.DocWorld::in_memory()
  let on_short_page = (table : &IntoContent) => {
    let document = Document([
      SetPage(width=Pt(420), height=Pt(190), margin=Sides(all=Pt(18))),
      SetText(size=Pt(10), fill=ink),
      table,
    ])
    let compiled : @doc.CompileReport[@layout.PagedDocument] = document.compile_paged(
      world,
    )
    assert_eq(compiled.errors.map(e => e.message), [])
    compiled
    .unwrap()
    .pages()
    .map(page => {
      let lines = Ref(0)
      let runs = Ref(0)
      count(page.frame, lines, runs)
      "\{lines.val} lines, \{runs.val} runs"
    })
    .join("; ")
  }
  // By hand: a rule under every row but the table's last. The engine draws
  // the rule under the last row of the first page too, on the outline of
  // the frame.
  inspect(
    on_short_page(bed_table_before(bed_columns)),
    content=(
      #|8 lines, 40 runs; 3 lines, 20 runs
    ),
  )
  // `DataTable`: no rule under the last row of a page, which its frame
  // closes like the table's last. The text is the same.
  inspect(
    on_short_page(bed_table_after(bed_columns)),
    content=(
      #|7 lines, 40 runs; 3 lines, 20 runs
    ),
  )
}
