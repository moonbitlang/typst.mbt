// Port of the capability impls of `typst-library/src/model/heading.rs`
// (`Synthesize`, `ShowSet`, `LocalName`).

///|
/// `impl Synthesize for Packed<HeadingElem>`.
fn heading_elem_synthesize(
  engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  let elem = HeadingElem(content)
  let supplement = match elem.supplement(styles) {
    Auto => TextElem::packed(heading_elem().local_name_in(styles))
    Custom(None) => Content::empty()
    Custom(Some(supplement)) =>
      supplement.resolve(engine, styles, [Content(content)])
  }
  let mut elem = elem
  if elem.numbering(styles) is Some(numbering) &&
    content.location() is Some(location) {
    // We are not early returning on error here because of
    // https://github.com/typst/typst/issues/7428
    //
    // A more comprehensive fix might introduce the error catching logic
    // of show rules for synthesis, too.
    let numbers = Some(
      Counter::of(heading_elem()).display_at(
        engine,
        location,
        styles,
        numbering,
        content.span(),
      ),
    ) catch {
      _ => None
    }
    if numbers is Some(numbers) {
      elem = elem.with_numbers(numbers.plain_text())
    }
  }
  elem
  .with_level(Custom(elem.resolve_level(styles)))
  .with_supplement(Custom(Some(Content(supplement))))
  .pack()
}

///|
/// `impl ShowSet for Packed<HeadingElem>`.
fn heading_elem_show_set(content : Content, styles : StyleChain) -> Styles {
  let level = HeadingElem(content).resolve_level(styles).get()
  let scale = match level {
    1 => 1.4
    2 => 1.2
    _ => 1.0
  }
  let size = Em::new(scale)
  let above = Em::new(if level == 1 { 1.8 } else { 1.44 }).div_by(scale)
  let below = Em::new(0.75).div_by(scale)
  let out = Styles::new()
  out.push(TextElem::set_size(TextSize(Length::from_em(size))))
  out.push(TextElem::set_weight(font_weight_bold))
  out.push(BlockElem::set_above(Custom(Spacing::from_em(above))))
  out.push(BlockElem::set_below(Custom(Spacing::from_em(below))))
  out.push(BlockElem::set_sticky(true))
  out
}

///|
/// `impl LocalName for Packed<HeadingElem>`.
fn heading_elem_local_name_key() -> String {
  "heading"
}
