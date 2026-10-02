// Port of `typst-layout/src/transforms.rs`.

///|
/// Layout the moved content.
pub fn layout_move(
  elem : @library.MoveElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let frame = layout_frame(engine, elem.body(), locator, styles, region)
  let delta = @library.Axes::new(
    elem.dx(styles).resolve(styles),
    elem.dy(styles).resolve(styles),
  )
  let delta = delta.relative_to(region.size)
  frame.translate_visual(delta.to_point())
  frame
}

///|
/// Layout the rotated content.
pub fn layout_rotate(
  elem : @library.RotateElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let angle = elem.angle(styles)
  let align = elem.origin(styles).resolve(styles)

  // Compute the new region's approximate size.
  let is_finite = region.size.is_finite_size()
  let size = if is_finite {
    compute_bounding_box(region.size, @library.Transform::rotate(-angle)).1
  } else {
    @library.Axes::splat(@library.Abs::inf())
  }
  measure_and_layout(
    engine,
    locator,
    region,
    size,
    styles,
    elem.body(),
    @library.Transform::rotate(angle),
    align,
    elem.reflow(styles),
    // TODO: Calculate new baseline after rotation
    false,
  )
}

///|
/// Layout the scaled content.
pub fn layout_scale(
  elem : @library.ScaleElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  // Compute the new region's approximate size.
  let scale = resolve_scale(
    elem,
    engine,
    locator.relayout(),
    region.size,
    styles,
  )
  let size = region.size
    .zip_map(scale, (r, s) => {
      if r.is_finite() {
        @library.Ratio::new(1.0 / s.get()).of(r)
      } else {
        r
      }
    })
    .map(@library.Abs::abs)
  measure_and_layout(
    engine,
    locator,
    region,
    size,
    styles,
    elem.body(),
    @library.Transform::scale(scale.x, scale.y),
    elem.origin(styles).resolve(styles),
    elem.reflow(styles),
    // TODO: Figure out where the baseline should go after a vertical flip.
    // Similar problem to >90deg rotation, as following the baseline would
    // lead text to go below the typical baseline. For now, simply do not
    // preserve the baseline if vertical scale is negative.
    scale.y.get() >= 0.0,
  )
}

///|
/// Resolves scale parameters, preserving aspect ratio if one of the scales
/// is set to `auto`.
fn resolve_scale(
  elem : @library.ScaleElem,
  engine : @library.Engine,
  locator : @library.Locator,
  container : @library.Axes[@library.Abs],
  styles : @library.StyleChain,
) -> @library.Axes[@library.Ratio] raise @library.SourceError {
  // The size of the body, laid out lazily (once).
  let mut size : Result[
    @library.Axes[@library.Abs],
    Array[@library.SourceDiagnostic],
  ]? = None
  let body_size = () => {
    match size {
      Some(result) => result
      None => {
        let pod = @library.LayoutRegion::new(
          container,
          @library.Axes::splat(false),
        )
        let result = try
          layout_frame(engine, elem.body(), locator, styles, pod)
        catch {
          @library.SourceError(errors) => Err(errors)
        } noraise {
          frame => Ok(frame.size())
        }
        size = Some(result)
        result
      }
    }
  }
  let resolve_axis = (
    axis : @library.Smart[@library.ScaleAmount],
    body : () -> @library.Abs raise @library.SourceError,
  ) => {
    match axis {
      Auto => @library.Smart::Auto
      Custom(amt) =>
        Custom(
          match amt {
            Ratio(ratio) => ratio
            Length(length) => {
              let length = length.resolve(styles)
              @library.Ratio::new(length.ratio_to(body()))
            }
          },
        )
    }
  }
  let x = resolve_axis(elem.x(styles), () => {
    match body_size() {
      Ok(size) => size.x
      Err(errors) => raise @library.SourceError(errors)
    }
  })
  let y = resolve_axis(elem.y(styles), () => {
    match body_size() {
      Ok(size) => size.y
      Err(errors) => raise @library.SourceError(errors)
    }
  })
  match (x, y) {
    (Auto, Auto) =>
      @library.bail_at(elem.pack().span(), "x and y cannot both be auto")
    (Custom(x), Custom(y)) => @library.Axes::new(x, y)
    (Auto, Custom(v)) | (Custom(v), Auto) => @library.Axes::splat(v)
  }
}

