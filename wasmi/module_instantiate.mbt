// Port of wasmi 1.0.9 `module/instantiate/{mod,error}.rs`.

///|
/// An error that may occur upon instantiation of a Wasm module.
pub(all) enum InstantiationError {
  /// Caused when the number of required imports does not match
  /// the number of given externals upon module instantiation.
  InvalidNumberOfImports(required~ : Int, given~ : Int)
  /// Caused when a given external value does not match the
  /// type of the required import for module instantiation.
  ImportsExternalsMismatch(expected~ : ExternType, actual~ : Extern)
  /// Returned when a global has a mismatching type.
  GlobalTypeMismatch(
    expected~ : @wasmi_core.GlobalType,
    actual~ : @wasmi_core.GlobalType
  )
  /// Returned when a function has a mismatching type.
  FuncTypeMismatch(
    expected~ : @wasmi_core.FuncType,
    actual~ : @wasmi_core.FuncType
  )
  /// Returned when a table has a mismatching type.
  TableTypeMismatch(
    expected~ : @wasmi_core.TableType,
    actual~ : @wasmi_core.TableType
  )
  /// Returned when a linear memory has a mismatching type.
  MemoryTypeMismatch(
    expected~ : @wasmi_core.MemoryType,
    actual~ : @wasmi_core.MemoryType
  )
  /// Caused when an element segment does not fit into the specified table instance.
  ElementSegmentDoesNotFit(table~ : Table, table_index~ : UInt64, len~ : UInt)
  /// Caused when the `start` function was unexpectedly found in the instantiated module.
  UnexpectedStartFn(index~ : UInt)
  /// When trying to instantiate more instances than supported by Wasmi.
  TooManyInstances
  /// When trying to instantiate more tables than supported by Wasmi.
  TooManyTables
  /// When trying to instantiate more linear memories than supported by Wasmi.
  TooManyMemories
  /// Encountered when failing to instantiate a linear memory.
  FailedToInstantiateMemory(@wasmi_core.MemoryError)
  /// Encountered when failing to instantiate a table.
  FailedToInstantiateTable(@wasmi_core.TableError)
}

///|
pub impl Show for InstantiationError with fn output(self, f) {
  match self {
    InvalidNumberOfImports(required~, given~) =>
      f.write_string(
        "invalid number of imports: required = \{required}, given = \{given}",
      )
    ImportsExternalsMismatch(expected~, actual~) =>
      f.write_string(
        "expected \{expected} external for import but found \{actual}",
      )
    GlobalTypeMismatch(expected~, actual~) =>
      f.write_string(
        "imported global type mismatch. expected \{debug_global_type(expected)} but found \{debug_global_type(actual)}",
      )
    FuncTypeMismatch(expected~, actual~) =>
      f.write_string(
        "imported function type mismatch. expected \{debug_func_type(expected)} but found \{debug_func_type(actual)}",
      )
    TableTypeMismatch(expected~, actual~) =>
      f.write_string(
        "imported table type mismatch. expected \{debug_table_type(expected)} but found \{debug_table_type(actual)}",
      )
    MemoryTypeMismatch(expected~, actual~) =>
      f.write_string(
        "imported memory type mismatch. expected \{debug_memory_type(expected)} but found \{debug_memory_type(actual)}",
      )
    ElementSegmentDoesNotFit(table~, table_index~, len~) =>
      f.write_string(
        "out of bounds table access: \{table} does not fit \{len} elements starting from offset \{table_index}",
      )
    UnexpectedStartFn(index~) =>
      f.write_string("found an unexpected start function with index \{index}")
    TooManyInstances =>
      f.write_string("tried to instantiate too many instances")
    TooManyTables => f.write_string("tried to instantiate too many tables")
    TooManyMemories =>
      f.write_string("tried to instantiate too many linear memories")
    FailedToInstantiateMemory(error) =>
      f.write_string("failed to instantiate memory: \{error}")
    FailedToInstantiateTable(error) =>
      f.write_string("failed to instantiate table: \{error}")
  }
}

///|
pub extend InstantiationError with Show::{to_string, output}

///|
/// Instantiates a new [`Instance`] from the given compiled [`Module`].
///
/// Uses the given `context` to store the instance data to.
/// The given `externals` are joined with the imports in the same order in which they occur.
///
/// # Errors
///
/// - If the given `externals` do not satisfy the required imports, e.g. if an externally
///   provided [`Func`] has a different function signature than required by the module import.
/// - If too many instances are instantiated.
/// - If the `start` function, if any, traps.
pub fn[T] Module::instantiate(
  self : Module,
  store : Store[T],
  externals : Array[Extern],
) -> Instance raise WasmiError {
  let handle = store.inner.alloc_instance()
  let builder = InstanceEntityBuilder::new(self)
  self.extract_imports(store, builder, externals)
  self.extract_functions(store, builder, handle)
  self.extract_tables(store, builder)
  self.extract_memories(store, builder)
  self.extract_globals(store, builder)
  self.extract_exports(builder)
  self.extract_start_fn(builder)
  self.initialize_table_elements(store, builder)
  self.initialize_memory_data(store, builder)
  Module::start(store, builder, handle)
  handle
}

