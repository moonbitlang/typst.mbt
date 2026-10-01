// Port of `typst-library/src/format.rs` (registration of export formats; the
// format option plumbing into the document is ported with realization).

///|
/// An export format with an associated format element.
pub(all) struct Format {
  /// The format element (e.g. `pdf`), defined on `std.format`.
  elem : Element
  /// The feature gating the format, if any.
  feature : Feature?
}

///|
/// Create a new format with an associated format element.
pub fn Format::new(elem : Element) -> Format {
  { elem, feature: None, }
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
