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
