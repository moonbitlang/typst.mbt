//! Reference-output generator for typst.mbt.
//!
//! Walks the upstream test suite, splits every file into test cases exactly
//! like `tests/src/collect.rs` + `tests/src/notes.rs` do, and dumps the
//! upstream results so that the MoonBit port can be checked against them
//! without needing Rust at test time.
//!
//! Usage: `typst-oracle syntax <suite-dir> <out-dir>`

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use typst_syntax::{DiagSpanKind, Source, SyntaxDiagnostic};

mod collect;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("syntax") => {
            let suite = PathBuf::from(&args[2]);
            let out = PathBuf::from(&args[3]);
            dump_syntax(&suite, &out);
        }
        Some("parse") => {
            // Debugging aid: parse a single file and print the tree.
            let text = std::fs::read_to_string(&args[2]).unwrap();
            print!("{}", syntax_report(&text));
        }
        _ => {
            eprintln!("usage: typst-oracle syntax <suite-dir> <out-dir>");
            std::process::exit(2);
        }
    }
}

fn dump_syntax(suite: &Path, out: &Path) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&syntax_report(&test.body));
            count += 1;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("dumped {count} test cases");
}

/// The syntax tree (Rust pretty debug format) followed by the diagnostics.
fn syntax_report(text: &str) -> String {
    let source = Source::detached(text);
    let mut out = format!("{:#?}\n", source.root());
    let (errors, warnings) = source.root().errors_and_warnings();
    for diag in errors.iter().chain(&warnings) {
        out.push_str(&diagnostic_line(&source, diag));
    }
    out
}

fn diagnostic_line(source: &Source, diag: &SyntaxDiagnostic) -> String {
    let kind = if diag.is_error { "error" } else { "warning" };
    let mut line = format!(
        "{kind} {} {:?}\n",
        range_of(source, diag.span.get()),
        diag.message.as_str()
    );
    for hint in &diag.hints {
        writeln!(line, "  hint {} {:?}", range_of(source, hint.span.get()), hint.v.as_str())
            .unwrap();
    }
    line
}

fn range_of(source: &Source, kind: DiagSpanKind) -> String {
    match kind {
        DiagSpanKind::Detached => "-".into(),
        DiagSpanKind::Number { num, sub_range, .. } => match source.range(num, sub_range) {
            Some(r) => format!("{}..{}", r.start, r.end),
            None => "?".into(),
        },
        DiagSpanKind::Range { range, .. } => format!("{}..{}", range.start, range.end),
    }
}
