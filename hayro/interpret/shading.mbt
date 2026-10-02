// Port of `hayro-interpret/src/shading.rs`: PDF shadings.

///|
/// The function supplied to a shading.
pub(all) enum ShadingFunction {
  /// A single function, which should be used to evaluate all components of the shading.
  Single(@function.Function)
  /// Multiple functions, one for each color component.
  Multiple(Array[@function.Function])
}

///|
/// Evaluate the shading function.
pub fn ShadingFunction::eval(
  self : ShadingFunction,
  input : Array[Float],
) -> Array[Float]? {
  match self {
    Single(s) => s.eval(input.copy())
    Multiple(m) => {
      // 1-in, 1-out function for each color component.
      let out = []
      for func in m {
        guard func.eval(input.copy()) is Some(v) else { return None }
        guard v.get(0) is Some(first) else { return None }
        out.push(first)
      }
      Some(out)
    }
  }
}

///|
/// The key of Rust's `f32::total_cmp`.
fn f32_total_cmp_key(x : Float) -> Int {
  let bits = x.reinterpret_as_int()
  bits ^ ((bits >> 31).reinterpret_as_uint() >> 1).reinterpret_as_int()
}

///|
fn ShadingFunction::stitching_bounds(self : ShadingFunction) -> Array[Float] {
  let bounds : Array[Float] = []
  match self {
    Single(function) => bounds.append(function.stitching_bounds())
    Multiple(functions) =>
      for function in functions {
        bounds.append(function.stitching_bounds())
      }
  }
  // `total_cmp` only considers bit-identical values equal, so stability
  // does not matter.
  bounds.sort_by((a, b) => f32_total_cmp_key(a).compare(f32_total_cmp_key(b)))
  // `dedup_by(|a, b| (*a - *b).abs() <= f32::EPSILON)`.
  let out : Array[Float] = []
  for b in bounds {
    match out.last() {
      Some(prev) if (b - prev).abs() <= F32_EPSILON => ()
      _ => out.push(b)
    }
  }
  out
}

///|
/// Rust's `f32::EPSILON`.
const F32_EPSILON : Float = 1.1920929e-7

///|
/// A type of shading.
pub(all) enum ShadingType {
  /// A function-based shading.
  /// The domain of the function.
  FunctionBased(
    domain~ : FixedArray[Float],
    /// A transform to apply to the shading.
    matrix~ : @kurbo.Affine,
    /// The function that should be used to evaluate the shading.
    function~ : ShadingFunction
  )
  /// A radial-axial shading.
  ///
  /// `coords`: for axial shadings, only the first 4 entries are relevant,
  /// representing the x/y coordinates of the first point and the coordinates
  /// for the second point. For radial shadings, the coordinates contain the
  /// x/y coordinates as well as the radius for both circles.
  /// The coordinates of the shading.
  RadialAxial(
    coords~ : FixedArray[Float],
    /// The domain of the shading.
    domain~ : FixedArray[Float],
    /// The function forming the basis of the shading.
    function~ : ShadingFunction,
    /// The extends in the left/right direction of the shading.
    extend~ : FixedArray[Bool],
    /// Whether the shading is axial or radial.
    axial~ : Bool
  )
  /// A triangle-mesh shading.
  /// The triangles making up the shading.
  TriangleMesh(
    triangles~ : Array[Triangle],
    /// An optional function used for calculating the sampled color values.
    function~ : ShadingFunction?
  )
  /// A coons-patch-mesh shading.
  /// The patches that make up the shading.
  CoonsPatchMesh(
    patches~ : Array[CoonsPatch],
    /// An optional function used for calculating the sampled color values.
    function~ : ShadingFunction?
  )
  /// A tensor-product-patch-mesh shading.
  /// The patches that make up the shading.
  TensorProductPatchMesh(
    patches~ : Array[TensorProductPatch],
    /// An optional function used for calculating the sampled color values.
    function~ : ShadingFunction?
  )
  /// A dummy shading that should just be drawn transparent.
  Dummy
}

///|
/// A PDF shading.
pub(all) struct Shading {
  priv cache_key : U128
  /// The type of shading.
  shading_type : ShadingType
  /// The color space of the shading.
  color_space : ColorSpace
  /// A clip path that should be applied to the shading.
  clip_path : @kurbo.BezPath?
  /// The background color of the shading.
  background : Array[Float]?
}

