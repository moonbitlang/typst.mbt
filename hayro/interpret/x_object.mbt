// Port of `hayro-interpret/src/x_object.rs`.

///|
priv enum XObject {
  FormXObject(FormXObject)
  ImageXObject(ImageXObject)
}

///|
fn XObject::new(
  stream : @hayro_syntax.Stream,
  warning_sink : WarningSinkFn,
  cache : Cache,
  transfer_function : ActiveTransferFunction?,
) -> XObject? {
  let dict = stream.dict()
  guard (dict.get("Subtype") : @hayro_syntax.Name?) is Some(subtype) else {
    return None
  }
  match subtype.as_str() {
    "Image" =>
      match
        ImageXObject::new(
          stream,
          _ => None,
          warning_sink,
          cache,
          false,
          transfer_function,
        ) {
        Some(i) => Some(ImageXObject(i))
        None => None
      }
    "Form" =>
      match FormXObject::new(stream) {
        Some(f) => Some(FormXObject(f))
        None => None
      }
    _ => None
  }
}

///|
priv struct FormXObject {
  decoded : BytesView
  matrix : @kurbo.Affine
  bbox : FixedArray[Float]
  is_transparency_group : Bool
  dict : @hayro_syntax.Dict
  resources : @hayro_syntax.Dict
}

