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
/// Resolves the numbering for this counter track.
///
/// This coupling between the counter type and the remaining standard library
/// is not great ...
fn Counter::matching_numbering(
  self : Counter,
  engine : Engine,
  styles : StyleChain,
  loc : Location,
  span : @syntax.Span,
) -> Numbering? {
  match self.0 {
    Page => loc.page_numbering(engine, span)
    Selector(Elem(func, _)) => {
      let from_elem = match
        engine.introspect(query_first_introspection(Location(loc), span)) {
        Some(content) =>
          if func == heading_elem() {
            match content.to_packed() {
              Some((elem : HeadingElem)) => elem.numbering_local().bind(n => n)
              None => None
            }
          } else if func == figure_elem() {
            match content.to_packed() {
              Some((elem : FigureElem)) => elem.numbering_local().bind(n => n)
              None => None
            }
          } else if func == equation_elem() {
            match content.to_packed() {
              Some((elem : EquationElem)) => elem.numbering_local().bind(n => n)
              None => None
            }
          } else if func == footnote_elem() {
            match content.to_packed() {
              Some((elem : FootnoteElem)) => elem.numbering_local()
              None => None
            }
          } else {
            None
          }
        None => None
      }
      match from_elem {
        Some(numbering) => Some(numbering)
        None =>
          if func == heading_elem() {
            HeadingElem::numbering_in(styles)
          } else if func == figure_elem() {
            FigureElem::numbering_in(styles)
          } else if func == equation_elem() {
            EquationElem::numbering_in(styles)
          } else if func == footnote_elem() {
            Some(FootnoteElem::numbering_in(styles))
          } else {
            None
          }
      }
    }
    _ => None
  }
}

///|
/// Catch the error of a source result (upstream `SourceResult<T>` as a
/// value).
pub fn[T] source_result(
  f : () -> T raise SourceError,
) -> Result[T, Array[SourceDiagnostic]] {
  try f() catch {
    SourceError(errors) => Err(errors)
  } noraise {
    v => Ok(v)
  }
}

///|
/// Raise the error of a source result.
pub fn[T] or_raise(
  result : Result[T, Array[SourceDiagnostic]],
) -> T raise SourceError {
  match result {
    Ok(v) => v
    Err(errors) => raise SourceError(errors)
  }
}

///|
/// The state of the counter at the location.
fn Counter::at_loc(
  self : Counter,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  or_raise(engine.introspect(counter_at_introspection(self, loc, span)))
}

///|
/// The state of the counter at the location and at the end of the document.
fn Counter::both_loc(
  self : Counter,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  or_raise(engine.introspect(counter_both_introspection(self, loc, span)))
}

