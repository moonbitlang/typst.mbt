// Port of `typst-eval/src/binding.rs`.

///|
fn eval_let_binding(
  vm : Vm,
  v : @ast.LetBinding,
) -> @library.Value raise @library.SourceError {
  let value : @library.Value = match v.init() {
    Some(expr) => eval_expr(vm, expr)
    None => None
  }
  if vm.flow is Some(_) {
    return None
  }
  match v.kind() {
    Normal(pattern) => destructure(vm, pattern, value)
    Closure(ident) => vm.define_(ident, value)
  }
  None
}

///|
fn eval_destruct_assignment(
  vm : Vm,
  v : @ast.DestructAssignment,
) -> @library.Value raise @library.SourceError {
  let value = eval_expr(vm, v.value())
  destructure_impl(vm, v.pattern(), value, (vm, expr, value) => {
    let location = access(vm, expr)
    (location.set)(value.shared())
  })
  None
}

///|
/// Destructures a value into a pattern.
fn destructure(
  vm : Vm,
  pattern : @ast.Pattern,
  value : @library.Value,
) -> Unit raise @library.SourceError {
  destructure_impl(vm, pattern, value, (vm, expr, value) => {
    match expr {
      Ident(ident) => vm.define_(ident, value)
      _ => @library.bail_at(expr.span(), "cannot assign to this expression")
    }
  })
}

///|
/// Destruct the given value into the pattern and apply the function to each
/// binding.
fn destructure_impl(
  vm : Vm,
  pattern : @ast.Pattern,
  value : @library.Value,
  f : (Vm, @ast.Expr, @library.Value) -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  match pattern {
    Normal(expr) => f(vm, expr, value)
    Placeholder(_) => ()
    Parenthesized(parenthesized) =>
      destructure_impl(vm, pattern_of_parenthesized(parenthesized), value, f)
    Destructuring(destruct) =>
      match value {
        Array(value) => destructure_array(vm, destruct, value, f)
        Dict(value) => destructure_dict(vm, destruct, value, f)
        _ =>
          @library.bail_at(pattern.span(), "cannot destructure \{value.ty()}")
      }
  }
}

///|
fn pattern_of_parenthesized(p : @ast.Parenthesized) -> @ast.Pattern {
  p.pattern()
}

///|
fn destructure_array(
  vm : Vm,
  destruct : @ast.Destructuring,
  value : @library.Arr,
  f : (Vm, @ast.Expr, @library.Value) -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  let len = value.len()
  let items = destruct.items().collect()
  let mut i = 0
  for p in items {
    match p {
      Pattern(pattern) => {
        if i >= len {
          raise @library.SourceError([wrong_number_of_elements(destruct, len)])
        }
        destructure_impl(vm, pattern, value.items[i].shared(), f)
        i += 1
      }
      Spread(spread) => {
        let sink_size = 1 + len - items.length()
        if sink_size < 0 || i + sink_size > len {
          raise @library.SourceError([wrong_number_of_elements(destruct, len)])
        }
        let sink = value.items[i:i + sink_size]
          .iter()
          .map(v => v.shared())
          .collect()
        if spread.sink_expr() is Some(expr) {
          f(vm, expr, Array(@library.Arr::from_array(sink)))
        }
        i += sink_size
      }
      Named(named) =>
        @library.bail_at(
          named.span(),
          "cannot destructure named pattern from an array",
        )
    }
  }
  if i < len {
    raise @library.SourceError([wrong_number_of_elements(destruct, len)])
  }
}

///|
fn destructure_dict(
  vm : Vm,
  destruct : @ast.Destructuring,
  dict : @library.Dict,
  f : (Vm, @ast.Expr, @library.Value) -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  let mut sink : @ast.Expr? = None
  let used : Map[String, Unit] = {}
  for p in destruct.items() {
    match p {
      Pattern(Normal(Ident(ident))) => {
        let v = @library.at(ident.span(), () => dict.get(ident.get()))
        f(vm, Ident(ident), v.shared())
        used[ident.get()] = ()
      }
      Named(named) => {
        let name = named.name()
        let v = @library.at(name.span(), () => dict.get(name.get()))
        destructure_impl(vm, named.pattern(), v.shared(), f)
        used[name.get()] = ()
      }
      Spread(spread) => sink = spread.sink_expr()
      Pattern(expr) =>
        @library.bail_at(
          expr.span(),
          "cannot destructure unnamed pattern from dictionary",
        )
    }
  }
  if sink is Some(expr) {
    let rest = @library.Dict::new()
    for key, value in dict.map {
      if !used.contains(key) {
        rest.insert(key, value.shared())
      }
    }
    f(vm, expr, Dict(rest))
  }
}

///|
/// The error message when the number of elements of the destructuring and
/// the array is mismatched.
fn wrong_number_of_elements(
  destruct : @ast.Destructuring,
  len : Int,
) -> @library.SourceDiagnostic {
  let mut count = 0
  let mut spread = false
  for p in destruct.items() {
    match p {
      Pattern(_) => count += 1
      Spread(_) => spread = true
      Named(_) => ()
    }
  }
  let quantifier = if len > count { "too many" } else { "not enough" }
  let expected = match (spread, count) {
    (true, 1) => "at least 1 element"
    (true, c) => "at least \{c} elements"
    (false, 0) => "an empty array"
    (false, 1) => "a single element"
    (false, c) => "\{c} elements"
  }
  @library.SourceDiagnostic::error_at(
    destruct.span(),
    "\{quantifier} elements to destructure",
  ).with_hint(
    "the provided array has a length of \{len}, but the pattern expects \{expected}",
  )
}
