// Port of `wasmi_core/src/func_type.rs`.
//
// Upstream stores up to 21 types inline (`FuncTypeInner::Inline`) and larger
// signatures on the heap (`FuncTypeInner::Big`); this is a memory layout
// optimization only, so here every [`FuncType`] stores its parameter types
// followed by its result types in one array.

///|
/// Errors that can occur upon type checking function signatures.
pub(all) suberror FuncTypeError {
  /// Too many function parameters.
  TooManyFunctionParams
  /// Too many function results.
  TooManyFunctionResults
} derive(Debug)

///|
pub impl Show for FuncTypeError with fn output(self, logger) {
  match self {
    TooManyFunctionParams =>
      logger.write_string("encountered a function with too many parameters")
    TooManyFunctionResults =>
      logger.write_string("encountered a function with too many results")
  }
}

///|
/// A function type representing a function's parameter and result types.
///
/// # Note
///
/// Can be cloned cheaply.
pub struct FuncType {
  /// The number of parameters.
  len_params : Int
  /// Combined parameter and result types.
  params_results : FixedArray[ValType]
} derive(Eq, Hash)

///|
/// The maximum number of parameter types allowed of a [`FuncType`].
let max_len_params : Int = 1_000

///|
/// The maximum number of result types allowed of a [`FuncType`].
let max_len_results : Int = 1_000

///|
/// Creates a new [`FuncType`].
///
/// # Errors
///
/// If an out of bounds number of parameters or results are given.
pub fn FuncType::new(
  params : ArrayView[ValType],
  results : ArrayView[ValType],
) -> FuncType raise FuncTypeError {
  let len_params = params.length()
  let len_results = results.length()
  if len_params > max_len_params {
    raise TooManyFunctionParams
  }
  if len_results > max_len_results {
    raise TooManyFunctionResults
  }
  let params_results = FixedArray::makei(len_params + len_results, i => {
    if i < len_params {
      params[i]
    } else {
      results[i - len_params]
    }
  })
  { len_params, params_results, }
}

///|
/// Returns the parameter types of the function type.
pub fn FuncType::params(self : FuncType) -> ArrayView[ValType] {
  self.params_results[:self.len_params]
}

///|
/// Returns the result types of the function type.
pub fn FuncType::results(self : FuncType) -> ArrayView[ValType] {
  self.params_results[self.len_params:]
}

///|
/// Returns the number of parameter types of the function type.
pub fn FuncType::len_params(self : FuncType) -> Int {
  self.len_params
}

///|
/// Returns the number of result types of the function type.
pub fn FuncType::len_results(self : FuncType) -> Int {
  self.params_results.length() - self.len_params
}

///|
/// Returns the pair of parameter and result types of the function type.
pub fn FuncType::params_results(
  self : FuncType,
) -> (ArrayView[ValType], ArrayView[ValType]) {
  (self.params(), self.results())
}

///|
/// Rust's `Debug` of [FuncType]: `FuncType { params: [..], results: [..] }`.
pub impl Show for FuncType with fn output(self, logger) {
  let list = (tys : ArrayView[ValType]) => {
    let parts = tys.iter().map(ty => ty.to_string()).collect()
    "[" + parts.join(", ") + "]"
  }
  logger.write_string(
    "FuncType { params: \{list(self.params())}, results: \{list(self.results())} }",
  )
}
