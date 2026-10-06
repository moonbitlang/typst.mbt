// `Para` (docs/edsl-ports.md, section 3.1): a paragraph of prose, which is
// the text of a `Prose` between two paragraph breaks, from one call site.
// First what the engine does with paragraphs, on Typst source (the facts
// that the lowering is built on); then `Para` itself, compared with
// `Par(Prose(..))` where the two are the same. The comparison of source
// characters, which needs the source file, is in `doc/examples/review`.
// (`lowered` is the helper of `ports_test.mbt`.)

///|
/// What Typst source is typeset as on a page of 200pt by 300pt with 10pt
/// margins and 10pt text: the errors, the warnings and the marks.
fn typeset(source : String) -> String {
  let report = compile([
    @doc.Markup(
      "#set page(width: 200pt, height: 300pt, margin: 10pt)\n#set text(size: 10pt)\n" +
      source,
    ),
  ])
  let marks = listing(marks(report)) catch { _ => "(no document)" }
  let errors = error_messages(report)
  let warnings = warning_messages(report)
  (if errors == "" { "" } else { "error: \{errors}\n" }) +
  (if warnings == "" { "" } else { "warning: \{warnings}\n" }) +
  marks
}

///|
test "engine: `par[..]` cannot hold a block" {
  // A displayed formula (or any block) in the body of `par` is dropped,
  // with a warning. (Upstream `typst-layout/src/inline/collect.rs`: what
  // is not inline content is reported and skipped.)
  inspect(
    typeset("#par[Before $ x $ after.]"),
    content=(
      #|warning: block may not occur inside of a paragraph and was ignored
      #|p1 text 10.0,16.6 w29.1 "Before "
      #|p1 text 39.1,16.6 w22.8 " after."
    ),
  )
  // Text between paragraph breaks keeps it.
  inspect(
    typeset("#[#parbreak()Before $ x $ after.#parbreak()]"),
    content=(
      #|p1 text 10.0,16.6 w26.6 "Before"
      #|p1 text 97.1,33.0 w5.7 "𝑥"
      #|p1 text 10.0,51.7 w20.3 "after."
    ),
  )
}

///|
test "engine: a block ends the paragraph, and the text after it is a paragraph that follows a block" {
  // Upstream `typst-realize`: a block interrupts the paragraph grouping;
  // `typst-layout/src/flow/collect.rs`: the paragraph after a block is in
  // the situation `Other`, the one after a paragraph `Consecutive`, and
  // the first-line indent is for `Consecutive`, or for all with `all`.
  let source = "Zero.\n\nBefore $ x $ after.\n\nNext.\n\nEnds $ y $\n\nAfterwards."
  // Without `all`: neither the continuation ("after.") nor a new paragraph
  // after a display ("Afterwards.") is indented; "Next." is.
  inspect(
    typeset("#set par(first-line-indent: 1em)\n" + source),
    content=(
      #|p1 text 10.0,16.6 w21.3 "Zero."
      #|p1 text 20.0,35.2 w26.6 "Before"
      #|p1 text 97.1,51.6 w5.7 "𝑥"
      #|p1 text 10.0,70.3 w20.3 "after."
      #|p1 text 20.0,88.9 w21.7 "Next."
      #|p1 text 20.0,107.4 w20.0 "Ends"
      #|p1 text 97.4,123.9 w5.2 "𝑦"
      #|p1 text 10.0,144.5 w48.1 "Afterwards."
    ),
  )
  // With `all`: every paragraph is indented, the continuation too.
  inspect(
    typeset("#set par(first-line-indent: (amount: 1em, all: true))\n" + source),
    content=(
      #|p1 text 20.0,16.6 w21.3 "Zero."
      #|p1 text 20.0,35.2 w26.6 "Before"
      #|p1 text 97.1,51.6 w5.7 "𝑥"
      #|p1 text 20.0,70.3 w20.3 "after."
      #|p1 text 20.0,88.9 w21.7 "Next."
      #|p1 text 20.0,107.4 w20.0 "Ends"
      #|p1 text 97.4,123.9 w5.2 "𝑦"
      #|p1 text 20.0,144.5 w48.1 "Afterwards."
    ),
  )
  // A set rule for the text after the block takes the indent away there
  // and nowhere else: what `Para` writes.
  inspect(
    typeset(
      "#set par(first-line-indent: (amount: 1em, all: true))\nZero.\n\nBefore $ x $ #[#set par(first-line-indent: 0pt);after.]\n\nNext.",
    ),
    content=(
      #|p1 text 20.0,16.6 w21.3 "Zero."
      #|p1 text 20.0,35.2 w26.6 "Before"
      #|p1 text 97.1,51.6 w5.7 "𝑥"
      #|p1 text 10.0,70.3 w20.3 "after."
      #|p1 text 20.0,88.9 w21.7 "Next."
    ),
  )
}

