//! Runs the WebAssembly spec test suite (as extracted by
//! `scripts/wasm_spec_extract.sh`) with the real wasmi 1.0.9, configured like
//! typst-library's plugin loader, and records what wasmi does for every
//! command: module load/instantiation outcomes (with the exact error texts),
//! invocation results (raw bits) and traps. The `wasm-spec` runner stage
//! replays the same commands with the MoonBit port and compares.
//!
//! Usage: gen_wasmi_spec <corpus dir> <output dir>
//!
//! Output: one `<dir>/<name>.tsv` per JSON file, one line per command:
//!
//! ```text
//! module   <line> <name|-> <file> <outcome>   outcome: ok | load-err:<msg> | inst-err:<msg>
//! assert   <line> <kind> <file> <outcome>     (assert_invalid/malformed/unlinkable/uninstantiable)
//! register <line> <as> <name|->
//! invoke   <line> <module|-> <field hex> <args> <outcome>   outcome: ok:<results> | err:<msg>
//! get      <line> <module|-> <field hex> <outcome>
//! skip     <line> <reason>
//! ```
//!
//! Values are `<type>:<bits in hex>` (`v128:` 32 hex digits, references
//! `funcref:null`, `funcref:nonnull`, `externref:null`, `externref:<n>`),
//! comma separated. Messages escape `\` as `\\`, newline as `\n` and tab as
//! `\t`.

use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use serde_json::Value as Json;
use wasmi::{
    Config, Engine, ExternRef, Func, Global, Instance, Linker, Memory, MemoryType,
    Module, Mutability, Ref, Store, Table, TableType, Val, ValType,
};

fn escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('\n', "\\n").replace('\t', "\\t")
}

fn hex(s: &str) -> String {
    let mut out = String::new();
    for b in s.as_bytes() {
        write!(out, "{b:02x}").unwrap();
    }
    out
}

fn engine() -> Engine {
    let mut config = Config::default();
    // Like typst-library: disable relaxed SIMD as it can introduce
    // non-determinism.
    config.wasm_relaxed_simd(false);
    Engine::new(&config)
}

struct Ctx {
    engine: Engine,
    store: Store<()>,
    linker: Linker<()>,
    named: HashMap<String, Instance>,
    defs: HashMap<String, Module>,
    current: Option<Instance>,
}

impl Ctx {
    fn new() -> Self {
        let engine = engine();
        let mut store = Store::new(&engine, ());
        let mut linker = Linker::new(&engine);
        linker.allow_shadowing(true);
        define_spectest(&mut store, &mut linker);
        Self { engine, store, linker, named: HashMap::new(), defs: HashMap::new(), current: None }
    }

    fn instance(&self, module: Option<&str>) -> Option<Instance> {
        match module {
            Some(name) => self.named.get(name).copied(),
            None => self.current,
        }
    }
}

fn define_spectest(store: &mut Store<()>, linker: &mut Linker<()>) {
    let funcs: Vec<(&str, Func)> = vec![
        ("print", Func::wrap(&mut *store, || {})),
        ("print_i32", Func::wrap(&mut *store, |_: i32| {})),
        ("print_i64", Func::wrap(&mut *store, |_: i64| {})),
        ("print_f32", Func::wrap(&mut *store, |_: f32| {})),
        ("print_f64", Func::wrap(&mut *store, |_: f64| {})),
        ("print_i32_f32", Func::wrap(&mut *store, |_: i32, _: f32| {})),
        ("print_f64_f64", Func::wrap(&mut *store, |_: f64, _: f64| {})),
    ];
    for (name, func) in funcs {
        linker.define("spectest", name, func).unwrap();
    }
    let globals = [
        ("global_i32", Val::I32(666)),
        ("global_i64", Val::I64(666)),
        ("global_f32", Val::F32(666.6f32.into())),
        ("global_f64", Val::F64(666.6f64.into())),
    ];
    for (name, val) in globals {
        let global = Global::new(&mut *store, val, Mutability::Const);
        linker.define("spectest", name, global).unwrap();
    }
    let table = Table::new(
        &mut *store,
        TableType::new(ValType::FuncRef, 10, Some(20)),
        Val::FuncRef(Ref::Null),
    )
    .unwrap();
    linker.define("spectest", "table", table).unwrap();
    let memory = Memory::new(&mut *store, MemoryType::new(1, Some(2))).unwrap();
    linker.define("spectest", "memory", memory).unwrap();
}

