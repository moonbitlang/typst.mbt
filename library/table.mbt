// Port of the value-level parts of `typst-library/src/model/table.rs`:
// `TableElem`/`TableCell` casts, `TableChild`, `TableItem`,
// `TableCellKind`, `TableHeaderScope` and the field defaults of the table
// elements.

///|
/// Typed view of `table` content.
pub struct TableElem(Content)

///|
pub impl Reflect for TableElem with fn input() {
  Content::input()
}

///|
pub impl Reflect for TableElem with fn output() {
  Content::output()
}

///|
pub impl Reflect for TableElem with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for TableElem with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for TableElem with fn from_value(value) {
  // Upstream `v.unpack::<Self>()`.
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    if v.is_(table_elem()) {
      return TableElem(unpack_content(v))
    }
    bail("expected table")
  }
  raise HintedError(Content::input().error(value))
}

///|
/// Upstream `Content::unpack`, as seen once the element is packed again:
/// the element's fields without the content's span, label, location and
/// lifecycle (so the content gets the span of the call that packs it).
fn unpack_content(content : Content) -> Content {
  Content::from_fields(content.elem, content.fields)
}

///|
/// A copy with the `summary` field set (upstream `with_summary`).
pub fn TableElem::with_summary(
  self : TableElem,
  summary : String?,
) -> TableElem {
  TableElem(
    self.0.with_field(table_elem_summary, IntoValue::into_value(summary)),
  )
}

///|
/// Any child of a table element.
pub(all) enum TableChild {
  Header(Content)
  Footer(Content)
  Item(TableItem)
} derive(Eq)

///|
pub impl Reflect for TableChild with fn input() {
  Content::input()
}

///|
pub impl Reflect for TableChild with fn output() {
  Content::output()
}

///|
pub impl Reflect for TableChild with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for TableChild with fn into_value(self) {
  match self {
    Header(header) => Content(header)
    Footer(footer) => Content(footer)
    Item(item) => IntoValue::into_value(item)
  }
}

///|
pub impl FromValue for TableChild with fn from_value(value) {
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    return TableChild::try_from(v)
  }
  raise HintedError(Content::input().error(value))
}

///|
/// Upstream `TryFrom<Content> for TableChild`.
pub fn TableChild::try_from(value : Content) -> TableChild raise HintedError {
  if value.is_(grid_header_elem()) {
    bail_hinted("cannot use `grid.header` as a table header", [
      "use `table.header` instead",
    ])
  }
  if value.is_(grid_footer_elem()) {
    bail_hinted("cannot use `grid.footer` as a table footer", [
      "use `table.footer` instead",
    ])
  }
  if value.is_(table_header_elem()) {
    Header(value)
  } else if value.is_(table_footer_elem()) {
    Footer(value)
  } else {
    Item(TableItem::try_from(value))
  }
}

///|
/// A table item, which is the basic unit of table specification.
pub(all) enum TableItem {
  HLine(Content)
  VLine(Content)
  Cell(Content)
} derive(Eq)

///|
pub impl Reflect for TableItem with fn input() {
  Content::input()
}

///|
pub impl Reflect for TableItem with fn output() {
  Content::output()
}

///|
pub impl Reflect for TableItem with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for TableItem with fn into_value(self) {
  match self {
    HLine(hline) => Content(hline)
    VLine(vline) => Content(vline)
    Cell(cell) => Content(cell)
  }
}

///|
pub impl FromValue for TableItem with fn from_value(value) {
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    return TableItem::try_from(v)
  }
  raise HintedError(Content::input().error(value))
}

