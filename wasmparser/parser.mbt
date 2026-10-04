// Port of wasmparser 0.228.0 `src/parser.rs` (without the `component-model`
// cargo feature: component sections are reported as `UnknownSection`).

///|
let wasm_module_version : UInt = 0x1

///|
// Note that this started at `0xa` and we're incrementing up from there. When
// the component model is stabilized this will become 0x1. The changes here are:
//
// * [????-??-??] 0xa - original version
// * [2023-01-05] 0xb - `export` introduces an alias
// * [2023-02-06] 0xc - `export` has an optional type ascribed to it
// * [2023-05-10] 0xd - imports/exports drop URLs, new discriminator byte which
//                      allows for `(import (interface "...") ...)` syntax.
let wasm_component_version : UInt = 0xd

///|
let kind_module : UInt = 0x00

///|
let kind_component : UInt = 0x01

///|
/// The supported encoding formats for the parser.
pub(all) enum Encoding {
  /// The encoding format is a WebAssembly module.
  Module
  /// The encoding format is a WebAssembly component.
  Component
} derive(Eq, Debug)

///|
/// An incremental parser of a binary WebAssembly module or component.
///
/// This type is intended to be used to incrementally parse a WebAssembly module
/// or component as bytes become available for the module. This can also be used
/// to parse modules or components that are already entirely resident within memory.
///
/// This primary function for a parser is the [`Parser::parse`] function which
/// will incrementally consume input. You can also use the [`Parser::parse_all`]
/// function to parse a module or component that is entirely resident in memory.
pub struct Parser {
  priv mut state : ParserState
  priv mut offset : Int64
  priv mut max_size : UInt64
  priv mut encoding : Encoding
  priv mut features : WasmFeatures
}

///|
priv enum ParserState {
  Header
  SectionStart
  FunctionBody(remaining~ : UInt, len~ : UInt)
}

///|
/// A successful return payload from [`Parser::parse`].
///
/// On success one of two possible values can be returned, either that more data
/// is needed to continue parsing or a chunk of the input was parsed, indicating
/// how much of it was parsed.
pub(all) enum Chunk {
  /// This can be returned at any time and indicates that more data is needed
  /// to proceed with parsing. Zero bytes were consumed from the input to
  /// [`Parser::parse`]. The `u64` value here is a hint as to how many more
  /// bytes are needed to continue parsing.
  NeedMoreData(UInt64)
  /// A chunk was successfully parsed.
  Parsed(consumed~ : Int, payload~ : Payload)
}

