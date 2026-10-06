// The lints that read the pages (docs/edsl-ports.md, section 6;
// `lint_frames.mbt`): L2, missing glyphs, and L3, content outside the page
// or outside a container of a fixed size. The findings that they answer
// (S4, S2b) are pinned in `ports_findings_test.mbt`. The page of most
// tests is `small_page`: 200pt by 120pt with 10pt margins and 10pt text.

///|
/// The lints of the pages of a report, one line each: the kind, the place
/// (the constructor and its argument; `(nowhere)` without one), the page
/// and the message.
fn page_lints(report : @doc.CompileReport[@layout.PagedDocument]) -> String {
  report.lints
  .filter(lint => lint.page is Some(_))
  .map(lint => {
    let place = match lint.location {
      Some(Edsl(origin)) => what(origin)
      Some(File(_)) => "(a file)"
      None => "(nowhere)"
    }
    "\{lint.kind.name()} \{place} p\{lint.page.unwrap()}: \{lint.message}"
  })
  .join("\n")
}

///|
/// `page_lints` of a document of `children` on the small page.
fn lints_on_page(children : Array[&@doc.IntoContent]) -> String {
  page_lints(compile([..small_page(), ..children]))
}

// L2: missing glyphs.

///|
test "lint L2: a character that no font has, at the call that has it" {
  // The case of the ports: an emoji in a card, with the embedded fonts.
  let report = compile(
    [
      ..small_page(),
      @doc.Block(
        "Shipped \u{1F680} today",
        fill=Luma(230),
        inset=@doc.Sides(all=Pt(4)),
      ),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(
    page_lints(report),
    content=(
      #|missing-glyph (Block, argument 1) p1: no font has a glyph for "🚀" (U+1F680): it is drawn as the missing glyph of Libertinus Serif
    ),
  )
  // As text: the location is the argument that has the character, the
  // page is the first that has the glyph, the hint names the remedy.
  let lint = report.lints[0]
  assert_true(lint.kind == MissingGlyph)
  inspect(lint.kind.name(), content="missing-glyph")
  inspect(
    rendered(lint),
    content=(
      #|lint[missing-glyph]: no font has a glyph for "🚀" (U+1F680): it is drawn as the missing glyph of Libertinus Serif
      #|  at LINE (Block, argument 1)
      #|  on page 1
      #|  hint: use a font that has it: name its family in the `font` of `SetText` or `Text`; a font that is not embedded comes from `font_paths` or from the system's fonts (docs/edsl-guide.md, section 5)
    ),
  )
  // The place is where the review loop finds the glyph on the page.
  guard lint.location is Some(Edsl(origin)) else { fail("no origin") }
  assert_true(report.review_text().origin_positions(origin).length() >= 1)
}

///|
/// `Lint::render` without the places of this file (`LINE` for each
/// `file:line:column`), which move when the file is edited.
fn rendered(lint : @doc.Lint) -> String {
  let mut text = lint.render()
  for place in [lint.location, ..lint.hints.map(hint => hint.location)] {
    if place is Some(Edsl(origin)) {
      text = text.replace_all(old=origin.position(), new="LINE")
    }
  }
  text
}

///|
test "lint L2: the origin is the glyph's, the text the cluster's" {
  // One text item with glyphs of two calls: each glyph has its own span.
  inspect(
    lints_on_page([
      @doc.Par(@doc.Seq(["one \u{4e2d} ", @doc.Text("two \u{6587}")])),
    ]),
    content=(
      #|missing-glyph (Seq, argument 1) p1: no font has a glyph for "中" (U+4E2D): it is drawn as the missing glyph of Libertinus Serif
      #|missing-glyph (Text, argument 1) p1: no font has a glyph for "文" (U+6587): it is drawn as the missing glyph of Libertinus Serif
    ),
  )
  // Every character of a run that no font has is one glyph of the font's
  // missing glyph: also a joiner and a variation selector in it, which
  // are named by their code points. (Next to a character that a font has
  // they are ignored: see below.)
  inspect(
    lints_on_page(["a \u{1F468}\u{200D}\u{1F469}\u{FE0F} b"]),
    content=(
      #|missing-glyph (Document, argument 1) p1: no font has a glyph for "👨" (U+1F468): it is drawn as the missing glyph of Libertinus Serif
      #|missing-glyph (Document, argument 1) p1: no font has a glyph for U+200D: it is drawn as the missing glyph of Libertinus Serif
      #|missing-glyph (Document, argument 1) p1: no font has a glyph for "👩" (U+1F469): it is drawn as the missing glyph of Libertinus Serif
      #|missing-glyph (Document, argument 1) p1: no font has a glyph for U+FE0F: it is drawn as the missing glyph of Libertinus Serif
    ),
  )
  // In a formula: the location is in the source string.
  let formula = compile([..small_page(), @doc.Equation("x + \u{4e2d}")])
  inspect(
    page_lints(formula),
    content=(
      #|missing-glyph (Equation, bytes 4..7 of the source string) p1: no font has a glyph for "中" (U+4E2D): it is drawn as the missing glyph of New Computer Modern Math
    ),
  )
  guard formula.lints[0].location is Some(Edsl(origin)) else {
    fail("no origin")
  }
  assert_eq(origin.text_range, Some((4, 7)))
  // With `fallback=false` the first font of the list sets it.
  inspect(
    lints_on_page([@doc.Text("a\u{4e2d}b", fallback=false)]),
    content=(
      #|missing-glyph (Text, argument 1) p1: no font has a glyph for "中" (U+4E2D): it is drawn as the missing glyph of Libertinus Serif
    ),
  )
  // A family that the world does not have is the engine's warning; the
  // missing glyph is the lint.
  let family = compile(
    [..small_page(), @doc.Text("a\u{4e2d}b", font=["No Such Family"])],
  )
  inspect(
    warning_messages(family),
    content=(
      #|unknown font family: no such family
    ),
  )
  inspect(
    page_lints(family),
    content=(
      #|missing-glyph (Text, argument 1) p1: no font has a glyph for "中" (U+4E2D): it is drawn as the missing glyph of Libertinus Serif
    ),
  )
}

///|
test "lint L2: what is not a missing glyph" {
  // Characters that are ignored by default (a soft hyphen, joiners, a
  // zero width space, a word joiner, a byte order mark, variation
  // selectors) have no glyph in the frames at all, and a tab, a line
  // break and a no-break space are spaces or breaks.
  inspect(
    lints_on_page([
      "a\u{ad}b a\u{200d}b a\u{200c}b a\u{200b}b a\u{2060}b a\u{feff}b a\u{fe0e}b a\u{fe0f}b",
      @doc.Parbreak(),
      "a\tb a\u{a0}b a\u{2028}b a\u{85}b",
      @doc.Raw("a\tb\nc", block=true),
    ]),
    content="",
  )
  // A control character that no font has is a missing glyph like any
  // other: the page shows the box. It is named by its code point.
  inspect(
    lints_on_page(["a\u{1}b"]),
    content=(
      #|missing-glyph (Document, argument 1) p1: no font has a glyph for U+0001: it is drawn as the missing glyph of Libertinus Serif
    ),
  )
  // Text that every font covers, in the three embedded families.
  inspect(
    lints_on_page([
      "Plain, ",
      @doc.Strong("strong"),
      @doc.Emph(" emphasis"),
      @doc.Raw(" raw"),
      @doc.Equation("sum_(i=1)^n i = (n(n+1))/2"),
    ]),
    content="",
  )
}

///|
test "lint L2: one lint per call site and character, with a count" {
  // A table of 100 rows that a function builds, each with the same
  // missing character, under keys.
  let row = (i : Int) => {
    @doc.Keyed("row \{i}", @doc.Text("\u{1F600} done \{i} \u{1F600}"))
  }
  let cells : Array[&@doc.IntoContent] = []
  for i in 0..<100 {
    cells.push(row(i))
  }
  let report = compile([
    @doc.SetPage(width=Pt(200), height=Pt(120), margin=@doc.Sides(all=Pt(10))),
    @doc.SetText(size=Pt(10)),
    @doc.Table(cells),
  ])
  inspect(
    page_lints(report),
    content=(
      #|missing-glyph (Text, argument 1, key "row 0") p1: no font has a glyph for "😀" (U+1F600): it is drawn as the missing glyph of Libertinus Serif, 200 times
    ),
  )
  // The same character at two call sites is two lints, and one call site
  // that is laid out on several pages is one, with its first page.
  inspect(
    lints_on_page([
      "first \u{4e2d}",
      @doc.Pagebreak(),
      @doc.Text("second \u{4e2d}"),
    ]),
    content=(
      #|missing-glyph (Document, argument 1) p1: no font has a glyph for "中" (U+4E2D): it is drawn as the missing glyph of Libertinus Serif
      #|missing-glyph (Text, argument 1) p2: no font has a glyph for "中" (U+4E2D): it is drawn as the missing glyph of Libertinus Serif
    ),
  )
}

///|
test "lint L2: beyond 65,535 bytes of an item the character is not known" {
  // The ranges of glyphs are 16-bit offsets into the text of their item:
  // in one line of more than 65,535 bytes they all end there, and the
  // lint has the item's text instead.
  let long = "abcdefghij".repeat(6600) + "\u{1F600}"
  let report = compile([
    @doc.SetPage(width=Auto, height=Pt(120), margin=@doc.Sides(all=Pt(10))),
    @doc.SetText(size=Pt(10)),
    @doc.Text(long),
  ])
  inspect(error_messages(report), content="")
  inspect(
    page_lints(report),
    content=(
      #|missing-glyph (Text, argument 1) p1: no font has a glyph for a character of "abcdefghijabcdef…" (a text of more than 65,535 bytes: the page does not say which): it is drawn as the missing glyph of Libertinus Serif
    ),
  )
}

///|
test "lint L2: in a world without fonts there is no text to look at" {
  // Nothing is shaped: the page has no text, so there is nothing to find,
  // and the engine has a warning only for a family that is named.
  let fontless = @doc.DocWorld::in_memory(embedded_fonts=false)
  let report = @doc.Document([..small_page(), "ab\u{4e2d}cd"]).compile_paged(
    fontless,
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  assert_eq(report.review_text().length(), 0)
  inspect(page_lints(report), content="")
  let named = @doc.Document(
    [..small_page(), @doc.Text("ab\u{4e2d}cd", font=["Libertinus Serif"])],
  ).compile_paged(fontless)
  inspect(
    warning_messages(named),
    content=(
      #|unknown font family: libertinus serif
    ),
  )
  assert_eq(named.review_text().length(), 0)
  inspect(page_lints(named), content="")
}

// L3: content outside the page.

///|
/// A filled rectangle of `w` by `h`.
fn slab(w : Double, h : Double) -> @doc.Rect {
  @doc.Rect(width=Pt(w), height=Pt(h), fill=Luma(120))
}

///|
test "lint L3: text, a shape and an image that leave the page" {
  // A word that cannot break is wider than the page: its glyphs beyond
  // the edge are found, at the argument that has the word.
  let report = compile(
    [
      ..small_page(),
      @doc.Para("a_long_identifier_without_a_break_that_does_not_fit_the_page"),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(
    page_lints(report),
    content=(
      #|outside-page (Para, argument 1) p1: text leaves the page at the right by 72pt
    ),
  )
  let lint = report.lints[0]
  assert_true(lint.kind == OutsidePage)
  inspect(lint.kind.name(), content="outside-page")
  inspect(
    rendered(lint),
    content=(
      #|lint[outside-page]: text leaves the page at the right by 72pt
      #|  at LINE (Para, argument 1)
      #|  on page 1
      #|  hint: what is outside the page is cut off: look for a width, a height or an offset that puts it there, a block that cannot break and is higher than the page, a word or a row that is wider
    ),
  )
  // A shape that is placed past the right and the bottom edge: the side
  // of the larger amount is named.
  inspect(
    lints_on_page([@doc.Place(slab(40, 20), dx=Pt(170), dy=Pt(95))]),
    content=(
      #|outside-page (Rect) p1: a shape leaves the page at the right by 20pt
    ),
  )
  // The stroke counts: a line of 4pt along the edge has 2pt outside, a
  // line of 1pt half a point, which is inside the tolerance of 1pt.
  let edge = (thickness : Double) => {
    lints_on_page([
      @doc.Place(
        @doc.Line(
          start=(Pt(0), Pt(0)),
          end_=(Pt(0), Pt(50)),
          stroke=@doc.Stroke(thickness=Pt(thickness)),
        ),
        dx=Pt(-10),
      ),
    ])
  }
  inspect(
    edge(4),
    content=(
      #|outside-page (Line) p1: a shape leaves the page at the left by 2pt
    ),
  )
  inspect(edge(1), content="")
  // An image.
  let files : Map[String, Bytes] = Map([])
  files["dot.svg"] = @utf8.encode(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"40\"><rect width=\"40\" height=\"40\"/></svg>",
  )
  let image = compile(
    [
      ..small_page(),
      @doc.Place(@doc.Image("dot.svg", width=Pt(40)), dx=Pt(-25)),
    ],
    files~,
  )
  inspect(error_messages(image), content="")
  inspect(
    page_lints(image),
    content=(
      #|outside-page (Image) p1: an image leaves the page at the left by 15pt
    ),
  )
  // A block that cannot break and is higher than the page.
  inspect(
    lints_on_page([
      @doc.Block(@doc.Seq([@doc.V(Pt(130)), "below the page"]), breakable=false),
    ]),
    content=(
      #|outside-page (Seq, argument 1) p1: text leaves the page at the bottom by 29pt
    ),
  )
}

///|
test "lint L3: the margin is the page, and so is the bleed" {
  // In the margin: a header, a footer with the page number, a footnote,
  // and what is placed there.
  inspect(
    page_lints(
      compile([
        @doc.SetPage(
          width=Pt(200),
          height=Pt(140),
          margin=@doc.Sides(all=Pt(24)),
          numbering=@doc.Numbering("1 / 1"),
          header="A running head",
        ),
        @doc.SetText(size=Pt(10)),
        @doc.Para("Text \{@doc.Footnote("A note at the foot.")} goes on."),
        @doc.Place(slab(20, 10), dx=Pt(-24), dy=Pt(-24)),
        @doc.Place(
          slab(20, 10),
          alignment=Both(Right, Bottom),
          dx=Pt(24),
          dy=Pt(24),
        ),
      ]),
    ),
    content="",
  )
  // The page's fill is no item, and a background or a foreground that
  // covers the page is on it.
  let cover = () => @doc.Rect(width=Pct(100), height=Pct(100), fill=Luma(240))
  inspect(
    lints_on_page([
      @doc.SetPage(fill=Luma(250), background=cover(), foreground=cover()),
      "Text.",
    ]),
    content="",
  )
  // With a bleed the engine lays them out on the page with the bleed, and
  // what the document places into the bleed is on that page, too. Beyond
  // the bleed it is outside.
  let bled = (dx : Double) => {
    page_lints(
      compile([
        @doc.SetPage(
          width=Pt(200),
          height=Pt(120),
          margin=@doc.Sides(all=Pt(10)),
          bleed=@doc.Sides(all=Pt(9)),
          background=cover(),
        ),
        @doc.Place(slab(20, 10), dx=Pt(dx)),
        "Text.",
      ]),
    )
  }
  inspect(bled(-19), content="")
  inspect(
    bled(-25),
    content=(
      #|outside-page (Rect) p1: a shape leaves the page at the left by 6pt
    ),
  )
}

///|
test "lint L3: the bounds of what is rotated, scaled and clipped" {
  // 40pt by 10pt at the right edge would be 5pt outside; turned by a
  // quarter around its middle it is 10pt wide and inside.
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Rotate(slab(40, 10), angle=Deg(90.0)),
        dx=Pt(155),
        dy=Pt(30),
      ),
    ]),
    content="",
  )
  // The other way round: 10pt by 40pt is inside, and turned it is not.
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Rotate(slab(10, 40), angle=Deg(90.0)),
        dx=Pt(170),
        dy=Pt(30),
      ),
    ]),
    content=(
      #|outside-page (Rect) p1: a shape leaves the page at the right by 5pt
    ),
  )
  // A circle that touches the edge still touches it when it is turned:
  // its bounds are those of the turned curve, not of its turned box.
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Rotate(@doc.Circle(radius=Pt(20), fill=Luma(120)), angle=Deg(45.0)),
        dx=Pt(150),
        dy=Pt(20),
      ),
    ]),
    content="",
  )
  // Scaled to a half around its top left corner, 60pt are 30pt.
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Scale(slab(60, 10), factor=Pct(50), origin=Both(Left, Top)),
        dx=Pt(155),
      ),
    ]),
    content="",
  )
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Scale(slab(60, 10), factor=Pct(150), origin=Both(Left, Top)),
        dx=Pt(155),
      ),
    ]),
    content=(
      #|outside-page (Rect) p1: a shape leaves the page at the right by 55pt
    ),
  )
  // Text that is turned: the boxes of its glyphs. As it is written it
  // would end 10pt past the edge.
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Rotate("upwards", angle=Deg(-90.0)),
        dx=Pt(165),
        dy=Pt(40),
      ),
    ]),
    content="",
  )
  // What a clip cuts off is not drawn: a block at the edge that clips
  // its content has nothing outside the page.
  inspect(
    lints_on_page([
      @doc.Place(
        @doc.Block(
          @doc.Place(slab(100, 10)),
          width=Pt(30),
          height=Pt(20),
          clip=true,
        ),
        dx=Pt(150),
      ),
    ]),
    content="",
  )
}

