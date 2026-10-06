// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_arabic.rs`.

///|
const HB_BUFFER_SCRATCH_FLAG_ARABIC_HAS_STCH : UInt = HB_BUFFER_SCRATCH_FLAG_SHAPER0

///|
// See:
// https://github.com/harfbuzz/harfbuzz/commit/6e6f82b6f3dde0fc6c3c7d991d9ec6cfff57823d#commitcomment-14248516
fn is_word_category(gc : Int) -> Bool {
  (
    rb_flag_unsafe(gc) &
    (
      rb_flag(GC_UNASSIGNED) |
      rb_flag(GC_PRIVATE_USE) |
      rb_flag(GC_MODIFIER_LETTER) |
      rb_flag(GC_OTHER_LETTER) |
      rb_flag(GC_SPACING_MARK) |
      rb_flag(GC_ENCLOSING_MARK) |
      rb_flag(GC_NON_SPACING_MARK) |
      rb_flag(GC_DECIMAL_NUMBER) |
      rb_flag(GC_LETTER_NUMBER) |
      rb_flag(GC_OTHER_NUMBER) |
      rb_flag(GC_CURRENCY_SYMBOL) |
      rb_flag(GC_MODIFIER_SYMBOL) |
      rb_flag(GC_MATH_SYMBOL) |
      rb_flag(GC_OTHER_SYMBOL)
    )
  ) !=
  0
}

// hb_arabic_joining_type_t

///|
const JOINING_TYPE_U : Int = 0

///|
// ot_shaper_arabic.rs:42; named only by the generated table upstream.
#warnings("-unused_value")
const JOINING_TYPE_L : Int = 1

///|
const JOINING_TYPE_R : Int = 2

///|
// ot_shaper_arabic.rs:44; named only by the generated table upstream.
#warnings("-unused_value")
const JOINING_TYPE_D : Int = 3

///|
// We don't have C, like harfbuzz, because Rust doesn't allow duplicated enum variants.
// ot_shaper_arabic.rs:46; named only by the generated table upstream.
#warnings("-unused_value")
const JOINING_TYPE_GROUP_ALAPH : Int = 4

///|
// ot_shaper_arabic.rs:47; named only by the generated table upstream.
#warnings("-unused_value")
const JOINING_TYPE_GROUP_DALATH_RISH : Int = 5

///|
const JOINING_TYPE_T : Int = 7

///|
/// Means: use general-category to choose between U or T.
const JOINING_TYPE_X : Int = 8

///|
fn get_joining_type(u : Int, gc : Int) -> Int {
  let j_type = joining_type(u)
  if j_type != JOINING_TYPE_X {
    return j_type
  }
  let ok = rb_flag_unsafe(gc) &
    (
      rb_flag(GC_NON_SPACING_MARK) |
      rb_flag(GC_ENCLOSING_MARK) |
      rb_flag(GC_FORMAT)
    )
  if ok != 0 {
    JOINING_TYPE_T
  } else {
    JOINING_TYPE_U
  }
}

///|
fn feature_is_syriac(tag : @otf.Tag) -> Bool {
  let b = tag.as_u32() & 0xFF
  b == '2'.to_int().reinterpret_as_uint() ||
  b == '3'.to_int().reinterpret_as_uint()
}

///|
let arabic_features : ReadOnlyArray[@otf.Tag] = [
  tag("isol"),
  tag("fina"),
  tag("fin2"),
  tag("fin3"),
  tag("medi"),
  tag("med2"),
  tag("init"),
]

// arabic_action_t

///|
const ARABIC_ACTION_ISOL : Int = 0

///|
const ARABIC_ACTION_FINA : Int = 1

///|
const ARABIC_ACTION_FIN2 : Int = 2

///|
const ARABIC_ACTION_FIN3 : Int = 3

///|
const ARABIC_ACTION_MEDI : Int = 4

///|
const ARABIC_ACTION_MED2 : Int = 5

///|
const ARABIC_ACTION_INIT : Int = 6

///|
const ARABIC_ACTION_NONE : Int = 7

///|
// We abuse the same byte for other things...
const ARABIC_ACTION_STRETCHING_FIXED : Int = 8

