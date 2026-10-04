// Port of the Huffman tree and bit writer parts of zlib-rs 0.6.8
// `src/deflate.rs` (zlib-ng's `trees.c`), and of `src/deflate/pending.rs` and
// `src/deflate/sym_buf.rs`.
//
// Upstream stores 16-bit values; arithmetic that wraps in upstream's release
// build is masked with 0xffff here.

///|
/// Output still pending (upstream `Pending`).
priv struct Pending {
  /// start of the allocation
  buf : FixedArray[Byte]
  /// next pending byte to output to the stream
  mut out : Int
  /// number of bytes in the pending buffer
  mut pending : Int
}

///|
fn Pending::new(len : Int) -> Pending {
  { buf: FixedArray::make(len, b'\x00'), out: 0, pending: 0, }
}

///|
/// Number of bytes that can be added to the pending buffer until it is full.
fn Pending::remaining(self : Pending) -> Int {
  self.buf.length() - (self.out + self.pending)
}

///|
/// Mark a number of pending bytes as no longer pending.
fn Pending::advance(self : Pending, number_of_bytes : Int) -> Unit {
  self.out += number_of_bytes
  self.pending -= number_of_bytes
  if self.pending == 0 {
    self.out = 0
  }
}

///|
fn Pending::push(self : Pending, byte : Byte) -> Unit {
  guard self.remaining() >= 1 else {
    abort("buf.len() must fit in remaining()")
  }
  self.buf[self.out + self.pending] = byte
  self.pending += 1
}

///|
fn Pending::extend_window(
  self : Pending,
  src : FixedArray[Byte],
  start : Int,
  len : Int,
) -> Unit {
  guard self.remaining() >= len else {
    abort("buf.len() must fit in remaining()")
  }
  src.blit_to(
    self.buf,
    len~,
    src_offset=start,
    dst_offset=self.out + self.pending,
  )
  self.pending += len
}

///|
/// The literal/length/distance symbol buffer (upstream `SymBuf`).
priv struct SymBuf {
  buf : FixedArray[Byte]
  mut filled : Int
}

///|
fn SymBuf::new(lit_bufsize : Int) -> SymBuf {
  { buf: FixedArray::make(lit_bufsize * 3, b'\x00'), filled: 0, }
}

///|
fn SymBuf::should_flush_block(self : SymBuf) -> Bool {
  self.filled == self.buf.length() - 3
}

///|
fn SymBuf::is_empty(self : SymBuf) -> Bool {
  self.filled == 0
}

///|
/// Clears the buffer, resetting the filled region to empty.
fn SymBuf::clear(self : SymBuf) -> Unit {
  self.buf.fill(b'\x00')
  self.filled = 0
}

///|
fn SymBuf::push_lit(self : SymBuf, byte : Int) -> Unit {
  // NOTE: we rely on the buffer being zeroed here!
  self.buf[self.filled + 2] = byte.to_byte()
  self.filled += 3
}

///|
fn SymBuf::push_dist(self : SymBuf, dist : Int, len : Int) -> Unit {
  self.buf[self.filled] = (dist & 0xff).to_byte()
  self.buf[self.filled + 1] = ((dist >> 8) & 0xff).to_byte()
  self.buf[self.filled + 2] = (len & 0xff).to_byte()
  self.filled += 3
}

///|
priv struct BitWriter {
  /// output still pending
  pending : Pending
  /// Output buffer. bits are inserted starting at the bottom (least
  /// significant bits).
  mut bit_buffer : UInt64
  /// Number of valid bits in bit_buffer. All bits above the last valid bit
  /// are always zero.
  mut bits_valid : Int
  // (`bits_used` is only read by `deflatePending`, not ported)
}

///|
const BIT_BUF_SIZE : Int = 64

///|
fn BitWriter::push_le_bytes(self : BitWriter, v : UInt64, n : Int) -> Unit {
  let pending = self.pending
  guard n >= 0 && n <= 8 && pending.remaining() >= n else {
    abort("buf.len() must fit in remaining()")
  }
  // `remaining() >= n`: `buf[at..at + n]` is in bounds (`out` and `pending`
  // are never negative).
  let buf = pending.buf
  let at = pending.out + pending.pending
  for i in 0..<n {
    buf.unsafe_set(at + i, (v >> (8 * i)).to_byte())
  }
  pending.pending += n
}

