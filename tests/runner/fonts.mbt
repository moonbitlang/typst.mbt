// The fonts of the test world, in the order of upstream's
// `typst_assets::fonts().chain(typst_dev_assets::fonts())` (see
// `oracle/src/world.rs`). The bytes are read from the cargo git checkouts of
// the pinned typst-assets / typst-dev-assets revisions.

///|
/// `typst-assets` fonts (`typst_assets::fonts()`), relative to its `files/`.
let typst_assets_fonts : Array[String] = [
  "fonts/LibertinusSerif-Regular.otf", "fonts/LibertinusSerif-Bold.otf", "fonts/LibertinusSerif-Italic.otf",
  "fonts/LibertinusSerif-BoldItalic.otf", "fonts/LibertinusSerif-Semibold.otf", "fonts/LibertinusSerif-SemiboldItalic.otf",
  "fonts/NewCMMath-Bold.otf", "fonts/NewCMMath-Book.otf", "fonts/NewCMMath-Regular.otf",
  "fonts/NewCM10-Regular.otf", "fonts/NewCM10-Bold.otf", "fonts/NewCM10-Italic.otf",
  "fonts/NewCM10-BoldItalic.otf", "fonts/DejaVuSansMono-Bold.ttf", "fonts/DejaVuSansMono-BoldOblique.ttf",
  "fonts/DejaVuSansMono-Oblique.ttf", "fonts/DejaVuSansMono.ttf",
]

///|
/// `typst-dev-assets` fonts (`typst_dev_assets::fonts()`, i.e. the `FILES`
/// entries starting with `fonts`), relative to its `files/`.
let typst_dev_assets_fonts : Array[String] = [
  "fonts/Asana-Math.otf", "fonts/Cantarell-VF.otf", "fonts/CascadiaCode-Regular.ttf",
  "fonts/CascadiaMono-Bold.ttf", "fonts/CascadiaMono-Regular.ttf", "fonts/Concrete-Math.otf",
  "fonts/DejaVuSans-Oblique.ttf", "fonts/DejaVuSans.ttf", "fonts/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf",
  "fonts/Fraunces[SOFT,WONK,opsz,wght].ttf", "fonts/Garamond-Math.otf", "fonts/HKGrotesk-BlackItalic.ttf",
  "fonts/HKGrotesk-Bold.ttf", "fonts/HKGrotesk-BoldItalic.ttf", "fonts/HKGrotesk-ExtraBold.ttf",
  "fonts/HKGrotesk-ExtraBoldItalic.ttf", "fonts/HKGrotesk-ExtraLight.ttf", "fonts/HKGrotesk-ExtraLightItalic.ttf",
  "fonts/HKGrotesk-Italic.ttf", "fonts/HKGrotesk-Light.ttf", "fonts/HKGrotesk-LightItalic.ttf",
  "fonts/HKGrotesk-Medium.ttf", "fonts/HKGrotesk-MediumItalic.ttf", "fonts/HKGrotesk-Regular.ttf",
  "fonts/HKGrotesk-SemiBold.ttf", "fonts/HKGrotesk-SemiBoldItalic.ttf", "fonts/HKGrotesk-Thin.ttf",
  "fonts/IBMPlexMath-Regular.otf", "fonts/IBMPlexSans-Bold.ttf", "fonts/IBMPlexSans-Light.ttf",
  "fonts/IBMPlexSans-Medium.ttf", "fonts/IBMPlexSans-Regular.ttf", "fonts/IBMPlexSansCondensed-Regular.ttf",
  "fonts/IBMPlexSansDevanagari-Regular.ttf", "fonts/IBMPlexSerif-Regular.ttf", "fonts/InriaSerif-Bold.ttf",
  "fonts/InriaSerif-BoldItalic.ttf", "fonts/InriaSerif-Italic.ttf", "fonts/InriaSerif-Regular.ttf",
  "fonts/LibertinusMath-Regular.otf", "fonts/MonaSansVF[wdth,wght,opsz,ital].ttf",
  "fonts/NotoColorEmoji-Regular-CBDT.subset.ttf", "fonts/NotoColorEmoji-Regular-COLR.subset.ttf",
  "fonts/NotoSans-Regular.ttf", "fonts/NotoSansArabic-Regular.ttf", "fonts/NotoSansMath-Regular.ttf",
  "fonts/NotoSansSymbols2-Regular.ttf", "fonts/NotoSansThai-Regular.ttf", "fonts/NotoSerifCJKjp-Regular.otf",
  "fonts/NotoSerifCJKkr-Regular.otf", "fonts/NotoSerifCJKsc-Bold.otf", "fonts/NotoSerifCJKsc-Regular.otf",
  "fonts/NotoSerifCJKtc-Bold.otf", "fonts/NotoSerifCJKtc-Regular.otf", "fonts/NotoSerifHebrew-Bold.ttf",
  "fonts/NotoSerifHebrew-Regular.ttf", "fonts/PTSans-Regular.ttf", "fonts/PennstanderMath-Regular.otf",
  "fonts/Roboto-Regular.ttf", "fonts/RobotoFlex-VariableFont_GRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght.ttf",
  "fonts/STIXTwoMath-Regular.otf", "fonts/SourceSerif4-Regular.otf", "fonts/SourceSerif4Variable-Italic.otf",
  "fonts/SourceSerif4Variable-Roman.otf", "fonts/TwitterColorEmoji.ttf", "fonts/Ubuntu-Regular.ttf",
  "fonts/XITSMath-Regular.otf", "fonts/texgyrebonum-math.otf",
]

///|
/// The `files/` directory of a cargo git checkout whose name starts with
/// `prefix` (e.g. `typst-assets-`).
fn cargo_checkout_files(prefix : String) -> String {
  let home = @env.get_env_vars().get("HOME").unwrap_or("")
  let base = home + "/.cargo/git/checkouts"
  let dirs = (@fs.read_dir(base) catch { _ => [][:] }).to_owned()
  dirs.sort()
  for d in dirs {
    if d.has_prefix(prefix) {
      let revs = (@fs.read_dir(base + "/" + d) catch { _ => [][:] }).to_owned()
      revs.sort()
      for r in revs {
        return base + "/" + d + "/" + r + "/files"
      }
    }
  }
  ""
}

///|
/// The raw data of all test-world font files, in order.
fn test_font_files() -> Array[(String, Bytes)] {
  match test_font_files_cell.val {
    Some(files) => files
    None => {
      let files = []
      let assets = cargo_checkout_files("typst-assets-")
      for path in typst_assets_fonts {
        files.push((path, read_bytes(assets + "/" + path)))
      }
      let dev = cargo_checkout_files("typst-dev-assets-")
      for path in typst_dev_assets_fonts {
        files.push((path, read_bytes(dev + "/" + path)))
      }
      test_font_files_cell.val = Some(files)
      files
    }
  }
}

///|
let test_font_files_cell : Ref[Array[(String, Bytes)]?] = Ref::new(None)

///|
fn read_bytes(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    _ => abort("cannot read font \{path}")
  }
}
