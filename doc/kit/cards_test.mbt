// `Cards` (docs/edsl-ports.md, section 4): what it expands to, that the
// cards of a row are equally high, where they break, and the provenance
// of its parts. The pairs with a Typst twin are in
// `doc/twins/kit.mbt`. The page of these tests is 200pt by 120pt with 10pt
// margins and 10pt text unless a test says otherwise, so the region is
// 180pt by 100pt; lengths are in points from the page's top left corner.

///|
using @doc {
  type Block,
  type Document,
  type Emph,
  type Grid,
  type GridCell,
  type Keyed,
  type SetPage,
  type SetText,
  type Show,
  type Select,
  type Heading,
  type Sides,
  type Stroke,
  type Sizing,
  type V,
  trait IntoContent,
}

///|
/// A drawn card (a filled shape: a rectangle, or the outline of a rounded
/// one) or a line of text on a page (`y` is its baseline, `h` is 0).
priv struct Mark {
  page : Int
  text : String
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
/// The filled shapes and the text runs of a frame at `(dx, dy)`.
fn collect(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  page : Int,
  out : Array[Mark],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    match entry.1 {
      Group(group) =>
        collect(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          page,
          out,
        )
      Text(text) =>
        out.push({
          page,
          text: text.text,
          x,
          y,
          w: text.width().to_pt(),
          h: 0.0,
        })
      Shape(shape, _) => {
        guard shape.fill is Some(_) else { continue }
        // The bounding box of the outline.
        let mut left = 0.0
        let mut top = 0.0
        let mut right = 0.0
        let mut bottom = 0.0
        let mut first = true
        let point = (p : @library.Point) => {
          let (px, py) = (p.x.to_pt(), p.y.to_pt())
          if first {
            left = px
            right = px
            top = py
            bottom = py
            first = false
          } else {
            left = if px < left { px } else { left }
            right = if px > right { px } else { right }
            top = if py < top { py } else { top }
            bottom = if py > bottom { py } else { bottom }
          }
        }
        match shape.geometry {
          Rect(size) => {
            point(@library.Point::zero())
            point(@library.Point::new(size.x, size.y))
          }
          Curve(curve) =>
            for item in curve.items() {
              match item {
                Move(p) | Line(p) => point(p)
                Cubic(p1, p2, p3) => {
                  point(p1)
                  point(p2)
                  point(p3)
                }
                Close => ()
              }
            }
          Line(_) => continue
        }
        out.push({
          page,
          text: "",
          x: x + left,
          y: y + top,
          w: right - left,
          h: bottom - top,
        })
      }
      _ => ()
    }
  }
}

///|
/// The page of the tests.
fn page(
  width? : @doc.Length = Pt(200),
  height? : @doc.Length = Pt(120),
) -> Array[&IntoContent] {
  [SetPage(width~, height~, margin=Sides(all=Pt(10))), SetText(size=Pt(10))]
}

///|
/// Compile `children` after `setup` (the page of the tests by default).
fn compile(
  children : Array[&IntoContent],
  setup? : Array[&IntoContent] = page(),
) -> @doc.CompileReport[@layout.PagedDocument] {
  Document([..setup, ..children]).compile_paged(@doc.DocWorld::in_memory())
}

///|
fn errors(report : @doc.CompileReport[@layout.PagedDocument]) -> String {
  report.errors.map(e => e.message).join(" | ")
}

///|
fn warnings(report : @doc.CompileReport[@layout.PagedDocument]) -> String {
  report.warnings.map(w => w.message).join(" | ")
}

