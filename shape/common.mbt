// Port of rustybuzz 0.20.1 `src/hb/common.rs` (directions, scripts,
// languages, features and variations).

///|
pub const HB_FEATURE_GLOBAL_START : UInt = 0

///|
pub const HB_FEATURE_GLOBAL_END : UInt = 0xFFFFFFFF

///|
/// Defines the direction in which text is to be read.
pub(all) enum Direction {
  /// Initial, unset direction.
  Invalid
  /// Text is set horizontally from left to right.
  LeftToRight
  /// Text is set horizontally from right to left.
  RightToLeft
  /// Text is set vertically from top to bottom.
  TopToBottom
  /// Text is set vertically from bottom to top.
  BottomToTop
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Direction with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Direction with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Direction with @debug.Debug::{to_repr}

///|
pub impl Default for Direction with fn default() {
  Invalid
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Direction with Default::{default}

///|
pub fn Direction::is_horizontal(self : Direction) -> Bool {
  match self {
    Invalid => false
    LeftToRight => true
    RightToLeft => true
    TopToBottom => false
    BottomToTop => false
  }
}

///|
pub fn Direction::is_vertical(self : Direction) -> Bool {
  !self.is_horizontal()
}

///|
pub fn Direction::is_forward(self : Direction) -> Bool {
  match self {
    Invalid => false
    LeftToRight => true
    RightToLeft => false
    TopToBottom => true
    BottomToTop => false
  }
}

///|
pub fn Direction::is_backward(self : Direction) -> Bool {
  !self.is_forward()
}

///|
pub fn Direction::reverse(self : Direction) -> Direction {
  match self {
    Invalid => Invalid
    LeftToRight => RightToLeft
    RightToLeft => LeftToRight
    TopToBottom => BottomToTop
    BottomToTop => TopToBottom
  }
}

///|
/// The native direction of a script, if it has one.
pub fn Direction::from_script(script : Script) -> Direction? {
  // https://docs.google.com/spreadsheets/d/1Y90M0Ie3MUJ6UVCRDOypOtijlMDLNNyyLk36T6iMu0o
  match tag_string(script.0) {
    // Unicode-1.1 additions
    "Arab"
    | "Hebr"
    // Unicode-3.0 additions
    | "Syrc"
    | "Thaa"
    // Unicode-4.0 additions
    | "Cprt"
    // Unicode-4.1 additions
    | "Khar"
    // Unicode-5.0 additions
    | "Phnx"
    | "Nkoo"
    // Unicode-5.1 additions
    | "Lydi"
    // Unicode-5.2 additions
    | "Avst"
    | "Armi"
    | "Phli"
    | "Prti"
    | "Sarb"
    | "Orkh"
    | "Samr"
    // Unicode-6.0 additions
    | "Mand"
    // Unicode-6.1 additions
    | "Merc"
    | "Mero"
    // Unicode-7.0 additions
    | "Mani"
    | "Mend"
    | "Nbat"
    | "Narb"
    | "Palm"
    | "Phlp"
    // Unicode-8.0 additions
    | "Hatr"
    // Unicode-9.0 additions
    | "Adlm"
    // Unicode-11.0 additions
    | "Rohg"
    | "Sogo"
    | "Sogd"
    // Unicode-12.0 additions
    | "Elym"
    // Unicode-13.0 additions
    | "Chrs"
    | "Yezi"
    // Unicode-14.0 additions
    | "Ougr" => Some(RightToLeft)
    // https://github.com/harfbuzz/harfbuzz/issues/1000
    "Hung" | "Ital" | "Runr" | "Tfng" => None
    _ => Some(LeftToRight)
  }
}

///|
/// Parses a direction (only the first letter matters, like harfbuzz).
pub fn Direction::from_str(s : String) -> Direction? {
  if s.is_empty() {
    return None
  }
  match s.code_unit_at(0).to_int() {
    'l' | 'L' => Some(LeftToRight)
    'r' | 'R' => Some(RightToLeft)
    't' | 'T' => Some(TopToBottom)
    'b' | 'B' => Some(BottomToTop)
    _ => None
  }
}

///|
/// A script language.
pub(all) struct Language(String) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Language with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Language with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Language with @debug.Debug::{to_repr}

///|
/// Returns the language as a string.
pub fn Language::as_str(self : Language) -> String {
  self.0
}

///|
/// Parses a language (lowercased; must not be empty).
pub fn Language::from_str(s : String) -> Language? {
  if s.is_empty() {
    None
  } else {
    Some(Language(ascii_lowercase(s)))
  }
}

///|
fn ascii_lowercase(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    buf.write_char(
      if c >= 'A' && c <= 'Z' {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      },
    )
  }
  buf.to_string()
}

///|
/// A text script. In harfbuzz, despite having `hb_script_t`, script can
/// actually have any tag (but not `HB_SCRIPT_INVALID`).
pub(all) struct Script(@otf.Tag) derive(Eq, Compare, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Script with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Script with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Script with Hash::{hash, hash_combine}

///|
pub impl Show for Script with fn output(self, logger) {
  logger.write_string("Script(")
  logger.write_string(tag_string(self.0))
  logger.write_string(")")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Script with Show::{to_string, output}

///|
fn Script::from_bytes(b : Bytes) -> Script {
  Script(@otf.Tag::from_bytes(b))
}

///|
/// Converts an ISO 15924 script tag to a corresponding `Script`.
pub fn Script::from_iso15924_tag(tag : @otf.Tag) -> Script? {
  if tag.is_null() {
    return None
  }

  // Be lenient, adjust case (one capital letter followed by three small letters).
  let tag = @otf.Tag((tag.as_u32() & 0xDFDFDFDF) | 0x00202020)
  match tag_string(tag) {
    // These graduated from the 'Q' private-area codes, but
    // the old code is still aliased by Unicode, and the Qaai
    // one in use by ICU.
    "Qaai" => return Some(script_inherited)
    "Qaac" => return Some(script_coptic)

    // Script variants from https://unicode.org/iso15924/
    "Aran" => return Some(script_arabic)
    "Cyrs" => return Some(script_cyrillic)
    "Geok" => return Some(script_georgian)
    "Hans" | "Hant" => return Some(script_han)
    "Jamo" => return Some(script_hangul)
    "Latf" | "Latg" => return Some(script_latin)
    "Syre" | "Syrj" | "Syrn" => return Some(script_syriac)
    _ => ()
  }
  if (tag.as_u32() & 0xE0E0E0E0) == 0x40606060 {
    Some(Script(tag))
  } else {
    Some(script_unknown)
  }
}

///|
/// Parses a script from a (lossy) tag string.
pub fn Script::from_str(s : String) -> Script? {
  let bytes = Bytes::from_array(
    s.to_array().map(c => (c.to_int() & 0xFF).to_byte()),
  )
  Script::from_iso15924_tag(@otf.Tag::from_bytes_lossy(bytes[:]))
}

///|
/// Returns script's tag.
pub fn Script::tag(self : Script) -> @otf.Tag {
  self.0
}

///|
/// The 4 characters of a tag.
fn tag_string(tag : @otf.Tag) -> String {
  String::from_array(tag.to_chars())
}

// Predefined scripts.

// Since 1.1

///|
pub let script_common : Script = Script::from_bytes(b"Zyyy")

///|
pub let script_inherited : Script = Script::from_bytes(b"Zinh")

///|
pub let script_arabic : Script = Script::from_bytes(b"Arab")

///|
pub let script_armenian : Script = Script::from_bytes(b"Armn")

///|
pub let script_bengali : Script = Script::from_bytes(b"Beng")

///|
pub let script_cyrillic : Script = Script::from_bytes(b"Cyrl")

///|
pub let script_devanagari : Script = Script::from_bytes(b"Deva")

///|
pub let script_georgian : Script = Script::from_bytes(b"Geor")

///|
pub let script_greek : Script = Script::from_bytes(b"Grek")

///|
pub let script_gujarati : Script = Script::from_bytes(b"Gujr")

///|
pub let script_gurmukhi : Script = Script::from_bytes(b"Guru")

///|
pub let script_hangul : Script = Script::from_bytes(b"Hang")

///|
pub let script_han : Script = Script::from_bytes(b"Hani")

///|
pub let script_hebrew : Script = Script::from_bytes(b"Hebr")

///|
pub let script_hiragana : Script = Script::from_bytes(b"Hira")

///|
pub let script_kannada : Script = Script::from_bytes(b"Knda")

///|
pub let script_katakana : Script = Script::from_bytes(b"Kana")

///|
pub let script_lao : Script = Script::from_bytes(b"Laoo")

///|
pub let script_latin : Script = Script::from_bytes(b"Latn")

///|
pub let script_malayalam : Script = Script::from_bytes(b"Mlym")

///|
pub let script_oriya : Script = Script::from_bytes(b"Orya")

///|
pub let script_tamil : Script = Script::from_bytes(b"Taml")

///|
pub let script_telugu : Script = Script::from_bytes(b"Telu")

///|
pub let script_thai : Script = Script::from_bytes(b"Thai")

// Since 2.0

///|
pub let script_tibetan : Script = Script::from_bytes(b"Tibt")

// Since 3.0

///|
pub let script_bopomofo : Script = Script::from_bytes(b"Bopo")

///|
pub let script_braille : Script = Script::from_bytes(b"Brai")

///|
pub let script_canadian_syllabics : Script = Script::from_bytes(b"Cans")

///|
pub let script_cherokee : Script = Script::from_bytes(b"Cher")

///|
pub let script_ethiopic : Script = Script::from_bytes(b"Ethi")

///|
pub let script_khmer : Script = Script::from_bytes(b"Khmr")

///|
pub let script_mongolian : Script = Script::from_bytes(b"Mong")

///|
pub let script_myanmar : Script = Script::from_bytes(b"Mymr")

///|
pub let script_ogham : Script = Script::from_bytes(b"Ogam")

///|
pub let script_runic : Script = Script::from_bytes(b"Runr")

///|
pub let script_sinhala : Script = Script::from_bytes(b"Sinh")

///|
pub let script_syriac : Script = Script::from_bytes(b"Syrc")

///|
pub let script_thaana : Script = Script::from_bytes(b"Thaa")

///|
pub let script_yi : Script = Script::from_bytes(b"Yiii")

// Since 3.1

///|
pub let script_deseret : Script = Script::from_bytes(b"Dsrt")

///|
pub let script_gothic : Script = Script::from_bytes(b"Goth")

///|
pub let script_old_italic : Script = Script::from_bytes(b"Ital")

// Since 3.2

///|
pub let script_buhid : Script = Script::from_bytes(b"Buhd")

///|
pub let script_hanunoo : Script = Script::from_bytes(b"Hano")

///|
pub let script_tagalog : Script = Script::from_bytes(b"Tglg")

///|
pub let script_tagbanwa : Script = Script::from_bytes(b"Tagb")

// Since 4.0

///|
pub let script_cypriot : Script = Script::from_bytes(b"Cprt")

///|
pub let script_limbu : Script = Script::from_bytes(b"Limb")

///|
pub let script_linear_b : Script = Script::from_bytes(b"Linb")

///|
pub let script_osmanya : Script = Script::from_bytes(b"Osma")

///|
pub let script_shavian : Script = Script::from_bytes(b"Shaw")

///|
pub let script_tai_le : Script = Script::from_bytes(b"Tale")

///|
pub let script_ugaritic : Script = Script::from_bytes(b"Ugar")

// Since 4.1

///|
pub let script_buginese : Script = Script::from_bytes(b"Bugi")

///|
pub let script_coptic : Script = Script::from_bytes(b"Copt")

///|
pub let script_glagolitic : Script = Script::from_bytes(b"Glag")

///|
pub let script_kharoshthi : Script = Script::from_bytes(b"Khar")

///|
pub let script_new_tai_lue : Script = Script::from_bytes(b"Talu")

///|
pub let script_old_persian : Script = Script::from_bytes(b"Xpeo")

///|
pub let script_syloti_nagri : Script = Script::from_bytes(b"Sylo")

///|
pub let script_tifinagh : Script = Script::from_bytes(b"Tfng")

// Since 5.0

///|
/// Script can be Unknown, but not Invalid.
pub let script_unknown : Script = Script::from_bytes(b"Zzzz")

///|
pub let script_balinese : Script = Script::from_bytes(b"Bali")

///|
pub let script_cuneiform : Script = Script::from_bytes(b"Xsux")

///|
pub let script_nko : Script = Script::from_bytes(b"Nkoo")

///|
pub let script_phags_pa : Script = Script::from_bytes(b"Phag")

///|
pub let script_phoenician : Script = Script::from_bytes(b"Phnx")

// Since 5.1

///|
pub let script_carian : Script = Script::from_bytes(b"Cari")

///|
pub let script_cham : Script = Script::from_bytes(b"Cham")

///|
pub let script_kayah_li : Script = Script::from_bytes(b"Kali")

///|
pub let script_lepcha : Script = Script::from_bytes(b"Lepc")

///|
pub let script_lycian : Script = Script::from_bytes(b"Lyci")

///|
pub let script_lydian : Script = Script::from_bytes(b"Lydi")

///|
pub let script_ol_chiki : Script = Script::from_bytes(b"Olck")

///|
pub let script_rejang : Script = Script::from_bytes(b"Rjng")

///|
pub let script_saurashtra : Script = Script::from_bytes(b"Saur")

///|
pub let script_sundanese : Script = Script::from_bytes(b"Sund")

///|
pub let script_vai : Script = Script::from_bytes(b"Vaii")

// Since 5.2

///|
pub let script_avestan : Script = Script::from_bytes(b"Avst")

///|
pub let script_bamum : Script = Script::from_bytes(b"Bamu")

///|
pub let script_egyptian_hieroglyphs : Script = Script::from_bytes(b"Egyp")

///|
pub let script_imperial_aramaic : Script = Script::from_bytes(b"Armi")

///|
pub let script_inscriptional_pahlavi : Script = Script::from_bytes(b"Phli")

///|
pub let script_inscriptional_parthian : Script = Script::from_bytes(b"Prti")

///|
pub let script_javanese : Script = Script::from_bytes(b"Java")

///|
pub let script_kaithi : Script = Script::from_bytes(b"Kthi")

///|
pub let script_lisu : Script = Script::from_bytes(b"Lisu")

///|
pub let script_meetei_mayek : Script = Script::from_bytes(b"Mtei")

///|
pub let script_old_south_arabian : Script = Script::from_bytes(b"Sarb")

///|
pub let script_old_turkic : Script = Script::from_bytes(b"Orkh")

///|
pub let script_samaritan : Script = Script::from_bytes(b"Samr")

///|
pub let script_tai_tham : Script = Script::from_bytes(b"Lana")

///|
pub let script_tai_viet : Script = Script::from_bytes(b"Tavt")

// Since 6.0

///|
pub let script_batak : Script = Script::from_bytes(b"Batk")

///|
pub let script_brahmi : Script = Script::from_bytes(b"Brah")

///|
pub let script_mandaic : Script = Script::from_bytes(b"Mand")

// Since 6.1

///|
pub let script_chakma : Script = Script::from_bytes(b"Cakm")

///|
pub let script_meroitic_cursive : Script = Script::from_bytes(b"Merc")

///|
pub let script_meroitic_hieroglyphs : Script = Script::from_bytes(b"Mero")

///|
pub let script_miao : Script = Script::from_bytes(b"Plrd")

///|
pub let script_sharada : Script = Script::from_bytes(b"Shrd")

///|
pub let script_sora_sompeng : Script = Script::from_bytes(b"Sora")

///|
pub let script_takri : Script = Script::from_bytes(b"Takr")

// Since 7.0

///|
pub let script_bassa_vah : Script = Script::from_bytes(b"Bass")

///|
pub let script_caucasian_albanian : Script = Script::from_bytes(b"Aghb")

///|
pub let script_duployan : Script = Script::from_bytes(b"Dupl")

///|
pub let script_elbasan : Script = Script::from_bytes(b"Elba")

///|
pub let script_grantha : Script = Script::from_bytes(b"Gran")

///|
pub let script_khojki : Script = Script::from_bytes(b"Khoj")

///|
pub let script_khudawadi : Script = Script::from_bytes(b"Sind")

///|
pub let script_linear_a : Script = Script::from_bytes(b"Lina")

///|
pub let script_mahajani : Script = Script::from_bytes(b"Mahj")

///|
pub let script_manichaean : Script = Script::from_bytes(b"Mani")

///|
pub let script_mende_kikakui : Script = Script::from_bytes(b"Mend")

///|
pub let script_modi : Script = Script::from_bytes(b"Modi")

///|
pub let script_mro : Script = Script::from_bytes(b"Mroo")

///|
pub let script_nabataean : Script = Script::from_bytes(b"Nbat")

///|
pub let script_old_north_arabian : Script = Script::from_bytes(b"Narb")

///|
pub let script_old_permic : Script = Script::from_bytes(b"Perm")

///|
pub let script_pahawh_hmong : Script = Script::from_bytes(b"Hmng")

///|
pub let script_palmyrene : Script = Script::from_bytes(b"Palm")

///|
pub let script_pau_cin_hau : Script = Script::from_bytes(b"Pauc")

///|
pub let script_psalter_pahlavi : Script = Script::from_bytes(b"Phlp")

///|
pub let script_siddham : Script = Script::from_bytes(b"Sidd")

///|
pub let script_tirhuta : Script = Script::from_bytes(b"Tirh")

///|
pub let script_warang_citi : Script = Script::from_bytes(b"Wara")

// Since 8.0

///|
pub let script_ahom : Script = Script::from_bytes(b"Ahom")

///|
pub let script_anatolian_hieroglyphs : Script = Script::from_bytes(b"Hluw")

///|
pub let script_hatran : Script = Script::from_bytes(b"Hatr")

///|
pub let script_multani : Script = Script::from_bytes(b"Mult")

///|
pub let script_old_hungarian : Script = Script::from_bytes(b"Hung")

///|
pub let script_signwriting : Script = Script::from_bytes(b"Sgnw")

// Since 9.0

///|
pub let script_adlam : Script = Script::from_bytes(b"Adlm")

///|
pub let script_bhaiksuki : Script = Script::from_bytes(b"Bhks")

///|
pub let script_marchen : Script = Script::from_bytes(b"Marc")

///|
pub let script_osage : Script = Script::from_bytes(b"Osge")

///|
pub let script_tangut : Script = Script::from_bytes(b"Tang")

///|
pub let script_newa : Script = Script::from_bytes(b"Newa")

// Since 10.0

///|
pub let script_masaram_gondi : Script = Script::from_bytes(b"Gonm")

///|
pub let script_nushu : Script = Script::from_bytes(b"Nshu")

///|
pub let script_soyombo : Script = Script::from_bytes(b"Soyo")

///|
pub let script_zanabazar_square : Script = Script::from_bytes(b"Zanb")

// Since 11.0

///|
pub let script_dogra : Script = Script::from_bytes(b"Dogr")

///|
pub let script_gunjala_gondi : Script = Script::from_bytes(b"Gong")

///|
pub let script_hanifi_rohingya : Script = Script::from_bytes(b"Rohg")

///|
pub let script_makasar : Script = Script::from_bytes(b"Maka")

///|
pub let script_medefaidrin : Script = Script::from_bytes(b"Medf")

///|
pub let script_old_sogdian : Script = Script::from_bytes(b"Sogo")

///|
pub let script_sogdian : Script = Script::from_bytes(b"Sogd")

// Since 12.0

///|
pub let script_elymaic : Script = Script::from_bytes(b"Elym")

///|
pub let script_nandinagari : Script = Script::from_bytes(b"Nand")

///|
pub let script_nyiakeng_puachue_hmong : Script = Script::from_bytes(b"Hmnp")

///|
pub let script_wancho : Script = Script::from_bytes(b"Wcho")

// Since 13.0

///|
pub let script_chorasmian : Script = Script::from_bytes(b"Chrs")

///|
pub let script_dives_akuru : Script = Script::from_bytes(b"Diak")

///|
pub let script_khitan_small_script : Script = Script::from_bytes(b"Kits")

///|
pub let script_yezidi : Script = Script::from_bytes(b"Yezi")

// Since 14.0

///|
pub let script_cypro_minoan : Script = Script::from_bytes(b"Cpmn")

///|
pub let script_old_uyghur : Script = Script::from_bytes(b"Ougr")

///|
pub let script_tangsa : Script = Script::from_bytes(b"Tnsa")

///|
pub let script_toto : Script = Script::from_bytes(b"Toto")

///|
pub let script_vithkuqi : Script = Script::from_bytes(b"Vith")

// Since 15.0

///|
pub let script_kawi : Script = Script::from_bytes(b"Kawi")

///|
pub let script_nag_mundari : Script = Script::from_bytes(b"Nagm")

// Since 16.0

///|
pub let script_garay : Script = Script::from_bytes(b"Gara")

///|
pub let script_gurung_khema : Script = Script::from_bytes(b"Gukh")

///|
pub let script_kirat_rai : Script = Script::from_bytes(b"Krai")

///|
pub let script_ol_onal : Script = Script::from_bytes(b"Onao")

///|
pub let script_sunuwar : Script = Script::from_bytes(b"Sunu")

///|
pub let script_todhri : Script = Script::from_bytes(b"Todr")

///|
pub let script_tulu_tigalari : Script = Script::from_bytes(b"Tutg")

///|
pub let script_script_math : Script = Script::from_bytes(b"Zmth")

///|
/// https://github.com/harfbuzz/harfbuzz/issues/1162
pub let script_myanmar_zawgyi : Script = Script::from_bytes(b"Qaag")

///|
/// A feature tag with an accompanying range specifying on which subslice of
/// `shape`s input it should be applied.
pub(all) struct Feature {
  tag : @otf.Tag
  value : UInt
  start : UInt
  end : UInt
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Feature with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Feature with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Feature with @debug.Debug::{to_repr}

///|
/// Create a new `Feature` applying to the inclusive cluster range
/// `start..=end` (rustybuzz's `Feature::new` with resolved range bounds).
pub fn Feature::new(
  tag : @otf.Tag,
  value : UInt,
  start~ : UInt = 0,
  end~ : UInt = 0xFFFFFFFF,
) -> Feature {
  { tag, value, start, end, }
}

///|
pub fn Feature::is_global(self : Feature) -> Bool {
  self.start == 0 && self.end == 0xFFFFFFFF
}

///|
/// Parses a `Feature` form a string.
///
/// Possible values:
///
/// - `kern` -> kern .. 1
/// - `+kern` -> kern .. 1
/// - `-kern` -> kern .. 0
/// - `kern=0` -> kern .. 0
/// - `kern=1` -> kern .. 1
/// - `aalt=2` -> altr .. 2
/// - `kern[]` -> kern .. 1
/// - `kern[:]` -> kern .. 1
/// - `kern[5:]` -> kern 5.. 1
/// - `kern[:5]` -> kern ..=5 1
/// - `kern[3:5]` -> kern 3..=5 1
/// - `kern[3]` -> kern 3..=4 1
/// - `aalt[3:5]=2` -> kern 3..=5 1
pub fn Feature::from_str(s : String) -> Feature? {
  if s.is_empty() {
    return None
  }
  let p = TextParser::new(s)

  // Parse prefix.
  let mut value : UInt = 1
  guard p.curr_byte() is Some(first) else { return None }
  match first {
    '-' => {
      value = 0
      p.advance(1)
    }
    '+' => {
      value = 1
      p.advance(1)
    }
    _ => ()
  }

  // Parse tag.
  p.skip_spaces()
  let quote = p.consume_quote()
  guard p.consume_tag() is Some(tag) else { return None }

  // Force closing quote.
  if quote is Some(quote) {
    guard p.consume_byte(quote) is Some(v) else { return None }
    v
  }

  // Parse indices.
  p.skip_spaces()
  let (start, end) = if p.consume_byte('[') is Some(_) {
    let start_opt = p.consume_i32()
    let start = start_opt.unwrap_or(0).reinterpret_as_uint() // negative value overflow is ok
    let end = if p.curr_byte() is Some(':' | ';') {
      p.advance(1)
      p.consume_i32().unwrap_or(-1).reinterpret_as_uint() // negative value overflow is ok
    } else if start_opt is Some(_) && start != 0xFFFFFFFF {
      start + 1
    } else {
      0xFFFFFFFF
    }
    guard p.consume_byte(']') is Some(_) else { return None }
    (start, end)
  } else {
    (0U, 0xFFFFFFFFU)
  }

  // Parse postfix.
  let had_equal = p.consume_byte('=') is Some(_)
  let value1 = match p.consume_i32() {
    Some(v) => Some(v)
    None => p.consume_bool().map(b => if b { 1 } else { 0 })
  }
  if had_equal && value1 is None {
    return None
  }
  if value1 is Some(value1) {
    value = value1.reinterpret_as_uint() // negative value overflow is ok
  }
  p.skip_spaces()
  if !p.at_end() {
    return None
  }
  Some({ tag, value, start, end, })
}

///|
/// A font variation.
pub(all) struct Variation {
  tag : @otf.Tag
  value : Float
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Variation with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Variation with @debug.Debug::{to_repr}

///|
/// Parses a `Variation` from a string like `wght=500`.
pub fn Variation::from_str(s : String) -> Variation? {
  if s.is_empty() {
    return None
  }
  let p = TextParser::new(s)

  // Parse tag.
  p.skip_spaces()
  let quote = p.consume_quote()
  guard p.consume_tag() is Some(tag) else { return None }

  // Force closing quote.
  if quote is Some(quote) {
    guard p.consume_byte(quote) is Some(v) else { return None }
    v
  }
  let _ = p.consume_byte('=')
  guard p.consume_f32() is Some(value) else { return None }
  p.skip_spaces()
  if !p.at_end() {
    return None
  }
  Some({ tag, value, })
}

///|
fn default_script_tag() -> @otf.Tag {
  @otf.Tag::from_bytes(b"DFLT")
}

///|
fn default_language_tag() -> @otf.Tag {
  @otf.Tag::from_bytes(b"dflt")
}

///|
/// Converts tag to uppercase.
fn tag_to_uppercase(tag : @otf.Tag) -> @otf.Tag {
  let b = tag.to_bytes()
  let up = (c : Byte) => if c >= b'a' && c <= b'z' { c - 32 } else { c }
  @otf.Tag::from_bytes(
    Bytes::from_array([up(b[0]), up(b[1]), up(b[2]), up(b[3])]),
  )
}
