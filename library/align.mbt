// Port of the value-level parts of `typst-library/src/layout/align.rs`.

///|
/// Where to align something along an axis.
///
/// Possible values are horizontal alignments (`start`, `end`, `left`,
/// `center`, `right`), vertical alignments (`top`, `horizon`, `bottom`) and
/// 2D alignments, like `{center + horizon}`.
pub(all) enum Alignment {
  H(HAlignment)
  V(VAlignment)
  Both(HAlignment, VAlignment)
} derive(Eq, Hash, Debug)

///|
/// The horizontal component.
pub fn Alignment::x(self : Alignment) -> HAlignment? {
  match self {
    H(h) | Both(h, _) => Some(h)
    V(_) => None
  }
}

///|
/// The vertical component.
pub fn Alignment::y(self : Alignment) -> VAlignment? {
  match self {
    V(v) | Both(_, v) => Some(v)
    H(_) => None
  }
}

///|
/// Normalize the alignment to a LTR-TTB space.
pub fn Alignment::fix(self : Alignment, text_dir : Dir) -> Axes[FixedAlignment] {
  Axes::new(
    self.x().unwrap_or(HAlignment::Start).fix(text_dir),
    self.y().unwrap_or(VAlignment::Top).fix(text_dir),
  )
}

///|
/// Horizontal alignment to the start of the text direction.
pub let alignment_start : Alignment = H(Start)

///|
/// Horizontal alignment to the end of the text direction.
pub let alignment_end : Alignment = H(End)

///|
/// Left horizontal alignment.
pub let alignment_left : Alignment = H(Left)

///|
/// Center horizontal alignment.
pub let alignment_center : Alignment = H(Center)

///|
/// Right horizontal alignment.
pub let alignment_right : Alignment = H(Right)

///|
/// Top vertical alignment.
pub let alignment_top : Alignment = V(Top)

///|
/// Middle vertical alignment.
pub let alignment_horizon : Alignment = V(Horizon)

///|
/// Bottom vertical alignment.
pub let alignment_bottom : Alignment = V(Bottom)

///|
fn impl_alignment_const_start() -> Value {
  Dyn(Alignment(alignment_start))
}

///|
fn impl_alignment_const_end() -> Value {
  Dyn(Alignment(alignment_end))
}

///|
fn impl_alignment_const_left() -> Value {
  Dyn(Alignment(alignment_left))
}

///|
fn impl_alignment_const_center() -> Value {
  Dyn(Alignment(alignment_center))
}

///|
fn impl_alignment_const_right() -> Value {
  Dyn(Alignment(alignment_right))
}

///|
fn impl_alignment_const_top() -> Value {
  Dyn(Alignment(alignment_top))
}

///|
fn impl_alignment_const_horizon() -> Value {
  Dyn(Alignment(alignment_horizon))
}

///|
fn impl_alignment_const_bottom() -> Value {
  Dyn(Alignment(alignment_bottom))
}

///|
/// The axis this alignment belongs to: `{"horizontal"}` for horizontal
/// alignments, `{"vertical"}` for vertical ones and `{none}` for 2D
/// alignments.
fn impl_alignment_axis(self_ : Alignment) -> Axis? {
  match self_ {
    H(_) => Some(X)
    V(_) => Some(Y)
    Both(_, _) => None
  }
}

///|
/// The inverse alignment.
fn impl_alignment_inv(self_ : Alignment) -> Alignment {
  self_.inv()
}

///|
/// The inverse alignment.
pub fn Alignment::inv(self : Alignment) -> Alignment {
  match self {
    H(h) => H(h.inv())
    V(v) => V(v.inv())
    Both(h, v) => Both(h.inv(), v.inv())
  }
}

///|
pub impl Default for Alignment with fn default() {
  Both(Start, Top)
}

///|
/// Sum two alignments (upstream `Add for Alignment`).
pub fn Alignment::add(
  self : Alignment,
  rhs : Alignment,
) -> Alignment raise HintedError {
  match (self, rhs) {
    (H(h), V(v)) | (V(v), H(h)) => Both(h, v)
    (H(_), H(_)) => bail("cannot add two horizontal alignments")
    (V(_), V(_)) => bail("cannot add two vertical alignments")
    (H(_), Both(_, _)) | (Both(_, _), H(_)) =>
      bail("cannot add a horizontal and a 2D alignment")
    (V(_), Both(_, _)) | (Both(_, _), V(_)) =>
      bail("cannot add a vertical and a 2D alignment")
    (Both(_, _), Both(_, _)) => bail("cannot add two 2D alignments")
  }
}

///|
pub fn Alignment::repr(self : Alignment) -> String {
  match self {
    H(h) => h.repr()
    V(v) => v.repr()
    Both(h, v) => "\{h.repr()} + \{v.repr()}"
  }
}

