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
      "\"samples\":[[0,0,{\"format\":\"typst.mbt review feedback 2\"",
    ),
  )
}

///|
/// This file, for the documents that are written in it.
let this_file : String = "doc/examples/review/review_wbtest.mbt"

///|
/// The feedback for an occurrence of `needle` in a small document that is
/// written in this file, with the sources read from disk.
fn feedback_in(
  children : Array[&@doc.IntoContent],
  needle : String,
  nth? : Int = 0,
) -> @doc.Feedback raise {
  let text = @doc.Document(children)
    .compile_paged(@doc.DocWorld::in_memory())
    .review_text(sources=@system.sources())
  guard text.find(needle, nth~) is Some(selection) else {
    fail("`\{needle}` is not in the document")
  }
  text.feedback(selection, "")
}

///|
/// The source characters of the first origin as `+lines:+columns text`:
/// where each run starts, relative to the place of `anchor` in this file
/// (found by searching the file), and its source text.
fn chars_of(feedback : @doc.Feedback, anchor : String) -> String raise {
  let at = position_of(@utf8.decode(@system.read(this_file)), anchor)
  feedback.origins[0].source_ranges
  .map(r => {
    assert_eq(r.end - r.start, r.text.to_array().length())
    "+\{r.line - at.0}:+\{r.start - at.1} \{r.text}"
  })
  .join(" | ")
}

///|
test "source characters: literals, escapes, array elements, prose" {
  // A plain literal: the selected words, at their columns.
  let plain = feedback_in([@doc.Par("Hello brave new world")], "brave new")
  assert_eq(plain.origins[0].tier, 3)
  inspect(chars_of(plain, "brave new world\")]"), content="+0:+0 brave new")
  // Escapes: the source text of the characters, as it is written.
  let escaped = feedback_in(
    [@doc.Par("say \"quoted\" and \u{e9}t\u{e9} done")],
    "été",
  )
  inspect(
    chars_of(escaped, "\\u{e9}t\\u{e9} done\")]"),
    content=(
      #|+0:+0 \u{e9}t\u{e9}
    ),
  )
  // The strings of an array are pieces of one argument: each word is
  // found in its element; a call between them is another origin.
  let array = feedback_in(
    [@doc.Par(@doc.Seq(["alpha beta ", @doc.Emph("gamma"), " delta beta"]))],
    "beta",
    nth=1,
  )
  assert_eq(array.origins[0].origin.kind, "Seq")
  inspect(chars_of(array, "beta\"]))],"), content="+0:+0 beta")
  // Prose: an interpolated description is a hole, the quotes are set by
  // the engine, the text is reflowed; a selection across the hole is two
  // runs of source characters.
  let prose = feedback_in(
    [
      @doc.Prose(
        (
          $|First line with "quotes" and
          $|a \{@doc.Emph("stressed")} second line.
        ),
      ),
    ],
    "and a stressed second",
  )
  assert_eq(prose.origins.map(o => (o.origin.kind, o.tier)), [
    ("Prose", 3),
    ("Emph", 3),
  ])
  inspect(
    chars_of(prose, "$|First line with"),
    content="+0:+27 and | +1:+2 a | +1:+29 second",
  )
  assert_eq(prose.origins[0].excerpt.length(), 2)
  let block = prose.to_text()
  assert_true(block.contains("          $|First line with \"quotes\" and\n"))
  assert_true(block.contains(" and\n       | "))
  assert_true(block.contains("^^^\n"))
  // The quotes themselves are source characters, too.
  let quoted = feedback_in(
    [@doc.Prose("Some \"quoted words\" here.")],
    "“quoted",
  )
  inspect(
    chars_of(quoted, "\\\"quoted words\\\" here.\")],"),
    content=(
      #|+0:+0 \"quoted
    ),
  )
  // A heading is on the page twice with an outline: both are the literal.
  let twice = [0, 1].map(nth => {
    feedback_in([@doc.Outline(), @doc.Heading("Repeated title")], "title", nth~).origins[0]
  })
  assert_eq(twice.map(o => o.tier), [3, 3])
  assert_eq(twice[0].source_ranges[0].text, "title")
  assert_eq(twice[0].source_ranges[0].start, twice[1].source_ranges[0].start)
  // A selection from the end of the first copy to the end of the second:
  // its runs overlap in the source, and all of it is marked once.
  let text = @doc.Document([@doc.Outline(), @doc.Heading("Repeated title")])
    .compile_paged(@doc.DocWorld::in_memory())
    .review_text(sources=@system.sources())
  let whole = text.feedback(text.find("Repeated title", nth=1).unwrap(), "").origins[0]
  assert_eq(whole.source_ranges.map(r => r.text), ["Repeated title"])
  let across = text.feedback(
    text.find("title").unwrap().through(text.find("title", nth=1).unwrap()),
    "",
  )
  let heading = across.origins.filter(o => o.origin.kind == "Heading")[0]
  assert_eq(heading.source_ranges.map(r => r.text), ["title", "Repeated title"])
  let block = across.to_text()
  assert_true(block.contains(" ^^^^^^^^^^^^^^\n"))
  assert_true(!block.contains("^^^^^^^^^^^^^^^"))
  // More lines than an excerpt shows: six, and the number of the rest.
  let long = feedback_in(
      [
        @doc.Prose(
          (
            #|one
            #|two
            #|three
            #|four
            #|five
            #|six
            #|seven
            #|eight
          ),
        ),
      ],
      "one two three four five six seven eight",
    ).origins[0]
  assert_eq(long.tier, 3)
  assert_eq(long.source_ranges.length(), 8)
  assert_eq(long.excerpt.length(), 6)
  assert_eq(long.more, 2)
}

