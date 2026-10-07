///|
test "the paper compiles: no error, warning or lint, 38 pages" {
  let world = @system.world(
    root="doc/examples/papers/einstein-1916",
    system_fonts=false,
    today=(1916, 3, 20),
  )
  let compiled = document().compile_paged(world)
  assert_eq(compiled.errors.map(e => e.render()), [])
  assert_eq(compiled.warnings.map(w => w.render()), [])
  assert_eq(compiled.lints.map(l => l.render()), [])
  assert_eq(compiled.unwrap().pages().length(), 38)
}
