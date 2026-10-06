// Memoization (not upstream: a replacement for comemo's `#[comemo::memoize]`
// on `layout_par_impl`, `layout_fragment_impl`, the counter sequence and
// `eval_closure`; the closure calls are at the end of this file).
//
// Upstream memoizes these functions on all their arguments, tracking which
// parts of the tracked arguments (introspector, locator, route, sink) the call
// observed. That makes later introspection iterations and repeated
// measurements (e.g. of grid cells) cheap. Here:
//
// - Entries are found by a fingerprint of the untracked arguments (content,
//   style chain, regions, ...) plus, for the layout functions, the fully
//   resolved locator and the route (stricter than upstream, which only
//   tracks what the call observes).
// - Fingerprints do not always distinguish what the computation can
//   observe: host closures compare by identity but fingerprint by their key
//   (and a `Fingerprint` that does not capture all data marks itself lossy;
//   none does at the moment). So an entry also keeps the arguments and is
//   only reused if they are equal ([values_memo_equal]: `==`, but recursing
//   into content, styles, arrays, dictionaries, functions and dynamic
//   values, where Typst's equality is looser). Closures compare by their
//   hash, like upstream's (`closures_equal`): equal fingerprints are equal
//   closures. Modules compare by identity, and a compilation has one module
//   object per evaluated file and per plugin: equal fingerprints are the
//   same module.
// - Layout results whose tags hold host closures are not cached
//   ([frame_cacheable]), the counter sequence only holds numbers, and the
//   state sequence is not memoized.
// - Introspector reads of the call are recorded into a fresh
//   [IntrospectionRecorder]. A cached result is only reused with the
//   introspector it was computed with, or if all of its recorded reads
//   produce the same results on the current introspector and none of the
//   recorded results had a lossy fingerprint or contained host closures.
//   Its reads are then merged into the caller's recorder (as if the call
//   had been executed), so convergence checking is unaffected.
// - The call's sink side effects (warnings, delayed errors, introspections,
//   traced values) are recorded into a fresh [Sink] and replayed into the
//   caller's sink, both after computing and on every reuse.
// - Results are copied for every caller where they are mutable (frames are
//   copy-on-write; values mark their containers shared).
// - Errors are not cached (the call is simply executed again).
//
// Caches only live for one compilation ([with_layout_memo]: its evaluation
// and its introspection iterations), as the world (files, fonts) is fixed
// during it.

///|
/// A memoized result.
priv struct MemoEntry[T, I] {
  /// The arguments that must be equal for reuse (beyond the key).
  input : I
  /// The introspector the result was computed with.
  backend : &IntrospectorBackend
  /// The introspector reads of the call.
  reads : IntrospectionRecorder
  /// The sink side effects of the call.
  sink : Sink
  /// The result.
  output : T
}

///|
/// The cached results of one memoized function.
priv struct MemoStore[T, I] {
  /// The compilation the entries belong to.
  mut generation : Int
  entries : Map[U128, Array[MemoEntry[T, I]]]
}

///|
fn[T, I] MemoStore::new() -> MemoStore[T, I] {
  { generation: 0, entries: {}, }
}

///|
/// The maximum number of results kept per key (results whose introspector
/// reads differ, e.g. from different introspection iterations).
let memo_max_entries : Int = 4

///|
/// The current compilation (0: memoization is off).
let memo_generation : Ref[Int] = { val: 0, }

///|
let memo_counter : Ref[Int] = { val: 0, }

///|
/// Whether compilations memoize (see [set_layout_memo_enabled]).
let memo_enabled : Ref[Bool] = { val: true, }

///|
/// Turn memoization on (the default) or off for the following
/// compilations. Memoization must not change results; tests compare
/// compilations with and without it.
pub fn set_layout_memo_enabled(enabled : Bool) -> Unit {
  memo_enabled.val = enabled
}

///|
/// Run `f` (a compilation) with fresh memoization caches.
pub fn[T] with_layout_memo(
  f : () -> T raise SourceError,
) -> T raise SourceError {
  let outer = memo_generation.val
  memo_counter.val += 1
  memo_generation.val = if memo_enabled.val { memo_counter.val } else { 0 }
  let result = {
    errdefer {
      memo_generation.val = outer
    }
    f()
  }
  memo_generation.val = outer
  result
}

