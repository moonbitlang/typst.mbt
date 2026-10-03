// Port of wasmi 1.0.9 `store/{mod,inner}.rs`, the entity handles of
// `func/mod.rs`, `memory/{mod,data}.rs`, `table/{mod,element}.rs`,
// `global.rs`, `reftype.rs` and `value.rs`.
//
// Entities are stored in arenas of the `StoreInner` like upstream; handles
// carry the store index and the entity index (their upstream `Debug` form is
// `GuardedEntity { guard_idx: StoreIdx(s), entity_idx: XxxIdx(i) }`).

///|
/// The global counter of stores (upstream `StoreIdx::new`).
let store_counter : Ref[Int] = { val: 0, }

///|
/// The inner store that owns all data not associated to the host state.
pub struct StoreInner {
  /// The unique store index.
  priv store_idx : Int
  /// Stored Wasm or host functions.
  priv funcs : Array[FuncEntity]
  /// Stored linear memories.
  priv memories : Array[@wasmi_core.Memory]
  /// Stored tables.
  priv tables : Array[@wasmi_core.Table]
  /// Stored global variables.
  priv globals : Array[@wasmi_core.Global]
  /// Stored module instances.
  priv instances : Array[InstanceEntity]
  /// Stored data segments.
  priv datas : Array[DataSegmentEntity]
  /// Stored data segments.
  priv elems : Array[@wasmi_core.ElementSegment]
  /// Stored external objects for [`ExternRef`] types.
  priv extern_objects : Array[ExternRefEntity]
  /// The [`Engine`] in use by the [`StoreInner`].
  priv engine : Engine
  /// The fuel of the [`Store`].
  priv fuel : @wasmi_core.Fuel
}

///|
/// Creates a new [`StoreInner`] for the given [`Engine`].
fn StoreInner::new(engine : Engine) -> StoreInner {
  let config = engine.config()
  let fuel = @wasmi_core.Fuel::new(
    config.get_consume_fuel(),
    config.fuel_costs(),
  )
  let store_idx = store_counter.val
  store_counter.val += 1
  {
    store_idx,
    funcs: [],
    memories: [],
    tables: [],
    globals: [],
    instances: [],
    datas: [],
    elems: [],
    extern_objects: [],
    engine,
    fuel,
  }
}

///|
/// Returns the [`Engine`] that this store is associated with.
pub fn StoreInner::engine(self : StoreInner) -> Engine {
  self.engine
}

///|
/// The store where all Wasm entities are stored.
pub struct Store[T] {
  /// All data that is not associated to `T`.
  inner : StoreInner
  /// The user provided host state.
  mut data : T
}

///|
/// Creates a new store.
pub fn[T] Store::new(engine : Engine, data : T) -> Store[T] {
  { inner: StoreInner::new(engine), data, }
}

///|
/// Returns the [`Engine`] that this store is associated with.
pub fn[T] Store::engine(self : Store[T]) -> Engine {
  self.inner.engine
}

///|
/// Returns the host state of the store.
pub fn[T] Store::data(self : Store[T]) -> T {
  self.data
}

///|
/// Sets the host state of the store (upstream `data_mut`).
pub fn[T] Store::set_data(self : Store[T], data : T) -> Unit {
  self.data = data
}

// ---------------------------------------------------------------------------
// Entity handles