///|
/// The fields of an alignment (`x`, `y`); `None` if missing.
pub fn Alignment::field(self : Alignment, field : String) -> Value? {
  match field {
    "x" => Some(IntoValue::into_value(self.x()))
    "y" => Some(IntoValue::into_value(self.y()))
    _ => None
  }
}

///|
pub impl Fold for Alignment with fn fold(self, outer) {
  match (self, outer) {
    (H(h), V(v) | Both(_, v)) => Both(h, v)
    (V(v), H(h) | Both(h, _)) => Both(h, v)
    _ => self
  }
}

///|
pub extend Alignment with Fold::{fold}

///|
/// Upstream `From<Side> for Alignment`.
pub fn Alignment::from_side(side : Side) -> Alignment {
  match side {
    Left => alignment_left
    Top => alignment_top
    Right => alignment_right
    Bottom => alignment_bottom
  }
}

///|
pub impl Reflect for Alignment with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for Alignment with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for Alignment with fn castable(value) {
  value is Dyn(Alignment(_))
}

///|
pub impl IntoValue for Alignment with fn into_value(self) {
  Dyn(Alignment(self))
}

///|
pub extend Alignment with IntoValue::{into_value}

///|
pub impl FromValue for Alignment with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) => align
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
/// Where to align something horizontally.
pub(all) enum HAlignment {
  Start
  Left
  Center
  Right
  End
} derive(Eq, Hash, Debug)

///|
pub impl Default for HAlignment with fn default() {
  Start
}

///|
/// The inverse horizontal alignment.
pub fn HAlignment::inv(self : HAlignment) -> HAlignment {
  match self {
    Start => End
    Left => Right
    Center => Center
    Right => Left
    End => Start
  }
}

///|
/// Resolve to the absolute alignment.
pub fn HAlignment::fix(self : HAlignment, dir : Dir) -> FixedAlignment {
  match (self, dir.is_positive()) {
    (Start, true) | (End, false) => Start
    (Left, _) => Start
    (Center, _) => Center
    (Right, _) => End
    (End, true) | (Start, false) => End
  }
}

///|
pub fn HAlignment::repr(self : HAlignment) -> String {
  match self {
    Start => "start"
    Left => "left"
    Center => "center"
    Right => "right"
    End => "end"
  }
}

///|
/// Upstream `TryFrom<Alignment> for HAlignment`.
pub fn HAlignment::try_from(value : Alignment) -> HAlignment raise HintedError {
  match value {
    H(h) => h
    v =>
      bail(
        "expected `start`, `left`, `center`, `right`, or `end`, found \{v.repr()}",
      )
  }
}

///|
pub impl Reflect for HAlignment with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for HAlignment with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for HAlignment with fn castable(value) {
  value is Dyn(Alignment(_))
}

///|
pub impl IntoValue for HAlignment with fn into_value(self) {
  Dyn(Alignment(H(self)))
}

///|
pub extend HAlignment with IntoValue::{into_value}

///|
pub impl FromValue for HAlignment with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) => HAlignment::try_from(align)
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
/// A horizontal alignment which only allows `left`/`right` and `start`/`end`,
/// thus excluding `center`.
pub(all) enum OuterHAlignment {
  Start
  Left
  Right
  End
} derive(Eq, Hash, Debug)

///|
pub impl Default for OuterHAlignment with fn default() {
  Start
}

///|
/// Resolve to the absolute alignment.
pub fn OuterHAlignment::fix(
  self : OuterHAlignment,
  dir : Dir,
) -> FixedAlignment {
  match (self, dir.is_positive()) {
    (Start, true) | (End, false) => Start
    (Left, _) => Start
    (Right, _) => End
    (End, true) | (Start, false) => End
  }
}

///|
/// Upstream `From<OuterHAlignment> for HAlignment`.
pub fn OuterHAlignment::to_h(self : OuterHAlignment) -> HAlignment {
  match self {
    Start => Start
    Left => Left
    Right => Right
    End => End
  }
}

///|
/// Upstream `TryFrom<Alignment> for OuterHAlignment`.
pub fn OuterHAlignment::try_from(
  value : Alignment,
) -> OuterHAlignment raise HintedError {
  match value {
    H(Start) => Start
    H(Left) => Left
    H(Right) => Right
    H(End) => End
    v => bail("expected `start`, `left`, `right`, or `end`, found \{v.repr()}")
  }
}

///|
pub impl Reflect for OuterHAlignment with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for OuterHAlignment with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for OuterHAlignment with fn castable(value) {
  value is Dyn(Alignment(_))
}

///|
pub impl IntoValue for OuterHAlignment with fn into_value(self) {
  self.to_h().into_value()
}

