// Port of rustybuzz 0.20.1 `src/hb/ot_layout_gsubgpos.rs` (matching of
// glyph patterns).

///|
/// A match function: glyph and the value it is matched against (a glyph id,
/// class or coverage index, depending on the rule).
type MatchFunc = (@otf.GlyphId, Int) -> Bool

///|
/// Value represents glyph id.
fn match_glyph(glyph : @otf.GlyphId, value : Int) -> Bool {
  glyph.0.to_int() == value
}

///|
/// Value represents glyph class.
fn match_class(class_def : @otf.ClassDefinition) -> MatchFunc {
  (glyph, value) => class_def.get(glyph).to_int() == value
}

///|
priv enum Ligbase {
  NotChecked
  MayNotSkip
  MaySkip
} derive(Eq)

///|
/// `match_input`: returns whether the input matched; `end_position` and
/// `match_positions` are output parameters (single-element/resizable
/// arrays), as is `p_total_component_count`.
fn match_input(
  ctx : ApplyContext,
  input_len : Int,
  match_func : MatchFunc,
  end_position : Ref[Int],
  match_positions : Array[Int],
  p_total_component_count : Ref[Int]?,
) -> Bool {
  // This is perhaps the trickiest part of OpenType...  Remarks:
  //
  // - If all components of the ligature were marks, we call this a mark ligature.
  //
  // - If there is no GDEF, and the ligature is NOT a mark ligature, we categorize
  //   it as a ligature glyph.
  //
  // - Ligatures cannot be formed across glyphs attached to different components
  //   of previous ligatures.  Eg. the sequence is LAM,SHADDA,LAM,FATHA,HEH, and
  //   LAM,LAM,HEH form a ligature, leaving SHADDA,FATHA next to eachother.
  //   However, it would be wrong to ligate that SHADDA,FATHA sequence.
  //   There are a couple of exceptions to this:
  //
  //   o If a ligature tries ligating with marks that belong to it itself, go ahead,
  //     assuming that the font designer knows what they are doing (otherwise it can
  //     break Indic stuff when a matra wants to ligate with a conjunct,
  //
  //   o If two marks want to ligate and they belong to different components of the
  //     same ligature glyph, and said ligature glyph is to be ignored according to
  //     mark-filtering rules, then allow.
  //     https://github.com/harfbuzz/harfbuzz/issues/545

  let count = input_len + 1
  if count > MAX_CONTEXT_LENGTH {
    return false
  }
  while count > match_positions.length() {
    match_positions.push(0)
  }
  let iter = SkippingIterator::new(ctx, ctx.buffer.idx, false)
  iter.set_glyph_data(0)
  iter.enable_matching(match_func)
  let first = ctx.buffer.cur(0)
  let first_lig_id = first.get_lig_id()
  let first_lig_comp = first.get_lig_comp()
  let mut total_component_count = 0
  let mut ligbase = NotChecked
  for position in 1..<count {
    let unsafe_to = Ref(0)
    if !iter.next(Some(unsafe_to)) {
      end_position.val = unsafe_to.val
      return false
    }
    match_positions[position] = iter.index()
    let this = ctx.buffer.info[iter.index()]
    let this_lig_id = this.get_lig_id()
    let this_lig_comp = this.get_lig_comp()
    if first_lig_id != 0 && first_lig_comp != 0 {
      // If first component was attached to a previous ligature component,
      // all subsequent components should be attached to the same ligature
      // component, otherwise we shouldn't ligate them...
      if first_lig_id != this_lig_id || first_lig_comp != this_lig_comp {
        // ...unless, we are attached to a base ligature and that base
        // ligature is ignorable.
        if ligbase == NotChecked {
          let out = ctx.buffer.out_info()
          let mut j = ctx.buffer.out_len
          let mut found = false
          while j > 0 && out[j - 1].get_lig_id() == first_lig_id {
            if out[j - 1].get_lig_comp() == 0 {
              j -= 1
              found = true
              break
            }
            j -= 1
          }
          ligbase = if found && iter.may_skip(out[j]) == SkipYes {
            MaySkip
          } else {
            MayNotSkip
          }
        }
        if ligbase == MayNotSkip {
          return false
        }
      }
    } else if this_lig_id != 0 &&
      this_lig_comp != 0 &&
      this_lig_id != first_lig_id {
      // If first component was NOT attached to a previous ligature component,
      // all subsequent components should also NOT be attached to any ligature
      // component, unless they are attached to the first component itself!
      return false
    }
    total_component_count = (total_component_count + this.get_lig_num_comps()) &
      0xFF
  }
  end_position.val = iter.index() + 1
  if p_total_component_count is Some(p_total_component_count) {
    total_component_count = (total_component_count + first.get_lig_num_comps()) &
      0xFF
    p_total_component_count.val = total_component_count
  }
  match_positions[0] = ctx.buffer.idx
  true
}

