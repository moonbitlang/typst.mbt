// The report with the kit's `Cards`, `DataTable`, `Chip` and `Canvas`.

///|
using @kit {type Cards, type DataTable, type Chip, type Canvas}

///|
/// Rounded cards around `bodies`, `columns` to a row.
fn cards(bodies : Array[Seq], columns : Int) -> Cards {
  Cards(
    bodies.map(body => body as &IntoContent),
    columns=Sizing::repeat(columns, size=Fr(1)),
    gutter=[Pt(GUTTER)],
    fill=surface,
    stroke=hairline,
    inset=Sides(all=Pt(INSET)),
    radius=Corners(all=Pt(RADIUS)),
  )
}

///|
/// A status chip.
fn chip(label : String, outcome : Outcome) -> Text {
  let (soft, strong) = chip_paints(outcome)
  Text(
    Chip(label, fill=soft, radius=Corners(all=Pt(7))),
    size=Pt(7),
    weight=SemiBold,
    fill=strong,
  )
}

///|
/// A table in a rounded frame, with its header in small capitals and the
/// rows `mark` (of the body, from 0) tinted.
fn data_table(
  head : Array[String],
  rows : Array[Array[&IntoContent]],
  columns~ : Array[Sizing],
  align~ : Cells[@doc.Alignment],
  mark~ : Array[Int] = [],
) -> Seq {
  let fill : Cells[Paint] = Cells((_, y) => {
    if y == 0 {
      sunk
    } else if mark.contains(y - 1) {
      tint
    } else {
      None
    }
  })
  Seq([
    ShowSet(Select::table_cell(), SetText(size=Pt(8.6))),
    ShowSet(
      Select::table_cell(y=0),
      SetText(size=Pt(7), weight=SemiBold, fill=muted, tracking=Pt(0.35)),
    ),
    DataTable(
      head.map(h => h.to_upper() as &IntoContent),
      rows,
      columns~,
      inset=Cells::all(Sides(x=Pt(8), y=Pt(6))),
      align~,
      fill~,
      stroke=rule,
      radius=Corners(all=Pt(RADIUS)),
    ),
  ])
}

///|
fn after() -> Document {
  report(
    cards(tiles.map(tile_body), tiles.length()),
    cards(worked.map(note_body), 3),
    cards(to_change.map(note_body), 3),
    bed_table_after(bed_columns),
    harvest_chart_after(),
    year_diagram_after(),
  )
}

///|
/// The table of the beds in `columns`.
fn bed_table_after(columns : Array[Sizing]) -> Seq {
  data_table(
    bed_head,
    bed_rows(chip),
    columns~,
    align=Cells::columns([Left, Left, Left, Right, Left]),
    mark=[best_bed()],
  )
}

///|
/// A figure that is as wide as the text: `draw` makes it for that width.
fn figure(draw : (Double) -> Canvas) -> Layout {
  Layout((size, _) => draw(size.width))
}

///|
/// The chart of the harvest: a bar for every bed with its value at its
/// end, over a grid with its ticks.
fn harvest_chart_after() -> Layout {
  figure(width => {
    let plot = beds.length().to_double() * BAR_STEP
    let items : Array[&IntoContent] = []
    for tick in @format.ticks(0.0, SCALE_TOP, SCALE_TICKS) {
      let x = on_scale(tick, width)
      items.push(Canvas::line((x, 0.0), (x, plot), stroke=grid))
      items.push(
        Canvas::place(
          (x, plot + 10.0),
          Text(@format.fixed(tick, 0), size=Pt(SMALL), fill=muted),
          anchor=(Center, Bottom),
        ),
      )
    }
    for i, bed in beds {
      let y = i.to_double() * BAR_STEP + (BAR_STEP - BAR_H) / 2
      let end = on_scale(bed.kilograms, width)
      let middle = y + BAR_H / 2
      items.push(
        Keyed(
          bed.id,
          Seq([
            Canvas::place(
              (CHART_LEFT - 6.0, middle),
              Text(bed.id, size=Pt(LABEL)),
              anchor=(Right, Horizon),
            ),
            Canvas::rect(
              (CHART_LEFT, y),
              end - CHART_LEFT,
              BAR_H,
              fill=chip_paints(bed.outcome).1,
              radius=Corners(all=Pt(2)),
            ),
            Canvas::place(
              (end + 4.0, middle),
              Text(kilograms(bed), size=Pt(SMALL), fill=muted),
              anchor=(Left, Horizon),
            ),
          ]),
        ),
      )
    }
    Canvas(width, plot + TICKS_H, items)
  })
}

///|
/// The diagram of a plant's year: a box for every stage, an arrow from
/// each to the next, and one from the last back to the first.
fn year_diagram_after() -> Layout {
  figure(width => {
    let count = stages.length()
    let top = 2.0
    let bottom = top + BOX_H
    let middle = top + BOX_H / 2
    let items : Array[&IntoContent] = []
    for i, stage in stages {
      let left = box_left(i, count, width)
      items.push(
        Keyed(
          stage.name,
          Seq([
            Canvas::rect(
              (left, top),
              BOX_W,
              BOX_H,
              fill=box_fill,
              stroke=box_stroke,
              radius=Corners(all=Pt(3)),
            ),
            Canvas::place(
              (left + BOX_W / 2, middle),
              stage_text(stage),
              anchor=(Center, Horizon),
            ),
          ]),
        ),
      )
      if i > 0 {
        items.push(
          Canvas::arrow(
            (box_left(i - 1, count, width) + BOX_W, middle),
            [LineTo((left, middle))],
            stroke=arrow_stroke(muted, dashed=stage.name == waits),
          ),
        )
      }
    }
    let from = box_left(count - 1, count, width) + BOX_W / 2
    let to = BOX_W / 2
    items.push(
      Canvas::arrow(
        (from, bottom),
        [CubicTo((from, bottom + SAG), (to, bottom + SAG), (to, bottom))],
        stroke=arrow_stroke(back_paint),
      ),
    )
    items.push(
      Canvas::place(
        ((from + to) / 2, bottom + 0.75 * SAG + 3),
        Text(back_label, size=Pt(SMALL), fill=back_paint),
        anchor=(Center, Top),
      ),
    )
    Canvas(width, bottom + SAG + 4, items)
  })
}
