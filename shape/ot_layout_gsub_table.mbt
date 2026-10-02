// Port of rustybuzz 0.20.1 `src/hb/ot_layout_gsub_table.rs` and
// `src/hb/ot/layout/GSUB/*.rs` (substitution lookups).

///|
fn substitute(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit {
  apply_layout_table(
    plan,
    face,
    buffer,
    GSUB,
    false,
    face.gsub.map(t => t.lookups),
  )
}

// subst_lookup.rs

///|
impl LayoutLookup for SubstLookup with fn props(self) {
  self.props
}

///|
impl LayoutLookup for SubstLookup with fn is_reverse(self) {
  self.reverse
}

///|
impl LayoutLookup for SubstLookup with fn digest(self) {
  self.set_digest
}

///|
impl LayoutLookup for SubstLookup with fn apply(self, ctx) {
  if self.set_digest.may_have_glyph(ctx.buffer.cur(0).as_glyph().0.to_int()) {
    for subtable in self.subtables {
      if subst_subtable_apply(subtable, ctx) is Some(_) {
        return Some(())
      }
    }
  }
  None
}

///|
fn SubstLookup::would_apply(
  self : SubstLookup,
  ctx : WouldApplyContext,
) -> Bool {
  self.set_digest.may_have_glyph(ctx.glyphs[0].0.to_int()) &&
  self.subtables
  .iter()
  .any(subtable => subst_subtable_would_apply(subtable, ctx))
}

// subst_lookup_subtable.rs

///|
fn subst_subtable_would_apply(
  this : @otf.SubstitutionSubtable,
  ctx : WouldApplyContext,
) -> Bool {
  match this {
    Single(t) => single_subst_would_apply(t, ctx)
    Multiple(t) => multi_subst_would_apply(t, ctx)
    Alternate(t) => alternate_subst_would_apply(t, ctx)
    Ligature(t) => ligature_subst_would_apply(t, ctx)
    Context(t) => context_would_apply(t, ctx)
    ChainContext(t) => chained_context_would_apply(t, ctx)
    ReverseChainSingle(t) => reverse_chain_single_subst_would_apply(t, ctx)
  }
}

///|
fn subst_subtable_apply(
  this : @otf.SubstitutionSubtable,
  ctx : ApplyContext,
) -> Unit? {
  match this {
    Single(t) => single_subst_apply(t, ctx)
    Multiple(t) => multi_subst_apply(t, ctx)
    Alternate(t) => alternate_subst_apply(t, ctx)
    Ligature(t) => ligature_subst_apply(t, ctx)
    Context(t) => context_apply(t, ctx)
    ChainContext(t) => chained_context_apply(t, ctx)
    ReverseChainSingle(t) => reverse_chain_single_subst_apply(t, ctx)
  }
}

// single_subst.rs

///|
/// SingleSubstFormat1::would_apply, SingleSubstFormat2::would_apply
fn single_subst_would_apply(
  this : @otf.SingleSubstitution,
  ctx : WouldApplyContext,
) -> Bool {
  ctx.glyphs.length() == 1 && this.coverage().get(ctx.glyphs[0]) is Some(_)
}

///|
/// SingleSubstFormat1::apply, SingleSubstFormat2::apply
fn single_subst_apply(
  this : @otf.SingleSubstitution,
  ctx : ApplyContext,
) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  let subst = match this {
    Format1(coverage~, delta~) => {
      guard coverage.get(glyph) is Some(_) else { return None }
      // According to the Adobe Annotated OpenType Suite, result is always
      // limited to 16bit, so we explicitly want to truncate.
      @otf.GlyphId(((glyph.0.to_int() + delta.to_int()) & 0xFFFF).to_uint16())
    }
    Format2(coverage~, substitutes~) => {
      guard coverage.get(glyph) is Some(index) else { return None }
      guard substitutes.get(index) is Some(v) else { return None }
      v
    }
  }
  ctx.replace_glyph(subst)
  Some(())
}

// multi_subst.rs

///|
/// MultipleSubstFormat1::would_apply
fn multi_subst_would_apply(
  this : @otf.MultipleSubstitution,
  ctx : WouldApplyContext,
) -> Bool {
  ctx.glyphs.length() == 1 && this.coverage.get(ctx.glyphs[0]) is Some(_)
}

