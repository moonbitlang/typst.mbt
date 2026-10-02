// Port of rustybuzz 0.20.1 `src/hb/aat_layout_morx_table.rs`.

// TODO: Use set_digest, similarly to how it's used in harfbuzz.

///|
/// `Chain::compile_flags` in harfbuzz
fn compile_flags(face : Face, builder : AatMapBuilder, map : AatMap) -> Unit? {
  let has_feature = (kind : Int, setting : Int) => {
    // `binary_search_by(...).is_ok()`
    let features = builder.current_features
    let mut lo = 0
    let mut hi = features.length()
    let mut found = false
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      let probe = features[mid]
      let c = if probe.kind != kind {
        probe.kind.compare(kind)
      } else {
        probe.setting.compare(setting)
      }
      if c == 0 {
        found = true
        break
      } else if c < 0 {
        lo = mid + 1
      } else {
        hi = mid
      }
    }
    found
  }
  guard face.tables().morx is Some(morx) else { return None }
  let chains = morx.chains
  let chain_len = chains.iter().count()
  resize_chain_flags(map.chain_flags, chain_len)
  for i, chain in chains.iter() {
    if i >= chain_len {
      break
    }
    let chain_flags = map.chain_flags[i]
    let mut flags = chain.default_flags
    for feature in chain.features.iter() {
      // Check whether this type/setting pair was requested in the map,
      // and if so, apply its flags.

      let kind = feature.kind.to_int()
      let setting = feature.setting.to_int()
      if has_feature(kind, setting) {
        flags = flags & feature.disable_flags
        flags = flags | feature.enable_flags
      } else if kind == HB_AAT_LAYOUT_FEATURE_TYPE_LETTER_CASE &&
        setting == HB_AAT_LAYOUT_FEATURE_SELECTOR_SMALL_CAPS {
        // Deprecated. https://github.com/harfbuzz/harfbuzz/issues/1342
        let ok = has_feature(
          HB_AAT_LAYOUT_FEATURE_TYPE_LOWER_CASE,
          HB_AAT_LAYOUT_FEATURE_SELECTOR_LOWER_CASE_SMALL_CAPS,
        )
        if ok {
          flags = flags & feature.disable_flags
          flags = flags | feature.enable_flags
        }
      }
      // TODO: Port the following commit: https://github.com/harfbuzz/harfbuzz/commit/2124ad890
    }
    chain_flags.push({
      flags,
      cluster_first: builder.range_first,
      cluster_last: builder.range_last,
    })
  }
  Some(())
}

///|
/// `map.chain_flags.resize(chain_len, vec![])`
fn resize_chain_flags(
  chain_flags : Array[Array[RangeFlags]],
  len : Int,
) -> Unit {
  if chain_flags.length() > len {
    chain_flags.truncate(len)
  }
  while chain_flags.length() < len {
    chain_flags.push([])
  }
}

///|
/// `Chain::apply` in harfbuzz
fn morx_apply(c : AatApplyContext, map : AatMap) -> Unit? {
  c.buffer.unsafe_to_concat(None, None)
  guard c.face.tables().morx is Some(morx) else { return None }
  let chains = morx.chains
  let chain_len = chains.iter().count()
  resize_chain_flags(map.chain_flags, chain_len)
  for i, chain in chains.iter() {
    if i >= chain_len {
      break
    }
    c.range_flags = Some(map.chain_flags[i])
    for subtable in chain.subtables.iter() {
      if c.range_flags is Some(range_flags) {
        if range_flags.length() == 1 &&
          (subtable.feature_flags & range_flags[0].flags) == 0 {
          continue
        }
      }
      c.subtable_flags = subtable.feature_flags
      if !subtable.coverage.is_all_directions() &&
        c.buffer.direction.is_vertical() != subtable.coverage.is_vertical() {
        continue
      }

      // Buffer contents is always in logical direction.  Determine if
      // we need to reverse before applying this subtable.  We reverse
      // back after if we did reverse indeed.
      //
      // Quoting the spec:
      // """
      // Bits 28 and 30 of the coverage field control the order in which
      // glyphs are processed when the subtable is run by the layout engine.
      // Bit 28 is used to indicate if the glyph processing direction is
      // the same as logical order or layout order. Bit 30 is used to
      // indicate whether glyphs are processed forwards or backwards within
      // that order.
      //
      // Bit 30   Bit 28   Interpretation for Horizontal Text
      //      0        0   The subtable is processed in layout order
      //                   (the same order as the glyphs, which is
      //                   always left-to-right).
      //      1        0   The subtable is processed in reverse layout order
      //                   (the order opposite that of the glyphs, which is
      //                   always right-to-left).
      //      0        1   The subtable is processed in logical order
      //                   (the same order as the characters, which may be
      //                   left-to-right or right-to-left).
      //      1        1   The subtable is processed in reverse logical order
      //                   (the order opposite that of the characters, which
      //                   may be right-to-left or left-to-right).

      let reverse = if subtable.coverage.is_logical() {
        subtable.coverage.is_backwards()
      } else {
        subtable.coverage.is_backwards() != c.buffer.direction.is_backward()
      }
      if reverse {
        c.buffer.reverse()
      }
      apply_subtable(subtable.kind, c)
      if reverse {
        c.buffer.reverse()
      }
    }
  }
  Some(())
}

