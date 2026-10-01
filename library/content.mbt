// Port of `typst-library/src/foundations/content/mod.rs` (+ raw.rs).
//
// Content is immutable: all modifying operations return new content.

///|
/// A piece of document content.
pub struct Content {
  /// The element.
  elem : Element
  /// Field values by field id (`None` = unset).
  fields : FixedArray[Value?]
  /// The content's span.
  span : @syntax.Span
  /// An optional label attached to the element.
  label : Label?
  /// The element's location which identifies it in the laid-out output.
  location : Location?
  /// Manages the element during realization: bit 0 = prepared, bit n =
  /// guarded against the n-th show rule recipe.
  lifecycle : Array[Int]
}

///|
/// Create content from field values.
pub fn Content::from_fields(
  elem : Element,
  fields : FixedArray[Value?],
) -> Content {
  {
    elem,
    fields,
    span: @syntax.Span::detached(),
    label: None,
    location: None,
    lifecycle: [],
  }
}

///|
/// Create content with the given required field values (in field order),
/// leaving all other fields unset.
pub fn Content::new(
  elem : Element,
  required : ArrayView[(Int, Value)],
) -> Content {
  let fields = FixedArray::make(elem.fields().length(), (None : Value?))
  for pair in required {
    fields[pair.0] = Some(pair.1)
  }
  Content::from_fields(elem, fields)
}

///|
fn Content::with_fields(self : Content, fields : FixedArray[Value?]) -> Content {
  { ..self, fields, }
}

///|
/// Get the element of this content.
pub fn Content::elem(self : Content) -> Element {
  self.elem
}

///|
/// Alias for [Content::elem] (upstream `Content::func`).
pub fn Content::func(self : Content) -> Element {
  self.elem
}

///|
/// Get the span of the content.
pub fn Content::span(self : Content) -> @syntax.Span {
  self.span
}

///|
/// Set the span of the content if it is detached.
pub fn Content::spanned(self : Content, span : @syntax.Span) -> Content {
  if self.span.is_detached() {
    { ..self, span, }
  } else {
    self
  }
}

///|
/// Get the label of the content.
pub fn Content::label(self : Content) -> Label? {
  self.label
}

///|
/// Attach a label to the content.
pub fn Content::labelled(self : Content, label : Label) -> Content {
  { ..self, label: Some(label), }
}

///|
/// Assign a location to the content.
pub fn Content::located(self : Content, loc : Location) -> Content {
  { ..self, location: Some(loc), }
}

///|
/// The location of the content, if any.
pub fn Content::location(self : Content) -> Location? {
  self.location
}

///|
/// Check whether a show rule recipe is disabled.
pub fn Content::is_guarded(self : Content, index : Int) -> Bool {
  self.lifecycle.contains(index)
}

///|
/// Disable a show rule recipe.
pub fn Content::guarded(self : Content, index : Int) -> Content {
  if self.lifecycle.contains(index) {
    self
  } else {
    let lifecycle = self.lifecycle.copy()
    lifecycle.push(index)
    { ..self, lifecycle, }
  }
}

///|
/// Whether this content has already been prepared.
pub fn Content::is_prepared(self : Content) -> Bool {
  self.lifecycle.contains(0)
}

///|
/// Mark this content as prepared.
pub fn Content::mark_prepared(self : Content) -> Content {
  self.guarded(0)
}

///|
/// Whether the content is an instance of the given element.
pub fn Content::is_(self : Content, elem : Element) -> Bool {
  self.elem == elem
}

///|
/// Whether the content's element has the given capability.
pub fn Content::can(self : Content, capability : String) -> Bool {
  self.elem.can(capability)
}

///|
/// The raw stored value of a field by id (no styles).
pub fn Content::field_raw(self : Content, id : Int) -> Value? {
  match self.fields.get(id) {
    Some(v) => v
    None => None
  }
}

///|
/// A copy with a field set to a value.
pub fn Content::with_field(self : Content, id : Int, value : Value) -> Content {
  let fields = self.fields.copy()
  fields[id] = Some(value)
  self.with_fields(fields)
}