///|
test "engine: paragraph breaks collapse, and one at the edge of a container is nothing" {
  let reference = typeset("One.\n\nTwo.\n\nThree.")
  assert_eq(
    typeset(
      "#[#parbreak()#parbreak()One.#parbreak()#parbreak()#parbreak()Two.#parbreak()]#parbreak()#[#parbreak()Three.#parbreak()]",
    ),
    reference,
  )
  let framed = (body : String) => {
    typeset("#block(stroke: 1pt, inset: 3pt)[\{body}]After.")
  }
  assert_eq(framed("#parbreak()In.#parbreak()"), framed("#par[In.]"))
  // (In a container, text without a paragraph break is no paragraph, but
  // it is typeset where the paragraph is.)
  assert_eq(framed("#parbreak()In.#parbreak()"), framed("In."))
}

///|
test "engine: text between paragraph breaks is typeset like `par[..]`, in every container" {
  let long = "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen."
  // `P` stands for the paragraph.
  let contexts = [
    "= Head\nIntro.\n\nP\n\nOutro.\n\nP P", "P", "#rect(width: 20pt, height: 5pt) P #rect(width: 20pt, height: 5pt)",
    "#list([Item one.], [P], [#[Lead] P #[Tail]])", "#enum([P], [Before. P])", "#table(columns: 2, [P], [Short], [A P], [P B])",
    "#grid(columns: (80pt, 1fr), [P], [P P])", "#block(inset: 4pt, stroke: 1pt)[P]#block(width: 120pt)[Intro. P Outro.]",
    "Text #box(width: 100pt)[P] more.", "#figure([P], caption: [Cap])", "Body#footnote[P] text.",
    "#columns(2)[P P]", "#stack(dir: ttb, [P], [P])", "#align(center)[P]", "#quote(block: true)[P]",
    "#pad(left: 10pt)[P]", "#place(top + right, block(width: 80pt)[P])",
  ]
  // (What is set for the document, the options of the paragraph.)
  let settings = [
    ("", ""),
    ("#set par(first-line-indent: 1em)\n", ""),
    ("#set par(first-line-indent: (amount: 1em, all: true))\n", ""),
    ("", "justify: true, leading: 0.4em, spacing: 20pt, hanging-indent: 8pt"),
    (
      "#set par(first-line-indent: (amount: 1em, all: true), spacing: 5pt)\n", "linebreaks: \"simple\", first-line-indent: 2em",
    ),
  ]
  let mut compared = 0
  for setting in settings {
    let (preamble, options) = setting
    let (explicit, delimited) = if options == "" {
      ("#par[\{long}]", "#[#parbreak()\{long}#parbreak()]")
    } else {
      (
        "#par(\{options})[\{long}]",
        "#[#set par(\{options});#parbreak()\{long}#parbreak()]",
      )
    }
    for context in contexts {
      let a = typeset(preamble + context.replace_all(old="P", new=explicit))
      let b = typeset(preamble + context.replace_all(old="P", new=delimited))
      if a != b {
        fail("differs in `\{context}` with `\{preamble}` and `\{options}`")
      }
      compared += 1
    }
  }
  assert_eq(compared, 85)
  // The one difference: options that are set reach the paragraphs inside
  // the text (the entry of a footnote, a box with paragraphs); the
  // arguments of `par(..)` are for that paragraph only.
  let options = "justify: true, first-line-indent: (amount: 1em, all: true), hanging-indent: 6pt"
  let inside = "Text #box(width: 90pt)[#parbreak()Inner paragraph that is long enough to wrap.#parbreak()] more."
  inspect(
    typeset("#par(\{options})[\{inside}]"),
    content=(
      #|p1 text 20.0,16.6 w20.3 "Text "
      #|p1 text 40.3,16.6 w85.2 "Inner paragraph that "
      #|p1 text 40.3,29.7 w71.0 "is long enough to "
      #|p1 text 40.3,42.7 w23.1 "wrap."
      #|p1 text 130.3,16.6 w25.7 " more."
    ),
  )
  inspect(
    typeset("#[#set par(\{options});#parbreak()\{inside}#parbreak()]"),
    content=(
      #|p1 text 20.0,16.6 w20.3 "Text "
      #|p1 text 50.3,16.6 w80.0 "Inner paragraph "
      #|p1 text 46.3,29.7 w84.0 "that is long enough "
      #|p1 text 46.3,42.7 w33.8 "to wrap."
      #|p1 text 130.3,16.6 w25.7 " more."
    ),
  )
}

