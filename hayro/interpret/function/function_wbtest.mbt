// Ports of the unit tests of `hayro-interpret/src/function/{type2,type3,type4}.rs`.

///|
fn obj(s : String) -> @hayro_syntax.Object {
  let arr = []
  for c in s {
    arr.push(c.to_int().to_byte())
  }
  (@hayro_syntax.from_bytes(Bytes::from_array(arr)) : @hayro_syntax.Object?).unwrap()
}

// type2.rs

///|
test "type2 simple" {
  let func = Function::new(
    obj(
      (
        #|<<
        #|  /FunctionType 2
        #|  /Domain [ 0  1 ]
        #|  /C0 [ 0 20  ]
        #|  /C1 [ 30 -50 ]
        #|  /N 1
        #|>>
      ),
    ),
  ).unwrap()
  assert_eq(func.eval([0.0]).unwrap(), [0.0, 20.0])
  assert_eq(func.eval([0.5]).unwrap(), [15.0, -15.0])
  assert_eq(func.eval([1.0]).unwrap(), [30.0, -50.0])
}

///|
test "type2 with_exponent" {
  let func = Function::new(
    obj(
      (
        #|<<
        #|  /FunctionType 2
        #|  /Domain [ 0  1 ]
        #|  /C0 [ 0  ]
        #|  /C1 [ 30 ]
        #|  /N 2
        #|>>
      ),
    ),
  ).unwrap()
  assert_eq(func.eval([0.5]), Some([7.5]))
}

///|
test "type2 clamp_domain" {
  let func = Function::new(
    obj(
      (
        #|<<
        #|  /FunctionType 2
        #|  /Domain [ 0.2  0.8 ]
        #|  /C0 [ 0  ]
        #|  /C1 [ 30 ]
        #|  /N 2
        #|>>
      ),
    ),
  ).unwrap()
  assert_eq(func.eval([0.0]), func.eval([0.2]))
  assert_eq(func.eval([-10.0]), func.eval([0.2]))
  assert_eq(func.eval([0.8]), func.eval([0.8]))
  assert_eq(func.eval([1.2]), func.eval([1.0]))
}

///|
test "type2 clamp_range" {
  let func = Function::new(
    obj(
      (
        #|<<
        #|  /FunctionType 2
        #|  /Domain [ 0.0  1.0 ]
        #|  /Range [10.0 20.0]
        #|  /C0 [ 0  ]
        #|  /C1 [ 30 ]
        #|  /N 1
        #|>>
      ),
    ),
  ).unwrap()
  assert_eq(func.eval([0.0]), Some([10.0]))
  assert_eq(func.eval([0.5]), Some([15.0]))
  assert_eq(func.eval([1.0]), Some([20.0]))
}

// type3.rs

///|
test "type3 simple" {
  let function = Function::new(
    obj(
      (
        #|<<
        #|  /FunctionType 3
        #|  /Domain [-7 7]
        #|  /Functions [
        #|    << /FunctionType 2
        #|       /Domain [0 1]
        #|       /C0 [0.5 0.5 0.5]
        #|       /C1 [0.5 0.5 0.5]
        #|       /N 1
        #|    >>
        #|    << /FunctionType 2
        #|       /Domain [0 1]
        #|       /C0 [0.7 0.7 0.7]
        #|       /C1 [0.7 0.7 0.7]
        #|       /N 1
        #|    >>
        #|  ]
        #|  /Bounds [0]
        #|  /Encode [0 1 0 1]
        #|>>
      ),
    ),
  ).unwrap()
  assert_eq(function.eval([-7.0]).unwrap(), [0.5, 0.5, 0.5])
  assert_eq(function.eval([-3.0]).unwrap(), [0.5, 0.5, 0.5])
  assert_eq(function.eval([-0.5]).unwrap(), [0.5, 0.5, 0.5])
  assert_eq(function.eval([0.0]).unwrap(), [0.7, 0.7, 0.7])
  assert_eq(function.eval([7.0]).unwrap(), [0.7, 0.7, 0.7])
  assert_eq(function.stitching_bounds(), [0.0])
}

// type4.rs

///|
test "lex_1" {
  let parsed = parse_procedure(b"{ copy dup 2.0 exch roll }").unwrap()
  assert_eq(parsed, [
    Copy,
    Dup,
    Number(@hayro_syntax.Number::from_f32(2.0)),
    Exch,
    Roll,
  ])
}

///|
test "lex_3" {
  let parsed = parse_procedure(b" {  {dup exch} if {0} {1} ifelse }").unwrap()
  assert_eq(parsed, [
    If([Dup, Exch]),
    IfElse([Number(@hayro_syntax.Number::from_i32(0))], [
      Number(@hayro_syntax.Number::from_i32(1)),
    ]),
  ])
}