///|
/// `trait driver_context_t<T>`
priv struct DriverContext[T] {
  in_place : Bool
  can_advance : (@otf.GenericStateEntry[T]) -> Bool
  is_actionable : (@otf.GenericStateEntry[T], Buffer) -> Bool
  transition : (@otf.GenericStateEntry[T], Buffer) -> Unit
}

///|
const MORX_START_OF_TEXT : UInt16 = 0

///|
fn aat_class_end_of_text_u16() -> UInt16 {
  @otf.aat_class_end_of_text.to_int().to_uint16()
}

///|
fn[T : @otf.FromData] drive(
  machine : @otf.ExtendedStateTable[T],
  c : DriverContext[T],
  ac : AatApplyContext,
) -> Unit {
  if !c.in_place {
    ac.buffer.clear_output()
  }
  let mut state = MORX_START_OF_TEXT
  let mut last_range : Int? = match ac.range_flags {
    Some(rf) =>
      if rf.length() > 1 {
        Some(0)
      } else {
        // If there's only one range, we already checked the flag.
        None
      }
    None => None
  }
  ac.buffer.idx = 0
  while true {
    // This block copied from NoncontextualSubtable::apply. Keep in sync.
    if ac.range_flags is Some(range_flags) {
      if last_range is Some(lr) {
        let mut range = lr
        if ac.buffer.idx < ac.buffer.len {
          let cluster = ac.buffer.cur(0).cluster
          while cluster < range_flags[range].cluster_first {
            range -= 1
          }
          while cluster > range_flags[range].cluster_last {
            range += 1
          }
          last_range = Some(range)
        }
        if (range_flags[range].flags & ac.subtable_flags) == 0 {
          if ac.buffer.idx == ac.buffer.len || !ac.buffer.successful {
            break
          }
          state = MORX_START_OF_TEXT
          ac.buffer.next_glyph()
          continue
        }
      }
    }
    let class = if ac.buffer.idx < ac.buffer.len {
      machine.class(ac.buffer.cur(0).as_glyph()).unwrap_or(1)
    } else {
      aat_class_end_of_text_u16()
    }
    let entry = match machine.entry(state, class) {
      Some(v) => v
      None => break
    }
    let next_state = entry.new_state

    // Conditions under which it's guaranteed safe-to-break before current glyph:
    //
    // 1. There was no action in this transition; and
    //
    // 2. If we break before current glyph, the results will be the same. That
    //    is guaranteed if:
    //
    //    2a. We were already in start-of-text state; or
    //
    //    2b. We are epsilon-transitioning to start-of-text state; or
    //
    //    2c. Starting from start-of-text state seeing current glyph:
    //
    //        2c'. There won't be any actions; and
    //
    //        2c". We would end up in the same state that we were going to end up
    //             in now, including whether epsilon-transitioning.
    //
    //    and
    //
    // 3. If we break before current glyph, there won't be any end-of-text action
    //    after previous glyph.
    //
    // This triples the transitions we need to look up, but is worth returning
    // granular unsafe-to-break results. See eg.:
    //
    //   https://github.com/harfbuzz/harfbuzz/issues/2860

    let is_safe_to_break_extra = () => {
      // 2c
      let wouldbe_entry = match machine.entry(MORX_START_OF_TEXT, class) {
        Some(v) => v
        None => return false
      }

      // 2c'
      if (c.is_actionable)(wouldbe_entry, ac.buffer) {
        return false
      }

      // 2c"
      next_state == wouldbe_entry.new_state &&
      (c.can_advance)(entry) == (c.can_advance)(wouldbe_entry)
    }
    let is_safe_to_break = () => {
      // 1
      if (c.is_actionable)(entry, ac.buffer) {
        return false
      }

      // 2
      let ok = state == MORX_START_OF_TEXT ||
        (!(c.can_advance)(entry) && next_state == MORX_START_OF_TEXT) ||
        is_safe_to_break_extra()
      if !ok {
        return false
      }

      // 3
      let end_entry = match machine.entry(state, aat_class_end_of_text_u16()) {
        Some(v) => v
        None => return false
      }
      !(c.is_actionable)(end_entry, ac.buffer)
    }
    if !is_safe_to_break() &&
      ac.buffer.backtrack_len() > 0 &&
      ac.buffer.idx < ac.buffer.len {
      ac.buffer.unsafe_to_break_from_outbuffer(
        Some(ac.buffer.backtrack_len() - 1),
        Some(ac.buffer.idx + 1),
      )
    }
    (c.transition)(entry, ac.buffer)
    state = next_state
    if ac.buffer.idx >= ac.buffer.len || !ac.buffer.successful {
      break
    }
    if (c.can_advance)(entry) {
      ac.buffer.next_glyph()
    } else {
      if ac.buffer.max_ops <= 0 {
        ac.buffer.next_glyph()
      }
      ac.buffer.max_ops -= 1
    }
  }
  if !c.in_place {
    ac.buffer.sync() |> ignore
  }
}