///|
/// MultipleSubstFormat1::apply
fn multi_subst_apply(
  this : @otf.MultipleSubstitution,
  ctx : ApplyContext,
) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  guard this.coverage.get(glyph) is Some(index) else { return None }
  guard (this.sequences.get(index) : @otf.Sequence?) is Some(seq) else {
    return None
  }
  sequence_apply(seq, ctx)
}

// sequence.rs

///|
fn sequence_apply(this : @otf.Sequence, ctx : ApplyContext) -> Unit? {
  match this.substitutes.len().to_int() {
    // Spec disallows this, but Uniscribe allows it.
    // https://github.com/harfbuzz/harfbuzz/issues/253
    0 => ctx.buffer.delete_glyph()

    // Special-case to make it in-place and not consider this
    // as a "multiplied" substitution.
    1 => {
      guard this.substitutes.get(0) is Some(g) else { return None }
      ctx.replace_glyph(g)
    }
    _ => {
      let class = if ctx.buffer.cur(0).is_ligature() {
        GLYPH_PROPS_BASE_GLYPH
      } else {
        0
      }
      let lig_id = ctx.buffer.cur(0).get_lig_id()
      for i, subst in this.substitutes.iter().to_array() {
        // If is attached to a ligature, don't disturb that.
        // https://github.com/harfbuzz/harfbuzz/issues/3069
        if lig_id == 0 {
          // Index is truncated to 4 bits anway, so we can safely cast to u8.
          ctx.buffer.cur(0).set_lig_props_for_component(i & 0xFF)
        }
        ctx.output_glyph_for_component(subst, class)
      }
      ctx.buffer.skip_glyph()
    }
  }
  Some(())
}

// alternate_subst.rs

///|
/// AlternateSubstFormat1::would_apply
fn alternate_subst_would_apply(
  this : @otf.AlternateSubstitution,
  ctx : WouldApplyContext,
) -> Bool {
  ctx.glyphs.length() == 1 && this.coverage.get(ctx.glyphs[0]) is Some(_)
}

///|
/// AlternateSubstFormat1::apply
fn alternate_subst_apply(
  this : @otf.AlternateSubstitution,
  ctx : ApplyContext,
) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  guard this.coverage.get(glyph) is Some(index) else { return None }
  guard (this.alternate_sets.get(index) : @otf.AlternateSet?) is Some(set) else {
    return None
  }
  alternate_set_apply(set, ctx)
}

// alternate_set.rs

///|
fn alternate_set_apply(this : @otf.AlternateSet, ctx : ApplyContext) -> Unit? {
  let len = this.alternates.len().to_uint()
  if len == 0 {
    return None
  }
  let glyph_mask = ctx.buffer.cur(0).mask

  // Note: This breaks badly if two features enabled this lookup together.
  let shift = ctx.lookup_mask().ctz()
  let mut alt_index = (ctx.lookup_mask() & glyph_mask) >> shift

  // If alt_index is MAX_VALUE, randomize feature if it is the rand feature.
  if alt_index == MAX_VALUE && ctx.random {
    // Maybe we can do better than unsafe-to-break all; but since we are
    // changing random state, it would be hard to track that.  Good 'nough.
    ctx.buffer.unsafe_to_break(Some(0), Some(ctx.buffer.len))
    alt_index = ctx.random_number() % len + 1
  }
  guard alt_index <= 0xFFFF && alt_index >= 1 else { return None }
  let idx = (alt_index - 1).to_uint16()
  guard this.alternates.get(idx) is Some(g) else { return None }
  ctx.replace_glyph(g)
  Some(())
}

// ligature_subst.rs

///|
/// LigatureSubstFormat1::would_apply
fn ligature_subst_would_apply(
  this : @otf.LigatureSubstitution,
  ctx : WouldApplyContext,
) -> Bool {
  match this.coverage.get(ctx.glyphs[0]) {
    Some(index) =>
      match this.ligature_sets.get(index) {
        Some(set) => ligature_set_would_apply(set, ctx)
        None => false
      }
    None => false
  }
}

///|
/// LigatureSubstFormat1::apply
fn ligature_subst_apply(
  this : @otf.LigatureSubstitution,
  ctx : ApplyContext,
) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  guard this.coverage.get(glyph) is Some(index) else { return None }
  guard (this.ligature_sets.get(index) : @otf.LigatureSet?) is Some(set) else {
    return None
  }
  ligature_set_apply(set, ctx)
}

// ligature_set.rs

