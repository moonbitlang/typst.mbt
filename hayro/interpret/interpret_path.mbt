// Port of `hayro-interpret/src/interpret/path.rs`.

///|
fn fill_path(context : Context, device : &Device, fill_rule : FillRule) -> Unit {
  fill_path_impl(context, device, fill_rule, None)
  context.path.truncate(0)
}

///|
fn stroke_path(context : Context, device : &Device) -> Unit {
  stroke_path_impl(context, device, None)
  context.path.truncate(0)
}

///|
fn fill_stroke_path(
  context : Context,
  device : &Device,
  fill_rule : FillRule,
) -> Unit {
  fill_path_impl(context, device, fill_rule, None)
  stroke_path_impl(context, device, None)
  context.path.truncate(0)
}

///|
fn close_path(context : Context) -> Unit {
  // This is necessary to prevent artifacts (see for example issue 157),
  // but it does cause some weird lines (maybe conflation artifacts) in
  // pdftc_900k_0907.
  if !(context.path.elements().last() is Some(ClosePath)) &&
    !context.path.is_empty() {
    context.path.close_path()
    context.last_point = context.sub_path_start
  }
}

///|
fn fill_path_impl(
  context : Context,
  device : &Device,
  fill_rule : FillRule,
  path : @kurbo.BezPath?,
) -> Unit {
  if !context.ocg_state.is_visible() {
    return
  }
  let props = context.draw_props(false)
  let draw = (path : @kurbo.BezPath) => {
    // pdf.js issue 4260: Replace zero-sized paths with a small stroke instead.
    let bbox = fast_bounding_box(path)
    match
      (
        f32_is_nearly_zero(bbox.width().to_float()),
        f32_is_nearly_zero(bbox.height().to_float()),
      ) {
      (false, false) => {
        let draw_mode = DrawMode::Fill(fill_rule)
        if path_as_rect(path) is Some(rect) {
          device.draw_rect(rect, props, draw_mode)
        } else {
          device.draw_path(path, props, draw_mode)
        }
      }
      _ => {
        let path = @kurbo.BezPath::new()
        path.move_to(@kurbo.Point::new(bbox.x0, bbox.y0))
        path.line_to(@kurbo.Point::new(bbox.x1, bbox.y1))
        let stroke_props = {
          ..StrokeProps::default(),
          // TODO: Make dependent on transform?
          line_width: 0.001,
          line_join: Bevel,
          line_cap: Butt,
        }
        device.draw_path(path, props, Stroke(stroke_props))
      }
    }
  }
  match path {
    None => draw(context.path)
    Some(path) => draw(path)
  }
}

///|
fn stroke_path_impl(
  context : Context,
  device : &Device,
  path : @kurbo.BezPath?,
) -> Unit {
  if !context.ocg_state.is_visible() {
    return
  }
  let stroke_props = context.stroke_props()
  let props = context.draw_props(true)
  let path = path.unwrap_or(context.path)
  let draw_mode = DrawMode::Stroke(stroke_props)
  if path_as_rect(path) is Some(rect) {
    device.draw_rect(rect, props, draw_mode)
  } else {
    device.draw_path(path, props, draw_mode)
  }
}