///|
fn apply_subtable(kind : @otf.MorxSubtableKind, ac : AatApplyContext) -> Unit {
  match kind {
    Rearrangement(table) => {
      let c = RearrangementCtx::{ start: 0, end: 0, }
      drive(table, c.driver(), ac)
    }
    Contextual(table) => {
      let c = ContextualCtx::{
        mark_set: false,
        face_if_has_glyph_classes: match ac.face.tables().gdef {
          Some(gdef) if gdef.has_glyph_classes() => Some(ac.face)
          _ => None
        },
        mark: 0,
        table,
      }
      drive(table.state, c.driver(), ac)
    }
    Ligature(table) => {
      let c = LigatureCtx::{
        table,
        match_length: 0,
        match_positions: FixedArray::make(LIGATURE_MAX_MATCHES, 0),
      }
      drive(table.state, c.driver(), ac)
    }
    NonContextual(lookup) => {
      let face_if_has_glyph_classes = match ac.face.tables().gdef {
        Some(gdef) if gdef.has_glyph_classes() => Some(ac.face)
        _ => None
      }
      let mut last_range : Int? = match ac.range_flags {
        Some(rf) =>
          if rf.length() > 1 {
            Some(0)
          } else {
            // If there's only one range, we already checked the flag.
            None
          }
        None => None
      }
      for info in 0..<ac.buffer.len {
        // This block copied from StateTableDriver::drive. Keep in sync.
        if ac.range_flags is Some(range_flags) {
          if last_range is Some(lr) {
            let mut range = lr
            if ac.buffer.idx < ac.buffer.len {
              // We need to access info
              let cluster = ac.buffer.cur(0).cluster
              while cluster < range_flags[range].cluster_first {
                range -= 1
              }
              while cluster > range_flags[range].cluster_last {
                range += 1
              }
              last_range = Some(range)
            }
            if (range_flags[range].flags & ac.subtable_flags) == 0 {
              continue
            }
          }
        }
        let info = ac.buffer.info[info]
        if lookup.value(info.as_glyph()) is Some(replacement) {
          info.glyph_id = replacement.to_uint()
          if face_if_has_glyph_classes is Some(face) {
            info.set_glyph_props(face.glyph_props(@otf.GlyphId(replacement)))
          }
        }
      }
    }
    Insertion(table) => {
      let c = InsertionCtx::{ mark: 0, glyphs: table.glyphs, }
      drive(table.state, c.driver(), ac)
    }
  }
}

