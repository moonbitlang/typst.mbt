// Port of wasmi 1.0.9 `engine/{mod,config,func_types,block_type,code_map}.rs`
// and `engine/limits/{engine,stack}.rs`.

// ---------------------------------------------------------------------------
// limits/stack.rs

///|
/// The configured limits of the Wasmi executor (upstream `StackConfig`).
pub(all) struct StackConfig {
  /// The maximum recursion depth.
  mut max_recursion_depth : Int
  /// The minimum (or initial) value stack height.
  mut min_stack_height : Int
  /// The maximum value stack height.
  mut max_stack_height : Int
  /// The maximum number of cached stacks for reuse.
  mut max_cached_stacks : Int
}

///|
/// The default maximum recursion depth.
let default_max_recursion_depth : Int = 1000

///|
/// The default minimum (or initial) value stack height.
let default_min_stack_height : Int = 1_000

///|
/// The default maximum value stack height.
let default_max_stack_height : Int = 1_000_000

///|
/// The default maximum number of cached stacks for reuse.
let default_max_cached_stacks : Int = 2

///|
pub fn StackConfig::default() -> StackConfig {
  {
    max_recursion_depth: default_max_recursion_depth,
    min_stack_height: default_min_stack_height,
    max_stack_height: default_max_stack_height,
    max_cached_stacks: default_max_cached_stacks,
  }
}

///|
pub fn StackConfig::max_recursion_depth(self : StackConfig) -> Int {
  self.max_recursion_depth
}

///|
pub fn StackConfig::min_stack_height(self : StackConfig) -> Int {
  self.min_stack_height
}

///|
pub fn StackConfig::max_stack_height(self : StackConfig) -> Int {
  self.max_stack_height
}

// ---------------------------------------------------------------------------
// limits/engine.rs

///|
/// An error that can occur upon parsing or compiling a Wasm module when
/// [`EnforcedLimits`] are set.
pub(all) enum EnforcedLimitsError {
  TooManyGlobals(limit~ : UInt)
  TooManyTables(limit~ : UInt)
  TooManyFunctions(limit~ : UInt)
  TooManyMemories(limit~ : UInt)
  TooManyElementSegments(limit~ : UInt)
  TooManyDataSegments(limit~ : UInt)
  TooManyParameters(limit~ : Int)
  TooManyResults(limit~ : Int)
  MinAvgBytesPerFunction(limit~ : UInt, avg~ : UInt)
}

///|
pub impl Show for EnforcedLimitsError with output(self, f) {
  match self {
    TooManyGlobals(limit~) =>
      f.write_string(
        "the Wasm module exceeds the limit of \{limit} global variables",
      )
    TooManyTables(limit~) =>
      f.write_string("the Wasm module exceeds the limit of \{limit} tables")
    TooManyFunctions(limit~) =>
      f.write_string("the Wasm modules exceeds the limit of \{limit} functions")
    TooManyMemories(limit~) =>
      f.write_string("the Wasm module exceeds the limit of \{limit} memories")
    TooManyElementSegments(limit~) =>
      f.write_string(
        "the Wasm module exceeds the limit of \{limit} active element segments",
      )
    TooManyDataSegments(limit~) =>
      f.write_string(
        "the Wasm module exceeds the limit of \{limit} active data segments",
      )
    TooManyParameters(limit~) =>
      f.write_string("a function type exceeds the limit of \{limit} parameters")
    TooManyResults(limit~) =>
      f.write_string("a function type exceeds the limit of \{limit} results")
    MinAvgBytesPerFunction(limit~, avg~) =>
      f.write_string(
        "the Wasm module failed to meet the minimum average bytes per function of \{limit}: avg=\{avg}",
      )
  }
}

///|
/// The required minimum average number of bytes per function.
pub(all) struct AvgBytesPerFunctionLimit {
  req_funcs_bytes : UInt
  min_avg_bytes_per_function : UInt
}

