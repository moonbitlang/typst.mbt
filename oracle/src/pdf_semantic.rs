//! The `pdf-semantic` and `pdftags` stages: export every paged test case to
//! PDF like the upstream test harness (`tests/src/output.rs`, `impl
//! OutputType for Pdf`) and dump a canonical, byte-hash independent
//! description of the resulting file.
//!
//! The PDF is exported with the harness' options: creator `Typst Test
//! Runner`, the document title set to the test name if the document has
//! none, and the PDF standards selected like `Pdf::make_live` (none, unless
//! the document configures some).
//!
//! # Format (`typst-pdf-semantic-v1`)
//!
//! Each test case is a `=== <name>` line followed by either `<error>` (the
//! document failed to compile), the export diagnostics (`export-error`
//! followed by diagnostic lines in the format of the `eval` stage) or the
//! semantic dump below. Export warnings precede the dump as
//! `warning <range> "msg"` lines.
//!
//! The dump is produced by [`extract`], which is mirrored line by line by the
//! MoonBit extractor (`tests/runner/pdf_semantic.mbt`). Numbers are printed
//! with two decimals (`-0.00` is printed as `0.00`), colors with three. All
//! strings are PDF text strings decoded to Unicode and printed with Rust's
//! `{:?}`.
//!
//! ```text
//! version <header version>
//! info <Key> "<value>"            (Title, Author, Subject, Keywords, Creator)
//! info CreationDate <Y-M-D h:m:s +hh:mm>
//! catalog lang "<Lang>"
//! catalog display-doc-title <bool>
//! catalog marked <bool>
//! catalog struct-tree <bool>
//! xmp <key> "<value>"             (dc:language, pdfaid:part, pdfaid:conformance, pdfuaid:part)
//! label <page> style=<S|-> prefix="<P>" start=<St>
//! page <i> media [x0 y0 x1 y1] [trim [..]]
//!   text [x y] <size> <font> <fill> "<text>"
//!   path <op> [x0 y0 x1 y1] <paints>
//!   image <w>x<h> <colorspace> bpc=<n> [smask] [interpolate] [a b c d e f]
//!   shading <type>
//!   annot <Subtype> [x0 y0 x1 y1] <target> [contents "<c>"]
//! dest "<name>" <target>
//! outline <indent>"<title>" <target>
//! attach "<name>" uf="<uf>" desc="<d>" rel=<R> mime=<M> size=<n>
//! ```
//!
//! - Text blocks are `BT`…`ET` sections: `[x y]` is the origin of the first
//!   shown glyph in default user space, `size` the font size scaled by the
//!   text rendering matrix, `font` the base font without subset tag and
//!   `-Identity-H` suffix; the text is the concatenation of the ToUnicode
//!   mappings of the shown glyphs, where glyphs inside a marked-content
//!   sequence with `/ActualText` are replaced by that text.
//! - Paths are painted paths (`f`, `f*`, `S`, `B`, `B*`, …; not clipping
//!   paths), with the bounding box of their points in default user space.
//! - Form XObjects are interpreted inline; tiling patterns are not entered.
//! - A target is `uri "<u>"`, `page <n> xyz <x> <y>` or
//!   `named "<name>" -> <target>`.

use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::Path;
use std::sync::Arc;

use hayro_syntax::Pdf;
use hayro_syntax::object::{Array, Dict, Name, Object, ObjRef, Stream};
use typst::diag::Warned;
use typst::foundations::Smart;
use typst::model::Document as _;
use typst::World;
use typst_layout::PagedDocument;
use typst_pdf::{PdfFormatOptions, PdfOptions, PdfStandard, PdfStandards};

use crate::collect;
use crate::eval::{deduplicate, write_diag};
use crate::paged::is_paged;
use crate::world::{TestWorld, parse_features};

/// Which dump to produce.
#[derive(Clone, Copy, PartialEq)]
pub enum Kind {
    Semantic,
    Tags,
}

/// Dump the PDF semantics of every paged test below `suite`.
pub fn dump_pdf(suite: &Path, out: &Path, kind: Kind) {
    let mut count = 0;
    let filter = std::env::var("ORACLE_FILTER").ok();
    let save = std::env::var("ORACLE_SAVE_PDF").ok();
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
            let selected = match kind {
                Kind::Semantic => is_paged(&test.attrs),
                Kind::Tags => test.attrs.split_whitespace().any(|a| a == "pdftags"),
            };
            if !selected {
                continue;
            }
            if std::env::var("ORACLE_VERBOSE").is_ok() {
                eprintln!("{} {}", rel.display(), test.name);
            }
            writeln!(report, "=== {}", test.name).unwrap();
            let save_to = save.as_ref().map(|dir| {
                Path::new(dir).join(rel).with_extension("").join(format!("{}.pdf", test.name))
            });
            report.push_str(&pdf_report(&file, &test, kind, save_to.as_deref()));
            count += 1;
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("exported {count} test cases to PDF");
}

/// Compile a single test case, export it like the upstream harness and dump
/// it.
fn pdf_report(
    path: &Path,
    test: &collect::TestCase,
    kind: Kind,
    save_to: Option<&Path>,
) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);
    let main = world.main();

    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let Warned { output, .. } = typst::compile::<PagedDocument>(&world);
        let Ok(mut doc) = output else { return "<error>\n".to_string() };
        if doc.info().title.is_none() {
            doc.info_mut().title = Some(test.name.clone().into());
        }
        let Warned { output, warnings } = make_live(&doc);
        let mut out = String::new();
        match output {
            Err(errors) => {
                out.push_str("export-error\n");
                for diag in deduplicate(errors) {
                    write_diag(&mut out, &world, main, &diag);
                }
                for diag in deduplicate(warnings) {
                    write_diag(&mut out, &world, main, &diag);
                }
            }
            Ok(bytes) => {
                for diag in deduplicate(warnings) {
                    write_diag(&mut out, &world, main, &diag);
                }
                if let Some(path) = save_to {
                    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
                    std::fs::write(path, &bytes).unwrap();
                }
                let dumped = match kind {
                    Kind::Semantic => extract(&bytes),
                    Kind::Tags => crate::pdftags::format(&bytes).map_err(|e| e.to_string()),
                };
                match dumped {
                    Ok(s) => out.push_str(&s),
                    Err(e) => writeln!(out, "<extract-error {e:?}>").unwrap(),
                }
            }
        }
        out
    }));
    match result {
        Ok(s) => s,
        Err(_) => "<panic>\n".into(),
    }
}

