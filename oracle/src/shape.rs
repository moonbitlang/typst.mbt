//! The `shape` stage: every text run upstream Typst shapes while compiling
//! the paged test suite, with rustybuzz's exact output.
//!
//! The runs are recorded by the rustybuzz tap (`oracle/rustybuzz-tap`, which
//! wraps `shape_with_plan`), deduplicated over the whole suite and written
//! per font to `<out>/<book index>-<postscript name>.txt`, one JSON object
//! per line, sorted by (input, plan):
//!
//! ```text
//! {"font":3,"coords":[],"dir":"ltr","script":"Latn","buffer_script":"Latn","lang":"en",
//!  "features":[["kern",1,0,4294967295]],"flags":8,"cluster_level":0,
//!  "text":"Hello","glyphs":[[gid,cluster,flags,x_advance,y_advance,
//!  x_offset,y_offset],...],"test":"first-test-name"}
//! ```
//!
//! `coords` are the face's normalized variation coordinates (F2DOT14),
//! `script`/`dir`/`lang` the shape plan's parameters (the buffer's direction
//! and language are identical, the dump asserts it; its script is
//! `buffer_script`, after guessing), `features` the plan's user features
//! `[tag, value, start, end]`, `flags` the buffer flags. Clusters of the
//! input are always UTF-8 byte offsets into `text` (asserted). Glyph `flags`
//! are the glyph flags (`UNSAFE_TO_BREAK` = 1, `UNSAFE_TO_CONCAT` = 2,
//! `SAFE_TO_INSERT_TATWEEL` = 4).

use std::collections::{BTreeMap, HashMap};
use std::fmt::Write as _;
use std::path::Path;

use typst::World;
use typst_layout::PagedDocument;

use crate::collect;
use crate::fonts::json_str;
use crate::paged::is_paged;
use crate::world::{TestWorld, parse_features};

fn dir_str(d: rustybuzz::Direction) -> &'static str {
    match d {
        rustybuzz::Direction::Invalid => "invalid",
        rustybuzz::Direction::LeftToRight => "ltr",
        rustybuzz::Direction::RightToLeft => "rtl",
        rustybuzz::Direction::TopToBottom => "ttb",
        rustybuzz::Direction::BottomToTop => "btt",
    }
}

fn tag_str(tag: ttf_parser::Tag) -> String {
    json_str(&String::from_utf8_lossy(&tag.to_bytes()))
}

/// Encode a recorded call (without the test name) as the JSON key/value
/// pairs of one line, and the font index.
fn encode(rec: &rustybuzz::TapRecord, font: usize) -> String {
    assert_eq!(rec.direction, rec.buffer_direction, "plan/buffer direction");
    assert_eq!(rec.language, rec.buffer_language, "plan/buffer language");
    assert!(rec.pre_context.is_empty() && rec.post_context.is_empty());
    let text: String = rec.input.iter().map(|(c, _)| *c).collect();
    let mut offset = 0;
    for (c, cluster) in &rec.input {
        assert_eq!(*cluster as usize, offset, "clusters are byte offsets");
        offset += c.len_utf8();
    }
    let mut s = String::new();
    write!(s, "\"font\":{font},\"coords\":[").unwrap();
    for (i, c) in rec.coords.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        write!(s, "{c}").unwrap();
    }
    write!(s, "],\"dir\":\"{}\",\"script\":", dir_str(rec.direction)).unwrap();
    match rec.script {
        Some(script) => s.push_str(&tag_str(script.tag())),
        None => s.push_str("null"),
    }
    s.push_str(",\"buffer_script\":");
    match rec.buffer_script {
        Some(script) => s.push_str(&tag_str(script.tag())),
        None => s.push_str("null"),
    }
    s.push_str(",\"lang\":");
    match &rec.language {
        Some(lang) => s.push_str(&json_str(lang)),
        None => s.push_str("null"),
    }
    s.push_str(",\"features\":[");
    for (i, f) in rec.features.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        write!(s, "[{},{},{},{}]", tag_str(f.tag), f.value, f.start, f.end).unwrap();
    }
    write!(
        s,
        "],\"flags\":{},\"cluster_level\":{},\"text\":{},\"glyphs\":[",
        rec.flags,
        rec.cluster_level,
        json_str(&text)
    )
    .unwrap();
    for (i, g) in rec.output.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        write!(s, "[{},{},{},{},{},{},{}]", g.0, g.1, g.2, g.3, g.4, g.5, g.6).unwrap();
    }
    s.push(']');
    s
}

/// Compile every paged test below `suite` (relative to the current
/// directory, the upstream checkout) and dump the recorded shaping runs.
pub fn dump_shape(suite: &Path, out: &Path) {
    let filter = std::env::var("ORACLE_FILTER").ok();
    // Font identity by data address (the faces borrow the world's fonts).
    let mut by_addr: HashMap<(usize, usize), usize> = HashMap::new();
    let mut names: Vec<String> = vec![];
    // Encoded call -> first test it occurred in, per font.
    let mut runs: BTreeMap<usize, BTreeMap<String, String>> = BTreeMap::new();
    let mut count = 0;
    let mut calls = 0;
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
        for test in collect::split_tests(&text) {
            if !is_paged(&test.attrs) {
                continue;
            }
            let features = test
                .attrs
                .split_whitespace()
                .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
                .map(parse_features);
            let source = TestWorld::main_source(&file, test.body.clone());
            let world = TestWorld::new(source, features);
            if names.is_empty() {
                let mut i = 0;
                while let Some(font) = world.font(i) {
                    let data = font.data();
                    by_addr.insert((data.as_ptr() as usize, data.len()), i);
                    names.push(
                        font.post_script_name()
                            .map(|n| n.to_string())
                            .unwrap_or_else(|| format!("font{i}")),
                    );
                    i += 1;
                }
            }
            rustybuzz::start_recording();
            let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                typst::compile::<PagedDocument>(&world)
            }));
            let records = rustybuzz::take_records();
            calls += records.len();
            for rec in &records {
                let font = *by_addr.get(&rec.data).expect("shaped face is a world font");
                runs.entry(font)
                    .or_default()
                    .entry(encode(rec, font))
                    .or_insert_with(|| test.name.clone());
            }
            count += 1;
        }
    }
    let _ = std::fs::remove_dir_all(out);
    std::fs::create_dir_all(out).unwrap();
    let mut unique = 0;
    for (font, entries) in &runs {
        let mut report = String::new();
        for (key, test) in entries {
            writeln!(report, "{{{key},\"test\":{}}}", json_str(test)).unwrap();
            unique += 1;
        }
        let name: String = names[*font]
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() || c == '-' { c } else { '_' })
            .collect();
        std::fs::write(out.join(format!("{font:02}-{name}.txt")), report).unwrap();
    }
    eprintln!("compiled {count} paged test cases: {calls} shaping calls, {unique} unique runs");
}
