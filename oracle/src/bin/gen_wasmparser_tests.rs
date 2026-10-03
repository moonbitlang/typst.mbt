//! Validates WebAssembly binaries with wasmparser 0.228.0 exactly like wasmi
//! 1.0.9 does when typst-library loads a plugin (`wasmi::Module::new` with
//! `Config::default()` and relaxed SIMD disabled), and records the outcome.
//! The `wasm-validate` runner stage runs the same driver on the MoonBit port
//! (`wasmparser/`) and compares.
//!
//! Usage: gen_wasmparser_tests <corpus dir> <plugins dir> > validate.tsv
//!
//! For every `.wasm` file below the corpus directory (sorted by relative
//! path), and for the Typst test plugins (as `plugins/<name>`), one line:
//!
//! ```text
//! <relative path>\tok
//! <relative path>\terr\t<Display of the BinaryReaderError>
//! <relative path>\tpanic          (a payload wasmi panics on)
//! ```
//!
//! For every binary that validates there are additionally lines for
//! deterministic mutations (truncations and byte replacements; 3 per corpus
//! file, 440 per plugin), keyed `<name>@<mutation>` where `<mutation>` is
//! `cut:<len>` (keep the first `len` bytes) or `set:<pos>:<byte>` (replace
//! the byte at `pos`, both decimal). Messages
//! escape `\` as `\\`, newline as `\n` and tab as `\t`.
//!
//! The driver (`validate_like_wasmi`) mirrors `wasmi::ModuleParser`'s
//! `parse_buffered` (`module/parser/{mod,buffered}.rs`), including how it
//! re-parses the payload that ends a parsing phase without consuming it, and
//! function bodies are validated like `FuncTranslationDriver`
//! (`engine/translator/driver.rs`): locals one by one with `define_locals`,
//! then operator by operator with `visit_operator`, `ensure_end` and
//! `finish`. Every result is cross-checked against the real
//! `wasmi::Module::new` (mismatches are reported on stderr).

use std::path::{Path, PathBuf};

use wasmparser::{
    BinaryReader, BinaryReaderError, Chunk, FunctionBody, Parser, Payload, Validator,
    WasmFeatures,
};

fn escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('\n', "\\n").replace('\t', "\\t")
}

/// `wasmi::Config::default()` features with `wasm_relaxed_simd(false)`.
fn features() -> WasmFeatures {
    let mut features = WasmFeatures::empty();
    features.set(WasmFeatures::MUTABLE_GLOBAL, true);
    features.set(WasmFeatures::MULTI_VALUE, true);
    features.set(WasmFeatures::MULTI_MEMORY, true);
    features.set(WasmFeatures::SATURATING_FLOAT_TO_INT, true);
    features.set(WasmFeatures::SIGN_EXTENSION, true);
    features.set(WasmFeatures::BULK_MEMORY, true);
    features.set(WasmFeatures::REFERENCE_TYPES, true);
    features.set(WasmFeatures::GC_TYPES, true);
    features.set(WasmFeatures::TAIL_CALL, true);
    features.set(WasmFeatures::EXTENDED_CONST, true);
    features.set(WasmFeatures::FLOATS, true);
    features.set(WasmFeatures::CUSTOM_PAGE_SIZES, false);
    features.set(WasmFeatures::MEMORY64, true);
    features.set(WasmFeatures::WIDE_ARITHMETIC, false);
    features.set(WasmFeatures::SIMD, true);
    features.set(WasmFeatures::RELAXED_SIMD, false);
    features
}

/// The outcome of the driver: `Ok`, a wasmparser error, or a payload wasmi
/// would panic on (`process_invalid_payload` after the validator accepted it).
enum Outcome {
    Ok,
    Err(BinaryReaderError),
    Panic(String),
}

struct Driver<'a> {
    parser: Parser,
    validator: Validator,
    buffer: &'a [u8],
}

impl<'a> Driver<'a> {
    /// `ModuleParser::next_payload`.
    fn next_payload(&mut self) -> Result<(usize, Payload<'a>), BinaryReaderError> {
        match self.parser.parse(self.buffer, true)? {
            Chunk::Parsed { consumed, payload } => Ok((consumed, payload)),
            Chunk::NeedMoreData(_) => unreachable!(),
        }
    }

    fn consume(&mut self, consumed: usize) {
        self.buffer = &self.buffer[consumed..];
    }

