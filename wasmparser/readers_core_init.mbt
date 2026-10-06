// Port of wasmparser 0.228.0 `src/readers/core/init.rs`.

///|
/// Represents an initialization expression.
pub struct ConstExpr {
  priv reader : BinaryReader
}

///|
pub impl Eq for ConstExpr with fn equal(self, other) {
  self.reader.remaining_buffer() == other.reader.remaining_buffer()
}

///|
/// Constructs a new `ConstExpr` from the given data and offset.
pub fn ConstExpr::new(reader : BinaryReader) -> ConstExpr {
  { reader, }
}

///|
/// Gets a binary reader for the initialization expression.
pub fn ConstExpr::get_binary_reader(self : ConstExpr) -> BinaryReader {
  self.reader.clone()
}

///|
/// Gets an operators reader for the initialization expression.
pub fn ConstExpr::get_operators_reader(self : ConstExpr) -> OperatorsReader {
  OperatorsReader::new(self.get_binary_reader())
}

///|
pub impl FromReader for ConstExpr with fn from_reader(reader) {
  // FIXME(#188) ideally shouldn't need to skip here
  let reader = reader.skip(r => r.skip_const_expr())
  { reader, }
}

///|
pub extend ConstExpr with FromReader::{from_reader}