/// Like upstream `Pdf::make_live`.
fn make_live(doc: &PagedDocument) -> Warned<typst::diag::SourceResult<Vec<u8>>> {
    let default_pdf = || generate_pdf(doc, Some(&[]));
    let ua1_pdf = || generate_pdf(doc, Some(&[PdfStandard::UA_1]));
    let doc_opts = doc.options().get::<typst_pdf::PdfFormat>();
    let standards = doc_opts.standard.v.standards().collect::<Vec<_>>();
    match *standards.as_slice() {
        [] => default_pdf(),
        [PdfStandard::V_1_7, PdfStandard::UA_1] => ua1_pdf(),
        _ => generate_pdf(doc, None),
    }
}

fn generate_pdf(
    doc: &PagedDocument,
    standards: Option<&[PdfStandard]>,
) -> Warned<typst::diag::SourceResult<Vec<u8>>> {
    let standard = standards
        .map(|s| PdfStandards::new(s.iter().copied()))
        .transpose()
        .unwrap();
    let options = PdfOptions {
        creator: Smart::Custom(Some("Typst Test Runner".into())),
        format: PdfFormatOptions { standard, ..Default::default() },
        ..Default::default()
    };
    typst_pdf::pdf(doc, &options)
}


// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

/// Format a number with two decimals, printing negative zero as zero.
fn num(v: f64) -> String {
    let s = format!("{v:.2}");
    if s == "-0.00" { "0.00".into() } else { s }
}

fn num3(v: f64) -> String {
    let s = format!("{v:.3}");
    if s == "-0.000" { "0.000".into() } else { s }
}

/// Decode a PDF text string (UTF-16BE with BOM, UTF-8 with BOM, or
/// PDFDocEncoding, approximated by Latin-1).
fn text_string(bytes: &[u8]) -> String {
    if let Some(rest) = bytes.strip_prefix(b"\xFE\xFF") {
        let units: Vec<u16> =
            rest.chunks(2).filter(|c| c.len() == 2).map(|c| u16::from_be_bytes([c[0], c[1]])).collect();
        String::from_utf16_lossy(&units)
    } else if let Some(rest) = bytes.strip_prefix(b"\xEF\xBB\xBF") {
        String::from_utf8_lossy(rest).into_owned()
    } else {
        bytes.iter().map(|&b| b as char).collect()
    }
}

fn obj_str(o: &Object) -> Option<String> {
    match o {
        Object::String(s) => Some(text_string(s.as_bytes())),
        Object::Name(n) => Some(n.as_str().to_string()),
        _ => None,
    }
}

fn obj_f64(o: &Object) -> Option<f64> {
    match o {
        Object::Number(n) => Some(n.as_f64()),
        _ => None,
    }
}

type Matrix = [f64; 6];

const IDENTITY: Matrix = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

/// `a × b` (apply `a`, then `b`), PDF row-vector convention.
fn mul(a: &Matrix, b: &Matrix) -> Matrix {
    [
        a[0] * b[0] + a[1] * b[2],
        a[0] * b[1] + a[1] * b[3],
        a[2] * b[0] + a[3] * b[2],
        a[2] * b[1] + a[3] * b[3],
        a[4] * b[0] + a[5] * b[2] + b[4],
        a[4] * b[1] + a[5] * b[3] + b[5],
    ]
}

fn apply(m: &Matrix, x: f64, y: f64) -> (f64, f64) {
    (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])
}

fn matrix_of(arr: &Array) -> Option<Matrix> {
    let v: Vec<f64> = arr.iter::<Object>().filter_map(|o| obj_f64(&o)).collect();
    (v.len() == 6).then(|| [v[0], v[1], v[2], v[3], v[4], v[5]])
}

fn rect_of(arr: &Array) -> Option<[f64; 4]> {
    let v: Vec<f64> = arr.iter::<Object>().filter_map(|o| obj_f64(&o)).collect();
    (v.len() == 4).then(|| [v[0], v[1], v[2], v[3]])
}

fn fmt_rect(r: [f64; 4]) -> String {
    format!("[{} {} {} {}]", num(r[0]), num(r[1]), num(r[2]), num(r[3]))
}

/// Context shared by the whole extraction.
struct Doc<'a> {
    pdf: &'a Pdf,
    pages: Vec<ObjRef>,
    named: HashMap<String, Object<'a>>,
}

impl<'a> Doc<'a> {
    fn page_index(&self, r: ObjRef) -> Option<usize> {
        self.pages.iter().position(|p| *p == r)
    }

    /// Format an explicit destination array.
    fn explicit_dest(&self, arr: &Array) -> String {
        let mut it = arr.raw_iter();
        let page = it.next().and_then(|p| p.as_obj_ref()).and_then(|r| self.page_index(r));
        // Resolve the remaining items one by one (iterating the resolved
        // items stops at the page reference).
        let items: Vec<Option<Object>> = it
            .map(|o| match o {
                hayro_syntax::object::MaybeRef::NotRef(o) => Some(o),
                hayro_syntax::object::MaybeRef::Ref(r) => self.pdf.xref().get::<Object>(r.into()),
            })
            .collect();
        let kind = items
            .first()
            .and_then(|o| o.as_ref())
            .and_then(obj_str)
            .unwrap_or_default();
        let rest: Vec<String> = items
            .iter()
            .skip(1)
            .map(|o| o.as_ref().and_then(obj_f64).map(num).unwrap_or_else(|| "null".into()))
            .collect();
        let page = page.map(|p| p.to_string()).unwrap_or_else(|| "?".into());
        if kind == "XYZ" && rest.len() >= 2 {
            format!("page {page} xyz {} {}", rest[0], rest[1])
        } else {
            format!("page {page} {} {}", kind.to_lowercase(), rest.join(" "))
        }
    }

