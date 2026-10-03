//! Records the output of hayro's image codecs (the revision Typst uses, with
//! the features hayro-interpret enables) for the codec oracle tests:
//!
//! - `streams <list>`: for every PDF listed in `<list>` (one path per line,
//!   relative to the module root, i.e. through the `target/hayro` symlink;
//!   `#` comments allowed), every stream object whose filters include
//!   `DCTDecode`, `JPXDecode`, `JBIG2Decode` or `CCITTFaxDecode` is decoded
//!   with `Stream::decoded_image` under a few `ImageDecodeParams` variants
//!   (see `variants`). One line per decoding:
//!   `path<TAB>obj gen<TAB>variant<TAB>result`, where the result is `E` (the
//!   `DecodeFailure` debug name) or `<len>:<fnv1a64 of the data>` followed by
//!   the image metadata. Checked by `hayro/syntax/codec_oracle_test.mbt`
//!   (`testdata/codec_streams.tsv`).
//! - `jpx <file>...`: decodes raw JPEG 2000 files (JP2 or J2K codestreams)
//!   with `hayro_jpeg2000::Image` under several `DecodeSettings`; one line per
//!   decoding: `path<TAB>settings<TAB>result`. Checked by
//!   `hayro/jpeg2000/oracle_test.mbt` (`testdata/oracle.tsv`).
//!
//! - `ccitt <cases.tsv>`: decodes the CCITT streams listed in `cases.tsv`
//!   (written by `scripts/gen_ccitt_test_files.py`; files relative to its
//!   `files/` directory) with `hayro_ccitt::decode` and the listed settings;
//!   one line per case: `file<TAB>case index<TAB>result<TAB>pixels`, where the
//!   result is `ok <bytes read>` or `E <error>` and `pixels` is
//!   `<rows> <len>:<fnv1a64>` of the pushed pixels (`1` white, `0` black,
//!   `\n` per completed row; chunks expanded). Checked by
//!   `hayro/ccitt/oracle_test.mbt` (`testdata/oracle.tsv`).
//! - `jbig2 <cases.tsv>`: decodes the JBIG2 files listed in `cases.tsv`
//!   (written by `scripts/gen_jbig2_test_files.py`; files relative to its
//!   `files/` directory) with `hayro_jbig2::Image::new` (kind `file`) or
//!   `Image::new_embedded` (kind `embedded`, with the listed globals or
//!   none); one line per case: `file<TAB>case index<TAB>result<TAB>pixels`,
//!   where the result is `E <error>` if parsing fails, else `<w>x<h> ok` or
//!   `<w>x<h> E <error>`, and `pixels` is `<rows> <len>:<fnv1a64>` of the
//!   pushed pixels (`1` black, `0` white, `[<1|0><count>]` per pixel chunk,
//!   `\n` per completed row). Checked by `hayro/jbig2/oracle_test.mbt`
//!   (`testdata/oracle.tsv`).
//!
//! Usage (in `oracle/`):
//! `cargo run --release --offline --bin gen_hayro_codec_tests -- streams ../hayro/syntax/testdata/codec_pdfs.txt > ../hayro/syntax/testdata/codec_streams.tsv`
//! `cargo run --release --offline --bin gen_hayro_codec_tests -- jpx ../hayro/jpeg2000/testdata/files/* > ../hayro/jpeg2000/testdata/oracle.tsv`
//! `cargo run --release --offline --bin gen_hayro_codec_tests -- ccitt ../hayro/ccitt/testdata/cases.tsv > ../hayro/ccitt/testdata/oracle.tsv`
//! `cargo run --release --offline --bin gen_hayro_codec_tests -- jbig2 ../hayro/jbig2/testdata/cases.tsv > ../hayro/jbig2/testdata/oracle.tsv`
//! (paths are printed relative to the module root).

use std::fmt::Write as _;

use hayro_syntax::object::stream::{ImageColorSpace, ImageDecodeParams};
use hayro_syntax::object::{Array, Name, Object};
use hayro_syntax::{Filter, Pdf};

/// FNV-1a (64 bit).
fn fnv(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in data {
        h = (h ^ *b as u64).wrapping_mul(0x100000001b3);
    }
    h
}