///|
/// A Wasm or host function reference.
pub(all) struct Func {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
pub impl Show for Func with fn output(self, f) {
  f.write_string(
    "Func(GuardedEntity { guard_idx: StoreIdx(\{self.store}), entity_idx: FuncIdx(\{self.idx + 1}) })",
  )
}

///|
/// A Wasm linear memory reference.
pub(all) struct Memory {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
pub impl Show for Memory with fn output(self, f) {
  f.write_string(
    "Memory(GuardedEntity { guard_idx: StoreIdx(\{self.store}), entity_idx: MemoryIdx(\{self.idx}) })",
  )
}

///|
/// A Wasm table reference.
pub(all) struct Table {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
pub impl Show for Table with fn output(self, f) {
  f.write_string(
    "Table(GuardedEntity { guard_idx: StoreIdx(\{self.store}), entity_idx: TableIdx(\{self.idx}) })",
  )
}

///|
/// A Wasm global variable reference.
pub(all) struct Global {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
pub impl Show for Global with fn output(self, f) {
  f.write_string(
    "Global(GuardedEntity { guard_idx: StoreIdx(\{self.store}), entity_idx: GlobalIdx(\{self.idx}) })",
  )
}

///|
/// An instantiated WebAssembly [`Module`].
pub(all) struct Instance {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
pub impl Show for Instance with fn output(self, f) {
  f.write_string(
    "Instance(GuardedEntity { guard_idx: StoreIdx(\{self.store}), entity_idx: InstanceIdx(\{self.idx}) })",
  )
}

///|
/// A reference to a data segment.
pub(all) struct DataSegment {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
/// A reference to an element segment.
pub(all) struct ElementSegment {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
/// Represents an opaque reference to any data within WebAssembly.
pub(all) struct ExternRef {
  priv store : Int
  priv idx : Int
} derive(Eq, Hash)

///|
pub impl Show for ExternRef with fn output(self, f) {
  f.write_string(
    "ExternRef(GuardedEntity { guard_idx: StoreIdx(\{self.store}), entity_idx: ExternRefIdx(\{self.idx + 1}) })",
  )
}

///|
/// An externally defined object (upstream `ExternRefEntity`, a boxed `dyn Any`).
pub(all) struct ExternRefEntity {
  data : Any
}

///|
/// An opaque value of any type (a stand-in for Rust's `dyn Any`).
pub(all) enum Any {
  U32(UInt)
  Str(String)
  Other
} derive(Eq, Show)

///|
/// A data segment entity (upstream `DataSegmentEntity`).
pub(all) struct DataSegmentEntity {
  /// The underlying bytes of the instance data segment, `None` once dropped
  /// or for active segments.
  mut bytes : Bytes?
}

///|
/// Returns the bytes of the data segment (empty if dropped or active).
pub fn DataSegmentEntity::bytes(self : DataSegmentEntity) -> Bytes {
  match self.bytes {
    Some(b) => b
    None => b""
  }
}

///|
/// Drops the bytes of the [`DataSegmentEntity`].
pub fn DataSegmentEntity::drop_bytes(self : DataSegmentEntity) -> Unit {
  self.bytes = None
}

// ---------------------------------------------------------------------------
// Store allocation and resolution

///|
pub fn StoreInner::alloc_global(
  self : StoreInner,
  global : @wasmi_core.Global,
) -> Global {
  self.globals.push(global)
  { store: self.store_idx, idx: self.globals.length() - 1, }
}

///|
pub fn StoreInner::alloc_table(
  self : StoreInner,
  table : @wasmi_core.Table,
) -> Table {
  self.tables.push(table)
  { store: self.store_idx, idx: self.tables.length() - 1, }
}

///|
pub fn StoreInner::alloc_memory(
  self : StoreInner,
  memory : @wasmi_core.Memory,
) -> Memory {
  self.memories.push(memory)
  { store: self.store_idx, idx: self.memories.length() - 1, }
}

///|
pub fn StoreInner::alloc_data_segment(
  self : StoreInner,
  segment : DataSegmentEntity,
) -> DataSegment {
  self.datas.push(segment)
  { store: self.store_idx, idx: self.datas.length() - 1, }
}

///|
pub fn StoreInner::alloc_element_segment(
  self : StoreInner,
  segment : @wasmi_core.ElementSegment,
) -> ElementSegment {
  self.elems.push(segment)
  { store: self.store_idx, idx: self.elems.length() - 1, }
}

///|
pub fn StoreInner::alloc_extern_object(
  self : StoreInner,
  object : ExternRefEntity,
) -> ExternRef {
  self.extern_objects.push(object)
  { store: self.store_idx, idx: self.extern_objects.length() - 1, }
}

///|
/// Allocates a new uninitialized [`InstanceEntity`] and returns an [`Instance`] reference to it.
pub fn StoreInner::alloc_instance(self : StoreInner) -> Instance {
  self.instances.push(InstanceEntity::uninitialized())
  { store: self.store_idx, idx: self.instances.length() - 1, }
}

///|
/// Initializes the [`Instance`] using the given [`InstanceEntity`].
pub fn StoreInner::initialize_instance(
  self : StoreInner,
  instance : Instance,
  init : InstanceEntity,
) -> Unit {
  self.instances[instance.idx] = init
}

///|
pub fn StoreInner::alloc_func(self : StoreInner, func : FuncEntity) -> Func {
  self.funcs.push(func)
  { store: self.store_idx, idx: self.funcs.length() - 1, }
}

///|
/// Checks that the entity belongs to this store.
fn StoreInner::check_store(self : StoreInner, store : Int) -> Unit {
  if store != self.store_idx {
    abort("failed to resolve stored entity: encountered foreign entity")
  }
}

///|
pub fn StoreInner::resolve_global(
  self : StoreInner,
  global : Global,
) -> @wasmi_core.Global {
  self.check_store(global.store)
  self.globals[global.idx]
}

///|
pub fn StoreInner::resolve_table(
  self : StoreInner,
  table : Table,
) -> @wasmi_core.Table {
  self.check_store(table.store)
  self.tables[table.idx]
}

///|
pub fn StoreInner::resolve_memory(
  self : StoreInner,
  memory : Memory,
) -> @wasmi_core.Memory {
  self.check_store(memory.store)
  self.memories[memory.idx]
}

///|
pub fn StoreInner::resolve_element(
  self : StoreInner,
  elem : ElementSegment,
) -> @wasmi_core.ElementSegment {
  self.check_store(elem.store)
  self.elems[elem.idx]
}

///|
pub fn StoreInner::resolve_data(
  self : StoreInner,
  data : DataSegment,
) -> DataSegmentEntity {
  self.check_store(data.store)
  self.datas[data.idx]
}

///|
pub fn StoreInner::resolve_instance(
  self : StoreInner,
  instance : Instance,
) -> InstanceEntity {
  self.check_store(instance.store)
  self.instances[instance.idx]
}

///|
pub fn StoreInner::resolve_func(self : StoreInner, func : Func) -> FuncEntity {
  self.check_store(func.store)
  self.funcs[func.idx]
}

///|
pub fn StoreInner::resolve_externref(
  self : StoreInner,
  object : ExternRef,
) -> ExternRefEntity {
  self.check_store(object.store)
  self.extern_objects[object.idx]
}

///|
/// Resolves the [`FuncType`] of the deduplicated function type.
pub fn StoreInner::resolve_func_type(
  self : StoreInner,
  func_type : DedupFuncType,
) -> @wasmi_core.FuncType {
  self.engine.resolve_func_type(func_type)
}

///|
/// Returns the fuel of the store.
pub fn StoreInner::fuel(self : StoreInner) -> @wasmi_core.Fuel {
  self.fuel
}

///|
/// Encodes a nullable function reference as [`UntypedVal`] (`0` is `null`).
pub fn StoreInner::funcref_to_untyped(
  self : StoreInner,
  func : Func?,
) -> @wasmi_core.UntypedVal {
  match func {
    None => @wasmi_core.UntypedVal::from_u64(0)
    Some(func) => {
      self.check_store(func.store)
      @wasmi_core.UntypedVal::from_u64((func.idx + 1).to_uint64())
    }
  }
}

///|
/// Decodes a nullable function reference from [`UntypedVal`] (`0` is `null`).
pub fn StoreInner::funcref_from_untyped(
  self : StoreInner,
  value : @wasmi_core.UntypedVal,
) -> Func? {
  let bits = value.to_bits64()
  if bits == 0 {
    None
  } else {
    Some({ store: self.store_idx, idx: bits.to_int() - 1, })
  }
}

///|
/// Encodes a nullable extern reference as [`UntypedVal`] (`0` is `null`).
pub fn StoreInner::externref_to_untyped(
  self : StoreInner,
  object : ExternRef?,
) -> @wasmi_core.UntypedVal {
  match object {
    None => @wasmi_core.UntypedVal::from_u64(0)
    Some(object) => {
      self.check_store(object.store)
      @wasmi_core.UntypedVal::from_u64((object.idx + 1).to_uint64())
    }
  }
}

///|
/// Decodes a nullable extern reference from [`UntypedVal`] (`0` is `null`).
pub fn StoreInner::externref_from_untyped(
  self : StoreInner,
  value : @wasmi_core.UntypedVal,
) -> ExternRef? {
  let bits = value.to_bits64()
  if bits == 0 {
    None
  } else {
    Some({ store: self.store_idx, idx: bits.to_int() - 1, })
  }
}

// ---------------------------------------------------------------------------
// value.rs

///|
/// Runtime representation of a Wasm value.
pub(all) enum Val {
  /// Value of 32-bit signed or unsigned integer.
  I32(Int)
  /// Value of 64-bit signed or unsigned integer.
  I64(Int64)
  /// Value of 32-bit IEEE 754-2008 floating point number (as bits).
  F32(UInt)
  /// Value of 64-bit IEEE 754-2008 floating point number (as bits).
  F64(UInt64)
  /// 128-bit Wasm `simd` proposal vector.
  V128(@wasmi_core.V128)
  /// A nullable [`Func`] reference.
  FuncRef(Func?)
  /// A nullable [`ExternRef`] reference.
  ExternRef(ExternRef?)
} derive(Eq)

///|
/// Creates new default value of given type.
pub fn Val::default(value_type : @wasmi_core.ValType) -> Val {
  match value_type {
    I32 => I32(0)
    I64 => I64(0)
    F32 => F32(0)
    F64 => F64(0)
    V128 => V128(@wasmi_core.V128::from_lo_hi(0, 0))
    FuncRef => FuncRef(None)
    ExternRef => ExternRef(None)
  }
}

///|
/// Get variable type for this value.
pub fn Val::ty(self : Val) -> @wasmi_core.ValType {
  match self {
    I32(_) => I32
    I64(_) => I64
    F32(_) => F32
    F64(_) => F64
    V128(_) => V128
    FuncRef(_) => FuncRef
    ExternRef(_) => ExternRef
  }
}

///|
/// Converts the [`Val`] into an [`UntypedVal`].
pub fn StoreInner::val_to_untyped(
  self : StoreInner,
  value : Val,
) -> @wasmi_core.UntypedVal {
  match value {
    I32(v) => @wasmi_core.UntypedVal::from_i32(v)
    I64(v) => @wasmi_core.UntypedVal::from_i64(v)
    F32(bits) => @wasmi_core.UntypedVal::from_u32(bits)
    F64(bits) => @wasmi_core.UntypedVal::from_u64(bits)
    V128(v) => @wasmi_core.UntypedVal::from_v128(v)
    FuncRef(f) => self.funcref_to_untyped(f)
    ExternRef(e) => self.externref_to_untyped(e)
  }
}

///|
/// Converts an [`UntypedVal`] of type `ty` into a [`Val`].
pub fn StoreInner::val_from_untyped(
  self : StoreInner,
  value : @wasmi_core.UntypedVal,
  ty : @wasmi_core.ValType,
) -> Val {
  match ty {
    I32 => I32(value.read_i32())
    I64 => I64(value.read_i64())
    F32 => F32(value.read_u32())
    F64 => F64(value.read_u64())
    V128 => V128(value.read_v128())
    FuncRef => FuncRef(self.funcref_from_untyped(value))
    ExternRef => ExternRef(self.externref_from_untyped(value))
  }
}

///|
/// Converts the [`Val`] into a [`TypedVal`].
pub fn StoreInner::val_to_typed(
  self : StoreInner,
  value : Val,
) -> @wasmi_core.TypedVal {
  @wasmi_core.TypedVal::new(value.ty(), self.val_to_untyped(value))
}
