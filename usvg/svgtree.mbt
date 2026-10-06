// Port of `usvg` 0.47.0 `src/parser/svgtree/mod.rs`: an SVG tree container
// with resolved CSS, `inherit` values and `use` references.

///|
/// An SVG tree container.
///
/// Contains only element and text nodes.
/// Text nodes are present only inside the `text` element.
pub struct Document {
  priv nodes : Array[NodeData]
  priv attrs : Array[Attribute]
  priv mut links : Map[String, Int]
}

///|
/// Returns the root node.
pub fn Document::root(self : Document) -> SvgNode {
  { id: 0, doc: self, }
}

///|
/// Returns the root element.
pub fn Document::root_element(self : Document) -> SvgNode {
  // `unwrap` is safe, because `Document` is guarantee to have at least one element.
  self.root().first_element_child().unwrap()
}

///|
/// Returns an iterator over document's descendant nodes.
pub fn Document::descendants(self : Document) -> Iter[SvgNode] {
  self.root().descendants()
}

///|
/// Returns an element by ID.
pub fn Document::element_by_id(self : Document, id : String) -> SvgNode? {
  guard self.links.get(id) is Some(node_id) else { return None }
  Some(self.get(node_id))
}

///|
fn Document::get(self : Document, id : Int) -> SvgNode {
  { id, doc: self, }
}

///|
priv enum NodeKind {
  Root
  Element(tag_name~ : EId, attributes~ : (Int, Int))
  Text(String)
}

///|
priv struct NodeData {
  parent : Int?
  mut next_sibling : Int?
  mut children : (Int, Int)?
  mut kind : NodeKind
}

///|
/// An attribute.
pub struct Attribute {
  /// Attribute's name.
  name : AId
  /// Attribute's value.
  mut value : String
  /// Attribute's importance
  important : Bool
}

///|
/// An SVG node.
pub struct SvgNode {
  priv id : Int
  priv doc : Document
}