///|
priv struct RearrangementCtx {
  mut start : Int
  mut end : Int
}

///|
const REARRANGEMENT_MARK_FIRST : UInt16 = 0x8000

///|
const REARRANGEMENT_DONT_ADVANCE : UInt16 = 0x4000

///|
const REARRANGEMENT_MARK_LAST : UInt16 = 0x2000

///|
const REARRANGEMENT_VERB : UInt16 = 0x000F

///|
/// The following map has two nibbles, for start-side
/// and end-side. Values of 0,1,2 mean move that many
/// to the other side. Value of 3 means move 2 and
/// flip them.
let rearrangement_map : FixedArray[Int] = [
  0x00, // 0  no change
   0x10, // 1  Ax => xA
   0x01, // 2  xD => Dx
   0x11, // 3  AxD => DxA
   0x20, // 4  ABx => xAB
   0x30, // 5  ABx => xBA
   0x02, // 6  xCD => CDx
   0x03, // 7  xCD => DCx
   0x12, // 8  AxCD => CDxA
   0x13, // 9  AxCD => DCxA
   0x21, // 10 ABxD => DxAB
   0x31, // 11 ABxD => DxBA
   0x22, // 12 ABxCD => CDxAB
   0x32, // 13 ABxCD => CDxBA
   0x23, // 14 ABxCD => DCxAB
   0x33, // 15 ABxCD => DCxBA
]

///|
fn RearrangementCtx::driver(self : RearrangementCtx) -> DriverContext[Unit] {
  {
    in_place: true,
    can_advance: entry => (entry.flags & REARRANGEMENT_DONT_ADVANCE) == 0,
    is_actionable: (entry, _) => {
      (entry.flags & REARRANGEMENT_VERB) != 0 && self.start < self.end
    },
    transition: (entry, buffer) => self.transition(entry, buffer),
  }
}

///|
fn RearrangementCtx::transition(
  self : RearrangementCtx,
  entry : @otf.GenericStateEntry[Unit],
  buffer : Buffer,
) -> Unit {
  let flags = entry.flags
  if (flags & REARRANGEMENT_MARK_FIRST) != 0 {
    self.start = buffer.idx
  }
  if (flags & REARRANGEMENT_MARK_LAST) != 0 {
    self.end = imin(buffer.idx + 1, buffer.len)
  }
  if (flags & REARRANGEMENT_VERB) != 0 && self.start < self.end {
    let m = rearrangement_map[(flags & REARRANGEMENT_VERB).to_int()]
    let l = imin(2, m >> 4)
    let r = imin(2, m & 0x0F)
    let reverse_l = 3 == m >> 4
    let reverse_r = 3 == (m & 0x0F)
    if self.end - self.start >= l + r &&
      self.end - self.start <= MAX_CONTEXT_LENGTH {
      buffer.merge_clusters(self.start, imin(buffer.idx + 1, buffer.len))
      buffer.merge_clusters(self.start, self.end)
      let info = buffer.info
      // The rearrangement is a permutation of `info[start..end]`, so the
      // glyph info objects are moved by reference.
      let buf : Array[GlyphInfo] = []
      for i in 0..<l {
        buf.push(info[self.start + i])
      }
      for _ in l..<2 {
        buf.push(info[self.start])
      }
      for i in 0..<r {
        buf.push(info[self.end - r + i])
      }
      if l > r {
        for i in 0..<(self.end - self.start - l - r) {
          info[self.start + r + i] = info[self.start + l + i]
        }
      } else if l < r {
        for i = self.end - self.start - l - r - 1; i >= 0; i = i - 1 {
          info[self.start + r + i] = info[self.start + l + i]
        }
      }
      for i in 0..<r {
        info[self.start + i] = buf[2 + i]
      }
      for i in 0..<l {
        info[self.end - l + i] = buf[i]
      }
      if reverse_l {
        info.swap(self.end - 1, self.end - 2)
      }
      if reverse_r {
        info.swap(self.start, self.start + 1)
      }
    }
  }
}

