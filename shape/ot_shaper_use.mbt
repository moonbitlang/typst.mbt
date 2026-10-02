// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_use.rs`.

///|
let universal_shaper : OtShaper = {
  name: "universal",
  collect_features: Some(collect_features_use),
  override_features: None,
  create_data: Some(plan => Use(UniversalShapePlan::new(plan))),
  preprocess_text: Some(preprocess_text_use),
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT,
  decompose: None,
  compose: Some(compose_use),
  setup_masks: Some(setup_masks_use),
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_EARLY,
  fallback_position: false,
}

// `category` module.

///|
/// OTHER
const USE_O : Int = 0

///|
/// BASE
const USE_B : Int = 1

// pub const IND: u8     = 3;    // BASE_IND

///|
/// BASE_NUM
const USE_N : Int = 4

///|
/// BASE_OTHER
const USE_GB : Int = 5

///|
const USE_CGJ : Int = 6

// pub const CGJ: u8     = 6;    // CGJ
// pub const F: u8       = 7;    // CONS_FINAL
// pub const FM: u8 = 8;         // CONS_FINAL_MOD
// pub const M: u8       = 9;    // CONS_MED
// pub const CM: u8      = 10;   // CONS_MOD

///|
/// CONS_SUB
const USE_SUB : Int = 11

///|
/// HALANT
const USE_H : Int = 12

///|
/// HALANT_NUM
const USE_HN : Int = 13

///|
/// Zero width non-joiner
const USE_ZWNJ : Int = 14

// pub const ZWJ: u8     = 15;   // Zero width joiner

///|
/// Word joiner
const USE_WJ : Int = 16

///|
/// Reserved characters
const USE_RSV : Int = 17

///|
/// REPHA
const USE_R : Int = 18

///|
/// SYM
const USE_S : Int = 19

// pub const SM: u8      = 20;   // SYM_MOD
// pub const VS: u8      = 21;   // VARIATION_SELECTOR
// pub const V: u8       = 36;   // VOWEL
// pub const VM: u8      = 40;   // VOWEL_MOD

///|
/// CONS_WITH_STACKER
const USE_CS : Int = 43

///|
/// HALANT_OR_VOWEL_MODIFIER
///
/// https://github.com/harfbuzz/harfbuzz/issues/1102
const USE_IS : Int = 44

///|
/// SAKOT
const USE_Sk : Int = 48

///|
/// CONS_FINAL_ABOVE
const USE_FAbv : Int = 24

///|
/// CONS_FINAL_BELOW
const USE_FBlw : Int = 25

///|
/// CONS_FINAL_POST
const USE_FPst : Int = 26

///|
/// CONS_MED_ABOVE
const USE_MAbv : Int = 27

///|
/// CONS_MED_BELOW
const USE_MBlw : Int = 28

///|
/// CONS_MED_POST
const USE_MPst : Int = 29

///|
/// CONS_MED_PRE
const USE_MPre : Int = 30

///|
/// CONS_MOD_ABOVE
const USE_CMAbv : Int = 31

///|
/// CONS_MOD_BELOW
const USE_CMBlw : Int = 32

///|
/// VOWEL_ABOVE / VOWEL_ABOVE_BELOW / VOWEL_ABOVE_BELOW_POST / VOWEL_ABOVE_POST
const USE_VAbv : Int = 33

///|
/// VOWEL_BELOW / VOWEL_BELOW_POST
const USE_VBlw : Int = 34

///|
/// VOWEL_POST UIPC = Right
const USE_VPst : Int = 35

///|
/// VOWEL_PRE / VOWEL_PRE_ABOVE / VOWEL_PRE_ABOVE_POST / VOWEL_PRE_POST
const USE_VPre : Int = 22

///|
/// VOWEL_MOD_ABOVE
const USE_VMAbv : Int = 37

///|
/// VOWEL_MOD_BELOW
const USE_VMBlw : Int = 38

///|
/// VOWEL_MOD_POST
const USE_VMPst : Int = 39

///|
/// VOWEL_MOD_PRE
const USE_VMPre : Int = 23

///|
/// SYM_MOD_ABOVE
const USE_SMAbv : Int = 41

///|
/// SYM_MOD_BELOW
const USE_SMBlw : Int = 42

///|
/// CONS_FINAL_MOD UIPC = Top
const USE_FMAbv : Int = 45

///|
/// CONS_FINAL_MOD UIPC = Bottom
const USE_FMBlw : Int = 46

///|
/// CONS_FINAL_MOD UIPC = Not_Applicable
const USE_FMPst : Int = 47

