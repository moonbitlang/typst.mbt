// cetz 0.3.4 (older API, still widely pinned): a schematic tram map with
// layers, groups with custom anchors, viewports, hidden helper paths,
// intersections, the 0.3 tree callbacks (node, parent) / (from, to, ..),
// angle marks and an ortho cut. Two cetz versions may be loaded in one run.

#import "@preview/cetz:0.3.4"

#set page(width: 18cm, height: 14cm, margin: 1cm, footer: context align(right, text(8pt)[
  Network plan, sheet #counter(page).display() of #counter(page).final().first()
]))
#set text(10pt)

#let lines = (
  "1": (color: rgb("#c0392b"), stops: ((0, 4), (2, 4), (4, 4), (6, 4), (8, 5.5), (10, 5.5), (12, 5.5))),
  "2": (color: rgb("#2471a3"), stops: ((1, 0.5), (2.5, 2), (4, 4), (4, 6), (4, 7.5))),
  "3": (color: rgb("#1e8449"), stops: ((0, 7), (2, 6), (4, 6), (6, 4), (8, 2.5), (10, 1), (12, 1))),
  "4": (color: rgb("#b7950b"), stops: ((8, 7.5), (8, 5.5), (8, 2.5), (8, 0.5))),
)
#let names = (
  "4,4": [Market], "6,4": [Mill Lane], "8,5.5": [Theatre], "4,6": [Mint], "8,2.5": [Harbour],
  "0,4": [West Gate], "12,5.5": [Zoo], "12,1": [Ferry], "4,7.5": [Hill], "1,0.5": [Depot],
  "0,7": [Quarry], "8,7.5": [Campus], "8,0.5": [Docks],
)

= Tram network

#cetz.canvas(length: 1.1cm, {
  import cetz.draw: *
  // River on the lowest layer, drawn last.
  on-layer(-1, {
    hobby((-0.5, 2.6), (3, 3), (6.5, 1.6), (9.5, 3.4), (12.5, 2.8), stroke: (paint: aqua.lighten(40%), thickness: 9pt, cap: "round"), name: "river")
    content("river.20%", text(7pt, fill: blue.darken(30%), style: "italic")[River Alm])
  })
  // Tracks.
  for (id, l) in lines {
    line(..l.stops, stroke: (paint: l.color, thickness: 3pt, join: "round", cap: "round"), name: "line" + id)
    // Terminus badges.
    for (pos, anchor) in ((l.stops.first(), "end"), (l.stops.last(), "start")) {
      content(pos, box(fill: l.color, inset: (x: 3pt, y: 2pt), radius: 2pt, text(7pt, fill: white, weight: "bold", id)), name: "badge" + id + anchor, anchor: "south", padding: 0.18)
    }
  }
  // Stations: count how many lines serve each stop.
  let served = (:)
  for (id, l) in lines {
    for s in l.stops {
      let key = str(s.at(0)) + "," + str(s.at(1))
      served.insert(key, served.at(key, default: 0) + 1)
    }
  }
  on-layer(1, {
    for (id, l) in lines {
      for s in l.stops {
        let key = str(s.at(0)) + "," + str(s.at(1))
        let n = served.at(key)
        circle(s, radius: if n > 1 { 0.17 } else { 0.1 }, fill: white, stroke: if n > 1 { black + 1pt } else { l.color + 1pt })
      }
    }
    for (key, name) in names {
      let (x, y) = key.split(",").map(float)
      content((x + 0.2, y - 0.3), anchor: "north-west", text(7pt, name))
    }
  })
  // Where tracks bridge the river.
  intersections("bridges", "river", "line2", "line3", "line4")
  for-each-anchor("bridges", n => {
    rect((rel: (-0.2, -0.2), to: "bridges." + n), (rel: (0.2, 0.2), to: "bridges." + n), stroke: (dash: "dotted", thickness: 0.6pt))
  })
  // A helper path that is not drawn, but gives positions for the fare zones.
  hide(circle((4, 4), radius: 3.2, name: "zone"))
  arc((name: "zone", anchor: 20deg), start: 20deg, stop: 160deg, radius: 3.2, stroke: (dash: "dashed", paint: gray))
  content((name: "zone", anchor: 90deg), anchor: "south", padding: 0.08, text(7pt, fill: gray)[zone A boundary])
  // Legend in its own coordinate system.
  group(name: "legend", {
    set-viewport((10, 6.6), (12.6, 8), bounds: (4, 4))
    rect((0, 0), (4, 4), stroke: 0.4pt, fill: white)
    for (i, (id, l)) in lines.pairs().enumerate() {
      line((0.4, 3.4 - i * 0.9), (1.4, 3.4 - i * 0.9), stroke: l.color + 2pt)
      content((1.7, 3.4 - i * 0.9), anchor: "west", text(6pt)[Line #id, #l.stops.len() stops])
    }
    anchor("corner", (0, 0))
  })
  line("legend.corner", (rel: (-0.6, -0.4)), mark: (end: ">"), stroke: 0.4pt)
})

