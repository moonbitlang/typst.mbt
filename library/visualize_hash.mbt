// Structural identity hashing ([Fingerprint]) of paints, strokes and frames,
// following upstream's `Hash` impls (`visualize/color.rs`, `gradient.rs`,
// `tiling.rs`, `stroke.rs`, `shape.rs`, `curve.rs`, `image/*.rs`,
// `text/item.rs`, `text/font/mod.rs`, `layout/frame.rs`, `model/link.rs`).
//
// Colors, color spaces, spot colorants, gradients, curves and fonts feed
// exactly the byte streams of Rust's `Hash` impls (derived or handwritten
// upstream): the SVG exporter hashes them into its deduplication keys, which
// are identical to upstream's (see `svg/hash.mbt` for the encoding rules).
// The other impls cover the same data in the same order; where upstream
// hashes a `LazyHash` or `Bytes` (the `u128` of the data's hash), the data
// is written inline or through a cache of its hash.

///|
fn SipHasher128::write_abs(self : SipHasher128, v : Abs) -> Unit {
  self.write_f64(v.to_raw())
}

///|
fn SipHasher128::write_ratio(self : SipHasher128, v : Ratio) -> Unit {
  self.write_f64(v.get())
}

///|
fn SipHasher128::write_size(self : SipHasher128, v : Axes[Abs]) -> Unit {
  self.write_f64(v.x.to_raw())
  self.write_f64(v.y.to_raw())
}

///|
/// Upstream's handwritten `impl Hash for ProcessColor`: the discriminant and
/// the bits of `to_vec4`.
pub impl Fingerprint for ProcessColor with fn fingerprint(self, state) {
  state.write_discriminant(
    match self {
      Luma(_) => 0
      Oklab(_) => 1
      Oklch(_) => 2
      Rgb(_) => 3
      LinearRgb(_) => 4
      Cmyk(_) => 5
      Hsl(_) => 6
      Hsv(_) => 7
    },
  )
  let vec = self.to_vec4()
  state.write_u32(vec[0].reinterpret_as_uint())
  state.write_u32(vec[1].reinterpret_as_uint())
  state.write_u32(vec[2].reinterpret_as_uint())
  state.write_u32(vec[3].reinterpret_as_uint())
}

///|
pub impl Fingerprint for SpotColorant with fn fingerprint(self, state) {
  match self.name {
    None => state.write_discriminant(0)
    Some(name) => {
      state.write_discriminant(1)
      match name {
        All => state.write_discriminant(0)
        Custom(s) => {
          state.write_discriminant(1)
          state.write_str(s)
        }
      }
    }
  }
  state.write(self.fallback)
}

///|
pub impl Fingerprint for Color with fn fingerprint(self, state) {
  match self {
    Process(c) => {
      state.write_discriminant(0)
      state.write(c)
    }
    Spot(c) => {
      state.write_discriminant(1)
      state.write(c.colorant)
      state.write_ratio(c.tint)
    }
  }
}

///|
pub impl Fingerprint for ColorSpace with fn fingerprint(self, state) {
  match self {
    Process(s) => {
      state.write_discriminant(0)
      state.write_discriminant(
        match s {
          Oklab => 0
          Oklch => 1
          Srgb => 2
          D65Gray => 3
          LinearRgb => 4
          Hsl => 5
          Hsv => 6
          Cmyk => 7
        },
      )
    }
    Spot(c) => {
      state.write_discriminant(1)
      state.write(c)
    }
  }
}

///|
/// `Smart<RelativeTo>`.
fn SipHasher128::write_relative(
  self : SipHasher128,
  relative : Smart[RelativeTo],
) -> Unit {
  match relative {
    Auto => self.write_discriminant(0)
    Custom(r) => {
      self.write_discriminant(1)
      self.write_discriminant(
        match r {
          Self_ => 0
          Parent => 1
        },
      )
    }
  }
}

///|
/// `Vec<(Color, Ratio)>`.
fn SipHasher128::write_stops(
  self : SipHasher128,
  stops : Array[(Color, Ratio)],
) -> Unit {
  self.write_usize(stops.length())
  for stop in stops {
    self.write(stop.0)
    self.write_ratio(stop.1)
  }
}

