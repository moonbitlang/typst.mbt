// Calls (docs/edsl-convert.md, section 4.2): typed constructors from the
// API table, the generic `Call`/`Value::call`, and the evaluation-order
// check.

///|
/// The signature of a typed constructor, set rule or function facade, as
/// the translator matches arguments to it.
priv struct Sig {
  /// What is called: `Heading`, `SetText`, `Paint::tiling`.
  head : String
  /// (Typst field, MoonBit name, kind, MoonBit type), in the order of the
  /// EDSL parameters.
  params : Array[(String, String, ParamKind, String)]
  /// The fields that take positional arguments, in the order the function
  /// takes them.
  positional : Array[String]
  /// The fields in the order their arguments are lowered (`extra` entries
  /// of named fields follow them).
  order : Array[String]
  /// Whether it has `extra=`.
  extra : Bool
  /// A set rule: every parameter is a labelled one.
  set : Bool
}

///|
fn Sig::of_elem(elem : ApiElem) -> Sig {
  {
    head: elem.name,
    params: elem.params[:].to_owned(),
    positional: elem.positional[:].to_owned(),
    order: elem.order[:].to_owned(),
    extra: true,
    set: false,
  }
}

///|
/// The set rule of an element: its settable fields, all labelled; the
/// settable positional fields are passed positionally, in lowering order.
fn Sig::of_set(elem : ApiElem) -> Sig {
  let settable = elem.settable[:].to_owned()
  let positional_fields = elem.positional[:].to_owned()
  let params : Array[(String, String, ParamKind, String)] = []
  for p in elem.params[:] {
    if settable.contains(p.0) {
      params.push(p)
    }
  }
  let positional : Array[String] = []
  for field in settable {
    if positional_fields.contains(field) {
      positional.push(field)
    }
  }
  {
    head: "Set" + elem.name,
    params,
    positional,
    order: settable,
    extra: true,
    set: true,
  }
}

///|
/// A function facade: its arguments are lowered in parameter order.
fn Sig::of_func(func : ApiFunc) -> Sig {
  let positional : Array[String] = []
  let order : Array[String] = []
  for p in func.params[:] {
    order.push(p.0)
    if !(p.2 is Named) {
      positional.push(p.0)
    }
  }
  {
    head: if func.owner == "" {
      func.name
    } else {
      func.owner + "::" + func.name
    },
    params: func.params[:].to_owned(),
    positional,
    order,
    // A static method of a value facade has no `extra`.
    extra: func.owner == "",
    set: false,
  }
}

///|
fn Sig::param(
  self : Sig,
  field : String,
) -> (String, String, ParamKind, String)? {
  for p in self.params {
    if p.0 == field {
      return Some(p)
    }
  }
  None
}

///|
/// The position of a field in the lowering order.
fn Sig::lowered_at(self : Sig, field : String) -> Int raise Bail {
  for i, name in self.order {
    if name == field {
      return i
    }
  }
  raise Bail("call")
}

///|
/// Where a translated argument stands in the source and in the lowering
/// order, and whether lowering it is total.
priv struct Slot {
  major : Int
  minor : Int
  total : Bool
}

///|
/// The evaluation-order check (section 4.2): the arguments that are not
/// total, taken in source order (the order of `slots`), must be lowered in
/// that order.
fn check_order(slots : Array[Slot]) -> Unit raise Bail {
  let mut major = -1
  let mut minor = -1
  for slot in slots {
    if slot.total {
      continue
    }
    if slot.major < major || (slot.major == major && slot.minor <= minor) {
      raise Bail("argument-order")
    }
    major = slot.major
    minor = slot.minor
  }
}

///|
/// An expression without its parentheses.
fn unparen(expr : @ast.Expr) -> @ast.Expr {
  match expr {
    Parenthesized(p) => unparen(p.expr())
    _ => expr
  }
}

