//! The `break` stage: bidi levels/runs, line break opportunities (ICU and
//! Typst's `breakpoints`), word bounds and hyphenation for
//!
//! - every paragraph (`\n\n`-separated chunk) of every test body of the
//!   suite (`<suite path>.txt`), and
//! - conformance corpora (`@corpus/*.txt`): the line/word break test files
//!   shipped with `icu_segmenter` and, if available (`BIDI_TEST_DATA`), the
//!   Unicode `BidiTest.txt` / `BidiCharacterTest.txt` files.
//!
//! Every record contains its input, so the MoonBit runner recomputes each
//! record from the golden alone. Record kinds:
//!
//! - `text: <hex code points>`: full paragraph report (see `text_report`),
//! - `line: <hex>`: ICU line break opportunities,
//! - `word: <hex>`: word bounds,
//! - `bidi: <ltr|rtl|auto> <hex>`: compact bidi report.
//!
//! The MoonBit port of the formatting is `tests/runner/break_stage.mbt`.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};
use std::sync::LazyLock;

use icu_properties::CodePointMapDataBorrowed;
use icu_properties::props::LineBreak;
use icu_provider_blob::BlobDataProvider;
use icu_segmenter::options::LineBreakOptions;
use icu_segmenter::{LineSegmenter, LineSegmenterBorrowed};
use unicode_bidi::{BidiInfo, Level};
use unicode_segmentation::UnicodeSegmentation;

use crate::collect;

static SEGMENTER: LazyLock<LineSegmenterBorrowed> =
    LazyLock::new(|| LineSegmenter::new_lstm(LineBreakOptions::default()));

static CJ_SEGMENTER: LazyLock<LineSegmenter> = LazyLock::new(|| {
    let blob = typst_assets::icu::ICU_CJ_SEGMENT;
    let cj_provider = BlobDataProvider::try_new_from_static_blob(blob).unwrap();
    LineSegmenter::try_new_for_non_complex_scripts_with_buffer_provider(
        &cj_provider,
        LineBreakOptions::default(),
    )
    .unwrap()
});

const LINEBREAK_DATA: CodePointMapDataBorrowed<LineBreak> = CodePointMapDataBorrowed::new();