///|
fn ligature_set_would_apply(
  this : @otf.LigatureSet,
  ctx : WouldApplyContext,
) -> Bool {
  this.iter().any(lig => ligature_would_apply(lig, ctx))
}

///|
fn ligature_set_apply(this : @otf.LigatureSet, ctx : ApplyContext) -> Unit? {
  for lig in this.iter() {
    if ligature_apply(lig, ctx) is Some(_) {
      return Some(())
    }
  }
  None

  // TODO: port https://github.com/harfbuzz/harfbuzz/commit/7881eadff and
  // the following commits. Since it's behind a feature flag, we ignore it
  // for now and just use the simpler version.
}

// ligature.rs

///|
fn ligature_would_apply(this : @otf.Ligature, ctx : WouldApplyContext) -> Bool {
  if ctx.glyphs.length() != this.components.len().to_int() + 1 {
    return false
  }
  let mut i = 0
  for comp in this.components.iter() {
    if ctx.glyphs[i + 1] != comp {
      return false
    }
    i += 1
  }
  true
}

///|
fn ligature_apply(this : @otf.Ligature, ctx : ApplyContext) -> Unit? {
  // Special-case to make it in-place and not consider this
  // as a "ligated" substitution.
  if this.components.is_empty() {
    ctx.replace_glyph(this.glyph)
    Some(())
  } else {
    let f = (glyph, index : Int) => {
      let value = this.components.get(index.to_uint16()).unwrap()
      match_glyph(glyph, value.0.to_int())
    }
    let match_end = Ref(0)
    let match_positions = [0, 0, 0, 0]
    let total_component_count = Ref(0)
    if !match_input(
        ctx,
        this.components.len().to_int(),
        f,
        match_end,
        match_positions,
        Some(total_component_count),
      ) {
      ctx.buffer.unsafe_to_concat(Some(ctx.buffer.idx), Some(match_end.val))
      return None
    }
    let count = this.components.len().to_int() + 1
    ligate_input(
      ctx,
      count,
      match_positions,
      match_end.val,
      total_component_count.val,
      this.glyph,
    )
    Some(())
  }
}

// reverse_chain_single_subst.rs

///|
/// ReverseChainSingleSubstFormat1::would_apply
fn reverse_chain_single_subst_would_apply(
  this : @otf.ReverseChainSingleSubstitution,
  ctx : WouldApplyContext,
) -> Bool {
  ctx.glyphs.length() == 1 && this.coverage.get(ctx.glyphs[0]) is Some(_)
}

///|
/// ReverseChainSingleSubstFormat1::apply
fn reverse_chain_single_subst_apply(
  this : @otf.ReverseChainSingleSubstitution,
  ctx : ApplyContext,
) -> Unit? {
  let glyph = ctx.buffer.cur(0).as_glyph()
  guard this.coverage.get(glyph) is Some(index) else { return None }
  if index >= this.substitutes.len() {
    return None
  }

  // No chaining to this type.
  if ctx.nesting_level_left != MAX_NESTING_LEVEL {
    return None
  }
  guard this.substitutes.get(index) is Some(subst) else { return None }
  let f1 = (glyph, index : Int) => {
    let value : @otf.Coverage = this.backtrack_coverages
      .get(index.to_uint16())
      .unwrap()
    value.contains(glyph)
  }
  let f2 = (glyph, index : Int) => {
    let value : @otf.Coverage = this.lookahead_coverages
      .get(index.to_uint16())
      .unwrap()
    value.contains(glyph)
  }
  let start_index = Ref(0)
  let end_index = Ref(0)
  if match_backtrack(
      ctx,
      this.backtrack_coverages.len().to_int(),
      f1,
      start_index,
    ) {
    if match_lookahead(
        ctx,
        this.lookahead_coverages.len().to_int(),
        f2,
        ctx.buffer.idx + 1,
        end_index,
      ) {
      ctx.buffer.unsafe_to_break_from_outbuffer(
        Some(start_index.val),
        Some(end_index.val),
      )
      ctx.replace_glyph_inplace(subst)

      // Note: We DON'T decrease buffer.idx.  The main loop does it
      // for us.  This is useful for preventing surprises if someone
      // calls us through a Context lookup.
      return Some(())
    }
  }
  ctx.buffer.unsafe_to_concat_from_outbuffer(
    Some(start_index.val),
    Some(end_index.val),
  )
  None
}
