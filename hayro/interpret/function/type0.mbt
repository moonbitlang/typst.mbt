// Port of `hayro-interpret/src/function/type0.rs`.

///|
/// A type 0 function (sampled function).
priv struct Type0 {
  sizes : Array[UInt]
  table : Map[Key, Array[UInt]]
  clamper : Clamper
  range : Array[(Float, Float)]
  bits_per_sample : Int
  encode : Array[(Float, Float)]
  decode : Array[(Float, Float)]
}

///|
/// Create a new type 0 function.
fn Type0::new(stream : @hayro_syntax.Stream) -> Type0? {
  let dict = stream.dict()
  guard (dict.get("BitsPerSample") : Byte?) is Some(bits_per_sample) else {
    return None
  }
  let bits_per_sample = bits_per_sample.to_int()
  if !(bits_per_sample is (1 | 2 | 4 | 8 | 16 | 24 | 32)) {
    // invalid bits per sample
    return None
  }
  guard Clamper::new(dict) is Some(clamper) else { return None }
  guard clamper.range is Some(range) else { return None }
  if range.length() == 0 {
    // encountered Type0 function with invalid range length 0.
    return None
  }
  guard (dict.get("Size") : @hayro_syntax.PdfArray?) is Some(size_array) else {
    return None
  }
  let sizes : Array[UInt] = size_array.iter().collect()
  let encode = match get_tuple_vec(dict, "Encode") {
    Some(e) => e
    None => sizes.map(s => (0.0, Float::from_uint(s - 1)))
  }
  let decode = match get_tuple_vec(dict, "Decode") {
    Some(d) => d
    None => range
  }
  guard stream.decoded() is Ok(decoded) else { return None }
  let data = []
  let reader = @hayro_syntax.BitReader::new(decoded)
  while reader.read(bits_per_sample) is Some(d) {
    data.push(d)
  }

  // `usize` arithmetic (wrapping).
  let mut num_expected_entries = 1UL
  for s in sizes {
    num_expected_entries = num_expected_entries * s.to_uint64()
  }
  num_expected_entries = num_expected_entries * range.length().to_uint64()
  if data.length().to_uint64() != num_expected_entries {
    // Type0 function didn't have the expected number of sample entries.
    if num_expected_entries < data.length().to_uint64() {
      data.truncate(num_expected_entries.to_int())
    }
  }
  let table = build_table(data, sizes, range.length())
  Some({ sizes, clamper, range, bits_per_sample, table, encode, decode, })
}

///|
/// Evaluate a type 0 function with the given input.
fn Type0::eval(self : Type0, input : Array[Float]) -> Array[Float]? {
  if input.length() != self.sizes.length() {
    // wrong number of arguments for sampled function
    return None
  }
  self.clamper.clamp_input(input)
  let key = input
  let n = @cmp.minimum(
    @cmp.minimum(key.length(), self.clamper.domain.length()),
    @cmp.minimum(self.encode.length(), self.sizes.length()),
  )
  for i in 0..<n {
    let domain = self.clamper.domain[i]
    let encode = self.encode[i]
    let size = self.sizes[i]
    let x = interpolate(key[i], domain.0, domain.1, encode.0, encode.1)
    key[i] = f32_min(f32_max(x, 0.0), Float::from_uint(size) - 1.0)
  }
  let in_prev = key.map(v => f32_to_u32(v.floor()))
  let in_next = key.map(v => f32_to_u32(v.ceil()))
  let interpolator = Interpolator::new(
    key.copy(),
    in_prev,
    in_next,
    self.sizes,
    self.range.length(),
  )
  guard interpolator.interpolate(self.table) is Some(interpolated) else {
    return None
  }
  let max = Float::from_uint(((1UL << self.bits_per_sample) - 1UL).to_uint())
  let out = []
  let n = @cmp.minimum(interpolated.length(), self.decode.length())
  for i in 0..<n {
    let decode = self.decode[i]
    out.push(interpolate(interpolated[i], 0.0, max, decode.0, decode.1))
  }
  self.clamper.clamp_output(out)
  Some(out)
}

///|
// See <https://github.com/apache/pdfbox/blob/bb778d4784f354c36ce032e91a0cee2169a4c598/pdfbox/src/main/java/org/apache/pdfbox/pdmodel/common/function/PDFunctionType0.java#L252>
priv struct Interpolator {
  input : Array[Float]
  sizes : Array[UInt]
  in_prev : Array[UInt]
  in_next : Array[UInt]
  out_len : Int
}

