// Port of skrifa 0.42.1 `src/outline/glyf/hint/math.rs` and the dot
// product helper from `projection.rs`.

///|
fn hfloor(x : Int) -> Int {
  x & -64
}

///|
fn hround(x : Int) -> Int {
  hfloor(x + 32)
}

///|
fn hceil(x : Int) -> Int {
  hfloor(x + 63)
}

///|
fn floor_pad(x : Int, n : Int) -> Int {
  x & -n
}

///|
fn round_pad(x : Int, n : Int) -> Int {
  floor_pad(x + n / 2, n)
}

///|
fn hmul(a : Int, b : Int) -> Int {
  (Fixed::from_bits(a) * Fixed::from_bits(b)).to_bits()
}

///|
fn hdiv(a : Int, b : Int) -> Int {
  (Fixed::from_bits(a) / Fixed::from_bits(b)).to_bits()
}

///|
/// Fixed point multiply and divide: a * b / c
fn hmul_div(a : Int, b : Int, c : Int) -> Int {
  Fixed::from_bits(a)
  .mul_div(Fixed::from_bits(b), Fixed::from_bits(c))
  .to_bits()
}

///|
/// Fixed point multiply and divide without rounding: a * b / c
fn mul_div_no_round(a : Int, b : Int, c : Int) -> Int {
  let mut a = a
  let mut b = b
  let mut c = c
  let mut s = 1
  if a < 0 {
    a = -a
    s = -1
  }
  if b < 0 {
    b = -b
    s = -s
  }
  if c < 0 {
    c = -c
    s = -s
  }
  let d = if c > 0 {
    a.to_int64() * b.to_int64() / c.to_int64()
  } else {
    0x7FFFFFFFL
  }
  if s < 0 {
    -d.to_int()
  } else {
    d.to_int()
  }
}

///|
/// Multiplication for 2.14 fixed point.
fn mul14(a : Int, b : Int) -> Int {
  let mut v = a.to_int64() * b.to_int64()
  v = v + 0x2000L + (v >> 63)
  (v >> 14).to_int()
}

///|
/// Dot product for vectors in 2.14 fixed point.
fn dot14(ax : Int, ay : Int, bx : Int, by : Int) -> Int {
  let mut v1 = ax.to_int64() * bx.to_int64()
  let v2 = ay.to_int64() * by.to_int64()
  v1 = v1 + v2
  v1 = v1 + 0x2000L + (v1 >> 63)
  (v1 >> 14).to_int()
}

///|
/// Wrapping i32 division (`Wrapping<i32> / Wrapping<i32>`).
fn wdiv(a : Int, b : Int) -> Int {
  if b == -1 {
    -a
  } else {
    a / b
  }
}

///|
/// Normalize a vector in 2.14 fixed point.
///
/// Direct port of FreeType's `FT_Vector_NormLen`.
fn normalize14(x : Int, y : Int) -> (Int, Int) {
  let mut sx = 1
  let mut sy = 1
  let mut ux = x.reinterpret_as_uint()
  let mut uy = y.reinterpret_as_uint()
  let mut rx = 0
  let mut ry = 0
  if x < 0 {
    ux = 0U - ux
    sx = -sx
  }
  if y < 0 {
    uy = 0U - uy
    sy = -sy
  }
  if ux == 0U {
    rx = x / 4
    if uy > 0U {
      ry = wdiv(sy * 0x10000, 4)
    }
    return (rx, ry)
  }
  if uy == 0U {
    ry = y / 4
    if ux > 0U {
      rx = wdiv(sx * 0x10000, 4)
    }
    return (rx, ry)
  }
  let mut len = if ux > uy { ux + (uy >> 1) } else { uy + (ux >> 1) }
  let mut shift = len.clz()
  shift = shift -
    (15 + (if len >= 0xAAAAAAAAU >> (shift & 31) { 1 } else { 0 }))
  if shift > 0 {
    let s = shift & 31
    ux = ux << s
    uy = uy << s
    len = if ux > uy { ux + (uy >> 1) } else { uy + (ux >> 1) }
  } else {
    let s = -shift & 31
    ux = ux >> s
    uy = uy >> s
    len = len >> s
  }
  let mut b = 0x10000 - len.reinterpret_as_int()
  let x = ux.reinterpret_as_int()
  let y = uy.reinterpret_as_int()
  let mut u = 0U
  let mut v = 0U
  while true {
    u = (x + ((x * b) >> 16)).reinterpret_as_uint()
    v = (y + ((y * b) >> 16)).reinterpret_as_uint()
    let mut z = wdiv(-(u * u + v * v).reinterpret_as_int(), 0x200)
    z = wdiv(z * ((0x10000 + b) >> 8), 0x10000)
    b = b + z
    if z <= 0 {
      break
    }
  }
  (wdiv(u.reinterpret_as_int() * sx, 4), wdiv(v.reinterpret_as_int() * sy, 4))
}
