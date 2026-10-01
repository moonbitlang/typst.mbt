///|
/// Describe all matches and the split of `hay`, in the format of the oracle
/// (`oracle_wbtest.mbt`).
fn describe(pattern : String, hay : String) -> String {
  let re = Regex::new(pattern) catch {
    RegexError(msg) => return "error: " + msg
  }
  let out = StringBuilder()
  for caps in re.captures_iter(hay) {
    out.write_char('[')
    for i, g in caps.groups {
      if i > 0 {
        out.write_char(' ')
      }
      match g {
        Some(m) => out.write_string("\{m.start}..\{m.end}")
        None => out.write_char('-')
      }
    }
    out.write_char(']')
  }
  out.write_string(" split=")
  out.write_string(re.split(hay).map(s => @unicode.rust_debug_str(s)).join(","))
  out.to_string()
}

///|
test "ast_is_single_char" {
  inspect(ast_is_single_char("[a-z]"), content="true")
  inspect(ast_is_single_char("\\p{L}"), content="true")
  inspect(ast_is_single_char("."), content="true")
  inspect(ast_is_single_char("a"), content="true")
  inspect(ast_is_single_char("ab"), content="false")
  inspect(ast_is_single_char("[a-z]+"), content="false")
  inspect(ast_is_single_char("("), content="false")
}
