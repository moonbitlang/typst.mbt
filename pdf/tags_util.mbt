// Port of `typst-pdf/src/tags/util/mod.rs` (the `IdVec`/`Id` helpers are
// plain arrays and `Int` indices here, and the property helpers are calls
// with an empty style chain, since all fields are materialized).

///|
/// The style chain used to read materialized element fields (upstream
/// `StyleChain::default()`).
fn tags_styles() -> @library.StyleChain {
  @library.StyleChain::empty()
}

///|
/// Best effort fallible conversion.
fn paint_to_color(paint : @library.Paint) -> @export.NaiveRgbColor? {
  match paint {
    Solid(color) => {
      let c = color.to_rgb()
      Some(naive_rgb_color_f32(c.red, c.green, c.blue))
    }
    Gradient(_) => None
    Tiling(_) => None
  }
}

///|
/// krilla's `NaiveRgbColor::new_f32`.
fn naive_rgb_color_f32(
  red : Float,
  green : Float,
  blue : Float,
) -> @export.NaiveRgbColor {
  let conv = (v : Float) => {
    let x = ((255.0 : Float) * v).to_double()
    @math.round(x).to_int()
  }
  { red: conv(red), green: conv(green), blue: conv(blue), }
}

///|
fn artifact_kind_to_export(
  kind : @library.ArtifactKind,
) -> @export.ArtifactType {
  match kind {
    Header => Header
    Footer => Footer
    Watermark => Watermark
    PageNumber => PageNumber
    LineNumber => LineNumber
    Redaction => Redaction
    Bates => Bates
    Page => Page
    PaginationOther => PaginationOther
    Layout => Layout
    Background => Background
    Other => Other
  }
}

///|
fn table_header_scope_to_export(
  scope : @library.TableHeaderScope,
) -> @export.TableHeaderScope {
  match scope {
    Both => Both
    Column => Column
    Row => Row
  }
}

///|
/// Try to propagate the child language to the parent. If the parent language
/// is absent or the same as the child, the language is propagated successfully,
/// this function will return `None`, and the language is written to the parent.
/// Otherwise this function will return `Some`, and the language should be
/// specified for the child.
fn propagate_lang(
  parent : Ref[@library.Locale?],
  child : @library.Locale?,
) -> @library.Locale? {
  match child {
    Some(c) =>
      match parent.val {
        None => {
          parent.val = Some(c)
          None
        }
        Some(p) if p == c => {
          parent.val = Some(c)
          None
        }
        Some(_) => Some(c)
      }
    None => None
  }
}

///|
/// A copy of a tag (krilla's `TagKind::clone`).
fn tag_clone(tag : @export.TagKind) -> @export.TagKind {
  { name: tag.name, attrs: tag.attrs.copy(), location: tag.location, }
}

///|
/// A new tag of the given kind.
fn new_tag(name : @export.TagName) -> @export.TagKind {
  @export.TagKind::new(name)
}

///|
/// Set an optional attribute: `Some` sets it, `None` removes any attribute
/// of the same kind as `like`.
fn tag_set_opt(
  tag : @export.TagKind,
  attr : @export.Attr?,
  like : @export.Attr,
) -> Unit {
  match attr {
    Some(a) => tag.set(a)
    None => tag.remove_like(like)
  }
}

///|
fn tag_set_placement(tag : @export.TagKind, p : @export.Placement?) -> Unit {
  tag_set_opt(tag, p.map(p => @export.Attr::Placement(p)), Placement(Block))
}

///|
fn tag_set_alt_text(tag : @export.TagKind, alt : String?) -> Unit {
  tag_set_opt(tag, alt.map(a => @export.Attr::AltText(a)), AltText(""))
}

///|
fn tag_set_lang(tag : @export.TagKind, lang : String?) -> Unit {
  tag_set_opt(tag, lang.map(l => @export.Attr::Lang(l)), Lang(""))
}

///|
fn tag_set_background_color(
  tag : @export.TagKind,
  c : @export.NaiveRgbColor?,
) -> Unit {
  tag_set_opt(
    tag,
    c.map(c => @export.Attr::BackgroundColor(c)),
    BackgroundColor({ red: 0, green: 0, blue: 0, }),
  )
}

///|
fn tag_set_border_style(
  tag : @export.TagKind,
  v : @export.Sides[@export.BorderStyle]?,
) -> Unit {
  tag_set_opt(
    tag,
    v.map(v => @export.Attr::BorderStyle(v)),
    BorderStyle(@export.Sides::uniform(NoBorder)),
  )
}

///|
fn tag_set_border_thickness(
  tag : @export.TagKind,
  v : @export.Sides[Double]?,
) -> Unit {
  tag_set_opt(
    tag,
    v.map(v => @export.Attr::BorderThickness(v)),
    BorderThickness(@export.Sides::uniform(0.0)),
  )
}

///|
fn tag_set_border_color(
  tag : @export.TagKind,
  v : @export.Sides[@export.NaiveRgbColor]?,
) -> Unit {
  tag_set_opt(
    tag,
    v.map(v => @export.Attr::BorderColor(v)),
    BorderColor(@export.Sides::uniform({ red: 0, green: 0, blue: 0, })),
  )
}

///|
fn tag_set_bbox(tag : @export.TagKind, bbox : (Int, @export.Rect)?) -> Unit {
  tag_set_opt(
    tag,
    bbox.map(b => @export.Attr::BBox(b.0, b.1)),
    BBox(0, @export.Rect::from_ltrb(0.0, 0.0, 1.0, 1.0).unwrap()),
  )
}
