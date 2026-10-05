// Snapshots of the translator's output (docs/edsl-convert.md, sections
// 4.2 to 4.5): calls, typed values, value forms and rules. Record with
// `moon test --target native -p moonbitlang/typst/doc/convert -u`.

///|
let library : @library.Library = @doc.standard_library()

///|
/// The translation of a document: its tier and the body, without the
/// `Document([..])` wrapper where the document is one line.
fn tr(source : String) -> String {
  let translation = @convert.translate(source, "main.typ", library)
  let body = translation.body
  let body = match (body.strip_prefix("Document(["), body.strip_suffix("])")) {
    (Some(_), Some(_)) =>
      body.view(start_offset=10, end_offset=body.length() - 2).to_owned()
    _ => body
  }
  "\{translation.tier}: \{body}"
}

///|
test "typed constructors: positional matching" {
  inspect(
    tr("#strong[a]"),
    content=(
      #|T1: Strong(Seq([Lit("a")]))
    ),
  )
  inspect(
    tr("#link(\"https://typst.app\")"),
    content=(
      #|T1: Link(Url("https://typst.app"))
    ),
  )
  inspect(
    tr("#link(\"https://typst.app\")[site]"),
    content=(
      #|T1: Link(Url("https://typst.app"), body=Seq([Lit("site")]))
    ),
  )
  inspect(
    tr("#link(<intro>)[there]"),
    content=(
      #|T1: Link(ToLabel("intro"), body=Seq([Lit("there")]))
    ),
  )
  inspect(
    tr("#enum.item[a]"),
    content=(
      #|T1: EnumItem(Seq([Lit("a")]))
    ),
  )
  inspect(
    tr("#enum.item(3)[a]"),
    content=(
      #|T1: EnumItem(Seq([Lit("a")]), number=3)
    ),
  )
  inspect(
    tr("#place(top)[a]"),
    content=(
      #|T1: Place(Seq([Lit("a")]), alignment=Top)
    ),
  )
  inspect(
    tr("#align(center)[a]"),
    content=(
      #|T1: Align(Center, Seq([Lit("a")]))
    ),
  )
  inspect(
    tr("#table(columns: (1fr, auto), [a], [b])"),
    content=(
      #|T1: Table([Seq([Lit("a")]), Seq([Lit("b")])], columns=[Fr(1.0), Auto])
    ),
  )
  inspect(
    tr("#stack(dir: ltr, [a], 5pt, [b])"),
    content=(
      #|T2: Stack([Seq([Lit("a")]), Value::length(Pt(5.0)), Seq([Lit("b")])], dir=Ltr)
    ),
  )
  inspect(
    tr("#polygon((0pt, 0pt), (10pt, 0pt), (5pt, 8pt))"),
    content=(
      #|T1: Polygon([(Pt(0.0), Pt(0.0)), (Pt(10.0), Pt(0.0)), (Pt(5.0), Pt(8.0))])
    ),
  )
  inspect(
    tr("#rect()"),
    content=(
      #|T1: Rect()
    ),
  )
  inspect(
    tr("#rect[a]"),
    content=(
      #|T1: Rect(body=Seq([Lit("a")]))
    ),
  )
  inspect(
    tr("#lorem(5)"),
    content=(
      #|T1: Lorem(5)
    ),
  )
  // The target of a reference and the key of a citation are label names.
  inspect(
    tr("#ref(<intro>)"),
    content=(
      #|T1: Ref("intro")
    ),
  )
  inspect(
    tr("#cite(<key>, form: \"prose\")"),
    content=(
      #|T1: Cite("key", form="prose")
    ),
  )
}