///|
fn BitWriter::flush_bits(self : BitWriter) -> Unit {
  let removed = (@cmp.maximum(self.bits_valid - 7, 0) + 7) / 8 * 8
  let keep_bytes = self.bits_valid / 8 // can never divide by zero
  self.push_le_bytes(self.bit_buffer, keep_bytes)
  self.bits_valid -= removed
  self.bit_buffer = if removed >= 64 { 0 } else { self.bit_buffer >> removed }
}

///|
fn BitWriter::emit_align(self : BitWriter) -> Unit {
  let keep_bytes = (self.bits_valid + 7) / 8
  self.push_le_bytes(self.bit_buffer, keep_bytes)
  self.bit_buffer = 0
  self.bits_valid = 0
}

///|
fn BitWriter::send_bits(self : BitWriter, val : UInt64, len : Int) -> Unit {
  let total_bits = len + self.bits_valid
  if total_bits < BIT_BUF_SIZE {
    self.bit_buffer = self.bit_buffer | (val << self.bits_valid)
    self.bits_valid = total_bits
  } else {
    self.send_bits_overflow(val, total_bits)
  }
}

///|
fn BitWriter::send_bits_overflow(
  self : BitWriter,
  val : UInt64,
  total_bits : Int,
) -> Unit {
  if self.bits_valid == BIT_BUF_SIZE {
    self.push_le_bytes(self.bit_buffer, 8)
    self.bit_buffer = val
    self.bits_valid = total_bits - BIT_BUF_SIZE
  } else {
    self.bit_buffer = self.bit_buffer | (val << self.bits_valid)
    self.push_le_bytes(self.bit_buffer, 8)
    self.bit_buffer = val >> (BIT_BUF_SIZE - self.bits_valid)
    self.bits_valid = total_bits - BIT_BUF_SIZE
  }
}

///|
fn BitWriter::send_code(
  self : BitWriter,
  code : Int,
  codes : FixedArray[Int],
  lens : FixedArray[Int],
) -> Unit {
  self.send_bits(codes[code].to_uint64(), lens[code])
}

///|
/// Send one empty static block to give enough lookahead for inflate.
/// This takes 10 bits, of which 7 may remain in the bit buffer.
fn BitWriter::align(self : BitWriter) -> Unit {
  self.emit_tree(BLOCK_STATIC_TREES, false)
  self.emit_end_block(static_ltree.0, static_ltree.1)
  self.flush_bits()
}

///|
const BLOCK_STORED : Int = 0

///|
const BLOCK_STATIC_TREES : Int = 1

///|
const BLOCK_DYNAMIC_TREES : Int = 2

///|
fn BitWriter::emit_tree(
  self : BitWriter,
  block_type : Int,
  is_last_block : Bool,
) -> Unit {
  let header_bits = (block_type << 1) | (if is_last_block { 1 } else { 0 })
  self.send_bits(header_bits.to_uint64(), 3)
}

///|
const END_BLOCK : Int = 256

///|
fn BitWriter::emit_end_block(
  self : BitWriter,
  lcodes : FixedArray[Int],
  llens : FixedArray[Int],
) -> Unit {
  self.send_code(END_BLOCK, lcodes, llens)
}

///|
/// Bits and their count (upstream returns `(u64, usize)` tuples, which would
/// be allocated here).
#valtype
priv struct EncodedBits {
  bits : UInt64
  len : Int
}

///|
/// Upstream `encode_len`: the length code and extra bits of a match length
/// (`lc` is a byte; the caller checks the table sizes, see
/// [DeflateStream::compress_block_help]).
#inline
fn encode_len(
  lcodes : FixedArray[Int],
  llens : FixedArray[Int],
  lc : Int,
) -> EncodedBits {
  let mut lc = lc
  // Send the length code, len is the match length - STD_MIN_MATCH
  let code = length_code.unsafe_get(lc)
  let c = code + LITERALS + 1
  let mut match_bits = u64_of_int(lcodes.unsafe_get(c))
  let mut match_bits_len = llens.unsafe_get(c)
  let extra = extra_lbits.unsafe_get(code)
  if extra != 0 {
    lc -= base_length.unsafe_get(code)
    match_bits = match_bits | (u64_of_int(lc) << match_bits_len)
    match_bits_len += extra
  }
  { bits: match_bits, len: match_bits_len, }
}

