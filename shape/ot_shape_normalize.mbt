// Port of rustybuzz 0.20.1 `src/hb/ot_shape_normalize.rs`.

///|
priv struct NormalizeContext {
  plan : ShapePlan
  buffer : Buffer
  face : Face
  mut decompose : DecomposeFn
  mut compose : ComposeFn
}

///|
type DecomposeFn = (NormalizeContext, Int) -> (Int, Int)?

///|
type ComposeFn = (NormalizeContext, Int, Int) -> Int?

///|
fn NormalizeContext::override_decompose_and_compose(
  self : NormalizeContext,
  decompose : DecomposeFn?,
  compose : ComposeFn?,
) -> Unit {
  if decompose is Some(decompose) {
    self.decompose = decompose
  }
  if compose is Some(compose) {
    self.compose = compose
  }
}

///|
const HB_OT_SHAPE_NORMALIZATION_MODE_NONE : Int = 0

///|
const HB_OT_SHAPE_NORMALIZATION_MODE_DECOMPOSED : Int = 1

///|
/// Never composes base-to-base
const HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS : Int = 2

///|
/// Always fully decomposes and then recompose back
const HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT : Int = 3

///|
/// See hb-ot-shape-normalize.cc for logic.
const HB_OT_SHAPE_NORMALIZATION_MODE_AUTO : Int = 4

// HIGHLEVEL DESIGN:
//
// This file exports one main function: normalize().
//
// This function closely reflects the Unicode Normalization Algorithm,
// yet it's different.
//
// Each shaper specifies whether it prefers decomposed (NFD) or composed (NFC).
// The logic however tries to use whatever the font can support.
//
// In general what happens is that: each grapheme is decomposed in a chain
// of 1:2 decompositions, marks reordered, and then recomposed if desired,
// so far it's like Unicode Normalization.  However, the decomposition and
// recomposition only happens if the font supports the resulting characters.
//
// The goals are:
//
//   - Try to render all canonically equivalent strings similarly.  To really
//     achieve this we have to always do the full decomposition and then
//     selectively recompose from there.  It's kinda too expensive though, so
//     we skip some cases.  For example, if composed is desired, we simply
//     don't touch 1-character clusters that are supported by the font, even
//     though their NFC may be different.
//
//   - When a font has a precomposed character for a sequence but the 'ccmp'
//     feature in the font is not adequate, use the precomposed character
//     which typically has better mark positioning.
//
//   - When a font does not support a combining mark, but supports it precomposed
//     with previous base, use that.  This needs the itemizer to have this
//     knowledge too.  We need to provide assistance to the itemizer.
//
//   - When a font does not support a character but supports its canonical
//     decomposition, well, use the decomposition.
//
//   - The shapers can customize the compose and decompose functions to
//     offload some of their requirements to the normalizer.  For example, the
//     Indic shaper may want to disallow recomposing of two matras.

///|
fn decompose_unicode(_ctx : NormalizeContext, ab : Int) -> (Int, Int)? {
  decompose(ab)
}

///|
fn compose_unicode(_ctx : NormalizeContext, a : Int, b : Int) -> Int? {
  compose(a, b)
}

///|
fn set_glyph(info : GlyphInfo, font : Face) -> Unit {
  if font.get_nominal_glyph(info.glyph_id.reinterpret_as_int())
    is Some(glyph_id) {
    info.set_glyph_index(glyph_id.0.to_uint())
  }
}

///|
fn output_char(buffer : Buffer, unichar : UInt, glyph : UInt) -> Unit {
  // This is very confusing indeed.
  buffer.cur(0).set_glyph_index(glyph)
  buffer.output_glyph(unichar)
  // TODO: should be _hb_glyph_info_set_unicode_props (&buffer->prev(), buffer);
  buffer.prev().init_unicode_props(buffer)
}

///|
fn next_char(buffer : Buffer, glyph : UInt) -> Unit {
  buffer.cur(0).set_glyph_index(glyph)
  buffer.next_glyph()
}

