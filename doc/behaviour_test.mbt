// Behavioural tests of the EDSL that have no single Typst twin
// (docs/edsl-design.md, section 17): callbacks, context, rules,
// provenance and reports.

///|
/// Compile with the in-memory world.
fn compile(
  children : Array[&@doc.IntoContent],
  files? : Map[String, Bytes] = Map([]),
) -> @doc.CompileReport[@layout.PagedDocument] {
  @doc.Document(children).compile_paged(@doc.DocWorld::in_memory(files~))
}

///|
/// The messages of the errors of a report.
fn error_messages(report : @doc.CompileReport[@layout.PagedDocument]) -> String {
  report.errors.map(e => e.message).join(" | ")
}

///|
/// The EDSL origin of a diagnostic.
fn origin_of(diagnostic : @doc.Diagnostic) -> @doc.Origin raise {
  guard diagnostic.location is Some(Edsl(origin)) else {
    fail("expected an EDSL location: \{diagnostic.render()}")
  }
  origin
}

///|
/// The glyphs of a frame with their text, span and span offset.
fn collect_glyphs(
  frame : @library.Frame,
  out : Array[(String, @syntax.Span, Int)],
) -> Unit {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => collect_glyphs(group.frame, out)
      Text(text) =>
        for glyph in text.glyphs {
          out.push((text.text, glyph.span, glyph.span_offset.to_int()))
        }
      _ => ()
    }
  }
}

