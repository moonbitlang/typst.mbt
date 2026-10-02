// Port of rustybuzz 0.20.1 `src/hb/ot_shape.rs`.

///|
priv struct ShapePlanner {
  face : Face
  direction : Direction
  script : Script?
  ot_map : OtMapBuilder
  apply_morx : Bool
  script_zero_marks : Bool
  script_fallback_mark_positioning : Bool
  shaper : OtShaper
}

///|
fn tag(s : String) -> @otf.Tag {
  @otf.Tag::from_str(s)
}

///|
fn ShapePlanner::new(
  face : Face,
  direction : Direction,
  script : Script?,
  language : Language?,
) -> ShapePlanner {
  let ot_map = OtMapBuilder::new(face, script, language)
  let mut shaper = match script {
    Some(script) =>
      hb_ot_shape_complex_categorize(
        script,
        direction,
        ot_map.chosen_script(GSUB),
      )
    None => default_shaper
  }
  let script_zero_marks = shaper.zero_width_marks !=
    HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE
  let script_fallback_mark_positioning = shaper.fallback_position

  // https://github.com/harfbuzz/harfbuzz/issues/2124
  let apply_morx = face.tables().morx is Some(_) &&
    (direction.is_horizontal() || face.gsub is None)

  // https://github.com/harfbuzz/harfbuzz/issues/1528
  if apply_morx && !physical_equal(shaper, default_shaper) {
    shaper = dumber_shaper
  }
  {
    face,
    direction,
    script,
    ot_map,
    apply_morx,
    script_zero_marks,
    script_fallback_mark_positioning,
    shaper,
  }
}

///|
fn ShapePlanner::collect_features(
  self : ShapePlanner,
  user_features : Array[Feature],
) -> Unit {
  let common_features = [
    (tag("abvm"), F_GLOBAL),
    (tag("blwm"), F_GLOBAL),
    (tag("ccmp"), F_GLOBAL),
    (tag("locl"), F_GLOBAL),
    (tag("mark"), F_GLOBAL_MANUAL_JOINERS),
    (tag("mkmk"), F_GLOBAL_MANUAL_JOINERS),
    (tag("rlig"), F_GLOBAL),
  ]
  let horizontal_features = [
    (tag("calt"), F_GLOBAL),
    (tag("clig"), F_GLOBAL),
    (tag("curs"), F_GLOBAL),
    (tag("dist"), F_GLOBAL),
    (tag("kern"), F_GLOBAL_HAS_FALLBACK),
    (tag("liga"), F_GLOBAL),
    (tag("rclt"), F_GLOBAL),
  ]
  let empty = F_NONE
  self.ot_map.is_simple = true
  self.ot_map.enable_feature(tag("rvrn"), empty, 1)
  self.ot_map.add_gsub_pause(None)
  match self.direction {
    LeftToRight => {
      self.ot_map.enable_feature(tag("ltra"), empty, 1)
      self.ot_map.enable_feature(tag("ltrm"), empty, 1)
    }
    RightToLeft => {
      self.ot_map.enable_feature(tag("rtla"), empty, 1)
      self.ot_map.add_feature(tag("rtlm"), empty, 1)
    }
    _ => ()
  }

  // Automatic fractions.
  self.ot_map.add_feature(tag("frac"), empty, 1)
  self.ot_map.add_feature(tag("numr"), empty, 1)
  self.ot_map.add_feature(tag("dnom"), empty, 1)

  // Random!
  self.ot_map.enable_feature(tag("rand"), F_RANDOM, MAX_VALUE)

  // Tracking.  We enable dummy feature here just to allow disabling
  // AAT 'trak' table using features.
  // https://github.com/harfbuzz/harfbuzz/issues/1303
  self.ot_map.enable_feature(tag("trak"), F_HAS_FALLBACK, 1)
  self.ot_map.enable_feature(tag("Harf"), empty, 1) // Considered required.
  self.ot_map.enable_feature(tag("HARF"), empty, 1) // Considered discretionary.
  if self.shaper.collect_features is Some(func) {
    self.ot_map.is_simple = false
    func(self)
  }
  self.ot_map.enable_feature(tag("Buzz"), empty, 1) // Considered required.
  self.ot_map.enable_feature(tag("BUZZ"), empty, 1) // Considered discretionary.
  for entry in common_features {
    self.ot_map.add_feature(entry.0, entry.1, 1)
  }
  if self.direction.is_horizontal() {
    for entry in horizontal_features {
      self.ot_map.add_feature(entry.0, entry.1, 1)
    }
  } else {
    // We only apply `vert` feature. See:
    // https://github.com/harfbuzz/harfbuzz/commit/d71c0df2d17f4590d5611239577a6cb532c26528
    // https://lists.freedesktop.org/archives/harfbuzz/2013-August/003490.html

    // We really want to find a 'vert' feature if there's any in the font, no
    // matter which script/langsys it is listed (or not) under.
    // See various bugs referenced from:
    // https://github.com/harfbuzz/harfbuzz/issues/63
    self.ot_map.enable_feature(tag("vert"), F_GLOBAL_SEARCH, 1)
  }
  if !user_features.is_empty() {
    self.ot_map.is_simple = false
  }
  for feature in user_features {
    let flags = if feature.is_global() { F_GLOBAL } else { empty }
    self.ot_map.add_feature(feature.tag, flags, feature.value)
  }
  if self.shaper.override_features is Some(func) {
    func(self)
  }
}

