// Edits are persistent: `Source::edit` and `Source::replace` return a new
// source, and whoever holds the source before the edit, or a node of its
// tree, keeps what it held (upstream: `Arc::make_mut` in `Source::edit` and
// in the reparser). The rule is in the header of `node.mbt`.
//
// Every test here takes a snapshot of what it holds before an edit and
// compares it after. That the tree after the edit is the one upstream gives
// is the `reparse` stage's (`tests/runner/reparse_stage.mbt`, against
// `oracle/src/reparse.rs`).

///|
/// 64-bit FNV-1a over what upstream's derived `Hash for SyntaxNode` covers
/// ([@syntax.SyntaxNode::hash_into]): besides what [snapshot] prints, the
/// descendant counts, the diagnosis flags and the numbering bounds of the
/// inner nodes.
priv struct TreeHash {
  mut h : UInt64
}

///|
impl @syntax.NodeHasher for TreeHash with fn write_u64(self, v) {
  for i in 0..<8 {
    self.h = (self.h ^ ((v >> (8 * i)) & 0xFF)) * 0x100000001b3UL
  }
}

///|
impl @syntax.NodeHasher for TreeHash with fn write_str(self, s) {
  for i in 0..<s.length() {
    self.h = (self.h ^ s.code_unit_at(i).to_int().to_uint64()) * 0x100000001b3UL
  }
  @syntax.NodeHasher::write_u64(self, s.length().to_uint64())
}

///|
fn tree_hash(node : @syntax.SyntaxNode) -> UInt64 {
  let hash : TreeHash = { h: 0xcbf29ce484222325UL, }
  node.hash_into(hash)
  hash.h
}

///|
fn write_diagnostic(
  buf : StringBuilder,
  what : String,
  diag : @syntax.SyntaxDiagnostic,
) -> Unit {
  buf.write_string(
    "\{what} \{@unicode.rust_debug_str(diag.message)} at \{diag.span.span.0}+\{diag.span.extra}",
  )
  for hint in diag.hints {
    buf.write_string(
      " hint \{@unicode.rust_debug_str(hint.v)} at \{hint.span.span.0}+\{hint.span.extra}",
    )
  }
  buf.write_char('\n')
}

///|
/// Everything that can be read from a node and the nodes below it: a line
/// per node with its kind, length, span and, for a leaf, text; the errors and
/// warnings with their hints; the hash of the tree.
fn snapshot(node : @syntax.SyntaxNode) -> String {
  let buf = StringBuilder()
  fn go(node : @syntax.SyntaxNode, depth : Int) {
    for _ in 0..<depth {
      buf.write_string("  ")
    }
    buf.write_string(
      "\{node.kind().name()} #\{node.kind().index()} len=\{node.len()} span=\{node.span().0}",
    )
    if node.children().is_empty() {
      buf.write_string(" \{@unicode.rust_debug_str(node.leaf_text())}")
    }
    buf.write_char('\n')
    for child in node.children() {
      go(child, depth + 1)
    }
  }

  go(node, 0)
  let (errors, warnings) = node.errors_and_warnings()
  for diag in errors {
    write_diagnostic(buf, "error", diag)
  }
  for diag in warnings {
    write_diagnostic(buf, "warning", diag)
  }
  buf.write_string("hash \{tree_hash(node)}\n")
  buf.to_string()
}

///|
/// Everything that can be read from the lines of a source: the text, its
/// lengths, and the byte and UTF-16 start of every line.
fn lines_snapshot(lines : @syntax.Lines) -> String {
  let buf = StringBuilder()
  buf.write_string(
    "\{lines.len_bytes()} bytes, \{lines.len_utf16()} units, \{lines.len_lines()} lines:",
  )
  for line in 0..<lines.len_lines() {
    // `?`: line starts that are not places in the text any more.
    match lines.line_to_byte(line) {
      Some(byte) =>
        match lines.byte_to_utf16(byte) {
          Some(unit) => buf.write_string(" \{byte}/\{unit}")
          None => buf.write_string(" \{byte}/?")
        }
      None => buf.write_string(" ?")
    }
  }
  buf.write_char('\n')
  buf.write_string(lines.text())
  buf.to_string()
}

///|
/// The nodes of a tree, in pre-order.
fn all_nodes(root : @syntax.SyntaxNode) -> Array[@syntax.SyntaxNode] {
  let out = []
  fn go(node : @syntax.SyntaxNode) {
    out.push(node)
    for child in node.children() {
      go(child)
    }
  }

  go(root)
  out
}

///|
/// A node that somebody holds, with what it was when they took it.
priv struct Held {
  name : String
  node : @syntax.SyntaxNode
  before : String
}

///|
fn Held::new(name : String, node : @syntax.SyntaxNode) -> Held {
  { name, node, before: snapshot(node), }
}

///|
/// The names of the held nodes that are no longer what they were.
fn changed_names(held : Array[Held]) -> Array[String] {
  held.filter(h => snapshot(h.node) != h.before).map(h => h.name)
}

