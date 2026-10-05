// Click to source (docs/edsl-review.md, slice 1): what a click on a page
// of a compiled document hits, a port of upstream `jump_from_click_in_frame`
// (`crates/typst-ide/src/jump.rs`) on the frames of a report. Where
// upstream looks the span up in the parsed source of its file, the port
// resolves it with the report's origins.

///|
/// Upstream `Curve::to_kurbo` (`typst-library/src/visualize/curve.rs`).
fn curve_to_kurbo(curve : @library.Curve) -> Array[@kurbo.PathEl] {
  let point = (p : @library.Point) => {
    @kurbo.Point::new(p.x.to_raw(), p.y.to_raw())
  }
  curve
  .items()
  .map(item => {
    match item {
      Move(p) => @kurbo.PathEl::MoveTo(point(p))
      Line(p) => @kurbo.PathEl::LineTo(point(p))
      Cubic(p1, p2, p3) =>
        @kurbo.PathEl::CurveTo(point(p1), point(p2), point(p3))
      Close => @kurbo.PathEl::ClosePath
    }
  })
}

///|
/// Whether a path has a segment. (A path without one contains nothing;
/// kurbo's `segments` does not accept a path that starts with `ClosePath`.)
fn has_segments(path : Array[@kurbo.PathEl]) -> Bool {
  guard path.length() > 0 && !(path[0] is ClosePath) else { return false }
  for el in path {
    if !(el is (MoveTo(_) | ClosePath)) {
      return true
    }
  }
  false
}

///|
/// The path with every subpath closed: what a fill paints (SVG and PDF
/// close an open subpath for filling).
fn closed_path(path : Array[@kurbo.PathEl]) -> Array[@kurbo.PathEl] {
  let out : Array[@kurbo.PathEl] = []
  // Whether the current subpath has a segment and is not closed.
  let mut open = false
  for el in path {
    match el {
      MoveTo(_) => {
        if open {
          out.push(ClosePath)
        }
        open = false
      }
      ClosePath => open = false
      _ => open = true
    }
    out.push(el)
  }
  if open {
    out.push(ClosePath)
  }
  out
}

///|
/// Upstream `Curve::contains`: when this curve is interpreted as a clip
/// mask, would it contain `needle`? With `painted`, the curve is tested
/// as a fill paints it, with its open subpaths closed; upstream tests the
/// path as it is, so the inside of an open path is not contained.
fn curve_contains(
  curve : @library.Curve,
  fill_rule : @library.FillRule,
  needle : @library.Point,
  painted : Bool,
) -> Bool {
  let path = curve_to_kurbo(curve)
  let path = if painted { closed_path(path) } else { path }
  guard has_segments(path) else { return false }
  let windings = @kurbo.BezPath::from_vec(path).winding(
    @kurbo.Point::new(needle.x.to_raw(), needle.y.to_raw()),
  )
  match fill_rule {
    NonZero => windings != 0
    EvenOdd => windings % 2 != 0
  }
}

///|
/// Upstream `Curve::stroke_contains`: when this curve is stroked with
/// `stroke`, would the stroke contain `needle`? (`Curve::to_kurbo_stroke`
/// with a tolerance of 0.01.) Without `dashed` the dash pattern is left
/// out: the whole line counts, also in its gaps, and the work does not
/// grow with the number of dashes.
fn curve_stroke_contains(
  curve : @library.Curve,
  stroke : @library.FixedStroke,
  needle : @library.Point,
  dashed : Bool,
) -> Bool {
  let cap = match stroke.cap {
    Butt => @kurbo.Cap::Butt
    Round => @kurbo.Cap::Round
    Square => @kurbo.Cap::Square
  }
  let join = match stroke.join {
    Miter => @kurbo.Join::Miter
    Round => @kurbo.Join::Round
    Bevel => @kurbo.Join::Bevel
  }
  let mut style = @kurbo.Stroke::new(stroke.thickness.to_raw())
    .with_caps(cap)
    .with_join(join)
    .with_miter_limit(stroke.miter_limit.get())
  if dashed && stroke.dash is Some(dash) {
    style = style.with_dashes(
      dash.phase.to_raw(),
      dash.array.map(length => length.to_raw()),
    )
  }
  let opts : @kurbo.StrokeOpts = Default::default()
  let outline = @kurbo.stroke(curve_to_kurbo(curve).iter(), style, opts, 0.01)
  guard has_segments(outline.elements()) else { return false }
  outline.contains(@kurbo.Point::new(needle.x.to_raw(), needle.y.to_raw()))
}

