// Port of rustybuzz 0.20.1 `src/hb/ot_shaper.rs`.

///|
fn GlyphInfo::ot_shaper_var_u8_category(self : GlyphInfo) -> Int {
  // var2 as [u8; 4], element 2.
  ((self.var2 >> 16) & 0xFF).reinterpret_as_int()
}

///|
fn GlyphInfo::set_ot_shaper_var_u8_category(self : GlyphInfo, c : Int) -> Unit {
  self.var2 = (self.var2 & 0xFF00FFFF) |
    ((c.reinterpret_as_uint() & 0xFF) << 16)
}

///|
fn GlyphInfo::ot_shaper_var_u8_auxiliary(self : GlyphInfo) -> Int {
  // var2 as [u8; 4], element 3.
  ((self.var2 >> 24) & 0xFF).reinterpret_as_int()
}

///|
fn GlyphInfo::set_ot_shaper_var_u8_auxiliary(self : GlyphInfo, c : Int) -> Unit {
  self.var2 = (self.var2 & 0x00FFFFFF) |
    ((c.reinterpret_as_uint() & 0xFF) << 24)
}

///|
const MAX_COMBINING_MARKS : Int = 32

///|
const HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE : Int = 0

///|
const HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_EARLY : Int = 1

///|
const HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_LATE : Int = 2

///|
/// Shaper-specific plan data (rustybuzz stores a `Box<dyn Any>`).
priv enum ShaperData {
  NoData
  Arabic(ArabicShapePlan)
  Hangul(HangulShapePlan)
  Indic(IndicShapePlan)
  Khmer(KhmerShapePlan)
  Use(UniversalShapePlan)
}

///|
/// A complex shaper (`hb_ot_shaper_t`).
priv struct OtShaper {
  /// Identifies the shaper (Rust compares shaper addresses).
  name : String
  /// Called during `shape_plan()`.
  /// Shapers should use plan.map to add their features and callbacks.
  collect_features : ((ShapePlanner) -> Unit)?
  /// Called during `shape_plan()`.
  /// Shapers should use plan.map to override features and add callbacks after
  /// common features are added.
  override_features : ((ShapePlanner) -> Unit)?
  /// Called at the end of `shape_plan()`.
  /// Whatever shapers return will be accessible through `plan.data` later.
  create_data : ((ShapePlan) -> ShaperData)?
  /// Called during `shape()`.
  /// Shapers can use to modify text before shaping starts.
  preprocess_text : ((ShapePlan, Face, Buffer) -> Unit)?
  /// Called during `shape()`.
  /// Shapers can use to modify text before shaping starts.
  postprocess_glyphs : ((ShapePlan, Face, Buffer) -> Unit)?
  /// How to normalize.
  normalization_preference : Int
  /// Called during `shape()`'s normalization.
  decompose : DecomposeFn?
  /// Called during `shape()`'s normalization.
  compose : ComposeFn?
  /// Called during `shape()`.
  /// Shapers should use map to get feature masks and set on buffer.
  /// Shapers may NOT modify characters.
  setup_masks : ((ShapePlan, Face, Buffer) -> Unit)?
  /// If not `None`, then must match found GPOS script tag for
  /// GPOS to be applied.  Otherwise, fallback positioning will be used.
  gpos_tag : @otf.Tag?
  /// Called during `shape()`.
  /// Shapers can use to modify ordering of combining marks.
  reorder_marks : ((ShapePlan, Buffer, Int, Int) -> Unit)?
  /// If and when to zero-width marks.
  zero_width_marks : Int
  /// Whether to use fallback mark positioning.
  fallback_position : Bool
}

///|
let default_shaper : OtShaper = {
  name: "default",
  collect_features: None,
  override_features: None,
  create_data: None,
  preprocess_text: None,
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_AUTO,
  decompose: None,
  compose: None,
  setup_masks: None,
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_BY_GDEF_LATE,
  fallback_position: true,
}

///|
/// Same as default but no mark advance zeroing / fallback positioning.
/// Dumbest shaper ever, basically.
let dumber_shaper : OtShaper = {
  name: "dumber",
  collect_features: None,
  override_features: None,
  create_data: None,
  preprocess_text: None,
  postprocess_glyphs: None,
  normalization_preference: HB_OT_SHAPE_NORMALIZATION_MODE_AUTO,
  decompose: None,
  compose: None,
  setup_masks: None,
  gpos_tag: None,
  reorder_marks: None,
  zero_width_marks: HB_OT_SHAPE_ZERO_WIDTH_MARKS_NONE,
  fallback_position: false,
}

