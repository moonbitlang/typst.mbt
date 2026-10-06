// Port of wasmparser 0.228.0 `src/readers/core/tables.rs`.

///|
/// Type information about a table defined in the table section of a
/// WebAssembly module.
pub(all) struct Table {
  /// The type of this table, including its element type and its limits.
  ty : TableType
  /// The initialization expression for the table.
  init : TableInit
}

///|
/// Different modes of initializing a table.
pub(all) enum TableInit {
  /// The table is initialized to all null elements.
  RefNull
  /// Each element in the table is initialized with the specified constant
  /// expression.
  Expr(ConstExpr)
}

///|
pub impl FromReader for Table with fn from_reader(reader) {
  let has_init_expr = if reader.peek() == 0x40 {
    reader.read_u8() |> ignore
    true
  } else {
    false
  }
  if has_init_expr {
    if reader.read_u8() != 0x00 {
      bail(reader.original_position() - 1, "invalid table encoding")
    }
  }
  let ty = TableType::from_reader(reader)
  let init : TableInit = if has_init_expr {
    Expr(ConstExpr::from_reader(reader))
  } else {
    RefNull
  }
  { ty, init, }
}

///|
pub impl FromReader for TableType with fn from_reader(reader) {
  let element_type = RefType::from_reader(reader)
  let pos = reader.original_position()
  let flags = reader.read_u8()
  if (flags & 0b11111000) != 0 {
    bail(pos, "invalid table resizable limits flags")
  }
  let has_max = (flags & 0b001) != 0
  let shared = (flags & 0b010) != 0
  let table64 = (flags & 0b100) != 0
  let initial = if table64 {
    reader.read_var_u64()
  } else {
    reader.read_var_u32().to_uint64()
  }
  let maximum = if !has_max {
    None
  } else if table64 {
    Some(reader.read_var_u64())
  } else {
    Some(reader.read_var_u32().to_uint64())
  }
  { element_type, table64, initial, maximum, shared, }
}

///|
pub extend TableType with FromReader::{from_reader}