pub fn dump_break(suite: &Path, out: &Path) {
    let mut count = 0;
    for file in collect::typ_files(suite) {
        let rel = file.strip_prefix(suite).unwrap();
        let text = std::fs::read_to_string(&file).unwrap();
        let mut report = String::new();
        for test in collect::split_tests(&text) {
            writeln!(report, "=== {}", test.name).unwrap();
            report.push_str(&body_report(&test.body));
            count += 1;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("dumped {count} test cases");

    // Conformance corpora.
    let corpus = out.join("@corpus");
    std::fs::create_dir_all(&corpus).unwrap();
    let icu = registry_crate("icu_segmenter-2.3.0").join("tests/testdata");
    for name in [
        "LineBreakTest_15.1",
        "LineBreakExtraTest_15.1",
        "LineBreakRandomTest_15.1",
        "LineBreakTest",
        "LineBreakExtraTest",
    ] {
        let rows = break_test_rows(&icu.join(format!("{name}.txt")));
        write_corpus(&corpus.join(format!("{name}.txt")), name, &rows, |cps| {
            format!("line: {}\n{}", hex(cps), line_report(&string(cps)))
        });
    }
    let rows = break_test_rows(&icu.join("WordBreakTest.txt"));
    write_corpus(&corpus.join("WordBreakTest.txt"), "WordBreakTest", &rows, |cps| {
        format!("word: {}\n{}", hex(cps), word_report(&string(cps)))
    });

    if let Some(dir) = std::env::var_os("BIDI_TEST_DATA").map(PathBuf::from) {
        let path = dir.join("BidiCharacterTest.txt");
        if path.exists() {
            let rows = bidi_character_rows(&path);
            write_corpus(&corpus.join("BidiCharacterTest.txt"), "BidiCharacterTest", &rows, |r| {
                bidi_record(&r.0, &r.1)
            });
        }
        let path = dir.join("BidiTest.txt");
        if path.exists() {
            let rows = bidi_test_rows(&path);
            write_corpus(&corpus.join("BidiTest.txt"), "BidiTest", &rows, |r| {
                bidi_record(&r.0, &r.1)
            });
        }
    } else {
        eprintln!("BIDI_TEST_DATA not set; skipping the bidi conformance corpora");
    }
}

/// Locate a crate in the cargo registry.
fn registry_crate(name: &str) -> PathBuf {
    let home = std::env::var_os("CARGO_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap()).join(".cargo"));
    for entry in std::fs::read_dir(home.join("registry/src")).unwrap() {
        let dir = entry.unwrap().path().join(name);
        if dir.exists() {
            return dir;
        }
    }
    panic!("crate {name} not found in the cargo registry");
}

/// Write records in sections of 100.
fn write_corpus<T>(path: &Path, name: &str, rows: &[T], f: impl Fn(&T) -> String) {
    let mut report = String::new();
    for (k, chunk) in rows.chunks(100).enumerate() {
        writeln!(report, "=== {name}#{k}").unwrap();
        for row in chunk {
            report.push_str(&f(row));
        }
    }
    std::fs::write(path, report).unwrap();
    eprintln!("dumped {} rows of {name}", rows.len());
}

/// The code point sequences of a `÷ 0041 × 0042 ÷` style test file.
fn break_test_rows(path: &Path) -> Vec<Vec<u32>> {
    let text = std::fs::read_to_string(path).unwrap();
    let mut rows = Vec::new();
    for line in text.split('\n') {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let data = line.split('#').next().unwrap();
        let cps: Vec<u32> = data
            .split_ascii_whitespace()
            .enumerate()
            .filter(|(i, _)| i % 2 == 1)
            .map(|(_, h)| u32::from_str_radix(h, 16).unwrap())
            .collect();
        rows.push(cps);
    }
    rows
}

/// `(code points, direction)` rows of `BidiCharacterTest.txt`.
fn bidi_character_rows(path: &Path) -> Vec<(Vec<u32>, String)> {
    let text = std::fs::read_to_string(path).unwrap();
    let mut rows = Vec::new();
    for line in text.lines() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let mut fields = line.split(';');
        let cps = fields
            .next()
            .unwrap()
            .split_ascii_whitespace()
            .map(|h| u32::from_str_radix(h, 16).unwrap())
            .collect();
        let dir = match fields.next().unwrap().trim() {
            "0" => "ltr",
            "1" => "rtl",
            _ => "auto",
        };
        rows.push((cps, dir.to_string()));
    }
    rows
}

/// A representative character for each bidi class (for `BidiTest.txt`).
fn class_char(class: &str) -> u32 {
    match class {
        "L" => 0x61,
        "R" => 0x5D0,
        "AL" => 0x627,
        "EN" => 0x30,
        "ES" => 0x2B,
        "ET" => 0x23,
        "AN" => 0x660,
        "CS" => 0x2C,
        "NSM" => 0x300,
        "BN" => 0xAD,
        "B" => 0x2029,
        "S" => 0x09,
        "WS" => 0x20,
        "ON" => 0x21,
        "LRE" => 0x202A,
        "RLE" => 0x202B,
        "PDF" => 0x202C,
        "LRO" => 0x202D,
        "RLO" => 0x202E,
        "LRI" => 0x2066,
        "RLI" => 0x2067,
        "FSI" => 0x2068,
        "PDI" => 0x2069,
        other => panic!("unknown bidi class {other}"),
    }
}

/// `(code points, direction)` rows of `BidiTest.txt` (one per bit of the
/// paragraph level bitset).
fn bidi_test_rows(path: &Path) -> Vec<(Vec<u32>, String)> {
    let text = std::fs::read_to_string(path).unwrap();
    let mut rows = Vec::new();
    for line in text.lines() {
        if line.is_empty() || line.starts_with('#') || line.starts_with('@') {
            continue;
        }
        let (classes, bits) = line.split_once(';').unwrap();
        let cps: Vec<u32> = classes.split_ascii_whitespace().map(class_char).collect();
        let bits: u32 = bits.trim().parse().unwrap();
        for (bit, dir) in [(1, "auto"), (2, "ltr"), (4, "rtl")] {
            if bits & bit != 0 {
                rows.push((cps.clone(), dir.to_string()));
            }
        }
    }
    rows
}

fn string(cps: &[u32]) -> String {
    cps.iter().map(|&c| char::from_u32(c).unwrap()).collect()
}

fn hex(cps: &[u32]) -> String {
    cps.iter().map(|c| format!("{c:04X}")).collect::<Vec<_>>().join(" ")
}

fn hex_str(s: &str) -> String {
    hex(&s.chars().map(|c| c as u32).collect::<Vec<_>>())
}

fn join<T: std::fmt::Display>(v: impl IntoIterator<Item = T>) -> String {
    v.into_iter().map(|x| x.to_string()).collect::<Vec<_>>().join(" ")
}

/// The test body's language (first `lang: "xx"`), defaulting to English.
fn body_lang(body: &str) -> String {
    let mut rest = body;
    while let Some(i) = rest.find("lang: \"") {
        let code = &rest[i + 7..];
        if code.len() >= 3
            && code.as_bytes()[2] == b'"'
            && code[..2].bytes().all(|b| b.is_ascii_lowercase())
        {
            return code[..2].to_string();
        }
        rest = &rest[i + 7..];
    }
    "en".into()
}

fn body_report(body: &str) -> String {
    let lang = body_lang(body);
    let mut out = format!("lang: {lang}\n");
    for para in body.split("\n\n") {
        if para.trim().is_empty() {
            continue;
        }
        writeln!(out, "text: {}", hex_str(para)).unwrap();
        out.push_str(&text_report(para, &lang));
    }
    out
}

/// The ICU line break opportunities with both segmenters.
fn line_report(text: &str) -> String {
    format!(
        "lb: {}\nlb-cj: {}\n",
        join(SEGMENTER.segment_str(text)),
        join(CJ_SEGMENTER.as_borrowed().segment_str(text))
    )
}

/// The UTF-8 lengths of the word bounds.
fn word_report(text: &str) -> String {
    format!("words: {}\n", join(text.split_word_bounds().map(str::len)))
}

/// The full report of one paragraph.
fn text_report(text: &str, lang: &str) -> String {
    let mut out = line_report(text);
    out.push_str(&word_report(text));
    let hlang = hypher::Lang::from_iso(lang.as_bytes().try_into().unwrap());

    // Hyphenation of every alphabetic word-bound segment.
    if let Some(hlang) = hlang {
        let words: Vec<String> = text
            .split_word_bounds()
            .filter(|s| !s.is_empty() && s.chars().all(char::is_alphabetic))
            .map(|w| hypher::hyphenate(w, hlang).collect::<Vec<_>>().join("|"))
            .collect();
        writeln!(out, "hyph: {}", words.join(" ")).unwrap();
    }

    // Typst's breakpoints.
    for (label, cj) in [("bp", false), ("bp-cj", true)] {
        let mut points = Vec::new();
        breakpoints(text, cj, true, hlang, |_| true, |i, bp| {
            points.push(match bp {
                Breakpoint::Normal => format!("{i}"),
                Breakpoint::Mandatory => format!("{i}m"),
                Breakpoint::Hyphen(l, r) => format!("{i}h{l},{r}"),
            })
        });
        writeln!(out, "{label}: {}", points.join(" ")).unwrap();
    }

    // Bidi.
    let lb: Vec<usize> = SEGMENTER.segment_str(text).collect();
    for (label, level) in
        [("ltr", Some(Level::ltr())), ("rtl", Some(Level::rtl())), ("auto", None)]
    {
        let bidi = BidiInfo::new(text, level);
        writeln!(out, "bidi-{label}: {}", bidi_summary(&bidi)).unwrap();
        for para in &bidi.paragraphs {
            writeln!(out, "  para {}", runs_report(&bidi, para, para.range.clone())).unwrap();
        }
        if bidi.has_rtl() {
            // Lines between consecutive line break opportunities.
            for w in lb.windows(2) {
                let (a, b) = (w[0], w[1]);
                let Some(para) = bidi.paragraphs.iter().find(|p| p.range.contains(&a))
                else {
                    continue;
                };
                writeln!(out, "  line {}", runs_report(&bidi, para, a..b)).unwrap();
            }
        }
    }
    out
}

/// Paragraphs and run-length encoded byte levels.
fn bidi_summary(bidi: &BidiInfo) -> String {
    let paras = join(
        bidi.paragraphs
            .iter()
            .map(|p| format!("{}..{}@{}", p.range.start, p.range.end, p.level.number())),
    );
    format!("paras {paras} levels {}", rle(&bidi.levels))
}

fn rle(levels: &[Level]) -> String {
    let mut out: Vec<(u8, usize)> = Vec::new();
    for l in levels {
        match out.last_mut() {
            Some((v, n)) if *v == l.number() => *n += 1,
            _ => out.push((l.number(), 1)),
        }
    }
    join(out.iter().map(|(v, n)| format!("{v}x{n}")))
}

/// The visual runs of a line.
fn runs_report(
    bidi: &BidiInfo,
    para: &unicode_bidi::ParagraphInfo,
    line: std::ops::Range<usize>,
) -> String {
    let (levels, runs) = bidi.visual_runs(para, line.clone());
    format!(
        "{}..{}: {} | {}",
        line.start,
        line.end,
        join(runs.iter().map(|r| format!("{}..{}@{}", r.start, r.end, levels[r.start].number()))),
        rle(&levels[line.clone()])
    )
}

/// A compact bidi report (for the conformance corpora).
fn bidi_record(cps: &[u32], dir: &str) -> String {
    let text = string(cps);
    let level = match dir {
        "ltr" => Some(Level::ltr()),
        "rtl" => Some(Level::rtl()),
        _ => None,
    };
    let bidi = BidiInfo::new(&text, level);
    let mut out = format!("bidi: {dir} {}\n  {}\n", hex(cps), bidi_summary(&bidi));
    for para in &bidi.paragraphs {
        writeln!(out, "  para {}", runs_report(&bidi, para, para.range.clone())).unwrap();
    }
    out
}

// ---------------------------------------------------------------------------
// A copy of upstream `breakpoints` (typst-layout/src/inline/linebreak.rs),
// with the `Preparation` replaced by parameters.

#[derive(Debug, Copy, Clone, Eq, PartialEq)]
enum Breakpoint {
    Normal,
    Mandatory,
    Hyphen(u8, u8),
}

fn breakpoints(
    text: &str,
    cj: bool,
    hyphenate: bool,
    lang: Option<hypher::Lang>,
    hyphenate_at: impl Fn(usize) -> bool,
    mut f: impl FnMut(usize, Breakpoint),
) {
    // Single breakpoint at the end for empty text.
    if text.is_empty() {
        f(0, Breakpoint::Mandatory);
        return;
    }

    let segmenter = if cj { CJ_SEGMENTER.as_borrowed() } else { *SEGMENTER };

    let mut last = 0;
    let mut iter = segmenter.segment_str(text).peekable();
    let mut next_url_scheme = find_url_scheme(text, 0);

    loop {
        // Special case for links. UAX #14 doesn't handle them well.
        let (head, tail) = text.split_at(last);
        if next_url_scheme.as_ref().is_some_and(|next| next.end < last) {
            next_url_scheme = find_url_scheme(text, last);
        }

        if head.ends_with("://")
            || tail.starts_with("www.")
            || next_url_scheme.as_ref().is_some_and(|it| it.contains(&last))
        {
            let (link, _) = typst_syntax::link_prefix(tail);
            linebreak_link(link, |i| f(last + i, Breakpoint::Normal));
            last += link.len();
            while iter.peek().is_some_and(|&p| p < last) {
                iter.next();
            }
        }

        // Get the next UAX #14 linebreak opportunity.
        let Some(point) = iter.next() else { break };

        // Skip breakpoint if there is no char before it. icu4x generates one
        // at offset 0, but we don't want it.
        let Some(c) = text[..point].chars().next_back() else { continue };

        let breakpoint = if point == text.len() {
            Breakpoint::Mandatory
        } else {
            const OBJ_REPLACE: char = '\u{FFFC}';
            match LINEBREAK_DATA.get(c) {
                LineBreak::MandatoryBreak
                | LineBreak::CarriageReturn
                | LineBreak::LineFeed
                | LineBreak::NextLine => Breakpoint::Mandatory,
                LineBreak::CombiningMark
                    if text[point..].starts_with(OBJ_REPLACE)
                        && last + c.len_utf8() == point =>
                {
                    continue;
                }
                _ => Breakpoint::Normal,
            }
        };

        // Hyphenate between the last and current breakpoint.
        if hyphenate && last < point {
            for segment in text[last..point].split_word_bounds() {
                if !segment.is_empty() && segment.chars().all(char::is_alphabetic) {
                    hyphenations(lang, &hyphenate_at, last, segment, &mut f);
                }
                last += segment.len();
            }
        }

        // Call `f` for the UAX #14 break opportunity.
        f(point, breakpoint);
        last = point;
    }
}

fn find_url_scheme(full_text: &str, base: usize) -> Option<std::ops::Range<usize>> {
    let text = &full_text[base..];
    let end = text.find("://")?;
    let start = text[..end].trim_end_matches(is_valid_in_url_scheme).len();
    Some(base + start..base + end)
}

fn is_valid_in_url_scheme(c: char) -> bool {
    matches!(c, '+' | '-' | '.') || c.is_ascii_alphanumeric()
}

fn hyphenations(
    lang: Option<hypher::Lang>,
    hyphenate_at: &impl Fn(usize) -> bool,
    mut offset: usize,
    word: &str,
    mut f: impl FnMut(usize, Breakpoint),
) {
    let Some(lang) = lang else { return };
    let count = word.chars().count();
    let end = offset + word.len();

    let mut chars = 0;
    for syllable in hypher::hyphenate(word, lang) {
        offset += syllable.len();
        chars += syllable.chars().count();

        if offset == end {
            continue;
        }
        if !hyphenate_at(offset) {
            continue;
        }
        if matches!(
            syllable.chars().next_back().map(|c| LINEBREAK_DATA.get(c)),
            Some(LineBreak::Glue | LineBreak::WordJoiner | LineBreak::ZWJ)
        ) {
            continue;
        }

        let l = chars.min(255) as u8;
        let r = (count - chars).min(255) as u8;
        f(offset, Breakpoint::Hyphen(l, r));
    }
}

fn linebreak_link(link: &str, mut f: impl FnMut(usize)) {
    #[derive(PartialEq)]
    enum Class {
        Alphabetic,
        Digit,
        Open,
        Other,
    }

    impl Class {
        fn of(c: char) -> Self {
            if c.is_alphabetic() {
                Class::Alphabetic
            } else if c.is_numeric() {
                Class::Digit
            } else if matches!(c, '(' | '[') {
                Class::Open
            } else {
                Class::Other
            }
        }
    }

    let mut offset = 0;
    let mut prev = Class::Other;

    for (end, c) in link.char_indices() {
        let class = Class::of(c);
        if end > 0
            && prev != Class::Open
            && if class == Class::Other { prev == Class::Other } else { class != prev }
        {
            let piece = &link[offset..end];
            if piece.len() < 16 {
                offset = end;
                f(offset);
            } else {
                for c in piece.chars() {
                    offset += c.len_utf8();
                    f(offset);
                }
            }
        }

        prev = class;
    }
}
