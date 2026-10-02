// Port of `usvg` 0.47.0 `src/parser/mask.rs`.

///|
fn mask_convert(
  node : SvgNode,
  state : State,
  object_bbox : NonZeroRect?,
  cache : Cache,
) -> Mask? {
  // A `mask` attribute must reference a `mask` element.
  if node.tag_name() != Some(EId::Mask) {
    return None
  }
  let units : Units = node
    .attribute(AId::MaskUnits)
    .unwrap_or(ObjectBoundingBox)
  let content_units : Units = node
    .attribute(AId::MaskContentUnits)
    .unwrap_or(UserSpaceOnUse)

  // Check if this element was already converted.
  //
  // Only `userSpaceOnUse` masks can be shared,
  // because `objectBoundingBox` one will be converted into user one
  // and will become node-specific.
  let cacheable = units == UserSpaceOnUse && content_units == UserSpaceOnUse
  if cacheable {
    if cache.masks.get(node.element_id()) is Some(mask) {
      return Some(mask)
    }
  }
  let rect = NonZeroRect::from_xywh(
    node.convert_length(
      AId::X,
      units,
      state,
      @svgtypes.Length::new(-10.0, @svgtypes.LengthUnit::Percent),
    ),
    node.convert_length(
      AId::Y,
      units,
      state,
      @svgtypes.Length::new(-10.0, @svgtypes.LengthUnit::Percent),
    ),
    node.convert_length(
      AId::Width,
      units,
      state,
      @svgtypes.Length::new(120.0, @svgtypes.LengthUnit::Percent),
    ),
    node.convert_length(
      AId::Height,
      units,
      state,
      @svgtypes.Length::new(120.0, @svgtypes.LengthUnit::Percent),
    ),
  )
  // Upstream warns: Mask '{}' has an invalid size. Skipped.
  guard rect is Some(rect_) else { return None }
  let mut rect = rect_
  let mut mask_all = false
  if units == ObjectBoundingBox {
    if object_bbox is Some(bbox) {
      rect = rect.bbox_transform(bbox)
    } else {
      // When mask units are `objectBoundingBox` and bbox is zero-sized - the whole
      // element should be masked.
      // Technically an UB, but this is what Chrome and Firefox do.
      mask_all = true
    }
  }
  guard NonEmptyString::new(node.element_id()) is Some(id_) else { return None }
  let mut id = id_
  // Generate ID only when we're parsing `objectBoundingBox` mask for the second time.
  if !cacheable && cache.masks.contains(id.get()) {
    id = cache.gen_mask_id()
  }
  let id_copy = id.get()
  if mask_all {
    let mask : Mask = {
      uid: gen_uid(),
      id,
      rect,
      kind: Luminance,
      mask: None,
      root: Group::empty(),
    }
    cache.masks[id_copy] = mask
    return Some(mask)
  }

  // Resolve linked mask.
  let mut mask = None
  let link : SvgNode? = node.attribute(AId::Mask)
  if link is Some(link) {
    mask = mask_convert(link, state, object_bbox, cache)

    // Linked `mask` must be valid.
    if mask is None {
      return None
    }
  }
  let mask_type : String? = node.attribute(AId::MaskType)
  let kind = if mask_type == Some("alpha") { Alpha } else { Luminance }
  let mask : Mask = {
    uid: gen_uid(),
    id,
    rect,
    kind,
    mask,
    root: Group::empty(),
  }

  // To emulate content `objectBoundingBox` units we have to put
  // mask children into a group with a transform.
  let mut subroot = None
  if content_units == ObjectBoundingBox {
    let object_bbox = match object_bbox {
      Some(v) => v
      None =>
        // Upstream warns: Masking of zero-sized shapes is not allowed.
        return None
    }
    let g = Group::empty()
    g.transform = Transform::from_bbox(object_bbox)
    // Make sure to set `abs_transform`, because it must propagate to all children.
    g.abs_transform = g.transform
    subroot = Some(g)
  }
  // Prefer `subroot` to `mask.root`.
  {
    let real_root = subroot.unwrap_or(mask.root)
    convert_children(node, state, cache, real_root)

    // A mask without children at this point is invalid.
    // Only masks with zero bbox and `objectBoundingBox` can be empty.
    if !real_root.has_children() {
      return None
    }
  }
  if subroot is Some(subroot) {
    subroot.calculate_bounding_boxes() |> ignore
    mask.root.children.push(Group(subroot))
  }
  mask.root.calculate_bounding_boxes() |> ignore
  cache.masks[id_copy] = mask
  Some(mask)
}
