// Port of `usvg` 0.47.0 `src/parser/clippath.rs`.

///|
fn clippath_convert(
  node : SvgNode,
  state : State,
  object_bbox : NonZeroRect?,
  cache : Cache,
) -> ClipPath? {
  // A `clip-path` attribute must reference a `clipPath` element.
  if node.tag_name() != Some(EId::ClipPath) {
    return None
  }

  // The whole clip path should be ignored when a transform is invalid.
  guard resolve_clip_path_transform(node, state) is Some(transform_) else {
    return None
  }
  let mut transform = transform_
  let units : Units = node
    .attribute(AId::ClipPathUnits)
    .unwrap_or(UserSpaceOnUse)

  // Check if this element was already converted.
  //
  // Only `userSpaceOnUse` clipPaths can be shared,
  // because `objectBoundingBox` one will be converted into user one
  // and will become node-specific.
  let cacheable = units == UserSpaceOnUse
  if cacheable {
    if cache.clip_paths.get(node.element_id()) is Some(clip) {
      return Some(clip)
    }
  }
  if units == ObjectBoundingBox {
    let object_bbox = match object_bbox {
      Some(v) => v
      None =>
        // Upstream warns: Clipping of zero-sized shapes is not allowed.
        return None
    }
    let ts = Transform::from_bbox(object_bbox)
    transform = transform.pre_concat(ts)
  }

  // Resolve linked clip path.
  let mut clip_path = None
  let link : SvgNode? = node.attribute(AId::ClipPath)
  if link is Some(link) {
    clip_path = clippath_convert(link, state, object_bbox, cache)

    // Linked `clipPath` must be valid.
    if clip_path is None {
      return None
    }
  }
  guard NonEmptyString::new(node.element_id()) is Some(id_) else { return None }
  let mut id = id_
  // Generate ID only when we're parsing `objectBoundingBox` clip for the second time.
  if !cacheable && cache.clip_paths.contains(id.get()) {
    id = cache.gen_clip_path_id()
  }
  let id_copy = id.get()
  let clip : ClipPath = {
    uid: gen_uid(),
    id,
    transform,
    clip_path,
    root: Group::empty(),
  }
  let clip_state = { ..state, parent_clip_path: Some(node), }
  convert_clip_path_elements(node, clip_state, cache, clip.root)
  if clip.root.has_children() {
    clip.root.calculate_bounding_boxes() |> ignore
    cache.clip_paths[id_copy] = clip
    Some(clip)
  } else {
    // A clip path without children is invalid.
    None
  }
}

///|
fn resolve_clip_path_transform(node : SvgNode, state : State) -> Transform? {
  // Do not use Node::attribute::<Transform>, because it will always
  // return a valid transform.

  let value : String = match node.attribute(AId::Transform) {
    Some(v) => v
    None => return Some(Transform::default())
  }
  let ts = @svgtypes.Transform::from_str(value) catch {
    _ =>
      // Upstream warns: Failed to parse {} value: '{}'.
      return None
  }
  let ts = Transform::from_row(
    Float::from_double(ts.a),
    Float::from_double(ts.b),
    Float::from_double(ts.c),
    Float::from_double(ts.d),
    Float::from_double(ts.e),
    Float::from_double(ts.f),
  )
  if ts.is_valid() {
    Some(node.resolve_transform(AId::Transform, state))
  } else {
    None
  }
}