///|
test "lint L3: what the engine draws without a location is at its element" {
  // The marker of a list item is the engine's: it has no span. Its place
  // is the item that it belongs to, and the lint says so.
  let report = compile(
    [
      ..small_page(),
      @doc.List(["An item whose marker is in the margin."], indent=Pt(-30)),
    ],
  )
  inspect(
    page_lints(report),
    content=(
      #|outside-page (List) p1: text leaves the page at the left by 19.4pt
      #|outside-page (List, argument 1) p1: text leaves the page at the left by 11.5pt
    ),
  )
  inspect(
    report.lints[0].hints.map(h => h.message).join("\n"),
    content=(
      #|what is outside the page is cut off: look for a width, a height or an offset that puts it there, a block that cannot break and is higher than the page, a word or a row that is wider
      #|the engine made it without a source location: the place is the element that it is part of
    ),
  )
  // The number of a page in a footer that is too low for it is nobody's:
  // no element around it has a location, and the lint has the page only.
  let numbered = compile([
    @doc.SetPage(
      width=Pt(200),
      height=Pt(120),
      margin=@doc.Sides(all=Pt(10)),
      numbering=@doc.Numbering("1"),
    ),
    @doc.SetText(size=Pt(60)),
    @doc.Text("Text.", size=Pt(10)),
  ])
  inspect(
    page_lints(numbered),
    content=(
      #|outside-page (nowhere) p1: text leaves the page at the bottom by 32.6pt
    ),
  )
  inspect(
    rendered(numbered.lints[0]),
    content=(
      #|lint[outside-page]: text leaves the page at the bottom by 32.6pt
      #|  on page 1
      #|  hint: what is outside the page is cut off: look for a width, a height or an offset that puts it there, a block that cannot break and is higher than the page, a word or a row that is wider
    ),
  )
}

