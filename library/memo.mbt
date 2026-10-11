// Memoization (not upstream: a replacement for comemo's `#[comemo::memoize]`
// on `layout_par_impl`, `layout_fragment_impl`, the counter sequence, the
// works of a bibliography (`Works::generate_impl`, `bibliography.mbt`) and
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
//   tracks what the call observes). The works have neither: no locator,
//   and a route that is tracked ([memoize], `tracks_route`).
// - Fingerprints do not always distinguish what the computation can
//   observe: host closures compare by identity but fingerprint by their key
//   (and a `Fingerprint` that does not capture all data marks itself lossy;
//   none does at the moment). So an entry also keeps the arguments and is
//   only reused if they are equal ([values_memo_equal]: `==`, but recursing
//   into content, styles, arrays, dictionaries, functions and dynamic
//   values, where Typst's equality is looser). Closures compare by their
//   hash, like upstream's (`closures_equal`): equal fingerprints are equal
//   closures, if the host closures they captured are the same objects
//   ([closures_memo_equal]).
// - Modules are taken by their hash, as upstream's memoized calls take
//   them (comemo compares the hashes of the arguments), although `==`
//   compares the objects ([modules_memo_equal]). Two plugins without
//   functions are the same argument: `(a, b).map(m => m == a)` is
//   `(true, true)`, upstream's answer. And a call that is found returns
//   the module it returned before, which `==` tells from the module of the
//   same file evaluated later. (The owner's decision of 2026-10-11:
//   exactly as upstream. The port told such modules apart before, by
//   identity, and was the stricter one.)
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
// - World reads of the call (sources, files, the font book, fonts, the
//   date) are recorded with the fingerprints of their answers
//   (`tracked_world.mbt`). A cached result is only reused if they give the
//   same answers in the scope of the later call; they are then noted for
//   the calls around it, as if the call had run. A call that read a file
//   that changes during a scope is not cached. Nothing is looked up or
//   stored for an engine whose world is not in a scope.
// - The library is compared by identity (upstream hashes it into the key
//   of every memoized function that builds an engine).
//
// - What the flags of a key's fingerprint mean for its entry is one rule
//   for every store ([MemoKey]): nothing is kept under a lossy key, and an
//   entry whose key holds a host closure ends with its compilation.
//
// Caches only live for one compilation ([with_layout_memo]: its evaluation
// and its introspection iterations). The world reads of an entry are
// therefore validated in the scope they were recorded in, where they
// hold, unless an engine with another world is used inside a compilation
// (a host function that evaluates with a world of its own).

///|
/// A memoized result.
priv struct MemoEntry[T, I] {
  /// The arguments that must be equal for reuse (beyond the key).
  input : I
  /// The library the result was computed with.
  library : Library
  /// The world reads of the call.
  world : WorldReads
  /// The introspector the result was computed with.
  backend : &IntrospectorBackend
  /// The introspector reads of the call.
  reads : IntrospectionRecorder
  /// The sink side effects of the call.
  sink : Sink
  /// The compilation the entry ends with ([MemoKey::compilation]).
  compilation : Int
  /// The result.
  output : T
}

///|
/// The cached results of one memoized function.
priv struct MemoStore[T, I] {
  /// The compilation the entries belong to.
  mut generation : Int
  mut entries : Map[U128, Array[MemoEntry[T, I]]]
  /// Whether [set_memo_check] knows the store (`memo_check.mbt`).
  mut checked : Bool
}

