// Port of wasmparser 0.228.0 `src/validator/core.rs`: state relating to
// validating a WebAssembly module.

///|
// Section order for WebAssembly modules.
//
// Component sections are unordered and allow for duplicates,
// so this isn't used for components.
priv enum Order {
  Initial
  Type
  Import
  Function
  Table
  Memory
  Tag
  Global
  Export
  Start
  Element
  DataCount
  Code
  Data
} derive(Eq)

///|
fn Order::rank(self : Order) -> Int {
  match self {
    Initial => 0
    Type => 1
    Import => 2
    Function => 3
    Table => 4
    Memory => 5
    Tag => 6
    Global => 7
    Export => 8
    Start => 9
    Element => 10
    DataCount => 11
    Code => 12
    Data => 13
  }
}

///|
priv struct ModuleState {
  /// Internal state that is incrementally built-up for the module being
  /// validated. This houses type information for all wasm items, like
  /// functions. Note that this starts out as a solely owned `Arc<T>` so we can
  /// get mutable access, but after we get to the code section this is never
  /// mutated to we can clone it cheaply and hand it to sub-validators.
  module_ : Module
  /// Where we are, order-wise, in the wasm binary.
  mut order : Order
  /// The number of data segments in the data section (if present).
  mut data_segment_count : UInt
  /// The number of functions we expect to be defined in the code section, or
  /// basically the length of the function section if it was found. The next
  /// index is where we are, in the code section index space, for the next
  /// entry in the code section (used to figure out what type is next for the
  /// function being validated).
  mut expected_code_bodies : UInt?
  mut const_expr_allocs : OperatorValidatorAllocations
  /// When parsing the code section, represents the current index in the section.
  mut code_section_index : Int?
}

///|
fn ModuleState::default() -> ModuleState {
  {
    module_: Module::default(),
    order: Initial,
    data_segment_count: 0,
    expected_code_bodies: None,
    const_expr_allocs: OperatorValidatorAllocations::default(),
    code_section_index: None,
  }
}

///|
fn ModuleState::update_order(
  self : ModuleState,
  order : Order,
  offset : Int,
) -> Unit raise BinaryReaderError {
  if self.order.rank() >= order.rank() {
    raise BinaryReaderError::new("section out of order", offset)
  }
  self.order = order
}

///|
fn ModuleState::validate_end(
  self : ModuleState,
  offset : Int,
) -> Unit raise BinaryReaderError {
  // Ensure that the data count section, if any, was correct.
  if self.module_.data_count is Some(data_count) {
    if data_count != self.data_segment_count {
      raise BinaryReaderError::new(
        "data count and data section have inconsistent lengths", offset,
      )
    }
  }
  // Ensure that the function section, if nonzero, was paired with a code
  // section with the appropriate length.
  if self.expected_code_bodies is Some(n) {
    if n > 0 {
      raise BinaryReaderError::new(
        "function and code section have inconsistent lengths", offset,
      )
    }
  }
}

///|
fn ModuleState::next_code_index_and_type(
  self : ModuleState,
  offset : Int,
) -> (UInt, UInt) raise BinaryReaderError {
  let index = match self.code_section_index {
    Some(i) => i
    None => self.module_.num_imported_functions.reinterpret_as_int()
  }
  if index >= self.module_.functions.length() {
    raise BinaryReaderError::new(
      "code section entry exceeds number of functions", offset,
    )
  }
  let ty = self.module_.functions[index]
  self.code_section_index = Some(index + 1)
  (index.reinterpret_as_uint(), ty)
}

///|
fn ModuleState::add_global(
  self : ModuleState,
  global : Global,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.module_.check_global_type(global.ty, features, types, offset)
  self.check_const_expr(
    global.init_expr,
    global.ty.content_type,
    features,
    types,
  )
  self.module_.globals.push(global.ty)
}

///|
fn ModuleState::add_table(
  self : ModuleState,
  table : Table,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.module_.check_table_type(table.ty, features, types, offset)
  match table.init {
    RefNull =>
      if !table.ty.element_type.is_nullable() {
        bail(offset, "type mismatch: non-defaultable element type")
      }
    Expr(expr) => {
      if !features.function_references() {
        bail(
          offset, "tables with expression initializers require the function-references proposal",
        )
      }
      self.check_const_expr(expr, Ref(table.ty.element_type), features, types)
    }
  }
  self.module_.tables.push(table.ty)
}

