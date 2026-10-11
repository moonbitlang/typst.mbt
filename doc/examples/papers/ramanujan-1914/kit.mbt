// Helpers of the port: formulas, paragraphs, the flow of two-column and
// full-width material, and a canvas for the two figures.

///|
using @doc {
  type Document,
  type SetPage,
  type SetPar,
  type SetText,
  type SetEquation,
  type SetBlock,
  type SetHeading,
  type Set,
  type Show,
  type ShowSet,
  type Select,
  type Par,
  type Prose,
  type Equation,
  type Columns,
  type Footnote,
  type Ref,
  type Heading,
  type Figure,
  type Numbering,
  type Supplement,
  type Context,
  type Layout,
  type Counter,
  type Seq,
  type Text,
  type Strong,
  type Emph,
  type Align,
  type Block,
  type Place,
  type Line,
  type Circle,
  type H,
  type V,
  type Value,
  type Lit,
  trait IntoContent,
}

///|
/// Text width between the page margins and the gutter of the two columns.
const GUTTER : Double = 20

///|
/// The space a centred display loses to its number on each side: "(50)" in
/// 10pt and Typst's gutter of half an em.
const NUMBER_ROOM : Double = 25

///|
/// What `--check` and `--dump-math` need: every formula in document order,
/// and the displays that are wider than the place they are set in.
priv struct Audit {
  mut check : Bool
  mut numbered : Int
  formulas : Array[(String, String)]
  overfull : Map[String, String]
}

///|
let audit : Audit = { check: false, numbered: 0, formulas: [], overfull: {}, }

///|
/// An item of the body: set in the two columns, or across both. The first
/// paragraph of a section is set in the columns with space above it.
priv enum Item {
  Narrow(&IntoContent)
  Section(&IntoContent)
  Wide(&IntoContent)
}

///|
/// The space above a section.
fn section_space() -> V {
  V(Em(1.1), weak=true)
}

///|
/// Makes an item span both columns.
fn wide(item : Item) -> Item {
  match item {
    Narrow(body) | Wide(body) => Wide(body)
    Section(body) => Wide(Seq([section_space(), body]))
  }
}

///|
/// Sets runs of narrow items in two balanced columns and wide items between
/// them across the text width.
fn flow(items : Array[Item]) -> Seq {
  let out : Array[&IntoContent] = []
  let mut run : Array[&IntoContent] = []
  for item in items {
    match item {
      Narrow(body) => run.push(body)
      Section(body) => {
        // Weak space at the top of the columns is dropped: when a section
        // starts them, its space goes above the columns.
        if run.length() == 0 {
          out.push(section_space())
        } else {
          run.push(section_space())
        }
        run.push(body)
      }
      Wide(body) => {
        if run.length() > 0 {
          out.push(Columns(Seq(run), count=2, gutter=Pt(GUTTER), balanced=true))
          run = []
        }
        out.push(body)
      }
    }
  }
  if run.length() > 0 {
    out.push(Columns(Seq(run), count=2, gutter=Pt(GUTTER), balanced=true))
  }
  Seq(out)
}

