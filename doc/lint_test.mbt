// Lints (docs/edsl-ports.md, section 6): the report's `lints`, and L1,
// adjacent inline items. The finding itself (S1) is pinned in
// `ports_findings_test.mbt`; the block list is checked against the engine
// in `lint_wbtest.mbt`.

///|
/// The lints of a document built from `children`, one line each
/// (`lint_lines`), without compiling more than the lowering.
fn lints_of(children : Array[&@doc.IntoContent]) -> String {
  lint_lines(compile(children))
}

///|
test "lint L1: neighbours that are text, in an array that holds a block" {
  // Text: a string, a `Prose`, and `Text`, `Strong`, `Emph` and `Link`
  // around one. Each pair of neighbours is reported at the text of its
  // second item.
  inspect(
    lints_of([
      @doc.Heading("Title"),
      "a string.",
      @doc.Prose("A prose."),
      @doc.Text("A text.", size=Pt(9)),
      @doc.Strong("Strong."),
      @doc.Emph(@doc.Prose("Emphasis.")),
      @doc.Link(Url("https://typst.app"), body="A link."),
      @doc.Strong(@doc.Emph(@doc.Text("Nested."))),
    ]),
    content=(
      #|adjacent-inline (Prose, argument 1) after (Document, argument 1): "a string.A prose."
      #|adjacent-inline (Text, argument 1) after (Prose, argument 1): "A prose.A text."
      #|adjacent-inline (Strong, argument 1) after (Text, argument 1): "A text.Strong."
      #|adjacent-inline (Prose, argument 1) after (Strong, argument 1): "Strong.Emphasis."
      #|adjacent-inline (Link, argument 2) after (Prose, argument 1): "Emphasis.A link."
      #|adjacent-inline (Text, argument 1) after (Link, argument 2): "A link.Nested."
    ),
  )
  // The block can be anywhere in the array, and of any kind on the list:
  // a table, a spacing, a paragraph, a display equation, raw text as a
  // block, an alignment (which ends the paragraph).
  let pair : Array[&@doc.IntoContent] = [@doc.Prose("One."), @doc.Prose("Two.")]
  let with_block = (block : &@doc.IntoContent) => {
    let items : Array[&@doc.IntoContent] = [..pair, block]
    @doc.Document(items).lower(@doc.DocWorld::in_memory()).lints.length()
  }
  assert_eq(with_block(@doc.Table(["x"])), 1)
  assert_eq(with_block(@doc.V(Pt(4))), 1)
  assert_eq(with_block(@doc.Para("x")), 1)
  assert_eq(with_block(@doc.Parbreak()), 1)
  assert_eq(with_block(@doc.Equation("x", block=true)), 1)
  assert_eq(with_block(@doc.Raw("x", block=true)), 1)
  assert_eq(with_block(@doc.Align(Center, "x")), 1)
  assert_eq(with_block(@doc.Heading("x", label="h")), 1)
  assert_eq(with_block(@doc.Keyed("k", @doc.Block("x"))), 1)
  // What is no block is no evidence: inline content, and what the lint
  // does not look into.
  assert_eq(with_block(@doc.Raw("x")), 0)
  assert_eq(with_block(@doc.Equation("x")), 0)
  assert_eq(with_block(@doc.Box("x")), 0)
  assert_eq(with_block(@doc.Linebreak()), 0)
  assert_eq(with_block(@doc.Seq([@doc.Heading("x")])), 0)
  assert_eq(with_block(@doc.Markup("= x")), 0)
  assert_eq(
    with_block(@doc.Call("heading", positional=[@doc.Value::content("x")])),
    0,
  )
  assert_eq(with_block(@doc.Context(_ => @doc.Heading("x"))), 0)
  assert_eq(with_block(@doc.SetPar(justify=true)), 0)
}

