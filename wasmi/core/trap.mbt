// Port of `wasmi_core/src/trap.rs`.

///|
/// Error type which can be returned by Wasm code or by the host environment.
///
/// Under some conditions, Wasm execution may produce a [`Trap`],
/// which immediately aborts execution.
/// Traps cannot be handled by WebAssembly code, but are reported to the
/// host embedder.
pub struct Trap {
  /// The cloneable reason of a [`Trap`].
  reason : TrapReason
}

///|
/// The reason of a [`Trap`].
pub enum TrapReason {
  /// Traps during Wasm execution.
  InstructionTrap(TrapCode)
  /// An `i32` exit status code.
  ///
  /// # Note
  ///
  /// This is useful for some WASI functions.
  I32Exit(Int)
  /// An error described by a display message.
  Message(String)
  /// Traps and errors during host execution.
  Host(HostError)
}

///|
/// Returns the classic `i32` exit program code of a `Trap` if any.
///
/// Otherwise returns `None`.
fn TrapReason::i32_exit_status(self : TrapReason) -> Int? {
  if self is I32Exit(status) {
    return Some(status)
  }
  None
}

///|
/// Returns a shared reference to the [`HostError`] if any.
fn TrapReason::as_host(self : TrapReason) -> HostError? {
  if self is Host(host_error) {
    return Some(host_error)
  }
  None
}

///|
/// Returns the [`TrapCode`] traps originating from Wasm execution.
fn TrapReason::trap_code(self : TrapReason) -> TrapCode? {
  if self is InstructionTrap(trap_code) {
    return Some(trap_code)
  }
  None
}

///|
/// Create a new [`Trap`] from the [`TrapReason`].
fn Trap::with_reason(reason : TrapReason) -> Trap {
  { reason, }
}

///|
/// Creates a new [`Trap`] described by a `message`.
pub fn Trap::new(message : String) -> Trap {
  Trap::with_reason(Message(message))
}

///|
/// Downcasts the [`Trap`] into the [`HostError`] if possible.
///
/// Returns `None` otherwise.
///
/// # Note
///
/// Host errors are MoonBit [`Error`]s, so the downcast of upstream
/// (`downcast_ref::<T>`) is a pattern match on the returned error.
pub fn Trap::downcast_ref(self : Trap) -> HostError? {
  self.reason.as_host()
}

///|
/// Creates a new `Trap` representing an explicit program exit with a classic `i32`
/// exit status value.
pub fn Trap::i32_exit(status : Int) -> Trap {
  Trap::with_reason(I32Exit(status))
}

///|
/// Returns the classic `i32` exit program code of a `Trap` if any.
///
/// Otherwise returns `None`.
pub fn Trap::i32_exit_status(self : Trap) -> Int? {
  self.reason.i32_exit_status()
}

///|
/// Returns the [`TrapCode`] traps originating from Wasm execution.
pub fn Trap::trap_code(self : Trap) -> TrapCode? {
  self.reason.trap_code()
}

///|
/// `impl From<TrapCode> for Trap`
pub fn Trap::from_trap_code(error : TrapCode) -> Trap {
  Trap::with_reason(InstructionTrap(error))
}

///|
/// `impl<E: HostError> From<E> for Trap`
pub fn Trap::from_host_error(host_error : HostError) -> Trap {
  Trap::with_reason(Host(host_error))
}

///|
fn TrapReason::fmt(self : TrapReason, logger : &Logger) -> Unit {
  match self {
    InstructionTrap(trap_code) => Show::output(trap_code, logger)
    I32Exit(status) =>
      logger.write_string("Exited with i32 exit status \{status}")
    Message(message) => logger.write_string(message)
    Host(host_error) => logger.write_string(host_error.to_string())
  }
}

///|
/// Rust's `Display` of [Trap].
pub impl Show for Trap with fn output(self, logger) {
  self.reason.fmt(logger)
}

///|
pub extend Trap with Show::{to_string, output}

///|
/// An invalid [`TrapCode`] integer value.
pub(all) suberror InvalidTrapCode derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InvalidTrapCode with @debug.Debug::{to_repr}

