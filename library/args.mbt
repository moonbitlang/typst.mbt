// Port of `typst-library/src/foundations/args.rs` (core; the `arguments`
// type's methods are in `args_methods.mbt`).

///|
/// An argument to a function call: `12` or `draw: false`.
pub(all) struct Arg {
  /// The span of the whole argument.
  span : @syntax.Span
  /// The name of the argument (`None` for positional arguments).
  name : String?
  /// The value of the argument.
  value : @syntax.Spanned[Value]
}

///|
/// Captured arguments to a function.
pub(all) struct Args {
  /// The callsite span for the function.
  mut span : @syntax.Span
  /// The positional and named arguments.
  items : Array[Arg]
}

///|
/// Create positional arguments from a span and values.
pub fn Args::new(span : @syntax.Span, values : ArrayView[Value]) -> Args {
  {
    span,
    items: values
    .to_owned()
    .map(v => ({ span, name: None, value: { v, span, }, } : Arg)),
  }
}

///|
/// Attach a span to these arguments if they don't already have one.
pub fn Args::spanned(self : Args, span : @syntax.Span) -> Args {
  if self.span.is_detached() {
    self.span = span
  }
  self
}

///|
/// Returns the number of remaining positional arguments.
pub fn Args::remaining(self : Args) -> Int {
  self.items.iter().filter(a => a.name is None).count()
}

///|
/// Insert a positional argument at a specific index.
pub fn Args::insert(
  self : Args,
  index : Int,
  span : @syntax.Span,
  value : Value,
) -> Unit {
  self.items.insert(index, {
    span: self.span,
    name: None,
    value: { v: value, span, },
  })
}

///|
/// Push a positional argument.
pub fn Args::push(self : Args, span : @syntax.Span, value : Value) -> Unit {
  self.items.push({ span: self.span, name: None, value: { v: value, span, }, })
}

///|
/// Consume and cast the first positional argument if there is one.
pub fn[T : FromValue] Args::eat(self : Args) -> T? raise SourceError {
  for i, slot in self.items {
    if slot.name is None {
      let value = self.items.remove(i).value
      return Some(at(value.span, () => T::from_value(value.v)))
    }
  }
  None
}

///|
/// Consume and return the first positional argument with its span.
pub fn Args::eat_spanned(self : Args) -> @syntax.Spanned[Value]? {
  for i, slot in self.items {
    if slot.name is None {
      return Some(self.items.remove(i).value)
    }
  }
  None
}

///|
/// Consume n positional arguments if possible.
pub fn Args::consume(self : Args, n : Int) -> Array[Arg] raise SourceError {
  let list = []
  let mut i = 0
  while i < self.items.length() && list.length() < n {
    if self.items[i].name is None {
      list.push(self.items.remove(i))
    } else {
      i += 1
    }
  }
  if list.length() < n {
    bail_at(self.span, "not enough arguments")
  }
  list
}

///|
/// Consume and cast the first positional argument.
///
/// Returns a `missing argument: {what}` error if no positional argument is
/// left.
pub fn[T : FromValue] Args::expect(
  self : Args,
  what : String,
) -> T raise SourceError {
  match self.eat() {
    Some(v) => v
    None => raise SourceError([self.missing_argument(what)])
  }
}

///|
/// The error message for missing arguments.
fn Args::missing_argument(self : Args, what : String) -> SourceDiagnostic {
  for item in self.items {
    if item.name is Some(name) && name == what {
      return SourceDiagnostic::error_at(
        item.span,
        "the argument `\{what}` is positional",
      ).with_hint("try removing `\{name}:`")
    }
  }
  SourceDiagnostic::error_at(self.span, "missing argument: \{what}")
}

///|
/// Find and consume the first castable positional argument.
pub fn[T : FromValue] Args::find(self : Args) -> T? raise SourceError {
  for i, slot in self.items {
    if slot.name is None && castable_of((Ty::new() : Ty[T]), slot.value.v) {
      let value = self.items.remove(i).value
      return Some(at(value.span, () => T::from_value(value.v)))
    }
  }
  None
}

///|
/// Find and consume all castable positional arguments.
pub fn[T : FromValue] Args::all(self : Args) -> Array[T] raise SourceError {
  let list = []
  let errors = []
  let kept = []
  for item in self.items {
    if item.name is Some(_) {
      kept.push(item)
      continue
    }
    let span = item.value.span
    let v = item.value.v
    try T::from_value(v) catch {
      HintedError(err) => errors.push(err.into_error_at(span))
    } noraise {
      val => list.push(val)
    }
  }
  self.items.clear()
  self.items.append(kept)
  if !errors.is_empty() {
    raise SourceError(errors)
  }
  list
}

///|
/// Cast and remove the value for the given named argument, returning an
/// error if the conversion fails.
pub fn[T : FromValue] Args::named(
  self : Args,
  name : String,
) -> T? raise SourceError {
  // We don't quit once we have a match because when multiple matches exist,
  // we want to remove all of them and use the last one.
  let mut i = 0
  let mut found : T? = None
  while i < self.items.length() {
    if self.items[i].name == Some(name) {
      let value = self.items.remove(i).value
      found = Some(at(value.span, () => T::from_value(value.v)))
    } else {
      i += 1
    }
  }
  found
}

///|
/// Same as named, but with fallback to find.
pub fn[T : FromValue] Args::named_or_find(
  self : Args,
  name : String,
) -> T? raise SourceError {
  match self.named(name) {
    Some(value) => Some(value)
    None => self.find()
  }
}