///|
fn Shading::new(
  dict : @hayro_syntax.Dict,
  stream : @hayro_syntax.Stream?,
  cache : Cache,
) -> Shading? {
  let cache_key = CacheKey::cache_key(dict)
  guard (dict.get("ShadingType") : Byte?) is Some(shading_num) else {
    return None
  }
  guard (dict.get("ColorSpace") : @hayro_syntax.Object?) is Some(cs_obj) else {
    return None
  }
  guard ColorSpace::new(cs_obj, cache) is Some(color_space) else { return None }
  let read_decode = () => {
    match (dict.get("Decode") : @hayro_syntax.PdfArray?) {
      Some(a) => Some((a.iter() : Iter[Float]).to_array())
      None => None
    }
  }
  let shading_type = match shading_num {
    1 => {
      let domain = match (dict.get_fixed("Domain", 4) : Array[Float]?) {
        Some(d) => FixedArray::from_array(d)
        None => [0.0, 1.0, 0.0, 1.0]
      }
      let matrix = match (dict.get_fixed("Matrix", 6) : Array[Double]?) {
        Some(m) => @kurbo.Affine::new(FixedArray::from_array(m))
        None => @kurbo.Affine::default()
      }
      guard read_function(dict, color_space) is Some(function) else {
        return None
      }
      ShadingType::FunctionBased(domain~, matrix~, function~)
    }
    2 | 3 => {
      let domain = match (dict.get_fixed("Domain", 2) : Array[Float]?) {
        Some(d) => FixedArray::from_array(d)
        None => [0.0, 1.0]
      }
      guard read_function(dict, color_space) is Some(function) else {
        return None
      }
      let extend = match (dict.get_fixed("Extend", 2) : Array[Bool]?) {
        Some(e) => FixedArray::from_array(e)
        None => [false, false]
      }
      let (coords, invalid) = if shading_num == 2 {
        guard (dict.get_fixed("Coords", 4) : Array[Float]?) is Some(read) else {
          return None
        }
        let invalid = f32_is_nearly_zero(read[0] - read[2]) &&
          f32_is_nearly_zero(read[1] - read[3])
        (
          ([read[0], read[1], read[2], read[3], 0.0, 0.0] : FixedArray[Float]),
          invalid,
        )
      } else {
        guard (dict.get_fixed("Coords", 6) : Array[Float]?) is Some(read) else {
          return None
        }
        let invalid = f32_is_nearly_zero(read[0] - read[3]) &&
          f32_is_nearly_zero(read[1] - read[4]) &&
          f32_is_nearly_zero(read[2] - read[5])
        (FixedArray::from_array(read), invalid)
      }
      let axial = shading_num == 2
      if invalid {
        ShadingType::Dummy
      } else {
        ShadingType::RadialAxial(domain~, function~, extend~, coords~, axial~)
      }
    }
    4 => {
      guard stream is Some(stream) else { return None }
      guard stream.decoded() is Ok(stream_data) else { return None }
      guard (dict.get("BitsPerCoordinate") : Byte?) is Some(bp_coord) else {
        return None
      }
      guard (dict.get("BitsPerComponent") : Byte?) is Some(bp_comp) else {
        return None
      }
      guard (dict.get("BitsPerFlag") : Byte?) is Some(bpf) else { return None }
      let function = read_function(dict, color_space)
      guard read_decode() is Some(decode) else { return None }
      guard read_free_form_triangles(
          stream_data,
          bpf,
          bp_coord,
          bp_comp,
          function is Some(_),
          decode,
        )
        is Some(triangles) else {
        return None
      }
      ShadingType::TriangleMesh(triangles~, function~)
    }
    5 => {
      guard stream is Some(stream) else { return None }
      guard stream.decoded() is Ok(stream_data) else { return None }
      guard (dict.get("BitsPerCoordinate") : Byte?) is Some(bp_coord) else {
        return None
      }
      guard (dict.get("BitsPerComponent") : Byte?) is Some(bp_comp) else {
        return None
      }
      let function = read_function(dict, color_space)
      guard read_decode() is Some(decode) else { return None }
      guard (dict.get("VerticesPerRow") : UInt?) is Some(vertices_per_row) else {
        return None
      }
      guard read_lattice_triangles(
          stream_data,
          bp_coord,
          bp_comp,
          function is Some(_),
          vertices_per_row,
          decode,
        )
        is Some(triangles) else {
        return None
      }
      ShadingType::TriangleMesh(triangles~, function~)
    }
    6 => {
      guard stream is Some(stream) else { return None }
      guard stream.decoded() is Ok(stream_data) else { return None }
      guard (dict.get("BitsPerCoordinate") : Byte?) is Some(bp_coord) else {
        return None
      }
      guard (dict.get("BitsPerComponent") : Byte?) is Some(bp_comp) else {
        return None
      }
      guard (dict.get("BitsPerFlag") : Byte?) is Some(bpf) else { return None }
      let function = read_function(dict, color_space)
      guard read_decode() is Some(decode) else { return None }
      guard read_coons_patch_mesh(
          stream_data,
          bpf,
          bp_coord,
          bp_comp,
          function is Some(_),
          decode,
        )
        is Some(patches) else {
        return None
      }
      ShadingType::CoonsPatchMesh(patches~, function~)
    }
    7 => {
      guard stream is Some(stream) else { return None }
      guard stream.decoded() is Ok(stream_data) else { return None }
      guard (dict.get("BitsPerCoordinate") : Byte?) is Some(bp_coord) else {
        return None
      }
      guard (dict.get("BitsPerComponent") : Byte?) is Some(bp_comp) else {
        return None
      }
      guard (dict.get("BitsPerFlag") : Byte?) is Some(bpf) else { return None }
      let function = read_function(dict, color_space)
      guard read_decode() is Some(decode) else { return None }
      guard read_tensor_product_patch_mesh(
          stream_data,
          bpf,
          bp_coord,
          bp_comp,
          function is Some(_),
          decode,
        )
        is Some(patches) else {
        return None
      }
      ShadingType::TensorProductPatchMesh(patches~, function~)
    }
    _ => return None
  }
  let bbox = match (dict.get("BBox") : @hayro_syntax.Rect?) {
    Some(r) => Some(rect_to_kurbo(r))
    None => None
  }
  let background = match (dict.get("Background") : @hayro_syntax.PdfArray?) {
    Some(a) => Some((a.iter() : Iter[Float]).to_array())
    None => None
  }
  Some({
    cache_key,
    shading_type,
    color_space,
    clip_path: match bbox {
      Some(r) => Some(r.to_path(0.1))
      None => None
    },
    background,
  })
}

