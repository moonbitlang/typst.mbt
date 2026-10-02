// The hash inputs of the deduplication keys (upstream `Deduplicator` keys
// hashed with `typst_utils::hash128`, i.e. 128-bit SipHash-1-3 with zero
// keys). These feed exactly the byte streams of Rust's `Hash` impls (derived
// or handwritten upstream), so that the `<defs>` IDs are identical to
// upstream's:
//
// - integers are written little-endian with their width (`usize`/`isize`
//   as 8 bytes), `char` as `u32`, `bool` as `u8`;
// - enum discriminants (derived `Hash`, `mem::discriminant`) as `isize`;
// - slices/`Vec`s with a `usize` length prefix, `str` as its bytes followed
//   by `0xff`;
// - floats (`Scalar`, `AxisValue`, color components) by their bits;
// - `Bytes` (font data) as the `u128` of `hash128` of the data (`LazyHash`).

///|
fn hash_u16(h : @library.SipHasher128, v : UInt) -> Unit {
  h.write_u8((v & 0xFF).to_byte())
  h.write_u8(((v >> 8) & 0xFF).to_byte())
}

///|
fn hash_abs(h : @library.SipHasher128, v : @library.Abs) -> Unit {
  h.write_f64(v.to_raw())
}

///|
fn hash_ratio(h : @library.SipHasher128, v : @library.Ratio) -> Unit {
  h.write_f64(v.get())
}

///|
fn hash_angle(h : @library.SipHasher128, v : @library.Angle) -> Unit {
  h.write_f64(v.to_raw())
}

///|
fn hash_point(h : @library.SipHasher128, p : @library.Point) -> Unit {
  hash_abs(h, p.x)
  hash_abs(h, p.y)
}

///|
fn hash_size(
  h : @library.SipHasher128,
  s : @library.Axes[@library.Abs],
) -> Unit {
  hash_abs(h, s.x)
  hash_abs(h, s.y)
}

///|
fn hash_transform(h : @library.SipHasher128, ts : @library.Transform) -> Unit {
  hash_ratio(h, ts.sx)
  hash_ratio(h, ts.ky)
  hash_ratio(h, ts.kx)
  hash_ratio(h, ts.sy)
  hash_abs(h, ts.tx)
  hash_abs(h, ts.ty)
}

///|
/// `DedupId(char, u128)`.
fn hash_dedup_id(h : @library.SipHasher128, id : DedupId) -> Unit {
  h.write_u32(id.kind.to_int().reinterpret_as_uint())
  h.write_u128(id.hash)
}

///|
fn hash_curve(h : @library.SipHasher128, curve : @library.Curve) -> Unit {
  let items = curve.items()
  h.write_usize(items.length())
  for item in items {
    match item {
      Move(p) => {
        h.write_discriminant(0)
        hash_point(h, p)
      }
      Line(p) => {
        h.write_discriminant(1)
        hash_point(h, p)
      }
      Cubic(p1, p2, p3) => {
        h.write_discriminant(2)
        hash_point(h, p1)
        hash_point(h, p2)
        hash_point(h, p3)
      }
      Close => h.write_discriminant(3)
    }
  }
}