///|
/// Take out all arguments into a new instance.
pub fn Args::take(self : Args) -> Args {
  let items = self.items.copy()
  self.items.clear()
  { span: self.span, items, }
}

///|
/// Return an "unexpected argument" error if there is any remaining argument.
pub fn Args::finish(self : Args) -> Unit raise SourceError {
  if self.items.length() > 0 {
    let arg = self.items[0]
    match arg.name {
      Some(name) => bail_at(arg.span, "unexpected argument: \{name}")
      None => bail_at(arg.span, "unexpected argument")
    }
  }
}

///|
/// Returns whether there are any arguments.
pub fn Args::is_empty(self : Args) -> Bool {
  self.items.is_empty()
}

///|
/// Access a named argument by name.
pub fn Args::field(self : Args, field : String) -> Value raise HintedError {
  for i = self.items.length() - 1; i >= 0; i = i - 1 {
    if self.items[i].name == Some(field) {
      return self.items[i].value.v
    }
  }
  bail("no named argument \{repr_str(field)}")
}

///|
/// The positional arguments.
pub fn Args::to_pos(self : Args) -> Arr {
  Arr::from_array(
    self.items
    .filter(item => item.name is None)
    .map(item => item.value.v.shared()),
  )
}

///|
/// The named arguments.
pub fn Args::to_named(self : Args) -> Dict {
  let d = Dict::new()
  for item in self.items {
    if item.name is Some(name) {
      d.map[name] = item.value.v.shared()
    }
  }
  d
}

///|
/// A copy of the arguments.
pub fn Args::copy(self : Args) -> Args {
  {
    span: self.span,
    items: self.items.map(a => {
      span: a.span,
      name: a.name,
      value: { v: a.value.v.shared(), span: a.value.span, },
    }),
  }
}

///|
/// Upstream `Repr for Args`.
pub fn Args::repr(self : Args) -> String {
  let pieces = self.items.map(arg => {
    match arg.name {
      Some(name) => "\{name}: \{arg.value.v.repr()}"
      None => arg.value.v.repr()
    }
  })
  "arguments" + pretty_array_like(pieces, false)
}

///|
/// Upstream `PartialEq for Args`: compares positional and named parts.
pub impl Eq for Args with fn equal(self, other) {
  equal(Array(self.to_pos()), Array(other.to_pos())) &&
  equal(Dict(self.to_named()), Dict(other.to_named()))
}

///|
/// Merge two argument lists (upstream `Add for Args`): named arguments of
/// `rhs` replace those of `self`.
pub fn Args::merge(self : Args, rhs : Args) -> Args {
  let items = self.items.filter(item => {
    match item.name {
      Some(name) => !rhs.items.iter().any(a => a.name == Some(name))
      None => true
    }
  })
  for a in rhs.items {
    items.push(a)
  }
  { span: @syntax.Span::detached(), items, }
}

// Helpers for `Spanned<T>` parameters (upstream casts from
// `Spanned<Value>` into `Spanned<T>`, keeping the argument's span).

///|
fn[T : FromValue] cast_spanned(
  value : @syntax.Spanned[Value],
) -> @syntax.Spanned[T] raise SourceError {
  { v: at(value.span, () => T::from_value(value.v)), span: value.span, }
}

///|
/// Consume and cast the first positional argument, keeping its span.
pub fn[T : FromValue] Args::eat_spanned_cast(
  self : Args,
) -> @syntax.Spanned[T]? raise SourceError {
  match self.eat_spanned() {
    Some(value) => Some(cast_spanned(value))
    None => None
  }
}

///|
/// [Args::expect] for a spanned parameter.
pub fn[T : FromValue] Args::expect_spanned(
  self : Args,
  what : String,
) -> @syntax.Spanned[T] raise SourceError {
  match self.eat_spanned() {
    Some(value) => cast_spanned(value)
    None => raise SourceError([self.missing_argument(what)])
  }
}

///|
/// [Args::named] for a spanned parameter.
pub fn[T : FromValue] Args::named_spanned(
  self : Args,
  name : String,
) -> @syntax.Spanned[T]? raise SourceError {
  let mut i = 0
  let mut found : @syntax.Spanned[T]? = None
  while i < self.items.length() {
    if self.items[i].name == Some(name) {
      found = Some(cast_spanned(self.items.remove(i).value))
    } else {
      i += 1
    }
  }
  found
}

///|
/// [Args::all] for spanned parameters.
pub fn[T : FromValue] Args::all_spanned(
  self : Args,
) -> Array[@syntax.Spanned[T]] raise SourceError {
  let list = []
  let errors = []
  let kept = []
  for item in self.items {
    if item.name is Some(_) {
      kept.push(item)
      continue
    }
    let span = item.value.span
    try T::from_value(item.value.v) catch {
      HintedError(err) => errors.push(err.into_error_at(span))
    } noraise {
      v => list.push(({ v, span, } : @syntax.Spanned[T]))
    }
  }
  self.items.clear()
  self.items.append(kept)
  if !errors.is_empty() {
    raise SourceError(errors)
  }
  list
}

///|
/// [Args::find] keeping the argument's span.
pub fn[T : FromValue] Args::find_spanned(
  self : Args,
) -> @syntax.Spanned[T]? raise SourceError {
  for i, slot in self.items {
    if slot.name is None && castable_of((Ty::new() : Ty[T]), slot.value.v) {
      let value = self.items.remove(i).value
      return Some(cast_spanned(value))
    }
  }
  None
}
