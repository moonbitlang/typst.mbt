// Font faces.
//
// Port of `ttf-parser` 0.25.1 `src/lib.rs` (`RawFace`, `RawFaceTables`,
// `FaceTables`, `Face`, `fonts_in_collection`).

///|
let max_var_coords : Int = 64

///|
/// A raw font face.
///
/// You are probably looking for `Face`. This is a low-level type.
///
/// Unlike `Face`, `RawFace` parses only face table records.
/// Meaning all you can get from this type is a raw data of a requested table.
pub(all) struct RawFace {
  /// The input font file data.
  data : BytesView
  /// An array of table records.
  table_records : LazyArray16[TableRecord]
}

///|
/// Creates a new `RawFace` from a raw data.
///
/// `index` indicates the specific font face in a font collection.
/// Use `fonts_in_collection` to get the total number of font faces.
/// Set to 0 if unsure.
///
/// While we do reuse `FaceParsingError`, `No*Table` errors will not be throws.
pub fn RawFace::parse(
  data : BytesView,
  index : UInt,
) -> RawFace raise FaceParsingError {
  // https://docs.microsoft.com/en-us/typography/opentype/spec/otff#organization-of-an-opentype-font

  let s = Stream::new(data)

  // Read **font** magic.
  let magic : Magic = s.read() catch { _ => raise UnknownMagic }
  if magic == FontCollection {
    s.advance(4) // version
    let number_of_faces = s.read_u32() catch { _ => raise MalformedFont }
    let offsets : LazyArray32[Offset32] = s.read_array32(number_of_faces) catch {
      _ => raise MalformedFont
    }
    guard offsets.get(index) is Some(face_offset) else {
      raise FaceIndexOutOfBounds
    }
    // Face offset is from the start of the font data,
    // so we have to adjust it to the current parser offset.
    guard usize_checked_sub(face_offset.to_usize(), s.offset())
      is Some(face_offset) else {
      raise MalformedFont
    }
    s.advance_checked(face_offset) catch {
      _ => raise MalformedFont
    }

    // Read **face** magic.
    // Each face in a font collection also starts with a magic.
    let magic : Magic = s.read() catch { _ => raise UnknownMagic }
    // And face in a font collection can't be another collection.
    if magic == FontCollection {
      raise UnknownMagic
    }
  } else if index != 0 {
    // When reading from a regular font (not a collection) disallow index to be non-zero
    // Basically treat the font as a one-element collection
    raise FaceIndexOutOfBounds
  }
  let num_tables = s.read_u16() catch { _ => raise MalformedFont }
  s.advance(6) // searchRange (u16) + entrySelector (u16) + rangeShift (u16)
  let table_records = s.read_array16(num_tables) catch {
    _ => raise MalformedFont
  }
  { data, table_records, }
}

///|
/// Returns the raw data of a selected table.
pub fn RawFace::table(self : RawFace, tag : Tag) -> BytesView? {
  guard self.table_records.binary_search_by(record => record.tag.compare(tag))
    is Some((_, table)) else {
    return None
  }
  let offset = u32_to_usize(table.offset)
  let length = u32_to_usize(table.length)
  guard usize_checked_add(offset, length) is Some(end) else { return None }
  slice_get(self.data, offset, end)
}

///|
/// A list of all supported tables as raw data.
///
/// This type should be used in tandem with `Face::from_raw_tables()`.
pub(all) struct RawFaceTables {
  // Mandatory tables.
  mut head : BytesView
  mut hhea : BytesView
  mut maxp : BytesView
  mut bdat : BytesView?
  mut bloc : BytesView?
  mut cbdt : BytesView?
  mut cblc : BytesView?
  mut cff : BytesView?
  mut cmap : BytesView?
  mut colr : BytesView?
  mut cpal : BytesView?
  mut ebdt : BytesView?
  mut eblc : BytesView?
  mut glyf : BytesView?
  mut hmtx : BytesView?
  mut kern : BytesView?
  mut loca : BytesView?
  mut name : BytesView?
  mut os2 : BytesView?
  mut post : BytesView?
  mut sbix : BytesView?
  mut stat : BytesView?
  mut svg : BytesView?
  mut vhea : BytesView?
  mut vmtx : BytesView?
  mut vorg : BytesView?
  mut gdef : BytesView?
  mut gpos : BytesView?
  mut gsub : BytesView?
  mut math : BytesView?
  mut ankr : BytesView?
  mut feat : BytesView?
  mut kerx : BytesView?
  mut morx : BytesView?
  mut trak : BytesView?
  mut avar : BytesView?
  mut cff2 : BytesView?
  mut fvar : BytesView?
  mut gvar : BytesView?
  mut hvar : BytesView?
  mut mvar : BytesView?
  mut vvar : BytesView?
}

///|
pub impl Default for RawFaceTables with fn default() {
  {
    head: empty_data,
    hhea: empty_data,
    maxp: empty_data,
    bdat: None,
    bloc: None,
    cbdt: None,
    cblc: None,
    cff: None,
    cmap: None,
    colr: None,
    cpal: None,
    ebdt: None,
    eblc: None,
    glyf: None,
    hmtx: None,
    kern: None,
    loca: None,
    name: None,
    os2: None,
    post: None,
    sbix: None,
    stat: None,
    svg: None,
    vhea: None,
    vmtx: None,
    vorg: None,
    gdef: None,
    gpos: None,
    gsub: None,
    math: None,
    ankr: None,
    feat: None,
    kerx: None,
    morx: None,
    trak: None,
    avar: None,
    cff2: None,
    fvar: None,
    gvar: None,
    hvar: None,
    mvar: None,
    vvar: None,
  }
}

