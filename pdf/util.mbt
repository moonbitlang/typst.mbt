// Port of `typst-pdf/src/util.rs` and `typst-pdf/src/page.rs`: basic
// utilities for converting Typst types to the exporter's types.

///|
/// Round a double to the nearest `f32` (krilla works with `f32`s).
fn f32(v : Double) -> Double {
  Float::from_double(v).to_double()
}

///|
/// An absolute length in points, as `f32`.
fn to_f32(abs : @library.Abs) -> Double {
  f32(abs.to_pt())
}

///|
fn to_export_transform(ts : @library.Transform) -> @export.Transform {
  @export.Transform::from_row(
    f32(ts.sx.get()),
    f32(ts.ky.get()),
    f32(ts.kx.get()),
    f32(ts.sy.get()),
    to_f32(ts.tx),
    to_f32(ts.ty),
  )
}

///|
fn to_export_point(p : @library.Point) -> @export.Point {
  @export.Point::from_xy(to_f32(p.x), to_f32(p.y))
}

///|
fn to_export_size(size : @library.Axes[@library.Abs]) -> @export.Size? {
  @export.Size::from_wh(to_f32(size.x), to_f32(size.y))
}

///|
fn to_export_line_cap(cap : @library.LineCap) -> @export.LineCap {
  match cap {
    Butt => Butt
    Round => Round
    Square => Square
  }
}

///|
fn to_export_line_join(join : @library.LineJoin) -> @export.LineJoin {
  match join {
    Miter => Miter
    Round => Round
    Bevel => Bevel
  }
}

///|
fn to_export_fill_rule(rule : @library.FillRule) -> @export.FillRule {
  match rule {
    NonZero => NonZero
    EvenOdd => EvenOdd
  }
}

///|
fn spot_colorant_to_export(
  name : @library.SpotColorantName?,
) -> @export.SeparationColorant {
  match name {
    Some(All) => AllColorants
    Some(Custom(name)) => Custom(name)
    None => NoColorant
  }
}

///|
/// Display the font family of a font.
fn display_font(font : @library.FontInstance?) -> String {
  match font {
    Some(font) => "font `\{@library.repr_str(font.font().info().family)}`"
    None => "a font"
  }
}

///|
/// Convert a Typst path to an export path.
fn convert_path(path : @library.Curve, builder : @export.PathBuilder) -> Unit {
  for item in path.items() {
    match item {
      Move(p) => builder.move_to(to_f32(p.x), to_f32(p.y))
      Line(p) => builder.line_to(to_f32(p.x), to_f32(p.y))
      Cubic(p1, p2, p3) =>
        builder.cubic_to(
          to_f32(p1.x),
          to_f32(p1.y),
          to_f32(p2.x),
          to_f32(p2.y),
          to_f32(p3.x),
          to_f32(p3.y),
        )
      Close => builder.close()
    }
  }
}

///|
/// Create a new page label from a numbering applied to a page number
/// (upstream `PageLabel::generate`).
fn page_label_generate(
  numbering : @library.Numbering,
  number : UInt64,
) -> @export.PageLabel? {
  guard numbering is Pattern(pat) else { return None }
  guard pat.pieces.get(0) is Some((prefix, system)) else { return None }
  // If there is a suffix, we cannot use the common style optimization,
  // since PDF does not provide a suffix field.
  let style : @export.NumberingStyle? = if pat.suffix.is_empty() {
    match system {
      Arabic => Some(Arabic)
      LowerRoman => Some(LowerRoman)
      UpperRoman => Some(UpperRoman)
      LowerLatin if number <= 26 => Some(LowerAlpha)
      UpperLatin if number <= 26 => Some(UpperAlpha)
      _ => None
    }
  } else {
    None
  }
  // Prefix and offset depend on the style: If it is supported by the PDF
  // spec, we use the given prefix and an offset. Otherwise, everything goes
  // into prefix.
  let prefix = if style is None {
    (try? pat.apply(None, [number.reinterpret_as_int64()])).to_option()
  } else if prefix.is_empty() {
    None
  } else {
    Some(prefix)
  }
  let offset = match style {
    Some(_) if number > 0 && number <= 0xFFFFFFFFUL => Some(number.to_int())
    _ => None
  }
  Some(@export.PageLabel::new(style, prefix, offset))
}

///|
/// Creates an arabic page label with the specified page number.
fn page_label_arabic(number : UInt64) -> @export.PageLabel {
  @export.PageLabel::new(
    Some(Arabic),
    None,
    if number > 0 && number <= 0xFFFFFFFFUL {
      Some(number.to_int())
    } else {
      None
    },
  )
}
