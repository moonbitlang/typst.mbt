// Port of the unit tests of `fancy-regex` 0.16.2 `src/parse.rs`.

///|
fn p(s : String) -> Expr raise FancyError {
  Expr::parse_tree(s).expr
}

///|
fn fail_parse(s : String) -> Unit raise {
  let ok = try Expr::parse_tree(s) catch {
    _ => false
  } noraise {
    _ => true
  }
  if ok {
    fail("Expected parse error, but was ok: \{s}")
  }
}

///|
fn parse_is_err(s : String) -> Bool {
  try Expr::parse_tree(s) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
fn assert_error(re : String, expected_error : String) -> Unit raise {
  try Expr::parse_tree(re) catch {
    e => assert_eq(e.to_string(), expected_error)
  } noraise {
    _ => fail("Expected parse error: \{re}")
  }
}

///|
fn parse_id_str(
  s : String,
  open : String,
  close : String,
  allow_relative : Bool,
) -> ParsedId? {
  parse_id(@utf8.encode(s), 0, open, close, allow_relative)
}

///|
fn create_id(id : String, relative : Int?, skip : Int) -> ParsedId? {
  Some({ id, relative, skip, })
}

///|
fn get_options(
  pattern : String,
  case_insensitive~ : Bool = false,
  multi_line~ : Bool = false,
  dot_matches_new_line~ : Bool = false,
) -> RegexOptions {
  let options = RegexOptions::default()
  options.syntaxc = {
    ..options.syntaxc,
    case_insensitive,
    multi_line,
    dot_matches_new_line,
  }
  options.pattern = pattern
  options
}

///|
test "empty" {
  assert_eq(p(""), Expr::Empty)
}

///|
test "any" {
  assert_eq(p("."), Expr::Any(newline=false))
  assert_eq(p("(?s:.)"), Expr::Any(newline=true))
}

///|
test "start_text" {
  assert_eq(p("^"), Expr::Assertion(Assertion::StartText))
}

///|
test "end_text" {
  assert_eq(p("$"), Expr::Assertion(Assertion::EndText))
}

///|
test "end_text_before_empty_lines" {
  assert_eq(
    p("\\Z"),
    Expr::LookAround(
      Expr::Delegate(inner="\\n*$", size=0, casei=false),
      LookAhead,
    ),
  )
}

///|
test "literal" {
  assert_eq(p("a"), make_literal("a"))
}

///|
test "literal_special" {
  assert_eq(p("}"), make_literal("}"))
  assert_eq(p("]"), make_literal("]"))
}

///|
test "parse_id_test" {
  assert_eq(parse_id_str("foo.", "", "", true), create_id("foo", None, 3))
  assert_eq(parse_id_str("1.", "", "", true), create_id("1", None, 1))
  assert_eq(parse_id_str("{foo}", "{", "}", true), create_id("foo", None, 5))
  assert_eq(parse_id_str("{foo.", "{", "}", true), None)
  assert_eq(parse_id_str("{foo", "{", "}", true), None)
  assert_eq(parse_id_str("{}", "{", "}", true), None)
  assert_eq(parse_id_str("", "", "", true), None)
  assert_eq(parse_id_str("{-1}", "{", "}", true), create_id("", Some(-1), 4))
  assert_eq(parse_id_str("{-1}", "{", "}", false), None)
  assert_eq(parse_id_str("{-a}", "{", "}", true), None)
  assert_eq(parse_id_str("{-a}", "{", "}", false), None)
  assert_eq(parse_id_str("{+a}", "{", "}", false), None)
  assert_eq(parse_id_str("+a", "", "", false), None)
  assert_eq(parse_id_str("-a", "", "", false), None)
  assert_eq(parse_id_str("2+a", "", "", false), create_id("2", None, 1))
  assert_eq(parse_id_str("2-a", "", "", false), create_id("2", None, 1))

  assert_eq(parse_id_str("<+1>", "<", ">", true), create_id("", Some(1), 4))
  assert_eq(parse_id_str("<-3>", "<", ">", true), create_id("", Some(-3), 4))
  assert_eq(parse_id_str("<n+1>", "<", ">", true), create_id("n", Some(1), 5))
  assert_eq(parse_id_str("<n-1>", "<", ">", true), create_id("n", Some(-1), 5))
  assert_eq(parse_id_str("<>", "<", ">", true), None)
  assert_eq(parse_id_str("<", "<", ">", true), None)
  assert_eq(parse_id_str("<+0>", "<", ">", true), None)
  assert_eq(parse_id_str("<-0>", "<", ">", true), None)
  assert_eq(parse_id_str("<n+0>", "<", ">", true), create_id("n", Some(0), 5))
  assert_eq(parse_id_str("<n-0>", "<", ">", true), create_id("n", Some(0), 5))
  assert_eq(parse_id_str("<2-0>", "<", ">", true), create_id("2", Some(0), 5))
  assert_eq(parse_id_str("<2+0>", "<", ">", true), create_id("2", Some(0), 5))
  assert_eq(parse_id_str("<2+1>", "<", ">", true), create_id("2", Some(1), 5))
  assert_eq(parse_id_str("<2-1>", "<", ">", true), create_id("2", Some(-1), 5))
}

///|
test "literal_unescaped_opening_curly" {
  // `{` in position where quantifier is not allowed results in literal `{`
  assert_eq(p("{"), make_literal("{"))
  assert_eq(p("({)"), Expr::Group(make_literal("{")))
  assert_eq(p("a|{"), Expr::Alt([make_literal("a"), make_literal("{")]))
  assert_eq(
    p("{{2}"),
    Expr::Repeat(child=make_literal("{"), lo=2, hi=2, greedy=true),
  )
}

///|
test "literal_escape" {
  assert_eq(p("\\'"), make_literal("'"))
  assert_eq(p("\\\""), make_literal("\""))
  assert_eq(p("\\ "), make_literal(" "))
  assert_eq(p("\\xA0"), make_literal(" "))
  assert_eq(p("\\x{1F4A9}"), make_literal("💩"))
  assert_eq(p("\\x{000000B7}"), make_literal("·"))
  assert_eq(p("\\u21D2"), make_literal("⇒"))
  assert_eq(p("\\u{21D2}"), make_literal("⇒"))
  assert_eq(p("\\u21D2x"), p("⇒x"))
  assert_eq(p("\\U0001F60A"), make_literal("😊"))
  assert_eq(p("\\U{0001F60A}"), make_literal("😊"))
}

///|
test "hex_escape" {
  assert_eq(p("\\h"), Expr::Delegate(inner="[0-9A-Fa-f]", size=1, casei=false))
  assert_eq(p("\\H"), Expr::Delegate(inner="[^0-9A-Fa-f]", size=1, casei=false))
}

///|
test "invalid_escape" {
  assert_error(
    "\\", "Parsing error at position 0: Backslash without following character",
  )
  assert_error("\\q", "Parsing error at position 0: Invalid escape: \\q")
  assert_error("\\xAG", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\xA", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\x{}", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\x{AG}", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\x{42", "Parsing error at position 2: Invalid hex escape")
  assert_error(
    "\\x{D800}", "Parsing error at position 2: Invalid codepoint for hex or unicode escape",
  )
  assert_error(
    "\\x{110000}", "Parsing error at position 2: Invalid codepoint for hex or unicode escape",
  )
  assert_error("\\u123", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\u123x", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\u{}", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\U1234567", "Parsing error at position 2: Invalid hex escape")
  assert_error("\\U{}", "Parsing error at position 2: Invalid hex escape")
}

///|
test "concat" {
  assert_eq(p("ab"), Expr::Concat([make_literal("a"), make_literal("b")]))
}

///|
test "alt" {
  assert_eq(p("a|b"), Expr::Alt([make_literal("a"), make_literal("b")]))
}

///|
test "group" {
  assert_eq(p("(a)"), Expr::Group(make_literal("a")))
}

///|
test "named_group" {
  assert_eq(p("(?'name'a)"), Expr::Group(make_literal("a")))
  assert_eq(p("(?<name>a)"), Expr::Group(make_literal("a")))
}

///|
test "group_repeat" {
  assert_eq(
    p("(a){2}"),
    Expr::Repeat(child=Expr::Group(make_literal("a")), lo=2, hi=2, greedy=true),
  )
}

///|
test "repeat" {
  assert_eq(
    p("a{2,42}"),
    Expr::Repeat(child=make_literal("a"), lo=2, hi=42, greedy=true),
  )
  assert_eq(
    p("a{2,}"),
    Expr::Repeat(child=make_literal("a"), lo=2, hi=USIZE_MAX, greedy=true),
  )
  assert_eq(
    p("a{2}"),
    Expr::Repeat(child=make_literal("a"), lo=2, hi=2, greedy=true),
  )
  assert_eq(
    p("a{,2}"),
    Expr::Repeat(child=make_literal("a"), lo=0, hi=2, greedy=true),
  )

  assert_eq(
    p("a{2,42}?"),
    Expr::Repeat(child=make_literal("a"), lo=2, hi=42, greedy=false),
  )
  assert_eq(
    p("a{2,}?"),
    Expr::Repeat(child=make_literal("a"), lo=2, hi=USIZE_MAX, greedy=false),
  )
  assert_eq(
    p("a{2}?"),
    Expr::Repeat(child=make_literal("a"), lo=2, hi=2, greedy=false),
  )
  assert_eq(
    p("a{,2}?"),
    Expr::Repeat(child=make_literal("a"), lo=0, hi=2, greedy=false),
  )
}

///|
test "invalid_repeat" {
  // Invalid repeat syntax results in literal
  assert_eq(p("a{"), Expr::Concat([make_literal("a"), make_literal("{")]))
  assert_eq(
    p("a{6"),
    Expr::Concat([make_literal("a"), make_literal("{"), make_literal("6")]),
  )
  assert_eq(
    p("a{6,"),
    Expr::Concat([
      make_literal("a"),
      make_literal("{"),
      make_literal("6"),
      make_literal(","),
    ]),
  )
  assert_eq(
    p("a{1,A}"),
    Expr::Concat([
      make_literal("a"),
      make_literal("{"),
      make_literal("1"),
      make_literal(","),
      make_literal("A"),
      make_literal("}"),
    ]),
  )
  assert_eq(
    p("a{1,2A}"),
    Expr::Concat([
      make_literal("a"),
      make_literal("{"),
      make_literal("1"),
      make_literal(","),
      make_literal("2"),
      make_literal("A"),
      make_literal("}"),
    ]),
  )
}

///|
test "delegate_zero" {
  assert_eq(p("\\b"), Expr::Assertion(Assertion::WordBoundary))
  assert_eq(p("\\B"), Expr::Assertion(Assertion::NotWordBoundary))
}

///|
test "delegate_named_group" {
  assert_eq(
    p("\\p{Greek}"),
    Expr::Delegate(inner="\\p{Greek}", size=1, casei=false),
  )
  assert_eq(p("\\pL"), Expr::Delegate(inner="\\pL", size=1, casei=false))
  assert_eq(
    p("\\P{Greek}"),
    Expr::Delegate(inner="\\P{Greek}", size=1, casei=false),
  )
  assert_eq(p("\\PL"), Expr::Delegate(inner="\\PL", size=1, casei=false))
  assert_eq(
    p("(?i)\\p{Ll}"),
    Expr::Delegate(inner="\\p{Ll}", size=1, casei=true),
  )
}

///|
test "backref" {
  assert_eq(
    p("(.)\\1"),
    Expr::Concat([
      Expr::Group(Expr::Any(newline=false)),
      Expr::Backref(group=1, casei=false),
    ]),
  )
}

///|
test "named_backref" {
  assert_eq(
    p("(?<i>.)\\k<i>"),
    Expr::Concat([
      Expr::Group(Expr::Any(newline=false)),
      Expr::Backref(group=1, casei=false),
    ]),
  )
}

///|
test "relative_backref" {
  assert_eq(
    p("(a)(.)\\k<-1>"),
    Expr::Concat([
      Expr::Group(make_literal("a")),
      Expr::Group(Expr::Any(newline=false)),
      Expr::Backref(group=2, casei=false),
    ]),
  )

  assert_eq(
    p("(a)\\k<+1>(.)"),
    Expr::Concat([
      Expr::Group(make_literal("a")),
      Expr::Backref(group=2, casei=false),
      Expr::Group(Expr::Any(newline=false)),
    ]),
  )

  fail_parse("(?P<->.)")
  fail_parse("(.)(?P=-)")
  fail_parse("(a)\\k<-0>(.)")
  fail_parse("(a)\\k<+0>(.)")
  fail_parse("(a)\\k<+>(.)")
  fail_parse("(a)\\k<->(.)")
  fail_parse("(a)\\k<>(.)")
}

///|
test "relative_backref_with_recursion_level" {
  assert_eq(
    p("()\\k<1+3>"),
    Expr::Concat([
      Expr::Group(Expr::Empty),
      Expr::BackrefWithRelativeRecursionLevel(
        group=1,
        relative_level=3,
        casei=false,
      ),
    ]),
  )

  assert_eq(
    p("()\\k<1-0>"),
    Expr::Concat([
      Expr::Group(Expr::Empty),
      Expr::BackrefWithRelativeRecursionLevel(
        group=1,
        relative_level=0,
        casei=false,
      ),
    ]),
  )

  assert_eq(
    p("(?<n>)\\k<n+3>"),
    Expr::Concat([
      Expr::Group(Expr::Empty),
      Expr::BackrefWithRelativeRecursionLevel(
        group=1,
        relative_level=3,
        casei=false,
      ),
    ]),
  )

  assert_eq(
    p("(?<n>)\\k<n-3>"),
    Expr::Concat([
      Expr::Group(Expr::Empty),
      Expr::BackrefWithRelativeRecursionLevel(
        group=1,
        relative_level=-3,
        casei=false,
      ),
    ]),
  )

  assert_eq(
    p("\\A(?<a>|.|(?:(?<b>.)\\g<a>\\k<b+0>))\\z"),
    Expr::Concat([
      Expr::Assertion(Assertion::StartText),
      Expr::Group(
        Expr::Alt([
          Expr::Empty,
          Expr::Any(newline=false),
          Expr::Concat([
            Expr::Group(Expr::Any(newline=false)),
            Expr::SubroutineCall(1),
            Expr::BackrefWithRelativeRecursionLevel(
              group=2,
              relative_level=0,
              casei=false,
            ),
          ]),
        ]),
      ),
      Expr::Assertion(Assertion::EndText),
    ]),
  )
}

///|
test "relative_subroutine_call" {
  assert_eq(
    p("(a)(.)\\g<-1>"),
    Expr::Concat([
      Expr::Group(make_literal("a")),
      Expr::Group(Expr::Any(newline=false)),
      Expr::SubroutineCall(2),
    ]),
  )

  assert_eq(
    p("(a)\\g<+1>(.)"),
    Expr::Concat([
      Expr::Group(make_literal("a")),
      Expr::SubroutineCall(2),
      Expr::Group(Expr::Any(newline=false)),
    ]),
  )

  fail_parse("(a)\\g<-0>(.)")
  fail_parse("(a)\\g<+0>(.)")
  fail_parse("(a)\\g<+>(.)")
  fail_parse("(a)\\g<->(.)")
  fail_parse("(a)\\g<>(.)")
}

///|
test "lookaround" {
  assert_eq(p("(?=a)"), Expr::LookAround(make_literal("a"), LookAhead))
  assert_eq(p("(?!a)"), Expr::LookAround(make_literal("a"), LookAheadNeg))
  assert_eq(p("(?<=a)"), Expr::LookAround(make_literal("a"), LookBehind))
  assert_eq(p("(?<!a)"), Expr::LookAround(make_literal("a"), LookBehindNeg))
}

///|
test "shy_group" {
  assert_eq(
    p("(?:ab)c"),
    Expr::Concat([
      Expr::Concat([make_literal("a"), make_literal("b")]),
      make_literal("c"),
    ]),
  )
}

///|
test "flag_state" {
  assert_eq(p("(?s)."), Expr::Any(newline=true))
  assert_eq(p("(?s:(?-s:.))"), Expr::Any(newline=false))
  assert_eq(
    p("(?s:.)."),
    Expr::Concat([Expr::Any(newline=true), Expr::Any(newline=false)]),
  )
  assert_eq(
    p("(?:(?s).)."),
    Expr::Concat([Expr::Any(newline=true), Expr::Any(newline=false)]),
  )
}

///|
test "flag_multiline" {
  assert_eq(p("^"), Expr::Assertion(Assertion::StartText))
  assert_eq(p("(?m:^)"), Expr::Assertion(Assertion::StartLine(crlf=false)))
  assert_eq(p("$"), Expr::Assertion(Assertion::EndText))
  assert_eq(p("(?m:$)"), Expr::Assertion(Assertion::EndLine(crlf=false)))
}

///|
test "flag_swap_greed" {
  assert_eq(p("a*"), p("(?U:a*?)"))
  assert_eq(p("a*?"), p("(?U:a*)"))
}

///|
test "invalid_flags" {
  assert_true(parse_is_err("(?"))
  assert_true(parse_is_err("(?)"))
  assert_true(parse_is_err("(?-)"))
  assert_true(parse_is_err("(?-:a)"))
  assert_true(parse_is_err("(?q:a)"))
}

///|
test "lifetime" {
  assert_eq(
    p("\\'[a-zA-Z_][a-zA-Z0-9_]*(?!\\')\\b"),
    Expr::Concat([
      make_literal("'"),
      Expr::Delegate(inner="[a-zA-Z_]", size=1, casei=false),
      Expr::Repeat(
        child=Expr::Delegate(inner="[a-zA-Z0-9_]", size=1, casei=false),
        lo=0,
        hi=USIZE_MAX,
        greedy=true,
      ),
      Expr::LookAround(make_literal("'"), LookAheadNeg),
      Expr::Assertion(Assertion::WordBoundary),
    ]),
  )
}

///|
test "ignore_whitespace" {
  assert_eq(p("(?x: )"), p(""))
  assert_eq(p("(?x) | "), p("|"))
  assert_eq(p("(?x: a )"), p("a"))
  assert_eq(p("(?x: a # ) bobby tables\n b )"), p("ab"))
  assert_eq(p("(?x: a | b )"), p("a|b"))
  assert_eq(p("(?x: ( a b ) )"), p("(ab)"))
  assert_eq(p("(?x: a + )"), p("a+"))
  assert_eq(p("(?x: a {2} )"), p("a{2}"))
  assert_eq(p("(?x: a { 2 } )"), p("a{2}"))
  assert_eq(p("(?x: a { 2 , } )"), p("a{2,}"))
  assert_eq(p("(?x: a { , 2 } )"), p("a{,2}"))
  assert_eq(p("(?x: a { 2 , 3 } )"), p("a{2,3}"))
  assert_eq(p("(?x: a { 2 , 3 } ? )"), p("a{2,3}?"))
  assert_eq(p("(?x: ( ? i : . ) )"), p("(?i:.)"))
  assert_eq(p("(?x: ( ?= a ) )"), p("(?=a)"))
  assert_eq(p("(?x: [ ] )"), p("[ ]"))
  assert_eq(p("(?x: [ ^] )"), p("[ ^]"))
  assert_eq(p("(?x: [a - z] )"), p("[a - z]"))
  assert_eq(p("(?x: [ \\] \\\\] )"), p("[ \\] \\\\]"))
  assert_eq(p("(?x: a\\ b )"), p("a b"))
  assert_eq(p("(?x: a (?-x:#) b )"), p("a#b"))
}

///|
test "comments" {
  assert_eq(p("ab(?# comment)"), p("ab"))
  assert_eq(p("ab(?#)"), p("ab"))
  assert_eq(p("(?# comment 1)(?# comment 2)ab"), p("ab"))
  assert_eq(p("ab(?# comment \\))c"), p("abc"))
  assert_eq(p("ab(?# comment \\\\)c"), p("abc"))
  assert_eq(p("ab(?# comment ()c"), p("abc"))
  assert_eq(p("ab(?# comment)*"), p("ab*"))
  fail_parse("ab(?# comment")
  fail_parse("ab(?# comment\\")
}

///|
test "atomic_group" {
  assert_eq(p("(?>a)"), Expr::AtomicGroup(make_literal("a")))
}

///|
test "possessive" {
  assert_eq(
    p("a++"),
    Expr::AtomicGroup(
      Expr::Repeat(child=make_literal("a"), lo=1, hi=USIZE_MAX, greedy=true),
    ),
  )
  assert_eq(
    p("a*+"),
    Expr::AtomicGroup(
      Expr::Repeat(child=make_literal("a"), lo=0, hi=USIZE_MAX, greedy=true),
    ),
  )
  assert_eq(
    p("a?+"),
    Expr::AtomicGroup(
      Expr::Repeat(child=make_literal("a"), lo=0, hi=1, greedy=true),
    ),
  )
}

///|
test "invalid_backref" {
  // only syntactic tests; see similar test in analyze module
  assert_error(
    ".\\18446744073709551616", "Parsing error at position 2: Invalid back reference",
  ) // unreasonably large number
  assert_error(".\\c", "Parsing error at position 1: Invalid escape: \\c") // not decimal

  assert_error("a\\1", "Parsing error at position 2: Invalid back reference") // invalid back reference according to regex length - not long enough to contain that many paren pairs
  assert_error("(a)\\2", "Parsing error at position 4: Invalid back reference") // invalid back reference according to regex length - not long enough to contain that many paren pairs
}

///|
test "invalid_group_name_backref" {
  assert_error(
    "\\k<id>(?<id>.)", "Parsing error at position 2: Invalid group name in back reference: id",
  )
}

///|
test "named_backref_only" {
  assert_error(
    "(?<id>.)\\1", "Error compiling regex: Numbered backref/call not allowed because named group was used, use a named backref instead",
  )
  assert_error(
    "(a)\\1(?<name>b)", "Error compiling regex: Numbered backref/call not allowed because named group was used, use a named backref instead",
  )
}

///|
test "invalid_group_name" {
  assert_error(
    "(?<id)", "Parsing error at position 1: Could not parse group name",
  )
  assert_error(
    "(?<>)", "Parsing error at position 1: Could not parse group name",
  )
  assert_error(
    "(?<#>)", "Parsing error at position 1: Could not parse group name",
  )
  assert_error(
    "\\kxxx<id>", "Parsing error at position 2: Could not parse group name",
  )
  // "-" can only be used after a name for relative recursion level, so must be followed by a number
  assert_error(
    "\\k<id-withdash>", "Parsing error at position 2: Could not parse group name",
  )
  assert_error(
    "\\k<-id>", "Parsing error at position 2: Could not parse group name",
  )
}

///|
test "unknown_flag" {
  assert_error(
    "(?-:a)", "Parsing error at position 2: Unknown group flag: (?-:",
  )
  assert_error("(?)", "Parsing error at position 2: Unknown group flag: (?)")
  assert_error("(?--)", "Parsing error at position 2: Unknown group flag: (?--")
  // Check that we don't split on char boundary
  assert_error(
    "(?😊)", "Parsing error at position 2: Unknown group flag: (?😊",
  )
}

///|
test "no_quantifiers_on_lookarounds" {
  assert_error(
    "(?=hello)+", "Parsing error at position 9: Target of repeat operator is invalid",
  )
  assert_error(
    "(?<!hello)*", "Parsing error at position 10: Target of repeat operator is invalid",
  )
  assert_error(
    "(?<=hello){2,3}", "Parsing error at position 14: Target of repeat operator is invalid",
  )
  assert_error(
    "(?!hello)?", "Parsing error at position 9: Target of repeat operator is invalid",
  )
  assert_error(
    "^?", "Parsing error at position 1: Target of repeat operator is invalid",
  )
  assert_error(
    "${2}", "Parsing error at position 3: Target of repeat operator is invalid",
  )
  assert_error(
    "(?m)^?", "Parsing error at position 5: Target of repeat operator is invalid",
  )
  assert_error(
    "(?m)${2}", "Parsing error at position 7: Target of repeat operator is invalid",
  )
  assert_error(
    "(a|b|?)", "Parsing error at position 5: Target of repeat operator is invalid",
  )
}

///|
test "keepout" {
  assert_eq(
    p("a\\Kb"),
    Expr::Concat([make_literal("a"), Expr::KeepOut, make_literal("b")]),
  )
}

///|
test "no_quantifiers_on_other_non_repeatable_expressions" {
  assert_error(
    "\\K?", "Parsing error at position 2: Target of repeat operator is invalid",
  )
  assert_error(
    "\\G*", "Parsing error at position 2: Target of repeat operator is invalid",
  )
  assert_error(
    "\\b+", "Parsing error at position 2: Target of repeat operator is invalid",
  )
}

///|
test "backref_exists_condition" {
  assert_eq(
    p("(h)?(?(1))"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("h")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::BackrefExistsCondition(1),
    ]),
  )
  assert_eq(
    p("(?<h>h)?(?('h'))"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("h")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::BackrefExistsCondition(1),
    ]),
  )
}

