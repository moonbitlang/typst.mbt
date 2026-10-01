// Port of `typst-html/src/css/resolve.rs`. (The value-level parts of the
// `css` module, `css/encode.rs`, live in `library/html_css.mbt`.)

///|
/// Turns CSS properties on all elements in the DOM into inline `style`
/// attributes.
///
/// This by itself would not need a separate pass over the DOM, but it will be
/// supplanted by more advanced CSS handling, so it makes sense to already
/// organize the code like this.
pub fn resolve_inline_styles(root : HtmlElement) -> Unit {
  visit_elem(root)
}

///|
fn visit_elem(elem : HtmlElement) -> Unit {
  if !elem.css.is_empty() {
    let generated = elem.css.to_inline()
    match elem.attrs.get(@library.attr_style) {
      Some(style) => {
        let value = if style.is_empty() {
          generated + style
        } else {
          generated + "; " + style
        }
        elem.attrs = elem.attrs.copy()
        elem.attrs.set_existing(@library.attr_style, value) |> ignore
      }
      None => {
        elem.attrs = elem.attrs.copy()
        elem.attrs.push(@library.attr_style, generated)
      }
    }
  }
  for child in elem.children {
    if child is Element(elem) {
      visit_elem(elem)
    }
  }
}
