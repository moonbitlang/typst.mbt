///|
/// Locates the module's `target/` directory (holding the upstream fixtures
/// via symlinks), if present.
fn target_dir() -> String? {
  for cand in ["target", "../target", "../../target", "../../../target"] {
    if @fs.path_exists(cand + "/hayro") || @fs.path_exists(cand + "/assets") {
      return Some(cand)
    }
  }
  None
}

///|
let pdf_cache : Map[String, Array[BytesView]] = {}

///|
fn pdf_font_streams(path : String) -> Array[BytesView] {
  if pdf_cache.get(path) is Some(v) {
    return v
  }
  let res = []
  let data = @fs.read_file_to_bytes(path) catch { _ => return res }
  guard @syntax.Pdf::new(data) is Ok(pdf) else { return res }
  for obj in pdf.objects() {
    guard obj.into_dict() is Some(dict) else { continue }
    for key in ["FontFile", "FontFile2", "FontFile3"] {
      if dict.get(key) is Some((s : @syntax.Stream)) {
        if s.decoded() is Ok(d) {
          res.push(d)
        }
      }
    }
  }
  pdf_cache[path] = res
  res
}

///|
/// Loads the font data for a case, or `None` if the fixture is unavailable.
fn load_case(
  root : String,
  path : String,
  stream_len : Int,
  stream_fnv : UInt64,
) -> BytesView? {
  guard target_dir() is Some(t) else { return None }
  let full = t + "/" + root + "/" + path
  if stream_len < 0 {
    return Some(@fs.read_file_to_bytes(full)[:]) catch { _ => None }
  }
  for s in pdf_font_streams(full) {
    if s.length() == stream_len && fnv(s) == stream_fnv {
      return Some(s)
    }
  }
  None
}

///|
/// Compares a dump with the expected hash; on mismatch reports the first
/// differing line if the full oracle output is available.
fn check_dump(
  name : String,
  out : String,
  out_len : Int,
  out_fnv : UInt64,
) -> String? {
  let h = fnv_str(out)
  if h == out_fnv {
    return None
  }
  let mut msg = "\{name}: mismatch (len \{out.length()} vs \{out_len})"
  if target_dir() is Some(t) {
    let p = t + "/scratch/expected/" + name + ".txt"
    let expected = @fs.read_file_to_string(p) catch { _ => "" }
    if expected != "" {
      let a : Array[StringView] = out.split("\n").to_array()
      let b : Array[StringView] = expected.split("\n").to_array()
      for
        i in 0..<(if a.length() < b.length() { b.length() } else { a.length() }) {
        let la = match a.get(i) {
          Some(v) => v.to_owned()
          None => "<eof>"
        }
        let lb = match b.get(i) {
          Some(v) => v.to_owned()
          None => "<eof>"
        }
        if la != lb {
          msg = msg +
            "\n  line \{i + 1}: got      \{la}\n  line \{i + 1}: expected \{lb}"
          break
        }
      }
    }
  }
  Some(msg)
}

///|
fn run_cases(kind : String, dump : (BytesView) -> String) -> Unit raise {
  let failures = []
  let mut ran = 0
  for case in cases {
    let (name, k, root, path, slen, sfnv, olen, ofnv) = case
    if k != kind {
      continue
    }
    guard load_case(root, path, slen, sfnv) is Some(data) else { continue }
    ran += 1
    if check_dump(name, dump(data), olen, ofnv) is Some(msg) {
      failures.push(msg)
    }
  }
  println("\{kind}: ran \{ran} cases, \{failures.length()} failed")
  if failures.length() > 0 {
    fail(
      "\{failures.length()}/\{ran} \{kind} cases failed:\n" +
      failures.join("\n"),
    )
  }
}
