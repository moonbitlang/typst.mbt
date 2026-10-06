// Port of `typst-pdf/src/tags/tree/text.rs`.

///|
priv struct TextAttrs {
  /// Store the last resolved set of text attributes. The resolution isn't
  /// that expensive, but for large bodies of text it is resolved quite often.
  mut last_resolved : (@library.FontInstance, @library.Abs, ResolvedTextAttrs)?
  items : Array[(Int, TextAttr)]
}

///|
fn TextAttrs::new() -> TextAttrs {
  { last_resolved: None, items: [], }
}

///|
fn TextAttrs::len(self : TextAttrs) -> Int {
  self.items.length()
}

///|
fn TextAttrs::push(self : TextAttrs, id : Int, attr : TextAttr) -> Unit {
  self.last_resolved = None
  self.items.push((id, attr))
}

///|
fn TextAttrs::insert(
  self : TextAttrs,
  idx : Int,
  id : Int,
  attr : TextAttr,
) -> Unit {
  self.last_resolved = None
  self.items.insert(idx, (id, attr))
}

///|
/// Returns true if a decoration was removed.
fn TextAttrs::pop(self : TextAttrs, id : Int) -> Bool {
  self.last_resolved = None
  if self.items.last() is Some((i, _)) && i == id {
    self.items.pop() |> ignore
    true
  } else {
    false
  }
}

///|
priv enum TextAttr {
  Strong
  Emph
  SuperScript(@library.SuperElem)
  SubScript(@library.SubElem)
  Highlight(@library.HighlightElem)
  Underline(@library.UnderlineElem)
  Overline(@library.OverlineElem)
  Strike(@library.StrikeElem)
}

///|
priv struct ResolvedTextAttrs {
  strong : Bool?
  emph : Bool?
  script : ResolvedScript?
  background : @export.NaiveRgbColor??
  deco : ResolvedTextDeco?
} derive(Eq)

///|
let resolved_text_attrs_empty : ResolvedTextAttrs = {
  strong: None,
  emph: None,
  script: None,
  background: None,
  deco: None,
}

///|
fn ResolvedTextAttrs::is_empty(self : ResolvedTextAttrs) -> Bool {
  self == resolved_text_attrs_empty
}

///|
priv struct ResolvedScript {
  baseline_shift : Double
  lineheight : @export.LineHeight
} derive(Eq)

///|
priv struct ResolvedTextDeco {
  kind : TextDecoKind
  color : @export.NaiveRgbColor?
  thickness : Double?
} derive(Eq)

///|
priv enum TextDecoKind {
  Underline
  Overline
  Strike
} derive(Eq)

///|
fn TextDecoKind::to_export(self : TextDecoKind) -> @export.TextDecorationType {
  match self {
    Underline => Underline
    Overline => Overline
    Strike => LineThrough
  }
}

///|
fn resolve_text_attrs(
  tree : Tree,
  options : CompletePdfOptions,
  text : @library.TextItem,
) -> ResolvedTextAttrs {
  let state = tree.state()
  if state.text_attrs.last_resolved is Some((font, size, attrs)) &&
    font == text.font &&
    size == text.size {
    return attrs
  }
  let (attrs, error) = compute_attrs(options, state.text_attrs.items, text)
  if error is Some(error) {
    tree.errors.push(error)
  }
  state.text_attrs.last_resolved = Some((text.font, text.size, attrs))
  attrs
}

