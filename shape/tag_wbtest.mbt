// Port of the unit tests of rustybuzz 0.20.1 `src/hb/tag.rs` (`mod tests`).

///|
fn new_tag_to_script(tag : @otf.Tag) -> Script? {
  match tag_string(tag) {
    "bng2" => Some(script_bengali)
    "dev2" => Some(script_devanagari)
    "gjr2" => Some(script_gujarati)
    "gur2" => Some(script_gurmukhi)
    "knd2" => Some(script_kannada)
    "mlm2" => Some(script_malayalam)
    "ory2" => Some(script_oriya)
    "tml2" => Some(script_tamil)
    "tel2" => Some(script_telugu)
    "mym2" => Some(script_myanmar)
    _ => Some(script_unknown)
  }
}

///|
fn old_tag_to_script(tag : @otf.Tag) -> Script? {
  if tag == default_script_tag() {
    return None
  }
  let bytes = tag.to_bytes().to_array()

  // This side of the conversion is fully algorithmic.

  // Any spaces at the end of the tag are replaced by repeating the last
  // letter.  Eg 'nko ' -> 'Nkoo'
  if bytes[2] == b' ' {
    bytes[2] = bytes[1]
  }
  if bytes[3] == b' ' {
    bytes[3] = bytes[2]
  }

  // Change first char to uppercase.
  if bytes[0] >= b'a' && bytes[0] <= b'z' {
    bytes[0] = bytes[0] - 32
  }
  Some(Script(@otf.Tag::from_bytes(Bytes::from_array(bytes))))
}

///|
fn tag_to_script(tag : @otf.Tag) -> Script? {
  let bytes = tag.to_bytes()
  if bytes[3] == b'2' || bytes[3] == b'3' {
    let tag2 = bytes.to_array()
    tag2[3] = b'2'
    return new_tag_to_script(@otf.Tag::from_bytes(Bytes::from_array(tag2)))
  }
  old_tag_to_script(tag)
}

///|
/// `Script` has no `Debug`: compare scripts by tag.
fn script_tag(script : Script?) -> @otf.Tag? {
  script.map(s => s.tag())
}

///|
/// `Tag::from_bytes_lossy(s.as_bytes())`.
fn lossy(s : String) -> @otf.Tag {
  tag_from_bytes_lossy(s)
}

///|
/// `TagExt::to_lowercase` (test only in rustybuzz).
fn tag_to_lowercase(tag : @otf.Tag) -> @otf.Tag {
  let b = tag.to_bytes()
  let low = (c : Byte) => if c >= b'A' && c <= b'Z' { c + 32 } else { c }
  @otf.Tag::from_bytes(
    Bytes::from_array([low(b[0]), low(b[1]), low(b[2]), low(b[3])]),
  )
}

///|
fn test_simple_tags(tag : String, script : Script) -> Unit raise {
  let tag = lossy(tag)
  let (scripts, _) = tags_from_script_and_language(Some(script), None)
  if !scripts.is_empty() {
    assert_eq(tag, scripts[0])
  } else {
    assert_eq(tag, default_script_tag())
  }
  assert_eq(script_tag(tag_to_script(tag)), Some(script.tag()))
}

///|
test "tag_to_uppercase" {
  assert_eq(
    tag_to_uppercase(@otf.Tag::from_bytes(b"abcd")),
    @otf.Tag::from_bytes(b"ABCD"),
  )
  assert_eq(
    tag_to_uppercase(@otf.Tag::from_bytes(b"abc ")),
    @otf.Tag::from_bytes(b"ABC "),
  )
  assert_eq(
    tag_to_uppercase(@otf.Tag::from_bytes(b"ABCD")),
    @otf.Tag::from_bytes(b"ABCD"),
  )
}

