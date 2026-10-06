// `Composite` (docs/edsl-ports.md, section 4): the provenance of elements
// that are defined outside `doc` by an expansion into its constructors.
// The elements of these tests are defined here, with the public hook only,
// as a package of elements defines them. (`compile`, `compile_on_page`,
// `origin_of`, `error_messages`, `lowered`, `lint_lines` and the other
// helpers are those of the other test files of this package.)

///|
/// Tiles: a grid. Its parameters are not in the order of `Grid`'s: `gutter`
/// is parameter 2 here and 3 there, `fill` 3 here and 8 there.
#callsite(autofill(loc, args_loc))
fn tiles(
  items : Array[&@doc.IntoContent],
  columns : Int,
  gutter? : Array[@doc.Sizing],
  fill? : @doc.Paint,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Tiles", loc, args_loc, site => {
    @doc.Grid(
      site.arg(0, items),
      columns=@doc.Sizing::repeat(site.arg(1, columns), size=Fr(1)),
      gutter?=gutter.map(v => site.arg(2, v)),
      fill?=fill.map(v => @doc.Cells::all(site.arg(3, v))),
    )
  })
}

///|
/// A titled note: the body is its second parameter and the first of the
/// `Block` that it is passed to. `mark` is text that the element generates.
#callsite(autofill(loc, args_loc))
fn titled(
  title : String,
  body : &@doc.IntoContent,
  mark? : String = "!",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Titled", loc, args_loc, site => {
    @doc.Seq([
      @doc.Strong(site.arg(0, title)),
      @doc.Text(mark, size=Pt(6)),
      @doc.Block(site.arg(1, body), inset=@doc.Sides(all=Pt(2))),
    ])
  })
}

///|
/// A filled panel of 60pt by 30pt.
#callsite(autofill(loc, args_loc))
fn panel(
  body : &@doc.IntoContent,
  fill : @doc.Paint,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Panel", loc, args_loc, site => {
    @doc.Block(
      site.arg(0, body),
      fill=site.arg(1, fill),
      width=Pt(60),
      height=Pt(30),
    )
  })
}

///|
/// A block per item, each under the key of its index.
#callsite(autofill(loc, args_loc))
fn rows(
  items : Array[&@doc.IntoContent],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Rows", loc, args_loc, site => {
    let blocks : Array[&@doc.IntoContent] = []
    for k, item in items {
      blocks.push(@doc.Keyed("\{k}", @doc.Block(site.arg(0, item))))
    }
    @doc.Seq(blocks)
  })
}

///|
/// A composite that is made of another one: a stroked `titled`.
#callsite(autofill(loc, args_loc))
fn framed(
  caption : String,
  body : &@doc.IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Framed", loc, args_loc, site => {
    @doc.Block(
      @doc.Seq([
        titled(site.arg(0, caption), site.arg(1, body), mark="*"),
        titled("fixed", "generated", mark=site.arg(0, caption)),
      ]),
      stroke=@doc.Sides(all=@doc.Stroke(thickness=Pt(0.5))),
    )
  })
}

///|
/// A composite that measures: the body in a block that is 4pt wider than
/// the body. `fail_with` is raised in the callback.
#callsite(autofill(loc, args_loc))
fn fit(
  body : &@doc.IntoContent,
  fail_with? : String = "",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Fit", loc, args_loc, site => {
    // The caller's content is converted once, here. The callback is a
    // part of this `build`: its constructors are the element's.
    let body = @doc.Content(body)
    @doc.Layout((_, cx) => {
      if fail_with != "" {
        fail(fail_with)
      }
      let measured = cx.measure(@doc.Block(site.arg(0, body)))
      @doc.Block(
        site.arg(0, body),
        width=Pt(measured.width + 4),
        fill=Luma(230),
      )
    })
  })
}

///|
/// One of two texts, by the width of the container.
#callsite(autofill(loc, args_loc))
fn responsive(
  narrow : String,
  wide : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Responsive", loc, args_loc, site => {
    @doc.Layout((size, _) => {
      if size.width < 100.0 {
        @doc.Seq([site.arg(0, narrow)])
      } else {
        @doc.Seq([site.arg(1, wide)])
      }
    })
  })
}

