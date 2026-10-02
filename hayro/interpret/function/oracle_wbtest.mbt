// Differential tests against hayro-interpret's functions.
//
// `testdata/func_summary.txt` was produced by a small Rust oracle program
// (hayro rev d8e24e2) that evaluates every function object (`/FunctionType`)
// of the hayro test PDFs and Typst's `images/diagrams.pdf` on an input grid
// (`dump_function` below mirrors it), printing f32 values as their bits. One
// line per PDF holds the number of functions and an FNV-1a hash of the
// per-function summaries. The PDFs are read from the `target/hayro` and
// `target/devassets` symlinks of a development checkout; missing files are
// skipped.

///|
fn module_root() -> String? {
  for prefix in ["", "../", "../../", "../../../", "../../../../"] {
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
fn pad16(s : String) -> String {
  let sb = StringBuilder()
  for _ in s.length()..<16 {
    sb.write_char('0')
  }
  sb.write_string(s)
  sb.to_string()
}

///|
fn fnv(s : String) -> String {
  let mut h = 0xcbf29ce484222325UL
  for c in s {
    // All dumps are ASCII.
    h = h ^ c.to_int().to_uint64()
    h = h * 0x100000001b3UL
  }
  pad16(hex((h >> 32).to_uint()) + pad8(hex(h.to_uint())))
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
fn bits(v : Array[Float]) -> String {
  v.map(f => hex(f.reinterpret_as_uint())).join(",")
}

///|
fn grid(domain : Array[Float], n_in : Int) -> Array[Array[Float]] {
  let dom = fn(i : Int) -> (Float, Float) {
    (domain.get(2 * i).unwrap_or(0.0), domain.get(2 * i + 1).unwrap_or(1.0))
  }
  if n_in == 1 {
    let (a, b) = dom(0)
    let pts = [[a - (b - a) * 0.1]]
    for k in 0..<=16 {
      pts.push([a + (b - a) * Float::from_int(k) / 16.0])
    }
    pts.push([b + (b - a) * 0.1])
    pts.push([@float.not_a_number])
    return pts
  }
  let steps = match n_in {
    2 => 6
    3 => 4
    _ => 3
  }
  let n = if n_in < 4 { n_in } else { 4 }
  let mut pts : Array[Array[Float]] = [[]]
  for i in 0..<n {
    let (a, b) = dom(i)
    let next = []
    for p in pts {
      for k in 0..<steps {
        let q = p.copy()
        q.push(a + (b - a) * Float::from_int(k) / Float::from_int(steps - 1))
        next.push(q)
      }
    }
    pts = next
  }
  pts
}

///|
fn dump_function(
  obj : @hayro_syntax.Object,
  dict : @hayro_syntax.Dict,
) -> String {
  let out = StringBuilder()
  let ft = match (dict.get("FunctionType") : Int?) {
    Some(v) => "Some(\{v})"
    None => "None"
  }
  let domain = match (dict.get("Domain") : @hayro_syntax.Vector[Float]?) {
    Some(Vector(v)) => v
    None => []
  }
  let n_in = if domain.length() / 2 > 1 { domain.length() / 2 } else { 1 }
  out.write_string("func \{ft} \{n_in}\n")
  guard Function::new(obj) is Some(f) else {
    out.write_string("none\n")
    return out.to_string()
  }
  out.write_string("bounds \{bits(f.stitching_bounds())}\n")
  let pts = grid(domain, n_in)
  // Also a wrong number of arguments.
  pts.push(Array::make(n_in + 1, (0.5 : Float)))
  for p in pts {
    match f.eval(p) {
      Some(r) => out.write_string("\{bits(p)} -> \{bits(r)}\n")
      None => out.write_string("\{bits(p)} -> none\n")
    }
  }
  out.to_string()
}

///|
fn summary_line(label : String, i : Int, dump : String) -> String {
  let lines = dump.split("\n").collect()
  let n = lines.length() - 1
  let first = lines[0].to_owned()
  "\{label} #\{i} \{n} \{fnv(dump)} \{first}"
}

///|
fn function_summaries(path : String, pdf : @hayro_syntax.Pdf) -> Array[String] {
  let res = []
  for obj in pdf.objects() {
    let dict = match obj {
      Dict(d) => d
      Stream(s) => s.dict()
      _ => continue
    }
    if dict.contains_key("FunctionType") {
      res.push(summary_line(path, res.length(), dump_function(obj, dict)))
    }
  }
  res
}

///|
test "functions of test pdfs match hayro-interpret" {
  guard module_root() is Some(root) else { return }
  let expected = @fs.read_file_to_string(
    root + "hayro/interpret/function/testdata/func_summary.txt",
  )
  let mut checked = 0
  let mut total = 0
  let mismatches = []
  for line in expected.split("\n") {
    if line.length() == 0 {
      continue
    }
    total += 1
    let parts = line.split(" ").map(s => s.to_owned()).collect()
    let path = parts[0]
    let full = root + path
    if !@fs.path_exists(full) {
      continue
    }
    let data = @fs.read_file_to_bytes(full)
    guard @hayro_syntax.Pdf::new(data) is Ok(pdf) else {
      mismatches.push("\{path}: failed to load")
      continue
    }
    let items = function_summaries(path, pdf)
    let joined = StringBuilder()
    for item in items {
      joined.write_string(item + "\n")
    }
    let actual = "\{path} \{items.length()} \{fnv(joined.to_string())}"
    if actual != line.to_owned() {
      mismatches.push(
        "expected \{line}\nactual   \{actual}\n" + items.join("\n"),
      )
    }
    checked += 1
  }
  if mismatches.length() > 0 {
    fail(mismatches.join("\n"))
  }
  if @fs.path_exists(root + "target/hayro") {
    assert_eq(checked, total)
  }
}

///|
/// Evaluate a PostScript calculator program with unbounded domain (like the
/// oracle's `ps` command).
fn eval_program(prog : String, input : Array[Float]) -> Array[Float]? {
  let arr = []
  for c in prog {
    arr.push(c.to_int().to_byte())
  }
  guard parse_procedure(Bytes::from_array(arr)) is Some(procedure) else {
    return None
  }
  let type4 : Type4 = {
    program: procedure,
    clamper: {
      domain: input.map(_ => (@float.neg_infinity, @float.infinity)),
      range: None,
    },
  }
  type4.eval(input.copy())
}

///|
test "postscript programs match hayro-interpret" {
  guard module_root() is Some(root) else { return }
  let expected = @fs.read_file_to_string(
    root + "hayro/interpret/function/testdata/ps_programs.txt",
  )
  let mismatches = []
  for line in expected.split("\n") {
    if line.length() == 0 {
      continue
    }
    let line = line.to_owned()
    // `<program>|<inputs> -> <result>`
    guard line.find(" -> ") is Some(arrow) else { continue }
    let spec = line.view(end_offset=arrow).to_owned()
    let parts = spec.split("|").map(s => s.to_owned()).collect()
    let inputs = parts[1]
      .split(" ")
      .filter(s => s.length() > 0)
      .map(s => Float::from_double(@string.parse_double(s) catch { _ => 0.0 }))
      .collect()
    let actual = match eval_program(parts[0], inputs) {
      Some(r) => "\{spec} -> \{bits(r)}"
      None => "\{spec} -> none"
    }
    if actual != line {
      mismatches.push("expected \{line}\nactual   \{actual}")
    }
  }
  if mismatches.length() > 0 {
    fail(mismatches.join("\n"))
  }
}
