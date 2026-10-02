// Generated stubs for native functions that are not ported yet.

///|
/// TODO: port `plugin` (typst-library/src/foundations/plugin.rs).
fn impl_plugin(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`plugin` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `plugin.transition` (typst-library/src/foundations/plugin.rs).
fn impl_plugin_transition(
  func_ : Value,
  arguments_ : Array[BytesValue],
) -> Value raise HintedError {
  ignore(func_)
  ignore(arguments_)
  bail("`plugin.transition` is not yet ported")
}