fn root() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("..")
}

/// The path relative to the module root (for paths given relative to
/// `oracle/`).
fn rel(path: &str) -> String {
    let abs = std::fs::canonicalize(path).unwrap();
    let root = std::fs::canonicalize(root()).unwrap();
    match abs.strip_prefix(&root) {
        Ok(p) => p.to_string_lossy().to_string(),
        Err(_) => path.to_string(),
    }
}

fn is_image_filter(f: &Filter) -> bool {
    matches!(
        f,
        Filter::DctDecode | Filter::JpxDecode | Filter::Jbig2Decode | Filter::CcittFaxDecode
    )
}

fn cs_name(cs: &Option<ImageColorSpace>) -> String {
    match cs {
        None => "-".into(),
        Some(ImageColorSpace::Gray) => "gray".into(),
        Some(ImageColorSpace::Rgb) => "rgb".into(),
        Some(ImageColorSpace::Cmyk) => "cmyk".into(),
        Some(ImageColorSpace::Unknown(n)) => format!("unknown{n}"),
    }
}

/// The `ImageDecodeParams` variants each image stream is decoded with.
fn variants(dict: &hayro_syntax::object::Dict<'_>, filters: &[Filter]) -> Vec<(String, ImageDecodeParams)> {
    let width = dict
        .get::<u32>(b"Width".as_ref())
        .or_else(|| dict.get::<u32>(b"W".as_ref()))
        .unwrap_or(0);
    let height = dict
        .get::<u32>(b"Height".as_ref())
        .or_else(|| dict.get::<u32>(b"H".as_ref()))
        .unwrap_or(0);
    let bpc = dict
        .get::<u8>(b"BPC".as_ref())
        .or_else(|| dict.get::<u8>(b"BitsPerComponent".as_ref()));
    let cs_indexed = dict
        .get::<Array<'_>>(b"ColorSpace".as_ref())
        .and_then(|a| a.iter::<Name<'_>>().next())
        .is_some_and(|n| n.as_ref() == b"Indexed" || n.as_ref() == b"I");
    let base = ImageDecodeParams {
        is_indexed: cs_indexed,
        bpc,
        num_components: None,
        target_dimension: None,
        width,
        height,
    };
    let mut out = vec![("base".to_string(), base.clone())];
    if filters
        .iter()
        .any(|f| matches!(f, Filter::Jbig2Decode | Filter::CcittFaxDecode))
    {
        out.push((
            "indexed".into(),
            ImageDecodeParams {
                is_indexed: !cs_indexed,
                ..base.clone()
            },
        ));
    }
    if filters.iter().any(|f| matches!(f, Filter::JpxDecode)) {
        out.push((
            "quarter".into(),
            ImageDecodeParams {
                target_dimension: Some((width / 4, height / 4)),
                ..base.clone()
            },
        ));
        out.push((
            "bpc4".into(),
            ImageDecodeParams {
                bpc: Some(4),
                ..base.clone()
            },
        ));
    }
    out
}

fn streams(list: &str) {
    println!("# path\tobj gen\tvariant\tresult (gen_hayro_codec_tests streams)");
    let list = std::fs::read_to_string(list).unwrap();
    for line in list.lines() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let path = line.trim();
        let data = std::fs::read(root().join(path)).unwrap();
        let Ok(pdf) = Pdf::new(data) else { continue };
        let mut lines = vec![];
        for o in pdf.objects() {
            let Object::Stream(s) = o else { continue };
            let filters = s.filters();
            if !filters.iter().any(is_image_filter) {
                continue;
            }
            let id = s.obj_id();
            for (name, params) in variants(s.dict(), &filters) {
                let mut out = String::new();
                match s.decoded_image(&params) {
                    Err(e) => write!(out, "E {e:?}").unwrap(),
                    Ok(r) => {
                        write!(out, "{}:{:016x}", r.data.len(), fnv(&r.data)).unwrap();
                        match &r.image_data {
                            None => out.push_str(" -"),
                            Some(i) => {
                                write!(
                                    out,
                                    " img {} {} {} {}",
                                    i.width,
                                    i.height,
                                    i.bits_per_component,
                                    cs_name(&i.color_space)
                                )
                                .unwrap();
                                match &i.alpha {
                                    None => out.push_str(" -"),
                                    Some(a) => {
                                        write!(out, " {}:{:016x}", a.len(), fnv(a)).unwrap()
                                    }
                                }
                            }
                        }
                    }
                }
                lines.push((
                    (id.obj_number, id.gen_number, name.clone()),
                    format!("{path}\t{} {}\t{name}\t{out}", id.obj_number, id.gen_number),
                ));
            }
        }
        // `Pdf::objects` yields objects at the same position in hash map
        // order, and an object can be yielded more than once.
        lines.sort();
        lines.dedup();
        for (_, l) in lines {
            println!("{l}");
        }
    }
}

