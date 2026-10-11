// The tracked world (`tracked_world.mbt`) at the level of the stores: what
// an entry keeps of the world, when it is rejected, and what a hit notes
// for the calls around it.
//
// Nothing is kept across compilations yet, so in a compilation the world
// reads of an entry always hold. These tests keep a store over several
// scopes of one world (the generation stays, the scope changes), which is
// what the later steps of `docs/incremental-design.md` do for real.

///|
/// A world whose answers a test changes, and that notes what it is asked.
priv struct ReadWorld {
  library : Library
  sources : Map[String, @syntax.Source]
  files : Map[String, Bytes]
  mut book : FontBook
  fonts : Array[Font?]
  mut date : Datetime?
  /// Files whose read fails with this error.
  failing : Map[String, FileError]
  asked : Array[String]
}

///|
fn ReadWorld::new() -> ReadWorld {
  {
    library: wb_library(),
    sources: {},
    files: {},
    book: FontBook::new(),
    fonts: [],
    date: None,
    failing: {},
    asked: [],
  }
}

///|
impl World for ReadWorld with fn library(self) {
  self.library
}

///|
impl World for ReadWorld with fn main(_) {
  memo_file("main.typ")
}

///|
impl World for ReadWorld with fn source(self, id) {
  let path = id.vpath().get_without_slash()
  self.asked.push("source \{path}")
  match self.sources.get(path) {
    Some(source) => source
    None => raise FileError::NotFound(path)
  }
}

///|
impl World for ReadWorld with fn file(self, id) {
  let path = id.vpath().get_without_slash()
  self.asked.push("file \{path}")
  if self.failing.get(path) is Some(error) {
    raise error
  }
  match self.files.get(path) {
    Some(data) => data
    None => raise FileError::NotFound(path)
  }
}

///|
impl World for ReadWorld with fn book(self) {
  self.asked.push("book")
  self.book
}

///|
impl World for ReadWorld with fn font(self, index) {
  self.asked.push("font \{index}")
  if index >= 0 && index < self.fonts.length() {
    self.fonts[index]
  } else {
    None
  }
}

///|
impl World for ReadWorld with fn today(self, offset) {
  self.asked.push(
    match offset {
      None => "today"
      Some(offset) => "today \{offset.0.whole_seconds()}"
    },
  )
  self.date
}

///|
/// A face that is never asked for anything: a font is its data and index
/// to the engine's fingerprint.
priv struct ReadFace(String)

///|
impl FontFace for ReadFace with fn family(self) {
  self.0
}

///|
impl FontFace for ReadFace with fn post_script_name(_) {
  None
}

///|
impl FontFace for ReadFace with fn instantiate(_, _) {
  abort("not instantiated in these tests")
}

///|
fn read_font(data : Bytes) -> Font {
  Font::new(data, 0, (ReadFace("Test") : ReadFace))
}

///|
fn read_info(family : String) -> FontInfo {
  {
    family,
    variant: FontVariant::default(),
    flags: FontFlags::empty(),
    axes: [],
    coverage: Coverage::default(),
  }
}

///|
/// What a test compiles with: a store that lives through the scopes of the
/// test, and the engine of the world.
priv struct ReadTest {
  world : ReadWorld
  tracked : TrackedWorld
  store : MemoStore[Int, Int]
  mut library : Library
  /// The number of times each call ran, by tag.
  runs : Map[Int, Int]
}

///|
fn ReadTest::new(volatile_files? : (@syntax.FileId) -> Bool) -> ReadTest {
  let world = ReadWorld::new()
  {
    world,
    tracked: TrackedWorld::new(world, volatile_files?),
    store: MemoStore::new(),
    library: world.library,
    runs: {},
  }
}

///|
fn ReadTest::engine(self : ReadTest) -> Engine {
  {
    world: self.tracked,
    library: self.library,
    introspector: Introspector::empty(),
    traced: Traced::new(),
    sink: Sink::new(),
    route: Route::root(),
  }
}

///|
/// The body of a memoized call of a test.
type ReadBody = (Engine) -> Int raise SourceError

