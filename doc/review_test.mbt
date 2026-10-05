// Tests of click to source (docs/edsl-review.md, slice 1): the click
// search (the cases of upstream's `typst-ide/src/jump.rs` that need no
// Typst source) and the preview page. The showcase is tested in
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
  assert_true(html.contains("<rect data-o=\"0\""))
  assert_true(html.contains("clip-path=\"url(#rv-clip-0)\""))
  assert_true(html.contains("pointer-events=\"fill\""))
  assert_true(html.contains("pointer-events=\"stroke\" stroke-width=\"2\""))
  // The table of origins: one entry per call or argument, in the order of
  // first use; text of the document does not end the data element.
  assert_true(
    html.contains("<script type=\"application/json\" id=\"review-origins\">[{"),
  )
  assert_true(
    html.contains("<script type=\"application/json\" id=\"review-probes\">[[1,"),
  )
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
  assert_eq(html.split("</script>").collect().length(), 4)
  assert_eq(html.split("<script").collect().length(), 4)
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
