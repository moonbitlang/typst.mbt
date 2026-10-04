//! Generates `html_assets/mathml_data_gen.mbt` (the MathML Core operator
//! dictionary tables of `typst_assets::mathml`) and
//! `html_assets/mathml_gen_wbtest.mbt` (expected results of the public
//! `typst_assets::mathml` API) from the very same `typst-assets` crate
//! upstream Typst uses.
//!
//! The tables live in the crate-private `files/mathml/data.rs`, which is
//! located through `cargo metadata` and parsed here.
//!
//! Usage (from `oracle/`): `cargo run --release --bin gen_mathml -- ..`
//! (the argument is the repository root), then `moon fmt`.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};
use std::process::Command;

use regex::Regex;
use typst_assets::mathml::{
    Form, OperatorInfo, Properties, is_fence, is_separator, is_stretch_axis_inline,
    will_auto_transform,
};

/// The categories in the order of `data::Category`.
const CATEGORIES: &[&str] = &[
    "DEFAULT", "FORCEDEFAULT", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
    "M",
];

/// Find `files/mathml/data.rs` of the `typst-assets` dependency.
fn data_path() -> PathBuf {
    let manifest = Path::new(env!("CARGO_MANIFEST_DIR")).join("Cargo.toml");
    let output = Command::new("cargo")
        .args(["metadata", "--format-version", "1", "--manifest-path"])
        .arg(&manifest)
        .output()
        .expect("failed to run cargo metadata");
    let meta: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    let pkg = meta["packages"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["name"] == "typst-assets")
        .expect("typst-assets not found");
    let manifest_path = PathBuf::from(pkg["manifest_path"].as_str().unwrap());
    manifest_path.parent().unwrap().join("files/mathml/data.rs")
}

/// Extract the body of `pub(crate) const NAME: ... = &[ ... ];`.
fn table_body<'a>(src: &'a str, name: &str) -> &'a str {
    let start = src.find(&format!("const {name}:")).expect(name);
    let open = start + src[start..].find("&[").unwrap() + 2;
    let close = open + src[open..].find("];").unwrap();
    &src[open..close]
}

/// Parse a Rust char literal body (`'\u{2C}'` or `'x'`).
fn parse_char(lit: &str) -> char {
    if let Some(hex) = lit.strip_prefix("\\u{").and_then(|s| s.strip_suffix('}')) {
        char::from_u32(u32::from_str_radix(hex, 16).unwrap()).unwrap()
    } else {
        let mut chars = lit.chars();
        let c = chars.next().unwrap();
        assert!(chars.next().is_none(), "unexpected char literal {lit}");
        c
    }
}

fn parse_int(s: &str) -> u32 {
    let s = s.trim();
    if let Some(hex) = s.strip_prefix("0x") {
        u32::from_str_radix(hex, 16).unwrap()
    } else {
        s.parse().unwrap()
    }
}

/// A MoonBit char literal.
fn char_lit(c: char) -> String {
    match c {
        '\'' => "'\\''".into(),
        '\\' => "'\\\\'".into(),
        c if c.is_ascii_graphic() || c == ' ' => format!("'{c}'"),
        c => format!("'\\u{{{:X}}}'", c as u32),
    }
}

/// A MoonBit string literal.
fn str_lit(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if c.is_ascii_graphic() || c == ' ' => out.push(c),
            c => write!(out, "\\u{{{:X}}}", c as u32).unwrap(),
        }
    }
    out.push('"');
    out
}

/// Emit an array-returning function with one entry per line.
fn emit_array(out: &mut String, doc: &str, name: &str, ty: &str, items: &[String]) {
    writeln!(out, "///|\n/// {doc}\nlet {name} : ReadOnlyArray[{ty}] = [").unwrap();
    for item in items {
        writeln!(out, "  {item},").unwrap();
    }
    out.push_str("]\n\n");
}

fn form_name(form: Form) -> &'static str {
    match form {
        Form::Infix => "Infix",
        Form::Prefix => "Prefix",
        Form::Postfix => "Postfix",
    }
}

/// The parsed category infos: (form, lspace, rspace, property bits).
type Info = (Option<Form>, f64, f64, u8);

