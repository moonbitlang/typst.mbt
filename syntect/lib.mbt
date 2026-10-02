// Port of `syntect/src/lib.rs` (the error type).

///|
/// An error enum for all things that can go wrong within syntect (upstream
/// `syntect::Error`, renamed because `Error` is reserved in MoonBit).
pub(all) suberror SyntectError {
  /// An error occurred while loading a syntax or theme
  LoadingError(LoadingError)
  /// An error occurred while parsing
  ParsingError(ParsingError)
  /// Scope error
  ScopeError(ScopeError)
}

///|
pub impl Show for SyntectError with fn output(self, logger) {
  match self {
    LoadingError(e) => logger.write_string("Loading error: \{e}")
    ParsingError(e) => logger.write_string("Parsing error: \{e}")
    ScopeError(e) => logger.write_string("Scope error: \{e}")
  }
}
