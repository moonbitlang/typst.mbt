//! The `paged` stage: compile every test case that the upstream test runner
//! compiles to a `PagedDocument` and dump the document in the
//! `typst-frame-v1` format.
//!
//! # Selection
//!
//! Upstream (`tests/src/run.rs`) compiles a paged document when
//! `attrs.implied_stages().with_required()` contains `PAGED`, i.e. for tests
//! with a `paged`, `pdf` or `pdftags` attribute (the latter two require the
//! paged target). Files starting with `// SKIP` are not collected at all, and
//! `tests/skip.txt` is empty. At the pinned revision this selects 2169 tests
//! with a literal `paged` attribute (none of them in a skipped file, no
//! duplicate names) plus 130 `pdf`/`pdftags`-only tests: 2299 in total. The
//! "2168 runnable cases" figure quoted in `docs/p4-plan.md` could not be
//! reproduced from the collector; the literal header count (2169) is the
//! number of `paged` tests the collector runs.
//!
//! The document is compiled with `typst::compile` exactly like upstream, but
//! without the harness' post-processing (upstream sets the document title to
//! the test name if it has none, which only matters for PDF export).
//!
//! # Format (`typst-frame-v1`)
//!
//! Each test case is a `=== <name>` line followed by records, one canonical
//! JSON array per line:
//!
//! ```text
//! ["header","typst-frame-v1",revision,font_manifest_sha256,test_name]
//! ["diagnostics",status,lines]
//! ["document",info,format_options,page_count]
//! ["font",F,asset_sha256,face_index,variations,family,postscript_name,upem]
//! ["image-resource",I,kind,asset_sha256,page_index,intrinsic_size,dpi,exif,icc_sha256,dependencies]
//! ["content",C,canonical_content]
//! ["page",P,logical_number,bleed,fill,numbering,supplement_C]
//! ["frame",R,size,explicit_baseline_or_null,"soft"|"hard",item_count]
//! ["group",R,index,position,child_R,transform,clip,label,parent]
//! ["text",R,index,position,F,size,fill,stroke,lang,region,text,glyphs]
//! ["shape",R,index,position,geometry,fill,fill_rule,stroke,span]
//! ["image",R,index,position,I,size,alt,scaling,span]
//! ["link",R,index,position,size,destination]
//! ["tag-start",R,index,position,L,C,introspectable,tagged]
//! ["tag-end",R,index,position,L,K,introspectable,tagged]
//! ["end"]
//! ```
//!
//! - `revision` is the trimmed content of `UPSTREAM_REV`;
//!   `font_manifest_sha256` is the SHA-256 of `tests/golden/fonts.json`.
//! - `diagnostics`: `status` is `"ok"` or `"err"`; `lines` are the
//!   diagnostic lines of the other stages (`error 1..2 "msg"`,
//!   `  hint ...`, see `eval::write_diag`) without the trailing newline:
//!   the deduplicated errors (if any), then the deduplicated warnings. If
//!   compilation failed, `["end"]` follows directly.
//! - Numbers: integers are JSON integers; an `f64` is the string `"f64:"`
//!   followed by the 16 lowercase hex digits of its IEEE-754 bits, an `f32`
//!   is `"f32:"` plus 8 digits. Lengths (`Abs`) are encoded raw
//!   (`Abs::to_raw`, 127 units per pt), `Em`, `Ratio` and `Scalar` by their
//!   value and angles in radians (`Angle::to_raw`).
//! - Strings use JSON escapes only for `"`, `\` and control characters
//!   below U+0020 (`\b \t \n \f \r`, else `\u00xx`).
//! - `point`/`position` is `[x,y]`, `size` is `[w,h]` (frame-local,
//!   x-right/y-down). A transform is `[sx,ky,kx,sy,tx,ty]` (ratios, then
//!   raw lengths). Sides are `[left,top,right,bottom]`.
//! - Identities: `F` (fonts, keyed by their record), `I` (images, keyed by
//!   their record), `C` (content, keyed by its canonical string), `L`
//!   (locations) and `K` (tag key hashes) are integers assigned in order of
//!   first encounter. `font`, `image-resource` and `content` records are
//!   emitted right before the first record referencing them. Locations
//!   share their numbering with the `#n` references in canonical content.
//! - Frame ids `R` are structural paths: `p<P>` for a page's frame,
//!   `<R>/<index>` for the frame of the group at `index`, `<R>/<index>/fill`
//!   and `<R>/<index>/stroke` for tiling frames of an item's paints and
//!   `p<P>/fill` for a tiling page fill. A frame's records (`frame`, then
//!   its items) directly follow the record that references it: pages and
//!   items are walked in stored order, depth-first.
//! - `glyphs` is an array of `[id,x_advance,y_advance,x_offset,y_offset,
//!   byte_start,byte_end,span,span_offset]` (advances/offsets in em, y-up).
//! - `span` is `null` (detached) or `[path,start,end]` with the virtual path
//!   of the file (`@namespace/name:version/` prefixed for packages) and the
//!   resolved UTF-8 byte range (`null`s if unresolvable).
//! - `geometry` is `["line",point]`, `["rect",size]` or `["curve",commands]`
//!   where commands are `["M",p]`, `["L",p]`, `["C",p1,p2,p3]`, `["Z"]`.
//!   A `clip` is `null` or a command list.
//! - `stroke` is `null` or `[paint,thickness,cap,join,dash,miter_limit]`
//!   with `cap` in `butt|round|square`, `join` in `miter|round|bevel` and
//!   `dash` `null` or `[[lengths],phase]`.
//! - `paint` is `["solid",color]`,
//!   `["linear",stops,angle,space,relative,anti_alias]`,
//!   `["radial",stops,center,radius,focal_center,focal_radius,space,relative,anti_alias]`,
//!   `["conic",stops,angle,center,space,relative,anti_alias]` or
//!   `["tiling",R,size,spacing,offset,angle,relative]`; stops are
//!   `[[color,ratio]]`, centers `[x,y]` ratios, `relative` is
//!   `"auto"|"self"|"parent"`.
//! - `color` is `["Luma",l,a]`, `["Oklab",l,a,b,alpha]`,
//!   `["Oklch",l,chroma,hue,alpha]`, `["Rgb",r,g,b,a]`,
//!   `["LinearRgb",r,g,b,a]`, `["Cmyk",c,m,y,k]`, `["Hsl",h,s,l,a]`,
//!   `["Hsv",h,s,v,a]` (f32 components as stored) or
//!   `["Spot",colorant,tint]` with `colorant` `[name,fallback]`, `name`
//!   `null`, `["All"]` or `["Custom",s]`. A color `space` is the name of a
//!   process space (`Oklab|Oklch|Srgb|D65Gray|LinearRgb|Hsl|Hsv|Cmyk`) or
//!   `["Spot",colorant]`.
//! - `font`: `variations` is `[[tag,f32]]`; `postscript_name` may be null;
//!   `upem` is an f64.
//! - `image-resource`: `kind` is the raster format (`png|jpg|gif|webp`, or
//!   the pixel encoding `rgb8|rgba8|luma8|lumaa8`), `svg` or `pdf`;
//!   `asset_sha256` hashes the encoded data (the whole document for PDF);
//!   `page_index` (PDF only), `intrinsic_size` `[w,h]` f64 (`Image::width`/
//!   `height`), `dpi` f64 or null, `exif` the raster EXIF rotation or null,
//!   `icc_sha256` of the raster ICC profile or null; `dependencies` is
//!   reserved (always null in v1).
//! - `image`: `alt` string or null, `scaling` `"auto"|"smooth"|"pixelated"`.
//! - `link` destination: `["url",s]`, `["position",page,point]` or
//!   `["location",L]`.
//! - `group`: `label` string or null; `parent` null or `[L,inherit]`.
//! - `page`: `fill` is `"auto"`, `null` or a paint; `numbering` null or its
//!   repr; `supplement_C` a content id.
//! - `document`: `info` is `[title,authors,description,keywords,date,
//!   locale]` (`date` `"auto"`, `"none"` or the datetime repr; `locale`
//!   `"auto"` or RFC 3066); `format_options` is
//!   `[[format,[[field,value_repr,span]]]]` for every registered format in
//!   registration order and every option field in field order.
//! - Canonical content is the structural encoding of the `realize` stage.

