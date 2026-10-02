///|
test "color validation order" {
  inspect(
    parse_result(["--color=bogus", "--help"]),
    content=(
      #|invalid: invalid value 'bogus' for '--color <COLOR>'
      #|  [possible values: auto, always, never]
    ),
  )
  inspect(
    parse_result(["--color", "eval"]),
    content=(
      #|invalid: invalid value 'eval' for '--color <COLOR>'
      #|  [possible values: auto, always, never]
    ),
  )
  inspect(
    parse_result(["--color=bogus", "eval"]),
    content=(
      #|invalid: invalid value 'bogus' for '--color <COLOR>'
      #|  [possible values: auto, always, never]
    ),
  )
}

///|
test "short options with empty attached values" {
  inspect(
    parse_result(["eval", "1", "-j="]),
    content="invalid: invalid value '' for '--jobs <JOBS>': cannot parse integer from empty string",
  )
  inspect(
    parse_result(["info", "-f=", "json"]),
    content=(
      #|invalid: a value is required for '--format <FORMAT>' but none was supplied
      #|  [possible values: json, yaml]
    ),
  )
}