///|
const ARABIC_ACTION_STRETCHING_REPEATING : Int = 9

///|
fn arabic_action_is_stch(n : Int) -> Bool {
  n == ARABIC_ACTION_STRETCHING_FIXED || n == ARABIC_ACTION_STRETCHING_REPEATING
}

///|
/// `(prev_action, curr_action, next_state)` per state and joining type.
let arabic_state_table : ReadOnlyArray[ReadOnlyArray[(Int, Int, Int)]] = [
  // jt_U,          jt_L,          jt_R,
  // jt_D,          jg_ALAPH,      jg_DALATH_RISH

  // State 0: prev was U, not willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 1),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 1),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 6),
  ],
  // State 1: prev was R or action::ISOL/ALAPH, not willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 1),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_FIN2, 5),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 6),
  ],
  // State 2: prev was D/L in action::ISOL form, willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_INIT, ARABIC_ACTION_FINA, 1),
    (ARABIC_ACTION_INIT, ARABIC_ACTION_FINA, 3),
    (ARABIC_ACTION_INIT, ARABIC_ACTION_FINA, 4),
    (ARABIC_ACTION_INIT, ARABIC_ACTION_FINA, 6),
  ],
  // State 3: prev was D in action::FINA form, willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_MEDI, ARABIC_ACTION_FINA, 1),
    (ARABIC_ACTION_MEDI, ARABIC_ACTION_FINA, 3),
    (ARABIC_ACTION_MEDI, ARABIC_ACTION_FINA, 4),
    (ARABIC_ACTION_MEDI, ARABIC_ACTION_FINA, 6),
  ],
  // State 4: prev was action::FINA ALAPH, not willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_MED2, ARABIC_ACTION_ISOL, 1),
    (ARABIC_ACTION_MED2, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_MED2, ARABIC_ACTION_FIN2, 5),
    (ARABIC_ACTION_MED2, ARABIC_ACTION_ISOL, 6),
  ],
  // State 5: prev was FIN2/FIN3 ALAPH, not willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_ISOL, ARABIC_ACTION_ISOL, 1),
    (ARABIC_ACTION_ISOL, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_ISOL, ARABIC_ACTION_FIN2, 5),
    (ARABIC_ACTION_ISOL, ARABIC_ACTION_ISOL, 6),
  ],
  // State 6: prev was DALATH/RISH, not willing to join.
  [
    (ARABIC_ACTION_NONE, ARABIC_ACTION_NONE, 0),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 1),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 2),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_FIN3, 5),
    (ARABIC_ACTION_NONE, ARABIC_ACTION_ISOL, 6),
  ],
]

///|
fn GlyphInfo::arabic_shaping_action(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_auxiliary()
}

///|
fn GlyphInfo::set_arabic_shaping_action(self : GlyphInfo, action : Int) -> Unit {
  self.set_ot_shaper_var_u8_auxiliary(action)
}