///|
/// The path a call's callee denotes (section 4.2): a global path that
/// resolves to a function or a type in the library. Raises for methods,
/// user functions, unknown names, and for `label` and `eval`, whose
/// results can be labels.
fn Tr::call_path(
  self : Tr,
  call : @ast.FuncCall,
  env : Env,
) -> String raise Bail {
  let callee = call.callee()
  let other = if callee is FieldAccess(_) { "method-call" } else { "user-call" }
  guard self.global_path(callee, env) is Some(path) else { raise Bail(other) }
  if path == "label" {
    raise Bail("label-call")
  }
  if path == "eval" {
    raise Bail("eval-call")
  }
  match self.lookup(path) {
    Some(Func(_) | Type(_)) => path
    Some(_) => raise Bail("call")
    // A field of a function or type that is not in its scope is a method
    // (`heading.where`, `box.with`).
    None =>
      raise Bail(if callee is FieldAccess(_) { other } else { "unknown-name" })
  }
}

///|
/// The typed constructor of a call (an element or a function facade that
/// is content), if the path has one and the arguments fit it; otherwise
/// why not (`""`: the path has no typed constructor).
fn Tr::typed_call(
  self : Tr,
  path : String,
  args : @ast.Args,
  env : Env,
) -> Result[Code, String] {
  match find_elem(path) {
    Some(elem) if elem.ctor => {
      // The constructor stores the element itself: the name must denote
      // it in this library.
      guard self.lookup(path) is Some(Func(func)) &&
        func.to_element() is Some(_) else {
        return Err("")
      }
      return self.try_sig(Sig::of_elem(elem), path, args, env)
    }
    _ => ()
  }
  match find_func(path) {
    Some(func) if func.owner == "" =>
      self.try_sig(Sig::of_func(func), path, args, env)
    _ => Err("")
  }
}

///|
/// The generic form of a call whose typed constructor did not fit for
/// `reason`. If the generic form fails too and the typed one failed for
/// the order of its arguments, that is the construct to report.
fn Tr::generic_call(
  self : Tr,
  head : String,
  path : String,
  args : @ast.Args,
  env : Env,
  reason : String,
) -> Code raise Bail {
  let args = self.generic_args(path, args, env, false) catch {
    Bail(construct) =>
      raise Bail(if reason == "argument-order" { reason } else { construct })
  }
  self.hatch = true
  { code: "\{head}(\{mbt_str(path)}\{args})", total: false, }
}

///|
/// A call (section 4.2) as content of a stream: a typed constructor or the
/// generic `Call`, which is displayed like `#path(..)` in markup.
fn Tr::call(self : Tr, call : @ast.FuncCall, env : Env) -> Code raise Bail {
  let path = self.call_path(call, env)
  match self.typed_call(path, call.args(), env) {
    Ok(code) => code
    Err(reason) => self.generic_call("Call", path, call.args(), env, reason)
  }
}

///|
/// A call as a content argument: a typed constructor, or the generic
/// `Value::call`, which passes the result itself (a `Call` would pass its
/// display).
fn Tr::call_arg(self : Tr, call : @ast.FuncCall, env : Env) -> Code raise Bail {
  let path = self.call_path(call, env)
  match self.typed_call(path, call.args(), env) {
    Ok(code) => code
    Err(reason) =>
      self.generic_call("Value::call", path, call.args(), env, reason)
  }
}

///|
/// A call as a value: `Value::call(path, ..)`.
fn Tr::call_value(
  self : Tr,
  path : String,
  args : @ast.Args,
  env : Env,
) -> Code raise Bail {
  self.generic_call("Value::call", path, args, env, "")
}