///|
fn op_impl(prog : String, out : Array[Float]) -> Unit raise {
  let procedure = "{" + prog + "}"
  let arr = []
  for c in procedure {
    arr.push(c.to_int().to_byte())
  }
  let procedure = parse_procedure(Bytes::from_array(arr)).unwrap()
  let type4 : Type4 = {
    program: procedure,
    clamper: { domain: [], range: None, },
  }
  let res = type4.eval([]).unwrap()
  assert_eq(res, out)
}

///|
test "op_abs" {
  op_impl("4.5 abs", [4.5])
  op_impl("-3 abs", [3.0])
  op_impl("0 abs", [0.0])
}

///|
test "op_atan" {
  op_impl("0 1 atan", [0.0])
  op_impl("1 0 atan", [90.0])
  op_impl("-100 0 atan", [270.0])
  op_impl("4 4 atan", [45.0])
}

///|
test "op_ceiling" {
  op_impl("3.2 ceiling", [4.0])
  op_impl("-4.8 ceiling", [-4.0])
  op_impl("99 ceiling", [99.0])
}

///|
test "op_cos" {
  op_impl("0 cos", [1.0])
  // Should be zero, but floating point impreciseness.
  op_impl("90 cos", [-4.371139e-8])
}

///|
test "op_cvi" {
  op_impl("-47.8 cvi", [-47.0])
  op_impl("520.9 cvi", [520.0])
}

///|
test "op_cvr" {
  op_impl("-47.8 cvr", [-47.8])
  op_impl("520 cvr", [520.0])
}

///|
test "op_div" {
  op_impl("3 2 div", [1.5])
  op_impl("4 2 div", [2.0])
}

///|
test "op_exp" {
  op_impl("9 0.5 exp", [3.0])
  op_impl("-9 -1 exp", [-0.11111111])
}

///|
test "op_floor" {
  op_impl("3.2 floor", [3.0])
  op_impl("-4.8 floor", [-5.0])
  op_impl("99 floor", [99.0])
}

///|
test "op_idiv" {
  op_impl("3 2 idiv", [1.0])
  op_impl("4 2 idiv", [2.0])
  op_impl("-5 2 idiv", [-2.0])
}

///|
test "op_ln" {
  op_impl("10 ln", [Float::from_double(@math.ln(10.0))])
  op_impl("100 ln", [4.6051702])
}

///|
test "op_log" {
  op_impl("10 log", [1.0])
  op_impl("100 log", [2.0])
}

///|
test "op_mod" {
  op_impl("5 3 mod", [2.0])
  op_impl("5 2 mod", [1.0])
  op_impl("-5 3 mod", [-2.0])
}

///|
test "op_mul" {
  op_impl("5 3 mul", [15.0])
  op_impl("-2 6 mul", [-12.0])
}

///|
test "op_neg" {
  op_impl("4.5 neg", [-4.5])
  op_impl("-3 neg", [3.0])
}

///|
test "op_round" {
  op_impl("3.2 round", [3.0])
  op_impl("6.5 round", [7.0])
  op_impl("-4.8 round", [-5.0])
  // TODO: This rounding doesn't match the PS spec.
  // op_impl("-6.5 round", [-6.0])
  op_impl("99 round", [99.0])
}

///|
test "op_sin" {
  op_impl("0.0 sin", [0.0])
  op_impl("90.0 sin", [1.0])
}

///|
test "op_sqrt" {
  op_impl("100 sqrt", [10.0])
}

///|
test "op_sub" {
  op_impl("3 4 sub", [-1.0])
  op_impl("6 0 sub", [6.0])
}

///|
test "op_truncate" {
  op_impl("3.2 truncate", [3.0])
  op_impl("-4.8 truncate", [-4.0])
  op_impl("99 truncate", [99.0])
}

///|
test "op_and" {
  op_impl("true true and", [1.0])
  op_impl("true false and", [0.0])
  op_impl("false true and", [0.0])
  op_impl("false false and", [0.0])
  op_impl("99 1 and", [1.0])
  op_impl("52 7 and", [4.0])
}

///|
test "op_bitshift" {
  op_impl("7 3 bitshift", [56.0])
  op_impl("142 -3 bitshift", [17.0])
}

///|
test "op_eq" {
  op_impl("4.0 4 eq", [1.0])
  op_impl("-2.0 -3 eq", [0.0])
}

///|
test "op_false" {
  op_impl("false", [0.0])
}

