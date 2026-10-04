// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_indic.rs`.
//
// Rust modules are namespaces; the shaper callbacks get an `_indic` suffix
// here (like HarfBuzz's C names) to avoid clashes in the flat package.

///|
let indic_shaper : OtShaper = {
  name: "indic",
  collect_features: Some(collect_features_indic),
  override_features: Some(override_features_indic),
  create_data: Some(plan => Indic(IndicShapePlan::new(plan))),
  preprocess_text: Some(preprocess_text_indic),
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT,
  decompose: Some(decompose_indic),
  compose: Some(compose_indic),
  setup_masks: Some(setup_masks_indic),
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE,
  fallback_position: false,
}

// `ot_category_t`
//
// This mod doesn't exist in harfbuzz anymore. Instead, the corresponding values are auto-generated
// by the various machines and stored in `hb-ot-shaper-indic-table`. This means that when updating the
// values in the machines, we also need to update them here.

///|
const OT_X : Int = 0

///|
const OT_C : Int = 1

///|
const OT_V : Int = 2

///|
const OT_N : Int = 3

///|
const OT_H : Int = 4

///|
const OT_ZWNJ : Int = 5

///|
const OT_ZWJ : Int = 6

///|
const OT_M : Int = 7

///|
const OT_SM : Int = 8

///|
const OT_A : Int = 9

///|
const OT_VD : Int = OT_A

///|
const OT_PLACEHOLDER : Int = 10

///|
const OT_GB : Int = OT_PLACEHOLDER

///|
const OT_DOTTEDCIRCLE : Int = 11

///|
/// Register Shifter, used in Khmer OT spec.
const OT_RS : Int = 12

///|
const OT_MPst : Int = 13

///|
/// Atomically-encoded logical or visual repha.
const OT_Repha : Int = 14

///|
const OT_Ra : Int = 15

///|
/// Consonant-Medial.
const OT_CM : Int = 16

///|
/// Avagraha, etc that take marks (SM,A,VD).
const OT_Symbol : Int = 17

///|
const OT_CS : Int = 18

// Khmer & Myanmar shapers.

///|
const OT_VAbv : Int = 20

///|
const OT_VBlw : Int = 21

///|
const OT_VPre : Int = 22

///|
const OT_VPst : Int = 23

// Khmer.

///|
const OT_Robatic : Int = 25

///|
const OT_Xgroup : Int = 26

///|
const OT_Ygroup : Int = 27

// Myanmar

///|
/// Asat
const OT_As : Int = 32

///|
/// Medial
const OT_MH : Int = 35

///|
/// Medial
const OT_MR : Int = 36

///|
/// Medial
const OT_MW : Int = 37

///|
/// Medial
const OT_MY : Int = 38

///|
/// Pwo and other tones
const OT_PT : Int = 39

///|
/// Variation selectors
const OT_VS : Int = 40

///|
/// Consonant medials
const OT_ML : Int = 41

///|
/// This one doesn't exist in ot_category_t in harfbuzz, only in
/// the Myanmar machine. However, in Rust we unfortunately can't export
/// inside the Ragel file, so we have to define it here as well. Needs to
/// be kept in sync with the value in the machine.
const OT_IV : Int = 2

// `ot_position_t`

///|
const POS_START : Int = 0

///|
const POS_RA_TO_BECOME_REPH : Int = 1

///|
const POS_PRE_M : Int = 2

///|
const POS_PRE_C : Int = 3

///|
const POS_BASE_C : Int = 4

///|
const POS_AFTER_MAIN : Int = 5

///|
const POS_ABOVE_C : Int = 6

///|
const POS_BEFORE_SUB : Int = 7

///|
const POS_BELOW_C : Int = 8

///|
const POS_AFTER_SUB : Int = 9

///|
const POS_BEFORE_POST : Int = 10

///|
const POS_POST_C : Int = 11

///|
const POS_AFTER_POST : Int = 12

///|
const POS_SMVD : Int = 13

///|
const POS_END : Int = 14

