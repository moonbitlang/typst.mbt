// timeliney 0.4.0 (on cetz 0.4.1): Gantt charts with two header lines,
// header groups, task groups with bars and bar labels, tasks with several
// bars, in-place and aligned milestones, grids, offsets and custom line
// styles. The chart width follows `layout`, so the same function is drawn
// on a portrait page, in a figure, on a landscape page and in a narrow column.

#import "@preview/timeliney:0.4.0"

#set page(width: 17cm, height: 22cm, margin: 1.5cm, numbering: "1")
#set heading(numbering: "1.")
#set text(10pt)
#set par(justify: true)

= Hut renovation, season plan

The hut above the tree line is open to work from the first week of June,
when the track is free of snow, until the middle of September. @fig-season
plans those fifteen weeks. The first header line groups the weeks by
month, the second numbers them.

#let weeks-per-month = (([*June*], 4), ([*July*], 5), ([*August*], 4), ([*Sept.*], 2))
#let bar(colour, thickness: 9pt) = (stroke: (paint: colour, thickness: thickness, cap: "butt"))

#figure(
  timeliney.timeline(
    show-grid: true,
    spacing: 4pt,
    line-style: (stroke: 3pt + gray),
    {
      import timeliney: *

      headerline(..weeks-per-month.map(m => group(m)))
      headerline(group(..range(1, 16).map(w => text(7pt)[#w])))

      taskgroup(
        title: [*Roof*],
        content: text(7pt, fill: white, weight: "bold")[carpenter],
        style: bar(black, thickness: 11pt),
        {
          task([Strip old shingles], (0, 2), style: bar(red.darken(10%)))
          task([Replace rafters], (1.5, 4), style: bar(red.darken(10%)))
          task([New larch shingles], (from: 4, to: 7, content: text(7pt, fill: white)[weather permitting], style: bar(red.darken(30%))))
        },
      )

      taskgroup(
        title: [*Masonry*],
        style: bar(black, thickness: 3pt),
        {
          task([Repoint north wall], (2, 5), style: bar(olive))
          task([Chimney], (5, 6.5), (8, 9), style: bar(olive))
        },
      )

      taskgroup(title: [*Interior*], {
        task([Bunks], (6, 9))
        task([Stove and flue], (9, 10.5), style: (stroke: (paint: orange, thickness: 3pt, dash: "dashed")))
        task([Floor oil], (10.5, 11), (12, 12.5))
      })

      task([_Helicopter days_], (0, 0.3), (4, 4.3), (8.8, 9.1), (14, 14.3), style: bar(blue, thickness: 6pt))

      milestone(at: 4, style: (stroke: (dash: "dashed", paint: blue)), align(center, text(8pt)[*Material flight*\ 4 loads]))
      milestone(at: 7, style: (stroke: (dash: "dotted")), align(center, text(8pt)[*Roof tight*]))
      milestone(at: 13, style: (stroke: (dash: "dashed", paint: red)), align(center, text(8pt)[*Inspection*\ by the section]))
    },
  ),
  caption: [The season from June to mid September, in weeks.],
) <fig-season>

Bars of the group titles span their tasks automatically. A task may have
several bars, as the chimney has: the mason comes twice.

#columns(2, gutter: 1cm)[
  == The first fortnight

  In a narrow column the chart shrinks with the available width; nothing in
  its description changes. Days replace weeks, and there is no grid.

  #timeliney.timeline(
    spacing: 3pt,
    heading-spacing: 6pt,
    tasks-vline: false,
    cell-line-style: (stroke: 0.5pt + gray),
    {
      import timeliney: *
      headerline(([Week 1], 7), ([Week 2], 7))
      headerline(..("M", "T", "W", "T", "F", "S", "S").map(d => text(6pt, d)) * 2)
      task(text(8pt)[Carry tools], (0, 1), (7, 7.5))
      task(text(8pt)[Scaffold], (1, 3))
      task(text(8pt)[Shingles off], (3, 6), (7.5, 11))
      task(text(8pt)[Rest], (6, 7), (13, 14), style: (stroke: 2pt + green))
      milestone(at: 11, text(7pt)[bare roof])
    },
  )

  #colbreak()

  == Who is up when

  #lorem(40)

  The volunteers of @fig-crew arrive in three shifts. The second chart of
  this sheet is drawn on a landscape page, because its milestone list
  needs the width.
]

#page(flipped: true)[
  = Crew plan <sec-crew>

  #figure(
    timeliney.timeline(
      show-grid: "x",
      milestone-layout: "aligned",
      box-milestones: true,
      offset: 0.5,
      milestone-line-style: (stroke: (paint: purple, thickness: 0.8pt, dash: "dash-dotted")),
      grid-style: (stroke: (dash: "dotted", thickness: 0.4pt, paint: luma(120))),
      {
        import timeliney: *
        headerline(
          group(([*June*], 4), ([*July*], 5)),
          group(([*August*], 4), ([*September*], 2)),
        )
        headerline(group(..range(23, 38).map(w => text(7pt)[W#w])))

        let shifts = (
          ([Anna (lead)], ((0, 14),), navy),
          ([Beat, roofer], ((0, 6.5),), red.darken(20%)),
          ([Chiara, mason], ((2, 6), (7.5, 8.5)), olive),
          ([Dario and Eva], ((5.5, 10.5),), orange.darken(10%)),
          ([School group], ((9, 10), (11, 12)), teal),
        )
        taskgroup(title: [*On the hut*], style: (stroke: 1.5pt + black), {
          for (name, bars, colour) in shifts {
            task(name, ..bars, style: (stroke: (paint: colour, thickness: 7pt, cap: "round")))
          }
        })
        taskgroup(title: [*In the valley*], style: (stroke: 1.5pt + black), {
          task([Ordering], (from: 0, to: 3.5, content: text(7pt)[Fritz]), style: (stroke: 10pt + luma(200)))
          task([Accounts], (from: 10, to: 14, content: text(7pt)[Greta]), style: (stroke: 10pt + luma(200)))
        })

        milestone(at: 3.5, [Larch delivered to the heliport])
        milestone(at: 6.5, [Roofer leaves, roof must be closed])
        milestone(at: 12, [Last school group down])
        milestone(at: 14, [Hut closed for winter])
      },
    ),
    caption: [Shifts of the crew, with milestones listed below the tasks.],
  ) <fig-crew>

  The chart reads its width from the page: this page is
  #context [#calc.round(page.height.cm(), digits: 1) cm] wide after flipping. See
  @fig-season for the work itself.
]
