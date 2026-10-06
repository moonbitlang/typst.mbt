// Port of `typst-library/src/foundations/plugin.rs`: WebAssembly plugins on
// the wasmi port (`wasmi/`).

///|
/// Loads a WebAssembly module.
///
/// The resulting module will contain one Typst function for each function
/// export of the loaded WebAssembly module.
fn impl_plugin(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Value raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  Module(at(source_.span, () => Plugin::module_(loaded.data)))
}

///|
/// Calls a plugin function that has side effects and returns a new module
/// with plugin functions that are guaranteed to have observed the results
/// of the mutable call.
fn impl_plugin_transition(
  func_ : Value,
  arguments_ : Array[BytesValue],
) -> Value raise HintedError {
  // `cast!` for `PluginFunc`.
  let func = match func_ {
    Func(f) =>
      match f.to_plugin() {
        Some(func) => func
        None => bail("expected plugin function")
      }
    v => cast_fail_with(Type(Type::func()), v)
  }
  Module(func.transition(arguments_.map(b => b.0)))
}

///|
/// A function loaded from a WebAssembly plugin.
pub struct PluginFunc {
  /// The underlying plugin, shared by this and the other functions.
  priv plugin : Plugin
  /// The name of the plugin function.
  priv name : String
}

///|
/// The name of the plugin function.
pub fn PluginFunc::name(self : PluginFunc) -> String {
  self.name
}

///|
/// Call the WebAssembly function with the given arguments.
pub fn PluginFunc::call(
  self : PluginFunc,
  args : Array[Bytes],
) -> Bytes raise HintedError {
  memoized(plugin_call_cache, self, args, () => {
    self.plugin.call(self.name, args)
  })
}

///|
/// Transition a plugin and turn the result into a module.
pub fn PluginFunc::transition(
  self : PluginFunc,
  args : Array[Bytes],
) -> Module raise HintedError {
  memoized(plugin_transition_cache, self, args, () => {
    self.plugin.transition(self.name, args).into_module()
  })
}

///|
/// The results of memoized plugin function calls and transitions (upstream
/// `#[comemo::memoize]`), keyed by the 128-bit hash of the function and
/// arguments. Like comemo, only the hash of the inputs is kept (not the
/// arguments themselves).
let plugin_call_cache : Map[U128, Result[Bytes, HintedError]] = Map([])

///|
let plugin_transition_cache : Map[U128, Result[Module, HintedError]] = Map([])

///|
/// The modules of memoized plugin loads (upstream `#[comemo::memoize]` on
/// `Plugin::module`), keyed by the hash of the bytes.
let plugin_module_cache : Map[U128, Array[(Bytes, Result[Module, HintedError])]] = Map([],
)

///|
/// Memoizes `f` for the plugin function `func` and its arguments.
fn[R] memoized(
  cache : Map[U128, Result[R, HintedError]],
  func : PluginFunc,
  args : Array[Bytes],
  f : () -> R raise HintedError,
) -> R raise HintedError {
  let state = SipHasher128::new()
  state.write(func)
  state.write_usize(args.length())
  for arg in args {
    state.write_usize(arg.length())
    state.write_bytes(arg)
  }
  let key = state.finish128()
  let result = match cache.get(key) {
    Some(result) => result
    None => {
      let result : Result[R, HintedError] = try f() catch {
        e => Err(e)
      } noraise {
        v => Ok(v)
      }
      cache.set(key, result)
      result
    }
  }
  match result {
    Ok(v) => v
    Err(e) => raise e
  }
}

