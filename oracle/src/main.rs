//! Reference-output generator for typst.mbt.
//!
//! Walks the upstream test suite, splits every file into test cases exactly
//! like `tests/src/collect.rs` + `tests/src/notes.rs` do, and dumps the
//! upstream results so that the MoonBit port can be checked against them
//! without needing Rust at test time.
//!
//! Usage: `typst-oracle <syntax|ast|reparse|eval|html|bundle|realize|paged|svg> <suite-dir> <out-dir>`
//! or `typst-oracle fonts <out-file>`.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use typst_syntax::{DiagSpanKind, Source, SyntaxDiagnostic};

mod ast_dump;
mod breaking;
mod bundle;
mod collect;
mod eval;
mod font;
mod fonts;
mod html;
mod paged;
mod pdf_semantic;
mod pdftags;
mod realize;
mod reparse;
mod shape;
mod svg;
mod usvg_images;
mod world;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("syntax") => {
            let suite = PathBuf::from(&args[2]);
            let out = PathBuf::from(&args[3]);
            dump(&suite, &out, syntax_report);
        }
        Some("ast") => {
            let suite = PathBuf::from(&args[2]);
            let out = PathBuf::from(&args[3]);
            dump(&suite, &out, ast_dump::ast_report);
        }
        Some("reparse") => {
            let suite = PathBuf::from(&args[2]);
            let out = PathBuf::from(&args[3]);
            dump(&suite, &out, reparse::reparse_report);
        }
        Some("eval") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap();
            eval::dump_eval(rel, &out);
        }
        Some("html") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap();
            html::dump_html(rel, &out);
        }
        Some("bundle") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap().to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || bundle::dump_bundle(&rel, &out))
                .unwrap()
                .join()
                .unwrap();
        }
        Some("realize") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap();
            let rel = rel.to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || realize::dump_realize(&rel, &out))
                .unwrap()
                .join()
                .unwrap();
        }
        Some("font") => {
            // Only the output directory is used.
            let out = PathBuf::from(&args[3]);
            font::dump_font(&out);
        }
        Some("fonts") => {
            // The font manifest of the test world: `fonts <out-file>`.
            let out = PathBuf::from(&args[2]);
            std::fs::create_dir_all(out.parent().unwrap()).unwrap();
            std::fs::write(&out, fonts::manifest()).unwrap();
        }
        Some("paged") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let revision = std::fs::read_to_string("UPSTREAM_REV").unwrap().trim().to_string();
            let manifest_sha = fonts::sha256_hex(fonts::manifest().as_bytes());
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap().to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || paged::dump_paged(&rel, &out, &revision, &manifest_sha))
                .unwrap()
                .join()
                .unwrap();
        }
        Some("shape") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap().to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || shape::dump_shape(&rel, &out))
                .unwrap()
                .join()
                .unwrap();
        }
        Some("usvg-images") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap().to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || usvg_images::dump_usvg_images(&rel, &out))
                .unwrap()
                .join()
                .unwrap();
        }
        Some("svg") => {
            // Paths are resolved relative to the upstream checkout.
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap().to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || svg::dump_svg(&rel, &out))
                .unwrap()
                .join()
                .unwrap();
        }
        Some(stage @ ("pdf-semantic" | "pdftags")) => {
            // Paths are resolved relative to the upstream checkout.
            let kind = if stage == "pdftags" {
                pdf_semantic::Kind::Tags
            } else {
                pdf_semantic::Kind::Semantic
            };
            let suite = PathBuf::from(&args[2]);
            let out = std::path::absolute(PathBuf::from(&args[3])).unwrap();
            let upstream = std::path::absolute(&suite).unwrap();
            let root = upstream.ancestors().nth(2).unwrap().to_path_buf();
            std::env::set_current_dir(&root).unwrap();
            let rel = upstream.strip_prefix(&root).unwrap().to_path_buf();
            std::thread::Builder::new()
                .stack_size(1 << 30)
                .spawn(move || pdf_semantic::dump_pdf(&rel, &out, kind))
                .unwrap()
                .join()
                .unwrap();
        }
        Some("pdf-extract") => {
            // Debugging aid: dump the semantics of a PDF file.
            let bytes = std::fs::read(&args[2]).unwrap();
            match pdf_semantic::extract(&bytes) {
                Ok(s) => print!("{s}"),
                Err(e) => println!("<extract-error {e:?}>"),
            }
        }
        Some("pdftags-file") => {
            // Debugging aid: format the tag tree of a PDF file.
            let bytes = std::fs::read(&args[2]).unwrap();
            match pdftags::format(&bytes) {
                Ok(s) => print!("{s}"),
                Err(e) => println!("<extract-error {e:?}>"),
            }
        }
        Some("break") => {
            let suite = PathBuf::from(&args[2]);
            let out = PathBuf::from(&args[3]);
            breaking::dump_break(&suite, &out);
        }
        Some("parse") => {
            // Debugging aid: parse a single file and print the tree.
            let text = std::fs::read_to_string(&args[2]).unwrap();
            print!("{}", syntax_report(&text));
        }
        Some("reparse-file") => {
            // Debugging aid: dump the reparse stage for a single file.
            let text = std::fs::read_to_string(&args[2]).unwrap();
            print!("{}", reparse::reparse_report(&text));
        }
        Some("reparse-edit") => {
            // Debugging aid: `reparse-edit <text> <start> <end> <with>` prints
            // the reparsed range of a single edit (or `All`).
            let mut source = Source::detached(args[2].as_str());
            let range = source.edit(
                args[3].parse().unwrap()..args[4].parse().unwrap(),
                &args[5],
            );
            if range == (0..source.text().len()) {
                println!("All");
            } else {
                println!("Incr({:?})", &source.text()[range]);
            }
        }
        Some("ast-file") => {
            // Debugging aid: dump the AST stage for a single file.
            let text = std::fs::read_to_string(&args[2]).unwrap();
            print!("{}", ast_dump::ast_report(&text));
        }
        _ => {
            eprintln!(
                "usage: typst-oracle <syntax|ast|reparse|eval|html|bundle|realize|paged|svg|usvg-images|shape|break> <suite-dir> <out-dir>\n       typst-oracle fonts <out-file>"
            );
            std::process::exit(2);
        }
    }
}

fn dump(suite: &Path, out: &Path, report_fn: fn(&str) -> String) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&report_fn(&test.body));
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