///|
test "lint L1: what is not reported" {
  // An array without a block: it may be the body of one paragraph, which
  // is written like this. (So a document of nothing but `Prose` items is
  // not reported either: the lint's false negative.)
  inspect(
    lints_of([
      @doc.Heading("Title"),
      @doc.Par(@doc.Seq(["Typeset with ", @doc.Emph("care"), "."])),
      @doc.Text(@doc.Seq([@doc.Strong("Note"), ": inline."]), size=Pt(9)),
    ]),
    content="",
  )
  inspect(lints_of([@doc.Prose("One."), @doc.Prose("Two.")]), content="")
  // Neighbours are adjacent items: with anything between them, two text
  // items are not neighbours. A space, a break, a rule.
  inspect(
    lints_of([
      @doc.Heading("Title"),
      @doc.Prose("One."),
      @doc.Space(),
      @doc.Prose("Two."),
      @doc.Parbreak(),
      @doc.Prose("Three."),
      @doc.Linebreak(),
      @doc.Prose("Four."),
      @doc.SetText(size=Pt(9)),
      @doc.Prose("Five."),
    ]),
    content="",
  )
  // Items that are not text for the lint, next to text: a `Lit` (which
  // is what the translator writes markup with), inline code and boxes, a
  // symbol, quoted content, a nested sequence, a wrapper around something
  // else or without a body, a value, the generic call.
  let beside = (item : &@doc.IntoContent) => {
    lints_of([@doc.Heading("Title"), @doc.Prose("One."), item, "two."])
  }
  inspect(beside(@doc.Lit("literal")), content="")
  inspect(beside(@doc.Text(@doc.Lit("literal"))), content="")
  inspect(beside(@doc.Raw("code")), content="")
  inspect(beside(@doc.Box("boxed")), content="")
  inspect(beside(@doc.Symbol("—")), content="")
  inspect(beside(@doc.Quoted("quoted")), content="")
  inspect(beside(@doc.Seq(["nested"])), content="")
  inspect(beside(@doc.Strong(@doc.Raw("code"))), content="")
  inspect(beside(@doc.Link(Url("https://typst.app"))), content="")
  inspect(beside(@doc.Highlight("marked")), content="")
  inspect(beside(@doc.Value::int(3)), content="")
  inspect(
    beside(@doc.Call("text", positional=[@doc.Value::content("called")])),
    content="",
  )
  // What a callback returns does not exist before layout, and `Markup`
  // is Typst source.
  inspect(
    lints_of([
      @doc.Context(_ => {
        @doc.Seq([@doc.Heading("In"), @doc.Prose("a."), @doc.Prose("b.")])
      }),
      @doc.Markup("= Title\n#[a.]#[b.]"),
    ]),
    content="",
  )
  // The fix.
  inspect(
    lints_of([@doc.Heading("Title"), @doc.Para("One."), @doc.Para("Two.")]),
    content="",
  )
}

