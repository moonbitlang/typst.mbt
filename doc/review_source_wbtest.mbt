// Tests of the reader of argument sources (`review_source.mbt`).

///|
/// The cells of a source text that starts at line 1, column 1.
fn cells_of(text : String) -> Array[Cell] {
  let cells : Array[Cell] = []
  let mut line = 1
  let mut col = 1
  for c in text {
    cells.push({ c, line, col, })
    if c == '\n' {
      line += 1
      col = 1
    } else {
      col += 1
    }
  }
  cells
}

///|
/// What `arg_shape` reads: for a literal its characters as
/// `c@line:col-end#at`, with `+holes` if something else is among them.
fn shape_of(text : String) -> String {
  match arg_shape(cells_of(text)) {
    Binding(name) => "binding \{name}"
    Expression => "expression"
    Literal(chars, holes~) =>
      chars.map(c => "\{c.c}@\{c.line}:\{c.col}-\{c.end}#\{c.at}").join(" ") +
      (if holes { " +holes" } else { "" })
  }
}

///|
test "reader: a string literal, with escapes and interpolations" {
  inspect(shape_of("\"ab c\""), content="a@1:2-3#0 b@1:3-4#1 c@1:5-6#2")
  // An escape is one character of the value and several columns of the
  // source; white space (also an escaped one) is no character.
  inspect(
    shape_of("\"a\\\"b\\n\\u{e9}\\\\\""),
    content="a@1:2-3#0 \"@1:3-5#1 b@1:5-6#2 é@1:8-14#3 \\@1:14-16#4",
  )
  inspect(shape_of("\"\\u00e9x\""), content="é@1:2-8#0 x@1:8-9#1")
  // An interpolation is no text of the literal: the numbers do not go on
  // across it. Its braces, strings and brackets are skipped.
  inspect(
    shape_of("\"a\\{f(\"}\", [1, 2])}b\""),
    content="a@1:2-3#0 b@1:20-21#2 +holes",
  )
  // Parentheses, white space and comments around the literal.
  inspect(shape_of("  ( \"x\" )  "), content="x@1:6-7#0")
  inspect(shape_of("// note\n\"x\""), content="x@2:2-3#0")
  // What this reader does not know is no literal.
  inspect(shape_of("\"a\\qb\""), content="expression")
  inspect(shape_of("\"open"), content="expression")
  inspect(shape_of("\"a\" + \"b\""), content="expression")
  inspect(shape_of("\"\""), content="")
  // Columns count code points: a character outside the basic plane is
  // one column.
  inspect(
    shape_of("\"a\u{1F600}b\""),
    content="a@1:2-3#0 😀@1:3-4#1 b@1:4-5#2",
  )
  // A comment behind the literal; a method call behind it is no literal.
  inspect(shape_of("\"x\" // why\n"), content="x@1:2-3#0")
  inspect(shape_of("\"x\" // why\n.f()"), content="expression")
  // Brackets are followed to a depth; beyond it nothing is read.
  inspect(
    shape_of("(".repeat(40) + "\"x\"" + ")".repeat(40)),
    content="x@1:42-43#0",
  )
  inspect(
    shape_of("(".repeat(5000) + "\"x\"" + ")".repeat(5000)),
    content="expression",
  )
  inspect(shape_of("[" + "(".repeat(5000) + "]"), content="expression")
}

///|
test "reader: multi-line strings" {
  let source =
    #|#|first line
    #|    #|second
  inspect(
    shape_of(source).replace_all(old=" ", new="\n"),
    content=(
      #|f@1:3-4#0
      #|i@1:4-5#1
      #|r@1:5-6#2
      #|s@1:6-7#3
      #|t@1:7-8#4
      #|l@1:9-10#5
      #|i@1:10-11#6
      #|n@1:11-12#7
      #|e@1:12-13#8
      #|s@2:7-8#10
      #|e@2:8-9#11
      #|c@2:9-10#12
      #|o@2:10-11#13
      #|n@2:11-12#14
      #|d@2:12-13#15
    ),
  )
  // A raw line keeps its backslashes; a `$|` line interpolates, and a
  // backslash that starts no interpolation is not read.
  inspect(shape_of("#|a\\n"), content="a@1:3-4#0 \\@1:4-5#1 n@1:5-6#2")
  inspect(shape_of("$|a\\{x}b"), content="a@1:3-4#0 b@1:8-9#2 +holes")
  inspect(shape_of("$|a\\nb"), content="expression")
  inspect(shape_of("( $|x\n)"), content="x@1:5-6#0")
}

///|
test "reader: arrays, bindings and expressions" {
  // The string elements of an array, in order; the numbers do not go on
  // from one element to the next. Another element is a hole.
  inspect(shape_of("[\"ab\", \"c\"]"), content="a@1:3-4#0 b@1:4-5#1 c@1:9-10#3")
  inspect(
    shape_of("[\"a\", Emph(\"x, y\"), name, \"b\",]"),
    content="a@1:3-4#0 b@1:28-29#4 +holes",
  )
  // A comment behind the last element.
  inspect(
    shape_of("[\n\"a\", // one\n\"b\" // two\n]"),
    content="a@2:2-3#0 b@3:2-3#2",
  )
  inspect(shape_of("[]"), content="")
  inspect(shape_of("[f(x), y]"), content=" +holes")
  inspect(shape_of("subtitle"), content="binding subtitle")
  inspect(shape_of("self.title"), content="binding self.title")
  inspect(shape_of("@pkg.name"), content="binding @pkg.name")
  inspect(shape_of("title()"), content="expression")
  inspect(shape_of("a + b"), content="expression")
  inspect(shape_of("\"a\".to_upper()"), content="expression")
  inspect(shape_of(""), content="expression")
  inspect(shape_of("[\"a\""), content="expression")
}