    /// Format the target of a named destination.
    fn named_target(&self, name: &str) -> String {
        match self.named.get(name) {
            Some(Object::Array(a)) => self.explicit_dest(a),
            Some(Object::Dict(d)) => match d.get::<Array>("D") {
                Some(a) => self.explicit_dest(&a),
                None => "?".into(),
            },
            _ => "?".into(),
        }
    }

    /// Format a destination (explicit or named).
    fn dest(&self, o: &Object<'a>) -> String {
        match o {
            Object::Array(a) => self.explicit_dest(a),
            Object::String(_) | Object::Name(_) => {
                let name = obj_str(o).unwrap();
                format!("named {name:?} -> {}", self.named_target(&name))
            }
            Object::Dict(d) => match d.get::<Object>("D") {
                Some(inner) => self.dest(&inner),
                None => "?".into(),
            },
            _ => "?".into(),
        }
    }

    /// Format the target of a link annotation or outline item.
    fn target(&self, d: &Dict<'a>) -> String {
        if let Some(dest) = d.get::<Object>("Dest") {
            return self.dest(&dest);
        }
        if let Some(action) = d.get::<Dict>("A") {
            let s = action.get::<Name>("S").map(|n| n.as_str().to_string()).unwrap_or_default();
            match s.as_str() {
                "URI" => {
                    let uri = action.get::<Object>("URI").and_then(|o| obj_str(&o)).unwrap_or_default();
                    return format!("uri {uri:?}");
                }
                "GoTo" => {
                    if let Some(dest) = action.get::<Object>("D") {
                        return self.dest(&dest);
                    }
                }
                _ => return format!("action {s}"),
            }
        }
        "none".into()
    }
}

/// Collect the entries of a name tree.
fn name_tree<'a>(node: &Dict<'a>, out: &mut Vec<(String, Object<'a>)>) {
    if let Some(names) = node.get::<Array>("Names") {
        let items: Vec<Object> = names.iter::<Object>().collect();
        for pair in items.chunks(2) {
            if let [k, v] = pair
                && let Some(k) = obj_str(k)
            {
                out.push((k, v.clone()));
            }
        }
    }
    if let Some(kids) = node.get::<Array>("Kids") {
        for kid in kids.iter::<Dict>() {
            name_tree(&kid, out);
        }
    }
}

/// Collect the entries of a number tree.
fn number_tree<'a>(node: &Dict<'a>, out: &mut Vec<(i64, Object<'a>)>) {
    if let Some(nums) = node.get::<Array>("Nums") {
        let items: Vec<Object> = nums.iter::<Object>().collect();
        for pair in items.chunks(2) {
            if let [Object::Number(k), v] = pair {
                out.push((k.as_i64(), v.clone()));
            }
        }
    }
    if let Some(kids) = node.get::<Array>("Kids") {
        for kid in kids.iter::<Dict>() {
            number_tree(&kid, out);
        }
    }
}

/// Collect the page references of a page tree in order.
fn page_refs(node: &Dict, out: &mut Vec<ObjRef>) {
    if let Some(kids) = node.get::<Array>("Kids") {
        for (raw, kid) in kids.raw_iter().zip(kids.iter::<Dict>()) {
            let Some(r) = raw.as_obj_ref() else { continue };
            let ty = kid.get::<Name>("Type").map(|n| n.as_str().to_string());
            if ty.as_deref() == Some("Pages") {
                page_refs(&kid, out);
            } else {
                out.push(r);
            }
        }
    }
}

/// Extract the canonical semantic description of a PDF.
pub fn extract(bytes: &[u8]) -> Result<String, String> {
    let pdf = Pdf::new(Arc::new(bytes.to_vec())).map_err(|e| format!("{e:?}"))?;
    extract_inner(bytes, &pdf)
}

