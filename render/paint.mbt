// Port of `typst-render/src/paint.rs` (plus `Gradient::sample_at` from
// `typst-library/src/visualize/gradient.rs`).

///|
/// Sampling of a paint (solid colors, gradients and tilings) for glyph
/// bitmaps: returns the packed premultiplied color at the pixel position.
priv struct PaintSampler((UInt, UInt) -> UInt raise RenderPanic)

///|
fn PaintSampler::sample(
  self : PaintSampler,
  x : UInt,
  y : UInt,
) -> UInt raise RenderPanic {
  (self.0)(x, y)
}

///|
fn PaintSampler::solid(c : @skia.PremultipliedColorU8) -> PaintSampler {
  PaintSampler((_, _) => c.0)
}

///|
/// State used when sampling colors for text.
///
/// It caches the inverse transform to the parent, so that we can
/// reuse it instead of recomputing it for each pixel.
fn gradient_sampler(
  gradient : @library.Gradient,
  state : State,
  item_size : @library.Axes[@library.Abs],
  on_text : Bool,
) -> PaintSampler raise RenderPanic {
  let relative = gradient.unwrap_relative(on_text)
  let container_size = match relative {
    Self_ => item_size
    Parent => state.size
  }
  let fill_transform = match relative {
    Self_ => @path.Transform::identity()
    Parent => must(state.container_transform.invert())
  }
  let transform_to_parent = fill_transform
  let cw = to_f32(container_size.x)
  let ch = to_f32(container_size.y)
  PaintSampler((x, y) => {
    // Compute the point in the gradient's coordinate space.
    let point = transform_to_parent.map_point(
      @path.Point::from_xy(Float::from_uint(x), Float::from_uint(y)),
    )

    // Sample the gradient
    to_sk_color_u8(
      gradient_sample_at(gradient, point.x, point.y, cw, ch).to_process(),
    ).premultiply().0
  })
}

///|
/// State used when sampling tilings for text.
fn tiling_sampler(
  tiling : @library.Tiling,
  pixmap : @skia.Pixmap,
  state : State,
  on_text : Bool,
) -> PaintSampler raise RenderPanic {
  let relative = tiling.unwrap_relative(on_text)
  let fill_transform = match relative {
    Self_ => @path.Transform::identity()
    Parent => must(state.container_transform.invert())
  }
  let pattern_transform = to_sk_transform(tiling_transform(tiling))
  let size = tiling.size.add_size(tiling.spacing)
  let size_x = to_f32(size.x.times(state.pixel_per_pt.to_double()))
  let size_y = to_f32(size.y.times(state.pixel_per_pt.to_double()))
  let transform_to_parent = fill_transform.post_concat(
    pattern_transform.invert().unwrap_or(@path.Transform::identity()),
  )
  let pixel_per_pt = state.pixel_per_pt
  PaintSampler((x, y) => {
    // Compute the point in the tilings's coordinate space.
    let point = transform_to_parent.map_point(
      @path.Point::from_xy(Float::from_uint(x), Float::from_uint(y)),
    )
    let x = @skia.f32_to_u32(
      @skia.floorf(@skia.rem_euclid(point.x * pixel_per_pt, size_x)),
    )
    let y = @skia.f32_to_u32(
      @skia.floorf(@skia.rem_euclid(point.y * pixel_per_pt, size_y)),
    )

    // Sample the tilings
    must(pixmap.pixel(x, y)).0
  })
}

///|
/// `Tiling::transform`.
fn tiling_transform(tiling : @library.Tiling) -> @library.Transform {
  @library.Transform::translate(tiling.offset.x, tiling.offset.y).pre_concat(
    @library.Transform::rotate(tiling.angle),
  )
}

