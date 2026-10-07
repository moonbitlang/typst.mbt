// Helpers for the differential test cases generated from rust_decimal
// (`rust_decimal_cases_wbtest.mbt`).

///|
let harness_failures : Array[String] = []

///|
let harness_checks : Ref[Int] = Ref(0)

///|
fn hparse(s : String) -> RustDecimal {
  RustDecimal::from_str_exact(s).unwrap()
}

///|
fn hstr(d : RustDecimal?) -> String {
  match d {
    Some(d) => d.to_string()
    None => "None"
  }
}

///|
fn hcheck(what : String, got : String, want : String) -> Unit {
  harness_checks.val += 1
  if got != want {
    harness_failures.push("\{what}: got \{got}, want \{want}")
  }
}

///|
fn chk2(
  a : String,
  b : String,
  add : String,
  sub : String,
  mul : String,
  div : String,
  rem : String,
  cmp : Int,
) -> Unit {
  let x = hparse(a)
  let y = hparse(b)
  hcheck("\{a} + \{b}", hstr(x.checked_add(y)), add)
  hcheck("\{a} - \{b}", hstr(x.checked_sub(y)), sub)
  hcheck("\{a} * \{b}", hstr(x.checked_mul(y)), mul)
  hcheck("\{a} / \{b}", hstr(x.checked_div(y)), div)
  hcheck("\{a} % \{b}", hstr(x.checked_rem(y)), rem)
  hcheck("cmp \{a} \{b}", x.cmp(y).to_string(), cmp.to_string())
}

///|
fn chk1(
  a : String,
  floor : String,
  ceil : String,
  trunc : String,
  fract : String,
  digits : Int,
  round : String,
  exp : Int,
  pow : String,
  f64bits : UInt64,
  i64s : String,
  is_int : Bool,
) -> Unit {
  let x = hparse(a)
  hcheck("floor \{a}", x.floor().to_string(), floor)
  hcheck("ceil \{a}", x.ceil().to_string(), ceil)
  hcheck("trunc \{a}", x.trunc().to_string(), trunc)
  hcheck("fract \{a}", x.fract().to_string(), fract)
  hcheck(
    "round \{a} \{digits}",
    match Decimal::Decimal(x).round(digits) {
      Some(d) => d.0.to_string()
      None => "None"
    },
    round,
  )
  hcheck("powi \{a} \{exp}", hstr(x.checked_powi(exp.to_int64())), pow)
  hcheck(
    "to_f64 \{a}",
    x.to_f64().reinterpret_as_uint64().to_string(),
    f64bits.to_string(),
  )
  hcheck(
    "to_i64 \{a}",
    match x.to_i64() {
      Some(i) => i.to_string()
      None => "None"
    },
    i64s,
  )
  hcheck("is_integer \{a}", x.is_integer().to_string(), is_int.to_string())
}

///|
fn chkf(bits : UInt64, want : String) -> Unit {
  let f = bits.reinterpret_as_double()
  hcheck("from_f64 \{f}", hstr(RustDecimal::from_f64_retain(f)), want)
}

///|
fn chkpow(base : String, exp : Int64, want : String) -> Unit {
  hcheck("pow \{base} \{exp}", hstr(hparse(base).checked_powi(exp)), want)
}

///|
fn chks(s : String, want : String) -> Unit {
  hcheck("parse \{s}", hstr(RustDecimal::from_str_exact(s)), want)
}

///|
fn report() -> Unit raise {
  if !harness_failures.is_empty() {
    let n = harness_failures.length()
    let shown = harness_failures[0:if n > 40 { 40 } else { n }].to_owned()
    fail("\{n} of \{harness_checks.val} checks failed:\n" + shown.join("\n"))
  }
}

///|
/// An ordering is `-1`, `0` or `1` (upstream's `Ordering`) on every target,
/// also where the mantissas differ by more than one limb of `BigInt`: there
/// `BigInt`'s own `compare` gives the difference of the limb counts on
/// wasm-gc, and `calc.max` (`ordering == goal`) kept its first argument.
test "decimal orderings are -1, 0 or 1" {
  let small = Decimal::from_str("1").unwrap()
  let big = Decimal::from_str("20000000000000000000").unwrap()
  let bigger = Decimal::from_str("30000000000000000000").unwrap()
  let tiny = Decimal::from_str("0.0000000000000000000000000001").unwrap()
  inspect(small.compare(big), content="-1")
  inspect(big.compare(small), content="1")
  inspect(small.neg().compare(big.neg()), content="1")
  inspect(big.neg().compare(small.neg()), content="-1")
  inspect(bigger.compare(tiny), content="1")
  inspect(tiny.compare(bigger), content="-1")
  inspect(big.compare(big), content="0")
  inspect(compare(Decimal(small), Decimal(bigger)), content="-1")
  inspect(compare(Int(1L), Decimal(big)), content="-1")
  inspect(compare(Decimal(big), Int(1L)), content="1")
  let span = @syntax.Span::detached()
  let values : Array[@syntax.Spanned[Value]] = [
    { v: Decimal(big), span, },
    { v: Decimal(small), span, },
    { v: Decimal(bigger), span, },
    { v: Decimal(tiny), span, },
  ]
  inspect(
    impl_calc_max(span, values).repr(),
    content="decimal(\"30000000000000000000\")",
  )
  inspect(
    impl_calc_min(span, values).repr(),
    content="decimal(\"0.0000000000000000000000000001\")",
  )
}