///|
/// Layout the skewed content.
pub fn layout_skew(
  elem : @library.SkewElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let ax = elem.ax(styles)
  let ay = elem.ay(styles)
  let align = elem.origin(styles).resolve(styles)

  // Compute the new region's approximate size.
  let size = if region.size.is_finite_size() {
    compute_bounding_box(region.size, @library.Transform::skew(ax, ay)).1
  } else {
    @library.Axes::splat(@library.Abs::inf())
  }
  measure_and_layout(
    engine,
    locator,
    region,
    size,
    styles,
    elem.body(),
    @library.Transform::skew(ax, ay),
    align,
    elem.reflow(styles),
    true,
  )
}

///|
/// Applies a transformation to a frame, reflowing the layout if necessary.
fn measure_and_layout(
  engine : @library.Engine,
  locator : @library.Locator,
  region : @library.LayoutRegion,
  size : @library.Axes[@library.Abs],
  styles : @library.StyleChain,
  body : @library.Content,
  transform : @library.Transform,
  align : @library.Axes[@library.FixedAlignment],
  reflow : Bool,
  keep_baseline : Bool,
) -> @library.Frame raise @library.SourceError {
  if reflow {
    // Measure the size of the body.
    let pod = @library.LayoutRegion::new(size, @library.Axes::splat(false))
    let frame = layout_frame(engine, body, locator.relayout(), styles, pod)

    // Actually perform the layout.
    let pod = @library.LayoutRegion::new(
      frame.size(),
      @library.Axes::splat(true),
    )
    let frame = layout_frame(engine, body, locator, styles, pod)
    let { x, y, } = align.zip_map(
      frame.size(),
      @library.FixedAlignment::position,
    )

    // Compute the transform.
    let ts = @library.Transform::translate(x, y)
      .pre_concat(transform)
      .pre_concat(@library.Transform::translate(-x, -y))

    // Compute a new baseline that goes through the transformed baseline
    // (when seen as a hypothetical line crossing the frame at the baseline
    // height). To do this, we use the height of one point at baseline height
    // after it undergoes transformation - in this case, the middle point.
    //
    // Note that, when only scaling, the chosen point doesn't matter as the
    // height of all transformed points at baseline height will be the same,
    // but, when skewing, this would ensure the new baseline will cross the
    // middle of the old baseline.
    //
    // For now, however, rotation with reflow, in particular, does not yet
    // preserve baselines as it's not yet clear that such a baseline change
    // would be an expected outcome of rotation. (For example, a 180-degree
    // rotation would cause the baseline to be above the text!)
    let new_baseline = if frame.has_baseline() && keep_baseline {
      Some(
        @library.Point::new(frame.width().div_by(2.0), frame.baseline()).transform(
          ts,
        ).y,
      )
    } else {
      None
    }

    // Compute the bounding box and offset and wrap in a new frame.
    let (offset, size) = compute_bounding_box(frame.size(), ts)
    frame.transform(ts)
    frame.translate_visual(offset)
    frame.set_size(size)
    if new_baseline is Some(new_baseline) {
      frame.set_baseline(new_baseline + offset.y)
    } else if !keep_baseline {
      // Post-transformation baseline is not clear.
      frame.clear_baseline()
    }
    frame
  } else {
    // Layout the body.
    let frame = layout_frame(engine, body, locator, styles, region)
    let { x, y, } = align.zip_map(
      frame.size(),
      @library.FixedAlignment::position,
    )

    // Compute the transform.
    let ts = @library.Transform::translate(x, y)
      .pre_concat(transform)
      .pre_concat(@library.Transform::translate(-x, -y))

    // Apply the transform.
    frame.transform(ts)
    frame
  }
}

///|
/// Computes the bounding box and offset of a transformed area.
fn compute_bounding_box(
  size : @library.Axes[@library.Abs],
  ts : @library.Transform,
) -> (@library.Point, @library.Axes[@library.Abs]) {
  let top_left = @library.Point::zero().transform_inf(ts)
  let top_right = @library.Point::with_x(size.x).transform_inf(ts)
  let bottom_left = @library.Point::with_y(size.y).transform_inf(ts)
  let bottom_right = size.to_point().transform_inf(ts)

  // We first compute the new bounding box of the rotated area.
  let min_x = top_left.x.min(top_right.x).min(bottom_left.x).min(bottom_right.x)
  let min_y = top_left.y.min(top_right.y).min(bottom_left.y).min(bottom_right.y)
  let max_x = top_left.x.max(top_right.x).max(bottom_left.x).max(bottom_right.x)
  let max_y = top_left.y.max(top_right.y).max(bottom_left.y).max(bottom_right.y)

  // Then we compute the new size of the area.
  let width = max_x - min_x
  let height = max_y - min_y
  (
    @library.Point::new(-min_x, -min_y),
    @library.Axes::new(width.abs(), height.abs()),
  )
}