///|
fn FormXObject::new(stream : @hayro_syntax.Stream) -> FormXObject? {
  let dict = stream.dict()
  guard stream.decoded() is Ok(decoded) else { return None }
  let resources = (dict.get("Resources") : @hayro_syntax.Dict?).unwrap_or(
    @hayro_syntax.Dict::empty(),
  )
  let matrix = @kurbo.Affine::new(
    match (dict.get_fixed("Matrix", 6) : Array[Double]?) {
      Some(m) => FixedArray::from_array(m)
      None => [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    },
  )
  guard (dict.get_fixed("BBox", 4) : Array[Float]?) is Some(bbox) else {
    return None
  }
  let is_transparency_group = (dict.get("Group") : @hayro_syntax.Dict?)
    is Some(_)
  Some({
    decoded,
    matrix,
    is_transparency_group,
    bbox: FixedArray::from_array(bbox),
    dict,
    resources,
  })
}

///|
fn draw_xobject(
  x_object : XObject,
  resources : @hayro_syntax.Resources,
  context : Context,
  device : &Device,
) -> Unit {
  match x_object {
    FormXObject(f) => draw_form_xobject(resources, f, context, device)
    ImageXObject(i) => draw_image_xobject(i, context, device)
  }
}

///|
fn draw_form_xobject(
  resources : @hayro_syntax.Resources,
  x_object : FormXObject,
  context : Context,
  device : &Device,
) -> Unit {
  if !context.ocg_state.is_visible() {
    return
  }
  if !context.begin_nested_interpretation() {
    return
  }
  let has_oc = xobject_oc(x_object.dict, context)
  if !context.ocg_state.is_visible() {
    if has_oc {
      context.ocg_state.end_marked_content()
    }
    context.end_nested_interpretation()
    return
  }
  let iter = @hayro_syntax.TypedIter::new(x_object.decoded)
  context.path.truncate(0)
  context.save_state()
  context.pre_concat_affine(x_object.matrix)
  context.push_root_transform()
  if x_object.is_transparency_group {
    let gs = context.get().graphics_state
    let soft_mask = gs.soft_mask
    gs.soft_mask = None
    let blend_mode = gs.blend_mode
    gs.blend_mode = Normal
    device.push_transparency_group(gs.non_stroke_alpha, soft_mask, blend_mode)
    gs.non_stroke_alpha = 1.0
    gs.stroke_alpha = 1.0
  }
  device.push_clip_path({
    path: @kurbo.Rect::new(
      x_object.bbox[0].to_double(),
      x_object.bbox[1].to_double(),
      x_object.bbox[2].to_double(),
      x_object.bbox[3].to_double(),
    )
    .to_path(0.1)
    .transform(context.get().ctm),
    fill: NonZero,
  })
  interpret(
    iter,
    @hayro_syntax.Resources::from_parent(x_object.resources, resources),
    context,
    device,
  )
  device.pop_clip()
  if x_object.is_transparency_group {
    device.pop_transparency_group()
  }
  context.pop_root_transform()
  context.restore_state(device)
  if has_oc {
    context.ocg_state.end_marked_content()
  }
  context.end_nested_interpretation()
}

///|
fn draw_image_xobject(
  x_object : ImageXObject,
  context : Context,
  device : &Device,
) -> Unit {
  if !context.ocg_state.is_visible() {
    return
  }
  let has_oc = xobject_oc(x_object.stream.dict(), context)
  if !context.ocg_state.is_visible() {
    if has_oc {
      context.ocg_state.end_marked_content()
    }
    return
  }
  let width = x_object.width.to_double()
  let height = x_object.height.to_double()
  context.save_state()
  context.pre_concat_affine(
    @kurbo.Affine::new([1.0 / width, 0.0, 0.0, -1.0 / height, 0.0, 1.0]),
  )
  let transform = context.get().ctm
  let has_alpha = x_object.has_mask()
  let gs = context.get().graphics_state
  let mut soft_mask = gs.soft_mask
  gs.soft_mask = None
  let blend_mode = gs.blend_mode
  gs.blend_mode = Normal

  // If image has smask, the soft mask from the graphics state should be discarde.
  if has_alpha {
    soft_mask = None
  }
  device.push_transparency_group(gs.non_stroke_alpha, soft_mask, blend_mode)
  let image = if x_object.is_mask {
    Image::Stencil({ paint: context.get_paint(false), image_xobject: x_object, })
  } else {
    Image::Raster({ obj: x_object, })
  }
  device.draw_image(image, { transform, soft_mask: None, blend_mode: Normal, })
  device.pop_transparency_group()
  context.restore_state(device)
  if has_oc {
    context.ocg_state.end_marked_content()
  }
}

///|
fn xobject_oc(dict : @hayro_syntax.Dict, context : Context) -> Bool {
  guard (dict.get("OC") : @hayro_syntax.Dict?) is Some(oc_dict) else {
    return false
  }
  if dict.get_ref("OC") is Some(oc_ref) {
    context.ocg_state.begin_ocg(oc_dict, oc_ref.to_id())
  } else {
    context.ocg_state.begin_ocmd(oc_dict)
  }
  true
}

///|
priv struct ImageXObject {
  width : Int
  height : Int
  color_space : ColorSpace?
  cache : Cache
  interpolate : Bool
  is_mask : Bool
  is_stencil_mask : Bool
  stream : @hayro_syntax.Stream
  transfer_function : ActiveTransferFunction?
  warning_sink : WarningSinkFn
}

///|
fn ImageXObject::new(
  stream : @hayro_syntax.Stream,
  resolve_cs : (@hayro_syntax.Name) -> ColorSpace?,
  warning_sink : WarningSinkFn,
  cache : Cache,
  is_mask : Bool,
  transfer_function : ActiveTransferFunction?,
) -> ImageXObject? {
  let dict = stream.dict()
  let is_stencil_mask = match (dict.get("IM") : Bool?) {
    Some(b) => b
    None => (dict.get("ImageMask") : Bool?).unwrap_or(false)
  }
  let is_mask = is_mask || is_stencil_mask
  let image_cs = if is_mask {
    // Masks are always single-channel.
    Some(ColorSpace::device_gray())
  } else {
    let cs_obj : @hayro_syntax.Object? = match
      (dict.get("CS") : @hayro_syntax.Object?) {
      Some(o) => Some(o)
      None => dict.get("ColorSpace")
    }
    let from_obj = match cs_obj {
      Some(c) => ColorSpace::new(c, cache)
      None => None
    }
    match from_obj {
      Some(cs) => Some(cs)
      None =>
        // Inline images can also refer to color spaces by name.
        match cs_obj {
          Some(c) =>
            match c.into_name() {
              Some(n) => resolve_cs(n)
              None => None
            }
          None => None
        }
    }
  }
  let interpolate = match (dict.get("I") : Bool?) {
    Some(b) => b
    None => (dict.get("Interpolate") : Bool?).unwrap_or(false)
  }
  let width = match (dict.get("W") : UInt?) {
    Some(w) => w
    None =>
      match (dict.get("Width") : UInt?) {
        Some(w) => w
        None => return None
      }
  }
  let height = match (dict.get("H") : UInt?) {
    Some(h) => h
    None =>
      match (dict.get("Height") : UInt?) {
        Some(h) => h
        None => return None
      }
  }
  if width == 0 || height == 0 {
    return None
  }
  Some({
    width: width.reinterpret_as_int(),
    cache,
    height: height.reinterpret_as_int(),
    color_space: image_cs,
    warning_sink,
    transfer_function,
    interpolate,
    stream,
    is_mask,
    is_stencil_mask,
  })
}

///|
fn ImageXObject::decoded_mask(
  self : ImageXObject,
  target_dimension : (Int, Int)?,
) -> DecodedMask? {
  if !self.is_mask {
    return None
  }
  decode_mask(self, target_dimension)
}

///|
fn ImageXObject::decoded_raster(
  self : ImageXObject,
  target_dimension : (Int, Int)?,
) -> DecodedRaster? {
  if self.is_mask {
    return None
  }
  decode_raster(self, target_dimension)
}

///|
fn ImageXObject::width(self : ImageXObject) -> Int {
  self.width
}

///|
fn ImageXObject::height(self : ImageXObject) -> Int {
  self.height
}

///|
fn ImageXObject::stream(self : ImageXObject) -> @hayro_syntax.Stream {
  self.stream
}

///|
fn ImageXObject::has_mask(self : ImageXObject) -> Bool {
  let dict = self.stream.dict()
  dict.contains_key("SMaskInData") ||
  dict.contains_key("SMask") ||
  dict.contains_key("Mask")
}

///|
priv struct DecodedMask {
  luma : LumaData
}

///|
priv struct DecodedRaster {
  image : ImageData
  alpha : LumaData?
}

///|
priv struct DecodeContext {
  mut decoded_data : Bytes
  mut decoded_alpha : Bytes?
  width : Int
  height : Int
  scale_factors : (Float, Float)
  color_space : ColorSpace
  bits_per_component : Int
  decode_arr : Array[(Float, Float)]
}

///|
fn decode_context(
  obj : ImageXObject,
  target_dimension : (Int, Int)?,
) -> DecodeContext? {
  let dict = obj.stream.dict()
  let dict_bpc : Int? = match (dict.get("BPC") : Byte?) {
    Some(b) => Some(b.to_int())
    None =>
      match (dict.get("BitsPerComponent") : Byte?) {
        Some(b) => Some(b.to_int())
        None => None
      }
  }
  let color_space = obj.color_space
  let is_indexed = match obj.color_space {
    Some(cs) => cs.is_indexed()
    None => false
  }
  let decode_params : @hayro_syntax.ImageDecodeParams = {
    is_indexed,
    bpc: dict_bpc,
    num_components: match color_space {
      Some(c) => Some(c.num_components())
      None => None
    },
    target_dimension,
    width: obj.width,
    height: obj.height,
  }
  let decoded = match obj.stream.decoded_image(decode_params) {
    Ok(d) => d
    Err(_) => {
      (obj.warning_sink)(ImageDecodeFailure)
      return None
    }
  }
  let mut scale_x : Float = 1.0
  let mut scale_y : Float = 1.0
  let (width, height) = match decoded.image_data {
    Some(d) => {
      scale_x = Float::from_int(obj.width) / Float::from_int(d.width)
      scale_y = Float::from_int(obj.height) / Float::from_int(d.height)
      (d.width, d.height)
    }
    None => (obj.width, obj.height)
  }
  let color_space = match color_space {
    Some(cs) => cs
    None => {
      let from_image = match decoded.image_data {
        Some(i) =>
          match i.color_space {
            Some(Gray) => Some(ColorSpace::device_gray())
            Some(Rgb) => Some(ColorSpace::device_rgb())
            Some(Cmyk) => Some(ColorSpace::device_cmyk())
            Some(Unknown(_)) => None
            None => None
          }
        None => None
      }
      from_image.unwrap_or(ColorSpace::device_gray())
    }
  }
  let fallback_bpc = if obj.is_stencil_mask { 1 } else { 8 }
  let bits_per_component = match decoded.image_data {
    Some(i) => i.bits_per_component
    None => dict_bpc.unwrap_or(fallback_bpc)
  }
  let decode_arr_raw : @hayro_syntax.PdfArray? = match
    (dict.get("D") : @hayro_syntax.PdfArray?) {
    Some(a) => Some(a)
    None => dict.get("Decode")
  }
  let decode_arr = match decode_arr_raw {
    Some(a) => read_f32_pairs(a)
    None => color_space.default_decode_arr(Float::from_int(bits_per_component))
  }
  Some({
    decoded_data: decoded.data.to_owned(),
    decoded_alpha: match decoded.image_data {
      Some(i) => i.alpha
      None => None
    },
    width,
    height,
    scale_factors: (scale_x, scale_y),
    color_space,
    bits_per_component,
    decode_arr,
  })
}

///|
/// Read the pairs of an array (upstream `array.iter::<(f32, f32)>()`).
fn read_f32_pairs(a : @hayro_syntax.PdfArray) -> Array[(Float, Float)] {
  let result = []
  let iter = (a.iter() : Iter[@hayro_syntax.Object])
  while true {
    guard iter.next() is Some(o1) else { break }
    guard iter.next() is Some(o2) else { break }
    guard o1.into_f32() is Some(v1) && o2.into_f32() is Some(v2) else { break }
    result.push((v1, v2))
  }
  result
}

///|
fn decode_mask(
  obj : ImageXObject,
  target_dimension : (Int, Int)?,
) -> DecodedMask? {
  guard decode_context(obj, target_dimension) is Some(ctx) else { return None }
  let height = Ref(ctx.height)
  guard decode_mask_bytes(
      ctx.decoded_data,
      ctx.width,
      height,
      ctx.color_space,
      ctx.bits_per_component,
      ctx.decode_arr,
      // Note: The semantics between "normal" soft masks (i.e. masks defined in
      // the graphics state or via `Mask`/`SMask` are inverted compared to
      // stencil masks (defined via `ImageMask`). The former match the semantics
      // of normal alpha images, where 0 stands for invisible and MAX stands for
      // fully opaque. For stencil masks, it's the other way around: 1 means the
      // paint is visible, while 0 means it's invisible.
      obj.is_stencil_mask,
    )
    is Some(data) else {
    return None
  }
  Some({
    luma: {
      data,
      width: ctx.width,
      height: height.val,
      interpolate: obj.interpolate,
      scale_factors: ctx.scale_factors,
    },
  })
}

///|
fn decode_raster(
  obj : ImageXObject,
  target_dimension : (Int, Int)?,
) -> DecodedRaster? {
  guard decode_context(obj, target_dimension) is Some(ctx) else { return None }
  let height = Ref(ctx.height)
  let is_default_decode = pairs_eq(
    ctx.decode_arr,
    ctx.color_space.default_decode_arr(Float::from_int(ctx.bits_per_component)),
  )
  let is_inverted_default_decode = pairs_eq(
    ctx.decode_arr,
    ctx.color_space.inverted_default_decode_arr(
      Float::from_int(ctx.bits_per_component),
    ),
  )
  let image_data = if ctx.bits_per_component == 8 &&
    ToRgb::supports_u8(ctx.color_space) &&
    obj.transfer_function is None &&
    (is_default_decode || is_inverted_default_decode) {
    // This is actually the most common case, where the PDF is embedded
    // in such a way where we don't need to decode. In this case,
    // we can prevent the round-trip from f32 back to u8 and just return
    // the raw decoded data, which will already be in
    // RGB8/gray-scale with values between 0 and 255.
    let data = Array::from_iter(ctx.decoded_data.iter())
    guard fix_image_length(data, ctx.width, height, b'\x00', ctx.color_space)
      is Some(_) else {
      return None
    }
    if is_inverted_default_decode {
      for i in 0..<data.length() {
        data[i] = (255 - data[i].to_int()).to_byte()
      }
    }
    let data = Bytes::from_array(data)
    // Upstream mutates the decoded data in place and takes it for gray and
    // RGB images.
    ctx.decoded_data = if ctx.color_space.is_device_gray() ||
      ctx.color_space.is_device_rgb() {
      b""
    } else {
      data
    }
    if ctx.color_space.is_device_gray() {
      Some(
        ImageData::Luma({
          data,
          width: ctx.width,
          height: height.val,
          interpolate: obj.interpolate,
          scale_factors: ctx.scale_factors,
        }),
      )
    } else if ctx.color_space.is_device_rgb() {
      Some(
        ImageData::Rgb({
          data,
          width: ctx.width,
          height: height.val,
          interpolate: obj.interpolate,
          scale_factors: ctx.scale_factors,
        }),
      )
    } else {
      let output_buf = FixedArray::make(ctx.width * height.val * 3, b'\x00')
      guard ToRgb::convert_u8(ctx.color_space, data, output_buf) is Some(_) else {
        return None
      }
      Some(
        ImageData::Rgb({
          data: Bytes::from_array(output_buf),
          width: ctx.width,
          height: height.val,
          interpolate: obj.interpolate,
          scale_factors: ctx.scale_factors,
        }),
      )
    }
  } else {
    guard get_components(
        ctx.decoded_data,
        ctx.width,
        height.val,
        ctx.color_space,
        ctx.bits_per_component,
      )
      is Some(components) else {
      return None
    }
    guard apply_decode_array(
        components,
        ctx.color_space,
        ctx.bits_per_component,
        ctx.decode_arr,
      )
      is Some(f32_data) else {
      return None
    }
    guard fix_image_length(
        f32_data,
        ctx.width,
        height,
        (0.0 : Float),
        ctx.color_space,
      )
      is Some(_) else {
      return None
    }
    let rgb_data = get_rgb_data(
      f32_data,
      ctx.width,
      height.val,
      ctx.scale_factors,
      ctx.color_space,
      obj.interpolate,
    )
    let rgb_data = match (obj.transfer_function, rgb_data) {
      (Some(transfer_function), Some(rgb_data)) => {
        let apply_single = (data : Byte, function : @function.Function) => {
          match function.eval([Float::from_byte(data) / 255.0]) {
            Some(v) if v.length() > 0 => f32_as_u8(v[0] * 255.0 + 0.5)
            _ => data
          }
        }
        let d = FixedArray::from_iter(rgb_data.data.iter())
        match transfer_function {
          Single(s) =>
            for i in 0..<d.length() {
              d[i] = apply_single(d[i], s)
            }
          Four(f) =>
            for k in 0..<(d.length() / 3) {
              d[k * 3] = apply_single(d[k * 3], f[0])
              d[k * 3 + 1] = apply_single(d[k * 3 + 1], f[1])
              d[k * 3 + 2] = apply_single(d[k * 3 + 2], f[2])
            }
        }
        Some(RgbData::{ ..rgb_data, data: Bytes::from_array(d), })
      }
      (_, r) => r
    }
    match rgb_data {
      Some(r) => Some(ImageData::Rgb(r))
      None => None
    }
  }
  guard image_data is Some(image) else { return None }
  let matte = match resolve_matte(obj, ctx.color_space, target_dimension) {
    Some((alpha, matte_rgb)) if alpha.width == ctx.width &&
      alpha.height == height.val => Some((alpha, matte_rgb))
    _ => None
  }
  let (image, alpha) = match matte {
    Some((alpha, matte_rgb)) =>
      (unpremultiply(image, alpha.data, matte_rgb), Some(alpha))
    None =>
      // Use flatten here, so in case the alpha channel is invalid we can still
      // return the main image (see PDFJS-19611).
      (
        image,
        match
          resolve_alpha(
            obj,
            ctx,
            Some(image),
            ctx.color_space,
            ctx.bits_per_component,
            ctx.width,
            height,
            ctx.scale_factors,
            target_dimension,
          ) {
          Some(a) => a
          None => None
        },
      )
  }
  Some({ image, alpha, })
}

///|
fn pairs_eq(a : Array[(Float, Float)], b : Array[(Float, Float)]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i].0 != b[i].0 || a[i].1 != b[i].1 {
      return false
    }
  }
  true
}

