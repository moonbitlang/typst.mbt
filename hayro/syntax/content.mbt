// Port of `hayro-syntax/src/content/mod.rs`: PDF content operators.

///|
// 6 operands are used for example for ctm or cubic curves,
// but anything above should be pretty rare (only for example for
// DeviceN color spaces, or invalid PDF files). So we settle on 10.
const OPERANDS_THRESHOLD : Int = 10

///|
/// Read a content stream operator (upstream `Operator`, a name without a
/// leading solidus).
fn read_operator(r : Reader) -> Name? {
  let old = r.offset()
  let start = r.offset()
  guard skip_name_like(r, false) is Some(_) else {
    r.jump(old)
    return None
  }
  let end = r.offset()
  let data = r.range(start, end)
  match data {
    Some(data) if data.length() > 0 =>
      match Name::new(data) {
        Some(n) => Some(n)
        None => {
          r.jump(old)
          None
        }
      }
    _ => {
      r.jump(old)
      None
    }
  }
}

///|
/// An instruction (= operator and its operands) in a content stream.
pub struct Instruction {
  /// The operands.
  operands : Array[Object]
  /// The actual operator.
  operator : Name
}

///|
/// An iterator over operators in the PDF content streams, providing raw
/// access to the instructions.
pub struct UntypedIter {
  priv reader : Reader
}

///|
/// Create a new untyped iterator.
pub fn UntypedIter::new(data : BytesView) -> UntypedIter {
  { reader: Reader::new(data), }
}

///|
/// Create a new empty untyped iterator.
pub fn UntypedIter::empty() -> UntypedIter {
  { reader: Reader::new(b""[:]), }
}

///|
pub fn UntypedIter::clone(self : UntypedIter) -> UntypedIter {
  { reader: self.reader.clone(), }
}

///|
fn stack_push(stack : Array[Object], operand : Object) -> Unit? {
  if stack.length() >= OPERANDS_THRESHOLD {
    return None
  }
  stack.push(operand)
  Some(())
}

///|
fn is_ascii(b : Byte) -> Bool {
  b.to_int() < 128
}

///|
/// Return the next instruction.
pub fn UntypedIter::next(self : UntypedIter) -> Instruction? {
  let stack : Array[Object] = []
  self.reader.skip_white_spaces_and_comments()
  while !self.reader.at_end() {
    // I believe booleans/null never appear as an operator?
    guard self.reader.peek_byte() is Some(peeked) else { return None }
    if peeked is (b'/' | b'.' | b'+' | b'-' | b'0'..<=b'9' | b'[' | b'<' | b'(') {
      // See issue 994. In all sane scenarios, if the next byte is a number
      // it has to be an operand (a number). However, it's possible that
      // the number is followed by a regular character, in which case it
      // should behave more like an operator (even though there exists
      // no operator that starts with a number). In order to preserve
      // similar behavior to Acrobat and Chromium, we try to consume
      // such an operator and then simply skip it.
      let object : Object? = self.reader.read_without_context()
      if object is Some(object) {
        guard stack_push(stack, object) is Some(_) else { return None }
      } else if read_operator(self.reader) is Some(_) {
        stack.clear()
      } else {
        return None
      }
    } else {
      let operator = match read_operator(self.reader) {
        Some(o) => o
        None => {
          // failed to read operator in content stream
          self.reader.jump_to_end()
          return None
        }
      }

      // Inline images need special casing...
      if operator.0 == "BI" {
        guard self.read_inline_image(stack) is Some(_) else { return None }
      }
      return Some({ operands: stack, operator, })
    }
    self.reader.skip_white_spaces_and_comments()
  }
  None
}