///|
/// Inline mathematics.
#callsite(autofill(loc, args_loc))
fn m(src : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Equation {
  audit.formulas.push(("inline", src))
  Equation(src, loc~, args_loc~)
}

///|
/// A display without a number.
#callsite(autofill(loc, args_loc))
fn ueq(src : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Item {
  audit.formulas.push(("display", src))
  let equation = Equation(
    src,
    block=true,
    numbering=Numbering::none(),
    loc~,
    args_loc~,
  )
  Narrow(checked(src, equation, 0))
}

///|
/// A display with the paper's number `n`, which must be the next one: the
/// numbers come from the engine's counter, the label `eq<n>` is what the
/// text refers to.
#callsite(autofill(loc, args_loc))
fn eq(src : String, n~ : Int, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Item {
  audit.numbered += 1
  guard audit.numbered == n else {
    abort("equation (\{n}) is the \{audit.numbered}th numbered display")
  }
  audit.formulas.push(("(\{n})", src))
  let equation = Equation(src, block=true, label="eq\{n}", loc~, args_loc~)
  Narrow(checked(src, equation, 2.0 * NUMBER_ROOM))
}

///|
/// With `--check`, reports a display that is wider than its container less
/// `reserve`. Nothing else reports it: the engine sets an overfull display
/// over the neighbouring column without a warning. The pages of a `--check`
/// run are not the paper's: `layout` is a breakable block, and a display
/// inside one is placed differently by the page and column breaks.
fn checked(src : String, equation : Equation, reserve : Double) -> &IntoContent {
  if !audit.check {
    return equation
  }
  Layout((size, cx) => {
    let bare = Equation(src, block=true, numbering=Numbering::none())
    let width = cx.measure(bare).width
    let room = size.width - reserve
    if width > room {
      audit.overfull[src] = "\{width.to_int()}pt in \{room.to_int()}pt"
    }
    equation
  })
}

///|
/// The rows of a table: a display across both columns that may break
/// between two pages. (A numbered display that breaks repeats its number on
/// each part, and one in a column breaks into the next column, so only the
/// tables are breakable.)
#callsite(autofill(loc, args_loc))
fn table_rows(src : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Item {
  audit.formulas.push(("display", src))
  let equation = Equation(
    src,
    block=true,
    numbering=Numbering::none(),
    loc~,
    args_loc~,
  )
  Wide(
    Seq([
      ShowSet(Select::equation(block=true), SetBlock(breakable=true)),
      checked(src, equation, 0),
    ]),
  )
}

///|
/// Joins the rows of a multi-line display with Typst's line break.
fn rows(lines : Array[String]) -> String {
  lines.join(" \\ ")
}

///|
/// The rows of a display that is broken to fit the column: the first row
/// at the left, the others indented.
fn hang(lines : Array[String]) -> String {
  rows(
    lines.mapi((i, line) => if i == 0 { "& " + line } else { "& quad " + line }),
  )
}

///|
/// Rows held together by a brace on the right (`\left. .. \right\}` around
/// an array). `cases` sets its rows in text style; `display` gives the
/// fractions of each part their size back. A row is split at its alignment
/// points, a comma inside a row is written `comma`.
fn braced(lines : Array[String], gap~ : String = "0.9em") -> String {
  let cells = lines.map(line => {
    let parts = line
      .split("&")
      .map(part => {
        let part = part.trim(char_set=" ").to_owned()
        if part == "" {
          ""
        } else if part.has_prefix("= ") {
          "= display(\{part[2:]})"
        } else {
          "display(\{part})"
        }
      })
      .collect()
    parts.join(" & ")
  })
  "cases(reverse: #true, gap: #\{gap}, \{cells.join(", ")})"
}

///|
/// A reference to a numbered display as the paper prints it: "(12)".
fn r(n : Int) -> Seq {
  Seq(["(", Ref("eq\{n}", supplement=Supplement::none()), ")"])
}

///|
/// A paragraph. After a display it continues the sentence and is not
/// indented; after another paragraph it is.
#callsite(autofill(loc, args_loc))
fn p(text : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Item {
  Narrow(Par(Prose(text, loc~, args_loc~)))
}

///|
/// The first paragraph of a numbered section. The number is the heading:
/// a show rule sets it as a run-in number.
#callsite(autofill(loc, args_loc))
fn sec(text : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Item {
  let heading = Heading(Seq([]), bookmarked=false)
  Section(
    Par(Prose("\{heading}\{H(Em(0.5))}" + text, loc~, args_loc~), extra=[
      ("first-line-indent", Value::length(Pt(0))),
    ]),
  )
}

///|
/// The title line of a table: a figure of the kind "table" without a body,
/// so that the text can refer to "Table III" with `Ref`.
fn table_title(label : String) -> Item {
  Wide(
    Seq([
      V(Em(1.3), weak=true),
      Figure(
        Seq([]),
        caption=Seq([]),
        supplement=Supplement("TABLE"),
        numbering=Numbering("I"),
        gap=Pt(0),
        extra=[("kind", Value::str("table"))],
        label~,
      ),
      V(Em(0.9), weak=true),
    ]),
  )
}

///|
/// A reference to a table as the text has it: "Table III".
fn table_ref(label : String) -> Ref {
  Ref(label, supplement=Supplement("Table"))
}

///|
/// A drawing in a box of `width` by `height` points. Coordinates are those
/// of the construction (the unit is the radius, y upwards); `scale` points
/// per unit, the origin at (`ox`, `oy`) points from the top left corner.
priv struct Canvas {
  width : Double
  height : Double
  scale : Double
  ox : Double
  oy : Double
  items : Array[&IntoContent]
}

///|
type Point = (Double, Double)

///|
fn Canvas::at(self : Canvas, point : Point) -> Point {
  (self.ox + point.0 * self.scale, self.oy - point.1 * self.scale)
}

///|
fn Canvas::segment(self : Canvas, a : Point, b : Point) -> Unit {
  let (ax, ay) = self.at(a)
  let (bx, by) = self.at(b)
  self.items.push(
    Place(
      Line(
        start=(Pt(ax), Pt(ay)),
        end_=(Pt(bx), Pt(by)),
        stroke=Stroke(thickness=Pt(0.5)),
      ),
    ),
  )
}

///|
fn Canvas::circle(self : Canvas, centre : Point, radius : Double) -> Unit {
  let (cx, cy) = self.at(centre)
  let radius = radius * self.scale
  self.items.push(
    Place(
      Circle(radius=Pt(radius), stroke=Stroke(thickness=Pt(0.5))),
      dx=Pt(cx - radius),
      dy=Pt(cy - radius),
    ),
  )
}

///|
/// A letter at a point, moved by (`dx`, `dy`) points from being centred on
/// it.
fn Canvas::label(
  self : Canvas,
  point : Point,
  letter : String,
  dx : Double,
  dy : Double,
) -> Unit {
  let (x, y) = self.at(point)
  self.items.push(
    Place(
      Text(Equation(letter), size=Pt(8.5)),
      dx=Pt(x - 3.2 + dx),
      dy=Pt(y - 3.0 + dy),
    ),
  )
}

///|
fn Canvas::block(self : Canvas) -> Block {
  Block(
    Seq(self.items),
    width=Pt(self.width),
    height=Pt(self.height),
    breakable=false,
  )
}

///|
/// A numbered figure; the text refers to it with `Ref`.
fn figure(canvas : Canvas, label : String) -> Item {
  Narrow(
    Figure(
      canvas.block(),
      caption=Seq([]),
      supplement=Supplement("Fig."),
      numbering=Numbering("1"),
      label~,
    ),
  )
}

///|
/// A point between `a` and `b`: `a + t (b - a)`.
fn between(a : Point, b : Point, t : Double) -> Point {
  (a.0 + t * (b.0 - a.0), a.1 + t * (b.1 - a.1))
}

///|
fn distance(a : Point, b : Point) -> Double {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  (dx * dx + dy * dy).sqrt()
}
