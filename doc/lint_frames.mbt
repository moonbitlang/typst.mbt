// The lints that read the laid-out pages (docs/edsl-ports.md, section 6):
// L2, missing glyphs, and L3, content outside the page or outside a
// container of a fixed size. They run on the frames of a paged
// compilation (`Document::compile_paged`); `lower` and a compilation to
// another output have no frames, and so none of these lints.
//
// What the frames hold, which is all that these lints can know:
//
// - A text item has its font, its text and its glyphs; a glyph has its id
//   in the font, its advance and offset, the bytes of the item's text that
//   it stands for (16-bit offsets), and the span of its text. Glyphs of one
//   item can have different spans.
// - A shape and an image have a span, which is detached for what the
//   engine drew on its own account (a decoration, the marker of a list).
// - A group has a frame, a transform and a clip, and no span. The frame of
//   a `block`, of a `box` and of a page is hard (`FrameKind`), and a hard
//   frame is always a group of its own; a soft frame of few items is
//   dissolved into the frame around it.
// - A tag marks where an element starts and ends (the elements that can be
//   located or that are tagged for PDF: a paragraph, a heading, a figure,
//   a table and its cells, a placed element, ..; not `block` and `box`).
//   Its element has a span.
//
// So a frame says where something is and which call made it, but not
// which frame is the frame of which call, nor whether a size was given.
// For the page that is not needed. For a container it is what lowering
// adds (`Container` in `origin.mbt`): the size that a `Block` or `Box` was
// called with, and which calls were lowered inside its arguments.

///|
/// How far something may leave the page or its container before it is
/// reported, in points.
const LINT_TOLERANCE : Double = 1.0

///|
/// The box of the outline of every glyph of a font that was asked for.
/// (Arrays by glyph id, and no value per glyph: every glyph of a document
/// is looked at.)
priv struct FontInk {
  font : @library.FontInstance
  /// Per glyph id: 0 if it was not asked for yet, 1 if it has no outline
  /// (a space, and a glyph that is a bitmap or an SVG document only), 2
  /// if its box is in `boxes`.
  known : Array[Int]
  /// Per glyph id four numbers: the left, top, right and bottom of the box
  /// of its outline in em, x to the right and y down from the pen.
  boxes : Array[Double]
}

///|
/// Whether the glyph `id` has an outline: its box is then at `4 * id` of
/// `boxes`.
fn FontInk::has(self : FontInk, id : Int) -> Bool {
  while self.known.length() <= id {
    self.known.push(0)
    for _ in 0..<4 {
      self.boxes.push(0.0)
    }
  }
  let known = self.known[id]
  guard known == 0 else { return known == 2 }
  match self.font.glyph_bounding_box(id.to_uint16()) {
    Some(rect) if rect.x_min < rect.x_max && rect.y_min < rect.y_max => {
      let upem = self.font.units_per_em()
      self.boxes[4 * id] = rect.x_min.to_double() / upem
      self.boxes[4 * id + 1] = -rect.y_max.to_double() / upem
      self.boxes[4 * id + 2] = rect.x_max.to_double() / upem
      self.boxes[4 * id + 3] = -rect.y_min.to_double() / upem
      self.known[id] = 2
      true
    }
    _ => {
      self.known[id] = 1
      false
    }
  }
}

///|
/// From the engine's unit of length to points. The paths of the click
/// search (`curve_to_kurbo`, `stroke_outline`) are in the engine's unit
/// like upstream's; everything else here is in points.
let raw_to_pt : @kurbo.Affine = @kurbo.Affine::scale(
  1.0 / @library.Abs::pt(1.0).to_raw(),
)

///|
/// What is drawn of an item, in the coordinates of its frame.
priv enum Extent {
  /// A rectangle: an image.
  ERect(@kurbo.Rect)
  /// A glyph: the box of its outline, which is what is drawn; of that
  /// box the part that the engine sets in a line (`FrameLinter::text`);
  /// and how far the engine lets the glyph hang over the end of its line
  /// (`hang_of`), which runs along the x axis.
  EGlyph(@kurbo.Rect, @kurbo.Rect, Double)
  /// A shape: its path, which is where it is set; and the areas that are
  /// drawn, the interior of a filled shape and the outline of its stroke
  /// (`FrameLinter::shape`).
  EShape(@kurbo.BezPath, Array[@kurbo.BezPath])
}

///|
/// The bounding box of the extent after the transform `ts`. For a path it
/// is the box of the transformed path, so a rotated circle has the box of
/// a circle; for a rectangle it is the box of its four corners. `set`:
/// what is set, not all that is drawn (of a glyph the part in its line,
/// of a shape its path without the stroke around it).
fn Extent::bounds(
  self : Extent,
  ts : @kurbo.Affine,
  set~ : Bool,
) -> @kurbo.Rect? {
  match self {
    ERect(rect) => Some(ts.transform_rect_bbox(rect))
    EGlyph(drawn, part, _) =>
      Some(ts.transform_rect_bbox(if set { part } else { drawn }))
    EShape(path, _) if set => Some(path.transform(ts).bounding_box())
    EShape(_, paths) => {
      let mut all : @kurbo.Rect? = Option::None
      for path in paths {
        let box = path.transform(ts).bounding_box()
        all = match all {
          Some(sum) => Some(sum.union(box))
          Option::None => Some(box)
        }
      }
      all
    }
  }
}

///|
/// How far the extent may leave a box along x and along y after the
/// transform `ts` without being found: what a glyph hangs over the end of
/// its line, in the direction that the line has then.
fn Extent::slack(self : Extent, ts : @kurbo.Affine) -> (Double, Double) {
  match self {
    EGlyph(_, _, hang) if hang > 0.0 => {
      let c = ts.as_coeffs()
      (hang * c[0].abs(), hang * c[1].abs())
    }
    _ => (0.0, 0.0)
  }
}

