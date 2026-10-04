// Port of `wasmi_core/src/limiter.rs`.
//
// Upstream `usize` sizes are `UInt64` (a 64-bit `usize`).

///|
/// An error either returned by a [`ResourceLimiter`] or back to one.
pub(all) suberror LimiterError {
  /// Encountered when the underlying system ran out of allocatable memory.
  OutOfSystemMemory
  /// Encountered when a memory or table is grown beyond its bounds.
  OutOfBoundsGrowth
  /// Returned if a [`ResourceLimiter`] denies allocation or growth.
  ResourceLimiterDeniedAllocation
  /// Encountered when an operation ran out of fuel.
  OutOfFuel(required_fuel~ : UInt64)
} derive(Debug)

///|
/// Rust's `Display` of [LimiterError].
pub impl Show for LimiterError with fn output(self, logger) {
  let message = match self {
    OutOfSystemMemory => "out of system memory"
    OutOfBoundsGrowth => "out of bounds growth"
    ResourceLimiterDeniedAllocation => "resource limiter denied allocation"
    OutOfFuel(required_fuel~) => {
      logger.write_string("not enough fuel. required=\{required_fuel}")
      return
    }
  }
  logger.write_string(message)
}

///|
/// `impl From<MemoryError> for LimiterError`
pub fn LimiterError::from_memory_error(error : MemoryError) -> LimiterError {
  match error {
    MemoryError::OutOfSystemMemory => OutOfSystemMemory
    MemoryError::OutOfBoundsGrowth => OutOfBoundsGrowth
    MemoryError::ResourceLimiterDeniedAllocation =>
      ResourceLimiterDeniedAllocation
    MemoryError::OutOfFuel(required_fuel~) => OutOfFuel(required_fuel~)
    error => abort("unexpected `MemoryError`: \{error}")
  }
}

///|
/// `impl From<TableError> for LimiterError`
pub fn LimiterError::from_table_error(error : TableError) -> LimiterError {
  match error {
    TableError::OutOfSystemMemory => OutOfSystemMemory
    TableError::GrowOutOfBounds
    | TableError::CopyOutOfBounds
    | TableError::FillOutOfBounds
    | TableError::InitOutOfBounds => OutOfBoundsGrowth
    TableError::ResourceLimiterDeniedAllocation =>
      ResourceLimiterDeniedAllocation
    TableError::OutOfFuel(required_fuel~) => OutOfFuel(required_fuel~)
    error => abort("unexpected `TableError`: \{error}")
  }
}

///|
/// Used by hosts to limit resource consumption of instances.
///
/// Resources limited via this trait are primarily related to memory.
///
/// Note that this trait does not limit 100% of memory allocated.
/// Implementers might still allocate memory to track data structures
/// and additionally embedder-specific memory allocations are not
/// tracked via this trait.
pub(open) trait ResourceLimiter {
  /// Notifies the resource limiter that an instance's linear memory has been
  /// requested to grow.
  ///
  /// * `current` is the current size of the linear memory in bytes.
  /// * `desired` is the desired size of the linear memory in bytes.
  /// * `maximum` is either the linear memory's maximum or a maximum from an
  ///   instance allocator, also in bytes. A value of `None`
  ///   indicates that the linear memory is unbounded.
  ///
  /// The `current` and `desired` amounts are guaranteed to always be
  /// multiples of the WebAssembly page size, 64KiB.
  ///
  /// ## Return Value
  ///
  /// If `Ok(true)` is returned from this function then the growth operation
  /// is allowed. This means that the wasm `memory.grow` or `table.grow` instructions
  /// will return with the `desired` size, in wasm pages. Note that even if
  /// `Ok(true)` is returned, though, if `desired` exceeds `maximum` then the
  /// growth operation will still fail.
  ///
  /// If `Ok(false)` is returned then this will cause the `grow` instruction
  /// in a module to return -1 (failure), or in the case of an embedder API
  /// calling any of the below methods an error will be returned.
  ///
  /// - [`Memory::new`]
  /// - [`Memory::grow`]
  ///
  /// # Errors
  ///
  /// If `Err(e)` is returned then the `memory.grow` or `table.grow` functions
  /// will behave as if a trap has been raised. Note that this is not necessarily
  /// compliant with the WebAssembly specification but it can be a handy and
  /// useful tool to get a precise backtrace at "what requested so much memory
  /// to cause a growth failure?".
  fn memory_growing(Self, current : UInt64, desired : UInt64, maximum : UInt64?) -> Bool raise LimiterError

  /// Notifies the resource limiter that an instance's table has been
  /// requested to grow.
  ///
  /// * `current` is the current number of elements in the table.
  /// * `desired` is the desired number of elements in the table.
  /// * `maximum` is either the table's maximum or a maximum from an instance
  ///   allocator.  A value of `None` indicates that the table is unbounded.
  ///
  /// # Errors
  ///
  /// See the details on the return values for [`ResourceLimiter::memory_growing`]
  /// for what the return values of this function indicates.
  fn table_growing(Self, current : UInt64, desired : UInt64, maximum : UInt64?) -> Bool raise LimiterError

  /// Notifies the resource limiter that growing a memory, permitted by
  /// the [`ResourceLimiter::memory_growing`] method, has failed.
  fn memory_grow_failed(Self, error : LimiterError) -> Unit = _

  /// Notifies the resource limiter that growing a table, permitted by
  /// the [`ResourceLimiter::table_growing`] method, has failed.
  fn table_grow_failed(Self, error : LimiterError) -> Unit = _

  /// The maximum number of instances that can be created for a Wasm store.
  ///
  /// Module instantiation will fail if this limit is exceeded.
  fn instances(Self) -> UInt64

  /// The maximum number of tables that can be created for a Wasm store.
  ///
  /// Creation of tables will fail if this limit is exceeded.
  fn tables(Self) -> UInt64

  /// The maximum number of linear memories that can be created for a Wasm store.
  ///
  /// Creation of memories will fail with an error if this limit is exceeded.
  fn memories(Self) -> UInt64
}

///|
impl ResourceLimiter with fn memory_grow_failed(_self, _error) {
  ()
}

///|
impl ResourceLimiter with fn table_grow_failed(_self, _error) {
  ()
}

///|
/// Wrapper around an optional `&mut dyn` [`ResourceLimiter`].
pub struct ResourceLimiterRef(&ResourceLimiter?)

///|
pub impl Default for ResourceLimiterRef with fn default() {
  ResourceLimiterRef(None)
}

///|
/// `impl From<&mut dyn ResourceLimiter> for ResourceLimiterRef`
pub fn ResourceLimiterRef::from_limiter(
  limiter : &ResourceLimiter,
) -> ResourceLimiterRef {
  ResourceLimiterRef(Some(limiter))
}

///|
/// Returns an exclusive reference to the underlying [`ResourceLimiter`] if any.
pub fn ResourceLimiterRef::as_resource_limiter(
  self : ResourceLimiterRef,
) -> &ResourceLimiter? {
  self.0
}

///|
pub impl Show for ResourceLimiterRef with fn output(_self, logger) {
  logger.write_string("ResourceLimiterRef(...)")
}
