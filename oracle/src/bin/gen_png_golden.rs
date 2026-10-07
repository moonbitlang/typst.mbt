//! Generates the oracle of damaged PNGs (`codecs/png_oracle_test.mbt`) from
//! the real `image` and `png` crates.
//!
//! The seeds of `png_corpus.txt` (`scripts/gen_png_corpus.py`: small valid
//! PNGs of every colour type and bit depth) are damaged in the ways listed
//! in `damage` below: every single-bit flip in the first 64 bytes and a
//! sample of flips in the rest, truncation at every length, bit flips in the
//! data of every chunk with the CRC made right again (so that the damage
//! reaches the parsers and the decompressor), bit flips all over the zlib
//! stream of the image data, and changes of the chunk structure (a wrong CRC in each chunk, chunks removed, repeated, emptied,
//! grown and out of order, a wrong Adler-32, a cut and an overlong zlib
//! stream, a missing `IEND`, unknown chunks, ...), and other dimensions in
//! the header. The test (`codecs/png_damage_test.mbt`) makes the same
//! damaged files from the seeds, so only the seeds and one short hash per
//! case are stored.
//!
//! Expected per case: what upstream `RasterImage::new` gets from the `image`
//! crate (`PngDecoder::new`, the non-empty ICC profile,
//! `set_limits(Limits::default())`, `DynamicImage::from_decoder`), as in
//! `gen_image_golden`: `<width>x<height> <color type> <FNV-1a of the pixel
//! buffer> icc=<length or none>` or `error: <message>`; `panic` where
//! upstream panics. The cases with other dimensions also record what
//! `png::Decoder::new` (its default limit of 64 MiB, as krilla and tiny-skia
//! call it) with `Transformations::EXPAND` gives, in the same terms, and run
//! in a child process each, since upstream allocates the frame that the
//! header claims before it reads a row: `abort` where that kills the
//! process.
//!
//! Usage (from `oracle/`): `cargo run --release --bin gen_png_golden -- <codecs dir>`;
//! `-- --explain <seed> [<filter>]` prints the cases of a seed (whose
//! description contains the filter) with what upstream gives.

use std::io::Cursor;
use std::path::PathBuf;
use std::process::Command;

use base64::Engine;
use image::codecs::png::PngDecoder;
use image::{DynamicImage, ImageDecoder, ImageResult, Limits};

