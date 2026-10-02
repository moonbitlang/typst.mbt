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

/// Code samples for the highlighting tests: (language token, code).
fn samples() -> Vec<(String, String)> {
    let mut out: Vec<(String, String)> = vec![
        ("rust".into(), "/// A state machine.\n#[derive(Debug)]\nenum State<'a> { A(u8), B(&'a str) }\n\nfn advance(state: State<'_>) -> State<'_> {\n    unimplemented!(\"state machine\")\n}\nlet r = r#\"raw \"string\"\"#; // comment\nimpl<T: Clone + 'static> Foo for Bar<T> where T: Debug { const X: u32 = 0x1F_u32; }".into()),
        ("py".into(), "import this\n\ndef hi():\n    print(\"Hi!\")\n\n@decorator\nclass Foo(Bar, metaclass=Meta):\n    \"\"\"Doc\n    string\"\"\"\n    x: int = 1_000 + 0b1010 # comment\n    f = lambda a, *b, **c: f\"{a!r:>10} {b}\"".into()),
        ("cpp".into(), "#include <iostream>\n\nint main() {\n  std::cout << \"Hello, world!\";\n}\ntemplate <typename T> class Vec : public Base<T> { T* data; /* block\n comment */ };\n#define MAX(a, b) ((a) > (b) ? (a) : (b))".into()),
        ("c".into(), "#include <stdio.h>\nstatic const char *s = \"a\\tb\\n\";\nint main(int argc, char **argv) {\n  for (int i = 0; i < 10; i++) printf(\"%d\\n\", i);\n  return 0;\n}".into()),
        ("html".into(), "<!DOCTYPE html>\n<html>\n  <head>\n    <meta charset=\"utf-8\">\n    <style>body { color: red; }</style>\n    <script>let x = 1 + 2; console.log(`x=${x}`);</script>\n  </head>\n  <body>\n    <h1>Topic</h1>\n    <p>The Hypertext Markup Language &amp; more.</p>\n  </body>\n</html>".into()),
        ("js".into(), "const a = [1, 2, 3].map((x) => x * 2);\nfunction* gen() { yield* other(); }\nclass A extends B { #priv = 1; static get x() { return /ab+c/gi.test('abc'); } }\nexport default async function () { await fetch(`/api/${id}`); }".into()),
        ("ts".into(), "interface Foo<T> { bar?: T; readonly baz: string[] }\ntype U = A | B & C;\nenum Color { Red = 1, Green }\nfunction f(this: Window, ...args: any[]): void {}".into()),
        ("json".into(), "{\n  \"key\": [1, 2.5e-3, true, null],\n  \"nested\": {\"a\": \"b\\\"c\"}\n}".into()),
        ("yaml".into(), "%YAML 1.2\n---\nname: lang\nfile_extensions:\n  - a\nscope: source # comment\ncontexts:\n  main:\n    - match: '\\b(if|else)\\b'\n      scope: keyword.control\nanchors: &a\n  b: *a\nmulti: |\n  text".into()),
        ("toml".into(), "[package]\nname = \"typst\"\nversion = \"0.1.0\" # comment\n[[bin]]\ndate = 1979-05-27T07:32:00Z\narr = [ 1, 2, 3 ]\ninline = { x = 1, y = 'lit' }".into()),
        ("sh".into(), "#!/bin/bash\nfor f in *.txt; do\n  echo \"$f ${f%.txt}\" | grep -E '^a' > /dev/null 2>&1\ndone\nif [[ -n $VAR ]]; then exit 1; fi\nfunction f() { local x=$(( 1 + 2 )); }".into()),
        ("go".into(), "package main\n\nimport \"fmt\"\n\nfunc main() {\n\tch := make(chan int, 10)\n\tgo func() { ch <- 42 }()\n\tfmt.Println(<-ch, `raw`)\n}".into()),
        ("java".into(), "package a.b;\nimport java.util.*;\n@Override\npublic class Main<T extends Comparable<T>> implements Runnable {\n  private static final int X = 0xFF;\n  public void run() { System.out.println(\"hi\" + 'c'); }\n}".into()),
        ("cs".into(), "using System;\nnamespace N {\n  public record R(int X);\n  class C { public string P { get; set; } = $\"x{1}\"; }\n}".into()),
        ("rb".into(), "module Bob::Wow::Troll::Five; 5; end\ndef foo(a, *b, &blk) = a + 1\nputs \"#{x} and #{y}\" if x =~ /ab+/\n%w[a b c].each { |x| p x }".into()),
        ("php".into(), "<?php\nnamespace App;\nclass A { public function f(int $x): ?string { return \"$x {$this->y}\"; } }\necho <<<EOT\nheredoc $x\nEOT;\n?>".into()),
        ("css".into(), "@media (max-width: 600px) {\n  .a > #b:hover::before { color: #fff; margin: 0 auto !important; }\n}\n:root { --x: calc(1px + 2em); }".into()),
        ("md".into(), "# Heading\n\nSome *emph* and **strong** and `code`.\n\n- item\n- [link](http://example.com)\n\n```rust\nfn main() {}\n```\n> quote".into()),
        ("diff".into(), "--- a/file\n+++ b/file\n@@ -1,3 +1,3 @@\n context\n-removed\n+added".into()),
        ("sql".into(), "SELECT a, COUNT(*) AS n FROM t WHERE x = 'y' AND z > 1.5 GROUP BY a; -- comment\nCREATE TABLE t (id INT PRIMARY KEY);".into()),
        ("hs".into(), "module Main where\nimport Data.List (sort)\nmain :: IO ()\nmain = do\n  let xs = [x * 2 | x <- [1..10], odd x]\n  print $ sort xs -- comment\n{- block -}".into()),
        ("tex".into(), "\\documentclass{article}\n\\begin{document}\n$x^2 + \\alpha$ % comment\n\\section{Intro}\\label{sec}\n\\end{document}".into()),
        ("lua".into(), "local function f(a, ...)\n  return a .. 'x', #t, [[long\nstring]]\nend\n-- comment\n--[[ block ]]".into()),
        ("swift".into(), "import UIKit\nstruct S: Codable { var x: Int? = nil; func f() throws -> String { \"\\(x)\" } }".into()),
        ("kt".into(), "fun main() { val x = listOf(1, 2).map { it * 2 }; println(\"$x ${x.size}\") }\ndata class P(val a: Int)".into()),
        ("scala".into(), "object Main extends App { val x: List[Int] = List(1, 2); x.foreach(println) }\ncase class A(b: String)".into()),
        ("xml".into(), "<?xml version=\"1.0\"?>\n<!DOCTYPE note>\n<note a=\"1\"><![CDATA[x < y]]><!-- c --></note>".into()),
        ("dockerfile".into(), "FROM rust:1.80 AS build\nRUN cargo build --release \\\n  && strip target/release/x\nCOPY --from=build /x /x\nENTRYPOINT [\"/x\"]".into()),
        ("makefile".into(), "all: main.o\n\t$(CC) -o $@ $^ $(LDFLAGS)\n%.o: %.c\n\t@echo \"building $<\"".into()),
        ("zig".into(), "const std = @import(\"std\");\npub fn main() !void { var x: u32 = 0; x +%= 1; }".into()),
        ("nix".into(), "{ pkgs ? import <nixpkgs> {} }: pkgs.mkShell { buildInputs = [ pkgs.hello ]; shellHook = ''\n  echo hi\n''; }".into()),
        ("ps1".into(), "function Get-X { param([string]$Name) Write-Host \"Hi $Name\" -ForegroundColor Red } # c".into()),
        ("r".into(), "x <- c(1, 2, 3)\nf <- function(a, b = 2) { a + b } # comment\nlibrary(ggplot2)".into()),
        ("pl".into(), "my @a = (1, 2); my %h = (a => 1);\nprint \"$a[0]\\n\" if $s =~ s/foo/bar/g;".into()),
        ("ex".into(), "defmodule M do\n  def f(x) when is_integer(x), do: x |> Kernel.+(1)\n  @attr :atom\nend".into()),
        ("erl".into(), "-module(m).\n-export([f/1]).\nf(X) when X > 0 -> {ok, X};\nf(_) -> error.".into()),
        ("clj".into(), "(defn f [x] (let [y (* x 2)] (println \"y\" y))) ; comment\n#{:a 1}".into()),
        ("ml".into(), "let rec f x = match x with | [] -> 0 | _ :: t -> 1 + f t (* comment *)".into()),
        ("fs".into(), "let f x = x + 1 // c\ntype R = { A: int }\n[<EntryPoint>]\nlet main _ = 0".into()),
        ("d".into(), "import std.stdio;\nvoid main() { writeln(\"hi\"); auto x = [1, 2]; }".into()),
        ("dart".into(), "void main() { var x = <int>[1, 2]; print('${x.length} items'); }".into()),
        ("sexp".into(), "(defun f (x) (+ x 1))".into()),
        ("txt".into(), "plain text".into()),
        ("tsv".into(), "a\tb\tc\n1\t2\t3".into()),
        ("csv".into(), "a,b,\"c,d\"\n1,2,3".into()),
        ("ini".into(), "[section]\nkey = value ; comment\n# other".into()),
        ("vim".into(), "set nocompatible\nlet g:x = 1 \" comment\nfunction! F()\nendfunction".into()),
        ("asm".into(), "mov eax, 1 ; comment\nlabel:\n  jmp label".into()),
        ("graphql".into(), "query Q($id: ID!) { user(id: $id) { name @include(if: true) } }".into()),
        ("proto".into(), "syntax = \"proto3\";\nmessage M { repeated int32 x = 1; }".into()),
        ("bat".into(), "@echo off\nset X=1\nif %X%==1 echo yes\nREM comment".into()),
        ("wgsl".into(), "@vertex fn main(@builtin(vertex_index) i: u32) -> @builtin(position) vec4<f32> { return vec4<f32>(0.0); }".into()),
        ("unicode-rs".into(), "".into()),
    ];
    out.retain(|(l, _)| l != "unicode-rs");
    out.push(("rs".into(), "let s = \"héllo wörld — ✓ 🎉\"; // ünïcödé ✓\nfn größe() -> char { 'ß' }".into()));
    // A generic snippet for every syntax with an extension, to exercise all
    // grammars at least shallowly.
    let generic = "foo(bar, 'baz', \"qux\") // comment\n# comment -- other ; x\n<tag attr=\"x\">{a: [1, 2.5e3, 0x1F]}</tag>\n  if (a == b && c != d) { return -1; } else x = y + z * 2\n\tlet $var = @at `tick` \\esc";
    let set = two_face::syntax::extra_no_newlines();
    for syntax in set.syntaxes() {
        if let Some(ext) = syntax.file_extensions.first() {
            out.push((ext.clone(), generic.into()));
        }
    }
    out
}

