// The tracked world (not upstream as a structure: comemo's `Tracked<dyn
// World>`, its constraints and its accelerator; `docs/incremental-design.md`,
// section 5.2).
//
// Upstream's engine holds `Tracked<'a, dyn World + 'a>`
// (`typst-library/src/engine.rs`). Every call of a tracked method inside a
// memoized function is recorded in that function's constraint with the hash
// of what it returned (`comemo/src/constraint.rs`, `Constraint`, `emit`),
// and a kept result is only taken if the same calls give the same hashes on
// the world of the later call (`comemo/src/tree.rs`, `CallTree::get`;
// `comemo/src/input.rs`, `Input::call`). Here:
//
// - The engine holds a [TrackedWorld]. Engine code has no `&World`: the
//   raw world is a private field that only this file reads (for `library`
//   itself that is a convention; `scripts/tracked_world_check.py` holds it).
//   The tracked methods are upstream's tracked ones without `library` and
//   `main`, which the port reads once per compilation outside of every
//   memoized call (`typst/lib.mbt`).
// - A *scope* is a stretch of work in which the world does not change
//   ([TrackedWorld::scoped]): a compilation, or an evaluation that is not
//   inside one. The memoized calls of `memo.mbt` and of `eval/import.mbt`
//   are only looked up and stored for an engine whose world is in a scope.
//   A scope has a token of its own and two things:
//   - the *answers*: for every read of the scope the fingerprint of what
//     the world answered, computed when the read is first made (comemo's
//     accelerator, `comemo/src/accelerate.rs`: per tracked reference a map
//     from a call to the hash of its result, so that validation makes a
//     call once; it lives until `evict`, the answers until the scope ends);
//   - the *log*: the reads of the memoized calls in progress, in order. A
//     call owns what was pushed since it started ([TrackedWorld::
//     reads_begin]), which includes what the calls inside it pushed. When
//     it ends ([TrackedWorld::reads_end]) its part is deduplicated, paired
//     with the fingerprints and returned for the entry, and the log is cut
//     back to the deduplicated reads, which are thereby the caller's
//     (`comemo/src/input.rs`, `MergedSink::emit`: a call goes to the
//     constraint of the function and to that of every function around
//     it). A read that is already in the part of the call in progress is
//     not pushed again (`MergedSink::emit`: "If the current sink already
//     deduplicated the value, we don't have to go the previous sink").
// - On a hit ([TrackedWorld::validate]) every read of the entry must have,
//   in the scope at hand, the fingerprint the entry has; a read the scope
//   has no answer for yet is made for that (comemo validates by making the
//   calls, which is also what tells a watching host that the file is still
//   a dependency). The reads are checked in the order in which the call
//   first made them and the check stops at the first that differs, so a
//   read is only made if a fresh run of the call would make it too. The
//   reads of an entry that is taken are pushed to the log as if the call
//   had run (`Input::call`: "It's crucial that we also send calls to the
//   outer sink here so that the outer sink observes the calls when we have
//   a cache hit"). An entry that passed is stamped with the scope's token
//   and not checked again in that scope.
// - Files that change during a scope (`doc`'s origin listing and markup
//   snippets) are declared by a predicate when the tracked world is made.
//   A read of one is not answered from the table and marks the log: a call
//   whose part of the log holds the mark is not stored, nor is any call
//   around it, and an entry with a read that is volatile in the scope at
//   hand is not taken, whatever the file answers.
//
// Not upstream: the state is the tracked world's, not process-wide like
// the route and traced-file logs of `memo.mbt`. An engine of an outer
// scope that is used while an inner scope (another world) is open records
// into its own log. A read through another tracked world while a memoized
// call of this one is in progress (a host function that evaluates or
// compiles with a world of its own) is not in this world's log, so it
// marks the call like a volatile read: the call is not stored
// ([recording_worlds]). So do a scope that is opened for another world
// and an entry that is found for one.