///|
fn skip_char(buffer : Buffer) -> Unit {
  buffer.skip_glyph()
}

///|
/// Returns 0 if didn't decompose, number of resulting characters otherwise.
fn decompose_char(ctx : NormalizeContext, shortest : Bool, ab : Int) -> Int {
  let (a, b) = match (ctx.decompose)(ctx, ab) {
    Some(decomposed) => decomposed
    _ => return 0
  }
  let a_glyph = ctx.face.get_nominal_glyph(a)
  let b_glyph = if b != 0 {
    match ctx.face.get_nominal_glyph(b) {
      Some(glyph_id) => Some(glyph_id)
      None => return 0
    }
  } else {
    None
  }
  if !shortest || a_glyph is None {
    let ret = decompose_char(ctx, shortest, a)
    if ret != 0 {
      if b_glyph is Some(b_glyph) {
        output_char(ctx.buffer, b.reinterpret_as_uint(), b_glyph.0.to_uint())
        return ret + 1
      }
      return ret
    }
  }
  if a_glyph is Some(a_glyph) {
    // Output a and b.
    output_char(ctx.buffer, a.reinterpret_as_uint(), a_glyph.0.to_uint())
    if b_glyph is Some(b_glyph) {
      output_char(ctx.buffer, b.reinterpret_as_uint(), b_glyph.0.to_uint())
      return 2
    }
    return 1
  }
  0
}

///|
fn decompose_current_character(ctx : NormalizeContext, shortest : Bool) -> Unit {
  let u = ctx.buffer.cur(0).as_char()
  let glyph = ctx.face.get_nominal_glyph(u)

  // TODO: different to harfbuzz, sync
  if !shortest || glyph is None {
    if decompose_char(ctx, shortest, u) > 0 {
      skip_char(ctx.buffer)
      return
    }
  }

  // TODO: different to harfbuzz, sync
  if glyph is Some(glyph) {
    next_char(ctx.buffer, glyph.0.to_uint())
    return
  }
  if ctx.buffer.cur(0).is_unicode_space() {
    let space_type = char_space_fallback(u)
    if space_type != NOT_SPACE {
      let space_glyph = match ctx.face.get_nominal_glyph(0x0020) {
        Some(g) => Some(g)
        None => ctx.buffer.invisible
      }
      if space_glyph is Some(space_glyph) {
        ctx.buffer.cur(0).set_unicode_space_fallback_type(space_type)
        next_char(ctx.buffer, space_glyph.0.to_uint())
        ctx.buffer.scratch_flags = ctx.buffer.scratch_flags |
          HB_BUFFER_SCRATCH_FLAG_HAS_SPACE_FALLBACK
        return
      }
    }
  }

  // U+2011 is the only sensible character that is a no-break version of another character
  // and not a space.  The space ones are handled already.  Handle this lone one.
  if u == 0x2011 {
    if ctx.face.get_nominal_glyph(0x2010) is Some(other_glyph) {
      next_char(ctx.buffer, other_glyph.0.to_uint())
      return
    }
  }

  // Insert a .notdef glyph if decomposition failed.
  next_char(ctx.buffer, 0)
}

