// What an edit of a source costs: `Source::edit` and `Source::replace` for a
// one-character edit at the start, in the middle and at the end of a
// source, beside a parse of the whole text.
//
//     moon run tests/edit_bench --target native --release
//     moon run tests/edit_bench --target native --release -- <scenario> <edits>
//
// Without arguments it prints the table. With arguments it runs one
// scenario (`<document>:<place>:<edit|replace|parse>`, e.g.
// `big:middle:replace`) for that many edits and prints nothing: the form
// for counting allocations with `scripts/alloc_sites.py` (the difference
// of two runs with different numbers of edits, divided by the difference
// of the numbers).
//
// The documents: `bench/longer.typ`, which is small as a source (its pages
// are computed), and a source of 1 MB made of
// `tests/recompile/docs/notes/main.typ` repeated: markup at the top level,
// so the root has a child for every word, which is the worst case for an
// edit that copies the nodes on its path.

///|
/// The id of the edited file.
fn bench_id() -> @syntax.FileId {
  let vpath = @syntax.VirtualPath::new("main.typ") catch {
    _ => abort("unreachable")
  }
  @syntax.RootedPath::new(Project, vpath).intern()
}

///|
/// The byte offset of the first ASCII letter at or after `from` that
/// follows a letter (the middle of a word), or of the last one before it.
fn letter_near(bytes : Bytes, from : Int) -> Int {
  let is_letter = (i : Int) => {
    i >= 0 &&
    i < bytes.length() &&
    (bytes[i] is (b'a'..=b'z') || bytes[i] is (b'A'..=b'Z'))
  }
  for i in from..<bytes.length() {
    if is_letter(i) && is_letter(i - 1) {
      return i
    }
  }
  for i = from - 1; i > 0; i = i - 1 {
    if is_letter(i) && is_letter(i - 1) {
      return i
    }
  }
  0
}

///|
/// A document and the places of its edits.
priv struct Doc {
  name : String
  text : String
  places : Array[(String, Int)]
}

///|
fn Doc::new(name : String, text : String) -> Doc {
  let bytes = @utf8.encode(text)
  let len = bytes.length()
  {
    name,
    text,
    places: [
      ("start", letter_near(bytes, 0)),
      ("middle", letter_near(bytes, len / 2)),
      ("end", letter_near(bytes, len)),
    ],
  }
}

///|
/// One edit at `at`: a letter is inserted (even `i`) or removed again.
fn edit_step(source : @syntax.Source, at : Int, i : Int) -> @syntax.Source {
  if i % 2 == 0 {
    source.edit(at, at, "x").0
  } else {
    source.edit(at, at + 1, "").0
  }
}

///|
/// The source after `edits` edits at `at`.
fn run_edit(doc : Doc, at : Int, edits : Int) -> @syntax.Source {
  let mut source = @syntax.Source::new(bench_id(), doc.text)
  for i in 0..<edits {
    source = edit_step(source, at, i)
  }
  source
}

///|
/// The text of `doc` with a letter inserted at `at`.
fn with_letter(doc : Doc, at : Int) -> String {
  @syntax.utf8_slice(doc.text, 0, at) +
  "x" +
  @syntax.utf8_slice(doc.text, at, @syntax.utf8_len(doc.text))
}

///|
/// The same through `Source::replace`, which finds the edit by comparing
/// the texts.
fn run_replace(doc : Doc, at : Int, edits : Int) -> @syntax.Source {
  let mut source = @syntax.Source::new(bench_id(), doc.text)
  let with_x = with_letter(doc, at)
  for i in 0..<edits {
    source = source.replace(if i % 2 == 0 { with_x } else { doc.text }).0
  }
  source
}

///|
fn run_parse(doc : Doc, times : Int) -> Int {
  let mut sum = 0
  for _ in 0..<times {
    sum += @syntax.Source::new(bench_id(), doc.text).root().len()
  }
  sum
}

///|
/// Microseconds per call of `f`, the least of five rounds.
fn micros(rounds : Int, f : () -> Unit) -> Double {
  let mut best = @double.infinity
  for _ in 0..<5 {
    let start = @bench.monotonic_clock_start()
    for _ in 0..<rounds {
      f()
    }
    let elapsed = @bench.monotonic_clock_end(start) / rounds.to_double()
    if elapsed < best {
      best = elapsed
    }
  }
  best
}

///|
fn fixed(v : Double) -> String {
  let scaled = (v * 10.0).round().to_int()
  "\{scaled / 10}.\{scaled % 10}"
}

///|
fn documents() -> Array[Doc] {
  let read = (path : String) => {
    @fs.read_file_to_string(path) catch {
      _ => abort("cannot read \{path} (run from the repository's root)")
    }
  }
  let unit = read("tests/recompile/docs/notes/main.typ")
  let big = StringBuilder()
  let mut len = 0
  let unit_len = @syntax.utf8_len(unit)
  while len < 1024 * 1024 {
    big.write_string(unit)
    len += unit_len
  }
  [
    Doc::new("longer", read("bench/longer.typ")),
    Doc::new("big", big.to_string()),
  ]
}

///|
fn main {
  let args = @env.args()
  let docs = documents()
  if args.length() >= 3 {
    let parts = args[1].split(":").map(p => p.to_owned()).collect()
    let edits = @string.parse_int(args[2]) catch { _ => abort("bad number") }
    guard docs.search_by(d => d.name == parts[0]) is Some(d) else {
      abort("no document \{parts[0]}")
    }
    let doc = docs[d]
    guard doc.places.search_by(p => p.0 == parts[1]) is Some(p) else {
      abort("no place \{parts[1]}")
    }
    let at = doc.places[p].1
    match parts[2] {
      "edit" => run_edit(doc, at, edits) |> ignore
      "replace" => run_replace(doc, at, edits) |> ignore
      _ => run_parse(doc, edits) |> ignore
    }
    return
  }
  for doc in docs {
    let bytes = @syntax.utf8_len(doc.text)
    let root = @syntax.Source::new(bench_id(), doc.text).root()
    println(
      "\{doc.name}: \{bytes} bytes, \{root.children().length()} children of the root",
    )
    let parse_rounds = if bytes > 100000 { 3 } else { 2000 }
    let parse = micros(parse_rounds, () => run_parse(doc, 1) |> ignore)
    println("  parse (Source::new): \{fixed(parse)} us")
    for place in doc.places {
      let (name, at) = place
      let edits = if bytes > 100000 { 200 } else { 20000 }
      let (_, range) = @syntax.Source::new(bench_id(), doc.text).edit(
        at, at, "x",
      )
      // The source is made outside of what is measured. The source before
      // an edit is dropped with it, as a world's file slot does.
      let edit = {
        let mut source = @syntax.Source::new(bench_id(), doc.text)
        let mut i = 0
        micros(edits, () => {
          source = edit_step(source, at, i)
          i += 1
        })
      }
      let replace = {
        let mut source = @syntax.Source::new(bench_id(), doc.text)
        let with_x = with_letter(doc, at)
        let mut i = 0
        micros(edits, () => {
          source = source.replace(if i % 2 == 0 { with_x } else { doc.text }).0
          i += 1
        })
      }
      println(
        "  \{name} (byte \{at}, reparsed \{range.0}..\{range.1}): edit \{fixed(edit)} us, replace \{fixed(replace)} us",
      )
    }
  }
}