///|
pub impl CacheKey for Shading with fn cache_key(self) {
  self.cache_key
}

///|
/// A triangle made up of three vertices.
pub struct Triangle {
  /// The first vertex.
  p0 : TriangleVertex
  /// The second vertex.
  p1 : TriangleVertex
  /// The third vertex.
  p2 : TriangleVertex
  priv kurbo_tri : @kurbo.Triangle
  priv d00 : Double
  priv d01 : Double
  priv d11 : Double
}

///|
/// Create a new triangle.
pub fn Triangle::new(
  p0 : TriangleVertex,
  p1 : TriangleVertex,
  p2 : TriangleVertex,
) -> Triangle {
  let v0 = p1.point.sub(p0.point)
  let v1 = p2.point.sub(p0.point)
  let d00 = v0.dot(v0)
  let d01 = v0.dot(v1)
  let d11 = v1.dot(v1)
  let kurbo_tri = @kurbo.Triangle::new(p0.point, p1.point, p2.point)
  { p0, p1, kurbo_tri, p2, d00, d01, d11, }
}

///|
/// Get the interpolated colors of the point from the triangle.
///
/// Returns `None` if the point is not inside of the triangle.
pub fn Triangle::interpolate(
  self : Triangle,
  pos : @kurbo.Point,
) -> ColorComponents {
  let (u, v, w) = self.barycentric_coords(pos)
  let result = []
  for i in 0..<self.p0.colors.length() {
    let c0 = self.p0.colors[i]
    let c1 = self.p1.colors[i]
    let c2 = self.p2.colors[i]
    result.push(u * c0 + v * c1 + w * c2)
  }
  result
}

///|
/// Return whether the point is contained within the triangle.
pub fn Triangle::contains_point(self : Triangle, pos : @kurbo.Point) -> Bool {
  self.kurbo_tri.winding(pos) != 0
}

///|
/// Return the bounding box of the triangle.
pub fn Triangle::bounding_box(self : Triangle) -> @kurbo.Rect {
  self.kurbo_tri.bounding_box()
}

