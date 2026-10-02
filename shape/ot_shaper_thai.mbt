// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_thai.rs`.

///|
let thai_shaper : OtShaper = {
  name: "thai",
  collect_features: None,
  override_features: None,
  create_data: None,
  preprocess_text: Some(preprocess_text_thai),
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_AUTO,
  decompose: None,
  compose: None,
  setup_masks: None,
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_LATE,
  fallback_position: false,
}

///|
priv enum Consonant {
  NC
  AC
  RC
  DC
  NotConsonant
}

///|
fn Consonant::to_int(self : Consonant) -> Int {
  match self {
    NC => 0
    AC => 1
    RC => 2
    DC => 3
    NotConsonant => 4
  }
}

///|
fn get_consonant_type(u : UInt) -> Consonant {
  match u {
    0x0E1B | 0x0E1D | 0x0E1F => AC
    0x0E0D | 0x0E10 => RC
    0x0E0E | 0x0E0F => DC
    0x0E01..=0x0E2E => NC
    _ => NotConsonant
  }
}

///|
priv enum Mark {
  AV
  BV
  T
  NotMark
} derive(Eq)

///|
fn Mark::to_int(self : Mark) -> Int {
  match self {
    AV => 0
    BV => 1
    T => 2
    NotMark => 3
  }
}

///|
fn get_mark_type(u : UInt) -> Mark {
  match u {
    0x0E31 | 0x0E34..=0x0E37 | 0x0E47 | 0x0E4D..=0x0E4E => AV
    0x0E38..=0x0E3A => BV
    0x0E48..=0x0E4C => T
    _ => NotMark
  }
}

///|
priv enum Action {
  NOP
  /// Shift combining-mark down.
  SD
  /// Shift combining-mark left.
  SL
  /// Shift combining-mark down-left.
  SDL
  /// Remove descender from base.
  RD
} derive(Eq)

///|
priv struct PuaMapping {
  u : UInt
  win_pua : UInt
  mac_pua : UInt
}

///|
fn PuaMapping::new(u : UInt, win_pua : UInt, mac_pua : UInt) -> PuaMapping {
  { u, win_pua, mac_pua, }
}

///|
let sd_mappings : FixedArray[PuaMapping] = [
  PuaMapping::new(0x0E48, 0xF70A, 0xF88B), // MAI EK
  PuaMapping::new(0x0E49, 0xF70B, 0xF88E), // MAI THO
  PuaMapping::new(0x0E4A, 0xF70C, 0xF891), // MAI TRI
  PuaMapping::new(0x0E4B, 0xF70D, 0xF894), // MAI CHATTAWA
  PuaMapping::new(0x0E4C, 0xF70E, 0xF897), // THANTHAKHAT
  PuaMapping::new(0x0E38, 0xF718, 0xF89B), // SARA U
  PuaMapping::new(0x0E39, 0xF719, 0xF89C), // SARA UU
  PuaMapping::new(0x0E3A, 0xF71A, 0xF89D), // PHINTHU
  PuaMapping::new(0x0000, 0x0000, 0x0000),
]

///|
let sdl_mappings : FixedArray[PuaMapping] = [
  PuaMapping::new(0x0E48, 0xF705, 0xF88C), // MAI EK
  PuaMapping::new(0x0E49, 0xF706, 0xF88F), // MAI THO
  PuaMapping::new(0x0E4A, 0xF707, 0xF892), // MAI TRI
  PuaMapping::new(0x0E4B, 0xF708, 0xF895), // MAI CHATTAWA
  PuaMapping::new(0x0E4C, 0xF709, 0xF898), // THANTHAKHAT
  PuaMapping::new(0x0000, 0x0000, 0x0000),
]

///|
let sl_mappings : FixedArray[PuaMapping] = [
  PuaMapping::new(0x0E48, 0xF713, 0xF88A), // MAI EK
  PuaMapping::new(0x0E49, 0xF714, 0xF88D), // MAI THO
  PuaMapping::new(0x0E4A, 0xF715, 0xF890), // MAI TRI
  PuaMapping::new(0x0E4B, 0xF716, 0xF893), // MAI CHATTAWA
  PuaMapping::new(0x0E4C, 0xF717, 0xF896), // THANTHAKHAT
  PuaMapping::new(0x0E31, 0xF710, 0xF884), // MAI HAN-AKAT
  PuaMapping::new(0x0E34, 0xF701, 0xF885), // SARA I
  PuaMapping::new(0x0E35, 0xF702, 0xF886), // SARA II
  PuaMapping::new(0x0E36, 0xF703, 0xF887), // SARA UE
  PuaMapping::new(0x0E37, 0xF704, 0xF888), // SARA UEE
  PuaMapping::new(0x0E47, 0xF712, 0xF889), // MAITAIKHU
  PuaMapping::new(0x0E4D, 0xF711, 0xF899), // NIKHAHIT
  PuaMapping::new(0x0000, 0x0000, 0x0000),
]

