//! Records the output of the real `hayro` renderer (the revision Typst uses,
//! on vello_cpu) for `hayro/render/oracle_test.mbt`.
//!
//! Every page listed in the input file (lines `path<TAB>page[<TAB>scales]`,
//! where page `*` selects the first 4 pages and the optional scales are
//! comma-separated; `#` comments allowed; paths relative to the module root, i.e. through the
//! `target/hayro` and `target/devassets` symlinks) is rendered with Typst's
//! settings (`typst-render`'s `build_pdf_texture`: the Foxit standard fonts
//! of `typst-assets`, no cmaps, no annotations, transparent background) at
//! each of the scales given on the command line (unless the line lists its
//! own), and one TSV line is printed
//! per rendering: `path page scale width height fnv1a64` where the hash is
//! taken over the premultiplied RGBA8 pixels.
//!
//! Set `HAYRO_RENDER_DUMP=<dir>` to also write the raw pixmaps
//! (`<dir>/<file-stem>-<page>-<scale>.rgba`).
//!
//! Usage (in `oracle/`):
//! `cargo run --release --offline --bin gen_hayro_render_tests -- ../hayro/render/testdata/corpus.txt 1 0.37 > ../hayro/render/testdata/expected.tsv`

use std::sync::Arc;

use hayro::hayro_interpret::InterpreterSettings;
use hayro::hayro_interpret::font::{FontData, FontQuery, StandardFont};
use hayro::vello_cpu::color::palette::css::TRANSPARENT;
use hayro::{RenderCache, RenderSettings};
use hayro_syntax::Pdf;

/// FNV-1a (64 bit).
fn fnv(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in data {
        h = (h ^ *b as u64).wrapping_mul(0x100000001b3);
    }
    h
}

fn select_standard_font(font: StandardFont) -> Option<(FontData, u32)> {
    let bytes = match font {
        StandardFont::Helvetica => typst_assets::pdf::SANS,
        StandardFont::HelveticaBold => typst_assets::pdf::SANS_BOLD,
        StandardFont::HelveticaOblique => typst_assets::pdf::SANS_ITALIC,
        StandardFont::HelveticaBoldOblique => typst_assets::pdf::SANS_BOLD_ITALIC,
        StandardFont::Courier => typst_assets::pdf::FIXED,
        StandardFont::CourierBold => typst_assets::pdf::FIXED_BOLD,
        StandardFont::CourierOblique => typst_assets::pdf::FIXED_ITALIC,
        StandardFont::CourierBoldOblique => typst_assets::pdf::FIXED_BOLD_ITALIC,
        StandardFont::TimesRoman => typst_assets::pdf::SERIF,
        StandardFont::TimesBold => typst_assets::pdf::SERIF_BOLD,
        StandardFont::TimesItalic => typst_assets::pdf::SERIF_ITALIC,
        StandardFont::TimesBoldItalic => typst_assets::pdf::SERIF_BOLD_ITALIC,
        StandardFont::ZapfDingBats => typst_assets::pdf::DING_BATS,
        StandardFont::Symbol => typst_assets::pdf::SYMBOL,
    };
    Some((Arc::new(bytes), 0))
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let list = std::fs::read_to_string(&args[1]).unwrap();
    let scales: Vec<String> = args[2..].to_vec();
    let dump = std::env::var("HAYRO_RENDER_DUMP").ok();
    // Paths in the list are relative to the module root (the parent of
    // `oracle/`).
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    println!("# path\tpage\tscale\twidth\theight\tfnv1a64 of the premultiplied RGBA8 pixmap (hayro::render, Typst settings)");
    for line in list.lines() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let mut parts = line.split('\t');
        let path = parts.next().unwrap();
        let page_spec = parts.next().unwrap_or("0");
        // An optional third column overrides the scales (comma-separated).
        let scales: Vec<String> = match parts.next() {
            Some(list) => list.split(',').map(str::to_string).collect(),
            None => scales.clone(),
        };
        let data = std::fs::read(root.join(path)).unwrap();
        let Ok(pdf) = Pdf::new(data) else {
            continue;
        };
        let pages = pdf.pages();
        // `*` selects the first `MAX_PAGES` pages.
        let page_indices: Vec<usize> = if page_spec == "*" {
            (0..pages.len().min(MAX_PAGES)).collect()
        } else {
            vec![page_spec.parse().unwrap()]
        };
        for page in page_indices {
        let Some(page_obj) = pages.get(page) else {
            continue;
        };
        let settings = InterpreterSettings {
            font_resolver: Arc::new(move |query| match query {
                FontQuery::Standard(s) => select_standard_font(*s),
                FontQuery::Fallback(f) => select_standard_font(f.pick_standard_font()),
            }),
            cmap_resolver: Arc::new(|_| None),
            warning_sink: Arc::new(|_| {}),
            render_annotations: false,
        };
        for scale_str in &scales {
            let scale: f32 = scale_str.parse().unwrap();
            let cache = RenderCache::new();
            let render_settings = RenderSettings {
                x_scale: scale,
                y_scale: scale,
                width: None,
                height: None,
                bg_color: TRANSPARENT,
            };
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                hayro::render(page_obj, &cache, &settings, &render_settings)
            }));
            // Pages on which the renderer panics are not recorded.
            let Ok(pix) = result else {
                eprintln!("panic: {path} {page} {scale_str}");
                continue;
            };
            let (w, h) = (pix.width(), pix.height());
            let bytes = pix.data_as_u8_slice();
            if let Some(dir) = &dump {
                let stem = std::path::Path::new(path).file_stem().unwrap().to_string_lossy();
                std::fs::write(format!("{dir}/{stem}-{page}-{scale_str}.rgba"), bytes).unwrap();
            }
            println!("{path}\t{page}\t{scale_str}\t{w}\t{h}\t{:016x}", fnv(bytes));
        }
        }
    }
}

/// The maximum number of pages rendered per file for a `*` page spec.
const MAX_PAGES: usize = 4;