///|
/// Values that can be parsed from a WebAssembly module or component.
///
/// This enumeration is all possible chunks of pieces that can be parsed by a
/// [`Parser`] from a binary WebAssembly module or component. Note that for many
/// sections the entire section is parsed all at once, whereas other functions,
/// like the code section, are parsed incrementally. This is a distinction where some
/// sections, like the type section, are required to be fully resident in memory
/// (fully downloaded) before proceeding. Other sections, like the code section,
/// can be processed in a streaming fashion where each function is extracted
/// individually so it can possibly be shipped to another thread while you wait
/// for more functions to get downloaded.
///
/// Note that payloads, when returned, do not indicate that the module or component
/// is valid. For example when you receive a `Payload::TypeSection` the type
/// section itself has not yet actually been parsed. The reader returned will be
/// able to parse it, but you'll have to actually iterate the reader to do the
/// full parse. Each payload returned is intended to be a *window* into the
/// original `data` passed to [`Parser::parse`] which can be further processed
/// if necessary.
pub(all) enum Payload {
  /// Indicates the header of a WebAssembly module or component.
  Version(num~ : UInt, encoding~ : Encoding, range~ : Range)
  /// A module type section was received and the provided reader can be
  /// used to parse the contents of the type section.
  TypeSection(SectionLimited[RecGroup])
  /// A module import section was received and the provided reader can be
  /// used to parse the contents of the import section.
  ImportSection(SectionLimited[Import])
  /// A module function section was received and the provided reader can be
  /// used to parse the contents of the function section.
  FunctionSection(SectionLimited[UInt])
  /// A module table section was received and the provided reader can be
  /// used to parse the contents of the table section.
  TableSection(SectionLimited[Table])
  /// A module memory section was received and the provided reader can be
  /// used to parse the contents of the memory section.
  MemorySection(SectionLimited[MemoryType])
  /// A module tag section was received, and the provided reader can be
  /// used to parse the contents of the tag section.
  TagSection(SectionLimited[TagType])
  /// A module global section was received and the provided reader can be
  /// used to parse the contents of the global section.
  GlobalSection(SectionLimited[Global])
  /// A module export section was received, and the provided reader can be
  /// used to parse the contents of the export section.
  ExportSection(SectionLimited[Export])
  /// A module start section was received.
  StartSection(func~ : UInt, range~ : Range)
  /// A module element section was received and the provided reader can be
  /// used to parse the contents of the element section.
  ElementSection(SectionLimited[Element])
  /// A module data count section was received.
  DataCountSection(count~ : UInt, range~ : Range)
  /// A module data section was received and the provided reader can be
  /// used to parse the contents of the data section.
  DataSection(SectionLimited[Data])
  /// Indicator of the start of the code section of a WebAssembly module.
  ///
  /// This entry is returned whenever the code section starts. The `count`
  /// field indicates how many entries are in this code section. After
  /// receiving this start marker you're guaranteed that the next `count`
  /// items will be either `CodeSectionEntry` or an error will be returned.
  ///
  /// This, unlike other sections, is intended to be used for streaming the
  /// contents of the code section. The code section is not required to be
  /// fully resident in memory when we parse it. Instead a [`Parser`] is
  /// capable of parsing piece-by-piece of a code section.
  CodeSectionStart(count~ : UInt, range~ : Range, size~ : UInt)
  /// An entry of the code section, a function, was parsed from a WebAssembly
  /// module.
  ///
  /// This entry indicates that a function was successfully received from the
  /// code section, and the payload here is the window into the original input
  /// where the function resides. Note that the function itself has not been
  /// parsed, it's only been outlined. You'll need to process the
  /// `FunctionBody` provided to test whether it parses and/or is valid.
  CodeSectionEntry(FunctionBody)
  /// A module or component custom section was received.
  CustomSection(CustomSectionReader)
  /// An unknown section was found.
  ///
  /// This variant is returned for all unknown sections encountered. This
  /// likely wants to be interpreted as an error by consumers of the parser,
  /// but this can also be used to parse sections currently unsupported by
  /// the parser.
  UnknownSection(id~ : Byte, contents~ : BytesView, range~ : Range)
  /// The end of the WebAssembly module or component was reached.
  ///
  /// The value is the offset in the input byte stream where the end
  /// was reached.
  End(Int)
}

///|
let custom_section : Byte = 0

///|
let type_section : Byte = 1

///|
let import_section : Byte = 2

///|
let function_section : Byte = 3

///|
let table_section : Byte = 4

///|
let memory_section : Byte = 5

///|
let global_section : Byte = 6

///|
let export_section : Byte = 7

///|
let start_section : Byte = 8

///|
let element_section : Byte = 9

///|
let code_section : Byte = 10

///|
let data_section : Byte = 11

///|
let data_count_section : Byte = 12

///|
let tag_section : Byte = 13

///|
/// Creates a new parser.
///
/// Reports errors and ranges relative to `offset` provided, where `offset`
/// is some logical offset within the input stream that we're parsing.
pub fn Parser::new(offset : Int64) -> Parser {
  {
    state: Header,
    offset,
    max_size: 0xFFFF_FFFF_FFFF_FFFFUL,
    // Assume the encoding is a module until we know otherwise
    encoding: Module,
    features: WasmFeatures::all(),
  }
}

///|
/// Tests whether `bytes` looks like a core WebAssembly module.
///
/// This will inspect the first 8 bytes of `bytes` and return `true` if it
/// starts with the standard core WebAssembly header.
pub fn Parser::is_core_wasm(bytes : BytesView) -> Bool {
  bytes.has_prefix(b"\x00asm\x01\x00\x00\x00"[:])
}

///|
/// Tests whether `bytes` looks like a WebAssembly component.
///
/// This will inspect the first 8 bytes of `bytes` and return `true` if it
/// starts with the standard WebAssembly component header.
pub fn Parser::is_component(bytes : BytesView) -> Bool {
  bytes.has_prefix(b"\x00asm\x0d\x00\x01\x00"[:])
}

///|
/// Returns the currently active set of wasm features that this parser is
/// using while parsing.
///
/// The default set of features is [`WasmFeatures::all()`] for new parsers.
pub fn Parser::features(self : Parser) -> WasmFeatures {
  self.features
}

///|
/// Sets the wasm features active while parsing to the `features` specified.
///
/// The default set of features is [`WasmFeatures::all()`] for new parsers.
pub fn Parser::set_features(self : Parser, features : WasmFeatures) -> Unit {
  self.features = features
}

