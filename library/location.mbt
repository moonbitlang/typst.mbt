// Port of `typst-library/src/introspection/location.rs`.

///|
/// Identifies an element in the document.
///
/// A location uniquely identifies an element in the document and lets you
/// access its absolute position on the pages. You can retrieve the current
/// location with the `here` function and the location of a queried or shown
/// element with the `location()` method on content.
pub(all) struct Location(U128) derive(Eq, Hash, Debug)

///|
/// Create a new location from a unique hash.
pub fn Location::new(hash : U128) -> Location {
  Location(hash)
}

///|
/// Extract the raw hash.
pub fn Location::hash(self : Location) -> U128 {
  self.0
}

///|
/// Produces a well-known variant of this location.
///
/// This is a synthetic location created from another one and is used, for
/// example, in bibliography management to create individual linkable
/// locations for reference entries from the bibliography's location.
pub fn Location::variant(self : Location, n : Int) -> Location {
  Location(hash128((self.0, n)))
}

///|
/// Upstream `Debug for Location` (the short form prints the hash truncated
/// to 16 bits).
pub impl Show for Location with fn output(self, logger) {
  logger.write_string("Location(\{(self.0.lo & 0xffff).to_int()})")
}

///|
pub fn Location::repr(self : Location) -> String {
  ignore(self)
  "location(..)"
}

///|
pub impl Fingerprint for Location with fn fingerprint(self, state) {
  state.write_u128(self.0)
}

///|
/// Can be used to have a location as a key in an ordered set or map.
///
/// [Location] itself does not implement `Compare` because comparing hashes
/// like this has no semantic meaning. The potential for misuse (e.g. checking
/// whether locations have a particular relative ordering) is relatively high.
pub(all) struct LocationKey(U128) derive(Eq, Hash, Compare)

///|
/// Create a location key from a location.
pub fn LocationKey::new(location : Location) -> LocationKey {
  LocationKey(location.0)
}

///|
pub impl Reflect for Location with fn input() {
  Type(Type::location())
}

///|
pub impl Reflect for Location with fn output() {
  Type(Type::location())
}

///|
pub impl Reflect for Location with fn castable(v) {
  v is Dyn(Location(_))
}

///|
pub impl IntoValue for Location with fn into_value(self) {
  Dyn(Location(self))
}

///|
pub impl FromValue for Location with fn from_value(v) {
  match v {
    Dyn(Location(loc)) => loc
    v => raise HintedError(CastInfo::Type(Type::location()).error(v))
  }
}

///|
/// Returns the page number for this location.
///
/// Note that this does not return the value of the @counter[page counter]
/// at this location, but the true page number (starting from one).
fn impl_location_page(
  self_ : Location,
  engine : Engine,
  span : @syntax.Span,
) -> NonZeroUSize? raise HintedError {
  engine.introspect(page_introspection(self_, span))
}

///|
/// Returns the page numbering pattern of the page at this location.
fn impl_location_page_numbering(
  self_ : Location,
  engine : Engine,
  span : @syntax.Span,
) -> Numbering? raise HintedError {
  Location::page_numbering(self_, engine, span)
}

///|
/// Upstream `Location::page_numbering`.
pub fn Location::page_numbering(
  self : Location,
  engine : Engine,
  span : @syntax.Span,
) -> Numbering? {
  engine.introspect(page_numbering_introspection(self, span))
}

///|
/// Returns a dictionary with the page number and the x, y position for this
/// location.
fn impl_location_position(
  self_ : Location,
  engine : Engine,
  span : @syntax.Span,
) -> Dict? raise HintedError {
  engine
  .introspect(position_introspection(self_, span))
  .bind(DocumentPosition::into_dict)
}

///|
/// The location of the content. This is only available on content returned
/// by @query or provided by a @reference:styling:show-rules[show rule], for
/// other content it will be `{none}`.
fn impl_content_location(self_ : Content) -> Location? raise HintedError {
  self_.location()
}