///|
/// Whether memoization is active (in a compilation).
pub fn layout_memo_active() -> Bool {
  memo_generation.val != 0
}

///|
/// The number of the current compilation, for caches that live as long as
/// its memoized results do; zero outside of a compilation and when
/// memoization is off.
pub fn memo_compilation() -> Int {
  memo_generation.val
}

///|
/// The fingerprint written by `f` (a memoization key).
pub fn memo_fingerprint(f : (SipHasher128) -> Unit) -> U128 {
  let state = SipHasher128::new()
  f(state)
  state.finish128()
}

///|
/// Memoize `f`, keyed by `key` (which must fingerprint every argument of the
/// call except the engine; see the module docs) and `input` (compared for
/// equality). `f` must use the engine it is given. `copy` produces an
/// independent copy of a result.
fn[T, I : Eq] memoize(
  store : MemoStore[T, I],
  engine : Engine,
  key : U128,
  input : I,
  copy : (T) -> T,
  f : (Engine) -> T raise SourceError,
  cacheable? : (T) -> Bool = _ => true,
) -> T raise SourceError {
  let generation = memo_generation.val
  if generation == 0 {
    return f(engine)
  }
  if store.generation != generation {
    store.entries.clear()
    store.generation = generation
  }
  let parent = engine.introspector.recorder
  let backend = engine.introspector.backend
  if store.entries.get(key) is Some(entries) {
    for entry in entries {
      if entry.input == input &&
        (
          physical_equal(entry.backend, backend) ||
          (!entry.reads.lossy && entry.reads.validate(engine.introspector))
        ) {
        if parent is Some(parent) {
          entry.reads.merge_into(parent)
        }
        engine.sink.extend_from_sink(entry.sink)
        // The key holds the whole route: for a closure call around this
        // one, the result is that of this depth only.
        note_route_shift(0, 0)
        return copy(entry.output)
      }
    }
  }
  let reads = IntrospectionRecorder::new()
  let sink = Sink::new()
  let inner = {
    ..engine,
    introspector: engine.introspector.track_with(reads),
    sink,
  }
  let finish = () => {
    if parent is Some(parent) {
      reads.merge_into(parent)
    }
    engine.sink.extend_from_sink(sink)
  }
  let output = {
    errdefer finish()
    f(inner)
  }
  finish()
  if !cacheable(output) {
    return output
  }
  let entry = { input, backend, reads, sink, output: copy(output), }
  match store.entries.get(key) {
    Some(entries) => {
      if entries.length() >= memo_max_entries {
        entries.remove(0) |> ignore
      }
      entries.push(entry)
    }
    None => store.entries[key] = [entry]
  }
  output
}

// Exact comparison of memoized arguments.

///|
/// The content and styles arguments of a memoized layout call.
priv struct LayoutInput {
  content : Content
  styles : StyleChain
  extra : Content?
}

///|
impl Eq for LayoutInput with fn equal(self, other) {
  content_memo_equal(self.content, other.content) &&
  chain_memo_equal(self.styles, other.styles) &&
  (match (self.extra, other.extra) {
    (None, None) => true
    (Some(a), Some(b)) => content_memo_equal(a, b)
    _ => false
  })
}

///|
/// Whether two values are interchangeable for a memoized computation: `==`,
/// but recursing into content, styles, collections and functions, whose
/// Typst equality ignores fields or compares loosely. (Metadata such as
/// spans and locations is covered by the fingerprint of the key.)
fn values_memo_equal(a : Value, b : Value) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  match (a, b) {
    (Content(x), Content(y)) => content_memo_equal(x, y)
    (Array(x), Array(y)) => value_arrays_memo_equal(x.items, y.items)
    (Dict(x), Dict(y)) => {
      if x.map.length() != y.map.length() {
        return false
      }
      let ys = y.map.iter().collect()
      let mut i = 0
      for k, v in x.map {
        let (k2, v2) = ys[i]
        if k != k2 || !values_memo_equal(v, v2) {
          return false
        }
        i += 1
      }
      true
    }
    (Styles(x), Styles(y)) => styles_memo_equal(x.items, y.items)
    (Func(x), Func(y)) => funcs_memo_equal(x, y)
    (Args(x), Args(y)) => args_memo_equal(x, y)
    (Dyn(x), Dyn(y)) => dyns_memo_equal(x, y)
    // Typst's equality says false for these.
    (Gradient(x), Gradient(y)) => x == y
    (Tiling(x), Tiling(y)) => x == y
    _ => a == b
  }
}

