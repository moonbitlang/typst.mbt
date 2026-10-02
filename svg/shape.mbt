// Port of `typst-svg/src/shape.rs`: rendering of shapes and strokes.

///|
/// Render a shape element.
fn SVGRenderer::render_shape(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  shape : @library.Shape,
) -> Unit {
  let svg = svg.elem("path")
  if shape.fill is Some(paint) {
    self.write_fill(
      svg,
      paint,
      shape.fill_rule,
      self.shape_fill_size(state, paint, shape).aspect_ratio(),
      self.shape_paint_transform(state, paint, shape, false),
    )
  } else {
    svg.attr("fill", "none") |> ignore
  }
  if shape.stroke is Some(stroke) {
    self.write_stroke(
      svg,
      stroke,
      self.shape_fill_size(state, stroke.paint, shape).aspect_ratio(),
      self.shape_paint_transform(state, stroke.paint, shape, true),
    )
  }
  if !state.transform.is_identity() {
    svg.attr("transform", SvgTransform(state.transform)) |> ignore
  }
  let path = convert_geometry_to_path(shape.geometry)
  svg.attr("d", path).end()
}

///|
/// Calculate the transform of the shape's fill or stroke.
fn SVGRenderer::shape_paint_transform(
  _self : SVGRenderer,
  state : State,
  paint : @library.Paint,
  shape : @library.Shape,
  include_stroke_in_bbox : Bool,
) -> @library.Transform {
  // Only gradients and tilings depend on the bounding box.
  if paint is Solid(_) {
    return @library.Transform::identity()
  }
  let bbox = shape_bbox(shape, include_stroke_in_bbox)
  let mut offset = bbox.min
  let mut size = bbox.size()

  // Special handling for rectangles (mirrors gradients for negative sizes)
  if shape.geometry is Rect(rect) {
    if rect.x.signum() < 1.0 {
      offset = { ..offset, x: offset.x + size.x, }
      size = { ..size, x: size.x.times(-1.0), }
    }
    if rect.y.signum() < 1.0 {
      offset = { ..offset, y: offset.y + size.y, }
      size = { ..size, y: size.y.times(-1.0), }
    }
  }
  if size.x.is_zero() {
    size = { ..size, x: @library.Abs::pt(1.0), }
  }
  if size.y.is_zero() {
    size = { ..size, y: @library.Abs::pt(1.0), }
  }
  match paint {
    Gradient(gradient) =>
      match gradient.unwrap_relative(false) {
        Self_ =>
          @library.Transform::scale(
            @library.Ratio::new(size.x.to_pt()),
            @library.Ratio::new(size.y.to_pt()),
          ).post_concat(@library.Transform::translate(offset.x, offset.y))
        Parent =>
          @library.Transform::scale(
            @library.Ratio::new(state.size.x.to_pt()),
            @library.Ratio::new(state.size.y.to_pt()),
          ).post_concat(state.transform.invert().unwrap())
      }
    Tiling(tiling) =>
      match tiling.unwrap_relative(false) {
        Self_ => @library.Transform::identity()
        Parent => state.transform.invert().unwrap()
      }
    Solid(_) => @library.Transform::identity()
  }
}

///|
/// Calculate the size of the shape's fill.
fn SVGRenderer::shape_fill_size(
  _self : SVGRenderer,
  state : State,
  paint : @library.Paint,
  shape : @library.Shape,
) -> @library.Axes[@library.Abs] {
  // Only gradients use the aspect ratio derived from this size.
  guard paint is Gradient(gradient) else {
    return { x: @library.Abs::pt(1.0), y: @library.Abs::pt(1.0), }
  }
  let mut shape_size = shape_bbox(shape, true).size()
  // Edge cases for strokes.
  if shape_size.x.is_zero() {
    shape_size = { ..shape_size, x: @library.Abs::pt(1.0), }
  }
  if shape_size.y.is_zero() {
    shape_size = { ..shape_size, y: @library.Abs::pt(1.0), }
  }
  match gradient.unwrap_relative(false) {
    Self_ => shape_size
    Parent => state.size
  }
}

///|
/// Write a stroke attribute.
fn SVGRenderer::write_stroke(
  self : SVGRenderer,
  svg : SvgElem,
  stroke : @library.FixedStroke,
  aspect_ratio : @library.Ratio,
  fill_transform : @library.Transform,
) -> Unit {
  match stroke.paint {
    Solid(color) => svg.attr("stroke", color) |> ignore
    Gradient(gradient) => {
      let id = self.push_gradient(gradient, aspect_ratio, fill_transform)
      svg.attr("stroke", SvgUrl(id)) |> ignore
    }
    Tiling(tiling) => {
      let id = self.push_tiling(tiling, fill_transform)
      svg.attr("stroke", SvgUrl(id)) |> ignore
    }
  }
  svg.attr("stroke-width", stroke.thickness.to_pt()) |> ignore
  svg.attr(
    "stroke-linecap",
    match stroke.cap {
      Butt => "butt"
      Round => "round"
      Square => "square"
    },
  )
  |> ignore
  svg.attr(
    "stroke-linejoin",
    match stroke.join {
      Miter => "miter"
      Round => "round"
      Bevel => "bevel"
    },
  )
  |> ignore
  svg.attr("stroke-miterlimit", stroke.miter_limit.get()) |> ignore
  if stroke.dash is Some(dash) {
    svg.attr("stroke-dashoffset", dash.phase.to_pt()) |> ignore
    svg.attr_with("stroke-dasharray", attr => {
      attr.push_nums(dash.array.map(d => d.to_pt()))
    })
    |> ignore
  }
}

