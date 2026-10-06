// Port of `hayro-interpret/src/font/standard_font.rs`.

///|
/// The 14 standard fonts of PDF.
pub(all) enum StandardFont {
  /// Helvetica.
  Helvetica
  /// Helvetica Bold.
  HelveticaBold
  /// Helvetica Oblique.
  HelveticaOblique
  /// Helvetica Bold Oblique.
  HelveticaBoldOblique
  /// Courier.
  Courier
  /// Courier Bold.
  CourierBold
  /// Courier Oblique.
  CourierOblique
  /// Courier Bold Oblique.
  CourierBoldOblique
  /// Times Roman.
  TimesRoman
  /// Times Bold.
  TimesBold
  /// Times Italic.
  TimesItalic
  /// Times Bold Italic.
  TimesBoldItalic
  /// Zapf Dingbats - a decorative symbol font.
  ZapfDingBats
  /// Symbol - a mathematical symbol font.
  Symbol
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StandardFont with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StandardFont with @debug.Debug::{to_repr}

///|
fn StandardFont::code_to_name(self : StandardFont, code : Byte) -> String? {
  match self {
    Symbol => symbol_get(code)
    // Note that this font does not return postscript character names,
    // but instead has a custom encoding.
    ZapfDingBats => zapf_dings_get(code)
    _ => standard_get(code)
  }
}

///|
fn StandardFont::get_width(self : StandardFont, name : String) -> Float? {
  // <https://github.com/apache/pdfbox/blob/129aafe26548c1ff935af9c55cb40a996186c35f/pdfbox/src/main/java/org/apache/pdfbox/pdmodel/font/PDSimpleFont.java#L340>
  if name == ".notdef" {
    return Some(250.0)
  }
  let name = normalized_glyph_name(name)
  let table = match self {
    Helvetica => metrics_helvetica
    HelveticaBold => metrics_helvetica_bold
    HelveticaOblique => metrics_helvetica_oblique
    HelveticaBoldOblique => metrics_helvetica_bold_oblique
    Courier => metrics_courier
    CourierBold => metrics_courier_bold
    CourierOblique => metrics_courier_oblique
    CourierBoldOblique => metrics_courier_bold_oblique
    TimesRoman => metrics_times_roman
    TimesBold => metrics_times_bold
    TimesItalic => metrics_times_italic
    TimesBoldItalic => metrics_times_bold_italic
    ZapfDingBats => metrics_zapf_ding_bats
    Symbol => metrics_symbol
  }
  sorted_table_get(table, name)
}

///|
pub fn StandardFont::as_str(self : StandardFont) -> String {
  match self {
    Helvetica => "Helvetica"
    HelveticaBold => "Helvetica Bold"
    HelveticaOblique => "Helvetica Oblique"
    HelveticaBoldOblique => "Helvetica Bold Oblique"
    Courier => "Courier"
    CourierBold => "Courier Bold"
    CourierOblique => "Courier Oblique"
    CourierBoldOblique => "Courier Bold Oblique"
    TimesRoman => "Times Roman"
    TimesBold => "Times Bold"
    TimesItalic => "Times Italic"
    TimesBoldItalic => "Times Bold Italic"
    ZapfDingBats => "Zapf Dingbats"
    Symbol => "Symbol"
  }
}

///|
/// Return the postscrit name of the font.
pub fn StandardFont::postscript_name(self : StandardFont) -> String {
  match self {
    Helvetica => "Helvetica"
    HelveticaBold => "Helvetica-Bold"
    HelveticaOblique => "Helvetica-Oblique"
    HelveticaBoldOblique => "Helvetica-BoldOblique"
    Courier => "Courier"
    CourierBold => "Courier-Bold"
    CourierOblique => "Courier-Oblique"
    CourierBoldOblique => "Courier-BoldOblique"
    TimesRoman => "Times-Roman"
    TimesBold => "Times-Bold"
    TimesItalic => "Times-Italic"
    TimesBoldItalic => "Times-BoldItalic"
    ZapfDingBats => "ZapfDingbats"
    Symbol => "Symbol"
  }
}

///|
fn StandardFont::is_bold(self : StandardFont) -> Bool {
  self
  is (HelveticaBold
  | HelveticaBoldOblique
  | CourierBold
  | CourierBoldOblique
  | TimesBold
  | TimesBoldItalic)
}

///|
fn StandardFont::is_italic(self : StandardFont) -> Bool {
  self
  is (HelveticaOblique
  | HelveticaBoldOblique
  | CourierOblique
  | CourierBoldOblique
  | TimesItalic
  | TimesBoldItalic)
}

///|
fn StandardFont::is_serif(self : StandardFont) -> Bool {
  self is (TimesRoman | TimesBold | TimesItalic | TimesBoldItalic)
}

///|
fn StandardFont::is_monospace(self : StandardFont) -> Bool {
  self is (Courier | CourierBold | CourierOblique | CourierBoldOblique)
}

///|
priv enum StandardFontFamily {
  Helvetica
  Courier
  Times
}

///|
fn select_standard_font(
  dict : @hayro_syntax.Dict,
  descriptor : @hayro_syntax.Dict,
) -> (StandardFont, Bool)? {
  guard (dict.get("BaseFont") : @hayro_syntax.Name?) is Some(base_font) else {
    return None
  }
  let name = strip_subset_prefix(base_font.as_str())

  // First try whether it matches literally.
  match name {
    "Helvetica" => return Some((Helvetica, true))
    "Helvetica-Bold" => return Some((HelveticaBold, true))
    "Helvetica-Oblique" => return Some((HelveticaOblique, true))
    "Helvetica-BoldOblique" => return Some((HelveticaBoldOblique, true))
    "Courier" => return Some((Courier, true))
    "Courier-Bold" => return Some((CourierBold, true))
    "Courier-Oblique" => return Some((CourierOblique, true))
    "Courier-BoldOblique" => return Some((CourierBoldOblique, true))
    "Times-Roman" => return Some((TimesRoman, true))
    "Times-Bold" => return Some((TimesBold, true))
    "Times-Italic" => return Some((TimesItalic, true))
    "Times-BoldItalic" => return Some((TimesBoldItalic, true))
    "Symbol" => return Some((Symbol, true))
    "ZapfDingbats" => return Some((ZapfDingBats, true))
    _ => ()
  }

  // Now, we bruteforce, trying to determine a suitable font based on the
  // keywords that appear in the name.
  let lower = ascii_lowercase(name)
  let is_bold = ((descriptor.get("FontWeight") : UInt?) is Some(w) && w >= 700) ||
    lower.contains("bold") ||
    lower.contains("demi")
  let is_italic = (
      (descriptor.get("ItalicAngle") : Float?) is Some(a) && a != 0.0
    ) ||
    lower.contains("italic") ||
    lower.contains("oblique")
  let (family, _exact) : (StandardFontFamily?, Bool) = if lower.contains(
      "helvetica",
    ) {
    (Some(Helvetica), true)
  } else if lower.contains("arial") || lower.contains("sans") {
    (Some(Helvetica), false)
  } else if lower.contains("courier") {
    (Some(Courier), true)
  } else if lower.contains("mono") {
    (Some(Courier), false)
  } else if lower.contains("times") {
    (Some(Times), true)
  } else if lower.contains("serif") {
    (Some(Times), false)
  } else if lower.contains("zapfdingbats") || lower.contains("dingbats") {
    return Some((ZapfDingBats, false))
  } else {
    (None, false)
  }
  guard family is Some(family) else { return None }
  let font : StandardFont = match (family, is_bold, is_italic) {
    (Helvetica, false, false) => Helvetica
    (Helvetica, true, false) => HelveticaBold
    (Helvetica, false, true) => HelveticaOblique
    (Helvetica, true, true) => HelveticaBoldOblique
    (Courier, false, false) => Courier
    (Courier, true, false) => CourierBold
    (Courier, false, true) => CourierOblique
    (Courier, true, true) => CourierBoldOblique
    (Times, false, false) => TimesRoman
    (Times, true, false) => TimesBold
    (Times, false, true) => TimesItalic
    (Times, true, true) => TimesBoldItalic
  }
  Some((font, _exact))
}

///|
/// Rust's `str::to_ascii_lowercase`.
fn ascii_lowercase(s : String) -> String {
  let buf = StringBuilder()
  for c in s {
    if c >= 'A' && c <= 'Z' {
      buf.write_char(Int::unsafe_to_char(c.to_int() + 32))
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
priv enum StandardFontBlob {
  Cff(CffFontBlob)
  Otf(OpenTypeFontBlob, Map[String, GlyphId])
}

///|
fn StandardFontBlob::from_data(data : Bytes, index : Int) -> StandardFontBlob? {
  if CffFontBlob::new(data) is Some(blob) {
    Some(StandardFontBlob::new_cff(blob))
  } else {
    match OpenTypeFontBlob::new(data, index) {
      Some(blob) => Some(StandardFontBlob::new_otf(blob))
      None => None
    }
  }
}

///|
fn StandardFontBlob::new_cff(blob : CffFontBlob) -> StandardFontBlob {
  Cff(blob)
}

///|
fn StandardFontBlob::new_otf(blob : OpenTypeFontBlob) -> StandardFontBlob {
  let glyph_names = blob.glyph_names()
  Otf(blob, glyph_names)
}

///|
fn StandardFontBlob::name_to_glyph(
  self : StandardFontBlob,
  name : String,
) -> GlyphId? {
  match self {
    Cff(blob) => blob.glyph_index_by_name(name)
    Otf(_, glyph_names) => glyph_names.get(name)
  }
}

///|
fn StandardFontBlob::unicode_to_glyph(
  self : StandardFontBlob,
  code : UInt,
) -> GlyphId? {
  match self {
    Cff(_) => None
    Otf(blob, _) => blob.map_codepoint(code)
  }
}

///|
fn StandardFontBlob::advance_width(
  self : StandardFontBlob,
  glyph : GlyphId,
) -> Float? {
  match self {
    Cff(_) => None
    Otf(blob, _) => blob.advance_width(glyph)
  }
}

///|
fn StandardFontBlob::outline_glyph(
  self : StandardFontBlob,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  // Standard fonts have empty outlines for these, but in Liberation Sans
  // they are a .notdef rectangle.
  if glyph == glyph_id_notdef {
    return @kurbo.BezPath::new()
  }
  match self {
    Cff(blob) => blob.outline_glyph(glyph)
    Otf(blob, _) => blob.outline_glyph(glyph)
  }
}

///|
priv struct StandardKind {
  base_font : StandardFont
  base_font_blob : StandardFontBlob
  encoding : Encoding
  widths : Array[Width]
  missing_width : Float
  fallback : Bool
  glyph_to_code : Map[UInt, Byte]
  encodings : Map[Int, String]
}

///|
fn StandardKind::new(
  dict : @hayro_syntax.Dict,
  resolver : FontResolverFn,
) -> StandardKind? {
  let descriptor = (dict.get("FontDescriptor") : @hayro_syntax.Dict?).unwrap_or(
    @hayro_syntax.Dict::empty(),
  )
  guard select_standard_font(dict, descriptor) is Some((font, exact)) else {
    return None
  }
  StandardKind::new_with_standard(dict, font, !exact, resolver)
}

///|
fn StandardKind::new_with_standard(
  dict : @hayro_syntax.Dict,
  base_font : StandardFont,
  fallback : Bool,
  resolver : FontResolverFn,
) -> StandardKind? {
  let descriptor = (dict.get("FontDescriptor") : @hayro_syntax.Dict?).unwrap_or(
    @hayro_syntax.Dict::empty(),
  )
  guard read_widths(dict, descriptor) is Some((widths, missing_width)) else {
    return None
  }
  let (encoding, encoding_map) = read_encoding(dict)

  // See PDFJS-16464: Ignore encodings for non-embedded Type1 symbol fonts.
  let encoding = if base_font is (Symbol | ZapfDingBats) {
    BuiltIn
  } else {
    encoding
  }
  guard resolver(Standard(base_font)) is Some((blob, index)) else {
    return None
  }
  guard StandardFontBlob::from_data(blob, index) is Some(base_font_blob) else {
    return None
  }
  Some({
    base_font,
    base_font_blob,
    widths,
    missing_width,
    encodings: encoding_map,
    glyph_to_code: {},
    fallback,
    encoding,
  })
}

///|
fn StandardKind::code_to_ps_name(self : StandardKind, code : Byte) -> String? {
  let bf = self.base_font
  match self.encodings.get(code.to_int()) {
    Some(s) => Some(s)
    None =>
      match self.encoding {
        BuiltIn => bf.code_to_name(code)
        _ => self.encoding.map_code(code)
      }
  }
}

///|
fn StandardKind::map_code(self : StandardKind, code : Byte) -> GlyphId {
  let result = match self.code_to_ps_name(code) {
    Some(c) =>
      match self.base_font_blob.name_to_glyph(c) {
        Some(g) => g
        None =>
          // If the font doesn't have a POST table, try to map via unicode instead.
          match glyph_names_get(c) {
            Some(u) =>
              match u.iter().next() {
                Some(ch) =>
                  self.base_font_blob
                  .unicode_to_glyph(ch.to_uint())
                  .unwrap_or(glyph_id_notdef)
                None => glyph_id_notdef
              }
            None => glyph_id_notdef
          }
      }
    None => glyph_id_notdef
  }
  self.glyph_to_code[result.to_u32()] = code
  result
}

///|
fn StandardKind::outline_glyph(
  self : StandardKind,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  let path = self.base_font_blob.outline_glyph(glyph)

  // If the font is not embedded, we might need to stretch it so that
  // it matches the metrics of the actual underlying font blob.
  guard self.glyph_to_code.get(glyph.to_u32()) is Some(code) else {
    return path
  }
  let actual_width = match self.base_font_blob.advance_width(glyph) {
    Some(w) => Some(w)
    None =>
      match self.code_to_ps_name(code) {
        Some(name) => self.base_font.get_width(name)
        None => None
      }
  }
  guard actual_width is Some(actual_width) else { return path }

  // From my experiments: Most PDF viewers, if they detect a font is a
  // standard font, they completely ignore the widths array, even if
  // different widths are indicated there. So only if it's an unknown
  // font do we check the widths array. Otherwise, we always use the
  // base font metrics.
  let should_width = if self.fallback {
    if self.widths.get(code.to_int()) is Some(Value(w)) {
      w
    } else {
      return path
    }
  } else {
    match self.code_to_ps_name(code) {
      Some(name) =>
        match self.base_font.get_width(name) {
          Some(w) => w
          None => return path
        }
      None => return path
    }
  }
  stretch_glyph(path, should_width, actual_width)
}

///|
fn StandardKind::glyph_width(self : StandardKind, code : Byte) -> Float? {
  match self.widths.get(code.to_int()) {
    Some(Value(w)) => Some(w)
    Some(Missing) => Some(self.missing_width)
    None =>
      match self.code_to_ps_name(code) {
        Some(c) => self.base_font.get_width(c)
        None => None
      }
  }
}

///|
fn StandardKind::char_code_to_unicode(
  self : StandardKind,
  code : Byte,
) -> Char? {
  match self.code_to_ps_name(code) {
    Some(name) => glyph_name_to_unicode(name)
    None => None
  }
}

///|
fn StandardKind::is_italic(self : StandardKind) -> Bool {
  self.base_font.is_italic()
}

///|
fn StandardKind::is_bold(self : StandardKind) -> Bool {
  self.base_font.is_bold()
}

///|
fn StandardKind::is_serif(self : StandardKind) -> Bool {
  self.base_font.is_serif()
}

///|
fn StandardKind::is_monospace(self : StandardKind) -> Bool {
  self.base_font.is_monospace()
}