#pagebreak()

= Depot yard and fares

#grid(
  columns: (1.1fr, 1fr),
  gutter: 0.6cm,
  [
    The yard fans out from one lead track. Each switch turns by the same
    angle $phi = 12 degree$; the drawing repeats one rotated group.

    #cetz.canvas(length: 1cm, {
      import cetz.draw: *
      import cetz.angle: angle
      line((0, 0), (1.5, 0), stroke: 1.5pt, name: "lead")
      for i in range(5) {
        group({
          translate((1.5, 0))
          rotate((i - 2) * 12deg)
          line((0, 0), (4.5, 0), stroke: 1.5pt, name: "t")
          content("t.end", anchor: "west", padding: 0.1, text(7pt)[track #(i + 1)])
          // Sleepers, scaled along the track.
          for k in range(1, 9) {
            line((k * 0.5, -0.08), (k * 0.5, 0.08), stroke: 0.6pt)
          }
        })
      }
      angle((1.5, 0), (6, 0), (rel: (12deg, 4), to: (1.5, 0)), radius: 3, label: text(8pt)[$phi$], label-radius: 108%, mark: (end: ">", start: ">"), stroke: 0.4pt)
      circle((1.5, 0), radius: 0.12, fill: red)
    })
  ],
  [
    Fares follow a small tree. The node callback of this version receives
    the node and its parent, the edge callback the two anchor names.

    #cetz.canvas(length: 1cm, {
      import cetz.draw: *
      set-style(content: (padding: 0.1))
      cetz.tree.tree(
        ([Ticket], ([Single], [A: 2.10], [A+B: 3.40]), ([Day], [A: 5.80], [A+B: 8.20]), [Bike: 1.50]),
        grow: 1.4,
        spread: 1.25,
        draw-node: (node, parent) => {
          let top = parent == none
          content((), frame: "rect", fill: if top { yellow.lighten(60%) } else { white }, stroke: 0.5pt, text(8pt, node.content))
        },
        draw-edge: (from, to, parent, child) => {
          line((a: from, number: 0.38, b: to), (a: to, number: 0.38, b: from), mark: (end: "stealth", fill: black, scale: 0.6), stroke: 0.5pt)
        },
      )
    })
  ],
)

A cut through the embankment at Harbour, drawn with the orthographic
projection of this version (planes `on-xy`, `on-xz`, `on-yz`):

#align(center, cetz.canvas(length: 0.9cm, {
  import cetz.draw: *
  ortho(x: 25deg, y: 35deg, sorted: false, {
    on-xz(y: 0, {
      rect((0, 0), (8, 3), fill: olive.lighten(70%), stroke: 0.4pt)
      for r in (1, 2) {
        line((0, r), (8, r), stroke: 1.2pt + luma(80))
      }
      for k in range(17) {
        line((k * 0.5, 0.8), (k * 0.5, 2.2), stroke: 0.5pt + maroon)
      }
    })
    on-xy(z: 3, rect((0, -1), (8, 0), fill: gray.lighten(40%), stroke: 0.4pt))
    on-yz(x: 8, rect((0, -1), (3, 0), fill: gray.lighten(10%), stroke: 0.4pt))
  })
}))
