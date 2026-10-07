// Tests of the bridge from `@fs.Watcher` to notify's interface: which
// events a change is reported as, and for which paths.

///|
fn EventKind::name(self : EventKind) -> String {
  match self {
    Create(Any) => "create"
    Modify(Data(Any)) => "modify"
    Modify(Name(From)) => "rename from"
    Modify(Name(To)) => "rename to"
    Remove(File) => "remove"
    _ => "?"
  }
}

///|
/// The events that arrive until none arrives for a while, in order.
///
/// How a change is reported depends on when the directory was scanned and
/// on the backend, so repetitions of an event are left out, and so is the
/// modification of a file whose removal or creation is reported as well.
async fn drain(rx : Receiver, dir : String) -> String {
  let events : Array[String] = []
  while rx.recv_timeout(Some(if events.is_empty() { 5000 } else { 400 }))
        is Some(event) {
    guard event is Ok(event) else {
      events.push("error")
      continue
    }
    let paths = event.paths.map(path => {
      if path.has_prefix(dir + "/") {
        path[dir.length() + 1:].to_owned()
      } else {
        path
      }
    })
    let event = "\{event.kind.name()} \{paths.join(" ")}"
    if !events.contains(event) {
      events.push(event)
    }
  }
  events
  .filter(event => {
    guard event.strip_prefix("modify ") is Some(path) else { return true }
    !(events.contains("remove \{path}") || events.contains("create \{path}"))
  })
  .join(", ")
}

///|
test "split_path" {
  @debug.debug_inspect(
    split_path("/project/chapters/intro.typ"),
    content=(
      #|Some(("/project/chapters", "intro.typ"))
    ),
  )
  @debug.debug_inspect(
    split_path("main.typ"),
    content=(
      #|Some((".", "main.typ"))
    ),
  )
  @debug.debug_inspect(
    split_path("/main.typ"),
    content=(
      #|Some(("/", "main.typ"))
    ),
  )
  @debug.debug_inspect(
    split_path("figures/"),
    content=(
      #|Some((".", "figures"))
    ),
  )
  @debug.debug_inspect(split_path("/"), content="None")
  @debug.debug_inspect(split_path(".."), content="None")
}

///|
test "name_key" {
  inspect(name_key("Main.TYP"), content="main.typ")
  // Precomposed and decomposed spellings of a name are one entry.
  inspect(name_key("\u{e9}.typ") == name_key("e\u{301}.typ"), content="true")
  inspect(name_key("a.typ") == name_key("b.typ"), content="false")
}

///|
async test "the events of changes to watched paths" {
  @async.with_task_group(group => {
    let dir = scratch("events")
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    write(a, "a")
    write(b, "b")
    write("\{dir}/other.typ", "other")
    let (watcher, rx) = RecommendedWatcher::new(group)
    watcher.watch(a)
    watcher.watch(b)
    // Nothing is watched before the commit.
    write(a, "early")
    inspect(rx.recv_timeout(Some(300)) is None, content="true")
    watcher.commit()

    // A file that is not watched.
    write("\{dir}/other.typ", "changed")
    @fs.remove("\{dir}/other.typ")
    inspect(rx.recv_timeout(Some(400)) is None, content="true")

    // Writing in place.
    write(a, "changed")
    inspect(drain(rx, dir), content="modify a.typ")

    // Replacing by a rename: the name gets another file.
    write("\{dir}/a.typ.tmp", "replaced")
    @fs.rename("\{dir}/a.typ.tmp", a, replace=true)
    inspect(drain(rx, dir), content="remove a.typ, create a.typ")
    // The new file is followed.
    write(a, "changed again")
    inspect(drain(rx, dir), content="modify a.typ")

    // Removing and creating.
    @fs.remove(b)
    inspect(drain(rx, dir), content="remove b.typ")
    write(b, "back")
    inspect(drain(rx, dir), content="create b.typ")

    // Renaming one watched path to another.
    @fs.remove(b)
    inspect(drain(rx, dir), content="remove b.typ")
    @fs.rename(a, b)
    inspect(drain(rx, dir), content="rename from a.typ, rename to b.typ")
  })
}

///|
async test "an unwatched path is reported until the next commit" {
  @async.with_task_group(group => {
    let dir = scratch("retired")
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    write(a, "a")
    write(b, "b")
    let (watcher, rx) = RecommendedWatcher::new(group)
    watcher.watch(a)
    watcher.watch(b)
    watcher.commit()
    watcher.unwatch(a)
    write(a, "changed")
    inspect(drain(rx, dir), content="modify a.typ")
    watcher.commit()
    write(a, "changed again")
    inspect(rx.recv_timeout(Some(400)) is None, content="true")
    // The watcher still serves the other path.
    write(b, "changed")
    inspect(drain(rx, dir), content="modify b.typ")
  })
}

///|
async test "a name that is spelled differently in the directory" {
  @async.with_task_group(group => {
    let dir = scratch("spelling")
    write("\{dir}/Chapter.typ", "a")
    let (watcher, rx) = RecommendedWatcher::new(group)
    // As a case-insensitive file system lets a document spell it.
    let path = "\{dir}/chapter.typ"
    watcher.watch(path)
    watcher.commit()
    write("\{dir}/Chapter.typ", "changed")
    inspect(drain(rx, dir), content="modify chapter.typ")
  })
}

///|
async test "a directory that cannot be watched" {
  @async.with_task_group(group => {
    let dir = scratch("gone")
    let (watcher, _) = RecommendedWatcher::new(group)
    watcher.watch("\{dir}/missing/a.typ")
    // Like notify's error for a path it cannot watch: the `io::Error` and
    // the path.
    try watcher.commit() catch {
      err =>
        inspect(
          err,
          content=(
            #|No such file or directory (os error 2) about ["_build/kit_watcher_test/gone/missing/a.typ"]
          ),
        )
    } noraise {
      _ => fail("expected an error")
    }
  })
}