///|
fn collect_features_arabic(planner : ShapePlanner) -> Unit {
  // We apply features according to the Arabic spec, with pauses
  // in between most.
  //
  // The pause between init/medi/... and rlig is required.  See eg:
  // https://bugzilla.mozilla.org/show_bug.cgi?id=644184
  //
  // The pauses between init/medi/... themselves are not necessarily
  // needed as only one of those features is applied to any character.
  // The only difference it makes is when fonts have contextual
  // substitutions.  We now follow the order of the spec, which makes
  // for better experience if that's what Uniscribe is doing.
  //
  // At least for Arabic, looks like Uniscribe has a pause between
  // rlig and calt.  Otherwise the IranNastaliq's ALLAH ligature won't
  // work.  However, testing shows that rlig and calt are applied
  // together for Mongolian in Uniscribe.  As such, we only add a
  // pause for Arabic, not other scripts.
  //
  // A pause after calt is required to make KFGQPC Uthmanic Script HAFS
  // work correctly.  See https://github.com/harfbuzz/harfbuzz/issues/505

  planner.ot_map.enable_feature(tag("stch"), F_NONE, 1)
  planner.ot_map.add_gsub_pause(Some(record_stch))
  planner.ot_map.enable_feature(tag("ccmp"), F_MANUAL_ZWJ, 1)
  planner.ot_map.enable_feature(tag("locl"), F_MANUAL_ZWJ, 1)
  planner.ot_map.add_gsub_pause(None)
  for feature in arabic_features[:] {
    let has_fallback = planner.script == Some(script_arabic) &&
      !feature_is_syriac(feature)
    let flags = if has_fallback { F_HAS_FALLBACK } else { F_NONE }
    planner.ot_map.add_feature(feature, F_MANUAL_ZWJ | flags, 1)
    planner.ot_map.add_gsub_pause(None)
  }

  // Normally, Unicode says a ZWNJ means "don't ligate".  In Arabic script
  // however, it says a ZWJ should also mean "don't ligate".  So we run
  // the main ligating features as MANUAL_ZWJ.

  planner.ot_map.enable_feature(tag("rlig"), F_MANUAL_ZWJ | F_HAS_FALLBACK, 1)
  if planner.script == Some(script_arabic) {
    planner.ot_map.add_gsub_pause(Some(arabic_fallback_shape))
  }

  // No pause after rclt.
  // See 98460779bae19e4d64d29461ff154b3527bf8420
  planner.ot_map.enable_feature(tag("calt"), F_MANUAL_ZWJ, 1)
  // https://github.com/harfbuzz/harfbuzz/issues/1573
  if !planner.ot_map.has_feature(tag("rclt")) {
    planner.ot_map.add_gsub_pause(None)
  }
  planner.ot_map.enable_feature(tag("liga"), F_MANUAL_ZWJ, 1)
  planner.ot_map.enable_feature(tag("clig"), F_MANUAL_ZWJ, 1)

  // The spec includes 'cswh'.  Earlier versions of Windows
  // used to enable this by default, but testing suggests
  // that Windows 8 and later do not enable it by default,
  // and spec now says 'Off by default'.
  // We disabled this in ae23c24c32.
  // Note that IranNastaliq uses this feature extensively
  // to fixup broken glyph sequences.  Oh well...
  // Test case: U+0643,U+0640,U+0631.

  // planner.ot_map.enable_feature(feature::CONTEXTUAL_SWASH, F_MANUAL_ZWJ, 1);
  planner.ot_map.enable_feature(tag("mset"), F_MANUAL_ZWJ, 1)
}

///|
/// `arabic_shape_plan_t`.
priv struct ArabicShapePlan {
  // The "+ 1" in the next array is to accommodate for the "NONE" command,
  // which is not an OpenType feature, but this simplifies the code by not
  // having to do a "if (... < NONE) ..." and just rely on the fact that
  // mask_array[NONE] == 0.
  mask_array : FixedArray[UInt]
  has_stch : Bool
}

///|
fn data_create_arabic(plan : ShapePlan) -> ArabicShapePlan {
  let has_stch = plan.ot_map.get_1_mask(tag("stch")) != 0
  let mask_array = FixedArray::make(arabic_features.length() + 1, 0U)
  for i in 0..<arabic_features.length() {
    mask_array[i] = plan.ot_map.get_1_mask(arabic_features[i])
  }
  { mask_array, has_stch, }
}

///|
fn arabic_plan_of(plan : ShapePlan) -> ArabicShapePlan {
  match plan.data {
    Arabic(d) => d
    _ => abort("arabic shaper: missing plan data")
  }
}

