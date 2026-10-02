//! Generates the goldens of the `resvg` runner stage (`tests/golden/resvg/`)
//! from the real `resvg` crate (the version typst-render uses), over resvg's
//! own regression suite (`.repos/resvg/crates/resvg/tests`, fetched by
//! `scripts/upstream.sh`).
//!
//! Every case is rendered like resvg's integration tests
//! (`tests/integration/main.rs`): the fonts of `tests/fonts` with the same
//! generic families, `resources_dir` = the directory of the SVG file, and
//!
//! - `normal`: every test of `integration/render.rs`, scaled to a width of
//!   300px;
//! - `extra`: the `render_extra[_with_scale]` tests of `integration/extra.rs`;
//! - `node`: the `render_node` tests of `integration/extra.rs`.
//!
//! `cases.jsonl` holds one object per case: `name` (path without `.svg`,
//! relative to the tests directory), `mode`, `scale`/`id` when relevant, and
//! either `size` + `sha256` (of the premultiplied RGBA pixmap data), `none`
//! (rendering produced no pixmap) or `error` (usvg parse error).
//!
//! Usage (from `oracle/`):
//! `cargo run --release --bin gen_resvg_golden -- <resvg tests dir> <out dir> [filter]`
//! With `RESVG_RAW=<dir>`, the raw RGBA of every case is written there.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use serde_json::json;
use sha2::{Digest, Sha256};

const IMAGE_SIZE: u32 = 300;

/// Fonts of `tests/fonts`, loaded in sorted file name order.
fn fontdb(tests: &Path) -> Arc<fontdb::Database> {
    let mut db = fontdb::Database::new();
    let mut files: Vec<PathBuf> = std::fs::read_dir(tests.join("fonts"))
        .unwrap()
        .map(|e| e.unwrap().path())
        .filter(|p| {
            matches!(
                p.extension().and_then(|e| e.to_str()),
                Some("ttf" | "otf" | "ttc" | "otc")
            )
        })
        .collect();
    files.sort();
    for f in files {
        db.load_font_data(std::fs::read(f).unwrap());
    }
    db.set_serif_family("Noto Serif");
    db.set_sans_serif_family("Noto Sans");
    db.set_cursive_family("Yellowtail");
    db.set_fantasy_family("Sedgwick Ave Display");
    db.set_monospace_family("Noto Mono");
    Arc::new(db)
}

enum Mode {
    Normal,
    Extra(f32),
    Node(String),
}

/// Extracts the string literals of `func("...")`-style calls.
fn cases(tests: &Path) -> Vec<(String, Mode)> {
    let mut out = Vec::new();
    let render = std::fs::read_to_string(tests.join("integration/render.rs")).unwrap();
    for line in render.lines() {
        if let Some(i) = line.find("render(\"") {
            let rest = &line[i + 8..];
            let name = &rest[..rest.find('"').unwrap()];
            out.push((name.to_string(), Mode::Normal));
        }
    }
    let extra = std::fs::read_to_string(tests.join("integration/extra.rs")).unwrap();
    // Calls may span lines: join and scan.
    let extra: String = extra.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut rest = extra.as_str();
    while let Some(i) = rest.find("render_") {
        rest = &rest[i..];
        let call_end = rest.find(')').unwrap();
        let call = &rest[..call_end];
        let args: Vec<&str> = call[call.find('(').unwrap() + 1..]
            .split(',')
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .collect();
        let unq = |s: &str| s.trim_matches('"').to_string();
        if call.starts_with("render_extra_with_scale(") {
            out.push((unq(args[0]), Mode::Extra(args[1].parse().unwrap())));
        } else if call.starts_with("render_extra(") {
            out.push((unq(args[0]), Mode::Extra(1.0)));
        } else if call.starts_with("render_node(") {
            out.push((unq(args[0]), Mode::Node(unq(args[1]))));
        }
        rest = &rest[call_end..];
    }
    out
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let tests = PathBuf::from(&args[1]);
    let out_dir = PathBuf::from(&args[2]);
    let filter = args.get(3).cloned();
    let raw = std::env::var("RESVG_RAW").ok().map(PathBuf::from);
    std::fs::create_dir_all(&out_dir).unwrap();
    let db = fontdb(&tests);

    let mut lines = Vec::new();
    for (name, mode) in cases(&tests) {
        if let Some(f) = &filter {
            if !name.contains(f.as_str()) {
                continue;
            }
        }
        let svg_path = tests.join(format!("{name}.svg"));
        let opt = usvg::Options {
            fontdb: db.clone(),
            resources_dir: Some(svg_path.parent().unwrap().to_owned()),
            ..usvg::Options::default()
        };
        let mut obj = match &mode {
            Mode::Normal => json!({ "name": name, "mode": "normal" }),
            Mode::Extra(s) => json!({ "name": name, "mode": "extra", "scale": s }),
            Mode::Node(id) => json!({ "name": name, "mode": "node", "id": id }),
        };
        let data = std::fs::read(&svg_path).unwrap();
        let tree = match usvg::Tree::from_data(&data, &opt) {
            Ok(tree) => tree,
            Err(e) => {
                obj["error"] = json!(e.to_string());
                lines.push(obj.to_string());
                continue;
            }
        };
        let pixmap = match &mode {
            Mode::Normal => tree
                .size()
                .to_int_size()
                .scale_to_width(IMAGE_SIZE)
                .and_then(|size| {
                    let mut pixmap = tiny_skia::Pixmap::new(size.width(), size.height())?;
                    let ts = tiny_skia::Transform::from_scale(
                        size.width() as f32 / tree.size().width() as f32,
                        size.height() as f32 / tree.size().height() as f32,
                    );
                    resvg::render(&tree, ts, &mut pixmap.as_mut());
                    Some(pixmap)
                }),
            Mode::Extra(scale) => tree.size().to_int_size().scale_by(*scale).and_then(|size| {
                let mut pixmap = tiny_skia::Pixmap::new(size.width(), size.height())?;
                let ts = tiny_skia::Transform::from_scale(*scale, *scale);
                resvg::render(&tree, ts, &mut pixmap.as_mut());
                Some(pixmap)
            }),
            Mode::Node(id) => tree.node_by_id(id).and_then(|node| {
                let size = node.abs_layer_bounding_box()?.size().to_int_size();
                let mut pixmap = tiny_skia::Pixmap::new(size.width(), size.height())?;
                resvg::render_node(node, tiny_skia::Transform::identity(), &mut pixmap.as_mut());
                Some(pixmap)
            }),
        };
        match pixmap {
            Some(pixmap) => {
                obj["size"] = json!([pixmap.width(), pixmap.height()]);
                obj["sha256"] = json!(format!("{:x}", Sha256::digest(pixmap.data())));
                if let Some(dir) = &raw {
                    let file = dir.join(format!("{}.rgba", name.replace('/', "_")));
                    std::fs::create_dir_all(dir).unwrap();
                    std::fs::write(file, pixmap.data()).unwrap();
                }
            }
            None => obj["none"] = json!(true),
        }
        lines.push(obj.to_string());
    }
    let mut text = lines.join("\n");
    text.push('\n');
    std::fs::write(out_dir.join("cases.jsonl"), text).unwrap();
    eprintln!("resvg: {} cases", lines.len());
}
