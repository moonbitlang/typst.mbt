// Tests of the review loop (docs/edsl-review.md): the click search of
// slice 1 (the cases of upstream's `typst-ide/src/jump.rs` that need no
// Typst source), the words, selections and feedback records of slice 2,
// the tiers of slice 3 without a source file, and the preview page. What
// needs source files (and the showcase) is tested in
// `doc/examples/review`.

///|
/// A page like upstream's test page: 120pt wide, 10pt margins.
fn test_page() -> @doc.SetPage {
  @doc.SetPage(width=Pt(120), height=Pt(120), margin=@doc.Sides(all=Pt(10)))
}

///|
/// Compile `children` on the test page.
fn compile_on_page(
  children : Array[&@doc.IntoContent],
) -> @doc.CompileReport[@layout.PagedDocument] {
  let body : Array[&@doc.IntoContent] = [test_page()]
  for child in children {
    body.push(child)
  }
  @doc.Document(body).compile_paged(@doc.DocWorld::in_memory())
}

///|
/// The constructor of what a click at `(x, y)` inside the margins of the
/// first page hits, `-` for nothing. The upstream lookup must agree.
fn hit(
  children : Array[&@doc.IntoContent],
  x : Double,
  y : Double,
) -> String raise {
  let report = compile_on_page(children)
  let kind = match report.origin_at(1, x + 10.0, y + 10.0) {
    Some(origin) => origin.kind
    None => "-"
  }
  let jump = match report.jump_from_click(1, x + 10.0, y + 10.0) {
    Some(Source(origin)) => origin.kind
    Some(_) => "link"
    None => "-"
  }
  assert_eq(jump, kind)
  kind
}

///|
test "click: a filled rectangle, also rotated, scaled and clipped (upstream test_jump_from_click_transform_clip)" {
  let rect = (w : Double, h : Double) => {
    @doc.Rect(width=Pt(w), height=Pt(h), fill=Black)
  }
  inspect(hit([rect(20, 20)], 10, 10), content="Rect")
  inspect(hit([rect(60, 10)], 5, 30), content="-")
  inspect(
    hit(
      [@doc.Rotate(rect(60, 10), angle=Deg(90), origin=Both(Bottom, Left))],
      5,
      30,
    ),
    content="Rect",
  )
  inspect(
    hit(
      [@doc.Scale(rect(10, 10), x=Pct(300), y=Pct(300), origin=Both(Top, Left))],
      20,
      20,
    ),
    content="Rect",
  )
  // The clip of a group is tested before its transform is inverted.
  inspect(
    hit(
      [
        @doc.Box(
          @doc.Scale(
            rect(10, 10),
            x=Pct(300),
            y=Pct(300),
            origin=Both(Top, Left),
          ),
          width=Pt(10),
          height=Pt(10),
          clip=true,
        ),
      ],
      20,
      20,
    ),
    content="-",
  )
  inspect(
    hit(
      [@doc.Box(rect(30, 30), width=Pt(10), height=Pt(10), clip=false)],
      20,
      20,
    ),
    content="Rect",
  )
  inspect(
    hit(
      [@doc.Box(rect(30, 30), width=Pt(10), height=Pt(10), clip=true)],
      20,
      20,
    ),
    content="-",
  )
  // Rotated text.
  inspect(
    hit(
      [@doc.Rotate("hello world", angle=Deg(90), origin=Both(Bottom, Left))],
      5,
      15,
    ),
    content="Rotate",
  )
}

