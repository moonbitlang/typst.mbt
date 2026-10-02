///|
fn outline_tree_repr(nodes : Array[OutlineNode[String]]) -> String {
  let parts = nodes.map(node => {
    if node.children.is_empty() {
      node.entry
    } else {
      "\{node.entry}\{outline_tree_repr(node.children)}"
    }
  })
  "[" + parts.join(", ") + "]"
}

///|
fn outline_tree_of(flat : Array[(String, Int, Bool)]) -> String {
  let flat = flat.map(item => (item.0, NonZeroUSize(item.1.to_int64()), item.2))
  outline_tree_repr(OutlineNode::build_tree(flat))
}

///|
test "outline build_tree nests by level" {
  inspect(
    outline_tree_of([
      ("A", 1, true),
      ("B", 2, true),
      ("C", 2, true),
      ("D", 3, true),
      ("E", 1, true),
    ]),
    content="[A[B, C[D]], E]",
  )
}

///|
test "outline build_tree skips levels" {
  // A level-3 entry right below a level-1 entry becomes its child.
  inspect(
    outline_tree_of([("A", 1, true), ("B", 3, true), ("C", 2, true)]),
    content="[A[B, C]]",
  )
}

///|
test "outline build_tree with skipped ancestors" {
  // An included heading of level N, a skipped heading of level N, a skipped
  // heading of level N + 1, and then an included heading of level N + 2: the
  // last one takes the place of its topmost skipped ancestor.
  inspect(
    outline_tree_of([
      ("A", 1, true),
      ("B", 1, false),
      ("C", 2, false),
      ("D", 3, true),
      ("E", 4, true),
    ]),
    content="[A, D[E]]",
  )
}
