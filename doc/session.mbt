// Compilation sessions (docs/edsl-design.md, sections 5, 11.2 and 12.2):
// the state shared by initial lowering and by the lowering of callback
// results during one compilation.

///|
priv struct Session {
  /// The caller's world.
  base : &@library.World
  /// The origin registry.
  registry : Registry
  /// The host function of each callback description (by serial): one per
  /// description and compilation.
  hosts : Map[Int, @library.HostFunc]
  /// The serial of the first callback description that did not exist when
  /// the compilation started.
  start_serial : Int
}

///|
fn Session::new(base : &@library.World, dir? : String = "") -> Session {
  {
    base,
    registry: Registry::new(dir~),
    hosts: {},
    start_serial: callback_serial.val,
  }
}

///|
/// The world of a session: the caller's world plus the session's virtual
/// source files (the origin listing and the markup snippets).
priv struct SessionWorld {
  session : Session
}

///|
impl @library.World for SessionWorld with fn library(self) {
  self.session.base.library()
}

///|
impl @library.World for SessionWorld with fn main(self) {
  self.session.registry.origins
}

///|
impl @library.World for SessionWorld with fn source(self, id) {
  match self.session.registry.virtual_source(id) {
    Some(source) => source
    None => self.session.base.source(id)
  }
}

///|
impl @library.World for SessionWorld with fn file(self, id) {
  match self.session.registry.virtual_source(id) {
    Some(source) => @utf8.encode(source.text())
    None => self.session.base.file(id)
  }
}

///|
impl @library.World for SessionWorld with fn book(self) {
  self.session.base.book()
}

///|
impl @library.World for SessionWorld with fn font(self, index) {
  self.session.base.font(index)
}

///|
impl @library.World for SessionWorld with fn today(self, offset) {
  self.session.base.today(offset)
}

///|
/// An error diagnostic at a span.
fn error_at(span : @syntax.Span, message : String) -> @library.SourceError {
  @library.SourceError([@library.SourceDiagnostic::error_at(span, message)])
}

///|
/// The host function of a callback description: created on first use and
/// then the same object for the whole compilation. `span` and `keys` are
/// those of the occurrence being lowered. A description can occur several
/// times (under different `Keyed` wrappers): each occurrence wraps the same
/// host function in a `Func` with its own span, which the engine passes
/// back as the span of the call's arguments, so an invocation knows the
/// occurrence it runs for.
fn Session::host(
  self : Session,
  callback : Callback,
  span : @syntax.Span,
  keys : Array[String],
) -> @library.HostFunc raise @library.SourceError {
  if self.hosts.get(callback.serial) is Some(host) {
    return host
  }
  if callback.serial >= self.start_serial {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        span, "callbacks cannot be created inside a callback",
      ).with_hints([
        "create the callback before compiling and capture it", "or use the `cx` of the enclosing callback",
      ]),
    ])
  }
  // The key identifies the function within the compilation. It is derived
  // from the order of first lowering, so it is reproducible across runs.
  let state = @library.SipHasher128::new()
  state.write_str("edsl-host")
  state.write_str(callback.origin.loc.to_string())
  state.write_usize(self.hosts.length())
  let key = state.finish128()
  let session = self
  let loc = callback.origin.loc.to_string()
  let host = @library.HostFunc::new(key, (engine, context, args) => {
    // The occurrence: the engine calls a function value with its own span
    // (`Func::call`). A call from elsewhere (Typst code in a snippet) runs
    // for the first occurrence.
    let (span, keys) = match session.registry.locate(args.span) {
      Some((entry, _)) if session.registry.entries[entry].loc == loc =>
        (session.registry.span(entry), session.registry.entries[entry].keys)
      _ => (span, keys)
    }
    let lower : Lower = { session, engine, context, keys, }
    let cx : Ctx = { lower, alive: { val: true, }, span, }
    let result = try (callback.invoke)(cx, args) catch {
      @library.SourceError(errors) => {
        cx.alive.val = false
        raise @library.SourceError(errors)
      }
      @library.HintedError(err) => {
        cx.alive.val = false
        raise @library.SourceError([err.into_error_at(span)])
      }
      err => {
        cx.alive.val = false
        raise error_at(span, err.to_string())
      }
    } noraise {
      value => value
    }
    cx.alive.val = false
    lower.value(result, span)
  })
  self.hosts[callback.serial] = host
  host
}
