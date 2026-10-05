// Port of `typst-library/src/text/font/book.rs`.

///|
/// Metadata about a collection of fonts.
pub struct FontBook {
  /// Maps from lowercased family names to font indices.
  priv families : Map[String, Array[Int]]
  /// Metadata about each font in the collection.
  priv infos : Array[FontInfo]
  /// Memoized [FontBook::select] results (not upstream; cleared by `push`).
  priv selected : Map[(String, FontVariant), Int?]
  /// Memoized indices of the fonts covering a char (not upstream; cleared by
  /// `push`).
  priv covering : Map[Int, Array[Int]]
}

///|
/// Create a new, empty font book.
pub fn FontBook::new() -> FontBook {
  { families: {}, infos: [], selected: {}, covering: {}, }
}

///|
pub impl Default for FontBook with fn default() {
  FontBook::new()
}

///|
/// Create a font book from a collection of font infos.
pub fn FontBook::from_infos(infos : Array[FontInfo]) -> FontBook {
  let book = FontBook::new()
  for info in infos {
    book.push(info)
  }
  book
}

///|
/// Create a font book for a collection of fonts.
pub fn FontBook::from_fonts(fonts : Array[Font]) -> FontBook {
  FontBook::from_infos(fonts.map(font => font.info()))
}

///|
/// Insert metadata into the font book.
pub fn FontBook::push(self : FontBook, info : FontInfo) -> Unit {
  self.selected.clear()
  self.covering.clear()
  let index = self.infos.length()
  let family = @unicode.to_lowercase(info.family)
  match self.families.get(family) {
    Some(ids) => ids.push(index)
    None => self.families[family] = [index]
  }
  self.infos.push(info)
}

///|
/// Get the font info for the given index.
pub fn FontBook::info(self : FontBook, index : Int) -> FontInfo? {
  self.infos.get(index)
}

///|
/// The number of fonts in the book.
pub fn FontBook::len(self : FontBook) -> Int {
  self.infos.length()
}

///|
/// Returns true if the book contains a font family with the given name.
pub fn FontBook::contains_family(self : FontBook, family : String) -> Bool {
  self.families.contains(family)
}

///|
/// An ordered iterator over all font families this book knows and the
/// font indices that belong to them.
pub fn FontBook::families(self : FontBook) -> Array[(String, Array[Int])] {
  // The keys are ordered like Rust's `BTreeMap<String, _>`.
  let keys = self.families.keys().to_array()
  keys.sort_by(compare_str)
  // Since the keys are lowercased, we instead use the family field of the
  // first face's info.
  keys.map(key => {
    let ids = self.families.get(key).unwrap()
    (self.infos[ids[0]].family, ids)
  })
}

///|
/// Try to find a font from the given `family` that matches the given
/// `variant` as closely as possible.
///
/// The `family` should be all lowercase.
pub fn FontBook::select(
  self : FontBook,
  family : String,
  variant : FontVariant,
) -> Int? {
  let key = (family, variant)
  if self.selected.get(key) is Some(selected) {
    return selected
  }
  let selected = match self.families.get(family) {
    Some(ids) => self.find_best_variant(None, variant, ids)
    None => None
  }
  self.selected[key] = selected
  selected
}

///|
/// Iterate over all variants of a family.
pub fn FontBook::select_family(self : FontBook, family : String) -> Array[Int] {
  self.families.get(family).unwrap_or([])
}

///|
/// Try to find and load a fallback font that
/// - is as close as possible to the font `like` (if any)
/// - is as close as possible to the given `variant`
/// - is suitable for shaping the given `text`
pub fn FontBook::select_fallback(
  self : FontBook,
  like : FontInfo?,
  variant : FontVariant,
  text : StringView,
) -> Int? {
  // Find the fonts that contain the text's first non-space and
  // non-ignorable char ...
  let mut c : Char? = None
  for ch in text {
    if !@unicode.is_whitespace(ch) && !@unicode.is_default_ignorable(ch) {
      c = Some(ch)
      break
    }
  }
  guard c is Some(c) else { return None }
  let ids = match self.covering.get(c.to_int()) {
    Some(ids) => ids
    None => {
      let ids = []
      for index, info in self.infos {
        if info.coverage.contains(c.to_int().reinterpret_as_uint()) {
          ids.push(index)
        }
      }
      self.covering[c.to_int()] = ids
      ids
    }
  }
  // ... and find the best variant among them.
  self.find_best_variant(like, variant, ids)
}

