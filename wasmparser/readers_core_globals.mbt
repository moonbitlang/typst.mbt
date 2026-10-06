// Port of wasmparser 0.228.0 `src/readers/core/globals.rs`.

///|
/// Represents a core WebAssembly global.
pub(all) struct Global {
  /// The global's type.
  ty : GlobalType
  /// The global's initialization expression.
  init_expr : ConstExpr
}

///|
pub impl FromReader for Global with fn from_reader(reader) {
  let ty = GlobalType::from_reader(reader)
  let init_expr = ConstExpr::from_reader(reader)
  { ty, init_expr, }
}

///|
#deprecated("call as `FromReader::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Global with FromReader::{from_reader}

///|
pub impl FromReader for GlobalType with fn from_reader(reader) {
  let content_type = ValType::from_reader(reader)
  let flags = reader.read_u8()
  if reader.features.shared_everything_threads() {
    if flags > 0b11 {
      bail(reader.original_position() - 1, "malformed global flags")
    }
  } else if flags > 0b1 {
    bail(
      reader.original_position() - 1,
      "malformed mutability -- or shared globals require the shared-everything-threads proposal",
    )
  }
  { content_type, mutable: (flags & 0b01) > 0, shared: (flags & 0b10) > 0, }
}

///|
pub extend GlobalType with FromReader::{from_reader}
