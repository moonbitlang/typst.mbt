// Port of wasmparser 0.228.0 `src/validator/func.rs`.

///|
/// Resources necessary to perform validation of a function.
///
/// This structure is created by
/// [`Validator::code_section_entry`](crate::Validator::code_section_entry) and
/// is created per-function in a WebAssembly module. This structure is suitable
/// for sending to other threads while the original
/// [`Validator`](crate::Validator) continues processing other functions.
pub struct FuncToValidate {
  /// Reusable, heap allocated resources to drive the Wasm validation.
  resources : ValidatorResources
  /// The core Wasm function index being validated.
  index : UInt
  /// The core Wasm type index of the function being validated,
  /// defining the results and parameters to the function.
  ty : UInt
  /// The Wasm features enabled to validate the function.
  features : WasmFeatures
}

///|
/// Converts this [`FuncToValidate`] into a [`FuncValidator`] using the
/// `allocs` provided.
///
/// This method, in conjunction with [`FuncValidator::into_allocations`],
/// provides a means to reuse allocations across validation of each
/// individual function. Note that it is also sufficient to call this
/// method with `Default::default()` if no prior allocations are
/// available.
///
/// # Panics
///
/// If a `FuncToValidate` was created with an invalid `ty` index then this
/// function will panic.
pub fn FuncToValidate::into_validator(
  self : FuncToValidate,
  allocs : FuncValidatorAllocations,
) -> FuncValidator {
  let validator = OperatorValidator::new_func(
    self.ty,
    0,
    self.features,
    self.resources,
    allocs.0,
  ) catch {
    _ => abort("unwrap")
  }
  {
    validator,
    resources: self.resources,
    index: self.index,
    visitor: validator.with_resources(self.resources, 0),
  }
}

///|
/// The features of the function.
pub fn FuncToValidate::features(self : FuncToValidate) -> WasmFeatures {
  self.features
}

///|
/// The resources of the function's module.
pub fn FuncToValidate::resources(self : FuncToValidate) -> ValidatorResources {
  self.resources
}

///|
/// The core Wasm function index being validated.
pub fn FuncToValidate::index(self : FuncToValidate) -> UInt {
  self.index
}

///|
/// The core Wasm type index of the function being validated.
pub fn FuncToValidate::ty(self : FuncToValidate) -> UInt {
  self.ty
}

///|
/// Validation context for a WebAssembly function.
///
/// This is a finalized validator which is ready to process a [`FunctionBody`].
/// This is created from the [`FuncToValidate::into_validator`] method.
pub struct FuncValidator {
  priv validator : OperatorValidator
  priv resources : ValidatorResources
  priv index : UInt
  // The proposal-checking visitor over `validator` (reused for every
  // operator; upstream creates a temporary one per operator).
  priv visitor : WasmProposalValidator
}

///|
/// External handle to the internal allocations used during function
/// validation.
///
/// This is created with either the `Default` implementation or with
/// [`FuncValidator::into_allocations`]. It is then passed as an argument to
/// [`FuncToValidate::into_validator`] to provide a means of reusing
/// allocations between each function.
pub struct FuncValidatorAllocations(OperatorValidatorAllocations)

///|
pub fn FuncValidatorAllocations::default() -> FuncValidatorAllocations {
  FuncValidatorAllocations(OperatorValidatorAllocations::default())
}

///|
/// Convenience function to validate an entire function's body.
///
/// You may not end up using this in final implementations because you'll
/// often want to interleave validation with parsing.
pub fn FuncValidator::validate(
  self : FuncValidator,
  body : FunctionBody,
) -> Unit raise BinaryReaderError {
  let reader = body.get_binary_reader()
  self.read_locals(reader)
  reader.set_features(self.validator.features)
  while !reader.eof() {
    let pos = reader.original_position()
    let op = reader.read_operator()
    self.op(pos, op)
  }
  self.finish(reader.original_position())
}

///|
/// Reads the local definitions from the given `BinaryReader`, often sourced
/// from a `FunctionBody`.
///
/// This function will automatically advance the `BinaryReader` forward,
/// leaving reading operators up to the caller afterwards.
pub fn FuncValidator::read_locals(
  self : FuncValidator,
  reader : BinaryReader,
) -> Unit raise BinaryReaderError {
  let n = reader.read_var_u32()
  for _ in 0U..<n {
    let offset = reader.original_position()
    let cnt = reader.read_var_u32()
    let ty = ValType::from_reader(reader)
    self.define_locals(offset, cnt, ty)
  }
}