///|
test "conditional_non_backref_validity_check_without_branches" {
  assert_error(
    "(?(foo))", "Parsing error at position 7: General parsing error: expected conditional to be a backreference or at least an expression for when the condition is true",
  )
}

///|
test "conditional_invalid_target_of_repeat_operator" {
  assert_error(
    "(?(?=\\d)\\w|!)", "Parsing error at position 3: Target of repeat operator is invalid",
  )
}

///|
test "conditional_unclosed_at_end_of_pattern" {
  assert_error(
    "(?(", "Parsing error at position 3: Opening parenthesis without closing parenthesis",
  )
}

///|
test "subroutine_call_unclosed_at_end_of_pattern" {
  assert_error(
    "\\g<", "Parsing error at position 2: Could not parse group name",
  )

  assert_error(
    "\\g<name", "Parsing error at position 2: Could not parse group name",
  )

  assert_error(
    "\\g'", "Parsing error at position 2: Could not parse group name",
  )

  assert_error(
    "\\g''", "Parsing error at position 2: Could not parse group name",
  )

  assert_error(
    "\\g<>", "Parsing error at position 2: Could not parse group name",
  )

  assert_error("\\g", "Parsing error at position 0: Invalid escape: \\g")

  assert_error(
    "\\g test", "Parsing error at position 2: Could not parse group name",
  )
}

