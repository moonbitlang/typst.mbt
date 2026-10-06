// Port of `typst-library/src/layout/dir.rs`.

///|
/// The four directions into which content can be laid out.
pub(all) enum Dir {
  /// Left to right.
  LTR
  /// Right to left.
  RTL
  /// Top to bottom.
  TTB
  /// Bottom to top.
  BTT
} derive(Eq, Hash, Debug)

///|
/// Whether this direction points into the positive coordinate direction.
///
/// The positive directions are left-to-right and top-to-bottom.
pub fn Dir::is_positive(self : Dir) -> Bool {
  match self {
    LTR | TTB => true
    RTL | BTT => false
  }
}

///|
fn impl_dir_const_ltr() -> Value {
  Dyn(Dir(LTR))
}

///|
fn impl_dir_const_rtl() -> Value {
  Dyn(Dir(RTL))
}

///|
fn impl_dir_const_ttb() -> Value {
  Dyn(Dir(TTB))
}

///|
fn impl_dir_const_btt() -> Value {
  Dyn(Dir(BTT))
}

///|
/// Returns a direction from a starting point.
fn impl_dir_from(side_ : Side) -> Dir {
  match side_ {
    Left => LTR
    Right => RTL
    Top => TTB
    Bottom => BTT
  }
}

///|
/// Returns a direction from an end point.
fn impl_dir_to(side_ : Side) -> Dir {
  match side_ {
    Right => LTR
    Left => RTL
    Bottom => TTB
    Top => BTT
  }
}

///|
/// The axis this direction belongs to.
fn impl_dir_axis(self_ : Dir) -> Axis {
  self_.axis()
}

///|
/// The axis this direction belongs to.
pub fn Dir::axis(self : Dir) -> Axis {
  match self {
    LTR | RTL => X
    TTB | BTT => Y
  }
}

///|
/// The corresponding sign, for use in calculations.
fn impl_dir_sign(self_ : Dir) -> Int64 {
  match self_ {
    LTR | TTB => 1L
    RTL | BTT => -1L
  }
}

///|
/// The start point of this direction, as an alignment.
fn impl_dir_start(self_ : Dir) -> Side {
  self_.start()
}

///|
/// The start point of this direction.
pub fn Dir::start(self : Dir) -> Side {
  match self {
    LTR => Left
    RTL => Right
    TTB => Top
    BTT => Bottom
  }
}

///|
/// The end point of this direction, as an alignment.
fn impl_dir_end(self_ : Dir) -> Side {
  self_.end()
}

///|
/// The end point of this direction.
pub fn Dir::end(self : Dir) -> Side {
  match self {
    LTR => Right
    RTL => Left
    TTB => Bottom
    BTT => Top
  }
}

///|
/// The inverse direction.
fn impl_dir_inv(self_ : Dir) -> Dir {
  self_.inv()
}

///|
/// The inverse direction.
pub fn Dir::inv(self : Dir) -> Dir {
  match self {
    LTR => RTL
    RTL => LTR
    TTB => BTT
    BTT => TTB
  }
}

///|
pub fn Dir::repr(self : Dir) -> String {
  match self {
    LTR => "ltr"
    RTL => "rtl"
    TTB => "ttb"
    BTT => "btt"
  }
}

///|
pub impl Reflect for Dir with fn input() {
  Type(Type::direction())
}

///|
pub impl Reflect for Dir with fn output() {
  Type(Type::direction())
}

///|
pub impl Reflect for Dir with fn castable(value) {
  value is Dyn(Dir(_))
}

///|
pub extend Dir with Reflect::{output, input, castable}

///|
pub impl IntoValue for Dir with fn into_value(self) {
  Dyn(Dir(self))
}

///|
pub impl FromValue for Dir with fn from_value(value) {
  match value {
    Dyn(Dir(dir)) => dir
    _ => raise HintedError(CastInfo::Type(Type::direction()).error(value))
  }
}

///|
/// The direction with the given positivity for this axis.
pub fn Axis::dir(self : Axis, positive : Bool) -> Dir {
  match (self, positive) {
    (X, true) => LTR
    (X, false) => RTL
    (Y, true) => TTB
    (Y, false) => BTT
  }
}
