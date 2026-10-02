// The fonts typst-cli embeds (`typst_assets::fonts()` with the `fonts`
// feature): Libertinus Serif, New Computer Modern (+ Math) and DejaVu Sans
// Mono. The font files are in `files/` (from typst-assets at revision
// 94dcb99, version 0.15.1, with its LICENSE and NOTICE); the pre-build step
// `gen-fonts` turns them into `fonts_gen.c` (native, decoded by
// `fonts_stub.c`) and `fonts_wasm_gen.mbt` (wasm, wasm-gc), which are not
// committed.

///|
let fonts_cell : Ref[Array[Bytes]?] = { val: None, }

///|
/// The embedded font files, in upstream order. Decoded once on first use.
pub fn fonts() -> Array[Bytes] {
  match fonts_cell.val {
    Some(fonts) => fonts
    None => {
      let fonts = Array::makei(font_count(), font_data)
      fonts_cell.val = Some(fonts)
      fonts
    }
  }
}