///|
fn Triangle::barycentric_coords(
  self : Triangle,
  p : @kurbo.Point,
) -> (Float, Float, Float) {
  let (a, b, c) = (self.p0.point, self.p1.point, self.p2.point)
  let v0 = b.sub(a)
  let v1 = c.sub(a)
  let v2 = p.sub(a)
  let d00 = self.d00
  let d01 = self.d01
  let d11 = self.d11
  let d20 = v2.dot(v0)
  let d21 = v2.dot(v1)
  let denom = d00 * d11 - d01 * d01
  let v = (d11 * d20 - d01 * d21) / denom
  let w = (d00 * d21 - d01 * d20) / denom
  let u = (1.0 - v - w).to_float()
  (u, v.to_float(), w.to_float())
}

///|
/// A triangle vertex.
pub struct TriangleVertex {
  priv flag : UInt
  /// The position of the vertex.
  point : @kurbo.Point
  /// The color component of the vertex.
  colors : ColorComponents
}

///|
/// A coons patch.
pub struct CoonsPatch {
  /// The control points of the coons patch.
  control_points : FixedArray[@kurbo.Point]
  /// The colors at each corner of the coons patch.
  colors : FixedArray[ColorComponents]
}

///|
/// A tensor-product patch.
pub struct TensorProductPatch {
  /// The control points of the tensor-product patch (4x4 grid = 16 points).
  control_points : FixedArray[@kurbo.Point]
  /// The colors at each corner of the tensor-product patch.
  colors : FixedArray[ColorComponents]
}

///|
/// Map the point to the coordinates of the coons patch.
pub fn CoonsPatch::map_coordinate(
  self : CoonsPatch,
  p : @kurbo.Point,
) -> @kurbo.Point {
  let (u, v) = (p.x, p.y)
  let cp = self.control_points
  let c1 = @kurbo.CubicBez::new(cp[0], cp[11], cp[10], cp[9])
  let c2 = @kurbo.CubicBez::new(cp[3], cp[4], cp[5], cp[6])
  let d1 = @kurbo.CubicBez::new(cp[0], cp[1], cp[2], cp[3])
  let d2 = @kurbo.CubicBez::new(cp[9], cp[8], cp[7], cp[6])
  let sc = c1.eval(u).to_vec2().scale(1.0 - v) + c2.eval(u).to_vec2().scale(v)
  let sd = d1.eval(v).to_vec2().scale(1.0 - u) + d2.eval(v).to_vec2().scale(u)
  let sb = (c1.eval(0.0).to_vec2().scale(1.0 - u) +
    c1.eval(1.0).to_vec2().scale(u)).scale(1.0 - v) +
    (c2.eval(0.0).to_vec2().scale(1.0 - u) + c2.eval(1.0).to_vec2().scale(u)).scale(
      v,
    )
  (sc + sd - sb).to_point()
}

///|
/// Approximate the patch by triangles.
pub fn CoonsPatch::to_triangles(
  self : CoonsPatch,
  buffer : Array[Triangle],
) -> Unit {
  generate_patch_triangles(
    p => self.map_coordinate(p),
    p => self.interpolate(p),
    buffer,
  )
}

///|
/// Get the interpolated colors of the point from the patch.
pub fn CoonsPatch::interpolate(
  self : CoonsPatch,
  pos : @kurbo.Point,
) -> ColorComponents {
  bilinear_colors(self.colors, pos)
}

///|
/// The bilinear color interpolation shared by both patch types.
fn bilinear_colors(
  colors : FixedArray[ColorComponents],
  pos : @kurbo.Point,
) -> ColorComponents {
  let (u, v) = (pos.x, pos.y)
  let (c0, c1, c2, c3) = (colors[0], colors[1], colors[2], colors[3])
  let result = []
  for i in 0..<c0.length() {
    let val = (1.0 - u) * (1.0 - v) * c0[i].to_double() +
      u * (1.0 - v) * c3[i].to_double() +
      u * v * c2[i].to_double() +
      (1.0 - u) * v * c1[i].to_double()
    result.push(val.to_float())
  }
  result
}

///|
/// Evaluate Bernstein polynomial `B_i(t)` for tensor-product patches.
fn TensorProductPatch::bernstein(i : Int, t : Double) -> Double {
  // `powi` with a constant exponent is expanded into multiplications.
  match i {
    0 => {
      let s = 1.0 - t
      s * (s * s)
    }
    1 => {
      let s = 1.0 - t
      3.0 * t * (s * s)
    }
    2 => 3.0 * (t * t) * (1.0 - t)
    3 => t * (t * t)
    _ => 0.0
  }
}

