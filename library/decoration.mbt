// Port of the `Decoration` and `DecoLine` types of
// `typst-library/src/text/deco.rs` (the values of the internal
// `TextElem::deco` style property, set by the decoration show rules of
// `typst-layout` and consumed by inline layout).

///|
/// A decoration for text.
///
/// Can be positioned over, under, or on top of text, or highlight the text
/// with a background.
pub(all) struct Decoration {
  line : DecoLine
  extent : Abs
} derive(Eq)

///|
/// A kind of decorative line.
pub(all) enum DecoLine {
  Underline(
    stroke~ : ResolvedStroke,
    offset~ : Smart[Abs],
    evade~ : Bool,
    background~ : Bool
  )
  Strikethrough(
    stroke~ : ResolvedStroke,
    offset~ : Smart[Abs],
    background~ : Bool
  )
  Overline(
    stroke~ : ResolvedStroke,
    offset~ : Smart[Abs],
    evade~ : Bool,
    background~ : Bool
  )
  Highlight(
    fill~ : Paint?,
    stroke~ : Sides[FixedStroke?],
    top_edge~ : TopEdge,
    bottom_edge~ : BottomEdge,
    radius~ : Corners[Rel[Abs]]
  )
} derive(Eq)

///|
/// A stroke whose fields are all unspecified (upstream
/// `Stroke::<Abs>::default()`).
pub impl Default for ResolvedStroke with fn default() {
  {
    paint: Auto,
    thickness: Auto,
    cap: Auto,
    join: Auto,
    dash: Auto,
    miter_limit: Auto,
  }
}

///|
pub extend ResolvedStroke with Default::{default}

// Decorations are only stored in the internal `TextElem::deco` property;
// as values, they are internal dynamic values.

///|
pub impl Reflect for Decoration with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for Decoration with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for Decoration with fn castable(v) {
  v is Dyn(Decoration(_))
}

///|
pub extend Decoration with Reflect::{output, input, castable}

///|
pub impl IntoValue for Decoration with fn into_value(self) {
  Dyn(Decoration(self))
}

///|
pub impl FromValue for Decoration with fn from_value(v) {
  match v {
    Dyn(Decoration(deco)) => deco
    v => raise HintedError(Decoration::input().error(v))
  }
}

///|
/// Upstream `Fold for SmallVec`: the outer decorations followed by the
/// inner ones (TextElem.deco).
fn text_elem_deco_fold(inner : Value, outer : Value) -> Value {
  let inner : Array[Decoration] = FromValue::from_value(inner) catch {
    _ => return inner
  }
  let outer : Array[Decoration] = FromValue::from_value(outer) catch {
    _ => return IntoValue::into_value(inner)
  }
  let folded = outer.copy()
  folded.append(inner)
  IntoValue::into_value(folded)
}

///|
/// Hashes the decoration through the values of its fields.
pub impl Fingerprint for Decoration with fn fingerprint(self, state) {
  let abs = (v : Abs) => Value::Length(Length::from_abs(v))
  let smart_abs = (v : Smart[Abs]) => {
    match v {
      Auto => Value::Auto
      Custom(v) => abs(v)
    }
  }
  let stroke = (v : ResolvedStroke) => v.to_length_stroke().into_value()
  state.write(abs(self.extent))
  match self.line {
    Underline(stroke=s, offset~, evade~, background~) => {
      state.write_discriminant(0)
      state.write(stroke(s))
      state.write(smart_abs(offset))
      state.write(evade)
      state.write(background)
    }
    Strikethrough(stroke=s, offset~, background~) => {
      state.write_discriminant(1)
      state.write(stroke(s))
      state.write(smart_abs(offset))
      state.write(background)
    }
    Overline(stroke=s, offset~, evade~, background~) => {
      state.write_discriminant(2)
      state.write(stroke(s))
      state.write(smart_abs(offset))
      state.write(evade)
      state.write(background)
    }
    Highlight(fill~, stroke=s, top_edge~, bottom_edge~, radius~) => {
      state.write_discriminant(3)
      state.write(IntoValue::into_value(fill))
      for side in s.iter() {
        state.write(side)
      }
      state.write(top_edge.into_value())
      state.write(bottom_edge.into_value())
      for r in radius.iter() {
        state.write(Value::Relative(r.map(Length::from_abs)))
      }
    }
  }
}
