//! A minimal re-implementation of the upstream test collector
//! (`tests/src/collect.rs`, `tests/src/notes.rs`): only what is needed to
//! recover each test's name, attributes and body source.

use std::path::{Path, PathBuf};

pub struct TestCase {
    pub name: String,
    pub attrs: String,
    /// Body text with annotation lines (`// Error:` etc.) removed, every line
    /// terminated by `\n`, exactly like upstream `parse_test_body`.
    pub body: String,
}

/// All `.typ` files below `dir`, sorted for determinism.
pub fn typ_files(dir: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    walk(dir, &mut out);
    out.sort();
    out
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) {
    for entry in std::fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            walk(&path, out);
        } else if path.extension().is_some_and(|e| e == "typ") {
            out.push(path);
        }
    }
}

fn is_newline(c: char) -> bool {
    matches!(c, '\n' | '\x0B' | '\x0C' | '\r' | '\u{0085}' | '\u{2028}' | '\u{2029}')
}

/// Split a test file into its test cases.
pub fn split_tests(text: &str) -> Vec<TestCase> {
    let mut tests = Vec::new();
    let mut rest = text;
    // Skip the preamble.
    while !rest.is_empty() && !rest.starts_with("---") {
        rest = skip_line(rest);
    }
    while let Some(after) = rest.strip_prefix("---") {
        let header_end = after.find(is_newline).unwrap_or(after.len());
        let header = after[..header_end].trim();
        let (name, attrs) = header.split_once(char::is_whitespace).unwrap_or((header, ""));
        let attrs = attrs.trim().trim_end_matches("---").trim();
        rest = eat_newline(&after[header_end..]);
        let start = rest;
        while !rest.is_empty() && !rest.starts_with("---") {
            rest = skip_line(rest);
        }
        let full_body = &start[..start.len() - rest.len()];
        tests.push(TestCase {
            name: name.to_string(),
            attrs: attrs.to_string(),
            body: strip_notes(full_body),
        });
    }
    tests
}

fn skip_line(s: &str) -> &str {
    let end = s.find(is_newline).unwrap_or(s.len());
    eat_newline(&s[end..])
}

fn eat_newline(s: &str) -> &str {
    let mut chars = s.chars();
    match chars.next() {
        Some('\r') => {
            let r = chars.as_str();
            r.strip_prefix('\n').unwrap_or(r)
        }
        Some(c) if is_newline(c) => chars.as_str(),
        _ => s,
    }
}

/// Mirrors the first loop of upstream `parse_test_body`.
fn strip_notes(full_body: &str) -> String {
    let mut body = String::with_capacity(full_body.len());
    for line in full_body.lines() {
        let trimmed = line.trim_start_matches(' ');
        let is_note = ["// Error:", "// Warning:", "// Hint:"]
            .iter()
            .any(|p| trimmed.starts_with(p));
        if !is_note {
            body.push_str(line);
            body.push('\n');
        }
    }
    body
}
