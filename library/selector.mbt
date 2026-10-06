// Port of `typst-library/src/foundations/selector.rs`.

///|
/// A filter for selecting elements within the document.
///
/// Selectors are used to apply styling rules to elements. You can also use
/// selectors to query the document for certain types of elements.
pub(all) enum Selector {
  /// Matches a specific type of element.
  ///
  /// If there is a dictionary, only elements with the fields from the
  /// dictionary match.
  Elem(Element, Array[(Int, Value)]?)
  /// Matches the element at the specified location.
  Location(Location)
  /// Matches elements with a specific label.
  Label(Label)
  /// Matches text elements through a regular expression.
  Regex(Regex)
  /// Matches elements with a specific capability.
  ///
  /// This is not exposed, but used internally.
  Can(String)
  /// Matches if any of the subselectors match.
  Or(Array[Selector])
  /// Matches if all of the subselectors match.
  And(Array[Selector])
  /// Matches all matches of `selector` before `end`.
  Before(selector~ : Selector, end~ : Selector, inclusive~ : Bool)
  /// Matches all matches of `selector` after `start`.
  After(selector~ : Selector, start~ : Selector, inclusive~ : Bool)
  /// Matches all matches of `selector` that are strictly within `ancestor`.
  ///
  /// This is not yet exposed, but used internally.
  Within(selector~ : Selector, ancestor~ : Selector)
} derive(Eq)

///|
/// Define a simple text selector.
pub fn Selector::text(text : String) -> Selector raise HintedError {
  if text.is_empty() {
    bail("text selector is empty")
  }
  Regex(Regex::new(regex_escape(text)))
}

///|
/// Define a regex selector.
pub fn Selector::regex(regex : Regex) -> Selector raise HintedError {
  if regex.as_str().is_empty() {
    bail("regex selector is empty")
  }
  if regex.is_match("") {
    bail("regex matches empty text")
  }
  Regex(regex)
}

///|
/// Define a simple [Selector::Can] selector.
pub fn Selector::can(capability : String) -> Selector {
  Can(capability)
}

///|
/// Whether the selector matches for the target.
pub fn Selector::matches(
  self : Selector,
  target : Content,
  styles : StyleChain?,
) -> Bool {
  match self {
    Elem(element, dict) =>
      target.elem() == element &&
      dict
      .unwrap_or([])
      .iter()
      .all(pair => field_matches(target, pair.0, pair.1, styles))
    Label(label) => target.label() == Some(label)
    Can(cap) => target.func().can(cap)
    Or(selectors) => selectors.iter().any(sel => sel.matches(target, styles))
    And(selectors) => selectors.iter().all(sel => sel.matches(target, styles))
    Location(location) => target.location() == Some(location)
    // Not supported here.
    Regex(_) | Before(..) | After(..) | Within(..) => false
  }
}

///|
/// Whether the field of the target has the given value.
fn field_matches(
  target : Content,
  id : Int,
  value : Value,
  styles : StyleChain?,
) -> Bool {
  let got = try {
    match styles {
      Some(styles) => target.get(id, styles~)
      None => target.get(id)
    }
  } catch {
    _ => return false
  }
  got == value
}

///|
/// Whether a value can be cast into `T`.
pub fn[T : Reflect] castable_of(_ : Ty[T], v : Value) -> Bool {
  T::castable(v)
}

///|
/// Turns a value into a selector. The following values are accepted:
/// - An element function like a `heading` or `figure`.
/// - A string or regular expression.
/// - A `{<label>}`.
/// - A location.
/// - A more complex selector like `{heading.where(level: 1)}`.
fn impl_selector_construct(target_ : Selector) -> Selector {
  target_
}

///|
/// Selects all elements that match this or any of the other selectors.
fn impl_selector_or(self_ : Selector, others_ : Array[Selector]) -> Selector {
  let list = others_.copy()
  list.push(self_)
  Or(list)
}

///|
/// Selects all elements that match this and all of the other selectors.
fn impl_selector_and(self_ : Selector, others_ : Array[Selector]) -> Selector {
  let list = others_.copy()
  list.push(self_)
  And(list)
}

///|
/// Returns a modified selector that will only match elements that occur
/// before the first match of `end`.
fn impl_selector_before(
  self_ : Selector,
  end_ : LocatableSelector,
  inclusive_ : Bool,
) -> Selector {
  Before(selector=self_, end=end_.0, inclusive=inclusive_)
}

