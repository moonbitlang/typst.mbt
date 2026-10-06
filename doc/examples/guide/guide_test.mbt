// What docs/edsl-guide.md says about its samples (`guide.mbt`), checked on
// the laid-out pages. The page of each test is 200pt by 120pt with 10pt
// margins and 10pt text, so the region is 180pt by 100pt; lengths are in
// points from the page's top left corner.

///|
/// Something on a page: a rectangle (`"rect"`), a line (`"line"`: `w` and
/// `h` are its end relative to its start) or a text run (`"text"`: `y` is
/// its baseline, `w` its advance width, `h` its font size).
priv struct Mark {
  page : Int
  kind : String
  x : Double
  y : Double
  w : Double
  h : Double
  /// The text of a run and the family of its font.
  text : String
  family : String
  /// The fill of a shape (`""`: none) and the dash pattern of its stroke
  /// (`""`: solid, or no stroke).
  fill : String
  dash : String
  /// The span of the first glyph of a run.
  span : @syntax.Span
}

///|
/// The marks of a frame at `(dx, dy)` on the page `page`. (No sample has a
/// scaled or rotated group: a group is a translation.)
fn collect_marks(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  page : Int,
  out : Array[Mark],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    match entry.1 {
      Group(group) =>
        collect_marks(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          page,
          out,
        )
      Text(text) =>
        out.push({
          page,
          kind: "text",
          x,
          y,
          w: text.width().to_pt(),
          h: text.size.to_pt(),
          text: text.text,
          family: text.font.font().family(),
          fill: "",
          dash: "",
          span: text.glyphs[0].span,
        })
      Shape(shape, span) => {
        let (kind, w, h) = match shape.geometry {
          Rect(size) => ("rect", size.x.to_pt(), size.y.to_pt())
          Line(to) => ("line", to.x.to_pt(), to.y.to_pt())
          Curve(_) => continue
        }
        let fill = match shape.fill {
          Some(paint) => paint.repr()
          None => ""
        }
        let dash = match shape.stroke {
          Some({ dash: Some(pattern), .. }) =>
            pattern.array.map(length => pt(length.to_pt())).join(" ")
          _ => ""
        }
        out.push({
          page,
          kind,
          x,
          y,
          w,
          h,
          text: "",
          family: "",
          fill,
          dash,
          span,
        })
      }
      _ => ()
    }
  }
}

///|
/// A length in points with one decimal.
fn pt(x : Double) -> String {
  let tenths = (x * 10.0).round().to_int()
  let sign = if tenths < 0 { "-" } else { "" }
  let tenths = tenths.abs()
  "\{sign}\{tenths / 10}.\{tenths % 10}"
}

///|
/// A compiled document and its marks.
priv struct Pages {
  report : @doc.CompileReport[@layout.PagedDocument]
  marks : Array[Mark]
}

///|
/// Compile `children` on the small page, with the embedded fonts or in
/// `world`.
fn pages(
  children : Array[&@doc.IntoContent],
  world? : @doc.DocWorld = @doc.DocWorld::in_memory(),
) -> Pages {
  let all : Array[&@doc.IntoContent] = [
    @doc.SetPage(width=Pt(200), height=Pt(120), margin=@doc.Sides(all=Pt(10))),
    @doc.SetText(size=Pt(10)),
  ]
  all.append(children)
  let report = @doc.Document(all).compile_paged(world)
  let marks = []
  if report.output() is Some(document) {
    for i, page in document.pages() {
      collect_marks(page.frame, 0.0, 0.0, i + 1, marks)
    }
  }
  { report, marks, }
}

///|
/// The messages of the errors and of the warnings.
fn Pages::errors(self : Pages) -> String {
  self.report.errors.map(e => e.message).join(" | ")
}

///|
fn Pages::warnings(self : Pages) -> String {
  self.report.warnings.map(w => w.message).join(" | ")
}

///|
/// The marks of one kind.
fn Pages::of_kind(self : Pages, kind : String) -> Array[Mark] {
  self.marks.filter(m => m.kind == kind)
}

///|
/// One line per mark: the page, the kind, the position, then the size (and
/// fill, and dash pattern) of a shape, or the advance width and the text
/// of a run.
fn Pages::listing(self : Pages) -> String {
  self.marks
  .map(m => {
    if m.kind == "text" {
      "p\{m.page} text \{pt(m.x)},\{pt(m.y)} w\{pt(m.w)} \{m.text.escape()}"
    } else {
      let fill = if m.fill == "" { "" } else { " \{m.fill}" }
      let dash = if m.dash == "" { "" } else { " dash \{m.dash}" }
      "p\{m.page} \{m.kind} \{pt(m.x)},\{pt(m.y)} \{pt(m.w)}x\{pt(m.h)}\{fill}\{dash}"
    }
  })
  .join("\n")
}

///|
/// The origin of the text run that contains `text`.
fn Pages::origin(self : Pages, text : String) -> @doc.Origin raise {
  for mark in self.marks {
    if mark.kind == "text" && mark.text.contains(text) {
      guard self.report.origins.resolve(mark.span) is Some(origin) else {
        fail("no origin for \{text}")
      }
      return origin
    }
  }
  fail("no text \{text}")
}

///|
/// `text` with every run of digits as `N`.
fn numberless(text : String) -> String {
  let out = StringBuilder()
  let mut in_number = false
  for c in text {
    if c >= '0' && c <= '9' {
      if !in_number {
        out.write_char('N')
      }
      in_number = true
    } else {
      out.write_char(c)
      in_number = false
    }
  }
  out.to_string()
}

///|
/// An origin without its line and column: `file (Constructor, argument n)`.
fn place(origin : @doc.Origin) -> String {
  let name = origin.file.split("/").collect().last().unwrap().to_owned()
  name + origin.describe().replace(old=origin.position(), new="")
}