///|
/// [values_memo_equal] for dynamic values: recursing into the payloads that
/// hold values, content or functions.
fn dyns_memo_equal(a : DynValue, b : DynValue) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  match (a, b) {
    (State(x), State(y)) => x.key == y.key && values_memo_equal(x.init, y.init)
    (StateUpdate(Set(x)), StateUpdate(Set(y))) => values_memo_equal(x, y)
    (StateUpdate(Func(x)), StateUpdate(Func(y))) => funcs_memo_equal(x, y)
    (CounterUpdate(Func(x)), CounterUpdate(Func(y))) => funcs_memo_equal(x, y)
    (Counter(x), Counter(y)) => counters_memo_equal(x, y)
    (Selector(x), Selector(y)) => selectors_memo_equal(x, y)
    (Tag(Start(x, f1)), Tag(Start(y, f2))) =>
      f1 == f2 && content_memo_equal(x, y)
    (InlineCallback(x), InlineCallback(y)) =>
      content_memo_equal(x.captured, y.captured)
    (BlockSingleCallback(x), BlockSingleCallback(y)) =>
      content_memo_equal(x.captured, y.captured)
    (BlockMultiCallback(x), BlockMultiCallback(y)) =>
      content_memo_equal(x.captured, y.captured)
    // Holds content compared loosely by `==`.
    (CellGrid(_), CellGrid(_)) => false
    // `==` ignores the spans of the lines, which highlighting gives to the
    // raw lines.
    (RawContent(Lines(x)), RawContent(Lines(y))) => {
      if x.length() != y.length() {
        return false
      }
      for i in 0..<x.length() {
        if x[i].0 != y[i].0 || x[i].1 != y[i].1 {
          return false
        }
      }
      true
    }
    _ => a == b
  }
}

///|
fn counters_memo_equal(a : Counter, b : Counter) -> Bool {
  match (a.0, b.0) {
    (Selector(x), Selector(y)) => selectors_memo_equal(x, y)
    _ => a == b
  }
}

///|
fn selectors_memo_equal(a : Selector, b : Selector) -> Bool {
  match (a, b) {
    (Elem(e1, f1), Elem(e2, f2)) =>
      e1 == e2 &&
      (match (f1, f2) {
        (None, None) => true
        (Some(x), Some(y)) => {
          if x.length() != y.length() {
            return false
          }
          for i in 0..<x.length() {
            if x[i].0 != y[i].0 || !values_memo_equal(x[i].1, y[i].1) {
              return false
            }
          }
          true
        }
        _ => false
      })
    (Or(x), Or(y)) | (And(x), And(y)) => {
      if x.length() != y.length() {
        return false
      }
      for i in 0..<x.length() {
        if !selectors_memo_equal(x[i], y[i]) {
          return false
        }
      }
      true
    }
    (
      Before(selector=s1, end=e1, inclusive=i1),
      Before(selector=s2, end=e2, inclusive=i2),
    ) =>
      i1 == i2 && selectors_memo_equal(s1, s2) && selectors_memo_equal(e1, e2)
    (
      After(selector=s1, start=e1, inclusive=i1),
      After(selector=s2, start=e2, inclusive=i2),
    ) =>
      i1 == i2 && selectors_memo_equal(s1, s2) && selectors_memo_equal(e1, e2)
    (Within(selector=s1, ancestor=a1), Within(selector=s2, ancestor=a2)) =>
      selectors_memo_equal(s1, s2) && selectors_memo_equal(a1, a2)
    _ => a == b
  }
}

