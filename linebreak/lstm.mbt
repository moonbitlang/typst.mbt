// Port of `icu_segmenter 2.3.0`: `complex/lstm/mod.rs` and
// `complex/lstm/matrix.rs` (LSTM inference over the baked
// `SegmenterLstmAutoV1` models, see `lstm_gen.mbt`). The arithmetic is done
// in `Float` (f32) in exactly the upstream order.

///|
/// A matrix of f32 values (`MatrixZero` / `MatrixOwned`), row-major.
priv struct Matrix {
  data : FixedArray[Float]
  dims : FixedArray[Int]
}

///|
fn Matrix::from_base64(b64 : String, dims : FixedArray[Int]) -> Matrix {
  let bytes = decode_base64(b64)
  let n = bytes.length() / 4
  let data = FixedArray::make(n, (0.0 : Float))
  for i in 0..<n {
    let b = i * 4
    let bits = bytes[b].to_uint() |
      (bytes[b + 1].to_uint() << 8) |
      (bytes[b + 2].to_uint() << 16) |
      (bytes[b + 3].to_uint() << 24)
    data[i] = Float::reinterpret_from_uint(bits)
  }
  { data, dims, }
}

///|
/// The size of a submatrix (product of all but the first dimension).
fn Matrix::stride(self : Matrix) -> Int {
  let mut n = 1
  for k in 1..<self.dims.length() {
    n *= self.dims[k]
  }
  n
}

///|
/// Submatrix `index` of a matrix (sharing the data).
fn Matrix::submatrix(self : Matrix, index : Int) -> Matrix {
  let n = self.stride()
  let data = FixedArray::make(n, (0.0 : Float))
  for i in 0..<n {
    data[i] = self.data[n * index + i]
  }
  {
    data,
    dims: FixedArray::makei(self.dims.length() - 1, k => self.dims[k + 1]),
  }
}

///|
/// A word break segmenter using an LSTM model. Input strings have to be of
/// the same complex script.
priv struct LstmSegmenter {
  dic : Map[String, Int]
  dic_len : Int
  grapheme_clusters : Bool
  embedding : Matrix
  fw_w : Matrix
  fw_u : Matrix
  fw_b : Matrix
  bw_w : Matrix
  bw_u : Matrix
  bw_b : Matrix
  timew_fw : Matrix
  timew_bw : Matrix
  time_b : Matrix
}

///|
fn LstmSegmenter::new(
  model_type : String,
  dic : FixedArray[(String, Int)],
  matrices : FixedArray[(String, FixedArray[Int])],
) -> LstmSegmenter {
  let m = matrices.map(p => Matrix::from_base64(p.0, p.1))
  let map : Map[String, Int] = Map([])
  for entry in dic {
    map[entry.0] = entry.1
  }
  let time_w = m[7]
  {
    dic: map,
    dic_len: dic.length(),
    grapheme_clusters: model_type == "GraphemeClusters",
    embedding: m[0],
    fw_w: m[1],
    fw_u: m[2],
    fw_b: m[3],
    bw_w: m[4],
    bw_u: m[5],
    bw_b: m[6],
    timew_fw: time_w.submatrix(0),
    timew_bw: time_w.submatrix(1),
    time_b: m[8],
  }
}

///|
/// Create an LSTM based break iterator for a sequence of code points; returns
/// the UTF-8 byte offsets of the breaks.
fn LstmSegmenter::segment_str(
  self : LstmSegmenter,
  input : ArrayView[Int],
) -> Array[Int] {
  if self.grapheme_clusters {
    // None of the baked models uses grapheme clusters.
    abort("grapheme cluster LSTM models are not supported")
  }
  let input_seq = input.map(c => {
    let s = Int::unsafe_to_char(c).to_string()
    match self.dic.get(s) {
      Some(id) => id
      None => self.dic_len
    }
  })
  let bies = BiesIterator::new(self, input_seq)
  // LstmSegmenterIterator::next
  let out = []
  let mut idx = 0
  let mut k = 0
  while true {
    let is_e = match bies.next() {
      Some(e) => e
      None => break
    }
    if k >= input.length() {
      break
    }
    let ch = input[k]
    k += 1
    let pos = idx
    idx += utf8_len(ch)
    if is_e || bies.remaining() == 0 {
      out.push(pos + utf8_len(ch))
    }
  }
  out
}

