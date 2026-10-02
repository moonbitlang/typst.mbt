//! Generates `hayro/syntax/oracle_test.mbt`: the real `hayro-syntax` crate
//! (the revision Typst uses) run over the PDFs of hayro's own test corpus
//! (`hayro-tests/pdfs/{custom,load}`) and the PDF images of Typst's test
//! assets. For each file the test compares a canonical summary: load result,
//! version, number of objects, an FNV-1a hash of a canonical dump of all
//! objects (in `Pdf::objects` order, streams with their decoded data), and
//! per page the boxes, rotation, render dimensions, initial transform, the
//! decoded content stream and its typed operators. The MoonBit side
//! (`oracle_support_test.mbt`) computes the same summary.
//!
//! Usage: `cargo run --release --offline --bin gen_hayro_syntax_tests > ../hayro/syntax/oracle_test.mbt && moon fmt`

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use hayro_syntax::Pdf;
use hayro_syntax::object::{MaybeRef, Object};
use hayro_syntax::page::Rotation;

/// FNV-1a (64 bit).
fn fnv(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in data {
        h = (h ^ *b as u64).wrapping_mul(0x100000001b3);
    }
    h
}

fn hex(data: &[u8]) -> String {
    data.iter().map(|b| format!("{b:02x}")).collect()
}

fn dump_maybe_ref(o: &MaybeRef<Object<'_>>, out: &mut String) {
    match o {
        MaybeRef::Ref(r) => write!(out, "R{}.{}", r.obj_number, r.gen_number).unwrap(),
        MaybeRef::NotRef(o) => dump_object(o, out),
    }
}

fn dump_object(o: &Object<'_>, out: &mut String) {
    match o {
        Object::Null(_) => out.push('n'),
        Object::Boolean(b) => out.push(if *b { 't' } else { 'f' }),
        Object::Number(n) => write!(out, "d{:x}", n.as_f64().to_bits()).unwrap(),
        Object::String(s) => write!(out, "s{}", hex(s.as_bytes())).unwrap(),
        Object::Name(n) => write!(out, "/{}", hex(n.as_ref())).unwrap(),
        Object::Array(a) => {
            out.push('[');
            for (i, item) in a.raw_iter().enumerate() {
                if i > 0 {
                    out.push(' ');
                }
                dump_maybe_ref(&item, out);
            }
            out.push(']');
        }
        Object::Dict(d) => {
            out.push_str("<<");
            for (k, v) in d.entries() {
                write!(out, "/{} ", hex(k.as_ref())).unwrap();
                dump_maybe_ref(&v, out);
                out.push(' ');
            }
            out.push_str(">>");
        }
        Object::Stream(s) => {
            out.push('S');
            dump_object(&Object::Dict(s.dict().clone()), out);
            let raw = s.raw_data();
            write!(out, "{{{}:{:x}", raw.len(), fnv(&raw)).unwrap();
            // Image filters are not part of the comparison.
            let image = s.filters().iter().any(|f| {
                matches!(
                    f,
                    hayro_syntax::Filter::DctDecode
                        | hayro_syntax::Filter::JpxDecode
                        | hayro_syntax::Filter::Jbig2Decode
                        | hayro_syntax::Filter::CcittFaxDecode
                )
            });
            if image {
                out.push_str(" I}");
                return;
            }
            match s.decoded() {
                Ok(d) => write!(out, " {}:{:x}}}", d.len(), fnv(&d)).unwrap(),
                Err(_) => out.push_str(" E}"),
            }
        }
    }
}

