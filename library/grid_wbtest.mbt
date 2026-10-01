///|
fn grid_cast_msg(f : () -> Unit raise HintedError) -> String {
  try {
    f()
    "ok"
  } catch {
    HintedError(e) => ([e.message] + e.hints).join(" | ")
  }
}

///|
test "track sizings cast" {
  let s : TrackSizings = Value::Int(2L).cast()
  inspect(IntoValue::into_value(s).repr(), content="(auto, auto)")
  let s : TrackSizings = Value::Auto.cast()
  inspect(IntoValue::into_value(s).repr(), content="(auto,)")
  inspect(
    grid_cast_msg(() => {
      let _ : TrackSizings = Value::Int(0L).cast()
    }),
    content="number must be positive",
  )
  inspect(
    grid_cast_msg(() => {
      let _ : TrackSizings = Value::Str("a").cast()
    }),
    content="expected auto, relative length, fraction, integer, or array, found string",
  )
  inspect(
    grid_cast_msg(() => {
      let _ : TrackSizings = Value::Array(Arr::from_array([Value::Int(1L)])).cast()
    }),
    content="expected auto, relative length, or fraction, found integer",
  )
}

///|
test "celled cast" {
  let c : Celled[Smart[Alignment]] = Value::Array(
    Arr::from_array([Value::Auto]),
  ).cast()
  inspect(IntoValue::into_value(c).repr(), content="(auto,)")
  inspect(
    grid_cast_msg(() => {
      let _ : Celled[Smart[Alignment]] = Value::Int(1L).cast()
    }),
    content="expected alignment, auto, array, or function, found integer",
  )
}

///|
test "grid children cast" {
  let item : GridItem = Value::Str("a").cast()
  inspect(IntoValue::into_value(item).repr(), content="cell(body: [a])")
  let header = Content::new(grid_header_elem(), [
    (grid_header_elem_children, Value::Array(Arr::new())),
  ])
  inspect(
    grid_cast_msg(() => {
      let _ : GridItem = Value::Content(header).cast()
    }),
    content="cannot place a grid header within another header or footer",
  )
  let cell = TableCell::new(Content::empty()).0
  inspect(
    grid_cast_msg(() => {
      let _ : GridChild = Value::Content(cell).cast()
    }),
    content="cannot use `table.cell` as a grid cell | use `grid.cell` instead",
  )
  inspect(
    grid_cast_msg(() => {
      let _ : TableChild = Value::Content(header).cast()
    }),
    content="cannot use `grid.header` as a table header | use `table.header` instead",
  )
}
