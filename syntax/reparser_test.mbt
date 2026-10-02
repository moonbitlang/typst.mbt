// Port of the unit tests in upstream `crates/typst-syntax/src/reparser.rs`.

///|
/// How to replace text in the test string.
priv enum Edit {
  /// Insert at the end.
  End
  /// Insert at an index.
  At(Int)
  /// Replace the given range.
  Range(Int, Int)
  /// Replace the first match in the original.
  Match(String)
  /// Replace at the index after the first match of this string.
  After(String)
}

///|
/// The byte index of the first match of `pat` in `text`.
fn find_bytes(text : String, pat : String) -> Int {
  match text.find(pat) {
    Some(i) => @syntax.utf8_len(text.unsafe_substring(start=0, end=i))
    None => abort("pattern must exist in original")
  }
}

///|
fn Edit::into_range(self : Edit, text : String) -> (Int, Int) {
  let len = @syntax.utf8_len(text)
  match self {
    End => (len, len)
    At(index) => {
      guard len >= index else { abort("index is out of bounds") }
      (index, index)
    }
    Range(start, end) => {
      guard len >= end else { abort("range is out of bounds") }
      (start, end)
    }
    Match(pat) => {
      let start = find_bytes(text, pat)
      (start, start + @syntax.utf8_len(pat))
    }
    After(pat) => {
      let end = find_bytes(text, pat) + @syntax.utf8_len(pat)
      (end, end)
    }
  }
}

///|
/// What kind of reparsing happened.
priv enum Reparse {
  /// The whole text was reparsed.
  All
  /// The text was parsed incrementally matching this string.
  Incr(String)
} derive(Eq)

///|
fn show_reparse(r : Reparse) -> String {
  match r {
    All => "All"
    Incr(s) => "Incr(\{@unicode.rust_debug_str(s)})"
  }
}

///|
fn check(
  text : String,
  edit : Edit,
  with_ : String,
  expected : Reparse,
) -> Unit {
  let source = @syntax.Source::detached(text)
  let orig_tree = source.root().deep_clone()
  // `Source::edit()` is the public interface for reparsing.
  let (start, end) = edit.into_range(text)
  let (rs, re) = source.edit(start, end, with_)
  let reparsed_tree = source.root().deep_clone()
  let normal_parse = @syntax.parse(source.text())
  reparsed_tree.synthesize(@syntax.Span::detached())
  normal_parse.synthesize(@syntax.Span::detached())
  if !reparsed_tree.spanless_eq(normal_parse) {
    println("Original source text: \{@unicode.rust_debug_str(text)}")
    println("Original tree:\n\{orig_tree.debug_tree()}")
    println("New source text: \{@unicode.rust_debug_str(source.text())}")
    println("Reparsed tree:\n\{reparsed_tree.debug_tree()}")
    println("Normal parse tree:\n\{normal_parse.debug_tree()}")
    abort("Reparsed tree did not match normal parse")
  }
  let actual = if rs == 0 && re == @syntax.utf8_len(source.text()) {
    All
  } else {
    Incr(@syntax.utf8_slice(source.text(), rs, re))
  }
  if actual != expected {
    abort(
      "reparse of \{@unicode.rust_debug_str(text)}: expected \{show_reparse(expected)}, got \{show_reparse(actual)}",
    )
  }
}

///|
/// Basic tests for the reparsing algorithm and the testing framework.
test "reparse basic" {
  // Replace everything with something else:
  check("some content", Match("some content"), "do it", All)
  check("some content", Range(0, 12), "", All)
  check("", At(0), "do it", All)
  check("", End, "do it", All)
  // Add something at the end:
  check("some content", After("some content"), " do it", All)
}

