// Font discovery like `fontdb` 0.23 (which upstream `typst_kit::fonts` uses
// via `load_system_fonts` and `load_fonts_dir`): recursive directory scans
// with the same extension filter, symlink deduplication and face admission
// (`parse_face_info`), followed by typst's `FontInfo::new` for every
// admitted face.
//
// fontdb memory-maps font files, so that only the pages it touches are
// read. Here, large font files are probed by reading just the face's table
// directory and the tables that face admission and `FontInfo::from_ttf`
// look at (`probe_tables`), which are reassembled into a small standalone
// font. Small files, unusual fonts (unsorted or duplicate table records)
// and platforms without cheap ranged reads (wasm) read the whole file.
//
// A file is opened once (`@platform.RangedFile`) and its pieces are read
// from that descriptor. It is not mapped: reading the pieces costs what
// touching them in a mapping costs (10 ms for the 1339 faces in 502 files
// of a macOS 26 installation, either way), and a file that is truncated
// while it is read gives short reads, which are faces that do not parse,
// where a mapping gives SIGBUS (fontdb has that exposure).
//
// fontdb and `FontInfo::new` look at every face on its own. Here the faces
// of a collection that is read in ranges share what they have in common: a
// table at one place of the file is read once, and the coverage of a `cmap`
// table is computed once (`FontFile::tables`, `FontFile::coverages`). What
// a face gets is what its whole file gives: `fontdb_wbtest.mbt`.

///|
/// A discovered font face: where it lives and its metadata.
priv struct DbFace {
  path : String
  index : UInt
  info : @library.FontInfo
}

///|
/// A font database (the parts of `fontdb::Database` that typst-kit uses).
priv struct FontDb {
  faces : Array[DbFace]
}

///|
fn FontDb::new() -> FontDb {
  { faces: [], }
}

///|
/// The extensions `load_fonts_dir` considers.
let font_extensions : ReadOnlyArray[String] = [
  "ttf", "ttc", "TTF", "TTC", "otf", "otc", "OTF", "OTC",
]

///|
/// Rust's `Path::extension` of a file name.
fn extension(name : String) -> String? {
  guard name.rev_find(".") is Some(i) else { return None }
  if i == 0 {
    return None
  }
  Some(name[i + 1:].to_owned())
}

///|
/// Loads font files from the selected directory into the database,
/// recursively (`Database::load_fonts_dir`).
fn FontDb::load_fonts_dir(self : FontDb, dir : String) -> Unit {
  self.load_fonts_dir_impl(dir, @hashset.HashSet([]))
}

///|
/// Resolves a directory entry to the path to load and its file type,
/// deduplicating symlinked entries (`Database::canonicalize`).
fn canonicalize_entry(
  path : String,
  kind : @platform.FileKind?,
  seen : @hashset.HashSet[String],
) -> (String, @platform.FileKind)? {
  // `entry.file_type()`: what the directory said, or else what the system
  // says.
  let file_type = match kind {
    Some(kind) => kind
    None => @platform.lstat_kind(path) catch { _ => return None }
  }
  if file_type != Symlink {
    if seen.length() > 0 {
      if seen.contains(path) {
        return None
      }
      seen.add(path)
    }
    return Some((path, file_type))
  }
  // (Upstream also seeds `seen` with the paths of all loaded faces here
  // when a symlink entry is a directory, but the file type of a symlink
  // entry is never a directory, so that branch never runs.)
  let stat = @platform.stat_kind(path) catch { _ => return None }
  let canon = @platform.canonicalize(path) catch { _ => return None }
  if seen.contains(canon) {
    return None
  }
  seen.add(canon)
  Some((canon, stat))
}

///|
fn FontDb::load_fonts_dir_impl(
  self : FontDb,
  dir : String,
  seen : @hashset.HashSet[String],
) -> Unit {
  let entries = @platform.read_dir_entries(dir) catch { _ => return }
  for entry in entries {
    let kind = entry.kind
    let entry = @platform.join(dir, entry.name)
    guard canonicalize_entry(entry, kind, seen) is Some((path, file_type)) else {
      continue
    }
    if file_type == File {
      let file_name = @platform.file_name(path).unwrap_or("")
      if extension(file_name) is Some(ext) && font_extensions.contains(ext) {
        self.load_font_file(path)
      }
    } else if file_type == Dir {
      self.load_fonts_dir_impl(path, seen)
    }
  }
}