///|
test "click: shapes by fill and by stroke (upstream test_jump_from_click_shapes, _stroke)" {
  let circle : () -> &@doc.IntoContent = () => {
    @doc.Circle(width=Pt(30), height=Pt(30), fill=Black)
  }
  inspect(hit([circle()], 15, 15), content="Circle")
  inspect(hit([circle()], 1, 1), content="-")
  let bowtie : () -> &@doc.IntoContent = () => {
    @doc.Polygon(
      [(Pt(0), Pt(0)), (Pt(20), Pt(20)), (Pt(20), Pt(0)), (Pt(0), Pt(20))],
      fill=Black,
    )
  }
  inspect(hit([bowtie()], 1, 2), content="Polygon")
  inspect(hit([bowtie()], 2, 1), content="-")
  inspect(hit([bowtie()], 19, 10), content="Polygon")
  let evenodd : () -> &@doc.IntoContent = () => {
    @doc.Polygon(
      [
        (Pt(0), Pt(10)),
        (Pt(30), Pt(10)),
        (Pt(30), Pt(20)),
        (Pt(20), Pt(20)),
        (Pt(20), Pt(0)),
        (Pt(10), Pt(0)),
        (Pt(10), Pt(30)),
        (Pt(20), Pt(30)),
        (Pt(20), Pt(20)),
        (Pt(0), Pt(20)),
      ],
      fill=Black,
      fill_rule="even-odd",
    )
  }
  inspect(hit([evenodd()], 15, 15), content="-")
  inspect(hit([evenodd()], 5, 15), content="Polygon")
  inspect(hit([evenodd()], 15, 5), content="Polygon")
  // A stroke without a fill: the inside is not hit, the outline is.
  let outlined : () -> &@doc.IntoContent = () => {
    @doc.Place(
      @doc.Rect(
        width=Pt(10),
        height=Pt(10),
        stroke=@doc.Sides(all=@doc.Stroke(thickness=Pt(5))),
      ),
      dx=Pt(10),
      dy=Pt(10),
    )
  }
  inspect(hit([outlined()], 15, 15), content="-")
  inspect(hit([outlined()], 10, 15), content="Rect")
  inspect(
    hit(
      [
        @doc.Line(
          angle=Deg(45),
          length=Pt(10),
          stroke=@doc.Stroke(thickness=Pt(2)),
        ),
      ],
      2,
      2,
    ),
    content="Line",
  )
  // An open filled path: the point is inside the triangle that the fill
  // paints. Upstream tests the path as it is (kurbo's winding does not
  // close it), so its lookup finds nothing; the origin lookup tests what
  // is painted, like the preview page.
  let open = compile_on_page([
    @doc.Curve(
      [
        @doc.CurveMove((Pt(0), Pt(0))),
        @doc.CurveLine((Pt(10), Pt(0))),
        @doc.CurveLine((Pt(10), Pt(10))),
      ],
      fill=Black,
    ),
  ])
  assert_true(open.jump_from_click(1, 18.0, 12.0) is None)
  guard open.origin_at(1, 18.0, 12.0) is Some(origin) else {
    fail("the painted triangle is not hit")
  }
  inspect(origin.kind, content="Curve")
  assert_true(open.origin_at(1, 12.0, 18.0) is None)
}

///|
test "click: text names its call and argument; a link wins only in the upstream lookup" {
  let report = compile_on_page([
    @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed")])),
    @doc.Link(Url("https://example.org/"), body="linked words"),
    @doc.List(["an item"]),
  ])
  // The first line: the string of the sequence, then the emphasis.
  guard report.origin_at(1, 14.0, 16.0) is Some(plain) else { fail("no text") }
  inspect(plain.kind, content="Seq")
  assert_eq(plain.param, Some(0))
  inspect(plain.file, content="doc/review_test.mbt")
  guard report.origin_at(1, 50.0, 16.0) is Some(stressed) else {
    fail("no emphasis")
  }
  inspect(stressed.kind, content="Emph")
  assert_true(stressed.start_line > plain.start_line - 1)
  // The second line is a link: upstream's lookup gives the URL, the
  // origin lookup the text under it.
  guard report.jump_from_click(1, 20.0, 31.0) is Some(Url(url)) else {
    fail("expected the link's URL")
  }
  inspect(url, content="https://example.org/")
  guard report.origin_at(1, 20.0, 31.0) is Some(linked) else {
    fail("expected the text under the link")
  }
  inspect(linked.kind, content="Link")
  // The marker of the list is generated: nothing with a source is there,
  // but the item beside it has one.
  assert_true(report.origin_at(1, 12.0, 46.0) is None)
  guard report.origin_at(1, 30.0, 46.0) is Some(item) else { fail("no item") }
  inspect(item.kind, content="List")
  // Outside the page, on a page that does not exist, and with
  // coordinates that are no numbers.
  assert_true(report.origin_at(1, 500.0, 500.0) is None)
  assert_true(report.origin_at(7, 20.0, 20.0) is None)
  assert_true(report.origin_at(0, 20.0, 20.0) is None)
  let zero = 0.0
  assert_true(report.origin_at(1, zero / zero, 20.0) is None)
  assert_true(report.jump_from_click(1, 1.0 / zero, 20.0) is None)
}

///|
test "click: what the origin lookup decides differently from upstream, like the page's layer" {
  let rect = () => @doc.Rect(width=Pt(20), height=Pt(20), fill=Black)
  // A scale of zero draws nothing. Upstream's `invert` answers it with a
  // translation, so its lookup still finds the rectangle.
  let flat = compile_on_page([
    @doc.Scale(rect(), x=Pct(0), y=Pct(100), origin=Both(Top, Left)),
  ])
  assert_true(flat.origin_at(1, 20.0, 20.0) is None)
  assert_true(flat.jump_from_click(1, 20.0, 20.0) is Some(Source(_)))
  assert_true(!flat.review_html().unwrap().contains("matrix(1 0 0 1"))
  // Two scales whose product is one: the rectangle is where it was, and
  // the layer keeps the small coefficient.
  let nested = compile_on_page([
    @doc.Scale(
      @doc.Scale(rect(), x=Pct(0.001), y=Pct(0.001), origin=Both(Top, Left)),
      x=Pct(10000000),
      y=Pct(10000000),
      origin=Both(Top, Left),
    ),
  ])
  guard nested.origin_at(1, 20.0, 20.0) is Some(origin) else {
    fail("the rectangle is not hit")
  }
  inspect(origin.kind, content="Rect")
  assert_true(
    nested.review_html().unwrap().contains("matrix(0.00001 0 0 0.00001"),
  )
  // A dashed line counts as a whole line, also in a gap (upstream tests
  // the dashes), however small the dashes are.
  let dashed = compile_on_page([
    @doc.Line(
      length=Pt(60),
      stroke=@doc.Stroke(
        thickness=Pt(4),
        dash=@doc.Value::array([
          @doc.Value::length(Pt(10)),
          @doc.Value::length(Pt(10)),
        ]),
      ),
    ),
  ])
  guard dashed.origin_at(1, 15.0, 10.0) is Some(dash) else { fail("no dash") }
  inspect(dash.kind, content="Line")
  assert_true(dashed.origin_at(1, 25.0, 10.0) is Some(_))
  assert_true(dashed.jump_from_click(1, 15.0, 10.0) is Some(_))
  assert_true(dashed.jump_from_click(1, 25.0, 10.0) is None)
  let dense = compile_on_page([
    @doc.Line(
      length=Pt(60),
      stroke=@doc.Stroke(
        thickness=Pt(4),
        dash=@doc.Value::array([
          @doc.Value::length(Pt(0.000000001)),
          @doc.Value::length(Pt(0.000000001)),
        ]),
      ),
    ),
  ])
  assert_true(dense.review_html().output() is Some(_))
  assert_true(dense.origin_at(1, 25.0, 10.0) is Some(_))
}

