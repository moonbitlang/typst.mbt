// Port of read-fonts 0.39.2 `src/ps/type1.rs` (the AGL based Unicode
// charmap is not ported since it requires the `agl` feature).

///|
/// A Type1 font.
pub struct Type1Font {
  mut name : String?
  mut full_name : String?
  mut family_name : String?
  mut weight : String?
  mut bbox : @font_types.BoundingBox[Fixed]
  mut italic_angle : Int
  mut is_fixed_pitch : Bool
  mut underline_position : Int
  mut underline_thickness : Int
  mut matrix : ScaledFontMatrix
  priv mut charstrings : Charstrings
  priv mut subrs : Subrs
  priv mut encoding : T1RawEncoding?
  mut weight_vector : Array[Fixed]
}

///|
/// Creates a new Type1 font from the given data.
pub fn Type1Font::new(data : BytesView) -> Type1Font raise PsError {
  // Any failure to parse is simply represented by an invalid font format
  // error
  match Type1Font::new_impl(data) {
    Some(f) => f
    None => raise InvalidFontFormat
  }
}

///|
fn Type1Font::new_impl(data : BytesView) -> Type1Font? {
  guard RawDicts::new(data) is Some(raw_dicts) else { return None }
  Type1Font::from_dicts(raw_dicts.base, raw_dicts.private[:])
}

///|
fn Type1Font::empty() -> Type1Font {
  {
    name: None,
    full_name: None,
    family_name: None,
    weight: None,
    italic_angle: 0,
    is_fixed_pitch: false,
    underline_position: 0,
    underline_thickness: 0,
    matrix: { matrix: FontMatrix::identity(), scale: 1000, },
    bbox: {
      x_min: Fixed::zero(),
      y_min: Fixed::zero(),
      x_max: Fixed::zero(),
      y_max: Fixed::zero(),
    },
    charstrings: Charstrings::new(),
    subrs: Subrs::new(),
    encoding: None,
    weight_vector: [],
  }
}

///|
fn name_is(tok : T1Token, s : String) -> Bool {
  match tok {
    TName(b) => bytes_eq(b, s)
    _ => false
  }
}

///|
fn raw_is(tok : T1Token?, s : String) -> Bool {
  match tok {
    Some(Raw(b)) => bytes_eq(b, s)
    _ => false
  }
}

///|
fn bytes_eq(b : BytesView, s : String) -> Bool {
  if b.length() != s.length() {
    return false
  }
  for i in 0..<b.length() {
    if b[i].to_int() != s[i].to_int() {
      return false
    }
  }
  true
}

///|
fn Type1Font::from_dicts(base : BytesView, private : BytesView) -> Type1Font? {
  let font = Type1Font::empty()
  // Read base dict entries
  let mut encoding_offset : Int? = None
  let parser = T1Parser::new(base)
  while parser.next() is Some(token) {
    if name_is(token, "FontName") {
      font.name = parser.read_string()
    } else if name_is(token, "FullName") {
      font.full_name = parser.read_string()
    } else if name_is(token, "FamilyName") {
      font.family_name = parser.read_string()
    } else if name_is(token, "Weight") {
      // The /Weight token can appear elsewhere in MM fonts so take
      // the first one
      if font.weight is None {
        font.weight = parser.read_string()
      }
    } else if name_is(token, "ItalicAngle") {
      font.italic_angle = parser.read_num_as_int().unwrap_or(0)
    } else if name_is(token, "IsFixedPitch") {
      font.is_fixed_pitch = raw_is(parser.next(), "true")
    } else if name_is(token, "UnderlinePosition") {
      font.underline_position = parser.read_num_as_int().unwrap_or(0)
    } else if name_is(token, "UnderlineThickness") {
      font.underline_thickness = parser.read_num_as_int().unwrap_or(0)
    } else if name_is(token, "FontBBox") {
      if parser.read_font_bbox() is Some(bbox) {
        font.bbox = {
          x_min: bbox[0],
          y_min: bbox[1],
          x_max: bbox[2],
          y_max: bbox[3],
        }
      }
    } else if name_is(token, "FontMatrix") {
      guard parser.read_font_matrix() is Some(m) else { return None }
      font.matrix = m
    } else if name_is(token, "Encoding") {
      // Simply save the encoding offset. We'll parse it after
      // we have read charstrings so we have an accurate mapping
      // if we've synthesized or remapped a notdef glyph
      encoding_offset = Some(parser.pos)
    } else if name_is(token, "WeightVector") {
      // Gated on a successful read because some fonts reference
      // the /WeightVector name outside of a proc, leading to
      // spurious field reads
      if parser.read_weight_vector() is Some(weights) {
        font.weight_vector = weights
      }
    }
  }
  // Read private dict entries
  let parser = T1Parser::new(private)
  // Default value if not present
  let mut len_iv = 4L
  while parser.next() is Some(token) {
    if name_is(token, "lenIV") {
      guard parser.read_int() is Some(v) else { return None }
      len_iv = v
    } else if name_is(token, "Subrs") {
      // With synthetic fonts, it's possible to read subroutines
      // twice. FreeType ignores the second copy.
      if font.subrs.index.is_empty() {
        guard parser.read_subrs(len_iv) is Some(subrs) else { return None }
        font.subrs = subrs
      }
    } else if name_is(token, "CharStrings") {
      // Some non-standard fonts provide multiple copies of
      // outlines for different resolutions and FreeType only
      // retains the first copy, so skip parsing if we've
      // already read some charstrings.
      if font.charstrings.index.is_empty() {
        guard parser.read_charstrings(len_iv) is Some(cs) else { return None }
        font.charstrings = cs
      }
    }
  }
  // Reject fonts that are missing a /CharStrings array
  if font.charstrings.index.is_empty() {
    return None
  }
  if encoding_offset is Some(encoding_offset) {
    if encoding_offset > base.length() {
      return None
    }
    let parser = T1Parser::new(base[encoding_offset:])
    guard parser.read_encoding(font.charstrings) is Some(enc) else {
      return None
    }
    font.encoding = Some(enc)
  }
  Some(font)
}

///|
/// Returns the PostScript name.
pub fn Type1Font::name(self : Type1Font) -> String? {
  self.name
}

///|
/// Returns the full font name.
pub fn Type1Font::full_name(self : Type1Font) -> String? {
  self.full_name
}

///|
/// Returns the font family name.
pub fn Type1Font::family_name(self : Type1Font) -> String? {
  self.family_name
}

