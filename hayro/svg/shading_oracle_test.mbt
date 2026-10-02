// Differential tests of shading rendering against `hayro_svg::convert`.
//
// `testdata/shading_oracle.txt` lists test PDFs that use shadings (axial,
// radial, function-based and mesh shadings, native gradients and rasterized
// shadings) with the length and FNV-1a 64 hash of the SVG produced by the
// upstream crates for the given page. The PDFs are read from the
// `target/hayro` symlink of a development checkout (hayro's `hayro-tests`);
// the test is skipped if it is missing.

///|
fn module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
fn fnv1a64(s : String) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in @utf8.encode(s) {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
fn hex64(v : UInt64) -> String {
  let digits = "0123456789abcdef"
  let buf = StringBuilder::new()
  for i = 15; i >= 0; i = i - 1 {
    buf.write_char(digits[((v >> (4 * i)) & 15).to_int()].unsafe_to_char())
  }
  buf.to_string()
}

///|
fn select_standard_font(font : @interpret.StandardFont) -> (Bytes, Int)? {
  let bytes = match font {
    Helvetica => @pdf_fonts.sans()
    HelveticaBold => @pdf_fonts.sans_bold()
    HelveticaOblique => @pdf_fonts.sans_italic()
    HelveticaBoldOblique => @pdf_fonts.sans_bold_italic()
    Courier => @pdf_fonts.fixed()
    CourierBold => @pdf_fonts.fixed_bold()
    CourierOblique => @pdf_fonts.fixed_italic()
    CourierBoldOblique => @pdf_fonts.fixed_bold_italic()
    TimesRoman => @pdf_fonts.serif()
    TimesBold => @pdf_fonts.serif_bold()
    TimesItalic => @pdf_fonts.serif_italic()
    TimesBoldItalic => @pdf_fonts.serif_bold_italic()
    ZapfDingBats => @pdf_fonts.ding_bats()
    Symbol => @pdf_fonts.symbol()
  }
  Some((bytes, 0))
}

///|
test "shading PDFs match hayro-svg" {
  guard module_root() is Some(root) else { return }
  let pdf_dir = root + "target/hayro/hayro-tests/pdfs/"
  if !@fs.path_exists(pdf_dir) {
    return
  }
  let expected = @fs.read_file_to_string(
    root + "hayro/svg/testdata/shading_oracle.txt",
  )
  let mismatches = []
  for line in expected.split("\n") {
    if line.length() == 0 {
      continue
    }
    let parts = line.split(" ").map(p => p.to_string()).to_array()
    let path = parts[0]
    let page_idx = @string.parse_int(parts[1])
    let exp_len = @string.parse_int(parts[2])
    let exp_hash = parts[3]
    let data = @fs.read_file_to_bytes(pdf_dir + path)
    guard @hayro_syntax.Pdf::new(data) is Ok(pdf) else {
      mismatches.push("\{path}: failed to load")
      continue
    }
    let settings : @interpret.InterpreterSettings = {
      font_resolver: query => {
        match query {
          Standard(s) => select_standard_font(s)
          Fallback(f) => select_standard_font(f.pick_standard_font())
        }
      },
      cmap_resolver: _ => None,
      warning_sink: _ => (),
      render_annotations: false,
    }
    let svg = @hayro_svg.convert(
      pdf.pages()[page_idx],
      @hayro_svg.RenderCache::new(),
      settings,
      { bg_color: [0, 0, 0, 0], },
    )
    let len = @utf8.encode(svg).length()
    let hash = hex64(fnv1a64(svg))
    if len != exp_len || hash != exp_hash {
      mismatches.push(
        "\{path}@\{page_idx}: expected \{exp_len} \{exp_hash}, got \{len} \{hash}",
      )
    }
  }
  if mismatches.length() > 0 {
    fail(mismatches.join("\n"))
  }
}