// L3: content outside a container of a fixed size.

///|
/// The groups and tags of a frame, one line each, indented by their
/// depth: a group with the kind and the size of its frame, a tag with its
/// element (`/` for the end of one).
fn skeleton(frame : @library.Frame, depth : Int, out : Array[String]) -> Unit {
  let pad = " ".repeat(depth * 2)
  for entry in frame.items() {
    match entry.1 {
      Group(group) => {
        let kind = if group.frame.kind().is_hard() { "hard" } else { "soft" }
        let size = group.frame.size()
        out.push("\{pad}\{kind} \{pt(size.x.to_pt())}x\{pt(size.y.to_pt())}")
        skeleton(group.frame, depth + 1, out)
      }
      Tag(Start(content, _)) => out.push("\{pad}<\{content.elem().name()}>")
      Tag(End(_, _, _)) => out.push("\{pad}</>")
      _ => ()
    }
  }
}

///|
/// `skeleton` of the pages of a document on the small page.
fn skeleton_of(children : Array[&@doc.IntoContent]) -> String raise {
  let out : Array[String] = []
  for i, page in compile([..small_page(), ..children]).unwrap().pages() {
    out.push("page \{i + 1}")
    skeleton(page.frame, 1, out)
  }
  out.join("\n")
}

///|
test "engine: the frame of a block or box is hard and has its size, and no item says whose it is" {
  // What the lint of containers rests on. A block and a box are a group
  // with a hard frame of their size (a hard frame is never dissolved into
  // the frame around it), with what is in them inside it: also what is
  // placed, whose tags are items of that frame. Neither has a tag of its
  // own, and a group has no span.
  inspect(
    skeleton_of([
      @doc.Block(
        @doc.Seq(["text", @doc.Place(slab(8, 8), dx=Pt(90))]),
        width=Pt(80),
        height=Pt(20),
      ),
      @doc.Par(@doc.Seq(["a ", @doc.Box("b", width=Pt(30), height=Pt(9))])),
    ]),
    content=(
      #|page 1
      #|  hard 80.0x20.0
      #|    <par>
      #|    </>
      #|    <place>
      #|    </>
      #|  <par>
      #|  hard 30.0x9.0
      #|  </>
    ),
  )
  // Without a size it is hard as well, with the size of its content; so
  // is the block that the engine puts around a heading or around raw
  // text. A hard frame alone does not say that a size was given.
  inspect(
    skeleton_of([@doc.Block("text"), @doc.Heading("Title")]),
    content=(
      #|page 1
      #|  hard 15.6x6.6
      #|  <heading>
      #|  hard 30.0x9.0
      #|  </>
    ),
  )
  // A block that is split has a frame per part, of the part's height.
  inspect(
    skeleton_of([
      @doc.V(Pt(70)),
      @doc.Block(five_lines, width=Pt(80), height=Pt(60)),
    ]),
    content=(
      #|page 1
      #|  hard 80.0x30.0
      #|page 2
      #|  hard 80.0x30.0
    ),
  )
}

