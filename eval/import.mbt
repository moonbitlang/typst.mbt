// Port of `typst-eval/src/import.rs` (file imports; package resolution is
// delegated to the world).

///|
fn eval_module_import(
  vm : Vm,
  imp : @ast.ModuleImport,
) -> @library.Value raise @library.SourceError {
  let source_expr = imp.source()
  let source_span = source_expr.span()
  let mut source = eval_expr(vm, source_expr)
  let mut replaced_source = false
  match source {
    Func(func) =>
      if func.scope() is None {
        @library.bail_at(
          source_span, "cannot import from user-defined functions",
        )
      }
    Type(_) => ()
    Module(_) => ()
    Str(path) => {
      source = Module(
        @library.trace(
          s => @library.world_range(vm.engine.world, s),
          () => Import(path),
          imp.span(),
          () => import_(vm.engine, path, source_span),
        ),
      )
      replaced_source = true
    }
    // Upstream: `v if RootedPath::castable(v)`.
    Dyn(RootedPath(path)) => {
      let id = path.intern()
      source = Module(
        @library.trace(
          s => @library.world_range(vm.engine.world, s),
          () => Import(id.get().vpath().get_with_slash()),
          imp.span(),
          () => import_file(vm.engine, id, source_span),
        ),
      )
      replaced_source = true
    }
    v =>
      @library.bail_at(
        source_span,
        "expected path, module, function, or type, found \{v.ty()}",
      )
  }

  // If there is a rename, import the source itself under that name.
  let new_name = imp.new_name()
  if new_name is Some(new_name) {
    if source_expr is Ident(ident) && ident.get() == new_name.get() {
      // Warn on `import x as x`
      vm.engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          new_name.span(),
          "unnecessary import rename to same name",
        ),
      )
    }

    // Define renamed module on the scope.
    vm.define_(new_name, source)
  }
  let scope = source.scope().unwrap()
  match imp.imports() {
    None =>
      if new_name is None {
        match imp.bare_name() {
          Ok(name) if !replaced_source || source_expr is Str(_) => {
            if source_expr is Ident(_) {
              vm.engine.sink.warn(
                @library.SourceDiagnostic::warning_at(
                  source_expr.span(),
                  "this import has no effect",
                ),
              )
            }
            vm.scopes.top.bind(name, @library.Binding::new(source, source_span))
            |> ignore
          }
          Ok(_) | Err(Dynamic) =>
            @library.bail_at(
              source_span,
              "dynamic import requires an explicit name",
              hints=["you can name the import with `as`"],
            )
          Err(PathInvalid) =>
            @library.bail_at(
              source_span,
              "module name would not be a valid identifier",
              hints=["you can rename the import with `as`"],
            )
          Err(PackageInvalid) => abort("unreachable")
        }
      }
    Some(Wildcard) => {
      let guard_ = @library.BindingGuard::silent(vm.engine.library.features)
      for pair in scope.iter() {
        let (name, binding) = pair
        let ok = try binding.read(guard_, "") catch {
          _ => false
        } noraise {
          _ => true
        }
        if ok {
          vm.scopes.top.bind(name, binding.copy()) |> ignore
        }
      }
    }
    Some(Items(items)) => {
      let errors = []
      for item in items.iter() {
        let path = item.path().iter().collect()
        let mut scope = scope
        for i, component in path {
          let field = component.get()
          guard scope.get(field) is Some(binding) else {
            errors.push(
              @library.SourceDiagnostic::error_at(
                component.span(),
                "unresolved import",
              ),
            )
            break
          }
          let value = @library.at(component.span(), () => {
            binding.read(vm.guard_at(component.span()), "import `\{field}`")
          })
          if i + 1 < path.length() {
            // Nested submodule.
            guard value.scope() is Some(submodule) else {
              let error = match value {
                Func(function) if function.scope() is None =>
                  @library.SourceDiagnostic::error_at(
                    component.span(),
                    "cannot import from user-defined functions",
                  )
                Func(_) | Module(_) | Type(_) =>
                  abort("unexpected nested import failure")
                _ =>
                  @library.SourceDiagnostic::error_at(
                    component.span(),
                    "expected module, function, or type, found \{value.ty()}",
                  )
              }
              errors.push(error)
              break
            }
            scope = submodule
          } else {
            if item is Renamed(renamed_item) &&
              renamed_item.original_name().get() ==
              renamed_item.new_name().get() {
              vm.engine.sink.warn(
                @library.SourceDiagnostic::warning_at(
                  renamed_item.new_name().span(),
                  "unnecessary import rename to same name",
                ),
              )
            }
            vm.bind(item.bound_name(), binding.copy())
          }
        }
      }
      if !errors.is_empty() {
        raise @library.SourceError(errors)
      }
    }
  }
  None
}

