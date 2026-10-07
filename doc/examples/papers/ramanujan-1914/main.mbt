// S. Ramanujan, "Modular equations and approximations to pi", Quarterly
// Journal of Mathematics, XLV, 1914, 350-372, set as a two-column journal
// article with the EDSL. The text is in the public domain; it follows the
// transcription at https://ramanujan.sirinudi.org/Volumes/published/ram06.html
//
// Usage (from the repository root):
//   moon run doc/examples/papers/ramanujan-1914 --target native
//   moon run doc/examples/papers/ramanujan-1914 --target native -- --check
// The first writes _build/papers/ramanujan-1914.pdf and one PNG per page.
// `--check` writes no pages: it lists the displays that are wider than
// their column and writes every formula, in the paper's order, to
// _build/papers/ramanujan-1914-math.txt (for a numerical check of the
// formulas that have no free variable).

///|
const TITLE : String = "Modular equations and approximations to "

///|
const SOURCE : String = "https://ramanujan.sirinudi.org/Volumes/published/ram06.html"

///|
/// Page furniture: no header on the first page, which has its number at
/// the foot; then the number outside and the author (even pages) or the
/// title (odd pages) in the middle.
fn header() -> Context {
  Context(cx => {
    let page = cx.counter(Counter::page())
    let number = page.get()[0]
    if number == 1 {
      return Seq([])
    }
    let folio : &IntoContent = page.display()
    let nothing : &IntoContent = Seq([])
    let author : &IntoContent = "S. RAMANUJAN"
    let title : &IntoContent = Seq([
      "MODULAR EQUATIONS AND APPROXIMATIONS TO ",
      Equation("pi"),
    ])
    let (left, middle, right) = if number % 2 == 0 {
      (folio, author, nothing)
    } else {
      (nothing, title, folio)
    }
    Text(
      Seq([left, H(Fr(1)), middle, H(Fr(1)), right]),
      size=Pt(8),
      tracking=Pt(0.6),
    )
  })
}

///|
fn footer() -> Context {
  Context(cx => {
    let page = cx.counter(Counter::page())
    if page.get()[0] == 1 {
      Align(Center, Text(page.display(), size=Pt(8)))
    } else {
      Align(Center, Seq([]))
    }
  })
}

///|
/// Set rules and show rules of the article.
fn design() -> Array[&IntoContent] {
  [
    SetPage(
      paper="a4",
      margin=Sides(left=Pt(46), right=Pt(46), top=Pt(62), bottom=Pt(58)),
      header=header(),
      header_ascent=Pt(18),
      footer=footer(),
    ),
    SetText(
      font=["New Computer Modern"],
      size=Pt(10),
      lang="en",
      region="GB",
      hyphenate=true,
    ),
    SetPar(justify=true, leading=Em(0.58), spacing=Em(0.58), extra=[
      ("first-line-indent", Value::length(Em(1.2))),
    ]),
    SetEquation(numbering=Numbering("(1)")),
    // Displays stand closer to the text than Typst's default block spacing.
    ShowSet(
      Select::equation(block=true),
      SetBlock(above=Em(0.85), below=Em(0.85)),
    ),
    // The sections have no titles: the number runs into the first line.
    SetHeading(numbering=Numbering("1.")),
    Show(Select::heading(), (_, cx) => {
      Strong(cx.counter(Counter::of(Select::heading())).display())
    }),
    ShowSet(Select::heading(), SetText(size=Pt(10))),
    // "TABLE I" and "Fig. 1": the caption is the supplement and the number.
    Set("figure.caption", [("separator", Value::content(Seq([])))]),
  ]
}

///|
fn title_block() -> Seq {
  let source = Footnote(
    Seq([Emph("Quarterly Journal of Mathematics"), ", XLV, 1914, 350–372."]),
    numbering=Numbering("*"),
  )
  Seq([
    V(Pt(6)),
    Align(
      Center,
      Seq([
        Block(
          Text(
            Seq([TITLE.to_upper(), Equation("pi"), source]),
            size=Pt(15),
            tracking=Pt(0.8),
          ),
          below=Pt(14),
        ),
        Block(
          Text(Seq(["By ", "S. RAMANUJAN"]), size=Pt(10.5), tracking=Pt(0.4)),
          below=Pt(6),
        ),
        Block(Text("1914", size=Pt(9)), below=Pt(18)),
      ]),
    ),
  ])
}

///|
/// The note the brief asks for on the last page.
fn colophon() -> Block {
  Block(
    Text(
      Par(
        Prose(
          (
            $|\{Strong("Source and rights.")} Srinivasa Ramanujan (died 1920),
            $|“\{TITLE}\{Equation("pi")}”,
            $|\{Emph("Quarterly Journal of Mathematics")}, XLV, 1914, 350–372.
            $|The paper was written in English: there is no translator. The
            $|text and the formulas follow the transcription published at
            $|\{Lit(SOURCE)}; the two figures of section 12 were drawn again
            $|from the constructions in the text. The work is in the public
            $|domain: its author died in 1920 and it was published in 1914.
            $|Typeset in 2026 with the document EDSL of typst.mbt.
          ),
          quotes=false,
        ),
        justify=true,
      ),
      size=Pt(8.5),
    ),
    above=Pt(22),
    inset=Sides(top=Pt(7)),
    stroke=Sides(top=Stroke(thickness=Pt(0.4))),
    breakable=false,
  )
}

///|
fn paper() -> Document {
  // In the paper's order: `eq` checks its numbers against it.
  let first = opening()
  let body : Array[Item] = [
    ..section_1(),
    ..section_2(),
    ..section_3(),
    ..section_4(),
    ..section_5(),
    ..section_6(),
    ..section_7(),
    ..section_8(),
    ..section_9(),
    ..section_10(),
    ..section_11(),
    ..section_12(),
    ..section_13(),
    ..section_14(),
    ..section_15(),
  ]
  Document([..design(), title_block(), flow(first), flow(body), colophon()])
}

///|
fn run(check : Bool) -> Unit raise {
  audit.check = check
  let world = @system.world(system_fonts=false, today=(2026, 1, 1))
  let compiled = paper().compile_paged(world)
  for diagnostic in compiled.warnings {
    println(diagnostic.render())
  }
  for lint in compiled.lints {
    println(lint.render())
  }
  let document = compiled.unwrap()
  println(
    "\{document.pages().length()} pages, \{audit.formulas.length()} formulas, \{audit.numbered} numbered",
  )
  if !check {
    @system.write("_build/papers/ramanujan-1914.pdf", compiled.pdf().unwrap())
    for i, page in compiled.png_pages(ppi=110).unwrap() {
      @system.write("_build/papers/ramanujan-1914-\{i + 1}.png", page)
    }
    return
  }
  // The measuring wrappers of a check run move the page and column breaks,
  // so its pages are not written.
  for src, widths in audit.overfull {
    println("overfull (\{widths}): \{src}")
  }
  let dump = StringBuilder()
  for formula in audit.formulas {
    dump.write_string("\{formula.0}\t\{formula.1}\n")
  }
  @system.write_text("_build/papers/ramanujan-1914-math.txt", dump.to_string())
}

///|
fn main {
  run(@env.args().contains("--check")) catch {
    @doc.DocError(errors) =>
      for error in errors {
        println(error.render())
      }
    err => println("error: \{err}")
  }
}
