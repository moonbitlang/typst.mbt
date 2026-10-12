// Port of `typst-library/src/introspection/introspector.rs`.
//
// Upstream's `Introspector` is a `#[comemo::track]`ed trait object. Here the
// trait is [IntrospectorBackend] and [Introspector] is a facade over a
// backend that optionally records every read (name, arguments and result
// fingerprint) in an [IntrospectionRecorder]. The recorded reads replace
// comemo's constraint validation: the convergence loop replays them against
// the next iteration's introspector (see docs/p3-plan.md, section 1).

///|
/// Serves inquiries for pieces of information from the compilation output.
///
/// This trait is implemented by target-specific introspectors. These must
/// implement all methods to provide a unified interface to the Typst standard
/// library, but may return `None` or error in some methods, depending on the
/// specifics of the target. The HTML target, for instance, will return `None`
/// for [page](Self::page) requests.
pub(open) trait IntrospectorBackend {
  /// Queries for all matching elements. The result is for reading: a
  /// backend may hand out what it keeps (upstream: an `EcoVec`, whose
  /// holders cannot write to each other's).
  fn query(Self, Selector) -> ArrayView[Content]
  /// Queries for the first element that matches the selector.
  fn query_first(Self, Selector) -> Content?
  /// Queries for the unique element that matches the selector.
  fn query_unique(Self, Selector) -> Content raise HintedError
  /// Queries for a unique element with the label.
  fn query_label(Self, Label) -> Content raise HintedError
  /// Queries for all elements with a label.
  fn query_labelled(Self) -> Array[Content]
  /// An optimized version of `query(selector.before(end, true).len()` used by
  /// counters and state.
  fn query_count_before(Self, Selector, Location) -> Int32
  /// Checks how many times a label exists.
  fn label_count(Self, Label) -> Int32
  /// Tries to find a location for an element with the given `key` hash that
  /// is closest after the `base`.
  ///
  /// This is used for introspector-assisted location assignment during
  /// measurement. See the "Dealing with Measurement" section of the
  /// [Locator] docs for more details.
  fn locator(Self, U128, Location) -> Location?
  /// Returns the total number of pages in the document that contains the
  /// given location.
  fn pages(Self, Location) -> NonZeroUSize?
  /// Returns the page number for the given location.
  fn page(Self, Location) -> NonZeroUSize?
  /// Returns the position for the given location.
  fn position(Self, Location) -> DocumentPosition?
  /// Returns the page numbering for the given location, if any.
  fn page_numbering(Self, Location) -> Numbering?
  /// Returns the page supplement for the given location, if any.
  fn page_supplement(Self, Location) -> Content?
  /// Retrieves the anchor to link to for this location in HTML export.
  fn anchor(Self, Location) -> String?
  /// Returns the location of the document which has/contains the given
  /// location.
  fn document(Self, Location) -> Location?
  /// Returns the file path of the document/asset which has or contains the
  /// given location.
  ///
  /// Returns `None` in a single document (not a bundle) or if the location
  /// is not associated with a document or asset (top-level in a bundle).
  fn path(Self, Location) -> @syntax.VirtualPath?
}

