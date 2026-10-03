// Port of `hayro-jpeg2000/src/jp2/colr.rs`: the color specification box
// (colr), defined in I.5.3.3.

///|
fn colr_parse(boxes : ImageBoxes, data : BytesView) -> Unit raise DecodeError {
  if boxes.color_specification is Some(_) {
    // "A JP2 file may contain multiple Colour Specification boxes, but
    // must contain at least one, specifying different methods
    // for achieving "equivalent" results. A conforming JP2 reader shall
    // ignore all Colour Specification boxes after the first.
    // However, readers conforming to other standards may use those boxes as
    // defined in those other standards."

    return
  }
  let reader = BitReader::new(data)
  guard reader.read_byte() is Some(meth) else { raise Format(InvalidBox) }
  // We don't care about those.
  guard reader.read_byte() is Some(_prec) else { raise Format(InvalidBox) }
  guard reader.read_byte() is Some(_approx) else { raise Format(InvalidBox) }
  let colr_method = match meth {
    1 => {
      guard reader.read_u32() is Some(enumerated) else {
        raise Format(InvalidBox)
      }
      guard EnumeratedColorspace::from_raw(enumerated, reader) is Some(e) else {
        raise Format(InvalidBox)
      }
      ColrColorSpace::Enumerated(e)
    }
    2 => {
      guard reader.tail() is Some(profile_data) else {
        raise Format(InvalidBox)
      }
      ColrColorSpace::Icc(profile_data.to_bytes())
    }
    _ => ColrColorSpace::Unknown
  }
  boxes.color_specification = Some({ color_space: colr_method, })
}

///|
priv struct ColorSpecificationBox {
  color_space : ColrColorSpace
}

///|
/// `jp2::colr::ColorSpace` upstream.
priv enum ColrColorSpace {
  Enumerated(EnumeratedColorspace)
  Icc(Bytes)
  Unknown
}

///|
priv enum EnumeratedColorspace {
  BiLevel1
  YCbCr1
  YCbCr2
  YCbCr3
  PhotoYcc
  Cmy
  Cmyk
  Ycck
  CieLab(CieLab)
  BiLevel2
  Srgb
  Greyscale
  Sycc
  CieJab
  EsRgb
  RommRgb
  YPbPr112560
  YPbPr125050
  EsYcc
  ScRgb
  ScRgbGray
}

///|
priv struct CieLab {
  rl : UInt?
  ol : UInt?
  ra : UInt?
  oa : UInt?
  rb : UInt?
  ob : UInt?
}

///|
fn EnumeratedColorspace::from_raw(
  value : UInt,
  reader : BitReader,
) -> EnumeratedColorspace? {
  match value {
    0 => Some(BiLevel1)
    1 => Some(YCbCr1)
    3 => Some(YCbCr2)
    4 => Some(YCbCr3)
    9 => Some(PhotoYcc)
    11 => Some(Cmy)
    12 => Some(Cmyk)
    13 => Some(Ycck)
    14 => {
      // M.11.7.4.1 EP field format for the CIELab colourspace
      let rl = reader.read_u32()
      let ol = reader.read_u32()
      let ra = reader.read_u32()
      let oa = reader.read_u32()
      let rb = reader.read_u32()
      let ob = reader.read_u32()
      // Not supported for now.
      let _il = reader.read_u32()
      Some(CieLab({ rl, ol, ra, oa, rb, ob, }))
    }
    15 => Some(BiLevel2)
    16 => Some(Srgb)
    17 => Some(Greyscale)
    18 => Some(Sycc)
    19 => Some(CieJab)
    20 => Some(EsRgb)
    21 => Some(RommRgb)
    22 => Some(YPbPr112560)
    23 => Some(YPbPr125050)
    24 => Some(EsYcc)
    25 => Some(ScRgb)
    26 => Some(ScRgbGray)
    _ => None
  }
}
