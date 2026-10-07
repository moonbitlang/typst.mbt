// Random sequences of edits on real documents: before every edit a snapshot
// of the source is taken (`snapshot` in `persistent_test.mbt`: kinds, texts,
// span numbers, error messages, and the hash of everything else), and after
// it the source and the nodes that were held must still give that snapshot.
// The documents are the projects of `tests/recompile/docs`, `bench/*.typ`
// and, where upstream's sources are checked out, every sixth file of its
// test suite.

///|
/// The path of the repository's root from the directory the tests run in.
fn repository_root() -> String? {
  for prefix in ["", "../", "../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
/// The `.typ` files below a directory, in the order of their paths.
fn typ_files(dir : String, out : Array[String]) -> Unit {
  let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
  // By length first: an order too, and the same on every platform.
  entries.sort()
  for entry in entries {
    let path = "\{dir}/\{entry}"
    let is_dir = @fs.is_dir(path) catch { _ => false }
    if is_dir {
      typ_files(path, out)
    } else if entry.has_suffix(".typ") {
      out.push(path)
    }
  }
}

///|
/// The splitmix64 generator.
priv struct EditRng {
  mut state : UInt64
}

///|
fn EditRng::next(self : EditRng) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// A number in `0..n` (`n > 0`).
fn EditRng::below(self : EditRng, n : Int) -> Int {
  (self.next() % n.to_uint64()).to_int()
}

///|
/// What is typed into a document, and what breaks one.
let property_snippets : Array[String] = [
  "a", "b c", " ", "\n", "\n\n", "\r\n", "#", "#x", "#{", "}", "#[", "[", "]", "{",
  "(", ")", "\"", "$", "*", "_", "=", "= ", "- ", "+ ", "/ a: ", "//", "/*", "*/",
  "`", "```", "\\", "<l>", "@r", ";", ",", "let", "#let x = 1", "1.5em", "ä", "😀",
  "~", ".", ":", "=>", "-", "'", "#f(", "x)", "[]", "#{}", "#[x]", "$ x $", "  ",
  "\t", "if", "else", "<", ">", "#let f(x) = { x }", "#let g = (a) => [#a]", "= Heading\n",
  "#import \"a.typ\": b\n", "**",
]

///|
/// A place between two characters of `text`, as an index into the string.
fn boundary(rng : EditRng, text : String) -> Int {
  let mut i = rng.below(text.length() + 1)
  // Not between the halves of a surrogate pair.
  if i > 0 && i < text.length() {
    let c = text.code_unit_at(i).to_int()
    if c >= 0xDC00 && c <= 0xDFFF {
      i -= 1
    }
  }
  i
}

///|
/// A random edit of `text`: the new text.
fn random_edit(rng : EditRng, text : String) -> String {
  let at = boundary(rng, text)
  let mut end = boundary(rng, text)
  if end < at || end > at + 40 {
    end = at
    let stop = at + rng.below(40)
    while end < stop && end < text.length() {
      end += 1
    }
    if end < text.length() {
      let c = text.code_unit_at(end).to_int()
      if c >= 0xDC00 && c <= 0xDFFF {
        end += 1
      }
    }
  }
  let before = text.unsafe_substring(start=0, end=at)
  let snippet = property_snippets[rng.below(property_snippets.length())]
  match rng.below(10) {
    // Something is typed.
    0 | 1 | 2 | 3 =>
      before + snippet + text.unsafe_substring(start=at, end=text.length())
    // Something is deleted.
    4 | 5 => before + text.unsafe_substring(start=end, end=text.length())
    // Something is replaced.
    6 | 7 =>
      before + snippet + text.unsafe_substring(start=end, end=text.length())
    // A stretch is there twice.
    8 =>
      before +
      text.unsafe_substring(start=at, end~) +
      text.unsafe_substring(start=at, end=text.length())
    // The rest of the line goes.
    _ => {
      let mut stop = at
      while stop < text.length() && text.code_unit_at(stop) != '\n' {
        stop += 1
      }
      before + text.unsafe_substring(start=stop, end=text.length())
    }
  }
}

///|
/// The edit that makes `new` of the text of `source`, through
/// [@syntax.Source::edit].
fn edit_to(source : @syntax.Source, new : String) -> @syntax.Source {
  guard source.lines().replacement_range(new) is Some((prefix, suffix)) else {
    return source
  }
  let replacement = @syntax.utf8_slice(
    new,
    prefix,
    @syntax.utf8_len(new) - suffix,
  )
  source.edit(prefix, source.lines().len_bytes() - suffix, replacement).0
}

///|
/// Runs `edits` edits on a document: random ones, or with `typing` words
/// that are inserted at one place, which uses up the span numbers there
/// until the nodes around it are renumbered. Returns how many of the edits
/// left the root's children as objects in the new tree (edits that were not
/// a parse of the whole text).
fn check_document(
  path : String,
  text : String,
  seed : UInt64,
  edits : Int,
  typing? : Bool = false,
) -> Int raise {
  let rng : EditRng = { state: seed, }
  let typed_at = boundary(rng, text)
  let mut source = @syntax.Source::detached(text)
  // Every source the document was, with its lines, their snapshot and the
  // hash of its tree.
  let history : Array[(@syntax.Source, @syntax.Lines, String, UInt64)] = []
  let mut incremental = 0
  for step in 0..<edits {
    let old_text = source.text()
    let before = snapshot(source.root())
    // Some nodes are held by themselves, as a closure holds its body.
    let nodes = all_nodes(source.root())
    let held = []
    for _ in 0..<12 {
      let node = nodes[rng.below(nodes.length())]
      held.push(Held::new(node.kind().name(), node))
    }
    let lines = source.lines()
    let lines_before = lines_snapshot(lines)
    history.push((source, lines, lines_before, tree_hash(source.root())))
    let new_text = if typing {
      let words = ["w ", "*b* ", "#x ", "_e_ ", "$x$ ", "[c] "]
      old_text.unsafe_substring(start=0, end=typed_at) +
      words[rng.below(words.length())] +
      old_text.unsafe_substring(start=typed_at, end=old_text.length())
    } else {
      random_edit(rng, old_text)
    }
    let edited = if rng.below(2) == 0 {
      source.replace(new_text).0
    } else {
      edit_to(source, new_text)
    }
    let place = "\{path}, seed \{seed}, edit \{step}"
    // The new source is the new text ..
    if edited.text() != new_text || edited.root().full_text() != new_text {
      fail("\{place}: the edited source is not the new text")
    }
    // .. numbered in the order of the tree ..
    let mut last = 0UL
    for node in all_nodes(edited.root()) {
      let number = node.span().number()
      if number <= last {
        fail("\{place}: span numbers are not in order")
      }
      last = number
    }
    // .. and the one before is what it was, with every node of it.
    if source.text() != old_text || snapshot(source.root()) != before {
      fail("\{place}: the source before the edit changed")
    }
    if !physical_equal(source.lines(), lines) ||
      lines_snapshot(lines) != lines_before {
      fail("\{place}: the lines of the source before the edit changed")
    }
    let changed = changed_names(held)
    if !changed.is_empty() {
      fail("\{place}: held nodes changed: \{changed.join(", ")}")
    }
    for i, entry in history {
      let (earlier, lines, lines_before, hash) = entry
      if !physical_equal(earlier.lines(), lines) ||
        lines_snapshot(lines) != lines_before ||
        earlier.text() != lines.text() ||
        tree_hash(earlier.root()) != hash {
        fail("\{place}: the source before edit \{i} changed")
      }
    }
    let old = source.root().children()
    let new = edited.root().children()
    if old.length() > 0 &&
      new.length() > 0 &&
      (
        physical_equal(old[0], new[0]) ||
        physical_equal(old[old.length() - 1], new[new.length() - 1])
      ) {
      incremental += 1
    }
    source = edited
  }
  incremental
}

///|
test "random edits leave every earlier source and its nodes as they were" {
  // The documents of this repository are required: a test that finds none
  // must not pass. (The tests run in the module's root.)
  guard repository_root() is Some(root) else {
    fail("the repository's files were not found from the working directory")
  }
  let documents = []
  typ_files(root + "tests/recompile/docs", documents)
  typ_files(root + "bench", documents)
  let own = documents.length()
  // Skipped where upstream's sources are not checked out.
  let suite = []
  typ_files(root + ".repos/typst/tests/suite", suite)
  for i, path in suite {
    if i % 6 == 0 {
      documents.push(path)
    }
  }
  let mut edits = 0
  let mut incremental = 0
  let mut checked = 0
  for i, path in documents {
    let text = @fs.read_file_to_string(path) catch { _ => continue }
    if text.length() > 60000 {
      continue
    }
    checked += 1
    for sequence in 0..<2 {
      let seed = 0x5EEDUL + i.to_uint64() * 1000 + sequence.to_uint64()
      incremental += check_document(path, text, seed, 12)
      edits += 12
    }
    if i < own {
      let seed = 0x7E57UL + i.to_uint64()
      incremental += check_document(path, text, seed, 48, typing=true)
      edits += 48
    }
  }
  println(
    "persistent edits: \{checked} documents (\{own} of this repository), \{edits} edits, \{incremental} of them not a parse of the whole text",
  )
  assert_true(own >= 10)
  assert_true(checked >= own)
  // Most edits are incremental: the test is about the trees that share
  // nodes.
  assert_true(incremental * 2 > edits)
}