///|
test "subroutine_call_missing_subroutine_reference" {
  assert_error(
    "\\g test", "Parsing error at position 2: Could not parse group name",
  )
}

///|
test "subroutine_call_name_includes_dash" {
  assert_error(
    "\\g<1-0>(a)", "Parsing error at position 2: Could not parse group name",
  )
  assert_error(
    "\\g<name+1>(?'name'a)", "Parsing error at position 2: Could not parse group name",
  )
}

///|
test "backref_condition_with_one_two_or_three_branches" {
  assert_eq(
    p("(h)?(?(1)i|x)"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("h")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::Conditional(
        condition=Expr::BackrefExistsCondition(1),
        true_branch=make_literal("i"),
        false_branch=make_literal("x"),
      ),
    ]),
  )

  assert_eq(
    p("(h)?(?(1)i)"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("h")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::Conditional(
        condition=Expr::BackrefExistsCondition(1),
        true_branch=make_literal("i"),
        false_branch=Expr::Empty,
      ),
    ]),
  )

  assert_eq(
    p("(h)?(?(1)ii|xy|z)"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("h")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::Conditional(
        condition=Expr::BackrefExistsCondition(1),
        true_branch=Expr::Concat([make_literal("i"), make_literal("i")]),
        false_branch=Expr::Alt([
          Expr::Concat([make_literal("x"), make_literal("y")]),
          make_literal("z"),
        ]),
      ),
    ]),
  )

  assert_eq(
    p("(?<cap>h)?(?(<cap>)ii|xy|z)"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("h")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::Conditional(
        condition=Expr::BackrefExistsCondition(1),
        true_branch=Expr::Concat([make_literal("i"), make_literal("i")]),
        false_branch=Expr::Alt([
          Expr::Concat([make_literal("x"), make_literal("y")]),
          make_literal("z"),
        ]),
      ),
    ]),
  )
}

