// Port of rustybuzz 0.20.1 `src/hb/ot_layout.rs` (OpenType layout).
//
// The `_hb_glyph_info_*` helpers are methods of `GlyphInfo` named without
// the prefix (e.g. `_hb_glyph_info_is_mark` is `GlyphInfo::is_mark`).

///|
const MAX_NESTING_LEVEL : Int = 64

///|
const MAX_CONTEXT_LENGTH : Int = 64

///|
fn hb_ot_layout_has_kerning(face : Face) -> Bool {
  face.tables().kern is Some(_)
}

///|
fn hb_ot_layout_has_machine_kerning(face : Face) -> Bool {
  match face.tables().kern {
    Some(kern) => kern.subtables.iter().any(s => s.has_state_machine)
    None => false
  }
}

///|
fn hb_ot_layout_has_cross_kerning(face : Face) -> Bool {
  match face.tables().kern {
    Some(kern) => kern.subtables.iter().any(s => s.has_cross_stream)
    None => false
  }
}

// hb_ot_layout_kern

// OT::GDEF::is_blocklisted unsupported

///|
fn _hb_ot_layout_set_glyph_props(face : Face, buffer : Buffer) -> Unit {
  for i in 0..<buffer.len {
    let info = buffer.info[i]
    info.set_glyph_props(face.glyph_props(info.as_glyph()))
    info.set_lig_props(0)
  }
}

///|
fn hb_ot_layout_has_glyph_classes(face : Face) -> Bool {
  match face.tables().gdef {
    Some(table) => table.has_glyph_classes()
    None => false
  }
}

// get_gsubgpos_table

///|
priv enum TableIndex {
  GSUB
  GPOS
} derive(Eq)

///|
fn TableIndex::to_int(self : TableIndex) -> Int {
  match self {
    GSUB => 0
    GPOS => 1
  }
}

///|
/// A lookup in a layout table (`LayoutLookup`).
priv trait LayoutLookup {
  /// The lookup's lookup_props.
  fn props(Self) -> UInt
  /// Whether the lookup has to be applied backwards.
  fn is_reverse(Self) -> Bool
  /// The digest of the lookup.
  fn digest(Self) -> SetDigest
  /// Apply the lookup.
  fn apply(Self, ApplyContext) -> Unit?
}

// LayoutTableExt for ttf_parser::opentype_layout::LayoutTable

///|
/// hb_ot_layout_table_select_script
///
/// Returns true + index and tag of the first found script tag in the given
/// GSUB or GPOS table or false + index and tag if falling back to a default
/// script.
fn layout_select_script(
  this : @otf.LayoutTable,
  script_tags : Array[@otf.Tag],
) -> (Bool, Int, @otf.Tag)? {
  for tag in script_tags {
    if this.scripts.index(tag) is Some(index) {
      return Some((true, index.to_int(), tag))
    }
  }
  for
    tag in [
      // try finding 'DFLT'
      default_script_tag(),
      // try with 'dflt'; MS site has had typos and many fonts use it now :(
      default_language_tag(),
      // try with 'latn'; some old fonts put their features there even though
      // they're really trying to support Thai, for example :(
      @otf.Tag::from_bytes(b"latn"),
    ] {
    if this.scripts.index(tag) is Some(index) {
      return Some((false, index.to_int(), tag))
    }
  }
  None
}

///|
/// hb_ot_layout_script_select_language
///
/// Returns the index of the first found language tag in the given GSUB or
/// GPOS table, underneath the specified script index.
fn layout_select_script_language(
  this : @otf.LayoutTable,
  script_index : Int,
  lang_tags : Array[@otf.Tag],
) -> Int? {
  guard (this.scripts.get(script_index.to_uint16()) : @otf.Script?)
    is Some(script) else {
    return None
  }
  for tag in lang_tags {
    if script.languages.index(tag) is Some(index) {
      return Some(index.to_int())
    }
  }

  // try finding 'dflt'
  if script.languages.index(default_language_tag()) is Some(index) {
    return Some(index.to_int())
  }
  None
}