///|
fn value_arrays_memo_equal(a : Array[Value], b : Array[Value]) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if !values_memo_equal(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
fn args_memo_equal(a : Args, b : Args) -> Bool {
  if a.items.length() != b.items.length() {
    return false
  }
  for i in 0..<a.items.length() {
    let x = a.items[i]
    let y = b.items[i]
    if x.name != y.name || !values_memo_equal(x.value.v, y.value.v) {
      return false
    }
  }
  true
}

///|
fn funcs_memo_equal(a : Func, b : Func) -> Bool {
  match (a.inner, b.inner) {
    (With(f1, a1), With(f2, a2)) =>
      funcs_memo_equal(f1, f2) && args_memo_equal(a1, a2)
    _ => a == b
  }
}

///|
/// Content equality over all stored fields (also internal and synthesized
/// ones), recursively with [values_memo_equal].
fn content_memo_equal(a : Content, b : Content) -> Bool {
  if physical_equal(a, b) || physical_equal(a.fields, b.fields) {
    return a.elem == b.elem
  }
  if a.elem != b.elem || a.fields.length() != b.fields.length() {
    return false
  }
  for i in 0..<a.fields.length() {
    match (a.fields[i], b.fields[i]) {
      (None, None) => ()
      (Some(x), Some(y)) => if !values_memo_equal(x, y) { return false }
      _ => return false
    }
  }
  true
}

///|
fn style_memo_equal(a : Style, b : Style) -> Bool {
  match (a, b) {
    (Property(x), Property(y)) =>
      physical_equal(x, y) ||
      (
        x.elem == y.elem &&
        x.id == y.id &&
        x.span == y.span &&
        x.liftable == y.liftable &&
        x.outside == y.outside &&
        values_memo_equal(x.value, y.value)
      )
    (Recipe(x), Recipe(y)) =>
      physical_equal(x, y) ||
      (
        (match (x.selector, y.selector) {
          (None, None) => true
          (Some(s1), Some(s2)) => selectors_memo_equal(s1, s2)
          _ => false
        }) &&
        x.span == y.span &&
        x.outside == y.outside &&
        (match (x.transform, y.transform) {
          (Content(c1), Content(c2)) => content_memo_equal(c1, c2)
          (Func(f1), Func(f2)) => funcs_memo_equal(f1, f2)
          (Style(s1), Style(s2)) => styles_memo_equal(s1.items, s2.items)
          _ => false
        })
      )
    (Revocation(x), Revocation(y)) => x == y
    _ => false
  }
}

///|
fn styles_memo_equal(a : Array[Style], b : Array[Style]) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if !style_memo_equal(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
/// Style chain equality: the same styles, link by link.
fn chain_memo_equal(a : StyleChain, b : StyleChain) -> Bool {
  let mut a = a
  let mut b = b
  while true {
    if physical_equal(a, b) {
      return true
    }
    if !styles_memo_equal(a.head, b.head) {
      return false
    }
    match (a.tail, b.tail) {
      (None, None) => return true
      (Some(x), Some(y)) => {
        a = x
        b = y
      }
      _ => return false
    }
  }
  true
}

///|
let layout_store : MemoStore[Array[Frame], LayoutInput] = MemoStore::new()

///|
/// Memoize a layout function of `content` and `styles` (and `extra`
/// content) producing frames, keyed by `key` (which must fingerprint every
/// argument of the call except the engine; see the module docs). `f` must
/// use the engine it is given.
pub fn memoized_layout(
  engine : Engine,
  key : U128,
  content : Content,
  styles : StyleChain,
  extra : Content?,
  f : (Engine) -> Fragment raise SourceError,
) -> Fragment raise SourceError {
  let frames = memoize(
    layout_store,
    engine,
    key,
    { content, styles, extra, },
    frames => frames.map(frame => frame.clone()),
    engine => f(engine).0,
    cacheable=frames => frames.iter().all(frame_cacheable),
  )
  Fragment(frames)
}

///|
/// Whether a laid-out frame can be reused: its tags must not hold host
/// closures (`fingerprint_identity`). The same holds for the frames of its
/// tiling paints.
fn frame_cacheable(frame : Frame) -> Bool {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => if !frame_cacheable(group.frame) { return false }
      Tag(Start(content, _)) => {
        let flags = fingerprint_flags_in(() => {
          SipHasher128::new().write(content)
        })
        if (flags & fingerprint_identity) != 0 {
          return false
        }
      }
      Shape(shape, _) => {
        if shape.fill is Some(fill) && !paint_cacheable(fill) {
          return false
        }
        if shape.stroke is Some(stroke) && !paint_cacheable(stroke.paint) {
          return false
        }
      }
      Text(text) => {
        if !paint_cacheable(text.fill) {
          return false
        }
        if text.stroke is Some(stroke) && !paint_cacheable(stroke.paint) {
          return false
        }
      }
      _ => ()
    }
  }
  true
}