///|
fn decode_mask_bytes(
  decoded_data : Bytes,
  width : Int,
  height : Ref[Int],
  color_space : ColorSpace,
  bits_per_component : Int,
  decode_arr : Array[(Float, Float)],
  invert : Bool,
) -> Bytes? {
  let default_decode = color_space.default_decode_arr(
    Float::from_int(bits_per_component),
  )
  let inverted_default = color_space.inverted_default_decode_arr(
    Float::from_int(bits_per_component),
  )
  let fast_path = bits_per_component == 8 &&
    (
      pairs_eq(decode_arr, default_decode) ||
      pairs_eq(decode_arr, inverted_default)
    )
  let data : Array[Byte] = if fast_path {
    let should_invert = invert != pairs_eq(decode_arr, inverted_default)
    let d = Array::from_iter(decoded_data.iter())
    if should_invert {
      for i in 0..<d.length() {
        d[i] = (255 - d[i].to_int()).to_byte()
      }
    }
    d
  } else {
    guard get_components(
        decoded_data,
        width,
        height.val,
        color_space,
        bits_per_component,
      )
      is Some(components) else {
      return None
    }
    guard apply_decode_array(
        components, color_space, bits_per_component, decode_arr,
      )
      is Some(f32_data) else {
      return None
    }
    if invert {
      f32_data.map(alpha => f32_as_u8((1.0 - alpha) * 255.0 + 0.5))
    } else {
      f32_data.map(alpha => f32_as_u8(alpha * 255.0 + 0.5))
    }
  }
  guard fix_image_length(data, width, height, b'\x00', color_space) is Some(_) else {
    return None
  }
  Some(Bytes::from_array(data))
}

