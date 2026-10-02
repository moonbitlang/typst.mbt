// Port of `krilla-svg/src/group.rs`.

///|
fn svg_group_render(
  group : @usvg.Group,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit {
  if !group.filters().is_empty() {
    svg_filter_render(group, surface, process_context) |> ignore
    return
  }
  let mut pop_count = 0
  surface.push_transform(svg_transform_to_export(group.transform()))
  pop_count += 1
  if group.clip_path() is Some(clip_path) {
    pop_count += svg_clip_path_render(
      group, clip_path, surface, process_context,
    )
  }
  if group.mask() is Some(mask) {
    pop_count += svg_mask_render(mask, surface, process_context)
  }
  surface.push_blend_mode(svg_convert_blend_mode(group.blend_mode()))
  surface.push_opacity(group.opacity().get().to_double())
  pop_count += 2

  // There is the `group.should_isolate` method which also returns true if
  // there is a clip path, since strictly speaking, just a clip path
  // also requires layer isolation. However, clip paths are very common
  // and it would be wasteful to generate new isolated XObjects for that
  // (especially since it shouldn't make any visual difference), so we
  // don't include this here.
  let should_isolate = group.isolate() ||
    group.opacity() != @usvg.NormalizedF32::one() ||
    group.mask() is Some(_) ||
    group.blend_mode() != Normal
  if should_isolate {
    surface.push_isolated()
    pop_count += 1
  }
  for child in group.children() {
    svg_group_render_node(child, surface, process_context)
  }
  for _ in 0..<pop_count {
    surface.pop()
  }
}

///|
fn svg_group_render_node(
  node : @usvg.Node,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit {
  match node {
    Group(g) => svg_group_render(g, surface, process_context)
    Path(p) => svg_path_render(p, surface, process_context)
    Image(i) => svg_image_render(i, surface, process_context) |> ignore
    Text(t) => svg_text_render(t, surface, process_context)
  }
}
