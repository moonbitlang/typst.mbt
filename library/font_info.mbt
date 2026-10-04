// Port of `typst-library/src/text/font/info.rs` and `exceptions.rs` (the
// table itself is generated into font_exceptions_gen.mbt).

///|
/// Properties of a single font.
pub(all) struct FontInfo {
  /// The typographic font family this font is part of.
  family : String
  /// Properties that distinguish this font from other fonts in the same
  /// family. For a variable font, this designates the default instance.
  variant : FontVariant
  /// Properties of the font.
  flags : FontFlags
  /// Variation axes this font supports.
  axes : Array[FontAxis]
  /// The unicode coverage of the font.
  coverage : Coverage
} derive(Eq, Hash)

///|
/// Bitflags describing characteristics of a font.
pub(all) struct FontFlags(UInt) derive(Eq, Hash, Debug)

///|
/// All glyphs have the same width.
pub let font_flags_monospace : FontFlags = FontFlags(1U << 0)

///|
/// Glyphs have short strokes at their stems.
pub let font_flags_serif : FontFlags = FontFlags(1U << 1)

///|
/// Font face has a MATH table
pub let font_flags_math : FontFlags = FontFlags(1U << 2)

///|
/// Font face has an fvar table
pub let font_flags_variable : FontFlags = FontFlags(1U << 3)

///|
pub fn FontFlags::empty() -> FontFlags {
  FontFlags(0)
}

///|
pub fn FontFlags::contains(self : FontFlags, other : FontFlags) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn FontFlags::set(
  self : FontFlags,
  other : FontFlags,
  value : Bool,
) -> FontFlags {
  if value {
    FontFlags(self.0 | other.0)
  } else {
    FontFlags(self.0 & other.0.lnot())
  }
}

///|
/// Upstream bitflags `Debug`: `FontFlags(MONOSPACE | SERIF)`, `FontFlags(0x0)`.
pub impl Show for FontFlags with fn output(self, logger) {
  let names = []
  if self.contains(font_flags_monospace) {
    names.push("MONOSPACE")
  }
  if self.contains(font_flags_serif) {
    names.push("SERIF")
  }
  if self.contains(font_flags_math) {
    names.push("MATH")
  }
  if self.contains(font_flags_variable) {
    names.push("VARIABLE")
  }
  if names.is_empty() {
    logger.write_string("FontFlags(0x0)")
  } else {
    logger.write_string("FontFlags(" + names.join(" | ") + ")")
  }
}

///|
/// Compute metadata for font at the `index` of the given data.
pub fn FontInfo::new(data : Bytes, index : UInt) -> FontInfo? {
  let ttf = @otf.Face::parse(data[:], index) catch { _ => return None }
  FontInfo::from_ttf(ttf)
}

///|
/// Compute metadata for all fonts in the given data.
pub fn FontInfo::iter(data : Bytes) -> Array[FontInfo] {
  let count = @otf.fonts_in_collection(data[:]).unwrap_or(1)
  let out = []
  for index in 0U..<count {
    if FontInfo::new(data, index) is Some(info) {
      out.push(info)
    }
  }
  out
}