///|
fn resolve_alpha(
  obj : ImageXObject,
  decoded : DecodeContext,
  image_data : ImageData?,
  color_space : ColorSpace,
  bits_per_component : Int,
  width : Int,
  height : Ref[Int],
  scale_factors : (Float, Float),
  target_dimension : (Int, Int)?,
) -> LumaData?? {
  let dict = obj.stream.dict()
  let alpha = if (dict.get("SMaskInData") : Byte?) is Some(b'\x01') {
    let smask_data = decoded.decoded_alpha
    decoded.decoded_alpha = None
    match smask_data {
      Some(data) => {
        let data = Array::from_iter(data.iter())
        guard fix_image_length(
            data,
            width,
            height,
            b'\x00',
            ColorSpace::device_gray(),
          )
          is Some(_) else {
          return None
        }
        Some(LumaData::{
          data: Bytes::from_array(data),
          width,
          height: height.val,
          interpolate: obj.interpolate,
          scale_factors,
        })
      }
      None => None
    }
    // Note: `SMASK` field takes precedence over `MASK`, so order matters here.
  } else if (match (dict.get("SMask") : @hayro_syntax.Stream?) {
      Some(s) => Some(s)
      None => (dict.get("Mask") : @hayro_syntax.Stream?)
    })
    is Some(s_mask) {
    guard ImageXObject::new(
        s_mask,
        _ => None,
        obj.warning_sink,
        obj.cache,
        true,
        None,
      )
      is Some(mask_obj) else {
      return None
    }
    match decode_mask(mask_obj, target_dimension) {
      Some(decoded) => Some(decoded.luma)
      None => None
    }
  } else if read_color_key_mask(dict) is Some(color_key_mask) {
    let mask_data = []

    // TODO: Make this less ugly.
    let nc = color_space.num_components()
    let raw_data = match image_data {
      Some(Luma(d)) if nc == 1 => d.data
      Some(Rgb(d)) if nc == 3 => d.data
      _ => decoded.decoded_data
    }
    guard get_components(
        raw_data,
        width,
        height.val,
        color_space,
        bits_per_component,
      )
      is Some(components) else {
      return None
    }
    for p in 0..<(components.length() / nc) {
      let mut mask_val = b'\x00'
      let n = @cmp.minimum(nc, color_key_mask.length() / 2)
      for c in 0..<n {
        let component = components[p * nc + c]
        if component > color_key_mask[c * 2 + 1] ||
          component < color_key_mask[c * 2] {
          mask_val = b'\xff'
        }
      }
      mask_data.push(mask_val)
    }
    guard fix_image_length(
        mask_data,
        width,
        height,
        b'\x00',
        ColorSpace::device_gray(),
      )
      is Some(_) else {
      return None
    }
    Some(LumaData::{
      data: Bytes::from_array(mask_data),
      width,
      height: height.val,
      interpolate: obj.interpolate,
      scale_factors,
    })
  } else {
    None
  }
  Some(alpha)
}

