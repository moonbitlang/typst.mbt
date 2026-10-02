// Port of image-webp 0.2.4 `src/vp8.rs`: a VP8 keyframe decoder (RFC 6386)
// as used for lossy WebP images.

///|
let max_segments : Int = 4

///|
let num_dct_tokens : Int = 12

// Prediction modes (`DC_PRED` ... `B_PRED`, `B_DC_PRED` ... `B_HU_PRED`).

///|
let dc_pred : Int = 0

///|
let v_pred : Int = 1

///|
let h_pred : Int = 2

///|
let tm_pred : Int = 3

///|
let b_pred : Int = 4

///|
let b_dc_pred : Int = 0

///|
let b_tm_pred : Int = 1

///|
let b_ve_pred : Int = 2

///|
let b_he_pred : Int = 3

///|
let b_ld_pred : Int = 4

///|
let b_rd_pred : Int = 5

///|
let b_vr_pred : Int = 6

///|
let b_vl_pred : Int = 7

///|
let b_hd_pred : Int = 8

///|
let b_hu_pred : Int = 9

///|
let segment_id_tree : Array[Int] = [2, 4, -0, -1, -2, -3]

///|
/// Section 11.2: tree for determining the keyframe luma intra prediction
/// modes.
let keyframe_ymode_tree : Array[Int] = [
  -b_pred,
  2,
  4,
  6,
  -dc_pred,
  -v_pred,
  -h_pred,
  -tm_pred,
]

///|
let keyframe_ymode_probs : Array[Int] = [145, 156, 163, 128]

///|
/// Tree for determining the keyframe B_PRED mode.
let keyframe_bpred_mode_tree : Array[Int] = [
  -b_dc_pred,
  2,
  -b_tm_pred,
  4,
  -b_ve_pred,
  6,
  8,
  12,
  -b_he_pred,
  10,
  -b_rd_pred,
  -b_vr_pred,
  -b_ld_pred,
  14,
  -b_vl_pred,
  16,
  -b_hd_pred,
  -b_hu_pred,
]

///|
/// Section 11.4: tree for determining macroblock the chroma mode.
let keyframe_uv_mode_tree : Array[Int] = [
  -dc_pred,
  2,
  -v_pred,
  4,
  -h_pred,
  -tm_pred,
]

///|
let keyframe_uv_mode_probs : Array[Int] = [142, 114, 183]

// DCT tokens.

///|
let dct_0 : Int = 0

///|
let dct_4 : Int = 4

///|
let dct_cat1 : Int = 5

///|
let dct_cat6 : Int = 10

///|
let dct_eob : Int = 11

///|
let dct_token_tree : Array[Int] = [
  -11, 2, -0, 4, -1, 6, 8, 12, -2, 10, -3, -4, 14, 16, -5, -6, 18, 20, -7, -8, -9,
  -10,
]

///|
let dct_cat_base : Array[Int] = [5, 7, 11, 19, 35, 67]

///|
let coeff_bands : Array[Int] = [0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7]

///|
let zigzag : Array[Int] = [0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15]

///|
let keyframe_ymode_nodes : FixedArray[TreeNode] = tree_nodes_from(
  keyframe_ymode_tree,
  keyframe_ymode_probs[:],
)

///|
let keyframe_uv_mode_nodes : FixedArray[TreeNode] = tree_nodes_from(
  keyframe_uv_mode_tree,
  keyframe_uv_mode_probs[:],
)

///|
/// `KEYFRAME_BPRED_MODE_NODES[top][left]`, flattened.
let keyframe_bpred_mode_nodes : Array[FixedArray[TreeNode]] = Array::makei(
  100,
  i => {
    let probs = Array::makei(9, k => keyframe_bpred_mode_probs[i * 9 + k])
    tree_nodes_from(keyframe_bpred_mode_tree, probs[:])
  },
)

///|
priv struct MacroBlock {
  bpred : FixedArray[Int]
  complexity : FixedArray[Int]
  mut luma_mode : Int
  mut chroma_mode : Int
  mut segmentid : Int
  mut coeffs_skipped : Bool
  mut non_zero_dct : Bool
}

///|
fn MacroBlock::default() -> MacroBlock {
  {
    bpred: FixedArray::make(16, b_dc_pred),
    complexity: FixedArray::make(9, 0),
    luma_mode: dc_pred,
    chroma_mode: dc_pred,
    segmentid: 0,
    coeffs_skipped: false,
    non_zero_dct: false,
  }
}

///|
fn MacroBlock::copy(self : MacroBlock) -> MacroBlock {
  { ..self, bpred: self.bpred.copy(), complexity: self.complexity.copy(), }
}

///|
/// A decoded frame (`Frame`): the Y, U and V planes, padded to whole
/// macroblocks.
priv struct Vp8Frame {
  mut width : Int
  mut height : Int
  mut ybuf : FixedArray[Byte]
  mut ubuf : FixedArray[Byte]
  mut vbuf : FixedArray[Byte]
  mut keyframe : Bool
  mut version : Int
  mut for_display : Bool
  mut pixel_type : Int
  mut filter_type : Bool
  mut filter_level : Int
  mut sharpness_level : Int
}

///|
fn Vp8Frame::buffer_width(self : Vp8Frame) -> Int {
  let difference = self.width % 16
  if difference > 0 {
    self.width + (16 - difference % 16)
  } else {
    self.width
  }
}

///|
/// Fills an RGB (`bpp == 3`) or RGBA (`bpp == 4`, alpha untouched) buffer
/// from the YUV buffers (bilinear "fancy" upsampling, the default).
fn Vp8Frame::fill_rgb(
  self : Vp8Frame,
  buf : FixedArray[Byte],
  bpp : Int,
) -> Unit {
  fill_rgb_buffer_fancy(
    buf,
    bpp,
    self.ybuf,
    self.ubuf,
    self.vbuf,
    self.width,
    self.height,
    self.buffer_width(),
  )
}

///|
priv struct Segment {
  mut ydc : Int
  mut yac : Int
  mut y2dc : Int
  mut y2ac : Int
  mut uvdc : Int
  mut uvac : Int
  mut delta_values : Bool
  mut quantizer_level : Int
  mut loopfilter_level : Int
}

///|
priv struct Vp8Decoder {
  data : BytesView
  mut pos : Int
  b : ArithmeticDecoder
  mut mbwidth : Int
  mut mbheight : Int
  macroblocks : Array[MacroBlock]
  frame : Vp8Frame
  mut segments_enabled : Bool
  mut segments_update_map : Bool
  segment : FixedArray[Segment]
  mut loop_filter_adjustments_enabled : Bool
  ref_delta : FixedArray[Int]
  mode_delta : FixedArray[Int]
  partitions : FixedArray[ArithmeticDecoder]
  mut num_partitions : Int
  segment_tree_nodes : FixedArray[TreeNode]
  /// `token_probs[i][j][k]` at `(i * 8 + j) * 3 + k`.
  token_probs : Array[FixedArray[TreeNode]]
  prob_intra : Int
  mut prob_skip_false : Int?
  mut top : Array[MacroBlock]
  mut left : MacroBlock
  mut top_border_y : FixedArray[Byte]
  mut left_border_y : FixedArray[Byte]
  mut top_border_u : FixedArray[Byte]
  mut left_border_u : FixedArray[Byte]
  mut top_border_v : FixedArray[Byte]
  mut left_border_v : FixedArray[Byte]
}

