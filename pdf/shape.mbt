// Port of `typst-pdf/src/shape.rs`.

///|
fn handle_shape(
  fc : FrameContext,
  shape : @library.Shape,
  surface : @export.Surface,
  gc : GlobalContext,
  span : @syntax.Span,
  artifact_type : @library.Smart[@export.ArtifactType],
) -> Unit raise @library.SourceError {
  let started = tags_shape(gc, fc, surface, shape, artifact_type)
  surface.set_location(span.0)
  surface.push_transform(to_export_transform(fc.state().transform))
  if convert_geometry(shape.geometry) is Some(path) {
    let fill = match shape.fill {
      Some(paint) =>
        Some(
          convert_fill(
            gc,
            paint,
            shape.fill_rule,
            false,
            surface,
            fc.state(),
            Some(shape),
          ),
        )
      None => None
    }
    let stroke = match shape.stroke {
      Some(stroke) if to_f32(stroke.thickness) > 0.0 =>
        Some(
          convert_stroke(gc, stroke, false, surface, fc.state(), Some(shape)),
        )
      _ => None
    }
    // Otherwise, the exporter will by default fill with a black paint.
    if fill is Some(_) || stroke is Some(_) {
      surface.set_fill(fill)
      surface.set_stroke(stroke)
      surface.draw_path(path)
    }
  }
  surface.pop()
  surface.reset_location()
  if started {
    surface.end_tagged()
  }
}

///|
fn convert_geometry(geometry : @library.Geometry) -> @export.Path? {
  let path_builder = @export.PathBuilder::new()
  match geometry {
    Line(l) => {
      path_builder.move_to(0.0, 0.0)
      path_builder.line_to(to_f32(l.x), to_f32(l.y))
    }
    Rect(size) => {
      let w = to_f32(size.x)
      let h = to_f32(size.y)
      let rect = if w < 0.0 || h < 0.0 {
        // Typst supports negative dimensions, so we apply a transform if
        // needed.
        let ts = @export.Transform::from_scale(signum(w), signum(h))
        match @export.Rect::from_xywh(0.0, 0.0, w.abs(), h.abs()) {
          Some(r) => Some(r.transform(ts))
          None => None
        }
      } else {
        @export.Rect::from_xywh(0.0, 0.0, w, h)
      }
      if rect is Some(rect) {
        path_builder.push_rect(rect)
      }
    }
    Curve(c) => convert_path(c, path_builder)
  }
  path_builder.finish()
}

///|
/// Rust's `f32::signum`.
fn signum(v : Double) -> Double {
  if v.is_nan() {
    v
  } else if v < 0.0 || (v == 0.0 && 1.0 / v < 0.0) {
    -1.0
  } else {
    1.0
  }
}
