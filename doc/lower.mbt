// Lowering (docs/edsl-design.md, section 5): turning descriptions into
// engine content and values through the paths the Typst evaluator uses.
// The same code lowers the document before layout (with `Context::none()`)
// and the results of callbacks during layout (with the invocation's engine
// and context).

///|
priv struct Lowering {
  session : Session
  engine : @library.Engine
  context : @library.Context
  /// The occurrence keys of the enclosing `Keyed` wrappers.
  keys : Array[String]
  /// The spans for what has no location of its own inside the argument
  /// that is being lowered (`None`: nothing was given out yet, see
  /// `Lowering::args`).
  pieces : Pieces?
  /// The blocks and boxes with a size of their own whose arguments are
  /// being lowered (`Registry::container`), outermost first, and the
  /// number of that stack (`Registry::stack`).
  containers : Array[Int]
  stack : Int
}

///|
/// The spans of the descendants of one located argument (or of a call
/// whose arguments have no locations) that have no location of their own:
/// the plain strings and values of a sequence, the text runs, quotes and
/// paragraph breaks of `Prose`, the arguments that share a location, the
/// arguments of call values. Each takes the next span of the counter, so
/// all of them are distinct, however they are nested: a string or a value
/// has no identity, and each place where one is used is a piece. The
/// counter starts anew whenever the node that has the argument is lowered
/// (in another layout iteration, or for a description with a site that is
/// used twice), which gives the same spans again. (docs/edsl-design.md,
/// section 12.2, pieces and reuse.)
priv struct Pieces {
  /// The span of the argument (its token in the origin listing) or of the
  /// call (its line).
  base : @syntax.Span
  /// The number of spans that were given out. The first is `base` itself.
  next : @ref.Ref[Int]
  /// The spans of what is inside the argument under `Keyed` wrappers: one
  /// counter per path of keys (`Lowering::keyed`). The table belongs to the
  /// argument: the counters of its key paths share it, so that a path is
  /// one counter however the wrappers that spell it are nested.
  keyed : Map[String, Pieces]
}

///|
/// The spans inside `base`, none given out.
fn Pieces::new(base : @syntax.Span) -> Pieces {
  { base, next: { val: 0, }, keyed: Map([]), }
}

///|
/// The spans inside `base` after `base` itself, which the caller uses.
fn Pieces::after(base : @syntax.Span) -> Pieces {
  { base, next: { val: 1, }, keyed: Map([]), }
}

///|
/// The spans inside `base` among the scopes of the node that is being
/// lowered, registered on first use: one counter per base, also when
/// several arguments of the node have the same span (arguments without a
/// location have the span of the call).
fn pieces_of(scopes : Array[Pieces], base : @syntax.Span) -> Pieces {
  for pieces in scopes {
    if pieces.base == base {
      return pieces
    }
  }
  let pieces = Pieces::new(base)
  scopes.push(pieces)
  pieces
}

///|
/// The first character of the keys of the occurrences that `piece_span`
/// registers: a Unicode noncharacter. The keys of `Keyed` must not start
/// with it, so no key of a document names such an occurrence, and
/// `Origins` does not report these keys.
const PIECES_KEY : Char = '\u{FDD2}'

///|
/// Whether a key of an origin was made by `piece_span`.
fn is_pieces_key(key : String) -> Bool {
  key.length() > 0 && key.get_char(0) == Some(PIECES_KEY)
}

///|
/// `self` for lowering what is passed in the argument with the span
/// `anchor`, which the caller gives to the argument itself.
fn Lowering::at(self : Lowering, anchor : @syntax.Span) -> Lowering {
  { ..self, pieces: Some(Pieces::after(anchor)), }
}

