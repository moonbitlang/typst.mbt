// Tagged PDF (port of `typst-pdf/src/tags/mod.rs`).
//
// TODO: The logical tree (`tags/tree`, `tags/groups`, `tags/context`,
// `tags/resolve`) is not ported yet. Until then, content is exported as if
// tagging were disabled, except that a (childless) structure tree is still
// written when tagging is enabled, and the document language is derived
// like upstream's root group: the document locale, else the language of
// the first text.

///|
/// The invalid group ID.
let group_id_invalid : Int = -1

///|
/// The tagging state.
priv struct Tags {
  /// Whether we are inside a tiling (tags are disabled there).
  mut in_tiling : Bool
  /// The language of the root group.
  mut doc_lang : @library.Locale?
  /// The number of reserved annotation IDs.
  mut next_annotation : Int
}

///|
fn tags_init(
  document : @layout.PagedDocument,
  _options : CompletePdfOptions,
) -> Tags {
  let doc_lang = match document.info().locale {
    Custom(l) => Some(l)
    Auto => None
  }
  { in_tiling: false, doc_lang, next_annotation: 0, }
}

///|
/// Whether tag generation is currently disabled. Either because it has been
/// disabled by the user using the `tagged` flag, or we're inside a tiling.
/// (While the logical tree is not ported, content tagging is always off.)
fn tags_disabled(_gc : GlobalContext) -> Bool {
  true
}

///|
fn tags_handle_start(
  gc : GlobalContext,
  _fc : FrameContext,
  _surface : @export.Surface,
) -> Unit {
  if tags_disabled(gc) {
    return
  }
}

///|
fn tags_handle_end(
  gc : GlobalContext,
  _fc : FrameContext,
  _surface : @export.Surface,
) -> Unit {
  if tags_disabled(gc) {
    return
  }
}

///|
fn tags_group(
  _gc : GlobalContext,
  _fc : FrameContext,
  _surface : @export.Surface,
  _parent : @library.FrameParent?,
  group_fn : () -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  group_fn()
}

///|
fn tags_page(
  _gc : GlobalContext,
  _surface : @export.Surface,
  page_fn : () -> Unit raise @library.SourceError,
) -> Unit raise @library.SourceError {
  page_fn()
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
    let prev = gc.tags.in_tiling
    gc.tags.in_tiling = true
    f()
    gc.tags.in_tiling = prev
    return
  }
  let prev = gc.tags.in_tiling
  gc.tags.in_tiling = true
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
  f()
  surface.end_tagged()
  gc.tags.in_tiling = prev
}

///|
/// Add all annotations that were found in the page frame.
fn tags_add_link_annotations(
  _gc : GlobalContext,
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
      Tagged(_) => page.add_tagged_annotation(annotation) |> ignore
      Artifact => page.add_annotation(annotation)
    }
  }
}

///|
/// Start the marked content of a text item; returns whether it was
/// started.
fn tags_text(
  gc : GlobalContext,
  _fc : FrameContext,
  _surface : @export.Surface,
  text : @library.TextItem,
) -> Bool {
  // Propagate the language of the text to the root group.
  if gc.options.tagged() && !gc.tags.in_tiling && gc.tags.doc_lang is None {
    gc.tags.doc_lang = Some(@library.Locale::new(text.lang, text.region))
  }
  false
}

///|
fn tags_image(
  gc : GlobalContext,
  _fc : FrameContext,
  _surface : @export.Surface,
  _image : @library.Image,
  _size : @library.Axes[@library.Abs],
) -> Bool {
  if tags_disabled(gc) {
    return false
  }
  false
}

///|
fn tags_shape(
  gc : GlobalContext,
  _fc : FrameContext,
  _surface : @export.Surface,
  _shape : @library.Shape,
  _artifact_type : @library.Smart[@export.ArtifactType],
) -> Bool {
  if tags_disabled(gc) {
    return false
  }
  false
}

///|
/// The lowest link ancestor in the logical tree: its group, alt text and
/// span.
fn tags_parent_link(_gc : GlobalContext) -> (Int, String?, @syntax.Span)? {
  None
}

///|
/// Whether there is an artifact ancestor.
fn tags_parent_artifact(_gc : GlobalContext) -> Bool {
  false
}

///|
fn tags_reserve_annotation(gc : GlobalContext) -> Int {
  let id = gc.tags.next_annotation
  gc.tags.next_annotation += 1
  id
}

///|
fn tags_group_push_annotation(
  _gc : GlobalContext,
  _group_id : Int,
  _annot_id : Int,
) -> Unit {
  ()
}

///|
fn tags_resolve(
  gc : GlobalContext,
) -> (@library.Locale?, @export.TagTree) raise @library.SourceError {
  (gc.tags.doc_lang, @export.TagTree::new())
}
