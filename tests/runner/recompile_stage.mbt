// The `recompile` stage: one world, compiled again after every edit, must
// give what a compilation from scratch of the same files gives.
// `tests/recompile/README.md` says why, what is covered and how it was
// shown to catch stale results.
//
//   recompile [filter] [--seed=N] [--rounds=N] [--sequences=N] [--steps=N]
//             [--all] [--only=NAME] [--list] [--names] [--edits] [--verbose]
//             [--times] [--trace] [--fresh]
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
//    (`recompile_compare.mbt`), with a snapshot of the files.
// 2. The references: for every step, a fresh world of the snapshot is
//    compiled, once as it is and once with memoization off
//    (`@library.set_layout_memo_enabled(false)`), each after
//    `@library.evict(1)` has dropped what the process keeps by content.
//    Each must give what the watch loop gave at that step.
//
// The phases are not interleaved on purpose. A cache that outlives a
// compilation may keep only the last one: with a fresh compilation between
// two steps of the loop it would never be asked for the step before, and
// the stage would pass without testing it. Nothing in phase 1 touches
// engine state but what the watch loop of the CLI does. (The sequences of a
// run do follow each other in one process, as the compilations of several
// worlds of one host do.)
//
// Sizes: by default every document runs the sweep and `default_sequences`
// random sequences of `default_steps` edits; the documents that take long
// (`recompile_heavy`, and those with packages) run a short sweep only.
// That is the CI run. `--sequences` and `--steps` size the random sequences
// of every document, `--rounds` repeats everything with that many seeds
// counting up from `--seed`, and `--all` adds `bench/longer` and every
// document of `tests/packages/docs`: soak runs
// (`scripts/recompile_soak.py`). A failure names the seed, the sequence
// and the step, and its files are written to `_build/recompile/`.
//
// An edit can make the compiler abort where upstream panics (a frame of
// infinite size, for one), and the runner with it: `--trace` prints every
// sequence and edit before it runs, and `--fresh` runs the same edits with
// a fresh world for every step and compares nothing, which tells whether
// the abort has anything to do with compiling again.

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
  /// Every step is compiled in a fresh world, and nothing is compared.
  fresh : Bool
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
/// The counts of a run.
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
/// The value of `--name=N`.
fn int_option(args : Array[String], name : String) -> Int? {
  let prefix = "--\{name}="
  for arg in args {
    if arg.has_prefix(prefix) {
      let value = arg.unsafe_substring(start=prefix.length(), end=arg.length())
      let n = @string.parse_int(value) catch {
        _ => abort("recompile: bad value of --\{name}: \{value}")
      }
      return Some(n)
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
    fresh: args.contains("--fresh"),
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
  // `--only=<name>`: the document of that name (a filter also selects the
  // documents whose names contain it).
  let mut only : String? = None
  for arg in args {
    if arg.has_prefix("--only=") {
      only = Some(arg.unsafe_substring(start=7, end=arg.length()))
    }
  }
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
              Sweep::new(if heavy { heavy_sweep_files } else { sweep_files }),
            )
          } else {
            Random(options.steps)
          }
          let name = if sequence < 0 { "sweep" } else { sequence.to_string() }
          match run_sequence(document, seed, name, rng, plan, stats, options) {
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
}

///|
/// Prints what the first compilation of a document gives (`--list`).
fn list_document(document : Document) -> Unit {
  let files = FileSet::new(document.base, document.files)
  let variant : Variant = { main: document.main, inputs: 0, day: 0, }
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
/// The kind of an edit: the first word of what it says it did.
fn edit_kind(edit : String) -> String {
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
/// compilation.
fn run_sequence(
  document : Document,
  seed : Int,
  name : String,
  rng : Rng,
  plan : Plan,
  stats : RecompileStats,
  options : RecompileOptions,
) -> String? {
  let files = FileSet::new(document.base, document.files)
  let variant : Variant = { main: document.main, inputs: 0, day: 0, }
  let project = Project::new(files, variant)
  stats.sequences += 1

  // The watch loop (`cli/watch.mbt`).
  let world = RecompileWorld::new(document.flavor, files, variant)
  let done : Array[RecompileStep] = []
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
    // Recompile.
    let (compiled, ids) = if options.fresh {
      let snapshot = world.snapshot()
      recompile_compile(
        RecompileWorld::new(document.flavor, snapshot.files, snapshot.variant),
      )
    } else {
      recompile_compile(world)
    }
    // Evict the cache.
    if step > 0 {
      @library.evict(10)
    }
    project.note(ids)
    stats.steps += 1
    stats.compilations += 1
    if !compiled.ok {
      stats.errors += 1
    }
    if done.last() is Some(before) {
      let changed = before.compiled.parts[2] != compiled.parts[2]
      if trace_tests.val {
        let status = if compiled.ok { "compiled" } else { "did not compile" }
        let pages = if changed { "other pages" } else { "the same pages" }
        println("TRACE     \{status}, \{pages}")
      }
      if changed {
        stats.changed += 1
      }
      if before.compiled.parts[0] != compiled.parts[0] {
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
    done.push({ edit, snapshot: world.snapshot(), compiled, })
  }

  if options.fresh {
    return None
  }

  // The references. Every step is compared; what differs is shown for the
  // first that does.
  let steps = done.length() - 1
  let mut failure : (Int, StringBuilder)? = None
  let also : Array[Int] = []
  for step, at in done {
    for memoized in [true, false] {
      @library.evict(1)
      @library.set_layout_memo_enabled(memoized)
      let fresh = RecompileWorld::new(
        document.flavor,
        at.snapshot.files,
        at.snapshot.variant,
      )
      let (expected, _) = recompile_compile(fresh)
      @library.set_layout_memo_enabled(true)
      stats.compilations += 1
      guard expected.difference(at.compiled) is Some((parts, detail)) else {
        continue
      }
      if failure is Some(_) {
        also.push(step)
        break
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
      failure = Some((step, out))
      break
    }
  }
  guard failure is Some((step, detail)) else { return None }
  let also = if also.is_empty() {
    ""
  } else {
    " (also at \{also.map(s => s.to_string()).join(", ")})"
  }
  Some(
    "FAIL \{document.name} :: seed=\{seed} sequence=\{name} step=\{step} of \{steps}\{also}: \{detail.to_string()}",
  )
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
  let write = (path : String, content : Bytes) => {
    let path = dir + "/" + path
    ensure_parent_dir(path)
    @fs.write_bytes_to_file(path, content) catch {
      _ => ()
    }
  }
  let edits = StringBuilder()
  for i in 0..<=step {
    let variant = done[i].snapshot.variant
    edits.write_string(
      "step \{i}: \{done[i].edit} (main \{file_path(variant.main)}, inputs \{variant.inputs}, day \{variant.day})\n",
    )
  }
  write("edits.txt", @utf8.encode(edits.to_string()))
  let index = compiled_parts[:].search(part).unwrap_or(0)
  let name = part.replace_all(old=" ", new="-")
  if part == "pdf" {
    write("expected.pdf", expected.pdf)
    write("actual.pdf", actual.pdf)
  } else {
    write("expected-\{name}.txt", @utf8.encode(expected.parts[index]))
    write("actual-\{name}.txt", @utf8.encode(actual.parts[index]))
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
        Some(bytes) => write("step\{i}/\{path}", bytes)
        None => write("step\{i}/\{path}.removed", b"")
      }
    }
  }
}