fn jpx(files: &[String]) {
    println!("# path\tsettings\tresult (gen_hayro_codec_tests jpx)");
    for path in files {
        let data = std::fs::read(path).unwrap();
        let path = rel(path);
        // (resolve_palette_indices, strict, target resolution divisor)
        for (palette, strict, div) in [
            (true, false, 0u32),
            (false, false, 0),
            (true, true, 0),
            (true, false, 2),
            (true, false, 5),
        ] {
            let mut settings = hayro_jpeg2000::DecodeSettings {
                resolve_palette_indices: palette,
                strict,
                target_resolution: None,
            };
            let name = format!("p{} s{} d{div}", palette as u8, strict as u8);
            let mut out = String::new();
            match hayro_jpeg2000::Image::new(&data, &settings) {
                Err(e) => write!(out, "E {e}").unwrap(),
                Ok(image) => {
                    if div > 0 {
                        settings.target_resolution =
                            Some((image.width() / div, image.height() / div));
                    }
                    let image = if div > 0 {
                        hayro_jpeg2000::Image::new(&data, &settings).unwrap()
                    } else {
                        image
                    };
                    let cs = match image.color_space() {
                        hayro_jpeg2000::ColorSpace::Gray => "gray".to_string(),
                        hayro_jpeg2000::ColorSpace::RGB => "rgb".to_string(),
                        hayro_jpeg2000::ColorSpace::CMYK => "cmyk".to_string(),
                        hayro_jpeg2000::ColorSpace::Unknown { num_channels } => {
                            format!("unknown{num_channels}")
                        }
                        hayro_jpeg2000::ColorSpace::Icc {
                            profile,
                            num_channels,
                        } => format!("icc{num_channels}:{}:{:016x}", profile.len(), fnv(profile)),
                    };
                    write!(
                        out,
                        "{} {} {cs} a{} b{}",
                        image.width(),
                        image.height(),
                        image.has_alpha() as u8,
                        image.original_bit_depth()
                    )
                    .unwrap();
                    let mut ctx = hayro_jpeg2000::DecoderContext::default();
                    match image.decode(&mut ctx) {
                        Err(e) => write!(out, " E {e}").unwrap(),
                        Ok(d) => {
                            let comps = d
                                .components()
                                .iter()
                                .map(|c| format!("{}", c.bit_depth()))
                                .collect::<Vec<_>>()
                                .join(",");
                            let mut samples = vec![];
                            for c in d.components() {
                                for v in c.samples() {
                                    samples.extend_from_slice(&v.to_bits().to_le_bytes());
                                }
                            }
                            let data = d.data_u8();
                            write!(
                                out,
                                " c{comps} f{:016x} {}:{:016x}",
                                fnv(&samples),
                                data.len(),
                                fnv(&data)
                            )
                            .unwrap();
                        }
                    }
                }
            }
            println!("{path}\t{name}\t{out}");
        }
    }
}

struct CcittRecorder {
    out: Vec<u8>,
    rows: u32,
}

impl hayro_ccitt::Decoder for CcittRecorder {
    fn push_pixel(&mut self, white: bool) {
        self.out.push(if white { b'1' } else { b'0' });
    }

    fn push_pixel_chunk(&mut self, white: bool, chunk_count: u32) {
        let b = if white { b'1' } else { b'0' };
        self.out.extend(std::iter::repeat_n(b, chunk_count as usize * 8));
    }