///|
/// The memoized call `tag` (its key and its only argument).
fn ReadTest::call(
  self : ReadTest,
  engine : Engine,
  tag : Int,
  body : ReadBody,
) -> Int raise SourceError {
  let key = memo_fingerprint(state => state.write_usize(tag))
  memoize(self.store, engine, key, tag, value => value, engine => {
    self.runs[tag] = self.runs.get(tag).unwrap_or(0) + 1
    body(engine)
  })
}

///|
fn ReadTest::ran(self : ReadTest, tag : Int) -> Int {
  self.runs.get(tag).unwrap_or(0)
}

///|
/// The world reads that the entries of the call `tag` keep, without the
/// fingerprints.
fn ReadTest::kept(self : ReadTest, tag : Int) -> String {
  let key = memo_fingerprint(state => state.write_usize(tag))
  let entries = self.store.entries.get(key).unwrap_or([])
  entries
  .map(entry => entry.world.reads.map(read => read.describe()).join(", "))
  .join(" | ")
}

///|
/// A scope of the test's world, as a compilation is one.
fn[T] ReadTest::scope(self : ReadTest, f : (Engine) -> T raise) -> T raise {
  self.tracked.open()
  defer self.tracked.close()
  f(self.engine())
}

///|
/// Runs a test with a store generation, like a compilation that never
/// ends.
fn read_test(
  f : (ReadTest) -> Unit raise,
  volatile_files? : (@syntax.FileId) -> Bool,
) -> Unit raise {
  memo_counter.val += 1
  memo_generation.val = memo_counter.val
  defer {
    memo_generation.val = 0
  }
  f(ReadTest::new(volatile_files?))
}

///|
fn length_of(engine : Engine, path : String) -> Int raise SourceError {
  let data = engine.world.file(memo_file(path)) catch {
    error =>
      raise SourceError([
        SourceDiagnostic::error_at(@syntax.Span::detached(), error.to_string()),
      ])
  }
  data.length()
}

///|
fn text_length_of(engine : Engine, path : String) -> Int {
  let source = engine.world.source(memo_file(path)) catch { _ => return -1 }
  source.text().length()
}

///|
test "world reads: kept once each, in the order of the first, with those of the calls inside" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    t.world.files["b.txt"] = b"bb"
    t.world.sources["m.typ"] = @syntax.Source::new(memo_file("m.typ"), "m")
    t.scope(engine => {
      let inner = (engine : Engine) => {
        t.call(engine, 2, engine => {
          length_of(engine, "b.txt") +
          length_of(engine, "a.txt") +
          text_length_of(engine, "m.typ")
        })
      }
      let value = t.call(engine, 1, engine => {
        engine.world.today(None) |> ignore
        let n = length_of(engine, "a.txt")
        let m = inner(engine)
        engine.world.book() |> ignore
        engine.world.font(3) |> ignore
        length_of(engine, "a.txt") + n + m
      })
      assert_eq(value, 6)
    })
    // The inner call's reads are its caller's, where they were first made.
    inspect(t.kept(2), content="file(b.txt), file(a.txt), source(m.typ)")
    inspect(
      t.kept(1),
      content="today(none), file(a.txt), file(b.txt), source(m.typ), book, font(3)",
    )
    // Outside of every memoized call nothing is noted, and nothing is left
    // in the log when the outermost one ends.
    assert_true(t.tracked.scope is None)
    t.scope(engine => {
      length_of(engine, "a.txt") |> ignore
      guard engine.world.scope is Some(scope) else { fail("no scope") }
      assert_eq(scope.log.length(), 0)
      assert_eq(scope.calls, 0)
    })
  })
}