///|
/// Parsed face tables.
///
/// Unlike `Face`, provides a low-level parsing abstraction over TrueType tables.
/// Useful when you need a direct access to tables data.
///
/// Also, used when high-level API is problematic to implement.
/// A good example would be OpenType layout tables (GPOS/GSUB).
pub(all) struct FaceTables {
  // Mandatory tables.
  head : HeadTable
  hhea : HheaTable
  maxp : MaxpTable
  bdat : CbdtTable?
  cbdt : CbdtTable?
  cff : CffTable?
  cmap : CmapTable?
  colr : ColrTable?
  ebdt : CbdtTable?
  glyf : GlyfTable?
  hmtx : HmtxTable?
  kern : KernTable?
  name : NameTable?
  os2 : Os2Table?
  post : PostTable?
  sbix : SbixTable?
  stat : StatTable?
  svg : SvgTable?
  vhea : VheaTable?
  vmtx : HmtxTable?
  vorg : VorgTable?
  gdef : GdefTable?
  gpos : LayoutTable?
  gsub : LayoutTable?
  math : MathTable?
  ankr : AnkrTable?
  feat : FeatTable?
  kerx : KerxTable?
  morx : MorxTable?
  trak : TrakTable?
  avar : AvarTable?
  cff2 : Cff2Table?
  fvar : FvarTable?
  gvar : GvarTable?
  hvar : HvarTable?
  mvar : MvarTable?
  vvar : VvarTable?
}

///|
/// A font face.
///
/// Provides a high-level API for working with TrueType fonts.
/// If you're not familiar with how TrueType works internally, you should use this type.
/// If you do know and want a bit more low-level access - checkout `FaceTables`.
struct Face {
  raw_face : RawFace
  tables : FaceTables // Parsed tables.
  coordinates : Array[NormalizedCoordinate]
}

///|
/// Creates a new `Face` from a raw data.
///
/// `index` indicates the specific font face in a font collection.
/// Use `fonts_in_collection` to get the total number of font faces.
/// Set to 0 if unsure.
///
/// This method will do some parsing and sanitization,
/// but in general can be considered free. No significant performance overhead.
///
/// Required tables: `head`, `hhea` and `maxp`.
///
/// If an optional table has invalid data it will be skipped.
pub fn Face::parse(
  data : BytesView,
  index : UInt,
) -> Face raise FaceParsingError {
  let raw_face = RawFace::parse(data, index)
  let raw_tables = Face::collect_tables(raw_face)
  Face::new_with(raw_face, Face::parse_tables(raw_tables))
}

///|
fn Face::new_with(raw_face : RawFace, tables : FaceTables) -> Face {
  let len = match tables.fvar {
    Some(fvar) => {
      let n = fvar.axes.len().to_int()
      if n < max_var_coords {
        n
      } else {
        max_var_coords
      }
    }
    None => 0
  }
  { raw_face, tables, coordinates: Array::make(len, NormalizedCoordinate(0)), }
}

///|
fn Face::collect_tables(raw_face : RawFace) -> RawFaceTables {
  let tables = RawFaceTables::default()
  for record in raw_face.table_records.iter() {
    let start = u32_to_usize(record.offset)
    let end = match usize_checked_add(start, u32_to_usize(record.length)) {
      Some(v) => v
      None => continue
    }
    let table_data = slice_get(raw_face.data, start, end)
    match record.tag.to_string() {
      "bdat" => tables.bdat = table_data
      "bloc" => tables.bloc = table_data
      "CBDT" => tables.cbdt = table_data
      "CBLC" => tables.cblc = table_data
      "CFF " => tables.cff = table_data
      "CFF2" => tables.cff2 = table_data
      "COLR" => tables.colr = table_data
      "CPAL" => tables.cpal = table_data
      "EBDT" => tables.ebdt = table_data
      "EBLC" => tables.eblc = table_data
      "GDEF" => tables.gdef = table_data
      "GPOS" => tables.gpos = table_data
      "GSUB" => tables.gsub = table_data
      "MATH" => tables.math = table_data
      "HVAR" => tables.hvar = table_data
      "MVAR" => tables.mvar = table_data
      "OS/2" => tables.os2 = table_data
      "SVG " => tables.svg = table_data
      "VORG" => tables.vorg = table_data
      "VVAR" => tables.vvar = table_data
      "ankr" => tables.ankr = table_data
      "avar" => tables.avar = table_data
      "cmap" => tables.cmap = table_data
      "feat" => tables.feat = table_data
      "fvar" => tables.fvar = table_data
      "glyf" => tables.glyf = table_data
      "gvar" => tables.gvar = table_data
      "head" => tables.head = table_data.unwrap_or(empty_data)
      "hhea" => tables.hhea = table_data.unwrap_or(empty_data)
      "hmtx" => tables.hmtx = table_data
      "kern" => tables.kern = table_data
      "kerx" => tables.kerx = table_data
      "loca" => tables.loca = table_data
      "maxp" => tables.maxp = table_data.unwrap_or(empty_data)
      "morx" => tables.morx = table_data
      "name" => tables.name = table_data
      "post" => tables.post = table_data
      "sbix" => tables.sbix = table_data
      "STAT" => tables.stat = table_data
      "trak" => tables.trak = table_data
      "vhea" => tables.vhea = table_data
      "vmtx" => tables.vmtx = table_data
      _ => ()
    }
  }
  tables
}

///|
/// Creates a new `Face` from provided `RawFaceTables`.
pub fn Face::from_raw_tables(
  raw_tables : RawFaceTables,
) -> Face raise FaceParsingError {
  Face::new_with(
    { data: empty_data, table_records: LazyArray16::default(), },
    Face::parse_tables(raw_tables),
  )
}

