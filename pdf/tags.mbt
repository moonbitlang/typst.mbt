// Tagged PDF (port of `typst-pdf/src/tags/mod.rs`).

///|
fn tags_init(
  document : @layout.PagedDocument,
  options : CompletePdfOptions,
) -> Tags raise @library.SourceError {
  let tree = if options.tagged() {
    build_tree(document, options)
  } else {
    Tree::empty(document, options)
  }
  Tags::new(tree)
}

///|
fn tags_handle_start(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
) -> Unit {
  if tags_disabled(gc) {
    return
  }
  step_start_tag(gc, fc, surface)
}

///|
fn tags_handle_end(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
) -> Unit {
  if tags_disabled(gc) {
    return
  }
  step_end_tag(gc, fc, surface)
}

///|
fn tags_group(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
  parent : @library.FrameParent?,
  group_fn : () -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  if tags_disabled(gc) || parent is None {
    return group_fn()
  }
  enter_logical_child(gc, fc, surface)
  group_fn()
  leave_logical_child(gc.tags.tree, surface)
}

///|
fn tags_page(
  gc : GlobalContext,
  surface : @export.Surface,
  page_fn : () -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  if tags_disabled(gc) {
    return page_fn()
  }
  if gc.tags.tree.parent_artifact() is Some(ty) {
    surface.start_tagged(Artifact(ty)) |> ignore
  }
  page_fn()
  if gc.tags.tree.parent_artifact() is Some(_) {
    surface.end_tagged()
  }
}

///|
/// Tags are completely disabled within tilings.
fn tags_tiling(
  gc : GlobalContext,
  surface : @export.Surface,
  tiling_size : @library.Axes[@library.Abs],
  f : () -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  if tags_disabled(gc) {
    return f()
  }
  let prev = gc.tags.in_tiling
  gc.tags.in_tiling = true
  let mark_artifact = gc.tags.tree.parent_artifact() is None
  if mark_artifact {
    let bbox = @export.Rect::from_ltrb(
      0.0,
      0.0,
      f32(tiling_size.x.to_pt()),
      f32(tiling_size.y.to_pt()),
    )
    surface.start_tagged(
      Artifact({
        kind: if gc.options.version() == Pdf17 && bbox is None {
          // PDF 1.7 cannot tolerate empty bounding boxes for background
          // artifacts.
          Other
        } else {
          Background
        },
        bbox,
      }),
    )
    |> ignore
  }
  f()
  if mark_artifact {
    surface.end_tagged()
  }
  gc.tags.in_tiling = prev
}

///|
/// Whether tag generation is currently disabled. Either because it has been
/// disabled by the user using the `tagged` flag, or we're inside a tiling.
fn tags_disabled(gc : GlobalContext) -> Bool {
  !gc.options.tagged() || gc.tags.in_tiling
}

///|
/// Add all annotations that were found in the page frame.
fn tags_add_link_annotations(
  gc : GlobalContext,
  page : @export.Page,
  annotations : Array[LinkAnnotation],
) -> Unit {
  for a in annotations {
    let link_annotation = if a.rects.length() == 1 {
      @export.LinkAnnotation::new(a.rects[0], a.target)
    } else {
      let quads = a.rects.map(r => {
        [
          @export.Point::from_xy(r.left, r.bottom),
          @export.Point::from_xy(r.right, r.bottom),
          @export.Point::from_xy(r.right, r.top),
          @export.Point::from_xy(r.left, r.top),
        ]
      })
      @export.LinkAnnotation::new_with_quad_points(quads, a.target)
    }
    let annotation = @export.Annotation::new_link(
      link_annotation,
      a.alt,
      location=Some(a.span.0),
    )
    match a.kind {
      Tagged(annot_id) => {
        let identifier = page.add_tagged_annotation(annotation)
        gc.tags.init_annotation(annot_id, identifier)
      }
      Artifact => page.add_annotation(annotation)
    }
  }
}