///|
/// The origins of the text of a compiled document: for each text run its
/// text and the constructor (and keys) of the origin of its first glyph.
fn text_origins(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[String] raise {
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let out : Array[String] = []
  for glyph in glyphs {
    let (text, span, offset) = glyph
    let line = match report.origins.resolve_glyph(span, offset) {
      Some(found) => {
        let keys = if found.origin.keys.is_empty() {
          ""
        } else {
          " " + found.origin.keys.join("/")
        }
        "\{text}: \{found.origin.kind}\{keys}"
      }
      None => "\{text}: -"
    }
    if !out.contains(line) {
      out.push(line)
    }
  }
  out
}

///|
test "a rule outside `Document` and `Seq` is an error at the rule" {
  let as_argument = compile([@doc.Par(@doc.SetText(size=Pt(9)))])
  inspect(
    error_messages(as_argument),
    content=(
      #|rules are only allowed directly in `Document` and `Seq`
    ),
  )
  inspect(origin_of(as_argument.errors[0]).kind, content="SetText")
  inspect(
    as_argument.errors[0].hints.map(h => h.message).join(" | "),
    content=(
      #|wrap the rule and the content it styles in `Seq([..])`
    ),
  )
  // A variadic array is not a sequence: a rule is not an entry of it.
  let in_table = compile([
    @doc.Table([@doc.SetText(size=Pt(9)), "a", "b"], columns=[Auto, Auto]),
  ])
  inspect(
    error_messages(in_table),
    content=(
      #|rules are only allowed directly in `Document` and `Seq`
    ),
  )
  // In a sequence the rule styles what follows it, also inside a cell.
  let in_cell = compile([
    @doc.Table([@doc.Seq([@doc.SetText(size=Pt(9)), "a"]), "b"], columns=[
      Auto,
      Auto,
    ]),
  ])
  inspect(error_messages(in_cell), content="")
}

///|
test "show rules: recipe checks and selector validation are Typst's" {
  let show_page = compile([
    @doc.Show(@doc.Select::page()) <| ((it, _) => it),
    "text",
  ])
  inspect(error_messages(show_page), content="")
  inspect(
    show_page.warnings.map(w => w.message).join(" | "),
    content=(
      #|`show page` is not supported and has no effect
    ),
  )
  inspect(origin_of(show_page.warnings[0]).kind, content="Show")
  // A selector that is not showable is rejected at the selector argument.
  let invalid = compile([
    @doc.Show(@doc.Select::regex("a").or(@doc.Select::heading())) <| ((it, _) => {
      @doc.Content(it)
    }),
    "text",
  ])
  inspect(
    error_messages(invalid),
    content=(
      #|this selector cannot be used with show
    ),
  )
  assert_eq(origin_of(invalid.errors[0]).param, Some(0))
}

///|
test "a callback description is one host function per compilation" {
  let context = @doc.Context() <| _ => { "x" }
  let document = @doc.Document([
    context,
    context,
    @doc.Context() <| _ => { "x" },
  ])
  let lowered = document.lower(@doc.DocWorld::in_memory()).unwrap()
  guard lowered.to_sequence() is Some(children) else { fail("no sequence") }
  let func = (content : @library.Content) => {
    content.field_raw(@library.context_elem_func).unwrap()
  }
  // The same description twice: the same function. Another description at
  // another site: another function.
  assert_true(func(children[0]) == func(children[1]))
  assert_false(func(children[0]) == func(children[2]))
  inspect(func(children[0]).repr(), content="(..) => ..")
  // A second lowering creates its own functions.
  let again = document.lower(@doc.DocWorld::in_memory()).unwrap()
  guard again.to_sequence() is Some(others) else { fail("no sequence") }
  assert_false(func(children[0]) == func(others[0]))
  // But the keys (fingerprints) are reproducible.
  assert_true(
    @library.hash128(func(children[0])) == @library.hash128(func(others[0])),
  )
}

///|
test "callbacks cannot be created inside a callback" {
  let nested = compile([
    @doc.Context() <| _ => { @doc.Context() <| _ => { "inner" } },
  ])
  inspect(
    error_messages(nested),
    content=(
      #|callbacks cannot be created inside a callback
    ),
  )
  inspect(origin_of(nested.errors[0]).kind, content="Context")
  // Created before compiling and captured: fine, also inside a callback
  // result and in a show rule that runs many times.
  let inner = @doc.Context() <| cx => {
    cx.counter(@doc.Counter::page()).display()
  }
  let captured = compile([
    @doc.Show(@doc.Select::heading()) <| ((it, _) => @doc.Seq([it, inner])),
    @doc.Heading("One"),
    @doc.Heading("Two"),
    @doc.Context() <| _ => { inner },
  ])
  inspect(error_messages(captured), content="")
}

///|
test "a `Ctx` is only valid during its callback" {
  let stale : Array[@doc.Ctx] = []
  let report = compile([
    @doc.Context() <| cx => {
      stale.push(cx)
      // During the callback it works, also through derived handles.
      let page = cx.counter(@doc.Counter::page())
      "page \{page.get()[0]}"
    },
  ])
  inspect(error_messages(report), content="")
  let cx = stale[0]
  let message = try cx.location() catch {
    @library.SourceError(errors) => errors[0].message
    _ => "other error"
  } noraise {
    _ => "no error"
  }
  inspect(message, content="context used outside of its callback")
  let handle = cx.counter(@doc.Counter::page())
  let message = try handle.get() catch {
    @library.SourceError(errors) => errors[0].message
    _ => "other error"
  } noraise {
    _ => "no error"
  }
  inspect(message, content="context used outside of its callback")
}

///|
test "context capabilities are the engine's, per callback kind" {
  // `Context`: location and styles.
  let context = compile([
    @doc.Context() <| cx => {
      cx.location() |> ignore
      cx.styles() |> ignore
      let size = cx.measure("wide text")
      assert_true(size.width > 10.0)
      let headings = cx.query(@doc.Select::heading())
      "\{headings.length()}"
    },
  ])
  inspect(error_messages(context), content="")
  // `Show` on text: styles, but no location (text has none).
  let show = compile([
    @doc.Show(@doc.Select::literal("word")) <| ((it, cx) => {
      cx.styles() |> ignore
      cx.location() |> ignore
      it
    }),
    "a word",
  ])
  inspect(
    error_messages(show),
    content=(
      #|can only be used when context is known
    ),
  )
  // The error is located at the operation.
  inspect(origin_of(show.errors[0]).kind, content="Ctx::location")
  // Initial lowering has no context at all: a contextual function fails
  // like at the top level of a Typst file.
  let top = compile([@doc.Call("here")])
  inspect(
    error_messages(top),
    content=(
      #|can only be used when context is known
    ),
  )
}

///|
test "any error raised by a callback is a diagnostic at the callback" {
  let report = compile([
    @doc.Context() <| _ => {
      if true {
        fail("boom")
      }
      "unreachable"
    },
  ])
  assert_eq(report.errors.length(), 1)
  assert_true(report.errors[0].message.contains("boom"))
  inspect(origin_of(report.errors[0]).kind, content="Context")
}

///|
test "a query whose results hold host functions converges" {
  // The headings carry a numbering callback; a context queries them. The
  // recorded query result contains the host function, which is the same
  // function in every iteration.
  let numbering = @doc.Numbering::func() <| ((numbers, _) => "§\{numbers[0]}")
  let report = compile([
    @doc.Set("heading", [("numbering", @doc.ToValue::to_value(numbering))]),
    @doc.Heading("One"),
    @doc.Heading("Two"),
    @doc.Context() <| cx => {
      let headings = cx.query(@doc.Select::heading())
      "\{headings.length()} headings"
    },
  ])
  inspect(error_messages(report), content="")
  inspect(
    report.warnings.map(w => w.message).join(" | "),
    content=(
      #|
    ),
  )
}

///|
test "host functions do not add layout iterations" {
  // The absence of a convergence warning does not show convergence (equal
  // histories are not reported): count the runs of a context callback
  // instead. They are the same whether the queried headings are numbered
  // by a pattern or by a host function, and also if the query's selector
  // holds the host function.
  let runs_of = (numbering : @doc.Numbering, by_numbering : Bool) => {
    let runs = @ref.Ref::{ val: 0, }
    let found = @ref.Ref::{ val: 0, }
    let report = compile([
      @doc.SetHeading(numbering~),
      @doc.Heading("One"),
      @doc.Heading("Two"),
      @doc.Context() <| cx => {
        runs.val += 1
        let selector = if by_numbering {
          @doc.Select::heading(numbering~)
        } else {
          @doc.Select::heading()
        }
        found.val = cx.query(selector).length()
        "\{found.val} headings"
      },
    ])
    assert_eq(error_messages(report), "")
    assert_eq(report.warnings.length(), 0)
    assert_eq(found.val, 2)
    runs.val
  }
  let host = @doc.Numbering::func() <| ((numbers, _) => "§\{numbers[0]}")
  let plain = runs_of(@doc.Numbering("1."), false)
  assert_eq(runs_of(@doc.Numbering("1."), true), plain)
  assert_eq(runs_of(host, false), plain)
  assert_eq(runs_of(host, true), plain)
}

///|
test "a callback description used twice runs for each occurrence" {
  // One host function, but the content it returns belongs to the
  // occurrence it was invoked for.
  let plain = @doc.Context() <| _ => { "x" }
  let report = compile([@doc.Keyed("a", plain), @doc.Keyed("b", plain)])
  inspect(error_messages(report), content="")
  inspect(
    text_origins(report).join(" | "),
    content="x: Context a | x: Context b",
  )
  let located = @doc.Context() <| _ => { @doc.Par("y") }
  let report = compile([@doc.Keyed("a", located), @doc.Keyed("b", located)])
  inspect(text_origins(report).join(" | "), content="y: Par a | y: Par b")
  // Errors too.
  let failing = @doc.Context() <| _ => { @doc.Text("z", size=Auto) }
  let report = compile([@doc.Keyed("a", "ok"), @doc.Keyed("b", failing)])
  inspect(error_messages(report), content="expected length, found auto")
  inspect(origin_of(report.errors[0]).keys.join("/"), content="b")
}

///|
test "plain strings in `Keyed` resolve to the enclosing argument under the key" {
  let report = compile([
    @doc.Keyed("a", "alpha"),
    @doc.Par(" "),
    @doc.Keyed("b", @doc.Keyed("c", "beta")),
  ])
  inspect(error_messages(report), content="")
  inspect(
    text_origins(report).join(" | "),
    content="alpha: Document a |  : Par | beta: Document b/c",
  )
  // The argument's location is kept.
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let (_, span, offset) = glyphs[0]
  guard report.origins.resolve_glyph(span, offset) is Some(found) else {
    fail("no origin")
  }
  assert_eq(found.origin.param, Some(0))
}

///|
test "glyphs resolve to their constructor calls, keys and callbacks" {
  let rows = ["alpha", "beta"]
  let report = compile([
    @doc.Show(@doc.Select::emph()) <| ((it, _) => {
      @doc.Seq([it, @doc.Strong("!")])
    }),
    @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed"), @doc.Lit(" tail")])),
    @doc.Seq::of(rows.map(row => @doc.Keyed(row, @doc.Par(row)))),
    @doc.Markup("from *markup*"),
  ])
  inspect(error_messages(report), content="")
  inspect(
    text_origins(report).join(" | "),
    content=(
      #|plain : Seq | stressed: Emph | !: Strong |  tail: Lit | alpha: Par alpha | beta: Par beta | from : Markup | markup: Markup
    ),
  )
  // One origin per call site and key, however often it is laid out.
  let again = compile([
    @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed")])),
    @doc.Par(@doc.Seq(["plain ", @doc.Emph("stressed")])),
  ])
  assert_eq(again.origins.length(), 7)
}

///|
test "origins of one site are registered once across layout iterations" {
  // The outline forces several layout iterations; the show callback makes
  // new nodes in each of them.
  let build = () => {
    compile([
      @doc.Show(@doc.Select::heading()) <| ((it, _) => {
        @doc.Block(@doc.Seq([it, @doc.Emph("shown")]))
      }),
      @doc.Outline(),
      @doc.Heading("One"),
      @doc.Heading("Two"),
      @doc.Heading("Three"),
    ])
  }
  let first = build()
  inspect(error_messages(first), content="")
  // Show, Outline, 3 headings sharing nothing, Document, plus the nodes of
  // the callback (Block, Seq, Emph): one line each.
  let lines = first.origins.listing().split("\n").filter(l => !l.is_empty())
  assert_eq(lines.count(), first.origins.length())
  assert_eq(first.origins.length(), 9)
  // Deterministic: another compilation registers the same origins.
  assert_eq(
    build().origins.listing().length(),
    first.origins.listing().length(),
  )
}

///|
test "a report keeps its locations after other compilations" {
  let failed = compile([@doc.Image("missing.png")])
  let before = failed.errors[0].render()
  // Other compilations reuse the virtual file ids.
  compile([@doc.Par("a"), @doc.Par("b"), @doc.Par("c")]) |> ignore
  compile([@doc.Image("other.png")]) |> ignore
  assert_eq(failed.errors[0].render(), before)
  inspect(origin_of(failed.errors[0]).kind, content="Image")
  assert_true(before.contains("behaviour_test.mbt"))
  // The raw span still resolves with the report's own snapshot.
  let raw = failed.errors[0].raw
  guard failed.origins.resolve_range(raw.span) is Some(origin) else {
    fail("the span does not resolve")
  }
  inspect(origin.kind, content="Image")
  // An export of a failed compilation reports the same errors.
  let exported = failed.pdf()
  assert_true(exported.output() is None)
  assert_eq(exported.errors[0].render(), before)
}

///|
test "errors in files imported by markup are located in those files" {
  let files : Map[String, Bytes] = {
    "lib.typ": b"#let f(x) = {\n  x + \"a\"\n}\n",
  }
  let report = compile([@doc.Markup("#import \"lib.typ\": f\n#f(1)")], files~)
  inspect(
    error_messages(report),
    content=(
      #|cannot add integer and string
    ),
  )
  guard report.errors[0].location is Some(File(file)) else {
    fail("expected a file location")
  }
  inspect(file.path, content="lib.typ")
  assert_eq((file.line, file.column), (2, 3))
  // The trace leads back to the markup source and its constructor call.
  let trace = report.errors[0].trace
  assert_true(trace.length() >= 1)
  guard trace[0].location is Some(Edsl(origin)) else {
    fail("expected an EDSL location in the trace")
  }
  inspect(origin.kind, content="Markup")
  assert_true(origin.text_range is Some(_))
  // A syntax error in the markup itself is located in the source string.
  let syntax = compile([@doc.Markup("a #( b")])
  guard syntax.errors[0].location is Some(Edsl(origin)) else {
    fail("expected an EDSL location")
  }
  inspect(origin.kind, content="Markup")
  assert_eq(origin.text_range, Some((3, 4)))
}

///|
test "text longer than the offset range reports no offset" {
  let long = "word ".repeat(14000)
  // Also for strings that reach text as values and as raw text.
  let report = compile([
    @doc.Par(long),
    @doc.Value::str(long),
    @doc.Raw(long),
    @doc.Par("short"),
  ])
  inspect(error_messages(report), content="")
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let mut long_offsets = 0
  let mut short_offsets = 0
  for glyph in glyphs {
    let (text, span, offset) = glyph
    guard report.origins.resolve_glyph(span, offset) is Some(found) else {
      continue
    }
    if text.contains("short") {
      assert_true(found.engine_offset is Some(_))
      short_offsets += 1
    } else if found.engine_offset is Some(_) {
      long_offsets += 1
    }
  }
  assert_true(short_offsets > 0)
  assert_eq(long_offsets, 0)
}
