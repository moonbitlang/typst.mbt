// Port of `wasmi_core/src/memory/error.rs`.

///|
/// An error that may occur upon operating with virtual or linear memory.
pub(all) suberror MemoryError {
  /// Tried to allocate more virtual memory than technically possible.
  OutOfSystemMemory
  /// Tried to grow linear memory out of its set bounds.
  OutOfBoundsGrowth
  /// Tried to access linear memory out of bounds.
  OutOfBoundsAccess
  /// Tried to create an invalid linear memory type.
  InvalidMemoryType
  /// Tried to create memory with invalid static buffer size
  InvalidStaticBufferSize
  /// If a resource limiter denied allocation or growth of a linear memory.
  ResourceLimiterDeniedAllocation
  /// The minimum size of the memory type overflows the system index type.
  MinimumSizeOverflow
  /// The maximum size of the memory type overflows the system index type.
  MaximumSizeOverflow
  /// Encountered if a `memory.grow` operation runs out of fuel.
  OutOfFuel(required_fuel~ : UInt64)
} derive(Debug)

///|
/// Rust's `Display` of [MemoryError].
pub impl Show for MemoryError with fn output(self, logger) {
  let message = match self {
    OutOfSystemMemory =>
      "tried to allocate more virtual memory than available on the system"
    OutOfBoundsGrowth => "out of bounds memory growth"
    OutOfBoundsAccess => "out of bounds memory access"
    InvalidMemoryType => "tried to create an invalid linear memory type"
    InvalidStaticBufferSize => "tried to use too small static buffer"
    ResourceLimiterDeniedAllocation =>
      "a resource limiter denied to allocate or grow the linear memory"
    MinimumSizeOverflow =>
      "the minimum size of the memory type overflows the system index type"
    MaximumSizeOverflow =>
      "the maximum size of the memory type overflows the system index type"
    OutOfFuel(required_fuel~) => {
      logger.write_string("not enough fuel. required=\{required_fuel}")
      return
    }
  }
  logger.write_string(message)
}

///|
pub extend MemoryError with Show::{to_string, output}

///|
/// `impl From<LimiterError> for MemoryError`
pub fn MemoryError::from_limiter_error(error : LimiterError) -> MemoryError {
  match error {
    LimiterError::OutOfSystemMemory => OutOfSystemMemory
    LimiterError::OutOfBoundsGrowth => OutOfBoundsGrowth
    LimiterError::ResourceLimiterDeniedAllocation =>
      ResourceLimiterDeniedAllocation
    LimiterError::OutOfFuel(required_fuel~) => OutOfFuel(required_fuel~)
  }
}
