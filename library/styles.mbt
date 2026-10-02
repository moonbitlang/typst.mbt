// Port of `typst-library/src/foundations/styles.rs`.

///|
/// A list of style properties.
pub struct Styles {
  items : Array[Style]
}

///|
/// Create a new, empty style list.
pub fn Styles::new() -> Styles {
  { items: [], }
}

///|
pub fn Styles::from_array(items : Array[Style]) -> Styles {
  { items, }
}

///|
/// A copy of the style list.
pub fn Styles::copy(self : Styles) -> Styles {
  { items: self.items.copy(), }
}

///|
/// Whether this contains no styles.
pub fn Styles::is_empty(self : Styles) -> Bool {
  self.items.is_empty()
}

///|
/// Iterate over the contained styles.
pub fn Styles::iter(self : Styles) -> Iter[Style] {
  self.items.iter()
}

///|
/// Set an inner value for a style property (by element and field id).
pub fn Styles::set(
  self : Styles,
  elem : Element,
  id : Int,
  value : Value,
) -> Unit {
  self.items.push(Property(Property::new(elem, id, value)))
}

///|
/// Add a new style to the list.
pub fn Styles::push(self : Styles, style : Style) -> Unit {
  self.items.push(style)
}

///|
/// Remove the style that was last set.
pub fn Styles::unset(self : Styles) -> Unit {
  self.items.pop() |> ignore
}

///|
/// Apply outer styles. Like [chain](StyleChain::chain), but in-place.
pub fn Styles::apply(self : Styles, outer : Styles) -> Unit {
  let inner = self.items.copy()
  self.items.clear()
  self.items.append(outer.items)
  self.items.append(inner)
}

///|
/// Apply one outer styles.
pub fn Styles::apply_one(self : Styles, outer : Style) -> Unit {
  self.items.insert(0, outer)
}

///|
/// Add an origin span to all contained properties.
pub fn Styles::spanned(self : Styles, span : @syntax.Span) -> Styles {
  {
    items: self.items.map(s => {
      match s {
        Property(p) => Property({ ..p, span, })
        other => other
      }
    }),
  }
}

///|
/// Marks the styles as having been applied outside of any show rule.
pub fn Styles::outside(self : Styles) -> Styles {
  {
    items: self.items.map(s => {
      match s {
        Property(p) => Property({ ..p, outside: true, })
        Recipe(r) => Recipe({ ..r, outside: true, })
        Revocation(r) => Revocation(r)
      }
    }),
  }
}

///|
/// Marks the styles as being allowed to be lifted up to the page level.
pub fn Styles::liftable(self : Styles) -> Styles {
  {
    items: self.items.map(s => {
      match s {
        Property(p) => Property({ ..p, liftable: true, })
        other => other
      }
    }),
  }
}

///|
/// Whether there is a style for the given field of the given element.
pub fn Styles::has(self : Styles, elem : Element, id : Int) -> Bool {
  self.items.iter().any(s => s is Property(p) && p.is_(elem, id))
}

///|
/// Upstream `PartialEq for Styles`.
pub impl Eq for Styles with fn equal(self, other) {
  self.items == other.items
}

///|
/// A single style property, recipe or revocation.
pub(all) enum Style {
  /// A style property originating from a set rule or constructor.
  Property(Property)
  /// A show rule recipe.
  Recipe(Recipe)
  /// Disables a specific show rule recipe.
  Revocation(Int)
} derive(Eq)

///|
/// If this is a property, return it.
pub fn Style::property(self : Style) -> Property? {
  match self {
    Property(p) => Some(p)
    _ => None
  }
}

///|
/// If this is a recipe, return it.
pub fn Style::recipe(self : Style) -> Recipe? {
  match self {
    Recipe(r) => Some(r)
    _ => None
  }
}

///|
/// The style's span.
pub fn Style::span(self : Style) -> @syntax.Span {
  match self {
    Property(p) => p.span
    Recipe(r) => r.span
    Revocation(_) => @syntax.Span::detached()
  }
}

