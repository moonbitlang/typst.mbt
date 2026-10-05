// The phase-1 milestone (docs/edsl-design.md, section 17): the reduced
// showcase. It is `bench/showcase.typ` without its Drawing and Citations
// sections and without the line that needs system fonts, written with the
// EDSL (`showcase`) and as functional Typst (`showcase_typst`). Its images
// are the files of `bench/`, which must be the project root of the world.

///|
/// The table of test stages: name, what it checks, tests, pass rate.
let stage_rows : Array[(String, String, String, String)] = [
  ("syntax", "parser, AST, incremental reparse", "3 792", "100%"),
  ("eval", "evaluation, styles, introspection", "3 792", "99.7%"),
  ("paged", "frames: layout, text, math", "2 299", "100%"),
  ("svg", "SVG export, byte-identical", "2 299", "100%"),
  ("pdf", "PDF semantics and tag tree", "2 299", "100%"),
  ("render", "PNG rasterization", "2 299", "100%"),
]

///|
let rust_code : String =
  #|/// Compute the n-th Fibonacci number.
  #|fn fib(n: u64) -> u64 {
  #|    let (mut a, mut b) = (0, 1);
  #|    for _ in 0..n {
  #|        (a, b) = (b, a + b);
  #|    }
  #|    a
  #|}

///|
let python_code : String =
  #|def primes(limit: int) -> list[int]:
  #|    sieve = [True] * (limit + 1)
  #|    for i in range(2, int(limit ** 0.5) + 1):
  #|        if sieve[i]:
  #|            sieve[i * i :: i] = [False] * len(sieve[i * i :: i])
  #|    return [i for i in range(2, limit + 1) if sieve[i]]

///|
let intro_1 : String = "Typst lays out text with a Knuth–Plass style optimizer, OpenType shaping and Unicode line breaking. Ligatures (fi, fl, ffi), kerning and old-style figures ("

///|
let intro_2 : String = ") come from the fonts' OpenType tables, and hyphenation follows the language: the paragraph you are reading is justified with hyphenation enabled."

///|
let german : String = "Donaudampfschifffahrtsgesellschaftskapitänsmütze ist ein langes deutsches Wort, das ohne Silbentrennung kaum in eine Zeile passt."

///|
let subtitle : String = "A faithful MoonBit port of the Typst typesetting engine"

///|
let blurb : String = "This document was compiled end to end by the MoonBit port: parsing, evaluation, layout, shaping, line breaking, hyphenation, math and PDF export."

///|
let quadratic : String = "x = (-b plus.minus sqrt(b^2 - 4 a c)) / (2 a)"

///|
let display_math : Array[String] = [
  "integral_(-infinity)^infinity e^(-x^2) dif x = sqrt(pi) quad \"and\" quad sum_(n=1)^infinity 1 / n^2 = pi^2 / 6",
  "mat(cos theta, -sin theta; sin theta, cos theta;) vec(x, y) = vec(x cos theta - y sin theta, x sin theta + y cos theta)",
  "f(x) = cases(x^2 & \"if\" x >= 0, -x & \"otherwise\",) wide lim_(n -> infinity) (1 + 1/n)^n = e",
]

///|
let maxwell : String = "nabla times bold(B) - 1/c^2 (partial bold(E)) / (partial t) = mu_0 bold(J)"

///|
/// The first Fibonacci numbers (the computed table).
fn fibonacci(count : Int) -> Array[Int] {
  let fibs = [0, 1]
  for i in 2..<count {
    fibs.push(fibs[i - 1] + fibs[i - 2])
  }
  fibs
}

