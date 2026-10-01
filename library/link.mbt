// Port of the runtime parts of `typst-library/src/model/link.rs`: link
// targets and destinations, link resolution and anchor generation. (The
// `LinkElem` definition is generated; its field casts are in
// `elem_parse.mbt`.)

///|
/// A target where a link can go.
pub(all) enum LinkTarget {
  Dest(Destination)
  Label(Label)
} derive(Eq)

///|
/// A link destination.
pub(all) enum Destination {
  /// A link to a URL.
  Url(String)
  /// A link to a point on a page.
  Position(PagedPosition)
  /// An unresolved link to a location in the document.
  Location(Location)
} derive(Eq)

///|
/// View a stored (already cast) link target value as a [LinkTarget].
pub fn LinkTarget::of_value(value : Value) -> LinkTarget {
  match value {
    Label(label) => Label(label)
    v => Dest(Destination::of_value(v))
  }
}

///|
pub impl IntoValue for LinkTarget with fn into_value(self) {
  match self {
    Dest(dest) => dest.into_value()
    Label(label) => Label(label)
  }
}

///|
/// View a stored (already cast) destination value as a [Destination].
pub fn Destination::of_value(value : Value) -> Destination {
  match value {
    Str(url) => Url(url)
    Dyn(Location(loc)) => Location(loc)
    Dict(_) as v =>
      Position(
        PagedPosition::from_value(v) catch {
          _ => abort("link destination holds an invalid position")
        },
      )
    v => abort("link destination holds an unexpected value: \{v.repr()}")
  }
}

///|
pub impl IntoValue for Destination with fn into_value(self) {
  match self {
    Url(url) => Str(url)
    Position(pos) => pos.into_value()
    Location(loc) => Dyn(Location(loc))
  }
}

///|
/// Resolves the destination.
pub fn LinkTarget::resolve_early(
  self : LinkTarget,
  engine : Engine,
  span : @syntax.Span,
) -> Destination raise SourceError {
  match self {
    Dest(dest) => dest
    Label(label) => {
      let elem = match
        engine.introspect(query_label_introspection(label, span)) {
        Ok(elem) => elem
        Err(err) => raise SourceError([err.into_error_at(span)])
      }
      Location(elem.location().unwrap())
    }
  }
}

///|
/// Resolves the destination without an engine.
pub fn LinkTarget::resolve_late(
  self : LinkTarget,
  introspector : &IntrospectorBackend,
) -> Destination raise HintedError {
  match self {
    Dest(dest) => dest
    Label(label) => {
      let elem = introspector.query_label(label)
      Location(elem.location().unwrap())
    }
  }
}

///|
/// The typed destination of a link (upstream `elem.dest`).
pub fn LinkElem::target(self : LinkElem) -> LinkTarget {
  LinkTarget::of_value(self.dest())
}

///|
/// Finds all linked-to locations referenced in an introspector.
pub fn LinkElem::find_destinations(
  introspector : &IntrospectorBackend,
) -> Array[Location] {
  let out = []
  for elem in introspector.query(link_elem().select()) {
    let elem = LinkElem(elem)
    try elem.target().resolve_late(introspector) catch {
      _ => ()
    } noraise {
      Location(loc) => out.push(loc)
      _ => ()
    }
  }
  out
}

///|
/// Creates unique IDs for elements.
pub struct AnchorGenerator {
  priv introspector : &IntrospectorBackend
  priv mut loc_counter : Int
  priv label_counter : Map[Label, Int]
}

///|
/// Creates a new identificator.
pub fn AnchorGenerator::new(
  introspector : &IntrospectorBackend,
) -> AnchorGenerator {
  { introspector, loc_counter: 0, label_counter: {}, }
}

///|
/// Returns a reference to the underlying introspector.
pub fn AnchorGenerator::introspector(
  self : AnchorGenerator,
) -> &IntrospectorBackend {
  self.introspector
}

///|
/// Generates an ID, potentially based on a label.
pub fn AnchorGenerator::identify(
  self : AnchorGenerator,
  label : Label?,
) -> String {
  if label is Some(label) {
    let text = label.resolve()
    if can_use_label_as_id(text) {
      if self.introspector.label_count(label) == 1 {
        return text
      }
      let counter = self.label_counter.get(label).unwrap_or(0) + 1
      let (id, counter) = disambiguate(self.introspector, text, counter)
      self.label_counter[label] = counter
      return id
    }
  }
  let (id, counter) = disambiguate(
    self.introspector,
    "loc",
    self.loc_counter + 1,
  )
  self.loc_counter = counter
  id
}

///|
/// Whether the label is both a valid CSS identifier and a valid URL fragment
/// for linking.
///
/// This is slightly more restrictive than HTML and CSS, but easier to
/// understand and explain.
fn can_use_label_as_id(label : String) -> Bool {
  guard label.get_char(0) is Some(first) else { return false }
  label.iter().all(c => @unicode.is_alphanumeric(c) || c is ('-' | '_')) &&
  !(@unicode.is_numeric(first) || first == '-')
}

///|
/// Disambiguates `text` with the suffix `-{counter}`, while ensuring that this
/// does not result in a collision with an existing label. Returns the
/// disambiguated text and the final counter.
fn disambiguate(
  introspector : &IntrospectorBackend,
  text : String,
  counter : Int,
) -> (String, Int) {
  let mut counter = counter
  while true {
    let disambiguated = "\{text}-\{counter}"
    if Label::new(disambiguated) is Some(label) &&
      introspector.label_count(label) > 0 {
      counter += 1
    } else {
      return (disambiguated, counter)
    }
  }
  abort("unreachable")
}

