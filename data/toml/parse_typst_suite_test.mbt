///|
/// Expectations verified against upstream Typst (toml 0.8.19 / toml_edit 0.22.23).
test "oracle: typst suite" {
  check_parse(
    "string = \"wonderful\"\ninteger = 42\nfloat = 3.14\nboolean = true\ndate_time = 2023-02-01T15:38:57Z\ndate_time2 = 2023-02-01T15:38:57\ndate = 2023-02-01\ntime = 15:38:57\narray = [1, \"string\", 3.0, false]\ninline_table = { first = \"amazing\", second = \"greater\" }\n\n[table]\nelement = 5\nothers = [false, \"indeed\", 7]\n",
    "ok {\"string\": \"wonderful\", \"integer\": 42, \"float\": 3.14f, \"boolean\": true, \"date_time\": D(2023-02-01T15:38:57Z), \"date_time2\": D(2023-02-01T15:38:57), \"date\": D(2023-02-01), \"time\": D(15:38:57), \"array\": [1, \"string\", 3.0f, false], \"inline_table\": {\"first\": \"amazing\", \"second\": \"greater\"}, \"table\": {\"element\": 5, \"others\": [false, \"indeed\", 7]}}",
  )
  check_parse("\"only a string\"\n", "err 15..16: expected `.`, `=`")
  check_parse("3", "err 1..1: expected `.`, `=`")
  check_parse("key = 9223372036854775807", "ok {\"key\": 9223372036854775807}")
  check_parse(
    "key = -9223372036854775808", "ok {\"key\": -9223372036854775808}",
  )
  check_parse(
    "key = 9223372036854775808", "err 6..7: number too large to fit in target type",
  )
  check_parse(
    "key = -9223372036854775809", "err 6..7: number too small to fit in target type",
  )
  check_parse(
    "key = 18446744073709551615", "err 6..7: number too large to fit in target type",
  )
  check_parse(
    "key = 18446744073709551616", "err 6..7: number too large to fit in target type",
  )
  check_parse(
    "key = 170141183460469231731687303715884105727", "err 6..7: number too large to fit in target type",
  )
  check_parse(
    "key = -170141183460469231731687303715884105728", "err 6..7: number too small to fit in target type",
  )
  check_parse(
    "key = 340282366920938463463374607431768211455", "err 6..7: number too large to fit in target type",
  )
  check_parse(
    "a = 1979-05-27T00:32:00-07:00\nb = 1979-05-27T00:32:00.999999-07:00\nc = 1979-05-27T07:32:60\nd = 07:32:00.1234567891234\ne = 1979-05-27T07:32:00.100+00:00\nf = 1979-05-27T07:32:00-00:00\ng = 9999-12-31T23:59:60.5+23:59\nh = 1979-05-27t07:32:00.123456789123z\ni = 1979-05-27 07:32:00.000000001\nj = 0001-01-01T00:00:00.0+01:30",
    "ok {\"a\": D(1979-05-27T00:32:00-07:00), \"b\": D(1979-05-27T00:32:00.999999-07:00), \"c\": D(1979-05-27T07:32:60), \"d\": D(07:32:00.123456789), \"e\": D(1979-05-27T07:32:00.1+00:00), \"f\": D(1979-05-27T07:32:00+00:00), \"g\": D(9999-12-31T23:59:60.5+23:59), \"h\": D(1979-05-27T07:32:00.123456789Z), \"i\": D(1979-05-27T07:32:00.000000001), \"j\": D(0001-01-01T00:00:00+01:30)}",
  )
}
