// Port of image-webp 0.2.4 `src/vp8_arithmetic_decoder.rs`: the boolean
// entropy decoder of VP8 (RFC 6386, section 7).
//
// Upstream has a fast path (reading whole 4-byte chunks optimistically and
// committing only when no chunk past the end was used) and a cold path that
// it falls back to; both produce the same results, so only the cold path is
// ported. Reads past the end yield default values (`false`/`0`) and are
// reported by `check` as `BitStreamError`.

///|
/// A node of a decoding tree (`TreeNode`): `left`/`right` are node indices,
/// or leaf values with the `0x80` bit set.
priv struct TreeNode {
  left : Int
  right : Int
  mut prob : Int
  index : Int
}

///|
fn TreeNode::prepare_branch(t : Int) -> Int {
  if t > 0 {
    t / 2
  } else {
    0x80 | -t
  }
}

///|
fn TreeNode::value_from_branch(t : Int) -> Int {
  t & 0x7F
}

///|
/// `tree_nodes_from`.
fn tree_nodes_from(
  tree : ReadOnlyArray[Int],
  probs : ArrayView[Int],
) -> FixedArray[TreeNode] {
  FixedArray::makei(probs.length(), i => {
    left: TreeNode::prepare_branch(tree[2 * i]),
    right: TreeNode::prepare_branch(tree[2 * i + 1]),
    prob: probs[i],
    index: i,
  })
}

///|
priv struct ArithmeticDecoder {
  /// The data as big-endian 32-bit chunks.
  mut chunks : FixedArray[UInt]
  mut chunk_index : Int
  mut value : UInt64
  mut range : UInt
  mut bit_count : Int
  final_bytes : FixedArray[Int]
  mut final_bytes_remaining : Int
}

///|
let final_bytes_remaining_eof : Int = -0xE

///|
fn ArithmeticDecoder::new() -> ArithmeticDecoder {
  {
    chunks: [],
    chunk_index: 0,
    value: 0,
    range: 255,
    bit_count: -8,
    final_bytes: FixedArray::make(3, 0),
    final_bytes_remaining: final_bytes_remaining_eof,
  }
}

///|
/// `init` with the `len` bytes of `data` (upstream passes them padded to
/// 4-byte chunks).
fn ArithmeticDecoder::init(
  self : ArithmeticDecoder,
  data : BytesView,
) -> Unit raise ImageError {
  let len = data.length()
  let n_chunks = (len + 3) / 4
  let full = len / 4
  let final_bytes_remaining = if len == 4 * n_chunks {
    0
  } else {
    // `buf.pop()` of the last (partial) chunk; `buf` is never empty here.
    if n_chunks == 0 {
      raise ImageError("Not enough VP8 init data")
    }
    let popped = len - 4 * full
    for i in 0..<3 {
      self.final_bytes[i] = if i < popped {
        data[4 * full + i].to_int()
      } else {
        0
      }
    }
    popped
  }
  if final_bytes_remaining == 0 {
    for i in 0..<3 {
      self.final_bytes[i] = 0
    }
  }
  self.chunks = FixedArray::makei(full, i => {
    (data[4 * i].to_uint() << 24) |
    (data[4 * i + 1].to_uint() << 16) |
    (data[4 * i + 2].to_uint() << 8) |
    data[4 * i + 3].to_uint()
  })
  self.chunk_index = 0
  self.value = 0
  self.range = 255
  self.bit_count = -8
  self.final_bytes_remaining = final_bytes_remaining
}

///|
fn ArithmeticDecoder::is_past_eof(self : ArithmeticDecoder) -> Bool {
  self.final_bytes_remaining == final_bytes_remaining_eof
}

///|
/// `check`: whether the reads since the last check stayed within the data.
fn ArithmeticDecoder::check(self : ArithmeticDecoder) -> Unit raise ImageError {
  if self.is_past_eof() {
    raise ImageError("Corrupt bitstream")
  }
}

///|
fn ArithmeticDecoder::load_from_final_bytes(self : ArithmeticDecoder) -> Unit {
  if self.final_bytes_remaining >= 1 {
    self.final_bytes_remaining -= 1
    let byte = self.final_bytes[0]
    self.final_bytes[0] = self.final_bytes[1]
    self.final_bytes[1] = self.final_bytes[2]
    self.final_bytes[2] = byte
    self.value = (self.value << 8) | byte.to_uint64()
    self.bit_count += 8
  } else if self.final_bytes_remaining == 0 {
    self.final_bytes_remaining -= 1
    self.value = self.value << 8
    self.bit_count += 8
  } else {
    self.final_bytes_remaining = final_bytes_remaining_eof
  }
}

///|
/// `cold_read_bit`.
fn ArithmeticDecoder::read_bit(
  self : ArithmeticDecoder,
  probability : Int,
) -> Bool {
  if self.bit_count < 0 {
    if self.chunk_index < self.chunks.length() {
      let v = self.chunks[self.chunk_index]
      self.chunk_index += 1
      self.value = (self.value << 32) | v.to_uint64()
      self.bit_count += 32
    } else {
      self.load_from_final_bytes()
      if self.is_past_eof() {
        return false
      }
    }
  }
  let probability = probability.reinterpret_as_uint()
  let split = 1U + (((self.range - 1) * probability) >> 8)
  let bigsplit = split.to_uint64() << self.bit_count
  let retval = if self.value >= bigsplit {
    self.range -= split
    self.value = self.value - bigsplit
    true
  } else {
    self.range = split
    false
  }
  let lz = self.range.clz()
  let shift = if lz > 24 { lz - 24 } else { 0 }
  self.range = self.range << shift
  self.bit_count -= shift
  retval
}

///|
fn ArithmeticDecoder::read_bool(
  self : ArithmeticDecoder,
  probability : Int,
) -> Bool {
  self.read_bit(probability)
}

///|
fn ArithmeticDecoder::read_flag(self : ArithmeticDecoder) -> Bool {
  self.read_bit(128)
}

///|
fn ArithmeticDecoder::read_literal(self : ArithmeticDecoder, n : Int) -> Int {
  let mut v = 0
  for _ in 0..<n {
    let b = self.read_flag()
    v = ((v << 1) + (if b { 1 } else { 0 })) & 0xFF
  }
  v
}

///|
fn ArithmeticDecoder::read_optional_signed_value(
  self : ArithmeticDecoder,
  n : Int,
) -> Int {
  let flag = self.read_flag()
  if !flag {
    return 0
  }
  let magnitude = self.read_literal(n)
  let sign = self.read_flag()
  if sign {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn ArithmeticDecoder::read_with_tree(
  self : ArithmeticDecoder,
  tree : FixedArray[TreeNode],
) -> Int {
  self.read_with_tree_with_first_node(tree, tree[0])
}

///|
fn ArithmeticDecoder::read_with_tree_with_first_node(
  self : ArithmeticDecoder,
  tree : FixedArray[TreeNode],
  first_node : TreeNode,
) -> Int {
  let mut index = first_node.index
  while true {
    let node = tree[index]
    let b = self.read_bit(node.prob)
    let t = if b { node.right } else { node.left }
    if t < tree.length() {
      index = t
    } else {
      return TreeNode::value_from_branch(t)
    }
  }
  0
}