///|
/// The curve that a shape's stroke follows, rooted at the shape's
/// position (upstream builds it in `jump_from_click_in_frame`).
fn stroke_base_curve(geometry : @library.Geometry) -> @library.Curve {
  match geometry {
    Line(to) => @library.Curve::Curve([@library.CurveItem::Line(to)])
    Rect(size) => @library.Curve::rect(size)
    Curve(curve) => curve
  }
}

///|
/// Whether a rectangle with the given size at the given position contains
/// the click position.
fn is_in_rect(
  pos : @library.Point,
  size : @library.Axes[@library.Abs],
  click : @library.Point,
) -> Bool {
  pos.x <= click.x &&
  pos.x + size.x >= click.x &&
  pos.y <= click.y &&
  pos.y + size.y >= click.y
}

///|
/// What a click hit.
priv enum Hit {
  /// Text, a shape or an image whose span has this origin.
  HOrigin(Origin)
  HUrl(String)
  HPosition(@library.PagedPosition)
}

///|
/// What a click in a frame hits: upstream `jump_from_click_in_frame`.
///
/// `strict` is upstream's behaviour: a link wins over what is under it,
/// and a shape or an image without a source location ends the search.
/// Without it links are ignored, such a shape or image is transparent, a
/// filled curve or a clip counts as it is painted (`curve_contains`), a
/// dashed stroke counts as a whole line, and a group whose transform has
/// no inverse is skipped (upstream's `invert` answers a scale of zero
/// with a translation): the question is where the content under the
/// pointer comes from, and the preview page's layer answers it with
/// exactly these rules.
///
/// One deviation in both modes: a glyph whose span has no origin (no
/// file, or none that the report knows) is passed over. Upstream does not
/// advance past a glyph without a file, which shifts the boxes of the
/// glyphs after it to the left, and gives up the whole search at a glyph
/// whose file or syntax node cannot be found; the port keeps every glyph
/// at its place and goes on.
fn[T] CompileReport::click_in_frame(
  self : CompileReport[T],
  document : @layout.PagedDocument,
  frame : @library.Frame,
  click : @library.Point,
  strict : Bool,
) -> Hit? {
  let items = frame.items()
  // Try to find a link first.
  if strict {
    for entry in items {
      if entry.1 is Link(dest, size) && is_in_rect(entry.0, size, click) {
        match dest {
          Url(url) => return Some(HUrl(url.into_inner()))
          Position(pos) => return Some(HPosition(pos))
          Location(loc) =>
            if document.paged_introspector().position(loc) is Some(pos) {
              return Some(HPosition(pos))
            }
        }
      }
    }
  }

  // If there's no link, search for a jump target.
  for k = items.length() - 1; k >= 0; k = k - 1 {
    let (pos, item) = items[k]
    match item {
      Group(group) => {
        let pos = click - pos
        if group.clip is Some(clip) &&
          !curve_contains(clip, NonZero, pos, !strict) {
          continue
        }
        // Realistic transforms should always be invertible.
        // An example of one that isn't is a scale of 0, which would
        // not be clickable anyway.
        guard group.transform.invert() is Some(inv_transform) else { continue }
        let ts = group.transform
        if !strict &&
          (ts.sx.get() * ts.sy.get() - ts.kx.get() * ts.ky.get()).abs() <
          1.0e-12 {
          continue
        }
        let pos = pos.transform_inf(inv_transform)
        if self.click_in_frame(document, group.frame, pos, strict) is Some(hit) {
          return Some(hit)
        }
      }
      Text(text) => {
        let mut x = pos.x
        for glyph in text.glyphs {
          let width = glyph.x_advance.at(text.size)
          if is_in_rect(
              @library.Point::new(x, pos.y - text.size),
              { x: width, y: text.size, },
              click,
            ) &&
            self.origins.resolve(glyph.span) is Some(origin) {
            return Some(HOrigin(origin))
          }
          x = x + width
        }
      }
      Shape(shape, span) => {
        let mut within = false
        if shape.fill is Some(_) {
          within = match shape.geometry {
            Line(_) => false
            Rect(size) => is_in_rect(pos, size, click)
            Curve(curve) =>
              curve_contains(curve, shape.fill_rule, click - pos, !strict)
          }
        }
        if !within && shape.stroke is Some(stroke) {
          within = !stroke.thickness.approx_empty() &&
            // This curve is rooted at (0, 0), not `pos`.
            curve_stroke_contains(
              stroke_base_curve(shape.geometry),
              stroke,
              click - pos,
              strict,
            )
        }
        if within {
          match self.origins.resolve(span) {
            Some(origin) => return Some(HOrigin(origin))
            None => if strict { return Option::None }
          }
        }
      }
      Image(_, size, span) =>
        if is_in_rect(pos, size, click) {
          match self.origins.resolve(span) {
            Some(origin) => return Some(HOrigin(origin))
            None => if strict { return Option::None }
          }
        }
      _ => ()
    }
  }
  Option::None
}