use std::fmt::Write as _;
use std::path::Path;

use rustc_hash::FxHashMap;
use typst::diag::{SourceDiagnostic, Warned};
use typst::foundations::{Content, IntoValue, Repr, Smart};
use typst::introspection::{Location, Tag, TagFlags};
use typst::layout::{Abs, Angle, Axes, Frame, FrameItem, Point, Ratio, Size, Transform};
use typst::model::{Destination, Document, DocumentInfo};
use typst::syntax::{DiagSpan, DiagSpanKind, FileId, Span, VirtualRoot};
use typst::text::{FontInstance, Glyph, TextItem};
use typst::visualize::{
    Color, ColorSpace, Curve, CurveItem, FillRule, FixedStroke, Geometry, Gradient,
    Image, ImageKind, ImageScaling, LineCap, LineJoin, Paint, ProcessColor,
    ProcessColorSpace, RelativeTo, SpotColorant, SpotColorantName,
};
use typst::{World, WorldExt};
use typst_layout::PagedDocument;

use crate::collect;
use crate::eval::{deduplicate, write_diag};
use crate::fonts::{json_str, sha256_hex};
use crate::realize::Dumper;
use crate::world::{TestWorld, parse_features};

/// Whether the upstream runner compiles a test to a paged document.
pub fn is_paged(attrs: &str) -> bool {
    attrs.split_whitespace().any(|a| {
        let name = a.split('(').next().unwrap();
        matches!(name, "paged" | "pdf" | "pdftags")
    })
}

