// The page design (a memoir of 1843 set with modern tools) and the helpers
// the text is written with.

///|
using @doc {
  type Document,
  type SetPage,
  type SetText,
  type SetPar,
  type SetFootnote,
  type SetEnum,
  type Page,
  type Par,
  type Prose,
  type Seq,
  type Emph,
  type Smallcaps,
  type Upper,
  type Text,
  type Super,
  type Heading,
  type Equation,
  type Footnote,
  type Cite,
  type Ref,
  type Bibliography,
  type Enum,
  type Align,
  type Block,
  type Box,
  type Pad,
  type Line,
  type Link,
  type Length,
  type H,
  type Grid,
  type GridCell,
  type Table,
  type TableCell,
  type TableHline,
  type Rotate,
  type Pagebreak,
  type Parbreak,
  type Linebreak,
  type Alignment,
  type Context,
  type Show,
  type ShowSet,
  type Select,
  type Counter,
  type CounterUpdate,
  type Supplement,
  type Cells,
  type Sides,
  type Stroke,
  type Sizing,
  type Value,
  type NoneValue,
  trait IntoContent,
}

// ---------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------

///|
/// A paragraph of running text. It is not a `Par`: a displayed formula
/// inside a `Par` is dropped ("block may not occur inside of a paragraph
/// and was ignored"), so the text is left to form its paragraph as markup
/// does, and a paragraph break ends it.
#callsite(autofill(loc, args_loc))
fn par(text : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Seq {
  Seq([Prose(text, loc~, args_loc~), Parbreak()])
}

///|
/// The indent of a paragraph.
let indent : Length = Em(1.4)

///|
/// A paragraph that follows a heading, a list or a displayed formula that
/// ended the paragraph before it. Typst indents a paragraph only after
/// another paragraph (or, with `all: true`, also the text that goes on after
/// a displayed formula), so these get their indent by hand.
#callsite(autofill(loc, args_loc))
fn indented(text : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Seq {
  Seq([H(indent.spacing()), Prose(text, loc~, args_loc~), Parbreak()])
}

///|
/// Italics of the original.
fn i(text : String) -> Emph {
  Emph(text)
}

///|
/// A formula in the line. It is boxed, so that a line cannot break inside
/// it (at "=" or "-"), as the transcription asks with its `nowrap`.
#callsite(autofill(loc, args_loc))
fn m(source : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Box {
  Box(Equation(source, loc~, args_loc~))
}

///|
/// A displayed formula without a number.
#callsite(autofill(loc, args_loc))
fn disp(source : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Equation {
  Equation(source, block=true, loc~, args_loc~)
}

///|
/// A displayed formula with the paper's number, `(1.)`, and a label.
#callsite(autofill(loc, args_loc))
fn numbered(
  source : String,
  label : String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Equation {
  Equation(
    source,
    block=true,
    numbering=Numbering("(1.)"),
    label~,
    loc~,
    args_loc~,
  )
}

///|
/// A reference to a numbered formula, as the paper prints it: "(8.)". A
/// reference gives the bare number (Typst drops what stands around the
/// counter in the numbering pattern), so the rest is written here.
fn eq(label : String) -> Seq {
  Seq(["(", Ref(label, supplement=Supplement::none()), ".)"])
}

///|
/// A citation that leaves the text as it is and puts the work into the
/// list at the end: the paper names its sources in the running text.
fn cited(key : String) -> Cite {
  Cite(key, extra=[("form", Value::none())])
}

///|
let edinburgh : Cite = cited("edinburgh-1834")

///|
/// The initials that close a note.
fn signature(initials : String) -> Align {
  Align(Right, Pad(initials, right=Em(2)))
}

///|
/// Something that stands on a line of its own inside a paragraph (a small
/// table): an inline box of the full width, so that the paragraph goes on
/// after it. A `Block` would end the paragraph.
fn in_paragraph(body : &IntoContent) -> Seq {
  // The line break keeps the line before the box from being justified.
  Seq([
    Linebreak(),
    Box(Align(Center, body), width=Pct(100), inset=Sides(y=Em(0.5))),
  ])
}

///|
/// A remark of this edition, not of the paper.
fn editorial(text : String) -> Block {
  Block(
    Align(Center, Text(Emph(text), size=Pt(9.5))),
    width=Pct(100),
    above=Em(1.6),
    below=Em(0.4),
  )
}

///|
/// The heading of a note: "Note A." in small capitals, then the page of the
/// memoir it belongs to.
fn note_heading(letter : String, page : String) -> Array[&IntoContent] {
  [
    // Each note numbers its formulas and marks its footnotes from the start.
    CounterUpdate(Counter::of(Select::equation()), [0]),
    CounterUpdate(Counter::of(Select::footnote()), [0]),
    Heading(
      Seq([Smallcaps("Note \{letter}."), "—Page \{page}."]),
      label="note-\{letter}",
    ),
  ]
}

// ---------------------------------------------------------------------
// Mathematics helpers: the source strings of Typst math
// ---------------------------------------------------------------------

///|
/// "&c." inside a formula.
let etc : String = "\"&c.\""

///|
/// A column of the engine, the upright bold V with its number: `V_4`.
fn vn(sub : Int) -> String {
  "bold(upright(V))_(\{sub})"
}

///|
/// A column with the index of its value at the upper left: `^1 V_4`.
fn v(pre : Int, sub : Int) -> String {
  "attach(bold(upright(V)), tl: \{pre}, br: \{sub})"
}

///|
/// `V_4` in the line.
fn mv(sub : Int) -> Box {
  m(vn(sub))
}

///|
/// `^1 V_4` in the line.
fn mpv(pre : Int, sub : Int) -> Box {
  m(v(pre, sub))
}

///|
/// A number of Bernoulli in the line: `B_7`.
fn b(index : String) -> Box {
  m("B_(\{index})")
}

// ---------------------------------------------------------------------
// Page design
// ---------------------------------------------------------------------

///|
let body_size : Double = 10.5

///|
let rule : Stroke = Stroke(thickness=Pt(0.5))

///|
/// The running head: the folio outside, the title in small capitals in the
/// middle, as in the volume (even pages "Translator's Notes to M. Menabrea's
/// Memoir", odd pages "On Babbage's Analytical Engine."). The first page has
/// none.
fn running_head() -> Context {
  Context(cx => {
    let page = cx.counter(Counter::page()).get()[0]
    if page <= 1L {
      return (NoneValue() : &IntoContent)
    }
    let folio = Text(page.to_string(), size=Pt(body_size))
    let head = (title : String) => {
      Text(Upper(title), size=Pt(7.5), tracking=Pt(0.6))
    }
    if page % 2L == 0L {
      Grid(
        [
          Align(Left, folio),
          Align(Center, head("Translator’s Notes to M. Menabrea’s Memoir")),
          "",
        ],
        columns=[Fr(1), Auto, Fr(1)],
        align=Cells::all(Bottom),
      )
    } else {
      Grid(
        [
          "",
          Align(Center, head("On Babbage’s Analytical Engine.")),
          Align(Right, folio),
        ],
        columns=[Fr(1), Auto, Fr(1)],
        align=Cells::all(Bottom),
      )
    }
  })
}

///|
fn design() -> Array[&IntoContent] {
  [
    SetPage(
      paper="a4",
      margin=Sides(left=Mm(38), right=Mm(38), top=Mm(32), bottom=Mm(29)),
      header=running_head(),
      header_ascent=Pct(40),
    ),
    SetText(font=["New Computer Modern"], size=Pt(body_size), lang="en"),
    SetPar(justify=true, leading=Em(0.6), spacing=Em(0.6), extra=[
      ("first-line-indent", Value::length(indent)),
    ]),
    SetFootnote(numbering=Numbering("*")),
    SetEnum(numbering=Numbering("1."), indent=Em(1.4), spacing=Em(0.6)),
    ShowSet(Select::elem("footnote.entry"), SetText(size=Pt(8.8))),
    Show(Select::heading(), (it, _) => {
      Block(
        Align(Center, Text(it.body(), size=Pt(body_size), weight=Regular)),
        width=Pct(100),
        above=Em(2.2),
        below=Em(1.2),
        sticky=true,
      )
    }),
  ]
}

///|
/// The title block: the head of the memoir in the volume, the translator,
/// and the head of her Notes.
fn title_block() -> Array[&IntoContent] {
  let centre = (body : &IntoContent, above : Double) => {
    Block(Align(Center, body), width=Pct(100), above=Em(above), below=Em(0))
  }
  [
    centre(
      Text(Upper("Scientific Memoirs, Vol. III."), size=Pt(8), tracking=Pt(0.8)),
      0,
    ),
    centre(Line(length=Pct(100), stroke=rule), 0.8),
    centre(Smallcaps("Article XXIX."), 2.6),
    centre(
      Par(
        Text(
          Prose(
            (
              $|\{i("Sketch of the Analytical Engine invented by")} Charles Babbage
              $|\{i("Esq. By")} \{Smallcaps("L. F. Menabrea")},
              $|\{i("of Turin, Officer of the Military Engineers.")}
            ),
          ),
          size=Pt(15),
        ),
        justify=false,
        leading=Em(0.5),
      ),
      1.4,
    ),
    centre(
      Text(
        Prose(
          "[From the \{i("Bibliothèque Universelle de Génève")}, No. 82. October 1842.]",
        ),
        size=Pt(9),
      ),
      1.4,
    ),
    centre(
      Text(
        "Translated, with Notes, by Ada Augusta, Countess of Lovelace. London, 1843.",
        size=Pt(9),
      ),
      0.9,
    ),
    centre(Line(length=Em(6), stroke=rule), 2.2),
    centre(
      Text(Upper("Notes by the Translator."), size=Pt(12.5), tracking=Pt(0.5)),
      2.2,
    ),
    centre(Line(length=Em(6), stroke=rule), 2.2),
  ]
}

///|
/// The last page: where the text comes from, and what is in and out.
fn colophon() -> Array[&IntoContent] {
  let entry = (text : String) => {
    Par(Prose(text), extra=[("first-line-indent", Value::length(Em(0)))])
  }
  [
    Pagebreak(),
    CounterUpdate(Counter::of(Select::footnote()), [0]),
    Block(
      Align(Center, Smallcaps("Works referred to in these Notes")),
      width=Pct(100),
      above=Em(1),
      below=Em(1.2),
    ),
    Bibliography("refs.yml", title=NoneValue()),
    Block(
      Align(Center, Smallcaps("The source of this edition")),
      width=Pct(100),
      above=Em(3),
      below=Em(1.2),
    ),
    entry(
      (
        $|\{i("Work.")} L. F. Menabrea, “Sketch of the Analytical Engine invented by
        $|Charles Babbage, Esq.”, from the \{i("Bibliothèque Universelle de Génève")},
        $|No. 82, October 1842; translated, with Notes A to G, by Ada Augusta,
        $|Countess of Lovelace (signed A. A. L.), in \{i("Scientific Memoirs")}, vol. 3,
        $|pages 666 to 731, London, 1843.
      ),
    ),
    entry(
      (
        $|\{i("Author.")} L. F. Menabrea, of Turin.
        $|\{i("Translator and author of the Notes.")} Ada Augusta, Countess of
        $|Lovelace. \{i("Year.")} 1843.
      ),
    ),
    entry(
      (
        $|\{i("Text.")} The transcription of English Wikisource,
        $|“Scientific Memoirs/3/Sketch of the Analytical Engine invented by Charles
        $|Babbage, Esq./Notes by the Translator” (pages 691 to 731 of the volume),
        $|which carries the statement: “This work was published before January 1, 1931,
        $|and is in the public domain worldwide because the author died at least 100
        $|years ago.”
      ),
    ),
    Par(
      Text(
        Link(
          Url(
            "https://en.wikisource.org/wiki/Scientific_Memoirs/3/Sketch_of_the_Analytical_Engine_invented_by_Charles_Babbage,_Esq./Notes_by_the_Translator",
          ),
        ),
        size=Pt(8.5),
      ),
      justify=false,
      extra=[("first-line-indent", Value::length(Em(0)))],
    ),
    entry(
      (
        $|\{i("In this edition.")} Note A (pages 691 to 701), Note F (pages 720 to 722)
        $|and Note G (pages 722 to 731) with its folding diagram, complete; the head of
        $|the memoir from page 666. \{i("Left out.")} The memoir itself and Notes B, C, D
        $|and E. Spellings and misprints of 1843 are kept, and so are the readings of
        $|the transcription where it differs from what the sense asks for (some cells
        $|of the diagram among them).
      ),
    ),
    entry(
      (
        $|\{i("Public domain.")} The memoir, the translation and the Notes are in the
        $|public domain.
      ),
    ),
  ]
}

///|
fn paper() -> Document {
  Document(
    [
      ..design(),
      ..title_block(),
      ..note_heading("A", "674"),
      ..note_a(),
      editorial("[Notes B, C, D and E are not reproduced in this edition.]"),
      ..note_heading("F", "688"),
      ..note_f(),
      ..note_heading("G", "689"),
      ..note_g(),
      diagram_page(),
      ..colophon(),
    ],
  )
}