    /// `ModuleParser::process_invalid_payload`.
    fn invalid_payload(&mut self, payload: Payload<'_>) -> Result<Option<String>, BinaryReaderError> {
        self.validator.payload(&payload)?;
        Ok(Some(format!("{payload:?}")))
    }

    fn run(&mut self) -> Result<Option<String>, BinaryReaderError> {
        // parse_buffered_header
        loop {
            let (consumed, payload) = self.next_payload()?;
            match payload {
                Payload::Version { num, encoding, range } => {
                    self.validator.version(num, encoding, &range)?
                }
                Payload::TypeSection(s) => self.validator.type_section(&s)?,
                Payload::ImportSection(s) => self.validator.import_section(&s)?,
                Payload::FunctionSection(s) => self.validator.function_section(&s)?,
                Payload::TableSection(s) => self.validator.table_section(&s)?,
                Payload::MemorySection(s) => self.validator.memory_section(&s)?,
                Payload::GlobalSection(s) => self.validator.global_section(&s)?,
                Payload::ExportSection(s) => self.validator.export_section(&s)?,
                Payload::StartSection { func, range } => {
                    self.validator.start_section(func, &range)?
                }
                Payload::ElementSection(s) => self.validator.element_section(&s)?,
                Payload::DataCountSection { count, range } => {
                    self.validator.data_count_section(count, &range)?
                }
                Payload::CodeSectionStart { count, range, .. } => {
                    self.validator.code_section_start(count, &range)?;
                    self.consume(consumed);
                    break;
                }
                Payload::DataSection(_) => break,
                Payload::End(_) => break,
                Payload::CustomSection(_) => {}
                other => {
                    if let Some(p) = self.invalid_payload(other)? {
                        return Ok(Some(p));
                    }
                }
            }
            self.consume(consumed);
        }
        // parse_buffered_code
        loop {
            let (consumed, payload) = self.next_payload()?;
            match payload {
                Payload::CodeSectionEntry(body) => {
                    self.consume(consumed);
                    self.code_entry(body)?;
                }
                _ => break,
            }
        }
        // parse_buffered_data
        loop {
            let (consumed, payload) = self.next_payload()?;
            match payload {
                Payload::DataSection(s) => self.validator.data_section(&s)?,
                Payload::End(offset) => {
                    self.validator.end(offset)?;
                    break;
                }
                Payload::CustomSection(_) => {}
                other => {
                    if let Some(p) = self.invalid_payload(other)? {
                        return Ok(Some(p));
                    }
                }
            }
            self.consume(consumed);
        }
        Ok(None)
    }

    /// `ModuleParser::process_code_entry` + `FuncTranslationDriver`.
    fn code_entry(&mut self, body: FunctionBody<'_>) -> Result<(), BinaryReaderError> {
        let bytes = body.as_bytes();
        let offset = body.get_binary_reader().original_position();
        let func = self.validator.code_section_entry(&body)?;
        let mut validator = func.into_validator(Default::default());
        let reader = BinaryReader::new_features(bytes, offset, features());
        let body = FunctionBody::new(reader);
        // translate_locals
        let mut locals = body.get_locals_reader()?;
        for _ in 0..locals.get_count() {
            let offset = locals.original_position();
            let (amount, ty) = locals.read()?;
            validator.define_locals(offset, amount, ty)?;
        }
        // translate_operators
        let mut reader = body.get_operators_reader()?;
        while !reader.eof() {
            let pos = reader.original_position();
            reader.visit_operator(&mut validator.visitor(pos))??;
        }
        reader.ensure_end()?;
        // finish
        validator.finish(reader.original_position())?;
        Ok(())
    }
}

fn validate_like_wasmi(bytes: &[u8]) -> Outcome {
    let features = features();
    let mut parser = Parser::new(0);
    parser.set_features(features);
    let mut driver = Driver {
        parser,
        validator: Validator::new_with_features(features),
        buffer: bytes,
    };
    match driver.run() {
        Ok(None) => Outcome::Ok,
        Ok(Some(p)) => Outcome::Panic(p),
        Err(e) => Outcome::Err(e),
    }
}