///|
test "para: what it lowers to" {
  // The pieces of the prose between two paragraph breaks.
  inspect(
    lowered([@doc.Para("say \"hi\" \{@doc.Emph("now")}")]),
    content=(
      #|sequence(
      #|  parbreak(),
      #|  [say],
      #|  [ ],
      #|  smartquote(double: true),
      #|  [hi],
      #|  smartquote(double: true),
      #|  [ ],
      #|  emph(body: [now]),
      #|  parbreak(),
      #|)
    ),
  )
  // The options of `par` are set for that sequence; `quotes` is the
  // option of the text.
  inspect(
    lowered([
      @doc.Para(
        "say \"hi\"",
        quotes=false,
        leading=Em(0.5),
        spacing=Pt(14),
        justify=true,
        linebreaks="simple",
        hanging_indent=Pt(6),
        extra=[("first-line-indent", @doc.Value::length(Pt(4)))],
      ),
    ]),
    content=(
      #|styled(child: sequence(parbreak(), [say], [ ], ["hi"], parbreak()), ..)
    ),
  )
  // The text after a block is a sequence of its own, with the rule that
  // takes its first-line indent away; a blank line ends it.
  inspect(
    lowered([
      (
        $|Before \{@doc.Equation("x", block=true)} after
        $|it.
        $|
        $|New.
      )
      |> @doc.Para,
    ]),
    content=(
      #|sequence(
      #|  parbreak(),
      #|  [Before],
      #|  [ ],
      #|  equation(block: true, body: [x]),
      #|  [ ],
      #|  styled(child: sequence([after], [ ], [it.]), ..),
      #|  parbreak(),
      #|  [New.],
      #|  parbreak(),
      #|)
    ),
  )
  // One word; nothing.
  inspect(
    lowered([@doc.Para("word")]),
    content="sequence(parbreak(), [word], parbreak())",
  )
  inspect(lowered([@doc.Para("")]), content="sequence(parbreak(), parbreak())")
}

///|
/// The marks of a document on the small page.
fn marks_of(children : Array[&@doc.IntoContent]) -> String raise {
  let report = compile([..small_page(), ..children])
  let errors = error_messages(report)
  let warnings = warning_messages(report)
  guard errors == "" && warnings == "" else {
    fail("errors: \{errors}; warnings: \{warnings}")
  }
  listing(marks(report))
}

