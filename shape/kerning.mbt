// Port of rustybuzz 0.20.1 `src/hb/kerning.rs` (legacy `kern` table).

///|
fn hb_ot_layout_kern(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit {
  let subtables = match face.tables().kern {
    Some(table) => table.subtables
    None => return
  }
  let mut seen_cross_stream = false
  for subtable in subtables.iter() {
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
    if subtable.has_state_machine {
      apply_state_machine_kerning(subtable, plan.kern_mask, buffer)
    } else {
      if !plan.requested_kerning {
        continue
      }
      apply_simple_kerning(subtable, face, plan.kern_mask, buffer)
    }
    if reverse {
      buffer.reverse()
    }
  }
}

///|
fn machine_kern(
  face : Face,
  buffer : Buffer,
  kern_mask : UInt,
  cross_stream : Bool,
  get_kerning : (UInt, UInt) -> Int,
) -> Unit {
  buffer.unsafe_to_concat(None, None)
  let ctx = ApplyContext::new(GPOS, face, buffer)
  ctx.set_lookup_mask(kern_mask)
  ctx.lookup_props = LOOKUP_FLAG_IGNORE_MARKS.reinterpret_as_uint()
  let horizontal = ctx.buffer.direction.is_horizontal()
  let mut i = 0
  while i < ctx.buffer.len {
    if (ctx.buffer.info[i].mask & kern_mask) == 0 {
      i += 1
      continue
    }
    let iter = SkippingIterator::new(ctx, i, false)
    let unsafe_to = Ref(0)
    if !iter.next(Some(unsafe_to)) {
      i += 1
      continue
    }
    let j = iter.index()
    let info = ctx.buffer.info
    let kern = get_kerning(info[i].glyph_id, info[j].glyph_id)
    let pos = ctx.buffer.pos
    if kern != 0 {
      if horizontal {
        if cross_stream {
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
      } else if cross_stream {
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
fn apply_simple_kerning(
  subtable : @otf.KernSubtable,
  face : Face,
  kern_mask : UInt,
  buffer : Buffer,
) -> Unit {
  machine_kern(face, buffer, kern_mask, subtable.has_cross_stream, (left, right) => {
    subtable
    .glyphs_kerning(
      @otf.GlyphId((left & 0xFFFF).to_uint16()),
      @otf.GlyphId((right & 0xFFFF).to_uint16()),
    )
    .map(v => v.to_int())
    .unwrap_or(0)
  })
}

///|
priv struct StateMachineDriver {
  stack : FixedArray[Int]
  mut depth : Int
}

///|
fn apply_state_machine_kerning(
  subtable : @otf.KernSubtable,
  kern_mask : UInt,
  buffer : Buffer,
) -> Unit {
  let state_table = match subtable.format {
    Format1(state_table) => state_table
    _ => return
  }
  let driver : StateMachineDriver = { stack: FixedArray::make(8, 0), depth: 0, }
  let mut state = @otf.aat_state_start_of_text
  buffer.idx = 0
  while true {
    let class = if buffer.idx < buffer.len {
      state_table.class(buffer.info[buffer.idx].as_glyph()).unwrap_or(b'\x01')
    } else {
      @otf.aat_class_end_of_text
    }
    let entry = match state_table.entry(state, class) {
      Some(v) => v
      None => break
    }

    // Unsafe-to-break before this if not in state 0, as things might
    // go differently if we start from state 0 here.
    if state != @otf.aat_state_start_of_text &&
      buffer.backtrack_len() != 0 &&
      buffer.idx < buffer.len {
      // If there's no value and we're just epsilon-transitioning to state 0, safe to break.
      if entry.has_offset() ||
        entry.new_state != @otf.aat_state_start_of_text ||
        entry.has_advance() {
        buffer.unsafe_to_break_from_outbuffer(
          Some(buffer.backtrack_len() - 1),
          Some(buffer.idx + 1),
        )
      }
    }

    // Unsafe-to-break if end-of-text would kick in here.
    if buffer.idx + 2 <= buffer.len {
      let end_entry = match
        state_table.entry(state, @otf.aat_class_end_of_text) {
        Some(v) => v
        None => break
      }
      if end_entry.has_offset() {
        buffer.unsafe_to_break(Some(buffer.idx), Some(buffer.idx + 2))
      }
    }
    state_machine_transition(
      entry,
      subtable.has_cross_stream,
      kern_mask,
      state_table,
      driver,
      buffer,
    )
    state = state_table.new_state(entry.new_state)
    if buffer.idx >= buffer.len {
      break
    }
    buffer.max_ops -= 1
    if entry.has_advance() || buffer.max_ops <= 0 {
      buffer.next_glyph()
    }
  }
}

///|
fn state_machine_transition(
  entry : @otf.StateEntry,
  has_cross_stream : Bool,
  kern_mask : UInt,
  state_table : @otf.AatStateTable,
  driver : StateMachineDriver,
  buffer : Buffer,
) -> Unit {
  if entry.has_push() {
    if driver.depth < driver.stack.length() {
      driver.stack[driver.depth] = buffer.idx
      driver.depth += 1
    } else {
      driver.depth = 0 // Probably not what CoreText does, but better?
    }
  }
  if entry.has_offset() && driver.depth != 0 {
    let mut value_offset = entry.value_offset()
    let mut value = match state_table.kerning(value_offset) {
      Some(v) => v
      None => {
        driver.depth = 0
        return
      }
    }

    // From Apple 'kern' spec:
    // "Each pops one glyph from the kerning stack and applies the kerning value to it.
    // The end of the list is marked by an odd value...
    let mut last = false
    while !last && driver.depth != 0 {
      driver.depth -= 1
      let idx = driver.stack[driver.depth]
      let mut v = value.to_int()
      value_offset = value_offset.next()
      value = state_table.kerning(value_offset).unwrap_or(0)
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
        } else if (glyph_mask & kern_mask) != 0 {
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
      } else if (glyph_mask & kern_mask) != 0 {
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
}