///|
fn handle_variation_selector_cluster(
  ctx : NormalizeContext,
  end : Int,
  _short_circuit : Bool,
) -> Unit {
  let face = ctx.face

  // Currently if there's a variation-selector we give-up on normalization, it's just too hard.
  let buffer = ctx.buffer
  while buffer.idx < end - 1 && buffer.successful {
    if char_is_variation_selector(buffer.cur(1).as_char()) {
      match
        face.ttfp_face.glyph_variation_index(
          buffer.cur(0).as_char().unsafe_to_char(),
          buffer.cur(1).as_char().unsafe_to_char(),
        ) {
        Some(glyph_id) => {
          buffer.cur(0).set_glyph_index(glyph_id.0.to_uint())
          let unicode = buffer.cur(0).glyph_id
          buffer.replace_glyphs(2, 1, [unicode])
        }
        None => {
          // Just pass on the two characters separately, let GSUB do its magic.
          set_glyph(buffer.cur(0), face)
          buffer.next_glyph()
          buffer.scratch_flags = buffer.scratch_flags |
            HB_BUFFER_SCRATCH_FLAG_HAS_VARIATION_SELECTOR_FALLBACK
          buffer.cur(0).set_variation_selector(true)
          if buffer.not_found_variation_selector is Some(_) {
            buffer.cur(0).clear_default_ignorable()
          }
          set_glyph(buffer.cur(0), face)
          buffer.next_glyph()
        }
      }

      // Skip any further variation selectors.
      while buffer.idx < end &&
            char_is_variation_selector(buffer.cur(0).as_char()) {
        set_glyph(buffer.cur(0), face)
        buffer.next_glyph()
      }
    } else {
      set_glyph(buffer.cur(0), face)
      buffer.next_glyph()
    }
  }
  if ctx.buffer.idx < end {
    set_glyph(ctx.buffer.cur(0), face)
    ctx.buffer.next_glyph()
  }
}

///|
fn decompose_multi_char_cluster(
  ctx : NormalizeContext,
  end : Int,
  short_circuit : Bool,
) -> Unit {
  let mut i = ctx.buffer.idx
  while i < end && ctx.buffer.successful {
    if char_is_variation_selector(ctx.buffer.info[i].as_char()) {
      handle_variation_selector_cluster(ctx, end, short_circuit)
      return
    }
    i += 1
  }
  while ctx.buffer.idx < end && ctx.buffer.successful {
    decompose_current_character(ctx, short_circuit)
  }
}

///|
fn compare_combining_class(pa : GlyphInfo, pb : GlyphInfo) -> Bool {
  let a = pa.get_modified_combining_class()
  let b = pb.get_modified_combining_class()
  a > b
}