///|
test "para: for text without blocks, the frames of Par(Prose(..))" {
  let text = () => {
    "It's \"\{3}\" \{@doc.Emph("fine")} words, and enough of them to need a second line of the paragraph."
  }
  let para = () => @doc.Para(text(), justify=true, hanging_indent=Pt(6))
  let nested = () => {
    @doc.Par(@doc.Prose(text()), justify=true, hanging_indent=Pt(6))
  }
  let plain = () => @doc.Para(text())
  let plain_nested = () => @doc.Par(@doc.Prose(text()))
  // In the flow, between other content; in a list item, a cell of a
  // table, a block and a figure.
  let contexts : Array[(&@doc.IntoContent) -> Array[&@doc.IntoContent]] = [
    p => [@doc.Heading("H"), "Intro.", p, "Outro."],
    p => [p],
    p => [@doc.List(["Item one.", p])],
    p => [@doc.Table([p, "Short"], columns=[Fr(1), Auto])],
    p => [@doc.Block(p, inset=@doc.Sides(all=Pt(4)), width=Pt(120))],
    p => [@doc.Figure(p, caption="Cap")],
  ]
  for context in contexts {
    assert_eq(marks_of(context(para())), marks_of(context(nested())))
    assert_eq(marks_of(context(plain())), marks_of(context(plain_nested())))
  }
  inspect(
    marks_of([para()]),
    content=(
      #|p1 text 10.0,16.6 w32.4 "It’s “3” "
      #|p1 text 42.4,16.6 w14.8 "fine"
      #|p1 text 57.2,16.6 w132.8 " words, and enough of them to "
      #|p1 text 16.0,29.7 w147.9 "need a second line of the paragraph."
    ),
  )
}

///|
test "para: two of them are two paragraphs" {
  let report = compile(
    [..small_page(), @doc.Para("One ends here."), @doc.Para("Two starts here.")],
  )
  inspect(error_messages(report), content="")
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w60.8 "One ends here."
      #|p1 text 10.0,35.2 w65.4 "Two starts here."
    ),
  )
  // Also as items of a list, where a string would be no paragraph.
  assert_eq(
    marks_of([@doc.List([@doc.Seq([@doc.Para("One."), @doc.Para("Two.")])])]),
    marks_of([@doc.List([@doc.Seq([@doc.Par("One."), @doc.Par("Two.")])])]),
  )
}

///|
test "para: a blank line in the text is a paragraph break" {
  // The text of a `Prose` has a paragraph break at a blank line. Between
  // the two breaks of a `Para` it is one more: two paragraphs, with the
  // options of the call, and no warning. (In `Par(Prose(..))` the `par`
  // element cannot hold the break: the engine ignores it with a warning
  // and the text runs together.)
  let report = compile(
    [
      ..small_page(),
      @doc.Para("One ends here.\n\nTwo starts here.", hanging_indent=Pt(4)),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  assert_eq(report.lints.length(), 0)
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w60.8 "One ends here."
      #|p1 text 10.0,35.2 w65.4 "Two starts here."
    ),
  )
  let line = line_here() + 1
  let nested = @doc.Par(@doc.Prose("One ends here.\n\nTwo starts here."))
  let report = compile([..small_page(), nested])
  assert_eq(report.warnings.length(), 1)
  inspect(
    warning_messages(report),
    content="parbreak may not occur inside of a paragraph and was ignored",
  )
  let at = origin_of(report.warnings[0])
  inspect(what(at), content="(Prose, argument 1)")
  assert_eq(at.start_line, line)
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w125.6 "One ends here.Two starts here."
    ),
  )
}

///|
/// The text runs of a document with a first-line indent of 10pt (`all`:
/// for every paragraph), as `x text`.
fn indents(all : Bool, children : Array[&@doc.IntoContent]) -> String raise {
  let report = compile(
    [
      ..small_page(),
      @doc.Set("par", [
        (
          "first-line-indent",
          @doc.Value::dict([
            ("amount", @doc.Value::length(Pt(10))),
            ("all", @doc.Value::bool(all)),
          ]),
        ),
      ]),
      ..children,
    ],
  )
  let errors = error_messages(report)
  let warnings = warning_messages(report)
  guard errors == "" && warnings == "" else {
    fail("errors: \{errors}; warnings: \{warnings}")
  }
  of_kind(marks(report), "text").map(m => "\{pt(m.x)} \{m.text}").join(" | ")
}

