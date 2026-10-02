// Stroke expansion (`vello_common::flatten::expand_stroke`).
// TEMPORARY shim until `kurbo` gains `stroke_with`.

///|
/// A stroke style (`kurbo::Stroke`).
pub(all) struct StrokeStyle {
  width : Double
  join : @kurbo.Join
  miter_limit : Double
  start_cap : @kurbo.Cap
  end_cap : @kurbo.Cap
  dash_pattern : Array[Double]
  dash_offset : Double
}

///|
/// Expand a stroked path to a filled path.
fn expand_stroke(
  _path : Array[@kurbo.PathEl],
  _style : StrokeStyle,
  _tolerance : Double,
) -> Array[@kurbo.PathEl] {
  []
}
