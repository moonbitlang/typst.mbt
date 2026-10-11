// The `recompile` stage: one world, compiled again after every edit, must
// give what a compilation from scratch of the same files gives.
// `tests/recompile/README.md` says why, what is covered and how it was
// shown to catch stale results.
//
//   recompile [filter] [--seed=N] [--rounds=N] [--sequences=N] [--steps=N]
//             [--all] [--only=NAME] [--list] [--names] [--edits] [--verbose]
//             [--times] [--trace] [--snapshots=DIR]
//   recompile --replay=DIR [--all]
//
// A case is a sequence of edits of one document (`recompile_edits.mbt`):
// the sweep, which changes everything the document depends on once, and
// random sequences, which are a function of the run's seed, the document
// and their number. A sequence runs in two phases.
//
// 1. The watch loop, with nothing else in between: the world
//    (`recompile_world.mbt`) is compiled, and then for every edit changed,
//    reset and compiled again, exactly as `cli/watch.mbt` does
//    (`world.reset()`, the compilation with its exports,
//    `@library.evict(10)`). What every compilation gave is kept
//    (`recompile_compare.mbt`), with a snapshot of the files. After every
//    compilation the document of the step before is exported again: it
//    must still be what it was (a host may hold it while it compiles).
// 2. The references: for every step, a fresh world of the snapshot is
//    compiled, once as it is and once with memoization off
//    (`@library.set_layout_memo_enabled(false)`), each after
//    `@library.evict(1)` has dropped what the process keeps by content.
//    Each must give what the watch loop gave at that step. (The documents
//    that take long have the second reference only.)
//
// The phases are not interleaved on purpose. A cache that outlives a
// compilation may keep only the last one: with a fresh compilation between
// two steps of the loop it would never be asked for the step before, and
// the stage would pass without testing it. Nothing in phase 1 touches
// engine state but what the watch loop of the CLI does, except that it
// exports both an SVG and a PDF, and the SVG of the document before once
// more. (The sequences of a run do follow each other in one process, as the
// compilations of several worlds of one host do.)
//
// A reference in the same process cannot see through a cache that neither
// `set_layout_memo_enabled(false)` turns off nor `evict(1)` drops. For that
// there is a reference in another process: `--snapshots=DIR` writes the
// files of every step before it is compiled and a digest of what it gave
// after, and `--replay=DIR/<document>/<sequence>/step<N>` compiles one such
// snapshot as the first compilation of a process and prints its digest
// (`scripts/recompile_soak.py` compares them). The snapshot that has no
// digest is the one whose compilation killed the runner: an edit can make
// the compiler abort where upstream panics (a frame of infinite size, for
// one), and replaying that snapshot tells whether the abort has anything
// to do with compiling again.
//
// Sizes: by default every document runs the sweep and `default_sequences`
// random sequences of `default_steps` edits; the documents that take long
// (`recompile_heavy`, and those with packages) run a short sweep only.
// That is the CI run. `--sequences` and `--steps` size the random sequences
// of every document, `--rounds` repeats everything with that many seeds
// counting up from `--seed`, and `--all` adds `bench/longer` and every
// document of `tests/packages/docs`: soak runs. A failure names the seed,
// the sequence and the step, and its files are written to
// `_build/recompile/`. `--trace` prints every sequence and edit before it
// runs.

///|
/// The random sequences of a document.
let default_sequences : Int = 1

///|
/// The edits of a random sequence.
let default_steps : Int = 6

///|
/// The most files, besides the main file, that a sweep edits.
let sweep_files : Int = 16

///|
/// The same for a document that takes long.
let heavy_sweep_files : Int = 1

///|
/// The documents whose compilation takes long, besides those with
/// packages.
let recompile_heavy : ReadOnlyArray[String] = [
  "bench/long", "bench/longer", "bench/showcase",
]

///|
/// The size of a run.
priv struct RecompileOptions {
  seed : Int
  rounds : Int
  /// `None`: the default of the document.
  sequences : Int?
  steps : Int
  verbose : Bool
  times : Bool
  /// Where the snapshots of the steps are written, if anywhere.
  snapshots : String?
}

///|
/// What is counted per kind of edit: the steps, those that did not compile
/// and those that gave other pages than the step before.
priv struct EditCount {
  mut steps : Int
  mut errors : Int
  mut changed : Int
}

