// Native functions, elements and types compare by their descriptor object
// (upstream: `Static<T>`, whose `PartialEq` is `ptr::eq`), and their
// fingerprint is a number of that object (upstream: its address,
// `typst-utils/src/static.rs`, `Hash for Static`). It was their texts: two
// descriptors with the same texts were one value wherever values are
// compared by their fingerprints, which is what a closure's hash does with
// what the closure captured.

///|
/// Two native functions that differ in nothing but the object (and in what
/// they return, which no fingerprint sees).
fn descriptor_test_twins() -> (NativeFuncData, NativeFuncData) {
  let make = (answer : Int64) => {
    NativeFuncData::new(name="twin", title="Twin", docs="One of two.", (_, _, _) => {
      Int(answer)
    })
  }
  (make(1), make(2))
}

///|
/// What the closure of [test_closure] captured.
fn descriptor_test_captured(closure : Closure) -> Value {
  closure.captured.get("x").unwrap().value
}

///|
test "descriptors: two native functions with the same texts are two values" {
  let (a, b) = descriptor_test_twins()
  assert_eq(a.name, b.name)
  assert_eq(a.title, b.title)
  assert_eq(a.docs, b.docs)
  let fa = Value::Func(Func::native(a))
  let fb = Value::Func(Func::native(b))
  assert_false(fa == fb)
  assert_true(fa == Value::Func(Func::native(a)))
  assert_false(hash128(fa) == hash128(fb))
  assert_eq(hash128(fa), hash128(Value::Func(Func::native(a))))
  // No flag: an equal fingerprint is the same descriptor.
  assert_eq(fingerprint_flags_in(() => SipHasher128::new().write(fa)), 0)
  // Closures compare by their hash, which covers what they captured.
  let node = @syntax.parse_code("x")
  assert_false(test_closure(node, fa) == test_closure(node, fb))
  assert_true(test_closure(node, fa) == test_closure(node, fa))
}

///|
test "descriptors: elements and types with the same texts are two values" {
  let elem = () => Element::new(name="twin", title="Twin", fields=[])
  let (a, b) = (elem(), elem())
  assert_false(a == b)
  assert_false(hash128(a) == hash128(b))
  assert_eq(hash128(a), hash128(a))
  // As the element of content, which is what a location key hashes.
  let content = (elem : Element) => Content::from_fields(elem, [])
  assert_false(hash128(content(a)) == hash128(content(b)))
  assert_eq(hash128(content(a)), hash128(content(a)))
  let ty = () => {
    Type::Type(
      NativeTypeData::new(name="twin", long_name="twin", title="Twin", docs=""),
    )
  }
  let (s, t) = (ty(), ty())
  assert_false(s == t)
  assert_false(hash128(Value::Type(s)) == hash128(Value::Type(t)))
  assert_eq(hash128(Value::Type(s)), hash128(Value::Type(s)))
}

