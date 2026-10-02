// Port of the capability impls of `typst-library/src/model/bibliography.rs`
// (the element itself is generated).

///|
/// Upstream `Synthesize for Packed<BibliographyElem>`.
fn bibliography_elem_synthesize(
  _engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  BibliographyElem(content)
  .with_lang(TextElem::lang_in(styles))
  .with_region(TextElem::region_in(styles))
  .pack()
}

///|
/// Upstream `ShowSet for Packed<BibliographyElem>`.
fn bibliography_elem_show_set(
  _content : Content,
  _styles : StyleChain,
) -> Styles {
  let indent = Em::new(1.0)
  let out = Styles::new()
  out.push(HeadingElem::set_numbering(None))
  out.push(PadElem::set_left(Rel::from_abs(Length::from_em(indent))))
  out
}

///|
/// Upstream `LocalName for Packed<BibliographyElem>`.
fn bibliography_elem_local_name_key() -> String {
  "bibliography"
}
