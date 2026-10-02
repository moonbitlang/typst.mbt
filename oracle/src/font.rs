//! The `font` stage: dumps what `ttf-parser` reports for every font of the
//! test world (typst-assets fonts, then typst-dev-assets fonts; collections
//! expanded in face order, exactly like `TestBase::default` in world.rs).
//!
//! One file per face: `<out>/<index:02>.txt`. The MoonBit runner stage
//! `font` (tests/runner/font_stage.mbt) produces the same text from `otf/`.
//!
//! Large per-glyph data is summarized with FNV-1a hashes over blocks of
//! lines; a deterministic sample of glyphs is printed in full.

use std::fmt::Write as _;
use std::path::Path;

use ttf_parser::{Face, GlyphId, OutlineBuilder};

/// All font data in test-world order.
pub fn test_fonts() -> Vec<&'static [u8]> {
    typst_assets::fonts().chain(typst_dev_assets::fonts()).collect()
}

pub fn dump_font(out: &Path) {
    std::fs::create_dir_all(out).unwrap();
    let mut index = 0;
    for data in test_fonts() {
        let count = ttf_parser::fonts_in_collection(data).unwrap_or(1);
        for face_index in 0..count {
            let mut text = String::new();
            dump_face(&mut text, index, data, face_index);
            std::fs::write(out.join(format!("{index:02}.txt")), text).unwrap();
            index += 1;
        }
    }
    eprintln!("dumped {index} faces");
}

/// FNV-1a 64-bit hash.
pub fn fnv(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in data {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

/// Escapes a string to printable ASCII.
pub fn esc(s: &str) -> String {
    let mut out = String::new();
    for c in s.chars() {
        if (' '..='~').contains(&c) && c != '"' && c != '\\' {
            out.push(c);
        } else {
            write!(out, "\\u{{{:x}}}", c as u32).unwrap();
        }
    }
    out
}

/// An f32 printed as Rust's `Display` of the value widened to f64.
pub fn f(x: f32) -> String {
    format!("{}", x as f64)
}

fn opt<T: std::fmt::Display>(v: Option<T>) -> String {
    match v {
        Some(v) => v.to_string(),
        None => "-".into(),
    }
}

fn hex(data: &[u8]) -> String {
    data.iter().map(|b| format!("{b:02x}")).collect()
}

struct PathBuilder(String);

impl OutlineBuilder for PathBuilder {
    fn move_to(&mut self, x: f32, y: f32) {
        write!(self.0, "M {} {} ", f(x), f(y)).unwrap();
    }
    fn line_to(&mut self, x: f32, y: f32) {
        write!(self.0, "L {} {} ", f(x), f(y)).unwrap();
    }
    fn quad_to(&mut self, x1: f32, y1: f32, x: f32, y: f32) {
        write!(self.0, "Q {} {} {} {} ", f(x1), f(y1), f(x), f(y)).unwrap();
    }
    fn curve_to(&mut self, x1: f32, y1: f32, x2: f32, y2: f32, x: f32, y: f32) {
        write!(self.0, "C {} {} {} {} {} {} ", f(x1), f(y1), f(x2), f(y2), f(x), f(y))
            .unwrap();
    }
    fn close(&mut self) {
        self.0.push_str("Z ");
    }
}

fn rect(r: Option<ttf_parser::Rect>) -> String {
    match r {
        Some(r) => format!("{},{},{},{}", r.x_min, r.y_min, r.x_max, r.y_max),
        None => "-".into(),
    }
}

fn line_metrics(m: Option<ttf_parser::LineMetrics>) -> String {
    match m {
        Some(m) => format!("{} {}", m.position, m.thickness),
        None => "-".into(),
    }
}

fn script_metrics(m: Option<ttf_parser::ScriptMetrics>) -> String {
    match m {
        Some(m) => format!("{} {} {} {}", m.x_size, m.y_size, m.x_offset, m.y_offset),
        None => "-".into(),
    }
}

fn platform(p: ttf_parser::PlatformId) -> &'static str {
    use ttf_parser::PlatformId::*;
    match p {
        Unicode => "Unicode",
        Macintosh => "Macintosh",
        Iso => "Iso",
        Windows => "Windows",
        Custom => "Custom",
    }
}

fn style(s: ttf_parser::Style) -> &'static str {
    match s {
        ttf_parser::Style::Normal => "Normal",
        ttf_parser::Style::Italic => "Italic",
        ttf_parser::Style::Oblique => "Oblique",
    }
}