///|
fn ShapePlanner::compile(
  self : ShapePlanner,
  user_features : Array[Feature],
) -> ShapePlan {
  let ot_map = self.ot_map.compile()
  let frac_mask = ot_map.get_1_mask(tag("frac"))
  let numr_mask = ot_map.get_1_mask(tag("numr"))
  let dnom_mask = ot_map.get_1_mask(tag("dnom"))
  let has_frac = frac_mask != 0 || (numr_mask != 0 && dnom_mask != 0)
  let rtlm_mask = ot_map.get_1_mask(tag("rtlm"))
  let has_vert = ot_map.get_1_mask(tag("vert")) != 0
  let horizontal = self.direction.is_horizontal()
  let kern_tag = if horizontal { tag("kern") } else { tag("vkrn") }
  let kern_mask = ot_map.get_mask(kern_tag).0
  let requested_kerning = kern_mask != 0
  let trak_mask = ot_map.get_mask(tag("trak")).0
  let requested_tracking = trak_mask != 0
  let has_gpos_kern = ot_map.get_feature_index(GPOS, kern_tag) is Some(_)
  let disable_gpos = self.shaper.gpos_tag is Some(_) &&
    self.shaper.gpos_tag != ot_map.chosen_script(GPOS)

  // Decide who provides glyph classes. GDEF or Unicode.
  let fallback_glyph_classes = !hb_ot_layout_has_glyph_classes(self.face)

  // Decide who does substitutions. GSUB, morx, or fallback.
  let apply_morx = self.apply_morx
  let mut apply_gpos = false
  let mut apply_kerx = false
  let mut apply_kern = false

  // Decide who does positioning. GPOS, kerx, kern, or fallback.
  let has_kerx = self.face.tables().kerx is Some(_)
  let has_gsub = !apply_morx && self.face.tables().gsub is Some(_)
  let has_gpos = !disable_gpos && self.face.tables().gpos is Some(_)

  // Prefer GPOS over kerx if GSUB is present;
  // https://github.com/harfbuzz/harfbuzz/issues/3008
  if has_kerx && !(has_gsub && has_gpos) {
    apply_kerx = true
  } else if has_gpos {
    apply_gpos = true
  }
  if !apply_kerx && (!has_gpos_kern || !apply_gpos) {
    if has_kerx {
      apply_kerx = true
    } else if hb_ot_layout_has_kerning(self.face) {
      apply_kern = true
    }
  }
  let apply_fallback_kern = !(apply_gpos || apply_kerx || apply_kern)
  let zero_marks = self.script_zero_marks &&
    !apply_kerx &&
    (!apply_kern || !hb_ot_layout_has_machine_kerning(self.face))
  let has_gpos_mark = ot_map.get_1_mask(tag("mark")) != 0
  let mut adjust_mark_positioning_when_zeroing = !apply_gpos &&
    !apply_kerx &&
    (!apply_kern || !hb_ot_layout_has_cross_kerning(self.face))
  let fallback_mark_positioning = adjust_mark_positioning_when_zeroing &&
    self.script_fallback_mark_positioning

  // If we're using morx shaping, we cancel mark position adjustment because
  // Apple Color Emoji assumes this will NOT be done when forming emoji sequences;
  // https://github.com/harfbuzz/harfbuzz/issues/2967.
  if apply_morx {
    adjust_mark_positioning_when_zeroing = false
  }

  // Currently we always apply trak.
  let apply_trak = requested_tracking && self.face.tables().trak is Some(_)
  let plan : ShapePlan = {
    direction: self.direction,
    script: self.script,
    shaper: self.shaper,
    ot_map,
    data: NoData,
    frac_mask,
    numr_mask,
    dnom_mask,
    rtlm_mask,
    kern_mask,
    trak_mask,
    requested_kerning,
    has_frac,
    has_vert,
    has_gpos_mark,
    zero_marks,
    fallback_glyph_classes,
    fallback_mark_positioning,
    adjust_mark_positioning_when_zeroing,
    apply_gpos,
    apply_kern,
    apply_fallback_kern,
    apply_kerx,
    apply_morx,
    apply_trak,
    user_features: user_features.copy(),
  }
  if self.shaper.create_data is Some(func) {
    plan.data = func(plan)
  }
  plan
}

