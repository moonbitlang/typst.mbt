// The twin corpus (docs/edsl-design.md, section 16): pairs of an EDSL
// document and the functional Typst source it must be equivalent to. The
// `edsl` stage of the differential runner compiles both in the same world
// and compares them structurally, by layout and by export; the tests of
// this package compare their SVG with the in-memory world.

///|
using @doc {
  type Document,
  type Heading,
  type Par,
  type Seq,
  type Emph,
  type Strong,
  type Lit,
  type Labelled,
  type Keyed,
  type Space,
  type Figure,
  type Table,
  type TableHeader,
  type TableCell,
  type Grid,
  type List,
  type Enum,
  type Quote,
  type Footnote,
  type Link,
  type Raw,
  type Cells,
  type SetPage,
  type SetText,
  type SetPar,
  type SetHeading,
  type Show,
  type ShowSet,
  type Select,
  type Block,
  type V,
  type H,
  type Line,
  type Align,
  type Context,
  type Counter,
  type CounterStep,
  type CounterUpdate,
  type Markup,
  type Equation,
  type Call,
  type Set,
  type Value,
  type Ref,
  type Outline,
  type Underline,
  type Linebreak,
  type Parbreak,
  type Pagebreak,
}

///|
/// An EDSL document and its functional Typst twin.
pub struct Twin {
  name : String
  /// The Typst source of a main file at the project root.
  typst : String
  /// Builds the EDSL document.
  build : () -> Document
}

///|
/// The Typst source of a twin: the parts are joined without separators,
/// so that no markup space separates the top-level expressions (the EDSL
/// sequence has none either).
fn twin(name : String, parts : Array[String], build : () -> Document) -> Twin {
  { name, typst: parts.join(""), build, }
}

///|
/// A small page, so that documents stay small.
fn page() -> SetPage {
  SetPage(
    width=Custom(Pt(240)),
    height=Custom(Pt(160)),
    margin=Custom(Sides(all=Custom(Pt(12)))),
  )
}

///|
let page_typ : String = "#set page(width: 240pt, height: 160pt, margin: 12pt);"

