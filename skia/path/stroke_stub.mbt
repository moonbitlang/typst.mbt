// TEMPORARY: replaced by stroker.mbt / dash.mbt (p4-render-stroke).

///|
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Eq, Debug)

///|
pub impl Default for LineCap with fn default() {
  Butt
}

///|
pub(all) enum LineJoin {
  Miter
  MiterClip
  Round
  Bevel
} derive(Eq, Debug)

///|
pub impl Default for LineJoin with fn default() {
  Miter
}

///|
pub struct StrokeDash {
  array : Array[Float]
  offset : Float
}

///|
pub fn StrokeDash::new(
  dash_array : Array[Float],
  offset : Float,
) -> StrokeDash? {
  Some({ array: dash_array, offset, })
}

///|
pub(all) struct Stroke {
  width : Float
  miter_limit : Float
  line_cap : LineCap
  line_join : LineJoin
  dash : StrokeDash?
}

///|
pub impl Default for Stroke with fn default() {
  {
    width: 1.0,
    miter_limit: 4.0,
    line_cap: Butt,
    line_join: Miter,
    dash: None,
  }
}

///|
pub struct PathStroker {}

///|
pub fn PathStroker::compute_resolution_scale(ts : Transform) -> Float {
  ignore(ts)
  1.0
}

///|
pub fn Path::stroke(self : Path, stroke : Stroke, res_scale : Float) -> Path? {
  ignore((self, stroke, res_scale))
  None
}

///|
pub fn Path::dash(self : Path, dash : StrokeDash, res_scale : Float) -> Path? {
  ignore((self, dash, res_scale))
  None
}