///|
/// Defines locals into this validator.
///
/// This should be used if the application is already reading local
/// definitions and there's no need to re-parse the function again.
pub fn FuncValidator::define_locals(
  self : FuncValidator,
  offset : Int,
  count : UInt,
  ty : ValType,
) -> Unit raise BinaryReaderError {
  self.validator.define_locals(offset, count, ty, self.resources)
}

///|
/// Validates the next operator in a function.
///
/// This functions is expected to be called once-per-operator in a
/// WebAssembly function. Each operator's offset in the original binary and
/// the operator itself are passed to this function to provide more useful
/// error messages.
pub fn FuncValidator::op(
  self : FuncValidator,
  offset : Int,
  operator : Operator,
) -> Unit raise BinaryReaderError {
  self.visitor.0.offset = offset
  self.visitor.visit_operator(operator)
}

///|
/// Get the operator visitor for the next operator in the function.
///
/// The returned visitor is intended to visit just one instruction at the `offset`.
pub fn FuncValidator::visitor(
  self : FuncValidator,
  offset : Int,
) -> WasmProposalValidator {
  self.visitor.0.offset = offset
  self.visitor
}

///|
/// Same as [`FuncValidator::visitor`] (the visitor validates SIMD
/// operators too).
pub fn FuncValidator::simd_visitor(
  self : FuncValidator,
  offset : Int,
) -> WasmProposalValidator {
  self.visitor(offset)
}

///|
/// Function that must be called after the last opcode has been processed.
///
/// This will validate that the function was properly terminated with the
/// `end` opcode. If this function is not called then the function will not
/// be properly validated.
///
/// The `offset` provided to this function will be used as a position for an
/// error if validation fails.
pub fn FuncValidator::finish(
  self : FuncValidator,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.validator.finish(offset)
}

///|
/// Returns the Wasm features enabled for this validator.
pub fn FuncValidator::features(self : FuncValidator) -> WasmFeatures {
  self.validator.features
}

///|
/// Returns the underlying module resources that this validator is using.
pub fn FuncValidator::resources(self : FuncValidator) -> ValidatorResources {
  self.resources
}

///|
/// The index of the function within the module's function index space that
/// is being validated.
pub fn FuncValidator::index(self : FuncValidator) -> UInt {
  self.index
}

///|
/// Returns the number of defined local variables in the function.
pub fn FuncValidator::len_locals(self : FuncValidator) -> UInt {
  self.validator.locals.len_locals()
}

///|
/// Returns the type of the local variable at the given `index` if any.
pub fn FuncValidator::get_local_type(
  self : FuncValidator,
  index : UInt,
) -> ValType? {
  self.validator.locals.get(index)
}

///|
/// Get the current height of the operand stack.
///
/// This returns the height of the whole operand stack for this function,
/// not just for the current control frame.
pub fn FuncValidator::operand_stack_height(self : FuncValidator) -> UInt {
  self.validator.operand_stack_height().reinterpret_as_uint()
}

///|
/// Returns the optional value type of the value operand at the given
/// `depth` from the top of the operand stack.
///
/// - Returns `None` if the `depth` is out of bounds.
/// - Returns `Some(None)` if there is a value with unknown type
/// at the given `depth`.
///
/// # Note
///
/// A `depth` of 0 will refer to the last operand on the stack.
pub fn FuncValidator::get_operand_type(
  self : FuncValidator,
  depth : Int,
) -> ValType?? {
  self.validator.peek_operand_at(depth)
}

///|
/// Get the current height of the control frame stack.
pub fn FuncValidator::control_stack_height(self : FuncValidator) -> UInt {
  self.validator.control_stack_height().reinterpret_as_uint()
}

///|
/// Returns access to the control frame at the given `depth` from the
/// top of the control frame stack (0 is the innermost frame).
pub fn FuncValidator::get_control_frame(
  self : FuncValidator,
  depth : Int,
) -> Frame? {
  self.validator.get_frame(depth)
}

///|
/// Consumes this validator and returns the underlying allocations that
/// were used during the validation process.
///
/// The returned value here can be paired with
/// [`FuncToValidate::into_validator`] to reuse the allocations already
/// created by this validator.
pub fn FuncValidator::into_allocations(
  self : FuncValidator,
) -> FuncValidatorAllocations {
  FuncValidatorAllocations(self.validator.into_allocations())
}
