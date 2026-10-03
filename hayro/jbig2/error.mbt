// Port of `hayro-jbig2/src/error.rs`: error types for JBIG2 decoding.

///|
/// Errors related to reading/parsing data.
pub(all) enum ParseError {
  /// Unexpected end of input.
  UnexpectedEof
} derive(Eq)

///|
/// Errors related to file structure.
pub(all) enum FormatError {
  /// Invalid file header signature.
  InvalidHeader
  /// Reserved bits are not zero.
  ReservedBits
  /// Missing required page information segment.
  MissingPageInfo
  /// Page height unknown with no stripe segments.
  UnknownPageHeight
  /// Page has zero width or height.
  EmptyPage
} derive(Eq)

///|
/// Errors related to segment processing.
pub(all) enum SegmentError {
  /// Unknown or reserved segment type.
  UnknownType
  /// Invalid referred-to segment count.
  InvalidReferredCount
  /// Segment refers to a larger segment number.
  InvalidReference
  /// Missing end marker for unknown-length region.
  MissingEndMarker
  /// Missing required pattern dictionary.
  MissingPatternDictionary
} derive(Eq)

///|
/// Errors related to Huffman decoding.
pub(all) enum HuffmanError {
  /// Invalid Huffman code sequence.
  InvalidCode
  /// Invalid Huffman table selection.
  InvalidSelection
  /// Not enough referred Huffman tables.
  MissingTables
  /// Unexpected out-of-band value.
  UnexpectedOob
  /// Huffman tree has conflicting codes (one code is a prefix of another).
  ConflictingCodes
  /// Prefix length exceeds maximum supported value.
  PrefixLengthTooLarge
} derive(Eq)

///|
/// Errors related to region parameters.
pub(all) enum RegionError {
  /// Invalid combination operator value.
  InvalidCombinationOperator
  /// Region with invalid dimension.
  InvalidDimension
  /// MMR (Modified Modified Read) decoding failed.
  InvalidMmrData
  /// Gray-scale value exceeds pattern count.
  GrayScaleOutOfRange
} derive(Eq)

///|
/// Errors related to template configuration.
pub(all) enum TemplateError {
  /// An invalid template value was used.
  Invalid
  /// Invalid adaptive template pixel location.
  InvalidAtPixel
} derive(Eq)

///|
/// Errors related to symbol handling.
pub(all) enum SymbolError {
  /// No symbols available for text region.
  NoSymbols
  /// The symbol dictionary contains more symbols than expected.
  TooManySymbols
  /// Symbol ID out of valid range.
  OutOfRange
  /// Unexpected out-of-band value.
  UnexpectedOob
  /// An invalid symbol was encountered.
  Invalid
  /// Strip delta multiplication overflowed.
  InvalidStripDelta
  /// Too many symbol instances in a text region.
  TooManyInstances
} derive(Eq)

///|
/// Arithmetic overflow errors.
pub(all) enum OverflowError {
  /// Bitmap dimension computation overflowed.
  BitmapDimension
  /// Halftone grid dimension computation overflowed.
  GridDimension
  /// Placement coordinate computation overflowed.
  PlacementCoordinate
  /// Reference offset computation overflowed.
  ReferenceOffset
  /// Index computation overflowed.
  Index
  /// A symbol dictionary has too many symbols.
  SymbolCount
} derive(Eq)

///|
/// The main error type for JBIG2 decoding operations.
pub(all) suberror DecodeError {
  /// Errors related to reading/parsing data.
  Parse(ParseError)
  /// Errors related to file structure.
  Format(FormatError)
  /// Errors related to segment processing.
  Segment(SegmentError)
  /// Errors related to Huffman decoding.
  Huffman(HuffmanError)
  /// Errors related to region parameters.
  Region(RegionError)
  /// Errors related to template configuration.
  Template(TemplateError)
  /// Errors related to symbol handling.
  Symbol(SymbolError)
  /// Arithmetic overflow in calculations.
  Overflow(OverflowError)
  /// Feature not yet implemented.
  Unsupported
} derive(Eq)