/// Dump paged results for every paged test below `suite` (a path relative to
/// the current directory, which must be the upstream checkout).
pub fn dump_paged(suite: &Path, out: &Path, revision: &str, manifest_sha: &str) {
    let mut count = 0;
    let filter = std::env::var("ORACLE_FILTER").ok();
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
            report.push_str(&paged_report(&file, &test, revision, manifest_sha));
            count += 1;
        }
        if report.is_empty() {
            continue;
        }
        let dest = out.join(rel).with_extension("txt");
        std::fs::create_dir_all(dest.parent().unwrap()).unwrap();
        std::fs::write(dest, report).unwrap();
    }
    eprintln!("compiled {count} paged test cases");
}

/// Compile a single test case to a paged document and encode it.
pub fn paged_report(
    path: &Path,
    test: &collect::TestCase,
    revision: &str,
    manifest_sha: &str,
) -> String {
    let features = test
        .attrs
        .split_whitespace()
        .find_map(|a| a.strip_prefix("features(").and_then(|r| r.strip_suffix(')')))
        .map(parse_features);
    let source = TestWorld::main_source(path, test.body.clone());
    let world = TestWorld::new(source, features);

    let mut enc = Encoder::new(&world);
    enc.record(&[
        json_str("header"),
        json_str("typst-frame-v1"),
        json_str(revision),
        json_str(manifest_sha),
        json_str(&test.name),
    ]);

    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        typst::compile::<PagedDocument>(&world)
    }));
    let Ok(Warned { output, warnings }) = result else {
        enc.record(&[json_str("diagnostics"), json_str("panic"), "[]".into()]);
        enc.record(&[json_str("end")]);
        return enc.out;
    };

    let warnings = deduplicate(warnings);
    match output {
        Ok(doc) => {
            let lines = enc.diag_lines(&[], &warnings);
            enc.record(&[json_str("diagnostics"), json_str("ok"), lines]);
            enc.document(&doc);
        }
        Err(errors) => {
            let errors = deduplicate(errors);
            let lines = enc.diag_lines(&errors, &warnings);
            enc.record(&[json_str("diagnostics"), json_str("err"), lines]);
        }
    }
    enc.record(&[json_str("end")]);
    enc.out
}

/// Encodes a paged document as `typst-frame-v1` records.
struct Encoder<'a> {
    world: &'a TestWorld,
    out: String,
    /// Shared with canonical content (location numbering).
    dumper: Dumper,
    fonts: FxHashMap<String, usize>,
    images: FxHashMap<String, usize>,
    contents: FxHashMap<String, usize>,
    keys: FxHashMap<u128, usize>,
}

impl<'a> Encoder<'a> {
    fn new(world: &'a TestWorld) -> Self {
        Self {
            world,
            out: String::new(),
            dumper: Dumper::default(),
            fonts: FxHashMap::default(),
            images: FxHashMap::default(),
            contents: FxHashMap::default(),
            keys: FxHashMap::default(),
        }
    }

