///|
fn debug_scope_stack_op(op : ScopeStackOp) -> String {
  match op {
    Push(scope) => "Push(\{scope.debug()})"
    Pop(n) => "Pop(\{n})"
    Clear(TopN(n)) => "Clear(TopN(\{n}))"
    Clear(All) => "Clear(All)"
    Restore => "Restore"
    Noop => "Noop"
  }
}

///|
fn describe_parse(syntax : String, lines : Array[String]) -> String {
  let out = StringBuilder()
  for newlines in [false, true] {
    try SyntaxDefinition::load_from_str(syntax, newlines, None) catch {
      e => out.write_string("error \{e}\n")
    } noraise {
      def => {
        let builder = SyntaxSetBuilder::new()
        builder.add(def)
        let set = builder.build()
        let state = ParseState::new(set.syntaxes()[0])
        for line in lines {
          let line = if newlines { line + "\n" } else { line }
          try state.parse_line(line, set) catch {
            e => out.write_string("error \{e}\n")
          } noraise {
            ops =>
              out.write_string(
                "ops " +
                ops.map(o => "\{o.0}:\{debug_scope_stack_op(o.1)}").join(" ") +
                "\n",
              )
          }
        }
      }
    }
  }
  out.to_string()
}

///|
test "upstream parser test syntaxes match syntect" {
  let failures = []
  for case in parser_cases {
    let (syntax, lines, expected) = case
    let actual = describe_parse(syntax, lines)
    if actual != expected {
      failures.push((syntax, expected, actual))
    }
  }
  if !failures.is_empty() {
    let (syntax, expected, actual) = failures[0]
    fail(
      "\{failures.length()}/\{parser_cases.length()} cases differ; first:\n\{syntax}\nexpected:\n\{expected}\nactual:\n\{actual}",
    )
  }
}

///|
test "scope repository" {
  let repo = ScopeRepository::new()
  assert_true(repo.build("source.php") == repo.build("source.php"))
  assert_true(
    repo.build("source.php.wow.hi.bob.troll.clock.5") ==
    repo.build("source.php.wow.hi.bob.troll.clock.5"),
  )
  assert_true(repo.build("") == repo.build(""))
  let s1 = repo.build("")
  assert_eq(repo.to_string(s1), "")
  let s2 = repo.build("source.php.wow")
  assert_eq(repo.to_string(s2), "source.php.wow")
  assert_true(repo.build("source.php") != repo.build("source.perl"))
  assert_true(repo.build("source.php") != repo.build("source.php.wagon"))
  assert_true(repo.build("comment.line.") == repo.build("comment.line"))
}

///|
test "global scope repository" {
  assert_true(Scope::new("source.php") == Scope::new("source.php"))
  assert_true((try? Scope::new("1.2.3.4.5.6.7.8")) is Ok(_))
  assert_true((try? Scope::new("1.2.3.4.5.6.7.8.9")) is Err(_))
}

///|
test "scope prefixes" {
  let s = (x : String) => Scope::new(x) catch { _ => abort("scope") }
  assert_true(s("1.2.3.4.5.6.7.8").is_prefix_of(s("1.2.3.4.5.6.7.8")))
  assert_true(s("1.2.3.4.5.6").is_prefix_of(s("1.2.3.4.5.6.7.8")))
  assert_true(s("1.2.3.4").is_prefix_of(s("1.2.3.4.5.6.7.8")))
  assert_true(!s("1.2.3.4.5.6.a").is_prefix_of(s("1.2.3.4.5.6.7.8")))
  assert_true(!s("1.2.a.4.5.6.7").is_prefix_of(s("1.2.3.4.5.6.7.8")))
  assert_true(!s("1.2.a.4.5.6.7").is_prefix_of(s("1.2.3.4.5")))
  assert_true(!s("1.2.a").is_prefix_of(s("1.2.3.4.5.6.7.8")))
}

///|
test "scope stack matching" {
  let m = (sel : String, stack : String) => {
    let sel = ScopeStack::from_str(sel) catch { _ => abort("stack") }
    let stack = ScopeStack::from_str(stack) catch { _ => abort("stack") }
    sel.does_match(stack.as_slice()).map(p => p.0.to_int())
  }
  assert_eq(m("string", "string.quoted"), Some(0o1))
  assert_eq(m("source", "string.quoted"), None)
  assert_eq(m("a.b e.f", "a.b c.d e.f.g"), Some(0o202))
  assert_eq(m("c e.f", "a.b c.d e.f.g"), Some(0o210))
  assert_eq(m("c.d e.f", "a.b c.d e.f.g"), Some(0o220))
  assert_eq(m("a.b c e.f", "a.b c.d e.f.g"), Some(0o212))
  assert_eq(m("a c.d", "a.b c.d e.f.g"), Some(0o021))
  assert_eq(m("a c.d.e", "a.b c.d e.f.g"), None)
}

