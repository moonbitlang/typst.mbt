// The `pdf-semantic` stage (see `oracle/src/pdf_semantic.rs`): export every
// paged test to PDF like the upstream harness and compare a canonical
// semantic description of the file (text, paths, images, annotations,
// destinations, outline, page labels, metadata, attachments). The
// extraction below mirrors the oracle's `extract` line by line, but reads
// the PDF with pdflite.
//
// Numbers are compared with a tolerance of 0.02 (see [pdf_semantic_matches])
// since the exporters compute in `f32` (krilla) and `f64` (here).

///|
/// Compile a single test case, export it to PDF and dump its semantics.
fn pdf_semantic_report(rel : String, tc : TestCase) -> String {
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
      if pdf_save_dir.val is Some(dir) {
        let path = "\{dir}/\{rel.unsafe_substring(start=0, end=rel.length() - 4)}/\{tc.name}.pdf"
        ensure_parent_dir(path)
        @fs.write_bytes_to_file(path, bytes) catch {
          _ => ()
        }
      }
      out.write_string(pdf_extract(bytes))
    }
  }
  out.to_string()
}

///|
/// Where the oracle saved upstream's PDFs (`--upstream-pdfs=<dir>`).
let upstream_pdf_dir : Ref[String?] = Ref(None)

///|
/// Run the MoonBit extractor on upstream's PDF of a test case and keep the
/// diagnostics of the golden (they don't come from the extractor).
fn pdf_extract_check_report(rel : String, tc : TestCase) -> String {
  let golden = pdf_semantic_golden(rel).get(tc.name).unwrap_or("")
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
  // Keep the diagnostic lines of the golden.
  let out = StringBuilder()
  for line in golden.split("\n") {
    if line.has_prefix("warning ") || line.has_prefix("  hint ") {
      out.write_string(line.to_owned())
      out.write_char('\n')
    }
  }
  out.write_string(pdf_extract(bytes))
  out.to_string()
}

///|
/// The parsed `pdf-semantic` golden of a test file, cached per file.
fn pdf_semantic_golden(rel : String) -> Map[String, String] {
  if pdf_golden_cache.get(rel) is Some(m) {
    return m
  }
  let path = golden_dir +
    "/pdf-semantic/" +
    rel.unsafe_substring(start=0, end=rel.length() - 4) +
    ".txt"
  let m = split_golden(read(path))
  pdf_golden_cache.clear()
  pdf_golden_cache[rel] = m
  m
}

///|
let pdf_golden_cache : Map[String, Map[String, String]] = Map([])

///|
/// Where to save the exported PDFs (`--save-pdf=<dir>`).
let pdf_save_dir : Ref[String?] = Ref(None)

///|
/// Compile a test case to a paged document like the oracle (setting the
/// title to the test name if the document has none).
fn pdf_compile(
  rel : String,
  tc : TestCase,
) -> (TestWorld, @syntax.FileId, @layout.PagedDocument)? {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let id = source.id()
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  match warned.output {
    Ok(doc) => {
      let info = doc.info_mut()
      if info.title is None {
        info.title = Some(tc.name)
      }
      Some((world, id, doc))
    }
    Err(_) => None
  }
}

///|
/// Like upstream `Pdf::make_live`.
fn make_live(
  doc : @layout.PagedDocument,
  untagged~ : Bool = false,
) -> @library.Warned[Result[Bytes, Array[@library.SourceDiagnostic]]] {
  let doc_opts = @pdf.PdfFormatOptions::get(doc.options())
  let standards = doc_opts.standard.v.standards()
  match standards {
    [] => generate_pdf(doc, Some([]), untagged~)
    [V_1_7, UA_1] => generate_pdf(doc, Some([UA_1]))
    _ => generate_pdf(doc, None, untagged~)
  }
}

///|
fn generate_pdf(
  doc : @layout.PagedDocument,
  standards : Array[@library.PdfStandard]?,
  untagged~ : Bool = false,
) -> @library.Warned[Result[Bytes, Array[@library.SourceDiagnostic]]] {
  let standard = match standards {
    Some(s) =>
      Some(
        @library.PdfStandards::new(s) catch {
          _ => abort("invalid test standards")
        },
      )
    None => None
  }
  let options : @pdf.PdfOptions = {
    ..@pdf.PdfOptions::default(),
    creator: Custom(Some("Typst Test Runner")),
    format: {
      ..@pdf.PartialPdfFormatOptions::default(),
      standard,
      tagged: if untagged {
        Some(Custom(false))
      } else {
        None
      },
    },
  }
  @pdf.pdf(doc, options)
}

///|
/// Whether two dumps match: equal up to numbers within 0.02.
fn pdf_semantic_matches(expected : String, actual : String) -> Bool {
  if expected == actual {
    return true
  }
  let e = expected.split("\n").collect()
  let a = actual.split("\n").collect()
  if e.length() != a.length() {
    return false
  }
  for i in 0..<e.length() {
    if e[i] != a[i] && !line_matches(e[i].to_owned(), a[i].to_owned()) {
      return false
    }
  }
  true
}

///|
fn line_matches(e : String, a : String) -> Bool {
  let et = number_tokens(e)
  let at = number_tokens(a)
  if et.length() != at.length() {
    return false
  }
  for i in 0..<et.length() {
    match (et[i], at[i]) {
      (Num(x), Num(y)) => if (x - y).abs() > 0.0201 { return false }
      (Text(x), Text(y)) => if x != y { return false }
      _ => return false
    }
  }
  true
}

///|
priv enum Token {
  Num(Double)
  Text(String)
}

///|
/// Split a line into numbers (`-?\d+\.\d+`) and the text between them.
fn number_tokens(s : String) -> Array[Token] {
  let out = []
  let chars = s.to_array()
  let mut i = 0
  let text = StringBuilder()
  while i < chars.length() {
    let c = chars[i]
    let start = i
    let mut j = i
    if c == '-' {
      j += 1
    }
    let digits_start = j
    while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
      j += 1
    }
    let is_num = j > digits_start &&
      j + 1 < chars.length() &&
      chars[j] == '.' &&
      chars[j + 1] >= '0' &&
      chars[j + 1] <= '9' &&
      (start == 0 || !chars[start - 1].is_ascii_alphabetic())
    if is_num {
      j += 1
      while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
        j += 1
      }
      let lit = String::from_array(chars[start:j])
      out.push(Text(text.to_string()))
      text.reset()
      out.push(Num(@string.parse_double(lit) catch { _ => 0.0 }))
      i = j
    } else {
      text.write_char(c)
      i += 1
    }
  }
  out.push(Text(text.to_string()))
  out
}