///|
fn match_backtrack(
  ctx : ApplyContext,
  backtrack_len : Int,
  match_func : MatchFunc,
  match_start : Ref[Int],
) -> Bool {
  let iter = SkippingIterator::new(ctx, ctx.buffer.backtrack_len(), true)
  iter.set_glyph_data(0)
  iter.enable_matching(match_func)
  for _ in 0..<backtrack_len {
    let unsafe_from = Ref(0)
    if !iter.prev(Some(unsafe_from)) {
      match_start.val = unsafe_from.val
      return false
    }
  }
  match_start.val = iter.index()
  true
}

///|
fn match_lookahead(
  ctx : ApplyContext,
  lookahead_len : Int,
  match_func : MatchFunc,
  start_index : Int,
  end_index : Ref[Int],
) -> Bool {
  // Function should always be called with a non-zero starting index
  // c.f. https://github.com/harfbuzz/rustybuzz/issues/142
  guard! start_index >= 1
  let iter = SkippingIterator::new(ctx, start_index - 1, true)
  iter.set_glyph_data(0)
  iter.enable_matching(match_func)
  for _ in 0..<lookahead_len {
    let unsafe_to = Ref(0)
    if !iter.next(Some(unsafe_to)) {
      end_index.val = unsafe_to.val
      return false
    }
  }
  end_index.val = iter.index() + 1
  true
}

///|
/// In harfbuzz, skipping iterator works quite differently than it works
/// here: a new skipping iterator is created when needed (no `reset` and
/// `init`).
priv struct SkippingIterator {
  ctx : ApplyContext
  mut lookup_props : UInt
  ignore_zwnj : Bool
  ignore_zwj : Bool
  ignore_hidden : Bool
  mask : UInt
  syllable : Int
  mut matching : MatchFunc?
  buf_len : Int
  mut glyph_data : Int
  mut buf_idx : Int
}

///|
priv enum MatchT {
  Match
  NotMatch
  Skip
} derive(Eq)

///|
priv enum MayMatchT {
  MatchNo
  MatchYes
  MatchMaybe
} derive(Eq)

///|
priv enum MaySkipT {
  SkipNo
  SkipYes
  SkipMaybe
} derive(Eq)

///|
fn SkippingIterator::new(
  ctx : ApplyContext,
  start_buf_index : Int,
  context_match : Bool,
) -> SkippingIterator {
  {
    ctx,
    lookup_props: ctx.lookup_props,
    // Ignore ZWNJ if we are matching GPOS, or matching GSUB context and asked to.
    ignore_zwnj: ctx.table_index == GPOS || (context_match && ctx.auto_zwnj),
    // Ignore ZWJ if we are matching context, or asked to.
    ignore_zwj: context_match || ctx.auto_zwj,
    // Ignore hidden glyphs (like CGJ) during GPOS.
    ignore_hidden: ctx.table_index == GPOS,
    mask: if context_match {
      0xFFFFFFFF
    } else {
      ctx.lookup_mask()
    },
    syllable: if ctx.buffer.idx == start_buf_index && ctx.per_syllable {
      ctx.buffer.cur(0).syllable()
    } else {
      0
    },
    glyph_data: 0,
    matching: None,
    buf_len: ctx.buffer.len,
    buf_idx: start_buf_index,
  }
}

///|
fn SkippingIterator::set_glyph_data(
  self : SkippingIterator,
  glyph_data : Int,
) -> Unit {
  self.glyph_data = glyph_data
}

///|
fn SkippingIterator::advance_glyph_data(self : SkippingIterator) -> Unit {
  self.glyph_data = (self.glyph_data + 1) & 0xFFFF
}

///|
fn SkippingIterator::set_lookup_props(
  self : SkippingIterator,
  lookup_props : UInt,
) -> Unit {
  self.lookup_props = lookup_props
}

///|
fn SkippingIterator::enable_matching(
  self : SkippingIterator,
  func : MatchFunc,
) -> Unit {
  self.matching = Some(func)
}

///|
fn SkippingIterator::index(self : SkippingIterator) -> Int {
  self.buf_idx
}

///|
fn SkippingIterator::next(
  self : SkippingIterator,
  unsafe_to : Ref[Int]?,
) -> Bool {
  let stop = self.buf_len - 1
  while self.buf_idx < stop {
    self.buf_idx += 1
    let info = self.ctx.buffer.info[self.buf_idx]
    match self.match_(info) {
      Match => {
        self.advance_glyph_data()
        return true
      }
      NotMatch => {
        if unsafe_to is Some(unsafe_to) {
          unsafe_to.val = self.buf_idx + 1
        }
        return false
      }
      Skip => continue
    }
  }
  if unsafe_to is Some(unsafe_to) {
    unsafe_to.val = self.buf_idx + 1
  }
  false
}

///|
fn SkippingIterator::prev(
  self : SkippingIterator,
  unsafe_from : Ref[Int]?,
) -> Bool {
  let stop = 0
  while self.buf_idx > stop {
    self.buf_idx -= 1
    let info = self.ctx.buffer.out_info()[self.buf_idx]
    match self.match_(info) {
      Match => {
        self.advance_glyph_data()
        return true
      }
      NotMatch => {
        if unsafe_from is Some(unsafe_from) {
          unsafe_from.val = imax(self.buf_idx, 1) - 1
        }
        return false
      }
      Skip => continue
    }
  }
  if unsafe_from is Some(unsafe_from) {
    unsafe_from.val = 0
  }
  false
}

