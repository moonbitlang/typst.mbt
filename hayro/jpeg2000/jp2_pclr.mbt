// Port of `hayro-jpeg2000/src/jp2/pclr.rs`: the palette box (pclr), defined
// in I.5.3.4.

///|
fn pclr_parse(boxes : ImageBoxes, data : BytesView) -> Unit raise DecodeError {
  let reader = BitReader::new(data)
  guard reader.read_u16() is Some(num_entries) else { raise Format(InvalidBox) }
  guard reader.read_byte() is Some(num_components) else {
    raise Format(InvalidBox)
  }
  if num_entries == 0 || num_components == 0 {
    raise Format(InvalidBox)
  }
  let columns : Array[PaletteColumn] = []
  for _ in 0..<num_components {
    guard reader.read_byte() is Some(descriptor) else {
      raise Format(InvalidBox)
    }
    // `(descriptor & 0x7F).checked_add(1)` cannot overflow.
    let bit_depth = (descriptor & 0x7F) + 1
    let is_signed = (descriptor & 0x80) != 0
    if is_signed {
      raise Format(InvalidBox)
    }
    columns.push({ bit_depth, })
  }
  let entries : Array[FixedArray[UInt64]] = []
  for _ in 0..<num_entries {
    let row = FixedArray::make(num_components, 0UL)
    for i, column in columns {
      let num_bytes = {
        let n = (column.bit_depth + 7) / 8
        if n < 1 {
          1
        } else {
          n
        }
      }
      guard reader.read_bytes(num_bytes) is Some(raw_bytes) else {
        raise Format(InvalidBox)
      }
      let mut raw_value = 0UL
      for byte in raw_bytes {
        raw_value = (raw_value << 8) | byte.to_uint64()
      }
      row[i] = raw_value
    }
    entries.push(row)
  }
  boxes.palette = Some({ entries, columns, })
}

///|
priv struct PaletteBox {
  entries : Array[FixedArray[UInt64]]
  columns : Array[PaletteColumn]
}

///|
fn PaletteBox::map(self : PaletteBox, entry : Int64, column : Int) -> UInt64? {
  if entry < 0 || entry >= self.entries.length().to_int64() {
    return None
  }
  let row = self.entries[entry.to_int()]
  if column < 0 || column >= row.length() {
    return None
  }
  Some(row[column])
}

///|
priv struct PaletteColumn {
  bit_depth : Int
}