///|
/// Stores customizable limits for the [`Engine`] when parsing or compiling Wasm modules.
///
/// By default no limits are enforced.
pub(all) struct EnforcedLimits {
  max_globals : UInt?
  max_functions : UInt?
  max_tables : UInt?
  max_element_segments : UInt?
  max_memories : UInt?
  max_data_segments : UInt?
  max_params : Int?
  max_results : Int?
  min_avg_bytes_per_function : AvgBytesPerFunctionLimit?
}

///|
pub fn EnforcedLimits::default() -> EnforcedLimits {
  {
    max_globals: None,
    max_functions: None,
    max_tables: None,
    max_element_segments: None,
    max_memories: None,
    max_data_segments: None,
    max_params: None,
    max_results: None,
    min_avg_bytes_per_function: None,
  }
}

// ---------------------------------------------------------------------------
// config.rs

///|
/// The chosen mode of Wasm to Wasmi bytecode compilation.
pub(all) enum CompilationMode {
  /// The Wasm code is compiled eagerly to Wasmi bytecode.
  Eager
  /// The Wasm code is validated eagerly and translated lazily on first use.
  LazyTranslation
  /// The Wasm code is validated and translated lazily on first use.
  Lazy
} derive(Eq)

///|
/// Configuration for an [`Engine`].
pub(all) struct Config {
  /// The limits set on the value stack and call stack.
  stack : StackConfig
  /// The Wasm features used when validating or translating functions.
  mut features : @wasmparser.WasmFeatures
  /// Is `true` if Wasmi executions shall consume fuel.
  mut consume_fuel : Bool
  /// Is `true` if Wasmi shall ignore Wasm custom sections when parsing Wasm modules.
  mut ignore_custom_sections : Bool
  /// The configured fuel costs of all Wasmi bytecode instructions.
  fuel_costs : @wasmi_core.FuelCostsProvider
  /// The mode of Wasm to Wasmi bytecode compilation.
  mut compilation_mode : CompilationMode
  /// Enforced limits for Wasm module parsing and compilation.
  mut limits : EnforcedLimits
}

///|
/// Returns the default [`WasmFeatures`].
fn Config::default_features() -> @wasmparser.WasmFeatures {
  let features = @wasmparser.WasmFeatures::empty()
  features
  .set(@wasmparser.MUTABLE_GLOBAL, true)
  .set(@wasmparser.MULTI_VALUE, true)
  .set(@wasmparser.MULTI_MEMORY, true)
  .set(@wasmparser.SATURATING_FLOAT_TO_INT, true)
  .set(@wasmparser.SIGN_EXTENSION, true)
  .set(@wasmparser.BULK_MEMORY, true)
  .set(@wasmparser.REFERENCE_TYPES, true)
  .set(@wasmparser.GC_TYPES, true) // required by reference-types
  .set(@wasmparser.TAIL_CALL, true)
  .set(@wasmparser.EXTENDED_CONST, true)
  .set(@wasmparser.FLOATS, true)
  .set(@wasmparser.CUSTOM_PAGE_SIZES, false)
  .set(@wasmparser.MEMORY64, true)
  .set(@wasmparser.WIDE_ARITHMETIC, false)
  .set(@wasmparser.SIMD, true)
  .set(@wasmparser.RELAXED_SIMD, true)
}

///|
pub fn Config::default() -> Config {
  {
    stack: StackConfig::default(),
    features: Config::default_features(),
    consume_fuel: false,
    ignore_custom_sections: false,
    fuel_costs: @wasmi_core.FuelCostsProvider::new(None),
    compilation_mode: LazyTranslation,
    limits: EnforcedLimits::default(),
  }
}

///|
/// Enable or disable the Wasm relaxed-simd proposal.
pub fn Config::wasm_relaxed_simd(self : Config, enable : Bool) -> Config {
  self.features = self.features.set(@wasmparser.RELAXED_SIMD, enable)
  self
}

///|
/// Returns `true` if the [`Config`] enables fuel consumption by the [`Engine`].
pub fn Config::get_consume_fuel(self : Config) -> Bool {
  self.consume_fuel
}

///|
/// Configures whether Wasmi will consume fuel during execution to either
/// halt execution as desired.
pub fn Config::set_consume_fuel(self : Config, enable : Bool) -> Config {
  self.consume_fuel = enable
  self
}