///|
/// Compute metadata for a single ttf-parser face.
pub fn FontInfo::from_ttf(ttf : @otf.Face) -> FontInfo? {
  let ps_name = find_name(ttf, @otf.name_id_post_script_name)
  let exception = match ps_name {
    Some(name) => find_exception(name)
    None => None
  }
  // We cannot use Name ID 16 "Typographic Family", because for some
  // fonts it groups together more than just Style / Weight / Stretch
  // variants (e.g. Display variants of Noto fonts) and then some
  // variants become inaccessible from Typst. And even though the
  // fsSelection bit WWS should help us decide whether that is the
  // case, it's wrong for some fonts (e.g. for certain variants of "Noto
  // Sans Display").
  //
  // So, instead we use Name ID 1 "Family" and trim many common
  // suffixes for which know that they just describe styling (e.g.
  // "ExtraBold").
  let family = match exception {
    Some({ family: Some(family), .. }) => family
    _ => {
      guard find_name(ttf, @otf.name_id_family) is Some(family) else {
        return None
      }
      typographic_family(family)
    }
  }
  let variant = {
    let style = match exception {
      Some({ style: Some(style), .. }) => style
      _ => {
        let full = ascii_lowercase(
          find_name(ttf, @otf.name_id_full_name).unwrap_or(""),
        )

        // Some fonts miss the relevant bits for italic or oblique, so
        // we also try to infer that from the full name.
        //
        // We do not use `ttf.is_italic()` because that also checks the
        // italic angle which leads to false positives for some oblique
        // fonts.
        //
        // See <https://github.com/typst/typst/issues/7479>.
        let italic = ttf.style() == Italic || full.contains("italic")
        let oblique = ttf.is_oblique() ||
          full.contains("oblique") ||
          full.contains("slanted")
        match (italic, oblique) {
          (false, false) => FontStyle::Normal
          (true, _) => FontStyle::Italic
          (_, true) => FontStyle::Oblique
        }
      }
    }
    let weight = match exception {
      Some({ weight: Some(weight), .. }) => weight
      _ => {
        let number = ttf.weight().to_number()
        FontWeight::from_number(number.to_int())
      }
    }
    let stretch = match exception {
      Some({ stretch: Some(stretch), .. }) => stretch
      _ => FontStretch::from_number(ttf.width().to_number().to_int())
    }
    FontVariant::{ style, weight, stretch, }
  }

  // Determine the unicode coverage.
  let mut coverage = Coverage([])
  if ttf.tables().cmap is Some(cmap) {
    for subtable in cmap.subtables.iter() {
      if subtable.is_unicode() {
        let subtable_coverage = CoverageBuilder::with_capacity(
          coverage.0.length(),
        )
        // Ranges instead of single codepoints (performance; the same
        // coverage).
        subtable.codepoint_ranges(
          // We expect codepoints in CMAP subtables to be already sorted
          (start, end) => {
            subtable_coverage.add_codepoint_range(
              (start, if end == 0xFFFFFFFFU { end } else { end + 1 }),
            )
          },
        )
        coverage = coverage.union(subtable_coverage.build())
      }
    }
  }
  let mut flags = FontFlags::empty()
  flags = flags.set(font_flags_monospace, ttf.is_monospaced())
  flags = flags.set(font_flags_math, ttf.tables().math is Some(_))
  flags = flags.set(font_flags_variable, ttf.is_variable())

  // Determine whether this is a serif or sans-serif font.
  if ttf.raw_face().table(@otf.Tag::from_str("OS/2")) is Some(os2) &&
    os2.length() >= 45 {
    let panose = os2[32:45]
    if panose[0] == 2 && panose[1] >= 2 && panose[1] <= 10 {
      flags = flags.set(font_flags_serif, true)
    }
  }
  let axes = ttf
    .variation_axes()
    .iter()
    .map(axis => FontAxis::{
      tag: OpenTypeTag::from_bytes_lossy(axis.tag.to_string()),
      min: AxisValue::new(axis.min_value),
      max: AxisValue::new(axis.max_value),
      default: AxisValue::new(axis.def_value),
    })
    .to_array()
  Some({ family, variant, flags, axes, coverage, })
}

///|
/// Whether this is the macOS LastResort font. It can yield tofus with
/// glyph ID != 0.
pub fn FontInfo::is_last_resort(self : FontInfo) -> Bool {
  self.family == "LastResort"
}

///|
/// Upstream `Debug for FontInfo` (derived).
pub impl Show for FontInfo with fn output(self, logger) {
  let axes = self.axes
    .map(a => {
      "FontAxis { tag: Tag(\{a.tag.0}), min: AxisValue(\{rust_debug_f32(a.min.get())}), max: AxisValue(\{rust_debug_f32(a.max.get())}), default: AxisValue(\{rust_debug_f32(a.default.get())}) }"
    })
    .join(", ")
  logger.write_string(
    "FontInfo { family: \{@unicode.rust_debug_str(self.family)}, variant: \{self.variant}, flags: \{self.flags}, axes: [\{axes}], coverage: Coverage(..) }",
  )
}