///|
pub impl Eq for SvgNode with fn equal(self, other) {
  self.id == other.id && physical_equal(self.doc, other.doc)
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SvgNode with Eq::{not_equal, equal}

///|
fn SvgNode::d(self : SvgNode) -> NodeData {
  self.doc.nodes[self.id]
}

///|
/// Checks if the current node is an element.
pub fn SvgNode::is_element(self : SvgNode) -> Bool {
  self.d().kind is Element(..)
}

///|
/// Checks if the current node is a text.
pub fn SvgNode::is_text(self : SvgNode) -> Bool {
  self.d().kind is Text(_)
}

///|
/// Returns node's document.
pub fn SvgNode::document(self : SvgNode) -> Document {
  self.doc
}

///|
/// Returns element's tag name, unless the current node is text.
pub fn SvgNode::tag_name(self : SvgNode) -> EId? {
  match self.d().kind {
    Element(tag_name~, ..) => Some(tag_name)
    _ => None
  }
}

///|
/// Returns element's `id` attribute value.
///
/// Returns an empty string otherwise.
pub fn SvgNode::element_id(self : SvgNode) -> String {
  self.attribute(AId::Id).unwrap_or("")
}

///|
fn SvgNode::raw_attribute(self : SvgNode, aid : AId) -> String? {
  for a in self.attributes() {
    if a.name == aid {
      return Some(a.value)
    }
  }
  None
}

///|
/// Returns an attribute value.
pub fn[T : FromValue] SvgNode::attribute(self : SvgNode, aid : AId) -> T? {
  guard self.raw_attribute(aid) is Some(value) else { return None }
  // These AId have an initial value of none
  let is_possible_none = aid
    is (AId::Mask
    | AId::MarkerStart
    | AId::MarkerMid
    | AId::MarkerEnd
    | AId::ClipPath
    | AId::Filter
    | AId::FontSizeAdjust
    | AId::TextDecoration
    | AId::Stroke
    | AId::StrokeDasharray)
  if is_possible_none && value == "none" {
    return None
  }
  // Upstream logs a warning when parsing fails.
  T::parse(self, aid, value)
}

///|
/// Returns an attribute value.
///
/// Same as `SvgNode::attribute`, but doesn't show a warning.
pub fn[T : FromValue] SvgNode::try_attribute(self : SvgNode, aid : AId) -> T? {
  guard self.raw_attribute(aid) is Some(value) else { return None }
  T::parse(self, aid, value)
}

///|
fn SvgNode::node_attribute(self : SvgNode, aid : AId) -> SvgNode? {
  guard (self.attribute(aid) : String?) is Some(value) else { return None }
  let id = if aid == AId::Href {
    Some(@svgtypes.IRI::from_str(value).0) catch {
      _ => None
    }
  } else {
    Some(@svgtypes.FuncIRI::from_str(value).0) catch {
      _ => None
    }
  }
  guard id is Some(id) else { return None }
  self.document().element_by_id(id)
}

///|
/// Checks if an attribute is present.
pub fn SvgNode::has_attribute(self : SvgNode, aid : AId) -> Bool {
  self.attributes().iter().any(a => a.name == aid)
}

///|
/// Returns a list of all element's attributes.
pub fn SvgNode::attributes(self : SvgNode) -> ArrayView[Attribute] {
  match self.d().kind {
    Element(attributes=(start, end), ..) => self.doc.attrs[start:end]
    _ => [][:]
  }
}

///|
fn SvgNode::attribute_id(self : SvgNode, aid : AId) -> Int? {
  match self.d().kind {
    Element(attributes=(start, _), ..) => {
      let attrs = self.attributes()
      for i in 0..<attrs.length() {
        if attrs[i].name == aid {
          return Some(start + i)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Finds a [`Node`] that contains the required attribute.
///
/// For inheritable attributes walks over ancestors until a node with
/// the specified attribute is found.
///
/// For non-inheritable attributes checks only the current node and the parent one.
/// As per SVG spec.
pub fn[T : FromValue] SvgNode::find_attribute(self : SvgNode, aid : AId) -> T? {
  guard self.find_attribute_impl(aid) is Some(n) else { return None }
  n.attribute(aid)
}

///|
fn SvgNode::find_attribute_impl(self : SvgNode, aid : AId) -> SvgNode? {
  if aid.is_inheritable() {
    for n in self.ancestors() {
      if n.has_attribute(aid) {
        return Some(n)
      }
    }
    None
  } else if self.has_attribute(aid) {
    Some(self)
  } else {
    // Non-inheritable attributes can inherit a value only from a direct parent.
    guard self.parent_element() is Some(n) else { return None }
    if n.has_attribute(aid) {
      Some(n)
    } else {
      None
    }
  }
}

///|
/// Returns node's text data.
///
/// For text nodes returns its content. For elements returns the first child node text.
pub fn SvgNode::text(self : SvgNode) -> String {
  match self.d().kind {
    Element(..) =>
      match self.first_child() {
        Some(child) if child.is_text() =>
          match self.doc.nodes[child.id].kind {
            Text(text) => text
            _ => ""
          }
        _ => ""
      }
    Text(text) => text
    _ => ""
  }
}

///|
/// Returns a parent node.
pub fn SvgNode::parent(self : SvgNode) -> SvgNode? {
  self.d().parent.map(id => self.doc.get(id))
}

///|
/// Returns the parent element.
pub fn SvgNode::parent_element(self : SvgNode) -> SvgNode? {
  self.ancestors().drop(1).find_first(n => n.is_element())
}

///|
/// Returns the next sibling.
pub fn SvgNode::next_sibling(self : SvgNode) -> SvgNode? {
  self.d().next_sibling.map(id => self.doc.get(id))
}

///|
/// Returns the first child.
pub fn SvgNode::first_child(self : SvgNode) -> SvgNode? {
  self.d().children.map(c => self.doc.get(c.0))
}

///|
/// Returns the first child element.
pub fn SvgNode::first_element_child(self : SvgNode) -> SvgNode? {
  self.children().find_first(n => n.is_element())
}

///|
/// Returns the last child.
pub fn SvgNode::last_child(self : SvgNode) -> SvgNode? {
  self.d().children.map(c => self.doc.get(c.1))
}

///|
/// Checks if the node has child nodes.
pub fn SvgNode::has_children(self : SvgNode) -> Bool {
  self.d().children is Some(_)
}

///|
/// Returns an iterator over ancestor nodes starting at this node.
pub fn SvgNode::ancestors(self : SvgNode) -> Iter[SvgNode] {
  let mut cur = Some(self)
  Iter::new(() => {
    let node = cur
    cur = match node {
      Some(n) => n.parent()
      None => None
    }
    node
  })
}

///|
/// Returns an iterator over children nodes.
pub fn SvgNode::children(self : SvgNode) -> Iter[SvgNode] {
  let mut front = self.first_child()
  let mut back = self.last_child()
  Iter::new(() => {
    let node = front
    if front == back {
      back = None
      front = None
    } else {
      front = match node {
        Some(n) => n.next_sibling()
        None => None
      }
    }
    node
  })
}

///|
/// Returns an iterator over this node and its descendants.
pub fn SvgNode::descendants(self : SvgNode) -> Iter[SvgNode] {
  let root = self
  // `Traverse` with `Edge::Open`/`Edge::Close`; only open edges are yielded.
  let mut edge : (Bool, SvgNode)? = None // (is_open, node)
  Iter::new(() => {
    while true {
      match edge {
        Some((true, node)) =>
          edge = Some(
            match node.first_child() {
              Some(first_child) => (true, first_child)
              None => (false, node)
            },
          )
        Some((false, node)) =>
          if node == root {
            edge = None
          } else if node.next_sibling() is Some(next_sibling) {
            edge = Some((true, next_sibling))
          } else {
            edge = node.parent().map(p => (false, p))
          }
        None => edge = Some((true, root))
      }
      match edge {
        Some((true, node)) => return Some(node)
        Some((false, _)) => continue
        None => return None
      }
    }
    None
  })
}

///|
/// Returns an iterator over elements linked via `xlink:href`.
pub fn SvgNode::href_iter(self : SvgNode) -> Iter[SvgNode] {
  let doc = self.document()
  let origin = self.id
  let mut curr = self.id
  let mut is_first = true
  let mut is_finished = false
  Iter::new(() => {
    if is_finished {
      return None
    }
    if is_first {
      is_first = false
      return Some(doc.get(curr))
    }
    if doc.get(curr).node_attribute(AId::Href) is Some(link) {
      if link.id == curr || link.id == origin {
        // Upstream warns: Element '#{}' cannot reference itself via 'xlink:href'.
        is_finished = true
        return None
      }
      curr = link.id
      Some(doc.get(curr))
    } else {
      None
    }
  })
}

///|
/// Checks if this is a
/// [graphics element](https://www.w3.org/TR/SVG11/intro.html#TermGraphicsElement).
pub fn EId::is_graphic(self : EId) -> Bool {
  self
  is (EId::Circle
  | EId::Ellipse
  | EId::Image
  | EId::Line
  | EId::Path
  | EId::Polygon
  | EId::Polyline
  | EId::Rect
  | EId::Text
  | EId::Use)
}

///|
/// Checks if this is a
/// [gradient element](https://www.w3.org/TR/SVG11/intro.html#TermGradientElement).
pub fn EId::is_gradient(self : EId) -> Bool {
  self is (EId::LinearGradient | EId::RadialGradient)
}

///|
/// Checks if this is a
/// [paint server element](https://www.w3.org/TR/SVG11/intro.html#TermPaint).
pub fn EId::is_paint_server(self : EId) -> Bool {
  self is (EId::LinearGradient | EId::RadialGradient | EId::Pattern)
}

///|
fn AId::is_presentation(self : AId) -> Bool {
  self
  is (AId::AlignmentBaseline
  | AId::BaselineShift
  | AId::BackgroundColor
  // non-standard SVG attribute
  | AId::ClipPath
  | AId::ClipRule
  | AId::Color
  | AId::ColorInterpolation
  | AId::ColorInterpolationFilters
  | AId::ColorRendering
  | AId::Direction
  | AId::Display
  | AId::DominantBaseline
  | AId::Fill
  | AId::FillOpacity
  | AId::FillRule
  | AId::Filter
  | AId::FloodColor
  | AId::FloodOpacity
  | AId::FontFamily
  | AId::FontKerning
  // technically not presentation
  | AId::FontOpticalSizing
  // technically not presentation
  | AId::FontSize
  | AId::FontSizeAdjust
  | AId::FontStretch
  | AId::FontStyle
  | AId::FontVariant
  | AId::FontWeight
  | AId::FontVariationSettings
  | AId::GlyphOrientationHorizontal
  | AId::GlyphOrientationVertical
  | AId::ImageRendering
  | AId::Isolation
  // technically not presentation
  | AId::LetterSpacing
  | AId::LightingColor
  | AId::MarkerEnd
  | AId::MarkerMid
  | AId::MarkerStart
  | AId::Mask
  | AId::MaskType
  | AId::MixBlendMode
  // technically not presentation
  | AId::Opacity
  | AId::Overflow
  | AId::PaintOrder
  | AId::ShapeRendering
  | AId::StopColor
  | AId::StopOpacity
  | AId::Stroke
  | AId::StrokeDasharray
  | AId::StrokeDashoffset
  | AId::StrokeLinecap
  | AId::StrokeLinejoin
  | AId::StrokeMiterlimit
  | AId::StrokeOpacity
  | AId::StrokeWidth
  | AId::TextAnchor
  | AId::TextDecoration
  | AId::TextOverflow
  | AId::TextRendering
  | AId::Transform
  | AId::TransformOrigin
  | AId::UnicodeBidi
  | AId::VectorEffect
  | AId::Visibility
  | AId::WhiteSpace
  | AId::WordSpacing
  | AId::WritingMode)
}

///|
/// Checks if the current attribute is inheritable.
fn AId::is_inheritable(self : AId) -> Bool {
  if self.is_presentation() {
    !is_non_inheritable(self)
  } else {
    false
  }
}

///|
fn AId::allows_inherit_value(self : AId) -> Bool {
  self
  is (AId::AlignmentBaseline
  | AId::BaselineShift
  | AId::ClipPath
  | AId::ClipRule
  | AId::Color
  | AId::ColorInterpolationFilters
  | AId::Direction
  | AId::Display
  | AId::DominantBaseline
  | AId::Fill
  | AId::FillOpacity
  | AId::FillRule
  | AId::Filter
  | AId::FloodColor
  | AId::FloodOpacity
  | AId::FontFamily
  | AId::FontKerning
  | AId::FontOpticalSizing
  | AId::FontSize
  | AId::FontStretch
  | AId::FontStyle
  | AId::FontVariant
  | AId::FontWeight
  | AId::ImageRendering
  | AId::Kerning
  | AId::LetterSpacing
  | AId::MarkerEnd
  | AId::MarkerMid
  | AId::MarkerStart
  | AId::Mask
  | AId::Opacity
  | AId::Overflow
  | AId::ShapeRendering
  | AId::StopColor
  | AId::StopOpacity
  | AId::Stroke
  | AId::StrokeDasharray
  | AId::StrokeDashoffset
  | AId::StrokeLinecap
  | AId::StrokeLinejoin
  | AId::StrokeMiterlimit
  | AId::StrokeOpacity
  | AId::StrokeWidth
  | AId::TextAnchor
  | AId::TextDecoration
  | AId::TextRendering
  | AId::Visibility
  | AId::WordSpacing
  | AId::WritingMode)
}

///|
fn is_non_inheritable(id : AId) -> Bool {
  id
  is (AId::AlignmentBaseline
  | AId::BaselineShift
  | AId::ClipPath
  | AId::Display
  | AId::DominantBaseline
  | AId::Filter
  | AId::FloodColor
  | AId::FloodOpacity
  | AId::Mask
  | AId::Opacity
  | AId::Overflow
  | AId::LightingColor
  | AId::StopColor
  | AId::StopOpacity
  | AId::TextDecoration
  | AId::Transform
  | AId::TransformOrigin)
}

///|
/// A trait for parsing attribute values.
pub(open) trait FromValue {
  /// Parses an attribute value.
  ///
  /// When `None` is returned, the attribute value will be logged as a parsing failure.
  fn parse(node : SvgNode, aid : AId, value : String) -> Self?
}

///|
pub impl FromValue for String with fn parse(_, _, value) {
  Some(value)
}

///|
pub impl FromValue for Float with fn parse(_, _, value) {
  Some(Float::from_double(@svgtypes.Number::from_str(value).0)) catch {
    _ => None
  }
}

///|
pub impl FromValue for @svgtypes.Length with fn parse(_, _, value) {
  Some(@svgtypes.Length::from_str(value)) catch {
    _ => None
  }
}

///|
// TODO: to svgtypes?
pub impl FromValue for Opacity with fn parse(_, _, value) {
  guard (Some(@svgtypes.Length::from_str(value)) catch { _ => None })
    is Some(length) else {
    return None
  }
  if length.unit == @svgtypes.LengthUnit::Percent {
    Some(Opacity::new_clamped(Float::from_double(length.number) / 100.0))
  } else if length.unit == @svgtypes.LengthUnit::None {
    Some(Opacity::new_clamped(Float::from_double(length.number)))
  } else {
    None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedF32 with FromValue::{parse}

///|
pub impl FromValue for Transform with fn parse(_, _, value) {
  let ts = @svgtypes.Transform::from_str(value) catch { _ => return None }
  let ts = Transform::from_row(
    Float::from_double(ts.a),
    Float::from_double(ts.b),
    Float::from_double(ts.c),
    Float::from_double(ts.d),
    Float::from_double(ts.e),
    Float::from_double(ts.f),
  )
  if ts.is_valid() {
    Some(ts)
  } else {
    Some(Transform::default())
  }
}

///|
pub impl FromValue for @svgtypes.TransformOrigin with fn parse(_, _, value) {
  Some(@svgtypes.TransformOrigin::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for @svgtypes.ViewBox with fn parse(_, _, value) {
  Some(@svgtypes.ViewBox::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for Units with fn parse(_, _, value) {
  match value {
    "userSpaceOnUse" => Some(UserSpaceOnUse)
    "objectBoundingBox" => Some(ObjectBoundingBox)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Units with FromValue::{parse}

///|
pub impl FromValue for @svgtypes.AspectRatio with fn parse(_, _, value) {
  Some(@svgtypes.AspectRatio::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for @svgtypes.PaintOrder with fn parse(_, _, value) {
  // Upstream: `svgtypes::PaintOrder::from_str(value).ok()`, which never
  // fails (`svgtypes/paint_order.mbt`).
  Some(@svgtypes.PaintOrder::from_str(value))
}

///|
pub impl FromValue for @svgtypes.Color with fn parse(_, _, value) {
  Some(@svgtypes.Color::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for @svgtypes.Angle with fn parse(_, _, value) {
  Some(@svgtypes.Angle::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for @svgtypes.EnableBackground with fn parse(_, _, value) {
  Some(@svgtypes.EnableBackground::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for @svgtypes.Paint with fn parse(_, _, value) {
  Some(@svgtypes.Paint::from_str(value)) catch {
    _ => None
  }
}

///|
pub impl FromValue for Array[Float] with fn parse(_, _, value) {
  let list = []
  let p = @svgtypes.NumberListParser::from(value)
  while p.next() is Some(n) {
    match n {
      Ok(n) => list.push(Float::from_double(n))
      Err(_) => return None
    }
  }
  Some(list)
}

///|
pub impl FromValue for Visibility with fn parse(_, _, value) {
  match value {
    "visible" => Some(Visible)
    "hidden" => Some(Hidden)
    "collapse" => Some(Collapse)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Visibility with FromValue::{parse}

///|
pub impl FromValue for SpreadMethod with fn parse(_, _, value) {
  match value {
    "pad" => Some(Pad)
    "reflect" => Some(Reflect)
    "repeat" => Some(Repeat)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SpreadMethod with FromValue::{parse}

///|
pub impl FromValue for ShapeRendering with fn parse(_, _, value) {
  match value {
    "optimizeSpeed" => Some(ShapeRendering::OptimizeSpeed)
    "crispEdges" => Some(ShapeRendering::CrispEdges)
    "auto" | "geometricPrecision" => Some(ShapeRendering::GeometricPrecision)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ShapeRendering with FromValue::{parse}

///|
pub impl FromValue for TextRendering with fn parse(_, _, value) {
  match value {
    "optimizeSpeed" => Some(TextRendering::OptimizeSpeed)
    "auto" | "optimizeLegibility" => Some(TextRendering::OptimizeLegibility)
    "geometricPrecision" => Some(TextRendering::GeometricPrecision)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TextRendering with FromValue::{parse}

///|
pub impl FromValue for ImageRendering with fn parse(_, _, value) {
  match value {
    "auto" | "optimizeQuality" => Some(ImageRendering::OptimizeQuality)
    "optimizeSpeed" => Some(ImageRendering::OptimizeSpeed)
    "smooth" => Some(ImageRendering::Smooth)
    "high-quality" => Some(ImageRendering::HighQuality)
    "crisp-edges" => Some(ImageRendering::CrispEdges)
    "pixelated" => Some(ImageRendering::Pixelated)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ImageRendering with FromValue::{parse}

///|
pub impl FromValue for BlendMode with fn parse(_, _, value) {
  match value {
    "normal" => Some(BlendMode::Normal)
    "multiply" => Some(BlendMode::Multiply)
    "screen" => Some(BlendMode::Screen)
    "overlay" => Some(BlendMode::Overlay)
    "darken" => Some(BlendMode::Darken)
    "lighten" => Some(BlendMode::Lighten)
    "color-dodge" => Some(BlendMode::ColorDodge)
    "color-burn" => Some(BlendMode::ColorBurn)
    "hard-light" => Some(BlendMode::HardLight)
    "soft-light" => Some(BlendMode::SoftLight)
    "difference" => Some(BlendMode::Difference)
    "exclusion" => Some(BlendMode::Exclusion)
    "hue" => Some(BlendMode::Hue)
    "saturation" => Some(BlendMode::Saturation)
    "color" => Some(BlendMode::Color)
    "luminosity" => Some(BlendMode::Luminosity)
    _ => None
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BlendMode with FromValue::{parse}

///|
pub impl FromValue for SvgNode with fn parse(node, aid, value) {
  let id = if aid == AId::Href {
    Some(@svgtypes.IRI::from_str(value).0) catch {
      _ => None
    }
  } else {
    Some(@svgtypes.FuncIRI::from_str(value).0) catch {
      _ => None
    }
  }
  guard id is Some(id) else { return None }
  node.document().element_by_id(id)
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SvgNode with FromValue::{parse}
