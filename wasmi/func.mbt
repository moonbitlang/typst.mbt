// Port of wasmi 1.0.9 `func/{mod,caller,func_inout,ty}.rs` (dynamically
// typed host functions only; upstream's statically typed `IntoFunc`/
// `TypedFunc` machinery is not ported).

///|
/// The parameters and results buffer of a host function call (upstream
/// `FuncInOut`): `max(len_params, len_results)` cells on the value stack.
pub(all) struct FuncInOut {
  /// The parameters of the host function call.
  params : Array[@wasmi_core.UntypedVal]
  /// The results written by the host function.
  results : Array[@wasmi_core.UntypedVal]
}

///|
/// A host function implementation: called with the caller instance (if any)
/// and the parameters/results buffer.
pub type Trampoline = (Instance?, FuncInOut) -> Unit raise WasmiError

///|
/// A host function reference.
pub(all) struct HostFuncEntity {
  /// The number of parameters of the [`HostFuncEntity`].
  len_params : Int
  /// The number of results of the [`HostFuncEntity`].
  len_results : Int
  /// The function type of the host function.
  ty : DedupFuncType
  /// The trampoline of the host function.
  func : Trampoline
}

///|
/// Creates a new [`HostFuncEntity`].
pub fn HostFuncEntity::new(
  engine : Engine,
  ty : @wasmi_core.FuncType,
  func : Trampoline,
) -> HostFuncEntity {
  let len_params = ty.len_params()
  let len_results = ty.len_results()
  let ty = engine.alloc_func_type(ty)
  { len_params, len_results, ty, func, }
}

///|
/// A Wasm function instance.
pub(all) struct WasmFuncEntity {
  /// The function type of the Wasm function.
  ty : DedupFuncType
  /// The compiled function body of the Wasm function.
  body : EngineFunc
  /// The instance associated to the Wasm function.
  instance : Instance
}

///|
/// A Wasm or host function entity.
pub(all) enum FuncEntity {
  /// A Wasm function.
  Wasm(WasmFuncEntity)
  /// A host function.
  Host(HostFuncEntity)
}

///|
/// Returns the signature of the Wasm function.
pub fn FuncEntity::ty_dedup(self : FuncEntity) -> DedupFuncType {
  match self {
    Wasm(func) => func.ty
    Host(func) => func.ty
  }
}

///|
/// Represents the caller's context when creating a host function via
/// [`Func::new`].
pub struct Caller[T] {
  priv store : Store[T]
  /// The module instance associated to the call.
  priv instance : Instance?
}

///|
/// Creates a new [`Caller`] from the given store context and [`Instance`] handle.
pub fn[T] Caller::new(store : Store[T], instance : Instance?) -> Caller[T] {
  { store, instance, }
}

///|
/// Queries the caller for an exported definition identifier by `name`.
///
/// Returns `None` if there is no associated [`Instance`] of the caller
/// or if the caller does not provide an export under the name `name`.
pub fn[T] Caller::get_export(self : Caller[T], name : String) -> Extern? {
  match self.instance {
    Some(instance) => instance.get_export(self.store, name)
    None => None
  }
}

///|
/// Returns the host state of the store.
pub fn[T] Caller::data(self : Caller[T]) -> T {
  self.store.data
}

///|
/// Sets the host state of the store (upstream `data_mut`).
pub fn[T] Caller::set_data(self : Caller[T], data : T) -> Unit {
  self.store.data = data
}

///|
/// Returns the store of the caller (upstream `as_context_mut`).
pub fn[T] Caller::store(self : Caller[T]) -> Store[T] {
  self.store
}

///|
/// Creates a new [`Func`] with the given arguments.
///
/// This is typically used to create a host-defined function to pass as an
/// import to a Wasm module.
pub fn[T] Func::new(
  store : Store[T],
  ty : @wasmi_core.FuncType,
  func : (Caller[T], Array[Val], Array[Val]) -> Unit raise WasmiError,
) -> Func {
  let trampoline = host_trampoline(store, ty, func)
  let host_func = HostFuncEntity::new(store.inner.engine, ty, trampoline)
  store.inner.alloc_func(Host(host_func))
}

