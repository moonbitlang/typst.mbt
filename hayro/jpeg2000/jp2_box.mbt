// Port of `hayro-jpeg2000/src/jp2/box.rs`: parsing a JP2 box, as specified in
// I.4. (Only the referenced box constants are ported; `tag_to_string` is only
// used for debug logging upstream.)

///|
/// JP2 signature box - 'jP\040\040'.
const JP2_SIGNATURE : UInt = 0x6A502020

///|
/// File Type box - 'ftyp'.
const FILE_TYPE : UInt = 0x66747970

///|
/// JP2 Header box - 'jp2h'.
const JP2_HEADER : UInt = 0x6A703268

///|
/// Colour Specification box - 'colr'.
const COLOUR_SPECIFICATION : UInt = 0x636F6C72

///|
/// Palette box - 'pclr'.
const PALETTE : UInt = 0x70636C72

///|
/// Component Mapping box - 'cmap'.
const COMPONENT_MAPPING : UInt = 0x636D6170

///|
/// Channel Definition box - 'cdef'.
const CHANNEL_DEFINITION : UInt = 0x63646566

///|
/// Contiguous Codestream box - 'jp2c'.
const CONTIGUOUS_CODESTREAM : UInt = 0x6A703263

///|
priv struct Jp2Box {
  data : BytesView
  box_type : UInt
}

///|
fn read_box(reader : BitReader) -> Jp2Box? {
  guard reader.read_u32() is Some(l_box) else { return None }
  guard reader.read_u32() is Some(t_box) else { return None }
  let data = match l_box {
    // If the value of this field is 0, then the length of the box
    // was not known when the LBox field was written. In this case, this box contains
    // all bytes up to the end of the file.
    0 => {
      guard reader.tail() is Some(data) else { return None }
      reader.jump_to_end()
      data
    }
    // If the value of this field is 1, then the XLBox field shall exist and the value of
    // that field shall be the actual length of the box.
    // The value includes all of the fields of the box, including the LBox, TBox and XLBox
    // fields.
    1 => {
      guard reader.read_u64() is Some(xl) && xl >= 16 else { return None }
      let xl_box = xl - 16
      guard xl_box <= 0x7FFFFFFFUL else { return None }
      guard reader.read_bytes(xl_box.to_int()) is Some(data) else {
        return None
      }
      data
    }
    // This field specifies the length of the box, stored as a 4-byte big-endian unsigned integer.
    // This value includes all of the fields of the box, including the length and type.
    _ => {
      guard l_box >= 8 else { return None }
      let length = l_box - 8
      guard length <= 0x7FFFFFFF else { return None }
      guard reader.read_bytes(length.reinterpret_as_int()) is Some(data) else {
        return None
      }
      data
    }
  }
  Some({ data, box_type: t_box, })
}
