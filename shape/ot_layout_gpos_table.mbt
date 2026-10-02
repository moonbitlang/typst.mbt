// Port of rustybuzz 0.20.1 `src/hb/ot_layout_gpos_table.rs` and
// `src/hb/ot/layout/GPOS/*.rs` (positioning lookups).

///|
fn position(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit {
  apply_layout_table(
    plan,
    face,
    buffer,
    GPOS,
    true,
    face.gpos.map(t => t.lookups),
  )
}

// ValueRecordExt

///|
fn value_record_is_empty(this : @otf.ValueRecord) -> Bool {
  this.x_placement == 0 &&
  this.y_placement == 0 &&
  this.x_advance == 0 &&
  this.y_advance == 0 &&
  this.x_placement_device is None &&
  this.y_placement_device is None &&
  this.x_advance_device is None &&
  this.y_advance_device is None
}

///|
fn value_record_apply(
  this : @otf.ValueRecord,
  ctx : ApplyContext,
  idx : Int,
) -> Bool {
  let pos = ctx.buffer.pos[idx].copy()
  let worked = value_record_apply_to_pos(this, ctx, pos)
  ctx.buffer.pos[idx].assign(pos)
  worked
}

///|
fn value_record_apply_to_pos(
  this : @otf.ValueRecord,
  ctx : ApplyContext,
  pos : GlyphPosition,
) -> Bool {
  let horizontal = ctx.buffer.direction.is_horizontal()
  let mut worked = false
  if this.x_placement != 0 {
    pos.x_offset += this.x_placement.to_int()
    worked = true
  }
  if this.y_placement != 0 {
    pos.y_offset += this.y_placement.to_int()
    worked = true
  }
  if this.x_advance != 0 && horizontal {
    pos.x_advance += this.x_advance.to_int()
    worked = true
  }
  if this.y_advance != 0 && !horizontal {
    // y_advance values grow downward but font-space grows upward, hence negation
    pos.y_advance -= this.y_advance.to_int()
    worked = true
  }
  {
    let (ppem_x, ppem_y) = ctx.face.pixels_per_em.unwrap_or((0, 0))
    let coords = ctx.face.variation_coordinates().length()
    let use_x_device = ppem_x != 0 || coords != 0
    let use_y_device = ppem_y != 0 || coords != 0
    if use_x_device {
      if this.x_placement_device is Some(device) {
        pos.x_offset += device_get_x_delta(device, ctx.face).unwrap_or(0)
        worked = true // TODO: even when 0?
      }
    }
    if use_y_device {
      if this.y_placement_device is Some(device) {
        pos.y_offset += device_get_y_delta(device, ctx.face).unwrap_or(0)
        worked = true
      }
    }
    if horizontal && use_x_device {
      if this.x_advance_device is Some(device) {
        pos.x_advance += device_get_x_delta(device, ctx.face).unwrap_or(0)
        worked = true
      }
    }
    if !horizontal && use_y_device {
      if this.y_advance_device is Some(device) {
        // y_advance values grow downward but face-space grows upward, hence negation
        pos.y_advance -= device_get_y_delta(device, ctx.face).unwrap_or(0)
        worked = true
      }
    }
  }
  worked
}

// AnchorExt

///|
fn anchor_get(this : @otf.Anchor, face : Face) -> (Int, Int) {
  let mut x = this.x.to_int()
  let mut y = this.y.to_int()
  if this.x_device is Some(_) || this.y_device is Some(_) {
    let (ppem_x, ppem_y) = face.pixels_per_em.unwrap_or((0, 0))
    let coords = face.variation_coordinates().length()
    if this.x_device is Some(device) {
      if ppem_x != 0 || coords != 0 {
        x += device_get_x_delta(device, face).unwrap_or(0)
      }
    }
    if this.y_device is Some(device) {
      if ppem_y != 0 || coords != 0 {
        y += device_get_y_delta(device, face).unwrap_or(0)
      }
    }
  }
  (x, y)
}

// attach_type

///|
const ATTACH_TYPE_MARK : Int = 1

///|
const ATTACH_TYPE_CURSIVE : Int = 2

///|
/// `i32::try_num_from(f32)`: values in `(MIN-1, MAX+1)` truncate toward zero.
fn try_i32_from_f32(v : Float) -> Int? {
  // Based on https://github.com/rust-num/num-traits/blob/master/src/cast.rs

  // Float as int truncates toward zero, so we want to allow values
  // in the exclusive range `(MIN-1, MAX+1)`.

  // We can't represent `MIN-1` exactly, but there's no fractional part
  // at this magnitude, so we can just use a `MIN` inclusive boundary.
  let min : Float = -2147483648.0
  // We can't represent `MAX` exactly, but it will round up to exactly
  // `MAX+1` (a power of two) when we cast it.
  let max_p1 : Float = 2147483648.0
  if v >= min && v < max_p1 {
    Some(v.to_double().to_int())
  } else {
    None
  }
}

///|
/// Rust's `f32::round`.
fn f32_round(v : Float) -> Float {
  let d = v.to_double()
  if d.is_nan() || d.is_inf() {
    return v
  }
  let r = if d < 0.0 { -(-d + 0.5).floor() } else { (d + 0.5).floor() }
  // |v| >= 2^23 are integers already.
  if d.abs() >= 8388608.0 {
    v
  } else {
    Float::from_double(r)
  }
}

///|
fn device_get_x_delta(this : @otf.Device, face : Face) -> Int? {
  match this {
    Hinting(hinting) =>
      hinting.x_delta(face.units_per_em.to_uint16(), ppem_u16(face))
    Variation(variation) => {
      guard face.tables().gdef is Some(gdef) else { return None }
      gdef
      .glyph_variation_delta(
        variation.outer_index,
        variation.inner_index,
        face.variation_coordinates(),
      )
      .bind(float => try_i32_from_f32(f32_round(float)))
    }
  }
}

///|
fn device_get_y_delta(this : @otf.Device, face : Face) -> Int? {
  match this {
    Hinting(hinting) =>
      hinting.y_delta(face.units_per_em.to_uint16(), ppem_u16(face))
    Variation(variation) => {
      guard face.tables().gdef is Some(gdef) else { return None }
      gdef
      .glyph_variation_delta(
        variation.outer_index,
        variation.inner_index,
        face.variation_coordinates(),
      )
      .bind(float => try_i32_from_f32(f32_round(float)))
    }
  }
}

///|
fn ppem_u16(face : Face) -> (UInt16, UInt16)? {
  face.pixels_per_em.map(p => (p.0.to_uint16(), p.1.to_uint16()))
}

///|
fn pos_subtable_apply(
  this : @otf.PositioningSubtable,
  ctx : ApplyContext,
) -> Unit? {
  match this {
    Single(t) => single_pos_apply(t, ctx)
    Pair(t) => pair_pos_apply(t, ctx)
    Cursive(t) => cursive_pos_apply(t, ctx)
    MarkToBase(t) => mark_base_pos_apply(t, ctx)
    MarkToLigature(t) => mark_lig_pos_apply(t, ctx)
    MarkToMark(t) => mark_mark_pos_apply(t, ctx)
    Context(t) => context_apply(t, ctx)
    ChainContext(t) => chained_context_apply(t, ctx)
  }
}

///|
fn propagate_attachment_offsets(
  pos : Array[GlyphPosition],
  len : Int,
  i : Int,
  direction : Direction,
) -> Unit {
  // Adjusts offsets of attached glyphs (both cursive and mark) to accumulate
  // offset of glyph they are attached to.
  let chain = pos[i].attach_chain()
  let kind = pos[i].attach_type()
  if chain == 0 {
    return
  }
  pos[i].set_attach_chain(0)
  let j = i + chain
  // `as usize`: negative indices wrap to huge values.
  if j < 0 || j >= len {
    return
  }
  propagate_attachment_offsets(pos, len, j, direction)
  match kind {
    ATTACH_TYPE_MARK => {
      pos[i].x_offset += pos[j].x_offset
      pos[i].y_offset += pos[j].y_offset
      guard! j < i
      if direction.is_forward() {
        for k in j..<i {
          pos[i].x_offset -= pos[k].x_advance
          pos[i].y_offset -= pos[k].y_advance
        }
      } else {
        for k in (j + 1)..<(i + 1) {
          pos[i].x_offset += pos[k].x_advance
          pos[i].y_offset += pos[k].y_advance
        }
      }
    }
    ATTACH_TYPE_CURSIVE =>
      if direction.is_horizontal() {
        pos[i].y_offset += pos[j].y_offset
      } else {
        pos[i].x_offset += pos[j].x_offset
      }
    _ => ()
  }
}

// mod GPOS

///|
fn gpos_position_start(_face : Face, buffer : Buffer) -> Unit {
  for i in 0..<buffer.len {
    let pos = buffer.pos[i]
    pos.set_attach_chain(0)
    pos.set_attach_type(0)
  }
}

///|
fn gpos_position_finish_advances(_face : Face, _buffer : Buffer) -> Unit {

}

///|
fn gpos_position_finish_offsets(_face : Face, buffer : Buffer) -> Unit {
  let len = buffer.len
  let direction = buffer.direction

  // Handle attachments
  if (buffer.scratch_flags & HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT) != 0 {
    for i in 0..<len {
      propagate_attachment_offsets(buffer.pos, len, i, direction)
    }
  }
}

// pos_lookup.rs

///|
impl LayoutLookup for PositioningLookup with fn props(self) {
  self.props
}

///|
impl LayoutLookup for PositioningLookup with fn is_reverse(_self) {
  false
}

///|
impl LayoutLookup for PositioningLookup with fn digest(self) {
  self.set_digest
}

///|
impl LayoutLookup for PositioningLookup with fn apply(self, ctx) {
  if self.set_digest.may_have_glyph(ctx.buffer.cur(0).as_glyph().0.to_int()) {
    for subtable in self.subtables {
      if pos_subtable_apply(subtable, ctx) is Some(_) {
        return Some(())
      }
    }
  }
  None
}

// single_pos.rs

///|
fn single_pos_apply(this : @otf.SingleAdjustment, ctx : ApplyContext) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  let record = match this {
    Format1(coverage~, value~) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      value
    }
    Format2(coverage~, values~) => {
      guard coverage.get(glyph) is Some(index) else { return None }
      guard values.get(index) is Some(v) else { return None }
      v
    }
  }
  value_record_apply(record, ctx, ctx.buffer.idx) |> ignore
  ctx.buffer.idx += 1
  Some(())
}

