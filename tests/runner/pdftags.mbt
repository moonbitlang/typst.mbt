// The `pdftags` stage: export the `pdftags` test cases to PDF like the
// upstream harness and format the tag tree of the PDF as YAML. This is a port
// of upstream `tests/src/pdftags.rs` (also used by the oracle, see
// `oracle/src/pdftags.rs`) on top of the pdflite reader.

///|
/// Compile a test case, export it to PDF and format its tag tree.
fn pdftags_report(rel : String, tc : TestCase) -> String {
  let (world, id, doc) = match pdf_compile(rel, tc) {
    Some(r) => r
    None => return "<error>\n"
  }
  let warned = make_live(doc)
  let out = StringBuilder()
  match warned.output {
    Err(errors) => {
      out.write_string("export-error\n")
      for diag in @typst.deduplicate(errors) {
        write_source_diag(out, world, id, diag)
      }
      for diag in @typst.deduplicate(warned.warnings) {
        write_source_diag(out, world, id, diag)
      }
    }
    Ok(bytes) => {
      for diag in @typst.deduplicate(warned.warnings) {
        write_source_diag(out, world, id, diag)
      }
      out.write_string(pdftags_format_or_error(bytes))
    }
  }
  out.to_string()
}

///|
/// Run the MoonBit formatter on upstream's PDF of a test case (see
/// `pdf_extract_check_report`).
fn pdftags_check_report(rel : String, tc : TestCase) -> String {
  let golden = pdftags_golden(rel).get(tc.name).unwrap_or("")
  if golden.has_prefix("<") || golden.has_prefix("export-error") {
    return golden
  }
  guard upstream_pdf_dir.val is Some(dir) else {
    return "<no --upstream-pdfs>\n"
  }
  let path = "\{dir}/\{rel.unsafe_substring(start=0, end=rel.length() - 4)}/\{tc.name}.pdf"
  let bytes = @fs.read_file_to_bytes(path) catch {
    _ => return "<missing upstream pdf>\n"
  }
  let out = StringBuilder()
  for line in golden.split("\n") {
    if line.has_prefix("warning ") || line.has_prefix("  hint ") {
      out.write_string(line.to_string())
      out.write_char('\n')
    }
  }
  out.write_string(pdftags_format_or_error(bytes))
  out.to_string()
}

///|
fn pdftags_golden(rel : String) -> Map[String, String] {
  let key = "pdftags:" + rel
  if pdf_golden_cache.get(key) is Some(m) {
    return m
  }
  let path = golden_dir +
    "/pdftags/" +
    rel.unsafe_substring(start=0, end=rel.length() - 4) +
    ".txt"
  let m = split_golden(read(path))
  pdf_golden_cache.clear()
  pdf_golden_cache[key] = m
  m
}

///|
fn pdftags_format_or_error(bytes : Bytes) -> String {
  pdftags_format(bytes) catch {
    PdfTagsError(e) => "<extract-error \{dq(e)}>\n"
    e => "<extract-error \{dq(e.to_string())}>\n"
  }
}

///|
suberror PdfTagsError {
  PdfTagsError(String)
}

///|
/// The context used while formatting the PDF tag tree.
priv struct TagsFormatter {
  r : PdfReader
  /// The marked content sequences of each page, by page object number:
  /// the page index and the properties of each MCID.
  pages : Map[Int, (Int, Map[Int64, @pdfsyntax.PdfObject])]
  buf : StringBuilder
  mut indent : Int
  /// Whether the last character written was a newline and an indent should
  /// be applied to the next line. This isn't done directly because the
  /// indent might be changed before writing any other content.
  mut pending_indent : Bool
  /// A string that is used to pad the following content, if there is any
  /// on the same line. If a newline is written, discard this padding so there
  /// isn't any trailing whitespace.
  mut maybe_space : String?
}

///|
fn TagsFormatter::write(self : TagsFormatter, s : String) -> Unit {
  if self.pending_indent {
    self.buf.write_string(" ".repeat(2 * self.indent))
    self.pending_indent = false
  }
  if self.maybe_space is Some(space) {
    self.maybe_space = None
    if !s.has_prefix("\n") {
      self.buf.write_string(space)
    }
  }
  // Rust's `str::lines`.
  let lines = s.split("\n").map(l => l.to_string()).collect()
  if s.has_suffix("\n") {
    lines.pop() |> ignore
  }
  for i, l in lines {
    if i == 0 {
      self.buf.write_string(l)
    } else {
      self.buf.write_char('\n')
      self.buf.write_string(" ".repeat(2 * self.indent))
      self.buf.write_string(l)
    }
  }
  if s.has_suffix("\n") {
    self.buf.write_char('\n')
    self.pending_indent = true
  }
}

