// Port of `zune-jpeg` (v0.5.15) `src/worker.rs`: color conversion of rows
// and up-sampling of components.

///|
/// Fast 0..255 * 0..255 => 0..255 rounded multiplication (borrowed from stb).
fn blinn_8x8(in_val : Int, y : Int) -> Int {
  let t = in_val * y + 128
  ((t + (t >> 8)) >> 8) & 0xFF
}

///|
/// A row-chunk iterator count: the number of `chunks_exact(size)` of a
/// slice of length `len`.
fn chunks(len : Int, size : Int) -> Int {
  if size <= 0 {
    0
  } else {
    len / size
  }
}

///|
/// Convert the rows of `unprocessed` (one `padded_width` long row per output
/// row) into `output[out_pos..out_pos + out_len]`.
fn color_convert(
  unprocessed : FixedArray[Slice],
  input_colorspace : ColorSpace,
  output_colorspace : ColorSpace,
  output : FixedArray[Byte],
  out_pos : Int,
  out_len : Int,
  width : Int,
  padded_width : Int,
) -> Unit raise DecodeErrors {
  let out = { bytes: output, off: out_pos, len: out_len, }
  if input_colorspace.num_components() == 3 &&
    input_colorspace == output_colorspace {
    // sort things like RGB to RGB conversion
    copy_removing_padding(unprocessed, width, padded_width, out, 3)
    return
  }
  if input_colorspace.num_components() == 4 &&
    input_colorspace == output_colorspace {
    copy_removing_padding(unprocessed, width, padded_width, out, 4)
    return
  }
  // color convert
  match (input_colorspace, output_colorspace) {
    (YCbCr | Luma, Luma) =>
      ycbcr_to_grayscale(unprocessed[0], width, padded_width, out)
    (YCbCr, RGB) =>
      color_convert_ycbcr(
        unprocessed, width, padded_width, output_colorspace, out,
      )
    (YCCK, RGB) =>
      color_convert_ycck_to_rgb(
        unprocessed, width, padded_width, output_colorspace, out, 3,
      )
    (CMYK, RGB) =>
      color_convert_cymk_to_rgb(unprocessed, width, padded_width, out, 3)
    (MultiBand(n), _) => {
      if n != 2 {
        raise Format("Unknown multiband sample (\{n}), please share sample")
      }
      copy_removing_padding(unprocessed, width, padded_width, out, 2)
    }
    (Luma, RGB) => convert_luma_to_rgb(unprocessed, width, padded_width, out, 3)
    // For the other components we do nothing(currently)
    _ =>
      raise Format(
        "Unimplemented colorspace mapping from \{input_colorspace.debug()} to \{output_colorspace.debug()}",
      )
  }
}

///|
/// Output view.
priv struct OutSlice {
  bytes : FixedArray[Byte]
  off : Int
  len : Int
}

///|
fn convert_luma_to_rgb(
  mcu_block : FixedArray[Slice],
  width : Int,
  padded_width : Int,
  output : OutSlice,
  n : Int,
) -> Unit {
  let rows = @cmp.minimum(
    chunks(output.len, width * n),
    chunks(mcu_block[0].len, padded_width),
  )
  for r in 0..<rows {
    let pix_w = output.off + r * width * n
    let y_w = r * padded_width
    let cnt = @cmp.minimum(width, padded_width)
    for x in 0..<cnt {
      let c = mcu_block[0].at(y_w + x).to_byte()
      output.bytes[pix_w + x * n] = c
      output.bytes[pix_w + x * n + 1] = c
      output.bytes[pix_w + x * n + 2] = c
      if n == 4 {
        output.bytes[pix_w + x * n + 3] = b'\xFF'
      }
    }
  }
}

///|
/// Copy a block to output removing padding bytes from input if necessary
/// (upstream `copy_removing_padding`, `copy_removing_padding_4x` and
/// `copy_removing_padding_generic`).
fn copy_removing_padding(
  mcu_block : FixedArray[Slice],
  width : Int,
  padded_width : Int,
  output : OutSlice,
  channels : Int,
) -> Unit {
  let mut rows = chunks(output.len, width * channels)
  for c in 0..<channels {
    rows = @cmp.minimum(rows, chunks(mcu_block[c].len, padded_width))
  }
  for r in 0..<rows {
    let pix_w = output.off + r * width * channels
    let cnt = @cmp.minimum(width, padded_width)
    for x in 0..<cnt {
      for c in 0..<channels {
        output.bytes[pix_w + x * channels + c] = mcu_block[c]
          .at(r * padded_width + x)
          .to_byte()
      }
    }
  }
}

