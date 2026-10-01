// Port of `typst-library/src/introspection/{here,locate,query}.rs`.

///|
/// Provides the current location in the document.
///
/// You can think of `here` as a low-level building block that directly
/// extracts the current location from the active context.
fn impl_here(context : Context) -> Location raise HintedError {
  context.location()
}

///|
/// Determines the location of an element in the document.
///
/// Takes a selector that must match exactly one element and returns that
/// element's location.
fn impl_locate(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  selector_ : LocatableSelector,
) -> Location raise SourceError {
  selector_.resolve_unique(engine, context, span)
}

///|
/// Finds elements in the document.
///
/// The `query` function lets you search your document for elements of a
/// particular type or with a particular label.
fn impl_query(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  target_ : LocatableSelector,
) -> Arr raise HintedError {
  ignore(span)
  context.introspect()
  let vec = engine.introspector.query(target_.0)
  Arr::from_array(vec.map(c => Content(c)))
}

///|
/// Describes a selector in convergence warnings.
pub fn format_selector(selector : Selector, kind : String) -> String {
  match selector {
    Elem(elem, None) => "\{elem.name()} \{kind}"
    Elem(elem, _) => "matching \{elem.name()} \{kind}"
    Label(label) => "\{kind} labelled `\{label.repr()}`"
    other => "\{kind} matching `\{other.repr()}`"
  }
}