///|
/// The arguments of a generic call or set rule as value descriptions:
/// `, positional=[..], named=[..]` (for a set rule: `, [named..],
/// positional=[..]`). They are lowered positional first, then named, so
/// the arguments that are not total must stand in that order in the
/// source.
fn Tr::generic_args(
  self : Tr,
  path : String,
  args : @ast.Args,
  env : Env,
  set : Bool,
) -> String raise Bail {
  let positional : Array[String] = []
  let named : Array[String] = []
  let names : Array[String] = []
  let slots : Array[Slot] = []
  // The source index of the last spread, and of the first named argument.
  let mut last_spread = -1
  let mut first_named = -1
  let mut index = 0
  for arg in args.items() {
    match arg {
      Pos(expr) => {
        let value = self.value(expr, env)
        slots.push({ major: 0, minor: positional.length(), total: value.total, })
        positional.push(value.code)
        // `arguments` keeps the order of its items.
        if path == "arguments" && first_named >= 0 {
          raise Bail("argument-order")
        }
      }
      Named(arg) => {
        let name = arg.name().get()
        if names.contains(name) {
          raise Bail("duplicate-argument")
        }
        names.push(name)
        let value = self.value(arg.expr(), env)
        slots.push({ major: 1, minor: named.length(), total: value.total, })
        named.push("(\{mbt_str(name)}, \{value.code})")
        if first_named < 0 {
          first_named = index
        }
      }
      Spread(spread) => {
        let value = self.value(spread.expr(), env)
        // A spread can fail (`cannot spread ..`).
        slots.push({ major: 0, minor: positional.length(), total: false, })
        positional.push("Value::spread(\{value.code})")
        last_spread = index
      }
    }
    index += 1
  }
  // A spread dictionary gives named arguments, of which the last one of a
  // name wins: the named arguments must all follow the spreads.
  if last_spread >= 0 && first_named >= 0 && first_named < last_spread {
    raise Bail("argument-order")
  }
  check_order(slots)
  let positional = if positional.is_empty() {
    ""
  } else {
    ", positional=[\{positional.join(", ")}]"
  }
  if set {
    ", [\{named.join(", ")}]\{positional}"
  } else if named.is_empty() {
    positional
  } else {
    "\{positional}, named=[\{named.join(", ")}]"
  }
}

///|
/// Try a typed signature; the reason (with the state restored) if the
/// arguments do not fit it.
fn Tr::try_sig(
  self : Tr,
  sig : Sig,
  path : String,
  args : @ast.Args,
  env : Env,
) -> Result[Code, String] {
  let mark = self.mark()
  try self.sig_call(sig, path, args, env) catch {
    Bail(reason) => {
      self.rollback(mark)
      Err(reason)
    }
  } noraise {
    code => Ok(code)
  }
}

///|
/// One argument matched to a field.
priv struct Assigned {
  field : String
  source : Int
  expr : @ast.Expr
  positional : Bool
}

