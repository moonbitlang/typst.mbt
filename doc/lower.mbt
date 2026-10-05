// Lowering (docs/edsl-design.md, section 5): turning descriptions into
// engine content and values through the paths the Typst evaluator uses.
// The same code lowers the document before layout (with `Context::none()`)
// and the results of callbacks during layout (with the invocation's engine
// and context).

///|
priv struct Lower {
  session : Session
  engine : @library.Engine
  context : @library.Context
  /// The occurrence keys of the enclosing `Keyed` wrappers.
  keys : Array[String]
}

///|
/// The entry of a call site under the current keys.
fn Lower::entry(self : Lower, site : Site) -> Int raise @library.SourceError {
  self.session.registry.entry(site, self.keys)
}

///|
/// Run `f`, adding a call trace point to its errors (the evaluator's
/// `trace_call`).
fn[T] Lower::trace_call(
  self : Lower,
  name : String?,
  span : @syntax.Span,
  f : () -> T raise @library.SourceError,
) -> T raise @library.SourceError {
  @library.trace(
    s => @library.world_range(self.engine.world, s),
    () => @library.Tracepoint::Call(name),
    span,
    f,
  )
}

///|
/// Lower a description to engine content. `fallback` is the span for nodes
/// without a location of their own (plain strings): the span of the
/// argument they were passed in.
fn Lower::content(
  self : Lower,
  content : Content,
  fallback : @syntax.Span,
) -> @library.Content raise @library.SourceError {
  match content.node {
    NText(text, site) => {
      let span = match site {
        Some(site) => self.session.registry.span(self.entry(site))
        None => fallback
      }
      self.check_text(text, span)
      if @syntax.utf8_len(text) > text_offset_max {
        self.session.registry.mark_long_text(span)
      }
      // Typst's string-to-content conversion (`Value::display`).
      @library.Value::Str(text).display().spanned(span)
    }
    // A lone inserted expression: a sequence of one.
    NCall(_) | NValue(_) => self.sequence([content], fallback)
    NKeyed(_, _) if is_inserted(content) => self.sequence([content], fallback)
    NSeq(children, site) => {
      let entry = self.entry(site)
      // Plain strings among the children share the array argument's span.
      self.sequence(children[:], self.session.registry.arg_span(entry, 0))
    }
    // A rule outside a sequence styles nothing (Typst only allows `set` and
    // `show` directly in code and content blocks).
    NSetRule(set) => raise self.misplaced_rule(set.origin)
    NShowRule(show) => raise self.misplaced_rule(show.origin)
    NInvalid(message, site) =>
      raise error_at(self.session.registry.span(self.entry(site)), message)
    NLabelled(body, label, site, label_param) => {
      let entry = self.entry(site)
      let span = self.session.registry.span(entry)
      let label_span = self.session.registry.arg_span(entry, label_param)
      let body = self.content(body, self.session.registry.arg_span(entry, 0))
      self.labelled(body, label, span, label_span)
    }
    NKeyed(key, body) => {
      self.check_text(key, fallback)
      let keys = self.keys.copy()
      keys.push(key)
      let inner : Lower = { ..self, keys, }
      // Content without a location of its own gets the enclosing
      // argument's origin under the keys.
      let fallback = match body.node {
        NText(_, None) | NValue(_) | NSpace(_) =>
          self.session.registry.keyed_span(fallback, keys)
        _ => fallback
      }
      inner.content(body, fallback)
    }
    NContext(callback, site) => {
      let entry = self.entry(site)
      let span = self.session.registry.span(entry)
      let func = @library.Func::host(
        self.session.host(callback, span, self.keys),
      ).spanned(span)
      // The evaluator's `eval_contextual`: the element function cannot be
      // called (`cannot be constructed manually`).
      @library.Content::new(@library.context_elem(), [
        (@library.context_elem_func, @library.Value::Func(func)),
      ]).spanned(span)
    }
    NEval(node) => self.eval(node)
    NSpace(false) => @library.SpaceElem::shared()
    NSpace(true) => @library.SpaceElem::shared_with_newline()
    NEngine(content) => content
  }
}

