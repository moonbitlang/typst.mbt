// Port of the castable value types of `typst-library/src/text/lang.rs`
// (`Lang`, `Region`, `WritingScript`, `Locale`). Translations
// (`localized_str`) are not ported here.

///|
/// An identifier for a natural language: an ISO 639-1/2/3 code, stored
/// lowercased.
pub(all) struct Lang(String) derive(Eq, Hash, Compare, Debug)

///|
pub let lang_arabic : Lang = Lang("ar")

///|
pub let lang_divehi : Lang = Lang("dv")

///|
pub let lang_english : Lang = Lang("en")

///|
pub let lang_hebrew : Lang = Lang("he")

///|
pub let lang_kashmiri : Lang = Lang("ks")

///|
pub let lang_pashto : Lang = Lang("ps")

///|
pub let lang_persian : Lang = Lang("fa")

///|
pub let lang_punjabi : Lang = Lang("pa")

///|
pub let lang_sindhi : Lang = Lang("sd")

///|
pub let lang_urdu : Lang = Lang("ur")

///|
pub let lang_uyghur : Lang = Lang("ug")

///|
pub let lang_yiddish : Lang = Lang("yi")

///|
/// Return the language code as an all lowercase string slice.
pub fn Lang::as_str(self : Lang) -> String {
  self.0
}

///|
/// The default direction for the language.
pub fn Lang::dir(self : Lang) -> Dir {
  if [
      lang_arabic, lang_divehi, lang_persian, lang_hebrew, lang_kashmiri, lang_punjabi,
      lang_pashto, lang_sindhi, lang_uyghur, lang_urdu, lang_yiddish,
    ].contains(self) {
    RTL
  } else {
    LTR
  }
}

///|
/// Whether all characters of the string are ASCII.
fn is_ascii_str(s : String) -> Bool {
  s.iter().all(c => c.to_int() < 0x80)
}

///|
/// Construct a language from a two- or three-byte ISO 639-1/2/3 code.
pub fn Lang::from_str(iso : String) -> Lang raise HintedError {
  let len = @syntax.utf8_len(iso)
  if len >= 2 && len <= 3 && is_ascii_str(iso) {
    Lang(iso.to_lower())
  } else {
    bail("expected two or three letter language code (ISO 639-1/2/3)")
  }
}

///|
pub impl Reflect for Lang with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for Lang with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for Lang with fn castable(v) {
  str_castable(v)
}

///|
pub impl IntoValue for Lang with fn into_value(self) {
  Str(self.as_str())
}

///|
pub impl FromValue for Lang with fn from_value(v) {
  let string : String = (FromValue::from_value(v) : String)
  Lang::from_str(string) catch {
    HintedError(err) => {
      match string.find("-") {
        Some(i) => {
          let lang = string.unsafe_substring(start=0, end=i)
          let region = string.unsafe_substring(start=i + 1, end=string.length())
          let lang_ok = try Lang::from_str(lang) catch {
            _ => false
          } noraise {
            _ => true
          }
          let region_ok = try Region::from_str(region) catch {
            _ => false
          } noraise {
            _ => true
          }
          if lang_ok && region_ok {
            err.hint(
              "you should leave only \"\{lang}\" in the `lang` parameter and specify \"\{region}\" in the `region` parameter",
            )
          }
        }
        None => ()
      }
      raise HintedError(err)
    }
  }
}

///|
/// An identifier for a region somewhere in the world: an ISO 3166-1 alpha-2
/// code, stored uppercased.
pub(all) struct Region(String) derive(Eq, Hash, Compare, Debug)

///|
/// Return the region code as an all uppercase string slice.
pub fn Region::as_str(self : Region) -> String {
  self.0
}

///|
/// Construct a region from its two-byte ISO 3166-1 alpha-2 code.
pub fn Region::from_str(iso : String) -> Region raise HintedError {
  if @syntax.utf8_len(iso) == 2 && is_ascii_str(iso) {
    Region(iso.to_upper())
  } else {
    bail("expected two letter region code (ISO 3166-1 alpha-2)")
  }
}

///|
pub impl Reflect for Region with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for Region with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for Region with fn castable(v) {
  str_castable(v)
}

///|
pub impl IntoValue for Region with fn into_value(self) {
  Str(self.as_str())
}

///|
pub impl FromValue for Region with fn from_value(v) {
  Region::from_str((FromValue::from_value(v) : String))
}

///|
/// An ISO 15924-type script identifier, stored lowercased.
pub(all) struct WritingScript(String) derive(Eq, Hash, Compare, Debug)

///|
/// Return the script as an all lowercase string slice.
pub fn WritingScript::as_str(self : WritingScript) -> String {
  self.0
}

///|
/// Construct a script from its ISO 15924 code.
pub fn WritingScript::from_str(iso : String) -> WritingScript raise HintedError {
  let len = @syntax.utf8_len(iso)
  if len >= 3 && len <= 4 && is_ascii_str(iso) {
    WritingScript(iso.to_lower())
  } else {
    bail("expected three or four letter script code (ISO 15924 or 'math')")
  }
}

///|
pub impl Reflect for WritingScript with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for WritingScript with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for WritingScript with fn castable(v) {
  str_castable(v)
}

///|
pub impl IntoValue for WritingScript with fn into_value(self) {
  Str(self.as_str())
}

///|
pub impl FromValue for WritingScript with fn from_value(v) {
  WritingScript::from_str((FromValue::from_value(v) : String))
}

///|
/// A locale consisting of a language and an optional region.
pub(all) struct Locale {
  lang : Lang
  region : Region?
} derive(Eq, Hash, Compare, Debug)

///|
pub fn Locale::new(lang : Lang, region : Region?) -> Locale {
  { lang, region, }
}

///|
pub impl Default for Locale with fn default() {
  Locale::new(lang_english, None)
}

///|
pub fn Locale::get_in(styles : StyleChain) -> Locale {
  Locale::new(TextElem::lang_in(styles), TextElem::region_in(styles))
}

// Upstream `Locale` has no cast: it is only stored in internal synthesized
// fields. Its value form here is the array `(lang, region)`.

///|
pub impl Reflect for Locale with fn input() {
  Type(Type::array())
}

///|
pub impl Reflect for Locale with fn output() {
  Type(Type::array())
}

///|
pub impl Reflect for Locale with fn castable(v) {
  v is Array(_)
}

///|
pub impl IntoValue for Locale with fn into_value(self) {
  Array(
    Arr::from_array([self.lang.into_value(), IntoValue::into_value(self.region)]),
  )
}

///|
pub impl FromValue for Locale with fn from_value(v) {
  let (lang, region) : (Lang, Region?) = FromValue::from_value(v)
  Locale::new(lang, region)
}

///|
pub fn Locale::rfc_3066(self : Locale) -> String {
  match self.region {
    Some(region) => self.lang.as_str() + "-" + region.as_str()
    None => self.lang.as_str()
  }
}

///|
fn text_elem_lang_default() -> Value {
  lang_english.into_value()
}