///|
/// All twins but the showcase.
pub fn constructs() -> Array[Twin] {
  [
    twin("heading", [page_typ, "#heading(level: 2)[#\"Introduction\"]"], () => {
      Document([page(), Heading("Introduction", level=Custom(2))])
    }),
    twin(
      "text-and-sequences",
      [
        page_typ, "#par[#\"Typeset with \"#emph[#\"care\"]#\".\"]", "#[#[#\"a\"#\"b\"]#\"c\"]",
        "#\"located\"", "#[ ]", "#strong(delta: 200)[#\"heavy\"]",
      ],
      () => {
        Document([
          page(),
          Par(Seq(["Typeset with ", Emph("care"), "."])),
          Seq([Seq(["a", "b"]), "c"]),
          Lit("located"),
          Space(),
          Strong("heavy", delta=200),
        ])
      },
    ),
    twin(
      "set-rules",
      [
        page_typ, "#set text(size: 9pt, fill: blue);", "#set par(justify: true, leading: 0.5em);",
        "#par[#\"small blue text\"]", "#[#set text(size: 2em);#\"twice as large\"]",
        "#\"small again\"",
      ],
      () => {
        Document([
          page(),
          SetText(size=Pt(9), fill=Blue),
          SetPar(justify=true, leading=Em(0.5)),
          Par("small blue text"),
          Seq([SetText(size=Em(2)), "twice as large"]),
          "small again",
        ])
      },
    ),
    twin(
      "show-rules",
      [
        page_typ, "#show heading: it => block(fill: luma(230), inset: 4pt, it);",
        "#show emph: set text(fill: red);", "#show \"MoonBit\": it => strong(it);",
        "#heading[#\"Shown\"]", "#par[#\"Written in MoonBit with \"#emph[#\"care\"]#\".\"]",
      ],
      () => {
        Document([
          page(),
          Show(Select::heading()) <| ((it, _) => {
            Block(it, fill=Some(Luma(230)), inset=Sides(all=Pt(4)))
          }),
          ShowSet(Select::emph(), SetText(fill=Red)),
          Show(Select::literal("MoonBit")) <| ((it, _) => Strong(it)),
          Heading("Shown"),
          Par(Seq(["Written in MoonBit with ", Emph("care"), "."])),
        ])
      },
    ),
    twin(
      "labels-and-references",
      [
        page_typ, "#set heading(numbering: \"1.\");", "#heading[#\"First\"]<first>",
        "#[#heading[#\"Second\"]<second>]", "#par[#\"See \"#ref(<first>)#\" and \"#ref(<second>, supplement: [#\"Part\"])#\".\"]",
        "#par[#\"Jump to \"#link(<first>)[#\"the start\"]#\" or \"#link(\"https://typst.app\")#\".\"]",
      ],
      () => {
        Document([
          page(),
          SetHeading(numbering=Some(Numbering("1."))),
          Heading("First", label="first"),
          Labelled(Heading("Second"), "second"),
          Par(
            Seq([
              "See ",
              Ref("first"),
              " and ",
              Ref("second", supplement=Custom(Some(Supplement("Part")))),
              ".",
            ]),
          ),
          Par(
            Seq([
              "Jump to ",
              Link(ToLabel("first"), body="the start"),
              " or ",
              Link(Url("https://typst.app")),
              ".",
            ]),
          ),
        ])
      },
    ),
    twin(
      "context-and-counters",
      [
        page_typ, "#set heading(numbering: \"1.\");", "#heading[#\"One\"]", "#heading[#\"Two\"]",
        "#context [#\"Headings so far: \"#counter(heading).display()]", "#counter(\"item\").step()",
        "#counter(\"item\").update(7)", "#context par[#\"Item \"#counter(\"item\").display(\"1\")#\" on page \"#counter(page).display(\"1 / 1\", both: true)]",
        "#context [#str(query(heading).len())#\" headings\"]",
      ],
      () => {
        Document([
          page(),
          SetHeading(numbering=Some(Numbering("1."))),
          Heading("One"),
          Heading("Two"),
          Context() <| cx => {
            Seq([
              "Headings so far: ",
              cx.counter(Counter::of(Select::heading())).display(),
            ])
          },
          CounterStep(Counter::named("item")),
          CounterUpdate(Counter::named("item"), [7]),
          Context() <| cx => {
            Par(
              Seq([
                "Item ",
                cx
                .counter(Counter::named("item"))
                .display(numbering=Numbering("1")),
                " on page ",
                cx
                .counter(Counter::page())
                .display(numbering=Numbering("1 / 1"), both=true),
              ]),
            )
          },
          Context() <| cx => {
            let headings = cx.query(Select::heading())
            Seq([
              Call("str", positional=[Value::int(headings.length().to_int64())]),
              " headings",
            ])
          },
        ])
      },
    ),
    twin(
      "math",
      [
        page_typ, "#set math.equation(numbering: \"(1)\");", "#par[#\"Inline \"#eval(\"x^2 + y^2\", mode: \"math\")#\" math.\"]",
        "#math.equation(block: true, eval(\"sum_(k=0)^n k = (n (n + 1)) / 2\", mode: \"math\").body)<gauss>",
        "#par[#\"See \"#ref(<gauss>)#\".\"]",
      ],
      () => {
        Document([
          page(),
          Set("math.equation", [("numbering", Value::str("(1)"))]),
          Par(Seq(["Inline ", Equation("x^2 + y^2"), " math."])),
          Equation("sum_(k=0)^n k = (n (n + 1)) / 2", block=true, label="gauss"),
          Par(Seq(["See ", Ref("gauss"), "."])),
        ])
      },
    ),
    twin(
      "markup",
      [
        page_typ, "#eval(\"Hello *#name*, see _this_.\", mode: \"markup\", scope: (name: \"world\"))",
      ],
      () => {
        Document([
          page(),
          Markup("Hello *#name*, see _this_.", scope=[
            ("name", Value::str("world")),
          ]),
        ])
      },
    ),
    twin(
      "table",
      [
        page_typ, "#figure(caption: [#\"Stages.\"], table(columns: (auto, 1fr), align: (left, right), fill: (x, y) => if y > 0 and calc.odd(y) { luma(240) }, stroke: (x, y) => if y == 0 { (bottom: 0.8pt) } else { (bottom: 0.3pt + luma(200)) }, table.header[#\"Stage\"][#\"Tests\"], [#\"syntax\"], [#\"3 792\"], [#\"paged\"], table.cell(fill: yellow)[#\"2 299\"]))<stages>",
        "#par[#ref(<stages>)]",
      ],
      () => {
        Document([
          page(),
          Figure(
            Table(
              [
                TableHeader(["Stage", "Tests"]),
                "syntax",
                "3 792",
                "paged",
                TableCell("2 299", fill=Custom(Some(Yellow))),
              ],
              columns=[Auto, Fr(1)],
              align=Cells::columns([Custom(Left), Custom(Right)]),
              fill=Cells() <| ((_, y) => {
                if y > 0 && y % 2 == 1 {
                  Some(Luma(240))
                } else {
                  None
                }
              }),
              stroke=Cells() <| ((_, y) => {
                if y == 0 {
                  Sides(bottom=Some(Stroke(thickness=Pt(0.8))))
                } else {
                  Sides(bottom=Some(Stroke(thickness=Pt(0.3), paint=Luma(200))))
                }
              }),
            ),
            caption=Some("Stages."),
            label="stages",
          ),
          Par(Ref("stages")),
        ])
      },
    ),
    twin(
      "lists-and-blocks",
      [
        page_typ, "#list([#\"one\"], [#\"two\"], tight: true)", "#enum([#\"first\"], [#\"second\"])",
        "#quote(block: true, attribution: [#\"Knuth\"])[#\"Beauty is our business.\"]",
        "#par[#\"Text\"#footnote[#\"A note.\"]#\" and \"#underline[#\"more\"]#linebreak()#\"next line\"]",
        "#align(center + horizon, block(width: 50%, stroke: 0.5pt + luma(120), radius: 2pt, inset: (x: 4pt, y: 2pt))[#\"boxed\"])",
        "#v(4pt)#line(length: 50% - 10pt)#h(1fr)", "#grid(columns: (1fr, 1fr), gutter: 6pt, [#\"left\"], [#\"right\"])",
        "#raw(\"let x = 1;\", lang: \"rust\", block: true)",
      ],
      () => {
        Document([
          page(),
          List(["one", "two"], tight=true),
          Enum(["first", "second"]),
          Quote(
            "Beauty is our business.",
            block=true,
            attribution=Some("Knuth"),
          ),
          Par(
            Seq([
              "Text",
              Footnote("A note."),
              " and ",
              Underline("more"),
              Linebreak(),
              "next line",
            ]),
          ),
          Align(
            Center + Horizon,
            Block(
              "boxed",
              width=Custom(Pct(50)),
              stroke=Sides(all=Some(Stroke(thickness=Pt(0.5), paint=Luma(120)))),
              radius=Corners(all=Pt(2)),
              inset=Sides(x=Pt(4), y=Pt(2)),
            ),
          ),
          V(Pt(4)),
          Line(length=Pct(50) - Pt(10)),
          H(Fr(1)),
          Grid(["left", "right"], columns=[Fr(1), Fr(1)], gutter=[Pt(6)]),
          Raw("let x = 1;", lang=Some("rust"), block=true),
        ])
      },
    ),
    twin(
      "keyed-and-escapes",
      [
        page_typ, "#[#par[#\"row a\"]#par[#\"row b\"]]", "#lorem(8)", "#set table.cell(inset: 2pt);",
        "#rect(fill: gradient.linear(red, blue), width: 100%, height: 12pt)", "#parbreak()",
        "#pagebreak(weak: true)", "#outline(depth: 1)",
      ],
      () => {
        let rows = ["row a", "row b"]
        Document([
          page(),
          Seq::of(rows.map(row => Keyed(row, Par(row)))),
          Call("lorem", positional=[Value::int(8)]),
          Set("table.cell", [("inset", Value::length(Pt(2)))]),
          Call("rect", named=[
            (
              "fill",
              Value::call("gradient.linear", positional=[
                Value::global("red"),
                Value::global("blue"),
              ]),
            ),
            ("width", Value::length(Pct(100))),
            ("height", Value::length(Pt(12))),
          ]),
          Parbreak(),
          Pagebreak(weak=true),
          Outline(depth=Some(1)),
        ])
      },
    ),
  ]
}

///|
/// The whole corpus.
pub fn all() -> Array[Twin] {
  constructs()
}
