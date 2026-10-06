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
    "`Emph` was interpolated into a string that is not the text of `Prose` or `Para`",
  )
  assert_true(report.errors[0].hints[0].message.contains("Prose"))
  // Also as a value (the text of `Raw`).
  let report = compile([@doc.Raw("x \{@doc.Strong("y")}")])
  assert_eq(
    error_messages(report),
    "`Strong` was interpolated into a string that is not the text of `Prose` or `Para`",
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
    "an interpolated description of this text was already used by another `Prose` or `Para`",
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
  let expected = "`Emph` was interpolated into a string that is not the text of `Prose` or `Para`"
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

///|
test "prose: a placeholder in a string that a function returns is a leak" {
  // The text of a file, read by a call in a stream and by a call as a
  // value.
  let files : Map[String, Bytes] = {
    "x.txt": @utf8.encode("see \{@doc.Emph("x")}"),
  }
  let expected = "`Emph` was interpolated into a string that is not the text of `Prose` or `Para`"
  let report = compile(
    [@doc.Call("read", positional=[@doc.Value::str("x.txt")])],
    files~,
  )
  assert_eq(error_messages(report), expected)
  let report = compile(
    [@doc.Par(@doc.Value::call("read", positional=[@doc.Value::str("x.txt")]))],
    files~,
  )
  assert_eq(error_messages(report), expected)
}

///|
test "prose: text runs resolve to the text argument of the Prose call" {
  let report = compile([@doc.Prose("alpha \{@doc.Emph("beta")} gamma")])
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let mut runs = 0
  for glyph in glyphs {
    // The spaces of the prose have no span, like `Space()`.
    guard report.origins.resolve(glyph.1) is Some(origin) else { continue }
    if glyph.0 == "beta" {
      assert_eq(origin.kind, "Emph")
    } else {
      // The words of the prose: the `text` argument of the `Prose` call.
      assert_eq(origin.kind, "Prose")
      assert_eq(origin.param, Some(0))
      runs += 1
    }
  }
  assert_true(runs > 0)
}

///|
/// The pieces of lowered content that carry a span (text, smart quotes,
/// paragraph breaks) with their spans as byte ranges of the origin listing.
fn pieces(content : @library.Content) -> Array[(String, @syntax.Span)] {
  let out = []
  content.traverse(elem => {
    let func = elem.elem()
    if func == @library.text_elem() {
      out.push(("text", elem.span()))
    } else if func == @library.smart_quote_elem() {
      out.push(("quote", elem.span()))
    } else if func == @library.parbreak_elem() {
      out.push(("break", elem.span()))
    }
    true
  })
  |> ignore
  out
}

///|
/// The number of distinct spans.
fn distinct_spans(spans : Array[@syntax.Span]) -> Int {
  let seen : Map[String, Unit] = Map([])
  for span in spans {
    let key = match span.get() {
      Range(start~, end~, ..) => "\{start}-\{end}"
      _ => "?"
    }
    seen[key] = ()
  }
  seen.length()
}

///|
/// The key hashes of the end tags of a frame, in order.
fn tag_keys(frame : @library.Frame, out : Array[@library.U128]) -> Unit {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => tag_keys(group.frame, out)
      Tag(End(_, key, _)) => out.push(key)
      _ => ()
    }
  }
}

