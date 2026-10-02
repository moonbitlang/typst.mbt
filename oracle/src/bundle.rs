//! The `bundle` stage: compile every test case with the `bundle` target to a
//! `Bundle` like the upstream test runner does (`tests/src/run.rs`) and export
//! it into a virtual file system with the options of `tests/src/output.rs`
//! (`impl OutputType for Bundle`).
//!
//! # Format
//!
//! Each test case is a `=== <name>` line followed by either
//!
//! - `ok` and, for every file of the exported bundle (in bundle order), a
//!   header line `--- <path> (<kind>, <size> bytes, sha256 <hex>)` where
//!   `<kind>` is `html`, `pdf`, `png`, or `svg` for documents and `asset` for
//!   assets. For HTML and SVG documents, and for assets whose bytes are valid
//!   UTF-8, the header is followed by the full text (with a newline appended if
//!   it does not end with one).
//! - `err` and the (deduplicated) errors of compilation or export,
//!
//! followed by the (deduplicated) warnings of compilation and export.

use std::fmt::Write as _;
use std::path::Path;

use ecow::EcoVec;
use typst::World;
use typst::diag::{SourceDiagnostic, Warned};
use typst_bundle::{Bundle, BundleDocument, BundleFile, BundleOptions};
use typst_html::{HtmlFormatOptions, HtmlOptions};
use typst_library::foundations::Smart;
use typst_utils::Scalar;
use typst_library::model::PagedFormat;
use typst_pdf::{PdfFormatOptions, PdfOptions};
use typst_render::{PngFormatOptions, RenderOptions};
use typst_svg::{SvgFormatOptions, SvgOptions};

use crate::collect;
use crate::eval::{deduplicate, write_diag};
use crate::fonts::sha256_hex;
use crate::world::{TestWorld, parse_features};

/// Dump bundle results for every `bundle` test below `suite` (a path relative
/// to the current directory, which must be the upstream checkout).
pub fn dump_bundle(suite: &Path, out: &Path) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            if !test.attrs.split_whitespace().any(|a| a == "bundle") {
                continue;
            }
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&bundle_report(&file, &test));
            count += 1;
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("compiled {count} bundle test cases");
}

/// The export options of the upstream test runner.
fn options() -> BundleOptions {
    BundleOptions {
        html: HtmlOptions { format: HtmlFormatOptions { pretty: Some(true) } },
        pdf: PdfOptions {
            creator: Smart::Custom(Some("Typst Test Runner".into())),
            format: PdfFormatOptions { standard: None, ..Default::default() },
            ..Default::default()
        },
        png: RenderOptions {
            format: PngFormatOptions { ppi: Some(Scalar::new(72.0)) },
            ..Default::default()
        },
        svg: SvgOptions {
            format: SvgFormatOptions { pretty: Some(true) },
            ..Default::default()
        },
    }
}

/// Compile a single test case to a bundle and export it.
pub fn bundle_report(path: &Path, test: &collect::TestCase) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);
    let main_id = world.main();

    let Warned { output, warnings } = typst::compile::<Bundle>(&world);
    let mut warnings: EcoVec<SourceDiagnostic> = warnings;
    let mut out = String::new();
    match output {
        Ok(bundle) => {
            let Warned { output, warnings: export_warnings } =
                typst_bundle::export(&bundle, &options());
            warnings.extend(export_warnings);
            match output {
                Ok(fs) => {
                    out.push_str("ok\n");
                    for (path, data) in &fs {
                        let kind = match bundle.files.get(path) {
                            Some(BundleFile::Asset(_)) => "asset",
                            Some(BundleFile::Document(BundleDocument::Html(_))) => "html",
                            Some(BundleFile::Document(BundleDocument::Paged(_, extras))) => {
                                match extras.format {
                                    PagedFormat::Pdf => "pdf",
                                    PagedFormat::Png => "png",
                                    PagedFormat::Svg => "svg",
                                }
                            }
                            None => "?",
                        };
                        let bytes = data.as_slice();
                        writeln!(
                            out,
                            "--- {} ({kind}, {} bytes, sha256 {})",
                            path.get_without_slash(),
                            bytes.len(),
                            sha256_hex(bytes),
                        )
                        .unwrap();
                        let text = match kind {
                            "html" | "svg" | "asset" => std::str::from_utf8(bytes).ok(),
                            _ => None,
                        };
                        if let Some(text) = text {
                            out.push_str(text);
                            if !text.ends_with('\n') {
                                out.push('\n');
                            }
                        }
                    }
                }
                Err(errors) => {
                    out.push_str("err\n");
                    for diag in deduplicate(errors) {
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
    warnings = deduplicate(warnings);
    for diag in &warnings {
        write_diag(&mut out, &world, main_id, diag);
    }
    out
}
