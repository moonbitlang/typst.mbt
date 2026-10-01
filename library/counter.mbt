// Port of `typst-library/src/introspection/counter.rs`.

///|
/// Counts through pages, elements, and more.
///
/// With the counter function, you can access and modify counters for pages,
/// headings, figures, and more. Moreover, you can define custom counters for
/// other things you want to count.
pub(all) struct Counter(CounterKey) derive(Eq)

///|
/// Create a new counter identified by a key.
pub fn Counter::new(key : CounterKey) -> Counter {
  Counter(key)
}

///|
/// The counter for the given element.
pub fn Counter::of(func : Element) -> Counter {
  Counter::new(Selector(Elem(func, None)))
}

///|
/// Selects all state updates.
pub fn Counter::select_any() -> Selector {
  counter_update_elem().select()
}

///|
/// The selector relevant for this counter's updates.
pub fn Counter::select(
  self : Counter,
  introspector : Introspector,
  loc : Location,
) -> Selector {
  let mut selector = counter_update_elem().where_([
    (counter_update_elem_key, self.0.into_value()),
  ])
  match self.0 {
    Page =>
      // In bundle export, we only want the page counter updates in the
      // current document.
      if introspector.document(loc) is Some(doc_location) {
        selector = Within(selector~, ancestor=Location(doc_location))
      }
    Selector(key) => selector = Or([selector, key])
    Str(_) => ()
  }
  selector
}

///|
/// Whether this is the page counter.
pub fn Counter::is_page(self : Counter) -> Bool {
  self.0 == Page
}

///|
/// Displays the value of the counter at the given location.
pub fn Counter::display_at(
  self : Counter,
  engine : Engine,
  loc : Location,
  styles : StyleChain,
  numbering : Numbering,
  span : @syntax.Span,
) -> Content raise SourceError {
  let context = Context::new(location=loc, styles~)
  self
  .at_loc(engine, loc, span)
  .display(engine, context, span, numbering)
  .display()
}

///|
/// The numbering of the element at the location, for counters of elements
/// with a numbering.
fn Counter::matching_numbering(
  self : Counter,
  engine : Engine,
  styles : StyleChain,
  loc : Location,
  span : @syntax.Span,
) -> Numbering? {
  ignore(span)
  match self.0 {
    Page => engine.introspector.page_numbering(loc)
    Selector(Elem(func, _)) => {
      let from_elem = match engine.introspector.query_first(Location(loc)) {
        Some(content) => numbering_field_of(content, func)
        None => None
      }
      match from_elem {
        Some(numbering) => Some(numbering)
        None => {
          let field = if func == heading_elem() {
            Some(heading_elem_numbering)
          } else if func == figure_elem() {
            Some(figure_elem_numbering)
          } else if func == equation_elem() {
            Some(equation_elem_numbering)
          } else if func == footnote_elem() {
            Some(footnote_elem_numbering)
          } else {
            None
          }
          guard field is Some(id) && func.field(id) is Some(info) else {
            return None
          }
          let value = styles.get_value_with_local(func, info, None)
          try Numbering::from_value(value) catch {
            _ => None
          } noraise {
            n => Some(n)
          }
        }
      }
    }
    _ => None
  }
}

///|
/// The stored `numbering` field of a heading, figure, equation or footnote.
fn numbering_field_of(content : Content, func : Element) -> Numbering? {
  let id = if func == heading_elem() {
    heading_elem_numbering
  } else if func == figure_elem() {
    figure_elem_numbering
  } else if func == equation_elem() {
    equation_elem_numbering
  } else if func == footnote_elem() {
    footnote_elem_numbering
  } else {
    return None
  }
  guard content.elem() == func else { return None }
  match content.field_raw(id) {
    Some(value) =>
      try Numbering::from_value(value) catch {
        _ => None
      } noraise {
        n => Some(n)
      }
    None => None
  }
}

