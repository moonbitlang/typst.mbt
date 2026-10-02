// Port of `usvg` 0.47.0 `src/parser/shapes.rs`: basic shapes to paths.

///|
fn shapes_convert(node : SvgNode, state : State) -> TinyPath? {
  guard node.tag_name() is Some(tag) else { return None }
  match tag {
    EId::Rect => convert_rect(node, state)
    EId::Circle => convert_circle(node, state)
    EId::Ellipse => convert_ellipse(node, state)
    EId::Line => convert_line(node, state)
    EId::Polyline => convert_polyline(node)
    EId::Polygon => convert_polygon(node)
    EId::Path => convert_path_data(node)
    _ => None
  }
}

///|
fn convert_path_data(node : SvgNode) -> TinyPath? {
  guard (node.attribute(AId::D) : String?) is Some(value) else { return None }
  let builder = @tiny_skia_path.PathBuilder::new()
  let parser = @svgtypes.SimplifyingPathParser::from(value)
  while parser.next() is Some(segment) {
    let segment = match segment {
      Ok(v) => v
      Err(_) => break
    }
    match segment {
      MoveTo(x~, y~) => builder.move_to(x.to_float(), y.to_float())
      LineTo(x~, y~) => builder.line_to(x.to_float(), y.to_float())
      Quadratic(x1~, y1~, x~, y~) =>
        builder.quad_to(
          x1.to_float(),
          y1.to_float(),
          x.to_float(),
          y.to_float(),
        )
      CurveTo(x1~, y1~, x2~, y2~, x~, y~) =>
        builder.cubic_to(
          x1.to_float(),
          y1.to_float(),
          x2.to_float(),
          y2.to_float(),
          x.to_float(),
          y.to_float(),
        )
      ClosePath => builder.close()
    }
  }
  builder.finish()
}

///|
fn convert_rect(node : SvgNode, state : State) -> TinyPath? {
  // 'width' and 'height' attributes must be positive and non-zero.
  let width = node.convert_user_length(
    AId::Width,
    state,
    @svgtypes.Length::zero(),
  )
  let height = node.convert_user_length(
    AId::Height,
    state,
    @svgtypes.Length::zero(),
  )
  if !is_valid_length(width) {
    // Upstream warns: Rect '{}' has an invalid 'width' value. Skipped.
    return None
  }
  if !is_valid_length(height) {
    // Upstream warns: Rect '{}' has an invalid 'height' value. Skipped.
    return None
  }
  let x = node.convert_user_length(AId::X, state, @svgtypes.Length::zero())
  let y = node.convert_user_length(AId::Y, state, @svgtypes.Length::zero())
  let (rx, ry) = resolve_rx_ry(node, state)
  let mut rx = rx
  let mut ry = ry

  // Clamp rx/ry to the half of the width/height.
  //
  // Should be done only after resolving.
  if rx > width / 2.0 {
    rx = width / 2.0
  }
  if ry > height / 2.0 {
    ry = height / 2.0
  }

  // Conversion according to https://www.w3.org/TR/SVG11/shapes.html#RectElement
  let path = if approx_eq_ulps(rx, 0.0, 4) {
    guard Rect::from_xywh(x, y, width, height) is Some(r) else { return None }
    @tiny_skia_path.PathBuilder::from_rect(r)
  } else {
    let builder = @tiny_skia_path.PathBuilder::new()
    builder.move_to(x + rx, y)
    builder.line_to(x + width - rx, y)
    builder.arc_to(rx, ry, 0.0, false, true, x + width, y + ry)
    builder.line_to(x + width, y + height - ry)
    builder.arc_to(rx, ry, 0.0, false, true, x + width - rx, y + height)
    builder.line_to(x + rx, y + height)
    builder.arc_to(rx, ry, 0.0, false, true, x, y + height - ry)
    builder.line_to(x, y + ry)
    builder.arc_to(rx, ry, 0.0, false, true, x + rx, y)
    builder.close()
    guard builder.finish() is Some(path) else { return None }
    path
  }
  Some(path)
}

///|
fn resolve_rx_ry(node : SvgNode, state : State) -> (Float, Float) {
  let mut rx_opt : @svgtypes.Length? = node.attribute(AId::Rx)
  let mut ry_opt : @svgtypes.Length? = node.attribute(AId::Ry)

  // Remove negative values first.
  if rx_opt is Some(v) {
    if is_sign_negative_f64(v.number) {
      rx_opt = None
    }
  }
  if ry_opt is Some(v) {
    if is_sign_negative_f64(v.number) {
      ry_opt = None
    }
  }

  // Resolve.
  match (rx_opt, ry_opt) {
    (None, None) => (0.0, 0.0)
    (Some(rx), None) => {
      let rx = convert_user_length(rx, node, AId::Rx, state)
      (rx, rx)
    }
    (None, Some(ry)) => {
      let ry = convert_user_length(ry, node, AId::Ry, state)
      (ry, ry)
    }
    (Some(rx), Some(ry)) => {
      let rx = convert_user_length(rx, node, AId::Rx, state)
      let ry = convert_user_length(ry, node, AId::Ry, state)
      (rx, ry)
    }
  }
}