///|
/// Test incremental reparsing of markup expressions.
test "reparse markup" {
  // Tilde is useful because it always creates a distinct token, whereas
  // spaces may join with adjacent text as one token.
  check("abc~def~gh~", Range(5, 6), "+", Incr("abc~d+f~"))
  check("~~~~~~~", Range(3, 4), "A", Incr("~~~A~~"))
  check("abc~~", Match("b"), "", Incr("ac~"))
  // Newlines behave slightly differently to tildes:
  check("~b~c~d~e", At(0), "a", Incr("a~b"))
  check("a~b~c~d~", End, "e", Incr("~d~e"))
  check("\nb\nc\nd\ne", At(0), "a", Incr("a\nb\n"))
  check("a\nb\nc\nd\n", End, "e", Incr("c\nd\ne"))
  check("#var. hello", Match(" "), " ", All)
  check("#var;hello", Range(9, 10), "a", All)
  check("https:/world", After("/"), "/", All)
  check("hello  world", Match("world"), "walkers", All)
  check("a d e", Match(" d"), " b c d", All)
  check("~*~*~", At(2), "*", All)
  check("::1\n2. a\n3", After(" "), "4", Incr("1\n2. 4a\n"))
  check("* #{1+2} *", Match("2"), "3", Incr("{1+3}"))
  check("#{(0, 1, 2)}", Match("1"), "11pt", Incr("{(0, 11pt, 2)}"))
  check("\n= A heading", After("A"), "n evocative", All)
  check("#call() abc~d", After("()"), "[]", Incr("#call()[] abc"))
  check("a your thing a", Range(6, 7), "a", All)
  check("#grid(columns: (auto, 1fr, 40%))", Match("auto"), "4pt", All)
  check(
    "abc\n= a head\njoke",
    Match("\n"),
    "\nmore\n\n",
    Incr("abc\nmore\n\n= a head\n"),
  )
  check("#show f: a => b..", End, "c", All)
  check("#for", End, "//", All)
  check("a\n#let \nb", At(7), "i", Incr("#let i\nb"))
  check("#{{let x = z}; a = 1} b", At(7), "//", All)
  check("a ```typst hello```", Range(16, 17), "", All)
  check("a{b}c", At(1), "#", All)
  check("a#{b}c", Match("#"), "", All)
}

///|
/// Test incremental reparsing of code and content blocks.
test "reparse block" {
  check("Hello #{ x + 1 }!", Match("x"), "abc", Incr("{ abc + 1 }"))
  check("A#{}!", After("{"), "\"", All)
  check("#{ [= x] }!", After("="), "=", Incr("== x"))
  check("#[[]]", At(3), "\\", Incr("[[\\]]"))
  check("#[[ab]]", Match("b"), "\\", Incr("[[a\\]]"))
  check("#{}}", After("{"), "{", All)
  check("A: #[BC]", After("B"), "{", Incr("B{C"))
  check("A: #[BC]", After("B"), "#{", Incr("B#{C"))
  check("A: #[BC]", After("B"), "#{}", Incr("B#{}C"))
  check("#{\"ab\"}A", At(5), "c", Incr("{\"abc\"}"))
  check("#{\"ab\"}A", Range(5, 6), "c", All)
  check("a#[]b", After("["), "#{", Incr("[#{]"))
  check("a#{call(); abc}b", At(8), "[]", Incr("{call([]); abc}"))
  check("a #while x {\n g(x) \n}  b", After("{"), "//", Incr("{//\n g(x) \n}"))
  check("a#[]b", After("["), "[hey]", Incr("[[hey]]"))
}

///|
/// Test unclosed strings/blocks in embedded code.
test "reparse unclosed embedded" {
  check("#\"a\nb\nc", End, "\"", All)
  check("#return \"a\nb\nc", End, "\"", All)
  check("#import \"@preview/pkg", End, "\"", All)
  check("#import [a\nb\nc", End, "]", All)
  check("#import $a\nb\nc", End, "$", All)
  check("#set thing\"a\n", End, "\"", All)
  check("#let x = \"a\nb\nc", End, "\"", All)
  check("#let x = {\"a\nb\nc}", After("c"), "\"", Incr("{\"a\nb\nc\"}"))
  check("#if x {\"a\nb\nc", End, "\"", All)
  check("#if x \"a\nb\nc", End, "\"", All)
  check("#if x \"a\nb\nc", After("x "), "{}", All)
  check("#if x $a\nb\nc", End, "$", All)
  check("#for x in \"a\nb\nc", End, "\"", All)
  check("#for x \"a\nb\nc", After("x "), "in ", All)
}

///|
/// Non-ASCII text: byte offsets of the edit and the returned range must be
/// UTF-8 based although the parser works on UTF-16 indices.
test "reparse non-ascii" {
  check("ä~😀~b~c", After("b"), "x", Incr("😀~bx~c"))
  check("#{ \"😀\" + 1 }ü", Match("1"), "2", Incr("{ \"😀\" + 2 }"))
  check("😀 #[a]", After("a"), "é", Incr("[aé]"))
}

///|
/// `Source::replace`.
test "source replace" {
  let source = @syntax.Source::detached("abc~def~gh~")
  let (s, e) = source.replace("abc~d+f~gh~")
  inspect(@syntax.utf8_slice(source.text(), s, e), content="abc~d+f~")
  assert_eq(source.replace("abc~d+f~gh~"), (0, 0))
  inspect(source.lines().len_lines(), content="1")
  source.replace("abc\nd+f~gh~") |> ignore
  inspect(source.lines().len_lines(), content="2")
}