///|
/// The counts of a run. What the steps did is counted on the references
/// without memoization, not on the watch loop: with a stale result the
/// loop would say that nothing changed.
priv struct RecompileStats {
  mut documents : Int
  mut sequences : Int
  mut steps : Int
  mut compilations : Int
  /// Steps whose document did not compile.
  mut errors : Int
  /// Steps that gave other pages than the step before.
  mut changed : Int
  /// Steps that gave other files to watch than the step before.
  mut rewatched : Int
  /// Steps of the watch loop with a source whose tree is not what a parse
  /// gives, and those of them that gave something else than a fresh
  /// compilation (which is not a failure).
  mut reparsed : Int
  mut reparsed_differing : Int
  /// By the kind of the edit.
  edits : Map[String, EditCount]
}

///|
/// A step of a sequence: the edit, what the world was after it and what the
/// watch loop's compilation gave.
priv struct RecompileStep {
  edit : String
  snapshot : Snapshot
  compiled : Compiled
}

///|
/// The value of `--name=N` (not negative).
fn int_option(args : Array[String], name : String) -> Int? {
  let prefix = "--\{name}="
  for arg in args {
    if arg.has_prefix(prefix) {
      let value = arg.unsafe_substring(start=prefix.length(), end=arg.length())
      let n = @string.parse_int(value) catch {
        _ => abort("recompile: bad value of --\{name}: \{value}")
      }
      guard n >= 0 else { abort("recompile: bad value of --\{name}: \{value}") }
      return Some(n)
    }
  }
  None
}

///|
/// The value of `--name=TEXT`.
fn string_option(args : Array[String], name : String) -> String? {
  let prefix = "--\{name}="
  for arg in args {
    if arg.has_prefix(prefix) {
      return Some(arg.unsafe_substring(start=prefix.length(), end=arg.length()))
    }
  }
  None
}

///|
/// Run the stage.
fn run_recompile_stage(
  args : Array[String],
  filter : String?,
  verbose : Bool,
) -> Unit {
  let options : RecompileOptions = {
    seed: int_option(args, "seed").unwrap_or(1),
    rounds: int_option(args, "rounds").unwrap_or(1),
    sequences: int_option(args, "sequences"),
    steps: int_option(args, "steps").unwrap_or(default_steps),
    verbose,
    times: args.contains("--times"),
    snapshots: string_option(args, "snapshots"),
  }
  let all = args.contains("--all")
  let missing : Array[String] = []
  let groups = [
    (
      "recompile",
      [..repository_documents(missing, all), ..suite_documents(missing)],
    ),
  ]
  // The documents with packages have a summary line of their own: without
  // the packages it has no cases (which `scripts/ci/stages.py` rejects, as
  // for the `packages` stage).
  if @fs.path_exists(packages_dir) {
    groups.push(("recompile packages", package_documents(missing, all)))
  } else {
    println("recompile: \{packages_dir} is missing (run scripts/packages.sh)")
    groups.push(("recompile packages", []))
  }
  if string_option(args, "replay") is Some(dir) {
    replay_snapshot(dir, [..groups[0].1, ..groups[1].1])
    return
  }
  // `--only=<name>`: the document of that name (a filter also selects the
  // documents whose names contain it).
  let only = string_option(args, "only")
  let selected = (name : String) => {
    !(filter is Some(f) && !name.contains(f)) &&
    !(only is Some(only) && name != only)
  }
  if args.contains("--list") || args.contains("--names") {
    for group in groups {
      for document in group.1 {
        if !selected(document.name) {
          continue
        }
        if args.contains("--names") {
          println(document.name)
        } else {
          list_document(document)
        }
      }
    }
    return
  }
  let stats : RecompileStats = {
    documents: 0,
    sequences: 0,
    steps: 0,
    compilations: 0,
    errors: 0,
    changed: 0,
    rewatched: 0,
    reparsed: 0,
    reparsed_differing: 0,
    edits: Map([]),
  }
  let failures = []
  let summaries = []
  for group in groups {
    let (label, documents) = group
    let mut passed = 0
    let mut failed = 0
    for document in documents {
      if !selected(document.name) {
        continue
      }
      stats.documents += 1
      let heavy = recompile_heavy[:].contains(document.name) ||
        document.flavor is Packages
      let sequences = match options.sequences {
        Some(n) => n
        None => if heavy { 0 } else { default_sequences }
      }
      let start = @env.now()
      for round in 0..<options.rounds {
        let seed = options.seed + round
        // The sweep is sequence -1.
        for sequence in -1..<sequences {
          if trace_tests.val {
            println("TRACE \{document.name} seed=\{seed} sequence=\{sequence}")
          }
          let rng : Rng = {
            state: sequence_seed(seed, document.name, sequence),
          }
          let plan : Plan = if sequence < 0 {
            Sweep(
              Sweep::new(
                if heavy {
                  heavy_sweep_files
                } else {
                  sweep_files
                },
                !heavy,
              ),
            )
          } else {
            Random(options.steps)
          }
          let name = if sequence < 0 { "sweep" } else { sequence.to_string() }
          match
            run_sequence(document, seed, name, rng, plan, heavy, stats, options) {
            None => passed += 1
            Some(failure) => {
              failed += 1
              failures.push(failure)
            }
          }
        }
      }
      if options.times {
        println("TIME \{@env.now() - start} ms \{document.name}")
      }
    }
    // A listed document that is not there fails.
    for name in missing {
      let mine = name.has_prefix("packages/") == (label == "recompile packages")
      if mine && selected(name) {
        failed += 1
        failures.push("FAIL \{name} :: the document is missing")
      }
    }
    summaries.push("\{label}: \{passed} passed, \{failed} failed")
  }
  for failure in failures {
    println(failure)
  }
  for summary in summaries {
    println(summary)
  }
  println(
    "recompile: \{stats.documents} documents, \{stats.sequences} sequences, \{stats.steps} steps, \{stats.compilations} compilations; of the steps \{stats.errors} did not compile, \{stats.changed} changed the pages, \{stats.rewatched} changed the dependencies",
  )
  if stats.reparsed > 0 {
    println(
      "recompile: \{stats.reparsed} steps had a source whose reparsed tree is not what a parse gives; \{stats.reparsed_differing} of them gave something else than a fresh compilation and were not compared",
    )
  }
  if args.contains("--edits") {
    let kinds = stats.edits.keys().to_array()
    kinds.sort_by(@library.compare_str)
    for kind in kinds {
      let count = stats.edits[kind]
      println(
        "recompile: \{kind}: \{count.steps} steps, \{count.errors} did not compile, \{count.changed} changed the pages",
      )
    }
  }
  // A run that compared nothing is not a run that passed.
  if stats.steps == 0 && failures.is_empty() {
    println("recompile: nothing was selected")
    @sys.exit(2)
  }
}

