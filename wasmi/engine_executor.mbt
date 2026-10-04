// Port of wasmi 1.0.9 `engine/executor/{mod,cache,instr_ptr}.rs`.
//
// Not ported: resumable calls (`execute_func_resumable`, `resume_func_*`:
// errors are returned as is), call hooks and fuel metering (Typst runs
// wasmi without fuel).
//
// `instr_ptr.rs`: upstream's `InstructionPtr` is a raw pointer into the
// `Op`s of the executed function. Here it is the pair of the function's
// `FixedArray[@ir.Op]` and an `Int` index into it (see `Executor::instrs`
// and `Executor::ip`, `CallFrame::instrs` and `CallFrame::ip`);
// `InstructionPtr::add(delta)` / `offset(by)` are `ip += delta`.

// ---------------------------------------------------------------------------
// mod.rs

///|
/// Executes the given [`Func`] with the given `params` and writes the
/// results into `results` (upstream `EngineInner::execute_func` together
/// with `Func::call`'s `CallParams`/`CallResults` for `&[Val]`/`&mut [Val]`).
///
/// # Note
///
/// `results` must have been prepared with values of the result types of
/// `func` (see `Func::verify_and_prepare_inputs_outputs`).
///
/// # Errors
///
/// If the Wasm execution traps or runs out of resources.
pub fn Engine::execute_func(
  self : Engine,
  store : StoreInner,
  func : Func,
  params : Array[Val],
  results : Array[Val],
) -> Unit raise WasmiError {
  let stack = engine_stacks_reuse_or_new(self.stacks, self.config.stack)
  defer engine_stacks_recycle(self.stacks, self.config.stack, stack)
  EngineExecutor::new(self.code_map, stack).execute_root_func(
    store, func, params, results,
  ) catch {
    // `error.into_resumable()`: resumable errors are turned back into
    // their non-resumable error (`ResumableError::into_error`).
    Table(OutOfFuel(..))
    | Memory(OutOfFuel(..))
    | Fuel(OutOfFuel(..))
    | ResumableOutOfFuel(_) => raise WasmiError::TrapCode(OutOfFuel)
    error => raise error
  }
}

///|
/// The internal state of the Wasmi engine.
priv struct EngineExecutor {
  /// Shared and reusable generic engine resources.
  code_map : CodeMap
  /// The value and call stacks.
  stack : Stack
}

///|
/// Creates a new [`EngineExecutor`] for the given [`Stack`].
fn EngineExecutor::new(code_map : CodeMap, stack : Stack) -> EngineExecutor {
  { code_map, stack, }
}

///|
/// Executes the given [`Func`] using the given `params`.
///
/// Stores the execution result into `results` upon a successful execution.
///
/// # Errors
///
/// - If the given `params` do not match the expected parameters of `func`.
/// - If the given `results` do not match the length of the expected results of `func`.
/// - When encountering a Wasm or host trap during the execution of `func`.
fn EngineExecutor::execute_root_func(
  self : EngineExecutor,
  store : StoreInner,
  func : Func,
  params : Array[Val],
  results : Array[Val],
) -> Unit raise WasmiError {
  self.stack.reset()
  match store.resolve_func(func) {
    Wasm(wasm_func) => {
      // We reserve space on the stack to write the results of the root function execution.
      let len_results = results.length()
      let _ = self.stack.values.extend_by(len_results) catch {
        e => raise WasmiError::TrapCode(e)
      }
      let instance = wasm_func.instance
      let engine_func = wasm_func.body
      let compiled_func = self.code_map.get(Some(store.fuel), engine_func)
      let uninit_params = FrameParams::new()
      let frame = self.stack.values.alloc_call_frame(
        compiled_func, uninit_params,
      ) catch {
        e => raise WasmiError::TrapCode(e)
      }
      for value in params {
        uninit_params.init_next(store.val_to_untyped(value))
      }
      uninit_params.init_zeroes()
      let base = frame + compiled_func.consts().length()
      self.stack.calls.push(
        CallFrame::new(
          compiled_func.instrs(),
          0,
          base,
          frame,
          @ir.SlotSpan::new(@ir.Slot(0)),
        ),
        Some(instance),
      ) catch {
        e => raise WasmiError::TrapCode(e)
      }
      // Note: call hooks (`CallHook::CallingWasm`/`ReturningFromWasm`) are not ported.
      self.execute_func(store)
    }
    Host(host_func) => {
      // The host function signature is required for properly
      // adjusting, inspecting and manipulating the value stack.
      // In case the host function returns more values than it takes
      // we are required to extend the value stack.
      let len_params = host_func.len_params
      let len_results = host_func.len_results
      let max_inout = if len_params > len_results {
        len_params
      } else {
        len_results
      }
      let uninit = self.stack.values.extend_by(max_inout) catch {
        e => raise WasmiError::TrapCode(e)
      }
      for i, param in params {
        if i >= max_inout {
          break
        }
        self.stack.values.set(uninit + i, store.val_to_untyped(param))
      }
      self.dispatch_host_func(store, host_func)
    }
  }
  self.write_results_back(store, results)
}

///|
/// Executes the top most Wasm function on the [`Stack`] until the [`Stack`] is empty.
///
/// # Errors
///
/// When encountering a Wasm or host trap during execution.
fn EngineExecutor::execute_func(
  self : EngineExecutor,
  store : StoreInner,
) -> Unit raise WasmiError {
  execute_instrs(store, self.stack, self.code_map)
}