    /// Write a record.
    fn record(&mut self, fields: &[String]) {
        self.out.push('[');
        self.out.push_str(&fields.join(","));
        self.out.push_str("]\n");
    }

    fn diag_lines(
        &self,
        errors: &[SourceDiagnostic],
        warnings: &[SourceDiagnostic],
    ) -> String {
        let main = self.world.main();
        let mut text = String::new();
        for diag in errors.iter().chain(warnings) {
            write_diag(&mut text, self.world, main, diag);
        }
        array(text.lines().map(json_str))
    }

    fn document(&mut self, doc: &PagedDocument) {
        let info = info(doc.info());
        let options = self.format_options(doc);
        let count = doc.pages().len().to_string();
        self.record(&[json_str("document"), info, options, count]);
        for (p, page) in doc.pages().iter().enumerate() {
            let supplement = self.content(&page.supplement);
            let r = format!("p{p}");
            let mut deferred = vec![];
            let fill = match &page.fill {
                Smart::Auto => json_str("auto"),
                Smart::Custom(None) => "null".into(),
                Smart::Custom(Some(paint)) => {
                    self.paint(paint, &format!("{r}/fill"), &mut deferred)
                }
            };
            let numbering = match &page.numbering {
                Some(n) => json_str(&n.clone().into_value().repr()),
                None => "null".into(),
            };
            let bleed = page.bleed;
            self.record(&[
                json_str("page"),
                p.to_string(),
                page.number.to_string(),
                array([bleed.left, bleed.top, bleed.right, bleed.bottom].map(abs)),
                fill,
                numbering,
                supplement.to_string(),
            ]);
            self.frames(deferred);
            self.frame(&page.frame, &r);
        }
    }

    fn format_options(&mut self, doc: &PagedDocument) -> String {
        let options = doc.options();
        let html = options.get::<typst_html::HtmlFormat>();
        let pdf = options.get::<typst_pdf::PdfFormat>();
        let svg = options.get::<typst_svg::SvgFormat>();
        let png = options.get::<typst_render::PngFormat>();
        let field = |name: &str, v: typst::foundations::Value, span: Span| {
            array([json_str(name), json_str(&v.repr()), self.span(span)])
        };
        let formats = [
            ("html", vec![field("pretty", html.pretty.v.into_value(), html.pretty.span)]),
            (
                "pdf",
                vec![
                    field("pages", pdf.pages.v.clone().into_value(), pdf.pages.span),
                    field("standard", pdf.standard.v.clone().into_value(), pdf.standard.span),
                    field("tagged", pdf.tagged.v.into_value(), pdf.tagged.span),
                    field("pretty", pdf.pretty.v.into_value(), pdf.pretty.span),
                ],
            ),
            ("svg", vec![field("pretty", svg.pretty.v.into_value(), svg.pretty.span)]),
            ("png", vec![field("ppi", png.ppi.v.into_value(), png.ppi.span)]),
            ("bundle", vec![]),
        ];
        array(formats.into_iter().map(|(name, fields)| array([json_str(name), array(fields)])))
    }

    /// The id of some content, emitting its record if it is new.
    fn content(&mut self, content: &Content) -> usize {
        let encoded = self.dumper.content(content);
        if let Some(&id) = self.contents.get(&encoded) {
            return id;
        }
        let id = self.contents.len();
        self.contents.insert(encoded.clone(), id);
        self.record(&[json_str("content"), id.to_string(), json_str(&encoded)]);
        id
    }

    fn location(&mut self, loc: Location) -> usize {
        self.dumper.loc_id(loc)
    }

    fn key(&mut self, key: u128) -> usize {
        let n = self.keys.len();
        *self.keys.entry(key).or_insert(n)
    }

    /// Emit the records of deferred (tiling) frames.
    fn frames(&mut self, deferred: Vec<(Frame, String)>) {
        for (frame, r) in deferred {
            self.frame(&frame, &r);
        }
    }

    fn frame(&mut self, frame: &Frame, r: &str) {
        let baseline =
            if frame.has_baseline() { abs(frame.baseline()) } else { "null".into() };
        let kind = if frame.kind().is_hard() { "hard" } else { "soft" };
        self.record(&[
            json_str("frame"),
            json_str(r),
            size(frame.size()),
            baseline,
            json_str(kind),
            frame.items().len().to_string(),
        ]);
        for (i, (pos, item)) in frame.items().enumerate() {
            self.item(r, i, *pos, item);
        }
    }

