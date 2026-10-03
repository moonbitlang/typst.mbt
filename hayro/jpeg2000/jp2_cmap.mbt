// Port of `hayro-jpeg2000/src/jp2/cmap.rs`: the component mapping box (cmap),
// defined in I.5.3.5.

///|
fn cmap_parse(boxes : ImageBoxes, data : BytesView) -> Unit raise DecodeError {
  let reader = BitReader::new(data)
  let entries = []
  while !reader.at_end() {
    guard reader.read_u16() is Some(component_index) else {
      raise Format(InvalidBox)
    }
    guard reader.read_byte() is Some(mapping_type) else {
      raise Format(InvalidBox)
    }
    guard reader.read_byte() is Some(palette_column) else {
      raise Format(InvalidBox)
    }
    let mapping_type = match mapping_type {
      0 => ComponentMappingType::Direct
      1 => Palette(column=palette_column)
      _ => raise Format(InvalidBox)
    }
    entries.push({ component_index, mapping_type, })
  }
  boxes.component_mapping = Some({ entries, })
}

///|
priv struct ComponentMappingBox {
  entries : Array[ComponentMappingEntry]
}

///|
priv struct ComponentMappingEntry {
  component_index : Int
  mapping_type : ComponentMappingType
}

///|
priv enum ComponentMappingType {
  Direct
  Palette(column~ : Int)
}