fn parse_u64(s: &str) -> u64 {
    s.parse::<u64>().unwrap_or_else(|_| s.parse::<i64>().unwrap() as u64)
}

/// Parses a JSON argument into a wasmi value, or `None` if unsupported.
fn arg_value(store: &mut Store<()>, v: &Json) -> Option<Val> {
    let ty = v["type"].as_str()?;
    let value = &v["value"];
    Some(match ty {
        "i32" => Val::I32(parse_u64(value.as_str()?) as u32 as i32),
        "i64" => Val::I64(parse_u64(value.as_str()?) as i64),
        "f32" => Val::F32(wasmi::F32::from_bits(parse_u64(value.as_str()?) as u32)),
        "f64" => Val::F64(wasmi::F64::from_bits(parse_u64(value.as_str()?))),
        "v128" => Val::V128(wasmi::V128::from(v128_bits(v)?)),
        "funcref" => match value.as_str()? {
            "null" => Val::FuncRef(Ref::Null),
            _ => return None,
        },
        "externref" => match value.as_str()? {
            "null" => Val::ExternRef(Ref::Null),
            n => Val::ExternRef(Ref::Val(ExternRef::new(&mut *store, n.parse::<u32>().ok()?))),
        },
        _ => return None,
    })
}

fn v128_bits(v: &Json) -> Option<u128> {
    let lane = v["lane_type"].as_str()?;
    let lanes = v["value"].as_array()?;
    let width = match lane {
        "i8" => 8,
        "i16" => 16,
        "i32" | "f32" => 32,
        "i64" | "f64" => 64,
        _ => return None,
    };
    let mut bits: u128 = 0;
    for (i, l) in lanes.iter().enumerate() {
        let x = parse_u64(l.as_str()?) as u128;
        let mask = if width == 128 { u128::MAX } else { (1u128 << width) - 1 };
        bits |= (x & mask) << (i * width);
    }
    Some(bits)
}

fn fmt_val(store: &Store<()>, v: &Val) -> String {
    match v {
        Val::I32(x) => format!("i32:{:08x}", *x as u32),
        Val::I64(x) => format!("i64:{:016x}", *x as u64),
        Val::F32(x) => format!("f32:{:08x}", x.to_bits()),
        Val::F64(x) => format!("f64:{:016x}", x.to_bits()),
        Val::V128(x) => format!("v128:{:032x}", x.as_u128()),
        Val::FuncRef(r) => {
            if r.is_null() {
                "funcref:null".into()
            } else {
                "funcref:nonnull".into()
            }
        }
        Val::ExternRef(r) => match r.val() {
            None => "externref:null".into(),
            Some(e) => match e.data(store).downcast_ref::<u32>() {
                Some(n) => format!("externref:{n}"),
                None => "externref:?".into(),
            },
        },
    }
}

fn fmt_args(args: &[Json]) -> String {
    args.iter()
        .map(|v| {
            let ty = v["type"].as_str().unwrap_or("?");
            match ty {
                "i32" => format!("i32:{:08x}", parse_u64(v["value"].as_str().unwrap()) as u32),
                "i64" => format!("i64:{:016x}", parse_u64(v["value"].as_str().unwrap())),
                "f32" => format!("f32:{:08x}", parse_u64(v["value"].as_str().unwrap()) as u32),
                "f64" => format!("f64:{:016x}", parse_u64(v["value"].as_str().unwrap())),
                "v128" => format!("v128:{:032x}", v128_bits(v).unwrap_or(0)),
                "funcref" | "externref" => format!("{ty}:{}", v["value"].as_str().unwrap_or("?")),
                other => format!("{other}:?"),
            }
        })
        .collect::<Vec<_>>()
        .join(",")
}

