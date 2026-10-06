// Port of `hayro-jpeg2000/src/jp2/mod.rs`: reading a JP2 file, defined in
// Annex I.

///|
priv struct ImageBoxes {
  mut color_specification : ColorSpecificationBox?
  mut channel_definition : ChannelDefinitionBox?
  mut palette : PaletteBox?
  mut component_mapping : ComponentMappingBox?
}

///|
fn ImageBoxes::default() -> ImageBoxes {
  {
    color_specification: None,
    channel_definition: None,
    palette: None,
    component_mapping: None,
  }
}

///|
fn ImageBoxes::clone(self : ImageBoxes) -> ImageBoxes {
  { ..self, }
}

///|
/// A decoded JPEG2000 image.
pub struct DecodedImage {
  /// The raw decoded JPEG2000 codestream components.
  priv decoded_components : Array[ComponentData]
  /// The JP2 boxes of the image. In the case of a raw codestream, we
  /// will synthesize the necessary boxes.
  priv boxes : ImageBoxes
}

///|
fn jp2_parse(
  data : BytesView,
  settings : DecodeSettings,
) -> Image raise DecodeError {
  let mut settings = settings
  let reader = BitReader::new(data)
  guard read_box(reader) is Some(signature_box) else {
    raise Format(InvalidBox)
  }
  if signature_box.box_type != JP2_SIGNATURE {
    raise Format(InvalidSignature)
  }
  guard read_box(reader) is Some(file_type_box) else {
    raise Format(InvalidBox)
  }
  if file_type_box.box_type != FILE_TYPE {
    raise Format(InvalidFileType)
  }
  let mut image_boxes : ImageBoxes? = None
  let mut parsed_codestream = None

  // Read boxes until we find the JP2 Header box
  while !reader.at_end() {
    guard read_box(reader) is Some(current_box) else {
      if settings.strict {
        raise Format(InvalidBox)
      }
      break
    }
    match current_box.box_type {
      JP2_HEADER => {
        let boxes = ImageBoxes::default()
        let jp2h_reader = BitReader::new(current_box.data)

        // Read child boxes within JP2 Header box
        while !jp2h_reader.at_end() {
          guard read_box(jp2h_reader) is Some(child_box) else {
            raise Format(InvalidBox)
          }
          match child_box.box_type {
            CHANNEL_DEFINITION => {
              let failed = try cdef_parse(boxes, child_box.data) catch {
                _ => true
              } noraise {
                _ => false
              }
              if failed && settings.strict {
                raise Format(InvalidBox)
              }
              // If not strict decoding, just assume default
              // configuration.
            }
            COLOUR_SPECIFICATION => colr_parse(boxes, child_box.data)
            PALETTE => {
              let failed = try pclr_parse(boxes, child_box.data) catch {
                _ => true
              } noraise {
                _ => false
              }
              if failed && settings.strict {
                raise Format(InvalidBox)
              }

              // If we have a palettized image, decoding at a
              // lower resolution will corrupt it, so we can't do
              // it in this case.
              settings = { ..settings, target_resolution: None, }
            }
            COMPONENT_MAPPING => cmap_parse(boxes, child_box.data)
            _ => ()
            // debug!("ignoring header box {}", ...)
          }
        }
        image_boxes = Some(boxes)
      }
      CONTIGUOUS_CODESTREAM =>
        parsed_codestream = Some(parse_raw(current_box.data, settings))
      _ => ()
    }
  }
  guard image_boxes is Some(image_boxes) else { raise Format(InvalidBox) }
  guard parsed_codestream is Some(parsed_codestream) else {
    raise Format(MissingCodestream)
  }
  if image_boxes.palette is Some(palette) &&
    image_boxes.component_mapping is None {
    // In theory, a cmap is required if we have pclr, but since there are
    // some files that don't seem to do so, we assume
    // that all channels are mapped via the palette in case not.
    let mappings = Array::makei(palette.columns.length(), i => {
      component_index: 0,
      mapping_type: Palette(column=i & 0xFF),
    })
    image_boxes.component_mapping = Some({ entries: mappings, })
  }
  let (color_space, has_alpha) = resolve_alpha_and_color_space(
    image_boxes,
    parsed_codestream.header,
    settings,
  )
  {
    codestream: parsed_codestream.data,
    header: parsed_codestream.header,
    boxes: image_boxes,
    settings,
    color_space,
    has_alpha,
  }
}
