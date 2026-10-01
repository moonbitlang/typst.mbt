// CMYK to sRGB conversion (upstream: `moxcms` 8-bit transform from the
// `CMYK-to-XYZ.icc` profile of `typst-assets` to sRGB, perceptual intent).

///|
/// Convert 8-bit CMYK components to 8-bit sRGB.
fn cmyk_to_srgb8(c : Int, m : Int, y : Int, k : Int) -> (Int, Int, Int) {
  // TODO: port the ICC transform. This is the naive conversion.
  let conv = (x : Int) => {
    let v = (255 - x) * (255 - k)
    (v + 127) / 255
  }
  (conv(c), conv(m), conv(y))
}
