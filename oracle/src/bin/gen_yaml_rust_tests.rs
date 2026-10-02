//! Generates `data/yaml_rust/oracle_gen_test.mbt`: differential tests for the
//! MoonBit port of `yaml-rust` 0.4.5 (the YAML loader of syntect), with
//! expected results produced by the real crate.
//!
//! Each test loads one input with `YamlLoader::load_from_str` and compares a
//! dump of the result: `Ok(<{:?} of the Vec<Yaml>>)` or
//! `Err(<Display of the ScanError> @ <index>:<line>:<col>)`.
//!
//! The corpus consists of hand-written edge cases, the YAML spec examples of
//! yaml-rust's own test suite and the YAML snippets of syntect's
//! `yaml_load.rs` tests (both read from the cargo registry), the YAML files of
//! typst-dev-assets, synthesized `.sublime-syntax` files, and deterministic
//! truncations/mutations of some of these.
//!
//! Usage: cargo run --release --bin gen_yaml_rust_tests -- <repo-root>

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use yaml_rust::YamlLoader;

/// The dumped result of loading `s`, or `None` if yaml-rust panics.
fn dump(s: &str) -> Option<String> {
    let s = s.to_owned();
    std::panic::catch_unwind(move || match YamlLoader::load_from_str(&s) {
        Ok(docs) => format!("Ok({docs:?})"),
        Err(e) => {
            let m = e.marker();
            format!("Err({e} @ {}:{}:{})", m.index(), m.line(), m.col())
        }
    })
    .ok()
}