///|
test "typed constructors: what does not fit is a generic call" {
  // No body: the constructor requires one.
  inspect(
    tr("#block(width: 10pt)"),
    content=(
      #|T2: Call("block", named=[("width", Value::length(Pt(10.0)))])
    ),
  )
  // Two positional arguments for one positional field.
  inspect(
    tr("#text(red)[a]"),
    content=(
      #|T2: Call("text", positional=[Value::global("red"), Value::content(Seq([Lit("a")]))])
    ),
  )
  // A field that Typst takes positionally only, by name.
  inspect(
    tr("#heading(body: [a])"),
    content=(
      #|T2: Call("heading", named=[("body", Value::content(Seq([Lit("a")])))])
    ),
  )
  // A spread.
  inspect(
    tr("#grid(..([a], [b]), columns: 2)"),
    content=(
      #|T2: Call("grid", positional=[Value::spread(Value::array([Value::content(Seq([Lit("a")])), Value::content(Seq([Lit("b")]))]))], named=[("columns", Value::int(2))])
    ),
  )
  // A required argument without a typed form.
  inspect(
    tr("#raw(none)"),
    content=(
      #|T2: Call("raw", positional=[Value::none()])
    ),
  )
  // The key of a citation is a label, not a string.
  inspect(
    tr("#cite(\"key\")"),
    content=(
      #|T2: Call("cite", positional=[Value::str("key")])
    ),
  )
  // A path without a constructor in the table.
  inspect(
    tr("#calc.max(1, 2.5)"),
    content=(
      #|T2: Call("calc.max", positional=[Value::int(1), Value::float(2.5)])
    ),
  )
  inspect(
    tr("#math.equation(block: true)[x]"),
    content=(
      #|T2: Call("math.equation", positional=[Value::content(Seq([Lit("x")]))], named=[("block", Value::bool(true))])
    ),
  )
}

///|
test "calls that are not typed" {
  // `label` and `eval` can return labels.
  inspect(
    tr("#label(\"a\")"),
    content=(
      #|T3: Markup("#label(\"a\")")
    ),
  )
  inspect(
    tr("a #eval(\"1\")"),
    content=(
      #|T3: Markup("a #eval(\"1\")")
    ),
  )
  // Methods, operators, closures and user functions have no value form.
  inspect(
    tr("#rect(fill: red.lighten(50%))"),
    content=(
      #|T3: Markup("#rect(fill: red.lighten(50%))")
    ),
  )
  inspect(
    tr("#rect(width: 2 * 5pt)"),
    content=(
      #|T2: Rect(extra=[("width", Value::mul(Value::int(2), Value::length(Pt(5.0))))])
    ),
  )
  inspect(
    tr("#table(fill: (x, y) => red)[a]"),
    content=(
      #|T3: Markup("#table(fill: (x, y) => red)[a]")
    ),
  )
  inspect(
    tr("#unknown-function(1)"),
    content=(
      #|T3: Markup("#unknown-function(1)")
    ),
  )
  // A spread after a named argument.
  inspect(
    tr("#rect(fill: red, ..(fill: blue))"),
    content=(
      #|T3: Markup("#rect(fill: red, ..(fill: blue))")
    ),
  )
}

///|
test "extra: named arguments without a typed form" {
  inspect(
    tr("#text(top-edge: \"x-height\")[a]"),
    content=(
      #|T2: Text(Seq([Lit("a")]), extra=[("top-edge", Value::str("x-height"))])
    ),
  )
  inspect(
    tr("#heading(level: auto)[a]"),
    content=(
      #|T2: Heading(Seq([Lit("a")]), extra=[("level", Value::auto())])
    ),
  )
  inspect(
    tr("#rect(stroke: (paint: red, thickness: 1pt))"),
    content=(
      #|T2: Rect(extra=[("stroke", Value::dict([("paint", Value::global("red")), ("thickness", Value::length(Pt(1.0)))]))])
    ),
  )
  inspect(
    tr("#table(columns: 3)[a]"),
    content=(
      #|T2: Table([Seq([Lit("a")])], extra=[("columns", Value::int(3))])
    ),
  )
  inspect(
    tr("#heading(numbering: [a])[b]"),
    content=(
      #|T2: Heading(Seq([Lit("b")]), extra=[("numbering", Value::content(Seq([Lit("a")])))])
    ),
  )
  // An optional positional field: in its positional place.
  inspect(
    tr("#rotate(none)[a]"),
    content=(
      #|T2: Rotate(Seq([Lit("a")]), extra=[("angle", Value::none())])
    ),
  )
  inspect(
    tr("#columns(auto)[a]"),
    content=(
      #|T2: Columns(Seq([Lit("a")]), extra=[("count", Value::auto())])
    ),
  )
}