///|
/// One read of a world: a tracked method and its argument.
priv enum WorldRead {
  Source(@syntax.FileId)
  File(@syntax.FileId)
  Book
  Font(Int)
  Today(Duration?)
}

///|
/// What a report of [set_memo_check] calls a read.
fn WorldRead::describe(self : WorldRead) -> String {
  match self {
    Source(id) => "source(\{file_id_name(id)})"
    File(id) => "file(\{file_id_name(id)})"
    Book => "book"
    Font(index) => "font(\{index})"
    Today(None) => "today(none)"
    Today(Some(offset)) => "today(\{offset.0.whole_seconds()}s)"
  }
}

///|
fn file_id_name(id : @syntax.FileId) -> String {
  let path = id.vpath().get_without_slash()
  match id.root() {
    Project => path
    Package(spec) => "\{spec}/\{path}"
  }
}

///|
/// The world reads of a memoized call with the fingerprints of their
/// answers: what an entry keeps ([TrackedWorld::reads_end]) and what must
/// hold for it to be taken ([TrackedWorld::validate]).
pub struct WorldReads {
  /// The reads, without repetitions, in the order in which the call first
  /// made them.
  priv reads : Array[WorldRead]
  /// The fingerprints of their answers.
  priv prints : Array[U128]
  /// The token of the scope in which the reads were last found to give
  /// these answers (at first the scope of the call), and where its answers
  /// for them are.
  priv mut stamp : Int
  priv mut slots : Array[Int]
  /// Whether the call read a volatile file: it must not be stored.
  priv unstorable : Bool
}

///|
/// The reads of a call that read nothing.
let no_world_reads : WorldReads = {
  reads: [],
  prints: [],
  stamp: 0,
  slots: [],
  unstorable: false,
}

///|
/// The reads of a call that read nothing but volatile files.
let volatile_world_reads : WorldReads = {
  reads: [],
  prints: [],
  stamp: 0,
  slots: [],
  unstorable: true,
}

///|
/// Whether the call read a file that changes during a scope: its result
/// must not be stored.
pub fn WorldReads::is_volatile(self : WorldReads) -> Bool {
  self.unstorable
}

///|
/// The number of reads.
pub fn WorldReads::length(self : WorldReads) -> Int {
  self.reads.length()
}

///|
/// The reads and the fingerprints of their answers, for tests and reports.
pub fn WorldReads::describe(self : WorldReads) -> Array[String] {
  let lines = []
  for i, read in self.reads {
    lines.push("\{read.describe()} = \{u128_hex(self.prints[i])}")
  }
  if self.unstorable {
    lines.push("volatile")
  }
  lines
}

///|
fn u128_hex(v : U128) -> String {
  v.hi.to_string(radix=16) + ":" + v.lo.to_string(radix=16)
}

///|
/// The state of a scope: the answers and the log (see the file header).
priv struct WorldScope {
  token : Int
  /// The answers, by slot: a scope numbers the reads it has seen.
  reads : Array[WorldRead]
  prints : Array[U128]
  /// By slot: where in the log the slot was pushed last.
  seen : Array[Int]
  /// By slot: the deduplication that saw the slot last (`dedups`).
  marks : Array[Int]
  /// The slots of the reads, plus one (zero: the scope has no answer):
  /// sources and files by file id, fonts by index.
  sources : Array[Int]
  files : Array[Int]
  fonts : Array[Int]
  mut book : Int
  /// The slots of `today`, by offset.
  today_offsets : Array[Duration?]
  today_slots : Array[Int]
  /// The fonts with an index that `fonts` does not hold.
  other_fonts : Map[Int, Int]
  /// The read lists made last ([WorldScope::kept_reads]).
  lists : Array[WorldReads]
  /// The reads of the memoized calls in progress, as slots.
  log : Array[Int]
  /// Where the part of the innermost call in progress starts.
  mut call_start : Int
  /// The number of calls in progress. Without one nothing is logged.
  mut calls : Int
  /// The number of reads of volatile files.
  mut volatile_reads : Int
  mut dedups : Int
}

