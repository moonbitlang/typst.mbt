// Every example of docs/edsl-design.md as compiled code. The section
// numbers refer to that document.

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
  type Content,
  type Figure,
  type Table,
  type TableHeader,
  type TableCell,
  type Cells,
  type SetPage,
  type SetText,
  type SetHeading,
  type SetPar,
  type Show,
  type ShowSet,
  type Select,
  type Block,
  type Text,
  type V,
  type H,
  type Line,
  type Context,
  type Counter,
  type CounterStep,
  type Markup,
  type Equation,
  type Call,
  type Set,
  type Value,
  type Image,
  type Link,
  type Raw,
  type Align,
  type Ref,
  trait IntoContent,
}

///|
/// Section 4.2: several pieces of content are joined with `Seq`.
pub fn joined_content() -> Par {
  Par(Seq(["Typeset with ", Emph("care"), "."]))
}

///|
/// Section 4.2: structural constructors.
pub fn structural() -> Seq {
  let rows = ["alpha", "beta"]
  Seq([
    Lit("located text"),
    Labelled(Heading("Results"), "sec:results"),
    Heading("Methods", label="sec:methods"),
    Seq::of(rows.map(row => Keyed(row, Par(row)))),
  ])
}

///|
/// Section 2, fact 7: branches of different description types.
pub fn branches(flag : Bool, it : &IntoContent) -> Content {
  if flag {
    Content(Seq([it, "!"]))
  } else {
    Content(it)
  }
}

///|
/// Section 6: field states and units.
pub fn field_states() -> Seq {
  Seq([
    Heading("Automatic level", level=Auto),
    Heading("Level two", level=Custom(2), numbering=None),
    Heading("Numbered", numbering=Some(Numbering("1.")), depth=2),
    Block(
      "A block",
      width=Custom(Pct(100)),
      inset=Sides(all=Pt(9)),
      radius=Corners(all=Pt(4)),
      fill=Some(Luma(246)),
      stroke=Sides(all=Some(Stroke(thickness=Pt(0.5), paint=Luma(220)))),
      above=Custom(Rel(Pt(11) + Em(0.5))),
    ),
    H(Fr(1)),
    V(Em(0.6)),
    Line(length=Pct(50) - Pt(10)),
    Align(Center + Horizon, "centered"),
  ])
}

///|
/// Section 7.3: a table in a figure.
pub fn stages_figure() -> Figure {
  Figure(
    Table(
      [
        TableHeader([Strong("Stage"), Strong("Tests")]),
        "syntax",
        "3 792",
        "paged",
        TableCell("2 299", colspan=1),
      ],
      columns=[Auto, Fr(1)],
      align=Cells::columns([Custom(Left), Custom(Right)]),
      fill=Cells() <| ((_, y) => {
        if y > 0 && y % 2 == 1 {
          Some(Luma(247))
        } else {
          None
        }
      }),
    ),
    caption=Some("Differential test stages."),
    label="stages",
  )
}

///|
/// Section 8: rules.
pub fn rules() -> Document {
  Document([
    SetPage(
      paper="a4",
      margin=Custom(Sides(x=Custom(Cm(2.2)), top=Custom(Cm(2.6)))),
    ),
    SetText(font=["Libertinus Serif"], size=Pt(11), lang="en"),
    SetPar(justify=true, leading=Em(0.62)),
    SetHeading(numbering=Some(Numbering("1.1"))),
    Show(Select::heading(level=Custom(1))) <| ((it, _) => {
      Seq([V(Em(0.6)), Block(Text(it, fill=Rgb("#1f4e79"))), V(Em(0.2))])
    }),
    ShowSet(Select::figure(), SetText(size=Pt(9))),
    Heading("Text and paragraphs"),
    Par("..."),
  ])
}

///|
/// Section 9: a show rule that wraps the matched element.
pub fn underlined_headings() -> Show {
  Show(Select::heading()) <| ((it, _) => Block(Seq([it, Line(length=Pct(100))])))
}

///|
/// Section 10: a contextual page header.
pub fn page_header() -> SetPage {
  SetPage(
    header=Custom(
      Some(
        Context() <| cx => {
          let page = cx.counter(Counter::page())
          if page.get()[0] > 1 {
            return Seq([
              Emph("typst.mbt"),
              H(Fr(1)),
              page.display(numbering=Numbering("1 / 1"), both=true),
            ])
          }
          Seq([])
        },
      ),
    ),
  )
}

///|
/// Section 10: queries and counters in a context.
pub fn contents_summary() -> Context {
  Context() <| cx => {
    let headings = cx.query(Select::heading())
    let figures = cx.counter(Counter::of(Select::figure())).final_value()
    Par("\{headings.length()} headings, \{figures[0]} figures")
  }
}

///|
/// Section 10.2: counter updates are content.
pub fn counter_updates() -> Seq {
  Seq([CounterStep(Counter::named("theorem")), "Theorem"])
}

///|
/// Section 13: escape hatches.
pub fn escape_hatches() -> Seq {
  Seq([
    Markup("Hello *#name*!", scope=[("name", Value::str("world"))]),
    Equation(
      "sum_(k=0)^n k = (n (n + 1)) / 2",
      block=true,
      numbering=Some(Numbering("(1)")),
      label="gauss",
    ),
    Par(Seq(["Inline ", Equation("x^2"), " and a reference: ", Ref("gauss")])),
    Call("lorem", positional=[Value::int(12)]),
    Seq([
      Set("table.cell", [("inset", Value::length(Pt(4)))]),
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
    ]),
  ])
}

///|
/// Sections 6.4 and 7.2: reviewed signatures.
pub fn overrides() -> Seq {
  Seq([
    Link(Url("https://moonbitlang.com")),
    Link(Url("https://typst.app"), body="Typst"),
    Raw("fn main() {}", lang=Some("rust"), block=true),
    Text("bold red", weight=Bold, fill=Red),
  ])
}

///|
/// Section 14: a complete document.
pub fn report() -> Document {
  Document([
    SetPage(
      width=Custom(Pt(360)),
      height=Custom(Pt(480)),
      margin=Custom(Sides(all=Custom(Pt(24)))),
    ),
    SetText(size=Pt(10)),
    SetHeading(numbering=Some(Numbering("1."))),
    underlined_headings(),
    page_header(),
    Heading("Report"),
    joined_content(),
    structural(),
    field_states(),
    stages_figure(),
    contents_summary(),
    counter_updates(),
    escape_hatches(),
    overrides(),
  ])
}

///|
/// Section 14.2: compile and export; the report carries diagnostics and
/// origins on success and on failure.
pub fn export_pdf(world : @doc.DocWorld) -> Bytes raise @doc.DocError {
  let compiled = report().compile_paged(world)
  compiled.pdf().unwrap()
}

///|
/// Section 14.3: the system world and file output.
pub fn write_report(path : String) -> Unit raise {
  let world = @system.world(root=".", system_fonts=false)
  @system.write(path, export_pdf(world))
}

///|
/// Section 12.5: resources resolve against the project root.
pub fn picture() -> Figure {
  Figure(
    Image("assets/chart.png", width=Custom(Pct(80))),
    caption=Some("A chart."),
  )
}