///|
fn eval_module_include(
  vm : Vm,
  inc : @ast.ModuleInclude,
) -> @library.Content raise @library.SourceError {
  let source_span = inc.source().span()
  let source = eval_expr(vm, inc.source())
  let module_ = match source {
    Str(path) =>
      @library.trace(
        s => @library.world_range(vm.engine.world, s),
        () => Include(path),
        inc.span(),
        () => import_(vm.engine, path, source_span),
      )
    Module(module_) => module_
    // Upstream: `v if RootedPath::castable(&v)`.
    Dyn(RootedPath(path)) => {
      let id = path.intern()
      @library.trace(
        s => @library.world_range(vm.engine.world, s),
        () => Include(id.get().vpath().get_with_slash()),
        inc.span(),
        () => import_file(vm.engine, id, source_span),
      )
    }
    v =>
      @library.bail_at(source_span, "expected path or module, found \{v.ty()}")
  }
  module_.content()
}

///|
/// Process an import of a package or file relative to the current location.
pub fn import_(
  engine : @library.Engine,
  from : String,
  span : @syntax.Span,
) -> @library.Module raise @library.SourceError {
  if from.has_prefix("@") {
    let spec = match @syntax.PackageSpec::from_str(from) {
      Ok(spec) => spec
      Err(err) => @library.bail_at(span, err)
    }
    import_package(engine, spec, span)
  } else {
    let path = @library.at(span, () => {
      @library.PathOrStr::Str(from).resolve_if_some(span.id())
    }).intern()
    import_file(engine, path, span)
  }
}

///|
/// Import a file from a path. The path is resolved relative to the given
/// `span`.
fn import_file(
  engine : @library.Engine,
  id : @syntax.FileId,
  span : @syntax.Span,
) -> @library.Module raise @library.SourceError {
  // Load the source file.
  let source = engine.world.source(id) catch {
    err => @library.bail_at(span, err.to_string())
  }

  // Prevent cyclic importing.
  if route_contains(engine.route, source.id()) {
    @library.bail_at(span, "cyclic import")
  }

  // Evaluate the file.
  eval_source(
    engine.world,
    engine.library,
    engine.traced,
    engine.sink,
    engine.route,
    source,
  )
}

///|
/// A memoized module evaluation: what [eval_source_memoized] keeps for one
/// source, one library and the answers that the evaluation got from its
/// tracked arguments.
priv struct EvalMemo {
  /// The scope of the evaluation ([@library.TrackedWorld::scope_token]).
  /// It says how long the entry is kept ([EvalMemos::of]), not where it is
  /// found.
  scope : Int
  library : @library.Library
  /// The world reads of the evaluation and their answers (comemo tracks
  /// the world of `eval`: the files that the module imported and loaded).
  /// The source of the file itself is not among them: it is an argument,
  /// and the entry is found by its fingerprint.
  reads : @library.WorldReads
  /// The outer route and the file ids it was queried for (comemo tracks
  /// `Route::contains` calls, so only those answers must match).
  route : @library.Route
  queried : Array[@syntax.FileId]
  /// The depth of the outer route and how much deeper or shallower it may
  /// be without changing the answer of a depth check of the evaluation
  /// (comemo tracks `Route::within`).
  depth : Int
  shifts : @library.RouteShifts
  /// The traced span and the files it was asked for (comemo tracks
  /// `Traced::get`: only those answers must match).
  traced : @library.Traced
  traced_files : Array[@syntax.FileId]
  result : Result[@library.Module, Array[@library.SourceDiagnostic]]
  sink : @library.Sink
}