///|
fn SkippingIterator::match_(
  self : SkippingIterator,
  info : GlyphInfo,
) -> MatchT {
  let skip = self.may_skip(info)
  if skip == SkipYes {
    return Skip
  }
  let match_ = self.may_match(info)
  if match_ == MatchYes || (match_ == MatchMaybe && skip == SkipNo) {
    return Match
  }
  if skip == SkipNo {
    return NotMatch
  }
  Skip
}

///|
fn SkippingIterator::may_match(
  self : SkippingIterator,
  info : GlyphInfo,
) -> MayMatchT {
  if (info.mask & self.mask) == 0 ||
    (self.syllable != 0 && self.syllable != info.syllable()) {
    return MatchNo
  }
  if self.matching is Some(match_func) {
    return if match_func(info.as_glyph(), self.glyph_data) {
      MatchYes
    } else {
      MatchNo
    }
  }
  MatchMaybe
}

///|
fn SkippingIterator::may_skip(
  self : SkippingIterator,
  info : GlyphInfo,
) -> MaySkipT {
  if !self.ctx.check_glyph_property(info, self.lookup_props) {
    return SkipYes
  }
  if info.is_default_ignorable() &&
    (self.ignore_zwnj || !info.is_zwnj()) &&
    (self.ignore_zwj || !info.is_zwj()) &&
    (self.ignore_hidden || !info.is_hidden()) {
    return SkipMaybe
  }
  SkipNo
}

///|
priv struct WouldApplyContext {
  glyphs : Array[@otf.GlyphId]
  zero_context : Bool
}

///|
fn context_would_apply(
  this : @otf.ContextLookup,
  ctx : WouldApplyContext,
) -> Bool {
  let glyph = ctx.glyphs[0]
  match this {
    Format1(coverage~, sets~) =>
      match coverage.get(glyph) {
        Some(index) =>
          match sets.get(index) {
            Some(set) => sequence_rule_set_would_apply(set, ctx, match_glyph)
            None => false
          }
        None => false
      }
    Format2(classes~, sets~, ..) => {
      let class = classes.get(glyph)
      match sets.get(class) {
        Some(set) =>
          sequence_rule_set_would_apply(set, ctx, match_class(classes))
        None => false
      }
    }
    Format3(coverages~, ..) =>
      ctx.glyphs.length() == coverages.len().to_int() + 1 &&
      coverages
      .iter()
      .to_array()
      .mapi((i, coverage) => (i, coverage))
      .iter()
      .all(p => p.1.get(ctx.glyphs[p.0 + 1]) is Some(_))
  }
}

///|
fn context_apply(this : @otf.ContextLookup, ctx : ApplyContext) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  match this {
    Format1(coverage~, sets~) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      guard coverage.get(glyph) is Some(index) else { return None }
      guard sets.get(index) is Some(set) else { return None }
      sequence_rule_set_apply(set, ctx, match_glyph)
    }
    Format2(coverage~, classes~, sets~) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      let class = classes.get(glyph)
      guard sets.get(class) is Some(set) else { return None }
      sequence_rule_set_apply(set, ctx, match_class(classes))
    }
    Format3(coverage~, coverages~, lookups~) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      let coverages_len = coverages.len().to_int()
      let match_func = (glyph, index : Int) => {
        let coverage : @otf.Coverage = coverages.get(index.to_uint16()).unwrap()
        coverage.get(glyph) is Some(_)
      }
      let match_end = Ref(0)
      let match_positions = [0, 0, 0, 0]
      if match_input(
          ctx,
          coverages_len,
          match_func,
          match_end,
          match_positions,
          None,
        ) {
        ctx.buffer.unsafe_to_break(Some(ctx.buffer.idx), Some(match_end.val))
        apply_lookup(
          ctx,
          coverages_len,
          match_positions,
          match_end.val,
          lookups,
        )
        Some(())
      } else {
        ctx.buffer.unsafe_to_concat(Some(ctx.buffer.idx), Some(match_end.val))
        None
      }
    }
  }
}

///|
fn sequence_rule_set_would_apply(
  this : @otf.SequenceRuleSet,
  ctx : WouldApplyContext,
  match_func : MatchFunc,
) -> Bool {
  this.iter().any(rule => sequence_rule_would_apply(rule, ctx, match_func))
}

///|
fn sequence_rule_set_apply(
  this : @otf.SequenceRuleSet,
  ctx : ApplyContext,
  match_func : MatchFunc,
) -> Unit? {
  if this
    .iter()
    .any(rule => sequence_rule_apply(rule, ctx, match_func) is Some(_)) {
    Some(())
  } else {
    None
  }
}

///|
fn sequence_rule_would_apply(
  this : @otf.SequenceRule,
  ctx : WouldApplyContext,
  match_func : MatchFunc,
) -> Bool {
  if ctx.glyphs.length() != this.input.len().to_int() + 1 {
    return false
  }
  let mut i = 0
  for value in this.input.iter() {
    if !match_func(ctx.glyphs[i + 1], value.to_int()) {
      return false
    }
    i += 1
  }
  true
}

