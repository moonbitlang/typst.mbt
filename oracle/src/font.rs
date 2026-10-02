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
    dump_layout(out, &face);
    dump_math(out, &face);
    dump_colr(out, &face);

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

/// Accumulates per-glyph lines into hashed blocks of 256 glyphs, printing a
/// sample of the lines in full.
struct Blocks<'a> {
    out: &'a mut String,
    prefix: &'static str,
    count: u16,
    block: String,
    start: u16,
}

impl<'a> Blocks<'a> {
    fn new(out: &'a mut String, prefix: &'static str, count: u16) -> Self {
        Self { out, prefix, count, block: String::new(), start: 0 }
    }

    fn push(&mut self, gid: u16, line: &str) {
        if is_sample(gid, self.count) {
            writeln!(self.out, "{} {gid} {line}", self.prefix).unwrap();
        }
        self.block.push_str(line);
        self.block.push('\n');
        if (gid + 1) % 256 == 0 || gid + 1 == self.count {
            writeln!(
                self.out,
                "{}s {}..{gid} fnv {:016x}",
                self.prefix,
                self.start,
                fnv(self.block.as_bytes())
            )
            .unwrap();
            self.block.clear();
            self.start = gid + 1;
        }
    }
}

fn glyph_class(c: Option<ttf_parser::gdef::GlyphClass>) -> &'static str {
    use ttf_parser::gdef::GlyphClass::*;
    match c {
        Some(Base) => "Base",
        Some(Ligature) => "Ligature",
        Some(Mark) => "Mark",
        Some(Component) => "Component",
        None => "-",
    }
}

fn join<T: std::fmt::Display>(items: impl IntoIterator<Item = T>) -> String {
    items.into_iter().map(|i| i.to_string()).collect::<Vec<_>>().join(",")
}

fn dump_layout(out: &mut String, face: &Face) {
    use ttf_parser::gpos::PositioningSubtable;
    use ttf_parser::gsub::SubstitutionSubtable;
    let count = face.number_of_glyphs();
    if let Some(gdef) = face.tables().gdef {
        writeln!(out, "gdef has_glyph_classes {}", gdef.has_glyph_classes()).unwrap();
        let mut blocks = Blocks::new(out, "gdef glyph", count);
        for gid in 0..count {
            let g = GlyphId(gid);
            let line = format!(
                "{} {} {}",
                glyph_class(gdef.glyph_class(g)),
                gdef.glyph_mark_attachment_class(g),
                gdef.is_mark_glyph(g, None)
            );
            blocks.push(gid, &line);
        }
    }
    for (name, table) in [("gsub", face.tables().gsub), ("gpos", face.tables().gpos)] {
        let Some(table) = table else { continue };
        for script in table.scripts {
            let mut langs = vec![];
            if let Some(lang) = script.default_language {
                langs.push(lang);
            }
            langs.extend(script.languages);
            let mut text = format!("{name} script {}", esc(&script.tag.to_string()));
            for lang in langs {
                write!(
                    text,
                    " [{} req={} {}]",
                    esc(&lang.tag.to_string()),
                    opt(lang.required_feature),
                    join(lang.feature_indices)
                )
                .unwrap();
            }
            writeln!(out, "{text}").unwrap();
        }
        for (i, feature) in table.features.into_iter().enumerate() {
            writeln!(
                out,
                "{name} feature {i} {} {}",
                esc(&feature.tag.to_string()),
                join(feature.lookup_indices)
            )
            .unwrap();
        }
        writeln!(out, "{name} variations {}", table.variations.is_some()).unwrap();
        for (i, lookup) in table.lookups.into_iter().enumerate() {
            let mut kinds = vec![];
            let mut text = String::new();
            for k in 0..lookup.subtables.len() {
                let coverage = if name == "gsub" {
                    let Some(st) = lookup.subtables.get::<SubstitutionSubtable>(k) else {
                        kinds.push("?");
                        continue;
                    };
                    kinds.push(match st {
                        SubstitutionSubtable::Single(_) => "Single",
                        SubstitutionSubtable::Multiple(_) => "Multiple",
                        SubstitutionSubtable::Alternate(_) => "Alternate",
                        SubstitutionSubtable::Ligature(_) => "Ligature",
                        SubstitutionSubtable::Context(_) => "Context",
                        SubstitutionSubtable::ChainContext(_) => "ChainContext",
                        SubstitutionSubtable::ReverseChainSingle(_) => "ReverseChainSingle",
                    });
                    st.coverage()
                } else {
                    let Some(st) = lookup.subtables.get::<PositioningSubtable>(k) else {
                        kinds.push("?");
                        continue;
                    };
                    kinds.push(match st {
                        PositioningSubtable::Single(_) => "Single",
                        PositioningSubtable::Pair(_) => "Pair",
                        PositioningSubtable::Cursive(_) => "Cursive",
                        PositioningSubtable::MarkToBase(_) => "MarkToBase",
                        PositioningSubtable::MarkToLigature(_) => "MarkToLigature",
                        PositioningSubtable::MarkToMark(_) => "MarkToMark",
                        PositioningSubtable::Context(_) => "Context",
                        PositioningSubtable::ChainContext(_) => "ChainContext",
                    });
                    st.coverage()
                };
                for gid in 0..count {
                    if let Some(idx) = coverage.get(GlyphId(gid)) {
                        write!(text, "{gid}:{idx};").unwrap();
                    }
                }
                text.push('|');
            }
            writeln!(
                out,
                "{name} lookup {i} flags {} set {} subtables {} coverage {:016x}",
                lookup.flags.0,
                opt(lookup.mark_filtering_set),
                kinds.join(","),
                fnv(text.as_bytes())
            )
            .unwrap();
        }
    }
}