///|
/// Returns a modified selector that will only match elements that occur
/// after the first match of `start`.
fn impl_selector_after(
  self_ : Selector,
  start_ : LocatableSelector,
  inclusive_ : Bool,
) -> Selector {
  After(selector=self_, start=start_.0, inclusive=inclusive_)
}

///|
/// Returns a modified selector that will only match elements that are
/// contained within any elements matching the `ancestor` selector.
fn impl_selector_within(
  self_ : Selector,
  ancestor_ : LocatableSelector,
) -> Selector {
  Within(selector=self_, ancestor=ancestor_.0)
}

///|
/// Returns a selector that filters for elements belonging to this function
/// whose fields have the values of the given arguments (upstream
/// `Func::where_`, `foundations/func.rs`).
fn impl_func_where(self_ : Func, args : Args) -> Selector raise HintedError {
  let fields = args.to_named()
  let kept = args.items.filter(arg => arg.name is None)
  args.items.clear()
  args.items.append(kept)
  guard self_.to_element() is Some(element) else {
    bail("`where()` can only be called on element functions")
  }
  let out = []
  for key, value in fields.map {
    match element.field_id(key) {
      Some(id) => out.push((id, value))
      None => bail("element `\{element.name()}` does not have field `\{key}`")
    }
  }
  element.where_(out)
}

///|
pub fn Selector::repr(self : Selector) -> String {
  match self {
    Elem(elem, dict) =>
      match dict {
        Some(dict) => {
          let pairs = dict.map(pair => {
            let (id, value) = pair
            (elem.field_name(id).unwrap(), value)
          })
          "\{elem.name()}.where\{Dict::from_pairs(pairs).repr()}"
        }
        None => elem.name()
      }
    Label(label) => label.repr()
    Regex(regex) => regex.repr()
    Can(_) => "selector(..)"
    Or(selectors) | And(selectors) => {
      let function = if self is Or(_) { "or" } else { "and" }
      let pieces = selectors.map(s => s.repr())
      "selector.\{function}\{pretty_array_like(pieces, false)}"
    }
    Location(loc) => loc.repr()
    Before(selector~, end=split, inclusive~)
    | After(selector~, start=split, inclusive~) => {
      let method_ = if self is Before(..) { "before" } else { "after" }
      let inclusive_arg = if !inclusive { ", inclusive: false" } else { "" }
      "\{selector.repr()}.\{method_}(\{split.repr()}\{inclusive_arg})"
    }
    Within(selector~, ancestor~) =>
      "\{selector.repr()}.within(\{ancestor.repr()})"
  }
}

// cast! {
//     type Selector,
//     text: EcoString => Self::text(&text)?,
//     func: Func => func
//         .to_element()
//         .ok_or("only element functions can be used as selectors")?
//         .select(),
//     label: Label => Self::Label(label),
//     regex: Regex => Self::regex(regex)?,
//     location: Location => Self::Location(location),
// }

///|
pub impl Reflect for Selector with fn input() {
  (Type(Type::str()) : CastInfo)
  .union_with(Type(Type::func()))
  .union_with(Type(Type::label()))
  .union_with(Type(Type::regex()))
  .union_with(Type(Type::location()))
  .union_with(Type(Type::selector()))
}

///|
pub impl Reflect for Selector with fn output() {
  Type(Type::selector())
}

///|
pub impl Reflect for Selector with fn castable(v) {
  v is Dyn(Selector(_)) ||
  castable_of((Ty::new() : Ty[String]), v) ||
  Func::castable(v) ||
  Label::castable(v) ||
  v is Dyn(Regex(_)) ||
  Location::castable(v)
}

///|
pub impl IntoValue for Selector with fn into_value(self) {
  Dyn(Selector(self))
}

///|
pub impl FromValue for Selector with fn from_value(v) {
  match v {
    Dyn(Selector(selector)) => selector
    v if castable_of((Ty::new() : Ty[String]), v) =>
      Selector::text((v.cast() : String))
    v if Func::castable(v) =>
      match Func::from_value(v).to_element() {
        Some(elem) => elem.select()
        None => bail("only element functions can be used as selectors")
      }
    Label(label) => Label(label)
    Dyn(Regex(regex)) => Selector::regex(regex)
    Dyn(Location(location)) => Location(location)
    v => raise HintedError(Selector::input().error(v))
  }
}