fn gen_tests(root: &PathBuf) {
    use syntect::easy::HighlightLines;
    use syntect::parsing::ParseState;
    let set = &*typst_library::text::RAW_SYNTAXES;
    let theme = &*typst_library::text::RAW_THEME;
    let mut out = String::new();
    out.push_str(
        "// Generated by `oracle/src/bin/gen_syntect.rs tests`: highlighting of\n\
         // samples with syntect 5.3.0, two-face 0.4.5's syntaxes and Typst's\n\
         // `RAW_THEME`. Do not edit by hand!\n\n",
    );
    out.push_str("///|\nlet highlight_cases : Array[(String, String, String)] = [\n");
    for (token, code) in samples() {
        let Some(syntax) = set.find_syntax_by_token(&token) else {
            continue;
        };
        let mut expected = String::new();
        writeln!(expected, "syntax {}", syntax.name).unwrap();
        let mut hl = HighlightLines::new(syntax, theme);
        let mut ps = ParseState::new(syntax);
        for line in typst_syntax::split_newlines(&code) {
            match ps.parse_line(line, set) {
                Ok(ops) => {
                    let ops: Vec<String> = ops.iter().map(|(i, op)| format!("{i}:{op:?}")).collect();
                    writeln!(expected, "ops {}", ops.join(" ")).unwrap();
                }
                Err(e) => writeln!(expected, "ops error {e}").unwrap(),
            }
            match hl.highlight_line(line, set) {
                Ok(pieces) => {
                    let pieces: Vec<String> = pieces
                        .iter()
                        .map(|(style, s)| {
                            let c = style.foreground;
                            format!(
                                "{:02x}{:02x}{:02x}{:02x}/{}/{s:?}",
                                c.r,
                                c.g,
                                c.b,
                                c.a,
                                style.font_style.bits()
                            )
                        })
                        .collect();
                    writeln!(expected, "line {}", pieces.join(" ")).unwrap();
                }
                Err(e) => writeln!(expected, "line error {e}").unwrap(),
            }
        }
        writeln!(out, "  ({}, {}, {}),", lit(&token), lit(&code), lit(&expected)).unwrap();
    }
    out.push_str("]\n");
    std::fs::write(root.join("syntect/two_face/highlight_gen_wbtest.mbt"), out).unwrap();
}

