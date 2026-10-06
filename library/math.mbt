// Parts of `typst-library/src/math/mod.rs` (`module()` lives in `lib.mbt`).

// Spacings.

///|
let math_thin : Em = Em::new(1.0 / 6.0)

///|
let math_medium : Em = Em::new(2.0 / 9.0)

///|
let math_thick : Em = Em::new(5.0 / 18.0)

///|
let math_quad : Em = Em::new(1.0)

///|
let math_wide : Em = Em::new(2.0)

///|
/// An em spacing as the `amount` of an `h` element (upstream
/// `Spacing::from(Em)`, cast to a value).
fn math_spacing(em : Em) -> Value {
  Length(Length::from_em(em))
}

///|
/// Define the spacings in the math module.
fn math_define_spacings(math : Scope) -> Unit {
  math
  .define_(
    "thin",
    Content(Content::new(h_elem(), [(h_elem_amount, math_spacing(math_thin))])),
  )
  .with_documentation({
    name: "thin",
    title: "Thin space",
    docs: "\n            A mathematical space of width one sixth of an em.\n\n            ```example\n            $\n              x y \\\n              x thin y\n            $\n            ```\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
  math
  .define_(
    "med",
    Content(
      Content::new(h_elem(), [(h_elem_amount, math_spacing(math_medium))]),
    ),
  )
  .with_documentation({
    name: "med",
    title: "Medium space",
    docs: "\n            A mathematical space of width two ninths of an em.\n\n            ```example\n            $ (lambda x. x) med y $\n            ```\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
  math
  .define_(
    "thick",
    Content(Content::new(h_elem(), [(h_elem_amount, math_spacing(math_thick))])),
  )
  .with_documentation({
    name: "thick",
    title: "Thick space",
    docs: "\n            A mathematical space of width five eighteenths of an em.\n\n            ```example\n            $ x thick y $\n            ```\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
  math
  .define_(
    "quad",
    Content(Content::new(h_elem(), [(h_elem_amount, math_spacing(math_quad))])),
  )
  .with_documentation({
    name: "quad",
    title: "Quad space",
    docs: "\n            A one-em wide mathematical space.\n\n            ```example\n            $\n              f(x) = cases(\n                1/x quad &\"if\" x != 0,\n                0 quad &\"otherwise\",\n              )\n            $\n            ```\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
  math
  .define_(
    "wide",
    Content(Content::new(h_elem(), [(h_elem_amount, math_spacing(math_wide))])),
  )
  .with_documentation({
    name: "wide",
    title: "Wide space",
    docs: "\n            A two-em wide mathematical space.\n\n            ```example\n            $\n              f(x) = cases(\n                1/x wide &\"if\" x != 0,\n                0 wide &\"otherwise\",\n              )\n            $\n            ```\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
}

///|
/// Upright (non-italic) font style in math (upstream `upright`).
fn impl_math_upright(body : Content) -> Content {
  math_upright(body)
}

///|
fn math_upright(body : Content) -> Content {
  body.styled(
    Property(Property::new(equation_elem(), equation_elem_italic, Bool(false))),
  )
}

// The `MathClass` cast (upstream `foundations/cast.rs`), used by
// `ClassElem::class`.

///|
fn math_class_name(class : @unicode.MathClass) -> String {
  match class {
    Normal => "normal"
    Alphabetic => "alphabetic"
    Binary => "binary"
    Closing => "closing"
    Diacritic => "diacritic"
    Fence => "fence"
    GlyphPart => "glyph-part"
    Large => "large"
    Opening => "opening"
    Punctuation => "punctuation"
    Relation => "relation"
    Space => "space"
    Unary => "unary"
    Vary => "vary"
    Special => "special"
  }
}

///|
/// The castable math classes, in upstream's order.
let math_class_casts : ReadOnlyArray[(String, @unicode.MathClass, String)] = [
  ("normal", Normal, "The default class for non-special things."),
  ("punctuation", Punctuation, "Punctuation, e.g. a comma."),
  ("opening", Opening, "An opening delimiter, e.g. `(`."),
  ("closing", Closing, "A closing delimiter, e.g. `)`."),
  ("fence", Fence, "A delimiter that is the same on both sides, e.g. `|`."),
  ("large", Large, "A large operator like `sum`."),
  ("relation", Relation, "A relation like `=` or `prec`."),
  ("unary", Unary, "A unary operator like `not`."),
  ("binary", Binary, "A binary operator like `times`."),
  ("vary", Vary, "An operator that can be both unary or binary like `+`."),
  ("diacritic", Diacritic, "An accent character."),
]

///|
pub impl Reflect for @unicode.MathClass with fn input() {
  let mut info : CastInfo? = None
  for entry in math_class_casts[:] {
    let next = CastInfo::Value(Str(entry.0), entry.2)
    info = Some(
      match info {
        None => next
        Some(info) => info.union_with(next)
      },
    )
  }
  info.unwrap()
}

///|
pub impl Reflect for @unicode.MathClass with fn output() {
  input_of((Ty::new() : Ty[@unicode.MathClass]))
}

///|
pub impl Reflect for @unicode.MathClass with fn castable(v) {
  match v {
    Str(s) => math_class_casts.iter().any(entry => entry.0 == s)
    _ => false
  }
}

///|
pub impl IntoValue for @unicode.MathClass with fn into_value(self) {
  Str(math_class_name(self))
}

///|
pub impl FromValue for @unicode.MathClass with fn from_value(v) {
  if v is Str(s) {
    for entry in math_class_casts[:] {
      if entry.0 == s {
        return entry.1
      }
    }
  }
  raise HintedError(input_of((Ty::new() : Ty[@unicode.MathClass])).error(v))
}

///|
/// An iterator that alternates between the `Left` and `Right` values, if the
/// initial value is not `None` (`None_` here; `None` would clash with
/// `Option`/`Value`).
pub(all) enum LeftRightAlternator {
  None_
  Left
  Right
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LeftRightAlternator with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LeftRightAlternator with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LeftRightAlternator with @debug.Debug::{to_repr}

///|
/// Returns the current value and advances the alternator (upstream
/// `Iterator::next`, which always yields).
pub fn LeftRightAlternator::next(
  self : Ref[LeftRightAlternator],
) -> LeftRightAlternator {
  let r = self.val
  match self.val {
    None_ => ()
    Left => self.val = Right
    Right => self.val = Left
  }
  r
}
