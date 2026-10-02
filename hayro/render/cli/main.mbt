// A development tool: renders a PDF page with the settings Typst uses (see
// `render/image.mbt`'s `build_pdf_texture`) and writes the raw premultiplied
// RGBA8 pixmap, for differential testing against `hayro::render`
// (`oracle/src/bin/gen_hayro_render_tests.rs` with `HAYRO_RENDER_DUMP`).
//
// Usage: hayro-render-cli <out.rgba> <file.pdf> <page> <scale>

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
fn main {
  let args = @env.args()
  guard args.length() >= 5 else {
    println("usage: hayro-render-cli <out.rgba> <file.pdf> <page> <scale>")
    return
  }
  let out = args[1]
  let path = args[2]
  let page = @string.parse_int(args[3]) catch { _ => 0 }
  let scale = Float::from_double(@string.parse_double(args[4]) catch { _ => 1.0 })
  let data = @fs.read_file_to_bytes(path) catch {
    _ => {
      println("\{path}: read error")
      return
    }
  }
  guard @hayro_syntax.Pdf::new(data) is Ok(pdf) else {
    println("\{path}: failed to load")
    return
  }
  guard pdf.pages().get(page) is Some(p) else {
    println("\{path}: missing page \{page}")
    return
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
  let pix = @hayro_render.render(p, @hayro_render.RenderCache::new(), settings, {
    x_scale: scale,
    y_scale: scale,
    width: None,
    height: None,
    bg_color: @vello_cpu.transparent,
  })
  @fs.write_bytes_to_file(out, Bytes::from_array(pix.data())) catch {
    _ => println("\{out}: write error")
  }
  println("\{pix.width()}x\{pix.height()}")
}