///|
fn layout_lang_sys(
  this : @otf.LayoutTable,
  script_index : Int,
  lang_index : Int?,
) -> @otf.LanguageSystem? {
  guard (this.scripts.get(script_index.to_uint16()) : @otf.Script?)
    is Some(script) else {
    return None
  }
  match lang_index {
    Some(index) => script.languages.get(index.to_uint16())
    None => script.default_language
  }
}

///|
/// hb_ot_layout_language_get_required_feature
///
/// Returns the index and tag of a required feature in the given GSUB or
/// GPOS table, underneath the specified script and language.
fn layout_get_required_language_feature(
  this : @otf.LayoutTable,
  script_index : Int,
  lang_index : Int?,
) -> (Int, @otf.Tag)? {
  guard layout_lang_sys(this, script_index, lang_index) is Some(sys) else {
    return None
  }
  guard sys.required_feature is Some(idx) else { return None }
  guard (this.features.get(idx) : @otf.Feature?) is Some(feature) else {
    return None
  }
  Some((idx.to_int(), feature.tag))
}

///|
/// hb_ot_layout_language_find_feature
///
/// Returns the index of a given feature tag in the given GSUB or GPOS table,
/// underneath the specified script and language.
fn layout_find_language_feature(
  this : @otf.LayoutTable,
  script_index : Int,
  lang_index : Int?,
  feature_tag : @otf.Tag,
) -> Int? {
  guard layout_lang_sys(this, script_index, lang_index) is Some(sys) else {
    return None
  }
  for i in 0..<sys.feature_indices.len().to_int() {
    if sys.feature_indices.get(i.to_uint16()) is Some(index) {
      let feature : @otf.Feature? = this.features.get(index)
      if feature.map(v => v.tag) == Some(feature_tag) {
        return Some(index.to_int())
      }
    }
  }
  None
}

///|
/// Called before substitution lookups are performed, to ensure that glyph
/// class and other properties are set on the glyphs in the buffer.
fn hb_ot_layout_substitute_start(face : Face, buffer : Buffer) -> Unit {
  _hb_ot_layout_set_glyph_props(face, buffer)
}

///|
/// Applies the lookups in the given GSUB or GPOS table.
fn[L : LayoutLookup] apply_layout_table(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
  table_index : TableIndex,
  in_place : Bool,
  table : Array[L]?,
) -> Unit {
  let ctx = ApplyContext::new(table_index, face, buffer)
  for stage_index, stage in plan.ot_map.stages(table_index) {
    if table is Some(table) {
      for lookup_map in plan.ot_map.stage_lookups(table_index, stage_index) {
        guard lookup_map.index < table.length() else { continue }
        let lookup = table[lookup_map.index]
        if lookup.digest().may_have(ctx.digest) {
          ctx.lookup_index = lookup_map.index
          ctx.set_lookup_mask(lookup_map.mask)
          ctx.auto_zwj = lookup_map.auto_zwj
          ctx.auto_zwnj = lookup_map.auto_zwnj
          ctx.random = lookup_map.random
          ctx.per_syllable = lookup_map.per_syllable
          apply_string(ctx, in_place, lookup)
        }
      }
    }
    if stage.pause_func is Some(func) {
      if func(plan, face, ctx.buffer) {
        ctx.digest = ctx.buffer.digest()
      }
    }
  }
}

///|
fn[L : LayoutLookup] apply_string(
  ctx : ApplyContext,
  in_place : Bool,
  lookup : L,
) -> Unit {
  if ctx.buffer.is_empty() || ctx.lookup_mask() == 0 {
    return
  }
  ctx.lookup_props = lookup.props()
  if !lookup.is_reverse() {
    // in/out forward substitution/positioning
    if !in_place {
      ctx.buffer.clear_output()
    }
    ctx.buffer.idx = 0
    apply_forward(ctx, lookup) |> ignore
    if !in_place {
      ctx.buffer.sync() |> ignore
    }
  } else {
    // in-place backward substitution/positioning
    guard! !ctx.buffer.have_output
    ctx.buffer.idx = ctx.buffer.len - 1
    apply_backward(ctx, lookup) |> ignore
  }
}