///|
/// Whether the entry is one for an evaluation with this library, traced
/// span and route: all conditions of a hit but the world reads, which are
/// looked at last ([@library.TrackedWorld::validate]).
fn EvalMemo::matches(
  self : EvalMemo,
  library : @library.Library,
  traced : @library.Traced,
  route : @library.Route,
  depth : Int,
) -> Bool {
  guard physical_equal(self.library, library) &&
    self.shifts.allows(depth - self.depth) else {
    return false
  }
  for id in self.queried {
    guard self.route.contains(id) == route.contains(id) else { return false }
  }
  @library.traced_answers_equal(self.traced, traced, self.traced_files)
}

///|
/// The memoized file evaluations of the scopes that are open.
priv struct EvalMemos {
  /// The scope that asked last.
  mut last : Int
  /// The evaluations by the fingerprint of their source
  /// ([@library.source_fingerprint]).
  mut entries : Map[@library.U128, Array[EvalMemo]]
  /// Whether `@library.set_memo_check` knows the store.
  mut checked : Bool
  /// The entries that were set aside for a second run of that check.
  mut aside : Map[@library.U128, Array[EvalMemo]]?
  /// The numbers of evaluations that were found and that were computed
  /// ([module_memo_stats]).
  counts : FixedArray[Int]
}

///|
/// Memoized file evaluations by the fingerprint of their source.
let eval_memo : EvalMemos = {
  last: 0,
  entries: Map([]),
  checked: false,
  aside: None,
  counts: [0, 0],
}

///|
/// For the tests of the store (`import_wbtest.mbt`): the entries outlive
/// the scope that stored them, as they will once they have ages (step 5
/// of slice 1 of `docs/incremental-design.md`), so that a test can ask in
/// one scope for what another stored. Not public, and never set outside of
/// those tests: what a kept entry needs besides what this store validates
/// (steps 4 and 5 of that slice) is not built.
let eval_memo_kept : Ref[Bool] = { val: false, }

///|
/// How many evaluations of source files the store has answered and how
/// many it has computed since the process started (for tests and
/// measurements, like `@library.closure_memo_stats`). An evaluation of a
/// file that changes during its scope is neither.
pub fn module_memo_stats() -> (Int, Int) {
  (eval_memo.counts[0], eval_memo.counts[1])
}

///|
/// The memoized evaluations of the source with the fingerprint `key`, for
/// a call in the scope `scope`.
///
/// An entry lives as long as the scope that stored it
/// (`library/tracked_world.mbt`: a compilation, or an evaluation that is
/// not inside one): the entries of the scopes that are closed are dropped
/// when another scope asks. Nothing is kept from one compilation to the
/// next yet (`docs/incremental-design.md`, slice 1: ages are its step 5).
/// A scope inside another (a host function that compiles) leaves the
/// entries of the outer one alone, and finds them if they are valid for
/// its world.
fn EvalMemos::of(
  self : EvalMemos,
  key : @library.U128,
  scope : Int,
) -> Array[EvalMemo] {
  if self.last != scope {
    self.last = scope
    if !eval_memo_kept.val {
      let empty = []
      for key, entries in self.entries {
        entries.retain(memo => @library.world_scope_open(memo.scope))
        if entries.is_empty() {
          empty.push(key)
        }
      }
      for key in empty {
        self.entries.remove(key)
      }
    }
  }
  match self.entries.get(key) {
    Some(entries) => entries
    None => {
      let entries = []
      self.entries[key] = entries
      entries
    }
  }
}

