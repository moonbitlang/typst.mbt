// Value facades (docs/edsl-design.md, section 6.4): typed, immutable
// descriptions of engine values that are lowered through Typst's public
// functions and values.

///|
/// A paint: a colour, a gradient ([Paint::linear], [Paint::radial],
/// [Paint::conic]), or any paint value through `Value`.
pub(all) enum Paint {
  /// Explicit `auto`, where the field accepts it.
  Auto
  /// Explicit `none`, where the field accepts it.
  None
  /// `rgb("#rrggbb")` (any string `rgb` accepts).
  Rgb(String)
  /// `luma(n)` with `n` in `0..=255`.
  Luma(Int)
  Black
  Gray
  Silver
  White
  Navy
  Blue
  Aqua
  Teal
  Eastern
  Purple
  Fuchsia
  Maroon
  Red
  Orange
  Yellow
  Olive
  Green
  Lime
  /// Any paint value, e.g. `Value::call("gradient.linear", ..)`.
  Value(Value)
}

///|
pub impl ToValue for Paint with fn to_value(self) {
  match self {
    Auto => Value::auto()
    None => Value::none()
    Rgb(hex) => Value::native(@library.native_color_rgb(), [Value::str(hex)])
    Luma(n) =>
      Value::native(@library.native_color_luma(), [Value::int(n.to_int64())])
    Black => Value::global("black")
    Gray => Value::global("gray")
    Silver => Value::global("silver")
    White => Value::global("white")
    Navy => Value::global("navy")
    Blue => Value::global("blue")
    Aqua => Value::global("aqua")
    Teal => Value::global("teal")
    Eastern => Value::global("eastern")
    Purple => Value::global("purple")
    Fuchsia => Value::global("fuchsia")
    Maroon => Value::global("maroon")
    Red => Value::global("red")
    Orange => Value::global("orange")
    Yellow => Value::global("yellow")
    Olive => Value::global("olive")
    Green => Value::global("green")
    Lime => Value::global("lime")
    Value(value) => value
  }
}

///|
/// A stroke (`stroke(paint: .., thickness: .., ..)`).
pub struct Stroke {
  priv value : Value
}

///|
pub fn Stroke::Stroke(
  paint? : Paint,
  thickness? : Length,
  cap? : String,
  join? : String,
  dash? : Value,
  miter_limit? : Double,
) -> Stroke {
  let named : Array[(String, Value)] = []
  if paint is Some(v) {
    named.push(("paint", v.to_value()))
  }
  if thickness is Some(v) {
    named.push(("thickness", v.to_value()))
  }
  if cap is Some(v) {
    named.push(("cap", Value::str(v)))
  }
  if join is Some(v) {
    named.push(("join", Value::str(v)))
  }
  if dash is Some(v) {
    named.push(("dash", v))
  }
  if miter_limit is Some(v) {
    named.push(("miter-limit", Value::float(v)))
  }
  { value: Value::native(@library.native_stroke_construct(), [], named~), }
}

///|
/// Explicit `none`, where the field accepts it.
pub fn Stroke::none() -> Stroke {
  { value: Value::none(), }
}

///|
/// Explicit `auto`, where the field accepts it.
pub fn Stroke::auto() -> Stroke {
  { value: Value::auto(), }
}

///|
pub impl ToValue for Stroke with fn to_value(self) {
  self.value
}

// Gradients: typed constructors for Typst's `gradient.*` functions.

///|
/// The stops of a gradient: colours, or colours with offsets
/// ([Paint::stop]).
fn gradient_stops(stops : Array[Paint]) -> Array[Value] {
  stops.map(stop => stop.to_value())
}

///|
/// A colour stop of a gradient at an offset: `(color, 30%)`.
pub fn Paint::stop(color : Paint, offset : Length) -> Paint {
  Value(Value::array([color.to_value(), offset.to_value()]))
}

///|
/// The colours of one of Typst's colour maps (`color.map.rainbow`,
/// `"viridis"`, ...) as gradient stops: `Paint::conic(Paint::map("rainbow"))`
/// is `gradient.conic(..color.map.rainbow)`.
pub fn Paint::map(name : String) -> Array[Paint] {
  [Value(Value::spread(Value::global("color.map." + name)))]
}

///|
/// `gradient.linear(..stops, angle: .., relative: ..)`.
pub fn Paint::linear(
  stops : Array[Paint],
  angle? : Angle,
  dir? : Dir,
  relative? : String,
) -> Paint {
  let named : Array[(String, Value)] = []
  if angle is Some(v) {
    named.push(("angle", v.to_value()))
  }
  if dir is Some(v) {
    named.push(("dir", v.to_value()))
  }
  if relative is Some(v) {
    named.push(("relative", Value::str(v)))
  }
  Value(
    Value::native(
      @library.native_gradient_linear(),
      gradient_stops(stops),
      named~,
    ),
  )
}

