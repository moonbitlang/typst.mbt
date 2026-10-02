///|
test "opentype fonts match skrifa" {
  run_cases("otf", data => dump_otf(data, 0))
}

///|
test "hinted opentype fonts match skrifa" {
  run_cases("otfh", data => dump_otf(data, 0, hinted=true))
}