///|
fn sequence_rule_apply(
  this : @otf.SequenceRule,
  ctx : ApplyContext,
  match_func : MatchFunc,
) -> Unit? {
  apply_context(ctx, this.input, match_func, this.lookups)

  // TODO: Port optimized version from https://github.com/harfbuzz/harfbuzz/commit/645fabd10
}

///|
fn chained_context_would_apply(
  this : @otf.ChainedContextLookup,
  ctx : WouldApplyContext,
) -> Bool {
  let glyph_id = ctx.glyphs[0]
  match this {
    Format1(coverage~, sets~) =>
      match coverage.get(glyph_id) {
        Some(index) =>
          match sets.get(index) {
            Some(set) => chain_rule_set_would_apply(set, ctx, match_glyph)
            None => false
          }
        None => false
      }
    Format2(input_classes~, sets~, ..) => {
      let class = input_classes.get(glyph_id)
      match sets.get(class) {
        Some(set) =>
          chain_rule_set_would_apply(set, ctx, match_class(input_classes))
        None => false
      }
    }
    Format3(backtrack_coverages~, input_coverages~, lookahead_coverages~, ..) =>
      (
        !ctx.zero_context ||
        (backtrack_coverages.is_empty() && lookahead_coverages.is_empty())
      ) &&
      ctx.glyphs.length() == input_coverages.len().to_int() + 1 &&
      ({
        let mut all = true
        let mut i = 0
        for coverage in input_coverages.iter() {
          if !coverage.contains(ctx.glyphs[i + 1]) {
            all = false
            break
          }
          i += 1
        }
        all
      })
  }
}

///|
fn chained_context_apply(
  this : @otf.ChainedContextLookup,
  ctx : ApplyContext,
) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  match this {
    Format1(coverage~, sets~) => {
      guard coverage.get(glyph) is Some(index) else { return None }
      guard sets.get(index) is Some(set) else { return None }
      chain_rule_set_apply(set, ctx, [match_glyph, match_glyph, match_glyph])
    }
    Format2(
      coverage~,
      backtrack_classes~,
      input_classes~,
      lookahead_classes~,
      sets~
    ) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      let class = input_classes.get(glyph)
      guard sets.get(class) is Some(set) else { return None }
      chain_rule_set_apply(set, ctx, [
        match_class(backtrack_classes),
        match_class(input_classes),
        match_class(lookahead_classes),
      ])
    }
    Format3(
      coverage~,
      backtrack_coverages~,
      input_coverages~,
      lookahead_coverages~,
      lookups~
    ) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      let back = (glyph, index : Int) => {
        let coverage : @otf.Coverage = backtrack_coverages
          .get(index.to_uint16())
          .unwrap()
        coverage.contains(glyph)
      }
      let ahead = (glyph, index : Int) => {
        let coverage : @otf.Coverage = lookahead_coverages
          .get(index.to_uint16())
          .unwrap()
        coverage.contains(glyph)
      }
      let input = (glyph, index : Int) => {
        let coverage : @otf.Coverage = input_coverages
          .get(index.to_uint16())
          .unwrap()
        coverage.contains(glyph)
      }
      let end_index = Ref(ctx.buffer.idx)
      let match_end = Ref(0)
      let match_positions = [0, 0, 0, 0]
      let input_matches = match_input(
        ctx,
        input_coverages.len().to_int(),
        input,
        match_end,
        match_positions,
        None,
      )
      if input_matches {
        end_index.val = match_end.val
      }
      if !(input_matches &&
        match_lookahead(
          ctx,
          lookahead_coverages.len().to_int(),
          ahead,
          match_end.val,
          end_index,
        )) {
        ctx.buffer.unsafe_to_concat(Some(ctx.buffer.idx), Some(end_index.val))
        return None
      }
      let start_index = Ref(ctx.buffer.out_len)
      if !match_backtrack(
          ctx,
          backtrack_coverages.len().to_int(),
          back,
          start_index,
        ) {
        ctx.buffer.unsafe_to_concat_from_outbuffer(
          Some(start_index.val),
          Some(end_index.val),
        )
        return None
      }
      ctx.buffer.unsafe_to_break_from_outbuffer(
        Some(start_index.val),
        Some(end_index.val),
      )
      apply_lookup(
        ctx,
        input_coverages.len().to_int(),
        match_positions,
        match_end.val,
        lookups,
      )
      Some(())
    }
  }
}

///|
fn chain_rule_set_would_apply(
  this : @otf.ChainedSequenceRuleSet,
  ctx : WouldApplyContext,
  match_func : MatchFunc,
) -> Bool {
  this.iter().any(rule => chain_rule_would_apply(rule, ctx, match_func))
}

///|
fn chain_rule_set_apply(
  this : @otf.ChainedSequenceRuleSet,
  ctx : ApplyContext,
  match_funcs : Array[MatchFunc],
) -> Unit? {
  if this
    .iter()
    .any(rule => chain_rule_apply(rule, ctx, match_funcs) is Some(_)) {
    Some(())
  } else {
    None
  }

  // TODO: Port optimized version from https://github.com/harfbuzz/harfbuzz/commit/77080f86f
}