///|
/// `gradient.radial(..stops, center: .., radius: .., relative: ..)`.
pub fn Paint::radial(
  stops : Array[Paint],
  center? : (Length, Length),
  radius? : Length,
  focal_center? : (Length, Length),
  focal_radius? : Length,
  relative? : String,
) -> Paint {
  let named : Array[(String, Value)] = []
  if center is Some((x, y)) {
    named.push(("center", Value::array([x.to_value(), y.to_value()])))
  }
  if radius is Some(v) {
    named.push(("radius", v.to_value()))
  }
  if focal_center is Some((x, y)) {
    named.push(("focal-center", Value::array([x.to_value(), y.to_value()])))
  }
  if focal_radius is Some(v) {
    named.push(("focal-radius", v.to_value()))
  }
  if relative is Some(v) {
    named.push(("relative", Value::str(v)))
  }
  Value(
    Value::native(
      @library.native_gradient_radial(),
      gradient_stops(stops),
      named~,
    ),
  )
}

///|
/// `gradient.conic(..stops, angle: .., center: .., relative: ..)`.
pub fn Paint::conic(
  stops : Array[Paint],
  angle? : Angle,
  center? : (Length, Length),
  relative? : String,
) -> Paint {
  let named : Array[(String, Value)] = []
  if angle is Some(v) {
    named.push(("angle", v.to_value()))
  }
  if center is Some((x, y)) {
    named.push(("center", Value::array([x.to_value(), y.to_value()])))
  }
  if relative is Some(v) {
    named.push(("relative", Value::str(v)))
  }
  Value(
    Value::native(
      @library.native_gradient_conic(),
      gradient_stops(stops),
      named~,
    ),
  )
}

///|
/// Values for the four sides of a box. `all` is the uniform value (as in
/// `inset: 9pt`) and excludes the others; otherwise the given sides form
/// Typst's dictionary (`(x: .., top: .., rest: ..)`).
pub struct Sides[T] {
  priv all : T?
  priv sides : Array[(String, T)]
  /// Explicit `auto` or `none` for the field as a whole.
  priv state : Value?
}

///|
pub fn[T] Sides::Sides(
  all? : T,
  x? : T,
  y? : T,
  left? : T,
  top? : T,
  right? : T,
  bottom? : T,
  rest? : T,
) -> Sides[T] {
  let sides : Array[(String, T)] = []
  if x is Some(v) {
    sides.push(("x", v))
  }
  if y is Some(v) {
    sides.push(("y", v))
  }
  if left is Some(v) {
    sides.push(("left", v))
  }
  if top is Some(v) {
    sides.push(("top", v))
  }
  if right is Some(v) {
    sides.push(("right", v))
  }
  if bottom is Some(v) {
    sides.push(("bottom", v))
  }
  if rest is Some(v) {
    sides.push(("rest", v))
  }
  { all, sides, state: Option::None, }
}

///|
/// Explicit `auto` for the field as a whole, where it accepts it.
pub fn[T] Sides::auto() -> Sides[T] {
  { all: Option::None, sides: [], state: Some(Value::auto()), }
}

///|
/// Explicit `none` for the field as a whole, where it accepts it.
pub fn[T] Sides::none() -> Sides[T] {
  { all: Option::None, sides: [], state: Some(Value::none()), }
}

///|
pub impl[T : ToValue] ToValue for Sides[T] with fn to_value(self) {
  if self.state is Some(state) {
    return state
  }
  let dict = Value::dict(self.sides.map(pair => (pair.0, pair.1.to_value())))
  match self.all {
    Some(all) =>
      if self.sides.is_empty() {
        all.to_value()
      } else {
        Value::of(VInvalid("`all` cannot be combined with individual sides"))
      }
    None => dict
  }
}

///|
/// Values for the four corners of a box, like [Sides].
pub struct Corners[T] {
  priv all : T?
  priv corners : Array[(String, T)]
}

///|
pub fn[T] Corners::Corners(
  all? : T,
  top? : T,
  bottom? : T,
  left? : T,
  right? : T,
  top_left? : T,
  top_right? : T,
  bottom_left? : T,
  bottom_right? : T,
  rest? : T,
) -> Corners[T] {
  let corners : Array[(String, T)] = []
  if top is Some(v) {
    corners.push(("top", v))
  }
  if bottom is Some(v) {
    corners.push(("bottom", v))
  }
  if left is Some(v) {
    corners.push(("left", v))
  }
  if right is Some(v) {
    corners.push(("right", v))
  }
  if top_left is Some(v) {
    corners.push(("top-left", v))
  }
  if top_right is Some(v) {
    corners.push(("top-right", v))
  }
  if bottom_left is Some(v) {
    corners.push(("bottom-left", v))
  }
  if bottom_right is Some(v) {
    corners.push(("bottom-right", v))
  }
  if rest is Some(v) {
    corners.push(("rest", v))
  }
  { all, corners, }
}