///|
/// Convert a geometry to an SVG path.
fn convert_geometry_to_path(geometry : @library.Geometry) -> String {
  let builder = SvgPathBuilder::with_translate(@library.Point::zero())
  match geometry {
    Line(t) => builder.line_to(t)
    Rect(size) => builder.rect(size)
    Curve(p) => return convert_curve(@library.Point::zero(), p)
  }
  builder.finsish()
}

///|
fn convert_curve(
  initial_point : @library.Point,
  curve : @library.Curve,
) -> String {
  let builder = SvgPathBuilder::with_translate(initial_point)
  for item in curve.items() {
    match item {
      Move(pos) => builder.move_to(pos)
      Line(pos) => builder.line_to(pos)
      Cubic(p1, p2, p3) => builder.curve_to(p1, p2, p3)
      Close => builder.close()
    }
  }
  builder.finsish()
}

///|
/// The bounding box of the shape, optionally taking the stroke into account
/// (upstream `Shape::bbox`).
pub fn shape_bbox(
  shape : @library.Shape,
  include_stroke : Bool,
) -> @library.Rect {
  geometry_bbox(
    shape.geometry,
    if include_stroke {
      shape.stroke
    } else {
      None
    },
  )
}

///|
/// The bounding box of the geometry, optionally taking the stroke width of
/// the shape into account (upstream `Geometry::bbox`).
fn geometry_bbox(
  geometry : @library.Geometry,
  stroke : @library.FixedStroke?,
) -> @library.Rect {
  let zero = @library.Point::zero()
  match geometry {
    Line(end) =>
      if stroke is Some(stroke) {
        // `bbox_of_stroked_line`: a single `LineTo` without dashes.
        let style = { ..kurbo_stroke_style(stroke), dash: None, }
        kurbo_rect_to_rect(
          kurbo_stroke_bbox([LineTo(point_to_kurbo(end))], style),
        )
      } else {
        @library.Rect::new(end.min(zero), end.max(zero))
      }
    Rect(size) => {
      let min = size.to_point().min(zero)
      let stroke_width = match stroke {
        Some(s) => s.thickness
        None => @library.Abs::zero()
      }
      @library.Rect::from_pos_size(
        min.map(i => i - stroke_width.times(0.5)),
        size.map(i => i.abs() + stroke_width),
      )
    }
    Curve(curve) => curve_bbox(curve, stroke)
  }
}

///|
/// Computes the bounding box of a curve (upstream `Curve::bbox`).
fn curve_bbox(
  curve : @library.Curve,
  stroke : @library.FixedStroke?,
) -> @library.Rect {
  let path = curve_to_kurbo(curve)
  let bbox = match stroke {
    Some(stroke) => kurbo_stroke_bbox(path, kurbo_stroke_style(stroke))
    None => bez_path_bbox(path)
  }
  kurbo_rect_to_rect(bbox)
}

///|
fn curve_to_kurbo(curve : @library.Curve) -> Array[PathEl] {
  curve
  .items()
  .map(item => {
    match item {
      Move(p) => MoveTo(point_to_kurbo(p))
      Line(p) => LineTo(point_to_kurbo(p))
      Cubic(p1, p2, p3) =>
        CurveTo(point_to_kurbo(p1), point_to_kurbo(p2), point_to_kurbo(p3))
      Close => ClosePath
    }
  })
}

///|
fn point_to_kurbo(point : @library.Point) -> KPoint {
  { x: point.x.to_raw(), y: point.y.to_raw(), }
}

///|
fn kurbo_rect_to_rect(r : KRect) -> @library.Rect {
  @library.Rect::new(
    { x: @library.Abs::raw(r.x0), y: @library.Abs::raw(r.y0), },
    { x: @library.Abs::raw(r.x1), y: @library.Abs::raw(r.y1), },
  )
}

///|
fn kurbo_stroke_style(stroke : @library.FixedStroke) -> KStroke {
  {
    width: stroke.thickness.to_raw(),
    cap: match stroke.cap {
      Butt => KButt
      Round => KRound
      Square => KSquare
    },
    join: match stroke.join {
      Miter => JMiter
      Round => JRound
      Bevel => JBevel
    },
    miter_limit: stroke.miter_limit.get(),
    dash: match stroke.dash {
      Some(dash) => Some((dash.phase.to_raw(), dash.array.map(d => d.to_raw())))
      None => None
    },
  }
}