///|
/// Upstream derives `Hash` for `Gradient` and its variants: stops, the
/// geometry (angle, centers, radii), the color space, the relative placement
/// and the anti-aliasing flag.
pub impl Fingerprint for Gradient with fn fingerprint(self, state) {
  match self {
    Linear(g) => {
      state.write_discriminant(0)
      state.write_stops(g.stops)
      state.write_f64(g.angle.to_raw())
      state.write(g.space)
      state.write_relative(g.relative)
      state.write_bool(g.anti_alias)
    }
    Radial(g) => {
      state.write_discriminant(1)
      state.write_stops(g.stops)
      state.write_ratio(g.center.x)
      state.write_ratio(g.center.y)
      state.write_ratio(g.radius)
      state.write_ratio(g.focal_center.x)
      state.write_ratio(g.focal_center.y)
      state.write_ratio(g.focal_radius)
      state.write(g.space)
      state.write_relative(g.relative)
      state.write_bool(g.anti_alias)
    }
    Conic(g) => {
      state.write_discriminant(2)
      state.write_stops(g.stops)
      state.write_f64(g.angle.to_raw())
      state.write_ratio(g.center.x)
      state.write_ratio(g.center.y)
      state.write(g.space)
      state.write_relative(g.relative)
      state.write_bool(g.anti_alias)
    }
  }
}

///|
/// Upstream derives `Hash` for `TilingInner`: the frame (a `LazyHash`), the
/// size, spacing, offset, angle and relative placement.
pub impl Fingerprint for Tiling with fn fingerprint(self, state) {
  if !self.frame_hash.write_cached(state) {
    self.frame_hash.write(state, state => state.write(self.frame))
  }
  state.write_size(self.size)
  state.write_size(self.spacing)
  state.write_size(self.offset)
  state.write_f64(self.angle.to_raw())
  state.write_relative(self.relative)
}

///|
/// The [fingerprint_flags] of the tiling's frame.
pub fn Tiling::frame_fingerprint_flags(self : Tiling) -> Int {
  self.frame_hash.flags(state => state.write(self.frame))
}

///|
pub impl Fingerprint for Paint with fn fingerprint(self, state) {
  match self {
    Solid(color) => {
      state.write_discriminant(0)
      state.write(color)
    }
    Gradient(gradient) => {
      state.write_discriminant(1)
      state.write(gradient)
    }
    Tiling(tiling) => {
      state.write_discriminant(2)
      state.write(tiling)
    }
  }
}

///|
fn SipHasher128::write_cap(self : SipHasher128, cap : LineCap) -> Unit {
  self.write_discriminant(
    match cap {
      Butt => 0
      Round => 1
      Square => 2
    },
  )
}

///|
fn SipHasher128::write_join(self : SipHasher128, join : LineJoin) -> Unit {
  self.write_discriminant(
    match join {
      Miter => 0
      Round => 1
      Bevel => 2
    },
  )
}

///|
/// Upstream derives `Hash` for `Stroke<Length>`: paint, thickness, cap,
/// join, dash pattern and miter limit.
pub impl Fingerprint for Stroke with fn fingerprint(self, state) {
  match self.paint {
    Auto => state.write_discriminant(0)
    Custom(paint) => {
      state.write_discriminant(1)
      state.write(paint)
    }
  }
  match self.thickness {
    Auto => state.write_discriminant(0)
    Custom(thickness) => {
      state.write_discriminant(1)
      state.write(thickness)
    }
  }
  match self.cap {
    Auto => state.write_discriminant(0)
    Custom(cap) => {
      state.write_discriminant(1)
      state.write_cap(cap)
    }
  }
  match self.join {
    Auto => state.write_discriminant(0)
    Custom(join) => {
      state.write_discriminant(1)
      state.write_join(join)
    }
  }
  match self.dash {
    Auto => state.write_discriminant(0)
    Custom(None) => {
      state.write_discriminant(1)
      state.write_discriminant(0)
    }
    Custom(Some(dash)) => {
      state.write_discriminant(1)
      state.write_discriminant(1)
      state.write_usize(dash.array.length())
      for length in dash.array {
        match length {
          LineWidth => state.write_discriminant(0)
          Length(length) => {
            state.write_discriminant(1)
            state.write(length)
          }
        }
      }
      state.write(dash.phase)
    }
  }
  match self.miter_limit {
    Auto => state.write_discriminant(0)
    Custom(limit) => {
      state.write_discriminant(1)
      state.write_ratio(limit)
    }
  }
}

///|
/// Upstream derives `Hash` for `FixedStroke`.
pub impl Fingerprint for FixedStroke with fn fingerprint(self, state) {
  state.write(self.paint)
  state.write_abs(self.thickness)
  state.write_cap(self.cap)
  state.write_join(self.join)
  match self.dash {
    None => state.write_discriminant(0)
    Some(dash) => {
      state.write_discriminant(1)
      state.write_usize(dash.array.length())
      for length in dash.array {
        state.write_abs(length)
      }
      state.write_abs(dash.phase)
    }
  }
  state.write_ratio(self.miter_limit)
}

