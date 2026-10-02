// Port of `usvg` 0.47.0 `src/tree/mod.rs`: the simplified SVG tree.
//
// Upstream shares paint servers, clip paths, masks and filters via `Arc`
// and modifies them in place when it holds the only reference
// (`Arc::get_mut`). These objects are plain (mutable) structs here; each has
// a unique `uid` so that reference counts can be recomputed where upstream
// relies on them (see `paint_server.mbt`).

///|
using @tiny_skia_path {
  type Transform,
  type Rect,
  type NonZeroRect,
  type Size,
  type Path as TinyPath,
}

///|
let next_uid : Ref[Int] = Ref::new(0)

///|
fn gen_uid() -> Int {
  next_uid.val += 1
  next_uid.val
}

///|
/// Must not be clone-able to preserve ID uniqueness.
priv struct NonEmptyString(String)

///|
fn NonEmptyString::new(string : String) -> NonEmptyString? {
  if rust_trim(string).is_empty() {
    return None
  }
  Some(NonEmptyString(string))
}

///|
fn NonEmptyString::get(self : NonEmptyString) -> String {
  self.0
}

///|
pub(all) enum Units {
  UserSpaceOnUse
  ObjectBoundingBox
} derive(Eq)

///|
/// A visibility property.
///
/// `visibility` attribute in the SVG.
pub(all) enum Visibility {
  Visible
  Hidden
  Collapse
} derive(Eq)

///|
pub impl Default for Visibility with fn default() {
  Visible
}

///|
/// A shape rendering method.
///
/// `shape-rendering` attribute in the SVG.
pub(all) enum ShapeRendering {
  OptimizeSpeed
  CrispEdges
  GeometricPrecision
} derive(Eq)

///|
/// Checks if anti-aliasing should be enabled.
pub fn ShapeRendering::use_shape_antialiasing(self : ShapeRendering) -> Bool {
  match self {
    OptimizeSpeed => false
    CrispEdges => false
    GeometricPrecision => true
  }
}

///|
pub impl Default for ShapeRendering with fn default() {
  GeometricPrecision
}

///|
/// A text rendering method.
///
/// `text-rendering` attribute in the SVG.
pub(all) enum TextRendering {
  OptimizeSpeed
  OptimizeLegibility
  GeometricPrecision
} derive(Eq)

///|
pub impl Default for TextRendering with fn default() {
  OptimizeLegibility
}

///|
/// An image rendering method.
///
/// `image-rendering` attribute in the SVG.
pub(all) enum ImageRendering {
  OptimizeQuality
  OptimizeSpeed
  // The following can only appear as presentation attributes.
  Smooth
  HighQuality
  CrispEdges
  Pixelated
} derive(Eq)

///|
pub impl Default for ImageRendering with fn default() {
  OptimizeQuality
}

///|
/// A blending mode property.
///
/// `mix-blend-mode` attribute in the SVG.
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  Saturation
  Color
  Luminosity
} derive(Eq)

///|
pub impl Default for BlendMode with fn default() {
  Normal
}

///|
pub impl Show for BlendMode with fn output(self, logger) {
  logger.write_string(
    match self {
      Normal => "normal"
      Multiply => "multiply"
      Screen => "screen"
      Overlay => "overlay"
      Darken => "darken"
      Lighten => "lighten"
      ColorDodge => "color-dodge"
      ColorBurn => "color-burn"
      HardLight => "hard-light"
      SoftLight => "soft-light"
      Difference => "difference"
      Exclusion => "exclusion"
      Hue => "hue"
      Saturation => "saturation"
      Color => "color"
      Luminosity => "luminosity"
    },
  )
}

///|
/// A spread method.
///
/// `spreadMethod` attribute in the SVG.
pub(all) enum SpreadMethod {
  Pad
  Reflect
  Repeat
} derive(Eq)

///|
pub impl Default for SpreadMethod with fn default() {
  Pad
}

///|
/// A generic gradient.
pub struct BaseGradient {
  priv id : NonEmptyString
  priv mut units : Units // used only during parsing
  priv mut transform : Transform
  priv spread_method : SpreadMethod
  priv stops : Array[Stop]
}

///|
/// A linear gradient.
///
/// `linearGradient` element in SVG.
pub struct LinearGradient {
  priv uid : Int
  priv base : BaseGradient
  priv x1 : Float
  priv y1 : Float
  priv x2 : Float
  priv y2 : Float
}

///|
/// Element's ID.
pub fn LinearGradient::id(self : LinearGradient) -> String {
  self.base.id.get()
}

///|
/// Gradient transform.
pub fn LinearGradient::transform(self : LinearGradient) -> Transform {
  self.base.transform
}

///|
/// Gradient spreading method.
pub fn LinearGradient::spread_method(self : LinearGradient) -> SpreadMethod {
  self.base.spread_method
}

///|
/// A list of `stop` elements.
pub fn LinearGradient::stops(self : LinearGradient) -> Array[Stop] {
  self.base.stops
}

///|
/// `x1` coordinate.
pub fn LinearGradient::x1(self : LinearGradient) -> Float {
  self.x1
}

///|
/// `y1` coordinate.
pub fn LinearGradient::y1(self : LinearGradient) -> Float {
  self.y1
}

///|
/// `x2` coordinate.
pub fn LinearGradient::x2(self : LinearGradient) -> Float {
  self.x2
}

///|
/// `y2` coordinate.
pub fn LinearGradient::y2(self : LinearGradient) -> Float {
  self.y2
}