fn extract_inner(bytes: &[u8], pdf: &Pdf) -> Result<String, String> {
    let mut out = String::new();
    let version = bytes
        .strip_prefix(b"%PDF-")
        .map(|r| String::from_utf8_lossy(&r[..3.min(r.len())]).into_owned())
        .unwrap_or_default();
    writeln!(out, "version {version}").unwrap();

    let meta = pdf.metadata();
    for (key, val) in [
        ("Title", &meta.title),
        ("Author", &meta.author),
        ("Subject", &meta.subject),
        ("Keywords", &meta.keywords),
        ("Creator", &meta.creator),
    ] {
        if let Some(v) = val {
            writeln!(out, "info {key} {:?}", text_string(v)).unwrap();
        }
    }
    if let Some(d) = &meta.creation_date {
        let sign = if d.utc_offset_hour < 0 { '-' } else { '+' };
        writeln!(
            out,
            "info CreationDate {:04}-{:02}-{:02} {:02}:{:02}:{:02} {sign}{:02}:{:02}",
            d.year,
            d.month,
            d.day,
            d.hour,
            d.minute,
            d.second,
            d.utc_offset_hour.unsigned_abs(),
            d.utc_offset_minute
        )
        .unwrap();
    }

    let catalog = pdf.xref().get::<Dict>(pdf.xref().root_id()).ok_or("missing catalog")?;
    if let Some(lang) = catalog.get::<Object>("Lang").and_then(|o| obj_str(&o)) {
        writeln!(out, "catalog lang {lang:?}").unwrap();
    }
    if let Some(vp) = catalog.get::<Dict>("ViewerPreferences")
        && let Some(b) = vp.get::<bool>("DisplayDocTitle")
    {
        writeln!(out, "catalog display-doc-title {b}").unwrap();
    }
    if let Some(mi) = catalog.get::<Dict>("MarkInfo")
        && let Some(b) = mi.get::<bool>("Marked")
    {
        writeln!(out, "catalog marked {b}").unwrap();
    }
    writeln!(out, "catalog struct-tree {}", catalog.contains_key("StructTreeRoot")).unwrap();

    if let Some(stream) = catalog.get::<Stream>("Metadata") {
        let data = stream.decoded().map_err(|e| format!("{e:?}"))?;
        let xml = String::from_utf8_lossy(&data);
        for key in ["dc:language", "pdfaid:part", "pdfaid:conformance", "pdfuaid:part"] {
            if let Some(v) = xmp_value(&xml, key) {
                writeln!(out, "xmp {key} {v:?}").unwrap();
            }
        }
    }

    // Pages and named destinations.
    let pages_dict = catalog.get::<Dict>("Pages").ok_or("missing pages")?;
    let mut pages = vec![];
    page_refs(&pages_dict, &mut pages);
    let mut named_list = vec![];
    if let Some(names) = catalog.get::<Dict>("Names")
        && let Some(dests) = names.get::<Dict>("Dests")
    {
        name_tree(&dests, &mut named_list);
    }
    if let Some(dests) = catalog.get::<Dict>("Dests") {
        let keys: Vec<String> = dests.keys().map(|k| k.as_str().to_string()).collect();
        for k in keys {
            if let Some(v) = dests.get::<Object>(k.as_str()) {
                named_list.push((k, v));
            }
        }
    }
    let doc = Doc { pdf, pages, named: named_list.iter().cloned().collect() };
    let _ = doc.pdf;

    if let Some(labels) = catalog.get::<Dict>("PageLabels") {
        let mut entries = vec![];
        number_tree(&labels, &mut entries);
        for (idx, label) in entries {
            let Object::Dict(label) = label else { continue };
            let style = label.get::<Name>("S").map(|n| n.as_str().to_string());
            let prefix = label.get::<Object>("P").and_then(|o| obj_str(&o));
            let start = label.get::<Object>("St").and_then(|o| obj_f64(&o));
            write!(out, "label {idx} style={}", style.as_deref().unwrap_or("-")).unwrap();
            if let Some(p) = prefix {
                write!(out, " prefix={p:?}").unwrap();
            }
            if let Some(s) = start {
                write!(out, " start={}", s as i64).unwrap();
            }
            out.push('\n');
        }
    }

    for (i, page) in pdf.pages().iter().enumerate() {
        let raw = page.raw();
        let media = raw.get::<Array>("MediaBox").and_then(|a| rect_of(&a));
        write!(out, "page {i} media {}", media.map(fmt_rect).unwrap_or("?".into())).unwrap();
        if let Some(trim) = raw.get::<Array>("TrimBox").and_then(|a| rect_of(&a)) {
            write!(out, " trim {}", fmt_rect(trim)).unwrap();
        }
        out.push('\n');

        let mut interp = Interp::new(&mut out);
        let resources = raw.get::<Dict>("Resources").unwrap_or_default();
        if let Some(content) = page.page_stream() {
            interp.run(content, &resources, IDENTITY, 0);
        }
        interp.flush();

        if let Some(annots) = raw.get::<Array>("Annots") {
            for annot in annots.iter::<Dict>() {
                let subtype = annot.get::<Name>("Subtype").map(|n| n.as_str().to_string()).unwrap_or_default();
                let rect = annot.get::<Array>("Rect").and_then(|a| rect_of(&a));
                write!(
                    out,
                    "  annot {subtype} {} {}",
                    rect.map(fmt_rect).unwrap_or("?".into()),
                    doc.target(&annot)
                )
                .unwrap();
                if let Some(c) = annot.get::<Object>("Contents").and_then(|o| obj_str(&o)) {
                    write!(out, " contents {c:?}").unwrap();
                }
                out.push('\n');
            }
        }
    }

    let mut sorted = named_list.clone();
    sorted.sort_by(|a, b| a.0.cmp(&b.0));
    for (name, _) in &sorted {
        let target = doc.named_target(name);
        writeln!(out, "dest {name:?} {target}").unwrap();
    }

    if let Some(outlines) = catalog.get::<Dict>("Outlines")
        && let Some(first) = outlines.get::<Dict>("First")
    {
        outline_items(&doc, first, 0, &mut out);
    }

    if let Some(names) = catalog.get::<Dict>("Names")
        && let Some(files) = names.get::<Dict>("EmbeddedFiles")
    {
        let mut entries = vec![];
        name_tree(&files, &mut entries);
        for (name, spec) in entries {
            let Object::Dict(spec) = spec else { continue };
            let uf = spec.get::<Object>("UF").and_then(|o| obj_str(&o)).unwrap_or_default();
            let desc = spec.get::<Object>("Desc").and_then(|o| obj_str(&o));
            let rel = spec.get::<Name>("AFRelationship").map(|n| n.as_str().to_string());
            let ef = spec.get::<Dict>("EF").and_then(|ef| ef.get::<Stream>("F"));
            let mime = ef
                .as_ref()
                .and_then(|s| s.dict().get::<Name>("Subtype"))
                .map(|n| n.as_str().to_string());
            let size = ef.as_ref().and_then(|s| s.decoded().ok()).map(|d| d.len());
            write!(out, "attach {name:?} uf={uf:?}").unwrap();
            if let Some(d) = desc {
                write!(out, " desc={d:?}").unwrap();
            }
            write!(
                out,
                " rel={} mime={} size={}\n",
                rel.as_deref().unwrap_or("-"),
                mime.as_deref().unwrap_or("-"),
                size.map(|s| s.to_string()).unwrap_or("?".into())
            )
            .unwrap();
        }
    }

    Ok(out)
}

fn outline_items(doc: &Doc, item: Dict, depth: usize, out: &mut String) {
    let mut cur = Some(item);
    while let Some(item) = cur {
        let title = item.get::<Object>("Title").and_then(|o| obj_str(&o)).unwrap_or_default();
        writeln!(out, "outline {}{title:?} {}", "  ".repeat(depth), doc.target(&item)).unwrap();
        if let Some(first) = item.get::<Dict>("First") {
            outline_items(doc, first, depth + 1, out);
        }
        cur = item.get::<Dict>("Next");
    }
}

