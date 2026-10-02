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