///|
/// A radial gradient.
///
/// `radialGradient` element in SVG.
pub struct RadialGradient {
  priv uid : Int
  priv base : BaseGradient
  priv cx : Float
  priv cy : Float
  priv r : PositiveF32
  priv fx : Float
  priv fy : Float
  priv fr : PositiveF32
}

///|
/// Element's ID.
pub fn RadialGradient::id(self : RadialGradient) -> String {
  self.base.id.get()
}

///|
/// Gradient transform.
pub fn RadialGradient::transform(self : RadialGradient) -> Transform {
  self.base.transform
}

///|
/// Gradient spreading method.
pub fn RadialGradient::spread_method(self : RadialGradient) -> SpreadMethod {
  self.base.spread_method
}

///|
/// A list of `stop` elements.
pub fn RadialGradient::stops(self : RadialGradient) -> Array[Stop] {
  self.base.stops
}

///|
/// `cx` coordinate.
pub fn RadialGradient::cx(self : RadialGradient) -> Float {
  self.cx
}

///|
/// `cy` coordinate.
pub fn RadialGradient::cy(self : RadialGradient) -> Float {
  self.cy
}

///|
/// Gradient radius.
pub fn RadialGradient::r(self : RadialGradient) -> PositiveF32 {
  self.r
}

///|
/// `fx` coordinate.
pub fn RadialGradient::fx(self : RadialGradient) -> Float {
  self.fx
}

///|
/// `fy` coordinate.
pub fn RadialGradient::fy(self : RadialGradient) -> Float {
  self.fy
}

///|
/// Focal radius.
pub fn RadialGradient::fr(self : RadialGradient) -> PositiveF32 {
  self.fr
}

///|
/// Gradient's stop element.
///
/// `stop` element in SVG.
pub struct Stop {
  priv offset : StopOffset
  priv color : Color
  priv opacity : Opacity
}

///|
/// Gradient stop offset.
pub fn Stop::offset(self : Stop) -> StopOffset {
  self.offset
}

///|
/// Gradient stop color.
pub fn Stop::color(self : Stop) -> Color {
  self.color
}

///|
/// Gradient stop opacity.
pub fn Stop::opacity(self : Stop) -> Opacity {
  self.opacity
}

///|
/// A pattern element.
///
/// `pattern` element in SVG.
pub struct Pattern {
  priv uid : Int
  priv id : NonEmptyString
  priv mut units : Units // used only during parsing
  priv mut content_units : Units // used only during parsing
  priv transform : Transform
  priv mut rect : NonZeroRect
  priv view_box : ViewBox?
  priv mut root : Group
}

///|
/// Element's ID.
pub fn Pattern::id(self : Pattern) -> String {
  self.id.get()
}

///|
/// Pattern transform.
pub fn Pattern::transform(self : Pattern) -> Transform {
  self.transform
}

///|
/// Pattern rectangle.
pub fn Pattern::rect(self : Pattern) -> NonZeroRect {
  self.rect
}

///|
/// Pattern children.
pub fn Pattern::root(self : Pattern) -> Group {
  self.root
}

///|
/// A `stroke-miterlimit` value.
///
/// Just like `f32` but immutable and guarantee to be >=1.0.
pub struct StrokeMiterlimit(Float)

///|
/// Creates a new `StrokeMiterlimit` value.
pub fn StrokeMiterlimit::new(n : Float) -> StrokeMiterlimit {
  let n : Float = if !(n >= 1.0) { 1.0 } else { n }
  StrokeMiterlimit(n)
}

///|
/// Returns an underlying value.
pub fn StrokeMiterlimit::get(self : StrokeMiterlimit) -> Float {
  self.0
}

///|
pub impl Default for StrokeMiterlimit with fn default() {
  StrokeMiterlimit::new(4.0)
}

///|
pub impl Eq for StrokeMiterlimit with fn equal(self, other) {
  approx_eq_ulps(self.0, other.0, 4)
}

///|
/// A line cap.
///
/// `stroke-linecap` attribute in the SVG.
pub(all) enum LineCap {
  Butt
  Round
  Square
} derive(Eq)

///|
pub impl Default for LineCap with fn default() {
  Butt
}

///|
/// A line join.
///
/// `stroke-linejoin` attribute in the SVG.
pub(all) enum LineJoin {
  Miter
  MiterClip
  Round
  Bevel
} derive(Eq)

///|
pub impl Default for LineJoin with fn default() {
  Miter
}

///|
/// A stroke style.
pub struct Stroke {
  priv paint : Paint
  priv dasharray : Array[Float]?
  priv dashoffset : Float
  priv miterlimit : StrokeMiterlimit
  priv opacity : Opacity
  priv width : StrokeWidth
  priv linecap : LineCap
  priv linejoin : LineJoin
  // Whether the current stroke needs to be resolved relative
  // to a context element.
  priv context_element : ContextElement?
}

///|
/// Stroke paint.
pub fn Stroke::paint(self : Stroke) -> Paint {
  self.paint
}

///|
/// Stroke dash array.
pub fn Stroke::dasharray(self : Stroke) -> Array[Float]? {
  self.dasharray
}

///|
/// Stroke dash offset.
pub fn Stroke::dashoffset(self : Stroke) -> Float {
  self.dashoffset
}

///|
/// Stroke miter limit.
pub fn Stroke::miterlimit(self : Stroke) -> StrokeMiterlimit {
  self.miterlimit
}