///|
/// Every node of a source, held by itself: the root, and each node below it
/// under a name that says what it is.
fn hold_all(source : @syntax.Source) -> Array[Held] {
  let nodes = all_nodes(source.root())
  nodes.mapi((i, node) => {
    let text = node.full_text()
    let short = if text.length() > 24 {
      text.unsafe_substring(start=0, end=24) + ".."
    } else {
      text
    }
    Held::new(
      "\{i} \{node.kind().name()} \{@unicode.rust_debug_str(short)}",
      node,
    )
  })
}

///|
/// The UTF-8 offset of the first occurrence of `needle`.
fn offset_of(text : String, needle : String) -> Int {
  guard text.find(needle) is Some(i) else { abort("no \{needle} in the text") }
  @syntax.utf8_len(text.unsafe_substring(start=0, end=i))
}

///|
/// A document with what a compilation holds nodes of: headings, two
/// closures (a code block and a content block as bodies), a warning and an
/// error.
let persistent_text : String =
  #|= First heading
  #|
  #|#let f(x) = { x + 1 }
  #|
  #|Some *text* and ** nothing, then #f(1).
  #|
  #|#let g = (a) => [body #a and more]
  #|
  #|== Second heading
  #|
  #|#let broken =
  #|
  #|Tail of the document.
  #|

///|
/// An edit of [persistent_text]: `find` is replaced by `with_`.
priv struct TextEdit {
  name : String
  find : String
  with_ : String
}

///|
let persistent_edits : Array[TextEdit] = [
  // Inside a held node: the body of a closure is reparsed as a block.
  { name: "in the code block of f", find: "x + 1", with_: "x + 20", },
  { name: "in the content block of g", find: "and more", with_: "or less", },
  // Markup at the top level: a range of the root's children is replaced.
  { name: "in the first heading", find: "First", with_: "1st", },
  { name: "in a paragraph", find: "Some", with_: "Any", },
  { name: "next to the error", find: "broken =", with_: "broken = 1", },
  { name: "at the end", find: "document.", with_: "document. More.", },
  // Changes how the whole file nests: everything is parsed anew.
  { name: "an opened comment", find: "= First", with_: "/* = First", },
  { name: "an opened block", find: "{ x + 1 }", with_: "{ x + 1 ", },
]

///|
test "an edit leaves the source and every node of its tree as they were" {
  for edit in persistent_edits {
    let source = @syntax.Source::detached(persistent_text)
    let held = hold_all(source)
    // The kinds that matter to a compilation are among them.
    for
      kind in [
        "heading", "closure", "code block", "content block", "syntax error",
      ] {
      assert_true(held.any(h => h.node.kind().name() == kind))
    }
    let lines = source.lines()
    let lines_before = lines_snapshot(lines)
    let start = offset_of(persistent_text, edit.find)
    let end = start + @syntax.utf8_len(edit.find)
    let (edited, _) = source.edit(start, end, edit.with_)
    let new_text = persistent_text.replace(old=edit.find, new=edit.with_)
    // The edit happened ..
    assert_eq(edited.text(), new_text)
    assert_true(edited.root().spanless_eq(@syntax.parse(new_text)))
    assert_eq(edited.root().full_text(), new_text)
    // .. in another source: the one that was edited has its text, its lines
    // and its nodes.
    assert_false(physical_equal(edited, source))
    assert_eq(source.text(), persistent_text)
    assert_true(physical_equal(source.lines(), lines))
    assert_eq(lines_snapshot(lines), lines_before)
    assert_eq(lines_before, lines_snapshot(@syntax.Lines::new(persistent_text)))
    let changed = changed_names(held)
    if !changed.is_empty() {
      fail("\{edit.name}: changed under their holder: \{changed.join(", ")}")
    }
    // The same through `replace`.
    let (replaced, _) = source.replace(new_text)
    assert_eq(snapshot(replaced.root()), snapshot(edited.root()))
    let changed = changed_names(held)
    if !changed.is_empty() {
      fail(
        "\{edit.name}, replace: changed under their holder: \{changed.join(", ")}",
      )
    }
  }
}

///|
/// The first node of a kind below `root`.
fn first_of(root : @syntax.SyntaxNode, kind : String) -> @syntax.SyntaxNode {
  for node in all_nodes(root) {
    if node.kind().name() == kind {
      return node
    }
  }
  abort("no \{kind}")
}

