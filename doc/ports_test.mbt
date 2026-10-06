// Tests of the typed additions of docs/edsl-ports.md, sections 3.2 to 3.4:
// `Layout`, the baseline of a measured size, and the typed parameters and
// values. The pairs with a Typst twin are in `doc/twins/ports.mbt`.

///|
/// A number with three decimals, for sizes that depend on font metrics.
fn fixed3(x : Double) -> String {
  if x.is_inf() {
    return if x > 0.0 { "inf" } else { "-inf" }
  }
  let scaled = (x * 1000.0).round().to_int64()
  let sign = if scaled < 0L { "-" } else { "" }
  let scaled = scaled.abs()
  let frac = (scaled % 1000L).to_string().pad_start(3, '0')
  "\{sign}\{scaled / 1000L}.\{frac}"
}

///|
/// The constructor and the argument a diagnostic is located at.
fn origin_arg(diagnostic : @doc.Diagnostic) -> String raise {
  let origin = origin_of(diagnostic)
  match origin.param {
    Some(index) => "\{origin.kind}, argument \{index}"
    None => origin.kind
  }
}

///|
/// The lowered content of a document, as Typst prints it.
fn lowered(children : Array[&@doc.IntoContent]) -> String raise {
  @doc.Document(children).lower(@doc.DocWorld::in_memory()).unwrap().repr()
}

///|
/// The SVG pages of a document on a small page.
fn svg_of(children : Array[&@doc.IntoContent]) -> String raise {
  let page : Array[&@doc.IntoContent] = [
    @doc.SetPage(width=Pt(120), height=Pt(60), margin=@doc.Sides(all=Pt(6))),
    @doc.SetText(size=Pt(10)),
  ]
  page.append(children)
  let report = compile(page)
  if !report.errors.is_empty() {
    fail(error_messages(report))
  }
  report.svg_pages().unwrap().join("\n")
}

///|
test "`Ctx::measure` returns the engine's baseline" {
  let sizes : Map[String, @doc.Size] = Map([])
  let report = compile([
    @doc.SetText(size=Pt(10)),
    @doc.Context() <| cx => {
      // Text with the default edges (cap height to baseline) ...
      sizes["text"] = cx.measure("xg")
      // ... and down to the descender: the baseline is above the bottom.
      sizes["descender"] = cx.measure(@doc.Text("xg", bottom_edge=Descender))
      sizes["ascender"] = cx.measure(
        @doc.Text("xg", top_edge=Ascender, bottom_edge=Descender),
      )
      // Two lines: the baseline of the first.
      sizes["two lines"] = cx.measure(@doc.Seq(["xg", @doc.Linebreak(), "xg"]))
      sizes["empty"] = cx.measure(@doc.Seq([]))
      // A block and a box that are higher than their text.
      sizes["block"] = cx.measure(@doc.Block("xg", height=Pt(30)))
      sizes["inset block"] = cx.measure(
        @doc.Block("xg", inset=@doc.Sides(all=Pt(5))),
      )
      sizes["box"] = cx.measure(@doc.Box("xg", height=Pt(30)))
      sizes["shifted box"] = cx.measure(@doc.Box("xg", baseline=Pt(2)))
      // Without text: a shape.
      sizes["rect"] = cx.measure(@doc.Rect(width=Pt(20), height=Pt(12)))
      sizes["inline rect"] = cx.measure(
        @doc.Box(@doc.Rect(width=Pt(20), height=Pt(12))),
      )
      ""
    },
  ])
  inspect(error_messages(report), content="")
  let lines = sizes
    .iter()
    .map(pair => {
      let (name, size) = pair
      "\{name}: \{fixed3(size.width)} x \{fixed3(size.height)}, baseline \{fixed3(size.baseline)}"
    })
    .collect()
  inspect(
    lines.join("\n"),
    content=(
      #|text: 9.900 x 6.580, baseline 6.580
      #|descender: 9.900 x 9.040, baseline 6.580
      #|ascender: 9.900 x 11.400, baseline 8.940
      #|two lines: 9.900 x 19.660, baseline 6.580
      #|empty: 0.000 x 0.000, baseline 0.000
      #|block: 9.900 x 30.000, baseline 6.580
      #|inset block: 19.900 x 16.580, baseline 11.580
      #|box: 9.900 x 30.000, baseline 6.580
      #|shifted box: 9.900 x 6.580, baseline 4.580
      #|rect: 20.000 x 12.000, baseline 12.000
      #|inline rect: 20.000 x 12.000, baseline 12.000
    ),
  )
}