fn math_value(v: ttf_parser::math::MathValue) -> String {
    format!("{}{}", v.value, if v.device.is_some() { "d" } else { "" })
}

fn math_construction(c: Option<ttf_parser::math::GlyphConstruction>) -> String {
    let Some(c) = c else { return "-".into() };
    let mut text = String::new();
    for v in c.variants {
        write!(text, "{}:{},", v.variant_glyph.0, v.advance_measurement).unwrap();
    }
    if let Some(a) = c.assembly {
        write!(text, " asm {}", math_value(a.italics_correction)).unwrap();
        for p in a.parts {
            write!(
                text,
                " {}:{}:{}:{}:{}",
                p.glyph_id.0,
                p.start_connector_length,
                p.end_connector_length,
                p.full_advance,
                p.part_flags.extender()
            )
            .unwrap();
        }
    }
    text
}

fn math_kern(k: Option<ttf_parser::math::Kern>) -> String {
    let Some(k) = k else { return "-".into() };
    let mut text = format!("{}", k.count());
    for i in 0..k.count() {
        write!(text, ",{}", opt(k.height(i).map(math_value))).unwrap();
    }
    for i in 0..=k.count() {
        write!(text, ",{}", opt(k.kern(i).map(math_value))).unwrap();
    }
    text
}