///|
fn Vp8Decoder::new(data : BytesView) -> Vp8Decoder {
  {
    data,
    pos: 0,
    b: ArithmeticDecoder::new(),
    mbwidth: 0,
    mbheight: 0,
    macroblocks: [],
    frame: {
      width: 0,
      height: 0,
      ybuf: [],
      ubuf: [],
      vbuf: [],
      keyframe: false,
      version: 0,
      for_display: false,
      pixel_type: 0,
      filter_type: false,
      filter_level: 0,
      sharpness_level: 0,
    },
    segments_enabled: false,
    segments_update_map: false,
    segment: FixedArray::makei(max_segments, _ => {
      ydc: 0,
      yac: 0,
      y2dc: 0,
      y2ac: 0,
      uvdc: 0,
      uvac: 0,
      delta_values: false,
      quantizer_level: 0,
      loopfilter_level: 0,
    }),
    loop_filter_adjustments_enabled: false,
    ref_delta: FixedArray::make(4, 0),
    mode_delta: FixedArray::make(4, 0),
    partitions: FixedArray::makei(8, _ => ArithmeticDecoder::new()),
    num_partitions: 1,
    segment_tree_nodes: tree_nodes_from(segment_id_tree, [255, 255, 255][:]),
    token_probs: Array::makei(4 * 8 * 3, i => {
      tree_nodes_from(dct_token_tree, coeff_probs[i * 11:i * 11 + 11])
    }),
    prob_intra: 0,
    prob_skip_false: None,
    top: [],
    left: MacroBlock::default(),
    top_border_y: [],
    left_border_y: [],
    top_border_u: [],
    left_border_u: [],
    top_border_v: [],
    left_border_v: [],
  }
}

///|
fn Vp8Decoder::read_bytes(
  self : Vp8Decoder,
  n : Int,
) -> BytesView raise ImageError {
  if self.pos + n > self.data.length() || n < 0 {
    raise ImageError("IO Error: failed to fill whole buffer")
  }
  let v = self.data[self.pos:self.pos + n]
  self.pos += n
  v
}

///|
fn Vp8Decoder::update_token_probabilities(
  self : Vp8Decoder,
) -> Unit raise ImageError {
  for i in 0..<(4 * 8 * 3) {
    let nodes = self.token_probs[i]
    for t in 0..<(num_dct_tokens - 1) {
      if self.b.read_bool(coeff_update_probs[i * 11 + t]) {
        let v = self.b.read_literal(8)
        nodes[t].prob = v
      }
    }
  }
  self.b.check()
}

///|
fn Vp8Decoder::init_partitions(
  self : Vp8Decoder,
  n : Int,
) -> Unit raise ImageError {
  if n > 1 {
    let sizes = self.read_bytes(3 * n - 3)
    for i in 0..<(n - 1) {
      let size = sizes[3 * i].to_int() |
        (sizes[3 * i + 1].to_int() << 8) |
        (sizes[3 * i + 2].to_int() << 16)
      let buf = self.read_bytes(size)
      self.partitions[i].init(buf)
    }
  }
  let rest = self.data[self.pos:]
  self.pos = self.data.length()
  self.partitions[n - 1].init(rest)
}

///|
fn Vp8Decoder::read_quantization_indices(
  self : Vp8Decoder,
) -> Unit raise ImageError {
  let dc_quant = (index : Int) => dc_quant_table[clamp(index, 0, 127)]
  let ac_quant = (index : Int) => ac_quant_table[clamp(index, 0, 127)]
  let yac_abs = self.b.read_literal(7)
  let ydc_delta = self.b.read_optional_signed_value(4)
  let y2dc_delta = self.b.read_optional_signed_value(4)
  let y2ac_delta = self.b.read_optional_signed_value(4)
  let uvdc_delta = self.b.read_optional_signed_value(4)
  let uvac_delta = self.b.read_optional_signed_value(4)
  let n = if self.segments_enabled { max_segments } else { 1 }
  for i in 0..<n {
    let seg = self.segment[i]
    let base = if self.segments_enabled {
      if seg.delta_values {
        seg.quantizer_level + yac_abs
      } else {
        seg.quantizer_level
      }
    } else {
      yac_abs
    }
    seg.ydc = dc_quant(base + ydc_delta)
    seg.yac = ac_quant(base)
    // `i16` multiplication (cannot overflow: at most 157 * 2).
    seg.y2dc = dc_quant(base + y2dc_delta) * 2
    // The intermediate result (max`284*155`) can be larger than the `i16` range.
    seg.y2ac = ac_quant(base + y2ac_delta) * 155 / 100
    seg.uvdc = dc_quant(base + uvdc_delta)
    seg.uvac = ac_quant(base + uvac_delta)
    if seg.y2ac < 8 {
      seg.y2ac = 8
    }
    if seg.uvdc > 132 {
      seg.uvdc = 132
    }
  }
  self.b.check()
}

