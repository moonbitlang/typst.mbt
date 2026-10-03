// Port of `hayro-jpeg2000/src/jp2/icc.rs`.

///|
priv enum ICCColorSpace {
  Xyz
  Lab
  Luv
  Ycbr
  Yxy
  Lms
  Rgb
  Gray
  Hsv
  Hls
  Cmyk
  Cmy
  OneClr
  ThreeClr
  FourClr
  // There are more, but those should be the most important
  // ones.
}

///|
fn ICCColorSpace::num_components(self : ICCColorSpace) -> Int {
  match self {
    Xyz => 3
    Lab => 3
    Luv => 3
    Ycbr => 3
    Yxy => 3
    Lms => 3
    Rgb => 3
    Gray => 1
    Hsv => 3
    Hls => 3
    Cmyk => 4
    Cmy => 3
    OneClr => 1
    ThreeClr => 3
    FourClr => 4
  }
}

///|
fn ICCColorSpace::try_from(value : UInt) -> ICCColorSpace? {
  match value {
    0x58595A20 => Some(Xyz)
    0x4C616220 => Some(Lab)
    0x4C757620 => Some(Luv)
    0x59436272 => Some(Ycbr)
    0x59787920 => Some(Yxy)
    0x4C4D5320 => Some(Lms)
    0x52474220 => Some(Rgb)
    0x47524159 => Some(Gray)
    0x48535620 => Some(Hsv)
    0x484C5320 => Some(Hls)
    0x434D594B => Some(Cmyk)
    0x434D5920 => Some(Cmy)
    0x31434C52 => Some(OneClr)
    0x33434C52 => Some(ThreeClr)
    0x34434C52 => Some(FourClr)
    _ => None
  }
}

///|
priv struct ICCMetadata {
  color_space : ICCColorSpace
}

///|
fn ICCMetadata::from_data(data : Bytes) -> ICCMetadata? {
  if data.length() < 20 {
    return None
  }
  let marker = (data[16].to_uint() << 24) |
    (data[17].to_uint() << 16) |
    (data[18].to_uint() << 8) |
    data[19].to_uint()
  guard ICCColorSpace::try_from(marker) is Some(color_space) else {
    return None
  }
  Some({ color_space, })
}