///|
fn[T, U] and_then(x : T?, f : (T) -> U?) -> U? {
  match x {
    Some(v) => f(v)
    None => None
  }
}

///|
fn Face::parse_tables(
  raw_tables : RawFaceTables,
) -> FaceTables raise FaceParsingError {
  guard HeadTable::parse(raw_tables.head) is Some(head) else {
    raise NoHeadTable
  }
  guard HheaTable::parse(raw_tables.hhea) is Some(hhea) else {
    raise NoHheaTable
  }
  guard MaxpTable::parse(raw_tables.maxp) is Some(maxp) else {
    raise NoMaxpTable
  }
  let hmtx = and_then(raw_tables.hmtx, data => {
    HmtxTable::parse(hhea.number_of_metrics, maxp.number_of_glyphs, data)
  })
  let vhea = and_then(raw_tables.vhea, VheaTable::parse)
  let vmtx = if vhea is Some(vhea) {
    and_then(raw_tables.vmtx, data => {
      HmtxTable::parse(vhea.number_of_metrics, maxp.number_of_glyphs, data)
    })
  } else {
    None
  }
  let loca = and_then(raw_tables.loca, data => {
    LocaTable::parse(maxp.number_of_glyphs, head.index_to_location_format, data)
  })
  let glyf = if loca is Some(loca) {
    and_then(raw_tables.glyf, data => GlyfTable::parse(loca, data))
  } else {
    None
  }
  let bdat = if and_then(raw_tables.bloc, CblcTable::parse) is Some(bloc) {
    and_then(raw_tables.bdat, data => CbdtTable::parse(bloc, data))
  } else {
    None
  }
  let cbdt = if and_then(raw_tables.cblc, CblcTable::parse) is Some(cblc) {
    and_then(raw_tables.cbdt, data => CbdtTable::parse(cblc, data))
  } else {
    None
  }
  let ebdt = if and_then(raw_tables.eblc, CblcTable::parse) is Some(eblc) {
    and_then(raw_tables.ebdt, data => CbdtTable::parse(eblc, data))
  } else {
    None
  }
  let cpal = and_then(raw_tables.cpal, CpalTable::parse)
  let colr = if cpal is Some(cpal) {
    and_then(raw_tables.colr, data => ColrTable::parse(cpal, data))
  } else {
    None
  }
  {
    head,
    hhea,
    maxp,
    bdat,
    cbdt,
    cff: and_then(raw_tables.cff, CffTable::parse),
    cmap: and_then(raw_tables.cmap, CmapTable::parse),
    colr,
    ebdt,
    glyf,
    hmtx,
    kern: and_then(raw_tables.kern, KernTable::parse),
    name: and_then(raw_tables.name, NameTable::parse),
    os2: and_then(raw_tables.os2, Os2Table::parse),
    post: and_then(raw_tables.post, PostTable::parse),
    sbix: and_then(raw_tables.sbix, data => {
      SbixTable::parse(maxp.number_of_glyphs, data)
    }),
    stat: and_then(raw_tables.stat, StatTable::parse),
    svg: and_then(raw_tables.svg, SvgTable::parse),
    vhea: and_then(raw_tables.vhea, VheaTable::parse),
    vmtx,
    vorg: and_then(raw_tables.vorg, VorgTable::parse),
    gdef: and_then(raw_tables.gdef, GdefTable::parse),
    gpos: and_then(raw_tables.gpos, LayoutTable::parse),
    gsub: and_then(raw_tables.gsub, LayoutTable::parse),
    math: and_then(raw_tables.math, MathTable::parse),
    ankr: and_then(raw_tables.ankr, data => {
      AnkrTable::parse(maxp.number_of_glyphs, data)
    }),
    feat: and_then(raw_tables.feat, FeatTable::parse),
    kerx: and_then(raw_tables.kerx, data => {
      KerxTable::parse(maxp.number_of_glyphs, data)
    }),
    morx: and_then(raw_tables.morx, data => {
      MorxTable::parse(maxp.number_of_glyphs, data)
    }),
    trak: and_then(raw_tables.trak, TrakTable::parse),
    avar: and_then(raw_tables.avar, AvarTable::parse),
    cff2: and_then(raw_tables.cff2, Cff2Table::parse),
    fvar: and_then(raw_tables.fvar, FvarTable::parse),
    gvar: and_then(raw_tables.gvar, GvarTable::parse),
    hvar: and_then(raw_tables.hvar, HvarTable::parse),
    mvar: and_then(raw_tables.mvar, MvarTable::parse),
    vvar: and_then(raw_tables.vvar, VvarTable::parse),
  }
}

///|
/// Clones the face (the variation coordinates are copied).
pub fn Face::clone(self : Face) -> Face {
  {
    raw_face: self.raw_face,
    tables: self.tables,
    coordinates: self.coordinates.copy(),
  }
}

///|
/// Returns low-level face tables.
pub fn Face::tables(self : Face) -> FaceTables {
  self.tables
}

///|
/// Returns the `RawFace` used to create this `Face`.
///
/// Useful if you want to parse the data manually.
pub fn Face::raw_face(self : Face) -> RawFace {
  self.raw_face
}

///|
/// Returns a list of names.
///
/// Contains face name and other strings.
pub fn Face::names(self : Face) -> Names {
  self.tables.name.unwrap_or(NameTable::default()).names
}

///|
/// Checks that face is marked as *Regular*.
///
/// Returns `false` when OS/2 table is not present.
pub fn Face::is_regular(self : Face) -> Bool {
  self.style() == Normal
}

///|
/// Checks that face is marked as *Italic*.
pub fn Face::is_italic(self : Face) -> Bool {
  // A face can have a Normal style and a non-zero italic angle, which also makes it italic.
  self.style() == Italic || self.italic_angle() != 0.0
}