fn invoke(ctx: &mut Ctx, action: &Json) -> String {
    let module = action["module"].as_str();
    let field = action["field"].as_str().unwrap();
    let Some(instance) = ctx.instance(module) else {
        return "err:no instance".into();
    };
    match action["type"].as_str().unwrap() {
        "invoke" => {
            let Some(func) = instance.get_func(&ctx.store, field) else {
                return "err:no export".into();
            };
            let mut args = Vec::new();
            for a in action["args"].as_array().unwrap() {
                match arg_value(&mut ctx.store, a) {
                    Some(v) => args.push(v),
                    None => return "unsupported".into(),
                }
            }
            let ty = func.ty(&ctx.store);
            let mut results: Vec<Val> =
                ty.results().iter().map(|t| Val::default(*t)).collect();
            match func.call(&mut ctx.store, &args, &mut results) {
                Ok(()) => {
                    let rs: Vec<String> =
                        results.iter().map(|v| fmt_val(&ctx.store, v)).collect();
                    format!("ok:{}", rs.join(","))
                }
                Err(e) => format!("err:{}", escape(&e.to_string())),
            }
        }
        "get" => match instance.get_global(&ctx.store, field) {
            Some(g) => format!("ok:{}", fmt_val(&ctx.store, &g.get(&ctx.store))),
            None => "err:no export".into(),
        },
        other => format!("unsupported action {other}"),
    }
}

fn load(ctx: &mut Ctx, path: &Path) -> Result<Module, String> {
    let bytes = std::fs::read(path).unwrap();
    Module::new(&ctx.engine, &bytes[..]).map_err(|e| format!("load-err:{}", escape(&e.to_string())))
}

fn instantiate(ctx: &mut Ctx, module: &Module) -> Result<Instance, String> {
    ctx.linker
        .instantiate_and_start(&mut ctx.store, module)
        .map_err(|e| format!("inst-err:{}", escape(&e.to_string())))
}

