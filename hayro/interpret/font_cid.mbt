// Port of `hayro-interpret/src/font/cid.rs`.

///|
priv struct Type0Font {
  font_type : CidFontType
  horizontal : Bool
  cache_key : U128
  dw : Float
  dw2 : (Float, Float)
  widths : Map[UInt, Float]
  encoding : @cmap.CMap
  to_unicode : @cmap.CMap?
  widths2 : Map[UInt, FixedArray[Float]]
  cid_to_gid_map : CidToGIdMap
  /// PostScript name from the PDF.
  postscript_name : String?
  /// Font flags from the font descriptor.
  font_flags : UInt?
  /// Whether this font is using a fallback (non-embedded) font.
  fallback : Bool
  /// Whether the `to_unicode` map is a UCS2 `CMap` (CID-indexed) rather than
  /// a `ToUnicode` `CMap` (code-indexed).
  to_unicode_is_cid_indexed : Bool
}

///|
fn Type0Font::new(
  dict : @hayro_syntax.Dict,
  font_resolver : FontResolverFn,
  cmap_resolver : CMapResolverFn,
) -> Type0Font? {
  guard (dict.get("Encoding") : @hayro_syntax.Object?) is Some(enc_obj) &&
    read_cid_encoding(enc_obj, cmap_resolver) is Some(cmap) else {
    return None
  }
  let horizontal = cmap.metadata().writing_mode != Some(Vertical)
  guard (dict.get("DescendantFonts") : @hayro_syntax.PdfArray?) is Some(arr) &&
    (arr.iter() : Iter[@hayro_syntax.Dict]).iterator().next()
    is Some(descendant_font) else {
    return None
  }
  let font_descriptor = (
    descendant_font.get("FontDescriptor") : @hayro_syntax.Dict?).unwrap_or(
    @hayro_syntax.Dict::empty(),
  )
  let character_collection = match cmap.metadata().character_collection {
    Some(cc) if cc.family != AdobeIdentity => Some(cc)
    _ => read_cid_system_info(descendant_font)
  }
  let (font_type, fallback) = match CidFontType::new(font_descriptor) {
    Some(ft) => (ft, false)
    None => {
      let query = match select_standard_font(dict, font_descriptor) {
        Some((standard, _)) => FontQuery::Standard(standard)
        None => {
          let query = FallbackFontQuery::new(dict)
          query.character_collection = character_collection
          // warn!("unable to load CID font {} ({:?}), attempting fallback", ...);
          FontQuery::Fallback(query)
        }
      }
      guard font_resolver(query) is Some((data, index)) else { return None }
      let blob = match OpenTypeFontBlob::new(data, index) {
        Some(b) => CidFontType::OpenType(b)
        None =>
          match CffFontBlob::new(data) {
            Some(c) => CidFontType::Cff(c)
            None => return None
          }
      }
      (blob, true)
    }
  }
  let default_width = (descendant_font.get("DW") : Float?).unwrap_or(1000.0)
  let dw2 = match (descendant_font.get_fixed("DW2", 2) : Array[Float]?) {
    Some(v) => (v[0], v[1])
    None => (880.0, -1000.0)
  }
  let widths = match (descendant_font.get("W") : @hayro_syntax.PdfArray?) {
    Some(a) => read_cid_widths(a).unwrap_or({})
    None => {}
  }
  let widths2 = match (descendant_font.get("W2") : @hayro_syntax.PdfArray?) {
    Some(a) => read_cid_widths2(a).unwrap_or({})
    None => {}
  }
  let cid_to_gid_map = CidToGIdMap::new(descendant_font).unwrap_or(Identity)
  let cache_key = CacheKey::cache_key(dict)
  let mut to_unicode = read_to_unicode(dict, cmap_resolver)
  let mut to_unicode_is_cid_indexed = false

  // If there is no ToUnicode map, try to get the UCS2 CMap.
  if fallback &&
    to_unicode is None &&
    character_collection is Some(cc) &&
    cc.family.ucs2_cmap() is Some(ucs2_name) &&
    cmap_resolver(ucs2_name) is Some(data) {
    if @cmap.CMap::parse(data[:], n => cmap_resolver(n)) is Some(ucs2_cmap) {
      to_unicode = Some(ucs2_cmap)
      to_unicode_is_cid_indexed = true
    }
  }
  let postscript_name = match (dict.get("BaseFont") : @hayro_syntax.Name?) {
    Some(n) => Some(strip_subset_prefix(n.as_str()))
    None => None
  }

  // Extract font flags from descriptor
  let font_flags = match (font_descriptor.get("Flags") : UInt?) {
    Some(bits) => font_flags_from_bits(bits)
    None => None
  }
  Some({
    cache_key,
    horizontal,
    encoding: cmap,
    to_unicode,
    font_type,
    dw: default_width,
    dw2,
    widths,
    widths2,
    cid_to_gid_map,
    postscript_name,
    font_flags,
    fallback,
    to_unicode_is_cid_indexed,
  })
}