///|
test "evaluation order" {
  // Named arguments that are total may stand before the body.
  inspect(
    tr("#text(fill: red, size: 12pt)[a #strong[b]]"),
    content=(
      #|T1: Text(Seq([Lit("a"), Space(), Strong(Seq([Lit("b")]))]), size=Pt(12.0), fill=Red)
    ),
  )
  // `rgb(..)` is not total and is lowered after the body.
  inspect(
    tr("#text(fill: rgb(\"#f00\"))[a #lorem(2)]"),
    content=(
      #|T3: Markup("#text(fill: rgb(\"#f00\"))[a #lorem(2)]")
    ),
  )
  // A body that is total may be lowered before it.
  inspect(
    tr("#text(fill: rgb(\"#f00\"))[a *b*]"),
    content=(
      #|T1: Text(Seq([Lit("a"), Space(), Strong(Seq([Lit("b")]))]), fill=Rgb("#f00"))
    ),
  )
  // The generic call lowers positional arguments first.
  inspect(
    tr("#calc.max(1, calc.min(2, 3))"),
    content=(
      #|T2: Call("calc.max", positional=[Value::int(1), Value::call("calc.min", positional=[Value::int(2), Value::int(3)])])
    ),
  )
  inspect(
    tr("#figure(caption: [a #lorem(1)], rect())"),
    content=(
      #|T3: Markup("#figure(caption: [a #lorem(1)], rect())")
    ),
  )
}

///|
test "typed values: lengths, sizes and angles" {
  inspect(
    tr("#rect(width: 50%, height: 1em + 2pt)"),
    content=(
      #|T1: Rect(width=Pct(50.0), height=Rel(Sum(Em(1.0), Pt(2.0))))
    ),
  )
  inspect(
    tr("#rect(width: -(1pt - 50%), height: auto)"),
    content=(
      #|T1: Rect(width=Neg(Diff(Pt(1.0), Pct(50.0))), height=Auto)
    ),
  )
  inspect(
    tr("#h(1fr) #v(-3pt) #v(1em, weak: true)"),
    content=(
      #|T1: H(Fr(1.0)), Space(), V(Rel(Neg(Pt(3.0)))), Space(), V(Em(1.0), weak=true)
    ),
  )
  inspect(
    tr("#rotate(10deg)[a]"),
    content=(
      #|T1: Rotate(Seq([Lit("a")]), angle=Deg(10.0))
    ),
  )
  // The facades have no negation of angles and fractions.
  inspect(
    tr("#rotate(-10deg)[a]"),
    content=(
      #|T3: Markup("#rotate(-10deg)[a]")
    ),
  )
  inspect(
    tr("#line(start: (0pt, 1pt), end: (10pt, 50%))"),
    content=(
      #|T1: Line(start=(Pt(0.0), Pt(1.0)), end_=(Pt(10.0), Pct(50.0)))
    ),
  )
  inspect(
    tr("#grid(columns: 1fr, rows: (auto, 10pt, 1pt + 1em), gutter: auto)"),
    content=(
      #|T1: Grid([], columns=[Fr(1.0)], rows=[Auto, Pt(10.0), Rel(Sum(Pt(1.0), Em(1.0)))], gutter=[Auto])
    ),
  )
}

