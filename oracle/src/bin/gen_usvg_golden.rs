//! Generates the goldens of the `usvg` runner stage (`tests/golden/usvg/`)
//! from the real `usvg` crate (the version typst-library uses).
//!
//! - `trees.jsonl`: every SVG file of `typst-dev-assets` and every case of
//!   `usvg_corpus.txt`, parsed like Typst's `SvgImage::new` (`base_options`)
//!   and written back with `Tree::to_string` (default `WriteOptions`).
//! - `glyphs.jsonl`: every SVG-table glyph of the test fonts, processed like
//!   Typst's `draw_svg_glyph` (`Tree::from_xmltree` with `Options::default()`,
//!   written without indentation) plus the root bounding box.
//!
//! Usage (from `oracle/`):
//! `cargo run --release --bin gen_usvg_golden -- <dev-assets files dir> <out dir>`

use std::io::Read;
use std::path::{Path, PathBuf};

use serde_json::json;

fn base_options() -> usvg::Options<'static> {
    usvg::Options {
        // Disable usvg's default to "Times New Roman".
        font_family: String::new(),
        resources_dir: None,
        image_href_resolver: usvg::ImageHrefResolver {
            resolve_data: usvg::ImageHrefResolver::default_data_resolver(),
            resolve_string: Box::new(|_, _| None),
        },
        ..Default::default()
    }
}

fn bits(x: f32) -> String {
    format!("{:08x}", x.to_bits())
}

fn rect_bits(r: usvg::Rect) -> Vec<String> {
    vec![bits(r.left()), bits(r.top()), bits(r.right()), bits(r.bottom())]
}

fn error_string(e: &usvg::Error) -> String {
    match e {
        usvg::Error::NotAnUtf8Str => "NotAnUtf8Str".into(),
        usvg::Error::MalformedGZip => "MalformedGZip".into(),
        usvg::Error::ElementsLimitReached => "ElementsLimitReached".into(),
        usvg::Error::InvalidSize => "InvalidSize".into(),
        usvg::Error::ParsingFailed(e) => format!("ParsingFailed: {e}"),
    }
}

fn tree_case(name: &str, source: serde_json::Value, data: &[u8]) -> serde_json::Value {
    match usvg::Tree::from_data(data, &base_options()) {
        Ok(tree) => json!({
            "name": name,
            "source": source,
            "size": [bits(tree.size().width()), bits(tree.size().height())],
            "bbox": rect_bits(tree.root().bounding_box()),
            "abs_bbox": rect_bits(tree.root().abs_bounding_box()),
            "stroke_bbox": rect_bits(tree.root().stroke_bounding_box()),
            "svg": tree.to_string(&usvg::WriteOptions::default()),
        }),
        Err(e) => json!({
            "name": name,
            "source": source,
            "error": error_string(&e),
        }),
    }
}

/// Parses `usvg_corpus.txt`: cases separated by `=== name` lines.
fn corpus() -> Vec<(String, String)> {
    parse_cases(include_str!("usvg_corpus.txt"))
}

fn parse_cases(text: &str) -> Vec<(String, String)> {
    let mut cases = Vec::new();
    let mut name: Option<String> = None;
    let mut body = String::new();
    for line in text.lines() {
        if let Some(n) = line.strip_prefix("=== ") {
            if let Some(prev) = name.take() {
                cases.push((prev, std::mem::take(&mut body)));
            }
            name = Some(n.trim().to_string());
        } else if name.is_some() {
            body.push_str(line);
            body.push('\n');
        }
    }
    if let Some(prev) = name {
        cases.push((prev, body));
    }
    cases
}

/// The fonts (of `typst-dev-assets`) loaded for the text cases, in order.
const TEXT_FONTS: &[&str] = &[
    "DejaVuSans.ttf",
    "NotoSans-Regular.ttf",
    "NotoSansArabic-Regular.ttf",
    "NotoSerifHebrew-Regular.ttf",
    "TwitterColorEmoji.ttf",
    "NotoColorEmoji-Regular-COLR.subset.ttf",
    "NotoColorEmoji-Regular-CBDT.subset.ttf",
    "Roboto-Regular.ttf",
    "MonaSansVF[wdth,wght,opsz,ital].ttf",
    "IBMPlexSans-Bold.ttf",
    "IBMPlexSans-Regular.ttf",
];

fn text_corpus() -> Vec<(String, String)> {
    parse_cases(include_str!("usvg_text_corpus.txt"))
}