///|
fn UntypedIter::read_inline_image(
  self : UntypedIter,
  stack : Array[Object],
) -> Unit? {
  // The ID operator will already be consumed by this.
  guard (self.reader.read_without_context() : InlineImageDict?)
    is Some(inline_dict) else {
    return None
  }
  let dict = inline_dict.get_dict()

  // One whitespace after "ID".
  guard self.reader.read_white_space() is Some(_) else { return None }
  guard self.reader.tail() is Some(stream_data) else { return None }
  let start_offset = self.reader.offset()
  while self.reader.tail() is Some(t) && find_needle(t, b"EI") is Some(pos) {
    guard self.reader.read_bytes(pos) is Some(_) else { return None }
    if self.reader.peek_bytes(2) is Some([b'E', b'I']) {
      // If the following character is not a whitespace character, then we are in a ASCII-85 stream.
      if self.reader.peek_bytes(3) is Some(b) && !is_white_space_character(b[2]) {
        guard self.reader.read_bytes(3) is Some(_) else { return None }
        continue
      }
      let end_offset = self.reader.offset() - start_offset
      let image_data = stream_data[:end_offset]
      let stream = Stream::new(image_data, dict)

      // Note that there is a possibility that the encoded stream data
      // contains the "EI" operator as part of the data, in which case we
      // cannot confidently know whether we have hit the actual end of the
      // stream. See also <https://github.com/pdf-association/pdf-issues/issues/543>
      guard self.reader.tail() is Some(tail) else { return None }
      let tail = tail[2:]
      let find_reader = Reader::new(tail)
      let mut continue_outer = false
      while !find_reader.at_end() {
        guard find_reader.tail() is Some(remaining) else { return None }
        let next_ei = find_needle(remaining, b"EI")
        let next_bi = find_needle(remaining, b"BI")
        let (next_pos, is_ei) = match (next_ei, next_bi) {
          (Some(ei), Some(bi)) if ei <= bi => (ei, true)
          (Some(_), Some(bi)) => (bi, false)
          (Some(ei), None) => (ei, true)
          (None, Some(bi)) => (bi, false)
          (None, None) => break
        }
        guard find_reader.read_bytes(next_pos) is Some(_) else { return None }
        if is_ei {
          let analyze_data = tail[:find_reader.offset()]

          // If there is any binary data in-between, we for sure
          // have not reached the end.
          let mut binary = false
          for c in analyze_data {
            if !is_ascii(c) {
              binary = true
              break
            }
          }
          if binary {
            guard self.reader.read_bytes(2) is Some(_) else { return None }
            continue_outer = true
            break
          }

          // Otherwise, the only possibility that we reached an
          // "EI", even though the previous one was valid, is
          // that it's part of a string in the content
          // stream that follows the inline image. Therefore,
          // it should be valid to interpret `tail` as a content
          // stream and there should be at least one text-related
          // operator that can be parsed correctly.
          let iter = TypedIter::new(tail)
          let mut found = false
          let mut counter = 0
          while iter.next() is Some(op) {
            // If we have read more than 20 valid operators, it should be
            // safe to assume that we are in a content stream, so abort
            // early.
            if counter >= 20 {
              found = true
              break
            }
            if op
              is (NextLineAndShowText(_)
              | ShowText(_)
              | ShowTexts(_)
              | ShowTextWithParameters(_, _, _)) {
              // Now it should be safe to assume that the
              // previous `EI` was the correct one.
              found = true
              break
            }
            counter += 1
          }
          if !found {
            // Seems like the data in-between is not a valid content
            // stream, so we are likely still within the image data.
            guard self.reader.read_bytes(2) is Some(_) else { return None }
            continue_outer = true
            break
          }
        } else {
          // Possibly another inline image, if so, the previously found "EI"
          // is indeed the end of data.
          let cloned = find_reader.clone()
          guard cloned.read_bytes(2) is Some(_) else { return None }
          let next_dict : InlineImageDict? = cloned.read_without_context()
          if next_dict is Some(_) {
            break
          }
        }
        guard find_reader.read_byte() is Some(_) else { return None }
      }
      if continue_outer {
        continue
      }
      guard stack_push(stack, Object::Stream(stream)) is Some(_) else {
        return None
      }
      guard self.reader.read_bytes(2) is Some(_) else { return None }
      self.reader.skip_white_spaces()
      break
    }
  }
  Some(())
}

///|
/// An iterator over PDF content streams that provide access to the
/// instructions in a typed fashion.
pub struct TypedIter {
  priv untyped : UntypedIter
}

///|
/// Create a new typed iterator.
pub fn TypedIter::new(data : BytesView) -> TypedIter {
  { untyped: UntypedIter::new(data), }
}

///|
pub fn TypedIter::from_untyped(untyped : UntypedIter) -> TypedIter {
  { untyped, }
}

///|
pub fn TypedIter::clone(self : TypedIter) -> TypedIter {
  { untyped: self.untyped.clone(), }
}

///|
/// Return the next typed instruction.
pub fn TypedIter::next(self : TypedIter) -> TypedInstruction? {
  guard self.untyped.next() is Some(op) else { return None }
  match TypedInstruction::dispatch(op) {
    Some(op) => Some(op)
    // In case this returns `None`, the content stream is invalid. In case a path-drawing
    // operator was used, let's abort completely, otherwise we might end up drawing random stuff.
    // However, for other operators it could be worth it to just skip it but keep attempting
    // to read other content operators.
    None =>
      if op.operator.0 is ("m" | "l" | "c" | "v" | "y" | "h" | "re") {
        None
      } else {
        Some(Fallback(op.operator))
      }
  }
}

///|
fn saturating_sub(a : Int, b : Int) -> Int {
  if a > b {
    a - b
  } else {
    0
  }
}

///|
fn operand_number(stack : Array[Object], index : Int) -> Number? {
  match stack.get(index) {
    Some(Number(n)) => Some(n)
    _ => None
  }
}

///|
fn operand_name(stack : Array[Object], index : Int) -> Name? {
  match stack.get(index) {
    Some(Name(n)) => Some(n)
    _ => None
  }
}

///|
fn operand_array(stack : Array[Object], index : Int) -> PdfArray? {
  match stack.get(index) {
    Some(Array(a)) => Some(a)
    _ => None
  }
}

///|
fn operand_stream(stack : Array[Object], index : Int) -> Stream? {
  match stack.get(index) {
    Some(Stream(s)) => Some(s)
    _ => None
  }
}

///|
fn operand_string(stack : Array[Object], index : Int) -> PdfString? {
  match stack.get(index) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn operand_object(stack : Array[Object], index : Int) -> Object? {
  stack.get(index)
}

///|
fn stack_get_all_numbers(stack : Array[Object]) -> Array[Number]? {
  let operands = []
  for op in stack {
    match op {
      Number(n) => operands.push(n)
      _ => return None
    }
  }
  Some(operands)
}

///|
// Need to special-case those because they have variable arguments.
fn parse_named_color(objects : Array[Object]) -> (Array[Number], Name?)? {
  let nums = []
  let mut name = None
  for o in objects {
    match o {
      Number(n) => nums.push(n)
      Name(n) => name = Some(n)
      // encountered unknown object when parsing scn/SCN
      _ => return None
    }
  }
  Some((nums, name))
}