///|
/// Returns `true` if the [`Config`] mandates to ignore Wasm custom sections.
pub fn Config::get_ignore_custom_sections(self : Config) -> Bool {
  self.ignore_custom_sections
}

///|
/// Returns the configured fuel costs.
pub fn Config::fuel_costs(self : Config) -> @wasmi_core.FuelCostsProvider {
  self.fuel_costs
}

///|
/// Returns the [`CompilationMode`] used for the [`Engine`].
pub fn Config::get_compilation_mode(self : Config) -> CompilationMode {
  self.compilation_mode
}

///|
/// Sets the [`CompilationMode`] used for the [`Engine`].
pub fn Config::compilation_mode(self : Config, mode : CompilationMode) -> Config {
  self.compilation_mode = mode
  self
}

///|
/// Returns the [`EnforcedLimits`] used for the [`Engine`].
pub fn Config::get_enforced_limits(self : Config) -> EnforcedLimits {
  self.limits
}

///|
/// Returns the [`WasmFeatures`] represented by the [`Config`].
pub fn Config::wasm_features(self : Config) -> @wasmparser.WasmFeatures {
  self.features
}

// ---------------------------------------------------------------------------
// func_types.rs

///|
/// A deduplicated Wasm [`FuncType`] (its index in the [`Engine`]'s
/// registry; equal function types share their index).
pub(all) struct DedupFuncType(Int) derive(Eq, Hash, Debug)

///|
/// A registry for [`FuncType`] entities.
priv struct FuncTypeRegistry {
  /// Deduplicated function types, keyed by their structure.
  dedup : Map[String, Int]
  /// The registered function types.
  func_types : Array[@wasmi_core.FuncType]
}

///|
/// Returns a structural key of a function type.
fn func_type_key(func_type : @wasmi_core.FuncType) -> String {
  let buf = StringBuilder::new()
  for ty in func_type.params() {
    buf.write_string(val_type_name(ty))
    buf.write_char(',')
  }
  buf.write_char('>')
  for ty in func_type.results() {
    buf.write_string(val_type_name(ty))
    buf.write_char(',')
  }
  buf.to_string()
}

///|
/// The Debug name of a [`ValType`].
pub fn val_type_name(ty : @wasmi_core.ValType) -> String {
  match ty {
    I32 => "I32"
    I64 => "I64"
    F32 => "F32"
    F64 => "F64"
    V128 => "V128"
    FuncRef => "FuncRef"
    ExternRef => "ExternRef"
  }
}

///|
fn FuncTypeRegistry::alloc_func_type(
  self : FuncTypeRegistry,
  func_type : @wasmi_core.FuncType,
) -> DedupFuncType {
  let key = func_type_key(func_type)
  match self.dedup.get(key) {
    Some(index) => DedupFuncType(index)
    None => {
      let index = self.func_types.length()
      self.func_types.push(func_type)
      self.dedup.set(key, index)
      DedupFuncType(index)
    }
  }
}

// ---------------------------------------------------------------------------
// block_type.rs

///|
/// The type of a Wasm control flow block.
pub(all) enum BlockType {
  /// A block type with no parameters and no results.
  Empty
  /// A block type with no parameters and exactly one result.
  Returns(@wasmi_core.ValType)
  /// A general block type with parameters and results.
  FuncType(DedupFuncType)
}

///|
/// Creates a new [`BlockType`] from the given [`wasmparser::BlockType`].
pub fn BlockType::new(
  block_type : @wasmparser.BlockType,
  res : ModuleHeader,
) -> BlockType {
  match block_type {
    Empty => Empty
    Type(return_type) => Returns(WasmiValueType::from_wasmparser(return_type))
    FuncType(func_type_idx) =>
      FuncType(res.get_func_type(FuncTypeIdx(func_type_idx.reinterpret_as_int())))
  }
}

///|
/// Creates a [`BlockType`] with parameters and results.
pub fn BlockType::func_type(func_type : DedupFuncType) -> BlockType {
  FuncType(func_type)
}

