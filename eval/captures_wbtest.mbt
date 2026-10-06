// The capture analysis that is kept per compilation (`captures.mbt`)
// against the reference, upstream's `CapturesVisitor`: the recorded
// identifiers of hand-written expressions, and the captured scopes of every
// closure and context expression of a corpus (upstream's test suite and the
// touying, cetz and fletcher packages, where they are on disk) in several
// environments.

///|
fn captures_module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
let captures_library_cell : Ref[@library.Library?] = Ref(None)

///|
/// A library for the external scopes (its routines are never called).
fn captures_library() -> @library.Library {
  match captures_library_cell.val {
    Some(library) => library
    None => {
      let routines = @library.Routines::new(eval_string~, eval_closure~)
      let library = @library.Library::builder(routines, []).build()
      captures_library_cell.val = Some(library)
      library
    }
  }
}

///|
/// Every node that the evaluator analyzes in the tree: the closure
/// expressions (`eval_closure_expr`) and the bodies of the context
/// expressions (`eval_contextual`).
fn capture_nodes(
  node : @syntax.SyntaxNode,
  out : Array[@syntax.SyntaxNode],
) -> Unit {
  match @ast.Expr::from_untyped(node) {
    Some(Closure(_)) => out.push(node)
    Some(Contextual(contextual)) => out.push(contextual.body().to_untyped())
    _ => ()
  }
  for child in node.children() {
    capture_nodes(child, out)
  }
}

///|
/// The identifiers of the tree, in order of first occurrence.
fn capture_idents(
  node : @syntax.SyntaxNode,
  seen : Map[String, Unit],
  out : Array[String],
) -> Unit {
  match node.kind() {
    Ident | MathIdent => {
      let text = node.leaf_text()
      if !seen.contains(text) {
        seen[text] = ()
        out.push(text)
      }
    }
    _ => ()
  }
  for child in node.children() {
    capture_idents(child, seen, out)
  }
}

///|
/// The external scopes of variant `variant` for a tree with the identifiers
/// `names`: which names are known, where (the top scope, an outer scope, the
/// library in code or in math) and to what, differs per variant.
fn capture_environment(names : Array[String], variant : Int) -> @library.Scopes {
  let library = captures_library()
  let bind = (scope : @library.Scope, name : String, i : Int) => {
    scope.bind(
      name,
      @library.Binding::new(Int(i.to_int64()), @syntax.Span::detached()),
    )
    |> ignore
  }
  match variant {
    // Only the library.
    0 => @library.Scopes::new(Some(library))
    // Every name in the top scope, shadowing the library.
    1 => {
      let scopes = @library.Scopes::new(Some(library))
      for i, name in names {
        bind(scopes.top, name, i)
      }
      scopes
    }
    // A third each: the top scope, an outer scope, unknown (or the
    // library's).
    2 => {
      let scopes = @library.Scopes::new(Some(library))
      scopes.enter()
      for i, name in names {
        match i % 3 {
          0 => bind(scopes.top, name, i)
          1 => bind(scopes.scopes[0], name, i)
          _ => ()
        }
      }
      scopes
    }
    // No library (the scopes of a closure call), every other name known.
    _ => {
      let scopes = @library.Scopes::new(None)
      for i, name in names {
        if i % 2 == 0 {
          bind(scopes.top, name, i)
        }
      }
      scopes
    }
  }
}

///|
/// The names of a scope in order, and its fingerprint (the names in order
/// and for every binding the value, the kind, the span and the rest of what
/// upstream's `Hash` covers).
fn scope_summary(scope : @library.Scope) -> (Array[String], @library.U128) {
  (scope.iter().map(pair => pair.0).collect(), @library.hash128(scope))
}