///|
priv struct ContextualCtx {
  mut mark_set : Bool
  face_if_has_glyph_classes : Face?
  mut mark : Int
  table : @otf.MorxContextualSubtable
}

///|
const CONTEXTUAL_SET_MARK : UInt16 = 0x8000

///|
const CONTEXTUAL_DONT_ADVANCE : UInt16 = 0x4000

///|
fn ContextualCtx::driver(
  self : ContextualCtx,
) -> DriverContext[@otf.MorxContextualEntryData] {
  {
    in_place: true,
    can_advance: entry => (entry.flags & CONTEXTUAL_DONT_ADVANCE) == 0,
    is_actionable: (entry, buffer) => {
      if buffer.idx == buffer.len && !self.mark_set {
        return false
      }
      entry.extra.mark_index != 0xFFFF || entry.extra.current_index != 0xFFFF
    },
    transition: (entry, buffer) => self.transition(entry, buffer) |> ignore,
  }
}

///|
fn ContextualCtx::transition(
  self : ContextualCtx,
  entry : @otf.GenericStateEntry[@otf.MorxContextualEntryData],
  buffer : Buffer,
) -> Unit? {
  // Looks like CoreText applies neither mark nor current substitution for
  // end-of-text if mark was not explicitly set.
  if buffer.idx == buffer.len && !self.mark_set {
    return Some(())
  }
  let mut replacement = None
  if entry.extra.mark_index != 0xFFFF {
    guard self.table.lookup(entry.extra.mark_index.to_uint()) is Some(lookup) else {
      return None
    }
    replacement = lookup.value(buffer.info[self.mark].as_glyph())
  }
  if replacement is Some(replacement) {
    buffer.unsafe_to_break(
      Some(self.mark),
      Some(imin(buffer.idx + 1, buffer.len)),
    )
    buffer.info[self.mark].glyph_id = replacement.to_uint()
    if self.face_if_has_glyph_classes is Some(face) {
      buffer.info[self.mark].set_glyph_props(
        face.glyph_props(@otf.GlyphId(replacement)),
      )
    }
  }
  replacement = None
  let idx = imin(buffer.idx, buffer.len - 1)
  if entry.extra.current_index != 0xFFFF {
    guard self.table.lookup(entry.extra.current_index.to_uint()) is Some(lookup) else {
      return None
    }
    replacement = lookup.value(buffer.info[idx].as_glyph())
  }
  if replacement is Some(replacement) {
    buffer.info[idx].glyph_id = replacement.to_uint()
    if self.face_if_has_glyph_classes is Some(face) {
      buffer.info[self.mark].set_glyph_props(
        face.glyph_props(@otf.GlyphId(replacement)),
      )
    }
  }
  if (entry.flags & CONTEXTUAL_SET_MARK) != 0 {
    self.mark_set = true
    self.mark = buffer.idx
  }
  Some(())
}

///|
priv struct InsertionCtx {
  mut mark : Int
  glyphs : @otf.LazyArray32[@otf.GlyphId]
}

///|
const INSERTION_SET_MARK : UInt16 = 0x8000

///|
const INSERTION_DONT_ADVANCE : UInt16 = 0x4000

///|
const INSERTION_CURRENT_INSERT_BEFORE : UInt16 = 0x0800

///|
const INSERTION_MARKED_INSERT_BEFORE : UInt16 = 0x0400

///|
const INSERTION_CURRENT_INSERT_COUNT : UInt16 = 0x03E0

///|
const INSERTION_MARKED_INSERT_COUNT : UInt16 = 0x001F

