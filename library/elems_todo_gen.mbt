// Generated stubs for element hooks that are not ported yet.

///|
/// TODO: port `` (AlignElem.alignment).
fn align_elem_alignment_default() -> Value {
  None
}

///|
/// TODO: port `Some(Arc::new(Stroke::default()))` (GridHLine.stroke).
fn grid_h_line_elem_stroke_default() -> Value {
  None
}

///|
/// TODO: port `Some(Arc::new(Stroke::default()))` (GridVLine.stroke).
fn grid_v_line_elem_stroke_default() -> Value {
  None
}

// TODO: port `#[parse]` of BibliographyElem.sources as `bibliography_elem_sources_parse`.

///|
/// TODO: port `{ let default = ArchivedStyle::InstituteOfElectricalAndElectronicsEngineers; Derived::new(CslSource::Named(default, None), CslStyle::from_archived(default)) }` (BibliographyElem.style).
fn bibliography_elem_style_default() -> Value {
  None
}

// TODO: port `#[parse]` of BibliographyElem.style as `bibliography_elem_style_parse`.

///|
/// TODO: port `Default::default() of Smart<Derived<CslSource, CslStyle>>` (CiteElem.style).
fn cite_elem_style_default() -> Value {
  None
}

// TODO: port `#[parse]` of CiteElem.style as `cite_elem_style_parse`.

///|
/// TODO: port `LineElem::new().with_length(Ratio::new(0.3).into()).with_stroke(Stroke { thickness : Smart::Custom(Em::new(0.05).into()), .. Default::default() }).pack()` (FootnoteEntry.separator).
fn footnote_entry_elem_separator_default() -> Value {
  None
}

///|
/// TODO: port `Celled::Value(Sides::splat(Some(Some(Arc::new(Stroke::default())))))` (TableElem.stroke).
fn table_elem_stroke_default() -> Value {
  None
}

///|
/// TODO: port `Some(Arc::new(Stroke::default()))` (TableHLine.stroke).
fn table_h_line_elem_stroke_default() -> Value {
  None
}

///|
/// TODO: port `Some(Arc::new(Stroke::default()))` (TableVLine.stroke).
fn table_v_line_elem_stroke_default() -> Value {
  None
}

///|
/// TODO: port `Some(Color::from_u8(0xFF, 0xFD, 0x11, 0xA1).into())` (HighlightElem.fill).
fn highlight_elem_fill_default() -> Value {
  None
}

///|
/// TODO: port `Default::default() of SmallVec<[Decoration; 1]>` (TextElem.deco).
fn text_elem_deco_default() -> Value {
  None
}

///|
/// TODO: fold for `SmallVec<[Decoration; 1]>` (TextElem.deco).
fn text_elem_deco_fold(inner : Value, _outer : Value) -> Value {
  inner
}

///|
/// TODO: port `Default::default() of Derived<OneOrMultiple<DataSource>, Vec<RawSyntax>>` (RawElem.syntaxes).
fn raw_elem_syntaxes_default() -> Value {
  None
}

///|
/// TODO: fold for `Derived<OneOrMultiple<DataSource>, Vec<RawSyntax>>` (RawElem.syntaxes).
fn raw_elem_syntaxes_fold(inner : Value, _outer : Value) -> Value {
  inner
}

// TODO: port `#[parse]` of RawElem.syntaxes as `raw_elem_syntaxes_parse`.

// TODO: port `#[parse]` of RawElem.theme as `raw_elem_theme_parse`.