///|
test "an edit copies the path to it and shares the rest" {
  let source = @syntax.Source::detached(persistent_text)
  let start = offset_of(persistent_text, "x + 1")
  let (edited, _) = source.edit(start, start + 5, "x + 20")
  let old = source.root().children()
  let new = edited.root().children()
  assert_eq(old.length(), new.length())
  let mut copied = 0
  for i in 0..<old.length() {
    if !physical_equal(old[i], new[i]) {
      copied += 1
      // The one child that is not shared is the `let` with the closure.
      assert_true(old[i].full_text().contains("x + 1"))
      assert_true(new[i].full_text().contains("x + 20"))
      assert_eq(old[i].span(), new[i].span())
    }
  }
  assert_eq(copied, 1)
  assert_false(physical_equal(source.root(), edited.root()))
  assert_eq(source.root().span(), edited.root().span())
  // Below it, the closure is a copy with its span, its parameters are
  // shared, and its body is new.
  let old_closure = first_of(source.root(), "closure")
  let new_closure = first_of(edited.root(), "closure")
  assert_false(physical_equal(old_closure, new_closure))
  assert_eq(old_closure.span(), new_closure.span())
  assert_true(
    physical_equal(
      first_of(old_closure, "closure parameters"),
      first_of(new_closure, "closure parameters"),
    ),
  )
  let old_body = first_of(old_closure, "code block")
  let new_body = first_of(new_closure, "code block")
  inspect(old_body.full_text(), content="{ x + 1 }")
  inspect(new_body.full_text(), content="{ x + 20 }")
  // The other closure is the same object in both trees.
  let second = (root : @syntax.SyntaxNode) => {
    all_nodes(root).filter(n => n.kind().name() == "closure")[1]
  }
  assert_true(physical_equal(second(source.root()), second(edited.root())))
}

///|
/// The span numbers of a tree in pre-order, hashed.
fn span_hash(root : @syntax.SyntaxNode) -> UInt64 {
  let hash : TreeHash = { h: 0xcbf29ce484222325UL, }
  for node in all_nodes(root) {
    @syntax.NodeHasher::write_u64(hash, node.span().number())
  }
  hash.h
}

///|
test "neighbours that an edit renumbers are copies" {
  // Words are inserted at one place until the numbers between its
  // neighbours run out and `replace_children` renumbers the neighbours too:
  // those are nodes of the tree before the edit.
  let text = "#let f(x) = { x }\n\n_one_ _two_ _three_ _four_ _five_ _six_ _seven_ _eight_\n\n#let g = () => [tail]\n"
  let at = offset_of(text, "_five_")
  let mut source = @syntax.Source::detached(text)
  let mut renumbered = 0
  for i in 0..<120 {
    let held = hold_all(source)
    let (edited, _) = source.edit(at, at, "_w\{i}_ ")
    let changed = changed_names(held)
    if !changed.is_empty() {
      fail("insertion \{i}: changed under their holder: \{changed.join(", ")}")
    }
    // The root has two children more, the word and the space behind it.
    // The others are the old ones, unless they were renumbered: then they
    // are copies.
    let old = source.root().children()
    let new = edited.root().children()
    assert_eq(new.length(), old.length() + 2)
    let mut offset = 0
    for j in 0..<old.length() {
      let before = old[j]
      let after = if offset < at { new[j] } else { new[j + 2] }
      offset += before.len()
      assert_true(before.spanless_eq(after))
      if physical_equal(before, after) {
        continue
      }
      // A copy, down to the leaves.
      let copies = all_nodes(after)
      for n, node in all_nodes(before) {
        assert_false(physical_equal(node, copies[n]))
      }
      if before.span() != after.span() {
        renumbered += 1
      }
    }
    source = edited
  }
  // It happened: 72 neighbours got other numbers on the way.
  inspect(renumbered, content="72")
  assert_true(source.root().spanless_eq(@syntax.parse(source.text())))
  // The numbers of the last tree are those the reparser gave when it still
  // wrote them into the nodes it had (the value is from that
  // implementation, 68aea3a; the `reparse` stage, which compares numbers
  // with upstream's, does not edit one place often enough to get here).
  inspect(span_hash(source.root()), content="4720880715630792174")
}

///|
test "a source that is replaced by the same text is itself" {
  let source = @syntax.Source::detached(persistent_text)
  let (same, range) = source.replace(persistent_text)
  assert_true(physical_equal(same, source))
  assert_eq(range, (0, 0))
}

///|
test "what a source's spans point at is what they pointed at before an edit" {
  let source = @syntax.Source::detached(persistent_text)
  let body = first_of(source.root(), "code block")
  let heading = all_nodes(source.root()).filter(n => {
      n.kind().name() == "heading"
    })[1]
  let range_of = (source : @syntax.Source, node : @syntax.SyntaxNode) => {
    source.range(@syntax.SpanNumber(node.span().number()), None)
  }
  let body_range = range_of(source, body)
  let heading_range = range_of(source, heading)
  // Text is inserted before both, and the body is edited.
  let (edited, _) = source.edit(0, 0, "Intro.\n\n")
  let at = offset_of(edited.text(), "x + 1")
  let (edited, _) = edited.edit(at, at + 5, "x")
  // The old source resolves the old nodes as before ..
  assert_eq(range_of(source, body), body_range)
  assert_eq(range_of(source, heading), heading_range)
  assert_true(
    source.find(body.span()) is Some(found) && physical_equal(found.get(), body),
  )
  // .. and the new one has the heading four bytes further (eight were
  // inserted and four removed before it), and does not have the body that
  // was replaced.
  guard heading_range is Some((start, end)) else { fail("no range") }
  assert_eq(range_of(edited, heading), Some((start + 4, end + 4)))
  assert_false(
    edited.find(body.span()) is Some(found) && physical_equal(found.get(), body),
  )
}