///|
pub impl FromValue for OuterHAlignment with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) => OuterHAlignment::try_from(align)
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
/// Where to align something vertically.
pub(all) enum VAlignment {
  Top
  Horizon
  Bottom
} derive(Eq, Compare, Hash, Debug)

///|
pub impl Default for VAlignment with fn default() {
  Top
}

///|
/// The inverse vertical alignment.
pub fn VAlignment::inv(self : VAlignment) -> VAlignment {
  match self {
    Top => Bottom
    Horizon => Horizon
    Bottom => Top
  }
}

///|
/// Returns the position of this alignment in a container with the given
/// extent.
pub fn VAlignment::position(self : VAlignment, extent : Abs) -> Abs {
  match self {
    Top => Abs::zero()
    Horizon => extent.div_by(2.0)
    Bottom => extent
  }
}

///|
/// Resolve to the absolute alignment. The vertical alignment does not depend
/// on text direction.
pub fn VAlignment::fix(self : VAlignment, _dir : Dir) -> FixedAlignment {
  match self {
    Top => Start
    Horizon => Center
    Bottom => End
  }
}

///|
pub fn VAlignment::repr(self : VAlignment) -> String {
  match self {
    Top => "top"
    Horizon => "horizon"
    Bottom => "bottom"
  }
}

///|
/// Upstream `TryFrom<Alignment> for VAlignment`.
pub fn VAlignment::try_from(value : Alignment) -> VAlignment raise HintedError {
  match value {
    V(v) => v
    v => bail("expected `top`, `horizon`, or `bottom`, found \{v.repr()}")
  }
}

///|
pub impl Reflect for VAlignment with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for VAlignment with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for VAlignment with fn castable(value) {
  value is Dyn(Alignment(_))
}

///|
pub extend VAlignment with Reflect::{output, input, castable}

///|
pub impl IntoValue for VAlignment with fn into_value(self) {
  Dyn(Alignment(V(self)))
}

///|
pub extend VAlignment with IntoValue::{into_value}

///|
pub impl FromValue for VAlignment with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) => VAlignment::try_from(align)
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
/// A vertical alignment which only allows `top` and `bottom`, thus excluding
/// `horizon`.
pub(all) enum OuterVAlignment {
  Top
  Bottom
} derive(Eq, Compare, Hash, Debug)

///|
pub impl Default for OuterVAlignment with fn default() {
  Top
}

///|
/// Resolve to the absolute alignment.
pub fn OuterVAlignment::fix(
  self : OuterVAlignment,
  _dir : Dir,
) -> FixedAlignment {
  match self {
    Top => Start
    Bottom => End
  }
}

///|
/// Upstream `From<OuterVAlignment> for VAlignment`.
pub fn OuterVAlignment::to_v(self : OuterVAlignment) -> VAlignment {
  match self {
    Top => Top
    Bottom => Bottom
  }
}

///|
/// Upstream `TryFrom<Alignment> for OuterVAlignment`.
pub fn OuterVAlignment::try_from(
  value : Alignment,
) -> OuterVAlignment raise HintedError {
  match value {
    V(Top) => Top
    V(Bottom) => Bottom
    v => bail("expected `top` or `bottom`, found \{v.repr()}")
  }
}

///|
pub impl Reflect for OuterVAlignment with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for OuterVAlignment with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for OuterVAlignment with fn castable(value) {
  value is Dyn(Alignment(_))
}

///|
pub impl IntoValue for OuterVAlignment with fn into_value(self) {
  self.to_v().into_value()
}

///|
pub impl FromValue for OuterVAlignment with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) => OuterVAlignment::try_from(align)
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
/// A component of a [SpecificAlignment] (upstream bounds
/// `TryFrom<Alignment>`, `HAlignment: From<H>` / `VAlignment: From<V>`).
pub(open) trait AlignmentComponent: Reflect {
  /// Convert from an alignment (upstream `TryFrom<Alignment>`).
  fn try_from_alignment(Alignment) -> Self raise HintedError
  /// Convert into an alignment (upstream `From<Self> for Alignment`).
  fn to_alignment(Self) -> Alignment
}

///|
pub impl AlignmentComponent for HAlignment with fn try_from_alignment(a) {
  HAlignment::try_from(a)
}

///|
pub impl AlignmentComponent for HAlignment with fn to_alignment(self) {
  H(self)
}

///|
pub impl AlignmentComponent for OuterHAlignment with fn try_from_alignment(a) {
  OuterHAlignment::try_from(a)
}

///|
pub impl AlignmentComponent for OuterHAlignment with fn to_alignment(self) {
  H(self.to_h())
}

///|
pub impl AlignmentComponent for VAlignment with fn try_from_alignment(a) {
  VAlignment::try_from(a)
}

///|
pub impl AlignmentComponent for VAlignment with fn to_alignment(self) {
  V(self)
}