///|
fn Type0Font::map_code(self : Type0Font, code : UInt) -> GlyphId {
  guard self.code_to_cid(code) is Some(cid) else { return glyph_id_notdef }

  // UCS2 maps are indexed by CIDs, while embededd `ToUnicode` maps are
  // indexed by character code.
  let to_unicode_key = if self.to_unicode_is_cid_indexed { cid } else { code }
  if self.fallback && self.map_via_unicode(to_unicode_key) is Some(glyph) {
    // Yay, Unicode worked!
    return glyph
  }

  // At this point, not much we can do anymore. Just hope that the
  // selected font has the right glyph order, and map via that.
  match self.font_type {
    OpenType(_) => self.cid_to_gid_map.map(cid.reinterpret_as_int() & 0xFFFF)
    Cff(c) =>
      if c.is_cid() {
        // Very confusing stuff going on here, see https://github.com/mozilla/pdf.js/pull/15563.
        // The PDF spec makes it sounds like cid-to-gid map should only be used for TrueType fonts,
        // but Acrobat also seems to support it for CFF fonts with some weird behavior.
        if self.cid_to_gid_map is Identity {
          c
          .glyph_index_by_cid(cid.reinterpret_as_int() & 0xFFFF)
          .unwrap_or(glyph_id_notdef)
        } else {
          GlyphId::new(
            self.cid_to_gid_map
            .inverse_map(GlyphId::new(cid))
            .reinterpret_as_uint(),
          )
        }
      } else {
        self.cid_to_gid_map.map(cid.reinterpret_as_int() & 0xFFFF)
      }
    // Maybe we need similar processing to CFF fonts? But since
    // Type1 fonts are invalid anyway, let's just ignore for now.
    Type1(_) => GlyphId::new(cid)
  }
}

///|
/// Map a character code (or CID) to a glyph ID
/// by first getting its Unicode and then looking up the codepoint in the
/// font's cmap.
fn Type0Font::map_via_unicode(self : Type0Font, key : UInt) -> GlyphId? {
  guard self.to_unicode is Some(to_unicode) else { return None }
  let bf = match to_unicode.lookup_bf_string(key) {
    Some(bf) => Some(bf)
    None => {
      let mut found = None
      for len in 0..<4 {
        if to_unicode.lookup_cid_code(key, len) is Some(code) &&
          char_from_u32(code) is Some(code) {
          found = Some(@cmap.BfString::Char(code))
          break
        }
      }
      found
    }
  }
  guard bf is Some(Char(character)) else { return None }
  match self.font_type {
    OpenType(t) => t.charmap_map(character)
    Cff(c) =>
      // Map codepoint to glyph name via AFL, and then look it up.
      match glyph_names_get_reverse(character) {
        Some(name) => c.glyph_index_by_name(name)
        None => None
      }
    Type1(_) =>
      // We could in theory map to a glyph via AFL and then look up
      // the glyph index in the encoding, but since skrifa doesn't have
      // an API for that and this is only really necessary for fallback
      // fonts (which currently only supports OpenType and CFF as fallback),
      // so we don't support this for now.
      None
  }
}

///|
fn Type0Font::code_to_cid(self : Type0Font, code : UInt) -> UInt? {
  for byte_len in 1..<=4 {
    if self.encoding.lookup_cid_code(code, byte_len) is Some(cid) {
      return Some(cid)
    }
  }
  None
}