///|
test "selectors" {
  let m = (sel : String, stack : String) => {
    let sel = ScopeSelectors::from_str(sel) catch { _ => abort("selector") }
    let stack = ScopeStack::from_str(stack) catch { _ => abort("stack") }
    sel.does_match(stack.as_slice()).map(p => p.0.to_int())
  }
  assert_eq(m("a.b, a e, e.f", "a.b e.f"), Some(0o20))
  assert_eq(m("a.b, a e.f, e.f", "a.b e.f"), Some(0o21))
  assert_eq(m("a.b, a e.f - c j, e.f", "a.b c.d j e.f"), Some(0o2000))
  assert_eq(m("a.b, a e.f - c j, e.f - a.b", "a.b c.d j e.f"), Some(0o2))
  assert_eq(m("a.b, a e.f - c k, e.f - a.b", "a.b c.d j e.f"), Some(0o2001))
  assert_eq(m("a.b|a e.f -d, e.f -a.b", "a.b c.d e.f"), Some(0o201))
  let sels = ScopeSelectors::from_str(" -a.b|j.g") catch { _ => abort("") }
  assert_eq(sels.selectors.length(), 2)
  assert_eq(sels.selectors[0].path.scopes.length(), 0)
  assert_eq(sels.selectors[0].excludes[0].scopes[0].build_string(), "a.b")
  assert_eq(sels.selectors[1].path.scopes[0].build_string(), "j.g")
  let sel = ScopeSelector::from_str(" - a.b") catch { _ => abort("") }
  let stack = ScopeStack::from_str("a.b c.d j e.f") catch { _ => abort("") }
  assert_eq(sel.does_match(stack.as_slice()), None)
}

///|
test "regex rewriting for newlines" {
  let rewrite = regex_for_newlines
  assert_eq(rewrite("a"), "a")
  assert_eq(rewrite("\\b"), "\\b")
  assert_eq(rewrite("(a)"), "(a)")
  assert_eq(rewrite("[a]"), "[a]")
  assert_eq(rewrite("[^a]"), "[^a]")
  assert_eq(rewrite("[]a]"), "[]a]")
  assert_eq(rewrite("[[a]]"), "[[a]]")
  assert_eq(rewrite("^"), "^")
  assert_eq(rewrite("$"), "(?m:$)")
  assert_eq(rewrite("^ab$"), "^ab(?m:$)")
  assert_eq(rewrite("\\^ab\\$"), "\\^ab\\$")
  assert_eq(rewrite("(//).*$"), "(//).*(?m:$)")
  assert_eq(rewrite("[a$]"), "[a$]")
}

///|
test "regex rewriting for no newlines" {
  let rewrite = regex_for_no_newlines
  assert_eq(rewrite("a"), "a")
  assert_eq(rewrite("\\b"), "\\b")
  assert_eq(rewrite("(a)"), "(a)")
  assert_eq(rewrite("[a]"), "[a]")
  assert_eq(rewrite("[^a]"), "[^a]")
  assert_eq(rewrite("[]a]"), "[]a]")
  assert_eq(rewrite("[[a]]"), "[[a]]")
  assert_eq(rewrite("\\n"), "$")
  assert_eq(rewrite("\\[\\n"), "\\[$")
  assert_eq(rewrite("a\\n?"), "a\\n?")
  assert_eq(rewrite("a\\n+"), "a\\n+")
  assert_eq(rewrite("a\\n*"), "a\\n*")
  assert_eq(rewrite("[abc\\n]"), "(?:[abc\\n]|$)")
  assert_eq(rewrite("[^\\n]"), "[^\\n]")
  assert_eq(rewrite("[^]\\n]"), "[^]\\n]")
  assert_eq(rewrite("[\\n]?"), "[\\n]?")
  assert_eq(rewrite("[\\n]"), "(?:[\\n]|$)")
  assert_eq(rewrite("[]\\n]"), "(?:[]\\n]|$)")
  assert_eq(rewrite("[[a]&&[\\n]]"), "[[a]&&[\\n]]")
  assert_eq(rewrite("ab(?:\\n)?"), "ab(?:$|)")
  assert_eq(rewrite("(?<!\\n)ab"), "(?<!$)ab")
  assert_eq(rewrite("(?<=\\n)ab"), "(?<=$)ab")
}

///|
test "consuming capture indexes" {
  assert_eq(
    get_consuming_capture_indexes("hello(test)(?=(world))(foo(?P<named>bar))"),
    [0, 1, 3, 4],
  )
  assert_eq(
    get_consuming_capture_indexes("hello(test)[(?=tricked](foo(bar))"),
    [0, 1, 2, 3],
  )
  assert_eq(
    get_consuming_capture_indexes(
      "hello(test)(?=(world(?!(te(?<=(st))))))(foo(bar))",
    ),
    [0, 1, 5, 6],
  )
}

///|
test "substitute backrefs" {
  let r = Regex::new("(\\\\\\[\\]\\(\\))(b)(c)(d)(e)")
  let s = "\\[]()bcde"
  let region = Region::new()
  let text = ByteIndex::new(s)
  assert_true(r.search(text, 0, text.len(), Some(region)))
  let pat = MatchPattern::new(
    true,
    "lol \\\\ \\2 \\1 '\\9' \\wz",
    [],
    None,
    MatchOperation::None,
    None,
  )
  assert_eq(
    pat.regex_with_refs(region, text).regex_str(),
    "lol \\\\ b \\\\\\[\\]\\(\\) '' \\wz",
  )
}
