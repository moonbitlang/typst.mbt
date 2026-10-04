// Port of skrifa 0.42.1 `src/outline/hint_reliant.rs`: name detection for
// fonts that require hinting to be run for correct contours (FreeType calls
// these "tricky" fonts).

///|
fn require_interpreter(font : FontRef) -> Bool {
  is_hint_reliant_by_name(font) ||
  matches_hint_reliant_id_list(FontId::from_font(font))
}

///|
const MAX_HINT_RELIANT_NAME_LEN : Int = 18

///|
fn is_hint_reliant_by_name(font : FontRef) -> Bool {
  let strings = font.localized_strings(@read_fonts.NAME_ID_FAMILY_NAME)
  guard @read_fonts.english_or_first(strings) is Some(name) else {
    return false
  }
  let chars = name.chars()
  if chars.length() > MAX_HINT_RELIANT_NAME_LEN {
    return false
  }
  // `ch as u8`
  let buf = Bytes::makei(chars.length(), i => {
    (chars[i].to_int() & 0xFF).to_byte()
  })
  // `core::str::from_utf8(&buf[..len]).unwrap_or_default()`
  let name = if is_valid_utf8(buf) { buf[:] } else { b""[:] }
  matches_hint_reliant_name_list(name)
}

///|
fn is_valid_utf8(b : Bytes) -> Bool {
  try @utf8.decode(b, ignore_bom=false) catch {
    _ => return false
  } noraise {
    _ => true
  }
}

///|
/// Is this name on the list of fonts that require hinting?
fn matches_hint_reliant_name_list(name : BytesView) -> Bool {
  let name = skip_pdf_random_tag(name)
  for tricky_name in hint_reliant_names[:] {
    // FreeType uses strstr(name, tricky_name) so we use contains() to
    // match behavior.
    if bytes_contains(name, tricky_name) {
      return true
    }
  }
  false
}

