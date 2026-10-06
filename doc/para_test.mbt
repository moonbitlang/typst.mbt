// `Para` (docs/edsl-ports.md, section 3.1): the same paragraph as
// `Par(Prose(..))`, from one call site. Each test compares the two forms.
// The comparison of source characters, which needs the source file, is in
// `doc/examples/review`. (`lowered` is the helper of `ports_test.mbt`.)

///|
test "para: the content of Par(Prose(..)), with the options of both" {
  // Words, a quote, an interpolated description and string.
  let n = 3
  assert_eq(
    lowered([@doc.Para("It's \"\{n}\" \{@doc.Emph("fine")} words.")]),
    lowered([@doc.Par(@doc.Prose("It's \"\{n}\" \{@doc.Emph("fine")} words."))]),
  )
  inspect(
    lowered([@doc.Para("say \"hi\" \{@doc.Emph("now")}")]),
    content=(
      #|par(
      #|  body: sequence(
      #|    [say],
      #|    [ ],
      #|    smartquote(double: true),
      #|    [hi],
      #|    smartquote(double: true),
      #|    [ ],
      #|    emph(body: [now]),
      #|  ),
      #|)
    ),
  )
  // The options of `Prose` and of `Par`, a label, `extra`.
  assert_eq(
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
        label="p",
      ),
    ]),
    lowered([
      @doc.Par(
        @doc.Prose("say \"hi\"", quotes=false),
        leading=Em(0.5),
        spacing=Pt(14),
        justify=true,
        linebreaks="simple",
        hanging_indent=Pt(6),
        extra=[("first-line-indent", @doc.Value::length(Pt(4)))],
        label="p",
      ),
    ]),
  )
  // The pipe form, with line breaks, a blank line and white space at the
  // edges; one word; nothing.
  assert_eq(
    lowered([
      (
        $|  First line
        $|and a second.
        $|
        $|After the blank line.
        $|
      )
      |> @doc.Para,
    ]),
    lowered([
      @doc.Par(@doc.Prose("First line\nand a second.\n\nAfter the blank line.")),
    ]),
  )
  assert_eq(
    lowered([@doc.Para("word")]),
    lowered([@doc.Par(@doc.Prose("word"))]),
  )
  assert_eq(lowered([@doc.Para("")]), lowered([@doc.Par(@doc.Prose(""))]))
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
}

///|
test "para: a blank line in the text is not a second paragraph" {
  // The text of a `Prose` has a paragraph break at a blank line, and a
  // `par` cannot hold one: the engine's warning, at the text, and one
  // paragraph without the break. `Par(Prose(..))` is the same.
  let line = line_here() + 1
  let para = @doc.Para("One ends here.\n\nTwo starts here.")
  let report = compile([..small_page(), para])
  inspect(error_messages(report), content="")
  // The warning is the engine's, in `warnings`, and the only one; its
  // location is the text argument of the `Para` call.
  assert_eq(report.warnings.length(), 1)
  assert_true(report.warnings[0].severity == Warning)
  inspect(
    warning_messages(report),
    content="parbreak may not occur inside of a paragraph and was ignored",
  )
  let at = origin_of(report.warnings[0])
  inspect(what(at), content="(Para, argument 1)")
  assert_eq(at.kind, "Para")
  assert_eq(at.file, "doc/para_test.mbt")
  assert_eq(at.start_line, line)
  // It is no lint.
  assert_eq(report.lints.length(), 0)
  inspect(
    listing(marks(report)),
    content=(
      #|p1 text 10.0,16.6 w125.6 "One ends here.Two starts here."
    ),
  )
  let nested = compile(
    [..small_page(), @doc.Par(@doc.Prose("One ends here.\n\nTwo starts here."))],
  )
  assert_eq(warning_messages(nested), warning_messages(report))
  assert_eq(listing(marks(nested)), listing(marks(report)))
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
  // Five words, the emphasized one, two quotes and a paragraph break.
  let spans = pieces(para).map(p => p.1)
  assert_eq(pieces(para).map(p => p.0), pieces(nested).map(p => p.0))
  assert_eq(spans.length(), 9)
  assert_eq(distinct_spans(spans), 9)
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
  assert_eq(spans.length(), 3000)
  assert_eq(distinct_spans(spans), 3000)
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
    content="sequence([out], [ ], par(body: [in]))",
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