///|
/// Prints what the first compilation of a document gives (`--list`).
fn list_document(document : Document) -> Unit {
  let files = FileSet::new(document.base, document.files)
  let variant : Variant = { main: document.main, inputs: 0, day: 0, fonts: 0, }
  let world = RecompileWorld::new(document.flavor, files, variant)
  let start = @env.now()
  let (compiled, ids) = recompile_compile(world)
  let ms = @env.now() - start
  let status = if compiled.ok { "ok " } else { "err" }
  println(
    "\{status} \{document.name}: \{ids.length()} dependencies, \{compiled.pdf.length()} bytes of PDF, \{ms} ms",
  )
  let diagnostics = compiled.parts[1]
  if diagnostics != "ok\n" {
    println(diagnostics.trim_end(chars="\n"))
  }
}

///|
/// How a sequence gets its edits.
priv enum Plan {
  /// The sweep.
  Sweep(Sweep)
  /// That many random edits.
  Random(Int)
}

///|
/// The kind of an edit: the first word of what it says it did, after what
/// the sweep undoes along with it.
fn edit_kind(edit : String) -> String {
  let mut edit = edit
  while edit.has_prefix("undo ") || edit.has_prefix("fonts 0 + ") {
    guard edit.find(" + ") is Some(i) else { break }
    edit = edit.unsafe_substring(start=i + 3, end=edit.length())
  }
  if edit.contains(" + ") {
    return "two-files"
  }
  match edit.find(" ") {
    Some(i) => edit.unsafe_substring(start=0, end=i)
    None => edit
  }
}