///|
/// Returns the number of parameters of the [`BlockType`].
pub fn BlockType::len_params(self : BlockType, engine : Engine) -> Int {
  match self {
    Empty | Returns(_) => 0
    FuncType(func_type) => engine.resolve_func_type(func_type).len_params()
  }
}

///|
/// Returns the number of results of the [`BlockType`].
pub fn BlockType::len_results(self : BlockType, engine : Engine) -> Int {
  match self {
    Empty => 0
    Returns(_) => 1
    FuncType(func_type) => engine.resolve_func_type(func_type).len_results()
  }
}

///|
/// Returns the function type of the [`BlockType`] (upstream `func_type_with`).
pub fn BlockType::func_type_of(self : BlockType, engine : Engine) -> @wasmi_core.FuncType {
  match self {
    Empty => @wasmi_core.FuncType::new([], []) catch { _ => abort("invalid func type") }
    Returns(return_type) =>
      @wasmi_core.FuncType::new([], [return_type]) catch {
        _ => abort("invalid func type")
      }
    FuncType(func_type) => engine.resolve_func_type(func_type)
  }
}

// ---------------------------------------------------------------------------
// code_map.rs

///|
/// A reference to a compiled function stored in the [`CodeMap`] of an [`Engine`].
pub(all) struct EngineFunc(Int) derive(Eq, Compare, Hash, Debug)

///|
/// Upstream `From<InternalFunc> for EngineFunc`.
pub fn EngineFunc::from_internal(index : @ir.InternalFunc) -> EngineFunc {
  EngineFunc(index.0)
}

///|
/// Upstream `From<EngineFunc> for InternalFunc`.
pub fn EngineFunc::to_internal(self : EngineFunc) -> @ir.InternalFunc {
  @ir.InternalFunc(self.0)
}

///|
/// A span of contiguous [`EngineFunc`] references.
pub(all) struct EngineFuncSpan {
  start : Int
  end : Int
}

///|
/// Creates an empty [`EngineFuncSpan`].
pub fn EngineFuncSpan::empty() -> EngineFuncSpan {
  { start: 0, end: 0 }
}

///|
/// Returns the number of [`EngineFunc`] in `self`.
pub fn EngineFuncSpan::len(self : EngineFuncSpan) -> Int {
  self.end - self.start
}

///|
/// Returns the n-th [`EngineFunc`] in `self`, if any.
pub fn EngineFuncSpan::get(self : EngineFuncSpan, n : Int) -> EngineFunc? {
  if n < 0 || n >= self.len() {
    return None
  }
  Some(EngineFunc(self.start + n))
}

///|
/// Returns the position of the [`EngineFunc`] in `self`, if any.
pub fn EngineFuncSpan::position(self : EngineFuncSpan, func : EngineFunc) -> Int? {
  if func.0 < self.start || func.0 >= self.end {
    return None
  }
  Some(func.0 - self.start)
}

///|
/// Returns the n-th [`EngineFunc`] in `self`, panicking if out of bounds.
pub fn EngineFuncSpan::get_or_panic(self : EngineFuncSpan, n : Int) -> EngineFunc {
  match self.get(n) {
    Some(f) => f
    None => abort("out of bounds `EngineFunc` index: \{n}")
  }
}

///|
/// The state of a function in the [`CodeMap`].
priv enum CodeMapEntity {
  /// The function entity has not yet been initialized.
  Uninit
  /// An internal function that has not yet been compiled.
  Uncompiled(UncompiledFuncEntity)
  /// The function entity is currently compiling.
  Compiling
  /// The function entity failed to compile lazily.
  FailedToCompile
  /// An internal function that has already been compiled.
  Compiled(CompiledFuncEntity)
}

///|
/// An internal uncompiled function.
priv struct UncompiledFuncEntity {
  /// The index of the function within the Wasm module.
  func_index : FuncIdx
  /// The Wasm binary bytes of the function body.
  bytes : BytesView
  /// The Wasm module of the Wasm function.
  module : ModuleHeader
}