///|
test "tag_to_lowercase" {
  assert_eq(
    tag_to_lowercase(@otf.Tag::from_bytes(b"abcd")),
    @otf.Tag::from_bytes(b"abcd"),
  )
  assert_eq(
    tag_to_lowercase(@otf.Tag::from_bytes(b"abc ")),
    @otf.Tag::from_bytes(b"abc "),
  )
  assert_eq(
    tag_to_lowercase(@otf.Tag::from_bytes(b"ABCD")),
    @otf.Tag::from_bytes(b"abcd"),
  )
}

///|
test "script_degenerate" {
  assert_eq(@otf.Tag::from_bytes(b"DFLT"), default_script_tag())

  // Hiragana and Katakana both map to 'kana'.
  test_simple_tags("kana", script_katakana)
  let (scripts, _) = tags_from_script_and_language(Some(script_hiragana), None)
  assert_eq(scripts, [@otf.Tag::from_bytes(b"kana")])

  // Spaces are replaced
  assert_eq(
    script_tag(tag_to_script(@otf.Tag::from_bytes(b"be  "))),
    script_tag(Script::from_iso15924_tag(@otf.Tag::from_bytes(b"Beee"))),
  )
}

///|
test "script_simple" {
  // Arbitrary non-existent script.
  test_simple_tags(
    "wwyz",
    Script::from_iso15924_tag(@otf.Tag::from_bytes(b"wWyZ")).unwrap(),
  )

  // These we don't really care about.
  test_simple_tags("zyyy", script_common)
  test_simple_tags("zinh", script_inherited)
  test_simple_tags("zzzz", script_unknown)
  test_simple_tags("arab", script_arabic)
  test_simple_tags("copt", script_coptic)
  test_simple_tags("kana", script_katakana)
  test_simple_tags("latn", script_latin)

  // These are trickier since their OT script tags have space.
  test_simple_tags("lao ", script_lao)
  test_simple_tags("yi  ", script_yi)
  // Unicode-5.0 additions.
  test_simple_tags("nko ", script_nko)
  // Unicode-5.1 additions.
  test_simple_tags("vai ", script_vai)

  // https://docs.microsoft.com/en-us/typography/opentype/spec/scripttags

  // Unicode-5.2 additions.
  test_simple_tags("mtei", script_meetei_mayek)
  // Unicode-6.0 additions.
  test_simple_tags("mand", script_mandaic)
}

///|
/// `test_script_from_language!`.
fn test_script_from_language(
  tag : String,
  lang : String,
  script : Script?,
) -> Unit raise {
  let tag = lossy(tag)
  let (scripts, _) = tags_from_script_and_language(
    script,
    Language::from_str(lang),
  )
  if !scripts.is_empty() {
    assert_eq(scripts, [tag])
  }
}

///|
test "script_indic" {
  fn check(
    tag1 : String,
    tag2 : String,
    tag3 : String,
    script : Script,
  ) -> Unit raise {
    let tag1 = lossy(tag1)
    let tag2 = lossy(tag2)
    let tag3 = lossy(tag3)
    let (scripts, _) = tags_from_script_and_language(Some(script), None)
    assert_eq(scripts, [tag1, tag2, tag3])
    assert_eq(script_tag(tag_to_script(tag1)), Some(script.tag()))
    assert_eq(script_tag(tag_to_script(tag2)), Some(script.tag()))
    assert_eq(script_tag(tag_to_script(tag3)), Some(script.tag()))
  }

  check("bng3", "bng2", "beng", script_bengali)
  check("dev3", "dev2", "deva", script_devanagari)
  check("gjr3", "gjr2", "gujr", script_gujarati)
  check("gur3", "gur2", "guru", script_gurmukhi)
  check("knd3", "knd2", "knda", script_kannada)
  check("mlm3", "mlm2", "mlym", script_malayalam)
  check("ory3", "ory2", "orya", script_oriya)
  check("tml3", "tml2", "taml", script_tamil)
  check("tel3", "tel2", "telu", script_telugu)
}