fn summary(data: Vec<u8>) -> String {
    let mut out = String::new();
    let pdf = match Pdf::new(data) {
        Ok(pdf) => pdf,
        Err(e) => {
            return match e {
                hayro_syntax::LoadPdfError::Invalid => "load invalid\n".into(),
                hayro_syntax::LoadPdfError::Decryption(_) => "load decryption\n".into(),
            };
        }
    };
    writeln!(out, "version {:?}", pdf.version()).unwrap();
    writeln!(out, "objects {}", pdf.len()).unwrap();
    // Objects at the same position are yielded in hash map order, so the
    // lines are sorted.
    let mut lines = vec![];
    for o in pdf.objects() {
        let mut line = String::new();
        dump_object(&o, &mut line);
        lines.push(line);
    }
    lines.sort();
    let count = lines.len();
    let dump = lines.iter().map(|l| format!("{l}\n")).collect::<String>();
    writeln!(out, "objhash {count} {:x}", fnv(dump.as_bytes())).unwrap();
    writeln!(
        out,
        "ocgs {}",
        pdf.xref().has_optional_content_groups()
    )
    .unwrap();
    for (i, page) in pdf.pages().iter().enumerate() {
        let r = |r: hayro_syntax::object::Rect| {
            format!(
                "{:x} {:x} {:x} {:x}",
                r.x0.to_bits(),
                r.y0.to_bits(),
                r.x1.to_bits(),
                r.y1.to_bits()
            )
        };
        let rot = match page.rotation() {
            Rotation::None => 0,
            Rotation::Horizontal => 90,
            Rotation::Flipped => 180,
            Rotation::FlippedHorizontal => 270,
        };
        let (w, h) = page.render_dimensions();
        writeln!(
            out,
            "page {i} media {} crop {} rot {rot} dims {:x} {:x}",
            r(page.media_box()),
            r(page.crop_box()),
            w.to_bits(),
            h.to_bits()
        )
        .unwrap();
        for invert in [false, true] {
            let t = page.initial_transform(invert).as_coeffs();
            writeln!(
                out,
                "  transform {}",
                t.iter().map(|c| format!("{:x}", c.to_bits())).collect::<Vec<_>>().join(" ")
            )
            .unwrap();
        }
        match page.page_stream() {
            Some(s) => writeln!(out, "  stream {}:{:x}", s.len(), fnv(s)).unwrap(),
            None => writeln!(out, "  stream none").unwrap(),
        }
        let mut ops = page.typed_operations();
        let mut names = String::new();
        let mut n = 0;
        while let Some(op) = ops.next() {
            let name = format!("{op:?}");
            let name = name.split(['(', ' ']).next().unwrap().to_string();
            names.push_str(&name);
            names.push(' ');
            n += 1;
        }
        writeln!(out, "  ops {n} {:x}", fnv(names.as_bytes())).unwrap();
    }
    out
}

fn lit(s: &str) -> String {
    let mut out = String::new();
    for line in s.lines() {
        writeln!(out, "      #|{line}").unwrap();
    }
    out
}

fn collect(dir: &Path, rel: &str, out: &mut Vec<(String, PathBuf)>) {
    let Ok(entries) = std::fs::read_dir(dir) else { return };
    let mut files: Vec<_> = entries.flatten().map(|e| e.path()).collect();
    files.sort();
    for f in files {
        if f.extension().is_some_and(|e| e == "pdf") {
            let name = f.file_name().unwrap().to_string_lossy().to_string();
            out.push((format!("{rel}/{name}"), f));
        }
    }
}

fn main() {
    // Debugging: `gen_hayro_syntax_tests <file.pdf>` prints the object dump.
    if let Some(path) = std::env::args().nth(1) {
        let pdf = Pdf::new(std::fs::read(path).unwrap()).unwrap();
        let mut dump = String::new();
        for o in pdf.objects() {
            dump_object(&o, &mut dump);
            dump.push('\n');
        }
        print!("{dump}");
        return;
    }
    let home = std::env::var("HOME").unwrap();
    let checkouts = PathBuf::from(home).join(".cargo/git/checkouts");
    let mut hayro = None;
    let mut assets = None;
    for e in std::fs::read_dir(&checkouts).unwrap().flatten() {
        let name = e.file_name().to_string_lossy().to_string();
        let rev = std::fs::read_dir(e.path()).unwrap().flatten().next().unwrap().path();
        if name.starts_with("hayro-") {
            hayro = Some(rev);
        } else if name.starts_with("typst-dev-assets-") {
            assets = Some(rev);
        }
    }
    let mut files = vec![];
    if let Some(assets) = assets {
        collect(&assets.join("files/images"), "assets", &mut files);
    }
    if let Some(hayro) = hayro {
        collect(&hayro.join("hayro-tests/pdfs/custom"), "custom", &mut files);
        collect(&hayro.join("hayro-tests/pdfs/load"), "load", &mut files);
    }

    let mut out = String::from(
        "// Generated by oracle/src/bin/gen_hayro_syntax_tests.rs from hayro-syntax\n\
         // (rev d8e24e2). Do not edit by hand. Helpers are in\n\
         // oracle_support_test.mbt.\n",
    );
    for (name, path) in files {
        let data = std::fs::read(&path).unwrap();
        let summary = summary(data);
        write!(
            out,
            "\n///|\ntest \"oracle {name}\" {{\n  check_pdf(\n    {name:?},\n    (\n{}    ),\n  )\n}}\n",
            lit(&summary)
        )
        .unwrap();
    }
    print!("{out}");
}