///|
test "lint L3: content below a block or a box of a fixed height" {
  let words = "one two three four five six seven eight nine ten eleven twelve"
  let report = compile(
    [
      ..small_page(),
      @doc.Block(words, width=Pt(80), height=Pt(20), fill=Luma(220)),
    ],
  )
  inspect(
    page_lints(report),
    content=(
      #|outside-container (Block, argument 1) p1: text leaves its container (Block, 80pt by 20pt) at the bottom by 25.8pt (the farthest of 2)
    ),
  )
  let lint = report.lints[0]
  assert_true(lint.kind == OutsideContainer)
  inspect(lint.kind.name(), content="outside-container")
  inspect(
    rendered(lint),
    content=(
      #|lint[outside-container]: text leaves its container (Block, 80pt by 20pt) at the bottom by 25.8pt (the farthest of 2)
      #|  at LINE (Block, argument 1)
      #|  on page 1
      #|  hint: the container (LINE (Block))
      #|  hint: a block or box with a size of its own does not grow with its content, and cuts nothing off unless `clip=true`
    ),
  )
  // The first hint is the container, and the review loop finds both on
  // the page.
  guard lint.hints[0].location is Some(Edsl(container)) else {
    fail("no container")
  }
  inspect(what(container), content="(Block)")
  let text = report.review_text()
  assert_true(text.origin_positions(container).length() >= 1)
  guard lint.location is Some(Edsl(origin)) else { fail("no origin") }
  assert_true(text.origin_positions(origin).length() >= 1)
  // A box in a line, and a height alone (the width is the region's).
  inspect(
    lints_on_page(["Before ", @doc.Box(words, width=Pt(80), height=Pt(20))]),
    content=(
      #|outside-container (Box, argument 1) p1: text leaves its container (Box, 80pt by 20pt) at the bottom by 25.8pt (the farthest of 2)
    ),
  )
  inspect(
    lints_on_page([@doc.Block(words + " " + words, height=Pt(20))]),
    content=(
      #|outside-container (Block, argument 1) p1: text leaves its container (Block, 177.2pt by 20pt) at the bottom by 12.7pt
    ),
  )
  // With room for the lines, or with a clip, nothing is found.
  inspect(
    lints_on_page([@doc.Block(words, width=Pt(80), height=Pt(60))]),
    content="",
  )
  inspect(
    lints_on_page([@doc.Block(words, width=Pt(80), height=Pt(20), clip=true)]),
    content="",
  )
}

