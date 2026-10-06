// The two versions of the report are the same pages, but for the labels of
// the chart, which the hand-written helper puts on a baseline that it
// estimates.

///|
test "the report compiles in both versions, without warnings" {
  let world = @doc.DocWorld::in_memory()
  for version in versions() {
    let compiled : @doc.CompileReport[@layout.PagedDocument] = (version.1)().compile_paged(
      world,
    )
    assert_eq(compiled.errors.map(e => e.message), [])
    assert_eq(compiled.warnings.map(w => w.message), [])
    assert_eq(compiled.lints.map(l => l.message), [])
    // Three pages: the tiles and the cards on the first, the table of the
    // beds, which is not as high as a page, on the second, the chart and
    // the diagram on the third.
    assert_eq(compiled.unwrap().pages().length(), 3)
  }
}

///|
test "the hand-written helpers and the kit's elements are the same pages" {
  let world = @doc.DocWorld::in_memory()
  let svg = (build : () -> Document) => {
    build().compile_paged(world).svg_pages().unwrap()
  }
  // The cards, the chips and the table: the first two pages.
  let pages_before = svg(before)
  let pages_after = svg(after)
  assert_eq(pages_before.length(), pages_after.length())
  for i in 0..<2 {
    assert_true(pages_before[i] == pages_after[i])
  }
  // And the PDF, byte for byte, of the two versions with the same figures
  // (the third page is compared below).
  let pdf = (document : Document) => {
    document.compile_paged(world).pdf().unwrap()
  }
  let by_hand = report(
    tile_row(tiles),
    note_cards(worked, 3),
    note_cards(to_change, 3),
    bed_table_before(bed_columns),
    harvest_chart_after(),
    year_diagram_after(),
  )
  assert_true(pdf(by_hand) == pdf(after()))
}

///|
/// A number with two decimals.
fn hundredths(x : Double) -> String {
  @format.fixed(x, 2)
}

///|
/// A text run of a page: where its baseline starts, its size, its text
/// and its fill.
priv struct Run {
  x : Double
  y : Double
  size : Double
  text : String
  fill : String
}

///|
/// What a frame at `(dx, dy)` draws, by what is on the page and not by
/// how it is described: a shape as the points of its outline in the
/// coordinates of the page (a straight line is the same two points
/// whether it is a `Line` or a `Curve` of one line), with its fill and its
/// stroke; a text run as a [Run]. `tops` gets the y of the origin of each
/// shape. (No group of these pages is scaled or rotated.)
fn on_page(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  shapes : Array[String],
  tops : Array[Double],
  runs : Array[Run],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    match entry.1 {
      Group(group) =>
        on_page(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          shapes,
          tops,
          runs,
        )
      Shape(shape, _) => {
        let points : Array[String] = []
        let point = (p : @library.Point) => {
          points.push(
            "\{hundredths(x + p.x.to_pt())},\{hundredths(y + p.y.to_pt())}",
          )
        }
        match shape.geometry {
          Rect(size) => {
            point(@library.Point::zero())
            point(@library.Point::new(size.x, @library.Abs::zero()))
            point(@library.Point::new(size.x, size.y))
            point(@library.Point::new(@library.Abs::zero(), size.y))
            points.push("closed")
          }
          Line(to) => {
            point(@library.Point::zero())
            point(to)
          }
          Curve(curve) =>
            for item in curve.items() {
              match item {
                Move(p) | Line(p) => point(p)
                Cubic(p1, p2, p3) => {
                  points.push("curve")
                  point(p1)
                  point(p2)
                  point(p3)
                }
                Close => points.push("closed")
              }
            }
        }
        let fill = shape.fill.map(paint => paint.repr()).unwrap_or("-")
        let stroke = match shape.stroke {
          Some(stroke) => {
            let dash = if stroke.dash is Some(_) { " dashed" } else { "" }
            "\{hundredths(stroke.thickness.to_pt())} \{stroke.paint.repr()}\{dash}"
          }
          None => "-"
        }
        shapes.push("\{points.join(" ")} fill \{fill} stroke \{stroke}")
        tops.push(y)
      }
      Text(text) =>
        runs.push({
          x,
          y,
          size: text.size.to_pt(),
          text: text.text,
          fill: text.fill.repr(),
        })
      _ => ()
    }
  }
}

