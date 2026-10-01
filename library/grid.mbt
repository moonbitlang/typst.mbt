// Port of the value-level parts of `typst-library/src/layout/grid/mod.rs`:
// `TrackSizings`, `GridChild`, `GridItem`, `GridCell` casts, `Celled<T>` and
// the field defaults of the grid elements.

///|
/// Track sizing definitions.
pub(all) struct TrackSizings(Array[Sizing]) derive(Eq, Hash)

///|
pub impl Default for TrackSizings with fn default() {
  TrackSizings([])
}

///|
fn track_sizings_input() -> CastInfo {
  Sizing::input().union_with(NonZeroUSize::input()).union_with(Arr::input())
}

///|
pub impl Reflect for TrackSizings with fn input() {
  track_sizings_input()
}

///|
pub impl Reflect for TrackSizings with fn output() {
  Sizing::output().union_with(NonZeroUSize::output()).union_with(Arr::output())
}

///|
pub impl Reflect for TrackSizings with fn castable(value) {
  Sizing::castable(value) ||
  NonZeroUSize::castable(value) ||
  Arr::castable(value)
}

///|
pub impl IntoValue for TrackSizings with fn into_value(self) {
  IntoValue::into_value(self.0)
}

///|
pub impl FromValue for TrackSizings with fn from_value(value) {
  if Sizing::castable(value) {
    let sizing : Sizing = Sizing::from_value(value)
    return TrackSizings([sizing])
  }
  if NonZeroUSize::castable(value) {
    let count : NonZeroUSize = NonZeroUSize::from_value(value)
    return TrackSizings(Array::make(count.get().to_int(), Sizing::Auto))
  }
  if Arr::castable(value) {
    let values : Arr = Arr::from_value(value)
    let sizings = []
    for v in values.items {
      sizings.push(Sizing::from_value(v))
    }
    return TrackSizings(sizings)
  }
  raise HintedError(track_sizings_input().error(value))
}

///|
/// Any child of a grid element.
pub(all) enum GridChild {
  Header(Content)
  Footer(Content)
  Item(GridItem)
} derive(Eq)

///|
pub impl Reflect for GridChild with fn input() {
  Content::input()
}

///|
pub impl Reflect for GridChild with fn output() {
  Content::output()
}

///|
pub impl Reflect for GridChild with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for GridChild with fn into_value(self) {
  match self {
    Header(header) => Content(header)
    Footer(footer) => Content(footer)
    Item(item) => IntoValue::into_value(item)
  }
}

///|
pub impl FromValue for GridChild with fn from_value(value) {
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    return GridChild::try_from(v)
  }
  raise HintedError(Content::input().error(value))
}

///|
/// Upstream `TryFrom<Content> for GridChild`.
pub fn GridChild::try_from(value : Content) -> GridChild raise HintedError {
  if value.is_(table_header_elem()) {
    bail_hinted("cannot use `table.header` as a grid header", [
      "use `grid.header` instead",
    ])
  }
  if value.is_(table_footer_elem()) {
    bail_hinted("cannot use `table.footer` as a grid footer", [
      "use `grid.footer` instead",
    ])
  }
  if value.is_(grid_header_elem()) {
    Header(value)
  } else if value.is_(grid_footer_elem()) {
    Footer(value)
  } else {
    Item(GridItem::try_from(value))
  }
}

///|
/// A grid item, which is the basic unit of grid specification.
pub(all) enum GridItem {
  HLine(Content)
  VLine(Content)
  Cell(Content)
} derive(Eq)

///|
pub impl Reflect for GridItem with fn input() {
  Content::input()
}

///|
pub impl Reflect for GridItem with fn output() {
  Content::output()
}

///|
pub impl Reflect for GridItem with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for GridItem with fn into_value(self) {
  match self {
    HLine(hline) => Content(hline)
    VLine(vline) => Content(vline)
    Cell(cell) => Content(cell)
  }
}

///|
pub impl FromValue for GridItem with fn from_value(value) {
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    return GridItem::try_from(v)
  }
  raise HintedError(Content::input().error(value))
}

///|
/// Upstream `TryFrom<Content> for GridItem`.
pub fn GridItem::try_from(value : Content) -> GridItem raise HintedError {
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
  if value.is_(table_cell_elem()) {
    bail_hinted("cannot use `table.cell` as a grid cell", [
      "use `grid.cell` instead",
    ])
  }
  if value.is_(table_h_line_elem()) {
    bail_hinted("cannot use `table.hline` as a grid line", [
      "use `grid.hline` instead",
    ])
  }
  if value.is_(table_v_line_elem()) {
    bail_hinted("cannot use `table.vline` as a grid line", [
      "use `grid.vline` instead",
    ])
  }
  if value.is_(grid_h_line_elem()) {
    HLine(value)
  } else if value.is_(grid_v_line_elem()) {
    VLine(value)
  } else if value.is_(grid_cell_elem()) {
    Cell(value)
  } else {
    let span = value.span()
    Cell(GridCell::new(value).0.spanned(span))
  }
}