///|
/// Map the point to the coordinates of the tensor product patch.
pub fn TensorProductPatch::map_coordinate(
  self : TensorProductPatch,
  p : @kurbo.Point,
) -> @kurbo.Point {
  let (u, v) = (p.x, p.y)
  let mut x = 0.0
  let mut y = 0.0
  fn idx(i : Int, j : Int) -> Int {
    match (i, j) {
      (0, 0) => 0
      (0, 1) => 1
      (0, 2) => 2
      (0, 3) => 3
      (1, 0) => 11
      (1, 1) => 12
      (1, 2) => 13
      (1, 3) => 4
      (2, 0) => 10
      (2, 1) => 15
      (2, 2) => 14
      (2, 3) => 5
      (3, 0) => 9
      (3, 1) => 8
      (3, 2) => 7
      (3, 3) => 6
      _ => abort("Invalid index")
    }
  }

  for i in 0..<4 {
    for j in 0..<4 {
      let control_point_idx = idx(i, j)
      let basis = TensorProductPatch::bernstein(i, u) *
        TensorProductPatch::bernstein(j, v)
      x += self.control_points[control_point_idx].x * basis
      y += self.control_points[control_point_idx].y * basis
    }
  }
  @kurbo.Point::new(x, y)
}

///|
/// Approximate the tensor product patch mesh by triangles.
pub fn TensorProductPatch::to_triangles(
  self : TensorProductPatch,
  buffer : Array[Triangle],
) -> Unit {
  generate_patch_triangles(
    p => self.map_coordinate(p),
    p => self.interpolate(p),
    buffer,
  )
}

///|
/// Get the interpolated colors of the point from the patch.
pub fn TensorProductPatch::interpolate(
  self : TensorProductPatch,
  pos : @kurbo.Point,
) -> ColorComponents {
  bilinear_colors(self.colors, pos)
}

///|
fn read_free_form_triangles(
  data : BytesView,
  bpf : Byte,
  bp_cord : Byte,
  bp_comp : Byte,
  has_function : Bool,
  decode : Array[Float],
) -> Array[Triangle]? {
  let triangles = []
  guard split_decode(decode) is Some((coords, decode)) else { return None }
  let reader = @hayro_syntax.BitReader::new(data)
  let helpers = InterpolationHelpers::new(
    bp_cord,
    bp_comp,
    coords[0],
    coords[1],
    coords[2],
    coords[3],
  )
  let read_single = (reader : @hayro_syntax.BitReader) => {
    helpers.read_triangle_vertex(reader, bpf, has_function, decode)
  }
  let mut a : TriangleVertex? = None
  let mut b : TriangleVertex? = None
  let mut c : TriangleVertex? = None
  while true {
    guard read_single(reader) is Some(first) else { break }
    if first.flag == 0 {
      guard read_single(reader) is Some(second) else { return None }
      guard read_single(reader) is Some(third) else { return None }
      a = Some(first)
      b = Some(second)
      c = Some(third)
    } else if first.flag == 1 {
      guard b is Some(b_) else { return None }
      a = Some(b_)
      guard c is Some(c_) else { return None }
      b = Some(c_)
      c = Some(first)
    } else if first.flag == 2 {
      guard c is Some(c_) else { return None }
      b = Some(c_)
      c = Some(first)
    }
    guard (a, b, c) is (Some(p0), Some(p1), Some(p2)) else { return None }
    if point_nearly_same(p0.point, p1.point) ||
      point_nearly_same(p1.point, p2.point) {
      continue
    }
    triangles.push(Triangle::new(p0, p1, p2))
  }
  Some(triangles)
}

///|
/// Common interpolation functions used across different shading types.
priv struct InterpolationHelpers {
  bp_coord : Int
  bp_comp : Int
  coord_max : Float
  comp_max : Float
  x_min : Float
  x_max : Float
  y_min : Float
  y_max : Float
}

///|
fn InterpolationHelpers::new(
  bp_coord : Byte,
  bp_comp : Byte,
  x_min : Float,
  x_max : Float,
  y_min : Float,
  y_max : Float,
) -> InterpolationHelpers {
  let coord_max = powi(2.0, bp_coord.to_int()) - 1.0
  let comp_max = powi(2.0, bp_comp.to_int()) - 1.0
  {
    bp_coord: bp_coord.to_int(),
    bp_comp: bp_comp.to_int(),
    coord_max,
    comp_max,
    x_min,
    x_max,
    y_min,
    y_max,
  }
}