///|
/// A copy with a field unset.
pub fn Content::without_field(self : Content, id : Int) -> Content {
  let fields = self.fields.copy()
  fields[id] = None
  self.with_fields(fields)
}

///|
/// Errors when accessing a field.
pub(all) suberror FieldAccessError {
  /// The element has no such field.
  Unknown
  /// The field is not set.
  Unset
} derive(Eq, Debug)

///|
/// Formats the field access error message.
pub fn FieldAccessError::message(
  self : FieldAccessError,
  content : Content,
  field : String,
) -> String {
  let elem_name = content.elem.name()
  match self {
    Unknown => "\{elem_name} does not have field \{repr_str(field)}"
    Unset =>
      "field \{repr_str(field)} in \{elem_name} is not known at this point"
  }
}

///|
/// Formats the field access error message when the default value was not
/// specified.
pub fn FieldAccessError::message_no_default(
  self : FieldAccessError,
  content : Content,
  field : String,
) -> String {
  self.message(content, field) + " and no default was specified"
}

///|
/// Get a field by id, optionally resolving settable fields through styles
/// (upstream `Content::get`).
pub fn Content::get(
  self : Content,
  id : Int,
  styles? : StyleChain,
) -> Value raise FieldAccessError {
  if id == 255 {
    match self.label {
      Some(label) => return Label(label)
      None => ()
    }
  }
  guard self.elem.field(id) is Some(info) else { raise Unknown }
  let stored = self.field_raw(id)
  let value = match styles {
    Some(styles) =>
      match info.kind {
        Settable => Some(styles.get_value_with_local(self.elem, info, stored))
        Ghost => Some(styles.get_value_with_local(self.elem, info, None))
        _ => stored
      }
    None => stored
  }
  match value {
    Some(v) => v.shared()
    None => raise Unset
  }
}

///|
/// Get a field by name (upstream `Content::get_by_name`).
pub fn Content::get_by_name(
  self : Content,
  name : String,
) -> Value raise FieldAccessError {
  if name == "label" {
    match self.label {
      Some(label) => return Label(label)
      None => raise Unknown
    }
  }
  guard self.elem.field_id(name) is Some(id) && self.elem.field(id) is Some(_) else {
    raise Unknown
  }
  match self.field_raw(id) {
    Some(v) => v.shared()
    None => raise Unset
  }
}

///|
/// Get a field by id, returning a string error.
pub fn Content::field(self : Content, id : Int) -> Value raise HintedError {
  self.get(id) catch {
    e =>
      raise HintedError(
        HintedString::new(e.message(self, self.elem.field_name(id).unwrap())),
      )
  }
}

///|
/// Get a field by name, returning a string error.
pub fn Content::field_by_name(
  self : Content,
  name : String,
) -> Value raise HintedError {
  self.get_by_name(name) catch {
    e => raise HintedError(HintedString::new(e.message(self, name)))
  }
}

///|
/// Resolve all fields with the styles and save them in-place (returns the
/// materialized copy).
pub fn Content::materialize(self : Content, styles : StyleChain) -> Content {
  let fields = self.fields.copy()
  // Like upstream, this includes internal settable fields.
  for info in self.elem.fields() {
    if info.kind is Settable && fields[info.id] is None {
      fields[info.id] = Some(styles.get_value_with_local(self.elem, info, None))
    }
  }
  self.with_fields(fields)
}

///|
/// Whether the content has the given field (upstream `Content::has`).
pub fn Content::has(self : Content, field : String) -> Bool {
  if field == "label" {
    return self.label is Some(_)
  }
  guard self.elem.field_id(field) is Some(id) &&
    self.elem.field(id) is Some(info) else {
    return false
  }
  match info.kind {
    Required => true
    Synthesized | Settable => self.field_raw(id) is Some(_)
    Ghost | External => false
  }
}

///|
/// The fields of the content as a dictionary (upstream `Content::fields`).
pub fn Content::fields(self : Content) -> Dict {
  let dict = Dict::new()
  for info in self.elem.fields() {
    if info.internal {
      continue
    }
    match self.field_raw(info.id) {
      Some(v) if info.kind is (Required | Synthesized | Settable) =>
        dict.insert(info.name, v.shared())
      _ => ()
    }
  }
  if self.label is Some(label) {
    dict.insert("label", Label(label))
  }
  dict
}