///|
test "typed values: paints and strokes" {
  inspect(
    tr("#rect(fill: red)"),
    content=(
      #|T1: Rect(fill=Red)
    ),
  )
  inspect(
    tr("#rect(fill: rgb(\"#1f4e79\"))"),
    content=(
      #|T1: Rect(fill=Rgb("#1f4e79"))
    ),
  )
  inspect(
    tr("#rect(fill: luma(240))"),
    content=(
      #|T1: Rect(fill=Luma(240))
    ),
  )
  inspect(
    tr("#rect(fill: none)"),
    content=(
      #|T1: Rect(fill=None)
    ),
  )
  inspect(
    tr("#rect(fill: gradient.linear(red, blue))"),
    content=(
      #|T2: Rect(fill=Value(Value::call("gradient.linear", positional=[Value::global("red"), Value::global("blue")])))
    ),
  )
  inspect(
    tr("#rect(fill: tiling(size: (4pt, 4pt))[a])"),
    content=(
      #|T1: Rect(fill=Paint::tiling(Seq([Lit("a")]), size=(Pt(4.0), Pt(4.0))))
    ),
  )
  inspect(
    tr("#line(stroke: 2pt)"),
    content=(
      #|T1: Line(stroke=Stroke(thickness=Pt(2.0)))
    ),
  )
  inspect(
    tr("#line(stroke: red)"),
    content=(
      #|T1: Line(stroke=Stroke(paint=Red))
    ),
  )
  inspect(
    tr("#line(stroke: 2pt + red)"),
    content=(
      #|T1: Line(stroke=Stroke(paint=Red, thickness=Pt(2.0)))
    ),
  )
  inspect(
    tr("#line(stroke: rgb(\"#f00\") + 2pt)"),
    content=(
      #|T1: Line(stroke=Stroke(paint=Rgb("#f00"), thickness=Pt(2.0)))
    ),
  )
  inspect(
    tr("#line(stroke: none)"),
    content=(
      #|T1: Line(stroke=Stroke::none())
    ),
  )
  // A ratio or a relative length is no stroke shorthand.
  inspect(
    tr("#line(stroke: 50%)"),
    content=(
      #|T2: Line(extra=[("stroke", Value::length(Pct(50.0)))])
    ),
  )
  inspect(
    tr("#line(stroke: (1pt + 1em) + red)"),
    content=(
      #|T2: Line(extra=[("stroke", Value::add(Value::add(Value::length(Pt(1.0)), Value::length(Em(1.0))), Value::global("red")))])
    ),
  )
}

///|
test "typed values: sides, corners and cells" {
  inspect(
    tr("#block(inset: 5pt, outset: (x: 1pt, top: 2pt))[a]"),
    content=(
      #|T1: Block(Seq([Lit("a")]), inset=Sides(all=Pt(5.0)), outset=Sides(x=Pt(1.0), top=Pt(2.0)))
    ),
  )
  inspect(
    tr("#block(radius: (top-left: 4pt, rest: 2pt))[a]"),
    content=(
      #|T1: Block(Seq([Lit("a")]), radius=Corners(top_left=Pt(4.0), rest=Pt(2.0)))
    ),
  )
  inspect(
    tr("#block(stroke: (top: red), inset: auto)[a]"),
    content=(
      #|T2: Block(Seq([Lit("a")]), inset=Sides::auto(), extra=[("stroke", Value::dict([("top", Value::global("red"))]))])
    ),
  )
  // A component that is not total: the dictionary stays one.
  inspect(
    tr("#block(inset: (x: 1pt + 2pt))[a]"),
    content=(
      #|T2: Block(Seq([Lit("a")]), extra=[("inset", Value::dict([("x", Value::add(Value::length(Pt(1.0)), Value::length(Pt(2.0))))]))])
    ),
  )
  // A dictionary of stroke fields stays one.
  inspect(
    tr("#block(stroke: (paint: red))[a]"),
    content=(
      #|T2: Block(Seq([Lit("a")]), extra=[("stroke", Value::dict([("paint", Value::global("red"))]))])
    ),
  )
  inspect(
    tr(
      "#table(align: (left, center), fill: red, inset: (x: 1pt), stroke: none)[a]",
    ),
    content=(
      #|T1: Table([Seq([Lit("a")])], inset=Cells::all(Sides(x=Pt(1.0))), align=Cells::columns([Left, Center]), fill=Cells::all(Red), stroke=Cells::all(Sides::none()))
    ),
  )
}