///|
/// Stroke opacity.
pub fn Stroke::opacity(self : Stroke) -> Opacity {
  self.opacity
}

///|
/// Stroke width.
pub fn Stroke::width(self : Stroke) -> StrokeWidth {
  self.width
}

///|
/// Stroke linecap.
pub fn Stroke::linecap(self : Stroke) -> LineCap {
  self.linecap
}

///|
/// Stroke linejoin.
pub fn Stroke::linejoin(self : Stroke) -> LineJoin {
  self.linejoin
}

///|
/// Converts into a `tiny_skia_path::Stroke` type.
pub fn Stroke::to_tiny_skia(self : Stroke) -> @tiny_skia_path.Stroke {
  let dash = match self.dasharray {
    Some(list) => @tiny_skia_path.StrokeDash::new(list.copy(), self.dashoffset)
    // According to the spec, dash should not be accounted during
    // bbox calculation.
    None => None
  }
  {
    width: self.width.get(),
    miter_limit: self.miterlimit.get(),
    line_cap: match self.linecap {
      Butt => @tiny_skia_path.LineCap::Butt
      Round => @tiny_skia_path.LineCap::Round
      Square => @tiny_skia_path.LineCap::Square
    },
    line_join: match self.linejoin {
      Miter => @tiny_skia_path.LineJoin::Miter
      MiterClip => @tiny_skia_path.LineJoin::MiterClip
      Round => @tiny_skia_path.LineJoin::Round
      Bevel => @tiny_skia_path.LineJoin::Bevel
    },
    dash,
  }
}

///|
/// A fill rule.
///
/// `fill-rule` attribute in the SVG.
pub(all) enum FillRule {
  NonZero
  EvenOdd
} derive(Eq)

///|
pub impl Default for FillRule with fn default() {
  NonZero
}

///|
priv enum ContextElement {
  /// The current context element is a use node. Since we can get
  /// the bounding box of a use node only once we have converted
  /// all elements, we need to fix the transform and units of
  /// the stroke/fill after converting the whole tree.
  UseNode
  /// The current context element is a path node (i.e. only applicable
  /// if we draw the marker of a path). Since we already know the bounding
  /// box of the path when rendering the markers, we can convert them directly,
  /// so we do it while parsing.
  PathNode(Transform, NonZeroRect?)
}

///|
/// A fill style.
pub struct Fill {
  priv paint : Paint
  priv opacity : Opacity
  priv rule : FillRule
  // Whether the current fill needs to be resolved relative
  // to a context element.
  priv context_element : ContextElement?
}

///|
/// Fill paint.
pub fn Fill::paint(self : Fill) -> Paint {
  self.paint
}

///|
/// Fill opacity.
pub fn Fill::opacity(self : Fill) -> Opacity {
  self.opacity
}

///|
/// Fill rule.
pub fn Fill::rule(self : Fill) -> FillRule {
  self.rule
}

///|
pub impl Default for Fill with fn default() {
  {
    paint: Color(Color::black()),
    opacity: Opacity::one(),
    rule: FillRule::default(),
    context_element: None,
  }
}

///|
/// A 8-bit RGB color.
pub(all) struct Color {
  red : Int
  green : Int
  blue : Int
} derive(Eq)

///|
/// Constructs a new `Color` from RGB values.
pub fn Color::new_rgb(red : Int, green : Int, blue : Int) -> Color {
  { red, green, blue, }
}

///|
/// Constructs a new `Color` set to black.
pub fn Color::black() -> Color {
  Color::new_rgb(0, 0, 0)
}

///|
/// Constructs a new `Color` set to white.
pub fn Color::white() -> Color {
  Color::new_rgb(255, 255, 255)
}

///|
/// A paint style.
///
/// `paint` value type in the SVG.
pub(all) enum Paint {
  Color(Color)
  LinearGradient(LinearGradient)
  RadialGradient(RadialGradient)
  Pattern(Pattern)
}

///|
pub impl Eq for Paint with fn equal(self, other) {
  match (self, other) {
    (Color(lc), Color(rc)) => lc == rc
    (LinearGradient(lg1), LinearGradient(lg2)) => physical_equal(lg1, lg2)
    (RadialGradient(rg1), RadialGradient(rg2)) => physical_equal(rg1, rg2)
    (Pattern(p1), Pattern(p2)) => physical_equal(p1, p2)
    _ => false
  }
}

///|
/// A clip-path element.
///
/// `clipPath` element in SVG.
pub struct ClipPath {
  priv uid : Int
  priv id : NonEmptyString
  priv transform : Transform
  priv clip_path : ClipPath?
  priv root : Group
}

///|
fn ClipPath::empty(id : NonEmptyString) -> ClipPath {
  {
    uid: gen_uid(),
    id,
    transform: Transform::default(),
    clip_path: None,
    root: Group::empty(),
  }
}

///|
/// Element's ID.
pub fn ClipPath::id(self : ClipPath) -> String {
  self.id.get()
}

///|
/// Clip path transform.
pub fn ClipPath::transform(self : ClipPath) -> Transform {
  self.transform
}

///|
/// Additional clip path.
pub fn ClipPath::clip_path(self : ClipPath) -> ClipPath? {
  self.clip_path
}

///|
/// Clip path children.
pub fn ClipPath::root(self : ClipPath) -> Group {
  self.root
}

///|
/// A mask type.
pub(all) enum MaskType {
  /// Indicates that the luminance values of the mask should be used.
  Luminance
  /// Indicates that the alpha values of the mask should be used.
  Alpha
} derive(Eq)

