// Port of `hayro-syntax/src/crypto/rc4.rs`.
//
// Ported from <https://github.com/mozilla/pdf.js/blob/master/src/core/crypto.js>.

///|
priv struct Rc4 {
  mut a : Int
  mut b : Int
  s : FixedArray[Int]
}

///|
fn Rc4::new(key : BytesView) -> Rc4 {
  let s : FixedArray[Int] = FixedArray::make(256, 0)
  let key_length = key.length()
  for i in 0..<256 {
    s[i] = i
  }
  let mut j = 0
  for i in 0..<256 {
    let tmp = s[i]
    j = (j + tmp + key[i % key_length].to_int()) & 0xff
    s[i] = s[j]
    s[j] = tmp
  }
  { a: 0, b: 0, s, }
}

///|
fn Rc4::decrypt(self : Rc4, data : BytesView) -> Bytes {
  let n = data.length()
  let output : FixedArray[Byte] = FixedArray::make(n, 0)
  for i in 0..<n {
    self.a = (self.a + 1) & 0xff
    let tmp = self.s[self.a]
    self.b = (self.b + tmp) & 0xff
    let tmp2 = self.s[self.b]
    self.s[self.a] = tmp2
    self.s[self.b] = tmp
    output[i] = data[i] ^ self.s[(tmp + tmp2) & 0xff].to_byte()
  }
  Bytes::from_array(output)
}

///|
fn Rc4::encrypt(self : Rc4, data : BytesView) -> Bytes {
  self.decrypt(data)
}
