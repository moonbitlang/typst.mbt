// The embedded sans-serif family (`doc/fonts`, `@doc.sans_fonts`): what the
// default worlds list, which faces a text selects, that a document which
// does not name the family is laid out as without it, and what the family
// covers of the punctuation and symbols of reports.

///|
/// The entries of a family in the book of a world, one line each: the
/// index, the family, the variant and the number of characters of the
/// entry's coverage.
fn family_entries(world : @doc.DocWorld, family : String) -> String {
  let book = @library.World::book(world)
  book
  .select_family(family)
  .map(index => {
    let info = book.info(index).unwrap()
    "\{index} \{info.family} \{info.variant} chars=\{info.coverage.iter().count()}"
  })
  .join("\n")
}

///|
/// The fonts that draw the text of a frame: per font (by PostScript name,
/// in order of first use) the texts of its glyphs' clusters, each once
/// (no plain spaces, other spaces by their number); `[..]` around the text
/// of a missing glyph.
fn collect_fonts(
  frame : @library.Frame,
  out : Map[String, Array[String]],
) -> Unit {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => collect_fonts(group.frame, out)
      Text(item) => {
        let font = item.font.font()
        let name = font.post_script_name().unwrap_or(font.info().family)
        let texts = match out.get(name) {
          Some(texts) => texts
          None => {
            let texts = []
            out[name] = texts
            texts
          }
        }
        let view = @library.TextItemView::full(item)
        for glyph in item.glyphs {
          let text = view.glyph_text(glyph)
          guard text != " " else { continue }
          // Other spaces by their number.
          let text = match text {
            [c] if c.to_int() == 0xA0 ||
              c.to_int() is (0x2000..<=0x200A | 0x202F) =>
              "U+" + c.to_int().to_string(radix=16).to_upper()
            _ => text
          }
          let text = if glyph.id == 0 { "[\{text}]" } else { text }
          if !texts.contains(text) {
            texts.push(text)
          }
        }
      }
      _ => ()
    }
  }
}

///|
/// `collect_fonts` of the pages of a report, one line per font.
fn fonts_of(report : @doc.CompileReport[@layout.PagedDocument]) -> String raise {
  let out : Map[String, Array[String]] = Map([])
  for page in report.unwrap().pages() {
    collect_fonts(page.frame, out)
  }
  out.iter().map(entry => "\{entry.0}: \{entry.1.join(" ")}").join("\n")
}

