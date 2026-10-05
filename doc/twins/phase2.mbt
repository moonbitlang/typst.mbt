// Twins of the constructs added for the full showcase and by the
// stress test of the EDSL (docs/edsl-design.md, sections 4.3, 6.4, 7 and
// 13): smart quotes, the equation set rule and selector, the outline
// indent, function facades (`Lorem`, `PolygonRegular`, `Paint::tiling`),
// shapes and curves, transforms, bibliographies and citations, spread
// arguments and the newline space.

///|
using @doc {
  type Cite,
  type Polygon,
  type CurveLine,
  type CurveQuad,
  type CurveClose,
  type Scale,
  type Skew,
  type ShowWith,
  type Symbol,
  type Prose,
}

///|
/// The twins of the phase-2 constructs.
pub fn phase2() -> Array[Twin] {
  [
    // Smart quotes follow the language and the nesting, as in markup.
    twin(
      "quoted",
      [
        page_typ, "#set text(lang: \"de\");", "#par[#\"Er sagte \"#[#smartquote()#\"Hallo\"#smartquote()]#\" und \"#[#smartquote(double: false)#\"ja\"#smartquote(double: false)]#\".\"]",
        "#text(lang: \"fr\")[#[#smartquote()#[#\"Bonjour \"#[#smartquote()#\"monde\"#smartquote()]]#smartquote()]]",
      ],
      () => {
        Document([
          page(),
          SetText(lang="de"),
          Par(
            Seq([
              "Er sagte ",
              Quoted("Hallo"),
              " und ",
              Quoted("ja", double=false),
              ".",
            ]),
          ),
          Text(Quoted(Seq(["Bonjour ", Quoted("monde")])), lang="fr"),
        ])
      },
    ),
    // The typed equation set rule and selector, and the outline's indent.
    twin(
      "equation-rules",
      [
        page_typ, "#set heading(numbering: \"1.\");", "#set math.equation(numbering: \"(1)\", number-align: left);",
        "#show math.equation.where(block: true): it => block(it, fill: luma(240));",
        "#outline(depth: 2, indent: auto)", "#outline(title: none, indent: 1em)",
        "#heading[#\"One\"]", "#heading(level: 2)[#\"Two\"]", "#math.equation(block: true, eval(\"x^2\", mode: \"math\").body)",
        "#eval(\"y\", mode: \"math\")",
      ],
      () => {
        Document([
          page(),
          SetHeading(numbering=Numbering("1.")),
          SetEquation(numbering=Numbering("(1)"), number_align=Left),
          Show(Select::equation(block=true), (it, _) => {
            Block(it, fill=Luma(240))
          }),
          Outline(depth=2, indent=Auto),
          Outline(title=NoneValue(), indent=Em(1)),
          Heading("One"),
          Heading("Two", level=2),
          Equation("x^2", block=true),
          Equation("y"),
        ])
      },
    ),
    // Function facades and the track shorthand.
    twin(
      "function-facades",
      [
        page_typ, "#lorem(12)", "#table(columns: 3, [#\"a\"], [#\"b\"], [#\"c\"])",
        "#grid(columns: (20pt, 20pt), rows: (auto, auto), [#\"x\"], [#\"y\"])", "#polygon.regular(vertices: 5, size: 20pt, fill: aqua, stroke: 1pt + red)",
        "#rect(width: 30pt, height: 10pt, fill: tiling(size: (4pt, 4pt), spacing: (1pt, 1pt), circle(radius: 1pt, fill: red)))",
        "#rect(width: 30pt, height: 10pt, fill: gradient.linear(..color.map.viridis))",
        "#rect(width: 30pt, height: 10pt, fill: gradient.conic(red, ..color.map.rainbow, blue))",
      ],
      () => {
        Document([
          page(),
          Lorem(12),
          Table(["a", "b", "c"], columns=Sizing::repeat(3)),
          Grid(
            ["x", "y"],
            columns=Sizing::repeat(2, size=Pt(20)),
            rows=Sizing::repeat(2),
          ),
          PolygonRegular(
            vertices=5,
            size=Pt(20),
            fill=Aqua,
            stroke=Stroke(thickness=Pt(1), paint=Red),
          ),
          Rect(
            width=Pt(30),
            height=Pt(10),
            fill=Paint::tiling(
              Circle(radius=Pt(1), fill=Red),
              size=(Pt(4), Pt(4)),
              spacing=(Pt(1), Pt(1)),
            ),
          ),
          Rect(
            width=Pt(30),
            height=Pt(10),
            fill=Paint::linear(Paint::map("viridis")),
          ),
          Rect(
            width=Pt(30),
            height=Pt(10),
            fill=Paint::conic([Red, ..Paint::map("rainbow"), Blue]),
          ),
        ])
      },
    ),
    // Shapes, curves and transforms.
    twin(
      "shapes",
      [
        page_typ, "#polygon(fill: blue, (0pt, 0pt), (20pt, 0pt), (10pt, 15pt))",
        "#curve(stroke: 1pt + green, fill: yellow, fill-rule: \"even-odd\", curve.move((0pt, 10pt)), curve.line((10pt, 0pt)), curve.quad((15pt, 5pt), (20pt, 10pt)), curve.cubic((5pt, 5pt), (10pt, 15pt), (20pt, 0pt), relative: true), curve.close(mode: \"straight\"))",
        "#scale(50%)[#\"half\"]", "#scale(x: 120%, y: 80%, origin: left)[#\"wide\"]",
        "#skew(ax: 10deg, reflow: true)[#\"skewed\"]", "#box(none, width: 10pt, height: 10pt, fill: red)",
      ],
      () => {
        Document([
          page(),
          Polygon(
            [(Pt(0), Pt(0)), (Pt(20), Pt(0)), (Pt(10), Pt(15))],
            fill=Blue,
          ),
          Curve(
            [
              CurveMove((Pt(0), Pt(10))),
              CurveLine((Pt(10), Pt(0))),
              CurveQuad((Pt(15), Pt(5)), (Pt(20), Pt(10))),
              CurveCubic(
                (Pt(5), Pt(5)),
                (Pt(10), Pt(15)),
                (Pt(20), Pt(0)),
                relative=true,
              ),
              CurveClose(mode="straight"),
            ],
            stroke=Stroke(thickness=Pt(1), paint=Green),
            fill=Yellow,
            fill_rule="even-odd",
          ),
          Scale("half", factor=Pct(50)),
          Scale("wide", x=Pct(120), y=Pct(80), origin=Left),
          Skew("skewed", ax=Deg(10), reflow=true),
          Box(NoneValue(), width=Pt(10), height=Pt(10), fill=Red),
        ])
      },
    ),
    // A bibliography with citations and a reference to a key.
    twin(
      "bibliography",
      [
        page_typ, "#par[#\"See \"#cite(label(\"netwok\"))#\", \"#cite(label(\"arrgh\"), supplement: [#\"p. 7\"], form: \"prose\")#\" and \"#ref(<tolkien54>)#\".\"]",
        "#bibliography(\"works.bib\", title: [#\"Sources\"], style: \"apa\", full: false)",
      ],
      () => {
        Document([
          page(),
          Par(
            Seq([
              "See ",
              Cite("netwok"),
              ", ",
              Cite("arrgh", supplement="p. 7", form="prose"),
              " and ",
              Ref("tolkien54"),
              ".",
            ]),
          ),
          Bibliography("works.bib", title="Sources", style="apa", full=false),
        ])
      },
    ),
    // Several bibliography sources are an array.
    twin(
      "bibliography-sources",
      [
        page_typ, "#cite(label(\"netwok\"))", "#bibliography((\"works.bib\",), title: none)",
      ],
      () => {
        Document([
          page(),
          Cite("netwok"),
          Bibliography(["works.bib"], title=NoneValue()),
        ])
      },
    ),
    // Spread arguments of generic calls: arrays positionally, dictionaries
    // by name.
    twin(
      "spread-arguments",
      [
        page_typ, "#grid(..([#\"a\"], [#\"b\"], [#\"c\"]), ..(columns: 3, gutter: 4pt))",
        "#text(..(fill: red, size: 8pt), ..none)[#\"red\"]",
      ],
      () => {
        Document([
          page(),
          Call("grid", positional=[
            Value::spread(
              Value::array([
                Value::content("a"),
                Value::content("b"),
                Value::content("c"),
              ]),
            ),
            Value::spread(
              Value::dict([
                ("columns", Value::int(3)),
                ("gutter", Value::length(Pt(4))),
              ]),
            ),
          ]),
          Call("text", positional=[
            Value::spread(
              Value::dict([
                ("fill", Value::paint(Red)),
                ("size", Value::length(Pt(8))),
              ]),
            ),
            Value::spread(Value::none()),
            Value::content("red"),
          ]),
        ])
      },
    ),
    // A document in a directory: relative paths in arguments and in
    // fragments resolve against it.
    twin(
      "document-directory",
      [
        page_typ, "#image(\"../glacier.jpg\", width: 30pt)", "#eval(\"#image(\\\"../diagram.svg\\\", width: 30pt)\", mode: \"markup\")",
        "#image(\"/glacier.jpg\", width: 20pt)",
      ],
      () => {
        Document(
          [
            page(),
            Image("../glacier.jpg", width=Pt(30)),
            Markup("#image(\"../diagram.svg\", width: 30pt)"),
            Image("/glacier.jpg", width=Pt(20)),
          ],
          dir="chapters",
        )
      },
      dir="chapters",
    ),
    // Symbols (markup's escapes and shorthands) and show rules whose
    // transformation is a value, with and without a selector; positional
    // arguments of the generic set rule.
    twin(
      "symbols-and-value-rules",
      [
        page_typ, "#set text(8pt, red);", "#show link: underline;", "#show \"old\": [#\"new\"];",
        "#show heading.where(level: 2): smallcaps;", "#show: box.with(stroke: 1pt);",
        "#symbol(\"—\")#symbol(\"#\")#\" \"#link(\"https://typst.app\")#\" old \"#heading(level: 2)[#\"Sub\"]",
      ],
      () => {
        Document([
          page(),
          Set("text", [], positional=[Value::length(Pt(8)), Value::paint(Red)]),
          ShowWith(Select::link(), Value::global("underline")),
          ShowWith(Select::literal("old"), Value::content("new")),
          ShowWith(Select::heading(level=2), Value::global("smallcaps")),
          ShowWith::all(
            Value::call("function.with", positional=[Value::global("box")], named=[
              ("stroke", Value::length(Pt(1))),
            ]),
          ),
          Symbol("—"),
          Symbol("#"),
          " ",
          Link(Url("https://typst.app")),
          " old ",
          Heading("Sub", level=2),
        ])
      },
    ),
    // Prose: words and markup's spaces, smart quotes, interpolated
    // descriptions, a paragraph break at the blank line; a line break
    // next to Chinese text is no space; `quotes=false` keeps the quote
    // characters; an interpolated string is text like the rest.
    twin(
      "prose",
      [
        page_typ, "#[#\"Code\" #\"blocks\" #\"use\" #raw(\"syntect\")#\",\" #smartquote(double: true)#\"quoted\"#smartquote(double: true)\n#\"and\" #\"it\"#smartquote(double: false)#\"s\" #emph[#\"fine\"]#\".\"#parbreak()#\"Next\" #\"paragraph\" #\"with\" #\"3\" #\"words.\"]",
        "#parbreak()", "#[#\"汉字\"\n#\"汉字\" #\"a\"\n#\"b\"]", "#parbreak()",
        "#[#\"say\" #\"\\\"hi\\\"\"]", "#figure(caption: [#\"A\" #strong[#\"bold\"] #\"caption\"])[#\"x\"]",
        // Carriage returns are line breaks (CR LF is one); white space at
        // the edges is dropped; `Lit` is verbatim between quotes.
         "#parbreak()", "#[#\"汉\"\r#\"字\" #\"a\"\r\n#\"b\"#parbreak()#\"c\"]",
        "#parbreak()", "#[#\"x\"]", "#[#smartquote(double: true)#\"a  'b'\"#smartquote(double: true)]",
      ],
      () => {
        let count = 3
        Document([
          page(),
          (
            $|Code blocks use \{Raw("syntect")}, "quoted"
            $|and it's \{Emph("fine")}.
            $|
            $|Next paragraph with \{count} words.
          )
          |> Prose,
          Parbreak(),
          (
            $|汉字
            $|汉字 a
            $|b
          )
          |> Prose,
          Parbreak(),
          Prose("say \"hi\"", quotes=false),
          Figure("x", caption=Prose("A \{Strong("bold")} caption")),
          Parbreak(),
          Prose("汉\r字 a\r\nb\r\rc"),
          Parbreak(),
          Prose(" \n x \t\n\n "),
          Prose("\"\{Lit("a  'b'")}\""),
        ])
      },
    ),
    // Every piece of a sequence is an expression of its own, as in markup:
    // the text runs, quotes and paragraph breaks of `Prose`, the plain
    // strings of `Seq` and the quotes of `Quoted` have distinct spans. The
    // engine hashes spans into the keys of located elements, so the
    // paragraphs with equal words below are different elements, as in the
    // twin (the keys of their tags are compared by the frame dump). Found
    // by converting the upstream suite in the readable mode
    // (`grid-subheaders-non-repeating-header-before-multi-page-row`,
    // `[row #colbreak() row]`).
    twin(
      "repeated-pieces",
      [
        page_typ, "#[#\"row\"#parbreak()#\"row\"#parbreak()#smartquote(double: true)#parbreak()#smartquote(double: true)#parbreak()#\"row\"]",
        "#parbreak()", "#[#\"same\"#parbreak()#\"same\"#parbreak()#3#parbreak()#3]",
        "#parbreak()", "#[#smartquote()#parbreak()#smartquote()]",
      ],
      () => {
        Document([
          page(),
          Prose("row\n\nrow\n\n\"\n\n\"\n\nrow"),
          Parbreak(),
          Seq([
            "same",
            Parbreak(),
            "same",
            Parbreak(),
            Value::int(3),
            Parbreak(),
            Value::int(3),
          ]),
          Parbreak(),
          Quoted(Parbreak()),
        ])
      },
    ),
    // Typst's operators on values, evaluated when the value is lowered.
    twin(
      "value-operators",
      [
        page_typ, "#rect(stroke: 1pt + red, width: 10pt * 2, height: 30pt / 2 - 5pt)",
        "#(-(2 + 3))", "#(\"a\" + \"b\")", "#((1, 2) + (3,))",
      ],
      () => {
        Document([
          page(),
          Call("rect", named=[
            ("stroke", Value::length(Pt(1)).add(Value::paint(Red))),
            ("width", Value::length(Pt(10)).mul(Value::int(2))),
            (
              "height",
              Value::length(Pt(30)).div(Value::int(2)).sub(Value::length(Pt(5))),
            ),
          ]),
          Value::int(2).add(Value::int(3)).neg(),
          Value::str("a").add(Value::str("b")),
          Value::array([Value::int(1), Value::int(2)]).add(
            Value::array([Value::int(3)]),
          ),
        ])
      },
    ),
    // The space of a source line break is discarded next to Chinese text;
    // an ordinary space is kept.
    twin(
      "newline-space",
      [
        page_typ, "#par[#\"and\"\n#\"汉字\"\n#\"汉字\" #\"汉字\"\n#\"end\"]",
        "#par[#\"a\"\n#\"b\"]",
      ],
      () => {
        Document([
          page(),
          Par(
            Seq([
              "and",
              Space::newline(),
              "汉字",
              Space::newline(),
              "汉字",
              Space(),
              "汉字",
              Space::newline(),
              "end",
            ]),
          ),
          Par(Seq(["a", Space::newline(), "b"])),
        ])
      },
    ),
  ]
}
