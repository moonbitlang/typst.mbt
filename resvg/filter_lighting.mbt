// Port of `resvg/src/filter/lighting.rs`.

///|
let factor_1_2 : Float = 1.0 / 2.0

///|
let factor_1_3 : Float = 1.0 / 3.0

///|
let factor_1_4 : Float = 1.0 / 4.0

///|
let factor_2_3 : Float = 2.0 / 3.0

///|
priv struct Vector2 {
  x : Float
  y : Float
}

///|
fn Vector2::approx_zero(self : Vector2) -> Bool {
  @path.approx_eq_ulps(self.x, 0.0, 4) && @path.approx_eq_ulps(self.y, 0.0, 4)
}

///|
priv struct Vector3 {
  x : Float
  y : Float
  z : Float
}

///|
fn Vector3::dot(self : Vector3, other : Vector3) -> Float {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///|
fn Vector3::length(self : Vector3) -> Float {
  (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
}

///|
fn Vector3::normalized(self : Vector3) -> Vector3? {
  let length = self.length()
  if !@path.approx_eq_ulps(length, 0.0, 4) {
    Some({ x: self.x / length, y: self.y / length, z: self.z / length })
  } else {
    None
  }
}

///|
fn Vector3::add(self : Vector3, rhs : Vector3) -> Vector3 {
  { x: self.x + rhs.x, y: self.y + rhs.y, z: self.z + rhs.z }
}

///|
fn Vector3::sub(self : Vector3, rhs : Vector3) -> Vector3 {
  { x: self.x - rhs.x, y: self.y - rhs.y, z: self.z - rhs.z }
}

///|
priv struct Normal {
  factor : Vector2
  normal : Vector2
}

///|
fn Normal::new(factor_x : Float, factor_y : Float, nx : Int, ny : Int) -> Normal {
  {
    factor: { x: factor_x, y: factor_y },
    normal: { x: Float::from_int(-nx), y: Float::from_int(-ny) },
  }
}

///|
/// Renders a diffuse lighting.
///
/// - `src` pixels can have any alpha method, since only the alpha channel is used.
/// - `dest` will have an **unpremultiplied alpha**.
///
/// Does nothing when `src` is less than 3x3.
///
/// # Panics
///
/// - When `src` and `dest` have different sizes.
fn diffuse_lighting(
  fe : @usvg.FeDiffuseLighting,
  light_source : @usvg.LightSource,
  src : @skia.Pixmap,
  dest : @skia.Pixmap,
) -> Unit {
  guard! src.width() == dest.width() && src.height() == dest.height()
  let light_factor = fn(normal : Normal, light_vector : Vector3) -> Float {
    let k = if normal.normal.approx_zero() {
      light_vector.z
    } else {
      let s = fe.surface_scale / 255.0
      let n : Vector2 = { x: normal.normal.x * s, y: normal.normal.y * s }
      let n : Vector2 = { x: n.x * normal.factor.x, y: n.y * normal.factor.y }
      let normal : Vector3 = { x: n.x, y: n.y, z: 1.0 }
      normal.dot(light_vector) / normal.length()
    }
    fe.diffuse_constant * k
  }
  lighting_apply(
    light_source,
    fe.surface_scale,
    fe.lighting_color,
    light_factor,
    calc_diffuse_alpha,
    src,
    dest,
  )
}

///|
/// Renders a specular lighting.
///
/// - `src` pixels can have any alpha method, since only the alpha channel is used.
/// - `dest` will have a **premultiplied alpha**.
///
/// Does nothing when `src` is less than 3x3.
///
/// # Panics
///
/// - When `src` and `dest` have different sizes.
fn specular_lighting(
  fe : @usvg.FeSpecularLighting,
  light_source : @usvg.LightSource,
  src : @skia.Pixmap,
  dest : @skia.Pixmap,
) -> Unit {
  guard! src.width() == dest.width() && src.height() == dest.height()
  let light_factor = fn(normal : Normal, light_vector : Vector3) -> Float {
    let h = light_vector.add({ x: 0.0, y: 0.0, z: 1.0 })
    let h_length = h.length()
    if @path.approx_eq_ulps(h_length, 0.0, 4) {
      return 0.0
    }
    let k = if normal.normal.approx_zero() {
      let n_dot_h = h.z / h_length
      if @path.approx_eq_ulps(fe.specular_exponent, 1.0, 4) {
        n_dot_h
      } else {
        @skia.powf(n_dot_h, fe.specular_exponent)
      }
    } else {
      let s = fe.surface_scale / 255.0
      let n : Vector2 = { x: normal.normal.x * s, y: normal.normal.y * s }
      let n : Vector2 = { x: n.x * normal.factor.x, y: n.y * normal.factor.y }
      let normal : Vector3 = { x: n.x, y: n.y, z: 1.0 }
      let n_dot_h = normal.dot(h) / normal.length() / h_length
      if @path.approx_eq_ulps(fe.specular_exponent, 1.0, 4) {
        n_dot_h
      } else {
        @skia.powf(n_dot_h, fe.specular_exponent)
      }
    }
    fe.specular_constant * k
  }
  lighting_apply(
    light_source,
    fe.surface_scale,
    fe.lighting_color,
    light_factor,
    calc_specular_alpha,
    src,
    dest,
  )
}

///|
/// `alpha_at` of upstream's `ImageRef`.
fn alpha_at(data : FixedArray[UInt], width : Int, x : Int, y : Int) -> Int {
  px_a(data[width * y + x])
}

///|
/// Upstream `lighting::apply`.
fn lighting_apply(
  light_source : @usvg.LightSource,
  surface_scale : Float,
  lighting_color : @usvg.Color,
  light_factor : (Normal, Vector3) -> Float,
  calc_alpha : (Int, Int, Int) -> Int,
  src : @skia.Pixmap,
  dest : @skia.Pixmap,
) -> Unit {
  if src.width() < 3 || src.height() < 3 {
    return
  }
  let width = src.width()
  let height = src.height()
  let src_data = src.pixels()
  let dest_data = dest.pixels()

  // `feDistantLight` has a fixed vector, so calculate it beforehand.
  let mut light_vector : Vector3 = match light_source {
    DistantLight(light) => {
      let azimuth = @skia.to_radians(light.azimuth)
      let elevation = @skia.to_radians(light.elevation)
      {
        x: sincosf_cos(azimuth) * sincosf_cos(elevation),
        y: sincosf_sin(azimuth) * sincosf_cos(elevation),
        z: sincosf_sin(elevation),
      }
    }
    _ => { x: 1.0, y: 1.0, z: 1.0 }
  }
  let calc = fn(nx : Int, ny : Int, normal : Normal) {
    match light_source {
      DistantLight(_) => ()
      PointLight(light) => {
        let nz = Float::from_int(alpha_at(src_data, width, nx, ny)) / 255.0 *
          surface_scale
        let origin : Vector3 = { x: light.x, y: light.y, z: light.z }
        let v = origin.sub({ x: Float::from_int(nx), y: Float::from_int(ny), z: nz })
        light_vector = v.normalized().unwrap_or(v)
      }
      SpotLight(light) => {
        let nz = Float::from_int(alpha_at(src_data, width, nx, ny)) / 255.0 *
          surface_scale
        let origin : Vector3 = { x: light.x, y: light.y, z: light.z }
        let v = origin.sub({ x: Float::from_int(nx), y: Float::from_int(ny), z: nz })
        light_vector = v.normalized().unwrap_or(v)
      }
    }
    let light_color = light_color(light_source, lighting_color, light_vector)
    let factor = light_factor(normal, light_vector)
    let compute = fn(x : Int) -> Int {
      f32_to_u8(f32_bound(0.0, Float::from_int(x) * factor, 255.0) + 0.5)
    }
    let r = compute(light_color.red)
    let g = compute(light_color.green)
    let b = compute(light_color.blue)
    let a = calc_alpha(r, g, b)
    dest_data[width * ny + nx] = px_pack(r, g, b, a)
  }
  let img = (src_data, width, height)
  calc(0, 0, top_left_normal(img))
  calc(width - 1, 0, top_right_normal(img))
  calc(0, height - 1, bottom_left_normal(img))
  calc(width - 1, height - 1, bottom_right_normal(img))
  for x in 1..<(width - 1) {
    calc(x, 0, top_row_normal(img, x))
    calc(x, height - 1, bottom_row_normal(img, x))
  }
  for y in 1..<(height - 1) {
    calc(0, y, left_column_normal(img, y))
    calc(width - 1, y, right_column_normal(img, y))
  }
  for y in 1..<(height - 1) {
    for x in 1..<(width - 1) {
      calc(x, y, interior_normal(img, x, y))
    }
  }
}

///|
fn light_color(
  light : @usvg.LightSource,
  lighting_color : @usvg.Color,
  light_vector : Vector3,
) -> @usvg.Color {
  match light {
    DistantLight(_) | PointLight(_) => lighting_color
    SpotLight(light) => {
      let origin : Vector3 = { x: light.x, y: light.y, z: light.z }
      let direction : Vector3 = {
        x: light.points_at_x,
        y: light.points_at_y,
        z: light.points_at_z,
      }
      let direction = direction.sub(origin)
      let direction = direction.normalized().unwrap_or(direction)
      let minus_l_dot_s = -light_vector.dot(direction)
      if minus_l_dot_s <= 0.0 {
        return @usvg.Color::black()
      }
      if light.limiting_cone_angle is Some(limiting_cone_angle) {
        if minus_l_dot_s < @skia.cosf(@skia.to_radians(limiting_cone_angle)) {
          return @usvg.Color::black()
        }
      }
      let factor = @skia.powf(minus_l_dot_s, light.specular_exponent.get())
      let compute = fn(x : Int) -> Int {
        f32_to_u8(f32_bound(0.0, Float::from_int(x) * factor, 255.0) + 0.5)
      }
      @usvg.Color::new_rgb(
        compute(lighting_color.red),
        compute(lighting_color.green),
        compute(lighting_color.blue),
      )
    }
  }
}

///|
fn top_left_normal(img : (FixedArray[UInt], Int, Int)) -> Normal {
  let (d, w, _) = img
  let center = alpha_at(d, w, 0, 0)
  let right = alpha_at(d, w, 1, 0)
  let bottom = alpha_at(d, w, 0, 1)
  let bottom_right = alpha_at(d, w, 1, 1)
  Normal::new(
    factor_2_3,
    factor_2_3,
    -2 * center + 2 * right - bottom + bottom_right,
    -2 * center - right + 2 * bottom + bottom_right,
  )
}

///|
fn top_right_normal(img : (FixedArray[UInt], Int, Int)) -> Normal {
  let (d, w, _) = img
  let left = alpha_at(d, w, w - 2, 0)
  let center = alpha_at(d, w, w - 1, 0)
  let bottom_left = alpha_at(d, w, w - 2, 1)
  let bottom = alpha_at(d, w, w - 1, 1)
  Normal::new(
    factor_2_3,
    factor_2_3,
    -2 * left + 2 * center - bottom_left + bottom,
    -left - 2 * center + bottom_left + 2 * bottom,
  )
}

///|
fn bottom_left_normal(img : (FixedArray[UInt], Int, Int)) -> Normal {
  let (d, w, h) = img
  let top = alpha_at(d, w, 0, h - 2)
  let top_right = alpha_at(d, w, 1, h - 2)
  let center = alpha_at(d, w, 0, h - 1)
  let right = alpha_at(d, w, 1, h - 1)
  Normal::new(
    factor_2_3,
    factor_2_3,
    -top + top_right - 2 * center + 2 * right,
    -2 * top - top_right + 2 * center + right,
  )
}

///|
fn bottom_right_normal(img : (FixedArray[UInt], Int, Int)) -> Normal {
  let (d, w, h) = img
  let top_left = alpha_at(d, w, w - 2, h - 2)
  let top = alpha_at(d, w, w - 1, h - 2)
  let left = alpha_at(d, w, w - 2, h - 1)
  let center = alpha_at(d, w, w - 1, h - 1)
  Normal::new(
    factor_2_3,
    factor_2_3,
    -top_left + top - 2 * left + 2 * center,
    -top_left - 2 * top + left + 2 * center,
  )
}

///|
fn top_row_normal(img : (FixedArray[UInt], Int, Int), x : Int) -> Normal {
  let (d, w, _) = img
  let left = alpha_at(d, w, x - 1, 0)
  let center = alpha_at(d, w, x, 0)
  let right = alpha_at(d, w, x + 1, 0)
  let bottom_left = alpha_at(d, w, x - 1, 1)
  let bottom = alpha_at(d, w, x, 1)
  let bottom_right = alpha_at(d, w, x + 1, 1)
  Normal::new(
    factor_1_3,
    factor_1_2,
    -2 * left + 2 * right - bottom_left + bottom_right,
    -left - 2 * center - right + bottom_left + 2 * bottom + bottom_right,
  )
}

///|
fn bottom_row_normal(img : (FixedArray[UInt], Int, Int), x : Int) -> Normal {
  let (d, w, h) = img
  let top_left = alpha_at(d, w, x - 1, h - 2)
  let top = alpha_at(d, w, x, h - 2)
  let top_right = alpha_at(d, w, x + 1, h - 2)
  let left = alpha_at(d, w, x - 1, h - 1)
  let center = alpha_at(d, w, x, h - 1)
  let right = alpha_at(d, w, x + 1, h - 1)
  Normal::new(
    factor_1_3,
    factor_1_2,
    -top_left + top_right - 2 * left + 2 * right,
    -top_left - 2 * top - top_right + left + 2 * center + right,
  )
}

///|
fn left_column_normal(img : (FixedArray[UInt], Int, Int), y : Int) -> Normal {
  let (d, w, _) = img
  let top = alpha_at(d, w, 0, y - 1)
  let top_right = alpha_at(d, w, 1, y - 1)
  let center = alpha_at(d, w, 0, y)
  let right = alpha_at(d, w, 1, y)
  let bottom = alpha_at(d, w, 0, y + 1)
  let bottom_right = alpha_at(d, w, 1, y + 1)
  Normal::new(
    factor_1_2,
    factor_1_3,
    -top + top_right - 2 * center + 2 * right - bottom + bottom_right,
    -2 * top - top_right + 2 * bottom + bottom_right,
  )
}

///|
fn right_column_normal(img : (FixedArray[UInt], Int, Int), y : Int) -> Normal {
  let (d, w, _) = img
  let top_left = alpha_at(d, w, w - 2, y - 1)
  let top = alpha_at(d, w, w - 1, y - 1)
  let left = alpha_at(d, w, w - 2, y)
  let center = alpha_at(d, w, w - 1, y)
  let bottom_left = alpha_at(d, w, w - 2, y + 1)
  let bottom = alpha_at(d, w, w - 1, y + 1)
  Normal::new(
    factor_1_2,
    factor_1_3,
    -top_left + top - 2 * left + 2 * center - bottom_left + bottom,
    -top_left - 2 * top + bottom_left + 2 * bottom,
  )
}

///|
fn interior_normal(
  img : (FixedArray[UInt], Int, Int),
  x : Int,
  y : Int,
) -> Normal {
  let (d, w, _) = img
  let top_left = alpha_at(d, w, x - 1, y - 1)
  let top = alpha_at(d, w, x, y - 1)
  let top_right = alpha_at(d, w, x + 1, y - 1)
  let left = alpha_at(d, w, x - 1, y)
  let right = alpha_at(d, w, x + 1, y)
  let bottom_left = alpha_at(d, w, x - 1, y + 1)
  let bottom = alpha_at(d, w, x, y + 1)
  let bottom_right = alpha_at(d, w, x + 1, y + 1)
  Normal::new(
    factor_1_4,
    factor_1_4,
    -top_left + top_right - 2 * left + 2 * right - bottom_left + bottom_right,
    -top_left - 2 * top - top_right + bottom_left + 2 * bottom + bottom_right,
  )
}

///|
fn calc_diffuse_alpha(_r : Int, _g : Int, _b : Int) -> Int {
  255
}

///|
fn calc_specular_alpha(r : Int, g : Int, b : Int) -> Int {
  imax(imax(r, g), b)
}