///|
test "op_ge" {
  op_impl("4.2 4 ge", [1.0])
  op_impl("4.2 4.2 ge", [1.0])
  op_impl("4.2 6 ge", [0.0])
}

///|
test "op_gt" {
  op_impl("4.2 4 gt", [1.0])
  op_impl("4.2 4.2 gt", [0.0])
  op_impl("4.2 6 gt", [0.0])
}

///|
test "op_le" {
  op_impl("4.2 4 le", [0.0])
  op_impl("4.2 4.2 le", [1.0])
  op_impl("4.2 6 le", [1.0])
}

///|
test "op_lt" {
  op_impl("4.2 4 lt", [0.0])
  op_impl("4.2 4.2 lt", [0.0])
  op_impl("4.2 6 lt", [1.0])
}

///|
test "op_ne" {
  op_impl("3.0 3 ne", [0.0])
  op_impl("3.0 3.0 ne", [0.0])
  op_impl("3.0 3.1 ne", [1.0])
}

///|
test "op_not" {
  op_impl("true not", [0.0])
  op_impl("false not", [1.0])
  op_impl("52 not", [-53.0])
}

///|
test "op_or" {
  op_impl("true true or", [1.0])
  op_impl("true false or", [1.0])
  op_impl("false true or", [1.0])
  op_impl("false false or", [0.0])
  op_impl("17 5 or", [21.0])
}

///|
test "op_xor" {
  op_impl("true true xor", [0.0])
  op_impl("true false xor", [1.0])
  op_impl("false true xor", [1.0])
  op_impl("false false xor", [0.0])
  op_impl("7 3 xor", [4.0])
  op_impl("12 3 xor", [15.0])
}

///|
test "op_if" {
  op_impl("true { 1.0 } if", [1.0])
  op_impl("false { 1.0 } if", [])
}

///|
test "op_ifelse" {
  op_impl("true { 1.0 } { 2.0 } ifelse", [1.0])
  op_impl("false { 1.0 } { 2.0 } ifelse", [2.0])
}

///|
test "op_copy" {
  op_impl("1 2 3 2 copy", [1.0, 2.0, 3.0, 2.0, 3.0])
  op_impl("1 2 3 0 copy", [1.0, 2.0, 3.0])
}

///|
test "op_dup" {
  op_impl("1 2 3 dup", [1.0, 2.0, 3.0, 3.0])
}

///|
test "op_exch" {
  op_impl("1 2 3 exch", [1.0, 3.0, 2.0])
}

///|
test "op_index" {
  op_impl("1 2 3 4 0 index", [1.0, 2.0, 3.0, 4.0, 4.0])
  op_impl("1 2 3 4 3 index", [1.0, 2.0, 3.0, 4.0, 1.0])
}

///|
test "op_pop" {
  op_impl("1 2 3 pop", [1.0, 2.0])
}

///|
test "op_roll" {
  op_impl("1 2 3 3 -1 roll", [2.0, 3.0, 1.0])
  op_impl("1 2 3 3 1 roll", [3.0, 1.0, 2.0])
  op_impl("1 2 3 3 0 roll", [1.0, 2.0, 3.0])
  op_impl("1 2 3 3 5 roll", [2.0, 3.0, 1.0])
  op_impl("0 2 roll", [])
  op_impl("1 2 3 4 5 6 7 5 2 roll", [1.0, 2.0, 6.0, 7.0, 3.0, 4.0, 5.0])
}

///|
test "domain" {
  let procedure = parse_procedure(b"{  }").unwrap()
  let type4 = Function::{
    inner: Type4({
      program: procedure,
      clamper: { domain: [(-5.0, 5.0), (-5.0, 5.0), (-5.0, 5.0)], range: None, },
    }),
  }
  let res = type4.eval([-10.0, -2.0, 6.0]).unwrap()
  assert_eq(res, [-5.0, -2.0, 5.0])
}

///|
test "float constants" {
  // `0.0001_f32`, `f32::EPSILON`.
  assert_eq((0.0001 : Float).reinterpret_as_uint(), 0x38D1B717)
  assert_eq(f32_epsilon, Float::from_double(1.1920928955078125e-7))
  assert_eq(f32_min(0.0, -0.0).reinterpret_as_uint(), 0x80000000)
  assert_eq(f32_max(-0.0, 0.0).reinterpret_as_uint(), 0)
  assert_eq(f32_min(@float.not_a_number, 1.0), 1.0)
  assert_eq(f32_round(-0.5), -1.0)
  assert_eq(f32_round(2.5), 3.0)
  assert_eq(f32_to_u32(-3.0), 0)
  assert_eq(f32_to_i32(3.0e10), 2147483647)
}
