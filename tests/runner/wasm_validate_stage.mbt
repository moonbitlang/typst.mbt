// The `wasm-validate` stage: validates WebAssembly binaries with the
// wasmparser port exactly like wasmi does when Typst loads a plugin, and
// compares the outcome with `tests/golden/wasm-spec/validate.tsv` (made by
// `oracle/src/bin/gen_wasmparser_tests.rs`, see `scripts/goldens.sh`).
//
// The corpus is `tests/golden/wasm-spec/corpus` (the official WebAssembly
// test suite, `scripts/wasm_spec_extract.sh`) plus the Typst test plugins of
// `typst-dev-assets` (as `plugins/<name>`), and deterministic mutations of
// the binaries that validate (keyed `<name>@cut:<len>` /
// `<name>@set:<pos>:<byte>`).

///|
let wasm_spec_corpus : String = "tests/golden/wasm-spec/corpus"

///|
/// The features of `wasmi::Config::default()` with relaxed SIMD disabled
/// (like typst-library's plugin loader).
fn wasmi_features() -> @wasmparser.WasmFeatures {
  @wasmparser.WasmFeatures::empty()
  .set(@wasmparser.MUTABLE_GLOBAL, true)
  .set(@wasmparser.MULTI_VALUE, true)
  .set(@wasmparser.MULTI_MEMORY, true)
  .set(@wasmparser.SATURATING_FLOAT_TO_INT, true)
  .set(@wasmparser.SIGN_EXTENSION, true)
  .set(@wasmparser.BULK_MEMORY, true)
  .set(@wasmparser.REFERENCE_TYPES, true)
  .set(@wasmparser.GC_TYPES, true)
  .set(@wasmparser.TAIL_CALL, true)
  .set(@wasmparser.EXTENDED_CONST, true)
  .set(@wasmparser.FLOATS, true)
  .set(@wasmparser.CUSTOM_PAGE_SIZES, false)
  .set(@wasmparser.MEMORY64, true)
  .set(@wasmparser.WIDE_ARITHMETIC, false)
  .set(@wasmparser.SIMD, true)
  .set(@wasmparser.RELAXED_SIMD, false)
}

///|
/// The driver of `gen_wasmparser_tests`: wasmi's `ModuleParser::
/// parse_buffered` (including how it re-parses the payload that ends a
/// parsing phase without consuming it) and `FuncTranslationDriver`.
priv struct WasmiDriver {
  parser : @wasmparser.Parser
  validator : @wasmparser.Validator
  mut buffer : BytesView
}

///|
fn WasmiDriver::next_payload(
  self : WasmiDriver,
) -> (Int, @wasmparser.Payload) raise @wasmparser.BinaryReaderError {
  match self.parser.parse(self.buffer, true) {
    Parsed(consumed~, payload~) => (consumed, payload)
    NeedMoreData(_) => abort("unreachable")
  }
}

///|
fn WasmiDriver::consume(self : WasmiDriver, consumed : Int) -> Unit {
  self.buffer = self.buffer[consumed:]
}

///|
/// `ModuleParser::process_invalid_payload`: `true` if wasmi would panic.
fn WasmiDriver::invalid_payload(
  self : WasmiDriver,
  payload : @wasmparser.Payload,
) -> Bool raise @wasmparser.BinaryReaderError {
  self.validator.payload(payload) |> ignore
  true
}

///|
/// Returns `true` if wasmi would panic.
fn WasmiDriver::run(
  self : WasmiDriver,
) -> Bool raise @wasmparser.BinaryReaderError {
  let v = self.validator
  // parse_buffered_header
  while true {
    let (consumed, payload) = self.next_payload()
    match payload {
      Version(num~, encoding~, range~) => v.version(num, encoding, range)
      TypeSection(s) => v.type_section(s)
      ImportSection(s) => v.import_section(s)
      FunctionSection(s) => v.function_section(s)
      TableSection(s) => v.table_section(s)
      MemorySection(s) => v.memory_section(s)
      GlobalSection(s) => v.global_section(s)
      ExportSection(s) => v.export_section(s)
      StartSection(func~, range~) => v.start_section(func, range)
      ElementSection(s) => v.element_section(s)
      DataCountSection(count~, range~) => v.data_count_section(count, range)
      CodeSectionStart(count~, range~, ..) => {
        v.code_section_start(count, range)
        self.consume(consumed)
        break
      }
      DataSection(_) => break
      End(_) => break
      CustomSection(_) => ()
      other => if self.invalid_payload(other) { return true }
    }
    self.consume(consumed)
  }
  // parse_buffered_code
  while true {
    let (consumed, payload) = self.next_payload()
    match payload {
      CodeSectionEntry(body) => {
        self.consume(consumed)
        self.code_entry(body)
      }
      _ => break
    }
  }
  // parse_buffered_data
  while true {
    let (consumed, payload) = self.next_payload()
    match payload {
      DataSection(s) => v.data_section(s)
      End(offset) => {
        v.end(offset) |> ignore
        break
      }
      CustomSection(_) => ()
      other => if self.invalid_payload(other) { return true }
    }
    self.consume(consumed)
  }
  false
}