///|
/// Checks that face is marked as *Bold*.
///
/// Returns `false` when OS/2 table is not present.
pub fn Face::is_bold(self : Face) -> Bool {
  self.tables.os2.map(os2 => os2.is_bold()).unwrap_or(false)
}

///|
/// Checks that face is marked as *Oblique*.
///
/// Returns `false` when OS/2 table is not present or when its version is < 4.
pub fn Face::is_oblique(self : Face) -> Bool {
  self.style() == Oblique
}

///|
/// Returns face style.
pub fn Face::style(self : Face) -> Style {
  self.tables.os2.map(os2 => os2.style()).unwrap_or(Normal)
}

///|
/// Checks that face is marked as *Monospaced*.
///
/// Returns `false` when `post` table is not present.
pub fn Face::is_monospaced(self : Face) -> Bool {
  self.tables.post.map(post => post.is_monospaced).unwrap_or(false)
}

///|
/// Checks that face is variable.
///
/// Simply checks the presence of a `fvar` table.
pub fn Face::is_variable(self : Face) -> Bool {
  // `fvar::Table::parse` already checked that `axisCount` is non-zero.
  self.tables.fvar is Some(_)
}

///|
/// Returns face's weight.
///
/// Returns `Weight::Normal` when OS/2 table is not present.
pub fn Face::weight(self : Face) -> Weight {
  self.tables.os2.map(os2 => os2.weight()).unwrap_or(Normal)
}

///|
/// Returns face's width.
///
/// Returns `Width::Normal` when OS/2 table is not present or when value is invalid.
pub fn Face::width(self : Face) -> Width {
  self.tables.os2.map(os2 => os2.width()).unwrap_or(Normal)
}

///|
/// Returns face's italic angle.
///
/// Returns `0.0` when `post` table is not present.
pub fn Face::italic_angle(self : Face) -> Float {
  self.tables.post.map(table => table.italic_angle).unwrap_or(0.0)
}

// Read https://github.com/freetype/freetype/blob/49270c17011491227ec7bd3fb73ede4f674aa065/src/sfnt/sfobjs.c#L1279
// to learn more about the logic behind the following functions.

///|
/// Returns a horizontal face ascender.
///
/// This method is affected by variation axes.
pub fn Face::ascender(self : Face) -> Int16 {
  if self.tables.os2 is Some(os_2) {
    if os_2.use_typographic_metrics() {
      let value = os_2.typographic_ascender()
      return self.apply_metrics_variation(Tag::from_str("hasc"), value)
    }
  }
  let mut value = self.tables.hhea.ascender
  if value == 0 {
    if self.tables.os2 is Some(os_2) {
      value = os_2.typographic_ascender()
      if value == 0 {
        value = os_2.windows_ascender()
        value = self.apply_metrics_variation(Tag::from_str("hcla"), value)
      } else {
        value = self.apply_metrics_variation(Tag::from_str("hasc"), value)
      }
    }
  }
  value
}

///|
/// Returns a horizontal face descender.
///
/// This method is affected by variation axes.
pub fn Face::descender(self : Face) -> Int16 {
  if self.tables.os2 is Some(os_2) {
    if os_2.use_typographic_metrics() {
      let value = os_2.typographic_descender()
      return self.apply_metrics_variation(Tag::from_str("hdsc"), value)
    }
  }
  let mut value = self.tables.hhea.descender
  if value == 0 {
    if self.tables.os2 is Some(os_2) {
      value = os_2.typographic_descender()
      if value == 0 {
        value = os_2.windows_descender()
        value = self.apply_metrics_variation(Tag::from_str("hcld"), value)
      } else {
        value = self.apply_metrics_variation(Tag::from_str("hdsc"), value)
      }
    }
  }
  value
}

///|
/// Returns face's height.
///
/// This method is affected by variation axes.
pub fn Face::height(self : Face) -> Int16 {
  self.ascender() - self.descender()
}

///|
/// Returns a horizontal face line gap.
///
/// This method is affected by variation axes.
pub fn Face::line_gap(self : Face) -> Int16 {
  if self.tables.os2 is Some(os_2) {
    if os_2.use_typographic_metrics() {
      let value = os_2.typographic_line_gap()
      return self.apply_metrics_variation(Tag::from_str("hlgp"), value)
    }
  }
  let mut value = self.tables.hhea.line_gap
  // For line gap, we have to check that ascender or descender are 0, not line gap itself.
  if self.tables.hhea.ascender == 0 || self.tables.hhea.descender == 0 {
    if self.tables.os2 is Some(os_2) {
      if os_2.typographic_ascender() != 0 || os_2.typographic_descender() != 0 {
        value = os_2.typographic_line_gap()
        value = self.apply_metrics_variation(Tag::from_str("hlgp"), value)
      } else {
        value = 0
      }
    }
  }
  value
}

///|
/// Returns a horizontal typographic face ascender.
///
/// Prefer `Face::ascender` unless you explicitly want this. This is a more
/// low-level alternative.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present.
pub fn Face::typographic_ascender(self : Face) -> Int16? {
  self.tables.os2.map(table => {
    let v = table.typographic_ascender()
    self.apply_metrics_variation(Tag::from_str("hasc"), v)
  })
}

///|
/// Returns a horizontal typographic face descender.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present.
pub fn Face::typographic_descender(self : Face) -> Int16? {
  self.tables.os2.map(table => {
    let v = table.typographic_descender()
    self.apply_metrics_variation(Tag::from_str("hdsc"), v)
  })
}

///|
/// Returns a horizontal typographic face line gap.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present.
pub fn Face::typographic_line_gap(self : Face) -> Int16? {
  self.tables.os2.map(table => {
    let v = table.typographic_line_gap()
    self.apply_metrics_variation(Tag::from_str("hlgp"), v)
  })
}

