// Port of `hayro-svg/src/mask.rs`.

///|
priv struct ImageLuminanceMask {
  image : DynamicImage
  transform : @kurbo.Affine
  interpolate : Bool
}

///|
priv enum MaskKind {
  SoftMask(@interpret.SoftMask)
  Image(ImageLuminanceMask)
}

///|
fn SvgRenderer::get_mask_id(self : SvgRenderer, mask : MaskKind) -> Id {
  match mask {
    SoftMask(mask) => {
      let cache_key = @interpret.CacheKey::cache_key(mask)
      if !self.masks.contains(cache_key) {
        self.with_dummy(r => mask.interpret(r))
      }
      self.masks.insert_with(cache_key, () => MaskKind::SoftMask(mask))
    }
    Image(mask) => {
      let transform_key = @interpret.CacheKey::cache_key(mask.transform)
      let cache_key = @interpret.hash128(h => {
        h.write_u8(if mask.interpolate { b'\x01' } else { b'\x00' })
        h.write_u128(transform_key)
        h.write_bytes(mask.image.data)
      })
      self.masks.insert_with(cache_key, () => MaskKind::Image(mask))
    }
  }
}

///|
fn SvgRenderer::write_mask_defs(self : SvgRenderer) -> Unit {
  if self.masks.is_empty() {
    return
  }
  self.xml.start_element("defs")
  self.xml.write_attribute("id", "mask")
  let masks = self.masks.iter()
  for item in masks {
    let (id, mask) = item
    if mask is SoftMask(mask) &&
      mask.transfer_function() is Some(transfer_function) {
      self.write_transfer_function_filter(
        "f\{id}",
        mask.mask_type(),
        transfer_function,
      )
    }
    self.xml.start_element("mask")
    self.xml.write_attribute("id", id.to_string())
    self.xml.write_attribute("maskUnits", "userSpaceOnUse")
    match mask {
      SoftMask(mask) => {
        let filter_id = match mask.transfer_function() {
          Some(_) => Some("f\{id}")
          None => None
        }
        if mask.mask_type() != Luminosity || filter_id is Some(_) {
          self.xml.write_attribute("mask-type", "alpha")
        }
        if filter_id is Some(filter_id) {
          self.xml.start_element("g")
          self.xml.write_attribute("filter", "url(#\{filter_id})")
        }
        let bg_color = mask.background_color()
        let rgba8 = bg_color.to_rgba().to_rgba8()
        let black = @interpret.alpha_color_black.to_rgba8()
        let use_bg = rgba8[0] != black[0] ||
          rgba8[1] != black[1] ||
          rgba8[2] != black[2] ||
          rgba8[3] != black[3]
        if use_bg {
          let paint = @interpret.Paint::Color(bg_color)
          self.draw_path_impl(
            @kurbo.Rect::new(
              0.0,
              0.0,
              self.dimensions.0.to_double(),
              self.dimensions.1.to_double(),
            ).to_path(0.1),
            {
              transform: @kurbo.Affine::identity(),
              paint,
              soft_mask: None,
              blend_mode: Normal,
            },
            Fill(NonZero),
          )
          self.xml.start_element("g")
          self.xml.write_attribute("style", "isolation:isolate")
        }
        mask.interpret(self)
        if use_bg {
          self.xml.end_element()
        }
        if filter_id is Some(_) {
          self.xml.end_element()
        }
      }
      Image(i) => self.write_image(i.image, i.interpolate, None, i.transform)
    }
    self.xml.end_element()
  }
  self.xml.end_element()
}

///|
fn SvgRenderer::write_transfer_function_filter(
  self : SvgRenderer,
  id : String,
  mask_type : @interpret.MaskType,
  transfer_function : @interpret.TransferFunction,
) -> Unit {
  let table_values = sampled_transfer_function(transfer_function)
  self.xml.start_element("filter")
  self.xml.write_attribute("id", id)
  self.xml.write_attribute("filterUnits", "userSpaceOnUse")
  self.xml.write_attribute("x", "0")
  self.xml.write_attribute("y", "0")
  self.xml.write_attribute("width", f32_str(self.dimensions.0))
  self.xml.write_attribute("height", f32_str(self.dimensions.1))
  if mask_type == Luminosity {
    self.xml.start_element("feColorMatrix")
    self.xml.write_attribute("type", "luminanceToAlpha")
    self.xml.end_element()
  }
  self.xml.start_element("feComponentTransfer")
  self.xml.start_element("feFuncA")
  self.xml.write_attribute("type", "table")
  self.xml.write_attribute("tableValues", table_values)
  self.xml.end_element()
  self.xml.end_element()
  self.xml.end_element()
}

///|
fn sampled_transfer_function(
  transfer_function : @interpret.TransferFunction,
) -> String {
  let parts = []
  for i in 0..<=255 {
    parts.push(f32_str(transfer_function.apply(Float::from_int(i) / 255.0)))
  }
  parts.join(" ")
}
