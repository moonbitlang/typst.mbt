// Port of `hayro-interpret/src/interpret/mod.rs`.

///|
/// A callback function for resolving font queries.
///
/// The result is the raw data and the index in case the font is a TTC,
/// otherwise it should be 0.
pub type FontResolverFn = (FontQuery) -> (Bytes, Int)?

///|
/// A callback function for resolving cmap names to their files.
pub type CMapResolverFn = (@cmap.CMapName) -> Bytes?

///|
/// A callback function for resolving warnings during interpretation.
pub type WarningSinkFn = (InterpreterWarning) -> Unit

///|
/// Settings that should be applied during the interpretation process.
pub(all) struct InterpreterSettings {
  /// Nearly every PDF contains text. In most cases, PDF files embed the fonts
  /// they use, and hayro can therefore read the font files and do all the
  /// processing needed. However, fonts don't _have_ to be embedded, and the
  /// PDF specification requires a list of 14 fonts that should always be
  /// available to a PDF processor. In these cases this callback will be
  /// called, which expects the data of an appropriate font to be returned,
  /// if available (any valid TTF/OTF font or a CFF font program).
  font_resolver : FontResolverFn
  /// A callback for resolving cmaps that aren't embedded.
  cmap_resolver : CMapResolverFn
  /// In certain cases, `hayro` will emit a warning in case an issue was
  /// encountered while interpreting the PDF file.
  warning_sink : WarningSinkFn
  /// Whether annotations should be rendered as well.
  ///
  /// Note that this feature is currently not fully implemented yet, so some
  /// annotations might be missing.
  render_annotations : Bool
}