///|
/// Returns a vertical face ascender.
///
/// This method is affected by variation axes.
pub fn Face::vertical_ascender(self : Face) -> Int16? {
  self.tables.vhea
  .map(vhea => vhea.ascender)
  .map(v => self.apply_metrics_variation(Tag::from_str("vasc"), v))
}

///|
/// Returns a vertical face descender.
///
/// This method is affected by variation axes.
pub fn Face::vertical_descender(self : Face) -> Int16? {
  self.tables.vhea
  .map(vhea => vhea.descender)
  .map(v => self.apply_metrics_variation(Tag::from_str("vdsc"), v))
}

///|
/// Returns a vertical face height.
///
/// This method is affected by variation axes.
pub fn Face::vertical_height(self : Face) -> Int16? {
  guard self.vertical_ascender() is Some(a) else { return None }
  guard self.vertical_descender() is Some(d) else { return None }
  Some(a - d)
}

///|
/// Returns a vertical face line gap.
///
/// This method is affected by variation axes.
pub fn Face::vertical_line_gap(self : Face) -> Int16? {
  self.tables.vhea
  .map(vhea => vhea.line_gap)
  .map(v => self.apply_metrics_variation(Tag::from_str("vlgp"), v))
}

///|
/// Returns face's units per EM.
///
/// Guarantee to be in a 16..=16384 range.
pub fn Face::units_per_em(self : Face) -> UInt16 {
  self.tables.head.units_per_em
}

///|
/// Returns face's x height.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present or when its version is < 2.
pub fn Face::x_height(self : Face) -> Int16? {
  and_then(self.tables.os2, os_2 => os_2.x_height()).map(v => {
    self.apply_metrics_variation(Tag::from_str("xhgt"), v)
  })
}

///|
/// Returns face's capital height.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present or when its version is < 2.
pub fn Face::capital_height(self : Face) -> Int16? {
  and_then(self.tables.os2, os_2 => os_2.capital_height()).map(v => {
    self.apply_metrics_variation(Tag::from_str("cpht"), v)
  })
}

///|
/// Returns face's underline metrics.
///
/// This method is affected by variation axes.
///
/// Returns `None` when `post` table is not present.
pub fn Face::underline_metrics(self : Face) -> LineMetrics? {
  guard self.tables.post is Some(post) else { return None }
  let metrics : LineMetrics = {
    position: post.underline_metrics.position,
    thickness: post.underline_metrics.thickness,
  }
  if self.is_variable() {
    metrics.position = self.apply_metrics_variation(
      Tag::from_str("undo"),
      metrics.position,
    )
    metrics.thickness = self.apply_metrics_variation(
      Tag::from_str("unds"),
      metrics.thickness,
    )
  }
  Some(metrics)
}

///|
/// Returns face's strikeout metrics.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present.
pub fn Face::strikeout_metrics(self : Face) -> LineMetrics? {
  guard self.tables.os2 is Some(os2) else { return None }
  let metrics = os2.strikeout_metrics()
  if self.is_variable() {
    metrics.position = self.apply_metrics_variation(
      Tag::from_str("stro"),
      metrics.position,
    )
    metrics.thickness = self.apply_metrics_variation(
      Tag::from_str("strs"),
      metrics.thickness,
    )
  }
  Some(metrics)
}

///|
/// Returns face's subscript metrics.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present.
pub fn Face::subscript_metrics(self : Face) -> ScriptMetrics? {
  guard self.tables.os2 is Some(os2) else { return None }
  let metrics = os2.subscript_metrics()
  if self.is_variable() {
    metrics.x_size = self.apply_metrics_variation(
      Tag::from_str("sbxs"),
      metrics.x_size,
    )
    metrics.y_size = self.apply_metrics_variation(
      Tag::from_str("sbys"),
      metrics.y_size,
    )
    metrics.x_offset = self.apply_metrics_variation(
      Tag::from_str("sbxo"),
      metrics.x_offset,
    )
    metrics.y_offset = self.apply_metrics_variation(
      Tag::from_str("sbyo"),
      metrics.y_offset,
    )
  }
  Some(metrics)
}

///|
/// Returns face's superscript metrics.
///
/// This method is affected by variation axes.
///
/// Returns `None` when OS/2 table is not present.
pub fn Face::superscript_metrics(self : Face) -> ScriptMetrics? {
  guard self.tables.os2 is Some(os2) else { return None }
  let metrics = os2.superscript_metrics()
  if self.is_variable() {
    metrics.x_size = self.apply_metrics_variation(
      Tag::from_str("spxs"),
      metrics.x_size,
    )
    metrics.y_size = self.apply_metrics_variation(
      Tag::from_str("spys"),
      metrics.y_size,
    )
    metrics.x_offset = self.apply_metrics_variation(
      Tag::from_str("spxo"),
      metrics.x_offset,
    )
    metrics.y_offset = self.apply_metrics_variation(
      Tag::from_str("spyo"),
      metrics.y_offset,
    )
  }
  Some(metrics)
}

///|
/// Returns face permissions.
///
/// Returns `None` in case of a malformed value.
pub fn Face::permissions(self : Face) -> Permissions? {
  and_then(self.tables.os2, os2 => os2.permissions())
}

///|
/// Checks if the face allows embedding a subset, further restricted by `permissions`.
pub fn Face::is_subsetting_allowed(self : Face) -> Bool {
  self.tables.os2.map(t => t.is_subsetting_allowed()).unwrap_or(false)
}