///|
/// Rust's `Debug` for an `f32`.
fn rust_debug_f32(x : Float) -> String {
  rust_debug_f64(x.to_double())
}

///|
/// Try to find and decode the name with the given id.
pub fn find_name(ttf : @otf.Face, name_id : UInt16) -> String? {
  for entry in ttf.names().iter() {
    if entry.name_id == name_id {
      if entry.to_string() is Some(string) {
        return Some(string)
      }
      if entry.platform_id == Macintosh && entry.encoding_id == 0 {
        return Some(decode_mac_roman(entry.name))
      }
    }
  }
  None
}

///|
let mac_roman_table : Array[Char] = [
  'Ä', 'Å', 'Ç', 'É', 'Ñ', 'Ö', 'Ü', 'á', 'à', 'â', 'ä', 'ã', 'å', 'ç',
  'é', 'è', 'ê', 'ë', 'í', 'ì', 'î', 'ï', 'ñ', 'ó', 'ò', 'ô', 'ö', 'õ',
  'ú', 'ù', 'û', 'ü', '†', '°', '¢', '£', '§', '•', '¶', 'ß', '®',
  '©', '™', '´', '¨', '≠', 'Æ', 'Ø', '∞', '±', '≤', '≥', '¥', 'µ',
  '∂', '∑', '∏', 'π', '∫', 'ª', 'º', 'Ω', 'æ', 'ø', '¿', '¡', '¬',
  '√', 'ƒ', '≈', '∆', '«', '»', '…', '\u{a0}', 'À', 'Ã', 'Õ', 'Œ',
  'œ', '–', '—', '“', '”', '‘', '’', '÷', '◊', 'ÿ', 'Ÿ', '⁄',
  '€', '‹', '›', 'ﬁ', 'ﬂ', '‡', '·', '‚', '„', '‰', 'Â', 'Ê',
  'Á', 'Ë', 'È', 'Í', 'Î', 'Ï', 'Ì', 'Ó', 'Ô', '\u{f8ff}', 'Ò', 'Ú', 'Û',
  'Ù', 'ı', 'ˆ', '˜', '¯', '˘', '˙', '˚', '¸', '˝', '˛', 'ˇ',
]

///|
/// Decode mac roman encoded bytes into a string.
fn decode_mac_roman(coded : BytesView) -> String {
  let buf = StringBuilder::new()
  for code in coded {
    let code = code.to_int()
    buf.write_char(
      if code < 128 {
        code.unsafe_to_char()
      } else {
        mac_roman_table[code - 128]
      },
    )
  }
  buf.to_string()
}

