// `Chip` (docs/edsl-ports.md, section 4; finding H4): what it expands to,
// that its label is on the baseline of its line and the line as high as
// without it, that a label of several words stays on one line, and the
// provenance of its parts. The pair with a Typst twin is in
// `doc/twins/kit.mbt`. The page is that of `cards_test.mbt`: 200pt by
// 120pt with 10pt margins and 10pt text.

///|
using @doc {type Box, type Par, type Strong, type Table, type Text}

///|
/// The fill of the chips of these tests.
let soft : @doc.Paint = Luma(220)

///|
test "chip: a box with the padding to the sides as inset, above and below as outset" {
  // The expansion. The spaces of the label are no-break spaces.
  assert_eq(
    lowered([@kit.Chip("needs review", fill=soft)]),
    lowered([
      Box(
        "needs\u{00A0}review",
        fill=soft,
        inset=Sides(x=Em(0.6)),
        outset=Sides(y=Em(0.3)),
      ),
    ]),
  )
  // The look and the paddings are passed on.
  let outline : Sides[Stroke] = Sides(all=Stroke(thickness=Pt(0.5)))
  assert_eq(
    lowered([
      @kit.Chip(
        "ok",
        fill=soft,
        stroke=outline,
        radius=round,
        inset=Sides(x=Pt(4)),
        outset=Sides(y=Pt(2), right=Pt(1)),
      ),
    ]),
    lowered([
      Box(
        "ok",
        fill=soft,
        stroke=outline,
        radius=round,
        inset=Sides(x=Pt(4)),
        outset=Sides(y=Pt(2), right=Pt(1)),
      ),
    ]),
  )
  // Around content: the same box, and the content as it is.
  assert_eq(
    lowered([@kit.Chip::of(Seq([Strong("3"), " to do"]), fill=soft)]),
    lowered([
      Box(
        Seq([Strong("3"), " to do"]),
        fill=soft,
        inset=Sides(x=Em(0.6)),
        outset=Sides(y=Em(0.3)),
      ),
    ]),
  )
  // It prints as its name around what it is made of.
  debug_inspect(
    @kit.Chip("to do", fill=Red),
    content=(
      #|Chip(Box("to do", fill=red, inset={ "x": 0.6em }, outset={ "y": 0.3em }))
    ),
  )
}

///|
test "chip: the label is on the baseline of its line, and the line keeps its height" {
  // Three lines of text, with and without a chip in the second.
  let words = "word ".repeat(7)
  let with_chip = compile([
    Par(Seq([words, @kit.Chip("chip", fill=soft), " ", words, words])),
  ])
  let without = compile([Par(Seq([words, "chip", " ", words, words]))])
  inspect(errors(with_chip) + warnings(with_chip), content="")
  inspect(
    listing(drawn(with_chip)),
    content=(
      #|p1 text 10.0,16.6 10.0pt "word word word word word word word "
      #|p1 box 10.0,20.1 29.6x12.6 luma(86.27%)
      #|p1 text 16.0,29.7 10.0pt "chip"
      #|p1 text 39.6,29.7 10.0pt " word word word word word word "
      #|p1 text 10.0,42.7 10.0pt "word word word word word word word "
      #|p1 text 10.0,55.8 10.0pt "word "
    ),
  )
  // The baselines of the lines are those of the paragraph without the
  // chip: the chip does not make its line higher.
  let baselines = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    let out : Array[String] = []
    for run in of_kind(drawn(report), "text") {
      if !out.contains(pt(run.y)) {
        out.push(pt(run.y))
      }
    }
    out.join(" ")
  }
  inspect(
    baselines(with_chip),
    content=(
      #|16.6 29.7 42.7 55.8
    ),
  )
  assert_eq(baselines(with_chip), baselines(without))
  // The label is on the baseline of the words before it.
  let runs = of_kind(drawn(with_chip), "text")
  let label = runs.filter(run => run.text == "chip")[0]
  let line = runs.filter(run => run.y == label.y)
  assert_true(line.length() > 1)
  // The box is the label with its paddings: 6pt to each side, 3pt above
  // the top of the letters and below the baseline.
  let box = of_kind(drawn(with_chip), "box")[0]
  assert_eq(pt(box.x), pt(label.x - 6.0))
  assert_eq(pt(box.w), pt(label.w + 12.0))
  assert_eq(pt(box.y + box.h), pt(label.y + 3.0))
  // What a box with the padding as its inset does instead (finding T1):
  // the line with it is 3pt lower, and the lines after it too.
  let inset = compile([
    Par(
      Seq([
        words,
        Box("chip", fill=soft, inset=Sides(x=Em(0.6), y=Em(0.3))),
        " ",
        words,
        words,
      ]),
    ),
  ])
  inspect(
    baselines(inset),
    content=(
      #|16.6 32.7 48.7 61.8
    ),
  )
}