///|
/// HIEROGLYPH
const USE_G : Int = 49

///|
/// HIEROGLYPH_JOINER
const USE_J : Int = 50

///|
/// HIEROGLYPH_SEGMENT_BEGIN
const USE_SB : Int = 51

///|
/// HIEROGLYPH_SEGMENT_END
const USE_SE : Int = 52

///|
/// HIEROGLYPH_SEGMENT_END
const USE_HVM : Int = 53

///|
/// HIEROGLYPH_MOD
const USE_HM : Int = 54

///|
/// HIEROGLYPH_MIRROR
const USE_HR : Int = 55

///|
/// These features are applied all at once, before reordering,
/// constrained to the syllable.
let use_basic_features : Array[@otf.Tag] = [
  tag("rkrf"),
  tag("abvf"),
  tag("blwf"),
  tag("half"),
  tag("pstf"),
  tag("vatu"),
  tag("cjct"),
]

///|
let use_topographical_features : Array[@otf.Tag] = [
  tag("isol"),
  tag("init"),
  tag("medi"),
  tag("fina"),
]

///|
/// Same order as use_topographical_features.
priv enum JoiningForm {
  Isolated
  Initial
  Medial
  Terminal
} derive(Eq)

///|
fn JoiningForm::to_int(self : JoiningForm) -> Int {
  match self {
    Isolated => 0
    Initial => 1
    Medial => 2
    Terminal => 3
  }
}

///|
/// These features are applied all at once, after reordering and clearing syllables.
let use_other_features : Array[@otf.Tag] = [
  tag("abvs"),
  tag("blws"),
  tag("haln"),
  tag("pres"),
  tag("psts"),
]

///|
fn GlyphInfo::use_category(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_category()
}

///|
fn GlyphInfo::set_use_category(self : GlyphInfo, c : Int) -> Unit {
  self.set_ot_shaper_var_u8_category(c)
}

///|
fn GlyphInfo::is_halant_use(self : GlyphInfo) -> Bool {
  self.use_category() is (USE_H | USE_HVM | USE_IS) && !self.ligated()
}

///|
priv struct UniversalShapePlan {
  rphf_mask : UInt
  arabic_plan : ArabicShapePlan?
}

///|
fn UniversalShapePlan::new(plan : ShapePlan) -> UniversalShapePlan {
  let mut arabic_plan = None
  if plan.script is Some(script) && has_arabic_joining(script) {
    arabic_plan = Some(data_create_arabic(plan))
  }
  { rphf_mask: plan.ot_map.get_1_mask(tag("rphf")), arabic_plan, }
}

///|
/// `plan.data::<UniversalShapePlan>()`
fn universal_plan(plan : ShapePlan) -> UniversalShapePlan {
  match plan.data {
    Use(d) => d
    _ => abort("expected UniversalShapePlan")
  }
}

///|
fn collect_features_use(planner : ShapePlanner) -> Unit {
  // Do this before any lookups have been applied.
  planner.ot_map.add_gsub_pause(Some(setup_syllables_use))

  // Default glyph pre-processing group
  planner.ot_map.enable_feature(tag("locl"), F_PER_SYLLABLE, 1)
  planner.ot_map.enable_feature(tag("ccmp"), F_PER_SYLLABLE, 1)
  planner.ot_map.enable_feature(tag("nukt"), F_PER_SYLLABLE, 1)
  planner.ot_map.enable_feature(tag("akhn"), F_MANUAL_ZWJ | F_PER_SYLLABLE, 1)

  // Reordering group
  planner.ot_map.add_gsub_pause(Some(_hb_clear_substitution_flags))
  planner.ot_map.add_feature(tag("rphf"), F_MANUAL_ZWJ | F_PER_SYLLABLE, 1)
  planner.ot_map.add_gsub_pause(Some(record_rphf_use))
  planner.ot_map.add_gsub_pause(Some(_hb_clear_substitution_flags))
  planner.ot_map.enable_feature(tag("pref"), F_MANUAL_ZWJ | F_PER_SYLLABLE, 1)
  planner.ot_map.add_gsub_pause(Some(record_pref_use))

  // Orthographic unit shaping group
  for feature in use_basic_features {
    planner.ot_map.enable_feature(feature, F_MANUAL_ZWJ | F_PER_SYLLABLE, 1)
  }
  planner.ot_map.add_gsub_pause(Some(reorder_use))
  planner.ot_map.add_gsub_pause(Some(syllabic_clear_var)) // Don't need syllables anymore.

  // Topographical features
  for feature in use_topographical_features {
    planner.ot_map.add_feature(feature, F_NONE, 1)
  }
  planner.ot_map.add_gsub_pause(None)

  // Standard typographic presentation
  for feature in use_other_features {
    planner.ot_map.enable_feature(feature, F_MANUAL_ZWJ, 1)
  }
}