///|
pub impl Default for MaskType with fn default() {
  Luminance
}

///|
/// A mask element.
///
/// `mask` element in SVG.
pub struct Mask {
  priv uid : Int
  priv id : NonEmptyString
  priv rect : NonZeroRect
  priv kind : MaskType
  priv mask : Mask?
  priv root : Group
}

///|
/// Element's ID.
pub fn Mask::id(self : Mask) -> String {
  self.id.get()
}

///|
/// Mask rectangle.
pub fn Mask::rect(self : Mask) -> NonZeroRect {
  self.rect
}

///|
/// Mask type.
pub fn Mask::kind(self : Mask) -> MaskType {
  self.kind
}

///|
/// Additional mask.
pub fn Mask::mask(self : Mask) -> Mask? {
  self.mask
}

///|
/// Mask children.
///
/// A mask can have no children, in which case the whole element should be masked out.
pub fn Mask::root(self : Mask) -> Group {
  self.root
}

///|
/// Node's kind.
pub(all) enum Node {
  Group(Group)
  Path(Path)
  Image(Image)
  Text(Text)
}

///|
/// Returns node's ID.
pub fn Node::id(self : Node) -> String {
  match self {
    Group(e) => e.id
    Path(e) => e.id
    Image(e) => e.id
    Text(e) => e.id
  }
}

///|
/// Returns node's absolute transform.
pub fn Node::abs_transform(self : Node) -> Transform {
  match self {
    Group(group) => group.abs_transform
    Path(path) => path.abs_transform
    Image(image) => image.abs_transform
    Text(text) => text.abs_transform
  }
}

///|
/// Returns node's bounding box in object coordinates, if any.
pub fn Node::bounding_box(self : Node) -> Rect {
  match self {
    Group(group) => group.bounding_box
    Path(path) => path.bounding_box
    Image(image) => image.bounding_box()
    Text(text) => text.bounding_box
  }
}

///|
/// Returns node's bounding box in canvas coordinates, if any.
pub fn Node::abs_bounding_box(self : Node) -> Rect {
  match self {
    Group(group) => group.abs_bounding_box
    Path(path) => path.abs_bounding_box
    Image(image) => image.abs_bounding_box()
    Text(text) => text.abs_bounding_box
  }
}

///|
/// Returns node's bounding box, including stroke, in object coordinates, if any.
pub fn Node::stroke_bounding_box(self : Node) -> Rect {
  match self {
    Group(group) => group.stroke_bounding_box
    Path(path) => path.stroke_bounding_box
    // Image cannot be stroked.
    Image(image) => image.bounding_box()
    Text(text) => text.stroke_bounding_box
  }
}

///|
/// Returns node's bounding box, including stroke, in canvas coordinates, if any.
pub fn Node::abs_stroke_bounding_box(self : Node) -> Rect {
  match self {
    Group(group) => group.abs_stroke_bounding_box
    Path(path) => path.abs_stroke_bounding_box
    // Image cannot be stroked.
    Image(image) => image.abs_bounding_box()
    Text(text) => text.abs_stroke_bounding_box
  }
}

///|
/// Element's "layer" bounding box in canvas units, if any.
pub fn Node::abs_layer_bounding_box(self : Node) -> NonZeroRect? {
  match self {
    Group(group) => Some(group.abs_layer_bounding_box)
    // Hor/ver path without stroke can return None. This is expected.
    Path(path) => path.abs_bounding_box.to_non_zero_rect()
    Image(image) => image.abs_bounding_box().to_non_zero_rect()
    Text(text) => text.abs_bounding_box.to_non_zero_rect()
  }
}

///|
/// Calls a closure for each subroot this `Node` has.
pub fn Node::subroots(self : Node, f : (Group) -> Unit) -> Unit {
  match self {
    Group(group) => group.subroots(f)
    Path(path) => path.subroots(f)
    Image(image) => image.subroots(f)
    Text(text) => text.subroots(f)
  }
}

///|
/// A deep copy of the node (upstream's `Clone`: shared objects stay shared).
fn Node::clone(self : Node) -> Node {
  match self {
    Group(g) => Group(g.clone())
    Path(p) => Path(p.clone())
    Image(i) => Image(i.clone())
    Text(t) => Text(t.clone())
  }
}

///|
/// A group container.
///
/// The preprocessor will remove all groups that don't impact rendering.
/// Those that left is just an indicator that a new canvas should be created.
///
/// `g` element in SVG.
pub struct Group {
  priv mut id : String
  priv mut transform : Transform
  priv mut abs_transform : Transform
  priv opacity : Opacity
  priv blend_mode : BlendMode
  priv isolate : Bool
  priv mut clip_path : ClipPath?
  /// Whether the group is a context element (i.e. a use node)
  priv mut is_context_element : Bool
  priv mut mask : Mask?
  priv mut filters : Array[Filter]
  priv mut bounding_box : Rect
  priv mut abs_bounding_box : Rect
  priv mut stroke_bounding_box : Rect
  priv mut abs_stroke_bounding_box : Rect
  priv mut layer_bounding_box : NonZeroRect
  priv mut abs_layer_bounding_box : NonZeroRect
  priv mut children : Array[Node]
}