///|
/// Read a color key mask (upstream `dict.get::<SmallVec<[u16; 4]>>(MASK)`).
fn read_color_key_mask(dict : @hayro_syntax.Dict) -> Array[Int]? {
  guard (dict.get("Mask") : @hayro_syntax.PdfArray?) is Some(arr) else {
    return None
  }
  Some((arr.iter() : Iter[UInt16]).map(v => v.to_int()).collect())
}

///|
fn resolve_matte(
  obj : ImageXObject,
  color_space : ColorSpace,
  target_dimension : (Int, Int)?,
) -> (LumaData, FixedArray[Byte])? {
  let dict = obj.stream.dict()
  guard (dict.get("SMask") : @hayro_syntax.Stream?) is Some(s_mask) else {
    return None
  }
  guard (s_mask.dict().get("Matte") : @hayro_syntax.PdfArray?)
    is Some(matte_arr) else {
    return None
  }
  let matte : Array[Float] = (matte_arr.iter() : Iter[Float]).collect()
  if matte.length() != color_space.num_components() {
    return None
  }

  // In theory, matte needs to be applied in the image's original color space,
  // but we always do it in RGB for now.
  let matte_rgb = FixedArray::make(3, b'\x00')
  let _ = ToRgb::convert_f32(color_space, matte[:], matte_rgb, false)
  guard ImageXObject::new(
      s_mask,
      _ => None,
      obj.warning_sink,
      obj.cache,
      true,
      None,
    )
    is Some(mask_obj) else {
    return None
  }
  guard decode_mask(mask_obj, target_dimension) is Some(decoded) else {
    return None
  }
  Some((decoded.luma, matte_rgb))
}