fn glyph_case(font: &str, face: &ttf_parser::Face, gid: u16) -> Option<serde_json::Value> {
    let glyph_id = ttf_parser::GlyphId(gid);
    let mut data = face.glyph_svg_image(glyph_id)?.data;
    let mut decoded = vec![];
    if data.starts_with(&[0x1f, 0x8b]) {
        let mut decoder = flate2::read::GzDecoder::new(data);
        decoder.read_to_end(&mut decoded).ok()?;
        data = &decoded;
    }
    let result = (|| {
        let xml = std::str::from_utf8(data).ok()?;
        let document = roxmltree::Document::parse(xml).ok()?;
        let opts = usvg::Options::default();
        let tree = usvg::Tree::from_xmltree(&document, &opts).ok()?;
        let svg = tree.to_string(&usvg::WriteOptions {
            indent: usvg::Indent::None,
            attributes_indent: usvg::Indent::None,
            ..Default::default()
        });
        Some((svg, tree.root().bounding_box()))
    })();
    Some(match result {
        Some((svg, bbox)) => json!({
            "font": font,
            "glyph": gid,
            "svg": svg,
            "bbox": rect_bits(bbox),
        }),
        None => json!({ "font": font, "glyph": gid, "error": true }),
    })
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let assets = PathBuf::from(&args[1]);
    let out = PathBuf::from(&args[2]);
    std::fs::create_dir_all(&out).unwrap();

    // Trees.
    let mut lines = Vec::new();
    let mut files: Vec<PathBuf> = Vec::new();
    collect_svgs(&assets, &mut files);
    files.sort();
    for path in files {
        let rel = path.strip_prefix(&assets).unwrap().to_string_lossy().replace('\\', "/");
        let data = std::fs::read(&path).unwrap();
        lines.push(tree_case(&rel, json!({ "file": rel }), &data).to_string());
    }
    for (name, body) in corpus() {
        lines.push(tree_case(&name, json!({ "text": body }), body.as_bytes()).to_string());
    }
    std::fs::write(out.join("trees.jsonl"), lines.join("\n") + "\n").unwrap();

    // Text (with fonts loaded into the font database).
    let mut db = fontdb::Database::new();
    for name in TEXT_FONTS {
        db.load_font_data(std::fs::read(assets.join("fonts").join(name)).unwrap());
    }
    let db = std::sync::Arc::new(db);
    let mut lines = Vec::new();
    for (name, body) in text_corpus() {
        let opts = usvg::Options {
            font_family: "DejaVu Sans".into(),
            fontdb: db.clone(),
            ..base_options()
        };
        let line = match usvg::Tree::from_data(body.as_bytes(), &opts) {
            Ok(tree) => json!({
                "name": name,
                "source": { "text": body },
                "size": [bits(tree.size().width()), bits(tree.size().height())],
                "bbox": rect_bits(tree.root().bounding_box()),
                "abs_bbox": rect_bits(tree.root().abs_bounding_box()),
                "stroke_bbox": rect_bits(tree.root().stroke_bounding_box()),
                "svg": tree.to_string(&usvg::WriteOptions::default()),
                "svg_preserve": tree.to_string(&usvg::WriteOptions {
                    preserve_text: true,
                    ..Default::default()
                }),
            }),
            Err(e) => json!({ "name": name, "source": { "text": body }, "error": error_string(&e) }),
        };
        lines.push(line.to_string());
    }
    std::fs::write(out.join("text.jsonl"), lines.join("\n") + "\n").unwrap();

    // Glyphs.
    let mut lines = Vec::new();
    let mut fonts: Vec<PathBuf> = std::fs::read_dir(assets.join("fonts"))
        .unwrap()
        .map(|e| e.unwrap().path())
        .collect();
    fonts.sort();
    for path in fonts {
        let data = std::fs::read(&path).unwrap();
        let name = path.file_name().unwrap().to_string_lossy().to_string();
        let count = ttf_parser::fonts_in_collection(&data).unwrap_or(1);
        for index in 0..count {
            let Ok(face) = ttf_parser::Face::parse(&data, index) else { continue };
            if face.tables().svg.is_none() {
                continue;
            }
            for gid in 0..face.number_of_glyphs() {
                if let Some(case) = glyph_case(&name, &face, gid) {
                    lines.push(case.to_string());
                }
            }
        }
    }
    std::fs::write(out.join("glyphs.jsonl"), lines.join("\n") + "\n").unwrap();
}

fn collect_svgs(dir: &Path, out: &mut Vec<PathBuf>) {
    for entry in std::fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            collect_svgs(&path, out);
        } else if matches!(
            path.extension().and_then(|e| e.to_str()),
            Some("svg") | Some("svgz")
        ) {
            out.push(path);
        }
    }
}