///|
test "typed values: constants, strings and supplements" {
  inspect(
    tr("#align(center + horizon)[a]"),
    content=(
      #|T1: Align(Both(Center, Horizon), Seq([Lit("a")]))
    ),
  )
  inspect(
    tr("#align(top + (center + bottom))[a]"),
    content=(
      #|T2: Call("align", positional=[Value::add(Value::global("top"), Value::add(Value::global("center"), Value::global("bottom"))), Value::content(Seq([Lit("a")]))])
    ),
  )
  inspect(
    tr("#text(dir: rtl, weight: \"bold\", font: \"Libertinus Serif\")[a]"),
    content=(
      #|T1: Text(Seq([Lit("a")]), font=["Libertinus Serif"], weight=Bold, dir=Rtl)
    ),
  )
  inspect(
    tr("#text(weight: 700, font: (\"A\", \"B\"), lang: \"de\")[a]"),
    content=(
      #|T1: Text(Seq([Lit("a")]), font=["A", "B"], weight=Weight(700), lang="de")
    ),
  )
  inspect(
    tr("#heading(numbering: \"1.\", supplement: [Sec])[a]"),
    content=(
      #|T1: Heading(Seq([Lit("a")]), numbering=Numbering("1."), supplement=Supplement(Seq([Lit("Sec")])))
    ),
  )
  inspect(
    tr("#heading(numbering: none, supplement: none)[a]"),
    content=(
      #|T1: Heading(Seq([Lit("a")]), numbering=Numbering::none(), supplement=Supplement::none())
    ),
  )
  inspect(
    tr("#figure(caption: \"a\", supplement: \"Fig\")[b]"),
    content=(
      #|T1: Figure(Seq([Lit("b")]), caption="a", supplement=Supplement("Fig"))
    ),
  )
  inspect(
    tr("#image(\"a.png\", width: 50%)"),
    content=(
      #|T1: Image("a.png", width=Pct(50.0))
    ),
  )
  inspect(
    tr("#outline(title: none, indent: auto)"),
    content=(
      #|T1: Outline(title=NoneValue(), indent=Auto)
    ),
  )
}

///|
test "value forms" {
  inspect(
    tr(
      "#metadata((a: 1, \"b c\": -2.5, d: (1pt, 50%, 1fr, 10deg, none, auto, true, \"s\")))",
    ),
    content=(
      #|T2: Metadata(Value::dict([("a", Value::int(1)), ("b c", Value::float(-2.5)), ("d", Value::array([Value::length(Pt(1.0)), Value::length(Pct(50.0)), Value::fr(1.0), Value::angle(Deg(10.0)), Value::none(), Value::auto(), Value::bool(true), Value::str("s")]))]))
    ),
  )
  inspect(
    tr("#metadata(<a>)"),
    content=(
      #|T2: Metadata(Value::label("a"))
    ),
  )
  inspect(
    tr("#metadata([a *b*])"),
    content=(
      #|T2: Metadata(Value::content(Seq([Lit("a"), Space(), Strong(Seq([Lit("b")]))])))
    ),
  )
  inspect(
    tr("#metadata(red)"),
    content=(
      #|T2: Metadata(Value::global("red"))
    ),
  )
  inspect(
    tr("#metadata(calc.pi)"),
    content=(
      #|T2: Metadata(Value::global("calc.pi"))
    ),
  )
  inspect(
    tr("#metadata(rect(width: 1pt))"),
    content=(
      #|T2: Metadata(Value::call("rect", named=[("width", Value::length(Pt(1.0)))]))
    ),
  )
  inspect(
    tr("#metadata(-1pt)"),
    content=(
      #|T2: Metadata(Value::length(Neg(Pt(1.0))))
    ),
  )
  // No form: spreads, computed keys, operators, closures, field accesses.
  inspect(
    tr("#metadata((..(1, 2), 3))"),
    content=(
      #|T3: Markup("#metadata((..(1, 2), 3))")
    ),
  )
  inspect(
    tr("#metadata(((\"a\" + \"b\"): 1))"),
    content=(
      #|T3: Markup("#metadata(((\"a\" + \"b\"): 1))")
    ),
  )
  inspect(
    tr("#metadata(1 + 2)"),
    content=(
      #|T2: Metadata(Value::add(Value::int(1), Value::int(2)))
    ),
  )
  inspect(
    tr("#metadata(x => x)"),
    content=(
      #|T3: Markup("#metadata(x => x)")
    ),
  )
  inspect(
    tr("#metadata((a: 1).a)"),
    content=(
      #|T3: Markup("#metadata((a: 1).a)")
    ),
  )
  // Values in a stream are displayed.
  inspect(
    tr("#red #1 #none"),
    content=(
      #|T2: Keyed("1", Value::global("red")), Space(), Keyed("2", Value::int(1)), Space(), Keyed("3", Value::none())
    ),
  )
}

