// Port of `typst-library/src/format.rs` (registration of export formats; the
// format option plumbing into the document is ported with realization).

///|
/// An export format with an associated format element.
pub(all) struct Format {
  /// The format element (e.g. `pdf`), defined on `std.format`.
  elem : Element
  /// The feature gating the format, if any.
  feature : Feature?
  /// Registers the rules specific to this format.
  rules : ((NativeRuleMap) -> Unit)?
}

///|
/// Create a new format with an associated format element.
pub fn Format::new(elem : Element) -> Format {
  { elem, feature: None, rules: None, }
}

///|
/// Add format specific rules that will be registered.
pub fn Format::with_rules(
  self : Format,
  register : (NativeRuleMap) -> Unit,
) -> Format {
  { ..self, rules: Some(register), }
}

///|
/// Register the rules specific to this format.
pub fn Format::register_rules(self : Format, rules : NativeRuleMap) -> Unit {
  if self.rules is Some(register) {
    register(rules)
  }
}

///|
/// Get the default format options of this format.
pub fn Format::default_options(self : Format) -> FormatOptions {
  FormatOptions::new(self.elem)
}

///|
/// Gate the format behind a feature flag.
pub fn Format::with_feature(self : Format, feature : Feature) -> Format {
  { ..self, feature: Some(feature), }
}

///|
/// The global `format` module on which all registered formats are defined.
pub fn format_module(formats : Array[Format]) -> Module {
  let format = Scope::deduplicating()
  format.start_category(Format)
  for f in formats {
    let binding = format.define(f.elem.name(), Func(Func::element(f.elem)))
    if f.feature is Some(feature) {
      binding.with_feature(feature) |> ignore
    }
  }
  Module::new("format", format)
}

// The formats of the export crates (`typst_<crate>::FORMAT`).

///|
/// `typst_html::FORMAT`.
pub fn html_format() -> Format {
  Format::new(html_format_elem()).with_feature(Html)
}

///|
/// `typst_pdf::FORMAT`.
pub fn pdf_format() -> Format {
  Format::new(pdf_format_elem())
}

///|
/// `typst_svg::FORMAT`.
pub fn svg_format() -> Format {
  Format::new(svg_format_elem())
}

///|
/// `typst_render::FORMAT`.
pub fn png_format() -> Format {
  Format::new(png_format_elem())
}

///|
/// `typst_bundle::FORMAT`.
pub fn bundle_format() -> Format {
  Format::new(bundle_format_elem()).with_feature(Bundle)
}

///|
/// Define the binding at the end of `path` (looked up through the scopes of
/// the values along it) in this scope, carrying over a feature gate on the
/// path (upstream `Scope::prelude_path`).
pub fn Scope::prelude_path(self : Scope, path : Array[String]) -> Binding? {
  if path.length() < 2 {
    abort("prelude path must have at least two segments")
  }
  guard self.get(path[0]) is Some(first) else { return None }
  let mut binding = first
  let mut path_feature = binding.feature()
  for name in path[1:] {
    guard binding.value.scope() is Some(scope) else { return None }
    guard scope.get(name) is Some(next) else { return None }
    binding = next
    if binding.feature() is Some(new) {
      if path_feature is Some(prev) && prev != new {
        abort(
          "cannot prelude from path \{path} because it's gated by two different features: `\{prev}` and `\{new}`",
        )
      }
      path_feature = Some(new)
    }
  }
  // Copy the metadata too, so that gating the copy leaves the original
  // binding untouched.
  let binding = { ..binding.copy(), info: binding.info.map(i => { ..i, }), }
  if path_feature is Some(feature) {
    binding.with_feature(feature) |> ignore
  }
  Some(self.bind(path[path.length() - 1], binding))
}

///|
/// The configured options of one export format: a value (and the span of
/// the set rule it stems from) for each settable field of the format element
/// (upstream: the format's `Options` struct of `SpannedValue`s, populated
/// through `Populate`).
pub struct FormatOptions {
  /// The format element.
  elem : Element
  /// Values by field id (settable fields only).
  priv values : Map[Int, @syntax.Spanned[Value]]
}

///|
/// The default options of a format element: each settable field's value in
/// an empty style chain, with a detached span.
pub fn FormatOptions::new(elem : Element) -> FormatOptions {
  let values = {}
  let empty = StyleChain::empty()
  for f in elem.fields() {
    if !f.internal && f.kind is Settable {
      values[f.id] = @syntax.Spanned::{
        v: empty.get_value_with_local(elem, f, None),
        span: @syntax.Span::detached(),
      }
    }
  }
  { elem, values }
}

///|
/// Populate these options from the spanned styles. If a field has been set,
/// this also updates its span.
pub fn FormatOptions::populate(
  self : FormatOptions,
  styles : StyleChain,
  span : @syntax.Span,
) -> Unit {
  for f in self.elem.fields() {
    if !f.internal && f.kind is Settable && styles.has(self.elem, f.id) {
      self.values[f.id] = @syntax.Spanned::{
        v: styles.get_value_with_local(self.elem, f, None),
        span,
      }
    }
  }
}

///|
/// The value of a field (by field id) together with the span of the set rule
/// it stems from.
pub fn FormatOptions::get(
  self : FormatOptions,
  id : Int,
) -> @syntax.Spanned[Value]? {
  self.values.get(id)
}

///|
/// A list of format options that have been configured by the document.
pub struct DocumentFormatOptions {
  priv options : Array[FormatOptions]
}

///|
/// Initialize default format options from a list of formats.
pub fn DocumentFormatOptions::new(
  formats : Array[Format],
) -> DocumentFormatOptions {
  { options: formats.map(f => f.default_options()) }
}

///|
/// Get the options of a format element.
pub fn DocumentFormatOptions::get(
  self : DocumentFormatOptions,
  elem : Element,
) -> FormatOptions {
  for o in self.options {
    if o.elem == elem {
      return o
    }
  }
  abort(
    "format `\{elem.name()}` not found\nhint: if you're a developer, you need to register `Library::formats`",
  )
}

///|
/// Populate the format options with details from the given styles.
pub fn DocumentFormatOptions::populate(
  self : DocumentFormatOptions,
  styles : StyleChain,
  span : @syntax.Span,
) -> Unit {
  for o in self.options {
    o.populate(styles, span)
  }
}