fn dump_math(out: &mut String, face: &Face) {
    let Some(math) = face.tables().math else { return };
    if let Some(c) = math.constants {
        let values = [
            c.math_leading(),
            c.axis_height(),
            c.accent_base_height(),
            c.flattened_accent_base_height(),
            c.subscript_shift_down(),
            c.subscript_top_max(),
            c.subscript_baseline_drop_min(),
            c.superscript_shift_up(),
            c.superscript_shift_up_cramped(),
            c.superscript_bottom_min(),
            c.superscript_baseline_drop_max(),
            c.sub_superscript_gap_min(),
            c.superscript_bottom_max_with_subscript(),
            c.space_after_script(),
            c.upper_limit_gap_min(),
            c.upper_limit_baseline_rise_min(),
            c.lower_limit_gap_min(),
            c.lower_limit_baseline_drop_min(),
            c.stack_top_shift_up(),
            c.stack_top_display_style_shift_up(),
            c.stack_bottom_shift_down(),
            c.stack_bottom_display_style_shift_down(),
            c.stack_gap_min(),
            c.stack_display_style_gap_min(),
            c.stretch_stack_top_shift_up(),
            c.stretch_stack_bottom_shift_down(),
            c.stretch_stack_gap_above_min(),
            c.stretch_stack_gap_below_min(),
            c.fraction_numerator_shift_up(),
            c.fraction_numerator_display_style_shift_up(),
            c.fraction_denominator_shift_down(),
            c.fraction_denominator_display_style_shift_down(),
            c.fraction_numerator_gap_min(),
            c.fraction_num_display_style_gap_min(),
            c.fraction_rule_thickness(),
            c.fraction_denominator_gap_min(),
            c.fraction_denom_display_style_gap_min(),
            c.skewed_fraction_horizontal_gap(),
            c.skewed_fraction_vertical_gap(),
            c.overbar_vertical_gap(),
            c.overbar_rule_thickness(),
            c.overbar_extra_ascender(),
            c.underbar_vertical_gap(),
            c.underbar_rule_thickness(),
            c.underbar_extra_descender(),
            c.radical_vertical_gap(),
            c.radical_display_style_vertical_gap(),
            c.radical_rule_thickness(),
            c.radical_extra_ascender(),
            c.radical_kern_before_degree(),
            c.radical_kern_after_degree(),
        ];
        writeln!(
            out,
            "math constants {} {} {} {} {} {}",
            c.script_percent_scale_down(),
            c.script_script_percent_scale_down(),
            c.delimited_sub_formula_min_height(),
            c.display_operator_min_height(),
            c.radical_degree_bottom_raise_percent(),
            values.into_iter().map(math_value).collect::<Vec<_>>().join(" ")
        )
        .unwrap();
    }
    if let Some(v) = math.variants {
        writeln!(out, "math min_connector_overlap {}", v.min_connector_overlap).unwrap();
    }
    let count = face.number_of_glyphs();
    let mut blocks = Blocks::new(out, "math glyph", count);
    for gid in 0..count {
        let g = GlyphId(gid);
        let mut line = String::new();
        if let Some(info) = math.glyph_info {
            write!(
                line,
                "italic {} accent {} extended {} kern",
                opt(info.italic_corrections.and_then(|v| v.get(g)).map(math_value)),
                opt(info.top_accent_attachments.and_then(|v| v.get(g)).map(math_value)),
                info.extended_shapes.map(|c| c.contains(g)).unwrap_or(false),
            )
            .unwrap();
            match info.kern_infos.and_then(|k| k.get(g)) {
                Some(k) => write!(
                    line,
                    " {} {} {} {}",
                    math_kern(k.top_right),
                    math_kern(k.top_left),
                    math_kern(k.bottom_right),
                    math_kern(k.bottom_left)
                )
                .unwrap(),
                None => line.push_str(" -"),
            }
        }
        if let Some(v) = math.variants {
            write!(
                line,
                " vert {} horiz {}",
                math_construction(v.vertical_constructions.get(g)),
                math_construction(v.horizontal_constructions.get(g))
            )
            .unwrap();
        }
        blocks.push(gid, &line);
    }
}

fn rgba(c: ttf_parser::RgbaColor) -> String {
    format!("{},{},{},{}", c.red, c.green, c.blue, c.alpha)
}

struct ColrRecorder(String);

impl ColrRecorder {
    fn stops(
        &mut self,
        stops: ttf_parser::colr::GradientStopsIter,
        extend: ttf_parser::colr::GradientExtend,
    ) {
        use ttf_parser::colr::GradientExtend::*;
        let extend = match extend {
            Pad => "pad",
            Repeat => "repeat",
            Reflect => "reflect",
        };
        write!(self.0, "{extend}").unwrap();
        for stop in stops {
            write!(self.0, " {}@{}", rgba(stop.color), f(stop.stop_offset)).unwrap();
        }
    }
}

