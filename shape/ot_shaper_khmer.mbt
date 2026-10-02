// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_khmer.rs`.

///|
let khmer_shaper : OtShaper = {
  name: "khmer",
  collect_features: Some(collect_features_khmer),
  override_features: Some(override_features_khmer),
  create_data: Some(plan => Khmer(KhmerShapePlan::new(plan))),
  preprocess_text: None,
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT,
  decompose: Some(decompose_khmer),
  compose: Some(compose_khmer),
  setup_masks: Some(setup_masks_khmer),
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE,
  fallback_position: false,
}

///|
let khmer_features : FixedArray[(@otf.Tag, Int)] = [
  // Basic features.
  // These features are applied all at once, before reordering, constrained
  // to the syllable.
  (tag("pref"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("blwf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("abvf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("pstf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("cfar"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  // Other features.
  // These features are applied all at once after clearing syllables.
  (tag("pres"), F_GLOBAL_MANUAL_JOINERS),
  (tag("abvs"), F_GLOBAL_MANUAL_JOINERS),
  (tag("blws"), F_GLOBAL_MANUAL_JOINERS),
  (tag("psts"), F_GLOBAL_MANUAL_JOINERS),
]

// `khmer_feature`: must be in the same order as the KHMER_FEATURES array.

///|
const KHMER_PREF : Int = 0

///|
const KHMER_BLWF : Int = 1

///|
const KHMER_ABVF : Int = 2

///|
const KHMER_PSTF : Int = 3

///|
const KHMER_CFAR : Int = 4

///|
fn GlyphInfo::set_khmer_properties(self : GlyphInfo) -> Unit {
  let u = self.glyph_id.reinterpret_as_int()
  let (cat, _) = get_categories(u)
  self.set_indic_category(cat)
}

///|
priv struct KhmerShapePlan {
  mask_array : FixedArray[UInt]
}

///|
fn KhmerShapePlan::new(plan : ShapePlan) -> KhmerShapePlan {
  let mask_array = FixedArray::make(khmer_features.length(), 0U)
  for i, feature in khmer_features {
    mask_array[i] = if (feature.1 & F_GLOBAL) != 0 {
      0
    } else {
      plan.ot_map.get_1_mask(feature.0)
    }
  }
  { mask_array, }
}

///|
fn collect_features_khmer(planner : ShapePlanner) -> Unit {
  // Do this before any lookups have been applied.
  planner.ot_map.add_gsub_pause(Some(setup_syllables_khmer))
  planner.ot_map.add_gsub_pause(Some(reorder_khmer))

  // Testing suggests that Uniscribe does NOT pause between basic
  // features.  Test with KhmerUI.ttf and the following three
  // sequences:
  //
  //   U+1789,U+17BC
  //   U+1789,U+17D2,U+1789
  //   U+1789,U+17D2,U+1789,U+17BC
  //
  // https://github.com/harfbuzz/harfbuzz/issues/974
  planner.ot_map.enable_feature(tag("locl"), F_PER_SYLLABLE, 1)
  planner.ot_map.enable_feature(tag("ccmp"), F_PER_SYLLABLE, 1)
  for i in 0..<5 {
    let feature = khmer_features[i]
    planner.ot_map.add_feature(feature.0, feature.1, 1)
  }

  // https://github.com/harfbuzz/harfbuzz/issues/3531
  planner.ot_map.add_gsub_pause(Some(syllabic_clear_var)) // Don't need syllables anymore.
  for i in 5..<khmer_features.length() {
    let feature = khmer_features[i]
    planner.ot_map.add_feature(feature.0, feature.1, 1)
  }
}

///|
fn setup_syllables_khmer(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Bool {
  find_syllables_khmer(buffer)
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
fn reorder_khmer(plan : ShapePlan, face : Face, buffer : Buffer) -> Bool {
  let mut ret = false
  if insert_dotted_circles(
      face,
      buffer,
      KhmerSyllableType::BrokenCluster.to_int(),
      OT_DOTTEDCIRCLE,
      Some(OT_Repha),
      None,
    ) {
    ret = true
  }
  let khmer_plan = match plan.data {
    Khmer(d) => d
    _ => abort("khmer shaper data expected")
  }
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    reorder_syllable_khmer(khmer_plan, start, end, buffer)
    start = end
    end = buffer.next_syllable(start)
  }
  ret
}

///|
fn reorder_syllable_khmer(
  khmer_plan : KhmerShapePlan,
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  let syllable_type : KhmerSyllableType = match
    buffer.info[start].syllable() & 0x0F {
    0 => ConsonantSyllable
    1 => BrokenCluster
    2 => NonKhmerCluster
    _ => abort("unreachable")
  }
  match syllable_type {
    ConsonantSyllable | BrokenCluster =>
      reorder_consonant_syllable_khmer(khmer_plan, start, end, buffer)
    NonKhmerCluster => ()
  }
}

///|
/// Rules from:
/// https://docs.microsoft.com/en-us/typography/script-development/devanagari
fn reorder_consonant_syllable_khmer(
  plan : KhmerShapePlan,
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  // Setup masks.
  // Post-base
  {
    let mask = plan.mask_array[KHMER_BLWF] |
      plan.mask_array[KHMER_ABVF] |
      plan.mask_array[KHMER_PSTF]
    for i in (start + 1)..<end {
      let info = buffer.info[i]
      info.mask = info.mask | mask
    }
  }
  let mut num_coengs = 0
  for i in (start + 1)..<end {
    // When a COENG + (Cons | IndV) combination are found (and subscript count
    // is less than two) the character combination is handled according to the
    // subscript type of the character following the COENG.
    //
    // ...
    //
    // Subscript Type 2 - The COENG + RO characters are reordered to immediately
    // before the base glyph. Then the COENG + RO characters are assigned to have
    // the 'pref' OpenType feature applied to them.
    if buffer.info[i].indic_category() == OT_H && num_coengs <= 2 && i + 1 < end {
      num_coengs += 1
      if buffer.info[i + 1].indic_category() == OT_Ra {
        for j in 0..<2 {
          buffer.info[i + j].mask = buffer.info[i + j].mask |
            plan.mask_array[KHMER_PREF]
        }

        // Move the Coeng,Ro sequence to the start.
        buffer.merge_clusters(start, i + 2)
        let t0 = buffer.info[i]
        let t1 = buffer.info[i + 1]
        for k = i - start - 1; k >= 0; k = k - 1 {
          buffer.info[k + start + 2] = buffer.info[k + start]
        }
        buffer.info[start] = t0
        buffer.info[start + 1] = t1

        // Mark the subsequent stuff with 'cfar'.  Used in Khmer.
        // Read the feature spec.
        // This allows distinguishing the following cases with MS Khmer fonts:
        // U+1784,U+17D2,U+179A,U+17D2,U+1782
        // U+1784,U+17D2,U+1782,U+17D2,U+179A
        if plan.mask_array[KHMER_CFAR] != 0 {
          for j in (i + 2)..<end {
            buffer.info[j].mask = buffer.info[j].mask |
              plan.mask_array[KHMER_CFAR]
          }
        }
        num_coengs = 2 // Done.
      }
    } else if buffer.info[i].indic_category() == OT_VPre {
      // Reorder left matra piece.

      // Move to the start.
      buffer.merge_clusters(start, i + 1)
      let t = buffer.info[i]
      for k = i - start - 1; k >= 0; k = k - 1 {
        buffer.info[k + start + 1] = buffer.info[k + start]
      }
      buffer.info[start] = t
    }
  }
}

///|
fn override_features_khmer(planner : ShapePlanner) -> Unit {
  // Khmer spec has 'clig' as part of required shaping features:
  // "Apply feature 'clig' to form ligatures that are desired for
  // typographical correctness.", hence in overrides...
  planner.ot_map.enable_feature(tag("clig"), F_NONE, 1)
  planner.ot_map.disable_feature(tag("liga"))
}

///|
fn decompose_khmer(_ctx : NormalizeContext, ab : Int) -> (Int, Int)? {
  // Decompose split matras that don't have Unicode decompositions.
  match ab {
    0x17BE | 0x17BF | 0x17C0 | 0x17C4 | 0x17C5 => Some((0x17C1, ab))
    _ => decompose(ab)
  }
}

///|
fn compose_khmer(_ctx : NormalizeContext, a : Int, b : Int) -> Int? {
  // Avoid recomposing split matras.
  if gc_is_mark(char_general_category(a)) {
    return None
  }
  compose(a, b)
}

///|
fn setup_masks_khmer(_plan : ShapePlan, _face : Face, buffer : Buffer) -> Unit {
  // We cannot setup masks here.  We save information about characters
  // and setup masks later on in a pause-callback.
  for i in 0..<buffer.len {
    buffer.info[i].set_khmer_properties()
  }
}
