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
let font_extensions : Array[String] = [
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
  seen : @hashset.HashSet[String],
) -> (String, @platform.FileKind)? {
  let file_type = @platform.lstat_kind(path) catch { _ => return None }
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
  let entries = @platform.read_dir(dir) catch { _ => return }
  for name in entries {
    let entry = @platform.join(dir, name)
    guard canonicalize_entry(entry, seen) is Some((path, file_type)) else {
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
  let n = file.fonts_in_collection().unwrap_or(1U)
  for index in 0U..<n {
    guard file.probe_face(index) is Some((data, at)) else { continue }
    // `fontdb::parse_face_info`.
    guard admit_face(data, at) else { continue }
    // `db.with_face_data(face.id, FontInfo::new)`.
    guard @library.FontInfo::new(data, at) is Some(info) else { continue }
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
/// The tables that face admission and `FontInfo::from_ttf` read (the first
/// three are required by `Face::parse`).
let probe_tables : Array[String] = [
  "head", "hhea", "maxp", "name", "OS/2", "post", "cmap", "fvar", "MATH",
]

///|
/// A font file being probed: either fully loaded or read in ranges.
priv struct FontFile {
  path : String
  size : Int64
  /// The whole file, if it was read completely.
  data : Bytes?
}

///|
fn FontFile::open(path : String) -> FontFile raise @platform.IoError {
  if @platform.supports_ranged_reads() {
    let size = @platform.file_size(path)
    // Small files are cheaper to read whole.
    if size > 262144L {
      return { path, size, data: None, }
    }
  }
  let data = @platform.read_file(path)
  { path, size: data.length().to_int64(), data: Some(data), }
}

///|
/// Reads exactly `len` bytes at `offset`, or `None` if the file is too
/// short.
fn FontFile::read(self : FontFile, offset : Int64, len : Int) -> Bytes? {
  if offset < 0L || len < 0 || offset + len.to_int64() > self.size {
    return None
  }
  match self.data {
    Some(data) => {
      let start = offset.to_int()
      Some(data[start:start + len].to_owned())
    }
    None => {
      let bytes = @platform.read_range(self.path, offset, len) catch {
        _ => return None
      }
      if bytes.length() == len {
        Some(bytes)
      } else {
        None
      }
    }
  }
}

///|
/// The whole file.
fn FontFile::all(self : FontFile) -> Bytes? {
  match self.data {
    Some(data) => Some(data)
    None => Some(@platform.read_file(self.path)) catch { _ => None }
  }
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
  Some(be_u32(header, 8))
}

///|
/// The data to parse a face from and the index to parse it at: the whole
/// file at the face's index or, with ranged reads, a standalone font with
/// the face's relevant tables (at index 0). `None` if the face cannot be
/// parsed at all (like `ttf_parser::RawFace::parse` failing).
fn FontFile::probe_face(self : FontFile, index : UInt) -> (Bytes, UInt)? {
  if self.data is Some(data) {
    return Some((data, index))
  }
  // Locate the face's offset table.
  guard self.read(0L, 4) is Some(magic) else { return None }
  let magic = be_u32(magic, 0)
  let face_offset = if magic == 0x74746366U {
    guard self.read(8L, 4) is Some(count) else { return None }
    let count = be_u32(count, 0)
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
  } else if index != 0U {
    return None
  } else {
    0L
  }
  guard self.read(face_offset, 12) is Some(header) else { return None }
  let face_magic = be_u32(header, 0)
  guard face_magic == 0x00010000U ||
    face_magic == 0x74727565U ||
    face_magic == 0x4F54544FU else {
    return None
  }
  let num_tables = be_u16(header, 4)
  guard self.read(face_offset + 12L, num_tables * 16) is Some(records) else {
    return None
  }
  // Collect the relevant tables. Fall back to the whole file for unsorted
  // or duplicate table records (where lookups in a subset could behave
  // differently from lookups in the full table directory).
  let tables : Array[(UInt, UInt, Bytes?)] = []
  let mut prev = -1L
  for i in 0..<num_tables {
    let at = i * 16
    let tag = be_u32(records, at)
    if tag.to_int64() <= prev {
      return self.all().map(data => (data, index))
    }
    prev = tag.to_int64()
    if probe_tables.contains(@otf.Tag(tag).to_string()) {
      let offset = be_u32(records, at + 8)
      let length = be_u32(records, at + 12)
      let data = if length > 0x7FFFFFFFU {
        None
      } else {
        self.read(offset.to_int64(), length.reinterpret_as_int())
      }
      tables.push((tag, be_u32(records, at + 4), data))
    }
  }
  Some((build_sfnt(face_magic, tables), 0U))
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
