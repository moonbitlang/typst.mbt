// Port of `fancy-regex` 0.16.2 `src/error.rs`. The `Show` impls produce the
// upstream `Display` texts byte for byte.

///|
/// An error as the result of parsing, compiling or running a regex
/// (upstream `fancy_regex::Error`).
pub(all) suberror FancyError {
  /// An error as a result of parsing a regex pattern, with the position
  /// (UTF-8 byte offset) where the error occurred
  ParseError(Int, ParseError)
  /// An error as a result of compiling a regex
  CompileError(CompileError)
  /// An error as a result of running a regex
  RuntimeError(RuntimeError)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FancyError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FancyError with @debug.Debug::{to_repr}

///|
/// An error for the result of parsing a regex pattern.
pub(all) enum ParseError {
  /// General parsing error
  GeneralParseError(String)
  /// Opening parenthesis without closing parenthesis, e.g. `(a|b`
  UnclosedOpenParen
  /// Invalid repeat syntax
  InvalidRepeat
  /// Pattern too deeply nested
  RecursionExceeded
  /// Backslash without following character
  TrailingBackslash
  /// Invalid escape
  InvalidEscape(String)
  /// Unicode escape not closed
  UnclosedUnicodeName
  /// Invalid hex escape
  InvalidHex
  /// Invalid codepoint for hex or unicode escape
  InvalidCodepointValue
  /// Invalid character class
  InvalidClass
  /// Unknown group flag
  UnknownFlag(String)
  /// Disabling Unicode not supported
  NonUnicodeUnsupported
  /// Invalid back reference
  InvalidBackref
  /// Quantifier on lookaround or other zero-width assertion
  TargetNotRepeatable
  /// Couldn't parse group name
  InvalidGroupName
  /// Invalid group id in escape sequence
  InvalidGroupNameBackref(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ParseError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ParseError with @debug.Debug::{to_repr}

///|
/// An error as the result of compiling a regex.
pub(all) enum CompileError {
  /// Regex crate error. Upstream wraps a `regex_automata` `BuildError`
  /// (whose `Display` is just `error parsing pattern 0`); here the payload
  /// is the message of the `regex` package error, kept for debugging.
  InnerError(String)
  /// Look-behind assertion without constant size
  LookBehindNotConst
  /// Couldn't parse group name
  InvalidGroupName
  /// Invalid group id in escape sequence
  InvalidGroupNameBackref(String)
  /// Invalid back reference
  InvalidBackref(Int)
  /// Once named groups are used you cannot refer to groups by number
  NamedBackrefOnly
  /// Feature not supported yet
  FeatureNotYetSupported(String)
  /// Subroutine call to non-existent group
  SubroutineCallTargetNotFound(String, Int)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CompileError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CompileError with @debug.Debug::{to_repr}

///|
/// An error as the result of executing a regex.
pub(all) enum RuntimeError {
  /// Max stack size exceeded for backtracking while executing regex.
  StackOverflow
  /// Max limit for backtracking count exceeded while executing the regex.
  /// Configure using `RegexBuilder::backtrack_limit`.
  BacktrackLimitExceeded
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RuntimeError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RuntimeError with @debug.Debug::{to_repr}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    GeneralParseError(s) => logger.write_string("General parsing error: \{s}")
    UnclosedOpenParen =>
      logger.write_string("Opening parenthesis without closing parenthesis")
    InvalidRepeat => logger.write_string("Invalid repeat syntax")
    RecursionExceeded => logger.write_string("Pattern too deeply nested")
    TrailingBackslash =>
      logger.write_string("Backslash without following character")
    InvalidEscape(s) => logger.write_string("Invalid escape: \{s}")
    UnclosedUnicodeName => logger.write_string("Unicode escape not closed")
    InvalidHex => logger.write_string("Invalid hex escape")
    InvalidCodepointValue =>
      logger.write_string("Invalid codepoint for hex or unicode escape")
    InvalidClass => logger.write_string("Invalid character class")
    UnknownFlag(s) => logger.write_string("Unknown group flag: \{s}")
    NonUnicodeUnsupported =>
      logger.write_string("Disabling Unicode not supported")
    InvalidBackref => logger.write_string("Invalid back reference")
    InvalidGroupName => logger.write_string("Could not parse group name")
    InvalidGroupNameBackref(s) =>
      logger.write_string("Invalid group name in back reference: \{s}")
    TargetNotRepeatable =>
      logger.write_string("Target of repeat operator is invalid")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ParseError with Show::{to_string, output}

///|
pub impl Show for CompileError with fn output(self, logger) {
  match self {
    InnerError(_) => logger.write_string("Regex error: error parsing pattern 0")
    LookBehindNotConst =>
      logger.write_string("Look-behind assertion without constant size")
    InvalidGroupName => logger.write_string("Could not parse group name")
    InvalidGroupNameBackref(s) =>
      logger.write_string("Invalid group name in back reference: \{s}")
    InvalidBackref(g) =>
      logger.write_string("Invalid back reference to group \{g}")
    NamedBackrefOnly =>
      logger.write_string(
        "Numbered backref/call not allowed because named group was used, use a named backref instead",
      )
    FeatureNotYetSupported(s) =>
      logger.write_string("Regex uses currently unimplemented feature: \{s}")
    SubroutineCallTargetNotFound(s, ix) =>
      logger.write_string(
        "Subroutine call target not found at position \{ix}: \{s}",
      )
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CompileError with Show::{to_string, output}

///|
pub impl Show for RuntimeError with fn output(self, logger) {
  match self {
    StackOverflow =>
      logger.write_string("Max stack size exceeded for backtracking")
    BacktrackLimitExceeded =>
      logger.write_string("Max limit for backtracking count exceeded")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RuntimeError with Show::{to_string, output}

///|
/// The upstream `Display` text.
pub fn FancyError::to_string(self : FancyError) -> String {
  "\{self}"
}

///|
pub impl Show for FancyError with fn output(self, logger) {
  match self {
    ParseError(position, parse_error) =>
      logger.write_string(
        "Parsing error at position \{position}: \{parse_error}",
      )
    CompileError(compile_error) =>
      logger.write_string("Error compiling regex: \{compile_error}")
    RuntimeError(runtime_error) =>
      logger.write_string("Error executing regex: \{runtime_error}")
  }
}

///|
// `to_string` is not named here: the type already has a method of this name.
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FancyError with Show::{output}