///|
/// The score used to rank font variants (compared lexicographically).
priv struct VariantScore {
  /// `like.map(|like| similarity(current, like))`.
  similarity : (Bool, Bool, Int, Int)?
  /// `Reverse(distance(current, variant))`.
  distance : (Int, Ratio, Int)
  /// Whether the font is variable.
  variable : Bool
}

///|
/// Rust's tuple/`Option`/`Reverse` ordering of a [VariantScore].
fn VariantScore::compare(self : VariantScore, other : VariantScore) -> Int {
  let c = match (self.similarity, other.similarity) {
    (None, None) => 0
    (None, Some(_)) => -1
    (Some(_), None) => 1
    (Some(a), Some(b)) => {
      let c = a.0.compare(b.0)
      if c != 0 {
        c
      } else {
        let c = a.1.compare(b.1)
        if c != 0 {
          c
        } else {
          let c = a.2.compare(b.2)
          if c != 0 {
            c
          } else {
            // `Reverse(left.family.len())`
            b.3.compare(a.3)
          }
        }
      }
    }
  }
  if c != 0 {
    return c
  }
  // `Reverse(distance)`.
  let (a0, a1, a2) = self.distance
  let (b0, b1, b2) = other.distance
  let c = b0.compare(a0)
  if c != 0 {
    return c
  }
  let c = b1.compare(a1)
  if c != 0 {
    return c
  }
  let c = b2.compare(a2)
  if c != 0 {
    return c
  }
  self.variable.compare(other.variable)
}

///|
/// Find the font in the passed iterator that
/// - is closest to the font `like` (if any), and
/// - is closest to the given `variant`
///
/// To do that we compute a score for all variants and select the one with the
/// higher score. This score prioritizes:
/// - If `like` is some other font:
///   - Are both fonts monospaced?
///   - Do both fonts have serifs?
///   - How many words do the families share in their prefix? E.g. "Noto
///     Sans" and "Noto Sans Arabic" share two words, whereas "IBM Plex
///     Arabic" shares none with "Noto Sans", so prefer "Noto Sans Arabic"
///     if `like` is "Noto Sans". In case there are two equally good
///     matches, we prefer the shorter one because it is less special (e.g.
///     if `like` is "Noto Sans Arabic", we prefer "Noto Sans" over "Noto
///     Sans CJK HK".)
/// - The style (normal / italic / oblique). If we want italic or oblique
///   but it doesn't exist, the other one of the two is still better than
///   normal.
/// - The absolute distance to the target stretch.
/// - The absolute distance to the target weight.
/// - All else being equal, we prefer variable fonts over static ones.
fn FontBook::find_best_variant(
  self : FontBook,
  like : FontInfo?,
  variant : FontVariant,
  ids : Array[Int],
) -> Int? {
  let mut best : Int? = None
  let mut best_score : VariantScore? = None
  for id in ids {
    let current = self.infos[id]
    let score : VariantScore = {
      similarity: like.map(like => similarity(current, like)),
      distance: distance(current, variant),
      variable: current.flags.contains(font_flags_variable),
    }
    let better = match best_score {
      None => true
      Some(b) => score.compare(b) > 0
    }
    if better {
      best = Some(id)
      best_score = Some(score)
    }
  }
  best
}

///|
/// Determines a metric that scores higher if `other` is similar to `self`.
/// This is used to pick a closely matching face during font fallback.
fn similarity(left : FontInfo, right : FontInfo) -> (Bool, Bool, Int, Int) {
  (
    // Most importantly, we want a font of a similar kind (monospace,
    // serif, etc.).
    left.flags.contains(font_flags_monospace) ==
    right.flags.contains(font_flags_monospace),
    left.flags.contains(font_flags_serif) ==
    right.flags.contains(font_flags_serif),
    // We prefer fonts that have more words shared in their name. E.g.
    // "Noto Sans" and "Noto Sans Arabic" share two words, whereas "IBM
    // Plex Arabic" shares none with "Noto Sans", so prefer "Noto Sans
    // Arabic" if `like` is "Noto Sans".
    shared_prefix_words(left.family, right.family),
    // In case there are two equally good matches, we prefer the shorter
    // one because it is less special (e.g. if `like` is "Noto Sans
    // Arabic", we prefer "Noto Sans" over "Noto Sans CJK HK".)
    @syntax.utf8_len(left.family),
  )
}