///|
/// An introspector that returns empty results for all inquiries.
pub(all) struct EmptyIntrospector(Unit)

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn query(_, _) {
  let none : Array[Content] = []
  none
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn query_first(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn query_unique(_, _) {
  bail("selector does not match any element")
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn query_label(_, label) {
  bail("label `\{label.repr()}` does not exist in the document")
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn query_labelled(_) {
  []
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn query_count_before(
  _,
  _,
  _,
) {
  0
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn label_count(_, _) {
  0
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn locator(_, _, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn pages(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn page(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn position(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn page_numbering(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn page_supplement(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn anchor(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn document(_, _) {
  None
}

///|
pub impl IntrospectorBackend for EmptyIntrospector with fn path(_, _) {
  None
}

///|
#deprecated("call as `IntrospectorBackend::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EmptyIntrospector with IntrospectorBackend::{
  document,
  query_label,
  path,
  query_unique,
  anchor,
  page,
  query_labelled,
  page_supplement,
  query_count_before,
  query,
  page_numbering,
  position,
  query_first,
  label_count,
  locator,
  pages,
}

// The facade.

///|
/// Provides access to information about the document: a target-specific
/// [IntrospectorBackend], optionally with an [IntrospectionRecorder] that
/// records all reads (upstream `Tracked<dyn Introspector>`).
pub struct Introspector {
  priv backend : &IntrospectorBackend
  priv recorder : IntrospectionRecorder?
  /// Which introspector this is ([Introspector::serial]).
  priv serial : Int64
}

///|
/// The number of introspectors made so far ([Introspector::new]).
let introspector_serials : Ref[Int64] = { val: 0L, }

///|
/// Wrap a target-specific introspector. Every call makes another
/// introspector ([Introspector::serial]): whoever asks one backend again
/// and again keeps what this returned, as a document does.
pub fn Introspector::new(backend : &IntrospectorBackend) -> Introspector {
  introspector_serials.val += 1L
  { backend, recorder: None, serial: introspector_serials.val, }
}

///|
/// An introspector that returns empty results for all inquiries (upstream
/// `EmptyIntrospector`).
pub fn Introspector::empty() -> Introspector {
  { backend: EmptyIntrospector(()), recorder: None, serial: 0L, }
}

///|
/// The same introspector, recording all reads into `recorder` (upstream
/// `introspector.track_with(&constraint)`).
pub fn Introspector::track_with(
  self : Introspector,
  recorder : IntrospectionRecorder,
) -> Introspector {
  { backend: self.backend, recorder: Some(recorder), serial: self.serial, }
}

///|
/// The same introspector, without recording.
pub fn Introspector::untracked(self : Introspector) -> Introspector {
  { backend: self.backend, recorder: None, serial: self.serial, }
}

///|
/// A number that says which introspector this is (not upstream): the same
/// for what [Introspector::track_with] and [Introspector::untracked] make
/// of one, another for every [Introspector::new], and zero for every empty
/// one. Two introspectors with one number give the same answers, since a
/// backend answers the same for as long as it lives (what it hands out is
/// for reading: [Introspector::query]).
///
/// It is what the entry of a memoized call keeps of the introspector it
/// was computed with, for the lookup that needs no validation of its reads
/// (`memo.mbt`). An entry kept the backend itself for that, and with it
/// every located element of a document for as long as the entry lived.
/// (64 bits: a watching process makes an introspector per layout
/// iteration, and a counter of 32 bits that comes round would give a
/// document the number of the empty ones.)
pub fn Introspector::serial(self : Introspector) -> Int64 {
  self.serial
}

///|
/// The target-specific introspector.
pub fn Introspector::backend(self : Introspector) -> &IntrospectorBackend {
  self.backend
}

///|
/// Record a read. `key` identifies the method and its arguments; `replay`
/// recomputes the result's fingerprint on another introspector.
///
/// If the result holds host closures, they are recorded too (not upstream):
/// host closures compare by identity, so a replayed result is only the same
/// if it holds the same closures, not just closures with the same key.
fn Introspector::record(
  self : Introspector,
  name : String,
  args : () -> U128,
  result : () -> U128,
  replay : (Introspector) -> U128,
) -> Unit {
  if self.recorder is Some(recorder) {
    let key = hash128((name, args()))
    if !recorder.calls.contains(key) {
      let mut expected = u128_zero
      let flags = fingerprint_flags_in(() => expected = result())
      if flags != 0 {
        recorder.lossy = true
      }
      let hosts = if (flags & fingerprint_host) != 0 {
        Some(fingerprint_hosts_in(() => result() |> ignore))
      } else {
        None
      }
      recorder.calls[key] = { name, expected, replay, hosts, }
    }
  }
}

///|
/// Queries for all matching elements.
///
/// The result is a view: the introspector keeps what it found (upstream
/// caches queries too and hands out an `EcoVec`, which nobody can write to
/// for the others), and the same answer is given to every later query, to
/// the validation of recorded reads and to the entries that were computed
/// with this introspector. (It was the kept array itself.)
pub fn Introspector::query(
  self : Introspector,
  selector : Selector,
) -> ArrayView[Content] {
  let output = self.backend.query(selector)
  self.record("query", () => hash128(selector), () => hash128(output), i => {
    hash128_output(i.backend.query(selector))
  })
  output
}

///|
/// Queries for the first element that matches the selector.
pub fn Introspector::query_first(
  self : Introspector,
  selector : Selector,
) -> Content? {
  let output = self.backend.query_first(selector)
  self.record("query_first", () => hash128(selector), () => hash128(output), i => {
    hash128_output(i.backend.query_first(selector))
  })
  output
}

///|
fn result_of(
  f : () -> Content raise HintedError,
) -> Result[Content, HintedString] {
  try f() catch {
    HintedError(err) => Err(err)
  } noraise {
    c => Ok(c)
  }
}

///|
/// Queries for the unique element that matches the selector.
pub fn Introspector::query_unique(
  self : Introspector,
  selector : Selector,
) -> Content raise HintedError {
  let output = result_of(() => self.backend.query_unique(selector))
  self.record("query_unique", () => hash128(selector), () => hash128(output), i => {
    hash128_output(result_of(() => i.backend.query_unique(selector)))
  })
  match output {
    Ok(c) => c
    Err(err) => raise HintedError(err)
  }
}

///|
/// Queries for a unique element with the label.
pub fn Introspector::query_label(
  self : Introspector,
  label : Label,
) -> Content raise HintedError {
  let output = result_of(() => self.backend.query_label(label))
  self.record("query_label", () => hash128(label), () => hash128(output), i => {
    hash128_output(result_of(() => i.backend.query_label(label)))
  })
  match output {
    Ok(c) => c
    Err(err) => raise HintedError(err)
  }
}

///|
/// Queries for all elements with a label.
pub fn Introspector::query_labelled(self : Introspector) -> Array[Content] {
  let output = self.backend.query_labelled()
  self.record("query_labelled", () => u128_zero, () => hash128(output), i => {
    hash128_output(i.backend.query_labelled())
  })
  output
}

///|
/// An optimized version of `query(selector.before(end, true).len()` used by
/// counters and state.
pub fn Introspector::query_count_before(
  self : Introspector,
  selector : Selector,
  end : Location,
) -> Int32 {
  let output = self.backend.query_count_before(selector, end)
  self.record(
    "query_count_before",
    () => hash128((selector, end)),
    () => hash128(output),
    i => hash128_output(i.backend.query_count_before(selector, end)),
  )
  output
}

///|
/// Checks how many times a label exists.
pub fn Introspector::label_count(self : Introspector, label : Label) -> Int32 {
  let output = self.backend.label_count(label)
  self.record("label_count", () => hash128(label), () => hash128(output), i => {
    hash128_output(i.backend.label_count(label))
  })
  output
}

///|
/// Tries to find a location for an element with the given `key` hash that is
/// closest after the `base`.
pub fn Introspector::locator(
  self : Introspector,
  key : U128,
  base : Location,
) -> Location? {
  let output = self.backend.locator(key, base)
  self.record("locator", () => hash128((key, base)), () => hash128(output), i => {
    hash128_output(i.backend.locator(key, base))
  })
  output
}

///|
/// Returns the total number of pages in the document that contains the given
/// location.
pub fn Introspector::pages(
  self : Introspector,
  location : Location,
) -> NonZeroUSize? {
  let output = self.backend.pages(location)
  self.record("pages", () => hash128(location), () => hash128(output), i => {
    hash128_output(i.backend.pages(location))
  })
  output
}

///|
/// Returns the page number for the given location.
pub fn Introspector::page(
  self : Introspector,
  location : Location,
) -> NonZeroUSize? {
  let output = self.backend.page(location)
  self.record("page", () => hash128(location), () => hash128(output), i => {
    hash128_output(i.backend.page(location))
  })
  output
}

///|
/// Returns the position for the given location.
pub fn Introspector::position(
  self : Introspector,
  location : Location,
) -> DocumentPosition? {
  let output = self.backend.position(location)
  self.record("position", () => hash128(location), () => hash128(output), i => {
    hash128_output(i.backend.position(location))
  })
  output
}

///|
/// Returns the page numbering for the given location, if any.
pub fn Introspector::page_numbering(
  self : Introspector,
  location : Location,
) -> Numbering? {
  let output = self.backend.page_numbering(location)
  self.record(
    "page_numbering",
    () => hash128(location),
    () => hash128(output),
    i => hash128_output(i.backend.page_numbering(location)),
  )
  output
}

///|
/// Returns the page supplement for the given location, if any.
pub fn Introspector::page_supplement(
  self : Introspector,
  location : Location,
) -> Content? {
  let output = self.backend.page_supplement(location)
  self.record(
    "page_supplement",
    () => hash128(location),
    () => hash128(output),
    i => hash128_output(i.backend.page_supplement(location)),
  )
  output
}

///|
/// Retrieves the anchor to link to for this location in HTML export.
pub fn Introspector::anchor(
  self : Introspector,
  location : Location,
) -> String? {
  let output = self.backend.anchor(location)
  self.record("anchor", () => hash128(location), () => hash128(output), i => {
    hash128_output(i.backend.anchor(location))
  })
  output
}

///|
/// Returns the location of the document which has/contains the given
/// location.
pub fn Introspector::document(
  self : Introspector,
  location : Location,
) -> Location? {
  let output = self.backend.document(location)
  self.record("document", () => hash128(location), () => hash128(output), i => {
    hash128_output(i.backend.document(location))
  })
  output
}

///|
/// Returns the file path of the document/asset which has or contains the
/// given location.
pub fn Introspector::path(
  self : Introspector,
  location : Location,
) -> @syntax.VirtualPath? {
  let output = self.backend.path(location)
  self.record("path", () => hash128(location), () => hash128(output), i => {
    hash128_output(i.backend.path(location))
  })
  output
}

// Read recording (replaces comemo's `Constraint`).

///|
/// A read of the introspector that was recorded during an iteration.
priv struct RecordedRead {
  /// The method that was called (for debugging).
  name : String
  /// The fingerprint of the result.
  expected : U128
  /// Recomputes the result's fingerprint on another introspector, with
  /// [hash128_output].
  replay : (Introspector) -> U128
  /// The host closures in the result, in the order the fingerprint visits
  /// them (not upstream; `None` if there are none): validated by identity.
  hosts : Array[HostFunc]?
}

///|
/// Records all reads of an [Introspector] during a compiler iteration
/// (upstream `comemo::Constraint`): the name, its arguments and the
/// fingerprint of the result, including error results.
pub struct IntrospectionRecorder {
  priv calls : Map[U128, RecordedRead]
  /// Whether the fingerprint of a recorded result was lossy or contained
  /// values compared by identity, so that [IntrospectionRecorder::validate]
  /// cannot prove interchangeable results (not upstream; only used for
  /// memoization, see `memo.mbt`).
  priv mut lossy : Bool
}

///|
/// Create an empty recorder.
pub fn IntrospectionRecorder::new() -> IntrospectionRecorder {
  { calls: {}, lossy: false, }
}

///|
/// The number of distinct recorded reads.
pub fn IntrospectionRecorder::len(self : IntrospectionRecorder) -> Int32 {
  self.calls.length()
}

///|
/// The names of the methods of the recorded reads (in recording order).
pub fn IntrospectionRecorder::methods(
  self : IntrospectionRecorder,
) -> Array[String] {
  self.calls.values().map(read => read.name).collect()
}

///|
/// Whether all recorded reads produce the same results on `introspector`,
/// i.e. whether an iteration observing `introspector` would observe exactly
/// what the recorded iteration observed.
pub fn IntrospectionRecorder::validate(
  self : IntrospectionRecorder,
  introspector : Introspector,
) -> Bool {
  let introspector = introspector.untracked()
  read_accelerator.ask(introspector.serial)
  // (Maps of this call: a replay asks the backend and nothing else.)
  let answers = read_accelerator.answers
  let before = read_accelerator.before
  for key, read in self.calls {
    match read.hosts {
      None => {
        let hash = match answers.get(key) {
          Some(hash) => hash
          None => {
            let hash = match before.get(key) {
              Some(hash) => hash
              None => (read.replay)(introspector)
            }
            answers[key] = hash
            hash
          }
        }
        if hash != read.expected {
          return false
        }
      }
      Some(expected) => {
        // Equal fingerprints and, in the same order, the same host
        // closures. Only the fingerprint of the replayed result is
        // collected (`hash128_output`), like when the read was recorded:
        // computing the result may fingerprint other values (a query
        // hashes its selector, which can hold host closures too).
        let hosts = []
        fingerprint_output_hosts.val = Some(hosts)
        let hash = (read.replay)(introspector)
        fingerprint_output_hosts.val = None
        if hash != read.expected || hosts.length() != expected.length() {
          return false
        }
        for i in 0..<hosts.length() {
          if !physical_equal(hosts[i], expected[i]) {
            return false
          }
        }
      }
    }
  }
  true
}

///|
/// The fingerprints of the results of reads on one introspector, by the
/// key of the read (comemo's accelerator, `comemo/src/accelerate.rs`: per
/// tracked value a map from the hash of a call to the hash of its result,
/// "so that validation makes a call once").
///
/// An entry of a store is validated by replaying its reads on the
/// introspector at hand, and many entries hold the same read: the query of
/// a counter's updates is a read of the counter sequence at every depth of
/// the route, of every result that an earlier iteration or compilation
/// left under the same key, and of every layout that displays the
/// counter. Each replay hashes the whole result. With the stores kept
/// across compilations the candidates of earlier compilations are
/// validated too, and are mostly rejected only after that hash. An
/// introspector answers the same forever ([Introspector::serial]), so the
/// fingerprint of an answer is computed once per introspector.
///
/// It is a table by introspector (slice 3 of `docs/incremental-design.md`;
/// it kept the answers of the introspector that was asked last only). A
/// document that is found again has the introspector it had
/// (`layout/document.mbt`, `PagedDocument::kept`), and the compilation
/// that finds it validates what the compilation that laid it out
/// validated: the reads of the document against the document's own
/// introspector, which is every read of the document, replayed once per
/// recompilation in which nothing changed. With the table that is a
/// lookup per read.
///
/// What is in it is what the compilations between the last two [evict]
/// calls asked, and no more (comemo drops its accelerator with every
/// `evict`): an introspector that was not asked since the `evict` before
/// the last is dropped with its answers ([read_answers_max_age]; it is
/// that of a document that changed), and of an introspector that stays,
/// the answers that were not asked since then are dropped too (`before`:
/// a document that is found in every compilation is asked the reads of
/// whatever changes around it, each with locations of its own). The
/// answers of the empty introspectors are not in it at all: they all have
/// the number zero, and every later compilation asks them. They are kept
/// while the empty introspector is the one that is asked, as before.
priv struct ReadAccelerator {
  /// The introspector that was asked last, with its answers: those that
  /// were asked for since the last [evict], and those that were asked for
  /// between the two before it (which nothing writes to).
  mut serial : Int64
  mut answers : Map[U128, U128]
  mut before : Map[U128, U128]
  /// The answers of the other introspectors (not of the empty ones).
  tables : Map[Int64, ReadAnswers]
  /// Counts the lookups in `tables`: the time of [ReadAnswers].
  mut clock : Int32
  /// Whether [evict] knows the table.
  mut registered : Bool
}

///|
/// The answers of one introspector ([ReadAccelerator]).
priv struct ReadAnswers {
  mut answers : Map[U128, U128]
  mut before : Map[U128, U128]
  /// The number of [evict] calls since the answers were asked for.
  mut age : Int32
  /// When they were last asked for (`ReadAccelerator.clock`).
  mut used : Int32
}

///|
/// The greatest age of the answers of an introspector: what the
/// compilation before an `evict` asked for stays for the next one.
let read_answers_max_age : Int32 = 1

///|
/// The greatest number of introspectors whose answers are kept, for a
/// process that never calls [evict]: the one that was not asked for the
/// longest makes room. (A compilation asks at most five and an empty
/// one.)
let read_answers_max_tables : Int32 = 16

///|
/// No answers (never written to).
let no_read_answers : Map[U128, U128] = Map([])

///|
let read_accelerator : ReadAccelerator = {
  serial: -1L,
  answers: {},
  before: no_read_answers,
  tables: {},
  clock: 0,
  registered: false,
}

///|
/// Makes the answers of the introspector with this number the ones at hand
/// (`answers` and `before`).
fn ReadAccelerator::ask(self : ReadAccelerator, serial : Int64) -> Unit {
  if self.serial == serial {
    return
  }
  self.serial = serial
  if serial == 0L {
    self.answers = {}
    self.before = no_read_answers
    return
  }
  self.clock += 1
  match self.tables.get(serial) {
    Some(kept) => {
      kept.age = 0
      kept.used = self.clock
      self.answers = kept.answers
      self.before = kept.before
    }
    None => {
      if !self.registered {
        self.registered = true
        register_evictor(max_age => self.evict(max_age))
      }
      if self.tables.length() >= read_answers_max_tables {
        let mut oldest = serial
        let mut used = self.clock
        for other, kept in self.tables {
          if kept.used < used {
            oldest = other
            used = kept.used
          }
        }
        self.tables.remove(oldest)
      }
      self.answers = {}
      self.before = no_read_answers
      self.tables[serial] = {
        answers: self.answers,
        before: self.before,
        age: 0,
        used: self.clock,
      }
    }
  }
}

///|
/// [evict] for the answers of introspectors: an introspector that was not
/// asked since the call before this one is dropped, and of the others the
/// answers that were not asked for since then; everything for zero.
fn ReadAccelerator::evict(self : ReadAccelerator, max_age : Int32) -> Unit {
  let max_age = if max_age < read_answers_max_age {
    max_age
  } else {
    read_answers_max_age
  }
  let old = []
  for serial, kept in self.tables {
    kept.age += 1
    if kept.age > max_age {
      old.push(serial)
    } else {
      kept.before = kept.answers
      kept.answers = {}
    }
  }
  for serial in old {
    self.tables.remove(serial)
  }
  // The next lookup goes through the table, which makes what it finds
  // young.
  self.serial = -1L
  self.answers = {}
  self.before = no_read_answers
}

///|
/// Add the reads of this recorder to `other` (reads already recorded there
/// are kept), as if they had been performed on `other`'s introspector.
pub fn IntrospectionRecorder::merge_into(
  self : IntrospectionRecorder,
  other : IntrospectionRecorder,
) -> Unit {
  if physical_equal(self, other) {
    return
  }
  if self.lossy {
    other.lossy = true
  }
  for key, read in self.calls {
    if !other.calls.contains(key) {
      other.calls[key] = read
    }
  }
}

// The target-agnostic element introspector.

///|
/// A map from one key to multiple values.
priv struct MultiMap[K, V](Map[K, Array[V]])

///|
fn[K : Hash + Eq, V] MultiMap::new() -> MultiMap[K, V] {
  MultiMap({})
}

///|
fn[K : Hash + Eq, V] MultiMap::get(self : MultiMap[K, V], key : K) -> Array[V] {
  match self.0.get(key) {
    Some(vec) => vec
    None => []
  }
}

///|
fn[K : Hash + Eq, V] MultiMap::insert(
  self : MultiMap[K, V],
  key : K,
  value : V,
) -> Unit {
  match self.0.get(key) {
    Some(vec) => vec.push(value)
    None => self.0[key] = [value]
  }
}

///|
fn[K : Hash + Eq, V] MultiMap::take(
  self : MultiMap[K, V],
  key : K,
) -> Array[V]? {
  match self.0.get(key) {
    Some(vec) => {
      self.0.remove(key)
      Some(vec)
    }
    None => None
  }
}

///|
fn[K : Hash + Eq, V] MultiMap::append(
  self : MultiMap[K, V],
  other : MultiMap[K, V],
) -> Unit {
  for key, values in other.0 {
    for value in values {
      self.insert(key, value)
    }
  }
}

///|
/// A half-open range of element indices.
priv struct IndexRange {
  start : Int32
  mut end : Int32
}

///|
/// `usize::MAX`, used for missing indices.
let usize_max : Int32 = 2147483647

///|
/// An underlying target-agnostic introspector used for most queries.
///
/// The parameter `P` represents a position type for the relevant target.
pub struct ElementIntrospector[P] {
  /// All introspectable elements.
  priv elems : Array[(Content, P)]
  /// Lists all elements with a specific hash key. This is used for
  /// introspector-assisted location assignment during measurement.
  priv keys : MultiMap[U128, Location]
  /// Accelerates lookup of elements by location.
  ///
  /// Holds a range pointing into `elems` that covers the element and all its
  /// conceptual descendants. The first element in the range (i.e.
  /// `elems[range.start]` is the element with the location itself while the
  /// last element is its right-most descendants).
  priv locations : Map[Location, IndexRange]
  /// Accelerates lookup of elements by label.
  priv labels : MultiMap[Label, Int32]
  /// Caches queries done on the introspector. This is important because even
  /// if all top-level queries are distinct, they often have shared
  /// subqueries. Example: Individual counter queries with `before` that all
  /// depend on a global counter query.
  ///
  /// What is kept here is handed out as views ([ElementIntrospector::query])
  /// and never written to again.
  priv queries : Map[U128, ArrayView[Content]]
}

///|
/// Queries for all matching elements. The result is a view of what the
/// introspector keeps for the selector.
pub fn[P] ElementIntrospector::query(
  self : ElementIntrospector[P],
  selector : Selector,
) -> ArrayView[Content] {
  let hash = hash128(selector)
  if self.queries.get(hash) is Some(output) {
    return output
  }
  let output : ArrayView[Content] = match selector {
    Elem(_, _) => self.all().filter(elem => selector.matches(elem, None))
    Location(location) =>
      match self.get_by_loc(location) {
        Some(c) => [c]
        None => []
      }
    Label(label) => self.labels.get(label).map(idx => self.get_by_idx(idx))
    Or(selectors) => {
      let indices = @hashset.HashSet([])
      let sorted = []
      for sel in selectors {
        for elem in self.query(sel) {
          let idx = self.elem_index(elem)
          if indices.add_and_check(idx) {
            sorted.push(idx)
          }
        }
      }
      sorted.sort()
      sorted.map(idx => self.get_by_idx(idx))
    }
    And(selectors) => {
      let results = selectors.map(sel => self.query(sel))
      // Extract the smallest result list and then keep only those elements
      // in the smallest list that are also in all other lists.
      if results.is_empty() {
        []
      } else {
        let mut min = 0
        for i, vec in results {
          if vec.length() < results[min].length() {
            min = i
          }
        }
        let smallest = swap_remove(results, min)
        smallest.filter(candidate => {
          results.iter().all(other => self.binary_search(other, candidate).0)
        })[:]
      }
    }
    Before(selector~, end~, inclusive~) => {
      let list = self.query(selector)
      match self.query_first(end) {
        Some(end) => {
          // Determine which elements are before `end`.
          let split = match self.binary_search(list, end) {
            // Element itself is contained.
            (true, i) => i + (if inclusive { 1 } else { 0 })
            // Element itself is not contained.
            (false, i) => i
          }
          list[:split].to_owned()[:]
        }
        None => list
      }
    }
    After(selector~, start~, inclusive~) => {
      let list = self.query(selector)
      match self.query_first(start) {
        Some(start) => {
          // Determine which elements are after `start`.
          let split = match self.binary_search(list, start) {
            // Element itself is contained.
            (true, i) => i + (if inclusive { 0 } else { 1 })
            // Element itself is not contained.
            (false, i) => i
          }
          list[split:].to_owned()[:]
        }
        None => list
      }
    }
    Within(selector~, ancestor~) => {
      let list = self.query(selector)
      let ancestors = self.query(ancestor)
      let out = []
      let mut visited = 0

      // Walk the ancestors in order, collecting all elements in `list` that
      // are descendants of them. Elements in the list that are descendants
      // of multiple ancestors are yielded only once by virtue of `visited`.
      for ancestor in ancestors {
        let loc = ancestor.location().unwrap()
        let { start, end, } = self.loc_range(loc)
        let start_in_list = match
          binary_search_by_key(list, start, elem => self.elem_index(elem)) {
          // The element and the ancestor start at the same index. This means
          // they are one and the same. The within selector is not inclusive,
          // so we exclude it.
          (true, i) => i + 1
          // The ancestor's insertion index would be at `i`, so the element
          // currently at `i` is later than it and should be included.
          (false, i) => i
        }
        let end_in_list = match
          binary_search_by_key(list, end, elem => {
            self.loc_range(elem.location().unwrap()).end
          }) {
          // The element and the ancestor end in the same place. They might
          // be the same, but it's equally possible for the element to be a
          // rightmost leaf of the ancestor. If it's the same, we already
          // exclude it via `start` above and if it's a rightmost leaf, we
          // want to include it.
          (true, i) => i + 1
          // The ancestor's end index would be at `i`, so the element right
          // before `i` is earlier than it and should be included.
          (false, i) => i
        }

        // If the ancestor is fully contained in one of the list elements, we
        // exclude the list element from both the start and end, leading to
        // `end < start`.
        if end_in_list < start_in_list {
          continue
        }

        // Clamp at `visited` to ensure we don't yield elements twice.
        let start_in_list = if start_in_list > visited {
          start_in_list
        } else {
          visited
        }
        let end_in_list = if end_in_list > visited {
          end_in_list
        } else {
          visited
        }
        out.append(list[start_in_list:end_in_list])
        visited = end_in_list
      }
      out
    }
    // Not supported here.
    Can(_) | Regex(_) => []
  }
  // (Not upstream, whose `QueryCache` has no bound: an introspector lives
  // as long as its document, and a document that a memoized layout keeps
  // is asked by every compilation that finds it, possibly something else
  // each time.)
  if self.queries.length() >= element_queries_max {
    self.queries.clear()
  }
  self.queries[hash] = output
  output
}

///|
/// The greatest number of queries whose results an [ElementIntrospector]
/// keeps: when it is reached they are all forgotten and computed again
/// when they are asked for (see [ElementIntrospector::query]). Far above
/// what one layout of a document asks (a query per located element or
/// so).
let element_queries_max : Int32 = 65536

///|
/// Rust's `Vec::swap_remove`.
fn[T] swap_remove(vec : Array[T], i : Int32) -> T {
  let last = vec.length() - 1
  let item = vec[i]
  vec[i] = vec[last]
  vec.pop() |> ignore
  item
}

///|
/// Rust's `binary_search_by_key`: `(true, i)` if found at `i`, otherwise
/// `(false, i)` with the insertion index. The list must be sorted by `key`.
fn[T] binary_search_by_key(
  list : ArrayView[T],
  target : Int32,
  key : (T) -> Int32,
) -> (Bool, Int32) {
  let mut size = list.length()
  if size == 0 {
    return (false, 0)
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    if key(list[mid]) <= target {
      base = mid
    }
    size -= half
  }
  let k = key(list[base])
  if k == target {
    (true, base)
  } else {
    (false, base + (if k < target { 1 } else { 0 }))
  }
}

///|
/// Queries for the first element that matches the selector.
pub fn[P] ElementIntrospector::query_first(
  self : ElementIntrospector[P],
  selector : Selector,
) -> Content? {
  match selector {
    Location(location) => self.get_by_loc(location)
    Label(label) =>
      self.labels.get(label).get(0).map(idx => self.get_by_idx(idx))
    _ => self.query(selector).get(0)
  }
}

///|
/// Queries for the unique element that matches the selector.
pub fn[P] ElementIntrospector::query_unique(
  self : ElementIntrospector[P],
  selector : Selector,
) -> Content raise HintedError {
  match selector {
    Location(location) =>
      match self.get_by_loc(location) {
        Some(c) => c
        None => bail("element does not exist in the document")
      }
    Label(label) => self.query_label(label)
    _ => {
      let elems = self.query(selector)
      if elems.length() > 1 {
        bail("selector matches multiple elements")
      }
      match elems.get(0) {
        Some(c) => c
        None => bail("selector does not match any element")
      }
    }
  }
}

///|
/// Queries for a unique element with the label.
pub fn[P] ElementIntrospector::query_label(
  self : ElementIntrospector[P],
  label : Label,
) -> Content raise HintedError {
  match self.labels.get(label) {
    [idx] => self.get_by_idx(idx)
    [] => bail("label `\{label.repr()}` does not exist in the document")
    _ => bail("label `\{label.repr()}` occurs multiple times in the document")
  }
}

///|
/// Queries for all elements with a label.
pub fn[P] ElementIntrospector::query_labelled(
  self : ElementIntrospector[P],
) -> Array[Content] {
  self.all().filter(c => c.label() is Some(_))
}

///|
/// An optimized version of `query(selector.before(end, true).len()` used by
/// counters and state.
pub fn[P] ElementIntrospector::query_count_before(
  self : ElementIntrospector[P],
  selector : Selector,
  end : Location,
) -> Int32 {
  // See `query()` for details.
  let list = self.query(selector)
  match self.get_by_loc(end) {
    Some(end) =>
      match self.binary_search(list, end) {
        (true, i) => i + 1
        (false, i) => i
      }
    None => list.length()
  }
}

///|
/// Checks how many times a label exists.
pub fn[P] ElementIntrospector::label_count(
  self : ElementIntrospector[P],
  label : Label,
) -> Int32 {
  self.labels.get(label).length()
}

///|
/// Tries to find a location for an element with the given `key` hash that is
/// closest after the `base`.
pub fn[P] ElementIntrospector::locator(
  self : ElementIntrospector[P],
  key : U128,
  base : Location,
) -> Location? {
  let base = self.loc_index(base).to_uint64()
  let mut best : (UInt64, Location)? = None
  for loc in self.keys.get(key) {
    // `loc_index(loc).wrapping_sub(base)` with `usize` arithmetic.
    let distance = self.loc_index(loc).to_uint64() - base
    match best {
      Some((d, _)) if d <= distance => ()
      _ => best = Some((distance, loc))
    }
  }
  best.map(pair => pair.1)
}

///|
/// Returns the target-specific position of the element at the given
/// location.
pub fn[P] ElementIntrospector::position(
  self : ElementIntrospector[P],
  location : Location,
) -> P? {
  self.locations.get(location).map(r => self.get_pos_by_idx(r.start))
}

///|
/// Iterates over all locatable elements.
pub fn[P] ElementIntrospector::all(
  self : ElementIntrospector[P],
) -> Array[Content] {
  self.elems.map(pair => pair.0)
}

///|
/// The number of introspectable elements.
pub fn[P] ElementIntrospector::len(self : ElementIntrospector[P]) -> Int32 {
  self.elems.length()
}

///|
/// Retrieves the element with the given index.
pub fn[P] ElementIntrospector::get_by_idx(
  self : ElementIntrospector[P],
  idx : Int32,
) -> Content {
  self.elems[idx].0
}

///|
/// Retrieves the position of the element with the given index.
pub fn[P] ElementIntrospector::get_pos_by_idx(
  self : ElementIntrospector[P],
  idx : Int32,
) -> P {
  self.elems[idx].1
}

///|
/// Retrieves an element by its location.
pub fn[P] ElementIntrospector::get_by_loc(
  self : ElementIntrospector[P],
  location : Location,
) -> Content? {
  self.locations.get(location).map(r => self.get_by_idx(r.start))
}

///|
/// Performs a binary search for `elem` among the `list`: `(true, i)` if found
/// at `i`, otherwise `(false, i)` with the insertion index.
pub fn[P] ElementIntrospector::binary_search(
  self : ElementIntrospector[P],
  list : ArrayView[Content],
  elem : Content,
) -> (Bool, Int32) {
  binary_search_by_key(list, self.elem_index(elem), elem => {
    self.elem_index(elem)
  })
}

///|
/// Gets the index of this element.
pub fn[P] ElementIntrospector::elem_index(
  self : ElementIntrospector[P],
  elem : Content,
) -> Int32 {
  self.loc_index(elem.location().unwrap())
}

///|
/// Gets the index of the element with this location among all.
pub fn[P] ElementIntrospector::loc_index(
  self : ElementIntrospector[P],
  location : Location,
) -> Int32 {
  match self.locations.get(location) {
    Some(r) => r.start
    None => usize_max
  }
}

///|
/// Gets the range `(start, end)` of the element with this location among
/// all.
fn[P] ElementIntrospector::loc_range(
  self : ElementIntrospector[P],
  location : Location,
) -> IndexRange {
  match self.locations.get(location) {
    Some(r) => { start: r.start, end: r.end, }
    None => { start: usize_max, end: usize_max, }
  }
}

///|
/// The index range `(start, end)` covering the element with this location
/// and all its conceptual descendants.
pub fn[P] ElementIntrospector::range_of(
  self : ElementIntrospector[P],
  location : Location,
) -> (Int32, Int32)? {
  self.locations.get(location).map(r => (r.start, r.end))
}

///|
/// Constructs the [ElementIntrospector].
pub struct ElementIntrospectorBuilder[P] {
  priv stack : Array[Array[BuilderItem[P]]]
  priv mut sink : Array[BuilderItem[P]]
  priv seen : @hashset.HashSet[Location]
  priv insertions : MultiMap[Location, Array[BuilderItem[P]]]
  priv keys : MultiMap[U128, Location]
  priv locations : Map[Location, IndexRange]
  priv labels : MultiMap[Label, Int32]
}

///|
/// An item in the builder's sink.
priv enum BuilderItem[P] {
  /// Indicates the start of the given element. Also holds its position.
  Start(Content, P)
  /// Indicates the end of the element with the given location.
  End(Location)
}

///|
/// Creates an empty builder.
pub fn[P] ElementIntrospectorBuilder::new() -> ElementIntrospectorBuilder[P] {
  {
    stack: [],
    sink: [],
    seen: @hashset.HashSet([]),
    insertions: MultiMap::new(),
    keys: MultiMap::new(),
    locations: {},
    labels: MultiMap::new(),
  }
}

///|
/// Discovers an introspectible in a tag.
pub fn[P] ElementIntrospectorBuilder::discover_tag(
  self : ElementIntrospectorBuilder[P],
  tag : Tag,
  position : P,
) -> Unit {
  match tag {
    Start(elem, flags) =>
      if flags.introspectable {
        let loc = elem.location().unwrap()
        if self.seen.add_and_check(loc) {
          self.sink.push(Start(elem, position))
        }
      }
    End(loc, key, flags) =>
      if flags.introspectable {
        self.keys.insert(key, loc)
        self.sink.push(End(loc))
      }
  }
}

///|
/// Discovers elements from another already built introspector.
pub fn[P, Q] ElementIntrospectorBuilder::discover_elements(
  self : ElementIntrospectorBuilder[P],
  elements : ElementIntrospector[Q],
  map_position : (Q) -> P,
) -> Unit {
  // Because `elements` is already fully built, we need to basically reverse
  // the already built location ranges back to start/end events. We do this
  // by queueing end events for positions as we visit elements and dequeueing
  // them at the end of the relevant element.
  let queued : MultiMap[Int32, Location] = MultiMap::new()
  for i, pair in elements.elems {
    let (elem, q) = pair
    let loc = elem.location().unwrap()
    if self.seen.add_and_check(loc) {
      let range = elements.locations.get(loc).unwrap()
      let position = map_position(q)
      self.sink.push(Start(elem, position))
      queued.insert(range.end, loc)
    }
    let ends = queued.get(i + 1)
    for j = ends.length() - 1; j >= 0; j = j - 1 {
      self.sink.push(End(ends[j]))
    }
  }
  self.keys.append(elements.keys)
}

///|
/// Future content until a matching `end_insertion` will ordering-wise be
/// treated as belonging to the `parent` passed to `end_insertion`.
pub fn[P] ElementIntrospectorBuilder::start_insertion(
  self : ElementIntrospectorBuilder[P],
) -> Unit {
  self.stack.push(self.sink)
  self.sink = []
}

///|
/// Closes an insertion group started by a matching `start_insertion`.
pub fn[P] ElementIntrospectorBuilder::end_insertion(
  self : ElementIntrospectorBuilder[P],
  parent : Location,
) -> Unit {
  let elems = self.sink
  self.sink = match self.stack.pop() {
    Some(sink) => sink
    None => abort("insertion to have been started")
  }
  self.insertions.insert(parent, elems)
}

///|
/// Builds a complete introspector with all acceleration structures from a
/// list of top-level pairs.
pub fn[P] ElementIntrospectorBuilder::finalize(
  self : ElementIntrospectorBuilder[P],
) -> ElementIntrospector[P] {
  // Save all pairs and their descendants in the correct order.
  let elems = []
  let sink = self.sink
  self.sink = []
  for item in sink {
    self.visit(elems, item)
  }
  {
    elems,
    keys: self.keys,
    locations: self.locations,
    labels: self.labels,
    queries: {},
  }
}

///|
/// Saves a pair and all its descendants into `elems` and populates the
/// acceleration structures.
fn[P] ElementIntrospectorBuilder::visit(
  self : ElementIntrospectorBuilder[P],
  elems : Array[(Content, P)],
  item : BuilderItem[P],
) -> Unit {
  match item {
    Start(elem, pos) => {
      let loc = elem.location().unwrap()
      let idx = elems.length()

      // Populate the location acceleration map. Initially, we insert with a
      // range covering just the element itself. Once we visit the end tag,
      // we update this information.
      self.locations[loc] = { start: idx, end: idx + 1, }

      // Populate the label acceleration map.
      if elem.label() is Some(label) {
        self.labels.insert(label, idx)
      }

      // Save the element.
      elems.push((elem, pos))

      // Process potential descendants.
      if self.insertions.take(loc) is Some(insertions) {
        for group in insertions {
          for pair in group {
            self.visit(elems, pair)
          }
        }
      }
    }
    End(loc) =>
      // Update the end of the element's range.
      if self.locations.get(loc) is Some(entry) {
        entry.end = elems.length()
      }
  }
}