    fn item(&mut self, r: &str, i: usize, pos: Point, item: &FrameItem) {
        let head = |kind: &str| vec![json_str(kind), json_str(r), i.to_string(), point(pos)];
        let mut deferred = vec![];
        match item {
            FrameItem::Group(group) => {
                let child = format!("{r}/{i}");
                let clip = match &group.clip {
                    Some(curve) => commands(curve),
                    None => "null".into(),
                };
                let label = match group.label {
                    Some(label) => json_str(label.resolve().as_str()),
                    None => "null".into(),
                };
                let parent = match group.parent {
                    Some(parent) => {
                        let l = self.location(parent.location);
                        let inherit = matches!(parent.inherit, typst::layout::Inherit::Yes);
                        array([l.to_string(), inherit.to_string()])
                    }
                    None => "null".into(),
                };
                let mut rec = head("group");
                rec.extend([json_str(&child), transform(group.transform), clip, label, parent]);
                self.record(&rec);
                self.frame(&group.frame, &child);
            }
            FrameItem::Text(text) => {
                let f = self.font(&text.font);
                let fill = self.paint(&text.fill, &format!("{r}/{i}/fill"), &mut deferred);
                let stroke =
                    self.stroke(text.stroke.as_ref(), &format!("{r}/{i}/stroke"), &mut deferred);
                let mut rec = head("text");
                rec.extend([
                    f.to_string(),
                    abs(text.size),
                    fill,
                    stroke,
                    json_str(text.lang.as_str()),
                    match &text.region {
                        Some(region) => json_str(region.as_str()),
                        None => "null".into(),
                    },
                    json_str(&text.text),
                    self.glyphs(text),
                ]);
                self.record(&rec);
            }
            FrameItem::Shape(shape, span) => {
                let fill = match &shape.fill {
                    Some(paint) => self.paint(paint, &format!("{r}/{i}/fill"), &mut deferred),
                    None => "null".into(),
                };
                let stroke = self.stroke(
                    shape.stroke.as_ref(),
                    &format!("{r}/{i}/stroke"),
                    &mut deferred,
                );
                let fill_rule = match shape.fill_rule {
                    FillRule::NonZero => "non-zero",
                    FillRule::EvenOdd => "even-odd",
                };
                let mut rec = head("shape");
                rec.extend([
                    geometry(&shape.geometry),
                    fill,
                    json_str(fill_rule),
                    stroke,
                    self.span(*span),
                ]);
                self.record(&rec);
            }
            FrameItem::Image(image, sz, span) => {
                let id = self.image(image);
                let alt = match image.alt() {
                    Some(alt) => json_str(alt),
                    None => "null".into(),
                };
                let scaling = match image.scaling() {
                    Smart::Auto => "auto",
                    Smart::Custom(ImageScaling::Smooth) => "smooth",
                    Smart::Custom(ImageScaling::Pixelated) => "pixelated",
                };
                let mut rec = head("image");
                rec.extend([id.to_string(), size(*sz), alt, json_str(scaling), self.span(*span)]);
                self.record(&rec);
            }
            FrameItem::Link(dest, sz) => {
                let dest = match dest {
                    Destination::Url(url) => array([json_str("url"), json_str(url.as_str())]),
                    Destination::Position(pos) => array([
                        json_str("position"),
                        pos.page.get().to_string(),
                        point(pos.point),
                    ]),
                    Destination::Location(loc) => {
                        array([json_str("location"), self.location(*loc).to_string()])
                    }
                };
                let mut rec = head("link");
                rec.extend([size(*sz), dest]);
                self.record(&rec);
            }
            FrameItem::Tag(Tag::Start(elem, flags)) => {
                let l = self.location(elem.location().unwrap());
                let c = self.content(elem);
                let mut rec = head("tag-start");
                rec.extend([l.to_string(), c.to_string()]);
                rec.extend(tag_flags(*flags));
                self.record(&rec);
            }
            FrameItem::Tag(Tag::End(loc, key, flags)) => {
                let l = self.location(*loc);
                let k = self.key(*key);
                let mut rec = head("tag-end");
                rec.extend([l.to_string(), k.to_string()]);
                rec.extend(tag_flags(*flags));
                self.record(&rec);
            }
        }
        self.frames(deferred);
    }

