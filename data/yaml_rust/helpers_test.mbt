// Test helpers: upstream's scanner test macros and the `YamlChecker` of
// tests/spec_test.rs.

///|
/// `next!(p, pat)`.
fn next(
  p : @yaml_rust.Scanner,
  f : (@yaml_rust.TokenType) -> Bool,
) -> Unit raise {
  guard p.next() is Some(tok) else { fail("unexpected end of tokens") }
  if !f(tok.1) {
    fail("unexpected token: \{Repr(tok)}")
  }
}

///|
/// `next_scalar!(p, style, v)`.
fn next_scalar(
  p : @yaml_rust.Scanner,
  style : @yaml_rust.TScalarStyle,
  v : String,
) -> Unit raise {
  guard p.next() is Some(tok) else { fail("unexpected end of tokens") }
  match tok.1 {
    Scalar(s, value) => {
      assert_eq(s, style)
      assert_eq(value, v)
    }
    _ => fail("unexpected token: \{Repr(tok)}")
  }
}

///|
/// `end!(p)`.
fn end(p : @yaml_rust.Scanner) -> Unit raise {
  assert_true(p.next() is None)
}

///|
/// These names match the names used in the C++ test suite.
enum TestEvent {
  OnDocumentStart
  OnDocumentEnd
  OnSequenceStart
  OnSequenceEnd
  OnMapStart
  OnMapEnd
  OnScalar
  OnAlias
  OnNull
} derive(Eq, Debug)

///|
struct YamlChecker {
  evs : Array[TestEvent]
}

///|
impl @yaml_rust.MarkedEventReceiver for YamlChecker with fn on_event(
  self,
  ev,
  _,
) {
  let tev = match ev {
    DocumentStart => OnDocumentStart
    DocumentEnd => OnDocumentEnd
    SequenceStart(_) => OnSequenceStart
    SequenceEnd => OnSequenceEnd
    MappingStart(_) => OnMapStart
    MappingEnd => OnMapEnd
    Scalar(v, style, _, _) =>
      if v == "~" && style == Plain {
        OnNull
      } else {
        OnScalar
      }
    Alias(_) => OnAlias
    _ => return // ignore other events
  }
  self.evs.push(tev)
}

///|
fn str_to_test_events(docs : String) -> Array[TestEvent] raise {
  let p = { evs: [], }
  let parser = @yaml_rust.Parser::new(docs)
  parser.load(p, true)
  p.evs
}

///|
/// The sequence of `assert_next!`s of a spec test: `evs` starts with
/// `expected` (upstream does not check that the iterator is exhausted).
fn assert_next(
  evs : Array[TestEvent],
  expected : Array[TestEvent],
) -> Unit raise {
  for i, e in expected {
    guard evs.get(i) is Some(ev) else {
      fail("unexpected end of events, expected \{Repr(e)}")
    }
    if ev != e {
      fail("unexpected event: \{Repr(ev)} at \{i}, expected \{Repr(e)}")
    }
  }
}

///|
/// The result of `YamlLoader::load_from_str` as compared with the oracle:
/// the `{:?}` of the documents, or the error's `Display` and marker.
fn load_dump(s : String) -> String {
  try @yaml_rust.YamlLoader::load_from_str(s) catch {
    e => {
      let m = e.marker()
      "Err(\{e} @ \{m.index()}:\{m.line()}:\{m.col()})"
    }
  } noraise {
    docs => "Ok(\{debug_docs(docs)})"
  }
}

///|
/// Rust's `{:?}` of a `Vec<Yaml>`.
fn debug_docs(docs : Array[@yaml_rust.Yaml]) -> String {
  "[" + docs.map(d => d.to_string()).join(", ") + "]"
}

///|
/// `YamlLoader::load_from_str(s).is_err()`.
fn load_fails(s : String) -> Bool {
  try @yaml_rust.YamlLoader::load_from_str(s) catch {
    _ => true
  } noraise {
    _ => false
  }
}