///|
test "source characters are not claimed where the literal is not the text" {
  let note = (feedback : @doc.Feedback) => {
    let origin = feedback.origins[0]
    assert_true(origin.source_ranges.is_empty())
    (origin.tier, origin.why)
  }
  // A variable: the argument's source is shown, and named as a binding.
  let subtitle = "bound words"
  let bound = feedback_in([@doc.Par(subtitle)], "bound")
  assert_eq(
    note(bound),
    (
      2, "the argument is the variable `subtitle`: the text comes from a binding, not from a literal at this location",
    ),
  )
  assert_eq(bound.origins[0].excerpt.length(), 1)
  assert_true(
    bound
    .to_text()
    .contains(
      "  let bound = feedback_in([@doc.Par(subtitle)], \"bound\")\n       |                                     ^^^^^^^^\n",
    ),
  )
  // An expression.
  let computed = feedback_in([@doc.Par(subtitle + " more")], "more")
  assert_true(note(computed).1.contains("is an expression, not a literal"))
  // An interpolated string: its literal is not all of the text.
  let count = 3
  let mixed = feedback_in([@doc.Par("counted \{count} times")], "times")
  assert_eq(note(mixed).0, 2)
  assert_true(
    note(mixed).1.contains("an interpolation or a computed element adds text"),
  )
  // Text that the engine changes on the way.
  let upper = feedback_in(
    [
      @doc.Par(
        @doc.Call("upper", positional=[
          @doc.Value::content(@doc.Text("shouted words")),
        ]),
      ),
    ],
    "SHOUTED",
  )
  assert_eq(note(upper).0, 2)
  assert_true(
    note(upper).1.contains("is not the text on the page as it is written"),
  )
  // What is hidden or scaled away has origins of its own: the literal
  // beside it is still all of its own text.
  let hidden = feedback_in(
    [
      @doc.Par(
        @doc.Seq([
          "seen ",
          @doc.Hide(@doc.Emph("gone")),
          @doc.Scale("lost words", x=Pct(0), y=Pct(100)),
        ]),
      ),
      @doc.Par(@doc.Scale(@doc.Seq(["kept ", "and"]), x=Pct(50))),
    ],
    "seen",
  )
  assert_eq(hidden.origins[0].tier, 3)
  // Content that is no text of an argument: the call.
  let markup = feedback_in([@doc.Markup("Some *bold* markup")], "bold")
  assert_eq(
    note(markup),
    (
      1, "the location is the constructor call: what was selected is not the text of one of its arguments",
    ),
  )
  assert_eq(markup.origins[0].excerpt.length(), 1)
  // Without a source provider nothing is read: the argument, no excerpt.
  let text = @doc.Document([@doc.Par("unread words")])
    .compile_paged(@doc.DocWorld::in_memory())
    .review_text()
  let unread = text.feedback(text.find("unread").unwrap(), "").origins[0]
  assert_eq(unread.tier, 2)
  assert_true(unread.excerpt.is_empty())
  assert_true(unread.why.contains("was not read"))
}