///|
fn[L : LayoutLookup] apply_forward(ctx : ApplyContext, lookup : L) -> Bool {
  let mut ret = false
  while ctx.buffer.idx < ctx.buffer.len && ctx.buffer.successful {
    let cur = ctx.buffer.cur(0)
    if (cur.mask & ctx.lookup_mask()) != 0 &&
      ctx.check_glyph_property(cur, ctx.lookup_props) &&
      lookup.apply(ctx) is Some(_) {
      ret = true
    } else {
      ctx.buffer.next_glyph()
    }
  }
  ret
}

///|
fn[L : LayoutLookup] apply_backward(ctx : ApplyContext, lookup : L) -> Bool {
  let mut ret = false
  while true {
    let cur = ctx.buffer.cur(0)
    // `ret |= ...` always evaluates the right-hand side.
    let applied = (cur.mask & ctx.lookup_mask()) != 0 &&
      ctx.check_glyph_property(cur, ctx.lookup_props) &&
      lookup.apply(ctx) is Some(_)
    ret = ret || applied
    if ctx.buffer.idx == 0 {
      break
    }
    ctx.buffer.idx -= 1
  }
  ret
}

// unicode_props
//
// Design:
// unicode_props() is a two-byte number.  The low byte includes:
// - Modified General_Category: 5 bits.
// - A bit each for:
//   * Is it Default_Ignorable(); we have a modified Default_Ignorable().
//   * Whether it's one of the four Mongolian Free Variation Selectors,
//     CGJ, or other characters that are hidden but should not be ignored
//     like most other Default_Ignorable()s do during GSUB matching.
//   * Whether it's a grapheme continuation.
//
// The high-byte has different meanings, switched by the Gen-Cat:
// - For Mn,Mc,Me: the modified Combining_Class.
// - For Cf: whether it's ZWJ, ZWNJ, or something else.
// - For Ws: index of which space character this is, if space fallback
//   is needed, ie. we don't set this by default, only if asked to.
//
// Above I said "modified" General_Category. This is because we need to
// remember Variation Selectors, and we don't have bits left. So we
// change their Gen_Cat from Mn to Cf, and use a bit of the high byte to
// remember them.

///|
fn GlyphInfo::set_general_category(self : GlyphInfo, gen_cat : Int) -> Unit {
  // Clears top-byte.
  let n = gen_cat | (self.unicode_props() & (0xFF & UPROPS_MASK_GEN_CAT.lnot()))
  self.set_unicode_props(n)
}

///|
fn GlyphInfo::get_general_category(self : GlyphInfo) -> Int {
  self.unicode_props() & UPROPS_MASK_GEN_CAT
}

///|
fn GlyphInfo::is_unicode_mark(self : GlyphInfo) -> Bool {
  gc_is_mark(self.get_general_category())
}

///|
fn GlyphInfo::set_modified_combining_class(
  self : GlyphInfo,
  modified_class : Int,
) -> Unit {
  if !self.is_unicode_mark() {
    return
  }
  let n = (modified_class << 8) | (self.unicode_props() & 0xFF)
  self.set_unicode_props(n)
}

///|
fn GlyphInfo::get_modified_combining_class(self : GlyphInfo) -> Int {
  if self.is_unicode_mark() {
    (self.unicode_props() >> 8) & 0xFF
  } else {
    0
  }
}

///|
fn GlyphInfo::is_unicode_space(self : GlyphInfo) -> Bool {
  self.get_general_category() == GC_SPACE_SEPARATOR
}