///|
fn ModuleState::add_data_segment(
  self : ModuleState,
  data : Data,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  match data.kind {
    Passive => ()
    Active(memory_index~, offset_expr~) => {
      let ty = self.module_.memory_at(memory_index, offset).index_type()
      self.check_const_expr(offset_expr, ty, features, types)
    }
  }
}

///|
fn ModuleState::add_element_segment(
  self : ModuleState,
  e : Element,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  // the `funcref` value type is allowed all the way back to the MVP, so
  // don't check it here
  let (element_ty, items) = match e.items {
    Functions(_) => (reftype_func, e.items)
    Expressions(ty, reader) => {
      let ty = self.module_.check_ref_type(ty, features, offset)
      (ty, ElementItems::Expressions(ty, reader))
    }
  }
  match e.kind {
    Active(table_index~, offset_expr~) => {
      let table = self.module_.table_at(table_index.unwrap_or(0), offset)
      if !types.reftype_is_subtype(element_ty, table.element_type) {
        raise BinaryReaderError::new(
          "type mismatch: invalid element type `\{ty_to_str(Ref(element_ty))}` for table type `\{ty_to_str(Ref(table.element_type))}`",
          offset,
        )
      }
      self.check_const_expr(offset_expr, table.index_type(), features, types)
    }
    Passive | Declared =>
      if !features.bulk_memory() {
        raise BinaryReaderError::new("bulk memory must be enabled", offset)
      }
  }
  let validate_count = (count : UInt) => {
    if count > MAX_WASM_TABLE_ENTRIES.reinterpret_as_uint() {
      raise BinaryReaderError::new(
        "number of elements is out of bounds", offset,
      )
    }
  }
  match items {
    Functions(reader) => {
      let count = reader.count()
      validate_count(count)
      let iter = reader.into_iter()
      while iter.next_with_offset() is Some((offset, f)) {
        self.module_.get_func_type(f, types, offset) |> ignore
        self.module_.function_references.add(f)
      }
    }
    Expressions(ty, reader) => {
      validate_count(reader.count())
      let iter = reader.into_iter()
      while iter.next() is Some(expr) {
        self.check_const_expr(expr, Ref(ty), features, types)
      }
    }
  }
  self.module_.element_types.push(element_ty)
}

///|
fn ModuleState::check_const_expr(
  self : ModuleState,
  expr : ConstExpr,
  expected_ty : ValType,
  features : WasmFeatures,
  types : TypeList,
) -> Unit raise BinaryReaderError {
  let allocs = self.const_expr_allocs
  self.const_expr_allocs = OperatorValidatorAllocations::default()
  let validator : VisitConstOperator = {
    offset: 0,
    order: self.order,
    uninserted_funcref: false,
    ops: OperatorValidator::new_const_expr(features, expected_ty, allocs),
    resources: { module_: self.module_, types, },
    features,
  }
  let ops = expr.get_operators_reader()
  while !ops.eof() {
    validator.offset = ops.original_position()
    let op = ops.read()
    validator.visit_operator(op)
  }
  validator.ops.finish(ops.original_position())

  // See comment in `RefFunc` below for why this is an assert.
  guard !validator.uninserted_funcref
  self.const_expr_allocs = validator.ops.into_allocations()
}

///|
priv struct VisitConstOperator {
  mut offset : Int
  mut uninserted_funcref : Bool
  ops : OperatorValidator
  resources : ValidatorResources
  order : Order
  features : WasmFeatures
}

///|
fn VisitConstOperator::validator(
  self : VisitConstOperator,
) -> WasmProposalValidator {
  self.ops.with_resources(self.resources, self.offset)
}

///|
fn VisitConstOperator::validate_extended_const(
  self : VisitConstOperator,
  op : String,
) -> Unit raise BinaryReaderError {
  if self.ops.features.extended_const() {
    ()
  } else {
    raise BinaryReaderError::new(
      "constant expression required: non-constant operator: \{op}",
      self.offset,
    )
  }
}