///|
fn InsertionCtx::driver(
  self : InsertionCtx,
) -> DriverContext[@otf.MorxInsertionEntryData] {
  {
    in_place: false,
    can_advance: entry => (entry.flags & INSERTION_DONT_ADVANCE) == 0,
    is_actionable: (entry, _) => {
      (
        entry.flags &
        (INSERTION_CURRENT_INSERT_COUNT | INSERTION_MARKED_INSERT_COUNT)
      ) !=
      0 &&
      (
        entry.extra.current_insert_index != 0xFFFF ||
        entry.extra.marked_insert_index != 0xFFFF
      )
    },
    transition: (entry, buffer) => self.transition(entry, buffer) |> ignore,
  }
}

///|
fn InsertionCtx::transition(
  self : InsertionCtx,
  entry : @otf.GenericStateEntry[@otf.MorxInsertionEntryData],
  buffer : Buffer,
) -> Unit? {
  let flags = entry.flags
  let mark_loc = buffer.out_len
  if entry.extra.marked_insert_index != 0xFFFF {
    let count = (flags & INSERTION_MARKED_INSERT_COUNT).to_int()
    buffer.max_ops -= count
    if buffer.max_ops <= 0 {
      return Some(())
    }
    let start = entry.extra.marked_insert_index.to_int()
    let before = (flags & INSERTION_MARKED_INSERT_BEFORE) != 0
    let end = buffer.out_len
    buffer.move_to(self.mark) |> ignore
    if buffer.idx < buffer.len && !before {
      buffer.copy_glyph()
    }

    // TODO We ignore KashidaLike setting.
    for i in 0..<count {
      let i = ((start + i) & 0xFFFF).reinterpret_as_uint()
      guard self.glyphs.get(i) is Some(glyph) else { return None }
      buffer.output_glyph(glyph.0.to_uint())
    }
    if buffer.idx < buffer.len && !before {
      buffer.skip_glyph()
    }
    buffer.move_to(end + count) |> ignore
    buffer.unsafe_to_break_from_outbuffer(
      Some(self.mark),
      Some(imin(buffer.idx + 1, buffer.len)),
    )
  }
  if (flags & INSERTION_SET_MARK) != 0 {
    self.mark = mark_loc
  }
  if entry.extra.current_insert_index != 0xFFFF {
    let count = ((flags & INSERTION_CURRENT_INSERT_COUNT) >> 5).to_int()
    buffer.max_ops -= count
    if buffer.max_ops < 0 {
      return Some(())
    }
    let start = entry.extra.current_insert_index.to_int()
    let before = (flags & INSERTION_CURRENT_INSERT_BEFORE) != 0
    let end = buffer.out_len
    if buffer.idx < buffer.len && !before {
      buffer.copy_glyph()
    }

    // TODO We ignore KashidaLike setting.
    for i in 0..<count {
      let i = ((start + i) & 0xFFFF).reinterpret_as_uint()
      guard self.glyphs.get(i) is Some(glyph) else { return None }
      buffer.output_glyph(glyph.0.to_uint())
    }
    if buffer.idx < buffer.len && !before {
      buffer.skip_glyph()
    }

    // Humm. Not sure where to move to. There's this wording under
    // DontAdvance flag:
    //
    // "If set, don't update the glyph index before going to the new state.
    // This does not mean that the glyph pointed to is the same one as
    // before. If you've made insertions immediately downstream of the
    // current glyph, the next glyph processed would in fact be the first
    // one inserted."
    //
    // This suggests that if DontAdvance is NOT set, we should move to
    // end+count. If it *was*, then move to end, such that newly inserted
    // glyphs are now visible.
    //
    // https://github.com/harfbuzz/harfbuzz/issues/1224#issuecomment-427691417
    buffer.move_to(
      if (flags & INSERTION_DONT_ADVANCE) != 0 {
        end
      } else {
        end + count
      },
    )
    |> ignore
  }
  Some(())
}

///|
const LIGATURE_MAX_MATCHES : Int = 64

///|
priv struct LigatureCtx {
  table : @otf.MorxLigatureSubtable
  mut match_length : Int
  match_positions : FixedArray[Int]
}

///|
const LIGATURE_SET_COMPONENT : UInt16 = 0x8000

///|
const LIGATURE_DONT_ADVANCE : UInt16 = 0x4000

///|
const LIGATURE_PERFORM_ACTION : UInt16 = 0x2000