///|
/// Rust's `u32 as f32`.
fn u32_as_f32(n : UInt) -> Float {
  n.to_uint64().to_double().to_float()
}

///|
fn InterpolationHelpers::interpolate_coord(
  self : InterpolationHelpers,
  n : UInt,
  d_min : Float,
  d_max : Float,
) -> Float {
  @function.interpolate(u32_as_f32(n), 0.0, self.coord_max, d_min, d_max)
}

///|
fn InterpolationHelpers::interpolate_comp(
  self : InterpolationHelpers,
  n : UInt,
  d_min : Float,
  d_max : Float,
) -> Float {
  @function.interpolate(u32_as_f32(n), 0.0, self.comp_max, d_min, d_max)
}

///|
fn InterpolationHelpers::read_point(
  self : InterpolationHelpers,
  reader : @hayro_syntax.BitReader,
) -> @kurbo.Point? {
  guard reader.read(self.bp_coord) is Some(xn) else { return None }
  let x = self.interpolate_coord(xn, self.x_min, self.x_max)
  guard reader.read(self.bp_coord) is Some(yn) else { return None }
  let y = self.interpolate_coord(yn, self.y_min, self.y_max)
  Some(@kurbo.Point::new(x.to_double(), y.to_double()))
}

///|
fn InterpolationHelpers::read_colors(
  self : InterpolationHelpers,
  reader : @hayro_syntax.BitReader,
  has_function : Bool,
  decode : ArrayView[Float],
) -> ColorComponents? {
  let colors = []
  if has_function {
    guard reader.read(self.bp_comp) is Some(n) else { return None }
    guard decode.get(0) is Some(d0) else { return None }
    guard decode.get(1) is Some(d1) else { return None }
    colors.push(self.interpolate_comp(n, d0, d1))
  } else {
    let num_components = decode.length() / 2
    for i in 0..<num_components {
      guard reader.read(self.bp_comp) is Some(n) else { return None }
      colors.push(self.interpolate_comp(n, decode[2 * i], decode[2 * i + 1]))
    }
  }
  Some(colors)
}

///|
fn InterpolationHelpers::read_triangle_vertex(
  self : InterpolationHelpers,
  reader : @hayro_syntax.BitReader,
  bpf : Byte,
  has_function : Bool,
  decode : ArrayView[Float],
) -> TriangleVertex? {
  guard reader.read(bpf.to_int()) is Some(flag) else { return None }
  guard self.read_point(reader) is Some(point) else { return None }
  guard self.read_colors(reader, has_function, decode) is Some(colors) else {
    return None
  }
  reader.align()
  Some({ flag, point, colors, })
}

///|
/// Split decode array into coordinate bounds and component decode values.
fn split_decode(
  decode : Array[Float],
) -> (FixedArray[Float], ArrayView[Float])? {
  if decode.length() < 4 {
    None
  } else {
    Some(([decode[0], decode[1], decode[2], decode[3]], decode[4:]))
  }
}

///|
/// Generate triangles from a grid of points using a mapping function.
fn generate_patch_triangles(
  map_coordinate : (@kurbo.Point) -> @kurbo.Point,
  interpolate : (@kurbo.Point) -> ColorComponents,
  buffer : Array[Triangle],
) -> Unit {
  let grid_size = 20
  let grid = Array::makei(grid_size, _ => {
    Array::make(grid_size, @kurbo.point_zero)
  })
  let n = (grid_size - 1).to_double()

  // Create grid by mapping unit square coordinates.
  for i in 0..<grid_size {
    for j in 0..<grid_size {
      let u = i.to_double() / n // 0.0 to 1.0 (left to right).
      let v = j.to_double() / n // 0.0 to 1.0 (top to bottom).

      // Map unit square coordinate to patch coordinate.
      let unit_point = @kurbo.Point::new(u, v)
      grid[i][j] = map_coordinate(unit_point)
    }
  }
  for i in 0..<(grid_size - 1) {
    for j in 0..<(grid_size - 1) {
      let p00 = grid[i][j]
      let p10 = grid[i + 1][j]
      let p01 = grid[i][j + 1]
      let p11 = grid[i + 1][j + 1]

      // Calculate unit square coordinates for color interpolation.
      let u0 = i.to_double() / n
      let u1 = (i + 1).to_double() / n
      let v0 = j.to_double() / n
      let v1 = (j + 1).to_double() / n

      // Create triangle vertices with interpolated colors.
      let v00 : TriangleVertex = {
        flag: 0,
        point: p00,
        colors: interpolate(@kurbo.Point::new(u0, v0)),
      }
      let v10 : TriangleVertex = {
        flag: 0,
        point: p10,
        colors: interpolate(@kurbo.Point::new(u1, v0)),
      }
      let v01 : TriangleVertex = {
        flag: 0,
        point: p01,
        colors: interpolate(@kurbo.Point::new(u0, v1)),
      }
      let v11 : TriangleVertex = {
        flag: 0,
        point: p11,
        colors: interpolate(@kurbo.Point::new(u1, v1)),
      }
      let inflate_point = (p : @kurbo.Point, mid : @kurbo.Point) => {
        let inflation_factor = 1.025
        mid.add_vec(p.sub(mid).scale(inflation_factor))
      }

      // Converting to triangles is lossy and can lead to gaps. To make this a bit better,
      // we slightly inflate the triangles.
      let inflate = (triangle : Triangle) => {
        let mid = triangle.kurbo_tri.centroid()
        {
          ..triangle,
          p0: { ..triangle.p0, point: inflate_point(triangle.p0.point, mid), },
          p1: { ..triangle.p1, point: inflate_point(triangle.p1.point, mid), },
          p2: { ..triangle.p2, point: inflate_point(triangle.p2.point, mid), },
        }
      }
      buffer.push(inflate(Triangle::new(v00, v10, v01)))
      buffer.push(inflate(Triangle::new(v10, v11, v01)))
    }
  }
}

