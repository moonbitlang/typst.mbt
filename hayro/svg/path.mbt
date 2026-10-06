// Port of `hayro-svg/src/path.rs`.

///|
fn SvgRenderer::draw_path_impl(
  self : SvgRenderer,
  path : @kurbo.BezPath,
  props : @interpret.DrawProps,
  draw_mode : @interpret.DrawMode,
) -> Unit {
  let svg_path = to_svg_f32(path)
  self.xml.start_element("path")
  self.xml.write_attribute("d", svg_path)
  match draw_mode {
    Fill(f) => {
      if f == EvenOdd {
        self.xml.write_attribute("fill-rule", "evenodd")
      }
      self.write_paint(
        props.paint,
        () => path.bounding_box(),
        props.transform,
        None,
      )
    }
    Stroke(s) => {
      self.write_stroke_properties(s)
      self.write_paint(
        props.paint,
        () => path.bounding_box(),
        props.transform,
        Some(s),
      )
    }
    FillAndStroke(f, s) => {
      if f == EvenOdd {
        self.xml.write_attribute("fill-rule", "evenodd")
      }
      self.write_stroke_properties(s)
      self.write_fill_and_stroke_paint(
        props.paint,
        () => path.bounding_box(),
        props.transform,
        s,
      )
    }
    Invisible => {
      self.xml.end_element()
      return
    }
  }
  self.write_transform(props.transform)
  self.xml.end_element()
}

///|
fn SvgRenderer::draw_rect_impl(
  self : SvgRenderer,
  rect : @kurbo.Rect,
  props : @interpret.DrawProps,
  draw_mode : @interpret.DrawMode,
) -> Unit {
  self.xml.start_element("rect")
  self.xml.write_attribute("x", f64_str(rect.x0))
  self.xml.write_attribute("y", f64_str(rect.y0))
  self.xml.write_attribute("width", f64_str(rect.width()))
  self.xml.write_attribute("height", f64_str(rect.height()))
  match draw_mode {
    Fill(_) => self.write_paint(props.paint, () => rect, props.transform, None)
    Stroke(s) => {
      self.write_stroke_properties(s)
      self.write_paint(props.paint, () => rect, props.transform, Some(s))
    }
    FillAndStroke(_, s) => {
      self.write_stroke_properties(s)
      self.write_fill_and_stroke_paint(
        props.paint,
        () => rect,
        props.transform,
        s,
      )
    }
    Invisible => {
      self.xml.end_element()
      return
    }
  }
  self.write_transform(props.transform)
  self.xml.end_element()
}

///|
/// Write the SVG representation of this path with `f32` precision
/// (`BezPathExt::to_svg_f32`).
fn to_svg_f32(path : @kurbo.BezPath) -> String {
  let buf = StringBuilder()
  let p = (x : Double) => f32_str(Float::from_double(x))
  for i, el in path.elements() {
    if i > 0 {
      buf.write_char(' ')
    }
    match el {
      MoveTo(pt) => buf.write_string("M\{p(pt.x)},\{p(pt.y)}")
      LineTo(pt) => buf.write_string("L\{p(pt.x)},\{p(pt.y)}")
      QuadTo(p1, p2) =>
        buf.write_string("Q\{p(p1.x)},\{p(p1.y)} \{p(p2.x)},\{p(p2.y)}")
      CurveTo(p1, p2, p3) =>
        buf.write_string(
          "C\{p(p1.x)},\{p(p1.y)} \{p(p2.x)},\{p(p2.y)} \{p(p3.x)},\{p(p3.y)}",
        )
      ClosePath => buf.write_string("Z")
    }
  }
  buf.to_string()
}