///|
fn Type0Font::outline_glyph(
  self : Type0Font,
  glyph : GlyphId,
  code : UInt,
) -> @kurbo.BezPath {
  let path = match self.font_type {
    OpenType(t) => t.outline_glyph(glyph)
    Cff(c) => c.outline_glyph(glyph)
    Type1(t) => t.outline_glyph(glyph)
  }
  if self.fallback &&
    self.font_type is OpenType(t) &&
    self.code_to_cid(code) is Some(cid) &&
    t.advance_width(glyph) is Some(actual_width) &&
    // Only use an expected width if there is an explicit /W array,
    // not the default width, as it leads to weird results from my testing.
    self.widths.get(cid) is Some(expected_width) {
    return stretch_glyph(path, expected_width, actual_width)
  }
  path
}

///|
fn Type0Font::font_data(self : Type0Font) -> Bytes? {
  match self.font_type {
    OpenType(t) => Some(t.font_data())
    Cff(c) => Some(c.font_data())
    Type1(_) => None
  }
}

///|
/// Get the PostScript name.
fn Type0Font::postscript_name(self : Type0Font) -> String? {
  self.postscript_name
}

///|
/// Get the font weight (100-900, 400=normal, 700=bold).
///
/// Returns `None` if weight cannot be determined (CFF fonts or invalid weight).
fn Type0Font::weight(self : Type0Font) -> UInt? {
  match self.font_type {
    OpenType(t) => {
      let weight = f32_as_u32(rust_round_f32(t.weight())).reinterpret_as_uint()
      if weight > 0 {
        Some(weight)
      } else {
        None
      }
    }
    Cff(_) | Type1(_) => None
  }
}

///|
/// Check if font is italic based on font flags or font attributes.
fn Type0Font::is_italic(self : Type0Font) -> Bool {
  if self.font_flags is Some(flags) && (flags & FONT_FLAG_ITALIC) != 0 {
    return true
  }
  match self.font_type {
    OpenType(t) => !t.style_is_normal()
    Cff(_) | Type1(_) => false
  }
}

///|
/// Check if font is serif based on font flags.
fn Type0Font::is_serif(self : Type0Font) -> Bool {
  self.font_flags is Some(f) && (f & FONT_FLAG_SERIF) != 0
}

///|
/// Check if font is monospace based on font flags or font metrics.
fn Type0Font::is_monospace(self : Type0Font) -> Bool {
  if self.font_flags is Some(flags) && (flags & FONT_FLAG_FIXED_PITCH) != 0 {
    return true
  }
  match self.font_type {
    OpenType(t) => t.is_monospace()
    Cff(_) | Type1(_) => false
  }
}

///|
fn Type0Font::code_advance(self : Type0Font, code : UInt) -> @kurbo.Vec2 {
  let cid = self.code_to_cid(code).unwrap_or(0)
  if self.horizontal {
    @kurbo.Vec2::new(self.horizontal_width(cid).to_double(), 0.0)
  } else if self.widths2.get(cid) is Some(w) {
    @kurbo.Vec2::new(0.0, w[0].to_double())
  } else {
    @kurbo.Vec2::new(0.0, self.dw2.1.to_double())
  }
}

///|
fn Type0Font::horizontal_width(self : Type0Font, cid : UInt) -> Float {
  self.widths.get(cid).unwrap_or(self.dw)
}

///|
fn Type0Font::is_horizontal(self : Type0Font) -> Bool {
  self.horizontal
}

///|
fn Type0Font::read_code(
  self : Type0Font,
  bytes : Bytes,
  offset : Int,
) -> (UInt, Int) {
  let mut code = 0U
  let remaining = bytes.length() - offset
  for n in 0..<@cmp.minimum(4, remaining) {
    code = (code << 8) | bytes[offset + n].to_uint()
    if self.encoding.lookup_cid_code(code, n + 1) is Some(_) {
      return (code, n + 1)
    }
  }
  (0, 1)
}

///|
fn Type0Font::origin_displacement(self : Type0Font, code : UInt) -> @kurbo.Vec2 {
  let cid = self.code_to_cid(code).unwrap_or(0)
  if self.is_horizontal() {
    @kurbo.vec2_zero
  } else if self.widths2.get(cid) is Some(w) {
    @kurbo.Vec2::new(-w[1].to_double(), -w[2].to_double())
  } else {
    @kurbo.Vec2::new(
      -self.horizontal_width(cid).to_double() / 2.0,
      -self.dw2.0.to_double(),
    )
  }
}

