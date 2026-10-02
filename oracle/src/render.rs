//! The `render` stage: compile every paged test case (same selection as the
//! `paged` stage, see `paged.rs`) and render it like the upstream test
//! harness does (`tests/src/output.rs`, `fn render`): `typst_render::
//! render_merged` at 1 pixel per point with a 1pt black gap between pages,
//! plus the translucent link boxes drawn by `render_links`.
//!
//! # Format
//!
//! Each test case is a `=== <name>` line followed by a single line, either
//! `<width>x<height> <sha256 of the premultiplied RGBA data>` or `<error>` /
//! `<panic>` if compilation (or rendering) failed or panicked.
//!
//! With `ORACLE_RENDER_RAW=<dir>`, the raw premultiplied RGBA data of every
//! rendered test is additionally written to `<dir>/<name>.rgba` (for
//! debugging pixel differences).

use std::fmt::Write as _;
use std::path::Path;

use sha2::{Digest, Sha256};
use tiny_skia as sk;
use typst::diag::Warned;
use typst_layout::PagedDocument;
use typst_library::layout::{Abs, Frame, FrameItem, Transform};
use typst_library::visualize::Color;
use typst_render::{PngFormatOptions, RenderOptions};
use typst_utils::Scalar;

use crate::collect;
use crate::paged::is_paged;
use crate::world::{TestWorld, parse_features};

/// Render every paged test below `suite` (a path relative to the current
/// directory, which must be the upstream checkout).
pub fn dump_render(suite: &Path, out: &Path) {
    let mut count = 0;
    let filter = std::env::var("ORACLE_FILTER").ok();
    let raw = std::env::var("ORACLE_RENDER_RAW").ok();
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
            report.push_str(&render_report(&file, &test, raw.as_deref()));
            count += 1;
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("rendered {count} paged test cases");
}

/// Compile and render a single test case like the upstream harness.
fn render_report(path: &Path, test: &collect::TestCase, raw: Option<&str>) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);

    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let Warned { output, .. } = typst::compile::<PagedDocument>(&world);
        output.ok().map(|doc| render(&doc, 1.0))
    }));
    match result {
        Ok(Some(pixmap)) => {
            if let Some(dir) = raw {
                let dest = Path::new(dir).join(format!("{}.rgba", test.name));
                std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
                std::fs::write(dest, pixmap.data()).unwrap();
            }
            let hash = Sha256::digest(pixmap.data());
            let mut hex = String::new();
            for b in hash {
                write!(hex, "{b:02x}").unwrap();
            }
            format!("{}x{} {}\n", pixmap.width(), pixmap.height(), hex)
        }
        Ok(None) => "<error>\n".into(),
        Err(_) => "<panic>\n".into(),
    }
}

/// Draw all frames into one image with padding in between (upstream
/// `tests/src/output.rs`).
fn render(document: &PagedDocument, pixel_per_pt: f32) -> sk::Pixmap {
    for page in document.pages() {
        let limit = Abs::cm(100.0);
        if page.frame.width() > limit || page.frame.height() > limit {
            panic!("overlarge frame: {:?}", page.frame.size());
        }
    }

    let gap = Abs::pt(1.0);
    let ppi = pixel_per_pt * 72.0;
    let opts = RenderOptions {
        format: PngFormatOptions { ppi: Some(Scalar::new(ppi as f64)) },
        render_bleed: false,
    };
    let mut pixmap = typst_render::render_merged(document, &opts, gap, Some(Color::BLACK));

    let gap = (pixel_per_pt * gap.to_pt() as f32).round();

    let mut y = 0.0;
    for page in document.pages() {
        let ts = sk::Transform::from_scale(pixel_per_pt, pixel_per_pt).post_translate(0.0, y);
        render_links(&mut pixmap, ts, &page.frame);
        y += (pixel_per_pt * page.frame.height().to_pt() as f32).round().max(1.0) + gap;
    }

    pixmap
}

/// Draw extra boxes for links so we can see whether they are there.
fn render_links(canvas: &mut sk::Pixmap, ts: sk::Transform, frame: &Frame) {
    for (pos, item) in frame.items() {
        let ts = ts.pre_translate(pos.x.to_pt() as f32, pos.y.to_pt() as f32);
        match *item {
            FrameItem::Group(ref group) => {
                let ts = ts.pre_concat(to_sk_transform(&group.transform));
                render_links(canvas, ts, &group.frame);
            }
            FrameItem::Link(_, size) => {
                let w = size.x.to_pt() as f32;
                let h = size.y.to_pt() as f32;
                let rect = sk::Rect::from_xywh(0.0, 0.0, w, h).unwrap();
                let mut paint = sk::Paint::default();
                paint.set_color_rgba8(40, 54, 99, 40);
                canvas.fill_rect(rect, &paint, ts, None);
            }
            _ => {}
        }
    }
}

/// Convert a Typst transform to a tiny-skia transform.
fn to_sk_transform(transform: &Transform) -> sk::Transform {
    let Transform { sx, ky, kx, sy, tx, ty } = *transform;
    sk::Transform::from_row(
        sx.get() as f32,
        ky.get() as f32,
        kx.get() as f32,
        sy.get() as f32,
        tx.to_pt() as f32,
        ty.to_pt() as f32,
    )
}