///|
fn clamp(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// `x as i8` for a small integer.
fn as_i8(x : Int) -> Int {
  let x = x & 0xFF
  if x >= 128 {
    x - 256
  } else {
    x
  }
}

///|
fn Vp8Decoder::read_loop_filter_adjustments(
  self : Vp8Decoder,
) -> Unit raise ImageError {
  if self.b.read_flag() {
    for i in 0..<4 {
      self.ref_delta[i] = self.b.read_optional_signed_value(6)
    }
    for i in 0..<4 {
      self.mode_delta[i] = self.b.read_optional_signed_value(6)
    }
  }
  self.b.check()
}

///|
fn Vp8Decoder::read_segment_updates(self : Vp8Decoder) -> Unit raise ImageError {
  // Section 9.3
  self.segments_update_map = self.b.read_flag()
  let update_segment_feature_data = self.b.read_flag()
  if update_segment_feature_data {
    let segment_feature_mode = self.b.read_flag()
    for i in 0..<max_segments {
      self.segment[i].delta_values = !segment_feature_mode
    }
    for i in 0..<max_segments {
      self.segment[i].quantizer_level = as_i8(
        self.b.read_optional_signed_value(7),
      )
    }
    for i in 0..<max_segments {
      self.segment[i].loopfilter_level = as_i8(
        self.b.read_optional_signed_value(6),
      )
    }
  }
  if self.segments_update_map {
    for i in 0..<3 {
      let update = self.b.read_flag()
      let prob = if update { self.b.read_literal(8) } else { 255 }
      self.segment_tree_nodes[i].prob = prob
    }
  }
  self.b.check()
}

///|
fn Vp8Decoder::read_frame_header(self : Vp8Decoder) -> Unit raise ImageError {
  let tag_bytes = self.read_bytes(3)
  let tag = tag_bytes[0].to_int() |
    (tag_bytes[1].to_int() << 8) |
    (tag_bytes[2].to_int() << 16)
  self.frame.keyframe = (tag & 1) == 0
  self.frame.version = (tag >> 1) & 7
  self.frame.for_display = ((tag >> 4) & 1) != 0
  let first_partition_size = tag >> 5
  if self.frame.keyframe {
    let magic = self.read_bytes(3)
    if magic[0] != 0x9d || magic[1] != 0x01 || magic[2] != 0x2a {
      raise ImageError(
        "Invalid VP8 magic: [\{hex_byte(magic[0])}, \{hex_byte(magic[1])}, \{hex_byte(magic[2])}]",
      )
    }
    let wh = self.read_bytes(4)
    let w = wh[0].to_int() | (wh[1].to_int() << 8)
    let h = wh[2].to_int() | (wh[3].to_int() << 8)
    self.frame.width = w & 0x3FFF
    self.frame.height = h & 0x3FFF
    self.top = init_top_macroblocks(self.frame.width)
    // Almost always the first macro block, except when non exists (i.e. `width == 0`)
    self.left = match self.top {
      [first, ..] => first.copy()
      [] => MacroBlock::default()
    }
    self.mbwidth = (self.frame.width + 15) / 16
    self.mbheight = (self.frame.height + 15) / 16
    self.frame.ybuf = FixedArray::make(
      self.mbwidth * 16 * self.mbheight * 16,
      b'\x00',
    )
    self.frame.ubuf = FixedArray::make(
      self.mbwidth * 8 * self.mbheight * 8,
      b'\x00',
    )
    self.frame.vbuf = FixedArray::make(
      self.mbwidth * 8 * self.mbheight * 8,
      b'\x00',
    )
    self.top_border_y = FixedArray::make(self.frame.width + 4 + 16, b'\x7f')
    self.left_border_y = FixedArray::make(1 + 16, b'\x81')
    // 8 pixels per macroblock
    self.top_border_u = FixedArray::make(8 * self.mbwidth, b'\x7f')
    self.left_border_u = FixedArray::make(1 + 8, b'\x81')
    self.top_border_v = FixedArray::make(8 * self.mbwidth, b'\x7f')
    self.left_border_v = FixedArray::make(1 + 8, b'\x81')
  }
  let buf = self.read_bytes(first_partition_size)
  // initialise binary decoder
  self.b.init(buf)
  if self.frame.keyframe {
    let color_space = self.b.read_literal(1)
    self.frame.pixel_type = self.b.read_literal(1)
    if color_space != 0 {
      raise ImageError("Invalid VP8 color space: \{color_space}")
    }
  }
  self.segments_enabled = self.b.read_flag()
  if self.segments_enabled {
    self.read_segment_updates()
  }
  self.frame.filter_type = self.b.read_flag()
  self.frame.filter_level = self.b.read_literal(6)
  self.frame.sharpness_level = self.b.read_literal(3)
  self.loop_filter_adjustments_enabled = self.b.read_flag()
  if self.loop_filter_adjustments_enabled {
    self.read_loop_filter_adjustments()
  }
  let num_partitions = 1 << self.b.read_literal(2)
  self.b.check()
  self.num_partitions = num_partitions
  self.init_partitions(num_partitions)
  self.read_quantization_indices()
  if !self.frame.keyframe {
    // 9.7 refresh golden frame and altref frame
    raise ImageError("Unsupported feature: Non-keyframe frames")
  }
  // Refresh entropy probs ?????
  let _ = self.b.read_literal(1)
  self.update_token_probabilities()
  let mb_no_skip_coeff = self.b.read_literal(1)
  self.prob_skip_false = if mb_no_skip_coeff == 1 {
    Some(self.b.read_literal(8))
  } else {
    None
  }
  self.b.check()
}

///|
fn hex_byte(b : Byte) -> String {
  b.to_int().to_string(radix=16)
}

///|
fn Vp8Decoder::read_macroblock_header(
  self : Vp8Decoder,
  mbx : Int,
) -> MacroBlock raise ImageError {
  let mb = MacroBlock::default()
  if self.segments_enabled && self.segments_update_map {
    mb.segmentid = self.b.read_with_tree(self.segment_tree_nodes)
  }
  mb.coeffs_skipped = match self.prob_skip_false {
    Some(prob) => self.b.read_bool(prob)
    None => false
  }
  let inter_predicted = if !self.frame.keyframe {
    self.b.read_bool(self.prob_intra)
  } else {
    false
  }
  if inter_predicted {
    raise ImageError("Unsupported feature: VP8 inter-prediction")
  }
  if self.frame.keyframe {
    // intra prediction
    let luma = self.b.read_with_tree(keyframe_ymode_nodes)
    if luma < 0 || luma > b_pred {
      raise ImageError("Invalid VP8 luma prediction mode: \{luma}")
    }
    mb.luma_mode = luma
    match luma_into_intra(luma) {
      // `LumaMode::B` - This is predicted individually
      None =>
        for y in 0..<4 {
          for x in 0..<4 {
            let top = self.top[mbx].bpred[12 + x]
            let left = self.left.bpred[y]
            let intra = self.b.read_with_tree(
              keyframe_bpred_mode_nodes[top * 10 + left],
            )
            if intra < 0 || intra > b_hu_pred {
              raise ImageError("Invalid VP8 intra prediction mode: \{intra}")
            }
            mb.bpred[x + y * 4] = intra
            self.top[mbx].bpred[12 + x] = intra
            self.left.bpred[y] = intra
          }
        }
      Some(mode) =>
        for i in 0..<4 {
          mb.bpred[12 + i] = mode
          self.left.bpred[i] = mode
        }
    }
    let chroma = self.b.read_with_tree(keyframe_uv_mode_nodes)
    if chroma < 0 || chroma > tm_pred {
      raise ImageError("Invalid VP8 chroma prediction mode: \{chroma}")
    }
    mb.chroma_mode = chroma
  }
  self.top[mbx].chroma_mode = mb.chroma_mode
  self.top[mbx].luma_mode = mb.luma_mode
  for i in 0..<16 {
    self.top[mbx].bpred[i] = mb.bpred[i]
  }
  self.b.check()
  mb
}

///|
/// `LumaMode::into_intra`.
fn luma_into_intra(mode : Int) -> Int? {
  if mode == dc_pred {
    Some(b_dc_pred)
  } else if mode == v_pred {
    Some(b_ve_pred)
  } else if mode == h_pred {
    Some(b_he_pred)
  } else if mode == tm_pred {
    Some(b_tm_pred)
  } else {
    None
  }
}

///|
fn Vp8Decoder::intra_predict_luma(
  self : Vp8Decoder,
  mbx : Int,
  mby : Int,
  mb : MacroBlock,
  resdata : FixedArray[Int],
) -> Unit {
  let stride = 1 + 16 + 4
  let mw = self.mbwidth
  let ws = create_border_luma(
    mbx,
    mby,
    mw,
    self.top_border_y,
    self.left_border_y,
  )
  if mb.luma_mode == v_pred {
    predict_vpred(ws, 16, 1, 1, stride)
  } else if mb.luma_mode == h_pred {
    predict_hpred(ws, 16, 1, 1, stride)
  } else if mb.luma_mode == tm_pred {
    predict_tmpred(ws, 16, 1, 1, stride)
  } else if mb.luma_mode == dc_pred {
    predict_dcpred(ws, 16, stride, mby != 0, mbx != 0)
  } else {
    predict_4x4(ws, stride, mb.bpred, resdata)
  }
  if mb.luma_mode != b_pred {
    for y in 0..<4 {
      for x in 0..<4 {
        let i = x + y * 4
        let y0 = 1 + y * 4
        let x0 = 1 + x * 4
        add_residue(ws, resdata, i * 16, y0, x0, stride)
      }
    }
  }
  self.left_border_y[0] = ws[16]
  for i in 0..<16 {
    self.left_border_y[1 + i] = ws[(i + 1) * stride + 16]
  }
  for i in 0..<16 {
    self.top_border_y[mbx * 16 + i] = ws[16 * stride + 1 + i]
  }
  for y in 0..<16 {
    let o = (mby * 16 + y) * mw * 16 + mbx * 16
    for i in 0..<16 {
      self.frame.ybuf[o + i] = ws[(1 + y) * stride + 1 + i]
    }
  }
}

///|
fn Vp8Decoder::intra_predict_chroma(
  self : Vp8Decoder,
  mbx : Int,
  mby : Int,
  mb : MacroBlock,
  resdata : FixedArray[Int],
) -> Unit {
  let stride = 1 + 8
  let mw = self.mbwidth
  //8x8 with left top border of 1
  let uws = create_border_chroma(
    mbx,
    mby,
    self.top_border_u,
    self.left_border_u,
  )
  let vws = create_border_chroma(
    mbx,
    mby,
    self.top_border_v,
    self.left_border_v,
  )
  if mb.chroma_mode == dc_pred {
    predict_dcpred(uws, 8, stride, mby != 0, mbx != 0)
    predict_dcpred(vws, 8, stride, mby != 0, mbx != 0)
  } else if mb.chroma_mode == v_pred {
    predict_vpred(uws, 8, 1, 1, stride)
    predict_vpred(vws, 8, 1, 1, stride)
  } else if mb.chroma_mode == h_pred {
    predict_hpred(uws, 8, 1, 1, stride)
    predict_hpred(vws, 8, 1, 1, stride)
  } else {
    predict_tmpred(uws, 8, 1, 1, stride)
    predict_tmpred(vws, 8, 1, 1, stride)
  }
  for y in 0..<2 {
    for x in 0..<2 {
      let i = x + y * 2
      let y0 = 1 + y * 4
      let x0 = 1 + x * 4
      add_residue(uws, resdata, 16 * 16 + i * 16, y0, x0, stride)
      add_residue(vws, resdata, 20 * 16 + i * 16, y0, x0, stride)
    }
  }
  set_chroma_border(self.left_border_u, self.top_border_u, uws, mbx)
  set_chroma_border(self.left_border_v, self.top_border_v, vws, mbx)
  for y in 0..<8 {
    let uv_buf_index = (mby * 8 + y) * mw * 8 + mbx * 8
    let ws_index = (1 + y) * stride + 1
    for i in 0..<8 {
      self.frame.ubuf[uv_buf_index + i] = uws[ws_index + i]
      self.frame.vbuf[uv_buf_index + i] = vws[ws_index + i]
    }
  }
}

///|
/// Reads the coefficients of one block into `block[off..off + 16]`.
fn Vp8Decoder::read_coefficients(
  self : Vp8Decoder,
  block : FixedArray[Int],
  off : Int,
  p : Int,
  plane : Int,
  complexity : Int,
  dcq : Int,
  acq : Int,
) -> Bool raise ImageError {
  guard! complexity <= 2
  let first = if plane == 0 { 1 } else { 0 }
  let decoder = self.partitions[p]
  let mut complexity = complexity
  let mut has_coefficients = false
  let mut skip = false
  for i in first..<16 {
    let band = coeff_bands[i]
    let tree = self.token_probs[(plane * 8 + band) * 3 + complexity]
    let token = decoder.read_with_tree_with_first_node(
      tree,
      tree[if skip { 1 } else { 0 }],
    )
    let mut abs_value = if token == dct_eob {
      break
    } else if token == dct_0 {
      skip = true
      has_coefficients = true
      complexity = 0
      continue
    } else if token <= dct_4 {
      token
    } else if token <= dct_cat6 {
      let cat = token - dct_cat1
      let mut extra = 0
      for k in 0..<12 {
        let t = prob_dct_cat[cat * 12 + k]
        if t == 0 {
          break
        }
        let b = decoder.read_bool(t)
        extra = extra + extra + (if b { 1 } else { 0 })
      }
      dct_cat_base[cat] + extra
    } else {
      abort("unknown token: \{token}")
    }
    skip = false
    complexity = if abs_value == 0 { 0 } else if abs_value == 1 { 1 } else { 2 }
    if decoder.read_flag() {
      abs_value = -abs_value
    }
    let zz = zigzag[i]
    block[off + zz] = abs_value * (if zz > 0 { acq } else { dcq })
    has_coefficients = true
  }
  decoder.check()
  has_coefficients
}

///|
fn Vp8Decoder::read_residual_data(
  self : Vp8Decoder,
  mb : MacroBlock,
  mbx : Int,
  p : Int,
) -> FixedArray[Int] raise ImageError {
  let sindex = mb.segmentid
  let blocks = FixedArray::make(384, 0)
  let mut plane = if mb.luma_mode == b_pred { 3 } else { 1 }
  let top = self.top[mbx]
  if plane == 1 {
    let complexity = top.complexity[0] + self.left.complexity[0]
    let block = FixedArray::make(16, 0)
    let dcq = self.segment[sindex].y2dc
    let acq = self.segment[sindex].y2ac
    let n = self.read_coefficients(block, 0, p, plane, complexity, dcq, acq)
    self.left.complexity[0] = if n { 1 } else { 0 }
    top.complexity[0] = if n { 1 } else { 0 }
    vp8_iwht4x4(block)
    for k in 0..<16 {
      blocks[16 * k] = block[k]
    }
    plane = 0
  }
  for y in 0..<4 {
    let mut left = self.left.complexity[y + 1]
    for x in 0..<4 {
      let i = x + y * 4
      let complexity = top.complexity[x + 1] + left
      let dcq = self.segment[sindex].ydc
      let acq = self.segment[sindex].yac
      let n = self.read_coefficients(
        blocks,
        i * 16,
        p,
        plane,
        complexity,
        dcq,
        acq,
      )
      if blocks[i * 16] != 0 || n {
        mb.non_zero_dct = true
        vp8_idct4x4(blocks, i * 16)
      }
      left = if n { 1 } else { 0 }
      top.complexity[x + 1] = if n { 1 } else { 0 }
    }
    self.left.complexity[y + 1] = left
  }
  plane = 2
  for j in [5, 7] {
    for y in 0..<2 {
      let mut left = self.left.complexity[y + j]
      for x in 0..<2 {
        let i = x + y * 2 + (if j == 5 { 16 } else { 20 })
        let complexity = top.complexity[x + j] + left
        let dcq = self.segment[sindex].uvdc
        let acq = self.segment[sindex].uvac
        let n = self.read_coefficients(
          blocks,
          i * 16,
          p,
          plane,
          complexity,
          dcq,
          acq,
        )
        if blocks[i * 16] != 0 || n {
          mb.non_zero_dct = true
          vp8_idct4x4(blocks, i * 16)
        }
        left = if n { 1 } else { 0 }
        top.complexity[x + j] = if n { 1 } else { 0 }
      }
      self.left.complexity[y + j] = left
    }
  }
  blocks
}

///|
/// Does loop filtering on the macroblock.
fn Vp8Decoder::loop_filter(
  self : Vp8Decoder,
  mbx : Int,
  mby : Int,
  mb : MacroBlock,
) -> Unit {
  let luma_w = self.mbwidth * 16
  let chroma_w = self.mbwidth * 8
  let (filter_level, interior_limit, hev_threshold) = self.calculate_filter_parameters(
    mb,
  )
  if filter_level <= 0 {
    return
  }
  // `u8` arithmetic (cannot overflow: at most 63 + 2 * 2 + 63).
  let mbedge_limit = (filter_level + 2) * 2 + interior_limit
  let sub_bedge_limit = filter_level * 2 + interior_limit
  // we skip subblock filtering if the coding mode isn't B_PRED and there's no DCT coefficient coded
  let do_subblock_filtering = mb.luma_mode == b_pred ||
    (!mb.coeffs_skipped && mb.non_zero_dct)
  let ybuf = self.frame.ybuf
  let ubuf = self.frame.ubuf
  let vbuf = self.frame.vbuf
  //filter across left of macroblock
  if mbx > 0 {
    //simple loop filtering
    if self.frame.filter_type {
      for y in 0..<16 {
        let y0 = mby * 16 + y
        let x0 = mbx * 16
        simple_segment_horizontal(mbedge_limit, ybuf, y0 * luma_w + x0 - 4)
      }
    } else {
      for y in 0..<16 {
        let y0 = mby * 16 + y
        let x0 = mbx * 16
        macroblock_filter_horizontal(
          hev_threshold,
          interior_limit,
          mbedge_limit,
          ybuf,
          y0 * luma_w + x0 - 4,
        )
      }
      for y in 0..<8 {
        let y0 = mby * 8 + y
        let x0 = mbx * 8
        macroblock_filter_horizontal(
          hev_threshold,
          interior_limit,
          mbedge_limit,
          ubuf,
          y0 * chroma_w + x0 - 4,
        )
        macroblock_filter_horizontal(
          hev_threshold,
          interior_limit,
          mbedge_limit,
          vbuf,
          y0 * chroma_w + x0 - 4,
        )
      }
    }
  }

  //filter across vertical subblocks in macroblock
  if do_subblock_filtering {
    if self.frame.filter_type {
      for x = 4; x < 16 - 1; x = x + 4 {
        for y in 0..<16 {
          let y0 = mby * 16 + y
          let x0 = mbx * 16 + x
          simple_segment_horizontal(sub_bedge_limit, ybuf, y0 * luma_w + x0 - 4)
        }
      }
    } else {
      for x = 4; x < 16 - 3; x = x + 4 {
        for y in 0..<16 {
          let y0 = mby * 16 + y
          let x0 = mbx * 16 + x
          subblock_filter_horizontal(
            hev_threshold,
            interior_limit,
            sub_bedge_limit,
            ybuf,
            y0 * luma_w + x0 - 4,
          )
        }
      }
      for y in 0..<8 {
        let y0 = mby * 8 + y
        let x0 = mbx * 8 + 4
        subblock_filter_horizontal(
          hev_threshold,
          interior_limit,
          sub_bedge_limit,
          ubuf,
          y0 * chroma_w + x0 - 4,
        )
        subblock_filter_horizontal(
          hev_threshold,
          interior_limit,
          sub_bedge_limit,
          vbuf,
          y0 * chroma_w + x0 - 4,
        )
      }
    }
  }

  //filter across top of macroblock
  if mby > 0 {
    if self.frame.filter_type {
      for x in 0..<16 {
        let y0 = mby * 16
        let x0 = mbx * 16 + x
        simple_segment_vertical(mbedge_limit, ybuf, y0 * luma_w + x0, luma_w)
      }
    } else {
      //if bottom macroblock, can only filter if there is 3 pixels below
      for x in 0..<16 {
        let y0 = mby * 16
        let x0 = mbx * 16 + x
        macroblock_filter_vertical(
          hev_threshold,
          interior_limit,
          mbedge_limit,
          ybuf,
          y0 * luma_w + x0,
          luma_w,
        )
      }
      for x in 0..<8 {
        let y0 = mby * 8
        let x0 = mbx * 8 + x
        macroblock_filter_vertical(
          hev_threshold,
          interior_limit,
          mbedge_limit,
          ubuf,
          y0 * chroma_w + x0,
          chroma_w,
        )
        macroblock_filter_vertical(
          hev_threshold,
          interior_limit,
          mbedge_limit,
          vbuf,
          y0 * chroma_w + x0,
          chroma_w,
        )
      }
    }
  }

  //filter across horizontal subblock edges within the macroblock
  if do_subblock_filtering {
    if self.frame.filter_type {
      for y = 4; y < 16 - 1; y = y + 4 {
        for x in 0..<16 {
          let y0 = mby * 16 + y
          let x0 = mbx * 16 + x
          simple_segment_vertical(
            sub_bedge_limit,
            ybuf,
            y0 * luma_w + x0,
            luma_w,
          )
        }
      }
    } else {
      for y = 4; y < 16 - 3; y = y + 4 {
        for x in 0..<16 {
          let y0 = mby * 16 + y
          let x0 = mbx * 16 + x
          subblock_filter_vertical(
            hev_threshold,
            interior_limit,
            sub_bedge_limit,
            ybuf,
            y0 * luma_w + x0,
            luma_w,
          )
        }
      }
      for x in 0..<8 {
        let y0 = mby * 8 + 4
        let x0 = mbx * 8 + x
        subblock_filter_vertical(
          hev_threshold,
          interior_limit,
          sub_bedge_limit,
          ubuf,
          y0 * chroma_w + x0,
          chroma_w,
        )
        subblock_filter_vertical(
          hev_threshold,
          interior_limit,
          sub_bedge_limit,
          vbuf,
          y0 * chroma_w + x0,
          chroma_w,
        )
      }
    }
  }
}

///|
/// Returns the filter level, interior limit and hev threshold.
fn Vp8Decoder::calculate_filter_parameters(
  self : Vp8Decoder,
  macroblock : MacroBlock,
) -> (Int, Int, Int) {
  let segment = self.segment[macroblock.segmentid]
  let mut filter_level = self.frame.filter_level

  // if frame level filter level is 0, we must skip loop filter
  if filter_level == 0 {
    return (0, 0, 0)
  }
  if self.segments_enabled {
    if segment.delta_values {
      filter_level += segment.loopfilter_level
    } else {
      filter_level = segment.loopfilter_level
    }
  }
  filter_level = clamp(filter_level, 0, 63)
  if self.loop_filter_adjustments_enabled {
    filter_level += self.ref_delta[0]
    if macroblock.luma_mode == b_pred {
      filter_level += self.mode_delta[0]
    }
  }
  let filter_level = clamp(filter_level, 0, 63)

  //interior limit
  let mut interior_limit = filter_level
  if self.frame.sharpness_level > 0 {
    interior_limit = interior_limit >>
      (if self.frame.sharpness_level > 4 { 2 } else { 1 })
    if interior_limit > 9 - self.frame.sharpness_level {
      interior_limit = 9 - self.frame.sharpness_level
    }
  }
  if interior_limit == 0 {
    interior_limit = 1
  }

  //high edge variance threshold
  let mut hev_threshold = 0
  if self.frame.keyframe {
    if filter_level >= 40 {
      hev_threshold = 2
    } else if filter_level >= 15 {
      hev_threshold = 1
    }
  } else if filter_level >= 40 {
    hev_threshold = 3
  } else if filter_level >= 20 {
    hev_threshold = 2
  } else if filter_level >= 15 {
    hev_threshold = 1
  }
  (filter_level, interior_limit, hev_threshold)
}

///|
/// Decodes the frame of a VP8 chunk.
fn vp8_decode_frame(data : BytesView) -> Vp8Frame raise ImageError {
  let d = Vp8Decoder::new(data)
  d.read_frame_header()
  for mby in 0..<d.mbheight {
    let p = mby % d.num_partitions
    d.left = MacroBlock::default()
    for mbx in 0..<d.mbwidth {
      let mb = d.read_macroblock_header(mbx)
      let blocks = if !mb.coeffs_skipped {
        d.read_residual_data(mb, mbx, p)
      } else {
        if mb.luma_mode != b_pred {
          d.left.complexity[0] = 0
          d.top[mbx].complexity[0] = 0
        }
        for i in 1..<9 {
          d.left.complexity[i] = 0
          d.top[mbx].complexity[i] = 0
        }
        FixedArray::make(384, 0)
      }
      d.intra_predict_luma(mbx, mby, mb, blocks)
      d.intra_predict_chroma(mbx, mby, mb, blocks)
      d.macroblocks.push(mb)
    }
    d.left_border_y = FixedArray::make(1 + 16, b'\x81')
    d.left_border_u = FixedArray::make(1 + 8, b'\x81')
    d.left_border_v = FixedArray::make(1 + 8, b'\x81')
  }

  //do loop filtering
  for mby in 0..<d.mbheight {
    for mbx in 0..<d.mbwidth {
      let mb = d.macroblocks[mby * d.mbwidth + mbx]
      d.loop_filter(mbx, mby, mb)
    }
  }
  d.frame
}

///|
fn init_top_macroblocks(width : Int) -> Array[MacroBlock] {
  let mb_width = (width + 15) / 16
  // Section 11.3 #3
  Array::makei(mb_width, _ => MacroBlock::default())
}

///|
fn create_border_luma(
  mbx : Int,
  mby : Int,
  mbw : Int,
  top : FixedArray[Byte],
  left : FixedArray[Byte],
) -> FixedArray[Byte] {
  let stride = 1 + 16 + 4
  let ws = FixedArray::make((1 + 16) * (1 + 16 + 4), b'\x00')
  // A
  if mby == 0 {
    for i in 1..<stride {
      ws[i] = b'\x7f'
    }
  } else {
    for i in 0..<16 {
      ws[1 + i] = top[mbx * 16 + i]
    }
    if mbx == mbw - 1 {
      for i in 16..<(stride - 1) {
        ws[1 + i] = top[mbx * 16 + 15]
      }
    } else {
      for i in 16..<(stride - 1) {
        ws[1 + i] = top[mbx * 16 + i]
      }
    }
  }
  for i in 17..<stride {
    ws[4 * stride + i] = ws[i]
    ws[8 * stride + i] = ws[i]
    ws[12 * stride + i] = ws[i]
  }
  // L
  if mbx == 0 {
    for i in 0..<16 {
      ws[(i + 1) * stride] = b'\x81'
    }
  } else {
    for i in 0..<16 {
      ws[(i + 1) * stride] = left[1 + i]
    }
  }
  // P
  ws[0] = if mby == 0 { b'\x7f' } else if mbx == 0 { b'\x81' } else { left[0] }
  ws
}

///|
/// Creates the left and top border for chroma prediction.
fn create_border_chroma(
  mbx : Int,
  mby : Int,
  top : FixedArray[Byte],
  left : FixedArray[Byte],
) -> FixedArray[Byte] {
  let stride = 1 + 8
  let chroma_block = FixedArray::make(9 * 9, b'\x00')
  // above
  if mby == 0 {
    for i in 1..<stride {
      chroma_block[i] = b'\x7f'
    }
  } else {
    for i in 0..<8 {
      chroma_block[1 + i] = top[mbx * 8 + i]
    }
  }
  // left
  if mbx == 0 {
    for y in 0..<8 {
      chroma_block[(y + 1) * stride] = b'\x81'
    }
  } else {
    for y in 0..<8 {
      chroma_block[(y + 1) * stride] = left[1 + y]
    }
  }
  chroma_block[0] = if mby == 0 {
    b'\x7f'
  } else if mbx == 0 {
    b'\x81'
  } else {
    left[0]
  }
  chroma_block
}

///|
fn set_chroma_border(
  left_border : FixedArray[Byte],
  top_border : FixedArray[Byte],
  chroma_block : FixedArray[Byte],
  mbx : Int,
) -> Unit {
  let stride = 1 + 8
  // top left is top right of previous chroma block
  left_border[0] = chroma_block[8]
  // left border
  for i in 0..<8 {
    left_border[1 + i] = chroma_block[(i + 1) * stride + 8]
  }
  for i in 0..<8 {
    top_border[mbx * 8 + i] = chroma_block[8 * stride + 1 + i]
  }
}

///|
fn avg3(left : Byte, this : Byte, right : Byte) -> Byte {
  ((left.to_int() + 2 * this.to_int() + right.to_int() + 2) >> 2).to_byte()
}

///|
fn avg2(this : Byte, right : Byte) -> Byte {
  ((this.to_int() + right.to_int() + 1) >> 1).to_byte()
}

///|
/// Adds the residue `rblock[roff..roff + 16]` to the 4x4 block at
/// (`x0`, `y0`).
fn add_residue(
  pblock : FixedArray[Byte],
  rblock : FixedArray[Int],
  roff : Int,
  y0 : Int,
  x0 : Int,
  stride : Int,
) -> Unit {
  let mut pos = y0 * stride + x0
  for r in 0..<4 {
    for c in 0..<4 {
      let a = rblock[roff + r * 4 + c]
      pblock[pos + c] = clamp(a + pblock[pos + c].to_int(), 0, 255).to_byte()
    }
    pos += stride
  }
}

///|
fn predict_4x4(
  ws : FixedArray[Byte],
  stride : Int,
  modes : FixedArray[Int],
  resdata : FixedArray[Int],
) -> Unit {
  for sby in 0..<4 {
    for sbx in 0..<4 {
      let i = sbx + sby * 4
      let y0 = sby * 4 + 1
      let x0 = sbx * 4 + 1
      let mode = modes[i]
      if mode == b_tm_pred {
        predict_tmpred(ws, 4, x0, y0, stride)
      } else if mode == b_ve_pred {
        predict_bvepred(ws, x0, y0, stride)
      } else if mode == b_he_pred {
        predict_bhepred(ws, x0, y0, stride)
      } else if mode == b_dc_pred {
        predict_bdcpred(ws, x0, y0, stride)
      } else if mode == b_ld_pred {
        predict_bldpred(ws, x0, y0, stride)
      } else if mode == b_rd_pred {
        predict_brdpred(ws, x0, y0, stride)
      } else if mode == b_vr_pred {
        predict_bvrpred(ws, x0, y0, stride)
      } else if mode == b_vl_pred {
        predict_bvlpred(ws, x0, y0, stride)
      } else if mode == b_hd_pred {
        predict_bhdpred(ws, x0, y0, stride)
      } else {
        predict_bhupred(ws, x0, y0, stride)
      }
      add_residue(ws, resdata, i * 16, y0, x0, stride)
    }
  }
}

///|
/// This pass copies the top row to the rows below it (all `stride - 1`
/// columns after the first, like upstream's slice zip).
fn predict_vpred(
  a : FixedArray[Byte],
  size : Int,
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let above_len = stride * y0 - x0
  let n = if stride - 1 < above_len { stride - 1 } else { above_len }
  for r in 0..<size {
    let row = (y0 + r) * stride
    for i in 0..<n {
      a[row + 1 + i] = a[x0 + i]
    }
  }
}

///|
/// This pass copies the first value of a row to the values right of it.
fn predict_hpred(
  a : FixedArray[Byte],
  size : Int,
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  for r in 0..<size {
    let row = (y0 + r) * stride
    let left = a[row + x0 - 1]
    for i in x0..<stride {
      a[row + i] = left
    }
  }
}

///|
fn predict_dcpred(
  a : FixedArray[Byte],
  size : Int,
  stride : Int,
  above : Bool,
  left : Bool,
) -> Unit {
  let mut sum = 0
  let mut shf = if size == 8 { 2 } else { 3 }
  if left {
    for y in 0..<size {
      sum += a[(y + 1) * stride].to_int()
    }
    shf += 1
  }
  if above {
    for i in 1..<=size {
      sum += a[i].to_int()
    }
    shf += 1
  }
  let dcval = if !left && !above {
    128
  } else {
    (sum + (1 << (shf - 1))) >> shf
  }
  for y in 0..<size {
    for i in 0..<size {
      a[1 + stride * (y + 1) + i] = dcval.to_byte()
    }
  }
}

///|
fn predict_tmpred(
  a : FixedArray[Byte],
  size : Int,
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  // X_ij = L_i + A_j - P (RFC 6386, p. 52)
  let p = a[(y0 - 1) * stride + x0 - 1].to_int()
  let above = (y0 - 1) * stride + x0
  let base = y0 * stride + (x0 - 1)
  for y in 0..<size {
    let left_minus_p = a[base + y * stride].to_int() - p
    for i in 0..<size {
      a[base + y * stride + 1 + i] = clamp(
        left_minus_p + a[above + i].to_int(),
        0,
        255,
      ).to_byte()
    }
  }
}

///|
fn predict_bdcpred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let mut v = 4
  for i in 0..<4 {
    v += a[(y0 - 1) * stride + x0 + i].to_int()
  }
  for i in 0..<4 {
    v += a[(y0 + i) * stride + x0 - 1].to_int()
  }
  v = v >> 3
  for r in 0..<4 {
    for i in 0..<4 {
      a[(y0 + r) * stride + x0 + i] = v.to_byte()
    }
  }
}