///|
test "the layer has the boxes of the glyphs, also when the pen moves back" {
  // Tracking that is wider than the letters: the advance of an `i` is
  // negative, so it has no box and the `W` starts left of the text's
  // position.
  let report = compile_on_page([
    @doc.Text(
      "iiW",
      size=Pt(10),
      tracking=Pt(-4),
      kerning=false,
      ligatures=false,
    ),
  ])
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  assert_eq(glyphs.length(), 3)
  let html = report.review_html().unwrap()
  // One box, for the `W`, which starts before the margin of 10pt.
  let boxes = html.split("<rect data-o=").collect()
  assert_eq(boxes.length(), 2)
  guard boxes[1].find(" x=\"") is Some(at) else { fail("no x") }
  let x = boxes[1][at + 4:].to_owned()
  assert_true(x.has_prefix("7.") || x.has_prefix("8.") || x.has_prefix("9."))
  // The library finds the `W` there as well, and nothing further left.
  assert_true(report.origin_at(1, 9.5, 12.0) is Some(_))
  assert_true(report.origin_at(1, 5.0, 12.0) is None)
}

///|
test "the preview page is self-contained and carries the origin of every piece" {
  let report = compile_on_page([
    @doc.Heading("A <heading> & more"),
    @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed")])),
    @doc.Box(
      @doc.Rect(width=Pt(30), height=Pt(30), fill=Black),
      width=Pt(10),
      height=Pt(10),
      clip=true,
    ),
    @doc.Line(length=Pt(20), stroke=@doc.Stroke(thickness=Pt(2))),
  ])
  let html = report.review_html(title="Test <page>").unwrap()
  assert_true(html.has_prefix("<!doctype html>"))
  assert_true(html.contains("<title>Test &lt;page&gt; review</title>"))
  // The pages are the SVG of the normal export, unchanged.
  for svg in report.svg_pages().unwrap() {
    assert_true(html.contains(svg))
  }
  // The exporter's SVG is inert in the page (its links cannot be
  // followed), and the layer follows it: text boxes, the clipped
  // rectangle and the stroked line.
  assert_true(html.contains("<div class=\"art\" inert><svg"))
  assert_true(html.contains("</svg></div>\n<svg class=\"hit\" data-page=\"1\""))
  assert_true(html.contains("<rect data-o=\"0\" data-i=\"0\""))
  assert_true(html.contains("clip-path=\"url(#rv-clip-0)\""))
  assert_true(html.contains("pointer-events=\"fill\""))
  assert_true(html.contains("pointer-events=\"stroke\" stroke-width=\"2\""))
  // The data: the words in reading order, the library's answers for the
  // self-test, and the table of origins (one entry per call or argument,
  // in the order of first use). Text of the document does not end the
  // data element.
  assert_true(
    html.contains(
      "<script type=\"application/json\" id=\"review-data\">{\"title\":\"Test \\u003cpage>\",\"probes\":[[1,",
    ),
  )
  assert_true(
    html.contains("\"words\":[[1,\"A\",1,0,0],[1,\"\\u003cheading>\",1,0,0],"),
  )
  // Without a source provider no line of a source file is in the page.
  assert_true(html.contains("\"lines\":[]"))
  assert_true(html.contains("\"kind\":\"Heading\",\"range\":["))
  assert_true(
    html.contains(
      ",\"param\":0,\"tier\":2,\"why\":\"the location is the argument as a whole: its source file was not read",
    ),
  )
  assert_true(html.contains("\"samples\":[[0,0,{\"format\":"))
  // The panel takes a comment and gives the record to copy.
  for
    id in ["comment", "copy", "copy-json", "add", "output", "list", "copy-all"] {
    assert_true(html.contains(" id=\"\{id}\""))
  }
  assert_true(html.contains("\"kind\":\"Heading\""))
  assert_true(html.contains("\"kind\":\"Emph\""))
  assert_true(html.contains("\"file\":\"doc/review_test.mbt\""))
  // Nothing is loaded from elsewhere, and nothing the host of a shared
  // page refuses is used.
  for
    forbidden in [
      "http://", "https://", "src=", "<link", "@import", "url(\"", "alert(", "confirm(",
      "prompt(", "print(", "download", "fetch(", "XMLHttpRequest",
    ] {
    // (The exporter's SVG names its XML namespaces, which are no requests.)
    let rest = html.replace_all(old="=\"http://www.w3.org/", new="")
    if rest.contains(forbidden) {
      fail("the page contains `\{forbidden}`")
    }
  }
  // Both themes are defined by tokens.
  assert_true(html.contains("@media (prefers-color-scheme: dark)"))
  assert_true(html.contains(":root[data-theme=\"dark\"]"))
  assert_true(html.contains(":root:not([data-theme=\"light\"])"))
  // The export changes nothing: the same pages afterwards, and a failed
  // compilation has no page.
  assert_true(
    report.svg_pages().unwrap() ==
    compile_on_page([
      @doc.Heading("A <heading> & more"),
      @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed")])),
      @doc.Box(
        @doc.Rect(width=Pt(30), height=Pt(30), fill=Black),
        width=Pt(10),
        height=Pt(10),
        clip=true,
      ),
      @doc.Line(length=Pt(20), stroke=@doc.Stroke(thickness=Pt(2))),
    ])
    .svg_pages()
    .unwrap(),
  )
  // Text of the document cannot end the data: a key with markup in it.
  let hostile = compile_on_page([
    @doc.Par(@doc.Keyed("</script><script>alert(1)</script>\u{2028}", "keyed")),
  ])
  let html = hostile.review_html(title="</title><script>").unwrap()
  assert_eq(html.split("</script>").collect().length(), 3)
  assert_eq(html.split("<script").collect().length(), 3)
  assert_true(html.contains("\\u003c/script>\\u003cscript>alert(1)"))
  assert_true(
    html.contains("<title>&lt;/title&gt;&lt;script&gt; review</title>"),
  )
  let failed = @doc.Document([@doc.Image("missing.png")]).compile_paged(
    @doc.DocWorld::in_memory(),
  )
  assert_true(failed.review_html().output() is None)
  assert_true(failed.origin_at(1, 10.0, 10.0) is None)
}

