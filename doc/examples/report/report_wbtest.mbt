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
/// A length in tenths of a point.
fn tenths(x : Double) -> String {
  let n = (x * 10.0).round().to_int()
  "\{n / 10}.\{n % 10}"
}

///|
/// What a frame at `(dx, dy)` on the page `page` draws, each with its place:
/// the straight lines (with their extent), the other shapes (with their
/// stroke and fill), and the text runs.
fn drawn(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  page : Int,
  lines : Array[String],
  rest : Array[String],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    let at = "p\{page} \{tenths(x)},\{tenths(y)}"
    match entry.1 {
      Group(group) =>
        drawn(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          page,
          lines,
          rest,
        )
      Shape({ geometry: Line(to), .. }, _) =>
        lines.push("\{at} \{tenths(to.x.to_pt())}x\{tenths(to.y.to_pt())}")
      Shape(shape, _) => {
        let fill = shape.fill.map(paint => paint.repr()).unwrap_or("")
        let stroke = shape.stroke
          .map(stroke => stroke.paint.repr())
          .unwrap_or("")
        rest.push("\{at} shape \{fill} \{stroke}")
      }
      Text(text) => rest.push("\{at} \{tenths(text.size.to_pt())} \{text.text}")
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
    let lines : Array[String] = []
    let rest : Array[String] = []
    for i, page in compiled.unwrap().pages() {
      drawn(page.frame, 0.0, 0.0, i + 1, lines, rest)
    }
    (lines, rest)
  }
  let (lines_before, rest_before) = on_short_page(bed_table_before(bed_columns))
  let (lines_after, rest_after) = on_short_page(bed_table_after(bed_columns))
  // The text, the fills, the chips and the frames are the same, at the
  // same places, on both pages.
  assert_eq(rest_after, rest_before)
  assert_eq(
    rest_after.filter(item => item.has_prefix("p2 ")).length() > 20,
    true,
  )
  // The rules of the version with the kit are rules of the hand-written
  // version, which has one more: the rule under the last row of the first
  // page. A rule under every row but the table's last is what the helper
  // asked for; the engine draws the line under a page's last row where the
  // table's bottom border is, on the outline of the frame.
  for line in lines_after {
    assert_true(lines_before.contains(line))
  }
  inspect(
    lines_before.filter(line => !lines_after.contains(line)).join("\n"),
    content=(
      #|p1 17.8,158.1 384.5x0.0
    ),
  )
  // (Seven rules on the first page and three on the second are in both.)
  assert_eq(lines_after.length(), 10)
  assert_eq(lines_before.length(), 11)
}