///|
fn read_lattice_triangles(
  data : BytesView,
  bp_cord : Byte,
  bp_comp : Byte,
  has_function : Bool,
  vertices_per_row : UInt,
  decode : Array[Float],
) -> Array[Triangle]? {
  let lattices : Array[Array[TriangleVertex]] = []
  guard split_decode(decode) is Some((coords, decode)) else { return None }
  let reader = @hayro_syntax.BitReader::new(data)
  let helpers = InterpolationHelpers::new(
    bp_cord,
    bp_comp,
    coords[0],
    coords[1],
    coords[2],
    coords[3],
  )
  let read_single = (reader : @hayro_syntax.BitReader) => {
    guard helpers.read_point(reader) is Some(point) else { return None }
    guard helpers.read_colors(reader, has_function, decode) is Some(colors) else {
      return None
    }
    reader.align()
    Some(({ flag: 0, point, colors, } : TriangleVertex))
  }
  outer~: while true {
    let single_row = []
    for _k = 0U; _k < vertices_per_row; _k = _k + 1 {
      guard read_single(reader) is Some(next) else { break outer~ }
      single_row.push(next)
    }
    // Deviation: upstream loops forever (pushing empty rows) if
    // `VerticesPerRow` is 0.
    if single_row.is_empty() {
      break outer~
    }
    lattices.push(single_row)
  }
  let triangles = []
  // All rows are complete, so `vertices_per_row` fits into an `Int` here.
  let vertices_per_row = if lattices.is_empty() {
    0
  } else {
    vertices_per_row.reinterpret_as_int()
  }
  for i in 0..<(lattices.length() - 1) {
    for j in 0..<(vertices_per_row - 1) {
      triangles.push(
        Triangle::new(lattices[i][j], lattices[i + 1][j], lattices[i][j + 1]),
      )
      triangles.push(
        Triangle::new(
          lattices[i + 1][j + 1],
          lattices[i + 1][j],
          lattices[i][j + 1],
        ),
      )
    }
  }
  Some(triangles)
}

///|
fn read_coons_patch_mesh(
  data : BytesView,
  bpf : Byte,
  bp_coord : Byte,
  bp_comp : Byte,
  has_function : Bool,
  decode : Array[Float],
) -> Array[CoonsPatch]? {
  read_patch_mesh(data, bpf, bp_coord, bp_comp, has_function, decode, 12, (
    control_points,
    colors,
  ) => {
    let coons_points = FixedArray::make(12, @kurbo.point_zero)
    for i in 0..<12 {
      coons_points[i] = control_points[i]
    }
    { control_points: coons_points, colors, }
  })
}