///|
/// The tracked worlds that have a memoized call in progress, which is one
/// at nearly all times. A read through any other tracked world marks their
/// calls as not to be stored: what such a call returns may depend on a
/// world whose reads its entry would not hold.
let recording_worlds : Array[TrackedWorld] = []

///|
/// Called by every tracked method, when a scope is opened and when an
/// entry with reads is looked up: marks the calls in progress of the
/// other worlds.
fn TrackedWorld::note_read(self : TrackedWorld) -> Unit {
  let recording = recording_worlds
  if recording.length() == 0 ||
    (recording.length() == 1 && physical_equal(recording[0], self)) {
    return
  }
  for world in recording {
    if !physical_equal(world, self) && world.scope is Some(scope) {
      scope.volatile_reads += 1
    }
  }
}

///|
/// The number of scopes that were opened.
let world_scope_tokens : Ref[Int] = { val: 0, }

///|
/// The tokens of the scopes that are open.
let open_world_scopes : Array[Int] = []

///|
fn WorldScope::new() -> WorldScope {
  world_scope_tokens.val += 1
  {
    token: world_scope_tokens.val,
    reads: [],
    prints: [],
    seen: [],
    marks: [],
    sources: [],
    files: [],
    fonts: [],
    book: 0,
    today_offsets: [],
    today_slots: [],
    other_fonts: {},
    lists: [],
    log: [],
    call_start: 0,
    calls: 0,
    volatile_reads: 0,
    dedups: 0,
  }
}

///|
/// Gives a read its slot.
fn WorldScope::add(self : WorldScope, read : WorldRead, print : U128) -> Int {
  let slot = self.reads.length()
  self.reads.push(read)
  self.prints.push(print)
  self.seen.push(-1)
  self.marks.push(0)
  slot
}

///|
/// Notes a read in the log, unless no memoized call is in progress or the
/// read is in the part of the innermost one already. Must not allocate
/// (but for the growth of the log): shaping asks for the book and a font
/// per text run.
fn WorldScope::push(self : WorldScope, slot : Int) -> Unit {
  if self.calls == 0 {
    return
  }
  let log = self.log
  let pos = self.seen[slot]
  // `pos` may be stale: the log is cut back when a call ends.
  if pos >= self.call_start && pos < log.length() && log[pos] == slot {
    return
  }
  self.seen[slot] = log.length()
  log.push(slot)
}

///|
/// The slot of the indexed table entry `i` (zero: none).
fn slot_at(table : Array[Int], i : Int) -> Int {
  if i < table.length() {
    table[i]
  } else {
    0
  }
}

///|
fn set_slot_at(table : Array[Int], i : Int, slot : Int) -> Unit {
  while table.length() <= i {
    table.push(0)
  }
  table[i] = slot + 1
}

///|
/// Font indices up to which a scope keeps slots in an array.
let world_font_table_max : Int = 65536

///|
/// The environment in which typesetting occurs, as the engine sees it
/// (upstream `Tracked<'a, dyn World + 'a>`): the reads of a world, which
/// are recorded for the memoized calls that make them. See the file header.
pub struct TrackedWorld {
  /// The world. Only this file may read it.
  priv raw : &World
  /// The files that change during a scope.
  priv volatile_files : ((@syntax.FileId) -> Bool)?
  /// The scope, while the world is in one.
  priv mut scope : WorldScope?
}

///|
/// Tracks a world (upstream `world.track()`).
///
/// `volatile_files` says which files change while the world is in a scope; for
/// every other file, and for the fonts and the date, the world must answer
/// the same throughout a scope ([TrackedWorld::scoped]). Between two
/// scopes it may change. Outside of a scope reads pass through and nothing
/// is memoized for an engine that holds the world.
pub fn TrackedWorld::new(
  world : &World,
  volatile_files? : (@syntax.FileId) -> Bool,
) -> TrackedWorld {
  let raw : &World = if memo_check.val { spy_world(world) } else { world }
  { raw, volatile_files, scope: None, }
}