///|
/// Warnings that can occur while interpreting a PDF file.
pub(all) enum InterpreterWarning {
  /// An unsupported font kind was encountered.
  ///
  /// Currently, only CID fonts with non-identity encoding are unsupported.
  UnsupportedFont
  /// An image failed to decode.
  ImageDecodeFailure
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InterpreterWarning with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InterpreterWarning with @debug.Debug::{to_repr}

///|
/// interpret the contents of the page and render them into the device.
pub fn interpret_page(
  page : @hayro_syntax.Page,
  context : Context,
  device : &Device,
) -> Unit {
  let resources = page.resources()
  interpret(page.typed_operations(), resources, context, device)
  if context.settings.render_annotations &&
    (page.raw().get("Annots") : @hayro_syntax.PdfArray?) is Some(annot_arr) {
    for annot in (annot_arr.iter() : Iter[@hayro_syntax.Dict]) {
      let flags = (annot.get("F") : UInt?).unwrap_or(0)

      // Annotation should be hidden.
      if (flags & 2) != 0 {
        continue
      }
      guard appearance_stream(annot) is Some(o) &&
        FormXObject::new(o) is Some(apx) else {
        continue
      }
      guard (annot.get("Rect") : @hayro_syntax.Rect?) is Some(rect) else {
        continue
      }
      let annot_rect = rect_to_kurbo(rect)
      // 12.5.5. Appearance streams
      // "The algorithm outlined in this subclause shall be used
      // to map from the coordinate system of the appearance XObject."

      // 1) The appearance’s bounding box (specified by its BBox entry)
      // shall be transformed, using Matrix, to produce a
      // quadrilateral with arbitrary orientation. The transformed
      // appearance box is the smallest upright rectangle that
      // encompasses this quadrilateral.
      let transformed_rect = @kurbo.Rect::new(
          apx.bbox[0].to_double(),
          apx.bbox[1].to_double(),
          apx.bbox[2].to_double(),
          apx.bbox[3].to_double(),
        )
        .to_path(0.1)
        .transform(apx.matrix)
        .bounding_box()

      // 2) A matrix A shall be computed that scales and translates
      // the transformed appearance box to align with the edges
      // of the annotation’s rectangle (specified by the Rect entry).
      // A maps the lower-left corner (the corner with the smallest
      // x and y coordinates) and the upper-right corner (the
      // corner with the greatest x and y coordinates) of the
      // transformed appearance box to the corresponding corners
      // of the annotation’s rectangle.
      let affine = @kurbo.Affine::new([
        annot_rect.width() / transformed_rect.width(),
        0.0,
        0.0,
        annot_rect.height() / transformed_rect.height(),
        annot_rect.x0 - transformed_rect.x0,
        annot_rect.y0 - transformed_rect.y0,
      ])

      // 3) Matrix shall be concatenated with A to form a matrix
      // AA that maps from the appearance’s coordinate system to
      // the annotation’s rectangle in default user space.
      context.save_state()
      context.pre_concat_affine(affine)
      context.push_root_transform()
      draw_form_xobject(resources, apx, context, device)
      context.pop_root_transform()
      context.restore_state(device)
    }
  }
}

///|
fn appearance_stream(annot : @hayro_syntax.Dict) -> @hayro_syntax.Stream? {
  guard (annot.get("AP") : @hayro_syntax.Dict?) is Some(ap) else { return None }
  match (ap.get("N") : @hayro_syntax.Object?) {
    Some(Stream(stream)) => Some(stream)
    Some(Dict(states)) => {
      let by_state = match (annot.get("AS") : @hayro_syntax.Name?) {
        Some(state) => (states.get(state.as_str()) : @hayro_syntax.Stream?)
        None => None
      }
      match by_state {
        Some(s) => Some(s)
        None => states.get("Off")
      }
    }
    _ => None
  }
}

///|
/// Interpret the instructions from `ops` and render them into the device.
pub fn interpret(
  ops : @hayro_syntax.TypedIter,
  resources : @hayro_syntax.Resources,
  context : Context,
  device : &Device,
) -> Unit {
  let num_states = context.num_states()
  let font_dict_cache : Map[String, @hayro_syntax.Dict] = Map([])
  context.save_state()
  while ops.next() is Some(op) {
    match op {
      SaveState => context.save_state()
      StrokeColorDeviceRgb(r, g, b) => {
        let gs = context.get().graphics_state
        gs.stroke_cs = ColorSpace::device_rgb()
        gs.stroke_color = [r.as_f32(), g.as_f32(), b.as_f32()]
        gs.stroke_pattern = None
      }
      StrokeColorDeviceGray(g) => {
        let gs = context.get().graphics_state
        gs.stroke_cs = ColorSpace::device_gray()
        gs.stroke_color = [g.as_f32()]
        gs.stroke_pattern = None
      }
      StrokeColorCmyk(c, m, y, k) => {
        let gs = context.get().graphics_state
        gs.stroke_cs = ColorSpace::device_cmyk()
        gs.stroke_color = [c.as_f32(), m.as_f32(), y.as_f32(), k.as_f32()]
        gs.stroke_pattern = None
      }
      LineWidth(w) => {
        let gs = context.get().graphics_state
        gs.stroke_props = { ..gs.stroke_props, line_width: w.as_f32(), }
      }
      LineCap(c) => {
        let gs = context.get().graphics_state
        gs.stroke_props = { ..gs.stroke_props, line_cap: convert_line_cap(c), }
      }
      LineJoin(j) => {
        let gs = context.get().graphics_state
        gs.stroke_props = {
          ..gs.stroke_props,
          line_join: convert_line_join(j),
        }
      }
      MiterLimit(l) => {
        let gs = context.get().graphics_state
        gs.stroke_props = { ..gs.stroke_props, miter_limit: l.as_f32(), }
      }
      Transform(a, b, c, d, e, f) =>
        context.pre_concat_affine(convert_transform(a, b, c, d, e, f))
      RectPath(x, y, w, h) => {
        let rect = @kurbo.Rect::new(
          x.as_f64(),
          y.as_f64(),
          x.as_f64() + w.as_f64(),
          y.as_f64() + h.as_f64(),
        ).to_path(0.1)
        context.path.extend_path(rect)
      }
      MoveTo(x, y) => {
        let p = @kurbo.Point::new(x.as_f64(), y.as_f64())
        context.last_point = p
        context.sub_path_start = p
        context.path.move_to(p)
      }
      FillPathEvenOdd => fill_path(context, device, EvenOdd)
      FillPathNonZero => fill_path(context, device, NonZero)
      FillPathNonZeroCompatibility => fill_path(context, device, NonZero)
      FillAndStrokeEvenOdd => fill_stroke_path(context, device, EvenOdd)
      FillAndStrokeNonZero => fill_stroke_path(context, device, NonZero)
      CloseAndStrokePath => {
        close_path(context)
        stroke_path(context, device)
      }
      CloseFillAndStrokeEvenOdd => {
        close_path(context)
        fill_stroke_path(context, device, EvenOdd)
      }
      CloseFillAndStrokeNonZero => {
        close_path(context)
        fill_stroke_path(context, device, NonZero)
      }
      NonStrokeColorDeviceGray(g) => {
        let gs = context.get().graphics_state
        gs.none_stroke_cs = ColorSpace::device_gray()
        gs.non_stroke_color = [g.as_f32()]
        gs.non_stroke_pattern = None
      }
      NonStrokeColorDeviceRgb(r, g, b) => {
        let gs = context.get().graphics_state
        gs.none_stroke_cs = ColorSpace::device_rgb()
        gs.non_stroke_color = [r.as_f32(), g.as_f32(), b.as_f32()]
        gs.non_stroke_pattern = None
      }
      NonStrokeColorCmyk(c, m, y, k) => {
        let gs = context.get().graphics_state
        gs.none_stroke_cs = ColorSpace::device_cmyk()
        gs.non_stroke_color = [c.as_f32(), m.as_f32(), y.as_f32(), k.as_f32()]
        gs.non_stroke_pattern = None
      }
      LineTo(x, y) =>
        if !context.path.elements().is_empty() {
          let last_point = context.last_point
          let mut p = @kurbo.Point::new(x.as_f64(), y.as_f64())
          context.last_point = p
          if last_point == p {
            // Add a small delta so that zero width lines can still have a round stroke.
            p = @kurbo.Point::new(p.x + 0.0001, p.y)
          }
          context.path.line_to(p)
        }
      CubicTo(x1, y1, x2, y2, x3, y3) =>
        if !context.path.elements().is_empty() {
          let p1 = @kurbo.Point::new(x1.as_f64(), y1.as_f64())
          let p2 = @kurbo.Point::new(x2.as_f64(), y2.as_f64())
          let p3 = @kurbo.Point::new(x3.as_f64(), y3.as_f64())
          context.last_point = p3
          context.path.curve_to(p1, p2, p3)
        }
      CubicStartTo(x2, y2, x3, y3) =>
        if !context.path.elements().is_empty() {
          let p1 = context.last_point
          let p2 = @kurbo.Point::new(x2.as_f64(), y2.as_f64())
          let p3 = @kurbo.Point::new(x3.as_f64(), y3.as_f64())
          context.last_point = p3
          context.path.curve_to(p1, p2, p3)
        }
      CubicEndTo(x2, y2, x3, y3) =>
        if !context.path.elements().is_empty() {
          let p2 = @kurbo.Point::new(x2.as_f64(), y2.as_f64())
          let p3 = @kurbo.Point::new(x3.as_f64(), y3.as_f64())
          context.last_point = p3
          context.path.curve_to(p2, p3, p3)
        }
      ClosePath => close_path(context)
      SetGraphicsState(name) =>
        // warn_none: "failed to get extgstate {name}"
        if resources.get_ext_g_state(name) is Some(gs) {
          handle_gs(gs, context, resources)
        }
      StrokePath => stroke_path(context, device)
      EndPath => {
        if context.clip is Some(clip) && !context.path.elements().is_empty() {
          let clip_path = context.path.transform(context.get().ctm)
          context.push_clip_path(clip_path, clip, device)
          context.clip = None
        }
        context.path.truncate(0)
      }
      NonStrokeColor(c) => {
        let gs = context.get().graphics_state
        gs.non_stroke_color = c.map(n => n.as_f32())
        gs.non_stroke_pattern = None
      }
      StrokeColor(c) => {
        let gs = context.get().graphics_state
        gs.stroke_color = c.map(n => n.as_f32())
        gs.stroke_pattern = None
      }
      ClipNonZero => context.clip = Some(NonZero)
      ClipEvenOdd => context.clip = Some(EvenOdd)
      RestoreState => context.restore_state(device)
      FlatnessTolerance(_) =>
        // Ignore for now.
        ()
      ColorSpaceStroke(name) => {
        let cs = match ColorSpace::new_from_name(name) {
          Some(named) => named
          None =>
            context
            .get_color_space(resources, name)
            .unwrap_or(ColorSpace::device_gray())
        }
        let gs = context.get().graphics_state
        if !cs.is_pattern() {
          gs.stroke_pattern = None
        }
        gs.stroke_color = cs.initial_color()
        gs.stroke_cs = cs
      }
      ColorSpaceNonStroke(name) => {
        let cs = match ColorSpace::new_from_name(name) {
          Some(named) => named
          None =>
            context
            .get_color_space(resources, name)
            .unwrap_or(ColorSpace::device_gray())
        }
        let gs = context.get().graphics_state
        if !cs.is_pattern() {
          gs.non_stroke_pattern = None
        }
        gs.non_stroke_color = cs.initial_color()
        gs.none_stroke_cs = cs
      }
      DashPattern(arr, phase) => {
        let gs = context.get().graphics_state
        gs.stroke_props = {
          ..gs.stroke_props,
          dash_offset: phase.as_f32(),
          // kurbo apparently cannot properly deal with offsets that are exactly 0.
          dash_array: (arr.iter() : Iter[Float])
          .map((n : Float) => if n == 0.0 { (0.01 : Float) } else { n })
          .collect(),
        }
      }
      RenderingIntent(_) =>
        // Ignore for now.
        ()
      NonStrokeColorNamed(c, name) => {
        context.get().graphics_state.non_stroke_color = c.map(n => n.as_f32())
        let pattern = match name {
          Some(name) =>
            match resources.get_pattern(name) {
              Some(d) => Pattern::new(d, context, resources)
              None => None
            }
          None => None
        }
        context.get().graphics_state.non_stroke_pattern = pattern
      }
      StrokeColorNamed(c, name) => {
        context.get().graphics_state.stroke_color = c.map(n => n.as_f32())
        let pattern = match name {
          Some(name) =>
            match resources.get_pattern(name) {
              Some(d) => Pattern::new(d, context, resources)
              None => None
            }
          None => None
        }
        context.get().graphics_state.stroke_pattern = pattern
      }
      BeginMarkedContentWithProperties(tag, props_obj) => {
        // Properties can be either:
        // 1. A Name that references an entry in the Resources/Properties dictionary
        // 2. An inline dictionary with an OC key
        let mcid = match @hayro_syntax.dict_or_stream(props_obj) {
          Some((props, _)) => (props.get("MCID") : Int?)
          None => None
        }
        let oc = match props_obj.into_name() {
          Some(name) =>
            match resources.properties.get_ref(name.as_str()) {
              Some(r) => {
                let d = (
                  resources.properties.get(name.as_str()) : @hayro_syntax.Dict?).unwrap_or(
                  @hayro_syntax.Dict::empty(),
                )
                Some((d, r))
              }
              None => None
            }
          None => None
        }
        let oc = match oc {
          Some(_) => oc
          None =>
            match @hayro_syntax.dict_or_stream(props_obj) {
              Some((props, _)) =>
                match props.get_ref("OC") {
                  Some(r) => {
                    let d = (props.get("OC") : @hayro_syntax.Dict?).unwrap_or(
                      @hayro_syntax.Dict::empty(),
                    )
                    Some((d, r))
                  }
                  None => None
                }
              None => None
            }
        }
        if oc is Some((dict, oc_ref)) {
          context.ocg_state.begin_ocg(dict, oc_ref.to_id())
        } else {
          context.ocg_state.begin_marked_content()
        }
        device.begin_marked_content(tag.as_bytes(), mcid)
      }
      MarkedContentPointWithProperties(_, _) => ()
      EndMarkedContent => {
        context.ocg_state.end_marked_content()
        device.end_marked_content()
      }
      MarkedContentPoint(_) => ()
      BeginMarkedContent(tag) => {
        context.ocg_state.begin_marked_content()
        device.begin_marked_content(tag.as_bytes(), None)
      }
      BeginText => {
        let ts = context.get().text_state
        ts.text_matrix = @kurbo.Affine::identity()
        ts.text_line_matrix = @kurbo.Affine::identity()
      }
      SetTextMatrix(a, b, c, d, e, f) => {
        let m = @kurbo.Affine::new([
          a.as_f64(),
          b.as_f64(),
          c.as_f64(),
          d.as_f64(),
          e.as_f64(),
          f.as_f64(),
        ])
        let ts = context.get().text_state
        ts.text_line_matrix = m
        ts.text_matrix = m
      }
      EndText => {
        let has_outline = context.get().text_state.clip_paths
          .segments()
          .length() >
          0
        if has_outline {
          let clip_path = context.get().text_state.clip_paths.transform(
            context.get().ctm,
          )
          context.push_clip_path(clip_path, NonZero, device)
        }
        context.get().text_state.clip_paths.truncate(0)
      }
      TextFont(name, size) => {
        // In case we are unable to resolve the font, two scenarios:
        // 1) If the font doesn't exist in the first place in the resource dictionary,
        // assume Helvetica (this seems to be what other PDF viewers do).
        // 2) In case it's `None` because we were unable to resolve the font
        // (for whatever reason), leave it as `None`. Better showing no
        // text at all than garbage text.
        let font = match font_dict_cache.get(name.as_str()) {
          Some(font_dict) => context.resolve_font(font_dict)
          None =>
            match resources.get_font(name) {
              Some(font_dict) => {
                font_dict_cache[name.as_str()] = font_dict
                context.resolve_font(font_dict)
              }
              None =>
                match
                  Font::new_standard(Helvetica, context.settings.font_resolver) {
                  Some(f) => Some(TextStateFont::Fallback(f))
                  None => None
                }
            }
        }
        context.get().text_state.font_size = size.as_f32()
        context.get().text_state.font = font
      }
      ShowText(s) => {
        ensure_text_font(context)
        show_text_string(context, device, resources, s)
      }
      ShowTexts(arr) => {
        ensure_text_font(context)
        for obj in (arr.iter() : Iter[@hayro_syntax.Object]) {
          match obj {
            Number(num) =>
              context.get().text_state.apply_adjustment(num.as_f32())
            String(text) => show_text_string(context, device, resources, text)
            _ => ()
          }
        }
      }
      HorizontalScaling(h) =>
        context.get().text_state.horizontal_scaling = h.as_f32()
      TextLeading(tl) => context.get().text_state.leading = tl.as_f32()
      CharacterSpacing(c) => context.get().text_state.char_space = c.as_f32()
      WordSpacing(w) => context.get().text_state.word_space = w.as_f32()
      NextLine(tx, ty) => next_line(context, tx.as_f64(), ty.as_f64())
      NextLineUsingLeading =>
        next_line(context, 0.0, -context.get().text_state.leading.to_double())
      NextLineAndShowText(s) => {
        next_line(context, 0.0, -context.get().text_state.leading.to_double())
        show_text_string(context, device, resources, s)
      }
      TextRenderingMode(r) => {
        let mode : TextRenderingMode = match r.as_i64() {
          0L => Fill
          1L => Stroke
          2L => FillStroke
          3L => Invisible
          4L => FillAndClip
          5L => StrokeAndClip
          6L => FillAndStrokeAndClip
          7L => Clip
          _ =>
            // warn!("unknown text rendering mode {}", r.0.as_i64());
            Fill
        }
        context.get().text_state.render_mode = mode
      }
      NextLineAndSetLeading(tx, ty) => {
        let (tx, ty) = (tx.as_f64(), ty.as_f64())
        context.get().text_state.leading = Float::from_double(-ty)
        next_line(context, tx, ty)
      }
      ShapeGlyph(_, _, _, _, _, _) => ()
      XObject(name) => {
        let cache = context.interpreter_cache.object_cache
        let transfer_function = context.get().graphics_state.transfer_function
        if resources.get_x_object(name) is Some(s) &&
          XObject::new(
            s,
            context.settings.warning_sink,
            cache,
            transfer_function,
          )
          is Some(x_object) {
          draw_xobject(x_object, resources, context, device)
        }
      }
      InlineImage(stream) => {
        let warning_sink = context.settings.warning_sink
        let transfer_function = context.get().graphics_state.transfer_function
        let cache = context.interpreter_cache.object_cache
        if ImageXObject::new(
            stream,
            name => context.get_color_space(resources, name),
            warning_sink,
            cache,
            false,
            transfer_function,
          )
          is Some(x_object) {
          draw_image_xobject(x_object, context, device)
        }
      }
      TextRise(t) => context.get().text_state.rise = t.as_f32()
      Shading(name) => {
        if !context.ocg_state.is_visible() {
          continue
        }
        let transfer_function = context.get().graphics_state.transfer_function
        let shading = match resources.get_shading(name) {
          Some(o) =>
            match @hayro_syntax.dict_or_stream(o) {
              Some((dict, stream)) =>
                Shading::new(
                  dict,
                  stream,
                  context.interpreter_cache.object_cache,
                )
              None => None
            }
          None => None
        }
        if shading is Some(s) {
          let sp = Pattern::Shading({
            shading: s,
            matrix: @kurbo.Affine::identity(),
            opacity: context.get().graphics_state.non_stroke_alpha,
            transfer_function,
          })
          context.save_state()
          context.push_root_transform()
          let st = context.get()
          st.graphics_state.non_stroke_pattern = Some(sp)
          st.graphics_state.none_stroke_cs = ColorSpace::pattern()
          let bbox = context.bbox().to_path(0.1)
          let inverted_bbox = bbox.transform(context.get().ctm.inverse())
          fill_path_impl(context, device, NonZero, Some(inverted_bbox))
          context.pop_root_transform()
          context.restore_state(device)
        } else {
          // warn!("failed to process shading");
          ()
        }
      }
      BeginCompatibility => ()
      EndCompatibility => ()
      ColorGlyph(_, _) => ()
      ShowTextWithParameters(aw, ac, s) => {
        context.get().text_state.word_space = aw.as_f32()
        context.get().text_state.char_space = ac.as_f32()
        next_line(context, 0.0, -context.get().text_state.leading.to_double())
        show_text_string(context, device, resources, s)
      }
      _ =>
        // warn!("failed to read an operator");
        ()
    }
  }
  while context.num_states() > num_states {
    context.restore_state(device)
  }
}

///|
/// Even if no explicit font was set, we try to assume Helvetica. Acrobat
/// seems to do the same.
fn ensure_text_font(context : Context) -> Unit {
  if context.get().text_state.font is None {
    context.get().text_state.font = match
      Font::new_standard(Helvetica, context.settings.font_resolver) {
      Some(f) => Some(TextStateFont::Fallback(f))
      None => None
    }
  }
}
