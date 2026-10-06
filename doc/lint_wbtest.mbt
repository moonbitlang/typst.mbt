// The block list of lint L1 (`is_block_call` in `lint.mbt`) against the
// engine, for every constructor of the generator's element table
// (`generated_elements`, from `scripts/docgen.py`): a constructor is on
// the list if and only if the engine does not typeset it inside a
// paragraph. A new element fails this test until it is classified here.

///|
/// Whether the paragraphs of a frame include one with the texts `AAA` and
/// `BBB`.
fn has_joined_par(frame : @library.Frame) -> Bool {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => if has_joined_par(group.frame) { return true }
      Tag(Start(content, _)) =>
        if content.elem() == @library.par_elem() {
          let text = content.plain_text()
          if text.contains("AAA") && text.contains("BBB") {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
/// What the engine does with `item` between two strings at the top of a
/// document: whether the strings are in one paragraph (so `item` is
/// inline content) or not (`item` is a block of the flow or ends the
/// paragraph).
fn joins(item : &IntoContent) -> Bool raise {
  let files : Map[String, Bytes] = Map([])
  files["refs.yaml"] = @utf8.encode(
    "probe:\n  type: Book\n  title: A plain title\n  author: Doe, Jane\n  date: 2020\n",
  )
  files["dot.svg"] = @utf8.encode(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"4\" height=\"4\"><rect width=\"4\" height=\"4\"/></svg>",
  )
  let report = Document([
    SetPage(width=Pt(200), height=Pt(200), margin=Sides(all=Pt(10))),
    "AAA",
    item,
    "BBB",
    // (For the samples that cite.)
    Bibliography("refs.yaml"),
  ]).compile_paged(DocWorld::in_memory(files~), lints=false)
  let mut joined = false
  let mut pars = 0
  for page in report.unwrap().pages() {
    if has_joined_par(page.frame) {
      joined = true
    }
    pars += 1
  }
  guard pars > 0 else { fail("no pages") }
  joined
}

///|
/// A sample of every constructor of the generator's element table, with
/// what the lint must say of it: `"block"`, `"inline"`, or `"part"` for
/// an element that only occurs inside another one (a cell, a segment of a
/// curve) or has no constructor, which the lint must not take for a
/// block and the engine is not asked about.
fn block_samples() -> Array[(String, String, Content)] {
  let c = (body : &IntoContent) => body.into_content()
  let dot : (Length, Length) = (Pt(0), Pt(0))
  [
    // Model.
    ("Heading", "block", c(Heading("x"))),
    ("Par", "block", c(Par("x"))),
    ("Parbreak", "block", c(Parbreak())),
    ("Strong", "inline", c(Strong("x"))),
    ("Emph", "inline", c(Emph("x"))),
    ("Link", "inline", c(Link(Url("https://typst.app"), body="x"))),
    ("Ref", "inline", c(Ref("probe"))),
    ("Footnote", "inline", c(Footnote("x"))),
    ("Quote", "inline", c(Quote("x"))),
    ("Quote", "block", c(Quote("x", block=true))),
    ("List", "block", c(List(["x"]))),
    ("ListItem", "block", c(ListItem("x"))),
    ("Enum", "block", c(Enum(["x"]))),
    ("EnumItem", "block", c(EnumItem("x"))),
    ("Terms", "block", c(Terms([TermsItem("t", "x")]))),
    ("TermsItem", "block", c(TermsItem("t", "x"))),
    ("Figure", "block", c(Figure("x"))),
    ("Table", "block", c(Table(["x"]))),
    ("TableCell", "part", c(TableCell("x"))),
    ("TableHeader", "part", c(TableHeader(["x"]))),
    ("TableFooter", "part", c(TableFooter(["x"]))),
    ("TableHline", "part", c(TableHline())),
    ("TableVline", "part", c(TableVline())),
    ("Outline", "block", c(Outline())),
    ("Document", "part", c(Space())),
    ("Title", "block", c(Title(body="x"))),
    // Text.
    ("Text", "inline", c(Text("x", size=Pt(9)))),
    ("Raw", "inline", c(Raw("x"))),
    ("Raw", "block", c(Raw("x", block=true))),
    ("Linebreak", "inline", c(Linebreak())),
    ("Smartquote", "inline", c(Smartquote())),
    ("Underline", "inline", c(Underline("x"))),
    ("Overline", "inline", c(Overline("x"))),
    ("Strike", "inline", c(Strike("x"))),
    ("Highlight", "inline", c(Highlight("x"))),
    ("Sub", "inline", c(Sub("x"))),
    ("Super", "inline", c(Super("x"))),
    ("Smallcaps", "inline", c(Smallcaps("x"))),
    // Layout.
    ("Page", "block", c(Page("x"))),
    ("Pagebreak", "block", c(Pagebreak())),
    ("Align", "block", c(Align(Start, "x"))),
    ("Block", "block", c(Block("x"))),
    ("Box", "inline", c(Box("x"))),
    ("Pad", "block", c(Pad("x", left=Pt(2)))),
    ("Place", "block", c(Place("x", alignment=Both(Top, Right)))),
    ("Stack", "block", c(Stack(["x"]))),
    ("Grid", "block", c(Grid(["x"]))),
    ("GridCell", "part", c(GridCell("x"))),
    ("GridHeader", "part", c(GridHeader(["x"]))),
    ("GridFooter", "part", c(GridFooter(["x"]))),
    ("GridHline", "part", c(GridHline())),
    ("GridVline", "part", c(GridVline())),
    ("Columns", "block", c(Columns("x", count=2))),
    ("Colbreak", "block", c(Colbreak())),
    ("H", "inline", c(H(Pt(4)))),
    ("V", "block", c(V(Pt(4)))),
    ("Hide", "inline", c(Hide("x"))),
    ("Repeat", "block", c(Repeat("x"))),
    ("Move", "block", c(Move("x", dx=Pt(1)))),
    ("Rotate", "block", c(Rotate("x", angle=Deg(10)))),
    ("Image", "block", c(Image("dot.svg"))),
    ("Line", "block", c(Line(length=Pt(20)))),
    ("Rect", "block", c(Rect(width=Pt(4), height=Pt(4)))),
    ("Square", "block", c(Square(size=Pt(4)))),
    ("Ellipse", "block", c(Ellipse(width=Pt(4), height=Pt(4)))),
    ("Circle", "block", c(Circle(radius=Pt(2)))),
    ("Polygon", "block", c(Polygon([dot, (Pt(4), Pt(0)), (Pt(4), Pt(4))]))),
    ("Curve", "block", c(Curve([CurveLine((Pt(4), Pt(4)))]))),
    ("CurveMove", "part", c(CurveMove(dot))),
    ("CurveLine", "part", c(CurveLine(dot))),
    ("CurveQuad", "part", c(CurveQuad(dot, dot))),
    ("CurveCubic", "part", c(CurveCubic(dot, dot, dot))),
    ("CurveClose", "part", c(CurveClose())),
    ("Scale", "block", c(Scale("x", x=Pct(50)))),
    ("Skew", "block", c(Skew("x", ax=Deg(10)))),
    // Math: the handwritten constructor.
    ("Equation", "inline", c(Equation("x"))),
    ("Equation", "block", c(Equation("x", block=true))),
    // Bibliography, introspection.
    ("Bibliography", "block", c(Bibliography("refs.yaml"))),
    ("Cite", "inline", c(Cite("probe"))),
    ("Metadata", "inline", c(Metadata(Value::int(1)))),
  ]
}

///|
test "lint L1: the block list is what the engine keeps out of a paragraph, for the whole element table" {
  let samples = block_samples()
  // Every constructor of the generator has a sample.
  for entry in generated_elements() {
    let mut found = false
    for sample in samples {
      if sample.0 == entry.0 {
        found = true
      }
    }
    if !found {
      fail(
        "\{entry.0} (`\{entry.1}`) is not classified for lint L1: add a sample",
      )
    }
  }
  let wrong : Array[String] = []
  for sample in samples {
    let (name, class, content) = sample
    let listed = is_block(content)
    if listed != (class == "block") {
      wrong.push("\{name}: the list says \{listed}, the sample \{class}")
    }
    if class != "part" {
      let engine = !joins(content)
      if engine != listed {
        wrong.push(
          "\{name} (\{class}): the engine keeps it out of a paragraph: \{engine}; the list: \{listed}",
        )
      }
    }
    // A text item is never a block.
    if listed && is_text_item(content) {
      wrong.push("\{name}: a block and a text item")
    }
  }
  inspect(wrong.join("\n"), content="")
}