///|
/// Runs a sequence. Returns the `FAIL` line (and, verbosely, what differs)
/// if a step of the watch loop gave something else than a fresh
/// compilation, or changed the document of the step before.
fn run_sequence(
  document : Document,
  seed : Int,
  name : String,
  rng : Rng,
  plan : Plan,
  heavy : Bool,
  stats : RecompileStats,
  options : RecompileOptions,
) -> String? {
  read_check_case.val = "\{document.name} seed=\{seed} sequence=\{name}"
  let files = FileSet::new(document.base, document.files)
  let variant : Variant = { main: document.main, inputs: 0, day: 0, fonts: 0, }
  let project = Project::new(files, variant)
  stats.sequences += 1
  let snapshots = options.snapshots.map(dir => {
    "\{dir}/\{document.name}/seed\{seed}-sequence-\{name}"
  })

  // The watch loop (`cli/watch.mbt`).
  let world = RecompileWorld::new(document.flavor, files, variant)
  let done : Array[RecompileStep] = []
  // The steps during whose compilation the document before them changed.
  let disturbed : Array[Int] = []
  for step = 0; ; step = step + 1 {
    let edit = if step == 0 {
      "the first compilation"
    } else {
      let edit = match plan {
        Sweep(sweep) =>
          project.sweep(rng, sweep, done[done.length() - 1].compiled.ok)
        Random(steps) =>
          if step <= steps {
            Some(project.edit(rng))
          } else {
            None
          }
      }
      guard edit is Some(edit) else { break }
      world.set_variant(project.variant)
      // Reset all dependencies.
      world.reset()
      edit
    }
    if trace_tests.val {
      println("TRACE   step \{step}: \{edit}")
    }
    let snapshot = world.snapshot()
    if snapshots is Some(dir) {
      write_snapshot("\{dir}/step\{step}", document.name, snapshot)
    }
    // Recompile.
    let (compiled, ids) = recompile_compile(world)
    // Evict the cache.
    if step > 0 {
      @library.evict(10)
    }
    if snapshots is Some(dir) {
      write_file(
        "\{dir}/step\{step}/digest.txt",
        @utf8.encode(compiled.digest()),
      )
      // A compilation of a tree that a parse does not give is not what a
      // new process gives either.
      if !compiled.reparsed.is_empty() {
        write_file(
          "\{dir}/step\{step}/reparsed.txt",
          @utf8.encode(compiled.reparsed.join("\n")),
        )
      }
    }
    project.note(ids)
    stats.steps += 1
    stats.compilations += 1
    if done.last() is Some(before) {
      // The document of the step before is what it was.
      if before.compiled.document is Some(doc) {
        if recompile_svg(doc) != before.compiled.parts[part_svg] {
          disturbed.push(step)
        }
        before.compiled.document = None
      }
      if trace_tests.val {
        let status = if compiled.ok { "compiled" } else { "did not compile" }
        let pages = if before.compiled.parts[part_frames] !=
          compiled.parts[part_frames] {
          "other pages"
        } else {
          "the same pages"
        }
        println("TRACE     \{status}, \{pages}")
      }
    }
    done.push({ edit, snapshot, compiled, })
  }
  done[done.length() - 1].compiled.document = None

  // The references. Every step is compared; what differs is shown for the
  // first that does. A document that takes long has the reference without
  // memoization only (the one that no memo of the process reaches).
  let steps = done.length() - 1
  let references = if heavy { [false] } else { [true, false] }
  let mut failure : (Int, String)? = None
  let also : Array[Int] = []
  let mut before : Compiled? = None
  for step, at in done {
    // A tree that a parse does not give (upstream's reparser) is no stale
    // result: the step is counted, not compared.
    let reparsed = !at.compiled.reparsed.is_empty()
    if reparsed {
      stats.reparsed += 1
    }
    let mut differing = false
    for memoized in references {
      @library.evict(1)
      @library.set_layout_memo_enabled(memoized)
      let fresh = RecompileWorld::new(
        document.flavor,
        at.snapshot.files,
        at.snapshot.variant,
      )
      let (expected, _) = recompile_compile(fresh)
      @library.set_layout_memo_enabled(true)
      expected.document = None
      stats.compilations += 1
      if !memoized {
        count_step(stats, at.edit, before, expected)
        before = Some(expected)
      }
      guard expected.difference(at.compiled) is Some((parts, detail)) else {
        continue
      }
      if reparsed {
        if !differing {
          differing = true
          stats.reparsed_differing += 1
          if options.verbose {
            println(
              "NOTE \{document.name} :: seed=\{seed} sequence=\{name} step=\{step}: not compared, the reparsed tree of \{at.compiled.reparsed.join(", ")} is not what a parse gives (\{parts.join(", ")} differ)",
            )
          }
        }
        continue
      }
      if failure is Some((first, _)) {
        if first != step && !also.contains(step) {
          also.push(step)
        }
        continue
      }
      let reference = if memoized {
        "a fresh compilation"
      } else {
        "a fresh compilation without memoization"
      }
      let out = StringBuilder()
      out.write_string("\{parts.join(", ")} differ from \{reference}")
      let dir = "_build/recompile/\{document.name}/seed\{seed}-sequence-\{name}"
      if options.verbose {
        for i in 0..<=step {
          out.write_string("\n  step \{i}: \{done[i].edit}")
        }
        out.write_string("\n\{detail}\n  (files in \{dir})")
      }
      dump_failure(dir, done, step, parts[0], expected, at.compiled)
      failure = Some((step, out.to_string()))
    }
  }
  let said = []
  if failure is Some((step, detail)) {
    let also = if also.is_empty() {
      ""
    } else {
      " (also at \{also.map(s => s.to_string()).join(", ")})"
    }
    said.push("step=\{step} of \{steps}\{also}: \{detail}")
  }
  if !disturbed.is_empty() {
    let at = disturbed.map(s => s.to_string()).join(", ")
    said.push(
      "the compilation of step \{at} changed the document of the step before",
    )
  }
  if said.is_empty() {
    None
  } else {
    Some(
      "FAIL \{document.name} :: seed=\{seed} sequence=\{name} \{said.join("; ")}",
    )
  }
}