///|
fn Group::empty() -> Group {
  let dummy = Rect::from_xywh(0.0, 0.0, 0.0, 0.0).unwrap()
  {
    id: "",
    transform: Transform::default(),
    abs_transform: Transform::default(),
    opacity: Opacity::one(),
    blend_mode: BlendMode::Normal,
    isolate: false,
    clip_path: None,
    mask: None,
    filters: [],
    is_context_element: false,
    bounding_box: dummy,
    abs_bounding_box: dummy,
    stroke_bounding_box: dummy,
    abs_stroke_bounding_box: dummy,
    layer_bounding_box: NonZeroRect::from_xywh(0.0, 0.0, 1.0, 1.0).unwrap(),
    abs_layer_bounding_box: NonZeroRect::from_xywh(0.0, 0.0, 1.0, 1.0).unwrap(),
    children: [],
  }
}

///|
/// A deep copy of the group (upstream's `Clone`).
fn Group::clone(self : Group) -> Group {
  {
    ..self,
    filters: self.filters.copy(),
    children: self.children.map(Node::clone),
  }
}

///|
/// Element's ID.
pub fn Group::id(self : Group) -> String {
  self.id
}

///|
/// Element's transform.
pub fn Group::transform(self : Group) -> Transform {
  self.transform
}

///|
/// Element's absolute transform.
pub fn Group::abs_transform(self : Group) -> Transform {
  self.abs_transform
}

///|
/// Group opacity.
pub fn Group::opacity(self : Group) -> Opacity {
  self.opacity
}

///|
/// Group blend mode.
pub fn Group::blend_mode(self : Group) -> BlendMode {
  self.blend_mode
}

///|
/// Group isolation.
pub fn Group::isolate(self : Group) -> Bool {
  self.isolate
}

///|
/// Element's clip path.
pub fn Group::clip_path(self : Group) -> ClipPath? {
  self.clip_path
}

///|
/// Element's mask.
pub fn Group::mask(self : Group) -> Mask? {
  self.mask
}

///|
/// Element's filters.
pub fn Group::filters(self : Group) -> Array[Filter] {
  self.filters
}

///|
/// Element's object bounding box.
pub fn Group::bounding_box(self : Group) -> Rect {
  self.bounding_box
}

///|
/// Element's bounding box in canvas coordinates.
pub fn Group::abs_bounding_box(self : Group) -> Rect {
  self.abs_bounding_box
}

///|
/// Element's object bounding box including stroke.
pub fn Group::stroke_bounding_box(self : Group) -> Rect {
  self.stroke_bounding_box
}

///|
/// Element's bounding box including stroke in user coordinates.
pub fn Group::abs_stroke_bounding_box(self : Group) -> Rect {
  self.abs_stroke_bounding_box
}

///|
/// Element's "layer" bounding box in object units.
pub fn Group::layer_bounding_box(self : Group) -> NonZeroRect {
  self.layer_bounding_box
}

///|
/// Element's "layer" bounding box in canvas units.
pub fn Group::abs_layer_bounding_box(self : Group) -> NonZeroRect {
  self.abs_layer_bounding_box
}

///|
/// Group's children.
pub fn Group::children(self : Group) -> Array[Node] {
  self.children
}

///|
/// Checks if this group should be isolated during rendering.
pub fn Group::should_isolate(self : Group) -> Bool {
  self.isolate ||
  self.opacity != Opacity::one() ||
  self.clip_path is Some(_) ||
  self.mask is Some(_) ||
  !self.filters.is_empty() ||
  self.blend_mode != BlendMode::Normal // TODO: probably not needed?
}

///|
/// Returns `true` if the group has any children.
pub fn Group::has_children(self : Group) -> Bool {
  !self.children.is_empty()
}

///|
/// Calculates a node's filter bounding box.
///
/// Filters with `objectBoundingBox` and missing or zero `bounding_box` would be ignored.
///
/// Note that a filter region can act like a clipping rectangle,
/// therefore this function can produce a bounding box smaller than `bounding_box`.
///
/// Returns `None` when then group has no filters.
pub fn Group::filters_bounding_box(self : Group) -> NonZeroRect? {
  let mut full_region = BBox::default()
  for filter in self.filters {
    full_region = full_region.expand(BBox::from_non_zero_rect(filter.rect))
  }
  full_region.to_non_zero_rect()
}

///|
fn Group::subroots(self : Group, f : (Group) -> Unit) -> Unit {
  if self.clip_path is Some(clip) {
    f(clip.root)
    if clip.clip_path is Some(sub_clip) {
      f(sub_clip.root)
    }
  }
  if self.mask is Some(mask) {
    f(mask.root)
    if mask.mask is Some(sub_mask) {
      f(sub_mask.root)
    }
  }
  for filter in self.filters {
    for primitive in filter.primitives {
      if primitive.kind is Image(image) {
        f(image.root)
      }
    }
  }
}

///|
/// Representation of the [`paint-order`] property.
///
/// `usvg` will handle `markers` automatically,
/// therefore we provide only `fill` and `stroke` variants.
pub(all) enum PaintOrder {
  FillAndStroke
  StrokeAndFill
} derive(Eq)

///|
pub impl Default for PaintOrder with fn default() {
  FillAndStroke
}

///|
/// A path element.
pub struct Path {
  priv mut id : String
  priv visible : Bool
  priv mut fill : Fill?
  priv mut stroke : Stroke?
  priv paint_order : PaintOrder
  priv rendering_mode : ShapeRendering
  priv data : TinyPath
  priv abs_transform : Transform
  priv bounding_box : Rect
  priv abs_bounding_box : Rect
  priv stroke_bounding_box : Rect
  priv abs_stroke_bounding_box : Rect
}

