// Port of wasmparser 0.228.0 `src/readers/core/tags.rs`.

///|
pub impl FromReader for TagType with fn from_reader(reader) {
  let attribute = reader.read_u8()
  if attribute != 0 {
    bail(reader.original_position() - 1, "invalid tag attributes")
  }
  { kind: Exception, func_type_idx: reader.read_var_u32(), }
}
