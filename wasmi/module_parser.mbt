// Port of wasmi 1.0.9 `module/parser/{mod,buffered}.rs` (buffered parsing
// with validation, which is what `Module::new` uses).

///|
/// Context used to construct a WebAssembly module from a stream of bytes.
priv struct ModuleParser {
  /// The engine used for translation.
  engine : Engine
  /// The Wasm validator used throughout stream parsing.
  mut validator : @wasmparser.Validator?
  /// The underlying Wasm parser.
  parser : @wasmparser.Parser
  /// The number of compiled or processed functions.
  mut engine_funcs : Int
}

///|
/// Creates a new [`ModuleParser`] for the given [`Engine`].
fn ModuleParser::new(engine : Engine) -> ModuleParser {
  let parser = @wasmparser.Parser::new(0)
  parser.set_features(engine.config().wasm_features())
  { engine, validator: None, parser, engine_funcs: 0, }
}

///|
/// Creates a new Wasm [`Module`] from the given Wasm bytecode buffer.
///
/// # Note
///
/// This parses, validates and translates the buffered Wasm bytecode.
///
/// # Errors
///
/// - If the Wasm bytecode is malformed or fails to validate.
/// - If the Wasm bytecode violates restrictions
///   set in the [`Config`] used by the `engine`.
/// - If Wasmi cannot translate the Wasm bytecode.
pub fn Module::new(engine : Engine, wasm : Bytes) -> Module raise WasmiError {
  ModuleParser::new(engine).parse_buffered(wasm[:])
}

///|
/// Raises a wasmparser error as a wasmi [`WasmiError`].
fn[R] wasm_err(
  f : () -> R raise @wasmparser.BinaryReaderError,
) -> R raise WasmiError {
  f() catch {
    e => raise Wasm(e)
  }
}

///|
/// Returns the [`Validator`] of the parser.
fn ModuleParser::validator(self : ModuleParser) -> @wasmparser.Validator {
  match self.validator {
    Some(v) => v
    None => abort("missing validator")
  }
}

///|
/// Processes the end of the Wasm binary.
fn ModuleParser::process_end(
  self : ModuleParser,
  offset : Int,
) -> Unit raise WasmiError {
  if self.validator is Some(validator) {
    // This only checks if the number of code section entries and data segments match
    // their expected numbers thus we must avoid this check in header-only mode because
    // otherwise we will receive errors for unmatched data section entries.
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.end(offset) |> ignore
    })
  }
}

///|
/// Processes the Wasm type section.
///
/// # Note
///
/// This extracts all function types into the [`Module`] under construction.
fn ModuleParser::process_types(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.RecGroup],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.type_section(section)
    })
  }
  let limits = self.engine.config().get_enforced_limits()
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(rec_group) {
    let ty = rec_group.into_types()[0]
    let func_ty = ty.unwrap_func()
    if limits.max_params is Some(limit) {
      if func_ty.params().length() > limit {
        raise Limits(TooManyParameters(limit~))
      }
    }
    if limits.max_results is Some(limit) {
      if func_ty.results().length() > limit {
        raise Limits(TooManyResults(limit~))
      }
    }
    let dedup = self.engine.alloc_func_type(func_type_from_wasmparser(func_ty))
    header.func_types.push(dedup)
  }
}

///|
/// Processes the Wasm import section.
///
/// # Note
///
/// This extracts all imports into the [`Module`] under construction.
fn ModuleParser::process_imports(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.Import],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.import_section(section)
    })
  }
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(imp) {
    let name = ImportName::new(imp.module_, imp.name)
    match imp.ty {
      Func(func_type_idx) => {
        header.imports_funcs.push(name)
        let func_type = header.func_types[func_type_idx.reinterpret_as_int()]
        header.funcs.push(func_type)
      }
      Table(table_type) => {
        header.imports_tables.push(name)
        header.tables.push(table_type_from_wasmparser(table_type))
      }
      Memory(memory_type) => {
        header.imports_memories.push(name)
        header.memories.push(memory_type_from_wasmparser(memory_type))
      }
      Global(global_type) => {
        header.imports_globals.push(name)
        header.globals.push(global_type_from_wasmparser(global_type))
      }
      Tag(_) =>
        abort("wasmi does not support the `exception-handling` Wasm proposal")
    }
  }
}