///|
/// The state of the counter at the location (upstream
/// `CounterAtIntrospection`).
fn Counter::at_loc(
  self : Counter,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  ignore(span)
  let introspector = engine.introspector
  let selector = self.select(introspector, loc)
  let sequence = counter_sequence(self, selector, engine)
  let offset = introspector.query_count_before(selector, loc)
  let (state, page) = sequence[offset]
  let state = state.copy()
  if self.is_page() {
    let delta = saturating_sub(
      introspector.page(loc).unwrap_or(NonZeroUSize(1L)).0,
      page,
    )
    state.step(1, delta)
  }
  state
}

///|
/// The state of the counter at the location and at the end of the document
/// (upstream `CounterBothIntrospection`).
fn Counter::both_loc(
  self : Counter,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  ignore(span)
  let introspector = engine.introspector
  let selector = self.select(introspector, loc)
  let sequence = counter_sequence(self, selector, engine)
  let offset = introspector.query_count_before(selector, loc)
  let (at_state, at_page) = sequence[offset]
  let at_state = at_state.copy()
  let (final_state, final_page) = sequence[sequence.length() - 1]
  let final_state = final_state.copy()
  if self.is_page() {
    let at_delta = saturating_sub(
      introspector.page(loc).unwrap_or(NonZeroUSize(1L)).0,
      at_page,
    )
    at_state.step(1, at_delta)
    let final_delta = saturating_sub(
      introspector.pages(loc).unwrap_or(NonZeroUSize(1L)).0,
      final_page,
    )
    final_state.step(1, final_delta)
  }
  CounterState([at_state.first(), final_state.first()])
}

///|
/// The state of the counter at the end of the document (upstream
/// `CounterFinalIntrospection`).
fn Counter::final_loc(
  self : Counter,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  ignore(span)
  let introspector = engine.introspector
  let selector = self.select(introspector, loc)
  let sequence = counter_sequence(self, selector, engine)
  let (state, page) = sequence[sequence.length() - 1]
  let state = state.copy()
  if self.is_page() {
    let delta = saturating_sub(
      introspector.pages(loc).unwrap_or(NonZeroUSize(1L)).0,
      page,
    )
    state.step(1, delta)
  }
  state
}

///|
fn saturating_sub(a : Int64, b : Int64) -> Int64 {
  if a > b {
    a - b
  } else {
    0L
  }
}

///|
/// Produces the whole sequence of counter states.
///
/// This has to happen just once for all counters, cutting down the number
/// of counter updates from quadratic to linear.
fn counter_sequence(
  counter : Counter,
  selector : Selector,
  engine : Engine,
) -> Array[(CounterState, Int64)] raise SourceError {
  let introspector = engine.introspector
  let engine = engine.with_route(Route::extend(engine.route).unnested())
  let current = CounterState::init(counter.0 is Page)
  let mut page = 1L
  let stops = [(current.copy(), page)]
  for elem in introspector.query(selector) {
    if counter.is_page() {
      let prev = page
      page = introspector
        .page(elem.location().unwrap())
        .unwrap_or(NonZeroUSize(1L)).0
      let delta = page - prev
      if delta > 0L {
        current.step(1, delta)
      }
    }
    let update = if elem.can("Count") {
      count_update(elem)
    } else {
      Some(Step(NonZeroUSize(1L)))
    }
    if update is Some(update) {
      current.update(engine, update)
    }
    stops.push((current.copy(), page))
  }
  stops
}

///|
/// The counter update of an element with the `Count` capability (upstream
/// `Count::update`).
fn count_update(elem : Content) -> CounterUpdate? {
  if elem.elem() == counter_update_elem() {
    match elem.field_raw(counter_update_elem_update) {
      Some(value) =>
        try CounterUpdate::from_value(value) catch {
          _ => None
        } noraise {
          update => Some(update)
        }
      None => None
    }
  } else {
    // The `Count` implementations of other elements (headings, figures,
    // equations, footnotes) are ported with those elements.
    Some(Step(NonZeroUSize(1L)))
  }
}

///|
/// Create a new counter identified by a key.
fn impl_counter_construct(key_ : CounterKey) -> Counter raise HintedError {
  Counter::new(key_)
}