///|
/// Resolves location links during compilation.
///
/// This is used in HTML export as there isn't a dedicated export stage that
/// could make use of the `LateLinkResolver`. There is the HTML serialization,
/// but that's not an appropriate stage for meaningful DOM manipulation.
pub struct EarlyLinkResolver {
  priv base : Location
  priv span : @syntax.Span
}

///|
/// Creates a resolver that resolves links relatively to the element with the
/// given location.
pub fn EarlyLinkResolver::new(
  base : Location,
  span : @syntax.Span,
) -> EarlyLinkResolver {
  { base, span, }
}

///|
/// Resolves a link to the given location.
pub fn EarlyLinkResolver::resolve(
  self : EarlyLinkResolver,
  engine : Engine,
  location : Location,
) -> ResolvedLink raise HintedError {
  let from = engine.introspect(path_introspection(self.base, self.span))
  let to = engine.introspect(path_introspection(location, self.span))
  guard engine.introspect(link_anchor_introspection(location, self.span))
    is Some(anchor) else {
    bail("failed to determine link anchor")
  }
  match (from, to) {
    // This is the normal case in single file export.
    (None, None) => Local(anchor~)
    // This is the normal case in bundle export.
    (Some(from), Some(to)) =>
      if from == to {
        Local(anchor~)
      } else {
        Cross(from~, to~, anchor~)
      }
    // This can, for instance, happen when trying to link to metadata that
    // is not within a document (top-level in the bundle).
    (Some(_), None) => bail("link destination is not within a document")
    // This is rather unlikely because we can't resolve a link rule in a
    // non-file. It could happen in a non-convergent case.
    (None, Some(_)) => bail("failed to resolve cross-link")
  }
}

///|
/// A resolved internal link.
pub(all) enum ResolvedLink {
  /// Should link to an anchor in the same document. If the anchor is empty,
  /// should link to the full current document.
  Local(anchor~ : String)
  /// Should link to an anchor in another document: `from` is the path of
  /// the file containing the link, `to` the path of the linked-to file. If
  /// the anchor is empty, should link to the full document.
  Cross(
    from~ : @syntax.VirtualPath,
    to~ : @syntax.VirtualPath,
    anchor~ : String
  )
} derive(Eq)

///|
/// Turns the link into a relative URI, potentially with an `#` anchor
/// fragment.
///
/// This will percent-encode characters in relative paths if necessary.
/// Anchor fragments are guaranteed to be URI-compatible so they are not
/// encoded.
pub fn ResolvedLink::into_relative_uri(
  self : ResolvedLink,
) -> String raise HintedError {
  match self {
    // Still write the empty anchor if linking to the document itself
    // because `#` doesn't trigger a reload unlike an empty href.
    Local(anchor~) => "#\{anchor}"
    Cross(from~, to~, anchor~) => {
      guard from.parent() is Some(parent) else {
        // For this to happen, `src` would have to be `/`, which is not
        // allowed.
        bail("containing document has invalid path")
      }
      let relative_path = to.relative_from(parent)
      let encoded = percent_encode_path(relative_path)
      if anchor.is_empty() {
        // Don't write a trailing `#` if linking to a full document.
        encoded
      } else {
        "\{encoded}#\{anchor}"
      }
    }
  }
}

///|
/// Cross-bundle relative paths may contain characters that are not safe to
/// use in URIs. This function encodes them with percent encoding.
///
/// Everything except ASCII alphanumerics and `-._~/` is percent-encoded
/// (byte-wise in UTF-8).
fn percent_encode_path(relative_path : String) -> String {
  let buf = StringBuilder()
  let bytes = @utf8.encode(relative_path)
  for b in bytes {
    let c = b.to_int()
    if (c >= 'a'.to_int() && c <= 'z'.to_int()) ||
      (c >= 'A'.to_int() && c <= 'Z'.to_int()) ||
      (c >= '0'.to_int() && c <= '9'.to_int()) ||
      c is (0x2D | 0x2E | 0x5F | 0x7E | 0x2F) {
      buf.write_char(c.unsafe_to_char())
    } else {
      let hex = "0123456789ABCDEF"
      buf.write_char('%')
      buf.write_char(hex.get_char(c >> 4).unwrap())
      buf.write_char(hex.get_char(c & 0xF).unwrap())
    }
  }
  buf.to_string()
}

///|
/// Resolves the anchor to reach the linked-to element with the given location
/// (upstream `LinkAnchorIntrospection`).
pub fn link_anchor_introspection(
  loc : Location,
  span : @syntax.Span,
) -> Introspect[String?] {
  Introspect::new((_, introspector) => introspector.anchor(loc), history => {
    let introspector = history.final_introspector()
    let what = match introspector.query_first(Location(loc)) {
      Some(content) => content.elem().name()
      None => "element"
    }
    SourceDiagnostic::warning_at(
      span,
      "link anchor assigned to the destination \{what} did not stabilize",
    ).with_hint(
      history.hint("anchors", id => {
        match id {
          Some(id) => id
          None => "(no anchor)"
        }
      }),
    )
  })
}