///|
fn unpremultiply(
  image : ImageData,
  alpha : Bytes,
  matte_rgb : FixedArray[Byte],
) -> ImageData {
  match image {
    Rgb(rgb) => {
      let d = FixedArray::from_iter(rgb.data.iter())
      let n = @cmp.minimum(d.length() / 3, alpha.length())
      for p in 0..<n {
        let a = alpha[p]
        if a == 0 {
          continue
        }
        let inv_alpha = (255.0 : Float) / Float::from_byte(a)
        for c in 0..<3 {
          let m = Float::from_byte(matte_rgb[c])
          d[p * 3 + c] = f32_as_u8(
            m + (Float::from_byte(d[p * 3 + c]) - m) * inv_alpha,
          )
        }
      }
      Rgb({ ..rgb, data: Bytes::from_array(d), })
    }
    Luma(luma) => {
      let d = FixedArray::from_iter(luma.data.iter())
      let m = Float::from_byte(matte_rgb[0])
      let n = @cmp.minimum(d.length(), alpha.length())
      for i in 0..<n {
        let a = alpha[i]
        if a == 0 {
          continue
        }
        let inv_alpha = (255.0 : Float) / Float::from_byte(a)
        d[i] = f32_as_u8(m + (Float::from_byte(d[i]) - m) * inv_alpha)
      }
      Luma({ ..luma, data: Bytes::from_array(d), })
    }
  }
}

