// Twins of the kit (docs/edsl-ports.md, section 4): an element of
// `doc/kit` is an expansion into constructors of `doc`, and its twin is a
// Typst function with the same expansion, written with the same
// primitives. The documents below call the element and the function with
// the same arguments.
//
// Two things differ between a Typst function and an element, and the
// documents are written around them:
// - the definition of the function is an expression of the markup, whose
//   value is `none`: the EDSL document starts with `Value::none()`;
// - an expression in the body of the function has one span for all calls
//   of the function, while every call of the element is a call site of its
//   own. Two calls that make equal elements (two empty grids) therefore
//   make one element twice for Typst (one key, told apart by their order)
//   and two elements for the EDSL, which the frame dump shows in the
//   numbers of the keys. No document here calls an element twice with
//   arguments that make equal elements; using one description twice is
//   the same on both sides.

///|
using @doc {type Pad, type SetGrid, type Stroke}

///|
/// The Typst functions of the kit's elements.
///
/// `cards`: the items are the positional arguments; the named ones are
/// those of `@kit.Cards` with Typst's names. Like the element it passes on
/// only the arguments that it was given (`pick`), so that the fields of
/// the primitives that were not set stay unset.
let kit_typ : String =
  #|#let cards(..args) = {
  #|  let items = args.pos()
  #|  let named = args.named()
  #|  let pick(..keys) = {
  #|    let out = (:)
  #|    for key in keys.pos() {
  #|      if key in named { out.insert(key, named.at(key)) }
  #|    }
  #|    out
  #|  }
  #|  // One row of equally wide cards unless the caller says otherwise.
  #|  let columns = named.at("columns", default: (1fr,) * items.len())
  #|  let look = pick("fill", "stroke", "inset")
  #|  if "radius" not in named or items.len() == 0 {
  #|    // The cells draw the cards.
  #|    return grid(
  #|      columns: columns,
  #|      ..pick("gutter", "column-gutter", "row-gutter"),
  #|      ..items.map(item => grid.cell(..look, item)),
  #|    )
  #|  }
  #|  // The rows are measured one by one, which an `auto` column forbids.
  #|  assert(
  #|    columns.len() > 0 and auto not in columns,
  #|    message: "`Cards` with a `radius` cannot have an `Auto` column: its rows are measured one by one, and an `auto` column is as wide as the widest card of all rows",
  #|  )
  #|  // A card as a block: what is measured (without a height) and what is
  #|  // placed (with the height of its row). The grid only places them.
  #|  let card(item, ..size) = block(
  #|    width: 100%,
  #|    ..size,
  #|    ..look,
  #|    radius: named.radius,
  #|    item,
  #|  )
  #|  layout(size => {
  #|    let cells = ()
  #|    let start = 0
  #|    while start < items.len() {
  #|      let row = items.slice(start, calc.min(start + columns.len(), items.len()))
  #|      // The row, as the grid lays it out at the width of the region.
  #|      let probe = grid(
  #|        columns: columns,
  #|        inset: 0pt,
  #|        ..pick("gutter", "column-gutter"),
  #|        ..row.map(item => card(item, breakable: false)),
  #|      )
  #|      let height = if size.width.pt() == float.inf {
  #|        measure(probe).height
  #|      } else {
  #|        measure(probe, width: size.width).height
  #|      }
  #|      cells += row.map(item => if height > size.height {
  #|        // No page holds this row: its cards may break.
  #|        card(item)
  #|      } else {
  #|        card(item, height: height, breakable: false)
  #|      })
  #|      start += columns.len()
  #|    }
  #|    grid(
  #|      columns: columns,
  #|      inset: 0pt,
  #|      ..pick("gutter", "column-gutter", "row-gutter"),
  #|      ..cells,
  #|    )
  #|  })
  #|};

///|
/// A text of `count` words.
fn words(count : Int) -> String {
  Array::make(count, "word").join(" ")
}