///|
/// `test_tag_from_language!`.
// TODO: swap tag and lang
fn test_tag_from_language(tag : String, lang : String) -> Unit raise {
  let tag = lossy(tag)
  let (_, languages) = tags_from_script_and_language(
    None,
    Language::from_str(ascii_lowercase(lang)),
  )
  if !languages.is_empty() {
    assert_eq(languages[0], tag)
  }
}

///|
/// `test_tags!`.
fn test_tags(
  script : Script?,
  lang : String,
  exp_scripts : Array[String],
  exp_langs : Array[String],
) -> Unit raise {
  let (scripts, languages) = tags_from_script_and_language(
    script,
    Language::from_str(lang),
  )
  let exp_scripts = exp_scripts.map(lossy)
  let exp_langs = exp_langs.map(lossy)
  assert_eq(exp_scripts, scripts)
  assert_eq(exp_langs, languages)
}

///|
test "script_from_language_01" {
  test_script_from_language("", "", None)
}

///|
test "script_from_language_02" {
  test_script_from_language("", "en", None)
}

///|
test "script_from_language_03" {
  test_script_from_language("copt", "en", Some(script_coptic))
}

///|
test "script_from_language_04" {
  test_script_from_language("", "x-hbsc", None)
}

///|
test "script_from_language_05" {
  test_script_from_language("copt", "x-hbsc", Some(script_coptic))
}

///|
test "script_from_language_06" {
  test_script_from_language("abc ", "x-hbscabc", None)
}

///|
test "script_from_language_07" {
  test_script_from_language("deva", "x-hbscdeva", None)
}

///|
test "script_from_language_08" {
  test_script_from_language("dev2", "x-hbscdev2", None)
}

///|
test "script_from_language_09" {
  test_script_from_language("dev3", "x-hbscdev3", None)
}

///|
test "script_from_language_10" {
  test_script_from_language("copt", "x-hbotpap0-hbsccopt", None)
}

///|
test "script_from_language_11" {
  test_script_from_language("", "en-x-hbsc", None)
}

///|
test "script_from_language_12" {
  test_script_from_language("copt", "en-x-hbsc", Some(script_coptic))
}

///|
test "script_from_language_13" {
  test_script_from_language("abc ", "en-x-hbscabc", None)
}

///|
test "script_from_language_14" {
  test_script_from_language("deva", "en-x-hbscdeva", None)
}

///|
test "script_from_language_15" {
  test_script_from_language("dev2", "en-x-hbscdev2", None)
}

///|
test "script_from_language_16" {
  test_script_from_language("dev3", "en-x-hbscdev3", None)
}

///|
test "script_from_language_17" {
  test_script_from_language("copt", "en-x-hbotpap0-hbsccopt", None)
}

///|
test "tag_from_language_dflt" {
  test_tag_from_language("dflt", "")
}

///|
test "tag_from_language_ALT" {
  test_tag_from_language("ALT", "alt")
}

///|
test "tag_from_language_ARA" {
  test_tag_from_language("ARA", "ar")
}

///|
test "tag_from_language_AZE" {
  test_tag_from_language("AZE", "az")
}

///|
test "tag_from_language_az_ir" {
  test_tag_from_language("AZE", "az-ir")
}

///|
test "tag_from_language_az_az" {
  test_tag_from_language("AZE", "az-az")
}

///|
test "tag_from_language_ENG" {
  test_tag_from_language("ENG", "en")
}

///|
test "tag_from_language_en_US" {
  test_tag_from_language("ENG", "en_US")
}

///|
test "tag_from_language_CJA" {
  test_tag_from_language("CJA", "cja") // Western Cham
}

///|
test "tag_from_language_CJM" {
  test_tag_from_language("CJM", "cjm") // Eastern Cham
}

///|
test "tag_from_language_ENV" {
  test_tag_from_language("EVN", "eve")
}

