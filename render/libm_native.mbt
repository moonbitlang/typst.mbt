// C math library functions for bit-identical results with upstream.

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_hypot(x : Double, y : Double) -> Double = "hypot"
