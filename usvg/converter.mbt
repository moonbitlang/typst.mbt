// Port of `usvg` 0.47.0 `src/parser/converter.rs`: converts an svgtree
// `Document` into a `Tree`.

///|
// `fe_image_link` is only written, like upstream (usvg 0.47.0
// parser/converter.rs:35; written :388, :494, filter.rs:833).
#warnings("-unused_field")
priv struct State {
  parent_clip_path : SvgNode?
  parent_markers : Array[SvgNode]
  /// Stores the resolved fill and stroke of a use node
  /// or a path element (for markers)
  context_element : (Fill?, Stroke?)?
  fe_image_link : Bool
  /// A viewBox of the parent SVG element.
  view_box : NonZeroRect
  /// A size of the parent `use` element.
  /// Used only during nested `svg` size resolving.
  /// Width and height can be set independently.
  use_size : (Float?, Float?)
  opt : Options
}

///|
priv struct Cache {
  /// This fontdb is initialized from [`Options::fontdb`] and then populated
  /// over the course of conversion.
  fontdb : FontDatabase
  cache_outline : Map[(Int, Int), TinyPath?]
  cache_colr : Map[(Int, Int), Tree?]
  cache_svg : Map[(Int, Int), Node?]
  cache_raster : Map[(Int, Int), BitmapImage?]
  cache_has_opsz : Map[Int, Bool]
  clip_paths : Map[String, ClipPath]
  masks : Map[String, Mask]
  filters : Map[String, Filter]
  paint : Map[String, Paint]

  // used for ID generation
  all_ids : Set[String]
  mut linear_gradient_index : Int
  mut radial_gradient_index : Int
  mut pattern_index : Int
  mut clip_path_index : Int
  mut mask_index : Int
  mut filter_index : Int
  mut image_index : Int
  /// Whether the tree conversion is done (and paint servers are being
  /// updated); see `is_unique` in `paint_server.mbt`.
  mut ref_roots : Array[Group]?
}

///|
fn Cache::new(fontdb : FontDatabase) -> Cache {
  {
    fontdb,
    cache_outline: {},
    cache_colr: {},
    cache_svg: {},
    cache_raster: {},
    cache_has_opsz: {},
    clip_paths: {},
    masks: {},
    filters: {},
    paint: {},
    all_ids: Set([]),
    linear_gradient_index: 0,
    radial_gradient_index: 0,
    pattern_index: 0,
    clip_path_index: 0,
    mask_index: 0,
    filter_index: 0,
    image_index: 0,
    ref_roots: None,
  }
}