///|
test "world reads: an entry is taken in a later scope if every read answers the same" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    t.world.sources["m.typ"] = @syntax.Source::new(memo_file("m.typ"), "m")
    t.world.date = Datetime::from_ymd(2026, 10, 7)
    t.world.book = FontBook::from_infos([read_info("One")])
    t.world.fonts.push(Some(read_font(b"font one")))
    let body = (engine : Engine) => {
      engine.world.book() |> ignore
      engine.world.font(0) |> ignore
      engine.world.font(7) |> ignore
      engine.world.today(None) |> ignore
      engine.world.today(Some(Duration(@time.Duration::hours(2)))) |> ignore
      length_of(engine, "a.txt") + text_length_of(engine, "m.typ")
    }
    t.scope(engine => assert_eq(t.call(engine, 1, body), 2))
    assert_eq(t.ran(1), 1)
    t.world.asked.clear()
    t.scope(engine => {
      assert_eq(t.call(engine, 1, body), 2)
      // Validating made every read once, in the order of the call.
      inspect(
        t.world.asked.join(", "),
        content="book, font 0, font 7, today, today 7200, file a.txt, source m.typ",
      )
      // Stamped: in the same scope the reads are not made again.
      assert_eq(t.call(engine, 1, body), 2)
      inspect(t.world.asked.length(), content="7")
    })
    assert_eq(t.ran(1), 1)
    // The same bytes in another object and a source parsed again from the
    // same text are the same answers.
    t.world.files["a.txt"] = Bytes::makei(1, _ => b'a')
    t.world.sources["m.typ"] = @syntax.Source::new(memo_file("m.typ"), "m")
    t.scope(engine => assert_eq(t.call(engine, 1, body), 2))
    assert_eq(t.ran(1), 1)
  })
}

///|
/// One call that reads `read`, a scope, `change`, a scope: whether the
/// second scope computed the call again.
fn recomputed_after(
  setup : (ReadWorld) -> Unit,
  read : (Engine) -> Unit,
  change : (ReadWorld) -> Unit,
) -> Bool raise {
  let mut again = false
  read_test(t => {
    setup(t.world)
    let body : ReadBody = engine => {
      read(engine)
      0
    }
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    // Nothing changed: found.
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    assert_eq(t.ran(1), 1)
    change(t.world)
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    again = t.ran(1) == 2
  })
  again
}

///|
test "world reads: an entry is rejected if one answer differs" {
  let source = (engine : Engine) => {
    let _ = engine.world.source(memo_file("m.typ")) catch { _ => return }
  }
  let file = (engine : Engine) => {
    let _ = engine.world.file(memo_file("a.txt")) catch { _ => return }
  }
  let edit = (world : ReadWorld, text : String) => {
    // An edit returns the edited source; a world keeps that.
    world.sources["m.typ"] = world.sources.get("m.typ").unwrap().replace(text).0
  }
  let with_source = (world : ReadWorld) => {
    world.sources["m.typ"] = @syntax.Source::new(memo_file("m.typ"), "one")
  }
  let with_file = (world : ReadWorld) => world.files["a.txt"] = b"one"
  // The text of a source: another object, and the same object edited.
  assert_true(
    recomputed_after(with_source, source, world => {
      world.sources["m.typ"] = @syntax.Source::new(memo_file("m.typ"), "two")
    }),
  )
  assert_true(
    recomputed_after(with_source, source, world => edit(world, "two")),
  )
  // Edited and edited back: the text it had, but span numbers a module
  // made from the first tree does not know.
  assert_true(
    recomputed_after(with_source, source, world => {
      edit(world, "two")
      edit(world, "one")
    }),
  )
  // Replaced by the text it has: nothing changed.
  assert_false(
    recomputed_after(with_source, source, world => edit(world, "one")),
  )
  // The bytes of a file.
  assert_true(
    recomputed_after(with_file, file, world => world.files["a.txt"] = b"two"),
  )
  // A file disappears, a file appears, a source too.
  assert_true(
    recomputed_after(with_file, file, world => world.files.remove("a.txt")),
  )
  assert_true(recomputed_after(_ => (), file, with_file))
  assert_true(recomputed_after(_ => (), source, with_source))
  assert_true(
    recomputed_after(with_source, source, world => world.sources.remove("m.typ")),
  )
  // Two errors with one message are two answers.
  let malformed = (detail : String?) => {
    (world : ReadWorld) => {
      world.failing["a.txt"] = FileError::Package(MalformedArchive(detail))
    }
  }
  inspect(
    FileError::Package(MalformedArchive(None)).to_string() ==
    FileError::Package(MalformedArchive(Some("archive malformed"))).to_string(),
    content="true",
  )
  assert_true(
    recomputed_after(
      malformed(None),
      file,
      malformed(Some("archive malformed")),
    ),
  )
  assert_false(recomputed_after(malformed(None), file, malformed(None)))
  // The date: another day, and a world that stops knowing it.
  let today = (engine : Engine) => engine.world.today(None) |> ignore
  let dated = (world : ReadWorld) => {
    world.date = Datetime::from_ymd(2026, 10, 7)
  }
  assert_true(
    recomputed_after(dated, today, world => {
      world.date = Datetime::from_ymd(2026, 10, 8)
    }),
  )
  assert_true(recomputed_after(dated, today, world => world.date = None))
  // The font book: a font is added to the book, another book.
  let book = (engine : Engine) => engine.world.book() |> ignore
  let one_font = (world : ReadWorld) => {
    world.book = FontBook::from_infos([read_info("One")])
    world.fonts.push(Some(read_font(b"font one")))
  }
  assert_true(
    recomputed_after(one_font, book, world => world.book.push(read_info("Two"))),
  )
  assert_true(
    recomputed_after(one_font, book, world => {
      world.book = FontBook::from_infos([read_info("Other")])
    }),
  )
  // A book and a font are the objects (stricter than upstream, which
  // hashes their infos and their data): the same infos in another book
  // and the same data in another font are other answers.
  assert_true(
    recomputed_after(one_font, book, world => {
      world.book = FontBook::from_infos([read_info("One")])
    }),
  )
  // A font: other data under an unchanged book, and a font that is gone.
  let font = (engine : Engine) => engine.world.font(0) |> ignore
  assert_true(
    recomputed_after(one_font, font, world => {
      world.fonts[0] = Some(read_font(b"font two"))
    }),
  )
  assert_true(
    recomputed_after(one_font, font, world => {
      world.fonts[0] = Some(read_font(b"font one"))
    }),
  )
  assert_true(recomputed_after(one_font, font, world => world.fonts[0] = None))
  // What a call did not read does not matter to it.
  assert_false(
    recomputed_after(
      world => {
        with_file(world)
        with_source(world)
        dated(world)
      },
      file,
      world => {
        edit(world, "two")
        world.date = None
        world.files["other.txt"] = b"new"
      },
    ),
  )
}