/// Custom `.sublime-syntax` files for the loading tests.
fn syntax_samples(assets: &std::path::Path) -> Vec<(String, String)> {
    let sexp = std::fs::read_to_string(assets.join("syntaxes/SExpressions.sublime-syntax")).unwrap();
    let head = "%YAML 1.2\n---\nname: lang\nfile_extensions:\n  - a\nscope: source\n";
    let mut v = vec![(sexp, "(define (f x) ; comment\n  (+ x 1.5 \"str\"\"ing\")) #| block |# #;(skip) )".to_string())];
    let bodies = [
        "contexts:\n  main:\n    - match: '\\'\n",
        "contexts:\n  main:\n    - match: ''\n",
        "contexts:\n  main:\n    - match: '(a)(b)?'\n      captures:\n        1: x.a\n        2: x.b\n",
        "contexts:\n  other:\n    - match: 'a'\n",
        "contexts:\n  main: 1\n",
        "contexts:\n  main:\n    - 1\n",
        "contexts:\n  main:\n    - match: 'a'\n      scope: a.b.c.d.e.f.g.h.i\n",
        "contexts:\n  main:\n    - match: '(?<!x)a+'\n      push: [inner, inner2]\n  inner:\n    - meta_scope: meta.inner\n    - match: '\\d'\n      scope: constant.numeric\n    - match: '$'\n      pop: true\n  inner2:\n    - meta_content_scope: meta.inner2\n    - match: 'b'\n      pop: true\n",
        "variables:\n  ident: '[A-Za-z_]\\w*'\n  num: '\\d+'\ncontexts:\n  main:\n    - match: '\\b({{ident}})\\s*(=)\\s*({{num}})'\n      captures:\n        1: variable.other\n        2: keyword.operator\n        3: constant.numeric\n    - match: '\"'\n      push: string\n  string:\n    - meta_scope: string.quoted\n    - match: '\\\\.'\n      scope: constant.character.escape\n    - match: '\"'\n      pop: true\n",
        "contexts:\n  main:\n    - match: '<<(\\w+)'\n      push: heredoc\n  heredoc:\n    - meta_scope: string.unquoted.heredoc\n    - match: '^\\1$'\n      pop: true\n",
        "contexts:\n  prototype:\n    - match: '#.*$'\n      scope: comment.line\n  main:\n    - match: '\\('\n      push: paren\n    - match: '\\w+'\n      scope: keyword\n  paren:\n    - clear_scopes: 1\n    - meta_scope: meta.paren\n    - match: '\\)'\n      pop: true\n    - include: main\n",
        "contexts:\n  main:\n    - match: '```'\n      embed: scope:source.rust\n      embed_scope: markup.raw\n      escape: '```'\n",
        "contexts:\n  main:\n    - match: '\\{'\n      set: block\n      with_prototype:\n        - match: '!'\n          scope: invalid\n  block:\n    - meta_content_scope: meta.block\n    - match: '\\}'\n      set: main\n    - match: 'x'\n      scope: variable\n",
        "contexts:\n  main:\n    - include: nonexistent\n    - match: 'a'\n      push: missing\n",
        "contexts:\n  main:\n    - match: 'a'\n      embed: other\n",
        "contexts:\n  main:\n    - match: '[[:alpha:]]+'\n      scope: word\n    - match: '\\n'\n      scope: newline\n    - match: '[\\n;]'\n      scope: sep\n",
        "contexts:\n  main:\n    - match: '(?x) a  # comment\n        b'\n      scope: ab\n",
        "contexts:\n  main:\n    - match: '\\p{Lu}\\w*'\n      scope: entity.name\n    - match: '(?i)select'\n      scope: keyword\n",
        "contexts:\n  main:\n    - match: '(?=a)'\n      push: x\n  x:\n    - match: '(?=a)'\n      pop: true\n    - match: 'a'\n      scope: a\n",
        "contexts:\n  main:\n    - match: 'a(?'\n",
        "contexts:\n  main:\n    - match: '\\k<x>'\n",
        "hidden: true\ncontexts:\n  main:\n    - match: 'x'\n",
    ];
    for b in bodies {
        v.push((format!("{head}{b}"), "a = 12 \"s\\\"x\" (b) a ```fn``` {x!} <<EOF\ntext\nEOF\nSelect Foo ab # c\naab".into()));
    }
    v.push(("".into(), "x".into()));
    v.push(("name: [unclosed\n".into(), "x".into()));
    v.push(("- a\n- b\n".into(), "x".into()));
    v.push(("name: x\ncontexts:\n  main: []\n".into(), "x".into()));
    v.push(("name: x\nscope: source.x\n".into(), "x".into()));
    v.push(("name: x\nscope: source.x\ncontexts:\n  main:\n    - match: 'a'\n      embed: b\n".into(), "x".into()));
    v.push(("scope: source.x\ncontexts:\n  main:\n    - match: \"\\t\"\n".into(), "x".into()));
    v
}

