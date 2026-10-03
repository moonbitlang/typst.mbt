// Port of wasmparser 0.228.0 `src/readers/core/{code,custom,data,elements,
// exports,functions,globals,imports,init,memories,tables,tags}.rs`.

// --- code.rs ---

///|
/// Represents a WebAssembly function body.
pub struct FunctionBody {
  priv reader : BinaryReader
}

///|
/// Constructs a new `FunctionBody` for the given data and offset.
pub fn FunctionBody::new(reader : BinaryReader) -> FunctionBody {
  { reader, }
}

///|
/// Gets a binary reader for this function body.
pub fn FunctionBody::get_binary_reader(self : FunctionBody) -> BinaryReader {
  self.reader.clone()
}

///|
fn FunctionBody::skip_locals(
  reader : BinaryReader,
) -> Unit raise BinaryReaderError {
  let count = reader.read_var_u32()
  for _ in 0U..<count {
    reader.read_var_u32() |> ignore
    ValType::from_reader(reader) |> ignore
  }
}

///|
/// Gets the locals reader for this function body.
pub fn FunctionBody::get_locals_reader(
  self : FunctionBody,
) -> LocalsReader raise BinaryReaderError {
  let reader = self.reader.clone()
  let count = reader.read_var_u32()
  { reader, count, }
}

///|
/// Gets the operators reader for this function body, after skipping all
/// locals.
pub fn FunctionBody::get_operators_reader(
  self : FunctionBody,
) -> OperatorsReader raise BinaryReaderError {
  let reader = self.reader.clone()
  FunctionBody::skip_locals(reader)
  OperatorsReader::new(reader)
}

///|
/// Gets the range of the function body.
pub fn FunctionBody::range(self : FunctionBody) -> Range {
  self.reader.range()
}

///|
/// Returns the body of this function as a list of bytes.
///
/// Note that the returned bytes start with the function locals declaration.
pub fn FunctionBody::as_bytes(self : FunctionBody) -> BytesView {
  self.reader.remaining_buffer()
}

///|
pub impl FromReader for FunctionBody with fn from_reader(reader) {
  let reader = reader.read_reader()
  { reader, }
}

///|
/// A reader for a function body's locals.
pub struct LocalsReader {
  priv reader : BinaryReader
  priv count : UInt
}

///|
/// Gets the count of locals in the function body.
pub fn LocalsReader::get_count(self : LocalsReader) -> UInt {
  self.count
}

///|
/// Gets the original position of the reader.
pub fn LocalsReader::original_position(self : LocalsReader) -> Int {
  self.reader.original_position()
}

///|
/// Reads an item from the reader.
pub fn LocalsReader::read(
  self : LocalsReader,
) -> (UInt, ValType) raise BinaryReaderError {
  let count = self.reader.read_var_u32()
  let value_type = ValType::from_reader(self.reader)
  (count, value_type)
}

// --- custom.rs ---

///|
/// A reader for custom sections of a WebAssembly module.
pub struct CustomSectionReader {
  priv name : String
  priv reader : BinaryReader
}

///|
/// Constructs a new `CustomSectionReader` for the given data and offset.
pub fn CustomSectionReader::new(
  reader : BinaryReader,
) -> CustomSectionReader raise BinaryReaderError {
  let name = reader.read_string()
  { name, reader, }
}

///|
/// The name of the custom section.
pub fn CustomSectionReader::name(self : CustomSectionReader) -> String {
  self.name
}

///|
/// The offset, relative to the start of the original module or component,
/// that the `data` payload for this custom section starts at.
pub fn CustomSectionReader::data_offset(self : CustomSectionReader) -> Int {
  self.reader.original_position()
}

///|
/// The actual contents of the custom section.
pub fn CustomSectionReader::data(self : CustomSectionReader) -> BytesView {
  self.reader.remaining_buffer()
}

///|
/// The range of bytes that specify this whole custom section (including
/// both the name of this custom section and its data) specified in
/// offsets relative to the start of the byte stream.
pub fn CustomSectionReader::range(self : CustomSectionReader) -> Range {
  self.reader.range()
}

// --- data.rs ---

///|
/// Represents a data segment in a core WebAssembly module.
pub(all) struct Data {
  /// The kind of data segment.
  kind : DataKind
  /// The data of the data segment.
  data : BytesView
  /// The range of the data segment.
  range : Range
}

///|
/// The kind of data segment.
pub(all) enum DataKind {
  /// The data segment is passive.
  Passive
  /// The data segment is active.
  Active(memory_index~ : UInt, offset_expr~ : ConstExpr)
}