///|
/// Returns the weight or style name.
pub fn Type1Font::weight(self : Type1Font) -> String? {
  self.weight
}

///|
/// Returns the italic angle.
pub fn Type1Font::italic_angle(self : Type1Font) -> Int {
  self.italic_angle
}

///|
/// Returns true if the glyphs in this font have the same width.
pub fn Type1Font::is_fixed_pitch(self : Type1Font) -> Bool {
  self.is_fixed_pitch
}

///|
/// Returns the position of the top of an underline decoration.
pub fn Type1Font::underline_position(self : Type1Font) -> Int {
  self.underline_position
}

///|
/// Returns the suggested size for an underline decoration.
pub fn Type1Font::underline_thickness(self : Type1Font) -> Int {
  self.underline_thickness
}

///|
/// Returns the font bounding box.
pub fn Type1Font::bbox(self : Type1Font) -> @font_types.BoundingBox[Fixed] {
  self.bbox
}

///|
/// Returns the number of glyphs in the Type1 font.
pub fn Type1Font::num_glyphs(self : Type1Font) -> Int {
  self.charstrings.index.length()
}

///|
/// Returns the units per em.
pub fn Type1Font::upem(self : Type1Font) -> Int {
  self.matrix.scale
}

///|
/// Returns the top level font matrix.
pub fn Type1Font::matrix(self : Type1Font) -> FontMatrix {
  self.matrix.matrix
}

///|
/// Returns the appropriate transform for adjusting points and metrics.
pub fn Type1Font::transform(self : Type1Font, ppem : Float?) -> Transform {
  let scale = match ppem {
    Some(ppem) => Some(Transform::compute_scale(ppem, self.upem()))
    None => None
  }
  { matrix: self.matrix(), scale, }
}

///|
/// Returns the character encoding.
pub fn Type1Font::encoding(self : Type1Font) -> Type1Encoding? {
  match self.encoding {
    Some(enc) => Some({ encoding: enc, charstrings: self.charstrings, })
    None => None
  }
}

///|
/// Returns the glyph name for the given id.
pub fn Type1Font::glyph_name(self : Type1Font, gid : GlyphId) -> String? {
  self.charstrings.name(gid.to_int())
}

///|
/// Returns the pairs of glyph ids and associated names in the Type1 font.
pub fn Type1Font::glyph_names(self : Type1Font) -> Array[(GlyphId, String)] {
  let result = []
  for idx in 0..<self.num_glyphs() {
    if self.charstrings.name(idx) is Some(name) {
      result.push((GlyphId::from_int(idx), name))
    }
  }
  result
}

///|
/// Given a glyph identifier in the original glyph order, returns the
/// possibly remapped identifier.
///
/// This occurs if we remap or synthesize a `.notdef` glyph.
pub fn Type1Font::remapped_gid(
  self : Type1Font,
  original_gid : GlyphId,
) -> GlyphId {
  match self.charstrings.orig_notdef_index {
    Some(orig_notdef) =>
      if original_gid == GlyphId::notdef() {
        GlyphId::from_int(orig_notdef)
      } else if orig_notdef == original_gid.to_int() {
        GlyphId::notdef()
      } else {
        original_gid
      }
    None => original_gid
  }
}

///|
/// Evaluates the charstring for the requested glyph and sends the results
/// to the given sink.
///
/// Returns the advance with of the glyph in font units if the charstring
/// provides one.
pub fn Type1Font::evaluate_charstring(
  self : Type1Font,
  gid : GlyphId,
  sink : &CommandSink,
) -> Fixed? raise PsError {
  guard self.charstrings.get(gid.to_int()) is Some(charstring_data) else {
    raise oob()
  }
  evaluate(self, charstring_data, sink)
}

///|
/// Draws the glyph with an optional size in ppem to the given pen.
///
/// Returns the advance width of the glyph if the charstring provides
/// one.
pub fn Type1Font::draw(
  self : Type1Font,
  gid : GlyphId,
  ppem : Float?,
  pen : &@read_fonts.OutlinePen,
) -> Float? raise PsError {
  let pen_sink = PenSink::new(pen)
  let nop_filter = NopFilterSink::new(pen_sink)
  let transform = self.transform(ppem)
  let transformer = TransformSink::new(nop_filter, transform)
  let width = self.evaluate_charstring(gid, transformer)
  match width {
    Some(w) => {
      let v = transform.transform_h_metric(w).to_f32()
      Some(if v > 0.0 { v } else { 0.0 })
    }
    None => None
  }
}

///|
pub impl CharstringContext for Type1Font with fn kind(_self) {
  Type1
}

///|
pub impl CharstringContext for Type1Font with fn seac_components(
  self,
  base_code,
  accent_code,
) {
  let decode = fn(code : Int) raise PsError {
    if code < 0 || code > 255 {
      raise InvalidSeacCode(code)
    }
    let name = PredefinedEncoding::Standard.name(code)
    match self.charstrings.index_for_name(name) {
      Some(idx) =>
        match self.charstrings.get(idx) {
          Some(d) => d
          None => raise InvalidSeacCode(code)
        }
      None => raise InvalidSeacCode(code)
    }
  }
  let base = decode(base_code)
  let accent = decode(accent_code)
  (base, accent)
}

///|
pub impl CharstringContext for Type1Font with fn subr(self, index) {
  match self.subrs.get(index.reinterpret_as_uint()) {
    Some(d) => d
    None => raise oob()
  }
}

///|
pub impl CharstringContext for Type1Font with fn global_subr(_self, _index) {
  // Type1 fonts don't have global subroutines
  raise MissingSubroutines
}

///|
pub impl CharstringContext for Type1Font with fn weight_vector(self) {
  self.weight_vector
}

///|
/// Associates character codes with glyph names and ids.
pub struct Type1Encoding {
  priv encoding : T1RawEncoding
  priv charstrings : Charstrings
}

///|
/// Returns the predefined encoding, if any.
pub fn Type1Encoding::predefined(self : Type1Encoding) -> PredefinedEncoding? {
  match self.encoding {
    Predefined(pre) => Some(pre)
    _ => None
  }
}

///|
/// Returns the glyph name for the given character code.
pub fn Type1Encoding::glyph_name(self : Type1Encoding, code : Byte) -> String? {
  match self.encoding {
    Predefined(pre) => Some(pre.name(code.to_int()))
    Custom(custom) =>
      match custom.get(code.to_int()) {
        Some(gid) => self.charstrings.name(gid.to_int())
        None => None
      }
  }
}

