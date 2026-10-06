///|
fn cast_msg(f : () -> Unit raise HintedError) -> String {
  try {
    f()
    "ok"
  } catch {
    HintedError(e) => e.message
  }
}

///|
test "sides cast" {
  let pt = (x : Double) => Value::Length(Length::from_abs(Abs::pt(x)))
  let d = Dict::from_pairs([("x", pt(1.0)), ("top", pt(2.0))])
  let s : Sides[Rel[Length]?] = Value::Dict(d).cast()
  @debug.debug_inspect(
    s.iter().map(v => v.map(r => r.repr_length()).unwrap_or("-")).collect(),
    content=(
      #|["0% + 1pt", "0% + 2pt", "0% + 1pt", "-"]
    ),
  )
  // The original dictionary is not modified.
  inspect(d.len(), content="2")
  inspect(
    cast_msg(() => {
      let _ : Sides[Rel[Length]?] = Value::Dict(
        Dict::from_pairs([("x", pt(1.0)), ("foo", pt(2.0))]),
      ).cast()
    }),
    content=(
      #|unexpected key "foo", valid keys are "left", "top", "right", "bottom", "x", "y", and "rest"
    ),
  )
  inspect(
    cast_msg(() => {
      let _ : Sides[Rel[Length]?] = Value::Dict(
        Dict::from_pairs([("foo", pt(2.0))]),
      ).cast()
    }),
    content=(
      #|unexpected key "foo"
    ),
  )
  let uniform : Sides[Rel[Length]?] = pt(3.0).cast()
  inspect(IntoValue::into_value(uniform).repr(), content="0% + 3pt")
  inspect(
    IntoValue::into_value(Sides::splat((None : Rel[Length]?))).repr(),
    content="(:)",
  )
}

///|
test "alignment add" {
  inspect(alignment_left.add(alignment_bottom).repr(), content="left + bottom")
  inspect(
    cast_msg(() => ignore(alignment_left.add(alignment_right))),
    content="cannot add two horizontal alignments",
  )
  inspect(
    cast_msg(() => {
      let _ : HAlignment = IntoValue::into_value(alignment_top).cast()
    }),
    content="expected `start`, `left`, `center`, `right`, or `end`, found top",
  )
}
