// Port of `svgtypes` 0.16.1 `src/transform.rs`.

///|
/// Representation of the [`<transform>`] type.
///
/// [`<transform>`]: https://www.w3.org/TR/SVG2/coords.html#InterfaceSVGTransform
pub(all) struct Transform {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Eq, Debug)

///|
/// Constructs a new transform.
pub fn Transform::new(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> Transform {
  { a, b, c, d, e, f, }
}

///|
pub impl Default for Transform with fn default() {
  Transform::new(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
}

///|
pub extend Transform with Default::{default}

///|
/// Transform list token.
pub(all) enum TransformListToken {
  Matrix(
    a~ : Double,
    b~ : Double,
    c~ : Double,
    d~ : Double,
    e~ : Double,
    f~ : Double
  )
  Translate(tx~ : Double, ty~ : Double)
  Scale(sx~ : Double, sy~ : Double)
  Rotate(angle~ : Double)
  SkewX(angle~ : Double)
  SkewY(angle~ : Double)
} derive(Eq, Debug)

///|
/// A pull-based [`<transform-list>`] parser.
///
/// # Errors
///
/// - Most of the `Error` types can occur.
///
/// # Notes
///
/// - There are no separate `rotate(<rotate-angle> <cx> <cy>)` type.
///   It will be automatically split into three `Transform` tokens:
///   `translate(<cx> <cy>) rotate(<rotate-angle>) translate(-<cx> -<cy>)`.
///   Just like the spec is stated.
///
/// [`<transform-list>`]: https://www.w3.org/TR/SVG11/shapes.html#PointsBNF
pub struct TransformListParser {
  priv stream : Stream
  priv mut rotate_ts : (Double, Double)?
  priv mut last_angle : Double?
}

///|
pub fn TransformListParser::from(text : String) -> TransformListParser {
  { stream: Stream::from(text), rotate_ts: None, last_angle: None, }
}

///|
pub fn TransformListParser::next(
  self : TransformListParser,
) -> Result[TransformListToken, SvgTypesError]? {
  if self.last_angle is Some(a) {
    self.last_angle = None
    return Some(Ok(Rotate(angle=a)))
  }
  if self.rotate_ts is Some((x, y)) {
    self.rotate_ts = None
    return Some(Ok(Translate(tx=-x, ty=-y)))
  }
  self.stream.skip_spaces()
  if self.stream.at_end() {
    // empty attribute is still a valid value
    return None
  }
  let res = try self.parse_next() |> Ok catch {
    e => Err(e)
  }
  if res is Err(_) {
    self.stream.jump_to_end()
  }
  Some(res)
}

///|
pub fn TransformListParser::iter(
  self : TransformListParser,
) -> Iter[Result[TransformListToken, SvgTypesError]] {
  Iter::new(() => self.next())
}

///|
fn TransformListParser::parse_next(
  self : TransformListParser,
) -> TransformListToken raise SvgTypesError {
  let s = self.stream
  let start = s.pos()
  let name = s.consume_ascii_ident()
  s.skip_spaces()
  s.consume_byte(b'(')
  let t = match name {
    "matrix" => {
      let a = s.parse_list_number()
      let b = s.parse_list_number()
      let c = s.parse_list_number()
      let d = s.parse_list_number()
      let e = s.parse_list_number()
      let f = s.parse_list_number()
      Matrix(a~, b~, c~, d~, e~, f~)
    }
    "translate" => {
      let x = s.parse_list_number()
      s.skip_spaces()
      let y = if s.is_curr_byte_eq(b')') {
        // 'If <ty> is not provided, it is assumed to be zero.'
        0.0
      } else {
        s.parse_list_number()
      }
      Translate(tx=x, ty=y)
    }
    "scale" => {
      let x = s.parse_list_number()
      s.skip_spaces()
      let y = if s.is_curr_byte_eq(b')') {
        // 'If <sy> is not provided, it is assumed to be equal to <sx>.'
        x
      } else {
        s.parse_list_number()
      }
      Scale(sx=x, sy=y)
    }
    "rotate" => {
      let a = s.parse_list_number()
      s.skip_spaces()
      if !s.is_curr_byte_eq(b')') {
        // 'If optional parameters <cx> and <cy> are supplied, the rotate is about the
        // point (cx, cy). The operation represents the equivalent of the following
        // specification:
        // translate(<cx>, <cy>) rotate(<rotate-angle>) translate(-<cx>, -<cy>).'
        let cx = s.parse_list_number()
        let cy = s.parse_list_number()
        self.rotate_ts = Some((cx, cy))
        self.last_angle = Some(a)
        Translate(tx=cx, ty=cy)
      } else {
        Rotate(angle=a)
      }
    }
    "skewX" => SkewX(angle=s.parse_list_number())
    "skewY" => SkewY(angle=s.parse_list_number())
    _ => raise UnexpectedData(s.calc_char_pos_at(start))
  }
  s.skip_spaces()
  s.consume_byte(b')')
  s.skip_spaces()
  if s.is_curr_byte_eq(b',') {
    s.advance(1)
  }
  t
}

///|
pub fn Transform::from_str(text : String) -> Transform raise SvgTypesError {
  let tokens = TransformListParser::from(text)
  let mut ts = Transform::default()
  while tokens.next() is Some(token) {
    match token {
      Err(e) => raise e
      Ok(Matrix(a~, b~, c~, d~, e~, f~)) =>
        ts = multiply(ts, Transform::new(a, b, c, d, e, f))
      Ok(Translate(tx~, ty~)) =>
        ts = multiply(ts, Transform::new(1.0, 0.0, 0.0, 1.0, tx, ty))
      Ok(Scale(sx~, sy~)) =>
        ts = multiply(ts, Transform::new(sx, 0.0, 0.0, sy, 0.0, 0.0))
      Ok(Rotate(angle~)) => {
        let v = f64_to_radians(angle)
        // `v.cos()` and `v.sin()` are merged into one `sincos` call.
        let (b, a) = libm_sin_cos(v)
        let c = -b
        let d = a
        ts = multiply(ts, Transform::new(a, b, c, d, 0.0, 0.0))
      }
      Ok(SkewX(angle~)) => {
        let c = libm_tan(f64_to_radians(angle))
        ts = multiply(ts, Transform::new(1.0, 0.0, c, 1.0, 0.0, 0.0))
      }
      Ok(SkewY(angle~)) => {
        let b = libm_tan(f64_to_radians(angle))
        ts = multiply(ts, Transform::new(1.0, b, 0.0, 1.0, 0.0, 0.0))
      }
    }
  }
  ts
}

///|
fn multiply(ts1 : Transform, ts2 : Transform) -> Transform {
  {
    a: ts1.a * ts2.a + ts1.c * ts2.b,
    b: ts1.b * ts2.a + ts1.d * ts2.b,
    c: ts1.a * ts2.c + ts1.c * ts2.d,
    d: ts1.b * ts2.c + ts1.d * ts2.d,
    e: ts1.a * ts2.e + ts1.c * ts2.f + ts1.e,
    f: ts1.b * ts2.e + ts1.d * ts2.f + ts1.f,
  }
}
