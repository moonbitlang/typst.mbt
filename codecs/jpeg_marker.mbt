// Port of `zune-jpeg` (v0.5.15) `src/marker.rs`.

///|
/// JPEG markers.
///
/// **NOTE** This doesn't cover all markers, just the ones zune-jpeg supports.
priv enum Marker {
  /// Start of frame markers (only 0..=2 are produced by `from_u8`).
  SOF(Int)
  /// Define Huffman table(s).
  DHT
  /// Define arithmetic coding conditioning(s).
  DAC
  /// Restart with modulo 8 count `m`.
  RST(Int)
  /// Start of image.
  SOI
  /// End of image.
  EOI
  /// Start of scan.
  SOS
  /// Define quantization table(s).
  DQT
  /// Define number of lines.
  DNL
  /// Define restart interval.
  DRI
  /// Reserved for application segments.
  APP(Int)
  /// Comment.
  COM
  /// Unknown markers.
  UNKNOWN(Int)
} derive(Eq)

///|
/// Upstream `Marker::from_u8` (which always returns `Some`).
fn Marker::from_u8(n : Int) -> Marker {
  match n {
    0xFE => COM
    0xC0 => SOF(0)
    0xC1 => SOF(1)
    0xC2 => SOF(2)
    0xC4 => DHT
    0xCC => DAC
    0xD0..<=0xD7 => RST(n - 0xD0)
    0xD8 => SOI
    0xD9 => EOI
    0xDA => SOS
    0xDB => DQT
    0xDC => DNL
    0xDD => DRI
    0xE0 => APP(0)
    0xE1 => APP(1)
    0xE2 => APP(2)
    0xED => APP(13)
    0xEE => APP(14)
    _ => UNKNOWN(n)
  }
}

///|
/// Upstream derived `Debug for Marker`.
fn Marker::debug(self : Marker) -> String {
  match self {
    SOF(n) => "SOF(\{n})"
    DHT => "DHT"
    DAC => "DAC"
    RST(n) => "RST(\{n})"
    SOI => "SOI"
    EOI => "EOI"
    SOS => "SOS"
    DQT => "DQT"
    DNL => "DNL"
    DRI => "DRI"
    APP(n) => "APP(\{n})"
    COM => "COM"
    UNKNOWN(n) => "UNKNOWN(\{n})"
  }
}