///|
/// The text of a document compiled on the test page.
fn text_of(children : Array[&@doc.IntoContent]) -> @doc.ReviewText raise {
  compile_on_page(children).review_text(title="Test")
}

///|
/// The origins of a feedback record as `Constructor: rendered [pieces]`.
fn origins_of(feedback : @doc.Feedback) -> String {
  feedback.origins
  .map(o => "\{o.origin.kind}: \{o.rendered} [\{o.pieces.join("/")}]")
  .join(" | ")
}

///|
test "select: words in reading order, and a word of two origins" {
  let text = text_of([
    @doc.Par(@doc.Seq(["alpha beta ", @doc.Emph("gam"), "ma delta"])),
    @doc.Par("second paragraph"),
  ])
  inspect(text.text(), content="alpha beta gamma delta second paragraph")
  assert_eq(text.length(), 7)
  // A written word whose style changes inside it is two words that
  // touch: selected together they read as one, and each has its origin.
  let gamma = text.find("gamma").unwrap()
  inspect(text.selected_text(gamma), content="gamma")
  inspect(
    origins_of(text.feedback(gamma, "")),
    content=(
      #|Emph: gam [gam] | Seq: ma [ma]
    ),
  )
  // The origins of a selection, each once, in reading order. The two
  // strings of the array are two pieces of one argument; the text of
  // another origin between them is a gap.
  let more = text.find("beta gamma   delta").unwrap()
  inspect(text.selected_text(more), content="beta gamma delta")
  let feedback = text.feedback(more, "shorter")
  inspect(
    origins_of(feedback),
    content=(
      #|Seq: beta … ma delta [beta/ma delta] | Emph: gam [gam]
    ),
  )
  assert_eq(feedback.origins[0].origin.param, Some(0))
  assert_eq(feedback.pages, [1])
  // A part of a word selects the word; the occurrences are counted.
  inspect(text.selected_text(text.find("econ").unwrap()), content="second")
  inspect(text.selected_text(text.find("a", nth=2).unwrap()), content="beta")
  assert_true(text.find("delta alpha") is None)
  assert_true(text.find("") is None)
  assert_true(text.find("   ") is None)
  assert_true(text.find("alpha", nth=1) is None)
  // Ranges of words, in either order.
  inspect(
    text.selected_text(text.range(5, 1).unwrap()),
    content="beta gamma delta second",
  )
  assert_true(text.range(0, 7) is None)
  assert_true(text.range(-1, 2) is None)
  // A document without text.
  let empty = text_of([@doc.Rect(width=Pt(20), height=Pt(20), fill=Black)])
  assert_eq(empty.length(), 0)
  inspect(empty.text(), content="")
  assert_true(empty.find("a") is None)
}

