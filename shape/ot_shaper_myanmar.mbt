// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_myanmar.rs`.

///|
let myanmar_shaper : OtShaper = {
  name: "myanmar",
  collect_features: Some(collect_features_myanmar),
  override_features: None,
  create_data: None,
  preprocess_text: None,
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT,
  decompose: None,
  compose: None,
  setup_masks: Some(setup_masks_myanmar),
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_EARLY,
  fallback_position: false,
}

///|
/// Ugly Zawgyi encoding.
/// Disable all auto processing.
/// https://github.com/harfbuzz/harfbuzz/issues/1162
let myanmar_zawgyi_shaper : OtShaper = {
  name: "myanmar_zawgyi",
  collect_features: None,
  override_features: None,
  create_data: None,
  preprocess_text: None,
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_NONE,
  decompose: None,
  compose: None,
  setup_masks: None,
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE,
  fallback_position: false,
}

///|
let myanmar_features : ReadOnlyArray[@otf.Tag] = [
  // Basic features.
  // These features are applied in order, one at a time, after reordering,
  // constrained to the syllable.
  tag("rphf"),
  tag("pref"),
  tag("blwf"),
  tag("pstf"),
  // Other features.
  // These features are applied all at once after clearing syllables.
  tag("pres"),
  tag("abvs"),
  tag("blws"),
  tag("psts"),
]

///|
fn GlyphInfo::set_myanmar_properties(self : GlyphInfo) -> Unit {
  let u = self.glyph_id.reinterpret_as_int()
  let (cat, _) = get_categories(u)
  self.set_myanmar_category(cat)
}

///|
fn collect_features_myanmar(planner : ShapePlanner) -> Unit {
  // Do this before any lookups have been applied.
  planner.ot_map.add_gsub_pause(Some(setup_syllables_myanmar))
  planner.ot_map.enable_feature(tag("locl"), F_PER_SYLLABLE, 1)
  // The Indic specs do not require ccmp, but we apply it here since if
  // there is a use of it, it's typically at the beginning.
  planner.ot_map.enable_feature(tag("ccmp"), F_PER_SYLLABLE, 1)
  planner.ot_map.add_gsub_pause(Some(reorder_myanmar))
  for i in 0..<4 {
    planner.ot_map.enable_feature(
      myanmar_features[i],
      F_MANUAL_ZWJ | F_PER_SYLLABLE,
      1,
    )
    planner.ot_map.add_gsub_pause(None)
  }
  planner.ot_map.add_gsub_pause(Some(syllabic_clear_var)) // Don't need syllables anymore.
  for i in 4..<myanmar_features.length() {
    planner.ot_map.enable_feature(myanmar_features[i], F_MANUAL_ZWJ, 1)
  }
}

///|
fn setup_syllables_myanmar(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Bool {
  find_syllables_myanmar(buffer)
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    buffer.unsafe_to_break(Some(start), Some(end))
    start = end
    end = buffer.next_syllable(start)
  }
  false
}

///|
fn reorder_myanmar(_plan : ShapePlan, face : Face, buffer : Buffer) -> Bool {
  let mut ret = false
  if insert_dotted_circles(
      face,
      buffer,
      MyanmarSyllableType::BrokenCluster.to_int(),
      OT_DOTTEDCIRCLE,
      None,
      None,
    ) {
    ret = true
  }
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    reorder_syllable_myanmar(start, end, buffer)
    start = end
    end = buffer.next_syllable(start)
  }
  ret
}

///|
fn reorder_syllable_myanmar(start : Int, end : Int, buffer : Buffer) -> Unit {
  let syllable_type : MyanmarSyllableType = match
    buffer.info[start].syllable() & 0x0F {
    0 => ConsonantSyllable
    1 => PunctuationCluster
    2 => BrokenCluster
    3 => NonMyanmarCluster
    _ => abort("unreachable")
  }
  match syllable_type {
    // We already inserted dotted-circles, so just call the consonant_syllable.
    ConsonantSyllable | BrokenCluster =>
      initial_reordering_consonant_syllable_myanmar(start, end, buffer)
    PunctuationCluster | NonMyanmarCluster => ()
  }
}