///|
test "lint L1: every array of `Document` and `Seq`, wherever it is" {
  // An array with the defect; `count` is the number of lints of a
  // document that has it in one place (each document is linted on its
  // own, so a place that is not walked gives 0).
  let section = () => {
    @doc.Seq([@doc.Heading("H"), @doc.Prose("First."), @doc.Prose("Second.")])
  }
  let count = (item : &@doc.IntoContent) => {
    @doc.Document([item]).lower(@doc.DocWorld::in_memory()).lints.length()
  }
  let content = (body : &@doc.IntoContent) => @doc.Value::content(body)
  // An item, the body of a block in a cell of a grid, of a figure under
  // a key, with a label.
  assert_eq(count(section()), 1)
  assert_eq(count(@doc.Grid([@doc.Block(section())])), 1)
  assert_eq(count(@doc.Keyed("row 3", @doc.Figure(section()))), 1)
  assert_eq(count(@doc.Labelled(section(), "l")), 1)
  // An argument of a set rule, typed or generic; a show-set rule; the
  // replacement of a show rule.
  assert_eq(count(@doc.SetPage(header=section())), 1)
  assert_eq(count(@doc.Set("page", [("header", content(section()))])), 1)
  assert_eq(
    count(@doc.ShowSet(@doc.Select::heading(), @doc.SetPage(header=section()))),
    1,
  )
  assert_eq(count(@doc.ShowWith(@doc.Select::strong(), content(section()))), 1)
  // Inside values: an array, a dictionary, the operands of an operator.
  let extra = (value : @doc.Value) => @doc.Block("x", extra=[("body", value)])
  assert_eq(count(extra(@doc.Value::array([content(section())]))), 1)
  assert_eq(count(extra(@doc.Value::dict([("k", content(section()))]))), 1)
  assert_eq(count(extra(content(section()).add(content("more")))), 1)
  assert_eq(count(extra(content(section()).mul(@doc.Value::int(2)))), 1)
  // Not inside the generic call or a call value, a callback, `Markup`.
  assert_eq(count(@doc.Call("block", positional=[content(section())])), 0)
  assert_eq(
    count(extra(@doc.Value::call("block", positional=[content(section())]))),
    0,
  )
  assert_eq(count(@doc.Context(_ => section())), 0)
  // One place in the source is reported once, however often it is used.
  let twice = section()
  assert_eq(count(@doc.Seq([twice, twice, @doc.Block(twice)])), 1)
  // Rows that a function builds for some data are one place, whatever
  // their keys are: the lint has the key of the first.
  let row = (key : String) => {
    @doc.Keyed(
      key,
      @doc.Block(@doc.Seq([@doc.V(Pt(1)), "cell \{key}.", @doc.Text("More.")])),
    )
  }
  inspect(
    lints_of([row("a"), row("b"), row("c")]),
    content=(
      #|adjacent-inline (Text, argument 1, key "a") after (Seq, argument 1, key "a"): "cell a.More."
    ),
  )
  // The texts of a `Prose` or `Para` are not an array of items, but an
  // interpolated sequence is one.
  inspect(
    lints_of([
      @doc.Para(
        "See \{@doc.Seq([@doc.V(Pt(1)), "one.", @doc.Text("Two.")])} there.",
      ),
    ]),
    content=(
      #|adjacent-inline (Text, argument 1) after (Seq, argument 1): "one.Two."
    ),
  )
}

///|
test "lint L1: an empty string, and a block at the seam" {
  // An empty string is nothing on the page: no text item.
  inspect(lints_of([@doc.Heading("H"), "", "x"]), content="")
  // A `Prose` that ends (or starts) with an interpolated block is
  // separated from its neighbour by that block.
  inspect(
    lints_of([
      @doc.Heading("H"),
      @doc.Prose("One. \{@doc.Block("between")}"),
      @doc.Prose("Two."),
      @doc.Prose("\{@doc.V(Pt(2))} Three."),
    ]),
    content="",
  )
  // Inline content at the seam does not separate.
  inspect(
    lints_of([
      @doc.Heading("H"),
      @doc.Prose("One \{@doc.Emph("stressed")}"),
      @doc.Prose("Two."),
    ]),
    content=(
      #|adjacent-inline (Prose, argument 1) after (Prose, argument 1):
    ),
  )
}

