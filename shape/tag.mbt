// Port of rustybuzz 0.20.1 `src/hb/tag.rs`.
// TODO(stub): language tags (tag_table) are not ported yet.

///|
/// Converts an `Script` and an `Language` to script and language tags.
fn tags_from_script_and_language(
  script : Script?,
  _language : Language?,
) -> (Array[@otf.Tag], Array[@otf.Tag]) {
  let scripts = []
  let languages = []
  all_tags_from_script(script, scripts)
  (scripts, languages)
}

///|
fn all_tags_from_script(script : Script?, tags : Array[@otf.Tag]) -> Unit {
  if script is Some(script) {
    if new_tag_from_script(script) is Some(tag) {
      // Script::Myanmar maps to 'mym2', but there is no 'mym3'.
      if tag != @otf.Tag::from_bytes(b"mym2") {
        let tag3 = @otf.Tag(
          (tag.as_u32() & 0xFFFFFF00) | '3'.to_int().reinterpret_as_uint(),
        )
        tags.push(tag3)
      }
      if tags.length() < 3 {
        tags.push(tag)
      }
    }
    if tags.length() < 3 {
      tags.push(old_tag_from_script(script))
    }
  }
}

///|
fn new_tag_from_script(script : Script) -> @otf.Tag? {
  match tag_string(script.0) {
    "Beng" => Some(@otf.Tag::from_bytes(b"bng2"))
    "Deva" => Some(@otf.Tag::from_bytes(b"dev2"))
    "Gujr" => Some(@otf.Tag::from_bytes(b"gjr2"))
    "Guru" => Some(@otf.Tag::from_bytes(b"gur2"))
    "Knda" => Some(@otf.Tag::from_bytes(b"knd2"))
    "Mlym" => Some(@otf.Tag::from_bytes(b"mlm2"))
    "Orya" => Some(@otf.Tag::from_bytes(b"ory2"))
    "Taml" => Some(@otf.Tag::from_bytes(b"tml2"))
    "Telu" => Some(@otf.Tag::from_bytes(b"tel2"))
    "Mymr" => Some(@otf.Tag::from_bytes(b"mym2"))
    _ => None
  }
}

///|
fn old_tag_from_script(script : Script) -> @otf.Tag {
  // This seems to be accurate as of end of 2012.
  match tag_string(script.0) {
    // Katakana and Hiragana both map to 'kana'.
    "Hira" => @otf.Tag::from_bytes(b"kana")

    // Spaces at the end are preserved, unlike ISO 15924.
    "Laoo" => @otf.Tag::from_bytes(b"lao ")
    "Yiii" => @otf.Tag::from_bytes(b"yi  ")
    // Unicode-5.0 additions.
    "Nkoo" => @otf.Tag::from_bytes(b"nko ")
    // Unicode-5.1 additions.
    "Vaii" => @otf.Tag::from_bytes(b"vai ")

    // Else, just change first char to lowercase and return.
    _ => @otf.Tag(script.tag().as_u32() | 0x20000000)
  }
}
