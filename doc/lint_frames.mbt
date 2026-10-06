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
  /// The area of paths: the interior of a filled shape, the outline of
  /// its stroke.
  EPaths(Array[@kurbo.BezPath])
}

///|
/// The bounding box of the extent after the transform `ts`. For a path it
/// is the box of the transformed path, so a rotated circle has the box of
/// a circle; for a rectangle it is the box of its four corners. `set`: of
/// a glyph the part that is set in a line, not all that is drawn.
fn Extent::bounds(
  self : Extent,
  ts : @kurbo.Affine,
  set~ : Bool,
) -> @kurbo.Rect? {
  match self {
    ERect(rect) => Some(ts.transform_rect_bbox(rect))
    EGlyph(drawn, part, _) =>
      Some(ts.transform_rect_bbox(if set { part } else { drawn }))
    EPaths(paths) => {
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
  slack? : (Double, Double) = (0.0, 0.0),
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
  /// `MissingGlyph`: the characters. Otherwise what left: `text`, `a
  /// shape`, `an image`.
  subject : String
  /// `MissingGlyph`: the family of the font.
  font : String
  /// `OutsideContainer`: the container's origin, and what it is.
  container : (Origin, String)?
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
        message: "use a font that has it: name its family in the `font` of `SetText` or `Text`; a font that is not embedded comes from `font_paths` or from the system's fonts (docs/edsl-guide.md, section 5)",
        location: Option::None,
      })
      let times = if self.count > 1 { ", \{self.count} times" } else { "" }
      "no font has a glyph for \{self.subject}: it is drawn as the missing glyph of \{self.font}\{times}"
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
  /// The entry of its span if it is a shape with the span of a call
  /// itself: what a call draws of its own (the fill and the stroke of a
  /// block).
  own : Int?
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
  /// The sizes that containers were built with: by their width, with the
  /// height where one was given, and by their height alone.
  by_width : Map[Double, Array[(Int, Double?)]]
  by_height : Map[Double, Array[Int]]
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
fn FrameLinter::new(origins : Origins, resolver : Resolver) -> FrameLinter {
  let by_width : Map[Double, Array[(Int, Double?)]] = Map([])
  let by_height : Map[Double, Array[Int]] = Map([])
  for id, container in origins.containers {
    for size in container.sizes {
      match size {
        (Some(width), height) => {
          let list = match by_width.get(width.to_pt()) {
            Some(list) => list
            Option::None => {
              let list = []
              by_width[width.to_pt()] = list
              list
            }
          }
          list.push((id, height.map(h => h.to_pt())))
        }
        (Option::None, Some(height)) => {
          let list = match by_height.get(height.to_pt()) {
            Some(list) => list
            Option::None => {
              let list = []
              by_height[height.to_pt()] = list
              list
            }
          }
          list.push(id)
        }
        (Option::None, Option::None) => ()
      }
    }
  }
  {
    origins,
    resolver,
    findings: [],
    index: Map([]),
    fonts: [],
    by_width,
    by_height,
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
        finding.amount = amount
        finding.side = side
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
/// Whether a shape with the entry `entry` of its span is what the
/// container `id` draws of its own: its fill and its stroke, which an
/// outset puts outside of it on purpose.
fn FrameLinter::own_shape(self : FrameLinter, own : Int?, id : Int) -> Bool {
  own is Some(entry) &&
  self.origins.entries[entry].loc == self.origins.containers[id].loc
}

///|
/// Something with the span `span` is in the frames that may be
/// containers: a frame holds what was lowered inside a container that had
/// its size, so it is that container's.
fn FrameLinter::evidence(
  self : FrameLinter,
  span : @syntax.Span,
  shape : Bool,
) -> Unit {
  guard self.unconfirmed > 0 &&
    self.origins.entry_of(span) is Some((entry, argument)) else {
    return
  }
  let inside = self.origins.inside[entry]
  guard !inside.is_empty() else { return }
  let own = if shape && !argument { Some(entry) } else { Option::None }
  for held in self.held {
    for k, id in held.containers {
      if !held.confirmed[k] && inside.contains(id) && !self.own_shape(own, id) {
        held.confirmed[k] = true
        self.unconfirmed -= 1
      }
    }
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
          Some(entry)
        } else {
          Option::None
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
      self.evidence(glyph.span, false)
    }
  }
  let ink = self.ink(text.font)
  let size = text.size.to_pt()
  let pad = match text.stroke {
    Some(stroke) => stroke.thickness.to_pt() / 2.0
    Option::None => 0.0
  }
  // All glyphs at once: nearly every item is inside.
  let mut pen = x
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
      let gy = y - glyph.y_offset.get() * size
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
  for glyph in text.glyphs {
    let advance = glyph.x_advance.get() * size
    let id = glyph.id.to_int()
    let gx = pen + glyph.x_offset.get() * size
    // The baseline of the glyph.
    let base = y - glyph.y_offset.get() * size
    pen += advance
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
/// A shape at `(x, y)` in a frame with the transform `mat`: the interior
/// of a filled shape and the outline of its stroke (a dashed line counts
/// as a whole line). A shape that draws nothing is nothing.
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
  self.evidence(span, true)
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
    let outline = stroke_outline(path, stroke, false)
    if has_segments(outline.elements()) {
      paths.push(outline)
    }
  }
  guard !paths.is_empty() else { return }
  self.drawing(
    "a shape",
    span,
    EPaths(paths),
    mat * @kurbo.Affine::translate(x, y) * raw_to_pt,
    true,
  )
}

///|
/// The frames with the size `width` by `height` that containers were
/// built with: the containers, and whether their width and their height
/// were given.
fn FrameLinter::sized(
  self : FrameLinter,
  width : Double,
  height : Double,
) -> (Array[Int], Array[(Bool, Bool)]) {
  let containers : Array[Int] = []
  let fixed : Array[(Bool, Bool)] = []
  let add = (id : Int, x : Bool, y : Bool) => {
    for k, other in containers {
      if other == id {
        fixed[k] = (fixed[k].0 || x, fixed[k].1 || y)
        return
      }
    }
    containers.push(id)
    fixed.push((x, y))
  }
  if self.by_width.get(width) is Some(list) {
    for entry in list {
      match entry.1 {
        Some(h) => if h == height { add(entry.0, true, true) }
        Option::None => add(entry.0, true, false)
      }
    }
  }
  if self.by_height.get(height) is Some(list) {
    for id in list {
      add(id, false, true)
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
      guard !self.own_shape(leaving.own, id) else { continue }
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
  if frame.kind().is_hard() &&
    !(self.by_width.is_empty() && self.by_height.is_empty()) {
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
        self.evidence(span, false)
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
