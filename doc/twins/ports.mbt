// Twins of the typed additions of docs/edsl-ports.md, sections 3.2 to 3.4:
// `Layout`, the baseline of a measured size, the baseline of a box, the
// edges of text, dash patterns, colour operations, the conversions of
// `Length`, `Upper`/`Lower` and `Sides::zero`.

///|
using @doc {
  type Layout,
  type Highlight,
  type Upper,
  type Lower,
  type SetBox,
  type SetHighlight,
  type Length,
  type Dash,
}

///|
/// The predefined dash patterns: the case of `Dash` and Typst's name.
fn dash_presets() -> Array[(Dash, String)] {
  [
    (Solid, "solid"),
    (Dotted, "dotted"),
    (DenselyDotted, "densely-dotted"),
    (LooselyDotted, "loosely-dotted"),
    (Dashed, "dashed"),
    (DenselyDashed, "densely-dashed"),
    (LooselyDashed, "loosely-dashed"),
    (DashDotted, "dash-dotted"),
    (DenselyDashDotted, "densely-dash-dotted"),
    (LooselyDashDotted, "loosely-dash-dotted"),
  ]
}

///|
/// The Typst source of the `dashes` twin.
fn dashes_typ() -> Array[String] {
  let parts = [
    page_typ, "#set line(length: 100%);", "#set block(spacing: 5pt);",
  ]
  for preset in dash_presets() {
    parts.push("#line(stroke: (dash: \"\{preset.1}\"))")
  }
  parts.append([
    "#line(stroke: (thickness: 2pt, dash: (array: (10pt, 5pt, \"dot\", 5pt), phase: 10pt)))",
    "#line(stroke: (paint: blue, dash: (array: (1em, \"dot\"), phase: 0pt)))", "#[#set line(stroke: (dash: \"dashed\"));#line()#line(stroke: (dash: none))#line(stroke: (dash: auto))#line(stroke: (thickness: 2pt))]",
    "#line(stroke: (dash: \"dotted\"))#line(stroke: (dash: (4pt, \"dot\")))", "#rect(width: 100%, height: 10pt, stroke: (dash: \"densely-dashed\", cap: \"round\"))",
  ])
  parts
}

