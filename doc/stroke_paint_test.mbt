// `Stroke::paint` (docs/edsl-ports.md, "As built (step 5)"): what a
// package of elements, to which a stroke is opaque, can ask of one.

///|
test "Stroke::paint: the paint that a stroke was made with" {
  // What Typst's `stroke(..).paint` is for a stroke with a paint, as it
  // was given.
  let name = (stroke : @doc.Stroke) => {
    match stroke.paint() {
      Some(Blue) => "blue"
      Some(Rgb(hex)) => "rgb \{hex}"
      Some(Auto) => "auto"
      Some(Value(_)) => "a value"
      Some(_) => "another paint"
      None => "none"
    }
  }
  inspect(name(@doc.Stroke(paint=Blue, thickness=Pt(2))), content="blue")
  inspect(name(@doc.Stroke(paint=Rgb("#abc"), dash=Dashed)), content="rgb #abc")
  // `auto` is no paint, however it is written.
  inspect(name(@doc.Stroke(paint=Auto)), content="none")
  inspect(name(@doc.Stroke(paint=Value(@doc.Value::auto()))), content="none")
  inspect(
    name(@doc.Stroke(paint=@doc.Paint::mix(Red, Blue))),
    content="a value",
  )
  // A stroke without a paint has none: it is drawn in the paint of the
  // stroke that it is folded with.
  inspect(name(@doc.Stroke(thickness=Pt(2))), content="none")
  inspect(name(@doc.Stroke()), content="none")
  inspect(name(@doc.Stroke::none()), content="none")
  inspect(name(@doc.Stroke::auto()), content="none")
}

///|
test "Stroke::paint: a shape that is filled with it is drawn in what the stroke draws" {
  let pen = @doc.Stroke(paint=@doc.Paint::mix(Red, Blue), thickness=Pt(2))
  let report = compile([
    @doc.Rect(width=Pt(20), height=Pt(10), stroke=@doc.Sides(all=pen)),
    @doc.Rect(width=Pt(20), height=Pt(10), fill=pen.paint().unwrap()),
  ])
  inspect(error_messages(report), content="")
  let strokes : Array[String] = []
  let fills : Array[String] = []
  fn walk(frame : @library.Frame) -> Unit {
    for entry in frame.items() {
      match entry.1 {
        Group(group) => walk(group.frame)
        Shape(shape, _) => {
          if shape.stroke is Some(stroke) {
            strokes.push(stroke.paint.repr())
          }
          if shape.fill is Some(fill) {
            fills.push(fill.repr())
          }
        }
        _ => ()
      }
    }
  }

  for page in report.unwrap().pages() {
    walk(page.frame)
  }
  assert_eq(strokes.length(), 1)
  assert_eq(fills, strokes)
}