///|
test "translated variables" {
  inspect(
    tr(
      "#let w = 10pt\n#let c = red\n#let n = 2\n#let s = \"a\"\n#rect(width: w, fill: c)[#s]#lorem(n)#metadata((w, c, n, s))",
    ),
    content=(
      #|T2: let v_w : @doc.Length = Pt(10.0)
      #|let v_c : @doc.Paint = @doc.Paint::Red
      #|let v_n : Int64 = 2
      #|let v_s : String = "a"
      #|Document([Seq([]), Seq([]), Seq([]), Seq([]), Rect(width=v_w, fill=v_c, body=Seq([Lit(v_s)])), Lorem(v_n), Metadata(Value::array([Value::length(v_w), Value::paint(v_c), Value::int(v_n), Value::str(v_s)]))])
    ),
  )
  // A stroke is typed only from a literal length and a constant colour.
  inspect(
    tr("#let w = 10pt\n#line(stroke: w)"),
    content=(
      #|T2: let v_w : @doc.Length = Pt(10.0)
      #|Document([Seq([]), Line(extra=[("stroke", Value::length(v_w))])])
    ),
  )
}

///|
test "set rules" {
  inspect(
    tr("#set text(11pt, red, lang: \"en\")"),
    content=(
      #|T1: SetText(size=Pt(11.0), fill=Red, lang="en")
    ),
  )
  inspect(
    tr("#set text(red, 11pt)"),
    content=(
      #|T1: SetText(size=Pt(11.0), fill=Red)
    ),
  )
  inspect(
    tr("#set text(50%)"),
    content=(
      #|T2: Set("text", [], positional=[Value::length(Pct(50.0))])
    ),
  )
  inspect(
    tr("#set text(11pt, size: 12pt)"),
    content=(
      #|T2: Set("text", [("size", Value::length(Pt(12.0)))], positional=[Value::length(Pt(11.0))])
    ),
  )
  inspect(
    tr("#set page(\"a4\", margin: (x: 1cm, rest: auto))"),
    content=(
      #|T2: Set("page", [("margin", Value::dict([("x", Value::length(Cm(1.0))), ("rest", Value::auto())]))], positional=[Value::str("a4")])
    ),
  )
  inspect(
    tr("#set page(paper: \"a5\", header: none, numbering: \"1\")"),
    content=(
      #|T1: SetPage(paper="a5", numbering=Numbering("1"), header=NoneValue())
    ),
  )
  inspect(
    tr("#set align(center)"),
    content=(
      #|T1: SetAlign(alignment=Center)
    ),
  )
  inspect(
    tr("#set enum.item(3)"),
    content=(
      #|T1: SetEnumItem(number=3)
    ),
  )
  inspect(
    tr("#set block(spacing: 1em)"),
    content=(
      #|T1: SetBlock(spacing=Em(1.0))
    ),
  )
  inspect(
    tr("#set par(first-line-indent: 1em, justify: true)"),
    content=(
      #|T2: SetPar(justify=true, extra=[("first-line-indent", Value::length(Em(1.0)))])
    ),
  )
  inspect(
    tr("#set figure.caption(separator: [: ])"),
    content=(
      #|T2: Set("figure.caption", [("separator", Value::content(Seq([Lit(":"), Space()])))])
    ),
  )
  inspect(
    tr("#set text(red) if true"),
    content=(
      #|T3: Markup("#set text(red) if true")
    ),
  )
  inspect(
    tr("#set calc.max(1)"),
    content=(
      #|T3: Markup("#set calc.max(1)")
    ),
  )
  inspect(
    tr("#set text(..(size: 1pt))"),
    content=(
      #|T2: Set("text", [], positional=[Value::spread(Value::dict([("size", Value::length(Pt(1.0)))]))])
    ),
  )
}