///|
priv struct ShapeContext {
  plan : ShapePlan
  face : Face
  buffer : Buffer
  // Transient stuff
  target_direction : Direction
}

///|
/// Pull it all together!
fn shape_internal(ctx : ShapeContext) -> Unit {
  ctx.buffer.enter()
  initialize_masks(ctx)
  set_unicode_props(ctx.buffer)
  insert_dotted_circle(ctx.buffer, ctx.face)
  form_clusters(ctx.buffer)
  ensure_native_direction(ctx.buffer)
  if ctx.plan.shaper.preprocess_text is Some(func) {
    func(ctx.plan, ctx.face, ctx.buffer)
  }
  substitute_pre(ctx)
  position_(ctx)
  substitute_post(ctx)
  propagate_flags(ctx.buffer)
  ctx.buffer.direction = ctx.target_direction
  ctx.buffer.leave()
}

///|
fn substitute_pre(ctx : ShapeContext) -> Unit {
  hb_ot_substitute_default(ctx)
  hb_ot_substitute_plan(ctx)
  if ctx.plan.apply_morx && ctx.plan.apply_gpos {
    hb_aat_layout_remove_deleted_glyphs(ctx.buffer)
  }
}

///|
fn substitute_post(ctx : ShapeContext) -> Unit {
  if ctx.plan.apply_morx && !ctx.plan.apply_gpos {
    hb_aat_layout_remove_deleted_glyphs(ctx.buffer)
  }
  deal_with_variation_selectors(ctx.buffer)
  hide_default_ignorables(ctx.buffer, ctx.face)
  if ctx.plan.shaper.postprocess_glyphs is Some(func) {
    func(ctx.plan, ctx.face, ctx.buffer)
  }
}

///|
fn hb_ot_substitute_default(ctx : ShapeContext) -> Unit {
  rotate_chars(ctx)
  _hb_ot_shape_normalize(ctx.plan, ctx.buffer, ctx.face)
  setup_masks(ctx)

  // This is unfortunate to go here, but necessary...
  if ctx.plan.fallback_mark_positioning {
    _hb_ot_shape_fallback_mark_position_recategorize_marks(
      ctx.plan,
      ctx.face,
      ctx.buffer,
    )
  }
  map_glyphs_fast(ctx.buffer)
}

///|
fn hb_ot_substitute_plan(ctx : ShapeContext) -> Unit {
  hb_ot_layout_substitute_start(ctx.face, ctx.buffer)
  if ctx.plan.fallback_glyph_classes {
    hb_synthesize_glyph_classes(ctx.buffer)
  }
  if ctx.plan.apply_morx {
    hb_aat_layout_substitute(ctx.plan, ctx.face, ctx.buffer)
  } else {
    substitute(ctx.plan, ctx.face, ctx.buffer)
  }
}

