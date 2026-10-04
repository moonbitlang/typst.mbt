// Port of read-fonts 0.39.2 `src/tables/post.rs` and `generated_post.rs`.

///|
/// The [post](https://docs.microsoft.com/en-us/typography/opentype/spec/post) table.
pub struct Post {
  data : FontData
}

///|
pub fn FontRef::post(self : FontRef) -> Post raise ReadError {
  let data = self.expect_data_for_tag("post")
  if data.len() < 32 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Post::version(self : Post) -> Version16Dot16 {
  Version16Dot16(u32_at(self.data, 0))
}

///|
pub fn Post::italic_angle(self : Post) -> Fixed {
  Fixed::from_bits(self.data.read_i32(4)) catch {
    _ => Fixed::zero()
  }
}

///|
pub fn Post::underline_position(self : Post) -> Int {
  i16_at(self.data, 8)
}

///|
pub fn Post::underline_thickness(self : Post) -> Int {
  i16_at(self.data, 10)
}

///|
pub fn Post::is_fixed_pitch(self : Post) -> UInt {
  u32_at(self.data, 12)
}

///|
pub fn Post::num_glyphs(self : Post) -> Int? {
  if !self.version().compatible(2, 0) {
    return None
  }
  try self.data.read_u16(32) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// The glyph name indices (version 2.0 only).
pub fn Post::glyph_name_index(self : Post) -> Array[Int]? {
  if !self.version().compatible(2, 0) {
    return None
  }
  let num_glyphs = self.num_glyphs().unwrap_or(0)
  let arr = self.data.read_array(34, num_glyphs, 2) catch { _ => return None }
  Some([ for i in 0..<num_glyphs => u16_at(arr, i * 2) ])
}

///|
fn Post::string_data_start(self : Post) -> Int {
  let num_glyphs = self.num_glyphs().unwrap_or(0)
  34 + num_glyphs * 2
}

///|
/// The Pascal strings following the glyph name indices (version 2.0 only).
///
/// Each item is `Ok(name)` or an error if the string is not ASCII (like
/// iterating the upstream `VarLenArray<PString>`).
pub fn Post::string_data(self : Post) -> Array[Result[String, ReadError]]? {
  if !self.version().compatible(2, 0) {
    return None
  }
  let start = self.string_data_start()
  let len = self.data.len() - start
  if len <= 0 {
    // empty range
    return None
  }
  guard self.data.split_off(start) is Some(data) else { return None }
  let result = []
  let mut d = data.as_bytes()
  while d.length() != 0 {
    let item_len = d[0].to_int() + 1
    if item_len > d.length() {
      break
    }
    let item = d[1:item_len]
    let mut ascii = true
    for b in item {
      if b.to_int() >= 0x80 {
        ascii = false
      }
    }
    if ascii {
      let sb = StringBuilder()
      for b in item {
        sb.write_char(Int::unsafe_to_char(b.to_int()))
      }
      result.push(Ok(sb.to_string()))
    } else {
      result.push(Err(MalformedData("Must be valid ascii")))
    }
    d = d[item_len:]
  }
  Some(result)
}

///|
/// The 258 standard Macintosh glyph names.
pub let default_glyph_names : ReadOnlyArray[String] = [
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