///|
fn[T, I] MemoStore::new() -> MemoStore[T, I] {
  { generation: 0, entries: {}, checked: false, }
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
/// The number of compilations in progress (one inside the other).
let compilation_depth : Ref[Int] = { val: 0, }

///|
/// Run `f` (a compilation) with fresh memoization caches. The caches are
/// only used by engines whose world is in a scope
/// ([TrackedWorld::scoped]): a compilation runs inside one.
pub fn[T] with_layout_memo(
  f : () -> T raise SourceError,
) -> T raise SourceError {
  let outer = memo_generation.val
  memo_counter.val += 1
  memo_generation.val = if memo_enabled.val { memo_counter.val } else { 0 }
  if compilation_depth.val == 0 {
    // The world may have other files now than in the compilation before.
    sweep_data_hashes()
  }
  compilation_depth.val += 1
  let result = {
    errdefer {
      memo_generation.val = outer
      compilation_depth.val -= 1
    }
    f()
  }
  memo_generation.val = outer
  compilation_depth.val -= 1
  result
}

///|
/// The number of [evict] calls since the caches were dropped.
let evictions : Ref[Int] = { val: 0, }

///|
/// Evict the caches (upstream `comemo::evict(max_age)`, which drops the
/// memoized results that were not used for `max_age` evictions; a watching
/// compiler calls it after every compilation).
///
/// Memoized calls end with their compilation here. What outlives it is
/// data decoded from bytes, found again by its content: syntaxes and
/// themes of `raw`, bibliographies and CSL styles, PDF documents, plugins
/// and the results of their calls. (The works of a bibliography were
/// among them, in a cell that was found by the engine's introspector
/// object; they are an entry of [memoize] now.) A process that compiles a world whose
/// files change would keep every version of them. They have no age, so
/// they are dropped as a whole on every `max_age`-th call instead (decoding
/// them again is all it costs). Must not be called during a compilation.
///
/// The results kept by content (`memo_content.mbt`: decoded raster images,
/// highlighted raw text, the PDF exporter's images) have ages like
/// comemo's: each call makes them older by one and drops those that were
/// not found for more than `max_age` calls. The hashes of data that are
/// kept by the identity of the `Bytes` are swept ([sweep_data_hashes]).
pub fn evict(max_age : Int) -> Unit {
  for evictor in evictors {
    evictor(max_age)
  }
  if max_age == 0 {
    data_hashes.clear()
  } else {
    sweep_data_hashes()
  }
  evictions.val += 1
  if evictions.val < max_age {
    return
  }
  evictions.val = 0
  raw_syntax_cache.clear()
  raw_theme_cache.clear()
  bibliography_cache.clear()
  csl_style_cache.clear()
  pdf_document_cache.clear()
  plugin_call_cache.clear()
  plugin_transition_cache.clear()
  plugin_module_cache.clear()
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
/// The key of a memoized call: the fingerprint of its hashed arguments,
/// with the flags of that fingerprint (`fingerprint_flags` in
/// `utils_hash.mbt`), which say what the fingerprint does not: whether an
/// equal one is the same arguments, and for how long.
///
/// This is the one place that decides it, for every store of memoized
/// calls (`memoize`, [memoized_closure]) and for the results kept by
/// content whose key can hold such values (highlighted raw text):
/// [MemoKey::memoizable] and [MemoKey::compilation]. (The module store of
/// `eval/import.mbt` has no key of this kind: an entry is a source and a
/// library, compared as objects.) What is said of results is said where
/// they are made: frames whose tags hold host closures are not kept
/// ([frame_cacheable]), and an entry whose introspector reads returned
/// them is only taken for the introspector it was computed with
/// (`IntrospectionRecorder.lossy`).
#valtype
pub struct MemoKey {
  priv hash : U128
  priv flags : Int
}

///|
/// The fingerprint written by `f` (a memoization key), with its flags.
pub fn memo_fingerprint(f : (SipHasher128) -> Unit) -> MemoKey {
  let state = SipHasher128::new()
  let outer = fingerprint_flags.val
  fingerprint_flags.val = 0
  f(state)
  let flags = fingerprint_flags.val
  fingerprint_flags.val = outer | flags
  { hash: state.finish128(), flags, }
}

///|
/// The fingerprint.
pub fn MemoKey::hash(self : MemoKey) -> U128 {
  self.hash
}

///|
/// Whether a result may be looked up and kept under this key: not if its
/// fingerprint leaves out data (`fingerprint_lossy`; no fingerprint does
/// today). A call with such a key is computed every time.
pub fn MemoKey::memoizable(self : MemoKey) -> Bool {
  (self.flags & fingerprint_lossy) == 0
}

///|
/// The compilation that an entry under this key ends with, for
/// [compilation_finds]: zero if any compilation may find it.
///
/// A key that holds a host closure (`fingerprint_identity`) can only be
/// the key of the same closures, as objects, and those are a
/// compilation's: a host makes its closures per compilation (`doc`'s
/// `Session.hosts`), and the keys that tell them apart are only promised
/// to be unique within one. So an entry under such a key is never found by
/// a later compilation, whatever its store keeps
/// (`docs/incremental-design.md`, section 5.4). Outside of a compilation
/// it is found by nobody.
pub fn MemoKey::compilation(self : MemoKey) -> Int {
  if (self.flags & fingerprint_identity) == 0 {
    0
  } else if memo_generation.val == 0 {
    -1
  } else {
    memo_generation.val
  }
}

///|
/// Whether the compilation in progress may find an entry that ends with
/// the compilation `bound` ([MemoKey::compilation]).
pub fn compilation_finds(bound : Int) -> Bool {
  bound == 0 || bound == memo_generation.val
}

///|
/// Memoize `f`, keyed by `key` (which must fingerprint every argument of the
/// call except the engine; see the module docs) and `input` (compared for
/// equality). `f` must use the engine it is given. `copy` produces an
/// independent copy of a result.
///
/// The route: upstream tracks it (`Tracked<Route>`), so a result is found
/// on any route that answers what the call asked as before. The key of a
/// layout or of a counter sequence holds the whole route instead, and a
/// result that is found is that of its depth only. With `tracks_route`
/// the key does not hold the route and the call must not ask it anything
/// (no depth check, no `Route::contains`, in `f` or in a memoized call
/// inside it): that is noticed, as for a closure call, and a result that
/// asked is not kept. Then a result is found on every route, as upstream.
fn[T, I : Eq] memoize(
  store : MemoStore[T, I],
  engine : Engine,
  key : MemoKey,
  input : I,
  copy : (T) -> T,
  f : (Engine) -> T raise SourceError,
  cacheable? : (T) -> Bool = _ => true,
  // What the recording check calls the call (a function of the input, so
  // that passing it allocates nothing).
  label? : (I) -> String = _ => "memoized call",
  tracks_route? : Bool = false,
) -> T raise SourceError {
  let generation = memo_generation.val
  let world = engine.world
  if generation == 0 || !world.in_scope() || !key.memoizable() {
    return f(engine)
  }
  if store.generation != generation {
    store.entries.clear()
    store.generation = generation
  }
  let compilation = key.compilation()
  // The traced span is not one per compilation (an evaluated string runs
  // without): a result computed there replays no traced values.
  let key = match engine.traced.0 {
    None => key.hash
    Some(span) => {
      let state = SipHasher128::new()
      state.write_u128(key.hash)
      state.write(span)
      state.finish128()
    }
  }
  let parent = engine.introspector.recorder
  let backend = engine.introspector.backend
  if store.entries.get(key) is Some(entries) {
    for entry in entries {
      if compilation_finds(entry.compilation) &&
        entry.input == input &&
        physical_equal(entry.library, engine.library) &&
        (
          physical_equal(entry.backend, backend) ||
          (!entry.reads.lossy && entry.reads.validate(engine.introspector))
        ) &&
        // Last: this makes the world reads that the scope has no answer
        // for and notes them for the calls around this one.
        world.validate(entry.world) {
        if parent is Some(parent) {
          entry.reads.merge_into(parent)
        }
        engine.sink.extend_from_sink(entry.sink)
        // The key holds the whole route: for a closure call around this
        // one, the result is that of this depth only. (An entry that
        // tracks its route asked nothing of it.)
        if !tracks_route {
          note_route_shift(0, 0)
        }
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
  let route_mark = if tracks_route { Some(RouteMark::begin()) } else { None }
  let mark = world.reads_begin()
  let output = {
    errdefer {
      world.reads_abort(mark)
      if route_mark is Some(route_mark) {
        route_mark.end() |> ignore
      }
      finish()
    }
    f(inner)
  }
  let world_reads = world.reads_end(mark)
  let asked_route = route_mark is Some(route_mark) && route_mark.end()
  finish()
  // A call that read a file that changes during the scope is not kept, nor
  // one that asked a route its key does not hold.
  if world_reads.is_volatile() || asked_route || !cacheable(output) {
    return output
  }
  // The store may belong to another compilation by now (a nested one).
  guard store.generation == generation else { return output }
  if memo_check_enabled() {
    if !store.checked {
      store.checked = true
      register_memo_check_store(() => store.set_aside())
    }
    memo_check_reads(() => label(input), world, world_reads, () => {
      let again = {
        ..engine,
        introspector: engine.introspector.track_with(
          IntrospectionRecorder::new(),
        ),
        sink: Sink::new(),
      }
      f(again) |> ignore
    })
  }
  let entry = {
    input,
    library: engine.library,
    world: world_reads,
    backend,
    reads,
    sink,
    compilation,
    output: copy(output),
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

///|
/// What a call that tracks its route ([memoize] with `tracks_route`) set
/// aside when it started: the depth bounds of the closure call around it
/// (`route_shift_lo` in `engine.mbt`) and where its route queries start.
priv struct RouteMark {
  lo : Int
  hi : Int
  queries : Int
}

///|
/// Starts noticing what is asked of routes, for one call.
fn RouteMark::begin() -> RouteMark {
  let mark = {
    lo: route_shift_lo.val,
    hi: route_shift_hi.val,
    queries: route_queries_begin(),
  }
  route_shift_lo.val = route_shift_min
  route_shift_hi.val = route_shift_max
  route_shift_scopes.val += 1
  mark
}

///|
/// Ends it: whether anything was asked of a route since
/// [RouteMark::begin]. What was asked is also noted for the calls around
/// this one.
fn RouteMark::end(self : RouteMark) -> Bool {
  let lo = route_shift_lo.val
  let hi = route_shift_hi.val
  route_shift_lo.val = self.lo
  route_shift_hi.val = self.hi
  route_shift_scopes.val -= 1
  note_route_shift(lo, hi)
  let queried = route_queries_end(self.queries)
  // "No bound" is not one number here: a closure call or a module
  // evaluation that is found on a route `shift` deeper notes its bounds
  // moved by `shift`, also where it has none
  // ([RouteShifts::note_reused]), so what is far outside the depths that
  // routes can have is no question.
  lo > route_shift_min / 2 || hi < route_shift_max / 2 || !queried.is_empty()
}

///|
/// Runs `f`, which works on a route of its own and not on one that extends
/// the route of the calls in progress (upstream: `eval_string` starts at
/// `Route::default()`, and its route is no tracked argument of whoever
/// calls it). What is asked of routes is noted in state of the process
/// (`route_shift_lo`, [route_query_log]), which cannot tell one route from
/// another: without this, a depth check on the fresh route counts as a
/// question to the route of the memoized calls around `f`, which binds a
/// closure call to its depth and keeps an entry that tracks its route from
/// being stored ([memoize], `tracks_route`).
fn[T] with_own_route(f : () -> T raise SourceError) -> T raise SourceError {
  let lo = route_shift_lo.val
  let hi = route_shift_hi.val
  let scopes = route_shift_scopes.val
  let query_scopes = route_query_scopes.val
  // (A memoized call inside `f` empties the log when it is the only one
  // that collects.)
  let queries = if route_query_log.is_empty() {
    no_route_queries
  } else {
    route_query_log.copy()
  }
  route_shift_scopes.val = 0
  route_query_scopes.val = 0
  defer {
    route_shift_lo.val = lo
    route_shift_hi.val = hi
    route_shift_scopes.val = scopes
    route_query_scopes.val = query_scopes
    route_query_log.clear()
    route_query_log.append(queries)
  }
  f()
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
    (Module(x), Module(y)) => modules_memo_equal(x, y)
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
    (Closure(x), Closure(y)) => closures_memo_equal(x, y)
    _ => a == b
  }
}

///|
/// Whether two closures are one argument of a memoized call: equal as
/// closures are (`closures_equal`: by their hash, as upstream's), and with
/// the same host closures among what they captured, as objects and in the
/// order in which the hash visits them. A host closure's part in a hash is
/// its key, which says which function it is only as long as the host keeps
/// its keys apart; the entry does not take the hash's word for it, as it
/// does not for a host closure that is an argument itself.
fn closures_memo_equal(a : Closure, b : Closure) -> Bool {
  if physical_equal(a, b) {
    return true
  }
  // The flags of the closures' data are not those of a fingerprint that may
  // be running around this comparison.
  let outer = fingerprint_flags.val
  fingerprint_flags.val = 0
  let x = SipHasher128::new()
  a.fingerprint_lazy(x)
  let y = SipHasher128::new()
  b.fingerprint_lazy(y)
  let flags = fingerprint_flags.val
  fingerprint_flags.val = outer
  x.finish128() == y.finish128() &&
  (
    (flags & fingerprint_host) == 0 ||
    same_hosts(() => a.fingerprint_lazy(SipHasher128::new()), () => {
      b.fingerprint_lazy(SipHasher128::new())
    })
  )
}

///|
/// Whether two modules are one argument of a memoized call. Upstream's
/// memoized calls (comemo) take their arguments by their hashes, and
/// `Hash for Module` is the name and what the module holds: two module
/// objects that hold the same are one argument there, although `==` tells
/// them apart (`PartialEq for Module` compares the objects). The port
/// follows: the same fingerprint is the same argument. So
/// `(a, b).map(m => m == a)` is `(true, true)` for two plugins without
/// functions, as upstream's is (`typst/oracle_wbtest.mbt`, "modules: ..").
/// Host closures in what the modules hold are compared as objects, as
/// everywhere (upstream has none).
fn modules_memo_equal(a : Module, b : Module) -> Bool {
  if a == b {
    return true
  }
  let outer = fingerprint_flags.val
  fingerprint_flags.val = 0
  let x = hash128(a)
  let y = hash128(b)
  let flags = fingerprint_flags.val
  fingerprint_flags.val = outer
  x == y &&
  (
    (flags & fingerprint_host) == 0 ||
    same_hosts(() => hash128(a) |> ignore, () => hash128(b) |> ignore)
  )
}

///|
/// Whether two fingerprint computations visit the same host closures, as
/// objects, in the same order (for values whose fingerprints are equal:
/// the walks then have one shape).
fn same_hosts(a : () -> Unit, b : () -> Unit) -> Bool {
  let outer = fingerprint_flags.val
  let x = fingerprint_hosts_in(a)
  let y = fingerprint_hosts_in(b)
  fingerprint_flags.val = outer
  if x.length() != y.length() {
    return false
  }
  for i in 0..<x.length() {
    if !physical_equal(x[i], y[i]) {
      return false
    }
  }
  true
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
  key : MemoKey,
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
    label=input => "layout of \{input.content.elem.name()}",
  )
  Fragment(frames)
}

///|
/// Whether a laid-out frame can be reused: its tags must not hold host
/// closures (`fingerprint_identity`), which compare by identity and whose
/// fingerprint is a key of the host's. The same holds for the frames of
/// its tiling paints.
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
// - The traced span is part of the fingerprint (an evaluated string runs
//   without one). The world is tracked like upstream's `Tracked<dyn World>`
//   (`tracked_world.mbt`): the reads of a call are kept with their answers,
//   which must be the same in the scope of a later call. The library is
//   compared by identity (upstream hashes it).
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
  /// The files whose code ran in the call (see `traced_file_log`), for the
  /// evaluation of a source file that reuses the call; `None` if the call
  /// was not computed inside one, which then cannot reuse it.
  traced_files : Array[@syntax.FileId]?
  /// The library the result was computed with.
  library : Library
  /// The world reads of the call.
  world : WorldReads
  /// The introspector the result was computed with.
  backend : &IntrospectorBackend
  /// The introspector reads of the call (`None`: none).
  reads : IntrospectionRecorder?
  /// The sink side effects of the call (`None`: none).
  sink : Sink?
  /// The compilation the entry ends with ([MemoKey::compilation]).
  compilation : Int
  /// The result.
  output : Value
}

///|
/// The cached closure calls of the current compilation.
priv struct ClosureStore {
  mut generation : Int
  /// By the fingerprint of the function and the arguments: what the calls
  /// computed so far asked of their contexts.
  mut asked : Map[U128, Int]
  /// By that fingerprint and the parts of the context in `asked`.
  mut entries : Map[U128, Array[ClosureEntry]]
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
/// How much shallower and deeper a route may be without changing the
/// answer of a depth check (`route_shift_lo`, `route_shift_hi` in
/// `engine.mbt`): what a memoized evaluation of a source file keeps of the
/// depth checks made in it ([route_shifts_end]), and, while it runs, the
/// bounds of the evaluation around it ([route_shifts_begin]).
#valtype
pub struct RouteShifts {
  priv lower : Int
  priv upper : Int
}

///|
/// Starts tracking the depth checks (`Route::within`, which comemo tracks)
/// of an evaluation of a source file, as [memoized_closure] does for a
/// closure call. Returns the bounds of the evaluation around it, for
/// [route_shifts_end].
pub fn route_shifts_begin() -> RouteShifts {
  let outer = { lower: route_shift_lo.val, upper: route_shift_hi.val, }
  route_shift_lo.val = route_shift_min
  route_shift_hi.val = route_shift_max
  route_shift_scopes.val += 1
  outer
}

///|
/// The bounds of the evaluation that the matching [route_shifts_begin]
/// started: by how much the depth of its route may change without changing
/// the answer of a depth check made in it. The evaluation around it has
/// them too.
pub fn route_shifts_end(outer : RouteShifts) -> RouteShifts {
  let own = { lower: route_shift_lo.val, upper: route_shift_hi.val, }
  route_shift_lo.val = outer.lower
  route_shift_hi.val = outer.upper
  route_shift_scopes.val -= 1
  note_route_shift(own.lower, own.upper)
  own
}

///|
/// Whether an evaluation with these bounds gives the same answers to its
/// depth checks on a route that is `shift` deeper.
pub fn RouteShifts::allows(self : RouteShifts, shift : Int) -> Bool {
  self.lower <= shift && shift <= self.upper
}

///|
/// Notes the depth checks of an evaluation that is reused on a route that
/// is `shift` deeper for the evaluations around it, as if it had run.
pub fn RouteShifts::note_reused(self : RouteShifts, shift : Int) -> Unit {
  note_route_shift(self.lower - shift, self.upper - shift)
}

///|
/// The files whose code ran in the evaluations in progress that collect
/// them, in order: an evaluation owns what was added since it started
/// (not upstream: comemo tracks `Traced::get`, which every `Vm` asks for
/// the file of its code, and reuses the evaluation of a source file if the
/// traced span of the later evaluation gives the same answers, that is, if
/// it lies in none of these files or is the same span). Only the
/// evaluations of source files collect (`eval_source_memoized`), and the
/// closure calls inside them, whose files are theirs; closure calls
/// elsewhere do not, they have the traced span in their key.
let traced_file_log : Ref[Array[@syntax.FileId]] = { val: [], }

///|
/// The number of evaluations that are collecting traced files.
let traced_file_scopes : Ref[Int] = { val: 0, }

///|
/// Whether an evaluation is collecting traced files.
pub fn traced_files_active() -> Bool {
  traced_file_scopes.val > 0
}

///|
/// Start collecting the traced files of an evaluation; returns the token
/// for [traced_files_end].
pub fn traced_files_begin() -> Int {
  traced_file_scopes.val += 1
  traced_file_log.val.length()
}

///|
/// The files noted since the matching [traced_files_begin] (without
/// repetitions), which ends the collection for this evaluation. The
/// evaluations around it keep them (once each: the log does not grow with
/// the number of calls). The result must not be modified.
pub fn traced_files_end(start : Int) -> Array[@syntax.FileId] {
  let log = traced_file_log.val
  let files = if log.length() == start {
    no_route_queries
  } else {
    let files = []
    for id in log[start:] {
      if !files.contains(id) {
        files.push(id)
      }
    }
    files
  }
  traced_file_scopes.val -= 1
  if traced_file_scopes.val == 0 {
    log.clear()
  } else {
    log.truncate(start)
    log.append(files)
  }
  files
}

///|
/// Record that code of the file `id` runs (a `Vm` asks `Traced::get(id)`).
pub fn note_traced_file(id : @syntax.FileId) -> Unit {
  if traced_file_scopes.val > 0 {
    let log = traced_file_log.val
    // Mostly the file of the call before.
    if log.last() is Some(last) && last == id {
      return
    }
    log.push(id)
  }
}

///|
/// [note_traced_file] for the files of a reused evaluation.
pub fn note_traced_files(ids : ArrayView[@syntax.FileId]) -> Unit {
  if traced_file_scopes.val > 0 {
    for id in ids {
      note_traced_file(id)
    }
  }
}

///|
/// The collection of traced files that an evaluation with a traced span of
/// its own set aside ([own_traced_begin]).
pub struct OwnTraced {
  priv log : Array[@syntax.FileId]
  priv scopes : Int
}

///|
/// Start an evaluation with a traced span of its own (an evaluated string
/// runs without one, upstream `Traced::default().track()`): the files of
/// its code are not those of the evaluations around it. Returns what
/// [own_traced_end] restores.
pub fn own_traced_begin() -> OwnTraced {
  let saved = { log: traced_file_log.val, scopes: traced_file_scopes.val, }
  traced_file_log.val = []
  traced_file_scopes.val = 0
  saved
}

///|
/// End the evaluation that [own_traced_begin] started.
pub fn own_traced_end(saved : OwnTraced) -> Unit {
  traced_file_log.val = saved.log
  traced_file_scopes.val = saved.scopes
}

///|
/// Whether the traced spans `a` and `b` give the same answers for the files
/// `asked` (`Traced::get`).
pub fn traced_answers_equal(
  a : Traced,
  b : Traced,
  asked : ArrayView[@syntax.FileId],
) -> Bool {
  if a.0 == b.0 {
    return true
  }
  for id in asked {
    if a.get(id) != b.get(id) {
      return false
    }
  }
  true
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
    self.func.span == func.span &&
    physical_equal(self.library, engine.library) else {
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
  guard physical_equal(self.backend, engine.introspector.backend) ||
    (match self.reads {
      None => true
      Some(reads) => !reads.lossy && reads.validate(engine.introspector)
    }) else {
    return false
  }
  // Last: this makes the world reads that the scope has no answer for and
  // notes them for the calls around this one.
  engine.world.validate(self.world)
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
  let world = engine.world
  if generation == 0 || !world.in_scope() {
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
  // The traced span is not one per compilation: an evaluated string runs
  // without (`eval_root`), and a call that ran there traced nothing.
  // (Upstream tracks `Traced::get`; the whole span is stricter, and what
  // the call returns does not depend on it.)
  state.write(engine.traced.0)
  let base = state.finish128()
  let depth = engine.route.depth()
  let parent = engine.introspector.recorder
  let known = store.asked.get(base)
  let collecting = traced_files_active()
  if known is Some(asked) {
    let state = SipHasher128::new()
    state.write_u128(base)
    write_asked_context(state, context, asked)
    let key : MemoKey = {
      hash: state.finish128(),
      flags: fingerprint_flags.val,
    }
    if key.memoizable() && store.entries.get(key.hash) is Some(entries) {
      for entry in entries {
        let shift = depth - entry.depth
        if compilation_finds(entry.compilation) &&
          (!collecting || entry.traced_files is Some(_)) &&
          entry.matches(func, engine, context, args, shift) {
          fingerprint_flags.val = outer_flags
          closure_memo_counts[0] += 1
          // What the call did to its tracked arguments.
          context.reads = context.reads | entry.asked
          note_route_shift(entry.shift_lo - shift, entry.shift_hi - shift)
          note_route_queries(entry.queried)
          if entry.traced_files is Some(files) {
            note_traced_files(files)
          }
          if entry.reads is Some(reads) && parent is Some(parent) {
            reads.merge_into(parent)
          }
          if entry.sink is Some(sink) {
            engine.sink.extend_from_sink(sink)
          }
          // The call consumed all of its arguments (`args.finish()`), which
          // a caller that passed its own arguments on goes on to check.
          args.items.clear()
          return entry.output
        }
      }
    }
  }
  // The flags of the function and the arguments (and of the parts of the
  // context that calls asked for so far).
  let base_flags = fingerprint_flags.val
  fingerprint_flags.val = outer_flags
  if !({ hash: base, flags: base_flags, } : MemoKey).memoizable() {
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
  let traced_start = if collecting { traced_files_begin() } else { -1 }
  let mark = world.reads_begin()
  let mut asked = 0
  let mut shift_lo = 0
  let mut shift_hi = 0
  let mut queried = no_route_queries
  let mut traced_files : Array[@syntax.FileId]? = None
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
    if collecting {
      traced_files = Some(traced_files_end(traced_start))
    }
    if parent is Some(parent) {
      reads.merge_into(parent)
    }
    engine.sink.extend_from_sink(sink)
  }
  let output = {
    errdefer {
      world.reads_abort(mark)
      finish()
    }
    f(func, closure, inner, context, args)
  }
  let world_reads = world.reads_end(mark)
  finish()
  // A call that read a file that changes during the scope is not kept.
  guard !world_reads.is_volatile() else { return output }
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
  fingerprint_flags.val = 0
  let state = SipHasher128::new()
  state.write_u128(base)
  write_asked_context(state, context, all)
  // The parts of the context that the call asked for are part of its key,
  // with their flags.
  let key : MemoKey = {
    hash: state.finish128(),
    flags: base_flags | fingerprint_flags.val,
  }
  fingerprint_flags.val = outer_flags
  guard key.memoizable() else { return output }
  if memo_check_enabled() {
    let label = () => "call of \{func.name().unwrap_or("a closure")}"
    memo_check_reads(label, world, world_reads, () => {
      let again = {
        ..engine,
        introspector: engine.introspector.track_with(
          IntrospectionRecorder::new(),
        ),
        sink: Sink::new(),
      }
      // What the call asks of its context is the first run's.
      let context_reads = context.reads
      defer {
        context.reads = context_reads
      }
      f(func, closure, again, context, snapshot.copy()) |> ignore
    })
  }
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
    traced_files,
    library: engine.library,
    world: world_reads,
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
    compilation: key.compilation(),
    output: output.shared(),
  }
  let key = key.hash
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