/// Theme files for the loading tests.
fn theme_samples(assets: &std::path::Path) -> Vec<String> {
    let halcyon = std::fs::read_to_string(assets.join("themes/halcyon.tmTheme")).unwrap();
    let plist = |body: &str| {
        format!("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\">\n{body}\n</plist>")
    };
    vec![
        halcyon,
        plist("<dict><key>name</key><string>T</string><key>settings</key><array><dict><key>settings</key><dict><key>foreground</key><string>#abc</string><key>background</key><string>#11223344</string></dict></dict><dict><key>scope</key><string>string, comment - comment.line</string><key>settings</key><dict><key>fontStyle</key><string>bold italic</string><key>foreground</key><string>#ff0000</string></dict></dict><dict><key>scope</key><string>keyword</string><key>settings</key><dict><key>fontStyle</key><string>weird</string></dict></dict></array></dict>"),
        plist("<dict><key>settings</key><array/></dict>"),
        plist("<dict><key>name</key><integer>1</integer><key>settings</key><array><dict><key>settings</key><dict/></dict></array></dict>"),
        plist("<array/>"),
        plist("<dict><key>settings</key><array><dict><key>settings</key><dict><key>foreground</key><string>red</string></dict></dict></array></dict>"),
        plist("<dict><key>settings</key><array><dict><key>settings</key><dict/></dict></array><key>gutterSettings</key><dict><key>background</key><string>#123456</string></dict></dict>"),
        plist("<dict><key>settings</key><array><dict><key>settings</key><dict/></dict><dict><key>scope</key><string>a</string><key>settings</key><dict><key>foreground</key><string>#12345</string></dict></dict></array><key>x</key><real>1.5</real><key>y</key><true/><key>z</key><date>2001-01-01T00:00:00Z</date></dict>"),
        plist("<dict><key>settings</key><array><dict><key>settings</key><dict/></dict></array><key>d</key><data>AAAA</data></dict>"),
        plist("<dict><key>settings</key><array><dict><key>settings</key><dict/></dict></array><key>i</key><integer>abc</integer></dict>"),
        plist("<dict><key>settings</key><unknown/></dict>"),
        "not xml at all".into(),
        "<plist><dict><key>a</key></plist>".into(),
        "".into(),
    ]
}