///|
test "chip: a label of several words stays on one line in a narrow column" {
  // A column of 70pt, of which a cell's inset leaves 60pt.
  let in_cell = (chip : &IntoContent) => {
    compile([Table([chip, "next"], columns=[Pt(70), Fr(1)])])
  }
  // A box is laid out in the width of its line: the label is broken
  // inside it.
  let box = in_cell(
    Box(
      "awaiting a second review",
      fill=soft,
      inset=Sides(x=Em(0.6)),
      outset=Sides(y=Em(0.3)),
    ),
  )
  inspect(
    lines_of_text(box),
    content=(
      #|p1 21.0,21.6 "awaiting a "
      #|p1 21.0,34.7 "second "
      #|p1 21.0,47.7 "review"
      #|p1 85.0,21.6 "next"
    ),
  )
  // The chip with that label is one line, and its row is one line high.
  let chip = in_cell(@kit.Chip("awaiting a second review", fill=soft))
  inspect(errors(chip) + warnings(chip), content="")
  inspect(
    listing(drawn(chip)),
    content=(
      #|p1 line 10.0,9.5 0.0x17.6 1.0 luma(0%)
      #|p1 line 80.0,9.5 0.0x17.6 1.0 luma(0%)
      #|p1 line 190.0,9.5 0.0x17.6 1.0 luma(0%)
      #|p1 line 9.5,10.0 181.0x0.0 1.0 luma(0%)
      #|p1 line 9.5,26.6 181.0x0.0 1.0 luma(0%)
      #|p1 box 15.0,12.0 60.0x12.6 luma(86.27%)
      #|p1 text 21.0,21.6 10.0pt "awaiting~a~second~review"
      #|p1 text 85.0,21.6 10.0pt "next"
    ),
  )
  let label = of_kind(drawn(chip), "text").filter(run => run.text != "next")
  assert_eq(label.length(), 1)
  // A label that is wider than its column runs out of it: the box is as
  // wide as the line (the cell without its inset), and the text goes on.
  let pill = of_kind(drawn(chip), "box")[0]
  assert_eq(pt(pill.w), "60.0")
  assert_true(label[0].x + label[0].w > pill.x + pill.w)
  // In an `Auto` column the column is as wide as the chip.
  let auto = compile([
    Table([@kit.Chip("awaiting a second review", fill=soft), "next"], columns=[
      Auto,
      Fr(1),
    ]),
  ])
  inspect(
    listing(drawn(auto)),
    content=(
      #|p1 line 10.0,9.5 0.0x17.6 1.0 luma(0%)
      #|p1 line 135.5,9.5 0.0x17.6 1.0 luma(0%)
      #|p1 line 190.0,9.5 0.0x17.6 1.0 luma(0%)
      #|p1 line 9.5,10.0 181.0x0.0 1.0 luma(0%)
      #|p1 line 9.5,26.6 181.0x0.0 1.0 luma(0%)
      #|p1 box 15.0,12.0 115.5x12.6 luma(86.27%)
      #|p1 text 21.0,21.6 10.0pt "awaiting~a~second~review"
      #|p1 text 140.5,21.6 10.0pt "next"
    ),
  )
  let pill = of_kind(drawn(auto), "box")[0]
  let label = of_kind(drawn(auto), "text")[0]
  assert_eq(pt(label.x + label.w + 6.0), pt(pill.x + pill.w))
  // Content is not changed: the body of `Chip::of` is broken like that of
  // the box.
  let content = in_cell(
    @kit.Chip::of(Text("awaiting a second review"), fill=soft),
  )
  assert_eq(lines_of_text(content), lines_of_text(box))
  // Only spaces are changed. A label is still broken where text breaks
  // without a space: after a hyphen.
  let hyphens = in_cell(@kit.Chip("awaiting-a-second-review", fill=soft))
  inspect(
    lines_of_text(hyphens),
    content=(
      #|p1 21.0,21.6 "awaiting-a-"
      #|p1 21.0,34.7 "second-"
      #|p1 21.0,47.7 "review"
      #|p1 85.0,21.6 "next"
    ),
  )
}

///|
test "chip: a selection in the label, with and without the source" {
  let report = compile([Par(@kit.Chip("done")), Par(@kit.Chip("to do"))])
  inspect(errors(report), content="")
  // A selection in a label is the `text` argument: as a whole while the
  // source file is not read.
  let text = report.review_text(title="Test")
  let entry = (review : @doc.ReviewText, word : String) => {
    // ("do" is in "done" first.)
    let nth = if word == "do" { 1 } else { 0 }
    review.feedback(review.find(word, nth~).unwrap(), "").origins[0]
  }
  // The argument, the tier, and the characters of the source with their
  // place in the literal (its opening quote is 0).
  let seen = (review : @doc.ReviewText, word : String) => {
    let found = entry(review, word)
    let source = found.source_ranges.map(range => {
      " \{range.text} at \{range.start - found.origin.start_column}"
    })
    "\{place(found.origin)}: tier \{found.tier}\{source.join("")}"
  }
  inspect(
    seen(text, "done"),
    content=(
      #|Chip a0: tier 2
    ),
  )
  inspect(
    seen(text, "do"),
    content=(
      #|Chip a0: tier 2
    ),
  )
  // With the source: the characters of the literal, also for a label whose
  // spaces are no-break spaces on the page.
  // (The file as far as it is read: the two literals where their origins
  // say they are, on one line or on two.)
  let lines : Array[String] = []
  for word in ["done", "do"] {
    let origin = entry(text, word).origin
    while lines.length() < origin.start_line {
      lines.push("")
    }
    let literal = if word == "done" { "\"done\"" } else { "\"to do\"" }
    let line = lines[origin.start_line - 1]
    let gap = " ".repeat(origin.start_column - 1 - line.length())
    lines[origin.start_line - 1] = line + gap + literal
  }
  let file = lines.join("\n") + "\n"
  let with_source = report.review_text(sources=(name, _) => {
    if name == "doc/kit/chip_test.mbt" {
      Some(file)
    } else {
      None
    }
  })
  inspect(
    seen(with_source, "done"),
    content=(
      #|Chip a0: tier 3 done at 1
    ),
  )
  inspect(
    seen(with_source, "do"),
    content=(
      #|Chip a0: tier 3 do at 4
    ),
  )
}