///|
test "tag_from_language_HAL" {
  test_tag_from_language("HAL", "cfm") // BCP47 and current ISO639-3 code for Halam/Falam Chin
}

///|
test "tag_from_language_flm" {
  test_tag_from_language("HAL", "flm") // Retired ISO639-3 code for Halam/Falam Chin
}

///|
test "tag_from_language_hy" {
  test_tag_from_language("HYE0", "hy")
}

///|
test "tag_from_language_hyw" {
  test_tag_from_language("HYE", "hyw")
}

///|
test "tag_from_language_bgr" {
  test_tag_from_language("QIN", "bgr") // Bawm Chin
}

///|
test "tag_from_language_cbl" {
  test_tag_from_language("QIN", "cbl") // Bualkhaw Chin
}

///|
test "tag_from_language_cka" {
  test_tag_from_language("QIN", "cka") // Khumi Awa Chin
}

///|
test "tag_from_language_cmr" {
  test_tag_from_language("QIN", "cmr") // Mro-Khimi Chin
}

///|
test "tag_from_language_cnb" {
  test_tag_from_language("QIN", "cnb") // Chinbon Chin
}

///|
test "tag_from_language_cnh" {
  test_tag_from_language("QIN", "cnh") // Hakha Chin
}

///|
test "tag_from_language_cnk" {
  test_tag_from_language("QIN", "cnk") // Khumi Chin
}

///|
test "tag_from_language_cnw" {
  test_tag_from_language("QIN", "cnw") // Ngawn Chin
}

///|
test "tag_from_language_csh" {
  test_tag_from_language("QIN", "csh") // Asho Chin
}

///|
test "tag_from_language_csy" {
  test_tag_from_language("QIN", "csy") // Siyin Chin
}

///|
test "tag_from_language_ctd" {
  test_tag_from_language("QIN", "ctd") // Tedim Chin
}

///|
test "tag_from_language_czt" {
  test_tag_from_language("QIN", "czt") // Zotung Chin
}

///|
test "tag_from_language_dao" {
  test_tag_from_language("QIN", "dao") // Daai Chin
}

///|
test "tag_from_language_htl" {
  test_tag_from_language("QIN", "hlt") // Matu Chin
}

///|
test "tag_from_language_mrh" {
  test_tag_from_language("QIN", "mrh") // Mara Chin
}

///|
test "tag_from_language_pck" {
  test_tag_from_language("QIN", "pck") // Paite Chin
}

///|
test "tag_from_language_sez" {
  test_tag_from_language("QIN", "sez") // Senthang Chin
}

///|
test "tag_from_language_tcp" {
  test_tag_from_language("QIN", "tcp") // Tawr Chin
}

///|
test "tag_from_language_tcz" {
  test_tag_from_language("QIN", "tcz") // Thado Chin
}

///|
test "tag_from_language_yos" {
  test_tag_from_language("QIN", "yos") // Yos, deprecated by IANA in favor of Zou [zom]
}

///|
test "tag_from_language_zom" {
  test_tag_from_language("QIN", "zom") // Zou
}

///|
test "tag_from_language_FAR" {
  test_tag_from_language("FAR", "fa")
}

///|
test "tag_from_language_fa_IR" {
  test_tag_from_language("FAR", "fa_IR")
}

///|
test "tag_from_language_man" {
  test_tag_from_language("MNK", "man")
}

///|
test "tag_from_language_SWA" {
  test_tag_from_language("SWA", "aii") // Swadaya Aramaic
}

///|
test "tag_from_language_SYR" {
  test_tag_from_language("SYR", "syr") // Syriac [macrolanguage]
}

///|
test "tag_from_language_amw" {
  test_tag_from_language("SYR", "amw") // Western Neo-Aramaic
}

///|
test "tag_from_language_cld" {
  test_tag_from_language("SYR", "cld") // Chaldean Neo-Aramaic
}

