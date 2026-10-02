// Port of the unit tests of `fancy-regex` 0.16.2 `src/vm.rs`.

///|
test "state_push_pop" {
  let state = State::new(1, MAX_STACK)
  state.push(0, 0)
  state.push(1, 1)
  assert_eq(state.pop(), (1, 1))
  assert_eq(state.pop(), (0, 0))
  assert_true(state.stack_pc.is_empty())
  state.push(2, 2)
  assert_eq(state.pop(), (2, 2))
  assert_true(state.stack_pc.is_empty())
}

///|
test "state_save_override" {
  let state = State::new(1, MAX_STACK)
  state.save(0, 10)
  state.push(0, 0)
  state.save(0, 20)
  assert_eq(state.pop(), (0, 0))
  assert_eq(state.get(0), 10)
}

///|
test "state_save_override_twice" {
  let state = State::new(1, MAX_STACK)
  state.save(0, 10)
  state.push(0, 0)
  state.save(0, 20)
  state.push(1, 1)
  state.save(0, 30)
  assert_eq(state.get(0), 30)
  assert_eq(state.pop(), (1, 1))
  assert_eq(state.get(0), 20)
  assert_eq(state.pop(), (0, 0))
  assert_eq(state.get(0), 10)
}

///|
test "state_explicit_stack" {
  let state = State::new(1, MAX_STACK)
  state.stack_push(11)
  state.stack_push(12)
  state.push(100, 101)
  state.stack_push(13)
  assert_eq(state.stack_pop(), 13)
  state.stack_push(14)
  assert_eq(state.pop(), (100, 101))

  // Note: 14 is not there because it was pushed as part of the backtrack branch
  assert_eq(state.stack_pop(), 12)
  assert_eq(state.stack_pop(), 11)
}

///|
test "state_backtrack_cut_simple" {
  let state = State::new(2, MAX_STACK)
  state.save(0, 1)
  state.save(1, 2)
  let count = state.backtrack_count()
  state.push(0, 0)
  state.save(0, 3)
  assert_eq(state.backtrack_count(), 1)
  state.backtrack_cut(count)
  assert_eq(state.backtrack_count(), 0)
  assert_eq(state.get(0), 3)
  assert_eq(state.get(1), 2)
}

///|
test "state_backtrack_cut_complex" {
  let state = State::new(2, MAX_STACK)
  state.save(0, 1)
  state.save(1, 2)
  state.push(0, 0)
  state.save(0, 3)
  let count = state.backtrack_count()
  state.push(1, 1)
  state.save(0, 4)
  state.push(2, 2)
  state.save(1, 5)
  assert_eq(state.backtrack_count(), 3)
  state.backtrack_cut(count)
  assert_eq(state.backtrack_count(), 1)
  assert_eq(state.get(0), 4)
  assert_eq(state.get(1), 5)
  state.pop() |> ignore
  assert_eq(state.backtrack_count(), 0)
  // Check that oldsave were set correctly
  assert_eq(state.get(0), 1)
  assert_eq(state.get(1), 2)
}

///|
priv enum Operation {
  Push
  Pop
  Save(Int, Int)
}

///|
fn check_saves_for_operations(operations : Array[Operation]) -> Bool raise {
  let mut slots = 0
  for o in operations {
    if o is Save(slot, _) && slot + 1 > slots {
      slots = slot + 1
    }
  }
  if slots == 0 {
    // No point checking if there's no save instructions
    return true
  }

  // Stack with the complete VM state (including saves)
  let stack : Array[Array[Int]] = []
  let mut saves = Array::make(slots, USIZE_MAX)
  let state = State::new(slots, MAX_STACK)
  let expected = []
  let actual = []
  for operation in operations {
    match operation {
      Push => {
        // We're not checking pc and ix later, so don't bother
        // putting in random values.
        stack.push(saves.copy())
        state.push(0, 0)
      }
      Pop =>
        // Note that because we generate the operations randomly
        // there might be more pops than pushes. So ignore a pop
        // if the stack was empty.
        if stack.pop() is Some(previous_saves) {
          saves = previous_saves
          state.pop() |> ignore
        }
      Save(slot, value) => {
        saves[slot] = value
        state.save(slot, value)
      }
    }

    // Remember state of saves for checking later
    expected.push(saves.copy())
    actual.push(Array::makei(slots, i => state.get(i)))
  }
  expected == actual
}

///|
/// Replaces upstream's quickcheck property with deterministic pseudo-random
/// operation sequences.
test "state_save_quickcheck" {
  let mut seed = 12345
  let next = () => {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    seed
  }
  for _ in 0..<500 {
    let n = next() % 60
    let ops = []
    for _ in 0..<n {
      ops.push(
        match next() % 3 {
          0 => Push
          1 => Pop
          _ => Save(next() % 5, next())
        },
      )
    }
    assert_true(check_saves_for_operations(ops))
  }
}
