// Port of the table functions of the `pdf` module
// (`typst-pdf/src/format.rs`).

///|
/// Annotate a table with a summary (upstream `table_summary`).
fn impl_pdf_format_table_summary(
  summary_ : String?,
  table_ : TableElem,
) -> Content {
  table_.with_summary(summary_).0
}

///|
fn impl_pdf_format_header_cell__level_default() -> NonZeroU32 {
  NonZeroU32(1L)
}

///|
fn impl_pdf_format_header_cell__scope_default() -> TableHeaderScope {
  TableHeaderScope::default()
}

///|
/// Explicitly defines a cell as a header cell (upstream `header_cell`).
fn impl_pdf_format_header_cell(
  level_ : NonZeroU32,
  scope_ : TableHeaderScope,
  cell_ : TableCell,
) -> Content {
  cell_.with_kind(Custom(Header(level_, scope_))).0
}

///|
/// Explicitly defines this cell as a data cell (upstream `data_cell`).
fn impl_pdf_format_data_cell(cell_ : TableCell) -> Content {
  cell_.with_kind(Custom(Data)).0
}
