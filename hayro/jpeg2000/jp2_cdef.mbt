// Port of `hayro-jpeg2000/src/jp2/cdef.rs`: the channel definition box
// (cdef), defined in I.5.3.6.

///|
fn cdef_parse(boxes : ImageBoxes, data : BytesView) -> Unit raise DecodeError {
  let reader = BitReader::new(data)
  guard reader.read_u16() is Some(count) else { raise Format(InvalidBox) }
  let definitions : Array[ChannelDefinition] = []
  if count == 0 {
    raise Format(InvalidBox)
  }
  for _ in 0..<count {
    guard reader.read_u16() is Some(channel_index) else {
      raise Format(InvalidBox)
    }
    guard reader.read_u16() is Some(channel_type) else {
      raise Format(InvalidBox)
    }
    guard reader.read_u16() is Some(association) else {
      raise Format(InvalidBox)
    }
    guard ChannelType::from_raw(channel_type) is Some(channel_type) else {
      raise Format(InvalidBox)
    }
    guard ChannelAssociation::from_raw(association) is Some(association) else {
      raise Format(InvalidBox)
    }
    definitions.push({ channel_index, channel_type, association, })
  }
  let definitions = stable_sort_by_key(definitions, d => d.channel_index)

  // Ensure channel indices increases in steps of 1, starting from 0.
  for idx, def in definitions {
    if def.channel_index != idx {
      raise Format(InvalidBox)
    }
  }
  boxes.channel_definition = Some({ channel_definitions: definitions, })
}

///|
priv struct ChannelDefinitionBox {
  channel_definitions : Array[ChannelDefinition]
}

///|
priv struct ChannelDefinition {
  channel_index : Int
  channel_type : ChannelType
  /// `_association` upstream.
  association : ChannelAssociation
}

///|
priv enum ChannelType {
  Colour
  Opacity
} derive(Eq)

///|
fn ChannelType::from_raw(value : Int) -> ChannelType? {
  match value {
    0 => Some(Colour)
    1 => Some(Opacity)
    // We don't support the others.
    _ => None
  }
}

///|
priv enum ChannelAssociation {
  WholeImage
  Colour(Int)
}

///|
fn ChannelAssociation::from_raw(value : Int) -> ChannelAssociation? {
  match value {
    0 => Some(WholeImage)
    // Unspecified.
    0xFFFF => None
    v => Some(Colour(v))
  }
}