///|
/// A drawing as the kit's `Canvas` makes it: an unbreakable block of a
/// size whose items are placed.
fn drawing(
  width : Double,
  height : Double,
  items : Array[&@doc.IntoContent],
) -> @doc.Block {
  @doc.Block(
    @doc.Seq(items),
    width=Pt(width),
    height=Pt(height),
    breakable=false,
  )
}

///|
test "lint L3: a label that leaves its drawing, also one built in a callback" {
  // The case of the ports: the label of a bar of a chart is placed where
  // the bar ends, and the last one is past the edge of the drawing.
  let chart = (width : Double) => {
    let items : Array[&@doc.IntoContent] = []
    for i, value in [40.0, 90.0, 150.0] {
      let y = 4.0 + i.to_double() * 14.0
      items.push(
        @doc.Keyed(
          "bar \{i}",
          @doc.Seq([
            @doc.Place(slab(value, 8), dy=Pt(y)),
            @doc.Place(
              @doc.Text("\{value.to_int()} requests", size=Pt(7)),
              dx=Pt(value + 3.0),
              dy=Pt(y + 1.0),
            ),
          ]),
        ),
      )
    }
    drawing(width, 46, items)
  }
  inspect(
    lints_on_page([chart(180)]),
    content=(
      #|outside-container (Text, argument 1, key "bar 2") p1: text leaves its container (Block, 180pt by 46pt) at the right by 8pt
    ),
  )
  // As wide as its container: built in a `Layout`, when the page is laid
  // out. The description tree does not have it; lowering does.
  let report = compile(
    [..small_page(), @doc.Layout((size, _) => chart(size.width))],
  )
  inspect(error_messages(report), content="")
  inspect(
    page_lints(report),
    content=(
      #|outside-container (Text, argument 1, key "bar 2") p1: text leaves its container (Block, 180pt by 46pt) at the right by 8pt
    ),
  )
  // Wide enough for the labels: nothing.
  inspect(
    lints_on_page([
      @doc.SetPage(width=Pt(260)),
      @doc.Layout((size, _) => chart(size.width)),
    ]),
    content="",
  )
  // Every side: a square of 8pt in a drawing of 60pt by 30pt.
  let square = (dx : Double, dy : Double) => {
    lints_on_page([
      @doc.V(Pt(20)),
      drawing(60, 30, [@doc.Place(slab(8, 8), dx=Pt(dx), dy=Pt(dy))]),
    ])
  }
  inspect(
    square(-5, 10),
    content=(
      #|outside-container (Rect) p1: a shape leaves its container (Block, 60pt by 30pt) at the left by 5pt
    ),
  )
  inspect(
    square(20, -6),
    content=(
      #|outside-container (Rect) p1: a shape leaves its container (Block, 60pt by 30pt) at the top by 6pt
    ),
  )
  inspect(
    square(57, 10),
    content=(
      #|outside-container (Rect) p1: a shape leaves its container (Block, 60pt by 30pt) at the right by 5pt
    ),
  )
  inspect(
    square(20, 25),
    content=(
      #|outside-container (Rect) p1: a shape leaves its container (Block, 60pt by 30pt) at the bottom by 3pt
    ),
  )
  inspect(square(20, 10), content="")
  // Inside the tolerance of a point.
  inspect(square(53, 10), content="")
}

