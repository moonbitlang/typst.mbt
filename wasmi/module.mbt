// Port of wasmi 1.0.9 `module/{mod,builder,export,global,import,data,element,init_expr,utils}.rs`.

// ---------------------------------------------------------------------------
// Indices (export.rs, global.rs, import.rs)

///|
/// An index to a function within a Wasm module.
pub(all) struct FuncIdx(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncIdx with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncIdx with @debug.Debug::{to_repr}

///|
/// An index to a table within a Wasm module.
pub(all) struct TableIdx(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TableIdx with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TableIdx with @debug.Debug::{to_repr}

///|
/// An index to a linear memory within a Wasm module.
pub(all) struct MemoryIdx(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemoryIdx with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MemoryIdx with @debug.Debug::{to_repr}

///|
/// An index to a global variable within a Wasm module.
pub(all) struct GlobalIdx(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlobalIdx with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlobalIdx with @debug.Debug::{to_repr}

///|
/// A function type index into the Wasm module's type section.
pub(all) struct FuncTypeIdx(Int) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncTypeIdx with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncTypeIdx with @debug.Debug::{to_repr}

///|
pub fn FuncIdx::into_u32(self : FuncIdx) -> UInt {
  self.0.reinterpret_as_uint()
}

///|
/// An external item index (export.rs `ExternIdx`).
pub(all) enum ExternIdx {
  Func(FuncIdx)
  Table(TableIdx)
  Memory(MemoryIdx)
  Global(GlobalIdx)
}

///|
/// Creates a new [`ExternIdx`] from the given [`wasmparser::ExternalKind`] and `index`.
fn ExternIdx::new(kind : @wasmparser.ExternalKind, index : UInt) -> ExternIdx {
  let index = index.reinterpret_as_int()
  match kind {
    Func => Func(FuncIdx(index))
    Table => Table(TableIdx(index))
    Memory => Memory(MemoryIdx(index))
    Global => Global(GlobalIdx(index))
    Tag =>
      abort("wasmi does not support the `exception-handling` Wasm proposal")
  }
}

///|
/// The name of an import (`module::field`).
pub(all) struct ImportName {
  module_ : String
  field : String
}

///|
pub fn ImportName::new(module_ : String, field : String) -> ImportName {
  { module_, field, }
}

///|
pub fn ImportName::module_(self : ImportName) -> String {
  self.module_
}

///|
pub fn ImportName::name(self : ImportName) -> String {
  self.field
}

///|
pub impl Show for ImportName with fn output(self, f) {
  f.write_string(self.module_)
  f.write_string("::")
  f.write_string(self.field)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImportName with Show::{to_string, output}

// ---------------------------------------------------------------------------
// utils.rs

///|
/// Conversions from wasmparser types (upstream `WasmiValueType`).
pub(all) struct WasmiValueType {}

///|
/// Upstream `From<wasmparser::ValType> for WasmiValueType`.
pub fn WasmiValueType::from_wasmparser(
  value_type : @wasmparser.ValType,
) -> @wasmi_core.ValType {
  match value_type {
    I32 => I32
    I64 => I64
    F32 => F32
    F64 => F64
    V128 => V128
    Ref(ref_type) => WasmiValueType::from_ref_type(ref_type)
  }
}

///|
/// Upstream `From<wasmparser::RefType> for WasmiValueType`.
pub fn WasmiValueType::from_ref_type(
  ref_type : @wasmparser.RefType,
) -> @wasmi_core.ValType {
  if ref_type == @wasmparser.reftype_funcref {
    FuncRef
  } else if ref_type == @wasmparser.reftype_externref {
    ExternRef
  } else {
    abort("encountered unsupported reference type")
  }
}

///|
/// Upstream `From<wasmparser::HeapType> for WasmiValueType`.
pub fn WasmiValueType::from_heap_type(
  heap_type : @wasmparser.HeapType,
) -> @wasmi_core.ValType {
  match heap_type {
    Abstract(shared=false, ty=Func) => FuncRef
    Abstract(shared=false, ty=Extern) => ExternRef
    _ => abort("encountered unsupported heap type")
  }
}

///|
/// Upstream `FromWasmparser<wasmparser::TableType> for TableType`.
fn table_type_from_wasmparser(
  table_type : @wasmparser.TableType,
) -> @wasmi_core.TableType {
  let element = WasmiValueType::from_ref_type(table_type.element_type)
  let minimum = table_type.initial
  let maximum = table_type.maximum
  if table_type.table64 {
    @wasmi_core.TableType::new64(element, minimum, maximum)
  } else {
    let minimum = minimum.to_uint()
    let maximum = match maximum {
      Some(m) => Some(m.to_uint())
      None => None
    }
    @wasmi_core.TableType::new(element, minimum, maximum)
  }
}

///|
/// Upstream `FromWasmparser<wasmparser::MemoryType> for MemoryType`.
fn memory_type_from_wasmparser(
  memory_type : @wasmparser.MemoryType,
) -> @wasmi_core.MemoryType {
  if memory_type.shared {
    abort("wasmi does not support the `threads` Wasm proposal")
  }
  let b = @wasmi_core.MemoryType::builder()
    .min(memory_type.initial)
    .max(memory_type.maximum)
    .memory64(memory_type.memory64)
  let b = match memory_type.page_size_log2 {
    Some(page_size_log2) => b.page_size_log2(page_size_log2.to_byte())
    None => b
  }
  b.build() catch {
    err => abort("received invalid `MemoryType` from `wasmparser`: \{err}")
  }
}

///|
/// Upstream `FromWasmparser<wasmparser::GlobalType> for GlobalType`.
fn global_type_from_wasmparser(
  global_type : @wasmparser.GlobalType,
) -> @wasmi_core.GlobalType {
  let value_type = WasmiValueType::from_wasmparser(global_type.content_type)
  let mutability : @wasmi_core.Mutability = if global_type.mutable {
    Var
  } else {
    Const
  }
  @wasmi_core.GlobalType::new(value_type, mutability)
}

///|
/// Upstream `FromWasmparser<&wasmparser::FuncType> for FuncType`.
fn func_type_from_wasmparser(
  func_type : @wasmparser.FuncType,
) -> @wasmi_core.FuncType {
  let params = func_type.params().map(WasmiValueType::from_wasmparser)
  let results = func_type.results().map(WasmiValueType::from_wasmparser)
  @wasmi_core.FuncType::new(params, results) catch {
    error => abort("failed to create function type: \{error}")
  }
}

// ---------------------------------------------------------------------------
// init_expr.rs

///|
/// A binary operator of an extended constant expression.
priv enum ConstBinOp {
  I32Add
  I32Sub
  I32Mul
  I64Add
  I64Sub
  I64Mul
}

///|
/// A single constant expression operator (upstream `init_expr::Op`).
priv enum ConstOp {
  /// A constant value.
  Const(@wasmi_core.UntypedVal)
  /// The value of a global variable.
  Global(UInt)
  /// A Wasm `ref.func index` value.
  FuncRef(UInt)
  /// An arbitrary expression.
  Expr(ConstBinOp, ConstOp, ConstOp)
}

///|
/// Context used to evaluate constant expressions (upstream `EvalContext`).
pub(all) struct EvalContext {
  get_global : (UInt) -> @wasmi_core.UntypedVal?
  get_func : (UInt) -> @wasmi_core.UntypedVal?
}

///|
fn ConstOp::eval(self : ConstOp, ctx : EvalContext) -> @wasmi_core.UntypedVal? {
  match self {
    Const(value) => Some(value)
    Global(index) => (ctx.get_global)(index)
    FuncRef(index) => (ctx.get_func)(index)
    Expr(op, lhs, rhs) => {
      guard lhs.eval(ctx) is Some(lhs) else { return None }
      guard rhs.eval(ctx) is Some(rhs) else { return None }
      let value = match op {
        I32Add =>
          @wasmi_core.UntypedVal::from_i32(
            @wasmi_core.i32_add(lhs.read_i32(), rhs.read_i32()),
          )
        I32Sub =>
          @wasmi_core.UntypedVal::from_i32(
            @wasmi_core.i32_sub(lhs.read_i32(), rhs.read_i32()),
          )
        I32Mul =>
          @wasmi_core.UntypedVal::from_i32(
            @wasmi_core.i32_mul(lhs.read_i32(), rhs.read_i32()),
          )
        I64Add =>
          @wasmi_core.UntypedVal::from_i64(
            @wasmi_core.i64_add(lhs.read_i64(), rhs.read_i64()),
          )
        I64Sub =>
          @wasmi_core.UntypedVal::from_i64(
            @wasmi_core.i64_sub(lhs.read_i64(), rhs.read_i64()),
          )
        I64Mul =>
          @wasmi_core.UntypedVal::from_i64(
            @wasmi_core.i64_mul(lhs.read_i64(), rhs.read_i64()),
          )
      }
      Some(value)
    }
  }
}

///|
/// An empty evaluation context.
let empty_eval_context : EvalContext = {
  get_global: fn(_) { None },
  get_func: fn(_) { None },
}

///|
/// A Wasm constant expression.
///
/// These are used to determine the offsets of memory data
/// and table element segments as well as the initial value
/// of global variables.
pub(all) struct ConstExpr {
  priv op : ConstOp
}

///|
/// Creates a new [`ConstExpr`] from the given Wasm [`ConstExpr`].
///
/// # Note
///
/// The constructor assumes that Wasm validation already succeeded
/// on the input Wasm [`ConstExpr`].
pub fn ConstExpr::new(expr : @wasmparser.ConstExpr) -> ConstExpr {
  let reader = expr.get_operators_reader()
  let stack : Array[ConstOp] = []
  fn expr_op(stack : Array[ConstOp], op : ConstBinOp) -> ConstOp {
    guard stack.pop() is Some(rhs) else {
      abort("must have 2 operators on the stack due to Wasm validation")
    }
    guard stack.pop() is Some(lhs) else {
      abort("must have 2 operators on the stack due to Wasm validation")
    }
    Expr(op, lhs, rhs)
  }
  while true {
    let wasm_op = reader.read() catch {
      error => abort("invalid const expression operator: \{error}")
    }
    let op : ConstOp = match wasm_op {
      I32Const(value~) => Const(@wasmi_core.UntypedVal::from_i32(value))
      I64Const(value~) => Const(@wasmi_core.UntypedVal::from_i64(value))
      F32Const(value~) => Const(@wasmi_core.UntypedVal::from_u32(value.bits()))
      F64Const(value~) => Const(@wasmi_core.UntypedVal::from_u64(value.bits()))
      V128Const(value~) =>
        Const(
          @wasmi_core.UntypedVal::from_v128(
            @wasmi_core.V128::from_le_bytes(value.bytes().to_fixedarray()[:]),
          ),
        )
      GlobalGet(global_index~) => Global(global_index)
      RefNull(hty~) =>
        match hty {
          Abstract(shared=false, ty=Func) | Abstract(shared=false, ty=Extern) =>
            Const(@wasmi_core.UntypedVal::from_u64(0))
          _ => abort("invalid heap type for `ref.null`")
        }
      RefFunc(function_index~) => FuncRef(function_index)
      I32Add => expr_op(stack, I32Add)
      I32Sub => expr_op(stack, I32Sub)
      I32Mul => expr_op(stack, I32Mul)
      I64Add => expr_op(stack, I64Add)
      I64Sub => expr_op(stack, I64Sub)
      I64Mul => expr_op(stack, I64Mul)
      End => break
      _ => abort("unexpected Wasm const expression operator")
    }
    stack.push(op)
  }
  reader.ensure_end() catch {
    _ => abort("Wasm validation requires const expressions to have an `end`")
  }
  guard stack.pop() is Some(op) else {
    abort("must contain the root const expression at this point")
  }
  { op, }
}

///|
/// Create a new `ref.func x` [`ConstExpr`].
pub fn ConstExpr::new_funcref(function_index : UInt) -> ConstExpr {
  { op: FuncRef(function_index), }
}

///|
/// Returns `Some(index)` if the [`ConstExpr`] is a `funcref(index)`.
pub fn ConstExpr::funcref(self : ConstExpr) -> FuncIdx? {
  if self.op is FuncRef(function_index) {
    return Some(FuncIdx(function_index.reinterpret_as_int()))
  }
  None
}

///|
/// Evaluates the [`ConstExpr`] in a constant evaluation context.
///
/// # Note
///
/// This is useful for evaluations during Wasm translation to
/// perform optimizations on the translated bytecode.
pub fn ConstExpr::eval_const(self : ConstExpr) -> @wasmi_core.UntypedVal? {
  self.op.eval(empty_eval_context)
}

///|
/// Evaluates the [`ConstExpr`] given the context for global variables and functions.
pub fn ConstExpr::eval_with_context(
  self : ConstExpr,
  global_get : (UInt) -> @wasmi_core.UntypedVal,
  func_get : (UInt) -> @wasmi_core.UntypedVal,
) -> @wasmi_core.UntypedVal? {
  self.op.eval({
    get_global: fn(index) { Some(global_get(index)) },
    get_func: fn(index) { Some(func_get(index)) },
  })
}

// ---------------------------------------------------------------------------
// data.rs

///|
/// An active data segment.
pub(all) struct ActiveDataSegment {
  /// The linear memory that is to be initialized with this active segment.
  memory_index : MemoryIdx
  /// The offset at which the data segment is initialized.
  offset : ConstExpr
  /// The bytes of the data segment.
  bytes : Bytes
}

///|
/// A Wasm [`Module`] data segment.
pub(all) enum ModuleDataSegment {
  /// An active data segment that is initialized upon module instantiation.
  Active(ActiveDataSegment)
  /// A passive data segment that can be used by some Wasm bulk instructions.
  Passive(Bytes)
}

///|
/// Converts a wasmparser data segment.
fn ModuleDataSegment::from_wasmparser(
  segment : @wasmparser.Data,
) -> ModuleDataSegment {
  match segment.kind {
    Passive => Passive(segment.data.to_owned())
    Active(memory_index~, offset_expr~) =>
      Active({
        memory_index: MemoryIdx(memory_index.reinterpret_as_int()),
        offset: ConstExpr::new(offset_expr),
        bytes: segment.data.to_owned(),
      })
  }
}

// ---------------------------------------------------------------------------
// element.rs

///|
/// The kind of a Wasm module [`ElementSegment`].
pub(all) enum ElementSegmentKind {
  /// A passive [`ElementSegment`] from the `bulk-memory` Wasm proposal.
  Passive
  /// An active [`ElementSegment`].
  Active(table_index~ : TableIdx, offset~ : ConstExpr)
  /// A declared [`ElementSegment`] from the `reference-types` Wasm proposal.
  Declared
}

///|
/// A table element segment within a [`Module`].
pub(all) struct ModuleElementSegment {
  /// The kind of the [`ElementSegment`].
  kind : ElementSegmentKind
  /// The type of elements of the [`ElementSegment`].
  ty : @wasmi_core.ValType
  /// The items of the [`ElementSegment`].
  items : Array[ConstExpr]
}

///|
/// Upstream `From<wasmparser::Element> for ElementSegment`.
fn ModuleElementSegment::from_wasmparser(
  element : @wasmparser.Element,
) -> ModuleElementSegment raise WasmiError {
  let kind : ElementSegmentKind = match element.kind {
    Active(table_index~, offset_expr~) =>
      Active(
        table_index=TableIdx(
          (match table_index {
            Some(i) => i
            None => 0U
          }).reinterpret_as_int(),
        ),
        offset=ConstExpr::new(offset_expr),
      )
    Passive => Passive
    Declared => Declared
  }
  let (items, ty) : (Array[ConstExpr], @wasmi_core.ValType) = match
    element.items {
    Functions(items) => {
      let out = []
      let iter = items.into_iter()
      while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
              iter.next()
            })
            is Some(item) {
        out.push(ConstExpr::new_funcref(item))
      }
      (out, FuncRef)
    }
    Expressions(ref_ty, items) => {
      let ty : @wasmi_core.ValType = if ref_ty.is_func_ref() {
        FuncRef
      } else if ref_ty.is_extern_ref() {
        ExternRef
      } else {
        abort("unsupported Wasm reference type")
      }
      let out = []
      let iter = items.into_iter()
      while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
              iter.next()
            })
            is Some(item) {
        out.push(ConstExpr::new(item))
      }
      (out, ty)
    }
  }
  { kind, ty, items, }
}

///|
pub fn ModuleElementSegment::kind(
  self : ModuleElementSegment,
) -> ElementSegmentKind {
  self.kind
}

///|
pub fn ModuleElementSegment::ty(
  self : ModuleElementSegment,
) -> @wasmi_core.ValType {
  self.ty
}

///|
pub fn ModuleElementSegment::items(
  self : ModuleElementSegment,
) -> Array[ConstExpr] {
  self.items
}

// ---------------------------------------------------------------------------
// mod.rs

///|
/// An imported item of a [`Module`].
pub(all) enum Imported {
  Func(ImportName)
  Table(ImportName)
  Memory(ImportName)
  Global(ImportName)
}

///|
/// The import items of a Wasm [`Module`].
pub(all) struct ModuleImports {
  /// All names and types of all imported items.
  items : Array[Imported]
  /// The amount of imported [`Func`].
  len_funcs : Int
  /// The amount of imported [`Global`].
  len_globals : Int
  /// The amount of imported [`Memory`].
  len_memories : Int
  /// The amount of imported [`Table`].
  len_tables : Int
}

///|
/// The index of the default linear memory.
pub let default_memory_index : Int = 0

///|
/// A parsed and validated WebAssembly module header.
pub(all) struct ModuleHeader {
  priv engine : EngineWeak
  priv func_types : Array[DedupFuncType]
  priv imports : ModuleImports
  priv funcs : Array[DedupFuncType]
  priv tables : Array[@wasmi_core.TableType]
  priv memories : Array[@wasmi_core.MemoryType]
  priv globals : Array[@wasmi_core.GlobalType]
  priv globals_init : Array[ConstExpr]
  /// The exports in insertion order with their indices (upstream uses a
  /// `BTreeMap`, see [`Module::exports`] for the ordering).
  priv exports : Map[String, ExternIdx]
  priv start : FuncIdx?
  priv engine_funcs : EngineFuncSpan
  priv element_segments : Array[ModuleElementSegment]
}

///|
/// Returns the [`Engine`] of the [`ModuleHeader`] (upstream upgrades a weak reference).
pub fn ModuleHeader::engine_upgrade(self : ModuleHeader) -> EngineWeak {
  self.engine
}

///|
/// Returns the [`FuncType`] at the given index.
pub fn ModuleHeader::get_func_type(
  self : ModuleHeader,
  func_type_idx : FuncTypeIdx,
) -> DedupFuncType {
  self.func_types[func_type_idx.0]
}

///|
/// Returns the [`FuncType`] of the indexed function.
pub fn ModuleHeader::get_type_of_func(
  self : ModuleHeader,
  func_idx : FuncIdx,
) -> DedupFuncType {
  self.funcs[func_idx.0]
}

///|
/// Returns the [`GlobalType`] the the indexed global variable.
pub fn ModuleHeader::get_type_of_global(
  self : ModuleHeader,
  global_idx : GlobalIdx,
) -> @wasmi_core.GlobalType {
  self.globals[global_idx.0]
}

///|
/// Returns the [`MemoryType`] the the indexed memory.
pub fn ModuleHeader::get_type_of_memory(
  self : ModuleHeader,
  memory_idx : MemoryIdx,
) -> @wasmi_core.MemoryType {
  self.memories[memory_idx.0]
}

///|
/// Returns the [`TableType`] the the indexed table.
pub fn ModuleHeader::get_type_of_table(
  self : ModuleHeader,
  table_idx : TableIdx,
) -> @wasmi_core.TableType {
  self.tables[table_idx.0]
}

///|
/// Returns the [`EngineFunc`] for the given [`FuncIdx`].
///
/// Returns `None` if [`FuncIdx`] refers to an imported function.
pub fn ModuleHeader::get_engine_func(
  self : ModuleHeader,
  func_idx : FuncIdx,
) -> EngineFunc? {
  let index = func_idx.0 - self.imports.len_funcs
  if index < 0 {
    return None
  }
  Some(self.engine_funcs.get_or_panic(index))
}

///|
/// Returns the [`FuncIdx`] of the given [`EngineFunc`].
pub fn ModuleHeader::get_func_index(
  self : ModuleHeader,
  func : EngineFunc,
) -> FuncIdx? {
  guard self.engine_funcs.position(func) is Some(position) else { return None }
  Some(FuncIdx(position + self.imports.len_funcs))
}

///|
/// Returns the global variable type and optional initial value.
pub fn ModuleHeader::get_global(
  self : ModuleHeader,
  global_idx : GlobalIdx,
) -> (@wasmi_core.GlobalType, ConstExpr?) {
  let index = global_idx.0
  let len_imports = self.imports.len_globals
  let global_type = self.get_type_of_global(global_idx)
  if index < len_imports {
    (global_type, None)
  } else {
    let init_expr = self.globals_init[index - len_imports]
    (global_type, Some(init_expr))
  }
}

///|
/// A builder for a [`ModuleHeader`] (builder.rs `ModuleHeaderBuilder`).
priv struct ModuleHeaderBuilder {
  engine : Engine
  func_types : Array[DedupFuncType]
  imports_funcs : Array[ImportName]
  imports_tables : Array[ImportName]
  imports_memories : Array[ImportName]
  imports_globals : Array[ImportName]
  funcs : Array[DedupFuncType]
  tables : Array[@wasmi_core.TableType]
  memories : Array[@wasmi_core.MemoryType]
  globals : Array[@wasmi_core.GlobalType]
  globals_init : Array[ConstExpr]
  exports : Map[String, ExternIdx]
  mut start : FuncIdx?
  mut engine_funcs : EngineFuncSpan
  mut element_segments : Array[ModuleElementSegment]
}

///|
fn ModuleHeaderBuilder::new(engine : Engine) -> ModuleHeaderBuilder {
  {
    engine,
    func_types: [],
    imports_funcs: [],
    imports_tables: [],
    imports_memories: [],
    imports_globals: [],
    funcs: [],
    tables: [],
    memories: [],
    globals: [],
    globals_init: [],
    exports: {},
    start: None,
    engine_funcs: EngineFuncSpan::empty(),
    element_segments: [],
  }
}

///|
/// Finishes construction of [`ModuleHeader`].
fn ModuleHeaderBuilder::finish(self : ModuleHeaderBuilder) -> ModuleHeader {
  let items : Array[Imported] = []
  for name in self.imports_funcs {
    items.push(Func(name))
  }
  for name in self.imports_tables {
    items.push(Table(name))
  }
  for name in self.imports_memories {
    items.push(Memory(name))
  }
  for name in self.imports_globals {
    items.push(Global(name))
  }
  {
    engine: self.engine.weak(),
    func_types: self.func_types,
    imports: {
      items,
      len_funcs: self.imports_funcs.length(),
      len_globals: self.imports_globals.length(),
      len_memories: self.imports_memories.length(),
      len_tables: self.imports_tables.length(),
    },
    funcs: self.funcs,
    tables: self.tables,
    memories: self.memories,
    globals: self.globals,
    globals_init: self.globals_init,
    exports: self.exports,
    start: self.start,
    engine_funcs: self.engine_funcs,
    element_segments: self.element_segments,
  }
}

///|
/// A parsed and validated WebAssembly module.
// `custom_sections` is only read by upstream's `Module::custom_sections()`
// accessor (wasmi 1.0.9 module/mod.rs:451), which is not ported: Typst's
// plugins do not read custom sections.
#warnings("-unused_field")
pub struct Module {
  priv engine : Engine
  priv header : ModuleHeader
  priv data_segments : Array[ModuleDataSegment]
  priv custom_sections : Array[(String, Bytes)]
}

///|
/// Returns the [`Engine`] used during creation of the [`Module`].
pub fn Module::engine(self : Module) -> Engine {
  self.engine
}

///|
/// Returns the [`ModuleHeader`] of the [`Module`].
pub fn Module::module_header(self : Module) -> ModuleHeader {
  self.header
}

///|
/// The type of an exported or imported item.
pub(all) enum ExternType {
  Global(@wasmi_core.GlobalType)
  Table(@wasmi_core.TableType)
  Memory(@wasmi_core.MemoryType)
  Func(@wasmi_core.FuncType)
}

///|
/// Returns the [`ExternType`] of the indexed item.
fn Module::get_extern_type(self : Module, idx : ExternIdx) -> ExternType {
  let header = self.header
  match idx {
    Func(index) => Func(self.engine.resolve_func_type(header.funcs[index.0]))
    Table(index) => Table(header.tables[index.0])
    Memory(index) => Memory(header.memories[index.0])
    Global(index) => Global(header.globals[index.0])
  }
}

///|
/// Compares strings by their UTF-8 bytes (Rust `str` ordering).
fn compare_utf8(a : String, b : String) -> Int {
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let ca = a.get_char(i).unwrap()
    let cb = b.get_char(j).unwrap()
    if ca != cb {
      return ca.to_int().compare(cb.to_int())
    }
    i += if ca.to_int() > 0xFFFF { 2 } else { 1 }
    j += if cb.to_int() > 0xFFFF { 2 } else { 1 }
  }
  (a.length() - i).compare(b.length() - j)
}

