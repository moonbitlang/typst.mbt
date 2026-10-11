// What a PDF export costs, and what the next one in the same process
// costs: a document is compiled and exported several times, as `typst
// watch` does after every edit, and each round prints its two times.
//
//     moon run tests/pdf_bench --target native --release -- <file.typ> [rounds] [--export-only] [--no-memo] [--fresh] [--out <prefix>]
//
// A round is a compilation and an export, followed by `@library.evict(10)`
// (the loop of `cli/watch.mbt`); with `--export-only` the document is
// compiled once and exported `rounds` times. `--no-memo` turns off what is
// kept (`set_layout_memo_enabled(false)`): every round is then a first
// one. `--fresh` drops what the process keeps between rounds
// (`@library.evict(0)`): every round is then a first compilation in a warm
// process. `--out` writes the file of each round to `<prefix>-<round>.pdf`.
// The last line says whether all rounds gave the same bytes.
//
// What is kept between exports is what `pdf/image.mbt` keeps of a raster
// image, its compressed samples; the document for it is the deck of
// `bench/mkdeck.py`. Peak memory is the caller's to measure
// (`/usr/bin/time -l`).
//
// The world is `doc/system`'s over the directory of the file, with the
// embedded fonts and without the system's, on a fixed date.

///|
/// Nanoseconds as milliseconds with one decimal.
fn millis(nanos : Int64) -> String {
  let tenths = (nanos + 50000L) / 100000L
  "\{tenths / 10L}.\{tenths % 10L}"
}

///|
fn run(args : Array[String]) -> Unit raise {
  let mut path : String? = None
  let mut rounds = 2
  let mut export_only = false
  let mut memo = true
  let mut fresh = false
  let mut out : String? = None
  let mut i = 1
  while i < args.length() {
    match args[i] {
      "--export-only" => export_only = true
      "--no-memo" => memo = false
      "--fresh" => fresh = true
      "--out" => {
        guard i + 1 < args.length() else { fail("--out <prefix>") }
        out = Some(args[i + 1])
        i += 1
      }
      arg =>
        if path is None {
          path = Some(arg)
        } else {
          rounds = @string.parse_int(arg)
        }
    }
    i += 1
  }
  guard path is Some(path) else {
    fail(
      "usage: pdf_bench <file.typ> [rounds] [--export-only] [--no-memo] [--fresh] [--out <prefix>]",
    )
  }
  let root = match @platform.parent(path) {
    Some(parent) => if parent == "" { "." } else { parent }
    None => "."
  }
  let text = @utf8.decode(@system.read(path))
  let world = @system.world(root~, system_fonts=false, today=(2026, 1, 1))
  @library.set_layout_memo_enabled(memo)
  let mut report = None
  let mut first : Bytes? = None
  let mut same = true
  for round in 1..<=rounds {
    let start = @platform.monotonic_nanos()
    let compiles = round == 1 || !export_only
    if compiles {
      report = Some(
        @doc.Document([@doc.Markup(text)]).compile_paged(world, lints=false),
      )
    }
    guard report is Some(document) else { fail("unreachable") }
    let compiled = @platform.monotonic_nanos()
    let pdf = document.pdf().unwrap()
    let exported = @platform.monotonic_nanos()
    @library.evict(if fresh { 0 } else { 10 })
    let compile_time = if compiles { millis(compiled - start) } else { "-" }
    println(
      "round \{round}: compile \{compile_time} ms, export \{millis(exported - compiled)} ms, \{pdf.length()} bytes",
    )
    match first {
      None => first = Some(pdf)
      Some(first) => if first != pdf { same = false }
    }
    if out is Some(prefix) {
      @system.write("\{prefix}-\{round}.pdf", pdf)
    }
  }
  println(if same { "all rounds: the same bytes" } else { "ROUNDS DIFFER" })
}

///|
fn main {
  run(@env.args()) catch {
    err => {
      println("error: \{err}")
      @platform.exit(1)
    }
  }
}