///|
/// See [frame_cacheable]: the fingerprint of a tiling's frame (computed
/// once per tiling) records whether it holds such values.
fn paint_cacheable(paint : Paint) -> Bool {
  match paint {
    Tiling(tiling) =>
      (tiling.frame_fingerprint_flags() & fingerprint_identity) == 0
    Solid(_) | Gradient(_) => true
  }
}

// Closure calls (upstream `#[comemo::memoize]` on `typst_eval::eval_closure`).
//
// Upstream memoizes every closure call on the function, the closure and the
// arguments (all hashed, with their spans) and on what the call observes of
// its tracked arguments: the world, the introspector, the traced span, the
// route and the context; the mutations of the sink are replayed. Packages
// that compute a lot (touying, cetz, fletcher) rely on it: a deck that calls
// 160 000 functions with it calls two million without, as every relayout
// and every measurement repeats them.
//
// Here, with the rules of the module docs:
// - The function (the closure's hash and the span) and the arguments are
//   fingerprinted, and the entry keeps them for the exact comparison.
// - The context is tracked like upstream's `Tracked<Context>`: a [Context]
//   notes what was asked of it, and a result only depends on the location
//   and the styles if the call (with the calls inside it) asked for them.
//   The entries of one function and arguments are found by a second
//   fingerprint over what such calls have asked for so far
//   (`ClosureStore.asked`), so that a function called at a thousand
//   locations is not a list of a thousand entries.
// - The route is tracked like upstream's `Tracked<Route>`: for the depth
//   checks (`Route::within`) the entry keeps how much deeper or shallower
//   the route may be without changing an answer (`route_shift_lo`, see
//   `engine.mbt`), and for `Route::contains` the file ids that were asked
//   for ([note_route_query]), whose answers must be the same on the route
//   of a later call.
// - The world, the library and the traced span are fixed for a compilation.
// - Results are values: containers are marked shared, so that a mutation
//   through one holder copies them. A result may hold closures that the
//   call created: they are equal to the ones a repeated call would create
//   (`closures_equal`), like upstream's.

///|
/// A memoized closure call.
priv struct ClosureEntry {
  /// The called function (the closure and the span).
  func : Func
  /// The arguments, as they were before the call consumed them.
  args : Args
  /// The context of the call and what the call asked of it (see [Context]).
  context : Context
  asked : Int
  /// The depth of the route of the call, and the least and greatest change
  /// of it that leaves the answers of all depth checks of the call as they
  /// were.
  depth : Int
  shift_lo : Int
  shift_hi : Int
  /// The route of the call and the file ids it was asked for during the
  /// call.
  route : Route
  queried : Array[@syntax.FileId]
  /// The introspector the result was computed with.
  backend : &IntrospectorBackend
  /// The introspector reads of the call (`None`: none).
  reads : IntrospectionRecorder?
  /// The sink side effects of the call (`None`: none).
  sink : Sink?
  /// The result.
  output : Value
}

///|
/// The cached closure calls of the current compilation.
priv struct ClosureStore {
  mut generation : Int
  /// By the fingerprint of the function and the arguments: what the calls
  /// computed so far asked of their contexts.
  asked : Map[U128, Int]
  /// By that fingerprint and the parts of the context in `asked`.
  entries : Map[U128, Array[ClosureEntry]]
}

///|
let closure_store : ClosureStore = { generation: 0, asked: {}, entries: {}, }

///|
/// The numbers of closure calls that were reused and that were computed
/// since the process started.
let closure_memo_counts : FixedArray[Int] = [0, 0]

///|
/// How many closure calls memoization has reused and how many it has
/// computed since the process started (for tests and measurements).
pub fn closure_memo_stats() -> (Int, Int) {
  (closure_memo_counts[0], closure_memo_counts[1])
}

///|
/// The file ids that routes were asked for (`Route::contains`) while the
/// memoized evaluations in progress ran (closure calls here, source files
/// in `eval/import.mbt`), in order: an evaluation owns what was added since
/// it started, which includes what the evaluations inside it added (comemo
/// tracks `Route::contains`: a result is reused if the route of the later
/// call gives the same answers).
let route_query_log : Array[@syntax.FileId] = []