fn fnv1a(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in data {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

/// Upstream `RasterImage::new_impl`'s `decode`.
fn decode<T: ImageDecoder>(
    decoder: ImageResult<T>,
) -> ImageResult<(DynamicImage, Option<Vec<u8>>)> {
    let mut decoder = decoder?;
    let icc = decoder.icc_profile().ok().flatten().filter(|icc| !icc.is_empty());
    decoder.set_limits(Limits::default())?;
    let dynamic = DynamicImage::from_decoder(decoder)?;
    Ok((dynamic, icc))
}

/// What the `image` crate makes of a PNG (as in `gen_image_golden`).
fn decode_image(data: &[u8]) -> String {
    let result = std::panic::catch_unwind(|| decode(PngDecoder::new(Cursor::new(data))));
    match result {
        Ok(Ok((dynamic, icc))) => format!(
            "{}x{} {:?} {:016x} icc={}",
            dynamic.width(),
            dynamic.height(),
            dynamic.color(),
            fnv1a(dynamic.as_bytes()),
            icc.map_or("none".to_string(), |icc| icc.len().to_string()),
        ),
        Ok(Err(err)) => format!("error: {err}"),
        Err(_) => "panic".to_string(),
    }
}

/// What `png::Decoder::new` (the default limits) with
/// `Transformations::EXPAND`, `read_info` and `next_frame` make of a PNG
/// (krilla's `decode_png`), in the terms of `decode_image`: the errors as
/// `ImageError::from_png` maps them, the samples in native byte order.
fn decode_direct(data: &[u8]) -> String {
    fn error(err: png::DecodingError) -> String {
        match err {
            png::DecodingError::IoError(err) => format!("error: {err}"),
            err @ png::DecodingError::Format(_) => {
                format!("error: Format error decoding Png: {err}")
            }
            err @ png::DecodingError::Parameter(_) => {
                format!("error: The parameter is malformed: {err}")
            }
            png::DecodingError::LimitsExceeded => "error: Memory limit exceeded".to_string(),
        }
    }
    let result = std::panic::catch_unwind(|| {
        let mut decoder = png::Decoder::new(Cursor::new(data));
        decoder.set_transformations(png::Transformations::EXPAND);
        let mut reader = match decoder.read_info() {
            Ok(reader) => reader,
            Err(err) => return error(err),
        };
        let Some(size) = reader.output_buffer_size() else {
            return "error: Memory limit exceeded".to_string();
        };
        let mut buf = vec![0; size];
        let info = match reader.next_frame(&mut buf) {
            Ok(info) => info,
            Err(err) => return error(err),
        };
        let sixteen = info.bit_depth == png::BitDepth::Sixteen;
        if sixteen {
            for pair in buf.chunks_exact_mut(2) {
                pair.swap(0, 1);
            }
        }
        let color = match (info.color_type, sixteen) {
            (png::ColorType::Grayscale, false) => "L8",
            (png::ColorType::Grayscale, true) => "L16",
            (png::ColorType::GrayscaleAlpha, false) => "La8",
            (png::ColorType::GrayscaleAlpha, true) => "La16",
            (png::ColorType::Rgb, false) => "Rgb8",
            (png::ColorType::Rgb, true) => "Rgb16",
            (png::ColorType::Rgba, false) => "Rgba8",
            (png::ColorType::Rgba, true) => "Rgba16",
            (png::ColorType::Indexed, _) => unreachable!(),
        };
        let icc = reader.info().icc_profile.as_ref().filter(|icc| !icc.is_empty());
        format!(
            "{}x{} {} {:016x} icc={}",
            info.width,
            info.height,
            color,
            fnv1a(&buf),
            icc.map_or("none".to_string(), |icc| icc.len().to_string()),
        )
    });
    result.unwrap_or_else(|_| "panic".to_string())
}

// ---- The damage. `codecs/png_damage_test.mbt` is the same code. ----

/// xorshift32
struct Rng(u32);

impl Rng {
    fn next(&mut self) -> u32 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.0 = x;
        x
    }
}

#[derive(Clone)]
struct Chunk {
    ty: [u8; 4],
    data: Vec<u8>,
}

fn crc32(ty: &[u8], data: &[u8]) -> u32 {
    let mut crc = 0xFFFFFFFFu32;
    for &b in ty.iter().chain(data) {
        crc ^= b as u32;
        for _ in 0..8 {
            crc = if crc & 1 != 0 { 0xEDB88320 ^ (crc >> 1) } else { crc >> 1 };
        }
    }
    !crc
}

/// The chunks of a valid PNG.
fn parse(seed: &[u8]) -> Vec<Chunk> {
    let mut chunks = Vec::new();
    let mut pos = 8;
    while pos < seed.len() {
        let len = u32::from_be_bytes(seed[pos..pos + 4].try_into().unwrap()) as usize;
        chunks.push(Chunk {
            ty: seed[pos + 4..pos + 8].try_into().unwrap(),
            data: seed[pos + 8..pos + 8 + len].to_vec(),
        });
        pos += 12 + len;
    }
    chunks
}

fn write_chunk(out: &mut Vec<u8>, chunk: &Chunk) {
    out.extend_from_slice(&(chunk.data.len() as u32).to_be_bytes());
    out.extend_from_slice(&chunk.ty);
    out.extend_from_slice(&chunk.data);
    out.extend_from_slice(&crc32(&chunk.ty, &chunk.data).to_be_bytes());
}

/// A PNG of the chunks, with their CRCs.
fn build(chunks: &[Chunk]) -> Vec<u8> {
    let mut out = b"\x89PNG\r\n\x1a\n".to_vec();
    for chunk in chunks {
        write_chunk(&mut out, chunk);
    }
    out
}

fn chunk(ty: &[u8; 4], data: &[u8]) -> Chunk {
    Chunk { ty: *ty, data: data.to_vec() }
}

struct Case {
    desc: String,
    data: Vec<u8>,
    /// Decode with `png::Decoder::new` (`decode_direct`) instead of `image`.
    direct: bool,
    /// Run in a child process (the cases with other dimensions).
    child: bool,
}

/// The damaged files of a seed, in the order of the expectations.
fn damage(seed: &[u8], seed_index: usize) -> Vec<Case> {
    let mut cases: Vec<Case> = Vec::new();
    let mut add = |desc: String, data: Vec<u8>| {
        cases.push(Case { desc, data, direct: false, child: false })
    };
    let len = seed.len();
    let mut rng = Rng(0x9E3779B9 ^ (seed_index as u32 + 1).wrapping_mul(0x85EBCA6B));
    let flip = |i: usize, b: u32| {
        let mut data = seed.to_vec();
        data[i] ^= 1 << b;
        data
    };

    // Every single-bit flip in the first 64 bytes, and a sample in the rest.
    for i in 0..len.min(64) {
        for b in 0..8 {
            add(format!("flip {i}.{b}"), flip(i, b));
        }
    }
    if len > 64 {
        let step = ((len - 64) / 96).max(1);
        let mut i = 64;
        while i < len {
            let b = rng.next() % 8;
            add(format!("flip {i}.{b}"), flip(i, b));
            i += step;
        }
    }

    // Truncation at every length (of a long file: at the first 200, the
    // last 100 and a hundred lengths between).
    let step = if len <= 400 { 1 } else { ((len - 300) / 100).max(1) };
    let mut n = 0;
    while n < len {
        add(format!("trunc {n}"), seed[..n].to_vec());
        n += if n < 200 || n + 100 >= len { 1 } else { step };
    }

    // Bit flips in the data of every chunk, with the right CRC: every bit
    // of a chunk of up to 13 bytes, two bits of every byte of one of up to
    // 40 bytes, and of the first and the last 8 bytes and of 24 bytes
    // between of a longer one.
    let chunks = parse(seed);
    for (k, c) in chunks.iter().enumerate() {
        let m = c.data.len();
        let name = String::from_utf8_lossy(&c.ty).to_string();
        let mut positions: Vec<usize> = Vec::new();
        if m <= 40 {
            positions.extend(0..m);
        } else {
            positions.extend(0..8);
            let step = ((m - 16) / 24).max(1);
            let mut p = 8;
            while p < m - 8 && positions.len() < 32 {
                positions.push(p);
                p += step;
            }
            positions.extend(m - 8..m);
        }
        for p in positions {
            let bits: Vec<u32> = if m <= 13 {
                (0..8).collect()
            } else {
                let b = rng.next() % 8;
                vec![b, (b + 1 + rng.next() % 7) % 8]
            };
            for b in bits {
                let mut chunks = chunks.clone();
                chunks[k].data[p] ^= 1 << b;
                add(format!("fix {k}:{name} {p}.{b}"), build(&chunks));
            }
        }
    }

    // The chunk structure.
    let n = chunks.len();
    for k in 0..n {
        let name = String::from_utf8_lossy(&chunks[k].ty).to_string();
        // A wrong CRC.
        let mut data = b"\x89PNG\r\n\x1a\n".to_vec();
        for (j, c) in chunks.iter().enumerate() {
            write_chunk(&mut data, c);
            if j == k {
                let last = data.len() - 1;
                data[last] ^= 1;
            }
        }
        add(format!("badcrc {k}:{name}"), data);
        // Without the chunk.
        let mut c = chunks.clone();
        c.remove(k);
        add(format!("del {k}:{name}"), build(&c));
        // The chunk twice.
        let mut c = chunks.clone();
        c.insert(k, chunks[k].clone());
        add(format!("dup {k}:{name}"), build(&c));
        // The chunk and the next one in the other order.
        if k + 1 < n {
            let mut c = chunks.clone();
            c.swap(k, k + 1);
            add(format!("swap {k}:{name}"), build(&c));
        }
        // The chunk right after the header.
        if k >= 2 {
            let mut c = chunks.clone();
            let moved = c.remove(k);
            c.insert(1, moved);
            add(format!("first {k}:{name}"), build(&c));
        }
        // The chunk after the end.
        if k + 1 < n {
            let mut c = chunks.clone();
            let moved = c.remove(k);
            c.push(moved);
            add(format!("last {k}:{name}"), build(&c));
        }
        // The chunk without data.
        let mut c = chunks.clone();
        c[k].data.clear();
        add(format!("empty {k}:{name}"), build(&c));
        // The chunk with one more byte.
        let mut c = chunks.clone();
        c[k].data.push(0);
        add(format!("grow {k}:{name}"), build(&c));
    }
    // Eight and seven zero bytes instead of the last chunk; bytes after it.
    let without_last = build(&chunks[..n - 1]);
    let mut data = without_last.clone();
    data.extend_from_slice(&[0; 8]);
    add("tail8".to_string(), data);
    let mut data = without_last.clone();
    data.extend_from_slice(&[0; 7]);
    add("tail7".to_string(), data);
    let mut data = seed.to_vec();
    data.extend_from_slice(&[0xAA; 64]);
    add("garbage".to_string(), data);
    // The image data: the chunks before and after it, and its bytes.
    let first = chunks.iter().position(|c| &c.ty == b"IDAT").unwrap();
    let last = chunks.iter().rposition(|c| &c.ty == b"IDAT").unwrap();
    let idat: Vec<u8> = chunks[first..=last].iter().flat_map(|c| c.data.clone()).collect();
    let with_idat = |parts: Vec<Chunk>| {
        let mut c = chunks[..first].to_vec();
        c.extend(parts);
        c.extend_from_slice(&chunks[last + 1..]);
        build(&c)
    };
    // In chunks of one byte, and in one chunk.
    add(
        "idat1".to_string(),
        with_idat(idat.iter().map(|&b| chunk(b"IDAT", &[b])).collect()),
    );
    add("idatall".to_string(), with_idat(vec![chunk(b"IDAT", &idat)]));
    // Empty chunks of image data around it.
    add(
        "idat0".to_string(),
        with_idat(vec![chunk(b"IDAT", &[]), chunk(b"IDAT", &idat), chunk(b"IDAT", &[])]),
    );
    // Another chunk in the middle of the image data.
    let half = idat.len() / 2;
    add(
        "idatsep".to_string(),
        with_idat(vec![
            chunk(b"IDAT", &idat[..half]),
            chunk(b"tEXt", b"k\0v"),
            chunk(b"IDAT", &idat[half..]),
        ]),
    );
    // A wrong Adler-32: one bit, and all of it.
    let mut z = idat.clone();
    let end = z.len();
    z[end - 1] ^= 1;
    add("adler".to_string(), with_idat(vec![chunk(b"IDAT", &z)]));
    let mut z = idat.clone();
    for b in &mut z[end - 4..] {
        *b = 0;
    }
    add("adler0".to_string(), with_idat(vec![chunk(b"IDAT", &z)]));
    // The zlib stream cut (by 2, 5 and 9 bytes and to its half) and
    // followed by more bytes.
    for cut in [2, 5, 9, end - half] {
        add(format!("zcut {cut}"), with_idat(vec![chunk(b"IDAT", &idat[..end - cut])]));
    }
    let mut z = idat.clone();
    z.extend_from_slice(&[0x55; 16]);
    add("zextra".to_string(), with_idat(vec![chunk(b"IDAT", &z)]));
    // Bit flips in the zlib stream (with the right CRC): two bits of every
    // byte, of three hundred bytes of a long stream.
    let step = (end / 300).max(1);
    let mut p = 0;
    while p < end {
        let b = rng.next() % 8;
        for b in [b, (b + 1 + rng.next() % 7) % 8] {
            let mut z = idat.clone();
            z[p] ^= 1 << b;
            add(format!("z {p}.{b}"), with_idat(vec![chunk(b"IDAT", &z)]));
        }
        p += step;
    }
    // Unknown chunks after the header: a critical one and an ancillary one.
    for ty in [b"ABCD", b"abCd"] {
        let mut c = chunks.clone();
        c.insert(1, chunk(ty, b"xy"));
        add(format!("unknown {}", String::from_utf8_lossy(ty)), build(&c));
    }
    // Every byte in a chunk type (the first seed only): the type is printed
    // in the error of a critical chunk.
    if seed_index == 0 {
        for pos in 0..2 {
            for v in 0..=255u8 {
                let mut ty = *b"ABCD";
                ty[pos] = v;
                let mut c = chunks.clone();
                c.insert(1, chunk(&ty, b"xy"));
                add(format!("type {pos}:{v}"), build(&c));
            }
        }
    }

    // Other dimensions in the header (with the right CRC). An interlaced
    // image is not made wider than 2^24 + 1 pixels: upstream fills a buffer
    // of a row of the full width before it reads the first row.
    let width = u32::from_be_bytes(chunks[0].data[0..4].try_into().unwrap());
    let height = u32::from_be_bytes(chunks[0].data[4..8].try_into().unwrap());
    let interlaced = chunks[0].data[12] != 0;
    let mut dims: Vec<(u32, u32)> = vec![
        (0, height),
        (width, 0),
        (1, 1),
        (width + 1, height),
        (width, height + 1),
        (width - 1, height),
        (width, height - 1),
        (2 * width, height),
        (width, 2 * height),
        (65536, 65536),
        ((1 << 24) + 1, height),
        (width, 0x7FFFFFFF),
        (width, 0xFFFFFFFF),
        (1 << 20, 1 << 20),
        (0xFFFFFFFF, 0xFFFFFFFF),
    ];
    if !interlaced {
        dims.extend([(0x7FFFFFFF, height), (0x80000000, 1), (0x7FFFFFFF, 0x7FFFFFFF)]);
    }
    for (w, h) in dims {
        let mut c = chunks.clone();
        c[0].data[0..4].copy_from_slice(&w.to_be_bytes());
        c[0].data[4..8].copy_from_slice(&h.to_be_bytes());
        let data = build(&c);
        cases.push(Case {
            desc: format!("dims {w}x{h}"),
            data: data.clone(),
            direct: false,
            child: true,
        });
        cases.push(Case { desc: format!("dims {w}x{h} direct"), data, direct: true, child: true });
    }
    cases
}

// ---- The expectations. ----

fn corpus() -> Vec<(String, Vec<u8>)> {
    let mut cases: Vec<(String, String)> = Vec::new();
    for line in include_str!("png_corpus.txt").lines() {
        if let Some(n) = line.strip_prefix("=== ") {
            cases.push((n.trim().to_string(), String::new()));
        } else if let Some(last) = cases.last_mut() {
            last.1.push_str(line.trim());
        }
    }
    cases
        .into_iter()
        .map(|(name, b64)| {
            (name, base64::engine::general_purpose::STANDARD.decode(&b64).expect("base64"))
        })
        .collect()
}

fn outcome(case: &Case) -> String {
    if case.direct { decode_direct(&case.data) } else { decode_image(&case.data) }
}

/// The outcome of a case, of one that runs in a child process: `abort` if
/// the child does not exit.
fn run(case: &Case, seed_index: usize, case_index: usize) -> String {
    if !case.child {
        return outcome(case);
    }
    let output = Command::new(std::env::current_exe().unwrap())
        .args(["--child", &seed_index.to_string(), &case_index.to_string()])
        .output()
        .expect("child");
    if output.status.success() {
        String::from_utf8(output.stdout).unwrap()
    } else {
        "abort".to_string()
    }
}

/// 24 bits of the FNV-1a hash of an outcome, as four characters.
fn short_hash(outcome: &str) -> String {
    match outcome {
        "panic" => return "!!!!".to_string(),
        "abort" => return "####".to_string(),
        _ => {}
    }
    let mut h: u32 = 0x811c9dc5;
    for &b in outcome.as_bytes() {
        h ^= b as u32;
        h = h.wrapping_mul(0x01000193);
    }
    let h = (h ^ (h >> 24)) & 0xFFFFFF;
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    (0..4).map(|i| ALPHABET[((h >> (18 - 6 * i)) & 63) as usize] as char).collect()
}

/// The class of an outcome: the outcome without what varies with the case.
fn class(outcome: &str) -> String {
    if !outcome.starts_with("error: ") {
        return if outcome == "panic" || outcome == "abort" {
            outcome.to_string()
        } else {
            "decoded".to_string()
        };
    }
    let mut out = String::new();
    let mut rest = outcome;
    // Hexadecimal numbers and chunk types.
    while !rest.is_empty() {
        if let Some(r) = rest.strip_prefix("0x") {
            let n = r.find(|c: char| !c.is_ascii_hexdigit()).unwrap_or(r.len());
            out.push_str("0x#");
            rest = &r[n..];
        } else if let Some(r) = rest.strip_prefix("ChunkType { type: ") {
            let n = r.find(", critical").unwrap();
            let known = matches!(&r[..n], "IHDR" | "PLTE" | "IDAT" | "IEND" | "fcTL" | "fdAT");
            out.push_str("ChunkType { type: ");
            out.push_str(if known { &r[..n] } else { "#" });
            rest = &r[n..];
            let n = rest.find('}').unwrap();
            if !known {
                out.push_str(", ..");
                rest = &rest[n - 1..];
            }
        } else if rest.as_bytes()[0].is_ascii_digit() {
            let n = rest.find(|c: char| !c.is_ascii_digit()).unwrap_or(rest.len());
            out.push('#');
            rest = &rest[n..];
        } else {
            let c = rest.chars().next().unwrap();
            out.push(c);
            rest = &rest[c.len_utf8()..];
        }
    }
    out
}

fn escape(s: &str) -> String {
    let mut out = String::new();
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            c if (c as u32) < 0x20 || (0x7F..0xA0).contains(&(c as u32)) => {
                out.push_str(&format!("\\u{{{:x}}}", c as u32))
            }
            c => out.push(c),
        }
    }
    out
}