///|
/// Typed view of `grid.cell` content.
pub struct GridCell(Content)

///|
/// A new grid cell with the given body (upstream `GridCell::new`).
pub fn GridCell::new(body : Content) -> GridCell {
  GridCell(
    Content::new(grid_cell_elem(), [(grid_cell_elem_body, Content(body))]),
  )
}

///|
/// Upstream `From<Content> for GridCell`.
pub fn GridCell::from_content(value : Content) -> GridCell {
  if value.is_(grid_cell_elem()) {
    GridCell(value)
  } else {
    GridCell::new(value)
  }
}

///|
pub impl Reflect for GridCell with fn input() {
  Content::input()
}

///|
pub impl Reflect for GridCell with fn output() {
  Content::output()
}

///|
pub impl Reflect for GridCell with fn castable(value) {
  Content::castable(value)
}

///|
pub impl IntoValue for GridCell with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for GridCell with fn from_value(value) {
  if Content::castable(value) {
    let v : Content = Content::from_value(value)
    return GridCell::from_content(v)
  }
  raise HintedError(Content::input().error(value))
}

///|
/// A value that can be configured per cell.
///
/// The variants are prefixed (upstream `Value`, `Func`, `Array`) to avoid
/// ambiguity with the constructors of [Value].
pub(all) enum Celled[T] {
  /// A bare value, the same for all cells.
  CelledValue(T)
  /// A closure mapping from cell coordinates to a value.
  CelledFunc(Func)
  /// An array of alignment values corresponding to each column.
  CelledArray(Array[T])
} derive(Eq)

///|
pub impl[T : Default] Default for Celled[T] with fn default() {
  CelledValue(T::default())
}

///|
pub impl[T : Reflect] Reflect for Celled[T] with fn input() {
  T::input().union_with(Arr::input()).union_with(Func::input())
}

///|
pub impl[T : Reflect] Reflect for Celled[T] with fn output() {
  T::output().union_with(Arr::output()).union_with(Func::output())
}

///|
pub impl[T : Reflect] Reflect for Celled[T] with fn castable(value) {
  Arr::castable(value) || Func::castable(value) || T::castable(value)
}

///|
pub impl[T : IntoValue] IntoValue for Celled[T] with fn into_value(self) {
  match self {
    CelledValue(value) => value.into_value()
    CelledFunc(func) => Func(func)
    CelledArray(arr) => IntoValue::into_value(arr)
  }
}

///|
pub impl[T : FromValue] FromValue for Celled[T] with fn from_value(value) {
  match value {
    Func(v) => CelledFunc(v)
    Array(array) => {
      let items = []
      for v in array.items {
        items.push(T::from_value(v))
      }
      CelledArray(items)
    }
    v if T::castable(v) => CelledValue(T::from_value(v))
    v =>
      raise HintedError(
        T::input().union_with(Arr::input()).union_with(Func::input()).error(v),
      )
  }
}

///|
pub impl[T : Fold] Fold for Celled[T] with fn fold(self, outer) {
  match (self, outer) {
    (CelledValue(inner), CelledValue(outer)) => CelledValue(inner.fold(outer))
    (self_, _) => self_
  }
}

// Field defaults of the grid elements.

///|
fn grid_elem_columns_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn grid_elem_rows_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn grid_elem_gutter_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn grid_elem_column_gutter_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn grid_elem_row_gutter_default() -> Value {
  IntoValue::into_value(TrackSizings::default())
}

///|
fn grid_elem_inset_default() -> Value {
  let inset : Celled[Sides[Rel[Length]?]] = CelledValue(Sides::splat(None))
  IntoValue::into_value(inset)
}

///|
fn grid_elem_align_default() -> Value {
  let align : Celled[Smart[Alignment]] = CelledValue(Auto)
  IntoValue::into_value(align)
}

///|
/// `Celled::Value(None)` of `Celled<Option<Paint>>`.
fn grid_elem_fill_default() -> Value {
  None
}

///|
/// `Celled::Value(Sides::splat(None))` of
/// `Celled<Sides<Option<Option<Arc<Stroke>>>>>`.
fn grid_elem_stroke_default() -> Value {
  Dict(Dict::new())
}

///|
/// `Smart::Auto` of `Smart<Option<Paint>>`.
fn grid_cell_elem_fill_default() -> Value {
  Auto
}

///|
/// `Sides::splat(None)` of `Sides<Option<Option<Arc<Stroke>>>>`.
fn grid_cell_elem_stroke_default() -> Value {
  Dict(Dict::new())
}