///|
/// The reduced showcase, built with the EDSL.
pub fn showcase() -> Document {
  let accent = "#1f4e79"
  let title_fill = Paint::linear(
    [Rgb("#1f4e79"), Rgb("#2e86ab"), Rgb("#7fc8a9")],
    angle=Deg(20),
  )
  let stage_cells : Array[&@doc.IntoContent] = [
    TableHeader([
      Strong("Stage"),
      Strong("What it checks"),
      Strong("Tests"),
      Strong("Pass"),
    ]),
  ]
  for row in stage_rows {
    stage_cells.push(row.0)
    stage_cells.push(row.1)
    stage_cells.push(row.2)
    stage_cells.push(row.3)
  }
  let fib_cells : Array[&@doc.IntoContent] = []
  for n in fibonacci(12) {
    fib_cells.push(n.to_string())
  }
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
        Text(blurb, size=Pt(9.5)),
      ]),
      width=Pct(100),
      inset=Sides(x=Pt(18), y=Pt(22)),
      radius=Corners(all=Pt(8)),
      fill=title_fill,
    ),
    V(Pt(4)),
    Outline(depth=2, indent=Auto),
    // Text and paragraphs.
    Heading("Text and paragraphs"),
    Par(
      Seq([
        intro_1,
        Text("1234567890", number_type="old-style"),
        intro_2,
        Footnote(
          Seq([
            "Hyphenation patterns come from the ",
            Raw("hypher"),
            " crate, ported to MoonBit together with its tries.",
          ]),
        ),
        " Smart quotes adapt to the language: ",
        Quoted("English"),
        ", ",
        Text(Quoted("Deutsch"), lang="de"),
        ", ",
        Text(Quoted("Français"), lang="fr"),
        ". See ",
        Link(Url("https://typst.app"), body="typst.app"),
        ".",
      ]),
    ),
    Par(Text(german, lang="de")),
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
    Par(
      Seq([
        "The quadratic formula ",
        Equation(quadratic),
        " sits inline, while display math gets its own line:",
      ]),
    ),
    Equation(display_math[0], block=true),
    Equation(display_math[1], block=true),
    Equation(display_math[2], block=true),
    Equation(maxwell, block=true, label="maxwell"),
    Par(Seq(["Maxwell's law, ", Ref("maxwell"), ", is referenced by label."])),
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
    Par(
      Seq([
        "Code blocks are highlighted with a port of ",
        Raw("syntect"),
        " and Typst's bundled syntaxes, see ",
        Ref("stages"),
        ":",
      ]),
    ),
    Raw(rust_code, lang="rust", block=true),
    Raw(python_code, lang="python", block=true),
    Par(
      "And MoonBit itself is the scripting language — this table is computed:",
    ),
    Table(
      fib_cells,
      columns=Array::make(12, @doc.Sizing::Auto),
      align=Cells::all(Center),
      inset=Cells::all(Sides(all=Pt(5))),
    ),
  ])
}

// The functional Typst twin, assembled from the same data.