///|
pub impl FromReader for Data with fn from_reader(reader) {
  let segment_start = reader.original_position()

  // The current handling of the flags is largely specified in the `bulk-memory` proposal,
  // which at the time this comment is written has been merged to the main specification
  // draft.
  //
  // Notably, this proposal allows multiple different encodings of the memory index 0. `00`
  // and `02 00` are both valid ways to specify the 0-th memory. However it also makes
  // another encoding of the 0-th memory `80 00` no longer valid.
  //
  // We, however maintain this by parsing `flags` as a LEB128 integer. In that case, `80 00`
  // encoding is parsed out as `0` and is therefore assigned a `memidx` 0, even though the
  // current specification draft does not allow for this.
  //
  // See also https://github.com/WebAssembly/spec/issues/1439
  let flags = reader.read_var_u32()
  let kind : DataKind = match flags {
    1 => Passive
    0 | 2 => {
      let memory_index = if flags == 0 { 0U } else { reader.read_var_u32() }
      let offset_expr = ConstExpr::from_reader(reader)
      Active(memory_index~, offset_expr~)
    }
    _ =>
      raise BinaryReaderError::new(
        "invalid flags byte in data segment", segment_start,
      )
  }
  let data = reader.read_reader()
  {
    kind,
    data: data.remaining_buffer(),
    range: { start: segment_start, end: data.range().end, },
  }
}

// --- elements.rs ---

///|
/// Represents a core WebAssembly element segment.
pub(all) struct Element {
  /// The kind of the element segment.
  kind : ElementKind
  /// The initial elements of the element segment.
  items : ElementItems
  /// The range of the the element segment.
  range : Range
}

///|
/// The kind of element segment.
pub(all) enum ElementKind {
  /// The element segment is passive.
  Passive
  /// The element segment is active.
  Active(table_index~ : UInt?, offset_expr~ : ConstExpr)
  /// The element segment is declared.
  Declared
}

///|
/// Represents the items of an element segment.
pub(all) enum ElementItems {
  /// This element contains function indices.
  Functions(SectionLimited[UInt])
  /// This element contains constant expressions used to initialize the table.
  Expressions(RefType, SectionLimited[ConstExpr])
}

///|
pub impl FromReader for Element with fn from_reader(reader) {
  let elem_start = reader.original_position()
  // The current handling of the flags is largely specified in the `bulk-memory` proposal,
  // which at the time this commend is written has been merged to the main specification
  // draft.
  //
  // Notably, this proposal allows multiple different encodings of the table index 0. `00`
  // and `02 00` are both valid ways to specify the 0-th table. However it also makes
  // another encoding of the 0-th memory `80 00` no longer valid.
  //
  // We, however maintain this support by parsing `flags` as a LEB128 integer. In that case,
  // `80 00` encoding is parsed out as `0` and is therefore assigned a `tableidx` 0, even
  // though the current specification draft does not allow for this.
  //
  // See also https://github.com/WebAssembly/spec/issues/1439
  let flags = reader.read_var_u32()
  if (flags & 0b111U.lnot()) != 0 {
    raise BinaryReaderError::new(
      "invalid flags byte in element segment",
      reader.original_position() - 1,
    )
  }
  let kind : ElementKind = if (flags & 0b001) != 0 {
    if (flags & 0b010) != 0 {
      Declared
    } else {
      Passive
    }
  } else {
    let table_index = if (flags & 0b010) == 0 {
      None
    } else {
      Some(reader.read_var_u32())
    }
    let offset_expr = ConstExpr::from_reader(reader)
    Active(table_index~, offset_expr~)
  }
  let exprs = (flags & 0b100) != 0
  let ty = if (flags & 0b011) != 0 {
    if exprs {
      Some(RefType::from_reader(reader))
    } else {
      match ExternalKind::from_reader(reader) {
        Func => None
        _ =>
          raise BinaryReaderError::new(
            "only the function external type is supported in elem segment",
            reader.original_position() - 1,
          )
      }
    }
  } else {
    None
  }
  // FIXME(#188) ideally wouldn't have to do skips here
  let data = reader.skip(reader => {
    let items_count = reader.read_var_u32()
    if exprs {
      for _ in 0U..<items_count {
        reader.skip_const_expr()
      }
    } else {
      for _ in 0U..<items_count {
        reader.read_var_u32() |> ignore
      }
    }
  })
  let items : ElementItems = if exprs {
    Expressions(ty.unwrap_or(reftype_funcref), SectionLimited::new(data))
  } else {
    if !(ty is None) {
      abort("assertion failed: ty is None")
    }
    Functions(SectionLimited::new(data))
  }
  let elem_end = reader.original_position()
  let range = { start: elem_start, end: elem_end, }
  { kind, items, range, }
}

