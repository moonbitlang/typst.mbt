// What porting fourteen pages to the EDSL showed (docs/edsl-ports.md,
// sections 2.1 and 2.3): one test per finding, on a minimal synthetic
// document, that pins what happens today. The later steps of that
// proposal change these tests deliberately. The page of every test is
// 200pt by 120pt with 10pt margins and 10pt text (`small_page`), so the
// region is 180pt by 100pt; lengths are in points from the page's top left
// corner.

///|
/// Something on a page: a filled or stroked rectangle (`kind` is `"rect"`),
/// a line (`"line"`: `w` and `h` are its end relative to its start), or a
/// text run (`"text"`: `y` is its baseline, `w` its advance width, `h` is
/// 0).
priv struct Mark {
  page : Int
  kind : String
  x : Double
  y : Double
  w : Double
  h : Double
  /// The text of a run.
  text : String
  /// The glyph ids of a run.
  glyphs : Array[Int]
  /// The fill of a shape (`""`: none).
  fill : String
  /// The dash pattern of the stroke of a shape (`""`: solid or no stroke).
  dash : String
}

///|
/// The marks of a frame at `(dx, dy)` on the page `page`. (The documents of
/// these tests have no scaled or rotated groups: a group is a translation.)
fn collect_marks(
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
        collect_marks(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          page,
          out,
        )
      Text(text) =>
        out.push({
          page,
          kind: "text",
          x,
          y,
          w: text.width().to_pt(),
          h: 0.0,
          text: text.text,
          glyphs: text.glyphs.map(glyph => glyph.id.to_int()),
          fill: "",
          dash: "",
        })
      Shape(shape, _) => {
        let (kind, w, h) = match shape.geometry {
          Rect(size) => ("rect", size.x.to_pt(), size.y.to_pt())
          Line(to) => ("line", to.x.to_pt(), to.y.to_pt())
          Curve(_) => continue
        }
        let fill = match shape.fill {
          Some(paint) => paint.repr()
          None => ""
        }
        let dash = match shape.stroke {
          Some({ dash: Some(pattern), .. }) =>
            pattern.array.map(length => pt(length.to_pt())).join(" ")
          _ => ""
        }
        out.push({ page, kind, x, y, w, h, text: "", glyphs: [], fill, dash, })
      }
      _ => ()
    }
  }
}

