// Port of `typst-pdf/src/link.rs`.

///|
priv struct LinkAnnotation {
  kind : LinkAnnotationKind
  alt : String?
  span : @syntax.Span
  rects : Array[@export.Rect]
  target : @export.Target
}

///|
priv enum LinkAnnotationKind {
  /// A link annotation that is tagged within a `Link` structure element.
  Tagged(Int)
  /// A link annotation within an artifact.
  Artifact
}

///|
fn handle_link(
  fc : FrameContext,
  gc : GlobalContext,
  dest : @library.Destination,
  size : @library.Axes[@library.Abs],
) -> Unit raise @library.SourceError {
  let target : @export.Target = match dest {
    Url(u) => Action(Link(u.0))
    Position(p) => {
      guard pos_to_xyz(gc.page_index_converter, p) is Some(dest) else { return }
      Destination(Xyz(dest))
    }
    Location(loc) =>
      match resolve_cross_link(gc, loc) {
        Some(uri) => Action(Link(uri))
        None =>
          match gc.loc_to_names.get(loc) {
            // If a named destination has been registered, it's already
            // guaranteed to not point to an excluded page.
            Some(nd) => Destination(Named(nd))
            None => {
              let pos = gc.document
                .paged_introspector()
                .position(loc)
                .unwrap_or(@library.PagedPosition::origin())
              guard pos_to_xyz(gc.page_index_converter, pos) is Some(dest) else {
                return
              }
              Destination(Xyz(dest))
            }
          }
      }
  }
  let rect = bounding_box(fc, size)
  if tags_disabled(gc) {
    if gc.tags.in_tiling && gc.options.validators().ua is Some(_) {
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "PDF/UA-1 error: PDF artifacts may not contain links",
        ).with_hints([
          "a link was used within a tiling", "references, citations, and footnotes are also considered links in PDF",
        ]),
      ])
    }
    fc.push_link_annotation(group_id_invalid, {
      kind: Artifact,
      alt: None,
      span: @syntax.Span::detached(),
      rects: [rect],
      target,
    })
    return
  }
  let (group_id, link_alt, link_span) = match tags_parent_link(gc) {
    Some(l) => l
    None =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "internal error: expected link ancestor in logical tree (occurred at crates/typst-pdf/src/link.rs:107:10)",
        ).with_hint("please report this as a bug"),
      ])
  }
  if tags_parent_artifact(gc) {
    if gc.options.validators().ua is Some(_) {
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          link_span, "PDF/UA-1 error: PDF artifacts may not contain links",
        ).with_hint(
          "references, citations, and footnotes are also considered links in PDF",
        ),
      ])
    }
    fc.push_link_annotation(group_id, {
      kind: Artifact,
      alt: link_alt,
      span: link_span,
      rects: [rect],
      target,
    })
    return
  }
  // Unfortunately quadpoints still aren't well supported by most PDF
  // readers. So only add multiple quadpoint entries to one annotation when
  // targeting PDF/UA. Otherwise generate multiple annotations.
  let join_annotations = gc.options.validators().ua is Some(_)
  match fc.get_link_annotation(group_id) {
    Some(annotation) if join_annotations => annotation.rects.push(rect)
    _ => {
      let annot_id = tags_reserve_annotation(gc)
      fc.push_link_annotation(group_id, {
        kind: Tagged(annot_id),
        alt: link_alt,
        span: link_span,
        rects: [rect],
        target,
      })
      tags_group_push_annotation(gc, group_id, annot_id)
    }
  }
}

///|
/// Resolve a cross-document link to a relative URI (bundle export).
fn resolve_cross_link(gc : GlobalContext, loc : @library.Location) -> String? {
  guard gc.link_resolver is Some(resolver) else { return None }
  match resolver.resolve(loc) {
    Some(Cross(..) as kind) => (try? kind.into_relative_uri()).to_option()
    _ => None
  }
}

///|
/// Compute the bounding box of the transformed rectangle for this frame.
fn bounding_box(
  fc : FrameContext,
  size : @library.Axes[@library.Abs],
) -> @export.Rect {
  let pos = @library.Point::zero()
  let points = [
    pos + @library.Point::with_y(size.y),
    pos + size.to_point(),
    pos + @library.Point::with_x(size.x),
    pos,
  ]
  let inf = 1.0 / 0.0
  let mut min_x = inf
  let mut min_y = inf
  let mut max_x = -inf
  let mut max_y = -inf
  for point in points {
    let p = to_export_point(point.transform(fc.state().transform))
    min_x = @math.minimum(min_x, p.x)
    min_y = @math.minimum(min_y, p.y)
    max_x = @math.maximum(max_x, p.x)
    max_y = @math.maximum(max_y, p.y)
  }
  { left: min_x, top: min_y, right: max_x, bottom: max_y, }
}

///|
/// Turns a position link into a PDF XYZ destination.
///
/// - Takes into account page index conversion (if only part of the document
///   is exported)
/// - Consistently shifts the link by 10pt because the position of e.g.
///   backlinks to footnotes is always at the baseline and if you link
///   directly to it, the text will not be visible since it is right above.
fn pos_to_xyz(
  pic : PageIndexConverter,
  pos : @library.PagedPosition,
) -> @export.XyzDestination? {
  guard pic.pdf_page_index((pos.page.get() - 1L).to_int()) is Some(page_index) else {
    return None
  }
  let adjusted = @library.Point::new(
    pos.point.x,
    (pos.point.y - @library.Abs::pt(10.0)).max(@library.Abs::zero()),
  )
  Some(@export.XyzDestination::new(page_index, to_export_point(adjusted)))
}
