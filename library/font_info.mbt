// Port of `typst-library/src/text/font/info.rs` and `exceptions.rs` (the
// table itself is generated into font_exceptions_gen.mbt).
//
// Not upstream, for font discovery, which computes a `FontInfo` for every
// face of the system (`kit/fontdb.mbt`); what is computed is upstream's,
// encoding for encoding (`kit/fontdb_wbtest.mbt`):
// - the coverage is a function of its own, `Coverage::from_ttf`, and
//   `FontInfo::from_ttf_with_coverage` takes one that is known (the faces
//   of a collection share `cmap` tables);
// - it is built from the ranges of a subtable's segments and groups, not
//   from single codepoints, and a subtable that an earlier encoding record
//   points to as well is skipped;
// - `Coverage::union` merges the runs of two coverages as it reads them.

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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontInfo with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontInfo with Hash::{hash, hash_combine}

///|
/// Bitflags describing characteristics of a font.
pub(all) struct FontFlags(UInt) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFlags with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFlags with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFlags with @debug.Debug::{to_repr}

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
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontFlags with Show::{to_string, output}

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
  FontInfo::from_ttf_with_coverage(ttf, None)
}

///|
/// `FontInfo::from_ttf` for a face whose coverage may be known already
/// (not upstream, whose `from_ttf` is the body of this function: the faces
/// of a collection often share one `cmap` table, and font discovery
/// computes its coverage once, with `Coverage::from_ttf`).
pub fn FontInfo::from_ttf_with_coverage(
  ttf : @otf.Face,
  coverage : Coverage?,
) -> FontInfo? {
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
  let coverage = match coverage {
    Some(coverage) => coverage
    None => Coverage::from_ttf(ttf)
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
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontInfo with Show::{to_string, output}

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
let mac_roman_table : ReadOnlyArray[Char] = [
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
  let buf = StringBuilder()
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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Coverage with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Coverage with Hash::{hash, hash_combine}

///|
pub impl Default for Coverage with fn default() {
  Coverage([])
}

///|
pub extend Coverage with Default::{default}

///|
/// The unicode coverage of a face (in upstream a part of
/// `FontInfo::from_ttf`: "Determine the unicode coverage").
pub fn Coverage::from_ttf(ttf : @otf.Face) -> Coverage {
  let mut coverage = Coverage([])
  if ttf.tables().cmap is Some(cmap) {
    // The offsets of the subtables that are in `coverage`.
    let seen : Array[UInt] = []
    let mut index : UInt16 = 0
    for subtable in cmap.subtables.iter() {
      let offset = cmap.subtables.offset(index)
      index += 1
      if subtable.is_unicode() {
        // Not upstream: a subtable that an earlier record points to as well
        // adds nothing. Most fonts have two records for each of their
        // subtables (one of the Unicode and one of the Windows platform).
        // The encoding stays the same: what is built from one subtable is
        // one set, the union of two sets is their union, and a set has one
        // encoding (its ranges, in order, each as long as it can be).
        if offset is Some(offset) {
          if seen.contains(offset) {
            continue
          }
          seen.push(offset)
        }
        let subtable_coverage = CoverageBuilder::with_capacity(
          coverage.0.length(),
        )
        // Ranges instead of single codepoints (performance; the same
        // coverage: a codepoint is added as `c..c.saturating_add(1)`, and
        // adding those of `start..=end` in order is adding
        // `start..end.saturating_add(1)`).
        subtable.codepoint_ranges(
          // We expect codepoints in CMAP subtables to be already sorted
          (start, end) => {
            subtable_coverage.add_codepoint_range(
              start,
              if end == 0xFFFFFFFFU {
                end
              } else {
                end + 1
              },
            )
          },
        )
        coverage = coverage.union(subtable_coverage.build())
      }
    }
  }
  coverage
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
///
/// The ranges of both (`iter_ranges`) are read off the runs as they are
/// merged, without a list of them: this runs for every subtable of every
/// face that font discovery finds.
fn Coverage::union(self : Coverage, other : Coverage) -> Coverage {
  let left = self.0
  let right = other.0
  let capacity = if left.length() > right.length() {
    left.length()
  } else {
    right.length()
  }
  let builder = CoverageBuilder::with_capacity(capacity)
  // The index of the next range's gap and the end of the range before it.
  let mut i = 0
  let mut left_offset : UInt = 0
  let mut j = 0
  let mut right_offset : UInt = 0
  while i + 1 < left.length() && j + 1 < right.length() {
    let left_start = left_offset + left[i]
    let right_start = right_offset + right[j]
    if left_start < right_start {
      left_offset = left_start + left[i + 1]
      builder.add_codepoint_range(left_start, left_offset)
      i += 2
    } else {
      right_offset = right_start + right[j + 1]
      builder.add_codepoint_range(right_start, right_offset)
      j += 2
    }
  }
  while i + 1 < left.length() {
    let start = left_offset + left[i]
    left_offset = start + left[i + 1]
    builder.add_codepoint_range(start, left_offset)
    i += 2
  }
  while j + 1 < right.length() {
    let start = right_offset + right[j]
    right_offset = start + right[j + 1]
    builder.add_codepoint_range(start, right_offset)
    j += 2
  }
  builder.build()
}

///|
pub impl Show for Coverage with fn output(_, logger) {
  logger.write_string("Coverage(..)")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Coverage with Show::{to_string, output}

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
  { runs: Array(capacity~), next: 0, }
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
  self.add_codepoint_range(codepoint, end)
}

///|
/// Add a continuous range of codepoints to the set being built. Ranges must
/// be added in non-decreasing order of start codepoint, but may intersect
/// or be contained in previously added ranges.
///
/// (Upstream's `Range<u32>` as its two ends: a tuple is an allocation.)
fn CoverageBuilder::add_codepoint_range(
  self : CoverageBuilder,
  start : UInt,
  end : UInt,
) -> Unit {
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
  let buf = StringBuilder()
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