///|
pub impl AlignmentComponent for OuterVAlignment with fn try_from_alignment(a) {
  OuterVAlignment::try_from(a)
}

///|
pub impl AlignmentComponent for OuterVAlignment with fn to_alignment(self) {
  V(self.to_v())
}

///|
/// An internal representation that combines horizontal or vertical
/// alignments. The allowed alignment positions are designated by the type
/// parameters `H` and `V`.
pub(all) enum SpecificAlignment[H, V] {
  H(H)
  V(V)
  Both(H, V)
} derive(Eq, Hash, Debug)

///|
/// Upstream `From<SpecificAlignment<H, V>> for Alignment`.
pub fn[H : AlignmentComponent, V : AlignmentComponent] SpecificAlignment::to_alignment(
  self : SpecificAlignment[H, V],
) -> Alignment {
  match self {
    H(h) => H::to_alignment(h)
    V(v) => V::to_alignment(v)
    Both(h, v) =>
      match (H::to_alignment(h), V::to_alignment(v)) {
        (H(h), V(v)) => Both(h, v)
        _ => panic()
      }
  }
}

///|
pub impl[H : AlignmentComponent, V : AlignmentComponent] Reflect for SpecificAlignment[
  H,
  V,
] with fn input() {
  Type(Type::alignment())
}

///|
pub impl[H : AlignmentComponent, V : AlignmentComponent] Reflect for SpecificAlignment[
  H,
  V,
] with fn output() {
  Type(Type::alignment())
}

///|
pub impl[H : AlignmentComponent, V : AlignmentComponent] Reflect for SpecificAlignment[
  H,
  V,
] with fn castable(value) {
  castable_of((Ty::new() : Ty[H]), value) ||
  castable_of((Ty::new() : Ty[V]), value)
}

///|
pub impl[H : AlignmentComponent, V : AlignmentComponent] IntoValue for SpecificAlignment[
  H,
  V,
] with fn into_value(self) {
  self.to_alignment().into_value()
}

///|
pub impl[H : AlignmentComponent, V : AlignmentComponent] FromValue for SpecificAlignment[
  H,
  V,
] with fn from_value(value) {
  match value {
    Dyn(Alignment(align)) =>
      match align {
        H(_) => H(H::try_from_alignment(align))
        V(_) => V(V::try_from_alignment(align))
        Both(h, v) =>
          Both(H::try_from_alignment(H(h)), V::try_from_alignment(V(v)))
      }
    _ => raise HintedError(CastInfo::Type(Type::alignment()).error(value))
  }
}

///|
/// A fixed alignment in the global coordinate space.
///
/// For horizontal alignment, start is globally left and for vertical alignment
/// it is globally top.
pub(all) enum FixedAlignment {
  Start
  Center
  End
} derive(Eq, Compare, Hash, Debug)

///|
/// Returns the position of this alignment in a container with the given
/// extent.
pub fn FixedAlignment::position(self : FixedAlignment, extent : Abs) -> Abs {
  match self {
    Start => Abs::zero()
    Center => extent.div_by(2.0)
    End => extent
  }
}

///|
/// The inverse alignment.
pub fn FixedAlignment::inv(self : FixedAlignment) -> FixedAlignment {
  match self {
    Start => End
    Center => Center
    End => Start
  }
}

///|
/// Upstream `From<Side> for FixedAlignment`.
pub fn FixedAlignment::from_side(side : Side) -> FixedAlignment {
  match side {
    Left | Top => Start
    Right | Bottom => End
  }
}

///|
/// The directions and alignments of upstream `fn prelude` (`lib.rs`):
/// scoped values that are globally available, too.
fn prelude_layout(global : Scope) -> Unit {
  global.define_("ltr", Dyn(Dir(LTR))) |> ignore
  global.define_("rtl", Dyn(Dir(RTL))) |> ignore
  global.define_("ttb", Dyn(Dir(TTB))) |> ignore
  global.define_("btt", Dyn(Dir(BTT))) |> ignore
  global.define_("start", Dyn(Alignment(alignment_start))) |> ignore
  global.define_("left", Dyn(Alignment(alignment_left))) |> ignore
  global.define_("center", Dyn(Alignment(alignment_center))) |> ignore
  global.define_("right", Dyn(Alignment(alignment_right))) |> ignore
  global.define_("end", Dyn(Alignment(alignment_end))) |> ignore
  global.define_("top", Dyn(Alignment(alignment_top))) |> ignore
  global.define_("horizon", Dyn(Alignment(alignment_horizon))) |> ignore
  global.define_("bottom", Dyn(Alignment(alignment_bottom))) |> ignore
}

///|
/// `Default::default()` of `Alignment` (AlignElem.alignment).
fn align_elem_alignment_default() -> Value {
  Alignment::default().into_value()
}