///|
fn arabic_joining(buffer : Buffer) -> Unit {
  let mut prev : Int? = None
  let mut state = 0

  // Check pre-context.
  for i in 0..<buffer.context_len[0] {
    let c = buffer.context[0][i]
    let this_type = get_joining_type(c, char_general_category(c))
    if this_type == JOINING_TYPE_T {
      continue
    }
    state = arabic_state_table[state][this_type].2
    break
  }
  for i in 0..<buffer.len {
    let this_type = get_joining_type(
      buffer.info[i].as_char(),
      buffer.info[i].get_general_category(),
    )
    if this_type == JOINING_TYPE_T {
      buffer.info[i].set_arabic_shaping_action(ARABIC_ACTION_NONE)
      continue
    }
    let entry = arabic_state_table[state][this_type]
    if entry.0 != ARABIC_ACTION_NONE && prev is Some(_) {
      if prev is Some(prev) {
        buffer.info[prev].set_arabic_shaping_action(entry.0)
        buffer.safe_to_insert_tatweel(Some(prev), Some(i + 1))
      }
    } else if prev is Some(prev) {
      // States that have a possible prev_action.
      if this_type >= JOINING_TYPE_R || (2 <= state && state <= 5) {
        buffer.unsafe_to_concat(Some(prev), Some(i + 1))
      }
    } else if this_type >= JOINING_TYPE_R {
      buffer.unsafe_to_concat_from_outbuffer(Some(0), Some(i + 1))
    }
    buffer.info[i].set_arabic_shaping_action(entry.1)
    prev = Some(i)
    state = entry.2
  }
  for i in 0..<buffer.context_len[1] {
    let c = buffer.context[1][i]
    let this_type = get_joining_type(c, char_general_category(c))
    if this_type == JOINING_TYPE_T {
      continue
    }
    let entry = arabic_state_table[state][this_type]
    if entry.0 != ARABIC_ACTION_NONE && prev is Some(_) {
      if prev is Some(prev) {
        buffer.info[prev].set_arabic_shaping_action(entry.0)
        buffer.safe_to_insert_tatweel(Some(prev), Some(buffer.len))
      }
    } else if 2 <= state && state <= 5 {
      // States that have a possible prev_action.
      if prev is Some(prev) {
        buffer.unsafe_to_concat(Some(prev), Some(buffer.len))
      }
    }
    break
  }
}

///|
fn mongolian_variation_selectors(buffer : Buffer) -> Unit {
  // Copy arabic_shaping_action() from base to Mongolian variation selectors.
  let len = buffer.len
  let info = buffer.info
  for i in 1..<len {
    let g = info[i].glyph_id
    if (g >= 0x180B && g <= 0x180D) || g == 0x180F {
      let a = info[i - 1].arabic_shaping_action()
      info[i].set_arabic_shaping_action(a)
    }
  }
}