///|
/// Returns the original offset that this parser is currently at.
pub fn Parser::offset(self : Parser) -> Int64 {
  self.offset
}

///|
/// Attempts to parse a chunk of data.
///
/// This method will attempt to parse the next incremental portion of a
/// WebAssembly binary. Data available for the module or component is
/// provided as `data`, and the data can be incomplete if more data has yet
/// to arrive. The `eof` flag indicates whether more data will ever be received.
///
/// There are two ways parsing can succeed with this method:
///
/// * `Chunk::NeedMoreData` - this indicates that there is not enough bytes
///   in `data` to parse a payload. The caller needs to wait for more data to
///   be available in this situation before calling this method again. It is
///   guaranteed that this is only returned if `eof` is `false`.
///
/// * `Chunk::Parsed` - this indicates that a chunk of the input was
///   successfully parsed. The payload is available in this variant of what
///   was parsed, and this also indicates how many bytes of `data` was
///   consumed. It's expected that the caller will not provide these bytes
///   back to the [`Parser`] again.
///
/// It is expected that you'll call this method until `Payload::End` is
/// reached, at which point you're guaranteed that the parse has completed.
/// Note that complete parsing, for the top-level module or component,
/// implies that `data` is empty and `eof` is `true`.
///
/// # Errors
///
/// Parse errors are returned as an `Err`. Errors can happen when the
/// structure of the data is unexpected or if sections are too large for
/// example. Note that errors are not returned for malformed *contents* of
/// sections here. Sections are generally not individually parsed and each
/// returned [`Payload`] needs to be iterated over further to detect all
/// errors.
pub fn Parser::parse(
  self : Parser,
  data : BytesView,
  eof : Bool,
) -> Chunk raise BinaryReaderError {
  let (data, eof) = if data.length().to_uint64() > self.max_size {
    (data[:self.max_size.to_int()], true)
  } else {
    (data, eof)
  }
  // TODO: thread through `offset: u64` to `BinaryReader`, remove
  // the cast here.
  let starting_offset = self.offset.to_int()
  let reader = BinaryReader::new(data, starting_offset)
  reader.set_features(self.features)
  let payload = self.parse_reader(reader, eof) catch {
    e => {
      // If we're at EOF then there's no way we can recover from any
      // error, so continue to propagate it.
      if eof {
        raise e
      }

      // If our error doesn't look like it can be resolved with more
      // data being pulled down, then propagate it, otherwise switch
      // the error to "feed me please"
      match e.needed_hint() {
        Some(hint) => return NeedMoreData(hint.to_uint64())
        None => raise e
      }
    }
  }
  // Be sure to update our offset with how far we got in the
  // reader
  let consumed = reader.original_position() - starting_offset
  self.offset += consumed.to_int64()
  self.max_size -= consumed.to_uint64()
  Parsed(consumed~, payload~)
}