fn describe_theme(theme: &syntect::highlighting::Theme) -> String {
    let c = |c: Option<syntect::highlighting::Color>| match c {
        Some(c) => format!("{:02x}{:02x}{:02x}{:02x}", c.r, c.g, c.b, c.a),
        None => "-".into(),
    };
    let mut out = String::new();
    writeln!(out, "name {:?} author {:?}", theme.name, theme.author).unwrap();
    let s = &theme.settings;
    writeln!(
        out,
        "settings fg {} bg {} caret {} gutter {} gutter_fg {} line {} popup {:?}",
        c(s.foreground),
        c(s.background),
        c(s.caret),
        c(s.gutter),
        c(s.gutter_foreground),
        c(s.line_highlight),
        s.popup_css
    )
    .unwrap();
    for item in &theme.scopes {
        let sels: Vec<String> = item
            .scope
            .selectors
            .iter()
            .map(|sel| {
                let path: Vec<String> = sel.path.scopes.iter().map(|s| s.build_string()).collect();
                let ex: Vec<String> = sel
                    .excludes
                    .iter()
                    .map(|e| e.scopes.iter().map(|s| s.build_string()).collect::<Vec<_>>().join(" "))
                    .collect();
                format!("{}|{}", path.join(" "), ex.join(","))
            })
            .collect();
        writeln!(
            out,
            "item {} fg {} bg {} fs {:?}",
            sels.join(";"),
            c(item.style.foreground),
            c(item.style.background),
            item.style.font_style.map(|f| f.bits())
        )
        .unwrap();
    }
    out
}

