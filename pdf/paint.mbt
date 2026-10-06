// Port of `typst-pdf/src/paint.rs`: convert paint types from Typst to the
// exporter.

///|
fn convert_fill(
  gc : GlobalContext,
  paint_ : @library.Paint,
  fill_rule_ : @library.FillRule,
  on_text : Bool,
  surface : @export.Surface,
  state : State,
  shape : @library.Shape?,
) -> @export.Fill raise @library.SourceError {
  let (paint, opacity) = convert_paint(
    gc, paint_, on_text, surface, state, shape, false,
  )
  {
    paint,
    rule: to_export_fill_rule(fill_rule_),
    opacity: f32(opacity.to_double() / 255.0),
  }
}

///|
fn convert_stroke(
  gc : GlobalContext,
  stroke : @library.FixedStroke,
  on_text : Bool,
  surface : @export.Surface,
  state : State,
  shape : @library.Shape?,
) -> @export.Stroke raise @library.SourceError {
  let (paint, opacity) = convert_paint(
    gc,
    stroke.paint,
    on_text,
    surface,
    state,
    shape,
    true,
  )
  {
    paint,
    width: to_f32(stroke.thickness),
    miter_limit: f32(stroke.miter_limit.get()),
    line_join: to_export_line_join(stroke.join),
    line_cap: to_export_line_cap(stroke.cap),
    opacity: f32(opacity.to_double() / 255.0),
    dash: match stroke.dash {
      Some(dash) => Some(convert_dash(dash))
      None => None
    },
  }
}

///|
fn convert_paint(
  gc : GlobalContext,
  paint : @library.Paint,
  on_text : Bool,
  surface : @export.Surface,
  state : State,
  shape : @library.Shape?,
  include_stroke_in_bbox : Bool,
) -> (@export.Paint, Int) raise @library.SourceError {
  let (offset, size) = match shape {
    Some(s) => {
      let bbox = @svg.shape_bbox(s, include_stroke_in_bbox)
      let mut offset = bbox.min
      let mut size = bbox.size()
      // Special handling for rectangles (mirrors gradients for negative
      // sizes).
      if s.geometry is Rect(rect) {
        if rect.x.signum() < 1.0 {
          offset = { ..offset, x: offset.x + size.x, }
          size = { ..size, x: size.x.times(-1.0), }
        }
        if rect.y.signum() < 1.0 {
          offset = { ..offset, y: offset.y + size.y, }
          size = { ..size, y: size.y.times(-1.0), }
        }
      }
      (offset, size)
    }
    None =>
      (
        @library.Point::zero(),
        @library.Axes::new(@library.Abs::zero(), @library.Abs::zero()),
      )
  }
  let mut size = size
  if size.x.is_zero() {
    size = { ..size, x: @library.Abs::pt(1.0), }
  }
  if size.y.is_zero() {
    size = { ..size, y: @library.Abs::pt(1.0), }
  }
  match paint {
    Solid(c) => {
      let (c, a) = convert_solid(c)
      (Color(c), a)
    }
    Gradient(g) => (convert_gradient(g, on_text, state, size, offset), 255)
    Tiling(p) => convert_pattern(gc, p, on_text, surface, state)
  }
}

///|
fn convert_solid(color : @library.Color) -> (@export.Color, Int) {
  match color {
    Process(color) => {
      let (c, a) = convert_process_solid(color)
      (Regular(c), a)
    }
    Spot(color) => (convert_spot(color), 255)
  }
}

///|
fn convert_process_solid(
  color : @library.ProcessColor,
) -> (@export.RegularColor, Int) {
  match color.space() {
    D65Gray => {
      let c = color.to_space(D65Gray).to_vec4_u8()
      (Luma(c[0]), c[3])
    }
    Cmyk => {
      let c = color.to_space(Cmyk).to_vec4_u8()
      (Cmyk(c[0], c[1], c[2], c[3]), 255)
    }
    // Convert all other colors in different color spaces into RGB.
    _ => {
      let c = color.to_space(Srgb).to_vec4_u8()
      (Rgb(c[0], c[1], c[2]), c[3])
    }
  }
}