///|
/// A call of a typed signature: the positional arguments are matched to
/// the positional fields, every argument is translated against its
/// parameter's type, and what has no typed form goes through `extra=`.
/// Raises if the arguments do not fit.
fn Tr::sig_call(
  self : Tr,
  sig : Sig,
  path : String,
  args : @ast.Args,
  env : Env,
) -> Code raise Bail {
  let positional : Array[(Int, @ast.Expr)] = []
  let assigned : Array[Assigned] = []
  let names : Array[String] = []
  let mut index = 0
  for arg in args.items() {
    match arg {
      Pos(expr) => positional.push((index, expr))
      Named(arg) => {
        let name = arg.name().get()
        // A field that Typst takes positionally only, or a duplicate.
        if sig.positional.contains(name) || names.contains(name) {
          raise Bail("call")
        }
        names.push(name)
        assigned.push({
          field: name,
          source: index,
          expr: arg.expr(),
          positional: false,
        })
      }
      Spread(_) => raise Bail("spread")
    }
    index += 1
  }
  // The fields of the positional arguments.
  let by_name = sig.set && path == "text"
  let fields : Array[String] = if by_name {
    self.text_positional(positional, names, env)
  } else if sig.set {
    if positional.length() > sig.positional.length() {
      raise Bail("call")
    }
    sig.positional[:positional.length()].to_owned()
  } else if sig.positional.length() == 1 &&
    sig.param(sig.positional[0]) is Some((_, _, Variadic, _)) {
    Array::make(positional.length(), sig.positional[0])
  } else {
    let required : Array[String] = []
    for field in sig.positional {
      if sig.param(field) is Some((_, _, Pos, _)) {
        required.push(field)
      }
    }
    if positional.length() == required.length() {
      required
    } else if positional.length() == sig.positional.length() {
      sig.positional
    } else {
      raise Bail("call")
    }
  }
  // The positional arguments reach the function in lowering order, which
  // must be their order in the source. (The positional arguments of
  // `set text(..)` are passed by name.)
  let mut last = -1
  for i, pair in positional {
    let at = sig.lowered_at(fields[i])
    if at < last && !by_name {
      raise Bail("call")
    }
    last = at
    assigned.push({
      field: fields[i],
      source: pair.0,
      expr: pair.1,
      positional: !by_name,
    })
  }
  assigned.sort_by_key(a => a.source)
  // Translate in source order.
  let required : Map[String, String] = Map([])
  let variadic : Array[String] = []
  let labelled : Map[String, String] = Map([])
  let extra : Array[String] = []
  let slots : Array[Slot] = []
  let mut named_extra = 0
  for arg in assigned {
    let param = sig.param(arg.field)
    match param {
      Some((_, _, Variadic, ty)) if !sig.set => {
        guard ty.strip_prefix("Array[") is Some(rest) &&
          rest.strip_suffix("]") is Some(item) else {
          raise Bail("call")
        }
        let code = self.typed_form(arg.expr, item.to_owned(), env)
        slots.push({
          major: sig.lowered_at(arg.field),
          minor: variadic.length(),
          total: code.total,
        })
        variadic.push(code.code)
        continue
      }
      Some((_, _, Pos, ty)) if !sig.set => {
        let code = self.typed_form(arg.expr, ty, env)
        slots.push({
          major: sig.lowered_at(arg.field),
          minor: 0,
          total: code.total,
        })
        required[arg.field] = code.code
        continue
      }
      Some((_, name, _, ty)) =>
        if self.typed(arg.expr, ty, env) is Some(code) {
          slots.push({
            major: sig.lowered_at(arg.field),
            minor: 0,
            total: code.total,
          })
          labelled[name] = code.code
          continue
        }
      None => ()
    }
    // No typed form: a value through `extra=`, passed in the positional
    // place of an optional positional field and after the typed arguments
    // otherwise.
    guard sig.extra else { raise Bail("call") }
    let value = self.value(arg.expr, env)
    if arg.positional {
      slots.push({
        major: sig.lowered_at(arg.field),
        minor: 0,
        total: value.total,
      })
    } else {
      slots.push({
        major: sig.order.length(),
        minor: named_extra,
        total: value.total,
      })
      named_extra += 1
    }
    extra.push("(\{mbt_str(arg.field)}, \{value.code})")
  }
  check_order(slots)
  let parts : Array[String] = []
  for p in sig.params {
    match p.2 {
      Pos if !sig.set =>
        match required.get(p.0) {
          Some(code) => parts.push(code)
          None => raise Bail("call")
        }
      Variadic if !sig.set => parts.push("[\{variadic.join(", ")}]")
      _ => if labelled.get(p.1) is Some(code) { parts.push("\{p.1}=\{code}") }
    }
  }
  if !extra.is_empty() {
    self.hatch = true
    parts.push("extra=[\{extra.join(", ")}]")
  }
  self.typed += 1
  { code: "\{sig.head}(\{parts.join(", ")})", total: false, }
}

///|
/// The fields of the positional arguments of `set text(..)`: its parse
/// hooks take a length as `size` and a colour as `fill` (unless the field
/// is also given by name).
fn Tr::text_positional(
  self : Tr,
  positional : Array[(Int, @ast.Expr)],
  names : Array[String],
  env : Env,
) -> Array[String] raise Bail {
  let fields : Array[String] = []
  for pair in positional {
    let field = if self.is_pure_length(pair.1, env) {
      "size"
    } else if self.is_color(pair.1, env) {
      "fill"
    } else {
      raise Bail("call")
    }
    if fields.contains(field) || names.contains(field) {
      raise Bail("call")
    }
    fields.push(field)
  }
  fields
}