///|
/// Wraps a dynamically typed host function into a [`Trampoline`] (upstream
/// `HostFuncTrampolineEntity::new`).
pub fn[T] host_trampoline(
  store : Store[T],
  ty : @wasmi_core.FuncType,
  func : (Caller[T], Array[Val], Array[Val]) -> Unit raise WasmiError,
) -> Trampoline {
  fn(instance, inout) {
    let params = []
    for i, param_ty in ty.params() {
      params.push(store.inner.val_from_untyped(inout.params[i], param_ty))
    }
    let results = ty.results().map(Val::default)
    func(Caller::new(store, instance), params, results)
    for i, result in results {
      inout.results[i] = store.inner.val_to_untyped(result)
    }
  }
}

///|
/// Returns the function type of the [`Func`].
pub fn[T] Func::ty(self : Func, store : Store[T]) -> @wasmi_core.FuncType {
  store.inner.resolve_func_type(store.inner.resolve_func(self).ty_dedup())
}

///|
/// Returns the deduplicated function type of the [`Func`].
pub fn Func::ty_dedup(self : Func, store : StoreInner) -> DedupFuncType {
  store.resolve_func(self).ty_dedup()
}

///|
/// Calls the Wasm or host function with the given inputs.
///
/// The result is written back into the `outputs` buffer.
///
/// # Errors
///
/// - If the function returned a [`WasmiError`].
/// - If the types of the `inputs` do not match the expected types for the
///   function signature of `self`.
/// - If the number of input values does not match the expected number of
///   inputs required by the function signature of `self`.
/// - If the number of output values does not match the expected number of
///   outputs required by the function signature of `self`.
pub fn[T] Func::call(
  self : Func,
  store : Store[T],
  inputs : Array[Val],
  outputs : Array[Val],
) -> Unit raise WasmiError {
  self.verify_and_prepare_inputs_outputs(store, inputs, outputs)
  store.inner.engine.execute_func(store.inner, self, inputs, outputs)
}

///|
/// Verify that the `inputs` and `outputs` value types match the function signature.
///
/// Since [`Func`] is a dynamically typed function instance there is
/// a need to verify that the given input parameters match the required
/// types and that the given output slice matches the expected length.
///
/// These checks can be avoided using the [`TypedFunc`] API.
fn[T] Func::verify_and_prepare_inputs_outputs(
  self : Func,
  store : Store[T],
  inputs : Array[Val],
  outputs : Array[Val],
) -> Unit raise WasmiError {
  let func_type = self.ty(store)
  // FuncType::match_params
  if func_type.params().length() != inputs.length() {
    raise Func(MismatchingParameterLen)
  }
  for i, param in func_type.params() {
    if param != inputs[i].ty() {
      raise Func(MismatchingParameterType)
    }
  }
  // FuncType::prepare_outputs
  if func_type.results().length() != outputs.length() {
    raise Func(MismatchingResultLen)
  }
  for i, result_ty in func_type.results() {
    outputs[i] = Val::default(result_ty)
  }
}

// ---------------------------------------------------------------------------
// Memory, Table, Global handle methods (memory/mod.rs, table/mod.rs, global.rs)

///|
/// Creates a new linear memory to the store.
pub fn[T] Memory::new(
  store : Store[T],
  ty : @wasmi_core.MemoryType,
) -> Memory raise WasmiError {
  let entity = @wasmi_core.Memory::new(
    ty,
    @wasmi_core.ResourceLimiterRef::default(),
  ) catch {
    e => raise Memory(e)
  }
  store.inner.alloc_memory(entity)
}

///|
/// Returns the memory type of the linear memory.
pub fn[T] Memory::ty(self : Memory, store : Store[T]) -> @wasmi_core.MemoryType {
  store.inner.resolve_memory(self).ty()
}

///|
/// Returns the amount of pages in use by the linear memory.
pub fn[T] Memory::size(self : Memory, store : Store[T]) -> UInt64 {
  store.inner.resolve_memory(self).size()
}

///|
/// Grows the linear memory by the given amount of new pages.
///
/// Returns the amount of pages before the operation upon success.
pub fn[T] Memory::grow(
  self : Memory,
  store : Store[T],
  additional : UInt64,
) -> UInt64 raise @wasmi_core.MemoryError {
  store.inner
  .resolve_memory(self)
  .grow(additional, None, @wasmi_core.ResourceLimiterRef::default()) catch {
    _ => raise OutOfBoundsGrowth
  }
}