///|
fn chain_rule_would_apply(
  this : @otf.ChainedSequenceRule,
  ctx : WouldApplyContext,
  match_func : MatchFunc,
) -> Bool {
  if !(!ctx.zero_context ||
    (this.backtrack.is_empty() && this.lookahead.is_empty())) {
    return false
  }
  if ctx.glyphs.length() != this.input.len().to_int() + 1 {
    return false
  }
  let mut i = 0
  for value in this.input.iter() {
    if !match_func(ctx.glyphs[i + 1], value.to_int()) {
      return false
    }
    i += 1
  }
  true
}

///|
fn chain_rule_apply(
  this : @otf.ChainedSequenceRule,
  ctx : ApplyContext,
  match_funcs : Array[MatchFunc],
) -> Unit? {
  apply_chain_context(
    ctx,
    this.backtrack,
    this.input,
    this.lookahead,
    match_funcs,
    this.lookups,
  )
}

///|
fn apply_context(
  ctx : ApplyContext,
  input : @otf.LazyArray16[UInt16],
  match_func : MatchFunc,
  lookups : @otf.LazyArray16[@otf.SequenceLookupRecord],
) -> Unit? {
  let match_func = (glyph, index : Int) => {
    let value = input.get(index.to_uint16()).unwrap()
    match_func(glyph, value.to_int())
  }
  let match_end = Ref(0)
  let match_positions = [0, 0, 0, 0]
  if match_input(
      ctx,
      input.len().to_int(),
      match_func,
      match_end,
      match_positions,
      None,
    ) {
    ctx.buffer.unsafe_to_break(Some(ctx.buffer.idx), Some(match_end.val))
    apply_lookup(
      ctx,
      input.len().to_int(),
      match_positions,
      match_end.val,
      lookups,
    )
    return Some(())
  }
  None
}

///|
fn apply_chain_context(
  ctx : ApplyContext,
  backtrack : @otf.LazyArray16[UInt16],
  input : @otf.LazyArray16[UInt16],
  lookahead : @otf.LazyArray16[UInt16],
  match_funcs : Array[MatchFunc],
  lookups : @otf.LazyArray16[@otf.SequenceLookupRecord],
) -> Unit? {
  // NOTE: Whenever something in this method changes, we also need to
  // change it in the `apply` implementation for ChainedContextLookup.
  let f1 = (glyph, index : Int) => {
    let value = backtrack.get(index.to_uint16()).unwrap()
    match_funcs[0](glyph, value.to_int())
  }
  let f2 = (glyph, index : Int) => {
    let value = lookahead.get(index.to_uint16()).unwrap()
    match_funcs[2](glyph, value.to_int())
  }
  let f3 = (glyph, index : Int) => {
    let value = input.get(index.to_uint16()).unwrap()
    match_funcs[1](glyph, value.to_int())
  }
  let end_index = Ref(ctx.buffer.idx)
  let match_end = Ref(0)
  let match_positions = [0, 0, 0, 0]
  let input_matches = match_input(
    ctx,
    input.len().to_int(),
    f3,
    match_end,
    match_positions,
    None,
  )
  if input_matches {
    end_index.val = match_end.val
  }
  if !(input_matches &&
    match_lookahead(ctx, lookahead.len().to_int(), f2, match_end.val, end_index)) {
    ctx.buffer.unsafe_to_concat(Some(ctx.buffer.idx), Some(end_index.val))
    return None
  }
  let start_index = Ref(ctx.buffer.out_len)
  if !match_backtrack(ctx, backtrack.len().to_int(), f1, start_index) {
    ctx.buffer.unsafe_to_concat_from_outbuffer(
      Some(start_index.val),
      Some(end_index.val),
    )
    return None
  }
  ctx.buffer.unsafe_to_break_from_outbuffer(
    Some(start_index.val),
    Some(end_index.val),
  )
  apply_lookup(
    ctx,
    input.len().to_int(),
    match_positions,
    match_end.val,
    lookups,
  )
  Some(())
}