///|
/// The height of the capitals of the report's text at `size`: the height
/// of a line of text, which is from the top of its capitals to its
/// baseline.
fn capitals(size : Double) -> Double raise {
  let height : Ref[Double] = { val: 0.0, }
  let document = Document([
    Context(cx => {
      height.val = cx.measure(Text("N1", size=Pt(size))).height
      ""
    }),
  ])
  document.compile_paged(@doc.DocWorld::in_memory()).unwrap() |> ignore
  height.val
}

///|
test "the figures: the same shapes and the same text, the labels of the chart on another baseline" {
  let world = @doc.DocWorld::in_memory()
  let third = (build : () -> Document) => {
    let compiled : @doc.CompileReport[@layout.PagedDocument] = build().compile_paged(
      world,
    )
    let shapes : Array[String] = []
    let runs : Array[Run] = []
    on_page(compiled.unwrap().pages()[2].frame, 0.0, 0.0, shapes, [], runs)
    (shapes, runs)
  }
  let (shapes_before, runs_before) = third(before)
  let (shapes_after, runs_after) = third(after)
  // Every shape is drawn at the same place in the same paint, in the same
  // order: the grid, the bars, the boxes, the arrows with their heads, the
  // curve back. (7 lines of the grid, 10 bars, 5 boxes of a fill and an
  // outline each, 5 arrows of a path and a head each.)
  assert_eq(shapes_after, shapes_before)
  assert_eq(shapes_after.length(), 7 + 10 + 5 * 2 + 5 * 2)
  // The text runs are the same text in the same size and paint at the
  // same x; their baselines differ for the three kinds of labels of the
  // chart, and for nothing else.
  assert_eq(runs_after.length(), runs_before.length())
  let moved : Map[String, Array[String]] = Map([])
  let mut same = 0
  for i, run in runs_after {
    let hand = runs_before[i]
    assert_eq(run.text, hand.text)
    assert_eq(run.fill, hand.fill)
    assert_eq(hundredths(run.size), hundredths(hand.size))
    assert_eq(hundredths(run.x), hundredths(hand.x))
    let down = hundredths(run.y - hand.y)
    if down == "0.00" {
      same += 1
    } else {
      match moved.get(down) {
        Some(texts) => texts.push(run.text)
        None => moved[down] = [run.text]
      }
    }
  }
  // How much lower the version with the kit has a label, in points.
  let lines : Array[String] = []
  for down, texts in moved {
    lines.push("\{down}: \{texts.join(" ")}")
  }
  lines.sort()
  inspect(
    lines.join("\n"),
    content=(
      #|0.40: 0 2 4 6 8 10 12
      #|0.43: N1 N2 N3 E1 E2 E3 S1 S2 S3 W1
      #|0.04: 3.4 kg 9.8 kg 6.1 kg 11.2 kg 4.7 kg 1.9 kg 0.6 kg 0.0 kg 0.3 kg 0.2 kg
    ),
  )
  // (The headings, the paragraphs and the text of the diagram.)
  inspect(
    same,
    content=(
      #|16
    ),
  )
}

///|
test "the figures: the labels are where the kit's anchors say, and not where the estimate puts them" {
  let world = @doc.DocWorld::in_memory()
  // The canvas of the chart on the third page: its top is where the grid
  // starts, and the middle of a bar is that of its rectangle.
  let offsets = (build : () -> Document) => {
    let compiled : @doc.CompileReport[@layout.PagedDocument] = build().compile_paged(
      world,
    )
    let shapes : Array[String] = []
    let tops : Array[Double] = []
    let runs : Array[Run] = []
    on_page(compiled.unwrap().pages()[2].frame, 0.0, 0.0, shapes, tops, runs)
    let run = (text : String) => runs.filter(run => run.text == text)[0]
    // (The top of the canvas: the baseline of a tick is asked for 10pt
    // under the bars, which end `beds.length() * BAR_STEP` under it. The
    // first grid line starts at the top.)
    let grid_top = tops[0]
    let plot = beds.length().to_double() * BAR_STEP
    // The baseline of a tick, from where it was asked for.
    let tick = run("12").y - (grid_top + plot + 10.0)
    // The middle of the capitals of the name and of the value of the
    // second bed, from the middle of its bar.
    let middle = grid_top + BAR_STEP + BAR_STEP / 2
    let name = run("N2").y - capitals(LABEL) / 2 - middle
    let value = run(kilograms(beds[1])).y - capitals(SMALL) / 2 - middle
    "tick \{hundredths(tick)}, name \{hundredths(name)}, value \{hundredths(value)}"
  }
  // With the kit: on the baseline that was asked for, and on the middle
  // of the bar.
  inspect(
    offsets(after),
    content=(
      #|tick 0.00, name 0.00, value 0.00
    ),
  )
  // By hand: the top of a label is taken to be 0.72 of its size above its
  // baseline, and it is 0.658 of it (finding T11), so a label is 0.06 of
  // its size too high; and the middle of a line of text is taken to be
  // 2.5pt above its baseline, whatever its size.
  inspect(
    offsets(before),
    content=(
      #|tick -0.40, name -0.43, value -0.04
    ),
  )
}

