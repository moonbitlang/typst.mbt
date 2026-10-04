// Port of `zune-jpeg` (v0.5.15) `src/upsampler.rs` and
// `src/upsampler/scalar.rs`: the triangle-filter ("fancy") up-sampling.
//
// On aarch64 upstream uses the NEON horizontal/vertical/hv up-samplers;
// they evaluate the same `(3 * a + b + 2) >> 2` filter for every output
// sample as the scalar code (re-computing a few samples in an overlapping
// tail), so the scalar code is ported. The generic (nearest neighbour)
// sampler is scalar on every platform.
//
// Slices are passed as (array, offset, length).

///|
priv struct Slice {
  arr : FixedArray[Int]
  off : Int
  len : Int
}

///|
fn Slice::of(arr : FixedArray[Int]) -> Slice {
  { arr, off: 0, len: arr.length(), }
}

///|
fn Slice::at(self : Slice, i : Int) -> Int {
  self.arr[self.off + i]
}

///|
fn Slice::set(self : Slice, i : Int, v : Int) -> Unit {
  self.arr[self.off + i] = v
}

///|
fn Slice::sub(self : Slice, start : Int, end : Int) -> Slice {
  { arr: self.arr, off: self.off + start, len: end - start, }
}

///|
/// Call the up-sampler of a component.
fn run_upsampler(
  kind : UpSampler,
  input : Slice,
  in_near : Slice,
  in_far : Slice,
  scratch : FixedArray[Int],
  output : Slice,
) -> Unit raise DecodeErrors {
  match kind {
    NoOp => ()
    Horizontal => upsample_horizontal(input, output)
    Vertical => upsample_vertical(input, in_near, in_far, output)
    HorizontalVertical => upsample_hv(input, in_near, in_far, scratch, output)
    Generic => upsample_generic(input, output)
  }
}

///|
fn upsample_horizontal(
  input : Slice,
  output : Slice,
) -> Unit raise DecodeErrors {
  if input.len * 2 != output.len || !(output.len > 4 && input.len > 2) {
    raise Panic("upsample_horizontal: assertion failed")
  }
  output.set(0, input.at(0))
  output.set(1, (input.at(0) * 3 + input.at(1) + 2) >> 2)
  // The readable code is
  //      for i in 1..input.len() - 1{
  //         let sample = 3 * input[i] + 2;
  //         out[i * 2] = (sample + input[i - 1]) >> 2;
  //         out[i * 2 + 1] = (sample + input[i + 1]) >> 2;
  //     }
  let n = @cmp.minimum((output.len - 2) / 2, input.len - 2)
  upsample_horizontal_core(input, output, n)
  // Get lengths
  let out_len = output.len - 2
  let input_len = input.len - 2
  // write out manually..
  output.set(
    out_len,
    (3 * input.at(input_len + 1) + input.at(input_len) + 2) >> 2,
  )
  output.set(out_len + 1, input.at(input_len + 1))
}

///|
fn upsample_vertical(
  input : Slice,
  in_near : Slice,
  in_far : Slice,
  output : Slice,
) -> Unit raise DecodeErrors {
  if input.len * 2 != output.len ||
    in_near.len != input.len ||
    in_far.len != input.len {
    raise Panic("upsample_vertical: assertion failed")
  }
  let middle = output.len / 2
  // for the first row, closest row is in_near
  let n = @cmp.minimum(input.len, @cmp.minimum(in_near.len, middle))
  upsample_vertical_core(input, in_near, output, 0, n)
  // for the second row, the closest row to input is in_far
  let n = @cmp.minimum(input.len, @cmp.minimum(in_far.len, output.len - middle))
  upsample_vertical_core(input, in_far, output, middle, n)
}

///|
fn upsample_hv(
  input : Slice,
  in_near : Slice,
  in_far : Slice,
  scratch_space : FixedArray[Int],
  output : Slice,
) -> Unit raise DecodeErrors {
  if input.len * 4 != output.len || input.len * 2 > scratch_space.length() {
    raise Panic("upsample_hv: assertion failed")
  }
  let scratch : Slice = { arr: scratch_space, off: 0, len: input.len * 2, }
  upsample_vertical(input, in_near, in_far, scratch)
  // horizontal upsampling must be done separate for every line
  let scratch_half = scratch.len / 2
  let output_half = output.len / 2
  upsample_horizontal(scratch.sub(0, scratch_half), output.sub(0, output_half))
  upsample_horizontal(
    scratch.sub(scratch_half, scratch.len),
    output.sub(output_half, output.len),
  )
}

///|
fn upsample_generic(input : Slice, output : Slice) -> Unit raise DecodeErrors {
  if input.len == 0 {
    raise Panic("attempt to divide by zero")
  }
  // use nearest sample
  let difference = output.len / input.len
  if difference > 0 {
    // nearest neighbour
    let n = @cmp.minimum(input.len, output.len / difference)
    for i in 0..<n {
      let v = input.at(i)
      for j in 0..<difference {
        output.set(i * difference + j, v)
      }
    }
  }
}
