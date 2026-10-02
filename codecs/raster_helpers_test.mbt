///|
fn webp_fnv1a(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
/// Decodes a base64-encoded WebP file: `<width>x<height> <has_alpha>
/// <FNV-1a of the buffer>` or `error`. Mirrors `decode_webp` in
/// `oracle/src/bin/gen_raster_golden.rs`.
fn webp_case(b64 : String) -> String {
  let data = @base64.decode(b64) catch { _ => return "bad base64" }
  let image = @codecs.decode_webp(data) catch { _ => return "error" }
  let h = webp_fnv1a(image.data).to_string(radix=16)
  "\{image.width}x\{image.height} \{image.has_alpha} \{String::make(16 - h.length(), '0')}\{h}"
}

///|
/// Decodes the first frame of a base64-encoded GIF file: `<width>x<height>
/// at <left>,<top> <FNV-1a of the RGBA buffer>`, `none` or `error`. Mirrors
/// `decode_gif` in `oracle/src/bin/gen_raster_golden.rs`.
fn gif_case(b64 : String) -> String {
  let data = @base64.decode(b64) catch { _ => return "bad base64" }
  let frame = @codecs.decode_gif_first_frame(data) catch { _ => return "error" }
  guard frame is Some(frame) else { return "none" }
  let h = webp_fnv1a(frame.rgba).to_string(radix=16)
  "\{frame.width}x\{frame.height} at \{frame.left},\{frame.top} \{String::make(16 - h.length(), '0')}\{h}"
}

///|
/// Decodes a base64-encoded image like upstream `RasterImage::new` decodes
/// it with the `image` crate: `<width>x<height> <color type> <FNV-1a of the
/// buffer> icc=<length of the non-empty ICC profile or none>` or `error:
/// <message>`. Mirrors `decode` in `oracle/src/bin/gen_image_golden.rs`.
fn image_case(format : String, b64 : String) -> String {
  let data = @base64.decode(b64) catch { _ => return "bad base64" }
  let (info, buf) = try {
    match format {
      "gif" => @codecs.decode_gif_image(data)
      "webp" => @codecs.decode_webp_image(data)
      _ => abort("unknown format")
    }
  } catch {
    @codecs.ImageError(msg) => return "error: \{msg}"
  }
  let h = webp_fnv1a(buf).to_string(radix=16)
  let color = match info.color {
    L8 => "L8"
    La8 => "La8"
    Rgb8 => "Rgb8"
    Rgba8 => "Rgba8"
    L16 => "L16"
    La16 => "La16"
    Rgb16 => "Rgb16"
    Rgba16 => "Rgba16"
  }
  let icc = match info.icc {
    Some(icc) if !icc.is_empty() => icc.length().to_string()
    _ => "none"
  }
  "\{info.width}x\{info.height} \{color} \{String::make(16 - h.length(), '0')}\{h} icc=\{icc}"
}