///|
test "tag_from_language_syc" {
  test_tag_from_language("SYR", "syc") // Classical Syriac
}

///|
test "tag_from_language_TUA" {
  test_tag_from_language("TUA", "tru") // Turoyo Aramaic
}

///|
test "tag_from_language_zh" {
  test_tag_from_language("ZHS", "zh") // Chinese
}

///|
test "tag_from_language_zh_cn" {
  test_tag_from_language("ZHS", "zh-cn") // Chinese (China)
}

///|
test "tag_from_language_zh_sg" {
  test_tag_from_language("ZHS", "zh-sg") // Chinese (Singapore)
}

///|
test "tag_from_language_zh_mo" {
  test_tag_from_language("ZHTM", "zh-mo") // Chinese (Macao)
}

///|
test "tag_from_language_zh_hant_mo" {
  test_tag_from_language("ZHTM", "zh-hant-mo") // Chinese (Macao)
}

///|
test "tag_from_language_zh_hans_mo" {
  test_tag_from_language("ZHS", "zh-hans-mo") // Chinese (Simplified, Macao)
}

///|
test "tag_from_language_ZHH" {
  test_tag_from_language("ZHH", "zh-HK") // Chinese (Hong Kong)
}

///|
test "tag_from_language_zh_HanT_hK" {
  test_tag_from_language("ZHH", "zH-HanT-hK") // Chinese (Hong Kong)
}

///|
test "tag_from_language_zh_HanS_hK" {
  test_tag_from_language("ZHS", "zH-HanS-hK") // Chinese (Simplified, Hong Kong)
}

///|
test "tag_from_language_zh_tw" {
  test_tag_from_language("ZHT", "zh-tw") // Chinese (Taiwan)
}

///|
test "tag_from_language_ZHS" {
  test_tag_from_language("ZHS", "zh-Hans") // Chinese (Simplified)
}

///|
test "tag_from_language_ZHT" {
  test_tag_from_language("ZHT", "zh-Hant") // Chinese (Traditional)
}

///|
test "tag_from_language_zh_xx" {
  test_tag_from_language("ZHS", "zh-xx") // Chinese (Other)
}

///|
test "tag_from_language_zh_Hans_TW" {
  test_tag_from_language("ZHS", "zh-Hans-TW")
}

///|
test "tag_from_language_yue" {
  test_tag_from_language("ZHH", "yue")
}

///|
test "tag_from_language_yue_Hant" {
  test_tag_from_language("ZHH", "yue-Hant")
}

///|
test "tag_from_language_yue_Hans" {
  test_tag_from_language("ZHS", "yue-Hans")
}

///|
test "tag_from_language_ABC" {
  test_tag_from_language("ABC", "abc")
}

///|
test "tag_from_language_ABCD" {
  test_tag_from_language("ABCD", "x-hbotabcd")
}

///|
test "tag_from_language_asdf_asdf_wer_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "asdf-asdf-wer-x-hbotabc-zxc")
}

///|
test "tag_from_language_asdf_asdf_wer_x_hbotabc" {
  test_tag_from_language("ABC", "asdf-asdf-wer-x-hbotabc")
}

///|
test "tag_from_language_asdf_asdf_wer_x_hbotabcd" {
  test_tag_from_language("ABCD", "asdf-asdf-wer-x-hbotabcd")
}

///|
test "tag_from_language_asdf_asdf_wer_x_hbot_zxc" {
  test_tag_from_language("dflt", "asdf-asdf-wer-x-hbot-zxc")
}

///|
test "tag_from_language_xy" {
  test_tag_from_language("dflt", "xy")
}

///|
test "tag_from_language_xyz" {
  test_tag_from_language("XYZ", "xyz") // Unknown ISO 639-3
}

///|
test "tag_from_language_xyz_qw" {
  test_tag_from_language("XYZ", "xyz-qw") // Unknown ISO 639-3
}