fn gen_loading(root: &PathBuf, assets: &std::path::Path) {
    use syntect::easy::HighlightLines;
    use syntect::parsing::{SyntaxDefinition, SyntaxSetBuilder};
    let mut out = String::new();
    out.push_str(
        "// Generated by `oracle/src/bin/gen_syntect.rs loading`: loading of\n\
         // `.sublime-syntax` and `.tmTheme` files with syntect 5.3.0. Do not\n\
         // edit by hand!\n\n",
    );
    out.push_str("///|\nlet syntax_loading_cases : Array[(String, String, String)] = [\n");
    let theme = &*typst_library::text::RAW_THEME;
    for (yaml, code) in syntax_samples(assets) {
        let mut expected = String::new();
        match SyntaxDefinition::load_from_str(&yaml, false, None) {
            Err(e) => {
                writeln!(expected, "error {e}").unwrap();
                if let syntect::parsing::ParseSyntaxError::InvalidYaml(se) = &e {
                    let m = se.marker();
                    writeln!(expected, "at {} {} {}", m.index(), m.line(), m.col()).unwrap();
                }
            }
            Ok(def) => {
                let mut builder = SyntaxSetBuilder::new();
                builder.add(def);
                let set = builder.build();
                let syntax = &set.syntaxes()[0];
                writeln!(
                    expected,
                    "syntax {:?} {:?} {} hidden={}",
                    syntax.name,
                    syntax.file_extensions,
                    syntax.scope.build_string(),
                    syntax.hidden
                )
                .unwrap();
                let mut hl = HighlightLines::new(syntax, theme);
                for line in typst_syntax::split_newlines(&code) {
                    match hl.highlight_line(line, &set) {
                        Ok(pieces) => {
                            let pieces: Vec<String> = pieces
                                .iter()
                                .map(|(style, s)| {
                                    let c = style.foreground;
                                    format!(
                                        "{:02x}{:02x}{:02x}{:02x}/{}/{s:?}",
                                        c.r,
                                        c.g,
                                        c.b,
                                        c.a,
                                        style.font_style.bits()
                                    )
                                })
                                .collect();
                            writeln!(expected, "line {}", pieces.join(" ")).unwrap();
                        }
                        Err(e) => writeln!(expected, "line error {e}").unwrap(),
                    }
                }
            }
        }
        writeln!(out, "  ({}, {}, {}),", lit(&yaml), lit(&code), lit(&expected)).unwrap();
    }
    out.push_str("]\n\n");
    out.push_str("///|\nlet theme_loading_cases : Array[(String, String)] = [\n");
    for xml in theme_samples(assets) {
        let mut cursor = std::io::Cursor::new(xml.as_bytes());
        let expected = match syntect::highlighting::ThemeSet::load_from_reader(&mut cursor) {
            Ok(theme) => describe_theme(&theme),
            Err(e) => format!("error {e}\n"),
        };
        writeln!(out, "  ({}, {}),", lit(&xml), lit(&expected)).unwrap();
    }
    out.push_str("]\n");
    std::fs::write(root.join("syntect/two_face/loading_gen_wbtest.mbt"), out).unwrap();
}