/// Find the value of an XMP property, given either as an element (possibly
/// containing an `rdf:Alt`/`rdf:Bag`/`rdf:Seq` with `rdf:li` items, of which
/// the first is taken) or as an attribute.
pub fn xmp_value(xml: &str, key: &str) -> Option<String> {
    let attr = format!("{key}=\"");
    if let Some(at) = xml.find(&attr) {
        let rest = &xml[at + attr.len()..];
        return rest.find('"').map(|end| xml_unescape(&rest[..end]));
    }
    let open = format!("<{key}");
    let at = xml.find(&open)?;
    let rest = &xml[at + open.len()..];
    let gt = rest.find('>')?;
    if rest[..gt].ends_with('/') {
        return Some(String::new());
    }
    let body = &rest[gt + 1..];
    let close = format!("</{key}>");
    let end = body.find(&close)?;
    let body = &body[..end];
    if let Some(li) = body.find("<rdf:li") {
        let rest = &body[li..];
        let gt = rest.find('>')?;
        let inner = &rest[gt + 1..];
        let end = inner.find("</rdf:li>")?;
        return Some(xml_unescape(&inner[..end]));
    }
    Some(xml_unescape(body.trim()))
}

fn xml_unescape(s: &str) -> String {
    s.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&amp;", "&")
}

// ---------------------------------------------------------------------------
// Content stream interpretation
// ---------------------------------------------------------------------------

#[derive(Clone)]
struct Paint {
    space: String,
    comps: Vec<f64>,
    pattern: Option<String>,
}

impl Paint {
    fn new(space: &str) -> Self {
        let comps = match space {
            "rgb" => vec![0.0, 0.0, 0.0],
            "cmyk" => vec![0.0, 0.0, 0.0, 1.0],
            _ => vec![0.0],
        };
        Self { space: space.into(), comps, pattern: None }
    }

    fn fmt(&self, alpha: f64) -> String {
        let mut s = if let Some(p) = &self.pattern {
            format!("pattern({p})")
        } else {
            let comps: Vec<String> = self.comps.iter().map(|c| num3(*c)).collect();
            format!("{}({})", self.space, comps.join(","))
        };
        if alpha != 1.0 {
            write!(s, "@{}", num(alpha)).unwrap();
        }
        s
    }
}

#[derive(Clone)]
struct GState {
    ctm: Matrix,
    fill: Paint,
    stroke: Paint,
    fill_alpha: f64,
    stroke_alpha: f64,
    soft_mask: bool,
}

struct TextBlock {
    origin: Option<(f64, f64)>,
    size: f64,
    font: String,
    fill: String,
    text: String,
}

struct Interp<'o> {
    out: &'o mut String,
    stack: Vec<GState>,
    gs: GState,
    tm: Matrix,
    tlm: Matrix,
    font: Option<FontInfo>,
    font_size: f64,
    rise: f64,
    leading: f64,
    block: Option<TextBlock>,
    /// Stack of marked-content sequences: `Some(text)` if it carries
    /// `/ActualText`.
    marked: Vec<Option<String>>,
    path: Vec<(f64, f64)>,
}

#[derive(Clone)]
struct FontInfo {
    name: String,
    two_byte: bool,
    to_unicode: HashMap<u32, String>,
}

impl<'o> Interp<'o> {
    fn new(out: &'o mut String) -> Self {
        let gs = GState {
            ctm: IDENTITY,
            fill: Paint::new("gray"),
            stroke: Paint::new("gray"),
            fill_alpha: 1.0,
            stroke_alpha: 1.0,
            soft_mask: false,
        };
        Self {
            out,
            stack: vec![],
            gs,
            tm: IDENTITY,
            tlm: IDENTITY,
            font: None,
            font_size: 0.0,
            rise: 0.0,
            leading: 0.0,
            block: None,
            marked: vec![],
            path: vec![],
        }
    }

    fn flush(&mut self) {
        if let Some(b) = self.block.take()
            && let Some((x, y)) = b.origin
        {
            writeln!(
                self.out,
                "  text [{} {}] {} {} {} {:?}",
                num(x),
                num(y),
                num(b.size),
                b.font,
                b.fill,
                b.text
            )
            .unwrap();
        }
    }

    fn in_actual_text(&self) -> bool {
        self.marked.iter().any(|m| m.is_some())
    }

    fn run(&mut self, content: &[u8], resources: &Dict, base: Matrix, depth: usize) {
        if depth > 16 {
            return;
        }
        let saved_ctm = self.gs.ctm;
        self.gs.ctm = mul(&base, &self.gs.ctm);
        let stack_depth = self.stack.len();
        let mut iter = hayro_syntax::content::UntypedIter::new(content);
        while let Some(instr) = iter.next() {
            let op = std::str::from_utf8(&instr.operator).unwrap_or("").to_string();
            let args: Vec<Object> = instr.operands().cloned().collect();
            self.op(&op, &args, resources, depth);
        }
        while self.stack.len() > stack_depth {
            self.gs = self.stack.pop().unwrap();
        }
        self.gs.ctm = saved_ctm;
    }

    fn nums(args: &[Object]) -> Vec<f64> {
        args.iter().filter_map(obj_f64).collect()
    }

    fn color_space(&self, name: &str, resources: &Dict) -> String {
        match name {
            "DeviceRGB" | "RGB" | "CalRGB" => return "rgb".into(),
            "DeviceGray" | "G" | "CalGray" => return "gray".into(),
            "DeviceCMYK" | "CMYK" => return "cmyk".into(),
            "Pattern" => return "pattern".into(),
            _ => {}
        }
        let Some(cs) = resources.get::<Dict>("ColorSpace") else { return name.into() };
        match cs.get::<Object>(name) {
            Some(Object::Name(n)) => self.color_space(n.as_str(), resources),
            Some(Object::Array(a)) => {
                let kind = a.iter::<Object>().next().and_then(|o| obj_str(&o)).unwrap_or_default();
                match kind.as_str() {
                    "ICCBased" => {
                        let n = a
                            .iter::<Object>()
                            .nth(1)
                            .and_then(|o| o.into_stream())
                            .and_then(|s| s.dict().get::<i64>("N"))
                            .unwrap_or(0);
                        match n {
                            1 => "gray".into(),
                            3 => "rgb".into(),
                            4 => "cmyk".into(),
                            _ => "icc".into(),
                        }
                    }
                    "Separation" => {
                        let colorant =
                            a.iter::<Object>().nth(1).and_then(|o| obj_str(&o)).unwrap_or_default();
                        format!("sep[{colorant}]")
                    }
                    "Pattern" => "pattern".into(),
                    "CalRGB" => "rgb".into(),
                    "CalGray" => "gray".into(),
                    "Lab" => "lab".into(),
                    "Indexed" => "indexed".into(),
                    "DeviceN" => "devicen".into(),
                    other => other.into(),
                }
            }
            _ => name.into(),
        }
    }

