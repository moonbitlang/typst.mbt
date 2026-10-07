///|
test "the paper compiles: no error, warning or lint, 22 pages" {
  let world = @system.world(
    root="doc/examples/papers/lovelace-1843",
    system_fonts=false,
    today=(1843, 9, 1),
  )
  let compiled = paper().compile_paged(world)
  assert_eq(compiled.errors.map(e => e.render()), [])
  assert_eq(compiled.warnings.map(w => w.render()), [])
  assert_eq(compiled.lints.map(l => l.render()), [])
  assert_eq(compiled.unwrap().pages().length(), 22)
}