///|
fn apply_lookup(
  ctx : ApplyContext,
  input_len : Int,
  match_positions : Array[Int],
  match_end : Int,
  lookups : @otf.LazyArray16[@otf.SequenceLookupRecord],
) -> Unit {
  let mut count = input_len + 1
  while count > match_positions.length() {
    match_positions.push(0)
  }

  // All positions are distance from beginning of *output* buffer.
  // Adjust.
  let mut end = {
    let backtrack_len = ctx.buffer.backtrack_len()
    let delta = backtrack_len - ctx.buffer.idx

    // Convert positions to new indexing.
    for j in 0..<count {
      match_positions[j] = match_positions[j] + delta
    }
    backtrack_len + match_end - ctx.buffer.idx
  }
  for record in lookups.iter() {
    if !ctx.buffer.successful {
      break
    }
    let idx = record.sequence_index.to_int()
    if idx >= count {
      continue
    }
    let orig_len = ctx.buffer.backtrack_len() + ctx.buffer.lookahead_len()

    // This can happen if earlier recursed lookups deleted many entries.
    if match_positions[idx] >= orig_len {
      continue
    }
    if !ctx.buffer.move_to(match_positions[idx]) {
      break
    }
    if ctx.buffer.max_ops <= 0 {
      break
    }
    if ctx.recurse(record.lookup_list_index.to_int()) is None {
      continue
    }
    let new_len = ctx.buffer.backtrack_len() + ctx.buffer.lookahead_len()
    let mut delta = new_len - orig_len
    if delta == 0 {
      continue
    }

    // Recursed lookup changed buffer len.  Adjust.
    //
    // TODO:
    //
    // Right now, if buffer length increased by n, we assume n new glyphs
    // were added right after the current position, and if buffer length
    // was decreased by n, we assume n match positions after the current
    // one where removed.  The former (buffer length increased) case is
    // fine, but the decrease case can be improved in at least two ways,
    // both of which are significant:
    //
    //   - If recursed-to lookup is MultipleSubst and buffer length
    //     decreased, then it's current match position that was deleted,
    //     NOT the one after it.
    //
    //   - If buffer length was decreased by n, it does not necessarily
    //     mean that n match positions where removed, as there recursed-to
    //     lookup might had a different LookupFlag.  Here's a constructed
    //     case of that:
    //     https://github.com/harfbuzz/harfbuzz/discussions/3538
    //
    // It should be possible to construct tests for both of these cases.

    end += delta
    if end < match_positions[idx] {
      // End might end up being smaller than match_positions[idx] if the recursed
      // lookup ended up removing many items.
      // Just never rewind end beyond start of current position, since that is
      // not possible in the recursed lookup.  Also adjust delta as such.
      //
      // https://bugs.chromium.org/p/chromium/issues/detail?id=659496
      // https://github.com/harfbuzz/harfbuzz/issues/1611
      //
      delta += match_positions[idx] - end
      end = match_positions[idx]
    }

    // next now is the position after the recursed lookup.
    let mut next = idx + 1
    if delta > 0 {
      if delta + count > MAX_CONTEXT_LENGTH {
        break
      }
      if delta + count > match_positions.length() {
        let inner_max = Float::from_int(imax(4, match_positions.length())) * 1.5
        let inner_max = inner_max.to_int()
        let new_len = imax(delta + count, inner_max)
        while match_positions.length() < new_len {
          match_positions.push(0)
        }
      }
    } else {
      // NOTE: delta is non-positive.
      delta = imax(delta, next - count)
      next = next - delta
    }

    // Shift!
    // copy_within(next..count, next + delta)
    let moved = match_positions[next:count].to_owned()
    for k, v in moved {
      match_positions[next + delta + k] = v
    }
    next = next + delta
    count = count + delta

    // Fill in new entries.
    for j in (idx + 1)..<next {
      match_positions[j] = match_positions[j - 1] + 1
    }

    // And fixup the rest.
    while next < count {
      match_positions[next] = match_positions[next] + delta
      next += 1
    }
  }
  ctx.buffer.move_to(end) |> ignore
}

///|
/// The OpenType apply context (`OT::hb_ot_apply_context_t`).
priv struct ApplyContext {
  table_index : TableIndex
  face : Face
  buffer : Buffer
  mut lookup_mask_ : UInt
  mut per_syllable : Bool
  mut lookup_index : Int
  mut lookup_props : UInt
  mut nesting_level_left : Int
  mut auto_zwnj : Bool
  mut auto_zwj : Bool
  mut random : Bool
  mut random_state : UInt
  mut last_base : Int
  mut last_base_until : Int
  mut digest : SetDigest
}

///|
fn ApplyContext::new(
  table_index : TableIndex,
  face : Face,
  buffer : Buffer,
) -> ApplyContext {
  let buffer_digest = buffer.digest()
  {
    table_index,
    face,
    buffer,
    lookup_mask_: 1,
    per_syllable: false,
    lookup_index: 0xFFFF,
    lookup_props: 0,
    nesting_level_left: MAX_NESTING_LEVEL,
    auto_zwnj: true,
    auto_zwj: true,
    random: false,
    random_state: 1,
    last_base: -1,
    last_base_until: 0,
    digest: buffer_digest,
  }
}

///|
fn ApplyContext::random_number(self : ApplyContext) -> UInt {
  // http://www.cplusplus.com/reference/random/minstd_rand/
  self.random_state = self.random_state * 48271 % 2147483647
  self.random_state
}

///|
fn ApplyContext::set_lookup_mask(self : ApplyContext, mask : UInt) -> Unit {
  self.lookup_mask_ = mask
  self.last_base = -1
  self.last_base_until = 0
}

///|
fn ApplyContext::lookup_mask(self : ApplyContext) -> UInt {
  self.lookup_mask_
}

