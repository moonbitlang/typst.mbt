// Documentation attached to bindings (upstream `BindingDocumentation`,
// typst-library/src/foundations/scope.rs).

///|
/// `define_func`, `define_type` and `define_elem` attach the documentation of
/// what they define (scope.rs:187, :194, :201).
test "native definitions are documented" {
  let scope = Scope::new()
  let elem = scope.define_elem(heading_elem())
  assert_true(elem.is_documented())
  assert_eq(elem.name(), Some("heading"))
  assert_eq(elem.title(), Some("Heading"))
  assert_eq(elem.docs(), Some(heading_elem().docs()))
  assert_true(elem.since() == Some(Forever))
  assert_eq(elem.keywords(), heading_elem().keywords())
  let ty = scope.define_type(Type::version())
  assert_true(ty.is_documented())
  assert_eq(ty.name(), Some("version"))
  assert_eq(ty.title(), Some("Version"))
  assert_eq(ty.docs(), Some(Type::version().docs()))
  assert_true(ty.since() == Some(Version(0, 9, 0)))
  assert_true(ty.since() == Type::version().since())
  assert_eq(ty.keywords(), Type::version().keywords())
  let func = scope.define_func(native_calc_abs())
  assert_true(func.is_documented())
  assert_eq(func.name(), Some("abs"))
  assert_eq(func.title(), Some("Absolute"))
  assert_eq(func.docs(), Some(native_calc_abs().docs))
  assert_true(func.since() == Some(Forever))
  // A plain definition has none.
  let plain = scope.define_("x", Int(1))
  assert_false(plain.is_documented())
  assert_eq(plain.name(), None)
  assert_eq(plain.title(), None)
  assert_eq(plain.docs(), None)
  assert_true(plain.since() is None)
  assert_true(plain.keywords().is_empty())
  // Neither has a user binding.
  assert_false(Binding::detached(Int(1)).is_documented())
}

///|
/// The definitions that upstream documents with a literal: the constants of
/// `calc` (calc.rs:61-127), `sys` (sys.rs:15-49) and the math spacings
/// (math/mod.rs:100-185).
test "explicit documentation" {
  let calc = calc_module().scope()
  guard calc.get("pi") is Some(pi) else { fail("calc.pi") }
  assert_eq(pi.name(), Some("pi"))
  assert_eq(pi.title(), Some("Pi"))
  assert_eq(
    pi.docs(),
    Some(
      "\n            Archimedes' constant ($pi$).\n\n            This is the ratio of a circle's circumference to its diameter.\n\n            ```example\n            #calc.pi\n            ```\n            ",
    ),
  )
  assert_true(pi.since() == Some(Forever))
  assert_eq(pi.keywords().to_owned(), ["Archimedes"])
  guard calc.get("tau") is Some(tau) else { fail("calc.tau") }
  assert_true(tau.since() == Some(Version(0, 8, 0)))
  guard calc.get("inf") is Some(inf) else { fail("calc.inf") }
  assert_eq(inf.title(), Some("Infinity"))
  guard calc.get("e") is Some(e) else { fail("calc.e") }
  assert_eq(e.title(), Some("Euler's number"))
  // Functions of the module are documented by `define_func`.
  guard calc.get("abs") is Some(abs) else { fail("calc.abs") }
  assert_eq(abs.title(), Some("Absolute"))
  let sys = sys_module(Dict::new()).scope()
  guard sys.get("version") is Some(version) else { fail("sys.version") }
  assert_eq(version.title(), Some("Compiler Version"))
  assert_true(version.since() == Some(Version(0, 9, 0)))
  guard sys.get("inputs") is Some(inputs) else { fail("sys.inputs") }
  assert_eq(inputs.title(), Some("CLI inputs"))
  assert_true(inputs.since() == Some(Version(0, 11, 0)))
  let math = math_module().scope()
  guard math.get("thin") is Some(thin) else { fail("math.thin") }
  assert_eq(thin.title(), Some("Thin space"))
  assert_eq(
    thin.docs(),
    Some(
      "\n            A mathematical space of width one sixth of an em.\n\n            ```example\n            $\n              x y \\\n              x thin y\n            $\n            ```\n            ",
    ),
  )
  assert_true(thin.since() == Some(Forever))
  for name in ["med", "thick", "quad", "wide"] {
    guard math.get(name) is Some(binding) else { fail("math.\{name}") }
    assert_true(binding.is_documented())
    assert_eq(binding.name(), Some(name))
  }
}