///|
/// Trim style naming from a family name and fix bad names.
fn typographic_family(family : String) -> String {
  // Separators between names, modifiers and styles.
  let separators = [' ', '-', '_']

  // Modifiers that can appear in combination with suffixes.
  let modifiers = [
    "extra", "ext", "ex", "x", "semi", "sem", "sm", "demi", "dem", "ultra",
  ]

  // Style suffixes.
  let suffixes = [
    "normal", "italic", "oblique", "slanted", "thin", "th", "hairline", "light",
    "lt", "regular", "medium", "med", "md", "bold", "bd", "demi", "extb", "black",
    "blk", "bk", "heavy", "narrow", "condensed", "cond", "cn", "cd", "compressed",
    "expanded", "exp", "vf", "var", "variable",
  ]

  // Trim spacing and weird leading dots in Apple fonts.
  let family = rust_str_trim(family).to_owned()
  let mut start = 0
  while start < family.length() && family.code_unit_at(start) == '.' {
    start += 1
  }
  let family = family.unsafe_substring(start~, end=family.length())

  // Lowercase the string so that the suffixes match case-insensitively.
  let lower = ascii_lowercase(family)
  // Lengths are byte lengths upstream, but the lowercasing is ASCII-only, so
  // UTF-16 lengths of `lower` and `family` correspond to each other as well.
  let mut len = 0x7fffffff
  let mut trimmed = lower

  // Trim style suffixes repeatedly.
  while trimmed.length() < len {
    len = trimmed.length()

    // Find style suffix.
    let mut t = trimmed
    let mut shortened = false
    while suffixes.search_by(s => t.has_suffix(s)) is Some(i) {
      shortened = true
      t = t.unsafe_substring(start=0, end=t.length() - suffixes[i].length())
    }
    if !shortened {
      break
    }

    // Strip optional separator.
    if t.length() > 0 &&
      separators.contains(t.code_unit_at(t.length() - 1).unsafe_to_char()) {
      let s = t.unsafe_substring(start=0, end=t.length() - 1)
      trimmed = s
      t = s
    }

    // Also allow an extra modifier, but apply it only if it is separated it
    // from the text before it (to prevent false positives).
    if modifiers.search_by(s => t.has_suffix(s)) is Some(i) {
      let t = t.unsafe_substring(
        start=0,
        end=t.length() - modifiers[i].length(),
      )
      if t.length() > 0 &&
        separators.contains(t.code_unit_at(t.length() - 1).unsafe_to_char()) {
        trimmed = t.unsafe_substring(start=0, end=t.length() - 1)
      }
    }
  }

  // Apply style suffix trimming.
  family.unsafe_substring(start=0, end=len)
}

///|
/// Rust's `str::trim` (Unicode `White_Space`).
fn rust_str_trim(s : String) -> StringView {
  let mut start = 0
  let mut end = s.length()
  while start < end &&
        @unicode.is_whitespace(s.code_unit_at(start).unsafe_to_char()) {
    start += 1
  }
  while end > start &&
        @unicode.is_whitespace(s.code_unit_at(end - 1).unsafe_to_char()) {
    end -= 1
  }
  s[start:end]
}

///|
/// A compactly encoded set of codepoints.
///
/// The set is represented by alternating specifications of how many codepoints
/// are not in the set and how many are in the set.
///
/// For example, for the set `{2, 3, 4, 9, 10, 11, 15, 18, 19}`, there are:
/// - 2 codepoints not inside (0, 1)
/// - 3 codepoints inside (2, 3, 4)
/// - 4 codepoints not inside (5, 6, 7, 8)
/// - 3 codepoints inside (9, 10, 11)
/// - 3 codepoints not inside (12, 13, 14)
/// - 1 codepoint inside (15)
/// - 2 codepoints not inside (16, 17)
/// - 2 codepoints inside (18, 19)
///
/// So the resulting encoding is `[2, 3, 4, 3, 3, 1, 2, 2]`.
pub(all) struct Coverage(Array[UInt]) derive(Eq, Hash)

///|
pub impl Default for Coverage with fn default() {
  Coverage([])
}

///|
/// Encode a vector of codepoints.
pub fn Coverage::from_vec(codepoints : Array[UInt]) -> Coverage {
  let codepoints = codepoints.copy()
  codepoints.sort()
  codepoints.dedup()
  let builder = CoverageBuilder::with_capacity(0)
  for c in codepoints {
    builder.add_codepoint(c)
  }
  builder.build()
}

///|
/// Whether the codepoint is covered.
pub fn Coverage::contains(self : Coverage, c : UInt) -> Bool {
  let mut inside = false
  let mut cursor : UInt = 0
  for run in self.0 {
    if c >= cursor && c < cursor + run {
      return inside
    }
    cursor += run
    inside = !inside
  }
  false
}

///|
/// Iterate over all covered codepoints.
pub fn Coverage::iter(self : Coverage) -> Iter[UInt] {
  self
  .iter_ranges()
  .flat_map(r => {
    let (start, end) = r
    let out = []
    let mut c = start
    while c < end {
      out.push(c)
      c += 1
    }
    out.iter()
  })
}