///|
fn GlyphInfo::set_unicode_space_fallback_type(
  self : GlyphInfo,
  s : Int,
) -> Unit {
  if !self.is_unicode_space() {
    return
  }
  let n = (s << 8) | (self.unicode_props() & 0xFF)
  self.set_unicode_props(n)
}

///|
fn GlyphInfo::get_unicode_space_fallback_type(self : GlyphInfo) -> Int {
  if self.is_unicode_space() {
    (self.unicode_props() >> 8) & 0xFF
  } else {
    NOT_SPACE
  }
}

///|
fn GlyphInfo::is_variation_selector(self : GlyphInfo) -> Bool {
  let a = self.get_general_category() == GC_FORMAT
  let b = (self.unicode_props() & UPROPS_MASK_CF_VS) != 0
  a && b
}

///|
fn GlyphInfo::set_variation_selector(
  self : GlyphInfo,
  customize : Bool,
) -> Unit {
  if customize {
    self.set_general_category(GC_FORMAT)
    self.set_unicode_props(self.unicode_props() | UPROPS_MASK_CF_VS)
  } else {
    // Reset to their original condition
    self.set_general_category(GC_NON_SPACING_MARK)
  }
}

///|
fn GlyphInfo::is_default_ignorable(self : GlyphInfo) -> Bool {
  let n = self.unicode_props() & UPROPS_MASK_IGNORABLE
  n != 0 && !self.substituted()
}

///|
fn GlyphInfo::clear_default_ignorable(self : GlyphInfo) -> Unit {
  let n = self.unicode_props()
  self.set_unicode_props(n & UPROPS_MASK_IGNORABLE.lnot())
}

///|
fn GlyphInfo::is_hidden(self : GlyphInfo) -> Bool {
  (self.unicode_props() & UPROPS_MASK_HIDDEN) != 0
}

///|
fn GlyphInfo::set_continuation(self : GlyphInfo) -> Unit {
  let n = self.unicode_props()
  self.set_unicode_props(n | UPROPS_MASK_CONTINUATION)
}

///|
fn GlyphInfo::reset_continuation(self : GlyphInfo) -> Unit {
  let n = self.unicode_props()
  self.set_unicode_props(n & UPROPS_MASK_CONTINUATION.lnot())
}

///|
fn GlyphInfo::is_continuation(self : GlyphInfo) -> Bool {
  (self.unicode_props() & UPROPS_MASK_CONTINUATION) != 0
}

///|
fn grapheme_group_func(_a : GlyphInfo, b : GlyphInfo) -> Bool {
  b.is_continuation()
}

///|
fn _hb_ot_layout_reverse_graphemes(buffer : Buffer) -> Unit {
  buffer.reverse_groups(
    grapheme_group_func,
    buffer.cluster_level == HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS,
  )
}

///|
fn GlyphInfo::is_unicode_format(self : GlyphInfo) -> Bool {
  self.get_general_category() == GC_FORMAT
}

///|
fn GlyphInfo::is_zwnj(self : GlyphInfo) -> Bool {
  self.is_unicode_format() && (self.unicode_props() & UPROPS_MASK_CF_ZWNJ) != 0
}

///|
fn GlyphInfo::is_zwj(self : GlyphInfo) -> Bool {
  self.is_unicode_format() && (self.unicode_props() & UPROPS_MASK_CF_ZWJ) != 0
}

// lig_props: aka lig_id / lig_comp
//
// When a ligature is formed:
//
//   - The ligature glyph and any marks in between all the same newly allocated
//     lig_id,
//   - The ligature glyph will get lig_num_comps set to the number of components
//   - The marks get lig_comp > 0, reflecting which component of the ligature
//     they were applied to.
//   - This is used in GPOS to attach marks to the right component of a ligature
//     in MarkLigPos,
//   - Note that when marks are ligated together, much of the above is skipped
//     and the current lig_id reused.
//
// When a multiple-substitution is done:
//
//   - All resulting glyphs will have lig_id = 0,
//   - The resulting glyphs will have lig_comp = 0, 1, 2, ... respectively.
//   - This is used in GPOS to attach marks to the first component of a
//     multiple substitution in MarkBasePos.
//
// The numbers are also used in GPOS to do mark-to-mark positioning only
// to marks that belong to the same component of the same ligature.

