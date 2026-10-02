// Port of rustybuzz 0.20.1 `src/hb/aat_layout_common.rs`.

///|
/// `hb_aat_apply_context_t`
priv struct AatApplyContext {
  face : Face
  buffer : Buffer
  mut range_flags : Array[RangeFlags]?
  mut subtable_flags : UInt
}

///|
fn AatApplyContext::new(face : Face, buffer : Buffer) -> AatApplyContext {
  { face, buffer, range_flags: None, subtable_flags: 0, }
}