///|
fn Interpolator::new(
  input : Array[Float],
  in_prev : Array[UInt],
  in_next : Array[UInt],
  sizes : Array[UInt],
  out_len : Int,
) -> Interpolator {
  { input, in_prev, in_next, sizes, out_len, }
}

///|
fn Interpolator::interpolate(
  self : Interpolator,
  table : Map[Key, Array[UInt]],
) -> Array[Float]? {
  // Upstream panics (index out of bounds) for a function without inputs.
  if self.input.length() == 0 {
    return None
  }
  self.interpolate_inner(Array::make(self.input.length(), 0U), 0, table)
}

///|
fn Interpolator::interpolate_inner(
  self : Interpolator,
  coord : Array[UInt],
  step : Int,
  table : Map[Key, Array[UInt]],
) -> Array[Float]? {
  if step == self.input.length() - 1 {
    if self.in_prev[step] == self.in_next[step] {
      coord[step] = self.in_prev[step]
      guard table.get(Key::from_raw(self.sizes, coord)) is Some(v) else {
        return None
      }
      Some(v.map(n => Float::from_uint(n)))
    } else {
      coord[step] = self.in_prev[step]
      guard table.get(Key::from_raw(self.sizes, coord)) is Some(val1) else {
        return None
      }
      coord[step] = self.in_next[step]
      guard table.get(Key::from_raw(self.sizes, coord)) is Some(val2) else {
        return None
      }
      let out = Array::make(self.out_len, (0.0 : Float))
      for i in 0..<self.out_len {
        out[i] = interpolate(
          self.input[step],
          Float::from_uint(self.in_prev[step]),
          Float::from_uint(self.in_next[step]),
          Float::from_uint(val1[i]),
          Float::from_uint(val2[i]),
        )
      }
      Some(out)
    }
  } else if self.in_prev[step] == self.in_next[step] {
    coord[step] = self.in_prev[step]
    self.interpolate_inner(coord, step + 1, table)
  } else {
    coord[step] = self.in_prev[step]
    guard self.interpolate_inner(coord.copy(), step + 1, table) is Some(val1) else {
      return None
    }
    coord[step] = self.in_next[step]
    guard self.interpolate_inner(coord, step + 1, table) is Some(val2) else {
      return None
    }
    let out = Array::make(self.out_len, (0.0 : Float))
    for i in 0..<self.out_len {
      out[i] = interpolate(
        self.input[step],
        Float::from_uint(self.in_prev[step]),
        Float::from_uint(self.in_next[step]),
        val1[i],
        val2[i],
      )
    }
    Some(out)
  }
}

///|
fn build_table(
  data : Array[UInt],
  sizes : Array[UInt],
  n : Int,
) -> Map[Key, Array[UInt]] {
  let key = Key::new(sizes)
  let table = Map([])
  let mut first = true
  // `data.chunks_exact(n)`.
  let mut i = 0
  while i + n <= data.length() {
    if !first {
      key.increment() |> ignore
    }
    table[key.copy()] = data[i:i + n].to_owned()
    first = false
    i += n
  }
  table
}

///|
/// A sampled function consists of a (possibly) multi-dimensional table that
/// we can index into. We do this by representing the entries as a flat list
/// of vectors, where each element in the vector represents the value of the
/// key in that specific dimension. (The sizes, which upstream also stores in
/// the key, are the same for all keys of a table.)
priv struct Key {
  sizes : Array[UInt]
  parts : Array[UInt]
}

///|
impl Eq for Key with fn equal(a, b) {
  a.parts == b.parts
}

///|
impl Hash for Key with fn hash_combine(self, hasher) {
  Hash::hash_combine(self.parts, hasher)
}

///|
fn Key::new(sizes : Array[UInt]) -> Key {
  { sizes, parts: Array::make(sizes.length(), 0U), }
}

///|
fn Key::from_raw(sizes : Array[UInt], parts : Array[UInt]) -> Key {
  { sizes, parts: parts.copy(), }
}

///|
fn Key::copy(self : Key) -> Key {
  { sizes: self.sizes, parts: self.parts.copy(), }
}

///|
fn Key::increment(self : Key) -> Unit? {
  self.increment_index(0)
}

///|
fn Key::increment_index(self : Key, index : Int) -> Unit? {
  guard self.sizes.get(index) is Some(size) else {
    // overflowed key in sampled function
    return None
  }
  guard self.parts.get(index) is Some(val) else { return None }
  // `size - 1` wraps for a size of 0.
  if val >= size - 1 {
    self.parts[index] = 0
    guard self.increment_index(index + 1) is Some(_) else { return None }
  } else {
    self.parts[index] = val + 1
  }
  Some(())
}