///|
fn Path::clone(self : Path) -> Path {
  { ..self, }
}

///|
fn Path::new_simple(data : TinyPath) -> Path? {
  Path::new(
    "",
    true,
    None,
    None,
    PaintOrder::default(),
    ShapeRendering::default(),
    data,
    Transform::default(),
  )
}

///|
fn Path::new(
  id : String,
  visible : Bool,
  fill : Fill?,
  stroke : Stroke?,
  paint_order : PaintOrder,
  rendering_mode : ShapeRendering,
  data : TinyPath,
  abs_transform : Transform,
) -> Path? {
  guard data.compute_tight_bounds() is Some(bounding_box) else { return None }
  let stroke_bounding_box = Path::calculate_stroke_bbox(stroke, data).unwrap_or(
    bounding_box,
  )
  let (abs_bounding_box, abs_stroke_bounding_box) = if abs_transform.has_skew() {
    // TODO: avoid re-alloc
    guard data.clone().transform(abs_transform) is Some(path2) else {
      return None
    }
    guard path2.compute_tight_bounds() is Some(abs_bounding_box) else {
      return None
    }
    (
      abs_bounding_box,
      Path::calculate_stroke_bbox(stroke, path2).unwrap_or(abs_bounding_box),
    )
  } else {
    // A transform without a skew can be performed just on a bbox.
    guard bounding_box.transform(abs_transform) is Some(r1) else { return None }
    guard stroke_bounding_box.transform(abs_transform) is Some(r2) else {
      return None
    }
    (r1, r2)
  }
  Some({
    id,
    visible,
    fill,
    stroke,
    paint_order,
    rendering_mode,
    data,
    abs_transform,
    bounding_box,
    abs_bounding_box,
    stroke_bounding_box,
    abs_stroke_bounding_box,
  })
}

///|
/// Element's ID.
pub fn Path::id(self : Path) -> String {
  self.id
}

///|
/// Element visibility.
pub fn Path::is_visible(self : Path) -> Bool {
  self.visible
}

///|
/// Fill style.
pub fn Path::fill(self : Path) -> Fill? {
  self.fill
}

///|
/// Stroke style.
pub fn Path::stroke(self : Path) -> Stroke? {
  self.stroke
}

///|
/// Fill and stroke paint order.
pub fn Path::paint_order(self : Path) -> PaintOrder {
  self.paint_order
}

///|
/// Rendering mode.
pub fn Path::rendering_mode(self : Path) -> ShapeRendering {
  self.rendering_mode
}

///|
/// Segments list.
///
/// All segments are in absolute coordinates.
pub fn Path::data(self : Path) -> TinyPath {
  self.data
}

///|
/// Element's absolute transform.
pub fn Path::abs_transform(self : Path) -> Transform {
  self.abs_transform
}

///|
/// Element's object bounding box.
pub fn Path::bounding_box(self : Path) -> Rect {
  self.bounding_box
}

///|
/// Element's bounding box in canvas coordinates.
pub fn Path::abs_bounding_box(self : Path) -> Rect {
  self.abs_bounding_box
}

///|
/// Element's object bounding box including stroke.
pub fn Path::stroke_bounding_box(self : Path) -> Rect {
  self.stroke_bounding_box
}

///|
/// Element's bounding box including stroke in canvas coordinates.
pub fn Path::abs_stroke_bounding_box(self : Path) -> Rect {
  self.abs_stroke_bounding_box
}

///|
fn Path::calculate_stroke_bbox(stroke : Stroke?, path : TinyPath) -> Rect? {
  guard stroke is Some(stroke) else { return None }
  let stroke = stroke.to_tiny_skia()
  stroke.dash = None
  // According to the spec, dash should not be accounted during bbox calculation.

  // TODO: avoid for round and bevel caps

  // Expensive, but there is not much we can do about it.
  if path.stroke(stroke, 1.0) is Some(stroked_path) {
    return stroked_path.compute_tight_bounds()
  }
  None
}

///|
fn Path::subroots(self : Path, f : (Group) -> Unit) -> Unit {
  if self.fill is Some({ paint: Pattern(patt), .. }) {
    f(patt.root)
  }
  if self.stroke is Some({ paint: Pattern(patt), .. }) {
    f(patt.root)
  }
}

///|
/// An embedded image kind.
pub(all) enum ImageKind {
  /// A reference to raw JPEG data. Should be decoded by the caller.
  JPEG(Bytes)
  /// A reference to raw PNG data. Should be decoded by the caller.
  PNG(Bytes)
  /// A reference to raw GIF data. Should be decoded by the caller.
  GIF(Bytes)
  /// A reference to raw WebP data. Should be decoded by the caller.
  WEBP(Bytes)
  /// A preprocessed SVG tree. Can be rendered as is.
  SVG(Tree)
}

///|
fn ImageKind::actual_size(self : ImageKind) -> Size? {
  match self {
    JPEG(data) | PNG(data) | GIF(data) | WEBP(data) =>
      // Upstream warns: Image has an invalid size. Skipped.
      match imagesize_blob_size(data) {
        Some((w, h)) => Size::from_wh(w.to_float(), h.to_float())
        None => None
      }
    SVG(svg) => Some(svg.size)
  }
}

