// Port of `typst-library/src/math/op.rs` (the `OpElem` element is
// generated).

///|
/// The predefined text operators: (name, text, limits) (upstream `ops!`).
let math_ops : ReadOnlyArray[(String, String, Bool)] = [
  ("arccos", "arccos", false),
  ("arcsin", "arcsin", false),
  ("arctan", "arctan", false),
  ("arg", "arg", false),
  ("cos", "cos", false),
  ("cosh", "cosh", false),
  ("cot", "cot", false),
  ("coth", "coth", false),
  ("csc", "csc", false),
  ("csch", "csch", false),
  ("ctg", "ctg", false),
  ("deg", "deg", false),
  ("det", "det", true),
  ("dim", "dim", false),
  ("exp", "exp", false),
  ("gcd", "gcd", true),
  ("lcm", "lcm", true),
  ("hom", "hom", false),
  ("id", "id", false),
  ("im", "im", false),
  ("inf", "inf", true),
  ("ker", "ker", false),
  ("lg", "lg", false),
  ("lim", "lim", true),
  ("liminf", "lim inf", true),
  ("limsup", "lim sup", true),
  ("ln", "ln", false),
  ("log", "log", false),
  ("max", "max", true),
  ("min", "min", true),
  ("mod", "mod", false),
  ("Pr", "Pr", true),
  ("sec", "sec", false),
  ("sech", "sech", false),
  ("sin", "sin", false),
  ("sinc", "sinc", false),
  ("sinh", "sinh", false),
  ("sup", "sup", true),
  ("tan", "tan", false),
  ("tanh", "tanh", false),
  ("tg", "tg", false),
  ("tr", "tr", false),
]

///|
/// Define the text operators in the math scope (upstream `op::define`).
fn op_define(math : Scope) -> Unit {
  for entry in math_ops[:] {
    let (name, operator, limits) = entry
    math.define_(
      name,
      // Latex also uses their equivalent of `TextElem` here.
      Content(
        Content::new(op_elem(), [
          (op_elem_text, Content(TextElem::packed(operator))),
        ]).with_field(op_elem_limits, Bool(limits)),
      ),
    )
    |> ignore
  }
  let dif = (d : Char) => {
    Content::new(h_elem(), [(h_elem_amount, math_spacing(math_thin))])
    .with_field(h_elem_weak, Bool(true))
    .add(
      Content::new(class_elem(), [
        (class_elem_class, Str("unary")),
        (
          class_elem_body,
          Content(math_upright(SymbolElem::packed(d.to_string()))),
        ),
      ]),
    )
  }
  math.define_("dif", Content(dif('d'))) |> ignore
  math.define_("Dif", Content(dif('D'))) |> ignore
}
