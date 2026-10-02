// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_syllabic.rs`.

///|
fn insert_dotted_circles(
  face : Face,
  buffer : Buffer,
  broken_syllable_type : Int,
  dottedcircle_category : Int,
  repha_category : Int?,
  dottedcircle_position : Int?,
) -> Bool {
  if (buffer.flags & BUFFER_FLAG_DO_NOT_INSERT_DOTTED_CIRCLE) != 0 {
    return false
  }
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_BROKEN_SYLLABLE) == 0 {
    return false
  }
  let dottedcircle_glyph = match face.get_nominal_glyph(0x25CC) {
    Some(g) => g.0.to_uint()
    None => return false
  }
  let dottedcircle = GlyphInfo::new()
  dottedcircle.glyph_id = 0x25CC
  dottedcircle.set_ot_shaper_var_u8_category(dottedcircle_category)
  if dottedcircle_position is Some(dottedcircle_position) {
    dottedcircle.set_ot_shaper_var_u8_auxiliary(dottedcircle_position)
  }
  dottedcircle.glyph_id = dottedcircle_glyph
  buffer.clear_output()
  buffer.idx = 0
  let mut last_syllable = 0
  while buffer.idx < buffer.len {
    let syllable = buffer.cur(0).syllable()
    if last_syllable != syllable && (syllable & 0x0F) == broken_syllable_type {
      last_syllable = syllable
      let ginfo = dottedcircle.copy()
      ginfo.cluster = buffer.cur(0).cluster
      ginfo.mask = buffer.cur(0).mask
      ginfo.set_syllable(buffer.cur(0).syllable())

      // Insert dottedcircle after possible Repha.
      if repha_category is Some(repha_category) {
        while buffer.idx < buffer.len &&
              last_syllable == buffer.cur(0).syllable() &&
              buffer.cur(0).ot_shaper_var_u8_category() == repha_category {
          buffer.next_glyph()
        }
      }
      buffer.output_info(ginfo)
    } else {
      buffer.next_glyph()
    }
  }
  buffer.sync() |> ignore
  true
}
