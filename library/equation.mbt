// Parts of `typst-library/src/math/equation.rs` (the element itself is
// generated): the `Synthesize`, `ShowSet` and `LocalName` impls (wired into
// the element's hooks by `scripts/elemgen.py`).

///|
/// Upstream `Synthesize for Packed<EquationElem>`.
fn equation_elem_synthesize(
  engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  let elem = EquationElem(content)
  let supplement = match elem.supplement(styles) {
    Auto => TextElem::packed(equation_elem().local_name_in(styles))
    Custom(None) => Content::empty()
    Custom(Some(supplement)) =>
      supplement.resolve(engine, styles, [Content(content)])
  }
  elem
  .with_supplement(Custom(Some(Content(supplement))))
  .with_locale(Locale::get_in(styles))
  .pack()
}

///|
/// Upstream `ShowSet for Packed<EquationElem>`.
fn equation_elem_show_set(content : Content, styles : StyleChain) -> Styles {
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

///|
/// Upstream `LocalName for Packed<EquationElem>`.
fn equation_elem_local_name_key() -> String {
  "equation"
}