///|
/// Rules from:
/// https://docs.microsoft.com/en-us/typography/script-development/myanmar
fn initial_reordering_consonant_syllable_myanmar(
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  let mut base = end
  let mut has_reph = false
  {
    let mut limit = start
    if start + 3 <= end &&
      buffer.info[start + 0].myanmar_category() == OT_Ra &&
      buffer.info[start + 1].myanmar_category() == OT_As &&
      buffer.info[start + 2].myanmar_category() == OT_H {
      limit += 3
      base = start
      has_reph = true
    }
    if !has_reph {
      base = limit
    }
    for i in limit..<end {
      if buffer.info[i].is_consonant() {
        base = i
        break
      }
    }
  }

  // Reorder!
  {
    let mut i = start
    while i < start + (if has_reph { 3 } else { 0 }) {
      buffer.info[i].set_myanmar_position(POS_AFTER_MAIN)
      i += 1
    }
    while i < base {
      buffer.info[i].set_myanmar_position(POS_PRE_C)
      i += 1
    }
    if i < end {
      buffer.info[i].set_myanmar_position(POS_BASE_C)
      i += 1
    }
    let mut pos = POS_AFTER_MAIN
    // The following loop may be ugly, but it implements all of
    // Myanmar reordering!
    for i in i..<end {
      // Pre-base reordering
      if buffer.info[i].myanmar_category() == OT_MR {
        buffer.info[i].set_myanmar_position(POS_PRE_C)
        continue
      }

      // Left matra
      if buffer.info[i].myanmar_category() == OT_VPre {
        buffer.info[i].set_myanmar_position(POS_PRE_M)
        continue
      }
      if buffer.info[i].myanmar_category() == OT_VS {
        let t = buffer.info[i - 1].myanmar_position()
        buffer.info[i].set_myanmar_position(t)
        continue
      }
      if pos == POS_AFTER_MAIN && buffer.info[i].myanmar_category() == OT_VBlw {
        pos = POS_BELOW_C
        buffer.info[i].set_myanmar_position(pos)
        continue
      }
      if pos == POS_BELOW_C && buffer.info[i].myanmar_category() == OT_A {
        buffer.info[i].set_myanmar_position(POS_BEFORE_SUB)
        continue
      }
      if pos == POS_BELOW_C && buffer.info[i].myanmar_category() == OT_VBlw {
        buffer.info[i].set_myanmar_position(pos)
        continue
      }
      if pos == POS_BELOW_C && buffer.info[i].myanmar_category() != OT_A {
        pos = POS_AFTER_SUB
        buffer.info[i].set_myanmar_position(pos)
        continue
      }
      buffer.info[i].set_myanmar_position(pos)
    }
  }
  buffer.sort(start, end, (a, b) => a.myanmar_position() > b.myanmar_position())

  // Flip left-mantra sequence
  let mut first_left_matra = end
  let mut last_left_matra = end
  for i in start..<end {
    if buffer.info[i].myanmar_position() == POS_PRE_M {
      if first_left_matra == end {
        first_left_matra = i
      }
      last_left_matra = i
    }
  }

  // https://github.com/harfbuzz/harfbuzz/issues/3863
  if first_left_matra < last_left_matra {
    // No need to merge clusters, done already?
    buffer.reverse_range(first_left_matra, last_left_matra + 1)
    // Reverse back VS, etc.
    let mut i = first_left_matra
    for j in i..<=last_left_matra {
      if buffer.info[j].myanmar_category() == OT_VPre {
        buffer.reverse_range(i, j + 1)
        i = j + 1
      }
    }
  }
}

///|
fn setup_masks_myanmar(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Unit {
  // No masks, we just save information about characters.
  for i in 0..<buffer.len {
    buffer.info[i].set_myanmar_properties()
  }
}
