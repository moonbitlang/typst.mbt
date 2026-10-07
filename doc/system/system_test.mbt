// The fonts of the system world (the files are read from the module root,
// where `moon test` runs).

///|
/// The entries of a family in the book of a world, one line each: the
/// index, the variant and the number of characters of the entry's
/// coverage.
fn family_entries(world : @doc.DocWorld, family : String) -> String {
  let book = @library.World::book(world)
  book
  .select_family(family)
  .map(index => {
    let info = book.info(index).unwrap()
    "\{index} \{info.variant} chars=\{info.coverage.iter().count()}"
  })
  .join("\n")
}

///|
test "world: the embedded fonts are the Typst fonts and IBM Plex Sans by name" {
  let world = @system.world(system_fonts=false)
  let book = @library.World::book(world)
  inspect(
    book.families().map(family => family.0).join(", "),
    content=(
      #|DejaVu Sans Mono, IBM Plex Sans, Libertinus Serif, New Computer Modern, New Computer Modern Math
    ),
  )
  // The entries of `@doc.sans_fonts`: after the Typst fonts, no coverage.
  inspect(
    family_entries(world, "ibm plex sans"),
    content=(
      #|17 Normal-FontWeight(400)-FontStretch(1000) chars=0
      #|18 Italic-FontWeight(400)-FontStretch(1000) chars=0
      #|19 Normal-FontWeight(700)-FontStretch(1000) chars=0
      #|20 Italic-FontWeight(700)-FontStretch(1000) chars=0
      #|21 Normal-FontWeight(500)-FontStretch(1000) chars=0
    ),
  )
  // Neither without the embedded fonts.
  let fontless = @system.world(system_fonts=false, embedded_fonts=false)
  inspect(@library.World::book(fontless).len(), content="0")
}

///|
test "world: a font of the family from `font_paths` comes first" {
  // The caller's files of the family (here the embedded ones, from their
  // directory) are whole entries before the embedded ones, so they are
  // what a text selects: a document that brought its own IBM Plex Sans
  // is laid out with it.
  let world = @system.world(system_fonts=false, font_paths=["doc/fonts/files"])
  let book = @library.World::book(world)
  let chars = book
    .select_family("ibm plex sans")
    .map(index => book.info(index).unwrap().coverage.iter().count())
  assert_eq(chars.length(), 10)
  for i, count in chars {
    assert_eq(count > 0, i < 5)
  }
  for style in [@library.FontStyle::Normal, Italic] {
    for weight in [400, 500, 700] {
      let variant = @library.FontVariant::new(
        style,
        @library.FontWeight::from_number(weight),
        @library.FontStretch::default(),
      )
      let index = book.select("ibm plex sans", variant).unwrap()
      assert_true(index >= 17 && index < 22)
    }
  }
}