///|
fn Parser::parse_reader(
  self : Parser,
  reader : BinaryReader,
  eof : Bool,
) -> Payload raise BinaryReaderError {
  match self.state {
    Header => {
      let start = reader.original_position()
      let header_version = reader.read_header_version()
      let kind = header_version >> 16
      self.encoding = if kind == kind_module {
        Module
      } else if kind == kind_component {
        Component
      } else {
        bail(
          start + 4,
          "unknown binary version: \{rust_fmt_hex_width(header_version, 10)}",
        )
      }
      let num = header_version & 0xFFFF
      self.state = SectionStart
      Version(num~, encoding=self.encoding, range={
        start,
        end: reader.original_position(),
      })
    }
    SectionStart => {
      // If we're at eof and there are no bytes in our buffer, then
      // that means we reached the end of the data since it's
      // just a bunch of sections concatenated after the header.
      if eof && reader.bytes_remaining() == 0 {
        return End(reader.original_position())
      }
      let id_pos = reader.original_position()
      let id = reader.read_u8()
      if (id & 0x80) != 0 {
        raise BinaryReaderError::new("malformed section id", id_pos)
      }
      let len_pos = reader.original_position()
      let len = reader.read_var_u32()

      // Test to make sure that this section actually fits within
      // `Parser::max_size`. This doesn't matter for top-level modules
      // but it is required for nested modules/components to correctly ensure
      // that all sections live entirely within their section of the
      // file.
      let consumed = (reader.original_position() - id_pos).to_uint64()
      let section_overflow = consumed > self.max_size ||
        len.to_uint64() > self.max_size - consumed
      if section_overflow {
        raise BinaryReaderError::new("section too large", len_pos)
      }
      match (self.encoding, id) {
        // Sections for both modules and components.
        (_, 0) => CustomSection(section(reader, len, CustomSectionReader::new))

        // Module sections
        (Module, 1) => TypeSection(section(reader, len, SectionLimited::new))
        (Module, 2) => ImportSection(section(reader, len, SectionLimited::new))
        (Module, 3) =>
          FunctionSection(section(reader, len, SectionLimited::new))
        (Module, 4) => TableSection(section(reader, len, SectionLimited::new))
        (Module, 5) => MemorySection(section(reader, len, SectionLimited::new))
        (Module, 6) => GlobalSection(section(reader, len, SectionLimited::new))
        (Module, 7) => ExportSection(section(reader, len, SectionLimited::new))
        (Module, 8) => {
          let (func, range) = single_item(reader, len, "start")
          StartSection(func~, range~)
        }
        (Module, 9) => ElementSection(section(reader, len, SectionLimited::new))
        (Module, 10) => {
          let start = reader.original_position()
          let len : Ref[UInt] = { val: len, }
          let count = delimited(reader, len, r => r.read_var_u32())
          let range = {
            start,
            end: reader.original_position() + len.val.reinterpret_as_int(),
          }
          self.state = FunctionBody(remaining=count, len=len.val)
          CodeSectionStart(count~, range~, size=len.val)
        }
        (Module, 11) => DataSection(section(reader, len, SectionLimited::new))
        (Module, 12) => {
          let (count, range) = single_item(reader, len, "data count")
          DataCountSection(count~, range~)
        }
        (Module, 13) => TagSection(section(reader, len, SectionLimited::new))
        (_, id) => {
          let offset = reader.original_position()
          let contents = reader.read_bytes_u32(len)
          let range = { start: offset, end: offset + len.reinterpret_as_int(), }
          UnknownSection(id~, contents~, range~)
        }
      }
    }

    // Once we hit 0 remaining incrementally parsed items, with 0
    // remaining bytes in each section, we're done and can switch back
    // to parsing sections.
    FunctionBody(remaining=0, len=0) => {
      self.state = SectionStart
      self.parse_reader(reader, eof)
    }

    // ... otherwise trailing bytes with no remaining entries in these
    // sections indicates an error.
    FunctionBody(remaining=0, len~) => {
      if !(len > 0) {
        abort("assertion failed: len > 0")
      }
      let offset = reader.original_position()
      raise BinaryReaderError::new("trailing bytes at end of section", offset)
    }

    // Functions are relatively easy to parse when we know there's at
    // least one remaining and at least one byte available to read
    // things.
    //
    // We use the remaining length try to read a u32 size of the
    // function, and using that size we require the entire function be
    // resident in memory. This means that we're reading whole chunks of
    // functions at a time.
    //
    // Limiting via `Parser::max_size` (nested parsing) happens above in
    // `fn parse`, and limiting by our section size happens via
    // `delimited`. Actual parsing of the function body is delegated to
    // the caller to iterate over the `FunctionBody` structure.
    FunctionBody(remaining~, len~) => {
      let len : Ref[UInt] = { val: len, }
      let body = delimited(reader, len, r => FunctionBody::new(r.read_reader()))
      self.state = FunctionBody(remaining=remaining - 1, len=len.val)
      CodeSectionEntry(body)
    }
  }
}

///|
/// Convenience function that can be used to parse a module or component
/// that is entirely resident in memory.
///
/// This function will parse the `data` provided as a WebAssembly module
/// or component, calling `f` for each payload until `End` (inclusive) or
/// the first error.
pub fn Parser::parse_all(
  self : Parser,
  data : BytesView,
  f : (Payload) -> Unit raise BinaryReaderError,
) -> Unit raise BinaryReaderError {
  let mut data = data
  while true {
    let payload = match self.parse(data, true) {
      // This isn't possible because `eof` is always true.
      NeedMoreData(_) => abort("unreachable")
      Parsed(payload~, consumed~) => {
        data = data[consumed:]
        payload
      }
    }
    let done = payload is End(_)
    f(payload)
    if done {
      break
    }
  }
}