///|
/// Meta information about a compiled function.
pub(all) struct CompiledFuncEntity {
  /// The sequence of [`Op`] of the [`CompiledFuncEntity`].
  instrs : FixedArray[@ir.Op]
  /// The constant values local to the [`EngineFunc`] (in frame order).
  consts : Array[@wasmi_core.UntypedVal]
  /// The number of stack slots used by the [`EngineFunc`] in total.
  ///
  /// # Note
  ///
  /// This includes registers to store the function local constant values,
  /// function parameters, function locals and dynamically used registers.
  len_stack_slots : Int
}

///|
/// Creates a new [`CompiledFuncEntity`].
///
/// # Panics
///
/// - If `instrs` is empty.
/// - If `instrs` contains more than `i32::MAX` instructions.
pub fn CompiledFuncEntity::new(
  len_stack_slots : Int,
  instrs : FixedArray[@ir.Op],
  consts : Array[@wasmi_core.UntypedVal],
) -> CompiledFuncEntity {
  if instrs.length() == 0 {
    abort("compiled functions must have at least one instruction")
  }
  { instrs, consts, len_stack_slots }
}

///|
/// Returns the [`Op`]s of the compiled function.
pub fn CompiledFuncEntity::instrs(self : CompiledFuncEntity) -> FixedArray[@ir.Op] {
  self.instrs
}

///|
/// Returns the number of stack slots used by the compiled function.
pub fn CompiledFuncEntity::len_stack_slots(self : CompiledFuncEntity) -> Int {
  self.len_stack_slots
}

///|
/// Returns the function local constant values of the compiled function.
pub fn CompiledFuncEntity::consts(self : CompiledFuncEntity) -> Array[@wasmi_core.UntypedVal] {
  self.consts
}

///|
/// Datastructure to efficiently store information about compiled functions.
priv struct CodeMap {
  funcs : Array[CodeMapEntity]
  features : @wasmparser.WasmFeatures
}

///|
fn CodeMap::new(config : Config) -> CodeMap {
  { funcs: [], features: config.wasm_features() }
}

///|
/// Allocates `amount` new uninitialized [`EngineFunc`] to the [`CodeMap`].
fn CodeMap::alloc_funcs(self : CodeMap, amount : Int) -> EngineFuncSpan {
  let start = self.funcs.length()
  for _ in 0..<amount {
    self.funcs.push(Uninit)
  }
  { start, end: self.funcs.length() }
}

///|
/// Initializes the [`EngineFunc`] with its [`CompiledFuncEntity`].
fn CodeMap::init_func_as_compiled(
  self : CodeMap,
  func : EngineFunc,
  entity : CompiledFuncEntity,
) -> Unit {
  guard self.funcs[func.0] is Uninit
  self.funcs[func.0] = Compiled(entity)
}

///|
/// Initializes the [`EngineFunc`] for lazy translation.
fn CodeMap::init_func_as_uncompiled(
  self : CodeMap,
  func : EngineFunc,
  func_idx : FuncIdx,
  bytes : BytesView,
  module : ModuleHeader,
) -> Unit {
  guard self.funcs[func.0] is Uninit
  self.funcs[func.0] = Uncompiled({ func_index: func_idx, bytes, module })
}

///|
/// Returns the [`CompiledFuncEntity`] of `func`, compiling it lazily if needed.
fn CodeMap::get(self : CodeMap, func : EngineFunc) -> CompiledFuncEntity raise WasmiError {
  match self.funcs[func.0] {
    Compiled(entity) => entity
    Uncompiled(uncompiled) => {
      self.funcs[func.0] = Compiling
      let compiled = uncompiled.compile() catch {
        error => {
          self.funcs[func.0] = FailedToCompile
          raise error
        }
      }
      self.funcs[func.0] = Compiled(compiled)
      compiled
    }
    FailedToCompile =>
      raise WasmiError::from_translation(TranslationError::LazyCompilationFailed)
    Compiling | Uninit => abort("unexpected function state")
  }
}