///|
/// Iterate over all continuous ranges of covered codepoints.
fn Coverage::iter_ranges(self : Coverage) -> Iter[(UInt, UInt)] {
  let ranges = []
  let mut offset : UInt = 0
  let mut i = 0
  while i + 1 < self.0.length() {
    let gap = self.0[i]
    let count = self.0[i + 1]
    offset += gap
    let start = offset
    offset += count
    ranges.push((start, offset))
    i += 2
  }
  ranges.iter()
}

///|
/// Returns an encoding of the set of codepoints covered by either `self` or
/// `other`.
fn Coverage::union(self : Coverage, other : Coverage) -> Coverage {
  let capacity = if self.0.length() > other.0.length() {
    self.0.length()
  } else {
    other.0.length()
  }
  let builder = CoverageBuilder::with_capacity(capacity)
  let self_ranges = self.iter_ranges().to_array()
  let other_ranges = other.iter_ranges().to_array()
  let mut i = 0
  let mut j = 0
  while i < self_ranges.length() && j < other_ranges.length() {
    let self_range = self_ranges[i]
    let other_range = other_ranges[j]
    if self_range.0 < other_range.0 {
      builder.add_codepoint_range(self_range)
      i += 1
    } else {
      builder.add_codepoint_range(other_range)
      j += 1
    }
  }
  for k in i..<self_ranges.length() {
    builder.add_codepoint_range(self_ranges[k])
  }
  for k in j..<other_ranges.length() {
    builder.add_codepoint_range(other_ranges[k])
  }
  builder.build()
}

///|
pub impl Show for Coverage with fn output(_, logger) {
  logger.write_string("Coverage(..)")
}

///|
/// Incrementally builds a [`Coverage`] set from a non-decreasing series of
/// codepoints, or ranges thereof.
priv struct CoverageBuilder {
  runs : Array[UInt]
  mut next : UInt
}

///|
/// Create a new coverage builder with at least the given capacity.
fn CoverageBuilder::with_capacity(capacity : Int) -> CoverageBuilder {
  { runs: Array::new(capacity~), next: 0, }
}

///|
/// Build the [`Coverage`] set.
fn CoverageBuilder::build(self : CoverageBuilder) -> Coverage {
  Coverage(self.runs)
}

///|
/// Add a single codepoint to the set being built. Codepoints must be added
/// in a strictly increasing order.
fn CoverageBuilder::add_codepoint(
  self : CoverageBuilder,
  codepoint : UInt,
) -> Unit {
  let end = if codepoint == 0xFFFFFFFFU { codepoint } else { codepoint + 1 }
  self.add_codepoint_range((codepoint, end))
}

///|
/// Add a continuous range of codepoints to the set being built. Ranges must
/// be added in non-decreasing order of start codepoint, but may intersect
/// or be contained in previously added ranges.
fn CoverageBuilder::add_codepoint_range(
  self : CoverageBuilder,
  range : (UInt, UInt),
) -> Unit {
  let (start, end) = range
  if end <= self.next || start >= end {
    return
  } else if start <= self.next && self.runs.length() > 0 {
    let last = self.runs.length() - 1
    self.runs[last] = self.runs[last] + (end - self.next)
  } else {
    let gap = start - self.next
    let count = end - start
    self.runs.push(gap)
    self.runs.push(count)
  }
  self.next = end
}

///|
/// Rust's `str::to_ascii_lowercase`.
fn ascii_lowercase(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    buf.write_char(
      if c >= 'A' && c <= 'Z' {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      },
    )
  }
  buf.to_string()
}

// exceptions.rs

///|
/// An override for a font's metadata, keyed by PostScript name.
priv struct Exception {
  family : String?
  style : FontStyle?
  weight : FontWeight?
  stretch : FontStretch?
}

///|
fn find_exception(postscript_name : String) -> Exception? {
  exception_map.get(postscript_name)
}
