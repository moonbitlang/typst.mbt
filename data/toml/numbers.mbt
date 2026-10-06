// `toml_edit::parser::numbers`.

///|
/// `true_`: `(peek(b't'), cut_err("true"))`
fn true_(i : Input) -> Bool raise ErrMode {
  ignore(peek(i, i => one_of(i, b => b == 't')))
  cut_err(i, i => literal(i, "true"))
  true
}

///|
/// `false_`: `(peek(b'f'), cut_err("false"))`
fn false_(i : Input) -> Bool raise ErrMode {
  ignore(peek(i, i => one_of(i, b => b == 'f')))
  cut_err(i, i => literal(i, "false"))
  false
}

///|
/// `integer = dec-int / hex-int / oct-int / bin-int`
fn integer(i : Input) -> Int64 raise ErrMode {
  let prefix = if i.byte_at(0) >= 0 && i.byte_at(1) >= 0 {
    Some((i.byte_at(0), i.byte_at(1)))
  } else {
    None
  }
  match prefix {
    Some(('0', 'x')) => cut_err(i, i => radix_int(i, hex_int, 16))
    Some(('0', 'o')) => cut_err(i, i => radix_int(i, oct_int, 8))
    Some(('0', 'b')) => cut_err(i, i => radix_int(i, bin_int, 2))
    _ => {
      let start = i.pos
      let s = dec_int(i)
      // `and_then(cut_err(rest.try_map(..)))`: on failure the input is reset
      // to the start of the integer.
      match parse_i64(s, 10) {
        Ok(v) => v
        Err(cause) => {
          i.pos = start
          raise Cut(ContextError::external(cause))
        }
      }
    }
  }
}

///|
/// `<radix>_int.try_map(|s| i64::from_str_radix(&s.replace('_', ""), radix))`
fn radix_int(
  i : Input,
  p : (Input) -> String raise ErrMode,
  radix : Int,
) -> Int64 raise ErrMode {
  let start = i.pos
  let s = p(i)
  match parse_i64(s, radix) {
    Ok(v) => v
    Err(cause) => raise map_failure(i, start, Some(cause))
  }
}

///|
/// `i64::from_str_radix(&s.replace('_', ""), radix)` for the digit strings
/// the grammar admits (optional sign, digits and underscores); the error is
/// the `Display` of `ParseIntError`.
fn parse_i64(s : String, radix : Int) -> Result[Int64, String] {
  let mut negative = false
  let mut k = 0
  if s.length() > 0 && (s[0] == '+' || s[0] == '-') {
    negative = s[0] == '-'
    k = 1
  }
  let mut acc = 0L
  let r = radix.to_int64()
  let mut any_digit = false
  for idx in k..<s.length() {
    let c = s[idx].to_int()
    if c == '_' {
      continue
    }
    any_digit = true
    let d = hex_value(c).to_int64()
    if negative {
      // acc * r - d without overflow
      if acc < (-0x7FFF_FFFF_FFFF_FFFFL - 1L + d) / r {
        return Err("number too small to fit in target type")
      }
      acc = acc * r - d
    } else {
      if acc > (0x7FFF_FFFF_FFFF_FFFFL - d) / r {
        return Err("number too large to fit in target type")
      }
      acc = acc * r + d
    }
  }
  if !any_digit {
    return Err("cannot parse integer from empty string")
  }
  Ok(acc)
}

///|
/// `digit-with-underscores` helper: `repeat(0.., alt((digit, ('_',
/// cut_err(digit).context(Expected("digit"))))))` for the given digit set.
fn digits_with_underscores(
  i : Input,
  pred : (Int) -> Bool,
) -> Unit raise ErrMode {
  repeat0(i, i => {
    alt(i, [
      i => ignore(one_of(i, pred)),
      i => {
        byte(i, '_')
        context(i, i => cut_err(i, i => ignore(one_of(i, pred))), [
          Expected(Description("digit")),
        ])
      },
    ])
  })
}

///|
/// `dec-int = [ minus / plus ] unsigned-dec-int`,
/// `unsigned-dec-int = DIGIT / digit1-9 1*( DIGIT / underscore DIGIT )`
fn dec_int(i : Input) -> String raise ErrMode {
  context(
    i,
    i => {
      let start = i.pos
      ignore(opt(i, i => one_of(i, b => b == '+' || b == '-')))
      alt(i, [
        i => {
          ignore(one_of(i, b => b >= '1' && b <= '9'))
          digits_with_underscores(i, is_digit)
        },
        i => ignore(one_of(i, is_digit)),
      ])
      i.slice(start, i.pos)
    },
    [Label("integer")],
  )
}