///|
test "the showcase's feedback has source characters and excerpts" {
  let report = compile_document(@twins.full_showcase)
  let text = report.review_text(sources=@system.sources())
  let source = @utf8.decode(@system.read(bench_file))
  // Words of a prose block: their characters in the multi-line string.
  let prose = text.feedback(
      text.find("Knuth–Plass style optimizer,").unwrap(),
      "",
    ).origins[0]
  assert_eq(prose.tier, 3)
  let at = position_of(source, "Knuth–Plass style optimizer,")
  assert_eq(prose.source_ranges.map(r => (r.line, r.start, r.end, r.text)), [
    (at.0, at.1, at.1 + 28, "Knuth–Plass style optimizer,"),
  ])
  assert_eq(prose.excerpt.map(line => line.0), [at.0])
  // A word that the engine hyphenates at a line break.
  let broken = text.feedback(text.find("hyphenation follows").unwrap(), "").origins[0]
  assert_eq(broken.source_ranges.map(r => r.text), ["hyphenation follows"])
  // An argument that is a variable.
  let bound = text.feedback(
      text.find("the Typst typesetting engine").unwrap(),
      "",
    ).origins[0]
  assert_eq(bound.tier, 2)
  assert_true(bound.why.has_prefix("the argument is the variable `subtitle`"))
  assert_eq(bound.excerpt.length(), 1)
  assert_true(bound.excerpt[0].1.contains("Text(subtitle"))
  // The page has the excerpts' lines embedded, and the same records.
  let html = report.review_html(sources=@system.sources()).unwrap()
  assert_true(
    html.contains(
      "\"\{at.0}\":\"      $|Typst lays out text with a Knuth–Plass",
    ),
  )
  assert_true(html.contains("\"format\":\"typst.mbt review feedback 2\""))
}

///|
test "positions on the showcase: source lines lead back to the pages" {
  let report = compile_document(@twins.full_showcase)
  let text = report.review_text(sources=@system.sources())
  let source = @utf8.decode(@system.read(bench_file))
  // The middle of a box, looked up in the other direction.
  let origin_of = (region : @doc.Region) => {
    report
    .origin_at(
      region.page,
      region.x + region.width / 2.0,
      region.y + region.height / 2.0,
    )
    .unwrap()
  }
  // A heading: its words, in the outline and in the text.
  let at = position_of(source, "Heading(\"Tables and figures\")")
  let heading = text.positions(bench_file, at.0)
  assert_eq(heading.length(), 6)
  assert_eq(
    heading
    .map(region => origin_of(region).kind)
    .filter(k => k != "Heading")
    .length(),
    0,
  )
  // A line of a prose block: the words that the line spells, not the
  // whole block.
  let at = position_of(source, "$|Typst lays out text with a Knuth–Plass")
  let line = text.positions(bench_file, at.0)
  assert_true(line.length() >= 12 && line.length() <= 16)
  let block = text.origin_positions(origin_of(line[0]))
  assert_true(block.length() > 5 * line.length())
  // A column in that line: one word.
  let at = position_of(source, "Knuth–Plass style")
  let word = text.positions(bench_file, at.0, column=at.1 + 3)
  assert_eq(word.length(), 1)
  assert_eq(origin_of(word[0]).kind, "Prose")
  let feedback = text.feedback(text.find("Knuth–Plass").unwrap(), "")
  assert_eq(feedback.origins[0].source_ranges[0].line, at.0)
  // An argument that is a variable: everything of the argument.
  let at = position_of(source, "stage_cells,")
  let cells = text.positions(bench_file, at.0)
  assert_true(cells.length() > 30)
  for region in cells {
    assert_eq(origin_of(region).kind, "Table")
  }
  // An image: its box.
  let at = position_of(source, "Image(\"glacier.jpg\"")
  let image = text.positions(bench_file, at.0)
  assert_eq(image.length(), 1)
  assert_eq(origin_of(image[0]).kind, "Image")
  assert_true(image[0].width > 100.0 && image[0].height > 100.0)
}

