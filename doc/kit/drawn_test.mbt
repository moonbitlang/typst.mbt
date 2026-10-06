// What is on the pages of a compiled document, for the tests of `Chip` and
// `DataTable`: boxes, lines and text runs, with what they are drawn in.
// (`cards_test.mbt` has the page of the tests, `compile` and the helpers
// for origins.)

///|
/// Something that is drawn on a page.
priv struct Drawn {
  page : Int
  /// `"box"`: a filled or outlined shape, by the box around its outline;
  /// `"line"`: a straight line, `w` and `h` its end from its start;
  /// `"text"`: a text run, `y` its baseline, `w` its width, `h` its size.
  kind : String
  x : Double
  y : Double
  w : Double
  h : Double
  /// The text of a run, and the family of its font.
  text : String
  family : String
  /// The fill of a box or of a run, as Typst prints it (`""`: none).
  fill : String
  /// The stroke of a box or of a line: its thickness and its paint
  /// (`""`: none).
  stroke : String
}

///|
/// The box around the points of an outline, as `(left, top, right, bottom)`.
fn outline_box(
  geometry : @library.Geometry,
) -> (Double, Double, Double, Double)? {
  let mut left = 0.0
  let mut top = 0.0
  let mut right = 0.0
  let mut bottom = 0.0
  let mut first = true
  let point = (p : @library.Point) => {
    let (px, py) = (p.x.to_pt(), p.y.to_pt())
    if first {
      left = px
      right = px
      top = py
      bottom = py
      first = false
    } else {
      left = if px < left { px } else { left }
      right = if px > right { px } else { right }
      top = if py < top { py } else { top }
      bottom = if py > bottom { py } else { bottom }
    }
  }
  match geometry {
    Rect(size) => {
      point(@library.Point::zero())
      point(@library.Point::new(size.x, size.y))
    }
    Curve(curve) =>
      for item in curve.items() {
        match item {
          Move(p) | Line(p) => point(p)
          Cubic(p1, p2, p3) => {
            point(p1)
            point(p2)
            point(p3)
          }
          Close => ()
        }
      }
    Line(_) => return None
  }
  Some((left, top, right, bottom))
}

///|
/// What a frame at `(dx, dy)` draws. (The documents of these tests have no
/// scaled or rotated groups: a group is a translation.)
fn collect_drawn(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  page : Int,
  out : Array[Drawn],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    match entry.1 {
      Group(group) =>
        collect_drawn(
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
          fill: text.fill.repr(),
          stroke: "",
        })
      Shape(shape, _) => {
        let fill = match shape.fill {
          Some(paint) => paint.repr()
          None => ""
        }
        let stroke = match shape.stroke {
          Some(stroke) =>
            "\{pt(stroke.thickness.to_pt())} \{stroke.paint.repr()}"
          None => ""
        }
        match shape.geometry {
          Line(to) =>
            out.push({
              page,
              kind: "line",
              x,
              y,
              w: to.x.to_pt(),
              h: to.y.to_pt(),
              text: "",
              family: "",
              fill,
              stroke,
            })
          geometry => {
            guard outline_box(geometry) is Some((left, top, right, bottom)) else {
              continue
            }
            out.push({
              page,
              kind: "box",
              x: x + left,
              y: y + top,
              w: right - left,
              h: bottom - top,
              text: "",
              family: "",
              fill,
              stroke,
            })
          }
        }
      }
      _ => ()
    }
  }
}

///|
/// What a compiled document draws, page by page (pages from 1).
fn drawn(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[Drawn] raise {
  let out = []
  for i, page in report.unwrap().pages() {
    collect_drawn(page.frame, 0.0, 0.0, i + 1, out)
  }
  out
}

///|
/// What is drawn, of one kind.
fn of_kind(all : Array[Drawn], kind : String) -> Array[Drawn] {
  all.filter(d => d.kind == kind)
}

///|
/// A text as a string literal, a no-break space as `~`.
fn shown(text : String) -> String {
  text.escape().replace_all(old="\u{00A0}", new="~")
}

///|
/// A listing of what is drawn, one line each: the page, the kind and the
/// position; then the size, the fill and the stroke of a box, the extent
/// and the stroke of a line, or the size and the text of a run.
fn listing(all : Array[Drawn]) -> String {
  all
  .map(d => {
    let at = "p\{d.page} \{d.kind} \{pt(d.x)},\{pt(d.y)}"
    match d.kind {
      "text" => "\{at} \{pt(d.h)}pt \{shown(d.text)}"
      "line" => "\{at} \{pt(d.w)}x\{pt(d.h)} \{d.stroke}"
      _ => {
        let fill = if d.fill == "" { "" } else { " \{d.fill}" }
        let stroke = if d.stroke == "" { "" } else { " stroke \{d.stroke}" }
        "\{at} \{pt(d.w)}x\{pt(d.h)}\{fill}\{stroke}"
      }
    }
  })
  .join("\n")
}

///|
/// The text runs of a compiled document, one line each: the page, the
/// baseline and the text.
fn lines_of_text(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String raise {
  of_kind(drawn(report), "text")
  .map(d => "p\{d.page} \{pt(d.x)},\{pt(d.y)} \{shown(d.text)}")
  .join("\n")
}