///|
/// Checks if the face allows outline data to be embedded.
///
/// If false, only bitmaps may be embedded in accordance with `permissions`.
///
/// If the font contains no bitmaps and this flag is not set, it implies no embedding is allowed.
pub fn Face::is_outline_embedding_allowed(self : Face) -> Bool {
  self.tables.os2.map(t => t.is_outline_embedding_allowed()).unwrap_or(false)
}

///|
/// Returns [Unicode Ranges](https://docs.microsoft.com/en-us/typography/opentype/spec/os2#ur).
pub fn Face::unicode_ranges(self : Face) -> UnicodeRanges {
  self.tables.os2
  .map(t => t.unicode_ranges())
  .unwrap_or(UnicodeRanges::default())
}

///|
/// Returns a total number of glyphs in the face.
///
/// Never zero.
///
/// The value was already parsed, so this function doesn't involve any parsing.
pub fn Face::number_of_glyphs(self : Face) -> UInt16 {
  self.tables.maxp.number_of_glyphs
}

///|
/// Resolves a Glyph ID for a code point.
///
/// Returns `None` instead of `0` when glyph is not found.
///
/// All subtable formats except Mixed Coverage (8) are supported.
///
/// If you need a more low-level control, prefer `Face::tables().cmap`.
pub fn Face::glyph_index(self : Face, code_point : Char) -> GlyphId? {
  guard self.tables.cmap is Some(cmap) else { return None }
  for subtable in cmap.subtables.iter() {
    if !subtable.is_unicode() {
      continue
    }
    if subtable.glyph_index(code_point.to_int().reinterpret_as_uint())
      is Some(id) {
      return Some(id)
    }
  }
  None
}

///|
/// Resolves a Glyph ID for a glyph name.
///
/// Uses the `post` and `CFF` tables as sources.
///
/// Returns `None` when no name is associated with a `glyph`.
pub fn Face::glyph_index_by_name(self : Face, name : String) -> GlyphId? {
  if and_then(self.tables.post, post => post.glyph_index_by_name(name))
    is Some(name) {
    return Some(name)
  }
  if and_then(self.tables.cff, cff => cff.glyph_index_by_name(name))
    is Some(name) {
    return Some(name)
  }
  None
}

///|
/// Resolves a variation of a Glyph ID from two code points.
///
/// Implemented according to
/// [Unicode Variation Sequences](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-14-unicode-variation-sequences).
///
/// Returns `None` instead of `0` when glyph is not found.
pub fn Face::glyph_variation_index(
  self : Face,
  code_point : Char,
  variation : Char,
) -> GlyphId? {
  guard self.tables.cmap is Some(cmap) else { return None }
  for subtable in cmap.subtables.iter() {
    if subtable.format is UnicodeVariationSequences(table) {
      return match
        table.glyph_index(
          code_point.to_int().reinterpret_as_uint(),
          variation.to_int().reinterpret_as_uint(),
        ) {
        None => None
        Some(Found(v)) => Some(v)
        Some(UseDefault) => self.glyph_index(code_point)
      }
    }
  }
  None
}

///|
/// Returns glyph's horizontal advance.
///
/// This method is affected by variation axes.
pub fn Face::glyph_hor_advance(self : Face, glyph_id : GlyphId) -> UInt16? {
  guard self.tables.hmtx is Some(hmtx) else { return None }
  guard hmtx.advance(glyph_id) is Some(advance) else { return None }
  let mut advance = Float::from_int(advance.to_int())
  if self.is_variable() {
    // Ignore variation offset when `hvar` is not set.
    if self.tables.hvar is Some(hvar) {
      if hvar.advance_offset(glyph_id, self.coords()) is Some(offset) {
        // We can't use `round()` in `no_std`, so this is the next best thing.
        advance += offset + 0.5
      }
    } else if self.glyph_phantom_points(glyph_id) is Some(points) {
      // We can't use `round()` in `no_std`, so this is the next best thing.
      advance += points.right.x + 0.5
    }
  }
  try_u16_from_f32(advance)
}

///|
/// Returns glyph's vertical advance.
///
/// This method is affected by variation axes.
pub fn Face::glyph_ver_advance(self : Face, glyph_id : GlyphId) -> UInt16? {
  guard self.tables.vmtx is Some(vmtx) else { return None }
  guard vmtx.advance(glyph_id) is Some(advance) else { return None }
  let mut advance = Float::from_int(advance.to_int())
  if self.is_variable() {
    // Ignore variation offset when `vvar` is not set.
    if self.tables.vvar is Some(vvar) {
      if vvar.advance_offset(glyph_id, self.coords()) is Some(offset) {
        // We can't use `round()` in `no_std`, so this is the next best thing.
        advance += offset + 0.5
      }
    } else if self.glyph_phantom_points(glyph_id) is Some(points) {
      // We can't use `round()` in `no_std`, so this is the next best thing.
      advance += points.bottom.y + 0.5
    }
  }
  try_u16_from_f32(advance)
}

///|
/// Returns glyph's horizontal side bearing.
///
/// This method is affected by variation axes.
pub fn Face::glyph_hor_side_bearing(self : Face, glyph_id : GlyphId) -> Int16? {
  guard self.tables.hmtx is Some(hmtx) else { return None }
  guard hmtx.side_bearing(glyph_id) is Some(bearing) else { return None }
  let mut bearing = Float::from_int(bearing.to_int())
  if self.is_variable() {
    // Ignore variation offset when `hvar` is not set.
    if self.tables.hvar is Some(hvar) {
      if hvar.left_side_bearing_offset(glyph_id, self.coords()) is Some(offset) {
        // We can't use `round()` in `no_std`, so this is the next best thing.
        bearing += offset + 0.5
      }
    }
  }
  try_i16_from_f32(bearing)
}