///|
fn TagsFormatter::writeln(self : TagsFormatter, s : String) -> Unit {
  self.write(s + "\n")
}

///|
fn TagsFormatter::get(
  self : TagsFormatter,
  obj : @pdfsyntax.PdfObject,
  key : String,
) -> @pdfsyntax.PdfObject? {
  self.r.get(obj, key)
}

///|
fn TagsFormatter::get_name(
  self : TagsFormatter,
  obj : @pdfsyntax.PdfObject,
  key : String,
) -> String? {
  match self.get(obj, key) {
    Some(PdfNameObject(n)) => Some(name_str(n))
    _ => None
  }
}

///|
fn TagsFormatter::get_ref(
  self : TagsFormatter,
  obj : @pdfsyntax.PdfObject,
  key : String,
) -> Int? {
  match self.r.get_raw(obj, key) {
    Some(PdfIndirect(n)) => Some(n)
    _ => None
  }
}

///|
/// Format the tag tree of a PDF document as YAML.
fn pdftags_format(bytes : Bytes) -> String raise {
  let doc = @pdflite.pdf_read_document_from_bytes(bytes)
  let r : PdfReader = { doc, pages: [], named: [], }
  let catalog = doc.catalog()
  let pages = {}
  for idx, page_num in doc.page_reference_numbers() {
    let page = doc.lookup_object_or_null(page_num)
    let marked_content = {}
    if r.get(page, "Contents") is Some(contents) {
      let parts = match doc.direct(contents) {
        PdfArray(items) => items
        c => [c]
      }
      let data = @buffer.new()
      for p in parts {
        if r.stream_data(p) is Some(d) {
          data.write_bytes(d)
          data.write_byte(b'\n')
        }
      }
      let ops = @pdflite.pdf_parse_content_ops_from_bytes(data.to_bytes()) catch {
        _ => []
      }
      for op in ops {
        let props = match op {
          Op_DP(_, props) | Op_BDC(_, props) => doc.direct(props)
          _ => continue
        }
        guard props is PdfDictionary(_) else { continue }
        match r.get(props, "MCID") {
          Some(PdfInteger(mcid)) => marked_content[mcid.to_int64()] = props
          _ => ()
        }
      }
    }
    pages[page_num] = (idx, marked_content)
  }
  let f : TagsFormatter = {
    r,
    pages,
    buf: StringBuilder(),
    indent: 0,
    pending_indent: false,
    maybe_space: None,
  }
  guard r.get(catalog, "StructTreeRoot") is Some(struct_tree) else {
    raise PdfTagsError("struct tree root")
  }
  guard r.get(struct_tree, "K") is Some(PdfArray(_) as kids) else {
    raise PdfTagsError("struct tree kids")
  }
  let document = match r.array(kids).filter(k => k is PdfDictionary(_)) {
    [d, ..] => d
    [] => raise PdfTagsError("document tag")
  }
  guard r.get(document, "K") is Some(PdfArray(_) as kids) else {
    raise PdfTagsError("document kids")
  }
  if r.get(catalog, "Metadata") is Some(meta) &&
    r.stream_data(meta) is Some(data) {
    let xml = @utf8.decode_lossy(data[:])
    if xmp_value(xml, "dc:language") is Some(lang) && lang != "en" {
      // Only write language if it deviates from the default.
      f.writeln("lang: \{dq(lang)}")
    }
    if f.buf.to_string() != "" {
      f.writeln("---")
    }
  }
  format_tag_children(f, document, kids)
  f.buf.to_string()
}

///|
/// Format a PDF structure element (tag).
fn format_tag(f : TagsFormatter, tag : @pdfsyntax.PdfObject) -> Unit raise {
  assert_type(f, tag, "StructElem")
  guard f.get_name(tag, "S") is Some(ty) else {
    raise PdfTagsError("missing structure type")
  }
  f.writeln("- Tag: \{ty}")
  f.indent += 1
  format_tag_attrs(f, tag) catch {
    PdfTagsError(e) => raise PdfTagsError("\{ty}: \{e}")
    e => raise e
  }
  guard f.get(tag, "K") is Some(PdfArray(items) as kids) else {
    raise PdfTagsError("\{ty}: missing kids array")
  }
  if !items.is_empty() {
    f.writeln("/K:")
    f.indent += 1
    format_tag_children(f, tag, kids) catch {
      PdfTagsError(e) => raise PdfTagsError("\{ty}: \{e}")
      e => raise e
    }
    f.indent -= 1
  }
  f.indent -= 1
}

