// Port of `zune-jpeg` (v0.5.15) `src/components.rs`: information about JPEG
// image components, extracted from a SOF header.

///|
const MAX_SAMP_FACTOR : Int = 4

///|
/// Component IDs.
priv enum ComponentID {
  /// Luminance channel
  Y
  /// Blue chrominance
  Cb
  /// Red chrominance
  Cr
  /// Q or fourth component
  Q
} derive(Eq)

///|
fn ComponentID::debug(self : ComponentID) -> String {
  match self {
    Y => "Y"
    Cb => "Cb"
    Cr => "Cr"
    Q => "Q"
  }
}

///|
/// Sub-sampling ratios.
priv enum SampleRatios {
  HV
  V
  H
  Generic(Int, Int)
  NoSample
} derive(Eq)

///|
fn SampleRatios::sample(self : SampleRatios) -> Int {
  match self {
    HV => 4
    V | H => 2
    Generic(a, b) => a * b
    NoSample => 1
  }
}

///|
/// The up-sampling function of a component (upstream `UpSampler` function
/// pointers; the NEON variants used on aarch64 compute the same values as
/// the scalar ones).
priv enum UpSampler {
  NoOp
  Horizontal
  Vertical
  HorizontalVertical
  Generic
}

///|
/// Component data from start of frame.
priv struct Components {
  /// The type of component that has the metadata below, can be Y, Cb or Cr
  component_id : ComponentID
  /// Sub-sampling ratio of this component in the y-plane
  mut vertical_sample : Int
  /// Sub-sampling ratio of this component in the x-plane
  mut horizontal_sample : Int
  /// DC huffman table position
  mut dc_huff_table : Int
  /// AC huffman table position for this element.
  mut ac_huff_table : Int
  /// Quantization table number
  quantization_table_number : Int
  /// Specifies quantization table to use with this component
  mut quantization_table : FixedArray[Int]
  /// dc prediction for the component
  mut dc_pred : Int
  /// An up-sampling function
  mut up_sampler : UpSampler
  /// How pixels do we need to go to get to the next line?
  mut width_stride : Int
  /// Component ID for progressive
  id : Int
  /// Whether we need to decode this image component.
  mut needed : Bool
  /// Upsample scanline
  mut raw_coeff : FixedArray[Int]
  /// Upsample destination, stores a scanline worth of sub sampled data
  mut upsample_dest : FixedArray[Int]
  /// previous row, used to handle MCU boundaries
  mut row_up : FixedArray[Int]
  /// current row, used to handle MCU boundaries again
  mut row : FixedArray[Int]
  mut first_row_upsample_dest : FixedArray[Int]
  mut idct_pos : Int
  mut sample_ratio : SampleRatios
  // a very annoying bug
  mut fix_an_annoying_bug : Int
}

///|
/// Create a new instance from three bytes from the start of frame.
fn Components::from(a : BytesView, pos : Int) -> Components raise DecodeErrors {
  let id = match pos {
    0 => ComponentID::Y
    1 => Cb
    2 => Cr
    3 => Q
    _ =>
      raise Format(
        "Unknown component id found,\{pos}, expected value between 1 and 4",
      )
  }
  let horizontal_sample = a[1].to_int() >> 4
  let vertical_sample = a[1].to_int() & 0x0f
  // Match libjpeg turbo on checking for sampling factors
  // Reject anything above 4
  if horizontal_sample > MAX_SAMP_FACTOR {
    raise Format("Bogus Horizontal Sampling Factor \{horizontal_sample}")
  }
  if vertical_sample > MAX_SAMP_FACTOR {
    raise Format("Bogus Vertical Sampling Factor \{vertical_sample}")
  }
  let quantization_table_number = a[2].to_int()
  // confirm quantization number is between 0 and MAX_COMPONENTS
  if quantization_table_number >= MAX_COMPONENTS {
    raise Format(
      "Too large quantization number :\{quantization_table_number}, expected value between 0 and \{MAX_COMPONENTS}",
    )
  }
  // check that upsampling ratios are powers of two
  // if these fail, it's probably a corrupt image.
  if horizontal_sample == 0 ||
    (horizontal_sample & (horizontal_sample - 1)) != 0 {
    raise Format(
      "Horizontal sample is not a power of two(\{horizontal_sample}) cannot decode",
    )
  }
  if vertical_sample == 0 {
    // Check for invalid vertical sample
    raise Format("Vertical sample is zero")
  }
  {
    component_id: id,
    vertical_sample,
    horizontal_sample,
    quantization_table_number,
    first_row_upsample_dest: [],
    dc_huff_table: 0,
    ac_huff_table: 0,
    quantization_table: FixedArray::make(64, 0),
    dc_pred: 0,
    up_sampler: NoOp,
    width_stride: horizontal_sample,
    id: a[0].to_int(),
    needed: true,
    raw_coeff: [],
    upsample_dest: [],
    row_up: [],
    row: [],
    idct_pos: 0,
    sample_ratio: NoSample,
    fix_an_annoying_bug: 1,
  }
}

///|
/// Setup space for upsampling.
fn Components::setup_upsample_scanline(self : Components) -> Unit {
  self.row = FixedArray::make(self.width_stride * self.vertical_sample, 0)
  self.row_up = FixedArray::make(self.width_stride * self.vertical_sample, 0)
  self.first_row_upsample_dest = FixedArray::make(
    self.vertical_sample * self.width_stride * self.sample_ratio.sample(),
    128,
  )
  self.upsample_dest = FixedArray::make(
    self.width_stride *
    self.sample_ratio.sample() *
    self.fix_an_annoying_bug *
    8,
    0,
  )
}