///|
/// The shared shape of `hex_int`, `oct_int` and `bin_int`.
fn prefixed_int(
  i : Input,
  prefix : String,
  pred : (Int) -> Bool,
  label : String,
) -> String raise ErrMode {
  context(
    i,
    i => {
      literal(i, prefix)
      cut_err(i, i => {
        let start = i.pos
        ignore(one_of(i, pred))
        digits_with_underscores(i, pred)
        i.slice(start, i.pos)
      })
    },
    [Label(label)],
  )
}

///|
/// `hex-int = hex-prefix HEXDIG *( HEXDIG / underscore HEXDIG )`
fn hex_int(i : Input) -> String raise ErrMode {
  prefixed_int(i, "0x", is_hexdig, "hexadecimal integer")
}

///|
/// `oct-int = oct-prefix digit0-7 *( digit0-7 / underscore digit0-7 )`
fn oct_int(i : Input) -> String raise ErrMode {
  prefixed_int(i, "0o", b => b >= '0' && b <= '7', "octal integer")
}

///|
/// `bin-int = bin-prefix digit0-1 *( digit0-1 / underscore digit0-1 )`
fn bin_int(i : Input) -> String raise ErrMode {
  prefixed_int(i, "0b", b => b == '0' || b == '1', "binary integer")
}

///|
/// `float = float-int-part ( exp / frac [ exp ] )`, `float =/ special-float`
fn float(i : Input) -> Double raise ErrMode {
  context(
    i,
    i => {
      alt(i, [
        i => {
          let start = i.pos
          let s = float_(i)
          let f = parse_f64(s)
          // `.verify(|f| *f != f64::INFINITY)` inside `cut_err`, run by
          // `and_then`, which resets the input on failure.
          if f == @double.infinity {
            i.pos = start
            raise Cut(ContextError::new())
          }
          f
        },
        special_float,
      ])
    },
    [Label("floating-point number")],
  )
}

///|
/// `s.replace('_', "").parse::<f64>()` (overflow gives an infinity).
fn parse_f64(s : String) -> Double {
  let s = s.replace_all(old="_", new="")
  @string.parse_double(s) catch {
    _ => if s.has_prefix("-") { @double.neg_infinity } else { @double.infinity }
  }
}

///|
/// `float_`: `dec-int ( exp / frac [ exp ] )`, taken as a string.
fn float_(i : Input) -> String raise ErrMode {
  let start = i.pos
  ignore(dec_int(i))
  alt(i, [
    i => ignore(exp(i)),
    i => {
      frac(i)
      ignore(opt(i, exp))
    },
  ])
  i.slice(start, i.pos)
}

///|
/// `frac = decimal-point zero-prefixable-int`
fn frac(i : Input) -> Unit raise ErrMode {
  byte(i, '.')
  context(i, i => cut_err(i, zero_prefixable_int), [
    Expected(Description("digit")),
  ])
}

///|
/// `zero-prefixable-int = DIGIT *( DIGIT / underscore DIGIT )`
fn zero_prefixable_int(i : Input) -> Unit raise ErrMode {
  ignore(one_of(i, is_digit))
  digits_with_underscores(i, is_digit)
}

///|
/// `exp = "e" float-exp-part`, `float-exp-part = [ minus / plus ]
/// zero-prefixable-int`
fn exp(i : Input) -> Unit raise ErrMode {
  ignore(one_of(i, b => b == 'e' || b == 'E'))
  ignore(opt(i, i => one_of(i, b => b == '+' || b == '-')))
  cut_err(i, zero_prefixable_int)
}

///|
/// `special-float = [ minus / plus ] ( inf / nan )`
fn special_float(i : Input) -> Double raise ErrMode {
  let sign = opt(i, i => one_of(i, b => b == '+' || b == '-'))
  let f = alt(i, [inf, nan])
  match sign {
    Some('-') => -f
    _ => f
  }
}

///|
/// `inf = %x69.6e.66`
fn inf(i : Input) -> Double raise ErrMode {
  literal(i, "inf")
  @double.infinity
}

///|
/// `nan = %x6e.61.6e` (a positive NaN)
fn nan(i : Input) -> Double raise ErrMode {
  literal(i, "nan")
  // `f64::NAN`.
  0x7FF8000000000000L.reinterpret_as_double()
}
