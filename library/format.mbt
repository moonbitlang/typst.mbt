// Port of `typst-library/src/format.rs`: registration of export formats and
// the format options configured by a document (`DocumentFormatOptions`).
//
// Upstream's options are typed per format (`FormatElement::Options`, with
// `Complete`/`Partial` field markers). Here, the options of a format are the
// spanned values of all settable fields of its element ([FormatOptions]);
// typed views like `HtmlFormatOptions` read from them.

///|
/// A spanned value that is associated with a specific field of a format
/// element (upstream `SpannedValue<E, I>`).
pub(all) struct SpannedValue[T] {
  v : T
  span : @syntax.Span
} derive(Eq)

///|
/// Create a new spanned value with a detached span.
pub fn[T] SpannedValue::detached(v : T) -> SpannedValue[T] {
  { v, span: @syntax.Span::detached(), }
}

///|
/// Format options that have been configured by the document (upstream
/// `FormatOptions`).
pub struct FormatOptions {
  /// The format element whose settable fields these are.
  elem : Element
  /// The values of the settable fields, by field index.
  priv fields : Map[Int, SpannedValue[Value]]
}

///|
/// The default options of a format element: the defaults of its settable
/// fields (upstream `E::Options::default()`).
pub fn FormatOptions::default_for(elem : Element) -> FormatOptions {
  let fields : Map[Int, SpannedValue[Value]] = Map([])
  for field in elem.fields() {
    if field.kind is (Settable | Ghost) {
      fields[field.id] = SpannedValue::detached(
        StyleChain::empty().get_field(elem, field.id),
      )
    }
  }
  { elem, fields, }
}

///|
/// Populate these options from the spanned styles. If a field has been set,
/// this also updates its span.
pub fn FormatOptions::populate(
  self : FormatOptions,
  styles : StyleChain,
  span : @syntax.Span,
) -> Unit {
  for id, _ in self.fields.copy() {
    if styles.has(self.elem, id) {
      self.fields[id] = { v: styles.get_field(self.elem, id), span, }
    }
  }
}

///|
/// The value of the settable field with the given index.
pub fn FormatOptions::get(
  self : FormatOptions,
  id : Int,
) -> SpannedValue[Value] {
  match self.fields.get(id) {
    Some(v) => v
    None => abort("field \{id} of `\{self.elem.name()}` is not settable")
  }
}

///|
/// A copy of the options.
pub fn FormatOptions::copy(self : FormatOptions) -> FormatOptions {
  { elem: self.elem, fields: self.fields.copy(), }
}

///|
pub impl Fingerprint for FormatOptions with fn fingerprint(self, state) {
  state.write(self.elem)
  for id, value in self.fields {
    state.write_usize(id)
    state.write(value.v)
    state.write(value.span)
  }
}

///|
/// A list of format options that have been configured by the document.
pub struct DocumentFormatOptions(Array[FormatOptions])

///|
/// The formats registered by default (upstream `typst::FORMATS`).
pub fn default_formats() -> Array[Format] {
  [html_format(), pdf_format(), svg_format(), png_format(), bundle_format()]
}

///|
/// Initialize default format options from a list of formats.
pub fn DocumentFormatOptions::new(
  formats? : Array[Format] = default_formats(),
) -> DocumentFormatOptions {
  DocumentFormatOptions(formats.map(f => FormatOptions::default_for(f.elem)))
}

///|
/// Get the options of a format by its element.
pub fn DocumentFormatOptions::get(
  self : DocumentFormatOptions,
  elem : Element,
) -> FormatOptions {
  for o in self.0 {
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
  for o in self.0 {
    o.populate(styles, span)
  }
}

///|
/// A deep copy of the options.
pub fn DocumentFormatOptions::copy(
  self : DocumentFormatOptions,
) -> DocumentFormatOptions {
  DocumentFormatOptions(self.0.map(o => o.copy()))
}

///|
pub impl Fingerprint for DocumentFormatOptions with fn fingerprint(self, state) {
  state.write_usize(self.0.length())
  for o in self.0 {
    state.write(o)
  }
}

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
  FormatOptions::default_for(self.elem)
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
  Format::new(pdf_format_elem()).with_rules(pdf_register)
}

///|
/// Registers show rules for PDF specific elements (upstream
/// `typst_pdf::format::register`).
fn pdf_register(rules : NativeRuleMap) -> Unit {
  rules.register(Paged, (_ : PdfAttachElem, _, _) => Content::empty())
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
  Format::new(bundle_format_elem())
  .with_feature(Bundle)
  .with_rules(bundle_register)
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