fn composite_mode(mode: ttf_parser::colr::CompositeMode) -> &'static str {
    use ttf_parser::colr::CompositeMode::*;
    match mode {
        Clear => "Clear",
        Source => "Source",
        Destination => "Destination",
        SourceOver => "SourceOver",
        DestinationOver => "DestinationOver",
        SourceIn => "SourceIn",
        DestinationIn => "DestinationIn",
        SourceOut => "SourceOut",
        DestinationOut => "DestinationOut",
        SourceAtop => "SourceAtop",
        DestinationAtop => "DestinationAtop",
        Xor => "Xor",
        Plus => "Plus",
        Screen => "Screen",
        Overlay => "Overlay",
        Darken => "Darken",
        Lighten => "Lighten",
        ColorDodge => "ColorDodge",
        ColorBurn => "ColorBurn",
        HardLight => "HardLight",
        SoftLight => "SoftLight",
        Difference => "Difference",
        Exclusion => "Exclusion",
        Multiply => "Multiply",
        Hue => "Hue",
        Saturation => "Saturation",
        Color => "Color",
        Luminosity => "Luminosity",
    }
}

impl<'a> ttf_parser::colr::Painter<'a> for ColrRecorder {
    fn outline_glyph(&mut self, glyph_id: GlyphId) {
        write!(self.0, "outline {};", glyph_id.0).unwrap();
    }
    fn paint(&mut self, paint: ttf_parser::colr::Paint<'a>) {
        use ttf_parser::colr::Paint;
        match paint {
            Paint::Solid(c) => write!(self.0, "solid {};", rgba(c)).unwrap(),
            Paint::LinearGradient(g) => {
                write!(
                    self.0,
                    "linear {} {} {} {} {} {} ",
                    f(g.x0),
                    f(g.y0),
                    f(g.x1),
                    f(g.y1),
                    f(g.x2),
                    f(g.y2)
                )
                .unwrap();
                self.stops(g.stops(0, &[]), g.extend);
                self.0.push(';');
            }
            Paint::RadialGradient(g) => {
                write!(
                    self.0,
                    "radial {} {} {} {} {} {} ",
                    f(g.x0),
                    f(g.y0),
                    f(g.r0),
                    f(g.r1),
                    f(g.x1),
                    f(g.y1)
                )
                .unwrap();
                self.stops(g.stops(0, &[]), g.extend);
                self.0.push(';');
            }
            Paint::SweepGradient(g) => {
                write!(
                    self.0,
                    "sweep {} {} {} {} ",
                    f(g.center_x),
                    f(g.center_y),
                    f(g.start_angle),
                    f(g.end_angle)
                )
                .unwrap();
                self.stops(g.stops(0, &[]), g.extend);
                self.0.push(';');
            }
        }
    }
    fn push_clip(&mut self) {
        self.0.push_str("clip;");
    }
    fn push_clip_box(&mut self, b: ttf_parser::colr::ClipBox) {
        write!(
            self.0,
            "clipbox {} {} {} {};",
            f(b.x_min),
            f(b.y_min),
            f(b.x_max),
            f(b.y_max)
        )
        .unwrap();
    }
    fn pop_clip(&mut self) {
        self.0.push_str("popclip;");
    }
    fn push_layer(&mut self, mode: ttf_parser::colr::CompositeMode) {
        write!(self.0, "layer {};", composite_mode(mode)).unwrap();
    }
    fn pop_layer(&mut self) {
        self.0.push_str("poplayer;");
    }
    fn push_transform(&mut self, t: ttf_parser::Transform) {
        write!(
            self.0,
            "transform {} {} {} {} {} {};",
            f(t.a),
            f(t.b),
            f(t.c),
            f(t.d),
            f(t.e),
            f(t.f)
        )
        .unwrap();
    }
    fn pop_transform(&mut self) {
        self.0.push_str("poptransform;");
    }
}

fn dump_colr(out: &mut String, face: &Face) {
    let Some(palettes) = face.color_palettes() else { return };
    writeln!(out, "colr palettes {}", palettes).unwrap();
    let count = face.number_of_glyphs();
    let mut blocks = Blocks::new(out, "colr glyph", count);
    for gid in 0..count {
        let g = GlyphId(gid);
        let mut rec = ColrRecorder(String::new());
        let res =
            face.paint_color_glyph(g, 0, ttf_parser::RgbaColor::new(1, 2, 3, 255), &mut rec);
        let line = format!("{} {}", res.is_some(), rec.0);
        blocks.push(gid, &line);
    }
}