///|
/// Counts what a step did, on its reference without memoization and the
/// one of the step before.
fn count_step(
  stats : RecompileStats,
  edit : String,
  before : Compiled?,
  compiled : Compiled,
) -> Unit {
  if !compiled.ok {
    stats.errors += 1
  }
  guard before is Some(before) else { return }
  let changed = before.parts[part_frames] != compiled.parts[part_frames]
  if changed {
    stats.changed += 1
  }
  if before.parts[0] != compiled.parts[0] {
    stats.rewatched += 1
  }
  let kind = edit_kind(edit)
  let count = match stats.edits.get(kind) {
    Some(count) => count
    None => {
      let count : EditCount = { steps: 0, errors: 0, changed: 0, }
      stats.edits[kind] = count
      count
    }
  }
  count.steps += 1
  if !compiled.ok {
    count.errors += 1
  }
  if changed {
    count.changed += 1
  }
}

///|
fn write_file(path : String, content : Bytes) -> Unit {
  ensure_parent_dir(path)
  @fs.write_bytes_to_file(path, content) catch {
    _ => println("recompile: cannot write \{path}")
  }
}

///|
/// Writes what is needed to look at a failure: the edits, the edited files
/// at the failing step and at the one before, and both sides of the part
/// that differs.
fn dump_failure(
  dir : String,
  done : Array[RecompileStep],
  step : Int,
  part : String,
  expected : Compiled,
  actual : Compiled,
) -> Unit {
  let edits = StringBuilder()
  for i in 0..<=step {
    let variant = done[i].snapshot.variant
    edits.write_string(
      "step \{i}: \{done[i].edit} (main \{file_path(variant.main)}, inputs \{variant.inputs}, day \{variant.day}, fonts \{variant.fonts})\n",
    )
  }
  write_file("\{dir}/edits.txt", @utf8.encode(edits.to_string()))
  let index = compiled_parts[:].search(part).unwrap_or(0)
  let name = part.replace_all(old=" ", new="-")
  if part == "pdf" {
    write_file("\{dir}/expected.pdf", expected.pdf)
    write_file("\{dir}/actual.pdf", actual.pdf)
  } else {
    write_file(
      "\{dir}/expected-\{name}.txt",
      @utf8.encode(expected.parts[index]),
    )
    write_file("\{dir}/actual-\{name}.txt", @utf8.encode(actual.parts[index]))
  }
  for i in [step - 1, step] {
    if i < 0 {
      continue
    }
    for id, content in done[i].snapshot.files.overlay {
      let path = file_path(id)
        .replace_all(old="@", new="_")
        .replace_all(old=":", new="_")
      match content {
        Some(bytes) => write_file("\{dir}/step\{i}/\{path}", bytes)
        None => write_file("\{dir}/step\{i}/\{path}.removed", b"")
      }
    }
  }
}