///|
/// Runs `f` with the world in a scope: a stretch of work in which the
/// world does not change and in which results that depend on it may be
/// kept and found (see the file header). A compilation is one, and so is
/// an evaluation that is not inside one. Inside a scope of this world `f`
/// just runs.
pub fn[T] TrackedWorld::scoped(
  self : TrackedWorld,
  f : () -> T raise SourceError,
) -> T raise SourceError {
  if self.scope is Some(_) {
    return f()
  }
  self.open()
  let result = {
    errdefer self.close()
    f()
  }
  self.close()
  result
}

///|
/// Opens a scope of the world, which is in none ([TrackedWorld::scoped]).
fn TrackedWorld::open(self : TrackedWorld) -> Unit {
  guard self.scope is None else { abort("the world is in a scope") }
  // A compilation or an evaluation with this world inside a memoized call
  // of another: what it gives may depend on this world without a tracked
  // read (the library and the main file of a compilation are read around
  // the tracked methods, and it may fail before it reads anything else).
  self.note_read()
  let scope = WorldScope::new()
  self.scope = Some(scope)
  open_world_scopes.push(scope.token)
}

///|
/// Closes the scope of the world.
fn TrackedWorld::close(self : TrackedWorld) -> Unit {
  guard self.scope is Some(scope) else { abort("the world is in no scope") }
  self.scope = None
  // No call of the scope is in progress when it ends; if one were, the
  // world must not stay among those that record.
  if scope.calls != 0 {
    self.stop_recording()
  }
  for i, token in open_world_scopes {
    if token == scope.token {
      open_world_scopes.remove(i) |> ignore
      break
    }
  }
}

///|
/// Whether the world is in a scope: only then is anything memoized for an
/// engine that holds it.
pub fn TrackedWorld::in_scope(self : TrackedWorld) -> Bool {
  self.scope is Some(_)
}

///|
/// The token of the scope the world is in (zero: none). No two scopes of a
/// process have the same.
pub fn TrackedWorld::scope_token(self : TrackedWorld) -> Int {
  match self.scope {
    Some(scope) => scope.token
    None => 0
  }
}

///|
/// Whether the scope with this token is still open.
pub fn world_scope_open(token : Int) -> Bool {
  for open in open_world_scopes {
    if open == token {
      return true
    }
  }
  false
}

///|
/// Whether the file changes during a scope of this world.
pub fn TrackedWorld::is_volatile(
  self : TrackedWorld,
  id : @syntax.FileId,
) -> Bool {
  match self.volatile_files {
    Some(changes) => changes(id)
    None => false
  }
}

// The tracked methods (upstream `trait World`, `typst-library/src/lib.rs`,
// under `#[comemo::track]`).

///|
/// Try to access the specified file location as a source file.
pub fn TrackedWorld::source(
  self : TrackedWorld,
  id : @syntax.FileId,
) -> @syntax.Source raise FileError {
  self.note_read()
  guard self.scope is Some(scope) else { return self.raw.source(id) }
  if self.is_volatile(id) {
    scope.volatile_reads += 1
    return self.raw.source(id)
  }
  let i = id.into_raw().to_int()
  let known = slot_at(scope.sources, i)
  if known != 0 {
    // A failed read is noted before it raises.
    scope.push(known - 1)
    return self.raw.source(id)
  }
  // The first read of the scope: its answer gets a fingerprint.
  let answer : Result[@syntax.Source, FileError] = Ok(self.raw.source(id)) catch {
    error => Err(error)
  }
  let print = match answer {
    Ok(source) => source_answer_print(source)
    Err(error) => failed_answer_print(error)
  }
  let slot = scope.add(Source(id), print)
  set_slot_at(scope.sources, i, slot)
  scope.push(slot)
  match answer {
    Ok(source) => source
    Err(error) => raise error
  }
}