///|
fn setup_masks_arabic_plan(
  plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Unit {
  let arabic_plan = arabic_plan_of(plan)
  setup_masks_inner(arabic_plan, plan.script, buffer)
}

///|
fn setup_masks_inner(
  arabic_plan : ArabicShapePlan,
  script : Script?,
  buffer : Buffer,
) -> Unit {
  arabic_joining(buffer)
  if script == Some(script_mongolian) {
    mongolian_variation_selectors(buffer)
  }
  for i in 0..<buffer.len {
    let info = buffer.info[i]
    info.mask = info.mask | arabic_plan.mask_array[info.arabic_shaping_action()]
  }
}

///|
fn arabic_fallback_shape(
  _plan : ShapePlan,
  _face : Face,
  _buffer : Buffer,
) -> Bool {
  false
}

///|
// Stretch feature: "stch".
// See example here:
// https://docs.microsoft.com/en-us/typography/script-development/syriac
// We implement this in a generic way, such that the Arabic subtending
// marks can use it as well.
fn record_stch(plan : ShapePlan, _face : Face, buffer : Buffer) -> Bool {
  let arabic_plan = arabic_plan_of(plan)
  if !arabic_plan.has_stch {
    return false
  }

  // 'stch' feature was just applied.  Look for anything that multiplied,
  // and record it for stch treatment later.  Note that rtlm, frac, etc
  // are applied before stch, but we assume that they didn't result in
  // anything multiplying into 5 pieces, so it's safe-ish...

  let len = buffer.len
  let info = buffer.info
  let mut has_stch = false
  for i in 0..<len {
    let glyph_info = info[i]
    if glyph_info.multiplied() {
      let comp = if glyph_info.get_lig_comp() % 2 != 0 {
        ARABIC_ACTION_STRETCHING_REPEATING
      } else {
        ARABIC_ACTION_STRETCHING_FIXED
      }
      glyph_info.set_arabic_shaping_action(comp)
      has_stch = true
    }
  }
  if has_stch {
    buffer.scratch_flags = buffer.scratch_flags |
      HB_BUFFER_SCRATCH_FLAG_ARABIC_HAS_STCH
  }
  false
}

///|
fn apply_stch(face : Face, buffer : Buffer) -> Unit {
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_ARABIC_HAS_STCH) == 0 {
    return
  }
  let rtl = buffer.direction == RightToLeft
  if !rtl {
    buffer.reverse()
  }

  // We do a two pass implementation:
  // First pass calculates the exact number of extra glyphs we need,
  // We then enlarge buffer to have that much room,
  // Second pass applies the stretch, copying things to the end of buffer.

  let mut extra_glyphs_needed = 0 // Set during MEASURE, used during CUT
  let measure = 0
  let cut = 1
  for step in 0..<2 {
    let new_len = buffer.len + extra_glyphs_needed // write head during CUT
    let mut i = buffer.len
    let mut j = new_len
    while i != 0 {
      if !arabic_action_is_stch(buffer.info[i - 1].arabic_shaping_action()) {
        if step == cut {
          j -= 1
          buffer.info[j].assign(buffer.info[i - 1])
          buffer.pos[j].assign(buffer.pos[i - 1])
        }
        i -= 1
        continue
      }

      // Yay, justification!

      let mut w_total = 0 // Total to be filled
      let mut w_fixed = 0 // Sum of fixed tiles
      let mut w_repeating = 0 // Sum of repeating tiles
      let mut n_repeating = 0
      let end = i
      while i != 0 &&
            arabic_action_is_stch(buffer.info[i - 1].arabic_shaping_action()) {
        i -= 1
        let width = face.glyph_h_advance(buffer.info[i].as_glyph())
        if buffer.info[i].arabic_shaping_action() ==
          ARABIC_ACTION_STRETCHING_FIXED {
          w_fixed += width
        } else {
          w_repeating += width
          n_repeating += 1
        }
      }
      let start = i
      let mut context = i
      while context != 0 &&
            !arabic_action_is_stch(
              buffer.info[context - 1].arabic_shaping_action(),
            ) &&
            (
              buffer.info[context - 1].is_default_ignorable() ||
              is_word_category(buffer.info[context - 1].get_general_category())
            ) {
        context -= 1
        w_total += buffer.pos[context].x_advance
      }
      i += 1 // Don't touch i again.

      // Number of additional times to repeat each repeating tile.
      let mut n_copies = 0
      let mut w_remaining = w_total - w_fixed
      if w_remaining > w_repeating && w_repeating > 0 {
        n_copies = w_remaining / w_repeating - 1
      }

      // See if we can improve the fit by adding an extra repeat and squeezing them together a bit.
      let mut extra_repeat_overlap = 0
      let shortfall = w_remaining - w_repeating * (n_copies + 1)
      if shortfall > 0 && n_repeating > 0 {
        n_copies += 1
        let excess = (n_copies + 1) * w_repeating - w_remaining
        if excess > 0 {
          extra_repeat_overlap = excess / (n_copies * n_repeating)
          w_remaining = 0
        }
      }
      if step == measure {
        extra_glyphs_needed += n_copies * n_repeating
      } else {
        buffer.unsafe_to_break(Some(context), Some(end))
        let mut x_offset = w_remaining / 2
        for k = end; k >= start + 1; k = k - 1 {
          let width = face.glyph_h_advance(buffer.info[k - 1].as_glyph())
          let mut repeat = 1
          if buffer.info[k - 1].arabic_shaping_action() ==
            ARABIC_ACTION_STRETCHING_REPEATING {
            repeat += n_copies
          }
          buffer.pos[k - 1].x_advance = 0
          for n in 0..<repeat {
            if rtl {
              x_offset -= width
              if n > 0 {
                x_offset += extra_repeat_overlap
              }
            }
            buffer.pos[k - 1].x_offset = x_offset

            // Append copy.
            j -= 1
            buffer.info[j].assign(buffer.info[k - 1])
            buffer.pos[j].assign(buffer.pos[k - 1])
            if !rtl {
              x_offset += width
              if n > 0 {
                x_offset -= extra_repeat_overlap
              }
            }
          }
        }
      }
      i -= 1
    }
    if step == measure {
      if !buffer.ensure(buffer.len + extra_glyphs_needed) {
        break
      }
    } else {
      // debug_assert_eq!(j, 0);
      buffer.len = new_len
    }
  }
  if !rtl {
    buffer.reverse()
  }
}