///|
/// How far the engine lets the glyph of a character hang over the end of
/// its line, as a part of its advance (`text.overhang`, which is on by
/// default): the table of `overhang` in `layout/inline_line.mbt` (upstream
/// `typst-layout/src/inline/line.rs`). A line that is as wide as its
/// container ends that much outside of it, by the engine's choice, and a
/// frame does not say which glyph ends a line: so much is no finding for
/// any glyph of these characters.
fn hang_of(c : Char) -> Double {
  match c {
    '–' | '—' => 0.2
    '-' | '\u{ad}' => 0.55
    '.' | ',' => 0.8
    ';' | ':' => 0.3
    '\u{60C}' | '\u{6D4}' => 0.4
    _ => 0.0
  }
}

///|
/// The four sides of a box, in the order of the amounts of `leaves`.
let side_names : ReadOnlyArray[String] = ["left", "top", "right", "bottom"]

///|
/// How far `rect` leaves `box`: the largest of the amounts at its left,
/// top, right and bottom side, and that side. `x` and `y`: whether the
/// sides of that axis count; `slack`: what does not count along x and
/// along y (`Extent::slack`). An amount of zero or less: inside.
fn leaves(
  rect : @kurbo.Rect,
  box : @kurbo.Rect,
  x : Bool,
  y : Bool,
  slack~ : (Double, Double) = (0.0, 0.0),
) -> (Double, Int) {
  // (Less than every amount.)
  let mut amount = -1.0e300
  let mut side = 0
  let amounts = [
    box.x0 - rect.x0 - slack.0,
    box.y0 - rect.y0 - slack.1,
    rect.x1 - box.x1 - slack.0,
    rect.y1 - box.y1 - slack.1,
  ]
  for i, a in amounts {
    if (if i % 2 == 0 { x } else { y }) && a > amount {
      amount = a
      side = i
    }
  }
  (amount, side)
}

///|
/// What was found of one kind at one place: the findings of one call of
/// the source are one lint.
priv struct Finding {
  kind : LintKind
  location : Location?
  /// Whether the location is that of the element around what was found
  /// (`FrameLinter::locate`).
  indirect : Bool
  /// The page of the first.
  page : Int
  /// `MissingGlyph`: the characters. Otherwise what left, of the farthest:
  /// `text`, `a shape`, `an image`.
  mut subject : String
  /// `MissingGlyph`: the family of the font.
  font : String
  /// `OutsideContainer`: the container's origin, and what it is, with the
  /// size of the frame that the farthest left.
  mut container : (Origin, String)?
  /// How many there are, and the item of the last one (a run of text
  /// counts once, however many of its glyphs are found).
  mut count : Int
  mut last_item : Int
  /// How far the farthest left, and at which side.
  mut amount : Double
  mut side : Int
}

///|
/// A length in points for a message: one decimal, none if it is zero.
fn points(x : Double) -> String {
  let tenths = (x * 10.0).round().to_int64()
  let sign = if tenths < 0 { "-" } else { "" }
  let tenths = tenths.abs()
  if tenths % 10 == 0 {
    "\{sign}\{tenths / 10}pt"
  } else {
    "\{sign}\{tenths / 10}.\{tenths % 10}pt"
  }
}

///|
/// The lint of a finding.
fn Finding::lint(self : Finding) -> Lint {
  let hints : Array[Hint] = []
  let message = match self.kind {
    MissingGlyph => {
      hints.push({
        message: "use a font that has it: name its family in the `font` of `SetText` or `Text` (with `fallback=false` only those are tried, otherwise every font of the world); a font that is not embedded comes from `font_paths` or from the system's fonts (docs/edsl-guide.md, section 5)",
        location: Option::None,
      })
      let times = if self.count > 1 { ", \{self.count} times" } else { "" }
      "no font of this text has a glyph for \{self.subject}: it is drawn as the missing glyph of \{self.font}\{times}"
    }
    _ => {
      let of = match self.container {
        Some((origin, what)) => {
          hints.push({ message: "the container", location: Some(Edsl(origin)), })
          hints.push({
            message: "a block or box with a size of its own does not grow with its content, and cuts nothing off unless `clip=true`",
            location: Option::None,
          })
          "its container (\{what})"
        }
        Option::None => {
          hints.push({
            message: "what is outside the page is cut off: look for a width, a height or an offset that puts it there, a block that cannot break and is higher than the page, a word or a row that is wider",
            location: Option::None,
          })
          "the page"
        }
      }
      let more = if self.count > 1 {
        " (the farthest of \{self.count})"
      } else {
        ""
      }
      "\{self.subject} leaves \{of} at the \{side_names[self.side]} by \{points(self.amount)}\{more}"
    }
  }
  if self.indirect {
    hints.push({
      message: "the engine made it without a source location: the place is the element that it is part of",
      location: Option::None,
    })
  }
  {
    kind: self.kind,
    message,
    hints,
    location: self.location,
    page: Some(self.page),
  }
}

///|
/// Something that leaves a frame that may be a container.
priv struct Leaving {
  /// The number of the item of the page that it is (of) (`Finding`).
  item : Int
  subject : String
  /// Its box in the coordinates of the frame, as far as it is drawn (not
  /// clipped away), and what does not count of it (`Extent::slack`).
  rect : @kurbo.Rect
  slack : (Double, Double)
  location : Location?
  indirect : Bool
  /// For a shape with the span of a call itself (not of an argument) that
  /// is the call of a container: that container (`-1`: none). It can be
  /// what the container draws itself (`FrameLinter::own_shape`).
  own : Int
}