///|
fn VisitConstOperator::validate_gc(
  self : VisitConstOperator,
  op : String,
) -> Unit raise BinaryReaderError {
  if self.features.gc() {
    ()
  } else {
    raise BinaryReaderError::new(
      "constant expression required: non-constant operator: \{op}",
      self.offset,
    )
  }
}

///|
fn VisitConstOperator::validate_shared_everything_threads(
  self : VisitConstOperator,
  op : String,
) -> Unit raise BinaryReaderError {
  if self.features.shared_everything_threads() {
    ()
  } else {
    raise BinaryReaderError::new(
      "constant expression required: non-constant operator: \{op}",
      self.offset,
    )
  }
}

///|
fn VisitConstOperator::validate_global(
  self : VisitConstOperator,
  index : UInt,
) -> Unit raise BinaryReaderError {
  let module_ = self.resources.module_
  let global = module_.global_at(index, self.offset)
  if index >= module_.num_imported_globals && !self.features.gc() {
    raise BinaryReaderError::new(
      "constant expression required: global.get of locally defined global",
      self.offset,
    )
  }
  if global.mutable {
    raise BinaryReaderError::new(
      "constant expression required: global.get of mutable global",
      self.offset,
    )
  }
}

///|
// Functions in initialization expressions are only valid in
// element segment initialization expressions and globals. In
// these contexts we want to record all function references.
//
// Initialization expressions can also be found in the data
// section, however. A `RefFunc` instruction in those situations
// is always invalid and needs to produce a validation error. In
// this situation, though, we can no longer modify
// the state since it's been "snapshot" already for
// parallel validation of functions.
//
// If we cannot modify the function references then this function
// *should* result in a validation error, but we defer that
// validation error to happen later. The `uninserted_funcref`
// boolean here is used to track this and will cause a panic
// (aka a fuzz bug) if we somehow forget to emit an error somewhere
// else.
fn VisitConstOperator::insert_ref_func(
  self : VisitConstOperator,
  index : UInt,
) -> Unit {
  if self.order == Data {
    self.uninserted_funcref = true
  } else {
    self.resources.module_.function_references.add(index)
  }
}

///|
fn VisitConstOperator::not_const(
  self : VisitConstOperator,
  instr : String,
) -> BinaryReaderError {
  BinaryReaderError::new(
    "constant expression required: non-constant operator: \{instr}",
    self.offset,
  )
}

///|
pub(all) struct Module {
  // This is set once the code section starts.
  // `WasmModuleResources` implementations use the snapshot to
  // enable parallel validation of functions.
  mut snapshot : TypeList?
  // Stores indexes into the validator's types list.
  types : Array[CoreTypeId]
  tables : Array[TableType]
  memories : Array[MemoryType]
  globals : Array[GlobalType]
  element_types : Array[RefType]
  mut data_count : UInt?
  // Stores indexes into `types`.
  functions : Array[UInt]
  tags : Array[CoreTypeId]
  function_references : @hashset.HashSet[UInt]
  imports : Map[(String, String), Array[EntityType]]
  exports : Map[String, EntityType]
  mut type_size : UInt
  mut num_imported_globals : UInt
  mut num_imported_functions : UInt
}

///|
fn Module::default() -> Module {
  {
    snapshot: None,
    types: [],
    tables: [],
    memories: [],
    globals: [],
    element_types: [],
    data_count: None,
    functions: [],
    tags: [],
    function_references: @hashset.new(),
    imports: {},
    exports: {},
    type_size: 1,
    num_imported_globals: 0,
    num_imported_functions: 0,
  }
}

///|
fn Module::add_types(
  self : Module,
  rec_group : RecGroup,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
  check_limit : Bool,
) -> Unit raise BinaryReaderError {
  if check_limit {
    check_max(
      self.types.length(),
      rec_group.len().reinterpret_as_uint(),
      MAX_WASM_TYPES,
      "types",
      offset,
    )
  }
  self.canonicalize_and_intern_rec_group(features, types, rec_group, offset)
}