///|
/// Returns the exports of the [`Module`] with their types.
///
/// # Note
///
/// Upstream stores the exports in a `BTreeMap<Box<str>, _>` (wasmi is built
/// without its `hash-collections` feature), so they are yielded in the byte
/// order of their names.
pub fn Module::exports(self : Module) -> Array[(String, ExternType)] {
  let names = self.header.exports.keys().collect()
  names.sort_by(compare_utf8)
  names.map(fn(name) {
    (name, self.get_extern_type(self.header.exports.get(name).unwrap()))
  })
}

///|
/// Looks up an export in this [`Module`] by its `name`.
pub fn Module::get_export(self : Module, name : String) -> ExternType? {
  guard self.header.exports.get(name) is Some(idx) else { return None }
  Some(self.get_extern_type(idx))
}

///|
/// A descriptor for an imported value into a Wasm [`Module`].
pub(all) struct ImportType {
  name : ImportName
  ty : ExternType
}

///|
pub fn ImportType::module_(self : ImportType) -> String {
  self.name.module_
}

///|
pub fn ImportType::name(self : ImportType) -> String {
  self.name.field
}

///|
pub fn ImportType::ty(self : ImportType) -> ExternType {
  self.ty
}

///|
/// Returns the imports of the [`Module`] (upstream `ModuleImportsIter`).
pub fn Module::imports(self : Module) -> Array[ImportType] {
  let header = self.header
  let out = []
  let mut funcs = 0
  let mut tables = 0
  let mut memories = 0
  let mut globals = 0
  for imported in header.imports.items {
    match imported {
      Func(name) => {
        let func_type = self.engine.resolve_func_type(header.funcs[funcs])
        funcs += 1
        out.push({ name, ty: Func(func_type), })
      }
      Table(name) => {
        out.push({ name, ty: Table(header.tables[tables]), })
        tables += 1
      }
      Memory(name) => {
        out.push({ name, ty: Memory(header.memories[memories]), })
        memories += 1
      }
      Global(name) => {
        out.push({ name, ty: Global(header.globals[globals]), })
        globals += 1
      }
    }
  }
  out
}