///|
/// Convert YCCK image to rgb.
fn color_convert_ycck_to_rgb(
  mcu_block : FixedArray[Slice],
  width : Int,
  padded_width : Int,
  output_colorspace : ColorSpace,
  output : OutSlice,
  num_components : Int,
) -> Unit {
  color_convert_ycbcr(mcu_block, width, padded_width, output_colorspace, output)
  let rows = @cmp.minimum(
    chunks(output.len, width * 3),
    chunks(mcu_block[3].len, padded_width),
  )
  for r in 0..<rows {
    let pix_w = output.off + r * width * 3
    let cnt = @cmp.minimum(width * 3 / num_components, padded_width)
    for x in 0..<cnt {
      let m = mcu_block[3].at(r * padded_width + x) & 0xFF
      let p = pix_w + x * num_components
      output.bytes[p] = blinn_8x8(255 - output.bytes[p].to_int(), m).to_byte()
      output.bytes[p + 1] = blinn_8x8(255 - output.bytes[p + 1].to_int(), m).to_byte()
      output.bytes[p + 2] = blinn_8x8(255 - output.bytes[p + 2].to_int(), m).to_byte()
    }
  }
}

///|
fn color_convert_cymk_to_rgb(
  mcu_block : FixedArray[Slice],
  width : Int,
  padded_width : Int,
  output : OutSlice,
  num_components : Int,
) -> Unit {
  let mut rows = chunks(output.len, width * num_components)
  for c in 0..<4 {
    rows = @cmp.minimum(rows, chunks(mcu_block[c].len, padded_width))
  }
  for r in 0..<rows {
    let pix_w = output.off + r * width * num_components
    let cnt = @cmp.minimum(width * num_components / 3, padded_width)
    for x in 0..<cnt {
      let i = r * padded_width + x
      let c = mcu_block[0].at(i) & 0xFF
      let m = mcu_block[1].at(i) & 0xFF
      let y = mcu_block[2].at(i) & 0xFF
      let k = mcu_block[3].at(i) & 0xFF
      let p = pix_w + x * 3
      output.bytes[p] = blinn_8x8(c, k).to_byte()
      output.bytes[p + 1] = blinn_8x8(m, k).to_byte()
      output.bytes[p + 2] = blinn_8x8(y, k).to_byte()
    }
  }
}

///|
/// Do color-conversion for interleaved MCU.
fn color_convert_ycbcr(
  mcu_block : FixedArray[Slice],
  width : Int,
  padded_width : Int,
  output_colorspace : ColorSpace,
  output : OutSlice,
) -> Unit {
  let num_components = output_colorspace.num_components()
  let stride = width * num_components
  // Allocate temporary buffer for small widths less than 16.
  let temp : FixedArray[Byte] = FixedArray::make(64, 0)
  // We need to chunk per width to ensure we can discard extra values at the
  // end of the width.
  let mut rows = chunks(output.len, stride)
  for c in 0..<3 {
    rows = @cmp.minimum(rows, chunks(mcu_block[c].len, padded_width))
  }
  let y_a = mcu_block[0]
  let cb_a = mcu_block[1]
  let cr_a = mcu_block[2]
  for r in 0..<rows {
    let yo = y_a.off + r * padded_width
    let cbo = cb_a.off + r * padded_width
    let cro = cr_a.off + r * padded_width
    let out = output.off + r * stride
    if width < 16 {
      // allocate temporary buffers for the values received from idct
      let y_out = FixedArray::make(16, 0)
      let cb_out = FixedArray::make(16, 0)
      let cr_out = FixedArray::make(16, 0)
      let n = @cmp.minimum(padded_width, 16)
      for i in 0..<n {
        y_out[i] = y_a.arr[yo + i]
        cb_out[i] = cb_a.arr[cbo + i]
        cr_out[i] = cr_a.arr[cro + i]
      }
      ycbcr_to_rgb_16(y_out, 0, cb_out, 0, cr_out, 0, temp, 0, num_components)
      // copy to stride
      for i in 0..<(width * num_components) {
        output.bytes[out + i] = temp[i]
      }
      continue
    }
    // Chunk in outputs of 16 to pass to color_convert as an array of 16
    // i16's.
    let n = @cmp.minimum(padded_width / 16, stride / (16 * num_components))
    for c in 0..<n {
      ycbcr_to_rgb_16(
        y_a.arr,
        yo + c * 16,
        cb_a.arr,
        cbo + c * 16,
        cr_a.arr,
        cro + c * 16,
        output.bytes,
        out + c * 16 * num_components,
        num_components,
      )
    }
    // we have more pixels in the end that can't be handled by the main loop.
    // move pointer back a little bit to get last 16 bytes, color convert,
    // and overwrite. This means some values will be color converted twice.
    if padded_width - (width - 16) >= 16 {
      ycbcr_to_rgb_16(
        y_a.arr,
        yo + width - 16,
        cb_a.arr,
        cbo + width - 16,
        cr_a.arr,
        cro + width - 16,
        temp,
        0,
        num_components,
      )
    }
    let rem = out + (width - 16) * num_components
    for i in 0..<(16 * num_components) {
      output.bytes[rem + i] = temp[i]
    }
  }
}