///|
/// A raster image element.
///
/// `image` element in SVG.
pub struct Image {
  priv id : String
  priv visible : Bool
  priv size : Size
  priv rendering_mode : ImageRendering
  priv kind : ImageKind
  priv abs_transform : Transform
  priv abs_bounding_box : NonZeroRect
}

///|
fn Image::clone(self : Image) -> Image {
  { ..self, }
}

///|
/// Element's ID.
pub fn Image::id(self : Image) -> String {
  self.id
}

///|
/// Element visibility.
pub fn Image::is_visible(self : Image) -> Bool {
  self.visible
}

///|
/// The actual image size.
pub fn Image::size(self : Image) -> Size {
  self.size
}

///|
/// Rendering mode.
pub fn Image::rendering_mode(self : Image) -> ImageRendering {
  self.rendering_mode
}

///|
/// Image data.
pub fn Image::kind(self : Image) -> ImageKind {
  self.kind
}

///|
/// Element's absolute transform.
pub fn Image::abs_transform(self : Image) -> Transform {
  self.abs_transform
}

///|
/// Element's object bounding box.
pub fn Image::bounding_box(self : Image) -> Rect {
  self.size.to_rect(0.0, 0.0).unwrap()
}

///|
/// Element's bounding box in canvas coordinates.
pub fn Image::abs_bounding_box(self : Image) -> Rect {
  self.abs_bounding_box.to_rect()
}

///|
fn Image::subroots(self : Image, f : (Group) -> Unit) -> Unit {
  if self.kind is SVG(tree) {
    f(tree.root)
  }
}

///|
/// A nodes tree container.
pub struct Tree {
  priv mut size : Size
  priv root : Group
  priv linear_gradients : Array[LinearGradient]
  priv radial_gradients : Array[RadialGradient]
  priv patterns : Array[Pattern]
  priv clip_paths : Array[ClipPath]
  priv masks : Array[Mask]
  priv filters : Array[Filter]
  priv mut fontdb : FontDatabase
}

///|
/// Image size.
///
/// Size of an image that should be created to fit the SVG.
///
/// `width` and `height` in SVG.
pub fn Tree::size(self : Tree) -> Size {
  self.size
}

///|
/// The root element of the SVG tree.
pub fn Tree::root(self : Tree) -> Group {
  self.root
}

///|
/// Returns a renderable node by ID.
///
/// If an empty ID is provided, than this method will always return `None`.
pub fn Tree::node_by_id(self : Tree, id : String) -> Node? {
  if id.is_empty() {
    return None
  }
  node_by_id(self.root, id)
}

///|
/// Checks if the current tree has any text nodes.
pub fn Tree::has_text_nodes(self : Tree) -> Bool {
  has_text_nodes(self.root)
}

///|
/// Checks if the current tree has any `defs` nodes.
pub fn Tree::has_defs_nodes(self : Tree) -> Bool {
  !self.linear_gradients.is_empty() ||
  !self.radial_gradients.is_empty() ||
  !self.patterns.is_empty() ||
  !self.filters.is_empty() ||
  !self.clip_paths.is_empty() ||
  !self.masks.is_empty()
}

///|
/// Returns a list of all unique [`LinearGradient`]s in the tree.
pub fn Tree::linear_gradients(self : Tree) -> Array[LinearGradient] {
  self.linear_gradients
}

///|
/// Returns a list of all unique [`RadialGradient`]s in the tree.
pub fn Tree::radial_gradients(self : Tree) -> Array[RadialGradient] {
  self.radial_gradients
}

///|
/// Returns a list of all unique [`Pattern`]s in the tree.
pub fn Tree::patterns(self : Tree) -> Array[Pattern] {
  self.patterns
}

///|
/// Returns a list of all unique [`ClipPath`]s in the tree.
pub fn Tree::clip_paths(self : Tree) -> Array[ClipPath] {
  self.clip_paths
}

///|
/// Returns a list of all unique [`Mask`]s in the tree.
pub fn Tree::masks(self : Tree) -> Array[Mask] {
  self.masks
}

///|
/// Returns a list of all unique [`Filter`](filter::Filter)s in the tree.
pub fn Tree::filters(self : Tree) -> Array[Filter] {
  self.filters
}

///|
/// Returns the font database that applies to all text nodes in the tree.
pub fn Tree::fontdb(self : Tree) -> FontDatabase {
  self.fontdb
}

///|
fn Tree::collect_paint_servers(self : Tree) -> Unit {
  loop_over_paint_servers(self.root, paint => {
    match paint {
      Color(_) => ()
      LinearGradient(lg) =>
        if !self.linear_gradients.iter().any(other => physical_equal(lg, other)) {
          self.linear_gradients.push(lg)
        }
      RadialGradient(rg) =>
        if !self.radial_gradients.iter().any(other => physical_equal(rg, other)) {
          self.radial_gradients.push(rg)
        }
      Pattern(patt) =>
        if !self.patterns.iter().any(other => physical_equal(patt, other)) {
          self.patterns.push(patt)
        }
    }
  })
}

///|
fn node_by_id(parent : Group, id : String) -> Node? {
  for child in parent.children {
    if child.id() == id {
      return Some(child)
    }
    if child is Group(g) {
      if node_by_id(g, id) is Some(n) {
        return Some(n)
      }
    }
  }
  None
}

///|
fn has_text_nodes(root : Group) -> Bool {
  for node in root.children {
    if node is Text(_) {
      return true
    }
    let mut has_text = false
    if node is Image(image) {
      if image.kind is SVG(tree) {
        if has_text_nodes(tree.root) {
          has_text = true
        }
      }
    }
    node.subroots(subroot => has_text = has_text || has_text_nodes(subroot))
    if has_text {
      return true
    }
  }
  false
}

