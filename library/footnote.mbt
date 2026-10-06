// Port of the castable value types of `typst-library/src/model/footnote.rs`
// (`FootnoteBody`, `Packed<FootnoteElem>`).

///|
/// The body of a footnote can be either some content or a label referencing
/// another footnote.
pub(all) enum FootnoteBody {
  Content(Content)
  Reference(Label)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FootnoteBody with Eq::{not_equal, equal}

///|
pub impl Reflect for FootnoteBody with fn input() {
  Content::input().union_with(Type(Type::label()))
}

///|
pub impl Reflect for FootnoteBody with fn output() {
  FootnoteBody::input()
}

///|
pub impl Reflect for FootnoteBody with fn castable(v) {
  Content::castable(v) || v is Label(_)
}

///|
pub extend FootnoteBody with Reflect::{output, input, castable}

///|
pub impl IntoValue for FootnoteBody with fn into_value(self) {
  match self {
    Content(v) => Content(v)
    Reference(v) => Label(v)
  }
}

///|
pub extend FootnoteBody with IntoValue::{into_value}

///|
pub impl FromValue for FootnoteBody with fn from_value(v) {
  if Content::castable(v) {
    return Content(Content::from_value(v))
  }
  match v {
    Label(label) => Reference(label)
    v => raise HintedError(FootnoteBody::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FootnoteBody with FromValue::{from_value}

///|
/// A footnote (upstream `Packed<FootnoteElem>`).
pub(all) struct FootnoteElem(Content) derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FootnoteElem with Eq::{not_equal, equal}

///|
/// Creates a new footnote that the passed content as its body.
pub fn FootnoteElem::with_content(content : Content) -> FootnoteElem {
  FootnoteElem(
    Content::new(footnote_elem(), [(footnote_elem_body, Content(content))]),
  )
}

///|
pub impl Reflect for FootnoteElem with fn input() {
  Content::input()
}

///|
pub impl Reflect for FootnoteElem with fn output() {
  Content::output()
}

///|
pub impl Reflect for FootnoteElem with fn castable(v) {
  Content::castable(v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FootnoteElem with Reflect::{output, input, castable}

///|
pub impl IntoValue for FootnoteElem with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FootnoteElem with IntoValue::{into_value}

///|
pub impl FromValue for FootnoteElem with fn from_value(v) {
  // Upstream `Packed<T>::from_value` with `v.unpack::<Self>()
  // .unwrap_or_else(Self::with_content)`.
  let content : Content = FromValue::from_value(v)
  if content.is_(footnote_elem()) {
    return FootnoteElem(content)
  }
  let span = if v is Content(_) {
    content.span()
  } else {
    @syntax.Span::detached()
  }
  FootnoteElem(FootnoteElem::with_content(content).0.spanned(span))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FootnoteElem with FromValue::{from_value}

///|
/// The alternative text of a footnote number: the footnote's local name
/// followed by the number.
pub fn FootnoteElem::alt_text(styles : StyleChain, num : String) -> String {
  let local_name = footnote_elem().local_name_in(styles)
  "\{local_name} \{num}"
}

///|
/// Creates a new footnote referencing the footnote with the specified label,
/// with the other fields from the current footnote cloned.
pub fn FootnoteElem::into_ref(
  self : FootnoteElem,
  label : Label,
) -> FootnoteElem {
  // Only the fields are cloned (upstream clones the unpacked element), not
  // the span, label, location or lifecycle.
  let fields = self.0.fields.copy()
  fields[footnote_elem_body] = Some(FootnoteBody::Reference(label).into_value())
  FootnoteElem(Content::from_fields(footnote_elem(), fields))
}

///|
/// Tests if this footnote is a reference to another footnote.
pub fn FootnoteElem::is_ref(self : FootnoteElem) -> Bool {
  self.body() is Reference(_)
}

///|
/// Returns the content of the body of this footnote if it is not a ref.
pub fn FootnoteElem::body_content(self : FootnoteElem) -> Content? {
  match self.body() {
    Content(content) => Some(content)
    Reference(_) => None
  }
}

///|
/// Returns the content that holds the number and links to the footnote
/// entry.
pub fn FootnoteElem::realize(
  self : FootnoteElem,
  engine : Engine,
  styles : StyleChain,
) -> Content raise SourceError {
  let span = self.0.span()
  let loc = at(span, () => self.declaration_location(engine))
  let numbering = self.numbering(styles)
  let counter = Counter::of(footnote_elem())
  let num = counter.display_at(engine, loc, styles, numbering, span)
  let alt = FootnoteElem::alt_text(styles, num.plain_text())
  let dest = loc.variant(1)
  DirectLinkElem::new(dest, num, Some(alt)).pack().spanned(span)
}

///|
/// Returns the location of the definition of this footnote.
pub fn FootnoteElem::declaration_location(
  self : FootnoteElem,
  engine : Engine,
) -> Location raise HintedError {
  match self.body() {
    Reference(label) => {
      let element = match
        engine.introspect(query_label_introspection(label, self.0.span())) {
        Ok(element) => element
        Err(err) => raise HintedError(err)
      }
      guard element.is_(footnote_elem()) else {
        bail("referenced element should be a footnote")
      }
      let footnote = FootnoteElem(element)
      if self.0.location() == footnote.0.location() {
        bail("footnote cannot reference itself")
      }
      footnote.declaration_location(engine)
    }
    Content(_) => self.0.location().unwrap()
  }
}

///|
/// Returns the content of the superscript that holds the number and links
/// back to the footnote, and the entry body.
pub fn FootnoteEntry::realize(
  self : FootnoteEntry,
  engine : Engine,
  styles : StyleChain,
) -> (Content, Content) raise SourceError {
  let span = self.0.span()
  let note = self.note()
  let numbering = note.numbering(StyleChain::empty())
  let counter = Counter::of(footnote_elem())
  guard note.0.location() is Some(dest) else {
    bail_at(span, "footnote entry must have a location", hints=[
      "try using a query or a show rule to customize the footnote instead",
    ])
  }
  let num = counter.display_at(engine, dest, styles, numbering, span)
  let alt = num.plain_text()
  let link = DirectLinkElem::new(dest, num, Some(alt)).pack().spanned(span)
  let sup = SuperElem::new(link).pack().spanned(span)
  let body = note.body_content().unwrap()
  (sup, body)
}

///|
/// Upstream `ShowSet for Packed<FootnoteEntry>`.
fn footnote_entry_elem_show_set(
  _content : Content,
  _styles : StyleChain,
) -> Styles {
  let out = Styles::new()
  out.push(ParElem::set_leading(Length::from_em(Em::new(0.5))))
  out.push(TextElem::set_size(TextSize(Length::from_em(Em::new(0.85)))))
  out
}

///|
/// Upstream `LocalName for Packed<FootnoteElem>`.
fn footnote_elem_local_name_key() -> String {
  "footnote"
}

///|
/// The default separator of footnote entries (FootnoteEntry.separator).
fn footnote_entry_elem_separator_default() -> Value {
  LineElem::new()
  .with_length(Rel::from_ratio(Ratio::new(0.3)))
  .with_stroke({
    ..Stroke::default(),
    thickness: Custom(Length::from_em(Em::new(0.05))),
  })
  .pack()
  .into_value()
}
