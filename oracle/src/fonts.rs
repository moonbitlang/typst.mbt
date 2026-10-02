//! The font manifest of the test world (`tests/golden/fonts.json`).
//!
//! The upstream test world (`world.rs`, like `tests/src/world.rs`) loads
//! `typst_assets::fonts()` followed by `typst_dev_assets::fonts()` and splits
//! every file into its faces with `Font::iter`. The resulting order is the
//! font book order, which determines font fallback, so it must be reproduced
//! exactly by the port. This module records every face in that order: its
//! source file, face index, SHA-256 of the file bytes, family, PostScript
//! name, units per em and variant.
//!
//! Neither asset crate exposes its file names, so they are listed here (in
//! the crates' order, pinned by the revisions in `Cargo.toml`) and checked
//! against the actual data at runtime.

use std::fmt::Write as _;

use sha2::{Digest, Sha256};
use typst::foundations::Bytes;
use typst::text::Font;

/// The fonts of `typst-assets@94dcb99`, in the order of `typst_assets::fonts()`.
const ASSETS_FONTS: &[&str] = &[
    "fonts/LibertinusSerif-Regular.otf",
    "fonts/LibertinusSerif-Bold.otf",
    "fonts/LibertinusSerif-Italic.otf",
    "fonts/LibertinusSerif-BoldItalic.otf",
    "fonts/LibertinusSerif-Semibold.otf",
    "fonts/LibertinusSerif-SemiboldItalic.otf",
    "fonts/NewCMMath-Bold.otf",
    "fonts/NewCMMath-Book.otf",
    "fonts/NewCMMath-Regular.otf",
    "fonts/NewCM10-Regular.otf",
    "fonts/NewCM10-Bold.otf",
    "fonts/NewCM10-Italic.otf",
    "fonts/NewCM10-BoldItalic.otf",
    "fonts/DejaVuSansMono-Bold.ttf",
    "fonts/DejaVuSansMono-BoldOblique.ttf",
    "fonts/DejaVuSansMono-Oblique.ttf",
    "fonts/DejaVuSansMono.ttf",
];

/// The fonts of `typst-dev-assets@e26d7ca`, in the order of
/// `typst_dev_assets::fonts()`.
const DEV_ASSETS_FONTS: &[&str] = &[
    "fonts/Asana-Math.otf",
    "fonts/Cantarell-VF.otf",
    "fonts/CascadiaCode-Regular.ttf",
    "fonts/CascadiaMono-Bold.ttf",
    "fonts/CascadiaMono-Regular.ttf",
    "fonts/Concrete-Math.otf",
    "fonts/DejaVuSans-Oblique.ttf",
    "fonts/DejaVuSans.ttf",
    "fonts/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf",
    "fonts/Fraunces[SOFT,WONK,opsz,wght].ttf",
    "fonts/Garamond-Math.otf",
    "fonts/HKGrotesk-BlackItalic.ttf",
    "fonts/HKGrotesk-Bold.ttf",
    "fonts/HKGrotesk-BoldItalic.ttf",
    "fonts/HKGrotesk-ExtraBold.ttf",
    "fonts/HKGrotesk-ExtraBoldItalic.ttf",
    "fonts/HKGrotesk-ExtraLight.ttf",
    "fonts/HKGrotesk-ExtraLightItalic.ttf",
    "fonts/HKGrotesk-Italic.ttf",
    "fonts/HKGrotesk-Light.ttf",
    "fonts/HKGrotesk-LightItalic.ttf",
    "fonts/HKGrotesk-Medium.ttf",
    "fonts/HKGrotesk-MediumItalic.ttf",
    "fonts/HKGrotesk-Regular.ttf",
    "fonts/HKGrotesk-SemiBold.ttf",
    "fonts/HKGrotesk-SemiBoldItalic.ttf",
    "fonts/HKGrotesk-Thin.ttf",
    "fonts/IBMPlexMath-Regular.otf",
    "fonts/IBMPlexSans-Bold.ttf",
    "fonts/IBMPlexSans-Light.ttf",
    "fonts/IBMPlexSans-Medium.ttf",
    "fonts/IBMPlexSans-Regular.ttf",
    "fonts/IBMPlexSansCondensed-Regular.ttf",
    "fonts/IBMPlexSansDevanagari-Regular.ttf",
    "fonts/IBMPlexSerif-Regular.ttf",
    "fonts/InriaSerif-Bold.ttf",
    "fonts/InriaSerif-BoldItalic.ttf",
    "fonts/InriaSerif-Italic.ttf",
    "fonts/InriaSerif-Regular.ttf",
    "fonts/LibertinusMath-Regular.otf",
    "fonts/MonaSansVF[wdth,wght,opsz,ital].ttf",
    "fonts/NotoColorEmoji-Regular-CBDT.subset.ttf",
    "fonts/NotoColorEmoji-Regular-COLR.subset.ttf",
    "fonts/NotoSans-Regular.ttf",
    "fonts/NotoSansArabic-Regular.ttf",
    "fonts/NotoSansMath-Regular.ttf",
    "fonts/NotoSansSymbols2-Regular.ttf",
    "fonts/NotoSansThai-Regular.ttf",
    "fonts/NotoSerifCJKjp-Regular.otf",
    "fonts/NotoSerifCJKkr-Regular.otf",
    "fonts/NotoSerifCJKsc-Bold.otf",
    "fonts/NotoSerifCJKsc-Regular.otf",
    "fonts/NotoSerifCJKtc-Bold.otf",
    "fonts/NotoSerifCJKtc-Regular.otf",
    "fonts/NotoSerifHebrew-Bold.ttf",
    "fonts/NotoSerifHebrew-Regular.ttf",
    "fonts/PTSans-Regular.ttf",
    "fonts/PennstanderMath-Regular.otf",
    "fonts/Roboto-Regular.ttf",
    "fonts/RobotoFlex-VariableFont_GRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght.ttf",
    "fonts/STIXTwoMath-Regular.otf",
    "fonts/SourceSerif4-Regular.otf",
    "fonts/SourceSerif4Variable-Italic.otf",
    "fonts/SourceSerif4Variable-Roman.otf",
    "fonts/TwitterColorEmoji.ttf",
    "fonts/Ubuntu-Regular.ttf",
    "fonts/XITSMath-Regular.otf",
    "fonts/texgyrebonum-math.otf",
];

