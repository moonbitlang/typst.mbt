// Port of wasmparser 0.228.0 `src/readers/core/custom.rs`.

///|
/// A reader for custom sections of a WebAssembly module.
pub struct CustomSectionReader {
  priv name : String
  priv reader : BinaryReader
}

///|
/// Constructs a new `CustomSectionReader` for the given data and offset.
pub fn CustomSectionReader::new(
  reader : BinaryReader,
) -> CustomSectionReader raise BinaryReaderError {
  let name = reader.read_string()
  { name, reader, }
}

///|
/// The name of the custom section.
pub fn CustomSectionReader::name(self : CustomSectionReader) -> String {
  self.name
}

///|
/// The offset, relative to the start of the original module or component,
/// that the `data` payload for this custom section starts at.
pub fn CustomSectionReader::data_offset(self : CustomSectionReader) -> Int {
  self.reader.original_position()
}

///|
/// The actual contents of the custom section.
pub fn CustomSectionReader::data(self : CustomSectionReader) -> BytesView {
  self.reader.remaining_buffer()
}

///|
/// The range of bytes that specify this whole custom section (including
/// both the name of this custom section and its data) specified in
/// offsets relative to the start of the byte stream.
pub fn CustomSectionReader::range(self : CustomSectionReader) -> Range {
  self.reader.range()
}
