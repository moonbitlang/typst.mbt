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
    RootedPath(v) => v.repr()
    CounterUpdate(_) => "counter.update(..)"
    StateUpdate(_) => "state.update(..)"
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