///|
fn convert_line(node : SvgNode, state : State) -> TinyPath? {
  let x1 = node.convert_user_length(AId::X1, state, @svgtypes.Length::zero())
  let y1 = node.convert_user_length(AId::Y1, state, @svgtypes.Length::zero())
  let x2 = node.convert_user_length(AId::X2, state, @svgtypes.Length::zero())
  let y2 = node.convert_user_length(AId::Y2, state, @svgtypes.Length::zero())
  let builder = @tiny_skia_path.PathBuilder::new()
  builder.move_to(x1, y1)
  builder.line_to(x2, y2)
  builder.finish()
}

///|
fn convert_polyline(node : SvgNode) -> TinyPath? {
  guard points_to_path(node, "Polyline") is Some(builder) else { return None }
  builder.finish()
}

///|
fn convert_polygon(node : SvgNode) -> TinyPath? {
  guard points_to_path(node, "Polygon") is Some(builder) else { return None }
  builder.close()
  builder.finish()
}

///|
fn points_to_path(
  node : SvgNode,
  _eid : String,
) -> @tiny_skia_path.PathBuilder? {
  let builder = @tiny_skia_path.PathBuilder::new()
  let text : String? = node.attribute(AId::Points)
  match text {
    Some(text) => {
      let parser = @svgtypes.PointsParser::from(text)
      while parser.next() is Some((x, y)) {
        if builder.is_empty() {
          builder.move_to(x.to_float(), y.to_float())
        } else {
          builder.line_to(x.to_float(), y.to_float())
        }
      }
    }
    _ =>
      // Upstream warns: {} '{}' has an invalid 'points' value. Skipped.
      return None
  }

  // 'polyline' and 'polygon' elements must contain at least 2 points.
  if builder.len() < 2 {
    // Upstream warns: {} '{}' has less than 2 points. Skipped.
    return None
  }
  Some(builder)
}

///|
fn convert_circle(node : SvgNode, state : State) -> TinyPath? {
  let cx = node.convert_user_length(AId::Cx, state, @svgtypes.Length::zero())
  let cy = node.convert_user_length(AId::Cy, state, @svgtypes.Length::zero())
  let r = node.convert_user_length(AId::R, state, @svgtypes.Length::zero())
  if !is_valid_length(r) {
    // Upstream warns: Circle '{}' has an invalid 'r' value. Skipped.
    return None
  }
  ellipse_to_path(cx, cy, r, r)
}

///|
fn convert_ellipse(node : SvgNode, state : State) -> TinyPath? {
  let cx = node.convert_user_length(AId::Cx, state, @svgtypes.Length::zero())
  let cy = node.convert_user_length(AId::Cy, state, @svgtypes.Length::zero())
  let (rx, ry) = resolve_rx_ry(node, state)
  if !is_valid_length(rx) {
    // Upstream warns: Ellipse '{}' has an invalid 'rx' value. Skipped.
    return None
  }
  if !is_valid_length(ry) {
    // Upstream warns: Ellipse '{}' has an invalid 'ry' value. Skipped.
    return None
  }
  ellipse_to_path(cx, cy, rx, ry)
}

///|
fn ellipse_to_path(cx : Float, cy : Float, rx : Float, ry : Float) -> TinyPath? {
  let builder = @tiny_skia_path.PathBuilder::new()
  builder.move_to(cx + rx, cy)
  builder.arc_to(rx, ry, 0.0, false, true, cx, cy + ry)
  builder.arc_to(rx, ry, 0.0, false, true, cx - rx, cy)
  builder.arc_to(rx, ry, 0.0, false, true, cx, cy - ry)
  builder.arc_to(rx, ry, 0.0, false, true, cx + rx, cy)
  builder.close()
  builder.finish()
}

///|
/// `PathBuilderExt::arc_to`.
fn @tiny_skia_path.PathBuilder::arc_to(
  self : @tiny_skia_path.PathBuilder,
  rx : Float,
  ry : Float,
  x_axis_rotation : Float,
  large_arc : Bool,
  sweep : Bool,
  x : Float,
  y : Float,
) -> Unit {
  let prev = match self.last_point() {
    Some(v) => v
    None => return
  }
  let svg_arc : KSvgArc = {
    from: { x: prev.x.to_double(), y: prev.y.to_double(), },
    to: { x: x.to_double(), y: y.to_double(), },
    radii: { x: rx.to_double(), y: ry.to_double(), },
    x_rotation: x_axis_rotation.to_double() * (@math.PI / 180.0),
    large_arc,
    sweep,
  }
  match KArc::from_svg_arc(svg_arc) {
    Some(arc) =>
      arc.to_cubic_beziers(0.1, (p1, p2, p) => {
        self.cubic_to(
          p1.x.to_float(),
          p1.y.to_float(),
          p2.x.to_float(),
          p2.y.to_float(),
          p.x.to_float(),
          p.y.to_float(),
        )
      })
    None => self.line_to(x, y)
  }
}
