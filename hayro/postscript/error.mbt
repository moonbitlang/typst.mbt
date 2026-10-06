// Port of `hayro-postscript/src/error.rs`: error types for the PostScript
// scanner.

///|
/// An error encountered while scanning a PostScript token stream (upstream
/// `Error`; renamed since `Error` is a builtin MoonBit type).
pub(all) enum PsError {
  /// A syntax error in the input.
  SyntaxError
  /// A numeric value exceeded implementation limits.
  LimitCheck
  /// An unsupported PostScript type was encountered (like dictionaries or
  /// procedures, which will be added in the future).
  UnsupportedType
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PsError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PsError with @debug.Debug::{to_repr}

///|
pub impl Show for PsError with fn output(self, logger) {
  logger.write_string(
    match self {
      SyntaxError => "syntaxerror"
      LimitCheck => "limitcheck"
      UnsupportedType => "unsupported type"
    },
  )
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PsError with Show::{to_string, output}