///|
/// Try to access the specified file.
pub fn TrackedWorld::file(
  self : TrackedWorld,
  id : @syntax.FileId,
) -> Bytes raise FileError {
  self.note_read()
  guard self.scope is Some(scope) else { return self.raw.file(id) }
  if self.is_volatile(id) {
    scope.volatile_reads += 1
    return self.raw.file(id)
  }
  let i = id.into_raw().to_int()
  let known = slot_at(scope.files, i)
  if known != 0 {
    scope.push(known - 1)
    return self.raw.file(id)
  }
  let answer : Result[Bytes, FileError] = Ok(self.raw.file(id)) catch {
    error => Err(error)
  }
  let print = match answer {
    Ok(data) => file_answer_print(data)
    Err(error) => failed_answer_print(error)
  }
  let slot = scope.add(File(id), print)
  set_slot_at(scope.files, i, slot)
  scope.push(slot)
  match answer {
    Ok(data) => data
    Err(error) => raise error
  }
}

///|
/// Metadata about all known fonts.
pub fn TrackedWorld::book(self : TrackedWorld) -> FontBook {
  self.note_read()
  let book = self.raw.book()
  guard self.scope is Some(scope) else { return book }
  if scope.book == 0 {
    scope.book = scope.add(Book, book_answer_print(book)) + 1
  }
  scope.push(scope.book - 1)
  book
}

///|
/// Try to access the font with the given index in the font book.
pub fn TrackedWorld::font(self : TrackedWorld, index : Int) -> Font? {
  self.note_read()
  let font = self.raw.font(index)
  guard self.scope is Some(scope) else { return font }
  let slot = if index >= 0 && index < world_font_table_max {
    let known = slot_at(scope.fonts, index)
    if known != 0 {
      known - 1
    } else {
      let slot = scope.add(Font(index), font_answer_print(font))
      set_slot_at(scope.fonts, index, slot)
      slot
    }
  } else {
    match scope.other_fonts.get(index) {
      Some(slot) => slot
      None => {
        let slot = scope.add(Font(index), font_answer_print(font))
        scope.other_fonts[index] = slot
        slot
      }
    }
  }
  scope.push(slot)
  font
}

///|
/// Get the current date.
pub fn TrackedWorld::today(
  self : TrackedWorld,
  offset : Duration?,
) -> Datetime? {
  self.note_read()
  let today = self.raw.today(offset)
  guard self.scope is Some(scope) else { return today }
  let slot = match scope.today_slot(offset) {
    -1 => {
      let slot = scope.add(Today(offset), today_answer_print(today))
      scope.today_offsets.push(offset)
      scope.today_slots.push(slot)
      slot
    }
    slot => slot
  }
  scope.push(slot)
  today
}

///|
/// The slot of `today(offset)`, or -1.
fn WorldScope::today_slot(self : WorldScope, offset : Duration?) -> Int {
  for i, known in self.today_offsets {
    let same = match (known, offset) {
      (None, None) => true
      (Some(a), Some(b)) => a == b
      _ => false
    }
    if same {
      return self.today_slots[i]
    }
  }
  -1
}

// The fingerprints of answers.

///|
/// The fingerprint of a source that a world returned.
///
/// Upstream hashes a `Source` as its id, its text and its numbered tree
/// (`typst-syntax/src/source.rs`, `SourceInner`), once (it is behind a
/// `LazyHash`). The tree is in it because span numbers are not a function
/// of the text: a file that is edited and edited back has the old text
/// and new numbers where it was reparsed. This fingerprint is equal only
/// where upstream's is and costs less (hashing a tree takes 35 times as
/// long as hashing its text): for a source that `Source::new` made the id
/// and the text (its tree is a function of them, `Source::is_pristine`),
/// for any other, the result of an edit, the id and the number of the
/// source object, which no other source has. A source never changes, so
/// the fingerprint of a text is kept in it (`Source::set_memo`).
fn source_answer_print(source : @syntax.Source) -> U128 {
  if !source.is_pristine() {
    return {
      hi: (2UL << 32) | source.id().into_raw().to_int().to_uint64(),
      lo: source.serial().to_uint64(),
    }
  }
  if source.has_memo() {
    return { hi: source.memo_hi(), lo: source.memo_lo(), }
  }
  let state = SipHasher128::new()
  state.write_discriminant(0)
  state.write_u32(source.id().into_raw().to_int().reinterpret_as_uint())
  state.write_str(source.text())
  let print = state.finish128()
  source.set_memo(print.hi, print.lo)
  print
}