///|
test "para: a displayed formula inside is kept, and the text after it is not indented" {
  let paragraphs = () => {
    let out : Array[&@doc.IntoContent] = [
      @doc.Para("Zero."),
      @doc.Para("Before \{@doc.Equation("x", block=true)} after."),
      @doc.Para("Next."),
      @doc.Para("Ends \{@doc.Equation("y", block=true)}"),
      @doc.Para("Afterwards."),
    ]
    out
  }
  // The formulas are there, without a warning (`indents` fails on one).
  // With an indent for every paragraph (`all`): the text after the
  // display is not indented, each `Para` is.
  inspect(
    indents(true, paragraphs()),
    content="20.0 Zero. | 20.0 Before | 97.1 𝑥 | 10.0 after. | 20.0 Next. | 20.0 Ends | 97.4 𝑦 | 20.0 Afterwards.",
  )
  // Without `all` the engine indents a paragraph that follows a
  // paragraph: not the first, and not the `Para` after one that ends
  // with a display ("Afterwards."), which follows a block. That is the
  // engine's rule for every paragraph after a block; an author who wants
  // that indent sets `all`, or gives that paragraph its indent by hand.
  inspect(
    indents(false, paragraphs()),
    content="10.0 Zero. | 20.0 Before | 97.1 𝑥 | 10.0 after. | 20.0 Next. | 20.0 Ends | 97.4 𝑦 | 10.0 Afterwards.",
  )
  // A blank line after a display starts a paragraph that is indented
  // again; a second display has its own continuation; any block that the
  // description shows counts (a list).
  inspect(
    indents(true, [
      (
        $|A \{@doc.Equation("x", block=true)} b
        $|\{@doc.Equation("y", block=true)} c
        $|
        $|D \{@doc.List(["item"])} e.
      )
      |> @doc.Para,
    ]),
    content=(
      #|20.0 A | 97.1 𝑥 | 10.0 b | 97.4 𝑦 | 10.0 c | 20.0 D | 10.0 • | 18.5 item | 10.0 e.
    ),
  )
  // What the description does not show is a block only for the engine:
  // the text after it is indented like any paragraph after a block.
  inspect(
    indents(true, [
      @doc.Para(
        "A \{@doc.Call("block", positional=[@doc.Value::content("called")])} b",
      ),
    ]),
    content=(
      #|20.0 A | 10.0 called | 20.0 b
    ),
  )
  // The formula keeps its own origin, the words theirs.
  let report = compile(
    [
      ..small_page(),
      @doc.Para("Before \{@doc.Equation("x", block=true)} after."),
    ],
  )
  assert_eq(text_origins(report), [
    "Before: Para", "𝑥: Equation", "after.: Para",
  ])
}

///|
test "para: one call site, whose first argument is the text" {
  let line = line_here() + 1
  let para = compile([@doc.Para("alpha \"\{@doc.Emph("beta")}\" gamma")])
  let nested = compile([
    @doc.Par(@doc.Prose("alpha \"\{@doc.Emph("beta")}\" gamma")),
  ])
  // The registry: the document, the paragraph and the emphasis; with
  // `Par(Prose(..))` the paragraph is two origins.
  let kinds = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    report.origins
    .listing()
    .split("\n")
    .filter(line => line != "")
    .map(line => line.split(" ").collect()[1].to_owned())
    .collect()
  }
  assert_eq(kinds(para), ["Document", "Para", "Emph"])
  assert_eq(kinds(nested), ["Document", "Par", "Prose", "Emph"])
  // The words and the quotes: the `text` argument of the `Para` call, as
  // they are the `text` argument of the `Prose` call.
  let origins = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    let glyphs = []
    for page in report.unwrap().pages() {
      collect_glyphs(page.frame, glyphs)
    }
    let out : Array[String] = []
    for glyph in glyphs {
      guard report.origins.resolve(glyph.1) is Some(origin) else { continue }
      let line = "\{glyph.0}: \{what(origin)}"
      if !out.contains(line) {
        out.push(line)
      }
    }
    out.join(" | ")
  }
  inspect(
    origins(para),
    content="alpha “: (Para, argument 1) | beta: (Emph, argument 1) | ” gamma: (Para, argument 1)",
  )
  assert_eq(origins(para).replace_all(old="Para", new="Prose"), origins(nested))
  // The location of that argument is the literal: inside the call.
  let glyphs = []
  for page in para.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let word = para.origins.resolve(glyphs[0].1).unwrap()
  assert_eq(word.start_line, line)
  assert_eq(word.end_line, line)
  // (`  let para = compile([@doc.Para(` is 32 characters.)
  assert_eq(word.start_column, 33)
}

