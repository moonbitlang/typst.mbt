// Port of image-webp 0.2.4 `src/lossless.rs`, `src/huffman.rs` and
// `src/lossless_transform.rs`: the lossless (VP8L) WebP decoder.

// ---------------------------------------------------------------------------
// BitReader

///|
/// `BitReader` over in-memory data (`fill_buf` returns the unread rest).
priv struct WebpBitReader {
  data : BytesView
  mut pos : Int
  mut buffer : UInt64
  mut nbits : Int
}

///|
fn WebpBitReader::new(data : BytesView) -> WebpBitReader {
  { data, pos: 0, buffer: 0, nbits: 0, }
}

///|
/// Fills the buffer with bits from the input stream: afterwards it contains
/// 56+ bits or the input is exhausted.
fn WebpBitReader::fill(self : WebpBitReader) -> Unit {
  let avail = self.data.length() - self.pos
  if avail >= 8 {
    let mut lookahead = 0UL
    for i in 0..<8 {
      lookahead = lookahead | (self.data[self.pos + i].to_uint64() << (8 * i))
    }
    self.pos += (63 - self.nbits) / 8
    self.buffer = self.buffer | (lookahead << self.nbits)
    self.nbits = self.nbits | 56
  } else {
    while self.pos < self.data.length() && self.nbits < 56 {
      self.buffer = self.buffer |
        (self.data[self.pos].to_uint64() << self.nbits)
      self.nbits += 8
      self.pos += 1
    }
  }
}

///|
fn WebpBitReader::peek(self : WebpBitReader, num : Int) -> UInt64 {
  self.buffer & ((1UL << num) - 1)
}

///|
fn WebpBitReader::consume(
  self : WebpBitReader,
  num : Int,
) -> Unit raise ImageError {
  if self.nbits < num {
    raise ImageError("Corrupt bitstream")
  }
  self.buffer = self.buffer >> num
  self.nbits -= num
}

///|
fn WebpBitReader::read_bits(
  self : WebpBitReader,
  num : Int,
) -> Int raise ImageError {
  if self.nbits < num {
    self.fill()
  }
  let value = self.peek(num).to_int()
  self.consume(num)
  value
}

// ---------------------------------------------------------------------------
// huffman.rs

///|
let max_allowed_code_length : Int = 15

///|
let max_table_bits : Int = 10

///|
/// `HuffmanTreeNode`: `Branch(offset)` is `offset >= 0`, `Leaf(symbol)` is
/// `-1 - symbol` and `Empty` is `empty_node`.
let empty_node : Int = -100000

///|
priv enum HuffmanTree {
  Single(Int)
  Tree(tree~ : Array[Int], table~ : FixedArray[UInt], table_mask~ : Int)
}

///|
fn HuffmanTree::build_implicit(
  code_lengths : FixedArray[Int],
) -> HuffmanTree raise ImageError {
  let mut num_symbols = 0
  let code_length_hist = FixedArray::make(max_allowed_code_length + 1, 0)
  for length in code_lengths {
    if length != 0 {
      code_length_hist[length] = (code_length_hist[length] + 1) & 0xFFFF
      num_symbols += 1
    }
  }
  if num_symbols == 0 {
    raise ImageError("Invalid Huffman code")
  } else if num_symbols == 1 {
    for i, x in code_lengths {
      if x != 0 {
        return Single(i)
      }
    }
  }
  let mut curr_code = 0
  let next_codes = FixedArray::make(max_allowed_code_length + 1, 0)
  let mut max_code_length = 0
  for i in 0..<=max_allowed_code_length {
    if code_length_hist[i] != 0 {
      max_code_length = i
    }
  }
  for code_len in 1..<(max_code_length + 1) {
    next_codes[code_len] = curr_code
    curr_code = ((curr_code + code_length_hist[code_len]) << 1) & 0xFFFF
  }
  if curr_code != ((2 << max_code_length) & 0xFFFF) {
    raise ImageError("Invalid Huffman code")
  }
  let table_bits = if max_code_length < max_table_bits {
    max_code_length
  } else {
    max_table_bits
  }
  let table_size = 1 << table_bits
  let table_mask = table_size - 1
  let tree : Array[Int] = []
  let table = FixedArray::make(table_size, 0U)
  for symbol, length in code_lengths {
    if length == 0 {
      continue
    }
    let code = next_codes[length]
    next_codes[length] = (next_codes[length] + 1) & 0xFFFF
    let rev = webp_reverse_bits16(code) >> (16 - length)
    if length <= table_bits {
      let mut j = rev
      let entry = (length.reinterpret_as_uint() << 16) |
        symbol.reinterpret_as_uint()
      while j < table_size {
        table[j] = entry
        j += 1 << length
      }
    } else {
      let table_index = rev & table_mask
      let table_value = table[table_index]
      let mut node_index = if table_value == 0 {
        let node_index = tree.length()
        table[table_index] = (node_index + 1).reinterpret_as_uint()
        tree.push(empty_node)
        node_index
      } else {
        (table_value - 1).reinterpret_as_int()
      }
      for depth = length - table_bits - 1; depth >= 0; depth = depth - 1 {
        let node = tree[node_index]
        let offset = if node == empty_node {
          let offset = tree.length() - node_index
          tree[node_index] = offset
          tree.push(empty_node)
          tree.push(empty_node)
          offset
        } else if node < 0 {
          raise ImageError("Invalid Huffman code")
        } else {
          node
        }
        node_index += offset + ((code >> depth) & 1)
      }
      if tree[node_index] == empty_node {
        tree[node_index] = -1 - symbol
      } else {
        raise ImageError("Invalid Huffman code")
      }
    }
  }
  Tree(tree~, table~, table_mask~)
}