///|
/// The fingerprint of the bytes of a file that a world returned: the
/// length and the bytes, as upstream's `Bytes` hashes, kept by the
/// identity of the object ([data_hash]: a world that returns the same
/// object for an unchanged file pays nothing).
fn file_answer_print(data : Bytes) -> U128 {
  let state = SipHasher128::new()
  state.write_discriminant(0)
  state.write_u128(data_hash(data))
  state.finish128()
}

///|
/// The fingerprint of a failed read of a source or a file: the error with
/// all of its payload (upstream `FileError` derives `Hash`), not its
/// message, which two errors can share.
fn failed_answer_print(error : FileError) -> U128 {
  let state = SipHasher128::new()
  state.write_discriminant(1)
  match error {
    NotFound(path) => {
      state.write_discriminant(0)
      state.write_str(path)
    }
    AccessDenied => state.write_discriminant(1)
    IsDirectory => state.write_discriminant(2)
    NotSource => state.write_discriminant(3)
    InvalidUtf8 => state.write_discriminant(4)
    Realize(error) => {
      state.write_discriminant(5)
      state.write_str(Show::to_string(error))
    }
    Package(error) => {
      state.write_discriminant(6)
      let version = (version : @syntax.PackageVersion) => {
        state.write_u32(version.major)
        state.write_u32(version.minor)
        state.write_u32(version.patch)
      }
      let spec = (spec : @syntax.PackageSpec) => {
        state.write_str(spec.namespace_)
        state.write_str(spec.name)
        version(spec.version)
      }
      let detail = (detail : String?) => {
        match detail {
          None => state.write_discriminant(0)
          Some(detail) => {
            state.write_discriminant(1)
            state.write_str(detail)
          }
        }
      }
      match error {
        NotFound(package_) => {
          state.write_discriminant(0)
          spec(package_)
        }
        VersionNotFound(package_, latest) => {
          state.write_discriminant(1)
          spec(package_)
          version(latest)
        }
        NetworkFailed(message) => {
          state.write_discriminant(2)
          detail(message)
        }
        MalformedArchive(message) => {
          state.write_discriminant(3)
          detail(message)
        }
        Other(message) => {
          state.write_discriminant(4)
          detail(message)
        }
      }
    }
    Other(message) => {
      state.write_discriminant(7)
      match message {
        None => state.write_discriminant(0)
        Some(message) => {
          state.write_discriminant(1)
          state.write_str(message)
        }
      }
    }
  }
  state.finish128()
}

///|
/// The fingerprint of the font book that a world returned: the state of
/// the book object ([FontBook::edition], which says why it is not a hash
/// of the infos as upstream's is). Two books with the same infos are two
/// answers.
fn book_answer_print(book : FontBook) -> U128 {
  { hi: 1, lo: book.edition().to_uint64(), }
}

///|
/// The fingerprint of a font that a world returned: the font object
/// ([Font::serial], which says why it is not upstream's `Hash for Font`),
/// or its absence. Two font objects of the same data are two answers.
fn font_answer_print(font : Font?) -> U128 {
  match font {
    None => { hi: 0, lo: 0, }
    Some(font) => { hi: 1, lo: font.serial().to_uint64(), }
  }
}

///|
/// The fingerprint of the date that a world returned, or of its absence.
fn today_answer_print(today : Datetime?) -> U128 {
  let state = SipHasher128::new()
  match today {
    None => state.write_discriminant(0)
    Some(today) => {
      state.write_discriminant(1)
      state.write(today)
    }
  }
  state.finish128()
}

// Recording.

