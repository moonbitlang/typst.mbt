// Checking that the recording of world reads is complete (not upstream;
// `docs/incremental-design.md`, section 9.1, as far as recording goes).
//
// While nothing is kept across compilations a missing world read cannot
// make a result stale, so nothing fails if one is missing. This is the
// check that fails. With [set_memo_check] on, every result that a store
// is about to keep is computed once more, from scratch, and the world
// reads the entry keeps must be exactly what that run asked of the world:
//
// - What the run asked is seen from below the tracked world: the raw world
//   of every [TrackedWorld] is wrapped in a spy that notes each call of
//   `source`, `file`, `book`, `font` and `today` with a fingerprint of the
//   answer it gave. A tracked method that does not record, a path on which
//   reads are dropped and a read that reaches the world around the
//   tracked methods all show as a read of the spy that the entry lacks.
// - From scratch: the run starts with empty stores (the stores of the
//   memoized calls are set aside and put back), so nothing in it is taken
//   from an entry whose reads are the thing under test, and every call
//   inside it runs at least once and asks the world itself. That makes its
//   reads complete, in the order of first occurrence; a read that an
//   entry merges into its caller instead of making it (a hit) is thereby
//   compared with the read that a run makes.
// - It is isolated from the call it repeats: a sink and an introspection
//   recorder of its own (its caller makes them), and the route's shift
//   bounds, the route-query and traced-file logs, the fingerprint flags,
//   the counts of closure calls and the world's log are put back.
//
// The comparison is exact: the same reads in the same order with the same
// fingerprints. It does not compare results (the checked mode of 9.1
// does, for hits; it belongs to the step that keeps results). What it
// cannot see: a host function that reads something that is not the world.
// A process cache that hides a read (a result found by something other
// than its key, section 5.5) shows as a read that the entry has and the
// second run lacks.

///|
/// Whether memoized results are checked ([set_memo_check]).
let memo_check : Ref[Bool] = { val: false, }

///|
/// Turn the check of recorded world reads on or off (see the file header).
/// It applies to the tracked worlds that are made while it is on, and it
/// costs a second run of every memoized call. For tests and the runner's
/// `--check-reads`.
pub fn set_memo_check(on : Bool) -> Unit {
  memo_check.val = on
}

///|
/// Whether the check of recorded world reads is on and not itself running
/// (a second run checks nothing).
pub fn memo_check_enabled() -> Bool {
  memo_check.val && !memo_check_running.val
}

///|
/// Whether a second run is in progress.
let memo_check_running : Ref[Bool] = { val: false, }

///|
/// Whether a second run of the check is in progress: a store that was set
/// aside for it may then hand out the objects of the entries it had where
/// the run makes the same ones again (the module of a file, which compares
/// by identity with what the repeated call holds).
pub fn memo_check_running_now() -> Bool {
  memo_check_running.val
}

///|
/// The number of entries that were checked, and what was found.
let memo_check_count : Ref[Int] = { val: 0, }

///|
let memo_check_failures : Array[String] = []

///|
/// The number of entries checked since the last call, and the failures:
/// one text per entry whose kept world reads are not the reads of a run
/// from scratch.
pub fn take_memo_check_report() -> (Int, Array[String]) {
  let count = memo_check_count.val
  let failures = memo_check_failures.copy()
  memo_check_count.val = 0
  memo_check_failures.clear()
  (count, failures)
}

// The spy.

///|
/// A read of the raw world and the fingerprint of its answer.
priv struct SpyRead {
  read : WorldRead
  print : U128
}

///|
/// The reads of the raw worlds while a second run is in progress.
let spy_log : Array[SpyRead] = []

///|
/// A world that notes what is asked of it (see the file header).
priv struct SpyWorld {
  inner : &World
}

///|
fn spy_world(world : &World) -> &World {
  let spy : SpyWorld = { inner: world, }
  spy
}

///|
fn spy_note(read : WorldRead, print : U128) -> Unit {
  if memo_check_running.val {
    spy_log.push({ read, print, })
  }
}

///|
impl World for SpyWorld with fn library(self) {
  self.inner.library()
}

///|
impl World for SpyWorld with fn main(self) {
  self.inner.main()
}

///|
impl World for SpyWorld with fn source(self, id) {
  let answer : Result[@syntax.Source, FileError] = Ok(self.inner.source(id)) catch {
    error => Err(error)
  }
  match answer {
    Ok(source) => {
      spy_note(Source(id), source_answer_print(source))
      source
    }
    Err(error) => {
      spy_note(Source(id), failed_answer_print(error))
      raise error
    }
  }
}

///|
impl World for SpyWorld with fn file(self, id) {
  let answer : Result[Bytes, FileError] = Ok(self.inner.file(id)) catch {
    error => Err(error)
  }
  match answer {
    Ok(data) => {
      spy_note(File(id), file_answer_print(data))
      data
    }
    Err(error) => {
      spy_note(File(id), failed_answer_print(error))
      raise error
    }
  }
}

///|
impl World for SpyWorld with fn book(self) {
  let book = self.inner.book()
  spy_note(Book, book_answer_print(book))
  book
}

