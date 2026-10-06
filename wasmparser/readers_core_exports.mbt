// Port of wasmparser 0.228.0 `src/readers/core/exports.rs`.

///|
/// External types as defined [here].
///
/// [here]: https://webassembly.github.io/spec/core/syntax/types.html#external-types
pub(all) enum ExternalKind {
  /// The external kind is a function.
  Func
  /// The external kind if a table.
  Table
  /// The external kind is a memory.
  Memory
  /// The external kind is a global.
  Global
  /// The external kind is a tag.
  Tag
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ExternalKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ExternalKind with @debug.Debug::{to_repr}

///|
/// Represents an export in a WebAssembly module.
pub(all) struct Export {
  /// The name of the exported item.
  name : String
  /// The kind of the export.
  kind : ExternalKind
  /// The index of the exported item.
  index : UInt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Export with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Export with @debug.Debug::{to_repr}

///|
pub impl FromReader for Export with fn from_reader(reader) {
  let name = reader.read_string()
  let kind = ExternalKind::from_reader(reader)
  let index = reader.read_var_u32()
  { name, kind, index, }
}

///|
#deprecated("call as `FromReader::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Export with FromReader::{from_reader}

///|
pub impl FromReader for ExternalKind with fn from_reader(reader) {
  let offset = reader.original_position()
  let byte = reader.read_u8()
  BinaryReader::external_kind_from_byte(byte, offset)
}

///|
pub extend ExternalKind with FromReader::{from_reader}