///|
/// The number of evaluations that are collecting route queries.
let route_query_scopes : Ref[Int] = { val: 0, }

///|
/// Start collecting the route queries of an evaluation; returns the token
/// for [route_queries_end].
pub fn route_queries_begin() -> Int {
  route_query_scopes.val += 1
  route_query_log.length()
}

///|
/// The file ids that routes were asked for since the matching
/// [route_queries_begin] (without repetitions), which ends the collection
/// for this evaluation. The evaluations around it keep them. The result
/// must not be modified.
pub fn route_queries_end(start : Int) -> Array[@syntax.FileId] {
  let queried = if route_query_log.length() == start {
    no_route_queries
  } else {
    let queried = []
    for id in route_query_log[start:] {
      if !queried.contains(id) {
        queried.push(id)
      }
    }
    queried
  }
  route_query_scopes.val -= 1
  if route_query_scopes.val == 0 {
    route_query_log.clear()
  }
  queried
}

///|
/// The result of [route_queries_end] without queries.
let no_route_queries : Array[@syntax.FileId] = []

///|
/// Record that a route was asked whether it contains `id`.
pub fn note_route_query(id : @syntax.FileId) -> Unit {
  if route_query_scopes.val > 0 {
    route_query_log.push(id)
  }
}

///|
/// [note_route_query] for the queries of a reused evaluation.
pub fn note_route_queries(ids : ArrayView[@syntax.FileId]) -> Unit {
  if route_query_scopes.val > 0 {
    for id in ids {
      route_query_log.push(id)
    }
  }
}

///|
/// The fingerprint of the parts of a context that calls asked for.
fn write_asked_context(
  state : SipHasher128,
  context : Context,
  asked : Int,
) -> Unit {
  state.write_usize(asked)
  if (asked & context_read_location) != 0 {
    state.write(context.location)
  }
  if (asked & context_read_styles) != 0 {
    match context.styles {
      None => state.write_discriminant(0)
      Some(styles) => {
        state.write_discriminant(1)
        state.write_u128(styles.memo_hash())
      }
    }
  }
  if (asked & context_read_introspect) != 0 {
    state.write_bool(context.location is None && context.styles is None)
  }
}

///|
/// Whether the cached call may be reused for this one (the fingerprints of
/// the function, the arguments and the asked parts of the context are
/// equal). `shift` is how much deeper the route is now.
fn ClosureEntry::matches(
  self : ClosureEntry,
  func : Func,
  engine : Engine,
  context : Context,
  args : Args,
  shift : Int,
) -> Bool {
  guard self.shift_lo <= shift &&
    shift <= self.shift_hi &&
    self.func.span == func.span else {
    return false
  }
  guard funcs_memo_equal(self.func, func) else { return false }
  if !physical_equal(self.context, context) {
    let asked = self.asked
    if (asked & context_read_location) != 0 {
      guard self.context.location == context.location else { return false }
    }
    if (asked & context_read_styles) != 0 {
      match (self.context.styles, context.styles) {
        (None, None) => ()
        (Some(a), Some(b)) => if !chain_memo_equal(a, b) { return false }
        _ => return false
      }
    }
    if (asked & context_read_introspect) != 0 {
      guard (self.context.location is None && self.context.styles is None) ==
        (context.location is None && context.styles is None) else {
        return false
      }
    }
  }
  guard args_memo_equal(self.args, args) else { return false }
  for id in self.queried {
    guard self.route.contains(id) == engine.route.contains(id) else {
      return false
    }
  }
  physical_equal(self.backend, engine.introspector.backend) ||
  (match self.reads {
    None => true
    Some(reads) => !reads.lossy && reads.validate(engine.introspector)
  })
}