///|
fn convert_spot(color : @library.SpotColor) -> @export.Color {
  Separation((color.tint.get() * 255.0).round().to_int(), {
    colorant: spot_colorant_to_export(color.colorant.name),
    fallback: convert_process_solid(color.colorant.fallback).0,
  })
}

///|
/// The transform of a tiling (upstream `Tiling::transform`).
fn tiling_transform(tiling : @library.Tiling) -> @library.Transform {
  @library.Transform::translate(tiling.offset.x, tiling.offset.y).pre_concat(
    @library.Transform::rotate(tiling.angle),
  )
}

///|
fn convert_pattern(
  gc : GlobalContext,
  pattern : @library.Tiling,
  on_text : Bool,
  surface : @export.Surface,
  state : State,
) -> (@export.Paint, Int) raise @library.SourceError {
  let transform = correct_transform(state, pattern.unwrap_relative(on_text)).pre_concat(
    tiling_transform(pattern),
  )
  let sub = surface.stream_surface()
  tags_tiling(gc, sub, pattern.size, () => {
    let fc = FrameContext::new(None, pattern.frame.size())
    handle_frame(
      fc,
      pattern.frame,
      @library.Sides::splat(@library.Abs::zero()),
      None,
      sub,
      gc,
    )
  })
  let stream = sub.finish_stream()
  let pattern : @export.Pattern = {
    stream,
    transform: to_export_transform(transform),
    width: f32((pattern.size.x + pattern.spacing.x).to_pt()),
    height: f32((pattern.size.y + pattern.spacing.y).to_pt()),
  }
  (Pattern(pattern), 255)
}

///|
/// Corrects an angle for the aspect ratio of a gradient (upstream
/// `Gradient::correct_aspect_ratio`).
fn correct_aspect_ratio(
  angle : @library.Angle,
  aspect_ratio : @library.Ratio,
) -> @library.Angle {
  @library.Angle::atan2(angle.sin() / aspect_ratio.get().abs(), angle.cos()).normalized()
}

///|
fn gradient_angle(gradient : @library.Gradient) -> @library.Angle? {
  match gradient {
    Linear(l) => Some(l.angle)
    Conic(c) => Some(c.angle)
    Radial(_) => None
  }
}