///|
/// A hard frame that has a size that a container was built with, while
/// its items are walked.
priv struct Held {
  /// From the coordinates of the page to those of the frame.
  to_local : @kurbo.Affine
  /// From the coordinates of the frame that is walked (`FrameLinter::
  /// frame`) to those of this frame.
  mut from_walked : @kurbo.Affine
  box : @kurbo.Rect
  /// The containers that had this size, and for each whether its width
  /// and its height were given, and whether the frame holds something
  /// that was lowered inside that container.
  containers : Array[Int]
  fixed : Array[(Bool, Bool)]
  confirmed : Array[Bool]
  leaving : Array[Leaving]
}

///|
/// The state of the walk over the pages of a document.
priv struct FrameLinter {
  origins : Origins
  resolver : Resolver
  findings : Array[Finding]
  /// The finding of each kind and place.
  index : Map[String, Int]
  fonts : Array[FontInk]
  /// The sizes that containers were built with: by the keys of their
  /// width and of their height (`size_key`; `NO_SIDE` for a side that was
  /// not given), the containers with that width and height in points.
  sizes : Map[Int64, Map[Int64, Array[(Int, Double?, Double?)]]]
  /// The page that is walked (from 1) and its box, with the bleed.
  mut page : Int
  mut page_box : @kurbo.Rect
  /// The number of the item that is looked at, counted over the document.
  mut item : Int
  /// The elements that are open (their tags), outermost first.
  elements : Array[(@library.Location, @syntax.Span)]
  /// The clips of the groups around the item: the transform from the
  /// group's coordinates to the page's, and the box of the clip path.
  clips : Array[(@kurbo.Affine, @kurbo.Rect)]
  /// The frames around the item that may be containers, and how many
  /// candidates of them are not confirmed.
  held : Array[Held]
  mut unconfirmed : Int
}

///|
/// How far the size of a frame may be from the size that a container was
/// built with, in points: the engine computes with floating point numbers
/// (a block of 60pt with an inset in per cent has a frame of
/// 60.00000000000001pt).
const SIZE_TOLERANCE : Double = 1.0e-6

///|
/// The key of a side that was not given.
const NO_SIDE : Int64 = -9223372036854775808L

///|
/// The key of a length in the table of sizes: lengths that are equal but
/// for `SIZE_TOLERANCE` have the same key or keys that follow each other.
fn size_key(length : Double) -> Int64 {
  (length * 1024.0).round().to_int64()
}

///|
fn FrameLinter::new(origins : Origins, resolver : Resolver) -> FrameLinter {
  let sizes : Map[Int64, Map[Int64, Array[(Int, Double?, Double?)]]] = Map([])
  for id, container in origins.containers {
    for size in container.sizes {
      let w = size.0.map(width => width.to_pt())
      let h = size.1.map(height => height.to_pt())
      let kw = match w {
        Some(w) => size_key(w)
        Option::None => NO_SIDE
      }
      let kh = match h {
        Some(h) => size_key(h)
        Option::None => NO_SIDE
      }
      let row = match sizes.get(kw) {
        Some(row) => row
        Option::None => {
          let row : Map[Int64, Array[(Int, Double?, Double?)]] = Map([])
          sizes[kw] = row
          row
        }
      }
      match row.get(kh) {
        Some(list) => list.push((id, w, h))
        Option::None => row[kh] = [(id, w, h)]
      }
    }
  }
  {
    origins,
    resolver,
    findings: [],
    index: Map([]),
    fonts: [],
    sizes,
    page: 0,
    page_box: @kurbo.rect_zero,
    item: 0,
    elements: [],
    clips: [],
    held: [],
    unconfirmed: 0,
  }
}

///|
/// The boxes of the glyphs of a font.
fn FrameLinter::ink(
  self : FrameLinter,
  font : @library.FontInstance,
) -> FontInk {
  // (Every text item has a font instance of its own: the same font is an
  // equal one.)
  for ink in self.fonts {
    if physical_equal(ink.font, font) || ink.font == font {
      return ink
    }
  }
  let ink : FontInk = { font, known: [], boxes: [], }
  self.fonts.push(ink)
  ink
}

///|
/// Where something with the span `span` comes from: the location of the
/// span, or, for a span without one (what the engine drew on its own
/// account), of the innermost element around it that has one. A group has
/// no span, so "around it" is by the tags of the elements.
fn FrameLinter::locate(
  self : FrameLinter,
  span : @syntax.Span,
) -> (Location?, Bool) {
  if self.resolver.locate(@syntax.DiagSpan::from_span(span)) is Some(location) {
    return (Some(location), false)
  }
  for i = self.elements.length() - 1; i >= 0; i = i - 1 {
    let location = self.resolver.locate(
      @syntax.DiagSpan::from_span(self.elements[i].1),
    )
    if location is Some(_) {
      return (location, true)
    }
  }
  (Option::None, false)
}

///|
/// A place for the table of findings: the source location without the
/// keys, so that the rows that a function builds for some data are one
/// place (as for L1).
fn location_key(location : Location?, page : Int) -> String {
  match location {
    Some(Edsl(origin)) => place_key(origin)
    Some(File(file)) => {
      let range = match file.range {
        Some((start, end)) => "\{start}-\{end}"
        Option::None => ""
      }
      "\{file.package_spec.unwrap_or("")}\u{0}\{file.path}\u{0}\{range}"
    }
    // Nothing to tell places apart by but the page.
    Option::None => "\u{0}page \{page}"
  }
}

