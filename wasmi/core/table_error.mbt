// Port of `wasmi_core/src/table/error.rs`.

///|
/// Errors that may occur upon operating with table entities.
pub(all) suberror TableError {
  /// Tried to allocate more virtual memory than technically possible.
  OutOfSystemMemory
  /// The minimum size of the table type overflows the system index type.
  MinimumSizeOverflow
  /// The maximum size of the table type overflows the system index type.
  MaximumSizeOverflow
  /// If a resource limiter denied allocation or growth of a linear memory.
  ResourceLimiterDeniedAllocation
  /// Occurs when growing a table out of its set bounds.
  GrowOutOfBounds
  /// Occurs when initializing a table out of its set bounds.
  InitOutOfBounds
  /// Occurs when filling a table out of its set bounds.
  FillOutOfBounds
  /// Occurs when accessing the table out of bounds.
  SetOutOfBounds
  /// Occur when coping elements of tables out of bounds.
  CopyOutOfBounds
  /// Occurs when operating with a [`Table`](crate::Table) and mismatching element types.
  ElementTypeMismatch
  /// The operation ran out of fuel before completion.
  OutOfFuel(required_fuel~ : UInt64)
} derive(Debug)

///|
/// Rust's `Display` of [TableError].
pub impl Show for TableError with fn output(self, logger) {
  let message = match self {
    OutOfSystemMemory =>
      "tried to allocate more virtual memory than available on the system"
    MinimumSizeOverflow => "the minimum table size overflows the system bounds"
    MaximumSizeOverflow => "the maximum table size overflows the system bounds"
    ResourceLimiterDeniedAllocation =>
      "a resource limiter denied to allocate or grow the table"
    GrowOutOfBounds => "out of bounds table access: `table.growth`"
    InitOutOfBounds => "out of bounds table access: `table.init`"
    FillOutOfBounds => "out of bounds table access: `table.fill`"
    CopyOutOfBounds => "out of bounds table access: `table.copy`"
    SetOutOfBounds => "out of bounds table access: `table.set`"
    ElementTypeMismatch => "encountered mismatching table element type"
    OutOfFuel(required_fuel~) => {
      logger.write_string("not enough fuel: required=\{required_fuel}")
      return
    }
  }
  logger.write_string(message)
}

///|
pub extend TableError with Show::{to_string, output}

///|
/// `impl From<LimiterError> for TableError`
pub fn TableError::from_limiter_error(error : LimiterError) -> TableError {
  match error {
    LimiterError::OutOfSystemMemory => OutOfSystemMemory
    LimiterError::OutOfBoundsGrowth => GrowOutOfBounds
    LimiterError::ResourceLimiterDeniedAllocation =>
      ResourceLimiterDeniedAllocation
    LimiterError::OutOfFuel(required_fuel~) => OutOfFuel(required_fuel~)
  }
}

///|
/// `impl From<FuelError> for TableError`
pub fn TableError::from_fuel_error(error : FuelError) -> TableError {
  match error {
    FuelError::OutOfFuel(required_fuel~) => OutOfFuel(required_fuel~)
    FuelError::FuelMeteringDisabled => abort("fuel metering is disabled")
  }
}