///|
/// Upstream `encode_dist` (`dist` is in `1..=32768`; the caller checks the
/// table sizes, see [DeflateStream::compress_block_help]).
#inline
fn encode_dist(
  dcodes : FixedArray[Int],
  dlens : FixedArray[Int],
  dist : Int,
) -> EncodedBits {
  let mut dist = dist - 1 // dist is now the match distance - 1
  let code = dist_code.unsafe_get(
    if dist < 256 {
      dist
    } else {
      256 + (dist >> 7)
    },
  )
  // Send the distance code
  let mut match_bits = u64_of_int(dcodes.unsafe_get(code))
  let mut match_bits_len = dlens.unsafe_get(code)
  let extra = extra_dbits.unsafe_get(code)
  if extra != 0 {
    dist -= base_dist.unsafe_get(code)
    match_bits = match_bits | (u64_of_int(dist) << match_bits_len)
    match_bits_len += extra
  }
  { bits: match_bits, len: match_bits_len, }
}

///|
/// `x as u64` for a non-negative `x` (intrinsic conversions only).
#inline
fn u64_of_int(x : Int) -> UInt64 {
  UInt64::extend_uint(x.reinterpret_as_uint())
}

///|
fn d_code(dist : Int) -> Int {
  let index = if dist < 256 { dist } else { 256 + (dist >> 7) }
  dist_code[index]
}

///|
/// Repeat previous bit length 3-6 times (2 bits of repeat count).
const REP_3_6 : Int = 16

///|
/// Repeat a zero length 3-10 times (3 bits of repeat count).
const REPZ_3_10 : Int = 17

///|
/// Repeat a zero length 11-138 times (7 bits of repeat count).
const REPZ_11_138 : Int = 18

///|
fn BitWriter::send_tree(
  self : BitWriter,
  tree : TreeDesc,
  bl_tree : TreeDesc,
  max_code : Int,
) -> Unit {
  let mut prevlen = -1 // last emitted length
  let mut nextlen = tree.b[0] // length of next code
  let mut count = 0 // repeat count of the current code
  let mut max_count = 7 // max repeat count
  let mut min_count = 4 // min repeat count
  if nextlen == 0 {
    max_count = 138
    min_count = 3
  }
  for n in 0..<=max_code {
    let curlen = nextlen
    nextlen = tree.b[n + 1]
    count += 1
    if count < max_count && curlen == nextlen {
      continue
    } else if count < min_count {
      while true {
        self.send_code(curlen, bl_tree.a, bl_tree.b)
        count -= 1
        if count == 0 {
          break
        }
      }
    } else if curlen != 0 {
      if curlen != prevlen {
        self.send_code(curlen, bl_tree.a, bl_tree.b)
        count -= 1
      }
      self.send_code(REP_3_6, bl_tree.a, bl_tree.b)
      self.send_bits((count - 3).to_uint64(), 2)
    } else if count <= 10 {
      self.send_code(REPZ_3_10, bl_tree.a, bl_tree.b)
      self.send_bits((count - 3).to_uint64(), 3)
    } else {
      self.send_code(REPZ_11_138, bl_tree.a, bl_tree.b)
      self.send_bits((count - 11).to_uint64(), 7)
    }
    count = 0
    prevlen = curlen
    if nextlen == 0 {
      max_count = 138
      min_count = 3
    } else if curlen == nextlen {
      max_count = 6
      min_count = 3
    } else {
      max_count = 7
      min_count = 4
    }
  }
}

///|
/// Static parameters of a tree (upstream `StaticTreeDesc`).
priv struct StaticTreeDesc {
  /// static tree (lengths) or None
  static_lens : FixedArray[Int]?
  /// extra bits for each code
  extra_bits : ReadOnlyArray[Int]
  /// base index for extra_bits
  extra_base : Int
  /// max number of elements in the tree
  elems : Int
  /// max bit length for the codes
  max_length : Int
}

///|
let static_l_desc : StaticTreeDesc = {
  static_lens: Some(static_ltree.1),
  extra_bits: extra_lbits,
  extra_base: LITERALS + 1,
  elems: L_CODES,
  max_length: MAX_BITS,
}

///|
let static_d_desc : StaticTreeDesc = {
  static_lens: Some(static_dtree.1),
  extra_bits: extra_dbits,
  extra_base: 0,
  elems: D_CODES,
  max_length: MAX_BITS,
}

///|
let static_bl_desc : StaticTreeDesc = {
  static_lens: None,
  extra_bits: extra_blbits,
  extra_base: 0,
  elems: BL_CODES,
  max_length: MAX_BL_BITS,
}