///|
pub impl Fingerprint for Curve with fn fingerprint(self, state) {
  let items = self.0
  state.write_usize(items.length())
  for item in items {
    match item {
      Move(p) => {
        state.write_discriminant(0)
        state.write(p)
      }
      Line(p) => {
        state.write_discriminant(1)
        state.write(p)
      }
      Cubic(p1, p2, p3) => {
        state.write_discriminant(2)
        state.write(p1)
        state.write(p2)
        state.write(p3)
      }
      Close => state.write_discriminant(3)
    }
  }
}

///|
pub impl Fingerprint for Transform with fn fingerprint(self, state) {
  state.write_ratio(self.sx)
  state.write_ratio(self.ky)
  state.write_ratio(self.kx)
  state.write_ratio(self.sy)
  state.write_abs(self.tx)
  state.write_abs(self.ty)
}

///|
/// Upstream derives `Hash` for `Shape`: geometry, fill, fill rule, stroke.
pub impl Fingerprint for Shape with fn fingerprint(self, state) {
  match self.geometry {
    Line(p) => {
      state.write_discriminant(0)
      state.write(p)
    }
    Rect(size) => {
      state.write_discriminant(1)
      state.write_size(size)
    }
    Curve(curve) => {
      state.write_discriminant(2)
      state.write(curve)
    }
  }
  state.write(self.fill)
  state.write_discriminant(
    match self.fill_rule {
      NonZero => 0
      EvenOdd => 1
    },
  )
  state.write(self.stroke)
}

///|
/// `hash128` of font data (upstream `Bytes` hashes as the `u128` of its
/// `LazyHash`), cached by the identity of the data.
let font_data_hashes : Array[(Bytes, U128)] = []

///|
fn font_data_hash(data : Bytes) -> U128 {
  for entry in font_data_hashes {
    if physical_equal(entry.0, data) {
      return entry.1
    }
  }
  let h = SipHasher128::new()
  // `[u8]`: a length prefix, then the bytes.
  h.write_usize(data.length())
  h.write_bytes(data[:])
  let hash = h.finish128()
  font_data_hashes.push((data, hash))
  hash
}

///|
/// Upstream `impl Hash for Font`: the data and the index.
pub impl Fingerprint for Font with fn fingerprint(self, state) {
  state.write_u128(font_data_hash(self.data))
  state.write_u32(self.index)
}

///|
/// Upstream `impl Hash for FontInstance`: the font, then the variations
/// (`SmallVec<[(Tag, AxisValue); 2]>`).
pub impl Fingerprint for FontInstance with fn fingerprint(self, state) {
  state.write(self.font)
  let variations = self.variations.0
  state.write_usize(variations.length())
  for v in variations {
    let (tag, value) = v
    // `Tag([u8; 4])`: hashed as a slice.
    let tag = tag.0
    state.write_usize(tag.length())
    for c in tag {
      state.write_u8(c.to_int().to_byte())
    }
    state.write_u32(Float::from_double(value.0).reinterpret_as_uint())
  }
}

///|
/// Upstream derives `Hash` for `Glyph`.
pub impl Fingerprint for Glyph with fn fingerprint(self, state) {
  state.write_u32(self.id.to_int().reinterpret_as_uint())
  state.write_f64(self.x_advance.get())
  state.write_f64(self.x_offset.get())
  state.write_f64(self.y_advance.get())
  state.write_f64(self.y_offset.get())
  state.write_u32(self.range_start.to_int().reinterpret_as_uint())
  state.write_u32(self.range_end.to_int().reinterpret_as_uint())
  state.write(self.span)
  state.write_u32(self.span_offset.to_int().reinterpret_as_uint())
}

///|
/// Upstream derives `Hash` for `TextItem`: font, size, fill, stroke,
/// language, region, text and glyphs.
pub impl Fingerprint for TextItem with fn fingerprint(self, state) {
  state.write(self.font)
  state.write_abs(self.size)
  state.write(self.fill)
  state.write(self.stroke)
  state.write_str(self.lang.0)
  match self.region {
    None => state.write_discriminant(0)
    Some(region) => {
      state.write_discriminant(1)
      state.write_str(region.0)
    }
  }
  state.write_str(self.text)
  state.write_usize(self.glyphs.length())
  for glyph in self.glyphs {
    state.write(glyph)
  }
}