/// A MoonBit string literal.
fn mbt_str(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 || c as u32 == 0x7f => {
                write!(out, "\\u{{{:x}}}", c as u32).unwrap()
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// Parses the Rust string literal (normal or raw) at the start of `s`;
/// returns its value and the rest of `s`.
fn parse_rust_str(s: &str) -> Option<(String, &str)> {
    if let Some(rest) = s.strip_prefix('r') {
        let hashes = rest.len() - rest.trim_start_matches('#').len();
        let rest = rest[hashes..].strip_prefix('"')?;
        let close = format!("\"{}", "#".repeat(hashes));
        let end = rest.find(&close)?;
        return Some((rest[..end].to_owned(), &rest[end + close.len()..]));
    }
    let rest = s.strip_prefix('"')?;
    let mut out = String::new();
    let mut chars = rest.char_indices();
    while let Some((i, c)) = chars.next() {
        match c {
            '"' => return Some((out, &rest[i + 1..])),
            '\\' => {
                let (_, n) = chars.next()?;
                match n {
                    'n' => out.push('\n'),
                    't' => out.push('\t'),
                    'r' => out.push('\r'),
                    '0' => out.push('\0'),
                    '\\' => out.push('\\'),
                    '"' => out.push('"'),
                    '\'' => out.push('\''),
                    'x' => {
                        let a = chars.next()?.1;
                        let b = chars.next()?.1;
                        let v = u32::from_str_radix(&format!("{a}{b}"), 16).ok()?;
                        out.push(char::from_u32(v)?);
                    }
                    'u' => {
                        chars.next()?; // '{'
                        let mut hex = String::new();
                        loop {
                            let (_, h) = chars.next()?;
                            if h == '}' {
                                break;
                            }
                            hex.push(h);
                        }
                        out.push(char::from_u32(u32::from_str_radix(&hex, 16).ok()?)?);
                    }
                    '\n' => {
                        // Line continuation: skip the following whitespace.
                        let mut peek = chars.clone();
                        while let Some((_, w)) = peek.next() {
                            if !w.is_whitespace() {
                                break;
                            }
                            chars = peek.clone();
                        }
                    }
                    _ => return None,
                }
            }
            c => out.push(c),
        }
    }
    None
}

/// The source directory of a crate in the cargo registry.
fn registry_crate(name: &str) -> Option<PathBuf> {
    let home = std::env::var_os("CARGO_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| Path::new(&h).join(".cargo")))?;
    for index in std::fs::read_dir(home.join("registry/src")).ok()? {
        let dir = index.ok()?.path().join(name);
        if dir.is_dir() {
            return Some(dir);
        }
    }
    None
}

/// The `const EX… : &'static str = "…";` spec examples of yaml-rust.
fn spec_examples() -> Vec<(String, String)> {
    let dir = registry_crate("yaml-rust-0.4.5").expect("yaml-rust-0.4.5 in the registry");
    let src = std::fs::read_to_string(dir.join("tests/specexamples.rs.inc")).unwrap();
    let mut out: Vec<(String, String)> = Vec::new();
    let mut rest = src.as_str();
    while let Some(i) = rest.find("const ") {
        rest = &rest[i + 6..];
        let name_end = rest.find(' ').unwrap();
        let name = rest[..name_end].to_owned();
        let eq = rest.find('=').unwrap();
        let value = rest[eq + 1..].trim_start();
        if let Some((v, r)) = parse_rust_str(value) {
            out.push((name, v));
            rest = r;
        } else {
            // `const EX8_11 : &'static str = EX8_10;`
            let alias = &value[..value.find(';').unwrap()];
            let v = out.iter().find(|(n, _)| n == alias).unwrap().1.clone();
            out.push((name, v));
        }
    }
    out
}

/// The string literals passed to `load_from_str(` in syntect's yaml_load.rs.
fn syntect_snippets() -> Vec<String> {
    let dir = registry_crate("syntect-5.3.0").expect("syntect-5.3.0 in the registry");
    let src = std::fs::read_to_string(dir.join("src/parsing/yaml_load.rs")).unwrap();
    let mut out = Vec::new();
    let mut rest = src.as_str();
    while let Some(i) = rest.find("load_from_str(") {
        rest = &rest[i + "load_from_str(".len()..];
        if let Some((v, r)) = parse_rust_str(rest.trim_start()) {
            out.push(v);
            rest = r;
        }
    }
    out
}

/// Hand-written edge cases.
const CASES: &[&str] = &[
    // empty and trivial documents
    "", " ", "\n", "\n\n# x\n", "# only comment", "---", "--- ", "...", "---\n...",
    "---\n---\n", "--- # c\n...\n...\n---", "- ", "-", ":", ": a", "?", "? ", "a:", "a: ",
    "- a:\n- b:", "[]", "{}", "''", "\"\"", "a\n...\nb", "a\n...\n---\nb",
    // required simple keys (flow content at the block indentation)
    "- [\nb\n]", "- [\nb\nc]", "- {\na\nb: c}", "- [\nb: c\n]", "- [\n'b'\nc]",
    "- [\nb\n, c]", "a:\n- [\nb\n]",
    // plain scalars and type resolution
    "~", "null", "Null", "NULL", "true", "True", "TRUE", "false", "yes", "no", "on", "0", "-0",
    "+0", "007", "1_000", "0x1F", "0xff", "0XFF", "0x", "0x-1", "0x+1", "0o17", "0o8", "0o-7",
    "0b101", "+12", "++12", "+-12", "-+12", "-", "+", "9223372036854775807",
    "9223372036854775808", "-9223372036854775808", "-9223372036854775809",
    "0x7FFFFFFFFFFFFFFF", "0x8000000000000000", "+9223372036854775807", "1.5", "1.", ".5", ".",
    "1e5", "1E5", "1e", "1e+5", "-1.5e-3", "1.5E+300", "1e400", "-1e400", "1e-400", "inf",
    "-inf", "+inf", "infinity", "Infinity", "-Infinity", "INF", "nan", "NaN", "-nan", "+NaN",
    ".inf", ".Inf", ".INF", "+.inf", "-.inf", "-.Inf", ".nan", ".NAN", ".NaN", "-.nan", "1_0.5",
    "0.1.2", "1,000", "2001-12-14", "12:30", "١٢٣", "0x١", "İnf",
    // tags
    "!!float 1", "!!float abc", "!!float .inf", "!!float inf", "!!float 1e", "!!int 0x10",
    "!!int +5", "!!int 1.0", "!!int 9223372036854775808", "!!bool True", "!!bool yes",
    "!!bool true", "!!null ''", "!!null null", "!!null ~", "!!null Null", "!!null", "!!str",
    "!!str ~", "!!str 12", "!!binary abc", "!foo 1", "!!map {a: 1}", "!!seq [1]", "! 12",
    "'~'", "\"true\"", "'1'", "!!int '1'", "- !!int\n- x", "&a !!int 5", "!!int &a 5",
    "&a !!int", "!", "!!", "!foo bar", "!<tag:yaml.org,2002:str> x", "!<x", "!<x> y", "!<> y",
    "!e!foo bar", "!a%41 b", "!a%ZZ b", "!a%C3%A9 b", "!a%FF b", "!a%C3 b", "!a%C3%41 b",
    "!a%E2%82%AC b", "!a%F0%9F%98%80 b", "!a%ED%A0%80 b", "!a{b} c", "!a,b c", "!a!b!c d",
    "!a\tb", "!!str\n- a", "!<!> x", "!!str: a",
    // directives
    "%YAML 1.2\n---\na", "%YAML 1.1\n--- a", "%YAML\n---", "%YAML 1\n---", "%YAML 1.\n---",
    "%YAML 1234567890.1\n---", "%YAML 1.1234567890\n---", "%YAML 1.2 # comment\n---\nx",
    "%YAML 1.2 junk\n---", "%YAML  \t1.2\n---\nx", "%YAML 1.2\n", "%YAML 1.2", "%FOO bar baz\n---\nx",
    "%\n---", "%YAML! 1.2", "%YA-ML 1.2\n---", "%YAML 1.2\n%YAML 1.2\n---\n", "%YAML 1.2\nx",
    "%TAG ! tag:x,2000:\n---\n!foo bar", "%TAG !e! tag:e.com,2000:app/\n---\n!e!foo x",
    "%TAG x", "%TAG !e tag\n---", "%TAG !e! \n---", "%TAG !! tag:yaml.org,2002:\n---\n!!int 3",
    "%TAG !e! %41b\n---", "%TAG !e! %4\n---", "a: b\n%YAML 1.2\n---\nc", " %YAML 1.2",
    "%YAML 1.2\r\n---\r\nx", "%TAG !e! tag:x\"y\n---", "%TAG !e! tag:x^\n---",
    "%TAG !e! tag:x # c\n---\n!e!a b", "%TAG !e!\n---",
    // multiple documents
    "---\na\n---\nb\n...\n---\nc", "--- |\n  foo\n...", "a\n---\n", "---\n- 1\n--- \n- 2",
    "--- a\n--- b\n--- c", "---a", "----", "--- #c", "...a", "....", "---\t", "...\t#",
    "'a'\n---\n'b'", "--- [\n---\n]", "--- '\n---\n'", "a: '\n...\n'",
    // block scalars
    "|\n a\n b\n\n", "|-\n a\n\n", "|+\n a\n\n", ">\n a\n b\n\n c\n", ">-\n a\n  b\n c",
    "|2\n   a\n  b", "|+2\n  a\n\n", "|-1\n x", "| # comment\n x", "|x\n", "|0\n  x", "|-0\n x",
    "|10\n x", "|1-\n x\n", "|+-\n x", "key: |\n  line1\n    indented\n  line3\n",
    "- |\n  a\n- >\n  b\n", ">\n\n folded\n line\n\n next\n line\n   * bullet\n\n last\n\n",
    "|\n\tx", "|\n  \t tab\n", "|\n  a\n \tb", "a: |\n  x\n b: c", "a: >\n\n\n  x\n\n\n",
    "|", ">", "a: |", "a: >-", "|\n", "|\n\n\n", "- |\n -", "a: |\n  x\nb: >\n  y\n",
    "|\r\n  a\r\n  b\r\n", ">\n  a\n\n\n  b", ">+\n  a\n\n", "|\n  a\n\u{85}b", "|\n   \n  a",
    "  |\n  a", "[|]", "{a: |}", "a: | x", "a: >2-\n    x\n  y",
    // flow collections
    "[a, b, c]", "[a, [b, c], {d: e}]", "{a: b, c: [d]}", "[a: b, c: d]", "{a, b: c}",
    "[? a : b]", "{? a}", "[,]", "[a,,b]", "{,}", "[a b]", "{a: b c: d}", "[\"a\":b]",
    "{\"a\":b}", "{a:b}", "[a:b]", "[:a]", "{a: :b}", "[- a]", "{a: - b}", "[\n a,\n b\n]",
    "{\n a: 1\n}", "[a\n,b]", "key: [a,\nb]", "- [a, b]: c", "[a, b]: c", "{a: 1}: b",
    "[a]]", "{a: 1}}", "[a", "{a", "[a,", "{a: [b}", "{a: b]", "]", "}", ",", "[a]b",
    "{a: b}c", "[a] b", "- [a] b", "['a' 'b']", "[\"a\" b]", "{'a': 'b'}", "{'a':'b'}",
    "{\"a\": 1, \"b\": [true, null]}", "[{}, [], {a: []}]", "{? [a]: b}", "[? ]", "[? a, b]",
    "{a: }", "{: b}", "{a: b,}", "[a,]", "[a, ]", "[ ]", "{ }", "[[[]]]", "[a, *b]",
    "[&a b, *a]", "{&a b: *a}", "[!!int 1, !!str 2]", "{a: [1,\n2],\nb: 3}", "[a\n  b]",
    "{a\n: b}", "[a, b]\n", " [a]", "- {a: b}\n- [c]", "[a: [b], c: {d: e}]", "[{a: b}: c]",
    "{[a]: b}", "[\"a\"\n:b]", "[a #c\n, b]", "[a, b] # c", "{a: 1, a: 2}", "[\ta,\tb]",
    "[a\t,b]", "{\ta: b}", "a: [b,\n  c]", "a: {b: c,\n d: e}", "[a, b\n  c]", "[`a`]",
    "[@a]", "{a: @}", "[%]", "[|a]", "[>a]", "[-]", "[- ]", "[?]", "[:]", "[::]", "{::}",
    "[a:]", "{a:}", "{a:,b:}", "[a: ]", "[\"a\":]", "{\"a\":}", "[a:1]", "{a:1}",
    "{\"a\":1}", "{'a':1}", "[?a]", "{?a: b}", "{a: ?b}",
    // block mappings and sequences, indentation
    "? a\n: b", "? [a, b]\n: c", "? |\n  block key\n: v", "? a\n? b\n: c", ": a\n: b",
    "? a\nb: c", "a: 1\na: 2", "1: a\n1: b", "~: a", "null: a\n~: b", "true: a", "1.5: x",
    "0x10: y", "a\n: b", "foo: bar: baz", "- a: b\n  - c", "a:\n- b\n- c\nd: e", "a: b\n c: d",
    "a:\n  b: c\n d: e", " a: b\nc: d", "a:\n    b: 1\n  c: 2", "- a\n  - b", "-   a\n    b",
    "a:\n- b\n  c: d", "a:\n  - b\n  - c\n e: f", "- - - a", "-a", "- -a", "--- a: b",
    "a: b\n- c", "- a\nb: c", "a:\n  - b\nc:\n  - d", "- a\n-\n- b", "-\n  a: b\n  c: d",
    "- ? a\n  : b", "a:\n  ? b\n  : c", "a: -b", "a: - b", "a: ? b", "a: : b", "a: b:",
    "a:b", "a :b", "a : b", "a  :  b", "'a': b", "\"a\": b", "'a' : b", "\"a\"\n: b",
    "[a]: b", "&x a: *x", "*x: a", "a: b\n  # c\nd: e", "a:\n#c\n  b: c", "a:\n  b\n  c",
    "a:\n  b\nc", "a: 'b'\n  c: d", "a:\n  - b\n  -c", "a:\n -  b\n -   c", "- a\n - b",
    "  - a\n  - b", "  a: b\n  c: d", "  a: b\n c: d", "a:\n  b:\n    c:\n      d: e",
    "a: b\n\n\nc: d", "a: b\r\nc: d\r\n", "a: b\rc: d", "a: b\r", "- a\r- b",
    "key with spaces: value with spaces", "a b: c d", "- a b\n- c d",
    // simple keys spanning lines and long keys
    "a\nb: c", "'a\nb': c", "\"a\nb\": c", "[a\nb]: c", "{a: b\n}: c", "a: b\nc",
    // quoted scalars and escapes
    "'unclosed", "\"unclosed", "\"bad \\q escape\"", "\"\\x4\"", "\"\\x4g\"", "\"\\uD800\"",
    "\"\\uDFFF\"", "\"\\U00110000\"", "\"\\U0001F600\"", "\"\\u00e9\\x41\\N\\_\\L\\P\"",
    "\"\\e\\a\\b\\v\\f\\0\\ \\t\\\t\\r\\n\\\"\\'\\\\\"", "\"\\/\"", "\"\\\"",
    "'it''s'", "'''", "''''", "\"a\\\"b\"", "\"a\\\nb\"", "\"a\\\n  b\"", "\"a\\\r\nb\"",
    "\"a\n  b\"", "'a\n  b'", "'a\n\n  b'", "\"a\n\n\n  b\"", "'a  \n  b'", "\"a \\\n b\"",
    "'a'b", "\"a\"b", "'a' b", "\"a\" b", "'a'#c", "'a' #c", "\"a\":", "'a\tb'", "\"a\tb\"",
    "'\ta'", "' a '", "\" a \"", "'a\n---\nb'", "\"a\n...\nb\"", "'a\n--- b'", "'a\n---b'",
    "\"\\x\"", "\"\\u12\"", "\"\\U0000000\"", "\"\\x41\\x42\"", "\"\\u{41}\"", "\"\\%\"",
    "\"a\r\nb\"", "'a\r\n\r\nb'", "a: \"x\\\n\n  y\"", "\"\\\n\"", "\"\n\"", "'\n'",
    "\"a\\\\\"b", "\"a\\\\\\\"\"", "'\\'", "\"\\x7f\\x80\\xff\"",
    // plain multi-line scalars
    "a: plain\n  continued\n  more", "a b\nc d", "a\n\nb", "a\n\n\nb", "a  \n  b", "a\n  \n  b",
    "a: b\n  \n  c", "- a\n  b\n- c", "a:\n b\n c", "plain # c\n more", "a: b #c\n  d",
    "a: x\n\t y", "a: x\n \ty", "- x\n \ty", "a\n\tb", "a\n \tb", "a: b\tc", "a: b \t c",
    "a: b\t#c", "a: b#c", "a#b: c", "a: b # c # d",
    // anchors and aliases
    "&", "*", "&anchor", "*undefined", "a: *undefined", "&a b\n", "&a [1, *a]",
    "- &a x\n- *a\n- &a y\n- *a", "&a: b", "a: &b\n  c: d\ne: *b", "*a: b", "[*a]", "&a\n- x",
    "&a &b c", "!!str !!int c", "a: !!str", "&a{}", "&a[]", "&a b: c\nd: *a", "&a\n",
    "a: &x 1\nb: *x\nc: &x 2\nd: *x", "&a- b", "&a:b", "&a,b", "&a]", "&a}", "&a%", "&a@",
    "&a`", "&a?", "&a b\n--- *a", "- &a\n- *a", "a: &x\n  - 1\n  - *x", "*a\n", "&a\t1",
    "&é b", "&a.b c", "*a b", "&a [*a]", "- &k key: v\n- *k",
    "base: &base {x: 1}\nderived:\n  <<: *base\n  y: 2", "&a !!str", "!!str &a",
    "[&a, *a]", "{&a : b}", "&a\n&b c",
    // reserved/odd characters
    "`a`", "@a", "%a", "a: @b", "a: `b`", "a: %b", "a: b@c", "a@: b", "- @", "- `",
    "a:\n  - %", "#a", "a: #b", "-#", "?#", ":#", "a: |#", "a: >#c",
    // tabs
    "a:\tb", "\ta: b", "a: b\t", "- \ta", "a:\n  b:\tc", "a: 'x\ty'", "a:\n  -\tb",
    "key:\n\t\tvalue", "-\ta", "?\ta", ":\ta", "a:\n\t- b", "- a\n\t- b", "\t", "\t\n",
    "a: [\n\tb\n]", "a:\n  b\n\tc", "\t#c\na: b", "a: b\n\t#c", "[a]\t", "a:\t\n  b",
    // unicode and special characters
    "你好: 世界", "😀: x", "- 😀\n- 你好", "a: é\u{301}", "\u{feff}a: b", "a: b\u{feff}",
    "\u{feff}", "a: \u{85}b", "a:\u{a0}b", "a\u{0}b", "a: b\n\u{0}c", "\u{0}", "'\u{0}'",
    "a: \u{2028}b", "\"\u{1}\"", "a: \u{7f}", "\u{10ffff}: x", "a: \u{e000}", "é: é",
    "[é, ü]", "{ä: ö}", "'ü\n ö'", "&ü x", "!ü x", "a\u{3000}b: c",
];

/// Realistic `.sublime-syntax` files.
const SUBLIME: &[&str] = &[
    r#"%YAML 1.2
---
# See http://www.sublimetext.com/docs/syntax.html
name: Mini Rust
file_extensions:
  - rs
  - rlib
first_line_match: ^#!\s*/usr/bin/env\s+run-cargo-script
scope: source.rust
version: 2

variables:
  non_raw_ident: '[[:alpha:]][_[:alnum:]]*|_[_[:alnum:]]+'
  identifier: '(?:(?:r\#)?{{non_raw_ident}})'
  escaped_byte: '\\([nrt0\"''\\]|x\h{2})'
  int_suffixes: '[iu](?:8|16|32|64|128|size)'

contexts:
  main:
    - include: statements

  prototype:
    - include: comments

  statements:
    - match: '(''){{identifier}}(?=\:\s*(?:for|while|loop)\b)'
      scope: entity.name.label.rust
      captures:
        1: punctuation.definition.label.rust
    - match: \b(fn)\s+({{identifier}})
      captures:
        1: storage.type.function.rust keyword.declaration.function.rust
        2: entity.name.function.rust
      push: fn-parameters
    - match: '"'
      scope: punctuation.definition.string.begin.rust
      push: string
    - match: '\b0x[\h_]+{{int_suffixes}}?\b'
      scope: constant.numeric.integer.hexadecimal.rust
    - match: \b(true|false)\b
      scope: constant.language.boolean.rust

  fn-parameters:
    - meta_scope: meta.function.parameters.rust
    - match: \)
      pop: true
    - match: '[{};]'
      pop: 2

  string:
    - meta_include_prototype: false
    - meta_scope: string.quoted.double.rust
    - match: '{{escaped_byte}}'
      scope: constant.character.escape.rust
    - match: '"'
      scope: punctuation.definition.string.end.rust
      pop: true

  comments:
    - match: /\*
      scope: punctuation.definition.comment.rust
      push:
        - meta_scope: comment.block.rust
        - match: \*/
          pop: true
    - match: //
      scope: punctuation.definition.comment.rust
      push:
        - meta_scope: comment.line.double-slash.rust
        - match: $\n?
          pop: true
"#,
    r#"%YAML 1.2
---
name: Mini Markdown
scope: text.html.markdown
file_extensions: [md, mdown, markdown]
hidden: false
variables:
  fenced_code_block_start: |-
    (?x:
      ([ \t]*)
      (
        (`){3,}    # 3 or more backticks
        (?![^`]*`) # not followed by any more backticks on the same line
      |            # or
        (~){3,}    # 3 or more tildas
      )
    )
  indented_code_block: (?:\s{4}|\t)
contexts:
  main:
    - match: '{{fenced_code_block_start}}(?i:(python|py))\s*$'
      captures:
        0: meta.code-fence.definition.begin.python.markdown-gfm
        2: punctuation.definition.raw.code-fence.begin.markdown
        5: constant.other.language-name.markdown
      embed: scope:source.python
      embed_scope: markup.raw.code-fence.python.markdown-gfm
      escape: ^\1\2\s*$
      escape_captures:
        0: meta.code-fence.definition.end.python.markdown-gfm
    - match: ^(#{1,6})\s+(.*?)\s*(#*)$\n?
      scope: markup.heading.markdown
      captures: {1: punctuation.definition.heading.begin.markdown, 2: entity.name.section.markdown}
    - match: (\*\*|__)(?=\S)
      push: bold
    - match: '\\[-`*_#+.!(){}\[\]\\>|~<]'
      scope: constant.character.escape.markdown
  bold:
    - meta_scope: markup.bold.markdown
    - match: \1
      pop: true
    - include: main
"#,
    r#"name: JSON-ish
scope: source.json
contexts:
  main:
    - match: '\{'
      scope: punctuation.section.mapping.begin.json
      push: object
    - match: '"'
      push:
        - meta_scope: string.quoted.double.json
        - match: '\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4})'
          scope: constant.character.escape.json
        - match: '\\.'
          scope: invalid.illegal.unrecognized-string-escape.json
        - match: '"'
          pop: true
    - match: '-?(?:0|[1-9]\d*)(?:(?:\.\d+)?(?:[eE][+-]?\d+)?)?'
      scope: constant.numeric.json
    - match: \b(?:true|false|null)\b
      scope: constant.language.json
  object:
    - match: '\}'
      pop: true
    - match: ':'
      scope: punctuation.separator.mapping.key-value.json
    - match: ','
      scope: punctuation.separator.mapping.pair.json
"#,
    "%YAML 1.2\n---\nname: lang\nfile_extensions:\n  - a\nscope: source\ncontexts:\n  main:\n    - match: '\\'\n",
    "%YAML 1.2\n---\nname: lang\nfile_extensions:\n  - a\nscope: source\ncontexts:\n  main:\n    - match: ''\n",
    r#"%YAML 1.2
---
name: With Prototype
scope: source.wp
contexts:
  main:
    - match: (?=<script)
      push: [script-close, script-open]
      with_prototype:
        - match: (?=</script)
          pop: true
    - match: "\"(?:[^\"\\\\]|\\\\.)*\""
      scope: string.quoted.double.wp
    - match: '\b(if|else|for|while)\b'
      scope: keyword.control.wp
    - match: '#.*$'
      scope: comment.line.number-sign.wp
    - match: (\$)([a-zA-Z_]\w*)
      captures:
        1: punctuation.definition.variable.wp
        2: variable.other.wp
    - match: '\{\{'
      push:
        - clear_scopes: 1
        - meta_content_scope: meta.interpolation.wp
        - match: '\}\}'
          pop: true
  script-open:
    - match: <script
      set: [ script-body ]
  script-close:
    - match: </script>
      pop: true
  script-body:
    - match: '>'
      embed: scope:source.js
      escape: (?i)(?=</script)
"#,
    // Broken variants of sublime syntaxes.
    "name: x\nscope: source.x\ncontexts:\n  main:\n    - match: 'unterminated\n      scope: a\n",
    "name: x\ncontexts:\n  main:\n  - match: a\n     scope: b\n",
    "name: x\ncontexts:\n\tmain:\n    - match: a\n",
    "name: x\ncontexts:\n  main:\n    - match: \"\\d+\"\n",
    "name: x\ncontexts:\n  main:\n    - match: [a\n",
    "name: x\ncontexts:\n  main:\n    - match: {{ident}}\n",
    "name: x\ncontexts:\n  main:\n    - match: '{{ident}}'\n      scope: a\n      scope: b\n",
    "name: x\ncontexts:\n  main:\n    - match: a\n    scope: b\n",
    "name: x\nvariables:\n  a: &v '\\w+'\ncontexts:\n  main:\n    - match: *v\n",
];

/// A deterministic xorshift PRNG.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }
}

/// Truncations and single-char mutations of `src`.
fn mutations(src: &str, rng: &mut Rng, count: usize) -> Vec<String> {
    const INSERT: &[char] = &[
        '\'', '"', '[', ']', '{', '}', ':', '-', '?', '#', '&', '*', '!', '|', '>', '%', '@', '`',
        '\t', '\n', ' ', ',', '\\', '\r',
    ];
    let chars: Vec<char> = src.chars().collect();
    let mut out = Vec::new();
    for _ in 0..count {
        let pos = (rng.next() % (chars.len() as u64 + 1)) as usize;
        let mut v = chars.clone();
        match rng.next() % 3 {
            0 => v.truncate(pos),
            1 => {
                if pos < v.len() {
                    v.remove(pos);
                }
            }
            _ => v.insert(pos, INSERT[(rng.next() % INSERT.len() as u64) as usize]),
        }
        out.push(v.into_iter().collect());
    }
    out
}

fn main() {
    let root = std::env::args().nth(1).expect("repo root");
    std::panic::set_hook(Box::new(|_| {}));

    let mut groups: Vec<(String, Vec<(String, String)>)> = Vec::new();
    let named = |prefix: &str, v: Vec<String>| -> Vec<(String, String)> {
        v.into_iter().enumerate().map(|(i, s)| (format!("{prefix}{i}"), s)).collect()
    };

    groups.push(("cases".into(), named("", CASES.iter().map(|s| s.to_string()).collect())));

    // Recursion limits and long simple keys.
    let mut limits = Vec::new();
    for n in [254, 255, 256, 300] {
        limits.push("[".repeat(n) + &"]".repeat(n));
        limits.push("{a:".repeat(n) + &"}".repeat(n));
    }
    let long = "k".repeat(1030);
    limits.push(format!("{long}: v"));
    limits.push(format!("{}: v", "k".repeat(1020)));
    limits.push(format!("{{{long}: v}}"));
    limits.push(format!("[{long}: v]"));
    limits.push(format!("'{long}': v"));
    limits.push(format!("a:\n  {long}: v"));
    limits.push("- ".repeat(200) + "x");
    groups.push(("limits".into(), named("", limits)));

    let spec = spec_examples();
    groups.push(("spec".into(), spec.iter().map(|(n, v)| (n.to_lowercase(), v.clone())).collect()));
    groups.push(("syntect".into(), named("", syntect_snippets())));

    let mut assets = Vec::new();
    for path in [
        "syntaxes/SExpressions.sublime-syntax",
        "data/yaml-types.yaml",
        "data/bad.yaml",
        "bib/scifi-authors.yaml",
    ] {
        let data = typst_dev_assets::get(path).expect(path);
        assets.push((path.replace(['/', '.'], "_"), String::from_utf8(data.to_vec()).unwrap()));
    }
    groups.push(("assets".into(), assets.clone()));
    groups.push(("sublime".into(), named("", SUBLIME.iter().map(|s| s.to_string()).collect())));

    // Deterministic mutations.
    let mut rng = Rng(0x9E37_79B9_7F4A_7C15);
    let mut muts = Vec::new();
    let sexp = &assets[0].1;
    muts.extend(mutations(sexp, &mut rng, 150));
    for s in SUBLIME.iter().take(3) {
        muts.extend(mutations(s, &mut rng, 100));
    }
    for (_, s) in spec.iter().step_by(3) {
        muts.extend(mutations(s, &mut rng, 4));
    }
    groups.push(("mutations".into(), named("", muts)));

    let mut out = String::new();
    writeln!(out, "// Code generated by oracle/src/bin/gen_yaml_rust_tests.rs. DO NOT EDIT.").unwrap();
    writeln!(out, "// Expected outputs come from the yaml-rust 0.4.5 crate.").unwrap();
    let mut total = 0;
    let mut panics = 0;
    for (group, cases) in &groups {
        for (name, input) in cases {
            let Some(expected) = dump(input) else {
                panics += 1;
                writeln!(out, "\n// {group}/{name}: yaml-rust panics on {}", mbt_str(input))
                    .unwrap();
                continue;
            };
            total += 1;
            writeln!(out).unwrap();
            writeln!(out, "///|").unwrap();
            writeln!(out, "test \"yaml_rust/{group}/{name}\" {{").unwrap();
            writeln!(out, "  assert_eq(\n    load_dump({}),\n    {},\n  )", mbt_str(input), mbt_str(&expected))
                .unwrap();
            writeln!(out, "}}").unwrap();
        }
    }
    std::fs::write(format!("{root}/data/yaml_rust/oracle_gen_test.mbt"), out).unwrap();
    eprintln!("wrote {total} tests ({panics} inputs panic upstream)");
}