/// The lowercase hex SHA-256 of some bytes.
pub fn sha256_hex(data: &[u8]) -> String {
    let digest = Sha256::digest(data);
    let mut out = String::with_capacity(64);
    for b in digest {
        write!(out, "{b:02x}").unwrap();
    }
    out
}

/// A font file of the test world.
struct FontFile {
    source: &'static str,
    path: &'static str,
    data: &'static [u8],
}

/// All font files of the test world, in book order.
fn font_files() -> Vec<FontFile> {
    let assets: Vec<&'static [u8]> = typst_assets::fonts().collect();
    assert_eq!(assets.len(), ASSETS_FONTS.len(), "typst-assets font list changed");
    let dev: Vec<&'static [u8]> = typst_dev_assets::fonts().collect();
    assert_eq!(dev.len(), DEV_ASSETS_FONTS.len(), "typst-dev-assets font list changed");
    let mut files = vec![];
    for (data, path) in assets.into_iter().zip(ASSETS_FONTS) {
        files.push(FontFile { source: "typst-assets", path, data });
    }
    for (data, path) in dev.into_iter().zip(DEV_ASSETS_FONTS) {
        let by_name = typst_dev_assets::get(path).expect("dev asset font exists");
        assert!(by_name == data, "dev asset font order changed at {path}");
        files.push(FontFile { source: "typst-dev-assets", path, data });
    }
    files
}

/// The font manifest as JSON: one object per face, in book order (exactly
/// the order of `TestBase::fonts` in `world.rs`).
///
/// ```text
/// {"version":"typst-fonts-v1","fonts":[
/// {"index":0,"source":"typst-assets","path":"fonts/...","face":0,"sha256":"...","size":123,"family":"...","postscript_name":"..."|null,"upem":1000,"style":"normal","weight":400,"stretch":1000},
/// ...
/// ]}
/// ```
pub fn manifest() -> String {
    let mut out = String::from("{\"version\":\"typst-fonts-v1\",\"fonts\":[\n");
    let mut index = 0;
    for file in font_files() {
        let sha = sha256_hex(file.data);
        for font in Font::iter(Bytes::new(file.data)) {
            let face = font.index();
            let ttf = ttf_parser::Face::parse(file.data, face).unwrap();
            let info = font.info();
            let variant = info.variant;
            let style = match variant.style {
                typst::text::FontStyle::Normal => "normal",
                typst::text::FontStyle::Italic => "italic",
                typst::text::FontStyle::Oblique => "oblique",
            };
            let stretch = (variant.stretch.to_ratio().get() * 1000.0).round() as u32;
            if index > 0 {
                out.push_str(",\n");
            }
            write!(
                out,
                "{{\"index\":{index},\"source\":{},\"path\":{},\"face\":{face},\"sha256\":{},\"size\":{},\"family\":{},\"postscript_name\":{},\"upem\":{},\"style\":{},\"weight\":{},\"stretch\":{stretch}}}",
                json_str(file.source),
                json_str(file.path),
                json_str(&sha),
                file.data.len(),
                json_str(&info.family),
                match font.post_script_name() {
                    Some(name) => json_str(&name),
                    None => "null".into(),
                },
                ttf.units_per_em(),
                json_str(style),
                variant.weight.to_number(),
            )
            .unwrap();
            index += 1;
        }
    }
    out.push_str("\n]}\n");
    out
}

/// Encode a string as a JSON string literal. Only `"`, `\` and control
/// characters below U+0020 are escaped (as `\b`, `\t`, `\n`, `\f`, `\r` or
/// `\u00xx` with lowercase hex digits); everything else is emitted as is.
pub fn json_str(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\u{8}' => out.push_str("\\b"),
            '\t' => out.push_str("\\t"),
            '\n' => out.push_str("\\n"),
            '\u{c}' => out.push_str("\\f"),
            '\r' => out.push_str("\\r"),
            c if (c as u32) < 0x20 => write!(out, "\\u{:04x}", c as u32).unwrap(),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}
