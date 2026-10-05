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
