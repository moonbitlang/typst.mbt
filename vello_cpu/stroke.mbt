// Stroke expansion (`vello_common::flatten::expand_stroke`).

///|
/// Expand a stroked path to a filled path.
fn expand_stroke(
  path : Array[@kurbo.PathEl],
  style : @kurbo.Stroke,
  tolerance : Double,
  stroke_ctx : @kurbo.StrokeCtx,
) -> Array[@kurbo.PathEl] {
  @kurbo.stroke_with(
    path.iter(),
    style,
    @kurbo.StrokeOpts::default(),
    tolerance,
    stroke_ctx,
  )
  stroke_ctx.output().elements()
}