///|
fn convert_gradient(
  gradient : @library.Gradient,
  on_text : Bool,
  state : State,
  size : @library.Axes[@library.Abs],
  offset : @library.Point,
) -> @export.Paint {
  let (size, offset) = match gradient.unwrap_relative(on_text) {
    Self_ => (size, offset)
    Parent => (state.container_size, @library.Point::zero())
  }
  let angle = gradient_angle(gradient).unwrap_or(@library.Angle::zero())
  let base_transform = correct_transform(
    state,
    gradient.unwrap_relative(on_text),
  )
  let stops = convert_gradient_stops(gradient)
  let anti_alias = gradient.anti_alias()
  let scaled = (ts : @library.Transform) => {
    ts
    .pre_concat(@library.Transform::translate(offset.x, offset.y))
    .pre_concat(
      @library.Transform::scale(
        @library.Ratio::new(to_f32(size.x)),
        @library.Ratio::new(to_f32(size.y)),
      ),
    )
  }
  match gradient {
    Linear(_) => {
      let angle = correct_aspect_ratio(angle, size.aspect_ratio())
      let (sin, cos) = (angle.sin(), angle.cos())
      // Scale to edges of unit square.
      let factor = cos.abs() + sin.abs()
      let (x1, y1) = match angle.quadrant() {
        First => (0.0, 0.0)
        Second => (1.0, 0.0)
        Third => (1.0, 1.0)
        Fourth => (0.0, 1.0)
      }
      let x2 = x1 + f32(cos * factor)
      let y2 = y1 + f32(sin * factor)
      LinearGradient({
        x1,
        y1,
        x2,
        y2,
        // x and y coordinates are normalized, so need to scale by the size.
        transform: to_export_transform(scaled(base_transform)),
        spread_method: Pad,
        stops,
        anti_alias,
      })
    }
    Radial(radial) =>
      RadialGradient({
        fx: f32(radial.focal_center.x.get()),
        fy: f32(radial.focal_center.y.get()),
        fr: f32(radial.focal_radius.get()),
        cx: f32(radial.center.x.get()),
        cy: f32(radial.center.y.get()),
        cr: f32(radial.radius.get()),
        transform: to_export_transform(scaled(base_transform)),
        spread_method: Pad,
        stops,
        anti_alias,
      })
    Conic(conic) => {
      // Correct the gradient's angle.
      let cx = f32(to_f32(size.x) * conic.center.x.get())
      let cy = f32(to_f32(size.y) * conic.center.y.get())
      let actual_transform = base_transform
        // Adjust for the angle.
        .pre_concat(
          @library.Transform::rotate_at(
            angle + @library.Angle::rad(@math.PI),
            @library.Abs::pt(cx),
            @library.Abs::pt(cy),
          ),
        )
        .pre_concat(@library.Transform::translate(offset.x, offset.y))
      SweepGradient({
        cx,
        cy,
        start_angle: 0.0,
        end_angle: 360.0,
        transform: to_export_transform(actual_transform),
        spread_method: Pad,
        stops,
        anti_alias,
      })
    }
  }
}

///|
fn convert_gradient_stops(gradient : @library.Gradient) -> Array[@export.Stop] {
  let stops = []
  let add_single = (color : @library.Color, offset : @library.Ratio) => {
    let (color, opacity) = convert_solid(color)
    stops.push(
      (
        {
          offset: f32(offset.get()),
          color,
          opacity: f32(opacity.to_double() / 255.0),
        } : @export.Stop),
    )
  }
  let gstops = gradient.stops_ref()
  match gradient {
    Linear(_) | Radial(_) => {
      if gstops.get(0) is Some((c, o)) {
        add_single(c, o)
      }
      // Create the individual gradient functions for each pair of stops.
      for i in 0..<(gstops.length() - 1) {
        let first = gstops[i]
        let second = gstops[i + 1]
        add_single(first.0, first.1)
        // If we have a hue index or are using Oklab, we will create several
        // stops in-between to make the gradient smoother without
        // interpolation issues with native color spaces.
        if second.1.get() > first.1.get() &&
          (
            gradient.space().hue_index() is Some(_) ||
            gradient.space() == Process(Oklab)
          ) {
          generate_intermediate_stops_for_rgb_interpolation(
            gradient,
            first,
            second,
            (c, at) => add_single(c, at),
          )
        }
      }
      if gstops.last() is Some((c, o)) {
        add_single(c, o)
      }
    }
    Conic(conic) => {
      if conic.stops.get(0) is Some((c, t)) {
        add_single(c, t)
      }
      for i in 0..<(conic.stops.length() - 1) {
        let (c0, t0) = conic.stops[i]
        let (c1, t1) = conic.stops[i + 1]
        // Precision:
        // - On an even color, insert a stop every 90deg.
        // - For a hue-based color space, insert 200 stops minimum.
        // - On any other, insert 20 stops minimum.
        let max_dt = if c0 == c1 {
          0.25
        } else if conic.space.hue_index() is Some(_) {
          0.005
        } else {
          0.05
        }
        let mut t_x = t0.get()
        let dt = @cmp.minimum(t1.get() - t0.get(), max_dt)
        // Special casing for sharp gradients.
        if t0 == t1 {
          add_single(c1, t1)
          continue
        }
        while t_x < t1.get() {
          let t_next = @cmp.minimum(t_x + dt, t1.get())
          // The current progress in the current window.
          let t = (t : Double) => (t - t0.get()) / (t1.get() - t0.get())
          let c_next = @library.Color::mix_iter(
            [
              @library.WeightedColor::new(c0, 1.0 - t(t_next)),
              @library.WeightedColor::new(c1, t(t_next)),
            ],
            Custom(conic.space),
          ) catch {
            _ => c1
          }
          add_single(c_next, @library.Ratio::new(t_next))
          t_x = t_next
        }
        add_single(c1, t1)
      }
    }
  }
  stops
}