///|
/// Enter a finding: a new one, or one more of a place that has one.
fn FrameLinter::found(
  self : FrameLinter,
  key : String,
  item : Int,
  amount : Double,
  side : Int,
  make : () -> Finding,
) -> Unit {
  match self.index.get(key) {
    Some(i) => {
      let finding = self.findings[i]
      if finding.last_item != item {
        finding.count += 1
        finding.last_item = item
      }
      if amount > finding.amount {
        // The message is about the farthest: what it is, and what it left.
        let farthest = make()
        finding.amount = amount
        finding.side = side
        finding.subject = farthest.subject
        finding.container = farthest.container
      }
    }
    Option::None => {
      self.index[key] = self.findings.length()
      self.findings.push(make())
    }
  }
}

///|
/// The box of `extent`, which is in a frame with the transform `mat` to
/// the page, in the coordinates that `to_local` maps the page to, as far
/// as it is drawn: inside the boxes of the clips around it. `None` if
/// nothing of it is drawn.
///
/// The box of a clip is the box of its path after the transform: more
/// than the clip where the path is not a rectangle (round corners) or is
/// rotated against the coordinates. So what is clipped away can still
/// count as drawn there, and never the other way round.
fn FrameLinter::drawn(
  self : FrameLinter,
  to_local : @kurbo.Affine,
  mat : @kurbo.Affine,
  extent : Extent,
  set~ : Bool,
) -> @kurbo.Rect? {
  guard extent.bounds(to_local * mat, set~) is Some(rect) else {
    return Option::None
  }
  let mut rect = rect
  for clip in self.clips {
    let box = (to_local * clip.0).transform_rect_bbox(clip.1)
    rect = @kurbo.Rect::new(
      if rect.x0 > box.x0 {
        rect.x0
      } else {
        box.x0
      },
      if rect.y0 > box.y0 {
        rect.y0
      } else {
        box.y0
      },
      if rect.x1 < box.x1 {
        rect.x1
      } else {
        box.x1
      },
      if rect.y1 < box.y1 {
        rect.y1
      } else {
        box.y1
      },
    )
    guard rect.x0 <= rect.x1 && rect.y0 <= rect.y1 else { return Option::None }
  }
  Some(rect)
}

///|
/// Whether the box `x0..x1`, `y0..y1` is inside `box` after the transform
/// `ts`, but for the tolerance. (Nothing is allocated: this is asked for
/// every item of a document.)
fn inside_after(
  ts : @kurbo.Affine,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  box : @kurbo.Rect,
) -> Bool {
  let c = ts.0
  // The least and the greatest of the four corners, per axis.
  let ax0 = c[0] * x0
  let ax1 = c[0] * x1
  let ay0 = c[2] * y0
  let ay1 = c[2] * y1
  let left = (if ax0 < ax1 { ax0 } else { ax1 }) +
    (if ay0 < ay1 { ay0 } else { ay1 }) +
    c[4]
  let right = (if ax0 > ax1 { ax0 } else { ax1 }) +
    (if ay0 > ay1 { ay0 } else { ay1 }) +
    c[4]
  let bx0 = c[1] * x0
  let bx1 = c[1] * x1
  let by0 = c[3] * y0
  let by1 = c[3] * y1
  let top = (if bx0 < bx1 { bx0 } else { bx1 }) +
    (if by0 < by1 { by0 } else { by1 }) +
    c[5]
  let bottom = (if bx0 > bx1 { bx0 } else { bx1 }) +
    (if by0 > by1 { by0 } else { by1 }) +
    c[5]
  box.x0 - left <= LINT_TOLERANCE &&
  box.y0 - top <= LINT_TOLERANCE &&
  right - box.x1 <= LINT_TOLERANCE &&
  bottom - box.y1 <= LINT_TOLERANCE
}