///|
/// Compare the cache with the visitor for every analyzed node of `root`.
/// Returns the number of nodes, of comparisons and of captured bindings.
fn check_captures(
  root : @syntax.SyntaxNode,
  what : String,
) -> (Int, Int, Int) raise {
  let nodes = []
  capture_nodes(root, nodes)
  if nodes.is_empty() {
    return (0, 0, 0)
  }
  let names = []
  capture_idents(root, {}, names)
  let mut comparisons = 0
  let mut bindings = 0
  for variant in 0..<4 {
    let scopes = capture_environment(names, variant)
    for node in nodes {
      // Analyzed once, replayed for both kinds of capturers.
      let site = CaptureSite::new(node)
      for capturer in [@library.Capturer::Function, Context] {
        let visitor = CapturesVisitor::new(Some(scopes), capturer)
        visitor.visit(node)
        let expected = visitor.finish()
        let actual = site.captures(scopes, capturer)
        let (expected_names, expected_hash) = scope_summary(expected)
        let (actual_names, actual_hash) = scope_summary(actual)
        if expected_names != actual_names || expected_hash != actual_hash {
          fail(
            "\{what}, environment \{variant}: the captures of `\{node.full_text()}` differ: \{actual_names.join(" ")} instead of \{expected_names.join(" ")}",
          )
        }
        // The bindings hold the values of the external scopes themselves.
        for pair in expected.iter() {
          guard actual.get(pair.0) is Some(binding) else { fail("missing") }
          assert_true(physical_equal(binding.value, pair.1.value))
        }
        comparisons += 1
        bindings += expected_names.length()
      }
    }
  }
  (nodes.length(), comparisons, bindings)
}

///|
/// The recorded identifiers of the first closure or context expression of
/// `source` (code): `name` in code, `$name` in math, in order.
fn recorded(source : String) -> String raise {
  let root = @syntax.parse_code(source)
  let nodes = []
  capture_nodes(root, nodes)
  guard nodes.length() > 0 else { fail("no closure in `\{source}`") }
  check_captures(root, source) |> ignore
  CaptureSite::new(nodes[0]).attempts
  .map(attempt => {
    (if attempt.in_math { "$" } else { "" }) +
    attempt.name +
    (if attempt.repeated { "'" } else { "" })
  })
  .join(" ")
}

