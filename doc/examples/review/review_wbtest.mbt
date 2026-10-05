// Click to source on the showcase (docs/edsl-review.md, slice 1): a
// click on known spots of the rendered document leads to the constructor
// call that the source file has at the expected line and column. The
// expected positions are found by searching the source file, and the
// points to click by searching the frames, independently of the lookup.

///|
/// The source of the showcase.
let bench_file : String = "doc/twins/bench.mbt"

///|
/// The one-based line and column (in code points) of the first occurrence
/// of `needle` in `text`.
fn position_of(text : String, needle : String) -> (Int, Int) {
  let wanted = needle.to_array()
  for i, line in text.split("\n").map(l => l.to_owned()).collect() {
    let chars = line.to_array()
    for at in 0..<(chars.length() - wanted.length() + 1) {
      if chars[at:at + wanted.length()] == wanted[:] {
        return (i + 1, at + 1)
      }
    }
  }
  abort("`\{needle}` is not in the source")
}

///|
/// The page and the point (in points, from the page's top left corner) in
/// the middle of the glyph that starts the `nth` occurrence of `needle`
/// in the text items of the document.
fn point_of(
  report : @doc.CompileReport[@layout.PagedDocument],
  needle : String,
  nth? : Int = 0,
) -> (Int, Double, Double) raise {
  let seen = [0]
  fn search(
    frame : @library.Frame,
    ts : @library.Transform,
  ) -> (Double, Double)? {
    for entry in frame.items() {
      let (pos, item) = entry
      match item {
        Group(group) => {
          let inner = ts
            .pre_concat(@library.Transform::translate(pos.x, pos.y))
            .pre_concat(group.transform)
          if search(group.frame, inner) is Some(found) {
            return Some(found)
          }
        }
        Text(text) => {
          guard text.text.find(needle) is Some(at) else { continue }
          seen[0] += 1
          guard seen[0] > nth else { continue }
          // The glyph whose cluster starts at the needle.
          let start = @utf8.encode(text.text[:at].to_owned()).length()
          let mut x = pos.x
          for glyph in text.glyphs {
            let width = glyph.x_advance.at(text.size)
            if glyph.range().0 == start {
              let point = @library.Point::new(
                @library.Abs::pt(x.to_pt() + width.to_pt() / 2.0),
                @library.Abs::pt(pos.y.to_pt() - text.size.to_pt() / 2.0),
              ).transform(ts)
              return Some((point.x.to_pt(), point.y.to_pt()))
            }
            x = x + width
          }
        }
        _ => ()
      }
    }
    None
  }

  for i, page in report.unwrap().pages() {
    if search(page.frame, @library.Transform::identity()) is Some((x, y)) {
      return (i + 1, x, y)
    }
  }
  fail("`\{needle}` (occurrence \{nth}) is not in the document")
}

///|
/// The origin of a click on the start of `needle`, which the upstream
/// lookup must name as well unless a link is there.
fn spot(
  report : @doc.CompileReport[@layout.PagedDocument],
  needle : String,
  nth? : Int = 0,
) -> @doc.Origin raise {
  let (page, x, y) = point_of(report, needle, nth~)
  guard report.origin_at(page, x, y) is Some(origin) else {
    fail("the click on `\{needle}` hits nothing with a source")
  }
  match report.jump_from_click(page, x, y) {
    Some(Source(jump)) => assert_eq(jump.describe(), origin.describe())
    // An outline entry is a link to its heading.
    Some(Position(..)) | Some(Url(_)) => ()
    None => fail("upstream's lookup finds nothing at `\{needle}`")
  }
  origin
}

