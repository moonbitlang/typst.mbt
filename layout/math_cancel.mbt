// Port of `typst-layout/src/math/cancel.rs`.

///|
/// Lays out a [`CancelItem`].
fn layout_cancel(
  item : @library.CancelItem,
  ctx : MathContext,
  styles : @library.StyleChain,
  props : @library.MathProperties,
) -> Unit raise @library.SourceError {
  let body = ctx.layout_into_fragment(item.base, styles)

  // Preserve properties of body.
  let body_text_like = body.is_text_like()
  let body_italics = body.italics_correction()
  let body_attach = body.accent_attach()
  let body = body.into_frame()
  let body_size = body.size()
  let first_line = draw_cancel_line(
    ctx.engine,
    item.length,
    item.stroke,
    item.invert_first_line,
    item.angle,
    body_size,
    styles,
    props.span,
  )

  // The origin of our line is the very middle of the element.
  let center = body_size.to_point().div_by(2.0)
  if item.background {
    body.prepend_frame(center, first_line)
  } else {
    body.push_frame(center, first_line)
  }
  if item.cross {
    // Draw the second line.
    let second_line = draw_cancel_line(
      ctx.engine,
      item.length,
      item.stroke,
      true,
      item.angle,
      body_size,
      styles,
      props.span,
    )
    if item.background {
      body.prepend_frame(center, second_line)
    } else {
      body.push_frame(center, second_line)
    }
  }
  ctx.push(
    Frame(
      FrameFragment::new(props, styles, body)
      .with_italics_correction(body_italics)
      .with_text_like(body_text_like)
      .with_accent_attach(body_attach),
    ),
  )
}

///|
/// Draws a cancel line.
fn draw_cancel_line(
  engine : @library.Engine,
  length_scale : @library.Rel[@library.Abs],
  stroke : @library.FixedStroke,
  invert : Bool,
  angle : @library.Smart[@library.CancelAngle],
  body_size : @library.Axes[@library.Abs],
  styles : @library.StyleChain,
  span : @syntax.Span,
) -> @library.Frame raise @library.SourceError {
  let default = default_angle(body_size)
  let mut angle = match angle {
    // Non specified angle defaults to the diagonal
    Auto => default
    Custom(angle) =>
      match angle {
        // This specifies the absolute angle w.r.t y-axis clockwise.
        Angle(v) => v
        // This specifies a function that takes the default angle as input.
        Func(func) => {
          let value = func.call_values(engine, @library.Context::new(styles~), [
            @library.IntoValue::into_value(default),
          ])
          @library.at(span, () => value.cast())
        }
      }
  }

  // invert means flipping along the y-axis
  if invert {
    angle = angle.times(-1.0)
  }

  // same as above, the default length is the diagonal of the body box.
  let default_length = body_size.to_point().hypot()
  let length = length_scale.relative_to(default_length)

  // Draw a vertical line of length and rotate it by angle
  let start = @library.Point::new(@library.Abs::zero(), length.div_by(2.0))
  let delta = @library.Point::new(@library.Abs::zero(), -length)
  let frame = @library.Frame::soft(body_size)
  frame.push(start, Shape(@library.Geometry::Line(delta).stroked(stroke), span))

  // Having the middle of the line at the origin is convenient here.
  frame.transform(@library.Transform::rotate(angle))
  frame
}

///|
/// The default line angle for a body of the given size.
fn default_angle(body : @library.Axes[@library.Abs]) -> @library.Angle {
  // The default cancel line is the diagonal.
  // We infer the default angle from
  // the diagonal w.r.t to the body box.
  //
  // The returned angle is in the range of [0, Pi/2]
  //
  // Note that the angle is computed w.r.t to the y-axis
  //
  //            B
  //           /|
  // diagonal / | height
  //         /  |
  //        /   |
  //       O ----
  //         width
  let (width, height) = (body.x, body.y)
  // arctangent (in the range [0, Pi/2])
  @library.Angle::atan(width.ratio_to(height))
}