///|
/// The marks of a compiled document.
fn marks(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[Mark] raise {
  let out = []
  for i, page in report.unwrap().pages() {
    collect(page.frame, 0.0, 0.0, i + 1, out)
  }
  out
}

///|
/// A length in points with one decimal.
fn pt(x : Double) -> String {
  let tenths = (x * 10.0).round().to_int()
  let sign = if tenths < 0 { "-" } else { "" }
  let tenths = tenths.abs()
  "\{sign}\{tenths / 10}.\{tenths % 10}"
}

///|
/// The cards of a compiled document in reading order, one line each: the
/// page, the position and the size. (A grid draws the fills of its cells
/// column by column, the blocks are drawn row by row.)
fn cards(report : @doc.CompileReport[@layout.PagedDocument]) -> String raise {
  let cards = marks(report).filter(m => m.text == "")
  cards.sort_by((a, b) => {
    if a.page != b.page {
      a.page.compare(b.page)
    } else if (a.y - b.y).abs() > 0.01 {
      a.y.compare(b.y)
    } else {
      a.x.compare(b.x)
    }
  })
  cards
  .map(m => "p\{m.page} \{pt(m.x)},\{pt(m.y)} \{pt(m.w)}x\{pt(m.h)}")
  .join("\n")
}

///|
/// The number of pages.
fn pages(report : @doc.CompileReport[@layout.PagedDocument]) -> Int raise {
  report.unwrap().pages().length()
}

///|
/// The lowered content of a document, as Typst prints it.
fn lowered(children : Array[&IntoContent]) -> String raise {
  Document(children).lower(@doc.DocWorld::in_memory()).unwrap().repr()
}

///|
/// The origin of each text run: its text, the constructor, the argument
/// (`a0`: the first; `call`: none) and the keys.
fn text_args(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String raise {
  let out : Array[String] = []
  fn walk(frame : @library.Frame) -> Unit {
    for entry in frame.items() {
      match entry.1 {
        Group(group) => walk(group.frame)
        Text(text) =>
          for glyph in text.glyphs {
            let line = match
              report.origins.resolve_glyph(
                glyph.span,
                glyph.span_offset.to_int(),
              ) {
              Some(found) => "\{text.text}: \{place(found.origin)}"
              None => "\{text.text}: -"
            }
            if !out.contains(line) {
              out.push(line)
            }
          }
        _ => ()
      }
    }
  }

  for page in report.unwrap().pages() {
    walk(page.frame)
  }
  out.join(" | ")
}

///|
/// An origin as its constructor, its argument and its keys.
fn place(origin : @doc.Origin) -> String {
  let arg = match origin.param {
    Some(param) => "a\{param}"
    None => "call"
  }
  let keys = if origin.keys.is_empty() {
    ""
  } else {
    " " + origin.keys.join("/")
  }
  "\{origin.kind} \{arg}\{keys}"
}

///|
/// The origin of the first error of a report.
fn error_origin(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> @doc.Origin raise {
  guard report.errors[0].location is Some(Edsl(origin)) else {
    fail("expected an EDSL location: \{report.errors[0].render()}")
  }
  origin
}

///|
/// Where the first error of a report is.
fn error_place(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String raise {
  place(error_origin(report))
}

///|
/// The line of the call of this function.
#callsite(autofill(loc))
fn line_here(loc~ : SourceLoc) -> Int {
  // `file:line:column-line:column@module`.
  let mut line = 0
  let mut colons = 0
  for c in loc.to_string() {
    if c == ':' {
      colons += 1
    } else if colons == 1 {
      line = line * 10 + (c.to_int() - '0'.to_int())
    }
  }
  line
}

///|
/// Three items of unequal height in a third of the region.
let uneven : Array[String] = [
  "One.", "Two has more words than fit one line of a card.", "Three.",
]

///|
/// The look of the cards of these tests.
let inset : Sides[@doc.Length] = Sides(all=Pt(4))

///|
let hairline : Sides[Stroke] = Sides(all=Stroke(thickness=Pt(0.5)))

///|
fn items(texts : Array[String]) -> Array[&IntoContent] {
  texts.map(text => text as &IntoContent)
}

///|
test "cards: a grid whose cells draw the cards" {
  // The expansion: the items in cells that carry the fill, the stroke and
  // the inset; one `1fr` column per item unless `columns` says otherwise.
  assert_eq(
    lowered([
      @kit.Cards(
        ["a", Emph("b")],
        gutter=[Pt(6)],
        fill=Luma(230),
        stroke=hairline,
        inset~,
      ),
    ]),
    lowered([
      Grid(
        [
          GridCell("a", fill=Luma(230), stroke=hairline, inset~),
          GridCell(Emph("b"), fill=Luma(230), stroke=hairline, inset~),
        ],
        columns=[Fr(1), Fr(1)],
        gutter=[Pt(6)],
      ),
    ]),
  )
  // Only what is given is passed on: the defaults are the primitives'.
  assert_eq(
    lowered([
      @kit.Cards(
        ["a", "b", "c"],
        columns=[Pt(40), Fr(1)],
        column_gutter=[Pt(2)],
        row_gutter=[Pt(3)],
      ),
    ]),
    lowered([
      Grid(
        [GridCell("a"), GridCell("b"), GridCell("c")],
        columns=[Pt(40), Fr(1)],
        column_gutter=[Pt(2)],
        row_gutter=[Pt(3)],
      ),
    ]),
  )
  // No items: an empty grid.
  assert_eq(lowered([@kit.Cards([])]), lowered([Grid([], columns=[])]))
  // It prints as its name around what it is made of.
  debug_inspect(
    @kit.Cards(["a"], fill=Red),
    content=(
      #|Cards(Grid(columns=[1fr], Keyed("0", GridCell("a", fill=red))))
    ),
  )
}

///|
test "cards: the cards of a row are equally high" {
  let cells = compile([
    "Before.",
    @kit.Cards(items(uneven), gutter=[Pt(6)], fill=Luma(230), inset~),
  ])
  inspect(errors(cells), content="")
  inspect(warnings(cells), content="")
  // Three cards of 56pt (a third of 180pt less two gutters), all as high
  // as the second, whose text takes five lines.
  inspect(
    cards(cells),
    content=(
      #|p1 10.0,28.6 56.0x66.9
      #|p1 72.0,28.6 56.0x66.9
      #|p1 134.0,28.6 56.0x66.9
    ),
  )
  assert_eq(pages(cells), 1)
  // What it replaces (finding S3): a block of `height=Pct(100)` per card
  // is as high as the region and adds a page.
  let blocks_of_blocks = compile([
    "Before.",
    Grid(
      items(uneven).map(item => {
        Block(item, height=Pct(100), fill=Luma(230), inset~)
      }),
      columns=[Fr(1), Fr(1), Fr(1)],
      gutter=[Pt(6)],
    ),
  ])
  assert_eq(pages(blocks_of_blocks), 2)
  // And a block per card without a size is as high and as wide as its
  // own text.
  let plain = compile([
    "Before.",
    Grid(
      items(uneven).map(item => Block(item, fill=Luma(230), inset~)),
      columns=[Fr(1), Fr(1), Fr(1)],
      gutter=[Pt(6)],
    ),
  ])
  inspect(
    cards(plain),
    content=(
      #|p1 10.0,28.6 27.0x14.6
      #|p1 72.0,28.6 54.1x66.9
      #|p1 134.0,28.6 34.1x14.6
    ),
  )
}

///|
test "cards: several rows, a last row that is not full, and the end of a page" {
  let five = ["1", "2 two two two two two", "3", "4", "5 five five five five"]
  // Two rows; the second has two cards and an open place, not an empty
  // card. Every row has the height of its own highest card.
  let report = compile(setup=page(height=Pt(400)), [
    @kit.Cards(
      items(five),
      columns=Sizing::repeat(3, size=Fr(1)),
      gutter=[Pt(4)],
      row_gutter=[Pt(8)],
      fill=Luma(230),
      inset~,
    ),
  ])
  inspect(errors(report), content="")
  inspect(
    cards(report),
    content=(
      #|p1 10.0,10.0 57.3x40.7
      #|p1 71.3,10.0 57.3x40.7
      #|p1 132.7,10.0 57.3x40.7
      #|p1 10.0,58.7 57.3x27.7
      #|p1 71.3,58.7 57.3x27.7
    ),
  )
  // At the end of a page the grid breaks a row as it breaks any row: the
  // lines that fit stay, and both cards of the row continue on the next
  // page.
  let six = [
    "1",
    "2 two two two two two two two",
    "3",
    "4 " + "four ".repeat(22),
    "5",
    "6",
  ]
  let cells = compile([
    V(Pt(20)),
    @kit.Cards(
      items(six),
      columns=Sizing::repeat(2, size=Fr(1)),
      gutter=[Pt(6)],
      fill=Luma(230),
      inset~,
    ),
  ])
  inspect(errors(cells), content="")
  inspect(
    cards(cells),
    content=(
      #|p1 10.0,30.0 87.0x27.7
      #|p1 103.0,30.0 87.0x27.7
      #|p1 10.0,63.7 87.0x46.3
      #|p1 103.0,63.7 87.0x46.3
      #|p2 10.0,10.0 87.0x40.7
      #|p2 103.0,10.0 87.0x40.7
      #|p2 10.0,56.7 87.0x14.6
      #|p2 103.0,56.7 87.0x14.6
    ),
  )
}

///|
test "cards: provenance, and that it can be built inside a callback" {
  let own = Emph("stressed")
  let line = line_here() + 2
  let report = compile([
    @kit.Cards(["plain", own, "plain"], fill=Luma(230), inset~),
  ])
  inspect(errors(report), content="")
  // A string of the caller is the `items` argument under the key of its
  // card; a description of the caller is at its own call, under that key
  // too.
  inspect(
    text_args(report),
    content="plain: Cards a0 0 | stressed: Emph a0 1 | plain: Cards a0 2",
  )
  // A click on a card, which the element drew: the call.
  let card = marks(report).filter(m => m.text == "")[0]
  guard report.origin_at(1, card.x + card.w - 2.0, card.y + card.h - 2.0)
    is Some(origin) else {
    fail("no origin at the card")
  }
  inspect(place(origin), content="Cards call")
  assert_eq(origin.start_line, line)
  // Under a key of the caller.
  inspect(
    text_args(compile([Keyed("row", @kit.Cards(["a", "b"]))])),
    content="a: Cards a0 row/0 | b: Cards a0 row/1",
  )
  // An error in an argument is at that argument: every argument that is
  // passed on.
  let stroke : Sides[Stroke] = Sides(
    all=Stroke(paint=Value(@doc.Value::str("x"))),
  )
  let failing : Array[(String, @kit.Cards)] = [
    ("columns", @kit.Cards(["a"], columns=[None])),
    ("gutter", @kit.Cards(["a"], gutter=[None])),
    ("column_gutter", @kit.Cards(["a"], column_gutter=[None])),
    ("row_gutter", @kit.Cards(["a"], row_gutter=[None])),
    ("fill", @kit.Cards(["a"], fill=Value(@doc.Value::str("x")))),
    ("stroke", @kit.Cards(["a"], stroke~)),
    ("inset", @kit.Cards(["a"], inset=Sides::none())),
  ]
  let places : Array[String] = []
  for entry in failing {
    let (name, cards) = entry
    let report = compile([cards])
    assert_true(errors(report) != "")
    places.push("\{name}: \{error_place(report)}")
  }
  inspect(
    places.join(" | "),
    content=(
      #|columns: Cards a1 | gutter: Cards a2 | column_gutter: Cards a3 | row_gutter: Cards a4 | fill: Cards a5 0 | stroke: Cards a6 0 | inset: Cards a7 0
    ),
  )
  // There is no callback in it: it can be built anywhere.
  let in_show = compile([
    Show(Select::heading()) <| ((it, _) => {
      @kit.Cards([it, "beside"], fill=Luma(230), inset~)
    }),
    Heading("Head"),
  ])
  inspect(errors(in_show), content="")
  assert_eq(cards(in_show).split("\n").count(), 2)
}
