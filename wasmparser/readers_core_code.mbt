// Port of wasmparser 0.228.0 `src/readers/core/code.rs`.

///|
/// Represents a WebAssembly function body.
pub struct FunctionBody {
  priv reader : BinaryReader
}

///|
/// Constructs a new `FunctionBody` for the given data and offset.
pub fn FunctionBody::new(reader : BinaryReader) -> FunctionBody {
  { reader, }
}

///|
/// Gets a binary reader for this function body.
pub fn FunctionBody::get_binary_reader(self : FunctionBody) -> BinaryReader {
  self.reader.clone()
}

///|
fn FunctionBody::skip_locals(
  reader : BinaryReader,
) -> Unit raise BinaryReaderError {
  let count = reader.read_var_u32()
  for _ in 0U..<count {
    reader.read_var_u32() |> ignore
    ValType::from_reader(reader) |> ignore
  }
}

///|
/// Gets the locals reader for this function body.
pub fn FunctionBody::get_locals_reader(
  self : FunctionBody,
) -> LocalsReader raise BinaryReaderError {
  let reader = self.reader.clone()
  let count = reader.read_var_u32()
  { reader, count, }
}

///|
/// Gets the operators reader for this function body, after skipping all
/// locals.
pub fn FunctionBody::get_operators_reader(
  self : FunctionBody,
) -> OperatorsReader raise BinaryReaderError {
  let reader = self.reader.clone()
  FunctionBody::skip_locals(reader)
  OperatorsReader::new(reader)
}

///|
/// Gets the range of the function body.
pub fn FunctionBody::range(self : FunctionBody) -> Range {
  self.reader.range()
}

///|
/// Returns the body of this function as a list of bytes.
///
/// Note that the returned bytes start with the function locals declaration.
pub fn FunctionBody::as_bytes(self : FunctionBody) -> BytesView {
  self.reader.remaining_buffer()
}

///|
pub impl FromReader for FunctionBody with fn from_reader(reader) {
  let reader = reader.read_reader()
  { reader, }
}

///|
#deprecated("call as `FromReader::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FunctionBody with FromReader::{from_reader}

///|
/// A reader for a function body's locals.
pub struct LocalsReader {
  priv reader : BinaryReader
  priv count : UInt
}

///|
/// Gets the count of locals in the function body.
pub fn LocalsReader::get_count(self : LocalsReader) -> UInt {
  self.count
}

///|
/// Gets the original position of the reader.
pub fn LocalsReader::original_position(self : LocalsReader) -> Int {
  self.reader.original_position()
}

///|
/// Reads an item from the reader.
pub fn LocalsReader::read(
  self : LocalsReader,
) -> (UInt, ValType) raise BinaryReaderError {
  let count = self.reader.read_var_u32()
  let value_type = ValType::from_reader(self.reader)
  (count, value_type)
}