///|
test "conditional" {
  assert_eq(
    p("((?(a)b|c))(\\1)"),
    Expr::Concat([
      Expr::Group(
        Expr::Conditional(
          condition=make_literal("a"),
          true_branch=make_literal("b"),
          false_branch=make_literal("c"),
        ),
      ),
      Expr::Group(Expr::Backref(group=1, casei=false)),
    ]),
  )

  assert_eq(
    p("^(?(\\d)abc|\\d!)$"),
    Expr::Concat([
      Expr::Assertion(Assertion::StartText),
      Expr::Conditional(
        condition=Expr::Delegate(inner="\\d", size=1, casei=false),
        true_branch=Expr::Concat([
          make_literal("a"),
          make_literal("b"),
          make_literal("c"),
        ]),
        false_branch=Expr::Concat([
          Expr::Delegate(inner="\\d", size=1, casei=false),
          make_literal("!"),
        ]),
      ),
      Expr::Assertion(Assertion::EndText),
    ]),
  )

  assert_eq(
    p("(?((?=\\d))\\w|!)"),
    Expr::Conditional(
      condition=Expr::LookAround(
        Expr::Delegate(inner="\\d", size=1, casei=false),
        LookAhead,
      ),
      true_branch=Expr::Delegate(inner="\\w", size=1, casei=false),
      false_branch=make_literal("!"),
    ),
  )

  assert_eq(
    p("(?((ab))c|d)"),
    Expr::Conditional(
      condition=Expr::Group(
        Expr::Concat([make_literal("a"), make_literal("b")]),
      ),
      true_branch=make_literal("c"),
      false_branch=make_literal("d"),
    ),
  )
}