///|
/// The ways to write a mark, by `mode`.
#callsite(autofill(loc, args_loc))
fn marked(
  mode : String,
  a : String,
  b : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Marked", loc, args_loc, site => {
    match mode {
      // Bound to a name first: no mark where the name is used.
      "bound" => {
        let body = site.arg(1, a)
        @doc.Content(@doc.Block(@doc.Emph(body)))
      }
      // Marks of two parameters in one argument: the call.
      "mixed" => @doc.Content(@doc.Seq([site.arg(1, a), site.arg(2, b)]))
      // Marks of one parameter in one argument: that parameter.
      "same" => @doc.Content(@doc.Seq([site.arg(1, a), site.arg(1, b)]))
      // Inside another expression that is the argument.
      "inside" => @doc.Content(@doc.Block(@doc.Keyed("k", site.arg(1, a))))
      // One branch of the argument is evaluated.
      "branch" =>
        @doc.Content(
          @doc.Block(if a == "" { site.arg(2, b) } else { site.arg(1, a) }),
        )
      // The result of `build` itself is not an argument of a constructor;
      "result" => @doc.Content(site.arg(1, a))
      // in a sequence it is one.
      "sequence" => @doc.Content(@doc.Seq([site.arg(1, a)]))
      // A mark that nothing takes says nothing about what is returned.
      "stale" => {
        let saved = site.arg(1, a)
        ignore(saved)
        @doc.Content(b)
      }
      // No mark.
      _ => @doc.Content(@doc.Block(a))
    }
  })
}

///|
/// An argument with a default.
#callsite(autofill(loc, args_loc))
fn greeting(
  name? : String = "world",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Greeting", loc, args_loc, site => {
    if name == "" {
      return site.invalid("`Greeting` needs a name", arg=0)
    }
    if name == "nobody" {
      return site.invalid("`Greeting` greets somebody")
    }
    @doc.Content(@doc.Emph(site.arg(0, name)))
  })
}

