// What both versions of the report need besides the cards, the table, the
// chips and the drawing of the figures: the colours, the measures of a
// card and of the figures, the scale of the chart, and what is inside a
// tile and a card. Helper code by the rule of docs/edsl-ports.md, section
// 9 (no text or data of the document), in both counts, and the document's
// own in both (`scripts/edsl_helper_lines.py`).

///|
using @doc {
  type Document,
  type SetPage,
  type SetText,
  type SetPar,
  type SetBlock,
  type SetTableCell,
  type ShowSet,
  type Select,
  type Heading,
  type Para,
  type Pagebreak,
  type Seq,
  type Text,
  type Block,
  type Box,
  type Grid,
  type Table,
  type TableHeader,
  type Keyed,
  type Context,
  type Cells,
  type Sides,
  type Stroke,
  type Paint,
  type Sizing,
  type Layout,
  type Linebreak,
  trait IntoContent,
}

///|
let ink : Paint = Rgb("#1d2a24")

///|
let muted : Paint = Rgb("#5f6f66")

///|
let surface : Paint = Rgb("#f3f6f1")

///|
/// The fill of a table's header, and of a marked row.
let sunk : Paint = Rgb("#e6ece4")

///|
let tint : Paint = Rgb("#fbf3d9")

///|
let rule : Stroke = Stroke(paint=Rgb("#c9d3cb"), thickness=Pt(0.5))

///|
let hairline : Sides[Stroke] = Sides(all=rule)

///|
/// The colours of a chip for an outcome: its fill and its text.
fn chip_paints(outcome : Outcome) -> (Paint, Paint) {
  match outcome {
    Harvested => (Rgb("#dcefe0"), Rgb("#1f6b38"))
    Growing => (Rgb("#e3ebf6"), Rgb("#2a4f86"))
    Lost => (Rgb("#f6e3df"), Rgb("#8a2f22"))
  }
}

///|
/// The gap between cards, their inset and the radius of their corners, in
/// points.
const GUTTER : Double = 8

///|
const INSET : Double = 9

///|
const RADIUS : Double = 5

///|
/// What is in a tile: the figure, its label and the note.
fn tile_body(tile : Tile) -> Seq {
  Seq([
    SetBlock(spacing=Pt(5)),
    Block(Text(tile.figure, size=Pt(17), weight=Bold)),
    Block(Text(tile.label, size=Pt(9))),
    Block(Text(tile.note, size=Pt(7), fill=muted)),
  ])
}

///|
/// What is in a card: the title and the text.
fn note_body(note : Note) -> Seq {
  Seq([
    SetBlock(spacing=Pt(5)),
    Block(Text(note.title, weight=SemiBold)),
    Block(Text(note.text, size=Pt(8.5))),
  ])
}

///|
/// The sizes of the labels of the figures, in points: of a name, and of a
/// number beside it.
const LABEL : Double = 7.5

///|
const SMALL : Double = 6.5

///|
/// The chart of the harvest: the room for the names of the beds at its
/// left and for the values at its right, the height of a bar, the distance
/// from one bar to the next, and the room for the ticks under the bars.
const CHART_LEFT : Double = 22

///|
const CHART_RIGHT : Double = 34

///|
const BAR_H : Double = 10

///|
const BAR_STEP : Double = 15

///|
const TICKS_H : Double = 14

///|
/// The scale of the chart: from 0 to 12 kilograms, a tick every 2.
const SCALE_TOP : Double = 12

///|
const SCALE_TICKS : Int = 6

///|
/// Where a value is on the scale of a chart that is `width` wide.
fn on_scale(value : Double, width : Double) -> Double {
  CHART_LEFT + value / SCALE_TOP * (width - CHART_LEFT - CHART_RIGHT)
}

///|
/// The line of the grid of the chart.
let grid : Stroke = Stroke(paint=Rgb("#dfe5e0"), thickness=Pt(0.5))

///|
/// The diagram of the year: the size of a box, how far the arrow back
/// hangs under the boxes, and its colours.
const BOX_W : Double = 54

///|
const BOX_H : Double = 30

///|
const SAG : Double = 28

///|
let box_fill : Paint = Rgb("#e9f1ea")

///|
let box_line : Paint = Rgb("#6f9079")

///|
let back_paint : Paint = Rgb("#2a4f86")

///|
/// The left edge of box `i` of `count` boxes across `width`.
fn box_left(i : Int, count : Int, width : Double) -> Double {
  let gap = (width - BOX_W * count.to_double()) / (count - 1).to_double()
  i.to_double() * (BOX_W + gap)
}

///|
/// The outline of a box of the diagram.
let box_stroke : Sides[Stroke] = Sides(
  all=Stroke(paint=box_line, thickness=Pt(0.8)),
)

///|
/// What is in a box of the diagram: the name of the stage and its note.
fn stage_text(stage : Stage) -> Seq {
  Seq([
    Text(stage.name, size=Pt(LABEL), weight=SemiBold),
    Linebreak(),
    Text(stage.note, size=Pt(SMALL), fill=muted),
  ])
}

///|
/// The stroke of an arrow of the diagram.
fn arrow_stroke(paint : Paint, dashed? : Bool = false) -> Stroke {
  if dashed {
    Stroke(paint~, thickness=Pt(0.9), dash=Dashed)
  } else {
    Stroke(paint~, thickness=Pt(0.9))
  }
}