///|
/// Returns `Some(_)` with an optional span if this style is for the given
/// element.
pub fn Style::element(self : Style) -> Element? {
  match self {
    Property(p) => Some(p.elem)
    Recipe(r) =>
      match r.selector {
        Some(Elem(elem, _)) => Some(elem)
        _ => None
      }
    Revocation(_) => None
  }
}

///|
/// Whether the style is allowed to be lifted up to the page level.
pub fn Style::liftable(self : Style) -> Bool {
  match self {
    Property(p) => p.liftable
    Recipe(_) => true
    Revocation(_) => false
  }
}

///|
/// Whether the style was applied outside of any show rule.
pub fn Style::outside(self : Style) -> Bool {
  match self {
    Property(p) => p.outside
    Recipe(r) => r.outside
    Revocation(_) => false
  }
}

///|
/// A style property originating from a set rule or constructor.
pub struct Property {
  /// The element the property belongs to.
  elem : Element
  /// The property's ID.
  id : Int
  /// The property's value.
  value : Value
  /// The span of the set rule the property stems from.
  span : @syntax.Span
  /// Whether the property is allowed to be lifted up to the page level.
  liftable : Bool
  /// Whether the property was applied outside of any show rule.
  outside : Bool
}

///|
/// Create a new property from a key-value pair.
pub fn Property::new(elem : Element, id : Int, value : Value) -> Property {
  {
    elem,
    id,
    value,
    span: @syntax.Span::detached(),
    liftable: false,
    outside: false,
  }
}

///|
/// Whether this property is the given one.
pub fn Property::is_(self : Property, elem : Element, id : Int) -> Bool {
  self.elem == elem && self.id == id
}

///|
/// Whether this property belongs to the given element.
pub fn Property::is_of(self : Property, elem : Element) -> Bool {
  self.elem == elem
}

///|
pub impl Eq for Property with fn equal(self, other) {
  self.elem == other.elem &&
  self.id == other.id &&
  self.value == other.value &&
  self.span == other.span &&
  self.liftable == other.liftable &&
  self.outside == other.outside
}

///|
/// A show rule recipe.
pub struct Recipe {
  /// Determines whether the recipe applies to an element.
  selector : Selector?
  /// The transformation to perform on the match.
  transform : Transformation
  /// The span that errors are reported with.
  span : @syntax.Span
  /// Relevant properties of the kind of construct the style originated from.
  outside : Bool
}

///|
/// Create a new recipe from a key-value pair.
pub fn Recipe::new(
  selector : Selector?,
  transform : Transformation,
  span : @syntax.Span,
) -> Recipe {
  { selector, transform, span, outside: false, }
}

///|
pub impl Eq for Recipe with fn equal(self, other) {
  self.selector == other.selector &&
  self.transform == other.transform &&
  self.span == other.span &&
  self.outside == other.outside
}

///|
/// Apply the recipe to the given content.
pub fn Recipe::apply(
  self : Recipe,
  engine : Engine,
  context : Context,
  content : Content,
) -> Content raise SourceError {
  let content = match self.transform {
    Content(c) => c
    Func(func) => {
      let call = () => func.call_values(engine, context, [Content(content)])
      let result = if self.selector is Some(_) {
        trace(
          span => world_range(engine.world, span),
          () => Show(content.func().name()),
          content.span(),
          call,
        )
      } else {
        call()
      }
      result.display()
    }
    Style(styles) => content.styled_with_map(styles)
  }
  if content.span().is_detached() {
    content.spanned(self.span)
  } else {
    content
  }
}

///|
/// A show rule transformation that can be applied to a match.
pub(all) enum Transformation {
  /// Replacement content.
  Content(Content)
  /// A function to apply to the match.
  Func(Func)
  /// Apply styles to the content.
  Style(Styles)
} derive(Eq)

///|
pub impl Reflect for Transformation with fn input() {
  Union([Type(Type::content()), Type(Type::func())])
}

///|
pub impl Reflect for Transformation with fn output() {
  Union([Type(Type::content()), Type(Type::func())])
}

///|
pub impl Reflect for Transformation with fn castable(v) {
  Content::castable(v) || Func::castable(v)
}

