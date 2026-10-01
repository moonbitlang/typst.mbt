// Whitebox tests for the hand-ported element field types.

///|
fn cast_err_msg(f : () -> Unit raise HintedError) -> String {
  try {
    f()
    "ok"
  } catch {
    HintedError(err) =>
      if err.hints.is_empty() {
        err.message
      } else {
        err.message + " | " + err.hints.join(" | ")
      }
  }
}

///|
test "font weight casts" {
  let w : FontWeight = FontWeight::from_value(Int(700L))
  inspect(w.into_value().repr(), content="\"bold\"")
  let w : FontWeight = FontWeight::from_value(Int(1000L))
  inspect(w.into_value().repr(), content="\"black\"")
  let w : FontWeight = FontWeight::from_value(Int(450L))
  inspect(w.into_value().repr(), content="450")
  inspect(
    cast_err_msg(() => FontWeight::from_value(Str("heavy")) |> ignore),
    content="expected integer, \"thin\", \"extralight\", \"light\", \"regular\", \"medium\", \"semibold\", \"bold\", \"extrabold\", or \"black\"",
  )
}

///|
test "tag validation" {
  inspect(cast_err_msg(() => Tag::from_value(Str("a")) |> ignore), content="ok")
  inspect(
    cast_err_msg(() => Tag::from_value(Str("foobar")) |> ignore),
    content="tag must be one to four characters in length | found 6 characters",
  )
  inspect(
    cast_err_msg(() => Tag::from_value(Str("a b")) |> ignore),
    content="spaces may only appear as padding following a tag",
  )
  inspect(Tag::from_bytes_lossy("a").to_str_lossy().length(), content="4")
}

///|
test "lang and region" {
  let l : Lang = Lang::from_value(Str("DE"))
  inspect(l.as_str(), content="de")
  inspect(
    cast_err_msg(() => Lang::from_value(Str("en-GB")) |> ignore),
    content="expected two or three letter language code (ISO 639-1/2/3) | you should leave only \"en\" in the `lang` parameter and specify \"GB\" in the `region` parameter",
  )
  let r : Region = Region::from_value(Str("gb"))
  inspect(r.as_str(), content="GB")
}

///|
test "margin casts" {
  let m : Margin[Smart[Rel[Length]]] = Margin::from_value(
    Dict(Dict::from_pairs([("x", Auto), ("top", Length(Length::zero()))])),
  )
  inspect(
    m.into_value().repr(),
    content=(
      #|(top: 0% + 0pt, left: auto, right: auto)
    ),
  )
  inspect(
    cast_err_msg(fn() {
      let _ : Margin[Smart[Rel[Length]]] = Margin::from_value(
        Dict(
          Dict::from_pairs([("inside", Length(Length::zero())), ("left", Auto)]),
        ),
      )
    }),
    content=(
      #|`inside` and `outside` are mutually exclusive with `left` and `right`
    ),
  )
}

///|
test "smart quotes" {
  inspect(
    cast_err_msg(() => SmartQuoteDict::from_value(Str("a")) |> ignore),
    content="expected 2 characters, found 1 character",
  )
  let q : SmartQuoteDict = SmartQuoteDict::from_value(Str("«»"))
  inspect(
    q.into_value().repr(),
    content="(double: (\"«\", \"»\"), single: auto)",
  )
}

///|
test "text size fold" {
  let inner = TextSize(Length::from_em(Em::new(1.5)))
  let outer = TextSize(Length::from_abs(Abs::pt(10.0)))
  inspect(inner.fold(outer).into_value().repr(), content="15pt")
}