    fn pattern_kind(&self, name: &str, resources: &Dict) -> String {
        let Some(pats) = resources.get::<Dict>("Pattern") else { return "?".into() };
        let (dict, is_stream) = match pats.get::<Object>(name) {
            Some(Object::Dict(d)) => (d, false),
            Some(Object::Stream(s)) => (s.dict().clone(), true),
            _ => return "?".into(),
        };
        let _ = is_stream;
        match dict.get::<i64>("PatternType") {
            Some(1) => "tiling".into(),
            Some(2) => {
                let st = dict
                    .get::<Object>("Shading")
                    .and_then(|o| match o {
                        Object::Dict(d) => d.get::<i64>("ShadingType"),
                        Object::Stream(s) => s.dict().get::<i64>("ShadingType"),
                        _ => None,
                    })
                    .unwrap_or(0);
                format!("shading{st}")
            }
            _ => "?".into(),
        }
    }

    fn set_color(&mut self, stroke: bool, args: &[Object], resources: &Dict) {
        let pattern = args.last().and_then(|o| match o {
            Object::Name(n) => Some(n.as_str().to_string()),
            _ => None,
        });
        let comps = Self::nums(args);
        let kind = pattern.map(|p| self.pattern_kind(&p, resources));
        let paint = if stroke { &mut self.gs.stroke } else { &mut self.gs.fill };
        paint.pattern = kind;
        if !comps.is_empty() {
            paint.comps = comps;
        }
    }

    fn font_info(&self, name: &str, resources: &Dict) -> Option<FontInfo> {
        let fonts = resources.get::<Dict>("Font")?;
        let font = fonts.get::<Dict>(name)?;
        let subtype = font.get::<Name>("Subtype").map(|n| n.as_str().to_string()).unwrap_or_default();
        let mut base = font.get::<Name>("BaseFont").map(|n| n.as_str().to_string()).unwrap_or_else(|| {
            if subtype == "Type3" { "Type3".into() } else { "?".into() }
        });
        if base.len() > 7 && base.as_bytes()[6] == b'+' && base[..6].bytes().all(|b| b.is_ascii_uppercase()) {
            base = base[7..].to_string();
        }
        if let Some(stripped) = base.strip_suffix("-Identity-H") {
            base = stripped.to_string();
        }
        let mut to_unicode = HashMap::new();
        if let Some(stream) = font.get::<Stream>("ToUnicode")
            && let Ok(data) = stream.decoded()
        {
            parse_to_unicode(&data, &mut to_unicode);
        }
        Some(FontInfo { name: base, two_byte: subtype == "Type0", to_unicode })
    }

    fn show(&mut self, s: &[u8]) {
        let Some(font) = self.font.clone() else { return };
        if self.block.is_none() {
            return;
        }
        let trm = mul(&[self.font_size, 0.0, 0.0, self.font_size, 0.0, self.rise], &mul(&self.tm, &self.gs.ctm));
        let in_actual = self.in_actual_text();
        let fill = self.gs.fill.fmt(self.gs.fill_alpha);
        let block = self.block.as_mut().unwrap();
        if block.origin.is_none() {
            let (x, y) = apply(&mul(&[1.0, 0.0, 0.0, 1.0, 0.0, self.rise], &mul(&self.tm, &self.gs.ctm)), 0.0, 0.0);
            block.origin = Some((x, y));
            block.size = (trm[0] * trm[3] - trm[1] * trm[2]).abs().sqrt();
            block.font = font.name.clone();
            block.fill = fill;
        }
        let step = if font.two_byte { 2 } else { 1 };
        for chunk in s.chunks(step) {
            let code = chunk.iter().fold(0u32, |acc, &b| (acc << 8) | b as u32);
            if !in_actual {
                if let Some(t) = font.to_unicode.get(&code) {
                    block.text.push_str(t);
                }
            }
        }
        // Advance positions are not tracked: only the origin of the first
        // glyph of a block is reported.
    }