///|
pub impl FromValue for Transformation with fn from_value(v) {
  if Content::castable(v) {
    Content(Content::from_value(v))
  } else if Func::castable(v) {
    Func(Func::from_value(v))
  } else {
    raise HintedError(Transformation::input().error(v))
  }
}

///|
/// A chain of styles, similar to a linked list.
pub struct StyleChain {
  /// The first link of this chain.
  head : Array[Style]
  /// The remaining links in the chain.
  tail : StyleChain?
}

///|
/// Start a new style chain with root styles.
pub fn StyleChain::new(root : Styles) -> StyleChain {
  { head: root.items, tail: None, }
}

///|
/// An empty style chain.
pub fn StyleChain::empty() -> StyleChain {
  // All empty chains share their (empty) head so that they compare equal,
  // like upstream's default chains do.
  { head: empty_style_head, tail: None, }
}

///|
let empty_style_head : Array[Style] = []

///|
/// Make the given chainable the first link of this chain.
pub fn StyleChain::chain(self : StyleChain, local : Styles) -> StyleChain {
  if local.is_empty() {
    self
  } else {
    { head: local.items, tail: Some(self), }
  }
}

///|
/// Make a single style the first link of this chain.
pub fn StyleChain::chain_one(self : StyleChain, style : Style) -> StyleChain {
  { head: [style], tail: Some(self), }
}

///|
/// Iterate over the entries of the chain (innermost first).
pub fn StyleChain::entries(self : StyleChain) -> Iter[Style] {
  let mut link : StyleChain? = Some(self)
  let mut i = self.head.length()
  Iter::new(() => {
    while link is Some(l) {
      if i > 0 {
        i -= 1
        return Some(l.head[i])
      }
      link = l.tail
      i = match l.tail {
        Some(t) => t.head.length()
        None => 0
      }
    }
    None
  })
}

///|
/// Iterate over the recipes in the chain.
pub fn StyleChain::recipes(self : StyleChain) -> Iter[Recipe] {
  self.entries().filter_map(s => s.recipe())
}

///|
/// Iterate over the links of the chain.
pub fn StyleChain::links(self : StyleChain) -> Array[Array[Style]] {
  let out = []
  let mut link : StyleChain? = Some(self)
  while link is Some(l) {
    out.push(l.head)
    link = l.tail
  }
  out
}

///|
/// Build owned styles from the suffix (all but the outermost `len` links) of
/// the chain.
pub fn StyleChain::suffix(self : StyleChain, len : Int) -> Styles {
  let links = self.links()
  let take = if links.length() > len { links.length() - len } else { 0 }
  let items = []
  for i = take - 1; i >= 0; i = i - 1 {
    for style in links[i] {
      items.push(style)
    }
  }
  { items, }
}

///|
/// Iterate over all values for the given property in the chain.
fn StyleChain::properties(
  self : StyleChain,
  elem : Element,
  id : Int,
) -> Iter[Value] {
  self
  .entries()
  .filter_map(s => {
    match s {
      Property(p) if p.is_(elem, id) => Some(p.value)
      _ => None
    }
  })
}

///|
/// Whether the chain has a property for the given field.
pub fn StyleChain::has(self : StyleChain, elem : Element, id : Int) -> Bool {
  self.entries().any(s => s is Property(p) && p.is_(elem, id))
}

///|
/// Get the value of a settable property from the chain, taking a local
/// (element) value into account and applying folding (upstream
/// `Settable::get_cloned` / `StyleChain::get_cloned`).
pub fn StyleChain::get_value_with_local(
  self : StyleChain,
  elem : Element,
  info : FieldInfo,
  local : Value?,
) -> Value {
  let default = () => {
    match info.default {
      Some(f) => f()
      None => None
    }
  }
  match info.fold {
    Some(fold) => {
      let mut folded : Value? = None
      for v in self.properties(elem, info.id) {
        folded = match folded {
          None => Some(v)
          Some(inner) => Some(fold(inner, v))
        }
      }
      let mut res = match folded {
        Some(f) => fold(f, default())
        None => default()
      }
      if local is Some(value) {
        res = fold(value, res)
      }
      res
    }
    None =>
      match local {
        Some(value) => value
        None =>
          match self.properties(elem, info.id).head() {
            Some(v) => v
            None => default()
          }
      }
  }
}