///|
test "select: the runs of a prose and the strings of an array are pieces of one origin" {
  let text = text_of([
    @doc.Prose("One two \{@doc.Emph("three")} four, \"five\"."),
    @doc.List(["first item", "second item"]),
    @doc.Par(@doc.Keyed("row 7", "keyed words")),
  ])
  // The marker of the list has no source: it is no word.
  inspect(
    text.text(),
    content="One two three four, “five”. first item second item keyed words",
  )
  let prose = text.feedback(text.find("One two three four").unwrap(), "")
  inspect(
    origins_of(prose),
    content=(
      #|Prose: One two … four, [One/two/four,] | Emph: three [three]
    ),
  )
  // Each string of the array is one piece, whatever is selected of it.
  let list = text.feedback(text.find("item second").unwrap(), "")
  inspect(
    origins_of(list),
    content=(
      #|List: item second [item/second]
    ),
  )
  let whole = text.feedback(text.find("first item").unwrap(), "")
  inspect(
    origins_of(whole),
    content=(
      #|List: first item [first item]
    ),
  )
  // The data key of a `Keyed` wrapper is part of the origin.
  let keyed = text.feedback(text.find("keyed").unwrap(), "")
  assert_eq(keyed.origins[0].origin.keys, ["row 7"])
  assert_true(
    keyed.to_text().contains(", Par(..), parameter 1, data key \"row 7\"\n"),
  )
}

///|
test "feedback: the text block and the JSON record" {
  let report = compile_on_page([
    @doc.Heading("The \"title\""),
    @doc.Prose("Some words of prose."),
    @doc.Rect(width=Pt(20), height=Pt(20), fill=Black),
  ])
  let text = report.review_text(title="Test")
  let feedback = text.feedback(
    text.find("title\" Some words").unwrap(),
    "Too vague.",
  )
  let line = feedback.origins[0].origin.start_line
  inspect(
    feedback
    .to_text()
    .replace_all(old="\{line + 1}:", new="M:")
    .replace_all(old="\{line}:", new="L:"),
    content=(
      #|Review comment on "Test" (a document rendered from MoonBit source by typst.mbt)
      #|Comment: Too vague.
      #|Selected text: "\"title\" Some words" (page 1)
      #|Source 1 of 2: doc/review_test.mbt:L:18-L:33, Heading(..), parameter 1
      #|  rendered: "\"title\""
      #|  note: the location is the argument as a whole: its source file was not read when this was made
      #|Source 2 of 2: doc/review_test.mbt:M:16-M:38, Prose(..), parameter 1
      #|  rendered: "Some words"
      #|  2 pieces of this argument are selected; they share this location, which is the argument as a whole.
      #|  note: the location is the argument as a whole: its source file was not read when this was made
      #|Locations are constructor calls and their arguments in the MoonBit source (line:column, columns in code points). Source characters are given only where the literal at a location is the text on the page.
      #|
    ),
  )
  let json = feedback.to_json().stringify()
  assert_true(
    json.has_prefix(
      "{\"format\":\"typst.mbt review feedback 2\",\"document\":\"Test\",\"comment\":\"Too vague.\",\"selected_text\":\"\\\"title\\\" Some words\",\"pages\":[1],\"origins\":[{\"file\":\"doc/review_test.mbt\",\"module\":\"moonbitlang/typst\",\"constructor\":\"Heading\",\"parameter\":1,\"start\":[\{line},18],\"end\":[\{line},33],\"rendered_text\":\"\\\"title\\\"\",\"pieces\":[\"\\\"title\\\"\"],\"tier\":2,\"why\":\"the location is the argument as a whole: its source file was not read when this was made\",\"source_ranges\":[],\"excerpt\":[]},",
    ),
  )
  assert_true(
    json.contains(
      "\"rendered_text\":\"Some words\",\"pieces\":[\"Some\",\"words\"],\"tier\":2,",
    ),
  )
  // A shape: its origin from a click, without text.
  guard report.origin_at(1, 20.0, 60.0) is Some(origin) else {
    fail("the rectangle is not hit")
  }
  let shape = text.origin_feedback(origin, 1, "")
  assert_eq(shape.selected_text, "")
  let block = shape.to_text()
  assert_true(
    block.contains("Comment: (none)\nSelected: a shape or an image (page 1)\n"),
  )
  assert_true(
    block.contains(
      ", Rect(..)\n  note: the location is the constructor call: what was selected is not the text of one of its arguments\n",
    ),
  )
  assert_true(!block.contains("rendered:"))
  assert_true(
    shape
    .to_json()
    .stringify()
    .contains("\"rendered_text\":\"\",\"pieces\":[],\"tier\":1,"),
  )
  // An origin of another document is not in this text's table.
  let other = compile_on_page([@doc.Par("elsewhere")])
  let foreign = text.origin_feedback(
    other.origin_at(1, 14.0, 16.0).unwrap(),
    1,
    "",
  )
  assert_eq(foreign.origins[0].tier, 2)
  assert_true(foreign.origins[0].excerpt.is_empty())
  // A long selection is shortened in the text, not in the record.
  let long = text_of([@doc.Par("word ".repeat(100))])
  let all = long.feedback(long.range(0, 99).unwrap(), "")
  assert_eq(all.selected_text.length(), 499)
  assert_true(all.to_text().contains("word word …\" (pages 1, 2"))
  // A failed compilation has no text.
  let failed = @doc.Document([@doc.Image("missing.png")]).compile_paged(
    @doc.DocWorld::in_memory(),
  )
  try failed.review_text() catch {
    _ => ()
  } noraise {
    _ => fail("a failed compilation has a text")
  }
}

