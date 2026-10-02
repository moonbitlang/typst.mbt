// Differential test runner: compares the MoonBit port against reference
// outputs dumped by the Rust oracle (see `scripts/goldens.sh`).
//
// Usage: moon run tests/runner -- <syntax|ast|eval|html|realize|paged> [filter] [--verbose]

///|
let suite_dir = ".repos/typst/tests/suite"

///|
let golden_dir = "tests/golden"

///|
fn main {
  let args = @env.args()
  let stage = args.get(1).unwrap_or("syntax")
  let verbose = args.contains("--verbose") || args.contains("-v")
  dump_actual.val = args.contains("--dump")
  let filter = args[2:].iter().find_first(a => !a.has_prefix("-"))
  match stage {
    "syntax" =>
      run_stage("syntax", (_, tc) => syntax_report(tc.body), filter, verbose)
    "ast" => run_stage("ast", (_, tc) => ast_report(tc.body), filter, verbose)
    "eval" => run_stage("eval", eval_report, filter, verbose)
    "realize" => run_stage("realize", realize_report, filter, verbose)
    // Like the oracle, only the tests that upstream compiles to a paged
    // document.
    "paged" =>
      run_stage(
        "paged",
        paged_report,
        filter,
        verbose,
        select=tc => is_paged(tc.attrs),
        skip_file=text => text.has_prefix("// SKIP"),
      )
    // Like the oracle, only tests that target HTML.
    "html" =>
      run_stage("html", html_report, filter, verbose, select=tc => {
        tc.attrs.split(" ").any(a => a == "html")
      })
    _ => {
      println("unknown stage: \{stage}")
      @sys.exit(2)
    }
  }
}

///|
fn run_stage(
  stage : String,
  report : (String, TestCase) -> String,
  filter : String?,
  verbose : Bool,
  select? : (TestCase) -> Bool = _ => true,
  skip_file? : (String) -> Bool = _ => false,
) -> Unit {
  let mut passed = 0
  let mut failed = 0
  let failures = []
  for file in typ_files(suite_dir) {
    let rel = file.unsafe_substring(
      start=suite_dir.length() + 1,
      end=file.length(),
    )
    let golden_path = golden_dir +
      "/\{stage}/" +
      rel.unsafe_substring(start=0, end=rel.length() - 4) +
      ".txt"
    let text = read(file)
    if skip_file(text) {
      continue
    }
    let golden = split_golden(read(golden_path))
    let dump = StringBuilder()
    for tc in split_tests(text) {
      if !select(tc) || (filter is Some(f) && !tc.name.contains(f)) {
        continue
      }
      let actual = report(rel, tc)
      dump.write_string("=== \{tc.name}\n\{actual}")
      let expected = golden.get(tc.name).unwrap_or("<missing golden>")
      if actual == expected {
        passed += 1
      } else {
        failed += 1
        failures.push((rel, tc.name, expected, actual))
      }
    }
    if dump_actual.val && dump.to_string() != "" {
      let out = "_build/actual/\{stage}/" +
        rel.unsafe_substring(start=0, end=rel.length() - 4) +
        ".txt"
      ensure_parent_dir(out)
      @fs.write_string_to_file(out, dump.to_string()) catch {
        _ => ()
      }
    }
  }
  for f in failures {
    let (rel, name, expected, actual) = f
    ignore(expected)
    println("FAIL \{rel} :: \{name}")
    if verbose {
      println(first_diff(expected, actual))
    }
  }
  println("\{stage}: \{passed} passed, \{failed} failed")
}

///|
/// The syntax tree followed by the diagnostics, in the oracle's format.
fn syntax_report(text : String) -> String {
  let source = @syntax.Source::detached(text)
  let root = source.root()
  let buf = StringBuilder()
  buf.write_string(root.debug_tree())
  buf.write_char('\n')
  let (errors, warnings) = root.errors_and_warnings()
  for diag in errors {
    write_diag(buf, source, diag)
  }
  for diag in warnings {
    write_diag(buf, source, diag)
  }
  buf.to_string()
}

///|
fn write_diag(
  buf : StringBuilder,
  source : @syntax.Source,
  diag : @syntax.SyntaxDiagnostic,
) -> Unit {
  let kind = if diag.is_error { "error" } else { "warning" }
  buf.write_string(
    "\{kind} \{range_of(source, diag.span)} \{@unicode.rust_debug_str(diag.message)}\n",
  )
  for hint in diag.hints {
    buf.write_string(
      "  hint \{range_of(source, hint.span)} \{@unicode.rust_debug_str(hint.v)}\n",
    )
  }
}

///|
fn range_of(source : @syntax.Source, span : @syntax.DiagSpan) -> String {
  match span.get() {
    Detached => "-"
    Number(num~, sub_range~, ..) =>
      match source.range(num, sub_range) {
        Some((s, e)) => "\{s}..\{e}"
        None => "?"
      }
    Range(start~, end~, ..) => "\{start}..\{end}"
  }
}

///|
/// Split a golden file into per-test sections.
fn split_golden(text : String) -> Map[String, String] {
  let out = {}
  let mut name : String? = None
  let buf = StringBuilder()
  for line in text.split("\n") {
    if line.has_prefix("=== ") {
      if name is Some(n) {
        out[n] = buf.to_string()
      }
      buf.reset()
      name = Some(line.to_string().unsafe_substring(start=4, end=line.length()))
    } else {
      buf.write_string(line.to_string())
      buf.write_char('\n')
    }
  }
  if name is Some(n) {
    // The file ends with a newline, so the last split piece is empty.
    let s = buf.to_string()
    out[n] = s.unsafe_substring(start=0, end=s.length() - 1)
  }
  out
}

///|
fn first_diff(expected : String, actual : String) -> String {
  let e = expected.split("\n").map(s => s.to_string()).collect()
  let a = actual.split("\n").map(s => s.to_string()).collect()
  let n = if e.length() < a.length() { e.length() } else { a.length() }
  for i in 0..<n {
    if e[i] != a[i] {
      let lo = if i > 3 { i - 3 } else { 0 }
      let buf = StringBuilder()
      for j in lo..<i {
        buf.write_string("    \{e[j]}\n")
      }
      buf.write_string("  - \{e[i]}\n  + \{a[i]}")
      return buf.to_string()
    }
  }
  "  (length differs: expected \{e.length()} lines, got \{a.length()})"
}

///|
fn read(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => ""
  }
}

///|
/// All `.typ` files below `dir`, sorted.
fn typ_files(dir : String) -> Array[String] {
  let out = []
  fn walk(dir : String) {
    let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_array()
    entries.sort()
    for entry in entries {
      let path = dir + "/" + entry
      let is_dir = @fs.is_dir(path) catch { _ => false }
      if is_dir {
        walk(path)
      } else if path.has_suffix(".typ") {
        out.push(path)
      }
    }
  }

  walk(dir)
  out.sort()
  out
}

///|
let dump_actual : Ref[Bool] = Ref::new(false)

///|
fn ensure_parent_dir(path : String) -> Unit {
  let parts = path.split("/").map(p => p.to_string()).collect()
  let mut dir = ""
  for i in 0..<(parts.length() - 1) {
    dir = if dir.is_empty() { parts[i] } else { dir + "/" + parts[i] }
    if !@fs.path_exists(dir) {
      @fs.create_dir(dir) catch {
        _ => ()
      }
    }
  }
}