///|
/// Returns the underlying bytes of the linear memory.
pub fn[T] Memory::data(self : Memory, store : Store[T]) -> FixedArray[Byte] {
  store.inner.resolve_memory(self).data()
}

///|
/// Returns the byte length of the linear memory.
pub fn[T] Memory::data_size(self : Memory, store : Store[T]) -> Int {
  store.inner.resolve_memory(self).data_size()
}

///|
/// Reads `n` bytes from `memory[offset..offset+n]` into `buffer`
/// where `n` is the length of `buffer`.
pub fn[T] Memory::read(
  self : Memory,
  store : Store[T],
  offset : UInt64,
  buffer : FixedArray[Byte],
) -> Unit raise @wasmi_core.MemoryError {
  store.inner.resolve_memory(self).read(offset, buffer)
}

///|
/// Writes `n` bytes to `memory[offset..offset+n]` from `buffer`
/// where `n` if the length of `buffer`.
pub fn[T] Memory::write(
  self : Memory,
  store : Store[T],
  offset : UInt64,
  buffer : BytesView,
) -> Unit raise @wasmi_core.MemoryError {
  store.inner.resolve_memory(self).write(offset, buffer)
}

///|
/// Creates a new table to the store.
pub fn[T] Table::new(
  store : Store[T],
  ty : @wasmi_core.TableType,
  init : Val,
) -> Table raise WasmiError {
  let entity = @wasmi_core.Table::new(
    ty,
    store.inner.val_to_typed(init),
    @wasmi_core.ResourceLimiterRef::default(),
  ) catch {
    e => raise Table(e)
  }
  store.inner.alloc_table(entity)
}

///|
/// Returns the type and limits of the table.
pub fn[T] Table::ty(self : Table, store : Store[T]) -> @wasmi_core.TableType {
  store.inner.resolve_table(self).ty()
}

///|
/// Returns the current size of the [`Table`].
pub fn[T] Table::size(self : Table, store : Store[T]) -> UInt64 {
  store.inner.resolve_table(self).size()
}

///|
/// Returns the [`Table`] element value at `index`.
///
/// Returns `None` if `index` is out of bounds.
pub fn[T] Table::get(self : Table, store : Store[T], index : UInt64) -> Val? {
  match store.inner.resolve_table(self).get_untyped(index) {
    Some(untyped) =>
      Some(
        store.inner.val_from_untyped(
          untyped,
          store.inner.resolve_table(self).ty().element(),
        ),
      )
    None => None
  }
}

///|
/// Creates a new global variable to the store.
pub fn[T] Global::new(
  store : Store[T],
  initial_value : Val,
  mutability : @wasmi_core.Mutability,
) -> Global {
  store.inner.alloc_global(
    @wasmi_core.Global::new(store.inner.val_to_typed(initial_value), mutability),
  )
}

///|
/// Returns the [`GlobalType`] of the global variable.
pub fn[T] Global::ty(self : Global, store : Store[T]) -> @wasmi_core.GlobalType {
  store.inner.resolve_global(self).ty()
}

///|
/// Returns the current value of the global variable.
pub fn[T] Global::get(self : Global, store : Store[T]) -> Val {
  let global = store.inner.resolve_global(self)
  store.inner.val_from_untyped(global.get_untyped(), global.ty().content())
}

///|
/// Sets a new value to the global variable.
pub fn[T] Global::set(
  self : Global,
  store : Store[T],
  new_value : Val,
) -> Unit raise WasmiError {
  store.inner.resolve_global(self).set(store.inner.val_to_typed(new_value)) catch {
    e => raise Global(e)
  }
}

///|
/// Creates a new instance of `ExternRef` wrapping the given value.
pub fn[T] ExternRef::new(store : Store[T], object : Any) -> ExternRef {
  store.inner.alloc_extern_object({ data: object, })
}

///|
/// Returns a shared reference to the underlying data for this [`ExternRef`].
pub fn[T] ExternRef::data(self : ExternRef, store : Store[T]) -> Any {
  store.inner.resolve_externref(self).data
}