///|
fn Cache::gen_linear_gradient_id(self : Cache) -> NonEmptyString {
  while true {
    self.linear_gradient_index += 1
    let new_id = "linearGradient\{self.linear_gradient_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn Cache::gen_radial_gradient_id(self : Cache) -> NonEmptyString {
  while true {
    self.radial_gradient_index += 1
    let new_id = "radialGradient\{self.radial_gradient_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn Cache::gen_pattern_id(self : Cache) -> NonEmptyString {
  while true {
    self.pattern_index += 1
    let new_id = "pattern\{self.pattern_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn Cache::gen_clip_path_id(self : Cache) -> NonEmptyString {
  while true {
    self.clip_path_index += 1
    let new_id = "clipPath\{self.clip_path_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn Cache::gen_mask_id(self : Cache) -> NonEmptyString {
  while true {
    self.mask_index += 1
    let new_id = "mask\{self.mask_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn Cache::gen_filter_id(self : Cache) -> NonEmptyString {
  while true {
    self.filter_index += 1
    let new_id = "filter\{self.filter_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn Cache::gen_image_id(self : Cache) -> NonEmptyString {
  while true {
    self.image_index += 1
    let new_id = "image\{self.image_index}"
    if !self.all_ids.contains(new_id) {
      return NonEmptyString(new_id)
    }
  }
  panic()
}

///|
fn SvgNode::convert_length(
  self : SvgNode,
  aid : AId,
  object_units : Units,
  state : State,
  def : @svgtypes.Length,
) -> Float {
  convert_length(
    self.attribute(aid).unwrap_or(def),
    self,
    aid,
    object_units,
    state,
  )
}

///|
fn SvgNode::convert_user_length(
  self : SvgNode,
  aid : AId,
  state : State,
  def : @svgtypes.Length,
) -> Float {
  self.convert_length(aid, UserSpaceOnUse, state, def)
}

///|
fn SvgNode::parse_viewbox(self : SvgNode) -> NonZeroRect? {
  guard (self.attribute(AId::ViewBox) : @svgtypes.ViewBox?) is Some(vb) else {
    return None
  }
  NonZeroRect::from_xywh(
    Float::from_double(vb.x),
    Float::from_double(vb.y),
    Float::from_double(vb.w),
    Float::from_double(vb.h),
  )
}

///|
fn SvgNode::resolve_length(
  self : SvgNode,
  aid : AId,
  state : State,
  def : Float,
) -> Float {
  if self.ancestors().find_first(n => n.has_attribute(aid)) is Some(n) {
    let length : @svgtypes.Length? = n.attribute(aid)
    if length is Some(length) {
      return convert_user_length(length, n, aid, state)
    }
  }
  def
}

///|
fn SvgNode::resolve_valid_length(
  self : SvgNode,
  aid : AId,
  state : State,
  def : Float,
) -> NonZeroPositiveF32? {
  let n = self.resolve_length(aid, state, def)
  NonZeroPositiveF32::new(n)
}

///|
fn SvgNode::try_convert_length(
  self : SvgNode,
  aid : AId,
  object_units : Units,
  state : State,
) -> Float? {
  guard (self.attribute(aid) : @svgtypes.Length?) is Some(length) else {
    return None
  }
  Some(convert_length(length, self, aid, object_units, state))
}

///|
fn SvgNode::has_valid_transform(self : SvgNode, aid : AId) -> Bool {
  // Do not use Node::attribute::<Transform>, because it will always
  // return a valid transform.

  let attr : String = match self.attribute(aid) {
    Some(attr) => attr
    None => return true
  }
  let ts = @svgtypes.Transform::from_str(attr) catch { _ => return true }
  let ts = Transform::from_row(
    Float::from_double(ts.a),
    Float::from_double(ts.b),
    Float::from_double(ts.c),
    Float::from_double(ts.d),
    Float::from_double(ts.e),
    Float::from_double(ts.f),
  )
  ts.is_valid()
}

///|
fn SvgNode::is_visible_element(self : SvgNode, opt : Options) -> Bool {
  let display : String? = self.attribute(AId::Display)
  display != Some("none") &&
  self.has_valid_transform(AId::Transform) &&
  is_condition_passed(self, opt)
}

///|
fn @svgtypes.Color::split_alpha(self : @svgtypes.Color) -> (Color, Opacity) {
  (
    Color::new_rgb(self.red.to_int(), self.green.to_int(), self.blue.to_int()),
    Opacity::new_u8(self.alpha.to_int()),
  )
}

///|
/// Converts an input `Document` into a `Tree`.
///
/// # Errors
///
/// - If `Document` doesn't have an SVG node - returns an empty tree.
/// - If `Document` doesn't have a valid size - returns `Error::InvalidSize`.
fn convert_doc(svg_doc : Document, opt : Options) -> Tree raise UsvgError {
  let svg = svg_doc.root_element()
  let (size, restore_viewbox) = resolve_svg_size(svg, opt)
  guard size is Some(size) else { raise InvalidSize }
  let view_box : ViewBox = {
    rect: svg.parse_viewbox().unwrap_or(size.to_non_zero_rect(0.0, 0.0)),
    aspect: svg
    .attribute(AId::PreserveAspectRatio)
    .unwrap_or(@svgtypes.AspectRatio::default()),
  }
  let background_color = {
    let s : String? = svg.attribute(AId::BackgroundColor)
    match s {
      Some(s) =>
        try @svgtypes.Paint::from_str(s) catch {
          _ => None
        } noraise {
          Color(c) => Some(c)
          _ => None
        }
      None => None
    }
  }
  let tree : Tree = {
    size,
    root: Group::empty(),
    linear_gradients: [],
    radial_gradients: [],
    patterns: [],
    clip_paths: [],
    masks: [],
    filters: [],
    fontdb: opt.fontdb,
  }
  if !svg.is_visible_element(opt) {
    return tree
  }
  let state : State = {
    parent_clip_path: None,
    context_element: None,
    parent_markers: [],
    fe_image_link: false,
    view_box: view_box.rect,
    use_size: (None, None),
    opt,
  }
  let cache = Cache::new(opt.fontdb.clone())
  for node in svg_doc.descendants() {
    if node.tag_name() is Some(tag) {
      if tag
        is (EId::ClipPath
        | EId::Filter
        | EId::LinearGradient
        | EId::Mask
        | EId::Pattern
        | EId::RadialGradient
        | EId::Image) {
        if !node.element_id().is_empty() {
          cache.all_ids.add(node.element_id())
        }
      }
    }
  }
  let root_ts = view_box.to_transform(tree.size)
  if root_ts.is_identity() && background_color is None {
    convert_children(svg_doc.root(), state, cache, tree.root)
  } else {
    let g = Group::empty()
    if background_color is Some(background_color) {
      if background_path(background_color, view_box.rect.to_rect())
        is Some(path) {
        g.children.push(Path(path))
      }
    }
    g.transform = root_ts
    g.abs_transform = root_ts
    convert_children(svg_doc.root(), state, cache, g)
    g.calculate_bounding_boxes() |> ignore
    tree.root.children.push(Group(g))
  }

  // Clear cache to make sure that all `Arc<T>` objects have a single strong reference.
  cache.clip_paths.clear()
  cache.masks.clear()
  cache.filters.clear()
  cache.paint.clear()
  cache.ref_roots = Some([tree.root])
  update_paint_servers(tree.root, Transform::default(), None, None, cache)
  cache.ref_roots = None
  tree.collect_paint_servers()
  tree.root.collect_clip_paths(tree.clip_paths)
  tree.root.collect_masks(tree.masks)
  tree.root.collect_filters(tree.filters)
  tree.root.calculate_bounding_boxes() |> ignore

  // The fontdb might have been mutated and we want to apply these changes to
  // the tree's fontdb.
  tree.fontdb = cache.fontdb
  if restore_viewbox {
    calculate_svg_bbox(tree)
  }
  tree
}

///|
fn background_path(background_color : @svgtypes.Color, area : Rect) -> Path? {
  let path = @tiny_skia_path.PathBuilder::from_rect(area)
  guard NormalizedF32::new(
      Float::from_int(background_color.alpha.to_int()) / 255.0,
    )
    is Some(opacity) else {
    return None
  }
  let fill : Fill = {
    ..Fill::default(),
    paint: Color(
      Color::new_rgb(
        background_color.red.to_int(),
        background_color.green.to_int(),
        background_color.blue.to_int(),
      ),
    ),
    opacity,
  }
  guard Path::new_simple(path) is Some(path) else { return None }
  path.fill = Some(fill)
  Some(path)
}

///|
fn resolve_svg_size(svg : SvgNode, opt : Options) -> (Size?, Bool) {
  let state : State = {
    parent_clip_path: None,
    context_element: None,
    parent_markers: [],
    fe_image_link: false,
    view_box: NonZeroRect::from_xywh(0.0, 0.0, 100.0, 100.0).unwrap(),
    use_size: (None, None),
    opt,
  }
  let def = @svgtypes.Length::new(100.0, @svgtypes.LengthUnit::Percent)
  let mut width : @svgtypes.Length = svg.attribute(AId::Width).unwrap_or(def)
  let mut height : @svgtypes.Length = svg.attribute(AId::Height).unwrap_or(def)
  let view_box = svg.parse_viewbox()
  let restore_viewbox = if (
      width.unit == @svgtypes.LengthUnit::Percent ||
      height.unit == @svgtypes.LengthUnit::Percent
    ) &&
    view_box is None {
    // Apply the percentages to the fallback size.
    if width.unit == @svgtypes.LengthUnit::Percent {
      width = @svgtypes.Length::new(
        width.number / 100.0 * state.opt.default_size.width().to_double(),
        @svgtypes.LengthUnit::None,
      )
    }
    if height.unit == @svgtypes.LengthUnit::Percent {
      height = @svgtypes.Length::new(
        height.number / 100.0 * state.opt.default_size.height().to_double(),
        @svgtypes.LengthUnit::None,
      )
    }
    true
  } else {
    false
  }
  let size = if view_box is Some(vbox) {
    let state = { ..state, view_box: vbox, }
    let w = if width.unit == @svgtypes.LengthUnit::Percent {
      vbox.width() * (Float::from_double(width.number) / 100.0)
    } else {
      svg.convert_user_length(AId::Width, state, def)
    }
    let h = if height.unit == @svgtypes.LengthUnit::Percent {
      vbox.height() * (Float::from_double(height.number) / 100.0)
    } else {
      svg.convert_user_length(AId::Height, state, def)
    }
    Size::from_wh(w, h)
  } else {
    Size::from_wh(
      svg.convert_user_length(AId::Width, state, def),
      svg.convert_user_length(AId::Height, state, def),
    )
  }
  (size, restore_viewbox)
}

///|
/// Calculates SVG's size and viewBox in case there were not set.
///
/// Simply iterates over all nodes and calculates a bounding box.
fn calculate_svg_bbox(tree : Tree) -> Unit {
  let bbox = tree.root.abs_bounding_box
  if Size::from_wh(bbox.right(), bbox.bottom()) is Some(size) {
    tree.size = size
  }
}

///|
fn convert_children(
  parent_node : SvgNode,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  for node in parent_node.children() {
    convert_element(node, state, cache, parent)
  }
}

///|
fn convert_element(
  node : SvgNode,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  let tag_name = match node.tag_name() {
    Some(v) => v
    None => return
  }
  if !tag_name.is_graphic() && !(tag_name is (EId::G | EId::Switch | EId::Svg)) {
    return
  }
  if !node.is_visible_element(state.opt) {
    return
  }
  if tag_name == EId::Use {
    use_node_convert(node, state, cache, parent)
    return
  }
  if tag_name == EId::Switch {
    switch_convert(node, state, cache, parent) |> ignore
    return
  }
  if convert_group(node, state, false, cache, parent, (cache, g) => {
      convert_element_impl(tag_name, node, state, cache, g)
    })
    is Some(g) {
    parent.children.push(Group(g))
  }
}

///|
fn convert_element_impl(
  tag_name : EId,
  node : SvgNode,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  match tag_name {
    EId::Rect
    | EId::Circle
    | EId::Ellipse
    | EId::Line
    | EId::Polyline
    | EId::Polygon
    | EId::Path =>
      if shapes_convert(node, state) is Some(path) {
        convert_path(node, path, state, cache, parent)
      }
    EId::Image => image_convert(node, state, cache, parent) |> ignore
    EId::Text => text_convert(node, state, cache, parent)
    EId::Svg =>
      if node.parent_element() is Some(_) {
        use_node_convert_svg(node, state, cache, parent)
      } else {
        // Skip root `svg`.
        convert_children(node, state, cache, parent)
      }
    EId::G => convert_children(node, state, cache, parent)
    _ => ()
  }
}

///|
// `clipPath` can have only shape and `text` children.
//
// `line` doesn't impact rendering because stroke is always disabled
// for `clipPath` children.
fn convert_clip_path_elements(
  clip_node : SvgNode,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  for node in clip_node.children() {
    let tag_name = match node.tag_name() {
      Some(v) => v
      None => continue
    }
    if !tag_name.is_graphic() {
      continue
    }
    if !node.is_visible_element(state.opt) {
      continue
    }
    if tag_name == EId::Use {
      use_node_convert(node, state, cache, parent)
      continue
    }
    if convert_group(node, state, false, cache, parent, (cache, g) => {
        convert_clip_path_elements_impl(tag_name, node, state, cache, g)
      })
      is Some(g) {
      parent.children.push(Group(g))
    }
  }
}

///|
fn convert_clip_path_elements_impl(
  tag_name : EId,
  node : SvgNode,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  match tag_name {
    EId::Rect
    | EId::Circle
    | EId::Ellipse
    | EId::Polyline
    | EId::Polygon
    | EId::Path =>
      if shapes_convert(node, state) is Some(path) {
        convert_path(node, path, state, cache, parent)
      }
    EId::Text => text_convert(node, state, cache, parent)
    _ =>
      // Upstream warns: '{}' is no a valid 'clip-path' child.
      ()
  }
}

///|
priv enum Isolation {
  Auto
  Isolate
} derive(Eq)

///|
impl Default for Isolation with fn default() {
  Auto
}

///|
extend Isolation with Default::{default}

///|
impl FromValue for Isolation with fn parse(_, _, value) {
  match value {
    "auto" => Some(Auto)
    "isolate" => Some(Isolate)
    _ => None
  }
}

///|
// TODO: explain
fn convert_group(
  node : SvgNode,
  state : State,
  force : Bool,
  cache : Cache,
  parent : Group,
  collect_children : (Cache, Group) -> Unit,
) -> Group? {
  // A `clipPath` child cannot have an opacity.
  let opacity = if state.parent_clip_path is None {
    node.attribute(AId::Opacity).unwrap_or(Opacity::one())
  } else {
    Opacity::one()
  }
  let transform = node.resolve_transform(AId::Transform, state)
  let blend_mode : BlendMode = node
    .attribute(AId::MixBlendMode)
    .unwrap_or(BlendMode::default())
  let isolation : Isolation = node
    .attribute(AId::Isolation)
    .unwrap_or(Isolation::default())
  let isolate = isolation == Isolate

  // Nodes generated by markers must not have an ID. Otherwise we would have duplicates.
  let is_g_or_use = node.tag_name() is Some(EId::G | EId::Use)
  let id = if is_g_or_use && state.parent_markers.is_empty() {
    node.element_id()
  } else {
    ""
  }
  let abs_transform = parent.abs_transform.pre_concat(transform)
  let g = {
    ..Group::empty(),
    id,
    transform,
    abs_transform,
    opacity,
    blend_mode,
    isolate,
  }
  collect_children(cache, g)

  // We need to know group's bounding box before converting
  // clipPaths, masks and filters.
  let object_bbox = g.calculate_object_bbox()

  // `mask` and `filter` cannot be set on `clipPath` children.
  // But `clip-path` can.

  let mut clip_path = None
  let link : SvgNode? = node.attribute(AId::ClipPath)
  if link is Some(link) {
    clip_path = clippath_convert(link, state, object_bbox, cache)
    if clip_path is None {
      return None
    }
  }
  let mut mask = None
  if state.parent_clip_path is None {
    let link : SvgNode? = node.attribute(AId::Mask)
    if link is Some(link) {
      mask = mask_convert(link, state, object_bbox, cache)
      if mask is None {
        return None
      }
    }
  }
  let filters = {
    let mut filters = []
    if state.parent_clip_path is None {
      let filter_attr : String? = node.attribute(AId::Filter)
      if filter_attr == Some("none") {
        // Do nothing.
      } else if node.has_attribute(AId::Filter) {
        match filter_convert(node, state, object_bbox, cache) {
          Ok(f) => filters = f
          Err(_) =>
            // A filter that not a link or a filter with a link to a non existing element.
            //
            // Unlike `clip-path` and `mask`, when a `filter` link is invalid
            // then the whole element should be ignored.
            //
            // This is kinda an undefined behaviour.
            // In most cases, Chrome, Firefox and rsvg will ignore such elements,
            // but in some cases Chrome allows it. Not sure why.
            // Inkscape (0.92) simply ignores such attributes, rendering element as is.
            // Batik (1.12) crashes.
            //
            // Test file: e-filter-051.svg
            return None
        }
      }
    }
    filters
  }
  let required = approx_ne_ulps(opacity.get(), 1.0, 4) ||
    clip_path is Some(_) ||
    mask is Some(_) ||
    !filters.is_empty() ||
    !transform.is_identity() ||
    blend_mode != BlendMode::Normal ||
    isolate ||
    is_g_or_use ||
    force
  if !required {
    parent.children.append(g.children)
    g.children = []
    return None
  }
  g.clip_path = clip_path
  g.mask = mask
  g.filters = filters

  // Must be called after we set Group::filters
  g.calculate_bounding_boxes() |> ignore
  Some(g)
}

///|
fn convert_path(
  node : SvgNode,
  tiny_skia_path : TinyPath,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit {
  if tiny_skia_path.len() < 2 {
    return
  }
  let has_bbox = tiny_skia_path.bounds().width() > 0.0 &&
    tiny_skia_path.bounds().height() > 0.0
  let mut fill = resolve_fill(node, has_bbox, state, cache)
  let mut stroke = resolve_stroke(node, has_bbox, state, cache)
  let visibility : Visibility = node
    .find_attribute(AId::Visibility)
    .unwrap_or(Visibility::default())
  let mut visible = visibility == Visible
  let rendering_mode : ShapeRendering = node
    .find_attribute(AId::ShapeRendering)
    .unwrap_or(state.opt.shape_rendering)

  // TODO: handle `markers` before `stroke`
  let raw_paint_order : @svgtypes.PaintOrder = node
    .find_attribute(AId::PaintOrder)
    .unwrap_or(@svgtypes.PaintOrder::default())
  let paint_order = svg_paint_order_to_usvg(raw_paint_order)
  let path_transform = parent.abs_transform

  // If a path doesn't have a fill or a stroke then it's invisible.
  // By setting `visibility` to `hidden` we are disabling rendering of this path.
  if fill is None && stroke is None {
    visible = false
  }
  if fill is Some(f) {
    if f.context_element is Some(PathNode(context_transform, context_bbox)) {
      let paint = Ref(f.paint)
      process_paint(
        { get: () => paint.val, set: p => paint.val = p, },
        true,
        context_transform,
        context_bbox.map(r => r.to_rect()),
        path_transform,
        tiny_skia_path.bounds(),
        cache,
      )
      |> ignore
      fill = Some({ ..f, paint: paint.val, context_element: None, })
    }
  }
  if stroke is Some(s) {
    if s.context_element is Some(PathNode(context_transform, context_bbox)) {
      let paint = Ref(s.paint)
      process_paint(
        { get: () => paint.val, set: p => paint.val = p, },
        true,
        context_transform,
        context_bbox.map(r => r.to_rect()),
        path_transform,
        tiny_skia_path.bounds(),
        cache,
      )
      |> ignore
      stroke = Some({ ..s, paint: paint.val, context_element: None, })
    }
  }
  let mut marker = None
  if marker_is_valid(node) && visibility == Visible {
    let marker_group = {
      ..Group::empty(),
      abs_transform: parent.abs_transform,
    }
    let bbox = match tiny_skia_path.compute_tight_bounds() {
      Some(r) => r.to_non_zero_rect()
      None => None
    }
    let fill = fill.map(f => {
      ..f,
      context_element: Some(PathNode(path_transform, bbox)),
    })
    let stroke = stroke.map(s => {
      ..s,
      context_element: Some(PathNode(path_transform, bbox)),
    })
    let marker_state = {
      ..state,
      parent_markers: state.parent_markers.copy(),
      context_element: Some((fill, stroke)),
    }
    marker_convert(node, tiny_skia_path, marker_state, cache, marker_group)
    marker_group.calculate_bounding_boxes() |> ignore
    marker = Some(marker_group)
  }

  // Nodes generated by markers must not have an ID. Otherwise we would have duplicates.
  let id = if state.parent_markers.is_empty() { node.element_id() } else { "" }
  let path = Path::new(
    id, visible, fill, stroke, paint_order, rendering_mode, tiny_skia_path, path_transform,
  )
  let path = match path {
    Some(v) => v
    None => return
  }
  match (raw_paint_order.order, marker) {
    ([Markers, _, _], Some(markers_node)) => {
      parent.children.push(Group(markers_node))
      parent.children.push(Path(path.clone()))
    }
    ([first, Markers, last], Some(markers_node)) => {
      append_single_paint_path(first, path, parent)
      parent.children.push(Group(markers_node))
      append_single_paint_path(last, path, parent)
    }
    ([_, _, Markers], Some(markers_node)) => {
      parent.children.push(Path(path.clone()))
      parent.children.push(Group(markers_node))
    }
    _ => parent.children.push(Path(path.clone()))
  }
}

///|
fn append_single_paint_path(
  paint_order_kind : @svgtypes.PaintOrderKind,
  path : Path,
  parent : Group,
) -> Unit {
  match paint_order_kind {
    Fill =>
      if path.fill is Some(_) {
        let fill_path = { ..path.clone(), stroke: None, id: "", }
        parent.children.push(Path(fill_path))
      }
    Stroke =>
      if path.stroke is Some(_) {
        let stroke_path = { ..path.clone(), fill: None, id: "", }
        parent.children.push(Path(stroke_path))
      }
    _ => ()
  }
}

///|
pub fn svg_paint_order_to_usvg(order : @svgtypes.PaintOrder) -> PaintOrder {
  match (order.order[0], order.order[1]) {
    (Stroke, _) => StrokeAndFill
    (Markers, Stroke) => StrokeAndFill
    _ => FillAndStroke
  }
}

///|
fn SvgNode::resolve_transform(
  self : SvgNode,
  transform_aid : AId,
  state : State,
) -> Transform {
  let mut transform : Transform = self
    .attribute(transform_aid)
    .unwrap_or(Transform::default())
  let transform_origin : @svgtypes.TransformOrigin? = self.attribute(
    AId::TransformOrigin,
  )
  if transform_origin is Some(transform_origin) {
    let dx = convert_length(
      transform_origin.x_offset,
      self,
      AId::Width,
      UserSpaceOnUse,
      state,
    )
    let dy = convert_length(
      transform_origin.y_offset,
      self,
      AId::Height,
      UserSpaceOnUse,
      state,
    )
    transform = Transform::default()
      .pre_translate(dx, dy)
      .pre_concat(transform)
      .pre_translate(-dx, -dy)
  }
  transform
}
