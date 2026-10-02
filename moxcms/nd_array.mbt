// Port of the linear interpolators of `moxcms::nd_array` (`Hypercube`,
// `Cube`). `Vector3f` lerps use fused multiply-adds per component.

///|
/// `lerp(a, b, t) = a.neg_mla(a, t).mla(b, t)` on 3-component vectors.
fn lerp3(
  a : (Float, Float, Float),
  b : (Float, Float, Float),
  t : Float,
) -> (Float, Float, Float) {
  (
    mlaf(neg_mlaf(a.0, a.0, t), b.0, t),
    mlaf(neg_mlaf(a.1, a.1, t), b.1, t),
    mlaf(neg_mlaf(a.2, a.2, t), b.2, t),
  )
}

///|
/// 4D CLUT helper.
priv struct Hypercube {
  array : FixedArray[Float]
  x_stride : Int
  y_stride : Int
  z_stride : Int
  grid_size : FixedArray[Int]
}

///|
fn Hypercube::new_hypercube(
  array : FixedArray[Float],
  grid_size : FixedArray[Int],
  channels : Int,
) -> Hypercube raise CmsError {
  if array.length() == 0 ||
    grid_size[0] == 0 ||
    grid_size[1] == 0 ||
    grid_size[2] == 0 ||
    grid_size[3] == 0 {
    return { array, x_stride: 0, y_stride: 0, z_stride: 0, grid_size, }
  }
  let z_stride = grid_size[2]
  let y_stride = z_stride * grid_size[1]
  let x_stride = y_stride * grid_size[0]
  let last_index = (
      (grid_size[0] - 1).to_int64() * x_stride.to_int64() +
      (grid_size[1] - 1).to_int64() * y_stride.to_int64() +
      (grid_size[2] - 1).to_int64() * z_stride.to_int64() +
      (grid_size[3] - 1).to_int64()
    ) *
    channels.to_int64()
  if last_index >= array.length().to_int64() {
    raise MalformedClut({ size: array.length(), expected: last_index.to_int(), })
  }
  { array, x_stride, y_stride, z_stride, grid_size, }
}

///|
fn Hypercube::new(
  array : FixedArray[Float],
  grid_size : Int,
  channels : Int,
) -> Hypercube raise CmsError {
  if array.length() == 0 || grid_size == 0 {
    return {
      array,
      x_stride: 0,
      y_stride: 0,
      z_stride: 0,
      grid_size: [0, 0, 0, 0],
    }
  }
  let z_stride = grid_size
  let y_stride = z_stride * z_stride
  let x_stride = z_stride * z_stride * z_stride
  let g = (grid_size - 1).to_int64()
  let last_index = (
      g * x_stride.to_int64() +
      g * y_stride.to_int64() +
      g * z_stride.to_int64() +
      g
    ) *
    channels.to_int64()
  if last_index >= array.length().to_int64() {
    raise MalformedClut({ size: array.length(), expected: last_index.to_int(), })
  }
  {
    array,
    x_stride,
    y_stride,
    z_stride,
    grid_size: [grid_size, grid_size, grid_size, grid_size],
  }
}

///|
fn Hypercube::fetch(
  self : Hypercube,
  x : Int,
  y : Int,
  z : Int,
  w : Int,
) -> (Float, Float, Float) {
  let start = (x * self.x_stride + y * self.y_stride + z * self.z_stride + w) *
    3
  (self.array[start], self.array[start + 1], self.array[start + 2])
}

///|
fn floor_idx(v : Float, scale : Float) -> Int {
  @pxfm.f32_as_i32(@pxfm.min_f32(v.floor(), scale))
}

///|
fn ceil_idx(v : Float, scale : Float) -> Int {
  @pxfm.f32_as_i32(@pxfm.min_f32(v.ceil(), scale))
}

///|
fn Hypercube::quadlinear_vec3(
  self : Hypercube,
  lin_x : Float,
  lin_y : Float,
  lin_z : Float,
  lin_w : Float,
) -> (Float, Float, Float) {
  let lin_x = @pxfm.max_f32(lin_x, 0.0)
  let lin_y = @pxfm.max_f32(lin_y, 0.0)
  let lin_z = @pxfm.max_f32(lin_z, 0.0)
  let lin_w = @pxfm.max_f32(lin_w, 0.0)
  let scale_x = Float::from_int(self.grid_size[0] - 1)
  let scale_y = Float::from_int(self.grid_size[1] - 1)
  let scale_z = Float::from_int(self.grid_size[2] - 1)
  let scale_w = Float::from_int(self.grid_size[3] - 1)
  let x = floor_idx(lin_x * scale_x, scale_x)
  let y = floor_idx(lin_y * scale_y, scale_y)
  let z = floor_idx(lin_z * scale_z, scale_z)
  let w = floor_idx(lin_w * scale_w, scale_w)
  let x_n = ceil_idx(lin_x * scale_x, scale_x)
  let y_n = ceil_idx(lin_y * scale_y, scale_y)
  let z_n = ceil_idx(lin_z * scale_z, scale_z)
  let w_n = ceil_idx(lin_w * scale_w, scale_w)
  let x_d = lin_x * scale_x - Float::from_int(x)
  let y_d = lin_y * scale_y - Float::from_int(y)
  let z_d = lin_z * scale_z - Float::from_int(z)
  let w_d = lin_w * scale_w - Float::from_int(w)
  let r = (x : Int, y : Int, z : Int, w : Int) => self.fetch(x, y, z, w)
  let r_x1 = lerp3(r(x, y, z, w), r(x_n, y, z, w), x_d)
  let r_x2 = lerp3(r(x, y_n, z, w), r(x_n, y_n, z, w), x_d)
  let r_y1 = lerp3(r_x1, r_x2, y_d)
  let r_x3 = lerp3(r(x, y, z_n, w), r(x_n, y, z_n, w), x_d)
  let r_x4 = lerp3(r(x, y_n, z_n, w), r(x_n, y_n, z_n, w), x_d)
  let r_y2 = lerp3(r_x3, r_x4, y_d)
  let r_z1 = lerp3(r_y1, r_y2, z_d)
  let r_x1 = lerp3(r(x, y, z, w_n), r(x_n, y, z, w_n), x_d)
  let r_x2 = lerp3(r(x, y_n, z, w_n), r(x_n, y_n, z, w_n), x_d)
  let r_y1 = lerp3(r_x1, r_x2, y_d)
  let r_x3 = lerp3(r(x, y, z_n, w_n), r(x_n, y, z_n, w_n), x_d)
  let r_x4 = lerp3(r(x, y_n, z_n, w_n), r(x_n, y_n, z_n, w_n), x_d)
  let r_y2 = lerp3(r_x3, r_x4, y_d)
  let r_z2 = lerp3(r_y1, r_y2, z_d)
  lerp3(r_z1, r_z2, w_d)
}