///|
/// A selector that can be used with `query`.
///
/// Hopefully, this is made obsolete by a more powerful query mechanism in the
/// future.
pub(all) struct LocatableSelector(Selector) derive(Eq)

///|
/// Resolve this selector into a location that is guaranteed to be unique.
pub fn LocatableSelector::resolve_unique(
  self : LocatableSelector,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Location raise SourceError {
  match self.0 {
    Location(loc) => loc
    other => {
      at(span, () => context.introspect())
      match engine.introspect(query_unique_introspection(other, span)) {
        Ok(content) => content.location().unwrap()
        Err(err) => raise SourceError([err.into_error_at(span)])
      }
    }
  }
}

///|
pub impl Reflect for LocatableSelector with fn input() {
  Union([
    Type(Type::label()),
    Type(Type::func()),
    Type(Type::location()),
    Type(Type::selector()),
  ])
}

///|
pub impl Reflect for LocatableSelector with fn output() {
  Type(Type::selector())
}

///|
pub impl Reflect for LocatableSelector with fn castable(v) {
  Label::castable(v) ||
  Func::castable(v) ||
  Location::castable(v) ||
  Selector::castable(v)
}

///|
pub impl IntoValue for LocatableSelector with fn into_value(self) {
  self.0.into_value()
}

///|
pub impl FromValue for LocatableSelector with fn from_value(v) {
  fn validate(selector : Selector) -> Unit raise HintedError {
    match selector {
      Elem(elem, _) =>
        if !elem.is_locatable() || elem.is_unqueriable() {
          bail("\{elem.name()} is not locatable")
        }
      Location(_) => ()
      Label(_) => ()
      Regex(_) => bail("text is not locatable")
      Can(_) => bail("capability is not locatable")
      Or(list) | And(list) =>
        for selector in list {
          validate(selector)
        }
      Before(selector~, end=split, ..) | After(selector~, start=split, ..) =>
        for selector in [selector, split] {
          validate(selector)
        }
      Within(selector~, ancestor~) =>
        for selector in [selector, ancestor] {
          validate(selector)
        }
    }
  }

  if !LocatableSelector::castable(v) {
    raise HintedError(LocatableSelector::input().error(v))
  }
  let selector = Selector::from_value(v)
  validate(selector)
  LocatableSelector(selector)
}

///|
/// A selector that can be used with show rules.
///
/// Hopefully, this is made obsolete by a more powerful showing mechanism in
/// the future.
pub(all) struct ShowableSelector(Selector) derive(Eq)

///|
pub impl Reflect for ShowableSelector with fn input() {
  Union([
    Type(Type::symbol()),
    Type(Type::str()),
    Type(Type::label()),
    Type(Type::func()),
    Type(Type::regex()),
    Type(Type::selector()),
  ])
}

///|
pub impl Reflect for ShowableSelector with fn output() {
  Type(Type::selector())
}

///|
pub impl Reflect for ShowableSelector with fn castable(v) {
  v is Symbol(_) ||
  castable_of((Ty::new() : Ty[String]), v) ||
  Label::castable(v) ||
  Func::castable(v) ||
  v is Dyn(Regex(_)) ||
  Selector::castable(v)
}

///|
pub impl IntoValue for ShowableSelector with fn into_value(self) {
  self.0.into_value()
}

///|
pub impl FromValue for ShowableSelector with fn from_value(v) {
  fn validate(selector : Selector, nested : Bool) -> Unit raise HintedError {
    match selector {
      Elem(_, _) => ()
      Label(_) => ()
      Regex(_) if !nested => ()
      Or(list) | And(list) =>
        for selector in list {
          validate(selector, true)
        }
      Regex(_) | Location(_) | Can(_) | Before(..) | After(..) =>
        bail("this selector cannot be used with show")
      Within(..) =>
        bail_hinted("this selector cannot currently be used with show", [
          "support for this is planned for the future",
        ])
    }
  }

  if !ShowableSelector::castable(v) {
    raise HintedError(ShowableSelector::input().error(v))
  }
  let selector = Selector::from_value(v)
  validate(selector, false)
  ShowableSelector(selector)
}

///|
/// `LocatableSelector(HeadingElem::ELEM.select())` (default of
/// `OutlineElem.target`).
fn outline_elem_target_default() -> Value {
  LocatableSelector(heading_elem().select()).into_value()
}
