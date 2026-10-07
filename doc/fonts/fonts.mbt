// The sans-serif family of the document EDSL: IBM Plex Sans in Regular,
// Italic, Bold, Bold Italic and Medium. Typst embeds no sans-serif
// (`typst_assets/fonts`: Libertinus Serif, New Computer Modern, DejaVu Sans
// Mono), so this is not part of the port: only the worlds of `doc` load it
// (`@doc.sans_fonts`), and nothing of the Typst command line (`cli/`,
// `kit/`) depends on this package.
//
// The font files are in `files/` with their licence (`files/LICENSE.txt`:
// the SIL Open Font License 1.1, copyright IBM Corp., Reserved Font Name
// "Plex"). Because of the reserved name the files are committed byte for
// byte as they were obtained and must stay so: no subsetting, no
// conversion, no change of the family's name; a newer release replaces a
// file as a whole. Where they are from, and their SHA-256:
//
// - typst-dev-assets (e26d7ca, `files/fonts`), version 3.2 (`name` table;
//   `head` revision 3.002):
//   - IBMPlexSans-Regular.ttf
//     852def7e24f7b71bab6e8a5c9b02b203e45b0ef59697feaf116e7e8091ad7a2a
//   - IBMPlexSans-Bold.ttf
//     856c41d7d47bba74b107e526ef8f49968fb2a3a129cdc3c5ef5899ba3c2dc181
//   - IBMPlexSans-Medium.ttf
//     11ddde88c29ef7e51f5c03da7fde285085469879139d006f631a62dba9bbd069
// - IBM's repository (github.com/IBM/plex, `packages/plex-sans/fonts/
//   complete/ttf`, October 2026), version 3.005:
//   - IBMPlexSans-Italic.ttf
//     a9c6ef9942c49e49d11e11a6dacc0b3a087978757e9b22a06b8ac22a6400fb15
//   - IBMPlexSans-BoldItalic.ttf
//     0e3142ba2ef31fe5c02f0c6c36424f251609cd6b73880076e21c2e81931ba2b9
//
// So the family is of two releases. Their metrics are the same; the
// italics have 51 more characters (section 5 of `docs/edsl-guide.md` says
// which of them a report meets). `doc/sans_test.mbt` pins what the files
// say of themselves.
//
// The data is generated like that of `typst_assets/fonts`, by its
// generator: the pre-build step turns the files into `fonts_gen.c`
// (native: raw bytes, copied by `fonts_stub.c`) and `fonts_wasm_gen.mbt`
// (wasm, wasm-gc: base64), which are not committed but are part of the
// published package.

///|
let sans_cell : Ref[Array[Bytes]?] = { val: None, }

///|
/// The font files of IBM Plex Sans: Regular, Italic, Bold, Bold Italic,
/// Medium. Decoded once on first use.
pub fn sans() -> Array[Bytes] {
  match sans_cell.val {
    Some(fonts) => fonts
    None => {
      let fonts = Array::makei(font_count(), font_data)
      sans_cell.val = Some(fonts)
      fonts
    }
  }
}