///|
/// Format either a child structure element (tag), a marked-content sequence or
/// an annotation.
fn format_tag_children(
  f : TagsFormatter,
  tag : @pdfsyntax.PdfObject,
  kids : @pdfsyntax.PdfObject,
) -> Unit raise {
  for kid in f.r.array(kids) {
    match kid {
      PdfInteger(mcid) => {
        guard f.get_ref(tag, "Pg") is Some(page_ref) else {
          raise PdfTagsError("missing page ref on structure element")
        }
        format_marked_content(f, page_ref, mcid.to_int64())
      }
      PdfDictionary(_) => {
        guard f.get_name(kid, "Type") is Some(ty) else {
          raise PdfTagsError("missing object type")
        }
        match ty {
          "MCR" => {
            guard f.get(kid, "MCID") is Some(PdfInteger(mcid)) else {
              raise PdfTagsError("missing content id")
            }
            guard f.get_ref(kid, "Pg") is Some(page_ref) else {
              raise PdfTagsError("missing page ref on marked-content reference")
            }
            format_marked_content(f, page_ref, mcid.to_int64())
          }
          "OBJR" => {
            guard f.get(kid, "Obj") is Some(PdfDictionary(_) as annot) else {
              raise PdfTagsError("missing referenced obj")
            }
            guard f.get_ref(kid, "Pg") is Some(page_ref) else {
              raise PdfTagsError("missing page ref on object reference")
            }
            format_annotation(f, page_ref, annot) catch {
              PdfTagsError(e) =>
                raise PdfTagsError("error formatting annotation: \{e}")
              e => raise e
            }
          }
          _ => format_tag(f, kid)
        }
      }
      _ => raise PdfTagsError("unexpected object")
    }
  }
}

///|
/// Format a marked content sequence.
fn format_marked_content(
  f : TagsFormatter,
  page_ref : Int,
  mcid : Int64,
) -> Unit raise {
  guard f.pages.get(page_ref) is Some((page_idx, marked_content)) else {
    raise PdfTagsError("error formatting marked-content: missing page")
  }
  guard marked_content.get(mcid) is Some(props) else {
    raise PdfTagsError("error formatting marked-content: missing mcid")
  }
  f.writeln("- Content: page=\{page_idx} mcid=\{mcid}")
  f.indent += 1
  if f.get(props, "Lang") is Some(val) {
    format_attr(f, "Lang", val, format_str)
  }
  if f.get(props, "Alt") is Some(val) {
    format_attr(f, "Alt", val, format_str)
  }
  if f.get(props, "E") is Some(val) {
    format_attr(f, "Expanded", val, format_str)
  }
  if f.get(props, "ActualText") is Some(val) {
    format_attr(f, "ActualText", val, format_str)
  }
  f.indent -= 1
}

///|
/// Format a link annotation.
fn format_annotation(
  f : TagsFormatter,
  page_ref : Int,
  annot : @pdfsyntax.PdfObject,
) -> Unit raise {
  assert_type(f, annot, "Annot")
  guard f.get_name(annot, "Subtype") is Some(subtype) else {
    raise PdfTagsError("missing subtype")
  }
  guard f.pages.get(page_ref) is Some((page_idx, _)) else {
    raise PdfTagsError("missing page")
  }
  f.writeln("- Annotation: page=\{page_idx} subtype=\{subtype}")
  f.indent += 1
  if f.get(annot, "Contents") is Some(val) {
    format_attr(f, "Contents", val, format_str)
  }
  if f.get(annot, "A") is Some(PdfDictionary(_) as action) {
    assert_type(f, action, "Action")
    if f.get(action, "URI") is Some(val) {
      format_attr(f, "URI", val, format_str)
    }
  }
  f.indent -= 1
}