///|
/// Generic patch mesh reading function that works for both Coons and Tensor Product patches.
fn[P] read_patch_mesh(
  data : BytesView,
  bpf : Byte,
  bp_coord : Byte,
  bp_comp : Byte,
  has_function : Bool,
  decode : Array[Float],
  control_points_count : Int,
  create_patch : (FixedArray[@kurbo.Point], FixedArray[ColorComponents]) -> P,
) -> Array[P]? {
  guard split_decode(decode) is Some((coords, decode)) else { return None }
  let reader = @hayro_syntax.BitReader::new(data)
  let helpers = InterpolationHelpers::new(
    bp_coord,
    bp_comp,
    coords[0],
    coords[1],
    coords[2],
    coords[3],
  )
  let read_colors = (reader : @hayro_syntax.BitReader) => {
    helpers.read_colors(reader, has_function, decode)
  }
  let mut prev_patch_points : FixedArray[@kurbo.Point]? = None
  let mut prev_patch_colors : FixedArray[ColorComponents]? = None
  let patches = []
  while reader.read(bpf.to_int()) is Some(flag) {
    let control_points = FixedArray::make(16, @kurbo.point_zero) // Always allocate 16, use subset as needed.
    let colors : FixedArray[ColorComponents] = [[], [], [], []]
    match flag {
      0 => {
        for i in 0..<control_points_count {
          guard helpers.read_point(reader) is Some(p) else { return None }
          control_points[i] = p
        }
        for i in 0..<4 {
          guard read_colors(reader) is Some(c) else { return None }
          colors[i] = c
        }
        prev_patch_points = Some(control_points.copy())
        prev_patch_colors = Some(colors.copy())
      }
      1..=3 => {
        guard prev_patch_points is Some(prev_points) else { return None }
        guard prev_patch_colors is Some(prev_colors) else { return None }
        copy_patch_control_points(flag, prev_points, control_points)
        match flag {
          1 => {
            colors[0] = prev_colors[1]
            colors[1] = prev_colors[2]
          }
          2 => {
            colors[0] = prev_colors[2]
            colors[1] = prev_colors[3]
          }
          3 => {
            colors[0] = prev_colors[3]
            colors[1] = prev_colors[0]
          }
          _ => panic()
        }
        for i in 4..<control_points_count {
          guard helpers.read_point(reader) is Some(p) else { return None }
          control_points[i] = p
        }
        guard read_colors(reader) is Some(c2) else { return None }
        colors[2] = c2
        guard read_colors(reader) is Some(c3) else { return None }
        colors[3] = c3
        prev_patch_points = Some(control_points.copy())
        prev_patch_colors = Some(colors.copy())
      }
      _ => break
    }
    patches.push(create_patch(control_points, colors))
  }
  Some(patches)
}

///|
fn copy_patch_control_points(
  flag : UInt,
  prev_control_points : FixedArray[@kurbo.Point],
  control_points : FixedArray[@kurbo.Point],
) -> Unit {
  match flag {
    1 => {
      control_points[0] = prev_control_points[3]
      control_points[1] = prev_control_points[4]
      control_points[2] = prev_control_points[5]
      control_points[3] = prev_control_points[6]
    }
    2 => {
      control_points[0] = prev_control_points[6]
      control_points[1] = prev_control_points[7]
      control_points[2] = prev_control_points[8]
      control_points[3] = prev_control_points[9]
    }
    3 => {
      control_points[0] = prev_control_points[9]
      control_points[1] = prev_control_points[10]
      control_points[2] = prev_control_points[11]
      control_points[3] = prev_control_points[0]
    }
    _ => ()
  }
}

///|
fn read_tensor_product_patch_mesh(
  data : BytesView,
  bpf : Byte,
  bp_coord : Byte,
  bp_comp : Byte,
  has_function : Bool,
  decode : Array[Float],
) -> Array[TensorProductPatch]? {
  read_patch_mesh(data, bpf, bp_coord, bp_comp, has_function, decode, 16, (
    control_points,
    colors,
  ) => { control_points, colors, })
}

///|
fn read_function(
  dict : @hayro_syntax.Dict,
  color_space : ColorSpace,
) -> ShadingFunction? {
  if (dict.get("Function") : @hayro_syntax.PdfArray?) is Some(arr) {
    let funcs = []
    for o in (arr.iter() : Iter[@hayro_syntax.Object]) {
      guard @function.Function::new(o) is Some(f) else { return None }
      funcs.push(f)
    }
    if funcs.length() != color_space.num_components() {
      // warn!("function array of shading has wrong size");
      return None
    }
    Some(Multiple(funcs))
  } else if (dict.get("Function") : @hayro_syntax.Object?) is Some(obj) {
    guard @function.Function::new(obj) is Some(f) else { return None }
    Some(Single(f))
  } else {
    None
  }
}