///|
fn _hb_ot_shape_normalize(
  plan : ShapePlan,
  buffer : Buffer,
  face : Face,
) -> Unit {
  if buffer.is_empty() {
    return
  }
  let mut mode = plan.shaper.normalization_preference
  if mode == HB_OT_SHAPE_NORMALIZATION_MODE_AUTO {
    if plan.has_gpos_mark {
      // https://github.com/harfbuzz/harfbuzz/issues/653#issuecomment-423905920
      // mode = Some(HB_OT_SHAPE_NORMALIZATION_MODE_DECOMPOSED);
      mode = HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS
    } else {
      mode = HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS
    }
  }
  let ctx : NormalizeContext = {
    plan,
    buffer,
    face,
    decompose: decompose_unicode,
    compose: compose_unicode,
  }
  ctx.override_decompose_and_compose(plan.shaper.decompose, plan.shaper.compose)
  let always_short_circuit = mode == HB_OT_SHAPE_NORMALIZATION_MODE_NONE
  let might_short_circuit = always_short_circuit ||
    (
      mode != HB_OT_SHAPE_NORMALIZATION_MODE_DECOMPOSED &&
      mode !=
      HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT
    )

  // We do a fairly straightforward yet custom normalization process in three
  // separate rounds: decompose, reorder, recompose (if desired).  Currently
  // this makes two buffer swaps.  We can make it faster by moving the last
  // two rounds into the inner loop for the first round, but it's more readable
  // this way.

  // First round, decompose
  let mut all_simple = true
  {
    buffer.clear_output()
    let count = buffer.len
    buffer.idx = 0
    while true {
      let mut end = buffer.idx + 1
      while end < count && !buffer.info[end].is_unicode_mark() {
        end += 1
      }
      if end < count {
        // Leave one base for the marks to cluster with.
        end -= 1
      }

      // From idx to end are simple clusters.
      if might_short_circuit {
        let len = end - buffer.idx
        let mut done = 0
        while done < len {
          let cur = buffer.cur(done)
          match face.get_nominal_glyph(cur.glyph_id.reinterpret_as_int()) {
            Some(glyph_id) => cur.set_glyph_index(glyph_id.0.to_uint())
            None => break
          }
          done += 1
        }
        buffer.next_glyphs(done)
      }
      while buffer.idx < end && buffer.successful {
        decompose_current_character(ctx, might_short_circuit)
      }
      if buffer.idx == count || !buffer.successful {
        break
      }
      all_simple = false

      // Find all the marks now.
      end = buffer.idx + 1
      while end < count && buffer.info[end].is_unicode_mark() {
        end += 1
      }

      // idx to end is one non-simple cluster.
      decompose_multi_char_cluster(ctx, end, always_short_circuit)
      if buffer.idx >= count || !buffer.successful {
        break
      }
    }
    buffer.sync() |> ignore
  }

  // Second round, reorder (inplace)
  if !all_simple {
    let count = buffer.len
    let mut i = 0
    while i < count {
      if buffer.info[i].get_modified_combining_class() == 0 {
        i += 1
        continue
      }
      let mut end = i + 1
      while end < count && buffer.info[end].get_modified_combining_class() != 0 {
        end += 1
      }

      // We are going to do a O(n^2).  Only do this if the sequence is short.
      if end - i <= MAX_COMBINING_MARKS {
        buffer.sort(i, end, compare_combining_class)
        if ctx.plan.shaper.reorder_marks is Some(reorder_marks) {
          reorder_marks(ctx.plan, buffer, i, end)
        }
      }
      i = end + 1
    }
  }
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_CGJ) != 0 {
    // For all CGJ, check if it prevented any reordering at all.
    // If it did NOT, then make it skippable.
    // https://github.com/harfbuzz/harfbuzz/issues/554
    for i in 1..<imax(buffer.len - 1, 0) {
      if buffer.info[i].glyph_id == 0x034F {
        // CGJ
        let last = buffer.info[i - 1].get_modified_combining_class()
        let next = buffer.info[i + 1].get_modified_combining_class()
        if next == 0 || last <= next {
          buffer.info[i].unhide()
        }
      }
    }
  }

  // Third round, recompose
  if !all_simple &&
    buffer.successful &&
    (
      mode == HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS ||
      mode ==
      HB_OT_SHAPE_NORMALIZATION_MODE_COMPOSED_DIACRITICS_NO_SHORT_CIRCUIT
    ) {
    // As noted in the comment earlier, we don't try to combine
    // ccc=0 chars with their previous Starter.

    let count = buffer.len
    let mut starter = 0
    buffer.clear_output()
    buffer.next_glyph()
    while buffer.idx < count && buffer.successful {
      // We don't try to compose a non-mark character with it's preceding starter.
      // This is both an optimization to avoid trying to compose every two neighboring
      // glyphs in most scripts AND a desired feature for Hangul.  Apparently Hangul
      // fonts are not designed to mix-and-match pre-composed syllables and Jamo.
      let cur = buffer.cur(0)
      if cur.is_unicode_mark() &&
        // If there's anything between the starter and this char, they should have CCC
        // smaller than this character's.
        (
          starter == buffer.out_len - 1 ||
          buffer.prev().get_modified_combining_class() <
          cur.get_modified_combining_class()
        ) {
        let a = buffer.out_info()[starter].as_char()
        let b = cur.as_char()
        if (ctx.compose)(ctx, a, b) is Some(composed) {
          if face.get_nominal_glyph(composed) is Some(glyph_id) {
            // Copy to out-buffer.
            buffer.next_glyph()
            if !buffer.successful {
              return
            }

            // Merge and remove the second composable.
            buffer.merge_out_clusters(starter, buffer.out_len)
            buffer.out_len -= 1

            // Modify starter and carry on.
            let info = buffer.out_info()[starter]
            info.glyph_id = composed.reinterpret_as_uint()
            info.set_glyph_index(glyph_id.0.to_uint())
            info.init_unicode_props(buffer)
            continue
          }
        }
      }

      // Blocked, or doesn't compose.
      buffer.next_glyph()
      if buffer.prev().get_modified_combining_class() == 0 {
        starter = buffer.out_len - 1
      }
    }
    buffer.sync() |> ignore
  }
}
