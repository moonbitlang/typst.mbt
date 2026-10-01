//! The `html` stage: compile every test case with the `html` target to an
//! `HtmlDocument` like the upstream test runner does (`tests/src/run.rs`) and
//! dump the encoded HTML (pretty-printed, as in `tests/src/output.rs`) or the
//! errors, followed by the warnings.

use std::fmt::Write as _;
use std::path::Path;

use typst::World;
use typst::diag::Warned;
use typst_html::{HtmlDocument, HtmlFormatOptions, HtmlOptions};

use crate::collect;
use crate::eval::write_diag;
use crate::world::{TestWorld, parse_features};

/// Dump HTML results for every `html` test below `suite` (a path relative to
/// the current directory, which must be the upstream checkout).
pub fn dump_html(suite: &Path, out: &Path) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            if !test.attrs.split_whitespace().any(|a| a == "html") {
                continue;
            }
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&html_report(&file, &test));
            count += 1;
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("compiled {count} html test cases");
}

/// Compile a single test case to HTML.
pub fn html_report(path: &Path, test: &collect::TestCase) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);
    let main_id = world.main();

    let Warned { output, mut warnings } = typst::compile::<HtmlDocument>(&world);
    let mut out = String::new();
    match output {
        Ok(doc) => {
            let options =
                HtmlOptions { format: HtmlFormatOptions { pretty: Some(true) } };
            match typst_html::html(&doc, &options) {
                Ok(html) => {
                    out.push_str("ok\n");
                    out.push_str(&html);
                    if !html.ends_with('\n') {
                        out.push('\n');
                    }
                }
                Err(errors) => {
                    out.push_str("err\n");
                    for diag in crate::eval::deduplicate(errors) {
                        write_diag(&mut out, &world, main_id, &diag);
                    }
                }
            }
        }
        Err(errors) => {
            out.push_str("err\n");
            for diag in &errors {
                write_diag(&mut out, &world, main_id, diag);
            }
        }
    }
    warnings = crate::eval::deduplicate(warnings);
    for diag in &warnings {
        write_diag(&mut out, &world, main_id, diag);
    }
    out
}