///|
/// A length in tenths of a point.
fn tenths(x : Double) -> String {
  let n = (x * 10.0).round().to_int()
  "\{n / 10}.\{n % 10}"
}

///|
/// What a frame at `(dx, dy)` on the page `page` draws, each with its place:
/// the straight lines (with their extent), the other shapes (with their
/// stroke and fill), and the text runs.
fn drawn(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  page : Int,
  lines : Array[String],
  rest : Array[String],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    let at = "p\{page} \{tenths(x)},\{tenths(y)}"
    match entry.1 {
      Group(group) =>
        drawn(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          page,
          lines,
          rest,
        )
      Shape({ geometry: Line(to), .. }, _) =>
        lines.push("\{at} \{tenths(to.x.to_pt())}x\{tenths(to.y.to_pt())}")
      Shape(shape, _) => {
        let fill = shape.fill.map(paint => paint.repr()).unwrap_or("")
        let stroke = shape.stroke
          .map(stroke => stroke.paint.repr())
          .unwrap_or("")
        rest.push("\{at} shape \{fill} \{stroke}")
      }
      Text(text) => rest.push("\{at} \{tenths(text.size.to_pt())} \{text.text}")
      _ => ()
    }
  }
}

///|
test "where the table continues on the next page, the two differ by one rule" {
  // The table of the beds alone, on a page that holds its header and seven
  // of its ten rows.
  let world = @doc.DocWorld::in_memory()
  let on_short_page = (table : &IntoContent) => {
    let document = Document([
      SetPage(width=Pt(420), height=Pt(190), margin=Sides(all=Pt(18))),
      SetText(size=Pt(10), fill=ink),
      table,
    ])
    let compiled : @doc.CompileReport[@layout.PagedDocument] = document.compile_paged(
      world,
    )
    assert_eq(compiled.errors.map(e => e.message), [])
    let lines : Array[String] = []
    let rest : Array[String] = []
    for i, page in compiled.unwrap().pages() {
      drawn(page.frame, 0.0, 0.0, i + 1, lines, rest)
    }
    (lines, rest)
  }
  let (lines_before, rest_before) = on_short_page(bed_table_before(bed_columns))
  let (lines_after, rest_after) = on_short_page(bed_table_after(bed_columns))
  // The text, the fills, the chips and the frames are the same, at the
  // same places, on both pages.
  assert_eq(rest_after, rest_before)
  assert_eq(
    rest_after.filter(item => item.has_prefix("p2 ")).length() > 20,
    true,
  )
  // The rules of the version with the kit are rules of the hand-written
  // version, which has one more: the rule under the last row of the first
  // page. A rule under every row but the table's last is what the helper
  // asked for; the engine draws the line under a page's last row where the
  // table's bottom border is, on the outline of the frame.
  for line in lines_after {
    assert_true(lines_before.contains(line))
  }
  inspect(
    lines_before.filter(line => !lines_after.contains(line)).join("\n"),
    content=(
      #|p1 17.8,158.1 384.5x0.0
    ),
  )
  // (Seven rules on the first page and three on the second are in both.)
  assert_eq(lines_after.length(), 10)
  assert_eq(lines_before.length(), 11)
}