    fn op(&mut self, op: &str, args: &[Object], resources: &Dict, depth: usize) {
        let n = Self::nums(args);
        match op {
            "q" => self.stack.push(self.gs.clone()),
            "Q" => {
                if let Some(gs) = self.stack.pop() {
                    self.gs = gs;
                }
            }
            "cm" if n.len() == 6 => {
                self.gs.ctm = mul(&[n[0], n[1], n[2], n[3], n[4], n[5]], &self.gs.ctm);
            }
            "gs" => {
                if let Some(Object::Name(name)) = args.first()
                    && let Some(egs) = resources.get::<Dict>("ExtGState")
                    && let Some(d) = egs.get::<Dict>(name.as_str())
                {
                    if let Some(ca) = d.get::<f64>("ca") {
                        self.gs.fill_alpha = ca;
                    }
                    if let Some(ca) = d.get::<f64>("CA") {
                        self.gs.stroke_alpha = ca;
                    }
                    if let Some(sm) = d.get::<Object>("SMask") {
                        self.gs.soft_mask = !matches!(sm, Object::Name(_));
                    }
                }
            }
            "g" | "G" | "rg" | "RG" | "k" | "K" => {
                let space = match op {
                    "g" | "G" => "gray",
                    "rg" | "RG" => "rgb",
                    _ => "cmyk",
                };
                let paint = Paint { space: space.into(), comps: n, pattern: None };
                if op.chars().next().unwrap().is_uppercase() {
                    self.gs.stroke = paint;
                } else {
                    self.gs.fill = paint;
                }
            }
            "cs" | "CS" => {
                let name = args.first().and_then(obj_str).unwrap_or_default();
                let space = self.color_space(&name, resources);
                if op == "CS" {
                    self.gs.stroke = Paint::new(&space);
                } else {
                    self.gs.fill = Paint::new(&space);
                }
            }
            "sc" | "scn" => self.set_color(false, args, resources),
            "SC" | "SCN" => self.set_color(true, args, resources),
            "BT" => {
                self.tm = IDENTITY;
                self.tlm = IDENTITY;
                self.block = Some(TextBlock {
                    origin: None,
                    size: 0.0,
                    font: String::new(),
                    fill: String::new(),
                    text: String::new(),
                });
            }
            "ET" => self.flush(),
            "Tf" => {
                if let Some(Object::Name(name)) = args.first() {
                    self.font = self.font_info(name.as_str(), resources);
                }
                if let Some(s) = n.first() {
                    self.font_size = *s;
                }
            }
            "Ts" => self.rise = n.first().copied().unwrap_or(0.0),
            "TL" => self.leading = n.first().copied().unwrap_or(0.0),
            "Tm" if n.len() == 6 => {
                self.tm = [n[0], n[1], n[2], n[3], n[4], n[5]];
                self.tlm = self.tm;
            }
            "Td" | "TD" if n.len() == 2 => {
                if op == "TD" {
                    self.leading = -n[1];
                }
                self.tlm = mul(&[1.0, 0.0, 0.0, 1.0, n[0], n[1]], &self.tlm);
                self.tm = self.tlm;
            }
            "T*" => {
                self.tlm = mul(&[1.0, 0.0, 0.0, 1.0, 0.0, -self.leading], &self.tlm);
                self.tm = self.tlm;
            }
            "Tj" | "'" | "\"" => {
                if let Some(Object::String(s)) = args.last() {
                    self.show(s.as_bytes());
                }
            }
            "TJ" => {
                if let Some(Object::Array(a)) = args.first() {
                    for item in a.iter::<Object>() {
                        if let Object::String(s) = item {
                            self.show(s.as_bytes());
                        }
                    }
                }
            }
            "BMC" => self.marked.push(None),
            "BDC" => {
                let props = match args.get(1) {
                    Some(Object::Dict(d)) => Some(d.clone()),
                    Some(Object::Name(n)) => resources
                        .get::<Dict>("Properties")
                        .and_then(|p| p.get::<Dict>(n.as_str())),
                    _ => None,
                };
                let actual = props
                    .and_then(|p| p.get::<Object>("ActualText"))
                    .and_then(|o| obj_str(&o));
                if let Some(t) = &actual
                    && !self.in_actual_text()
                    && let Some(block) = self.block.as_mut()
                {
                    block.text.push_str(t);
                }
                self.marked.push(actual);
            }
            "EMC" => {
                self.marked.pop();
            }
            "m" | "l" if n.len() == 2 => self.path.push(apply(&self.gs.ctm, n[0], n[1])),
            "c" if n.len() == 6 => {
                for i in 0..3 {
                    self.path.push(apply(&self.gs.ctm, n[2 * i], n[2 * i + 1]));
                }
            }
            "v" | "y" if n.len() == 4 => {
                for i in 0..2 {
                    self.path.push(apply(&self.gs.ctm, n[2 * i], n[2 * i + 1]));
                }
            }
            "re" if n.len() == 4 => {
                for (x, y) in [(n[0], n[1]), (n[0] + n[2], n[1]), (n[0] + n[2], n[1] + n[3]), (n[0], n[1] + n[3])] {
                    self.path.push(apply(&self.gs.ctm, x, y));
                }
            }
            "h" => {}
            "n" => self.path.clear(),
            "W" | "W*" => {}
            "f" | "F" | "f*" | "S" | "s" | "B" | "B*" | "b" | "b*" => {
                let path = std::mem::take(&mut self.path);
                let (mut x0, mut y0, mut x1, mut y1) = (f64::INFINITY, f64::INFINITY, f64::NEG_INFINITY, f64::NEG_INFINITY);
                for (x, y) in &path {
                    x0 = x0.min(*x);
                    y0 = y0.min(*y);
                    x1 = x1.max(*x);
                    y1 = y1.max(*y);
                }
                let op = if op == "F" { "f" } else { op };
                let fills = !matches!(op, "S" | "s");
                let strokes = matches!(op, "S" | "s" | "B" | "B*" | "b" | "b*");
                write!(self.out, "  path {op} {}", if path.is_empty() { "[]".into() } else { fmt_rect([x0, y0, x1, y1]) }).unwrap();
                if fills {
                    write!(self.out, " fill={}", self.gs.fill.fmt(self.gs.fill_alpha)).unwrap();
                }
                if strokes {
                    write!(self.out, " stroke={}", self.gs.stroke.fmt(self.gs.stroke_alpha)).unwrap();
                }
                if self.gs.soft_mask {
                    write!(self.out, " smask").unwrap();
                }
                self.out.push('\n');
            }
            "sh" => {
                let name = args.first().and_then(obj_str).unwrap_or_default();
                let ty = resources
                    .get::<Dict>("Shading")
                    .and_then(|s| s.get::<Object>(name.as_str()))
                    .and_then(|o| match o {
                        Object::Dict(d) => d.get::<i64>("ShadingType"),
                        Object::Stream(s) => s.dict().get::<i64>("ShadingType"),
                        _ => None,
                    })
                    .unwrap_or(0);
                writeln!(self.out, "  shading {ty}").unwrap();
            }
            "Do" => {
                let name = args.first().and_then(obj_str).unwrap_or_default();
                let Some(xobjects) = resources.get::<Dict>("XObject") else { return };
                let Some(stream) = xobjects.get::<Stream>(name.as_str()) else { return };
                let dict = stream.dict().clone();
                let subtype = dict.get::<Name>("Subtype").map(|n| n.as_str().to_string()).unwrap_or_default();
                if subtype == "Image" {
                    let w = dict.get::<i64>("Width").unwrap_or(0);
                    let h = dict.get::<i64>("Height").unwrap_or(0);
                    let filter = match dict.get::<Object>("Filter") {
                        Some(Object::Name(n)) => n.as_str().to_string(),
                        Some(Object::Array(a)) => a.iter::<Object>().last().and_then(|o| obj_str(&o)).unwrap_or_default(),
                        _ => String::new(),
                    };
                    let cs = match dict.get::<Object>("ColorSpace") {
                        Some(Object::Name(n)) => self.color_space(n.as_str(), &Dict::default()),
                        Some(Object::Array(a)) => {
                            let kind = a.iter::<Object>().next().and_then(|o| obj_str(&o)).unwrap_or_default();
                            if kind == "ICCBased" {
                                let n = a
                                    .iter::<Object>()
                                    .nth(1)
                                    .and_then(|o| o.into_stream())
                                    .and_then(|s| s.dict().get::<i64>("N"))
                                    .unwrap_or(0);
                                match n {
                                    1 => "gray".into(),
                                    3 => "rgb".into(),
                                    4 => "cmyk".into(),
                                    _ => "icc".into(),
                                }
                            } else {
                                kind.to_lowercase()
                            }
                        }
                        _ => "-".into(),
                    };
                    let bpc = dict.get::<i64>("BitsPerComponent").unwrap_or(0);
                    let m = &self.gs.ctm;
                    write!(self.out, "  image {w}x{h} {cs} bpc={bpc}").unwrap();
                    if filter == "DCTDecode" {
                        write!(self.out, " jpeg").unwrap();
                    }
                    if dict.contains_key("SMask") {
                        write!(self.out, " smask").unwrap();
                    }
                    if dict.get::<bool>("Interpolate") == Some(true) {
                        write!(self.out, " interpolate").unwrap();
                    }
                    writeln!(
                        self.out,
                        " [{} {} {} {} {} {}]",
                        num(m[0]),
                        num(m[1]),
                        num(m[2]),
                        num(m[3]),
                        num(m[4]),
                        num(m[5])
                    )
                    .unwrap();
                } else if subtype == "Form" {
                    let matrix = dict.get::<Array>("Matrix").and_then(|a| matrix_of(&a)).unwrap_or(IDENTITY);
                    let res = dict.get::<Dict>("Resources").unwrap_or_default();
                    if let Ok(data) = stream.decoded() {
                        self.stack.push(self.gs.clone());
                        // Text blocks of the form are reported separately.
                        let outer = self.block.take();
                        let font = self.font.clone();
                        self.run(&data, &res, matrix, depth + 1);
                        self.flush();
                        self.block = outer;
                        self.font = font;
                        self.gs = self.stack.pop().unwrap();
                    }
                }
            }
            _ => {}
        }
    }
}

