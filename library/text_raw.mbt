// Port of the castable value types of `typst-library/src/text/raw.rs`
// (`RawContent`). Syntax highlighting, syntaxes and themes are not ported
// here.

///|
/// The content of the raw text.
///
/// Upstream also has a `Lines` variant (lines with their spans) created by
/// the evaluator for raw blocks; it is stored as its joined text here.
pub(all) enum RawContent {
  /// From a string.
  Text(String)
} derive(Eq, Hash, Debug)

///|
/// Returns or synthesizes the text content of the raw text.
pub fn RawContent::get(self : RawContent) -> String {
  match self {
    Text(text) => text
  }
}

///|
pub impl Reflect for RawContent with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for RawContent with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for RawContent with fn castable(v) {
  str_castable(v)
}

///|
pub impl IntoValue for RawContent with fn into_value(self) {
  Str(self.get())
}

///|
pub impl FromValue for RawContent with fn from_value(v) {
  Text(FromValue::from_value(v))
}

///|
/// Upstream `ShowSet for Packed<RawElem>`.
fn raw_elem_show_set(content : Content, styles : StyleChain) -> Styles {
  let out = Styles::new()
  out.push(TextElem::set_overhang(false))
  out.push(TextElem::set_lang(lang_english))
  out.push(TextElem::set_hyphenate(Custom(false)))
  out.push(TextElem::set_size(TextSize(Length::from_em(Em::new(0.8)))))
  out.push(TextElem::set_font(FontList([FontFamily::new("DejaVu Sans Mono")])))
  out.push(TextElem::set_cjk_latin_spacing(Custom(None)))
  if RawElem(content).block(styles) {
    out.push(ParElem::set_justify(false))
  }
  out
}

///|
/// Upstream `LocalName for Packed<RawElem>`.
fn raw_elem_local_name_key() -> String {
  "raw"
}
