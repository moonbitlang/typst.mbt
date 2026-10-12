// The accelerator of introspector reads (`introspector.mbt`,
// `ReadAccelerator`): the answers of an introspector are computed once and
// kept by its number, for the documents that are found again with the
// introspector they had (`docs/incremental-design.md`, slice 3).

///|
/// The number of introspectors whose answers the accelerator keeps.
fn read_accelerator_tables() -> Int32 {
  read_accelerator.tables.length()
}

///|
/// A recorder of `n` reads whose replays count themselves in `replays`
/// and answer what was expected of them.
fn counting_reads(n : Int32, replays : Ref[Int32]) -> IntrospectionRecorder {
  let recorder = IntrospectionRecorder::new()
  for i in 0..<n {
    let key = hash128(("read", i))
    let expected = hash128(i)
    recorder.calls[key] = {
      name: "read",
      expected,
      replay: _ => {
        replays.val += 1
        expected
      },
      hosts: None,
    }
  }
  recorder
}

///|
test "read accelerator: the answers of an introspector are kept by its number" {
  evict(0)
  let replays = Ref(0)
  let reads = counting_reads(3, replays)
  let first = wb_introspector(sample())
  let second = wb_introspector(sample())
  assert_true(reads.validate(first))
  inspect(replays.val, content="3")
  // Another introspector is asked for itself.
  assert_true(reads.validate(second))
  inspect(replays.val, content="6")
  // And the first again, and what tracks it or does not: one number.
  assert_true(reads.validate(first))
  assert_true(reads.validate(first.track_with(IntrospectionRecorder::new())))
  assert_true(reads.validate(second.untracked()))
  inspect(replays.val, content="6")
  inspect(read_accelerator_tables(), content="2")
  // A read that was not asked of it yet is replayed, the others are not.
  let more = counting_reads(5, replays)
  assert_true(more.validate(first))
  inspect(replays.val, content="8")
}

///|
test "read accelerator: answers stay for the compilation after the one that asked" {
  evict(0)
  let replays = Ref(0)
  let reads = counting_reads(3, replays)
  let kept = wb_introspector(sample())
  let other = wb_introspector(sample())
  assert_true(reads.validate(kept))
  assert_true(reads.validate(other))
  inspect(replays.val, content="6")
  // A watching compiler evicts after every compilation. What the next
  // compilation asks again stays known for as long as it is asked.
  for _ in 0..<12 {
    evict(10)
    assert_true(reads.validate(kept))
  }
  inspect(replays.val, content="6")
  // What was not asked for in two evictions in a row is gone: the
  // introspector of a document that no compilation finds any more.
  inspect(read_accelerator_tables(), content="1")
  assert_true(reads.validate(other))
  inspect(replays.val, content="9")
  evict(10)
  inspect(read_accelerator_tables(), content="2")
  evict(10)
  inspect(read_accelerator_tables(), content="0")
  assert_true(reads.validate(kept))
  inspect(replays.val, content="12")
  // `evict(0)` drops everything.
  evict(0)
  inspect(read_accelerator_tables(), content="0")
  assert_true(reads.validate(kept))
  inspect(replays.val, content="15")
}

///|
test "read accelerator: of an introspector that stays, the answers that are no longer asked for go" {
  // A document that is found in every compilation is asked the reads of
  // whatever changes around it. What a compilation did not ask is gone
  // after the eviction that follows the next one.
  evict(0)
  let replays = Ref(0)
  let many = counting_reads(6, replays)
  let few = counting_reads(3, replays)
  let kept = wb_introspector(sample())
  assert_true(many.validate(kept))
  inspect(replays.val, content="6")
  evict(10)
  // Known from the compilation before.
  assert_true(few.validate(kept))
  assert_true(many.validate(kept))
  inspect(replays.val, content="6")
  evict(10)
  assert_true(few.validate(kept))
  inspect(replays.val, content="6")
  evict(10)
  // The three that the last compilation did not ask are computed again.
  assert_true(many.validate(kept))
  inspect(replays.val, content="9")
  inspect(read_accelerator_tables(), content="1")
  evict(0)
}

///|
test "read accelerator: the answers of the empty introspectors are not a table" {
  evict(0)
  let replays = Ref(0)
  let reads = counting_reads(3, replays)
  let document = wb_introspector(sample())
  // All empty introspectors have one number, and every compilation asks
  // one of reads that hold its own locations: their answers are kept
  // while the empty introspector is the one that is asked.
  assert_true(reads.validate(Introspector::empty()))
  assert_true(reads.validate(Introspector::empty()))
  inspect(replays.val, content="3")
  inspect(read_accelerator_tables(), content="0")
  assert_true(reads.validate(document))
  inspect(read_accelerator_tables(), content="1")
  assert_true(reads.validate(Introspector::empty()))
  inspect(replays.val, content="9")
  inspect(read_accelerator_tables(), content="1")
}

///|
test "read accelerator: a process that never evicts keeps the answers of a few introspectors" {
  evict(0)
  let replays = Ref(0)
  let reads = counting_reads(2, replays)
  let first = wb_introspector(sample())
  assert_true(reads.validate(first))
  for _ in 0..<40 {
    assert_true(reads.validate(wb_introspector(sample())))
    // The first is asked again and again and stays.
    assert_true(reads.validate(first))
  }
  inspect(replays.val, content="82")
  inspect(read_accelerator_tables(), content="16")
  evict(0)
}

///|
test "read accelerator: an answer is that of its introspector and of its read" {
  evict(0)
  // The recorded reads of the sample document are rejected by a document
  // with one element more, whichever of the two was asked first and
  // however often.
  let recorder = IntrospectionRecorder::new()
  let first = wb_introspector(sample()).track_with(recorder)
  let metadata = metadata_elem().select()
  ignore(first.query(metadata))
  ignore(first.query_count_before(metadata, loc(4)))
  let builder = ElementIntrospectorBuilder::new()
  discover(builder, meta(1), [meta(2), meta(3)])
  discover(builder, meta(4, label="a"), [meta(5, label="b")])
  discover(builder, meta(6, label="b"), [])
  discover(builder, meta(7), [])
  let longer = wb_introspector(builder.finalize())
  let same = wb_introspector(sample())
  for _ in 0..<3 {
    assert_true(recorder.validate(first))
    assert_false(recorder.validate(longer))
    assert_true(recorder.validate(same))
    assert_false(recorder.validate(Introspector::empty()))
    evict(10)
  }
  evict(0)
}
