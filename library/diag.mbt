// Port of upstream `typst-library/src/diag.rs`.
//
// Error handling: upstream `StrResult<T>` / `HintedStrResult<T>` become
// `T raise HintedError` and `SourceResult<T>` becomes `T raise SourceError`.

///|
/// The severity of a [SourceDiagnostic].
pub(all) enum Severity {
  /// A fatal error.
  Error
  /// A non-fatal warning.
  Warning
} derive(Eq, Hash, Debug)

///|
/// A part of a diagnostic's trace.
pub(all) enum Tracepoint {
  /// A function call.
  Call(String?)
  /// A show rule application.
  Show(String)
  /// A module import.
  Import(String)
  /// A file include.
  Include(String)
} derive(Eq, Hash, Debug)

///|
pub impl Show for Tracepoint with fn output(self, logger) {
  match self {
    Call(Some(name)) => logger.write_string("while calling `\{name}`")
    Call(None) => logger.write_string("while calling function")
    Show(name) => logger.write_string("while showing \{name} element")
    Import(name) => logger.write_string("while importing `\{name}`")
    Include(name) => logger.write_string("while including `\{name}`")
  }
}

///|
/// An error or warning in a source or text file.
pub(all) struct SourceDiagnostic {
  /// Whether the diagnostic is an error or a warning.
  severity : Severity
  /// The span of a relevant node in a Typst source file or the relevant byte
  /// range of an external file.
  span : @syntax.DiagSpan
  /// A diagnostic message describing the problem.
  message : String
  /// The trace of function calls leading to the problem.
  trace : Array[@syntax.Spanned[Tracepoint]]
  /// Additional hints to the user.
  hints : Array[@syntax.DiagSpanned[String]]
} derive(Eq, Hash, Debug)

///|
/// Create a new, bare error.
pub fn SourceDiagnostic::error(
  span : @syntax.DiagSpan,
  message : String,
) -> SourceDiagnostic {
  { severity: Error, span, message, trace: [], hints: [], }
}

///|
/// Create a new, bare error at a [Span].
pub fn SourceDiagnostic::error_at(
  span : @syntax.Span,
  message : String,
) -> SourceDiagnostic {
  SourceDiagnostic::error(@syntax.DiagSpan::from_span(span), message)
}

///|
/// Create a new, bare warning.
pub fn SourceDiagnostic::warning(
  span : @syntax.DiagSpan,
  message : String,
) -> SourceDiagnostic {
  { severity: Warning, span, message, trace: [], hints: [], }
}

///|
/// Create a new, bare warning at a [Span].
pub fn SourceDiagnostic::warning_at(
  span : @syntax.Span,
  message : String,
) -> SourceDiagnostic {
  SourceDiagnostic::warning(@syntax.DiagSpan::from_span(span), message)
}

///|
/// Adds a single hint to the diagnostic.
pub fn SourceDiagnostic::hint(self : SourceDiagnostic, hint : String) -> Unit {
  self.hints.push({ v: hint, span: @syntax.DiagSpan::detached(), })
}

///|
/// Adds a single hint specific to a source code location.
pub fn SourceDiagnostic::spanned_hint(
  self : SourceDiagnostic,
  hint : String,
  span : @syntax.DiagSpan,
) -> Unit {
  self.hints.push({ v: hint, span, })
}

///|
/// Adds a single hint to the diagnostic (builder style).
pub fn SourceDiagnostic::with_hint(
  self : SourceDiagnostic,
  hint : String,
) -> SourceDiagnostic {
  self.hint(hint)
  self
}

///|
/// Adds multiple hints to the diagnostic (builder style).
pub fn SourceDiagnostic::with_hints(
  self : SourceDiagnostic,
  hints : ArrayView[String],
) -> SourceDiagnostic {
  for h in hints {
    self.hint(h)
  }
  self
}

///|
/// Adds a user-facing trace point (builder style).
pub fn SourceDiagnostic::with_tracepoint(
  self : SourceDiagnostic,
  tracepoint : Tracepoint,
  span : @syntax.Span,
) -> SourceDiagnostic {
  self.trace.push({ v: tracepoint, span, })
  self
}