///|
/// [eval_source] in a scope of the world: the evaluation of a source file
/// ([eval_source_impl]), which returns the same module for repeated
/// evaluations with identical inputs.
///
/// Upstream `typst_eval::eval` is memoized by comemo, so importing the same
/// file twice yields the same module (modules compare by identity), and a
/// compilation whose main file is what it was finds its module:
///
///     #[comemo::memoize]
///     pub fn eval(
///         world: Tracked<dyn World + '_>,
///         library: &LazyHash<Library>,
///         traced: Tracked<Traced>,
///         sink: TrackedMut<Sink>,
///         route: Tracked<Route>,
///         source: &Source,
///     ) -> SourceResult<Module>
///
/// Its key is the hash of the library and of the source, which is the hash
/// of the source's id, text and numbered tree (`typst-syntax/src/source.rs`,
/// `SourceInner` under `LazyHash`); a result is taken if the world, the
/// traced span and the route give the answers that the evaluation got, and
/// the mutations of the sink are replayed. Here:
///
/// - An entry is found by the fingerprint of the source
///   ([@library.source_fingerprint]): the id and the text of a source that
///   `Source::new` parsed (its tree and span numbers are a function of the
///   two), the id and the number of the object for a source that an edit
///   made. Not by the text alone: spans are in the closures, the content
///   and the diagnostics of a module, and a file that was edited and edited
///   back has its old text with other span numbers where it was reparsed.
///   The fingerprint is equal only where upstream's hash is; two sources
///   that were edited into the same tree are two keys here and one there.
/// - The library is compared by identity (upstream hashes it).
/// - The route: the file ids the evaluation asked it for must get the
///   same answers (`Route::contains`), and its depth may only differ by as
///   much as leaves the depth checks of the evaluation as they were
///   (`Route::within`; [@library.RouteShifts]).
/// - The traced span must give the same answers for the files whose code
///   ran in the evaluation (`Traced::get`).
/// - The world must give the answers it gave
///   ([@library.TrackedWorld::validate], looked at last); the world reads
///   are then noted for the evaluation around this one (upstream: comemo
///   validates the world accesses of a memoized `eval` and thereby repeats
///   them, which is also what makes these files dependencies of the later
///   compilation).
/// - The sink effects (warnings, ...) are replayed.
///
/// Stricter than upstream in one more point: nothing is kept for a file
/// that changes during the scope ([@library.TrackedWorld::is_volatile]).
fn eval_source_memoized(
  world : @library.TrackedWorld,
  library : @library.Library,
  traced : @library.Traced,
  sink : @library.Sink,
  route : @library.Route,
  source : @syntax.Source,
) -> @library.Module raise @library.SourceError {
  let id = source.id()
  let scope = world.scope_token()
  // No store outside of a scope ([eval_source] opens one). And none for a
  // file that changes during the scope (`doc`'s snippets): every import
  // of it evaluates what the world hands out then.
  if scope == 0 || world.is_volatile(id) {
    return eval_source_impl(world, library, traced, sink, route, source)
  }
  let key = @library.source_fingerprint(source)
  let entries = eval_memo.of(key, scope)
  let depth = route.depth()
  for memo in entries {
    if memo.matches(library, traced, route, depth) &&
      // Last: this notes the world reads for the evaluation around.
      world.validate(memo.reads) {
      eval_memo.counts[0] += 1
      // The evaluations around this one asked the same of their routes
      // and of their traced spans.
      @library.note_route_queries(memo.queried)
      memo.shifts.note_reused(depth - memo.depth)
      @library.note_traced_files(memo.traced_files)
      sink.extend_from_sink(memo.sink)
      match memo.result {
        Ok(module_) => return module_
        Err(errors) => raise @library.SourceError(errors)
      }
    }
  }
  eval_memo.counts[1] += 1
  let own_sink = @library.Sink::new()
  let queries = @library.route_queries_begin()
  let outer_shifts = @library.route_shifts_begin()
  let traced_start = @library.traced_files_begin()
  let mark = world.reads_begin()
  @library.note_route_query(id)
  let result : Result[@library.Module, Array[@library.SourceDiagnostic]] = try
    eval_source_impl(world, library, traced, own_sink, route, source)
  catch {
    @library.SourceError(errors) => Err(errors)
  } noraise {
    module_ => Ok(module_)
  }
  // Queries and reads made here are also made by the enclosing
  // evaluations.
  let queried = @library.route_queries_end(queries)
  let shifts = @library.route_shifts_end(outer_shifts)
  let traced_files = @library.traced_files_end(traced_start)
  let reads = world.reads_end(mark)
  let result = match eval_memo.original(key, library, traced, route, depth) {
    Some(original) => original
    None => result
  }
  // An evaluation that read a file that changes during the scope is not
  // kept, also when it ended with an error.
  if !reads.is_volatile() {
    if @library.memo_check_enabled() {
      eval_memo.check(world, library, traced, route, source, reads)
    }
    entries.push({
      scope,
      library,
      reads,
      route,
      queried,
      depth,
      shifts,
      traced,
      traced_files,
      result,
      sink: own_sink,
    })
  }
  sink.extend_from_sink(own_sink)
  match result {
    Ok(module_) => module_
    Err(errors) => raise @library.SourceError(errors)
  }
}