///|
test "select: a word that is hyphenated at a line break is read as one" {
  let written = "an extraordinarily incomprehensible internationalization"
  let text = text_of([@doc.SetText(hyphenate=true), @doc.Par(written)])
  // The word is in two text items with the engine's hyphen between them:
  // two words that touch, and no hyphen in the text.
  assert_true(text.length() > 4)
  inspect(text.text(), content=written)
  let word = text.find("incomprehensible").unwrap()
  inspect(text.selected_text(word), content="incomprehensible")
  // The engine's hyphen is no word of the page's data either.
  let html = compile_on_page([@doc.SetText(hyphenate=true), @doc.Par(written)])
    .review_html()
    .unwrap()
  assert_true(!html.contains("\u{ad}"))
}

///|
test "select: what is one text on the page is one text in the words" {
  // Any white space of Unicode separates words (a thin space, a no-break
  // space), and stands for a space in the text.
  let spaced = text_of([@doc.Par("alpha\u{2009}beta\u{a0}gamma")])
  assert_eq(spaced.length(), 3)
  inspect(spaced.text(), content="alpha beta gamma")
  assert_true(spaced.find("alpha beta") is Some(_))
  // A box in a line is a group of its own: the text goes on through it.
  let boxed = text_of([@doc.Par(@doc.Seq(["a", @doc.Box("b"), "c d"]))])
  inspect(boxed.text(), content="abc d")
  inspect(
    origins_of(boxed.feedback(boxed.find("abc").unwrap(), "")),
    content="Seq: a … c [a/c] | Box: b [b]",
  )
  // Text in a group that draws nothing (a scale of zero) is no text of
  // the page.
  let scaled = text_of([
    @doc.Par(
      @doc.Seq(["before ", @doc.Scale("hidden", x=Pct(0), y=Pct(100)), " after"]),
    ),
  ])
  inspect(scaled.text(), content="before after")
  // Many occurrences of a long needle's start: the search is linear.
  let repeated = text_of([@doc.Par("ab ".repeat(300) + "ac")])
  let needle = "ab ".repeat(200) + "ac"
  guard repeated.find(needle) is Some(found) else { fail("not found") }
  inspect(repeated.selected_text(found).length(), content="602")
  assert_true(repeated.find("ab ".repeat(301)) is None)
}

///|
test "select: beyond 65,535 bytes of a text item the words keep their origins" {
  // Two strings in one line: one text item of 80,000 bytes. Glyph ranges
  // are stored in 16 bits, so the end of the second string has no known
  // text; its glyphs still have their span.
  let report = @doc.Document([
    @doc.SetPage(width=Pt(50000), height=Pt(40), margin=@doc.Sides(all=Pt(5))),
    @doc.SetText(size=Pt(1), hyphenate=false),
    @doc.Par(
      @doc.Seq([
        @doc.Keyed("A", "a".repeat(40000)),
        @doc.Keyed("B", "b".repeat(40000)),
      ]),
    ),
  ]).compile_paged(@doc.DocWorld::in_memory())
  let text = report.review_text()
  assert_eq(text.length(), 3)
  let all = text.feedback(text.range(0, 2).unwrap(), "")
  assert_eq(all.origins.map(o => o.origin.keys), [["A"], ["B"]])
  assert_eq(all.origins[0].rendered.length(), 40000)
  // The known part of the second string touches the first; the rest is a
  // word without a known text.
  assert_eq(all.origins[1].pieces.length(), 1)
  assert_true(all.origins[1].rendered.has_prefix("bbbb"))
  assert_true(all.origins[1].rendered.has_suffix("b …"))
  assert_eq(all.origins[1].rendered.length(), 65535 - 40000 + 2)
  assert_eq(
    text.feedback(text.range(2, 2).unwrap(), "").origins[0].origin.keys,
    ["B"],
  )
}

