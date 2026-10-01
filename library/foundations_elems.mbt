// Constructors for frequently used elements (upstream `XElem::packed` etc.).

///|
/// Text content (upstream `TextElem::packed`).
pub fn TextElem::packed(text : String) -> Content {
  Content::new(text_elem(), [(text_elem_text, Str(text))])
}

///|
/// Typed view of `text` content.
pub struct TextElem(Content)

///|
/// A symbol (upstream `SymbolElem::packed`).
pub fn SymbolElem::packed(text : String) -> Content {
  Content::new(symbol_elem(), [(symbol_elem_text, Str(text))])
}

///|
/// Typed view of `symbol` content.
pub struct SymbolElem(Content)

///|
/// Raw text of code (used by `Value::display`).
pub fn RawElem::packed_code(text : String) -> Content {
  Content::new(raw_elem(), [(raw_elem_text, Str(text))])
  .with_field(raw_elem_lang, Str("typc"))
  .with_field(raw_elem_block, Bool(false))
}

///|
/// Typed view of `raw` content.
pub struct RawElem(Content)