///|
pub impl[T : ToValue] ToValue for Corners[T] with fn to_value(self) {
  let dict = Value::dict(self.corners.map(pair => (pair.0, pair.1.to_value())))
  match self.all {
    Some(all) =>
      if self.corners.is_empty() {
        all.to_value()
      } else {
        Value::of(VInvalid("`all` cannot be combined with individual corners"))
      }
    None => dict
  }
}

///|
/// An alignment (`left`, `center + horizon`, ...).
pub(all) enum Alignment {
  /// Explicit `auto`, where the field accepts it.
  Auto
  /// Explicit `none`, where the field accepts it.
  None
  Start
  Left
  Center
  Right
  End
  Top
  Horizon
  Bottom
  /// `a + b`.
  Both(Alignment, Alignment)
}

///|
pub impl Add for Alignment with fn add(self, other) {
  Both(self, other)
}

///|
pub impl ToValue for Alignment with fn to_value(self) {
  match self {
    Auto => Value::auto()
    None => Value::none()
    Start => Value::global("start")
    Left => Value::global("left")
    Center => Value::global("center")
    Right => Value::global("right")
    End => Value::global("end")
    Top => Value::global("top")
    Horizon => Value::global("horizon")
    Bottom => Value::global("bottom")
    Both(a, b) => Value::of(VAdd(a.to_value(), b.to_value()))
  }
}

///|
/// A numbering: a pattern (`"1.1"`) or a callback.
pub struct Numbering {
  priv value : Value
}

///|
pub fn Numbering::Numbering(pattern : String) -> Numbering {
  { value: Value::str(pattern), }
}

///|
/// A numbering computed by a callback from the counter's numbers.
#callsite(autofill(loc, args_loc))
pub fn Numbering::func(
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
  f : (Array[Int64], Ctx) -> &IntoContent raise,
) -> Numbering {
  let site = Site::new("Numbering::func", loc, args_loc)
  let callback = Callback::new(site, (cx, args) => {
    let numbers : Array[Int64] = args.all()
    Value::content(f(numbers, cx))
  })
  { value: Value::of(VCallback(callback)), }
}

///|
/// Explicit `none`: no numbering.
pub fn Numbering::none() -> Numbering {
  { value: Value::none(), }
}

///|
pub impl ToValue for Numbering with fn to_value(self) {
  self.value
}

///|
/// A supplement (of references to headings, figures, equations): content
/// or a callback from the referenced element.
pub struct Supplement {
  priv value : Value
}

///|
pub fn Supplement::Supplement(content : &IntoContent) -> Supplement {
  { value: Value::content(content), }
}

///|
/// A supplement computed by a callback from the referenced element.
#callsite(autofill(loc, args_loc))
pub fn Supplement::func(
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
  f : (ContentView, Ctx) -> &IntoContent raise,
) -> Supplement {
  let site = Site::new("Supplement::func", loc, args_loc)
  let callback = Callback::new(site, (cx, args) => {
    let content : @library.Content = args.expect("content")
    Value::content(f(ContentView::new(content), cx))
  })
  { value: Value::of(VCallback(callback)), }
}

///|
/// Explicit `none`: no supplement.
pub fn Supplement::none() -> Supplement {
  { value: Value::none(), }
}

///|
/// Explicit `auto`: the element's default supplement.
pub fn Supplement::auto() -> Supplement {
  { value: Value::auto(), }
}

///|
pub impl ToValue for Supplement with fn to_value(self) {
  self.value
}

///|
/// A per-cell value of a table or grid: one value for all cells, one per
/// column, or a callback from the cell's column and row.
#warnings("-unused_type_variable")
pub struct Cells[T] {
  priv value : Value
}

///|
#callsite(autofill(loc, args_loc))
pub fn[T : ToValue] Cells::Cells(
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
  f : (Int, Int) -> T raise,
) -> Cells[T] {
  let site = Site::new("Cells", loc, args_loc)
  let callback = Callback::new(site, (_, args) => {
    let x : Int64 = args.expect("x")
    let y : Int64 = args.expect("y")
    f(x.to_int(), y.to_int()).to_value()
  })
  { value: Value::of(VCallback(callback)), }
}

///|
/// The same value for all cells.
pub fn[T : ToValue] Cells::all(value : T) -> Cells[T] {
  { value: value.to_value(), }
}

///|
/// One value per column (repeated cyclically).
pub fn[T : ToValue] Cells::columns(values : Array[T]) -> Cells[T] {
  { value: Value::array(values.map(v => v.to_value())), }
}