///|
impl World for SpyWorld with fn font(self, index) {
  let font = self.inner.font(index)
  spy_note(Font(index), font_answer_print(font))
  font
}

///|
impl World for SpyWorld with fn today(self, offset) {
  let today = self.inner.today(offset)
  spy_note(Today(offset), today_answer_print(today))
  today
}

///|
fn world_reads_same(a : WorldRead, b : WorldRead) -> Bool {
  match (a, b) {
    (Source(x), Source(y)) | (File(x), File(y)) => x == y
    (Book, Book) => true
    (Font(x), Font(y)) => x == y
    (Today(None), Today(None)) => true
    (Today(Some(x)), Today(Some(y))) => x == y
    _ => false
  }
}

// The stores that a second run sets aside.

///|
/// What sets the stores aside for a second run and returns what puts them
/// back: the stores of `memoize` (each from its first entry on) and those
/// of other packages ([register_memo_check_store]).
let memo_check_stores : Array[() -> () -> Unit] = []

///|
/// Registers a store of memoized calls outside of this package (the
/// modules of `eval/import.mbt`): `set_aside` empties it and returns the
/// function that puts its entries back.
pub fn register_memo_check_store(set_aside : () -> () -> Unit) -> Unit {
  memo_check_stores.push(set_aside)
}

///|
fn[T, I] MemoStore::set_aside(self : MemoStore[T, I]) -> () -> Unit {
  let entries = self.entries
  let generation = self.generation
  self.entries = {}
  () => {
    self.entries = entries
    self.generation = generation
  }
}

///|
fn ClosureStore::set_aside(self : ClosureStore) -> () -> Unit {
  let asked = self.asked
  let entries = self.entries
  let generation = self.generation
  self.asked = {}
  self.entries = {}
  () => {
    self.asked = asked
    self.entries = entries
    self.generation = generation
  }
}

///|
/// The world reads of a run of `run` from scratch (see the file header),
/// without repetitions, in the order in which they were first made; `None`
/// if the run raised.
fn fresh_world_reads(
  world : TrackedWorld,
  run : () -> Unit raise SourceError,
) -> Array[SpyRead]? {
  guard world.scope is Some(scope) else { return None }
  memo_check_running.val = true
  // The stores.
  let restore = [closure_store.set_aside()]
  for set_aside in memo_check_stores {
    restore.push(set_aside())
  }
  // What a memoized call notes for the calls around it.
  let shift_lo = route_shift_lo.val
  let shift_hi = route_shift_hi.val
  let shift_scopes = route_shift_scopes.val
  let queries = route_query_log.copy()
  let query_scopes = route_query_scopes.val
  let traced = own_traced_begin()
  let flags = fingerprint_flags.val
  let reused = closure_memo_counts[0]
  let computed = closure_memo_counts[1]
  // The log of the world: what the run pushes is taken out again.
  let log = scope.log.copy()
  let volatile_reads = scope.volatile_reads
  let mark = world.reads_begin()
  let start = spy_log.length()
  let finish = () => {
    for put_back in restore {
      put_back()
    }
    route_shift_lo.val = shift_lo
    route_shift_hi.val = shift_hi
    route_shift_scopes.val = shift_scopes
    route_query_log.clear()
    route_query_log.append(queries)
    route_query_scopes.val = query_scopes
    own_traced_end(traced)
    fingerprint_flags.val = flags
    closure_memo_counts[0] = reused
    closure_memo_counts[1] = computed
    world.reads_abort(mark)
    scope.log.clear()
    scope.log.append(log)
    scope.volatile_reads = volatile_reads
    memo_check_running.val = false
  }
  let ok = try run() catch {
    _ => false
  } noraise {
    _ => true
  }
  finish()
  let reads : Array[SpyRead] = []
  for i in start..<spy_log.length() {
    let read = spy_log[i]
    let mut known = false
    for other in reads {
      if world_reads_same(other.read, read.read) {
        known = true
        break
      }
    }
    if !known {
      reads.push(read)
    }
  }
  spy_log.truncate(start)
  if ok {
    Some(reads)
  } else {
    None
  }
}

///|
/// Checks an entry that a store is about to keep: `reads` are the world
/// reads it keeps, `run` computes its result once more (with a sink and
/// an introspection recorder of its own). A difference is noted for
/// [take_memo_check_report] under `label`. Only call it if
/// [memo_check_enabled].
pub fn memo_check_reads(
  label : () -> String,
  world : TrackedWorld,
  reads : WorldReads,
  run : () -> Unit raise SourceError,
) -> Unit {
  guard memo_check_enabled() && world.in_scope() else { return }
  memo_check_count.val += 1
  let kept = reads.describe()
  let list = (lines : Array[String]) => "[" + lines.join(", ") + "]"
  match fresh_world_reads(world, run) {
    None =>
      memo_check_failures.push(
        "\{label()}: the run from scratch raised; kept \{list(kept)}",
      )
    Some(fresh) => {
      let asked = fresh.map(read => {
        "\{read.read.describe()} = \{u128_hex(read.print)}"
      })
      if asked != kept {
        memo_check_failures.push(
          "\{label()}: kept \{list(kept)}, a run from scratch asked \{list(asked)}",
        )
      }
    }
  }
}