///|
fn get_rgb_data(
  decoded : Array[Float],
  width : Int,
  height : Int,
  scale_factors : (Float, Float),
  cs : ColorSpace,
  interpolate : Bool,
) -> RgbData? {
  // To prevent a panic when calling the `chunks` method.
  if cs.num_components() == 0 {
    return None
  }
  let output = FixedArray::make(width * height * 3, b'\x00')
  let _ = ToRgb::convert_f32(cs, decoded[:], output, false)
  Some({
    data: Bytes::from_array(output),
    width,
    height,
    interpolate,
    scale_factors,
  })
}

///|
impl CacheKey for ImageXObject with fn cache_key(self) {
  CacheKey::cache_key(self.stream)
}

///|
fn[T] fix_image_length(
  image : Array[T],
  width : Int,
  height : Ref[Int],
  filler : T,
  cs : ColorSpace,
) -> Unit? {
  let row_len = width * cs.num_components()
  if row_len * height.val <= image.length() {
    // Too much data (or just the right amount), truncate it.
    image.truncate(row_len * height.val)
  } else {
    // Too little data, adapt the height and pad.
    height.val = (image.length() + row_len - 1) / row_len
    if image.length() % row_len != 0 {
      let pad = row_len - image.length() % row_len
      for _ in 0..<pad {
        image.push(filler)
      }
    }
  }
  if width == 0 || height.val == 0 {
    None
  } else {
    Some(())
  }
}