///|
const IS_LIG_BASE : Int = 0x10

///|
fn GlyphInfo::set_lig_props_for_ligature(
  self : GlyphInfo,
  lig_id : Int,
  lig_num_comps : Int,
) -> Unit {
  self.set_lig_props(
    ((lig_id << 5) & 0xFF) | IS_LIG_BASE | (lig_num_comps & 0x0F),
  )
}

///|
fn GlyphInfo::set_lig_props_for_mark(
  self : GlyphInfo,
  lig_id : Int,
  lig_comp : Int,
) -> Unit {
  self.set_lig_props(((lig_id << 5) & 0xFF) | (lig_comp & 0x0F))
}

///|
fn GlyphInfo::set_lig_props_for_component(self : GlyphInfo, comp : Int) -> Unit {
  self.set_lig_props_for_mark(0, comp)
}

///|
fn GlyphInfo::get_lig_id(self : GlyphInfo) -> Int {
  self.lig_props() >> 5
}

///|
fn GlyphInfo::ligated_internal(self : GlyphInfo) -> Bool {
  (self.lig_props() & IS_LIG_BASE) != 0
}

///|
fn GlyphInfo::get_lig_comp(self : GlyphInfo) -> Int {
  if self.ligated_internal() {
    0
  } else {
    self.lig_props() & 0x0F
  }
}

///|
fn GlyphInfo::get_lig_num_comps(self : GlyphInfo) -> Int {
  if (self.glyph_props() & GLYPH_PROPS_LIGATURE) != 0 && self.ligated_internal() {
    self.lig_props() & 0x0F
  } else {
    1
  }
}

///|
fn GlyphInfo::is_base_glyph(self : GlyphInfo) -> Bool {
  (self.glyph_props() & GLYPH_PROPS_BASE_GLYPH) != 0
}

///|
fn GlyphInfo::is_ligature(self : GlyphInfo) -> Bool {
  (self.glyph_props() & GLYPH_PROPS_LIGATURE) != 0
}

///|
fn GlyphInfo::is_mark(self : GlyphInfo) -> Bool {
  (self.glyph_props() & GLYPH_PROPS_MARK) != 0
}

///|
fn GlyphInfo::substituted(self : GlyphInfo) -> Bool {
  (self.glyph_props() & GLYPH_PROPS_SUBSTITUTED) != 0
}

///|
fn GlyphInfo::ligated(self : GlyphInfo) -> Bool {
  (self.glyph_props() & GLYPH_PROPS_LIGATED) != 0
}

///|
fn GlyphInfo::multiplied(self : GlyphInfo) -> Bool {
  (self.glyph_props() & GLYPH_PROPS_MULTIPLIED) != 0
}

///|
fn GlyphInfo::ligated_and_didnt_multiply(self : GlyphInfo) -> Bool {
  self.ligated() && !self.multiplied()
}

///|
fn GlyphInfo::clear_ligated_and_multiplied(self : GlyphInfo) -> Unit {
  let n = self.glyph_props()
  self.set_glyph_props(
    n & (GLYPH_PROPS_LIGATED | GLYPH_PROPS_MULTIPLIED).lnot(),
  )
}

///|
fn GlyphInfo::clear_substituted(self : GlyphInfo) -> Unit {
  let n = self.glyph_props()
  self.set_glyph_props(n & GLYPH_PROPS_SUBSTITUTED.lnot())
}

///|
fn _hb_clear_substitution_flags(
  _plan : ShapePlan,
  _face : Face,
  buffer : Buffer,
) -> Bool {
  for i in 0..<buffer.len {
    buffer.info[i].clear_substituted()
  }
  false
}