///|
test "para: every piece of the text has a span of its own, like the pieces of a Prose" {
  let text = () => "row \"row\" row\n\nrow \{@doc.Emph("row")} row"
  let para = @doc.Document([@doc.Para(text())])
    .lower(@doc.DocWorld::in_memory())
    .unwrap()
  let nested = @doc.Document([@doc.Par(@doc.Prose(text()))])
    .lower(@doc.DocWorld::in_memory())
    .unwrap()
  // Five words, the emphasized one, two quotes and a paragraph break,
  // between the two breaks of the `Para`.
  let spans = pieces(para).map(p => p.1)
  let kinds = pieces(para).map(p => p.0)
  let around = pieces(nested).map(p => p.0)
  around.insert(0, "break")
  around.push("break")
  assert_eq(kinds, around)
  assert_eq(kinds[0], "break")
  assert_eq(kinds[kinds.length() - 1], "break")
  assert_eq(spans.length(), 11)
  assert_eq(distinct_spans(spans), 11)
  // Paragraphs with equal words are different elements.
  let same = compile([@doc.Para("same"), @doc.Para("same")])
  let reused = @doc.Para("same")
  let twice = compile([reused, reused])
  assert_eq(count_keys(same), (2, 2))
  assert_eq(count_keys(twice), (2, 1))
  // Thousands of pieces stay distinct and add few origins.
  let words = StringBuilder()
  for _ in 0..<3000 {
    words.write_string("w ")
  }
  let long = @doc.Document([@doc.Para(words.to_string())]).lower(
    @doc.DocWorld::in_memory(),
  )
  let spans = pieces(long.unwrap()).map(p => p.1)
  // (The words and the two paragraph breaks.)
  assert_eq(spans.length(), 3002)
  assert_eq(distinct_spans(spans), 3002)
  assert_true(long.origins.length() < 80)
  for span in spans {
    let origin = long.origins.resolve(span).unwrap()
    assert_eq(origin.kind, "Para")
    assert_eq(origin.param, Some(0))
  }
}

///|
test "para: under a key" {
  let row = (key : String) => @doc.Keyed(key, @doc.Para("keyed words"))
  let report = compile([row("a"), row("b")])
  // (The space between the words has no origin, as in a `Prose`.)
  assert_eq(text_origins(report), [
    "keyed words: Para a", "keyed words: -", "keyed words: Para b",
  ])
}

///|
test "para: misuse is reported at the Para call" {
  // A rule cannot be interpolated; a reserved character; a description
  // that another text took.
  let line = line_here() + 2
  let rule = compile([
    @doc.Para("a \{@doc.Content(@doc.SetText(size=Pt(9)))} b"),
  ])
  inspect(
    error_messages(rule),
    content="`SetText` is a rule and cannot be interpolated into prose",
  )
  inspect(what(origin_of(rule.errors[0])), content="(Para)")
  assert_eq(origin_of(rule.errors[0]).start_line, line)
  let reserved = compile([@doc.Para("a \u{FDD1} b")])
  inspect(
    error_messages(reserved),
    content="the text of `Para` contains a reserved character (U+FDD1)",
  )
  let text = "a \{@doc.Emph("b")}"
  let first = compile([@doc.Para(text)])
  inspect(error_messages(first), content="")
  let second = compile([@doc.Para(text)])
  inspect(
    error_messages(second),
    content="an interpolated description of this text was already used by another `Prose` or `Para`",
  )
  // A `Para` is a description: it can be interpolated, and it prints as
  // its call.
  let inner = @doc.Para("in")
  inspect(
    lowered([@doc.Prose("out \{inner}")]),
    content="sequence([out], [ ], sequence(parbreak(), [in], parbreak()))",
  )
  debug_inspect(
    @doc.Para("a \"b\" \{@doc.Emph("c")}", justify=true),
    content=(
      #|Para(
      #|  [
      #|    "a",
      #|    Space,
      #|    smartquote(double=true),
      #|    "b",
      #|    smartquote(double=true),
      #|    Space,
      #|    Emph("c"),
      #|  ],
      #|  justify=true,
      #|)
    ),
  )
  // (The breaks around the text and the rule after a block are how it is
  // lowered, not what was written.)
  debug_inspect(
    @doc.Para("a \{@doc.V(Pt(2))} b\n\nc"),
    content=(
      #|Para(["a", Space, V(2pt), Space, "b", parbreak, "c"])
    ),
  )
}