///|
test "show-set rules and selectors" {
  inspect(
    tr("#show heading: set text(blue)"),
    content=(
      #|T1: ShowSet(Select::heading(), SetText(fill=Blue))
    ),
  )
  inspect(
    tr("#show heading.where(level: 1): set text(14pt)"),
    content=(
      #|T1: ShowSet(Select::heading(level=1), SetText(size=Pt(14.0)))
    ),
  )
  inspect(
    tr("#show \"a\": set text(red)"),
    content=(
      #|T1: ShowSet(Select::literal("a"), SetText(fill=Red))
    ),
  )
  inspect(
    tr("#show regex(\"\\d+\"): set text(red)"),
    content=(
      #|T1: ShowSet(Select::regex("\\d+"), SetText(fill=Red))
    ),
  )
  inspect(
    tr("#show <a>: set text(red)"),
    content=(
      #|T1: ShowSet(Select::label("a"), SetText(fill=Red))
    ),
  )
  inspect(
    tr("#show figure.caption: set text(8pt)"),
    content=(
      #|T2: ShowSet(Select::elem("figure.caption"), SetText(size=Pt(8.0)))
    ),
  )
  inspect(
    tr("#show math.equation.where(block: true): set block(above: 1em)"),
    content=(
      #|T1: ShowSet(Select::equation(block=true), SetBlock(above=Em(1.0)))
    ),
  )
  // A constructor shorthand is no selector value.
  inspect(
    tr("#show line.where(stroke: 1pt): set line(length: 1pt)"),
    content=(
      #|T2: ShowSet(Select::elem("line", where_=[("stroke", Value::length(Pt(1.0)))]), SetLine(length=Pt(1.0)))
    ),
  )
  inspect(
    tr("#show figure.where(kind: table): set text(red)"),
    content=(
      #|T2: ShowSet(Select::elem("figure", where_=[("kind", Value::global("table"))]), SetText(fill=Red))
    ),
  )
  inspect(
    tr("#show: set text(red)"),
    content=(
      #|T3: Markup("#show: set text(red)")
    ),
  )
  inspect(
    tr("#show heading.or(strong): set text(red)"),
    content=(
      #|T3: Markup("#show heading.or(strong): set text(red)")
    ),
  )
}

