// Port of rustybuzz 0.20.1 `src/hb/tag.rs`.
//
// `ThreeTags` (`SmallVec<[hb_tag_t; 3]>`) is an `Array[@otf.Tag]`;
// `left()`/`is_full()` are relative to the inline capacity 3
// (`three_tags_left`/`three_tags_is_full`).
//
// Rust string operations are byte based. Languages are converted to byte
// strings (`byte_string`: one char per UTF-8 byte) so that indices, lengths
// and comparisons match Rust's `str` semantics (languages are ASCII in
// practice, where this is the identity).

///|
/// `SmallVecExt::left`.
fn three_tags_left(tags : Array[@otf.Tag]) -> Int {
  3 - tags.length()
}

///|
/// `SmallVecExt::is_full`.
fn three_tags_is_full(tags : Array[@otf.Tag]) -> Bool {
  tags.length() == 3
}

///|
/// The UTF-8 bytes of `s`, one char per byte.
fn byte_string(s : String) -> String {
  let mut ascii = true
  for c in s {
    if c.to_int() >= 0x80 {
      ascii = false
      break
    }
  }
  if ascii {
    return s
  }
  let buf = StringBuilder()
  for b in @utf8.encode(s) {
    buf.write_char(b.to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// `u8::is_ascii_alphanumeric`.
fn is_ascii_alphanumeric(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit()
}

///|
/// `bytes.get(i)` of a byte string.
fn byte_at(s : StringView, i : Int) -> Char? {
  if i >= 0 && i < s.length() {
    Some(s[i].to_int().unsafe_to_char())
  } else {
    None
  }
}

///|
/// `Tag::from_bytes_lossy` of a byte string.
fn tag_from_bytes_lossy(s : StringView) -> @otf.Tag {
  let bytes = Bytes::makei(s.length().min(4), i => s[i].to_byte())
  @otf.Tag::from_bytes_lossy(bytes[:])
}

///|
/// Converts an `Script` and an `Language` to script and language tags.
fn tags_from_script_and_language(
  script : Script?,
  language : Language?,
) -> (Array[@otf.Tag], Array[@otf.Tag]) {
  let mut needs_script = true
  let scripts = Array(capacity=3)
  let languages = Array(capacity=3)
  let mut private_use_subtag : StringView? = None
  let mut prefix : StringView = ""
  if language is Some(language) {
    let language = byte_string(language.as_str())
    if language.has_prefix("x-") {
      private_use_subtag = Some(language)
    } else {
      let bytes = language
      let mut i = 1
      while i < bytes.length() {
        if byte_at(bytes, i - 1) == Some('-') &&
          byte_at(bytes, i + 1) == Some('-') {
          if byte_at(bytes, i) == Some('x') {
            private_use_subtag = Some(language[i:])
            if prefix.is_empty() {
              prefix = language[:i - 1]
            }
            break
          } else {
            prefix = language[:i - 1]
          }
        }
        i += 1
      }
      if prefix.is_empty() {
        prefix = language[:i]
      }
    }
    needs_script = !parse_private_use_subtag(
      private_use_subtag, "-hbsc", to_ascii_lowercase, scripts,
    )
    let needs_language = !parse_private_use_subtag(
      private_use_subtag, "-hbot", to_ascii_uppercase, languages,
    )
    if needs_language {
      if Language::from_str(prefix.to_owned()) is Some(prefix) {
        tags_from_language(prefix, languages)
      }
    }
  }
  if needs_script {
    all_tags_from_script(script, scripts)
  }
  (scripts, languages)
}

///|
fn to_ascii_lowercase(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn to_ascii_uppercase(c : Char) -> Char {
  if c >= 'a' && c <= 'z' {
    (c.to_int() - 32).unsafe_to_char()
  } else {
    c
  }
}

///|
fn parse_private_use_subtag(
  private_use_subtag : StringView?,
  prefix : StringView,
  normalize : (Char) -> Char,
  tags : Array[@otf.Tag],
) -> Bool {
  let private_use_subtag = match private_use_subtag {
    Some(v) => v
    None => return false
  }
  let private_use_subtag = match private_use_subtag.find(prefix) {
    Some(idx) => private_use_subtag[idx + prefix.length():]
    None => return false
  }
  let tag = StringBuilder()
  for k in 0..<private_use_subtag.length().min(4) {
    let c = private_use_subtag[k].to_int().unsafe_to_char()
    if is_ascii_alphanumeric(c) {
      tag.write_char(normalize(c))
    } else {
      break
    }
  }
  let tag = tag.to_string()
  if tag.is_empty() {
    return false
  }
  let mut tag = tag_from_bytes_lossy(tag)

  // Some bits magic from HarfBuzz...
  if (tag.as_u32() & 0xDFDFDFDF) == default_script_tag().as_u32() {
    tag = @otf.Tag(tag.as_u32() ^ (0xDFDFDFDF : UInt).lnot())
  }
  tags.push(tag)
  true
}

///|
fn lang_cmp(s1 : StringView, s2 : StringView) -> Int {
  let da = s1.find("-").unwrap_or(s1.length())
  let db = s2.find("-").unwrap_or(s2.length())
  let n = da.max(db)
  let ea = n.min(s1.length())
  let eb = n.min(s2.length())
  s1[:ea].lexical_compare(s2[:eb])
}

///|
fn tags_from_language(language : Language, tags : Array[@otf.Tag]) -> Unit {
  let language = language.as_str()

  // Check for matches of multiple subtags.
  if tags_from_complex_language(language, tags) {
    return
  }
  let mut sublang : StringView = language

  // Find a language matching in the first component.
  if language.find("-") is Some(i) {
    // If there is an extended language tag, use it.
    if language.length() >= 6 {
      let extlang = match language[i + 1:].find("-") {
        Some(idx) => idx == 3
        None => language.length() - i - 1 == 3
      }
      if extlang &&
        language[i + 1].to_int().unsafe_to_char().is_ascii_alphabetic() {
        sublang = language[i + 1:]
      }
    }
  }
  let languages = open_type_languages
  if languages.binary_search_by(v => lang_cmp(v.language, sublang)) is Ok(idx) {
    let mut idx = idx
    while idx != 0 && languages[idx].language == languages[idx - 1].language {
      idx -= 1
    }
    let len = three_tags_left(tags).min(languages.length() - idx - 1)
    for i in 0..<len {
      if languages[idx + i].language != languages[idx].language {
        break
      }
      if languages[idx + i].tag.is_null() {
        break
      }
      if three_tags_is_full(tags) {
        break
      }
      tags.push(languages[idx + i].tag)
    }
    return
  }
  if language.length() == 3 {
    tags.push(tag_to_uppercase(tag_from_bytes_lossy(language)))
  }
}

///|
fn all_tags_from_script(script : Script?, tags : Array[@otf.Tag]) -> Unit {
  if script is Some(script) {
    if new_tag_from_script(script) is Some(tag) {
      // Script::Myanmar maps to 'mym2', but there is no 'mym3'.
      if tag != @otf.Tag::from_bytes(b"mym2") {
        let tag3 = tag.to_bytes().to_array()
        tag3[3] = b'3'
        tags.push(@otf.Tag::from_bytes(Bytes::from_array(tag3)))
      }
      if !three_tags_is_full(tags) {
        tags.push(tag)
      }
    }
    if !three_tags_is_full(tags) {
      tags.push(old_tag_from_script(script))
    }
  }
}

///|
fn new_tag_from_script(script : Script) -> @otf.Tag? {
  match script {
    s if s == script_bengali => Some(@otf.Tag::from_bytes(b"bng2"))
    s if s == script_devanagari => Some(@otf.Tag::from_bytes(b"dev2"))
    s if s == script_gujarati => Some(@otf.Tag::from_bytes(b"gjr2"))
    s if s == script_gurmukhi => Some(@otf.Tag::from_bytes(b"gur2"))
    s if s == script_kannada => Some(@otf.Tag::from_bytes(b"knd2"))
    s if s == script_malayalam => Some(@otf.Tag::from_bytes(b"mlm2"))
    s if s == script_oriya => Some(@otf.Tag::from_bytes(b"ory2"))
    s if s == script_tamil => Some(@otf.Tag::from_bytes(b"tml2"))
    s if s == script_telugu => Some(@otf.Tag::from_bytes(b"tel2"))
    s if s == script_myanmar => Some(@otf.Tag::from_bytes(b"mym2"))
    _ => None
  }
}

///|
fn old_tag_from_script(script : Script) -> @otf.Tag {
  // This seems to be accurate as of end of 2012.
  match script {
    // Katakana and Hiragana both map to 'kana'.
    s if s == script_hiragana => @otf.Tag::from_bytes(b"kana")

    // Spaces at the end are preserved, unlike ISO 15924.
    s if s == script_lao => @otf.Tag::from_bytes(b"lao ")
    s if s == script_yi => @otf.Tag::from_bytes(b"yi  ")
    // Unicode-5.0 additions.
    s if s == script_nko => @otf.Tag::from_bytes(b"nko ")
    // Unicode-5.1 additions.
    s if s == script_vai => @otf.Tag::from_bytes(b"vai ")

    // Else, just change first char to lowercase and return.
    _ => @otf.Tag(script.tag().as_u32() | 0x20000000)
  }
}