///|
fn get_components(
  data : Bytes,
  width : Int,
  height : Int,
  color_space : ColorSpace,
  bits_per_component : Int,
) -> Array[Int]? {
  let result = match bits_per_component {
    1..=7 | 9..=15 => {
      let buf = []
      let bpc = bits_per_component
      let reader = @hayro_syntax.BitReader::new(data[:])
      let nc = color_space.num_components()
      for _ in 0..<height {
        for _ in 0..<width {
          for _ in 0..<nc {
            // See `stream_ccit_not_enough_data`, some images seemingly don't have
            // enough data, so we just pad with zeroes in this case.
            let next = reader.read(bpc).unwrap_or(0).reinterpret_as_int() &
              0xffff
            buf.push(next)
          }
        }
        reader.align()
      }
      buf
    }
    8 => data.iter().map(v => v.to_int()).collect()
    16 => {
      let buf = []
      let mut i = 0
      while i < data.length() {
        // `chunks(2)`: a trailing odd byte panics upstream (`v[1]`).
        guard i + 1 < data.length() else { abort("index out of bounds") }
        buf.push((data[i].to_int() << 8) | data[i + 1].to_int())
        i += 2
      }
      buf
    }
    _ =>
      // warn!("unsupported bits per component: {bits_per_component}");
      return None
  }
  Some(result)
}

///|
fn apply_decode_array(
  components : Array[Int],
  color_space : ColorSpace,
  bits_per_component : Int,
  decode : Array[(Float, Float)],
) -> Array[Float]? {
  let max = powi(2.0, bits_per_component) - 1.0
  let interpolate = (n : Float, d_min : Float, d_max : Float) => {
    @function.interpolate(n, 0.0, max, d_min, d_max)
  }
  let decoded_arr = []
  let nc = color_space.num_components()
  let mut start = 0
  while start < components.length() {
    let end = @cmp.minimum(start + nc, components.length())
    let n = @cmp.minimum(end - start, decode.length())
    for i in 0..<n {
      let (d_min, d_max) = decode[i]
      decoded_arr.push(
        interpolate(Float::from_int(components[start + i]), d_min, d_max),
      )
    }
    start = end
  }
  Some(decoded_arr)
}
