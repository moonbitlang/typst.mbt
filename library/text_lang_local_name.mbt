// Port of the local name lookup of `typst-library/src/text/lang.rs`
// (`LocalName`, `localized_str`, `parse_language_bundle`). The bundles are
// generated into `translations_gen.mbt` by `scripts/gen_translations.py`.

///|
/// Retrieves the localized string for a given language and region.
/// Silently falls back to English if no fitting string exists for
/// the given language + region. Panics if no fitting string exists
/// in both given language + region and English.
pub fn localized_str(lang : String, region : String?, key : String) -> String {
  let lang_region_bundle = parse_language_bundle(lang, region)
  if lang_region_bundle.get(key) is Some(str) {
    return str
  }
  let lang_bundle = parse_language_bundle(lang, None)
  if lang_bundle.get(key) is Some(str) {
    return str
  }
  let english_bundle = parse_language_bundle(lang_english.as_str(), None)
  english_bundle.get(key).unwrap()
}

///|
/// The translation bundle for a given language and region (upstream
/// `parse_language_bundle`; the files are parsed at generation time).
fn parse_language_bundle(
  lang : String,
  region : String?,
) -> Map[String, String] {
  // Convert language + region to a string to be able to get a file name.
  let name = match region {
    Some(r) => lang + "-" + r
    None => lang
  }
  for entry in translations {
    if entry.0 == name {
      return Map::from_array(entry.1)
    }
  }
  {}
}

///|
/// Gets the local name of an element from the style chain (upstream
/// `LocalName::local_name_in`). Panics if the element has no local name.
pub fn Element::local_name_in(self : Element, styles : StyleChain) -> String {
  let lang = TextElem::lang_in(styles).as_str()
  let region = TextElem::region_in(styles).map(r => r.as_str())
  self.local_name(lang, region).unwrap()
}