///|
/// Upstream `TryFrom<Content> for TableItem`.
pub fn TableItem::try_from(value : Content) -> TableItem raise HintedError {
  if value.is_(grid_header_elem()) {
    bail("cannot place a grid header within another header or footer")
  }
  if value.is_(table_header_elem()) {
    bail("cannot place a table header within another header or footer")
  }
  if value.is_(grid_footer_elem()) {
    bail("cannot place a grid footer within another footer or header")
  }
  if value.is_(table_footer_elem()) {
    bail("cannot place a table footer within another footer or header")
  }
  if value.is_(grid_cell_elem()) {
    bail_hinted("cannot use `grid.cell` as a table cell", [
      "use `table.cell` instead",
    ])
  }
  if value.is_(grid_h_line_elem()) {
    bail_hinted("cannot use `grid.hline` as a table line", [
      "use `table.hline` instead",
    ])
  }
  if value.is_(grid_v_line_elem()) {
    bail_hinted("cannot use `grid.vline` as a table line", [
      "use `table.vline` instead",
    ])
  }
  if value.is_(table_h_line_elem()) {
    HLine(value)
  } else if value.is_(table_v_line_elem()) {
    VLine(value)
  } else if value.is_(table_cell_elem()) {
    Cell(value)
  } else {
    let span = value.span()
    Cell(TableCell::new(value).0.spanned(span))
  }
}

///|
/// Typed view of `table.cell` content.
pub struct TableCell(Content)

///|
/// A new table cell with the given body (upstream `TableCell::new`).
pub fn TableCell::new(body : Content) -> TableCell {
  TableCell(
    Content::new(table_cell_elem(), [(table_cell_elem_body, Content(body))]),
  )
}

///|
/// Upstream `From<Content> for TableCell`.
pub fn TableCell::from_content(value : Content) -> TableCell {
  // Upstream `value.unpack::<Self>().unwrap_or_else(Self::new)`.
  if value.is_(table_cell_elem()) {
    TableCell(unpack_content(value))
  } else {
    TableCell::new(value)
  }
}

///|
/// A copy with the internal `kind` field set (upstream `with_kind`).
pub fn TableCell::with_kind(
  self : TableCell,
  kind : Smart[TableCellKind],
) -> TableCell {
  TableCell(self.0.with_field(table_cell_elem_kind, kind_to_value(kind)))
}

///|
/// The internal `kind` field of the cell, if set.
pub fn TableCell::kind(self : TableCell) -> Smart[TableCellKind]? {
  self.0.field_raw(table_cell_elem_kind).map(kind_from_value)
}

///|
pub impl Reflect for TableCell with fn input() {
  Content::input()
}

///|
pub impl Reflect for TableCell with fn output() {
  Content::output()
}

///|
pub impl Reflect for TableCell with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for TableCell with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for TableCell with fn from_value(value) {
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    return TableCell::from_content(v)
  }
  raise HintedError(Content::input().error(value))
}

///|
/// Describes what kind of table cell this is.
///
/// The full Typst table model only supports header and footer rows, this is
/// currently only used for PDF export.
pub(all) enum TableCellKind {
  Header(NonZeroU32, TableHeaderScope)
  Footer
  Data
} derive(Eq, Hash, Debug)

///|
pub impl Default for TableCellKind with fn default() {
  Data
}

// `TableCellKind` is not castable upstream; the internal `kind` field stores
// it in an encoding private to this file.

///|
fn kind_to_value(kind : Smart[TableCellKind]) -> Value {
  match kind {
    Auto => Auto
    Custom(Header(level, scope)) =>
      Array(Arr::from_array([Int(level.0), IntoValue::into_value(scope)]))
    Custom(Footer) => Str("footer")
    Custom(Data) => Str("data")
  }
}

///|
fn kind_from_value(value : Value) -> Smart[TableCellKind] {
  match value {
    Array(arr) if arr.items is [Int(level), scope] =>
      Custom(
        Header(
          NonZeroU32(level),
          TableHeaderScope::from_value(scope) catch {
            _ => Column
          },
        ),
      )
    Str("footer") => Custom(Footer)
    Str("data") => Custom(Data)
    _ => Auto
  }
}

///|
/// Which table track a header cell labels.
pub(all) enum TableHeaderScope {
  /// The header cell refers to both the row and the column.
  Both
  /// The header cell refers to the column.
  Column
  /// The header cell refers to the row.
  Row
} derive(Eq, Hash, Debug)

///|
pub impl Default for TableHeaderScope with fn default() {
  Column
}

///|
pub fn TableHeaderScope::refers_to_column(self : TableHeaderScope) -> Bool {
  match self {
    Both => true
    Column => true
    Row => false
  }
}

///|
pub fn TableHeaderScope::refers_to_row(self : TableHeaderScope) -> Bool {
  match self {
    Both => true
    Column => false
    Row => true
  }
}