fn parse_infos(src: &str) -> Vec<Info> {
    let re = Regex::new(
        r"(?s)static CATEGORY_(\w+): OperatorInfo = OperatorInfo \{\s*form: ([^,]+),\s*lspace: ([0-9.]+),\s*rspace: ([0-9.]+),\s*properties: (.*?),\n\};",
    )
    .unwrap();
    let mut infos = vec![None; CATEGORIES.len()];
    for cap in re.captures_iter(src) {
        let idx = CATEGORIES.iter().position(|c| *c == &cap[1]).expect(&cap[1]);
        let form = match cap[2].trim() {
            "None" => None,
            "Some(Form::Infix)" => Some(Form::Infix),
            "Some(Form::Prefix)" => Some(Form::Prefix),
            "Some(Form::Postfix)" => Some(Form::Postfix),
            other => panic!("unexpected form {other}"),
        };
        let props = &cap[5];
        let mut bits = 0u8;
        for (name, flag) in [
            ("STRETCHY", Properties::STRETCHY),
            ("SYMMETRIC", Properties::SYMMETRIC),
            ("LARGEOP", Properties::LARGEOP),
            ("MOVABLELIMITS", Properties::MOVABLELIMITS),
        ] {
            if props.contains(name) {
                bits |= flag.bits();
            }
        }
        let lspace: f64 = cap[3].parse().unwrap();
        let rspace: f64 = cap[4].parse().unwrap();
        infos[idx] = Some((form, lspace, rspace, bits));
    }
    infos.into_iter().map(|i| i.expect("missing category")).collect()
}

fn info_of(info: &OperatorInfo) -> Info {
    (info.form, info.lspace, info.rspace, info.properties.bits())
}

/// The contents for which expected results are generated.
fn test_contents(two_ascii: &[String]) -> Vec<String> {
    let mut contents = vec![String::new(), "abc".into(), "xx".into(), "==".into()];
    for c in (0u32..0x400).chain(0x2000..0x2C00).chain(0xFE30..0xFE40) {
        contents.push(char::from_u32(c).unwrap().to_string());
    }
    for c in [0x1EEF0, 0x1EEF1, 0x1EEF2, 0x10437, 0x1D11E] {
        contents.push(char::from_u32(c).unwrap().to_string());
    }
    contents.extend(two_ascii.iter().cloned());
    for s in ["/\u{338}", "=\u{20D2}", "<\u{338}", "a\u{338}"] {
        contents.push(s.into());
    }
    contents
}

