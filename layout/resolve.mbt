// Helpers for upstream's generic `Resolve` and `unwrap_or_default` calls on
// composite types (`Sides`, `Corners`, `Axes`, `Smart`, strokes), which have
// no generic counterpart in the library.

///|
/// `Sides<Option<Rel<Length>>>::resolve`.
fn resolve_sides_rel(
  sides : @library.Sides[@library.Rel[@library.Length]?],
  styles : @library.StyleChain,
) -> @library.Sides[@library.Rel[@library.Abs]?] {
  sides.map(side => side.map(rel => rel.resolve(styles)))
}

///|
/// `Sides<Option<Rel<Abs>>>::unwrap_or_default`.
fn sides_rel_or_zero(
  sides : @library.Sides[@library.Rel[@library.Abs]?],
) -> @library.Sides[@library.Rel[@library.Abs]] {
  sides.map(side => side.unwrap_or(@library.Rel::zero()))
}

///|
/// `Corners<Option<Rel<Length>>>::resolve`.
fn resolve_corners_rel(
  corners : @library.Corners[@library.Rel[@library.Length]?],
  styles : @library.StyleChain,
) -> @library.Corners[@library.Rel[@library.Abs]?] {
  corners.map(corner => corner.map(rel => rel.resolve(styles)))
}

///|
/// `Corners<Option<Rel<Abs>>>::unwrap_or_default`.
fn corners_rel_or_zero(
  corners : @library.Corners[@library.Rel[@library.Abs]?],
) -> @library.Corners[@library.Rel[@library.Abs]] {
  corners.map(corner => corner.unwrap_or(@library.Rel::zero()))
}

///|
/// `Axes<Rel<Length>>::resolve`.
fn resolve_axes_rel(
  axes : @library.Axes[@library.Rel[@library.Length]],
  styles : @library.StyleChain,
) -> @library.Axes[@library.Rel[@library.Abs]] {
  axes.map(rel => rel.resolve(styles))
}

///|
/// `Sides<Option<Option<Stroke>>>::resolve`.
fn resolve_sides_stroke(
  sides : @library.Sides[@library.Stroke??],
  styles : @library.StyleChain,
) -> @library.Sides[@library.ResolvedStroke??] {
  sides.map(side => side.map(stroke => stroke.map(s => s.resolve(styles))))
}

///|
/// `sides.unwrap_or_default().map(|s| s.map(Stroke::unwrap_or_default))` on
/// resolved stroke sides: unspecified sides have no stroke, and the
/// specified ones are completed with the default stroke.
fn sides_fixed_stroke(
  sides : @library.Sides[@library.ResolvedStroke??],
) -> @library.Sides[@library.FixedStroke?] {
  sides.map(side => {
    match side {
      Some(Some(stroke)) => Some(stroke.unwrap_or_default())
      _ => None
    }
  })
}

///|
/// Whether any side has a stroke (`stroke.iter().any(Option::is_some)`).
fn any_stroke(sides : @library.Sides[@library.FixedStroke?]) -> Bool {
  sides.iter().any(s => s is Some(_))
}

///|
/// Upstream `Sizing::from(Smart<Rel>)`.
fn sizing_from_smart(
  smart : @library.Smart[@library.Rel[@library.Length]],
) -> @library.Sizing {
  match smart {
    Auto => Auto
    Custom(rel) => Rel(rel)
  }
}
