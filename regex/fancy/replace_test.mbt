// Port of `fancy-regex` 0.16.2 `tests/replace.rs` and `tests/splitting.rs`.

///|
test "replacer_string" {
  let regex = @fancy.Regex::new(
    "\\b([sS])uc(?:cs|s?)e(ed(?:ed|ing|s?)|ss(?:es|ful(?:ly)?|i(?:ons?|ve(?:ly)?)|ors?)?)\\b",
  )
  assert_eq(
    regex.replace("a sucessful b", Expand("${1}ucce$2")),
    "a successful b",
  )
  assert_eq(
    regex.replace("a Suceeded b", Expand("${1}ucce$2")),
    "a Succeeded b",
  )
  assert_eq(
    regex.replace("a sucessor b", Expand("${1}ucce$2")),
    "a successor b",
  )
}

///|
test "replacer_cow" {
  let regex = @fancy.Regex::new("\\b([oO])mmi(?=t)t?(t(?:ed|ing)|s)\\b")
  assert_eq(regex.replace("a ommiting b", Expand("${1}mit$2")), "a omitting b")
  assert_eq(regex.replace("a ommited b", Expand("${1}mit$2")), "a omitted b")
  assert_eq(regex.replace("a Ommits b", Expand("${1}mit$2")), "a Omits b")
}

///|
test "replacer_noexpand" {
  let regex = @fancy.Regex::new("\\b([aA])n+ull(ar|ments?|s?)\\b")
  assert_eq(
    regex.replace("a anullment b", NoExpand("${1}nnul$2")),
    "a ${1}nnul$2 b",
  )
}

///|
test "replacer_callback" {
  let regex = @fancy.Regex::new("\\b([aA])p(?:p[or]|ro)x\\.?(?=[ \\)\\n])")
  let result = regex.replace(
    "a Aprox b",
    Func(cap => "\{cap.get(1).unwrap().as_str()}pprox."),
  )
  assert_eq(result, "a Approx. b")
}

///|
/// `replace()` does only one replacement
test "replace_one" {
  let regex = @fancy.Regex::new("bla")
  assert_eq(regex.replace("blabla", Expand("foo")), "foobla")
}

///|
/// `replace_all()` replaces all non-overlapping matches
test "replace_all" {
  let regex = @fancy.Regex::new("aa")
  assert_eq(regex.replace_all("aaaa aaa aa a", Expand("xx")), "xxxx xxa xx a")
}

///|
/// `replacen()` replaces predefined number of times
test "replacen" {
  let regex = @fancy.Regex::new("bla")
  assert_eq(regex.replacen("blablabla", 2, Expand("foo")), "foofoobla")
}

///|
test "replace_doc_examples" {
  let re = @fancy.Regex::new("[^01]+")
  assert_eq(re.replace("1078910", Expand("")), "1010")
  let re = @fancy.Regex::new("([^,\\s]+),\\s+(\\S+)")
  let result = re.replace(
    "Springsteen, Bruce",
    Func(caps => "\{caps.at(2)} \{caps.at(1)}"),
  )
  assert_eq(result, "Bruce Springsteen")
  let re = @fancy.Regex::new("(?P<last>[^,\\s]+),\\s+(?P<first>\\S+)")
  assert_eq(
    re.replace("Springsteen, Bruce", Expand("$first $last")),
    "Bruce Springsteen",
  )
  let re = @fancy.Regex::new("(?P<first>\\w+)\\s+(?P<second>\\w+)")
  assert_eq(re.replace("deep fried", Expand("${first}_$second")), "deep_fried")
  let re = @fancy.Regex::new("(?P<last>[^,\\s]+),\\s+(\\S+)")
  assert_eq(re.replace("Springsteen, Bruce", NoExpand("$2 $last")), "$2 $last")
}

///|
fn split_to_vec(re_str : String, target : String) -> Array[String] raise {
  let re = @fancy.Regex::new(re_str)
  re.split(target).iter().map(x => x.unwrap()).collect()
}

///|
fn splitn_to_vec(
  re_str : String,
  target : String,
  limit : Int,
) -> Array[String] raise {
  let re = @fancy.Regex::new(re_str)
  re.splitn(target, limit).iter().map(x => x.unwrap()).collect()
}

///|
test "split" {
  assert_eq(split_to_vec("1", "123"), ["", "23"])
  assert_eq(split_to_vec("2", "123"), ["1", "3"])
  assert_eq(split_to_vec("3", "123"), ["12", ""])
  assert_eq(split_to_vec("4", "123"), ["123"])
  assert_eq(split_to_vec("1", ""), [""])
  assert_eq(split_to_vec("", "123"), ["", "1", "2", "3", ""])
  assert_eq(split_to_vec("123", "123"), ["", ""])
  assert_eq(split_to_vec("1", "111"), ["", "", "", ""])
  assert_eq(split_to_vec("123", "123456"), ["", "456"])
  assert_eq(split_to_vec("234|678", "123456789"), ["1", "5", "9"])
  assert_eq(split_to_vec("[1-3]", "123456"), ["", "", "", "456"])
  assert_eq(split_to_vec("[236]", "123456"), ["1", "", "45", ""])
  assert_eq(split_to_vec("(1|2)\\1", "12112122"), ["12", "21", ""])
  assert_eq(split_to_vec("(?<=1)2", "12112122"), ["1", "11", "1", "2"])
  assert_eq(split_to_vec("1(?=2)", "12112122"), ["", "21", "2", "22"])
  assert_eq(split_to_vec("(?<=2)1(?=2)", "12112122"), ["12112", "22"])
  let re = @fancy.Regex::new("[ \\t]+")
  let target = "a b \t  c\td    e"
  assert_eq(split_to_vec("[ \\t]+", target), ["a", "b", "c", "d", "e"])
  let fields : Array[String] = re
    .splitn(target, 3)
    .iter()
    .map(x => x.unwrap())
    .collect()
  assert_eq(fields, ["a", "b", "c\td    e"])
}

///|
test "splitn" {
  let cases : Array[(String, String, Array[String])] = [
    ("1", "123", ["", "23"]),
    ("2", "123", ["1", "3"]),
    ("3", "123", ["12", ""]),
    ("", "123", ["", "1", "2", "3", ""]),
    ("1", "", [""]),
  ]
  // splitn_limit_lt_num_mathes
  for case in cases {
    let (re_str, target, expected) = case
    assert_eq(splitn_to_vec(re_str, target, 6), expected)
  }
  // splitn_limit_eq_num_mathes
  for case in cases {
    let (re_str, target, expected) = case
    assert_eq(splitn_to_vec(re_str, target, expected.length()), expected)
  }
  // splitn_limit_st_num_mathes
  for re_str in ["1", "2", "3", ""] {
    assert_eq(splitn_to_vec(re_str, "123", 1), ["123"])
  }
  // splitn_limit_zero
  for case in cases {
    let (re_str, target, _) = case
    assert_eq(splitn_to_vec(re_str, target, 0), [])
  }
}