///|
/// Whether the box `x0..x1`, `y0..y1` of the frame that is walked, which
/// has the transform `mat`, is inside the page and inside every frame
/// that may be a container: nothing in it can be found.
fn FrameLinter::within(
  self : FrameLinter,
  mat : @kurbo.Affine,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Bool {
  guard inside_after(mat, x0, y0, x1, y1, self.page_box) else { return false }
  for held in self.held {
    guard inside_after(held.from_walked, x0, y0, x1, y1, held.box) else {
      return false
    }
  }
  true
}

///|
/// The frame with the transform `mat` is walked from here on.
fn FrameLinter::walking(self : FrameLinter, mat : @kurbo.Affine) -> Unit {
  for held in self.held {
    held.from_walked = held.to_local * mat
  }
}

///|
/// Whether something that leaves the frame `held` is what the container
/// `id` draws itself, not its content: its fill and its stroke, which an
/// outset puts outside on purpose. They are shapes with the span of the
/// container's call, and so is every shape that a composite builds in its
/// container (one call site for all that it builds). What tells them
/// apart: the container was called with a `fill` or a `stroke`, or the
/// shape covers the whole frame (a fill from a set rule).
fn FrameLinter::own_shape(
  self : FrameLinter,
  leaving : Leaving,
  id : Int,
  held : Held,
) -> Bool {
  leaving.own == id &&
  (
    self.origins.containers[id].decorated ||
    (
      leaving.rect.x0 <= held.box.x0 + LINT_TOLERANCE &&
      leaving.rect.y0 <= held.box.y0 + LINT_TOLERANCE &&
      leaving.rect.x1 >= held.box.x1 - LINT_TOLERANCE &&
      leaving.rect.y1 >= held.box.y1 - LINT_TOLERANCE
    )
  )
}

///|
/// Something with the span `span` is in the frames that may be
/// containers: it tells which of them is the frame of which container.
///
/// Its call site was lowered under a stack of containers (in the arguments
/// of the innermost, which was lowered in the arguments of the next, ..),
/// and the frame of a container holds what was lowered in its arguments.
/// So the frames around the item are those containers' frames, in that
/// order, with other frames between them: from the inside, each container
/// of the stack is the nearest frame around the item that has a size of
/// that container and is outside the frame of the container before it. A
/// container whose frame is not there (it was split, or the item was
/// moved out of it: a footnote, a float) is passed over.
///
/// The occurrences of a call site have the same spans, so the stack is
/// what all of them were lowered under (`Registry::note_stack`): a
/// description that is used in a container and outside of it tells
/// nothing. What has the span of a container's own call (its fill, a plain
/// string as its body, what a composite builds in it) is in that
/// container.
fn FrameLinter::evidence(self : FrameLinter, span : @syntax.Span) -> Unit {
  guard self.unconfirmed > 0 && self.origins.entry_of(span) is Some((entry, _)) else {
    return
  }
  let own = self.origins.own[entry]
  let under = self.origins.under[entry]
  guard own >= 0 || !under.is_empty() else { return }
  let mut limit = self.held.length() - 1
  let confirm = (id : Int) => {
    for h = limit; h >= 0; h = h - 1 {
      let held = self.held[h]
      for k, candidate in held.containers {
        if candidate == id {
          if !held.confirmed[k] {
            held.confirmed[k] = true
            self.unconfirmed -= 1
          }
          limit = h - 1
          return
        }
      }
    }
  }
  if own >= 0 {
    confirm(own)
  }
  for k = under.length() - 1; k >= 0; k = k - 1 {
    confirm(under[k])
  }
}

///|
/// Look at something that is drawn: `extent`, in a frame with the
/// transform `mat`, with the span `span`.
fn FrameLinter::drawing(
  self : FrameLinter,
  subject : String,
  span : @syntax.Span,
  extent : Extent,
  mat : @kurbo.Affine,
  shape : Bool,
) -> Unit {
  // The page: what is drawn outside of it is cut off.
  guard self.drawn(@kurbo.Affine::identity(), mat, extent, set=false)
    is Some(rect) else {
    return
  }
  let mut place : (Location?, Bool)? = Option::None
  let locate = () => {
    match place {
      Some(place) => place
      Option::None => {
        let found = self.locate(span)
        place = Some(found)
        found
      }
    }
  }
  let (amount, side) = leaves(rect, self.page_box, true, true)
  if amount > LINT_TOLERANCE {
    let (location, indirect) = locate()
    let page = self.page
    let item = self.item
    self.found("page\u{0}\{location_key(location, page)}", item, amount, side, () => {
      kind: OutsidePage,
      location,
      indirect,
      page,
      subject,
      font: "",
      container: Option::None,
      count: 1,
      last_item: item,
      amount,
      side,
    })
  }
  // The frames that may be containers: nothing is cut off there, and
  // the question is what was set outside.
  for held in self.held {
    guard self.drawn(held.to_local, mat, extent, set=true) is Some(rect) else {
      continue
    }
    let slack = extent.slack(held.to_local * mat)
    if leaves(rect, held.box, true, true, slack~).0 > LINT_TOLERANCE {
      let (location, indirect) = locate()
      held.leaving.push({
        item: self.item,
        subject,
        rect,
        slack,
        location,
        indirect,
        own: if shape && self.origins.entry_of(span) is Some((entry, false)) {
          self.origins.own[entry]
        } else {
          -1
        },
      })
    }
  }
}

///|
/// The characters of the text of a text item with their places in it, to
/// cut it at the ranges of its glyphs (which are in bytes of UTF-8).
priv struct ItemText {
  chars : Array[Char]
  /// The byte offset of each character, and the length of the text.
  offsets : Array[Int]
}

///|
fn ItemText::new(text : String) -> ItemText {
  let chars = text.to_array()
  let offsets : Array[Int] = Array(capacity=chars.length() + 1)
  let mut at = 0
  for c in chars {
    offsets.push(at)
    let n = c.to_int()
    at += if n < 0x80 {
      1
    } else if n < 0x800 {
      2
    } else if n < 0x10000 {
      3
    } else {
      4
    }
  }
  offsets.push(at)
  { chars, offsets, }
}

///|
/// The characters of the bytes `from..to`, which is what a glyph stands
/// for. `None` where the range says nothing: the offsets of a glyph are
/// 16-bit numbers, so beyond 65,535 bytes of an item they all end there.
fn ItemText::range(self : ItemText, from : Int, to : Int) -> ArrayView[Char]? {
  guard from < to &&
    self.offsets.binary_search(from) is Ok(first) &&
    self.offsets.binary_search(to) is Ok(end) else {
    return Option::None
  }
  Some(self.chars[first:end])
}

///|
/// `U+4E2D`: a code point in the notation of Unicode.
fn code_point(c : Char) -> String {
  let digits = "0123456789ABCDEF"
  let out : Array[Char] = []
  let mut n = c.to_int()
  while n > 0 || out.length() < 4 {
    out.push(digits.get_char(n % 16).unwrap())
    n = n / 16
  }
  out.rev_in_place()
  "U+" + String::from_array(out)
}

///|
/// The characters of a missing glyph for a message: as text and as code
/// points. A character that would show nothing (a control character, a
/// space, one that is ignored by default) is a code point only.
fn glyph_subject(chars : ArrayView[Char]) -> String {
  let shown = chars.filter(c => {
    let n = c.to_int()
    !(n < 0x20 ||
    (n >= 0x7f && n < 0xa0) ||
    @unicode.is_whitespace(c) ||
    @unicode.is_default_ignorable(c))
  })
  let points = chars.map(code_point).join(" ")
  if shown.is_empty() {
    points
  } else {
    "\"\{String::from_array(shown)}\" (\{points})"
  }
}

///|
/// L2 for a text item: its glyphs with the id 0.
///
/// Glyph 0 is the font's glyph for a missing character (`.notdef`), and
/// the shaper of the engine gives it out in one case only: no font of the
/// list, and with `fallback` no font of the world, has a glyph for a
/// character, so the first font of the list sets it (`shape_tofus` in
/// `layout/inline_shaping.mbt` and `layout/math_shaping.mbt`; a glyph 0
/// that shaping with a font returns is never kept, but shaped again with
/// the next font).
fn FrameLinter::missing(self : FrameLinter, text : @library.TextItem) -> Unit {
  let mut chars : ItemText? = Option::None
  for glyph in text.glyphs {
    guard glyph.id == 0 else { continue }
    let chars = match chars {
      Some(chars) => chars
      Option::None => {
        let made = ItemText::new(text.text)
        chars = Some(made)
        made
      }
    }
    let (from, to) = glyph.range()
    let subject = match chars.range(from, to) {
      Some(cluster) => glyph_subject(cluster)
      // The item's text, as far as a message can show it.
      Option::None =>
        "a character of \"\{clip_text(chars.chars, false, false)}\" (a text of more than 65,535 bytes: the page does not say which)"
    }
    let (location, indirect) = self.locate(glyph.span)
    let page = self.page
    // Every glyph is one: the item is not what is counted.
    self.item += 1
    let item = self.item
    self.found(
      "glyph\u{0}\{location_key(location, 0)}\u{0}\{subject}",
      item,
      0.0,
      0,
      () => {
        kind: MissingGlyph,
        location,
        indirect,
        page,
        subject,
        font: text.font.font().info().family,
        container: Option::None,
        count: 1,
        last_item: item,
        amount: 0.0,
        side: 0,
      },
    )
  }
}

///|
/// A text item at `(x, y)` (its pen on the baseline) in a frame with the
/// transform `mat`.
///
/// What is drawn of a glyph is the box of its outline, widened by half of
/// a stroke. The advance of a glyph and the ascent and descent of its font
/// say where text is set, not where it is seen: a line at the top of a
/// page is higher than its letters by the font's ascent, and nothing of
/// it is cut off. So for the page a glyph is the box of its outline.
///
/// In a container nothing is cut off, and what is found is what was set
/// outside of it. There the engine's own box of a line counts: by default
/// a line of text reaches from the cap height to the baseline (`top-edge`
/// and `bottom-edge` of `text`), so the descenders of the last line of
/// every block are below the block, and a block that is as high as its
/// lines (one that was measured, like a card of the kit) has them
/// outside by the engine's choice. Of the box of a glyph the part between
/// the baseline and the cap height is what is set. Along the line the
/// engine lets a mark hang over the end (`hang_of`).
fn FrameLinter::text(
  self : FrameLinter,
  text : @library.TextItem,
  x : Double,
  y : Double,
  mat : @kurbo.Affine,
) -> Unit {
  self.item += 1
  if self.unconfirmed > 0 {
    let mut last : @syntax.Span? = Option::None
    for glyph in text.glyphs {
      if last is Some(span) && span == glyph.span {
        continue
      }
      last = Some(glyph.span)
      self.evidence(glyph.span)
    }
  }
  let ink = self.ink(text.font)
  let size = text.size.to_pt()
  let pad = match text.stroke {
    Some(stroke) => stroke.thickness.to_pt() / 2.0
    Option::None => 0.0
  }
  // All glyphs at once: nearly every item is inside. The pen moves along
  // the line by the advance of a glyph, and upwards by its vertical
  // advance (the pieces of a delimiter that a formula builds).
  let mut pen = x
  let mut rise = 0.0
  let mut missing = false
  let mut x0 = 1.0e300
  let mut y0 = 1.0e300
  let mut x1 = -1.0e300
  let mut y1 = -1.0e300
  for glyph in text.glyphs {
    let id = glyph.id.to_int()
    if id == 0 {
      missing = true
    }
    if ink.has(id) {
      let gx = pen + glyph.x_offset.get() * size
      let gy = y - rise - glyph.y_offset.get() * size
      let left = gx + ink.boxes[4 * id] * size
      let top = gy + ink.boxes[4 * id + 1] * size
      let right = gx + ink.boxes[4 * id + 2] * size
      let bottom = gy + ink.boxes[4 * id + 3] * size
      if left < x0 {
        x0 = left
      }
      if top < y0 {
        y0 = top
      }
      if right > x1 {
        x1 = right
      }
      if bottom > y1 {
        y1 = bottom
      }
    }
    pen += glyph.x_advance.get() * size
    rise += glyph.y_advance.get() * size
  }
  if missing {
    self.missing(text)
  }
  guard x0 <= x1 && !self.within(mat, x0 - pad, y0 - pad, x1 + pad, y1 + pad) else {
    return
  }
  // Glyph by glyph: each has its own span.
  let chars = ItemText::new(text.text)
  let cap = text.font.metrics().cap_height.get() * size
  pen = x
  rise = 0.0
  for glyph in text.glyphs {
    let advance = glyph.x_advance.get() * size
    let id = glyph.id.to_int()
    let gx = pen + glyph.x_offset.get() * size
    // The baseline of the glyph.
    let base = y - rise - glyph.y_offset.get() * size
    pen += advance
    rise += glyph.y_advance.get() * size
    guard ink.has(id) else { continue }
    let box = @kurbo.Rect::new(
      gx + ink.boxes[4 * id] * size - pad,
      base + ink.boxes[4 * id + 1] * size - pad,
      gx + ink.boxes[4 * id + 2] * size + pad,
      base + ink.boxes[4 * id + 3] * size + pad,
    )
    guard !self.within(mat, box.x0, box.y0, box.x1, box.y1) else { continue }
    let (from, to) = glyph.range()
    let hang = match chars.range(from, to) {
      Some([c]) => hang_of(c) * advance.abs()
      _ => 0.0
    }
    // Between the cap height and the baseline.
    let between = (v : Double) => {
      if v < base - cap {
        base - cap
      } else if v > base {
        base
      } else {
        v
      }
    }
    let set = @kurbo.Rect::new(box.x0, between(box.y0), box.x1, between(box.y1))
    self.drawing("text", glyph.span, EGlyph(box, set, hang), mat, false)
  }
}

///|
/// How many periods of a dash pattern the outline of a stroke is made
/// with (`FrameLinter::shape`).
const MAX_DASH_PERIODS : Double = 2000.0

///|
/// A shape at `(x, y)` in a frame with the transform `mat`. A shape that
/// draws nothing is nothing.
///
/// What is drawn is the interior of a filled shape and the outline of its
/// stroke, with its dashes: that is what the page cuts off. In a container a shape is where its path is: the engine
/// draws a stroke on the path, half of it to either side, and gives it no
/// room, so the stroke of what fills its container (the frame of a
/// drawing, the rules of a table) is outside by half by the engine's
/// choice, like the descenders of a line.
fn FrameLinter::shape(
  self : FrameLinter,
  shape : @library.Shape,
  span : @syntax.Span,
  x : Double,
  y : Double,
  mat : @kurbo.Affine,
) -> Unit {
  let filled = shape.fill is Some(_) && !(shape.geometry is Line(_))
  let stroke = match shape.stroke {
    Some(stroke) if !stroke.thickness.approx_empty() => Some(stroke)
    _ => Option::None
  }
  guard filled || stroke is Some(_) else { return }
  self.item += 1
  self.evidence(span)
  // A box around it first: of its points and of what a stroke can reach.
  let (x0, y0, x1, y1) = shape_box(shape, x, y)
  guard !self.within(mat, x0, y0, x1, y1) else { return }
  let path : Array[@kurbo.PathEl] = match shape.geometry {
    Line(to) =>
      [
        MoveTo(@kurbo.Point::new(0.0, 0.0)),
        LineTo(@kurbo.Point::new(to.x.to_raw(), to.y.to_raw())),
      ]
    Rect(size) => curve_to_kurbo(@library.Curve::rect(size))
    Curve(curve) => curve_to_kurbo(curve)
  }
  guard has_segments(path) else { return }
  let paths : Array[@kurbo.BezPath] = []
  if filled {
    paths.push(@kurbo.BezPath::from_vec(closed_path(path)))
  }
  if stroke is Some(stroke) {
    // The dashes as they are drawn, unless there are too many to make
    // (the box around the shape, `x0..y1`, is longer than any of its
    // lines if it is of lines): then the line as a whole, which is more.
    let dashed = match stroke.dash {
      Some(dash) => {
        let mut period = 0.0
        let mut regular = !dash.array.is_empty()
        for length in dash.array {
          let length = length.to_pt()
          regular = regular && length >= 0.0 && length < 1.0e9
          period += length
        }
        regular &&
        period > 0.0 &&
        (x1 - x0 + (y1 - y0)) / period < MAX_DASH_PERIODS
      }
      Option::None => false
    }
    let outline = stroke_outline(path, stroke, dashed)
    if has_segments(outline.elements()) {
      paths.push(outline)
    }
  }
  guard !paths.is_empty() else { return }
  self.drawing(
    "a shape",
    span,
    EShape(@kurbo.BezPath::from_vec(path), paths),
    mat * @kurbo.Affine::translate(x, y) * raw_to_pt,
    true,
  )
}

///|
/// The containers that were built with the size `width` by `height` of a
/// frame (but for `SIZE_TOLERANCE`), and for each whether its width and
/// its height were given.
fn FrameLinter::sized(
  self : FrameLinter,
  width : Double,
  height : Double,
) -> (Array[Int], Array[(Bool, Bool)]) {
  let containers : Array[Int] = []
  let fixed : Array[(Bool, Bool)] = []
  let kw = size_key(width)
  let kh = size_key(height)
  for row_key in [kw - 1, kw, kw + 1, NO_SIDE] {
    guard self.sizes.get(row_key) is Some(row) else { continue }
    for key in [kh - 1, kh, kh + 1, NO_SIDE] {
      guard row.get(key) is Some(list) else { continue }
      for entry in list {
        let (id, w, h) = entry
        let x = match w {
          Some(w) => {
            guard (w - width).abs() <= SIZE_TOLERANCE else { continue }
            true
          }
          Option::None => false
        }
        let y = match h {
          Some(h) => {
            guard (h - height).abs() <= SIZE_TOLERANCE else { continue }
            true
          }
          Option::None => false
        }
        match containers.search(id) {
          Some(k) => fixed[k] = (fixed[k].0 || x, fixed[k].1 || y)
          Option::None => {
            containers.push(id)
            fixed.push((x, y))
          }
        }
      }
    }
  }
  (containers, fixed)
}

///|
/// What a container is, for a message: its constructor and the size of
/// its frame.
fn FrameLinter::container_name(
  self : FrameLinter,
  id : Int,
  held : Held,
) -> (Origin, String) {
  let origin = self.origins.origin_of(
    self.origins.containers[id].entry,
    Option::None,
    Option::None,
  )
  (origin, "\{origin.kind}, \{points(held.box.x1)} by \{points(held.box.y1)}")
}

///|
/// The frame `held` is walked: for each container that it is the frame
/// of, what left it along a side that the container fixed.
fn FrameLinter::close(self : FrameLinter, held : Held) -> Unit {
  for k, id in held.containers {
    guard held.confirmed[k] else {
      self.unconfirmed -= 1
      continue
    }
    let (x, y) = held.fixed[k]
    for leaving in held.leaving {
      guard !self.own_shape(leaving, id, held) else { continue }
      let (amount, side) = leaves(
        leaving.rect,
        held.box,
        x,
        y,
        slack=leaving.slack,
      )
      guard amount > LINT_TOLERANCE else { continue }
      let page = self.page
      self.found(
        "container\u{0}\{self.origins.containers[id].loc}\u{0}\{location_key(leaving.location, page)}",
        leaving.item,
        amount,
        side,
        () => {
          kind: OutsideContainer,
          location: leaving.location,
          indirect: leaving.indirect,
          page,
          subject: leaving.subject,
          font: "",
          container: Some(self.container_name(id, held)),
          count: 1,
          last_item: leaving.item,
          amount,
          side,
        },
      )
    }
  }
}

///|
/// A group at `(x, y)` in a frame with the transform `mat`.
fn FrameLinter::group(
  self : FrameLinter,
  group : @library.GroupItem,
  x : Double,
  y : Double,
  mat : @kurbo.Affine,
) -> Unit {
  let ts = group.transform
  // The frame's coordinates: the group's transform, then its place.
  let inside = mat *
    @kurbo.Affine::new([
      ts.sx.get(),
      ts.ky.get(),
      ts.kx.get(),
      ts.sy.get(),
      ts.tx.to_pt() + x,
      ts.ty.to_pt() + y,
    ])
  let frame = group.frame
  // A group that draws nothing (a scale of zero, a clip without an
  // area) has nothing outside of anything; its tags still open and close
  // elements.
  let mut hidden = inside.determinant().abs() < 1.0e-12 || !inside.is_finite()
  let mut clipped = false
  if !hidden && group.clip is Some(clip) {
    // Like the exporters, in the frame's coordinates. (The engine never
    // gives one group a clip and a transform.)
    let path = curve_to_kurbo(clip)
    if has_segments(path) {
      self.clips.push(
        (inside * raw_to_pt, @kurbo.BezPath::from_vec(path).bounding_box()),
      )
      clipped = true
    } else {
      hidden = true
    }
  }
  if hidden {
    self.tags(frame)
    return
  }
  let mut held : Held? = Option::None
  if frame.kind().is_hard() && !self.sizes.is_empty() {
    let width = frame.width().to_pt()
    let height = frame.height().to_pt()
    let (containers, fixed) = self.sized(width, height)
    if !containers.is_empty() {
      let frame : Held = {
        to_local: inside.inverse(),
        from_walked: @kurbo.Affine::identity(),
        box: @kurbo.Rect::new(0.0, 0.0, width, height),
        confirmed: containers.map(_ => false),
        containers,
        fixed,
        leaving: [],
      }
      self.unconfirmed += frame.containers.length()
      self.held.push(frame)
      held = Some(frame)
    }
  }
  self.frame(frame, inside)
  // (The frame around the group is walked again.)
  self.walking(mat)
  if held is Some(held) {
    self.held.pop() |> ignore
    self.close(held)
  }
  if clipped {
    self.clips.pop() |> ignore
  }
}

///|
/// The tags of a frame that is not drawn.
fn FrameLinter::tags(self : FrameLinter, frame : @library.Frame) -> Unit {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => self.tags(group.frame)
      Tag(tag) => self.tag(tag)
      _ => ()
    }
  }
}

