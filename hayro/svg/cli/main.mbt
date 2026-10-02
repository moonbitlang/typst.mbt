// A development tool: converts PDF pages to SVG with the settings Typst uses
// (see `svg/image.mbt`'s `pdf_to_svg`), for differential testing against
// `hayro_svg::convert`.
//
// Usage: hayro-svg-cli <out-dir> <file.pdf>[@page] ...
// Writes `<out-dir>/<basename>-<page>.svg` for each page (all pages if no
// `@page` is given).

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
  guard args.length() >= 3 else {
    println("usage: hayro-svg-cli <out-dir> <file.pdf>[@page] ...")
    return
  }
  let out_dir = args[1]
  for arg in args[2:] {
    let (path, page_sel) = match arg.find("@") {
      Some(i) =>
        (
          arg.view(end_offset=i).to_string(),
          Some(@string.parse_int(arg.view(start_offset=i + 1)) catch { _ => 0 }),
        )
      None => (arg, None)
    }
    let data = @fs.read_file_to_bytes(path) catch {
      e => {
        println("\{path}: read error \{e is @fs.IOError(_)}")
        continue
      }
    }
    let pdf = match @hayro_syntax.Pdf::new(data) {
      Ok(pdf) => pdf
      Err(_) => {
        println("\{path}: failed to load")
        continue
      }
    }
    let base = match path.rev_find("/") {
      Some(i) => path.view(start_offset=i + 1).to_string()
      None => path
    }
    let base = if base.has_suffix(".pdf") {
      base.view(end_offset=base.length() - 4).to_string()
    } else {
      base
    }
    let pages = pdf.pages()
    let indices = match page_sel {
      Some(p) => [p]
      None => Array::makei(pages.length(), i => i)
    }
    for idx in indices {
      guard pages.get(idx) is Some(page) else { continue }
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
      let cache = @hayro_svg.RenderCache::new()
      let svg = @hayro_svg.convert(page, cache, settings, {
        bg_color: [0, 0, 0, 0],
      })
      let out = "\{out_dir}/\{base}-\{idx}.svg"
      @fs.write_string_to_file(out, svg) catch {
        _ => println("\{out}: write error")
      }
    }
  }
}