fn permissions(p: Option<ttf_parser::Permissions>) -> &'static str {
    use ttf_parser::Permissions::*;
    match p {
        Some(Installable) => "Installable",
        Some(Restricted) => "Restricted",
        Some(PreviewAndPrint) => "PreviewAndPrint",
        Some(Editable) => "Editable",
        None => "-",
    }
}

fn raster_format(f: ttf_parser::RasterImageFormat) -> &'static str {
    use ttf_parser::RasterImageFormat::*;
    match f {
        PNG => "PNG",
        BitmapMono => "BitmapMono",
        BitmapMonoPacked => "BitmapMonoPacked",
        BitmapGray2 => "BitmapGray2",
        BitmapGray2Packed => "BitmapGray2Packed",
        BitmapGray4 => "BitmapGray4",
        BitmapGray4Packed => "BitmapGray4Packed",
        BitmapGray8 => "BitmapGray8",
        BitmapPremulBgra32 => "BitmapPremulBgra32",
    }
}

/// Whether a glyph is printed in full.
fn is_sample(gid: u16, count: u16) -> bool {
    gid < 40 || gid % 397 == 0 || gid + 1 == count
}

fn dump_face(out: &mut String, index: usize, data: &[u8], face_index: u32) {
    writeln!(
        out,
        "font {index} face {face_index} len {} fnv {:016x}",
        data.len(),
        fnv(data)
    )
    .unwrap();
    let face = match Face::parse(data, face_index) {
        Ok(face) => face,
        Err(err) => {
            writeln!(out, "error {err}").unwrap();
            return;
        }
    };

    for record in face.raw_face().table_records {
        writeln!(
            out,
            "table {} {:08x} {} {}",
            esc(&record.tag.to_string()),
            record.check_sum,
            record.offset,
            record.length
        )
        .unwrap();
    }

    dump_metrics(out, &face);
    writeln!(out, "permissions {}", permissions(face.permissions())).unwrap();
    writeln!(out, "is_subsetting_allowed {}", face.is_subsetting_allowed()).unwrap();
    writeln!(out, "is_outline_embedding_allowed {}", face.is_outline_embedding_allowed())
        .unwrap();
    writeln!(out, "unicode_ranges {:032x}", face.unicode_ranges().0).unwrap();
    writeln!(
        out,
        "style {} weight {} width {} italic_angle {}",
        style(face.style()),
        face.weight().to_number(),
        face.width().to_number(),
        f(face.italic_angle())
    )
    .unwrap();
    writeln!(
        out,
        "flags regular={} italic={} bold={} oblique={} monospaced={} variable={}",
        face.is_regular(),
        face.is_italic(),
        face.is_bold(),
        face.is_oblique(),
        face.is_monospaced(),
        face.is_variable()
    )
    .unwrap();

    for (i, name) in face.names().into_iter().enumerate() {
        let text = match name.to_string() {
            Some(s) => format!("\"{}\"", esc(&s)),
            None => format!("bytes:{}", hex(name.name)),
        };
        writeln!(
            out,
            "name {i} {} {} {} {} lang=\"{}\" {text}",
            platform(name.platform_id),
            name.encoding_id,
            name.language_id,
            name.name_id,
            esc(&name.language().to_string())
        )
        .unwrap();
    }

    dump_cmap(out, &face);
    dump_kern(out, &face);
    dump_cff(out, &face);
    dump_glyphs(out, &face, "");

    // Variations.
    let axes: Vec<_> = face.variation_axes().into_iter().collect();
    for axis in &axes {
        writeln!(
            out,
            "axis {} min {} def {} max {} name_id {} hidden {}",
            esc(&axis.tag.to_string()),
            f(axis.min_value),
            f(axis.def_value),
            f(axis.max_value),
            axis.name_id,
            axis.hidden
        )
        .unwrap();
    }
    if face.is_variable() {
        let instances: [(&str, fn(&ttf_parser::VariationAxis) -> f32); 3] = [
            ("min", |a| a.min_value),
            ("max", |a| a.max_value),
            ("mid", |a| (a.def_value + a.max_value) / 2.0),
        ];
        for (label, value) in instances {
            let mut face = face.clone();
            for axis in &axes {
                face.set_variation(axis.tag, value(axis));
            }
            let coords: Vec<String> = face
                .variation_coordinates()
                .iter()
                .map(|c| c.get().to_string())
                .collect();
            writeln!(out, "instance {label} coords {}", coords.join(" ")).unwrap();
            dump_metrics(out, &face);
            dump_glyphs(out, &face, label);
        }
    }
}