///|
fn topleft_pixel(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Byte {
  a[(y0 - 1) * stride + x0 - 1]
}

///|
/// The 8 pixels above (`top_pixels`).
fn top_pixels(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> FixedArray[Byte] {
  let pos = (y0 - 1) * stride + x0
  FixedArray::makei(8, i => a[pos + i])
}

///|
/// The 4 pixels on the left (`left_pixels`).
fn left_pixels(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> FixedArray[Byte] {
  FixedArray::makei(4, i => a[(y0 + i) * stride + x0 - 1])
}

///|
/// The 9 edge pixels (`edge_pixels`): the left column bottom-up, the
/// top-left pixel and the 4 pixels above.
fn edge_pixels(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> FixedArray[Byte] {
  let pos = (y0 - 1) * stride + x0 - 1
  [
    a[pos + 4 * stride],
    a[pos + 3 * stride],
    a[pos + 2 * stride],
    a[pos + stride],
    a[pos],
    a[pos + 1],
    a[pos + 2],
    a[pos + 3],
    a[pos + 4],
  ]
}

///|
fn predict_bvepred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let p = topleft_pixel(a, x0, y0, stride)
  let t = top_pixels(a, x0, y0, stride)
  let avg = [
    avg3(p, t[0], t[1]),
    avg3(t[0], t[1], t[2]),
    avg3(t[1], t[2], t[3]),
    avg3(t[2], t[3], t[4]),
  ]
  let mut pos = y0 * stride + x0
  for _ in 0..<4 {
    for i in 0..<4 {
      a[pos + i] = avg[i]
    }
    pos += stride
  }
}

///|
fn predict_bhepred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let p = topleft_pixel(a, x0, y0, stride)
  let l = left_pixels(a, x0, y0, stride)
  let avgs = [
    avg3(p, l[0], l[1]),
    avg3(l[0], l[1], l[2]),
    avg3(l[1], l[2], l[3]),
    avg3(l[2], l[3], l[3]),
  ]
  let mut pos = y0 * stride + x0
  for avg in avgs {
    for i in 0..<4 {
      a[pos + i] = avg
    }
    pos += stride
  }
}

///|
fn predict_bldpred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let t = top_pixels(a, x0, y0, stride)
  let avgs = [
    avg3(t[0], t[1], t[2]),
    avg3(t[1], t[2], t[3]),
    avg3(t[2], t[3], t[4]),
    avg3(t[3], t[4], t[5]),
    avg3(t[4], t[5], t[6]),
    avg3(t[5], t[6], t[7]),
    avg3(t[6], t[7], t[7]),
  ]
  let mut pos = y0 * stride + x0
  for i in 0..<4 {
    for k in 0..<4 {
      a[pos + k] = avgs[i + k]
    }
    pos += stride
  }
}

///|
fn predict_brdpred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let e = edge_pixels(a, x0, y0, stride)
  let avgs = [
    avg3(e[0], e[1], e[2]),
    avg3(e[1], e[2], e[3]),
    avg3(e[2], e[3], e[4]),
    avg3(e[3], e[4], e[5]),
    avg3(e[4], e[5], e[6]),
    avg3(e[5], e[6], e[7]),
    avg3(e[6], e[7], e[8]),
  ]
  let mut pos = y0 * stride + x0
  for i in 0..<4 {
    for k in 0..<4 {
      a[pos + k] = avgs[3 - i + k]
    }
    pos += stride
  }
}

