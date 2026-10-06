// Port of wasmi 1.0.9 `engine/translator/error.rs`.

///|
/// An error that may occur upon parsing, validating and translating Wasm.
pub(all) enum TranslationError {
  /// WasmiError that indicates that a used feature is not supported.
  UnsupportedBlockType(@wasmparser.BlockType)
  /// WasmiError that indicates that a used feature is not supported.
  UnsupportedValueType(@wasmparser.ValType)
  /// When using too many branch table targets.
  BranchTableTargetsOutOfBounds
  /// Branching offset out of bounds.
  BranchOffsetOutOfBounds
  /// Fuel required for a block is out of bounds.
  BlockFuelOutOfBounds
  /// Tried to allocate more registers than possible.
  AllocatedTooManySlots
  /// Tried to use an out of bounds register index.
  SlotOutOfBounds
  /// Pushed too many values on the emulated value stack during translation.
  EmulatedValueStackOverflow
  /// Tried to allocate too many or large provider slices.
  ProviderSliceOverflow
  /// Tried to allocate too many function local constant values.
  TooManyFuncLocalConstValues
  /// Tried to define a function with too many function results.
  TooManyFunctionResults
  /// Tried to define a function with too many function parameters.
  TooManyFunctionParams
  /// Tried to define a function with too many local variables.
  TooManyLocalVariables
  /// The function failed to compiled lazily.
  LazyCompilationFailed
}

///|
pub impl Show for TranslationError with fn output(self, f) {
  match self {
    UnsupportedBlockType(error) =>
      f.write_string(
        "encountered unsupported Wasm block type: \{debug_block_type(error)}",
      )
    UnsupportedValueType(error) =>
      f.write_string(
        "encountered unsupported Wasm value type: \{debug_wasmparser_val_type(error)}",
      )
    BranchTableTargetsOutOfBounds =>
      f.write_string(
        "branch table targets are out of bounds for wasmi bytecode",
      )
    BranchOffsetOutOfBounds =>
      f.write_string("branching offset is out of bounds for wasmi bytecode")
    BlockFuelOutOfBounds =>
      f.write_string(
        "fuel required to execute a block is out of bounds for wasmi bytecode",
      )
    AllocatedTooManySlots =>
      f.write_string(
        "translation requires more registers for a function than available",
      )
    SlotOutOfBounds =>
      f.write_string("tried to access out of bounds register index")
    EmulatedValueStackOverflow =>
      f.write_string("function requires value stack with out of bounds depth")
    ProviderSliceOverflow =>
      f.write_string("tried to allocate too many or too large provider slices")
    TooManyFuncLocalConstValues =>
      f.write_string(
        "tried to allocate too many function local constant values",
      )
    TooManyFunctionResults =>
      f.write_string("encountered function with too many function results")
    TooManyFunctionParams =>
      f.write_string("encountered function with too many function parameters")
    TooManyLocalVariables =>
      f.write_string("encountered function with too many local variables")
    LazyCompilationFailed =>
      f.write_string(
        "lazy function compilation encountered a Wasm validation or translation error",
      )
  }
}

///|
pub extend TranslationError with Show::{to_string, output}

///|
/// Rust `Debug` of a wasmparser value type (for unsupported types only).
fn debug_wasmparser_val_type(ty : @wasmparser.ValType) -> String {
  match ty {
    I32 => "I32"
    I64 => "I64"
    F32 => "F32"
    F64 => "F64"
    V128 => "V128"
    Ref(_) => "Ref(..)"
  }
}

///|
/// Rust `Debug` of a wasmparser block type (for unsupported types only).
fn debug_block_type(ty : @wasmparser.BlockType) -> String {
  match ty {
    Empty => "Empty"
    Type(ty) => "Type(\{debug_wasmparser_val_type(ty)})"
    FuncType(index) => "FuncType(\{index})"
  }
}