fn dump_metrics(out: &mut String, face: &Face) {
    writeln!(out, "number_of_glyphs {}", face.number_of_glyphs()).unwrap();
    writeln!(out, "units_per_em {}", face.units_per_em()).unwrap();
    writeln!(out, "global_bbox {}", rect(Some(face.global_bounding_box()))).unwrap();
    writeln!(
        out,
        "hmetrics {} {} {} {}",
        face.ascender(),
        face.descender(),
        face.height(),
        face.line_gap()
    )
    .unwrap();
    writeln!(
        out,
        "typographic {} {} {}",
        opt(face.typographic_ascender()),
        opt(face.typographic_descender()),
        opt(face.typographic_line_gap())
    )
    .unwrap();
    writeln!(
        out,
        "vmetrics {} {} {} {}",
        opt(face.vertical_ascender()),
        opt(face.vertical_descender()),
        opt(face.vertical_height()),
        opt(face.vertical_line_gap())
    )
    .unwrap();
    writeln!(
        out,
        "x_height {} capital_height {}",
        opt(face.x_height()),
        opt(face.capital_height())
    )
    .unwrap();
    writeln!(out, "underline {}", line_metrics(face.underline_metrics())).unwrap();
    writeln!(out, "strikeout {}", line_metrics(face.strikeout_metrics())).unwrap();
    writeln!(out, "subscript {}", script_metrics(face.subscript_metrics())).unwrap();
    writeln!(out, "superscript {}", script_metrics(face.superscript_metrics())).unwrap();
}

fn cmap_format(format: &ttf_parser::cmap::Format) -> u16 {
    use ttf_parser::cmap::Format::*;
    match format {
        ByteEncodingTable(_) => 0,
        HighByteMappingThroughTable(_) => 2,
        SegmentMappingToDeltaValues(_) => 4,
        TrimmedTableMapping(_) => 6,
        MixedCoverage => 8,
        TrimmedArray(_) => 10,
        SegmentedCoverage(_) => 12,
        ManyToOneRangeMappings(_) => 13,
        UnicodeVariationSequences(_) => 14,
    }
}

fn dump_cmap(out: &mut String, face: &Face) {
    let Some(cmap) = face.tables().cmap else {
        writeln!(out, "cmap -").unwrap();
        return;
    };
    let mut all = std::collections::BTreeSet::new();
    for (i, subtable) in cmap.subtables.into_iter().enumerate() {
        let mut cps = vec![];
        subtable.codepoints(|cp| cps.push(cp));
        let mut text = String::new();
        for &cp in &cps {
            write!(text, "{cp}:{};", opt(subtable.glyph_index(cp).map(|g| g.0))).unwrap();
            all.insert(cp);
        }
        writeln!(
            out,
            "cmap {i} {} {} format {} unicode {} count {} fnv {:016x}",
            platform(subtable.platform_id),
            subtable.encoding_id,
            cmap_format(&subtable.format),
            subtable.is_unicode(),
            cps.len(),
            fnv(text.as_bytes())
        )
        .unwrap();
    }

    // Face-level lookups over the union of all mapped code points.
    let mut text = String::new();
    let mut vs_text = String::new();
    let mut found = 0;
    let mut vs_found = 0;
    let mut samples = String::new();
    for (k, &cp) in all.iter().enumerate() {
        let Some(c) = char::from_u32(cp) else { continue };
        let gid = face.glyph_index(c);
        if gid.is_some() {
            found += 1;
        }
        write!(text, "{cp}:{};", opt(gid.map(|g| g.0))).unwrap();
        if k < 20 || k % 1009 == 0 {
            writeln!(samples, "glyph_index {cp} {}", opt(gid.map(|g| g.0))).unwrap();
        }
        for vs in [0xFE00, 0xFE0E, 0xFE0F, 0xE0100] {
            let vs = char::from_u32(vs).unwrap();
            let v = face.glyph_variation_index(c, vs);
            if v.is_some() {
                vs_found += 1;
            }
            write!(vs_text, "{};", opt(v.map(|g| g.0))).unwrap();
        }
    }
    writeln!(
        out,
        "coverage {} found {found} fnv {:016x} vs_found {vs_found} vs_fnv {:016x}",
        all.len(),
        fnv(text.as_bytes()),
        fnv(vs_text.as_bytes())
    )
    .unwrap();
    out.push_str(&samples);
}

