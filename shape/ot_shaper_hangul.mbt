// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_hangul.rs`.
//
// The jamo constants (`L_BASE`, `V_BASE`, `T_BASE`, `L_COUNT`, `V_COUNT`,
// `T_COUNT`, `N_COUNT`, `S_COUNT`, `S_BASE`) are shared with `unicode.mbt`,
// which defines the same values.

///|
const LJMO : Int = 1

///|
const VJMO : Int = 2

///|
const TJMO : Int = 3

///|
fn GlyphInfo::hangul_shaping_feature(self : GlyphInfo) -> Int {
  self.ot_shaper_var_u8_auxiliary()
}

///|
fn GlyphInfo::set_hangul_shaping_feature(
  self : GlyphInfo,
  feature : Int,
) -> Unit {
  self.set_ot_shaper_var_u8_auxiliary(feature)
}

///|
fn collect_features_hangul(planner : ShapePlanner) -> Unit {
  planner.ot_map.add_feature(tag("ljmo"), F_NONE, 1)
  planner.ot_map.add_feature(tag("vjmo"), F_NONE, 1)
  planner.ot_map.add_feature(tag("tjmo"), F_NONE, 1)
}

///|
fn override_features_hangul(planner : ShapePlanner) -> Unit {
  // Uniscribe does not apply 'calt' for Hangul, and certain fonts
  // (Noto Sans CJK, Source Sans Han, etc) apply all of jamo lookups
  // in calt, which is not desirable.
  planner.ot_map.disable_feature(tag("calt"))
}

///|
/// `hangul_shape_plan_t`.
priv struct HangulShapePlan {
  mask_array : FixedArray[UInt]
}

///|
fn data_create_hangul(map : OtMap) -> HangulShapePlan {
  {
    mask_array: [
      0,
      map.get_1_mask(tag("ljmo")),
      map.get_1_mask(tag("vjmo")),
      map.get_1_mask(tag("tjmo")),
    ],
  }
}

///|
fn is_combining_l(u : Int) -> Bool {
  u >= L_BASE && u <= L_BASE + L_COUNT - 1
}

///|
fn is_combining_v(u : Int) -> Bool {
  u >= V_BASE && u <= V_BASE + V_COUNT - 1
}

///|
fn is_combining_t(u : Int) -> Bool {
  u >= T_BASE + 1 && u <= T_BASE + T_COUNT - 1
}

///|
fn is_combined_s(u : Int) -> Bool {
  u >= S_BASE && u <= S_BASE + S_COUNT - 1
}

///|
fn is_l(u : Int) -> Bool {
  (u >= 0x1100 && u <= 0x115F) || (u >= 0xA960 && u <= 0xA97C)
}

///|
fn is_v(u : Int) -> Bool {
  (u >= 0x1160 && u <= 0x11A7) || (u >= 0xD7B0 && u <= 0xD7C6)
}

///|
fn is_t(u : Int) -> Bool {
  (u >= 0x11A8 && u <= 0x11FF) || (u >= 0xD7CB && u <= 0xD7FB)
}

///|
fn is_hangul_tone(u : Int) -> Bool {
  u >= 0x302E && u <= 0x302F
}

///|
fn is_zero_width_char(face : Face, c : Int) -> Bool {
  if face.get_nominal_glyph(c) is Some(glyph) {
    face.glyph_h_advance(glyph) == 0
  } else {
    false
  }
}