fn line(name: &str, bytes: &[u8]) -> String {
    let outcome = validate_like_wasmi(bytes);
    let text = match &outcome {
        Outcome::Ok => format!("{name}\tok"),
        Outcome::Err(e) => format!("{name}\terr\t{}", escape(&e.to_string())),
        Outcome::Panic(_) => format!("{name}\tpanic"),
    };
    // Cross-check with the real wasmi.
    let mut config = wasmi::Config::default();
    config.wasm_relaxed_simd(false);
    let engine = wasmi::Engine::new(&config);
    let real = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        wasmi::Module::new(&engine, bytes).map(|_| ())
    }));
    let agrees = match (&outcome, &real) {
        (Outcome::Ok, Ok(Ok(()))) => true,
        (Outcome::Err(e), Ok(Err(w))) => e.to_string() == w.to_string(),
        (Outcome::Panic(_), Err(_)) => true,
        _ => false,
    };
    if !agrees {
        let real = match real {
            Ok(Ok(())) => "ok".to_string(),
            Ok(Err(e)) => format!("err: {e}"),
            Err(_) => "panic".to_string(),
        };
        eprintln!("driver disagrees with wasmi on {name}: {text} vs {real}");
    }
    text
}

fn collect(dir: &Path, out: &mut Vec<PathBuf>) {
    let mut entries: Vec<_> = std::fs::read_dir(dir)
        .unwrap()
        .map(|e| e.unwrap().path())
        .collect();
    entries.sort();
    for path in entries {
        if path.is_dir() {
            collect(&path, out);
        } else if path.extension().map_or(false, |e| e == "wasm") {
            out.push(path);
        }
    }
}

/// Deterministic mutations of `bytes`: `cuts` truncations and `sets` byte
/// replacements.
fn mutations(bytes: &[u8], cuts: usize, sets: usize) -> Vec<(String, Vec<u8>)> {
    let mut out = Vec::new();
    let len = bytes.len();
    if len == 0 {
        return out;
    }
    let mut state: u64 = 0x2545_f491_4f6c_dd1d ^ len as u64;
    for b in bytes.iter().take(64) {
        state = state.wrapping_mul(31).wrapping_add(*b as u64) | 1;
    }
    let mut next = || {
        // xorshift64
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    for _ in 0..cuts {
        let cut = (next() % len as u64) as usize;
        out.push((format!("cut:{cut}"), bytes[..cut].to_vec()));
    }
    for _ in 0..sets {
        // Skip the header: mutations there all fail the same way.
        let pos = if len > 8 {
            8 + (next() % (len as u64 - 8)) as usize
        } else {
            (next() % len as u64) as usize
        };
        let byte = (next() & 0xff) as u8;
        let mut m = bytes.to_vec();
        m[pos] = byte;
        out.push((format!("set:{pos}:{byte}"), m));
    }
    out
}

/// Prints the line of `name` and, if it validates, of `cuts`/`sets`
/// mutations of it (keyed `<name>@<mutation>`).
fn emit(name: &str, bytes: &[u8], cuts: usize, sets: usize) {
    let base = line(name, bytes);
    let ok = base.ends_with("\tok");
    println!("{base}");
    if ok {
        for (m, mutated) in mutations(bytes, cuts, sets) {
            println!("{}", line(&format!("{name}@{m}"), &mutated));
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let corpus = Path::new(&args[1]);
    let plugins = Path::new(&args[2]);
    let mut files = Vec::new();
    collect(corpus, &mut files);
    let mut entries: Vec<(String, PathBuf)> = files
        .into_iter()
        .map(|p| {
            let rel = p.strip_prefix(corpus).unwrap().to_str().unwrap().to_string();
            (rel, p)
        })
        .collect();
    // Sort by the relative path as a string (code point order), which is
    // what the runner does.
    entries.sort_by(|a, b| a.0.cmp(&b.0));
    for (rel, path) in entries {
        let bytes = std::fs::read(&path).unwrap();
        emit(&rel, &bytes, 1, 2);
    }
    let mut plugin_files: Vec<PathBuf> = std::fs::read_dir(plugins)
        .unwrap()
        .map(|e| e.unwrap().path())
        .filter(|p| p.extension().map_or(false, |e| e == "wasm"))
        .collect();
    plugin_files.sort();
    for path in plugin_files {
        let name = format!("plugins/{}", path.file_name().unwrap().to_str().unwrap());
        let bytes = std::fs::read(&path).unwrap();
        emit(&name, &bytes, 40, 400);
    }
}