///|
/// A paragraph of prose.
#callsite(autofill(loc, args_loc))
fn plain(
  text : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Composite {
  @doc.Composite("Plain", loc, args_loc, site => @doc.Prose(site.arg(0, text)))
}

///|
/// A type of the caller that is content.
priv struct Badge {
  text : String
}

///|
impl @doc.IntoContent for Badge with fn into_content(self) {
  @doc.Content(@doc.Emph(self.text))
}

///|
/// The origin of each text run of a compiled document: its text, the
/// constructor, the argument (`a0`: the first; `call`: none) and the keys.
fn text_args(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String raise {
  let glyphs = []
  for page in report.unwrap().pages() {
    collect_glyphs(page.frame, glyphs)
  }
  let out : Array[String] = []
  for glyph in glyphs {
    let (text, span, offset) = glyph
    let line = match report.origins.resolve_glyph(span, offset) {
      Some(found) => "\{text}: \{place(found.origin)}"
      None => "\{text}: -"
    }
    if !out.contains(line) {
      out.push(line)
    }
  }
  out.join(" | ")
}

///|
/// The origins of a feedback record: place, rendered text and tier.
fn tiers(feedback : @doc.Feedback) -> String {
  feedback.origins
  .map(o => "\{place(o.origin)}: \{o.rendered}, tier \{o.tier}")
  .join(" | ")
}

///|
/// An origin as its constructor, its argument and its keys.
fn place(origin : @doc.Origin) -> String {
  let arg = match origin.param {
    Some(param) => "a\{param}"
    None => "call"
  }
  let keys = if origin.keys.is_empty() {
    ""
  } else {
    " " + origin.keys.join("/")
  }
  "\{origin.kind} \{arg}\{keys}"
}

///|
test "composite: an argument resolves to its own range, not to the one with the constructor's index" {
  // The case of the third review of the proposal. `Grid` has `gutter` as
  // its parameter 3, which is `fill` here: with the constructor's own
  // indices an error in the gutter is reported at the fill. (This test was
  // written first and failed so, with `Tiles a3`, on a hook that put the
  // composite's call in the place of the constructors' own.)
  let line = line_here() + 2
  let report = compile([
    tiles(["a", "b"], 2, gutter=[Rel(None)], fill=Rgb("#eee")),
  ])
  inspect(
    error_messages(report),
    content="expected auto, relative length, or fraction, found none",
  )
  let origin = origin_of(report.errors[0])
  inspect(place(origin), content="Tiles a2")
  assert_eq(origin.start_line, line)
  // The location is the range of the gutter argument: `[Rel(None)]`.
  assert_eq(origin.end_column - origin.start_column, "[Rel(None)]".length())
  // An error in the fill is at the fill, which is `Grid`'s parameter 8 (an
  // index that this call does not have).
  let fill = compile([
    tiles(["a", "b"], 2, gutter=[Pt(2)], fill=Value(@doc.Value::str("x"))),
  ])
  inspect(
    error_messages(fill),
    content="expected color, gradient, tiling, none, array, or function, found string",
  )
  inspect(place(origin_of(fill.errors[0])), content="Tiles a3")
  // Text: the body is the second argument here and the first of `Block`.
  // What the element generates is the call.
  let text = compile([titled("Title", "body text")])
  inspect(
    text_args(text),
    content="Title: Titled a0 | !: Titled call | body text: Titled a1",
  )
  // The strings of an array argument are pieces of it, as in `Grid`.
  inspect(
    text_args(compile([tiles(["one", "two"], 2)])),
    content="one: Tiles a0 | two: Tiles a0",
  )
}

///|
test "composite: one site, and what it lowers to" {
  let report = compile([titled("Title", "body text")])
  inspect(error_messages(report), content="")
  // One origin for the whole element: the constructors inside it have no
  // lines of their own in the listing.
  let listing = report.origins.listing()
  assert_eq(listing.split("\n").filter(line => line != "").count(), 2)
  assert_true(listing.contains(" Document "))
  assert_true(listing.contains(" Titled a0="))
  assert_true(!listing.contains("Block"))
  // The content is the expansion.
  assert_eq(
    lowered([titled("Title", "body text")]),
    lowered([
      @doc.Seq([
        @doc.Strong("Title"),
        @doc.Text("!", size=Pt(6)),
        @doc.Block("body text", inset=@doc.Sides(all=Pt(2))),
      ]),
    ]),
  )
  // It prints as its name around what it is made of.
  debug_inspect(
    panel("x", Red),
    content=(
      #|Panel(Block("x", width=60pt, height=30pt, fill=red))
    ),
  )
  // It is a description: it can be interpolated into prose.
  assert_eq(
    lowered([@doc.Prose("see \{panel("x", Red)}")]),
    lowered([
      @doc.Prose(
        "see \{@doc.Block("x", fill=Red, width=Pt(60), height=Pt(30))}",
      ),
    ]),
  )
}

///|
test "composite: the caller's descriptions keep their origins" {
  // A description that the caller built is at its own call, with or
  // without a mark; so are the words of a `Prose`.
  let report = compile([
    titled("Title", @doc.Emph("stressed")),
    titled("Other", @doc.Prose("two words")),
    tiles([@doc.Lit("located"), "plain"], 2),
  ])
  inspect(
    text_args(report),
    content=(
      #|Title: Titled a0 | !: Titled call | stressed: Emph a0 | Other: Titled a0 | two words: Prose a0 | two words: - | located: Lit call | plain: Tiles a0
    ),
  )
  // What the `into_content` of a type of the caller builds is the
  // caller's: the `Emph` of `Badge`, not the element.
  inspect(
    text_args(compile([titled("Title", Badge::{ text: "badge", })])),
    content="Title: Titled a0 | !: Titled call | badge: Emph a0",
  )
}

///|
test "composite: a click, a selection and a source line" {
  let line = line_here() + 2
  let report = compile_on_page([
    panel("in the panel", Luma(230)),
    titled("Title", "body text"),
  ])
  inspect(error_messages(report), content="")
  // A click on the fill, which the element generated: its call.
  guard report.origin_at(1, 65.0, 35.0) is Some(fill) else {
    fail("no origin at the fill")
  }
  inspect(place(fill), content="Panel call")
  assert_eq(fill.start_line, line)
  // A click on the text: the argument.
  guard report.origin_at(1, 14.0, 16.0) is Some(word) else {
    fail("no origin at the text")
  }
  inspect(place(word), content="Panel a0")
  // A selection: the caller's argument, as a whole while the source file
  // is not read.
  let text = report.review_text(title="Test")
  inspect(
    text.text(),
    content=(
      #|in the panel Title! body text
    ),
  )
  let record = text.feedback(text.find("body").unwrap(), "")
  inspect(
    tiers(record),
    content=(
      #|Titled a1: body, tier 2
    ),
  )
  // A word that is made of an argument and of generated text.
  inspect(
    tiers(text.feedback(text.find("Title!").unwrap(), "")),
    content="Titled a0: Title, tier 2 | Titled call: !, tier 1",
  )
  // With the source: the characters of the caller's own literal.
  let origin = record.origins[0].origin
  assert_eq(origin.start_line, line + 1)
  let source_line = " ".repeat(origin.start_column - 1) + "\"body text\"),"
  let file = "\n".repeat(origin.start_line - 1) + source_line + "\n"
  let with_source = report.review_text(sources=(name, _) => {
    if name == "doc/composite_test.mbt" {
      Some(file)
    } else {
      None
    }
  })
  let entry = with_source.feedback(with_source.find("text").unwrap(), "").origins[0]
  assert_eq(entry.tier, 3)
  assert_eq(entry.source_ranges.length(), 1)
  assert_eq(entry.source_ranges[0].line, origin.start_line)
  assert_eq(entry.source_ranges[0].start, origin.start_column + 6)
  assert_eq(entry.source_ranges[0].text, "text")
  // From the source to the page. The column of a call: what the element
  // generated there, the panel's rectangle.
  let file = "doc/composite_test.mbt"
  inspect(
    text
    .positions(file, line, column=fill.start_column)
    .map(region_text)
    .join(" | "),
    content="1: 10 10 60 30",
  )
  // A line gives the narrowest locations on it, the arguments: the three
  // words of the panel (and the two gaps between them);
  assert_eq(text.positions(file, line).length(), 5)
  // for the other call a box for the title, and two words and a gap for
  // the body. The column of the second argument gives that one.
  assert_eq(text.positions(file, line + 1).length(), 4)
  assert_eq(
    text
    .positions(file, line + 1, column=origin.start_column + 1)
    .map(region_text),
    text.origin_positions(origin).map(region_text),
  )
  assert_eq(text.origin_positions(origin).length(), 3)
}

///|
test "composite: keys, of the caller and of the element" {
  // An element under the keys of the caller: one origin per key.
  let keyed : Array[&@doc.IntoContent] = []
  for key in ["x", "y"] {
    keyed.push(@doc.Keyed(key, titled("Title", "body of \{key}")))
  }
  inspect(
    text_args(compile(keyed)),
    content="Title: Titled a0 x | !: Titled call x | body of x: Titled a1 x | Title: Titled a0 y | !: Titled call y | body of y: Titled a1 y",
  )
  // An element that keys its parts: the strings of its array are its
  // first argument under the key of their part, and a description of the
  // caller is under that key too.
  let report = compile([rows(["same", "same", @doc.Emph("own")])])
  inspect(error_messages(report), content="")
  inspect(
    text_args(report),
    content="same: Rows a0 0 | same: Rows a0 1 | own: Emph a0 2",
  )
  // Both together.
  inspect(
    text_args(compile([@doc.Keyed("outer", rows(["a", "b"]))])),
    content="a: Rows a0 outer/0 | b: Rows a0 outer/1",
  )
}

///|
test "composite: one description used twice is two occurrences of one origin" {
  let twice = titled("Title", "body text")
  let report = compile_on_page([twice, twice])
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(
    text_args(report),
    content="Title: Titled a0 | !: Titled call | body text: Titled a1",
  )
  let text = report.review_text(title="Test")
  inspect(
    text.text(),
    content=(
      #|Title! body text Title! body text
    ),
  )
  let body = text.feedback(text.find("body").unwrap(), "").origins[0].origin
  // Both places are boxes of the one origin (two words and a gap each).
  assert_eq(text.origin_positions(body).length(), 6)
  // An element that measures, used twice: one callback, two places.
  let fitted = fit("fits")
  let report = compile_on_page([fitted, fitted])
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(text_args(report), content="fits: Fit a0")
  let text = report.review_text(title="Test")
  let word = text.feedback(text.find("fits").unwrap(), "").origins[0].origin
  assert_eq(text.origin_positions(word).length(), 2)
}

///|
test "composite: a composite inside a composite is the outer one's" {
  let report = compile([framed("Caption", "body text")])
  inspect(error_messages(report), content="")
  // The arguments of the inner element are the outer arguments that they
  // were marked as. The outer call as a whole: what the inner element
  // generates, what the outer one passes it of its own, and an argument
  // that the outer element marks and the inner one does not (its `mark`,
  // which is the caption in the second use).
  inspect(
    text_args(report),
    content="Caption: Framed a0 | *: Framed call | body text: Framed a1 | fixed: Framed call | Caption: Framed call | generated: Framed call",
  )
  // One origin: the inner element has no line in the listing.
  assert_true(!report.origins.listing().contains("Titled"))
  // An error in an argument of the outer element that the inner one
  // passes on.
  let failing = compile([framed("Caption", @doc.Value::call("no-such"))])
  inspect(
    error_messages(failing),
    content=(
      #|unknown variable `no-such`
    ),
  )
  inspect(place(origin_of(failing.errors[0])), content="Framed a1")
}

///|
test "composite: content that is made in a callback of the element" {
  // The callback was created when the element was: before the document
  // is compiled. What it returns is built by constructors of the element.
  let line = line_here() + 1
  let report = compile_on_page([fit("fits"), @doc.Keyed("k", fit("keyed"))])
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(text_args(report), content="fits: Fit a0 | keyed: Fit a0 k")
  // The block is 4pt wider than its text, and its fill is the call.
  let block = of_kind(marks(report), "rect")[0]
  let word = of_kind(marks(report), "text")[0]
  inspect(pt(block.w - word.w), content="4.0")
  guard report.origin_at(1, block.x + block.w - 1.0, block.y + 1.0)
    is Some(fill) else {
    fail("no origin at the fill")
  }
  inspect(place(fill), content="Fit call")
  assert_eq(fill.start_line, line)
  // The origins of the callback's content are the element's: the
  // listing has the call (also under the key), and no line of this file
  // where the element is defined (`cx.measure` records its call too).
  let lines = report.origins
    .listing()
    .split("\n")
    .filter(entry => entry.contains("doc/composite_test.mbt:\{line}:"))
    .map(entry => entry.to_owned())
    .collect()
  assert_eq(lines.length(), 2)
  for entry in lines {
    assert_true(entry.contains(" Fit "))
  }
  // (The page and the document are the other two.)
  assert_eq(report.origins.length(), 4)
  // What the callback builds from an argument is that argument.
  inspect(
    text_args(
      compile_on_page([
        responsive("narrow", "wide"),
        @doc.Block(responsive("narrow", "wide"), width=Pt(50)),
      ]),
    ),
    content="wide: Responsive a1 | narrow: Responsive a0",
  )
  // A callback of the caller that the engine calls while the element's
  // callback is running (it measures the body) runs as the caller's: what
  // it builds has its own call sites, and its errors are there.
  inspect(
    text_args(compile([fit(@doc.Context(_ => @doc.Emph("inner")))])),
    content="inner: Emph a0",
  )
  let inner = compile([
    fit(@doc.Context(_ => @doc.Block("x", inset=@doc.Sides::none()))),
  ])
  inspect(place(origin_of(inner.errors[0])), content="Block a7")
  // An error that the callback raises is at the call.
  let failing = compile([fit("x", fail_with="boom")])
  assert_true(failing.errors[0].message.contains("boom"))
  inspect(place(origin_of(failing.errors[0])), content="Fit call")
  // An element that creates a callback cannot be built inside a callback:
  // the error of `Layout`, at the call of the element.
  let line = line_here() + 1
  let inside = compile([@doc.Context(_ => fit("too late"))])
  inspect(
    error_messages(inside),
    content="callbacks cannot be created inside a callback",
  )
  inspect(place(origin_of(inside.errors[0])), content="Fit call")
  assert_eq(origin_of(inside.errors[0]).start_line, line)
  inspect(
    inside.errors[0].hints.map(h => h.message).join(" | "),
    content="create the callback before compiling and capture it | or use the `cx` of the enclosing callback",
  )
  // Built before and captured, it can be used in one.
  let early = fit("in time")
  let captured = compile([@doc.Context(_ => early)])
  inspect(error_messages(captured), content="")
  inspect(text_args(captured), content="in time: Fit a0")
  // An element without a callback can be built anywhere.
  let in_show = compile([
    @doc.Show(@doc.Select::heading()) <| ((it, _) => titled("Shown", it)),
    @doc.Heading("Head"),
  ])
  inspect(error_messages(in_show), content="")
  inspect(
    text_args(in_show),
    content="Shown: Titled a0 | !: Titled call | Head: Heading a0",
  )
}

///|
test "composite: where a mark counts" {
  let args = (mode : String, a : String, b : String) => {
    text_args(compile([marked(mode, a, b)]))
  }
  // Marked where the value is passed to the constructor.
  inspect(args("inside", "a", "b"), content="a: Marked a1 k")
  inspect(
    args("same", "a", "b"),
    content=(
      #|ab: Marked a1
    ),
  )
  inspect(args("branch", "a", "b"), content="a: Marked a1")
  inspect(args("branch", "", "b"), content="b: Marked a2")
  inspect(args("sequence", "a", "b"), content="a: Marked a1")
  // Not marked there: the call, never another argument.
  inspect(args("result", "a", "b"), content="a: Marked call")
  inspect(args("stale", "a", "b"), content="b: Marked call")
  inspect(args("bound", "a", "b"), content="a: Marked call")
  inspect(
    args("mixed", "a", "b"),
    content=(
      #|ab: Marked call
    ),
  )
  inspect(args("none", "a", "b"), content="a: Marked call")
  // An argument that the caller did not write has no location.
  inspect(text_args(compile([greeting()])), content="world: Greeting call")
  inspect(
    text_args(compile([greeting(name="you")])),
    content="you: Greeting a0",
  )
  // An argument that the element cannot accept: an error at the argument,
  // or at the call.
  let line = line_here() + 1
  let invalid = compile([greeting(name="")])
  inspect(error_messages(invalid), content="`Greeting` needs a name")
  inspect(place(origin_of(invalid.errors[0])), content="Greeting a0")
  assert_eq(origin_of(invalid.errors[0]).start_line, line)
  let nobody = compile([greeting(name="nobody")])
  inspect(error_messages(nobody), content="`Greeting` greets somebody")
  inspect(place(origin_of(nobody.errors[0])), content="Greeting call")
}

///|
/// A composite that is a rule, one that is a value, and one that is made
/// of the second.
#callsite(autofill(loc, args_loc))
fn small(loc~ : SourceLoc, args_loc~ : ArgsLoc) -> @doc.Composite {
  @doc.Composite("Small", loc, args_loc, _ => @doc.SetText(size=Pt(6)))
}

///|
#callsite(autofill(loc, args_loc))
fn nothing(loc~ : SourceLoc, args_loc~ : ArgsLoc) -> @doc.Composite {
  @doc.Composite("Nothing", loc, args_loc, _ => @doc.Value::none())
}

///|
#callsite(autofill(loc, args_loc))
fn nothing_at_all(loc~ : SourceLoc, args_loc~ : ArgsLoc) -> @doc.Composite {
  @doc.Composite("NothingAtAll", loc, args_loc, _ => nothing())
}

///|
test "composite: an element is what it is made of, also a rule or a value" {
  // A rule styles what follows it in the sequence.
  assert_eq(
    lowered([small(), "text"]),
    lowered([@doc.SetText(size=Pt(6)), "text"]),
  )
  // Elsewhere it is the error of a rule, at the call of the element.
  let misplaced = compile([@doc.Par(small())])
  inspect(
    error_messages(misplaced),
    content="rules are only allowed directly in `Document` and `Seq`",
  )
  inspect(place(origin_of(misplaced.errors[0])), content="Small call")
  // A value is passed as the value where content is expected: `none` is
  // no caption, not an empty one. Also through a second element.
  let expected = lowered([@doc.Figure("x", caption=@doc.NoneValue())])
  assert_true(expected != lowered([@doc.Figure("x", caption=@doc.Seq([]))]))
  assert_eq(lowered([@doc.Figure("x", caption=nothing())]), expected)
  assert_eq(lowered([@doc.Figure("x", caption=nothing_at_all())]), expected)
}

///|
test "composite: the lint of adjacent text reads an element as what it is made of" {
  // An element that is a block makes the array a flow, like the grid it
  // is made of.
  let flow = compile([tiles(["x"], 1), "one", "two"])
  inspect(
    lint_lines(flow),
    content="adjacent-inline (Document, argument 1) after (Document, argument 1): \"onetwo\"",
  )
  assert_eq(
    lint_lines(flow),
    lint_lines(compile([@doc.Grid(["x"]), "one", "two"])),
  )
  // An element that is a `Prose` is text, at its own text argument.
  inspect(
    lint_lines(compile([plain("One ends."), plain("Two starts.")])),
    content="adjacent-inline (Plain, argument 1) after (Plain, argument 1): \"One ends.Two starts.\"",
  )
}

///|
/// A cell over two columns, as an element.
#callsite(autofill(loc, args_loc))
fn wide(body : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> @doc.Composite {
  @doc.Composite("Wide", loc, args_loc, site => {
    @doc.TableCell(site.arg(0, body), colspan=2)
  })
}

///|
test "table_cell_spans: what a description takes as a cell of a table" {
  let spans = (cell : &@doc.IntoContent) => {
    match @doc.Content(cell).table_cell_spans() {
      Some((colspan, rowspan)) => "\{colspan}x\{rowspan}"
      None => "-"
    }
  }
  // What a table makes a cell of is one column and one row.
  inspect(spans("text"), content="1x1")
  inspect(spans(@doc.Emph("stressed")), content="1x1")
  inspect(
    spans(@doc.Seq([@doc.TableCell("in a sequence", colspan=2)])),
    content="1x1",
  )
  inspect(spans(@doc.GridCell("of a grid", colspan=2)), content="1x1")
  // A cell as it is described: the spans that it names, also with a key,
  // with a label, as a call by name, as a value, and as what an element is
  // made of.
  inspect(spans(@doc.TableCell("a")), content="1x1")
  inspect(spans(@doc.TableCell("a", colspan=3)), content="3x1")
  inspect(spans(@doc.TableCell("a", colspan=2, rowspan=4)), content="2x4")
  inspect(
    spans(@doc.Keyed("k", @doc.TableCell("a", rowspan=2, label="cell"))),
    content="1x2",
  )
  inspect(
    spans(@doc.Labelled(@doc.TableCell("a", colspan=2), "cell")),
    content="2x1",
  )
  let named = [("colspan", @doc.Value::int(2))]
  inspect(spans(@doc.Call("table.cell", named~)), content="2x1")
  inspect(spans(@doc.Value::call("table.cell", named~)), content="2x1")
  inspect(spans(wide("a")), content="2x1")
  // The last argument of a name wins, as in Typst.
  inspect(
    spans(
      @doc.TableCell("a", colspan=2, extra=[("colspan", @doc.Value::int(3))]),
    ),
    content="3x1",
  )
  // Not placed after the child before it: a cell with a position, a line,
  // a header, a footer.
  inspect(spans(@doc.TableCell("a", x=1)), content="-")
  inspect(spans(@doc.TableCell("a", y=0, colspan=2)), content="-")
  inspect(spans(@doc.TableHline()), content="-")
  inspect(spans(@doc.TableVline()), content="-")
  inspect(spans(@doc.TableHeader(["a"])), content="-")
  inspect(spans(@doc.TableFooter(["a"])), content="-")
  inspect(spans(@doc.Call("table.hline")), content="-")
  // (An explicit `auto` is no position.)
  inspect(
    spans(@doc.TableCell("a", extra=[("x", @doc.Value::auto())])),
    content="1x1",
  )
  // What only the engine sees is not read: a cell that a callback makes,
  // a span that is computed.
  inspect(
    spans(@doc.Context(_ => @doc.TableCell("a", colspan=2))),
    content="1x1",
  )
  inspect(
    spans(
      @doc.TableCell("a", extra=[
        ("colspan", @doc.Value::int(1).add(@doc.Value::int(1))),
      ]),
    ),
    content="1x1",
  )
}
