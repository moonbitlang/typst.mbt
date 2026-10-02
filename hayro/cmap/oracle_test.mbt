// Differential tests against the real `hayro-cmap` crate.
//
// `testdata/cmap_summary.txt` was produced by a small Rust oracle program
// (built against hayro rev d8e24e2) that, for every ToUnicode/Encoding cmap
// stream in the hayro test PDFs and Typst's `images/diagrams.pdf`, dumps all
// lookups (`dump_cmap` below mirrors it line by line) and records the number
// of lines, an FNV-1a hash and the first line. The PDFs are read from the
// `target/hayro` and `target/devassets` symlinks of a development checkout;
// missing files are skipped.

///|
/// The module root, relative to the test's working directory.
fn module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../"] {
    if @fs.path_exists(prefix + "moon.mod") {
      return Some(prefix)
    }
  }
  None
}

///|
fn hex(v : UInt) -> String {
  if v == 0 {
    return "0"
  }
  let digits = "0123456789abcdef"
  let buf = []
  let mut x = v
  while x > 0 {
    buf.push(digits[(x & 15).reinterpret_as_int()].unsafe_to_char())
    x = x >> 4
  }
  buf.rev_in_place()
  String::from_array(buf)
}

///|
fn hex_bytes(b : Bytes) -> String {
  let sb = StringBuilder()
  for x in b {
    let s = hex(x.to_uint())
    if s.length() == 1 {
      sb.write_char('0')
    }
    sb.write_string(s)
  }
  sb.to_string()
}