/// Parse the `bfchar`/`bfrange` sections of a ToUnicode CMap.
pub fn parse_to_unicode(data: &[u8], map: &mut HashMap<u32, String>) {
    let text = String::from_utf8_lossy(data);
    let tokens = tokenize_cmap(&text);
    let mut i = 0;
    let hex = |s: &str| -> Option<Vec<u8>> {
        let s = s.strip_prefix('<')?.strip_suffix('>')?;
        let s: String = s.chars().filter(|c| !c.is_whitespace()).collect();
        (0..s.len() / 2).map(|k| u8::from_str_radix(&s[2 * k..2 * k + 2], 16).ok()).collect()
    };
    let code = |b: &[u8]| b.iter().fold(0u32, |acc, &x| (acc << 8) | x as u32);
    let utf16 = |b: &[u8]| {
        let units: Vec<u16> = b.chunks(2).filter(|c| c.len() == 2).map(|c| u16::from_be_bytes([c[0], c[1]])).collect();
        String::from_utf16_lossy(&units)
    };
    while i < tokens.len() {
        match tokens[i].as_str() {
            "beginbfchar" => {
                i += 1;
                while i + 1 < tokens.len() && tokens[i] != "endbfchar" {
                    if let (Some(src), Some(dst)) = (hex(&tokens[i]), hex(&tokens[i + 1])) {
                        map.insert(code(&src), utf16(&dst));
                    }
                    i += 2;
                }
            }
            "beginbfrange" => {
                i += 1;
                while i + 2 < tokens.len() && tokens[i] != "endbfrange" {
                    let lo = hex(&tokens[i]).map(|b| code(&b));
                    let hi = hex(&tokens[i + 1]).map(|b| code(&b));
                    if tokens[i + 2] == "[" {
                        let mut j = i + 3;
                        let mut k = 0;
                        while j < tokens.len() && tokens[j] != "]" {
                            if let (Some(lo), Some(dst)) = (lo, hex(&tokens[j])) {
                                map.insert(lo + k, utf16(&dst));
                            }
                            k += 1;
                            j += 1;
                        }
                        i = j + 1;
                    } else {
                        if let (Some(lo), Some(hi), Some(dst)) = (lo, hi, hex(&tokens[i + 2])) {
                            for c in lo..=hi.min(lo + 0xFFFF) {
                                let mut d = dst.clone();
                                let off = c - lo;
                                if let Some(last) = d.last_mut() {
                                    let v = *last as u32 + off;
                                    *last = (v & 0xFF) as u8;
                                }
                                map.insert(c, utf16(&d));
                            }
                        }
                        i += 3;
                    }
                }
            }
            _ => {}
        }
        i += 1;
    }
}

fn tokenize_cmap(text: &str) -> Vec<String> {
    let mut tokens = vec![];
    let chars: Vec<char> = text.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
        } else if c == '%' {
            while i < chars.len() && chars[i] != '\n' && chars[i] != '\r' {
                i += 1;
            }
        } else if c == '<' {
            let start = i;
            while i < chars.len() && chars[i] != '>' {
                i += 1;
            }
            i += 1;
            tokens.push(chars[start..i.min(chars.len())].iter().collect());
        } else if c == '[' || c == ']' {
            tokens.push(c.to_string());
            i += 1;
        } else if c == '(' {
            let mut depth = 0;
            let start = i;
            while i < chars.len() {
                if chars[i] == '\\' {
                    i += 2;
                    continue;
                }
                if chars[i] == '(' {
                    depth += 1;
                }
                if chars[i] == ')' {
                    depth -= 1;
                    if depth == 0 {
                        i += 1;
                        break;
                    }
                }
                i += 1;
            }
            tokens.push(chars[start..i.min(chars.len())].iter().collect());
        } else {
            let start = i;
            while i < chars.len() && !chars[i].is_whitespace() && !"<>[]()/%".contains(chars[i]) {
                i += 1;
            }
            if i == start {
                i += 1;
            }
            tokens.push(chars[start..i].iter().collect());
        }
    }
    tokens
}