///|
fn predict_bvrpred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let e = edge_pixels(a, x0, y0, stride)
  let (e1, e2, e3, e4, e5, e6, e7, e8) = (
    e[1],
    e[2],
    e[3],
    e[4],
    e[5],
    e[6],
    e[7],
    e[8],
  )
  a[(y0 + 3) * stride + x0] = avg3(e1, e2, e3)
  a[(y0 + 2) * stride + x0] = avg3(e2, e3, e4)
  a[(y0 + 3) * stride + x0 + 1] = avg3(e3, e4, e5)
  a[(y0 + 1) * stride + x0] = avg3(e3, e4, e5)
  a[(y0 + 2) * stride + x0 + 1] = avg2(e4, e5)
  a[y0 * stride + x0] = avg2(e4, e5)
  a[(y0 + 3) * stride + x0 + 2] = avg3(e4, e5, e6)
  a[(y0 + 1) * stride + x0 + 1] = avg3(e4, e5, e6)
  a[(y0 + 2) * stride + x0 + 2] = avg2(e5, e6)
  a[y0 * stride + x0 + 1] = avg2(e5, e6)
  a[(y0 + 3) * stride + x0 + 3] = avg3(e5, e6, e7)
  a[(y0 + 1) * stride + x0 + 2] = avg3(e5, e6, e7)
  a[(y0 + 2) * stride + x0 + 3] = avg2(e6, e7)
  a[y0 * stride + x0 + 2] = avg2(e6, e7)
  a[(y0 + 1) * stride + x0 + 3] = avg3(e6, e7, e8)
  a[y0 * stride + x0 + 3] = avg2(e7, e8)
}