fn dump_kern(out: &mut String, face: &Face) {
    let Some(kern) = face.tables().kern else { return };
    let n = face.number_of_glyphs().min(128);
    for (i, subtable) in kern.subtables.into_iter().enumerate() {
        let format = match subtable.format {
            ttf_parser::kern::Format::Format0(_) => 0,
            ttf_parser::kern::Format::Format1(_) => 1,
            ttf_parser::kern::Format::Format2(_) => 2,
            ttf_parser::kern::Format::Format3(_) => 3,
        };
        let mut text = String::new();
        if let ttf_parser::kern::Format::Format0(ref st) = subtable.format {
            for pair in st.pairs {
                write!(
                    text,
                    "{}:{}:{}:{};",
                    pair.left().0,
                    pair.right().0,
                    pair.value,
                    opt(subtable.glyphs_kerning(pair.left(), pair.right()))
                )
                .unwrap();
            }
        }
        for l in 0..n {
            for r in 0..n {
                if let Some(v) = subtable.glyphs_kerning(GlyphId(l), GlyphId(r)) {
                    write!(text, "{l}:{r}:{v};").unwrap();
                }
            }
        }
        writeln!(
            out,
            "kern {i} horizontal {} variable {} cross {} state {} format {format} fnv {:016x}",
            subtable.horizontal,
            subtable.variable,
            subtable.has_cross_stream,
            subtable.has_state_machine,
            fnv(text.as_bytes())
        )
        .unwrap();
    }
}

fn dump_cff(out: &mut String, face: &Face) {
    let Some(cff) = face.tables().cff.as_ref() else { return };
    let m = cff.matrix();
    writeln!(
        out,
        "cff glyphs {} matrix {} {} {} {} {} {}",
        cff.number_of_glyphs(),
        f(m.sx),
        f(m.ky),
        f(m.kx),
        f(m.sy),
        f(m.tx),
        f(m.ty)
    )
    .unwrap();
    let mut text = String::new();
    for code in 0..=255u8 {
        write!(text, "{};", opt(cff.glyph_index(code).map(|g| g.0))).unwrap();
    }
    writeln!(out, "cff glyph_index fnv {:016x}", fnv(text.as_bytes())).unwrap();
    let mut text = String::new();
    for gid in 0..cff.number_of_glyphs() {
        let g = GlyphId(gid);
        let line = format!(
            "{gid} {} {} {}",
            opt(cff.glyph_width(g)),
            opt(cff.glyph_cid(g)),
            match cff.glyph_name(g) {
                Some(n) => esc(n),
                None => "-".into(),
            }
        );
        if is_sample(gid, cff.number_of_glyphs()) {
            writeln!(out, "cff glyph {line}").unwrap();
        }
        text.push_str(&line);
        text.push('\n');
    }
    writeln!(out, "cff glyphs fnv {:016x}", fnv(text.as_bytes())).unwrap();
}

fn dump_glyphs(out: &mut String, face: &Face, label: &str) {
    let count = face.number_of_glyphs();
    let mut block = String::new();
    let mut block_start = 0;
    for gid in 0..count {
        let g = GlyphId(gid);
        let mut path = PathBuilder(String::new());
        let bbox = face.outline_glyph(g, &mut path);
        let raster = match face.glyph_raster_image(g, u16::MAX) {
            Some(img) => format!(
                "{},{},{},{},{},{},{},{:016x}",
                raster_format(img.format),
                img.x,
                img.y,
                img.width,
                img.height,
                img.pixels_per_em,
                img.data.len(),
                fnv(img.data)
            ),
            None => "-".into(),
        };
        let svg = match face.glyph_svg_image(g) {
            Some(doc) => format!(
                "{}..{},{},{:016x}",
                doc.start_glyph_id.0,
                doc.end_glyph_id.0,
                doc.data.len(),
                fnv(doc.data)
            ),
            None => "-".into(),
        };
        let line = format!(
            "glyph {gid} adv {} vadv {} lsb {} tsb {} yorg {} name {} bbox {} path {:016x} color {} raster {raster} svg {svg}",
            opt(face.glyph_hor_advance(g)),
            opt(face.glyph_ver_advance(g)),
            opt(face.glyph_hor_side_bearing(g)),
            opt(face.glyph_ver_side_bearing(g)),
            opt(face.glyph_y_origin(g)),
            match face.glyph_name(g) {
                Some(n) => esc(n),
                None => "-".into(),
            },
            rect(bbox),
            fnv(path.0.as_bytes()),
            face.is_color_glyph(g),
        );
        if is_sample(gid, count) {
            writeln!(out, "{label}{line}").unwrap();
            if !path.0.is_empty() {
                writeln!(out, "{label}path {gid} {}", path.0.trim_end()).unwrap();
            }
        }
        block.push_str(&line);
        block.push('\n');
        if (gid + 1) % 256 == 0 || gid + 1 == count {
            writeln!(
                out,
                "{label}glyphs {block_start}..{gid} fnv {:016x}",
                fnv(block.as_bytes())
            )
            .unwrap();
            block.clear();
            block_start = gid + 1;
        }
    }
}
