// Port of rustybuzz 0.20.1 `src/hb/ot_shape_fallback.rs`.

// CanonicalCombiningClass values used by the fallback positioning.

///|
const CCC_ATTACHED_BELOW_LEFT : Int = 200

///|
const CCC_ATTACHED_BELOW : Int = 202

///|
const CCC_ATTACHED_ABOVE : Int = 214

///|
const CCC_ATTACHED_ABOVE_RIGHT : Int = 216

///|
const CCC_BELOW_LEFT : Int = 218

///|
const CCC_BELOW : Int = 220

///|
const CCC_BELOW_RIGHT : Int = 222

///|
const CCC_ABOVE_LEFT : Int = 228

///|
const CCC_ABOVE : Int = 230

///|
const CCC_ABOVE_RIGHT : Int = 232

///|
const CCC_DOUBLE_BELOW : Int = 233

///|
const CCC_DOUBLE_ABOVE : Int = 234

///|
fn recategorize_combining_class(u : Int, class : Int) -> Int {
  let mut class = class
  if class >= 200 {
    return class
  }

  // Thai / Lao need some per-character work.
  if (u & (0xFF).lnot()) == 0x0E00 {
    if class == 0 {
      match u {
        0x0E31
        | 0x0E34
        | 0x0E35
        | 0x0E36
        | 0x0E37
        | 0x0E47
        | 0x0E4C
        | 0x0E4D
        | 0x0E4E => class = CCC_ABOVE_RIGHT
        0x0EB1 | 0x0EB4 | 0x0EB5 | 0x0EB6 | 0x0EB7 | 0x0EBB | 0x0ECC | 0x0ECD =>
          class = CCC_ABOVE
        0x0EBC => class = CCC_BELOW
        _ => ()
      }
    } else if u == 0x0E3A {
      // Thai virama is below-right
      class = CCC_BELOW_RIGHT
    }
  }

  // The patterns are the modified combining classes (`mcc::CCC*`).
  match class {
    // Hebrew
    22 => CCC_BELOW // sheva (CCC10)
    15 => CCC_BELOW // hataf segol (CCC11)
    16 => CCC_BELOW // hataf patah (CCC12)
    17 => CCC_BELOW // hataf qamats (CCC13)
    23 => CCC_BELOW // hiriq (CCC14)
    18 => CCC_BELOW // tsere (CCC15)
    19 => CCC_BELOW // segol (CCC16)
    20 => CCC_BELOW // patah (CCC17)
    21 => CCC_BELOW // qamats & qamats qatan (CCC18)
    24 => CCC_BELOW // qubuts (CCC20)
    25 => CCC_BELOW // meteg (CCC22)
    13 => CCC_ATTACHED_ABOVE // rafe (CCC23)
    10 => CCC_ABOVE_RIGHT // shin dot (CCC24)
    11 => CCC_ABOVE_LEFT // sin dot (CCC25)
    14 => CCC_ABOVE_LEFT // holam & holam haser for vav (CCC19)
    26 => CCC_ABOVE // point varika (CCC26)
    12 => class // dagesh (CCC21)

    // Arabic and Syriac
    28 => CCC_ABOVE // fathatan (CCC27)
    29 => CCC_ABOVE // dammatan (CCC28)
    31 => CCC_ABOVE // fatha (CCC30)
    32 => CCC_ABOVE // damma (CCC31)
    27 => CCC_ABOVE // shadda (CCC33)
    34 => CCC_ABOVE // sukun (CCC34)
    35 => CCC_ABOVE // superscript alef (CCC35)
    36 => CCC_ABOVE // superscript alaph (CCC36)
    30 => CCC_BELOW // kasratan (CCC29)
    33 => CCC_BELOW // kasra (CCC32)

    // Thai
    3 => CCC_BELOW_RIGHT // sara u / sara uu (CCC103)
    107 => CCC_ABOVE_RIGHT // mai (CCC107)

    // Lao
    118 => CCC_BELOW // sign u / sign uu (CCC118)
    122 => CCC_ABOVE // mai (CCC122)

    // Tibetian
    129 => CCC_BELOW // sign aa (CCC129)
    132 => CCC_ABOVE // sign i (CCC130)
    131 => CCC_BELOW // sign u (CCC132)
    _ => class
  }
}

