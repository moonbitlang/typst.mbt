// Port of upstream `Dynamic` (`typst-library/src/foundations/value.rs`).
//
// Upstream stores native types that have no dedicated `Value` variant behind
// a type-erased `Dynamic` and downcasts it where needed. MoonBit has no
// downcasting, so the dynamic types are a closed enum. Each payload type is
// owned by its module port and must provide `repr`, `Eq` and the per-type
// hooks dispatched below.

///|
/// Internal native values stored in `Value::Dyn` (upstream `Dynamic`).
pub(all) enum DynValue {
  /// `layout/align.rs`
  Alignment(Alignment)
  /// `layout/dir.rs`
  Dir(Dir)
  /// `foundations/str.rs`
  Regex(Regex)
  /// `visualize/color.rs`
  SpotColorant(SpotColorant)
  /// `visualize/stroke.rs`
  Stroke(Stroke)
  /// `introspection/counter.rs`
  Counter(Counter)
  /// `introspection/state.rs`
  State(State)
  /// `introspection/location.rs`
  Location(Location)
  /// `foundations/selector.rs`
  Selector(Selector)
  /// `foundations/path.rs`
  RootedPath(RootedPath)
  /// `introspection/counter.rs` (internal: the `update` field of counter
  /// updates)
  CounterUpdate(CounterUpdate)
  /// `introspection/state.rs` (internal: the `update` field of state
  /// updates)
  StateUpdate(StateUpdate)
  /// `introspection/tag.rs` (internal: the `tag` field of tag elements)
  Tag(Tag)
  /// `typst-html/src/css/encode.rs` (internal: the `css` field of HTML
  /// elements)
  HtmlCss(CssProperties)
  /// `layout/grid/resolve.rs` (internal: the synthesized `grid` field of
  /// grids and tables)
  CellGrid(CellGrid)
  /// `layout/container.rs` (internal: the callback bodies of inline and
  /// block elements, cast to `auto` upstream)
  InlineCallback(InlineCallback)
  BlockSingleCallback(BlockSingleCallback)
  BlockMultiCallback(BlockMultiCallback)
  /// `text/deco.rs` (internal: the values of `TextElem::deco`)
  Decoration(Decoration)
  /// The loaded data of a `Derived` field (stored in its generated internal
  /// `<field>-derived` companion field; upstream `Derived::derived`).
  Loaded(Loaded)
  /// `text/raw.rs` (internal: the `text` field of raw elements that the
  /// evaluator created from the lines of raw syntax, upstream
  /// `RawContent::Lines`; see `RawContent`)
  RawContent(RawContent)
} derive(Eq)

///|
/// The type of the dynamic value.
pub fn DynValue::ty(self : DynValue) -> Type {
  match self {
    Alignment(_) => Type::alignment()
    Dir(_) => Type::direction()
    Regex(_) => Type::regex()
    SpotColorant(_) => Type::spot()
    Stroke(_) => Type::stroke()
    Counter(_) => Type::counter()
    State(_) => Type::state()
    Location(_) => Type::location()
    Selector(_) => Type::selector()
    RootedPath(_) => Type::path()
    // Internal values that are never exposed to users.
    CounterUpdate(_) => Type::counter()
    StateUpdate(_) => Type::state()
    Tag(_) => Type::content()
    // Upstream's `css::Properties` has no Typst type; it is only stored in
    // an internal field.
    HtmlCss(_) => Type::dict()
    // Upstream's `CellGrid` has no Typst type; it is only stored in an
    // internal field.
    CellGrid(_) => Type::content()
    // Upstream casts layout callbacks to `auto`.
    InlineCallback(_) | BlockSingleCallback(_) | BlockMultiCallback(_) =>
      Type::auto()
    // Upstream's `Decoration` has no Typst type; it is only stored in an
    // internal style property.
    Decoration(_) => Type::content()
    Loaded(_) => Type::bytes()
    // Upstream casts `RawContent` to its string; it is only stored in the
    // `text` field of raw elements.
    RawContent(_) => Type::str()
  }
}

///|
/// The repr of the dynamic value.
pub fn DynValue::repr(self : DynValue) -> String {
  match self {
    Alignment(v) => v.repr()
    Dir(v) => v.repr()
    Regex(v) => v.repr()
    SpotColorant(v) => v.repr()
    Stroke(v) => v.repr()
    Counter(v) => v.repr()
    State(v) => v.repr()
    Location(v) => v.repr()
    Selector(v) => v.repr()
    RootedPath(v) => repr_rooted_path(v)
    CounterUpdate(_) => "counter.update(..)"
    StateUpdate(_) => "state.update(..)"
    Tag(tag) => tag.to_string()
    HtmlCss(p) => "css(\{repr_str(p.to_inline())})"
    CellGrid(_) => "cellgrid(..)"
    InlineCallback(_) | BlockSingleCallback(_) | BlockMultiCallback(_) => "auto"
    Decoration(_) => "decoration(..)"
    Loaded(_) => "loaded(..)"
    RawContent(v) => repr_str(v.get())
  }
}

///|
/// Whether this is an alignment (upstream `d.is::<Alignment>()`).
pub fn DynValue::is_alignment(self : DynValue) -> Bool {
  self is Alignment(_)
}

///|
/// Add two dynamic values (upstream: only alignments can be summed).
/// Returns `None` if they cannot be added.
pub fn DynValue::add_dyn(
  self : DynValue,
  other : DynValue,
) -> Value? raise HintedError {
  match (self, other) {
    (Alignment(a), Alignment(b)) => Some(Dyn(Alignment(a.add(b))))
    _ => None
  }
}

///|
/// Regex matching for `in` (upstream `downcast::<Regex>().is_match`).
pub fn DynValue::regex_is_match(self : DynValue, s : String) -> Bool? {
  match self {
    Regex(regex) => Some(regex.is_match(s))
    _ => None
  }
}

///|
/// Access a field on a dynamic value (upstream `fields::field`): `None` if
/// the type has no fields, `Some(None)` if the field is missing.
pub fn DynValue::field(self : DynValue, field : String) -> Value?? {
  match self {
    Stroke(stroke) => Some(stroke.field(field))
    Alignment(align) => Some(align.field(field))
    _ => None
  }
}