///|
let rd_mappings : FixedArray[PuaMapping] = [
  PuaMapping::new(0x0E0D, 0xF70F, 0xF89A), // YO YING
  PuaMapping::new(0x0E10, 0xF700, 0xF89E), // THO THAN
  PuaMapping::new(0x0000, 0x0000, 0x0000),
]

///|
fn pua_shape(u : UInt, action : Action, face : Face) -> UInt {
  let mappings = match action {
    NOP => return u
    SD => sd_mappings
    SL => sl_mappings
    SDL => sdl_mappings
    RD => rd_mappings
  }
  for m in mappings {
    if m.u == u {
      if face.get_nominal_glyph(m.win_pua.reinterpret_as_int()) is Some(_) {
        return m.win_pua
      }
      if face.get_nominal_glyph(m.mac_pua.reinterpret_as_int()) is Some(_) {
        return m.mac_pua
      }
      break
    }
  }
  u
}

///|
priv enum AboveState {
  // Cluster above looks like:
  T0 //  ⣤
  T1 //     ⣼
  T2 //        ⣾
  T3 //           ⣿
}

///|
fn AboveState::to_int(self : AboveState) -> Int {
  match self {
    T0 => 0
    T1 => 1
    T2 => 2
    T3 => 3
  }
}

///|
let above_start_state : FixedArray[AboveState] = [
  T0, // NC
  T1, // AC
  T0, // RC
  T0, // DC
  T3, // NotConsonant
]

///|
priv struct AboveStateMachineEdge {
  action : Action
  next_state : AboveState
}

///|
fn AboveStateMachineEdge::new(
  action : Action,
  next_state : AboveState,
) -> AboveStateMachineEdge {
  { action, next_state, }
}

///|
let above_state_machine : FixedArray[FixedArray[AboveStateMachineEdge]] = [
  //        AV                                      BV                                      T
  // T0
  [
    AboveStateMachineEdge::new(NOP, T3),
    AboveStateMachineEdge::new(NOP, T0),
    AboveStateMachineEdge::new(SD, T3),
  ],
  // T1
  [
    AboveStateMachineEdge::new(SL, T2),
    AboveStateMachineEdge::new(NOP, T1),
    AboveStateMachineEdge::new(SDL, T2),
  ],
  // T2
  [
    AboveStateMachineEdge::new(NOP, T3),
    AboveStateMachineEdge::new(NOP, T2),
    AboveStateMachineEdge::new(SL, T3),
  ],
  // T3
  [
    AboveStateMachineEdge::new(NOP, T3),
    AboveStateMachineEdge::new(NOP, T3),
    AboveStateMachineEdge::new(NOP, T3),
  ],
]

///|
priv enum BelowState {
  /// No descender.
  B0
  /// Removable descender.
  B1
  /// Strict descender.
  B2
}

///|
fn BelowState::to_int(self : BelowState) -> Int {
  match self {
    B0 => 0
    B1 => 1
    B2 => 2
  }
}

///|
let below_start_state : FixedArray[BelowState] = [
  B0, // NC
  B0, // AC
  B1, // RC
  B2, // DC
  B2, // NotConsonant
]

///|
priv struct BelowStateMachineEdge {
  action : Action
  next_state : BelowState
}

///|
fn BelowStateMachineEdge::new(
  action : Action,
  next_state : BelowState,
) -> BelowStateMachineEdge {
  { action, next_state, }
}

///|
let below_state_machine : FixedArray[FixedArray[BelowStateMachineEdge]] = [
  //        AV                                      BV                                      T
  // B0
  [
    BelowStateMachineEdge::new(NOP, B0),
    BelowStateMachineEdge::new(NOP, B2),
    BelowStateMachineEdge::new(NOP, B0),
  ],
  // B1
  [
    BelowStateMachineEdge::new(NOP, B1),
    BelowStateMachineEdge::new(RD, B2),
    BelowStateMachineEdge::new(NOP, B1),
  ],
  // B2
  [
    BelowStateMachineEdge::new(NOP, B2),
    BelowStateMachineEdge::new(SD, B2),
    BelowStateMachineEdge::new(NOP, B2),
  ],
]

///|
fn do_pua_shaping(face : Face, buffer : Buffer) -> Unit {
  let mut above_state = above_start_state[NotConsonant.to_int()]
  let mut below_state = below_start_state[NotConsonant.to_int()]
  let mut base = 0
  for i in 0..<buffer.len {
    let mt = get_mark_type(buffer.info[i].glyph_id)
    if mt == NotMark {
      let ct = get_consonant_type(buffer.info[i].glyph_id)
      above_state = above_start_state[ct.to_int()]
      below_state = below_start_state[ct.to_int()]
      base = i
      continue
    }
    let above_edge = above_state_machine[above_state.to_int()][mt.to_int()]
    let below_edge = below_state_machine[below_state.to_int()][mt.to_int()]
    above_state = above_edge.next_state
    below_state = below_edge.next_state

    // At least one of the above/below actions is NOP.
    let action = if above_edge.action != NOP {
      above_edge.action
    } else {
      below_edge.action
    }
    buffer.unsafe_to_break(Some(base), Some(i))
    if action == RD {
      buffer.info[base].glyph_id = pua_shape(
        buffer.info[base].glyph_id,
        action,
        face,
      )
    } else {
      buffer.info[i].glyph_id = pua_shape(buffer.info[i].glyph_id, action, face)
    }
  }
}

