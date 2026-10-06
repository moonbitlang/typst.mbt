// Port of `typst-library/src/introspection/state.rs`.

///|
/// Manages stateful parts of your document.
///
/// States are identified by a key and hold an initial value. Their value
/// changes through `update`s and can be read contextually with `get`, `at`
/// and `final`.
pub(all) struct State {
  /// The key that identifies the state.
  key : String
  /// The initial value of the state.
  init : Value
} derive(Eq)

///|
/// Create a new state identified by a key.
pub fn State::new(key : String, init : Value) -> State {
  { key, init, }
}

///|
/// Selects all state updates for this state.
pub fn State::select(self : State) -> Selector {
  state_update_elem().where_([(state_update_elem_key, Str(self.key))])
}

///|
/// Selects all state updates.
pub fn State::select_any() -> Selector {
  state_update_elem().select()
}

///|
/// The value of the state at the location (upstream
/// `StateAtIntrospection`).
fn State::at_loc(
  self : State,
  engine : Engine,
  loc : Location,
  span : @syntax.Span,
) -> Value raise SourceError {
  or_raise(engine.introspect(state_at_introspection(self, loc, span)))
}

///|
/// The value of the state at the end of the document (upstream
/// `StateFinalIntrospection`).
fn State::final_value(
  self : State,
  engine : Engine,
  span : @syntax.Span,
) -> Value raise SourceError {
  or_raise(engine.introspect(state_final_introspection(self, span)))
}

///|
/// Retrieves a state at a specific location (upstream
/// `StateAtIntrospection`).
fn state_at_introspection(
  state : State,
  loc : Location,
  span : @syntax.Span,
) -> Introspect[Result[Value, Array[SourceDiagnostic]]] {
  Introspect::new(
    (engine, introspector) => {
      source_result(() => {
        let sequence = state_sequence(state, engine, introspector)
        let offset = introspector.query_count_before(state.select(), loc)
        sequence[offset]
      })
    },
    history => format_state_convergence_warning(state, span, history),
  )
}

///|
/// Retrieves the final value of a state (upstream
/// `StateFinalIntrospection`).
fn state_final_introspection(
  state : State,
  span : @syntax.Span,
) -> Introspect[Result[Value, Array[SourceDiagnostic]]] {
  Introspect::new(
    (engine, introspector) => {
      source_result(() => {
        let sequence = state_sequence(state, engine, introspector)
        sequence[sequence.length() - 1]
      })
    },
    history => format_state_convergence_warning(state, span, history),
  )
}

///|
/// The warning when a state failed to converge.
fn format_state_convergence_warning(
  state : State,
  span : @syntax.Span,
  history : History[Result[Value, Array[SourceDiagnostic]]],
) -> SourceDiagnostic {
  SourceDiagnostic::warning_at(
    span,
    "value of `state(\{repr_str(state.key)})` did not converge",
  )
  .with_hint(
    history.hint("values", ret => {
      match ret {
        Ok(v) => "`\{v.repr()}`"
        Err(_) => "(errored)"
      }
    }),
  )
  .with_hint("see https://typst.app/help/state-convergence for help")
}

///|
/// Produces the whole sequence of states.
///
/// This has to happen just once for all states, cutting down the number of
/// state updates from quadratic to linear.
fn state_sequence(
  state : State,
  engine : Engine,
  introspector : Introspector,
) -> Array[Value] raise SourceError {
  let engine = {
    ..engine,
    introspector,
    route: Route::extend_(engine.route).unnested(),
  }
  let mut current = state.init
  let stops = [current]
  for elem in introspector.query(state.select()) {
    let update = match elem.field_raw(state_update_elem_update) {
      Some(Dyn(StateUpdate(update))) => update
      _ => abort("state update without update")
    }
    match update {
      Set(value) => current = value
      Func(func) =>
        current = func.call_values(engine, Context::none(), [current])
    }
    stops.push(current)
  }
  stops
}

///|
/// Create a new state identified by a key.
fn impl_state_construct(key_ : String, init_ : Value) -> State {
  State::new(key_, init_)
}

///|
/// `Default::default()` of `Value`.
fn impl_state_construct__init_default() -> Value {
  None
}

///|
/// Retrieves the value of the state at the current location.
fn impl_state_get(
  self_ : State,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Value raise SourceError {
  let loc = at(span, () => context.location())
  self_.at_loc(engine, loc, span)
}

///|
/// Retrieves the value of the state at the given selector's unique match.
fn impl_state_at(
  self_ : State,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  selector_ : LocatableSelector,
) -> Value raise SourceError {
  let loc = selector_.resolve_unique(engine, context, span)
  self_.at_loc(engine, loc, span)
}

///|
/// Retrieves the value of the state at the end of the document.
fn impl_state_final(
  self_ : State,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Value raise SourceError {
  at(span, () => context.introspect())
  self_.final_value(engine, span)
}

///|
/// Updates the value of the state.
fn impl_state_update(
  self_ : State,
  span : @syntax.Span,
  update_ : StateUpdate,
) -> Content {
  Content::new(state_update_elem(), [
    (state_update_elem_key, Str(self_.key)),
    (state_update_elem_update, update_.into_value()),
  ]).spanned(span)
}

///|
pub fn State::repr(self : State) -> String {
  "state(\{repr_str(self.key)}, \{self.init.repr()})"
}

///|
pub impl Reflect for State with fn input() {
  Type(Type::state())
}

///|
pub impl Reflect for State with fn output() {
  Type(Type::state())
}

///|
pub impl Reflect for State with fn castable(v) {
  v is Dyn(State(_))
}

///|
pub impl IntoValue for State with fn into_value(self) {
  Dyn(State(self))
}

///|
pub impl FromValue for State with fn from_value(v) {
  match v {
    Dyn(State(state)) => state
    v => raise HintedError(State::input().error(v))
  }
}

///|
/// An update to perform on a state.
pub(all) enum StateUpdate {
  /// Set the state to the specified value.
  Set(Value)
  /// Apply the given function to the state.
  Func(Func)
} derive(Eq)

// cast! {
//     StateUpdate,
//     v: Func => Self::Func(v),
//     v: Value => Self::Set(v),
// }

///|
pub impl Reflect for StateUpdate with fn input() {
  Func::input().union_with(Value::input())
}

///|
pub impl Reflect for StateUpdate with fn output() {
  StateUpdate::input()
}

///|
pub impl Reflect for StateUpdate with fn castable(v) {
  Func::castable(v) || Value::castable(v)
}

///|
/// State updates are stored as dynamic values in the (internal) `update`
/// field of `state.update` elements.
pub impl IntoValue for StateUpdate with fn into_value(self) {
  Dyn(StateUpdate(self))
}

///|
pub impl FromValue for StateUpdate with fn from_value(v) {
  if v is Dyn(StateUpdate(update)) {
    return update
  }
  if Func::castable(v) {
    return Func(Func::from_value(v))
  }
  Set(v)
}

///|
fn state_update_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}