///|
fn position_(ctx : ShapeContext) -> Unit {
  ctx.buffer.clear_positions()
  position_default(ctx)
  position_complex(ctx)
  if ctx.buffer.direction.is_backward() {
    ctx.buffer.reverse()
  }
}

///|
fn position_default(ctx : ShapeContext) -> Unit {
  let len = ctx.buffer.len
  if ctx.buffer.direction.is_horizontal() {
    for i in 0..<len {
      ctx.buffer.pos[i].x_advance = ctx.face.glyph_h_advance(
        ctx.buffer.info[i].as_glyph(),
      )
    }
  } else {
    for i in 0..<len {
      let glyph = ctx.buffer.info[i].as_glyph()
      let pos = ctx.buffer.pos[i]
      pos.y_advance = ctx.face.glyph_v_advance(glyph)
      pos.x_offset -= ctx.face.glyph_h_origin(glyph)
      pos.y_offset -= ctx.face.glyph_v_origin(glyph)
    }
  }
  if (ctx.buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_SPACE_FALLBACK) != 0 {
    _hb_ot_shape_fallback_spaces(ctx.plan, ctx.face, ctx.buffer)
  }
}

///|
fn position_complex(ctx : ShapeContext) -> Unit {
  // If the font has no GPOS and direction is forward, then when
  // zeroing mark widths, we shift the mark with it, such that the
  // mark is positioned hanging over the previous glyph.  When
  // direction is backward we don't shift and it will end up
  // hanging over the next glyph after the final reordering.
  //
  // Note: If fallback positioning happens, we don't care about
  // this as it will be overridden.
  let adjust_offsets_when_zeroing = ctx.plan.adjust_mark_positioning_when_zeroing &&
    ctx.buffer.direction.is_forward()

  // We change glyph origin to what GPOS expects (horizontal), apply GPOS, change it back.

  gpos_position_start(ctx.face, ctx.buffer)
  if ctx.plan.zero_marks &&
    ctx.plan.shaper.zero_width_marks ==
    HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_EARLY {
    zero_mark_widths_by_gdef(ctx.buffer, adjust_offsets_when_zeroing)
  }
  position_by_plan(ctx.plan, ctx.face, ctx.buffer)
  if ctx.plan.zero_marks &&
    ctx.plan.shaper.zero_width_marks ==
    HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_LATE {
    zero_mark_widths_by_gdef(ctx.buffer, adjust_offsets_when_zeroing)
  }

  // Finish off.  Has to follow a certain order.
  gpos_position_finish_advances(ctx.face, ctx.buffer)
  zero_width_default_ignorables(ctx.buffer)
  if ctx.plan.apply_morx {
    hb_aat_layout_zero_width_deleted_glyphs(ctx.buffer)
  }
  gpos_position_finish_offsets(ctx.face, ctx.buffer)
  if ctx.plan.fallback_mark_positioning {
    position_marks(ctx.plan, ctx.face, ctx.buffer, adjust_offsets_when_zeroing)
  }
}