///|
fn Type0Font::char_code_to_unicode(
  self : Type0Font,
  code : UInt,
) -> @cmap.BfString? {
  if self.to_unicode is Some(to_unicode) {
    let key = if self.to_unicode_is_cid_indexed {
      self.code_to_cid(code).unwrap_or(0)
    } else {
      code
    }
    return to_unicode.lookup_bf_string(key)
  }
  None
}

///|
impl CacheKey for Type0Font with fn cache_key(self) {
  self.cache_key
}

///|
priv enum CidFontType {
  /// An OpenType font.
  OpenType(OpenTypeFontBlob)
  /// A CFF font.
  Cff(CffFontBlob)
  /// A Type1 font. (Yes, there actually exist PDFs that embed a Type1 font in a
  /// CID font :))
  Type1(Type1FontBlob)
}

///|
fn CidFontType::new(descriptor : @hayro_syntax.Dict) -> CidFontType? {
  // PDF has a distinction between CIDFontType0 and CIDFontType 2, with
  // specific requirements what font type can appear where. However, some
  // PDFs use wrong metadata, so we simply bruteforce without even looking
  // at the metadata.
  let stream = match (descriptor.get("FontFile2") : @hayro_syntax.Stream?) {
    Some(s) => Some(s)
    None =>
      match (descriptor.get("FontFile3") : @hayro_syntax.Stream?) {
        Some(s) => Some(s)
        // See PDFBOX-2599. Apparently, Acrobat accepts this as well.
        None => descriptor.get("FontFile")
      }
  }
  guard stream is Some(stream) && stream.decoded() is Ok(data) else {
    return None
  }
  let data = data.to_bytes()
  if is_open_type(data) {
    // It's an OpenType font, either TrueType or CFF.
    match OpenTypeFontBlob::new(data, 0) {
      Some(b) => Some(OpenType(b))
      None => None
    }
  } else if CffFontBlob::new(data) is Some(cff) {
    // It's a CFF font.
    Some(Cff(cff))
  } else if Type1FontBlob::new(data) is Some(t1) {
    // It's a Type1 (PFB) font.
    Some(Type1(t1))
  } else {
    None
  }
}

///|
priv enum CidToGIdMap {
  Identity
  Mapped(forward~ : Map[Int, GlyphId], inverse~ : Map[UInt, Int])
}

///|
fn CidToGIdMap::new(dict : @hayro_syntax.Dict) -> CidToGIdMap? {
  if (dict.get("CIDToGIDMap") : @hayro_syntax.Name?) is Some(name) {
    if name.as_str() == "Identity" {
      Some(Identity)
    } else {
      None
    }
  } else if (dict.get("CIDToGIDMap") : @hayro_syntax.Stream?) is Some(stream) {
    guard stream.decoded() is Ok(decoded) else { return None }
    let forward = {}
    let inverse = {}
    for cid in 0..<(decoded.length() / 2) {
      let gid = GlyphId::new(
        (decoded[cid * 2].to_uint() << 8) | decoded[cid * 2 + 1].to_uint(),
      )
      forward[cid & 0xFFFF] = gid
      inverse[gid.to_u32()] = cid & 0xFFFF
    }
    Some(Mapped(forward~, inverse~))
  } else {
    None
  }
}

///|
fn CidToGIdMap::map(self : CidToGIdMap, code : Int) -> GlyphId {
  match self {
    Identity => GlyphId::new(code.reinterpret_as_uint())
    Mapped(forward~, ..) => forward.get(code).unwrap_or(glyph_id_notdef)
  }
}

///|
fn CidToGIdMap::inverse_map(self : CidToGIdMap, gid : GlyphId) -> Int {
  match self {
    Identity => gid.to_u32().reinterpret_as_int() & 0xFFFF
    Mapped(inverse~, ..) =>
      inverse
      .get(gid.to_u32())
      .unwrap_or(gid.to_u32().reinterpret_as_int() & 0xFFFF)
  }
}