///|
fn webp_reverse_bits16(v : Int) -> Int {
  let mut r = 0
  for i in 0..<16 {
    if (v & (1 << i)) != 0 {
      r = r | (1 << (15 - i))
    }
  }
  r
}

///|
fn HuffmanTree::build_two_node(zero : Int, one : Int) -> HuffmanTree {
  Tree(
    tree=[-1 - zero, -1 - one, empty_node],
    table=[
      (1U << 16) | zero.reinterpret_as_uint(),
      (1U << 16) | one.reinterpret_as_uint(),
    ],
    table_mask=1,
  )
}

///|
fn HuffmanTree::is_single_node(self : HuffmanTree) -> Bool {
  self is Single(_)
}

///|
fn HuffmanTree::read_symbol(
  self : HuffmanTree,
  bit_reader : WebpBitReader,
) -> Int raise ImageError {
  match self {
    Tree(tree~, table~, table_mask~) => {
      let v = (bit_reader.buffer & 0xFFFFUL).to_int()
      let entry = table[v & table_mask]
      if entry >> 16 != 0 {
        bit_reader.consume((entry >> 16).reinterpret_as_int())
        return (entry & 0xFFFF).reinterpret_as_int()
      }
      // `read_symbol_slowpath`
      let mut v = v >> max_table_bits
      let mut depth = max_table_bits
      let mut index = (entry & 0xFFFF).reinterpret_as_int() - 1
      while true {
        let node = tree[index]
        if node == empty_node {
          raise ImageError("Invalid Huffman code")
        } else if node >= 0 {
          index += node + (v & 1)
          depth += 1
          v = v >> 1
        } else {
          bit_reader.consume(depth)
          return -1 - node
        }
      }
      0
    }
    Single(symbol) => symbol
  }
}

///|
fn HuffmanTree::peek_symbol(
  self : HuffmanTree,
  bit_reader : WebpBitReader,
) -> (Int, Int)? {
  match self {
    Tree(table~, table_mask~, ..) => {
      let v = (bit_reader.buffer & 0xFFFFUL).to_int()
      let entry = table[v & table_mask]
      if entry >> 16 != 0 {
        return Some(
          (
            (entry >> 16).reinterpret_as_int(),
            (entry & 0xFFFF).reinterpret_as_int(),
          ),
        )
      }
      None
    }
    Single(symbol) => Some((0, symbol))
  }
}

// ---------------------------------------------------------------------------
// lossless.rs

///|
let code_length_code_order : ReadOnlyArray[Int] = [
  17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
]

///|
/// `DISTANCE_MAP` as (xoffset, yoffset) pairs.
let distance_map : ReadOnlyArray[Int] = [
  0, 1, 1, 0, 1, 1, -1, 1, 0, 2, 2, 0, 1, 2, -1, 2, 2, 1, -2, 1, 2, 2, -2, 2, 0,
  3, 3, 0, 1, 3, -1, 3, 3, 1, -3, 1, 2, 3, -2, 3, 3, 2, -3, 2, 0, 4, 4, 0, 1, 4,
  -1, 4, 4, 1, -4, 1, 3, 3, -3, 3, 2, 4, -2, 4, 4, 2, -4, 2, 0, 5, 3, 4, -3, 4, 4,
  3, -4, 3, 5, 0, 1, 5, -1, 5, 5, 1, -5, 1, 2, 5, -2, 5, 5, 2, -5, 2, 4, 4, -4, 4,
  3, 5, -3, 5, 5, 3, -5, 3, 0, 6, 6, 0, 1, 6, -1, 6, 6, 1, -6, 1, 2, 6, -2, 6, 6,
  2, -6, 2, 4, 5, -4, 5, 5, 4, -5, 4, 3, 6, -3, 6, 6, 3, -6, 3, 0, 7, 7, 0, 1, 7,
  -1, 7, 5, 5, -5, 5, 7, 1, -7, 1, 4, 6, -4, 6, 6, 4, -6, 4, 2, 7, -2, 7, 7, 2, -7,
  2, 3, 7, -3, 7, 7, 3, -7, 3, 5, 6, -5, 6, 6, 5, -6, 5, 8, 0, 4, 7, -4, 7, 7, 4,
  -7, 4, 8, 1, 8, 2, 6, 6, -6, 6, 8, 3, 5, 7, -5, 7, 7, 5, -7, 5, 8, 4, 6, 7, -6,
  7, 7, 6, -7, 6, 8, 5, 7, 7, -7, 7, 8, 6, 8, 7,
]

