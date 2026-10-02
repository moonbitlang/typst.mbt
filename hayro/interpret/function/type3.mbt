// Port of `hayro-interpret/src/function/type3.rs`.

///|
/// A type 3 function (stitching function).
priv struct Type3 {
  functions : Array[Function]
  bounds : Array[Float]
  encode : Array[(Float, Float)]
  clamper : Clamper
}

///|
/// Create a new type 3 function.
fn Type3::new(dict : @hayro_syntax.Dict) -> Type3? {
  guard Clamper::new(dict) is Some(clamper) else { return None }
  guard (dict.get("Functions") : @hayro_syntax.PdfArray?) is Some(d) else {
    return None
  }
  let functions = []
  for o in (d.iter() : Iter[@hayro_syntax.Object]) {
    guard Function::new(o) is Some(f) else { return None }
    functions.push(f)
  }
  guard clamper.domain.get(0) is Some(domain) else { return None }
  let bounds : Array[Float] = [domain.0 - 0.0001]
  if (dict.get("Bounds") : @hayro_syntax.PdfArray?) is Some(a) {
    for b in (a.iter() : Iter[Float]) {
      bounds.push(b)
    }
  }
  // Add a small delta so that the interval is considered to be closed on the right.
  bounds.push(domain.1 + 0.0001)
  guard get_tuple_vec(dict, "Encode") is Some(encode) else { return None }
  Some({ functions, clamper, bounds, encode, })
}

///|
/// Evaluate the function with the given input.
fn Type3::eval(self : Type3, input : Float) -> Array[Float]? {
  let input = [input]
  self.clamper.clamp_input(input)
  guard find_interval(self.bounds, input[0]) is Some(index) else { return None }
  guard self.bounds.get(index + 1) is Some(bounds_i) else { return None }
  guard self.bounds.get(index) is Some(bounds_i_minus_1) else { return None }

  // - 1 because we inserted a dummy bound in the constructor.
  guard self.encode.get(index) is Some(encoding) else { return None }
  guard self.functions.get(index) is Some(function) else { return None }
  let encoded = interpolate(
    input[0],
    bounds_i_minus_1,
    bounds_i,
    encoding.0,
    encoding.1,
  )
  guard function.eval([encoded]) is Some(evaluated) else { return None }
  self.clamper.clamp_output(evaluated)
  Some(evaluated)
}

///|
fn Type3::stitching_bounds(self : Type3) -> Array[Float] {
  let stitching_bounds = []
  if self.bounds.length() > 2 {
    for i in 1..<(self.bounds.length() - 1) {
      stitching_bounds.push(self.bounds[i])
    }
  }
  for index, function in self.functions {
    guard self.bounds.get(index) is Some(bounds_i_minus_1) else { continue }
    guard self.bounds.get(index + 1) is Some(bounds_i) else { continue }
    guard self.encode.get(index) is Some((encode_min, encode_max)) else {
      continue
    }
    if (encode_max - encode_min).abs() <= f32_epsilon {
      continue
    }
    for child_bound in function.stitching_bounds() {
      let bound = interpolate(
        child_bound, encode_min, encode_max, bounds_i_minus_1, bounds_i,
      )
      let min_bound = f32_min(bounds_i_minus_1, bounds_i)
      let max_bound = f32_max(bounds_i_minus_1, bounds_i)
      if bound > min_bound && bound < max_bound {
        stitching_bounds.push(bound)
      }
    }
  }

  // `sort_by(f32::total_cmp)`: values with equal keys are bitwise identical,
  // so the (unstable) sort gives the same result.
  stitching_bounds.sort_by((a, b) => total_cmp_key(a).compare(total_cmp_key(b)))
  // `dedup_by(|a, b| (*a - *b).abs() <= f32::EPSILON)`.
  let deduped = []
  for b in stitching_bounds {
    match deduped.last() {
      Some(last) if (b - last).abs() <= f32_epsilon => ()
      _ => deduped.push(b)
    }
  }
  deduped
}

///|
let f32_epsilon : Float = Float::reinterpret_from_uint(0x34000000)

///|
/// The key of `f32::total_cmp`.
fn total_cmp_key(x : Float) -> Int {
  let left = x.reinterpret_as_int()
  left ^ ((left >> 31).reinterpret_as_uint() >> 1).reinterpret_as_int()
}

///|
fn find_interval(bounds : Array[Float], x : Float) -> Int? {
  guard bounds.get(0) is Some(first) else { return None }
  guard bounds.last() is Some(last) else { return None }
  if x < first || x >= last {
    return None
  }

  // `bounds.binary_search_by(|val| if *val <= x { Less } else { Greater })`,
  // which never finds an element and returns the partition point.
  let mut size = bounds.length()
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    if bounds[mid] <= x {
      base = mid
    }
    size -= half
  }
  let i = if bounds[base] <= x { base + 1 } else { base }
  // `i - 1` (`usize`): an underflow makes the lookups in `eval` fail.
  if i == 0 {
    None
  } else {
    Some(i - 1)
  }
}