///|
/// Actual sampling of the gradient, cached for performance (upstream:
/// `comemo::memoize`).
fn gradient_pixmap(
  gradient : @library.Gradient,
  width : UInt,
  height : UInt,
  gradient_map : (@library.Point, @library.Axes[@library.Ratio])?,
) -> @skia.Pixmap raise RenderPanic {
  let (offset, scale) = match gradient_map {
    Some(m) => m
    None =>
      (@library.Point::zero(), @library.Axes::splat(@library.Ratio::one()))
  }
  let pixmap = must(
    @skia.Pixmap::new(
      if width > 1 {
        width
      } else {
        1
      },
      if height > 1 {
        height
      } else {
        1
      },
    ),
  )
  let pixels = pixmap.pixels()
  let w = width.reinterpret_as_int()
  let h = height.reinterpret_as_int()
  let wf = Float::from_uint(width)
  let hf = Float::from_uint(height)
  let ox = to_f32(offset.x)
  let oy = to_f32(offset.y)
  let sx = Float::from_double(scale.x.get())
  let sy = Float::from_double(scale.y.get())
  for x in 0..<w {
    for y in 0..<h {
      let color = gradient_sample_at(
        gradient,
        (Float::from_int(x) + ox) * sx,
        (Float::from_int(y) + oy) * sy,
        wf,
        hf,
      )
      pixels[y * w + x] = to_sk_color(color.to_process())
        .premultiply()
        .to_color_u8().0
    }
  }
  pixmap
}

///|
/// Transforms a [`Paint`] into a [`sk::Paint`].
/// Applying the necessary transform, if the paint is a gradient.
///
/// `gradient_map` is used to scale and move the gradient being sampled,
/// this is used to line up the stroke and the fill of a shape.
fn to_sk_paint(
  paint : @library.Paint,
  state : State,
  on_text : Bool,
  shape : @library.Shape?,
  include_stroke_in_bbox : Bool,
) -> @skia.Paint raise RenderPanic {
  let (item_size, fill_transform, gradient_map) = match shape {
    Some(shape) => {
      let bbox = @svg.shape_bbox(shape, include_stroke_in_bbox)
      let fill_transform = @path.Transform::from_translate(
        to_f32(bbox.min.x),
        to_f32(bbox.min.y),
      )
      let gradient_map = match shape.geometry {
        // Special handling for rectangles (mirrors gradients for negative
        // sizes)
        Rect(rect) => {
          let ppp = state.pixel_per_pt.to_double()
          let px = if rect.x.signum() < 0.0 {
            -bbox.size().x
          } else {
            @library.Abs::zero()
          }
          let py = if rect.y.signum() < 0.0 {
            -bbox.size().y
          } else {
            @library.Abs::zero()
          }
          Some(
            (
              @library.Point::{ x: px.times(ppp), y: py.times(ppp), },
              @library.Axes::{
                x: @library.Ratio::new(rect.x.signum()),
                y: @library.Ratio::new(rect.y.signum()),
              },
            ),
          )
        }
        _ => None
      }
      (bbox.size(), Some(fill_transform), gradient_map)
    }
    None => (@library.Axes::splat(@library.Abs::zero()), None, None)
  }
  let sk_paint = @skia.Paint::default()
  match paint {
    Solid(color) => {
      sk_paint.set_color(to_sk_color(color.to_process()))
      sk_paint.anti_alias = true
    }
    Gradient(gradient) => {
      let relative = gradient.unwrap_relative(on_text)
      let container_size = match relative {
        Self_ => item_size
        Parent => state.size
      }
      let fill_transform = match relative {
        Self_ => fill_transform.unwrap_or(@path.Transform::identity())
        Parent =>
          state.container_transform.post_concat(must(state.transform.invert()))
      }
      let gradient_map = match relative {
        Self_ => gradient_map
        Parent => None
      }
      let width = @skia.f32_to_u32(
        @skia.ceilf(@skia.fabs(to_f32(container_size.x)) * state.pixel_per_pt),
      )
      let height = @skia.f32_to_u32(
        @skia.ceilf(@skia.fabs(to_f32(container_size.y)) * state.pixel_per_pt),
      )
      let min = @skia.f32_to_u32(@skia.ceilf(state.pixel_per_pt))
      let pixmap = gradient_pixmap(
        gradient,
        if width > min {
          width
        } else {
          min
        },
        if height > min {
          height
        } else {
          min
        },
        gradient_map,
      )

      // We can use FilterQuality::Nearest here because we're
      // rendering to a pixmap that is already at native resolution.
      sk_paint.shader = @skia.Pattern::new(
        pixmap,
        Pad,
        Nearest,
        1.0,
        fill_transform.pre_scale(
          Float::from_double(container_size.x.signum()) / state.pixel_per_pt,
          Float::from_double(container_size.y.signum()) / state.pixel_per_pt,
        ),
      )
      sk_paint.anti_alias = gradient.anti_alias()
    }
    Tiling(tilings) => {
      let relative = tilings.unwrap_relative(on_text)
      let fill_transform = match relative {
        Self_ => fill_transform.unwrap_or(@path.Transform::identity())
        Parent =>
          state.container_transform.post_concat(must(state.transform.invert()))
      }
      let canvas = render_tiling_frame(state, tilings)
      let base_offset : @library.Point = match relative {
        Self_ =>
          match gradient_map {
            Some((offset, _)) => { x: -offset.x, y: -offset.y, }
            None => @library.Point::zero()
          }
        Parent => @library.Point::zero()
      }

      // Create the shader
      sk_paint.shader = @skia.Pattern::new(
        canvas,
        Repeat,
        Nearest,
        1.0,
        fill_transform
        .pre_concat(to_sk_transform(tiling_transform(tilings)))
        .pre_scale(
          (1.0 : Float) / state.pixel_per_pt,
          (1.0 : Float) / state.pixel_per_pt,
        )
        .pre_translate(to_f32(base_offset.x), to_f32(base_offset.y)),
      )
    }
  }
  sk_paint
}

