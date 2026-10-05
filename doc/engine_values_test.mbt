///|
/// Compile markup to SVG text (one page).
fn markup_svg(source : String) -> String raise {
  let page = "#set page(width: 200pt, height: 60pt, margin: 6pt)\n"
  let compiled = @doc.Document([@doc.Markup(page + source)]).compile_paged(
    @doc.DocWorld::in_memory(),
  )
  compiled.svg_pages().unwrap().join("\n")
}

///|
test "Typst evaluation cannot tie a knot in a value" {
  // The port's arrays and dictionaries are mutable objects, but pushing an
  // array into itself stores the value it had, as in Typst: the result is
  // finite (the engine's fingerprints, reprs and comparisons rely on it).
  let nested = markup_svg(
    "#let a = (1,)\n#a.push(a)\n#a.push(a)\n#let d = (k: 1)\n#d.insert(\"self\", d)\n#assert.eq(a, (1, (1,), (1, (1,))))\n#assert.eq(d, (k: 1, self: (k: 1)))\n#metadata(a) <m>\n#context assert.eq(query(<m>).first().value, a)",
  )
  assert_true(nested.contains("<svg"))
}