// ---------------------------------------------------------------------------
// Extraction (mirrors `oracle/src/pdf_semantic.rs`).
// ---------------------------------------------------------------------------

///|
fn pdf_name(s : String) -> @pdfcore.PdfName {
  @pdfcore.PdfName(
    // pdflite's names include the leading slash.
    @pdfexport.utf8_bytes("/" + s),
  )
}

///|
fn name_str(n : @pdfcore.PdfName) -> String {
  let s = latin1(n.bytes())
  if s.has_prefix("/") {
    s.unsafe_substring(start=1, end=s.length())
  } else {
    s
  }
}

///|
fn latin1(b : Bytes) -> String {
  let sb = StringBuilder()
  for x in b {
    sb.write_char(x.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Decode a PDF text string (UTF-16BE with BOM, UTF-8 with BOM, or
/// PDFDocEncoding approximated by Latin-1).
fn pdf_text_string(b : Bytes) -> String {
  if b.length() >= 2 && b[0] == b'\xFE' && b[1] == b'\xFF' {
    let sb = StringBuilder()
    let units = []
    let mut i = 2
    while i + 1 < b.length() {
      units.push((b[i].to_int() << 8) | b[i + 1].to_int())
      i += 2
    }
    decode_utf16_lossy(units, sb)
    sb.to_string()
  } else if b.length() >= 3 &&
    b[0] == b'\xEF' &&
    b[1] == b'\xBB' &&
    b[2] == b'\xBF' {
    @utf8.decode_lossy(b[3:])
  } else {
    latin1(b)
  }
}

///|
fn decode_utf16_lossy(units : Array[Int], sb : StringBuilder) -> Unit {
  let mut i = 0
  while i < units.length() {
    let u = units[i]
    if u >= 0xD800 && u <= 0xDBFF {
      if i + 1 < units.length() &&
        units[i + 1] >= 0xDC00 &&
        units[i + 1] <= 0xDFFF {
        let cp = 0x10000 + ((u - 0xD800) << 10) + (units[i + 1] - 0xDC00)
        sb.write_char(cp.unsafe_to_char())
        i += 2
        continue
      }
      sb.write_char('\u{FFFD}')
    } else if u >= 0xDC00 && u <= 0xDFFF {
      sb.write_char('\u{FFFD}')
    } else {
      sb.write_char(u.unsafe_to_char())
    }
    i += 1
  }
}

///|
fn num2(v : Double) -> String {
  let s = @library.rust_fixed_f64(v, 2)
  if s == "-0.00" {
    "0.00"
  } else {
    s
  }
}

///|
fn num3(v : Double) -> String {
  let s = @library.rust_fixed_f64(v, 3)
  if s == "-0.000" {
    "0.000"
  } else {
    s
  }
}

///|
fn dq(s : String) -> String {
  @unicode.rust_debug_str(s)
}

///|
priv struct PdfReader {
  doc : @pdflite.PdfDocument
  pages : Array[Int]
  named : Array[(String, @pdfsyntax.PdfObject)]
}

///|
fn PdfReader::get(
  self : PdfReader,
  obj : @pdfsyntax.PdfObject,
  key : String,
) -> @pdfsyntax.PdfObject? {
  self.doc.lookup_direct(pdf_name(key), obj)
}

///|
fn PdfReader::get_raw(
  self : PdfReader,
  obj : @pdfsyntax.PdfObject,
  key : String,
) -> @pdfsyntax.PdfObject? {
  guard self.doc.direct(obj).dictionary_view() is Some(entries) else {
    return None
  }
  for e in entries {
    if e.0 == pdf_name(key) {
      return Some(e.1)
    }
  }
  None
}

///|
fn obj_str(o : @pdfsyntax.PdfObject) -> String? {
  match o {
    PdfString(b) => Some(pdf_text_string(b))
    PdfNameObject(n) => Some(name_str(n))
    _ => None
  }
}

///|
fn obj_f64(o : @pdfsyntax.PdfObject) -> Double? {
  match o {
    PdfInteger(i) => Some(i.to_double())
    PdfReal(r) | PdfExactReal(r) => Some(r)
    _ => None
  }
}

///|
fn PdfReader::array(
  self : PdfReader,
  o : @pdfsyntax.PdfObject,
) -> Array[@pdfsyntax.PdfObject] {
  match self.doc.direct(o) {
    PdfArray(items) => items.map(x => self.doc.direct(x))
    _ => []
  }
}

///|
fn PdfReader::rect(
  self : PdfReader,
  o : @pdfsyntax.PdfObject,
) -> Array[Double]? {
  let v = []
  for x in self.array(o) {
    if obj_f64(x) is Some(n) {
      v.push(n)
    }
  }
  if v.length() == 4 {
    Some(v)
  } else {
    None
  }
}

///|
fn fmt_rect(r : Array[Double]) -> String {
  "[\{num2(r[0])} \{num2(r[1])} \{num2(r[2])} \{num2(r[3])}]"
}

///|
fn PdfReader::stream_data(self : PdfReader, o : @pdfsyntax.PdfObject) -> Bytes? {
  let o = self.doc.direct(o)
  guard o is PdfStreamObject(_) else { return None }
  let decoded = @pdflite.pdf_decode_stream(o) catch { _ => return None }
  match decoded {
    PdfStreamObject(s) =>
      Some(@pdfsyntax.pdf_stream_data_bytes(s.data) catch { _ => return None })
    _ => None
  }
}

///|
fn PdfReader::explicit_dest(
  self : PdfReader,
  arr : Array[@pdfsyntax.PdfObject],
) -> String {
  let page = match arr.get(0) {
    Some(PdfIndirect(r)) =>
      match self.pages.search(r) {
        Some(i) => i.to_string()
        None => "?"
      }
    _ => "?"
  }
  let kind = match arr.get(1) {
    Some(o) => self.doc.direct(o) |> obj_str |> Option::unwrap_or("")
    None => ""
  }
  let rest = []
  for i in 2..<arr.length() {
    rest.push(
      match obj_f64(self.doc.direct(arr[i])) {
        Some(n) => num2(n)
        None => "null"
      },
    )
  }
  if kind == "XYZ" && rest.length() >= 2 {
    "page \{page} xyz \{rest[0]} \{rest[1]}"
  } else {
    "page \{page} \{kind.to_lower()} \{rest.join(" ")}"
  }
}

///|
fn PdfReader::named_target(self : PdfReader, name : String) -> String {
  for e in self.named {
    if e.0 == name {
      return match self.doc.direct(e.1) {
        PdfArray(a) => self.explicit_dest(a)
        PdfDictionary(_) as d =>
          match self.get(d, "D") {
            Some(PdfArray(a)) => self.explicit_dest(a)
            _ => "?"
          }
        _ => "?"
      }
    }
  }
  "?"
}

///|
fn PdfReader::dest(self : PdfReader, o : @pdfsyntax.PdfObject) -> String {
  match self.doc.direct(o) {
    PdfArray(a) => self.explicit_dest(a)
    PdfString(_) | PdfNameObject(_) as s => {
      let name = obj_str(s).unwrap()
      "named \{dq(name)} -> \{self.named_target(name)}"
    }
    PdfDictionary(_) as d =>
      match self.get(d, "D") {
        Some(inner) => self.dest(inner)
        None => "?"
      }
    _ => "?"
  }
}

///|
fn PdfReader::target(self : PdfReader, d : @pdfsyntax.PdfObject) -> String {
  if self.get(d, "Dest") is Some(dest) {
    return self.dest(dest)
  }
  if self.get(d, "A") is Some(action) {
    let s = match self.get(action, "S") {
      Some(PdfNameObject(n)) => name_str(n)
      _ => ""
    }
    match s {
      "URI" => {
        let uri = match self.get(action, "URI") {
          Some(o) => obj_str(o).unwrap_or("")
          None => ""
        }
        return "uri \{dq(uri)}"
      }
      "GoTo" =>
        if self.get(action, "D") is Some(dest) {
          return self.dest(dest)
        }
      _ => return "action \{s}"
    }
  }
  "none"
}

///|
fn PdfReader::name_tree(
  self : PdfReader,
  node : @pdfsyntax.PdfObject,
  out : Array[(String, @pdfsyntax.PdfObject)],
) -> Unit {
  if self.get(node, "Names") is Some(names) {
    let items = self.array(names)
    let mut i = 0
    while i + 1 < items.length() {
      if obj_str(items[i]) is Some(k) {
        out.push((k, items[i + 1]))
      }
      i += 2
    }
  }
  if self.get(node, "Kids") is Some(kids) {
    for kid in self.array(kids) {
      self.name_tree(kid, out)
    }
  }
}

///|
fn PdfReader::number_tree(
  self : PdfReader,
  node : @pdfsyntax.PdfObject,
  out : Array[(Int, @pdfsyntax.PdfObject)],
) -> Unit {
  if self.get(node, "Nums") is Some(nums) {
    let items = self.array(nums)
    let mut i = 0
    while i + 1 < items.length() {
      if items[i] is PdfInteger(k) {
        out.push((k, items[i + 1]))
      }
      i += 2
    }
  }
  if self.get(node, "Kids") is Some(kids) {
    for kid in self.array(kids) {
      self.number_tree(kid, out)
    }
  }
}

///|
/// Find the value of an XMP property (element or attribute form).
fn xmp_value(xml : String, key : String) -> String? {
  let attr = "\{key}=\""
  if xml.find(attr) is Some(at) {
    let rest = xml.view(start_offset=at + attr.length())
    return match rest.find("\"") {
      Some(end) => Some(xml_unescape(rest.view(end_offset=end).to_owned()))
      None => None
    }
  }
  let open = "<\{key}"
  guard xml.find(open) is Some(at) else { return None }
  let rest = xml.view(start_offset=at + open.length())
  guard rest.find(">") is Some(gt) else { return None }
  if rest.view(end_offset=gt).has_suffix("/") {
    return Some("")
  }
  let body = rest.view(start_offset=gt + 1)
  let close = "</\{key}>"
  guard body.find(close) is Some(end) else { return None }
  let body = body.view(end_offset=end)
  if body.find("<rdf:li") is Some(li) {
    let rest = body.view(start_offset=li)
    guard rest.find(">") is Some(gt) else { return None }
    let inner = rest.view(start_offset=gt + 1)
    guard inner.find("</rdf:li>") is Some(end) else { return None }
    return Some(xml_unescape(inner.view(end_offset=end).to_owned()))
  }
  Some(xml_unescape(body.trim().to_owned()))
}

///|
fn xml_unescape(s : String) -> String {
  s
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
  .replace_all(old="&amp;", new="&")
}

///|
/// Extract the canonical semantic description of a PDF.
fn pdf_extract(bytes : Bytes) -> String {
  pdf_extract_impl(bytes) catch {
    e => "<extract-error \{dq(e.to_string())}>\n"
  }
}

///|
fn pdf_extract_impl(bytes : Bytes) -> String raise {
  let doc = @pdflite.pdf_read_document_from_bytes(bytes)
  let out = StringBuilder()
  let version = if bytes.length() >= 8 {
    latin1(bytes[5:8].to_owned())
  } else {
    ""
  }
  out.write_string("version \{version}\n")
  let r0 : PdfReader = { doc, pages: [], named: [], }
  let trailer = doc.trailer_dict()
  if r0.get(trailer, "Info") is Some(info) {
    for key in ["Title", "Author", "Subject", "Keywords", "Creator"] {
      if r0.get(info, key) is Some(PdfString(b)) {
        out.write_string("info \{key} \{dq(pdf_text_string(b))}\n")
      }
    }
    if r0.get(info, "CreationDate") is Some(PdfString(b)) &&
      parse_pdf_date(latin1(b)) is Some(d) {
      out.write_string("info CreationDate \{d}\n")
    }
  }
  let catalog = doc.catalog()
  if r0.get(catalog, "Lang") is Some(o) && obj_str(o) is Some(lang) {
    out.write_string("catalog lang \{dq(lang)}\n")
  }
  if r0.get(catalog, "ViewerPreferences") is Some(vp) &&
    r0.get(vp, "DisplayDocTitle") is Some(PdfBoolean(b)) {
    out.write_string("catalog display-doc-title \{b}\n")
  }
  if r0.get(catalog, "MarkInfo") is Some(mi) &&
    r0.get(mi, "Marked") is Some(PdfBoolean(b)) {
    out.write_string("catalog marked \{b}\n")
  }
  out.write_string(
    "catalog struct-tree \{r0.get_raw(catalog, "StructTreeRoot") is Some(_)}\n",
  )
  if r0.get(catalog, "Metadata") is Some(meta) &&
    r0.stream_data(meta) is Some(data) {
    let xml = @utf8.decode_lossy(data[:])
    for
      key in [
        "dc:language", "pdfaid:part", "pdfaid:conformance", "pdfuaid:part",
      ] {
      if xmp_value(xml, key) is Some(v) {
        out.write_string("xmp \{key} \{dq(v)}\n")
      }
    }
  }
  // Pages and named destinations.
  let pages = doc.page_reference_numbers()
  let named = []
  if r0.get(catalog, "Names") is Some(names) &&
    r0.get(names, "Dests") is Some(dests) {
    r0.name_tree(dests, named)
  }
  if r0.get(catalog, "Dests") is Some(dests) &&
    doc.direct(dests).dictionary_view() is Some(entries) {
    for e in entries {
      named.push((name_str(e.0), e.1))
    }
  }
  let r : PdfReader = { doc, pages, named, }
  if r.get(catalog, "PageLabels") is Some(labels) {
    let entries = []
    r.number_tree(labels, entries)
    for entry in entries {
      let (idx, label) = entry
      let label = doc.direct(label)
      guard label is PdfDictionary(_) else { continue }
      let style = match r.get(label, "S") {
        Some(PdfNameObject(n)) => name_str(n)
        _ => "-"
      }
      out.write_string("label \{idx} style=\{style}")
      if r.get(label, "P") is Some(p) && obj_str(p) is Some(p) {
        out.write_string(" prefix=\{dq(p)}")
      }
      if r.get(label, "St") is Some(s) && obj_f64(s) is Some(s) {
        out.write_string(" start=\{s.to_int64()}")
      }
      out.write_string("\n")
    }
  }
  for i, page_num in pages {
    let page = doc.lookup_object_or_null(page_num)
    let media = match r.get(page, "MediaBox") {
      Some(m) => r.rect(m).map(fmt_rect).unwrap_or("?")
      None => "?"
    }
    out.write_string("page \{i} media \{media}")
    if r.get(page, "TrimBox") is Some(t) && r.rect(t) is Some(t) {
      out.write_string(" trim \{fmt_rect(t)}")
    }
    out.write_string("\n")
    let interp = Interp::new(r, out)
    let resources = r.get(page, "Resources").unwrap_or(PdfDictionary([]))
    match r.get(page, "Contents") {
      Some(contents) => {
        let parts = match doc.direct(contents) {
          PdfArray(items) => items
          c => [c]
        }
        let data = Buffer()
        for p in parts {
          if r.stream_data(p) is Some(d) {
            data.write_bytes(d)
            data.write_byte(b'\n')
          }
        }
        interp.run(data.to_bytes(), resources, identity_matrix, 0)
      }
      None => ()
    }
    interp.flush()
    if r.get(page, "Annots") is Some(annots) {
      for annot in r.array(annots) {
        let subtype = match r.get(annot, "Subtype") {
          Some(PdfNameObject(n)) => name_str(n)
          _ => ""
        }
        let rect = match r.get(annot, "Rect") {
          Some(o) => r.rect(o).map(fmt_rect).unwrap_or("?")
          None => "?"
        }
        out.write_string("  annot \{subtype} \{rect} \{r.target(annot)}")
        if r.get(annot, "Contents") is Some(c) && obj_str(c) is Some(c) {
          out.write_string(" contents \{dq(c)}")
        }
        out.write_string("\n")
      }
    }
  }
  let sorted = named.copy()
  sorted.sort_by((a, b) => @library.compare_str(a.0, b.0))
  for e in sorted {
    out.write_string("dest \{dq(e.0)} \{r.named_target(e.0)}\n")
  }
  if r.get(catalog, "Outlines") is Some(outlines) &&
    r.get(outlines, "First") is Some(first) {
    outline_items(r, first, 0, out)
  }
  if r.get(catalog, "Names") is Some(names) &&
    r.get(names, "EmbeddedFiles") is Some(files) {
    let entries = []
    r.name_tree(files, entries)
    for entry in entries {
      let (name, spec) = entry
      let spec = doc.direct(spec)
      guard spec is PdfDictionary(_) else { continue }
      let uf = match r.get(spec, "UF") {
        Some(o) => obj_str(o).unwrap_or("")
        None => ""
      }
      out.write_string("attach \{dq(name)} uf=\{dq(uf)}")
      if r.get(spec, "Desc") is Some(d) && obj_str(d) is Some(d) {
        out.write_string(" desc=\{dq(d)}")
      }
      let rel = match r.get(spec, "AFRelationship") {
        Some(PdfNameObject(n)) => name_str(n)
        _ => "-"
      }
      let ef = match r.get(spec, "EF") {
        Some(ef) => r.get(ef, "F")
        None => None
      }
      let mime = match ef {
        Some(s) =>
          match r.get(s, "Subtype") {
            Some(PdfNameObject(n)) => name_str(n)
            _ => "-"
          }
        None => "-"
      }
      let size = match ef {
        Some(s) =>
          match r.stream_data(s) {
            Some(d) => d.length().to_string()
            None => "?"
          }
        None => "?"
      }
      out.write_string(" rel=\{rel} mime=\{mime} size=\{size}\n")
    }
  }
  out.to_string()
}

///|
/// Format a PDF date (`D:YYYYMMDDHHmmSS+HH'mm`) like hayro's `DateTime`.
fn parse_pdf_date(s : String) -> String? {
  let s = if s.has_prefix("D:") {
    s.unsafe_substring(start=2, end=s.length())
  } else {
    s
  }
  let digits = (from : Int, len : Int, default : Int) => {
    if from + len > s.length() {
      return default
    }
    let mut v = 0
    for i in from..<(from + len) {
      let c = s.unsafe_get(i).to_int()
      if c < '0'.to_int() || c > '9'.to_int() {
        return default
      }
      v = v * 10 + (c - '0'.to_int())
    }
    v
  }
  if s.length() < 4 {
    return None
  }
  let year = digits(0, 4, 0)
  let month = digits(4, 2, 1)
  let day = digits(6, 2, 1)
  let hour = digits(8, 2, 0)
  let minute = digits(10, 2, 0)
  let second = digits(12, 2, 0)
  let (sign, oh, om) = if s.length() > 14 {
    match s.unsafe_get(14).unsafe_to_char() {
      '+' => ("+", digits(15, 2, 0), digits(18, 2, 0))
      '-' => ("-", digits(15, 2, 0), digits(18, 2, 0))
      _ => ("+", 0, 0)
    }
  } else {
    ("+", 0, 0)
  }
  let p2 = (v : Int) => if v < 10 { "0\{v}" } else { v.to_string() }
  let p4 = (v : Int) => {
    let t = v.to_string()
    "0000".unsafe_substring(start=0, end=@cmp.maximum(0, 4 - t.length())) + t
  }
  Some(
    "\{p4(year)}-\{p2(month)}-\{p2(day)} \{p2(hour)}:\{p2(minute)}:\{p2(second)} \{sign}\{p2(oh)}:\{p2(om)}",
  )
}

///|
fn outline_items(
  r : PdfReader,
  item : @pdfsyntax.PdfObject,
  depth : Int,
  out : StringBuilder,
) -> Unit {
  let mut cur = Some(item)
  while cur is Some(item) {
    let title = match r.get(item, "Title") {
      Some(o) => obj_str(o).unwrap_or("")
      None => ""
    }
    let indent = StringBuilder()
    for _ in 0..<depth {
      indent.write_string("  ")
    }
    out.write_string("outline \{indent}\{dq(title)} \{r.target(item)}\n")
    if r.get(item, "First") is Some(first) {
      outline_items(r, first, depth + 1, out)
    }
    cur = r.get(item, "Next")
  }
}

// ---------------------------------------------------------------------------
// Content stream interpretation
// ---------------------------------------------------------------------------

///|
priv struct Matrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
let identity_matrix : Matrix = {
  a: 1.0,
  b: 0.0,
  c: 0.0,
  d: 1.0,
  e: 0.0,
  f: 0.0,
}

///|
/// `x × y` (apply `x`, then `y`).
fn mmul(x : Matrix, y : Matrix) -> Matrix {
  {
    a: x.a * y.a + x.b * y.c,
    b: x.a * y.b + x.b * y.d,
    c: x.c * y.a + x.d * y.c,
    d: x.c * y.b + x.d * y.d,
    e: x.e * y.a + x.f * y.c + y.e,
    f: x.e * y.b + x.f * y.d + y.f,
  }
}

///|
fn mapply(m : Matrix, x : Double, y : Double) -> (Double, Double) {
  (m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f)
}

///|
fn of_tm(t : @pdfgeometry.TransformMatrix) -> Matrix {
  { a: t.a, b: t.b, c: t.c, d: t.d, e: t.e, f: t.f, }
}

///|
priv struct Paint {
  space : String
  mut comps : Array[Double]
  mut pattern : String?
}

///|
fn Paint::new(space : String) -> Paint {
  let comps = match space {
    "rgb" => [0.0, 0.0, 0.0]
    "cmyk" => [0.0, 0.0, 0.0, 1.0]
    _ => [0.0]
  }
  { space, comps, pattern: None, }
}

///|
fn Paint::copy(self : Paint) -> Paint {
  { space: self.space, comps: self.comps, pattern: self.pattern, }
}

///|
fn Paint::fmt(self : Paint, alpha : Double) -> String {
  let s = match self.pattern {
    Some(p) => "pattern(\{p})"
    None => "\{self.space}(\{self.comps.map(num3).join(",")})"
  }
  if alpha != 1.0 {
    "\{s}@\{num2(alpha)}"
  } else {
    s
  }
}

///|
priv struct GState {
  mut ctm : Matrix
  mut fill : Paint
  mut stroke : Paint
  mut fill_alpha : Double
  mut stroke_alpha : Double
  mut soft_mask : Bool
}

///|
fn GState::copy(self : GState) -> GState {
  {
    ctm: self.ctm,
    fill: self.fill.copy(),
    stroke: self.stroke.copy(),
    fill_alpha: self.fill_alpha,
    stroke_alpha: self.stroke_alpha,
    soft_mask: self.soft_mask,
  }
}

///|
priv struct TextBlock {
  mut origin : (Double, Double)?
  mut size : Double
  mut font : String
  mut fill : String
  text : StringBuilder
}

///|
priv struct FontInfo {
  name : String
  two_byte : Bool
  to_unicode : Map[Int, String]
}

///|
priv struct Interp {
  r : PdfReader
  out : StringBuilder
  stack : Array[GState]
  mut gs : GState
  mut tm : Matrix
  mut tlm : Matrix
  mut font : FontInfo?
  mut font_size : Double
  mut rise : Double
  mut leading : Double
  mut block : TextBlock?
  marked : Array[String?]
  path : Array[(Double, Double)]
}

///|
fn Interp::new(r : PdfReader, out : StringBuilder) -> Interp {
  {
    r,
    out,
    stack: [],
    gs: {
      ctm: identity_matrix,
      fill: Paint::new("gray"),
      stroke: Paint::new("gray"),
      fill_alpha: 1.0,
      stroke_alpha: 1.0,
      soft_mask: false,
    },
    tm: identity_matrix,
    tlm: identity_matrix,
    font: None,
    font_size: 0.0,
    rise: 0.0,
    leading: 0.0,
    block: None,
    marked: [],
    path: [],
  }
}

///|
fn Interp::flush(self : Interp) -> Unit {
  if self.block is Some(b) {
    self.block = None
    if b.origin is Some((x, y)) {
      self.out.write_string(
        "  text [\{num2(x)} \{num2(y)}] \{num2(b.size)} \{b.font} \{b.fill} \{dq(b.text.to_string())}\n",
      )
    }
  }
}

///|
fn Interp::in_actual_text(self : Interp) -> Bool {
  self.marked.iter().any(m => m is Some(_))
}

///|
fn Interp::run(
  self : Interp,
  content : Bytes,
  resources : @pdfsyntax.PdfObject,
  base : Matrix,
  depth : Int,
) -> Unit {
  if depth > 16 {
    return
  }
  let saved_ctm = self.gs.ctm
  self.gs.ctm = mmul(base, self.gs.ctm)
  let stack_depth = self.stack.length()
  let ops = @pdflite.pdf_parse_content_ops_from_bytes(content) catch { _ => [] }
  for op in ops {
    self.op(op, resources, depth)
  }
  while self.stack.length() > stack_depth {
    self.gs = self.stack.pop().unwrap()
  }
  self.gs.ctm = saved_ctm
}

///|
fn Interp::color_space(
  self : Interp,
  name : String,
  resources : @pdfsyntax.PdfObject,
) -> String {
  match name {
    "DeviceRGB" | "RGB" | "CalRGB" => return "rgb"
    "DeviceGray" | "G" | "CalGray" => return "gray"
    "DeviceCMYK" | "CMYK" => return "cmyk"
    "Pattern" => return "pattern"
    _ => ()
  }
  guard self.r.get(resources, "ColorSpace") is Some(cs) else { return name }
  match self.r.get(cs, name) {
    Some(PdfNameObject(n)) => self.color_space(name_str(n), resources)
    Some(PdfArray(a)) => {
      let a = a.map(x => self.r.doc.direct(x))
      let kind = a.get(0).bind(obj_str).unwrap_or("")
      match kind {
        "ICCBased" => {
          let n = match a.get(1) {
            Some(s) =>
              match self.r.get(s, "N") {
                Some(PdfInteger(n)) => n
                _ => 0
              }
            None => 0
          }
          match n {
            1 => "gray"
            3 => "rgb"
            4 => "cmyk"
            _ => "icc"
          }
        }
        "Separation" => {
          let colorant = a.get(1).bind(obj_str).unwrap_or("")
          "sep[\{colorant}]"
        }
        "Pattern" => "pattern"
        "CalRGB" => "rgb"
        "CalGray" => "gray"
        "Lab" => "lab"
        "Indexed" => "indexed"
        "DeviceN" => "devicen"
        other => other
      }
    }
    _ => name
  }
}

///|
fn Interp::pattern_kind(
  self : Interp,
  name : String,
  resources : @pdfsyntax.PdfObject,
) -> String {
  guard self.r.get(resources, "Pattern") is Some(pats) else { return "?" }
  guard self.r.get(pats, name) is Some(p) else { return "?" }
  match self.r.get(p, "PatternType") {
    Some(PdfInteger(1)) => "tiling"
    Some(PdfInteger(2)) => {
      let st = match self.r.get(p, "Shading") {
        Some(sh) =>
          match self.r.get(sh, "ShadingType") {
            Some(PdfInteger(t)) => t
            _ => 0
          }
        None => 0
      }
      "shading\{st}"
    }
    _ => "?"
  }
}

///|
fn Interp::set_color(
  self : Interp,
  stroke : Bool,
  pattern : String?,
  comps : Array[Double],
  resources : @pdfsyntax.PdfObject,
) -> Unit {
  let kind = pattern.map(p => self.pattern_kind(p, resources))
  let paint = if stroke { self.gs.stroke } else { self.gs.fill }
  paint.pattern = kind
  if !comps.is_empty() {
    paint.comps = comps
  }
}

///|
fn Interp::font_info(
  self : Interp,
  name : String,
  resources : @pdfsyntax.PdfObject,
) -> FontInfo? {
  guard self.r.get(resources, "Font") is Some(fonts) else { return None }
  guard self.r.get(fonts, name) is Some(font) else { return None }
  let subtype = match self.r.get(font, "Subtype") {
    Some(PdfNameObject(n)) => name_str(n)
    _ => ""
  }
  let mut base = match self.r.get(font, "BaseFont") {
    Some(PdfNameObject(n)) => name_str(n)
    _ => if subtype == "Type3" { "Type3" } else { "?" }
  }
  if base.length() > 7 && base.unsafe_get(6) == '+' {
    let mut tag = true
    for i in 0..<6 {
      let c = base.unsafe_get(i)
      if c < 'A' || c > 'Z' {
        tag = false
      }
    }
    if tag {
      base = base.unsafe_substring(start=7, end=base.length())
    }
  }
  if base.has_suffix("-Identity-H") {
    base = base.unsafe_substring(start=0, end=base.length() - 11)
  }
  let to_unicode : Map[Int, String] = Map([])
  if self.r.get(font, "ToUnicode") is Some(s) &&
    self.r.stream_data(s) is Some(data) {
    parse_to_unicode(data, to_unicode)
  }
  Some({ name: base, two_byte: subtype == "Type0", to_unicode, })
}

///|
fn Interp::show(self : Interp, s : Bytes) -> Unit {
  guard self.font is Some(font) else { return }
  guard self.block is Some(block) else { return }
  let trm = mmul(
    {
      a: self.font_size,
      b: 0.0,
      c: 0.0,
      d: self.font_size,
      e: 0.0,
      f: self.rise,
    },
    mmul(self.tm, self.gs.ctm),
  )
  let in_actual = self.in_actual_text()
  if block.origin is None {
    let m = mmul(
      { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: self.rise, },
      mmul(self.tm, self.gs.ctm),
    )
    block.origin = Some(mapply(m, 0.0, 0.0))
    block.size = (trm.a * trm.d - trm.b * trm.c).abs().sqrt()
    block.font = font.name
    block.fill = self.gs.fill.fmt(self.gs.fill_alpha)
  }
  let step = if font.two_byte { 2 } else { 1 }
  let mut i = 0
  while i < s.length() {
    let mut code = 0
    for k in i..<@cmp.minimum(i + step, s.length()) {
      code = (code << 8) | s[k].to_int()
    }
    if !in_actual && font.to_unicode.get(code) is Some(t) {
      block.text.write_string(t)
    }
    i += step
  }
}

///|
fn Interp::paint_path(self : Interp, op : String) -> Unit {
  let path = self.path.copy()
  self.path.clear()
  let inf = 1.0 / 0.0
  let mut x0 = inf
  let mut y0 = inf
  let mut x1 = -inf
  let mut y1 = -inf
  for p in path {
    x0 = @cmp.minimum(x0, p.0)
    y0 = @cmp.minimum(y0, p.1)
    x1 = @cmp.maximum(x1, p.0)
    y1 = @cmp.maximum(y1, p.1)
  }
  let fills = !(op == "S" || op == "s")
  let strokes = op is ("S" | "s" | "B" | "B*" | "b" | "b*")
  let bbox = if path.is_empty() { "[]" } else { fmt_rect([x0, y0, x1, y1]) }
  self.out.write_string("  path \{op} \{bbox}")
  if fills {
    self.out.write_string(" fill=\{self.gs.fill.fmt(self.gs.fill_alpha)}")
  }
  if strokes {
    self.out.write_string(" stroke=\{self.gs.stroke.fmt(self.gs.stroke_alpha)}")
  }
  if self.gs.soft_mask {
    self.out.write_string(" smask")
  }
  self.out.write_string("\n")
}

///|
fn Interp::push_pt(self : Interp, x : Double, y : Double) -> Unit {
  self.path.push(mapply(self.gs.ctm, x, y))
}

///|
fn Interp::op(
  self : Interp,
  op : @pdfcontent.PdfContentOp,
  resources : @pdfsyntax.PdfObject,
  depth : Int,
) -> Unit {
  let r = self.r
  match op {
    Op_q => self.stack.push(self.gs.copy())
    Op_Q => if self.stack.pop() is Some(gs) { self.gs = gs }
    Op_cm(t) => self.gs.ctm = mmul(of_tm(t), self.gs.ctm)
    Op_gs(name) =>
      if r.get(resources, "ExtGState") is Some(egs) &&
        r.get(egs, name_str(name)) is Some(d) {
        if r.get(d, "ca") is Some(o) && obj_f64(o) is Some(v) {
          self.gs.fill_alpha = v
        }
        if r.get(d, "CA") is Some(o) && obj_f64(o) is Some(v) {
          self.gs.stroke_alpha = v
        }
        if r.get_raw(d, "SMask") is Some(sm) {
          self.gs.soft_mask = !(r.doc.direct(sm) is PdfNameObject(_))
        }
      }
    Op_g(v) => self.gs.fill = { space: "gray", comps: [v], pattern: None, }
    Op_G(v) => self.gs.stroke = { space: "gray", comps: [v], pattern: None, }
    Op_rg(a, b, c) =>
      self.gs.fill = { space: "rgb", comps: [a, b, c], pattern: None, }
    Op_RG(a, b, c) =>
      self.gs.stroke = { space: "rgb", comps: [a, b, c], pattern: None, }
    Op_k(a, b, c, d) =>
      self.gs.fill = { space: "cmyk", comps: [a, b, c, d], pattern: None, }
    Op_K(a, b, c, d) =>
      self.gs.stroke = { space: "cmyk", comps: [a, b, c, d], pattern: None, }
    Op_cs(n) =>
      self.gs.fill = Paint::new(self.color_space(name_str(n), resources))
    Op_CS(n) =>
      self.gs.stroke = Paint::new(self.color_space(name_str(n), resources))
    Op_sc(c) | Op_scn(c) => self.set_color(false, None, c, resources)
    Op_SC(c) | Op_SCN(c) => self.set_color(true, None, c, resources)
    Op_scnName(n, c) => self.set_color(false, Some(name_str(n)), c, resources)
    Op_SCNName(n, c) => self.set_color(true, Some(name_str(n)), c, resources)
    Op_BT => {
      self.tm = identity_matrix
      self.tlm = identity_matrix
      self.block = Some({
        origin: None,
        size: 0.0,
        font: "",
        fill: "",
        text: StringBuilder(),
      })
    }
    Op_ET => self.flush()
    Op_Tf(name, size) => {
      self.font = self.font_info(name_str(name), resources)
      self.font_size = size
    }
    Op_Ts(v) => self.rise = v
    Op_TL(v) => self.leading = v
    Op_Tm(t) => {
      self.tm = of_tm(t)
      self.tlm = self.tm
    }
    Op_Td(x, y) => {
      self.tlm = mmul({ ..identity_matrix, e: x, f: y, }, self.tlm)
      self.tm = self.tlm
    }
    Op_TD(x, y) => {
      self.leading = -y
      self.tlm = mmul({ ..identity_matrix, e: x, f: y, }, self.tlm)
      self.tm = self.tlm
    }
    Op_Tstar => {
      self.tlm = mmul({ ..identity_matrix, f: -self.leading, }, self.tlm)
      self.tm = self.tlm
    }
    Op_Tj(s) | Op_quote(s) | Op_double_quote(_, _, s) => self.show(s)
    Op_TJ(arr) =>
      for item in r.array(arr) {
        if item is PdfString(s) {
          self.show(s)
        }
      }
    Op_BMC(_) => self.marked.push(None)
    Op_BDC(_, props) => {
      let props = match r.doc.direct(props) {
        PdfDictionary(_) as d => Some(d)
        PdfNameObject(n) =>
          match r.get(resources, "Properties") {
            Some(p) => r.get(p, name_str(n))
            None => None
          }
        _ => None
      }
      let actual = match props {
        Some(p) => r.get(p, "ActualText").bind(obj_str)
        None => None
      }
      if actual is Some(t) &&
        !self.in_actual_text() &&
        self.block is Some(block) {
        block.text.write_string(t)
      }
      self.marked.push(actual)
    }
    Op_EMC => self.marked.pop() |> ignore
    Op_m(x, y) | Op_l(x, y) => self.push_pt(x, y)
    Op_c(x1, y1, x2, y2, x3, y3) => {
      self.push_pt(x1, y1)
      self.push_pt(x2, y2)
      self.push_pt(x3, y3)
    }
    Op_v(x1, y1, x2, y2) | Op_y(x1, y1, x2, y2) => {
      self.push_pt(x1, y1)
      self.push_pt(x2, y2)
    }
    Op_re(x, y, w, h) => {
      self.push_pt(x, y)
      self.push_pt(x + w, y)
      self.push_pt(x + w, y + h)
      self.push_pt(x, y + h)
    }
    Op_n => self.path.clear()
    Op_f | Op_F => self.paint_path("f")
    Op_fstar => self.paint_path("f*")
    Op_S => self.paint_path("S")
    Op_s => self.paint_path("s")
    Op_B => self.paint_path("B")
    Op_Bstar => self.paint_path("B*")
    Op_b => self.paint_path("b")
    Op_bstar => self.paint_path("b*")
    Op_sh(name) => {
      let ty = match r.get(resources, "Shading") {
        Some(sh) =>
          match r.get(sh, name_str(name)) {
            Some(s) =>
              match r.get(s, "ShadingType") {
                Some(PdfInteger(t)) => t
                _ => 0
              }
            None => 0
          }
        None => 0
      }
      self.out.write_string("  shading \{ty}\n")
    }
    Op_Do(name) => self.draw_xobject(name_str(name), resources, depth)
    _ => ()
  }
}

///|
fn Interp::draw_xobject(
  self : Interp,
  name : String,
  resources : @pdfsyntax.PdfObject,
  depth : Int,
) -> Unit {
  let r = self.r
  guard r.get(resources, "XObject") is Some(xobjects) else { return }
  guard r.get(xobjects, name) is Some(stream) else { return }
  let subtype = match r.get(stream, "Subtype") {
    Some(PdfNameObject(n)) => name_str(n)
    _ => ""
  }
  if subtype == "Image" {
    let int = (key : String) => {
      match r.get(stream, key) {
        Some(PdfInteger(i)) => i
        _ => 0
      }
    }
    let filter = match r.get(stream, "Filter") {
      Some(PdfNameObject(n)) => name_str(n)
      Some(PdfArray(a)) =>
        match a.last() {
          Some(o) => obj_str(r.doc.direct(o)).unwrap_or("")
          None => ""
        }
      _ => ""
    }
    let cs = match r.get(stream, "ColorSpace") {
      Some(PdfNameObject(n)) => self.color_space(name_str(n), PdfDictionary([]))
      Some(PdfArray(a)) => {
        let a = a.map(x => r.doc.direct(x))
        let kind = a.get(0).bind(obj_str).unwrap_or("")
        if kind == "ICCBased" {
          let n = match a.get(1) {
            Some(s) =>
              match r.get(s, "N") {
                Some(PdfInteger(n)) => n
                _ => 0
              }
            None => 0
          }
          match n {
            1 => "gray"
            3 => "rgb"
            4 => "cmyk"
            _ => "icc"
          }
        } else {
          kind.to_lower()
        }
      }
      _ => "-"
    }
    let m = self.gs.ctm
    self.out.write_string(
      "  image \{int("Width")}x\{int("Height")} \{cs} bpc=\{int("BitsPerComponent")}",
    )
    if filter == "DCTDecode" {
      self.out.write_string(" jpeg")
    }
    if r.get_raw(stream, "SMask") is Some(_) {
      self.out.write_string(" smask")
    }
    if r.get(stream, "Interpolate") is Some(PdfBoolean(true)) {
      self.out.write_string(" interpolate")
    }
    self.out.write_string(
      " [\{num2(m.a)} \{num2(m.b)} \{num2(m.c)} \{num2(m.d)} \{num2(m.e)} \{num2(m.f)}]\n",
    )
  } else if subtype == "Form" {
    let matrix = match r.get(stream, "Matrix") {
      Some(a) => {
        let v = r.array(a).filter_map(obj_f64)
        if v.length() == 6 {
          { a: v[0], b: v[1], c: v[2], d: v[3], e: v[4], f: v[5], }
        } else {
          identity_matrix
        }
      }
      None => identity_matrix
    }
    let res = r.get(stream, "Resources").unwrap_or(PdfDictionary([]))
    if r.stream_data(stream) is Some(data) {
      self.stack.push(self.gs.copy())
      let outer = self.block
      self.block = None
      let font = self.font
      self.run(data, res, matrix, depth + 1)
      self.flush()
      self.block = outer
      self.font = font
      self.gs = self.stack.pop().unwrap()
    }
  }
}

///|
/// Parse the `bfchar`/`bfrange` sections of a ToUnicode CMap.
fn parse_to_unicode(data : Bytes, map : Map[Int, String]) -> Unit {
  let tokens = tokenize_cmap(latin1(data))
  let hex = (s : String) => {
    if !s.has_prefix("<") || !s.has_suffix(">") {
      return None
    }
    let inner = StringBuilder()
    for c in s.unsafe_substring(start=1, end=s.length() - 1) {
      if c != ' ' && c != '\n' && c != '\r' && c != '\t' {
        inner.write_char(c)
      }
    }
    let inner = inner.to_string()
    let out = []
    let mut k = 0
    while k + 1 < inner.length() {
      let v = @string.parse_int(
        inner.unsafe_substring(start=k, end=k + 2),
        base=16,
      ) catch {
        _ => return None
      }
      out.push(v)
      k += 2
    }
    Some(out)
  }
  let code = (b : Array[Int]) => b.fold(init=0, (acc, x) => (acc << 8) | x)
  let utf16 = (b : Array[Int]) => {
    let units = []
    let mut k = 0
    while k + 1 < b.length() {
      units.push((b[k] << 8) | b[k + 1])
      k += 2
    }
    let sb = StringBuilder()
    decode_utf16_lossy(units, sb)
    sb.to_string()
  }
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      "beginbfchar" => {
        i += 1
        while i + 1 < tokens.length() && tokens[i] != "endbfchar" {
          if hex(tokens[i]) is Some(src) && hex(tokens[i + 1]) is Some(dst) {
            map[code(src)] = utf16(dst)
          }
          i += 2
        }
      }
      "beginbfrange" => {
        i += 1
        while i + 2 < tokens.length() && tokens[i] != "endbfrange" {
          let lo = hex(tokens[i]).map(code)
          let hi = hex(tokens[i + 1]).map(code)
          if tokens[i + 2] == "[" {
            let mut j = i + 3
            let mut k = 0
            while j < tokens.length() && tokens[j] != "]" {
              if lo is Some(lo) && hex(tokens[j]) is Some(dst) {
                map[lo + k] = utf16(dst)
              }
              k += 1
              j += 1
            }
            i = j + 1
          } else {
            if lo is Some(lo) &&
              hi is Some(hi) &&
              hex(tokens[i + 2]) is Some(dst) {
              let end = @cmp.minimum(hi, lo + 0xFFFF)
              for c in lo..<=end {
                let d = dst.copy()
                if d.length() > 0 {
                  let last = d.length() - 1
                  d[last] = (d[last] + (c - lo)) & 0xFF
                }
                map[c] = utf16(d)
              }
            }
            i += 3
          }
        }
      }
      _ => ()
    }
    i += 1
  }
}

///|
fn tokenize_cmap(text : String) -> Array[String] {
  let tokens = []
  let chars = text.to_array()
  let mut i = 0
  let is_ws = (c : Char) => {
    c == ' ' ||
    c == '\n' ||
    c == '\r' ||
    c == '\t' ||
    c == '\u{0c}' ||
    c == '\u{0b}'
  }
  while i < chars.length() {
    let c = chars[i]
    if is_ws(c) {
      i += 1
    } else if c == '%' {
      while i < chars.length() && chars[i] != '\n' && chars[i] != '\r' {
        i += 1
      }
    } else if c == '<' {
      let start = i
      while i < chars.length() && chars[i] != '>' {
        i += 1
      }
      i += 1
      tokens.push(
        String::from_array(chars[start:@cmp.minimum(i, chars.length())]),
      )
    } else if c == '[' || c == ']' {
      tokens.push(c.to_string())
      i += 1
    } else if c == '(' {
      let mut depth = 0
      let start = i
      while i < chars.length() {
        if chars[i] == '\\' {
          i += 2
          continue
        }
        if chars[i] == '(' {
          depth += 1
        }
        if chars[i] == ')' {
          depth -= 1
          if depth == 0 {
            i += 1
            break
          }
        }
        i += 1
      }
      tokens.push(
        String::from_array(chars[start:@cmp.minimum(i, chars.length())]),
      )
    } else {
      let start = i
      while i < chars.length() &&
            !is_ws(chars[i]) &&
            !(chars[i] is ('<' | '>' | '[' | ']' | '(' | ')' | '/' | '%')) {
        i += 1
      }
      if i == start {
        i += 1
      }
      tokens.push(String::from_array(chars[start:i]))
    }
  }
  tokens
}
