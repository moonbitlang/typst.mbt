// Differential tests against `hayro_svg::convert`: converts PDFs of the hayro
// test corpus and of typst-dev-assets with the settings Typst uses and
// compares the SVG with the oracle's output (by length and FNV-1a hash,
// recorded in `testdata/expected.tsv` by
// `scripts/gen_hayro_svg_tests.py`).
//
// The PDFs are read through the `target/hayro` and `target/devassets`
// symlinks of a development checkout; the test is skipped if they are
// missing.

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
  let buf = StringBuilder()
  for i = 15; i >= 0; i = i - 1 {
    buf.write_char(digits[((v >> (i * 4)) & 0xf).to_int()].unsafe_to_char())
  }
  buf.to_string()
}

///|
fn test_select_standard_font(font : @interpret.StandardFont) -> (Bytes, Int)? {
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
test "hayro-svg matches the oracle" {
  guard module_root() is Some(root) else { return }
  guard @fs.path_exists(root + "target/hayro") else { return }
  let expected = @fs.read_file_to_string(
    root + "hayro/svg/testdata/expected.tsv",
  )
  let mismatches = []
  let mut checked = 0
  for line in expected.split("\n") {
    let line = line.to_owned()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let parts = line.split("\t").map(p => p.to_owned()).to_array()
    let path = root + parts[0]
    let page = @string.parse_int(parts[1])
    let len = @string.parse_int(parts[2])
    let hash = parts[3]
    let data = @fs.read_file_to_bytes(path) catch { _ => continue }
    guard @hayro_syntax.Pdf::new(data) is Ok(pdf) else {
      mismatches.push("\{parts[0]}: failed to load")
      continue
    }
    guard pdf.pages().get(page) is Some(p) else {
      mismatches.push("\{parts[0]}: missing page \{page}")
      continue
    }
    let settings : @interpret.InterpreterSettings = {
      font_resolver: query => {
        match query {
          Standard(s) => test_select_standard_font(s)
          Fallback(f) => test_select_standard_font(f.pick_standard_font())
        }
      },
      cmap_resolver: _ => None,
      warning_sink: _ => (),
      render_annotations: false,
    }
    let svg = @hayro_svg.convert(p, @hayro_svg.RenderCache::new(), settings, {
      bg_color: [0, 0, 0, 0],
    })
    let actual_len = @utf8.encode(svg).length()
    let actual_hash = hex64(fnv1a64(svg))
    if actual_len != len || actual_hash != hash {
      mismatches.push(
        "\{parts[0]}@\{page}: expected \{len} \{hash}, got \{actual_len} \{actual_hash}",
      )
    }
    checked += 1
  }
  if mismatches.length() > 0 {
    fail(mismatches.join("\n"))
  }
  assert_true(checked > 0)
}