///|
/// Retrieves the value of the counter at the current location. Always
/// returns an array of integers, even if the counter has just one number.
fn impl_counter_get(
  self_ : Counter,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  let loc = at(span, () => context.location())
  self_.at_loc(engine, loc, span)
}

///|
/// `Default::default()` of `Smart<Numbering>`.
fn impl_counter_display__numbering_default() -> Value raise SourceError {
  Auto
}

///|
/// `Default::default()` of `Smart<LocatableSelector>`.
fn impl_counter_display__at_default() -> Value raise SourceError {
  Auto
}

///|
/// Displays the current value of the counter with a numbering and returns
/// the formatted output.
fn impl_counter_display(
  self_ : Counter,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  numbering_ : Value,
  at_ : Value,
  both_ : Bool,
) -> Value raise SourceError {
  // `Smart<Numbering>` and `Smart<LocatableSelector>` arguments.
  let numbering : Numbering? = match numbering_ {
    Auto => None
    v =>
      Some(
        at(span, () => {
          smart_cast(
            v,
            Numbering::input(),
            Numbering::castable,
            Numbering::from_value,
          )
        }),
      )
  }
  let at_ : LocatableSelector? = match at_ {
    Auto => None
    v =>
      Some(
        at(span, () => {
          smart_cast(
            v,
            LocatableSelector::input(),
            LocatableSelector::castable,
            LocatableSelector::from_value,
          )
        }),
      )
  }
  let location = match at_ {
    None => at(span, () => context.location())
    Some(selector) => selector.resolve_unique(engine, context, span)
  }
  let state = if both_ {
    self_.both_loc(engine, location, span)
  } else {
    self_.at_loc(engine, location, span)
  }
  let numbering = match numbering {
    Some(numbering) => numbering
    None => {
      let found = match context.styles {
        Some(styles) => self_.matching_numbering(engine, styles, location, span)
        None => None
      }
      match found {
        Some(numbering) => numbering
        None =>
          Pattern(NumberingPattern::from_str("1.1") catch { _ => abort("") })
      }
    }
  }
  if at_ is Some(_) {
    let context = match context.styles {
      Some(styles) => Context::new(location~, styles~)
      None => Context::new(location~)
    }
    state.display(engine, context, span, numbering)
  } else {
    state.display(engine, context, span, numbering)
  }
}

///|
/// Cast a value that is not `auto` into `T` with the error of `Smart<T>`
/// (until `Smart` is ported).
fn[T] smart_cast(
  v : Value,
  input : CastInfo,
  castable : (Value) -> Bool,
  from_value : (Value) -> T raise HintedError,
) -> T raise HintedError {
  if castable(v) {
    from_value(v)
  } else {
    raise HintedError(input.union_with(Type(Type::auto())).error(v))
  }
}

///|
/// Retrieves the value of the counter at the given location. Always returns
/// an array of integers, even if the counter has just one number.
fn impl_counter_at(
  self_ : Counter,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  selector_ : LocatableSelector,
) -> CounterState raise SourceError {
  let loc = selector_.resolve_unique(engine, context, span)
  self_.at_loc(engine, loc, span)
}

///|
/// Retrieves the value of the counter at the end of the document. Always
/// returns an array of integers, even if the counter has just one number.
fn impl_counter_final(
  self_ : Counter,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  let loc = at(span, () => context.location())
  self_.final_loc(engine, loc, span)
}

///|
/// `NonZeroUsize::ONE`.
fn impl_counter_step__level_default() -> NonZeroUSize raise SourceError {
  NonZeroUSize(1L)
}

///|
/// Increases the value of the counter by one.
fn impl_counter_step(
  self_ : Counter,
  span : @syntax.Span,
  level_ : NonZeroUSize,
) -> Content raise HintedError {
  impl_counter_update(self_, span, Step(level_))
}

///|
/// Updates the value of the counter.
fn impl_counter_update(
  self_ : Counter,
  span : @syntax.Span,
  update_ : CounterUpdate,
) -> Content raise HintedError {
  Content::new(counter_update_elem(), [
    (counter_update_elem_key, self_.0.into_value()),
    (counter_update_elem_update, update_.into_value()),
  ]).spanned(span)
}