///|
fn compute_attrs(
  options : CompletePdfOptions,
  items : Array[(Int, TextAttr)],
  text : @library.TextItem,
) -> (ResolvedTextAttrs, @library.SourceDiagnostic?) {
  let styles = tags_styles()
  let mut strong : Bool? = None
  let mut emph : Bool? = None
  let mut script : ResolvedScript? = None
  let mut background : @export.NaiveRgbColor?? = None
  let resolved_deco : Ref[(@library.Content, ResolvedTextDeco)?] = Ref(None)
  let err : Ref[@library.SourceDiagnostic?] = Ref(None)
  for i = items.length() - 1; i >= 0; i = i - 1 {
    let (_, attr) = items[i]
    match attr {
      Strong => if strong is None { strong = Some(true) }
      Emph => if emph is None { emph = Some(true) }
      SubScript(sub) =>
        if script is None {
          script = Some(
            compute_script(text, Sub, sub.baseline(styles), sub.size(styles)),
          )
        }
      SuperScript(sup) =>
        if script is None {
          script = Some(
            compute_script(text, Super, sup.baseline(styles), sup.size(styles)),
          )
        }
      Highlight(highlight) =>
        if background is None {
          let color = match highlight.fill(styles) {
            Some(paint) => paint_to_color(paint)
            None => None
          }
          background = Some(color)
        }
      Underline(underline) =>
        compute_deco(
          resolved_deco,
          err,
          options,
          text,
          underline.pack(),
          Underline,
          underline.stroke(styles),
        )
      Overline(overline) =>
        compute_deco(
          resolved_deco,
          err,
          options,
          text,
          overline.pack(),
          Overline,
          overline.stroke(styles),
        )
      Strike(strike) =>
        compute_deco(
          resolved_deco,
          err,
          options,
          text,
          strike.pack(),
          Strike,
          strike.stroke(styles),
        )
    }
  }
  let attrs : ResolvedTextAttrs = {
    strong,
    emph,
    script,
    background,
    deco: resolved_deco.val.map(d => d.1),
  }
  (attrs, err.val)
}

///|
fn compute_script(
  text : @library.TextItem,
  kind : @library.ScriptKind,
  baseline_shift : @library.Smart[@library.Length],
  lineheight : @library.Smart[@library.TextSize],
) -> ResolvedScript {
  // TODO: The `typographic` setting is ignored for now.
  // Is it better to be accurate regarding the layouting, and
  // thus don't write any baseline shift and lineheight when
  // a typographic sub/super script glyph is used? Or should
  // we always write the shift so the sub/super script can be
  // picked up by AT?
  let metrics = text.font.metrics()
  let script_metrics = match kind {
    Sub => metrics.subscript.unwrap_or(@library.default_subscript_metrics)
    Super => metrics.superscript.unwrap_or(@library.default_superscript_metrics)
  }
  // NOTE: The user provided baseline_shift needs to be inverted.
  let baseline_shift = match baseline_shift {
    Custom(s) => s.at(text.size).neg()
    Auto => script_metrics.vertical_offset.at(text.size)
  }
  let lineheight = match lineheight {
    Custom(s) => s.0.at(text.size)
    Auto => script_metrics.height.at(text.size)
  }
  {
    baseline_shift: to_f32(baseline_shift),
    lineheight: CustomHeight(to_f32(lineheight)),
  }
}

///|
fn compute_deco(
  resolved : Ref[(@library.Content, ResolvedTextDeco)?],
  err : Ref[@library.SourceDiagnostic?],
  options : CompletePdfOptions,
  text : @library.TextItem,
  elem : @library.Content,
  kind : TextDecoKind,
  stroke : @library.Smart[@library.Stroke],
) -> Unit {
  match resolved.val {
    Some((elem, deco)) =>
      // PDF can only represent one text decoration style at a time.
      // If PDF/UA-1 is enforced, throw an error.
      if err.val is None &&
        deco.kind != kind &&
        options.validators().ua is Some(accessibility) {
        let validator = accessibility_as_str(accessibility)
        let span = elem.span()
        err.val = Some(
          @library.SourceDiagnostic::error_at(
            span,
            "\{validator} error: cannot combine underline, overline, or strike",
          ),
        )
      }
    None => {
      let (color, thickness) = match stroke {
        Custom(s) =>
          (
            match s.paint {
              Custom(p) => paint_to_color(p)
              Auto => None
            },
            match s.thickness {
              Custom(t) => Some(to_f32(t.at(text.size)))
              Auto => None
            },
          )
        Auto => (None, None)
      }
      let deco : ResolvedTextDeco = { kind, color, thickness, }
      resolved.val = Some((elem, deco))
    }
  }
}

///|
fn accessibility_as_str(a : @export.Accessibility) -> String {
  @export.Validator::Ua(a).as_str()
}