///|
fn predict_bvlpred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let t = top_pixels(a, x0, y0, stride)
  let (a0, a1, a2, a3, a4, a5, a6, a7) = (
    t[0],
    t[1],
    t[2],
    t[3],
    t[4],
    t[5],
    t[6],
    t[7],
  )
  a[y0 * stride + x0] = avg2(a0, a1)
  a[(y0 + 1) * stride + x0] = avg3(a0, a1, a2)
  a[(y0 + 2) * stride + x0] = avg2(a1, a2)
  a[y0 * stride + x0 + 1] = avg2(a1, a2)
  a[(y0 + 1) * stride + x0 + 1] = avg3(a1, a2, a3)
  a[(y0 + 3) * stride + x0] = avg3(a1, a2, a3)
  a[(y0 + 2) * stride + x0 + 1] = avg2(a2, a3)
  a[y0 * stride + x0 + 2] = avg2(a2, a3)
  a[(y0 + 3) * stride + x0 + 1] = avg3(a2, a3, a4)
  a[(y0 + 1) * stride + x0 + 2] = avg3(a2, a3, a4)
  a[(y0 + 2) * stride + x0 + 2] = avg2(a3, a4)
  a[y0 * stride + x0 + 3] = avg2(a3, a4)
  a[(y0 + 3) * stride + x0 + 2] = avg3(a3, a4, a5)
  a[(y0 + 1) * stride + x0 + 3] = avg3(a3, a4, a5)
  a[(y0 + 2) * stride + x0 + 3] = avg3(a4, a5, a6)
  a[(y0 + 3) * stride + x0 + 3] = avg3(a5, a6, a7)
}

