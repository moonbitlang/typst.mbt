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

///|
let space_shared_cell : Ref[Content?] = Ref::new(None)

///|
/// Typed view of `space` content.
pub struct SpaceElem(Content)

///|
/// Shared space content (upstream `SpaceElem::shared`).
pub fn SpaceElem::shared() -> Content {
  match space_shared_cell.val {
    Some(c) => c
    None => {
      let c = Content::new(space_elem(), [])
      space_shared_cell.val = Some(c)
      c
    }
  }
}

///|
/// Shared space content with a newline (upstream
/// `SpaceElem::shared_with_newline`).
pub fn SpaceElem::shared_with_newline() -> Content {
  SpaceElem::shared()
}

///|
/// Typed view of `link` content.
pub struct LinkElem(Content)

///|
/// Create a link element from a URL with its URL as the body (upstream
/// `LinkElem::from_url`).
pub fn LinkElem::from_url(url : String) -> Content raise HintedError {
  if @syntax.utf8_len(url) > 8000 {
    bail_hinted("URL is too long", ["URLs are limited to 8000 bytes"])
  }
  let body = TextElem::packed(link_body_from_url(url))
  Content::new(link_elem(), [
    (link_elem_dest, Str(url)),
    (link_elem_body, Content(body)),
  ])
}

///|
/// Strip `mailto:` and `tel:` prefixes from a URL for display.
fn link_body_from_url(url : String) -> String {
  let mut text = url
  for prefix in ["mailto:", "tel:"] {
    if text.has_prefix(prefix) {
      text = text.unsafe_substring(start=prefix.length(), end=text.length())
    }
  }
  text
}

///|
/// A selector that can be used with show rules (upstream `ShowableSelector`).
pub(all) struct ShowableSelector(Selector)

///|
pub impl Reflect for ShowableSelector with fn input() {
  Union([
    Type(Type::symbol()),
    Type(Type::str()),
    Type(Type::label()),
    Type(Type::func()),
    Type(Type::regex()),
    Type(Type::selector()),
  ])
}

///|
pub impl Reflect for ShowableSelector with fn output() {
  Type(Type::selector())
}

///|
pub impl Reflect for ShowableSelector with fn castable(v) {
  v is (Symbol(_) | Str(_) | Label(_) | Func(_))
}

///|
pub impl FromValue for ShowableSelector with fn from_value(v) {
  match v {
    Symbol(s) => ShowableSelector(Regex(regex_escape(s.get())))
    Str(s) =>
      if s.is_empty() {
        bail("text selector is empty")
      } else {
        ShowableSelector(Regex(regex_escape(s)))
      }
    Label(l) => ShowableSelector(Label(l))
    Func(f) =>
      match f.to_element() {
        Some(elem) => ShowableSelector(Elem(elem, None))
        None => bail("only element functions can be used as selectors")
      }
    v => raise HintedError(ShowableSelector::input().error(v))
  }
}

///|
/// Escape regex metacharacters (upstream `regex::escape`).
pub fn regex_escape(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    if c
      is ('\\'
      | '.'
      | '+'
      | '*'
      | '?'
      | '('
      | ')'
      | '|'
      | '['
      | ']'
      | '{'
      | '}'
      | '^'
      | '$'
      | '#'
      | '&'
      | '-'
      | '~') {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
  buf.to_string()
}
