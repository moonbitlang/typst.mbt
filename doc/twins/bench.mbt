// The repository's own documents (`bench/*.typ`) written with the EDSL as
// an author would write them. The `edsl` stage compares each with its
// original Typst file (`originals`): the paged documents must be equal in
// layout, warnings, SVG, PDF and pixels. They are not structural twins: the
// originals are markup (text split at spaces, implicit paragraphs, list
// items), the EDSL versions use plain strings and explicit elements.

///|
using @doc {
  type SetEquation,
  type Lorem,
  type Quoted,
  type Sizing,
  type Stack,
  type Circle,
  type PolygonRegular,
  type Curve,
  type CurveMove,
  type CurveCubic,
  type Box,
  type Bibliography,
}

///|
/// An EDSL document and the Typst file it was converted from.
pub struct Original {
  name : String
  /// The path of the Typst file below `bench/`.
  path : String
  /// Whether the document uses system fonts.
  system_fonts : Bool
  /// Builds the EDSL document.
  build : () -> Document
}

///|
/// The converted documents of `bench/`.
pub fn originals() -> Array[Original] {
  [
    { name: "tiny", path: "tiny.typ", system_fonts: false, build: tiny, },
    { name: "long", path: "long.typ", system_fonts: false, build: long, },
    { name: "longer", path: "longer.typ", system_fonts: false, build: longer, },
    {
      name: "showcase",
      path: "showcase.typ",
      system_fonts: true,
      build: full_showcase,
    },
  ]
}

///|
/// `bench/tiny.typ`.
pub fn tiny() -> Document {
  Document(["Hello"])
}

///|
/// `bench/long.typ`: 12 chapters.
pub fn long() -> Document {
  chapters(12)
}

///|
/// `bench/longer.typ`: 60 chapters.
pub fn longer() -> Document {
  chapters(60)
}

///|
/// Chapters of three sections each: filler text, a numbered equation that
/// mentions the chapter, and a computed table.
fn chapters(count : Int) -> Document {
  let body : Array[&@doc.IntoContent] = [
    SetPage(paper="a4", numbering=Numbering("1")),
    SetText(font=["Libertinus Serif"], size=Pt(10.5)),
    SetPar(justify=true),
    SetHeading(numbering=Numbering("1.1")),
    SetEquation(numbering=Numbering("(1)")),
    Outline(),
  ]
  for chapter in 1..<=count {
    body.push(Heading("Chapter \{chapter}"))
    for section in 1..<=3 {
      body.push(Heading("Section \{chapter}.\{section}", level=2))
      body.push(Par(Lorem(180)))
      body.push(
        Equation(
          "sum_(k=0)^n binom(n, k) x^k y^(n-k) = (x + y)^n quad integral_0^1 x^(\{chapter}) dif x = 1 / \{chapter + 1}",
          block=true,
        ),
      )
      body.push(Par(Lorem(120)))
      let cells : Array[&@doc.IntoContent] = []
      for i in 0..<15 {
        cells.push((i * chapter * section).to_string())
      }
      body.push(Table(cells, columns=Sizing::repeat(5)))
    }
  }
  Document(body)
}