///|
fn ycbcr_to_grayscale(
  y : Slice,
  width : Int,
  padded_width : Int,
  output : OutSlice,
) -> Unit {
  let rows = @cmp.minimum(
    chunks(y.len, padded_width),
    chunks(output.len, width),
  )
  for r in 0..<rows {
    let cnt = @cmp.minimum(width, padded_width)
    for x in 0..<cnt {
      output.bytes[output.off + r * width + x] = y
        .at(r * padded_width + x)
        .to_byte()
    }
  }
}

///|
/// Copy `src[s..s + n]` to `dst[d..d + n]`.
fn copy_ints(
  dst : FixedArray[Int],
  d : Int,
  src : FixedArray[Int],
  s : Int,
  n : Int,
) -> Unit {
  for i in 0..<n {
    dst[d + i] = src[s + i]
  }
}

///|
fn upsample(
  component : Components,
  mcu_height : Int,
  i : Int,
  upsampler_scratch_space : FixedArray[Int],
  has_vertical_sample : Bool,
) -> Unit raise DecodeErrors {
  match component.sample_ratio {
    V | HV => {
      // When upsampling vertically sampled images, we do not have all MCU's
      // decoded, so we carry over the last rows and upsample them when the
      // next MCU row is available.
      let mut dest_start = 0
      let stride_bytes_written = component.width_stride *
        component.sample_ratio.sample()
      if i > 0 {
        // Handle the last MCU of the previous row
        // This wasn't up-sampled as we didn't have the row_down
        // so we do it now
        let stride = component.width_stride
        let dest = {
          arr: component.first_row_upsample_dest,
          off: 0,
          len: stride_bytes_written,
        }
        // get current row
        let row = Slice::of(component.row)
        let row_up = Slice::of(component.row_up)
        let row_down = { arr: component.raw_coeff, off: 0, len: stride, }
        run_upsampler(
          component.up_sampler,
          row,
          row_up,
          row_down,
          upsampler_scratch_space,
          dest,
        )
      }
      // we have the Y component width stride.
      // this may be higher than the actual width,(2x because vertical sampling)
      //
      // This will not upsample the last row

      // if false, do not upsample.
      // set to false on the last row of an mcu
      let mut upsample = true
      let stride = component.width_stride * component.vertical_sample
      let raw_len = component.raw_coeff.length()
      let stop_offset = raw_len / component.width_stride
      if raw_len != stop_offset * stride {
        // slice would panic below
        raise FormatStatic("Invalid component dimensions, would panic")
      }
      let raw = component.raw_coeff
      for pos in 0..<stop_offset {
        let curr_row = {
          arr: raw,
          off: pos * component.width_stride,
          len: component.width_stride,
        }
        let mut row_up = { arr: raw, off: 0, len: 0, }
        // row below current sample
        let mut row_down = { arr: raw, off: 0, len: 0, }
        // Order of ifs matters
        if i == 0 && pos == 0 {
          // first IMAGE row, row_up is the same as current row
          // row_down is the row below.
          row_up = { arr: raw, off: pos * stride, len: stride, }
          row_down = { arr: raw, off: (pos + 1) * stride, len: stride, }
        } else if i > 0 && pos == 0 {
          // first row of a new mcu, previous row was copied so use that
          row_up = Slice::of(component.row)
          row_down = { arr: raw, off: (pos + 1) * stride, len: stride, }
        } else if i == @cmp.maximum(mcu_height - 1, 0) && pos == stop_offset - 1 {
          // last IMAGE row, adjust pointer to use previous row and current row
          row_up = { arr: raw, off: (pos - 1) * stride, len: stride, }
          row_down = { arr: raw, off: pos * stride, len: stride, }
        } else if pos > 0 && pos < stop_offset - 1 {
          // other rows, get row up and row down relative to our current row
          // ignore last row of each mcu
          row_up = { arr: raw, off: (pos - 1) * stride, len: stride, }
          row_down = { arr: raw, off: (pos + 1) * stride, len: stride, }
        } else if pos == stop_offset - 1 {
          // last MCU in a row
          //
          // we need a row at the next MCU but we haven't decoded that MCU yet
          // so we should save this and when we have the next MCU,
          // do the upsampling

          // store the current row and previous row in a buffer
          copy_ints(component.row_up, 0, raw, (pos - 1) * stride, stride)
          copy_ints(component.row, 0, raw, curr_row.off, component.width_stride)
          upsample = false
        } else {
          abort("Uh oh!")
        }
        if upsample {
          let dest = {
            arr: component.upsample_dest,
            off: dest_start,
            len: stride_bytes_written,
          }
          dest_start += stride_bytes_written
          run_upsampler(
            component.up_sampler,
            curr_row,
            row_up,
            row_down,
            upsampler_scratch_space,
            dest,
          )
        }
      }
    }
    H => {
      // Before it was an assert, but numerous and numerous and numerous bug
      // fixes and ad hoc solutions later, I have now just decided to keep it
      // as a resize
      let new_len = component.raw_coeff.length() * 2
      if component.upsample_dest.length() != new_len {
        let old = component.upsample_dest
        let dest = FixedArray::make(new_len, 0)
        copy_ints(dest, 0, old, 0, @cmp.minimum(old.length(), new_len))
        component.upsample_dest = dest
      }
      let raw_coeff = component.raw_coeff
      let dest_coeff = component.upsample_dest
      if has_vertical_sample {
        // Save the last MCU row in case it will be needed (misaligned
        // sampling factors, e.g. Y 2x2, Cb 1x1, Cr 1x2).
        let length = component.first_row_upsample_dest.length()
        copy_ints(
          component.first_row_upsample_dest,
          0,
          dest_coeff,
          dest_coeff.length() - length,
          length,
        )
      }
      // up-sample each row
      let ws = component.width_stride
      let rows = @cmp.minimum(
        chunks(raw_coeff.length(), ws),
        chunks(dest_coeff.length(), ws * 2),
      )
      for r in 0..<rows {
        run_upsampler(
          component.up_sampler,
          { arr: raw_coeff, off: r * ws, len: ws, },
          { arr: raw_coeff, off: 0, len: 0, },
          { arr: raw_coeff, off: 0, len: 0, },
          [],
          { arr: dest_coeff, off: r * ws * 2, len: ws * 2, },
        )
      }
    }
    Generic(h, v) => {
      let raw_coeff = component.raw_coeff
      let dest_coeff = component.upsample_dest
      let ws = component.width_stride
      let rows = @cmp.minimum(
        chunks(raw_coeff.length(), ws),
        chunks(dest_coeff.length(), ws * h * v),
      )
      for r in 0..<rows {
        let base = r * ws * h * v
        for k in 0..<chunks(ws * h * v, ws * h) {
          run_upsampler(
            component.up_sampler,
            { arr: raw_coeff, off: r * ws, len: ws, },
            { arr: raw_coeff, off: 0, len: 0, },
            { arr: raw_coeff, off: 0, len: 0, },
            [],
            { arr: dest_coeff, off: base + k * ws * h, len: ws * h, },
          )
        }
      }
    }
    NoSample => ()
  }
}
