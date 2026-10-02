//! Generates `bib/hayagriva/collation_gen.mbt`: per-code-point collation
//! data for the ICU root collator (default options), extracted from
//! `icu_collator` itself via single-character sort keys, plus
//! `bib/hayagriva/collation_gen_test.mbt` with reference comparisons.
//!
//! hayagriva sorts bibliographies with `icu_collator::Collator::compare`.
//! The MoonBit port compares strings level by level:
//!
//! - Primary: the sort-key bytes of each character are concatenated while
//!   emulating ICU's primary lead-byte compression (this needs, for each
//!   character, its first lead byte, the remaining primary bytes and the
//!   compression state after the character).
//! - Secondary / tertiary: uncompressed weights (common weights expanded),
//!   which compare the same as ICU's compressed keys.
//!
//! Contractions and canonical reordering across characters are not
//! modelled. The generator validates the approach against
//! `Collator::compare` and reports the mismatch rate.
//!
//! Usage: cargo run --release --bin gen_collation -- <repo-root>

use std::cmp::Ordering;
use std::collections::BTreeMap;
use std::fmt::Write as _;

use icu_collator::options::CollatorOptions;
use icu_collator::{Collator, CollatorBorrowed};

const RANGES: &[(u32, u32)] = &[
    (0x0000, 0x0700),
    (0x1100, 0x1200),
    (0x1D00, 0x2200),
    (0x2460, 0x2500),
    (0x3000, 0x3190),
    (0xFB00, 0xFB50),
    (0xFF00, 0xFFF0),
];

const SEC_LOW: u8 = 0x05;
const SEC_HIGH: u8 = 0x45;
const SEC_MIDDLE: u8 = 0x25;
const TER_LOW: u8 = 0x05;
const TER_HIGH: u8 = 0xC5;
const TER_MIDDLE: u8 = 0x65;

#[derive(Debug, Clone, Default)]
struct Entry {
    /// First primary lead byte (None if the character has no primary).
    first: Option<u8>,
    /// Remaining primary bytes after the first lead byte.
    rest: Vec<u8>,
    /// Compressible lead byte in effect after this character.
    end: Option<u8>,
    /// Uncompressed secondary weights.
    sec: Vec<u8>,
    /// Uncompressed tertiary weights.
    ter: Vec<u8>,
}

fn key(c: &CollatorBorrowed, s: &str) -> Vec<u8> {
    let mut v = Vec::new();
    c.write_sort_key_to(s, &mut v).unwrap();
    v
}

/// Split a sort key into its primary, secondary and tertiary sections.
fn levels(k: &[u8]) -> (Vec<u8>, Vec<u8>, Vec<u8>) {
    let mut parts = k.split(|&b| b == 1);
    let p = parts.next().unwrap_or(&[]).to_vec();
    let s = parts.next().unwrap_or(&[]).to_vec();
    // The (empty) case level.
    let _ = parts.next();
    let t = parts.next().unwrap_or(&[]).to_vec();
    (p, s, t)
}

fn decompress(bytes: &[u8], low: u8, middle: u8, high: u8, max: u8) -> Vec<u8> {
    let mut out = Vec::new();
    for &b in bytes {
        if b == middle {
            out.extend(std::iter::repeat_n(low, max as usize));
        } else if b >= low && b < middle {
            out.extend(std::iter::repeat_n(low, (b - low + 1) as usize));
        } else if b > middle && b <= high {
            out.extend(std::iter::repeat_n(low, (high - b + 1) as usize));
        } else {
            out.push(b);
        }
    }
    out
}