///|
test "lint L1: the place of a lint is the origin that the review loop gives" {
  let report = compile([
    @doc.SetPage(width=Pt(200), height=Pt(120), margin=@doc.Sides(all=Pt(10))),
    @doc.Heading("T"),
    "plain.",
    @doc.Prose("prose."),
    @doc.Keyed("k", "keyed."),
  ])
  guard report.lints.map(lint => lint.location)
    is [Some(Edsl(prose)), Some(Edsl(keyed))] else {
    fail("expected two lints with origins")
  }
  // The three texts are one word on the page, of three origins: what a
  // selection of it gives for each.
  let text = report.review_text()
  let record = text.feedback(text.find("plain.prose.keyed.").unwrap(), "")
  let origin_of_text = (rendered : String) => {
    for entry in record.origins {
      if entry.rendered == rendered {
        return entry.origin.describe()
      }
    }
    "-"
  }
  assert_eq(prose.describe(), origin_of_text("prose."))
  assert_eq(keyed.describe(), origin_of_text("keyed."))
  assert_eq(keyed.keys, ["k"])
  guard report.lints[0].hints[0].location is Some(Edsl(plain)) else {
    fail("expected an origin")
  }
  assert_eq(plain.describe(), origin_of_text("plain."))
  assert_eq(what(plain), "(Document, argument 1)")
  // The review text finds the place on the page.
  assert_true(text.origin_positions(prose).length() >= 1)
  // A string in `Labelled` is that call's body, also for the lint.
  let labelled = compile([
    @doc.Heading("T"),
    "plain.",
    @doc.Labelled("marked.", "m"),
  ])
  guard labelled.lints.map(lint => lint.location) is [Some(Edsl(marked))] else {
    fail("expected one lint with an origin")
  }
  assert_eq(what(marked), "(Labelled, argument 1)")
  let text = labelled.review_text()
  let record = text.feedback(text.find("plain.marked.").unwrap(), "")
  assert_true(
    record.origins.map(o => o.origin.describe()).contains(marked.describe()),
  )
  // A `Prose` that is all interpolated has no text of its own: the place
  // is its text argument, and the page has nothing with that origin.
  let hollow = compile([
    @doc.Heading("T"),
    "plain.",
    @doc.Prose("\{@doc.Emph("stressed.")}"),
  ])
  guard hollow.lints.map(lint => lint.location) is [Some(Edsl(prose))] else {
    fail("expected one lint with an origin")
  }
  assert_eq(what(prose), "(Prose, argument 1)")
  assert_true(hollow.review_text().origin_positions(prose).is_empty())
}

///|
test "lints: on by default, off with `lints=false`, and there when the compilation fails" {
  let doc = @doc.Document([
    @doc.Heading("T"),
    @doc.Prose("One."),
    @doc.Prose("Two."),
  ])
  let world = @doc.DocWorld::in_memory()
  assert_eq(doc.compile_paged(world).lints.length(), 1)
  assert_eq(doc.compile_paged(world, lints=false).lints.length(), 0)
  assert_eq(doc.lower(world).lints.length(), 1)
  assert_eq(doc.lower(world, lints=false).lints.length(), 0)
  // Lints are no warnings: those are the engine's.
  assert_eq(doc.compile_paged(world).warnings.length(), 0)
  // A document that does not compile still has the lints of its tree.
  let failed = @doc.Document([
    @doc.Heading("T"),
    @doc.Prose("One."),
    @doc.Prose("Two."),
    @doc.Image("missing.png"),
  ]).compile_paged(world)
  assert_true(failed.output() is None)
  assert_eq(failed.lints.length(), 1)
  let lint = failed.lints[0]
  assert_true(lint.kind == AdjacentInline)
  inspect(lint.kind.name(), content="adjacent-inline")
  assert_eq(lint.hints.length(), 2)
  assert_true(lint.hints[1].message.contains("`Para(..)`"))
  assert_true(lint.hints[1].location is None)
  assert_true(lint.render().has_prefix("lint[adjacent-inline]: this text and"))
  // A description that is used twice is reported once; long texts are
  // cut at the seam; where an interpolated description is at the seam,
  // the message has no text.
  let twice = @doc.Seq([
    @doc.V(Pt(2)),
    @doc.Prose("A sentence that is long enough to be cut somewhere."),
    @doc.Prose("Another sentence that is long enough as well."),
    @doc.Prose("\{@doc.Emph("Stressed")} at the start."),
  ])
  inspect(
    lints_of([twice, twice]),
    content=(
      #|adjacent-inline (Prose, argument 1) after (Prose, argument 1): "…e cut somewhere.Another sentence…"
      #|adjacent-inline (Prose, argument 1) after (Prose, argument 1):
    ),
  )
}
