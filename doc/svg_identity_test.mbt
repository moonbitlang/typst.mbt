// What an SVG image is identified by (`@library.SvgImage`), with real
// fonts: its data, the fonts it uses, and which of them was chosen for
// what. Upstream's hash has the first two (`font_hash` is the fonts in the
// order in which they were first loaded), so there two trees that set a
// text in different fonts are one image if both fonts are in the SVG
// anyway. (The linked images, which are the third thing an image is
// identified by, need no fonts: `typst/state_outside_wbtest.mbt`.)

///|
/// The images of a frame, in order.
fn collect_images(frame : @library.Frame, out : Array[@library.Image]) -> Unit {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => collect_images(group.frame, out)
      Image(image, _, _) => out.push(image)
      _ => ()
    }
  }
}

///|
test "svg: an image is also which font was chosen for which text" {
  // The first two texts name their fonts, so both fonts are loaded in this
  // order whatever is around the image. The third names none and gets the
  // font of the text around the image.
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" viewBox="0 0 120 60">
    #|  <text x="5" y="15" font-family="Libertinus Serif" font-size="12">serif</text>
    #|  <text x="5" y="30" font-family="DejaVu Sans Mono" font-size="12">mono</text>
    #|  <text x="5" y="45" font-size="12">none</text>
    #|</svg>
    #|
  let source =
    #|#set page(width: 140pt, height: 80pt, margin: 10pt)
    #|#let shown(font) = text(font: font, image("t.svg", width: 120pt))
    #|#shown("Libertinus Serif")
    #|#pagebreak()
    #|#shown("DejaVu Sans Mono")
    #|#pagebreak()
    #|#shown("Libertinus Serif")
    #|
  let files : Map[String, Bytes] = { "t.svg": @utf8.encode(svg) }
  let report = compile([@doc.Markup(source)], files~)
  inspect(error_messages(report), content="")
  guard report.output() is Some(document) else { fail("a document") }
  let images = []
  for page in document.pages() {
    collect_images(page.frame, images)
  }
  inspect(images.length(), content="3")
  let selections = images.map(image => {
    match image.kind() {
      Svg(svg) =>
        svg
        .selections()
        .to_owned()
        .map(selection => selection.to_string())
        .join(" ")
      _ => "no SVG"
    }
  })
  // The places of the chosen fonts among the two that are used.
  inspect(selections.join(", "), content="0 1 0, 0 1 1, 0 1 0")
  // The same data and the same two fonts, and another picture.
  assert_true(images[0] != images[1])
  assert_true(@library.hash128(images[0]) != @library.hash128(images[1]))
  assert_true(images[0] == images[2])
  assert_eq(@library.hash128(images[0]), @library.hash128(images[2]))
  // The pages show it: the last line of the second is set in the other
  // font.
  let pages = report.png_pages(ppi=72.0).unwrap()
  assert_true(pages[0] != pages[1])
  assert_true(pages[0] == pages[2])
}