///|
/// A dynamic tree (upstream `TreeDesc`). Upstream's `Value` holds two `u16`s:
/// `a` is the frequency or the code, `b` the dad or the length.
priv struct TreeDesc {
  a : FixedArray[Int]
  b : FixedArray[Int]
  mut max_code : Int
  stat_desc : StaticTreeDesc
}

///|
fn TreeDesc::new(n : Int, stat_desc : StaticTreeDesc) -> TreeDesc {
  {
    a: FixedArray::make(n, 0),
    b: FixedArray::make(n, 0),
    max_code: 0,
    stat_desc,
  }
}

///|
/// The heap used to build the Huffman trees. The sons of heap[n] are
/// heap[2*n] and heap[2*n+1]. heap[0] is not used.
priv struct Heap {
  heap : FixedArray[Int]
  /// number of elements in the heap
  mut heap_len : Int
  /// element of the largest frequency
  mut heap_max : Int
  depth : FixedArray[Int]
}

///|
fn Heap::new() -> Heap {
  {
    heap: FixedArray::make(HEAP_SIZE, 0),
    heap_len: 0,
    heap_max: 0,
    depth: FixedArray::make(HEAP_SIZE, 0),
  }
}

///|
/// Construct the initial heap, with least frequent element in
/// heap[SMALLEST].
fn Heap::initialize(self : Heap, tree : TreeDesc, elements : Int) -> Int {
  let mut max_code = -1
  self.heap_len = 0
  self.heap_max = HEAP_SIZE
  for n in 0..<elements {
    if tree.a[n] > 0 {
      self.heap_len += 1
      self.heap[self.heap_len] = n
      max_code = n
      self.depth[n] = 0
    } else {
      tree.b[n] = 0
    }
  }
  max_code
}

///|
/// Index within the heap array of least frequent node in the Huffman tree.
const SMALLEST : Int = 1

///|
fn Heap::pqdownheap(self : Heap, tree : TreeDesc, k : Int) -> Unit {
  let mut k = k
  let v = self.heap[k]
  let v_val = freq_and_depth(tree, self.depth, v)
  let mut j = k << 1 // left son of k
  while j <= self.heap_len {
    // Set j to the smallest of the two sons:
    let mut j_val = freq_and_depth(tree, self.depth, self.heap[j])
    if j < self.heap_len {
      let j1_val = freq_and_depth(tree, self.depth, self.heap[j + 1])
      if j1_val <= j_val {
        j += 1
        j_val = j1_val
      }
    }
    // Exit if v is smaller than both sons
    if v_val <= j_val {
      break
    }
    // Exchange v with the smallest son
    self.heap[k] = self.heap[j]
    k = j
    // And continue down the tree, setting j to the left son of k
    j = j << 1
  }
  self.heap[k] = v
}

///|
/// Pack the node's frequency and depth into a single integer (a closure in
/// upstream's `pqdownheap`).
#inline
fn freq_and_depth(tree : TreeDesc, depth : FixedArray[Int], i : Int) -> Int {
  (tree.a[i] << 8) | depth[i]
}

///|
/// Remove the smallest element from the heap and recreate the heap with one
/// less element.
fn Heap::pqremove(self : Heap, tree : TreeDesc) -> Int {
  let top = self.heap[SMALLEST]
  self.heap[SMALLEST] = self.heap[self.heap_len]
  self.heap_len -= 1
  self.pqdownheap(tree, SMALLEST)
  top
}

///|
/// Construct the Huffman tree by repeatedly combining the least two frequent
/// nodes.
fn Heap::construct_huffman_tree(
  self : Heap,
  tree : TreeDesc,
  node : Int,
) -> Unit {
  let mut node = node
  while true {
    let n = self.pqremove(tree) // n = node of least frequency
    let m = self.heap[SMALLEST] // m = node of next least frequency
    self.heap_max -= 1
    self.heap[self.heap_max] = n // keep the nodes sorted by frequency
    self.heap_max -= 1
    self.heap[self.heap_max] = m
    // Create a new node father of n and m
    tree.a[node] = (tree.a[n] + tree.a[m]) & 0xffff
    self.depth[node] = (@cmp.maximum(self.depth[n], self.depth[m]) + 1) & 0xff
    tree.b[n] = node
    tree.b[m] = node
    // and insert the new node in the heap
    self.heap[SMALLEST] = node
    node += 1
    self.pqdownheap(tree, SMALLEST)
    if self.heap_len < 2 {
      break
    }
  }
  self.heap_max -= 1
  self.heap[self.heap_max] = self.heap[SMALLEST]
}

