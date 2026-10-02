// Port of `svgtypes` 0.16.1 `src/path.rs`.

///|
/// Representation of a path segment.
///
/// If you want to change the segment type (for example `MoveTo` to `LineTo`)
/// you should create a new segment.
/// But you still can change points or make segment relative or absolute.
pub(all) enum PathSegment {
  MoveTo(abs~ : Bool, x~ : Double, y~ : Double)
  LineTo(abs~ : Bool, x~ : Double, y~ : Double)
  HorizontalLineTo(abs~ : Bool, x~ : Double)
  VerticalLineTo(abs~ : Bool, y~ : Double)
  CurveTo(
    abs~ : Bool,
    x1~ : Double,
    y1~ : Double,
    x2~ : Double,
    y2~ : Double,
    x~ : Double,
    y~ : Double
  )
  SmoothCurveTo(
    abs~ : Bool,
    x2~ : Double,
    y2~ : Double,
    x~ : Double,
    y~ : Double
  )
  Quadratic(abs~ : Bool, x1~ : Double, y1~ : Double, x~ : Double, y~ : Double)
  SmoothQuadratic(abs~ : Bool, x~ : Double, y~ : Double)
  EllipticalArc(
    abs~ : Bool,
    rx~ : Double,
    ry~ : Double,
    x_axis_rotation~ : Double,
    large_arc~ : Bool,
    sweep~ : Bool,
    x~ : Double,
    y~ : Double
  )
  ClosePath(abs~ : Bool)
} derive(Eq, Debug)

///|
/// Returns `true` if the segment is absolute.
pub fn PathSegment::is_abs(self : PathSegment) -> Bool {
  match self {
    MoveTo(abs~, ..) => abs
    LineTo(abs~, ..) => abs
    HorizontalLineTo(abs~, ..) => abs
    VerticalLineTo(abs~, ..) => abs
    CurveTo(abs~, ..) => abs
    SmoothCurveTo(abs~, ..) => abs
    Quadratic(abs~, ..) => abs
    SmoothQuadratic(abs~, ..) => abs
    EllipticalArc(abs~, ..) => abs
    ClosePath(abs~) => abs
  }
}

///|
/// Returns the segment letter.
pub fn PathSegment::command(self : PathSegment) -> Byte {
  match self.is_abs() {
    true =>
      match self {
        MoveTo(..) => b'M'
        LineTo(..) => b'L'
        HorizontalLineTo(..) => b'H'
        VerticalLineTo(..) => b'V'
        CurveTo(..) => b'C'
        SmoothCurveTo(..) => b'S'
        Quadratic(..) => b'Q'
        SmoothQuadratic(..) => b'T'
        EllipticalArc(..) => b'A'
        ClosePath(..) => b'Z'
      }
    false =>
      match self {
        MoveTo(..) => b'm'
        LineTo(..) => b'l'
        HorizontalLineTo(..) => b'h'
        VerticalLineTo(..) => b'v'
        CurveTo(..) => b'c'
        SmoothCurveTo(..) => b's'
        Quadratic(..) => b'q'
        SmoothQuadratic(..) => b't'
        EllipticalArc(..) => b'a'
        ClosePath(..) => b'z'
      }
  }
}

///|
/// A pull-based [path data] parser.
///
/// # Errors
///
/// - Most of the `Error` types can occur.
///
/// # Notes
///
/// The library does not support implicit commands, so they will be converted to an explicit one.
/// It mostly affects an implicit `MoveTo`, which will be converted, according to the spec,
/// into an explicit `LineTo`.
///
/// Example: `M 10 20 30 40 50 60` -> `M 10 20 L 30 40 L 50 60`
///
/// [path data]: https://www.w3.org/TR/SVG2/paths.html#PathData
pub struct PathParser {
  priv stream : Stream
  priv mut prev_cmd : Byte?
}

///|
pub fn PathParser::from(v : String) -> PathParser {
  { stream: Stream::from(v), prev_cmd: None, }
}

///|
pub fn PathParser::next(
  self : PathParser,
) -> Result[PathSegment, SvgTypesError]? {
  let s = self.stream
  s.skip_spaces()
  if s.at_end() {
    return None
  }
  let res = try next_impl(s, self) |> Ok catch {
    e => Err(e)
  }
  if res is Err(_) {
    s.jump_to_end()
  }
  Some(res)
}

