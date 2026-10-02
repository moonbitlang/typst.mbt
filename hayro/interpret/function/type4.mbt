// Port of `hayro-interpret/src/function/type4.rs`.

///|
/// A type 4 function (postscript function).
priv struct Type4 {
  program : Array[PostScriptOp]
  clamper : Clamper
}

///|
/// Create a new type 4 function.
fn Type4::new(stream : @hayro_syntax.Stream) -> Type4? {
  let dict = stream.dict()
  guard Clamper::new(dict) is Some(clamper) else { return None }
  guard stream.decoded() is Ok(decoded) else { return None }
  guard parse_procedure(decoded) is Some(program) else { return None }
  Some({ clamper, program, })
}

///|
/// Evaluate the function with the given input.
fn Type4::eval(self : Type4, input : Array[Float]) -> Array[Float]? {
  self.clamper.clamp_input(input)
  let arg_stack = ArgumentsStack::new(64)
  for input in input {
    arg_stack.push(Float(input)) |> ignore
  }
  guard eval_inner(self.program, arg_stack) is Some(_) else { return None }
  let out = arg_stack.items().map(i => i.as_f32())
  self.clamper.clamp_output(out)
  Some(out)
}

///|
priv enum Argument {
  Float(Float)
  Bool(Bool)
}

///|
fn Argument::as_bool(self : Argument) -> Bool {
  match self {
    Float(f) => f != 0.0
    Bool(b) => b
  }
}

///|
fn Argument::as_f32(self : Argument) -> Float {
  match self {
    Float(f) => f
    Bool(b) => if b { 1.0 } else { 0.0 }
  }
}

///|
/// A stack with a fixed capacity.
priv struct ArgumentsStack[T] {
  stack : Array[T]
  capacity : Int
}

///|
fn[T] ArgumentsStack::new(capacity : Int) -> ArgumentsStack[T] {
  { stack: [], capacity, }
}

///|
fn[T] ArgumentsStack::len(self : ArgumentsStack[T]) -> Int {
  self.stack.length()
}

///|
fn[T] ArgumentsStack::push(self : ArgumentsStack[T], n : T) -> Unit? {
  if self.stack.length() == self.capacity {
    // overflowed post script argument stack
    None
  } else {
    self.stack.push(n)
    Some(())
  }
}

///|
fn[T] ArgumentsStack::at(self : ArgumentsStack[T], index : Int) -> T? {
  self.stack.get(index)
}

///|
fn[T] ArgumentsStack::last(self : ArgumentsStack[T]) -> T? {
  self.stack.last()
}

///|
fn[T] ArgumentsStack::pop(self : ArgumentsStack[T]) -> T? {
  // (An error is logged upstream on underflow.)
  self.stack.pop()
}

///|
fn[T] ArgumentsStack::items(self : ArgumentsStack[T]) -> Array[T] {
  self.stack
}

///|
fn bf(cond : Bool) -> Float {
  if cond {
    1.0
  } else {
    0.0
  }
}