///|
/// Retrieves the exact position of an element in the document (upstream
/// `PositionIntrospection`).
pub fn position_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[DocumentPosition?] {
  Introspect::new(
    // A location that is not part of the document has no position. This
    // notably includes every location in the first iteration, before there
    // is a document to introspect.
    (_, introspector) => introspector.position(loc),
    history => {
      format_location_convergence_warning(
        loc,
        span,
        history,
        "positions",
        element => "\{element} position",
        pos => {
          let coord = (v : Abs) => {
            format_float(v.to_pt(), precision=0, false, "pt")
          }
          match pos {
            Some(Paged(pos)) =>
              "page \{pos.page.0} at (\{coord(pos.point.x)}, \{coord(pos.point.y)})"
            Some(Html(pos)) =>
              match pos.details() {
                Some(Frame(point)) => "(\{coord(point.x)}, \{coord(point.y)})"
                _ => "none"
              }
            None => "none"
          }
        },
      )
    },
  )
}

///|
/// Retrieves the number of the page where an element is located (upstream
/// `PageIntrospection`).
pub fn page_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[NonZeroUSize?] {
  Introspect::new((_, introspector) => introspector.page(loc), history => {
    format_location_convergence_warning(
      loc,
      span,
      history,
      "page numbers",
      element => "page number of the \{element}",
      n => {
        match n {
          Some(n) => "page \{n.0}"
          None => "none"
        }
      },
    )
  })
}

///|
/// Retrieves the numbering of the page where an element is located
/// (upstream `PageNumberingIntrospection`).
pub fn page_numbering_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Numbering?] {
  Introspect::new((_, introspector) => introspector.page_numbering(loc), history => {
    format_location_convergence_warning(
      loc,
      span,
      history,
      "numberings",
      element => "numbering of the page on which the \{element} is located",
      numbering => {
        let value : Value = match numbering {
          Some(n) => n.into_value()
          None => None
        }
        "`\{value.repr()}`"
      },
    )
  })
}

///|
/// Retrieves the supplement of the page where an element is located
/// (upstream `PageSupplementIntrospection`).
pub fn page_supplement_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Content] {
  Introspect::new(
    // Maybe returns `None` here instead of empty content if no supplement
    // was specified?
    (_, introspector) => {
      introspector.page_supplement(loc).unwrap_or(Content::empty())
    },
    history => {
      format_location_convergence_warning(
        loc,
        span,
        history,
        "supplements",
        element => "supplement of the page on which the \{element} is located",
        supplement => "`\{supplement.repr()}`",
      )
    },
  )
}

///|
/// Retrieves the file path of the document/asset which has or contains the
/// given location (upstream `PathIntrospection`).
pub fn path_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[@syntax.VirtualPath?] {
  Introspect::new((_, introspector) => introspector.path(loc), history => {
    format_location_convergence_warning(
      loc,
      span,
      history,
      "path",
      element => "path of the document in which the \{element} is located",
      path => {
        let value : Value = match path {
          Some(p) => Str(p.get_with_slash())
          None => None
        }
        "`\{value.repr()}`"
      },
    )
  })
}

///|
/// Retrieves the location of the document in which an element is located
/// (upstream `DocumentIntrospection`).
pub fn document_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Location?] {
  Introspect::new((_, introspector) => introspector.document(loc), history => {
    format_location_convergence_warning(
      loc,
      span,
      history,
      "path",
      element => "document in which the \{element} is located",
      _ => "TODO",
    )
  })
}

///|
/// The warning when an introspection on a [Location] did not converge.
fn[T] format_location_convergence_warning(
  loc : Location,
  span : @syntax.Span,
  history : History[T],
  output_kind_plural : String,
  format_output_kind : (String) -> String,
  format_output : (T) -> String,
) -> SourceDiagnostic {
  let elem = history.final_introspector().query_first(Location(loc))
  let kind = match elem {
    Some(content) => content.elem().name()
    None => "element"
  }
  let what = format_output_kind(kind)
  let diag = SourceDiagnostic::warning_at(span, "\{what} did not stabilize")
  if elem is Some(elem) && !elem.span().is_detached() {
    diag.spanned_hint(
      "\{kind} was created here",
      @syntax.DiagSpan::from_span(elem.span()),
    )
  }
  diag.with_hint(history.hint(output_kind_plural, format_output))
}
