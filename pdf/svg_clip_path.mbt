// Port of `krilla-svg/src/clip_path.rs`.

///|
/// Render a clip path into a surface.
fn svg_clip_path_render(
  group : @usvg.Group,
  clip_path : @usvg.ClipPath,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Int {
  // Unfortunately, clip paths are a bit tricky to deal with, the reason being
  // that clip paths in SVGs can be much more complex than in PDF. In SVG,
  // clip paths can have transforms, as well as nested clip paths. The objects
  // inside of the clip path can have transforms as well, making it even more
  // difficult to deal with. Because in PDF, once you start a clip path
  // operation you cannot interrupt it, because once you pop the current
  // graphics state, the clip path will be lost since it is part of the
  // current graphics state. However, if we have various transforms on the
  // children, we need to be able to push/pop the graphics state, so that the
  // children's transforms don't affect each other. Initially, because of
  // this, clip paths were only implemented using soft masks, but Safari has a
  // couple of issues with rendering them properly. Not to mention the fact
  // that soft masks are obviously also more expensive. Because of this, we
  // proceed the following way: We first check whether the clip path itself
  // is too "complex" (complex being that it fulfills some attributes that
  // make it impossible to represent them in our current setup using just
  // native PDF clip paths. If it is too complex, we fall back to using soft
  // masks. However, if it is simple enough, we just use the normal clip path
  // operator in PDF. It should be noted that in reality, only very few SVGs
  // seem to have such complex clipping paths (they are not even rendered
  // correctly by all online converters that were tested), so in most
  // real-life scenarios, the simple version should suffice. But in order to
  // conform with the SVG specification, we also handle the case of more
  // complex clipping paths, even if this means that Safari will in some cases
  // not display them correctly.
  let is_simple_clip_path = svg_is_simple_clip_path(clip_path.root())
  let clip_rules = svg_collect_clip_rules(clip_path.root())
  let mut pop_count = 0
  if is_simple_clip_path &&
    (
      clip_rules.iter().all(f => f == NonZero) ||
      // For even odd, there must be at most one shape in the group, because
      // overlapping shapes with evenodd render differently in PDF
      (clip_rules.iter().all(f => f == EvenOdd) && clip_rules.length() == 1)
    ) {
    let clips = svg_create_clip_path(
      clip_path,
      clip_rules.get(0).unwrap_or(NonZero),
    )
    for clip in clips {
      let (clip, rule) = clip
      surface.push_clip_path(clip, rule)
      pop_count += 1
    }
  } else {
    pop_count += svg_clip_path_render_complex(
      group, clip_path, surface, process_context,
    )
  }
  pop_count
}

///|
/// Create a simple clip path.
fn svg_create_clip_path(
  clip_path : @usvg.ClipPath,
  clip_rule : @usvg.FillRule,
) -> Array[(@export.Path, @export.FillRule)] {
  let clips = []
  if clip_path.clip_path() is Some(clip_path) {
    clips.append(svg_create_clip_path(clip_path, clip_rule))
  }

  // Just a dummy operation, so that in case the clip path only has hidden
  // children the clip path will still be applied and everything will be
  // hidden.
  let path_builder = @export.PathBuilder::new()
  path_builder.move_to(0.0, 0.0)
  let base_transform = clip_path.transform()
  svg_extend_segments_from_group(clip_path.root(), base_transform, path_builder)
  clips.push(
    (
      match path_builder.finish() {
        Some(path) => path
        None => {
          let builder = @export.PathBuilder::new()
          builder.move_to(0.0, 0.0)
          builder.line_to(0.0, 0.0)
          builder.finish().unwrap()
        }
      },
      svg_convert_fill_rule(clip_rule),
    ),
  )
  clips
}

///|
/// Collect the paths of a group so that they can be used in the clip path.
fn svg_extend_segments_from_group(
  group : @usvg.Group,
  transform : @tiny_skia_path.Transform,
  path_builder : @export.PathBuilder,
) -> Unit {
  for child in group.children() {
    match child {
      Path(path) =>
        if path.is_visible() {
          for segment in path.data().segments().iter() {
            match segment {
              MoveTo(p) => {
                let p = transform.map_point(p)
                path_builder.move_to(p.x.to_double(), p.y.to_double())
              }
              LineTo(p) => {
                let p = transform.map_point(p)
                path_builder.line_to(p.x.to_double(), p.y.to_double())
              }
              QuadTo(p1, p2) => {
                let points = [p1, p2]
                transform.map_points(points)
                path_builder.quad_to(
                  points[0].x.to_double(),
                  points[0].y.to_double(),
                  points[1].x.to_double(),
                  points[1].y.to_double(),
                )
              }
              CubicTo(p1, p2, p3) => {
                let points = [p1, p2, p3]
                transform.map_points(points)
                path_builder.cubic_to(
                  points[0].x.to_double(),
                  points[0].y.to_double(),
                  points[1].x.to_double(),
                  points[1].y.to_double(),
                  points[2].x.to_double(),
                  points[2].y.to_double(),
                )
              }
              Close => path_builder.close()
            }
          }
        }
      Group(group) => {
        let group_transform = transform.pre_concat(group.transform())
        svg_extend_segments_from_group(group, group_transform, path_builder)
      }
      Text(text) =>
        // We could in theory preserve text in clip paths by using the
        // appropriate rendering mode, but for now we just use the flattened
        // version.
        svg_extend_segments_from_group(
          text.flattened(),
          transform,
          path_builder,
        )
      // Images are not valid in a clip path.
      _ => ()
    }
  }
}

///|
/// Check if the clip path is simple, i.e. it can be translated into a PDF
/// clip path.
fn svg_is_simple_clip_path(group : @usvg.Group) -> Bool {
  group
  .children()
  .iter()
  .all(n => {
    match n {
      // We can only intersect one clipping path with another one, meaning
      // that we can convert nested clip paths if a second clip path is
      // defined on the clip path itself, but not if it is defined on a
      // child.
      Group(group) =>
        group.clip_path() is None && svg_is_simple_clip_path(group)
      _ => true
    }
  })
}

///|
/// Collect the filling rules used in the clip path.
fn svg_collect_clip_rules(group : @usvg.Group) -> Array[@usvg.FillRule] {
  let clip_rules = []
  for n in group.children() {
    match n {
      Path(path) =>
        if path.fill() is Some(fill) {
          clip_rules.push(fill.rule())
        }
      Text(text) => clip_rules.append(svg_collect_clip_rules(text.flattened()))
      Group(group) => clip_rules.append(svg_collect_clip_rules(group))
      _ => ()
    }
  }
  clip_rules
}

///|
/// Render a clip path by using alpha masks.
fn svg_clip_path_render_complex(
  parent : @usvg.Group,
  clip_path : @usvg.ClipPath,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Int {
  let sub_surface = surface.stream_surface()
  let mut pop_count = 0
  if clip_path.clip_path() is Some(clip_path) {
    pop_count += svg_clip_path_render(
      parent, clip_path, sub_surface, process_context,
    )
  }
  sub_surface.push_transform(svg_transform_to_export(clip_path.transform()))
  pop_count += 1
  svg_group_render(clip_path.root(), sub_surface, process_context)
  for _ in 0..<pop_count {
    sub_surface.pop()
  }
  let stream = sub_surface.finish_stream()
  surface.push_mask(stream, false)
  1
}