///|
/// Process module function declarations.
///
/// # Note
///
/// This extracts all function declarations into the [`Module`] under construction.
fn ModuleParser::process_functions(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[UInt],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_functions is Some(limit) {
    if section.count() > limit {
      raise Limits(TooManyFunctions(limit~))
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.function_section(section)
    })
  }
  header.engine_funcs = self.engine.alloc_funcs(
    section.count().reinterpret_as_int(),
  )
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(func_type_idx) {
    let func_type = header.func_types[func_type_idx.reinterpret_as_int()]
    header.funcs.push(func_type)
  }
}

///|
/// Process module table declarations.
///
/// # Note
///
/// This extracts all table declarations into the [`Module`] under construction.
fn ModuleParser::process_tables(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.Table],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_tables is Some(limit) {
    if section.count() > limit {
      raise Limits(TooManyTables(limit~))
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.table_section(section)
    })
  }
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(table) {
    // Upstream: `assert!(matches!(table.init,
    // wasmparser::TableInit::RefNull))`.
    guard! table.init is RefNull
    header.tables.push(table_type_from_wasmparser(table.ty))
  }
}

///|
/// Process module linear memory declarations.
///
/// # Note
///
/// This extracts all linear memory declarations into the [`Module`] under construction.
fn ModuleParser::process_memories(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.MemoryType],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_memories is Some(limit) {
    if section.count() > limit {
      raise Limits(TooManyMemories(limit~))
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.memory_section(section)
    })
  }
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(memory) {
    header.memories.push(memory_type_from_wasmparser(memory))
  }
}

///|
/// Process module global variable declarations.
///
/// # Note
///
/// This extracts all global variable declarations into the [`Module`] under construction.
fn ModuleParser::process_globals(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.Global],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_globals is Some(limit) {
    if section.count() > limit {
      raise Limits(TooManyGlobals(limit~))
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.global_section(section)
    })
  }
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(global) {
    header.globals.push(global_type_from_wasmparser(global.ty))
    header.globals_init.push(ConstExpr::new(global.init_expr))
  }
}

///|
/// Process module export declarations.
///
/// # Note
///
/// This extracts all export declarations into the [`Module`] under construction.
fn ModuleParser::process_exports(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.Export],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.export_section(section)
    })
  }
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(export_) {
    let idx = ExternIdx::new(export_.kind, export_.index)
    header.exports.set(export_.name, idx)
  }
}

///|
/// Process module start section.
///
/// # Note
///
/// This sets the start function for the [`Module`] under construction.
fn ModuleParser::process_start(
  self : ModuleParser,
  func : UInt,
  range : @wasmparser.Range,
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.start_section(func, range)
    })
  }
  if header.start is Some(old_start) {
    abort("encountered multiple start functions: \{old_start.0}, \{func}")
  }
  header.start = Some(FuncIdx(func.reinterpret_as_int()))
}

///|
/// Process module table element segments.
///
/// # Note
///
/// This extracts all table element segments into the [`Module`] under construction.
fn ModuleParser::process_element(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.Element],
  header : ModuleHeaderBuilder,
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_element_segments
    is Some(limit) {
    if section.count() > limit {
      raise Limits(TooManyElementSegments(limit~))
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.element_section(section)
    })
  }
  let segments = []
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(segment) {
    segments.push(ModuleElementSegment::from_wasmparser(segment))
  }
  header.element_segments = segments
}

///|
/// Process module data count section.
fn ModuleParser::process_data_count(
  self : ModuleParser,
  count : UInt,
  range : @wasmparser.Range,
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_data_segments is Some(limit) {
    if count > limit {
      raise Limits(TooManyDataSegments(limit~))
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.data_count_section(count, range)
    })
  }
}