///|
test "captures: the identifiers that are looked up" {
  // Parameters are bound; the defaults of named parameters are evaluated
  // outside, before any parameter is bound.
  inspect(recorded("(x, y: a) => x + y + b"), content="a b")
  inspect(recorded("(a, b: a) => b"), content="a")
  inspect(recorded("(..rest) => rest.pos() + other"), content="other")
  inspect(recorded("(..) => none"), content="")
  inspect(recorded("x => x"), content="")
  // Patterns bind their names, not their keys.
  inspect(recorded("((a, b: (c, d), ..e)) => a + c + d + e + b"), content="b")
  inspect(recorded("((a, _), (b: c)) => a + b + c"), content="b")
  // A named closure knows itself.
  inspect(recorded("{ let f(x) = f(x - 1) + g }"), content="g")
  inspect(recorded("() => { let h(x) = h(x) + j; h(k) }"), content="j k")
  // A let binding is active after its initializer.
  inspect(recorded("() => { let a = a; a + b }"), content="a b")
  inspect(recorded("() => { let (a, (b, c)) = v; a + b + c }"), content="v")
  inspect(recorded("() => { let a; a }"), content="")
  // Blocks are scopes.
  inspect(recorded("() => { { let t = 1 }; t }"), content="t")
  inspect(recorded("() => [#let u = 1; #u #w]"), content="w")
  inspect(recorded("() => { [#let u = 1]; u }"), content="u")
  // A for loop binds its pattern for the body, after the iterable.
  inspect(
    recorded("() => { for (k, v) in d { k + v + w }; k }"),
    content="d w k",
  )
  inspect(recorded("() => { for x in x { x } }"), content="x")
  // An import binds its items after the source.
  inspect(
    recorded("() => { import m: p as q, r; p + q + r + m }"),
    content="m p",
  )
  inspect(recorded("() => { import m as n; m + n }"), content="m n")
  inspect(recorded("() => { import \"a.typ\": *; x }"), content="x")
  inspect(recorded("() => { include path; path }"), content="path")
  // Fields, methods and the names of named pairs are not variables.
  inspect(
    recorded("() => { x.y.z; f.with(k: v); (n: o, \"s\": p) }"),
    content="x f v o p",
  )
  inspect(recorded("() => f(..xs, a: b)"), content="f xs b")
  // Assignments are not bindings.
  inspect(recorded("() => { (a, b) = (b, a); c += d }"), content="a b c d")
  // Rules.
  inspect(
    recorded("() => { show heading: it => it.body + s; set text(fill: c) }"),
    content="heading s text c",
  )
  // Nested closures: their defaults are outside of them, their parameters
  // inside.
  inspect(
    recorded("() => { let g = (p, q: r) => p + q + s; g(p) }"),
    content="r s p",
  )
  inspect(recorded("(a) => (b) => (c) => a + b + c + d"), content="d")
  // Math identifiers are looked up in math; a name can be tried in both
  // modes.
  inspect(
    recorded("() => $ alpha + beta_gamma + #delta $"),
    content="$alpha $beta $gamma delta",
  )
  inspect(recorded("() => { alpha; $ alpha $ }"), content="alpha $alpha'")
  inspect(
    recorded("() => { $ alpha $; alpha; $ alpha $ }"),
    content="$alpha alpha'",
  )
  inspect(recorded("() => $ pi.alt + sin(theta) $"), content="$pi $sin $theta")
  // Context expressions: the body is analyzed.
  inspect(recorded("context here().page() + n"), content="here n")
  inspect(recorded("context { let n = 1; n + m }"), content="m")
  inspect(recorded("() => context a + b"), content="a b")
  // An identifier is recorded once per mode, however often it occurs.
  inspect(recorded("() => a + a + a + b + a"), content="a b")
  // Conditionals and loops bind nothing.
  inspect(
    recorded("() => { if a { b } else { c }; while d { e; break } }"),
    content="a b c d e",
  )
}

///|
test "captures: a name known in one mode only" {
  // `alpha` is a math symbol and unknown in code; `calc` is known in code
  // and not in math. Whichever lookup finds the name captures it, and the
  // other one is skipped or fails.
  let library = captures_library()
  for
    source in [
      "() => { alpha; $ alpha $ }", "() => { $ alpha $; alpha }", "() => { calc; $ calc $ }",
      "() => { $ calc $; calc }", "() => { $ nosuchname $; nosuchname }", "() => { std; $ std $ }",
    ] {
    let root = @syntax.parse_code(source)
    let nodes = []
    capture_nodes(root, nodes)
    let scopes = @library.Scopes::new(Some(library))
    let visitor = CapturesVisitor::new(Some(scopes), Function)
    visitor.visit(nodes[0])
    let expected = visitor.finish()
    let actual = CaptureSite::new(nodes[0]).captures(scopes, Function)
    assert_eq(scope_summary(actual).0, scope_summary(expected).0)
    assert_true(scope_summary(actual).1 == scope_summary(expected).1)
    assert_eq(
      expected.length(),
      if source.contains("nosuchname") {
        0
      } else {
        1
      },
    )
  }
}