///|
fn predict_bhdpred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let e = edge_pixels(a, x0, y0, stride)
  let (e0, e1, e2, e3, e4, e5, e6, e7) = (
    e[0],
    e[1],
    e[2],
    e[3],
    e[4],
    e[5],
    e[6],
    e[7],
  )
  a[(y0 + 3) * stride + x0] = avg2(e0, e1)
  a[(y0 + 3) * stride + x0 + 1] = avg3(e0, e1, e2)
  a[(y0 + 2) * stride + x0] = avg2(e1, e2)
  a[(y0 + 3) * stride + x0 + 2] = avg2(e1, e2)
  a[(y0 + 2) * stride + x0 + 1] = avg3(e1, e2, e3)
  a[(y0 + 3) * stride + x0 + 3] = avg3(e1, e2, e3)
  a[(y0 + 2) * stride + x0 + 2] = avg2(e2, e3)
  a[(y0 + 1) * stride + x0] = avg2(e2, e3)
  a[(y0 + 2) * stride + x0 + 3] = avg3(e2, e3, e4)
  a[(y0 + 1) * stride + x0 + 1] = avg3(e2, e3, e4)
  a[(y0 + 1) * stride + x0 + 2] = avg2(e3, e4)
  a[y0 * stride + x0] = avg2(e3, e4)
  a[(y0 + 1) * stride + x0 + 3] = avg3(e3, e4, e5)
  a[y0 * stride + x0 + 1] = avg3(e3, e4, e5)
  a[y0 * stride + x0 + 2] = avg3(e4, e5, e6)
  a[y0 * stride + x0 + 3] = avg3(e5, e6, e7)
}