///|
test "world reads: the library is compared (`sys.inputs`)" {
  read_test(t => {
    let body : ReadBody = _ => 0
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    assert_eq(t.ran(1), 1)
    // Another library: the same definitions and other inputs.
    let inputs = Dict::new()
    inputs.insert("v", Str("2"))
    let routines = Routines::new(eval_string=(_, _, _, _, _, _) => None, eval_closure=(
      _,
      _,
      _,
      _,
      _,
    ) => None)
    t.library = Library::builder(routines, []).with_inputs(inputs).build()
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    assert_eq(t.ran(1), 2)
    // And one made the same way is another library too.
    t.library = Library::builder(routines, []).with_inputs(inputs).build()
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    assert_eq(t.ran(1), 3)
  })
}

///|
test "world reads: a failed read is kept, also of a call that goes on" {
  read_test(t => {
    let body : ReadBody = engine => {
      // Like `Engine::delay`: the error of the call inside is put aside.
      let inner = t.call(engine, 2, engine => length_of(engine, "a.txt")) catch {
        _ => -1
      }
      inner
    }
    t.scope(engine => assert_eq(t.call(engine, 1, body), -1))
    // The call that failed is not kept; the one around it has its read.
    inspect(t.kept(2), content="")
    inspect(t.kept(1), content="file(a.txt)")
    t.scope(engine => assert_eq(t.call(engine, 1, body), -1))
    assert_eq(t.ran(1), 1)
    // The file appears.
    t.world.files["a.txt"] = b"abc"
    t.scope(engine => assert_eq(t.call(engine, 1, body), 3))
    assert_eq(t.ran(1), 2)
  })
}