///|
test "captures: kept per node for one compilation" {
  let root = @syntax.parse_code("{ let f = x => x + y; let g = x => x + y }")
  let nodes = []
  capture_nodes(root, nodes)
  assert_eq(nodes.length(), 2)
  // Outside of a compilation there is no cache.
  assert_true(CaptureSite::of(nodes[0]) is None)
  let site = (node : @syntax.SyntaxNode) => {
    guard CaptureSite::of(node) is Some(site) else { abort("no site") }
    site
  }
  let first : Ref[CaptureSite?] = Ref(None)
  @library.with_layout_memo(() => {
    let a = site(nodes[0])
    let b = site(nodes[1])
    first.val = Some(a)
    // One analysis per node object, also for nodes with the same text.
    guard physical_equal(a, site(nodes[0])) &&
      physical_equal(b, site(nodes[1])) &&
      !physical_equal(a, b) else {
      abort("sites are not kept per node")
    }
    // The nodes of an evaluated string share one span (and detached nodes
    // do): they are told apart, and more of them than are kept are
    // analyzed again.
    let many = []
    for i in 0..<(capture_sites_per_span + 2) {
      let root = @syntax.parse_code("x => x + y\{i}")
      root.synthesize(nodes[0].span())
      capture_nodes(root, many)
    }
    for i, node in many {
      let found = site(node)
      guard physical_equal(found.node, node) &&
        found.attempts.length() == 1 &&
        found.attempts[0].name == "y\{i}" else {
        abort("the site of another node")
      }
    }
    for i, node in many {
      guard site(node).attempts[0].name == "y\{i}" else {
        abort("the site of another node")
      }
    }
    guard site(nodes[0]).attempts[0].name == "y" else {
      abort("the site of another node")
    }
  })
  // Another compilation analyzes again.
  @library.with_layout_memo(() => {
    guard first.val is Some(a) && !physical_equal(a, site(nodes[0])) else {
      abort("a site outlived its compilation")
    }
  })
  // And none when memoization is off.
  @library.set_layout_memo_enabled(false)
  defer @library.set_layout_memo_enabled(true)
  @library.with_layout_memo(() => {
    guard CaptureSite::of(nodes[0]) is None else { abort("a site") }
  })
}

///|
/// The `.typ` files below `dir` (sorted, so that failures are stable).
fn typ_files(dir : String, out : Array[String]) -> Unit {
  let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
  entries.sort_by((a, b) => @library.compare_str(a, b))
  for entry in entries {
    let path = dir + "/" + entry
    let is_dir = @fs.is_dir(path) catch { _ => false }
    if is_dir {
      typ_files(path, out)
    } else if entry.has_suffix(".typ") {
      out.push(path)
    }
  }
}

///|
/// Check every file below `dir` (if it is there); returns the counts of
/// files, analyzed nodes, comparisons and captured bindings.
fn check_corpus(dir : String) -> (Int, Int, Int, Int) raise {
  guard captures_module_root() is Some(root) else { return (0, 0, 0, 0) }
  let files = []
  typ_files(root + dir, files)
  let mut nodes = 0
  let mut comparisons = 0
  let mut bindings = 0
  for path in files {
    let text = @fs.read_file_to_string(path) catch { _ => continue }
    // As markup (what the files are) and as code and math, which analyze
    // other trees of the same text.
    for mode in 0..<3 {
      let root = match mode {
        0 => @syntax.parse(text)
        1 => @syntax.parse_code(text)
        _ => @syntax.parse_math(text)
      }
      let (n, c, b) = check_captures(root, path)
      nodes += n
      comparisons += c
      bindings += b
    }
  }
  (files.length(), nodes, comparisons, bindings)
}

///|
test "captures: the cache gives the visitor's scopes on upstream's suite" {
  let (files, nodes, comparisons, bindings) = check_corpus(
    ".repos/typst/tests/suite",
  )
  // Skipped where upstream's sources are not checked out.
  if files > 0 {
    println(
      "captures: suite: \{files} files, \{nodes} expressions, \{comparisons} comparisons, \{bindings} captured bindings",
    )
    assert_true(nodes > 2000)
    assert_true(bindings > 20000)
  }
}

///|
test "captures: the cache gives the visitor's scopes on packages" {
  // touying, cetz and fletcher, if they are in the local package cache.
  let mut total = 0
  for package_ in ["touying", "cetz", "fletcher"] {
    let (files, nodes, comparisons, bindings) = check_corpus(
      "_build/typst-packages/preview/" + package_,
    )
    if files > 0 {
      println(
        "captures: \{package_}: \{files} files, \{nodes} expressions, \{comparisons} comparisons, \{bindings} captured bindings",
      )
      assert_true(nodes > 100)
    }
    total += files
  }
  ignore(total)
}