///|
pub impl Show for DecodeError with fn output(self, logger) {
  match self {
    Parse(e) => e.output(logger)
    Format(e) => e.output(logger)
    Segment(e) => e.output(logger)
    Huffman(e) => e.output(logger)
    Region(e) => e.output(logger)
    Template(e) => e.output(logger)
    Symbol(e) => e.output(logger)
    Overflow(e) => e.output(logger)
    Unsupported => logger.write_string("unsupported feature")
  }
}

///|
pub impl Show for OverflowError with fn output(self, logger) {
  logger.write_string(
    match self {
      BitmapDimension => "overflow in bitmap dimension computation"
      PlacementCoordinate => "overflow in placement coordinate computation"
      ReferenceOffset => "overflow in reference offset computation"
      Index => "overflow in index computation"
      GridDimension => "overflow in grid dimension computation"
      SymbolCount => "a symbol dictionary has too many symbols"
    },
  )
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnexpectedEof => "unexpected end of input"
    },
  )
}

///|
pub impl Show for FormatError with fn output(self, logger) {
  logger.write_string(
    match self {
      InvalidHeader => "invalid JBIG2 file header"
      ReservedBits => "reserved bits must be zero"
      MissingPageInfo => "missing page information segment"
      UnknownPageHeight => "page height unknown with no stripe segments"
      EmptyPage => "page has zero width or height"
    },
  )
}

///|
pub impl Show for SegmentError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnknownType => "unknown or reserved segment type"
      InvalidReferredCount => "invalid referred-to segment count"
      InvalidReference => "segment refers to larger segment number"
      MissingEndMarker => "missing end marker for unknown-length region"
      MissingPatternDictionary => "missing required pattern dictionary"
    },
  )
}

///|
pub impl Show for HuffmanError with fn output(self, logger) {
  logger.write_string(
    match self {
      InvalidCode => "invalid Huffman code"
      InvalidSelection => "invalid Huffman table selection"
      MissingTables => "not enough referred Huffman tables"
      UnexpectedOob => "unexpected out-of-band value"
      ConflictingCodes => "conflicting Huffman codes"
      PrefixLengthTooLarge => "Huffman prefix length too large"
    },
  )
}

///|
pub impl Show for RegionError with fn output(self, logger) {
  logger.write_string(
    match self {
      InvalidCombinationOperator => "invalid combination operator"
      InvalidDimension => "invalid dimension value"
      InvalidMmrData => "invalid MMR-encoded data"
      GrayScaleOutOfRange => "gray-scale value exceeds pattern count"
    },
  )
}

///|
pub impl Show for TemplateError with fn output(self, logger) {
  logger.write_string(
    match self {
      Invalid => "invalid template value"
      InvalidAtPixel => "invalid adaptive template pixel location"
    },
  )
}

///|
pub impl Show for SymbolError with fn output(self, logger) {
  logger.write_string(
    match self {
      NoSymbols => "no symbols available"
      OutOfRange => "symbol ID out of range"
      UnexpectedOob => "unexpected out-of-band value"
      TooManySymbols => "symbol dictionary contains too many symbols"
      Invalid => "invalid symbol encountered"
      InvalidStripDelta => "strip delta overflow"
      TooManyInstances => "too many symbol instances"
    },
  )
}

///|
/// `x.ok_or(err)?`: unwrap `x` or raise `err` (upstream's `?` on
/// `Option::ok_or`, with the `From` conversions into `DecodeError`).
fn[T] ok_or(x : T?, err : DecodeError) -> T raise DecodeError {
  match x {
    Some(v) => v
    None => raise err
  }
}

///|
/// `Parse(UnexpectedEof)`, the most common error.
let eof : DecodeError = Parse(UnexpectedEof)
