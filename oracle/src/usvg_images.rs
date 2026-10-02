//! The `usvg-images` stage: compile every paged test case and dump the usvg
//! tree (`Tree::to_string` with default `WriteOptions`) of every SVG image
//! placed in the document, in placement order (each distinct tree once).
//!
//! This checks `SvgImage::with_fonts_images` (Typst's font resolver for
//! `<text>` in SVG images and its linked image resolver) beyond the image
//! size the `paged` stage records.
//!
//! Format: `=== <test name>` followed by one `--- svg <data sha256>` line and
//! the written tree per image.

use std::fmt::Write as _;
use std::path::Path;

use typst::layout::{Frame, FrameItem};
use typst::visualize::ImageKind;
use typst_layout::PagedDocument;

use crate::collect;
use crate::fonts::sha256_hex;
use crate::paged::is_paged;
use crate::world::{TestWorld, parse_features};

/// Dump the SVG image trees of every paged test below `suite`.
pub fn dump_usvg_images(suite: &Path, out: &Path) {
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
            let entries = test_report(&file, &test);
            if entries.is_empty() {
                continue;
            }
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&entries);
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
}

fn test_report(path: &Path, test: &collect::TestCase) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        typst::compile::<PagedDocument>(&world)
    }));
    let Ok(warned) = result else { return String::new() };
    let Ok(doc) = warned.output else { return String::new() };
    let mut seen: Vec<String> = vec![];
    let mut out = String::new();
    for page in doc.pages() {
        walk(&page.frame, &mut seen, &mut out);
    }
    out
}

fn walk(frame: &Frame, seen: &mut Vec<String>, out: &mut String) {
    for (_, item) in frame.items() {
        match item {
            FrameItem::Group(group) => walk(&group.frame, seen, out),
            FrameItem::Image(image, _, _) => {
                if let ImageKind::Svg(svg) = image.kind() {
                    let tree = svg.tree().to_string(&usvg::WriteOptions::default());
                    let entry =
                        format!("--- svg {}\n{}\n", sha256_hex(svg.data().as_slice()), tree);
                    if !seen.contains(&entry) {
                        out.push_str(&entry);
                        seen.push(entry);
                    }
                }
            }
            _ => {}
        }
    }
}
