// A. Einstein, "The Foundation of the Generalised Theory of Relativity"
// (Annalen der Physik, 1916), in the translation of S. N. Bose (1920), as
// English Wikisource transcribes it, set as a journal article with the
// EDSL. Rights, and what is left out (all footnotes), are in `../README.md`
// and in the colophon below.
//
//   mkdir -p _build/papers
//   moon run doc/examples/papers/einstein-1916 --target native
//
// writes `_build/papers/einstein-1916.pdf` and one PNG per page.

///|
using @doc {
  type Document,
  type SetPage,
  type SetText,
  type SetPar,
  type SetHeading,
  type SetEquation,
  type SetAlign,
  type SetBlock,
  type ShowSet,
  type Select,
  type Heading,
  type Prose,
  type Parbreak,
  type Equation,
  type Ref,
  type Numbering,
  type Supplement,
  type Value,
  type Context,
  type Counter,
  type Ctx,
  type Emph,
  type Smallcaps,
  type Text,
  type Block,
  type Align,
  type Grid,
  type Cells,
  type Line,
  type Seq,
  type V,
  type Bibliography,
  type Link,
  type Place,
  type Circle,
  type Polygon,
  type Stroke,
  type H,
  type Linebreak,
  trait IntoContent,
}

// ---------------------------------------------------------------------
// Mathematics
// ---------------------------------------------------------------------

///|
/// A function of Typst as a value, for the scope of the formulas.
fn typst_function(source : String) -> Value {
  Value::call("eval", positional=[Value::str(source)])
}

///|
/// What every formula can use besides Typst's own names: Christoffel's
/// symbols in the notation of the paper, `chr(mu nu, tau)` with braces (the
/// second kind) and `chf(mu nu, sigma)` with brackets (the first kind).
let scope : Array[(String, Value)] = [
  ("chr", typst_function("(a, b) => math.mat(delim: \"{\", (a,), (b,))")),
  ("chf", typst_function("(a, b) => math.mat(delim: \"[\", (a,), (b,))")),
  (
    "sys",
    typst_function(
      (
        #|(..rows) => math.mat(
        #|  delim: ("{", none),
        #|  row-gap: 0.9em,
        #|  ..rows.pos().map(row => (math.display(row),)),
        #|)
      ),
    ),
  ),
]

