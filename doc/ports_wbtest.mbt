// White-box tests of the typed additions of docs/edsl-ports.md.

///|
test "the callback of `Layout` is its located argument" {
  let layout = Layout() <| ((_, _) => "x")
  guard layout.content.node is NCall(call) else { fail("not a call") }
  guard call.args is [arg] else { fail("not one argument") }
  // `ArgsLoc` has one entry per declared parameter, the autofilled ones
  // included: the callback is the third.
  let ArgsLoc(locations) = call.origin.args
  assert_eq(locations.length(), 3)
  assert_true(locations[arg.param] is Some(_))
  // So the argument has a span of its own inside the call's line, which
  // resolves to the call and the parameter.
  let registry = Registry::new()
  let entry = registry.entry(call.origin, [])
  let span = registry.arg_span(entry, arg.param)
  assert_true(span != registry.span(entry))
  guard registry.freeze().resolve(span) is Some(origin) else {
    fail("no origin")
  }
  inspect(origin.kind, content="Layout")
  assert_eq(origin.param, Some(arg.param))
}