///|
/// The state of the counter at the end of the document.
fn Counter::final_loc(
  self : Counter,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> CounterState raise SourceError {
  or_raise(engine.introspect(counter_final_introspection(self, loc, span)))
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
/// Retrieves a counter at a specific location (upstream
/// `CounterAtIntrospection`).
fn counter_at_introspection(
  counter : Counter,
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Result[CounterState, Array[SourceDiagnostic]]] {
  Introspect::new(
    (engine, introspector) => {
      source_result(() => {
        let selector = counter.select(introspector, loc)
        let sequence = counter_sequence(counter, selector, engine, introspector)
        let offset = introspector.query_count_before(selector, loc)
        let (state, page) = sequence[offset]
        let state = state.copy()
        if counter.is_page() {
          let delta = saturating_sub(
            introspector.page(loc).unwrap_or(NonZeroUSize(1L)).0,
            page,
          )
          state.step(1, delta)
        }
        state
      })
    },
    history => format_counter_convergence_warning(counter, span, history),
  )
}

///|
/// Retrieves the first number of a counter at a specific location and the
/// first number of the final state, both in one operation (upstream
/// `CounterBothIntrospection`).
fn counter_both_introspection(
  counter : Counter,
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Result[CounterState, Array[SourceDiagnostic]]] {
  Introspect::new(
    (engine, introspector) => {
      source_result(() => {
        let selector = counter.select(introspector, loc)
        let sequence = counter_sequence(counter, selector, engine, introspector)
        let offset = introspector.query_count_before(selector, loc)
        let (at_state, at_page) = sequence[offset]
        let at_state = at_state.copy()
        let (final_state, final_page) = sequence[sequence.length() - 1]
        let final_state = final_state.copy()
        if counter.is_page() {
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
      })
    },
    history => format_counter_convergence_warning(counter, span, history),
  )
}

///|
/// Retrieves the final state of a counter (upstream
/// `CounterFinalIntrospection`).
fn counter_final_introspection(
  counter : Counter,
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Result[CounterState, Array[SourceDiagnostic]]] {
  Introspect::new(
    (engine, introspector) => {
      source_result(() => {
        let selector = counter.select(introspector, loc)
        let sequence = counter_sequence(counter, selector, engine, introspector)
        let (state, page) = sequence[sequence.length() - 1]
        let state = state.copy()
        if counter.is_page() {
          let delta = saturating_sub(
            introspector.pages(loc).unwrap_or(NonZeroUSize(1L)).0,
            page,
          )
          state.step(1, delta)
        }
        state
      })
    },
    history => format_counter_convergence_warning(counter, span, history),
  )
}

///|
/// Produces the whole sequence of a counter.
///
/// Upstream memoizes this so that it happens just once for all retrievals of
/// the same counter, cutting down the number of computations from quadratic
/// to linear.
fn counter_sequence(
  counter : Counter,
  selector : Selector,
  engine : Engine,
  introspector : Introspector,
) -> Array[(CounterState, Int64)] raise SourceError {
  // Memoized like upstream (see `memo.mbt`). The sequence is not mutated by
  // its users (they copy the states they modify).
  let key = memo_fingerprint(state => {
    state.write(counter)
    state.write(selector)
    state.write_u128(engine.route.memo_hash())
  })
  memoize(
    counter_sequence_store,
    { ..engine, introspector, },
    key,
    (counter, selector),
    sequence => sequence,
    engine => {
      counter_sequence_impl(counter, selector, engine, engine.introspector)
    },
  )
}

///|
let counter_sequence_store : MemoStore[
  Array[(CounterState, Int64)],
  (Counter, Selector),
] = MemoStore::new()

///|
/// The uncached [counter_sequence].
fn counter_sequence_impl(
  counter : Counter,
  selector : Selector,
  engine : Engine,
  introspector : Introspector,
) -> Array[(CounterState, Int64)] raise SourceError {
  let engine = {
    ..engine,
    introspector,
    route: Route::extend(engine.route).unnested(),
  }
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
/// The warning when a counter failed to converge.
fn format_counter_convergence_warning(
  counter : Counter,
  span : @syntax.Span,
  history : History[Result[CounterState, Array[SourceDiagnostic]]],
) -> SourceDiagnostic {
  SourceDiagnostic::warning_at(
    span,
    "value of \{format_counter_key(counter)} did not converge",
  ).with_hint(
    history.hint("values", ret => {
      match ret {
        Ok(v) => format_counter_state(v)
        Err(_) => "(errored)"
      }
    }),
  )
}

///|
/// Formats a counter's key human-readably.
fn format_counter_key(counter : Counter) -> String {
  match counter.0 {
    Page => "the page counter"
    _ => "`\{counter.repr()}`"
  }
}

///|
/// Formats a counter's state human-readably.
fn format_counter_state(state : CounterState) -> String {
  let output = StringBuilder()
  let mut sep = ""
  for value in state.0 {
    output.write_string("\{sep}\{value}")
    sep = ", "
  }
  output.to_string()
}

///|
/// The counter update of an element with the `Count` capability (upstream
/// `Count::update` of the elements that implement it).
fn count_update(elem : Content) -> CounterUpdate? {
  let styles = StyleChain::empty()
  if CounterUpdateElem::of(elem) is Some(update) {
    Some(update.update())
  } else if HeadingElem::of(elem) is Some(heading) {
    if heading.numbering(styles) is Some(_) {
      Some(Step(heading.resolve_level(styles)))
    } else {
      None
    }
  } else if FigureElem::of(elem) is Some(figure) {
    // If the figure is numbered, step the counter by one. This steps the
    // `counter(figure)` which is global to all numbered figures.
    if figure.numbering(styles) is Some(_) {
      Some(Step(NonZeroUSize(1L)))
    } else {
      None
    }
  } else if EquationElem::of(elem) is Some(equation) {
    if equation.block(styles) && equation.numbering(styles) is Some(_) {
      Some(Step(NonZeroUSize(1L)))
    } else {
      None
    }
  } else if FootnoteElem::of(elem) is Some(footnote) {
    // `FootnoteElem::is_ref`: the body is a reference to another footnote.
    if footnote.body() is Reference(_) {
      None
    } else {
      Some(Step(NonZeroUSize(1L)))
    }
  } else if ParLineMarker::of(elem) is Some(_) {
    // The line counter must be updated manually by the root flow.
    None
  } else {
    Some(Step(NonZeroUSize(1L)))
  }
}

///|
/// The level of a heading: `level` if set, otherwise `offset + depth`
/// (upstream `HeadingElem::resolve_level`).
pub fn HeadingElem::resolve_level(
  self : HeadingElem,
  styles : StyleChain,
) -> NonZeroUSize {
  match self.level(styles) {
    Custom(level) => level
    Auto => NonZeroUSize(self.offset(styles).0 + self.depth(styles).0)
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
fn impl_counter_display__numbering_default() -> Smart[Numbering] raise SourceError {
  Auto
}

///|
fn impl_counter_display__at_default() -> Smart[LocatableSelector] raise SourceError {
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
  numbering_ : Smart[Numbering],
  at_ : Smart[LocatableSelector],
  both_ : Bool,
) -> Value raise SourceError {
  let numbering : Numbering? = match numbering_ {
    Auto => None
    Custom(n) => Some(n)
  }
  let at_ : LocatableSelector? = match at_ {
    Auto => None
    Custom(s) => Some(s)
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
    } else if elem.is_locatable() && elem.is_unqueriable() {
      // Upstream stores `CounterKey` natively and never casts it back from a
      // value. Internal counters on unqueriable elements (the line number
      // counter on `ParLineMarker`) must survive the value round trip of
      // the port's element fields. Users cannot name such elements.
      return Selector(Elem(elem, None))
    } else {
      return Selector(LocatableSelector::from_value(elem.into_value()).0)
    }
  }
  if LocatableSelector::castable(v) {
    // See above: internal counters on unqueriable elements.
    let sel = Selector::from_value(v) catch { _ => Can("") }
    if sel is Elem(elem, _) && elem.is_locatable() && elem.is_unqueriable() {
      return Selector(sel)
    }
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