///|
fn DeflateStream::build_tree(self : DeflateStream, desc : TreeDesc) -> Unit {
  let tree = desc
  let stree = desc.stat_desc.static_lens
  let elements = desc.stat_desc.elems
  let heap = Heap::new()
  let mut max_code = heap.initialize(tree, elements)

  // The pkzip format requires that at least one distance code exists, and
  // that at least one bit should be sent even if there is only one possible
  // code. So to avoid special checks later on we force at least two codes of
  // non zero frequency.
  while heap.heap_len < 2 {
    heap.heap_len += 1
    let node = if max_code < 2 {
      max_code += 1
      max_code
    } else {
      0
    }
    heap.heap[heap.heap_len] = node
    tree.a[node] = 1
    heap.depth[node] = 0
    self.opt_len -= 1
    if stree is Some(stree) {
      self.static_len -= stree[node]
    }
    // node is 0 or 1 so it does not have extra bits
  }
  desc.max_code = max_code

  // The elements heap[heap_len/2+1 .. heap_len] are leaves of the tree,
  // establish sub-heaps of increasing lengths:
  let mut n = heap.heap_len / 2
  while n >= 1 {
    heap.pqdownheap(tree, n)
    n -= 1
  }
  heap.construct_huffman_tree(tree, elements)

  // At this point, the fields freq and dad are set. We can now generate the
  // bit lengths.
  let bl_count = self.gen_bitlen(heap, desc)

  // The field len is now set, we can generate the bit codes
  gen_codes(desc.a, desc.b, max_code, bl_count)
}

///|
fn DeflateStream::gen_bitlen(
  self : DeflateStream,
  heap : Heap,
  desc : TreeDesc,
) -> FixedArray[Int] {
  let tree = desc
  let max_code = desc.max_code
  let stree = desc.stat_desc.static_lens
  let extra = desc.stat_desc.extra_bits
  let base = desc.stat_desc.extra_base
  let max_length = desc.stat_desc.max_length
  let bl_count = FixedArray::make(MAX_BITS + 1, 0)

  // In a first pass, compute the optimal bit lengths (which may overflow in
  // the case of the bit length tree).
  tree.b[heap.heap[heap.heap_max]] = 0 // root of the heap

  // number of elements with bit length too large
  let mut overflow = 0
  for h in (heap.heap_max + 1)..<HEAP_SIZE {
    let n = heap.heap[h]
    let mut bits = tree.b[tree.b[n]] + 1
    if bits > max_length {
      bits = max_length
      overflow += 1
    }
    // We overwrite tree[n].Dad which is no longer needed
    tree.b[n] = bits

    // not a leaf node
    if n > max_code {
      continue
    }
    bl_count[bits] += 1
    let mut xbits = 0
    if n >= base {
      xbits = extra[n - base]
    }
    let f = tree.a[n]
    self.opt_len += f * (bits + xbits)
    if stree is Some(stree) {
      self.static_len += f * (stree[n] + xbits)
    }
  }
  if overflow == 0 {
    return bl_count
  }

  // Find the first bit length which could increase:
  while true {
    let mut bits = max_length - 1
    while bl_count[bits] == 0 {
      bits -= 1
    }
    bl_count[bits] -= 1 // move one leaf down the tree
    bl_count[bits + 1] += 2 // move one overflow item as its brother
    bl_count[max_length] -= 1
    // The brother of the overflow item also moves one step up, but this does
    // not affect bl_count[max_length]
    overflow -= 2
    if overflow <= 0 {
      break
    }
  }

  // Now recompute all bit lengths, scanning in increasing frequency. h is
  // still equal to HEAP_SIZE.
  let mut h = HEAP_SIZE
  for bits = max_length; bits >= 1; bits = bits - 1 {
    let mut n = bl_count[bits]
    while n != 0 {
      h -= 1
      let m = heap.heap[h]
      if m > max_code {
        continue
      }
      if tree.b[m] != bits {
        // upstream multiplies `u16`s here (wrapping)
        self.opt_len += (bits * tree.a[m]) & 0xffff
        self.opt_len -= (tree.b[m] * tree.a[m]) & 0xffff
        tree.b[m] = bits
      }
      n -= 1
    }
  }
  bl_count
}