///|
fn predict_bhupred(
  a : FixedArray[Byte],
  x0 : Int,
  y0 : Int,
  stride : Int,
) -> Unit {
  let l = left_pixels(a, x0, y0, stride)
  let (l0, l1, l2, l3) = (l[0], l[1], l[2], l[3])
  a[y0 * stride + x0] = avg2(l0, l1)
  a[y0 * stride + x0 + 1] = avg3(l0, l1, l2)
  a[y0 * stride + x0 + 2] = avg2(l1, l2)
  a[(y0 + 1) * stride + x0] = avg2(l1, l2)
  a[y0 * stride + x0 + 3] = avg3(l1, l2, l3)
  a[(y0 + 1) * stride + x0 + 1] = avg3(l1, l2, l3)
  a[(y0 + 1) * stride + x0 + 2] = avg2(l2, l3)
  a[(y0 + 2) * stride + x0] = avg2(l2, l3)
  a[(y0 + 1) * stride + x0 + 3] = avg3(l2, l3, l3)
  a[(y0 + 2) * stride + x0 + 1] = avg3(l2, l3, l3)
  a[(y0 + 2) * stride + x0 + 2] = l3
  a[(y0 + 2) * stride + x0 + 3] = l3
  a[(y0 + 3) * stride + x0] = l3
  a[(y0 + 3) * stride + x0 + 1] = l3
  a[(y0 + 3) * stride + x0 + 2] = l3
  a[(y0 + 3) * stride + x0 + 3] = l3
}