///|
/// Mutation check 22 of `docs/incremental-design.md`, section 9.1: with the
/// texts as the fingerprint, the second call below is answered with the
/// result of the first, the other function.
test "descriptors: a memoized call is not answered for a twin of what it captured" {
  memo_test_begin()
  defer memo_test_end()
  let (a, b) = descriptor_test_twins()
  let node = @syntax.parse_code("x")
  let getter = (data : NativeFuncData) => {
    guard test_closure(node, Func(Func::native(data))) is Func(func) else {
      abort("not a function")
    }
    func
  }
  let mut runs = 0
  // `get() = x`: returns what it captured.
  let body : ClosureBody = (_, closure, _, _, _) => {
    runs += 1
    descriptor_test_captured(closure)
  }
  let engine = memo_engine()
  let call = (data : NativeFuncData) => {
    memo_call(getter(data), engine, Context::none(), [], body)
  }
  let same = (value : Value, data : NativeFuncData) => {
    value is Func(func) &&
    func.inner is Native(found) &&
    physical_equal(found, data)
  }
  assert_true(same(call(a), a))
  assert_true(same(call(b), b))
  assert_eq(runs, 2)
  // Each is found again, as itself.
  assert_true(same(call(a), a))
  assert_true(same(call(b), b))
  assert_eq(runs, 2)
  // The same through content that holds the function, as an argument: the
  // arguments are compared exactly, and content compares its fields.
  let holder = (data : NativeFuncData) => {
    Value::Content(
      Content::from_fields(TextElem::packed("x").elem(), [
        Some(test_closure(node, Func(Func::native(data)))),
      ]),
    )
  }
  let f = memo_test_func(7)
  let mut seen = 0
  let body : ClosureBody = (_, _, _, _, args) => {
    seen += 1
    args.expect("holder")
  }
  let first = memo_call(f, engine, Context::none(), [holder(a)], body)
  let second = memo_call(f, engine, Context::none(), [holder(b)], body)
  assert_eq(seen, 2)
  assert_false(hash128(first) == hash128(second))
}

///|
/// Every native function, element and type that the standard library's
/// scopes hold, with the scopes of functions, elements, types and modules
/// followed.
fn descriptor_test_collect(
  scope : Scope,
  funcs : Array[NativeFuncData],
  elems : Array[Element],
  types : Array[Type],
  seen : Array[Scope],
) -> Unit {
  for other in seen {
    if physical_equal(other, scope) {
      return
    }
  }
  seen.push(scope)
  for _, binding in scope.map {
    match binding.value {
      Func(func) =>
        match func.inner {
          Native(data) =>
            if !funcs.iter().any(other => physical_equal(other, data)) {
              funcs.push(data)
              descriptor_test_collect(data.scope(), funcs, elems, types, seen)
            }
          Element(elem) =>
            if !elems.contains(elem) {
              elems.push(elem)
              descriptor_test_collect(elem.scope(), funcs, elems, types, seen)
            }
          _ => ()
        }
      Type(ty) =>
        if !types.contains(ty) {
          types.push(ty)
          descriptor_test_collect(ty.scope(), funcs, elems, types, seen)
          if ty.0.constructor_ is Some(data) &&
            !funcs.iter().any(other => physical_equal(other, data)) {
            funcs.push(data)
          }
        }
      Module(module_) =>
        descriptor_test_collect(module_.scope(), funcs, elems, types, seen)
      _ => ()
    }
  }
}

///|
/// The standard library has no two descriptors that a fingerprint of their
/// texts would take for one (so the hole was a host's: a library with two
/// native functions of the same name, title and documentation). Their
/// numbers are distinct, as they are for any two descriptors.
test "descriptors: the standard library's are distinct by their texts too" {
  let funcs = []
  let elems = []
  let types = []
  let library = wb_library()
  descriptor_test_collect(library.global.scope(), funcs, elems, types, [])
  descriptor_test_collect(library.math.scope(), funcs, elems, types, [])
  // 296 native functions, 111 elements and 36 types when this was written.
  assert_true(funcs.length() > 250)
  assert_true(elems.length() > 100)
  assert_true(types.length() > 30)
  let texts : Map[String, Int] = Map([])
  let twins = []
  for data in funcs {
    let text = "\{data.name}\u{0}\{data.title}\u{0}\{data.docs}"
    if texts.contains(text) {
      twins.push("\{data.name} (\{data.title})")
    }
    texts[text] = 1
  }
  assert_eq(twins.length(), 0)
  let numbers : Map[U128, Int] = Map([])
  for data in funcs {
    numbers[hash128(Value::Func(Func::native(data)))] = 1
  }
  for elem in elems {
    numbers[hash128(Value::Func(Func::element(elem)))] = 1
  }
  for ty in types {
    numbers[hash128(Value::Type(ty))] = 1
  }
  assert_eq(numbers.length(), funcs.length() + elems.length() + types.length())
}