///|
fn position_by_plan(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit {
  if plan.apply_gpos {
    position(plan, face, buffer)
  } else if plan.apply_kerx {
    hb_aat_layout_position(plan, face, buffer)
  }
  if plan.apply_kern {
    hb_ot_layout_kern(plan, face, buffer)
  } else if plan.apply_fallback_kern {
    _hb_ot_shape_fallback_kern(plan, face, buffer)
  }
  if plan.apply_trak {
    hb_aat_layout_track(plan, face, buffer)
  }
}

///|
fn initialize_masks(ctx : ShapeContext) -> Unit {
  let global_mask = ctx.plan.ot_map.get_global_mask()
  ctx.buffer.reset_masks(global_mask)
}

///|
fn setup_masks(ctx : ShapeContext) -> Unit {
  setup_masks_fraction(ctx)
  if ctx.plan.shaper.setup_masks is Some(func) {
    func(ctx.plan, ctx.face, ctx.buffer)
  }
  for feature in ctx.plan.user_features {
    if !feature.is_global() {
      let (mask, shift) = ctx.plan.ot_map.get_mask(feature.tag)
      ctx.buffer.set_masks(
        feature.value << shift,
        mask,
        feature.start,
        feature.end,
      )
    }
  }
}

///|
fn setup_masks_fraction(ctx : ShapeContext) -> Unit {
  let buffer = ctx.buffer
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_NON_ASCII) == 0 ||
    !ctx.plan.has_frac {
    return
  }
  let (pre_mask, post_mask) = if buffer.direction.is_forward() {
    (
      ctx.plan.numr_mask | ctx.plan.frac_mask,
      ctx.plan.frac_mask | ctx.plan.dnom_mask,
    )
  } else {
    (
      ctx.plan.frac_mask | ctx.plan.dnom_mask,
      ctx.plan.numr_mask | ctx.plan.frac_mask,
    )
  }
  let len = buffer.len
  let mut i = 0
  while i < len {
    // FRACTION SLASH
    if buffer.info[i].glyph_id == 0x2044 {
      let mut start = i
      while start > 0 &&
            buffer.info[start - 1].get_general_category() == GC_DECIMAL_NUMBER {
        start -= 1
      }
      let mut end = i + 1
      while end < len &&
            buffer.info[end].get_general_category() == GC_DECIMAL_NUMBER {
        end += 1
      }
      if start == i || end == i + 1 {
        if start == i {
          buffer.unsafe_to_concat(Some(start), Some(start + 1))
        }
        if end == i + 1 {
          buffer.unsafe_to_concat(Some(end - 1), Some(end))
        }
        i += 1
        continue
      }
      buffer.unsafe_to_break(Some(start), Some(end))
      for k in start..<i {
        buffer.info[k].mask = buffer.info[k].mask | pre_mask
      }
      buffer.info[i].mask = buffer.info[i].mask | ctx.plan.frac_mask
      for k in (i + 1)..<end {
        buffer.info[k].mask = buffer.info[k].mask | post_mask
      }
      i = end
    } else {
      i += 1
    }
  }
}

///|
fn rb_flag(x : Int) -> UInt {
  1U << x
}

///|
/// FLAG_UNSAFE: 0 for out-of-range bits.
fn rb_flag_unsafe(x : Int) -> UInt {
  if x >= 0 && x < 32 {
    1U << x
  } else {
    0
  }
}

///|
/// FLAG_RANGE
fn rb_flag_range(x : Int, y : Int) -> UInt {
  (if x < y { 1U } else { 0U }) + rb_flag(y + 1) - rb_flag(x)
}

///|
/// FLAG64
fn rb_flag64(x : Int) -> UInt64 {
  1UL << x
}

///|
/// FLAG64_UNSAFE
fn rb_flag64_unsafe(x : Int) -> UInt64 {
  if x >= 0 && x < 64 {
    1UL << x
  } else {
    0
  }
}