    fn glyphs(&self, text: &TextItem) -> String {
        array(text.glyphs.iter().map(|g: &Glyph| {
            array([
                g.id.to_string(),
                f64_hex(g.x_advance.get()),
                f64_hex(g.y_advance.get()),
                f64_hex(g.x_offset.get()),
                f64_hex(g.y_offset.get()),
                g.range.start.to_string(),
                g.range.end.to_string(),
                self.span(g.span.0),
                g.span.1.to_string(),
            ])
        }))
    }

    /// The id of a font instance, emitting its record if it is new.
    fn font(&mut self, font: &FontInstance) -> usize {
        let inner = font.font();
        let variations = array(font.variations().0.iter().map(|(tag, value)| {
            array([json_str(&tag.to_str_lossy()), f32_hex(value.0)])
        }));
        let fields = [
            json_str(&sha256_hex(inner.data().as_slice())),
            inner.index().to_string(),
            variations,
            json_str(&inner.info().family),
            match inner.post_script_name() {
                Some(name) => json_str(&name),
                None => "null".into(),
            },
            f64_hex(font.units_per_em()),
        ];
        let key = fields.join(",");
        if let Some(&id) = self.fonts.get(&key) {
            return id;
        }
        let id = self.fonts.len();
        self.fonts.insert(key.clone(), id);
        self.out.push_str(&format!("[{},{id},{key}]\n", json_str("font")));
        id
    }

    /// The id of an image, emitting its record if it is new.
    fn image(&mut self, image: &Image) -> usize {
        let null = || "null".to_string();
        let (kind, sha, page_index, exif, icc) = match image.kind() {
            ImageKind::Raster(raster) => {
                use typst::visualize::{ExchangeFormat, PixelEncoding, RasterFormat};
                let kind = match raster.format() {
                    RasterFormat::Exchange(ExchangeFormat::Png) => "png",
                    RasterFormat::Exchange(ExchangeFormat::Jpg) => "jpg",
                    RasterFormat::Exchange(ExchangeFormat::Gif) => "gif",
                    RasterFormat::Exchange(ExchangeFormat::Webp) => "webp",
                    RasterFormat::Pixel(format) => match format.encoding {
                        PixelEncoding::Rgb8 => "rgb8",
                        PixelEncoding::Rgba8 => "rgba8",
                        PixelEncoding::Luma8 => "luma8",
                        PixelEncoding::Lumaa8 => "lumaa8",
                    },
                };
                let exif = match raster.exif_rotation() {
                    Some(r) => r.to_string(),
                    None => null(),
                };
                let icc = match raster.icc() {
                    Some(icc) => json_str(&sha256_hex(icc.as_slice())),
                    None => null(),
                };
                (kind, sha256_hex(raster.data().as_slice()), null(), exif, icc)
            }
            ImageKind::Svg(svg) => {
                ("svg", sha256_hex(svg.data().as_slice()), null(), null(), null())
            }
            ImageKind::Pdf(pdf) => {
                let data: &[u8] = pdf.document().pdf().data().as_ref();
                ("pdf", sha256_hex(data), pdf.page_index().to_string(), null(), null())
            }
        };
        let dpi = match image.dpi() {
            Some(dpi) => f64_hex(dpi),
            None => null(),
        };
        let fields = [
            json_str(kind),
            json_str(&sha),
            page_index,
            array([f64_hex(image.width()), f64_hex(image.height())]),
            dpi,
            exif,
            icc,
            null(),
        ];
        let key = fields.join(",");
        if let Some(&id) = self.images.get(&key) {
            return id;
        }
        let id = self.images.len();
        self.images.insert(key.clone(), id);
        self.out.push_str(&format!("[{},{id},{key}]\n", json_str("image-resource")));
        id
    }

    fn stroke(
        &mut self,
        stroke: Option<&FixedStroke>,
        r: &str,
        deferred: &mut Vec<(Frame, String)>,
    ) -> String {
        let Some(stroke) = stroke else { return "null".into() };
        let cap = match stroke.cap {
            LineCap::Butt => "butt",
            LineCap::Round => "round",
            LineCap::Square => "square",
        };
        let join = match stroke.join {
            LineJoin::Miter => "miter",
            LineJoin::Round => "round",
            LineJoin::Bevel => "bevel",
        };
        let dash = match &stroke.dash {
            Some(dash) => {
                array([array(dash.array.iter().map(|&l| abs(l))), abs(dash.phase)])
            }
            None => "null".into(),
        };
        array([
            self.paint(&stroke.paint, r, deferred),
            abs(stroke.thickness),
            json_str(cap),
            json_str(join),
            dash,
            ratio(stroke.miter_limit),
        ])
    }