///|
test "subroutines" {
  assert_eq(
    p("(a)\\g1"),
    Expr::Concat([Expr::Group(make_literal("a")), Expr::SubroutineCall(1)]),
  )

  assert_eq(
    p("(a)\\g<1>"),
    Expr::Concat([Expr::Group(make_literal("a")), Expr::SubroutineCall(1)]),
  )

  assert_eq(
    p("(?<group_name>a)\\g<group_name>"),
    Expr::Concat([Expr::Group(make_literal("a")), Expr::SubroutineCall(1)]),
  )

  assert_eq(
    p("(?<group_name>a)\\g'group_name'"),
    Expr::Concat([Expr::Group(make_literal("a")), Expr::SubroutineCall(1)]),
  )

  assert_eq(
    p("(?<group_name>a)(?P>group_name)"),
    Expr::Concat([Expr::Group(make_literal("a")), Expr::SubroutineCall(1)]),
  )
}

///|
test "subroutine_defined_later" {
  assert_eq(
    p("\\g<name>(?<name>a)"),
    Expr::Concat([Expr::SubroutineCall(1), Expr::Group(make_literal("a"))]),
  )

  assert_eq(
    p("\\g<c>(?:a|b|(?<c>c)?)"),
    Expr::Concat([
      Expr::SubroutineCall(1),
      Expr::Alt([
        make_literal("a"),
        make_literal("b"),
        Expr::Repeat(
          child=Expr::Group(make_literal("c")),
          lo=0,
          hi=1,
          greedy=true,
        ),
      ]),
    ]),
  )

  assert_eq(
    p("(?<a>a)?\\g<b>(?(<a>)(?<b>b)|c)"),
    Expr::Concat([
      Expr::Repeat(
        child=Expr::Group(make_literal("a")),
        lo=0,
        hi=1,
        greedy=true,
      ),
      Expr::SubroutineCall(2),
      Expr::Conditional(
        condition=Expr::BackrefExistsCondition(1),
        true_branch=Expr::Group(make_literal("b")),
        false_branch=make_literal("c"),
      ),
    ]),
  )

  assert_eq(
    p("\\g<1>(a)"),
    Expr::Concat([Expr::SubroutineCall(1), Expr::Group(make_literal("a"))]),
  )
}