///|
/// The number of end tags of a compiled document and of distinct keys
/// among them.
fn count_keys(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> (Int, Int) raise {
  let keys = []
  for page in report.unwrap().pages() {
    tag_keys(page.frame, keys)
  }
  let seen : Map[@library.U128, Unit] = Map([])
  for key in keys {
    seen[key] = ()
  }
  (keys.length(), seen.length())
}

///|
test "prose: every text run, quote and paragraph break has a span of its own" {
  // Like the expressions of the twin (`[#"row" #smartquote()..]`): the
  // engine hashes spans into the keys of located elements and
  // deduplicates diagnostics by span.
  let report = @doc.Document([@doc.Prose("row \"row\"\n\nrow \"row\"")]).lower(
    @doc.DocWorld::in_memory(),
  )
  let found = pieces(report.unwrap())
  inspect(
    found.map(piece => piece.0).join(" "),
    content="text quote text quote break text quote text quote",
  )
  assert_eq(distinct_spans(found.map(piece => piece.1)), found.length())
  // All of them are the `text` argument of the `Prose` call, and no origin
  // was registered for them.
  for piece in found {
    guard report.origins.resolve(piece.1) is Some(origin) else {
      fail("no origin")
    }
    assert_eq(origin.kind, "Prose")
    assert_eq(origin.param, Some(0))
    assert_true(origin.keys.is_empty())
  }
  assert_eq(report.origins.length(), 2)
}

///|
test "prose: paragraphs with equal words are different elements" {
  // Found by converting the upstream suite in the readable mode
  // (`[row #colbreak() row]`): with one span for all text runs the two
  // paragraphs were equal including their spans, so their tags had the
  // same key, unlike the markup's.
  let prose = compile([@doc.Prose("row\n\nrow\n\n\"\n\n\"")])
  let markup = compile([
    @doc.Markup("row\n\nrow\n\n#smartquote()\n\n#smartquote()"),
  ])
  assert_eq(count_keys(prose), (4, 4))
  assert_eq(count_keys(markup), (4, 4))
  // Plain strings of a sequence and the quotes of `Quoted` likewise.
  let seq = compile([@doc.Seq(["same", @doc.Parbreak(), "same"])])
  assert_eq(count_keys(seq), (2, 2))
  let quoted = compile([@doc.Quoted(@doc.Parbreak())])
  assert_eq(count_keys(quoted), (2, 2))
  // One description with a site used twice has the spans of its site in
  // both places (`#let p = par[row]`, `#p#p`): equal elements with equal
  // spans share their key, and the engine tells them apart by their order.
  let par = @doc.Par("row")
  let twice = compile([par, par])
  assert_eq(count_keys(twice), (2, 1))
  let twice = compile([@doc.Markup("#let p = par[row]\n#p#p")])
  assert_eq(count_keys(twice), (2, 1))
}

///|
test "prose: thousands of pieces keep distinct spans and add few origins" {
  // The sub-ranges of the text argument's span run out after as many
  // pieces as its token has bytes; further occurrences of the origin
  // provide more, one line of the origin listing each. They are the same
  // origin: their keys are not reported.
  let words = StringBuilder()
  for i in 0..<5000 {
    words.write_string(if i % 7 == 0 { "\"w\" " } else { "w " })
  }
  let report = @doc.Document([@doc.Prose(words.to_string())]).lower(
    @doc.DocWorld::in_memory(),
  )
  let found = pieces(report.unwrap())
  assert_eq(found.length(), 5000 + 2 * 715)
  assert_eq(distinct_spans(found.map(piece => piece.1)), found.length())
  for piece in found {
    guard report.origins.resolve(piece.1) is Some(origin) else {
      fail("no origin")
    }
    assert_eq(origin.kind, "Prose")
    assert_eq(origin.param, Some(0))
    assert_true(origin.keys.is_empty())
  }
  assert_true(report.origins.length() > 2)
  assert_true(report.origins.length() < found.length() / 20)
}

///|
test "pieces: all spans inside one argument are distinct, however nested" {
  // Found by review: the arguments of a call value among the pieces are
  // spanned inside the same argument as the pieces. They take spans of the
  // same counter, so the seventeenth argument, the arguments of nested
  // call values and of calls near the end of a block of sub-ranges are
  // all distinct from the pieces and from each other.
  let cell = (text : String) => @doc.Value::content(text)
  let children : Array[&@doc.IntoContent] = []
  for _ in 0..<300 {
    let args : Array[@doc.Value] = []
    for _ in 0..<20 {
      args.push(cell("x"))
    }
    args.push(
      @doc.Value::call("grid", positional=[
        cell("x"),
        @doc.Value::call("grid", positional=[cell("x"), cell("x")]),
        cell("x"),
      ]),
    )
    args.push(cell("x"))
    children.push(@doc.Value::call("grid", positional=args))
    children.push("x")
  }
  let report = @doc.Document([@doc.Seq(children)]).lower(
    @doc.DocWorld::in_memory(),
  )
  let found = pieces(report.unwrap())
  assert_eq(found.length(), 300 * 26)
  assert_eq(distinct_spans(found.map(piece => piece.1)), found.length())
  for piece in found {
    guard report.origins.resolve(piece.1) is Some(origin) else {
      fail("no origin")
    }
    assert_eq(origin.kind, "Seq")
    assert_eq(origin.param, Some(0))
    assert_true(origin.keys.is_empty())
  }
  // The arguments of a located call that share a location, and the call
  // values among them.
  let args : Array[@doc.Value] = []
  for _ in 0..<40 {
    args.push(cell("x"))
    args.push(@doc.Value::call("grid", positional=[cell("x"), cell("x")]))
  }
  let report = @doc.Document([@doc.Call("grid", positional=args)]).lower(
    @doc.DocWorld::in_memory(),
  )
  let found = pieces(report.unwrap())
  assert_eq(found.length(), 120)
  assert_eq(distinct_spans(found.map(piece => piece.1)), 120)
  for piece in found {
    guard report.origins.resolve(piece.1) is Some(origin) else {
      fail("no origin")
    }
    assert_eq(origin.kind, "Call")
  }
}

///|
test "pieces: no key of `Keyed` names an occurrence of the pieces" {
  // Found by review: the occurrences that provide more spans are
  // registered under a key of their own, which no `Keyed` can have.
  let children : Array[&@doc.IntoContent] = []
  for _ in 0..<400 {
    children.push("same")
  }
  children.push(@doc.Keyed("pieces 1", "same"))
  children.push(@doc.Keyed("pieces 1", @doc.Keyed("pieces 2", "same")))
  children.push(@doc.Keyed("x\u{FDD2}", @doc.Emph("same")))
  let report = @doc.Document([@doc.Seq(children)]).lower(
    @doc.DocWorld::in_memory(),
  )
  let found = pieces(report.unwrap())
  assert_eq(found.length(), 403)
  assert_eq(distinct_spans(found.map(piece => piece.1)), 403)
  let report = compile([@doc.Keyed("\u{FDD2}pieces 1", "same")])
  inspect(
    error_messages(report),
    content="the key of `Keyed` starts with a reserved character (U+FDD2)",
  )
}

///|
test "pieces: the values of a `Markup` scope share one counter" {
  // Found by review: every scope value restarted the counter of the call's
  // span, so the second cells of the two grids had the same span and the
  // grids were one element for the engine (the same key).
  let grid = () => {
    @doc.Value::call("grid", positional=[
      @doc.Value::content("x"),
      @doc.Value::content("x"),
    ])
  }
  let document : Array[&@doc.IntoContent] = [
    @doc.Markup("#a #b #c", scope=[("a", grid()), ("b", grid()), ("c", grid())]),
  ]
  let report = @doc.Document(document).lower(@doc.DocWorld::in_memory())
  let found = pieces(report.unwrap())
  assert_eq(found.length(), 6)
  assert_eq(distinct_spans(found.map(piece => piece.1)), 6)
  for piece in found {
    guard report.origins.resolve(piece.1) is Some(origin) else {
      fail("no origin")
    }
    assert_eq(origin.kind, "Markup")
  }
  let (tags, keys) = count_keys(compile(document))
  assert_true(tags >= 3)
  assert_eq(keys, tags)
  // One binding that the source uses twice is one value used twice by
  // Typst: equal elements with equal spans, which share their keys.
  let same = grid()
  let (tags, keys) = count_keys(
    compile([@doc.Markup("#a #a", scope=[("a", same)])]),
  )
  assert_true(keys < tags)
  // A value has no location and no identity: used in two bindings, it is
  // lowered for each and is a piece in each, like the expression written
  // twice (`scope: (a: grid(..), b: grid(..))`).
  let (tags, keys) = count_keys(
    compile([@doc.Markup("#a #b", scope=[("a", same), ("b", same)])]),
  )
  assert_eq(keys, tags)
  // Likewise as two children of a sequence, unlike a description with a
  // site of its own, which has the spans of its site in both places.
  let (tags, keys) = count_keys(compile([@doc.Seq([same, same])]))
  assert_eq(keys, tags)
  let located = @doc.Call("grid", positional=[
    @doc.Value::content("x"),
    @doc.Value::content("x"),
  ])
  let (tags, keys) = count_keys(compile([@doc.Seq([located, located])]))
  assert_true(keys < tags)
}

///|
test "pieces: an error at an argument is inside the call in every block" {
  // Found by review: the spans of further occurrences are other lines of
  // the origin listing than the call. For trace points they count as the
  // spans inside the call that they stand for, so an error at the last of
  // many arguments has the same trace as an error at the second.
  let failing = (cells : Int) => {
    let args : Array[@doc.Value] = []
    for _ in 0..<cells {
      args.push(@doc.Value::content("x"))
    }
    compile([
      @doc.Call("grid", positional=args, named=[("bogus", @doc.Value::int(1))]),
    ])
  }
  let few = failing(2)
  let many = failing(700)
  inspect(error_messages(few), content="unexpected argument: bogus")
  assert_eq(error_messages(many), error_messages(few))
  assert_eq(origin_of(many.errors[0]).kind, "Call")
  assert_eq(
    many.errors[0].trace.map(point => point.description),
    few.errors[0].trace.map(point => point.description),
  )
  // A call value among the pieces of a sequence, in a later block.
  let failing = (before : Int, cells : Int) => {
    let children : Array[&@doc.IntoContent] = []
    for _ in 0..<before {
      children.push("x")
    }
    let args : Array[@doc.Value] = []
    for _ in 0..<cells {
      args.push(@doc.Value::content("x"))
    }
    children.push(
      @doc.Value::call("grid", positional=args, named=[
        ("bogus", @doc.Value::int(1)),
      ]),
    )
    compile([@doc.Seq(children)])
  }
  let few = failing(0, 2)
  inspect(error_messages(few), content="unexpected argument: bogus")
  for shape in [(0, 700), (700, 2), (130, 130), (45, 45), (0, 61), (60, 3)] {
    let many = failing(shape.0, shape.1)
    assert_eq(error_messages(many), error_messages(few))
    assert_eq(origin_of(many.errors[0]).kind, "Seq")
    assert_eq(
      many.errors[0].trace.map(point => point.description),
      few.errors[0].trace.map(point => point.description),
    )
  }
}

///|
test "pieces: an error in a later block is outside unrelated calls" {
  // Found by review: the range that a span of a further occurrence counts
  // as must be a range of its own origin, or calls on other lines would
  // seem to contain it and lose their trace points. A numbering callback
  // returns a call that fails at its last argument: the trace of the
  // surrounding `numbering` call stays, whatever the number of arguments.
  let failing = (cells : Int) => {
    let numbering = @doc.Numbering::func() <| ((_, _) => {
      let args : Array[@doc.Value] = []
      for _ in 0..<cells {
        args.push(@doc.Value::content("x"))
      }
      @doc.Call("grid", positional=args, named=[("bogus", @doc.Value::int(1))])
    })
    compile([
      @doc.Call("numbering", positional=[
        @doc.ToValue::to_value(numbering),
        @doc.Value::int(1),
      ]),
    ])
  }
  let few = failing(2)
  inspect(error_messages(few), content="unexpected argument: bogus")
  assert_eq(few.errors[0].trace.map(point => point.description), [
    "while calling `numbering`",
  ])
  for cells in [61, 130, 700] {
    let many = failing(cells)
    assert_eq(error_messages(many), error_messages(few))
    assert_eq(
      many.errors[0].trace.map(point => point.description),
      few.errors[0].trace.map(point => point.description),
    )
  }
}

///|
test "debug: generic targets and views" {
  @debug.debug_inspect(
    @doc.ShowSet(@doc.Select::heading(), @doc.Set("text", [])),
    content=(
      #|ShowSet(heading, Set("text"))
    ),
  )
  @debug.debug_inspect(
    @doc.ShowSet(@doc.Select::heading(), @doc.Set("par", [])),
    content=(
      #|ShowSet(heading, Set("par"))
    ),
  )
  @debug.debug_inspect(
    @doc.Document(
      [@doc.Call("emph", positional=[@doc.Value::content("x")])],
      dir="a/b",
    ),
    content=(
      #|Document([Call("emph", "x")], dir="a/b")
    ),
  )
}
