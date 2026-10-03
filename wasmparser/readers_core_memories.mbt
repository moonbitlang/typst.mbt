// Port of wasmparser 0.228.0 `src/readers/core/memories.rs`.

///|
pub impl FromReader for MemoryType with fn from_reader(reader) {
  let pos = reader.original_position()
  let flags = reader.read_u8()
  if (flags & 0b11110000) != 0 {
    bail(pos, "invalid memory limits flags")
  }
  let memory64 = (flags & 0b0100) != 0
  let shared = (flags & 0b0010) != 0
  let has_max = (flags & 0b0001) != 0
  let has_page_size = (flags & 0b1000) != 0
  let initial = if memory64 {
    reader.read_var_u64()
  } else {
    reader.read_var_u32().to_uint64()
  }
  let maximum = if !has_max {
    None
  } else if memory64 {
    Some(reader.read_var_u64())
  } else {
    Some(reader.read_var_u32().to_uint64())
  }
  let page_size_log2 = if has_page_size {
    Some(reader.read_var_u32())
  } else {
    None
  }
  { memory64, shared, initial, maximum, page_size_log2, }
}