///|
/// The twins of the typed additions.
pub fn ports() -> Array[Twin] {
  [
    // Content that depends on the size of its container: the base size of
    // the region (the block's width, the page's height), with the context
    // of the invocation for measuring.
    twin(
      "layout",
      [
        page_typ, "#block(width: 120pt, layout(size => rect(width: size.width / 2, height: 10pt)))",
        "#layout(size => { let m = measure(width: size.width / 3, [#\"some words that wrap in a third of the width\"]); rect(width: m.width, height: m.height) })",
        "#grid(columns: (70pt, 1fr), layout(size => line(length: size.width)), layout(size => line(length: size.width - 10pt)))",
      ],
      () => {
        Document([
          page(),
          Block(
            Layout((size, _) => Rect(width=Pt(size.width / 2), height=Pt(10))),
            width=Pt(120),
          ),
          Layout((size, cx) => {
            let m = cx.measure(
              "some words that wrap in a third of the width",
              width=Pt(size.width / 3),
            )
            Rect(width=Pt(m.width), height=Pt(m.height))
          }),
          Grid(
            [
              Layout((size, _) => Line(length=Pt(size.width))),
              Layout((size, _) => Line(length=Pt(size.width) - Pt(10))),
            ],
            columns=[Pt(70), Fr(1)],
          ),
        ])
      },
    ),
    // A dimension that nothing bounds is infinite: the height of a page
    // that grows with its content, and both dimensions while measuring.
    twin(
      "layout-unbounded",
      [
        page_typ, "#set page(height: auto);", "#layout(size => if size.height.pt() == float.inf { [#\"unbounded\"] } else { [#\"bounded\"] })",
        "#block(height: 30pt, layout(size => if size.height.pt() == float.inf { [#\"unbounded\"] } else { [#\"bounded\"] }))",
        "#context { let m = measure(layout(size => rect(width: if size.width.pt() == float.inf { 30pt } else { 60pt }, height: 5pt))); rect(width: m.width, height: m.height) }",
      ],
      () => {
        let measured = Layout((size, _) => {
          Rect(
            width=if size.width.is_inf() { Pt(30) } else { Pt(60) },
            height=Pt(5),
          )
        })
        Document([
          page(),
          SetPage(height=Auto),
          Layout((size, _) => {
            if size.height.is_inf() {
              "unbounded"
            } else {
              "bounded"
            }
          }),
          Block(
            Layout((size, _) => {
              if size.height.is_inf() {
                "unbounded"
              } else {
                "bounded"
              }
            }),
            height=Pt(30),
          ),
          Context(cx => {
            let m = cx.measure(measured)
            Rect(width=Pt(m.width), height=Pt(m.height))
          }),
        ])
      },
    ),
    // The baseline of a measured size, and the baseline shift of a box.
    twin(
      "baselines",
      [
        page_typ, "#context { let m = measure(text(bottom-edge: \"descender\")[#\"xg\"]); rect(width: m.baseline * 4, height: m.height) }",
        "#context { let m = measure(block(inset: 5pt)[#\"xg\"]); rect(width: m.width, height: m.baseline) }",
        "#par[#\"a\"#box(baseline: 2pt, fill: luma(220))[#\"b\"]#\"c\"#box(baseline: -30% + 1pt, stroke: 0.5pt)[#\"d\"]#box(baseline: auto)[#\"e\"]]",
        "#[#set box(baseline: 0.2em);#par[#\"f\"#box[#\"g\"]#box(baseline: (at: bottom, shift: 1pt))[#\"h\"]]]",
      ],
      () => {
        Document([
          page(),
          Context(cx => {
            let m = cx.measure(Text("xg", bottom_edge=Descender))
            Rect(width=Pt(m.baseline * 4), height=Pt(m.height))
          }),
          Context(cx => {
            let m = cx.measure(Block("xg", inset=Sides(all=Pt(5))))
            Rect(width=Pt(m.width), height=Pt(m.baseline))
          }),
          Par(
            Seq([
              "a",
              Box("b", baseline=Pt(2), fill=Luma(220)),
              "c",
              Box(
                "d",
                baseline=Pct(-30) + Pt(1),
                stroke=Sides(all=Stroke(thickness=Pt(0.5))),
              ),
              Box("e", baseline=Auto),
            ]),
          ),
          Seq([
            SetBox(baseline=Em(0.2)),
            Par(
              Seq([
                "f",
                Box("g"),
                // The other forms of the field stay reachable.
                Box("h", extra=[
                  (
                    "baseline",
                    Value::dict([
                      ("at", Value::alignment(Bottom)),
                      ("shift", Value::length(Pt(1))),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ])
      },
    ),
    // The edges of text, in constructors and set rules, for text and
    // highlights: every metric of each edge and a length.
    twin(
      "text-edges",
      [
        page_typ, "#set text(size: 9pt);", "#rect(inset: 0pt, text(top-edge: \"ascender\", bottom-edge: \"descender\")[#\"Typst\"])",
        "#rect(inset: 0pt, text(top-edge: \"cap-height\", bottom-edge: \"baseline\")[#\"Typst\"])",
        "#rect(inset: 0pt, text(top-edge: \"x-height\", bottom-edge: \"bounds\")[#\"Typst\"])",
        "#rect(inset: 0pt, text(top-edge: \"bounds\", bottom-edge: -0.2em)[#\"Typst\"])",
        "#rect(inset: 0pt, text(top-edge: \"baseline\", bottom-edge: -6pt)[#\"Typst\"])",
        "#rect(inset: 0pt, text(top-edge: 0.7em + 1pt)[#\"Typst\"])", "#par[#highlight(top-edge: \"x-height\", bottom-edge: \"baseline\")[#\"low\"]#highlight(top-edge: \"bounds\", bottom-edge: \"bounds\")[#\"tight\"]#highlight(top-edge: 9pt, bottom-edge: \"descender\")[#\"high\"]]",
        "#[#set text(top-edge: \"bounds\", bottom-edge: \"bounds\");#set highlight(top-edge: \"cap-height\", bottom-edge: -1pt);#par[#\"edges \"#highlight[#\"set\"]]]",
      ],
      () => {
        let boxed = (text : Text) => Rect(body=text, inset=Sides::zero())
        Document([
          page(),
          SetText(size=Pt(9)),
          boxed(Text("Typst", top_edge=Ascender, bottom_edge=Descender)),
          boxed(Text("Typst", top_edge=CapHeight, bottom_edge=Baseline)),
          boxed(Text("Typst", top_edge=XHeight, bottom_edge=Bounds)),
          boxed(Text("Typst", top_edge=Bounds, bottom_edge=Len(Em(-0.2)))),
          boxed(Text("Typst", top_edge=Baseline, bottom_edge=Len(Pt(-6)))),
          boxed(Text("Typst", top_edge=Len(Em(0.7) + Pt(1)))),
          Par(
            Seq([
              Highlight("low", top_edge=XHeight, bottom_edge=Baseline),
              Highlight("tight", top_edge=Bounds, bottom_edge=Bounds),
              Highlight("high", top_edge=Len(Pt(9)), bottom_edge=Descender),
            ]),
          ),
          Seq([
            SetText(top_edge=Bounds, bottom_edge=Bounds),
            SetHighlight(top_edge=CapHeight, bottom_edge=Len(Pt(-1))),
            Par(Seq(["edges ", Highlight("set")])),
          ]),
        ])
      },
    ),
    // Dash patterns: the states, every predefined pattern, an array of
    // lengths with a phase, and the untyped forms.
    twin("dashes", dashes_typ(), () => {
      let children : Array[&@doc.IntoContent] = [
        page(),
        Set("line", [("length", Value::length(Pct(100)))]),
        Set("block", [("spacing", Value::length(Pt(5)))]),
      ]
      for preset in dash_presets() {
        children.push(Line(stroke=Stroke(dash=preset.0)))
      }
      children.append([
        Line(
          stroke=Stroke(
            thickness=Pt(2),
            dash=Pattern(
              [Len(Pt(10)), Len(Pt(5)), Dot, Len(Pt(5))],
              phase=Pt(10),
            ),
          ),
        ),
        Line(
          stroke=Stroke(
            paint=Blue,
            dash=Pattern([Len(Em(1)), Dot], phase=Pt(0)),
          ),
        ),
        // A pattern is inherited; `none` removes it, `auto` and an
        // omitted `dash` keep it.
        Seq([
          Set("line", [("stroke", Value::stroke(Stroke(dash=Dashed)))]),
          Line(),
          Line(stroke=Stroke(dash=None)),
          Line(stroke=Stroke(dash=Auto)),
          Line(stroke=Stroke(thickness=Pt(2))),
        ]),
        // What a script passed while the parameter was a `Value`.
        Line(stroke=Stroke(dash=RawValue(Value::str("dotted")))),
        Line(
          stroke=Stroke(
            dash=RawValue(
              Value::array([Value::length(Pt(4)), Value::str("dot")]),
            ),
          ),
        ),
        Rect(
          width=Pct(100),
          height=Pt(10),
          stroke=Sides(all=Stroke(dash=DenselyDashed, cap="round")),
        ),
      ])
      Document(children)
    }),
    // Colour operations: Typst's methods with the colour as receiver, and
    // `color.mix` with colour-weight pairs in every colour space.
    twin(
      "colour-operations",
      [
        page_typ, "#set rect(width: 100%, height: 5pt);", "#set block(spacing: 2pt);",
        "#rect(fill: rgb(\"#1f4e79\").transparentize(30%))", "#rect(fill: rgb(\"#1f4e79\").transparentize(30%).transparentize(30%))",
        "#rect(fill: rgb(\"#1f4e7933\").transparentize(-50%))", "#rect(fill: rgb(\"#1f4e79\").lighten(25%), stroke: 1pt + red.darken(40%))",
        "#rect(fill: luma(100).darken(12.5%))", "#rect(fill: color.mix((rgb(\"#1f4e79\"), 60%), (rgb(\"#7fc8a9\"), 40%), space: rgb))",
        "#rect(fill: color.mix((rgb(\"#1f4e79\"), 50%), (rgb(\"#7fc8a9\"), 50%)))",
        "#rect(fill: color.mix((red, 75%), (blue, 25%), space: oklab))", "#rect(fill: color.mix((red, 75%), (blue, 25%), space: oklch))",
        "#rect(fill: color.mix((red, 75%), (blue, 25%), space: color.linear-rgb))",
        "#rect(fill: color.mix((red, 75%), (blue, 25%), space: luma))", "#rect(fill: color.mix((red, 75%), (blue, 25%), space: cmyk))",
        "#rect(fill: color.mix((red, 75%), (blue, 25%), space: color.hsl))", "#rect(fill: color.mix((red, 75%), (blue, 25%), space: color.hsv))",
        "#rect(fill: gradient.linear(rgb(\"#1f4e79\").lighten(60%), color.mix((rgb(\"#1f4e79\"), 100%), (white, 0%))))",
        "#text(fill: blue.darken(20%).transparentize(10%))[#\"tinted\"]",
      ],
      () => {
        let blue : Paint = Rgb("#1f4e79")
        let green : Paint = Rgb("#7fc8a9")
        let children : Array[&@doc.IntoContent] = [
          page(),
          SetRect(width=Pct(100), height=Pt(5)),
          Set("block", [("spacing", Value::length(Pt(2)))]),
          // The alpha is scaled, not set; a negative amount adds opacity.
          Rect(fill=blue.transparentize(30)),
          Rect(fill=blue.transparentize(30).transparentize(30)),
          Rect(fill=Paint::transparentize(Rgb("#1f4e7933"), -50)),
          Rect(
            fill=blue.lighten(25),
            stroke=Sides(
              all=Stroke(thickness=Pt(1), paint=Paint::darken(Red, 40)),
            ),
          ),
          Rect(fill=Paint::darken(Luma(100), 12.5)),
          // The other colour gets `weight` percent; the default is half.
          Rect(fill=blue.mix(green, weight=40, space=Srgb)),
          Rect(fill=blue.mix(green)),
        ]
        let spaces : Array[@doc.ColorSpace] = [
          Oklab,
          Oklch,
          LinearRgb,
          Grayscale,
          Cmyk,
          Hsl,
          Hsv,
        ]
        for space in spaces {
          children.push(Rect(fill=Paint::mix(Red, Blue, weight=25, space~)))
        }
        children.append([
          Rect(
            fill=Paint::linear([blue.lighten(60), blue.mix(White, weight=0)]),
          ),
          Text("tinted", fill=Paint::darken(Blue, 20).transparentize(10)),
        ])
        Document(children)
      },
    ),
    // A length where a size or a spacing is expected, text case on content
    // (and on a string value), and the uniform zero of insets.
    twin(
      "conversions-and-case",
      [
        page_typ, "#v(6pt + 0.5em)", "#grid(columns: (6pt + 0.5em, 1fr, 30pt), [#\"a\"], [#\"b\"], [#\"c\"])",
        "#par[#\"x\"#h(30pt)#box(width: 30pt, fill: luma(220))[#\"y\"]]", "#upper[#\"loud\"]",
        "#lower[#[#\"Quiet \"#emph[#\"Words\"]]]", "#par[#\"a \"#upper[#\"b\"]#\" c \"#upper(\"string\")]",
        "#upper[#\"labelled\"]<up>", "#block(inset: 0pt, outset: 0pt, fill: luma(230))[#\"tight\"]",
        "#rect(inset: 0pt)[#\"tight\"]", "#table(inset: 0pt, [#\"cell\"])",
      ],
      () => {
        let gap : Length = Pt(6) + Em(0.5)
        let wide : Length = Pt(30)
        Document([
          page(),
          V(gap.spacing()),
          Grid(["a", "b", "c"], columns=[gap.sizing(), Fr(1), wide.sizing()]),
          Par(
            Seq([
              "x",
              H(wide.spacing()),
              Box("y", width=wide.sizing(), fill=Luma(220)),
            ]),
          ),
          Upper("loud"),
          Lower(Seq(["Quiet ", Emph("Words")])),
          Par(
            Seq([
              "a ",
              Upper("b"),
              " c ",
              // `upper` of a string is the converted string.
              Upper(Value::str("string")),
            ]),
          ),
          Upper("labelled", label="up"),
          Block(
            "tight",
            inset=Sides::zero(),
            outset=Sides::zero(),
            fill=Luma(230),
          ),
          Rect(body="tight", inset=Sides::zero()),
          Table(["cell"], inset=Cells::all(Sides::zero())),
        ])
      },
    ),
  ]
}
