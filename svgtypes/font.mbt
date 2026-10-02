// Port of `svgtypes` 0.16.1 `src/font.rs`.

///|
/// Parses a list of font families and generic families from a string.
pub fn parse_font_families(
  text : String,
) -> Array[FontFamily] raise SvgTypesError {
  let s = Stream::from(text)
  let font_families = s.parse_font_families()
  s.skip_spaces()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  font_families
}

///|
/// A type of font family.
pub(all) enum FontFamily {
  /// A serif font.
  Serif
  /// A sans-serif font.
  SansSerif
  /// A cursive font.
  Cursive
  /// A fantasy font.
  Fantasy
  /// A monospace font.
  Monospace
  /// A custom named font.
  Named(String)
} derive(Eq, Debug, Hash)

///|
/// Upstream's `Display`.
pub impl Show for FontFamily with fn output(self, logger) {
  let str = match self {
    Monospace => "monospace"
    Serif => "serif"
    SansSerif => "sans-serif"
    Cursive => "cursive"
    Fantasy => "fantasy"
    Named(s) => "\"\{s}\""
  }
  logger.write_string(str)
}

///|
pub fn Stream::parse_font_families(
  self : Stream,
) -> Array[FontFamily] raise SvgTypesError {
  let families = []
  while !self.at_end() {
    self.skip_spaces()
    let family = {
      let ch = self.curr_byte()
      if ch == b'\'' || ch == b'"' {
        let res = self.parse_quoted_string()
        FontFamily::Named(res)
      } else {
        let idents = []
        while self.curr_char() is Some(c) {
          if c != ',' {
            idents.push(self.parse_ident())
            self.skip_spaces()
          } else {
            break
          }
        }
        let joined = idents.join(" ")

        // TODO: No CSS keyword must be matched as a family name...
        match joined {
          "serif" => FontFamily::Serif
          "sans-serif" => FontFamily::SansSerif
          "cursive" => FontFamily::Cursive
          "fantasy" => FontFamily::Fantasy
          "monospace" => FontFamily::Monospace
          _ => FontFamily::Named(joined)
        }
      }
    }
    families.push(family)
    if self.curr_byte_opt() is Some(b) {
      if b == b',' {
        self.advance(1)
      } else {
        break
      }
    }
  }
  families.filter(f => {
    match f {
      Named(s) => !s.is_empty()
      _ => true
    }
  })
}

///|
/// The values of a [`font` shorthand](https://www.w3.org/TR/css-fonts-3/#font-prop).
pub(all) struct FontShorthand {
  /// The font style.
  font_style : String?
  /// The font variant.
  font_variant : String?
  /// The font weight.
  font_weight : String?
  /// The font stretch.
  font_stretch : String?
  /// The font size.
  font_size : String
  /// The font family.
  font_family : String
} derive(Eq, Debug, Hash)

///|
/// Parses the `font` shorthand from a string.
///
/// [font]: https://www.w3.org/TR/css-fonts-3/#font-prop
pub fn FontShorthand::from_str(
  text : String,
) -> FontShorthand raise SvgTypesError {
  let stream = Stream::from(text)
  stream.skip_spaces()
  let mut prev_pos = stream.pos()
  let mut font_style : String? = None
  let mut font_variant : String? = None
  let mut font_weight : String? = None
  let mut font_stretch : String? = None
  for _ in 0..<4 {
    let ident = stream.consume_ascii_ident()
    match ident {
      // TODO: Reuse actual parsers to prevent duplication.
      // We ignore normal because it's ambiguous to which it belongs and all
      // other attributes need to be reset anyway.
      "normal" => ()
      "small-caps" => font_variant = Some(ident)
      "italic" | "oblique" => font_style = Some(ident)
      "bold"
      | "bolder"
      | "lighter"
      | "100"
      | "200"
      | "300"
      | "400"
      | "500"
      | "600"
      | "700"
      | "800"
      | "900" => font_weight = Some(ident)
      "ultra-condensed"
      | "extra-condensed"
      | "condensed"
      | "semi-condensed"
      | "semi-expanded"
      | "expanded"
      | "extra-expanded"
      | "ultra-expanded" => font_stretch = Some(ident)
      _ => {
        // Not one of the 4 properties, so we backtrack and then start
        // passing font size and family.
        stream.pos = 0
        stream.advance(prev_pos)
        break
      }
    }
    stream.skip_spaces()
    prev_pos = stream.pos()
  }
  prev_pos = stream.pos()
  if is_digit(stream.curr_byte()) {
    // A font size such as '15pt'.
    let _ = stream.parse_length()
  } else {
    // A font size like 'xx-large'.
    let size = stream.consume_ascii_ident()
    if !(size
      is ("xx-small"
      | "x-small"
      | "small"
      | "medium"
      | "large"
      | "x-large"
      | "xx-large"
      | "larger"
      | "smaller")) {
      raise UnexpectedData(prev_pos)
    }
  }
  let font_size = stream.slice_back(prev_pos)
  stream.skip_spaces()
  if stream.curr_byte() == b'/' {
    // We should ignore line height since it has no effect in SVG.
    stream.advance(1)
    stream.skip_spaces()
    let _ = stream.parse_length()
    stream.skip_spaces()
  }
  if stream.at_end() {
    raise UnexpectedEndOfStream
  }
  let font_family = stream.slice_tail()
  {
    font_style,
    font_variant,
    font_weight,
    font_stretch,
    font_size,
    font_family,
  }
}
