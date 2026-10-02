// Port of rustybuzz 0.20.1 `src/hb/aat_layout.rs`.
//
// The feature type/selector constants and `feature_mappings` are generated
// into `aat_layout_gen.mbt` by scripts/gen_shape_tables.py.

///|
/// `hb_aat_feature_mapping_t`
priv struct AatFeatureMapping {
  ot_feature_tag : @otf.Tag
  aat_feature_type : Int
  selector_to_enable : Int
  selector_to_disable : Int
}

///|
fn AatFeatureMapping::new(
  ot_feature_tag : String,
  aat_feature_type : Int,
  selector_to_enable : Int,
  selector_to_disable : Int,
) -> AatFeatureMapping {
  {
    ot_feature_tag: tag(ot_feature_tag),
    aat_feature_type,
    selector_to_enable,
    selector_to_disable,
  }
}

///|
/// `AAT::DELETED_GLYPH`
const AAT_DELETED_GLYPH : UInt = 0xFFFF

///|
fn hb_aat_layout_substitute(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  let builder = AatMapBuilder::default()
  for feature in plan.user_features {
    builder.add_feature(face, feature) |> ignore
  }
  let aat_map = AatMap::default()
  if plan.apply_morx {
    builder.compile(face, aat_map)
  }
  let c = AatApplyContext::new(face, buffer)
  morx_apply(c, aat_map) |> ignore
}

///|
fn hb_aat_layout_zero_width_deleted_glyphs(buffer : Buffer) -> Unit {
  for i in 0..<buffer.len {
    if buffer.info[i].glyph_id == AAT_DELETED_GLYPH {
      buffer.pos[i].x_advance = 0
      buffer.pos[i].y_advance = 0
      buffer.pos[i].x_offset = 0
      buffer.pos[i].y_offset = 0
    }
  }
}

///|
fn is_deleted_glyph(info : GlyphInfo) -> Bool {
  info.glyph_id == AAT_DELETED_GLYPH
}

///|
fn hb_aat_layout_remove_deleted_glyphs(buffer : Buffer) -> Unit {
  buffer.delete_glyphs_inplace(is_deleted_glyph)
}

///|
fn hb_aat_layout_position(
  plan : ShapePlan,
  face : Face,
  buffer : Buffer,
) -> Unit {
  kerx_apply(plan, face, buffer) |> ignore
}

///|
fn hb_aat_layout_track(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit {
  trak_apply(plan, face, buffer) |> ignore
}