///|
test "recursive_subroutine_call" {
  assert_eq(
    p("\\A(?<a>|.|(?:(?<b>.)\\g<a>\\k<b>))\\z"),
    Expr::Concat([
      Expr::Assertion(Assertion::StartText),
      Expr::Group(
        Expr::Alt([
          Expr::Empty,
          Expr::Any(newline=false),
          Expr::Concat([
            Expr::Group(Expr::Any(newline=false)),
            Expr::SubroutineCall(1),
            Expr::Backref(group=2, casei=false),
          ]),
        ]),
      ),
      Expr::Assertion(Assertion::EndText),
    ]),
  )
}

///|
test "self_recursive_subroutine_call" {
  let tree = Expr::parse_tree("hello\\g<0>?world")
  assert_true(tree.self_recursive)

  let tree = Expr::parse_tree("hello\\g0?world")
  assert_true(tree.self_recursive)

  let tree = Expr::parse_tree("hello world")
  assert_true(!tree.self_recursive)

  let tree = Expr::parse_tree("hello\\g1world")
  assert_true(!tree.self_recursive)

  let tree = Expr::parse_tree("hello\\g<1>world")
  assert_true(!tree.self_recursive)

  let tree = Expr::parse_tree("(hello\\g1?world)")
  assert_true(!tree.self_recursive)

  let tree = Expr::parse_tree("(?<a>hello\\g<a>world)")
  assert_true(!tree.self_recursive)
}