///|
/// Process module linear memory data segments.
fn ModuleParser::process_data(
  self : ModuleParser,
  section : @wasmparser.SectionLimited[@wasmparser.Data],
  data_segments : Array[ModuleDataSegment],
) -> Unit raise WasmiError {
  if self.engine.config().get_enforced_limits().max_data_segments is Some(limit) {
    if section.count() > limit {
      raise Limits(TooManyDataSegments(limit~))
    }
  }
  if self.validator is Some(validator) {
    // Note: data section does not belong to the Wasm module header.
    //
    // Also benchmarks show that validation of the data section can be very costly.
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.data_section(section)
    })
  }
  let iter = section.into_iter()
  while wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          iter.next()
        })
        is Some(segment) {
    data_segments.push(ModuleDataSegment::from_wasmparser(segment))
  }
}

///|
/// Process module code section start.
fn ModuleParser::process_code_start(
  self : ModuleParser,
  count : UInt,
  range : @wasmparser.Range,
  size : UInt,
) -> Unit raise WasmiError {
  let enforced_limits = self.engine.config().get_enforced_limits()
  if enforced_limits.max_functions is Some(limit) {
    if count > limit {
      raise Limits(TooManyFunctions(limit~))
    }
  }
  if enforced_limits.min_avg_bytes_per_function is Some(limit) {
    if size >= limit.req_funcs_bytes {
      let limit = limit.min_avg_bytes_per_function
      let avg = size / count
      if avg < limit {
        raise Limits(MinAvgBytesPerFunction(limit~, avg~))
      }
    }
  }
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.code_section_start(count, range)
    })
  }
}

///|
/// Returns the next `FuncIdx` for processing of its function body.
fn ModuleParser::next_func(
  self : ModuleParser,
  header : ModuleHeader,
) -> (FuncIdx, EngineFunc) {
  let index = self.engine_funcs
  let engine_func = header.engine_funcs.get_or_panic(index)
  self.engine_funcs += 1
  // We have to adjust the initial func reference to the first
  // internal function before we process any of the internal functions.
  let len_func_imports = header.imports.len_funcs
  let func_idx = FuncIdx(index + len_func_imports)
  (func_idx, engine_func)
}

///|
/// Process a single module code section entry.
///
/// # Note
///
/// This contains the local variables and Wasm instructions of
/// a single function body.
/// This procedure is translating the Wasm bytecode into Wasmi bytecode.
fn ModuleParser::process_code_entry(
  self : ModuleParser,
  func_body : @wasmparser.FunctionBody,
  bytes : BytesView,
  header : ModuleHeader,
) -> Unit raise WasmiError {
  let (func, engine_func) = self.next_func(header)
  let offset = func_body.get_binary_reader().original_position()
  let func_to_validate = match self.validator {
    Some(validator) =>
      Some(
        wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          validator.code_section_entry(func_body)
        }),
      )
    None => None
  }
  self.engine.translate_func(
    func, engine_func, offset, bytes, header, func_to_validate,
  )
}

///|
/// Process an unexpected, unsupported or malformed Wasm module section payload.
fn ModuleParser::process_invalid_payload(
  self : ModuleParser,
  payload : @wasmparser.Payload,
) -> Unit raise WasmiError {
  if self.validator is Some(validator) {
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      validator.payload(payload) |> ignore
    })
  }
  abort("encountered unsupported, unexpected or malformed Wasm payload")
}

///|
/// Fetch next Wasm module payload and adust the `buffer`.
///
/// # Errors
///
/// If the parsed Wasm is malformed.
fn ModuleParser::next_payload(
  self : ModuleParser,
  buffer : BytesView,
) -> (Int, @wasmparser.Payload) raise WasmiError {
  match
    wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
      self.parser.parse(buffer, true)
    }) {
    Parsed(consumed~, payload~) => (consumed, payload)
    NeedMoreData(_) =>
      // This is not possible since `eof` is always true.
      abort("unreachable")
  }
}