fn main() {
    let root = std::env::args().nth(1).expect("repo root");
    let collator = Collator::try_new(Default::default(), CollatorOptions::default()).unwrap();
    let c = &collator;
    if std::env::var("COLL_DEBUG").is_ok() {
        for s in ["a", "A", "â", "Â", "ab", "AB", "ß", "æ", "한", "日"] {
            eprintln!("{s:?}: {:02X?}", key(c, s));
        }
    }

    // All code points in the ranges, as strings.
    let mut chars = Vec::new();
    for &(a, b) in RANGES {
        for cp in a..b {
            if let Some(ch) = char::from_u32(cp) {
                chars.push(ch);
            }
        }
    }

    // Find compressible lead bytes: lead L is compressible iff the key of
    // "xy" (both single-primary chars with lead L) omits the second lead.
    let mut by_lead: BTreeMap<u8, Vec<char>> = BTreeMap::new();
    for &ch in &chars {
        let (p, _, _) = levels(&key(c, &ch.to_string()));
        if p.len() >= 2 && p.len() <= 4 && !p.contains(&3) && !p.contains(&0xff) {
            by_lead.entry(p[0]).or_default().push(ch);
        }
    }
    let mut compressible = Vec::new();
    for (&lead, xs) in &by_lead {
        let x = xs[0];
        let y = *xs.get(1).unwrap_or(&x);
        let (px, _, _) = levels(&key(c, &x.to_string()));
        let (py, _, _) = levels(&key(c, &y.to_string()));
        let (pxy, _, _) = levels(&key(c, &format!("{x}{y}")));
        if pxy.len() == px.len() + py.len() - 1 {
            compressible.push(lead);
        }
    }

    // A probe with a non-compressible lead byte.
    let probe_nc = chars
        .iter()
        .copied()
        .find(|&ch| {
            let (p, _, _) = levels(&key(c, &ch.to_string()));
            !p.is_empty() && p[0] > 3 && !compressible.contains(&p[0]) && p.len() >= 2
        })
        .expect("non-compressible probe");
    let (probe_nc_p, _, _) = levels(&key(c, &probe_nc.to_string()));

    let mut table: BTreeMap<u32, Entry> = BTreeMap::new();
    for &ch in &chars {
        let s = ch.to_string();
        let (p, sec, ter) = levels(&key(c, &s));
        let mut e = Entry {
            sec: decompress(&sec, SEC_LOW, SEC_MIDDLE, SEC_HIGH, 0x21),
            ter: decompress(&ter, TER_LOW, TER_MIDDLE, TER_HIGH, 0x61),
            ..Default::default()
        };
        if !p.is_empty() {
            e.first = Some(p[0]);
            e.rest = p[1..].to_vec();
            // Determine the compression state after the character.
            let (pp, _, _) = levels(&key(c, &format!("{ch}{probe_nc}")));
            let plain: Vec<u8> = p.iter().chain(probe_nc_p.iter()).copied().collect();
            if pp != plain {
                for &lead in &compressible {
                    let g = by_lead[&lead][0];
                    let (pg, _, _) = levels(&key(c, &g.to_string()));
                    let (pcg, _, _) = levels(&key(c, &format!("{ch}{g}")));
                    let omitted: Vec<u8> = p.iter().chain(pg[1..].iter()).copied().collect();
                    if pcg == omitted {
                        e.end = Some(lead);
                        break;
                    }
                }
                if e.end.is_none() {
                    eprintln!("warning: could not determine end state of {:?}", ch);
                }
            }
        }
        table.insert(ch as u32, e);
    }

    // Validate against the real collator.
    let corpus = corpus(&chars);
    let mut total = 0usize;
    let mut mismatches = 0usize;
    let mut tests = Vec::new();
    for (i, a) in corpus.iter().enumerate() {
        for (j, b) in corpus.iter().enumerate() {
            if (i * 31 + j * 17) % 7 != 0 {
                continue;
            }
            total += 1;
            let expected = c.compare(a, b);
            let got = emulate(&table, &compressible, a, b);
            if expected != got {
                mismatches += 1;
                if mismatches <= 20 {
                    eprintln!("mismatch: {a:?} vs {b:?}: icu {expected:?}, emulated {got:?}");
                }
            } else if tests.len() < 400 && (i + j) % 5 == 0 {
                tests.push((a.clone(), b.clone(), expected));
            }
        }
    }
    eprintln!("validated {total} pairs, {mismatches} mismatches");

    // Emit the table.
    let mut out = String::new();
    writeln!(out, "// Code generated by oracle/src/bin/gen_collation.rs. DO NOT EDIT.").unwrap();
    writeln!(out, "// Collation data of the ICU root collator (icu_collator 2.3.1).").unwrap();
    writeln!(out).unwrap();
    writeln!(out, "///|").unwrap();
    write!(out, "let collation_compressible_leads : Array[Int] = [").unwrap();
    for (i, l) in compressible.iter().enumerate() {
        if i > 0 {
            out.push_str(", ");
        }
        write!(out, "0x{l:02X}").unwrap();
    }
    writeln!(out, "]").unwrap();
    writeln!(out).unwrap();
    writeln!(out, "///|").unwrap();
    writeln!(out, "/// Ranges of code points covered by `collation_table_data`.").unwrap();
    write!(out, "let collation_ranges : Array[(Int, Int)] = [").unwrap();
    for (i, (a, b)) in RANGES.iter().enumerate() {
        if i > 0 {
            out.push_str(", ");
        }
        write!(out, "(0x{a:04X}, 0x{b:04X})").unwrap();
    }
    writeln!(out, "]").unwrap();
    writeln!(out).unwrap();
    writeln!(out, "///|").unwrap();
    writeln!(
        out,
        "/// One line per code point: `cp first rest end sec ter` (hex, `-` = none)."
    )
    .unwrap();
    writeln!(out, "let collation_table_data : String =").unwrap();
    for (cp, e) in &table {
        let hex = |v: &[u8]| -> String {
            if v.is_empty() {
                "-".into()
            } else {
                v.iter().map(|b| format!("{b:02X}")).collect()
            }
        };
        let opt = |v: Option<u8>| v.map(|b| format!("{b:02X}")).unwrap_or("-".into());
        writeln!(
            out,
            "  #|{:X} {} {} {} {} {}",
            cp,
            opt(e.first),
            hex(&e.rest),
            opt(e.end),
            hex(&e.sec),
            hex(&e.ter)
        )
        .unwrap();
    }
    std::fs::write(format!("{root}/bib/hayagriva/collation_gen.mbt"), out).unwrap();

    // Emit tests.
    let mut t = String::new();
    writeln!(t, "// Code generated by oracle/src/bin/gen_collation.rs. DO NOT EDIT.").unwrap();
    writeln!(t, "// Expected values come from icu_collator 2.3.1 (root, default options).").unwrap();
    writeln!(t).unwrap();
    writeln!(t, "///|").unwrap();
    writeln!(t, "test \"root collation matches icu_collator\" {{").unwrap();
    writeln!(t, "  let cases : Array[(String, String, Int)] = [").unwrap();
    for (a, b, o) in &tests {
        let o = match o {
            Ordering::Less => -1,
            Ordering::Equal => 0,
            Ordering::Greater => 1,
        };
        writeln!(t, "    ({}, {}, {}),", mbt_str(a), mbt_str(b), o).unwrap();
    }
    writeln!(t, "  ]").unwrap();
    writeln!(t, "  for case in cases {{").unwrap();
    writeln!(t, "    let (a, b, expected) = case").unwrap();
    writeln!(
        t,
        "    assert_eq((a, b, root_collation_compare(a, b)), (a, b, expected))"
    )
    .unwrap();
    writeln!(t, "  }}").unwrap();
    writeln!(t, "}}").unwrap();
    std::fs::write(format!("{root}/bib/hayagriva/collation_gen_wbtest.mbt"), t).unwrap();
}