///|
test "clicks on the showcase lead to the constructor calls of its source" {
  // Embedded fonts only, so that the result does not depend on the machine.
  let report = compile_document(@twins.full_showcase)
  assert_true(report.errors.is_empty())
  let source = @utf8.decode(@system.read(bench_file))
  let at = (origin : @doc.Origin) => (origin.start_line, origin.start_column)

  // A heading (the second occurrence in the document: the first is the
  // outline entry, which has the same origin): the argument of `Heading`.
  let heading = spot(report, "Tables and figures", nth=1)
  assert_eq(heading.file, bench_file)
  assert_eq(heading.kind, "Heading")
  assert_eq(heading.param, Some(0))
  let call = position_of(source, "Heading(\"Tables and figures\")")
  assert_eq(at(heading), (call.0, call.1 + 8))
  assert_eq(heading.end_column - heading.start_column, 20)
  assert_eq(spot(report, "Tables and figures").describe(), heading.describe())

  // A figure caption: the labelled argument of `Figure`.
  let caption = spot(report, "Differential test stages")
  assert_eq(caption.kind, "Figure")
  let call = position_of(source, "caption=\"Differential test stages")
  assert_eq(at(caption), (call.0, call.1 + 8))
  assert_true(caption.param is Some(_))

  // A table cell built in a loop: the argument of the table that holds
  // the cells (the variable `stage_cells`).
  let cell = spot(report, "parser, AST, incremental reparse")
  assert_eq(cell.kind, "Table")
  assert_eq(cell.param, Some(0))
  assert_eq(at(cell).0, position_of(source, "stage_cells,").0)

  // The page header made by a `Context` callback: the constructor call
  // inside the callback.
  let header = spot(report, "typst.mbt — a MoonBit port of Typst")
  assert_eq(header.kind, "Emph")
  let call = position_of(
    source, "Emph(\"typst.mbt — a MoonBit port of Typst\")",
  )
  assert_eq(at(header), (call.0, call.1 + 5))

  // The images (a JPEG, an SVG and a PDF): a coarse grid of clicks over
  // the pages finds each at the line and column of its `Image(..)` call.
  let images : Array[(Int, Int)] = []
  for i, page in report.unwrap().pages() {
    let size = page.frame.size()
    for row in 1..<40 {
      for column in 1..<20 {
        let x = size.x.to_pt() * column.to_double() / 20.0
        let y = size.y.to_pt() * row.to_double() / 40.0
        if report.origin_at(i + 1, x, y) is Some(origin) &&
          origin.kind == "Image" &&
          !images.contains(at(origin)) {
          assert_eq(origin.param, None)
          images.push(at(origin))
        }
      }
    }
  }
  assert_eq(images, [
    position_of(source, "Image(\"glacier.jpg\""),
    position_of(source, "Image(\"diagram.svg\""),
    position_of(source, "Image(\"matplotlib.pdf\""),
  ])

  // The preview page has the origins of all of them, and its pages are
  // the SVG of the normal export.
  let html = report.review_html().unwrap()
  assert_true(html.contains("<title>typst.mbt Showcase review</title>"))
  for kind in ["Heading", "Figure", "Table", "Emph", "Image", "Prose"] {
    assert_true(html.contains("\"kind\":\"\{kind}\""))
  }
  let pages = report.svg_pages().unwrap()
  assert_eq(pages.length(), 4)
  for svg in pages {
    assert_true(html.contains(svg))
  }
}

///|
test "selections on the showcase become feedback with the origins they cover" {
  let report = compile_document(@twins.full_showcase)
  let text = report.review_text()
  let source = @utf8.decode(@system.read(bench_file))
  // Words of one prose block: one origin, the text argument, and one
  // piece per word.
  let prose = text.feedback(
    text.find("Knuth–Plass style optimizer,").unwrap(),
    "",
  )
  assert_eq(prose.selected_text, "Knuth–Plass style optimizer,")
  assert_eq(prose.origins.length(), 1)
  assert_eq(prose.origins[0].origin.kind, "Prose")
  assert_eq(prose.origins[0].pieces, ["Knuth–Plass", "style", "optimizer,"])
  let call = position_of(source, "$|Typst lays out text with a Knuth–Plass")
  assert_eq(prose.origins[0].origin.start_line, call.0)
  // From a heading into the paragraph after it: two origins, in reading
  // order.
  let across = text.feedback(
    text.find("Text and paragraphs Typst lays out").unwrap(),
    "Tighten this.",
  )
  assert_eq(across.origins.map(o => o.origin.kind), ["Heading", "Prose"])
  assert_eq(across.origins[0].pieces, ["Text and paragraphs"])
  assert_eq(across.origins[1].rendered, "Typst lays out")
  assert_eq(across.pages, [1])
  let block = across.to_text()
  assert_true(
    block.has_prefix(
      "Review comment on \"typst.mbt Showcase\" (a document rendered from MoonBit source by typst.mbt)\nComment: Tighten this.\n",
    ),
  )
  let call = position_of(source, "Heading(\"Text and paragraphs\")")
  assert_true(
    block.contains(
      "Source 1 of 2: \{bench_file}:\{call.0}:\{call.1 + 8}-\{call.0}:\{call.1 + 29}, Heading(..), parameter 1\n  rendered: \"Text and paragraphs\"\n",
    ),
  )
  // Cells of the table that is built in a loop: pieces of the argument
  // that holds the cells.
  let cells = text.feedback(text.find("incremental reparse 3 792").unwrap(), "")
  assert_eq(cells.origins.length(), 1)
  assert_eq(cells.origins[0].origin.kind, "Table")
  assert_eq(cells.origins[0].pieces, ["incremental reparse", "3 792"])
  // The page carries the words and the library's records for its
  // self-test.
  let html = report.review_html().unwrap()
  assert_true(html.contains("\"words\":[[1,\""))
  assert_true(html.contains("[1,\"Knuth–Plass\",1,"))
  assert_true(
    html.contains(
      "\"samples\":[[0,0,{\"format\":\"typst.mbt review feedback 1\"",
    ),
  )
}
