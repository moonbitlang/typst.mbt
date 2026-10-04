// A [PostScript Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/post) implementation.

///|
let post_italic_angle_offset : Int = 4

///|
let post_underline_position_offset : Int = 8

///|
let post_underline_thickness_offset : Int = 10

///|
let post_is_fixed_pitch_offset : Int = 12

///|
/// An iterator over glyph names.
///
/// The `post` table doesn't provide the glyph names count,
/// so we have to simply iterate over all of them to find it out.
pub struct PostNames {
  data : BytesView
  mut offset : Int
}

///|
/// Returns the next glyph name.
pub fn PostNames::next(self : PostNames) -> String? {
  // Glyph names are stored as Pascal Strings.
  // Meaning u8 (len) + [u8] (data).
  if self.offset >= self.data.length() {
    return None
  }
  let len = self.data[self.offset].to_int()
  self.offset += 1

  // An empty name is an error.
  if len == 0 {
    return None
  }
  guard slice_get(self.data, self.offset, self.offset + len) is Some(name) else {
    return None
  }
  self.offset += len
  utf8_to_string(name)
}

///|
/// Decodes UTF-8 bytes (`core::str::from_utf8`), `None` if invalid.
pub fn utf8_to_string(data : BytesView) -> String? {
  try @utf8.decode(data, ignore_bom=false) catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
/// A [PostScript Table](https://docs.microsoft.com/en-us/typography/opentype/spec/post).
pub struct PostTable {
  /// Italic angle in counter-clockwise degrees from the vertical.
  italic_angle : Float
  /// Underline metrics.
  underline_metrics : LineMetrics
  /// Flag that indicates that the font is monospaced.
  is_monospaced : Bool
  glyph_indexes : LazyArray16[UInt16]
  names_data : BytesView
}

///|
/// Parses a table from raw data.
pub fn PostTable::parse(data : BytesView) -> PostTable? {
  // Do not check the exact length, because some fonts include
  // padding in table's length in table records, which is incorrect.
  if data.length() < 32 {
    return None
  }
  try {
    let version = Stream::new(data).read_u32()
    if !(version == 0x00010000 ||
      version == 0x00020000 ||
      version == 0x00025000 ||
      version == 0x00030000 ||
      version == 0x00040000) {
      return None
    }
    let italic_angle = (Stream::read_at(data, post_italic_angle_offset) : Fixed).0
    let underline_metrics : LineMetrics = {
      position: Stream::read_at(data, post_underline_position_offset),
      thickness: Stream::read_at(data, post_underline_thickness_offset),
    }
    let is_monospaced = (
        Stream::read_at(data, post_is_fixed_pitch_offset) : UInt) !=
      0
    let mut names_data = empty_data
    let mut glyph_indexes = LazyArray16::default()

    // Only version 2.0 of the table has data at the end.
    if version == 0x00020000 {
      let s = Stream::new_at_r(data, 32)
      let indexes_count = s.read_u16()
      glyph_indexes = s.read_array16(indexes_count)
      names_data = s.tail_r()
    }
    Some({
      italic_angle,
      underline_metrics,
      is_monospaced,
      names_data,
      glyph_indexes,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph name by ID.
pub fn PostTable::glyph_name(self : PostTable, glyph_id : GlyphId) -> String? {
  guard self.glyph_indexes.get(glyph_id.0) is Some(index) else { return None }
  let index = index.to_int()
  // 'If the name index is between 0 and 257, treat the name index
  // as a glyph index in the Macintosh standard order.'
  if index < macintosh_names.length() {
    Some(macintosh_names[index])
  } else {
    // 'If the name index is between 258 and 65535, then subtract 258 and use that
    // to index into the list of Pascal strings at the end of the table.'
    let mut index = index - macintosh_names.length()
    let names = self.names()
    while names.next() is Some(name) {
      if index == 0 {
        return Some(name)
      }
      index -= 1
    }
    None
  }
}

///|
/// Returns a glyph ID by a name.
pub fn PostTable::glyph_index_by_name(
  self : PostTable,
  name : String,
) -> GlyphId? {
  let index = match macintosh_names.search(name) {
    Some(index) => index
    None => {
      let names = self.names()
      let mut i = 0
      let mut found = None
      while names.next() is Some(n) {
        if n == name {
          found = Some(i)
          break
        }
        i += 1
      }
      guard found is Some(index) else { return None }
      index + macintosh_names.length()
    }
  }
  let mut id = 0
  for i in self.glyph_indexes.iter() {
    if i.to_int() == index {
      return Some(GlyphId(id.to_uint16()))
    }
    id += 1
  }
  None
}

///|
/// Returns an iterator over glyph names.
///
/// Default/predefined names are not included. Just the one in the font file.
pub fn PostTable::names(self : PostTable) -> PostNames {
  { data: self.names_data, offset: 0, }
}

///|
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6post.html

///|
/// A list of Macintosh glyph names.
let macintosh_names : ReadOnlyArray[String] = [
  ".notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl", "numbersign",
  "dollar", "percent", "ampersand", "quotesingle", "parenleft", "parenright", "asterisk",
  "plus", "comma", "hyphen", "period", "slash", "zero", "one", "two", "three", "four",
  "five", "six", "seven", "eight", "nine", "colon", "semicolon", "less", "equal",
  "greater", "question", "at", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
  "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "bracketleft", "backslash", "bracketright", "asciicircum", "underscore", "grave",
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
  "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar", "braceright",
  "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute", "Ntilde", "Odieresis",
  "Udieresis", "aacute", "agrave", "acircumflex", "adieresis", "atilde", "aring",
  "ccedilla", "eacute", "egrave", "ecircumflex", "edieresis", "iacute", "igrave",
  "icircumflex", "idieresis", "ntilde", "oacute", "ograve", "ocircumflex", "odieresis",
  "otilde", "uacute", "ugrave", "ucircumflex", "udieresis", "dagger", "degree", "cent",
  "sterling", "section", "bullet", "paragraph", "germandbls", "registered", "copyright",
  "trademark", "acute", "dieresis", "notequal", "AE", "Oslash", "infinity", "plusminus",
  "lessequal", "greaterequal", "yen", "mu", "partialdiff", "summation", "product",
  "pi", "integral", "ordfeminine", "ordmasculine", "Omega", "ae", "oslash", "questiondown",
  "exclamdown", "logicalnot", "radical", "florin", "approxequal", "Delta", "guillemotleft",
  "guillemotright", "ellipsis", "nonbreakingspace", "Agrave", "Atilde", "Otilde",
  "OE", "oe", "endash", "emdash", "quotedblleft", "quotedblright", "quoteleft", "quoteright",
  "divide", "lozenge", "ydieresis", "Ydieresis", "fraction", "currency", "guilsinglleft",
  "guilsinglright", "fi", "fl", "daggerdbl", "periodcentered", "quotesinglbase",
  "quotedblbase", "perthousand", "Acircumflex", "Ecircumflex", "Aacute", "Edieresis",
  "Egrave", "Iacute", "Icircumflex", "Idieresis", "Igrave", "Oacute", "Ocircumflex",
  "apple", "Ograve", "Uacute", "Ucircumflex", "Ugrave", "dotlessi", "circumflex",
  "tilde", "macron", "breve", "dotaccent", "ring", "cedilla", "hungarumlaut", "ogonek",
  "caron", "Lslash", "lslash", "Scaron", "scaron", "Zcaron", "zcaron", "brokenbar",
  "Eth", "eth", "Yacute", "yacute", "Thorn", "thorn", "minus", "multiply", "onesuperior",
  "twosuperior", "threesuperior", "onehalf", "onequarter", "threequarters", "franc",
  "Gbreve", "gbreve", "Idotaccent", "Scedilla", "scedilla", "Cacute", "cacute", "Ccaron",
  "ccaron", "dcroat",
]