///|
fn preprocess_text_hangul(
  _plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  // Hangul syllables come in two shapes: LV, and LVT.  Of those:
  //
  //   - LV can be precomposed, or decomposed.  Lets call those
  //     <LV> and <L,V>,
  //   - LVT can be fully precomposed, partially precomposed, or
  //     fully decomposed.  Ie. <LVT>, <LV,T>, or <L,V,T>.
  //
  // The composition / decomposition is mechanical.  However, not
  // all <L,V> sequences compose, and not all <LV,T> sequences
  // compose.
  //
  // Here are the specifics:
  //
  //   - <L>: U+1100..115F, U+A960..A97F
  //   - <V>: U+1160..11A7, U+D7B0..D7C7
  //   - <T>: U+11A8..11FF, U+D7CB..D7FB
  //
  //   - Only the <L,V> sequences for some of the U+11xx ranges combine.
  //   - Only <LV,T> sequences for some of the Ts in U+11xx range combine.
  //
  // Here is what we want to accomplish in this shaper:
  //
  //   - If the whole syllable can be precomposed, do that,
  //   - Otherwise, fully decompose and apply ljmo/vjmo/tjmo features.
  //   - If a valid syllable is followed by a Hangul tone mark, reorder the tone
  //     mark to precede the whole syllable - unless it is a zero-width glyph, in
  //     which case we leave it untouched, assuming it's designed to overstrike.
  //
  // That is, of the different possible syllables:
  //
  //   <L>
  //   <L,V>
  //   <L,V,T>
  //   <LV>
  //   <LVT>
  //   <LV, T>
  //
  // - <L> needs no work.
  //
  // - <LV> and <LVT> can stay the way they are if the font supports them, otherwise we
  //   should fully decompose them if font supports.
  //
  // - <L,V> and <L,V,T> we should compose if the whole thing can be composed.
  //
  // - <LV,T> we should compose if the whole thing can be composed, otherwise we should
  //   decompose.

  buffer.clear_output()
  // Extent of most recently seen syllable; valid only if start < end
  let mut start = 0
  let mut end = 0
  buffer.idx = 0
  while buffer.idx < buffer.len {
    let u = buffer.cur(0).glyph_id.reinterpret_as_int()
    let c = buffer.cur(0).as_char()
    if is_hangul_tone(u) {
      // We could cache the width of the tone marks and the existence of dotted-circle,
      // but the use of the Hangul tone mark characters seems to be rare enough that
      // I didn't bother for now.
      if start < end && end == buffer.out_len {
        // Tone mark follows a valid syllable; move it in front, unless it's zero width.
        buffer.unsafe_to_break_from_outbuffer(Some(start), Some(buffer.idx))
        buffer.next_glyph()
        if !is_zero_width_char(face, c) {
          buffer.merge_out_clusters(start, end + 1)
          let out_info = buffer.out_info()
          let tone = out_info[end].copy()
          for i = end - start - 1; i >= 0; i = i - 1 {
            out_info[i + start + 1].assign(out_info[i + start])
          }
          out_info[start].assign(tone)
        }
      } else if (buffer.flags & BUFFER_FLAG_DO_NOT_INSERT_DOTTED_CIRCLE) == 0 &&
        face.has_glyph(0x25CC) {
        // No valid syllable as base for tone mark; try to insert dotted circle.
        let chars : Array[UInt] = [0, 0]
        if !is_zero_width_char(face, c) {
          chars[0] = u.reinterpret_as_uint()
          chars[1] = 0x25CC
        } else {
          chars[0] = 0x25CC
          chars[1] = u.reinterpret_as_uint()
        }
        buffer.replace_glyphs(1, 2, chars)
      } else {
        // No dotted circle available in the font; just leave tone mark untouched.
        buffer.next_glyph()
      }
      start = buffer.out_len
      end = buffer.out_len
      continue
    }

    // Remember current position as a potential syllable start;
    // will only be used if we set end to a later position.
    start = buffer.out_len
    if is_l(u) && buffer.idx + 1 < buffer.len {
      let l = u
      let v = buffer.cur(1).glyph_id.reinterpret_as_int()
      if is_v(v) {
        // Have <L,V> or <L,V,T>.
        let mut t = 0
        let mut tindex = 0
        if buffer.idx + 2 < buffer.len {
          t = buffer.cur(2).glyph_id.reinterpret_as_int()
          if is_t(t) {
            // Only used if isCombiningT (t); otherwise invalid.
            tindex = t - T_BASE
          } else {
            // The next character was not a trailing jamo.
            t = 0
          }
        }
        let offset = if t != 0 { 3 } else { 2 }
        buffer.unsafe_to_break(Some(buffer.idx), Some(buffer.idx + offset))

        // We've got a syllable <L,V,T?>; see if it can potentially be composed.
        if is_combining_l(l) &&
          is_combining_v(v) &&
          (t == 0 || is_combining_t(t)) {
          // Try to compose; if this succeeds, end is set to start+1.
          let s = S_BASE +
            (l - L_BASE) * N_COUNT +
            (v - V_BASE) * T_COUNT +
            tindex
          if face.has_glyph(s) {
            let n = if t != 0 { 3 } else { 2 }
            buffer.replace_glyphs(n, 1, [s.reinterpret_as_uint()])
            end = start + 1
            continue
          }
        }

        // We didn't compose, either because it's an Old Hangul syllable without a
        // precomposed character in Unicode, or because the font didn't support the
        // necessary precomposed glyph.
        // Set jamo features on the individual glyphs, and advance past them.
        buffer.cur(0).set_hangul_shaping_feature(LJMO)
        buffer.next_glyph()
        buffer.cur(0).set_hangul_shaping_feature(VJMO)
        buffer.next_glyph()
        if t != 0 {
          buffer.cur(0).set_hangul_shaping_feature(TJMO)
          buffer.next_glyph()
          end = start + 3
        } else {
          end = start + 2
        }
        if buffer.cluster_level == HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES {
          buffer.merge_out_clusters(start, end)
        }
        continue
      }
    } else if is_combined_s(u) {
      // Have <LV>, <LVT>, or <LV,T>
      let s = u
      let has_glyph = face.has_glyph(s)
      let lindex = (s - S_BASE) / N_COUNT
      let nindex = (s - S_BASE) % N_COUNT
      let vindex = nindex / T_COUNT
      let tindex = nindex % T_COUNT
      if tindex == 0 &&
        buffer.idx + 1 < buffer.len &&
        is_combining_t(buffer.cur(1).glyph_id.reinterpret_as_int()) {
        // <LV,T>, try to combine.
        let new_tindex = buffer.cur(1).glyph_id.reinterpret_as_int() - T_BASE
        let new_s = s + new_tindex
        if face.has_glyph(new_s) {
          buffer.replace_glyphs(2, 1, [new_s.reinterpret_as_uint()])
          end = start + 1
          continue
        } else {
          // Mark unsafe between LV and T.
          buffer.unsafe_to_break(Some(buffer.idx), Some(buffer.idx + 2))
        }
      }

      // Otherwise, decompose if font doesn't support <LV> or <LVT>,
      // or if having non-combining <LV,T>.  Note that we already handled
      // combining <LV,T> above.
      if !has_glyph ||
        (
          tindex == 0 &&
          buffer.idx + 1 < buffer.len &&
          is_t(buffer.cur(1).glyph_id.reinterpret_as_int())
        ) {
        let decomposed = [L_BASE + lindex, V_BASE + vindex, T_BASE + tindex]
        if face.has_glyph(decomposed[0]) &&
          face.has_glyph(decomposed[1]) &&
          (tindex == 0 || face.has_glyph(decomposed[2])) {
          let mut s_len = if tindex != 0 { 3 } else { 2 }
          buffer.replace_glyphs(
            1,
            s_len,
            decomposed.map(x => x.reinterpret_as_uint()),
          )

          // If we decomposed an LV because of a non-combining T following,
          // we want to include this T in the syllable.
          if has_glyph && tindex == 0 {
            buffer.next_glyph()
            s_len += 1
          }

          // We decomposed S: apply jamo features to the individual glyphs
          // that are now in `buffer.out_info`.
          end = start + s_len
          buffer.out_info()[start + 0].set_hangul_shaping_feature(LJMO)
          buffer.out_info()[start + 1].set_hangul_shaping_feature(VJMO)
          if start + 2 < end {
            buffer.out_info()[start + 2].set_hangul_shaping_feature(TJMO)
          }
          if buffer.cluster_level == HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES {
            buffer.merge_out_clusters(start, end)
          }
          continue
        } else if tindex == 0 &&
          buffer.idx + 1 > buffer.len &&
          is_t(buffer.cur(1).glyph_id.reinterpret_as_int()) {
          // Mark unsafe between LV and T.
          buffer.unsafe_to_break(Some(buffer.idx), Some(buffer.idx + 2))
        }
      }
      if has_glyph {
        // We didn't decompose the S, so just advance past it.
        end = start + 1
        buffer.next_glyph()
        continue
      }
    }

    // Didn't find a recognizable syllable, so we leave end <= start;
    // this will prevent tone-mark reordering happening.
    buffer.next_glyph()
  }
  buffer.sync() |> ignore
}

///|
fn setup_masks_hangul(plan : ShapePlan, _face : Face, buffer : Buffer) -> Unit {
  let hangul_plan = match plan.data {
    Hangul(d) => d
    _ => abort("hangul shaper: missing plan data")
  }
  for i in 0..<buffer.len {
    let info = buffer.info[i]
    info.mask = info.mask |
      hangul_plan.mask_array[info.hangul_shaping_feature()]
  }
}

///|
let hangul_shaper : OtShaper = {
  name: "hangul",
  collect_features: Some(collect_features_hangul),
  override_features: Some(override_features_hangul),
  create_data: Some(plan => Hangul(data_create_hangul(plan.ot_map))),
  preprocess_text: Some(preprocess_text_hangul),
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_NONE,
  decompose: None,
  compose: None,
  setup_masks: Some(setup_masks_hangul),
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE,
  fallback_position: false,
}
