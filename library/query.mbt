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
  context.introspect()
  let vec = engine.introspect(query_introspection(target_.0, span))
  Arr::from_array(vec.map(c => Content(c)))
}

///|
/// Retrieves all matches of a selector (upstream `QueryIntrospection`).
pub fn query_introspection(
  selector : Selector,
  span : @syntax.Span,
) -> Introspect[Array[Content]] {
  Introspect::new((_, introspector) => introspector.query(selector), history => {
    let lengths = history.map(vec => vec.length())
    let things = format_selector(selector, "elements")
    let what = if !lengths.converged() {
      "number of \{things}"
    } else {
      "query for \{things}"
    }
    format_query_convergence_warning(span, lengths, what)
  })
}

///|
/// Retrieves the first match of a selector (upstream
/// `QueryFirstIntrospection`).
pub fn query_first_introspection(
  selector : Selector,
  span : @syntax.Span,
) -> Introspect[Content?] {
  Introspect::new((_, introspector) => introspector.query_first(selector), history => {
    let lengths = history.map(vec => if vec is Some(_) { 1 } else { 0 })
    let thing = format_selector(selector, "element")
    let what = "query for the first \{thing}"
    format_query_convergence_warning(span, lengths, what)
  })
}

///|
/// Retrieves the unique match of a selector (upstream
/// `QueryUniqueIntrospection`).
pub fn query_unique_introspection(
  selector : Selector,
  span : @syntax.Span,
) -> Introspect[Result[Content, HintedString]] {
  Introspect::new(
    (_, introspector) => {
      try introspector.query_unique(selector) catch {
        HintedError(err) => Err(err)
      } noraise {
        c => Ok(c)
      }
    },
    history => format_query_unique_convergence_warning(selector, span, history),
  )
}

///|
/// Retrieves the unique element with a label (upstream
/// `QueryLabelIntrospection`).
pub fn query_label_introspection(
  label : Label,
  span : @syntax.Span,
) -> Introspect[Result[Content, HintedString]] {
  Introspect::new(
    (_, introspector) => {
      try introspector.query_label(label) catch {
        HintedError(err) => Err(err)
      } noraise {
        c => Ok(c)
      }
    },
    history => {
      format_query_unique_convergence_warning(Label(label), span, history)
    },
  )
}

///|
/// Upstream `QueryUniqueIntrospection::diagnose`.
fn format_query_unique_convergence_warning(
  selector : Selector,
  span : @syntax.Span,
  history : History[Result[Content, HintedString]],
) -> SourceDiagnostic {
  let lengths = history.map(vec => if vec is Ok(_) { 1 } else { 0 })
  let thing = format_selector(selector, "element")
  let what = "query for a unique \{thing}"
  format_query_convergence_warning(span, lengths, what)
}

///|
/// The warning when a query did not converge.
fn format_query_convergence_warning(
  span : @syntax.Span,
  lengths : History[Int],
  what : String,
) -> SourceDiagnostic {
  let diag = SourceDiagnostic::warning_at(span, "\{what} did not stabilize")
  if !lengths.converged() {
    diag.hint(lengths.hint("numbers of elements", c => "\{c}"))
  }
  diag
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
