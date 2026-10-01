// Port of `typst-library/src/model/title.rs` (`TitleElem::resolve_body`;
// the element itself is generated).

///|
/// The title's body: the explicit body or the document title.
pub fn TitleElem::resolve_body(
  self : TitleElem,
  styles : StyleChain,
) -> Content raise HintedError {
  match self.body(styles) {
    Auto =>
      match DocumentElem::title_in(styles) {
        Some(title) => title
        None =>
          bail_hinted("document title was not set", [
            "set the title with `set document(title: [...])`", "or provide an explicit body with `title[..]`",
          ])
      }
    Custom(body) => body
  }
}