///|
/// Loads all faces of a font file (`Database::load_font_file`), keeping
/// those that fontdb admits and for which typst can compute metadata.
fn FontDb::load_font_file(self : FontDb, path : String) -> Unit {
  let file = FontFile::open(path) catch { _ => return }
  defer file.close()
  let n = match file.fonts_in_collection() {
    Some(n) => {
      // `RawFace::parse` reads the offsets of all faces before it looks
      // for one, so no face parses if the file is too short for them.
      // (Not in fontdb, which tries every index: a count of 2^32 - 1 is 12
      // bytes of a file and minutes of failing parses.)
      if n.to_int64() * 4L > file.size - 12L {
        return
      }
      n
    }
    None => 1U
  }
  for index in 0U..<n {
    guard file.probe_face(index) is Some(probe) else { continue }
    // `fontdb::parse_face_info`.
    guard admit_face(probe.data, probe.index) else { continue }
    // `db.with_face_data(face.id, FontInfo::new)`.
    guard file.info(probe) is Some(info) else { continue }
    self.faces.push({ path, index, info, })
  }
}

///|
/// Whether fontdb admits a face (`fontdb::parse_face_info` succeeds): the
/// face must parse and have a family and a PostScript name.
fn admit_face(data : Bytes, index : UInt) -> Bool {
  let raw_face = @otf.RawFace::parse(data[:], index) catch { _ => return false }
  guard raw_face.table(@otf.Tag::from_str("name")) is Some(name_data) else {
    return false
  }
  guard @otf.NameTable::parse(name_data) is Some(name_table) else {
    return false
  }
  let names = name_table.names
  let has_family = (name_id : UInt16) => {
    names
    .iter()
    .any(name => {
      name.name_id == name_id &&
      ((name.is_unicode() && name.to_string() is Some(_)) || is_mac_roman(name))
    })
  }
  // We have to fallback to Family Name when no Typographic Family Name was
  // set.
  guard has_family(@otf.name_id_typographic_family) ||
    has_family(@otf.name_id_family) else {
    return false
  }
  // The first PostScript name in a supported encoding must decode.
  match
    names
    .iter()
    .find_first(name => {
      name.name_id == @otf.name_id_post_script_name &&
      (name.is_unicode() || is_mac_roman(name))
    }) {
    Some(name) => is_mac_roman(name) || name.to_string() is Some(_)
    None => false
  }
}

///|
fn is_mac_roman(name : @otf.Name) -> Bool {
  name.platform_id == Macintosh && name.encoding_id == 0
}

///|
const TAG_CMAP : UInt = 0x636D6170U

///|
/// Whether a table is one that face admission and `FontInfo::from_ttf` read
/// (the first three are required by `Face::parse`).
fn is_probe_table(tag : UInt) -> Bool {
  match tag {
    // head, hhea, maxp
    0x68656164U | 0x68686561U | 0x6D617870U => true
    // name, OS/2, post
    0x6E616D65U | 0x4F532F32U | 0x706F7374U => true
    // cmap, fvar, MATH
    TAG_CMAP | 0x66766172U | 0x4D415448U => true
    _ => false
  }
}

///|
/// A font file being probed: either fully loaded or read in ranges.
priv struct FontFile {
  size : Int64
  /// The whole file, if it was read completely.
  mut data : Bytes?
  /// The open file, if it is read in ranges.
  file : @platform.RangedFile?
  /// The number of faces, if this is a collection that is read in ranges
  /// (set by `fonts_in_collection`).
  mut faces : UInt?
  /// Of a collection that is read in ranges: the tables read so far, by
  /// their place in the file (`table_key`). The faces of a collection share
  /// tables: of the system fonts of macOS 26, 1339 faces in 502 files,
  /// every second table that discovery needs is one that an earlier face
  /// of the file has as well.
  tables : Map[UInt64, Bytes?]
  /// And the coverages computed so far, by the place of the `cmap` table
  /// they are of: the largest of these tables and half of the work of
  /// `FontInfo::new`.
  coverages : Map[UInt64, @library.Coverage]
}

///|
/// The place of a table in a file as a key: its offset and its length.
fn table_key(offset : UInt, length : UInt) -> UInt64 {
  (offset.to_uint64() << 32) | length.to_uint64()
}

///|
/// What to parse a face from.
priv struct Probe {
  /// The whole file, or a standalone font with the face's relevant tables.
  data : Bytes
  /// The index of the face in `data`.
  index : UInt
  /// For a face of a collection that is read in ranges: the place of its
  /// `cmap` table in the file. The table is in `data` unless its coverage
  /// is known (`FontFile::info`).
  cmap : UInt64?
}

///|
/// Files up to this size are read whole: that is one read, and their faces
/// are parsed in place.
const WHOLE_FILE_LIMIT : Int64 = 262144L

