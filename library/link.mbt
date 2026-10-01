// Port of the link target types of `typst-library/src/model/link.rs`
// (`LinkTarget`, `Destination`, `Url`) and the `LinkElem` field hooks.

///|
/// `#[parse]` of `LinkElem::dest`.
fn link_elem_dest_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let dest : LinkTarget = args.expect("destination")
  let value = dest.into_value()
  locals.set("dest", Some(value))
  Some(value)
}

///|
/// `#[parse]` of `LinkElem::body`.
fn link_elem_body_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  // A `Str` destination is always a `LinkTarget::Dest(Destination::Url(..))`.
  match locals.get("dest") {
    Some(Str(url)) =>
      match args.eat() {
        Some(body) => Some(Content(body))
        None => Some(Content(body_from_url(Url(url))))
      }
    _ => Some(Content(args.expect("body")))
  }
}

///|
fn body_from_url(url : Url) -> Content {
  let stripped = url.strip_contact_scheme().map(pair => pair.1)
  TextElem::packed(stripped.unwrap_or(url.0))
}

///|
/// A target where a link can go.
pub(all) enum LinkTarget {
  Dest(Destination)
  Label(Label)
} derive(Eq)

///|
pub impl Reflect for LinkTarget with fn input() {
  Destination::input().union_with(input_of((Ty::new() : Ty[Label])))
}

///|
pub impl Reflect for LinkTarget with fn output() {
  Destination::output().union_with(output_of((Ty::new() : Ty[Label])))
}

///|
pub impl Reflect for LinkTarget with fn castable(v) {
  Destination::castable(v) || castable_of((Ty::new() : Ty[Label]), v)
}

///|
pub impl IntoValue for LinkTarget with fn into_value(self) {
  match self {
    Dest(v) => v.into_value()
    Label(v) => IntoValue::into_value(v)
  }
}

///|
pub impl FromValue for LinkTarget with fn from_value(v) {
  if Destination::castable(v) {
    Dest(Destination::from_value(v))
  } else if castable_of((Ty::new() : Ty[Label]), v) {
    Label(v.cast())
  } else {
    raise HintedError(LinkTarget::input().error(v))
  }
}

///|
/// A link destination.
pub(all) enum Destination {
  /// A link to a URL.
  Url(Url)
  /// A link to a point on a page.
  Position(PagedPosition)
  /// An unresolved link to a location in the document.
  Location(Location)
} derive(Eq)

///|
pub impl Reflect for Destination with fn input() {
  Url::input()
  .union_with(PagedPosition::input())
  .union_with(input_of((Ty::new() : Ty[Location])))
}

///|
pub impl Reflect for Destination with fn output() {
  Url::output()
  .union_with(PagedPosition::output())
  .union_with(output_of((Ty::new() : Ty[Location])))
}

///|
pub impl Reflect for Destination with fn castable(v) {
  Url::castable(v) ||
  PagedPosition::castable(v) ||
  castable_of((Ty::new() : Ty[Location]), v)
}

///|
pub impl IntoValue for Destination with fn into_value(self) {
  match self {
    Url(v) => v.into_value()
    Position(v) => v.into_value()
    Location(v) => IntoValue::into_value(v)
  }
}

///|
pub impl FromValue for Destination with fn from_value(v) {
  if Url::castable(v) {
    Url(Url::from_value(v))
  } else if PagedPosition::castable(v) {
    Position(PagedPosition::from_value(v))
  } else if castable_of((Ty::new() : Ty[Location]), v) {
    Location(v.cast())
  } else {
    raise HintedError(Destination::input().error(v))
  }
}

///|
/// A uniform resource locator with a maximum length.
pub(all) struct Url(String) derive(Eq, Hash, Compare)

///|
/// Create a URL from a string, checking the maximum length.
pub fn Url::new(url : String) -> Url raise HintedError {
  if @syntax.utf8_len(url) > 8000 {
    bail("URL is too long")
  } else if url.is_empty() {
    bail("URL must not be empty")
  }
  Url(url)
}

///|
/// Extract the underlying string.
pub fn Url::into_inner(self : Url) -> String {
  self.0
}

///|
/// Strips a `mailto:` or `tel:` scheme.
pub fn Url::strip_contact_scheme(self : Url) -> (UrlContactScheme, String)? {
  for scheme in [UrlContactScheme::Mailto, UrlContactScheme::Tel] {
    let prefix = scheme.as_str()
    if self.0.has_prefix(prefix) {
      return Some(
        (
          scheme,
          self.0.unsafe_substring(start=prefix.length(), end=self.0.length()),
        ),
      )
    }
  }
  None
}

///|
pub impl Reflect for Url with fn input() {
  input_of((Ty::new() : Ty[String]))
}

///|
pub impl Reflect for Url with fn output() {
  output_of((Ty::new() : Ty[String]))
}

///|
pub impl Reflect for Url with fn castable(v) {
  castable_of((Ty::new() : Ty[String]), v)
}

///|
pub impl IntoValue for Url with fn into_value(self) {
  Str(self.0)
}

///|
pub impl FromValue for Url with fn from_value(v) {
  Url::new(FromValue::from_value(v))
}

///|
/// A contact scheme of a URL.
pub(all) enum UrlContactScheme {
  /// The `mailto:` prefix.
  Mailto
  /// The `tel:` prefix.
  Tel
} derive(Eq, Hash)

///|
pub fn UrlContactScheme::as_str(self : UrlContactScheme) -> String {
  match self {
    Mailto => "mailto:"
    Tel => "tel:"
  }
}
