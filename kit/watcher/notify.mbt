// The slice of the `notify` crate (8.0.0, with `notify-types` 2.0.0) that
// `typst_kit::watcher` uses, on top of `moonbitlang/async`'s `@fs.Watcher`:
// the event kinds, `RecommendedWatcher` (`watch`, `unwatch`) and the
// channel it sends its events to.
//
// The two watchers differ, and this file is the bridge:
//
// - notify watches the paths it is given, each one on its own
//   (`RecursiveMode::NonRecursive`). `@fs.Watcher` watches one directory
//   recursively and tells which entries it follows through `ignored_paths`.
//   A path is therefore watched through a watcher of its parent directory
//   that ignores every other entry (and with them everything below the
//   directory's subdirectories). One watcher serves all the paths of a
//   directory that are registered together. `ignored_paths` is consulted
//   when a directory is scanned, so a path that is registered later gets a
//   watcher of its own instead of a place in a running one. Hence `watch`
//   only records the path, and `commit` starts the watchers.
// - `@fs.Watcher` follows names: when an entry is removed and created
//   again (or replaced by a rename, as editors that write a temporary file
//   do), it follows the new file. notify's inotify backend follows the
//   inode and drops the watch, which `Watcher::wait` works around by
//   unwatching the path and watching it again after the next compilation.
//   The bridge keeps that protocol, because the directory itself may be
//   the thing that was replaced (`rm -r figures; mkdir figures; ..`), and
//   then only a new watcher sees the new files: a removal is reported as
//   `Remove(File)` and a rename away as `Modify(Name(From))`. What the
//   bridge adds is that a path stays reported between `unwatch` and the
//   `commit` that follows (and its old watcher a moment longer): events
//   that arrive while the compilation runs are not lost, as they are with
//   notify until the path is watched again.
// - `@fs.Watcher` reports the net change of a directory since the last
//   `wait` (`Modify`, `Create`, `Remove`, `Rename`), not single operations:
//   access, metadata and the kinds of a data change are not told apart. Its
//   own debouncing is turned off, the batching is `Watcher::wait`'s.
// - Not watched: the entries of a watched directory (a dependency that is a
//   directory only reports its own removal and creation), and a watched
//   directory that is renamed while its files stay (notify's FSEvents
//   backend follows paths and reports it; its inotify backend does not
//   either).