///|
test "`Layout` passes the size of the enclosing region" {
  let seen : Array[String] = []
  let layout = (name : String) => {
    @doc.Layout() <| ((size, cx) => {
      // The context has a location and styles: `measure` works.
      let measured = cx.measure("xg", width=Pt(size.width))
      let line = "\{name}: \{fixed3(size.width)} x \{fixed3(size.height)}, measured \{fixed3(measured.width)}"
      if !seen.contains(line) {
        seen.push(line)
      }
      @doc.Rect(width=Pt(size.width / 2.0), height=Pt(4))
    })
  }
  let report = compile([
    @doc.SetPage(width=Pt(200), height=Pt(100), margin=@doc.Sides(all=Pt(10))),
    @doc.SetText(size=Pt(10)),
    layout("page"),
    // The base size of the container, not what remains of it.
    @doc.Block(
      @doc.Seq(["above", layout("block")]),
      width=Pt(120),
      height=Pt(40),
    ),
    @doc.Block(layout("auto block"), width=Pct(50)),
    @doc.Box(layout("box"), width=Pt(90)),
    @doc.Box(layout("auto box")),
    @doc.Grid([layout("cell"), "b"], columns=[Pt(70), Fr(1)]),
    @doc.Pad(layout("pad"), x=Pt(15)),
  ])
  inspect(error_messages(report), content="")
  seen.sort()
  inspect(
    seen.join("\n"),
    content=(
      #|box: 90.000 x 80.000, measured 9.900
      #|cell: 70.000 x 80.000, measured 9.900
      #|pad: 150.000 x 80.000, measured 9.900
      #|page: 180.000 x 80.000, measured 9.900
      #|block: 120.000 x 40.000, measured 9.900
      #|auto box: 180.000 x 80.000, measured 9.900
      #|auto block: 90.000 x 80.000, measured 9.900
    ),
  )
}

///|
test "a dimension of a `Layout` region can be infinite" {
  let seen : Array[String] = []
  let layout = (name : String) => {
    @doc.Layout() <| ((size, _) => {
      let line = "\{name}: \{fixed3(size.width)} x \{fixed3(size.height)}"
      if !seen.contains(line) {
        seen.push(line)
      }
      if size.height.is_inf() {
        "unbounded"
      } else {
        "bounded"
      }
    })
  }
  let measured = layout("measured")
  let report = compile([
    // A page that grows with its content has no height.
    @doc.SetPage(width=Pt(200), height=Auto, margin=@doc.Sides(all=Pt(10))),
    layout("auto page"),
    // Measuring lays out in an unbounded region, unless given a size.
    @doc.Context() <| cx => {
      cx.measure(measured) |> ignore
      ""
    },
  ])
  inspect(error_messages(report), content="")
  seen.sort()
  inspect(
    seen.join("\n"),
    content=(
      #|measured: inf x inf
      #|auto page: 180.000 x inf
    ),
  )
  let wide = compile([
    @doc.SetPage(width=Auto, height=Pt(50), margin=@doc.Sides(all=Pt(10))),
    layout("wide page"),
  ])
  inspect(error_messages(wide), content="")
  inspect(
    seen.filter(line => line.has_prefix("wide")).join("\n"),
    content=(
      #|wide page: inf x 30.000
    ),
  )
}

///|
test "a `Layout` cannot be created inside a callback" {
  let nested = compile([
    @doc.Context() <| _ => { @doc.Layout() <| ((_, _) => "inner") },
  ])
  inspect(
    error_messages(nested),
    content="callbacks cannot be created inside a callback",
  )
  inspect(origin_of(nested.errors[0]).kind, content="Layout")
  inspect(
    nested.errors[0].hints.map(h => h.message).join(" | "),
    content="create the callback before compiling and capture it | or use the `cx` of the enclosing callback",
  )
  // The same inside another `Layout`.
  let in_layout = compile([
    @doc.Layout() <| ((_, _) => @doc.Layout() <| ((_, _) => "inner")),
  ])
  inspect(
    error_messages(in_layout),
    content="callbacks cannot be created inside a callback",
  )
  // Created before compiling and captured: fine, also in a show rule that
  // runs several times, and inside another `Layout`.
  let inner = @doc.Layout() <| ((size, _) => {
    @doc.Line(length=Pt(size.width / 4.0))
  })
  let captured = compile([
    @doc.Show(@doc.Select::heading()) <| ((it, _) => @doc.Seq([it, inner])),
    @doc.Heading("One"),
    @doc.Heading("Two"),
    @doc.Layout() <| ((_, _) => @doc.Block(inner, width=Pt(80))),
  ])
  inspect(error_messages(captured), content="")
  // An error raised by the callback is a diagnostic at the `Layout`.
  let failing = compile([
    @doc.Layout() <| ((_, _) => {
      if true {
        fail("boom")
      }
      "unreachable"
    }),
  ])
  assert_true(failing.errors[0].message.contains("boom"))
  inspect(origin_of(failing.errors[0]).kind, content="Layout")
  // Its description.
  debug_inspect(
    inner,
    content=(
      #|Layout(<callback of Layout>)
    ),
  )
}