///|
fn FontFile::open(path : String) -> FontFile raise @platform.IoError {
  if !@platform.supports_ranged_reads() {
    return FontFile::whole(@platform.read_file(path))
  }
  let file = @platform.RangedFile::open(path)
  errdefer file.close()
  let size = file.size()
  if size > WHOLE_FILE_LIMIT {
    return {
      size,
      data: None,
      file: Some(file),
      faces: None,
      tables: Map([]),
      coverages: Map([]),
    }
  }
  // Small files are cheaper to read whole.
  let data = file.read(0L, size.to_int())
  file.close()
  FontFile::whole(data)
}

///|
/// A file that was read completely.
fn FontFile::whole(data : Bytes) -> FontFile {
  {
    size: data.length().to_int64(),
    data: Some(data),
    file: None,
    faces: None,
    tables: Map([]),
    coverages: Map([]),
  }
}

///|
/// Closes the file.
fn FontFile::close(self : FontFile) -> Unit {
  if self.file is Some(file) {
    file.close()
  }
}

///|
/// Reads exactly `len` bytes at `offset`, or `None` if the file is too
/// short (also if it got shorter since it was opened).
fn FontFile::read(self : FontFile, offset : Int64, len : Int) -> Bytes? {
  if offset < 0L || len < 0 || len.to_int64() > self.size - offset {
    return None
  }
  if self.data is Some(data) {
    let start = offset.to_int()
    return Some(data[start:start + len].to_owned())
  }
  guard self.file is Some(file) else { return None }
  let bytes = file.read(offset, len) catch { _ => return None }
  if bytes.length() == len {
    Some(bytes)
  } else {
    None
  }
}

///|
/// The whole file. It is kept, so the remaining faces are parsed in place.
fn FontFile::all(self : FontFile) -> Bytes? {
  if self.data is Some(data) {
    return Some(data)
  }
  guard self.file is Some(file) else { return None }
  // (`fs::read` of a larger file fails as well.)
  guard self.size <= 0x7FFFFFFFL else { return None }
  let size = self.size.to_int()
  let data = file.read(0L, size) catch { _ => return None }
  // The file got shorter since it was opened.
  guard data.length() == size else { return None }
  self.data = Some(data)
  Some(data)
}

///|
fn be_u32(b : Bytes, at : Int) -> UInt {
  (b[at].to_uint() << 24) |
  (b[at + 1].to_uint() << 16) |
  (b[at + 2].to_uint() << 8) |
  b[at + 3].to_uint()
}

///|
fn be_u16(b : Bytes, at : Int) -> Int {
  (b[at].to_int() << 8) | b[at + 1].to_int()
}

///|
/// The number of faces if this is a font collection
/// (`ttf_parser::fonts_in_collection`).
fn FontFile::fonts_in_collection(self : FontFile) -> UInt? {
  guard self.read(0L, 12) is Some(header) else { return None }
  if be_u32(header, 0) != 0x74746366U {
    return None
  }
  let count = be_u32(header, 8)
  if self.data is None {
    self.faces = Some(count)
  }
  Some(count)
}

///|
/// The table at a place of a collection that is read in ranges, or `None`
/// if it is not all in the file. Read once for all faces that have it.
fn FontFile::table(self : FontFile, offset : UInt, length : UInt) -> Bytes? {
  let key = table_key(offset, length)
  if self.tables.get(key) is Some(data) {
    return data
  }
  let data = self.read_table(offset, length)
  self.tables[key] = data
  data
}

///|
/// The table at a place of the file, or `None` if it is not all there.
fn FontFile::read_table(
  self : FontFile,
  offset : UInt,
  length : UInt,
) -> Bytes? {
  if length > 0x7FFFFFFFU {
    None
  } else {
    self.read(offset.to_int64(), length.reinterpret_as_int())
  }
}

///|
/// `FontInfo::new` for a face. For the faces of a collection that is read
/// in ranges, the coverage of a `cmap` table is computed for the first
/// face that has the table and taken from there by the others.
fn FontFile::info(self : FontFile, probe : Probe) -> @library.FontInfo? {
  guard probe.cmap is Some(key) else {
    return @library.FontInfo::new(probe.data, probe.index)
  }
  let ttf = @otf.Face::parse(probe.data[:], probe.index) catch {
    _ => return None
  }
  let coverage = match self.coverages.get(key) {
    Some(coverage) => coverage
    None => {
      let coverage = @library.Coverage::from_ttf(ttf)
      self.coverages[key] = coverage
      coverage
    }
  }
  @library.FontInfo::from_ttf_with_coverage(ttf, Some(coverage))
}