///|
/// Upstream `Repr for Content`.
pub fn Content::repr(self : Content) -> String {
  match self.elem.hooks().repr {
    Some(f) => f(self)
    None => {
      let fields = []
      for info in self.elem.fields() {
        if info.internal {
          continue
        }
        match self.field_raw(info.id) {
          Some(v) if info.kind is (Required | Synthesized | Settable) =>
            fields.push("\{info.name}: \{v.repr()}")
          _ => ()
        }
      }
      self.elem.name() + pretty_array_like(fields, false)
    }
  }
}

///|
/// Upstream `PartialEq for Content`: same element and equal fields
/// (synthesized, ghost and external fields are ignored).
pub impl Eq for Content with fn equal(self, other) {
  if self.elem != other.elem {
    return false
  }
  match self.elem.hooks().eq {
    Some(f) => f(self, other)
    None => {
      for info in self.elem.fields() {
        if info.internal {
          continue
        }
        match info.kind {
          Required | Settable => {
            let a = self.field_raw(info.id)
            let b = other.field_raw(info.id)
            match (a, b) {
              (None, None) => ()
              (Some(x), Some(y)) => if x != y { return false }
              _ => return false
            }
          }
          _ => ()
        }
      }
      true
    }
  }
}

///|
/// Create empty content.
pub fn Content::empty() -> Content {
  Content::new(sequence_elem(), [(0, Array(Arr::new()))])
}

///|
/// Create a new sequence element from multiple elements.
pub fn Content::sequence(children : ArrayView[Content]) -> Content {
  if children.length() == 0 {
    Content::empty()
  } else if children.length() == 1 {
    children[0]
  } else {
    SequenceElem::new(children.to_array())
  }
}

///|
/// Whether the content is an empty sequence.
pub fn Content::is_empty(self : Content) -> Bool {
  match self.to_sequence() {
    Some(children) => children.is_empty()
    None => false
  }
}

///|
/// The children if this is a sequence.
pub fn Content::to_sequence(self : Content) -> Array[Content]? {
  if self.elem == sequence_elem() {
    Some(SequenceElem::children(self))
  } else {
    None
  }
}

///|
/// Also auto expands sequence of sequences into flat sequence.
pub fn Content::sequence_recursive_for_each(
  self : Content,
  f : (Content) -> Unit,
) -> Unit {
  match self.to_sequence() {
    Some(children) =>
      for child in children {
        child.sequence_recursive_for_each(f)
      }
    None => f(self)
  }
}

///|
/// Style this content with a style entry.
pub fn Content::styled(self : Content, style : Style) -> Content {
  if self.elem == styled_elem() {
    let styles = StyledElem::styles(self).copy()
    styles.apply_one(style)
    self.with_field(1, Styles(styles))
  } else {
    self.styled_with_map(Styles::from_array([style]))
  }
}

///|
/// Style this content with a full style map.
pub fn Content::styled_with_map(self : Content, styles : Styles) -> Content {
  if styles.is_empty() {
    return self
  }
  if self.elem == styled_elem() {
    let merged = StyledElem::styles(self).copy()
    merged.apply(styles)
    self.with_field(1, Styles(merged))
  } else {
    StyledElem::new(self, styles)
  }
}

///|
/// Repeat this content `count` times.
pub fn Content::repeat(self : Content, count : Int) -> Content {
  Content::sequence(Array::make(count, self))
}

///|
/// Concatenate two pieces of content (upstream `Add for Content`).
pub fn Content::add(self : Content, rhs : Content) -> Content {
  match (self.to_sequence(), rhs.to_sequence()) {
    (Some(lhs), Some(rhs_children)) =>
      SequenceElem::new(lhs + rhs_children).spanned(self.span)
    (Some(lhs), None) => {
      let children = lhs.copy()
      children.push(rhs)
      { ..SequenceElem::new(children), span: self.span, }
    }
    (None, Some(rhs_children)) => {
      let children = [self]
      children.append(rhs_children)
      { ..SequenceElem::new(children), span: rhs.span, }
    }
    (None, None) => Content::sequence([self, rhs])
  }
}

