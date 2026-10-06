// Port of the castable value types of `typst-library/src/text/lang.rs`
// (`Lang`, `Region`, `WritingScript`, `Locale`). Translations
// (`localized_str`) are not ported here.

///|
/// An identifier for a natural language: an ISO 639-1/2/3 code, stored
/// lowercased.
pub(all) struct Lang(String) derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lang with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lang with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lang with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lang with @debug.Debug::{to_repr}

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
  // The codes of `[ARABIC, DIVEHI, PERSIAN, HEBREW, KASHMIRI, PUNJABI,
  // PASHTO, SINDHI, UYGHUR, URDU, YIDDISH].contains(self)`, matched without
  // allocating the array on every call.
  match self.0 {
    "ar"
    | "dv"
    | "fa"
    | "he"
    | "ks"
    | "pa"
    | "ps"
    | "sd"
    | "ug"
    | "ur"
    | "yi" => RTL
    _ => LTR
  }
}

///|
/// Whether all characters of the string are ASCII.
fn is_ascii_str(s : String) -> Bool {
  for i in 0..<s.length() {
    if s.code_unit_at(i).to_int() >= 0x80 {
      return false
    }
  }
  true
}

///|
/// `s.to_lower()`, returning `s` itself if it has no ASCII uppercase letters
/// (performance: language codes are cast on every style lookup).
fn ascii_to_lower(s : String) -> String {
  for i in 0..<s.length() {
    let c = s.code_unit_at(i).to_int()
    if c >= 'A'.to_int() && c <= 'Z'.to_int() {
      return s.to_lower()
    }
  }
  s
}

///|
/// Construct a language from a two- or three-byte ISO 639-1/2/3 code.
pub fn Lang::from_str(iso : String) -> Lang raise HintedError {
  let len = @syntax.utf8_len(iso)
  if len >= 2 && len <= 3 && is_ascii_str(iso) {
    Lang(ascii_to_lower(iso))
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
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Lang with Reflect::{output, input, castable}

///|
pub impl IntoValue for Lang with fn into_value(self) {
  Str(self.as_str())
}

///|
pub extend Lang with IntoValue::{into_value}

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
pub extend Lang with FromValue::{from_value}

///|
/// An identifier for a region somewhere in the world: an ISO 3166-1 alpha-2
/// code, stored uppercased.
pub(all) struct Region(String) derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with @debug.Debug::{to_repr}

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
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with Reflect::{output, input, castable}

///|
pub impl IntoValue for Region with fn into_value(self) {
  Str(self.as_str())
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Region with IntoValue::{into_value}

///|
pub impl FromValue for Region with fn from_value(v) {
  Region::from_str((FromValue::from_value(v) : String))
}

///|
pub extend Region with FromValue::{from_value}

///|
/// An ISO 15924-type script identifier, stored lowercased.
pub(all) struct WritingScript(String) derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with @debug.Debug::{to_repr}

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
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with Reflect::{output, input, castable}

///|
pub impl IntoValue for WritingScript with fn into_value(self) {
  Str(self.as_str())
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with IntoValue::{into_value}

///|
pub impl FromValue for WritingScript with fn from_value(v) {
  WritingScript::from_str((FromValue::from_value(v) : String))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend WritingScript with FromValue::{from_value}

///|
/// A locale consisting of a language and an optional region.
pub(all) struct Locale {
  lang : Lang
  region : Region?
} derive(Eq, Hash, Compare, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with Hash::{hash, hash_combine}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with @debug.Debug::{to_repr}

///|
pub fn Locale::new(lang : Lang, region : Region?) -> Locale {
  { lang, region, }
}

///|
pub impl Default for Locale with fn default() {
  Locale::new(lang_english, None)
}

///|
pub extend Locale with Default::{default}

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
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with Reflect::{output, input, castable}

///|
pub impl IntoValue for Locale with fn into_value(self) {
  Array(
    Arr::from_array([self.lang.into_value(), IntoValue::into_value(self.region)]),
  )
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with IntoValue::{into_value}

///|
pub impl FromValue for Locale with fn from_value(v) {
  let (lang, region) : (Lang, Region?) = FromValue::from_value(v)
  Locale::new(lang, region)
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Locale with FromValue::{from_value}

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