// --- exports.rs ---

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
pub impl FromReader for Export with fn from_reader(reader) {
  let name = reader.read_string()
  let kind = ExternalKind::from_reader(reader)
  let index = reader.read_var_u32()
  { name, kind, index, }
}

///|
pub impl FromReader for ExternalKind with fn from_reader(reader) {
  let offset = reader.original_position()
  let byte = reader.read_u8()
  BinaryReader::external_kind_from_byte(byte, offset)
}

// --- globals.rs ---

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

// --- imports.rs ---

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

// --- init.rs ---

///|
/// Represents an initialization expression.
pub struct ConstExpr {
  priv reader : BinaryReader
}

///|
pub impl Eq for ConstExpr with fn equal(self, other) {
  self.reader.remaining_buffer() == other.reader.remaining_buffer()
}

///|
/// Constructs a new `ConstExpr` from the given data and offset.
pub fn ConstExpr::new(reader : BinaryReader) -> ConstExpr {
  { reader, }
}

///|
/// Gets a binary reader for the initialization expression.
pub fn ConstExpr::get_binary_reader(self : ConstExpr) -> BinaryReader {
  self.reader.clone()
}

///|
/// Gets an operators reader for the initialization expression.
pub fn ConstExpr::get_operators_reader(self : ConstExpr) -> OperatorsReader {
  OperatorsReader::new(self.get_binary_reader())
}

///|
pub impl FromReader for ConstExpr with fn from_reader(reader) {
  // FIXME(#188) ideally shouldn't need to skip here
  let reader = reader.skip(r => r.skip_const_expr())
  { reader, }
}

// --- memories.rs ---

///|
pub impl FromReader for MemoryType with fn from_reader(reader) {
  let pos = reader.original_position()
  let flags = reader.read_u8()
  if (flags & 0b11110000) != 0 {
    bail(pos, "invalid memory limits flags")
  }
  let memory64 = (flags & 0b0100) != 0
  let shared = (flags & 0b0010) != 0
  let has_max = (flags & 0b0001) != 0
  let has_page_size = (flags & 0b1000) != 0
  let initial = if memory64 {
    reader.read_var_u64()
  } else {
    reader.read_var_u32().to_uint64()
  }
  let maximum = if !has_max {
    None
  } else if memory64 {
    Some(reader.read_var_u64())
  } else {
    Some(reader.read_var_u32().to_uint64())
  }
  let page_size_log2 = if has_page_size {
    Some(reader.read_var_u32())
  } else {
    None
  }
  { memory64, shared, initial, maximum, page_size_log2, }
}

// --- tables.rs ---

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

// --- tags.rs ---

///|
pub impl FromReader for TagType with fn from_reader(reader) {
  let attribute = reader.read_u8()
  if attribute != 0 {
    bail(reader.original_position() - 1, "invalid tag attributes")
  }
  { kind: Exception, func_type_idx: reader.read_var_u32(), }
}

// --- Section reader aliases (upstream `<Name>SectionReader<'a>`) ---

///|
/// A reader for the import section of a WebAssembly module.
pub type ImportSectionReader = SectionLimited[Import]

///|
/// A reader for the function section of a WebAssembly module.
pub type FunctionSectionReader = SectionLimited[UInt]

///|
/// A reader for the table section of a WebAssembly module.
pub type TableSectionReader = SectionLimited[Table]

///|
/// A reader for the memory section of a WebAssembly module.
pub type MemorySectionReader = SectionLimited[MemoryType]

///|
/// A reader for the tag section of a WebAssembly module.
pub type TagSectionReader = SectionLimited[TagType]

///|
/// A reader for the global section of a WebAssembly module.
pub type GlobalSectionReader = SectionLimited[Global]

///|
/// A reader for the export section of a WebAssembly module.
pub type ExportSectionReader = SectionLimited[Export]

///|
/// A reader for the element section of a WebAssembly module.
pub type ElementSectionReader = SectionLimited[Element]

///|
/// A reader for the code section of a WebAssembly module.
pub type CodeSectionReader = SectionLimited[FunctionBody]

///|
/// A reader for the data section of a WebAssembly module.
pub type DataSectionReader = SectionLimited[Data]