///|
test "the samples compile to PDF without warnings" {
  let world = @doc.DocWorld::in_memory()
  for document in [@guide.first_document(), @guide.guide()] {
    let compiled = document.compile_paged(world)
    for diagnostic in compiled.errors {
      println(diagnostic.render())
    }
    assert_true(compiled.errors.is_empty())
    for diagnostic in compiled.warnings {
      println(diagnostic.render())
    }
    assert_true(compiled.warnings.is_empty())
    assert_true(compiled.pdf().unwrap().length() > 1000)
  }
}

///|
test "section 2: inline items in a sequence are one paragraph, `Para` separates them" {
  let joined = pages([@guide.run_together()])
  inspect(joined.errors(), content="")
  inspect(joined.warnings(), content="")
  inspect(
    joined.listing(),
    content=(
      #|p1 text 10.0,16.6 w172.0 "The first ends here.The second starts here."
    ),
  )
  // The lint (line and column numbers as N).
  inspect(
    numberless(
      @guide.lints_of(@doc.Document([@guide.run_together()])).join("\n"),
    ),
    content=(
      #|lint[adjacent-inline]: this text and the text before it are typeset as one paragraph with nothing between them: "…first ends here.The second start…"
      #|  at doc/examples/guide/guide.mbt:N:N (Prose, argument N)
      #|  hint: the text before it (doc/examples/guide/guide.mbt:N:N (Prose, argument N))
      #|  hint: a paragraph of text is `Para(..)`; pieces of one paragraph go in one `Par(Seq([..]))`
    ),
  )
  // It is a field of the report, and `lints=false` turns the lints off.
  let document = @doc.Document([@guide.run_together()])
  let world = @doc.DocWorld::in_memory()
  assert_eq(document.compile_paged(world).lints.length(), 1)
  assert_eq(document.compile_paged(world, lints=false).lints.length(), 0)
  // Other text than two `Prose` (a string, a `Text` around one) is
  // reported next to text if the array also holds a block, here a
  // heading; without one the array may be the body of one paragraph.
  let strings : Array[&@doc.IntoContent] = [
    "The first ends here.",
    @doc.Text("The second starts here."),
  ]
  assert_eq(@guide.lints_of(@doc.Document(strings)), [])
  assert_eq(
    @guide.lints_of(@doc.Document([@doc.Heading("Notes"), ..strings])).length(),
    1,
  )
  // A paragraph each.
  let apart = pages([@guide.paragraphs()])
  inspect(apart.errors(), content="")
  inspect(apart.warnings(), content="")
  inspect(
    apart.listing(),
    content=(
      #|p1 text 10.0,19.0 w35.9 "Notes"
      #|p1 text 10.0,33.1 w78.6 "The first ends here."
      #|p1 text 10.0,51.7 w160.2 "The second starts here, with a “quoted” "
      #|p1 text 10.0,64.8 w41.2 "word and "
      #|p1 text 51.2,64.8 w30.1 "stressed"
      #|p1 text 81.3,64.8 w97.1 " ones on its second line."
      #|p1 text 10.0,83.4 w85.1 "The third is justified."
    ),
  )
  assert_eq(@guide.lints_of(@doc.Document([@guide.paragraphs()])), [])
  // The document of all samples has the one lint of `run_together`.
  assert_eq(@guide.lints_of(@guide.guide()).length(), 1)
  // A blank line in the text of a `Para` is a paragraph break.
  let blank = pages([@doc.Para("One ends here.\n\nTwo starts here.")])
  inspect(blank.warnings(), content="")
  inspect(
    blank.listing(),
    content=(
      #|p1 text 10.0,16.6 w60.8 "One ends here."
      #|p1 text 10.0,35.2 w65.4 "Two starts here."
    ),
  )
  // A displayed formula in a `Para` is kept; the text after it is not
  // indented, the next `Para` is.
  let display = pages([@guide.with_display()])
  inspect(display.errors(), content="")
  inspect(display.warnings(), content="")
  inspect(
    display.listing(),
    content=(
      #|p1 text 25.0,16.6 w127.8 "The sum of the first numbers is"
      #|p1 text 63.1,43.2 w14.4 "∑"
      #|p1 text 67.8,31.7 w4.9 "𝑛"
      #|p1 text 63.5,54.3 w4.2 "𝑘"
      #|p1 text 67.7,54.3 w5.4 "="
      #|p1 text 73.2,54.3 w4.0 "1"
      #|p1 text 79.2,43.2 w5.4 "𝑘"
      #|p1 text 87.3,43.2 w7.8 "="
      #|p1 text 98.9,36.5 w6.0 "𝑛"
      #|p1 text 104.9,36.5 w3.9 "("
      #|p1 text 108.8,36.5 w6.0 "𝑛"
      #|p1 text 117.0,36.5 w7.8 "+"
      #|p1 text 127.0,36.5 w5.0 "1"
      #|p1 text 132.0,36.5 w3.9 ")"
      #|p1 text 114.9,50.1 w5.0 "2"
      #|p1 line 98.9,40.7 37.0x0.0
      #|p1 text 10.0,72.9 w127.8 "which the next paragraph uses."
      #|p1 text 25.0,91.5 w73.4 "A new paragraph."
    ),
  )
  // The `par` element cannot hold it: `Par(..)` is for inline content.
  let dropped = pages([
    @doc.Par(@doc.Prose("Before \{@doc.Equation("x", block=true)} after.")),
  ])
  inspect(
    dropped.warnings(),
    content="block may not occur inside of a paragraph and was ignored",
  )
  inspect(
    dropped.listing(),
    content=(
      #|p1 text 10.0,16.6 w29.1 "Before "
      #|p1 text 39.1,16.6 w22.8 " after."
    ),
  )
  // A block between two inline items separates them.
  let apart = pages([@doc.Seq(["One.", @doc.Block("Between."), "Two."])])
  inspect(
    apart.listing(),
    content=(
      #|p1 text 10.0,16.6 w19.0 "One."
      #|p1 text 10.0,35.2 w37.5 "Between."
      #|p1 text 10.0,53.7 w20.0 "Two."
    ),
  )
}