///|
/// What to parse a face from: the whole file at the face's index or, with
/// ranged reads, a standalone font with the face's relevant tables (at
/// index 0). `None` if the face cannot be parsed at all (like
/// `ttf_parser::RawFace::parse` failing).
fn FontFile::probe_face(self : FontFile, index : UInt) -> Probe? {
  if self.data is Some(data) {
    return Some({ data, index, cmap: None, })
  }
  // Locate the face's offset table.
  let face_offset = match self.faces {
    Some(count) => {
      let records_end = 12L + count.to_int64() * 4L
      if records_end > self.size || index >= count {
        return None
      }
      guard self.read(12L + index.to_int64() * 4L, 4) is Some(offset) else {
        return None
      }
      let offset = be_u32(offset, 0).to_int64()
      if offset < records_end {
        return None
      }
      offset
    }
    None => if index != 0U { return None } else { 0L }
  }
  // The offset table and, in the same read, as many table records as most
  // fonts have.
  let rest = self.size - face_offset
  if rest < 12L {
    return None
  }
  let first = if rest < 12L + 16L * 32L { rest.to_int() } else { 12 + 16 * 32 }
  guard self.read(face_offset, first) is Some(header) else { return None }
  let face_magic = be_u32(header, 0)
  guard face_magic == 0x00010000U ||
    face_magic == 0x74727565U ||
    face_magic == 0x4F54544FU else {
    return None
  }
  let num_tables = be_u16(header, 4)
  let records = if 12 + num_tables * 16 <= first {
    header
  } else {
    guard self.read(face_offset, 12 + num_tables * 16) is Some(header) else {
      return None
    }
    header
  }
  // Collect the relevant tables. Fall back to the whole file for unsorted
  // or duplicate table records (where lookups in a subset could behave
  // differently from lookups in the full table directory).
  let shared = self.faces is Some(_)
  let tables : Array[(UInt, UInt, Bytes?)] = []
  let mut cmap : UInt64? = None
  let mut prev = -1L
  for i in 0..<num_tables {
    let at = 12 + i * 16
    let tag = be_u32(records, at)
    if tag.to_int64() <= prev {
      guard self.all() is Some(data) else { return None }
      return Some({ data, index, cmap: None, })
    }
    prev = tag.to_int64()
    if is_probe_table(tag) {
      let offset = be_u32(records, at + 8)
      let length = be_u32(records, at + 12)
      let data = if !shared {
        self.read_table(offset, length)
      } else if tag == TAG_CMAP {
        let key = table_key(offset, length)
        cmap = Some(key)
        // The coverage of this table is known: the face does without the
        // table itself (nothing else in `FontInfo::from_ttf` and nothing
        // in the face's admission reads it).
        if self.coverages.contains(key) {
          continue
        }
        self.read_table(offset, length)
      } else {
        self.table(offset, length)
      }
      tables.push((tag, be_u32(records, at + 4), data))
    }
  }
  Some({ data: build_sfnt(face_magic, tables), index: 0U, cmap, })
}

///|
/// Assembles a standalone font from table records (in order). Tables
/// without data (out of the file's bounds) get an out-of-bounds record, so
/// that they behave as missing like in the original.
fn build_sfnt(magic : UInt, tables : Array[(UInt, UInt, Bytes?)]) -> Bytes {
  let n = tables.length()
  let header_len = 12 + 16 * n
  let mut total = header_len
  for table in tables {
    if table.2 is Some(data) {
      total += (data.length() + 3) / 4 * 4
    }
  }
  let out = FixedArray::make(total, b'\x00')
  let put_u32 = (at : Int, v : UInt) => {
    out[at] = (v >> 24).to_byte()
    out[at + 1] = (v >> 16).to_byte()
    out[at + 2] = (v >> 8).to_byte()
    out[at + 3] = v.to_byte()
  }
  put_u32(0, magic)
  out[4] = (n >> 8).to_byte()
  out[5] = n.to_byte()
  let mut pos = header_len
  for i, table in tables {
    let (tag, check_sum, data) = table
    let at = 12 + i * 16
    put_u32(at, tag)
    put_u32(at + 4, check_sum)
    match data {
      Some(data) => {
        put_u32(at + 8, pos.reinterpret_as_uint())
        put_u32(at + 12, data.length().reinterpret_as_uint())
        out.blit_from_bytes(pos, data, 0, data.length())
        pos += (data.length() + 3) / 4 * 4
      }
      None => {
        put_u32(at + 8, 0xFFFFFFF0U)
        put_u32(at + 12, 16U)
      }
    }
  }
  Bytes::from_array(out)
}
