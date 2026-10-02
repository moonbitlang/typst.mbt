// Port of `hayro-interpret/src/function/type2.rs`.

///|
/// A type 2 function (exponential function).
priv struct Type2 {
  c0 : Array[Float]
  c1 : Array[Float]
  clamper : Clamper
  n : Float
}

///|
/// Create a new type 2 function.
fn Type2::new(dict : @hayro_syntax.Dict) -> Type2? {
  let c0 = get_values(dict, "C0").unwrap_or([0.0])
  let c1 = get_values(dict, "C1").unwrap_or([1.0])
  guard Clamper::new(dict) is Some(clamper) else { return None }
  guard (dict.get("N") : @hayro_syntax.Number?) is Some(n) else { return None }
  let n = Float::from_double(n.as_f64())
  Some({ c0, c1, clamper, n, })
}

///|
/// Evaluate the function with the given input.
fn Type2::eval(self : Type2, input : Float) -> Array[Float] {
  let input = [input]
  self.clamper.clamp_input(input)
  let out = []
  let len = @cmp.minimum(self.c0.length(), self.c1.length())
  for i in 0..<len {
    let c0 = self.c0[i]
    let c1 = self.c1[i]
    out.push(c0 + powf(input[0], self.n) * (c1 - c0))
  }
  self.clamper.clamp_output(out)
  out
}