///|
test "lint L3: only the sides that the container fixed" {
  // A width alone: a word that cannot break leaves at the right, and
  // nothing is said of the height, which is the content's.
  inspect(
    lints_on_page([
      @doc.Block("an_identifier_that_is_too_long gypsy", width=Pt(60)),
    ]),
    content=(
      #|outside-container (Block, argument 1) p1: text leaves its container (Block, 60pt by 19.7pt) at the right by 65.7pt
    ),
  )
  // Not seen: a size that is not absolute (per cent of the region, em),
  // a size from a set rule, a shape with a size, a cell of a grid with
  // fixed tracks.
  let long = "an_identifier_that_is_too_long"
  inspect(
    lints_on_page([
      @doc.Block(long, width=Pct(30)),
      @doc.Block(long, width=Em(6)),
      @doc.Seq([@doc.SetBlock(width=Pt(60)), @doc.Block(long)]),
      @doc.Rect(body=long, width=Pt(60)),
      @doc.Grid([long, "b"], columns=[Pt(60), Pt(60)]),
    ]),
    content="",
  )
}

///|
test "lint L3: what a container draws itself, and what the engine lets hang" {
  // The fill and the stroke of the container are not its content: an
  // outset puts them outside on purpose.
  inspect(
    lints_on_page([
      @doc.V(Pt(10)),
      @doc.Block(
        "inside",
        width=Pt(80),
        height=Pt(20),
        fill=Luma(220),
        stroke=@doc.Sides(all=@doc.Stroke(thickness=Pt(4))),
        outset=@doc.Sides(all=Pt(6)),
        radius=@doc.Corners(all=Pt(3)),
        inset=@doc.Sides(all=Pt(4)),
      ),
    ]),
    content="",
  )
  // The descenders of the last line are below every block: a line of
  // text ends at its baseline. A block that is exactly as high as its
  // line (6.58pt: the cap height of 10pt text) has nothing outside.
  inspect(
    lints_on_page([@doc.Block("gypsy jog", width=Pt(80), height=Pt(6.58))]),
    content="",
  )
  // The mark at the end of a justified line hangs over the edge
  // (`text.overhang`): full stops, commas, hyphens.
  let marks = "It is. It was. Go on, go. So it is. As is. No, no. On it. Up, up. It is so. Do it. We do. If so. Be it. At it. To be. He is. Or so. It is. It was. Go on, go. So it is. Co-op, re-do, so-so, on-off, in-out, up-to, as-is."
  let justified = compile([
    @doc.SetPage(width=Pt(400), height=Pt(700), margin=@doc.Sides(all=Pt(10))),
    @doc.SetText(size=Pt(20)),
    @doc.SetPar(justify=true),
    @doc.Block(@doc.Para(marks), width=Pt(160)),
  ])
  inspect(page_lints(justified), content="")
  // (They do hang: on a page without a margin they are cut off, which is
  // what the lint of the page reports.)
  let cut = compile([
    @doc.SetPage(width=Pt(160), height=Pt(700), margin=@doc.Sides(all=Pt(0))),
    @doc.SetText(size=Pt(20)),
    @doc.SetPar(justify=true),
    @doc.Para(marks),
  ])
  inspect(
    page_lints(cut),
    content=(
      #|outside-page (Para, argument 1) p1: text leaves the page at the right by 2.5pt (the farthest of 8)
    ),
  )
}