///|
/// `Bytes`: upstream hashes the `u128` of the data's hash; the data itself
/// carries the same information.
fn SipHasher128::write_data(self : SipHasher128, data : Bytes) -> Unit {
  self.write_usize(data.length())
  self.write_bytes(data[:])
}

///|
/// Upstream derives `Hash` for `ImageInner` (kind, alt text, scaling) with
/// the handwritten impls of the kinds: raster images are defined by data,
/// format and ICC profile, SVGs by data and used fonts (and whether fonts
/// were resolved at all), PDF pages by the document's data and the page
/// index.
pub impl Fingerprint for Image with fn fingerprint(self, state) {
  match self.kind {
    Raster(raster) => {
      state.write_discriminant(0)
      state.write_data(raster.data)
      match raster.format {
        Exchange(format) => {
          state.write_discriminant(0)
          state.write_discriminant(
            match format {
              Png => 0
              Jpg => 1
              Gif => 2
              Webp => 3
            },
          )
        }
        Pixel(format) => {
          state.write_discriminant(1)
          state.write_discriminant(
            match format.encoding {
              Rgb8 => 0
              Rgba8 => 1
              Luma8 => 2
              Lumaa8 => 3
            },
          )
          state.write_i64(format.width.0)
          state.write_i64(format.height.0)
        }
      }
      match raster.icc {
        None => state.write_discriminant(0)
        Some(icc) => {
          state.write_discriminant(1)
          state.write_data(icc)
        }
      }
    }
    Svg(svg) => {
      state.write_discriminant(1)
      state.write_data(svg.data)
      state.write_bool(svg.resolved)
      state.write(svg.fonts)
    }
    Pdf(pdf) => {
      state.write_discriminant(2)
      state.write_data(pdf.document.data)
      state.write_usize(pdf.page_index)
    }
  }
  state.write(self.alt)
  match self.scaling {
    Auto => state.write_discriminant(0)
    Custom(scaling) => {
      state.write_discriminant(1)
      state.write_discriminant(
        match scaling {
          Smooth => 0
          Pixelated => 1
        },
      )
    }
  }
}

///|
/// Upstream derives `Hash` for `Destination`.
pub impl Fingerprint for Destination with fn fingerprint(self, state) {
  match self {
    Url(url) => {
      state.write_discriminant(0)
      state.write_str(url.0)
    }
    Position(position) => {
      state.write_discriminant(1)
      state.write(position)
    }
    Location(location) => {
      state.write_discriminant(2)
      state.write(location)
    }
  }
}

///|
/// Upstream derives `Hash` for `Frame`: size, baseline, items and kind.
///
/// Upstream keeps the items in a `LazyHash`; frames are mutable objects
/// here, so the items are hashed on every call (owners of immutable frames
/// cache the result, like [Tiling]).
pub impl Fingerprint for Frame with fn fingerprint(self, state) {
  state.write_size(self.size)
  match self.baseline {
    None => state.write_discriminant(0)
    Some(baseline) => {
      state.write_discriminant(1)
      state.write_abs(baseline)
    }
  }
  state.write_usize(self.items.length())
  for entry in self.items {
    state.write(entry.0)
    state.write(entry.1)
  }
  state.write_discriminant(
    match self.kind {
      Soft => 0
      Hard => 1
    },
  )
}

///|
/// Upstream derives `Hash` for `FrameItem`.
pub impl Fingerprint for FrameItem with fn fingerprint(self, state) {
  match self {
    Group(group) => {
      state.write_discriminant(0)
      state.write(group)
    }
    Text(text) => {
      state.write_discriminant(1)
      state.write(text)
    }
    Shape(shape, span) => {
      state.write_discriminant(2)
      state.write(shape)
      state.write(span)
    }
    Image(image, size, span) => {
      state.write_discriminant(3)
      state.write(image)
      state.write_size(size)
      state.write(span)
    }
    Link(dest, size) => {
      state.write_discriminant(4)
      state.write(dest)
      state.write_size(size)
    }
    Tag(tag) => {
      state.write_discriminant(5)
      state.write(tag)
    }
  }
}

///|
/// Upstream derives `Hash` for `GroupItem`: frame, transform, clip curve,
/// label and parent.
pub impl Fingerprint for GroupItem with fn fingerprint(self, state) {
  state.write(self.frame)
  state.write(self.transform)
  state.write(self.clip)
  state.write(self.label)
  match self.parent {
    None => state.write_discriminant(0)
    Some(parent) => {
      state.write_discriminant(1)
      state.write(parent.location)
      state.write_discriminant(
        match parent.inherit_ {
          Yes => 0
          No => 1
        },
      )
    }
  }
}