///|
priv struct BiesIterator {
  model : LstmSegmenter
  input_seq : Array[Int]
  mut pos : Int
  h_bw : FixedArray[Float]
  curr_fw : FixedArray[Float]
  c_fw : FixedArray[Float]
  hunits : Int
}

///|
// input_seq is a sequence of id numbers that represents grapheme clusters or code points in the input line. These ids are used later
// in the embedding layer of the model.
fn BiesIterator::new(
  model : LstmSegmenter,
  input_seq : Array[Int],
) -> BiesIterator {
  let hunits = model.fw_u.dims[1]
  let n = input_seq.length()

  // Backward LSTM
  let c_bw = FixedArray::make(hunits, (0.0 : Float))
  let h_bw = FixedArray::make(n * hunits, (0.0 : Float))
  for i = n - 1; i >= 0; i = i - 1 {
    let g_id = input_seq[i]
    if i + 1 < n {
      // copy_submatrix(i + 1, i)
      for j in 0..<hunits {
        h_bw[i * hunits + j] = h_bw[(i + 1) * hunits + j]
      }
    }
    compute_hc(
      model.embedding,
      g_id,
      h_bw,
      i * hunits,
      c_bw,
      model.bw_w,
      model.bw_u,
      model.bw_b,
    )
  }
  {
    model,
    input_seq,
    pos: 0,
    h_bw,
    c_fw: FixedArray::make(hunits, (0.0 : Float)),
    curr_fw: FixedArray::make(hunits, (0.0 : Float)),
    hunits,
  }
}

///|
fn BiesIterator::remaining(self : BiesIterator) -> Int {
  self.input_seq.length() - self.pos
}

///|
fn BiesIterator::next(self : BiesIterator) -> Bool? {
  if self.pos >= self.input_seq.length() {
    return None
  }
  let i = self.pos
  let g_id = self.input_seq[i]
  self.pos += 1
  let m = self.model
  compute_hc(
    m.embedding,
    g_id,
    self.curr_fw,
    0,
    self.c_fw,
    m.fw_w,
    m.fw_u,
    m.fw_b,
  )
  let h = self.hunits
  let weights = FixedArray::make(4, (0.0 : Float))
  // curr_est.add_dot_2d(self.curr_fw, self.timew_fw)
  for k in 0..<4 {
    weights[k] = weights[k] +
      unrolled_dot(self.curr_fw, 0, m.timew_fw.data, k * h, h)
  }
  // curr_est.add_dot_2d(curr_bw, self.timew_bw)
  for k in 0..<4 {
    weights[k] = weights[k] +
      unrolled_dot(self.h_bw, i * h, m.timew_bw.data, k * h, h)
  }
  // curr_est.add(self.time_b)
  for k in 0..<4 {
    weights[k] = weights[k] + m.time_b.data[k]
  }
  // For correct BIES weight calculation we'd now have to apply softmax, however
  // we're only doing a naive argmax, so a monotonic function doesn't make a difference.
  Some(
    weights[2] > weights[0] &&
    weights[2] > weights[1] &&
    weights[2] > weights[3],
  )
}