// pair_pos.rs

///|
fn pair_pos_apply(this : @otf.PairAdjustment, ctx : ApplyContext) -> Unit? {
  let first_glyph = ctx.buffer.cur(0).as_glyph()
  guard this.coverage().get(first_glyph) is Some(first_glyph_coverage_index) else {
    return None
  }
  let iter = SkippingIterator::new(ctx, ctx.buffer.idx, false)
  let unsafe_to = Ref(0)
  if !iter.next(Some(unsafe_to)) {
    ctx.buffer.unsafe_to_concat(Some(ctx.buffer.idx), Some(unsafe_to.val))
    return None
  }
  let second_glyph_index = iter.index()
  let second_glyph = ctx.buffer.info[second_glyph_index].as_glyph()
  let finish = (has_record2 : Bool) => {
    if has_record2 {
      iter.buf_idx += 1
      // https://github.com/harfbuzz/harfbuzz/issues/3824
      // https://github.com/harfbuzz/harfbuzz/issues/3888#issuecomment-1326781116
      ctx.buffer.unsafe_to_break(Some(ctx.buffer.idx), Some(iter.buf_idx + 1))
    }
    ctx.buffer.idx = iter.buf_idx
    Some(())
  }
  let boring = (has_record2 : Bool) => {
    ctx.buffer.unsafe_to_concat(
      Some(ctx.buffer.idx),
      Some(second_glyph_index + 1),
    )
    finish(has_record2)
  }
  let success = (flag1 : Bool, flag2 : Bool, has_record2 : Bool) => {
    if flag1 || flag2 {
      ctx.buffer.unsafe_to_break(
        Some(ctx.buffer.idx),
        Some(second_glyph_index + 1),
      )
      finish(has_record2)
    } else {
      boring(has_record2)
    }
  }
  let bail = (records : (@otf.ValueRecord, @otf.ValueRecord)) => {
    let has_record1 = !value_record_is_empty(records.0)
    let has_record2 = !value_record_is_empty(records.1)
    let flag1 = has_record1 &&
      value_record_apply(records.0, ctx, ctx.buffer.idx)
    let flag2 = has_record2 &&
      value_record_apply(records.1, ctx, second_glyph_index)
    success(flag1, flag2, has_record2)
  }
  let records = match this {
    Format1(sets~, ..) => {
      guard sets.get(first_glyph_coverage_index) is Some(set) else {
        return None
      }
      guard set.get(second_glyph) is Some(v) else { return None }
      v
    }
    Format2(classes~, matrix~, ..) => {
      let classes = (classes.0.get(first_glyph), classes.1.get(second_glyph))
      let records = match matrix.get(classes) {
        Some(v) => v
        None => {
          ctx.buffer.unsafe_to_concat(
            Some(ctx.buffer.idx),
            Some(iter.index() + 1),
          )
          return None
        }
      }
      return bail(records)
    }
  }
  bail(records)
}