///|
test "lint L3: which frame is a container's" {
  let long = "an_identifier_that_is_too_long"
  // A block that is split at the end of a page has two frames, neither
  // of its size: not seen (finding S2a).
  let split = compile(
    [
      ..small_page(),
      @doc.V(Pt(70)),
      @doc.Block(five_lines, width=Pt(80), height=Pt(60), fill=Luma(220)),
    ],
  )
  assert_eq(split.unwrap().pages().length(), 2)
  inspect(page_lints(split), content="")
  // Containers inside each other: each is compared with what is in it.
  inspect(
    lints_on_page([
      @doc.Block(
        @doc.Block(long, width=Pt(60), height=Pt(30)),
        width=Pt(100),
        height=Pt(40),
      ),
    ]),
    content=(
      #|outside-container (Block, argument 1) p1: text leaves its container (Block, 60pt by 30pt) at the right by 65.7pt
      #|outside-container (Block, argument 1) p1: text leaves its container (Block, 100pt by 40pt) at the right by 25.7pt
    ),
  )
  inspect(
    lints_on_page([
      @doc.Block(
        @doc.Block(long, width=Pt(60), height=Pt(30)),
        width=Pt(140),
        height=Pt(40),
      ),
    ]),
    content=(
      #|outside-container (Block, argument 1) p1: text leaves its container (Block, 60pt by 30pt) at the right by 65.7pt
    ),
  )
  // One description in two containers of other sizes, and one container
  // that a function builds for many rows: one lint for one call site.
  let label = @doc.Place(@doc.Text("a label", size=Pt(8)), dx=Pt(50))
  inspect(
    lints_on_page([drawing(60, 12, [label]), drawing(100, 12, [label])]),
    content=(
      #|outside-container (Text, argument 1) p1: text leaves its container (Block, 60pt by 12pt) at the right by 11pt
    ),
  )
  let rows : Array[&@doc.IntoContent] = []
  for i in 0..<5 {
    rows.push(@doc.Keyed("row \{i}", drawing(60, 12, [label])))
  }
  inspect(
    lints_on_page(rows),
    content=(
      #|outside-container (Text, argument 1, key "row 0") p1: text leaves its container (Block, 60pt by 12pt) at the right by 11pt (the farthest of 5)
    ),
  )
  // A container that is turned: the amounts are in its own coordinates.
  inspect(
    lints_on_page([
      @doc.V(Pt(30)),
      @doc.Rotate(
        drawing(60, 12, [@doc.Place(slab(10, 6), dx=Pt(56), dy=Pt(3))]),
        angle=Deg(90.0),
      ),
    ]),
    content=(
      #|outside-container (Rect) p1: a shape leaves its container (Block, 60pt by 12pt) at the right by 6pt
    ),
  )
  inspect(
    lints_on_page([
      @doc.V(Pt(30)),
      @doc.Rotate(
        drawing(60, 12, [@doc.Place(slab(10, 6), dx=Pt(40), dy=Pt(3))]),
        angle=Deg(90.0),
      ),
    ]),
    content="",
  )
  // Content from Typst source inside a container.
  inspect(
    lints_on_page([
      @doc.Block(
        @doc.Markup("#place(dx: 70pt, rect(width: 20pt, height: 5pt))"),
        width=Pt(80),
        height=Pt(20),
      ),
    ]),
    content=(
      #|outside-container (Markup, bytes 17..47 of the source string) p1: a shape leaves its container (Block, 80pt by 20pt) at the right by 10.5pt
    ),
  )
}