///|
test "world reads: the reads of an entry that is taken are its caller's" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    let inner = (engine : Engine) => {
      t.call(engine, 2, engine => length_of(engine, "a.txt"))
    }
    let middle = (engine : Engine) => t.call(engine, 3, inner)
    t.scope(engine => {
      // The inner call is computed on its own, the calls around it find it.
      assert_eq(inner(engine), 1)
      assert_eq(t.call(engine, 1, middle), 1)
      assert_eq(t.ran(2), 1)
    })
    inspect(t.kept(3), content="file(a.txt)")
    inspect(t.kept(1), content="file(a.txt)")
    // So they are rejected with it.
    t.world.files["a.txt"] = b"abc"
    t.scope(engine => assert_eq(t.call(engine, 1, middle), 3))
    assert_eq((t.ran(1), t.ran(3), t.ran(2)), (2, 2, 2))
    // In a scope in which the inner entry is found again and the outer
    // ones are not there: the reads come from the entry.
    t.store.entries.remove(memo_fingerprint(state => state.write_usize(1)))
    t.store.entries.remove(memo_fingerprint(state => state.write_usize(3)))
    t.scope(engine => assert_eq(t.call(engine, 1, middle), 3))
    assert_eq((t.ran(1), t.ran(3), t.ran(2)), (3, 3, 2))
    inspect(t.kept(1), content="file(a.txt)")
    t.world.files["a.txt"] = b"abcde"
    t.scope(engine => assert_eq(t.call(engine, 1, middle), 5))
    assert_eq((t.ran(1), t.ran(3), t.ran(2)), (4, 4, 3))
  })
}

///|
test "world reads: checked in order, up to the first that differs" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    t.world.files["b.txt"] = b"b"
    t.world.files["c.txt"] = b"c"
    // Reads `c.txt` only if `a.txt` is short.
    let body = (engine : Engine) => {
      if length_of(engine, "a.txt") == 1 {
        length_of(engine, "b.txt") + length_of(engine, "c.txt")
      } else {
        0
      }
    }
    t.scope(engine => t.call(engine, 1, body) |> ignore)
    t.world.files["a.txt"] = b"aa"
    t.world.asked.clear()
    t.scope(engine => assert_eq(t.call(engine, 1, body), 0))
    // The world is not asked for what a run from scratch does not read.
    inspect(t.world.asked.join(", "), content="file a.txt, file a.txt")
  })
}

///|
test "world reads: closure calls keep them, are rejected by them and hand them on" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    let mut runs = 0
    let body : ClosureBody = (_, _, engine, _, args) => {
      runs += 1
      args.finish()
      Int(length_of(engine, "a.txt").to_int64())
    }
    let f = memo_test_func(1)
    let call = (engine : Engine) => {
      memo_call(f, engine, Context::none(), [], body)
    }
    t.scope(engine => {
      assert_true(call(engine) == Int(1))
      assert_true(call(engine) == Int(1))
      // A memoized call around the closure call that finds it.
      assert_eq(
        t.call(engine, 1, engine => {
          call(engine) |> ignore
          0
        }),
        0,
      )
    })
    assert_eq(runs, 1)
    inspect(t.kept(1), content="file(a.txt)")
    t.scope(engine => assert_true(call(engine) == Int(1)))
    assert_eq(runs, 1)
    t.world.files["a.txt"] = b"abc"
    t.scope(engine => assert_true(call(engine) == Int(3)))
    assert_eq(runs, 2)
  })
}

///|
test "world reads: what reads a volatile file is not kept, nor what is around it" {
  let listing = memo_file("listing.txt")
  read_test(volatile_files=id => id == listing, t => {
    t.world.files["listing.txt"] = b"one"
    t.world.files["a.txt"] = b"a"
    let reader = (engine : Engine) => {
      t.call(engine, 2, engine => length_of(engine, "listing.txt"))
    }
    let around = (engine : Engine) => {
      t.call(engine, 1, engine => length_of(engine, "a.txt") + reader(engine))
    }
    let beside = (engine : Engine) => {
      t.call(engine, 3, engine => length_of(engine, "a.txt"))
    }
    t.scope(engine => {
      assert_eq(around(engine), 4)
      // The file grows during the scope.
      t.world.files["listing.txt"] = b"one two"
      assert_eq(around(engine), 8)
      assert_eq(beside(engine), 1)
      assert_eq(beside(engine), 1)
    })
    assert_eq((t.ran(1), t.ran(2), t.ran(3)), (2, 2, 1))
    inspect(t.kept(1), content="")
    inspect(t.kept(2), content="")
    inspect(t.kept(3), content="file(a.txt)")
  })
}