///|
/// The twins of the kit.
pub fn kit() -> Array[Twin] {
  let hairline : Sides[Stroke] = Sides(
    all=Stroke(thickness=Pt(0.5), paint=Luma(120)),
  )
  [
    // `Cards` without a radius: the cells of a grid draw the cards.
    twin(
      "kit-cards",
      [
        kit_typ,
        page_typ,
        "#\"Before.\"",
        "#cards(gutter: (6pt,), fill: luma(230), stroke: 0.5pt + luma(120), inset: 4pt, [#\"One.\"], [#\"Two has more words than fit one line of a card.\"], emph[#\"Three.\"])",
        // Tracks of its own, a last row that is not full, and an item
        // that is higher than what is left of the page.
        "#cards(columns: (40pt, 1fr, 2fr), column-gutter: (3pt,), row-gutter: (5pt,), inset: (x: 3pt, y: 2pt), fill: rgb(\"#eef\"), [#\"a\"], [#\"b\"], [#\"c\"], [#\"d\"], [#\"\{words(40)}\"])",
        // Nothing given, and nothing to show.
        "#cards([#\"plain\"], [#\"cards\"])",
        "#cards(fill: red)",
        // In a container, and under a set rule for its primitive.
        "#pad(x: 20pt, cards(columns: (1fr, 1fr), gutter: (4pt,), stroke: 0.5pt + luma(120), [#\"padded\"], [#\"cards in a narrower region\"]))",
        "#[#set grid(inset: 2pt);#cards(fill: luma(230), [#\"set\"], [#\"rule\"])]",
      ],
      () => {
        Document([
          Value::none(),
          page(),
          "Before.",
          @kit.Cards(
            [
              "One.",
              "Two has more words than fit one line of a card.",
              Emph("Three."),
            ],
            gutter=[Pt(6)],
            fill=Luma(230),
            stroke=hairline,
            inset=Sides(all=Pt(4)),
          ),
          @kit.Cards(
            ["a", "b", "c", "d", words(40)],
            columns=[Pt(40), Fr(1), Fr(2)],
            column_gutter=[Pt(3)],
            row_gutter=[Pt(5)],
            inset=Sides(x=Pt(3), y=Pt(2)),
            fill=Rgb("#eef"),
          ),
          @kit.Cards(["plain", "cards"]),
          @kit.Cards([], fill=Red),
          Pad(
            @kit.Cards(
              ["padded", "cards in a narrower region"],
              columns=[Fr(1), Fr(1)],
              gutter=[Pt(4)],
              stroke=hairline,
            ),
            x=Pt(20),
          ),
          Seq([
            SetGrid(inset=Cells::all(Sides(all=Pt(2)))),
            @kit.Cards(["set", "rule"], fill=Luma(230)),
          ]),
        ])
      },
    ),
    // `Cards` with a radius: the rows are measured, the cards are rounded
    // unbreakable blocks of the height of their row.
    twin(
      "kit-cards-radius",
      [
        kit_typ,
        page_typ,
        "#\"Before.\"",
        "#cards(gutter: (6pt,), fill: luma(230), stroke: 0.5pt + luma(120), inset: 4pt, radius: 3pt, [#\"One.\"], [#\"Two has more words than fit one line of a card.\"], emph[#\"Three.\"])",
        // Tracks of its own, corners of their own and a last row that is
        // not full.
        "#cards(columns: (40pt, 1fr, 2fr), column-gutter: (3pt,), row-gutter: (5pt,), inset: (x: 3pt, y: 2pt), fill: rgb(\"#eef\"), radius: (top-left: 6pt, rest: 1pt), [#\"a\"], [#\"b\"], [#\"c\"], [#\"d\"], [#\"\{words(12)}\"])",
        // A row that no page holds: its cards break.
        "#cards(columns: (1fr, 3fr), gutter: (4pt,), fill: luma(230), inset: 3pt, radius: 3pt, [#\"beside\"], [#\"\{words(150)}\"], [#\"after\"])",
        // Nothing but a radius, and nothing to show.
        "#cards(radius: 2pt, [#\"plain\"], [#\"cards\"])",
        "#cards(radius: 2pt)",
        // In a container, and the same cards used twice.
        "#pad(x: 20pt, cards(columns: (1fr, 1fr), gutter: (4pt,), stroke: 0.5pt + luma(120), radius: 4pt, [#\"padded\"], [#\"cards in a narrower region\"]))",
        "#let twice = cards(fill: luma(230), radius: 2pt, inset: 2pt, [#\"used\"], [#\"twice, in two places\"]);#twice#twice",
        // An inset that the document sets for grids is not the cards'.
        "#[#set grid(inset: 5pt);#cards(fill: luma(230), radius: 2pt, [#\"set\"], [#\"rule\"])]",
      ],
      () => {
        let twice = @kit.Cards(
          ["used", "twice, in two places"],
          fill=Luma(230),
          radius=Corners(all=Pt(2)),
          inset=Sides(all=Pt(2)),
        )
        Document([
          Value::none(),
          page(),
          "Before.",
          @kit.Cards(
            [
              "One.",
              "Two has more words than fit one line of a card.",
              Emph("Three."),
            ],
            gutter=[Pt(6)],
            fill=Luma(230),
            stroke=hairline,
            inset=Sides(all=Pt(4)),
            radius=Corners(all=Pt(3)),
          ),
          @kit.Cards(
            ["a", "b", "c", "d", words(12)],
            columns=[Pt(40), Fr(1), Fr(2)],
            column_gutter=[Pt(3)],
            row_gutter=[Pt(5)],
            inset=Sides(x=Pt(3), y=Pt(2)),
            fill=Rgb("#eef"),
            radius=Corners(top_left=Pt(6), rest=Pt(1)),
          ),
          @kit.Cards(
            ["beside", words(150), "after"],
            columns=[Fr(1), Fr(3)],
            gutter=[Pt(4)],
            fill=Luma(230),
            inset=Sides(all=Pt(3)),
            radius=Corners(all=Pt(3)),
          ),
          @kit.Cards(["plain", "cards"], radius=Corners(all=Pt(2))),
          @kit.Cards([], radius=Corners(all=Pt(2))),
          Pad(
            @kit.Cards(
              ["padded", "cards in a narrower region"],
              columns=Sizing::repeat(2, size=Fr(1)),
              gutter=[Pt(4)],
              stroke=hairline,
              radius=Corners(all=Pt(4)),
            ),
            x=Pt(20),
          ),
          // (The binding of `twice` in the markup.)
          Value::none(),
          twice,
          twice,
          Seq([
            SetGrid(inset=Cells::all(Sides(all=Pt(5)))),
            @kit.Cards(
              ["set", "rule"],
              fill=Luma(230),
              radius=Corners(all=Pt(2)),
            ),
          ]),
        ])
      },
    ),
  ]
}