///|
fn set_unicode_props(buffer : Buffer) -> Unit {
  // Implement enough of Unicode Graphemes here that shaping
  // in reverse-direction wouldn't break graphemes.  Namely,
  // we mark all marks and ZWJ and ZWJ,Extended_Pictographic
  // sequences as continuations.  The foreach_grapheme()
  // macro uses this bit.
  //
  // https://www.unicode.org/reports/tr29/#Regex_Definitions

  let len = buffer.len
  let mut i = 0
  while i < len {
    let info = buffer.info[i]
    info.init_unicode_props(buffer)
    let gen_cat = info.get_general_category()
    if (
        rb_flag_unsafe(gen_cat) &
        (
          rb_flag(GC_LOWERCASE_LETTER) |
          rb_flag(GC_UPPERCASE_LETTER) |
          rb_flag(GC_TITLECASE_LETTER) |
          rb_flag(GC_OTHER_LETTER) |
          rb_flag(GC_SPACE_SEPARATOR)
        )
      ) !=
      0 {
      i += 1
      continue
    }

    // Marks are already set as continuation by the above line.
    // Handle Emoji_Modifier and ZWJ-continuation.
    let cp = info.as_char()
    if gen_cat == GC_MODIFIER_SYMBOL && cp >= 0x1F3FB && cp <= 0x1F3FF {
      info.set_continuation()
    } else if i != 0 && cp >= 0x1F1E6 && cp <= 0x1F1FF {
      let prev = buffer.info[i - 1]
      let pc = prev.as_char()
      if pc >= 0x1F1E6 && pc <= 0x1F1FF && !prev.is_continuation() {
        info.set_continuation()
      }
    } else if info.is_zwj() {
      info.set_continuation()
      if i + 1 < len {
        let next = buffer.info[i + 1]
        if char_is_emoji_extended_pictographic(next.as_char()) {
          next.init_unicode_props(buffer)
          next.set_continuation()
          i += 1
        }
      }
    } else if (cp >= 0xFF9E && cp <= 0xFF9F) || (cp >= 0xE0020 && cp <= 0xE007F) {
      // Or part of the Other_Grapheme_Extend that is not marks.
      // As of Unicode 15 that is just:
      //
      // 200C          ; Other_Grapheme_Extend # Cf       ZERO WIDTH NON-JOINER
      // FF9E..FF9F    ; Other_Grapheme_Extend # Lm   [2] HALFWIDTH KATAKANA VOICED SOUND MARK..HALFWIDTH KATAKANA
      // SEMI-VOICED SOUND MARK E0020..E007F  ; Other_Grapheme_Extend # Cf  [96] TAG SPACE..CANCEL TAG
      //
      // ZWNJ is special, we don't want to merge it as there's no need, and keeping
      // it separate results in more granular clusters.
      // Tags are used for Emoji sub-region flag sequences:
      // https://github.com/harfbuzz/harfbuzz/issues/1556
      // Katakana ones were requested:
      // https://github.com/harfbuzz/harfbuzz/issues/3844
      info.set_continuation()
    }
    i += 1
  }
}

///|
fn syllabic_clear_var(_plan : ShapePlan, _face : Face, buffer : Buffer) -> Bool {
  for info in buffer.info {
    info.set_syllable(0)
  }
  false
}

///|
fn insert_dotted_circle(buffer : Buffer, face : Face) -> Unit {
  if (buffer.flags & BUFFER_FLAG_DO_NOT_INSERT_DOTTED_CIRCLE) == 0 &&
    (buffer.flags & BUFFER_FLAG_BEGINNING_OF_TEXT) != 0 &&
    buffer.context_len[0] == 0 &&
    buffer.info[0].is_unicode_mark() &&
    face.has_glyph(0x25CC) {
    let info : GlyphInfo = {
      glyph_id: 0x25CC,
      mask: buffer.cur(0).mask,
      cluster: buffer.cur(0).cluster,
      var1: 0,
      var2: 0,
    }
    info.init_unicode_props(buffer)
    buffer.clear_output()
    buffer.output_info(info)
    buffer.sync() |> ignore
  }
}

///|
fn form_clusters(buffer : Buffer) -> Unit {
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_NON_ASCII) != 0 {
    if buffer.cluster_level == HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES {
      buffer.foreach_grapheme((start, end) => buffer.merge_clusters(start, end))
    } else {
      buffer.foreach_grapheme((start, end) => {
        buffer.unsafe_to_break(Some(start), Some(end))
      })
    }
  }
}