/// Extracts the string literals of each `#[test]` function of a Rust file.
fn test_literals(src: &str) -> Vec<Vec<String>> {
    let start = src.find("#[cfg(test)]").unwrap_or(0);
    let src = &src[start..];
    let mut out = Vec::new();
    for body in src.split("#[test]").skip(1) {
        let b = body.as_bytes();
        let mut lits = Vec::new();
        let mut i = 0;
        while i < b.len() {
            if b[i] == b'/' && b.get(i + 1) == Some(&b'/') {
                while i < b.len() && b[i] != b'\n' {
                    i += 1;
                }
                continue;
            }
            if b[i] == b'\'' {
                // A char literal or a lifetime: skip `'x'` / `'\x'`.
                if b.get(i + 2) == Some(&b'\'') {
                    i += 3;
                    continue;
                }
                if b.get(i + 1) == Some(&b'\\') {
                    let mut j = i + 2;
                    while j < b.len() && b[j] != b'\'' {
                        j += 1;
                    }
                    i = j + 1;
                    continue;
                }
                i += 1;
                continue;
            }
            if b[i] == b'r' && (b.get(i + 1) == Some(&b'#') || b.get(i + 1) == Some(&b'"')) {
                let mut j = i + 1;
                let mut hashes = 0;
                while b.get(j) == Some(&b'#') {
                    hashes += 1;
                    j += 1;
                }
                if b.get(j) != Some(&b'"') {
                    i += 1;
                    continue;
                }
                let close = format!("\"{}", "#".repeat(hashes));
                let content_start = j + 1;
                let end = body[content_start..].find(&close).unwrap() + content_start;
                lits.push(body[content_start..end].to_string());
                i = end + close.len();
                continue;
            }
            if b[i] == b'"' {
                let mut s = String::new();
                let mut j = i + 1;
                let chars: Vec<char> = body[j..].chars().collect();
                let mut k = 0;
                while k < chars.len() && chars[k] != '"' {
                    if chars[k] == '\\' {
                        k += 1;
                        match chars[k] {
                            'n' => s.push('\n'),
                            't' => s.push('\t'),
                            'r' => s.push('\r'),
                            '0' => s.push('\0'),
                            '\\' => s.push('\\'),
                            '"' => s.push('"'),
                            '\'' => s.push('\''),
                            'u' => {
                                let close = chars[k..].iter().position(|&c| c == '}').unwrap();
                                let hex: String = chars[k + 2..k + close].iter().collect();
                                s.push(char::from_u32(u32::from_str_radix(&hex, 16).unwrap()).unwrap());
                                k += close;
                            }
                            '\n' => {
                                while k + 1 < chars.len() && chars[k + 1].is_whitespace() {
                                    k += 1;
                                }
                            }
                            c => panic!("unknown escape {c}"),
                        }
                    } else {
                        s.push(chars[k]);
                    }
                    k += 1;
                }
                j += chars[..k].iter().map(|c| c.len_utf8()).sum::<usize>();
                lits.push(s);
                i = j + 1;
                continue;
            }
            i += 1;
        }
        out.push(lits);
    }
    out
}