///|
test "`Box(baseline=)` is the shift form; the other forms go through `extra`" {
  inspect(
    lowered([@doc.Box("x", baseline=Pt(2))]),
    content=(
      #|box(baseline: (shift: 0% + 2pt), body: [x])
    ),
  )
  inspect(
    lowered([@doc.Box("x", baseline=Pct(-40) + Pt(1))]),
    content=(
      #|box(baseline: (shift: -40% + 1pt), body: [x])
    ),
  )
  // The alignment form and the dictionary form.
  inspect(
    lowered([
      @doc.Box("x", extra=[("baseline", @doc.Value::alignment(Horizon))]),
    ]),
    content=(
      #|box(baseline: (at: horizon), body: [x])
    ),
  )
  inspect(
    lowered([
      @doc.Box("x", extra=[
        (
          "baseline",
          @doc.Value::dict([
            ("at", @doc.Value::alignment(Bottom)),
            ("shift", @doc.Value::length(Pt(10))),
          ]),
        ),
      ]),
    ]),
    content=(
      #|box(
      #|  baseline: (at: bottom, shift: 0% + 10pt),
      #|  body: [x],
      #|)
    ),
  )
  // The set rule, and what the field does not accept.
  inspect(
    error_messages(compile([@doc.SetBox(baseline=Em(0.2)), @doc.Box("x")])),
    content="",
  )
  let none = compile([@doc.Box("x", baseline=None)])
  inspect(
    error_messages(none),
    content=(
      #|expected alignment, auto, relative length, or dictionary, found none
    ),
  )
  inspect(
    origin_arg(none.errors[0]),
    content=(
      #|Box, argument 3
    ),
  )
}

///|
test "`top_edge` and `bottom_edge` lower to the engine's names" {
  let top : Array[@doc.TopEdge] = [
    Ascender,
    CapHeight,
    XHeight,
    Baseline,
    Bounds,
    Len(Em(0.7)),
  ]
  let bottom : Array[@doc.BottomEdge] = [
    Baseline,
    Descender,
    Bounds,
    Len(Pt(-2)),
  ]
  inspect(
    top.map(edge => lowered([@doc.Highlight("x", top_edge=edge)])).join("\n"),
    content=(
      #|highlight(top-edge: "ascender", body: [x])
      #|highlight(top-edge: "cap-height", body: [x])
      #|highlight(top-edge: "x-height", body: [x])
      #|highlight(top-edge: "baseline", body: [x])
      #|highlight(top-edge: "bounds", body: [x])
      #|highlight(top-edge: 0.7em, body: [x])
    ),
  )
  inspect(
    bottom
    .map(edge => lowered([@doc.Highlight("x", bottom_edge=edge)]))
    .join("\n"),
    content=(
      #|highlight(bottom-edge: "baseline", body: [x])
      #|highlight(bottom-edge: "descender", body: [x])
      #|highlight(bottom-edge: "bounds", body: [x])
      #|highlight(bottom-edge: -2pt, body: [x])
    ),
  )
  // On `Text` (whose lowered form is styled content, which does not print
  // its styles) the edges are measured: each gives the height that the
  // untyped argument gave before, and the heights differ by edge.
  let heights : Array[String] = []
  let report = compile([
    @doc.SetText(size=Pt(10)),
    @doc.Context() <| cx => {
      heights.clear()
      for edge in top {
        let typed = cx.measure(@doc.Text("xg", top_edge=edge))
        let untyped = cx.measure(
          @doc.Text("xg", extra=[("top-edge", @doc.ToValue::to_value(edge))]),
        )
        assert_eq(typed.height, untyped.height)
        heights.push("top \{fixed3(typed.height)}")
      }
      for edge in bottom {
        let typed = cx.measure(@doc.Text("xg", bottom_edge=edge))
        let untyped = cx.measure(
          @doc.Text("xg", extra=[("bottom-edge", @doc.ToValue::to_value(edge))]),
        )
        assert_eq(typed.height, untyped.height)
        heights.push("bottom \{fixed3(typed.height)}")
      }
      ""
    },
  ])
  inspect(error_messages(report), content="")
  inspect(
    heights.join(", "),
    content=(
      #|top 8.940, top 6.580, top 4.290, top 0.000, top 4.620, top 7.000, bottom 6.580, bottom 9.040, bottom 8.960, bottom 8.580
    ),
  )
  assert_eq(
    svg_of([@doc.SetText(top_edge=Bounds, bottom_edge=Bounds), "xg"]),
    svg_of([
      @doc.SetText(extra=[
        ("top-edge", @doc.Value::str("bounds")),
        ("bottom-edge", @doc.Value::str("bounds")),
      ]),
      "xg",
    ]),
  )
  assert_eq(
    svg_of([@doc.Text("xg", top_edge=Len(Pt(9)), bottom_edge=Descender)]),
    svg_of([@doc.Markup("#text(top-edge: 9pt, bottom-edge: \"descender\")[xg]")]),
  )
  // A name of the other edge is still reachable untyped, and is Typst's
  // cast error there.
  let wrong = compile([
    @doc.Text("x", extra=[("top-edge", @doc.Value::str("descender"))]),
  ])
  inspect(
    error_messages(wrong),
    content=(
      #|expected "ascender", "cap-height", "x-height", "baseline", "bounds", or length
    ),
  )
  // A ratio is not an edge.
  let ratio = compile([@doc.Highlight("x", bottom_edge=Len(Pct(10)))])
  inspect(
    error_messages(ratio),
    content=(
      #|expected "baseline", "descender", "bounds", or length, found ratio
    ),
  )
  inspect(origin_of(ratio.errors[0]).kind, content="Highlight")
}
