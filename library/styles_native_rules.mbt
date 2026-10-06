// Port of the native show rule map of `typst-library/src/foundations/styles.rs`
// (`NativeRuleMap`, `ShowFn`, `NativeShowRule`).

///|
/// The signature of a native show rule over the typed view `T` of an element
/// (upstream `ShowFn<T>`).
pub type ShowFn[T] = (T, Engine, StyleChain) -> Content raise SourceError

///|
/// The show rule for a native element.
pub struct NativeShowRule {
  /// The element to which this rule applies.
  priv elem : Element
  /// Must only be called with content of the appropriate type.
  priv f : (Content, Engine, StyleChain) -> Content raise SourceError
}

///|
/// Create a new type-erased show rule.
pub fn[T : NativeElement] NativeShowRule::new(f : ShowFn[T]) -> NativeShowRule {
  {
    elem: T::elem(),
    f: (content, engine, styles) => {
      f(T::from_content_unchecked(content), engine, styles)
    },
  }
}

///|
/// The element to which this rule applies.
pub fn NativeShowRule::elem(self : NativeShowRule) -> Element {
  self.elem
}

///|
/// Applies the rule to content. Panics if the content is of the wrong type.
pub fn NativeShowRule::apply(
  self : NativeShowRule,
  content : Content,
  engine : Engine,
  styles : StyleChain,
) -> Content raise SourceError {
  if content.elem() != self.elem {
    abort(
      "native show rule for `\{self.elem.name()}` applied to `\{content.elem().name()}`",
    )
  }
  (self.f)(content, engine, styles)
}

///|
/// Holds native show rules.
pub struct NativeRuleMap {
  priv rules : Map[(Element, Target), NativeShowRule]
}

///|
/// A show rule that produces empty content.
// The bound is upstream's (`fn empty<T: NativeElement>`,
// foundations/styles.rs:1011).
#warnings("-unused_trait_bound")
fn[T : NativeElement] empty_rule() -> ShowFn[T] {
  (_, _, _) => Content::empty()
}

///|
/// Creates a new rule map.
///
/// Should be populated with rules for all target-element combinations that
/// are supported.
///
/// Contains built-in rules for a few special elements.
pub fn NativeRuleMap::new() -> NativeRuleMap {
  let rules = { rules: {}, }
  for target in [Target::Paged, Html, Bundle] {
    // ContextElem is as special as SequenceElem and StyledElem and could, in
    // theory, also be special cased in realization.
    rules.register(target, context_rule)

    // CounterDisplayElem only exists because the compiler can't currently
    // express the equivalent of `context counter(..).display(..)` in native
    // code (no native closures).
    rules.register(target, counter_display_rule)

    // These are all only for introspection and empty on all targets.
    rules.register(target, (empty_rule() : ShowFn[CounterUpdateElem]))
    rules.register(target, (empty_rule() : ShowFn[StateUpdateElem]))
    rules.register(target, (empty_rule() : ShowFn[MetadataElem]))
    rules.register(target, (empty_rule() : ShowFn[PrefixInfo]))
  }
  for target in [Target::Paged, Html] {
    rules.register(target, document_unsupported_rule)
  }
  rules
}

///|
/// Registers a rule for a target.
///
/// Panics if a rule already exists for this target-element combination.
pub fn[T : NativeElement] NativeRuleMap::register(
  self : NativeRuleMap,
  target : Target,
  f : ShowFn[T],
) -> Unit {
  let key = (T::elem(), target)
  if self.rules.contains(key) {
    abort(
      "duplicate native show rule for `\{T::elem().name()}` on \{target} target",
    )
  }
  self.rules[key] = NativeShowRule::new(f)
}

///|
/// Replaces a rule for a target.
///
/// Panics if no rule exists for this target-element combination.
pub fn[T : NativeElement] NativeRuleMap::replace(
  self : NativeRuleMap,
  target : Target,
  f : ShowFn[T],
) -> Unit {
  let key = (T::elem(), target)
  if !self.rules.contains(key) {
    abort(
      "no existing native show rule for `\{T::elem().name()}` on \{target} target",
    )
  }
  self.rules[key] = NativeShowRule::new(f)
}

///|
/// Retrieves the rule that applies to the `content` on the current `target`.
pub fn NativeRuleMap::get(
  self : NativeRuleMap,
  target : Target,
  content : Content,
) -> NativeShowRule? {
  self.rules.get((content.func(), target))
}

///|
/// The number of registered rules.
pub fn NativeRuleMap::len(self : NativeRuleMap) -> Int {
  self.rules.length()
}

///|
pub impl Fingerprint for NativeRuleMap with fn fingerprint(self, state) {
  state.write_usize(self.rules.length())
  for key, rule in self.rules {
    state.write(key.0)
    state.write(key.1)
    state.write(rule.elem)
  }
}

///|
/// The native show rule of `context` elements (upstream `CONTEXT_RULE`,
/// `foundations/context.rs`).
pub fn context_rule(
  elem : ContextElem,
  engine : Engine,
  styles : StyleChain,
) -> Content raise SourceError {
  let loc = elem.pack().location().unwrap()
  let context = Context::new(location=loc, styles~)
  elem.func().call_values(engine, context, []).display()
}

///|
/// The native show rule of counter displays (upstream
/// `COUNTER_DISPLAY_RULE`, `introspection/counter.rs`).
pub fn counter_display_rule(
  elem : CounterDisplayElem,
  engine : Engine,
  styles : StyleChain,
) -> Content raise SourceError {
  let content = elem.pack()
  let context = Context::new(location?=content.location(), styles~)
  impl_counter_display(
    elem.counter(),
    engine,
    context,
    content.span(),
    elem.numbering(),
    Auto,
    elem.both(),
  ).display()
}

///|
/// The native show rule of documents on targets that don't support them
/// (upstream `DOCUMENT_UNSUPPORTED_RULE`, `model/document.rs`).
pub fn document_unsupported_rule(
  elem : DocumentElem,
  _engine : Engine,
  _styles : StyleChain,
) -> Content raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      elem.pack().span(),
      "cannot construct a document",
    ).with_hint("use a `set document(..)` rule to configure metadata"),
  ])
}