///|
/// What a click at the point `(x, y)` of a page hits (points from the
/// page's top left corner; pages start at 1).
fn CompileReport::click(
  self : CompileReport[@layout.PagedDocument],
  page : Int,
  x : Double,
  y : Double,
  strict : Bool,
) -> Hit? {
  guard self.output is Some(document) else { return Option::None }
  let pages = document.pages()
  guard page >= 1 && page <= pages.length() && !x.is_nan() && !y.is_nan() else {
    return Option::None
  }
  let click = @library.Point::new(@library.Abs::pt(x), @library.Abs::pt(y))
  self.click_in_frame(document, pages[page - 1].frame, click, strict)
}

///|
/// Where to jump to from a click (upstream `Jump`).
pub(all) enum Jump {
  /// The source of what was hit (upstream `Jump::File`): the constructor
  /// call, and its argument if the location is narrower than the call.
  Source(Origin)
  /// An external URL.
  Url(String)
  /// A point on a page (the target of an internal link).
  Position(page~ : Int, x~ : Double, y~ : Double)
}

///|
/// Determine where to jump to, based on a click in the rendered document
/// (upstream `jump_from_click`): links first, then the topmost text, shape
/// or image. Coordinates are points from the page's top left corner; pages
/// start at 1. `None` if nothing with a source location is there, or the
/// compilation failed.
pub fn CompileReport::jump_from_click(
  self : CompileReport[@layout.PagedDocument],
  page : Int,
  x : Double,
  y : Double,
) -> Jump? {
  match self.click(page, x, y, true) {
    Some(HOrigin(origin)) => Some(Source(origin))
    Some(HUrl(url)) => Some(Url(url))
    Some(HPosition(pos)) =>
      Some(
        Position(
          page=pos.page.get().to_int(),
          x=pos.point.x.to_pt(),
          y=pos.point.y.to_pt(),
        ),
      )
    None => Option::None
  }
}

///|
/// The origin of the content at a point of a page: the constructor call
/// (and argument) that produced the topmost text, shape or image there.
/// Unlike `jump_from_click`, a link does not hide the content under it,
/// and content that the engine generated without a source location (a
/// list marker, a page fill) is transparent. This is what the preview page
/// of `review_html` shows for a click.
pub fn CompileReport::origin_at(
  self : CompileReport[@layout.PagedDocument],
  page : Int,
  x : Double,
  y : Double,
) -> Origin? {
  match self.click(page, x, y, false) {
    Some(HOrigin(origin)) => Some(origin)
    _ => Option::None
  }
}
