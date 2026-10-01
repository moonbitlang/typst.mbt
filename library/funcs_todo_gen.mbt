// Generated stubs for native functions that are not ported yet.

///|
/// TODO: port `plugin` (typst-library/src/foundations/plugin.rs).
fn impl_plugin(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
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

///|
/// TODO: port `layout` (typst-library/src/layout/layout.rs).
fn impl_layout(span : @syntax.Span, func_ : Func) -> Content raise HintedError {
  ignore(span)
  ignore(func_)
  bail("`layout` is not yet ported")
}

///|
/// TODO: port `measure` (typst-library/src/layout/measure.rs).
fn impl_measure(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  width_ : Smart[Length],
  height_ : Smart[Length],
  content_ : Content,
) -> Dict raise SourceError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(width_)
  ignore(height_)
  ignore(content_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`measure` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `cbor` (typst-library/src/loading/cbor.rs).
fn impl_cbor(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`cbor` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `cbor.encode` (typst-library/src/loading/cbor.rs).
fn impl_cbor_encode(
  value_ : @syntax.Spanned[Value],
) -> BytesValue raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`cbor.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_csv__delimiter_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `csv.delimiter` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `RowType::Array`.
fn impl_csv__row_type_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `csv.row_type` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `csv` (typst-library/src/loading/csv.rs).
fn impl_csv(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
  delimiter_ : Value,
  row_type_ : Value,
) -> Arr raise SourceError {
  ignore(engine)
  ignore(source_)
  ignore(delimiter_)
  ignore(row_type_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`csv` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `json` (typst-library/src/loading/json.rs).
fn impl_json(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`json` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `json.encode` (typst-library/src/loading/json.rs).
fn impl_json_encode(
  value_ : @syntax.Spanned[Value],
  pretty_ : Bool,
) -> String raise SourceError {
  ignore(value_)
  ignore(pretty_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`json.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Some(Encoding::Utf8)`.
fn impl_read__encoding_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `read.encoding` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `read` (typst-library/src/loading/read.rs).
fn impl_read(
  engine : Engine,
  path_ : @syntax.Spanned[PathOrStr],
  encoding_ : Value,
) -> Value raise SourceError {
  ignore(engine)
  ignore(path_)
  ignore(encoding_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`read` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `toml` (typst-library/src/loading/toml.rs).
fn impl_toml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Dict raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`toml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `toml.encode` (typst-library/src/loading/toml.rs).
fn impl_toml_encode(
  value_ : @syntax.Spanned[Dict],
  pretty_ : Bool,
) -> String raise SourceError {
  ignore(value_)
  ignore(pretty_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`toml.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `xml` (typst-library/src/loading/xml.rs).
fn impl_xml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`xml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `yaml` (typst-library/src/loading/yaml.rs).
fn impl_yaml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`yaml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `yaml.encode` (typst-library/src/loading/yaml.rs).
fn impl_yaml_encode(
  value_ : @syntax.Spanned[Value],
) -> String raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`yaml.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Em::new(0.5).into()`.
fn impl_outline_entry_indented__gap_default() -> Length raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `outline_entry_indented.gap` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.indented` (typst-library/src/model/outline.rs).
fn impl_outline_entry_indented(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  prefix_ : Content?,
  inner_ : Content,
  gap_ : Length,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(prefix_)
  ignore(inner_)
  ignore(gap_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.indented` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.prefix` (typst-library/src/model/outline.rs).
fn impl_outline_entry_prefix(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content? raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.prefix` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.inner` (typst-library/src/model/outline.rs).
fn impl_outline_entry_inner(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.inner` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.body` (typst-library/src/model/outline.rs).
fn impl_outline_entry_body(self_ : Value) -> Content raise HintedError {
  ignore(self_)
  bail("`OutlineEntry.body` is not yet ported")
}

///|
/// TODO: port `OutlineEntry.page` (typst-library/src/model/outline.rs).
fn impl_outline_entry_page(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.page` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `#[defs]` of `HtmlFormat` (typst-html/src/format.rs).
fn defs_html_format(scope : Scope) -> Unit {
  ignore(scope)
}