// cursive_pos.rs

///|
fn cursive_pos_apply(
  this : @otf.CursiveAdjustment,
  ctx : ApplyContext,
) -> Unit? {
  let this_glyph = ctx.buffer.cur(0).as_glyph()
  guard this.coverage.get(this_glyph) is Some(index_this) else { return None }
  guard this.sets.entry(index_this) is Some(entry_this) else { return None }
  let iter = SkippingIterator::new(ctx, ctx.buffer.idx, false)
  let unsafe_from = Ref(0)
  if !iter.prev(Some(unsafe_from)) {
    ctx.buffer.unsafe_to_concat_from_outbuffer(
      Some(unsafe_from.val),
      Some(ctx.buffer.idx + 1),
    )
    return None
  }
  let i = iter.index()
  let prev = ctx.buffer.info[i].as_glyph()
  guard this.coverage.get(prev) is Some(index_prev) else { return None }
  guard this.sets.exit(index_prev) is Some(exit_prev) else {
    ctx.buffer.unsafe_to_concat_from_outbuffer(
      Some(iter.index()),
      Some(ctx.buffer.idx + 1),
    )
    return None
  }
  let (exit_x, exit_y) = anchor_get(exit_prev, ctx.face)
  let (entry_x, entry_y) = anchor_get(entry_this, ctx.face)
  let direction = ctx.buffer.direction
  let j = ctx.buffer.idx
  ctx.buffer.unsafe_to_break(Some(i), Some(j + 1))
  let pos = ctx.buffer.pos
  match direction {
    LeftToRight => {
      pos[i].x_advance = exit_x + pos[i].x_offset
      let d = entry_x + pos[j].x_offset
      pos[j].x_advance -= d
      pos[j].x_offset -= d
    }
    RightToLeft => {
      let d = exit_x + pos[i].x_offset
      pos[i].x_advance -= d
      pos[i].x_offset -= d
      pos[j].x_advance = entry_x + pos[j].x_offset
    }
    TopToBottom => {
      pos[i].y_advance = exit_y + pos[i].y_offset
      let d = entry_y + pos[j].y_offset
      pos[j].y_advance -= d
      pos[j].y_offset -= d
    }
    BottomToTop => {
      let d = exit_y + pos[i].y_offset
      pos[i].y_advance -= d
      pos[i].y_offset -= d
      pos[j].y_advance = entry_y
    }
    Invalid => ()
  }

  // Cross-direction adjustment

  // We attach child to parent (think graph theory and rooted trees whereas
  // the root stays on baseline and each node aligns itself against its
  // parent.
  //
  // Optimize things for the case of RightToLeft, as that's most common in
  // Arabic.
  let mut child = i
  let mut parent = j
  let mut x_offset = entry_x - exit_x
  let mut y_offset = entry_y - exit_y

  // Low bits are lookup flags, so we want to truncate.
  if (
      ctx.lookup_props.reinterpret_as_int() & 0xFFFF & LOOKUP_FLAG_RIGHT_TO_LEFT
    ) ==
    0 {
    let t = child
    child = parent
    parent = t
    x_offset = -x_offset
    y_offset = -y_offset
  }

  // If child was already connected to someone else, walk through its old
  // chain and reverse the link direction, such that the whole tree of its
  // previous connection now attaches to new parent.  Watch out for case
  // where new parent is on the path from old chain...
  reverse_cursive_minor_offset(pos, child, direction, parent)
  pos[child].set_attach_type(ATTACH_TYPE_CURSIVE)
  pos[child].set_attach_chain(parent - child)
  ctx.buffer.scratch_flags = ctx.buffer.scratch_flags |
    HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT
  if direction.is_horizontal() {
    pos[child].y_offset = y_offset
  } else {
    pos[child].x_offset = x_offset
  }

  // If parent was attached to child, separate them.
  // https://github.com/harfbuzz/harfbuzz/issues/2469
  if pos[parent].attach_chain() == i16_neg(pos[child].attach_chain()) {
    pos[parent].set_attach_chain(0)
    if direction.is_horizontal() {
      pos[parent].y_offset = 0
    } else {
      pos[parent].x_offset = 0
    }
  }
  ctx.buffer.idx += 1
  Some(())
}

