// Port of `vello_common/src/paint.rs`.

///|
/// A premultiplied color, cached in `u8` form (the `f32` form is only used
/// by the `f32` pipeline).
priv struct PremulColor {
  premul_u8 : FixedArray[Int]
}

///|
/// Create a new premultiplied color from an alpha color.
fn PremulColor::from_alpha_color(color : AlphaColor) -> PremulColor {
  let premul = color.premultiply()
  { premul_u8: components_to_rgba8(premul), }
}

///|
/// A paint that needs to be resolved via its index.
priv enum Paint {
  /// A solid color.
  Solid(PremulColor)
  /// A paint that needs to be resolved via an index.
  Indexed(Int)
}

///|
/// The source of an image paint.
pub(all) enum ImageSource {
  /// Pixmap pixels travel with the scene packet.
  Pixmap(Pixmap)
}

///|
/// `ImageSource::may_have_transparency`.
fn ImageSource::may_have_transparency(self : ImageSource) -> Bool {
  match self {
    Pixmap(p) => p.may_have_transparency()
  }
}

///|
/// An image brush (`peniko::ImageBrush<ImageSource>`).
pub(all) struct Image {
  image : ImageSource
  sampler : ImageSampler
}

///|
/// A kind of paint that can be used for filling and stroking shapes
/// (`peniko::Brush<Image, Gradient>`).
pub(all) enum PaintType {
  Solid(AlphaColor)
  Gradient(Gradient)
  Image(Image)
}