///|
fn ApplyContext::recurse(self : ApplyContext, sub_lookup_index : Int) -> Unit? {
  if self.nesting_level_left == 0 {
    self.buffer.shaping_failed = true
    return None
  }
  self.buffer.max_ops -= 1
  if self.buffer.max_ops < 0 {
    self.buffer.shaping_failed = true
    return None
  }
  self.nesting_level_left -= 1
  let saved_props = self.lookup_props
  let saved_index = self.lookup_index
  self.lookup_index = sub_lookup_index
  let applied = match self.table_index {
    GSUB =>
      match self.face.gsub {
        Some(table) if sub_lookup_index < table.lookups.length() => {
          let lookup = table.lookups[sub_lookup_index]
          self.lookup_props = LayoutLookup::props(lookup)
          LayoutLookup::apply(lookup, self)
        }
        _ => None
      }
    GPOS =>
      match self.face.gpos {
        Some(table) if sub_lookup_index < table.lookups.length() => {
          let lookup = table.lookups[sub_lookup_index]
          self.lookup_props = LayoutLookup::props(lookup)
          LayoutLookup::apply(lookup, self)
        }
        _ => None
      }
  }
  self.lookup_props = saved_props
  self.lookup_index = saved_index
  self.nesting_level_left += 1
  applied
}

///|
fn ApplyContext::check_glyph_property(
  self : ApplyContext,
  info : GlyphInfo,
  match_props : UInt,
) -> Bool {
  let glyph_props = info.glyph_props()

  // Lookup flags are lower 16-bit of match props.
  let lookup_flags = (match_props & 0xFFFF).reinterpret_as_int()

  // Not covered, if, for example, glyph class is ligature and
  // match_props includes LookupFlags::IgnoreLigatures
  if (glyph_props & lookup_flags & LOOKUP_FLAG_IGNORE_FLAGS) != 0 {
    return false
  }
  if (glyph_props & GLYPH_PROPS_MARK) != 0 {
    // If using mark filtering sets, the high short of
    // match_props has the set index.
    if (lookup_flags & LOOKUP_FLAG_USE_MARK_FILTERING_SET) != 0 {
      let set_index = (match_props >> 16).to_uint16()
      // TODO: harfbuzz uses a digest here to speed things up if HB_NO_GDEF_CACHE
      // is enabled. But a bit harder to implement for us since it's taken care of by
      // ttf-parser
      if self.face.tables().gdef is Some(table) {
        return table.is_mark_glyph(info.as_glyph(), Some(set_index))
      } else {
        return false
      }
    }

    // The second byte of match_props has the meaning
    // "ignore marks of attachment type different than
    // the attachment type specified."
    if (lookup_flags & LOOKUP_FLAG_MARK_ATTACHMENT_TYPE_MASK) != 0 {
      return (lookup_flags & LOOKUP_FLAG_MARK_ATTACHMENT_TYPE_MASK) ==
        (glyph_props & LOOKUP_FLAG_MARK_ATTACHMENT_TYPE_MASK)
    }
  }
  true
}

///|
fn ApplyContext::set_glyph_class(
  self : ApplyContext,
  glyph_id : @otf.GlyphId,
  class_guess : Int,
  ligature : Bool,
  component : Bool,
) -> Unit {
  self.digest.add(glyph_id.0.to_int())
  let cur = self.buffer.cur(0)
  let mut props = cur.glyph_props()
  props = props | GLYPH_PROPS_SUBSTITUTED
  if ligature {
    props = props | GLYPH_PROPS_LIGATED
    // In the only place that the MULTIPLIED bit is used, Uniscribe
    // seems to only care about the "last" transformation between
    // Ligature and Multiple substitutions.  Ie. if you ligate, expand,
    // and ligate again, it forgives the multiplication and acts as
    // if only ligation happened.  As such, clear MULTIPLIED bit.
    props = props & GLYPH_PROPS_MULTIPLIED.lnot()
  }
  if component {
    props = props | GLYPH_PROPS_MULTIPLIED
  }
  let has_glyph_classes = match self.face.tables().gdef {
    Some(table) => table.has_glyph_classes()
    None => false
  }
  if has_glyph_classes {
    props = props & GLYPH_PROPS_PRESERVE
    cur.set_glyph_props(props | self.face.glyph_props(glyph_id))
  } else if class_guess != 0 {
    props = props & GLYPH_PROPS_PRESERVE
    cur.set_glyph_props(props | class_guess)
  } else {
    cur.set_glyph_props(props)
  }
}

///|
fn ApplyContext::replace_glyph(
  self : ApplyContext,
  glyph_id : @otf.GlyphId,
) -> Unit {
  self.set_glyph_class(glyph_id, 0, false, false)
  self.buffer.replace_glyph(glyph_id.0.to_uint())
}

///|
fn ApplyContext::replace_glyph_inplace(
  self : ApplyContext,
  glyph_id : @otf.GlyphId,
) -> Unit {
  self.set_glyph_class(glyph_id, 0, false, false)
  self.buffer.cur(0).glyph_id = glyph_id.0.to_uint()
}

///|
fn ApplyContext::replace_glyph_with_ligature(
  self : ApplyContext,
  glyph_id : @otf.GlyphId,
  class_guess : Int,
) -> Unit {
  self.set_glyph_class(glyph_id, class_guess, true, false)
  self.buffer.replace_glyph(glyph_id.0.to_uint())
}

///|
fn ApplyContext::output_glyph_for_component(
  self : ApplyContext,
  glyph_id : @otf.GlyphId,
  class_guess : Int,
) -> Unit {
  self.set_glyph_class(glyph_id, class_guess, false, true)
  self.buffer.output_glyph(glyph_id.0.to_uint())
}