///|
pub impl[T] ToValue for Cells[T] with fn to_value(self) {
  self.value
}

///|
/// The destination of a link.
pub(all) enum LinkTarget {
  /// A URL.
  Url(String)
  /// A label in the document.
  ToLabel(String)
  /// Any destination value (a location, a position dictionary).
  Dest(Value)
}

///|
pub impl ToValue for LinkTarget with fn to_value(self) {
  match self {
    Url(url) => Value::str(url)
    ToLabel(name) => Value::label(name)
    Dest(value) => value
  }
}

///|
/// A data source: a path (resolved against the project root) or bytes.
pub(all) enum Source {
  Path(String)
  Bytes(Bytes)
  /// Several sources, where the field takes more than one (the files of a
  /// bibliography).
  Many(Array[Source])
}

///|
/// Types usable as a data source: `String` (a path), `Bytes` and [Source].
pub(open) trait IntoSource {
  fn into_source(Self) -> Source
}

///|
pub impl IntoSource for Source with fn into_source(self) {
  self
}

///|
pub impl IntoSource for String with fn into_source(self) {
  Path(self)
}

///|
pub impl IntoSource for Bytes with fn into_source(self) {
  Bytes(self)
}

///|
/// Several paths.
pub impl IntoSource for Array[String] with fn into_source(self) {
  Many(self.map(path => Source::Path(path)))
}

///|
pub impl ToValue for Source with fn to_value(self) {
  match self {
    Path(path) => Value::str(path)
    Bytes(bytes) =>
      Value::engine(@library.Value::Bytes(@library.BytesValue::new(bytes)))
    Many(sources) => Value::array(sources.map(source => source.to_value()))
  }
}

///|
/// A font weight: a named weight or a number from 100 to 900.
pub(all) enum FontWeight {
  Thin
  ExtraLight
  Light
  Regular
  Medium
  SemiBold
  Bold
  ExtraBold
  Black
  Weight(Int)
}

///|
pub impl ToValue for FontWeight with fn to_value(self) {
  match self {
    Thin => Value::str("thin")
    ExtraLight => Value::str("extralight")
    Light => Value::str("light")
    Regular => Value::str("regular")
    Medium => Value::str("medium")
    SemiBold => Value::str("semibold")
    Bold => Value::str("bold")
    ExtraBold => Value::str("extrabold")
    Black => Value::str("black")
    Weight(n) => Value::int(n.to_int64())
  }
}

///|
/// The top edge of text (`text.top-edge`, `highlight.top-edge`): a metric
/// of the font or a length above the baseline.
pub(all) enum TopEdge {
  /// `"ascender"`: the font's ascender, which typically exceeds the height
  /// of all glyphs.
  Ascender
  /// `"cap-height"`: the approximate height of uppercase letters.
  CapHeight
  /// `"x-height"`: the approximate height of non-ascending lowercase
  /// letters.
  XHeight
  /// `"baseline"`: the baseline on which the letters rest.
  Baseline
  /// `"bounds"`: the top edge of the glyphs' bounding box.
  Bounds
  /// A length above the baseline.
  Len(Length)
}

///|
pub impl ToValue for TopEdge with fn to_value(self) {
  match self {
    Ascender => Value::str("ascender")
    CapHeight => Value::str("cap-height")
    XHeight => Value::str("x-height")
    Baseline => Value::str("baseline")
    Bounds => Value::str("bounds")
    Len(length) => length.to_value()
  }
}

///|
/// The bottom edge of text (`text.bottom-edge`, `highlight.bottom-edge`): a
/// metric of the font or a length above the baseline (negative: below it).
pub(all) enum BottomEdge {
  /// `"baseline"`: the baseline on which the letters rest.
  Baseline
  /// `"descender"`: the font's descender, which typically exceeds the depth
  /// of all glyphs.
  Descender
  /// `"bounds"`: the bottom edge of the glyphs' bounding box.
  Bounds
  /// A length above the baseline.
  Len(Length)
}

///|
pub impl ToValue for BottomEdge with fn to_value(self) {
  match self {
    Baseline => Value::str("baseline")
    Descender => Value::str("descender")
    Bounds => Value::str("bounds")
    Len(length) => length.to_value()
  }
}

///|
/// A direction (`ltr`, `rtl`, `ttb`, `btt`).
pub(all) enum Dir {
  /// Explicit `auto` (the direction of the text's language).
  Auto
  Ltr
  Rtl
  Ttb
  Btt
}

///|
pub impl ToValue for Dir with fn to_value(self) {
  match self {
    Auto => Value::auto()
    Ltr => Value::global("ltr")
    Rtl => Value::global("rtl")
    Ttb => Value::global("ttb")
    Btt => Value::global("btt")
  }
}