///|
pub fn PathParser::iter(
  self : PathParser,
) -> Iter[Result[PathSegment, SvgTypesError]] {
  Iter::new(() => self.next())
}

///|
fn next_impl(s : Stream, p : PathParser) -> PathSegment raise SvgTypesError {
  let start = s.pos()
  let has_prev_cmd = p.prev_cmd is Some(_)
  let first_char = s.curr_byte_unchecked()
  if !has_prev_cmd && !is_cmd(first_char) {
    raise UnexpectedData(s.calc_char_pos_at(start))
  }
  if !has_prev_cmd && !(first_char == b'M' || first_char == b'm') {
    // The first segment must be a MoveTo.
    raise UnexpectedData(s.calc_char_pos_at(start))
  }

  // TODO: simplify
  let (is_implicit_move_to, cmd) = if is_cmd(first_char) {
    s.advance(1)
    (false, first_char)
  } else if is_number_start(first_char) && has_prev_cmd {
    // unwrap is safe, because we checked 'has_prev_cmd'
    let p_cmd = p.prev_cmd.unwrap()
    if p_cmd == b'Z' || p_cmd == b'z' {
      // ClosePath cannot be followed by a number.
      raise UnexpectedData(s.calc_char_pos_at(start))
    }
    if p_cmd == b'M' || p_cmd == b'm' {
      // 'If a moveto is followed by multiple pairs of coordinates,
      // the subsequent pairs are treated as implicit lineto commands.'
      // So we parse them as LineTo.
      (true, if is_absolute(p_cmd) { b'L' } else { b'l' })
    } else {
      (false, p_cmd)
    }
  } else {
    raise UnexpectedData(s.calc_char_pos_at(start))
  }
  let cmdl = to_relative(cmd)
  let absolute = is_absolute(cmd)
  let token = match cmdl {
    b'm' => {
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::MoveTo(abs=absolute, x~, y~)
    }
    b'l' => {
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::LineTo(abs=absolute, x~, y~)
    }
    b'h' => {
      let x = s.parse_list_number()
      PathSegment::HorizontalLineTo(abs=absolute, x~)
    }
    b'v' => {
      let y = s.parse_list_number()
      PathSegment::VerticalLineTo(abs=absolute, y~)
    }
    b'c' => {
      let x1 = s.parse_list_number()
      let y1 = s.parse_list_number()
      let x2 = s.parse_list_number()
      let y2 = s.parse_list_number()
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::CurveTo(abs=absolute, x1~, y1~, x2~, y2~, x~, y~)
    }
    b's' => {
      let x2 = s.parse_list_number()
      let y2 = s.parse_list_number()
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::SmoothCurveTo(abs=absolute, x2~, y2~, x~, y~)
    }
    b'q' => {
      let x1 = s.parse_list_number()
      let y1 = s.parse_list_number()
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::Quadratic(abs=absolute, x1~, y1~, x~, y~)
    }
    b't' => {
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::SmoothQuadratic(abs=absolute, x~, y~)
    }
    b'a' => {
      // TODO: radius cannot be negative
      let rx = s.parse_list_number()
      let ry = s.parse_list_number()
      let x_axis_rotation = s.parse_list_number()
      let large_arc = parse_flag(s)
      let sweep = parse_flag(s)
      let x = s.parse_list_number()
      let y = s.parse_list_number()
      PathSegment::EllipticalArc(
        abs=absolute,
        rx~,
        ry~,
        x_axis_rotation~,
        large_arc~,
        sweep~,
        x~,
        y~,
      )
    }
    b'z' => PathSegment::ClosePath(abs=absolute)
    _ => abort("unreachable")
  }
  p.prev_cmd = Some(
    if is_implicit_move_to {
      if absolute {
        b'M'
      } else {
        b'm'
      }
    } else {
      cmd
    },
  )
  token
}

