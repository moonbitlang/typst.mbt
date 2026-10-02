// Port of `hayro-cmap/src/bcmap/huffman.rs`.

///|
priv enum HuffmanNode {
  /// Intermediate node with optional children (indices of the zero- and
  /// one-child).
  Intermediate(Int?, Int?)
  /// Leaf node holding a decoded symbol value.
  Leaf(UInt)
}

///|
/// A Huffman table built from canonical codes.
struct HuffmanTable {
  nodes : Array[HuffmanNode]
}

///|
/// Decode a single symbol from the bit reader.
fn HuffmanTable::decode(self : HuffmanTable, reader : BReader) -> UInt? {
  let mut idx = 0
  while true {
    match self.nodes[idx] {
      Intermediate(zero, one) => {
        guard reader.read_bit() is Some(bit) else { return None }
        let child = if bit == 0 { zero } else { one }
        guard child is Some(c) else { return None }
        idx = c
      }
      Leaf(symbol) => return Some(symbol)
    }
  }
  None
}

///|
fn insert_code(
  nodes : Array[HuffmanNode],
  node_index : Int,
  code : UInt,
  length : Int,
  symbol : UInt,
) -> Unit {
  if length == 0 {
    nodes[node_index] = Leaf(symbol)
    return
  }
  let shift = (length - 1) & 31
  let bit = (code >> shift) & 1
  let remaining = code & ((1U << shift) - 1)
  let child_index = match nodes[node_index] {
    Intermediate(zero, one) => {
      let existing = if bit == 0 { zero } else { one }
      match existing {
        Some(idx) => idx
        None => {
          let new_idx = nodes.length()
          nodes.push(Intermediate(None, None))
          nodes[node_index] = if bit == 0 {
            Intermediate(Some(new_idx), one)
          } else {
            Intermediate(zero, Some(new_idx))
          }
          new_idx
        }
      }
    }
    _ => return
  }
  insert_code(nodes, child_index, remaining, length - 1, symbol)
}

///|
fn HuffmanTable::build(
  code_lengths : Array[Int],
  symbols : Array[UInt],
) -> HuffmanTable {
  if symbols.length() == 0 {
    return { nodes: [Intermediate(None, None)], }
  }
  let mut max_length = 0
  for cl in code_lengths {
    if cl > max_length {
      max_length = cl
    }
  }
  let codes = Array::make(symbols.length(), 0U)
  let mut code = 0U
  for length in 1..<=max_length {
    for i, cl in code_lengths {
      if cl == length {
        codes[i] = code
        code += 1
      }
    }
    code = code << 1
  }
  let nodes = [Intermediate(None, None)]
  for i, symbol in symbols {
    if code_lengths[i] == 0 {
      continue
    }
    insert_code(nodes, 0, codes[i], code_lengths[i], symbol)
  }
  { nodes, }
}

///|
fn decode_tables(data : BytesView) -> (HuffmanTable, HuffmanTable)? {
  let reader = BReader::new(data)
  guard decode_single_table(reader, r => r.read_u32()) is Some(delta) else {
    return None
  }
  guard decode_single_table(reader, r => {
      r.read_u8().map(v => v.reinterpret_as_uint())
    })
    is Some(count) else {
    return None
  }
  Some((delta, count))
}

///|
fn decode_single_table(
  reader : BReader,
  read_sym : (BReader) -> UInt?,
) -> HuffmanTable? {
  guard reader.read_u16() is Some(n_symbols) else { return None }
  if n_symbols == 0 {
    guard reader.read_u8() is Some(_max_len) else { return None }
    return Some({ nodes: [Intermediate(None, None)], })
  }
  guard reader.read_u8() is Some(max_code_length) else { return None }
  let counts = []
  for _ in 0..<max_code_length {
    guard reader.read_u16() is Some(c) else { return None }
    counts.push(c)
  }
  let code_lengths = []
  let symbols = []
  for length_idx, count in counts {
    let code_len = (length_idx + 1) & 0xFF
    for _ in 0..<count {
      guard read_sym(reader) is Some(sym) else { return None }
      symbols.push(sym)
      code_lengths.push(code_len)
    }
  }
  Some(HuffmanTable::build(code_lengths, symbols))
}