///|
pub fn Counter::repr(self : Counter) -> String {
  "counter(\{self.0.repr()})"
}

///|
pub impl Reflect for Counter with fn input() {
  Type(Type::counter())
}

///|
pub impl Reflect for Counter with fn output() {
  Type(Type::counter())
}

///|
pub impl Reflect for Counter with fn castable(v) {
  v is Dyn(Counter(_))
}

///|
pub impl IntoValue for Counter with fn into_value(self) {
  Dyn(Counter(self))
}

///|
pub impl FromValue for Counter with fn from_value(v) {
  match v {
    Dyn(Counter(counter)) => counter
    v => raise HintedError(Counter::input().error(v))
  }
}

///|
/// Identifies a counter.
pub(all) enum CounterKey {
  /// The page counter.
  Page
  /// Counts elements matching the given selectors. Only works for
  /// locatable elements or labels.
  Selector(Selector)
  /// Counts through manual counters with the same key.
  Str(String)
} derive(Eq)

// cast! {
//     CounterKey,
//     self => match self {
//         Self::Page => PageElem::ELEM.into_value(),
//         Self::Selector(v) => v.into_value(),
//         Self::Str(v) => v.into_value(),
//     },
//     v: Str => Self::Str(v),
//     v: Label => Self::Selector(Selector::Label(v)),
//     v: Element => {
//         if v == PageElem::ELEM {
//             Self::Page
//         } else {
//             Self::Selector(LocatableSelector::from_value(v.into_value())?.0)
//         }
//     },
//     v: LocatableSelector => Self::Selector(v.0),
// }

///|
pub impl Reflect for CounterKey with fn input() {
  input_of((Ty::new() : Ty[String]))
  .union_with(Label::input())
  .union_with(Element::input())
  .union_with(LocatableSelector::input())
}

///|
pub impl Reflect for CounterKey with fn output() {
  CounterKey::input()
}

///|
pub impl Reflect for CounterKey with fn castable(v) {
  castable_of((Ty::new() : Ty[String]), v) ||
  Label::castable(v) ||
  Element::castable(v) ||
  LocatableSelector::castable(v)
}

///|
pub impl IntoValue for CounterKey with fn into_value(self) {
  match self {
    Page => page_elem().into_value()
    Selector(v) => v.into_value()
    Str(v) => Str(v)
  }
}

///|
pub impl FromValue for CounterKey with fn from_value(v) {
  if castable_of((Ty::new() : Ty[String]), v) {
    return Str((v.cast() : String))
  }
  if v is Label(label) {
    return Selector(Label(label))
  }
  if Element::castable(v) {
    let elem = Element::from_value(v)
    if elem == page_elem() {
      return Page
    } else {
      return Selector(LocatableSelector::from_value(elem.into_value()).0)
    }
  }
  if LocatableSelector::castable(v) {
    return Selector(LocatableSelector::from_value(v).0)
  }
  raise HintedError(CounterKey::input().error(v))
}

///|
pub fn CounterKey::repr(self : CounterKey) -> String {
  match self {
    Page => "page"
    Selector(selector) => selector.repr()
    Str(str) => repr_str(str)
  }
}

///|
/// An update to perform on a counter.
pub(all) enum CounterUpdate {
  /// Set the counter to the specified state.
  Set(CounterState)
  /// Increase the number for the given level by one.
  Step(NonZeroUSize)
  /// Apply the given function to the counter's state.
  Func(Func)
} derive(Eq)

// cast! {
//     CounterUpdate,
//     v: CounterState => Self::Set(v),
//     v: Func => Self::Func(v),
// }

///|
pub impl Reflect for CounterUpdate with fn input() {
  CounterState::input().union_with(Func::input())
}

///|
pub impl Reflect for CounterUpdate with fn output() {
  CounterUpdate::input()
}