///|
/// For lowering a body without a location of its own under the keys `keys`
/// (the current ones and that of a `Keyed`): the lowering context and the
/// span of the body. `fallback` is the span that the body would have
/// without the key.
///
/// The body is a piece of the enclosing argument under the keys: of the
/// argument's token (or line) in the origin's occurrence under the keys
/// (`Registry::keyed_span`). The pieces of an argument under one path of
/// keys have a counter of their own, so the first is that token itself,
/// and a second body under the same keys — another cell of a row whose
/// cells have the row's key — takes the next piece instead of the same
/// span. What is inside a body takes further pieces from that counter.
/// The counters of all paths are in the table of the argument, also the
/// paths that are reached inside a keyed body (a call value with a
/// `Keyed` argument): `["a", "b"]` is one counter, wherever it is spelled.
fn Lowering::keyed(
  self : Lowering,
  keys : Array[String],
  fallback : @syntax.Span,
) -> (Lowering, @syntax.Span) raise @library.SourceError {
  match self.pieces {
    Some(outer) => {
      // (Unambiguous for any keys: each is prefixed with its length.)
      let path = keys.map(key => "\{key.length()}:\{key}").join("")
      let pieces = match outer.keyed.get(path) {
        Some(pieces) => pieces
        None => {
          let pieces : Pieces = {
            base: self.session.registry.keyed_span(outer.base, keys),
            next: { val: 0, },
            keyed: outer.keyed,
          }
          outer.keyed[path] = pieces
          pieces
        }
      }
      let inner : Lowering = { ..self, keys, pieces: Some(pieces), }
      (inner, inner.take(pieces))
    }
    // No argument is being lowered: the span itself under the keys.
    Option::None => {
      let span = self.session.registry.keyed_span(fallback, keys)
      ({ ..self, keys, pieces: Some(Pieces::after(span)), }, span)
    }
  }
}

///|
/// The next span of `pieces`.
fn Lowering::take(
  self : Lowering,
  pieces : Pieces,
) -> @syntax.Span raise @library.SourceError {
  let k = pieces.next.val
  pieces.next.val = k + 1
  self.piece_span(pieces.base, k)
}

///|
/// The entry of a call site under the current keys.
fn Lowering::entry(
  self : Lowering,
  site : Site,
) -> Int raise @library.SourceError {
  let entry = self.session.registry.entry(site, self.keys)
  if self.session.lints {
    self.session.registry.note_stack(entry, self.stack)
  }
  entry
}

///|
/// Whether a call can be a container of a fixed size: `block` or `box`
/// with a `width` or a `height`. (Whether the size is fixed is read from
/// the element that the call returns: `Registry::note_size`.)
fn sizes_container(call : CallNode) -> Bool {
  guard call.func is FElem(elem) &&
    (elem == @library.block_elem() || elem == @library.box_elem()) else {
    return false
  }
  for arg in call.args {
    if arg.name is Some("width" | "height") {
      return true
    }
  }
  false
}

///|
/// Run `f`, adding a call trace point to its errors (the evaluator's
/// `trace_call`).
fn[T] Lowering::trace_call(
  self : Lowering,
  name : String?,
  span : @syntax.Span,
  f : () -> T raise @library.SourceError,
) -> T raise @library.SourceError {
  @library.trace(
    s => self.trace_range(s),
    () => @library.Tracepoint::Call(name),
    span,
    f,
  )
}