///|
/// Format the attributes of a structure element (tag).
fn format_tag_attrs(
  f : TagsFormatter,
  tag : @pdfsyntax.PdfObject,
) -> Unit raise {
  if f.get(tag, "ID") is Some(val) {
    format_attr(f, "Id", val, format_byte_str)
  }
  if f.get(tag, "Lang") is Some(val) {
    format_attr(f, "Lang", val, format_str)
  }
  if f.get(tag, "Alt") is Some(val) {
    format_attr(f, "Alt", val, format_str)
  }
  if f.get(tag, "E") is Some(val) {
    format_attr(f, "Expanded", val, format_str)
  }
  if f.get(tag, "ActualText") is Some(val) {
    format_attr(f, "ActualText", val, format_str)
  }
  if f.get(tag, "T") is Some(val) {
    format_attr(f, "T", val, format_str)
  }
  guard f.get(tag, "A") is Some(PdfArray(_) as attrs_array) else { return }
  for attrs in f.r.array(attrs_array) {
    guard attrs.dictionary_view() is Some(entries) else { continue }
    // Attributes are stored in a hash map. Sort the keys by a
    // predefined order so the formatted tag tree is deterministic.
    let indices = []
    for e in entries {
      let name = name_str(e.0)
      // Ignore the attribute owner
      if name == "O" {
        continue
      }
      guard tags_attribute_index(name) is Some(idx) else {
        raise PdfTagsError("unhandled key `\{name}`")
      }
      indices.push(idx)
    }
    indices.sort()
    for idx in indices {
      let (name, fmt) = tags_attributes[idx]
      let val = f.get(attrs, name).unwrap()
      format_attr(f, name, val, fmt)
    }
  }
}

///|
/// The sorted list of PDF structure element attributes and how to format
/// them.
let tags_attributes : Array[
  (String, (TagsFormatter, @pdfsyntax.PdfObject) -> Bool),
] = [
  // List
  ("ListNumbering", format_name),
  // Table
  ("Summary", format_str),
  ("Scope", format_name),
  ("Headers", (f, val) => format_array(f, val, format_byte_str)),
  ("RowSpan", format_int),
  ("ColSpan", format_int),
  // Layout
  ("Placement", format_name),
  ("WritingMode", format_name),
  ("BBox", (f, val) => format_array(f, val, format_float)),
  ("Width", format_float),
  ("Height", format_float),
  ("BackgroundColor", format_color),
  ("BorderColor", (f, val) => format_sides(f, val, format_color)),
  ("BorderStyle", (f, val) => format_sides(f, val, format_name)),
  ("BorderThickness", (f, val) => format_sides(f, val, format_float)),
  ("Padding", (f, val) => format_sides(f, val, format_float)),
  ("Color", format_color),
  ("SpaceBefore", format_float),
  ("SpaceAfter", format_float),
  ("StartIndent", format_float),
  ("EndIndent", format_float),
  ("TextIndent", format_float),
  ("TextAlign", format_name),
  ("BlockAlign", format_name),
  ("InlineAlign", format_name),
  ("TBorderStyle", (f, val) => format_sides(f, val, format_name)),
  ("TPadding", (f, val) => format_sides(f, val, format_float)),
  ("BaselineShift", format_float),
  ("LineHeight", (f, val) => format_float(f, val) || format_name(f, val)),
  ("TextDecorationColor", format_color),
  ("TextDecorationThickness", format_float),
  ("TextDecorationType", format_name),
  (
    "GlyphOrientationVertical",
    (f, val) => format_int(f, val) || format_name(f, val),
  ),
  ("ColumnCount", format_int),
  ("ColumnGap", (f, val) => format_array(f, val, format_float)),
  ("ColumnWidths", (f, val) => format_array(f, val, format_float)),
]

///|
fn tags_attribute_index(name : String) -> Int? {
  for i, a in tags_attributes {
    if a.0 == name {
      return Some(i)
    }
  }
  None
}

///|
fn format_attr(
  f : TagsFormatter,
  name : String,
  val : @pdfsyntax.PdfObject,
  fmt : (TagsFormatter, @pdfsyntax.PdfObject) -> Bool,
) -> Unit raise {
  f.write("/\{name}:")
  f.maybe_space = Some(" ")
  f.indent += 1
  if !fmt(f, f.r.doc.direct(val)) {
    raise PdfTagsError("couldn't format `\{name}`")
  }
  f.indent -= 1
  f.write("\n")
}

///|
fn format_int(f : TagsFormatter, val : @pdfsyntax.PdfObject) -> Bool {
  match val {
    PdfInteger(i) => {
      f.write(i.to_string())
      true
    }
    PdfReal(r) | PdfExactReal(r) => {
      f.write(r.to_int64().to_string())
      true
    }
    _ => false
  }
}