///|
test "world reads: an entry with a read that is volatile in the scope at hand is not taken" {
  let listing = memo_file("listing.txt")
  read_test(t => {
    // Stored for a world in which the file is a file like any other.
    t.world.files["listing.txt"] = b"one"
    let body = (engine : Engine) => length_of(engine, "listing.txt")
    t.scope(engine => assert_eq(t.call(engine, 1, body), 3))
    inspect(t.kept(1), content="file(listing.txt)")
    // The same store, a world with the same files in which it changes
    // during a scope: not found, whatever the file answers.
    let session = TrackedWorld::new(t.world, volatile_files=id => id == listing)
    let engine = { ..t.engine(), world: session, }
    session.open()
    assert_eq(t.call(engine, 1, body), 3)
    assert_eq(t.call(engine, 1, body), 3)
    session.close()
    assert_eq(t.ran(1), 3)
    // And where it does not, the entry is still good.
    t.scope(engine => assert_eq(t.call(engine, 1, body), 3))
    assert_eq(t.ran(1), 3)
  })
}

///|
test "world reads: the stamp of one scope is not taken for another's" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    let body = (engine : Engine) => length_of(engine, "a.txt")
    // Another world with other bytes in the same file, as a host function
    // that compiles inside a compilation has.
    let other = ReadWorld::new()
    other.files["a.txt"] = b"abc"
    let inner = TrackedWorld::new(other)
    t.scope(engine => {
      assert_eq(t.call(engine, 1, body), 1)
      // Found and stamped in the outer scope.
      assert_eq(t.call(engine, 1, body), 1)
      assert_eq(t.ran(1), 1)
      inner.open()
      {
        let engine = { ..engine, world: inner, }
        assert_eq(t.call(engine, 1, body), 3)
        assert_eq(t.call(engine, 1, body), 3)
      }
      inner.close()
      assert_eq(t.ran(1), 2)
      // Each world gets its own answers, also afterwards.
      assert_eq(t.call(engine, 1, body), 1)
      assert_eq(t.ran(1), 2)
    })
    // The same when the inner scope fails with an error.
    t.scope(engine => {
      let failed = try
        inner.scoped(() => {
          let engine = { ..engine, world: inner, }
          t.call(engine, 1, body) |> ignore
          if true {
            raise SourceError([])
          }
        })
      catch {
        _ => true
      } noraise {
        _ => false
      }
      assert_true(failed)
      assert_true(inner.scope is None)
      assert_eq(t.call(engine, 1, body), 1)
    })
    assert_eq(t.ran(1), 2)
  })
}

///|
test "world reads: a call that reads through another tracked world is not kept" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    let other = ReadWorld::new()
    other.files["a.txt"] = b"abc"
    // In a scope of its own, and in none.
    let scoped = TrackedWorld::new(other)
    let unscoped = TrackedWorld::new(other)
    scoped.open()
    defer scoped.close()
    let body : ReadBody = engine => {
      length_of(engine, "a.txt") +
      length_of({ ..engine, world: scoped, }, "a.txt")
    }
    let through : ReadBody = engine => {
      length_of({ ..engine, world: unscoped, }, "a.txt")
    }
    t.scope(engine => {
      assert_eq(t.call(engine, 1, body), 4)
      assert_eq(t.call(engine, 1, body), 4)
      assert_eq(t.call(engine, 2, through), 3)
      assert_eq(t.call(engine, 2, through), 3)
      // A call that makes its own reads only is kept beside them.
      assert_eq(t.call(engine, 3, engine => length_of(engine, "a.txt")), 1)
      assert_eq(t.call(engine, 3, engine => length_of(engine, "a.txt")), 1)
    })
    assert_eq((t.ran(1), t.ran(2), t.ran(3)), (2, 2, 1))
    assert_eq(recording_worlds.length(), 0)
    // The same for what is found for the other world instead of read
    // through it: a call of the other world that is kept, and a call of
    // this world that finds it.
    let inner : ReadBody = engine => {
      t.call({ ..engine, world: scoped, }, 4, engine => {
        length_of(engine, "a.txt")
      })
    }
    assert_eq(inner(t.engine()), 3)
    t.scope(engine => {
      assert_eq(t.call(engine, 5, inner), 3)
      assert_eq(t.call(engine, 5, inner), 3)
    })
    assert_eq((t.ran(4), t.ran(5)), (1, 2))
    // And for a scope of another world that is opened during a call: a
    // compilation may depend on its world without a tracked read.
    let compiling : ReadBody = _ => {
      let other = TrackedWorld::new(ReadWorld::new())
      other.scoped(() => 7)
    }
    t.scope(engine => {
      assert_eq(t.call(engine, 6, compiling), 7)
      assert_eq(t.call(engine, 6, compiling), 7)
    })
    assert_eq(t.ran(6), 2)
  })
}

