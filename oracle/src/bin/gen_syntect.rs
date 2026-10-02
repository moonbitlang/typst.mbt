//! Generates the data of the syntect port (`syntect/`):
//!
//! - `data <root>`: `syntect/two_face/syntaxes_gen.mbt`, the built-in syntax
//!   set of Typst's raw blocks (`two_face::syntax::extra_no_newlines()`,
//!   i.e. typst-library's `RAW_SYNTAXES`), decoded from two-face's packed
//!   dump and re-serialized in a compact text format that
//!   `syntect/two_face` decodes lazily per syntax (like syntect's own
//!   `LazyContexts`).
//!
//! The format is a sequence of tokens:
//! - integer: decimal digits followed by `,`
//! - string: `<n>:` followed by `n` UTF-16 code units
//! - option: `-` for `None`, otherwise the value
//!
//! Header (`SYNTAX_HEADER`):
//!   scope table: count, then strings
//!   syntaxes: count, then per syntax:
//!     name, extension count + strings, scope (string), first_line_match
//!     (option string), hidden (int), `__start` context index (int),
//!     context count (int)
//!
//! Per syntax contexts (`SYNTAX_CONTEXTS[i]`): per context:
//!   meta_scope (count + scope indices), meta_content_scope (same),
//!   meta_include_prototype (int), clear_scopes (`-` | `A` | `T` int),
//!   prototype (`-` | syntax int, context int), uses_backrefs (int),
//!   pattern count, then patterns:
//!     `C` reference                                  (include)
//!     `M` has_captures(int) regex(string) scopes(count + indices)
//!         captures(`-` | count + (index int, count + scope indices))
//!         operation(`P` refs | `T` refs | `O` | `X`) with_prototype(`-` | ref)
//!   where refs = count + references, and a reference is
//!     `D` syntax(int) context(int) | `N` name | `I` name
//!     | `S` scope(string) sub_context(option string) with_escape(int)
//!     | `F` name sub_context(option string) with_escape(int)
//!
//! Usage (from `oracle/`): `cargo run --release --bin gen_syntect -- data ..`

use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::PathBuf;

use serde::Deserialize;
use serde_json::Value;
use syntect::parsing::syntax_definition::{Context, ContextId};

/// Mirror of syntect's private `LazyContexts`.
#[derive(Deserialize)]
struct LazyContexts {
    context_ids: HashMap<String, ContextId>,
    contexts: Vec<Context>,
}

struct Enc {
    out: String,
}

impl Enc {
    fn int(&mut self, n: u64) {
        write!(self.out, "{n},").unwrap();
    }
    fn str(&mut self, s: &str) {
        write!(self.out, "{}:", s.encode_utf16().count()).unwrap();
        self.out.push_str(s);
    }
    fn opt_str(&mut self, s: Option<&str>) {
        match s {
            None => self.out.push('-'),
            Some(s) => self.str(s),
        }
    }
    fn tag(&mut self, c: char) {
        self.out.push(c);
    }
}

struct Scopes {
    table: Vec<String>,
    index: HashMap<String, usize>,
}

impl Scopes {
    fn get(&mut self, s: &str) -> u64 {
        if let Some(&i) = self.index.get(s) {
            return i as u64;
        }
        self.table.push(s.to_string());
        self.index.insert(s.to_string(), self.table.len() - 1);
        (self.table.len() - 1) as u64
    }
}

fn scope_list(e: &mut Enc, scopes: &mut Scopes, v: &Value) {
    let arr = v.as_array().unwrap();
    e.int(arr.len() as u64);
    for s in arr {
        let i = scopes.get(s.as_str().unwrap());
        e.int(i);
    }
}

fn context_id(e: &mut Enc, v: &Value) {
    e.int(v["syntax_index"].as_u64().unwrap());
    e.int(v["context_index"].as_u64().unwrap());
}

fn reference(e: &mut Enc, v: &Value) {
    let obj = v.as_object().unwrap();
    assert_eq!(obj.len(), 1);
    let (k, v) = obj.iter().next().unwrap();
    match k.as_str() {
        "Direct" => {
            e.tag('D');
            context_id(e, v);
        }
        "Named" => {
            e.tag('N');
            e.str(v.as_str().unwrap());
        }
        "Inline" => {
            e.tag('I');
            e.str(v.as_str().unwrap());
        }
        "ByScope" => {
            e.tag('S');
            e.str(v["scope"].as_str().unwrap());
            e.opt_str(v["sub_context"].as_str());
            e.int(v["with_escape"].as_bool().unwrap() as u64);
        }
        "File" => {
            e.tag('F');
            e.str(v["name"].as_str().unwrap());
            e.opt_str(v["sub_context"].as_str());
            e.int(v["with_escape"].as_bool().unwrap() as u64);
        }
        other => panic!("unknown reference {other}"),
    }
}

fn refs(e: &mut Enc, v: &Value) {
    let arr = v.as_array().unwrap();
    e.int(arr.len() as u64);
    for r in arr {
        reference(e, r);
    }
}

