// Port of wasmparser 0.228.0 `src/readers/core/data.rs`.

///|
/// Represents a data segment in a core WebAssembly module.
pub(all) struct Data {
  /// The kind of data segment.
  kind : DataKind
  /// The data of the data segment.
  data : BytesView
  /// The range of the data segment.
  range : Range
}

///|
/// The kind of data segment.
pub(all) enum DataKind {
  /// The data segment is passive.
  Passive
  /// The data segment is active.
  Active(memory_index~ : UInt, offset_expr~ : ConstExpr)
}

///|
pub impl FromReader for Data with fn from_reader(reader) {
  let segment_start = reader.original_position()

  // The current handling of the flags is largely specified in the `bulk-memory` proposal,
  // which at the time this comment is written has been merged to the main specification
  // draft.
  //
  // Notably, this proposal allows multiple different encodings of the memory index 0. `00`
  // and `02 00` are both valid ways to specify the 0-th memory. However it also makes
  // another encoding of the 0-th memory `80 00` no longer valid.
  //
  // We, however maintain this by parsing `flags` as a LEB128 integer. In that case, `80 00`
  // encoding is parsed out as `0` and is therefore assigned a `memidx` 0, even though the
  // current specification draft does not allow for this.
  //
  // See also https://github.com/WebAssembly/spec/issues/1439
  let flags = reader.read_var_u32()
  let kind : DataKind = match flags {
    1 => Passive
    0 | 2 => {
      let memory_index = if flags == 0 { 0U } else { reader.read_var_u32() }
      let offset_expr = ConstExpr::from_reader(reader)
      Active(memory_index~, offset_expr~)
    }
    _ =>
      raise BinaryReaderError::new(
        "invalid flags byte in data segment", segment_start,
      )
  }
  let data = reader.read_reader()
  {
    kind,
    data: data.remaining_buffer(),
    range: { start: segment_start, end: data.range().end, },
  }
}

///|
#deprecated("call as `FromReader::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with FromReader::{from_reader}