///|
fn setup_syllables_use(plan : ShapePlan, _face : Face, buffer : Buffer) -> Bool {
  find_syllables_use(buffer)
  buffer.foreach_syllable((start, end) => {
    buffer.unsafe_to_break(Some(start), Some(end))
  })
  setup_rphf_mask(plan, buffer) |> ignore
  setup_topographical_masks(plan, buffer)
  false
}

///|
fn setup_rphf_mask(plan : ShapePlan, buffer : Buffer) -> Bool {
  let universal_plan = universal_plan(plan)
  let mask = universal_plan.rphf_mask
  if mask == 0 {
    return false
  }
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    let limit = if buffer.info[start].use_category() == USE_R {
      1
    } else {
      imin(3, end - start)
    }
    for i in start..<(start + limit) {
      buffer.info[i].mask = buffer.info[i].mask | mask
    }
    start = end
    end = buffer.next_syllable(start)
  }
  false
}

///|
fn setup_topographical_masks(plan : ShapePlan, buffer : Buffer) -> Unit {
  if universal_plan(plan).arabic_plan is Some(_) {
    return
  }
  let masks : FixedArray[UInt] = [0, 0, 0, 0]
  let mut all_masks = 0U
  for i in 0..<4 {
    masks[i] = plan.ot_map.get_1_mask(use_topographical_features[i])
    if masks[i] == plan.ot_map.get_global_mask() {
      masks[i] = 0
    }
    all_masks = all_masks | masks[i]
  }
  if all_masks == 0 {
    return
  }
  let other_masks = all_masks ^ 0xFFFFFFFF
  let mut last_start = 0
  let mut last_form : JoiningForm? = None
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    let syllable = buffer.info[start].syllable() & 0x0F
    if syllable == UseSyllableType::HieroglyphCluster.to_int() ||
      syllable == UseSyllableType::NonCluster.to_int() {
      last_form = None
    } else {
      let join = last_form == Some(Terminal) || last_form == Some(Isolated)
      if join {
        // Fixup previous syllable's form.
        let form = if last_form == Some(Terminal) { Medial } else { Initial }
        for i in last_start..<start {
          buffer.info[i].mask = (buffer.info[i].mask & other_masks) |
            masks[form.to_int()]
        }
      }

      // Form for this syllable.
      let form = if join { Terminal } else { Isolated }
      last_form = Some(form)
      for i in start..<end {
        buffer.info[i].mask = (buffer.info[i].mask & other_masks) |
          masks[form.to_int()]
      }
    }
    last_start = start
    start = end
    end = buffer.next_syllable(start)
  }
}

///|
fn record_rphf_use(plan : ShapePlan, _face : Face, buffer : Buffer) -> Bool {
  let universal_plan = universal_plan(plan)
  let mask = universal_plan.rphf_mask
  if mask == 0 {
    return false
  }
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    // Mark a substituted repha as USE_R.
    for i in start..<end {
      if (buffer.info[i].mask & mask) == 0 {
        break
      }
      if buffer.info[i].substituted() {
        buffer.info[i].set_use_category(USE_R)
        break
      }
    }
    start = end
    end = buffer.next_syllable(start)
  }
  false
}

///|
fn reorder_use(_plan : ShapePlan, face : Face, buffer : Buffer) -> Bool {
  let mut ret = false
  if insert_dotted_circles(
      face,
      buffer,
      UseSyllableType::BrokenCluster.to_int(),
      USE_B,
      Some(USE_R),
      None,
    ) {
    ret = true
  }
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    reorder_syllable_use(start, end, buffer)
    start = end
    end = buffer.next_syllable(start)
  }
  ret
}

///|
fn category_flag(c : Int) -> UInt {
  rb_flag(c)
}

///|
fn category_flag64(c : Int) -> UInt64 {
  rb_flag64(c)
}

///|
let use_post_base_flags : UInt64 = category_flag64(USE_FAbv) |
  category_flag64(USE_FBlw) |
  category_flag64(USE_FPst) |
  category_flag64(USE_FMAbv) |
  category_flag64(USE_FMBlw) |
  category_flag64(USE_FMPst) |
  category_flag64(USE_MAbv) |
  category_flag64(USE_MBlw) |
  category_flag64(USE_MPst) |
  category_flag64(USE_MPre) |
  category_flag64(USE_VAbv) |
  category_flag64(USE_VBlw) |
  category_flag64(USE_VPst) |
  category_flag64(USE_VPre) |
  category_flag64(USE_VMAbv) |
  category_flag64(USE_VMBlw) |
  category_flag64(USE_VMPst) |
  category_flag64(USE_VMPre)