///|
/// The error for a rule that is not a direct child of a sequence.
/// A string that reaches lowering must not contain the placeholder of an
/// interpolated description: only `Prose` resolves those (`prose.mbt`).
fn Lower::check_text(
  self : Lower,
  text : String,
  span : @syntax.Span,
) -> Unit raise @library.SourceError {
  ignore(self)
  if prose_leak(text) is Some(message) {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(span, message).with_hint(
        prose_leak_hint,
      ),
    ])
  }
}

///|
fn Lower::misplaced_rule(
  self : Lower,
  site : Site,
) -> @library.SourceError raise @library.SourceError {
  let span = self.session.registry.span(self.entry(site))
  @library.SourceError([
    @library.SourceDiagnostic::error_at(
      span, "rules are only allowed directly in `Document` and `Seq`",
    ).with_hint("wrap the rule and the content it styles in `Seq([..])`"),
  ])
}

///|
/// Lower the children of a sequence like the evaluator's
/// `eval_markup_exprs`: a rule styles the children after it.
fn Lower::sequence(
  self : Lower,
  children : ArrayView[Content],
  fallback : @syntax.Span,
) -> @library.Content raise @library.SourceError {
  let seq : Array[@library.Content] = []
  let mut i = 0
  while i < children.length() {
    let child = children[i]
    i += 1
    match child.node {
      NSetRule(set) => {
        let styles = self.set_rule(set)
        let tail = self.sequence(children[i:], fallback)
        i = children.length()
        seq.push(tail.styled_with_map(styles))
      }
      NShowRule(show) => {
        let recipe = self.show_rule(show)
        let tail = self.sequence(children[i:], fallback)
        i = children.length()
        // The evaluator's `styled_with_recipe`: a rule without a selector
        // transforms the tail at once.
        if recipe.selector is Option::None {
          seq.push(recipe.apply(self.engine, self.context, tail))
        } else {
          seq.push(tail.styled(@library.Style::Recipe(recipe)))
        }
      }
      // An inserted expression (`#f(..)`, `#value` in markup), also
      // inside `Keyed` wrappers, which do not change the lowered content:
      // its value is displayed, and a label is attached to the content
      // before it, with the evaluator's rule and warnings
      // (`eval_markup_exprs`).
      _ if is_inserted(child) => {
        let (value, span) = self.inserted(child, fallback)
        match value {
          Label(label) => {
            let mut found = -1
            for j = seq.length() - 1; j >= 0; j = j - 1 {
              if !seq[j].can("Unlabellable") {
                found = j
                break
              }
            }
            if found >= 0 {
              let elem = seq[found]
              if elem.label() is Some(_) {
                self.engine.sink.warn(
                  @library.SourceDiagnostic::warning_at(
                    elem.span(),
                    "content labelled multiple times",
                  ).with_hint(
                    "only the last label is used, the rest are ignored",
                  ),
                )
              }
              seq[found] = elem.labelled(label)
            } else {
              self.engine.sink.warn(
                @library.SourceDiagnostic::warning_at(
                  span,
                  "label `\{label.repr()}` is not attached to anything",
                ),
              )
            }
          }
          value => {
            self.mark_long(value, span)
            seq.push(value.display().spanned(span))
          }
        }
      }
      _ => seq.push(self.content(child, fallback))
    }
  }
  @library.Content::sequence(seq)
}

///|
/// Whether a description is an inserted expression: a call or a value,
/// possibly inside `Keyed` wrappers.
fn is_inserted(content : Content) -> Bool {
  match content.node {
    NCall(_) | NValue(_) => true
    NKeyed(_, body) => is_inserted(body)
    _ => false
  }
}

///|
/// The value and the span of an inserted expression (`is_inserted`),
/// evaluated under the keys of its `Keyed` wrappers.
fn Lower::inserted(
  self : Lower,
  content : Content,
  fallback : @syntax.Span,
) -> (@library.Value, @syntax.Span) raise @library.SourceError {
  match content.node {
    NCall(call) => {
      let entry = self.entry(call.origin)
      let span = self.session.registry.span(entry)
      (self.call(call.func, call.args, entry, span), span)
    }
    NValue(value) => (self.value(value, fallback), fallback)
    NKeyed(key, body) => {
      self.check_text(key, fallback)
      let keys = self.keys.copy()
      keys.push(key)
      let inner : Lower = { ..self, keys, }
      let fallback = match body.node {
        NValue(_) => self.session.registry.keyed_span(fallback, keys)
        _ => fallback
      }
      inner.inserted(body, fallback)
    }
    _ => panic()
  }
}