///|
let alphabet_size : ReadOnlyArray[Int] = [256 + 24, 256, 256, 256, 40]

///|
fn subsample_size(size : Int, bits : Int) -> Int {
  (size + (1 << bits) - 1) >> bits
}

///|
priv enum TransformType {
  PredictorTransform(size_bits~ : Int, predictor_data~ : FixedArray[Byte])
  ColorTransform(size_bits~ : Int, transform_data~ : FixedArray[Byte])
  SubtractGreen
  ColorIndexingTransform(table_size~ : Int, table_data~ : FixedArray[Byte])
}

///|
priv struct ColorCache {
  color_cache_bits : Int
  color_cache : FixedArray[UInt]
}

///|
/// Stores the RGBA bytes `[r, g, b, a]` packed little-endian.
fn ColorCache::insert(
  self : ColorCache,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit {
  let color_u32 = (r.reinterpret_as_uint() << 16) |
    (g.reinterpret_as_uint() << 8) |
    b.reinterpret_as_uint() |
    (a.reinterpret_as_uint() << 24)
  let index = (0x1e35a7bdU * color_u32) >> (32 - self.color_cache_bits)
  self.color_cache[index.reinterpret_as_int()] = r.reinterpret_as_uint() |
    (g.reinterpret_as_uint() << 8) |
    (b.reinterpret_as_uint() << 16) |
    (a.reinterpret_as_uint() << 24)
}

///|
priv struct HuffmanInfo {
  xsize : Int
  color_cache : ColorCache?
  image : Array[Int]
  bits : Int
  mask : Int
  huffman_code_groups : Array[Array[HuffmanTree]]
}

///|
fn HuffmanInfo::get_huff_index(self : HuffmanInfo, x : Int, y : Int) -> Int {
  if self.bits == 0 {
    return 0
  }
  let position = (y >> self.bits) * self.xsize + (x >> self.bits)
  self.image[position]
}

///|
priv struct LosslessDecoder {
  bit_reader : WebpBitReader
  transforms : FixedArray[TransformType?]
  transform_order : Array[Int]
  mut width : Int
  mut height : Int
}

///|
fn LosslessDecoder::new(data : BytesView) -> LosslessDecoder {
  {
    bit_reader: WebpBitReader::new(data),
    transforms: FixedArray::make(4, None),
    transform_order: [],
    width: 0,
    height: 0,
  }
}

///|
/// Decodes a frame into `buf` (RGBA, `width * height * 4` bytes). In an
/// alpha chunk the dimensions are implicit.
fn LosslessDecoder::decode_frame(
  self : LosslessDecoder,
  width : Int,
  height : Int,
  implicit_dimensions : Bool,
  buf : FixedArray[Byte],
) -> Unit raise ImageError {
  if implicit_dimensions {
    self.width = width & 0xFFFF
    self.height = height & 0xFFFF
  } else {
    let signature = self.bit_reader.read_bits(8)
    if signature != 0x2f {
      raise ImageError(
        "Invalid lossless signature: \{signature.to_string(radix=16)}",
      )
    }
    self.width = self.bit_reader.read_bits(14) + 1
    self.height = self.bit_reader.read_bits(14) + 1
    if self.width != width || self.height != height {
      raise ImageError("Inconsistent image sizes")
    }
    let _alpha_used = self.bit_reader.read_bits(1)
    let version_num = self.bit_reader.read_bits(3)
    if version_num != 0 {
      raise ImageError("Invalid lossless version number: \{version_num}")
    }
  }
  let transformed_width = self.read_transforms()
  let transformed_size = transformed_width * self.height * 4
  self.decode_image_stream(
    transformed_width,
    self.height,
    true,
    buf,
    transformed_size,
  )
  let mut image_size = transformed_size
  let mut width = transformed_width
  for k = self.transform_order.length() - 1; k >= 0; k = k - 1 {
    let trans_index = self.transform_order[k]
    match self.transforms[trans_index].unwrap() {
      PredictorTransform(size_bits~, predictor_data~) =>
        apply_predictor_transform(
          buf,
          image_size,
          width,
          self.height,
          size_bits,
          predictor_data,
        )
      ColorTransform(size_bits~, transform_data~) =>
        apply_color_transform(buf, image_size, width, size_bits, transform_data)
      SubtractGreen => apply_subtract_green_transform(buf, image_size)
      ColorIndexingTransform(table_size~, table_data~) => {
        width = self.width
        image_size = width * self.height * 4
        apply_color_indexing_transform(
          buf,
          width,
          self.height,
          table_size,
          table_data,
        )
      }
    }
  }
}

///|
/// Reads image data from the bitstream into `data[..len]`.
fn LosslessDecoder::decode_image_stream(
  self : LosslessDecoder,
  xsize : Int,
  ysize : Int,
  is_argb_img : Bool,
  data : FixedArray[Byte],
  len : Int,
) -> Unit raise ImageError {
  let color_cache_bits = self.read_color_cache()
  let color_cache = color_cache_bits.map(bits => {
    color_cache_bits: bits,
    color_cache: FixedArray::make(1 << bits, 0U),
  })
  let huffman_info = self.read_huffman_codes(
    is_argb_img, xsize, ysize, color_cache,
  )
  self.decode_image_data(xsize, ysize, huffman_info, data, len)
}

///|
/// Reads transforms and their data from the bitstream.
fn LosslessDecoder::read_transforms(
  self : LosslessDecoder,
) -> Int raise ImageError {
  let mut xsize = self.width
  while self.bit_reader.read_bits(1) == 1 {
    let transform_type_val = self.bit_reader.read_bits(2)
    if self.transforms[transform_type_val] is Some(_) {
      //can only have one of each transform, error
      raise ImageError("Invalid transform")
    }
    self.transform_order.push(transform_type_val)
    let transform_type : TransformType = match transform_type_val {
      0 => {
        //predictor
        let size_bits = self.bit_reader.read_bits(3) + 2
        let block_xsize = subsample_size(xsize, size_bits)
        let block_ysize = subsample_size(self.height, size_bits)
        let n = block_xsize * block_ysize * 4
        let predictor_data = FixedArray::make(n, b'\x00')
        self.decode_image_stream(
          block_xsize, block_ysize, false, predictor_data, n,
        )
        PredictorTransform(size_bits~, predictor_data~)
      }
      1 => {
        //color transform
        let size_bits = self.bit_reader.read_bits(3) + 2
        let block_xsize = subsample_size(xsize, size_bits)
        let block_ysize = subsample_size(self.height, size_bits)
        let n = block_xsize * block_ysize * 4
        let transform_data = FixedArray::make(n, b'\x00')
        self.decode_image_stream(
          block_xsize, block_ysize, false, transform_data, n,
        )
        ColorTransform(size_bits~, transform_data~)
      }
      2 =>
        //subtract green
        SubtractGreen
      _ => {
        let color_table_size = self.bit_reader.read_bits(8) + 1
        let n = color_table_size * 4
        let color_map = FixedArray::make(n, b'\x00')
        self.decode_image_stream(color_table_size, 1, false, color_map, n)
        let bits = if color_table_size <= 2 {
          3
        } else if color_table_size <= 4 {
          2
        } else if color_table_size <= 16 {
          1
        } else {
          0
        }
        xsize = subsample_size(xsize, bits)
        // Adjusts the color map since it's subtraction coded
        for i in 4..<color_map.length() {
          color_map[i] = (color_map[i].to_int() + color_map[i - 4].to_int()).to_byte()
        }
        ColorIndexingTransform(
          table_size=color_table_size,
          table_data=color_map,
        )
      }
    }
    self.transforms[transform_type_val] = Some(transform_type)
  }
  xsize
}

///|
/// Reads huffman codes associated with an image.
fn LosslessDecoder::read_huffman_codes(
  self : LosslessDecoder,
  read_meta : Bool,
  xsize : Int,
  ysize : Int,
  color_cache : ColorCache?,
) -> HuffmanInfo raise ImageError {
  let mut num_huff_groups = 1
  let mut huffman_bits = 0
  let mut huffman_xsize = 1
  let entropy_image = []
  if read_meta && self.bit_reader.read_bits(1) == 1 {
    //meta huffman codes
    huffman_bits = self.bit_reader.read_bits(3) + 2
    huffman_xsize = subsample_size(xsize, huffman_bits)
    let huffman_ysize = subsample_size(ysize, huffman_bits)
    let n = huffman_xsize * huffman_ysize * 4
    let data = FixedArray::make(n, b'\x00')
    self.decode_image_stream(huffman_xsize, huffman_ysize, false, data, n)
    for i in 0..<(n / 4) {
      let meta_huff_code = (data[i * 4].to_int() << 8) |
        data[i * 4 + 1].to_int()
      if meta_huff_code >= num_huff_groups {
        num_huff_groups = meta_huff_code + 1
      }
      entropy_image.push(meta_huff_code)
    }
  }
  let hufftree_groups = []
  for _ in 0..<num_huff_groups {
    let group = []
    for j in 0..<5 {
      let mut size = alphabet_size[j]
      if j == 0 && color_cache is Some(color_cache) {
        size += 1 << color_cache.color_cache_bits
      }
      group.push(self.read_huffman_code(size))
    }
    hufftree_groups.push(group)
  }
  let huffman_mask = if huffman_bits == 0 {
    0xFFFF
  } else {
    (1 << huffman_bits) - 1
  }
  {
    xsize: huffman_xsize,
    color_cache,
    image: entropy_image,
    bits: huffman_bits,
    mask: huffman_mask,
    huffman_code_groups: hufftree_groups,
  }
}

///|
/// Decodes and returns a single huffman tree.
fn LosslessDecoder::read_huffman_code(
  self : LosslessDecoder,
  alphabet_size : Int,
) -> HuffmanTree raise ImageError {
  let simple = self.bit_reader.read_bits(1) == 1
  if simple {
    let num_symbols = self.bit_reader.read_bits(1) + 1
    let is_first_8bits = self.bit_reader.read_bits(1)
    let zero_symbol = self.bit_reader.read_bits(1 + 7 * is_first_8bits)
    if zero_symbol >= alphabet_size {
      raise ImageError("Corrupt bitstream")
    }
    if num_symbols == 1 {
      Single(zero_symbol)
    } else {
      let one_symbol = self.bit_reader.read_bits(8)
      if one_symbol >= alphabet_size {
        raise ImageError("Corrupt bitstream")
      }
      HuffmanTree::build_two_node(zero_symbol, one_symbol)
    }
  } else {
    let code_length_code_lengths = FixedArray::make(19, 0)
    let num_code_lengths = 4 + self.bit_reader.read_bits(4)
    for i in 0..<num_code_lengths {
      code_length_code_lengths[code_length_code_order[i]] = self.bit_reader.read_bits(
        3,
      )
    }
    let new_code_lengths = self.read_huffman_code_lengths(
      code_length_code_lengths, alphabet_size,
    )
    HuffmanTree::build_implicit(new_code_lengths)
  }
}

///|
/// Reads huffman code lengths.
fn LosslessDecoder::read_huffman_code_lengths(
  self : LosslessDecoder,
  code_length_code_lengths : FixedArray[Int],
  num_symbols : Int,
) -> FixedArray[Int] raise ImageError {
  let table = HuffmanTree::build_implicit(code_length_code_lengths)
  let mut max_symbol = if self.bit_reader.read_bits(1) == 1 {
    let length_nbits = 2 + 2 * self.bit_reader.read_bits(3)
    let max_minus_two = self.bit_reader.read_bits(length_nbits)
    if max_minus_two > num_symbols - 2 {
      raise ImageError("Corrupt bitstream")
    }
    2 + max_minus_two
  } else {
    num_symbols
  }
  let code_lengths = FixedArray::make(num_symbols, 0)
  let mut prev_code_len = 8 //default code length
  let mut symbol = 0
  while symbol < num_symbols {
    if max_symbol == 0 {
      break
    }
    max_symbol -= 1
    self.bit_reader.fill()
    let code_len = table.read_symbol(self.bit_reader)
    if code_len < 16 {
      code_lengths[symbol] = code_len
      symbol += 1
      if code_len != 0 {
        prev_code_len = code_len
      }
    } else {
      let use_prev = code_len == 16
      let slot = code_len - 16
      let extra_bits = match slot {
        0 => 2
        1 => 3
        2 => 7
        _ => raise ImageError("Corrupt bitstream")
      }
      let repeat_offset = if slot == 2 { 11 } else { 3 }
      let mut repeat = self.bit_reader.read_bits(extra_bits) + repeat_offset
      if symbol + repeat > num_symbols {
        raise ImageError("Corrupt bitstream")
      }
      let length = if use_prev { prev_code_len } else { 0 }
      while repeat > 0 {
        repeat -= 1
        code_lengths[symbol] = length
        symbol += 1
      }
    }
  }
  code_lengths
}

///|
/// Decodes the image data using the huffman trees and either of the 3
/// methods of decoding.
fn LosslessDecoder::decode_image_data(
  self : LosslessDecoder,
  width : Int,
  height : Int,
  huffman_info : HuffmanInfo,
  data : FixedArray[Byte],
  len : Int,
) -> Unit raise ImageError {
  let num_values = width * height
  let br = self.bit_reader
  let huff_index = huffman_info.get_huff_index(0, 0)
  let mut tree = huffman_info.huffman_code_groups[huff_index]
  let mut index = 0
  let mut next_block_start = 0
  let set = (i : Int, v : Int) => {
    if i >= len {
      abort("index out of bounds")
    }
    data[i] = v.to_byte()
  }
  while index < num_values {
    br.fill()
    if index >= next_block_start {
      let x = index % width
      let y = index / width
      let xm = x | huffman_info.mask
      next_block_start = (if xm < width - 1 { xm } else { width - 1 }) +
        y * width +
        1
      let huff_index = huffman_info.get_huff_index(x, y)
      tree = huffman_info.huffman_code_groups[huff_index]
      // Fast path: If all the codes each contain only a single
      // symbol, then the pixel data isn't written to the bitstream
      // and we can just fill the output buffer with the symbol
      // directly.
      if tree[0].is_single_node() &&
        tree[1].is_single_node() &&
        tree[2].is_single_node() &&
        tree[3].is_single_node() {
        let code = tree[0].read_symbol(br)
        if code < 256 {
          let n = if huffman_info.bits == 0 {
            num_values
          } else {
            next_block_start - index
          }
          let red = tree[1].read_symbol(br) & 0xFF
          let blue = tree[2].read_symbol(br) & 0xFF
          let alpha = tree[3].read_symbol(br) & 0xFF
          for i in 0..<n {
            set(index * 4 + i * 4, red)
            set(index * 4 + i * 4 + 1, code)
            set(index * 4 + i * 4 + 2, blue)
            set(index * 4 + i * 4 + 3, alpha)
          }
          if huffman_info.color_cache is Some(color_cache) {
            color_cache.insert(red, code, blue, alpha)
          }
          index += n
          continue
        }
      }
    }
    let code = tree[0].read_symbol(br)
    //check code
    if code < 256 {
      //literal, so just use huffman codes and read as argb
      let green = code
      let red = tree[1].read_symbol(br) & 0xFF
      let blue = tree[2].read_symbol(br) & 0xFF
      if br.nbits < 15 {
        br.fill()
      }
      let alpha = tree[3].read_symbol(br) & 0xFF
      set(index * 4, red)
      set(index * 4 + 1, green)
      set(index * 4 + 2, blue)
      set(index * 4 + 3, alpha)
      if huffman_info.color_cache is Some(color_cache) {
        color_cache.insert(red, green, blue, alpha)
      }
      index += 1
    } else if code < 256 + 24 {
      //backward reference, so go back and use that to add image data
      let length_symbol = code - 256
      let length = get_copy_distance(br, length_symbol)
      let dist_symbol = tree[4].read_symbol(br)
      let dist_code = get_copy_distance(br, dist_symbol)
      let dist = plane_code_to_distance(width, dist_code)
      if index < dist || num_values - index < length {
        raise ImageError("Corrupt bitstream")
      }
      if dist == 1 {
        let s = (index - dist) * 4
        let (r, g, b, a) = (
          data[s].to_int(),
          data[s + 1].to_int(),
          data[s + 2].to_int(),
          data[s + 3].to_int(),
        )
        for i in 0..<length {
          set(index * 4 + i * 4, r)
          set(index * 4 + i * 4 + 1, g)
          set(index * 4 + i * 4 + 2, b)
          set(index * 4 + i * 4 + 3, a)
        }
      } else {
        // (Upstream copies in 16-byte blocks when possible; the bytes
        // within `length` are the same as with this byte-wise copy, and
        // the extra bytes it writes beyond are overwritten later.)
        for i in 0..<(length * 4) {
          set(index * 4 + i, data[index * 4 + i - dist * 4].to_int())
        }
        if huffman_info.color_cache is Some(color_cache) {
          for k in 0..<length {
            let o = (index + k) * 4
            color_cache.insert(
              data[o].to_int(),
              data[o + 1].to_int(),
              data[o + 2].to_int(),
              data[o + 3].to_int(),
            )
          }
        }
      }
      index += length
    } else {
      //color cache, so use previously stored pixels to get this pixel
      guard huffman_info.color_cache is Some(color_cache) else {
        raise ImageError("Corrupt bitstream")
      }
      let color = color_cache.color_cache[code - 280]
      for k in 0..<4 {
        set(index * 4 + k, ((color >> (8 * k)) & 0xFF).reinterpret_as_int())
      }
      index += 1
      if index < next_block_start {
        if tree[0].peek_symbol(br) is Some((bits, code)) {
          if code >= 280 {
            br.consume(bits)
            let color = color_cache.color_cache[code - 280]
            for k in 0..<4 {
              set(
                index * 4 + k,
                ((color >> (8 * k)) & 0xFF).reinterpret_as_int(),
              )
            }
            index += 1
          }
        }
      }
    }
  }
}

///|
/// Reads color cache data from the bitstream.
fn LosslessDecoder::read_color_cache(
  self : LosslessDecoder,
) -> Int? raise ImageError {
  if self.bit_reader.read_bits(1) == 1 {
    let code_bits = self.bit_reader.read_bits(4)
    if code_bits < 1 || code_bits > 11 {
      raise ImageError("Invalid color cache bits: \{code_bits}")
    }
    Some(code_bits)
  } else {
    None
  }
}

///|
/// Gets the copy distance from the prefix code and bitstream.
fn get_copy_distance(
  bit_reader : WebpBitReader,
  prefix_code : Int,
) -> Int raise ImageError {
  if prefix_code < 4 {
    return prefix_code + 1
  }
  let extra_bits = (prefix_code - 2) >> 1
  let offset = (2 + (prefix_code & 1)) << extra_bits
  let bits = bit_reader.peek(extra_bits).to_int()
  bit_reader.consume(extra_bits)
  offset + bits + 1
}

///|
/// Gets distance to pixel.
fn plane_code_to_distance(xsize : Int, plane_code : Int) -> Int {
  if plane_code > 120 {
    plane_code - 120
  } else {
    let xoffset = distance_map[(plane_code - 1) * 2]
    let yoffset = distance_map[(plane_code - 1) * 2 + 1]
    let dist = xoffset + yoffset * xsize
    if dist < 1 {
      1
    } else {
      dist
    }
  }
}

// ---------------------------------------------------------------------------
// lossless_transform.rs

///|
fn average2(a : Int, b : Int) -> Int {
  (a + b) / 2
}

///|
fn clamp_add_subtract_full(a : Int, b : Int, c : Int) -> Int {
  clamp(a + b - c, 0, 255)
}

///|
fn clamp_add_subtract_half(a : Int, b : Int) -> Int {
  clamp(a + (a - b) / 2, 0, 255)
}

///|
fn apply_predictor_transform(
  image_data : FixedArray[Byte],
  len : Int,
  width : Int,
  height : Int,
  size_bits : Int,
  predictor_data : FixedArray[Byte],
) -> Unit {
  let block_xsize = subsample_size(width, size_bits)
  let d = image_data
  let get = (i : Int) => d[i].to_int()
  let add = (i : Int, v : Int) => {
    if i >= len {
      abort("index out of bounds")
    }
    d[i] = (d[i].to_int() + v).to_byte()
  }
  // Handle top and left borders specially. This involves ignoring mode and using specific
  // predictors for each.
  add(3, 255)
  for i in 4..<(width * 4) {
    add(i, get(i - 4))
  }
  for y in 1..<height {
    for i in 0..<4 {
      add(y * width * 4 + i, get((y - 1) * width * 4 + i))
    }
  }
  let w4 = width * 4
  for y in 1..<height {
    for block_x in 0..<block_xsize {
      let block_index = (y >> size_bits) * block_xsize + block_x
      let predictor = predictor_data[block_index * 4 + 1].to_int()
      let bx = block_x << size_bits
      let start_index = (y * width + (if bx > 1 { bx } else { 1 })) * 4
      let bx1 = (block_x + 1) << size_bits
      let end_index = (y * width + (if bx1 < width { bx1 } else { width })) * 4
      if end_index > len {
        abort("index out of bounds")
      }
      match predictor {
        0 =>
          for i = start_index + 3; i < end_index; i = i + 4 {
            add(i, 0xff)
          }
        1 =>
          for i in start_index..<end_index {
            add(i, get(i - 4))
          }
        2 =>
          for i in start_index..<end_index {
            add(i, get(i - w4))
          }
        3 =>
          for i in start_index..<end_index {
            add(i, get(i - w4 + 4))
          }
        4 =>
          for i in start_index..<end_index {
            add(i, get(i - w4 - 4))
          }
        5 =>
          for i in start_index..<end_index {
            add(i, average2(average2(get(i - 4), get(i - w4 + 4)), get(i - w4)))
          }
        6 =>
          for i in start_index..<end_index {
            add(i, average2(get(i - 4), get(i - w4 - 4)))
          }
        7 =>
          for i in start_index..<end_index {
            add(i, average2(get(i - 4), get(i - w4)))
          }
        8 =>
          for i in start_index..<end_index {
            add(i, average2(get(i - w4 - 4), get(i - w4)))
          }
        9 =>
          for i in start_index..<end_index {
            add(i, average2(get(i - w4), get(i - w4 + 4)))
          }
        10 =>
          for i in start_index..<end_index {
            add(
              i,
              average2(
                average2(get(i - 4), get(i - w4 - 4)),
                average2(get(i - w4), get(i - w4 + 4)),
              ),
            )
          }
        11 =>
          for p = start_index; p < end_index; p = p + 4 {
            let mut predict_left = 0
            let mut predict_top = 0
            for k in 0..<4 {
              let l = get(p - 4 + k)
              let t = get(p - w4 + k)
              let tl = get(p - w4 - 4 + k)
              let predict = l + t - tl
              predict_left += (predict - l).abs()
              predict_top += (predict - t).abs()
            }
            if predict_left < predict_top {
              let l = FixedArray::makei(4, k => get(p - 4 + k))
              for k in 0..<4 {
                add(p + k, l[k])
              }
            } else {
              let t = FixedArray::makei(4, k => get(p - w4 + k))
              for k in 0..<4 {
                add(p + k, t[k])
              }
            }
          }
        12 =>
          for i in start_index..<end_index {
            add(
              i,
              clamp_add_subtract_full(get(i - 4), get(i - w4), get(i - w4 - 4)),
            )
          }
        13 =>
          for i in start_index..<end_index {
            add(
              i,
              clamp_add_subtract_half(
                (get(i - 4) + get(i - w4)) / 2,
                get(i - w4 - 4),
              ),
            )
          }
        _ => ()
      }
    }
  }
}

///|
/// Does color transform on 2 numbers.
fn color_transform_delta(t : Int, c : Int) -> UInt {
  (as_i8(t) * as_i8(c)).reinterpret_as_uint() >> 5
}

///|
fn apply_color_transform(
  image_data : FixedArray[Byte],
  len : Int,
  width : Int,
  size_bits : Int,
  transform_data : FixedArray[Byte],
) -> Unit {
  let block_xsize = subsample_size(width, size_bits)
  let rows = len / (width * 4)
  for y in 0..<rows {
    let row_transform_data_start = (y >> size_bits) * block_xsize * 4
    let blocks = (transform_data.length() - row_transform_data_start) / 4
    for x in 0..<width {
      let block = x >> size_bits
      if block >= blocks {
        break
      }
      let t = row_transform_data_start + block * 4
      let red_to_blue = transform_data[t].to_int()
      let green_to_blue = transform_data[t + 1].to_int()
      let green_to_red = transform_data[t + 2].to_int()
      let p = (y * width + x) * 4
      let green = image_data[p + 1].to_int()
      let mut temp_red = image_data[p].to_int().reinterpret_as_uint()
      let mut temp_blue = image_data[p + 2].to_int().reinterpret_as_uint()
      temp_red += color_transform_delta(green_to_red, green)
      temp_blue += color_transform_delta(green_to_blue, green)
      temp_blue += color_transform_delta(
        red_to_blue,
        (temp_red & 0xFF).reinterpret_as_int(),
      )
      image_data[p] = (temp_red & 0xFF).reinterpret_as_int().to_byte()
      image_data[p + 2] = (temp_blue & 0xFF).reinterpret_as_int().to_byte()
    }
  }
}

///|
fn apply_subtract_green_transform(
  image_data : FixedArray[Byte],
  len : Int,
) -> Unit {
  for p = 0; p + 4 <= len; p = p + 4 {
    let g = image_data[p + 1].to_int()
    image_data[p] = (image_data[p].to_int() + g).to_byte()
    image_data[p + 2] = (image_data[p + 2].to_int() + g).to_byte()
  }
}

///|
fn apply_color_indexing_transform(
  image_data : FixedArray[Byte],
  width : Int,
  height : Int,
  table_size : Int,
  table_data : FixedArray[Byte],
) -> Unit {
  guard! table_size > 0
  if table_size > 16 {
    // Index is in G channel; out-of-bounds indices are [0, 0, 0, 0].
    for p = 0; p + 4 <= image_data.length(); p = p + 4 {
      let idx = image_data[p + 1].to_int()
      for k in 0..<4 {
        image_data[p + k] = if idx * 4 + 3 < table_data.length() {
          table_data[idx * 4 + k]
        } else {
          b'\x00'
        }
      }
    }
  } else {
    let w_bits = if table_size <= 2 {
      3
    } else if table_size <= 4 {
      2
    } else {
      1
    }
    let pixels_per_packed_byte = 1 << w_bits
    let bits_per_entry = 8 / pixels_per_packed_byte
    let mask = (1 << bits_per_entry) - 1
    let packed_width = (width + pixels_per_packed_byte - 1) /
      pixels_per_packed_byte
    if width == 0 || height == 0 {
      return
    }
    // The packed indices (green channel), read before the expansion
    // overwrites them (upstream expands bottom-up in place).
    let packed = FixedArray::make(packed_width * height, 0)
    for y in 0..<height {
      for b in 0..<packed_width {
        packed[y * packed_width + b] = image_data[(y * packed_width + b) * 4 + 1].to_int()
      }
    }
    for y in 0..<height {
      for x in 0..<width {
        let byte = packed[y * packed_width + (x >> w_bits)]
        let k = (byte >> ((x & (pixels_per_packed_byte - 1)) * bits_per_entry)) &
          mask
        let o = (y * width + x) * 4
        for c in 0..<4 {
          image_data[o + c] = if k < table_size {
            table_data[k * 4 + c]
          } else {
            b'\x00'
          }
        }
      }
    }
  }
}