///|
fn to_sk_color(color : @library.ProcessColor) -> @skia.Color raise RenderPanic {
  let c = color.to_rgb()
  must(@skia.Color::from_rgba(c.red, c.green, c.blue, c.alpha))
}

///|
fn to_sk_color_u8(color : @library.ProcessColor) -> @skia.ColorU8 {
  let c = color.to_rgb()
  @skia.ColorU8::from_rgba(
    f32_to_u8_stimulus(c.red),
    f32_to_u8_stimulus(c.green),
    f32_to_u8_stimulus(c.blue),
    f32_to_u8_stimulus(c.alpha),
  )
}

///|
/// Palette's `f32` to `u8` stimulus conversion (`into_format`): scales by
/// 255, clamps and rounds half to even.
fn f32_to_u8_stimulus(x : Float) -> Int {
  let max : Float = 255.0
  let scaled = @skia.fmin(x * max, max)
  let f = scaled + Float::reinterpret_from_uint(0x4b00_0000)
  let bits = f.reinterpret_as_uint()
  let c23 : UInt = 0x4b00_0000
  let v = if bits < c23 { 0U } else { bits - c23 }
  (v & 0xff).reinterpret_as_int()
}

///|
fn render_tiling_frame(
  state : State,
  tilings : @library.Tiling,
) -> @skia.Pixmap raise RenderPanic {
  let size = tilings.size.add_size(tilings.spacing)
  let canvas = must(
    @skia.Pixmap::new(
      @skia.f32_to_u32(@skia.roundf(to_f32(size.x) * state.pixel_per_pt)),
      @skia.f32_to_u32(@skia.roundf(to_f32(size.y) * state.pixel_per_pt)),
    ),
  )

  // Render the tilings into a new canvas.
  let ts = @path.Transform::from_scale(state.pixel_per_pt, state.pixel_per_pt)
  let temp_state = State::new(tilings.size, ts, state.pixel_per_pt)
  render_frame(canvas, temp_state, tilings.frame)
  canvas
}