///|
fn format_float(f : TagsFormatter, val : @pdfsyntax.PdfObject) -> Bool {
  guard obj_f64(val) is Some(v) else { return false }
  let s = @library.rust_fixed_f64(v, 3)
  f.write(" ".repeat(@cmp.maximum(0, 7 - s.length())) + s)
  true
}

///|
fn format_name(f : TagsFormatter, val : @pdfsyntax.PdfObject) -> Bool {
  guard val is PdfNameObject(n) else { return false }
  f.write(name_str(n))
  true
}

///|
fn format_str(f : TagsFormatter, val : @pdfsyntax.PdfObject) -> Bool {
  guard val is PdfString(b) else { return false }
  let b : Bytes = b
  if b.length() >= 2 && b[0] == b'\xFE' && b[1] == b'\xFF' {
    f.write(dq(pdf_text_string(b)))
  } else {
    f.write(dq(@utf8.decode_lossy(b[:])))
  }
  true
}

///|
fn format_byte_str(f : TagsFormatter, val : @pdfsyntax.PdfObject) -> Bool {
  guard val is PdfString(b) else { return false }
  let b : Bytes = b
  let plain = b
    .iter()
    .all(c => {
      (c >= b'0' && c <= b'9') ||
      (c >= b'a' && c <= b'z') ||
      (c >= b'A' && c <= b'Z') ||
      c == b' ' ||
      c == b'-' ||
      c == b'_'
    })
  if plain {
    f.write(dq(latin1(b)))
  } else {
    let sb = StringBuilder()
    sb.write_string("0x")
    for c in b {
      let h = c.to_int()
      sb.write_char("0123456789abcdef".get_char(h >> 4).unwrap())
      sb.write_char("0123456789abcdef".get_char(h & 15).unwrap())
    }
    f.write(sb.to_string())
  }
  true
}

///|
fn format_color(f : TagsFormatter, val : @pdfsyntax.PdfObject) -> Bool {
  guard val is PdfArray(items) && items.length() == 3 else { return false }
  let sb = StringBuilder()
  sb.write_char('#')
  for item in items {
    guard obj_f64(f.r.doc.direct(item)) is Some(n) else { return false }
    let v = @library.rust_round(255.0 * n)
    let v = if v < 0.0 { 0 } else if v > 255.0 { 255 } else { v.to_int() }
    sb.write_char("0123456789abcdef".get_char(v >> 4).unwrap())
    sb.write_char("0123456789abcdef".get_char(v & 15).unwrap())
  }
  f.write(sb.to_string())
  true
}

///|
fn format_array(
  f : TagsFormatter,
  val : @pdfsyntax.PdfObject,
  fmt : (TagsFormatter, @pdfsyntax.PdfObject) -> Bool,
) -> Bool {
  match val {
    PdfArray(items) => {
      f.indent += 1
      f.write("[")
      for i, item in items {
        if i != 0 {
          f.write(", ")
        }
        if !fmt(f, f.r.doc.direct(item)) {
          return false
        }
      }
      f.write("]")
      f.indent -= 1
      true
    }
    val => fmt(f, val)
  }
}

///|
fn format_sides(
  f : TagsFormatter,
  val : @pdfsyntax.PdfObject,
  fmt : (TagsFormatter, @pdfsyntax.PdfObject) -> Bool,
) -> Bool {
  match val {
    PdfArray(items) if items.length() == 4 => {
      let names = [
        ("before", " "),
        ("after", "  "),
        ("start", "  "),
        ("end", "    "),
      ]
      for i, entry in names {
        let (name, space) = entry
        f.write("\n\{name}:")
        f.maybe_space = Some(space)
        f.indent += 1
        if !fmt(f, f.r.doc.direct(items[i])) {
          return false
        }
        f.indent -= 1
      }
      true
    }
    val => fmt(f, val)
  }
}

///|
fn assert_type(
  f : TagsFormatter,
  obj : @pdfsyntax.PdfObject,
  expected : String,
) -> Unit raise {
  guard f.get_name(obj, "Type") is Some(found) else {
    raise PdfTagsError("missing object type")
  }
  if found != expected {
    raise PdfTagsError("expected object type `\{expected}` found `\{found}`")
  }
}

///|
/// Whether a test case is a `pdftags` test.
fn is_pdftags(attrs : String) -> Bool {
  attrs.split(" ").any(a => a == "pdftags")
}
