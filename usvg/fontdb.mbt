// The parts of `fontdb` 0.23.0 (`src/lib.rs`) that usvg uses: an in-memory
// font database with CSS-like queries. There is no system font discovery:
// fonts are added with `Database::load_font_data` (which parses the face
// metadata like upstream's `parse_face_info`) or `push_face_info`.

///|
/// A unique font face ID (upstream `fontdb::ID`). IDs are assigned in
/// insertion order.
pub type FontId = Int

///|
/// A font style (upstream `fontdb::Style`).
pub(all) enum DbStyle {
  Normal
  Italic
  Oblique
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DbStyle with Eq::{not_equal, equal}

///|
/// A single font face info.
pub(all) struct FaceInfo {
  /// An unique ID (overwritten by `push_face_info`).
  mut id : FontId
  /// The font data.
  source : Bytes
  /// A face index in the `source`.
  index : UInt
  /// A list of family names.
  ///
  /// Contains pairs of Name + Language. Where the first family is always English US,
  /// unless it's missing from the font.
  families : Array[(String, @otf.Language)]
  /// A PostScript name.
  post_script_name : String
  /// A font face style.
  style : DbStyle
  /// A font face weight.
  weight : Int
  /// A font face stretch.
  stretch : FontStretch
  /// Indicates that the font face is monospaced.
  monospaced : Bool
}

///|
/// A font database.
pub struct FontDatabase {
  priv faces : Array[FaceInfo]
  // Parsed faces (upstream parses the data in every `with_face_data` call).
  priv parsed : Map[FontId, @otf.Face?]
  priv mut family_serif : String
  priv mut family_sans_serif : String
  priv mut family_cursive : String
  priv mut family_fantasy : String
  priv mut family_monospace : String
}

///|
/// Create a new, empty `Database`.
///
/// Generic font families would be set to:
///
/// - `serif` - Times New Roman
/// - `sans-serif` - Arial
/// - `cursive` - Comic Sans MS
/// - `fantasy` - Impact (Papyrus on macOS; as upstream on the macOS oracle)
/// - `monospace` - Courier New
pub fn FontDatabase::new() -> FontDatabase {
  {
    faces: [],
    parsed: {},
    family_serif: "Times New Roman",
    family_sans_serif: "Arial",
    family_cursive: "Comic Sans MS",
    family_fantasy: "Papyrus",
    family_monospace: "Courier New",
  }
}

///|
/// A copy of the database (upstream's copy-on-write `Arc::make_mut`).
pub fn FontDatabase::clone(self : FontDatabase) -> FontDatabase {
  { ..self, faces: self.faces.copy(), parsed: {}, }
}

///|
/// Pushes a user-provided `FaceInfo` to the database.
pub fn FontDatabase::push_face_info(
  self : FontDatabase,
  info : FaceInfo,
) -> FontId {
  let id = self.faces.length()
  self.faces.push({ ..info, id, })
  id
}

///|
/// Loads a font data into the `Database`.
///
/// Will load all font faces in case of a font collection.
pub fn FontDatabase::load_font_data(self : FontDatabase, data : Bytes) -> Unit {
  let n = @otf.fonts_in_collection(data[:]).unwrap_or(1)
  for index in 0U..<n {
    if parse_face_info(data, index) is Some(info) {
      self.push_face_info(info) |> ignore
    }
  }
}

///|
/// Returns the number of font faces in the `Database`.
pub fn FontDatabase::len(self : FontDatabase) -> Int {
  self.faces.length()
}

///|
/// Returns `true` if the `Database` contains no font faces.
pub fn FontDatabase::is_empty(self : FontDatabase) -> Bool {
  self.faces.is_empty()
}

///|
/// Sets the family that will be used by `Family::Serif`.
pub fn FontDatabase::set_serif_family(
  self : FontDatabase,
  family : String,
) -> Unit {
  self.family_serif = family
}

///|
/// Sets the family that will be used by `Family::SansSerif`.
pub fn FontDatabase::set_sans_serif_family(
  self : FontDatabase,
  family : String,
) -> Unit {
  self.family_sans_serif = family
}

///|
/// Sets the family that will be used by `Family::Cursive`.
pub fn FontDatabase::set_cursive_family(
  self : FontDatabase,
  family : String,
) -> Unit {
  self.family_cursive = family
}

///|
/// Sets the family that will be used by `Family::Fantasy`.
pub fn FontDatabase::set_fantasy_family(
  self : FontDatabase,
  family : String,
) -> Unit {
  self.family_fantasy = family
}

///|
/// Sets the family that will be used by `Family::Monospace`.
pub fn FontDatabase::set_monospace_family(
  self : FontDatabase,
  family : String,
) -> Unit {
  self.family_monospace = family
}

///|
/// Returns the generic family name or the `Family::Name` itself.
pub fn FontDatabase::family_name(
  self : FontDatabase,
  family : @svgtypes.FontFamily,
) -> String {
  match family {
    Named(name) => name
    Serif => self.family_serif
    SansSerif => self.family_sans_serif
    Cursive => self.family_cursive
    Fantasy => self.family_fantasy
    Monospace => self.family_monospace
  }
}

///|
/// A database query (upstream `fontdb::Query`).
pub(all) struct FontQuery {
  families : Array[@svgtypes.FontFamily]
  weight : Int
  stretch : FontStretch
  style : DbStyle
}

///|
/// Performs a CSS-like query and returns the best matched font face.
pub fn FontDatabase::query(self : FontDatabase, query : FontQuery) -> FontId? {
  for family in query.families {
    let name = self.family_name(family)
    let candidates = self.faces.filter(face => {
      face.families.iter().any(f => f.0 == name)
    })
    if !candidates.is_empty() {
      if find_best_match(candidates, query) is Some(index) {
        return Some(candidates[index].id)
      }
    }
  }
  None
}

///|
/// Returns all faces.
pub fn FontDatabase::faces(self : FontDatabase) -> Array[FaceInfo] {
  self.faces
}

///|
/// Selects a `FaceInfo` by `id`.
pub fn FontDatabase::face(self : FontDatabase, id : FontId) -> FaceInfo? {
  self.faces.get(id)
}

///|
/// Executes a closure with a font's data.
pub fn[T] FontDatabase::with_face_data(
  self : FontDatabase,
  id : FontId,
  p : (Bytes, UInt) -> T,
) -> T? {
  guard self.face(id) is Some(face) else { return None }
  Some(p(face.source, face.index))
}

///|
// https://www.w3.org/TR/2018/REC-css-fonts-3-20180920/#font-style-matching
// Based on https://github.com/servo/font-kit
fn find_best_match(candidates : Array[FaceInfo], query : FontQuery) -> Int? {
  // Step 4.
  let mut matching_set = Array::makei(candidates.length(), i => i)

  // `min_by_key` (the first minimum).
  let min_by_key = (set : Array[Int], key : (Int) -> Int) => {
    let mut best : Int? = None
    let mut best_key = 0
    for index in set {
      let k = key(index)
      if best is None || k < best_key {
        best = Some(index)
        best_key = k
      }
    }
    best
  }

  // Step 4a (`font-stretch`).
  let q = query.stretch.to_number()
  let matches = matching_set
    .iter()
    .any(index => candidates[index].stretch == query.stretch)
  let matching_stretch = if matches {
    // Exact match.
    query.stretch
  } else if q <= FontStretch::Normal.to_number() {
    // Closest stretch, first checking narrower values and then wider values.
    let narrower = matching_set.filter(index => {
      candidates[index].stretch.to_number() < q
    })
    match
      min_by_key(narrower, index => q - candidates[index].stretch.to_number()) {
      Some(matching_index) => candidates[matching_index].stretch
      None => {
        guard min_by_key(matching_set, index => {
            candidates[index].stretch.to_number() - q
          })
          is Some(matching_index) else {
          return None
        }
        candidates[matching_index].stretch
      }
    }
  } else {
    // Closest stretch, first checking wider values and then narrower values.
    let wider = matching_set.filter(index => {
      candidates[index].stretch.to_number() > q
    })
    match
      min_by_key(wider, index => candidates[index].stretch.to_number() - q) {
      Some(matching_index) => candidates[matching_index].stretch
      None => {
        guard min_by_key(matching_set, index => {
            q - candidates[index].stretch.to_number()
          })
          is Some(matching_index) else {
          return None
        }
        candidates[matching_index].stretch
      }
    }
  }
  matching_set = matching_set.filter(index => {
    candidates[index].stretch == matching_stretch
  })

  // Step 4b (`font-style`).
  let style_preference = match query.style {
    Italic => [DbStyle::Italic, DbStyle::Oblique, DbStyle::Normal]
    Oblique => [DbStyle::Oblique, DbStyle::Italic, DbStyle::Normal]
    Normal => [DbStyle::Normal, DbStyle::Oblique, DbStyle::Italic]
  }
  guard style_preference
    .iter()
    .find_first(query_style => {
      matching_set.iter().any(index => candidates[index].style == query_style)
    })
    is Some(matching_style) else {
    return None
  }
  matching_set = matching_set.filter(index => {
    candidates[index].style == matching_style
  })

  // Step 4c (`font-weight`).
  //
  // The spec doesn't say what to do if the weight is between 400 and 500 exclusive, so we
  // just use 450 as the cutoff.
  let weight = query.weight
  let matching_weight = if matching_set
    .iter()
    .any(index => candidates[index].weight == weight) {
    weight
  } else if weight >= 400 &&
    weight < 450 &&
    matching_set.iter().any(index => candidates[index].weight == 500) {
    // Check 500 first.
    500
  } else if weight >= 450 &&
    weight <= 500 &&
    matching_set.iter().any(index => candidates[index].weight == 400) {
    // Check 400 first.
    400
  } else if weight <= 500 {
    // Closest weight, first checking thinner values and then fatter ones.
    let thinner = matching_set.filter(index => {
      candidates[index].weight <= weight
    })
    match min_by_key(thinner, index => weight - candidates[index].weight) {
      Some(matching_index) => candidates[matching_index].weight
      None => {
        guard min_by_key(matching_set, index => {
            candidates[index].weight - weight
          })
          is Some(matching_index) else {
          return None
        }
        candidates[matching_index].weight
      }
    }
  } else {
    // Closest weight, first checking fatter values and then thinner ones.
    let fatter = matching_set.filter(index => candidates[index].weight >= weight)
    match min_by_key(fatter, index => candidates[index].weight - weight) {
      Some(matching_index) => candidates[matching_index].weight
      None => {
        guard min_by_key(matching_set, index => {
            weight - candidates[index].weight
          })
          is Some(matching_index) else {
          return None
        }
        candidates[matching_index].weight
      }
    }
  }
  matching_set = matching_set.filter(index => {
    candidates[index].weight == matching_weight
  })

  // Ignore step 4d (`font-size`).

  // Return the result.
  matching_set.get(0)
}

///|
/// Parses the face metadata (upstream `parse_face_info`).
fn parse_face_info(data : Bytes, index : UInt) -> FaceInfo? {
  guard (Some(@otf.Face::parse(data[:], index)) catch { _ => None })
    is Some(face) else {
    return None
  }
  guard parse_face_names(face) is Some((families, post_script_name)) else {
    return None
  }
  let (style, weight, stretch) = match face.tables().os2 {
    Some(table) => {
      let style = match table.style() {
        Normal => DbStyle::Normal
        Italic => DbStyle::Italic
        Oblique => DbStyle::Oblique
      }
      let stretch = match table.width() {
        UltraCondensed => FontStretch::UltraCondensed
        ExtraCondensed => FontStretch::ExtraCondensed
        Condensed => FontStretch::Condensed
        SemiCondensed => FontStretch::SemiCondensed
        Normal => FontStretch::Normal
        SemiExpanded => FontStretch::SemiExpanded
        Expanded => FontStretch::Expanded
        ExtraExpanded => FontStretch::ExtraExpanded
        UltraExpanded => FontStretch::UltraExpanded
      }
      (style, table.weight().to_number().to_int(), stretch)
    }
    None => (DbStyle::Normal, 400, FontStretch::Normal)
  }
  let (monospaced, italic) = match
    face.raw_face().table(@otf.Tag::from_bytes(b"post")) {
    Some(post) => {
      let zero4 = (start : Int) => {
        post.length() >= start + 4 &&
        post[start] == 0 &&
        post[start + 1] == 0 &&
        post[start + 2] == 0 &&
        post[start + 3] == 0
      }
      (!zero4(12), !zero4(4))
    }
    None => (false, false)
  }
  let style = if style == DbStyle::Normal && italic {
    DbStyle::Italic
  } else {
    style
  }
  Some({
    id: 0,
    source: data,
    index,
    families,
    post_script_name,
    style,
    weight,
    stretch,
    monospaced,
  })
}

///|
fn parse_face_names(
  face : @otf.Face,
) -> (Array[(String, @otf.Language)], String)? {
  let names = face.names()
  let collect_families = (name_id : Int) => {
    let families = []
    for name in names.iter() {
      if name.name_id.to_int() == name_id && name.is_unicode() {
        if name_to_unicode(name) is Some(family) {
          families.push((family, name.language()))
        }
      }
    }

    // If no Unicode English US family name was found then look for English MacRoman as well.
    if !families.iter().any(f => f.1 == English_UnitedStates) {
      for name in names.iter() {
        if name.name_id.to_int() == name_id && name_is_mac_roman(name) {
          if name_to_unicode(name) is Some(family) {
            families.push((family, name.language()))
            break
          }
        }
      }
    }
    families
  }
  let mut families = collect_families(16) // TYPOGRAPHIC_FAMILY

  // We have to fallback to Family Name when no Typographic Family Name was set.
  if families.is_empty() {
    families = collect_families(1) // FAMILY
  }

  // Make English US the first one.
  if families.length() > 1 {
    for index, f in families {
      if f.1 == English_UnitedStates {
        if index != 0 {
          families.swap(0, index)
        }
        break
      }
    }
  }
  if families.is_empty() {
    return None
  }
  let mut post_script_name = None
  for name in names.iter() {
    if name.name_id.to_int() == 6 &&
      (name.is_unicode() || name_is_mac_roman(name)) {
      post_script_name = name_to_unicode(name)
      break
    }
  }
  guard post_script_name is Some(post_script_name) else { return None }
  Some((families, post_script_name))
}

///|
fn name_is_mac_roman(name : @otf.Name) -> Bool {
  name.platform_id == Macintosh && name.encoding_id.to_int() == 0
}

///|
fn name_to_unicode(name : @otf.Name) -> String? {
  let data = name.name
  if name.is_unicode() {
    let units = []
    let mut i = 0
    while i + 1 < data.length() {
      units.push((data[i].to_int() << 8) | data[i + 1].to_int())
      i += 2
    }
    utf16_decode_strict(units)
  } else if name_is_mac_roman(name) {
    let units = []
    for b in data {
      units.push(mac_roman[b.to_int()])
    }
    utf16_decode_strict(units)
  } else {
    None
  }
}

///|
/// `String::from_utf16` (fails on unpaired surrogates).
fn utf16_decode_strict(units : Array[Int]) -> String? {
  let sb = StringBuilder()
  let mut i = 0
  while i < units.length() {
    let u = units[i]
    if u >= 0xD800 && u <= 0xDBFF {
      if i + 1 < units.length() &&
        units[i + 1] >= 0xDC00 &&
        units[i + 1] <= 0xDFFF {
        let c = 0x10000 + ((u - 0xD800) << 10) + (units[i + 1] - 0xDC00)
        sb.write_char(c.unsafe_to_char())
        i += 2
        continue
      }
      return None
    } else if u >= 0xDC00 && u <= 0xDFFF {
      return None
    }
    sb.write_char(u.unsafe_to_char())
    i += 1
  }
  Some(sb.to_string())
}

///|
/// Macintosh Roman to UTF-16 encoding table.
let mac_roman : ReadOnlyArray[Int] = [
  0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009,
  0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F, 0x0010, 0x2318, 0x21E7, 0x2325,
  0x2303, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D,
  0x001E, 0x001F, 0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
  0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F, 0x0030, 0x0031,
  0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003A, 0x003B,
  0x003C, 0x003D, 0x003E, 0x003F, 0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045,
  0x0046, 0x0047, 0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
  0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059,
  0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F, 0x0060, 0x0061, 0x0062, 0x0063,
  0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D,
  0x006E, 0x006F, 0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
  0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x007D, 0x007E, 0x007F, 0x00C4, 0x00C5,
  0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1, 0x00E0, 0x00E2, 0x00E4, 0x00E3,
  0x00E5, 0x00E7, 0x00E9, 0x00E8, 0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF,
  0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,
  0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF, 0x00AE, 0x00A9,
  0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8, 0x221E, 0x00B1, 0x2264, 0x2265,
  0x00A5, 0x00B5, 0x2202, 0x2211, 0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9,
  0x00E6, 0x00F8, 0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB,
  0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153, 0x2013, 0x2014,
  0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA, 0x00FF, 0x0178, 0x2044, 0x20AC,
  0x2039, 0x203A, 0xFB01, 0xFB02, 0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2,
  0x00CA, 0x00C1, 0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
  0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC, 0x00AF, 0x02D8,
  0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
]