    fn paint(&mut self, paint: &Paint, r: &str, deferred: &mut Vec<(Frame, String)>) -> String {
        match paint {
            Paint::Solid(color) => array([json_str("solid"), color_enc(color)]),
            Paint::Gradient(gradient) => {
                let stops = |stops: &[(Color, Ratio)]| {
                    array(stops.iter().map(|(c, r)| array([color_enc(c), ratio(*r)])))
                };
                match gradient {
                    Gradient::Linear(g) => array([
                        json_str("linear"),
                        stops(&g.stops),
                        angle(g.angle),
                        space(&g.space),
                        relative(g.relative),
                        g.anti_alias.to_string(),
                    ]),
                    Gradient::Radial(g) => array([
                        json_str("radial"),
                        stops(&g.stops),
                        ratios(g.center),
                        ratio(g.radius),
                        ratios(g.focal_center),
                        ratio(g.focal_radius),
                        space(&g.space),
                        relative(g.relative),
                        g.anti_alias.to_string(),
                    ]),
                    Gradient::Conic(g) => array([
                        json_str("conic"),
                        stops(&g.stops),
                        angle(g.angle),
                        ratios(g.center),
                        space(&g.space),
                        relative(g.relative),
                        g.anti_alias.to_string(),
                    ]),
                }
            }
            Paint::Tiling(tiling) => {
                deferred.push((tiling.frame().clone(), r.to_string()));
                array([
                    json_str("tiling"),
                    json_str(r),
                    size(tiling.size()),
                    size(tiling.spacing()),
                    size(tiling.offset()),
                    angle(tiling.angle()),
                    relative(tiling.relative()),
                ])
            }
        }
    }

    fn span(&self, span: Span) -> String {
        let diag = DiagSpan::from(span);
        let id = match diag.get() {
            DiagSpanKind::Detached => return "null".into(),
            DiagSpanKind::Number { id, .. } | DiagSpanKind::Range { id, .. } => id,
        };
        let path = file_path(id);
        match self.world.range(diag) {
            Some(range) => array([json_str(&path), range.start.to_string(), range.end.to_string()]),
            None => array([json_str(&path), "null".into(), "null".into()]),
        }
    }
}

/// The repository-relative virtual path of a file.
fn file_path(id: FileId) -> String {
    let path = id.vpath().get_without_slash().to_string();
    match id.root() {
        VirtualRoot::Project => path,
        VirtualRoot::Package(spec) => {
            format!("@{}/{}:{}/{}", spec.namespace, spec.name, spec.version, path)
        }
    }
}

fn info(info: &DocumentInfo) -> String {
    let opt = |s: &Option<ecow::EcoString>| match s {
        Some(s) => json_str(s),
        None => "null".into(),
    };
    let list = |l: &[ecow::EcoString]| array(l.iter().map(|s| json_str(s)));
    let date = match &info.date {
        Smart::Auto => "auto".to_string(),
        Smart::Custom(None) => "none".to_string(),
        Smart::Custom(Some(d)) => d.repr().to_string(),
    };
    let locale = match &info.locale {
        Smart::Auto => "auto".to_string(),
        Smart::Custom(l) => l.rfc_3066().to_string(),
    };
    array([
        opt(&info.title),
        list(&info.author),
        opt(&info.description),
        list(&info.keywords),
        json_str(&date),
        json_str(&locale),
    ])
}

fn tag_flags(flags: TagFlags) -> [String; 2] {
    [flags.introspectable.to_string(), flags.tagged.to_string()]
}

fn geometry(geometry: &Geometry) -> String {
    match geometry {
        Geometry::Line(p) => array([json_str("line"), point(*p)]),
        Geometry::Rect(s) => array([json_str("rect"), size(*s)]),
        Geometry::Curve(c) => array([json_str("curve"), commands(c)]),
    }
}