///|
/// A Typst string literal.
fn typ_str(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      _ => out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// Literal text in markup: `#"text"`.
fn typ_text(text : String) -> String {
  "#" + typ_str(text)
}

///|
/// A content block with literal text: `[#"text"]`.
fn typ_block(text : String) -> String {
  "[" + typ_text(text) + "]"
}

///|
/// An equation from a math string, like `Equation(source, block=..)`.
fn typ_equation(source : String, block : Bool) -> String {
  if block {
    "math.equation(block: true, eval(\{typ_str(source)}, mode: \"math\").body)"
  } else {
    "eval(\{typ_str(source)}, mode: \"math\")"
  }
}

///|
/// The functional Typst twin of [showcase].
pub fn showcase_typst() -> String {
  let parts : Array[String] = []
  // Setup.
  parts.push(
    "#set document(title: [#\"typst.mbt Showcase\"], author: (\"typst.mbt\",), keywords: (\"typst\", \"moonbit\", \"typesetting\"));",
  )
  parts.push(
    "#set page(paper: \"a4\", margin: (x: 2.2cm, top: 2.6cm, bottom: 2.4cm), header: context { if counter(page).get().first() > 1 [#set text(size: 9pt, fill: luma(110));#emph[#\"typst.mbt — a MoonBit port of Typst\"]#h(1fr)#counter(page).display(\"1 / 1\", both: true)] });",
  )
  parts.push(
    "#set text(font: (\"Libertinus Serif\",), size: 11pt, lang: \"en\");",
  )
  parts.push("#set par(justify: true, leading: 0.62em);")
  parts.push("#set heading(numbering: \"1.1\");")
  parts.push("#set math.equation(numbering: \"(1)\");")
  parts.push(
    "#show heading.where(level: 1): it => [#v(0.6em)#block(text(fill: rgb(\"#1f4e79\"), it))#v(0.2em)];",
  )
  parts.push(
    "#show raw.where(block: true): it => block(fill: luma(246), inset: 9pt, radius: 4pt, width: 100%, stroke: 0.5pt + luma(220), it);",
  )
  parts.push("#show link: it => underline(it);")
  // Title.
  parts.push(
    "#block(width: 100%, inset: (x: 18pt, y: 22pt), radius: 8pt, fill: gradient.linear(rgb(\"#1f4e79\"), rgb(\"#2e86ab\"), rgb(\"#7fc8a9\"), angle: 20deg))[#set text(fill: white);#text(size: 26pt, weight: \"bold\")[#\"typst.mbt\"]#v(-6pt)#text(size: 13pt)\{typ_block(subtitle)}#v(4pt)#text(size: 9.5pt)\{typ_block(blurb)}]",
  )
  parts.push("#v(4pt)")
  parts.push("#outline(depth: 2, indent: auto)")
  // Text and paragraphs.
  parts.push("#heading[#\"Text and paragraphs\"]")
  parts.push(
    "#par[\{typ_text(intro_1)}#text(number-type: \"old-style\")[#\"1234567890\"]\{typ_text(intro_2)}#footnote[#\"Hyphenation patterns come from the \"#raw(\"hypher\")#\" crate, ported to MoonBit together with its tries.\"]#\" Smart quotes adapt to the language: \"#[#smartquote()#\"English\"#smartquote()]#\", \"#text(lang: \"de\")[#smartquote()#\"Deutsch\"#smartquote()]#\", \"#text(lang: \"fr\")[#smartquote()#\"Français\"#smartquote()]#\". See \"#link(\"https://typst.app\")[#\"typst.app\"]#\".\"]",
  )
  parts.push("#par(text(lang: \"de\")\{typ_block(german)})")
  parts.push(
    "#grid(columns: (1fr, 1fr), gutter: 14pt, [#strong[#\"Lists\"]#list([#\"Native, wasm-gc and wasm targets\"], [#\"Differential tests against upstream\"#list([#\"3 792 test files\"], [#\"Byte-exact SVG\"])])#enum([#\"Parse\"], [#\"Evaluate\"], [#\"Lay out\"])], [#strong[#\"Quote\"]#quote(attribution: [#\"Donald E. Knuth\"], block: true)[#\"Beauty is our business.\"]])",
  )
  // Mathematics.
  parts.push("#heading[#\"Mathematics\"]")
  parts.push(
    "#par[#\"The quadratic formula \"#\{typ_equation(quadratic, false)}#\" sits inline, while display math gets its own line:\"]",
  )
  for source in display_math {
    parts.push("#" + typ_equation(source, true))
  }
  parts.push("#" + typ_equation(maxwell, true) + "<maxwell>")
  parts.push(
    "#par[#\"Maxwell's law, \"#ref(<maxwell>)#\", is referenced by label.\"]",
  )
  // Tables and figures.
  parts.push("#heading[#\"Tables and figures\"]")
  let cells = StringBuilder()
  for row in stage_rows {
    for cell in [row.0, row.1, row.2, row.3] {
      cells.write_string(", ")
      cells.write_string(typ_block(cell))
    }
  }
  parts.push(
    "#figure(table(columns: (auto, 1fr, auto, auto), align: (left, left, right, right), stroke: (x, y) => if y == 0 { (bottom: 0.8pt) } else { (bottom: 0.3pt + luma(200)) }, fill: (x, y) => if y > 0 and calc.odd(y) { luma(247) }, table.header(strong[#\"Stage\"], strong[#\"What it checks\"], strong[#\"Tests\"], strong[#\"Pass\"])\{cells.to_string()}), caption: [#\"Differential test stages against upstream Typst.\"])<stages>",
  )
  parts.push(
    "#grid(columns: (1.15fr, 1fr), gutter: 12pt, figure(image(\"glacier.jpg\", width: 100%), caption: [#\"A JPEG photo, embedded as is.\"]), figure(image(\"diagram.svg\", width: 100%), caption: [#\"An SVG diagram, converted to vectors.\"]))",
  )
  parts.push(
    "#figure(image(\"matplotlib.pdf\", width: 62%), caption: [#\"A PDF figure (matplotlib), embedded as a vector form.\"])",
  )
  // Code.
  parts.push("#heading[#\"Code\"]")
  parts.push(
    "#par[#\"Code blocks are highlighted with a port of \"#raw(\"syntect\")#\" and Typst's bundled syntaxes, see \"#ref(<stages>)#\":\"]",
  )
  parts.push("#raw(\{typ_str(rust_code)}, lang: \"rust\", block: true)")
  parts.push("#raw(\{typ_str(python_code)}, lang: \"python\", block: true)")
  parts.push(
    "#par[#\"And MoonBit itself is the scripting language — this table is computed:\"]",
  )
  let fibs = StringBuilder()
  for n in fibonacci(12) {
    fibs.write_string(", ")
    fibs.write_string(typ_block(n.to_string()))
  }
  parts.push(
    "#table(columns: (auto,) * 12, align: center, inset: 5pt\{fibs.to_string()})",
  )
  parts.join("")
}
