// `Cards` (docs/edsl-ports.md, section 4): what it expands to, that the
// cards of a row are equally high in both forms, where they break, and
// the provenance of its parts. The pairs with a Typst twin are in
// `doc/twins/kit.mbt`. The page of these tests is 200pt by 120pt with 10pt
// margins and 10pt text unless a test says otherwise, so the region is
// 180pt by 100pt; lengths are in points from the page's top left corner.

///|
using @doc {
  type Block,
  type Cells,
  type Columns,
  type Context,
  type Corners,
  type Document,
  type Emph,
  type Grid,
  type GridCell,
  type Keyed,
  type Pad,
  type Seq,
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
let round : Corners[@doc.Length] = Corners(all=Pt(3))

///|
fn items(texts : Array[String]) -> Array[&IntoContent] {
  texts.map(text => text as &IntoContent)
}

///|
test "cards: without a radius it is a grid whose cells draw the cards" {
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
  // No items: an empty grid, with or without a radius.
  assert_eq(lowered([@kit.Cards([])]), lowered([Grid([], columns=[])]))
  assert_eq(
    lowered([@kit.Cards([], radius=round)]),
    lowered([Grid([], columns=[])]),
  )
  // It prints as its name around what it is made of.
  debug_inspect(
    @kit.Cards(["a"], fill=Red),
    content=(
      #|Cards(Grid(columns=[1fr], Keyed("0", GridCell("a", fill=red))))
    ),
  )
}

///|
test "cards: the cards of a row are equally high, in both forms" {
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
  // With a radius: the same boxes, drawn as rounded blocks.
  let blocks = compile([
    "Before.",
    @kit.Cards(
      items(uneven),
      gutter=[Pt(6)],
      fill=Luma(230),
      inset~,
      radius=round,
    ),
  ])
  inspect(errors(blocks), content="")
  inspect(warnings(blocks), content="")
  assert_eq(cards(blocks), cards(cells))
  assert_eq(pages(blocks), 1)
  // The text is where it is in the cells.
  let texts = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    marks(report)
    .filter(m => m.text != "")
    .map(m => "\{m.text} \{pt(m.x)},\{pt(m.y)}")
    .join("\n")
  }
  assert_eq(texts(blocks), texts(cells))
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
test "cards: several rows, a last row that is not full, and other tracks" {
  let five = ["1", "2 two two two two two", "3", "4", "5 five five five five"]
  // (On a page that holds every row: where rows meet the end of a page the
  // two forms differ, see below.)
  let setup = page(height=Pt(400))
  let both = (columns : Array[Sizing]) => {
    let cells = compile(setup~, [
      @kit.Cards(
        items(five),
        columns~,
        gutter=[Pt(4)],
        row_gutter=[Pt(8)],
        fill=Luma(230),
        inset~,
      ),
    ])
    let blocks = compile(setup~, [
      @kit.Cards(
        items(five),
        columns~,
        gutter=[Pt(4)],
        row_gutter=[Pt(8)],
        fill=Luma(230),
        inset~,
        radius=round,
      ),
    ])
    assert_eq(errors(cells) + errors(blocks), "")
    assert_eq(cards(blocks), cards(cells))
    cards(cells)
  }
  // Two rows; the second has two cards and an open place, not an empty
  // card. Every row has the height of its own highest card.
  inspect(
    both(Sizing::repeat(3, size=Fr(1))),
    content=(
      #|p1 10.0,10.0 57.3x40.7
      #|p1 71.3,10.0 57.3x40.7
      #|p1 132.7,10.0 57.3x40.7
      #|p1 10.0,58.7 57.3x27.7
      #|p1 71.3,58.7 57.3x27.7
    ),
  )
  // (Why the look is on the cells and not on the grid: a grid fills the
  // cells that it adds to complete a row, which would be an empty card.)
  let filled = compile([
    Grid(
      items(["1", "2", "3"]),
      columns=Sizing::repeat(2, size=Fr(1)),
      fill=Cells::all(Luma(230)),
    ),
  ])
  assert_eq(cards(filled).split("\n").count(), 4)
  // Tracks of fixed, relative and fractional widths, with a gutter of
  // their own.
  inspect(
    both([Pt(30), Pct(25), Fr(1), Fr(2)]),
    content=(
      #|p1 10.0,10.0 30.0x40.7
      #|p1 44.0,10.0 45.0x40.7
      #|p1 93.0,10.0 31.0x40.7
      #|p1 128.0,10.0 62.0x40.7
      #|p1 10.0,58.7 30.0x66.9
    ),
  )
}

///|
test "cards: inside containers the measured rows are the rows of the grid" {
  // The width that the rows are measured at is the width that the grid
  // is laid out in: a block with an inset, a grid cell, a column, a pad.
  let setup = page(height=Pt(400))
  let inside = (wrap : (&IntoContent) -> &IntoContent) => {
    let cells = compile(setup~, [
      wrap(@kit.Cards(items(uneven), gutter=[Pt(4)], fill=Luma(230), inset~)),
    ])
    let blocks = compile(setup~, [
      wrap(
        @kit.Cards(
          items(uneven),
          gutter=[Pt(4)],
          fill=Luma(230),
          inset~,
          radius=round,
        ),
      ),
    ])
    assert_eq(errors(cells) + errors(blocks), "")
    assert_eq(warnings(cells) + warnings(blocks), "")
    assert_eq(cards(blocks), cards(cells))
    cards(cells).split("\n").map(line => line.to_owned()).collect()[1]
  }
  inspect(
    inside(body => body),
    content=(
      #|p1 71.3,10.0 57.3x66.9
    ),
  )
  inspect(
    inside(body => Block(body, width=Pt(150), inset=Sides(all=Pt(6)))),
    content=(
      #|p1 63.3,16.0 43.3x93.1
    ),
  )
  inspect(
    inside(body => Grid(["left", body], columns=[Pt(40), Fr(1)])),
    content=(
      #|p1 98.0,10.0 44.0x93.1
    ),
  )
  inspect(
    inside(body => Pad(body, x=Pt(15))),
    content=(
      #|p1 76.3,10.0 47.3x80.0
    ),
  )
  inspect(
    inside(body => Columns(body, count=2)),
    content=(
      #|p1 40.1,10.0 26.1x132.3
    ),
  )
}

///|
test "cards: at the end of a page" {
  let six = [
    "1",
    "2 two two two two two two two",
    "3",
    "4 " + "four ".repeat(22),
    "5",
    "6",
  ]
  let columns = Sizing::repeat(2, size=Fr(1))
  // With a radius a card is not split: the second row, of six lines, does
  // not fit the 46pt that are left, and moves to the next page as a whole.
  let blocks = compile([
    V(Pt(20)),
    @kit.Cards(
      items(six),
      columns~,
      gutter=[Pt(6)],
      fill=Luma(230),
      inset~,
      radius=round,
    ),
  ])
  inspect(errors(blocks), content="")
  inspect(warnings(blocks), content="")
  inspect(
    cards(blocks),
    content=(
      #|p1 10.0,30.0 87.0x27.7
      #|p1 103.0,30.0 87.0x27.7
      #|p2 10.0,10.0 87.0x80.0
      #|p2 103.0,10.0 87.0x80.0
      #|p3 10.0,10.0 87.0x14.6
      #|p3 103.0,10.0 87.0x14.6
    ),
  )
  // Without one the grid breaks the row as it breaks any row: the lines
  // that fit stay, and both cards of the row continue on the next page.
  let cells = compile([
    V(Pt(20)),
    @kit.Cards(items(six), columns~, gutter=[Pt(6)], fill=Luma(230), inset~),
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
test "cards: a row that is higher than the page" {
  let long = "word ".repeat(60)
  // The engine's fact: an unbreakable block that no page holds leaves the
  // page (finding S2), without a diagnostic.
  let unbreakable = compile([Block(long, width=Pt(60), breakable=false)])
  inspect(errors(unbreakable) + warnings(unbreakable), content="")
  assert_eq(pages(unbreakable), 1)
  assert_true(marks(unbreakable).iter().any(m => m.y > 120.0))
  // So the cards of such a row are breakable blocks of their own height:
  // everything is on a page, and the row is not equalized.
  let report = compile([
    @kit.Cards(
      items(["short", long, "after"]),
      columns=Sizing::repeat(2, size=Fr(1)),
      gutter=[Pt(6)],
      fill=Luma(230),
      inset~,
      radius=round,
    ),
  ])
  inspect(errors(report), content="")
  inspect(warnings(report), content="")
  assert_true(pages(report) > 1)
  for mark in marks(report) {
    assert_true(mark.y >= 10.0 && mark.y + mark.h <= 110.01)
  }
  inspect(
    cards(report),
    content=(
      #|p1 10.0,10.0 87.0x14.6
      #|p1 103.0,10.0 87.0x93.1
      #|p2 103.0,10.0 87.0x93.1
      #|p3 103.0,10.0 87.0x80.0
      #|p4 10.0,10.0 87.0x14.6
    ),
  )
  // The words are all there.
  let words = marks(report)
    .map(m => m.text.split(" ").filter(w => w == "word").count())
    .fold(init=0, (a, b) => a + b)
  assert_eq(words, 60)
}

///|
test "cards: in a region without a width" {
  // A page as wide as its content. Tracks of a fixed width: both forms
  // are the same cards.
  let wide = page(width=Auto)
  let both = (columns : Array[Sizing]) => {
    let cells = compile(
      [@kit.Cards(items(uneven), columns~, fill=Luma(230), inset~)],
      setup=wide,
    )
    let blocks = compile(
      [
        @kit.Cards(
          items(uneven),
          columns~,
          fill=Luma(230),
          inset~,
          radius=round,
        ),
      ],
      setup=wide,
    )
    assert_eq(errors(cells) + errors(blocks), "")
    assert_eq(cards(blocks), cards(cells))
    cards(cells)
  }
  inspect(
    both([Pt(50), Pt(70), Pt(50)]),
    content=(
      #|p1 10.0,10.0 50.0x53.8
      #|p1 60.0,10.0 70.0x53.8
      #|p1 130.0,10.0 50.0x53.8
    ),
  )
  // Fractional tracks have no width there, in any grid, so the cards
  // have none in either form (and their text is a letter per line).
  for radius in [None, Some(round)] {
    let report = compile(
      [@kit.Cards(["ab", "cd"], fill=Luma(230), radius?)],
      setup=wide,
    )
    assert_eq(errors(report), "")
    for card in marks(report).filter(m => m.text == "") {
      assert_eq(pt(card.w), "0.0")
    }
  }
}

///|
test "cards: with a radius it is a callback, and cannot be built inside one" {
  // Built inside a callback: the error of `Layout`, at the call.
  let line = line_here() + 1
  let inside = compile([Context(_ => @kit.Cards(["a", "b"], radius=round))])
  inspect(
    errors(inside),
    content="callbacks cannot be created inside a callback",
  )
  inspect(error_place(inside), content="Cards call")
  assert_eq(error_origin(inside).start_line, line)
  // Built before and captured: fine, also when it is used twice.
  let early = @kit.Cards(["a", "b"], fill=Luma(230), inset~, radius=round)
  let captured = compile([Context(_ => Seq([early, early]))])
  inspect(errors(captured), content="")
  inspect(warnings(captured), content="")
  assert_eq(cards(captured).split("\n").count(), 4)
  // Without a radius there is no callback: it can be built anywhere.
  let in_show = compile([
    Show(Select::heading()) <| ((it, _) => {
      @kit.Cards([it, "beside"], fill=Luma(230), inset~)
    }),
    Heading("Head"),
  ])
  inspect(errors(in_show), content="")
  assert_eq(cards(in_show).split("\n").count(), 2)
}

///|
test "cards: with a radius a column cannot be auto" {
  let line = line_here() + 2
  let auto = compile([
    @kit.Cards(["a", "b"], columns=[Auto, Fr(1)], radius=round),
  ])
  inspect(
    errors(auto),
    content="`Cards` with a `radius` cannot have an `Auto` column: its rows are measured one by one, and an `auto` column is as wide as the widest card of all rows",
  )
  inspect(error_place(auto), content="Cards call")
  assert_eq(error_origin(auto).start_line, line)
  // (No tracks are one `auto` column for the engine.)
  assert_eq(
    errors(compile([@kit.Cards(["a"], columns=[], radius=round)])),
    errors(auto),
  )
  assert_eq(
    errors(compile([@kit.Cards(["a"], columns=[Rel(Auto)], radius=round)])),
    errors(auto),
  )
  // Without a radius an `auto` column is the grid's.
  let cells = compile([
    @kit.Cards(["a", "wider"], columns=[Auto, Auto], fill=Luma(230), inset~),
  ])
  inspect(errors(cells), content="")
  inspect(
    cards(cells),
    content=(
      #|p1 10.0,10.0 12.6x14.6
      #|p1 22.6,10.0 31.4x14.6
    ),
  )
}

///|
test "cards: provenance, in both forms" {
  let own = Emph("stressed")
  let line = line_here() + 2
  let cells = compile([
    @kit.Cards(["plain", own, "plain"], fill=Luma(230), inset~),
  ])
  let line_rounded = line_here() + 2
  let blocks = compile([
    @kit.Cards(["plain", own, "plain"], fill=Luma(230), inset~, radius=round),
  ])
  for report in [cells, blocks] {
    inspect(errors(report), content="")
    // A string of the caller is the `items` argument under the key of its
    // card; a description of the caller is at its own call, under that
    // key too.
    inspect(
      text_args(report),
      content="plain: Cards a0 0 | stressed: Emph a0 1 | plain: Cards a0 2",
    )
  }
  // A click on a card, which the element drew: the call.
  for pair in [(cells, line), (blocks, line_rounded)] {
    let (report, line) = pair
    let card = marks(report).filter(m => m.text == "")[0]
    guard report.origin_at(1, card.x + card.w - 2.0, card.y + card.h - 2.0)
      is Some(origin) else {
      fail("no origin at the card")
    }
    // (The grid draws the fill of a cell, the card's block its own: the
    // second is under the card's key.)
    assert_eq(origin.kind, "Cards")
    assert_eq(origin.param, None)
    assert_eq(origin.start_line, line)
  }
  // Under a key of the caller.
  inspect(
    text_args(compile([Keyed("row", @kit.Cards(["a", "b"]))])),
    content="a: Cards a0 row/0 | b: Cards a0 row/1",
  )
  // An error in an argument is at that argument, with or without a
  // radius: every argument that is passed on.
  let stroke : Sides[Stroke] = Sides(
    all=Stroke(paint=Value(@doc.Value::str("x"))),
  )
  let failing : Array[(String, (Corners[@doc.Length]?) -> @kit.Cards)] = [
    ("columns", radius => @kit.Cards(["a"], columns=[None], radius?)),
    ("gutter", radius => @kit.Cards(["a"], gutter=[None], radius?)),
    (
      "column_gutter",
      radius => @kit.Cards(["a"], column_gutter=[None], radius?),
    ),
    ("row_gutter", radius => @kit.Cards(["a"], row_gutter=[None], radius?)),
    (
      "fill",
      radius => @kit.Cards(["a"], fill=Value(@doc.Value::str("x")), radius?),
    ),
    ("stroke", radius => @kit.Cards(["a"], stroke~, radius?)),
    ("inset", radius => @kit.Cards(["a"], inset=Sides::none(), radius?)),
  ]
  let places : Array[String] = []
  for entry in failing {
    let (name, build) = entry
    // (The messages are those of the primitives: of `grid.cell` and of
    // `block` for the look of a card.)
    let plain = compile([build(None)])
    let rounded = compile([build(Some(round))])
    assert_true(errors(plain) != "" && errors(rounded) != "")
    assert_eq(error_place(rounded), error_place(plain))
    places.push("\{name}: \{error_place(plain)}")
  }
  inspect(
    places.join(" | "),
    content=(
      #|columns: Cards a1 | gutter: Cards a2 | column_gutter: Cards a3 | row_gutter: Cards a4 | fill: Cards a5 0 | stroke: Cards a6 0 | inset: Cards a7 0
    ),
  )
  let radius = compile([@kit.Cards(["a"], radius=Corners(all=Auto))])
  inspect(
    errors(radius),
    content="expected relative length or dictionary, found auto",
  )
  inspect(
    error_place(radius),
    content=(
      #|Cards a8 0
    ),
  )
}