///|
/// Generate the codes for a given tree and bit counts (which need not be
/// optimal).
fn gen_codes(
  codes : FixedArray[Int],
  lens : FixedArray[Int],
  max_code : Int,
  bl_count : FixedArray[Int],
) -> Unit {
  let next_code = FixedArray::make(MAX_BITS + 1, 0) // next code value for each bit length
  let mut code = 0 // running code value

  // The distribution counts are first used to generate the code values
  // without bit reversal.
  for bits in 1..<=MAX_BITS {
    code = ((code + bl_count[bits - 1]) << 1) & 0xffff
    next_code[bits] = code
  }
  for n in 0..<=max_code {
    let len = lens[n]
    if len == 0 {
      continue
    }
    // Now reverse the bits
    codes[n] = bi_reverse(next_code[len], len)
    next_code[len] += 1
  }
}

///|
/// Scan a literal or distance tree to determine the frequencies of the codes
/// in the bit length tree.
fn scan_tree(bl_desc : TreeDesc, tree : TreeDesc, max_code : Int) -> Unit {
  let mut prevlen = -1 // last emitted length
  let mut nextlen = tree.b[0] // length of next code
  let mut count = 0 // repeat count of the current code
  let mut max_count = 7 // max repeat count
  let mut min_count = 4 // min repeat count
  if nextlen == 0 {
    max_count = 138
    min_count = 3
  }
  tree.b[max_code + 1] = 0xffff // guard
  let bl_tree = bl_desc
  for n in 0..<=max_code {
    let curlen = nextlen
    nextlen = tree.b[n + 1]
    count += 1
    if count < max_count && curlen == nextlen {
      continue
    } else if count < min_count {
      bl_tree.a[curlen] = (bl_tree.a[curlen] + count) & 0xffff
    } else if curlen != 0 {
      if curlen != prevlen {
        bl_tree.a[curlen] += 1
      }
      bl_tree.a[REP_3_6] += 1
    } else if count <= 10 {
      bl_tree.a[REPZ_3_10] += 1
    } else {
      bl_tree.a[REPZ_11_138] += 1
    }
    count = 0
    prevlen = curlen
    if nextlen == 0 {
      max_count = 138
      min_count = 3
    } else if curlen == nextlen {
      max_count = 6
      min_count = 3
    } else {
      max_count = 7
      min_count = 4
    }
  }
}

///|
/// Send the header for a block using dynamic Huffman trees: the counts, the
/// lengths of the bit length codes, the literal tree and the distance tree.
fn DeflateStream::send_all_trees(
  self : DeflateStream,
  lcodes : Int,
  dcodes : Int,
  blcodes : Int,
) -> Unit {
  let bw = self.bit_writer
  bw.send_bits((lcodes - 257).to_uint64(), 5) // not +255 as stated in appnote.txt
  bw.send_bits((dcodes - 1).to_uint64(), 5)
  bw.send_bits((blcodes - 4).to_uint64(), 4) // not -3 as stated in appnote.txt
  for rank in 0..<blcodes {
    bw.send_bits(self.bl_desc.b[bl_order[rank]].to_uint64(), 3)
  }
  // literal tree
  bw.send_tree(self.l_desc, self.bl_desc, lcodes - 1)
  // distance tree
  bw.send_tree(self.d_desc, self.bl_desc, dcodes - 1)
}

///|
/// Construct the Huffman tree for the bit lengths and return the index in
/// bl_order of the last bit length code to send.
fn DeflateStream::build_bl_tree(self : DeflateStream) -> Int {
  // Determine the bit length frequencies for literal and distance trees
  scan_tree(self.bl_desc, self.l_desc, self.l_desc.max_code)
  scan_tree(self.bl_desc, self.d_desc, self.d_desc.max_code)

  // Build the bit length tree:
  self.build_tree(self.bl_desc)

  // opt_len now includes the length of the tree representations, except the
  // lengths of the bit lengths codes and the 5+5+4 bits for the counts.

  // Determine the number of bit length codes to send. The pkzip format
  // requires that at least 4 bit length codes be sent. (appnote.txt says 3
  // but the actual value used is 4.)
  let mut max_blindex = BL_CODES - 1
  while max_blindex >= 3 {
    let index = bl_order[max_blindex]
    if self.bl_desc.b[index] != 0 {
      break
    }
    max_blindex -= 1
  }

  // Update opt_len to include the bit length tree and counts
  self.opt_len += 3 * (max_blindex + 1) + 5 + 5 + 4
  max_blindex
}