///|
/// `bench/showcase.typ`, the whole document.
pub fn full_showcase() -> Document {
  let accent = "#1f4e79"
  let stage_cells : Array[&@doc.IntoContent] = [
    TableHeader([
      Strong("Stage"),
      Strong("What it checks"),
      Strong("Tests"),
      Strong("Pass"),
    ]),
  ]
  // The cells of the two tables come from data. Each row has a key, so
  // that a review comment on a cell names the row it is from
  // (docs/edsl-review.md, slice 4b); `Keyed` does not change the content.
  for row in stage_rows {
    let key = "stage:\{row.0}"
    stage_cells.push(Keyed(key, row.0))
    stage_cells.push(Keyed(key, row.1))
    stage_cells.push(Keyed(key, row.2))
    stage_cells.push(Keyed(key, row.3))
  }
  let fib_cells : Array[&@doc.IntoContent] = []
  for i, n in fibonacci(12) {
    fib_cells.push(Keyed("fib:\{i}", n.to_string()))
  }
  let hyphenation_note = Footnote(
    (
      $|Hyphenation patterns come from the
      $|\{Raw("hypher")} crate, ported to MoonBit together with its tries.
    )
    |> Prose,
  )
  Document([
    // Setup.
    SetDocument(title="typst.mbt Showcase", author=["typst.mbt"], keywords=[
      "typst", "moonbit", "typesetting",
    ]),
    SetPage(
      paper="a4",
      margin=Sides(x=Cm(2.2), top=Cm(2.6), bottom=Cm(2.4)),
      header=Context(cx => {
        let page = cx.counter(Counter::page())
        if page.get()[0] > 1 {
          return Seq([
            SetText(size=Pt(9), fill=Luma(110)),
            Emph("typst.mbt — a MoonBit port of Typst"),
            H(Fr(1)),
            page.display(numbering=Numbering("1 / 1"), both=true),
          ])
        }
        Seq([])
      }),
    ),
    SetText(font=["Libertinus Serif"], size=Pt(11), lang="en"),
    SetPar(justify=true, leading=Em(0.62)),
    SetHeading(numbering=Numbering("1.1")),
    SetEquation(numbering=Numbering("(1)")),
    Show(Select::heading(level=1), (it, _) => {
      Seq([V(Em(0.6)), Block(Text(it, fill=Rgb(accent))), V(Em(0.2))])
    }),
    Show(Select::raw(block=true), (it, _) => {
      Block(
        it,
        fill=Luma(246),
        inset=Sides(all=Pt(9)),
        radius=Corners(all=Pt(4)),
        width=Pct(100),
        stroke=Sides(all=Stroke(thickness=Pt(0.5), paint=Luma(220))),
      )
    }),
    Show(Select::link(), (it, _) => Underline(it)),
    // Title.
    Block(
      Seq([
        SetText(fill=White),
        Text("typst.mbt", size=Pt(26), weight=Bold),
        V(Pt(-6)),
        Text(subtitle, size=Pt(13)),
        V(Pt(4)),
        Text(
          (
            $|This document was compiled end to end by the MoonBit port: parsing, evaluation,
            $|layout, shaping, line breaking, hyphenation, math, bibliography and PDF export.
          )
          |> Prose,
          size=Pt(9.5),
        ),
      ]),
      width=Pct(100),
      inset=Sides(x=Pt(18), y=Pt(22)),
      radius=Corners(all=Pt(8)),
      fill=Paint::linear(
        [Rgb("#1f4e79"), Rgb("#2e86ab"), Rgb("#7fc8a9")],
        angle=Deg(20),
      ),
    ),
    V(Pt(4)),
    Outline(depth=2, indent=Auto),
    // Text and paragraphs.
    Heading("Text and paragraphs"),
    (
      $|Typst lays out text with a Knuth–Plass style optimizer, OpenType shaping and
      $|Unicode line breaking. Ligatures (fi, fl, ffi), kerning and old-style figures
      $|(\{Text("1234567890", number_type="old-style")}) come from the fonts' OpenType
      $|tables, and hyphenation follows the language: the paragraph you are reading is
      $|justified with hyphenation enabled.\{hyphenation_note} Smart quotes adapt
      $|to the language: "English", \{Text(Prose("\"Deutsch\""), lang="de")},
      $|\{Text(Prose("\"Français\""), lang="fr")}.
      $|
      $|\{Text(german, lang="de")}
      $|
      $|Mixed scripts are shaped and reordered with the Unicode bidirectional
      $|algorithm: English, \{Text("مرحبا بالعالم", font=["Geeza Pro"], lang="ar")}, and
      $|\{Text("排版引擎的移植", font=["PingFang SC", "Songti SC"], lang="zh")}, all in
      $|one line.
    )
    |> Prose,
    Grid(
      [
        Seq([
          Strong("Lists"),
          List([
            "Native, wasm-gc and wasm targets",
            Seq([
              "Differential tests against upstream",
              List(["3 792 test files", "Byte-exact SVG"]),
            ]),
          ]),
          Enum(["Parse", "Evaluate", "Lay out"]),
        ]),
        Seq([
          Strong("Quote"),
          Quote(
            "Beauty is our business.",
            attribution="Donald E. Knuth",
            block=true,
          ),
        ]),
      ],
      columns=[Fr(1), Fr(1)],
      gutter=[Pt(14)],
    ),
    // Mathematics.
    Heading("Mathematics"),
    (
      $|The quadratic formula \{Equation(quadratic)} sits
      $|inline, while display math gets its own line:
    )
    |> Prose,
    Equation(display_math[0], block=true),
    Equation(display_math[1], block=true),
    Equation(display_math[2], block=true),
    Equation(maxwell, block=true, label="maxwell"),
    Prose("Maxwell's law, \{Ref("maxwell")}, is referenced by label."),
    // Tables and figures.
    Heading("Tables and figures"),
    Figure(
      Table(
        stage_cells,
        columns=[Auto, Fr(1), Auto, Auto],
        align=Cells::columns([Left, Left, Right, Right]),
        stroke=Cells((_, y) => {
          if y == 0 {
            Sides(bottom=Stroke(thickness=Pt(0.8)))
          } else {
            Sides(bottom=Stroke(thickness=Pt(0.3), paint=Luma(200)))
          }
        }),
        fill=Cells((_, y) => if y > 0 && y % 2 == 1 { Luma(247) } else { None }),
      ),
      caption="Differential test stages against upstream Typst.",
      label="stages",
    ),
    Grid(
      [
        Figure(
          Image("glacier.jpg", width=Pct(100)),
          caption="A JPEG photo, embedded as is.",
        ),
        Figure(
          Image("diagram.svg", width=Pct(100)),
          caption="An SVG diagram, converted to vectors.",
        ),
      ],
      columns=[Fr(1.15), Fr(1)],
      gutter=[Pt(12)],
    ),
    Figure(
      Image("matplotlib.pdf", width=Pct(62)),
      caption="A PDF figure (matplotlib), embedded as a vector form.",
    ),
    // Code.
    Heading("Code"),
    (
      $|Code blocks are highlighted with a port of \{Raw("syntect")} and Typst's bundled
      $|syntaxes:
    )
    |> Prose,
    Raw(rust_code, lang="rust", block=true),
    Raw(python_code, lang="python", block=true),
    Prose("And Typst itself is scriptable — this table is computed:"),
    Table(
      fib_cells,
      columns=Sizing::repeat(12),
      align=Cells::all(Center),
      inset=Cells::all(Sides(all=Pt(5))),
    ),
    // Drawing.
    Heading("Drawing"),
    Align(
      Center,
      Stack(
        [
          Circle(
            radius=Pt(22),
            fill=Paint::radial([Rgb("#ffd166"), Rgb("#ef476f")]),
          ),
          Rect(
            width=Pt(60),
            height=Pt(44),
            radius=Corners(all=Pt(6)),
            fill=Paint::conic(Paint::map("rainbow")),
          ),
          PolygonRegular(
            vertices=6,
            size=Pt(48),
            fill=Rgb("#118ab2"),
            stroke=Stroke(thickness=Pt(1.5), paint=Rgb("#073b4c")),
          ),
          Curve(
            [
              CurveMove((Pt(0), Pt(40))),
              CurveCubic((Pt(20), Pt(-20)), (Pt(40), Pt(80)), (Pt(60), Pt(10))),
            ],
            stroke=Stroke(thickness=Pt(2), paint=Rgb("#06d6a0")),
          ),
          Box(
            NoneValue(),
            width=Pt(70),
            height=Pt(44),
            fill=Paint::tiling(
              Place(
                Line(
                  start=(Pt(0), Pt(0)),
                  end_=(Pt(8), Pt(8)),
                  stroke=Stroke(thickness=Pt(0.6), paint=Luma(120)),
                ),
              ),
              size=(Pt(8), Pt(8)),
            ),
            stroke=Sides(all=Stroke(thickness=Pt(0.6))),
          ),
        ],
        dir=Ltr,
        spacing=Pt(12),
      ),
    ),
    // Citations.
    Heading("Citations"),
    (
      $|Bibliographies are formatted with a port of \{Raw("hayagriva")} and the Citation Style
      $|Language: the Net Wok study \{Ref("netwok")}, distributed dumplings revisited
      $|\{Ref("netwok", supplement=Supplement("p. 200"))}, piracy \{Ref("arrgh")} and glaciers \{Ref("glacier-melt")}, as well as a classic
      $|\{Ref("tolkien54")}.
    )
    |> Prose,
    Bibliography("works.bib", style="ieee"),
  ])
}
