// The `usvg-images` stage (see `oracle/src/usvg_images.rs`): compile every
// paged test of the files that mention SVG and dump the usvg tree of every SVG
// image placed in the document (`Tree::to_string` with default
// `WriteOptions`), in placement order, each distinct tree once. This checks
// `SvgImage::with_fonts_images` (font resolution through the font book and
// the linked image resolver) beyond the image sizes compared by `paged`.

///|
/// Compile a single test case and write the trees of its SVG images.
fn usvg_images_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  guard warned.output is Ok(doc) else { return "" }
  let seen : Map[String, Unit] = Map::new()
  let out = StringBuilder()
  fn walk(frame : @library.Frame) -> Unit {
    for entry in frame.items() {
      match entry.1 {
        Group(group) => walk(group.frame)
        Image(image, _, _) =>
          if image.kind() is Svg(svg) {
            let tree = svg.tree().to_string(@usvg.WriteOptions::default())
            let entry = "--- svg \{sha256_hex(svg.data())}\n\{tree}\n"
            if !seen.contains(entry) {
              seen[entry] = ()
              out.write_string(entry)
            }
          }
        _ => ()
      }
    }
  }

  for page in doc.pages() {
    walk(page.frame)
  }
  out.to_string()
}