///|
/// The marks of a compiled document, page by page (pages from 1).
fn marks(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[Mark] raise {
  let out = []
  for i, page in report.unwrap().pages() {
    collect_marks(page.frame, 0.0, 0.0, i + 1, out)
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
/// A listing of marks, one line each: the page, the kind, the position,
/// then the size (and fill, and dash pattern) of a shape, or the advance
/// width and the text of a run.
fn listing(marks : Array[Mark]) -> String {
  marks
  .map(m => {
    if m.kind == "text" {
      "p\{m.page} text \{pt(m.x)},\{pt(m.y)} w\{pt(m.w)} \{m.text.escape()}"
    } else {
      let fill = if m.fill == "" { "" } else { " \{m.fill}" }
      let dash = if m.dash == "" { "" } else { " dash \{m.dash}" }
      "p\{m.page} \{m.kind} \{pt(m.x)},\{pt(m.y)} \{pt(m.w)}x\{pt(m.h)}\{fill}\{dash}"
    }
  })
  .join("\n")
}

///|
/// The marks of one kind.
fn of_kind(marks : Array[Mark], kind : String) -> Array[Mark] {
  marks.filter(m => m.kind == kind)
}

///|
/// A page of 200pt by 120pt with 10pt margins and 10pt text.
fn small_page() -> Array[&@doc.IntoContent] {
  [
    @doc.SetPage(width=Pt(200), height=Pt(120), margin=@doc.Sides(all=Pt(10))),
    @doc.SetText(size=Pt(10)),
  ]
}

///|
/// The messages of the warnings of a report.
fn warning_messages(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String {
  report.warnings.map(w => w.message).join(" | ")
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
/// An origin without its position: `(Constructor, argument n)`.
fn what(origin : @doc.Origin) -> String {
  origin.describe().replace(old=origin.position() + " ", new="")
}

///|
/// The EDSL origin of the first trace point of a diagnostic.
fn origin_of_trace(diagnostic : @doc.Diagnostic) -> @doc.Origin raise {
  guard diagnostic.trace[0].location is Some(Edsl(origin)) else {
    fail("expected an EDSL location: \{diagnostic.render()}")
  }
  origin
}

// Section 2.1: wrong output without a diagnostic.

///|
test "S1: adjacent inline items are one paragraph with nothing between them" {
  let report = compile(
    [
      ..small_page(),
      @doc.Prose("One ends here."),
      @doc.Prose("Two starts here."),
      "Three.",
      @doc.Text("Four."),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  // One line of one paragraph: no space and no break between the items.
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w171.6 "One ends here.Two starts here.Three.Four."
    ),
  )
  // What separates them today: a paragraph each.
  let separate = compile(
    [
      ..small_page(),
      @doc.Par(@doc.Prose("One ends here.")),
      @doc.Par(@doc.Prose("Two starts here.")),
    ],
  )
  inspect(
    listing(marks(separate)),
    content=(
      #|p1 text 10.0,16.6 w60.8 "One ends here."
      #|p1 text 10.0,35.2 w65.4 "Two starts here."
    ),
  )
}

///|
/// Fifteen words: five lines of 10pt text in a width of 80pt, which need
/// 59pt (6.6pt for the first line, 13.1pt for each further one).
let five_lines : String = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen"

///|
test "S2a: a fixed-height block that is split at a page break does not hold its content" {
  let card = @doc.Block(five_lines, width=Pt(80), height=Pt(60), fill=Luma(220))
  // On one page the five baselines are inside the 60pt.
  let whole = compile([..small_page(), card])
  inspect(
    listing(marks(whole)),
    content=(
      #|p1 rect 10.0,10.0 80.0x60.0 luma(86.27%)
      #|p1 text 10.0,16.6 w76.4 "one two three four "
      #|p1 text 10.0,29.7 w77.8 "five six seven eight "
      #|p1 text 10.0,42.7 w62.4 "nine ten eleven "
      #|p1 text 10.0,55.8 w62.1 "twelve thirteen "
      #|p1 text 10.0,68.9 w63.2 "fourteen fifteen"
    ),
  )
  // With 30pt left on the page the block is split into 30pt and 30pt. Two
  // lines fit the first part (a third would need 32.8pt), so three lines
  // are left for the second part, which is 30pt high as well.
  let split = compile([..small_page(), @doc.V(Pt(70)), card])
  inspect(error_messages(split), content="")
  inspect(warning_messages(split), content="")
  inspect(
    listing(marks(split)),
    content=(
      #|p1 rect 10.0,80.0 80.0x30.0 luma(86.27%)
      #|p1 text 10.0,86.6 w76.4 "one two three four "
      #|p1 text 10.0,99.7 w77.8 "five six seven eight "
      #|p2 rect 10.0,10.0 80.0x30.0 luma(86.27%)
      #|p2 text 10.0,16.6 w62.4 "nine ten eleven "
      #|p2 text 10.0,29.7 w62.1 "twelve thirteen "
      #|p2 text 10.0,42.7 w63.2 "fourteen fifteen"
    ),
  )
  // The baseline of the last line is below the second part.
  let all = marks(split)
  let part = of_kind(all, "rect")[1]
  let last = of_kind(all, "text")[4]
  assert_eq(last.page, part.page)
  assert_true(last.y > part.y + part.h)
}

///|
test "S2b: a block or a box with a fixed height does not grow" {
  let words = "one two three four five six seven eight nine ten eleven twelve"
  let block = compile(
    [
      ..small_page(),
      @doc.Block(words, width=Pt(80), height=Pt(20), fill=Luma(220)),
    ],
  )
  inspect(error_messages(block), content="")
  inspect(warning_messages(block), content="")
  inspect(
    listing(marks(block)),
    content=(
      #|p1 rect 10.0,10.0 80.0x20.0 luma(86.27%)
      #|p1 text 10.0,16.6 w76.4 "one two three four "
      #|p1 text 10.0,29.7 w77.8 "five six seven eight "
      #|p1 text 10.0,42.7 w62.4 "nine ten eleven "
      #|p1 text 10.0,55.8 w27.0 "twelve"
    ),
  )
  let box = compile(
    [
      ..small_page(),
      @doc.Box(words, width=Pt(80), height=Pt(20), fill=Luma(220)),
    ],
  )
  inspect(error_messages(box), content="")
  inspect(warning_messages(box), content="")
  // The same marks: the baselines of the last two of the four lines are
  // below the rectangle.
  assert_eq(listing(marks(box)), listing(marks(block)))
  for report in [block, box] {
    let all = marks(report)
    let frame = of_kind(all, "rect")[0]
    let below = of_kind(all, "text").filter(line => line.y > frame.y + frame.h)
    assert_eq(below.length(), 2)
  }
}

///|
test "S3: `Block(height=Pct(100))` in a grid cell takes the height of the region" {
  let report = compile(
    [
      ..small_page(),
      "Before.",
      @doc.Grid(
        [
          @doc.Block("a", width=Pct(100), height=Pct(100), fill=Luma(220)),
          @doc.Block("b", width=Pct(100), height=Pct(100), fill=Luma(200)),
        ],
        columns=[Fr(1), Fr(1)],
      ),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  // 100% is the height of the region (100pt), not of the row: each card
  // is 81.4pt on the first page, where that much was left, and 18.6pt on
  // a second page. Nothing is out of bounds.
  assert_eq(report.unwrap().pages().length(), 2)
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w28.7 "Before."
      #|p1 rect 10.0,28.6 90.0x81.4 luma(86.27%)
      #|p1 text 10.0,35.2 w4.6 "a"
      #|p1 rect 100.0,28.6 90.0x81.4 luma(78.43%)
      #|p1 text 100.0,35.2 w4.9 "b"
      #|p2 rect 10.0,10.0 90.0x18.6 luma(86.27%)
      #|p2 rect 100.0,10.0 90.0x18.6 luma(78.43%)
    ),
  )
}

///|
test "S4: a character no font covers is glyph 0, without a warning" {
  // The embedded fonts have no CJK glyphs.
  let report = compile([..small_page(), "ab\u{4e2d}cd"])
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  let runs = of_kind(marks(report), "text").map(run => {
    "\{run.text.escape()} \{run.glyphs.map(id => id.to_string()).join(",")}"
  })
  inspect(
    runs.join(" | "),
    content=(
      #|"ab" 66,67 | "中" 0 | "cd" 68,69
    ),
  )
  // A font family that does not exist is reported; a glyph that does not
  // exist is not.
  let family = compile(
    [..small_page(), @doc.Text("ab", font=["No Such Family"])],
  )
  inspect(
    warning_messages(family),
    content=(
      #|unknown font family: no such family
    ),
  )
  inspect(
    what(origin_of(family.warnings[0])),
    content=(
      #|(Text, argument 2)
    ),
  )
}

///|
test "S5: a long word of inline raw text does not break and leaves its table cell" {
  let report = compile(
    [
      ..small_page(),
      @doc.Table(
        [@doc.Raw("a_long_identifier_without_a_break"), "b"],
        columns=[Pt(60), Pt(60)],
        fill=@doc.Cells::all(Luma(230)),
      ),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(
    listing(marks(report)),
    content=(
      #|p1 rect 10.0,10.0 60.0x16.6 luma(90.2%)
      #|p1 rect 70.0,10.0 60.0x16.6 luma(90.2%)
      #|p1 line 10.0,9.5 0.0x17.6
      #|p1 line 70.0,9.5 0.0x17.6
      #|p1 line 130.0,9.5 0.0x17.6
      #|p1 line 9.5,10.0 121.0x0.0
      #|p1 line 9.5,26.6 121.0x0.0
      #|p1 text 15.0,21.1 w158.9 "a_long_identifier_without_a_break"
      #|p1 text 75.0,21.6 w4.9 "b"
    ),
  )
  // The run ends to the right of its cell (and of the table).
  let all = marks(report)
  let cells = of_kind(all, "rect")
  let run = of_kind(all, "text")[0]
  assert_true(run.x + run.w > cells[0].x + cells[0].w)
  assert_true(run.x + run.w > cells[1].x + cells[1].w)
  // Raw text is not hyphenated, but it breaks where text may break: at a
  // space, and so at a zero-width space (U+200B), which stays a character
  // of the run's text.
  let spaced = compile(
    [
      ..small_page(),
      @doc.Table([@doc.Raw("a long name with breaks"), "b"], columns=[
        Pt(60),
        Pt(60),
      ]),
    ],
  )
  inspect(
    of_kind(marks(spaced), "text")
    .filter(run => run.text != "b")
    .map(run => run.text)
    .join("|"),
    content=(
      #|a long |name with |breaks
    ),
  )
  let broken = compile(
    [
      ..small_page(),
      @doc.Table(
        [@doc.Raw("a_long_\u{200B}name_\u{200B}with_\u{200B}breaks"), "b"],
        columns=[Pt(60), Pt(60)],
        fill=@doc.Cells::all(Luma(230)),
      ),
    ],
  )
  let all = marks(broken)
  let cell = of_kind(all, "rect")[0]
  let runs = of_kind(all, "text").filter(run => run.text != "b")
  inspect(
    runs.map(run => run.text.replace_all(old="\u{200B}", new="")).join("|"),
    content=(
      #|a_long_|name_with_|breaks
    ),
  )
  for run in runs {
    assert_true(run.x + run.w < cell.x + cell.w)
  }
}

///|
test "S6: `Prose` turns `'` after a digit into a prime" {
  let line = (item : &@doc.IntoContent) => {
    of_kind(marks(compile([..small_page(), item])), "text")
    .map(run => run.text)
    .join("")
  }
  // Typst's smart quotes: an apostrophe after a letter, a prime after a
  // digit.
  inspect(
    line(@doc.Prose("it's issue #1770's fix")),
    content=(
      #|it’s issue #1770′s fix
    ),
  )
  // Without smart quotes, and in a plain string, the character stays.
  inspect(
    line(@doc.Prose("it's issue #1770's fix", quotes=false)),
    content=(
      #|it's issue #1770's fix
    ),
  )
  inspect(
    line("it's issue #1770's fix"),
    content=(
      #|it's issue #1770's fix
    ),
  )
  // The typographic apostrophe is kept as written.
  inspect(
    line(@doc.Prose("issue #1770’s fix")),
    content=(
      #|issue #1770’s fix
    ),
  )
}

// Section 2.3: typed API gaps, with the way around each that works today.

///|
test "T1: `Box` has no typed `baseline`; `outset` and `extra` are the ways around" {
  // (`box.baseline` is in doc/elements_coverage.txt: unmapped type.)
  let line = (chip : @doc.Box) => {
    listing(marks(compile([..small_page(), @doc.Par(@doc.Seq(["Mg ", chip]))])))
  }
  // Insets on all sides: the text of the chip stays on the baseline, and
  // the line is 3pt higher and 3pt deeper (its baseline is at 19.6pt
  // instead of 16.6pt).
  inspect(
    line(@doc.Box("chip", fill=Luma(220), inset=@doc.Sides(x=Pt(3), y=Pt(3)))),
    content=(
      #|p1 text 10.0,19.6 w15.9 "Mg "
      #|p1 rect 25.9,10.0 23.6x12.6 luma(86.27%)
      #|p1 text 28.9,19.6 w17.6 "chip"
    ),
  )
  // The vertical padding as an outset: the same rectangle around the text,
  // and the line keeps its height.
  inspect(
    line(
      @doc.Box(
        "chip",
        fill=Luma(220),
        inset=@doc.Sides(x=Pt(3)),
        outset=@doc.Sides(y=Pt(3)),
      ),
    ),
    content=(
      #|p1 text 10.0,16.6 w15.9 "Mg "
      #|p1 rect 25.9,7.0 23.6x12.6 luma(86.27%)
      #|p1 text 28.9,16.6 w17.6 "chip"
    ),
  )
  // `baseline` through `extra`: the box is moved down by that much.
  inspect(
    line(
      @doc.Box("chip", fill=Luma(220), extra=[
        ("baseline", @doc.Value::length(Pt(3))),
      ]),
    ),
    content=(
      #|p1 text 10.0,16.6 w15.9 "Mg "
      #|p1 rect 25.9,13.0 17.6x6.6 luma(86.27%)
      #|p1 text 25.9,19.6 w17.6 "chip"
    ),
  )
}

///|
test "T2: `top-edge` and `bottom-edge` are reachable through `extra`" {
  // (`text.top-edge`, `highlight.top-edge` and the bottom edges are in
  // doc/elements_coverage.txt: unmapped types.)
  let shown = (item : &@doc.IntoContent) => {
    listing(marks(compile([..small_page(), @doc.Par(item)])))
  }
  // A highlight is as high as the text's ascender and descender ...
  inspect(
    shown(@doc.Highlight("xo")),
    content=(
      #|p1 rect 10.0,7.6 9.9x11.4 rgb("#fffd11a1")
      #|p1 text 10.0,16.6 w9.9 "xo"
    ),
  )
  // ... or as the edges say.
  inspect(
    shown(
      @doc.Highlight("xo", extra=[
        ("top-edge", @doc.Value::str("x-height")),
        ("bottom-edge", @doc.Value::str("baseline")),
      ]),
    ),
    content=(
      #|p1 rect 10.0,12.3 9.9x4.3 rgb("#fffd11a1")
      #|p1 text 10.0,16.6 w9.9 "xo"
    ),
  )
  // The edges of text decide the height of its line: of a box around it.
  inspect(
    shown(@doc.Box(@doc.Text("xo"), fill=Luma(220))),
    content=(
      #|p1 rect 10.0,10.0 9.9x6.6 luma(86.27%)
      #|p1 text 10.0,16.6 w9.9 "xo"
    ),
  )
  inspect(
    shown(
      @doc.Box(
        @doc.Text("xo", extra=[
          ("top-edge", @doc.Value::str("bounds")),
          ("bottom-edge", @doc.Value::str("bounds")),
        ]),
        fill=Luma(220),
      ),
    ),
    content=(
      #|p1 rect 10.0,10.0 9.9x4.5 luma(86.27%)
      #|p1 text 10.0,14.4 w9.9 "xo"
    ),
  )
  // A wrong name is the engine's cast error, at the `extra` argument.
  let wrong = compile([
    @doc.Text("xo", extra=[("top-edge", @doc.Value::str("descender"))]),
  ])
  inspect(
    error_messages(wrong),
    content=(
      #|expected "ascender", "cap-height", "x-height", "baseline", "bounds", or length
    ),
  )
  inspect(
    what(origin_of(wrong.errors[0])),
    content=(
      #|(Text, argument 25)
    ),
  )
}

///|
test "T3: the dash of a `Stroke` is a `Value`" {
  let report = compile(
    [
      ..small_page(),
      @doc.Line(
        length=Pt(50),
        stroke=@doc.Stroke(thickness=Pt(1), dash=@doc.Value::str("dotted")),
      ),
      @doc.Line(
        length=Pt(50),
        stroke=@doc.Stroke(
          thickness=Pt(1),
          dash=@doc.Value::array([
            @doc.Value::length(Pt(4)),
            @doc.Value::length(Pt(2)),
          ]),
        ),
      ),
    ],
  )
  inspect(error_messages(report), content="")
  // `"dotted"` is a dash as long as the line is wide (1pt) and a gap of
  // 2pt.
  inspect(
    listing(marks(report)),
    content=(
      #|p1 line 10.0,10.0 50.0x0.0 dash 1.0 2.0
      #|p1 line 10.0,22.0 50.0x0.0 dash 4.0 2.0
    ),
  )
  // A name that is no dash pattern is an error when the document is
  // compiled, at the argument that holds the stroke.
  let wrong = compile([
    @doc.Line(stroke=@doc.Stroke(dash=@doc.Value::str("dots"))),
  ])
  inspect(
    error_messages(wrong),
    content=(
      #|expected "solid", "dotted", "densely-dotted", "loosely-dotted", "dashed", "densely-dashed", "loosely-dashed", "dash-dotted", "densely-dash-dotted", "loosely-dash-dotted", array, dictionary, none, or auto
    ),
  )
  inspect(
    what(origin_of(wrong.errors[0])),
    content=(
      #|(Line, argument 5)
    ),
  )
}

///|
test "T4: colour operations are calls of Typst's functions on a `Value`" {
  let swatch = (fill : @doc.Paint) => {
    @doc.Rect(width=Pt(20), height=Pt(10), fill~)
  }
  let teal : @doc.Paint = Rgb("#1d7586")
  let report = compile(
    [
      ..small_page(),
      // What the ports wrote: the alpha as two more hex digits.
      swatch(Rgb("#1d758680")),
      // Typst's own operations, through the generic call.
      swatch(
        Value(
          @doc.Value::call("color.transparentize", positional=[
            @doc.Value::paint(teal),
            @doc.Value::length(Pct(50)),
          ]),
        ),
      ),
      swatch(
        Value(
          @doc.Value::call("color.mix", positional=[
            @doc.Value::paint(teal),
            @doc.Value::paint(White),
          ]),
        ),
      ),
      swatch(
        Value(
          @doc.Value::call(
            "color.mix",
            positional=[@doc.Value::paint(teal), @doc.Value::paint(White)],
            named=[("space", @doc.Value::global("rgb"))],
          ),
        ),
      ),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(
    of_kind(marks(report), "rect").map(rect => rect.fill).join("\n"),
    content=(
      #|rgb("#1d758680")
      #|rgb("#1d758680")
      #|oklab(76.01%, -0.034, -0.023)
      #|rgb("#8ebac3")
    ),
  )
}

///|
test "T5: the size of the enclosing region is only known to Typst source" {
  // There is no `Layout`: a `Context` callback has the location and the
  // styles, and `measure` asks for the size of content, not of the region.
  // Embedded Typst source can ask.
  let report = compile(
    [
      ..small_page(),
      @doc.Markup("#layout(size => [#size.width by #size.height])"),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(
    of_kind(marks(report), "text").map(run => run.text).join(""),
    content=(
      #|180pt by 100pt
    ),
  )
}

///|
test "T6: a composed length is a `Sizing` or a `Spacing` through `Rel`" {
  // `Length`, `Sizing` and `Spacing` are three enums with the same cases;
  // a `Length` value (a sum, or the result of a helper) becomes one of
  // the others with `Rel(..)`.
  let half : @doc.Length = Pct(50) - Pt(10)
  let gap : @doc.Length = Pt(11) + Em(0.5)
  let bar = @doc.Rect(width=Pct(100), height=Pt(5), fill=Luma(200))
  let report = compile(
    [
      ..small_page(),
      @doc.Grid([bar, bar], columns=[Rel(half), Fr(1)]),
      @doc.Block(bar, above=Rel(gap)),
    ],
  )
  inspect(error_messages(report), content="")
  // The first column is 50% of 180pt less 10pt; the block is 11pt and half
  // of the 10pt font size below the grid.
  inspect(
    listing(marks(report)),
    content=(
      #|p1 rect 10.0,10.0 80.0x5.0 luma(78.43%)
      #|p1 rect 90.0,10.0 100.0x5.0 luma(78.43%)
      #|p1 rect 10.0,31.0 180.0x5.0 luma(78.43%)
    ),
  )
}

///|
test "T7: upper case of content is `Call(\"upper\", ..)`" {
  let report = compile(
    [
      ..small_page(),
      @doc.Call("upper", positional=[
        @doc.Value::content(@doc.Seq(["quiet ", @doc.Emph("words")])),
      ]),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w30.6 "QUIET "
      #|p1 text 40.6,16.6 w32.2 "WORDS"
    ),
  )
}

///|
test "T8: `Sides::none()` as an inset is an error at the argument" {
  let block = compile([@doc.Block("a", inset=@doc.Sides::none())])
  inspect(
    error_messages(block),
    content=(
      #|expected relative length or dictionary, found none
    ),
  )
  // The eighth parameter of `Block` is `inset`.
  inspect(
    what(origin_of(block.errors[0])),
    content=(
      #|(Block, argument 8)
    ),
  )
  // Other fields say what they accept.
  let table = compile([
    @doc.Table(["a"], inset=@doc.Cells::all(@doc.Sides::none())),
  ])
  inspect(
    error_messages(table),
    content=(
      #|expected relative length, dictionary, array, or function, found none
    ),
  )
  inspect(
    what(origin_of(table.errors[0])),
    content=(
      #|(Table, argument 7)
    ),
  )
  let page = compile([@doc.SetPage(margin=@doc.Sides::none()), "a"])
  inspect(
    error_messages(page),
    content=(
      #|expected relative length, auto, or dictionary, found none
    ),
  )
  inspect(
    what(origin_of(page.errors[0])),
    content=(
      #|(SetPage, argument 5)
    ),
  )
  // No inset is a length of zero.
  let zero = compile(
    [
      ..small_page(),
      @doc.Block("a", inset=@doc.Sides(all=Pt(0)), fill=Luma(220)),
    ],
  )
  inspect(
    listing(marks(zero)),
    content=(
      #|p1 rect 10.0,10.0 4.6x6.6 luma(86.27%)
      #|p1 text 10.0,16.6 w4.6 "a"
    ),
  )
}

///|
test "T9: an outline without a title is `title=NoneValue()`" {
  let texts = (outline : @doc.Outline) => {
    of_kind(marks(compile([..small_page(), outline])), "text")
    .map(run => run.text)
    .join("|")
  }
  inspect(
    texts(@doc.Outline()),
    content=(
      #|Contents
    ),
  )
  inspect(texts(@doc.Outline(title=@doc.NoneValue())), content="")
  // A value in a content position is passed as that value, so this is the
  // same `none`.
  inspect(texts(@doc.Outline(title=@doc.Value::none())), content="")
}

///|
/// The table helper of the slide deck: rows with a striped fill, the
/// stroke given by the caller.
fn striped(
  rows : Array[&@doc.IntoContent],
  stroke : @doc.Cells[@doc.Sides[@doc.Stroke]],
) -> @doc.Seq {
  @doc.Seq([
    @doc.SetText(size=Pt(18)),
    @doc.Table(
      rows,
      columns=[Auto],
      inset=@doc.Cells::all(@doc.Sides(x=Pt(14), y=Pt(9))),
      fill=@doc.Cells((_, y) => if y % 2 == 1 { Luma(230) } else { None }),
      stroke~,
    ),
  ])
}

///|
test "T10: `Stroke(paint=None)` in a table is an error with a location" {
  // The report was an error without a source location. It did not
  // reproduce: every way of passing the stroke gives a located error, at
  // the nearest argument that has a location (`Stroke`, `Sides` and
  // `Cells::all` are values and have none of their own).
  let message = "expected color, gradient, tiling, or auto, found none"
  let bad = @doc.Stroke(paint=None)
  // In `Cells::all`: the `stroke` argument of the table.
  let before = line_here()
  let all = compile([
    @doc.Table(["a"], stroke=@doc.Cells::all(@doc.Sides(all=bad))),
  ])
  let after = line_here()
  assert_eq(error_messages(all), message)
  let origin = origin_of(all.errors[0])
  inspect(
    what(origin),
    content=(
      #|(Table, argument 10)
    ),
  )
  assert_true(before < origin.start_line && origin.start_line < after)
  // In a `Cells` callback: the callback, called by the table.
  let before = line_here()
  let each = compile([
    @doc.Table(["a"], stroke=@doc.Cells((_, _) => @doc.Sides(all=bad))),
  ])
  let after = line_here()
  assert_eq(error_messages(each), message)
  let origin = origin_of(each.errors[0])
  inspect(
    what(origin),
    content=(
      #|(Cells)
    ),
  )
  assert_true(before < origin.start_line && origin.start_line < after)
  inspect(
    each.errors[0].trace.map(point => point.description).join(" | "),
    content=(
      #|while calling `table`
    ),
  )
  inspect(
    what(origin_of_trace(each.errors[0])),
    content=(
      #|(Table)
    ),
  )
  // Per column, one side, a cell, a rule and a set rule.
  let others : Array[Array[&@doc.IntoContent]] = [
    [@doc.Table(["a"], stroke=@doc.Cells::columns([@doc.Sides(all=bad)]))],
    [@doc.Table(["a"], stroke=@doc.Cells::all(@doc.Sides(bottom=bad)))],
    [@doc.Table([@doc.TableCell("a", stroke=@doc.Sides(all=bad))])],
    [@doc.Table([@doc.TableHline(stroke=bad), "a"])],
    [
      @doc.SetTable(stroke=@doc.Cells::all(@doc.Sides(all=bad))),
      @doc.Table(["a"]),
    ],
  ]
  let places = []
  for children in others {
    let report = compile(children)
    assert_eq(error_messages(report), message)
    places.push(what(origin_of(report.errors[0])))
  }
  inspect(
    places.join(" | "),
    content=(
      #|(Table, argument 10) | (Table, argument 10) | (TableCell, argument 9) | (TableHline, argument 4) | (SetTable, argument 9)
    ),
  )
  // Through a helper (the deck's, in a sequence after a set rule): the
  // location is where the helper passes the stroke on, not where the
  // stroke was written.
  let before = line_here()
  let helped = compile([striped(["a"], @doc.Cells::all(@doc.Sides(all=bad)))])
  assert_eq(error_messages(helped), message)
  let origin = origin_of(helped.errors[0])
  inspect(
    what(origin),
    content=(
      #|(Table, argument 10)
    ),
  )
  assert_true(origin.start_line < before)
  // In the result of a callback the location is the argument, too.
  let shown = compile([
    @doc.Show(@doc.Select::heading()) <| ((it, _) => {
      @doc.Table([it], stroke=@doc.Cells::all(@doc.Sides(all=bad)))
    }),
    @doc.Heading("a"),
  ])
  assert_eq(error_messages(shown), message)
  inspect(
    what(origin_of(shown.errors[0])),
    content=(
      #|(Table, argument 10)
    ),
  )
  // An export of the failed compilation reports the same location.
  assert_eq(all.pdf().errors[0].render(), all.errors[0].render())
  // What was meant: no stroke.
  let none = compile([
    @doc.Table(
      ["a"],
      stroke=@doc.Cells::all(@doc.Sides(all=@doc.Stroke::none())),
    ),
  ])
  inspect(error_messages(none), content="")
}

///|
test "T11: `Ctx::measure` gives a width and a height, no baseline" {
  let sizes : Array[String] = []
  let note = (size : String) => if !sizes.contains(size) { sizes.push(size) }
  let report = compile(
    [
      ..small_page(),
      @doc.Context() <| cx => {
        // All fields of `Size`: a pattern that leaves one out is a warning
        // (`missing_pattern_field`), which `moon check --deny-warn` rejects.
        let { width, height, } = cx.measure("Mg")
        note("text \{pt(width)}x\{pt(height)}")
        let { width, height, } = cx.measure(
          @doc.Box("Mg", inset=@doc.Sides(y=Pt(3))),
        )
        note("box \{pt(width)}x\{pt(height)}")
        ""
      },
    ],
  )
  inspect(error_messages(report), content="")
  // The height of text is from its top edge (the cap height) to its
  // bottom edge (the baseline). Where the baseline is in a box with
  // insets, or in any other content, is not in the result.
  inspect(
    sizes.join(" | "),
    content=(
      #|text 13.4x6.6 | box 13.4x12.6
    ),
  )
}