///|
/// `Gradient::sample_at`: samples the gradient at a given position, in the
/// given container. Handles the aspect ratio and angle directly.
fn gradient_sample_at(
  gradient : @library.Gradient,
  x : Float,
  y : Float,
  width : Float,
  height : Float,
) -> @library.Color {
  // Normalize the coordinates.
  let mut x = x / width
  let mut y = y / height
  let t = match gradient {
    Linear(linear) => {
      // Aspect ratio correction.
      let angle = correct_aspect_ratio(
        linear.angle,
        @library.Ratio::new((width / height).to_double()),
      )
      let sin = angle.sin()
      let cos = angle.cos()
      let factor = sin.abs() + cos.abs()
      if angle.to_rad() > @math.PI / 2.0 &&
        angle.to_rad() < 3.0 * @math.PI / 2.0 {
        x = (1.0 : Float) - x
      }
      if angle.to_rad() > @math.PI {
        y = (1.0 : Float) - y
      }
      (x.to_double() * cos.abs() + y.to_double() * sin.abs()) / factor
    }
    Radial(radial) => {
      // Source: @Enivex - https://typst.app/project/pYLeS0QyCCe8mf0pdnwoAI
      let cr = radial.radius.get()
      let fr = radial.focal_radius.get()
      let zx = x.to_double()
      let zy = y.to_double()
      let px = radial.center.x.get()
      let py = radial.center.y.get()
      let qx = radial.focal_center.x.get()
      let qy = radial.focal_center.y.get()
      if kurbo_hypot(zx - qx, zy - qy) < fr {
        0.0
      } else if kurbo_hypot(zx - px, zy - py) > cr {
        1.0
      } else {
        let len = kurbo_hypot(zx - qx, zy - qy)
        let ux = (zx - qx) / len
        let uy = (zy - qy) / len
        let az = (qx - px) * ux + (qy - py) * uy
        let rho = cr * cr - ((qx - px) * (qx - px) + (qy - py) * (qy - py))
        let bz = (az * az + rho).sqrt() - az
        (kurbo_hypot(zx - qx, zy - qy) - fr) / (bz - fr)
      }
    }
    Conic(conic) => {
      // The x and y coordinates have been transformed into ratios to
      // compute the position relative to the gradient center.
      let x = x.to_double() - conic.center.x.get()
      let y = y.to_double() - conic.center.y.get()

      // Transform the angle computed from the ratio positions back
      // into the screen space, to correct for the aspect ratio.
      let sample_angle = correct_aspect_ratio(
        @library.Angle::atan2(y, x),
        @library.Ratio::new((width / height).to_double()),
      )

      // Negate conic angle for clockwise rotation.
      @library.Angle::raw(
        @library.Angle::rad(@math.PI).to_raw() +
        sample_angle.to_raw() -
        conic.angle.to_raw(),
      )
      .normalized()
      .to_rad() /
      (2.0 * @math.PI)
    }
  }
  let t = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
  gradient.sample(Ratio(@library.Ratio::new(t)))
}

///|
/// `kurbo::Vec2::hypot` (`hypot2().sqrt()`).
fn kurbo_hypot(x : Double, y : Double) -> Double {
  (x * x + y * y).sqrt()
}

///|
/// `Gradient::correct_aspect_ratio` (`Angle::atan2` uses the `libm` crate,
/// i.e. musl, like `@math.atan2`).
fn correct_aspect_ratio(
  angle : @library.Angle,
  aspect_ratio : @library.Ratio,
) -> @library.Angle {
  @library.Angle::rad(
    @math.atan2(angle.sin() / aspect_ratio.get().abs(), angle.cos()),
  ).normalized()
}

///|
/// A panic of upstream's renderer (an `unwrap` of `None`), which aborts the
/// rendering of the document.
pub suberror RenderPanic {
  RenderPanic(String)
} derive(Debug)

///|
fn[T] must(x : T?) -> T raise RenderPanic {
  match x {
    Some(v) => v
    None => raise RenderPanic("called `Option::unwrap()` on a `None` value")
  }
}