///|
/// Returns glyph's vertical side bearing.
///
/// This method is affected by variation axes.
pub fn Face::glyph_ver_side_bearing(self : Face, glyph_id : GlyphId) -> Int16? {
  guard self.tables.vmtx is Some(vmtx) else { return None }
  guard vmtx.side_bearing(glyph_id) is Some(bearing) else { return None }
  let mut bearing = Float::from_int(bearing.to_int())
  if self.is_variable() {
    // Ignore variation offset when `vvar` is not set.
    if self.tables.vvar is Some(vvar) {
      if vvar.top_side_bearing_offset(glyph_id, self.coords()) is Some(offset) {
        // We can't use `round()` in `no_std`, so this is the next best thing.
        bearing += offset + 0.5
      }
    }
  }
  try_i16_from_f32(bearing)
}

///|
/// Returns glyph's vertical origin according to
/// [Vertical Origin Table](https://docs.microsoft.com/en-us/typography/opentype/spec/vorg).
///
/// This method is affected by variation axes.
pub fn Face::glyph_y_origin(self : Face, glyph_id : GlyphId) -> Int16? {
  guard self.tables.vorg is Some(vorg) else { return None }
  let mut origin = Float::from_int(vorg.glyph_y_origin(glyph_id).to_int())
  if self.is_variable() {
    // Ignore variation offset when `vvar` is not set.
    if self.tables.vvar is Some(vvar) {
      if vvar.vertical_origin_offset(glyph_id, self.coords()) is Some(offset) {
        // We can't use `round()` in `no_std`, so this is the next best thing.
        origin += offset + 0.5
      }
    }
  }
  try_i16_from_f32(origin)
}

///|
/// Returns glyph's name.
///
/// Uses the `post` and `CFF` tables as sources.
///
/// Returns `None` when no name is associated with a `glyph`.
pub fn Face::glyph_name(self : Face, glyph_id : GlyphId) -> String? {
  if and_then(self.tables.post, post => post.glyph_name(glyph_id)) is Some(name) {
    return Some(name)
  }
  if and_then(self.tables.cff, cff1 => cff1.glyph_name(glyph_id)) is Some(name) {
    return Some(name)
  }
  None
}

///|
/// Outlines a glyph and returns its tight bounding box.
///
/// **Warning**: since `ttf-parser` is a pull parser,
/// `OutlineBuilder` will emit segments even when outline is partially malformed.
/// You must check `outline_glyph()` result before using
/// `OutlineBuilder`'s output.
///
/// `gvar`, `glyf`, `CFF` and `CFF2` tables are supported.
/// And they will be accesses in this specific order.
///
/// This method is affected by variation axes.
///
/// Returns `None` when glyph has no outline or on error.
pub fn Face::outline_glyph(
  self : Face,
  glyph_id : GlyphId,
  builder : &OutlineBuilder,
) -> Rect? {
  if self.tables.gvar is Some(gvar) {
    guard self.tables.glyf is Some(glyf) else { return None }
    return gvar.outline(glyf, self.coords(), glyph_id, builder)
  }
  if self.tables.glyf is Some(table) {
    return table.outline(glyph_id, builder)
  }
  if self.tables.cff is Some(cff) {
    return cff.outline(glyph_id, builder).to_option()
  }
  if self.tables.cff2 is Some(cff2) {
    return cff2.outline(self.coords(), glyph_id, builder).to_option()
  }
  None
}

///|
/// Returns a tight glyph bounding box.
///
/// This is just a shorthand for `outline_glyph()` since only the `glyf` table stores
/// a bounding box. We ignore `glyf` table bboxes because they can be malformed.
/// In case of CFF and variable fonts we have to actually outline
/// a glyph to find it's bounding box.
///
/// When a glyph is defined by a raster or a vector image,
/// that can be obtained via `glyph_image()`,
/// the bounding box must be calculated manually and this method will return `None`.
///
/// Note: the returned bbox is not validated in any way. A font can have a glyph bbox
/// set to zero/negative width and/or height and this is perfectly ok.
/// For calculated bboxes, zero width and/or height is also perfectly fine.
///
/// This method is affected by variation axes.
pub fn Face::glyph_bounding_box(self : Face, glyph_id : GlyphId) -> Rect? {
  self.outline_glyph(glyph_id, DummyOutline::{ })
}

///|
/// Returns a bounding box that large enough to enclose any glyph from the face.
pub fn Face::global_bounding_box(self : Face) -> Rect {
  self.tables.head.global_bbox
}

///|
/// Returns a reference to a glyph's raster image.
///
/// A font can define a glyph using a raster or a vector image instead of a simple outline.
/// Which is primarily used for emojis. This method should be used to access raster images.
///
/// `pixels_per_em` allows selecting a preferred image size. The chosen size will
/// be closer to an upper one. So when font has 64px and 96px images and `pixels_per_em`
/// is set to 72, 96px image will be returned.
/// To get the largest image simply use `std::u16::MAX`.
///
/// Note that this method will return an encoded image. It should be decoded
/// by the caller. We don't validate or preprocess it in any way.
///
/// Also, a font can contain both: images and outlines. So when this method returns `None`
/// you should also try `outline_glyph()` afterwards.
///
/// There are multiple ways an image can be stored in a TrueType font
/// and this method supports most of them.
/// This includes `sbix`, `bloc` + `bdat`, `EBLC` + `EBDT`, `CBLC` + `CBDT`.
/// And font's tables will be accesses in this specific order.
pub fn Face::glyph_raster_image(
  self : Face,
  glyph_id : GlyphId,
  pixels_per_em : UInt16,
) -> RasterGlyphImage? {
  if self.tables.sbix is Some(table) {
    if table.best_strike(pixels_per_em) is Some(strike) {
      return strike.get(glyph_id)
    }
  }
  if self.tables.bdat is Some(bdat) {
    return bdat.get(glyph_id, pixels_per_em)
  }
  if self.tables.ebdt is Some(ebdt) {
    return ebdt.get(glyph_id, pixels_per_em)
  }
  if self.tables.cbdt is Some(cbdt) {
    return cbdt.get(glyph_id, pixels_per_em)
  }
  None
}