///|
/// A tag: an element starts or ends.
fn FrameLinter::tag(self : FrameLinter, tag : @library.Tag) -> Unit {
  match tag {
    Start(content, _) =>
      if content.location() is Some(location) {
        self.elements.push((location, content.span()))
      }
    End(location, _, _) =>
      for i = self.elements.length() - 1; i >= 0; i = i - 1 {
        if self.elements[i].0 == location {
          self.elements.truncate(i)
          break
        }
      }
  }
}

///|
/// The items of a frame with the transform `mat` to the page.
fn FrameLinter::frame(
  self : FrameLinter,
  frame : @library.Frame,
  mat : @kurbo.Affine,
) -> Unit {
  self.walking(mat)
  for entry in frame.items() {
    let (pos, item) = entry
    let x = pos.x.to_pt()
    let y = pos.y.to_pt()
    match item {
      Group(group) => self.group(group, x, y, mat)
      Text(text) => self.text(text, x, y, mat)
      Shape(shape, span) => self.shape(shape, span, x, y, mat)
      Image(_, size, span) => {
        self.item += 1
        self.evidence(span)
        let right = x + size.x.to_pt()
        let bottom = y + size.y.to_pt()
        if !self.within(mat, x, y, right, bottom) {
          let box = @kurbo.Rect::new(x, y, right, bottom)
          self.drawing("an image", span, ERect(box), mat, false)
        }
      }
      Tag(tag) => self.tag(tag)
      // A link is an area of the page, not something that is drawn.
      Link(_, _) => ()
    }
  }
}

///|
/// The lints of the pages of a document, in the order in which their
/// first findings are met.
fn lint_pages(
  document : @layout.PagedDocument,
  origins : Origins,
  resolver : Resolver,
) -> Array[Lint] {
  let linter = FrameLinter::new(origins, resolver)
  for i, page in document.pages() {
    let size = page.frame.size()
    linter.page = i + 1
    // The page with its bleed: the engine lays the background and the
    // foreground out in this box, and the PDF has it.
    linter.page_box = @kurbo.Rect::new(
      -page.bleed.left.to_pt(),
      -page.bleed.top.to_pt(),
      size.x.to_pt() + page.bleed.right.to_pt(),
      size.y.to_pt() + page.bleed.bottom.to_pt(),
    )
    linter.frame(page.frame, @kurbo.Affine::identity())
  }
  linter.findings.map(finding => finding.lint())
}
