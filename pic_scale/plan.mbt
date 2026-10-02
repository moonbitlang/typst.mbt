// Ports of pic-scale's `plan/horizontal_filtering.rs`,
// `plan/vertical_filtering.rs` and `plan/trampoline_filtering.rs` (single
// threaded, `ThreadingPolicy::Single`).
//
// Upstream's row filters may process 4 rows at once (`filter_4_rows`); the
// u8 NEON 4-row kernels compute every row exactly like their 1-row
// counterparts, so rows are processed one at a time here.

///|
/// A horizontal row kernel: filters the pixels of one source row starting at
/// `src_offset` into one destination row starting at `dst_offset`.
type RowKernel = (FixedArray[Byte], Int, FixedArray[Byte], Int, FixedWeights) -> Unit

///|
/// A vertical row kernel (`fn(usize, &FilterBounds, &[u8], &mut [u8], usize,
/// &[i16], u32)`): `width` bytes of one destination row from the source rows
/// `bounds_start .. bounds_start + bounds_size`; the last argument is an
/// accumulator scratch of at least `width` elements.
type ColumnKernel = (
  Int,
  Int,
  Int,
  FixedArray[Byte],
  Int,
  Int,
  FixedArray[Byte],
  Int,
  FixedArray[Int],
  Int,
  FixedArray[Int],
) -> Unit

///|
/// `HorizontalFiltering<u8, i16, N>`.
priv struct HorizontalFiltering {
  filter_row : RowKernel
  filter_weights : FixedWeights
}

///|
/// `RowFilter::filter`: every destination row from the source row with the
/// same index.
fn HorizontalFiltering::filter(
  self : HorizontalFiltering,
  src : FixedArray[Byte],
  src_stride : Int,
  dst : FixedArray[Byte],
  dst_stride : Int,
  dst_height : Int,
) -> Unit {
  for y in 0..<dst_height {
    self.run_on_row(src, y * src_stride, dst, y * dst_stride)
  }
}

///|
/// `RowFilter::run_on_row`.
fn HorizontalFiltering::run_on_row(
  self : HorizontalFiltering,
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
) -> Unit {
  (self.filter_row)(src, src_offset, dst, dst_offset, self.filter_weights)
}

///|
/// `VerticalFiltering<u8, i16, N>`.
priv struct VerticalFiltering {
  filter_row : ColumnKernel
  filter_weights : FixedWeights
}

///|
/// `ColumnFilter::filter`: destination row `y` from the source rows of
/// kernel `y`; `width` is the row length in bytes (`dst_width * N`).
fn VerticalFiltering::filter(
  self : VerticalFiltering,
  src : FixedArray[Byte],
  src_stride : Int,
  dst : FixedArray[Byte],
  dst_stride : Int,
  width : Int,
  dst_height : Int,
) -> Unit {
  let acc = FixedArray::make(width, 0)
  for y in 0..<dst_height {
    self.run_on_row(src, src_stride, dst, y * dst_stride, width, y, acc)
  }
}

///|
/// `ColumnFilter::run_on_row`.
fn VerticalFiltering::run_on_row(
  self : VerticalFiltering,
  src : FixedArray[Byte],
  src_stride : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  width : Int,
  y : Int,
  acc : FixedArray[Int],
) -> Unit {
  let fw = self.filter_weights
  (self.filter_row)(
    width,
    fw.bounds_start[y],
    fw.bounds_size[y],
    src,
    0,
    src_stride,
    dst,
    dst_offset,
    fw.weights,
    y * fw.aligned_size,
    acc,
  )
}

///|
/// `TrampolineFiltering::filter`: for each destination row, the vertical
/// pass produces a full-width `u8` row (in `scratch`) which the horizontal
/// pass then resamples.
fn trampoline_filter(
  horizontal_filter : HorizontalFiltering,
  vertical_filter : VerticalFiltering,
  src : FixedArray[Byte],
  src_width : Int,
  dst : FixedArray[Byte],
  dst_height : Int,
  channels : Int,
) -> Unit {
  let src_stride = src_width * channels
  let dst_stride = horizontal_filter.filter_weights.bounds_start.length() *
    channels
  let scratch = FixedArray::make(src_stride, b'\x00')
  let acc = FixedArray::make(src_stride, 0)
  for y in 0..<dst_height {
    vertical_filter.run_on_row(src, src_stride, scratch, 0, src_stride, y, acc)
    horizontal_filter.run_on_row(scratch, 0, dst, y * dst_stride)
  }
}