///|
/// Where a memoized call started in the log ([TrackedWorld::reads_begin]).
#valtype
pub struct WorldReadsMark {
  /// Where the part of the call around this one starts (-1: no scope).
  priv outer : Int
  /// The number of volatile reads so far.
  priv volatile_reads : Int
}

///|
/// Starts collecting the world reads of a memoized call. What it returns
/// goes to [TrackedWorld::reads_end] if the call returns and to
/// [TrackedWorld::reads_abort] if it raises.
pub fn TrackedWorld::reads_begin(self : TrackedWorld) -> WorldReadsMark {
  match self.scope {
    None => { outer: -1, volatile_reads: 0, }
    Some(scope) => {
      let mark = {
        outer: scope.call_start,
        volatile_reads: scope.volatile_reads,
      }
      scope.call_start = scope.log.length()
      if scope.calls == 0 {
        recording_worlds.push(self)
      }
      scope.calls += 1
      mark
    }
  }
}

///|
/// The world reads since the matching [TrackedWorld::reads_begin], without
/// repetitions, in the order in which they were first made, with the
/// fingerprints of their answers. The calls around this one keep them.
pub fn TrackedWorld::reads_end(
  self : TrackedWorld,
  mark : WorldReadsMark,
) -> WorldReads {
  guard mark.outer >= 0 && self.scope is Some(scope) else {
    return no_world_reads
  }
  let log = scope.log
  let start = scope.call_start
  let unstorable = scope.volatile_reads != mark.volatile_reads
  scope.call_start = mark.outer
  scope.calls -= 1
  let end = log.length()
  let result = if end == start {
    if unstorable {
      volatile_world_reads
    } else {
      no_world_reads
    }
  } else {
    scope.dedups += 1
    let serial = scope.dedups
    let mut next = start
    for i in start..<end {
      let slot = log[i]
      if scope.marks[slot] != serial {
        scope.marks[slot] = serial
        log[next] = slot
        scope.seen[slot] = next
        next += 1
      }
    }
    log.truncate(next)
    scope.kept_reads(start, unstorable)
  }
  if scope.calls == 0 {
    log.clear()
    self.stop_recording()
  }
  result
}

///|
/// The number of read lists a scope remembers ([WorldScope::kept_reads]).
let world_kept_reads_max : Int = 8

///|
/// The reads from `start` to the end of the log, which are deduplicated,
/// with their fingerprints. Most calls of a compilation read what a call
/// before them read (the book and the fonts of the text), so the scope
/// remembers the last lists it made and hands out the same object for the
/// same reads: one object and four arrays less per entry, and one check
/// for all of them when they are validated in another scope.
fn WorldScope::kept_reads(
  self : WorldScope,
  start : Int,
  unstorable : Bool,
) -> WorldReads {
  let log = self.log
  let count = log.length() - start
  if !unstorable {
    for known in self.lists {
      // The slots of a list are this scope's as long as its stamp is.
      if known.stamp == self.token && known.slots.length() == count {
        let slots = known.slots
        let mut same = true
        for i in 0..<count {
          if slots[i] != log[start + i] {
            same = false
            break
          }
        }
        if same {
          return known
        }
      }
    }
  }
  let slots = []
  let reads = []
  let prints = []
  for i in start..<log.length() {
    let slot = log[i]
    slots.push(slot)
    reads.push(self.reads[slot])
    prints.push(self.prints[slot])
  }
  let list = { reads, prints, stamp: self.token, slots, unstorable, }
  if !unstorable {
    if self.lists.length() >= world_kept_reads_max {
      self.lists.pop() |> ignore
    }
    self.lists.insert(0, list)
  }
  list
}

///|
/// The world has no memoized call in progress any more.
fn TrackedWorld::stop_recording(self : TrackedWorld) -> Unit {
  let recording = recording_worlds
  let mut i = recording.length() - 1
  while i >= 0 {
    if physical_equal(recording[i], self) {
      recording.remove(i) |> ignore
      return
    }
    i -= 1
  }
}