///|
/// The byte range of a span for the containment test of trace points
/// (`@library.trace`: an error inside the span of a call gets no trace
/// point for that call). It is the range of the span in its file, except
/// for the spans that `piece_span` takes from further occurrences of an
/// origin, which are bytes of another line than the call: such a span
/// counts as the first byte of the argument (or line) of the origin itself
/// that it is a piece of. The pieces of the first block are the ranges
/// from that byte to `k` bytes before the argument's end, so a later piece
/// is inside every earlier one and inside the call's line, in every block:
/// an error at an argument is inside its call, and the arguments of a call
/// value, which are taken after the call's own span, are inside that. The
/// range is a real range of the origin's own line, so no span outside that
/// line contains it.
fn Lowering::trace_range(
  self : Lowering,
  span : @syntax.DiagSpan,
) -> (Int, Int)? {
  let range = @library.world_range(self.engine.world, span)
  let registry = self.session.registry
  guard span.get() is Range(id~, start~, end~) && id == registry.origins else {
    return range
  }
  // The entry of the line (entries are sorted by their start).
  let entries = registry.entries
  let mut lo = 0
  let mut hi = entries.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if entries[mid].start <= start {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  guard lo > 0 else { return range }
  let occurrence = entries[lo - 1]
  guard start <= occurrence.end &&
    occurrence.keys.last() is Some(key) &&
    is_pieces_key(key) else {
    return range
  }
  // The origin: the entry without the key of the block.
  let keys = occurrence.keys.copy()
  keys.pop() |> ignore
  let origin = registry.rekeyed(lo - 1, keys) catch { _ => return range }
  let origin = entries[origin]
  for i, arg in occurrence.args {
    if arg is Some((_, s, t)) &&
      s == start &&
      end <= t &&
      origin.args[i] is Some((_, os, _)) {
      return Some((os, os + 1))
    }
  }
  guard start == occurrence.start else { return range }
  Some((origin.start, origin.start + 1))
}

///|
/// Lower a description to engine content. `fallback` is the span for nodes
/// without a location of their own (plain strings): the span of the
/// argument they were passed in.
fn Lowering::content(
  self : Lowering,
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
    NCall(_) | NValue(_) => self.sequence([content], fallback, own=false)
    NKeyed(_, _) | NComposite(_, _) if is_inserted(content) =>
      self.sequence([content], fallback, own=false)
    NSeq(children, site) => {
      let entry = self.entry(site)
      // Children without a location of their own (plain strings, values)
      // get distinct spans inside the array argument's (`Pieces`).
      let pieces = Pieces::new(self.param_span(site, entry, 0))
      let inner : Lowering = { ..self, pieces: Some(pieces), }
      inner.sequence(children[:], pieces.base, own=true)
    }
    // A sequence without a site inside one that has a site (the text
    // after a block in a `Para`): its children are further pieces of the
    // argument that is being lowered. They take the next spans of that
    // argument's counter (`self.pieces`), so the words resolve to the text
    // argument of the one call, like the words around them.
    NPieces(children) => self.sequence(children[:], fallback, own=true)
    // A rule outside a sequence styles nothing (Typst only allows `set` and
    // `show` directly in code and content blocks).
    NSetRule(set) => raise self.misplaced_rule(set.origin)
    NShowRule(show) => raise self.misplaced_rule(show.origin)
    NInvalid(message, site, param) =>
      raise error_at(
        self.session.registry.arg_span(self.entry(site), param),
        message,
      )
    NLabelled(body, label, site, label_param) => {
      let entry = self.entry(site)
      let span = self.session.registry.span(entry)
      let label_span = self.param_span(site, entry, label_param)
      let body_span = self.param_span(site, entry, 0)
      let body = self.at(body_span).content(body, body_span)
      self.labelled(body, label, span, label_span)
    }
    // What the `build` of a composite made.
    NComposite(body, site) => {
      let (inner, span) = self.composite(site)
      inner.content(body, span)
    }
    NKeyed(key, body) => {
      self.check_key(key, fallback)
      let keys = self.keys.copy()
      keys.push(key)
      let inner : Lowering = { ..self, keys, }
      // Content without a location of its own gets the enclosing
      // argument's origin under the keys.
      match body.node {
        NText(_, None) | NValue(_) | NSpace(_) => {
          let (inner, span) = self.keyed(keys, fallback)
          inner.content(body, span)
        }
        _ => inner.content(body, fallback)
      }
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
fn Lowering::check_text(
  self : Lowering,
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
/// The key of a `Keyed`: a text like any other that is lowered, and no key
/// of the occurrences that lowering registers itself (`PIECES_KEY`).
fn Lowering::check_key(
  self : Lowering,
  key : String,
  span : @syntax.Span,
) -> Unit raise @library.SourceError {
  self.check_text(key, span)
  if is_pieces_key(key) {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        span, "the key of `Keyed` starts with a reserved character (U+FDD2)",
      ),
    ])
  }
}

///|
fn Lowering::misplaced_rule(
  self : Lowering,
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
/// The `k`-th span inside `base`, the span of a located argument (its token
/// in the origin listing) or of a call (its line): the spans that
/// [Pieces] gives to what has no location of its own. Every markup
/// expression has a span of its own, and so has every piece: the engine
/// hashes spans into the keys of located elements (two paragraphs with the
/// same words are different elements in Typst) and deduplicates
/// diagnostics by span. The spans are sub-ranges of `base`, which resolve
/// to the same origin and argument: the `k`-th ends `k` bytes before its
/// end. When they run out, the next ones are the sub-ranges of the same
/// argument in a further occurrence of the origin, registered under the
/// keys of the origin plus a key of its own (`PIECES_KEY`, block number):
/// one line of the origin listing per `len` pieces, where `len` is the
/// length of `base`.
fn Lowering::piece_span(
  self : Lowering,
  base : @syntax.Span,
  k : Int,
) -> @syntax.Span raise @library.SourceError {
  guard k > 0 && base.get() is Range(start~, end~, ..) && end > start else {
    return base
  }
  // The sub-ranges that end 0 to `len - 1` bytes before the end are
  // non-empty and distinct.
  let per_block = end - start
  let block = k / per_block
  let m = k % per_block
  let base = if block == 0 {
    base
  } else {
    // The same argument (or line) in the occurrence `block` of the origin
    // of `base`, which is at least as long.
    let registry = self.session.registry
    guard registry.locate(base) is Some((entry, param)) else { return base }
    let keys = registry.entries[entry].keys.copy()
    keys.push("\{PIECES_KEY}pieces \{block}")
    let occurrence = registry.rekeyed(entry, keys)
    if param >= 0 {
      registry.arg_span(occurrence, param)
    } else {
      registry.span(occurrence)
    }
  }
  guard m > 0 && base.get() is Range(id~, start~, end~) && end - m > start else {
    return base
  }
  @syntax.Span::from_range(id, start, end - m)
}

///|
/// Lower the children of a sequence like the evaluator's
/// `eval_markup_exprs`: a rule styles the children after it. `own`: the
/// children are the pieces of the argument with the span `fallback`, and
/// each child without a location of its own takes a span of `self.pieces`;
/// otherwise there is one child, an inserted expression with that span.
fn Lowering::sequence(
  self : Lowering,
  children : ArrayView[Content],
  fallback : @syntax.Span,
  own~ : Bool,
) -> @library.Content raise @library.SourceError {
  let base = fallback
  let seq : Array[@library.Content] = []
  let mut i = 0
  while i < children.length() {
    let child = children[i]
    i += 1
    let fallback = match (child.node, self.pieces) {
      (NText(_, Option::None) | NValue(_), Some(pieces)) if own =>
        self.take(pieces)
      _ => base
    }
    match rule_of(child).unwrap_or(child.node) {
      NSetRule(set) => {
        let styles = self.set_rule(set)
        let tail = self.sequence(children[i:], base, own~)
        i = children.length()
        seq.push(tail.styled_with_map(styles))
      }
      NShowRule(show) => {
        let recipe = self.show_rule(show)
        let tail = self.sequence(children[i:], base, own~)
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
    NKeyed(_, body) | NComposite(body, _) => is_inserted(body)
    _ => false
  }
}

///|
/// For lowering the body of a composite (`NComposite`): the lowering
/// context and the span of the body, which is the call (what has no
/// location of its own in the result of `build` is not an argument of a
/// constructor).
fn Lowering::composite(
  self : Lowering,
  site : Site,
) -> (Lowering, @syntax.Span) raise @library.SourceError {
  let span = self.session.registry.span(self.entry(site))
  (self.at(span), span)
}

///|
/// The rule that a child of a sequence is, also as the result of a
/// composite (which is what it is made of).
fn rule_of(content : Content) -> Node? {
  match content.node {
    NSetRule(_) | NShowRule(_) => Some(content.node)
    NComposite(body, _) => rule_of(body)
    _ => Option::None
  }
}

///|
/// The value that a description is, also as the result of a composite:
/// as an argument it is passed as the value (`none` reaches a content
/// field as such).
fn value_of(content : Content) -> Value? {
  match content.node {
    NValue(value) => Some(value)
    NComposite(body, _) => value_of(body)
    _ => Option::None
  }
}

///|
/// The span of the parameter `param` of the constructor with the site
/// `site`, whose entry is `entry`: the argument's token; the line of the
/// call if the argument has no location, or, for a constructor inside a
/// composite, if it is not marked as an argument of the composite.
fn Lowering::param_span(
  self : Lowering,
  site : Site,
  entry : Int,
  param : Int,
) -> @syntax.Span {
  self.session.registry.arg_span(entry, site.param(param))
}

///|
/// The value and the span of an inserted expression (`is_inserted`),
/// evaluated under the keys of its `Keyed` wrappers.
fn Lowering::inserted(
  self : Lowering,
  content : Content,
  fallback : @syntax.Span,
) -> (@library.Value, @syntax.Span) raise @library.SourceError {
  match content.node {
    NCall(call) => {
      let entry = self.entry(call.origin)
      let span = self.session.registry.span(entry)
      guard self.session.lints && sizes_container(call) else {
        return (
          self.call(call.func, call.args, entry, span, site=call.origin),
          span,
        )
      }
      // What is lowered in the arguments of a block or box with a size of
      // its own is inside it.
      let registry = self.session.registry
      let id = registry.container(entry)
      if call.args.any(arg => arg.name is Some("fill" | "stroke")) {
        registry.containers[id].decorated = true
      }
      let containers = [..self.containers, id]
      let inner : Lowering = {
        ..self,
        stack: registry.stack(containers),
        containers,
      }
      let value = inner.call(
        call.func,
        call.args,
        entry,
        span,
        site=call.origin,
      )
      registry.note_size(id, value)
      (value, span)
    }
    NValue(value) => (self.value(value, fallback), fallback)
    NComposite(body, site) => {
      let (inner, span) = self.composite(site)
      inner.inserted(body, span)
    }
    NKeyed(key, body) => {
      self.check_key(key, fallback)
      let keys = self.keys.copy()
      keys.push(key)
      let inner : Lowering = { ..self, keys, }
      match body.node {
        NValue(_) => {
          let (inner, span) = self.keyed(keys, fallback)
          inner.inserted(body, span)
        }
        _ => inner.inserted(body, fallback)
      }
    }
    _ => panic()
  }
}

///|
/// Glyph offsets into a string of more than 65,535 bytes are not reliable:
/// mark the origin of `span` if `value` is one (a string literal or the
/// result of a call).
fn Lowering::mark_long(
  self : Lowering,
  value : @library.Value,
  span : @syntax.Span,
) -> Unit {
  if value is Str(text) && @syntax.utf8_len(text.to_string()) > text_offset_max {
    self.session.registry.mark_long_text(span)
  }
}

///|
/// Attach a label like markup does to one inserted expression result.
fn Lowering::labelled(
  self : Lowering,
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
fn Lowering::global(
  self : Lowering,
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
fn Lowering::func(
  self : Lowering,
  func : Callee,
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
/// (`entry < 0` or `param < 0`: the call's span). `site` is the site of
/// the entry: the parameters of a constructor inside a composite are those
/// of the composite that they were marked as (`Site::param`).
fn Lowering::args(
  self : Lowering,
  args : Array[ArgNode],
  entry : Int,
  span : @syntax.Span,
  scopes~ : Array[Pieces] = [],
  site? : Site,
) -> @library.Args raise @library.SourceError {
  let items : Array[@library.Arg] = []
  // Arguments that share a location (the arguments of a generic call, the
  // entries of a variadic array or of `extra`) still get distinct spans:
  // the spans of one `Pieces` per location, which resolve to the same
  // origin. A function that reports an error per argument would otherwise
  // have equal diagnostics deduplicated into one, and equal content in two
  // arguments would be one element for the engine. (`scopes`: the spans
  // that the caller already took for the node.)
  // A call without a location of its own (a call value): `span` is a span
  // of the argument that the call is in. Its first argument has the span
  // of the call, the others take further spans of that argument.
  let outer = match self.pieces {
    Some(pieces) => pieces
    Option::None => Pieces::after(span)
  }
  let mut first = true
  for arg in args {
    let pieces = if entry < 0 {
      outer
    } else {
      // A located argument: its token; an argument without a location:
      // the line of the call.
      let param = match site {
        Some(site) => site.param(arg.param)
        Option::None => arg.param
      }
      let base = if param >= 0 {
        self.session.registry.arg_span(entry, param)
      } else {
        span
      }
      pieces_of(scopes, base)
    }
    let arg_span = if entry < 0 && first { span } else { self.take(pieces) }
    first = false
    if arg.name is Some(name) {
      self.check_text(name, arg_span)
    }
    // What has no location inside the argument takes further spans.
    let inner : Lowering = { ..self, pieces: Some(pieces), }
    if arg.value.val is VSpread(spread) {
      // Like the evaluator's spread argument (`eval_args`).
      match inner.value(spread, arg_span) {
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
    let v = inner.value(arg.value, arg_span)
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
fn Lowering::call(
  self : Lowering,
  func : Callee,
  args : Array[ArgNode],
  entry : Int,
  span : @syntax.Span,
  site? : Site,
) -> @library.Value raise @library.SourceError {
  let func = self.func(func, span).spanned(span)
  let args = self.args(args, entry, span, site?)
  let result = self.trace_call(func.name(), span, () => {
    func.call(self.engine, self.context, args)
  })
  // A string that a function returns (the text of a file, say) is
  // checked like a string that is written.
  if result is Str(text) {
    self.check_text(text, span)
  }
  result
}

///|
/// Lower a value description. `span` is the span of the argument it is
/// passed in.
fn Lowering::value(
  self : Lowering,
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
    VDiv(a, b) => {
      let a = self.value(a, span)
      let b = self.value(b, span)
      @library.at(span, () => @library.div(a, b))
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
    VContent(content) =>
      match (content.node, value_of(content)) {
        // (Also where a composite made the value.)
        (NComposite(_, site), Some(inner)) => {
          let (lowering, span) = self.composite(site)
          lowering.value(inner, span)
        }
        _ => @library.Value::Content(self.content(content, span))
      }
    VLabel(name) =>
      self.call(
        FNative(@library.native_label_construct()),
        [{ name: None, value: Value::str(name), param: -1, }],
        -1,
        span,
      )
    VCall(func, args) => {
      let result = self.call(func, args, -1, span)
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
fn Lowering::set_rule(
  self : Lowering,
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
  let args = self.args(set.args, entry, span, site=set.origin)
  target.set(self.engine, args).spanned(span).liftable()
}

///|
/// Lower a show rule like the evaluator's `eval_show_rule`.
fn Lowering::show_rule(
  self : Lowering,
  show : ShowNode,
) -> @library.Recipe raise @library.SourceError {
  let entry = self.entry(show.origin)
  let span = self.session.registry.span(entry)
  let scopes : Array[Pieces] = []
  let selector : @library.Selector? = match show.selector {
    Some(selector) => {
      let pieces = pieces_of(scopes, self.param_span(show.origin, entry, 0))
      let selector_span = self.take(pieces)
      let inner : Lowering = { ..self, pieces: Some(pieces), }
      let selector = inner.value(selector, selector_span)
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
      let pieces = pieces_of(
        scopes,
        self.param_span(
          show.origin,
          entry,
          if show.selector is Some(_) {
            1
          } else {
            0
          },
        ),
      )
      let transform_span = self.take(pieces)
      let inner : Lowering = { ..self, pieces: Some(pieces), }
      let value = inner.value(value, transform_span)
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
fn Lowering::eval(
  self : Lowering,
  node : EvalNode,
) -> @library.Content raise @library.SourceError {
  let entry = self.entry(node.origin)
  let span = self.session.registry.span(entry)
  let source_span = self.param_span(node.origin, entry, node.source_param)
  self.check_text(node.source, source_span)
  let scope = @library.Scope::new()
  // The values of the scope have no locations: each takes a span inside
  // the call's, from one counter with what is inside them and with the
  // arguments without a location.
  let scopes : Array[Pieces] = []
  for pair in node.scope {
    self.check_text(pair.0, span)
    let pieces = pieces_of(scopes, span)
    let value_span = self.take(pieces)
    let inner : Lowering = { ..self, pieces: Some(pieces), }
    scope.define_(pair.0, inner.value(pair.1, value_span)) |> ignore
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
      let args = self.args(node.args, entry, span, scopes~, site=node.origin)
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