///|
/// Initializes the [`Instance`] and runs the `start` function if any.
fn[T] Module::start(
  store : Store[T],
  builder : InstanceEntityBuilder,
  instance : Instance,
) -> Unit raise WasmiError {
  let opt_start_index = builder.get_start()
  store.inner.initialize_instance(instance, builder.finish())
  if opt_start_index is Some(start_index) {
    guard instance.get_func_by_index(store, start_index.0) is Some(start_func) else {
      abort(
        "encountered invalid start function after validation: \{start_index.0}",
      )
    }
    start_func.call(store, [], [])
  }
}

///|
/// Extract the Wasm imports from the module and zips them with the given external values.
///
/// This also stores imported references into the [`Instance`] under construction.
///
/// # Errors
///
/// - If too few or too many external values are given for the required module imports.
/// - If the zipped import and given external have mismatching types.
fn[T] Module::extract_imports(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
  externals : Array[Extern],
) -> Unit raise WasmiError {
  let imports = self.imports()
  if imports.length() != externals.length() {
    raise Instantiation(
      InvalidNumberOfImports(
        required=imports.length(),
        given=externals.length(),
      ),
    )
  }
  for i, imp in imports {
    let external = externals[i]
    match (imp.ty(), external) {
      (Func(expected_signature), Func(func)) => {
        let actual_signature = func.ty(store)
        if actual_signature != expected_signature {
          raise Instantiation(
            FuncTypeMismatch(
              actual=actual_signature,
              expected=expected_signature,
            ),
          )
        }
        builder.funcs.push(func)
      }
      (Table(required), Table(table)) => {
        let imported = store.inner.resolve_table(table).dynamic_ty()
        if !imported.is_subtype_of(required) {
          raise Instantiation(
            TableTypeMismatch(expected=required, actual=imported),
          )
        }
        builder.tables.push(table)
      }
      (Memory(required), Memory(memory)) => {
        let imported = store.inner.resolve_memory(memory).dynamic_ty()
        if !imported.is_subtype_of(required) {
          raise Instantiation(
            MemoryTypeMismatch(expected=required, actual=imported),
          )
        }
        builder.memories.push(memory)
      }
      (Global(required), Global(global)) => {
        let imported = global.ty(store)
        if imported != required {
          raise Instantiation(
            GlobalTypeMismatch(expected=required, actual=imported),
          )
        }
        builder.globals.push(global)
      }
      (expected_import, actual_extern_val) =>
        raise Instantiation(
          ImportsExternalsMismatch(
            expected=expected_import,
            actual=actual_extern_val,
          ),
        )
    }
  }
}

///|
/// Extracts the Wasm functions from the module and stores them into the [`Store`].
///
/// This also stores [`Func`] references into the [`Instance`] under construction.
fn[T] Module::extract_functions(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
  handle : Instance,
) -> Unit {
  let header = self.header
  let len_imported = header.imports.len_funcs
  for i in len_imported..<header.funcs.length() {
    let func_type = header.funcs[i]
    let func_body = header.engine_funcs.get_or_panic(i - len_imported)
    let wasm_func : WasmFuncEntity = {
      ty: func_type,
      body: func_body,
      instance: handle,
    }
    let func = store.inner.alloc_func(Wasm(wasm_func))
    builder.funcs.push(func)
  }
}

///|
/// Extracts the Wasm tables from the module and stores them into the [`Store`].
///
/// This also stores [`Table`] references into the [`Instance`] under construction.
fn[T] Module::extract_tables(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
) -> Unit raise WasmiError {
  let header = self.header
  for i in header.imports.len_tables..<header.tables.length() {
    let table_type = header.tables[i]
    let init = Val::default(table_type.element())
    let table = Table::new(store, table_type, init) catch {
      Table(error) => raise Instantiation(FailedToInstantiateTable(error))
      error => abort("unexpected error: \{error}")
    }
    builder.tables.push(table)
  }
}

///|
/// Extracts the Wasm linear memories from the module and stores them into the [`Store`].
///
/// This also stores [`Memory`] references into the [`Instance`] under construction.
fn[T] Module::extract_memories(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
) -> Unit raise WasmiError {
  let header = self.header
  for i in header.imports.len_memories..<header.memories.length() {
    let memory_type = header.memories[i]
    let memory = Memory::new(store, memory_type) catch {
      Memory(error) => raise Instantiation(FailedToInstantiateMemory(error))
      error => abort("unexpected error: \{error}")
    }
    builder.memories.push(memory)
  }
}