///|
/// Ends the collection of a call that raised: nothing is kept for it, and
/// what it read stays in the log for the calls around it (one of them may
/// go on: `Engine::delay`).
pub fn TrackedWorld::reads_abort(
  self : TrackedWorld,
  mark : WorldReadsMark,
) -> Unit {
  guard mark.outer >= 0 && self.scope is Some(scope) else { return }
  scope.call_start = mark.outer
  scope.calls -= 1
  if scope.calls == 0 {
    scope.log.clear()
    self.stop_recording()
  }
}

///|
/// Whether an entry with these world reads may be taken for a call in the
/// scope at hand: none of the reads is of a volatile file, and each has
/// the answer it had (see the file header). If so, the reads are noted for
/// the calls in progress, as if the call had run. Call it last of the
/// conditions of a hit: it makes the reads that the scope has no answer
/// for.
pub fn TrackedWorld::validate(self : TrackedWorld, reads : WorldReads) -> Bool {
  if reads.unstorable {
    return false
  }
  if reads.reads.is_empty() {
    return true
  }
  // What is found here was read of this world: for a call in progress of
  // another world that is a read through this one, like one a tracked
  // method makes.
  self.note_read()
  guard self.scope is Some(scope) else { return false }
  if reads.stamp != scope.token {
    // Stores cross worlds and file ids are interned by path: an entry
    // that another world stored for a real file must not be found where
    // the file of that path is volatile.
    if self.volatile_files is Some(changes) {
      for read in reads.reads {
        match read {
          Source(id) | File(id) => if changes(id) { return false }
          _ => ()
        }
      }
    }
    let slots = []
    for i, read in reads.reads {
      let slot = self.slot_of(scope, read)
      if scope.prints[slot] != reads.prints[i] {
        return false
      }
      slots.push(slot)
    }
    reads.slots = slots
    reads.stamp = scope.token
  }
  for slot in reads.slots {
    scope.push(slot)
  }
  true
}

///|
/// The slot of a read in the scope; the read is made if the scope has no
/// answer for it yet.
fn TrackedWorld::slot_of(
  self : TrackedWorld,
  scope : WorldScope,
  read : WorldRead,
) -> Int {
  match read {
    Source(id) => {
      let i = id.into_raw().to_int()
      let known = slot_at(scope.sources, i)
      if known != 0 {
        return known - 1
      }
      let print = try self.raw.source(id) catch {
        error => failed_answer_print(error)
      } noraise {
        source => source_answer_print(source)
      }
      let slot = scope.add(read, print)
      set_slot_at(scope.sources, i, slot)
      slot
    }
    File(id) => {
      let i = id.into_raw().to_int()
      let known = slot_at(scope.files, i)
      if known != 0 {
        return known - 1
      }
      let print = try self.raw.file(id) catch {
        error => failed_answer_print(error)
      } noraise {
        data => file_answer_print(data)
      }
      let slot = scope.add(read, print)
      set_slot_at(scope.files, i, slot)
      slot
    }
    Book => {
      if scope.book == 0 {
        scope.book = scope.add(Book, book_answer_print(self.raw.book())) + 1
      }
      scope.book - 1
    }
    Font(index) =>
      if index >= 0 && index < world_font_table_max {
        let known = slot_at(scope.fonts, index)
        if known != 0 {
          return known - 1
        }
        let slot = scope.add(read, font_answer_print(self.raw.font(index)))
        set_slot_at(scope.fonts, index, slot)
        slot
      } else {
        match scope.other_fonts.get(index) {
          Some(slot) => slot
          None => {
            let slot = scope.add(read, font_answer_print(self.raw.font(index)))
            scope.other_fonts[index] = slot
            slot
          }
        }
      }
    Today(offset) =>
      match scope.today_slot(offset) {
        -1 => {
          let slot = scope.add(read, today_answer_print(self.raw.today(offset)))
          scope.today_offsets.push(offset)
          scope.today_slots.push(slot)
          slot
        }
        slot => slot
      }
  }
}