///|
fn eval_inner(
  procedure : Array[PostScriptOp],
  arg_stack : ArgumentsStack[Argument],
) -> Unit? {
  fn one_f(eval : (Float) -> Float) -> Unit? {
    guard arg_stack.pop() is Some(n1) else { return None }
    arg_stack.push(Float(eval(n1.as_f32()))) |> ignore
    Some(())
  }

  fn two_f(eval : (Float, Float) -> Float) -> Unit? {
    guard arg_stack.pop() is Some(n2) else { return None }
    guard arg_stack.pop() is Some(n1) else { return None }
    arg_stack.push(Float(eval(n1.as_f32(), n2.as_f32()))) |> ignore
    Some(())
  }

  fn four(
    eval_f : (Float, Float) -> Float,
    eval_b : (Bool, Bool) -> Bool,
  ) -> Unit? {
    guard arg_stack.pop() is Some(n2) else { return None }
    guard arg_stack.pop() is Some(n1) else { return None }
    let res : Argument = match (n1, n2) {
      (Float(f1), Float(f2)) => Float(eval_f(f1, f2))
      (Float(_), Bool(f2)) => Bool(eval_b(n1.as_bool(), f2))
      (Bool(f1), Float(_)) => Bool(eval_b(f1, n2.as_bool()))
      (Bool(f1), Bool(f2)) => Bool(eval_b(f1, f2))
    }
    arg_stack.push(res) |> ignore
    Some(())
  }

  for op in procedure {
    let res : Unit? = match op {
      Number(n) => arg_stack.push(Float(Float::from_double(n.as_f64())))
      Abs => one_f(n => n.abs())
      Add => two_f((n1, n2) => n1 + n2)
      Atan =>
        two_f((n1, n2) => {
          let mut res = fmodf(f32_to_degrees(atan2f(n1, n2)), 360.0)
          if res < 0.0 {
            res += 360.0
          }
          res
        })
      Ceiling => one_f(n => n.ceil())
      Cos => one_f(n => cosf(f32_to_radians(n)))
      Cvi => one_f(n => n.trunc())
      Cvr => one_f(n => n)
      Div => two_f((n1, n2) => n1 / n2)
      Exp => two_f((n1, n2) => powf(n1, n2))
      Floor => one_f(n => n.floor())
      Idiv => {
        guard arg_stack.pop() is Some(n2) else { return None }
        guard arg_stack.pop() is Some(n1) else { return None }
        let n1 = f32_to_i32(n1.as_f32())
        let n2 = f32_to_i32(n2.as_f32())
        // Upstream panics on a division by zero or overflow; fail instead.
        if n2 == 0 || (n1 == -2147483648 && n2 == -1) {
          return None
        }
        arg_stack.push(Float(Float::from_int(n1 / n2))) |> ignore
        Some(())
      }
      Ln => one_f(n => logf(n))
      Log => one_f(n => log10f(n))
      Mod => two_f((n1, n2) => fmodf(n1, n2))
      Mul => two_f((n1, n2) => n1 * n2)
      Neg => one_f(n => -n)
      Round => one_f(n => f32_round(n))
      Sin => one_f(n => sinf(f32_to_radians(n)))
      Sqrt => one_f(n => n.sqrt())
      Sub => two_f((n1, n2) => n1 - n2)
      Truncate => one_f(n => n.trunc())
      And => two_f((n1, n2) => Float::from_int(f32_to_i32(n1) & f32_to_i32(n2)))
      Bitshift =>
        two_f((n1, n2) => {
          let num = f32_to_u32(n1)
          let shift = f32_to_i32(n2)
          // Shift amounts are masked like Rust's release-mode `<<`/`>>`.
          if shift >= 0 {
            Float::from_uint(num << (shift & 31))
          } else {
            Float::from_uint(num >> ((0 - shift) & 31))
          }
        })
      Eq => two_f((n1, n2) => bf(n1 == n2))
      False => {
        arg_stack.push(Bool(false)) |> ignore
        Some(())
      }
      Ge => two_f((n1, n2) => bf(n1 >= n2))
      Gt => two_f((n1, n2) => bf(n1 > n2))
      Le => two_f((n1, n2) => bf(n1 <= n2))
      Lt => two_f((n1, n2) => bf(n1 < n2))
      Ne => two_f((n1, n2) => bf(n1 != n2))
      Not => {
        guard arg_stack.pop() is Some(arg) else { return None }
        let res : Argument = match arg {
          Float(f) => Float(Float::from_int(f32_to_i32(f).lnot()))
          Bool(b) => Bool(!b)
        }
        arg_stack.push(res) |> ignore
        Some(())
      }
      Or =>
        four((n1, n2) => Float::from_int(f32_to_i32(n1) | f32_to_i32(n2)), (
          b1,
          b2,
        ) => b1 || b2)
      True => {
        arg_stack.push(Bool(true)) |> ignore
        Some(())
      }
      Xor =>
        four((n1, n2) => Float::from_int(f32_to_i32(n1) ^ f32_to_i32(n2)), (
          b1,
          b2,
        ) => b1 != b2)
      If(p) => {
        guard arg_stack.pop() is Some(cond) else { return None }
        if cond.as_bool() {
          eval_inner(p, arg_stack)
        } else {
          Some(())
        }
      }
      IfElse(p1, p2) => {
        guard arg_stack.pop() is Some(cond) else { return None }
        if cond.as_bool() {
          eval_inner(p1, arg_stack)
        } else {
          eval_inner(p2, arg_stack)
        }
      }
      Copy => {
        guard arg_stack.pop() is Some(n) else { return None }
        let n = f32_to_u32(n.as_f32()).to_uint64()
        let len = arg_stack.len()
        guard n <= len.to_uint64() else { return None }
        let start = len - n.to_int()
        for i in start..<len {
          guard arg_stack.at(i) is Some(v) else { return None }
          arg_stack.push(v) |> ignore
        }
        Some(())
      }
      Dup => {
        guard arg_stack.last() is Some(v) else { return None }
        arg_stack.push(v) |> ignore
        Some(())
      }
      Exch => {
        guard arg_stack.pop() is Some(n2) else { return None }
        guard arg_stack.pop() is Some(n1) else { return None }
        arg_stack.push(n2) |> ignore
        arg_stack.push(n1) |> ignore
        Some(())
      }
      Index => {
        guard arg_stack.pop() is Some(n) else { return None }
        let n = f32_to_u32(n.as_f32()).to_uint64()
        let len = arg_stack.len().to_uint64()
        guard n + 1UL <= len else { return None }
        guard arg_stack.at((len - (n + 1UL)).to_int()) is Some(v) else {
          return None
        }
        arg_stack.push(v) |> ignore
        Some(())
      }
      Pop => {
        guard arg_stack.pop() is Some(_) else { return None }
        Some(())
      }
      Roll => {
        guard arg_stack.pop() is Some(j) else { return None }
        let j = f32_to_i32(j.as_f32())
        guard arg_stack.pop() is Some(n) else { return None }
        let n = f32_to_u32(n.as_f32()).to_uint64()
        let len = arg_stack.len()
        guard n <= len.to_uint64() else { return None }
        let trimmed_n = len - n.to_int()
        let target_len = len - trimmed_n
        if target_len > 0 {
          let items = arg_stack.items()
          let target = items[trimmed_n:].to_owned()
          let shift = if j >= 0 {
            j.to_uint64() % target_len.to_uint64()
          } else {
            // `(-j) as usize` (with `i32` wrapping negation).
            (0 - j).to_int64().reinterpret_as_uint64() % target_len.to_uint64()
          }
          let shift = shift.to_int()
          for k in 0..<target_len {
            // `rotate_right(shift)` moves element `k` to `k + shift`;
            // `rotate_left(shift)` moves it to `k - shift`.
            let dst = if j >= 0 {
              (k + shift) % target_len
            } else {
              (k - shift + target_len) % target_len
            }
            items[trimmed_n + dst] = target[k]
          }
        }
        Some(())
      }
    }
    guard res is Some(_) else { return None }
  }
  Some(())
}