///|
fn reorder_syllable_use(start : Int, end : Int, buffer : Buffer) -> Unit {
  let syllable_type = buffer.info[start].syllable() & 0x0F
  // Only a few syllable types need reordering.
  if (
      rb_flag_unsafe(syllable_type) &
      (
        rb_flag(UseSyllableType::ViramaTerminatedCluster.to_int()) |
        rb_flag(UseSyllableType::SakotTerminatedCluster.to_int()) |
        rb_flag(UseSyllableType::StandardCluster.to_int()) |
        rb_flag(UseSyllableType::BrokenCluster.to_int()) |
        0
      )
    ) ==
    0 {
    return
  }

  // Move things forward.
  if buffer.info[start].use_category() == USE_R && end - start > 1 {
    // Got a repha.  Reorder it towards the end, but before the first post-base glyph.
    for i in (start + 1)..<end {
      let is_post_base_glyph = (
          rb_flag64_unsafe(buffer.info[i].use_category()) & use_post_base_flags
        ) !=
        0 ||
        buffer.info[i].is_halant_use()
      if is_post_base_glyph || i == end - 1 {
        // If we hit a post-base glyph, move before it; otherwise move to the
        // end. Shift things in between backward.

        let mut i = i
        if is_post_base_glyph {
          i -= 1
        }
        buffer.merge_clusters(start, i + 1)
        let t = buffer.info[start]
        for k in 0..<(i - start) {
          buffer.info[k + start] = buffer.info[k + start + 1]
        }
        buffer.info[i] = t
        break
      }
    }
  }

  // Move things back.
  let mut j = start
  for i in start..<end {
    let flag = rb_flag_unsafe(buffer.info[i].use_category())
    if buffer.info[i].is_halant_use() {
      // If we hit a halant, move after it; otherwise move to the beginning, and
      // shift things in between forward.
      j = i + 1
    } else if (flag & (category_flag(USE_VPre) | category_flag(USE_VMPre))) != 0 &&
      buffer.info[i].get_lig_comp() == 0 &&
      j < i {
      // Only move the first component of a MultipleSubst.
      buffer.merge_clusters(j, i + 1)
      let t = buffer.info[i]
      for k = i - j - 1; k >= 0; k = k - 1 {
        buffer.info[k + j + 1] = buffer.info[k + j]
      }
      buffer.info[j] = t
    }
  }
}

///|
fn record_pref_use(_plan : ShapePlan, _face : Face, buffer : Buffer) -> Bool {
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    // Mark a substituted pref as VPre, as they behave the same way.
    for i in start..<end {
      if buffer.info[i].substituted() {
        buffer.info[i].set_use_category(USE_VPre)
        break
      }
    }
    start = end
    end = buffer.next_syllable(start)
  }
  false
}

///|
fn has_arabic_joining(script : Script) -> Bool {
  // List of scripts that have data in arabic-table.
  script == script_adlam ||
  script == script_arabic ||
  script == script_chorasmian ||
  script == script_hanifi_rohingya ||
  script == script_mandaic ||
  script == script_manichaean ||
  script == script_mongolian ||
  script == script_nko ||
  script == script_old_uyghur ||
  script == script_phags_pa ||
  script == script_psalter_pahlavi ||
  script == script_sogdian ||
  script == script_syriac
}

///|
fn preprocess_text_use(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Unit {
  preprocess_text_vowel_constraints(buffer)
}

///|
fn compose_use(_ctx : NormalizeContext, a : Int, b : Int) -> Int? {
  // Avoid recomposing split matras.
  if gc_is_mark(char_general_category(a)) {
    return None
  }
  compose(a, b)
}

///|
fn setup_masks_use(plan : ShapePlan, _face : Face, buffer : Buffer) -> Unit {
  let universal_plan = universal_plan(plan)

  // Do this before allocating use_category().
  if universal_plan.arabic_plan is Some(arabic_plan) {
    setup_masks_inner(arabic_plan, plan.script, buffer)
  }

  // We cannot setup masks here. We save information about characters
  // and setup masks later on in a pause-callback.
  for i in 0..<buffer.len {
    let info = buffer.info[i]
    info.set_use_category(use_get_category(info.glyph_id))
  }
}