///|
fn documented(
  docs~ : String = "docs",
  since? : Since,
  keywords~ : Array[String] = [],
) -> U128 {
  hash128(
    Binding::detached(Int(1)).with_documentation({
      name: "x",
      title: "X",
      docs,
      since,
      keywords,
    }),
  )
}

///|
/// Upstream derives `Hash` for `BindingDocumentation`, so the fingerprint of
/// a binding covers every field of its documentation.
test "the fingerprint of a binding covers its documentation" {
  let base = documented()
  assert_true(base == documented())
  assert_true(base != hash128(Binding::detached(Int(1))))
  assert_true(base != documented(docs="other"))
  assert_true(base != documented(since=Forever))
  assert_true(documented(since=Forever) != documented(since=Unreleased))
  assert_true(
    documented(since=Version(0, 8, 0)) != documented(since=Version(0, 9, 0)),
  )
  assert_true(
    documented(since=Version(0, 8, 0)) == documented(since=Version(0, 8, 0)),
  )
  assert_true(base != documented(keywords=["a"]))
  assert_true(documented(keywords=["a"]) != documented(keywords=["b"]))
  assert_true(documented(keywords=["a", "b"]) != documented(keywords=["ab"]))
  assert_true(
    documented(since=Version(0, 8, 0)) != documented(since=Version(1, 8, 0)),
  )
  assert_true(
    documented(since=Version(0, 8, 0)) != documented(since=Version(0, 8, 1)),
  )
  let named = (name : String, title : String) => {
    hash128(
      Binding::detached(Int(1)).with_documentation({
        name,
        title,
        docs: "docs",
        since: None,
        keywords: [],
      }),
    )
  }
  assert_true(named("x", "X") == base)
  assert_true(named("y", "X") != base)
  assert_true(named("x", "Y") != base)
}

///|
/// Upstream's keywords are a static slice. Here the binding keeps its own
/// copy, so the array it was given cannot change them (or leave the cached
/// fingerprint of the binding stale), and the accessor returns a view.
test "the keywords of a binding cannot be changed from outside" {
  let keywords = ["a", "b"]
  let binding = Binding::detached(Int(1)).with_documentation({
    name: "x",
    title: "X",
    docs: "docs",
    since: None,
    keywords,
  })
  let before = hash128(binding)
  keywords[0] = "changed"
  keywords.push("c")
  assert_eq(binding.keywords().to_owned(), ["a", "b"])
  assert_true(hash128(binding) == before)
  // Changing the documentation through the binding does change it.
  binding.with_documentation({
    name: "x",
    title: "X",
    docs: "docs",
    since: None,
    keywords,
  })
  |> ignore
  assert_eq(binding.keywords().to_owned(), ["changed", "b", "c"])
  assert_true(hash128(binding) != before)
}

///|
/// Upstream's `cast!` for `Since` (version.rs:229-244).
test "since casts" {
  assert_true((Str("forever") : Value).cast() == (Forever : Since))
  assert_true((Str("unreleased") : Value).cast() == (Unreleased : Since))
  let version : Value = Version(Version([0, 8, 0]))
  assert_true(version.cast() == (Version(0, 8, 0) : Since))
  assert_eq((Forever : Since).into_value().repr(), "\"forever\"")
  assert_eq((Unreleased : Since).into_value().repr(), "\"unreleased\"")
  assert_eq(
    (Version(0, 14, 0) : Since).into_value().repr(),
    "version(0, 14, 0)",
  )
  let short : Value = Version(Version([0, 8]))
  let error = try {
    let _ : Since = short.cast()
    ""
  } catch {
    HintedError(e) => e.message
  }
  assert_eq(error, "expected a version with exactly three components")
  assert_true(Since::castable(Str("forever")))
  assert_false(Since::castable(Str("never")))
  assert_eq(@debug.to_string((Version(0, 8, 0) : Since)), "Version([0, 8, 0])")
  assert_eq(@debug.to_string(Some((Forever : Since))), "Some(Forever)")
}