///|
/// `compute_hc` implements the evaluation of one LSTM layer. `h_tm1` is the
/// row of `h` starting at `h_at`.
fn compute_hc(
  embedding : Matrix,
  g_id : Int,
  h : FixedArray[Float],
  h_at : Int,
  c_tm1 : FixedArray[Float],
  w : Matrix,
  u : Matrix,
  b : Matrix,
) -> Unit {
  let hunits = c_tm1.length()
  let embedd_dim = embedding.dims[1]
  let x_at = g_id * embedd_dim
  let n = 4 * hunits
  let s_t = FixedArray::make(n, (0.0 : Float))
  for i in 0..<n {
    s_t[i] = b.data[i]
  }
  // s_t.add_dot_3d_2(x_t, w)
  for i in 0..<n {
    s_t[i] = s_t[i] +
      unrolled_dot(embedding.data, x_at, w.data, i * embedd_dim, embedd_dim)
  }
  // s_t.add_dot_3d_1(h_tm1, u)
  for i in 0..<n {
    s_t[i] = s_t[i] + unrolled_dot(h, h_at, u.data, i * hunits, hunits)
  }
  for i in 0..<hunits {
    s_t[i] = sigmoid(s_t[i])
    s_t[hunits + i] = sigmoid(s_t[hunits + i])
    s_t[2 * hunits + i] = tanhf(s_t[2 * hunits + i])
    s_t[3 * hunits + i] = sigmoid(s_t[3 * hunits + i])
  }
  // c_tm1.convolve(i = s_t[0], c = s_t[2], f = s_t[1])
  for idx in 0..<hunits {
    c_tm1[idx] = s_t[idx] * s_t[2 * hunits + idx] +
      c_tm1[idx] * s_t[hunits + idx]
  }
  // h_tm1.mul_tanh(o = s_t[3], c_tm1)
  for idx in 0..<hunits {
    h[h_at + idx] = s_t[3 * hunits + idx] * tanhf(c_tm1[idx])
  }
}

///|
fn sigmoid(x : Float) -> Float {
  (1.0 : Float) / ((1.0 : Float) + expf(-x))
}

///|
/// `unrolled_dot_1` / `unrolled_dot_2`: eightfold unrolled dot product of
/// `xs[xa:xa+len]` and `ys[ya:ya+len]`.
fn unrolled_dot(
  xs : FixedArray[Float],
  xa : Int,
  ys : FixedArray[Float],
  ya : Int,
  len : Int,
) -> Float {
  let chunks = len / 8
  let rem = chunks * 8
  // `Sum for f32` starts at -0.0.
  let mut sum : Float = -0.0
  for k in rem..<len {
    sum = sum + xs[xa + k] * ys[ya + k]
  }
  let mut p0 : Float = 0.0
  let mut p1 : Float = 0.0
  let mut p2 : Float = 0.0
  let mut p3 : Float = 0.0
  let mut p4 : Float = 0.0
  let mut p5 : Float = 0.0
  let mut p6 : Float = 0.0
  let mut p7 : Float = 0.0
  for c in 0..<chunks {
    let x = xa + c * 8
    let y = ya + c * 8
    p0 = p0 + xs[x] * ys[y]
    p1 = p1 + xs[x + 1] * ys[y + 1]
    p2 = p2 + xs[x + 2] * ys[y + 2]
    p3 = p3 + xs[x + 3] * ys[y + 3]
    p4 = p4 + xs[x + 4] * ys[y + 4]
    p5 = p5 + xs[x + 5] * ys[y + 5]
    p6 = p6 + xs[x + 6] * ys[y + 6]
    p7 = p7 + xs[x + 7] * ys[y + 7]
  }
  sum + (p0 + p4) + (p1 + p5) + (p2 + p6) + (p3 + p7)
}

///|
/// A lazily loaded model.
priv struct LazyModel {
  load : () -> LstmSegmenter
  mut value : LstmSegmenter?
}

///|
fn LazyModel::get(self : LazyModel) -> LstmSegmenter {
  match self.value {
    Some(v) => v
    None => {
      let v = (self.load)()
      self.value = Some(v)
      v
    }
  }
}