///|
/// Convert a syntax error or warning into a source diagnostic.
pub fn SourceDiagnostic::from_syntax(
  diag : @syntax.SyntaxDiagnostic,
) -> SourceDiagnostic {
  {
    severity: if diag.is_error {
      Error
    } else {
      Warning
    },
    span: diag.span,
    message: diag.message,
    trace: [],
    hints: diag.hints.copy(),
  }
}

///|
/// A string message with optional hints: upstream `HintedString`, used for
/// `StrResult` and `HintedStrResult`.
pub(all) struct HintedString {
  message : String
  hints : Array[String]
} derive(Eq, Hash, Debug)

///|
pub fn HintedString::new(message : String) -> HintedString {
  { message, hints: [], }
}

///|
/// Adds a single hint.
pub fn HintedString::hint(self : HintedString, hint : String) -> Unit {
  self.hints.push(hint)
}

///|
/// Adds a single hint (builder style).
pub fn HintedString::with_hint(
  self : HintedString,
  hint : String,
) -> HintedString {
  self.hints.push(hint)
  self
}

///|
/// Convert into an error diagnostic at the given span.
pub fn HintedString::into_error_at(
  self : HintedString,
  span : @syntax.Span,
) -> SourceDiagnostic {
  SourceDiagnostic::error_at(span, self.message).with_hints(self.hints)
}

///|
/// Convert into a warning diagnostic at the given span.
pub fn HintedString::into_warning_at(
  self : HintedString,
  span : @syntax.Span,
) -> SourceDiagnostic {
  SourceDiagnostic::warning_at(span, self.message).with_hints(self.hints)
}

///|
/// An error without a span: upstream `StrResult`/`HintedStrResult` error.
pub(all) suberror HintedError {
  HintedError(HintedString)
} derive(Debug)

///|
/// An error with spans: upstream `SourceResult` error.
pub(all) suberror SourceError {
  SourceError(Array[SourceDiagnostic])
} derive(Debug)

///|
/// Raise a [HintedError] with a message (upstream `bail!("...")`).
pub fn[T] bail(message : String) -> T raise HintedError {
  raise HintedError({ message, hints: [], })
}

///|
/// Raise a [HintedError] with a message and hints.
pub fn[T] bail_hinted(
  message : String,
  hints : ArrayView[String],
) -> T raise HintedError {
  raise HintedError({ message, hints: hints.to_owned(), })
}

///|
/// Raise a [SourceError] with a single error at a span (upstream
/// `bail!(span, "...")`).
pub fn[T] bail_at(
  span : @syntax.Span,
  message : String,
  hints? : ArrayView[String] = [],
) -> T raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(span, message).with_hints(hints),
  ])
}

///|
/// Raise a [SourceError] with the given diagnostic.
pub fn[T] bail_diag(diag : SourceDiagnostic) -> T raise SourceError {
  raise SourceError([diag])
}

///|
/// Attach a span to the errors of `f` (upstream `.at(span)`).
pub fn[T] at(
  span : @syntax.Span,
  f : () -> T raise HintedError,
) -> T raise SourceError {
  f() catch {
    HintedError(err) => raise SourceError([err.into_error_at(span)])
  }
}

///|
/// Add a trace point to all errors of `f` that lie outside `span` (upstream
/// `.trace(world, make_point, span)`). `range` maps spans to byte ranges
/// (upstream `world.range`).
pub fn[T] trace(
  range : (@syntax.DiagSpan) -> (Int, Int)?,
  make_point : () -> Tracepoint,
  span : @syntax.Span,
  f : () -> T raise SourceError,
) -> T raise SourceError {
  f() catch {
    SourceError(errors) => {
      guard range(@syntax.DiagSpan::from_span(span)) is Some((ts, te)) else {
        raise SourceError(errors)
      }
      for error in errors {
        // Skip traces that surround the error.
        if range(error.span) is Some((es, ee)) &&
          error.span.id() == span.id() &&
          ts <= es &&
          te >= ee {
          continue
        }
        error.trace.push({ v: make_point(), span, })
      }
      raise SourceError(errors)
    }
  }
}

///|
/// An output alongside warnings generated while producing it.
pub(all) struct Warned[T] {
  /// The produced output.
  output : T
  /// Warnings generated while producing the output.
  warnings : Array[SourceDiagnostic]
}
