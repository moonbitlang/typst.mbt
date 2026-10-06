///|
fn test_sym(path : String) -> Symbol raise {
  let parts = path.split(".").map(p => p.to_owned()).to_array()
  let scope = Scope::from_codex(codex_sym())
  guard scope.get(parts[0]) is Some(binding) else { fail("no \{parts[0]}") }
  guard binding.value is Symbol(s) else { fail("not a symbol") }
  let mut s = s
  for i in 1..<parts.length() {
    s = s.modified(BindingGuard::silent(Features::none()), parts[i])
  }
  s
}

///|
test "symbol repr" {
  inspect(test_sym("amp").repr(), content="symbol(\"&\", (\"inv\", \"⅋\"))")
  inspect(test_sym("amp.inv").repr(), content="symbol(\"⅋\")")
  inspect(
    test_sym("arrow.double.r").repr(),
    content=(
      #|symbol(
      #|  "⇒",
      #|  ("bar", "⤇"),
      #|  ("long", "⟹"),
      #|  ("long.bar", "⟾"),
      #|  ("not", "⇏"),
      #|  ("struck", "⤃"),
      #|  ("l", "⇔"),
      #|  ("l.long", "⟺"),
      #|  ("l.not", "⇎"),
      #|  ("l.struck", "⤄"),
      #|)
    ),
  )
  inspect(test_sym("smash").repr(), content="symbol(\"⨳\")")
  inspect(test_sym("arrow.r.long").get(), content="⟶")
  inspect(test_sym("arrow.long.r").get(), content="⟶")
  inspect(test_sym("arrow").get(), content="→")
}

///|
test "symbol deprecation" {
  let warnings = []
  let guard_ = {
    features: Features::none(),
    emit: w => warnings.push(w.message),
  }
  let scope = Scope::from_codex(codex_sym())
  guard scope.get("succ") is Some({ value: Symbol(s), .. }) else {
    fail("succ")
  }
  let s = s.modified(guard_, "curly").modified(guard_, "eq")
  inspect(s.get(), content="≽")
  @debug.debug_inspect(
    warnings,
    content=(
      #|["`succ.curly.eq` is deprecated, use `succ.eq.slant` instead"]
    ),
  )
}

///|
test "symbol func" {
  let f = test_sym("arrow").func()
  @debug.debug_inspect(
    f.title(),
    content=(
      #|Some("Accent (⃗)")
    ),
  )
  let f = test_sym("paren.l").func()
  @debug.debug_inspect(
    f.title(),
    content=(
      #|Some("() Left/Right")
    ),
  )
  let alpha = test_sym("alpha")
  let message = try alpha.func() catch {
    HintedError(e) => e.message
  } noraise {
    _ => "callable"
  }
  inspect(message, content="symbol α is not callable")
}
