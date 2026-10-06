// Port of the `#[scope] impl Args` block of
// `typst-library/src/foundations/args.rs`: the methods of the `arguments`
// type.

///|
/// Construct spreadable arguments in place.
fn impl_args_construct(args : Args) -> Args {
  args.take()
}

///|
/// Returns the number of arguments, both positional and named.
fn impl_args_len(self_ : Args) -> USize {
  USize(self_.items.length().to_int64())
}

///|
/// Returns the positional argument at the specified index, or the named
/// argument with the specified name.
fn impl_args_at(
  self_ : Args,
  key_ : ArgumentKey,
  default_ : Value?,
) -> Value raise HintedError {
  match self_.get(key_) {
    Some(v) => v.shared()
    None =>
      match default_ {
        Some(d) => d
        None => bail(args_missing_key_no_default(key_))
      }
  }
}

///|
/// Returns the captured positional arguments as an array.
fn impl_args_to_pos(self_ : Args) -> Arr {
  self_.to_pos()
}

///|
/// Returns the captured named arguments as a dictionary.
fn impl_args_to_named(self_ : Args) -> Dict {
  self_.to_named()
}

///|
/// Produces a new arguments object with only the arguments for which the
/// given function returns `{true}`.
fn impl_args_filter(
  self_ : Args,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Args raise SourceError {
  let items = []
  for arg in self_.items {
    if call_bool_test(test_, engine, context, arg.value.v.shared()) {
      items.push({
        span: arg.span,
        name: arg.name,
        value: { v: arg.value.v.shared(), span: arg.value.span, },
      })
    }
  }
  { span: @syntax.Span::detached(), items, }
}

///|
/// Produces a new arguments object in which all argument values were
/// transformed with the given function.
fn impl_args_map(
  self_ : Args,
  engine : Engine,
  context : Context,
  mapper_ : Func,
) -> Args raise SourceError {
  let items = []
  for arg in self_.items {
    let mapped_value = mapper_.call_values(engine, context, [
      arg.value.v.shared(),
    ])
    items.push({
      span: arg.span,
      name: arg.name,
      value: { v: mapped_value, span: @syntax.Span::detached(), },
    })
  }
  { span: @syntax.Span::detached(), items, }
}

///|
/// A key to access an argument: an index for positional arguments or a name
/// for named ones.
pub(all) enum ArgumentKey {
  Index(Int64)
  Name(String)
}

///|
pub impl Reflect for ArgumentKey with fn input() {
  CastInfo::Type(Type::int()).union_with(Type(Type::str()))
}

///|
pub impl Reflect for ArgumentKey with fn output() {
  ArgumentKey::input()
}

///|
pub impl Reflect for ArgumentKey with fn castable(v) {
  v is (Int(_) | Str(_) | Symbol(_))
}

///|
pub extend ArgumentKey with Reflect::{output, input, castable}

///|
pub impl FromValue for ArgumentKey with fn from_value(v) {
  match v {
    Int(v) => Index(v)
    Str(_) | Symbol(_) => Name((FromValue::from_value(v) : String))
    v => raise HintedError(ArgumentKey::input().error(v))
  }
}

///|
/// Look up an argument by index (among the positional ones; negative
/// indices count from the back) or by name (the last one wins).
fn Args::get(self : Args, key : ArgumentKey) -> Value? {
  match key {
    Index(index) => {
      let positional = self.items.filter(item => item.name is None)
      let n = positional.length().to_int64()
      let i = if index < 0L { n - -(index + 1L) - 1L } else { index }
      if index < 0L && -(index + 1L) >= n {
        None
      } else if i >= 0L && i < n {
        Some(positional[i.to_int()].value.v)
      } else {
        None
      }
    }
    // Accept the last argument with the right name.
    Name(name) => {
      for i = self.items.length() - 1; i >= 0; i = i - 1 {
        if self.items[i].name == Some(name) {
          return Some(self.items[i].value.v)
        }
      }
      None
    }
  }
}

///|
/// The missing key access error message when no default was given.
fn args_missing_key_no_default(key : ArgumentKey) -> String {
  match key {
    Index(i) =>
      "no positional argument at index \{i} and no default value was specified"
    Name(name) =>
      "no named argument \{repr_str(name)} and no default value was specified"
  }
}
