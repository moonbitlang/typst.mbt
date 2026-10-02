use hayro_interpret::InterpreterSettings;
use hayro_interpret::font::{FontData, FontQuery, StandardFont};
use hayro_svg::{RenderCache, SvgRenderSettings};
use hayro_syntax::Pdf;
use std::sync::Arc;

fn select_standard_font(font: StandardFont) -> Option<(FontData, u32)> {
    let bytes = match font {
        StandardFont::Helvetica => typst_assets::pdf::SANS,
        StandardFont::HelveticaBold => typst_assets::pdf::SANS_BOLD,
        StandardFont::HelveticaOblique => typst_assets::pdf::SANS_ITALIC,
        StandardFont::HelveticaBoldOblique => typst_assets::pdf::SANS_BOLD_ITALIC,
        StandardFont::Courier => typst_assets::pdf::FIXED,
        StandardFont::CourierBold => typst_assets::pdf::FIXED_BOLD,
        StandardFont::CourierOblique => typst_assets::pdf::FIXED_ITALIC,
        StandardFont::CourierBoldOblique => typst_assets::pdf::FIXED_BOLD_ITALIC,
        StandardFont::TimesRoman => typst_assets::pdf::SERIF,
        StandardFont::TimesBold => typst_assets::pdf::SERIF_BOLD,
        StandardFont::TimesItalic => typst_assets::pdf::SERIF_ITALIC,
        StandardFont::TimesBoldItalic => typst_assets::pdf::SERIF_BOLD_ITALIC,
        StandardFont::ZapfDingBats => typst_assets::pdf::DING_BATS,
        StandardFont::Symbol => typst_assets::pdf::SYMBOL,
    };
    Some((Arc::new(bytes), 0))
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args[1].as_str() {
        // svg <pdf> [page-index]: the page as SVG, like typst-svg's `pdf_to_svg`.
        "svg" => {
            let data = std::fs::read(&args[2]).unwrap();
            let pdf = Pdf::new(data).unwrap();
            let page_idx: usize = args.get(3).map(|s| s.parse().unwrap()).unwrap_or(0);
            let pages = pdf.pages();
            let page = &pages[page_idx];
            let settings = InterpreterSettings {
                font_resolver: Arc::new(move |query| match query {
                    FontQuery::Standard(s) => select_standard_font(*s),
                    FontQuery::Fallback(f) => select_standard_font(f.pick_standard_font()),
                }),
                cmap_resolver: Arc::new(|_| None),
                warning_sink: Arc::new(|_| {}),
                render_annotations: false,
            };
            let cache = RenderCache::new();
            let svg = hayro_svg::convert(
                page,
                &cache,
                &settings,
                &SvgRenderSettings {
                    bg_color: [0, 0, 0, 0],
                },
            );
            print!("{svg}");
        }
        _ => panic!("unknown command"),
    }
}