///|
/// Returns `true` if the selected char is the command.
fn is_cmd(c : Byte) -> Bool {
  match c {
    b'M'
    | b'm'
    | b'Z'
    | b'z'
    | b'L'
    | b'l'
    | b'H'
    | b'h'
    | b'V'
    | b'v'
    | b'C'
    | b'c'
    | b'S'
    | b's'
    | b'Q'
    | b'q'
    | b'T'
    | b't'
    | b'A'
    | b'a' => true
    _ => false
  }
}

///|
/// Returns `true` if the selected char is the absolute command.
fn is_absolute(c : Byte) -> Bool {
  match c {
    b'M' | b'Z' | b'L' | b'H' | b'V' | b'C' | b'S' | b'Q' | b'T' | b'A' => true
    _ => false
  }
}

///|
/// Converts the selected command char into the relative command char.
fn to_relative(c : Byte) -> Byte {
  match c {
    b'M' => b'm'
    b'Z' => b'z'
    b'L' => b'l'
    b'H' => b'h'
    b'V' => b'v'
    b'C' => b'c'
    b'S' => b's'
    b'Q' => b'q'
    b'T' => b't'
    b'A' => b'a'
    _ => c
  }
}

///|
fn is_number_start(c : Byte) -> Bool {
  match c {
    b'0'..=b'9' | b'.' | b'-' | b'+' => true
    _ => false
  }
}

///|
/// By the SVG spec 'large-arc' and 'sweep' must contain only one char
/// and can be written without any separators, e.g.: 10 20 30 01 10 20.
fn parse_flag(s : Stream) -> Bool raise SvgTypesError {
  s.skip_spaces()
  let c = s.curr_byte()
  match c {
    b'0' | b'1' => {
      s.advance(1)
      if s.is_curr_byte_eq(b',') {
        s.advance(1)
      }
      s.skip_spaces()
      c == b'1'
    }
    _ => raise UnexpectedData(s.calc_char_pos_at(s.pos()))
  }
}

///|
/// Representation of a simple path segment.
pub(all) enum SimplePathSegment {
  MoveTo(x~ : Double, y~ : Double)
  LineTo(x~ : Double, y~ : Double)
  CurveTo(
    x1~ : Double,
    y1~ : Double,
    x2~ : Double,
    y2~ : Double,
    x~ : Double,
    y~ : Double
  )
  Quadratic(x1~ : Double, y1~ : Double, x~ : Double, y~ : Double)
  ClosePath
} derive(Eq, Debug)

///|
/// A simplifying Path Data parser.
///
/// A more high-level Path Data parser on top of [`PathParser`] that provides:
///
/// - Relative to absolute segment coordinates conversion
/// - `ArcTo` to `CurveTo`s conversion
/// - `SmoothCurveTo` and `SmoothQuadratic` conversion
/// - `HorizontalLineTo` and `VerticalLineTo` to `LineTo` conversion
/// - Implicit `MoveTo` after `ClosePath` handling
///
/// In the end, only absolute `MoveTo`, `LineTo`, `CurveTo`, `Quadratic` and `ClosePath` segments
/// will be produced.
pub struct SimplifyingPathParser {
  priv parser : PathParser

  // Previous MoveTo coordinates.
  priv mut prev_mx : Double
  priv mut prev_my : Double

  // Previous SmoothQuadratic coordinates.
  priv mut prev_tx : Double
  priv mut prev_ty : Double

  // Previous coordinates.
  priv mut prev_x : Double
  priv mut prev_y : Double
  priv mut prev_seg : PathSegment
  priv mut prev_simple_seg : SimplePathSegment?
  priv buffer : Array[SimplePathSegment]
}

///|
pub fn SimplifyingPathParser::from(v : String) -> SimplifyingPathParser {
  {
    parser: PathParser::from(v),
    prev_mx: 0.0,
    prev_my: 0.0,
    prev_tx: 0.0,
    prev_ty: 0.0,
    prev_x: 0.0,
    prev_y: 0.0,
    prev_seg: PathSegment::MoveTo(abs=true, x=0.0, y=0.0),
    prev_simple_seg: None,
    buffer: [],
  }
}

///|
pub fn SimplifyingPathParser::iter(
  self : SimplifyingPathParser,
) -> Iter[Result[SimplePathSegment, SvgTypesError]] {
  Iter::new(() => self.next())
}