///|
fn DeflateStream::compress_block_static_trees(self : DeflateStream) -> Unit {
  // Upstream's `emit_dist_static` reads the length codes from
  // `STATIC_LTREE_ENCODINGS`, which are `encode_len` on the static tree.
  self.compress_block_help(
    static_ltree.0,
    static_ltree.1,
    static_dtree.0,
    static_dtree.1,
  )
}

///|
fn DeflateStream::compress_block_dynamic_trees(self : DeflateStream) -> Unit {
  self.compress_block_help(
    self.l_desc.a,
    self.l_desc.b,
    self.d_desc.a,
    self.d_desc.b,
  )
}

///|
/// Upstream `compress_block_help`, with `emit_lit`, `emit_dist`
/// (`encode_len`, `encode_dist`) and `send_bits` inlined and the bit buffer
/// kept in locals (performance).
fn DeflateStream::compress_block_help(
  self : DeflateStream,
  lcodes : FixedArray[Int],
  llens : FixedArray[Int],
  dcodes : FixedArray[Int],
  dlens : FixedArray[Int],
) -> Unit {
  let sym = self.sym_buf.buf
  let filled = self.sym_buf.filled
  // One check for all lookups below: literals are bytes, `lc` (the match
  // length - STD_MIN_MATCH) is a byte, the distance - 1 is below 32K.
  guard filled >= 0 &&
    filled <= sym.length() &&
    lcodes.length() >= L_CODES &&
    llens.length() >= L_CODES &&
    dcodes.length() >= D_CODES &&
    dlens.length() >= D_CODES &&
    length_code.length() == 256 &&
    base_length.length() == LENGTH_CODES &&
    extra_lbits.length() == LENGTH_CODES &&
    dist_code.length() == 512 &&
    base_dist.length() == D_CODES &&
    extra_dbits.length() == D_CODES else {
    abort("index out of bounds")
  }
  let bw = self.bit_writer
  let mut bit_buffer = bw.bit_buffer
  let mut bits_valid = bw.bits_valid
  for i = 0; i <= filled - 3; i = i + 3 {
    let dist = sym.unsafe_get(i).to_int() |
      (sym.unsafe_get(i + 1).to_int() << 8)
    let lc = sym.unsafe_get(i + 2).to_int()
    let mut val : UInt64 = 0
    let mut len = 0
    if dist == 0 {
      // emit_lit
      val = u64_of_int(lcodes.unsafe_get(lc))
      len = llens.unsafe_get(lc)
    } else {
      // emit_dist
      let m = encode_len(lcodes, llens, lc)
      let d = encode_dist(dcodes, dlens, dist)
      val = m.bits | (d.bits << m.len)
      len = m.len + d.len
    }
    // send_bits
    let total_bits = len + bits_valid
    if total_bits < BIT_BUF_SIZE {
      bit_buffer = bit_buffer | (val << bits_valid)
      bits_valid = total_bits
    } else if bits_valid == BIT_BUF_SIZE {
      // send_bits_overflow
      bw.push_le_bytes(bit_buffer, 8)
      bit_buffer = val
      bits_valid = total_bits - BIT_BUF_SIZE
    } else {
      bit_buffer = bit_buffer | (val << bits_valid)
      bw.push_le_bytes(bit_buffer, 8)
      bit_buffer = val >> (BIT_BUF_SIZE - bits_valid)
      bits_valid = total_bits - BIT_BUF_SIZE
    }
  }
  bw.bit_buffer = bit_buffer
  bw.bits_valid = bits_valid
  bw.emit_end_block(lcodes, llens)
}

///|
/// Upstream `detect_data_type`: Check if the data type is TEXT or BINARY.
fn detect_data_type(dyn_tree : TreeDesc) -> Int {
  // set bits 0..6, 14..25, and 28..31
  // 0xf3ffc07f = binary 11110011111111111100000001111111
  let mut mask = 0xf3ffc07fU
  // Check for non-textual bytes.
  for n in 0..<32 {
    if (mask & 1) != 0 && dyn_tree.a[n] != 0 {
      return Z_BINARY
    }
    mask = mask >> 1
  }
  // Check for textual bytes.
  if dyn_tree.a[9] != 0 || dyn_tree.a[10] != 0 || dyn_tree.a[13] != 0 {
    return Z_TEXT
  }
  for n in 32..<LITERALS {
    if dyn_tree.a[n] != 0 {
      return Z_TEXT
    }
  }
  // there are no explicit text or non-text bytes. The stream is either empty
  // or has only tolerated bytes
  Z_BINARY
}

///|
const Z_BINARY : Int = 0

///|
const Z_TEXT : Int = 1

