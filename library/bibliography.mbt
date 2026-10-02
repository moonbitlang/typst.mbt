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

///|
/// Checks if this bibliography contains the given key.
///
/// TODO: The loaded bibliography data (`sources.derived`) is not ported yet,
/// so no bibliography contains any key.
pub fn BibliographyElem::has(
  engine : Engine,
  key : Label,
  span : @syntax.Span,
) -> Bool {
  engine
  .introspect(query_introspection(bibliography_elem().select(), span))
  .iter()
  .any(elem => BibliographyElem(elem).sources_has(key))
}

///|
/// Whether the loaded sources contain the key (upstream
/// `sources.derived.has(key)`; not ported yet).
fn BibliographyElem::sources_has(
  _self : BibliographyElem,
  _key : Label,
) -> Bool {
  false
}