///|
const LIG_ACTION_LAST : UInt = 0x80000000

///|
const LIG_ACTION_STORE : UInt = 0x40000000

///|
const LIG_ACTION_OFFSET : UInt = 0x3FFFFFFF

///|
fn LigatureCtx::driver(self : LigatureCtx) -> DriverContext[UInt16] {
  {
    in_place: false,
    can_advance: entry => (entry.flags & LIGATURE_DONT_ADVANCE) == 0,
    is_actionable: (entry, _) => (entry.flags & LIGATURE_PERFORM_ACTION) != 0,
    transition: (entry, buffer) => self.transition(entry, buffer),
  }
}

///|
fn LigatureCtx::transition(
  self : LigatureCtx,
  entry : @otf.GenericStateEntry[UInt16],
  buffer : Buffer,
) -> Unit {
  if (entry.flags & LIGATURE_SET_COMPONENT) != 0 {
    // Never mark same index twice, in case DONT_ADVANCE was used...
    if self.match_length != 0 &&
      self.match_positions[(self.match_length - 1) % LIGATURE_MAX_MATCHES] ==
      buffer.out_len {
      self.match_length -= 1
    }
    self.match_positions[self.match_length % LIGATURE_MAX_MATCHES] = buffer.out_len
    self.match_length += 1
  }
  if (entry.flags & LIGATURE_PERFORM_ACTION) != 0 {
    let end = buffer.out_len
    if self.match_length == 0 {
      return
    }
    if buffer.idx >= buffer.len {
      return // TODO: Work on previous instead?
    }
    let mut cursor = self.match_length
    let mut ligature_actions_index = entry.extra.to_int()
    let mut ligature_idx = 0
    while true {
      if cursor == 0 {
        // Stack underflow. Clear the stack.
        self.match_length = 0
        break
      }
      cursor -= 1
      buffer.move_to(self.match_positions[cursor % LIGATURE_MAX_MATCHES])
      |> ignore

      // We cannot use ? in this loop, because we must call
      // buffer.move_to(end) in the end.
      let action = match
        self.table.ligature_actions.get(
          ligature_actions_index.reinterpret_as_uint(),
        ) {
        Some(v) => v
        None => break
      }
      let mut uoffset = action & LIG_ACTION_OFFSET
      if (uoffset & 0x20000000) != 0 {
        uoffset = uoffset | 0xC0000000 // Sign-extend.
      }
      let offset = uoffset.reinterpret_as_int()
      let component_idx = (buffer.cur(0).glyph_id.reinterpret_as_int() + offset).reinterpret_as_uint()
      ligature_idx = (
          ligature_idx +
          (match self.table.components.get(component_idx) {
            Some(v) => v.to_int()
            None => break
          })
        ) &
        0xFFFF
      if (action & (LIG_ACTION_STORE | LIG_ACTION_LAST)) != 0 {
        let lig = match
          self.table.ligatures.get(ligature_idx.reinterpret_as_uint()) {
          Some(v) => v
          None => break
        }
        buffer.replace_glyph(lig.0.to_uint())
        let lig_end = self.match_positions[(self.match_length - 1) %
          LIGATURE_MAX_MATCHES] +
          1
        // Now go and delete all subsequent components.
        while self.match_length - 1 > cursor {
          self.match_length -= 1
          buffer.move_to(
            self.match_positions[self.match_length % LIGATURE_MAX_MATCHES],
          )
          |> ignore
          let cur_unicode = buffer.cur(0).unicode_props()
          buffer.cur(0).set_unicode_props(cur_unicode | UPROPS_MASK_IGNORABLE)
          buffer.replace_glyph(0xFFFF)
        }
        buffer.move_to(lig_end) |> ignore
        buffer.merge_out_clusters(
          self.match_positions[cursor % LIGATURE_MAX_MATCHES],
          buffer.out_len,
        )
      }
      ligature_actions_index = (ligature_actions_index + 1) & 0xFFFF
      if (action & LIG_ACTION_LAST) != 0 {
        break
      }
    }
    buffer.move_to(end) |> ignore
  }
}