///|
pub fn SimplifyingPathParser::next(
  self : SimplifyingPathParser,
) -> Result[SimplePathSegment, SvgTypesError]? {
  if !self.buffer.is_empty() {
    return Some(Ok(self.buffer.remove(0)))
  }
  let segment = match self.parser.next() {
    None => return None
    Some(Ok(v)) => v
    Some(Err(e)) => return Some(Err(e))
  }

  // If a ClosePath segment is followed by any command other than MoveTo or ClosePath
  // then MoveTo is implicit.
  if self.prev_simple_seg is Some(SimplePathSegment::ClosePath) {
    match segment {
      PathSegment::MoveTo(..) | PathSegment::ClosePath(..) => ()
      _ => {
        let new_seg = SimplePathSegment::MoveTo(x=self.prev_mx, y=self.prev_my)
        self.buffer.push(new_seg)
        self.prev_simple_seg = Some(new_seg)
      }
    }
  }
  match segment {
    PathSegment::MoveTo(abs~, x~, y~) => {
      let mut x = x
      let mut y = y
      if !abs {
        // When we get 'm'(relative) segment, which is not first segment - then it's
        // relative to a previous 'M'(absolute) segment, not to the first segment.
        if self.prev_simple_seg is Some(SimplePathSegment::ClosePath) {
          x += self.prev_mx
          y += self.prev_my
        } else {
          x += self.prev_x
          y += self.prev_y
        }
      }
      self.buffer.push(SimplePathSegment::MoveTo(x~, y~))
      self.prev_seg = segment
    }
    PathSegment::LineTo(abs~, x~, y~) => {
      let mut x = x
      let mut y = y
      if !abs {
        x += self.prev_x
        y += self.prev_y
      }
      self.buffer.push(SimplePathSegment::LineTo(x~, y~))
      self.prev_seg = segment
    }
    PathSegment::HorizontalLineTo(abs~, x~) => {
      let mut x = x
      if !abs {
        x += self.prev_x
      }
      self.buffer.push(SimplePathSegment::LineTo(x~, y=self.prev_y))
      self.prev_seg = segment
    }
    PathSegment::VerticalLineTo(abs~, y~) => {
      let mut y = y
      if !abs {
        y += self.prev_y
      }
      self.buffer.push(SimplePathSegment::LineTo(x=self.prev_x, y~))
      self.prev_seg = segment
    }
    PathSegment::CurveTo(abs~, x1~, y1~, x2~, y2~, x~, y~) => {
      let mut x1 = x1
      let mut y1 = y1
      let mut x2 = x2
      let mut y2 = y2
      let mut x = x
      let mut y = y
      if !abs {
        x1 += self.prev_x
        y1 += self.prev_y
        x2 += self.prev_x
        y2 += self.prev_y
        x += self.prev_x
        y += self.prev_y
      }
      self.buffer.push(SimplePathSegment::CurveTo(x1~, y1~, x2~, y2~, x~, y~))

      // Remember as absolute.
      self.prev_seg = PathSegment::CurveTo(abs=true, x1~, y1~, x2~, y2~, x~, y~)
    }
    PathSegment::SmoothCurveTo(abs~, x2~, y2~, x~, y~) => {
      let mut x2 = x2
      let mut y2 = y2
      let mut x = x
      let mut y = y
      // 'The first control point is assumed to be the reflection of the second control
      // point on the previous command relative to the current point.
      // (If there is no previous command or if the previous command
      // was not an C, c, S or s, assume the first control point is
      // coincident with the current point.)'
      let (x1, y1) = match self.prev_seg {
        PathSegment::CurveTo(x2~, y2~, x~, y~, ..)
        | PathSegment::SmoothCurveTo(x2~, y2~, x~, y~, ..) =>
          (x * 2.0 - x2, y * 2.0 - y2)
        _ => (self.prev_x, self.prev_y)
      }
      if !abs {
        x2 += self.prev_x
        y2 += self.prev_y
        x += self.prev_x
        y += self.prev_y
      }
      self.buffer.push(SimplePathSegment::CurveTo(x1~, y1~, x2~, y2~, x~, y~))

      // Remember as absolute.
      self.prev_seg = PathSegment::SmoothCurveTo(abs=true, x2~, y2~, x~, y~)
    }
    PathSegment::Quadratic(abs~, x1~, y1~, x~, y~) => {
      let mut x1 = x1
      let mut y1 = y1
      let mut x = x
      let mut y = y
      if !abs {
        x1 += self.prev_x
        y1 += self.prev_y
        x += self.prev_x
        y += self.prev_y
      }
      self.buffer.push(SimplePathSegment::Quadratic(x1~, y1~, x~, y~))

      // Remember as absolute.
      self.prev_seg = PathSegment::Quadratic(abs=true, x1~, y1~, x~, y~)
    }
    PathSegment::SmoothQuadratic(abs~, x~, y~) => {
      let mut x = x
      let mut y = y
      // 'The control point is assumed to be the reflection of
      // the control point on the previous command relative to
      // the current point. (If there is no previous command or
      // if the previous command was not a Q, q, T or t, assume
      // the control point is coincident with the current point.)'
      let (x1, y1) = match self.prev_seg {
        PathSegment::Quadratic(x1~, y1~, x~, y~, ..) =>
          (x * 2.0 - x1, y * 2.0 - y1)
        PathSegment::SmoothQuadratic(x~, y~, ..) =>
          (x * 2.0 - self.prev_tx, y * 2.0 - self.prev_ty)
        _ => (self.prev_x, self.prev_y)
      }
      self.prev_tx = x1
      self.prev_ty = y1
      if !abs {
        x += self.prev_x
        y += self.prev_y
      }
      self.buffer.push(SimplePathSegment::Quadratic(x1~, y1~, x~, y~))

      // Remember as absolute.
      self.prev_seg = PathSegment::SmoothQuadratic(abs=true, x~, y~)
    }
    PathSegment::EllipticalArc(
      abs~,
      rx~,
      ry~,
      x_axis_rotation~,
      large_arc~,
      sweep~,
      x~,
      y~
    ) => {
      let mut x = x
      let mut y = y
      if !abs {
        x += self.prev_x
        y += self.prev_y
      }
      let svg_arc : SvgArc = {
        from: { x: self.prev_x, y: self.prev_y, },
        to: { x, y, },
        radii: { x: rx, y: ry, },
        x_rotation: f64_to_radians(x_axis_rotation),
        large_arc,
        sweep,
      }
      match KArc::from_svg_arc(svg_arc) {
        Some(arc) =>
          arc.to_cubic_beziers(0.1, (p1, p2, p) => {
            self.buffer.push(
              SimplePathSegment::CurveTo(
                x1=p1.x,
                y1=p1.y,
                x2=p2.x,
                y2=p2.y,
                x=p.x,
                y=p.y,
              ),
            )
          })
        None => self.buffer.push(SimplePathSegment::LineTo(x~, y~))
      }
      self.prev_seg = segment
    }
    PathSegment::ClosePath(..) =>
      if self.prev_simple_seg is Some(SimplePathSegment::ClosePath) {
        // Do not add sequential ClosePath segments.
        // Otherwise it will break markers rendering.
        self.prev_seg = segment
      } else {
        self.buffer.push(SimplePathSegment::ClosePath)
        self.prev_seg = segment
      }
  }

  // Remember last position.
  if self.buffer.last() is Some(new_segment) {
    self.prev_simple_seg = Some(new_segment)
    match new_segment {
      SimplePathSegment::MoveTo(x~, y~) => {
        self.prev_x = x
        self.prev_y = y
        self.prev_mx = self.prev_x
        self.prev_my = self.prev_y
      }
      SimplePathSegment::LineTo(x~, y~) => {
        self.prev_x = x
        self.prev_y = y
      }
      SimplePathSegment::CurveTo(x~, y~, ..) => {
        self.prev_x = x
        self.prev_y = y
      }
      SimplePathSegment::Quadratic(x~, y~, ..) => {
        self.prev_x = x
        self.prev_y = y
      }
      SimplePathSegment::ClosePath => {
        // ClosePath moves us to the last MoveTo coordinate.
        self.prev_x = self.prev_mx
        self.prev_y = self.prev_my
      }
    }
  }
  if self.buffer.is_empty() {
    return self.next()
  }
  Some(Ok(self.buffer.remove(0)))
}