///|
/// Start the marked content of a text item; returns whether it was
/// started (and must thus be ended by the caller).
fn tags_text(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
  text : @library.TextItem,
) -> Bool {
  if tags_disabled(gc) {
    return false
  }
  if gc.tags.tree.parent_artifact() is Some(_) {
    return false
  }
  update_bbox(gc, fc, () => text.bbox())
  let attrs = resolve_text_attrs(gc.tags.tree, gc.options, text)
  let lang = {
    let locale = @library.Locale::new(text.lang, text.region)
    gc.tags.tree.groups.propagate_lang(gc.tags.tree.current(), locale)
  }
  let lang_str = lang.map(l => l.rfc_3066())
  let content = @export.ContentTag::Span({
    ..@export.SpanTag::empty(),
    lang: lang_str,
  })
  let id = surface.start_tagged(content)
  gc.tags.push_text(attrs, id)
  true
}

///|
fn tags_image(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
  image : @library.Image,
  size : @library.Axes[@library.Abs],
) -> Bool {
  if tags_disabled(gc) {
    return false
  }
  if gc.tags.tree.parent_artifact() is Some(_) {
    return false
  }
  update_bbox(gc, fc, () => {
    @library.Rect::from_pos_size(@library.Point::zero(), size)
  })
  let content = @export.ContentTag::Span({
    ..@export.SpanTag::empty(),
    alt_text: image.alt(),
  })
  let id = surface.start_tagged(content)
  gc.tags.push_leaf(id)
  true
}

///|
fn tags_shape(
  gc : GlobalContext,
  fc : FrameContext,
  surface : @export.Surface,
  shape : @library.Shape,
  artifact_type : @library.Smart[@export.ArtifactType],
) -> Bool {
  if tags_disabled(gc) {
    return false
  }
  if gc.tags.tree.parent_artifact() is Some(_) {
    return false
  }
  update_bbox(gc, fc, () => @svg.shape_bbox(shape, true))
  if artifact_type is Auto && gc.tags.tree.parent_alt() is Some(parent) {
    // If we're within a tag that has an alternative description, use marked
    // content sequences for shapes, so that they show up in the tag tree.
    // This tag will most likely be a figure or an equation, where marked
    // content sequences will associate it with portions of a page and might
    // improve how AT handles the item.
    // This *shouldn't* be an issue for any tag structure, because during
    // resolution the structure of tags with an alternative description is
    // flattened.
    //
    // A limitation of PDF/UA-1 is that graphic objects other than text
    // *must* be grouped within a `Figure` tag, so if the illustrative
    // element is anything but a `Figure`, we still mark it as an artifact.
    if gc.options.validators().ua == Some(UA1) &&
      !gc.tags.tree.groups.get(parent).kind.is_figure() {
      surface.start_tagged(Artifact({ kind: Other, bbox: None, })) |> ignore
    } else {
      let id = surface.start_tagged(Other)
      gc.tags.push_leaf(id)
    }
  } else {
    // PDF 1.7 is the only PDF version that requires bounding boxes for
    // background artifacts. Because this has no noticeable effect on
    // how AT handles the artifacts and because we don't have a good way
    // to compute bounding boxes for artifacts at this point in the
    // conversion process, we just mark them as `Other` artifacts.
    let ty : @export.ArtifactType = match artifact_type {
      Custom(ty) =>
        if gc.options.version() == Pdf17 && ty == Background {
          Other
        } else {
          ty
        }
      Auto => Layout
    }
    surface.start_tagged(Artifact({ kind: ty, bbox: None, })) |> ignore
  }
  true
}

///|
fn update_bbox(
  gc : GlobalContext,
  fc : FrameContext,
  compute_bbox : () -> @library.Rect,
) -> Unit {
  if gc.tags.tree.parent_bbox() is Some(bbox) &&
    gc.options.validators().ua is Some(_) {
    bbox.expand_frame(fc, compute_bbox)
  }
}

///|
/// The lowest link ancestor in the logical tree: its group, alt text and
/// span.
fn tags_parent_link(gc : GlobalContext) -> (Int, String?, @syntax.Span)? {
  match gc.tags.tree.parent_link() {
    Some((id, link)) => Some((id, link.alt(), link.pack().span()))
    None => None
  }
}

///|
/// Whether there is an artifact ancestor.
fn tags_parent_artifact(gc : GlobalContext) -> Bool {
  gc.tags.tree.parent_artifact() is Some(_)
}

///|
fn tags_reserve_annotation(gc : GlobalContext) -> Int {
  gc.tags.reserve_annotation()
}

///|
fn tags_group_push_annotation(
  gc : GlobalContext,
  group_id : Int,
  annot_id : Int,
) -> Unit {
  gc.tags.tree.groups.get(group_id).push_annotation(annot_id)
}