///|
/// Returns a reference to a glyph's SVG image.
///
/// A font can define a glyph using a raster or a vector image instead of a simple outline.
/// Which is primarily used for emojis. This method should be used to access SVG images.
///
/// Note that this method will return just an SVG data. It should be rendered
/// or even decompressed (in case of SVGZ) by the caller.
/// We don't validate or preprocess it in any way.
///
/// Also, a font can contain both: images and outlines. So when this method returns `None`
/// you should also try `outline_glyph()` afterwards.
pub fn Face::glyph_svg_image(self : Face, glyph_id : GlyphId) -> SvgDocument? {
  and_then(self.tables.svg, svg => svg.documents.find(glyph_id))
}

///|
/// Returns `true` if the glyph can be colored/painted using the `COLR`+`CPAL` tables.
///
/// See `paint_color_glyph` for details.
pub fn Face::is_color_glyph(self : Face, glyph_id : GlyphId) -> Bool {
  self.tables.colr.map(colr => colr.contains(glyph_id)).unwrap_or(false)
}

///|
/// Returns the number of palettes stored in the `COLR`+`CPAL` tables.
///
/// See `paint_color_glyph` for details.
pub fn Face::color_palettes(self : Face) -> UInt16? {
  self.tables.colr.map(colr => colr.palettes.palettes())
}

///|
/// Paints a color glyph from the `COLR` table.
///
/// A font can have multiple palettes, which you can check via
/// `color_palettes`.
/// If unsure, just pass 0 to the `palette` argument, which is the default.
///
/// A font can define a glyph using layers of colored shapes instead of a
/// simple outline. Which is primarily used for emojis. This method should
/// be used to access glyphs defined in the `COLR` table.
///
/// Also, a font can contain both: a layered definition and outlines. So
/// when this method returns `None` you should also try
/// `outline_glyph` afterwards.
///
/// Returns `None` if the glyph has no `COLR` definition or if the glyph
/// definition is malformed.
pub fn Face::paint_color_glyph(
  self : Face,
  glyph_id : GlyphId,
  palette : UInt16,
  foreground_color : RgbaColor,
  painter : &ColrPainter,
) -> Unit? {
  guard self.tables.colr is Some(colr) else { return None }
  colr.paint(glyph_id, palette, painter, self.coords(), foreground_color)
}

///|
/// Returns an iterator over variation axes.
pub fn Face::variation_axes(self : Face) -> LazyArray16[VariationAxis] {
  self.tables.fvar.map(fvar => fvar.axes).unwrap_or(LazyArray16::default())
}

///|
/// Sets a variation axis coordinate.
///
/// This is one of the two only mutable methods in the library.
/// We can simplify the API a lot by storing the variable coordinates
/// in the face object itself.
///
/// Since coordinates are stored on the stack, we allow only 64 of them.
///
/// Returns `None` when face is not variable or doesn't have such axis.
pub fn Face::set_variation(self : Face, axis : Tag, value : Float) -> Unit? {
  if !self.is_variable() {
    return None
  }
  if self.variation_axes().len().to_int() >= max_var_coords {
    return None
  }
  let mut i = 0
  for var_axis in self.variation_axes().iter() {
    if var_axis.tag == axis {
      self.coordinates[i] = var_axis.normalized_value(value)
      if self.tables.avar is Some(avar) {
        let _ = avar.map_coordinate(self.coordinates, i)
      }
    }
    i += 1
  }
  Some(())
}

///|
/// Returns the current normalized variation coordinates.
pub fn Face::variation_coordinates(
  self : Face,
) -> ArrayView[NormalizedCoordinate] {
  self.coordinates[:]
}

///|
/// Checks that face has non-default variation coordinates.
pub fn Face::has_non_default_variation_coordinates(self : Face) -> Bool {
  self.coordinates.iter().any(c => c.0 != 0)
}

///|
/// Parses glyph's phantom points.
///
/// Available only for variable fonts with the `gvar` table.
pub fn Face::glyph_phantom_points(
  self : Face,
  glyph_id : GlyphId,
) -> PhantomPoints? {
  guard self.tables.glyf is Some(glyf) else { return None }
  guard self.tables.gvar is Some(gvar) else { return None }
  gvar.phantom_points(glyf, self.coords(), glyph_id)
}

///|
fn Face::metrics_var_offset(self : Face, tag : Tag) -> Float {
  and_then(self.tables.mvar, table => table.metric_offset(tag, self.coords())).unwrap_or(
    0.0,
  )
}

///|
fn Face::apply_metrics_variation(
  self : Face,
  tag : Tag,
  value : Int16,
) -> Int16 {
  if self.is_variable() {
    let v = Float::from_int(value.to_int()) + self.metrics_var_offset(tag)
    // TODO: Should probably round it, but f32::round is not available in core.
    if try_i16_from_f32(v) is Some(v) {
      return v
    }
  }
  value
}

///|
fn Face::coords(self : Face) -> ArrayView[NormalizedCoordinate] {
  self.coordinates[:]
}

///|
/// Returns the number of fonts stored in a TrueType font collection.
///
/// Returns `None` if a provided data is not a TrueType font collection.
pub fn fonts_in_collection(data : BytesView) -> UInt? {
  let s = Stream::new(data)
  let magic : Magic = s.read() catch { _ => return None }
  if magic != FontCollection {
    return None
  }
  s.advance(4) // version
  try s.read_u32() catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}