///|
/// A formula in the line.
#callsite(autofill(loc, args_loc))
fn m(source : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Equation {
  Equation(source, scope~, loc~, args_loc~)
}

///|
/// A displayed formula without a number.
#callsite(autofill(loc, args_loc))
fn dm(source : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Equation {
  Equation(source, block=true, scope~, loc~, args_loc~)
}

///|
/// A displayed formula with the paper's own number (`"20a"`), which is also
/// its label: `r("20a")` refers to it.
#callsite(autofill(loc, args_loc))
fn eq(
  source : String,
  tag : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Equation {
  Equation(
    source,
    block=true,
    numbering=Numbering::func() <| ((_, _) => "(\{tag})"),
    label="eq-\{tag}",
    scope~,
    loc~,
    args_loc~,
  )
}

///|
/// The number of a formula, as the paper writes it: "(20a)".
#callsite(autofill(loc, args_loc))
fn r(tag : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Ref {
  Ref("eq-\{tag}", loc~, args_loc~)
}

///|
/// The number of a formula without the parentheses, where the paper writes
/// "equation 43": a link to the formula.
#callsite(autofill(loc, args_loc))
fn rb(tag : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Link {
  Link(ToLabel("eq-\{tag}"), body=tag, loc~, args_loc~)
}

///|
/// A number with a decimal comma (the paper writes "6,7"), which as
/// mathematics would be a list of two numbers; `rest` is what follows it
/// in the formula.
fn decimal(number : String, rest : String) -> Equation {
  Equation("\"\{number}\"\{rest}", scope~)
}

// ---------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------

///|
fn em(text : String) -> Emph {
  Emph(text)
}

///|
fn sc(name : String) -> Smallcaps {
  Smallcaps(name)
}

///|
/// The indent of a paragraph that begins after a displayed formula. Typst
/// indents a paragraph only after another paragraph, and the text after a
/// displayed formula is a paragraph of its own: where the paper goes on
/// with the sentence it must not be indented, where it begins a new
/// paragraph it must be, and only the author knows which.
fn indent() -> H {
  H(Em(1.3))
}

///|
/// A numbered paragraph of the paper: "§ 7. Multiplication of Tensors."
#callsite(autofill(loc, args_loc))
fn sec(
  title : &IntoContent,
  number : Int,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Heading {
  Heading(title, label="sec-\{number}", loc~, args_loc~)
}

///|
/// "§ 7", a reference to a paragraph of the paper.
#callsite(autofill(loc, args_loc))
fn s(number : Int, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Ref {
  Ref("sec-\{number}", loc~, args_loc~)
}

///|
/// One of the parts A to E: a heading without a number of its own, so that
/// the paragraphs are counted through the whole paper.
#callsite(autofill(loc, args_loc))
fn part(title : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Heading {
  Heading(
    Text(title, size=Pt(12), style="normal"),
    numbering=Numbering::none(),
    loc~,
    args_loc~,
  )
}

// ---------------------------------------------------------------------
// Page design
// ---------------------------------------------------------------------

///|
const SHORT_TITLE : String = "The Foundation of the Generalised Theory of Relativity"

///|
fn page_number(cx : Ctx) -> Int64 raise {
  cx.counter(Counter::page()).get()[0]
}

///|
/// The running header: the page number at the outer edge, the author on
/// even pages and the title on odd ones; nothing on the first page.
fn running_header(cx : Ctx) -> &IntoContent raise {
  let page = page_number(cx)
  if page == 1 {
    return Seq([])
  }
  let number : &IntoContent = "\{page}"
  let empty : &IntoContent = ""
  let (left, middle, right) : (&IntoContent, &IntoContent, &IntoContent) = if page %
    2 ==
    0 {
    (number, Prose("A. \{sc("Einstein")}."), empty)
  } else {
    (empty, Emph(SHORT_TITLE + "."), number)
  }
  Text(
    Grid(
      [left, middle, right],
      columns=[Fr(1), Auto, Fr(1)],
      align=Cells::columns([Left, Center, Right]),
    ),
    size=Pt(9),
  )
}

///|
/// The first page has its number at the foot.
fn first_page_footer(cx : Ctx) -> &IntoContent raise {
  if page_number(cx) != 1 {
    return Seq([])
  }
  Align(Center, Text("1", size=Pt(9)))
}

///|
fn design() -> Array[&IntoContent] {
  [
    SetPage(
      paper="a4",
      margin=Sides(top=Mm(34), bottom=Mm(32), x=Mm(35)),
      header=Context() <| running_header,
      footer=Context() <| first_page_footer,
      header_ascent=Pct(40),
    ),
    SetText(font=["New Computer Modern"], size=Pt(10.5), lang="en"),
    SetPar(justify=true, leading=Em(0.62), spacing=Em(0.62), extra=[
      ("first-line-indent", Value::dict([("amount", Value::length(Em(1.3)))])),
    ]),
    // The formulas have the paper's numbers, and the text refers to them by
    // the number alone.
    SetEquation(supplement=Supplement::none()),
    // "§ 7." before the title; a reference is the supplement and the number
    // without its full stop: "§ 7".
    SetHeading(numbering=Numbering("§ 1."), supplement=Supplement("§")),
    ShowSet(
      Select::heading(),
      SetText(size=Pt(10.5), weight=Regular, style="italic", hyphenate=false),
    ),
    ShowSet(Select::heading(), SetAlign(alignment=Center)),
    ShowSet(Select::heading(), SetBlock(above=Em(1.8), below=Em(1.1))),
    ShowSet(
      Select::equation(block=true),
      SetBlock(above=Em(0.95), below=Em(0.95)),
    ),
  ]
}

///|
fn title_block() -> Array[&IntoContent] {
  [
    Align(
      Center,
      Seq([
        Block(
          Text(
            Seq([
              "The Foundation of the Generalised Theory",
              Linebreak(),
              "of Relativity",
            ]),
            size=Pt(17),
          ),
          below=Em(1.4),
        ),
        Block(Prose("By A. \{sc("Einstein")}."), below=Em(1.2)),
        Block(
          Text(
            Prose(
              (
                $|\{em("Annalen der Physik")} 354 (7), 1916, pp. 769–822.
                $|Translated by Satyendra Nath Bose (1920).
              ),
            ),
            size=Pt(9),
          ),
          below=Em(1.6),
        ),
        Line(length=Mm(22), stroke=Stroke(thickness=Pt(0.5))),
      ]),
    ),
    V(Em(1.2)),
  ]
}

///|
/// The source, the rights and what is left out, on the last page. The
/// transcription has sixteen footnotes; it says of itself that "the omitted
/// references were included and translated from the German original", so
/// some of them are translations by its contributors (CC BY-SA), not Bose's
/// text of 1920, and nothing here tells which. None is reproduced.
fn colophon() -> Array[&IntoContent] {
  [
    V(Em(2.5)),
    Align(Center, Line(length=Mm(22), stroke=Stroke(thickness=Pt(0.5)))),
    V(Em(0.8)),
    Text(
      Prose(
        (
          $|\{em("About this text.")} Albert Einstein, “Die Grundlage der
          $|allgemeinen Relativitätstheorie”, \{em("Annalen der Physik")} 354
          $|(7), 1916, pp. 769–822, in the English translation of Satyendra Nath
          $|Bose, “The Foundation of the Generalised Theory of Relativity”,
          $|in \{em("The Principle of Relativity: Original Papers by A. Einstein and H. Minkowski")}
          $|(University of Calcutta, 1920), pp. 89–163. The text is that of
          $|the transcription at English Wikisource,
          $|en.wikisource.org/wiki/The_Foundation_of_the_Generalised_Theory_of_Relativity,
          $|which writes the formulas in Einstein's notation and says that
          $|“the omitted references were included and translated from the
          $|German original”. \{em("Omitted here:")} all sixteen footnotes of
          $|the transcription, because nothing in it tells which are Bose's
          $|of 1920 and which were translated by its contributors (whose work
          $|is licensed CC BY-SA and is not in the public domain); the three
          $|works that the footnotes cite are listed above, as bibliographic
          $|data. \{em("Rights.")} The
          $|original (1916; Einstein died in 1955) and the translation (1920;
          $|Bose died in 1974) are in the public domain in the United States,
          $|where Wikisource marks both so because they were published before
          $|January 1, 1931. The translation is also in the public domain
          $|where copyright ends 50 years after the author's death. It is not
          $|in India, where it was published (60 years: until the end of
          $|2034), nor in the countries with a term of 70 years, among them
          $|those of the European Union and the United Kingdom (until the end
          $|of 2044 at the latest, and of 2034 where the term of a foreign
          $|work is limited to that of its country of origin). The numbers of
          $|the formulas (29), (41a), (54) and (70), which the transcription
          $|lacks and the text refers to, are those of the original; the
          $|diagram in § 22 is drawn again from the text. The text was not
          $|compared with the edition of 1920.
        ),
      ),
      size=Pt(9),
    ),
  ]
}

///|
fn document() -> Document {
  Document(
    [
      ..design(),
      ..title_block(),
      ..opening(),
      ..part_a(),
      ..part_b_intro(),
      ..sec_5(),
      ..sec_6(),
      ..sec_7(),
      ..sec_8(),
      ..sec_9(),
      ..sec_10(),
      ..sec_11(),
      ..sec_12(),
      ..sec_13(),
      ..sec_14(),
      ..sec_15(),
      ..sec_16(),
      ..sec_17(),
      ..sec_18(),
      ..part_d_intro(),
      ..sec_19(),
      ..sec_20(),
      ..sec_21(),
      ..sec_22(),
      // The works that the footnotes of the transcription cite. The
      // footnotes are omitted (see `colophon`), so nothing cites them and
      // the list is asked for in full.
      Bibliography(
        "refs.yml",
        title="References",
        full=true,
        style="american-physics-society",
      ),
      ..colophon(),
    ],
  )
}

///|
fn run() -> Unit raise {
  let world = @system.world(
    root="doc/examples/papers/einstein-1916",
    system_fonts=false,
    today=(1916, 3, 20),
  )
  let compiled = document().compile_paged(world)
  for diagnostic in compiled.warnings {
    println(diagnostic.render())
  }
  for lint in compiled.lints {
    println(lint.render())
  }
  let pages = compiled.unwrap().pages().length()
  println("\{pages} pages")
  let out = "_build/papers/einstein-1916"
  @system.write("\{out}.pdf", compiled.pdf().unwrap())
  for i, page in compiled.png_pages(ppi=110).unwrap() {
    @system.write("\{out}-\{i + 1}.png", page)
  }
}

///|
fn main {
  run() catch {
    @doc.DocError(errors) =>
      for error in errors {
        println(error.render())
      }
    err => println("error: \{err}")
  }
}