///|
/// `-x` for an `i16` (wrapping).
fn i16_neg(x : Int) -> Int {
  let v = -x & 0xFFFF
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
fn reverse_cursive_minor_offset(
  pos : Array[GlyphPosition],
  i : Int,
  direction : Direction,
  new_parent : Int,
) -> Unit {
  let chain = pos[i].attach_chain()
  let attach_type = pos[i].attach_type()
  if chain == 0 || (attach_type & ATTACH_TYPE_CURSIVE) == 0 {
    return
  }
  pos[i].set_attach_chain(0)

  // Stop if we see new parent in the chain.
  let j = i + chain
  if j == new_parent {
    return
  }
  reverse_cursive_minor_offset(pos, j, direction, new_parent)
  if direction.is_horizontal() {
    pos[j].y_offset = -pos[i].y_offset
  } else {
    pos[j].x_offset = -pos[i].x_offset
  }
  pos[j].set_attach_chain(i16_neg(chain))
  pos[j].set_attach_type(attach_type)
}

// mark_array.rs

///|
fn mark_array_apply(
  this : @otf.MarkArray,
  ctx : ApplyContext,
  anchors : @otf.AnchorMatrix,
  mark_index : UInt16,
  glyph_index : UInt16,
  glyph_pos : Int,
) -> Unit? {
  // If this subtable doesn't have an anchor for this base and this class
  // return `None` such that the subsequent subtables have a chance at it.
  guard this.get(mark_index) is Some((mark_class, mark_anchor)) else {
    return None
  }
  guard anchors.get(glyph_index, mark_class) is Some(base_anchor) else {
    return None
  }
  let (mark_x, mark_y) = anchor_get(mark_anchor, ctx.face)
  let (base_x, base_y) = anchor_get(base_anchor, ctx.face)
  ctx.buffer.unsafe_to_break(Some(glyph_pos), Some(ctx.buffer.idx + 1))
  let idx = ctx.buffer.idx
  let pos = ctx.buffer.cur_pos()
  pos.x_offset = base_x - mark_x
  pos.y_offset = base_y - mark_y
  pos.set_attach_type(ATTACH_TYPE_MARK)
  pos.set_attach_chain(glyph_pos - idx)
  ctx.buffer.scratch_flags = ctx.buffer.scratch_flags |
    HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT
  ctx.buffer.idx += 1
  Some(())
}

// mark_base_pos.rs

///|
fn mark_base_pos_apply(
  this : @otf.MarkToBaseAdjustment,
  ctx : ApplyContext,
) -> Unit? {
  let buffer = ctx.buffer
  let mark_glyph = ctx.buffer.cur(0).as_glyph()
  guard this.mark_coverage.get(mark_glyph) is Some(mark_index) else {
    return None
  }

  // Due to borrowing rules, we have this piece of code before creating the
  // iterator, unlike in harfbuzz.
  if ctx.last_base_until > buffer.idx {
    ctx.last_base_until = 0
    ctx.last_base = -1
  }

  // Now we search backwards for a non-mark glyph
  // We don't use skippy_iter.prev() to avoid O(n^2) behavior.
  let iter = SkippingIterator::new(ctx, 0, false)
  iter.set_lookup_props(LOOKUP_FLAG_IGNORE_MARKS.reinterpret_as_uint())
  let mut j = buffer.idx
  while j > ctx.last_base_until {
    let mut match_ = iter.match_(buffer.info[j - 1])
    if match_ == Match {
      // https://github.com/harfbuzz/harfbuzz/issues/4124
      if !mark_base_accept(buffer, j - 1) &&
        !this.base_coverage.contains(buffer.info[j - 1].as_glyph()) {
        match_ = Skip
      }
    }
    if match_ == Match {
      ctx.last_base = j - 1
      break
    }
    j -= 1
  }
  ctx.last_base_until = buffer.idx
  if ctx.last_base == -1 {
    ctx.buffer.unsafe_to_concat_from_outbuffer(Some(0), Some(buffer.idx + 1))
    return None
  }
  let idx = ctx.last_base
  let info = buffer.info

  // Checking that matched glyph is actually a base glyph by GDEF is too strong; disabled
  let base_glyph = info[idx].as_glyph()
  guard this.base_coverage.get(base_glyph) is Some(base_index) else {
    ctx.buffer.unsafe_to_concat_from_outbuffer(Some(idx), Some(buffer.idx + 1))
    return None
  }
  mark_array_apply(this.marks, ctx, this.anchors, mark_index, base_index, idx)
}

///|
fn mark_base_accept(buffer : Buffer, idx : Int) -> Bool {
  // We only want to attach to the first of a MultipleSubst sequence.
  // https://github.com/harfbuzz/harfbuzz/issues/740
  // Reject others...
  // ...but stop if we find a mark in the MultipleSubst sequence:
  // https://github.com/harfbuzz/harfbuzz/issues/1020
  !buffer.info[idx].multiplied() ||
  0 == buffer.info[idx].get_lig_comp() ||
  idx == 0 ||
  buffer.info[idx - 1].is_mark() ||
  !buffer.info[idx - 1].multiplied() ||
  buffer.info[idx].get_lig_id() != buffer.info[idx - 1].get_lig_id() ||
  buffer.info[idx].get_lig_comp() != buffer.info[idx - 1].get_lig_comp() + 1
}

// mark_lig_pos.rs

///|
fn mark_lig_pos_apply(
  this : @otf.MarkToLigatureAdjustment,
  ctx : ApplyContext,
) -> Unit? {
  let buffer = ctx.buffer
  let mark_glyph = ctx.buffer.cur(0).as_glyph()
  guard this.mark_coverage.get(mark_glyph) is Some(mark_index) else {
    return None
  }

  // Due to borrowing rules, we have this piece of code before creating the
  // iterator, unlike in harfbuzz.
  if ctx.last_base_until > buffer.idx {
    ctx.last_base_until = 0
    ctx.last_base = -1
  }

  // Now we search backwards for a non-mark glyph
  let iter = SkippingIterator::new(ctx, 0, false)
  iter.set_lookup_props(LOOKUP_FLAG_IGNORE_MARKS.reinterpret_as_uint())
  let mut j = buffer.idx
  while j > ctx.last_base_until {
    let match_ = iter.match_(buffer.info[j - 1])
    if match_ == Match {
      ctx.last_base = j - 1
      break
    }
    j -= 1
  }
  ctx.last_base_until = buffer.idx
  if ctx.last_base == -1 {
    ctx.buffer.unsafe_to_concat_from_outbuffer(Some(0), Some(buffer.idx + 1))
    return None
  }
  let idx = ctx.last_base

  // Checking that matched glyph is actually a ligature by GDEF is too strong; disabled

  let lig_glyph = buffer.info[idx].as_glyph()
  guard this.ligature_coverage.get(lig_glyph) is Some(lig_index) else {
    ctx.buffer.unsafe_to_concat_from_outbuffer(Some(idx), Some(buffer.idx + 1))
    return None
  }
  guard this.ligature_array.get(lig_index) is Some(lig_attach) else {
    return None
  }

  // Find component to attach to
  let comp_count = lig_attach.rows.to_int()
  if comp_count == 0 {
    ctx.buffer.unsafe_to_concat_from_outbuffer(Some(idx), Some(buffer.idx + 1))
    return None
  }

  // We must now check whether the ligature ID of the current mark glyph
  // is identical to the ligature ID of the found ligature.  If yes, we
  // can directly use the component index.  If not, we attach the mark
  // glyph to the last component of the ligature.
  let lig_id = buffer.info[idx].get_lig_id()
  let mark_id = buffer.cur(0).get_lig_id()
  let mark_comp = buffer.cur(0).get_lig_comp()
  let matches = lig_id != 0 && lig_id == mark_id && mark_comp > 0
  let comp_index = (if matches {
      imin(mark_comp, comp_count)
    } else {
      comp_count
    }) -
    1
  mark_array_apply(
    this.marks,
    ctx,
    lig_attach,
    mark_index,
    comp_index.to_uint16(),
    idx,
  )
}

// mark_mark_pos.rs

///|
fn mark_mark_pos_apply(
  this : @otf.MarkToMarkAdjustment,
  ctx : ApplyContext,
) -> Unit? {
  let buffer = ctx.buffer
  let mark1_glyph = ctx.buffer.cur(0).as_glyph()
  guard this.mark1_coverage.get(mark1_glyph) is Some(mark1_index) else {
    return None
  }

  // Now we search backwards for a suitable mark glyph until a non-mark glyph
  let iter = SkippingIterator::new(ctx, buffer.idx, false)
  iter.set_lookup_props(
    ctx.lookup_props &
    (LOOKUP_FLAG_IGNORE_FLAGS.reinterpret_as_uint() ^ 0xFFFFFFFF),
  )
  let unsafe_from = Ref(0)
  if !iter.prev(Some(unsafe_from)) {
    ctx.buffer.unsafe_to_concat_from_outbuffer(
      Some(unsafe_from.val),
      Some(ctx.buffer.idx + 1),
    )
    return None
  }
  let iter_idx = iter.index()
  if !buffer.info[iter_idx].is_mark() {
    ctx.buffer.unsafe_to_concat_from_outbuffer(
      Some(iter_idx),
      Some(buffer.idx + 1),
    )
    return None
  }
  let id1 = buffer.cur(0).get_lig_id()
  let id2 = buffer.info[iter_idx].get_lig_id()
  let comp1 = buffer.cur(0).get_lig_comp()
  let comp2 = buffer.info[iter_idx].get_lig_comp()
  let matches = if id1 == id2 {
    // Marks belonging to the same base
    // or marks belonging to the same ligature component.
    id1 == 0 || comp1 == comp2
  } else {
    // If ligature ids don't match, it may be the case that one of the marks
    // itself is a ligature.  In which case match.
    (id1 > 0 && comp1 == 0) || (id2 > 0 && comp2 == 0)
  }
  if !matches {
    ctx.buffer.unsafe_to_concat_from_outbuffer(
      Some(iter_idx),
      Some(buffer.idx + 1),
    )
    return None
  }
  let mark2_glyph = buffer.info[iter_idx].as_glyph()
  guard this.mark2_coverage.get(mark2_glyph) is Some(mark2_index) else {
    return None
  }
  mark_array_apply(
    this.marks,
    ctx,
    this.mark2_matrix,
    mark1_index,
    mark2_index,
    iter_idx,
  )
}