// The report.

///|
test "lints of the pages: where they run" {
  let doc = @doc.Document(
    [
      ..small_page(),
      @doc.Block("a\u{4e2d}", width=Pt(80), height=Pt(3)),
      @doc.Place(slab(40, 20), dx=Pt(170)),
    ],
  )
  let world = @doc.DocWorld::in_memory()
  let kinds = (lints : Array[@doc.Lint]) => {
    lints.map(lint => lint.kind.name()).join(" ")
  }
  // A paged compilation has all of them, after the lints of the tree.
  inspect(
    kinds(doc.compile_paged(world).lints),
    content=(
      #|missing-glyph outside-container outside-page
    ),
  )
  // `lints=false` turns them off, too.
  inspect(kinds(doc.compile_paged(world, lints=false).lints), content="")
  // Without pages there is nothing to read: lowering, and the generic
  // `compile`, which is how another output (HTML) is made.
  inspect(kinds(doc.lower(world).lints), content="")
  let generic : @doc.CompileReport[@layout.PagedDocument] = doc.compile(world)
  inspect(kinds(generic.lints), content="")
  // A document that does not compile has no pages.
  let failed = @doc.Document(
    [..small_page(), "a\u{4e2d}", @doc.Image("missing.png")],
  ).compile_paged(world)
  assert_true(failed.output() is None)
  inspect(kinds(failed.lints), content="")
  // The lints of the tree have no page.
  let tree = @doc.Document([@doc.Prose("One."), @doc.Prose("Two.")]).compile_paged(
    world,
  )
  assert_true(tree.lints[0].page is None)
  assert_true(!tree.lints[0].render().contains("on page"))
}