///|
/// Glyph offsets into a string of more than 65,535 bytes are not reliable:
/// mark the origin of `span` if `value` is one (a string literal or the
/// result of a call).
fn Lower::mark_long(
  self : Lower,
  value : @library.Value,
  span : @syntax.Span,
) -> Unit {
  if value is Str(text) && @syntax.utf8_len(text.to_string()) > text_offset_max {
    self.session.registry.mark_long_text(span)
  }
}

///|
/// Attach a label like markup does to one inserted expression result.
fn Lower::labelled(
  self : Lower,
  body : @library.Content,
  name : String,
  span : @syntax.Span,
  label_span : @syntax.Span,
) -> @library.Content raise @library.SourceError {
  // The label value comes from Typst's `label` function (empty names are
  // rejected there).
  let value = self.call(
    FNative(@library.native_label_construct()),
    [{ name: None, value: Value::str(name), param: -1, }],
    -1,
    label_span,
  )
  let label : @library.Label = @library.at(label_span, () => value.cast())
  if body.can("Unlabellable") {
    self.engine.sink.warn(
      @library.SourceDiagnostic::warning_at(
        label_span,
        "label `\{label.repr()}` is not attached to anything",
      ),
    )
    return body
  }
  if body.label() is Some(_) {
    self.engine.sink.warn(
      @library.SourceDiagnostic::warning_at(
        body.span(),
        "content labelled multiple times",
      ).with_hint("only the last label is used, the rest are ignored"),
    )
  }
  ignore(span)
  body.labelled(label)
}

///|
/// Resolve a qualified name like the evaluator resolves an identifier
/// followed by field accesses.
fn Lower::global(
  self : Lower,
  path : String,
  span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  self.check_text(path, span)
  let scopes = @library.Scopes::new(Some(self.engine.library))
  let guard_ = self.engine.binding_guard(span)
  let mut value : @library.Value? = None
  for segment in path.split(".") {
    let segment = segment.to_owned()
    value = Some(
      match value {
        None => @library.at(span, () => scopes.get(segment, guard_)).shared()
        Some(target) => @library.at(span, () => target.field(segment, guard_))
      },
    )
  }
  match value {
    Some(value) => value
    None => raise error_at(span, "empty name")
  }
}

///|
/// The function a reference denotes.
fn Lower::func(
  self : Lower,
  func : FuncRef,
  span : @syntax.Span,
) -> @library.Func raise @library.SourceError {
  match func {
    FElem(elem) => @library.Func::element(elem)
    FNative(data) => @library.Func::native(data)
    FPath(path) => {
      let value = self.global(path, span)
      @library.at(span, () => value.cast())
    }
  }
}