///|
/// The fonts that draw the text of the pages of a report.
fn font_names(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> String raise {
  let out : Map[String, Array[String]] = Map([])
  for page in report.unwrap().pages() {
    collect_fonts(page.frame, out)
  }
  out.keys().to_array().join(", ")
}

///|
/// A world of the given fonts and book, without files.
fn world_of(
  fonts : Array[@library.Font],
  book : @library.FontBook,
) -> @doc.DocWorld {
  @doc.DocWorld::new(
    load=id => {
      raise @library.FileError::NotFound(id.vpath().get_without_slash())
    },
    book~,
    font=index => fonts.get(index),
  )
}

///|
test "sans: the files are one family, in two releases" {
  // What the files say of themselves: the family and style of the `name`
  // table, its version, the units per em, the glyphs, the characters and
  // the size. Italic and Bold Italic are a later release (51 characters
  // more), with the same metrics.
  let lines = []
  for entry in @doc.sans_fonts() {
    let (font, _) = entry
    let ttf = font.ttf().unwrap()
    let name = id => @library.find_name(ttf, id).unwrap_or("-")
    let metrics = font
      .instantiate_with(@library.FontVariations::default())
      .metrics()
    lines.push(
      "\{name(1)} / \{name(2)} / \{name(5)} / \{font.post_script_name().unwrap_or("-")}: upem \{ttf.units_per_em()}, \{ttf.number_of_glyphs()} glyphs, \{font.info().coverage.iter().count()} chars, \{font.data().length()} bytes, ascender \{metrics.ascender.get()}, cap \{metrics.cap_height.get()}, x \{metrics.x_height.get()}, descender \{metrics.descender.get()}",
    )
  }
  inspect(
    lines.join("\n"),
    content=(
      #|IBM Plex Sans / Regular / Version 3.2 / IBMPlexSans-Regular: upem 1000, 926 glyphs, 844 chars, 175748 bytes, ascender 0.78, cap 0.698, x 0.516, descender -0.22
      #|IBM Plex Sans / Italic / Version 3.005 / IBMPlexSans-Italic: upem 1000, 1011 glyphs, 895 chars, 207920 bytes, ascender 0.78, cap 0.698, x 0.516, descender -0.22
      #|IBM Plex Sans / Bold / Version 3.2 / IBMPlexSans-Bold: upem 1000, 926 glyphs, 844 chars, 175712 bytes, ascender 0.78, cap 0.698, x 0.525, descender -0.22
      #|IBM Plex Sans / Bold Italic / Version 3.005 / IBMPlexSans-BoldItalic: upem 1000, 1011 glyphs, 895 chars, 208588 bytes, ascender 0.78, cap 0.698, x 0.525, descender -0.22
      #|IBM Plex Sans Medium / Regular / Version 3.2 / IBMPlexSans-Medium: upem 1000, 926 glyphs, 844 chars, 177104 bytes, ascender 0.78, cap 0.698, x 0.52, descender -0.22
    ),
  )
}

///|
test "sans: in the default world by name, with five variants" {
  let world = @doc.DocWorld::in_memory()
  let book = @library.World::book(world)
  // After the Typst fonts, as one family, each entry without coverage.
  inspect(
    book.len(),
    content=(
      #|22
    ),
  )
  inspect(
    family_entries(world, "ibm plex sans"),
    content=(
      #|17 IBM Plex Sans Normal-FontWeight(400)-FontStretch(1000) chars=0
      #|18 IBM Plex Sans Italic-FontWeight(400)-FontStretch(1000) chars=0
      #|19 IBM Plex Sans Normal-FontWeight(700)-FontStretch(1000) chars=0
      #|20 IBM Plex Sans Italic-FontWeight(700)-FontStretch(1000) chars=0
      #|21 IBM Plex Sans Normal-FontWeight(500)-FontStretch(1000) chars=0
    ),
  )
  inspect(
    book.families().map(family => family.0).join(", "),
    content=(
      #|DejaVu Sans Mono, IBM Plex Sans, Libertinus Serif, New Computer Modern, New Computer Modern Math
    ),
  )
  // The fonts themselves are whole.
  inspect(
    book
    .select_family("ibm plex sans")
    .map(index => {
      let font = @library.World::font(world, index).unwrap()
      "\{font.post_script_name().unwrap_or("-")} \{font.info().variant} chars=\{font.info().coverage.iter().count()}"
    })
    .join("\n"),
    content=(
      #|IBMPlexSans-Regular Normal-FontWeight(400)-FontStretch(1000) chars=844
      #|IBMPlexSans-Italic Italic-FontWeight(400)-FontStretch(1000) chars=895
      #|IBMPlexSans-Bold Normal-FontWeight(700)-FontStretch(1000) chars=844
      #|IBMPlexSans-BoldItalic Italic-FontWeight(700)-FontStretch(1000) chars=895
      #|IBMPlexSans-Medium Normal-FontWeight(500)-FontStretch(1000) chars=844
    ),
  )
  // Not without the embedded fonts.
  let fontless = @doc.DocWorld::in_memory(embedded_fonts=false)
  assert_eq(@library.World::book(fontless).len(), 0)
  assert_false(@library.World::book(fontless).contains_family("ibm plex sans"))
  let report = @doc.Document(
    [..small_page(), @doc.Text("Sans", font=["IBM Plex Sans"])],
  ).compile_paged(fontless)
  inspect(
    warning_messages(report),
    content=(
      #|unknown font family: ibm plex sans
    ),
  )
}

///|
test "sans: italic, bold and medium are the family's own faces" {
  // Typst does not synthesize a style or a weight: each line is drawn by
  // the face that the book selects.
  let line = (text : String, style : String, weight : @doc.FontWeight) => {
    @doc.Par(@doc.Text(text, font=["IBM Plex Sans"], style~, weight~))
  }
  let report = compile(
    [
      ..small_page(),
      line("regular", "normal", Regular),
      line("italic", "italic", Regular),
      line("bold", "normal", Bold),
      line("bolditalic", "italic", Bold),
      line("medium", "normal", Medium),
      // No medium italic: the style counts before the weight.
      line("mediumitalic", "italic", Medium),
      // Between Medium and Bold: Bold, which is the earlier file.
      line("semibold", "normal", SemiBold),
      line("light", "normal", Light),
      // `Strong` and `Emph` inside the family.
      @doc.Par(
        @doc.Text(@doc.Seq([@doc.Strong("strong"), @doc.Emph("emph")]), font=[
          "IBM Plex Sans",
        ]),
      ),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(
    fonts_of(report),
    content=(
      #|IBMPlexSans-Regular: r e g u l a i h t
      #|IBMPlexSans-Italic: i t a l c m e d u p h
      #|IBMPlexSans-Bold: b o l d s e m i t r n g
      #|IBMPlexSans-BoldItalic: b o l d i t a c
      #|IBMPlexSans-Medium: m e d i u
    ),
  )
}

///|
/// Characters that IBM Plex Sans has and the font of the text lacks, for
/// each of the embedded Typst families: in body text, in raw text, in
/// text in New Computer Modern and in a formula (New Computer Modern
/// Math). Text in another font than Libertinus Serif tries that one
/// before any fallback (the tail of the list of families), so only what
/// Libertinus Serif lacks as well reaches the choice among all fonts.
fn fallback_probe() -> Array[&@doc.IntoContent] {
  [
    ..small_page(),
    @doc.Par(
      "check \u{2713} rouble \u{20BD} hook \u{21A9} seventh \u{2150} cross \u{274C}",
    ),
    @doc.Par(@doc.Emph("check \u{2713} rouble \u{20BD} ligature \u{FB01}")),
    @doc.Par(@doc.Raw("vi\u{1EC7}t \u{1E9E} \u{20BF} \u{2B0E}")),
    @doc.Par(
      @doc.Text("third \u{2153} two \u{2082} \u{FFFD}", font=[
        "New Computer Modern",
      ]),
    ),
    @doc.Equation("x + \u{2153} + \"fifth \u{2155}\""),
  ]
}

///|
test "sans: a document that does not name the family is laid out as without it" {
  // The default world against a world of the Typst fonts alone.
  let with_sans = @doc.Document(fallback_probe()).compile_paged(
    @doc.DocWorld::in_memory(),
  )
  let typst_fonts = @doc.typst_fonts()
  let without = @doc.Document(fallback_probe()).compile_paged(
    world_of(typst_fonts, @library.FontBook::from_fonts(typst_fonts)),
  )
  inspect(error_messages(with_sans), content="")
  inspect(
    fonts_of(with_sans),
    content=(
      #|LibertinusSerif-Regular: c h e k r o u b l s v n t [❌] ẞ ₿ ⅓ ₂ � ⅕
      #|NewCMMath-Regular: ✓ ↩ ⬎
      #|NewCM10-Regular: ₽ t h i r d w o
      #|DejaVuSansMono: ⅐ v i ệ t
      #|LibertinusSerif-Italic: c h e k r o u b l i g a t
      #|NewCM10-Italic: ₽ ﬁ
      #|NewCMMath-Book: 𝑥 + f i t h
    ),
  )
  assert_eq(fonts_of(with_sans), fonts_of(without))
  assert_true(with_sans.svg_pages().unwrap() == without.svg_pages().unwrap())
  assert_true(with_sans.pdf().unwrap() == without.pdf().unwrap())
  // What `sans_fonts` avoids: with the coverage of the family in the book
  // the engine gives it these characters, although it is the last entry
  // (a fallback is the font most similar to the font of the text, and
  // among equals the one with the shorter name).
  let fonts = [..typst_fonts, ..@doc.sans_fonts().map(entry => entry.0)]
  let covering = @doc.Document(fallback_probe()).compile_paged(
    world_of(fonts, @library.FontBook::from_fonts(fonts)),
  )
  inspect(
    fonts_of(covering),
    content=(
      #|LibertinusSerif-Regular: c h e k r o u b l s v n t ẞ ₿ ⅓ ₂ � ⅕
      #|IBMPlexSans-Regular: ✓ ₽ ↩ ⅐ ❌ ⬎
      #|LibertinusSerif-Italic: c h e k r o u b l i g a t
      #|IBMPlexSans-Italic: ✓ ₽ ﬁ
      #|DejaVuSansMono: v i ệ t
      #|NewCM10-Regular: t h i r d w o
      #|NewCMMath-Book: 𝑥 + f i t h
    ),
  )
}

///|
test "sans: Latin text with the punctuation of reports has no missing glyph" {
  let text = "\u{201C}Quoted\u{201D} and \u{2018}single\u{2019}, a dash \u{2013} or \u{2014}, an ellipsis\u{2026} 3 \u{00D7} 4 \u{2192} 12 \u{2264} 13 \u{2265} 2 \u{2260} 1 \u{2212} 0 \u{2022} \u{20AC}5 20\u{00B0}C \u{00B1}1 \u{00B7} \u{2190} \u{2191} \u{2193} \u{2248} \u{221E} \u{00B5}m 5\u{2030} \u{2116}1 \u{2122} \u{00A9} \u{00A7} \u{2020} 5\u{2032} \u{00AB}a\u{00BB} \u{00BD} m\u{00B2} H\u{2082}O \u{2713} \u{0394} \u{03C0} na\u{00EF}ve caf\u{00E9} \u{0141}\u{00F3}d\u{017A} \u{017D}i\u{017E}ek"
  let report = compile(
    [
      ..small_page(),
      @doc.SetText(font=["IBM Plex Sans"]),
      @doc.Par(text),
      @doc.Par(@doc.Emph(text)),
      @doc.Par(@doc.Strong(text)),
      @doc.Par(@doc.Strong(@doc.Emph(text))),
      @doc.Par(@doc.Text(text, weight=Medium)),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(page_lints(report), content="")
  // Every glyph is the family's own.
  inspect(
    font_names(report),
    content=(
      #|IBMPlexSans-Regular, IBMPlexSans-Italic, IBMPlexSans-Bold, IBMPlexSans-BoldItalic, IBMPlexSans-Medium
    ),
  )
}

///|
test "sans: what the family lacks comes from the Typst fonts" {
  // Symbols of reports that IBM Plex Sans does not have (a fallback, no
  // missing glyph), and of the characters that only the italics have (the
  // later release) the hyphens U+2010 and U+2011 and two spaces: the
  // hyphens of upright text are a fallback, the spaces are not (for a
  // space character that a font lacks the shaper takes the font's space
  // glyph in that character's width: HarfBuzz's fallback spaces).
  let symbols = "a \u{21D2} \u{25B2} \u{25BC} \u{25A0} \u{25CF} \u{25CB} \u{2717} \u{25C6} \u{2605} \u{2610} \u{2611} non\u{2011}breaking hy\u{2010}phen 5\u{2009}kg 5\u{202F}%"
  let report = compile(
    [
      ..small_page(),
      @doc.SetText(font=["IBM Plex Sans"]),
      @doc.Par(symbols),
      @doc.Par(@doc.Emph(symbols)),
    ],
  )
  inspect(error_messages(report), content="")
  inspect(warning_messages(report), content="")
  inspect(page_lints(report), content="")
  inspect(
    fonts_of(report),
    content=(
      #|IBMPlexSans-Regular: a n o b r e k i g h y p 5 U+2009 U+202F %
      #|LibertinusSerif-Regular: ⇒ ▲ ▼ ■ ● ○ ◆ ★ ‑ ‐
      #|NewCMMath-Regular: ✗
      #|DejaVuSansMono: ☐ ☑
      #|IBMPlexSans-Italic: a n o ‑ b r e k i g h y ‐ p 5 U+2009 U+202F %
      #|LibertinusSerif-Italic: ⇒ ▲ ▼ ■ ● ○ ◆ ★
    ),
  )
}
