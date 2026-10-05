///|
test "the design examples compile to PDF, SVG and PNG" {
  let world = @doc.DocWorld::in_memory()
  let compiled = @examples.report().compile_paged(world)
  for diagnostic in compiled.errors {
    println(diagnostic.render())
  }
  assert_true(compiled.errors.is_empty())
  let pdf = compiled.pdf().unwrap()
  assert_true(pdf.length() > 1000)
  let svg = compiled.svg_pages().unwrap()
  assert_true(svg.length() >= 1)
  let png = compiled.png_pages(ppi=72).unwrap()
  assert_eq(png.length(), svg.length())
  // The rules example on its own.
  let rules = @examples.rules().compile_paged(world)
  for diagnostic in rules.errors {
    println(diagnostic.render())
  }
  assert_true(rules.errors.is_empty())
}

///|
test "a missing resource is an error at the argument" {
  let doc = @doc.Document([@examples.picture()])
  let compiled = doc.compile_paged(@doc.DocWorld::in_memory())
  assert_eq(compiled.errors.length(), 1)
  let error = compiled.errors[0]
  inspect(
    error.message,
    content="file not found (searched at assets/chart.png)",
  )
  guard error.location is Some(Edsl(origin)) else {
    fail("expected an EDSL location")
  }
  inspect(origin.kind, content="Image")
  assert_eq(origin.param, Some(0))
  assert_true(origin.file.has_suffix("design_examples.mbt"))
}
