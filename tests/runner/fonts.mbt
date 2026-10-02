// The fonts of the test world, in the order of upstream's
// `typst_assets::fonts().chain(typst_dev_assets::fonts())` (see
// `oracle/src/world.rs`), as recorded in the font manifest
// `tests/golden/fonts.json` (written by `scripts/goldens.sh fonts`). The
// bytes are read from the cargo git checkouts of the pinned typst-assets /
// typst-dev-assets revisions.

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
/// The font files of the test world (`source/path` and data), in order.
/// Collections appear once; their faces are split by the caller.
fn test_font_files() -> Array[(String, Bytes)] {
  match test_font_files_cell.val {
    Some(files) => files
    None => {
      let files = []
      let manifest = @json.parse(read(golden_dir + "/fonts.json")) catch {
        _ => abort("cannot parse \{golden_dir}/fonts.json")
      }
      guard manifest is Object(obj) && obj.get("fonts") is Some(Array(fonts)) else {
        abort("malformed font manifest")
      }
      let assets = cargo_checkout_files("typst-assets-")
      let dev = cargo_checkout_files("typst-dev-assets-")
      for entry in fonts {
        guard entry is Object(e) &&
          e.get("source") is Some(String(source)) &&
          e.get("path") is Some(String(path)) &&
          e.get("face") is Some(Number(face, ..)) else {
          abort("malformed font manifest entry")
        }
        // Only the first face of a collection introduces the file.
        if face != 0.0 {
          continue
        }
        let root = if source == "typst-assets" { assets } else { dev }
        files.push((source + "/" + path, read_bytes(root + "/" + path)))
      }
      test_font_files_cell.val = Some(files)
      files
    }
  }
}

///|
let test_font_files_cell : Ref[Array[(String, Bytes)]?] = Ref::new(None)

///|
/// The fonts of the test world, in book order (upstream
/// `TestBase::default`: `Font::iter` over every file).
fn test_fonts() -> Array[@library.Font] {
  match test_fonts_cell.val {
    Some(fonts) => fonts
    None => {
      let fonts = []
      for file in test_font_files() {
        for font in @library.Font::iter(file.1) {
          fonts.push(font)
        }
      }
      test_fonts_cell.val = Some(fonts)
      fonts
    }
  }
}

///|
let test_fonts_cell : Ref[Array[@library.Font]?] = Ref::new(None)

///|
/// The font book of the test world.
fn test_font_book() -> @library.FontBook {
  match test_font_book_cell.val {
    Some(book) => book
    None => {
      let book = @library.FontBook::from_fonts(test_fonts())
      test_font_book_cell.val = Some(book)
      book
    }
  }
}

///|
let test_font_book_cell : Ref[@library.FontBook?] = Ref::new(None)

///|
fn read_bytes(path : String) -> Bytes {
  @fs.read_file_to_bytes(path) catch {
    _ => abort("cannot read font \{path}")
  }
}
