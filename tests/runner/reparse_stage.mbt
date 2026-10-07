// The `reparse` stage: incremental reparsing through `Source::edit` and
// `Source::replace`, compared against `oracle/src/reparse.rs`, which applies
// the same seeded pseudo-random edits with the same generator.
//
// Per edit the report has the reparsed range, a hash of the tree's debug
// output, a hash of all span numbers in pre-order, the line starts, and
// whether the tree is what a parse of the text gives; at the end the tree
// and its diagnostics with their ranges. So the tree after every edit, with
// its numbers, is upstream's.
//
// Not in upstream's report: an edit must leave the source it was applied to
// as it was (`syntax/node.mbt`). The source before every edit is hashed
// with its text and its whole tree before and after, and a difference is a
// line of the report, which then differs from upstream's.

///|
/// Number of edits applied to every test body.
let reparse_edits : Int = 8

///|
/// Text that is inserted or replaces a range.
let reparse_snippets : Array[String] = [
  "a", "b c", " ", "\n", "\n\n", "\r\n", "#", "#x", "#{", "}", "#[", "[", "]", "{",
  "(", ")", "\"", "$", "*", "_", "=", "= ", "- ", "+ ", "/ a: ", "//", "/*", "*/",
  "`", "```", "\\", "<l>", "@r", ";", ",", "let", "#let x = 1", "1.5em", "ä", "😀",
  "~", ".", ":", "=>", "-", "'", "#f(", "x)", "[]", "#{}", "#[x]", "$ x $", "  ",
  "\t", "if", "else", "<", ">", "\\[", "http://x.y/", "1.", "\u{200b}",
]

///|
/// The splitmix64 generator.
priv struct Rng {
  mut state : UInt64
}

///|
fn Rng::next(self : Rng) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
/// A number in `0..n` (`n > 0`).
fn Rng::below(self : Rng, n : Int) -> Int {
  (self.next() % n.to_uint64()).to_int()
}

///|
/// 64-bit FNV-1a.
priv struct Fnv {
  mut h : UInt64
}

///|
fn Fnv::new() -> Fnv {
  { h: 0xcbf29ce484222325UL, }
}

///|
fn Fnv::write(self : Fnv, bytes : BytesView) -> Unit {
  for b in bytes {
    self.h = (self.h ^ b.to_uint64()) * 0x100000001b3UL
  }
}

///|
fn Fnv::write_u64(self : Fnv, v : UInt64) -> Unit {
  for i in 0..<8 {
    self.h = (self.h ^ ((v >> (8 * i)) & 0xffUL)) * 0x100000001b3UL
  }
}

///|
impl @syntax.NodeHasher for Fnv with fn write_u64(self, v) {
  self.write_u64(v)
}

///|
impl @syntax.NodeHasher for Fnv with fn write_str(self, s) {
  for i in 0..<s.length() {
    self.h = (self.h ^ s.code_unit_at(i).to_int().to_uint64()) * 0x100000001b3UL
  }
  self.write_u64(s.length().to_uint64())
}

///|
/// A hash of everything a holder of a source can read from it: the text and
/// what upstream's `Hash for SyntaxNode` covers of the tree (kinds, texts,
/// spans, lengths, descendants, diagnoses, numbering bounds, messages and
/// hints).
fn source_state(source : @syntax.Source) -> UInt64 {
  let hash = Fnv::new()
  @syntax.NodeHasher::write_str(hash, source.text())
  source.root().hash_into(hash)
  hash.h
}

///|
/// The closest position at or before `i` that is a char boundary of the
/// UTF-8 `text` and not between `\r` and `\n`.
fn floor_boundary(text : Bytes, i : Int) -> Int {
  let mut i = i
  while (i < text.length() && (text[i].to_int() & 0xC0) == 0x80) ||
        (i > 0 && i < text.length() && text[i - 1] == b'\r' && text[i] == b'\n') {
    i -= 1
  }
  i
}

///|
/// An edit: replace `start..end` with `with_`, through `Source::replace` if
/// `whole` and through `Source::edit` otherwise.
priv struct ReparseEdit {
  start : Int
  end : Int
  with_ : String
  whole : Bool
}

///|
fn next_edit(rng : Rng, text : Bytes) -> ReparseEdit {
  let len = text.length()
  let kind = rng.below(5)
  let start = floor_boundary(text, rng.below(len + 1))
  fn snippet() {
    reparse_snippets[rng.below(reparse_snippets.length())]
  }

  fn end() {
    floor_boundary(text, @cmp.minimum(start + 1 + rng.below(8), len))
  }

  match kind {
    // Insert a snippet.
    0 => { start, end: start, with_: snippet(), whole: false, }
    // Delete a short range.
    1 => { start, end: end(), with_: "", whole: false, }
    // Replace a short range with a snippet.
    2 => {
      let end = end()
      { start, end, with_: snippet(), whole: false, }
    }
    // Insert a copy of a piece of the text itself.
    3 => {
      let a = floor_boundary(text, rng.below(len + 1))
      let b = floor_boundary(text, @cmp.minimum(a + rng.below(17), len))
      let with_ = @utf8.decode(text[a:b]) catch { _ => abort("invalid UTF-8") }
      { start, end: start, with_, whole: false, }
    }
    // Replace a short range with a snippet, through `Source::replace`.
    _ => {
      let end = end()
      { start, end, with_: snippet(), whole: true, }
    }
  }
}

///|
/// Hash all span numbers of the tree in pre-order.
fn hash_spans(node : @syntax.SyntaxNode, h : Fnv) -> Unit {
  h.write_u64(node.span().number())
  for child in node.children() {
    hash_spans(child, h)
  }
}

///|
fn reparse_report(text : String) -> String {
  let buf = StringBuilder()
  let seed = Fnv::new()
  seed.write(@utf8.encode(text))
  let rng = { state: seed.h, }
  let mut source = @syntax.Source::detached(text)
  for i in 0..<reparse_edits {
    let bytes = @utf8.encode(source.text())
    let edit = next_edit(rng, bytes)
    let before = source_state(source)
    let (edited, (rs, re)) = if edit.whole {
      let old = source.text()
      let new = @syntax.utf8_slice(old, 0, edit.start) +
        edit.with_ +
        @syntax.utf8_slice(old, edit.end, bytes.length())
      source.replace(new)
    } else {
      source.edit(edit.start, edit.end, edit.with_)
    }
    if source_state(source) != before {
      buf.write_string("edit \{i}: the source before the edit changed\n")
    }
    source = edited
    let root = source.root()
    let tree = Fnv::new()
    tree.write(@utf8.encode(root.debug_tree()))
    let spans = Fnv::new()
    hash_spans(root, spans)
    let lines = source.lines()
    let line_hash = Fnv::new()
    for l in 0..<lines.len_lines() {
      let b = lines.line_to_byte(l).unwrap()
      line_hash.write_u64(b.to_uint64())
      line_hash.write_u64(lines.byte_to_utf16(b).unwrap().to_uint64())
    }
    let full = if root.spanless_eq(@syntax.parse(source.text())) {
      "same"
    } else {
      "differs"
    }
    let how = if edit.whole { "replace" } else { "edit" }
    buf.write_string(
      "edit \{i} \{how} \{edit.start}..\{edit.end} \{@unicode.rust_debug_str(edit.with_)} -> \{rs}..\{re} tree=\{hex16(tree.h)} spans=\{hex16(spans.h)} lines=\{lines.len_lines()}:\{hex16(line_hash.h)} full=\{full}\n",
    )
  }
  let root = source.root()
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