fn main() {
    let root = PathBuf::from(std::env::args().nth(1).unwrap_or_else(|| "..".into()));
    let src = std::fs::read_to_string(data_path()).unwrap();
    let infos = parse_infos(&src);

    let mut out = String::new();
    out.push_str(
        "// Generated by `oracle/src/bin/gen_mathml.rs` from the `typst-assets`\n\
         // crate used by upstream Typst (`typst_assets::mathml`, derived from the\n\
         // MathML Core operator dictionary). Do not edit.\n\n",
    );

    // Category infos.
    let mut items = vec![];
    for (name, (form, lspace, rspace, bits)) in CATEGORIES.iter().zip(&infos) {
        let form = match form {
            None => "None".to_string(),
            Some(f) => format!("Some({})", form_name(*f)),
        };
        items.push(format!(
            "// {name}\n  {{ form: {form}, lspace: {lspace:?}, rspace: {rspace:?}, properties: Properties({bits}) }}"
        ));
    }
    emit_array(
        &mut out,
        "The operator infos of the categories, in the order of `Category`.",
        "category_infos",
        "OperatorInfo",
        &items,
    );

    // `from_encoding`.
    let re = Regex::new(r"(0x[0-9a-fA-F]+) => Category::(\w+),").unwrap();
    let start = src.find("fn from_encoding").unwrap();
    let end = start + src[start..].find("_ => unreachable!()").unwrap();
    let mut items = vec![];
    for cap in re.captures_iter(&src[start..end]) {
        let idx = CATEGORIES
            .iter()
            .position(|c| c.eq_ignore_ascii_case(&cap[2]))
            .unwrap();
        items.push(format!("({}, {idx})", parse_int(&cap[1])));
    }
    emit_array(
        &mut out,
        "Maps an operator table encoding to a category index (`from_encoding`).",
        "category_encodings",
        "(Int, Int)",
        &items,
    );

    // `OPERATOR_TABLE`.
    let re = Regex::new(r"\((0x[0-9a-fA-F]+), (0x[0-9a-fA-F]+)\)").unwrap();
    let items: Vec<_> = re
        .captures_iter(table_body(&src, "OPERATOR_TABLE"))
        .map(|cap| format!("({}, {})", parse_int(&cap[1]), parse_int(&cap[2])))
        .collect();
    emit_array(
        &mut out,
        "The operator dictionary (`OPERATOR_TABLE`): (key, encoding << 4 | range length).",
        "operator_table",
        "(Int, Int)",
        &items,
    );

    // `TWO_ASCII_CHARS_TABLE`.
    let re = Regex::new(r#""((?:[^"\\]|\\.)*)""#).unwrap();
    let two_ascii: Vec<String> = re
        .captures_iter(table_body(&src, "TWO_ASCII_CHARS_TABLE"))
        .map(|cap| cap[1].replace("\\\\", "\\").replace("\\\"", "\""))
        .collect();
    let items: Vec<_> = two_ascii.iter().map(|s| str_lit(s)).collect();
    emit_array(
        &mut out,
        "Operators of two ASCII characters (`TWO_ASCII_CHARS_TABLE`).",
        "two_ascii_chars_table",
        "String",
        &items,
    );

    // `FENCE_TABLE`.
    let re = Regex::new(r"\('([^']+)', (0x[0-9a-fA-F]+)\)").unwrap();
    let items: Vec<_> = re
        .captures_iter(table_body(&src, "FENCE_TABLE"))
        .map(|cap| format!("({}, {})", char_lit(parse_char(&cap[1])), parse_int(&cap[2])))
        .collect();
    emit_array(
        &mut out,
        "Ranges of fence characters (`FENCE_TABLE`): (start, length).",
        "fence_table",
        "(Char, Int)",
        &items,
    );

    // Char tables.
    let re = Regex::new(r"'([^']+)'").unwrap();
    for (table, name, doc) in [
        ("SEPARATOR_TABLE", "separator_table", "Separator characters (`SEPARATOR_TABLE`)."),
        (
            "INLINE_AXIS_NON_BMP_TABLE",
            "inline_axis_non_bmp_table",
            "Non-BMP characters with an inline stretch axis (`INLINE_AXIS_NON_BMP_TABLE`).",
        ),
    ] {
        let items: Vec<_> = re
            .captures_iter(table_body(&src, table))
            .map(|cap| char_lit(parse_char(&cap[1])))
            .collect();
        emit_array(&mut out, doc, name, "Char", &items);
    }

    // `INLINE_AXIS_BMP_TABLE`.
    let re = Regex::new(r"0x[0-9a-fA-F]+").unwrap();
    let items: Vec<_> = re
        .find_iter(table_body(&src, "INLINE_AXIS_BMP_TABLE"))
        .map(|m| parse_int(m.as_str()).to_string())
        .collect();
    emit_array(
        &mut out,
        "BMP characters with an inline stretch axis (`INLINE_AXIS_BMP_TABLE`).",
        "inline_axis_bmp_table",
        "Int",
        &items,
    );
    std::fs::write(root.join("html_assets/mathml_data_gen.mbt"), out).unwrap();

    // Expected results of the public API.
    let contents = test_contents(&two_ascii);
    let mut test = String::new();
    test.push_str(
        "// Generated by `oracle/src/bin/gen_mathml.rs`: expected results of the\n\
         // public `typst_assets::mathml` API. Do not edit.\n\n",
    );
    let items: Vec<_> = contents.iter().map(|s| str_lit(s)).collect();
    emit_array(&mut test, "The tested contents.", "test_contents", "String", &items);
    let letter = |info: Info| -> char {
        let idx = infos.iter().position(|i| *i == info).expect("unknown info");
        (b'a' + idx as u8) as char
    };
    let mut items = vec![];
    for form in [Form::Infix, Form::Prefix, Form::Postfix] {
        for explicit in [false, true] {
            let s: String = contents
                .iter()
                .map(|c| letter(info_of(OperatorInfo::of(c, form, explicit))))
                .collect();
            items.push(format!("({}, {explicit}, {})", form_name(form), str_lit(&s)));
        }
    }
    emit_array(
        &mut test,
        "Expected `OperatorInfo::of` results (as indices into `category_infos`, `a` = 0).",
        "test_infos",
        "(Form, Bool, String)",
        &items,
    );
    let flags = |f: &dyn Fn(&str) -> bool| -> String {
        contents.iter().map(|c| if f(c) { '1' } else { '0' }).collect()
    };
    let axis = |c: &str| {
        let mut chars = c.chars();
        match (chars.next(), chars.next()) {
            (Some(c), None) => is_stretch_axis_inline(c),
            _ => false,
        }
    };
    for (name, s) in [
        ("test_fence", flags(&|c| is_fence(c))),
        ("test_separator", flags(&|c| is_separator(c))),
        ("test_stretch_axis_inline", flags(&axis)),
        ("test_auto_transform", flags(&|c| will_auto_transform(c))),
    ] {
        writeln!(test, "///|\nlet {name} : String = {}\n", str_lit(&s)).unwrap();
    }
    std::fs::write(root.join("html_assets/mathml_gen_wbtest.mbt"), test).unwrap();
}
