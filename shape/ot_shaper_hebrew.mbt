// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_hebrew.rs`.

///|
let hebrew_shaper : OtShaper = {
  collect_features: None,
  override_features: None,
  create_data: None,
  preprocess_text: None,
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_AUTO,
  decompose: None,
  compose: Some(compose_hebrew),
  setup_masks: None,
  gpos_tag: Some(tag("hebr")),
  reorder_marks: Some(reorder_marks_hebrew),
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_LATE,
  fallback_position: true,
}

///|
/// `modified_combining_class::CCC10` (sheva).
const MODIFIED_CCC10 : Int = 22

///|
/// `modified_combining_class::CCC14` (hiriq).
const MODIFIED_CCC14 : Int = 23

///|
/// `modified_combining_class::CCC17` (patah).
const MODIFIED_CCC17 : Int = 20

///|
/// `modified_combining_class::CCC18` (qamats & qamats qatan).
const MODIFIED_CCC18 : Int = 21

///|
fn reorder_marks_hebrew(
  _plan : ShapePlan,
  buffer : Buffer,
  start : Int,
  end : Int,
) -> Unit {
  for i in (start + 2)..<end {
    let c0 = buffer.info[i - 2]
    let c1 = buffer.info[i - 1]
    let c2 = buffer.info[i - 0]
    if (
        c0.get_modified_combining_class() == MODIFIED_CCC17 ||
        c0.get_modified_combining_class() == MODIFIED_CCC18
      ) && // patach or qamats
      (
        c1.get_modified_combining_class() == MODIFIED_CCC10 ||
        c1.get_modified_combining_class() == MODIFIED_CCC14
      ) && // sheva or hiriq
      (
        c2.get_modified_combining_class() == MODIFIED_CCC22 ||
        c2.get_modified_combining_class() == CCC_BELOW
      ) {
      // meteg or below
      buffer.merge_clusters(i - 1, i + 1)
      buffer.info.swap(i - 1, i)
      break
    }
  }
}

///|
let s_dagesh_forms : ReadOnlyArray[Int] = [
  0xFB30, // ALEF
   0xFB31, // BET
   0xFB32, // GIMEL
   0xFB33, // DALET
   0xFB34, // HE
   0xFB35, // VAV
   0xFB36, // ZAYIN
   0x0000, // HET
   0xFB38, // TET
   0xFB39, // YOD
   0xFB3A, // FINAL KAF
   0xFB3B, // KAF
   0xFB3C, // LAMED
   0x0000, // FINAL MEM
   0xFB3E, // MEM
   0x0000, // FINAL NUN
   0xFB40, // NUN
   0xFB41, // SAMEKH
   0x0000, // AYIN
   0xFB43, // FINAL PE
   0xFB44, // PE
   0x0000, // FINAL TSADI
   0xFB46, // TSADI
   0xFB47, // QOF
   0xFB48, // RESH
   0xFB49, // SHIN
   0xFB4A, // TAV
]

///|
fn compose_hebrew(ctx : NormalizeContext, a : Int, b : Int) -> Int? {
  // Hebrew presentation-form shaping.
  // https://bugzilla.mozilla.org/show_bug.cgi?id=728866
  // Hebrew presentation forms with dagesh, for characters U+05D0..05EA;
  // Note that some letters do not have a dagesh presForm encoded.
  match compose(a, b) {
    Some(c) => Some(c)
    None if !ctx.plan.has_gpos_mark =>
      // Special-case Hebrew presentation forms that are excluded from
      // standard normalization, but wanted for old fonts.
      match b {
        0x05B4 =>
          // HIRIQ
          match a {
            0x05D9 => Some(0xFB1D) // YOD
            _ => None
          }
        0x05B7 =>
          // PATAH
          match a {
            0x05D9 => Some(0xFB1F) // YIDDISH YOD YOD
            0x05D0 => Some(0xFB2E) // ALEF
            _ => None
          }
        0x05B8 =>
          // QAMATS
          match a {
            0x05D0 => Some(0xFB2F) // ALEF
            _ => None
          }
        0x05B9 =>
          // HOLAM
          match a {
            0x05D5 => Some(0xFB4B) // VAV
            _ => None
          }
        0x05BC =>
          // DAGESH
          match a {
            0x05D0..=0x05EA => {
              let c = s_dagesh_forms[a - 0x05D0]
              if c != 0 {
                Some(c)
              } else {
                None
              }
            }
            0xFB2A => Some(0xFB2C) // SHIN WITH SHIN DOT
            0xFB2B => Some(0xFB2D) // SHIN WITH SIN DOT
            _ => None
          }
        0x05BF =>
          // RAFE
          match a {
            0x05D1 => Some(0xFB4C) // BET
            0x05DB => Some(0xFB4D) // KAF
            0x05E4 => Some(0xFB4E) // PE
            _ => None
          }
        0x05C1 =>
          // SHIN DOT
          match a {
            0x05E9 => Some(0xFB2A) // SHIN
            0xFB49 => Some(0xFB2C) // SHIN WITH DAGESH
            _ => None
          }
        0x05C2 =>
          // SIN DOT
          match a {
            0x05E9 => Some(0xFB2B) // SHIN
            0xFB49 => Some(0xFB2D) // SHIN WITH DAGESH
            _ => None
          }
        _ => None
      }
    None => None
  }
}
