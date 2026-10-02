//! The `reparse` stage: incremental reparsing through `Source::edit` and
//! `Source::replace`.
//!
//! For every test body, a deterministic sequence of pseudo-random edits
//! (seeded by the body's bytes, like a fuzzer) is applied to a detached
//! source. After each edit, one line records the edit, the range returned by
//! upstream, hashes of the tree, its span numbers and the line metadata, and
//! whether the tree equals a fresh parse. The final tree and its diagnostics
//! follow in the format of the `syntax` stage.
//!
//! The MoonBit runner (`tests/runner/reparse_stage.mbt`) generates the same
//! edits with the same generator and must produce the same report.

use std::fmt::Write as _;

use typst_syntax::{Source, SyntaxNode, parse};

/// Number of edits applied to every test body.
const EDITS: usize = 8;

/// Text that is inserted or replaces a range.
const SNIPPETS: &[&str] = &[
    "a",
    "b c",
    " ",
    "\n",
    "\n\n",
    "\r\n",
    "#",
    "#x",
    "#{",
    "}",
    "#[",
    "[",
    "]",
    "{",
    "(",
    ")",
    "\"",
    "$",
    "*",
    "_",
    "=",
    "= ",
    "- ",
    "+ ",
    "/ a: ",
    "//",
    "/*",
    "*/",
    "`",
    "```",
    "\\",
    "<l>",
    "@r",
    ";",
    ",",
    "let",
    "#let x = 1",
    "1.5em",
    "ä",
    "😀",
    "~",
    ".",
    ":",
    "=>",
    "-",
    "'",
    "#f(",
    "x)",
    "[]",
    "#{}",
    "#[x]",
    "$ x $",
    "  ",
    "\t",
    "if",
    "else",
    "<",
    ">",
    "\\[",
    "http://x.y/",
    "1.",
    "\u{200b}",
];

/// The splitmix64 generator.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// A number in `0..n` (`n > 0`).
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

/// 64-bit FNV-1a.
struct Fnv(u64);

impl Fnv {
    fn new() -> Self {
        Self(0xcbf2_9ce4_8422_2325)
    }

    fn write(&mut self, bytes: &[u8]) {
        for &b in bytes {
            self.0 ^= b as u64;
            self.0 = self.0.wrapping_mul(0x0000_0100_0000_01b3);
        }
    }

    fn write_u64(&mut self, v: u64) {
        self.write(&v.to_le_bytes());
    }
}

/// The closest position at or before `i` that is a char boundary and not
/// between `\r` and `\n` (upstream `Lines::edit` mishandles edits starting
/// there, so such edits are avoided).
fn floor_boundary(text: &str, mut i: usize) -> usize {
    while !text.is_char_boundary(i)
        || (i > 0 && text.as_bytes()[i - 1] == b'\r' && text.as_bytes().get(i) == Some(&b'\n'))
    {
        i -= 1;
    }
    i
}

/// An edit: replace `start..end` with `with`, through `Source::replace` if
/// `whole` and through `Source::edit` otherwise.
struct Edit {
    start: usize,
    end: usize,
    with: String,
    whole: bool,
}

fn next_edit(rng: &mut Rng, text: &str) -> Edit {
    let len = text.len();
    let kind = rng.below(5);
    let start = floor_boundary(text, rng.below(len + 1));
    let snippet = |rng: &mut Rng| SNIPPETS[rng.below(SNIPPETS.len())].to_string();
    let end = |rng: &mut Rng| floor_boundary(text, (start + 1 + rng.below(8)).min(len));
    match kind {
        // Insert a snippet.
        0 => Edit {
            start,
            end: start,
            with: snippet(rng),
            whole: false,
        },
        // Delete a short range.
        1 => Edit {
            start,
            end: end(rng),
            with: String::new(),
            whole: false,
        },
        // Replace a short range with a snippet.
        2 => {
            let end = end(rng);
            Edit {
                start,
                end,
                with: snippet(rng),
                whole: false,
            }
        }
        // Insert a copy of a piece of the text itself.
        3 => {
            let a = floor_boundary(text, rng.below(len + 1));
            let b = floor_boundary(text, (a + rng.below(17)).min(len));
            Edit {
                start,
                end: start,
                with: text[a..b].to_string(),
                whole: false,
            }
        }
        // Replace a short range with a snippet, through `Source::replace`.
        _ => {
            let end = end(rng);
            Edit {
                start,
                end,
                with: snippet(rng),
                whole: true,
            }
        }
    }
}

/// Hash all span numbers of the tree in pre-order.
fn hash_spans(node: &SyntaxNode, h: &mut Fnv) {
    h.write_u64(node.span().into_raw().get() & ((1 << 48) - 1));
    for child in node.children() {
        hash_spans(child, h);
    }
}

pub fn reparse_report(text: &str) -> String {
    let mut out = String::new();
    let mut seed = Fnv::new();
    seed.write(text.as_bytes());
    let mut rng = Rng(seed.0);
    let mut source = Source::detached(text);
    for i in 0..EDITS {
        let edit = next_edit(&mut rng, source.text());
        let range = if edit.whole {
            let old = source.text();
            let new = format!("{}{}{}", &old[..edit.start], edit.with, &old[edit.end..]);
            source.replace(&new)
        } else {
            source.edit(edit.start..edit.end, &edit.with)
        };

        let root = source.root();
        let mut tree = Fnv::new();
        tree.write(format!("{root:#?}").as_bytes());
        let mut spans = Fnv::new();
        hash_spans(root, &mut spans);
        let lines = source.lines();
        let mut line_hash = Fnv::new();
        for l in 0..lines.len_lines() {
            let b = lines.line_to_byte(l).unwrap();
            line_hash.write_u64(b as u64);
            line_hash.write_u64(lines.byte_to_utf16(b).unwrap() as u64);
        }
        let full = if root.spanless_eq(&parse(source.text())) {
            "same"
        } else {
            "differs"
        };
        writeln!(
            out,
            "edit {i} {} {}..{} {:?} -> {}..{} tree={:016x} spans={:016x} lines={}:{:016x} full={full}",
            if edit.whole { "replace" } else { "edit" },
            edit.start,
            edit.end,
            edit.with,
            range.start,
            range.end,
            tree.0,
            spans.0,
            lines.len_lines(),
            line_hash.0,
        )
        .unwrap();
    }

    let root = source.root();
    writeln!(out, "{root:#?}").unwrap();
    let (errors, warnings) = root.errors_and_warnings();
    for diag in errors.iter().chain(&warnings) {
        out.push_str(&crate::diagnostic_line(&source, diag));
    }
    out
}
