// The `wasm-spec` stage: replays the WebAssembly spec test suite (extracted
// by `scripts/wasm_spec_extract.sh` into `tests/golden/wasm-spec/corpus`)
// with the wasmi port and compares every command's outcome with what the
// real wasmi 1.0.9 did (`tests/golden/wasm-spec/expected/<dir>/<name>.tsv`,
// made by `oracle/src/bin/gen_wasmi_spec.rs`; see `scripts/goldens.sh`):
// module load/instantiation outcomes with their exact error texts, results
// as raw bits and trap messages.

///|
priv struct SpecCtx {
  engine : @wasmi.Engine
  store : @wasmi.Store[Unit]
  linker : @wasmi.Linker[Unit]
  named : Map[String, @wasmi.Instance]
  defs : Map[String, @wasmi.Module]
  mut current : @wasmi.Instance?
}

///|
fn spec_engine() -> @wasmi.Engine {
  // Like typst-library: disable relaxed SIMD as it can introduce
  // non-determinism.
  @wasmi.Engine::new(@wasmi.Config::default().wasm_relaxed_simd(false))
}

///|
fn spec_func_type(
  params : Array[@wasmi_core.ValType],
  results : Array[@wasmi_core.ValType],
) -> @wasmi_core.FuncType {
  @wasmi_core.FuncType::new(params, results) catch {
    _ => abort("invalid func type")
  }
}

///|
fn SpecCtx::new() -> SpecCtx raise @wasmi.WasmiError {
  let engine = spec_engine()
  let store = @wasmi.Store::new(engine, ())
  let linker : @wasmi.Linker[Unit] = @wasmi.Linker::new(engine)
  linker.allow_shadowing(true) |> ignore
  let print_types : Array[(String, Array[@wasmi_core.ValType])] = [
    ("print", []),
    ("print_i32", [I32]),
    ("print_i64", [I64]),
    ("print_f32", [F32]),
    ("print_f64", [F64]),
    ("print_i32_f32", [I32, F32]),
    ("print_f64_f64", [F64, F64]),
  ]
  for entry in print_types {
    let (name, params) = entry
    let func = @wasmi.Func::new(store, spec_func_type(params, []), fn(_, _, _) {
      ()
    })
    linker.define_("spectest", name, Func(func)) |> ignore
  }
  let globals : Array[(String, @wasmi.Val)] = [
    ("global_i32", I32(666)),
    ("global_i64", I64(666)),
    ("global_f32", F32(0x4426A666)),
    ("global_f64", F64(0x4084D4CCCCCCCCCD)),
  ]
  for entry in globals {
    let (name, val) = entry
    let global = @wasmi.Global::new(store, val, Const)
    linker.define_("spectest", name, Global(global)) |> ignore
  }
  let table = @wasmi.Table::new(
    store,
    @wasmi_core.TableType::new(FuncRef, 10, Some(20)),
    FuncRef(None),
  )
  linker.define_("spectest", "table", Table(table)) |> ignore
  let memory_type = @wasmi_core.MemoryType::builder()
    .min(1)
    .max(Some(2))
    .build() catch {
      _ => abort("invalid memory type")
    }
  let memory = @wasmi.Memory::new(store, memory_type)
  linker.define_("spectest", "memory", Memory(memory)) |> ignore
  { engine, store, linker, named: {}, defs: {}, current: None, }
}

///|
fn SpecCtx::instance(self : SpecCtx, module_ : String) -> @wasmi.Instance? {
  if module_ == "-" {
    self.current
  } else {
    self.named.get(module_)
  }
}

///|
fn spec_escape(s : String) -> String {
  s
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\t", new="\\t")
}

///|
fn spec_hex(value : UInt64, digits : Int) -> String {
  let s = value.to_string(radix=16)
  "0".repeat(digits - s.length()) + s
}

///|
fn spec_parse_hex(s : String) -> UInt64 {
  let mut v = 0UL
  for c in s {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      c.to_int() - 'a'.to_int() + 10
    }
    v = (v << 4) | d.to_uint64()
  }
  v
}