///|
/// Only the call's location is forwarded.
#callsite(autofill(loc))
fn call_only_note(body : &@doc.IntoContent, loc~ : SourceLoc) -> @doc.Block {
  @doc.Block(body, inset=@doc.Sides(all=Pt(6)), loc~)
}

///|
/// The body is wrapped in constructors of the helper.
#callsite(autofill(loc, args_loc))
fn titled_note(
  title : String,
  body : &@doc.IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Block {
  @doc.Block(@doc.Seq([@doc.Strong(title), " ", body]), loc~, args_loc~)
}

///|
/// The location is forwarded to more than one constructor.
#callsite(autofill(loc, args_loc))
fn shared_note(
  title : String,
  body : &@doc.IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Block {
  @doc.Block(
    @doc.Seq([@doc.Strong(title, loc~, args_loc~), " ", body], loc~, args_loc~),
    loc~,
    args_loc~,
  )
}

///|
/// The body is the second parameter of the helper and the first of the
/// constructor.
#callsite(autofill(loc, args_loc))
fn labelled_note(
  label : String,
  body : &@doc.IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Block {
  @doc.Block(body, label~, loc~, args_loc~)
}

///|
/// An argument that the helper supplies is wrong.
#callsite(autofill(loc, args_loc))
fn broken_note(
  body : &@doc.IntoContent,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> @doc.Block {
  @doc.Block(body, inset=@doc.Sides::none(), loc~, args_loc~)
}

///|
test "section 3: a helper with `#callsite` gives its element the caller's location" {
  let notes = pages([@guide.notes()])
  inspect(notes.errors(), content="")
  let before = notes.origin("before")
  let after = notes.origin("after")
  let plain = notes.origin("in the helper")
  let kept = notes.origin("at the call")
  // Both are the body argument of a `Block` in guide.mbt ...
  inspect(
    place(plain),
    content=(
      #|guide.mbt (Block, argument 1)
    ),
  )
  inspect(
    place(kept),
    content=(
      #|guide.mbt (Block, argument 1)
    ),
  )
  // ... the one of `note` on its line in `notes`, between the two texts,
  // the one of `plain_note` on a line of the helper, which is above.
  assert_true(before.start_line < kept.start_line)
  assert_true(kept.start_line < after.start_line)
  assert_true(plain.start_line < before.start_line)
  // It is the argument of the call, which starts to the right of the
  // call.
  assert_true(kept.start_column > before.start_column)
}

///|
test "section 3: what the location of a helper covers" {
  let here = @guide.note("marker")
  let marker = pages([here]).origin("marker")
  let this_file = "guide_test.mbt"
  assert_true(marker.file.has_suffix(this_file))
  // Argument locations are read by position: the body, the first
  // parameter of `Block`, gets the location of the helper's first
  // argument, the three characters `"L"`.
  let labelled = pages([labelled_note("L", "labelled body")])
  let origin = labelled.origin("labelled body")
  inspect(
    place(origin),
    content=(
      #|guide_test.mbt (Block, argument 1)
    ),
  )
  assert_true(origin.start_line > marker.start_line)
  assert_eq(origin.end_column - origin.start_column, 3)
  // Only `loc`: the call is the caller's, the arguments are the helper's.
  let call_only = pages([call_only_note("call only")])
  let origin = call_only.origin("call only")
  inspect(
    place(origin),
    content=(
      #|guide_test.mbt (Block, argument 1)
    ),
  )
  assert_true(origin.start_line < marker.start_line)
  // Constructors that the helper wraps around its parameters are on the
  // helper's lines; the block itself is the caller's.
  let titled = pages([titled_note("Title", "wrapped")])
  inspect(
    place(titled.origin("Title")),
    content=(
      #|guide_test.mbt (Strong, argument 1)
    ),
  )
  inspect(
    place(titled.origin("wrapped")),
    content=(
      #|guide_test.mbt (Seq, argument 1)
    ),
  )
  assert_true(titled.origin("wrapped").start_line < marker.start_line)
  // A location that is forwarded to several constructors is one origin,
  // named after the one that is lowered first: the texts of the others
  // are reported as its arguments.
  let shared = pages([shared_note("Title", "shared")])
  inspect(
    place(shared.origin("Title")),
    content=(
      #|guide_test.mbt (Block, argument 1)
    ),
  )
  inspect(
    place(shared.origin("shared")),
    content=(
      #|guide_test.mbt (Block, argument 1)
    ),
  )
  // Document, SetPage, SetText and one origin for the three constructors.
  assert_eq(shared.report.origins.length(), 4)
  // An error at an argument that the helper supplies is reported at the
  // call of the helper.
  let broken = pages([broken_note("x")])
  inspect(
    broken.errors(),
    content=(
      #|expected relative length or dictionary, found none
    ),
  )
  guard broken.report.errors[0].location is Some(Edsl(origin)) else {
    fail("expected an EDSL location")
  }
  inspect(
    place(origin),
    content=(
      #|guide_test.mbt (Block)
    ),
  )
  assert_true(origin.start_line > marker.start_line)
}

///|
test "section 4: conversions, `Call`, `NoneValue()`, typed and untyped fields, `Layout`" {
  // 4.1: the first column is 50% of 180pt less 10pt, and the block is 11pt
  // and half of the font size (10pt) below the grid.
  let lengths = pages([@guide.composed_lengths()])
  inspect(lengths.errors(), content="")
  inspect(
    lengths.listing(),
    content=(
      #|p1 rect 10.0,10.0 80.0x5.0 luma(78.43%)
      #|p1 rect 90.0,10.0 100.0x5.0 luma(78.43%)
      #|p1 rect 10.0,31.0 180.0x5.0 luma(78.43%)
    ),
  )
  // 4.2: a function without a constructor, by its name.
  let roman = pages([@guide.roman_numeral()])
  inspect(roman.errors(), content="")
  inspect(
    roman.listing(),
    content=(
      #|p1 text 10.0,16.6 w11.0 "IV."
    ),
  )
  // `Upper` on content keeps its structure (the emphasis).
  let upper = pages([@guide.upper_case()])
  inspect(upper.errors(), content="")
  inspect(
    upper.listing(),
    content=(
      #|p1 text 10.0,16.6 w30.6 "QUIET "
      #|p1 text 40.6,16.6 w32.2 "WORDS"
    ),
  )
  // 4.3: the outline has its title unless it is `none`.
  inspect(
    pages([@doc.Outline()]).listing(),
    content=(
      #|p1 text 10.0,19.0 w57.7 "Contents"
    ),
  )
  let untitled = pages([@guide.untitled_outline()])
  inspect(untitled.errors(), content="")
  inspect(untitled.listing(), content="")
  // 4.4: the highlight from the x-height to the baseline, the box 2pt
  // below the baseline, a dotted line, a half transparent fill.
  let typed = pages([@guide.typed_fields()])
  inspect(typed.errors(), content="")
  inspect(typed.warnings(), content="")
  inspect(
    typed.listing(),
    content=(
      #|p1 rect 10.0,12.3 19.4x4.3 rgb("#fffd11a1")
      #|p1 text 10.0,16.6 w19.4 "tight"
      #|p1 text 10.0,35.2 w29.5 "A chip "
      #|p1 rect 39.5,30.6 52.8x6.6 luma(90.2%)
      #|p1 text 39.5,37.2 w52.8 "moved down"
      #|p1 line 10.0,49.2 60.0x0.0 dash 1.0 2.0
      #|p1 rect 10.0,61.2 20.0x10.0 rgb("#1d758680")
    ),
  )
  // The untyped ways: a first line indented by 1em (10pt), the same dotted
  // line and the same fill.
  let untyped = pages([@guide.untyped_fields()])
  inspect(untyped.errors(), content="")
  inspect(untyped.warnings(), content="")
  inspect(
    untyped.listing(),
    content=(
      #|p1 text 20.0,16.6 w38.3 "Indented."
      #|p1 line 10.0,28.6 60.0x0.0 dash 1.0 2.0
      #|p1 rect 10.0,40.6 20.0x10.0 rgb("#1d758680")
    ),
  )
  // 4.5: half of the region's width (180pt) and of a block's (100pt); the
  // rectangle is as high as the baseline of the measured block is deep:
  // its inset (4pt) and the height of one line (6.6pt).
  let half = pages([
    @guide.half_width(),
    @doc.Block(@guide.half_width(), width=Pt(100)),
  ])
  inspect(half.errors(), content="")
  inspect(half.warnings(), content="")
  inspect(
    half.listing(),
    content=(
      #|p1 rect 10.0,10.0 90.0x10.6 luma(78.43%)
      #|p1 text 14.0,43.2 w15.7 "half"
      #|p1 rect 10.0,59.2 50.0x10.6 luma(78.43%)
      #|p1 text 14.0,92.3 w15.7 "half"
    ),
  )
}

///|
test "section 5: fonts come from the world" {
  let text : Array[&@doc.IntoContent] = [@guide.font_families(), "mono"]
  // The directory of the embedded fonts, read as a directory of the
  // project.
  let from_dir = pages(text, world=@guide.fonts_of("typst_assets/fonts/files"))
  inspect(from_dir.errors(), content="")
  inspect(from_dir.warnings(), content="")
  inspect(
    from_dir.of_kind("text").map(run => run.family).join(","),
    content=(
      #|DejaVu Sans Mono
    ),
  )
  // A directory without fonts: each family of the list is reported, and
  // the page has no text.
  let empty = pages(text, world=@guide.fonts_of("docs"))
  inspect(empty.errors(), content="")
  inspect(
    empty.warnings(),
    content=(
      #|unknown font family: dejavu sans mono | unknown font family: libertinus serif
    ),
  )
  assert_eq(empty.of_kind("text").length(), 0)
  // A family that the world does not have is reported where it is named,
  // and the next one of the list is used.
  let missing = pages([
    @doc.SetText(font=["No Such Sans", "Libertinus Serif"]),
    "serif",
  ])
  inspect(
    missing.warnings(),
    content=(
      #|unknown font family: no such sans
    ),
  )
  guard missing.report.warnings[0].location is Some(Edsl(origin)) else {
    fail("expected an EDSL location")
  }
  inspect(
    place(origin),
    content=(
      #|guide_test.mbt (SetText, argument 1)
    ),
  )
  inspect(
    missing.of_kind("text").map(run => run.family).join(","),
    content=(
      #|Libertinus Serif
    ),
  )
}

///|
test "section 6: auto columns take their content's width" {
  // The region is 180pt wide. The short text is 64.8pt wide and has 10pt
  // of insets: its column gets that, the other one the rest, where the
  // long text takes three lines.
  let auto = pages([@guide.prose_table([Auto, Auto])])
  inspect(auto.errors(), content="")
  inspect(
    auto.of_kind("rect").map(cell => pt(cell.w)).join(" "),
    content=(
      #|74.8 105.2
    ),
  )
  inspect(
    auto.of_kind("text").length(),
    content=(
      #|4
    ),
  )
  // Fractions divide the width whatever the content is.
  let weighted = pages([@guide.prose_table([Fr(1), Fr(2)])])
  inspect(
    weighted.of_kind("rect").map(cell => pt(cell.w)).join(" "),
    content=(
      #|60.0 120.0
    ),
  )
}

///|
test "section 6: a sticky block stays with the block after it" {
  // 40pt are taken; the heading and the line under it fit the rest of the
  // page, the block after them does not.
  let next = @doc.Block(
    "one two three four five six seven eight nine ten eleven twelve",
    breakable=false,
    width=Pt(80),
  )
  let page_of = (pages : Pages, text : String) => {
    pages.marks.filter(m => m.text.contains(text))[0].page
  }
  // A heading is sticky: it moves with the block after it.
  let heading = pages([@doc.V(Pt(40)), @doc.Heading("Results"), next])
  assert_eq(page_of(heading, "Results"), 2)
  assert_eq(page_of(heading, "one two"), 2)
  // The paragraph is not: the heading stays with it, and both stay
  // behind.
  let loose = pages([@doc.V(Pt(40)), @guide.loose_title(next)])
  inspect(loose.errors(), content="")
  assert_eq(page_of(loose, "Results"), 1)
  assert_eq(page_of(loose, "Sorted"), 1)
  assert_eq(page_of(loose, "one two"), 2)
  // As one sticky block they move with the block.
  let kept = pages([@doc.V(Pt(40)), @guide.kept_title(next)])
  inspect(kept.errors(), content="")
  assert_eq(page_of(kept, "Results"), 2)
  assert_eq(page_of(kept, "Sorted"), 2)
  assert_eq(page_of(kept, "one two"), 2)
  // So they do when the paragraph is a sticky block of its own:
  // consecutive sticky blocks are a group.
  let both = pages([
    @doc.V(Pt(40)),
    @doc.Heading("Results"),
    @doc.Block("Sorted by name.", sticky=true),
    next,
  ])
  assert_eq(page_of(both, "Results"), 2)
  assert_eq(page_of(both, "Sorted"), 2)
  assert_eq(page_of(both, "one two"), 2)
}

///|
test "section 6: the size of raw text" {
  let size = (children : Array[&@doc.IntoContent]) => {
    let raw = pages(children).marks.filter(m => m.text.contains("code"))[0]
    pt(raw.h)
  }
  // In 10pt text raw text is 8pt.
  inspect(
    size([@doc.Raw("code")]),
    content=(
      #|8.0
    ),
  )
  // A size that is set around it is multiplied with the 0.8em of `raw`,
  // also an absolute one.
  inspect(
    size([@doc.Text(@doc.Raw("code"), size=Em(0.9))]),
    content=(
      #|7.2
    ),
  )
  inspect(
    size([@doc.Text(@doc.Raw("code"), size=Pt(9))]),
    content=(
      #|7.2
    ),
  )
  // A show-set rule on `raw` is applied after that 0.8em: an absolute
  // size is the size of the raw text, an em size is multiplied with the
  // 0.8em again.
  inspect(
    size([@guide.code_size(), @doc.Raw("code")]),
    content=(
      #|9.0
    ),
  )
  inspect(
    size([
      @doc.ShowSet(@doc.Select::raw(), @doc.SetText(size=Em(0.9))),
      @doc.Raw("code"),
    ]),
    content=(
      #|7.2
    ),
  )
}

///|
test "section 6: the sides of a stroke that are not named" {
  let cells : Array[&@doc.IntoContent] = ["a", "b", "c", "d"]
  let rule = @doc.Stroke(thickness=Pt(0.5), paint=Luma(120))
  let lines = (table : &@doc.IntoContent) => {
    let mut across = 0
    let mut down = 0
    for line in pages([table]).of_kind("line") {
      if line.h == 0.0 {
        across += 1
      } else {
        down += 1
      }
    }
    "\{across} across, \{down} down"
  }
  // Two rows of two cells. Only `bottom`: the other sides are the table's
  // default stroke, so there is a rule above the first row and there are
  // three rules down.
  inspect(
    lines(
      @doc.Table(
        cells,
        columns=[Auto, Auto],
        stroke=@doc.Cells::all(@doc.Sides(bottom=rule)),
      ),
    ),
    content=(
      #|3 across, 3 down
    ),
  )
  // With `rest=Stroke::none()`: the two rules below the rows.
  inspect(
    lines(@guide.ruled_table(cells)),
    content=(
      #|2 across, 0 down
    ),
  )
  // A grid has no default stroke.
  inspect(
    lines(
      @doc.Grid(
        cells,
        columns=[Auto, Auto],
        stroke=@doc.Cells::all(@doc.Sides(bottom=rule)),
      ),
    ),
    content=(
      #|2 across, 0 down
    ),
  )
}

///|
test "section 6: the apostrophe" {
  let text = (item : &@doc.IntoContent) => {
    pages([item]).of_kind("text").map(run => run.text).join("|")
  }
  inspect(
    text(@doc.Prose("Issue #1770's fix is in.")),
    content=(
      #|Issue #1770′s fix is in.
    ),
  )
  inspect(
    text(@guide.apostrophes()),
    content=(
      #|Issue #1770’s fix is in.|Issue #1770's fix is in.
    ),
  )
}

///|
test "section 7: the cards of a row are equally high" {
  let short = "One."
  let long = "Two, with more text than the first card has, so that it needs three lines."
  let cards = pages([@guide.cards([short, long])])
  inspect(cards.errors(), content="")
  inspect(cards.warnings(), content="")
  let cells = cards.of_kind("rect")
  inspect(
    cells.map(cell => "\{pt(cell.w)}x\{pt(cell.h)}").join(" "),
    content=(
      #|86.0x74.9 86.0x74.9
    ),
  )
  assert_eq(cells.length(), 2)
  assert_eq(pt(cells[0].h), pt(cells[1].h))
  assert_eq(pt(cells[0].y), pt(cells[1].y))
  // Three to a row, the last row open: five cards. With a radius the text
  // of the cards is where it is without one (their boxes are compared in
  // `doc/kit/cards_test.mbt`).
  let five : Array[&@doc.IntoContent] = [
    short, "Two, with more.", short, short, "Five, with more.",
  ]
  let rounded = pages([@guide.rounded_cards(five)])
  inspect(rounded.errors(), content="")
  inspect(rounded.warnings(), content="")
  let square = pages([
    @kit.Cards(
      five,
      columns=@doc.Sizing::repeat(3, size=Fr(1)),
      gutter=[Pt(8)],
      inset=@doc.Sides(all=Pt(8)),
      fill=Luma(245),
    ),
  ])
  assert_eq(square.of_kind("rect").length(), 5)
  let texts = (pages : Pages) => {
    pages
    .of_kind("text")
    .map(run => "\{run.page} \{pt(run.x)} \{pt(run.y)} \{run.text}")
    .join("\n")
  }
  assert_eq(texts(rounded), texts(square))
  // A click on a card leads to the call, a selection in it to the string.
  let origin = cards.origin("One.")
  assert_eq(origin.kind, "Cards")
  assert_eq(origin.param, Some(0))
  // With a radius it cannot be built inside a callback, and a column
  // cannot be `Auto`; without one both are fine.
  let late = (radius : @doc.Corners[@doc.Length]?) => {
    pages([@doc.Layout((_, _) => @kit.Cards([short, long], radius?))]).errors()
  }
  inspect(late(None), content="")
  inspect(
    late(Some(@doc.Corners(all=Pt(4)))),
    content="callbacks cannot be created inside a callback",
  )
  let auto = (radius : @doc.Corners[@doc.Length]?) => {
    pages([@kit.Cards([short, long], columns=[Auto, Fr(1)], radius?)]).errors()
  }
  inspect(auto(None), content="")
  assert_true(
    auto(Some(@doc.Corners(all=Pt(4)))).contains("cannot have an `Auto` column"),
  )
  // Blocks with a fill in the cells are as high as their own content.
  let block = (body : String) => {
    @doc.Block(body, inset=@doc.Sides(all=Pt(8)), fill=Luma(245))
  }
  let blocks = pages([
    @doc.Grid([block(short), block(long)], columns=[Fr(1), Fr(1)], gutter=[
      Pt(8),
    ]),
  ])
  inspect(
    blocks.of_kind("rect").map(cell => "\{pt(cell.w)}x\{pt(cell.h)}").join(" "),
    content=(
      #|35.0x22.6 82.4x74.9
    ),
  )
}

///|
/// The lines of a compiled document: how many go across and how many down.
fn Pages::lines(self : Pages) -> String {
  let mut across = 0
  let mut down = 0
  for line in self.of_kind("line") {
    if line.h == 0.0 {
      across += 1
    } else {
      down += 1
    }
  }
  "\{across} across, \{down} down"
}

///|
test "section 7: a table of data is given by rows, and every row is checked" {
  let rows : Array[Array[&@doc.IntoContent]] = [
    ["North", "Beans", "4.5"],
    ["South", "Chard", "12.0"],
  ]
  let table = pages([@guide.harvest_table(rows)])
  inspect(table.errors(), content="")
  inspect(table.warnings(), content="")
  // A rule under the header and under each row, and no other line.
  inspect(
    table.lines(),
    content=(
      #|3 across, 0 down
    ),
  )
  // The numbers and their header end where their column ends.
  let ends = table
    .of_kind("text")
    .filter(run => ["Harvest (kg)", "4.5", "12.0"].contains(run.text))
    .map(run => pt(run.x + run.w))
  inspect(
    ends.join(" "),
    content=(
      #|185.0 185.0 185.0
    ),
  )
  // A row with a cell too few: the text of the guide, with every number
  // as `N`.
  let short = pages([@guide.short_row()])
  inspect(
    numberless(short.report.errors[0].render()),
    content=(
      #|error: `rows[N]` has cells for N columns: this `DataTable` has N columns
      #|  at doc/examples/guide/guide.mbt:N:N (DataTable, argument N, key "N")
    ),
  )
  // A cell that spans is counted with its span.
  let spanned = pages([
    @guide.harvest_table([
      ["North", "Beans", "4.5"],
      [@doc.TableCell("Both beds", colspan=2), "16.5"],
    ]),
  ])
  inspect(spanned.errors(), content="")
  // Over pages: the header is on each, and a row of three lines is not
  // split.
  let many : Array[Array[&@doc.IntoContent]] = Array::makei(4, i => {
    ["Bed \{i + 1}", "A crop that needs a second line in its column.", "1.0"]
  })
  let long = pages([@guide.harvest_table(many)])
  inspect(long.errors(), content="")
  let texts = long.of_kind("text")
  let crop = texts.filter(run => run.text == "Crop")
  // Per page: the header, the rows, and the lines of text in the second
  // column, which are three for every row.
  let per_page : Array[String] = []
  for header in crop {
    let on_page = texts.filter(run => run.page == header.page)
    let rows = on_page.filter(run => run.text.has_prefix("Bed ")).length()
    let lines = on_page
      .filter(run => pt(run.x) == pt(header.x) && run.text != "Crop")
      .length()
    per_page.push("p\{header.page}: \{rows} rows, \{lines} lines")
  }
  inspect(
    per_page.join("\n"),
    content=(
      #|p1: 1 rows, 3 lines
      #|p2: 1 rows, 3 lines
      #|p3: 1 rows, 3 lines
      #|p4: 1 rows, 3 lines
    ),
  )
}

///|
test "section 7: the looks of a table of data" {
  let rows : Array[Array[&@doc.IntoContent]] = [
    ["North", "Beans", "4.5"],
    ["South", "Chard", "12.0"],
    ["West", "Kale", "3.1"],
  ]
  let table = pages([@guide.styled_table(rows, 1), "after"])
  inspect(table.errors(), content="")
  inspect(table.warnings(), content="")
  // In a frame: a rule under the header and under every row but the last.
  inspect(
    table.lines(),
    content=(
      #|3 across, 0 down
    ),
  )
  // The fills of the header and of the marked row (`rows[1]`), cell by
  // cell.
  inspect(
    table.of_kind("rect").map(cell => "\{pt(cell.y)} \{cell.fill}").join("\n"),
    content=(
      #|10.0 luma(92.16%)
      #|41.4 rgb("#fdf3d7")
      #|10.0 luma(92.16%)
      #|41.4 rgb("#fdf3d7")
      #|10.0 luma(92.16%)
      #|41.4 rgb("#fdf3d7")
    ),
  )
  // The text: 9pt in the table, the header in its own size, the numbers
  // in their font, the text after the sequence as before.
  inspect(
    table
    .of_kind("text")
    .map(run => "\{run.text}: \{pt(run.h)} \{run.family}")
    .join("\n"),
    content=(
      #|BED: 7.0 Libertinus Serif
      #|CROP: 7.0 Libertinus Serif
      #|HARVEST (KG): 7.0 Libertinus Serif
      #|North: 9.0 Libertinus Serif
      #|Beans: 9.0 Libertinus Serif
      #|4.5: 9.0 DejaVu Sans Mono
      #|South: 9.0 Libertinus Serif
      #|Chard: 9.0 Libertinus Serif
      #|12.0: 9.0 DejaVu Sans Mono
      #|West: 9.0 Libertinus Serif
      #|Kale: 9.0 Libertinus Serif
      #|3.1: 9.0 DejaVu Sans Mono
      #|after: 10.0 Libertinus Serif
    ),
  )
  // `styled_table` creates a `Cells` function: it cannot be called inside
  // a callback. `DataTable` itself creates none.
  let late = pages([@doc.Context(_ => @guide.styled_table(rows, 1))])
  inspect(
    late.errors(),
    content=(
      #|callbacks cannot be created inside a callback
    ),
  )
  let plain = pages([@doc.Context(_ => @guide.harvest_table(rows))])
  inspect(plain.errors(), content="")
  // The cells of a row resolve to the `rows` argument under the key of
  // the row.
  let origin = table.origin("Chard")
  inspect(
    place(origin),
    content=(
      #|guide.mbt (DataTable, argument 2, key "1")
    ),
  )
  inspect(
    origin.keys.join("/"),
    content=(
      #|1
    ),
  )
}

///|
test "section 7: inline code in a cell breaks where it has soft breaks" {
  let name = "garden_bed_watering_schedule"
  let table = (cell : &@doc.IntoContent) => {
    pages([
      @kit.DataTable(["Name", "Bed"], [[cell, "North"]], columns=[Pt(80), Fr(1)]),
    ])
  }
  // Without them it runs over its column, which ends at 90pt.
  let whole = table(@doc.Raw(name)).of_kind("text")[2]
  assert_eq(whole.text, name)
  assert_true(whole.x + whole.w > 90.0)
  // With them it is broken inside its cell.
  let broken = table(@guide.code_cell(name))
  inspect(broken.errors(), content="")
  let runs = broken.of_kind("text").filter(run => run.family.contains("Mono"))
  inspect(
    runs.map(run => run.text.replace_all(old="\u{200B}", new="")).join("|"),
    content=(
      #|garden_bed_|watering_|schedule
    ),
  )
  for run in runs {
    assert_true(run.x + run.w <= 85.0)
  }
}

///|
test "section 7: a chip is on the baseline of its line and stays on one line" {
  let words = "word ".repeat(7)
  let line = (item : &@doc.IntoContent) => {
    let out : Array[String] = []
    for
      run in pages([@doc.Par(@doc.Seq([words, item, " ", words, words]))]).of_kind(
        "text",
      ) {
      if !out.contains(pt(run.y)) {
        out.push(pt(run.y))
      }
    }
    out.join(" ")
  }
  // The baselines of three lines of text, with a chip in the second and
  // with a word in its place.
  let chip = @guide.status("needs water", done=false)
  inspect(
    line(chip),
    content=(
      #|16.6 29.7 42.7 55.8
    ),
  )
  assert_eq(line(chip), line(@doc.Text("needs water", size=Pt(7))))
  // A box with the padding as its inset makes its line higher.
  let box = @doc.Text(
    @doc.Box("needs water", inset=@doc.Sides(x=Em(0.6), y=Em(0.3))),
    size=Pt(7),
  )
  assert_true(line(box) != line(chip))
  // The label is one run, in the size and the weight of the `Text`
  // around the chip, with no-break spaces.
  let label = pages([@doc.Par(chip)]).of_kind("text")
  inspect(
    label
    .map(run => "\{run.text.replace_all(old="\u{00A0}", new="~")}: \{pt(run.h)}")
    .join("|"),
    content=(
      #|needs~water: 7.0
    ),
  )
  // In a column of 50pt the label is one line, where a box breaks it.
  let cell = (item : &@doc.IntoContent) => {
    pages([@doc.Table([item, "x"], columns=[Pt(50), Fr(1)])])
    .of_kind("text")
    .filter(run => run.text != "x")
    .length()
  }
  inspect(
    cell(chip),
    content=(
      #|1
    ),
  )
  inspect(
    cell(@doc.Box("needs water", inset=@doc.Sides(x=Em(0.6)))),
    content=(
      #|2
    ),
  )
}

///|
test "section 7: a chart on a canvas is as wide as its container, its labels at their anchors" {
  let beds = [("North", 4.5), ("South", 12.0)]
  // In a pad of 20pt to each side of the region's 180pt: a canvas of
  // 140pt, from 30pt to 170pt of the page.
  let chart = pages([@doc.Pad(@guide.harvest_chart(beds, 12.0), x=Pt(20))])
  inspect(chart.errors() + chart.warnings(), content="")
  inspect(chart.listing(), content=(
    #|p1 line 66.0,10.0 0.0x28.0
    #|p1 text 64.4,45.6 w3.3 "0"
    #|p1 line 79.3,10.0 0.0x28.0
    #|p1 text 77.7,45.6 w3.3 "2"
    #|p1 line 92.7,10.0 0.0x28.0
    #|p1 text 91.0,45.6 w3.3 "4"
    #|p1 line 106.0,10.0 0.0x28.0
    #|p1 text 104.4,45.6 w3.3 "6"
    #|p1 line 119.3,10.0 0.0x28.0
    #|p1 text 117.7,45.6 w3.3 "8"
    #|p1 line 132.7,10.0 0.0x28.0
    #|p1 text 129.4,45.6 w6.5 "10"
    #|p1 line 146.0,10.0 0.0x28.0
    #|p1 text 142.7,45.6 w6.5 "12"
    #|p1 text 45.0,19.3 w17.0 "North"
    #|p1 rect 66.0,12.0 30.0x10.0 rgb("#2a78d6")
    #|p1 text 99.0,19.3 w8.1 "4.5"
    #|p1 text 45.4,33.3 w16.6 "South"
    #|p1 rect 66.0,26.0 80.0x10.0 rgb("#2a78d6")
    #|p1 text 149.0,33.3 w11.3 "12.0"
  ))
  let bars = chart.of_kind("rect")
  let lines = chart.of_kind("line")
  assert_eq(bars.length(), 2)
  // The scale ends 24pt before the right edge of the canvas: there are
  // the last line of the grid and the end of the bar of 12 kilograms.
  assert_eq(pt(lines[lines.length() - 1].x), "146.0")
  assert_eq(pt(bars[1].x + bars[1].w), "146.0")
  // A name ends 4pt before its bar, and the value of a bar starts 3pt
  // after it; both have the middle of their capitals on the middle of
  // the bar (3.3pt of 7pt text are its capitals' half: 2.3pt).
  let run = (text : String) => {
    chart.of_kind("text").filter(run => run.text == text)[0]
  }
  let name = run("South")
  assert_eq(pt(name.x + name.w), pt(bars[1].x - 4.0))
  assert_eq(pt(run("4.5").x), pt(bars[0].x + bars[0].w + 3.0))
  let middle = bars[1].y + bars[1].h / 2.0
  assert_eq(pt(name.y - middle), "2.3")
  assert_eq(pt(run("12.0").y - middle), "2.3")
  // A tick is centred under its line, its top 3pt under the bars.
  let tick = run("12")
  assert_eq(pt(tick.x + tick.w / 2.0), "146.0")
  // A click on a bar: the `Canvas::rect` that drew it, under the key of
  // its bed (after the key that the canvas gives the item).
  guard chart.report.origin_at(1, bars[1].x + 2.0, bars[1].y + 2.0)
    is Some(origin) else {
    fail("no origin at the bar")
  }
  inspect(
    place(origin) + " " + origin.keys[origin.keys.length() - 1],
    content=(
      #|guide.mbt (Canvas::rect, key "15", key "South") South
    ),
  )
}

///|
test "section 7: arrows on a canvas, and labels on one baseline" {
  let year = pages([@guide.year()])
  inspect(year.errors() + year.warnings(), content="")
  // A click on the head of the first arrow, whose tip is at (65, 10) of
  // the canvas: the `Canvas::arrow`.
  guard year.report.origin_at(1, 10.0 + 63.0, 10.0 + 10.0) is Some(origin) else {
    fail("no origin at the head")
  }
  inspect(place(origin), content=(
    #|guide.mbt (Canvas::arrow, key "3")
  ))
  // The number and its unit: both baselines 20pt under the top of the
  // canvas, the number ending at 40pt and the unit starting at 42pt.
  let both = pages([@guide.number_and_unit()])
  inspect(both.errors() + both.warnings(), content="")
  inspect(both.listing(), content=(
    #|p1 text 31.4,30.0 w18.6 "38"
    #|p1 text 52.0,30.0 w10.1 "kg"
  ))
  let runs = both.of_kind("text")
  assert_eq(pt(runs[0].y), "30.0")
  assert_eq(pt(runs[1].y), "30.0")
  assert_eq(pt(runs[0].x + runs[0].w), "50.0")
  // The anchor `Baseline` measures: built inside a callback, it is the
  // error of section 8, at the item.
  let inside = pages([@doc.Layout((_, _) => @guide.number_and_unit())])
  inspect(inside.errors(), content=(
    #|callbacks cannot be created inside a callback
  ))
  guard inside.report.errors[0].location is Some(Edsl(late)) else {
    fail("expected an EDSL location")
  }
  inspect(place(late), content=(
    #|guide.mbt (Canvas::place, key "0")
  ))
}

///|
test "section 8: a callback cannot be created inside a callback" {
  let nested = pages([@guide.stripes_in_show()])
  inspect(
    nested.errors(),
    content=(
      #|callbacks cannot be created inside a callback
    ),
  )
  let error = nested.report.errors[0]
  // The text of the guide's section 8, with every number as `N` (the
  // lines and columns of the sample).
  inspect(
    numberless(error.render()),
    content=(
      #|error: callbacks cannot be created inside a callback
      #|  at doc/examples/guide/guide.mbt:N:N (Cells)
      #|  hint: create the callback before compiling and capture it
      #|  hint: or use the `cx` of the enclosing callback
      #|  while showing heading element at doc/examples/guide/guide.mbt:N:N (Heading)
    ),
  )
  inspect(
    error.hints.map(hint => hint.message).join(" | "),
    content=(
      #|create the callback before compiling and capture it | or use the `cx` of the enclosing callback
    ),
  )
  guard error.location is Some(Edsl(origin)) else {
    fail("expected an EDSL location")
  }
  // The error is at the callback that was created too late; the trace
  // names the callback that created it.
  inspect(
    place(origin),
    content=(
      #|guide.mbt (Cells)
    ),
  )
  inspect(
    error.trace.map(point => point.description).join(" | "),
    content=(
      #|while showing heading element
    ),
  )
  // Created before compiling and captured, it is the fill of the grid:
  // the row of index 1 (the second) is filled.
  let captured = pages([@guide.stripes_captured()])
  inspect(captured.errors(), content="")
  inspect(
    captured.listing(),
    content=(
      #|p1 rect 10.0,19.0 45.6x9.0 luma(90.2%)
      #|p1 text 10.0,19.0 w45.6 "Striped"
      #|p1 text 10.0,28.1 w35.1 "row 1"
      #|p1 text 10.0,37.1 w35.1 "row 2"
    ),
  )
}
