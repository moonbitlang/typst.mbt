// Port of wasmi 1.0.9 `error.rs`.
//
// Upstream `WasmiError` is a boxed `ErrorKind`; here the error kinds are the
// constructors of the `WasmiError` suberror directly.

///|
/// The generic Wasmi root error type.
pub(all) suberror WasmiError {
  /// A trap code as defined by the WebAssembly specification.
  TrapCode(@wasmi_core.TrapCode)
  /// A message usually provided by Wasmi users of host function calls.
  Message(String)
  /// An `i32` exit status usually used by WASI applications.
  I32ExitStatus(Int)
  /// A trap as defined by the WebAssembly specification.
  Host(@wasmi_core.HostError)
  /// A global variable error.
  Global(@wasmi_core.GlobalError)
  /// A linear memory error.
  Memory(@wasmi_core.MemoryError)
  /// A table error.
  Table(@wasmi_core.TableError)
  /// A linker error.
  Linker(LinkerError)
  /// A module instantiation error.
  Instantiation(InstantiationError)
  /// A fuel error.
  Fuel(@wasmi_core.FuelError)
  /// A function error.
  Func(FuncError)
  /// Encountered when there is a problem with the Wasm input stream.
  Read(ReadError)
  /// Encountered when there is a Wasm parsing or validation error.
  Wasm(@wasmparser.BinaryReaderError)
  /// Encountered when there is a Wasm to Wasmi translation error.
  Translation(TranslationError)
  /// Encountered when an enforced limit is exceeded.
  Limits(EnforcedLimitsError)
  /// Encountered for Wasmi bytecode related errors.
  Ir(@ir.IrError)
  /// A resumable out of fuel error (upstream `ResumableOutOfFuelError`),
  /// carrying the minimum required amount of fuel to progress execution.
  ResumableOutOfFuel(UInt64)
}

///|
/// Creates a new [`WasmiError`] described by a `message`.
pub fn WasmiError::new(message : String) -> WasmiError {
  Message(message)
}

///|
/// Creates a custom [`HostError`].
pub fn WasmiError::host(host_error : @wasmi_core.HostError) -> WasmiError {
  Host(host_error)
}

///|
/// Creates a new [`WasmiError`] representing an explicit program exit with a
/// classic `i32` exit status value.
pub fn WasmiError::i32_exit(status : Int) -> WasmiError {
  I32ExitStatus(status)
}

///|
pub fn WasmiError::from_ir(error : @ir.IrError) -> WasmiError {
  Ir(error)
}

///|
pub fn WasmiError::from_translation(error : TranslationError) -> WasmiError {
  Translation(error)
}

///|
pub fn WasmiError::from_wasm(
  error : @wasmparser.BinaryReaderError,
) -> WasmiError {
  Wasm(error)
}

///|
/// Returns a reference to [`TrapCode`] if [`WasmiError`] is a [`TrapCode`].
pub fn WasmiError::as_trap_code(self : WasmiError) -> @wasmi_core.TrapCode? {
  match self {
    TrapCode(trap_code) => Some(trap_code)
    Fuel(@wasmi_core.FuelError::OutOfFuel(..)) => Some(OutOfFuel)
    Table(@wasmi_core.TableError::OutOfFuel(..)) => Some(OutOfFuel)
    Memory(@wasmi_core.MemoryError::OutOfFuel(..)) => Some(OutOfFuel)
    Memory(OutOfBoundsAccess) | Memory(OutOfBoundsGrowth) =>
      Some(MemoryOutOfBounds)
    Table(ElementTypeMismatch) => Some(BadSignature)
    Table(SetOutOfBounds)
    | Table(FillOutOfBounds)
    | Table(GrowOutOfBounds)
    | Table(InitOutOfBounds) => Some(TableOutOfBounds)
    ResumableOutOfFuel(_) => Some(OutOfFuel)
    _ => None
  }
}

///|
/// Returns the `i32` exit status if [`WasmiError`] is an `I32ExitStatus`.
pub fn WasmiError::i32_exit_status(self : WasmiError) -> Int? {
  match self {
    I32ExitStatus(status) => Some(status)
    _ => None
  }
}

///|
/// Upstream `Display for ErrorKind`.
pub impl Show for WasmiError with fn output(self, f) {
  match self {
    TrapCode(error) => f.write_string(error.trap_message())
    I32ExitStatus(status) =>
      f.write_string("Exited with i32 exit status \{status}\n")
    Message(message) => f.write_string(message)
    Host(error) => f.write_string(error.to_string())
    Global(error) => error.output(f)
    Memory(error) => error.output(f)
    Table(error) => error.output(f)
    Linker(error) => error.output(f)
    Func(error) => error.output(f)
    Instantiation(error) => error.output(f)
    Fuel(error) => error.output(f)
    Read(error) => error.output(f)
    Wasm(error) => f.write_string(error.to_string())
    Translation(error) => error.output(f)
    Limits(error) => error.output(f)
    Ir(error) => error.output(f)
    ResumableOutOfFuel(required_fuel) =>
      f.write_string(
        "ran out of fuel while calling a resumable function: required_fuel=\{required_fuel}",
      )
  }
}

///|
/// Upstream `WasmiError::to_string()` (the `Display` text).
pub fn WasmiError::message(self : WasmiError) -> String {
  let buf = StringBuilder()
  Show::output(self, buf)
  buf.to_string()
}

///|
/// An error that may occur upon reading from a Wasm input stream (module/read.rs).
pub(all) enum ReadError {
  /// The end of the stream has been reached unexpectedly.
  EndOfStream
  /// An unknown error occurred.
  UnknownError
} derive(Eq)

///|
pub impl Show for ReadError with fn output(self, f) {
  match self {
    EndOfStream => f.write_string("encountered unexpected end of stream")
    UnknownError => f.write_string("encountered unknown error")
  }
}

///|
/// Errors that can occur upon type checking function signatures (func/error.rs).
pub(all) enum FuncError {
  /// The exported function could not be found.
  ExportedFuncNotFound
  /// A function parameter did not match the required type.
  MismatchingParameterType
  /// Specified an incorrect number of parameters.
  MismatchingParameterLen
  /// A function result did not match the required type.
  MismatchingResultType
  /// Specified an incorrect number of results.
  MismatchingResultLen
} derive(Eq)

///|
pub impl Show for FuncError with fn output(self, f) {
  match self {
    ExportedFuncNotFound => f.write_string("could not find exported function")
    MismatchingParameterType =>
      f.write_string("encountered incorrect function parameter type")
    MismatchingParameterLen =>
      f.write_string("encountered an incorrect number of parameters")
    MismatchingResultType =>
      f.write_string("encountered incorrect function result type")
    MismatchingResultLen =>
      f.write_string("encountered an incorrect number of results")
  }
}
