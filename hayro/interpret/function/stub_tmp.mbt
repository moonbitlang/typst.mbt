// TEMPORARY stub of the function package (replaced by the real port).

///|
pub struct Function {
  priv dummy : Int
}

///|
pub fn Function::new(_obj : @hayro_syntax.Object) -> Function? {
  None
}

///|
pub fn Function::eval(_self : Function, _input : Array[Float]) -> Array[Float]? {
  None
}

///|
pub fn Function::stitching_bounds(_self : Function) -> Array[Float] {
  []
}

///|
pub fn interpolate(
  x : Float,
  x_min : Float,
  x_max : Float,
  y_min : Float,
  y_max : Float,
) -> Float {
  y_min + (x - x_min) * (y_max - y_min) / (x_max - x_min)
}