///|
test "world reads: nothing is kept for a world that is in no scope" {
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    let body = (engine : Engine) => length_of(engine, "a.txt")
    let engine = t.engine()
    assert_eq(t.call(engine, 1, body), 1)
    t.world.files["a.txt"] = b"abc"
    assert_eq(t.call(engine, 1, body), 3)
    assert_eq(t.ran(1), 2)
    inspect(t.kept(1), content="")
  })
}

///|
test "world reads: a read that is in the part of the call in progress is not logged again" {
  read_test(t => {
    t.world.book = FontBook::from_infos([read_info("One")])
    t.world.fonts.push(Some(read_font(b"font one")))
    let lengths = []
    t.scope(engine => {
      guard engine.world.scope is Some(scope) else { fail("no scope") }
      t.call(engine, 1, engine => {
        for _ in 0..<100 {
          engine.world.book() |> ignore
          engine.world.font(0) |> ignore
        }
        lengths.push(scope.log.length())
        // A call inside logs them in its own part, once.
        t.call(engine, 2, engine => {
          for _ in 0..<100 {
            engine.world.book() |> ignore
            engine.world.font(0) |> ignore
          }
          lengths.push(scope.log.length())
          0
        })
        |> ignore
        for _ in 0..<100 {
          engine.world.font(0) |> ignore
          engine.world.book() |> ignore
        }
        lengths.push(scope.log.length())
        0
      })
      |> ignore
    })
    assert_eq(lengths, [2, 4, 4])
    inspect(t.kept(1), content="book, font(0)")
    inspect(t.kept(2), content="book, font(0)")
  })
}

///|
test "memo check: an entry that lacks a read of its run is reported" {
  set_memo_check(true)
  defer set_memo_check(false)
  take_memo_check_report() |> ignore
  read_test(t => {
    t.world.files["a.txt"] = b"a"
    t.world.files["b.txt"] = b"b"
    t.scope(engine => {
      // Complete.
      t.call(engine, 1, engine => {
        length_of(engine, "a.txt") +
        t.call(engine, 2, engine => length_of(engine, "b.txt"))
      })
      |> ignore
      let (checked, failures) = take_memo_check_report()
      assert_eq(checked, 2)
      inspect(failures.join("\n"), content="")
      // A call that reaches the world around the tracked methods.
      t.call(engine, 3, engine => {
        engine.world.raw.file(memo_file("a.txt")).length() catch {
          _ => 0
        }
      })
      |> ignore
      let (checked, failures) = take_memo_check_report()
      assert_eq(checked, 1)
      assert_eq(failures.length(), 1)
      assert_true(failures[0].contains("a run from scratch asked [file(a.txt)"))
      // A hit whose reads would not reach its caller: the entry of the
      // caller is compared with a run in which the call inside is made.
      t.call(engine, 4, engine => {
        guard engine.world.scope is Some(scope) else { return 0 }
        let before = scope.log.length()
        let n = t.call(engine, 2, engine => length_of(engine, "b.txt"))
        scope.log.truncate(before)
        n
      })
      |> ignore
      let (_, failures) = take_memo_check_report()
      assert_eq(failures.length(), 1)
      assert_true(failures[0].contains("kept [],"))
    })
  })
}
