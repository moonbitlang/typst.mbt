// Behavioural tests of `Prose` (docs/edsl-design.md, section 4.4).

///|
/// The text of the glyph runs of a compiled document.
fn run_texts(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[String] raise {
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let texts : Array[String] = []
  for glyph in glyphs {
    if !texts.contains(glyph.0) {
      texts.push(glyph.0)
    }
  }
  texts
}

///|
test "prose: interpolated descriptions keep their structure, strings are text" {
  let name = "MoonBit"
  let report = compile([
    (
      $|Written in \{name} with \{@doc.Emph("care")}
      $|and "quotes".
      $|
      $|Second paragraph.
    )
    |> @doc.Prose,
  ])
  assert_eq(error_messages(report), "")
  let texts = run_texts(report)
  assert_true(texts.contains("Written in MoonBit with "))
  assert_true(texts.contains("care"))
  // The quotes are smart quotes.
  assert_true(texts.iter().any(t => t.contains("“quotes”")))
  assert_true(texts.contains("Second paragraph."))
}

///|
test "prose: a description interpolated into another string is an error" {
  let report = compile([@doc.Par("see \{@doc.Emph("this")}")])
  assert_eq(
    error_messages(report),
    "`Emph` was interpolated into a string that is not the text of `Prose`",
  )
  assert_true(report.errors[0].hints[0].message.contains("Prose"))
  // Also as a value (the text of `Raw`).
  let report = compile([@doc.Raw("x \{@doc.Strong("y")}")])
  assert_eq(
    error_messages(report),
    "`Strong` was interpolated into a string that is not the text of `Prose`",
  )
}

///|
test "prose: misuse is reported at the Prose call" {
  // The same text twice: the interpolated description is taken by the
  // first `Prose`.
  let text = "a \{@doc.Emph("b")}"
  let first = @doc.Prose(text)
  let second = @doc.Prose(text)
  let report = compile([first, second])
  assert_eq(
    error_messages(report),
    "an interpolated description of this text was already used by another `Prose`",
  )
  assert_eq(origin_of(report.errors[0]).kind, "Prose")
  // A rule has no place in prose (the rule types cannot be interpolated;
  // through `Content` the rule is found when the prose is built).
  let report = compile([
    @doc.Prose("a \{@doc.Content(@doc.SetText(size=Pt(9)))} b"),
  ])
  assert_eq(
    error_messages(report),
    "`SetText` is a rule and cannot be interpolated into prose",
  )
  // The reserved characters cannot be written.
  let report = compile([@doc.Prose("a \u{FDD1} b")])
  assert_eq(
    error_messages(report),
    "the text of `Prose` contains a reserved character (U+FDD1)",
  )
}

///|
test "prose: block content splits the paragraph, as in markup" {
  let report = compile([
    @doc.SetPage(width=Pt(200), height=Pt(200)),
    @doc.Prose("before \{@doc.Heading("Title")} after"),
  ])
  assert_eq(error_messages(report), "")
  let texts = run_texts(report)
  assert_true(texts.contains("before"))
  assert_true(texts.contains("Title"))
  assert_true(texts.contains("after"))
}

///|
test "prose: in a show callback, the view is interpolated like a description" {
  let report = compile([
    @doc.Show(@doc.Select::heading(), (it, _) => {
      @doc.Block(@doc.Prose("§ \{it} (heading)"))
    }),
    @doc.Heading("Title"),
  ])
  assert_eq(error_messages(report), "")
  let texts = run_texts(report)
  assert_true(texts.contains("Title"))
  assert_true(texts.iter().any(t => t.contains("(heading)")))
}

///|
test "prose: a delimiter character alone is text outside Prose" {
  // Found by converting the upstream suite (html-non-char): only a
  // complete placeholder is a leak.
  let report = compile([@doc.Par("a \u{FDD0} b"), @doc.Symbol("\u{FDD0}")])
  assert_eq(error_messages(report), "")
}

///|
test "prose: only canonical placeholders of issued numbers are interpolations" {
  // A number that overflows, has leading zeros or was never given out is
  // not a placeholder: in `Prose` the character is reserved.
  for
    text in [
      "\u{FDD0}4294967296000000000000\u{FDD1}", "\u{FDD0}007\u{FDD1}", "\u{FDD0}999999999999\u{FDD1}",
      "\u{FDD0}\u{FDD1}",
    ] {
    let report = compile([@doc.Prose(text)])
    assert_eq(
      error_messages(report),
      "the text of `Prose` contains a reserved character (U+FDD0)",
    )
    // Elsewhere it is text.
    let report = compile([@doc.Par(text)])
    assert_eq(error_messages(report), "")
  }
}

///|
test "prose: placeholders are found in every string that is lowered" {
  let leak = (build : (String) -> &@doc.IntoContent) => {
    let report = compile([build("x\{@doc.Emph("e")}")])
    error_messages(report)
  }
  let expected = "`Emph` was interpolated into a string that is not the text of `Prose`"
  // Literal text and string values.
  assert_eq(leak(s => @doc.Lit(s)), expected)
  assert_eq(leak(s => @doc.Value::str(s)), expected)
  assert_eq(leak(s => @doc.Markup(s)), expected)
  assert_eq(leak(s => @doc.Equation(s)), expected)
  // Names: dictionary keys, argument names, paths, scope names, keys,
  // labels.
  assert_eq(leak(s => @doc.Value::dict([(s, @doc.Value::int(0))])), expected)
  assert_eq(
    leak(s => @doc.Call("text", named=[(s, @doc.Value::int(0))])),
    expected,
  )
  assert_eq(leak(s => @doc.Call(s)), expected)
  assert_eq(leak(s => @doc.Value::global(s)), expected)
  assert_eq(
    leak(s => @doc.Markup("x", scope=[(s, @doc.Value::int(0))])),
    expected,
  )
  assert_eq(leak(s => @doc.Keyed(s, "x")), expected)
  assert_eq(leak(s => @doc.Labelled("x", s)), expected)
  assert_eq(
    leak(s => @doc.Heading("x", extra=[(s, @doc.Value::int(0))])),
    expected,
  )
  // The directory of a document.
  let report = @doc.Document(["x"], dir="d\{@doc.Emph("e")}").compile_paged(
    @doc.DocWorld::in_memory(),
  )
  assert_eq(error_messages(report), expected)
}

///|
test "prose: nested and repeated interpolation" {
  let inner = @doc.Emph("inner")
  let report = compile([
    @doc.Prose(
      "a \{@doc.Strong(@doc.Prose("b \{inner} c"))} d \{inner} e \{inner}",
    ),
  ])
  assert_eq(error_messages(report), "")
  let texts = run_texts(report)
  // The description is interpolated three times: three occurrences.
  assert_eq(texts.filter(t => t == "inner").length(), 1)
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let mut inner_glyphs = 0
  for glyph in glyphs {
    if glyph.0 == "inner" {
      inner_glyphs += 1
    }
  }
  assert_eq(inner_glyphs, 15)
}

///|
test "debug: a description prints as its constructor call, not as a placeholder" {
  let heading = @doc.Heading("Title", level=2, label="t")
  @debug.debug_inspect(
    heading,
    content=(
      #|Labelled(Heading("Title", level=2), label="t")
    ),
  )
  @debug.debug_inspect(
    @doc.Seq([
      @doc.SetText(size=Pt(9), fill=Red),
      @doc.Prose("a \"b\" \{@doc.Emph("c")}"),
      @doc.Raw("fn main() {}", lang="rust", block=true),
      @doc.Show(@doc.Select::heading(level=1), (it, _) => it),
      @doc.Value::dict([("k", @doc.Value::length(Pt(1) + Em(2)))]),
    ]),
    content=(
      #|Seq(
      #|  [
      #|    SetText(size=9pt, fill=red),
      #|    Prose(
      #|      [
      #|        "a",
      #|        Space,
      #|        smartquote(double=true),
      #|        "b",
      #|        smartquote(double=true),
      #|        Space,
      #|        Emph("c"),
      #|      ],
      #|    ),
      #|    Raw("fn main() {}", block=true, lang="rust"),
      #|    Show(where(heading, level=1), <callback>),
      #|    { "k": add(1pt, 2em) },
      #|  ],
      #|)
    ),
  )
  // In a string: `Repr` is readable, plain interpolation is the hook of
  // `Prose`.
  inspect(
    "see \{@debug.Repr(@doc.Emph("x"))}",
    content=(
      #|see Emph("x")
    ),
  )
  assert_true("\{@doc.Emph("x")}".contains("\u{FDD0}"))
}