///|
fn ensure_native_direction(buffer : Buffer) -> Unit {
  let dir = buffer.direction
  let mut hor = match buffer.script {
    Some(script) => Direction::from_script(script).unwrap_or(Invalid)
    None => Invalid
  }

  // Numeric runs in natively-RTL scripts are actually native-LTR, so we reset
  // the horiz_dir if the run contains at least one decimal-number char, and no
  // letter chars (ideally we should be checking for chars with strong
  // directionality but hb-unicode currently lacks bidi categories).
  //
  // This allows digit sequences in Arabic etc to be shaped in "native"
  // direction, so that features like ligatures will work as intended.
  //
  // https://github.com/harfbuzz/harfbuzz/issues/501
  //
  // Similar thing about Regional_Indicators; They are bidi=L, but Script=Common.
  // If they are present in a run of natively-RTL text, they get assigned a script
  // with natively RTL direction, which would result in wrong shaping if we
  // assign such native RTL direction to them then. Detect that as well.
  //
  // https://github.com/harfbuzz/harfbuzz/issues/3314

  if hor == RightToLeft && dir == LeftToRight {
    let mut found_number = false
    let mut found_letter = false
    let mut found_ri = false
    for info in buffer.info {
      let gc = info.get_general_category()
      if gc == GC_DECIMAL_NUMBER {
        found_number = true
      } else if gc_is_letter(gc) {
        found_letter = true
        break
      } else if info.glyph_id >= 0x1F1E6 && info.glyph_id <= 0x1F1FF {
        found_ri = true
      }
    }
    if (found_number || found_ri) && !found_letter {
      hor = LeftToRight
    }
  }

  // TODO vertical:
  // The only BTT vertical script is Ogham, but it's not clear to me whether OpenType
  // Ogham fonts are supposed to be implemented BTT or not.  Need to research that
  // first.
  if (dir.is_horizontal() && dir != hor && hor != Invalid) ||
    (dir.is_vertical() && dir != TopToBottom) {
    _hb_ot_layout_reverse_graphemes(buffer)
    buffer.direction = buffer.direction.reverse()
  }
}

///|
fn rotate_chars(ctx : ShapeContext) -> Unit {
  let len = ctx.buffer.len
  if ctx.target_direction.is_backward() {
    let rtlm_mask = ctx.plan.rtlm_mask
    for i in 0..<len {
      let info = ctx.buffer.info[i]
      if char_mirrored(info.as_char()) is Some(c) {
        if ctx.face.has_glyph(c) {
          info.glyph_id = c.reinterpret_as_uint()
          continue
        }
      }
      info.mask = info.mask | rtlm_mask
    }
  }
  if ctx.target_direction.is_vertical() && !ctx.plan.has_vert {
    for i in 0..<len {
      let info = ctx.buffer.info[i]
      if char_vertical(info.as_char()) is Some(c) {
        if ctx.face.has_glyph(c) {
          info.glyph_id = c.reinterpret_as_uint()
        }
      }
    }
  }
}

///|
fn map_glyphs_fast(buffer : Buffer) -> Unit {
  // Normalization process sets up glyph_index(), we just copy it.
  let len = buffer.len
  for i in 0..<len {
    let info = buffer.info[i]
    info.glyph_id = info.glyph_index()
  }
  let out = buffer.out_info()
  for i in 0..<len {
    let info = out[i]
    info.glyph_id = info.glyph_index()
  }
}

///|
fn hb_synthesize_glyph_classes(buffer : Buffer) -> Unit {
  let len = buffer.len
  for i in 0..<len {
    let info = buffer.info[i]
    // Never mark default-ignorables as marks.
    // They won't get in the way of lookups anyway,
    // but having them as mark will cause them to be skipped
    // over if the lookup-flag says so, but at least for the
    // Mongolian variation selectors, looks like Uniscribe
    // marks them as non-mark.  Some Mongolian fonts without
    // GDEF rely on this.  Another notable character that
    // this applies to is COMBINING GRAPHEME JOINER.
    let class = if info.get_general_category() != GC_NON_SPACING_MARK ||
      info.is_default_ignorable() {
      GLYPH_PROPS_BASE_GLYPH
    } else {
      GLYPH_PROPS_MARK
    }
    info.set_glyph_props(class)
  }
}

///|
fn zero_width_default_ignorables(buffer : Buffer) -> Unit {
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_DEFAULT_IGNORABLES) != 0 &&
    (buffer.flags & BUFFER_FLAG_PRESERVE_DEFAULT_IGNORABLES) == 0 &&
    (buffer.flags & BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES) == 0 {
    let len = buffer.len
    for i in 0..<len {
      if buffer.info[i].is_default_ignorable() {
        let pos = buffer.pos[i]
        pos.x_advance = 0
        pos.y_advance = 0
        pos.x_offset = 0
        pos.y_offset = 0
      }
    }
  }
}

