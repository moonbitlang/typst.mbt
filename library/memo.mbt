// Memoization (not upstream: a replacement for comemo's `#[comemo::memoize]`
// on `layout_par_impl`, `layout_fragment_impl` and the counter/state
// sequences).
//
// Upstream memoizes these functions on all their arguments, tracking which
// parts of the tracked arguments (introspector, locator, route, sink) the call
// observed. That makes later introspection iterations and repeated
// measurements (e.g. of grid cells) cheap. Here:
//
// - Entries are found by a fingerprint of the untracked arguments (content,
//   style chain, regions, ...) plus the fully resolved locator and the route
//   (stricter than upstream, which only tracks what the call observes).
// - Fingerprints do not always distinguish what the computation can
//   observe: closures compare by identity but fingerprint structurally (and
//   a `Fingerprint` that does not capture all data marks itself lossy; none
//   does at the moment). So an entry also keeps the arguments and is only
//   reused if they are equal ([values_memo_equal]: `==`, but recursing into
//   content, styles, arrays, dictionaries, functions and dynamic values,
//   where Typst's equality is looser).
// - Results that may contain values created during the computation are not
//   reused (a reused closure would keep its identity where a recomputed one
//   gets a new one): layout results whose tags hold closures are not cached
//   ([frame_cacheable]), the counter sequence only holds numbers, and the
//   state sequence is not memoized.
// - Introspector reads of the call are recorded into a fresh
//   [IntrospectionRecorder]. A cached result is only reused with the
//   introspector it was computed with, or if all of its recorded reads
//   produce the same results on the current introspector and none of the
//   recorded results had a lossy fingerprint or contained values compared by
//   identity (closures). Its reads are then merged into
//   the caller's recorder (as if the call had been executed), so convergence
//   checking is unaffected.
// - The call's sink side effects (warnings, delayed errors, introspections,
//   traced values) are recorded into a fresh [Sink] and replayed into the
//   caller's sink, both after computing and on every reuse.
// - Results are copied for every caller where they are mutable (frames are
//   copy-on-write).
// - Errors are not cached (the call is simply executed again).
//
// Caches only live for one compilation ([with_layout_memo]), across its
// introspection iterations, as the world (files, fonts) is fixed during it.

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
  let result = f() catch {
    e => {
      memo_generation.val = outer
      raise e
    }
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
  let output = f(inner) catch {
    e => {
      finish()
      raise e
    }
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
/// Whether a laid-out frame can be reused: its tags must not hold closures
/// (they may have been created during layout, and a recomputation would
/// create new ones with a different identity). The same holds for the
/// frames of its tiling paints.
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
/// once per tiling) records whether it holds closures.
fn paint_cacheable(paint : Paint) -> Bool {
  match paint {
    Tiling(tiling) =>
      (tiling.frame_fingerprint_flags() & fingerprint_identity) == 0
    Solid(_) | Gradient(_) => true
  }
}
