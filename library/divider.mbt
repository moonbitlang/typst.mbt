// Port of the `ShowSet` impl of `typst-library/src/model/divider.rs` (the
// element itself is generated).

///|
/// Upstream `ShowSet for Packed<DividerElem>`.
fn divider_elem_show_set(_content : Content, _styles : StyleChain) -> Styles {
  let out = Styles::new()
  out.push(BlockElem::set_above(Custom(Spacing::from_em(Em::new(2.0)))))
  out.push(BlockElem::set_below(Custom(Spacing::from_em(Em::new(2.0)))))
  out.push(LineElem::set_length(Rel::from_ratio(Ratio::one())))
  out.push(
    LineElem::set_stroke({
      ..Stroke::default(),
      thickness: Custom(Length::from_em(Em::new(0.05))),
    }),
  )
  out
}
