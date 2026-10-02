// TODO: the AAT layout (rustybuzz `aat_layout*.rs`: morx, kerx, trak, ankr)
// is not ported yet. None of the fonts of the Typst test world has AAT
// tables; these entry points do nothing.

///|
fn hb_aat_layout_remove_deleted_glyphs(_buffer : Buffer) -> Unit {

}

///|
fn hb_aat_layout_substitute(
  _plan : ShapePlan,
  _face : Face,
  _buffer : Buffer,
) -> Unit {

}

///|
fn hb_aat_layout_position(
  _plan : ShapePlan,
  _face : Face,
  _buffer : Buffer,
) -> Unit {

}

///|
fn hb_aat_layout_track(
  _plan : ShapePlan,
  _face : Face,
  _buffer : Buffer,
) -> Unit {

}

///|
fn hb_aat_layout_zero_width_deleted_glyphs(_buffer : Buffer) -> Unit {

}