///|
/// Memoize the closure call `f(func, closure, engine, context, args)` (see
/// above). `f` must use the engine it is given.
pub fn memoized_closure(
  func : Func,
  closure : Closure,
  engine : Engine,
  context : Context,
  args : Args,
  f : (Func, Closure, Engine, Context, Args) -> Value raise SourceError,
) -> Value raise SourceError {
  let generation = memo_generation.val
  if generation == 0 {
    return f(func, closure, engine, context, args)
  }
  let store = closure_store
  if store.generation != generation {
    store.asked.clear()
    store.entries.clear()
    store.generation = generation
  }
  // The fingerprints. Their flags are not those of a fingerprint that may
  // be running around this call.
  let outer_flags = fingerprint_flags.val
  fingerprint_flags.val = 0
  let state = SipHasher128::new()
  state.write(func)
  state.write(args)
  let base = state.finish128()
  let depth = engine.route.depth()
  let parent = engine.introspector.recorder
  let known = store.asked.get(base)
  if known is Some(asked) {
    let state = SipHasher128::new()
    state.write_u128(base)
    write_asked_context(state, context, asked)
    let key = state.finish128()
    if (fingerprint_flags.val & fingerprint_lossy) == 0 &&
      store.entries.get(key) is Some(entries) {
      for entry in entries {
        let shift = depth - entry.depth
        if entry.matches(func, engine, context, args, shift) {
          fingerprint_flags.val = outer_flags
          closure_memo_counts[0] += 1
          // What the call did to its tracked arguments.
          context.reads = context.reads | entry.asked
          note_route_shift(entry.shift_lo - shift, entry.shift_hi - shift)
          note_route_queries(entry.queried)
          if entry.reads is Some(reads) && parent is Some(parent) {
            reads.merge_into(parent)
          }
          if entry.sink is Some(sink) {
            engine.sink.extend_from_sink(sink)
          }
          return entry.output
        }
      }
    }
  }
  let lossy = (fingerprint_flags.val & fingerprint_lossy) != 0
  fingerprint_flags.val = outer_flags
  if lossy {
    return f(func, closure, engine, context, args)
  }
  closure_memo_counts[1] += 1
  // The call consumes the arguments.
  let snapshot = args.copy()
  let reads = IntrospectionRecorder::new()
  let sink = Sink::new()
  let inner = {
    ..engine,
    introspector: engine.introspector.track_with(reads),
    sink,
  }
  // Track the context and the route for this call alone.
  let outer_asked = context.reads
  context.reads = 0
  let outer_lo = route_shift_lo.val
  let outer_hi = route_shift_hi.val
  route_shift_lo.val = route_shift_min
  route_shift_hi.val = route_shift_max
  route_shift_scopes.val += 1
  let queries = route_queries_begin()
  let mut asked = 0
  let mut shift_lo = 0
  let mut shift_hi = 0
  let mut queried = no_route_queries
  // What the call did, it also did for the calls around it.
  let finish = () => {
    asked = context.reads
    context.reads = outer_asked | asked
    shift_lo = route_shift_lo.val
    shift_hi = route_shift_hi.val
    route_shift_lo.val = outer_lo
    route_shift_hi.val = outer_hi
    route_shift_scopes.val -= 1
    note_route_shift(shift_lo, shift_hi)
    queried = route_queries_end(queries)
    if parent is Some(parent) {
      reads.merge_into(parent)
    }
    engine.sink.extend_from_sink(sink)
  }
  let output = {
    errdefer finish()
    f(func, closure, inner, context, args)
  }
  finish()
  // The store may belong to another compilation by now (a nested one).
  guard store.generation == generation else { return output }
  let known = store.asked.get(base)
  let all = match known {
    Some(known) => known | asked
    None => asked
  }
  if known != Some(all) {
    // Entries under what was asked before are not found again; they are
    // few (the set only grows, three times at most).
    store.asked[base] = all
  }
  let outer_flags = fingerprint_flags.val
  let state = SipHasher128::new()
  state.write_u128(base)
  write_asked_context(state, context, all)
  let key = state.finish128()
  fingerprint_flags.val = outer_flags
  let entry : ClosureEntry = {
    func,
    args: snapshot,
    context,
    asked,
    depth,
    shift_lo,
    shift_hi,
    route: engine.route,
    queried,
    backend: engine.introspector.backend,
    reads: if reads.calls.is_empty() && !reads.lossy {
      None
    } else {
      Some(reads)
    },
    sink: if sink.is_empty() {
      None
    } else {
      Some(sink)
    },
    output: output.shared(),
  }
  match store.entries.get(key) {
    Some(entries) => {
      if entries.length() >= memo_max_entries {
        entries.remove(0) |> ignore
      }
      entries.push(entry)
    }
    None => store.entries[key] = [entry]
  }
  output
}
