// Generated stubs for native functions that are not ported yet.

///|
/// TODO: port `plugin` (typst-library/src/foundations/plugin.rs).
fn impl_plugin(engine : Engine, source_ : @syntax.Spanned[DataSource]) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "`plugin` is not yet ported")])
}

///|
/// TODO: port `plugin.transition` (typst-library/src/foundations/plugin.rs).
fn impl_plugin_transition(func_ : Value, arguments_ : Array[BytesValue]) -> Value raise HintedError {
  ignore(func_)
  ignore(arguments_)
  bail("`plugin.transition` is not yet ported")
}

///|
/// TODO: port `target` (typst-library/src/foundations/target.rs).
fn impl_target(context : Context) -> Value raise HintedError {
  ignore(context)
  bail("`target` is not yet ported")
}

///|
/// TODO: port `layout` (typst-library/src/layout/layout.rs).
fn impl_layout(span : @syntax.Span, func_ : Func) -> Content raise HintedError {
  ignore(span)
  ignore(func_)
  bail("`layout` is not yet ported")
}

///|
/// TODO: port `measure` (typst-library/src/layout/measure.rs).
fn impl_measure(engine : Engine, context : Context, span : @syntax.Span, width_ : Smart[Length], height_ : Smart[Length], content_ : Content) -> Dict raise SourceError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(width_)
  ignore(height_)
  ignore(content_)
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "`measure` is not yet ported")])
}

///|
/// TODO: port default `Em::new(0.5).into()`.
fn impl_outline_entry_indented__gap_default() -> Length raise SourceError {
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "default of `outline_entry_indented.gap` is not yet ported")])
}

///|
/// TODO: port `OutlineEntry.indented` (typst-library/src/model/outline.rs).
fn impl_outline_entry_indented(self_ : Value, engine : Engine, context : Context, span : @syntax.Span, prefix_ : Content?, inner_ : Content, gap_ : Length) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(prefix_)
  ignore(inner_)
  ignore(gap_)
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "`OutlineEntry.indented` is not yet ported")])
}

///|
/// TODO: port `OutlineEntry.prefix` (typst-library/src/model/outline.rs).
fn impl_outline_entry_prefix(self_ : Value, engine : Engine, context : Context, span : @syntax.Span) -> Content? raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "`OutlineEntry.prefix` is not yet ported")])
}

///|
/// TODO: port `OutlineEntry.inner` (typst-library/src/model/outline.rs).
fn impl_outline_entry_inner(self_ : Value, engine : Engine, context : Context, span : @syntax.Span) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "`OutlineEntry.inner` is not yet ported")])
}

///|
/// TODO: port `OutlineEntry.body` (typst-library/src/model/outline.rs).
fn impl_outline_entry_body(self_ : Value) -> Content raise HintedError {
  ignore(self_)
  bail("`OutlineEntry.body` is not yet ported")
}

///|
/// TODO: port `OutlineEntry.page` (typst-library/src/model/outline.rs).
fn impl_outline_entry_page(self_ : Value, engine : Engine, context : Context, span : @syntax.Span) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([SourceDiagnostic::error_at(@syntax.Span::detached(), "`OutlineEntry.page` is not yet ported")])
}