///|
fn postprocess_glyphs_arabic(
  _plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  apply_stch(face, buffer)
}

///|
// http://www.unicode.org/reports/tr53/
let modifier_combining_marks : ReadOnlyArray[UInt] = [
  0x0654, // ARABIC HAMZA ABOVE
   0x0655, // ARABIC HAMZA BELOW
   0x0658, // ARABIC MARK NOON GHUNNA
   0x06DC, // ARABIC SMALL HIGH SEEN
   0x06E3, // ARABIC SMALL LOW SEEN
   0x06E7, // ARABIC SMALL HIGH YEH
   0x06E8, // ARABIC SMALL HIGH NOON
   0x08CA, // ARABIC SMALL HIGH FARSI YEH
   0x08CB, // ARABIC SMALL HIGH YEH BARREE WITH TWO DOTS BELOW
   0x08CD, // ARABIC SMALL HIGH ZAH
   0x08CE, // ARABIC LARGE ROUND DOT ABOVE
   0x08CF, // ARABIC LARGE ROUND DOT BELOW
   0x08D3, // ARABIC SMALL LOW WAW
   0x08F3, // ARABIC SMALL HIGH WAW
]

///|
/// `modified_combining_class::CCC22` (meteg).
const MODIFIED_CCC22 : Int = 25

///|
/// `modified_combining_class::CCC26` (point varika).
const MODIFIED_CCC26 : Int = 26

///|
fn reorder_marks_arabic(
  _plan : ShapePlan,
  buffer : Buffer,
  start : Int,
  end : Int,
) -> Unit {
  let mut start = start
  let mut i = start
  for cc in [220, 230] {
    while i < end && buffer.info[i].get_modified_combining_class() < cc {
      i += 1
    }
    if i == end {
      break
    }
    if buffer.info[i].get_modified_combining_class() > cc {
      continue
    }
    let mut j = i
    while j < end &&
          buffer.info[j].get_modified_combining_class() == cc &&
          modifier_combining_marks.contains(buffer.info[j].glyph_id) {
      j += 1
    }
    if i == j {
      continue
    }

    // Shift it!
    guard! j - i <= MAX_COMBINING_MARKS
    buffer.merge_clusters(start, j)
    let temp = []
    for k in i..<j {
      temp.push(buffer.info[k].copy())
    }
    for k = i - start - 1; k >= 0; k = k - 1 {
      buffer.info[k + start + j - i].assign(buffer.info[k + start])
    }
    for k in 0..<(j - i) {
      buffer.info[start + k].assign(temp[k])
    }

    // Renumber CC such that the reordered sequence is still sorted.
    // 22 and 26 are chosen because they are smaller than all Arabic categories,
    // and are folded back to 220/230 respectively during fallback mark positioning.
    //
    // We do this because the CGJ-handling logic in the normalizer relies on
    // mark sequences having an increasing order even after this reordering.
    // https://github.com/harfbuzz/harfbuzz/issues/554
    // This, however, does break some obscure sequences, where the normalizer
    // might compose a sequence that it should not.  For example, in the seequence
    // ALEF, HAMZAH, MADDAH, we should NOT try to compose ALEF+MADDAH, but with this
    // renumbering, we will.
    let new_start = start + j - i
    let new_cc = if cc == 220 { MODIFIED_CCC22 } else { MODIFIED_CCC26 }
    while start < new_start {
      buffer.info[start].set_modified_combining_class(new_cc)
      start += 1
    }
    i = j
  }
}

///|
let arabic_shaper : OtShaper = {
  collect_features: Some(collect_features_arabic),
  override_features: None,
  create_data: Some(plan => Arabic(data_create_arabic(plan))),
  preprocess_text: None,
  postprocess_glyphs: Some(postprocess_glyphs_arabic),
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_AUTO,
  decompose: None,
  compose: None,
  setup_masks: Some(setup_masks_arabic_plan),
  gpos_tag: None,
  reorder_marks: Some(reorder_marks_arabic),
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_LATE,
  fallback_position: true,
}
