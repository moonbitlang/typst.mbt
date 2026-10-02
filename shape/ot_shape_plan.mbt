// Port of rustybuzz 0.20.1 `src/hb/ot_shape_plan.rs`.

///|
/// A reusable plan for shaping a text buffer.
struct ShapePlan {
  direction : Direction
  script : Script?
  shaper : OtShaper
  ot_map : OtMap
  mut data : ShaperData
  frac_mask : UInt
  numr_mask : UInt
  dnom_mask : UInt
  rtlm_mask : UInt
  kern_mask : UInt
  trak_mask : UInt
  requested_kerning : Bool
  has_frac : Bool
  has_vert : Bool
  has_gpos_mark : Bool
  zero_marks : Bool
  fallback_glyph_classes : Bool
  fallback_mark_positioning : Bool
  adjust_mark_positioning_when_zeroing : Bool
  apply_gpos : Bool
  apply_fallback_kern : Bool
  apply_kern : Bool
  apply_kerx : Bool
  apply_morx : Bool
  apply_trak : Bool
  user_features : Array[Feature]
}

///|
/// Returns a plan that can be used for shaping any buffer with the
/// provided properties.
pub fn ShapePlan::new(
  face : Face,
  direction : Direction,
  script : Script?,
  language : Language?,
  user_features : Array[Feature],
) -> ShapePlan {
  guard! direction != Invalid
  let planner = ShapePlanner::new(face, direction, script, language)
  planner.collect_features(user_features)
  planner.compile(user_features)
}

///|
/// The plan's direction.
pub fn ShapePlan::direction(self : ShapePlan) -> Direction {
  self.direction
}

///|
/// The plan's script.
pub fn ShapePlan::script(self : ShapePlan) -> Script? {
  self.script
}