///|
/// Starts parsing and validating the Wasm bytecode stream.
///
/// Returns the compiled and validated Wasm [`Module`] upon success.
///
/// # Errors
///
/// If the Wasm bytecode stream fails to validate.
fn ModuleParser::parse_buffered(
  self : ModuleParser,
  buffer : BytesView,
) -> Module raise WasmiError {
  let features = self.engine.config().wasm_features()
  self.validator = Some(@wasmparser.Validator::new_with_features(features))
  let mut buffer = buffer
  let custom_sections = []
  // Parse the Wasm module header.
  //
  // - The Wasm module header is the set of all sections that appear before
  //   the Wasm code section.
  // - We separate parsing of the Wasm module header since the information of
  //   the Wasm module header is required for translating the Wasm code section.
  let header_builder = ModuleHeaderBuilder::new(self.engine)
  while true {
    let (consumed, payload) = self.next_payload(buffer)
    match payload {
      Version(num~, encoding~, range~) =>
        wasm_err(fn() raise @moonbitlang/typst/wasmparser.BinaryReaderError {
          self.validator().version(num, encoding, range)
        })
      TypeSection(section) => self.process_types(section, header_builder)
      ImportSection(section) => self.process_imports(section, header_builder)
      FunctionSection(section) =>
        self.process_functions(section, header_builder)
      TableSection(section) => self.process_tables(section, header_builder)
      MemorySection(section) => self.process_memories(section, header_builder)
      GlobalSection(section) => self.process_globals(section, header_builder)
      ExportSection(section) => self.process_exports(section, header_builder)
      StartSection(func~, range~) =>
        self.process_start(func, range, header_builder)
      ElementSection(section) => self.process_element(section, header_builder)
      DataCountSection(count~, range~) => self.process_data_count(count, range)
      CodeSectionStart(count~, range~, size~) => {
        self.process_code_start(count, range, size)
        buffer = buffer[consumed:]
        break
      }
      DataSection(_) => break
      End(_) => break
      CustomSection(reader) =>
        if !self.engine.config().get_ignore_custom_sections() {
          custom_sections.push((reader.name(), reader.data().to_owned()))
        }
      unexpected => self.process_invalid_payload(unexpected)
    }
    buffer = buffer[consumed:]
  }
  let header = header_builder.finish()
  // Parse the Wasm code section entries.
  //
  // We separate parsing of the Wasm code section since most of a Wasm module
  // is made up of code section entries which we can parse and validate more efficiently
  // by serving them with a specialized routine.
  while true {
    let (consumed, payload) = self.next_payload(buffer)
    match payload {
      CodeSectionEntry(func_body) => {
        // Note: Unfortunately the `wasmparser` crate is missing an API
        //       to return the byte slice for the respective code section
        //       entry payload. Please remove this work around as soon as
        //       such an API becomes available.
        buffer = buffer[consumed:]
        let bytes = func_body.as_bytes()
        self.process_code_entry(func_body, bytes, header)
      }
      _ => break
    }
  }
  // Parse the Wasm data section and finalize parsing.
  //
  // We separate parsing of the Wasm data section since it is the only Wasm
  // section that comes after the Wasm code section that we have to separate
  // out for technical reasons.
  let data_segments = []
  while true {
    let (consumed, payload) = self.next_payload(buffer)
    match payload {
      DataSection(section) => self.process_data(section, data_segments)
      End(offset) => {
        self.process_end(offset)
        break
      }
      CustomSection(reader) =>
        if !self.engine.config().get_ignore_custom_sections() {
          custom_sections.push((reader.name(), reader.data().to_owned()))
        }
      invalid => self.process_invalid_payload(invalid)
    }
    buffer = buffer[consumed:]
  }
  { engine: self.engine, header, data_segments, custom_sections, }
}