///|
/// Lower arguments. Each argument is spanned with its parameter's location
/// (`entry < 0` or `param < 0`: the call's span).
fn Lower::args(
  self : Lower,
  args : Array[ArgNode],
  entry : Int,
  span : @syntax.Span,
) -> @library.Args raise @library.SourceError {
  let items : Array[@library.Arg] = []
  // How many arguments had each span so far.
  let uses : Map[Int, Int] = Map([])
  for arg in args {
    let base = if entry >= 0 && arg.param >= 0 {
      self.session.registry.arg_span(entry, arg.param)
    } else {
      span
    }
    // Arguments that share a location (the arguments of a generic call,
    // the entries of a variadic array or of `extra`) still get distinct
    // spans: sub-ranges of the shared one, which resolve to the same
    // origin. A function that reports an error per argument would
    // otherwise have equal diagnostics deduplicated into one.
    let key = if entry >= 0 && arg.param >= 0 { arg.param } else { -1 }
    let used = uses.get(key).unwrap_or(0)
    uses[key] = used + 1
    let arg_span = match base.get() {
      // (Only the first few: the sub-range must stay inside the text
      // before the next token of the listing line.)
      Range(id~, start~, end~) if used > 0 && used < 16 && start + used < end =>
        @syntax.Span::from_range(id, start + used, end)
      _ => base
    }
    if arg.name is Some(name) {
      self.check_text(name, arg_span)
    }
    if arg.value.val is VSpread(inner) {
      // Like the evaluator's spread argument (`eval_args`).
      match self.value(inner, arg_span) {
        None => ()
        Array(array) =>
          for value in array.items {
            items.push({
              span: arg_span,
              name: Option::None,
              value: { v: value.shared(), span: arg_span, },
            })
          }
        Dict(dict) =>
          for key, value in dict.map {
            items.push({
              span: arg_span,
              name: Some(key),
              value: { v: value.shared(), span: arg_span, },
            })
          }
        Args(args) => items.append(args.items)
        v => @library.bail_at(arg_span, "cannot spread \{v.ty()}")
      }
      continue
    }
    let v = self.value(arg.value, arg_span)
    items.push({
      span: arg_span,
      name: arg.name,
      value: { v, span: arg_span, },
    })
  }
  { span, items, }
}

///|
/// Call a function like the evaluator's `call_func`.
fn Lower::call(
  self : Lower,
  func : FuncRef,
  args : Array[ArgNode],
  entry : Int,
  span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  let func = self.func(func, span).spanned(span)
  let args = self.args(args, entry, span)
  self.trace_call(func.name(), span, () => {
    func.call(self.engine, self.context, args)
  })
}

///|
/// Lower a value description. `span` is the span of the argument it is
/// passed in.
fn Lower::value(
  self : Lower,
  value : Value,
  span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  match value.val {
    VNone => @library.Value::None
    VAuto => @library.Value::Auto
    VBool(v) => @library.Value::Bool(v)
    VInt(v) => @library.Value::Int(v)
    VFloat(v) => @library.Value::Float(v)
    VStr(v) => {
      self.check_text(v, span)
      // Also for strings that become text (`#value`, raw text): glyph
      // offsets into a long string are not reliable.
      if @syntax.utf8_len(v) > text_offset_max {
        self.session.registry.mark_long_text(span)
      }
      @library.Value::Str(v)
    }
    // A numeric literal (`11pt`, `50%`, `1fr`, `90deg`).
    VNumeric(v, unit) => @library.Value::numeric(v, unit)
    // Typst's operators, in source order.
    VAdd(a, b) => {
      let a = self.value(a, span)
      let b = self.value(b, span)
      @library.at(span, () => @library.add(a, b))
    }
    VSub(a, b) => {
      let a = self.value(a, span)
      let b = self.value(b, span)
      @library.at(span, () => @library.sub(a, b))
    }
    VMul(a, b) => {
      let a = self.value(a, span)
      let b = self.value(b, span)
      @library.at(span, () => @library.mul(a, b))
    }
    VNeg(a) => {
      let a = self.value(a, span)
      @library.at(span, () => @library.neg(a))
    }
    VArray(items) => {
      let out : Array[@library.Value] = []
      for item in items {
        out.push(self.value(item, span))
      }
      @library.Value::Array(@library.Arr::from_array(out))
    }
    VDict(pairs) => {
      let dict = @library.Dict::new()
      for pair in pairs {
        self.check_text(pair.0, span)
        dict.insert(pair.0, self.value(pair.1, span))
      }
      @library.Value::Dict(dict)
    }
    // A value in a content position is passed as the value (so that
    // `none` and `auto` reach a content field as such).
    VContent({ node: NValue(inner), }) => self.value(inner, span)
    VContent(content) => @library.Value::Content(self.content(content, span))
    VLabel(name) =>
      self.call(
        FNative(@library.native_label_construct()),
        [{ name: None, value: Value::str(name), param: -1, }],
        -1,
        span,
      )
    VCall(func, args) => {
      let result = self.call(func, args, -1, span)
      if result is Str(text) {
        self.check_text(text, span)
      }
      self.mark_long(result, span)
      result.spanned(span)
    }
    VGlobal(path) => self.global(path, span)
    VCallback(callback) => {
      let own = self.session.registry.span(self.entry(callback.origin))
      @library.Value::Func(
        @library.Func::host(self.session.host(callback, own, self.keys)).spanned(
          own,
        ),
      )
    }
    VEngine(value) => value
    VSpread(_) =>
      raise error_at(span, "a spread value is only allowed as an argument")
    VInvalid(message) => raise error_at(span, message)
  }
}

