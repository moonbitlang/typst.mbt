// Port of `resvg` 0.47.0 (`src/lib.rs`): an SVG rendering library on top of
// `usvg` and `tiny-skia`.

///|
/// Renders a tree onto the pixmap.
///
/// `transform` will be used as a root transform.
/// Can be used to position SVG inside the `pixmap`.
///
/// The produced content is in the sRGB color space.
pub fn render(
  tree : @usvg.Tree,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  let ctx = { max_bbox: max_bbox_for(pixmap) }
  render_nodes(tree.root(), ctx, transform, pixmap)
}

///|
/// Renders a node onto the pixmap.
///
/// `transform` will be used as a root transform.
/// Can be used to position SVG inside the `pixmap`.
///
/// The expected pixmap size can be retrieved from
/// `usvg::Node::abs_layer_bounding_box()`.
///
/// Returns `None` when `node` has a zero size.
///
/// The produced content is in the sRGB color space.
pub fn render_node(
  node : @usvg.Node,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit? {
  guard node.abs_layer_bounding_box() is Some(bbox) else { return None }
  let ctx = { max_bbox: max_bbox_for(pixmap) }
  let transform = transform.pre_translate(-bbox.x(), -bbox.y())
  render_node_inner(node, ctx, transform, pixmap)
  Some(())
}

///|
/// `IntRect::from_xywh(-(w as i32) * 2, -(h as i32) * 2, w * 5, h * 5)`.
fn max_bbox_for(pixmap : @skia.Pixmap) -> @path.IntRect {
  let w = pixmap.width()
  let h = pixmap.height()
  @path.IntRect::from_xywh(
    -w * 2,
    -h * 2,
    w.reinterpret_as_uint() * 5,
    h.reinterpret_as_uint() * 5,
  ).unwrap()
}