///|
fn loop_over_paint_servers(parent : Group, f : (Paint) -> Unit) -> Unit {
  for node in parent.children {
    match node {
      Group(group) => loop_over_paint_servers(group, f)
      Path(path) => {
        if path.fill is Some(fill) {
          f(fill.paint)
        }
        if path.stroke is Some(stroke) {
          f(stroke.paint)
        }
      }
      Image(_) => ()
      // Flattened text would be used instead.
      Text(_) => ()
    }
    node.subroots(subroot => loop_over_paint_servers(subroot, f))
  }
}

///|
fn Group::collect_clip_paths(
  self : Group,
  clip_paths : Array[ClipPath],
) -> Unit {
  for node in self.children {
    if node is Group(g) {
      if g.clip_path is Some(clip) {
        if !clip_paths.iter().any(other => physical_equal(clip, other)) {
          clip_paths.push(clip)
        }
        if clip.clip_path is Some(sub_clip) {
          if !clip_paths.iter().any(other => physical_equal(sub_clip, other)) {
            clip_paths.push(sub_clip)
          }
        }
      }
    }
    node.subroots(subroot => subroot.collect_clip_paths(clip_paths))
    if node is Group(g) {
      g.collect_clip_paths(clip_paths)
    }
  }
}

///|
fn Group::collect_masks(self : Group, masks : Array[Mask]) -> Unit {
  for node in self.children {
    if node is Group(g) {
      if g.mask is Some(mask) {
        if !masks.iter().any(other => physical_equal(mask, other)) {
          masks.push(mask)
        }
        if mask.mask is Some(sub_mask) {
          if !masks.iter().any(other => physical_equal(sub_mask, other)) {
            masks.push(sub_mask)
          }
        }
      }
    }
    node.subroots(subroot => subroot.collect_masks(masks))
    if node is Group(g) {
      g.collect_masks(masks)
    }
  }
}

///|
fn Group::collect_filters(self : Group, filters : Array[Filter]) -> Unit {
  for node in self.children {
    if node is Group(g) {
      for filter in g.filters {
        if !filters.iter().any(other => physical_equal(filter, other)) {
          filters.push(filter)
        }
      }
    }
    node.subroots(subroot => subroot.collect_filters(filters))
    if node is Group(g) {
      g.collect_filters(filters)
    }
  }
}

///|
fn Group::calculate_object_bbox(self : Group) -> NonZeroRect? {
  let mut bbox = BBox::default()
  for child in self.children {
    let mut c_bbox = child.bounding_box()
    if child is Group(group) {
      if c_bbox.transform(group.transform) is Some(r) {
        c_bbox = r
      }
    }
    bbox = bbox.expand(BBox::from_rect(c_bbox))
  }
  bbox.to_non_zero_rect()
}

///|
fn Group::calculate_bounding_boxes(self : Group) -> Unit? {
  let mut bbox = BBox::default()
  let mut abs_bbox = BBox::default()
  let mut stroke_bbox = BBox::default()
  let mut abs_stroke_bbox = BBox::default()
  let mut layer_bbox = BBox::default()
  for child in self.children {
    {
      let mut c_bbox = child.bounding_box()
      if child is Group(group) {
        if c_bbox.transform(group.transform) is Some(r) {
          c_bbox = r
        }
      }
      bbox = bbox.expand(BBox::from_rect(c_bbox))
    }
    abs_bbox = abs_bbox.expand(BBox::from_rect(child.abs_bounding_box()))
    {
      let mut c_bbox = child.stroke_bounding_box()
      if child is Group(group) {
        if c_bbox.transform(group.transform) is Some(r) {
          c_bbox = r
        }
      }
      stroke_bbox = stroke_bbox.expand(BBox::from_rect(c_bbox))
    }
    abs_stroke_bbox = abs_stroke_bbox.expand(
      BBox::from_rect(child.abs_stroke_bounding_box()),
    )
    if child is Group(group) {
      let r = group.layer_bounding_box
      if r.transform(group.transform) is Some(r) {
        layer_bbox = layer_bbox.expand(BBox::from_non_zero_rect(r))
      }
    } else {
      // Not a group - no need to transform.
      layer_bbox = layer_bbox.expand(
        BBox::from_rect(child.stroke_bounding_box()),
      )
    }
  }

  // `bbox` can be None for empty groups, but we still have to
  // calculate `layer_bounding_box after` it.
  if bbox.to_rect() is Some(bbox) {
    self.bounding_box = bbox
    guard abs_bbox.to_rect() is Some(r) else { return None }
    self.abs_bounding_box = r
    guard stroke_bbox.to_rect() is Some(r) else { return None }
    self.stroke_bounding_box = r
    guard abs_stroke_bbox.to_rect() is Some(r) else { return None }
    self.abs_stroke_bounding_box = r
  }

  // Filter bbox has a higher priority than layers bbox.
  if self.filters_bounding_box() is Some(filter_bbox) {
    self.layer_bounding_box = filter_bbox
  } else {
    guard layer_bbox.to_non_zero_rect() is Some(r) else { return None }
    self.layer_bounding_box = r
  }
  guard self.layer_bounding_box.transform(self.abs_transform) is Some(r) else {
    return None
  }
  self.abs_layer_bounding_box = r
  Some(())
}