///|
/// Compile the uncompiled function entity.
///
/// # Errors
///
/// - If `func` fails to compile or validate.
fn UncompiledFuncEntity::compile(
  self : UncompiledFuncEntity,
) -> CompiledFuncEntity raise WasmiError {
  let translator = FuncTranslator::new(self.func_index, self.module)
  FuncTranslationDriver::new(0, self.bytes, self.module.engine_upgrade().config())
  .translate(translator)
}

// ---------------------------------------------------------------------------
// mod.rs

///|
/// The global counter of engines (upstream `EngineIdx::new`).
let engine_counter : Ref[Int] = { val: 0 }

///|
/// The Wasmi interpreter.
///
/// # Note
///
/// - The current Wasmi engine implements a bytecode interpreter.
/// - This structure is intentionally cheap to copy.
///   Most of its API has a `&self` receiver, so can be shared easily.
pub struct Engine {
  priv idx : Int
  priv config : Config
  priv code_map : CodeMap
  priv func_types : FuncTypeRegistry
  /// Reusable value stacks (upstream `EngineStacks`).
  priv stacks : Array[Stack_]
}

///|
/// Creates a new [`Engine`] with the given [`Config`].
pub fn Engine::new(config : Config) -> Engine {
  let idx = engine_counter.val
  engine_counter.val += 1
  {
    idx,
    config,
    code_map: CodeMap::new(config),
    func_types: { dedup: {}, func_types: [] },
    stacks: [],
  }
}

///|
/// Creates a new default [`Engine`].
pub fn Engine::default() -> Engine {
  Engine::new(Config::default())
}

///|
/// Returns a shared reference to the [`Config`] of the [`Engine`].
pub fn Engine::config(self : Engine) -> Config {
  self.config
}

///|
/// Returns `true` if both [`Engine`] references `a` and `b` refer to the same [`Engine`].
pub fn Engine::same(a : Engine, b : Engine) -> Bool {
  physical_equal(a, b)
}

///|
/// Allocates a new function type to the [`Engine`].
pub fn Engine::alloc_func_type(
  self : Engine,
  func_type : @wasmi_core.FuncType,
) -> DedupFuncType {
  self.func_types.alloc_func_type(func_type)
}

///|
/// Resolves a deduplicated function type into a [`FuncType`].
pub fn Engine::resolve_func_type(
  self : Engine,
  func_type : DedupFuncType,
) -> @wasmi_core.FuncType {
  self.func_types.func_types[func_type.0]
}

///|
/// Allocates `amount` new uninitialized [`EngineFunc`] to the [`CodeMap`].
pub fn Engine::alloc_funcs(self : Engine, amount : Int) -> EngineFuncSpan {
  self.code_map.alloc_funcs(amount)
}

///|
/// Returns the compiled function `func`, translating it lazily if needed.
pub fn Engine::get_compiled(
  self : Engine,
  func : EngineFunc,
) -> CompiledFuncEntity raise WasmiError {
  self.code_map.get(func)
}

///|
/// Translates the Wasm function using the [`Engine`] (upstream
/// `translate_func`, for the `LazyTranslation` compilation mode with a
/// validator: the body is validated now and translated on first use).
pub fn Engine::translate_func(
  self : Engine,
  func_index : FuncIdx,
  engine_func : EngineFunc,
  offset : Int,
  bytes : BytesView,
  module : ModuleHeader,
  func_to_validate : @wasmparser.FuncToValidate?,
) -> Unit raise WasmiError {
  match (self.config.get_compilation_mode(), func_to_validate) {
    (Eager, _) => {
      if func_to_validate is Some(func_to_validate) {
        validate_func_body(func_to_validate, offset, bytes, self.config)
      }
      let translator = FuncTranslator::new(func_index, module)
      let compiled = FuncTranslationDriver::new(offset, bytes, self.config).translate(
        translator,
      )
      self.code_map.init_func_as_compiled(engine_func, compiled)
    }
    (LazyTranslation, Some(func_to_validate)) => {
      validate_func_body(func_to_validate, offset, bytes, self.config)
      self.code_map.init_func_as_uncompiled(engine_func, func_index, bytes, module)
    }
    (_, _) =>
      self.code_map.init_func_as_uncompiled(engine_func, func_index, bytes, module)
  }
}
