// TrueType hinting entry points (skrifa 0.42.1 `src/outline/glyf/hint`).
//
// TODO(p4-skrifa): the TrueType bytecode interpreter is not ported yet.
// `HintInstance::new` reports an error so that callers (hayro) fall back to
// unhinted outlines, as upstream does when creating the instance fails.

///|
priv struct HintInstance {
  enabled : Bool
}

///|
fn HintInstance::new(
  _glyf : GlyfOutlines,
  _scale : Int,
  _ppem : Int,
  _target : Target,
) -> HintInstance raise DrawError {
  raise HintingFailed("TrueType hinting is not supported")
}

///|
fn HintInstance::is_enabled(self : HintInstance) -> Bool {
  self.enabled
}

///|
fn FreeTypeScaler::hint_simple(
  _self : FreeTypeScaler,
  _hinter : HintInstance,
  _glyph_id : GlyphId,
  _ins : BytesView,
  _points_start : Int,
  _point_count : Int,
  _contours_start : Int,
  _contour_count : Int,
) -> Unit raise DrawError {
  ()
}

///|
fn FreeTypeScaler::hint_composite(
  _self : FreeTypeScaler,
  _hinter : HintInstance,
  _glyph_id : GlyphId,
  _ins : BytesView,
  _point_base : Int,
  _contour_base : Int,
) -> Unit raise DrawError {
  ()
}