///|
// We only get one script at a time, so a script-agnostic implementation
// is adequate here.
fn is_sara_am(u : UInt) -> Bool {
  (u & (0x0080U ^ 0xFFFFFFFF)) == 0x0E33
}

///|
fn nikhahit_from_sara_am(u : UInt) -> UInt {
  u - 0x0E33 + 0x0E4D
}

///|
fn sara_aa_from_sara_am(u : UInt) -> UInt {
  u - 1
}

///|
fn is_above_base_mark(u : UInt) -> Bool {
  let u = u & (0x0080U ^ 0xFFFFFFFF)
  match u {
    0x0E34..=0x0E37 | 0x0E47..=0x0E4E | 0x0E31..=0x0E31 | 0x0E3B..=0x0E3B =>
      true
    _ => false
  }
}

///|
// TODO: more tests
fn preprocess_text_thai(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit {
  // This function implements the shaping logic documented here:
  //
  //   https://linux.thai.net/~thep/th-otf/shaping.html
  //
  // The first shaping rule listed there is needed even if the font has Thai
  // OpenType tables.  The rest do fallback positioning based on PUA codepoints.
  // We implement that only if there exist no Thai GSUB in the font.

  // The following is NOT specified in the MS OT Thai spec, however, it seems
  // to be what Uniscribe and other engines implement.  According to Eric Muller:
  //
  // When you have a SARA AM, decompose it in NIKHAHIT + SARA AA, *and* move the
  // NIKHAHIT backwards over any above-base marks (0E31, 0E34-0E37, 0E47-0E4E).
  //
  // <0E14, 0E4B, 0E33> -> <0E14, 0E4D, 0E4B, 0E32>
  //
  // This reordering is legit only when the NIKHAHIT comes from a SARA AM, not
  // when it's there to start with. The string <0E14, 0E4B, 0E4D> is probably
  // not what a user wanted, but the rendering is nevertheless nikhahit above
  // chattawa.
  //
  // Same for Lao.
  //
  // Note:
  //
  // Uniscribe also does some below-marks reordering.  Namely, it positions U+0E3A
  // after U+0E38 and U+0E39.  We do that by modifying the ccc for U+0E3A.
  // See unicode->modified_combining_class ().  Lao does NOT have a U+0E3A
  // equivalent.

  // Here are the characters of significance:
  //
  //              Thai    Lao
  // SARA AM:     U+0E33  U+0EB3
  // SARA AA:     U+0E32  U+0EB2
  // Nikhahit:    U+0E4D  U+0ECD
  //
  // Testing shows that Uniscribe reorder the following marks:
  // Thai:	<0E31,0E34..0E37,0E47..0E4E>
  // Lao:     <0EB1,0EB4..0EB7,0EBB,0EC8..0ECD>
  //
  // Note how the Lao versions are the same as Thai + 0x80.

  buffer.clear_output()
  buffer.idx = 0
  while buffer.idx < buffer.len {
    let u = buffer.cur(0).glyph_id
    if !is_sara_am(u) {
      buffer.next_glyph()
      continue
    }

    // Is SARA AM. Decompose and reorder.
    buffer.output_glyph(nikhahit_from_sara_am(u))
    {
      let out_idx = buffer.out_len - 1
      buffer.out_info()[out_idx].set_continuation()
    }
    buffer.replace_glyph(sara_aa_from_sara_am(u))

    // Make Nikhahit be recognized as a ccc=0 mark when zeroing widths.
    let end = buffer.out_len
    buffer.out_info()[end - 2].set_general_category(GC_NON_SPACING_MARK)

    // Ok, let's see...
    let mut start = end - 2
    while start > 0 && is_above_base_mark(buffer.out_info()[start - 1].glyph_id) {
      start -= 1
    }
    if start + 2 < end {
      // Move Nikhahit (end-2) to the beginning
      buffer.merge_out_clusters(start, end)
      let t = buffer.out_info()[end - 2].copy()
      for i in 0..<(end - start - 2) {
        buffer.out_info()[i + start + 1].assign(buffer.out_info()[i + start])
      }
      buffer.out_info()[start].assign(t)
    } else if start != 0 &&
      buffer.cluster_level == HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES {
      // Since we decomposed, and NIKHAHIT is combining, merge clusters with the
      // previous cluster.
      buffer.merge_out_clusters(start - 1, end)
    }
  }
  buffer.sync() |> ignore

  // If font has Thai GSUB, we are done.
  if plan.script == Some(script_thai) && !plan.ot_map.found_script(GSUB) {
    do_pua_shaping(face, buffer)
  }
}
