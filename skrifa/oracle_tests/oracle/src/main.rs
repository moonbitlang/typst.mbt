use hayro_syntax::Pdf;
use hayro_syntax::object::{Dict, Object, Stream};
use skrifa::instance::{LocationRef, Size};
use skrifa::outline::{DrawSettings, Engine, HintingInstance, HintingOptions, OutlinePen, Target};
use skrifa::raw::ps::cff::{CffFontRef, v1::Cff};
use skrifa::raw::ps::string::Sid;
use skrifa::raw::ps::type1::Type1Font;
use skrifa::raw::tables::post::DEFAULT_GLYPH_NAMES;
use skrifa::raw::{FontData as ReadFontData, FontRead, TableProvider};
use skrifa::{FontRef, GlyphId, MetadataProvider};
use std::fmt::Write;

fn readable() -> bool {
    std::env::var("READABLE").is_ok()
}

fn f(v: f32) -> String {
    if readable() {
        format!("{:?}", v)
    } else {
        format!("{:08x}", v.to_bits())
    }
}

struct Pen(String);

impl OutlinePen for Pen {
    fn move_to(&mut self, x: f32, y: f32) {
        writeln!(self.0, "M {} {}", f(x), f(y)).unwrap();
    }
    fn line_to(&mut self, x: f32, y: f32) {
        writeln!(self.0, "L {} {}", f(x), f(y)).unwrap();
    }
    fn quad_to(&mut self, cx: f32, cy: f32, x: f32, y: f32) {
        writeln!(self.0, "Q {} {} {} {}", f(cx), f(cy), f(x), f(y)).unwrap();
    }
    fn curve_to(&mut self, cx0: f32, cy0: f32, cx1: f32, cy1: f32, x: f32, y: f32) {
        writeln!(
            self.0,
            "C {} {} {} {} {} {}",
            f(cx0),
            f(cy0),
            f(cx1),
            f(cy1),
            f(x),
            f(y)
        )
        .unwrap();
    }
    fn close(&mut self) {
        writeln!(self.0, "Z").unwrap();
    }
}