///|
test "the showcase's loop-built rows name their data row" {
  let report = compile_document(@twins.full_showcase)
  let text = report.review_text(sources=@system.sources())
  let source = @utf8.decode(@system.read(bench_file))
  // A click on a cell of the stage table: the argument that holds the
  // cells, under the key of the row.
  let cell = spot(report, "parser, AST, incremental reparse")
  assert_eq((cell.kind, cell.keys), ("Table", ["stage:syntax"]))
  assert_eq(cell.start_line, position_of(source, "stage_cells,").0)
  assert_eq(spot(report, "PNG rasterization").keys, ["stage:render"])
  // The computed table: the cell with 13 is the eighth Fibonacci number.
  assert_eq(spot(report, "13").keys, ["fib:7"])
  // The four cells of a row are four pieces of that origin, and the
  // feedback names the key.
  let row = text.feedback(
    text.find("syntax parser, AST, incremental reparse 3 792 100%").unwrap(),
    "",
  )
  assert_eq(row.origins.length(), 1)
  assert_eq(row.origins[0].pieces, [
    "syntax", "parser, AST, incremental reparse", "3 792", "100%",
  ])
  assert_true(
    row
    .to_text()
    .contains(", Table(..), parameter 1, data key \"stage:syntax\"\n"),
  )
  assert_true(
    row.origins[0].why.has_prefix("the argument is the variable `stage_cells`"),
  )
  // A selection over two rows: two origins, one per key.
  let rows = text.feedback(text.find("100% eval evaluation").unwrap(), "")
  assert_eq(rows.origins.map(o => o.origin.keys), [
    ["stage:syntax"],
    ["stage:eval"],
  ])
  // The line of the argument still leads to all the cells.
  let cells = text.positions(bench_file, cell.start_line)
  assert_true(cells.length() > 30)
  // Content made in a callback, with its source characters: the page
  // header is on every page but the first, from one literal.
  let header = text.feedback(text.find("a MoonBit port of Typst").unwrap(), "").origins[0]
  assert_eq((header.origin.kind, header.tier), ("Emph", 3))
  assert_eq(header.source_ranges.map(r => r.text), ["a MoonBit port of Typst"])
  // Raw text interpolated into prose: its call.
  let raw = text.feedback(text.find("syntect").unwrap(), "").origins[0]
  assert_eq((raw.origin.kind, raw.tier), ("Raw", 1))
  // The entries of the bibliography: its call. A citation: its call.
  let entry = text.feedback(text.find("The Pirate Organization").unwrap(), "").origins[0]
  assert_eq((entry.origin.kind, entry.tier), ("Bibliography", 1))
  assert_eq(
    entry.origin.start_line,
    position_of(source, "Bibliography(\"works.bib\"").0,
  )
  let cited = text.feedback(text.find("[2]").unwrap(), "").origins[0]
  assert_eq((cited.origin.kind, cited.tier), ("Ref", 1))
}
