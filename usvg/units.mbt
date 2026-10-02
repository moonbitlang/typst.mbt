// Port of `usvg` 0.47.0 `src/parser/units.rs`.

///|
fn convert_length(
  length : @svgtypes.Length,
  node : SvgNode,
  aid : AId,
  object_units : Units,
  state : State,
) -> Float {
  let dpi = state.opt.dpi
  let n = length.number.to_float()
  match length.unit {
    None | Px => n
    Em => n * resolve_font_size(node, state)
    Ex => n * resolve_font_size(node, state) / 2.0
    In => n * dpi
    Cm => n * dpi / 2.54
    Mm => n * dpi / 25.4
    Pt => n * dpi / 72.0
    Pc => n * dpi / 6.0
    Percent =>
      if object_units == ObjectBoundingBox {
        n / 100.0
      } else {
        let view_box = state.view_box
        match aid {
          AId::Cx
          | AId::Dx
          | AId::Fx
          | AId::MarkerWidth
          | AId::RefX
          | AId::Rx
          | AId::Width
          | AId::X
          | AId::X1
          | AId::X2 => convert_percent(length, view_box.width())
          AId::Cy
          | AId::Dy
          | AId::Fy
          | AId::Height
          | AId::MarkerHeight
          | AId::RefY
          | AId::Ry
          | AId::Y
          | AId::Y1
          | AId::Y2 => convert_percent(length, view_box.height())
          _ => {
            let mut vb_len = powi_f32(view_box.width(), 2) +
              powi_f32(view_box.height(), 2)
            vb_len = (vb_len / 2.0).sqrt()
            convert_percent(length, vb_len)
          }
        }
      }
  }
}

///|
fn convert_user_length(
  length : @svgtypes.Length,
  node : SvgNode,
  aid : AId,
  state : State,
) -> Float {
  convert_length(length, node, aid, UserSpaceOnUse, state)
}

///|
fn convert_list(node : SvgNode, aid : AId, state : State) -> Array[Float]? {
  let text : String? = node.attribute(aid)
  if text is Some(text) {
    let num_list = []
    let p = @svgtypes.LengthListParser::from(text)
    while p.next() is Some(length) {
      // `.flatten()` skips errors.
      if length is Ok(length) {
        num_list.push(convert_user_length(length, node, aid, state))
      }
    }
    Some(num_list)
  } else {
    None
  }
}

///|
fn convert_percent(length : @svgtypes.Length, base : Float) -> Float {
  base * length.number.to_float() / 100.0
}

///|
fn resolve_font_size(node : SvgNode, state : State) -> Float {
  let nodes = node.ancestors().collect()
  let mut font_size = state.opt.font_size
  // skip Root
  for i = nodes.length() - 2; i >= 0; i = i - 1 {
    let n = nodes[i]
    let length : @svgtypes.Length? = n.try_attribute(AId::FontSize)
    if length is Some(length) {
      let dpi = state.opt.dpi
      let n = length.number.to_float()
      font_size = match length.unit {
        None | Px => n
        Em => n * font_size
        Ex => n * font_size / 2.0
        In => n * dpi
        Cm => n * dpi / 2.54
        Mm => n * dpi / 25.4
        Pt => n * dpi / 72.0
        Pc => n * dpi / 6.0
        Percent =>
          // If `font-size` has percent units that it's value
          // is relative to the parent node `font-size`.
          length.number.to_float() * font_size * 0.01
      }
    } else {
      let name : String? = n.attribute(AId::FontSize)
      if name is Some(name) {
        font_size = convert_named_font_size(name, font_size)
      }
    }
  }
  font_size
}

///|
fn convert_named_font_size(name : String, parent_font_size : Float) -> Float {
  let factor = match name {
    "xx-small" => -3
    "x-small" => -2
    "small" => -1
    "medium" => 0
    "large" => 1
    "x-large" => 2
    "xx-large" => 3
    "smaller" => -1
    "larger" => 1
    _ =>
      // Upstream warns: Invalid 'font-size' value.
      0
  }

  // 'On a computer screen a scaling factor of 1.2 is suggested between adjacent indexes.'
  parent_font_size * powi_f32(1.2, factor)
}