fn run_file(json_path: &Path, wasm_dir: &Path) -> String {
    let data: Json = serde_json::from_str(&std::fs::read_to_string(json_path).unwrap()).unwrap();
    let mut ctx = Ctx::new();
    let mut out = String::new();
    for cmd in data["commands"].as_array().unwrap() {
        let ty = cmd["type"].as_str().unwrap();
        let line = cmd["line"].as_u64().unwrap_or(0);
        match ty {
            "module" | "module_definition" => {
                let name = cmd["name"].as_str();
                let file = cmd["filename"].as_str().unwrap();
                if cmd["module_type"].as_str() == Some("text") {
                    writeln!(out, "skip\t{line}\ttext module").unwrap();
                    continue;
                }
                let outcome = match load(&mut ctx, &wasm_dir.join(file)) {
                    Err(e) => e,
                    Ok(module) if ty == "module_definition" => {
                        if let Some(name) = name {
                            ctx.defs.insert(name.into(), module);
                        }
                        "ok".into()
                    }
                    Ok(module) => match instantiate(&mut ctx, &module) {
                        Err(e) => e,
                        Ok(instance) => {
                            ctx.current = Some(instance);
                            if let Some(name) = name {
                                ctx.named.insert(name.into(), instance);
                            }
                            "ok".into()
                        }
                    },
                };
                let kind = if ty == "module" { "module" } else { "define" };
                writeln!(out, "{kind}\t{line}\t{}\t{file}\t{outcome}", name.unwrap_or("-"))
                    .unwrap();
            }
            "module_instance" => {
                let instance_name = cmd["instance"].as_str();
                let module_name = cmd["module"].as_str().unwrap_or("");
                let outcome = match ctx.defs.get(module_name).cloned() {
                    None => "inst-err:no definition".into(),
                    Some(module) => match instantiate(&mut ctx, &module) {
                        Err(e) => e,
                        Ok(instance) => {
                            ctx.current = Some(instance);
                            if let Some(name) = instance_name {
                                ctx.named.insert(name.into(), instance);
                            }
                            "ok".into()
                        }
                    },
                };
                writeln!(
                    out,
                    "instance\t{line}\t{}\t{module_name}\t{outcome}",
                    instance_name.unwrap_or("-")
                )
                .unwrap();
            }
            "assert_invalid" | "assert_malformed" | "assert_unlinkable"
            | "assert_uninstantiable" => {
                let file = cmd["filename"].as_str().unwrap();
                if cmd["module_type"].as_str() == Some("text") {
                    writeln!(out, "skip\t{line}\ttext module").unwrap();
                    continue;
                }
                let outcome = match load(&mut ctx, &wasm_dir.join(file)) {
                    Err(e) => e,
                    Ok(module) => match instantiate(&mut ctx, &module) {
                        Err(e) => e,
                        Ok(_) => "ok".into(),
                    },
                };
                writeln!(out, "assert\t{line}\t{ty}\t{file}\t{outcome}").unwrap();
            }
            "register" => {
                let as_name = cmd["as"].as_str().unwrap();
                let name = cmd["name"].as_str();
                match ctx.instance(name) {
                    Some(instance) => {
                        ctx.linker.instance(&mut ctx.store, as_name, instance).unwrap();
                    }
                    None => {}
                }
                writeln!(out, "register\t{line}\t{as_name}\t{}", name.unwrap_or("-")).unwrap();
            }
            "action" | "assert_return" | "assert_trap" | "assert_exhaustion"
            | "assert_exception" => {
                let action = &cmd["action"];
                let outcome = invoke(&mut ctx, action);
                let module = action["module"].as_str().unwrap_or("-");
                let field = hex(action["field"].as_str().unwrap());
                if action["type"] == "get" {
                    writeln!(out, "get\t{line}\t{module}\t{field}\t{outcome}").unwrap();
                } else {
                    let args = fmt_args(action["args"].as_array().unwrap());
                    writeln!(out, "invoke\t{line}\t{module}\t{field}\t{args}\t{outcome}")
                        .unwrap();
                }
            }
            other => {
                writeln!(out, "skip\t{line}\tunsupported command {other}").unwrap();
            }
        }
    }
    out
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let corpus = PathBuf::from(&args[1]);
    let out_dir = PathBuf::from(&args[2]);
    let mut files: Vec<PathBuf> = Vec::new();
    for dir in std::fs::read_dir(&corpus).unwrap() {
        let dir = dir.unwrap().path();
        if !dir.is_dir() {
            continue;
        }
        for f in std::fs::read_dir(&dir).unwrap() {
            let f = f.unwrap().path();
            if f.extension().is_some_and(|e| e == "json") {
                files.push(f);
            }
        }
    }
    files.sort();
    let mut count = 0;
    for json in files {
        let dir = json.parent().unwrap().file_name().unwrap().to_owned();
        let stem = json.file_stem().unwrap().to_owned();
        let wasm_dir = json.parent().unwrap().join(&stem);
        let result = std::panic::catch_unwind(|| run_file(&json, &wasm_dir));
        let text = match result {
            Ok(text) => text,
            Err(_) => {
                eprintln!("panic in {}", json.display());
                continue;
            }
        };
        let target = out_dir.join(&dir);
        std::fs::create_dir_all(&target).unwrap();
        std::fs::write(target.join(stem).with_extension("tsv"), text).unwrap();
        count += 1;
    }
    eprintln!("wrote {count} files");
}