///|
test "named_subroutine_not_defined_later" {
  assert_eq(
    p("\\g<wrong_name>(?<different_name>a)"),
    Expr::Concat([
      Expr::UnresolvedNamedSubroutineCall(name="wrong_name", ix=2),
      Expr::Group(make_literal("a")),
    ]),
  )
}

// found by cargo fuzz, then minimized

///|
test "fuzz_1" {
  p("\\ä") |> ignore
}

///|
test "fuzz_2" {
  p("\\pä") |> ignore
}

///|
test "fuzz_3" {
  fail_parse("(?()^")
  fail_parse("!w(?()\\\"Kuz>")
}

///|
test "fuzz_4" {
  fail_parse("\\u{2}(?(2)")
}

///|
test "parse_with_case_insensitive_in_pattern" {
  let tree = Expr::parse_tree("(?i)hello")
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      make_literal_case_insensitive("h", true),
      make_literal_case_insensitive("e", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("o", true),
    ]),
  )
}

///|
test "parse_with_case_insensitive_option" {
  let options = get_options("hello", case_insensitive=true)

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      make_literal_case_insensitive("h", true),
      make_literal_case_insensitive("e", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("o", true),
    ]),
  )
}

///|
test "parse_with_multiline_in_pattern" {
  let options = get_options("(?m)^hello$")

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      Expr::Assertion(Assertion::StartLine(crlf=false)),
      make_literal("h"),
      make_literal("e"),
      make_literal("l"),
      make_literal("l"),
      make_literal("o"),
      Expr::Assertion(Assertion::EndLine(crlf=false)),
    ]),
  )
}