///|
fn ligate_input(
  ctx : ApplyContext,
  // Including the first glyph
  count : Int,
  // Including the first glyph
  match_positions : Array[Int],
  match_end : Int,
  total_component_count : Int,
  lig_glyph : @otf.GlyphId,
) -> Unit {
  // - If a base and one or more marks ligate, consider that as a base, NOT
  //   ligature, such that all following marks can still attach to it.
  //   https://github.com/harfbuzz/harfbuzz/issues/1109
  //
  // - If all components of the ligature were marks, we call this a mark ligature.
  //   If it *is* a mark ligature, we don't allocate a new ligature id, and leave
  //   the ligature to keep its old ligature id.  This will allow it to attach to
  //   a base ligature in GPOS.  Eg. if the sequence is: LAM,LAM,SHADDA,FATHA,HEH,
  //   and LAM,LAM,HEH for a ligature, they will leave SHADDA and FATHA with a
  //   ligature id and component value of 2.  Then if SHADDA,FATHA form a ligature
  //   later, we don't want them to lose their ligature id/component, otherwise
  //   GPOS will fail to correctly position the mark ligature on top of the
  //   LAM,LAM,HEH ligature.  See:
  //     https://bugzilla.gnome.org/show_bug.cgi?id=676343
  //
  // - If a ligature is formed of components that some of which are also ligatures
  //   themselves, and those ligature components had marks attached to *their*
  //   components, we have to attach the marks to the new ligature component
  //   positions!  Now *that*'s tricky!  And these marks may be following the
  //   last component of the whole sequence, so we should loop forward looking
  //   for them and update them.
  //
  //   Eg. the sequence is LAM,LAM,SHADDA,FATHA,HEH, and the font first forms a
  //   'calt' ligature of LAM,HEH, leaving the SHADDA and FATHA with a ligature
  //   id and component == 1.  Now, during 'liga', the LAM and the LAM-HEH ligature
  //   form a LAM-LAM-HEH ligature.  We need to reassign the SHADDA and FATHA to
  //   the new ligature with a component value of 2.
  //
  //   This in fact happened to a font...  See:
  //   https://bugzilla.gnome.org/show_bug.cgi?id=437633
  //

  let buffer = ctx.buffer
  buffer.merge_clusters(buffer.idx, match_end)
  let mut is_base_ligature = buffer.info[match_positions[0]].is_base_glyph()
  let mut is_mark_ligature = buffer.info[match_positions[0]].is_mark()
  for i in 1..<count {
    if !buffer.info[match_positions[i]].is_mark() {
      is_base_ligature = false
      is_mark_ligature = false
    }
  }
  let is_ligature = !is_base_ligature && !is_mark_ligature
  let class = if is_ligature { GLYPH_PROPS_LIGATURE } else { 0 }
  let lig_id = if is_ligature { buffer.allocate_lig_id() } else { 0 }
  let first = buffer.cur(0)
  let mut last_lig_id = first.get_lig_id()
  let mut last_num_comps = first.get_lig_num_comps()
  let mut comps_so_far = last_num_comps
  if is_ligature {
    first.set_lig_props_for_ligature(lig_id, total_component_count)
    if first.get_general_category() == GC_NON_SPACING_MARK {
      first.set_general_category(GC_OTHER_LETTER)
    }
  }
  ctx.replace_glyph_with_ligature(lig_glyph, class)
  for i in 1..<count {
    while buffer.idx < match_positions[i] && buffer.successful {
      if is_ligature {
        let cur = buffer.cur(0)
        let mut this_comp = cur.get_lig_comp()
        if this_comp == 0 {
          this_comp = last_num_comps
        }
        // Avoid the potential for a wrap-around bug when subtracting from an unsigned integer
        // c.f. https://github.com/harfbuzz/rustybuzz/issues/142
        guard! comps_so_far >= last_num_comps
        let new_lig_comp = (
            comps_so_far - last_num_comps + imin(this_comp, last_num_comps)
          ) &
          0xFF
        cur.set_lig_props_for_mark(lig_id, new_lig_comp)
      }
      buffer.next_glyph()
    }
    let cur = buffer.cur(0)
    last_lig_id = cur.get_lig_id()
    last_num_comps = cur.get_lig_num_comps()
    comps_so_far = (comps_so_far + last_num_comps) & 0xFF

    // Skip the base glyph.
    buffer.idx += 1
  }
  if !is_mark_ligature && last_lig_id != 0 {
    // Re-adjust components for any marks following.
    for i in buffer.idx..<buffer.len {
      let info = buffer.info[i]
      if last_lig_id != info.get_lig_id() {
        break
      }
      let this_comp = info.get_lig_comp()
      if this_comp == 0 {
        break
      }

      // Avoid the potential for a wrap-around bug when subtracting from an unsigned integer
      // c.f. https://github.com/harfbuzz/rustybuzz/issues/142
      guard! comps_so_far >= last_num_comps
      let new_lig_comp = (
          comps_so_far - last_num_comps + imin(this_comp, last_num_comps)
        ) &
        0xFF
      info.set_lig_props_for_mark(lig_id, new_lig_comp)
    }
  }
}