///|
pub impl Reflect for CounterUpdate with fn castable(v) {
  v is Dyn(CounterUpdate(_)) || CounterState::castable(v) || Func::castable(v)
}

///|
/// Counter updates are stored as dynamic values in the (internal) `update`
/// field of `counter.update` elements.
pub impl IntoValue for CounterUpdate with fn into_value(self) {
  Dyn(CounterUpdate(self))
}

///|
pub impl FromValue for CounterUpdate with fn from_value(v) {
  if v is Dyn(CounterUpdate(update)) {
    return update
  }
  if CounterState::castable(v) {
    return Set(CounterState::from_value(v))
  }
  if Func::castable(v) {
    return Func(Func::from_value(v))
  }
  raise HintedError(CounterUpdate::input().error(v))
}

///|
/// Elements that have special counting behaviour (upstream `Count`): their
/// update is given by [count_update].

///|
/// Counts through elements with different levels.
pub(all) struct CounterState(Array[Int64]) derive(Eq)

///|
/// Get the initial counter state for the key.
pub fn CounterState::init(page : Bool) -> CounterState {
  // Special case, because pages always start at one.
  CounterState([if page { 1L } else { 0L }])
}

///|
pub fn CounterState::copy(self : CounterState) -> CounterState {
  CounterState(self.0.copy())
}

///|
/// Advance the counter and return the numbers for the given heading.
pub fn CounterState::update(
  self : CounterState,
  engine : Engine,
  update : CounterUpdate,
) -> Unit raise SourceError {
  match update {
    Set(state) => {
      self.0.clear()
      self.0.append(state.0)
    }
    Step(level) => self.step(level.0.to_int(), 1L)
    Func(func) => {
      let value = func.call_values(
        engine,
        Context::none(),
        self.0.map(n => Int(n)),
      )
      let state : CounterState = at(func.span(), () => value.cast())
      self.0.clear()
      self.0.append(state.0)
    }
  }
}

///|
/// Advance the number of the given level by the specified amount.
pub fn CounterState::step(self : CounterState, level : Int, by : Int64) -> Unit {
  while self.0.length() < level {
    self.0.push(0L)
  }
  let cur = self.0[level - 1]
  self.0[level - 1] = if cur > @int64.MAX_VALUE - by {
    @int64.MAX_VALUE
  } else {
    cur + by
  }
  self.0.truncate(level)
}

///|
/// Get the first number of the state.
pub fn CounterState::first(self : CounterState) -> Int64 {
  self.0.get(0).unwrap_or(1L)
}

///|
/// Display the counter state with a numbering.
pub fn CounterState::display(
  self : CounterState,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  numbering : Numbering,
) -> Value raise SourceError {
  numbering.apply(engine, context, span, self.0)
}

// cast! {
//     CounterState,
//     self => Value::Array(self.0.into_iter().map(IntoValue::into_value).collect()),
//     num: u64 => Self(smallvec![num]),
//     array: Array => Self(array
//         .into_iter()
//         .map(Value::cast)
//         .collect::<HintedStrResult<_>>()?),
// }

///|
pub impl Reflect for CounterState with fn input() {
  U64::input().union_with(Arr::input())
}

///|
pub impl Reflect for CounterState with fn output() {
  CounterState::input()
}

///|
pub impl Reflect for CounterState with fn castable(v) {
  U64::castable(v) || Arr::castable(v)
}

///|
pub impl IntoValue for CounterState with fn into_value(self) {
  Array(Arr::from_array(self.0.map(n => Int(n))))
}

///|
pub impl FromValue for CounterState with fn from_value(v) {
  if U64::castable(v) {
    return CounterState([U64::from_value(v).get()])
  }
  if Arr::castable(v) {
    let array = Arr::from_value(v)
    return CounterState(array.items.map(x => U64::from_value(x).get()))
  }
  raise HintedError(CounterState::input().error(v))
}

///|
/// Custom behavior of `counter.update`, `counter.display` (internal) and
/// `context` elements: they cannot be constructed manually.
fn counter_update_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}

///|
fn counter_display_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}