///|
fn parse_procedure(data : BytesView) -> Array[PostScriptOp]? {
  let r = @hayro_syntax.Reader::new(data)
  parse_procedure_inner(r)
}

///|
fn parse_procedure_inner(r : @hayro_syntax.Reader) -> Array[PostScriptOp]? {
  let stack : ArgumentsStack[Array[PostScriptOp]] = ArgumentsStack::new(2)
  let ops = []
  r.skip_white_spaces_and_comments()
  guard r.forward_tag(b"{") is Some(_) else { return None }
  while true {
    r.skip_white_spaces_and_comments()
    guard r.peek_byte() is Some(b) else { return None }
    if b == b'}' {
      guard r.forward_tag(b"}") is Some(_) else { return None }
      break
    } else if b == b'{' {
      guard parse_procedure_inner(r) is Some(p) else { return None }
      stack.push(p) |> ignore
    } else {
      guard PostScriptOp::from_reader(r, stack) is Some(op) else { return None }
      ops.push(op)
    }
  }
  Some(ops)
}

///|
priv enum PostScriptOp {
  Number(@hayro_syntax.Number)
  Abs
  Add
  Atan
  Ceiling
  Cos
  Cvi
  Cvr
  Div
  Exp
  Floor
  Idiv
  Ln
  Log
  Mod
  Mul
  Neg
  Round
  Sin
  Sqrt
  Sub
  Truncate
  And
  Bitshift
  Eq
  False
  Ge
  Gt
  Le
  Lt
  Ne
  Not
  Or
  True
  Xor
  If(Array[PostScriptOp])
  IfElse(Array[PostScriptOp], Array[PostScriptOp])
  Copy
  Dup
  Exch
  Index
  Pop
  Roll
} derive(Eq, Debug)

///|
/// `r.read::<content::Operator>()`.
fn read_operator(r : @hayro_syntax.Reader) -> @hayro_syntax.Name? {
  let old = r.offset()
  let start = r.offset()
  guard @hayro_syntax.skip_name_like(r, false) is Some(_) else {
    r.jump(old)
    return None
  }
  let end = r.offset()
  guard r.range(start, end) is Some(data) && data.length() > 0 else {
    r.jump(old)
    return None
  }
  guard @hayro_syntax.Name::new(data) is Some(name) else {
    r.jump(old)
    return None
  }
  Some(name)
}

///|
fn PostScriptOp::from_reader(
  r : @hayro_syntax.Reader,
  stack : ArgumentsStack[Array[PostScriptOp]],
) -> PostScriptOp? {
  let ctx = @hayro_syntax.ReaderContext::dummy()
  if (r.read(ctx) : @hayro_syntax.Number?) is Some(n) {
    // TODO: Support radix numbers
    return Some(Number(n))
  }
  guard read_operator(r) is Some(op) else { return None }
  let op : PostScriptOp = match op.raw() {
    "abs" => Abs
    "add" => Add
    "atan" => Atan
    "ceiling" => Ceiling
    "cos" => Cos
    "cvi" => Cvi
    "cvr" => Cvr
    "div" => Div
    "exp" => Exp
    "floor" => Floor
    "idiv" => Idiv
    "ln" => Ln
    "log" => Log
    "mod" => Mod
    "mul" => Mul
    "neg" => Neg
    "round" => Round
    "sin" => Sin
    "sqrt" => Sqrt
    "sub" => Sub
    "truncate" => Truncate
    "and" => And
    "bitshift" => Bitshift
    "eq" => Eq
    "false" => False
    "ge" => Ge
    "gt" => Gt
    "le" => Le
    "lt" => Lt
    "ne" => Ne
    "not" => Not
    "or" => Or
    "true" => True
    "xor" => Xor
    "if" => {
      guard stack.pop() is Some(p) else { return None }
      If(p)
    }
    "ifelse" => {
      guard stack.pop() is Some(s) else { return None }
      guard stack.pop() is Some(f) else { return None }
      IfElse(f, s)
    }
    "copy" => Copy
    "dup" => Dup
    "exch" => Exch
    "index" => Index
    "pop" => Pop
    "roll" => Roll
    _ =>
      // encountered unknown postscript operator
      return None
  }
  Some(op)
}