///|
/// Extracts the Wasm global variables from the module and stores them into the [`Store`].
///
/// This also stores [`Global`] references into the [`Instance`] under construction.
fn[T] Module::extract_globals(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
) -> Unit {
  let header = self.header
  let len_imported = header.imports.len_globals
  for i in len_imported..<header.globals.length() {
    let global_type = header.globals[i]
    let global_init = header.globals_init[i - len_imported]
    let value_type = global_type.content()
    let init_value = Module::eval_init_expr(store, builder, global_init)
    let mutability = global_type.mutability()
    let global = store.inner.alloc_global(
      @wasmi_core.Global::new(
        @wasmi_core.TypedVal::new(value_type, init_value),
        mutability,
      ),
    )
    builder.globals.push(global)
  }
}

///|
/// Evaluates the given initializer expression using the partially constructed [`Instance`].
fn[T] Module::eval_init_expr(
  store : Store[T],
  builder : InstanceEntityBuilder,
  init_expr : ConstExpr,
) -> @wasmi_core.UntypedVal {
  let value = init_expr.eval_with_context(
    fn(global_index) {
      store.inner
      .resolve_global(builder.get_global(global_index.reinterpret_as_int()))
      .get_untyped()
    },
    fn(func_index) {
      store.inner.funcref_to_untyped(
        Some(builder.get_func(func_index.reinterpret_as_int())),
      )
    },
  )
  match value {
    Some(v) => v
    None => abort("must evaluate to proper value")
  }
}

///|
/// Extracts the Wasm exports from the module and registers them into the [`Instance`].
fn Module::extract_exports(
  self : Module,
  builder : InstanceEntityBuilder,
) -> Unit {
  for field, idx in self.header.exports {
    let external : Extern = match idx {
      Func(func_index) => Func(builder.get_func(func_index.0))
      Table(table_index) => Table(builder.get_table(table_index.0))
      Memory(memory_index) => Memory(builder.get_memory(memory_index.0))
      Global(global_index) => Global(builder.get_global(global_index.0))
    }
    builder.push_export(field, external)
  }
}

///|
/// Extracts the optional start function for the build instance.
fn Module::extract_start_fn(
  self : Module,
  builder : InstanceEntityBuilder,
) -> Unit {
  if self.header.start is Some(start_fn) {
    builder.set_start(start_fn)
  }
}

///|
/// Initializes the [`Instance`] tables with the Wasm element segments of the [`Module`].
fn[T] Module::initialize_table_elements(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
) -> Unit raise WasmiError {
  for segment in self.header.element_segments {
    let items : Array[@wasmi_core.UntypedVal] = match segment.kind() {
      Passive | Active(..) =>
        segment
        .items()
        .map(fn(const_expr) {
          match
            const_expr.eval_with_context(
              fn(index) {
                store.inner
                .resolve_global(builder.get_global(index.reinterpret_as_int()))
                .get_untyped()
              },
              fn(index) {
                store.inner.funcref_to_untyped(
                  Some(builder.get_func(index.reinterpret_as_int())),
                )
              },
            ) {
            Some(v) => v
            None =>
              abort("unexpected failed initialization of constant expression")
          }
        })
      Declared => []
    }
    let element = store.inner.alloc_element_segment(
      @wasmi_core.ElementSegment::new(segment.ty(), items[:]),
    )
    if segment.kind() is Active(table_index~, offset~) {
      let dst_index = Module::eval_init_expr(store, builder, offset).to_bits64()
      let table = builder.get_table(table_index.0)
      let len_table = store.inner.resolve_table(table).size()
      let elem = store.inner.resolve_element(element)
      let len_items = elem.size()
      let max_index = dst_index + len_items.to_uint64()
      if max_index < dst_index || max_index > len_table {
        raise Instantiation(
          ElementSegmentDoesNotFit(table~, table_index=dst_index, len=len_items),
        )
      }
      store.inner
      .resolve_table(table)
      .init(elem.as_ref(), dst_index, 0, len_items, None) catch {
        e => raise Table(e)
      }
      elem.drop_items()
    }
    builder.elem_segments.push(element)
  }
}

///|
/// Initializes the [`Instance`] linear memories with the Wasm data segments of the [`Module`].
fn[T] Module::initialize_memory_data(
  self : Module,
  store : Store[T],
  builder : InstanceEntityBuilder,
) -> Unit raise WasmiError {
  for segment in self.data_segments {
    let segment = match segment {
      Active({ memory_index, offset, bytes, }) => {
        let memory = builder.get_memory(memory_index.0)
        let offset = Module::eval_init_expr(store, builder, offset).to_bits64()
        store.inner.resolve_memory(memory).write(offset, bytes[:]) catch {
          e => raise Memory(e)
        }
        store.inner.alloc_data_segment({ bytes: None, })
      }
      Passive(bytes) => store.inner.alloc_data_segment({ bytes: Some(bytes), })
    }
    builder.data_segments.push(segment)
  }
}