///|
fn deal_with_variation_selectors(buffer : Buffer) -> Unit {
  if (
      buffer.scratch_flags &
      HB_BUFFER_SCRATCH_FLAG_HAS_VARIATION_SELECTOR_FALLBACK
    ) ==
    0 {
    return
  }

  // Note: In harfbuzz, this is part of the condition above (with OR), so it needs to stay
  // in sync.
  guard buffer.not_found_variation_selector is Some(nf) else { return }
  let count = buffer.len
  let info = buffer.info
  let pos = buffer.pos
  for i in 0..<count {
    if info[i].is_variation_selector() {
      info[i].glyph_id = nf
      pos[i].x_advance = 0
      pos[i].y_advance = 0
      pos[i].x_offset = 0
      pos[i].y_offset = 0
      info[i].set_variation_selector(false)
    }
  }
}

///|
fn zero_mark_widths_by_gdef(buffer : Buffer, adjust_offsets : Bool) -> Unit {
  let len = buffer.len
  for i in 0..<len {
    if buffer.info[i].is_mark() {
      let pos = buffer.pos[i]
      if adjust_offsets {
        pos.x_offset -= pos.x_advance
        pos.y_offset -= pos.y_advance
      }
      pos.x_advance = 0
      pos.y_advance = 0
    }
  }
}

///|
fn hide_default_ignorables(buffer : Buffer, face : Face) -> Unit {
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_DEFAULT_IGNORABLES) != 0 &&
    (buffer.flags & BUFFER_FLAG_PRESERVE_DEFAULT_IGNORABLES) == 0 {
    if (buffer.flags & BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES) == 0 {
      let invisible = match buffer.invisible {
        Some(g) => Some(g)
        None => face.get_nominal_glyph(' '.to_int())
      }
      if invisible is Some(invisible) {
        let len = buffer.len
        for i in 0..<len {
          if buffer.info[i].is_default_ignorable() {
            buffer.info[i].glyph_id = invisible.0.to_uint()
          }
        }
        return
      }
    }
    buffer.delete_glyphs_inplace(info => info.is_default_ignorable())
  }
}

///|
fn propagate_flags(buffer : Buffer) -> Unit {
  // Propagate cluster-level glyph flags to be the same on all cluster glyphs.
  // Simplifies using them.

  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_GLYPH_FLAGS) == 0 {
    return
  }

  // If we are producing SAFE_TO_INSERT_TATWEEL, then do two things:
  //
  // - If the places that the Arabic shaper marked as SAFE_TO_INSERT_TATWEEL,
  //   are UNSAFE_TO_BREAK, then clear the SAFE_TO_INSERT_TATWEEL,
  // - Any place that is SAFE_TO_INSERT_TATWEEL, is also now UNSAFE_TO_BREAK.
  //
  // We couldn't make this interaction earlier. It has to be done here.
  let flip_tatweel = (buffer.flags & BUFFER_FLAG_PRODUCE_SAFE_TO_INSERT_TATWEEL) !=
    0
  let clear_concat = (buffer.flags & BUFFER_FLAG_PRODUCE_UNSAFE_TO_CONCAT) == 0
  buffer.foreach_cluster((start, end) => {
    let mut mask : UInt = 0
    for i in start..<end {
      mask = mask | (buffer.info[i].mask & GLYPH_FLAG_DEFINED)
    }
    if flip_tatweel {
      if (mask & UNSAFE_TO_BREAK) != 0 {
        mask = mask & (SAFE_TO_INSERT_TATWEEL ^ 0xFFFFFFFF)
      }
      if (mask & SAFE_TO_INSERT_TATWEEL) != 0 {
        mask = mask | UNSAFE_TO_BREAK | UNSAFE_TO_CONCAT
      }
    }
    if clear_concat {
      mask = mask & (UNSAFE_TO_CONCAT ^ 0xFFFFFFFF)
      for i in start..<end {
        buffer.info[i].mask = mask
      }
    }
  })
}