///|
/// Convenience forwarder to [`dispatch_host_func`].
fn EngineExecutor::dispatch_host_func(
  self : EngineExecutor,
  store : StoreInner,
  host_func : HostFuncEntity,
) -> Unit raise WasmiError {
  dispatch_host_func(store, self.stack.values, host_func, None)
}

///|
/// Writes the results of the function execution back into the `results` buffer.
///
/// Each result is decoded with the type of the value already in `results`
/// (upstream `CallResults for &mut [Val]`).
fn EngineExecutor::write_results_back(
  self : EngineExecutor,
  store : StoreInner,
  results : Array[Val],
) -> Unit {
  let len_results = results.length()
  for i in 0..<len_results {
    let untyped = self.stack.values.get(i)
    results[i] = store.val_from_untyped(untyped, results[i].ty())
  }
}

// ---------------------------------------------------------------------------
// cache.rs

///|
/// A global variable used as cache when the instance has no global at index 0
/// (upstream uses a null pointer which is never accessed).
let no_cached_global : @wasmi_core.Global = @wasmi_core.Global::new(
  @wasmi_core.TypedVal::new(I32, @wasmi_core.UntypedVal::default()),
  Var,
)

///|
/// Cached WebAssembly instance.
///
/// # Note
///
/// Upstream's `CachedMemory` (a pointer to the bytes of the default linear
/// memory) and `CachedGlobal` (a pointer to the value of the global at index
/// 0) are flattened into this struct: `memory_data`/`memory_len` (the byte
/// buffer and the accessible length of the memory) and `global`.
priv struct CachedInstance {
  /// The currently used instance.
  mut instance : InstanceEntity
  /// The cached bytes of the default linear memory.
  mut memory_data : FixedArray[Byte]
  /// The cached length of the default linear memory.
  mut memory_len : Int
  /// The cached global variable at index 0.
  mut global : @wasmi_core.Global
}

///|
/// Creates a new [`CachedInstance`].
fn CachedInstance::new(ctx : StoreInner, instance : Instance) -> CachedInstance {
  let entity = CachedInstance::load_instance(ctx, instance)
  let cache = {
    instance: entity,
    memory_data: [],
    memory_len: 0,
    global: no_cached_global,
  }
  cache.load_caches(ctx, entity)
  cache
}

///|
/// Loads the [`InstanceEntity`] from the [`StoreInner`].
fn CachedInstance::load_instance(
  ctx : StoreInner,
  instance : Instance,
) -> InstanceEntity {
  ctx.resolve_instance(instance)
}

///|
/// Loads the cached global and linear memory.
fn CachedInstance::load_caches(
  self : CachedInstance,
  ctx : StoreInner,
  entity : InstanceEntity,
) -> Unit {
  self.instance = entity
  self.load_memory(ctx)
  self.global = match entity.get_global(0) {
    Some(global) => ctx.resolve_global(global)
    None => no_cached_global
  }
}

///|
/// Loads the cached default linear memory of the cached instance.
fn CachedInstance::load_memory(self : CachedInstance, ctx : StoreInner) -> Unit {
  match self.instance.get_memory(default_memory_index) {
    Some(memory) => {
      let memory = ctx.resolve_memory(memory)
      self.memory_data = memory.data()
      self.memory_len = memory.data_size()
    }
    None => {
      self.memory_data = []
      self.memory_len = 0
    }
  }
}

///|
/// Update the cached instance, linear memory and global variable.
fn CachedInstance::update(
  self : CachedInstance,
  ctx : StoreInner,
  instance : Instance,
) -> Unit {
  self.load_caches(ctx, CachedInstance::load_instance(ctx, instance))
}

///|
/// Updates the cached linear memory data.
///
/// # Note
///
/// This needs to be called whenever the cached memory might have changed.
///
/// The linear memory might change when ...
///
/// - calling a host function
/// - successfully growing the default linear memory
/// - calling functions defined in other instances via imported or indirect calls
/// - returning from functions that changed the currently used instance
fn CachedInstance::update_memory(
  self : CachedInstance,
  ctx : StoreInner,
) -> Unit {
  self.load_memory(ctx)
}

///|
/// Returns the [`Func`] at the `index` if any.
fn CachedInstance::get_func(self : CachedInstance, index : @ir.Func) -> Func? {
  self.instance.get_func(index.0)
}

///|
/// Returns the [`Memory`] at the `index` if any.
fn CachedInstance::get_memory(
  self : CachedInstance,
  index : @ir.Memory,
) -> Memory? {
  self.instance.get_memory(index.0)
}

///|
/// Returns the [`Table`] at the `index` if any.
fn CachedInstance::get_table(
  self : CachedInstance,
  index : @ir.Table,
) -> Table? {
  self.instance.get_table(index.0)
}

///|
/// Returns the [`Global`] at the `index` if any.
fn CachedInstance::get_global(
  self : CachedInstance,
  index : @ir.Global,
) -> Global? {
  self.instance.get_global(index.0)
}

///|
/// Returns the [`DataSegment`] at the `index` if any.
fn CachedInstance::get_data_segment(
  self : CachedInstance,
  index : @ir.Data,
) -> DataSegment? {
  self.instance.get_data_segment(index.0)
}

///|
/// Returns the [`ElementSegment`] at the `index` if any.
fn CachedInstance::get_element_segment(
  self : CachedInstance,
  index : @ir.Elem,
) -> ElementSegment? {
  self.instance.get_element_segment(index.0)
}

///|
/// Returns the [`DedupFuncType`] at the `index` if any.
fn CachedInstance::get_func_type_dedup(
  self : CachedInstance,
  index : @ir.FuncType,
) -> DedupFuncType? {
  self.instance.get_signature(index.0)
}
