//! The `svg` stage: compile every paged test case (same selection as the
//! `paged` stage, see `paged.rs`) and dump the SVG that the upstream test
//! harness produces for it (`tests/src/output.rs`, `impl OutputType for
//! Svg`): `typst_svg::svg_merged` with pretty printing and a 1pt gap between
//! pages.
//!
//! # Format
//!
//! Each test case is a `=== <name>` line followed by either the raw SVG
//! (which ends with a newline) or a single `<error>` / `<panic>` line if
//! compilation failed or panicked.
//!
//! The SVG is dumped raw: its `<defs>` IDs contain `hash128` values of
//! upstream's `Hash` impls. The MoonBit runner canonicalizes both sides
//! before comparing them (see `tests/runner/svg_stage.mbt`).

use std::fmt::Write as _;
use std::path::Path;

use typst::diag::Warned;
use typst_layout::PagedDocument;
use typst_library::layout::Abs;
use typst_svg::{SvgFormatOptions, SvgOptions};

use crate::collect;
use crate::paged::is_paged;
use crate::world::{TestWorld, parse_features};

/// Dump SVGs for every paged test below `suite` (a path relative to the
/// current directory, which must be the upstream checkout).
pub fn dump_svg(suite: &Path, out: &Path) {
    let mut count = 0;
    let filter = std::env::var("ORACLE_FILTER").ok();
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        if let Some(f) = &filter
            && !rel.to_string_lossy().contains(f.as_str())
        {
            continue;
        }
        let text = std::fs::read_to_string(&file).unwrap();
        if text.starts_with("// SKIP") {
            continue;
        }
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            if !is_paged(&test.attrs) {
                continue;
            }
            if std::env::var("ORACLE_VERBOSE").is_ok() {
                eprintln!("{} {}", rel.display(), test.name);
            }
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&svg_report(&file, &test));
            count += 1;
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("exported {count} paged test cases to SVG");
}

/// Compile a single test case and export it like the upstream harness.
fn svg_report(path: &Path, test: &collect::TestCase) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);

    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let Warned { output, .. } = typst::compile::<PagedDocument>(&world);
        output.ok().map(|doc| {
            let options = SvgOptions {
                format: SvgFormatOptions { pretty: Some(true) },
                ..Default::default()
            };
            typst_svg::svg_merged(&doc, &options, Abs::pt(1.0))
        })
    }));
    match result {
        Ok(Some(svg)) => svg,
        Ok(None) => "<error>\n".into(),
        Err(_) => "<panic>\n".into(),
    }
}