///|
/// Maps a character code to a glyph identifier.
pub fn Type1Encoding::map(self : Type1Encoding, code : Byte) -> GlyphId? {
  match self.encoding {
    Predefined(pre) =>
      match self.charstrings.index_for_name(pre.name(code.to_int())) {
        Some(idx) => Some(GlyphId::from_int(idx))
        None => None
      }
    Custom(custom) => custom.get(code.to_int())
  }
}

///|
/// Raw dictionary data for a Type1 font.
priv struct RawDicts {
  /// Data containing the base dictionary.
  base : BytesView
  /// Data containing the decrypted private dictionary.
  private : Bytes
}

///|
fn RawDicts::new(data : BytesView) -> RawDicts? {
  if decode_pfb_tag(data, 0) is Some((PFB_TEXT_SEGMENT_TAG, base_size)) {
    // We have a PFB; skip the tag
    guard get_from(data, 6) is Some(data) else { return None }
    guard verify_header(data) else { return None }
    if base_size.to_uint64() > data.length().to_uint64() {
      return None
    }
    let base_size = base_size.reinterpret_as_int()
    let base_dict = data[0:base_size]
    let raw_private_dict = data[base_size:]
    // Decrypt private dict segments
    let buf = Buffer()
    for segment in decode_pfb_binary_segments(raw_private_dict) {
      buf.write_bytesview(segment)
    }
    let private_dict = decrypt_skip(buf.to_bytes()[:], EEXEC_SEED, 4)
    Some({ base: base_dict, private: private_dict, })
  } else {
    // We have a PFA
    guard verify_header(data) else { return None }
    // Now find the start of the private dictionary
    guard find_eexec_data(data) is Some(start) else { return None }
    let base_dict = data[0:start]
    let raw_private_dict = data[start:]
    let is_hex = raw_private_dict.length() > 3 &&
      is_ascii_hexdigit(raw_private_dict[0]) &&
      is_ascii_hexdigit(raw_private_dict[1]) &&
      is_ascii_hexdigit(raw_private_dict[2]) &&
      is_ascii_hexdigit(raw_private_dict[3])
    let private_dict = if is_hex {
      // Hex decode and then decrypt
      decrypt_skip(decode_hex(raw_private_dict)[:], EEXEC_SEED, 4)
    } else {
      // Just decrypt
      decrypt_skip(raw_private_dict, EEXEC_SEED, 4)
    }
    Some({ base: base_dict, private: private_dict, })
  }
}

///|
fn is_ascii_hexdigit(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'a' && b <= b'f') ||
  (b >= b'A' && b <= b'F')
}

