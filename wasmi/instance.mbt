// Port of wasmi 1.0.9 `instance/{mod,builder,exports}.rs`.

///|
/// An external item to a WebAssembly module.
///
/// This is returned from [`Instance::exports`]
/// or [`Instance::get_export`].
pub(all) enum Extern {
  /// A WebAssembly global which acts like a [`Cell<T>`] of sorts, supporting `get` and `set` operations.
  Global(Global)
  /// A WebAssembly table which is an array of funtion references.
  Table(Table)
  /// A WebAssembly linear memory.
  Memory(Memory)
  /// A WebAssembly function which can be called.
  Func(Func)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Extern with Eq::{not_equal, equal}

///|
pub impl Show for Extern with fn output(self, f) {
  match self {
    Global(g) => f.write_string("Global(\{g})")
    Table(t) => f.write_string("Table(\{t})")
    Memory(m) => f.write_string("Memory(\{m})")
    Func(func) => f.write_string("Func(\{func})")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Extern with Show::{to_string, output}

///|
/// Returns the underlying global variable if `self` is a global variable.
pub fn Extern::into_global(self : Extern) -> Global? {
  if self is Global(global) {
    Some(global)
  } else {
    None
  }
}

///|
/// Returns the underlying table if `self` is a table.
pub fn Extern::into_table(self : Extern) -> Table? {
  if self is Table(table) {
    Some(table)
  } else {
    None
  }
}

///|
/// Returns the underlying linear memory if `self` is a linear memory.
pub fn Extern::into_memory(self : Extern) -> Memory? {
  if self is Memory(memory) {
    Some(memory)
  } else {
    None
  }
}

///|
/// Returns the underlying function if `self` is a function.
pub fn Extern::into_func(self : Extern) -> Func? {
  if self is Func(func) {
    Some(func)
  } else {
    None
  }
}

///|
/// Returns the type associated with this [`Extern`].
pub fn[T] Extern::ty(self : Extern, store : Store[T]) -> ExternType {
  match self {
    Global(global) => Global(global.ty(store))
    Table(table) => Table(table.ty(store))
    Memory(memory) => Memory(memory.ty(store))
    Func(func) => Func(func.ty(store))
  }
}

///|
/// Upstream `Debug for wasmi::FuncType`.
pub fn debug_func_type(ty : @wasmi_core.FuncType) -> String {
  let params = ty.params().iter().map(val_type_name).collect()
  let results = ty.results().iter().map(val_type_name).collect()
  "FuncType { core: FuncType { params: [\{params.join(", ")}], results: [\{results.join(", ")}] } }"
}

///|
/// Formats an `Option<u64>` like Rust's `Debug`.
fn debug_option_u64(value : UInt64?) -> String {
  match value {
    Some(v) => "Some(\{v})"
    None => "None"
  }
}

///|
/// The Debug name of an [`IndexType`].
fn index_type_name(ty : @wasmi_core.IndexType) -> String {
  match ty {
    I32 => "I32"
    I64 => "I64"
  }
}

///|
/// Upstream `Debug for wasmi::MemoryType`.
pub fn debug_memory_type(ty : @wasmi_core.MemoryType) -> String {
  "MemoryType { core: MemoryType { inner: MemoryTypeInner { minimum: \{ty.minimum()}, maximum: \{debug_option_u64(ty.maximum())}, page_size_log2: \{ty.page_size_log2().to_int()}, index_type: \{index_type_name(ty.index_ty())} } } }"
}

///|
/// Upstream `Debug for wasmi::TableType`.
pub fn debug_table_type(ty : @wasmi_core.TableType) -> String {
  "TableType { core: TableType { element: \{val_type_name(ty.element())}, min: \{ty.minimum()}, max: \{debug_option_u64(ty.maximum())}, index_ty: \{index_type_name(ty.index_ty())} } }"
}

///|
/// Upstream `Debug for GlobalType`.
pub fn debug_global_type(ty : @wasmi_core.GlobalType) -> String {
  let mutability = match ty.mutability() {
    Const => "Const"
    Var => "Var"
  }
  "GlobalType { content: \{val_type_name(ty.content())}, mutability: \{mutability} }"
}

///|
/// Upstream `Debug for ExternType`.
pub impl Show for ExternType with fn output(self, f) {
  match self {
    Global(ty) => f.write_string("Global(\{debug_global_type(ty)})")
    Table(ty) => f.write_string("Table(\{debug_table_type(ty)})")
    Memory(ty) => f.write_string("Memory(\{debug_memory_type(ty)})")
    Func(ty) => f.write_string("Func(\{debug_func_type(ty)})")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ExternType with Show::{to_string, output}

///|
/// An instantiated WebAssembly [`Module`].
///
/// This type represents an instantiation of a [`Module`].
/// It primarily allows to access its [`exports`](Instance::exports)
/// to call functions, get or set globals, read or write memory, etc.
pub(all) struct InstanceEntity {
  mut initialized : Bool
  func_types : Array[DedupFuncType]
  tables : Array[Table]
  funcs : Array[Func]
  memories : Array[Memory]
  globals : Array[Global]
  exports : Map[String, Extern]
  data_segments : Array[DataSegment]
  elem_segments : Array[ElementSegment]
}

///|
/// Creates an uninitialized [`InstanceEntity`].
pub fn InstanceEntity::uninitialized() -> InstanceEntity {
  {
    initialized: false,
    func_types: [],
    tables: [],
    funcs: [],
    memories: [],
    globals: [],
    exports: {},
    data_segments: [],
    elem_segments: [],
  }
}

///|
/// Returns `true` if the [`InstanceEntity`] has been fully initialized.
pub fn InstanceEntity::is_initialized(self : InstanceEntity) -> Bool {
  self.initialized
}

///|
/// Returns the linear memory at the `index` if any.
pub fn InstanceEntity::get_memory(
  self : InstanceEntity,
  index : Int,
) -> Memory? {
  self.memories.get(index)
}

///|
/// Returns the table at the `index` if any.
pub fn InstanceEntity::get_table(self : InstanceEntity, index : Int) -> Table? {
  self.tables.get(index)
}

///|
/// Returns the global variable at the `index` if any.
pub fn InstanceEntity::get_global(
  self : InstanceEntity,
  index : Int,
) -> Global? {
  self.globals.get(index)
}

///|
/// Returns the function at the `index` if any.
pub fn InstanceEntity::get_func(self : InstanceEntity, index : Int) -> Func? {
  self.funcs.get(index)
}

///|
/// Returns the signature at the `index` if any.
pub fn InstanceEntity::get_signature(
  self : InstanceEntity,
  index : Int,
) -> DedupFuncType? {
  self.func_types.get(index)
}

///|
/// Returns the [`DataSegment`] at the `index` if any.
pub fn InstanceEntity::get_data_segment(
  self : InstanceEntity,
  index : Int,
) -> DataSegment? {
  self.data_segments.get(index)
}

///|
/// Returns the [`ElementSegment`] at the `index` if any.
pub fn InstanceEntity::get_element_segment(
  self : InstanceEntity,
  index : Int,
) -> ElementSegment? {
  self.elem_segments.get(index)
}

///|
/// Returns the value exported to the given `name` if any.
pub fn InstanceEntity::get_export(
  self : InstanceEntity,
  name : String,
) -> Extern? {
  self.exports.get(name)
}

///|
/// Returns the value exported to the given `name` if any.
pub fn[T] Instance::get_export(
  self : Instance,
  store : Store[T],
  name : String,
) -> Extern? {
  store.inner.resolve_instance(self).get_export(name)
}

///|
/// Returns the function at the `index` (upstream `get_func_by_index`).
pub fn[T] Instance::get_func_by_index(
  self : Instance,
  store : Store[T],
  index : Int,
) -> Func? {
  store.inner.resolve_instance(self).get_func(index)
}

///|
/// Looks up an exported [`Func`] value by `name`.
pub fn[T] Instance::get_func(
  self : Instance,
  store : Store[T],
  name : String,
) -> Func? {
  match self.get_export(store, name) {
    Some(e) => e.into_func()
    None => None
  }
}

///|
/// Looks up an exported [`Global`] value by `name`.
pub fn[T] Instance::get_global(
  self : Instance,
  store : Store[T],
  name : String,
) -> Global? {
  match self.get_export(store, name) {
    Some(e) => e.into_global()
    None => None
  }
}

///|
/// Looks up an exported [`Table`] value by `name`.
pub fn[T] Instance::get_table(
  self : Instance,
  store : Store[T],
  name : String,
) -> Table? {
  match self.get_export(store, name) {
    Some(e) => e.into_table()
    None => None
  }
}

///|
/// Looks up an exported [`Memory`] value by `name`.
pub fn[T] Instance::get_memory(
  self : Instance,
  store : Store[T],
  name : String,
) -> Memory? {
  match self.get_export(store, name) {
    Some(e) => e.into_memory()
    None => None
  }
}

///|
/// Returns the exports of the [`Instance`] in name (byte) order.
pub fn[T] Instance::exports(
  self : Instance,
  store : Store[T],
) -> Array[(String, Extern)] {
  let exports = store.inner.resolve_instance(self).exports
  let names = exports.keys().collect()
  names.sort_by(compare_utf8)
  names.map(fn(name) { (name, exports.get(name).unwrap()) })
}

///|
/// A module instance entity builder.
priv struct InstanceEntityBuilder {
  func_types : Array[DedupFuncType]
  tables : Array[Table]
  funcs : Array[Func]
  memories : Array[Memory]
  globals : Array[Global]
  mut start_fn : FuncIdx?
  exports : Map[String, Extern]
  data_segments : Array[DataSegment]
  elem_segments : Array[ElementSegment]
}

///|
/// Creates a new [`InstanceEntityBuilder`] optimized for the [`Module`].
fn InstanceEntityBuilder::new(module_ : Module) -> InstanceEntityBuilder {
  {
    func_types: module_.header.func_types,
    tables: [],
    funcs: [],
    memories: [],
    globals: [],
    start_fn: None,
    exports: {},
    data_segments: [],
    elem_segments: [],
  }
}

///|
/// Sets the start function of the built instance.
fn InstanceEntityBuilder::set_start(
  self : InstanceEntityBuilder,
  start_fn : FuncIdx,
) -> Unit {
  match self.start_fn {
    Some(index) => abort("already set start function \{index.0}")
    None => self.start_fn = Some(start_fn)
  }
}

///|
/// Returns the optional start function index.
fn InstanceEntityBuilder::get_start(self : InstanceEntityBuilder) -> FuncIdx? {
  self.start_fn
}

///|
fn InstanceEntityBuilder::get_memory(
  self : InstanceEntityBuilder,
  index : Int,
) -> Memory {
  match self.memories.get(index) {
    Some(m) => m
    None => abort("missing `Memory` at index: \{index}")
  }
}

///|
fn InstanceEntityBuilder::get_table(
  self : InstanceEntityBuilder,
  index : Int,
) -> Table {
  match self.tables.get(index) {
    Some(t) => t
    None => abort("missing `Table` at index: \{index}")
  }
}

///|
fn InstanceEntityBuilder::get_global(
  self : InstanceEntityBuilder,
  index : Int,
) -> Global {
  match self.globals.get(index) {
    Some(g) => g
    None => abort("missing `Global` at index: \{index}")
  }
}

///|
fn InstanceEntityBuilder::get_func(
  self : InstanceEntityBuilder,
  index : Int,
) -> Func {
  match self.funcs.get(index) {
    Some(f) => f
    None => abort("missing `Func` at index: \{index}")
  }
}

///|
fn InstanceEntityBuilder::push_export(
  self : InstanceEntityBuilder,
  name : String,
  new_value : Extern,
) -> Unit {
  if self.exports.get(name) is Some(old_value) {
    abort(
      "tried to register \{new_value} for name \{name} but name is already used by \{old_value}",
    )
  }
  self.exports.set(name, new_value)
}

///|
/// Finishes constructing the [`InstanceEntity`].
fn InstanceEntityBuilder::finish(
  self : InstanceEntityBuilder,
) -> InstanceEntity {
  {
    initialized: true,
    func_types: self.func_types,
    tables: self.tables,
    funcs: self.funcs,
    memories: self.memories,
    globals: self.globals,
    exports: self.exports,
    data_segments: self.data_segments,
    elem_segments: self.elem_segments,
  }
}