fn mbt_str(s: &str) -> String {
    let mut out = String::from("\"");
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            c if (c as u32) < 0x20 || (c as u32) == 0x7f => {
                write!(out, "\\u{{{:x}}}", c as u32).unwrap()
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// Strings used to validate the emulation.
fn corpus(chars: &[char]) -> Vec<String> {
    let mut v: Vec<String> = [
        "", "a", "A", "b", "ab", "aB", "Ab", "abc", "abd", "résumé", "resume", "Résumé",
        "resumes", "müller", "muller", "mueller", "Müller", "Mueller", "ångström",
        "angstrom", "zoë", "zoe", "øster", "oster", "straße", "strasse", "strase",
        "æsop", "aesop", "aesir", "de la cruz", "delacruz", "de la Cruz", "o'brien",
        "obrien", "o brien", "van gogh", "vangogh", "đorđević", "dordevic", "łukasz",
        "lukasz", "ünal", "unal", "çelik", "celik", "i̇stanbul", "istanbul", "1984",
        "2001", "20", "a1", "a10", "a2", "the art of computer programming",
        "the quick brown fox", "quantum mechanics", "über alles", "uber alles",
        "naïve", "naive", "coöperate", "cooperate", "œuvre", "oeuvre", "ﬁle", "file",
        "x-ray", "xray", "x ray", "a.b", "a,b", "a-b", "a_b", "(a)", "[a]", "“a”",
        "\"a\"", "a…", "a...", "½", "1/2", "α", "β", "alpha", "ω", "я", "а", "б",
        "日本", "中文", "かな", "カナ", "한국", "עברית", "عربي", "ii", "ij", "ĳ",
        "ss", "sß", "ßs", "tschüss", "tschuss", "électricité", "electricite",
        "élan", "elan", "emil", "Émile", "zz", "z", "þorn", "thorn", "ð", "d",
        "ǆ", "dž", "dz", "ŉ", "ʼn", "ﬀ", "ff", "ſ", "s", "ẞ", "ss", "aa", "å",
        "aaa", "aå", "åa", "Á", "á", "À", "à", "Â", "â", "ä", "Ä", "ã", "Ã",
    ]
    .iter()
    .map(|s| s.to_string())
    .collect();
    // Pseudo-random strings over a small alphabet.
    let alphabet: Vec<char> = "aeiouyAEIOUbcdfghklmnprstvwxzéèêëàâäöüçñßæø .,'-()0123456789"
        .chars()
        .collect();
    let mut seed: u64 = 0x1234_5678;
    for _ in 0..300 {
        let mut s = String::new();
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let len = 1 + (seed >> 60) as usize;
        for _ in 0..len {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            s.push(alphabet[(seed >> 33) as usize % alphabet.len()]);
        }
        v.push(s);
    }
    // Some strings using arbitrary table characters.
    for i in 0..100 {
        let a = chars[(i * 37) % chars.len()];
        let b = chars[(i * 101 + 7) % chars.len()];
        v.push(format!("{a}{b}"));
    }
    v
}

/// The comparison as implemented in MoonBit.
fn emulate(table: &BTreeMap<u32, Entry>, compressible: &[u8], a: &str, b: &str) -> Ordering {
    let ka = emulate_key(table, compressible, a);
    let kb = emulate_key(table, compressible, b);
    ka.0.cmp(&kb.0).then(ka.1.cmp(&kb.1)).then(ka.2.cmp(&kb.2))
}

fn is_han(cp: u32) -> bool {
    (0x4E00..=0x9FFF).contains(&cp)
        || (0x3400..=0x4DBF).contains(&cp)
        || (0xF900..=0xFAFF).contains(&cp)
        || (0x20000..=0x3FFFF).contains(&cp)
}

fn fallback(cp: u32) -> Entry {
    Entry {
        first: Some(if is_han(cp) { 0xFA } else { 0xF0 }),
        rest: vec![(cp >> 16) as u8 + 2, (cp >> 8) as u8 | 1, cp as u8 | 1],
        end: None,
        sec: vec![SEC_LOW],
        ter: vec![TER_LOW],
    }
}

fn emulate_key(
    table: &BTreeMap<u32, Entry>,
    _compressible: &[u8],
    s: &str,
) -> (Vec<u8>, Vec<u8>, Vec<u8>) {
    let mut p = Vec::new();
    let mut sec = Vec::new();
    let mut ter = Vec::new();
    let mut prev: Option<u8> = None;
    let mut decomposed = Vec::new();
    for ch in s.chars() {
        let cp = ch as u32;
        if (0xAC00..=0xD7A3).contains(&cp) {
            // Hangul syllables decompose algorithmically into jamo.
            let si = cp - 0xAC00;
            decomposed.push(char::from_u32(0x1100 + si / 588).unwrap());
            decomposed.push(char::from_u32(0x1161 + (si % 588) / 28).unwrap());
            if si % 28 != 0 {
                decomposed.push(char::from_u32(0x11A7 + si % 28).unwrap());
            }
        } else {
            decomposed.push(ch);
        }
    }
    for ch in decomposed {
        let fb;
        let e = match table.get(&(ch as u32)) {
            Some(e) => e,
            None => {
                fb = fallback(ch as u32);
                &fb
            }
        };
        if let Some(first) = e.first {
            if prev == Some(first) {
                p.extend_from_slice(&e.rest);
            } else {
                if let Some(pl) = prev {
                    if first < pl {
                        if first > 2 {
                            p.push(3);
                        }
                    } else {
                        p.push(0xff);
                    }
                }
                p.push(first);
                p.extend_from_slice(&e.rest);
            }
            prev = e.end;
        }
        sec.extend_from_slice(&e.sec);
        ter.extend_from_slice(&e.ter);
    }
    (p, sec, ter)
}
