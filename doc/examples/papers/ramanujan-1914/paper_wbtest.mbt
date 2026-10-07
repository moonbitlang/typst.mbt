///|
test "the paper compiles: no error, warning or lint, 14 pages" {
  let world = @system.world(system_fonts=false, today=(2026, 1, 1))
  let compiled = paper().compile_paged(world)
  assert_eq(compiled.errors.map(e => e.render()), [])
  assert_eq(compiled.warnings.map(w => w.render()), [])
  assert_eq(compiled.lints.map(l => l.render()), [])
  assert_eq(compiled.unwrap().pages().length(), 14)
  // What `main` prints: `eq` counts the numbered displays and checks that
  // each has the paper's number.
  assert_eq(audit.numbered, 50)
  assert_eq(audit.formulas.length(), 355)
}