///|
let lstm_burmese : LazyModel = {
  load: () => {
    LstmSegmenter::new(burmese_model_type, burmese_dic, [
      (burmese_embedding_data, burmese_embedding_dims),
      (burmese_fw_w_data, burmese_fw_w_dims),
      (burmese_fw_u_data, burmese_fw_u_dims),
      (burmese_fw_b_data, burmese_fw_b_dims),
      (burmese_bw_w_data, burmese_bw_w_dims),
      (burmese_bw_u_data, burmese_bw_u_dims),
      (burmese_bw_b_data, burmese_bw_b_dims),
      (burmese_time_w_data, burmese_time_w_dims),
      (burmese_time_b_data, burmese_time_b_dims),
    ])
  },
  value: None,
}

///|
let lstm_khmer : LazyModel = {
  load: () => {
    LstmSegmenter::new(khmer_model_type, khmer_dic, [
      (khmer_embedding_data, khmer_embedding_dims),
      (khmer_fw_w_data, khmer_fw_w_dims),
      (khmer_fw_u_data, khmer_fw_u_dims),
      (khmer_fw_b_data, khmer_fw_b_dims),
      (khmer_bw_w_data, khmer_bw_w_dims),
      (khmer_bw_u_data, khmer_bw_u_dims),
      (khmer_bw_b_data, khmer_bw_b_dims),
      (khmer_time_w_data, khmer_time_w_dims),
      (khmer_time_b_data, khmer_time_b_dims),
    ])
  },
  value: None,
}

///|
let lstm_lao : LazyModel = {
  load: () => {
    LstmSegmenter::new(lao_model_type, lao_dic, [
      (lao_embedding_data, lao_embedding_dims),
      (lao_fw_w_data, lao_fw_w_dims),
      (lao_fw_u_data, lao_fw_u_dims),
      (lao_fw_b_data, lao_fw_b_dims),
      (lao_bw_w_data, lao_bw_w_dims),
      (lao_bw_u_data, lao_bw_u_dims),
      (lao_bw_b_data, lao_bw_b_dims),
      (lao_time_w_data, lao_time_w_dims),
      (lao_time_b_data, lao_time_b_dims),
    ])
  },
  value: None,
}

///|
let lstm_thai : LazyModel = {
  load: () => {
    LstmSegmenter::new(thai_model_type, thai_dic, [
      (thai_embedding_data, thai_embedding_dims),
      (thai_fw_w_data, thai_fw_w_dims),
      (thai_fw_u_data, thai_fw_u_dims),
      (thai_fw_b_data, thai_fw_b_dims),
      (thai_bw_w_data, thai_bw_w_dims),
      (thai_bw_u_data, thai_bw_u_dims),
      (thai_bw_b_data, thai_bw_b_dims),
      (thai_time_w_data, thai_time_w_dims),
      (thai_time_b_data, thai_time_b_dims),
    ])
  },
  value: None,
}

///|
/// Decode base64 data, ignoring newlines.
fn decode_base64(s : String) -> Bytes {
  fn value(c : Int) -> Int {
    if c >= 'A' && c <= 'Z' {
      c - 'A'
    } else if c >= 'a' && c <= 'z' {
      c - 'a' + 26
    } else if c >= '0' && c <= '9' {
      c - '0' + 52
    } else if c == '+' {
      62
    } else if c == '/' {
      63
    } else {
      -1
    }
  }

  let out = FixedArray::make(s.length() / 4 * 3 + 3, b'\x00')
  let mut len = 0
  let mut acc = 0
  let mut bits = 0
  for i in 0..<s.length() {
    let v = value(s.code_unit_at(i).to_int())
    if v < 0 {
      continue
    }
    acc = ((acc << 6) | v) & 0xFFFFFF
    bits += 6
    if bits >= 8 {
      bits -= 8
      out[len] = ((acc >> bits) & 0xFF).to_byte()
      len += 1
    }
  }
  Bytes::from_fixedarray(out, len~)
}
