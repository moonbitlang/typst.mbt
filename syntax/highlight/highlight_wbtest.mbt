///|
fn highlight_tree(
  tags : Array[((Int, Int), Tag)],
  node : @syntax.LinkedNode,
) -> Unit {
  if highlight(node) is Some(tag) {
    tags.push((node.range(), tag))
  }
  for child in node.children() {
    highlight_tree(tags, child)
  }
}

///|
fn tags_of(text : String) -> String {
  let tags = []
  highlight_tree(tags, @syntax.LinkedNode::new(@syntax.parse(text)))
  tags.map(t => "\{t.0.0}..\{t.0.1} \{@debug.to_string(t.1)}").join(", ")
}

///|
test "highlighting" {
  inspect(tags_of("= *AB*"), content="0..6 Heading, 2..6 Strong")
  inspect(
    tags_of("#f(x + 1)"),
    content="0..1 Function, 1..2 Function, 2..3 Punctuation, 5..6 Operator, 7..8 Number, 8..9 Punctuation",
  )
  inspect(
    tags_of("#let f(x) = x"),
    content="0..1 Keyword, 1..4 Keyword, 5..6 Function, 6..7 Punctuation, 8..9 Punctuation, 10..11 Operator",
  )
}

///|
test "highlight_html" {
  inspect(
    highlight_html(@syntax.parse("#let x = \"<a>\"")),
    content=(
      #|<code><span class="typ-key">#</span><span class="typ-key">let</span> x <span class="typ-op">=</span> <span class="typ-str">&quot;&lt;a&gt;&quot;</span></code>
    ),
  )
}