///|
test "pparse_with_multiline_option" {
  let options = get_options("^hello$", multi_line=true)

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      Expr::Assertion(Assertion::StartLine(crlf=false)),
      make_literal("h"),
      make_literal("e"),
      make_literal("l"),
      make_literal("l"),
      make_literal("o"),
      Expr::Assertion(Assertion::EndLine(crlf=false)),
    ]),
  )
}

///|
test "parse_with_dot_matches_new_line_in_pattern" {
  let options = get_options("(?s)(.*)")

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Group(
      Expr::Repeat(
        child=Expr::Any(newline=true),
        lo=0,
        hi=USIZE_MAX,
        greedy=true,
      ),
    ),
  )
}

///|
test "parse_with_dot_matches_new_line_option" {
  let options = get_options("(.*)", dot_matches_new_line=true)

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Group(
      Expr::Repeat(
        child=Expr::Any(newline=true),
        lo=0,
        hi=USIZE_MAX,
        greedy=true,
      ),
    ),
  )
}

///|
test "parse_fancy_with_dot_matches_new_line_in_pattern" {
  let options = get_options("(.*)(?<=hugo)", dot_matches_new_line=true)

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      Expr::Group(
        Expr::Repeat(
          child=Expr::Any(newline=true),
          lo=0,
          hi=USIZE_MAX,
          greedy=true,
        ),
      ),
      Expr::LookAround(
        Expr::Concat([
          make_literal("h"),
          make_literal("u"),
          make_literal("g"),
          make_literal("o"),
        ]),
        LookBehind,
      ),
    ]),
  )
}

///|
test "parse_with_case_insensitre_from_pattern_and_multi_line_option" {
  let options = get_options("(?i)^hello$", multi_line=true)

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      Expr::Assertion(Assertion::StartLine(crlf=false)),
      make_literal_case_insensitive("h", true),
      make_literal_case_insensitive("e", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("o", true),
      Expr::Assertion(Assertion::EndLine(crlf=false)),
    ]),
  )
}

///|
test "parse_with_multi_line_and_case_insensitive_options" {
  let options = get_options("^hello$", multi_line=true)
  options.syntaxc = { ..options.syntaxc, case_insensitive: true, }

  let tree = Expr::parse_tree_with_flags(
    options.pattern,
    options.compute_flags(),
  )
  let expr = tree.expr

  assert_eq(
    expr,
    Expr::Concat([
      Expr::Assertion(Assertion::StartLine(crlf=false)),
      make_literal_case_insensitive("h", true),
      make_literal_case_insensitive("e", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("l", true),
      make_literal_case_insensitive("o", true),
      Expr::Assertion(Assertion::EndLine(crlf=false)),
    ]),
  )
}