///|
/// Upstream `PartialEq for PluginFunc`.
pub impl Eq for PluginFunc with fn equal(self, other) {
  self.plugin == other.plugin && self.name == other.name
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PluginFunc with Eq::{not_equal, equal}

///|
/// Upstream `Hash for PluginFunc`.
pub impl Fingerprint for PluginFunc with fn fingerprint(self, state) {
  self.plugin.fingerprint(state)
  state.write_str(self.name)
}

///|
#deprecated("call as `Fingerprint::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PluginFunc with Fingerprint::{fingerprint}

///|
/// The persistent store data used for communication between store and host.
priv struct CallData {
  /// Arguments for a current call.
  mut args : Array[Bytes]
  /// The results of the current call.
  mut output : Bytes
  /// A memory error that occurred during execution of the current call.
  mut memory_error : MemoryError?
}

///|
/// If there was an error reading/writing memory, keep the offset + length to
/// display an error message.
priv struct MemoryError {
  offset : UInt
  length : UInt
  write : Bool
}

///|
/// Shared by all pooled & transitioned variants of the plugin.
priv struct PluginBase {
  /// The raw WebAssembly bytes.
  bytes : Bytes
  /// The hash of the bytes (upstream `Bytes` carries a `LazyHash`).
  bytes_hash : U128
  /// The compiled WebAssembly module.
  module_ : @wasmi.Module
  /// A linker used to create a `Store` for execution.
  linker : @wasmi.Linker[CallData]
}

///|
/// An single plugin instance for single-threaded execution.
priv struct PluginInstance {
  /// The underlying wasmi instance.
  instance : @wasmi.Instance
  /// The execution store of this concrete plugin instance.
  store : @wasmi.Store[CallData]
}

///|
/// A snapshot of a plugin instance.
priv struct Snapshot {
  /// The number of pages in the main memory.
  mem_pages : UInt64
  /// The data in the main memory.
  mem_data : FixedArray[Byte]
}

///|
/// A plugin with potentially multiple instances for multi-threaded
/// execution.
priv struct Plugin {
  /// Shared by all variants of the plugin.
  base : PluginBase
  /// A pool of plugin instances.
  ///
  /// When multiple plugin calls run concurrently due to multi-threading, we
  /// create new instances whenever we run out of ones.
  pool : Array[PluginInstance]
  /// A snapshot that new instances should be restored to.
  snapshot : Snapshot?
  /// A combined hash that incorporates all function names and arguments used
  /// in transitions of this plugin, such that this plugin has a deterministic
  /// hash and equality check that can differentiate it from "siblings" (same
  /// base, different transitions).
  fingerprint : U128
}

///|
/// Upstream `PartialEq for Plugin`.
impl Eq for Plugin with fn equal(self, other) {
  self.base.bytes == other.base.bytes && self.fingerprint == other.fingerprint
}

///|
/// Upstream `Hash for Plugin`.
fn Plugin::fingerprint(self : Plugin, state : SipHasher128) -> Unit {
  state.write_u128(self.base.bytes_hash)
  state.write_u128(self.fingerprint)
}

///|
/// The hash of a plugin's bytes.
fn plugin_bytes_hash(bytes : Bytes) -> U128 {
  let state = SipHasher128::new()
  state.write_usize(bytes.length())
  state.write_bytes(bytes)
  state.finish128()
}

///|
/// Create a plugin and turn it into a module.
fn Plugin::module_(bytes : Bytes) -> Module raise HintedError {
  let key = plugin_bytes_hash(bytes)
  let entries = match plugin_module_cache.get(key) {
    Some(entries) => entries
    None => {
      let entries = []
      plugin_module_cache.set(key, entries)
      entries
    }
  }
  for entry in entries {
    if entry.0 == bytes {
      match entry.1 {
        Ok(v) => return v
        Err(e) => raise e
      }
    }
  }
  let result : Result[Module, HintedError] = try
    Plugin::new(bytes, bytes_hash=key).into_module()
  catch {
    e => Err(e)
  } noraise {
    v => Ok(v)
  }
  entries.push((bytes, result))
  match result {
    Ok(v) => v
    Err(e) => raise e
  }
}

///|
/// Wraps the plugin protocol's host functions.
fn plugin_func_type(
  params : Array[@wasmi_core.ValType],
) -> @wasmi_core.FuncType {
  @wasmi_core.FuncType::new(params, []) catch {
    _ => abort("invalid function type")
  }
}

///|
/// Create a new plugin from raw WebAssembly bytes.
fn Plugin::new(
  bytes : Bytes,
  bytes_hash? : U128 = plugin_bytes_hash(bytes),
) -> Plugin raise HintedError {
  let config = @wasmi.Config::default()
  // Disable relaxed SIMD as it can introduce non-determinism.
  config.wasm_relaxed_simd(false) |> ignore
  let engine = @wasmi.Engine::new(config)
  let module_ = @wasmi.Module::new(engine, bytes) catch {
    err => bail("failed to load WebAssembly module (\{err})")
  }
  // Ensure that the plugin exports its memory.
  if !(module_.get_export("memory") is Some(Memory(_))) {
    bail("plugin does not export its memory")
  }
  let linker : @wasmi.Linker[CallData] = @wasmi.Linker::new(engine)
  try {
    linker.func_new(
      "typst_env",
      "wasm_minimal_protocol_send_result_to_host",
      plugin_func_type([I32, I32]),
      wasm_minimal_protocol_send_result_to_host,
    )
    |> ignore
    linker.func_new(
      "typst_env",
      "wasm_minimal_protocol_write_args_to_buffer",
      plugin_func_type([I32]),
      wasm_minimal_protocol_write_args_to_buffer,
    )
    |> ignore
  } catch {
    _ => abort("unreachable")
  }
  let base = { bytes, bytes_hash, module_, linker, }
  let instance = PluginInstance::new(base, None)
  { base, snapshot: None, fingerprint: U128::default(), pool: [instance], }
}

///|
/// Execute a function with access to an instance.
fn Plugin::call(
  self : Plugin,
  func : String,
  args : Array[Bytes],
) -> Bytes raise HintedError {
  // Acquire an instance from the pool (potentially creating a new one).
  let instance = self.acquire()
  // Execute the call on an instance from the pool. If the call fails, we
  // return early and _don't_ return the instance to the pool as it might
  // be irrecoverably damaged.
  let output = instance.call(func, args)
  // Return the instance to the pool.
  self.pool.push(instance)
  output
}

///|
/// Call a mutable plugin function, producing a new mutable whose functions
/// are guaranteed to be able to observe the mutation.
fn Plugin::transition(
  self : Plugin,
  func : String,
  args : Array[Bytes],
) -> Plugin raise HintedError {
  // Derive a new transition hash from the old one and the function and arguments.
  let state = SipHasher128::new()
  state.write_u128(self.fingerprint)
  state.write_str(func)
  state.write_usize(args.length())
  for arg in args {
    state.write_usize(arg.length())
    state.write_bytes(arg)
  }
  let fingerprint = state.finish128()
  // Execute the mutable call on an instance.
  let instance = self.acquire()
  // Call the function. If the call fails, we return early and _don't_
  // return the instance to the pool as it might be irrecoverably damaged.
  instance.call(func, args) |> ignore
  // Snapshot the instance after the mutable call.
  let snapshot = instance.snapshot()
  // Create a new plugin and move (this is important!) the used instance
  // into it, so that the old plugin won't observe the mutation. Also
  // save the snapshot so that instances that are initialized for the
  // transitioned plugin's pool observe the mutation.
  { base: self.base, snapshot: Some(snapshot), fingerprint, pool: [instance], }
}

///|
/// Acquire an instance from the pool (or create a new one).
fn Plugin::acquire(self : Plugin) -> PluginInstance raise HintedError {
  if self.pool.pop() is Some(instance) {
    return instance
  }
  PluginInstance::new(self.base, self.snapshot)
}

///|
/// Turn a plugin into a Typst module containing plugin functions.
fn Plugin::into_module(self : Plugin) -> Module {
  // Build a scope from the collected functions.
  let scope = Scope::new()
  for export_ in self.base.module_.exports() {
    let (name, ty) = export_
    if ty is Func(_) {
      let func = { plugin: self, name, }
      scope.bind(name, Binding::detached(Func(Func::plugin(func)))) |> ignore
    }
  }
  Module::anonymous(scope)
}

///|
/// Create a new execution instance of a plugin, potentially restoring
/// a snapshot.
fn PluginInstance::new(
  base : PluginBase,
  snapshot : Snapshot?,
) -> PluginInstance raise HintedError {
  let data : CallData = { args: [], output: b"", memory_error: None, }
  let store = @wasmi.Store::new(base.linker.engine(), data)
  let instance = base.linker.instantiate_and_start(store, base.module_) catch {
    e => bail("\{e}")
  }
  let instance = { instance, store, }
  if snapshot is Some(snapshot) {
    instance.restore(snapshot)
  }
  instance
}

///|
/// Call a plugin function with byte arguments.
fn PluginInstance::call(
  self : PluginInstance,
  func : String,
  args : Array[Bytes],
) -> Bytes raise HintedError {
  guard self.instance.get_func(self.store, func) is Some(handle) else {
    abort("missing plugin function")
  }
  let ty = handle.ty(self.store)
  // Check function signature. Do this lazily only when a function is called
  // because there might be exported functions like `_initialize` that don't
  // match the schema.
  for v in ty.params() {
    if v != I32 {
      bail(
        "plugin function `\{func}` has a parameter that is not a 32-bit integer",
      )
    }
  }
  if !(ty.results() is [I32]) {
    bail("plugin function `\{func}` does not return exactly one 32-bit integer")
  }
  // Check inputs.
  let expected = ty.params().length()
  let given = args.length()
  if expected != given {
    let s = if expected == 1 { "" } else { "s" }
    let was = if given == 1 { "was" } else { "were" }
    bail(
      "plugin function takes \{expected} argument\{s}, but \{given} \{was} given",
    )
  }
  // Collect the lengths of the argument buffers.
  let lengths : Array[@wasmi.Val] = args.map(a => I32(a.length()))
  // Store the input data.
  self.store.data().args = args
  // Call the function.
  let code : Array[@wasmi.Val] = [I32(-1)]
  handle.call(self.store, lengths, code) catch {
    err => bail("plugin panicked: \{err}")
  }
  let data = self.store.data()
  if data.memory_error is Some({ offset, length, write, }) {
    data.memory_error = None
    let kind = if write { "write" } else { "read" }
    bail(
      "plugin tried to \{kind} out of bounds: pointer 0x\{offset.to_string(radix=16)} is out of bounds for \{kind} of length \{length}",
    )
  }
  // Extract the returned data.
  let output = data.output
  data.output = b""
  // Parse the functions return value.
  match code[0] {
    I32(0) => ()
    I32(1) => {
      let message = @utf8.decode(output[:]) catch {
        _ => bail("plugin errored, but did not return a valid error message")
      }
      bail("plugin errored with: \{message}")
    }
    _ => bail("plugin did not respect the protocol")
  }
  output
}

///|
/// Creates a snapshot of this instance from which another one can be
/// initialized.
fn PluginInstance::snapshot(self : PluginInstance) -> Snapshot {
  let memory = self.memory()
  let mem_pages = memory.size(self.store)
  // Note: `data` is the memory's backing buffer, which may be longer than the
  // memory itself (upstream's slice is exactly `data_size` bytes long).
  let len = memory.data_size(self.store)
  let mem_data = FixedArray::make(len, b'\x00')
  memory.data(self.store).blit_to(mem_data, len~)
  { mem_pages, mem_data, }
}

///|
/// Restores the instance to a snapshot.
fn PluginInstance::restore(self : PluginInstance, snapshot : Snapshot) -> Unit {
  let memory = self.memory()
  let current_size = memory.size(self.store)
  if current_size < snapshot.mem_pages {
    (memory.grow(self.store, snapshot.mem_pages - current_size) |> ignore) catch {
      _ => abort("failed to restore the plugin memory")
    }
  }
  let data = memory.data(self.store)
  snapshot.mem_data.blit_to(data, len=snapshot.mem_data.length())
}

///|
/// Retrieves a handle to the plugin's main memory.
fn PluginInstance::memory(self : PluginInstance) -> @wasmi.Memory {
  match self.instance.get_memory(self.store, "memory") {
    Some(memory) => memory
    None => abort("plugin does not export its memory")
  }
}

///|
/// Retrieves the main memory of the caller's instance.
fn caller_memory(caller : @wasmi.Caller[CallData]) -> @wasmi.Memory {
  match caller.get_export("memory") {
    Some(Memory(memory)) => memory
    _ => abort("plugin does not export its memory")
  }
}

///|
/// Write the arguments to the plugin function into the plugin's memory.
// Cannot fail; host functions share the linker's raising type
// (upstream returns `()`, typst-library/src/foundations/plugin.rs:577).
#warnings("-unused_error_type")
fn wasm_minimal_protocol_write_args_to_buffer(
  caller : @wasmi.Caller[CallData],
  params : Array[@wasmi.Val],
  _results : Array[@wasmi.Val],
) -> Unit raise @wasmi.WasmiError {
  // Upstream's host function is typed (`ptr: u32`, plugin.rs:577) and
  // `func_wrap` (plugin.rs:292) derives the signature from it, so the
  // linker only ever calls it with one `i32`.
  guard! params[0] is I32(ptr)
  let memory = caller_memory(caller)
  let data = caller.data()
  let arguments = data.args
  data.args = []
  let mut offset = ptr.reinterpret_as_uint().to_uint64()
  for arg in arguments {
    memory.write(caller.store(), offset, arg[:]) catch {
      _ => {
        data.memory_error = Some({
          offset: offset.to_uint(),
          length: arg.length().reinterpret_as_uint(),
          write: true,
        })
        return
      }
    }
    offset += arg.length().to_uint64()
  }
}

///|
/// Extracts the output of the plugin function from the plugin's memory.
// Cannot fail; host functions share the linker's raising type
// (upstream returns `()`, typst-library/src/foundations/plugin.rs:598).
#warnings("-unused_error_type")
fn wasm_minimal_protocol_send_result_to_host(
  caller : @wasmi.Caller[CallData],
  params : Array[@wasmi.Val],
  _results : Array[@wasmi.Val],
) -> Unit raise @wasmi.WasmiError {
  // Upstream's host function is typed (`ptr: u32, len: u32`,
  // plugin.rs:598) and `func_wrap` (plugin.rs:285) derives the signature
  // from it, so the linker only ever calls it with two `i32`s.
  guard! params is [I32(ptr), I32(len)]
  let ptr = ptr.reinterpret_as_uint()
  let len = len.reinterpret_as_uint()
  let memory = caller_memory(caller)
  let data = caller.data()
  // Note: upstream resizes the output buffer to `len` before reading; an
  // out of bounds read fails without touching the buffer, so check the
  // bounds first instead of allocating up to 4 GiB.
  if ptr.to_uint64() + len.to_uint64() >
    memory.data_size(caller.store()).to_uint64() {
    data.memory_error = Some({ offset: ptr, length: len, write: false, })
    return
  }
  let buffer = FixedArray::make(len.reinterpret_as_int(), b'\x00')
  memory.read(caller.store(), ptr.to_uint64(), buffer) catch {
    _ => {
      data.memory_error = Some({ offset: ptr, length: len, write: false, })
      return
    }
  }
  data.output = Bytes::from_array(buffer)
}