///|
/// Get the value of the given settable field from the chain.
pub fn StyleChain::get_field(
  self : StyleChain,
  elem : Element,
  id : Int,
) -> Value {
  self.get_value_with_local(elem, elem.fields()[id], None)
}

///|
/// Convert to a style map.
pub fn StyleChain::to_map(self : StyleChain) -> Styles {
  let items = self.entries().collect()
  items.rev_in_place()
  { items, }
}

///|
/// Remove the topmost link from the chain.
pub fn StyleChain::pop(self : StyleChain) -> StyleChain {
  match self.tail {
    Some(t) => t
    None => StyleChain::empty()
  }
}

///|
/// Iterate over the links of the chain (innermost first) and count them.
pub fn StyleChain::depth(self : StyleChain) -> Int {
  let mut n = 0
  let mut link : StyleChain? = Some(self)
  while link is Some(l) {
    n += 1
    link = l.tail
  }
  n
}

///|
/// A copy of this chain with its own identity (upstream: lifetime-extending
/// a chain in an arena yields a new address, so links chained onto the copy
/// are not equal to links chained onto the original).
pub fn StyleChain::fresh(self : StyleChain) -> StyleChain {
  { head: self.head, tail: self.tail, }
}

///|
/// The number of styles in the first link of the chain.
pub fn StyleChain::head_len(self : StyleChain) -> Int {
  self.head.length()
}

///|
/// Upstream `PartialEq for StyleChain` (pointer equality of links).
pub impl Eq for StyleChain with fn equal(self, other) {
  physical_equal(self.head, other.head) &&
  (match (self.tail, other.tail) {
    (Some(a), Some(b)) => physical_equal(a, b)
    (None, None) => true
    _ => false
  })
}

///|
pub impl Reflect for Styles with fn input() {
  Type(Type::styles())
}

///|
pub impl Reflect for Styles with fn output() {
  Type(Type::styles())
}

///|
pub impl Reflect for Styles with fn castable(v) {
  v is Styles(_)
}

///|
pub impl IntoValue for Styles with fn into_value(self) {
  Styles(self)
}

///|
pub impl FromValue for Styles with fn from_value(v) {
  match v {
    Styles(s) => s
    v => raise HintedError(CastInfo::Type(Type::styles()).error(v))
  }
}

///|
/// A property that is folded to determine its final value (upstream
/// `Fold`).
///
/// Note: Folding must be associative, i.e. any implementation must satisfy
/// `fold(fold(a, b), c) == fold(a, fold(b, c))`.
pub(open) trait Fold {
  /// Fold this inner value with an outer folded value.
  fn fold(Self, Self) -> Self
}

///|
pub impl Fold for Bool with fn fold(self, _) {
  self
}

///|
pub impl[T : Fold] Fold for T? with fn fold(self, outer) {
  match (self, outer) {
    (Some(inner), Some(outer)) => Some(inner.fold(outer))
    // An explicit `None` should be respected, thus we don't do
    // `inner.or(outer)`.
    (inner, _) => inner
  }
}

///|
/// Attempts to fold this inner value with an outer value. However, if
/// either value is `None`, returns the other one instead of folding
/// (upstream `AlternativeFold::fold_or`).
pub fn[T : Fold] fold_or(inner : T?, outer : T?) -> T? {
  match (inner, outer) {
    (Some(inner), Some(outer)) => Some(inner.fold(outer))
    // If one of values is `None`, return the other one instead of
    // folding.
    (Some(_), None) => inner
    (None, _) => outer
  }
}

///|
/// The value-level fold function of a field of type `T` (upstream: the
/// `#[fold]` attribute folds through `T`'s `Fold` impl).
pub fn[T : FromValue + IntoValue + Fold] fold_of(
  _ty : Ty[T],
) -> (Value, Value) -> Value {
  (inner, outer) => {
    let folded = try {
      let i : T = T::from_value(inner)
      let o : T = T::from_value(outer)
      Some(IntoValue::into_value(Fold::fold(i, o)))
    } catch {
      _ => None
    }
    folded.unwrap_or(inner)
  }
}