fn commands(curve: &Curve) -> String {
    array(curve.0.iter().map(|item| match item {
        CurveItem::Move(p) => array([json_str("M"), point(*p)]),
        CurveItem::Line(p) => array([json_str("L"), point(*p)]),
        CurveItem::Cubic(a, b, c) => array([json_str("C"), point(*a), point(*b), point(*c)]),
        CurveItem::Close => array([json_str("Z")]),
    }))
}

fn color_enc(color: &Color) -> String {
    match color {
        Color::Process(c) => process_color(c),
        Color::Spot(s) => {
            array([json_str("Spot"), colorant(&s.colorant), ratio(s.tint)])
        }
    }
}

fn process_color(color: &ProcessColor) -> String {
    let f = |name: &str, cs: &[f32]| {
        array(std::iter::once(json_str(name)).chain(cs.iter().map(|&c| f32_hex(c))))
    };
    match *color {
        ProcessColor::Luma(c) => f("Luma", &[c.luma, c.alpha]),
        ProcessColor::Oklab(c) => f("Oklab", &[c.l, c.a, c.b, c.alpha]),
        ProcessColor::Oklch(c) => {
            f("Oklch", &[c.l, c.chroma, c.hue.into_inner(), c.alpha])
        }
        ProcessColor::Rgb(c) => f("Rgb", &[c.red, c.green, c.blue, c.alpha]),
        ProcessColor::LinearRgb(c) => f("LinearRgb", &[c.red, c.green, c.blue, c.alpha]),
        ProcessColor::Cmyk(c) => f("Cmyk", &[c.c, c.m, c.y, c.k]),
        ProcessColor::Hsl(c) => {
            f("Hsl", &[c.hue.into_inner(), c.saturation, c.lightness, c.alpha])
        }
        ProcessColor::Hsv(c) => f("Hsv", &[c.hue.into_inner(), c.saturation, c.value, c.alpha]),
    }
}

fn colorant(colorant: &SpotColorant) -> String {
    let name = match &colorant.name {
        None => "null".to_string(),
        Some(SpotColorantName::All) => array([json_str("All")]),
        Some(SpotColorantName::Custom(s)) => array([json_str("Custom"), json_str(s)]),
    };
    array([name, process_color(&colorant.fallback)])
}

fn space(space: &ColorSpace) -> String {
    match space {
        ColorSpace::Process(s) => json_str(match s {
            ProcessColorSpace::Oklab => "Oklab",
            ProcessColorSpace::Oklch => "Oklch",
            ProcessColorSpace::Srgb => "Srgb",
            ProcessColorSpace::D65Gray => "D65Gray",
            ProcessColorSpace::LinearRgb => "LinearRgb",
            ProcessColorSpace::Hsl => "Hsl",
            ProcessColorSpace::Hsv => "Hsv",
            ProcessColorSpace::Cmyk => "Cmyk",
        }),
        ColorSpace::Spot(c) => array([json_str("Spot"), colorant(c)]),
    }
}

fn relative(relative: Smart<RelativeTo>) -> String {
    json_str(match relative {
        Smart::Auto => "auto",
        Smart::Custom(RelativeTo::Self_) => "self",
        Smart::Custom(RelativeTo::Parent) => "parent",
    })
}

fn transform(ts: Transform) -> String {
    array([
        ratio(ts.sx),
        ratio(ts.ky),
        ratio(ts.kx),
        ratio(ts.sy),
        abs(ts.tx),
        abs(ts.ty),
    ])
}

fn point(p: Point) -> String {
    array([abs(p.x), abs(p.y)])
}

fn size(s: Size) -> String {
    array([abs(s.x), abs(s.y)])
}

fn ratios(r: Axes<Ratio>) -> String {
    array([ratio(r.x), ratio(r.y)])
}

fn abs(v: Abs) -> String {
    f64_hex(v.to_raw())
}

fn ratio(v: Ratio) -> String {
    f64_hex(v.get())
}

fn angle(v: Angle) -> String {
    f64_hex(v.to_raw())
}

pub fn f64_hex(v: f64) -> String {
    format!("\"f64:{:016x}\"", v.to_bits())
}

pub fn f32_hex(v: f32) -> String {
    format!("\"f32:{:08x}\"", v.to_bits())
}

fn array(items: impl IntoIterator<Item = String>) -> String {
    let items: Vec<String> = items.into_iter().collect();
    format!("[{}]", items.join(","))
}