///|
/// Read a `(T, U)` tuple at the current position of a flex iterator,
/// restoring nothing on failure (upstream `FlexArrayIter::next::<(T, U)>`).
fn read_cid_widths(arr : @hayro_syntax.PdfArray) -> Map[UInt, Float]? {
  let map = {}
  let items : Array[@hayro_syntax.Object] = arr.iter().collect()
  let mut i = 0
  while true {
    // `(u32, Array)`
    if i + 1 < items.length() &&
      (items[i].cast() : UInt?) is Some(first) &&
      items[i + 1] is Array(range) {
      let mut first = first
      for width in (range.iter() : Iter[Float]) {
        map[first] = width
        guard first < 0xFFFF_FFFF else { return None }
        first = first + 1
      }
      i += 2
    } else if i + 2 < items.length() &&
      (items[i].cast() : UInt?) is Some(first) &&
      (items[i + 1].cast() : UInt?) is Some(second) &&
      (items[i + 2].cast() : Float?) is Some(width) {
      // `(u32, u32, f32)`
      let mut c = first
      while c <= second {
        map[c] = width
        if c == 0xFFFF_FFFF {
          break
        }
        c = c + 1
      }
      i += 3
    } else {
      break
    }
  }
  Some(map)
}

///|
fn read_cid_widths2(
  arr : @hayro_syntax.PdfArray,
) -> Map[UInt, FixedArray[Float]]? {
  let map = {}
  let items : Array[@hayro_syntax.Object] = arr.iter().collect()
  let mut i = 0
  while true {
    if i + 1 < items.length() &&
      (items[i].cast() : UInt?) is Some(first) &&
      items[i + 1] is Array(range) {
      let mut first = first
      let vals : Array[Float] = range.iter().collect()
      let mut j = 0
      while j < vals.length() {
        let w = vals[j]
        guard j + 2 < vals.length() else { return None }
        let v1 = vals[j + 1]
        let v2 = vals[j + 2]
        map[first] = FixedArray::from_array([w, v1, v2])
        guard first < 0xFFFF_FFFF else { return None }
        first = first + 1
        j += 3
      }
      i += 2
    } else if i + 4 < items.length() &&
      (items[i].cast() : UInt?) is Some(first) &&
      (items[i + 1].cast() : UInt?) is Some(second) &&
      (items[i + 2].cast() : Float?) is Some(w) &&
      (items[i + 3].cast() : Float?) is Some(v1) &&
      (items[i + 4].cast() : Float?) is Some(v2) {
      let mut c = first
      while c <= second {
        map[c] = FixedArray::from_array([w, v1, v2])
        if c == 0xFFFF_FFFF {
          break
        }
        c = c + 1
      }
      i += 5
    } else {
      break
    }
  }
  Some(map)
}

///|
fn read_cid_system_info(
  descendant_font : @hayro_syntax.Dict,
) -> @cmap.CharacterCollection? {
  guard (descendant_font.get("CIDSystemInfo") : @hayro_syntax.Dict?)
    is Some(info) else {
    return None
  }
  guard (info.get("Registry") : @hayro_syntax.PdfString?) is Some(registry) else {
    return None
  }
  guard (info.get("Ordering") : @hayro_syntax.PdfString?) is Some(ordering) else {
    return None
  }
  let supplement = (info.get("Supplement") : Int?).unwrap_or(0)
  let family = @cmap.CidFamily::from_registry_ordering(
    registry.as_bytes()[:],
    ordering.as_bytes()[:],
  )
  Some({ family, supplement, })
}

///|
fn read_cid_encoding(
  object : @hayro_syntax.Object,
  cmap_resolver : CMapResolverFn,
) -> @cmap.CMap? {
  // TODO: Support fetching CMaps referenced via `usecmap` in the PDF.
  match object {
    Name(n) => {
      let cmap_type = @cmap.CMapName::from_bytes(n.as_bytes()[:])
      match cmap_type {
        IdentityH => Some(@cmap.CMap::identity_h())
        IdentityV => Some(@cmap.CMap::identity_v())
        _ => {
          guard cmap_resolver(cmap_type) is Some(data) else { return None }
          @cmap.CMap::parse(data[:], n => cmap_resolver(n))
        }
      }
    }
    Stream(s) => {
      guard s.decoded() is Ok(decoded) else { return None }
      @cmap.CMap::parse(decoded, n => cmap_resolver(n))
    }
    _ => None
  }
}