///|
fn is_ascii_digit(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
fn starts_with(data : BytesView, s : String) -> Bool {
  if data.length() < s.length() {
    return false
  }
  for i in 0..<s.length() {
    if data[i].to_int() != s[i].to_int() {
      return false
    }
  }
  true
}

///|
fn verify_header(data : BytesView) -> Bool {
  starts_with(data, "%!PS-AdobeFont") || starts_with(data, "%!FontType")
}

///|
const PFB_TEXT_SEGMENT_TAG : Int = 0x8001

///|
const PFB_BINARY_SEGMENT_TAG : Int = 0x8002

///|
/// Returns the PFB tag and segment size.
fn decode_pfb_tag(data : BytesView, start : Int) -> (Int, UInt)? {
  if start < 0 || start + 6 > data.length() {
    return None
  }
  let tag = (data[start].to_int() << 8) | data[start + 1].to_int()
  if tag == PFB_BINARY_SEGMENT_TAG || tag == PFB_TEXT_SEGMENT_TAG {
    let size = data[start + 2].to_uint() |
      (data[start + 3].to_uint() << 8) |
      (data[start + 4].to_uint() << 16) |
      (data[start + 5].to_uint() << 24)
    Some((tag, size))
  } else {
    None
  }
}

///|
/// Returns the sequence of PFB binary segments.
fn decode_pfb_binary_segments(data : BytesView) -> Array[BytesView] {
  let result = []
  let mut pos = 0
  while decode_pfb_tag(data, pos) is Some((tag, len)) {
    // FT only decodes the sequence of binary segments here
    if tag != PFB_BINARY_SEGMENT_TAG {
      break
    }
    // Skip tag and size bytes
    let start = pos + 6
    let end = start.to_uint64() + len.to_uint64()
    if end > data.length().to_uint64() {
      break
    }
    result.push(data[start:end.to_int()])
    pos = end.to_int()
  }
  result
}

///|
/// Helper to find the position of the data following the 'eexec' token.
fn find_eexec_data(data : BytesView) -> Int? {
  // Use a parser to avoid catching "eexec" in a comment or string
  // which apparently occurs in some fonts.
  let parser = T1Parser::new(data)
  while parser.next() is Some(token) {
    if !raw_is(Some(token), "eexec") {
      continue
    }
    let mut start = parser.pos
    // FreeType has some unfun logic for skipping whitespace
    // after the eexec token
    let mut linefeed_pos : Int? = None
    while start < data.length() {
      let c = data[start]
      if c == b' ' || c == b'\t' {
        ()
      } else if c == b'\n' {
        linefeed_pos = Some(start)
      } else if c == b'\r' {
        // If we've already seen \n or there is not a \n later
        // in the data, then stop at this \r
        let lp = match linefeed_pos {
          Some(lp) => lp
          None => {
            let mut found = 0
            for i in start..<data.length() {
              if data[i] == b'\n' {
                found = i
                break
              }
            }
            linefeed_pos = Some(found)
            found
          }
        }
        if lp < start {
          break
        }
      } else {
        break
      }
      start += 1
    }
    if start == data.length() {
      // eexec not properly terminated
      return None
    }
    return Some(start)
  }
  None
}

///|
/// Converts digits (as ASCII characters) into integer values.
let digit_to_num : FixedArray[Int] = [
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1, -1, -1, -1, -1,
  -1, -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
  28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1, -1, 10, 11, 12, 13, 14, 15,
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
  -1, -1, -1, -1, -1,
]

///|
/// Converts hex formatted data to associated bytes (collected until the
/// upstream iterator yields `None`).
fn decode_hex(bytes : BytesView) -> Bytes {
  let out = Buffer()
  let mut pad = 1U
  let mut pos = 0
  while true {
    // One call of the upstream iterator closure.
    let mut produced : Int? = None
    while pos < bytes.length() {
      let c = bytes[pos]
      pos += 1
      if is_t1_whitespace(c) {
        continue
      }
      if c.to_int() >= 0x80 {
        break
      }
      let c = digit_to_num[c.to_int() & 0x7F]
      // `as u32`: -1 becomes u32::MAX which is >= 16
      if c < 0 || c >= 16 {
        break
      }
      pad = (pad << 4) | c.reinterpret_as_uint()
      if (pad & 0x100U) != 0 {
        let res = (pad & 0xFFU).reinterpret_as_int()
        pad = 1
        produced = Some(res)
        break
      }
    }
    match produced {
      Some(b) => out.write_byte(b.to_byte())
      None =>
        if pad != 1U {
          let res = ((pad << 4) & 0xFFU).reinterpret_as_int()
          pad = 1
          out.write_byte(res.to_byte())
        } else {
          break
        }
    }
  }
  out.to_bytes()
}

///|
/// Decryption seed for eexec segment.
const EEXEC_SEED : UInt = 55665

///|
/// Decryption seed for charstring (and subroutine) data.
const CHARSTRING_SEED : UInt = 4330

///|
/// Returns the decrypted bytes, skipping the first `skip` bytes.
fn decrypt_skip(bytes : BytesView, seed : UInt, skip : Int) -> Bytes {
  let out = Buffer()
  decrypt_into(bytes, seed, skip, out)
  out.to_bytes()
}

///|
fn decrypt_into(
  bytes : BytesView,
  seed : UInt,
  skip : Int,
  out : Buffer,
) -> Unit {
  let mut seed = seed
  for i, b in bytes {
    let b = b.to_uint()
    let plain = b ^ (seed >> 8)
    seed = ((b + seed) * 52845U + 22719U) & 0xFFFFU
    if i >= skip {
      out.write_byte((plain & 0xFFU).reinterpret_as_int().to_byte())
    }
  }
}

///|
fn is_t1_whitespace(c : Byte) -> Bool {
  c == b' ' ||
  c == b'\n' ||
  c == b'\r' ||
  c == b'\t' ||
  c == b'\x00' ||
  c == b'\x0C'
}

///|
/// Characters that always delimit tokens.
fn is_special(c : Byte) -> Bool {
  c == b'(' ||
  c == b')' ||
  c == b'<' ||
  c == b'>' ||
  c == b'[' ||
  c == b']' ||
  c == b'{' ||
  c == b'}' ||
  c == b'/' ||
  c == b'%'
}

///|
fn is_special_or_whitespace(c : Byte) -> Bool {
  is_special(c) || is_t1_whitespace(c)
}

///|
priv enum T1Token {
  /// Integers
  TInt(Int64)
  /// Literal strings, delimited by ()
  LitString(BytesView)
  /// Hex strings, delimited by <>
  HexString(BytesView)
  /// Procedures, delimited by {}
  Proc(BytesView)
  /// Binary blobs
  Binary(BytesView)
  /// Names, preceded by /
  TName(BytesView)
  /// All other raw tokens (identifiers and self-delimiting punctuation)
  Raw(BytesView)
}

///|
fn T1Token::equals(self : T1Token, other : T1Token) -> Bool {
  match (self, other) {
    (TInt(a), TInt(b)) => a == b
    (LitString(a), LitString(b))
    | (HexString(a), HexString(b))
    | (Proc(a), Proc(b))
    | (Binary(a), Binary(b))
    | (TName(a), TName(b))
    | (Raw(a), Raw(b)) => a == b
    _ => false
  }
}

///|
/// Collection of subroutines.
priv struct Subrs {
  /// Packed data for all subroutines.
  data : Buffer
  /// Index mapping subroutine number to range in the packed data. Sorted
  /// by subroutine number.
  index : Array[(UInt, Int, Int)]
  /// If true, subroutine number == index so we don't need to bsearch.
  mut is_dense : Bool
  mut bytes : Bytes
}

///|
fn Subrs::new() -> Subrs {
  { data: Buffer(), index: [], is_dense: false, bytes: b"", }
}

///|
fn Subrs::get(self : Subrs, index : UInt) -> BytesView? {
  let entry_idx = if self.is_dense {
    if index > 0x7FFFFFFFU {
      return None
    }
    index.reinterpret_as_int()
  } else {
    let mut lo = 0
    let mut hi = self.index.length()
    let mut found = -1
    while lo < hi {
      let mid = lo + (hi - lo) / 2
      let (n, _, _) = self.index[mid]
      if n < index {
        lo = mid + 1
      } else if n > index {
        hi = mid
      } else {
        found = mid
        break
      }
    }
    if found < 0 {
      return None
    }
    found
  }
  guard self.index.get(entry_idx) is Some((_, start, end)) else { return None }
  Some(self.bytes[start:end])
}

///|
priv struct CharstringEntry {
  name_start : Int
  name_end : Int
  data_start : Int
  data_end : Int
}

///|
/// Collection of charstrings.
priv struct Charstrings {
  /// Packed data for all charstrings.
  data : Buffer
  /// Packed data for all glyph names.
  names : Buffer
  /// Index containing all charstrings.
  index : Array[CharstringEntry]
  /// If notdef was remapped, holds the original index of the notdef
  /// charstring.
  mut orig_notdef_index : Int?
  mut data_bytes : Bytes
  mut names_bytes : Bytes
}

///|
fn Charstrings::new() -> Charstrings {
  {
    data: Buffer(),
    names: Buffer(),
    index: [],
    orig_notdef_index: None,
    data_bytes: b"",
    names_bytes: b"",
  }
}

///|
fn Charstrings::finish(self : Charstrings) -> Unit {
  self.data_bytes = self.data.to_bytes()
  self.names_bytes = self.names.to_bytes()
}

///|
fn Charstrings::get(self : Charstrings, index : Int) -> BytesView? {
  guard self.index.get(index) is Some(e) else { return None }
  Some(self.data_bytes[e.data_start:e.data_end])
}

///|
fn Charstrings::name(self : Charstrings, index : Int) -> String? {
  guard self.index.get(index) is Some(e) else { return None }
  let bytes = self.names_bytes[e.name_start:e.name_end]
  try @utf8.decode(bytes, ignore_bom=false) catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
fn Charstrings::index_for_name(self : Charstrings, name : String) -> Int? {
  for idx, entry in self.index {
    let bytes = self.names_bytes[entry.name_start:entry.name_end]
    if utf8_eq(bytes, name) {
      return Some(idx)
    }
  }
  None
}

///|
fn utf8_eq(bytes : BytesView, s : String) -> Bool {
  // Names are compared as UTF-8 byte strings.
  let enc = @utf8.encode(s)
  bytes == enc[:]
}

///|
fn Charstrings::push(
  self : Charstrings,
  name : BytesView,
  data : BytesView,
  len_iv : Int64,
) -> Unit {
  let start = self.data.length()
  if len_iv >= 0L {
    // use decryption; skip first len_iv bytes
    let skip = if len_iv > 0x7FFFFFFFL { 0x7FFFFFFF } else { len_iv.to_int() }
    decrypt_into(data, CHARSTRING_SEED, skip, self.data)
  } else {
    // just add the data
    self.data.write_bytesview(data)
  }
  let end = self.data.length()
  let name_start = self.names.length()
  self.names.write_bytesview(name)
  let name_end = self.names.length()
  self.index.push({ name_start, name_end, data_start: start, data_end: end, })
}

///|
/// Encoding that maps characters to glyph identifiers.
priv enum T1RawEncoding {
  Predefined(PredefinedEncoding)
  Custom(Array[GlyphId])
}

///|
/// Simulated .notdef glyph, same as FreeType:
///
/// 0 333 hsbw endchar
let notdef_glyph : Bytes = b"\x8B\xF7\xE1\x0D\x0E"

///|
priv struct T1Parser {
  data : BytesView
  mut pos : Int
}

///|
fn T1Parser::new(data : BytesView) -> T1Parser {
  { data, pos: 0, }
}

///|
fn T1Parser::clone(self : T1Parser) -> T1Parser {
  { data: self.data, pos: self.pos, }
}

///|
fn T1Parser::get(self : T1Parser, start : Int, end : Int) -> BytesView? {
  get_range(self.data, start, end)
}

///|
fn T1Parser::next(self : T1Parser) -> T1Token? {
  // Roughly follows the logic of ps_parser_skip_PS_token
  while true {
    guard self.skip_whitespace() else { return None }
    let start = self.pos
    guard self.next_byte() is Some(c) else { return None }
    if c == b'%' {
      // Line comment
      self.skip_line()
    } else if c == b'{' {
      // Procedures
      return self.read_proc(start)
    } else if c == b'(' {
      // Literal strings
      return self.read_lit_string(start)
    } else if c == b'<' {
      if self.peek_byte() == Some(b'<') {
        // Just ignore these
        self.pos += 1
        continue
      }
      // Hex string: hex digits and whitespace
      return self.read_hex_string(start)
    } else if c == b'>' {
      // We consume single '>' when parsing hex strings so a
      // double >> is expected here
      guard self.next_byte() is Some(c2) else { return None }
      if c2 != b'>' {
        return None
      }
    } else if c == b'/' {
      // Name
      if self.peek_byte() is Some(c) {
        if is_t1_whitespace(c) || is_special(c) {
          if !is_special(c) {
            self.pos += 1
          }
          return Some(TName(b""[:]))
        } else {
          let count = self.skip_until(is_special_or_whitespace)
          return match self.get(start + 1, start + count) {
            Some(b) => Some(TName(b))
            None => None
          }
        }
      }
    } else if c == b'[' || c == b']' {
      // Brackets
      return match self.get(start, start + 1) {
        Some(b) => Some(Raw(b))
        None => None
      }
    } else {
      let count = self.skip_until(is_special_or_whitespace)
      guard self.get(start, start + count) is Some(content) else { return None }
      // Look for numbers but don't try to parse fractional
      // values since we want to handle those with special
      // precision
      if (is_ascii_digit(c) || c == b'-') && !bytes_contains(content, b'.') {
        if decode_int(content) is Some(int) {
          // HACK: if we have an int followed by RD or -|
          // then is a binary blob in Type1.
          let peeked = self.peek()
          if raw_is(peeked, "RD") || raw_is(peeked, "-|") {
            // skip the token
            ignore(self.next())
            // and a single space
            self.pos += 1
            // read the internal data
            guard self.read_bytes(int) is Some(data) else { return None }
            // there's often some form of terminator here
            // but let the calling code handle it because
            // some buggy fonts may omit it
            return Some(Binary(data))
          }
          return Some(TInt(int))
        }
      }
      return Some(Raw(content))
    }
  }
  None
}

///|
fn bytes_contains(b : BytesView, c : Byte) -> Bool {
  for x in b {
    if x == c {
      return true
    }
  }
  false
}

///|
fn T1Parser::peek(self : T1Parser) -> T1Token? {
  self.clone().next()
}

///|
fn T1Parser::accept(self : T1Parser, token : T1Token) -> Bool {
  if self.peek() is Some(t) && t.equals(token) {
    ignore(self.next())
    true
  } else {
    false
  }
}

///|
fn T1Parser::expect(self : T1Parser, token : T1Token) -> Bool {
  match self.next() {
    Some(t) => t.equals(token)
    None => false
  }
}

///|
fn T1Parser::next_byte(self : T1Parser) -> Byte? {
  guard self.peek_byte() is Some(byte) else { return None }
  self.pos += 1
  Some(byte)
}

///|
fn T1Parser::peek_byte(self : T1Parser) -> Byte? {
  if self.pos >= 0 && self.pos < self.data.length() {
    Some(self.data[self.pos])
  } else {
    None
  }
}

///|
fn T1Parser::read_bytes(self : T1Parser, len : Int64) -> BytesView? {
  // `len as usize` for negative values is huge, so the add overflows
  if len < 0L {
    return None
  }
  let end = self.pos.to_int64() + len
  if end > self.data.length().to_int64() {
    return None
  }
  let content = self.data[self.pos:end.to_int()]
  self.pos = end.to_int()
  Some(content)
}

///|
/// Returns false if the end of data was reached (`None` upstream).
fn T1Parser::skip_whitespace(self : T1Parser) -> Bool {
  while true {
    guard self.peek_byte() is Some(c) else { return false }
    if !is_t1_whitespace(c) {
      return true
    }
    self.pos += 1
  }
  true
}

///|
fn T1Parser::skip_line(self : T1Parser) -> Unit {
  while self.next_byte() is Some(c) {
    if c == b'\n' || c == b'\r' {
      break
    }
  }
}

///|
fn T1Parser::skip_until(self : T1Parser, f : (Byte) -> Bool) -> Int {
  let mut count = 0
  while self.peek_byte() is Some(byte) {
    if f(byte) {
      break
    }
    self.pos += 1
    count += 1
  }
  count + 1
}

///|
fn T1Parser::read_proc(self : T1Parser, start : Int) -> T1Token? {
  while true {
    guard self.next_byte() is Some(c) else { return None }
    if c == b'}' {
      break
    }
    // This handles nested procedures
    guard self.next() is Some(_) else { return None }
    ignore(self.skip_whitespace())
  }
  let end = self.pos
  if self.get(end - 1, end) is Some(b) && b[0] == b'}' {
    match self.get(start + 1, end - 1) {
      Some(b) => Some(Proc(b))
      None => None
    }
  } else {
    // unterminated procedure
    None
  }
}

///|
fn T1Parser::read_lit_string(self : T1Parser, start : Int) -> T1Token? {
  let mut nest_depth = 1
  while self.next_byte() is Some(c) {
    if c == b'(' {
      nest_depth += 1
    } else if c == b')' {
      nest_depth -= 1
      if nest_depth == 0 {
        break
      }
    } else if c == b'\\' {
      // Just eat the next byte. We only care
      // about avoiding \( and \) anyway.
      guard self.next_byte() is Some(_) else { return None }
    }
  }
  if nest_depth != 0 {
    // unterminated string
    return None
  }
  let end = self.pos
  self.pos += 1
  match self.get(start + 1, end - 1) {
    Some(b) => Some(LitString(b))
    None => None
  }
}

///|
fn T1Parser::read_hex_string(self : T1Parser, start : Int) -> T1Token? {
  while self.next_byte() is Some(c) {
    if !is_t1_whitespace(c) && !is_ascii_hexdigit(c) {
      break
    }
  }
  let end = self.pos
  if !(self.get(end - 1, end) is Some(b) && b[0] == b'>') {
    // unterminated hex string
    return None
  }
  match self.get(start + 1, end - 1) {
    Some(b) => Some(HexString(b))
    None => None
  }
}

///|
fn T1Parser::read_int(self : T1Parser) -> Int64? {
  match self.next() {
    Some(TInt(n)) => Some(n)
    _ => None
  }
}

///|
fn T1Parser::read_num_as_int(self : T1Parser) -> Int? {
  match self.next() {
    Some(TInt(n)) => Some(n.to_int())
    // Note, FT calls PS_Conv_ToInt for fields that might contain
    // fractional bits but just ignores everything after the
    // initial integer, so we do the same
    Some(Raw(bytes)) =>
      match decode_int_prefix(bytes, 0) {
        Some((n, _)) => Some(n.to_int())
        None => None
      }
    _ => None
  }
}

///|
fn T1Parser::read_string(self : T1Parser) -> String? {
  let bytes = match self.next() {
    // FreeType accepts a name or a string here
    Some(TName(bytes)) | Some(LitString(bytes)) => bytes
    _ => return None
  }
  try @utf8.decode(bytes, ignore_bom=false) catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
/// Parse a font matrix.
///
/// Like FreeType, this is designed assuming a upem of 1000 and produces
/// an identity matrix in that case.
fn T1Parser::read_font_matrix(self : T1Parser) -> ScaledFontMatrix? {
  let components = FixedArray::make(6, Fixed::zero())
  // accept [ or { to match FreeType
  if !self.accept(Raw(b"["[:])) {
    guard self.expect(Raw(b"{"[:])) else { return None }
  }
  // read all components
  for i in 0..<6 {
    components[i] = match self.next() {
      Some(TInt(int)) => {
        let v = int.to_int().to_int64() * 1000L
        if v > 2147483647L || v < -2147483648L {
          return None
        }
        Fixed::from_i32(v.to_int())
      }
      Some(Raw(bytes)) =>
        match decode_fixed(bytes, 3) {
          Some(v) => v
          None => return None
        }
      _ => return None
    }
  }
  // FreeType doesn't validate the closing delimiter, so just skip
  guard self.next() is Some(_) else { return None }
  let temp_scale = components[3].abs()
  if temp_scale == Fixed::zero() {
    return None
  }
  let mut upem = 1000
  if temp_scale != Fixed::one() {
    upem = (Fixed::from_bits(1000) / temp_scale).to_bits()
    components[0] = components[0] / temp_scale
    components[1] = components[1] / temp_scale
    components[2] = components[2] / temp_scale
    // don't scale components[3]
    components[4] = components[4] / temp_scale
    components[5] = components[5] / temp_scale
    if components[3] < Fixed::zero() {
      components[3] = -Fixed::one()
    } else {
      components[3] = Fixed::one()
    }
  }
  // offsets must be expressed in integer font units
  for i in 4..<6 {
    components[i] = Fixed::from_bits(components[i].to_bits() >> 16)
  }
  let matrix = FontMatrix::from_elements(components)
  if is_degenerate(matrix) {
    return None
  }
  Some({ matrix, scale: upem, })
}

///|
/// Parse the set of subroutines.
fn T1Parser::read_subrs(self : T1Parser, len_iv : Int64) -> Subrs? {
  let subrs = Subrs::new()
  match self.next() {
    Some(Raw(b)) if bytes_eq(b, "[") => {
      // Just an empty array
      guard self.expect(Raw(b"]"[:])) else { return None }
      subrs.bytes = subrs.data.to_bytes()
      return Some(subrs)
    }
    Some(TInt(n)) => if n < 0L { return None }
    _ => return None
  }
  guard self.expect(Raw(b"array"[:])) else { return None }
  let mut is_dense = true
  // The pattern for each subroutine is `dup <subr_num> <data>`
  while self.accept(Raw(b"dup"[:])) {
    guard self.next() is Some(t1) else { return None }
    guard self.next() is Some(t2) else { return None }
    guard (t1, t2) is (TInt(n), Binary(data)) else { return None }
    // Skip the NP, | or noaccess. FreeType just skips whatever happens
    // to be here
    ignore(self.next())
    // There might be an additional put token following the binary data
    ignore(self.accept(Raw(b"put"[:])))
    if n < 0L || n > 0xFFFFFFFFL {
      return None
    }
    let subr_num = n.reinterpret_as_uint64().to_uint()
    if subr_num.to_int64() != subrs.index.length().to_int64() {
      is_dense = false
    }
    let start = subrs.data.length()
    if len_iv >= 0L {
      // use decryption; skip first len_iv bytes
      let skip = if len_iv > 0x7FFFFFFFL { 0x7FFFFFFF } else { len_iv.to_int() }
      decrypt_into(data, CHARSTRING_SEED, skip, subrs.data)
    } else {
      // just add the data
      subrs.data.write_bytesview(data)
    }
    let end = subrs.data.length()
    subrs.index.push((subr_num, start, end))
  }
  // If we don't have a dense set, sort the index by number
  if !is_dense {
    subrs.index.sort_by((a, b) => a.0.compare(b.0))
  }
  subrs.is_dense = is_dense
  subrs.bytes = subrs.data.to_bytes()
  Some(subrs)
}

///|
/// Parse the set of charstrings.
fn T1Parser::read_charstrings(self : T1Parser, len_iv : Int64) -> Charstrings? {
  let charstrings = Charstrings::new()
  match self.next() {
    Some(TInt(n)) => if n < 0L { return None }
    _ => return None
  }
  let mut notdef_idx : Int? = None
  while self.next() is Some(token) {
    let name = match token {
      // Stop when we find a `def` or `end` keyword.
      Raw(b) if bytes_eq(b, "end") => {
        let at_delim = match self.peek_byte() {
          Some(c) => is_special_or_whitespace(c)
          None => false
        }
        if at_delim {
          break
        } else {
          continue
        }
      }
      Raw(b) if bytes_eq(b, "def") => {
        // but ignore `def` if no charstring has been seen
        let at_delim = match self.peek_byte() {
          Some(c) => is_special_or_whitespace(c)
          None => false
        }
        if at_delim && !charstrings.index.is_empty() {
          break
        } else {
          continue
        }
      }
      TName(name) => name
      _ => continue
    }
    if bytes_eq(name, ".notdef") {
      notdef_idx = Some(charstrings.index.length())
    }
    guard self.next() is Some(Binary(data)) else { return None }
    charstrings.push(name, data, len_iv)
  }
  match notdef_idx {
    Some(0) =>
      // .notdef found and at correct location
      ()
    Some(idx) => {
      // .notdef found but at incorrect location. Swap with the
      // glyph at 0
      charstrings.index.swap(0, idx)
      charstrings.orig_notdef_index = Some(idx)
    }
    None => {
      // .notdef not found. Add it to the end and then swap with
      // the glyph at 0
      let idx = charstrings.index.length()
      charstrings.push(b".notdef"[:], notdef_glyph[:], -1L)
      charstrings.index.swap(0, idx)
      charstrings.orig_notdef_index = Some(idx)
    }
  }
  charstrings.finish()
  Some(charstrings)
}

///|
fn T1Parser::read_font_bbox(self : T1Parser) -> FixedArray[Fixed]? {
  let bbox = FixedArray::make(4, Fixed::zero())
  // accept [ or { to match FreeType
  // Note that we parse { as a procedure so this needs some special
  // handling
  let parser = if self.accept(Raw(b"["[:])) {
    self
  } else {
    match self.next() {
      Some(Proc(proc)) => T1Parser::new(proc)
      _ => return None
    }
  }
  // read all components
  for i in 0..<4 {
    bbox[i] = match parser.next() {
      Some(TInt(int)) => Fixed::from_i32(int.to_int())
      Some(Raw(bytes)) =>
        match decode_fixed(bytes, 0) {
          Some(v) => v
          None => return None
        }
      _ => return None
    }
  }
  Some(bbox)
}

///|
fn T1Parser::read_weight_vector(self : T1Parser) -> Array[Fixed]? {
  ignore(self.accept(Raw(b"["[:])))
  let weights = []
  while self.next() is Some(token) {
    match token {
      Raw(b) if bytes_eq(b, "]") => break
      TInt(val) => weights.push(Fixed::from_i32(val.to_int()))
      Raw(raw) =>
        match decode_fixed(raw, 0) {
          Some(v) => weights.push(v)
          None => return None
        }
      _ => return None
    }
  }
  Some(weights)
}

///|
/// Parse the encoding.
fn T1Parser::read_encoding(
  self : T1Parser,
  charstrings : Charstrings,
) -> T1RawEncoding? {
  match self.next() {
    // Array of names where index == character code
    Some(Raw(b)) if bytes_eq(b, "[") => {
      // Should always be 256 entries but preset values to notdef
      let map = Array::make(256, GlyphId::notdef())
      ignore(
        self.read_dense_encoding(fn(idx, name) {
          if idx >= 0L && idx < map.length().to_int64() {
            if charstrings.index_for_name(name) is Some(gid) {
              map[idx.to_int()] = GlyphId::from_int(gid)
            }
          }
        }),
      )
      Some(Custom(map))
    }
    // Map of index to glyph name
    Some(TInt(count)) => {
      // We're limited to 256 character codes
      let count = if count < 0L {
        0
      } else if count > 256L {
        256
      } else {
        count.to_int()
      }
      // Start with all glyphs mapped to notdef
      let map = Array::make(count, GlyphId::notdef())
      ignore(
        self.read_sparse_encoding(fn(idx, name) {
          if idx >= 0L && idx < map.length().to_int64() {
            if charstrings.index_for_name(name) is Some(gid) {
              map[idx.to_int()] = GlyphId::from_int(gid)
            }
          }
        }),
      )
      Some(Custom(map))
    }
    Some(Raw(b)) if bytes_eq(b, "StandardEncoding") =>
      Some(Predefined(Standard))
    Some(Raw(b)) if bytes_eq(b, "ExpertEncoding") => Some(Predefined(Expert))
    Some(Raw(b)) if bytes_eq(b, "ISOLatin1Encoding") =>
      Some(Predefined(IsoLatin1))
    _ => None
  }
}

///|
/// Returns a custom encoding defined by an array of `/<name>`, where
/// the index represents the character code, and invokes the given
/// callback for each.
fn T1Parser::read_dense_encoding(
  self : T1Parser,
  f : (Int64, String) -> Unit,
) -> Unit? {
  // Eat the opening brace if present
  ignore(self.accept(Raw(b"["[:])))
  let mut idx = 0L
  while self.next() is Some(token) {
    match token {
      Raw(b) if bytes_eq(b, "]") => break
      TName(name) => {
        let code = idx
        idx += 1L
        let name = @utf8.decode(name, ignore_bom=false) catch { _ => continue }
        f(code, name)
      }
      // FreeType fails if missing a literal name here
      _ => return None
    }
  }
  Some(())
}

///|
/// Reads a custom encoding defined by a map of `<charcode> /<name>`
/// and invokes the given callback for each.
fn T1Parser::read_sparse_encoding(
  self : T1Parser,
  f : (Int64, String) -> Unit,
) -> Unit? {
  while self.next() is Some(token) {
    match token {
      // The 'def' keyword ends the mapping
      Raw(b) if bytes_eq(b, "def") => break
      TInt(code) => {
        // read the name
        guard self.next() is Some(TName(name)) else { continue }
        let name = @utf8.decode(name, ignore_bom=false) catch { _ => continue }
        f(code, name)
      }
      _ => ()
    }
  }
  Some(())
}

///|
/// Rust `str::parse::<i64>` / `i64::from_str_radix` on ASCII bytes.
fn parse_i64_radix(b : BytesView, radix : Int) -> Int64? {
  if b.length() == 0 {
    return None
  }
  let mut i = 0
  let mut neg = false
  if b[0] == b'+' || b[0] == b'-' {
    neg = b[0] == b'-'
    i = 1
    if b.length() == 1 {
      return None
    }
  }
  // Accumulate negatively to cover i64::MIN
  let mut acc = 0L
  let r = radix.to_int64()
  let min = -9223372036854775807L - 1L
  while i < b.length() {
    let c = b[i].to_int()
    let d = if c >= 0x30 && c <= 0x39 {
      c - 0x30
    } else if c >= 0x61 && c <= 0x7A {
      c - 0x61 + 10
    } else if c >= 0x41 && c <= 0x5A {
      c - 0x41 + 10
    } else {
      return None
    }
    if d >= radix {
      return None
    }
    // acc * r - d without overflow
    if acc < min / r {
      return None
    }
    let t = acc * r
    if t < min + d.to_int64() {
      return None
    }
    acc = t - d.to_int64()
    i += 1
  }
  if neg {
    Some(acc)
  } else if acc == min {
    None
  } else {
    Some(-acc)
  }
}

///|
/// Decode an integer, optionally with a base.
fn decode_int(bytes : BytesView) -> Int64? {
  // `std::str::from_utf8(bytes).ok()?`
  let valid = @utf8.decode(bytes, ignore_bom=false) catch { _ => return None }
  ignore(valid)
  let mut hash_idx = -1
  for i in 0..<bytes.length() {
    if bytes[i] == b'#' {
      hash_idx = i
      break
    }
  }
  if hash_idx == 1 || hash_idx == 2 {
    // It's a radix number, like 8#40.
    let radix_str = bytes[0:hash_idx]
    let number_str = bytes[hash_idx + 1:]
    // `radix_str.parse::<u32>()`: an optional '+' followed by digits
    guard parse_i64_radix(radix_str, 10) is Some(radix) else { return None }
    if radix_str[0] == b'-' && radix != 0L {
      return None
    }
    if radix_str[0] == b'-' {
      // "-0" is not a valid u32
      return None
    }
    if radix < 2L || radix > 36L {
      return None
    }
    parse_i64_radix(number_str, radix.to_int())
  } else {
    parse_i64_radix(bytes, 10)
  }
}

///|
/// Decode an integer at the given position, returning the value and the
/// index of the position following the decoded integer.
fn decode_int_prefix(bytes : BytesView, start : Int) -> (Int64, Int)? {
  guard get_from(bytes, start) is Some(tail) else { return None }
  let mut end = tail.length()
  for i in 0..<tail.length() {
    let c = tail[i]
    if c != b'-' && !is_ascii_digit(c) {
      end = i
      break
    }
  }
  guard decode_int(tail[0:end]) is Some(int) else { return None }
  Some((int, start + end))
}

///|
/// Decode a fixed point value, scaling to a specific power of ten.
fn decode_fixed(bytes : BytesView, power_ten : Int) -> Fixed? {
  let limit = 0xCCCCCCC
  let mut power_ten = power_ten
  let mut idx = 0
  if bytes.length() == 0 {
    return None
  }
  let first = bytes[0]
  let sign = if first == b'-' || first == b'+' {
    idx += 1
    if first == b'-' {
      -1
    } else {
      1
    }
  } else {
    1
  }
  let overflow = Some(Fixed::from_bits(0x7FFFFFFF * sign))
  let mut integral = 0
  if idx >= bytes.length() {
    return None
  }
  if bytes[idx] != b'.' {
    guard decode_int_prefix(bytes, idx) is Some((int, end_idx)) else {
      return None
    }
    if int > 0x7FFFL {
      return overflow
    }
    integral = (int << 16).to_int()
    idx = end_idx
  }
  let mut decimal = 0
  let mut divider = 1
  if idx < bytes.length() && bytes[idx] == b'.' {
    idx += 1
    while idx < bytes.length() {
      let byte = bytes[idx]
      if !is_ascii_digit(byte) {
        break
      }
      let digit = byte.to_int() - 0x30
      if divider < limit && decimal < limit {
        decimal = decimal * 10 + digit
        if integral == 0 && power_ten > 0 {
          power_ten -= 1
        } else {
          divider *= 10
        }
      }
      idx += 1
    }
  }
  if idx < bytes.length() && (bytes[idx] == b'e' || bytes[idx] == b'E') {
    idx += 1
    guard decode_int_prefix(bytes, idx) is Some((exponent, _)) else {
      return None
    }
    if exponent > 1000L {
      return overflow
    } else if exponent < -1000L {
      // underflow
      return Some(Fixed::zero())
    } else {
      let p = power_ten.to_int64() + exponent
      if p > 2147483647L || p < -2147483648L {
        return None
      }
      power_ten = p.to_int()
    }
  }
  if integral == 0 && decimal == 0 {
    return Some(Fixed::zero())
  }
  while power_ten > 0 {
    if integral >= limit {
      return overflow
    }
    integral *= 10
    if decimal >= limit {
      if divider == 1 {
        return overflow
      }
      divider /= 10
    } else {
      decimal *= 10
    }
    power_ten -= 1
  }
  while power_ten < 0 {
    integral /= 10
    if divider < limit {
      divider *= 10
    } else {
      decimal /= 10
    }
    if integral == 0 && decimal == 0 {
      return Some(Fixed::zero())
    }
    power_ten += 1
  }
  if decimal != 0 {
    decimal = (Fixed::from_bits(decimal) / Fixed::from_bits(divider)).to_bits()
    integral += decimal
  }
  Some(Fixed::from_bits(integral * sign))
}