///|
/// Determines a distance metric from the given variant to
/// - this font's variant (if static)
/// - this font's closest instance (if variable)
///
/// Used to pick the most suitable font in a family.
fn distance(info : FontInfo, variant : FontVariant) -> (Int, Ratio, Int) {
  // TODO: Potentially also consider optical size for the distance
  // computation. However, this would ideally also apply to non-variable
  // font and there are different mechanisms with which these advertise
  // their intended optical size range.
  let axes = StandardAxes::parse(info.axes)
  let style_distance = {
    let mut dist = info.variant.style.distance(variant.style)
    if axes.ital is Some(_) {
      dist = @cmp.minimum(dist, FontStyle::Italic.distance(variant.style))
    }
    if axes.slnt is Some(_) {
      dist = @cmp.minimum(dist, FontStyle::Oblique.distance(variant.style))
    }
    dist
  }
  let stretch_distance = match axes.wdth {
    Some(axis) =>
      axis.distance(
        variant.stretch,
        FontStretch::from_wdth,
        FontStretch::distance,
      )
    None => info.variant.stretch.distance(variant.stretch)
  }
  let weight_distance = match axes.wght {
    Some(axis) =>
      axis.distance(variant.weight, FontWeight::from_wght, FontWeight::distance)
    None => info.variant.weight.distance(variant.weight)
  }
  (style_distance, stretch_distance, weight_distance)
}

///|
/// How many words the two strings share in their prefix.
fn shared_prefix_words(left : String, right : String) -> Int {
  let l = unicode_words(left)
  let r = unicode_words(right)
  let mut n = 0
  while n < l.length() && n < r.length() && l[n] == r[n] {
    n += 1
  }
  n
}

///|
/// The words of a string (`unicode-segmentation`'s `unicode_words`).
///
/// TODO: This implements the UAX #29 word rules for ASCII text (letters,
/// digits, `_`, and the mid-word punctuation `.`, `'`, `:`, `,`, `;`); other
/// alphanumeric characters are treated as letters. A full port needs the
/// `Word_Break` property table in `unicode/`.
fn unicode_words(s : String) -> Array[String] {
  let chars = s.to_array()
  let n = chars.length()
  let kind = (c : Char) => {
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      1 // ALetter
    } else if c >= '0' && c <= '9' {
      2 // Numeric
    } else if c == '_' {
      3 // ExtendNumLet
    } else if c == ':' {
      4 // MidLetter
    } else if c == '.' || c == '\'' {
      5 // MidNumLet / Single_Quote
    } else if c == ',' || c == ';' {
      6 // MidNum
    } else if c.to_int() > 0x7f && @unicode.is_alphanumeric(c) {
      1
    } else {
      0 // Other
    }
  }
  let words = []
  let mut i = 0
  while i < n {
    let start = i
    let k = kind(chars[i])
    if k == 1 || k == 2 || k == 3 {
      i += 1
      while i < n {
        let prev = kind(chars[i - 1])
        let cur = kind(chars[i])
        if cur == 1 || cur == 2 || cur == 3 {
          i += 1
          continue
        }
        // WB6/7 and WB11/12: letters/numbers joined by mid punctuation.
        if i + 1 < n {
          let next = kind(chars[i + 1])
          if prev == 1 && next == 1 && (cur == 4 || cur == 5) {
            i += 2
            continue
          }
          if prev == 2 && next == 2 && (cur == 5 || cur == 6) {
            i += 2
            continue
          }
        }
        break
      }
      let word = String::from_array(chars[start:i].to_owned())
      if word.iter().any(c => @unicode.is_alphanumeric(c)) {
        words.push(word)
      }
    } else {
      i += 1
    }
  }
  words
}