///|
fn premultiply(c : @library.Rgb) -> (Float, Float, Float) {
  (c.red * c.alpha, c.green * c.alpha, c.blue * c.alpha)
}

///|
/// Generates additional stops to replicate a gradient in rgb color space
/// interpolation by bisecting (upstream
/// `Gradient::generate_intermediate_stops_for_rgb_interpolation`).
fn generate_intermediate_stops_for_rgb_interpolation(
  gradient : @library.Gradient,
  first : (@library.Color, @library.Ratio),
  second : (@library.Color, @library.Ratio),
  yield_ : (@library.Color, @library.Ratio) -> Unit,
) -> Unit {
  let threshold : Float = 0.001
  let max_subdivisions : UInt64 = 64
  let t0 = first.1.get()
  let dt = second.1.get() - t0
  let mut prev_color = first.0
  let mut next_stop = second.1
  let mut next_color = second.0
  let mut n : UInt64 = 1
  let mut i : UInt64 = 1
  while true {
    let mut intermediate_stop = None
    let euclidean_error = {
      let mid = @library.Ratio::new(
        t0 + dt * (i.to_double() - 0.5) / n.to_double(),
      )
      let exact = gradient.sample(Ratio(mid))
      let approx = @library.Color::mix_iter(
        [
          @library.WeightedColor::new(prev_color, 0.5),
          @library.WeightedColor::new(next_color, 0.5),
        ],
        Custom(Process(Srgb)),
      ) catch {
        _ => abort("mixing two colors in sRGB cannot fail")
      }
      let exact_color = premultiply(exact.to_rgb())
      let approx_color = premultiply(approx.to_rgb())
      let d0 = exact_color.0 - approx_color.0
      let d1 = exact_color.1 - approx_color.1
      let d2 = exact_color.2 - approx_color.2
      (d0 * d0 + d1 * d1 + d2 * d2).sqrt()
    }
    if n < max_subdivisions && euclidean_error > threshold {
      n = n * 2
      i = 2 * i - 1
    } else if i >= n {
      break
    } else {
      intermediate_stop = Some((next_color, next_stop))
      prev_color = next_color
      let shift = i.ctz()
      n = n >> shift
      i = i >> shift
      i = i + 1
    }
    next_stop = @library.Ratio::new(t0 + dt * i.to_double() / n.to_double())
    next_color = gradient.sample(Ratio(next_stop))
    if intermediate_stop is Some((c, s)) {
      yield_(c, s)
    }
  }
}

///|
fn convert_dash(dash : @library.FixedDashPattern) -> @export.StrokeDash {
  { array: dash.array.map(e => to_f32(e)), offset: to_f32(dash.phase), }
}

///|
fn correct_transform(
  state : State,
  relative : @library.RelativeTo,
) -> @library.Transform {
  // If we have a shape with a transform and a complex paint, then the paint
  // will inherit the transform of the shape.
  match relative {
    // Because of the above, we don't need to apply an additional transform
    // here.
    Self_ => @library.Transform::identity()
    // Because of the above, we need to first reverse the transform that will
    // be applied from the shape, and then re-apply the transform that is
    // used for the next parent container.
    Parent =>
      state.transform.invert().unwrap().pre_concat(state.container_transform)
  }
}
