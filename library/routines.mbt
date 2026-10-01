// Port of `typst-library/src/routines.rs`.

///|
/// Defines implementation of various Typst compiler routines as a table of
/// function pointers (upstream `Routines`).
///
/// This is essentially dynamic linking and done to allow for package
/// splitting.
pub(all) struct Routines {
  /// Creates the map with the built-in show rules.
  rules : () -> NativeRuleMap
  /// Evaluates a string as code/markup/math.
  eval_string : (
    Engine,
    Context,
    String,
    @syntax.Span,
    @syntax.SyntaxMode,
    Scope,
  ) -> Value raise SourceError
  /// Calls a closure.
  eval_closure : (Func, Closure, Engine, Context, Args) -> Value raise SourceError
  /// Realizes content into a flat list of well-known, styled items.
  realize : (RealizationKind, Engine, SplitLocator, Content, StyleChain) -> Array[
    Pair,
  ] raise SourceError
  /// Lays out content into a single region, producing a single frame.
  layout_frame : (Engine, Content, Locator, StyleChain, LayoutRegion) -> Frame raise SourceError
  /// Returns the body of a MathML `HtmlElem`, if the content is one.
  html_mathml_body : (Content, StyleChain) -> Content??
  /// Wraps content in a span with a color.
  ///
  /// This is a temporary workaround until `TextElem::fill` is supported in
  /// HTML export.
  html_span_filled : (Content, Color) -> Content
}

///|
/// Create the routines table. Routines that are not provided are stubs that
/// fail with an error (or, for the HTML helpers, behave as if the content was
/// not special), so that embedders that only evaluate code need not provide
/// them.
pub fn Routines::new(
  eval_string~ : (
    Engine,
    Context,
    String,
    @syntax.Span,
    @syntax.SyntaxMode,
    Scope,
  ) -> Value raise SourceError,
  eval_closure~ : (Func, Closure, Engine, Context, Args) -> Value raise SourceError,
  rules? : () -> NativeRuleMap = NativeRuleMap::new,
  realize? : (RealizationKind, Engine, SplitLocator, Content, StyleChain) -> Array[
    Pair,
  ] raise SourceError = (_, _, _, content, _) => {
    bail_at(content.span(), "realization is not available")
  },
  layout_frame? : (Engine, Content, Locator, StyleChain, LayoutRegion) -> Frame raise SourceError = (
    _,
    content,
    _,
    _,
    _,
  ) => bail_at(content.span(), "layout is not available"),
  html_mathml_body? : (Content, StyleChain) -> Content?? = (_, _) => None,
  html_span_filled? : (Content, Color) -> Content = (content, _) => content,
) -> Routines {
  {
    rules,
    eval_string,
    eval_closure,
    realize,
    layout_frame,
    html_mathml_body,
    html_span_filled,
  }
}

// The types below only live here to enable the routines to be defined here.
// Conceptually, they belong with the modules where the functions they are
// used with are defined in.

///|
/// Defines what kind of realization we are performing.
pub(all) enum RealizationKind {
  /// The realization for bundles. The content is realized into documents and
  /// assets.
  Bundle
  /// This the root realization for a document. Requires mutable document
  /// metadata that will be filled from `set document` rules.
  Document(info~ : DocumentInfo, options~ : DocumentFormatOptions)
  /// A nested realization in a container (e.g. a `block` or an `html.div`).
  /// Requires a mutable cell that will be set to `FragmentKind::Inline` if
  /// the fragment's content was fully inline.
  Fragment(kind~ : Ref[FragmentKind])
  /// A nested realization in a paragraph (i.e. a `par`).
  Par
  /// A realization within math.
  Math
}

///|
/// The kind of fragment output that realization produced.
pub(all) enum FragmentKind {
  /// The fragment's contents were fully inline, and as a result, the output
  /// elements are too.
  Inline
  /// The fragment contained non-inline content, so inline content was forced
  /// into paragraphs, and as a result, the output elements are not inline.
  Block
} derive(Eq, Hash, Debug)

///|
/// A pair of content and a style chain that applies to it.
pub type Pair = (Content, StyleChain)
