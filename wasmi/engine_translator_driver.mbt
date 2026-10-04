// Port of wasmi 1.0.9 `engine/translator/driver.rs` and the validating part
// of `engine/translator/mod.rs` (`ValidatingFuncTranslator` driven with a
// `LazyFuncTranslator`, i.e. validation only).

///|
/// Translates Wasm bytecode into Wasmi bytecode for a single Wasm function.
pub(all) struct FuncTranslationDriver {
  /// The function body that shall be translated.
  priv func_body : @wasmparser.FunctionBody
}

///|
/// Creates a new Wasm to Wasmi bytecode function translator.
pub fn FuncTranslationDriver::new(
  offset : Int,
  bytes : BytesView,
  config : Config,
) -> FuncTranslationDriver {
  let features = config.wasm_features()
  let reader = @wasmparser.BinaryReader::new_features(bytes, offset, features)
  let func_body = @wasmparser.FunctionBody::new(reader)
  { func_body, }
}

///|
/// Starts translation of the Wasm stream into Wasmi bytecode.
pub fn FuncTranslationDriver::translate(
  self : FuncTranslationDriver,
  translator : FuncTranslator,
) -> CompiledFuncEntity raise WasmiError {
  // Translates local variables and parameters of the Wasm function.
  let reader = self.func_body.get_locals_reader() catch {
    e => raise WasmiError::from_wasm(e)
  }
  let len_locals = reader.get_count()
  for _ in 0U..<len_locals {
    let (amount, value_type) = reader.read() catch {
      e => raise WasmiError::from_wasm(e)
    }
    translator.translate_locals(amount, value_type)
  }
  // Translates the Wasm operators of the Wasm function.
  let reader = self.func_body.get_operators_reader() catch {
    e => raise WasmiError::from_wasm(e)
  }
  while !reader.eof() {
    let op = reader.read() catch { e => raise WasmiError::from_wasm(e) }
    translator.visit_operator(op)
  }
  reader.ensure_end() catch {
    e => raise WasmiError::from_wasm(e)
  }
  translator.finish()
}

///|
/// Validates the Wasm function body `bytes` (at `offset` in the Wasm binary)
/// like upstream's `ValidatingFuncTranslator` wrapping a `LazyFuncTranslator`
/// driven by the `FuncTranslationDriver`.
pub fn validate_func_body(
  func_to_validate : @wasmparser.FuncToValidate,
  offset : Int,
  bytes : BytesView,
  config : Config,
) -> Unit raise WasmiError {
  let validator = func_to_validate.into_validator(
    @wasmparser.FuncValidatorAllocations::default(),
  )
  let features = config.wasm_features()
  let reader = @wasmparser.BinaryReader::new_features(bytes, offset, features)
  let func_body = @wasmparser.FunctionBody::new(reader)
  try {
    let reader = func_body.get_locals_reader()
    let len_locals = reader.get_count()
    for _ in 0U..<len_locals {
      let offset = reader.original_position()
      let (amount, value_type) = reader.read()
      validator.define_locals(offset, amount, value_type)
    }
    let reader = func_body.get_operators_reader()
    while !reader.eof() {
      let pos = reader.original_position()
      let op = reader.read()
      validator.op(pos, op)
    }
    reader.ensure_end()
    validator.finish(reader.original_position())
  } catch {
    e => raise WasmiError::from_wasm(e)
  }
}