///|
fn hb_ot_shape_complex_categorize(
  script : Script,
  direction : Direction,
  gsub_script : @otf.Tag?,
) -> OtShaper {
  let dflt = Some(default_script_tag())
  let latn = Some(@otf.Tag::from_bytes(b"latn"))
  match tag_string(script.0) {
    // Unicode-1.1 additions
    "Arab"
    // Unicode-3.0 additions
    | "Syrc" =>
      // For Arabic script, use the Arabic shaper even if no OT script tag was found.
      // This is because we do fallback shaping for Arabic script (and not others).
      // But note that Arabic shaping is applicable only to horizontal layout; for
      // vertical text, just use the generic shaper instead.
      //
      // TODO: Does this still apply? Arabic fallback shaping was removed.
      if (gsub_script != dflt || script == script_arabic) &&
        direction.is_horizontal() {
        arabic_shaper
      } else {
        default_shaper
      }

    // Unicode-1.1 additions
    "Thai" | "Laoo" => thai_shaper

    // Unicode-1.1 additions
    "Hang" => hangul_shaper

    // Unicode-1.1 additions
    "Hebr" => hebrew_shaper

    // Unicode-1.1 additions
    "Beng"
    | "Deva"
    | "Gujr"
    | "Guru"
    | "Knda"
    | "Mlym"
    | "Orya"
    | "Taml"
    | "Telu" =>
      // If the designer designed the font for the 'DFLT' script,
      // (or we ended up arbitrarily pick 'latn'), use the default shaper.
      // Otherwise, use the specific shaper.
      //
      // If it's indy3 tag, send to USE.
      if gsub_script == dflt || gsub_script == latn {
        default_shaper
      } else if gsub_script is Some(tag) && (tag.as_u32() & 0xFF) == 0x33 {
        universal_shaper
      } else {
        indic_shaper
      }
    "Khmr" => khmer_shaper
    "Mymr" =>
      // If the designer designed the font for the 'DFLT' script,
      // (or we ended up arbitrarily pick 'latn'), use the default shaper.
      // Otherwise, use the specific shaper.
      //
      // If designer designed for 'mymr' tag, also send to default
      // shaper.  That's tag used from before Myanmar shaping spec
      // was developed.  The shaping spec uses 'mym2' tag.
      if gsub_script == dflt ||
        gsub_script == latn ||
        gsub_script == Some(@otf.Tag::from_bytes(b"mymr")) {
        default_shaper
      } else {
        myanmar_shaper
      }

    // https://github.com/harfbuzz/harfbuzz/issues/1162
    "Qaag" => myanmar_zawgyi_shaper

    // Unicode-2.0 additions
    "Tibt"
    // Unicode-3.0 additions
    | "Mong"
    | "Sinh"
    // Unicode-3.2 additions
    | "Buhd"
    | "Hano"
    | "Tglg"
    | "Tagb"
    // Unicode-4.0 additions
    | "Limb"
    | "Tale"
    // Unicode-4.1 additions
    | "Bugi"
    | "Khar"
    | "Sylo"
    | "Tfng"
    // Unicode-5.0 additions
    | "Bali"
    | "Nkoo"
    | "Phag"
    // Unicode-5.1 additions
    | "Cham"
    | "Kali"
    | "Lepc"
    | "Rjng"
    | "Saur"
    | "Sund"
    // Unicode-5.2 additions
    | "Egyp"
    | "Java"
    | "Kthi"
    | "Mtei"
    | "Lana"
    | "Tavt"
    // Unicode-6.0 additions
    | "Batk"
    | "Brah"
    | "Mand"
    // Unicode-6.1 additions
    | "Cakm"
    | "Plrd"
    | "Shrd"
    | "Takr"
    // Unicode-7.0 additions
    | "Dupl"
    | "Gran"
    | "Khoj"
    | "Sind"
    | "Mahj"
    | "Mani"
    | "Modi"
    | "Hmng"
    | "Phlp"
    | "Sidd"
    | "Tirh"
    // Unicode-8.0 additions
    | "Ahom"
    | "Mult"
    // Unicode-9.0 additions
    | "Adlm"
    | "Bhks"
    | "Marc"
    | "Newa"
    // Unicode-10.0 additions
    | "Gonm"
    | "Soyo"
    | "Zanb"
    // Unicode-11.0 additions
    | "Dogr"
    | "Gong"
    | "Rohg"
    | "Maka"
    | "Medf"
    | "Sogo"
    | "Sogd"
    // Unicode-12.0 additions
    | "Elym"
    | "Nand"
    | "Hmnp"
    | "Wcho"
    // Unicode-13.0 additions
    | "Chrs"
    | "Diak"
    | "Kits"
    | "Yezi"
    // Unicode-14.0 additions
    | "Cpmn"
    | "Ougr"
    | "Tnsa"
    | "Toto"
    | "Vith"
    // Unicode-15.0 additions
    | "Kawi"
    | "Nagm"
    // Unicode-16.0 additions
    | "Gara"
    | "Gukh"
    | "Krai"
    | "Onao"
    | "Sunu"
    | "Todr"
    | "Tutg" =>
      // If the designer designed the font for the 'DFLT' script,
      // (or we ended up arbitrarily pick 'latn'), use the default shaper.
      // Otherwise, use the specific shaper.
      // Note that for some simple scripts, there may not be *any*
      // GSUB/GPOS needed, so there may be no scripts found!
      if gsub_script == dflt || gsub_script == latn {
        default_shaper
      } else {
        universal_shaper
      }
    _ => default_shaper
  }
}