///|
/// `ModuleParser::process_code_entry` + `FuncTranslationDriver`.
fn WasmiDriver::code_entry(
  self : WasmiDriver,
  body : @wasmparser.FunctionBody,
) -> Unit raise @wasmparser.BinaryReaderError {
  let bytes = body.as_bytes()
  let offset = body.get_binary_reader().original_position()
  let func = self.validator.code_section_entry(body)
  let validator = func.into_validator(
    @wasmparser.FuncValidatorAllocations::default(),
  )
  let reader = @wasmparser.BinaryReader::new_features(
    bytes,
    offset,
    wasmi_features(),
  )
  let body = @wasmparser.FunctionBody::new(reader)
  // translate_locals
  let locals = body.get_locals_reader()
  for _ in 0U..<locals.get_count() {
    let offset = locals.original_position()
    let (amount, ty) = locals.read()
    validator.define_locals(offset, amount, ty)
  }
  // translate_operators
  let reader = body.get_operators_reader()
  while !reader.eof() {
    let pos = reader.original_position()
    let op = reader.read()
    validator.op(pos, op)
  }
  reader.ensure_end()
  // finish
  validator.finish(reader.original_position())
}

///|
fn escape_tsv(s : String) -> String {
  s
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\t", new="\\t")
}

///|
/// The outcome of validating `bytes`, in the golden's format.
fn wasm_validate_line(name : String, bytes : Bytes) -> String {
  let features = wasmi_features()
  let parser = @wasmparser.Parser::new(0)
  parser.set_features(features)
  let driver : WasmiDriver = {
    parser,
    validator: @wasmparser.Validator::new_with_features(features),
    buffer: bytes[:],
  }
  let panicked = driver.run() catch {
    e => return "\{name}\terr\t\{escape_tsv(e.to_string())}"
  }
  if panicked {
    "\{name}\tpanic"
  } else {
    "\{name}\tok"
  }
}

///|
fn wasm_files(
  dir : String,
  rel : String,
  out : Array[(String, String)],
) -> Unit {
  let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
  for e in entries {
    let path = dir + "/" + e
    let r = if rel == "" { e } else { rel + "/" + e }
    let is_dir = @fs.is_dir(path) catch { _ => false }
    if is_dir {
      wasm_files(path, r, out)
    } else if e.has_suffix(".wasm") {
      out.push((r, path))
    }
  }
}

///|
fn parse_decimal(s : String) -> Int {
  let mut n = 0
  for c in s {
    n = n * 10 + (c.to_int() - '0'.to_int())
  }
  n
}

///|
/// Applies a mutation key (`cut:<len>` or `set:<pos>:<byte>`) to `bytes`.
fn apply_wasm_mutation(bytes : Bytes, m : String) -> Bytes {
  let parts = m.split(":").map(p => p.to_string()).collect()
  match parts[0] {
    "cut" => {
      let len = parse_decimal(parts[1])
      bytes[:len].to_owned()
    }
    "set" => {
      let pos = parse_decimal(parts[1])
      let byte = parse_decimal(parts[2])
      let a = bytes.to_fixedarray()
      a[pos] = byte.to_byte()
      Bytes::from_fixedarray(a)
    }
    _ => abort("unknown mutation \{m}")
  }
}

///|
/// `--wasm-corpus=<dir>` and `--wasm-golden=<file>` replace the corpus and
/// the golden (for ad-hoc corpora run through `gen_wasmparser_tests`).
fn run_wasm_validate_stage(filter : String?, verbose : Bool) -> Unit {
  let mut corpus_dir = wasm_spec_corpus
  let mut golden_path = golden_dir + "/wasm-spec/validate.tsv"
  for a in @env.args() {
    if a.has_prefix("--wasm-corpus=") {
      corpus_dir = a.unsafe_substring(start=14, end=a.length())
    }
    if a.has_prefix("--wasm-golden=") {
      golden_path = a.unsafe_substring(start=14, end=a.length())
    }
  }
  let golden = read(golden_path)
  let expected : Map[String, String] = {}
  let order = []
  for line in golden.split("\n") {
    let line = line.to_string()
    if line == "" {
      continue
    }
    let name = match line.find("\t") {
      Some(i) => line.unsafe_substring(start=0, end=i)
      None => line
    }
    expected.set(name, line)
    order.push(name)
  }
  let files : Map[String, String] = {}
  let corpus = []
  wasm_files(corpus_dir, "", corpus)
  for f in corpus {
    files.set(f.0, f.1)
  }
  let plugins = cargo_checkout_files("typst-dev-assets-") + "/plugins"
  let mut passed = 0
  let mut failed = 0
  // The last file read (mutations follow their file).
  let cache : Map[String, Bytes] = {}
  for name in order {
    if filter is Some(f) && !name.contains(f) {
      continue
    }
    let (file, mutation) = match name.find("@") {
      Some(i) =>
        (
          name.unsafe_substring(start=0, end=i),
          Some(name.unsafe_substring(start=i + 1, end=name.length())),
        )
      None => (name, None)
    }
    let path = if file.has_prefix("plugins/") {
      Some(plugins + "/" + file.unsafe_substring(start=8, end=file.length()))
    } else {
      files.get(file)
    }
    let data = match cache.get(file) {
      Some(d) => d
      None =>
        match path {
          Some(path) => {
            let d = read_bytes(path)
            cache.clear()
            cache.set(file, d)
            d
          }
          None => {
            failed += 1
            println("FAIL \{name} (missing file)")
            continue
          }
        }
    }
    let bytes = match mutation {
      Some(m) => apply_wasm_mutation(data, m)
      None => data
    }
    let actual = wasm_validate_line(name, bytes)
    let want = expected.get(name).unwrap()
    if actual == want {
      passed += 1
    } else {
      failed += 1
      println("FAIL \{name}")
      if verbose {
        println("  expected: \{want}")
        println("  actual:   \{actual}")
      }
    }
  }
  println("wasm-validate: \{passed} passed, \{failed} failed")
}