fn fnv(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in data {
        h ^= *b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

fn lossy(b: &[u8]) -> String {
    b.iter().map(|c| *c as char).collect()
}

fn cff(data: &[u8], out: &mut String) {
    let font = match CffFontRef::new(data, 0, None) {
        Ok(f) => f,
        Err(e) => {
            writeln!(out, "error {e}").unwrap();
            return;
        }
    };
    let cff = Cff::read(ReadFontData::new(data)).ok();
    writeln!(
        out,
        "num_glyphs {} is_cid {} num_subfonts {} upem {}",
        font.num_glyphs(),
        font.is_cid(),
        font.num_subfonts(),
        font.upem()
    )
    .unwrap();
    if let Some(charset) = font.charset() {
        for (gid, sid) in charset.iter() {
            let name = cff
                .as_ref()
                .and_then(|c| c.string(sid))
                .map(lossy)
                .unwrap_or_else(|| "-".into());
            writeln!(out, "cs {} {} {}", gid.to_u32(), sid.to_u16(), name).unwrap();
        }
        let n = font.num_glyphs() + 500;
        for s in 0..n.min(65535) {
            if let Ok(g) = charset.glyph_id(Sid::new(s as u16)) {
                writeln!(out, "gid_of {} {}", s, g.to_u32()).unwrap();
            }
        }
    } else {
        writeln!(out, "no charset").unwrap();
    }
    if let Some(enc) = font.encoding() {
        for code in 0..=255u8 {
            if let Some(g) = enc.map(code) {
                writeln!(out, "enc {} {}", code, g.to_u32()).unwrap();
            }
        }
    } else {
        writeln!(out, "no encoding").unwrap();
    }
    let mut subfonts = vec![];
    for i in 0..font.num_subfonts() {
        match font.subfont(i, &[]) {
            Ok(s) => {
                writeln!(
                    out,
                    "subfont {} subrs {} dw {:?} nw {:?}",
                    i,
                    s.subrs_offset(),
                    s.default_width().map(|w| w.to_bits()),
                    s.nominal_width().to_bits()
                )
                .unwrap();
                subfonts.push(Some(s))
            }
            Err(e) => {
                writeln!(out, "subfont {} error {e}", i).unwrap();
                subfonts.push(None)
            }
        }
    }
    for gid in 0..font.num_glyphs() {
        let glyph = GlyphId::new(gid);
        let Some(idx) = font.subfont_index(glyph) else {
            writeln!(out, "glyph {gid} no subfont").unwrap();
            continue;
        };
        let Some(Some(subfont)) = subfonts.get(idx as usize) else {
            writeln!(out, "glyph {gid} bad subfont {idx}").unwrap();
            continue;
        };
        let mut pen = Pen(String::new());
        let res = font.draw(subfont, glyph, &[], Some(1000.0), &mut pen);
        match res {
            Ok(w) => writeln!(out, "glyph {gid} sf {idx} w {}", w.map(f).unwrap_or("-".into())).unwrap(),
            Err(e) => writeln!(out, "glyph {gid} sf {idx} error {e}").unwrap(),
        }
        out.push_str(&pen.0);
    }
}

fn t1(data: &[u8], out: &mut String) {
    let font = match Type1Font::new(data) {
        Ok(f) => f,
        Err(e) => {
            writeln!(out, "error {e}").unwrap();
            return;
        }
    };
    writeln!(out, "num_glyphs {} upem {}", font.num_glyphs(), font.upem()).unwrap();
    for (gid, name) in font.glyph_names() {
        writeln!(out, "name {} {}", gid.to_u32(), name).unwrap();
    }
    if let Some(enc) = font.encoding() {
        for code in 0..=255u8 {
            let g = enc.map(code).map(|g| g.to_u32() as i64).unwrap_or(-1);
            let n = enc.glyph_name(code).unwrap_or("-");
            if g >= 0 || n != "-" {
                writeln!(out, "enc {} {} {}", code, g, n).unwrap();
            }
        }
    } else {
        writeln!(out, "no encoding").unwrap();
    }
    for gid in 0..font.num_glyphs() {
        let mut pen = Pen(String::new());
        match font.draw(GlyphId::new(gid), Some(1000.0), &mut pen) {
            Ok(w) => writeln!(out, "glyph {gid} w {}", w.map(f).unwrap_or("-".into())).unwrap(),
            Err(e) => writeln!(out, "glyph {gid} error {e}").unwrap(),
        }
        out.push_str(&pen.0);
    }
}

fn otf(data: &[u8], index: u32, out: &mut String, hinted: bool) {
    let font = match FontRef::from_index(data, index) {
        Ok(f) => f,
        Err(e) => {
            writeln!(out, "error {e}").unwrap();
            return;
        }
    };
    match font.post() {
        Ok(post) => {
            let (maj, min) = post.version().to_major_minor();
            writeln!(out, "post {maj} {min}").unwrap();
            if let Some(idx) = post.glyph_name_index() {
                let v: Vec<String> = idx.iter().map(|i| i.get().to_string()).collect();
                writeln!(out, "post_idx {}", v.join(" ")).unwrap();
            }
            if let Some(sd) = post.string_data() {
                for e in sd.iter() {
                    match e {
                        Ok(s) => writeln!(out, "post_str {}", s.as_str()).unwrap(),
                        Err(e) => writeln!(out, "post_str_err {e}").unwrap(),
                    }
                }
            }
            let _ = DEFAULT_GLYPH_NAMES.len();
        }
        Err(e) => writeln!(out, "post error {e}").unwrap(),
    }
    match font.cff() {
        Ok(cff) => {
            let d = cff.offset_data();
            writeln!(out, "cff {} {:016x}", d.len(), fnv(d.as_ref())).unwrap()
        }
        Err(e) => writeln!(out, "cff error {e}").unwrap(),
    }
    match font.cmap() {
        Ok(cmap) => {
            for record in cmap.encoding_records() {
                write!(
                    out,
                    "cmap {:?} {}",
                    record.platform_id(),
                    record.encoding_id()
                )
                .unwrap();
                match record.subtable(cmap.offset_data()) {
                    Ok(sub) => {
                        let mut h = String::new();
                        let mut n = 0;
                        for c in 0..0x11000u32 {
                            if let Some(g) = sub.map_codepoint(c) {
                                writeln!(h, "{c} {}", g.to_u32()).unwrap();
                                n += 1;
                            }
                        }
                        writeln!(out, " fmt {} n {} h {:016x}", sub.format(), n, fnv(h.as_bytes()))
                            .unwrap();
                    }
                    Err(e) => writeln!(out, " error {e}").unwrap(),
                }
            }
            let mut h = String::new();
            let mut n = 0;
            for c in 0..0x11000u32 {
                if let Some(g) = cmap.map_codepoint(c) {
                    writeln!(h, "{c} {}", g.to_u32()).unwrap();
                    n += 1;
                }
            }
            writeln!(out, "cmap_map n {} h {:016x}", n, fnv(h.as_bytes())).unwrap();
        }
        Err(e) => writeln!(out, "cmap error {e}").unwrap(),
    }
    {
        let cm = font.charmap();
        let mut h = String::new();
        let mut n = 0;
        for c in 0..0x11000u32 {
            if let Some(ch) = char::from_u32(c) {
                if let Some(g) = cm.map(ch) {
                    writeln!(h, "{c} {}", g.to_u32()).unwrap();
                    n += 1;
                }
            }
        }
        writeln!(out, "charmap n {} h {:016x}", n, fnv(h.as_bytes())).unwrap();
    }
    let attrs = font.attributes();
    let style = match attrs.style {
        skrifa::attribute::Style::Normal => "Normal".to_string(),
        skrifa::attribute::Style::Italic => "Italic".to_string(),
        skrifa::attribute::Style::Oblique(None) => "Oblique(None)".to_string(),
        skrifa::attribute::Style::Oblique(Some(a)) => format!("Oblique({})", f(a)),
    };
    writeln!(
        out,
        "attrs weight {} style {} stretch {}",
        f(attrs.weight.value()),
        style,
        f(attrs.stretch.ratio())
    )
    .unwrap();
    let m = font.metrics(Size::unscaled(), LocationRef::default());
    writeln!(out, "metrics upem {} mono {}", m.units_per_em, m.is_monospace).unwrap();
    let outlines = font.outline_glyphs();
    let req = outlines.require_interpreter();
    writeln!(out, "require_interpreter {req}").unwrap();
    let gm = font.glyph_metrics(Size::new(1000.0), LocationRef::default());
    let num_glyphs = font.maxp().map(|m| m.num_glyphs() as u32).unwrap_or(0);
    writeln!(out, "num_glyphs {num_glyphs}").unwrap();
    let instance = if hinted {
        match HintingInstance::new(
            &outlines,
            Size::new(1000.0),
            LocationRef::default(),
            HintingOptions {
                engine: Engine::Interpreter,
                target: Target::Mono,
            },
        ) {
            Ok(i) => Some(i),
            Err(e) => {
                writeln!(out, "hinting error {e}").unwrap();
                None
            }
        }
    } else {
        None
    };
    for gid in 0..num_glyphs + 1 {
        let glyph = GlyphId::new(gid);
        let aw = gm.advance_width(glyph).map(f).unwrap_or("-".into());
        let Some(outline) = outlines.get(glyph) else {
            writeln!(out, "glyph {gid} aw {aw} none").unwrap();
            continue;
        };
        let mut pen = Pen(String::new());
        let settings = if let Some(inst) = instance.as_ref() {
            DrawSettings::hinted(inst, false)
        } else {
            DrawSettings::unhinted(Size::new(1000.0), LocationRef::default())
        };
        match outline.draw(settings, &mut pen) {
            Ok(_) => writeln!(out, "glyph {gid} aw {aw}").unwrap(),
            Err(e) => writeln!(out, "glyph {gid} aw {aw} error {e}").unwrap(),
        }
        out.push_str(&pen.0);
    }
}

fn font_streams(path: &str) -> Vec<(String, Vec<u8>)> {
    let data = std::fs::read(path).unwrap();
    let pdf = Pdf::new(data).unwrap();
    let mut res = vec![];
    for obj in pdf.objects() {
        let dict: Dict = match obj {
            Object::Dict(d) => d,
            _ => continue,
        };
        for key in ["FontFile", "FontFile2", "FontFile3"] {
            if let Some(s) = dict.get::<Stream>(key.as_bytes()) {
                if let Ok(d) = s.decoded() {
                    res.push((key.to_string(), d.to_vec()));
                }
            }
        }
    }
    res
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut out = String::new();
    match args[1].as_str() {
        "cff" => cff(&std::fs::read(&args[2]).unwrap(), &mut out),
        "t1" => t1(&std::fs::read(&args[2]).unwrap(), &mut out),
        "otf" => {
            let idx = args.get(3).map(|s| s.parse().unwrap()).unwrap_or(0);
            otf(&std::fs::read(&args[2]).unwrap(), idx, &mut out, false)
        }
        "otf-hinted" => {
            let idx = args.get(3).map(|s| s.parse().unwrap()).unwrap_or(0);
            otf(&std::fs::read(&args[2]).unwrap(), idx, &mut out, true)
        }
        // fonts <pdf> <outdir>: list embedded font files (key, len, fnv) and dump them
        "fonts" => {
            for (i, (key, data)) in font_streams(&args[2]).iter().enumerate() {
                writeln!(out, "{i} {key} {} {:016x}", data.len(), fnv(data)).unwrap();
                if let Some(dir) = args.get(3) {
                    std::fs::write(format!("{dir}/{i}.{key}"), data).unwrap();
                }
            }
        }
        "hash" => {
            let data = std::fs::read(&args[2]).unwrap();
            writeln!(out, "{} {:016x}", data.len(), fnv(&data)).unwrap();
        }
        _ => panic!("unknown command"),
    }
    print!("{out}");
}