///|
const Z_UNKNOWN : Int = 2

///|
/// Send a stored block.
fn DeflateStream::zng_tr_stored_block(
  self : DeflateStream,
  start : Int,
  end : Int,
  is_last : Bool,
) -> Unit {
  let bw = self.bit_writer
  // send block type
  bw.emit_tree(BLOCK_STORED, is_last)
  // align on byte boundary
  bw.emit_align()
  let stored_len = (end - start) & 0xffff
  bw.pending.push((stored_len & 0xff).to_byte())
  bw.pending.push((stored_len >> 8).to_byte())
  let not_len = stored_len ^ 0xffff
  bw.pending.push((not_len & 0xff).to_byte())
  bw.pending.push((not_len >> 8).to_byte())
  if stored_len > 0 {
    bw.pending.extend_window(self.window, start, end - start)
  }
}

///|
/// Determine the best encoding for the current block: dynamic trees, static
/// trees or store, and write out the encoded block.
fn DeflateStream::zng_tr_flush_block(
  self : DeflateStream,
  window_offset : Int?,
  stored_len : Int,
  last : Bool,
) -> Unit {
  // window_offset: offset of the input block into the window
  // stored_len: length of input block
  // last: one if this is the last block for a file
  let mut opt_lenb = 0
  let mut static_lenb = 0
  let mut max_blindex = 0
  if self.sym_buf.is_empty() {
    opt_lenb = 0
    static_lenb = 0
    self.static_len = 7
  } else if self.level > 0 {
    if self.data_type == Z_UNKNOWN {
      self.data_type = detect_data_type(self.l_desc)
    }
    self.build_tree(self.l_desc)
    self.build_tree(self.d_desc)

    // Build the bit length tree for the above two trees, and get the index in
    // bl_order of the last bit length code to send.
    max_blindex = self.build_bl_tree()

    // Determine the best encoding. Compute the block lengths in bytes.
    opt_lenb = (self.opt_len + 3 + 7) >> 3
    static_lenb = (self.static_len + 3 + 7) >> 3
    if static_lenb <= opt_lenb || self.strategy == STRATEGY_FIXED {
      opt_lenb = static_lenb
    }
  } else {
    // force a stored block
    opt_lenb = stored_len + 5
    static_lenb = stored_len + 5
  }
  if stored_len + 4 <= opt_lenb && window_offset is Some(window_offset) {
    // 4: two words for the lengths
    self.zng_tr_stored_block(window_offset, window_offset + stored_len, last)
  } else if static_lenb == opt_lenb {
    self.bit_writer.emit_tree(BLOCK_STATIC_TREES, last)
    self.compress_block_static_trees()
  } else {
    self.bit_writer.emit_tree(BLOCK_DYNAMIC_TREES, last)
    self.send_all_trees(
      self.l_desc.max_code + 1,
      self.d_desc.max_code + 1,
      max_blindex + 1,
    )
    self.compress_block_dynamic_trees()
  }
  self.init_block()
  if last {
    self.bit_writer.emit_align()
  }
}

///|
/// Initializes a new block.
fn DeflateStream::init_block(self : DeflateStream) -> Unit {
  // Initialize the trees.
  for n in 0..<L_CODES {
    self.l_desc.a[n] = 0
  }
  for n in 0..<D_CODES {
    self.d_desc.a[n] = 0
  }
  for n in 0..<BL_CODES {
    self.bl_desc.a[n] = 0
  }
  self.l_desc.a[END_BLOCK] = 1
  self.opt_len = 0
  self.static_len = 0
  self.sym_buf.clear()
  self.matches = 0
}

///|
fn DeflateStream::tally_lit(self : DeflateStream, unmatched : Int) -> Bool {
  self.sym_buf.push_lit(unmatched)
  self.l_desc.a[unmatched] += 1
  // signal that the current block should be flushed
  self.sym_buf.should_flush_block()
}

///|
fn DeflateStream::tally_dist(
  self : DeflateStream,
  dist : Int,
  len : Int,
) -> Bool {
  self.sym_buf.push_dist(dist, len)
  self.matches = @cmp.minimum(self.matches + 1, 255)
  let dist = dist - 1
  guard dist < self.max_dist() else { abort("tally_dist: bad match") }
  let index = length_code[len] + LITERALS + 1
  self.l_desc.a[index] += 1
  self.d_desc.a[d_code(dist)] += 1
  // signal that the current block should be flushed
  self.sym_buf.should_flush_block()
}