///|
pub impl Reflect for TableHeaderScope with fn input() {
  Union([
    Value(Str("both"), "The header cell refers to both the row and the column."),
    Value(Str("column"), "The header cell refers to the column."),
    Value(Str("row"), "The header cell refers to the row."),
  ])
}

///|
pub impl Reflect for TableHeaderScope with fn output() {
  TableHeaderScope::input()
}

///|
pub impl Reflect for TableHeaderScope with fn castable(v) {
  v is Str("both" | "column" | "row")
}

///|
pub extend TableHeaderScope with Reflect::{output, input, castable}

///|
pub impl IntoValue for TableHeaderScope with fn into_value(self) {
  match self {
    Both => Str("both")
    Column => Str("column")
    Row => Str("row")
  }
}

///|
pub impl FromValue for TableHeaderScope with fn from_value(v) {
  match v {
    Str("both") => Both
    Str("column") => Column
    Str("row") => Row
    v => raise HintedError(TableHeaderScope::input().error(v))
  }
}

///|
pub extend TableHeaderScope with FromValue::{from_value}

// Field defaults of the table elements.

///|
fn table_elem_columns_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn table_elem_rows_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn table_elem_gutter_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn table_elem_column_gutter_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn table_elem_row_gutter_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn table_elem_inset_default() -> Value {
  let inset : Celled[Sides[Rel[Length]?]] = CelledValue(
    Sides::splat(Some(Rel::from_abs(Length::from_abs(Abs::pt(5.0))))),
  )
  IntoValue::into_value(inset)
}

///|
fn table_elem_align_default() -> Value {
  let align : Celled[Smart[Alignment]] = CelledValue(Auto)
  IntoValue::into_value(align)
}

///|
/// `Celled::Value(None)` of `Celled<Option<Paint>>`.
fn table_elem_fill_default() -> Value {
  None
}

///|
/// `Smart::Auto` of `Smart<TableCellKind>`.
fn table_cell_elem_kind_default() -> Value {
  kind_to_value(Auto)
}

///|
/// Upstream `LocalName for Packed<TableElem>`.
fn table_elem_local_name_key() -> String {
  "table"
}

///|
/// `Some(Arc::new(Stroke::default()))` (TableHLine.stroke).
fn table_h_line_elem_stroke_default() -> Value {
  IntoValue::into_value((Some(Stroke::default()) : Stroke?))
}

///|
/// `Some(Arc::new(Stroke::default()))` (TableVLine.stroke).
fn table_v_line_elem_stroke_default() -> Value {
  IntoValue::into_value((Some(Stroke::default()) : Stroke?))
}

///|
/// `Celled::Value(Sides::splat(Some(Some(Arc::new(Stroke::default())))))`
/// (TableElem.stroke).
fn table_elem_stroke_default() -> Value {
  let stroke : Stroke?? = Some(Some(Stroke::default()))
  (CelledValue(Sides::splat(stroke)) : Celled[Sides[Stroke??]]).into_value()
}

///|
/// `impl Synthesize for Packed<TableElem>`.
fn table_elem_synthesize(
  engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  let elem = TableElem(content)
  let grid = table_to_cellgrid(elem, engine, styles)
  elem.with_grid(grid).pack()
}

///|
/// Upstream `Default for Packed<TableCell>`.
pub impl Default for TableCell with fn default() {
  // Explicitly set colspan and rowspan to ensure they won't be
  // overridden by set rules (default cells are created after
  // colspans and rowspans are processed in the resolver)
  TableCell::new(Content::empty())
  .with_colspan(NonZeroUSize(1L))
  .with_rowspan(NonZeroUSize(1L))
}

///|
/// The internal `kind` field of the cell, taking styles into account
/// (upstream `cell.kind.get(styles)`).
pub fn TableCell::kind_in_chain(
  self : TableCell,
  styles : StyleChain,
) -> Smart[TableCellKind] {
  let e = table_cell_elem()
  kind_from_value(
    styles.get_value_with_local(
      e,
      e.fields()[table_cell_elem_kind],
      self.0.field_raw(table_cell_elem_kind),
    ),
  )
}