///|
test "source: a provider's text gives excerpts and, for a literal that is the text, source characters" {
  let report = compile_on_page([@doc.Par("plain words here")])
  // The source file as the provider gives it: empty but for the line of
  // the argument, which has the literal where the origin says it is.
  let origin = report.origin_at(1, 14.0, 16.0).unwrap()
  let line = " ".repeat(origin.start_column - 1) + "\"plain words here\"),"
  let file = "\n".repeat(origin.start_line - 1) + line + "\nafter\n"
  let asked : Array[String] = []
  let sources = (name : String, module_name : String) => {
    asked.push("\{name} \{module_name}")
    if name == "doc/review_test.mbt" {
      Some(file)
    } else {
      None
    }
  }
  let text = report.review_text(sources~)
  // (Lines can end with a carriage return.)
  let text_crlf = report.review_text(sources=(_, _) => {
    Some(file.replace_all(old="\n", new="\r\n"))
  })
  assert_eq(
    text_crlf.feedback(text_crlf.find("words").unwrap(), "").origins[0].excerpt,
    [(origin.start_line, line)],
  )
  // The file is asked for once.
  assert_eq(asked, ["doc/review_test.mbt moonbitlang/typst"])
  let feedback = text.feedback(text.find("words here").unwrap(), "")
  let entry = feedback.origins[0]
  assert_eq(entry.tier, 3)
  assert_eq(entry.why, "")
  assert_eq(entry.source_ranges.length(), 1)
  assert_eq(entry.source_ranges[0].line, origin.start_line)
  assert_eq(entry.source_ranges[0].start, origin.start_column + 7)
  assert_eq(entry.source_ranges[0].end, origin.start_column + 17)
  assert_eq(entry.source_ranges[0].text, "words here")
  assert_eq(entry.excerpt, [(origin.start_line, line)])
  assert_eq(entry.more, 0)
  let block = feedback.to_text()
  let l = origin.start_line
  assert_true(
    block.contains(
      "  rendered: \"words here\"\n  source characters: \{l}:\{origin.start_column + 7}-\{l}:\{origin.start_column + 17}\n",
    ),
  )
  assert_true(
    block.contains(
      " | \{line}\n       | \{" ".repeat(origin.start_column + 6)}^^^^^^^^^^\n",
    ),
  )
  // The page has the line, the tier and the runs of the words.
  let html = report.review_html(sources~).unwrap()
  assert_true(html.contains("\"tier\":3,\"source\":0}"))
  assert_true(
    html.contains(
      "\"lines\":[{\"\{l}\":\"\{" ".repeat(origin.start_column - 1)}\\\"plain words here\\\"),\"}]",
    ),
  )
  assert_true(
    html.contains(
      "[1,\"plain\",1,0,0,[[\{l},\{origin.start_column + 1},\{origin.start_column + 6},0,5]]]",
    ),
  )
  // A file whose text at the location is something else: the argument.
  let wrong = report.review_text(sources=(_, _) => {
    Some(
      "\n".repeat(origin.start_line - 1) +
      " ".repeat(origin.start_column - 1) +
      "\"other words here\"),",
    )
  })
  let entry = wrong.feedback(wrong.find("words").unwrap(), "").origins[0]
  assert_eq(entry.tier, 2)
  assert_true(entry.source_ranges.is_empty())
  assert_true(entry.why.contains("is not the text on the page"))
  assert_eq(entry.excerpt.length(), 1)
  // A literal of which only a part is on the page.
  let partly = report.review_text(sources=(_, _) => {
    Some(
      "\n".repeat(origin.start_line - 1) +
      " ".repeat(origin.start_column - 1) +
      "\"plain words here plain\"),",
    )
  })
  assert_eq(
    partly.feedback(partly.find("words").unwrap(), "").origins[0].tier,
    2,
  )
  // A file that is too short for the location: no excerpt, no lines that
  // would be left out, no panic.
  let short = report.review_text(sources=(_, _) => Some("one line"))
  let entry = short.feedback(short.find("words").unwrap(), "").origins[0]
  assert_eq(entry.tier, 2)
  assert_true(entry.excerpt.is_empty())
  assert_eq(entry.more, 0)
  assert_true(entry.why.contains("does not have this location"))
  // A tab in the source line is a tab in the line of marks.
  let tabbed = report.review_text(sources=(_, _) => {
    Some(
      "\n".repeat(origin.start_line - 1) +
      "\t" +
      " ".repeat(origin.start_column - 2) +
      "\"plain words here\"),",
    )
  })
  assert_true(
    tabbed
    .feedback(tabbed.find("plain").unwrap(), "")
    .to_text()
    .contains("\n       | \t\{" ".repeat(origin.start_column - 1)}^^^^^\n"),
  )
}

///|
/// A region as `page: x y width height`, rounded to tenths of a point.
fn region_text(region : @doc.Region) -> String {
  let tenth = (x : Double) => (x * 10.0).round() / 10.0
  "\{region.page}: \{tenth(region.x)} \{tenth(region.y)} \{tenth(region.width)} \{tenth(region.height)}"
}