///|
test "para: the review text, feedback and positions of Par(Prose(..))" {
  let para_line = line_here() + 2
  let para = compile_on_page([
    @doc.Para("One two \{@doc.Emph("three")} four, \"five\"."),
  ])
  let nested_line = line_here() + 2
  let nested = compile_on_page([
    @doc.Par(@doc.Prose("One two \{@doc.Emph("three")} four, \"five\".")),
  ])
  let para_text = para.review_text(title="Test")
  let nested_text = nested.review_text(title="Test")
  inspect(para_text.text(), content="One two three four, “five”.")
  assert_eq(para_text.text(), nested_text.text())
  assert_eq(para_text.length(), nested_text.length())
  // The runs of the text are pieces of one origin, the argument.
  let feedback = (text : @doc.ReviewText, needle : String) => {
    let record = text.feedback(text.find(needle).unwrap(), "")
    (
      origins_of(record),
      record.origins.map(o => (o.origin.param, o.tier, o.why, o.pieces)),
      record.pages,
    )
  }
  inspect(
    feedback(para_text, "One two three four").0,
    content=(
      #|Para: One two … four, [One/two/four,] | Emph: three [three]
    ),
  )
  for
    needle in [
      "One two three four", "five", "three", "two", "four, “five”.",
    ] {
    let a = feedback(para_text, needle)
    let b = feedback(nested_text, needle)
    assert_eq(a.0.replace_all(old="Para:", new="Prose:"), b.0)
    assert_eq(a.1, b.1)
    assert_eq(a.2, b.2)
  }
  // Without a source file the location is the argument (tier 2).
  assert_eq(feedback(para_text, "two").1, [
    (
      Some(0),
      2,
      "the location is the argument as a whole: its source file was not read when this was made",
      ["two"],
    ),
  ])
  // Positions: the line of the text has the call, its argument and the
  // emphasis inside it, and gives the narrowest of them, the emphasis;
  // the origin of a word gives the boxes of the words of the text.
  let file = "doc/para_test.mbt"
  let boxes = (text : @doc.ReviewText, line : Int) => {
    text.positions(file, line).map(region_text).join(" | ")
  }
  inspect(boxes(para_text, para_line), content="1: 51.3 6.2 21.8 11")
  assert_eq(boxes(para_text, para_line), boxes(nested_text, nested_line))
  let word = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    report.origin_at(1, 14.0, 16.0).unwrap()
  }
  assert_eq(word(para).kind, "Para")
  assert_eq(word(nested).kind, "Prose")
  assert_eq(word(para).param, Some(0))
  assert_eq(
    para_text.origin_positions(word(para)).map(region_text),
    nested_text.origin_positions(word(nested)).map(region_text),
  )
  // With a column: the argument, and the emphasis inside it.
  let stressed = para.origin_at(1, 60.0, 16.0).unwrap()
  assert_eq(stressed.kind, "Emph")
  assert_eq(
    para_text.positions(file, para_line, column=stressed.start_column).length(),
    1,
  )
  assert_eq(
    para_text
    .positions(file, para_line, column=word(para).start_column + 1)
    .length(),
    para_text.origin_positions(word(para)).length(),
  )
  // The page carries the same origins for both.
  let html = para.review_html().unwrap()
  assert_true(html.contains("\"kind\":\"Para\""))
  assert_true(!html.contains("\"kind\":\"Par\""))
  assert_true(!html.contains("\"kind\":\"Prose\""))
}
