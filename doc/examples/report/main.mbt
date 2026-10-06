// The report of this package in both versions.
//
//   moon run doc/examples/report --target native --release -- pdf <dir>
//     writes <dir>/before.pdf and <dir>/after.pdf
//   moon run doc/examples/report --target native --release -- time [runs]
//     compiles each version `runs` times (200) and prints the times
//
// What the measurement is (docs/edsl-ports.md, section 9):
// - helper lines: the lines of code of the top-level functions and
//   constants that have no text or data of the document. The files are
//   split by that rule, so `python3 scripts/edsl_helper_lines.py` counts
//   them: `shared.mbt`, `before_helpers.mbt` and `before.mbt` for the
//   version before, `shared.mbt` and `after.mbt` for the version after
//   (`content.mbt` is the document's text and data, this file the tool);
// - pages: `report_wbtest.mbt` compares the SVG of the two versions;
// - time: `time` below, building the description and compiling it.

///|
/// The two versions, by name.
fn versions() -> Array[(String, () -> Document)] {
  [("before", before), ("after", after)]
}

///|
fn write_pdfs(dir : String) -> Unit raise {
  let world = @doc.DocWorld::in_memory()
  for version in versions() {
    let (name, build) = version
    let compiled = build().compile_paged(world)
    for diagnostic in compiled.warnings {
      println(diagnostic.render())
    }
    let path = "\{dir}/\{name}.pdf"
    @system.write(path, compiled.pdf().unwrap())
    println("wrote \{path} (\{compiled.unwrap().pages().length()} pages)")
  }
}

///|
/// Build and compile each version `runs` times, in turns of ten: the mean
/// time of a run in the fastest turn and over all turns, in milliseconds
/// (the clock has milliseconds, so a turn is timed, not a run).
fn time(runs : Int) -> Unit raise {
  let world = @doc.DocWorld::in_memory()
  let turn = 10
  let turns = (runs + turn - 1) / turn
  let times : Array[Array[UInt64]] = versions().map(_ => [])
  // (One turn of each first: the fonts are parsed on first use.)
  for round in 0..<(turns + 1) {
    for i, version in versions() {
      let start = @env.now()
      for _ in 0..<turn {
        (version.1)().compile_paged(world).unwrap() |> ignore
      }
      if round > 0 {
        times[i].push(@env.now() - start)
      }
    }
  }
  let ms = (total : UInt64, count : Int) => {
    let hundredths = total.to_double() * 100.0 / count.to_double()
    let rounded = hundredths.round().to_int()
    "\{rounded / 100}.\{(rounded % 100).to_string().pad_start(2, '0')}"
  }
  for i, version in versions() {
    times[i].sort()
    let total = times[i].fold(init=0UL, (a, b) => a + b)
    println(
      "\{version.0}: \{ms(times[i][0], turn)} ms a run in the fastest turn, \{ms(total, turns * turn)} ms over \{turns * turn} runs",
    )
  }
}

///|
fn main {
  let args = @env.args()
  let run = () => {
    match args.get(1) {
      Some("pdf") => write_pdfs(args.get(2).unwrap_or("."))
      Some("time") => {
        let mut runs = 0
        for c in args.get(2).unwrap_or("200") {
          runs = runs * 10 + (c.to_int() - '0'.to_int())
        }
        time(runs)
      }
      _ => println("usage: report pdf <dir> | report time [runs]")
    }
  }
  run() catch {
    @doc.DocError(errors) =>
      for error in errors {
        println(error.render())
      }
    err => println("error: \{err}")
  }
}