///|
test "tag_from_language__fonipa" {
  test_tag_from_language("IPPH", "-fonipa")
}

///|
test "tag_from_language_en_fonipax" {
  test_tag_from_language("ENG", "en-fonipax")
}

///|
test "tag_from_language_en_x_fonipa" {
  test_tag_from_language("ENG", "en-x-fonipa")
}

///|
test "tag_from_language_en_a_fonipa" {
  test_tag_from_language("ENG", "en-a-fonipa")
}

///|
test "tag_from_language_en_a_qwe_b_fonipa" {
  test_tag_from_language("ENG", "en-a-qwe-b-fonipa")
}

///|
test "tag_from_language_en_fonipa" {
  test_tag_from_language("IPPH", "en-fonipa")
}

///|
test "tag_from_language_en_fonipax_fonipa" {
  test_tag_from_language("IPPH", "en-fonipax-fonipa")
}

///|
test "tag_from_language_rm_ch_fonipa_sursilv_x_foobar" {
  test_tag_from_language("IPPH", "rm-CH-fonipa-sursilv-x-foobar")
}

///|
test "tag_from_language_IPPH" {
  test_tag_from_language("IPPH", "und-fonipa")
}

///|
test "tag_from_language_zh_fonipa" {
  test_tag_from_language("IPPH", "zh-fonipa")
}

///|
test "tag_from_language_en_fonnapa" {
  test_tag_from_language("APPH", "en-fonnapa")
}

///|
test "tag_from_language_chr_fonnapa" {
  test_tag_from_language("APPH", "chr-fonnapa")
}

///|
test "tag_from_language_APPH" {
  test_tag_from_language("APPH", "und-fonnapa")
}

///|
test "tag_from_language_ka_geok" {
  test_tag_from_language("KGE", "ka-Geok")
}

///|
test "tag_from_language_KGE" {
  test_tag_from_language("KGE", "und-Geok")
}

///|
test "tag_from_language_IRT" {
  test_tag_from_language("IRT", "ga-Latg")
}

///|
test "tag_from_language_MOL" {
  test_tag_from_language("MOL", "ro-MD")
}

///|
test "tag_from_language_PGR" {
  test_tag_from_language("PGR", "el-polyton")
}

///|
test "tag_from_language_el_CY_polyton" {
  test_tag_from_language("PGR", "el-CY-polyton")
}

///|
test "tag_from_language_aii_Syre" {
  test_tag_from_language("SYRE", "aii-Syre")
}

///|
test "tag_from_language_de_Syre" {
  test_tag_from_language("SYRE", "de-Syre")
}

///|
test "tag_from_language_syr_Syre" {
  test_tag_from_language("SYRE", "syr-Syre")
}

///|
test "tag_from_language_und_Syre" {
  test_tag_from_language("SYRE", "und-Syre")
}

///|
test "tag_from_language_aii_Syrj" {
  test_tag_from_language("SYRJ", "aii-Syrj")
}

///|
test "tag_from_language_de_Syrj" {
  test_tag_from_language("SYRJ", "de-Syrj")
}

///|
test "tag_from_language_syr_Syrj" {
  test_tag_from_language("SYRJ", "syr-Syrj")
}

///|
test "tag_from_language_SYRJ" {
  test_tag_from_language("SYRJ", "und-Syrj")
}

///|
test "tag_from_language_aii_Syrn" {
  test_tag_from_language("SYRN", "aii-Syrn")
}

///|
test "tag_from_language_de_Syrn" {
  test_tag_from_language("SYRN", "de-Syrn")
}

///|
test "tag_from_language_syr_Syrn" {
  test_tag_from_language("SYRN", "syr-Syrn")
}

///|
test "tag_from_language_SYRN" {
  test_tag_from_language("SYRN", "und-Syrn")
}

///|
test "tag_from_language_fa_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "fa-x-hbotabc-zxc")
}

