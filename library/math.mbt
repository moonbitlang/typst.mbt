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
  for
    entry in [
      (
        "thin", "Thin space", "A mathematical space of width one sixth of an em.",
        math_thin,
      ),
      (
        "med", "Medium space", "A mathematical space of width two ninths of an em.",
        math_medium,
      ),
      (
        "thick", "Thick space", "A mathematical space of width five eighteenths of an em.",
        math_thick,
      ),
      ("quad", "Quad space", "A one-em wide mathematical space.", math_quad),
      ("wide", "Wide space", "A two-em wide mathematical space.", math_wide),
    ] {
    let (name, title, docs, amount) = entry
    math
    .define(
      name,
      Content(Content::new(h_elem(), [(h_elem_amount, math_spacing(amount))])),
    )
    .with_documentation({ name, title, docs, })
    |> ignore
  }
}

///|
/// Upright (non-italic) font style in math (upstream `upright`).
fn impl_math_upright(body : Content) -> Content raise HintedError {
  math_upright(body)
}

///|
fn math_upright(body : Content) -> Content {
  body.styled(
    Property(Property::new(equation_elem(), equation_elem_italic, Bool(false))),
  )
}
