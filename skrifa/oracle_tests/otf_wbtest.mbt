///|
test "opentype fonts match skrifa" {
  run_cases("otf", data => dump_otf(data, 0))
}