///|
test "tag_from_language_fa_ir_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "fa-ir-x-hbotabc-zxc")
}

///|
test "tag_from_language_zh_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "zh-x-hbotabc-zxc")
}

///|
test "tag_from_language_zh_cn_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "zh-cn-x-hbotabc-zxc")
}

///|
test "tag_from_language_zh_xy_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "zh-xy-x-hbotabc-zxc")
}

///|
test "tag_from_language_xyz_xy_x_hbotabc_zxc" {
  test_tag_from_language("ABC", "xyz-xy-x-hbotabc-zxc")
}

///|
test "tag_from_language_ar_aao" {
  test_tag_from_language("ARA", "ar-aao")
}

///|
test "tag_from_language_art_lojban" {
  test_tag_from_language("JBO", "art-lojban")
}

///|
test "tag_from_language_kok_gom" {
  test_tag_from_language("KOK", "kok-gom")
}

///|
test "tag_from_language_i_lux" {
  test_tag_from_language("LTZ", "i-lux")
}

///|
test "tag_from_language_drh" {
  test_tag_from_language("MNG", "drh")
}

///|
test "tag_from_language_ar_ary1" {
  test_tag_from_language("MOR", "ar-ary")
}

///|
test "tag_from_language_ar_ary_DZ" {
  test_tag_from_language("MOR", "ar-ary-DZ")
}

///|
test "tag_from_language_no_bok" {
  test_tag_from_language("NOR", "no-bok")
}

///|
test "tag_from_language_no_nyn" {
  test_tag_from_language("NYN", "no-nyn")
}

///|
test "tag_from_language_i_hak" {
  test_tag_from_language("ZHS", "i-hak")
}

///|
test "tag_from_language_zh_guoyu" {
  test_tag_from_language("ZHS", "zh-guoyu")
}

///|
test "tag_from_language_zh_min" {
  test_tag_from_language("ZHS", "zh-min")
}

///|
test "tag_from_language_zh_min_nan" {
  test_tag_from_language("ZHS", "zh-min-nan")
}

///|
test "tag_from_language_zh_xiang" {
  test_tag_from_language("ZHS", "zh-xiang")
}

///|
test "tag_from_language_als" {
  test_tag_from_language("SQI", "als")
}

///|
test "tag_from_language_far" {
  test_tag_from_language("dflt", "far")
}

///|
test "tag_from_language_ar_001" {
  test_tag_from_language("ARA", "ar-001")
}

///|
test "tag_from_language_invalid" {
  test_tag_from_language("TRK", "tr@foo=bar")
}

///|
test "tag_full_en" {
  test_tags(None, "en", [], ["ENG"])
}

///|
test "tag_full_en_x_hbscdflt" {
  test_tags(None, "en-x-hbscdflt", ["DFLT"], ["ENG"])
}

///|
test "tag_full_en_latin" {
  test_tags(Some(script_latin), "en", ["latn"], ["ENG"])
}

///|
test "tag_full_und_fonnapa" {
  test_tags(None, "und-fonnapa", [], ["APPH"])
}

///|
test "tag_full_en_fonnapa" {
  test_tags(None, "en-fonnapa", [], ["APPH"])
}

///|
test "tag_full_x_hbot1234_hbsc5678" {
  test_tags(None, "x-hbot1234-hbsc5678", ["5678"], ["1234"])
}

///|
test "tag_full_x_hbsc5678_hbot1234" {
  test_tags(None, "x-hbsc5678-hbot1234", ["5678"], ["1234"])
}

///|
test "tag_full_ml" {
  test_tags(Some(script_malayalam), "ml", ["mlm3", "mlm2", "mlym"], [
    "MAL", "MLR",
  ])
}

///|
test "tag_full_xyz" {
  test_tags(None, "xyz", [], ["XYZ"])
}

///|
test "tag_full_xy" {
  test_tags(None, "xy", [], [])
}
