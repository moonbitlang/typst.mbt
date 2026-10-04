// Port of wasmparser 0.228.0 `src/readers/core/imports.rs`.

///|
/// Represents a reference to a type definition in a WebAssembly module.
pub(all) enum TypeRef {
  /// The type is a function.
  ///
  /// The value is an index into the type section.
  Func(UInt)
  /// The type is a table.
  Table(TableType)
  /// The type is a memory.
  Memory(MemoryType)
  /// The type is a global.
  Global(GlobalType)
  /// The type is a tag.
  ///
  /// This variant is only used for the exception handling proposal.
  ///
  /// The value is an index in the types index space.
  Tag(TagType)
} derive(Eq, Debug)

///|
/// Represents an import in a WebAssembly module.
pub(all) struct Import {
  /// The module being imported from.
  module_ : String
  /// The name of the imported item.
  name : String
  /// The type of the imported item.
  ty : TypeRef
} derive(Eq, Debug)

///|
pub impl FromReader for Import with fn from_reader(reader) {
  let module_ = reader.read_string()
  let name = reader.read_string()
  let ty = TypeRef::from_reader(reader)
  { module_, name, ty, }
}

///|
pub impl FromReader for TypeRef with fn from_reader(reader) {
  match ExternalKind::from_reader(reader) {
    Func => Func(reader.read_var_u32())
    Table => Table(TableType::from_reader(reader))
    Memory => Memory(MemoryType::from_reader(reader))
    Global => Global(GlobalType::from_reader(reader))
    Tag => Tag(TagType::from_reader(reader))
  }
}