///|
test "positions: where on the pages is what a source line produced" {
  let report = compile_on_page([
    @doc.Rect(width=Pt(20), height=Pt(10), fill=Black),
    @doc.Scale(
      @doc.Rect(width=Pt(10), height=Pt(10), fill=Black),
      x=Pct(300),
      y=Pct(200),
      origin=Both(Top, Left),
    ),
    @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed")])),
    @doc.Par("alone"),
  ])
  let text = report.review_text()
  let file = "doc/review_test.mbt"
  let line_of = (x : Double, y : Double) => {
    report.origin_at(1, x, y).unwrap().start_line
  }
  // A shape: its box on the page. (The page has margins of 10pt.)
  let rect = line_of(15.0, 15.0)
  inspect(
    text.positions(file, rect).map(region_text).join(" | "),
    content="1: 10 10 20 10",
  )
  // A shape in a group with a transform: the box of what is drawn (10pt
  // by 10pt, scaled by 3 and 2, below the first shape and the spacing).
  let scaled = rect + 2
  inspect(
    text.positions(file, scaled).map(region_text).join(" | "),
    content="1: 10 33.2 30 20",
  )
  // The other direction agrees: the middle of every box of a line is
  // something whose location has that line.
  for line in rect..<(rect + 12) {
    for region in text.positions(file, line) {
      let found = report
        .origin_at(
          region.page,
          region.x + region.width / 2.0,
          region.y + region.height / 2.0,
        )
        .unwrap()
      assert_true(found.start_line <= line && line <= found.end_line)
    }
  }
  // Text whose source was not read is found by its location. Where a
  // call is inside an argument on the same line, the line gives the
  // narrower of the two: the emphasis, not the strings around it.
  let seq = rect + 7
  assert_eq(text.positions(file, seq).length(), 1)
  let emphasis = text.positions(file, seq)[0]
  let stressed = report
    .origin_at(1, emphasis.x + 2.0, emphasis.y + emphasis.height / 2.0)
    .unwrap()
  assert_eq(stressed.kind, "Emph")
  inspect(
    text.positions(file, seq).map(region_text) ==
    text.origin_positions(stressed).map(region_text),
    content="true",
  )
  // With a column: what is at that position. The string of the sequence
  // is its array argument, around the emphasis.
  let plain = report
    .origin_at(1, 12.0, emphasis.y + emphasis.height / 2.0)
    .unwrap()
  assert_eq(plain.kind, "Seq")
  assert_eq(
    text.positions(file, seq, column=plain.start_column + 1).length(),
    text.origin_positions(plain).length(),
  )
  assert_true(text.origin_positions(plain).length() >= 1)
  assert_eq(text.positions(file, seq, column=stressed.start_column).length(), 1)
  // A line of its own.
  assert_eq(text.positions(file, seq + 1).length(), 1)
  // The end of a location is exclusive: the column behind the emphasis'
  // argument is the array around it again.
  assert_eq(
    text.positions(file, seq, column=stressed.end_column - 1).length(),
    1,
  )
  assert_eq(
    text.positions(file, seq, column=stressed.end_column).length(),
    text.origin_positions(plain).length(),
  )
  // Nothing: another file, a line without a location, a column outside.
  assert_true(text.positions("other.mbt", rect).is_empty())
  assert_true(text.positions(file, 1).is_empty())
  assert_true(text.positions(file, rect, column=1).is_empty())
  // An origin of another document has no positions here.
  let other = compile_on_page([@doc.Par("elsewhere, later")])
  assert_true(
    text.origin_positions(other.origin_at(1, 14.0, 16.0).unwrap()).is_empty(),
  )
  // The page has the form to find a line, and the library's answers for
  // its self-test.
  let html = report.review_html().unwrap()
  assert_true(html.contains("<form id=\"find\""))
  assert_true(
    html.contains("\"finds\":[[\"doc/review_test.mbt\",\{rect},[],[0]]"),
  )
}

///|
/// A square from one call site (`positions` test below).
fn keyed_square(key : String) -> @doc.Keyed {
  @doc.Keyed(key, @doc.Rect(width=Pt(6), height=Pt(6), fill=Black))
}

///|
test "positions: one location under many keys, and the reach of a stroke" {
  // Each key is an origin of its own with the same location: a line gives
  // all of them, one box each.
  let squares : Array[&@doc.IntoContent] = []
  for i in 0..<40 {
    squares.push(keyed_square("row \{i}"))
  }
  let report = compile_on_page(squares)
  let text = report.review_text()
  let origin = report.origin_at(1, 12.0, 12.0).unwrap()
  assert_eq(origin.keys, ["row 0"])
  let all = text.positions("doc/review_test.mbt", origin.start_line)
  assert_eq(all.length(), 40)
  assert_eq(text.origin_positions(origin).length(), 1)
  // A line with square caps reaches beyond its end points by half its
  // thickness in both directions: the box has room for that.
  let line = compile_on_page([
    @doc.Line(
      end_=(Pt(20), Pt(20)),
      stroke=@doc.Stroke(thickness=Pt(2), cap="square"),
    ),
  ])
  let text = line.review_text()
  let origin = line.origin_at(1, 20.0, 20.0).unwrap()
  let box = text.origin_positions(origin)[0]
  assert_true(box.x <= 10.0 - 1.4142 && box.y <= 10.0 - 1.4142)
  assert_true(box.x + box.width >= 30.0 + 1.4142)
  // (And for a pointed join up to the miter limit, here 4: not more.)
  assert_true(box.width <= 28.01)
}