///|
/// Upstream's handwritten `impl Hash for ProcessColor`: the discriminant and
/// the bits of `to_vec4`.
fn hash_process_color(
  h : @library.SipHasher128,
  c : @library.ProcessColor,
) -> Unit {
  h.write_discriminant(
    match c {
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
  for x in c.to_vec4() {
    h.write_u32(x.reinterpret_as_uint())
  }
}

///|
fn hash_colorant(h : @library.SipHasher128, c : @library.SpotColorant) -> Unit {
  match c.name {
    None => h.write_discriminant(0)
    Some(name) => {
      h.write_discriminant(1)
      match name {
        All => h.write_discriminant(0)
        Custom(s) => {
          h.write_discriminant(1)
          h.write_str(s)
        }
      }
    }
  }
  hash_process_color(h, c.fallback)
}

///|
fn hash_color(h : @library.SipHasher128, color : @library.Color) -> Unit {
  match color {
    Process(c) => {
      h.write_discriminant(0)
      hash_process_color(h, c)
    }
    Spot(c) => {
      h.write_discriminant(1)
      hash_colorant(h, c.colorant)
      hash_ratio(h, c.tint)
    }
  }
}

///|
fn hash_relative(
  h : @library.SipHasher128,
  relative : @library.Smart[@library.RelativeTo],
) -> Unit {
  match relative {
    Auto => h.write_discriminant(0)
    Custom(r) => {
      h.write_discriminant(1)
      h.write_discriminant(
        match r {
          Self_ => 0
          Parent => 1
        },
      )
    }
  }
}

///|
fn hash_space(h : @library.SipHasher128, space : @library.ColorSpace) -> Unit {
  match space {
    Process(s) => {
      h.write_discriminant(0)
      h.write_discriminant(
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
      h.write_discriminant(1)
      hash_colorant(h, c)
    }
  }
}

///|
fn hash_stops(
  h : @library.SipHasher128,
  stops : Array[(@library.Color, @library.Ratio)],
) -> Unit {
  h.write_usize(stops.length())
  for stop in stops {
    hash_color(h, stop.0)
    hash_ratio(h, stop.1)
  }
}

///|
fn hash_gradient(
  h : @library.SipHasher128,
  gradient : @library.Gradient,
) -> Unit {
  match gradient {
    Linear(g) => {
      h.write_discriminant(0)
      hash_stops(h, g.stops)
      hash_angle(h, g.angle)
      hash_space(h, g.space)
      hash_relative(h, g.relative)
      h.write_bool(g.anti_alias)
    }
    Radial(g) => {
      h.write_discriminant(1)
      hash_stops(h, g.stops)
      hash_ratio(h, g.center.x)
      hash_ratio(h, g.center.y)
      hash_ratio(h, g.radius)
      hash_ratio(h, g.focal_center.x)
      hash_ratio(h, g.focal_center.y)
      hash_ratio(h, g.focal_radius)
      hash_space(h, g.space)
      hash_relative(h, g.relative)
      h.write_bool(g.anti_alias)
    }
    Conic(g) => {
      h.write_discriminant(2)
      hash_stops(h, g.stops)
      hash_angle(h, g.angle)
      hash_ratio(h, g.center.x)
      hash_ratio(h, g.center.y)
      hash_space(h, g.space)
      hash_relative(h, g.relative)
      h.write_bool(g.anti_alias)
    }
  }
}

///|
/// `hash128` of font data (upstream `Bytes` hashes as the `u128` of its
/// `LazyHash`), cached by the identity of the data.
let font_data_hashes : Array[(Bytes, @library.U128)] = []

///|
fn font_data_hash(data : Bytes) -> @library.U128 {
  for entry in font_data_hashes {
    if physical_equal(entry.0, data) {
      return entry.1
    }
  }
  let h = @library.SipHasher128::new()
  // `[u8]`: a length prefix, then the bytes.
  h.write_usize(data.length())
  h.write_bytes(data[:])
  let hash = h.finish128()
  font_data_hashes.push((data, hash))
  hash
}

///|
/// `impl Hash for FontInstance`: the font (its data and index), then the
/// variations (`SmallVec<[(Tag, AxisValue); 2]>`).
fn hash_font(h : @library.SipHasher128, font : @library.FontInstance) -> Unit {
  let inner = font.font()
  h.write_u128(font_data_hash(inner.data()))
  h.write_u32(inner.index())
  let variations = font.variations().0
  h.write_usize(variations.length())
  for v in variations {
    let (tag, value) = v
    // `Tag([u8; 4])`: hashed as a slice.
    let tag = tag.0
    h.write_usize(tag.length())
    for c in tag {
      h.write_u8(c.to_int().to_byte())
    }
    h.write_u32(Float::from_double(value.0).reinterpret_as_uint())
  }
}
