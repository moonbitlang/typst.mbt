// Differential tests against `hayro::render`: renders the pages of the hayro
// test corpus and of typst-dev-assets with the settings Typst uses (see
// `render/image.mbt`) at the scales recorded in `testdata/expected.tsv` and
// compares the size and the FNV-1a hash of the premultiplied RGBA8 pixmap
// with the oracle's (`oracle/src/bin/gen_hayro_render_tests.rs`, which reads
// `testdata/corpus.txt`).
//
// The PDFs are read through the `target/hayro` and `target/devassets`
// symlinks of a development checkout; the test is skipped if they are
// missing. `hayro/render/cli` renders single pages for ad-hoc diffs.

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
fn fnv1a64(data : FixedArray[Byte]) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
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
    buf.write_char(digits[((v >> (i * 4)) & 0xf).to_int()].unsafe_to_char())
  }
  buf.to_string()
}

///|
test "hayro::render matches the oracle" {
  guard module_root() is Some(root) else { return }
  guard @fs.path_exists(root + "target/hayro") else { return }
  let expected = @fs.read_file_to_string(
    root + "hayro/render/testdata/expected.tsv",
  )
  let mismatches = []
  let mut checked = 0
  for line in expected.split("\n") {
    let line = line.to_string()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let parts = line.split("\t").map(p => p.to_string()).to_array()
    let path = root + parts[0]
    let page = @string.parse_int(parts[1])
    let scale = Float::from_double(@string.parse_double(parts[2]))
    let width = @string.parse_int(parts[3])
    let height = @string.parse_int(parts[4])
    let hash = parts[5]
    let data = @fs.read_file_to_bytes(path) catch {
      _ => {
        mismatches.push("\{parts[0]}: cannot read")
        continue
      }
    }
    guard @hayro_syntax.Pdf::new(data) is Ok(pdf) else {
      mismatches.push("\{parts[0]}: failed to load")
      continue
    }
    guard pdf.pages().get(page) is Some(p) else {
      mismatches.push("\{parts[0]}: missing page \{page}")
      continue
    }
    let pix = @render.render(
      p,
      @render.RenderCache::new(),
      typst_interpreter_settings(),
      {
        x_scale: scale,
        y_scale: scale,
        width: None,
        height: None,
        bg_color: @vello_cpu.transparent,
      },
    )
    let actual_hash = hex64(fnv1a64(pix.data()))
    if pix.width() != width || pix.height() != height || actual_hash != hash {
      mismatches.push(
        "\{parts[0]}@\{page} x\{parts[2]}: expected \{width}x\{height} \{hash}, got \{pix.width()}x\{pix.height()} \{actual_hash}",
      )
    }
    checked += 1
  }
  if mismatches.length() > 0 {
    fail(
      "\{mismatches.length()}/\{checked} mismatches:\n" + mismatches.join("\n"),
    )
  }
  assert_true(checked > 0)
}

///|
/// The interpreter settings of `typst-render`'s `build_pdf_texture`.
fn typst_interpreter_settings() -> @interpret.InterpreterSettings {
  {
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
