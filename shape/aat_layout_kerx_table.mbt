// Port of rustybuzz 0.20.1 `src/hb/aat_layout_kerx_table.rs`.

// TODO: Use set_digest, similarly to how it's used in harfbuzz.

///|
fn kerx_apply(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit? {
  buffer.unsafe_to_concat(None, None)
  guard face.tables().kerx is Some(kerx) else { return None }
  let mut seen_cross_stream = false
  for subtable in kerx.subtables.iter() {
    if subtable.variable {
      continue
    }
    if buffer.direction.is_horizontal() != subtable.horizontal {
      continue
    }
    let reverse = buffer.direction.is_backward()
    if !seen_cross_stream && subtable.has_cross_stream {
      seen_cross_stream = true

      // Attach all glyphs into a chain.
      for pos in buffer.pos {
        pos.set_attach_type(ATTACH_TYPE_CURSIVE)
        pos.set_attach_chain(if buffer.direction.is_forward() { -1 } else { 1 })
        // We intentionally don't set BufferScratchFlags::HAS_GPOS_ATTACHMENT,
        // since there needs to be a non-zero attachment for post-positioning to
        // be needed.
      }
    }
    if reverse {
      buffer.reverse()
    }
    match subtable.format {
      Format0(_) => {
        if !plan.requested_kerning {
          continue
        }
        kerx_apply_simple_kerning(subtable, plan, face, buffer)
      }
      Format1(sub) => {
        let driver = KerxDriver1::{ stack: FixedArray::make(8, 0), depth: 0, }
        kerx_apply_state_machine_kerning(
          subtable,
          glyph => sub.class(glyph),
          (state, class) => sub.entry(state, class),
          (entry, has_cross_stream, tuple_count, plan, buffer) => {
            driver.transition(
              sub, entry, has_cross_stream, tuple_count, plan, buffer,
            )
            |> ignore
          },
          plan,
          buffer,
        )
      }
      Format2(_) => {
        if !plan.requested_kerning {
          continue
        }
        buffer.unsafe_to_concat(None, None)
        kerx_apply_simple_kerning(subtable, plan, face, buffer)
      }
      Format4(sub) => {
        let driver = KerxDriver4::{
          mark_set: false,
          mark: 0,
          ankr_table: face.tables().ankr,
        }
        kerx_apply_state_machine_kerning(
          subtable,
          glyph => sub.class(glyph),
          (state, class) => sub.entry(state, class),
          (entry, _, _, _, buffer) => {
            driver.transition(sub, entry, buffer) |> ignore
          },
          plan,
          buffer,
        )
      }
      Format6(_) => {
        if !plan.requested_kerning {
          continue
        }
        kerx_apply_simple_kerning(subtable, plan, face, buffer)
      }
    }
    if reverse {
      buffer.reverse()
    }
  }
  Some(())
}

///|
fn kerx_apply_simple_kerning(
  subtable : @otf.KerxSubtable,
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  let ctx = ApplyContext::new(GPOS, face, buffer)
  ctx.set_lookup_mask(plan.kern_mask)
  ctx.lookup_props = LOOKUP_FLAG_IGNORE_FLAGS.reinterpret_as_uint()
  let horizontal = ctx.buffer.direction.is_horizontal()
  let mut i = 0
  while i < ctx.buffer.len {
    if (ctx.buffer.info[i].mask & plan.kern_mask) == 0 {
      i += 1
      continue
    }
    let iter = SkippingIterator::new(ctx, i, false)
    let unsafe_to = Ref(0)
    if !iter.next(Some(unsafe_to)) {
      ctx.buffer.unsafe_to_concat(Some(i), Some(unsafe_to.val))
      i += 1
      continue
    }
    let j = iter.index()
    let info = ctx.buffer.info
    let kern = subtable
      .glyphs_kerning(info[i].as_glyph(), info[j].as_glyph())
      .unwrap_or(0)
    let kern = kern.to_int()
    let pos = ctx.buffer.pos
    if kern != 0 {
      if horizontal {
        if subtable.has_cross_stream {
          pos[j].y_offset = kern
          ctx.buffer.scratch_flags = ctx.buffer.scratch_flags |
            HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT
        } else {
          let kern1 = kern >> 1
          let kern2 = kern - kern1
          pos[i].x_advance += kern1
          pos[j].x_advance += kern2
          pos[j].x_offset += kern2
        }
      } else if subtable.has_cross_stream {
        pos[j].x_offset = kern
        ctx.buffer.scratch_flags = ctx.buffer.scratch_flags |
          HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT
      } else {
        let kern1 = kern >> 1
        let kern2 = kern - kern1
        pos[i].y_advance += kern1
        pos[j].y_advance += kern2
        pos[j].y_offset += kern2
      }
      ctx.buffer.unsafe_to_break(Some(i), Some(j + 1))
    }
    i = j
  }
}

///|
const KERX_START_OF_TEXT : UInt16 = 0

///|
/// `KerxEntryDataExt::is_actionable`
fn kerx_entry_is_actionable(
  entry : @otf.GenericStateEntry[@otf.KerxEntryData],
) -> Bool {
  entry.extra.action_index != 0xFFFF
}

///|
fn kerx_apply_state_machine_kerning(
  subtable : @otf.KerxSubtable,
  state_table_class : (@otf.GlyphId) -> UInt16?,
  state_table_entry : (UInt16, UInt16) -> @otf.GenericStateEntry[
    @otf.KerxEntryData,
  ]?,
  transition : (
    @otf.GenericStateEntry[@otf.KerxEntryData],
    Bool,
    UInt,
    ShapePlan,
    Buffer,
  ) -> Unit,
  plan : ShapePlan,
  buffer : Buffer,
) -> Unit {
  let end_of_text = @otf.aat_class_end_of_text.to_int().to_uint16()
  let mut state = KERX_START_OF_TEXT
  buffer.idx = 0
  while true {
    let class = if buffer.idx < buffer.len {
      state_table_class(buffer.info[buffer.idx].as_glyph()).unwrap_or(1)
    } else {
      end_of_text
    }
    let entry = match state_table_entry(state, class) {
      Some(v) => v
      None => break
    }

    // Unsafe-to-break before this if not in state 0, as things might
    // go differently if we start from state 0 here.
    if state != KERX_START_OF_TEXT &&
      buffer.backtrack_len() != 0 &&
      buffer.idx < buffer.len {
      // If there's no value and we're just epsilon-transitioning to state 0, safe to break.
      if kerx_entry_is_actionable(entry) ||
        entry.new_state != KERX_START_OF_TEXT ||
        entry.has_advance() {
        buffer.unsafe_to_break_from_outbuffer(
          Some(buffer.backtrack_len() - 1),
          Some(buffer.idx + 1),
        )
      }
    }

    // Unsafe-to-break if end-of-text would kick in here.
    if buffer.idx + 2 <= buffer.len {
      let end_entry = match state_table_entry(state, end_of_text) {
        Some(v) => v
        None => break
      }
      if kerx_entry_is_actionable(end_entry) {
        buffer.unsafe_to_break(Some(buffer.idx), Some(buffer.idx + 2))
      }
    }
    transition(
      entry,
      subtable.has_cross_stream,
      subtable.tuple_count,
      plan,
      buffer,
    )
    state = entry.new_state
    if buffer.idx >= buffer.len {
      break
    }
    if entry.has_advance() || buffer.max_ops <= 0 {
      buffer.next_glyph()
    }
    buffer.max_ops -= 1
  }
}

///|
priv struct KerxDriver1 {
  stack : FixedArray[Int]
  mut depth : Int
}

///|
fn KerxDriver1::transition(
  self : KerxDriver1,
  aat : @otf.KerxSubtable1,
  entry : @otf.GenericStateEntry[@otf.KerxEntryData],
  has_cross_stream : Bool,
  tuple_count : UInt,
  plan : ShapePlan,
  buffer : Buffer,
) -> Unit? {
  if entry.has_reset() {
    self.depth = 0
  }
  if entry.has_push() {
    if self.depth < self.stack.length() {
      self.stack[self.depth] = buffer.idx
      self.depth += 1
    } else {
      self.depth = 0 // Probably not what CoreText does, but better?
    }
  }
  if kerx_entry_is_actionable(entry) && self.depth != 0 {
    let tuple_count = if tuple_count > 1 { tuple_count } else { 1 }
    guard tuple_count <= 0xFFFF else { return None }
    let tuple_count = tuple_count.reinterpret_as_int()
    let mut action_index = entry.extra.action_index.to_int()

    // From Apple 'kern' spec:
    // "Each pops one glyph from the kerning stack and applies the kerning value to it.
    // The end of the list is marked by an odd value...
    let mut last = false
    while !last && self.depth != 0 {
      self.depth -= 1
      let idx = self.stack[self.depth]
      guard aat.glyphs_kerning(action_index.to_uint16()) is Some(v) else {
        return None
      }
      let mut v = v.to_int()
      action_index = action_index + tuple_count
      guard action_index <= 0xFFFF else { return None }
      if idx >= buffer.len {
        continue
      }

      // "The end of the list is marked by an odd value..."
      last = (v & 1) != 0
      v = v & -2

      // Testing shows that CoreText only applies kern (cross-stream or not)
      // if none has been applied by previous subtables. That is, it does
      // NOT seem to accumulate as otherwise implied by specs.

      let mut has_gpos_attachment = false
      let glyph_mask = buffer.info[idx].mask
      let pos = buffer.pos[idx]
      if buffer.direction.is_horizontal() {
        if has_cross_stream {
          // The following flag is undocumented in the spec, but described
          // in the 'kern' table example.
          if v == -0x8000 {
            pos.set_attach_type(0)
            pos.set_attach_chain(0)
            pos.y_offset = 0
          } else if pos.attach_type() != 0 {
            pos.y_offset += v
            has_gpos_attachment = true
          }
        } else if (glyph_mask & plan.kern_mask) != 0 {
          pos.x_advance += v
          pos.x_offset += v
        }
      } else if has_cross_stream {
        // CoreText doesn't do crossStream kerning in vertical. We do.
        if v == -0x8000 {
          pos.set_attach_type(0)
          pos.set_attach_chain(0)
          pos.x_offset = 0
        } else if pos.attach_type() != 0 {
          pos.x_offset += v
          has_gpos_attachment = true
        }
      } else if (glyph_mask & plan.kern_mask) != 0 {
        if pos.y_offset == 0 {
          pos.y_advance += v
          pos.y_offset += v
        }
      }
      if has_gpos_attachment {
        buffer.scratch_flags = buffer.scratch_flags |
          HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT
      }
    }
  }
  Some(())
}

///|
priv struct KerxDriver4 {
  mut mark_set : Bool
  mut mark : Int
  ankr_table : @otf.AnkrTable?
}

///|
fn KerxDriver4::transition(
  self : KerxDriver4,
  aat : @otf.KerxSubtable4,
  entry : @otf.GenericStateEntry[@otf.KerxEntryData],
  buffer : Buffer,
) -> Unit? {
  if self.mark_set && kerx_entry_is_actionable(entry) && buffer.idx < buffer.len {
    if self.ankr_table is Some(ankr_table) {
      guard aat.anchor_points.get(entry.extra.action_index) is Some(point) else {
        return None
      }
      let mark_idx = buffer.info[self.mark].as_glyph()
      let mark_anchor = match
        ankr_table.points(mark_idx).bind(list => list.get(point.0.to_uint())) {
        Some(p) => p
        None => { x: 0, y: 0, }
      }
      let curr_idx = buffer.cur(0).as_glyph()
      let curr_anchor = match
        ankr_table.points(curr_idx).bind(list => list.get(point.1.to_uint())) {
        Some(p) => p
        None => { x: 0, y: 0, }
      }
      let pos = buffer.cur_pos()
      pos.x_offset = mark_anchor.x.to_int() - curr_anchor.x.to_int()
      pos.y_offset = mark_anchor.y.to_int() - curr_anchor.y.to_int()
    }
    buffer.cur_pos().set_attach_type(ATTACH_TYPE_MARK)
    let idx = buffer.idx
    buffer.cur_pos().set_attach_chain(self.mark - idx)
    buffer.scratch_flags = buffer.scratch_flags |
      HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT
  }
  if entry.has_mark() {
    self.mark_set = true
    self.mark = buffer.idx
  }
  Some(())
}