///|
fn Module::add_import(
  self : Module,
  import_ : Import,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  let entity = self.check_type_ref(import_.ty, features, types, offset)
  let (len, max, desc) = match import_.ty {
    Func(type_index) => {
      self.functions.push(type_index)
      self.num_imported_functions += 1
      (self.functions.length(), MAX_WASM_FUNCTIONS, "functions")
    }
    Table(ty) => {
      self.tables.push(ty)
      (self.tables.length(), self.max_tables(features), "tables")
    }
    Memory(ty) => {
      self.memories.push(ty)
      (self.memories.length(), self.max_memories(features), "memories")
    }
    Tag(ty) => {
      self.tags.push(self.types[ty.func_type_idx.reinterpret_as_int()])
      (self.tags.length(), MAX_WASM_TAGS, "tags")
    }
    Global(ty) => {
      if !features.mutable_global() && ty.mutable {
        raise BinaryReaderError::new(
          "mutable global support is not enabled", offset,
        )
      }
      self.globals.push(ty)
      self.num_imported_globals += 1
      (self.globals.length(), MAX_WASM_GLOBALS, "globals")
    }
  }
  check_max(len, 0, max, desc, offset)
  self.type_size = combine_type_sizes(
    self.type_size,
    entity.info(types).size(),
    offset,
  )
  let key = (import_.module_, import_.name)
  match self.imports.get(key) {
    Some(list) => list.push(entity)
    None => self.imports.set(key, [entity])
  }
}

///|
fn Module::add_export(
  self : Module,
  name : String,
  ty : EntityType,
  features : WasmFeatures,
  offset : Int,
  check_limit : Bool,
  types : TypeList,
) -> Unit raise BinaryReaderError {
  if !features.mutable_global() {
    if ty is Global(global_type) && global_type.mutable {
      raise BinaryReaderError::new(
        "mutable global support is not enabled", offset,
      )
    }
  }
  if check_limit {
    check_max(self.exports.length(), 1, MAX_WASM_EXPORTS, "exports", offset)
  }
  self.type_size = combine_type_sizes(
    self.type_size,
    ty.info(types).size(),
    offset,
  )
  let duplicate = self.exports.contains(name)
  self.exports.set(name, ty)
  if duplicate {
    bail(offset, "duplicate export name `\{name}` already defined")
  }
}

///|
fn Module::add_function(
  self : Module,
  type_index : UInt,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.func_type_at(type_index, types, offset) |> ignore
  self.functions.push(type_index)
}

///|
fn Module::add_memory(
  self : Module,
  ty : MemoryType,
  features : WasmFeatures,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.check_memory_type(ty, features, offset)
  self.memories.push(ty)
}

///|
fn Module::add_tag(
  self : Module,
  ty : TagType,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.check_tag_type(ty, features, types, offset)
  self.tags.push(self.types[ty.func_type_idx.reinterpret_as_int()])
}

///|
fn Module::sub_type_at(
  self : Module,
  types : TypeList,
  idx : UInt,
  offset : Int,
) -> SubType raise BinaryReaderError {
  let id = self.type_id_at(idx, offset)
  types.get_core(id)
}

///|
fn Module::func_type_at(
  self : Module,
  type_index : UInt,
  types : TypeList,
  offset : Int,
) -> FuncType raise BinaryReaderError {
  match self.sub_type_at(types, type_index, offset).composite_type.inner {
    Func(f) => f
    _ => bail(offset, "type index \{type_index} is not a function type")
  }
}