///|
/// Traverse this content and all nested content (via fields).
pub fn Content::traverse(self : Content, f : (Content) -> Bool) -> Bool {
  fn walk_value(value : Value, f : (Content) -> Bool) -> Bool {
    match value {
      Content(content) => content.traverse(f)
      Array(array) => {
        for v in array.items {
          if !walk_value(v, f) {
            return false
          }
        }
        true
      }
      _ => true
    }
  }

  if !f(self) {
    return false
  }
  for _, value in self.fields().map {
    if !walk_value(value, f) {
      return false
    }
  }
  true
}

///|
/// Extracts the plain text of this content.
pub fn Content::plain_text(self : Content) -> String {
  let buf = StringBuilder()
  self.traverse(element => {
    if element.elem.hooks().plain_text is Some(f) {
      f(element, buf)
    }
    true
  })
  |> ignore
  buf.to_string()
}

// Foundational elements: sequence and styled.

///|
let sequence_elem_cell : Ref[Element?] = Ref::new(None)

///|
/// A sequence of content.
pub fn sequence_elem() -> Element {
  match sequence_elem_cell.val {
    Some(e) => e
    None => {
      let elem = Element::new(name="sequence", title="Sequence", fields=[
        field_of(
          (Ty::new() : Ty[Array[Content]]),
          id=0,
          name="children",
          kind=Required,
          required=true,
        ),
      ])
      sequence_elem_cell.val = Some(elem)
      elem.hooks().repr = Some(c => {
        let children = SequenceElem::children(c)
        if children.is_empty() {
          "[]"
        } else {
          "sequence" + pretty_array_like(children.map(c => c.repr()), false)
        }
      })
      elem
    }
  }
}

///|
/// Typed view of `sequence` content.
pub struct SequenceElem(Content)

///|
pub fn SequenceElem::new(children : Array[Content]) -> Content {
  Content::new(sequence_elem(), [
    (0, Array(Arr::from_array(children.map(c => Content(c))))),
  ])
}

///|
/// The children of a sequence.
pub fn SequenceElem::children(c : Content) -> Array[Content] {
  match c.field_raw(0) {
    Some(Array(a)) =>
      a.items.map(v => {
        match v {
          Content(c) => c
          _ => Content::empty()
        }
      })
    _ => []
  }
}

///|
let styled_elem_cell : Ref[Element?] = Ref::new(None)

///|
/// Content alongside styles.
pub fn styled_elem() -> Element {
  match styled_elem_cell.val {
    Some(e) => e
    None => {
      let elem = Element::new(name="styled", title="Styled", fields=[
        field_of(
          (Ty::new() : Ty[Content]),
          id=0,
          name="child",
          kind=Required,
          required=true,
        ),
        field_of(
          (Ty::new() : Ty[Styles]),
          id=1,
          name="styles",
          kind=Required,
          required=true,
        ),
      ])
      styled_elem_cell.val = Some(elem)
      elem.hooks().repr = Some(c => {
        "styled(child: \{StyledElem::child(c).repr()}, ..)"
      })
      elem.hooks().eq = Some((a, b) => {
        StyledElem::child(a) == StyledElem::child(b)
      })
      elem
    }
  }
}

///|
/// Typed view of `styled` content.
pub struct StyledElem(Content)

///|
pub fn StyledElem::new(child : Content, styles : Styles) -> Content {
  Content::new(styled_elem(), [(0, Content(child)), (1, Styles(styles))])
}

///|
/// The styled content.
pub fn StyledElem::child(c : Content) -> Content {
  match c.field_raw(0) {
    Some(Content(c)) => c
    _ => Content::empty()
  }
}

///|
/// The styles.
pub fn StyledElem::styles(c : Content) -> Styles {
  match c.field_raw(1) {
    Some(Styles(s)) => s
    _ => Styles::new()
  }
}