///|
fn bytes_contains(hay : BytesView, needle : String) -> Bool {
  let n = needle.length()
  if n == 0 {
    return true
  }
  for i in 0..<(hay.length() - n + 1) {
    let mut ok = true
    for j in 0..<n {
      if hay[i + j].to_int() != needle[j].to_int() {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
  }
  false
}

///|
/// Fonts embedded in PDFs add random prefixes. Strip these
/// for tricky font comparison purposes.
fn skip_pdf_random_tag(name : BytesView) -> BytesView {
  // Random tag is 6 uppercase letters followed by a +
  if name.length() < 8 || name[6] != b'+' {
    return name
  }
  for i in 0..<6 {
    if !(name[i] >= b'A' && name[i] <= b'Z') {
      return name
    }
  }
  name[7:]
}

///|
let hint_reliant_names : ReadOnlyArray[String] = [
  "cpop", "DFGirl-W6-WIN-BF", "DFGothic-EB", "DFGyoSho-Lt", "DFHei", "DFHSGothic-W5",
  "DFHSMincho-W3", "DFHSMincho-W7", "DFKaiSho-SB", "DFKaiShu", "DFKai-SB", "DFMing",
  "DLC", "HuaTianKaiTi?", "HuaTianSongTi?", "Ming(for ISO10646)", "MingLiU", "MingMedium",
  "PMingLiU", "MingLi43",
]

///|
priv struct TableId {
  checksum : UInt
  len : UInt
} derive(Eq)

///|
fn TableId::from_font_and_tag(font : FontRef, tag : String) -> TableId {
  match font.data_for_tag(tag) {
    Some(data) =>
      // Note: FreeType always just computes the checksum
      {
        checksum: @read_fonts.compute_checksum(data.as_bytes()),
        len: data.len().reinterpret_as_uint(),
      }
    None => { checksum: 0, len: 0, }
  }
}

///|
priv struct FontId {
  cvt : TableId
  fpgm : TableId
  prep : TableId
} derive(Eq)

///|
fn FontId::from_font(font : FontRef) -> FontId {
  {
    cvt: TableId::from_font_and_tag(font, "cvt "),
    fpgm: TableId::from_font_and_tag(font, "fpgm"),
    prep: TableId::from_font_and_tag(font, "prep"),
  }
}

///|
/// Checks for fonts that require hinting based on the length and checksum
/// of the cvt, fpgm and prep tables.
fn matches_hint_reliant_id_list(font_id : FontId) -> Bool {
  for id in hint_reliant_ids[:] {
    let (a, b, c, d, e, f) = id
    if font_id ==
      {
        cvt: { checksum: a, len: b, },
        fpgm: { checksum: c, len: d, },
        prep: { checksum: e, len: f, },
      } {
      return true
    }
  }
  false
}

///|
/// (cvt checksum, cvt len, fpgm checksum, fpgm len, prep checksum, prep len)
let hint_reliant_ids : ReadOnlyArray[(UInt, UInt, UInt, UInt, UInt, UInt)] = [
  (0x05BCF058U, 0x000002E4U, 0x28233BF1U, 0x000087C4U, 0xA344A1EAU, 0x000001E1U),
  (0x05BCF058U, 0x000002E4U, 0x28233BF1U, 0x000087C4U, 0xA344A1EBU, 0x000001E1U),
  (0x12C3EBB2U, 0x00000350U, 0xB680EE64U, 0x000087A7U, 0xCE939563U, 0x00000758U),
  (0x11E5EAD4U, 0x00000350U, 0xCE5956E9U, 0x0000BC85U, 0x8272F416U, 0x00000045U),
  (0x1257EB46U, 0x00000350U, 0xF699D160U, 0x0000715FU, 0xD222F568U, 0x000003BCU),
  (0x1262EB4EU, 0x00000350U, 0xE86A5D64U, 0x00007940U, 0x7850F729U, 0x000005FFU),
  (0x122DEB0AU, 0x00000350U, 0x3D16328AU, 0x0000859BU, 0xA93FC33BU, 0x000002CBU),
  (0x125FEB26U, 0x00000350U, 0xA5ACC982U, 0x00007EE1U, 0x90999196U, 0x0000041FU),
  (0x11E5EAD4U, 0x00000350U, 0x5A30CA3BU, 0x00009063U, 0x13A42602U, 0x0000007EU),
  (0x11E5EAD4U, 0x00000350U, 0xA6E78C01U, 0x00008998U, 0x13A42602U, 0x0000007EU),
  (0x11E5EAD4U, 0x00000360U, 0x9DB282B2U, 0x0000C06EU, 0x53E6D7CAU, 0x00000082U),
  (0x1243EB18U, 0x00000350U, 0xBA0A8C30U, 0x000074ADU, 0xF3D83409U, 0x0000037BU),
  (0x07DCF546U, 0x00000308U, 0x40FE7C90U, 0x00008E2AU, 0x608174B5U, 0x0000007AU),
  (0xEB891238U, 0x00000308U, 0xD2E4DCD4U, 0x0000676FU, 0x8EA5F293U, 0x000003B8U),
  (0xFFFBFFFCU, 0x00000008U, 0x9C9E48B8U, 0x0000BEA2U, 0x70020112U, 0x00000008U),
  (0xFFFBFFFCU, 0x00000008U, 0x0A5A0483U, 0x00017C39U, 0x70020112U, 0x00000008U),
  (0x00000000U, 0x00000000U, 0x40C92555U, 0x000000E5U, 0xA39B58E3U, 0x0000117CU),
  (0x00000000U, 0x00000000U, 0x33C41652U, 0x000000E5U, 0x26D6C52AU, 0x00000F6AU),
  (0x00000000U, 0x00000000U, 0x6DB1651DU, 0x0000019DU, 0x6C6E4B03U, 0x00002492U),
  (0x00000000U, 0x00000000U, 0x40C92555U, 0x000000E5U, 0xDE51FAD0U, 0x0000117CU),
  (0x00000000U, 0x00000000U, 0x85E47664U, 0x000000E5U, 0xA6C62831U, 0x00001CAAU),
  (0x00000000U, 0x00000000U, 0x2D891CFDU, 0x0000019DU, 0xA0604633U, 0x00001DE8U),
  (0x00000000U, 0x00000000U, 0x40AA774CU, 0x000001CBU, 0x9B5CAA96U, 0x00001F9AU),
  (0x00000000U, 0x00000000U, 0x0D3DE9CBU, 0x00000141U, 0xD4127766U, 0x00002280U),
  (0x00000000U, 0x00000000U, 0x4A692698U, 0x000001F0U, 0x340D4346U, 0x00001FCAU),
  (0x00000000U, 0x00000000U, 0xCD34C604U, 0x00000166U, 0x6CF31046U, 0x000022B0U),
  (0x00000000U, 0x00000000U, 0x5DA75315U, 0x0000019DU, 0x40745A5FU, 0x000022E0U),
  (0x00000000U, 0x00000000U, 0xF055FC48U, 0x000001C2U, 0x3900DED3U, 0x00001E18U),
  (0x00170003U, 0x00000060U, 0xDBB4306EU, 0x000058AAU, 0xD643482AU, 0x00000035U),
  (0x1269EB58U, 0x00000350U, 0x5CD5957AU, 0x00006A4EU, 0xF758323AU, 0x00000380U),
  (0x122FEB0BU, 0x00000350U, 0x7F10919AU, 0x000070A9U, 0x7CD7E7B7U, 0x0000025CU),
]