fn context(e: &mut Enc, scopes: &mut Scopes, ctx: &Context) {
    let v = serde_json::to_value(ctx).unwrap();
    scope_list(e, scopes, &v["meta_scope"]);
    scope_list(e, scopes, &v["meta_content_scope"]);
    e.int(v["meta_include_prototype"].as_bool().unwrap() as u64);
    match &v["clear_scopes"] {
        Value::Null => e.tag('-'),
        Value::String(s) if s == "All" => e.tag('A'),
        Value::Object(o) => {
            e.tag('T');
            e.int(o["TopN"].as_u64().unwrap());
        }
        other => panic!("unknown clear amount {other}"),
    }
    match &v["prototype"] {
        Value::Null => e.tag('-'),
        id => context_id(e, id),
    }
    e.int(v["uses_backrefs"].as_bool().unwrap() as u64);
    let patterns = v["patterns"].as_array().unwrap();
    e.int(patterns.len() as u64);
    for p in patterns {
        if let Some(r) = p.get("Include") {
            e.tag('C');
            reference(e, r);
            continue;
        }
        let m = &p["Match"];
        e.tag('M');
        e.int(m["has_captures"].as_bool().unwrap() as u64);
        e.str(m["regex"].as_str().unwrap());
        scope_list(e, scopes, &m["scope"]);
        match &m["captures"] {
            Value::Null => e.tag('-'),
            Value::Array(caps) => {
                e.int(caps.len() as u64);
                for cap in caps {
                    e.int(cap[0].as_u64().unwrap());
                    scope_list(e, scopes, &cap[1]);
                }
            }
            other => panic!("unknown captures {other}"),
        }
        match &m["operation"] {
            Value::String(s) if s == "Pop" => e.tag('O'),
            Value::String(s) if s == "None" => e.tag('X'),
            Value::Object(o) if o.contains_key("Push") => {
                e.tag('P');
                refs(e, &o["Push"]);
            }
            Value::Object(o) if o.contains_key("Set") => {
                e.tag('T');
                refs(e, &o["Set"]);
            }
            other => panic!("unknown operation {other}"),
        }
        match &m["with_prototype"] {
            Value::Null => e.tag('-'),
            r => reference(e, r),
        }
    }
}

/// A MoonBit string literal.
fn lit(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 || c == '\u{7f}' => {
                write!(out, "\\u{{{:x}}}", c as u32).unwrap();
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn gen_data(root: &PathBuf) {
    let set = two_face::syntax::extra_no_newlines();
    let json = serde_json::to_value(&set).unwrap();
    let syntaxes = json["syntaxes"].as_array().unwrap();
    assert_eq!(syntaxes.len(), set.syntaxes().len());

    let mut scopes = Scopes { table: Vec::new(), index: HashMap::new() };
    let mut header = Enc { out: String::new() };
    let mut blobs = Vec::new();
    header.int(syntaxes.len() as u64);
    for (syntax, sv) in set.syntaxes().iter().zip(syntaxes) {
        let bytes: Vec<u8> = sv["serialized_lazy_contexts"]
            .as_array()
            .unwrap()
            .iter()
            .map(|b| b.as_u64().unwrap() as u8)
            .collect();
        let lazy: LazyContexts = syntect::dumps::from_reader(&bytes[..]).unwrap();
        // Contexts are stored in index order; check that the ids agree.
        for id in lazy.context_ids.values() {
            let v = serde_json::to_value(id).unwrap();
            assert!((v["context_index"].as_u64().unwrap() as usize) < lazy.contexts.len());
        }
        let start = serde_json::to_value(lazy.context_ids["__start"]).unwrap();

        header.str(&syntax.name);
        header.int(syntax.file_extensions.len() as u64);
        for ext in &syntax.file_extensions {
            header.str(ext);
        }
        header.str(&syntax.scope.build_string());
        header.opt_str(syntax.first_line_match.as_deref());
        header.int(syntax.hidden as u64);
        header.int(start["context_index"].as_u64().unwrap());
        header.int(lazy.contexts.len() as u64);

        let mut blob = Enc { out: String::new() };
        for ctx in &lazy.contexts {
            context(&mut blob, &mut scopes, ctx);
        }
        blobs.push(blob.out);
    }
    let mut table = Enc { out: String::new() };
    table.int(scopes.table.len() as u64);
    for s in &scopes.table {
        table.str(s);
    }

    let mut out = String::new();
    out.push_str(
        "// Generated by `oracle/src/bin/gen_syntect.rs` from two-face 0.4.5's\n\
         // `syntax::extra_no_newlines()` (fancy-regex flavour). Do not edit by hand!\n\n",
    );
    writeln!(out, "///|\nlet syntax_header : String = {}\n", lit(&(table.out + &header.out)))
        .unwrap();
    out.push_str("///|\nlet syntax_contexts : FixedArray[String] = [\n");
    for b in &blobs {
        writeln!(out, "  {},", lit(b)).unwrap();
    }
    out.push_str("]\n");
    let total: usize = blobs.iter().map(|b| b.len()).sum();
    eprintln!(
        "{} syntaxes, {} scopes, {} bytes of contexts, {} bytes total",
        blobs.len(),
        scopes.table.len(),
        total,
        out.len()
    );
    std::fs::write(root.join("syntect/two_face/syntaxes_gen.mbt"), out).unwrap();
}

fn main() {
    let mut args = std::env::args().skip(1);
    let mode = args.next().expect("mode");
    let root = PathBuf::from(args.next().unwrap_or_else(|| "..".into()));
    match mode.as_str() {
        "data" => gen_data(&root),
        other => panic!("unknown mode {other}"),
    }
}