///|
/// 3D CLUT helper.
priv struct Cube {
  array : FixedArray[Float]
  x_stride : Int
  y_stride : Int
  grid_size : FixedArray[Int]
}

///|
fn Cube::new(
  array : FixedArray[Float],
  grid_size : Int,
  channels : Int,
) -> Cube raise CmsError {
  if array.length() == 0 || grid_size == 0 {
    return { array, x_stride: 0, y_stride: 0, grid_size: [0, 0, 0], }
  }
  let y_stride = grid_size
  let x_stride = y_stride * y_stride
  let g = (grid_size - 1).to_int64()
  let last_index = (g * x_stride.to_int64() + g * y_stride.to_int64() + g) *
    channels.to_int64()
  if last_index >= array.length().to_int64() {
    raise MalformedClut({ size: array.length(), expected: last_index.to_int(), })
  }
  { array, x_stride, y_stride, grid_size: [grid_size, grid_size, grid_size], }
}

///|
fn Cube::new_cube(
  array : FixedArray[Float],
  grid_size : FixedArray[Int],
  channels : Int,
) -> Cube raise CmsError {
  if array.length() == 0 ||
    grid_size[0] == 0 ||
    grid_size[1] == 0 ||
    grid_size[2] == 0 {
    return { array, x_stride: 0, y_stride: 0, grid_size, }
  }
  let y_stride = grid_size[2]
  let x_stride = y_stride * grid_size[1]
  let last_index = (
      (grid_size[0] - 1).to_int64() * x_stride.to_int64() +
      (grid_size[1] - 1).to_int64() * y_stride.to_int64() +
      (grid_size[2] - 1).to_int64()
    ) *
    channels.to_int64()
  if last_index >= array.length().to_int64() {
    raise MalformedClut({ size: array.length(), expected: last_index.to_int(), })
  }
  { array, x_stride, y_stride, grid_size, }
}

///|
fn Cube::fetch(self : Cube, x : Int, y : Int, z : Int) -> (Float, Float, Float) {
  let start = (x * self.x_stride + y * self.y_stride + z) * 3
  (self.array[start], self.array[start + 1], self.array[start + 2])
}

///|
fn Cube::trilinear_vec3(
  self : Cube,
  lin_x : Float,
  lin_y : Float,
  lin_z : Float,
) -> (Float, Float, Float) {
  let lin_x = @pxfm.max_f32(lin_x, 0.0)
  let lin_y = @pxfm.max_f32(lin_y, 0.0)
  let lin_z = @pxfm.max_f32(lin_z, 0.0)
  let scale_x = Float::from_int(self.grid_size[0] - 1)
  let scale_y = Float::from_int(self.grid_size[1] - 1)
  let scale_z = Float::from_int(self.grid_size[2] - 1)
  let x = floor_idx(lin_x * scale_x, scale_x)
  let y = floor_idx(lin_y * scale_y, scale_y)
  let z = floor_idx(lin_z * scale_z, scale_z)
  let x_n = ceil_idx(lin_x * scale_x, scale_x)
  let y_n = ceil_idx(lin_y * scale_y, scale_y)
  let z_n = ceil_idx(lin_z * scale_z, scale_z)
  let x_d = lin_x * scale_x - Float::from_int(x)
  let y_d = lin_y * scale_y - Float::from_int(y)
  let z_d = lin_z * scale_z - Float::from_int(z)
  let c000 = self.fetch(x, y, z)
  let c100 = self.fetch(x_n, y, z)
  let c010 = self.fetch(x, y_n, z)
  let c110 = self.fetch(x_n, y_n, z)
  let c001 = self.fetch(x, y, z_n)
  let c101 = self.fetch(x_n, y, z_n)
  let c011 = self.fetch(x, y_n, z_n)
  let c111 = self.fetch(x_n, y_n, z_n)
  let c00 = lerp3(c000, c100, x_d)
  let c10 = lerp3(c010, c110, x_d)
  let c01 = lerp3(c001, c101, x_d)
  let c11 = lerp3(c011, c111, x_d)
  let c0 = lerp3(c00, c10, y_d)
  let c1 = lerp3(c01, c11, y_d)
  lerp3(c0, c1, z_d)
}