///|
let indic_features : ReadOnlyArray[(@otf.Tag, Int)] = [
  // Basic features.
  // These features are applied in order, one at a time, after initial_reordering,
  // constrained to the syllable.
  (tag("nukt"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("akhn"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("rphf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("rkrf"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("pref"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("blwf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("abvf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("half"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("pstf"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("vatu"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("cjct"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  // Other features.
  // These features are applied all at once, after final_reordering, constrained
  // to the syllable.
  // Default Bengali font in Windows for example has intermixed
  // lookups for init,pres,abvs,blws features.
  (tag("init"), F_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("pres"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("abvs"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("blws"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("psts"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
  (tag("haln"), F_GLOBAL_MANUAL_JOINERS | F_PER_SYLLABLE),
]

// `indic_feature`: must be in the same order as the INDIC_FEATURES array.

///|
const INDIC_NUKT : Int = 0

///|
const INDIC_AKHN : Int = 1

///|
const INDIC_RPHF : Int = 2

///|
const INDIC_RKRF : Int = 3

///|
const INDIC_PREF : Int = 4

///|
const INDIC_BLWF : Int = 5

///|
const INDIC_ABVF : Int = 6

///|
const INDIC_HALF : Int = 7

///|
const INDIC_PSTF : Int = 8

///|
const INDIC_VATU : Int = 9

///|
const INDIC_CJCT : Int = 10

///|
const INDIC_INIT : Int = 11

///|
const INDIC_PRES : Int = 12

///|
const INDIC_ABVS : Int = 13

///|
const INDIC_BLWS : Int = 14

///|
const INDIC_PSTS : Int = 15

///|
const INDIC_HALN : Int = 16

///|
fn indic_category_flag(c : Int) -> UInt {
  rb_flag(c)
}

///|
/// Note:
///
/// We treat Vowels and placeholders as if they were consonants.  This is safe because Vowels
/// cannot happen in a consonant syllable.  The plus side however is, we can call the
/// consonant syllable logic from the vowel syllable function and get it all right!
let consonant_flags_indic : UInt = indic_category_flag(OT_C) |
  indic_category_flag(OT_CS) |
  indic_category_flag(OT_Ra) |
  indic_category_flag(OT_CM) |
  indic_category_flag(OT_V) |
  indic_category_flag(OT_PLACEHOLDER) |
  indic_category_flag(OT_DOTTEDCIRCLE)

///|
let consonant_flags_myanmar : UInt = indic_category_flag(OT_C) |
  indic_category_flag(OT_CS) |
  indic_category_flag(OT_Ra) |
  // | category_flag(ot_category_t::OT_CM)
  indic_category_flag(OT_IV) |
  indic_category_flag(OT_GB) |
  indic_category_flag(OT_DOTTEDCIRCLE)

///|
let joiner_flags : UInt = indic_category_flag(OT_ZWJ) |
  indic_category_flag(OT_ZWNJ)

///|
priv enum RephPosition {
  AfterMain
  BeforeSub
  AfterSub
  BeforePost
  AfterPost
} derive(Eq)

///|
priv enum RephMode {
  /// Reph formed out of initial Ra,H sequence.
  Implicit
  /// Reph formed out of initial Ra,H,ZWJ sequence.
  Explicit
  /// Encoded Repha character, needs reordering.
  LogRepha
} derive(Eq)

///|
priv enum BlwfMode {
  /// Below-forms feature applied to pre-base and post-base.
  PreAndPost
  /// Below-forms feature applied to post-base only.
  PostOnly
} derive(Eq)

///|
priv struct IndicConfig {
  script : Script?
  has_old_spec : Bool
  virama : Int
  reph_pos : RephPosition
  reph_mode : RephMode
  blwf_mode : BlwfMode
}

///|
fn IndicConfig::new(
  script : Script?,
  has_old_spec : Bool,
  virama : Int,
  reph_pos : RephPosition,
  reph_mode : RephMode,
  blwf_mode : BlwfMode,
) -> IndicConfig {
  { script, has_old_spec, virama, reph_pos, reph_mode, blwf_mode, }
}

///|
let indic_configs : ReadOnlyArray[IndicConfig] = [
  IndicConfig::new(None, false, 0, BeforePost, Implicit, PreAndPost),
  IndicConfig::new(
    Some(script_devanagari),
    true,
    0x094D,
    BeforePost,
    Implicit,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_bengali),
    true,
    0x09CD,
    AfterSub,
    Implicit,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_gurmukhi),
    true,
    0x0A4D,
    BeforeSub,
    Implicit,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_gujarati),
    true,
    0x0ACD,
    BeforePost,
    Implicit,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_oriya),
    true,
    0x0B4D,
    AfterMain,
    Implicit,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_tamil),
    true,
    0x0BCD,
    AfterPost,
    Implicit,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_telugu),
    true,
    0x0C4D,
    AfterPost,
    Explicit,
    PostOnly,
  ),
  IndicConfig::new(
    Some(script_kannada),
    true,
    0x0CCD,
    AfterPost,
    Implicit,
    PostOnly,
  ),
  IndicConfig::new(
    Some(script_malayalam),
    true,
    0x0D4D,
    AfterMain,
    LogRepha,
    PreAndPost,
  ),
  IndicConfig::new(
    Some(script_sinhala),
    false,
    0x0DCA,
    AfterPost,
    Explicit,
    PreAndPost,
  ),
]

///|
priv struct IndicWouldSubstituteFeature {
  /// `Range<usize>` as `(start, end)`.
  lookups : (Int, Int)
  zero_context : Bool
}

///|
fn IndicWouldSubstituteFeature::new(
  map : OtMap,
  feature_tag : @otf.Tag,
  zero_context : Bool,
) -> IndicWouldSubstituteFeature {
  {
    lookups: match map.get_feature_stage(GSUB, feature_tag) {
      Some(stage) => map.stage_lookup_range(GSUB, stage)
      None => (0, 0)
    },
    zero_context,
  }
}

///|
fn IndicWouldSubstituteFeature::would_substitute(
  self : IndicWouldSubstituteFeature,
  map : OtMap,
  face : Face,
  glyphs : Array[@otf.GlyphId],
) -> Bool {
  let (start, end) = self.lookups
  for index in start..<end {
    let lookup = map.lookup(GSUB, index)
    let ctx : WouldApplyContext = { glyphs, zero_context: self.zero_context, }
    if face.gsub is Some(table) &&
      table.lookups.get(lookup.index) is Some(lookup) &&
      lookup.would_apply(ctx) {
      return true
    }
  }
  false
}

///|
priv struct IndicShapePlan {
  config : IndicConfig
  is_old_spec : Bool
  // virama_glyph: Option<u32>,
  rphf : IndicWouldSubstituteFeature
  pref : IndicWouldSubstituteFeature
  blwf : IndicWouldSubstituteFeature
  pstf : IndicWouldSubstituteFeature
  vatu : IndicWouldSubstituteFeature
  mask_array : FixedArray[UInt]
}

///|
fn IndicShapePlan::new(plan : ShapePlan) -> IndicShapePlan {
  let script = plan.script
  let mut config = indic_configs[0]
  for i in 1..<indic_configs.length() {
    if indic_configs[i].script == script {
      config = indic_configs[i]
      break
    }
  }
  let is_old_spec = config.has_old_spec &&
    (match plan.ot_map.chosen_script(GSUB) {
      Some(tag) => (tag.as_u32() & 0xFF) != 0x32 // b'2'
      None => true
    })

  // Use zero-context would_substitute() matching for new-spec of the main
  // Indic scripts, and scripts with one spec only, but not for old-specs.
  // The new-spec for all dual-spec scripts says zero-context matching happens.
  //
  // However, testing with Malayalam shows that old and new spec both allow
  // context.  Testing with Bengali new-spec however shows that it doesn't.
  // So, the heuristic here is the way it is.  It should *only* be changed,
  // as we discover more cases of what Windows does.  DON'T TOUCH OTHERWISE.
  let zero_context = is_old_spec && script != Some(script_malayalam)
  let mask_array = FixedArray::make(indic_features.length(), 0U)
  for i, feature in indic_features[:] {
    mask_array[i] = if (feature.1 & F_GLOBAL) != 0 {
      0
    } else {
      plan.ot_map.get_1_mask(feature.0)
    }
  }

  // TODO: what is this?
  // let mut virama_glyph = None;
  // if config.virama != 0 {
  //     if let Some(g) = face.glyph_index(char::try_from(config.virama).unwrap()) {
  //         virama_glyph = Some(g.0 as u32);
  //     }
  // }

  {
    config,
    is_old_spec,
    // virama_glyph,
    rphf: IndicWouldSubstituteFeature::new(
      plan.ot_map,
      tag("rphf"),
      zero_context,
    ),
    pref: IndicWouldSubstituteFeature::new(
      plan.ot_map,
      tag("pref"),
      zero_context,
    ),
    blwf: IndicWouldSubstituteFeature::new(
      plan.ot_map,
      tag("blwf"),
      zero_context,
    ),
    pstf: IndicWouldSubstituteFeature::new(
      plan.ot_map,
      tag("pstf"),
      zero_context,
    ),
    vatu: IndicWouldSubstituteFeature::new(
      plan.ot_map,
      tag("vatu"),
      zero_context,
    ),
    mask_array,
  }
}

///|
/// `plan.data::<IndicShapePlan>()`
fn indic_shape_plan(plan : ShapePlan) -> IndicShapePlan {
  match plan.data {
    Indic(d) => d
    _ => abort("indic shaper data expected")
  }
}

///|
fn GlyphInfo::indic_category(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_category()
}

///|
fn GlyphInfo::myanmar_category(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_category()
}

///|
fn GlyphInfo::khmer_category(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_category()
}

///|
fn GlyphInfo::set_indic_category(self : GlyphInfo, c : Int) -> Unit {
  self.set_ot_shaper_var_u8_category(c)
}

///|
fn GlyphInfo::set_myanmar_category(self : GlyphInfo, c : Int) -> Unit {
  self.set_ot_shaper_var_u8_category(c)
}

///|
fn GlyphInfo::indic_position(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_auxiliary()
}

///|
fn GlyphInfo::myanmar_position(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_auxiliary()
}

///|
fn GlyphInfo::set_indic_position(self : GlyphInfo, c : Int) -> Unit {
  self.set_ot_shaper_var_u8_auxiliary(c)
}

///|
fn GlyphInfo::set_myanmar_position(self : GlyphInfo, c : Int) -> Unit {
  self.set_ot_shaper_var_u8_auxiliary(c)
}

///|
fn GlyphInfo::is_one_of(self : GlyphInfo, flags : UInt) -> Bool {
  // If it ligated, all bets are off.
  if self.ligated() {
    return false
  }
  (rb_flag_unsafe(self.indic_category()) & flags) != 0
}

///|
fn GlyphInfo::is_joiner(self : GlyphInfo) -> Bool {
  self.is_one_of(joiner_flags)
}

///|
fn GlyphInfo::is_consonant(self : GlyphInfo) -> Bool {
  self.is_one_of(consonant_flags_indic)
}

///|
fn GlyphInfo::is_consonant_myanmar(self : GlyphInfo) -> Bool {
  self.is_one_of(consonant_flags_myanmar)
}

///|
fn GlyphInfo::is_halant(self : GlyphInfo) -> Bool {
  self.is_one_of(rb_flag(OT_H))
}

///|
fn GlyphInfo::set_indic_properties(self : GlyphInfo) -> Unit {
  let u = self.glyph_id.reinterpret_as_int()
  let (cat, pos) = get_categories(u)
  self.set_indic_category(cat)
  self.set_indic_position(pos)
}

///|
fn collect_features_indic(planner : ShapePlanner) -> Unit {
  // Do this before any lookups have been applied.
  planner.ot_map.add_gsub_pause(Some(setup_syllables_indic))
  planner.ot_map.enable_feature(tag("locl"), F_PER_SYLLABLE, 1)
  // The Indic specs do not require ccmp, but we apply it here since if
  // there is a use of it, it's typically at the beginning.
  planner.ot_map.enable_feature(tag("ccmp"), F_PER_SYLLABLE, 1)
  planner.ot_map.add_gsub_pause(Some(initial_reordering_indic))
  for i in 0..<11 {
    let feature = indic_features[i]
    planner.ot_map.add_feature(feature.0, feature.1, 1)
    planner.ot_map.add_gsub_pause(None)
  }
  planner.ot_map.add_gsub_pause(Some(final_reordering_indic))
  for i in 11..<indic_features.length() {
    let feature = indic_features[i]
    planner.ot_map.add_feature(feature.0, feature.1, 1)
  }
}

///|
fn override_features_indic(planner : ShapePlanner) -> Unit {
  planner.ot_map.disable_feature(tag("liga"))
  planner.ot_map.add_gsub_pause(Some(syllabic_clear_var)) // Don't need syllables anymore.
}

///|
fn preprocess_text_indic(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Unit {
  preprocess_text_vowel_constraints(buffer)
}

///|
fn decompose_indic(_ctx : NormalizeContext, ab : Int) -> (Int, Int)? {
  // Don't decompose these.
  //   U+0931 DEVANAGARI LETTER RRA
  //   https://github.com/harfbuzz/harfbuzz/issues/779
  //   U+09DC BENGALI LETTER RRA
  //   U+09DD BENGALI LETTER RHA
  //   U+0B94 TAMIL LETTER AU
  match ab {
    0x0931 | 0x09DC | 0x09DD | 0x0B94 => return None
    _ => ()
  }
  decompose(ab)
}

///|
fn compose_indic(_ctx : NormalizeContext, a : Int, b : Int) -> Int? {
  // Avoid recomposing split matras.
  if gc_is_mark(char_general_category(a)) {
    return None
  }

  // Composition-exclusion exceptions that we want to recompose.
  if a == 0x09AF && b == 0x09BC {
    return Some(0x09DF)
  }
  compose(a, b)
}

///|
fn setup_masks_indic(_plan : ShapePlan, _face : Face, buffer : Buffer) -> Unit {
  // We cannot setup masks here.  We save information about characters
  // and setup masks later on in a pause-callback.
  for i in 0..<buffer.len {
    buffer.info[i].set_indic_properties()
  }
}

///|
fn setup_syllables_indic(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Bool {
  find_syllables_indic(buffer)
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
fn initial_reordering_indic(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Bool {
  let mut ret = false
  let indic_plan = indic_shape_plan(plan)
  update_consonant_positions_indic(plan, indic_plan, face, buffer)
  if insert_dotted_circles(
      face,
      buffer,
      IndicSyllableType::BrokenCluster.to_int(),
      OT_DOTTEDCIRCLE,
      Some(OT_Repha),
      Some(POS_END),
    ) {
    ret = true
  }
  let mut start = 0
  let mut end = buffer.next_syllable(0)
  while start < buffer.len {
    initial_reordering_syllable_indic(
      plan, indic_plan, face, start, end, buffer,
    )
    start = end
    end = buffer.next_syllable(start)
  }
  ret
}

///|
fn update_consonant_positions_indic(
  plan : ShapePlan,
  indic_plan : IndicShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  let mut virama_glyph = None
  if indic_plan.config.virama != 0 {
    virama_glyph = face.get_nominal_glyph(indic_plan.config.virama)
  }
  if virama_glyph is Some(virama) {
    for i in 0..<buffer.len {
      let info = buffer.info[i]
      if info.indic_position() == POS_BASE_C {
        let consonant = info.as_glyph()
        info.set_indic_position(
          consonant_position_from_face(
            plan, indic_plan, face, consonant, virama,
          ),
        )
      }
    }
  }
}

///|
fn consonant_position_from_face(
  plan : ShapePlan,
  indic_plan : IndicShapePlan,
  face : Face,
  consonant : @otf.GlyphId,
  virama : @otf.GlyphId,
) -> Int {
  // For old-spec, the order of glyphs is Consonant,Virama,
  // whereas for new-spec, it's Virama,Consonant.  However,
  // some broken fonts (like Free Sans) simply copied lookups
  // from old-spec to new-spec without modification.
  // And oddly enough, Uniscribe seems to respect those lookups.
  // Eg. in the sequence U+0924,U+094D,U+0930, Uniscribe finds
  // base at 0.  The font however, only has lookups matching
  // 930,94D in 'blwf', not the expected 94D,930 (with new-spec
  // table).  As such, we simply match both sequences.  Seems
  // to work.
  //
  // Vatu is done as well, for:
  // https://github.com/harfbuzz/harfbuzz/issues/1587

  if indic_plan.blwf.would_substitute(plan.ot_map, face, [virama, consonant]) ||
    indic_plan.blwf.would_substitute(plan.ot_map, face, [consonant, virama]) ||
    indic_plan.vatu.would_substitute(plan.ot_map, face, [virama, consonant]) ||
    indic_plan.vatu.would_substitute(plan.ot_map, face, [consonant, virama]) {
    return POS_BELOW_C
  }
  if indic_plan.pstf.would_substitute(plan.ot_map, face, [virama, consonant]) ||
    indic_plan.pstf.would_substitute(plan.ot_map, face, [consonant, virama]) {
    return POS_POST_C
  }
  if indic_plan.pref.would_substitute(plan.ot_map, face, [virama, consonant]) ||
    indic_plan.pref.would_substitute(plan.ot_map, face, [consonant, virama]) {
    return POS_POST_C
  }
  POS_BASE_C
}

///|
fn initial_reordering_syllable_indic(
  plan : ShapePlan,
  indic_plan : IndicShapePlan,
  face : Face,
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  let syllable_type : IndicSyllableType = match
    buffer.info[start].syllable() & 0x0F {
    0 => ConsonantSyllable
    1 => VowelSyllable
    2 => StandaloneCluster
    3 => SymbolCluster
    4 => BrokenCluster
    5 => NonIndicCluster
    _ => abort("unreachable")
  }
  match syllable_type {
    // We made the vowels look like consonants.  So let's call the consonant logic!
    VowelSyllable | ConsonantSyllable =>
      initial_reordering_consonant_syllable_indic(
        plan, indic_plan, face, start, end, buffer,
      )
    // We already inserted dotted-circles, so just call the standalone_cluster.
    BrokenCluster | StandaloneCluster =>
      initial_reordering_standalone_cluster_indic(
        plan, indic_plan, face, start, end, buffer,
      )
    SymbolCluster | NonIndicCluster => ()
  }
}

///|
/// Rules from:
/// https://docs.microsqoft.com/en-us/typography/script-development/devanagari */
fn initial_reordering_consonant_syllable_indic(
  plan : ShapePlan,
  indic_plan : IndicShapePlan,
  face : Face,
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  // https://github.com/harfbuzz/harfbuzz/issues/435#issuecomment-335560167
  // For compatibility with legacy usage in Kannada,
  // Ra+h+ZWJ must behave like Ra+ZWJ+h...
  if buffer.script == Some(script_kannada) &&
    start + 3 <= end &&
    buffer.info[start].is_one_of(indic_category_flag(OT_Ra)) &&
    buffer.info[start + 1].is_one_of(indic_category_flag(OT_H)) &&
    buffer.info[start + 2].is_one_of(indic_category_flag(OT_ZWJ)) {
    buffer.merge_clusters(start + 1, start + 3)
    buffer.info.swap(start + 1, start + 2)
  }

  // 1. Find base consonant:
  //
  // The shaping engine finds the base consonant of the syllable, using the
  // following algorithm: starting from the end of the syllable, move backwards
  // until a consonant is found that does not have a below-base or post-base
  // form (post-base forms have to follow below-base forms), or that is not a
  // pre-base-reordering Ra, or arrive at the first consonant. The consonant
  // stopped at will be the base.
  //
  //   - If the syllable starts with Ra + Halant (in a script that has Reph)
  //     and has more than one consonant, Ra is excluded from candidates for
  //     base consonants.

  let mut base = end
  let mut has_reph = false
  // -> If the syllable starts with Ra + Halant (in a script that has Reph)
  //    and has more than one consonant, Ra is excluded from candidates for
  //    base consonants.
  {
    let mut limit = start
    if indic_plan.mask_array[INDIC_RPHF] != 0 &&
      start + 3 <= end &&
      (
        (
          indic_plan.config.reph_mode == Implicit &&
          !buffer.info[start + 2].is_joiner()
        ) ||
        (
          indic_plan.config.reph_mode == Explicit &&
          buffer.info[start + 2].indic_category() == OT_ZWJ
        )
      ) {
      // See if it matches the 'rphf' feature.
      let glyphs = [
        buffer.info[start].as_glyph(),
        buffer.info[start + 1].as_glyph(),
        if indic_plan.config.reph_mode == Explicit {
          buffer.info[start + 2].as_glyph()
        } else {
          @otf.GlyphId(0)
        },
      ]
      if indic_plan.rphf.would_substitute(plan.ot_map, face, [
          glyphs[0],
          glyphs[1],
        ]) ||
        (
          indic_plan.config.reph_mode == Explicit &&
          indic_plan.rphf.would_substitute(plan.ot_map, face, glyphs)
        ) {
        limit += 2
        while limit < end && buffer.info[limit].is_joiner() {
          limit += 1
        }
        base = start
        has_reph = true
      }
    } else if indic_plan.config.reph_mode == LogRepha &&
      buffer.info[start].indic_category() == OT_Repha {
      limit += 1
      while limit < end && buffer.info[limit].is_joiner() {
        limit += 1
      }
      base = start
      has_reph = true
    }
    // -> starting from the end of the syllable, move backwards
    {
      let mut i = end
      let mut seen_below = false
      while true {
        i -= 1
        // -> until a consonant is found
        if buffer.info[i].is_consonant_myanmar() {
          // -> that does not have a below-base or post-base form
          // (post-base forms have to follow below-base forms),
          if buffer.info[i].indic_position() != POS_BELOW_C &&
            (buffer.info[i].indic_position() != POS_POST_C || seen_below) {
            base = i
            break
          }
          if buffer.info[i].indic_position() == POS_BELOW_C {
            seen_below = true
          }

          // -> or that is not a pre-base-reordering Ra,
          //
          // IMPLEMENTATION NOTES:
          //
          // Our pre-base-reordering Ra's are marked position::PostC, so will be skipped
          // by the logic above already.

          // -> or arrive at the first consonant. The consonant stopped at will
          // be the base.
          base = i
        } else if start < i &&
          buffer.info[i].indic_category() == OT_ZWJ &&
          buffer.info[i - 1].indic_category() == OT_H {
          // A ZWJ after a Halant stops the base search, and requests an explicit
          // half form.
          // A ZWJ before a Halant, requests a subjoined form instead, and hence
          // search continues.  This is particularly important for Bengali
          // sequence Ra,H,Ya that should form Ya-Phalaa by subjoining Ya.
          break
        }
        if i <= limit {
          break
        }
      }
    }

    // -> If the syllable starts with Ra + Halant (in a script that has Reph)
    //    and has more than one consonant, Ra is excluded from candidates for
    //    base consonants.
    //
    //  Only do this for unforced Reph. (ie. not for Ra,H,ZWJ.
    if has_reph && base == start && limit - base <= 2 {
      // Have no other consonant, so Reph is not formed and Ra becomes base.
      has_reph = false
    }
  }

  // 2. Decompose and reorder Matras:
  //
  // Each matra and any syllable modifier sign in the syllable are moved to the
  // appropriate position relative to the consonant(s) in the syllable. The
  // shaping engine decomposes two- or three-part matras into their constituent
  // parts before any repositioning. Matra characters are classified by which
  // consonant in a conjunct they have affinity for and are reordered to the
  // following positions:
  //
  //   - Before first half form in the syllable
  //   - After subjoined consonants
  //   - After post-form consonant
  //   - After main consonant (for above marks)
  //
  // IMPLEMENTATION NOTES:
  //
  // The normalize() routine has already decomposed matras for us, so we don't
  // need to worry about that.

  // 3.  Reorder marks to canonical order:
  //
  // Adjacent nukta and halant or nukta and vedic sign are always repositioned
  // if necessary, so that the nukta is first.
  //
  // IMPLEMENTATION NOTES:
  //
  // We don't need to do this: the normalize() routine already did this for us.

  // Reorder characters

  for i in start..<base {
    let pos = buffer.info[i].indic_position()
    buffer.info[i].set_indic_position(imin(POS_PRE_C, pos))
  }
  if base < end {
    buffer.info[base].set_indic_position(POS_BASE_C)
  }

  // Handle beginning Ra
  if has_reph {
    buffer.info[start].set_indic_position(POS_RA_TO_BECOME_REPH)
  }

  // For old-style Indic script tags, move the first post-base Halant after
  // last consonant.
  //
  // Reports suggest that in some scripts Uniscribe does this only if there
  // is *not* a Halant after last consonant already.  We know that is the
  // case for Kannada, while it reorders unconditionally in other scripts,
  // eg. Malayalam, Bengali, and Devanagari.  We don't currently know about
  // other scripts, so we block Kannada.
  //
  // Kannada test case:
  // U+0C9A,U+0CCD,U+0C9A,U+0CCD
  // With some versions of Lohit Kannada.
  // https://bugs.freedesktop.org/show_bug.cgi?id=59118
  //
  // Malayalam test case:
  // U+0D38,U+0D4D,U+0D31,U+0D4D,U+0D31,U+0D4D
  // With lohit-ttf-20121122/Lohit-Malayalam.ttf
  //
  // Bengali test case:
  // U+0998,U+09CD,U+09AF,U+09CD
  // With Windows XP vrinda.ttf
  // https://github.com/harfbuzz/harfbuzz/issues/1073
  //
  // Devanagari test case:
  // U+091F,U+094D,U+0930,U+094D
  // With chandas.ttf
  // https://github.com/harfbuzz/harfbuzz/issues/1071
  if indic_plan.is_old_spec {
    let disallow_double_halants = buffer.script == Some(script_kannada)
    for i in (base + 1)..<end {
      if buffer.info[i].indic_category() == OT_H {
        let mut j = end - 1
        while j > i {
          if buffer.info[j].is_consonant() ||
            (disallow_double_halants && buffer.info[j].indic_category() == OT_H) {
            break
          }
          j -= 1
        }
        if buffer.info[j].indic_category() != OT_H && j > i {
          // Move Halant to after last consonant.
          let t = buffer.info[i]
          for k in 0..<(j - i) {
            buffer.info[k + i] = buffer.info[k + i + 1]
          }
          buffer.info[j] = t
        }
        break
      }
    }
  }

  // Attach misc marks to previous char to move with them.
  {
    let mut last_pos = POS_START
    for i in start..<end {
      let ok = (
          rb_flag_unsafe(buffer.info[i].indic_category()) &
          (
            indic_category_flag(OT_ZWJ) |
            indic_category_flag(OT_ZWNJ) |
            indic_category_flag(OT_N) |
            indic_category_flag(OT_RS) |
            indic_category_flag(OT_CM) |
            indic_category_flag(OT_H)
          )
        ) !=
        0
      if ok {
        buffer.info[i].set_indic_position(last_pos)
        if buffer.info[i].indic_category() == OT_H &&
          buffer.info[i].indic_position() == POS_PRE_M {
          // Uniscribe doesn't move the Halant with Left Matra.
          // TEST: U+092B,U+093F,U+094DE
          // We follow.
          for j = i; j >= start + 1; j = j - 1 {
            if buffer.info[j - 1].indic_position() != POS_PRE_M {
              let pos = buffer.info[j - 1].indic_position()
              buffer.info[i].set_indic_position(pos)
              break
            }
          }
        }
      } else if buffer.info[i].indic_position() != POS_SMVD {
        if buffer.info[i].indic_category() == OT_MPst &&
          i > start &&
          buffer.info[i - 1].indic_category() == OT_SM {
          let val = buffer.info[i].indic_position()
          buffer.info[i - 1].set_indic_position(val)
        }
        last_pos = buffer.info[i].indic_position()
      }
    }
  }
  // For post-base consonants let them own anything before them
  // since the last consonant or matra.
  {
    let mut last = base
    for i in (base + 1)..<end {
      if buffer.info[i].is_consonant() {
        for j in (last + 1)..<i {
          if buffer.info[j].indic_position() < POS_SMVD {
            let pos = buffer.info[i].indic_position()
            buffer.info[j].set_indic_position(pos)
          }
        }
        last = i
      } else if (
          rb_flag_unsafe(buffer.info[i].indic_category()) &
          (rb_flag(OT_M) | rb_flag(OT_MPst))
        ) !=
        0 {
        last = i
      }
    }
  }
  // Use syllable() for sort accounting temporarily.
  {
    let syllable = buffer.info[start].syllable()
    for i in start..<end {
      buffer.info[i].set_syllable(i - start)
    }
    stable_sort_by(buffer.info, start, end, (a, b) => {
      a.indic_position().compare(b.indic_position())
    })

    // Find base again; also flip left-matra sequence.
    let mut first_left_mantra = end
    let mut last_left_mantra = end
    base = end
    for i in start..<end {
      if buffer.info[i].indic_position() == POS_BASE_C {
        base = i
        break
      } else if buffer.info[i].indic_position() == POS_PRE_M {
        if first_left_mantra == end {
          first_left_mantra = i
        }
        last_left_mantra = i
      }
    }

    // https://github.com/harfbuzz/harfbuzz/issues/3863
    if first_left_mantra < last_left_mantra {
      // No need to merge clusters, handled later.
      buffer.reverse_range(first_left_mantra, last_left_mantra + 1)
      // Reverse back nuktas, etc.
      let mut i = first_left_mantra
      for j in i..<=last_left_mantra {
        if (
            rb_flag_unsafe(buffer.info[j].indic_category()) &
            (rb_flag(OT_M) | rb_flag(OT_MPst))
          ) !=
          0 {
          buffer.reverse_range(i, j + 1)
          i = j + 1
        }
      }
    }

    // Things are out-of-control for post base positions, they may shuffle
    // around like crazy.  In old-spec mode, we move halants around, so in
    // that case merge all clusters after base.  Otherwise, check the sort
    // order and merge as needed.
    // For pre-base stuff, we handle cluster issues in final reordering.
    //
    // We could use buffer->sort() for this, if there was no special
    // reordering of pre-base stuff happening later...
    // We don't want to merge_clusters all of that, which buffer->sort()
    // would.  Here's a concrete example:
    //
    // Assume there's a pre-base consonant and explicit Halant before base,
    // followed by a prebase-reordering (left) Matra:
    //
    //   C,H,ZWNJ,B,M
    //
    // At this point in reordering we would have:
    //
    //   M,C,H,ZWNJ,B
    //
    // whereas in final reordering we will bring the Matra closer to Base:
    //
    //   C,H,ZWNJ,M,B
    //
    // That's why we don't want to merge-clusters anything before the Base
    // at this point.  But if something moved from after Base to before it,
    // we should merge clusters from base to them.  In final-reordering, we
    // only move things around before base, and merge-clusters up to base.
    // These two merge-clusters from the two sides of base will interlock
    // to merge things correctly.  See:
    // https://github.com/harfbuzz/harfbuzz/issues/2272
    if indic_plan.is_old_spec || end - start > 127 {
      buffer.merge_clusters(base, end)
    } else {
      // Note! syllable() is a one-byte field.
      for i in base..<end {
        if buffer.info[i].syllable() != 255 {
          let mut min = i
          let mut max = i
          let mut j = start + buffer.info[i].syllable()
          while j != i {
            min = imin(min, j)
            max = imax(max, j)
            let next = start + buffer.info[j].syllable()
            buffer.info[j].set_syllable(255) // So we don't process j later again.
            j = next
          }
          buffer.merge_clusters(imax(base, min), max + 1)
        }
      }
    }

    // Put syllable back in.
    for i in start..<end {
      buffer.info[i].set_syllable(syllable)
    }
  }

  // Setup masks now

  // Reph
  {
    for i in start..<end {
      let info = buffer.info[i]
      if info.indic_position() != POS_RA_TO_BECOME_REPH {
        break
      }
      info.mask = info.mask | indic_plan.mask_array[INDIC_RPHF]
    }

    // Pre-base
    let mut mask = indic_plan.mask_array[INDIC_HALF]
    if !indic_plan.is_old_spec && indic_plan.config.blwf_mode == PreAndPost {
      mask = mask | indic_plan.mask_array[INDIC_BLWF]
    }
    for i in start..<base {
      let info = buffer.info[i]
      info.mask = info.mask | mask
    }

    // Base
    mask = 0
    if base < end {
      buffer.info[base].mask = buffer.info[base].mask | mask
    }

    // Post-base
    mask = indic_plan.mask_array[INDIC_BLWF] |
      indic_plan.mask_array[INDIC_ABVF] |
      indic_plan.mask_array[INDIC_PSTF]
    for i in (base + 1)..<end {
      buffer.info[i].mask = buffer.info[i].mask | mask
    }
  }
  if indic_plan.is_old_spec && buffer.script == Some(script_devanagari) {
    // Old-spec eye-lash Ra needs special handling.  From the
    // spec:
    //
    // "The feature 'below-base form' is applied to consonants
    // having below-base forms and following the base consonant.
    // The exception is vattu, which may appear below half forms
    // as well as below the base glyph. The feature 'below-base
    // form' will be applied to all such occurrences of Ra as well."
    //
    // Test case: U+0924,U+094D,U+0930,U+094d,U+0915
    // with Sanskrit 2003 font.
    //
    // However, note that Ra,Halant,ZWJ is the correct way to
    // request eyelash form of Ra, so we wouldbn't inhibit it
    // in that sequence.
    //
    // Test case: U+0924,U+094D,U+0930,U+094d,U+200D,U+0915
    for i in start..<imax(base - 1, 0) {
      if buffer.info[i].indic_category() == OT_Ra &&
        buffer.info[i + 1].indic_category() == OT_H &&
        (i + 2 == base || buffer.info[i + 2].indic_category() != OT_ZWJ) {
        buffer.info[i].mask = buffer.info[i].mask |
          indic_plan.mask_array[INDIC_BLWF]
        buffer.info[i + 1].mask = buffer.info[i + 1].mask |
          indic_plan.mask_array[INDIC_BLWF]
      }
    }
  }
  let pref_len = 2
  if indic_plan.mask_array[INDIC_PREF] != 0 && base + pref_len < end {
    // Find a Halant,Ra sequence and mark it for pre-base-reordering processing.
    for i in (base + 1)..<(end - pref_len + 1) {
      let glyphs = [
        buffer.info[i + 0].as_glyph(),
        buffer.info[i + 1].as_glyph(),
      ]
      if indic_plan.pref.would_substitute(plan.ot_map, face, glyphs) {
        buffer.info[i + 0].mask = buffer.info[i + 0].mask |
          indic_plan.mask_array[INDIC_PREF]
        buffer.info[i + 1].mask = buffer.info[i + 1].mask |
          indic_plan.mask_array[INDIC_PREF]
        break
      }
    }
  }

  // Apply ZWJ/ZWNJ effects
  for i in (start + 1)..<end {
    if buffer.info[i].is_joiner() {
      let non_joiner = buffer.info[i].indic_category() == OT_ZWNJ
      let mut j = i
      while true {
        j -= 1

        // ZWJ/ZWNJ should disable CJCT.  They do that by simply
        // being there, since we don't skip them for the CJCT
        // feature (ie. F_MANUAL_ZWJ)

        // A ZWNJ disables HALF.
        if non_joiner {
          buffer.info[j].mask = buffer.info[j].mask &
            (indic_plan.mask_array[INDIC_HALF] ^ 0xFFFFFFFF)
        }
        if j <= start || buffer.info[j].is_consonant() {
          break
        }
      }
    }
  }
}

///|
fn initial_reordering_standalone_cluster_indic(
  plan : ShapePlan,
  indic_plan : IndicShapePlan,
  face : Face,
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  // We treat placeholder/dotted-circle as if they are consonants, so we
  // should just chain.  Only if not in compatibility mode that is...
  initial_reordering_consonant_syllable_indic(
    plan, indic_plan, face, start, end, buffer,
  )
}

///|
fn final_reordering_indic(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Bool {
  if buffer.is_empty() {
    return false
  }
  buffer.foreach_syllable((start, end) => {
    final_reordering_impl_indic(plan, face, start, end, buffer)
  })
  false
}

///|
fn final_reordering_impl_indic(
  plan : ShapePlan,
  face : Face,
  start : Int,
  end : Int,
  buffer : Buffer,
) -> Unit {
  let indic_plan = indic_shape_plan(plan)

  // This function relies heavily on halant glyphs.  Lots of ligation
  // and possibly multiple substitutions happened prior to this
  // phase, and that might have messed up our properties.  Recover
  // from a particular case of that where we're fairly sure that a
  // class of OT_H is desired but has been lost.
  //
  // We don't call load_virama_glyph(), since we know it's already loaded.
  let mut virama_glyph = None
  if indic_plan.config.virama != 0 {
    if face.get_nominal_glyph(indic_plan.config.virama) is Some(g) {
      virama_glyph = Some(g.0.to_uint())
    }
  }
  if virama_glyph is Some(virama_glyph) {
    for i in start..<end {
      let info = buffer.info[i]
      if info.glyph_id == virama_glyph && info.ligated() && info.multiplied() {
        // This will make sure that this glyph passes is_halant() test.
        info.set_indic_category(OT_H)
        info.clear_ligated_and_multiplied()
      }
    }
  }

  // 4. Final reordering:
  //
  // After the localized forms and basic shaping forms GSUB features have been
  // applied (see below), the shaping engine performs some final glyph
  // reordering before applying all the remaining font features to the entire
  // syllable.

  let mut try_pref = indic_plan.mask_array[INDIC_PREF] != 0
  let mut base = start
  while base < end {
    if buffer.info[base].indic_position() >= POS_BASE_C {
      if try_pref && base + 1 < end {
        for i in (base + 1)..<end {
          if (buffer.info[i].mask & indic_plan.mask_array[INDIC_PREF]) != 0 {
            if !(buffer.info[i].substituted() &&
              buffer.info[i].ligated_and_didnt_multiply()) {
              // Ok, this was a 'pref' candidate but didn't form any.
              // Base is around here...
              base = i
              while base < end && buffer.info[base].is_halant() {
                base += 1
              }
              if base < end {
                buffer.info[base].set_indic_position(POS_BASE_C)
              }
              try_pref = false
            }
            break
          }
          if base == end {
            break
          }
        }
      }

      // For Malayalam, skip over unformed below- (but NOT post-) forms.
      if buffer.script == Some(script_malayalam) {
        let mut i = base + 1
        while i < end {
          while i < end && buffer.info[i].is_joiner() {
            i += 1
          }
          if i == end || !buffer.info[i].is_halant() {
            break
          }
          i += 1 // Skip halant.
          while i < end && buffer.info[i].is_joiner() {
            i += 1
          }
          if i < end &&
            buffer.info[i].is_consonant() &&
            buffer.info[i].indic_position() == POS_BELOW_C {
            base = i
            buffer.info[base].set_indic_position(POS_BASE_C)
          }
          i += 1
        }
      }
      if start < base && buffer.info[base].indic_position() > POS_BASE_C {
        base -= 1
      }
      break
    }
    base += 1
  }
  if base == end &&
    start < base &&
    buffer.info[base - 1].is_one_of(rb_flag(OT_ZWJ)) {
    base -= 1
  }
  if base < end {
    while start < base &&
          buffer.info[base].is_one_of(rb_flag(OT_N) | rb_flag(OT_H)) {
      base -= 1
    }
  }

  // - Reorder matras:
  //
  //   If a pre-base matra character had been reordered before applying basic
  //   features, the glyph can be moved closer to the main consonant based on
  //   whether half-forms had been formed. Actual position for the matra is
  //   defined as “after last standalone halant glyph, after initial matra
  //   position and before the main consonant”. If ZWJ or ZWNJ follow this
  //   halant, position is moved after it.
  //
  // IMPLEMENTATION NOTES:
  //
  // It looks like the last sentence is wrong.  Testing, with Windows 7 Uniscribe
  // and Devanagari shows that the behavior is best described as:
  //
  // "If ZWJ follows this halant, matra is NOT repositioned after this halant.
  //  If ZWNJ follows this halant, position is moved after it."
  //
  // Test case, with Adobe Devanagari or Nirmala UI:
  //
  //   U+091F,U+094D,U+200C,U+092F,U+093F
  //   (Matra moves to the middle, after ZWNJ.)
  //
  //   U+091F,U+094D,U+200D,U+092F,U+093F
  //   (Matra does NOT move, stays to the left.)
  //
  // https://github.com/harfbuzz/harfbuzz/issues/1070

  // Otherwise there can't be any pre-base matra characters.
  if start + 1 < end && start < base {
    // If we lost track of base, alas, position before last thingy.
    let mut new_pos = if base == end { base - 2 } else { base - 1 }

    // Malayalam / Tamil do not have "half" forms or explicit virama forms.
    // The glyphs formed by 'half' are Chillus or ligated explicit viramas.
    // We want to position matra after them.
    if buffer.script != Some(script_malayalam) &&
      buffer.script != Some(script_tamil) {
      while true {
        while new_pos > start &&
              !buffer.info[new_pos].is_one_of(
                rb_flag(OT_M) | rb_flag(OT_MPst) | rb_flag(OT_H),
              ) {
          new_pos -= 1
        }

        // If we found no Halant we are done.
        // Otherwise only proceed if the Halant does
        // not belong to the Matra itself!
        if buffer.info[new_pos].is_halant() &&
          buffer.info[new_pos].indic_position() != POS_PRE_M {
          if new_pos + 1 < end {
            // -> If ZWJ follows this halant, matra is NOT repositioned after this halant.
            if buffer.info[new_pos + 1].indic_category() == OT_ZWJ {
              // Keep searching.
              if new_pos > start {
                new_pos -= 1
                continue
              }
            }

            // -> If ZWNJ follows this halant, position is moved after it.
            //
            // IMPLEMENTATION NOTES:
            //
            // This is taken care of by the state-machine. A Halant,ZWNJ is a terminating
            // sequence for a consonant syllable; any pre-base matras occurring after it
            // will belong to the subsequent syllable.
          }
        } else {
          new_pos = start // No move.
        }
        break
      }
    }
    if start < new_pos && buffer.info[new_pos].indic_position() != POS_PRE_M {
      // Now go see if there's actually any matras...
      for i = new_pos; i >= start + 1; i = i - 1 {
        if buffer.info[i - 1].indic_position() == POS_PRE_M {
          let old_pos = i - 1
          // Shouldn't actually happen.
          if old_pos < base && base <= new_pos {
            base -= 1
          }
          let tmp = buffer.info[old_pos]
          for k in 0..<(new_pos - old_pos) {
            buffer.info[k + old_pos] = buffer.info[k + old_pos + 1]
          }
          buffer.info[new_pos] = tmp

          // Note: this merge_clusters() is intentionally *after* the reordering.
          // Indic matra reordering is special and tricky...
          buffer.merge_clusters(new_pos, imin(end, base + 1))
          new_pos -= 1
        }
      }
    } else {
      for i in start..<base {
        if buffer.info[i].indic_position() == POS_PRE_M {
          buffer.merge_clusters(i, imin(end, base + 1))
          break
        }
      }
    }
  }

  // - Reorder reph:
  //
  //   Reph’s original position is always at the beginning of the syllable,
  //   (i.e. it is not reordered at the character reordering stage). However,
  //   it will be reordered according to the basic-forms shaping results.
  //   Possible positions for reph, depending on the script, are; after main,
  //   before post-base consonant forms, and after post-base consonant forms.

  // Two cases:
  //
  // - If repha is encoded as a sequence of characters (Ra,H or Ra,H,ZWJ), then
  //   we should only move it if the sequence ligated to the repha form.
  //
  // - If repha is encoded separately and in the logical position, we should only
  //   move it if it did NOT ligate.  If it ligated, it's probably the font trying
  //   to make it work without the reordering.

  if start + 1 < end &&
    buffer.info[start].indic_position() == POS_RA_TO_BECOME_REPH &&
    (buffer.info[start].indic_category() == OT_Repha) !=
    buffer.info[start].ligated_and_didnt_multiply() {
    let new_reph_pos = find_new_reph_pos_indic(
      indic_plan, start, end, base, buffer,
    )

    // Move
    buffer.merge_clusters(start, new_reph_pos + 1)
    let reph = buffer.info[start]
    for i in 0..<(new_reph_pos - start) {
      buffer.info[i + start] = buffer.info[i + start + 1]
    }
    buffer.info[new_reph_pos] = reph
    if start < base && base <= new_reph_pos {
      base -= 1
    }
  }

  // - Reorder pre-base-reordering consonants:
  //
  //   If a pre-base-reordering consonant is found, reorder it according to
  //   the following rules:

  // Otherwise there can't be any pre-base-reordering Ra.
  if try_pref && base + 1 < end {
    for i in (base + 1)..<end {
      if (buffer.info[i].mask & indic_plan.mask_array[INDIC_PREF]) != 0 {
        // 1. Only reorder a glyph produced by substitution during application
        //    of the <pref> feature. (Note that a font may shape a Ra consonant with
        //    the feature generally but block it in certain contexts.)
        //
        // Note: We just check that something got substituted.  We don't check that
        // the <pref> feature actually did it...
        //
        // Reorder pref only if it ligated.
        if buffer.info[i].ligated_and_didnt_multiply() {
          // 2. Try to find a target position the same way as for pre-base matra.
          //    If it is found, reorder pre-base consonant glyph.
          //
          // 3. If position is not found, reorder immediately before main consonant.

          let mut new_pos = base
          // Malayalam / Tamil do not have "half" forms or explicit virama forms.
          // The glyphs formed by 'half' are Chillus or ligated explicit viramas.
          // We want to position matra after them.
          if buffer.script != Some(script_malayalam) &&
            buffer.script != Some(script_tamil) {
            while new_pos > start &&
                  !buffer.info[new_pos - 1].is_one_of(
                    rb_flag(OT_M) | rb_flag(OT_MPst) | rb_flag(OT_H),
                  ) {
              new_pos -= 1
            }
          }
          if new_pos > start && buffer.info[new_pos - 1].is_halant() {
            // -> If ZWJ or ZWNJ follow this halant, position is moved after it.
            if new_pos < end && buffer.info[new_pos].is_joiner() {
              new_pos += 1
            }
          }
          let old_pos = i
          buffer.merge_clusters(new_pos, old_pos + 1)
          let tmp = buffer.info[old_pos]
          for k = old_pos - new_pos - 1; k >= 0; k = k - 1 {
            buffer.info[k + new_pos + 1] = buffer.info[k + new_pos]
          }
          buffer.info[new_pos] = tmp
          if new_pos <= base && base < old_pos {
            // TODO: investigate
            base += 1
          }
        }
        break
      }
    }
  }

  // Apply 'init' to the Left Matra if it's a word start.
  if buffer.info[start].indic_position() == POS_PRE_M {
    if start == 0 ||
      (
        rb_flag_unsafe(buffer.info[start - 1].get_general_category()) &
        rb_flag_range(GC_FORMAT, GC_NON_SPACING_MARK)
      ) ==
      0 {
      buffer.info[start].mask = buffer.info[start].mask |
        indic_plan.mask_array[INDIC_INIT]
    } else {
      buffer.unsafe_to_break(Some(start - 1), Some(start + 1))
    }
  }
}

///|
/// The `'reph: { ... }` block of `final_reordering_impl`: the new position of
/// the reph.
fn find_new_reph_pos_indic(
  indic_plan : IndicShapePlan,
  start : Int,
  end : Int,
  base : Int,
  buffer : Buffer,
) -> Int {
  let mut new_reph_pos = 0
  let reph_pos = indic_plan.config.reph_pos

  // 1. If reph should be positioned after post-base consonant forms,
  //    proceed to step 5.
  if reph_pos != AfterPost {
    // 2. If the reph repositioning class is not after post-base: target
    //    position is after the first explicit halant glyph between the
    //    first post-reph consonant and last main consonant. If ZWJ or ZWNJ
    //    are following this halant, position is moved after it. If such
    //    position is found, this is the target position. Otherwise,
    //    proceed to the next step.
    //
    //    Note: in old-implementation fonts, where classifications were
    //    fixed in shaping engine, there was no case where reph position
    //    will be found on this step.
    {
      new_reph_pos = start + 1
      while new_reph_pos < base && !buffer.info[new_reph_pos].is_halant() {
        new_reph_pos += 1
      }
      if new_reph_pos < base && buffer.info[new_reph_pos].is_halant() {
        // ->If ZWJ or ZWNJ are following this halant, position is moved after it.
        if new_reph_pos + 1 < base && buffer.info[new_reph_pos + 1].is_joiner() {
          new_reph_pos += 1
        }
        return new_reph_pos
      }
    }

    // 3. If reph should be repositioned after the main consonant: find the
    //    first consonant not ligated with main, or find the first
    //    consonant that is not a potential pre-base-reordering Ra.
    if reph_pos == AfterMain {
      new_reph_pos = base
      while new_reph_pos + 1 < end &&
            buffer.info[new_reph_pos + 1].indic_position() <= POS_AFTER_MAIN {
        new_reph_pos += 1
      }
      if new_reph_pos < end {
        return new_reph_pos
      }
    }

    // 4. If reph should be positioned before post-base consonant, find
    //    first post-base classified consonant not ligated with main. If no
    //    consonant is found, the target position should be before the
    //    first matra, syllable modifier sign or vedic sign.
    //
    // This is our take on what step 4 is trying to say (and failing, BADLY).
    if reph_pos == AfterSub {
      new_reph_pos = base
      while new_reph_pos + 1 < end &&
            (
              rb_flag_unsafe(buffer.info[new_reph_pos + 1].indic_position()) &
              (
                rb_flag(POS_POST_C) |
                rb_flag(POS_AFTER_POST) |
                rb_flag(POS_SMVD)
              )
            ) ==
            0 {
        new_reph_pos += 1
      }
      if new_reph_pos < end {
        return new_reph_pos
      }
    }
  }

  // 5. If no consonant is found in steps 3 or 4, move reph to a position
  //    immediately before the first post-base matra, syllable modifier
  //    sign or vedic sign that has a reordering class after the intended
  //    reph position. For example, if the reordering position for reph
  //    is post-main, it will skip above-base matras that also have a
  //    post-main position.
  //
  // Copied from step 2.
  new_reph_pos = start + 1
  while new_reph_pos < base && !buffer.info[new_reph_pos].is_halant() {
    new_reph_pos += 1
  }
  if new_reph_pos < base && buffer.info[new_reph_pos].is_halant() {
    // ->If ZWJ or ZWNJ are following this halant, position is moved after it.
    if new_reph_pos + 1 < base && buffer.info[new_reph_pos + 1].is_joiner() {
      new_reph_pos += 1
    }
    return new_reph_pos
  }
  // See https://github.com/harfbuzz/harfbuzz/issues/2298#issuecomment-615318654

  // 6. Otherwise, reorder reph to the end of the syllable.
  {
    new_reph_pos = end - 1
    while new_reph_pos > start &&
          buffer.info[new_reph_pos].indic_position() == POS_SMVD {
      new_reph_pos -= 1
    }

    // If the Reph is to be ending up after a Matra,Halant sequence,
    // position it before that Halant so it can interact with the Matra.
    // However, if it's a plain Consonant,Halant we shouldn't do that.
    // Uniscribe doesn't do this.
    // TEST: U+0930,U+094D,U+0915,U+094B,U+094D
    if buffer.info[new_reph_pos].is_halant() {
      let limit = new_reph_pos
      for k in (base + 1)..<limit {
        let info = buffer.info[k]
        if (
            rb_flag_unsafe(info.indic_category()) &
            (rb_flag(OT_M) | rb_flag(OT_MPst))
          ) !=
          0 {
          // Ok, got it.
          new_reph_pos -= 1
        }
      }
    }
  }
  new_reph_pos
}