///|
fn spec_unhex_name(s : String) -> String {
  let bytes = FixedArray::make(s.length() / 2, b'\x00')
  for i in 0..<(s.length() / 2) {
    bytes[i] = spec_parse_hex(s.unsafe_substring(start=2 * i, end=2 * i + 2)).to_byte()
  }
  @utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
/// Parses an argument `<type>:<value>` into a value, `None` if unsupported.
fn SpecCtx::arg(self : SpecCtx, arg : String) -> @wasmi.Val? {
  guard arg.find(":") is Some(i) else { return None }
  let ty = arg.unsafe_substring(start=0, end=i)
  let v = arg.unsafe_substring(start=i + 1, end=arg.length())
  match ty {
    "i32" => Some(I32(spec_parse_hex(v).to_int()))
    "i64" => Some(I64(spec_parse_hex(v).reinterpret_as_int64()))
    "f32" => Some(F32(spec_parse_hex(v).to_uint()))
    "f64" => Some(F64(spec_parse_hex(v)))
    "v128" => {
      let hi = spec_parse_hex(v.unsafe_substring(start=0, end=16))
      let lo = spec_parse_hex(v.unsafe_substring(start=16, end=32))
      Some(V128(@wasmi_core.V128Value::from_lo_hi(lo, hi)))
    }
    "funcref" => if v == "null" { Some(FuncRef(None)) } else { None }
    "externref" =>
      if v == "null" {
        Some(ExternRef(None))
      } else {
        let n = spec_parse_dec(v)
        Some(ExternRef(Some(@wasmi.ExternRef::new(self.store, U32(n)))))
      }
    _ => None
  }
}

///|
fn SpecCtx::fmt_val(self : SpecCtx, v : @wasmi.Val) -> String {
  match v {
    I32(x) => "i32:" + spec_hex(x.reinterpret_as_uint().to_uint64(), 8)
    I64(x) => "i64:" + spec_hex(x.reinterpret_as_uint64(), 16)
    F32(x) => "f32:" + spec_hex(x.to_uint64(), 8)
    F64(x) => "f64:" + spec_hex(x, 16)
    V128(x) => "v128:" + spec_hex(x.hi(), 16) + spec_hex(x.lo(), 16)
    FuncRef(None) => "funcref:null"
    FuncRef(Some(_)) => "funcref:nonnull"
    ExternRef(None) => "externref:null"
    ExternRef(Some(e)) =>
      match e.data(self.store) {
        U32(n) => "externref:\{n}"
        _ => "externref:?"
      }
  }
}

///|
fn SpecCtx::invoke(
  self : SpecCtx,
  module_ : String,
  field : String,
  args : String,
) -> String {
  guard self.instance(module_) is Some(instance) else {
    return "err:no instance"
  }
  guard instance.get_func(self.store, field) is Some(func) else {
    return "err:no export"
  }
  let vals = []
  if args != "" {
    for a in args.split(",") {
      match self.arg(a.to_owned()) {
        Some(v) => vals.push(v)
        None => return "unsupported"
      }
    }
  }
  let ty = func.ty(self.store)
  let results = ty.results().iter().map(@wasmi.Val::default).collect()
  func.call(self.store, vals, results) catch {
    e => return "err:" + spec_escape(e.to_string())
  }
  "ok:" + results.map(v => self.fmt_val(v)).join(",")
}

///|
fn SpecCtx::get(self : SpecCtx, module_ : String, field : String) -> String {
  guard self.instance(module_) is Some(instance) else {
    return "err:no instance"
  }
  match instance.get_global(self.store, field) {
    Some(g) => "ok:" + self.fmt_val(g.get(self.store))
    None => "err:no export"
  }
}

///|
fn SpecCtx::load(
  self : SpecCtx,
  path : String,
) -> Result[@wasmi.Module, String] {
  let bytes = @fs.read_file_to_bytes(path) catch {
    _ => return Err("load-err:missing file")
  }
  let module_ = @wasmi.Module::new(self.engine, bytes) catch {
    e => return Err("load-err:" + spec_escape(e.to_string()))
  }
  Ok(module_)
}

///|
fn SpecCtx::instantiate(
  self : SpecCtx,
  module_ : @wasmi.Module,
) -> Result[@wasmi.Instance, String] {
  let instance = self.linker.instantiate_and_start(self.store, module_) catch {
    e => return Err("inst-err:" + spec_escape(e.to_string()))
  }
  Ok(instance)
}

///|
/// Replays one expected-outcome file, returning (passed, failed, skipped).
/// `skip` lines (text-format modules, which wasmi does not parse) are
/// counted as skipped; unknown commands fail.
fn run_wasm_spec_file(
  json_dir : String,
  tsv : String,
  verbose : Bool,
  label : String,
) -> (Int, Int, Int) {
  let ctx = SpecCtx::new() catch {
    e => {
      println("\{label}: failed to set up spectest: \{e}")
      return (0, 1, 0)
    }
  }
  let mut passed = 0
  let mut failed = 0
  let mut skipped = 0
  for line in tsv.split("\n") {
    let line = line.to_owned()
    if line == "" {
      continue
    }
    let parts = line.split("\t").map(p => p.to_owned()).collect()
    let kind = parts[0]
    let actual = match kind {
      "module" | "define" => {
        let name = parts[2]
        let file = parts[3]
        let outcome = match ctx.load(json_dir + "/" + file) {
          Err(e) => e
          Ok(module_) =>
            if kind == "define" {
              if name != "-" {
                ctx.defs.set(name, module_)
              }
              "ok"
            } else {
              match ctx.instantiate(module_) {
                Err(e) => e
                Ok(instance) => {
                  ctx.current = Some(instance)
                  if name != "-" {
                    ctx.named.set(name, instance)
                  }
                  "ok"
                }
              }
            }
        }
        "\{kind}\t\{parts[1]}\t\{name}\t\{file}\t\{outcome}"
      }
      "instance" => {
        let instance_name = parts[2]
        let module_name = parts[3]
        let outcome = match ctx.defs.get(module_name) {
          None => "inst-err:no definition"
          Some(module_) =>
            match ctx.instantiate(module_) {
              Err(e) => e
              Ok(instance) => {
                ctx.current = Some(instance)
                if instance_name != "-" {
                  ctx.named.set(instance_name, instance)
                }
                "ok"
              }
            }
        }
        "instance\t\{parts[1]}\t\{instance_name}\t\{module_name}\t\{outcome}"
      }
      "assert" => {
        let file = parts[3]
        let outcome = match ctx.load(json_dir + "/" + file) {
          Err(e) => e
          Ok(module_) =>
            match ctx.instantiate(module_) {
              Err(e) => e
              Ok(_) => "ok"
            }
        }
        "assert\t\{parts[1]}\t\{parts[2]}\t\{file}\t\{outcome}"
      }
      "register" => {
        let as_name = parts[2]
        let name = parts[3]
        // Like the oracle, a missing instance (its module failed to
        // instantiate, which the module line compares) registers nothing;
        // a linker error fails the command (the oracle panics on one).
        match ctx.instance(name) {
          Some(instance) =>
            try
              ctx.linker.instance(ctx.store, as_name, instance) |> ignore
            catch {
              e => line + "\tregister failed: " + spec_escape(e.to_string())
            } noraise {
              _ => line
            }
          None => line
        }
      }
      "invoke" => {
        let field = spec_unhex_name(parts[3])
        let outcome = ctx.invoke(parts[2], field, parts[4])
        "invoke\t\{parts[1]}\t\{parts[2]}\t\{parts[3]}\t\{parts[4]}\t\{outcome}"
      }
      "get" => {
        let field = spec_unhex_name(parts[3])
        let outcome = ctx.get(parts[2], field)
        "get\t\{parts[1]}\t\{parts[2]}\t\{parts[3]}\t\{outcome}"
      }
      "skip" => {
        skipped += 1
        continue
      }
      _ => {
        failed += 1
        println("FAIL \{label}: unknown command: \{line}")
        continue
      }
    }
    if actual == line {
      passed += 1
    } else {
      failed += 1
      if verbose {
        println("FAIL \{label}")
        println("  - \{line}")
        println("  + \{actual}")
      }
    }
  }
  (passed, failed, skipped)
}

///|
fn run_wasm_spec_stage(filter : String?, verbose : Bool) -> Unit {
  let corpus = golden_dir + "/wasm-spec/corpus"
  let expected = golden_dir + "/wasm-spec/expected"
  let dirs = (@fs.read_dir(expected) catch { _ => [][:] }).to_owned()
  dirs.sort_by(spec_compare)
  let mut passed = 0
  let mut failed = 0
  let mut skipped = 0
  let mut files_ok = 0
  let mut files = 0
  for dir in dirs {
    let tsvs = (@fs.read_dir(expected + "/" + dir) catch { _ => [][:] }).to_owned()
    tsvs.sort_by(spec_compare)
    for tsv in tsvs {
      guard tsv.has_suffix(".tsv") else { continue }
      let stem = tsv.unsafe_substring(start=0, end=tsv.length() - 4)
      let label = dir + "/" + stem
      if filter is Some(f) && !label.contains(f) {
        continue
      }
      let text = read(expected + "/" + dir + "/" + tsv)
      let (p, f, s) = run_wasm_spec_file(
        corpus + "/" + dir + "/" + stem,
        text,
        verbose,
        label,
      )
      passed += p
      failed += f
      skipped += s
      files += 1
      if f == 0 {
        files_ok += 1
      } else if !verbose {
        println("FAIL \{label}: \{f} of \{p + f} commands")
      }
    }
  }
  println(
    "wasm-spec: \{passed} passed, \{failed} failed, \{skipped} skipped (text modules) (files: \{files_ok}/\{files})",
  )
}

///|
/// Compares strings by code points (Rust `str`/path order).
fn spec_compare(a : String, b : String) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let c = a.code_unit_at(i).compare(b.code_unit_at(i))
    if c != 0 {
      return c
    }
  }
  a.length().compare(b.length())
}

///|
fn spec_parse_dec(s : String) -> UInt {
  let mut v = 0U
  for c in s {
    v = v * 10 + (c.to_int() - '0'.to_int()).reinterpret_as_uint()
  }
  v
}