///|
fn _hb_ot_shape_fallback_mark_position_recategorize_marks(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Unit {
  for i in 0..<buffer.len {
    let info = buffer.info[i]
    if info.get_general_category() == GC_NON_SPACING_MARK {
      let mut class = info.get_modified_combining_class()
      class = recategorize_combining_class(
        info.glyph_id.reinterpret_as_int(),
        class,
      )
      info.set_modified_combining_class(class)
    }
  }
}

///|
fn zero_mark_advances(
  buffer : Buffer,
  start : Int,
  end : Int,
  adjust_offsets_when_zeroing : Bool,
) -> Unit {
  for i in start..<end {
    let info = buffer.info[i]
    let pos = buffer.pos[i]
    if info.get_general_category() == GC_NON_SPACING_MARK {
      if adjust_offsets_when_zeroing {
        pos.x_offset -= pos.x_advance
        pos.y_offset -= pos.y_advance
      }
      pos.x_advance = 0
      pos.y_advance = 0
    }
  }
}

///|
fn position_mark(
  _plan : ShapePlan,
  face : Face,
  direction : Direction,
  glyph : @otf.GlyphId,
  pos : GlyphPosition,
  base_extents : GlyphExtents,
  combining_class : Int,
) -> Unit {
  let mark_extents = GlyphExtents::new()
  if !face.glyph_extents(glyph, mark_extents) {
    return
  }
  let y_gap = face.units_per_em / 16
  pos.x_offset = 0
  pos.y_offset = 0

  // We don't position LEFT and RIGHT marks.

  // X positioning
  match combining_class {
    CCC_DOUBLE_BELOW | CCC_DOUBLE_ABOVE if direction.is_horizontal() =>
      pos.x_offset += base_extents.x_bearing +
        (if direction.is_forward() { base_extents.width } else { 0 }) -
        mark_extents.width / 2 -
        mark_extents.x_bearing
    CCC_ATTACHED_BELOW_LEFT | CCC_BELOW_LEFT | CCC_ABOVE_LEFT =>
      // Left align.
      pos.x_offset += base_extents.x_bearing - mark_extents.x_bearing
    CCC_ATTACHED_ABOVE_RIGHT | CCC_BELOW_RIGHT | CCC_ABOVE_RIGHT =>
      // Right align.
      pos.x_offset += base_extents.x_bearing +
        base_extents.width -
        mark_extents.width -
        mark_extents.x_bearing
    _ =>
      // Center align.
      pos.x_offset += base_extents.x_bearing +
        (base_extents.width - mark_extents.width) / 2 -
        mark_extents.x_bearing
  }
  let is_attached = combining_class == CCC_ATTACHED_BELOW_LEFT ||
    combining_class == CCC_ATTACHED_BELOW ||
    combining_class == CCC_ATTACHED_ABOVE ||
    combining_class == CCC_ATTACHED_ABOVE_RIGHT

  // Y positioning.
  match combining_class {
    CCC_DOUBLE_BELOW
    | CCC_BELOW_LEFT
    | CCC_BELOW
    | CCC_BELOW_RIGHT
    | CCC_ATTACHED_BELOW_LEFT
    | CCC_ATTACHED_BELOW => {
      if !is_attached {
        // Add gap.
        base_extents.height -= y_gap
      }
      pos.y_offset = base_extents.y_bearing +
        base_extents.height -
        mark_extents.y_bearing

      // Never shift up "below" marks.
      if (y_gap > 0) == (pos.y_offset > 0) {
        base_extents.height -= pos.y_offset
        pos.y_offset = 0
      }
      base_extents.height += mark_extents.height
    }
    CCC_DOUBLE_ABOVE
    | CCC_ABOVE_LEFT
    | CCC_ABOVE
    | CCC_ABOVE_RIGHT
    | CCC_ATTACHED_ABOVE
    | CCC_ATTACHED_ABOVE_RIGHT => {
      if !is_attached {
        // Add gap.
        base_extents.y_bearing += y_gap
        base_extents.height -= y_gap
      }
      pos.y_offset = base_extents.y_bearing -
        (mark_extents.y_bearing + mark_extents.height)

      // Don't shift down "above" marks too much.
      if (y_gap > 0) != (pos.y_offset > 0) {
        let correction = -pos.y_offset / 2
        base_extents.y_bearing += correction
        base_extents.height -= correction
        pos.y_offset += correction
      }
      base_extents.y_bearing -= mark_extents.height
      base_extents.height += mark_extents.height
    }
    _ => ()
  }
}

///|
fn GlyphExtents::copy(self : GlyphExtents) -> GlyphExtents {
  { ..self, }
}

///|
fn position_around_base(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
  base : Int,
  end : Int,
  adjust_offsets_when_zeroing : Bool,
) -> Unit {
  let mut horizontal_dir = Invalid
  buffer.unsafe_to_break(Some(base), Some(end))
  let base_info = buffer.info[base]
  let base_pos = buffer.pos[base]
  let base_glyph = base_info.as_glyph()
  let base_extents = GlyphExtents::new()
  if !face.glyph_extents(base_glyph, base_extents) {
    zero_mark_advances(buffer, base + 1, end, adjust_offsets_when_zeroing)
    return
  }
  base_extents.y_bearing += base_pos.y_offset
  base_extents.x_bearing = 0

  // Use horizontal advance for horizontal positioning.
  // Generally a better idea. Also works for zero-ink glyphs. See:
  // https://github.com/harfbuzz/harfbuzz/issues/1532
  base_extents.width = face.glyph_h_advance(base_glyph)
  let lig_id = base_info.get_lig_id()
  let num_lig_components = base_info.get_lig_num_comps()
  let mut x_offset = 0
  let mut y_offset = 0
  if buffer.direction.is_forward() {
    x_offset -= base_pos.x_advance
    y_offset -= base_pos.y_advance
  }
  let mut last_lig_component = -1
  let mut last_combining_class = 255
  let mut component_extents = base_extents.copy()
  let mut cluster_extents = base_extents.copy()
  for k in (base + 1)..<end {
    let info = buffer.info[k]
    let pos = buffer.pos[k]
    if info.get_modified_combining_class() != 0 {
      if num_lig_components > 1 {
        let this_lig_id = info.get_lig_id()
        let mut this_lig_component = info.get_lig_comp() - 1

        // Conditions for attaching to the last component.
        if lig_id == 0 ||
          lig_id != this_lig_id ||
          this_lig_component >= num_lig_components {
          this_lig_component = num_lig_components - 1
        }
        if last_lig_component != this_lig_component {
          last_lig_component = this_lig_component
          last_combining_class = 255
          component_extents = base_extents.copy()
          if horizontal_dir == Invalid {
            horizontal_dir = if plan.direction.is_horizontal() {
              plan.direction
            } else {
              match plan.script {
                Some(script) =>
                  Direction::from_script(script).unwrap_or(LeftToRight)
                None => LeftToRight
              }
            }
          }
          component_extents.x_bearing += (if horizontal_dir == LeftToRight {
              this_lig_component
            } else {
              num_lig_components - 1 - this_lig_component
            }) *
            component_extents.width /
            num_lig_components
          component_extents.width = component_extents.width / num_lig_components
        }
      }
      let this_combining_class = info.get_modified_combining_class()
      if last_combining_class != this_combining_class {
        last_combining_class = this_combining_class
        cluster_extents = component_extents.copy()
      }
      position_mark(
        plan,
        face,
        buffer.direction,
        info.as_glyph(),
        pos,
        cluster_extents,
        conv_combining_class(this_combining_class),
      )
      pos.x_advance = 0
      pos.y_advance = 0
      pos.x_offset += x_offset
      pos.y_offset += y_offset
    } else if buffer.direction.is_forward() {
      x_offset -= pos.x_advance
      y_offset -= pos.y_advance
    } else {
      x_offset += pos.x_advance
      y_offset += pos.y_advance
    }
  }
}

///|
/// `conv_combining_class`: classes without a `CanonicalCombiningClass`
/// variant become NotReordered (0).
fn conv_combining_class(n : Int) -> Int {
  match n {
    1 | 6 | 7 | 8 | 9 => n
    10..=36 => n
    84 | 91 | 103 | 107 | 118 | 122 | 129 | 130 | 132 => n
    200
    | 202
    | 214
    | 216
    | 218
    | 220
    | 222
    | 224
    | 226
    | 228
    | 230
    | 232
    | 233
    | 234
    | 240 => n
    _ => 0
  }
}

///|
fn position_cluster(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
  start : Int,
  end : Int,
  adjust_offsets_when_zeroing : Bool,
) -> Unit {
  if end - start < 2 {
    return
  }

  // Find the base glyph
  let mut i = start
  while i < end {
    if !buffer.info[i].is_unicode_mark() {
      // Find mark glyphs
      let mut j = i + 1
      while j < end && buffer.info[j].is_unicode_mark() {
        j += 1
      }
      position_around_base(
        plan, face, buffer, i, j, adjust_offsets_when_zeroing,
      )
      i = j - 1
    }
    i += 1
  }
}

///|
fn position_marks(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
  adjust_offsets_when_zeroing : Bool,
) -> Unit {
  let mut start = 0
  let len = buffer.len
  for i in 1..<len {
    if !buffer.info[i].is_unicode_mark() {
      position_cluster(
        plan, face, buffer, start, i, adjust_offsets_when_zeroing,
      )
      start = i
    }
  }
  position_cluster(plan, face, buffer, start, len, adjust_offsets_when_zeroing)
}

///|
fn _hb_ot_shape_fallback_kern(
  _plan : ShapePlan,
  _face : Face,
  _buffer : Buffer,
) -> Unit {
  // STUB: this is deprecated in HarfBuzz
}

///|
fn _hb_ot_shape_fallback_spaces(
  _plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  let len = buffer.len
  let horizontal = buffer.direction.is_horizontal()
  for i in 0..<len {
    let info = buffer.info[i]
    let pos = buffer.pos[i]
    if info.is_unicode_space() && !info.ligated() {
      let space_type = info.get_unicode_space_fallback_type()
      match space_type {
        SPACE_EM
        | SPACE_EM_2
        | SPACE_EM_3
        | SPACE_EM_4
        | SPACE_EM_5
        | SPACE_EM_6
        | SPACE_EM_16 => {
          let length = (face.units_per_em + space_type / 2) / space_type
          if horizontal {
            pos.x_advance = length
          } else {
            pos.y_advance = -length
          }
        }
        SPACE_4_EM_18 => {
          let length = (face.units_per_em.to_int64() * 4L / 18L).to_int()
          if horizontal {
            pos.x_advance = length
          } else {
            pos.y_advance = -length
          }
        }
        SPACE_FIGURE =>
          for u in '0'.to_int()..<='9'.to_int() {
            if face.get_nominal_glyph(u) is Some(glyph) {
              if horizontal {
                pos.x_advance = face.glyph_h_advance(glyph)
              } else {
                pos.y_advance = face.glyph_v_advance(glyph)
              }
              break
            }
          }
        SPACE_PUNCTUATION => {
          let punct = match face.get_nominal_glyph('.'.to_int()) {
            Some(g) => Some(g)
            None => face.get_nominal_glyph(','.to_int())
          }
          if punct is Some(glyph) {
            if horizontal {
              pos.x_advance = face.glyph_h_advance(glyph)
            } else {
              pos.y_advance = face.glyph_v_advance(glyph)
            }
          }
        }
        SPACE_NARROW =>
          // Half-space?
          // Unicode doc https://unicode.org/charts/PDF/U2000.pdf says ~1/4 or 1/5 of EM.
          // However, in my testing, many fonts have their regular space being about that
          // size. To me, a percentage of the space width makes more sense. Half is as
          // good as any.
          if horizontal {
            pos.x_advance = pos.x_advance / 2
          } else {
            pos.y_advance = pos.y_advance / 2
          }
        _ => ()
      }
    }
  }
}
