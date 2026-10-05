// Plain values first (docs/edsl-design.md, section 6.1): which explicit
// states a field accepts is the engine's cast, reported at the argument.

///|
test "an explicit state the field does not accept is the engine's cast error" {
  // `text.size` is a length: no `auto`.
  let auto_size = compile([@doc.Text("x", size=Auto)])
  inspect(error_messages(auto_size), content="expected length, found auto")
  let origin = origin_of(auto_size.errors[0])
  inspect(origin.kind, content="Text")
  inspect(
    origin.param,
    content=(
      #|Some(5)
    ),
  )
  // `heading.numbering` accepts `none` but not `auto`.
  let none = compile([@doc.Heading("x", numbering=@doc.Numbering::none())])
  inspect(error_messages(none), content="")
  let auto = compile([
    @doc.Heading("x", extra=[("numbering", @doc.Value::auto())]),
  ])
  inspect(
    error_messages(auto),
    content="expected string, function, or none, found auto",
  )
  // Units: a ratio where the field is a length.
  let ratio = compile([@doc.Par("x", leading=Pct(50))])
  inspect(error_messages(ratio), content="expected length, found ratio")
  // Arithmetic on a state is Typst's operator error.
  let sum = compile([@doc.Block("x", width=Auto + Pt(1))])
  inspect(error_messages(sum), content="cannot add auto and length")
  // `all` with individual sides is rejected by the EDSL.
  let sides = compile([@doc.Block("x", inset=@doc.Sides(all=Pt(1), x=Pt(2)))])
  inspect(
    error_messages(sides),
    content="`all` cannot be combined with individual sides",
  )
}

///|
test "`extra` passes named arguments after the typed ones" {
  // A field without a typed parameter yet (`text.stretch`).
  let stretched = compile([
    @doc.Text("x", extra=[("stretch", @doc.Value::length(Pct(75)))]),
  ])
  inspect(error_messages(stretched), content="")
  // An unknown name is the engine's error, at the `extra` argument.
  let unknown = compile([@doc.Par("x", extra=[("nope", @doc.Value::int(1))])])
  inspect(error_messages(unknown), content="unexpected argument: nope")
  inspect(origin_of(unknown.errors[0]).kind, content="Par")
  // A later argument wins, as in Typst: `extra` overrides a typed one.
  let overridden = @doc.Document([
      @doc.Heading("x", level=2, extra=[("level", @doc.Value::int(3))]),
    ])
    .lower(@doc.DocWorld::in_memory())
    .unwrap()
  let level : Int64 = overridden.field(@library.heading_elem_level).cast()
  assert_eq(level, 3)
}
