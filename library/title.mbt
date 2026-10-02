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

///|
/// Upstream `ShowSet for Packed<TitleElem>`.
fn title_elem_show_set(_content : Content, _styles : StyleChain) -> Styles {
  let size = Em::new(1.7)
  let above = Em::new(1.125)
  let below = Em::new(0.75)
  let out = Styles::new()
  out.push(TextElem::set_size(TextSize(Length::from_em(size))))
  out.push(TextElem::set_weight(font_weight_bold))
  out.push(BlockElem::set_above(Custom(Spacing::from_em(above))))
  out.push(BlockElem::set_below(Custom(Spacing::from_em(below))))
  out.push(BlockElem::set_sticky(true))
  out
}
