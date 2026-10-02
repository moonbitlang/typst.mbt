///|
/// FNV-1a (64 bit) of the premultiplied RGBA pixmap data.
fn fnv1a(data : Bytes) -> UInt64 {
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = h ^ b.to_uint64()
    h = h * 0x100000001b3UL
  }
  h
}

///|
/// Renders an SVG at a scale of 1.5 with `Options::default()`:
/// `<width>x<height> <hash>`, `none` or `error`. Mirrors `corpus_render` in
/// `oracle/src/bin/gen_resvg_golden.rs`.
fn corpus_render(svg : String) -> String {
  let tree = @usvg.Tree::from_data(@utf8.encode(svg), @usvg.Options::default()) catch {
    _ => return "error"
  }
  let scale : Float = 1.5
  guard tree.size().to_int_size().scale_by(scale) is Some(size) else {
    return "none"
  }
  guard @skia.Pixmap::new(size.width(), size.height()) is Some(pixmap) else {
    return "none"
  }
  @resvg.render(
    tree,
    @tiny_skia_path.Transform::from_scale(scale, scale),
    pixmap,
  )
  let h = fnv1a(pixmap.data()).to_string(radix=16)
  "\{pixmap.width()}x\{pixmap.height()} \{String::make(16 - h.length(), '0')}\{h}"
}