///|
/// Skip parsing the code section entirely.
///
/// This function can be used to indicate, after receiving
/// `CodeSectionStart`, that the section will not be parsed.
///
/// The caller will be responsible for skipping `size` bytes (found in the
/// `CodeSectionStart` payload). Bytes should only be fed into `parse`
/// after the `size` bytes have been skipped.
///
/// # Panics
///
/// This function will panic if the parser is not in a state where it's
/// parsing the code section.
pub fn Parser::skip_section(self : Parser) -> Unit {
  let skip = match self.state {
    FunctionBody(len~, ..) => len
    _ => abort("wrong state to call `skip_section`")
  }
  self.offset += skip.to_int64()
  self.max_size -= skip.to_uint64()
  self.state = SectionStart
}

///|
/// Parses an entire section resident in memory into a `Payload`.
///
/// Requires that `len` bytes are resident in `reader` and uses `ctor`/`variant`
/// to construct the section to return.
fn[T] section(
  reader : BinaryReader,
  len : UInt,
  ctor : (BinaryReader) -> T raise BinaryReaderError,
) -> T raise BinaryReaderError {
  let reader = reader.skip(r => r.skip_bytes_u32(len))
  // clear the hint for "need this many more bytes" here because we already
  // read all the bytes, so it's not possible to read more bytes if this
  // fails.
  ctor(reader) catch {
    e => raise e.clear_hint()
  }
}

///|
/// Reads a section that is represented by a single uleb-encoded `u32`.
fn single_item(
  reader : BinaryReader,
  len : UInt,
  desc : String,
) -> (UInt, Range) raise BinaryReaderError {
  let range = {
    start: reader.original_position(),
    end: reader.original_position() + len.reinterpret_as_int(),
  }
  let content = reader.skip(r => r.skip_bytes_u32(len))
  // We can't recover from "unexpected eof" here because our entire section is
  // already resident in memory, so clear the hint for how many more bytes are
  // expected.
  let ret = content.read_var_u32() catch { e => raise e.clear_hint() }
  if !content.eof() {
    bail(
      content.original_position(),
      "unexpected content in the \{desc} section",
    )
  }
  (ret, range)
}

///|
/// Attempts to parse using `f`.
///
/// This will update `*len` with the number of bytes consumed, and it will cause
/// a failure to be returned instead of the number of bytes consumed exceeds
/// what `*len` currently is.
fn[T] delimited(
  reader : BinaryReader,
  len : Ref[UInt],
  f : (BinaryReader) -> T raise BinaryReaderError,
) -> T raise BinaryReaderError {
  let start = reader.original_position()
  let ret = f(reader)
  let used = (reader.original_position() - start).reinterpret_as_uint()
  if used > len.val {
    raise BinaryReaderError::new("unexpected end-of-file", start)
  }
  len.val = len.val - used
  ret
}

///|
/// If this `Payload` represents a section in the original wasm module then
/// the section's id and range within the original wasm binary are returned.
///
/// Not all payloads refer to entire sections, such as the `Version` and
/// `CodeSectionEntry` variants. These variants will return `None` from this
/// function.
///
/// Otherwise this function will return `Some` where the first element is
/// the byte identifier for the section and the second element is the range
/// of the contents of the section within the original wasm binary.
///
/// The purpose of this method is to enable tools to easily iterate over
/// entire sections if necessary and handle sections uniformly, for example
/// dropping custom sections while preserving all other sections.
pub fn Payload::as_section(self : Payload) -> (Byte, Range)? {
  match self {
    Version(..) => None
    TypeSection(s) => Some((type_section, s.range()))
    ImportSection(s) => Some((import_section, s.range()))
    FunctionSection(s) => Some((function_section, s.range()))
    TableSection(s) => Some((table_section, s.range()))
    MemorySection(s) => Some((memory_section, s.range()))
    TagSection(s) => Some((tag_section, s.range()))
    GlobalSection(s) => Some((global_section, s.range()))
    ExportSection(s) => Some((export_section, s.range()))
    ElementSection(s) => Some((element_section, s.range()))
    DataSection(s) => Some((data_section, s.range()))
    StartSection(range~, ..) => Some((start_section, range))
    DataCountSection(range~, ..) => Some((data_count_section, range))
    CodeSectionStart(range~, ..) => Some((code_section, range))
    CodeSectionEntry(_) => None
    CustomSection(c) => Some((custom_section, c.range()))
    UnknownSection(id~, range~, ..) => Some((id, range))
    End(_) => None
  }
}

///|
/// `{:#10x}`: `0x`-prefixed lowercase hex, right-aligned in `width` columns.
fn rust_fmt_hex_width(x : UInt, width : Int) -> String {
  let s = "0x" + x.to_string(radix=16)
  if s.length() >= width {
    s
  } else {
    String::make(width - s.length(), ' ') + s
  }
}