///|
test "chip: the paddings follow the size of the text around it" {
  let chip = @kit.Chip("chip", fill=soft)
  let sized = (size : Double) => {
    let report = compile([Par(Seq(["Mg ", Text(chip, size=Pt(size))]))])
    assert_eq(errors(report), "")
    let label = of_kind(drawn(report), "text").filter(run => run.text == "chip")[0]
    let box = of_kind(drawn(report), "box")[0]
    // The padding to the left, and the padding below the baseline.
    "\{pt(label.h)}pt: \{pt(label.x - box.x)} \{pt(box.y + box.h - label.y)}"
  }
  inspect(
    sized(10),
    content=(
      #|10.0pt: 6.0 3.0
    ),
  )
  inspect(
    sized(7),
    content=(
      #|7.0pt: 4.2 2.1
    ),
  )
  inspect(
    sized(20),
    content=(
      #|20.0pt: 12.0 6.0
    ),
  )
}

///|
test "chip: it has no callback, and can be built anywhere" {
  // In a show rule and in a `Context`, where an element that measures
  // cannot be built.
  let report = compile([
    Show(Select::heading()) <| ((it, _) => {
      Seq([it, " ", @kit.Chip("new", fill=soft)])
    }),
    Heading("Head"),
    Context(_ => @kit.Chip("in a context", fill=soft)),
  ])
  inspect(errors(report) + warnings(report), content="")
  assert_eq(of_kind(drawn(report), "box").length(), 2)
}

///|
test "chip: provenance" {
  let own = Strong("strong")
  let line = line_here() + 3
  let report = compile([
    Par(
      Seq([@kit.Chip("label", fill=soft), " ", @kit.Chip::of(own, fill=soft)]),
    ),
    Par(Seq([@kit.Chip::of("plain", fill=soft)])),
  ])
  inspect(errors(report), content="")
  // The label is the `text` argument; a description of the caller is at
  // its own call; a string in `Chip::of` is the `body` argument.
  inspect(
    text_args(report),
    content=(
      #|label: Chip a0 |  : Seq a0 | strong: Strong a0 | plain: Chip a0
    ),
  )
  // A click on the box, which the element drew: the call.
  let box = of_kind(drawn(report), "box")[0]
  guard report.origin_at(1, box.x + 1.0, box.y + 1.0) is Some(origin) else {
    fail("no origin at the box")
  }
  assert_eq(origin.kind, "Chip")
  assert_eq(origin.param, None)
  assert_eq(origin.start_line, line)
  // Under a key of the caller.
  inspect(
    text_args(compile([Par(Keyed("row", @kit.Chip("a")))])),
    content=(
      #|a: Chip a0 row
    ),
  )
  // An error in an argument is at that argument, in both constructors.
  let paint : @doc.Paint = Value(@doc.Value::str("x"))
  let stroke : Sides[Stroke] = Sides(all=Stroke(paint~))
  let radius : Corners[@doc.Length] = Corners(all=Auto)
  let none : Sides[@doc.Length] = Sides::none()
  let failing : Array[(String, @kit.Chip, @kit.Chip)] = [
    ("fill", @kit.Chip("a", fill=paint), @kit.Chip::of(own, fill=paint)),
    ("stroke", @kit.Chip("a", stroke~), @kit.Chip::of(own, stroke~)),
    ("radius", @kit.Chip("a", radius~), @kit.Chip::of(own, radius~)),
    ("inset", @kit.Chip("a", inset=none), @kit.Chip::of(own, inset=none)),
    ("outset", @kit.Chip("a", outset=none), @kit.Chip::of(own, outset=none)),
  ]
  let places : Array[String] = []
  for entry in failing {
    let (name, chip, of) = entry
    let report = compile([chip])
    assert_true(errors(report) != "")
    assert_eq(error_place(compile([of])), error_place(report))
    places.push("\{name}: \{error_place(report)}")
  }
  inspect(
    places.join(" | "),
    content=(
      #|fill: Chip a1 | stroke: Chip a2 | radius: Chip a3 | inset: Chip a4 | outset: Chip a5
    ),
  )
}
