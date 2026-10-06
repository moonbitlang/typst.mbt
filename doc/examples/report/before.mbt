// The report with the hand-written helpers of `before_helpers.mbt` and
// `before_drawing.mbt`: what it is made of, and its two figures.

///|
fn before() -> Document {
  report(
    tile_row(tiles),
    note_cards(worked, 3),
    note_cards(to_change, 3),
    bed_table_before(bed_columns),
    harvest_chart_before(),
    year_diagram_before(),
  )
}

///|
/// The table of the beds in `columns`.
fn bed_table_before(columns : Array[Sizing]) -> Block {
  framed_table(bed_head, bed_rows(pill), columns~, num=[3], mark=[best_bed()])
}

///|
/// The chart of the harvest: a bar for every bed with its value at its
/// end, over a grid with its ticks.
fn harvest_chart_before() -> Block {
  let plot = beds.length().to_double() * BAR_STEP
  let items : Array[&IntoContent] = []
  for tick in @format.ticks(0.0, SCALE_TOP, SCALE_TICKS) {
    let x = on_scale(tick, TEXT_W)
    items.push(segment(x, 0, x, plot, grid))
    items.push(
      label(
        x,
        plot + 10,
        @format.fixed(tick, 0),
        size=SMALL,
        fill=muted,
        anchor=Mid,
      ),
    )
  }
  for i, bed in beds {
    let y = i.to_double() * BAR_STEP + (BAR_STEP - BAR_H) / 2
    let end = on_scale(bed.kilograms, TEXT_W)
    // (A label on the middle of its bar: its baseline a little under it.)
    let baseline = y + BAR_H / 2 + 2.5
    items.push(
      Keyed(
        bed.id,
        Seq([
          label(CHART_LEFT - 6, baseline, bed.id, anchor=Trail),
          bar(
            CHART_LEFT,
            y,
            end - CHART_LEFT,
            BAR_H,
            chip_paints(bed.outcome).1,
          ),
          label(end + 4, baseline, kilograms(bed), size=SMALL, fill=muted),
        ]),
      ),
    )
  }
  canvas(plot + TICKS_H, items)
}

///|
/// The diagram of a plant's year: a box for every stage, an arrow from
/// each to the next, and one from the last back to the first.
fn year_diagram_before() -> Block {
  let count = stages.length()
  let top = 2.0
  let bottom = top + BOX_H
  let nodes : Array[Node] = Array::makei(count, i => {
    x: box_left(i, count, TEXT_W),
    y: top,
    w: BOX_W,
    h: BOX_H,
  })
  let items : Array[&IntoContent] = []
  for i, stage in stages {
    items.push(
      Keyed(stage.name, node(nodes[i], stage_text(stage), box_fill, box_stroke)),
    )
    if i > 0 {
      let from = nodes[i - 1]
      items.push(
        arrow(
          from.x + from.w,
          from.cy(),
          nodes[i].x,
          nodes[i].cy(),
          muted,
          dashed=stage.name == waits,
        ),
      )
    }
  }
  let from = nodes[count - 1].cx()
  let to = nodes[0].cx()
  items.push(arrow_back(from, to, bottom, SAG, back_paint))
  items.push(
    at(
      (from + to) / 2 - 90,
      bottom + 0.75 * SAG + 3,
      Box(
        Align(Center, Text(back_label, size=Pt(SMALL), fill=back_paint)),
        width=Pt(180),
      ),
    ),
  )
  canvas(bottom + SAG + 4, items)
}