fn main() {
    // A panic is an outcome; its message is not printed.
    std::panic::set_hook(Box::new(|_| {}));
    let args: Vec<String> = std::env::args().skip(1).collect();
    let seeds = corpus();
    if args.first().map(String::as_str) == Some("--child") {
        let seed_index: usize = args[1].parse().unwrap();
        let case_index: usize = args[2].parse().unwrap();
        let cases = damage(&seeds[seed_index].1, seed_index);
        print!("{}", outcome(&cases[case_index]));
        return;
    }
    if args.first().map(String::as_str) == Some("--explain") {
        let seed_index = seeds.iter().position(|(name, _)| *name == args[1]).expect("seed");
        let filter = args.get(2).cloned().unwrap_or_default();
        for (i, case) in damage(&seeds[seed_index].1, seed_index).iter().enumerate() {
            if case.desc.contains(&filter) {
                let outcome = run(case, seed_index, i);
                println!("{i} {}: {} {outcome}", case.desc, short_hash(&outcome));
            }
        }
        return;
    }

    let dir = PathBuf::from(args.first().expect("codecs dir"));
    let mut tests = String::new();
    // class -> (count, seed, case index, description, outcome of the first case)
    let mut classes: Vec<(String, usize, String, usize, String, String)> = Vec::new();
    let mut total = 0;
    for (seed_index, (name, seed)) in seeds.iter().enumerate() {
        let valid = decode_image(seed);
        assert!(!valid.starts_with("error") && valid != "panic", "{name}: {valid}");
        let cases = damage(seed, seed_index);
        let mut hashes = String::new();
        for (i, case) in cases.iter().enumerate() {
            let outcome = run(case, seed_index, i);
            hashes.push_str(&short_hash(&outcome));
            let mut class = class(&outcome);
            if case.direct {
                class.push_str(" (png::Decoder::new)");
            }
            match classes.iter_mut().find(|c| c.0 == class) {
                Some(c) => c.1 += 1,
                None => classes.push((class, 1, name.clone(), i, case.desc.clone(), outcome)),
            }
        }
        total += cases.len();
        let b64 = base64::engine::general_purpose::STANDARD.encode(seed);
        tests.push_str(&format!(
            "\n///|\ntest \"png/damage/{name}\" {{\n  png_damage_seed(\n    {seed_index},\n    \"{b64}\",\n    \"{}\",\n    {},\n    \"{}\",\n  )\n}}\n",
            escape(&valid),
            cases.len(),
            hashes,
        ));
    }

    let mut s = String::from(
        "// Generated by oracle/src/bin/gen_png_golden.rs from png_corpus.txt. Do not\n\
         // edit. Expected values are the outputs of the real `image` crate (and of\n\
         // `png::Decoder::new` where a case says so) for damaged copies of the seeds\n\
         // (see `png_damage_seed` in png_damage_test.mbt): four characters per case, a\n\
         // hash of the outcome, `!!!!` where upstream panics, `####` where it aborts.\n\
         //\n",
    );
    s.push_str(&format!(
        "// {total} cases of {} seeds. Cases per outcome (numbers and the types of\n// ancillary chunks left out):\n//\n",
        seeds.len()
    ));
    classes.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    for (class, count, ..) in &classes {
        s.push_str(&format!("// {count:>6}  {}\n", escape(class)));
    }
    // One case of every class with its whole outcome.
    s.push_str("\n///|\ntest \"png/damage/outcomes\" {\n");
    for (_, _, name, i, desc, outcome) in &classes {
        let seed_index = seeds.iter().position(|(n, _)| n == name).unwrap();
        let b64 = base64::engine::general_purpose::STANDARD.encode(&seeds[seed_index].1);
        s.push_str(&format!(
            "  png_damage_outcome(\n    {seed_index},\n    \"{b64}\",\n    {i},\n    \"{}\",\n    \"{}\",\n  )\n",
            escape(desc),
            escape(outcome),
        ));
    }
    s.push_str("}\n");
    s.push_str(&tests);
    std::fs::write(dir.join("png_oracle_test.mbt"), s).unwrap();
    eprintln!("{total} cases");
    for (class, count, ..) in &classes {
        eprintln!("{count:>6}  {class}");
    }
}