///|
/// The check of `@library.set_memo_check` for a module evaluation that is
/// about to be kept, with a module or with an error: the evaluation once
/// more, from scratch (with the module store set aside), must ask the
/// world what the entry keeps.
fn EvalMemos::check(
  self : EvalMemos,
  world : @library.TrackedWorld,
  library : @library.Library,
  traced : @library.Traced,
  route : @library.Route,
  source : @syntax.Source,
  reads : @library.WorldReads,
) -> Unit {
  if !self.checked {
    self.checked = true
    @library.register_memo_check_store(() => {
      let entries = self.entries
      let last = self.last
      let found = self.counts[0]
      let computed = self.counts[1]
      self.entries = Map([])
      self.aside = Some(entries)
      () => {
        self.entries = entries
        self.last = last
        self.aside = None
        self.counts[0] = found
        self.counts[1] = computed
      }
    })
  }
  @library.memo_check_reads(
    () => "module \{source.id().vpath().get_without_slash()}",
    world,
    reads,
    () => {
      // An evaluation that failed fails again: its reads are compared
      // all the same.
      let _ : Result[@library.Module, Array[@library.SourceDiagnostic]] = try
        eval_source_impl(
          world,
          library,
          traced,
          @library.Sink::new(),
          route,
          source,
        )
      catch {
        @library.SourceError(errors) => Err(errors)
      } noraise {
        module_ => Ok(module_)
      }
    },
  )
}

///|
/// In a second run of the check: the result of the entry that was set
/// aside for this evaluation, if there is one. The run evaluates every
/// file again, for its reads, and would make new modules; but the call it
/// repeats holds the modules of the first run in its arguments and
/// captures, and modules compare by identity. So an import in the run
/// gives the module it gave in the first.
fn EvalMemos::original(
  self : EvalMemos,
  key : @library.U128,
  library : @library.Library,
  traced : @library.Traced,
  route : @library.Route,
  depth : Int,
) -> Result[@library.Module, Array[@library.SourceDiagnostic]]? {
  guard @library.memo_check_running_now() && self.aside is Some(aside) else {
    return None
  }
  guard aside.get(key) is Some(entries) else { return None }
  for memo in entries {
    if memo.matches(library, traced, route, depth) {
      return Some(memo.result)
    }
  }
  None
}

///|
/// Import an external package.
fn import_package(
  engine : @library.Engine,
  spec : @syntax.PackageSpec,
  span : @syntax.Span,
) -> @library.Module raise @library.SourceError {
  let (name, id) = resolve_package(engine, spec, span)
  import_file(engine, id, span).with_name(name)
}

///|
/// Resolve the name and entrypoint of a package.
fn resolve_package(
  engine : @library.Engine,
  spec : @syntax.PackageSpec,
  span : @syntax.Span,
) -> (String, @syntax.FileId) raise @library.SourceError {
  // Evaluate the manifest.
  let vpath = @syntax.VirtualPath::new("typst.toml") catch {
    _ => abort("unreachable")
  }
  let manifest_id = @syntax.RootedPath::new(Package(spec), vpath).intern()
  let bytes = engine.world.file(manifest_id) catch {
    err => @library.bail_at(span, err.to_string())
  }
  let string = @utf8.decode(bytes) catch {
    _ => @library.bail_at(span, @library.FileError::InvalidUtf8.to_string())
  }
  let manifest = match @syntax.PackageManifest::from_toml(string) {
    Ok(manifest) => manifest
    Err(err) => @library.bail_at(span, "package manifest is malformed (\{err})")
  }
  if manifest.validate(spec) is Err(err) {
    @library.bail_at(span, err)
  }

  // Evaluate the entry point.
  let entrypoint = @library.at(span, () => {
    @library.PathOrStr::Str(manifest.package_.entrypoint).resolve(manifest_id)
  })
  (manifest.package_.name, entrypoint.intern())
}

///|
/// `Route::contains`, recording the query for memoization (of the source
/// files here and of closure calls in `library/memo.mbt`).
fn route_contains(route : @library.Route, id : @syntax.FileId) -> Bool {
  @library.note_route_query(id)
  route.contains(id)
}