///|
/// An event describing open or close operations on files
/// (`notify_types::event::AccessMode`).
// Only matched, never reported by `@fs.Watcher`.
#warnings("-unused_constructor")
priv enum AccessMode {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// The file was executed, or the folder opened.
  Execute
  /// The file was opened for reading.
  Read
  /// The file was opened for writing.
  Write
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing non-mutating access operations on files
/// (`notify_types::event::AccessKind`).
#warnings("-unused_constructor")
priv enum AccessKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the file is read.
  Read
  /// An event emitted when the file, or a handle to the file, is opened.
  Open(AccessMode)
  /// An event emitted when the file, or a handle to the file, is closed.
  Close(AccessMode)
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing creation operations on files
/// (`notify_types::event::CreateKind`).
#warnings("-unused_constructor")
priv enum CreateKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event which results in the creation of a file.
  File
  /// An event which results in the creation of a folder.
  Folder
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event emitted when the data content of a file is changed
/// (`notify_types::event::DataChange`).
#warnings("-unused_constructor")
priv enum DataChange {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the size of the data is changed.
  Size
  /// An event emitted when the content of the data is changed.
  Content
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event emitted when the metadata of a file or folder is changed
/// (`notify_types::event::MetadataKind`).
#warnings("-unused_constructor")
priv enum MetadataKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the access time of the file or folder is changed.
  AccessTime
  /// An event emitted when the write or modify time of the file or folder is
  /// changed.
  WriteTime
  /// An event emitted when the permissions of the file or folder are
  /// changed.
  Permissions
  /// An event emitted when the ownership of the file or folder is changed.
  Ownership
  /// An event emitted when an extended attribute of the file or folder is
  /// changed.
  Extended
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event emitted when the name of a file or folder is changed
/// (`notify_types::event::RenameMode`).
#warnings("-unused_constructor")
priv enum RenameMode {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted on the file or folder resulting from a rename.
  To
  /// An event emitted on the file or folder that was renamed.
  From
  /// A single event emitted with both the `From` and `To` paths.
  Both
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing mutation of content, name, or metadata
/// (`notify_types::event::ModifyKind`).
#warnings("-unused_constructor-unused_field")
priv enum ModifyKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when the data content of a file is changed.
  Data(DataChange)
  /// An event emitted when the metadata of a file or folder is changed.
  Metadata(MetadataKind)
  /// An event emitted when the name of a file or folder is changed.
  Name(RenameMode)
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// An event describing removal operations on files
/// (`notify_types::event::RemoveKind`).
#warnings("-unused_constructor")
priv enum RemoveKind {
  /// The catch-all case, to be used when the specific kind of event is
  /// unknown.
  Any
  /// An event emitted when a file is removed.
  File
  /// An event emitted when a folder is removed.
  Folder
  /// An event which specific kind is known but cannot be represented
  /// otherwise.
  Other
}

///|
/// Top-level event kind (`notify_types::event::EventKind`).
#warnings("-unused_constructor-unused_field")
priv enum EventKind {
  /// The catch-all event kind, for unsupported/unknown events.
  Any
  /// An event describing non-mutating access operations on files.
  Access(AccessKind)
  /// An event describing creation operations on files.
  Create(CreateKind)
  /// An event describing mutation of content, name, or metadata.
  Modify(ModifyKind)
  /// An event describing removal operations on files.
  Remove(RemoveKind)
  /// An event not fitting in any of the above four categories.
  Other
}

///|
/// Notify event (`notify_types::event::Event`; its attributes are not read
/// by typst-kit).
priv struct Event {
  /// Kind or type of the event.
  kind : EventKind
  /// Paths the event is about, if known.
  paths : Array[String]
}

///|
/// An error of the watcher (`notify::Error`: the `Display` of its kind, and
/// the path it is about).
priv suberror NotifyError {
  NotifyError(String, path~ : String?)
}

///|
impl Show for NotifyError with fn output(self, logger) {
  let NotifyError(error, path~) = self
  match path {
    None => logger.write_string(error)
    Some(path) =>
      logger.write_string("\{error} about [\{@unicode.rust_debug_str(path)}]")
  }
}

///|
/// An error of `@fs.Watcher` for a path as notify reports it: an
/// `io::Error`, but an exhausted inotify as `ErrorKind::MaxFilesWatch`
/// (notify-8.0.0/src/inotify.rs:448).
fn NotifyError::io(err : Error, path : String?) -> NotifyError {
  let error = match err {
    @os_error.OSError(28, ..) if @platform.os() == Linux =>
      "OS file watch limit reached."
    @os_error.OSError(errno, ..) => @platform.os_error(errno).to_string()
    err => err.to_string()
  }
  NotifyError(error, path~)
}

///|
/// The receiving half of the channel of events
/// (`std::sync::mpsc::Receiver<notify::Result<Event>>`).
priv struct Receiver(@aqueue.Queue[Result[Event, NotifyError]])

///|
/// Waits for a value for at most `timeout` milliseconds (`None`: upstream's
/// `Duration::MAX`).
async fn Receiver::recv_timeout(
  self : Receiver,
  timeout : Int?,
) -> Result[Event, NotifyError]? noraise {
  // An error is a channel without a sender, which upstream treats like a
  // timeout (`Result::into_iter`, `.ok()`).
  match timeout {
    None => Some(self.0.get()) catch { _ => None }
    Some(timeout) =>
      @async.with_timeout_opt(timeout, () => self.0.get()) catch {
        _ => None
      }
  }
}

///|
/// A `@fs.Watcher` of one directory.
priv struct DirWatcher {
  /// The paths the watcher was started for, by the key of their file names.
  /// This is what `ignored_paths` lets through, for as long as it runs.
  names : Map[String, Array[String]]
  /// How many of these paths are still watched through it.
  mut owned : Int
  /// The task that forwards its events.
  mut task : @async.Task[Unit]?
}

///|
/// How a path is watched.
priv enum Watch {
  /// Recorded by `watch`; watched from the next `commit` on.
  Pending
  /// Watched through this watcher.
  Watched(DirWatcher)
}

///|
/// The watcher (`notify::RecommendedWatcher`).
priv struct RecommendedWatcher {
  /// The sending half of the channel of events.
  tx : @aqueue.Queue[Result[Event, NotifyError]]
  /// The tasks that forward the events of the directories' watchers belong
  /// to this group (notify has a thread of its own).
  group : @async.TaskGroup[Unit]
  /// The watched paths.
  paths : Map[String, Watch]
  /// The paths that were unwatched since the last `commit`. Their events
  /// are still reported.
  retired : Map[String, Unit]
  /// The watchers no path is watched through any more, to be stopped by the
  /// next `commit`.
  idle : Array[DirWatcher]
}

///|
/// How long a watcher that is no longer needed keeps running after a
/// `commit`, in milliseconds: long enough to report what happened to its
/// files before the `commit` (events the operating system queued while a
/// compilation was running).
const LINGER : Int = 1000

///|
/// Creates the watcher and the channel it sends its events to
/// (`std::sync::mpsc::channel` and `RecommendedWatcher::new`).
fn RecommendedWatcher::new(
  group : @async.TaskGroup[Unit],
) -> (RecommendedWatcher, Receiver) {
  let tx = @aqueue.Queue(kind=Unbounded)
  ({ tx, group, paths: Map([]), retired: Map([]), idle: [], }, Receiver(tx))
}

///|
/// Begins watching a new path (`Watcher::watch` with
/// `RecursiveMode::NonRecursive`). The path is watched from the next
/// [`commit`](Self::commit) on.
fn RecommendedWatcher::watch(self : RecommendedWatcher, path : String) -> Unit {
  if !self.paths.contains(path) {
    self.paths[path] = Pending
  }
}

///|
/// Stops watching a path (`Watcher::unwatch`; upstream ignores its error
/// for a path that is not watched).
fn RecommendedWatcher::unwatch(
  self : RecommendedWatcher,
  path : String,
) -> Unit {
  match self.paths.get(path) {
    None => ()
    Some(Pending) => self.paths.remove(path)
    Some(Watched(watcher)) => {
      self.paths.remove(path)
      self.retired[path] = ()
      watcher.owned -= 1
      if watcher.owned == 0 {
        self.idle.push(watcher)
      }
    }
  }
}

///|
/// The directory to watch for a path, and the path's name in it.
fn split_path(path : String) -> (String, String)? {
  guard @platform.file_name(path) is Some(name) else { return None }
  let dir = match @platform.parent(path) {
    Some("") | None => "."
    Some(dir) => dir
  }
  Some((dir, name))
}

///|
/// The key under which the names of a directory's entries are compared.
///
/// A file system that ignores case or normalizes names (APFS, HFS+, NTFS)
/// opens a file under a name that differs from the entry `@fs.Watcher`
/// reads from the directory. Matching too much only costs a compilation;
/// a file whose entry is not found under this key (a file system that
/// folds names in yet another way) is not watched.
fn name_key(name : StringView) -> String {
  @unicode.to_lowercase(@unicode.nfd(name))
}

///|
/// Starts watching the paths recorded by [`watch`](Self::watch) and stops
/// the watchers that are no longer needed.
async fn RecommendedWatcher::commit(
  self : RecommendedWatcher,
) -> Unit raise NotifyError {
  // One watcher per directory for the new paths.
  let dirs : Map[String, DirWatcher] = Map([])
  for path, watch in self.paths {
    guard watch is Pending else { continue }
    guard split_path(path) is Some((dir, name)) else {
      raise NotifyError("No path was found.", path=Some(path))
    }
    let watcher = match dirs.get(dir) {
      Some(watcher) => watcher
      None => {
        let watcher = { names: Map([]), owned: 0, task: None, }
        dirs[dir] = watcher
        watcher
      }
    }
    let key = name_key(name)
    match watcher.names.get(key) {
      Some(paths) => paths.push(path)
      None => watcher.names[key] = [path]
    }
    watcher.owned += 1
  }
  for dir, watcher in dirs {
    let names = watcher.names
    let inner = @fs.Watcher(dir, debounce_timeout=0, ignored_paths=path => {
      !names.contains(name_key(path))
    }) catch {
      err => {
        let mut first = None
        for paths in names.values() {
          first = Some(paths[0])
          break
        }
        raise NotifyError::io(err, first)
      }
    }
    for paths in names.values() {
      for path in paths {
        self.paths[path] = Watched(watcher)
      }
    }
    watcher.task = Some(
      self.group.spawn(no_wait=true, () => self.forward(watcher, inner)),
    )
  }

  // From here on the new watchers report the paths that were unwatched and
  // watched again; the others are forgotten.
  self.retired.clear()
  for watcher in self.idle {
    guard watcher.task is Some(task) else { continue }
    self.group.spawn_bg(no_wait=true, () => {
      @async.sleep(LINGER)
      task.cancel()
    })
  }
  self.idle.clear()
}

///|
/// Whether events of a path are reported: it is watched, or it was until a
/// moment ago.
fn RecommendedWatcher::reports(
  self : RecommendedWatcher,
  path : String,
) -> Bool {
  self.paths.contains(path) || self.retired.contains(path)
}

///|
/// Sends an event for every reported path with the given name in a
/// watcher's directory.
async fn RecommendedWatcher::send(
  self : RecommendedWatcher,
  watcher : DirWatcher,
  name : String,
  kind : EventKind,
) -> Unit {
  guard watcher.names.get(name_key(name)) is Some(paths) else { return }
  for path in paths {
    if self.reports(path) {
      self.tx.put(Ok({ kind, paths: [path], }))
    }
  }
}

///|
/// Translates the events of a directory's watcher and sends them to the
/// channel, until the task is cancelled.
async fn RecommendedWatcher::forward(
  self : RecommendedWatcher,
  watcher : DirWatcher,
  inner : @fs.Watcher,
) -> Unit {
  defer inner.close()
  for ;; {
    let events = inner.wait() catch {
      _ => {
        // The watcher gave up, which is what happens when its directory is
        // removed. Its paths are not watched any more: report that like
        // notify reports the watches it drops.
        for paths in watcher.names.values() {
          for path in paths {
            if self.reports(path) {
              self.tx.put(Ok({ kind: Remove(File), paths: [path], }))
            }
          }
        }
        return
      }
    }
    for event in events {
      match event {
        Modify(name) => self.send(watcher, name, Modify(Data(Any)))
        Create(name) => self.send(watcher, name, Create(Any))
        Remove(name) => self.send(watcher, name, Remove(File))
        Rename(old~, new~) => {
          self.send(watcher, old, Modify(Name(From)))
          self.send(watcher, new, Modify(Name(To)))
        }
      }
    }
  }
}