///|
test "show rules: callbacks" {
  inspect(
    tr("#show heading: it => block(fill: red, it)"),
    content=(
      #|T1: Show(Select::heading(), (v_it, _) => Block(v_it, fill=Red))
    ),
  )
  inspect(
    tr("#show emph: it => [(#it)]"),
    content=(
      #|T1: Show(Select::emph(), (v_it, _) => Seq([Lit("("), v_it, Lit(")")]))
    ),
  )
  inspect(
    tr("#show emph: it => [a]"),
    content=(
      #|T1: Show(Select::emph(), (_, _) => Seq([Lit("a")]))
    ),
  )
  // A field of the view, a code block: the Typst closure in a fragment.
  inspect(
    tr("#show heading: it => [#it.body!]"),
    content=(
      #|T3: Show(Select::heading(), (v_it, _) => Markup("#(it => [#it.body!])(it1)", scope=[("it1", Value::content(v_it))]))
    ),
  )
  inspect(
    tr("#show strong: it => { set text(red); it }"),
    content=(
      #|T3: Show(Select::strong(), (v_it, _) => Markup("#(it => { set text(red); it })(it1)", scope=[("it1", Value::content(v_it))]))
    ),
  )
  inspect(
    tr("#let c = red\n#show strong: x => text(fill: c, x.body)"),
    content=(
      #|T3: let v_c : @doc.Paint = @doc.Paint::Red
      #|Document([Seq([]), Show(Select::strong(), (v_x, _) => Markup("#(x => text(fill: c, x.body))(it)", scope=[("it", Value::content(v_x)), ("c", Value::paint(v_c))]))])
    ),
  )
  // A nested rule with a callback is no typed callback.
  inspect(
    tr("#show heading: it => [#show emph: x => [a];#it]"),
    content=(
      #|T3: Show(Select::heading(), (v_it, _) => Markup("#(it => [#show emph: x => [a];#it])(it1)", scope=[("it1", Value::content(v_it))]))
    ),
  )
  // Not proven to be no label; other parameter shapes.
  inspect(
    tr("#show heading: it => it.body"),
    content=(
      #|T3: Markup("#show heading: it => it.body")
    ),
  )
  inspect(
    tr("#show heading: (it, x: 1) => [a]"),
    content=(
      #|T3: Markup("#show heading: (it, x: 1) => [a]")
    ),
  )
  inspect(
    tr("#show heading: _ => [a]"),
    content=(
      #|T3: Markup("#show heading: _ => [a]")
    ),
  )
}

///|
test "show rules: value transformations" {
  inspect(
    tr("#show link: underline"),
    content=(
      #|T2: ShowWith(Select::link(), Value::global("underline"))
    ),
  )
  inspect(
    tr("#show \"a\": [b]"),
    content=(
      #|T2: ShowWith(Select::literal("a"), Value::content(Seq([Lit("b")])))
    ),
  )
  inspect(
    tr("#show \"a\": \"b\""),
    content=(
      #|T2: ShowWith(Select::literal("a"), Value::str("b"))
    ),
  )
  inspect(
    tr("#show: columns.with(2)"),
    content=(
      #|T2: ShowWith::all(Value::call("function.with", positional=[Value::global("columns"), Value::int(2)]))
    ),
  )
  inspect(
    tr("#show: strong"),
    content=(
      #|T2: ShowWith::all(Value::global("strong"))
    ),
  )
  inspect(
    tr("#show: it => [a #it]"),
    content=(
      #|T3: Markup("#show: it => [a #it]")
    ),
  )
}

///|
test "final review: local bindings, variable names, strings in prose" {
  // A name that the expression binds itself may hold a label: the stream
  // is the fragment, not the expression.
  inspect(
    tr("#heading[H] #{ let x = <target>; x }"),
    content=(
      #|T3: Markup("#heading[H] #{ let x = <target>; x }")
    ),
  )
  // An expression without bindings of its own stays an item.
  inspect(
    tr("#heading[H] #for i in range(2) [a]"),
    content=(
      #|T3: Heading(Seq([Lit("H")])), Space(), Markup("#for i in range(2) [a]")
    ),
  )
  // Every emitted identifier is reserved.
  inspect(
    tr("#let a-b = 1;#let a_b = 2;#let a_b_2 = 3;#a_b"),
    content=(
      #|T2: let v_a_b : Int64 = 1
      #|let v_a_b_2 : Int64 = 2
      #|let v_a_b_2_2 : Int64 = 3
      #|Document([Seq([]), Seq([]), Seq([]), Keyed("1", Value::int(v_a_b_2))])
    ),
  )
  // The readable mode: a string is a text of its own.
  let prose = @convert.translate("a#\"b\"c", "main.typ", library, prose=true)
  inspect(
    prose.body,
    content=(
      #|Document([Prose("a\{Lit("b")}c")])
    ),
  )
}
