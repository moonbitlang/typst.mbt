// Port of rustybuzz 0.20.1 `src/hb/machine_cursor.rs`.

///|
/// Similar to machine_index_t in harfbuzz, but Rust specific.
///
/// A position in `data` that only stops on indices accepted by `pred`.
/// Cursors are values: `add`/`sub` return moved copies.
priv struct MachineCursor[T] {
  data : Array[T]
  pred : (Array[T], Int) -> Bool
  pos : Int
}

///|
fn[T] MachineCursor::new(
  data : Array[T],
  pred : (Array[T], Int) -> Bool,
) -> MachineCursor[T] {
  let mut pos = data.length()
  for i in 0..<data.length() {
    if pred(data, i) {
      pos = i
      break
    }
  }
  { data, pred, pos, }
}

///|
fn[T] MachineCursor::advance1(self : MachineCursor[T]) -> MachineCursor[T] {
  let mut pos = self.data.length()
  for q in (self.pos + 1)..<self.data.length() {
    if (self.pred)(self.data, q) {
      pos = q
      break
    }
  }
  { ..self, pos, }
}

///|
fn[T] MachineCursor::recede1(self : MachineCursor[T]) -> MachineCursor[T] {
  let mut pos = 0
  for q = self.pos - 1; q >= 0; q = q - 1 {
    if (self.pred)(self.data, q) {
      pos = q
      break
    }
  }
  { ..self, pos, }
}

///|
fn[T] MachineCursor::index(self : MachineCursor[T]) -> Int {
  self.pos
}

///|
fn[T] MachineCursor::end(self : MachineCursor[T]) -> MachineCursor[T] {
  { ..self, pos: self.data.length(), }
}

///|
/// `cursor + rhs`
fn[T] MachineCursor::add(
  self : MachineCursor[T],
  rhs : Int,
) -> MachineCursor[T] {
  let mut c = self
  for _ in 0..<rhs {
    c = c.advance1()
  }
  c
}

///|
/// `cursor - rhs`
fn[T] MachineCursor::sub(
  self : MachineCursor[T],
  rhs : Int,
) -> MachineCursor[T] {
  let mut c = self
  for _ in 0..<rhs {
    c = c.recede1()
  }
  c
}

///|
fn[T] MachineCursor::equal(
  self : MachineCursor[T],
  other : MachineCursor[T],
) -> Bool {
  self.pos == other.pos
}