///|
/// Error type which can be thrown by wasm code or by host environment.
///
/// See [`Trap`] for details.
///
/// [`Trap`]: struct.Trap.html
pub(all) suberror TrapCode {
  /// Wasm code executed `unreachable` opcode.
  ///
  /// This indicates that unreachable Wasm code was actually reached.
  /// This opcode have a similar purpose as `ud2` in x86.
  UnreachableCodeReached
  /// Attempt to load or store at the address which
  /// lies outside of bounds of the memory.
  ///
  /// Since addresses are interpreted as unsigned integers, out of bounds access
  /// can't happen with negative addresses (i.e. they will always wrap).
  MemoryOutOfBounds
  /// Attempt to access table element at index which
  /// lies outside of bounds.
  ///
  /// This typically can happen when `call_indirect` is executed
  /// with index that lies out of bounds.
  ///
  /// Since indexes are interpreted as unsigned integers, out of bounds access
  /// can't happen with negative indexes (i.e. they will always wrap).
  TableOutOfBounds
  /// Indicates that a `call_indirect` instruction called a function at
  /// an uninitialized (i.e. `null`) table index.
  IndirectCallToNull
  /// Attempt to divide by zero.
  ///
  /// This trap typically can happen if `div` or `rem` is executed with
  /// zero as divider.
  IntegerDivisionByZero
  /// An integer arithmetic operation caused an overflow.
  ///
  /// This can happen when trying to do signed division (or get the remainder)
  /// -2<sup>N-1</sup> over -1. This is because the result +2<sup>N-1</sup>
  /// isn't representable as a N-bit signed integer.
  IntegerOverflow
  /// Attempted to make an invalid conversion to an integer type.
  ///
  /// This can for example happen when trying to truncate NaNs,
  /// infinity, or value for which the result is out of range into an integer.
  BadConversionToInteger
  /// Stack overflow.
  ///
  /// This is likely caused by some infinite or very deep recursion.
  /// Extensive inlining might also be the cause of stack overflow.
  StackOverflow
  /// Attempt to invoke a function with mismatching signature.
  ///
  /// This can happen with indirect calls as they always
  /// specify the expected signature of function. If an indirect call is executed
  /// with an index that points to a function with signature different of what is
  /// expected by this indirect call, this trap is raised.
  BadSignature
  /// This trap is raised when a WebAssembly execution ran out of fuel.
  ///
  /// The Wasmi execution engine can be configured to instrument its
  /// internal bytecode so that fuel is consumed for each executed instruction.
  /// This is useful to deterministically halt or yield a WebAssembly execution.
  OutOfFuel
  /// This trap is raised when a growth operation was attempted and an
  /// installed `wasmi::ResourceLimiter` returned `Err(...)` from the
  /// associated `table_growing` or `memory_growing` method, indicating a
  /// desire on the part of the embedder to trap the interpreter rather than
  /// merely fail the growth operation.
  GrowthOperationLimited
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TrapCode with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TrapCode with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TrapCode with @debug.Debug::{to_repr}

///|
/// `impl From<TrapCode> for u8`
pub fn TrapCode::to_u8(self : TrapCode) -> Byte {
  match self {
    UnreachableCodeReached => 0
    MemoryOutOfBounds => 1
    TableOutOfBounds => 2
    IndirectCallToNull => 3
    IntegerDivisionByZero => 4
    IntegerOverflow => 5
    BadConversionToInteger => 6
    StackOverflow => 7
    BadSignature => 8
    OutOfFuel => 9
    GrowthOperationLimited => 10
  }
}

///|
/// `impl TryFrom<u8> for TrapCode`
pub fn TrapCode::try_from_u8(value : Byte) -> TrapCode raise InvalidTrapCode {
  match value {
    0 => UnreachableCodeReached
    1 => MemoryOutOfBounds
    2 => TableOutOfBounds
    3 => IndirectCallToNull
    4 => IntegerDivisionByZero
    5 => IntegerOverflow
    6 => BadConversionToInteger
    7 => StackOverflow
    8 => BadSignature
    9 => OutOfFuel
    10 => GrowthOperationLimited
    _ => raise InvalidTrapCode
  }
}

///|
/// Returns the trap message as specified by the WebAssembly specification.
///
/// # Note
///
/// This API is primarily useful for the Wasm spec testsuite but might have
/// other uses since it avoid heap memory allocation in certain cases.
pub fn TrapCode::trap_message(self : TrapCode) -> String {
  match self {
    UnreachableCodeReached => "wasm `unreachable` instruction executed"
    MemoryOutOfBounds => "out of bounds memory access"
    TableOutOfBounds => "undefined element: out of bounds table access"
    IndirectCallToNull => "uninitialized element 2" // TODO: fixme, remove the trailing " 2" again
    IntegerDivisionByZero => "integer divide by zero"
    IntegerOverflow => "integer overflow"
    BadConversionToInteger => "invalid conversion to integer"
    StackOverflow => "call stack exhausted"
    BadSignature => "indirect call type mismatch"
    OutOfFuel => "all fuel consumed by WebAssembly"
    GrowthOperationLimited => "growth operation limited"
  }
}

///|
/// Rust's `Display` of [TrapCode].
pub impl Show for TrapCode with fn output(self, logger) {
  logger.write_string(self.trap_message())
}

///|
pub extend TrapCode with Show::{to_string, output}