    fn next_line(&mut self) {
        self.rows += 1;
        self.out.push(b'\n');
    }
}

fn ccitt(cases: &str) {
    println!("# file\tcase\tresult\tpixels (gen_hayro_codec_tests ccitt)");
    let dir = std::path::Path::new(cases).parent().unwrap().join("files");
    let list = std::fs::read_to_string(cases).unwrap();
    let mut index = 0;
    for line in list.lines() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let f: Vec<&str> = line.split('\t').collect();
        let data = std::fs::read(dir.join(f[0])).unwrap();
        let k: i32 = f[3].parse().unwrap();
        let settings = hayro_ccitt::DecodeSettings {
            columns: f[1].parse().unwrap(),
            rows: f[2].parse().unwrap(),
            end_of_line: f[4] == "1",
            rows_are_byte_aligned: f[5] == "1",
            end_of_block: f[6] == "1",
            encoding: if k < 0 {
                hayro_ccitt::EncodingMode::Group4
            } else if k == 0 {
                hayro_ccitt::EncodingMode::Group3_1D
            } else {
                hayro_ccitt::EncodingMode::Group3_2D { k: k as u32 }
            },
            invert_black: f[7] == "1",
        };
        let mut decoder = CcittRecorder { out: vec![], rows: 0 };
        let mut ctx = hayro_ccitt::DecoderContext::new(settings);
        let result = match hayro_ccitt::decode(&data, &mut decoder, &mut ctx) {
            Ok(n) => format!("ok {n}"),
            Err(e) => format!("E {e}"),
        };
        println!(
            "{}\t{index}\t{result}\t{} {}:{:016x}",
            f[0],
            decoder.rows,
            decoder.out.len(),
            fnv(&decoder.out)
        );
        index += 1;
    }
}

struct Jbig2Recorder {
    out: Vec<u8>,
    rows: u32,
}

impl hayro_jbig2::Decoder for Jbig2Recorder {
    fn push_pixel(&mut self, black: bool) {
        self.out.push(if black { b'1' } else { b'0' });
    }

    fn push_pixel_chunk(&mut self, black: bool, chunk_count: u32) {
        self.out
            .extend_from_slice(format!("[{}{chunk_count}]", black as u8).as_bytes());
    }

    fn next_line(&mut self) {
        self.rows += 1;
        self.out.push(b'\n');
    }
}

fn jbig2(cases: &str) {
    println!("# file\tcase\tresult\tpixels (gen_hayro_codec_tests jbig2)");
    let dir = std::path::Path::new(cases).parent().unwrap().join("files");
    let list = std::fs::read_to_string(cases).unwrap();
    let mut index = 0;
    for line in list.lines() {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let f: Vec<&str> = line.split('\t').collect();
        let data = std::fs::read(dir.join(f[0])).unwrap();
        let globals = (f[1] != "-").then(|| std::fs::read(dir.join(f[1])).unwrap());
        let mut rec = Jbig2Recorder { out: vec![], rows: 0 };
        let image = if f[2] == "file" {
            hayro_jbig2::Image::new(&data)
        } else {
            hayro_jbig2::Image::new_embedded(&data, globals.as_deref())
        };
        let result = match image {
            Err(e) => format!("E {e}"),
            Ok(image) => match image.decode(&mut rec) {
                Ok(()) => format!("{}x{} ok", image.width(), image.height()),
                Err(e) => format!("{}x{} E {e}", image.width(), image.height()),
            },
        };
        println!(
            "{}\t{index}\t{result}\t{} {}:{:016x}",
            f[0],
            rec.rows,
            rec.out.len(),
            fnv(&rec.out)
        );
        index += 1;
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("streams") => streams(&args[2]),
        Some("jpx") => jpx(&args[2..]),
        Some("ccitt") => ccitt(&args[2]),
        Some("jbig2") => jbig2(&args[2]),
        _ => panic!(
            "usage: gen_hayro_codec_tests streams <list> | jpx <file>... | ccitt <cases.tsv> | jbig2 <cases.tsv>"
        ),
    }
}