/// Runs the inline syntaxes of syntect's own parser and YAML loading tests
/// over the other string literals of each test.
fn gen_parser_tests(root: &PathBuf) {
    use syntect::parsing::{ParseState, SyntaxDefinition, SyntaxSetBuilder};
    let registry = PathBuf::from(std::env::var("HOME").unwrap())
        .join(".cargo/registry/src/index.crates.io-1949cf8c6b5b557f/syntect-5.3.0/src/parsing");
    let mut cases: Vec<(String, Vec<String>)> = Vec::new();
    for file in ["parser.rs", "yaml_load.rs"] {
        let src = std::fs::read_to_string(registry.join(file)).unwrap();
        for lits in test_literals(&src) {
            let (syntaxes, lines): (Vec<String>, Vec<String>) =
                lits.into_iter().partition(|l| l.contains("contexts:"));
            let lines: Vec<String> = lines.into_iter().filter(|l| l.len() < 200).collect();
            for syntax in syntaxes {
                cases.push((syntax, lines.clone()));
            }
        }
    }
    let mut out = String::new();
    out.push_str(
        "// Generated by `oracle/src/bin/gen_syntect.rs parser`: the inline\n\
         // syntaxes of syntect 5.3.0's parser and YAML loading tests, run over the\n\
         // other string literals of each test. Do not edit by hand!\n\n",
    );
    out.push_str("///|\nlet parser_cases : Array[(String, Array[String], String)] = [\n");
    for (syntax, lines) in &cases {
        let mut expected = String::new();
        for newlines in [false, true] {
            match SyntaxDefinition::load_from_str(syntax, newlines, None) {
                Err(e) => writeln!(expected, "error {e}").unwrap(),
                Ok(def) => {
                    let mut builder = SyntaxSetBuilder::new();
                    builder.add(def);
                    let set = builder.build();
                    let mut state = ParseState::new(&set.syntaxes()[0]);
                    for line in lines {
                        let line = if newlines { format!("{line}\n") } else { line.clone() };
                        match state.parse_line(&line, &set) {
                            Ok(ops) => {
                                let ops: Vec<String> =
                                    ops.iter().map(|(i, op)| format!("{i}:{op:?}")).collect();
                                writeln!(expected, "ops {}", ops.join(" ")).unwrap();
                            }
                            Err(e) => writeln!(expected, "error {e}").unwrap(),
                        }
                    }
                }
            }
        }
        let lines_lit: Vec<String> = lines.iter().map(|l| lit(l)).collect();
        writeln!(out, "  ({}, [{}], {}),", lit(syntax), lines_lit.join(", "), lit(&expected))
            .unwrap();
    }
    out.push_str("]\n");
    std::fs::write(root.join("syntect/parser_gen_wbtest.mbt"), out).unwrap();
}

fn main() {
    let mut args = std::env::args().skip(1);
    let mode = args.next().expect("mode");
    let root = PathBuf::from(args.next().unwrap_or_else(|| "..".into()));
    match mode.as_str() {
        "data" => gen_data(&root),
        "tests" => gen_tests(&root),
        "parser" => gen_parser_tests(&root),
        "loading" => {
            let assets = PathBuf::from(args.next().expect("typst-dev-assets files dir"));
            gen_loading(&root, &assets)
        }
        other => panic!("unknown mode {other}"),
    }
}
