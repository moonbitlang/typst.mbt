// Parts of `typst-library/src/math/equation.rs` (the element itself is
// generated).

///|
fn equation_elem_init(e : Element) -> Unit {
  e.hooks().show_set = Some(equation_show_set)
}

///|
/// Upstream `ShowSet for Packed<EquationElem>`.
fn equation_show_set(content : Content, styles : StyleChain) -> Styles {
  let elem = EquationElem(content)
  let out = Styles::new()
  if elem.block(styles) {
    out.push(AlignElem::set_alignment(alignment_center))
    out.push(BlockElem::set_breakable(false))
    out.push(ParLine::set_numbering(None))
    out.push(EquationElem::set_size(Display))
  } else {
    out.push(EquationElem::set_size(Text))
  }
  out.push(TextElem::set_weight(FontWeight::from_number(450)))
  out.push(
    TextElem::set_font(FontList([FontFamily::new("New Computer Modern Math")])),
  )
  out
}
