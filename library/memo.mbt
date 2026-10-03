// Memoization (not upstream: a replacement for comemo's `#[comemo::memoize]`
// on `layout_par_impl`, `layout_fragment_impl` and the counter/state
// sequences).
//
// Upstream memoizes these functions on all their arguments, tracking which
// parts of the tracked arguments (introspector, locator, route, sink) the call
// observed. That makes later introspection iterations and repeated
// measurements (e.g. of grid cells) cheap. Here:
//
// - The cache key is a fingerprint of the untracked arguments (content,
//   style chain, regions, ...) plus the fully resolved locator and the route
//   (stricter than upstream, which only tracks what the call observes).
// - Introspector reads of the call are recorded into a fresh
//   [IntrospectionRecorder]. A cached result is only reused if all of its
//   recorded reads produce the same results on the current introspector
//   (trivially so for the introspector the result was computed with), and
//   its reads are then merged into the caller's recorder (as if the call had
//   been executed), so convergence checking is unaffected.
// - The call's sink side effects (warnings, delayed errors, introspections,
//   traced values) are recorded into a fresh [Sink] and replayed into the
//   caller's sink, both after computing and on every reuse.
// - Results are copied for every caller where they are mutable (frames are
//   copy-on-write).
// - Errors are not cached (the call is simply executed again).
//
// Caches only live for one compilation ([with_layout_memo]), across its
// introspection iterations, as the world (files, fonts) is fixed during it.
//
// Keys rely on [Fingerprint]s. Calls whose arguments contain values with
// lossy fingerprints (gradients and tilings, hashed through their repr) are
// not memoized ([memo_fingerprint]). Values compare differently than they
// fingerprint in one respect: closures are equal only to themselves, while
// their fingerprints are structural. Where a result can contain argument
// values (the state sequence holds the state's initial value), entries also
// keep the arguments and are only reused for equal ones.

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
/// Run `f` (a compilation) with fresh memoization caches.
pub fn[T] with_layout_memo(
  f : () -> T raise SourceError,
) -> T raise SourceError {
  let outer = memo_generation.val
  memo_counter.val += 1
  memo_generation.val = memo_counter.val
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
          entry.reads.validate(engine.introspector)
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

///|
let layout_store : MemoStore[Array[Frame], Unit] = MemoStore::new()

///|
/// Memoize a layout function producing frames, keyed by `key` (which must
/// fingerprint every argument of the call except the engine; see the module
/// docs). `f` must use the engine it is given.
pub fn memoized_layout(
  engine : Engine,
  key : U128,
  f : (Engine) -> Fragment raise SourceError,
) -> Fragment raise SourceError {
  let frames = memoize(
    layout_store,
    engine,
    key,
    (),
    frames => frames.map(frame => frame.clone()),
    engine => f(engine).0,
  )
  Fragment(frames)
}