///|
fn fnv(s : String) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for c in s {
    // All dumps are ASCII.
    h = h ^ c.to_int().to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
fn hex64(v : UInt64) -> String {
  let s = hex((v >> 32).to_uint()) |> pad8
  s + pad8(hex(v.to_uint()))
}

///|
fn pad8(s : String) -> String {
  let sb = StringBuilder()
  for _ in s.length()..<8 {
    sb.write_char('0')
  }
  sb.write_string(s)
  sb.to_string()
}

///|
struct Lcg {
  mut state : UInt64
}

///|
fn Lcg::next(self : Lcg) -> UInt {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  (self.state >> 32).to_uint()
}

///|
fn bf_repr(b : @cmap.BfString) -> String {
  match b {
    Char(c) => "C" + hex(c.to_int().reinterpret_as_uint())
    String(s) => {
      let parts = []
      for c in s {
        parts.push(hex(c.to_int().reinterpret_as_uint()))
      }
      "S" + parts.join(".")
    }
  }
}

///|
fn family_repr(f : @cmap.CidFamily) -> String {
  match f {
    AdobeJapan1 => "AdobeJapan1"
    AdobeGB1 => "AdobeGB1"
    AdobeCNS1 => "AdobeCNS1"
    AdobeKorea1 => "AdobeKorea1"
    AdobeIdentity => "AdobeIdentity"
    Custom(registry~, ordering~) =>
      "Custom(\{hex_bytes(registry)},\{hex_bytes(ordering)})"
  }
}

///|
/// Dump of all lookups of a cmap (one line each), like the oracle.
fn dump_cmap(data : BytesView) -> String {
  let out = StringBuilder()
  guard @cmap.CMap::parse(data, _ => None) is Some(cmap) else {
    return "none\n"
  }
  let m = cmap.metadata()
  let name = match m.name {
    Some(n) => hex_bytes(n)
    None => "-"
  }
  let wm = match m.writing_mode {
    Some(Horizontal) => "H"
    Some(Vertical) => "V"
    None => "-"
  }
  let cc = match m.character_collection {
    Some(cc) => "\{family_repr(cc.family)} \{cc.supplement}"
    None => "-"
  }
  out.write_string("meta \{name} \{wm} \{cc}\n")
  for bl in 1..<=2 {
    let max = if bl == 1 { 0xFFU } else { 0xFFFFU }
    let mut code = 0U
    while code <= max {
      if cmap.lookup_cid_code(code, bl) is Some(cid) {
        out.write_string("c\{bl} \{hex(code)} \{cid}\n")
      }
      code += 1
    }
  }
  let rng = { state: 42UL, }
  for bl in [0, 3, 4, 5] {
    for _ in 0..<500 {
      let r = rng.next()
      let code = if bl == 3 { r & 0xFFFFFFU } else { r }
      if cmap.lookup_cid_code(code, bl) is Some(cid) {
        out.write_string("c\{bl} \{hex(code)} \{cid}\n")
      }
    }
  }
  let mut code = 0U
  while code <= 0xFFFFU {
    if cmap.lookup_bf_string(code) is Some(b) {
      out.write_string("b \{hex(code)} \{bf_repr(b)}\n")
    }
    code += 1
  }
  for _ in 0..<500 {
    let code = rng.next()
    if cmap.lookup_bf_string(code) is Some(b) {
      out.write_string("b \{hex(code)} \{bf_repr(b)}\n")
    }
  }
  out.to_string()
}

///|
fn summary_line(label : String, i : Int, dump : String) -> String {
  let lines = dump.split("\n").collect()
  let n = lines.length() - 1
  let first = lines[0].to_owned()
  "\{label} #\{i} \{n} \{hex64(fnv(dump))} \{first}"
}

///|
fn cmap_streams(pdf : @hayro_syntax.Pdf) -> Array[BytesView] {
  let res = []
  for obj in pdf.objects() {
    let dict = match obj {
      Dict(d) => d
      Stream(s) => s.dict()
      _ => continue
    }
    if (dict.get("ToUnicode") : @hayro_syntax.Stream?) is Some(s) &&
      s.decoded() is Ok(d) {
      res.push(d)
    }
    if (dict.get("Encoding") : @hayro_syntax.Stream?) is Some(s) &&
      s.decoded() is Ok(d) {
      res.push(d)
    }
  }
  res
}

///|
test "cmaps of test pdfs match hayro-cmap" {
  guard module_root() is Some(root) else { return }
  let expected = @fs.read_file_to_string(
    root + "hayro/cmap/testdata/cmap_summary.txt",
  )
  // Group the expected lines by file, in order.
  let files : Array[String] = []
  let by_file : Map[String, Array[String]] = Map([])
  for line in expected.split("\n") {
    if line.length() == 0 {
      continue
    }
    let line = line.to_owned()
    let path = line.split(" ").next().unwrap().to_owned()
    if !by_file.contains(path) {
      files.push(path)
      by_file[path] = []
    }
    by_file[path].push(line)
  }
  let mut checked = 0
  let mismatches = []
  for path in files {
    let full = root + path
    if !@fs.path_exists(full) {
      continue
    }
    let data = @fs.read_file_to_bytes(full)
    guard @hayro_syntax.Pdf::new(data) is Ok(pdf) else {
      mismatches.push("\{path}: failed to load")
      continue
    }
    let actual = cmap_streams(pdf).mapi((i, d) => {
      summary_line(path, i, dump_cmap(d))
    })
    let exp = by_file[path]
    if actual != exp {
      mismatches.push(
        "\{path}:\n  expected \{exp.join(" | ")}\n  actual   \{actual.join(" | ")}",
      )
    }
    checked += 1
  }
  if mismatches.length() > 0 {
    fail(mismatches.join("\n"))
  }
  if @fs.path_exists(root + "target/hayro") {
    assert_eq(checked, files.length())
  }
}

///|
test "synthetic cmaps match hayro-cmap" {
  guard module_root() is Some(root) else { return }
  let expected = @fs.read_file_to_string(
    root + "hayro/cmap/testdata/synth_summary.txt",
  )
  let mismatches = []
  for line in expected.split("\n") {
    if line.length() == 0 {
      continue
    }
    let line = line.to_owned()
    let path = line.split(" ").next().unwrap().to_owned()
    let data = @fs.read_file_to_bytes(root + path)
    let actual = summary_line(path, 0, dump_cmap(data))
    if actual != line {
      mismatches.push("expected \{line}\nactual   \{actual}")
    }
  }
  if mismatches.length() > 0 {
    fail(mismatches.join("\n"))
  }
}