///|
fn Module::check_type_ref(
  self : Module,
  type_ref : TypeRef,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> EntityType raise BinaryReaderError {
  match type_ref {
    Func(type_index) => {
      self.func_type_at(type_index, types, offset) |> ignore
      Func(self.types[type_index.reinterpret_as_int()])
    }
    Table(t) => {
      self.check_table_type(t, features, types, offset)
      Table(t)
    }
    Memory(t) => {
      self.check_memory_type(t, features, offset)
      Memory(t)
    }
    Tag(t) => {
      self.check_tag_type(t, features, types, offset)
      Tag(self.types[t.func_type_idx.reinterpret_as_int()])
    }
    Global(t) => {
      self.check_global_type(t, features, types, offset)
      Global(t)
    }
  }
}

///|
fn Module::check_table_type(
  self : Module,
  ty : TableType,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  // The `funcref` value type is allowed all the way back to the MVP, so
  // don't check it here.
  if ty.element_type != reftype_funcref {
    ty.element_type = self.check_ref_type(ty.element_type, features, offset)
  }
  if ty.table64 && !features.memory64() {
    raise BinaryReaderError::new(
      "memory64 must be enabled for 64-bit tables", offset,
    )
  }
  self.check_limits(ty.initial, ty.maximum, offset)
  if ty.shared {
    if !features.shared_everything_threads() {
      raise BinaryReaderError::new(
        "shared tables require the shared-everything-threads proposal", offset,
      )
    }
    if !types.reftype_is_shared(ty.element_type) {
      raise BinaryReaderError::new(
        "shared tables must have a shared element type", offset,
      )
    }
  }
}

///|
fn Module::check_memory_type(
  self : Module,
  ty : MemoryType,
  features : WasmFeatures,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.check_limits(ty.initial, ty.maximum, offset)
  let (page_size, page_size_log2) = if ty.page_size_log2 is Some(page_size_log2) {
    if !features.custom_page_sizes() {
      raise BinaryReaderError::new(
        "the custom page sizes proposal must be enabled to customize a memory's page size",
        offset,
      )
    }
    // Currently 2**0 and 2**16 are the only valid page sizes, but this
    // may be relaxed to allow any power of two in the future.
    if page_size_log2 != 0 && page_size_log2 != 16 {
      raise BinaryReaderError::new("invalid custom page size", offset)
    }
    let page_size = 1UL << page_size_log2.reinterpret_as_int()
    (page_size, page_size_log2)
  } else {
    let page_size_log2 = 16U
    (DEFAULT_WASM_PAGE_SIZE, page_size_log2)
  }
  let (true_maximum, err) = if ty.memory64 {
    if !features.memory64() {
      raise BinaryReaderError::new(
        "memory64 must be enabled for 64-bit memories", offset,
      )
    }
    (
      max_wasm_memory64_pages(page_size),
      "memory size must be at most 2**\{64U - page_size_log2} pages",
    )
  } else {
    let max = max_wasm_memory32_pages(page_size)
    (max, "memory size must be at most \{max} pages (4GiB)")
  }
  if ty.initial > true_maximum {
    raise BinaryReaderError::new(err, offset)
  }
  if ty.maximum is Some(maximum) {
    if maximum > true_maximum {
      raise BinaryReaderError::new(err, offset)
    }
  }
  if ty.shared {
    if !features.threads() {
      raise BinaryReaderError::new(
        "threads must be enabled for shared memories", offset,
      )
    }
    if ty.maximum is None {
      raise BinaryReaderError::new(
        "shared memory must have maximum size", offset,
      )
    }
  }
}

///|
fn Module::check_value_type(
  self : Module,
  ty : ValType,
  features : WasmFeatures,
  offset : Int,
) -> ValType raise BinaryReaderError {
  // The above only checks the value type for features.
  // We must check it if it's a reference.
  match ty {
    Ref(rt) => Ref(self.check_ref_type(rt, features, offset))
    _ =>
      match features.check_value_type(ty) {
        None => ty
        Some(e) => raise BinaryReaderError::new(e, offset)
      }
  }
}

///|
fn Module::check_ref_type(
  self : Module,
  ty : RefType,
  features : WasmFeatures,
  offset : Int,
) -> RefType raise BinaryReaderError {
  if features.check_ref_type(ty) is Some(e) {
    raise BinaryReaderError::new(e, offset)
  }
  let hty = self.check_heap_type(ty.heap_type(), offset)
  RefType::new(ty.is_nullable(), hty).unwrap()
}

///|
fn Module::check_heap_type(
  self : Module,
  ty : HeapType,
  offset : Int,
) -> HeapType raise BinaryReaderError {
  // Check that the heap type is valid.
  let type_index = match ty {
    Abstract(..) => return ty
    Concrete(type_index) => type_index
  }
  match type_index {
    Module(idx) => {
      let id = self.type_id_at(idx, offset)
      Concrete(Id(id))
    }
    // Types at this stage should not be canonicalized. All
    // canonicalized types should already be validated meaning they
    // shouldn't be double-checked here again.
    RecGroup(_) | Id(_) => abort("unreachable")
  }
}

///|
fn Module::check_tag_type(
  self : Module,
  ty : TagType,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  if !features.exceptions() {
    raise BinaryReaderError::new("exceptions proposal not enabled", offset)
  }
  let ty = self.func_type_at(ty.func_type_idx, types, offset)
  if ty.results().length() != 0 && !features.stack_switching() {
    raise BinaryReaderError::new(
      "invalid exception type: non-empty tag result type", offset,
    )
  }
}

///|
fn Module::check_global_type(
  self : Module,
  ty : GlobalType,
  features : WasmFeatures,
  types : TypeList,
  offset : Int,
) -> Unit raise BinaryReaderError {
  ty.content_type = self.check_value_type(ty.content_type, features, offset)
  if ty.shared {
    if !features.shared_everything_threads() {
      raise BinaryReaderError::new(
        "shared globals require the shared-everything-threads proposal", offset,
      )
    }
    if !types.valtype_is_shared(ty.content_type) {
      raise BinaryReaderError::new(
        "shared globals must have a shared value type", offset,
      )
    }
  }
}

///|
fn Module::check_limits(
  _self : Module,
  initial : UInt64,
  maximum : UInt64?,
  offset : Int,
) -> Unit raise BinaryReaderError {
  if maximum is Some(max) {
    if initial > max {
      raise BinaryReaderError::new(
        "size minimum must not be greater than maximum", offset,
      )
    }
  }
}

///|
fn Module::max_tables(_self : Module, features : WasmFeatures) -> Int {
  if features.reference_types() {
    MAX_WASM_TABLES
  } else {
    1
  }
}

///|
fn Module::max_memories(_self : Module, features : WasmFeatures) -> Int {
  if features.multi_memory() {
    MAX_WASM_MEMORIES
  } else {
    1
  }
}

///|
fn Module::export_to_entity_type(
  self : Module,
  export : Export,
  offset : Int,
) -> EntityType raise BinaryReaderError {
  let check = (ty : String, index : UInt, total : Int) => {
    if index >= total.reinterpret_as_uint() {
      bail(offset, "unknown \{ty} \{index}: exported \{ty} index out of bounds")
    }
  }
  let index = export.index.reinterpret_as_int()
  match export.kind {
    Func => {
      check("function", export.index, self.functions.length())
      self.function_references.add(export.index)
      Func(self.types[self.functions[index].reinterpret_as_int()])
    }
    Table => {
      check("table", export.index, self.tables.length())
      Table(self.tables[index])
    }
    Memory => {
      check("memory", export.index, self.memories.length())
      Memory(self.memories[index])
    }
    Global => {
      check("global", export.index, self.globals.length())
      Global(self.globals[index])
    }
    Tag => {
      check("tag", export.index, self.tags.length())
      Tag(self.tags[index])
    }
  }
}

///|
fn Module::get_func_type(
  self : Module,
  func_idx : UInt,
  types : TypeList,
  offset : Int,
) -> FuncType raise BinaryReaderError {
  if func_idx < self.functions.length().reinterpret_as_uint() {
    self.func_type_at(
      self.functions[func_idx.reinterpret_as_int()],
      types,
      offset,
    )
  } else {
    bail(offset, "unknown function \{func_idx}: func index out of bounds")
  }
}

///|
fn Module::global_at(
  self : Module,
  idx : UInt,
  offset : Int,
) -> GlobalType raise BinaryReaderError {
  if idx < self.globals.length().reinterpret_as_uint() {
    self.globals[idx.reinterpret_as_int()]
  } else {
    bail(offset, "unknown global \{idx}: global index out of bounds")
  }
}

///|
fn Module::table_at(
  self : Module,
  idx : UInt,
  offset : Int,
) -> TableType raise BinaryReaderError {
  if idx < self.tables.length().reinterpret_as_uint() {
    self.tables[idx.reinterpret_as_int()]
  } else {
    bail(offset, "unknown table \{idx}: table index out of bounds")
  }
}

///|
fn Module::memory_at(
  self : Module,
  idx : UInt,
  offset : Int,
) -> MemoryType raise BinaryReaderError {
  if idx < self.memories.length().reinterpret_as_uint() {
    self.memories[idx.reinterpret_as_int()]
  } else {
    bail(offset, "unknown memory \{idx}: memory index out of bounds")
  }
}

///|
/// `InternRecGroup::add_type_id`.
fn Module::add_type_id(self : Module, id : CoreTypeId) -> Unit {
  self.types.push(id)
}

///|
/// `InternRecGroup::type_id_at`.
fn Module::type_id_at(
  self : Module,
  idx : UInt,
  offset : Int,
) -> CoreTypeId raise BinaryReaderError {
  if idx < self.types.length().reinterpret_as_uint() {
    self.types[idx.reinterpret_as_int()]
  } else {
    bail(offset, "unknown type \{idx}: type index out of bounds")
  }
}

///|
/// `InternRecGroup::types_len`.
fn Module::types_len(self : Module) -> UInt {
  self.types.length().reinterpret_as_uint()
}

///|
/// The resources of a module for validating its constant expressions and
/// function bodies (upstream `OperatorValidatorResources` and
/// `ValidatorResources`, both `WasmModuleResources` implementations).
pub struct ValidatorResources {
  priv module_ : Module
  priv types : TypeList
}

///|
/// Returns the table at given index if any.
///
/// The table element type must be canonicalized.
pub fn ValidatorResources::table_at(
  self : ValidatorResources,
  at : UInt,
) -> TableType? {
  self.module_.tables.get(at.reinterpret_as_int())
}

///|
/// Returns the linear memory at given index.
pub fn ValidatorResources::memory_at(
  self : ValidatorResources,
  at : UInt,
) -> MemoryType? {
  if at < self.module_.memories.length().reinterpret_as_uint() {
    Some(self.module_.memories[at.reinterpret_as_int()])
  } else {
    None
  }
}

///|
/// Returns the tag at given index.
///
/// The tag's function type must be canonicalized.
pub fn ValidatorResources::tag_at(
  self : ValidatorResources,
  at : UInt,
) -> FuncType? {
  if at >= self.module_.tags.length().reinterpret_as_uint() {
    return None
  }
  let id = self.module_.tags[at.reinterpret_as_int()]
  match self.types.get_core(id).composite_type.inner {
    Func(f) => Some(f)
    _ => None
  }
}

///|
/// Returns the global variable at given index.
///
/// The global's value type must be canonicalized.
pub fn ValidatorResources::global_at(
  self : ValidatorResources,
  at : UInt,
) -> GlobalType? {
  if at < self.module_.globals.length().reinterpret_as_uint() {
    Some(self.module_.globals[at.reinterpret_as_int()])
  } else {
    None
  }
}

///|
/// Returns the `SubType` associated with the given type index.
///
/// The sub type must be canonicalized.
pub fn ValidatorResources::sub_type_at(
  self : ValidatorResources,
  at : UInt,
) -> SubType? {
  if at < self.module_.types.length().reinterpret_as_uint() {
    let id = self.module_.types[at.reinterpret_as_int()]
    Some(self.types.get_core(id))
  } else {
    None
  }
}

///|
/// Returns the type ID associated with the given function index.
pub fn ValidatorResources::sub_type_at_id(
  self : ValidatorResources,
  at : CoreTypeId,
) -> SubType {
  self.types.get_core(at)
}

///|
/// Returns the type id associated with the given function index.
pub fn ValidatorResources::type_id_of_function(
  self : ValidatorResources,
  at : UInt,
) -> CoreTypeId? {
  if at >= self.module_.functions.length().reinterpret_as_uint() {
    return None
  }
  let type_index = self.module_.functions[at.reinterpret_as_int()]
  if type_index < self.module_.types.length().reinterpret_as_uint() {
    Some(self.module_.types[type_index.reinterpret_as_int()])
  } else {
    None
  }
}

///|
/// Returns the type index associated with the given function index.
pub fn ValidatorResources::type_index_of_function(
  self : ValidatorResources,
  at : UInt,
) -> UInt? {
  if at < self.module_.functions.length().reinterpret_as_uint() {
    Some(self.module_.functions[at.reinterpret_as_int()])
  } else {
    None
  }
}

///|
/// Returns the function type of the function at the given index (wasmi's
/// `type_of_function` helper).
pub fn ValidatorResources::func_type_of_function(
  self : ValidatorResources,
  at : UInt,
) -> FuncType? {
  match self.type_id_of_function(at) {
    Some(id) =>
      match self.types.get_core(id).composite_type.inner {
        Func(f) => Some(f)
        _ => None
      }
    None => None
  }
}

///|
/// Check and canonicalize a value type.
///
/// This will validate that `t` is valid under the `features` provided and
/// that it is additionally valid within the context that `self` resides in.
fn ValidatorResources::check_value_type(
  self : ValidatorResources,
  t : ValType,
  features : WasmFeatures,
  offset : Int,
) -> ValType raise BinaryReaderError {
  if features.check_value_type(t) is Some(s) {
    raise BinaryReaderError::new(s, offset)
  }
  match t {
    Ref(r) => Ref(self.check_ref_type(r, offset))
    I32 | I64 | F32 | F64 | V128 => t
  }
}

///|
/// Check and canonicalize a reference type.
fn ValidatorResources::check_ref_type(
  self : ValidatorResources,
  ref_type : RefType,
  offset : Int,
) -> RefType raise BinaryReaderError {
  let is_nullable = ref_type.is_nullable()
  let heap_ty = self.check_heap_type(ref_type.heap_type(), offset)
  RefType::new(is_nullable, heap_ty).unwrap()
}

///|
/// Checks that a `HeapType` is valid and then additionally place it in its
/// canonical form.
///
/// Similar to `check_value_type` but for heap types.
fn ValidatorResources::check_heap_type(
  self : ValidatorResources,
  t : HeapType,
  offset : Int,
) -> HeapType raise BinaryReaderError {
  self.module_.check_heap_type(t, offset)
}

///|
/// Get the top type for the given heap type.
pub fn ValidatorResources::top_type(
  self : ValidatorResources,
  heap_type : HeapType,
) -> HeapType {
  self.types.top_type(heap_type)
}

///|
/// Returns the element type at the given index.
///
/// The `RefType` must be canonicalized.
pub fn ValidatorResources::element_type_at(
  self : ValidatorResources,
  at : UInt,
) -> RefType? {
  if at < self.module_.element_types.length().reinterpret_as_uint() {
    Some(self.module_.element_types[at.reinterpret_as_int()])
  } else {
    None
  }
}

///|
/// Is `a` a subtype of `b`?
pub fn ValidatorResources::is_subtype(
  self : ValidatorResources,
  a : ValType,
  b : ValType,
) -> Bool {
  self.types.valtype_is_subtype(a, b)
}

///|
/// Is the given reference type `shared`?
///
/// While abstract heap types do carry along a `shared` flag, concrete heap
/// types do not. This function resolves those concrete heap types to
/// determine `shared`-ness.
pub fn ValidatorResources::is_shared(
  self : ValidatorResources,
  ty : RefType,
) -> Bool {
  self.types.reftype_is_shared(ty)
}

///|
/// Returns the number of elements.
pub fn ValidatorResources::element_count(self : ValidatorResources) -> UInt {
  self.module_.element_types.length().reinterpret_as_uint()
}

///|
/// Returns the number of bytes in the Wasm data section.
pub fn ValidatorResources::data_count(self : ValidatorResources) -> UInt? {
  self.module_.data_count
}

///|
/// Returns whether the function index is referenced in the module anywhere
/// outside of the start/function sections.
pub fn ValidatorResources::is_function_referenced(
  self : ValidatorResources,
  idx : UInt,
) -> Bool {
  self.module_.function_references.contains(idx)
}

///|
/// The type list of the module (all its core types).
pub fn ValidatorResources::types(self : ValidatorResources) -> TypeList {
  self.types
}

///|
/// The number of functions (imported and defined) in the module.
pub fn ValidatorResources::function_count(self : ValidatorResources) -> UInt {
  self.module_.functions.length().reinterpret_as_uint()
}

///|
/// The number of types in the module's type index space.
pub fn ValidatorResources::type_count(self : ValidatorResources) -> UInt {
  self.module_.types.length().reinterpret_as_uint()
}