///|
/// Lower a set rule like the evaluator's `eval_set_rule`.
fn Lower::set_rule(
  self : Lower,
  set : SetNode,
) -> @library.Styles raise @library.SourceError {
  let entry = self.entry(set.origin)
  let span = self.session.registry.span(entry)
  let target = match set.func {
    FElem(elem) => elem
    func => {
      let func = self.func(func, span)
      match func.to_element() {
        Some(elem) => elem
        None =>
          raise error_at(
            span, "only element functions can be used in set rules",
          )
      }
    }
  }
  let args = self.args(set.args, entry, span)
  target.set(self.engine, args).spanned(span).liftable()
}

///|
/// Lower a show rule like the evaluator's `eval_show_rule`.
fn Lower::show_rule(
  self : Lower,
  show : ShowNode,
) -> @library.Recipe raise @library.SourceError {
  let entry = self.entry(show.origin)
  let span = self.session.registry.span(entry)
  let selector : @library.Selector? = match show.selector {
    Some(selector) => {
      let selector_span = self.session.registry.arg_span(entry, 0)
      let selector = self.value(selector, selector_span)
      let selector : @library.ShowableSelector = @library.at(selector_span, () => {
        selector.cast()
      })
      Some(selector.0)
    }
    Option::None => Option::None
  }
  let transform : @library.Transformation = match show.transform {
    TValue(value) => {
      // The transformation is the last declared parameter.
      let transform_span = self.session.registry.arg_span(
        entry,
        if show.selector is Some(_) {
          1
        } else {
          0
        },
      )
      let value = self.value(value, transform_span)
      @library.at(transform_span, () => value.cast())
    }
    TFunc(callback) =>
      @library.Transformation::Func(
        @library.Func::host(self.session.host(callback, span, self.keys)).spanned(
          span,
        ),
      )
    TStyle(set) => @library.Transformation::Style(self.set_rule(set))
  }
  let recipe = @library.Recipe::new(selector, transform, span)
  @eval.check_recipe(self.engine, recipe)
  recipe
}

///|
/// Evaluate Typst source with the front end (`Markup`, `Equation`).
fn Lower::eval(
  self : Lower,
  node : EvalNode,
) -> @library.Content raise @library.SourceError {
  let entry = self.entry(node.origin)
  let span = self.session.registry.span(entry)
  let source_span = self.session.registry.arg_span(entry, node.source_param)
  self.check_text(node.source, source_span)
  let scope = @library.Scope::new()
  for pair in node.scope {
    self.check_text(pair.0, span)
    scope.define(pair.0, self.value(pair.1, span)) |> ignore
  }
  let id = self.session.registry.snippet(
    entry,
    node.mode,
    node.source,
    source_span,
  )
  let value = @eval.eval_string_mapped(
    self.engine,
    self.context,
    node.source,
    id,
    node.mode,
    scope,
  )
  match node.mode {
    Math => {
      // Math mode returns an equation element. Its body is passed to the
      // element function together with the options, so there is one
      // equation, constructed like `math.equation(body, block: ..)`.
      let equation : @library.Content = @library.at(span, () => value.cast())
      let body = @library.at(span, () => {
        equation.field(@library.equation_elem_body)
      })
      let func = @library.Func::element(@library.equation_elem()).spanned(span)
      let args = self.args(node.args, entry, span)
      args.items.insert(0, {
        span: source_span,
        name: None,
        value: { v: body, span: source_span, },
      })
      self
      .trace_call(func.name(), span, () => {
        func.call(self.engine, self.context, args)
      })
      .display()
      .spanned(span)
    }
    _ => value.display().spanned(span)
  }
}