///|
/// Writes a snapshot: `meta.txt` (the document, what is not a file, and
/// the edited files by their names) and the bytes of the edited files as
/// `files/<number>`.
fn write_snapshot(dir : String, document : String, snapshot : Snapshot) -> Unit {
  let variant = snapshot.variant
  let meta = StringBuilder()
  meta.write_string("document \{document}\n")
  meta.write_string("main \{file_path(variant.main)}\n")
  meta.write_string("inputs \{variant.inputs}\n")
  meta.write_string("day \{variant.day}\n")
  meta.write_string("fonts \{variant.fonts}\n")
  let mut n = 0
  for id, content in snapshot.files.overlay {
    match content {
      Some(bytes) => {
        meta.write_string("file \{n} \{file_path(id)}\n")
        write_file("\{dir}/files/\{n}", bytes)
        n += 1
      }
      None => meta.write_string("removed \{file_path(id)}\n")
    }
  }
  write_file("\{dir}/meta.txt", @utf8.encode(meta.to_string()))
}

///|
/// The file that [file_path] names.
fn file_of_path(path : String) -> @syntax.FileId {
  guard path.has_prefix("@") else { return project_file(path) }
  // `@namespace/name:version/path`.
  guard path.find(":") is Some(colon) &&
    path.view(start_offset=colon).find("/") is Some(slash) else {
    abort("recompile: bad file name in a snapshot: \{path}")
  }
  let slash = colon + slash
  guard @syntax.PackageSpec::from_str(path.unsafe_substring(start=0, end=slash))
    is Ok(spec) else {
    abort("recompile: bad package in a snapshot: \{path}")
  }
  let vpath = @syntax.VirtualPath::new(
    path.unsafe_substring(start=slash + 1, end=path.length()),
  ) catch {
    e => abort(e.to_string())
  }
  @syntax.RootedPath::new(Package(spec), vpath).intern()
}

///|
/// Compiles a snapshot in a fresh world, as the first compilation of this
/// process, and prints the digest of what it gave (`--replay`).
fn replay_snapshot(dir : String, documents : Array[Document]) -> Unit {
  let meta = read("\{dir}/meta.txt")
  let mut name = ""
  let mut main = ""
  let numbers : Map[String, Int] = Map([])
  let overlay : Array[(@syntax.FileId, Bytes?)] = []
  for line in meta.split("\n") {
    let line = line.to_owned()
    guard line.find(" ") is Some(space) else { continue }
    let key = line.unsafe_substring(start=0, end=space)
    let value = line.unsafe_substring(start=space + 1, end=line.length())
    match key {
      "document" => name = value
      "main" => main = value
      "inputs" | "day" | "fonts" =>
        numbers[key] = @string.parse_int(value) catch {
          _ => abort("recompile: bad \{key} in \{dir}/meta.txt")
        }
      "file" => {
        guard value.find(" ") is Some(space) else {
          abort("recompile: bad line in \{dir}/meta.txt: \{line}")
        }
        let number = value.unsafe_substring(start=0, end=space)
        let path = value.unsafe_substring(start=space + 1, end=value.length())
        let bytes = @fs.read_file_to_bytes("\{dir}/files/\{number}") catch {
          _ => abort("recompile: cannot read \{dir}/files/\{number}")
        }
        overlay.push((file_of_path(path), Some(bytes)))
      }
      "removed" => overlay.push((file_of_path(value), None))
      _ => abort("recompile: bad line in \{dir}/meta.txt: \{line}")
    }
  }
  guard documents.iter().find_first(d => d.name == name) is Some(document) else {
    abort("recompile: no document `\{name}` (\{dir}/meta.txt; --all?)")
  }
  let files = FileSet::new(document.base, [])
  for entry in overlay {
    files.overlay[entry.0] = entry.1
  }
  let variant : Variant = {
    main: file_of_path(main),
    inputs: numbers.get("inputs").unwrap_or(0),
    day: numbers.get("day").unwrap_or(0),
    fonts: numbers.get("fonts").unwrap_or(0),
  }
  let world = RecompileWorld::new(document.flavor, files, variant)
  let (compiled, _) = recompile_compile(world)
  for i, part in compiled_parts[:] {
    println("PART \{part} \{sha256_hex(@utf8.encode(compiled.parts[i])[:])}")
  }
  println("DIGEST \{compiled.digest()}")
}
