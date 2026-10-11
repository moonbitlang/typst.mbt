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
  /// The scope that stored the entry or, once that is closed, the scope
  /// that took it last ([@library.TrackedWorld::scope_token]). It does not
  /// say where the entry is found, only that a scope that is still open
  /// may hold the entry's module: such an entry is not dropped for the
  /// limit of entries per source ([EvalMemos::push]).
  mut scope : Int
  /// Whether the entry ends with the scope that stored it: an evaluation
  /// with memoization off (`@library.set_layout_memo_enabled(false)`).
  /// Such a scope neither leaves anything for a later one nor takes
  /// anything from an earlier one ([EvalMemo::lives]); the store still
  /// answers within it, since a file is one module in a compilation with
  /// or without memoization (modules compare by identity).
  scoped : Bool
  /// The number of `@library.evict` calls since the entry was stored or
  /// taken (comemo's age).
  mut age : Int
  /// The source that was evaluated: the entry is found by its fingerprint
  /// and only taken for the same source ([same_source]).
  source : @syntax.Source
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
  /// The module, or the errors of an evaluation that failed. The errors
  /// are the entry's own: no caller has these objects ([own_result]).
  result : Result[@library.Module, Array[@library.SourceDiagnostic]]
  /// The effects of the evaluation on its sink, as the entry's own copy
  /// (`@library.Sink::kept`): what is replayed is a copy of it again.
  sink : @library.Sink
}

///|
/// The result of an evaluation with diagnostics of its own: what an entry
/// keeps of the result it was computed with, and what it hands out on
/// every hit.
///
/// A diagnostic is an object whose trace and hints are appended to, and
/// every import adds a tracepoint to the errors that pass through it
/// (`@library.trace`). Upstream never writes to what its cache holds:
/// comemo stores a clone of the output and returns a clone on a hit
/// (`comemo/src/memoize.rs`: `cache.insert(key, constraint,
/// output.clone())`, `return entry.output.clone()`), and `Trace for
/// SourceResult` adds its tracepoint through `errors.make_mut()`
/// (`typst-library/src/diag.rs`), which copies a vector that is shared.
/// Without the copies the error of a file that fails got one more
/// tracepoint with every import that found it.
fn own_result(
  result : Result[@library.Module, Array[@library.SourceDiagnostic]],
) -> Result[@library.Module, Array[@library.SourceDiagnostic]] {
  match result {
    Ok(_) => result
    Err(errors) => Err(errors.map(error => error.clone()))
  }
}

///|
/// Whether two sources are the same argument of an evaluation: one object,
/// or two parses of one text of one file (`Source::new`: the tree and its
/// span numbers are a function of the two). That is what the fingerprint
/// that finds an entry says too ([@library.source_fingerprint]); like the
/// other stores (`library/memo.mbt`, header), this one does not take a
/// fingerprint's word for it but keeps the argument and compares it. (The
/// fingerprint of a parsed text is kept in the source, in two words that
/// `Source::set_memo` writes and any caller could write; and the result of
/// an edit is identified by a number, not by a hash.) The comparison is of
/// two objects unless two worlds parsed the same text, and then of two
/// texts.
fn same_source(a : @syntax.Source, b : @syntax.Source) -> Bool {
  physical_equal(a, b) ||
  (
    a.is_pristine() &&
    b.is_pristine() &&
    a.id() == b.id() &&
    a.text() == b.text()
  )
}

///|
/// Whether the entry is one for an evaluation of this source with this
/// library, traced span and route: all conditions of a hit but the world
/// reads, which are looked at last ([@library.TrackedWorld::validate]).
fn EvalMemo::matches(
  self : EvalMemo,
  source : @syntax.Source,
  library : @library.Library,
  traced : @library.Traced,
  route : @library.Route,
  depth : Int,
) -> Bool {
  guard physical_equal(self.library, library) &&
    self.shifts.allows(depth - self.depth) &&
    same_source(self.source, source) else {
    return false
  }
  for id in self.queried {
    guard self.route.contains(id) == route.contains(id) else { return false }
  }
  @library.traced_answers_equal(self.traced, traced, self.traced_files)
}

///|
/// Whether a lookup may see the entry at all: any entry of a scope that
/// is still open, and with memoization on (`memoizing`) also every entry
/// that an evaluation with memoization on left. So a compilation with
/// memoization off starts from nothing, as every compilation did before
/// entries had ages, and what it evaluated is not handed to a compilation
/// with memoization on (the two can differ: with memoization off no
/// closure call is found, and a call that is found is what makes two
/// modules with one hash one argument, `library/memo.mbt`).
fn EvalMemo::lives(self : EvalMemo, memoizing : Bool) -> Bool {
  (memoizing && !self.scoped) || @library.world_scope_open(self.scope)
}

///|
/// The memoized file evaluations.
priv struct EvalMemos {
  /// The evaluations by the fingerprint of their source
  /// ([@library.source_fingerprint]).
  mut entries : Map[@library.U128, Array[EvalMemo]]
  /// Whether `@library.evict` knows the store.
  mut registered : Bool
  /// The sources that have entries that end with their scope
  /// (`EvalMemo.scoped`), and the scope that stored such an entry last:
  /// when another scope stores one, those of the scopes that are closed
  /// are dropped ([EvalMemos::drop_ended]).
  scoped_keys : Array[@library.U128]
  mut scoped_scope : Int
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
///
/// An entry outlives the scope that stored it (a compilation, or an
/// evaluation that is not inside one): a later compilation finds it if its
/// source, its library, its route, its traced span and its world reads are
/// what they were ([eval_source_memoized]). Its lifetime is comemo's
/// (`comemo/src/memoize.rs`, `CacheData::evict` and `lookup`): every
/// `@library.evict(max_age)` makes it older by one, being taken makes it
/// young, and it is dropped when it was not taken for more than `max_age`
/// calls. A watching compiler calls `evict(10)` after every recompilation;
/// a process that never calls it keeps what it evaluated, up to
/// [eval_memo_max_entries] per source.
let eval_memo : EvalMemos = {
  entries: Map([]),
  registered: false,
  scoped_keys: [],
  scoped_scope: 0,
  checked: false,
  aside: None,
  counts: [0, 0],
}

///|
/// The number of entries kept per source (not upstream: comemo has no
/// limit). An entry more is one for the same source with another library,
/// route, traced span or, mostly, other answers of the world: a file that
/// the module reads and that changes again and again adds one with every
/// compilation. Under `evict(10)` a store never holds more than eleven
/// versions of anything, so there the ages decide, as comemo's do, and
/// this limit is for a process that does not call `evict`. An entry that a
/// scope that is still open stored or took is not dropped for it: in one
/// compilation a file is the same module for every import that asks the
/// same, as upstream.
let eval_memo_max_entries : Int = 12

///|
/// How many evaluations of source files the store has answered and how
/// many it has computed since the process started (for tests and
/// measurements, like `@library.closure_memo_stats`). An evaluation of a
/// file that changes during its scope is neither.
pub fn module_memo_stats() -> (Int, Int) {
  (eval_memo.counts[0], eval_memo.counts[1])
}

///|
/// The number of evaluations that the store keeps (for tests and
/// measurements).
pub fn module_memo_entries() -> Int {
  let mut count = 0
  for _, entries in eval_memo.entries {
    count += entries.length()
  }
  count
}

///|
/// Keeps an evaluation of the source with the fingerprint `key`.
fn EvalMemos::push(
  self : EvalMemos,
  key : @library.U128,
  memo : EvalMemo,
) -> Unit {
  if !self.registered {
    self.registered = true
    @library.register_evictor(max_age => self.evict(max_age))
  }
  if memo.scoped {
    if self.scoped_scope != memo.scope {
      self.drop_ended()
      self.scoped_scope = memo.scope
    }
    self.scoped_keys.push(key)
  }
  match self.entries.get(key) {
    Some(entries) => {
      if entries.length() >= eval_memo_max_entries {
        // The oldest that no open scope may rely on.
        for i, other in entries {
          if !@library.world_scope_open(other.scope) {
            entries.remove(i) |> ignore
            break
          }
        }
      }
      entries.push(memo)
    }
    None => self.entries[key] = [memo]
  }
}

///|
/// Drops the entries that ended with their scope (`EvalMemo.scoped`, of
/// evaluations with memoization off) and whose scope is closed. No lookup
/// sees them; this is for the memory of a process that compiles again and
/// again with memoization off.
fn EvalMemos::drop_ended(self : EvalMemos) -> Unit {
  let keys = self.scoped_keys.copy()
  self.scoped_keys.clear()
  for key in keys {
    guard self.entries.get(key) is Some(entries) else { continue }
    let mut open = false
    entries.retain(memo => {
      if !memo.scoped {
        true
      } else if @library.world_scope_open(memo.scope) {
        open = true
        true
      } else {
        false
      }
    })
    if entries.is_empty() {
      self.entries.remove(key)
    } else if open && !self.scoped_keys.contains(key) {
      self.scoped_keys.push(key)
    }
  }
}

///|
/// comemo's `evict` for this store: every entry gets older by one, and
/// those that were not taken for more than `max_age` calls are dropped
/// (all of them for zero).
///
/// Except the entries that a scope that is still open stored or took (a
/// host function that calls `evict` during a compilation): modules compare
/// by identity, and a file that is imported again in that compilation
/// must be the module it was. (comemo would drop them; upstream never
/// evicts during a compilation.)
fn EvalMemos::evict(self : EvalMemos, max_age : Int) -> Unit {
  let empty = []
  for key, entries in self.entries {
    entries.retain(memo => {
      if @library.world_scope_open(memo.scope) {
        return true
      }
      memo.age += 1
      memo.age <= max_age
    })
    if entries.is_empty() {
      empty.push(key)
    }
  }
  for key in empty {
    self.entries.remove(key)
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
///   An entry also keeps its source and is only taken for the same one
///   ([same_source]; upstream keeps the hash alone).
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
/// - A result that is an error is kept and handed out as a copy
///   ([own_result]).
///
/// Stricter than upstream in one more point: nothing is kept for a file
/// that changes during the scope ([@library.TrackedWorld::is_volatile]).
///
/// An entry is found by a later scope too (the next compilation of a
/// watching compiler) and has comemo's age ([eval_memo]). With
/// memoization off (`@library.set_layout_memo_enabled(false)`) it ends
/// with its scope, and nothing of an earlier scope is found
/// ([EvalMemo::lives]).
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
  let depth = route.depth()
  let memoizing = @library.content_memo_enabled()
  if eval_memo.entries.get(key) is Some(entries) {
    for memo in entries {
      if memo.lives(memoizing) &&
        memo.matches(source, library, traced, route, depth) &&
        // Last: this notes the world reads for the evaluation around.
        world.validate(memo.reads) {
        eval_memo.counts[0] += 1
        // A hit makes the entry young (comemo: `lookup` stores age 0).
        memo.age = 0
        if !@library.world_scope_open(memo.scope) {
          memo.scope = scope
        }
        // The evaluations around this one asked the same of their routes
        // and of their traced spans.
        @library.note_route_queries(memo.queried)
        memo.shifts.note_reused(depth - memo.depth)
        @library.note_traced_files(memo.traced_files)
        sink.extend_from_kept(memo.sink)
        match own_result(memo.result) {
          Ok(module_) => return module_
          Err(errors) => raise @library.SourceError(errors)
        }
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
  let result = match
    eval_memo.original(key, world, source, library, traced, route, depth) {
    Some(original) => original
    None => result
  }
  // An evaluation that read a file that changes during the scope is not
  // kept, also when it ended with an error.
  if !reads.is_volatile() {
    if @library.memo_check_enabled() {
      eval_memo.check(world, library, traced, route, source, reads)
    }
    eval_memo.push(key, {
      scope,
      scoped: !memoizing,
      age: 0,
      source,
      library,
      reads,
      route,
      queried,
      depth,
      shifts,
      traced,
      traced_files,
      result: own_result(result),
      sink: own_sink.kept(),
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
      let found = self.counts[0]
      let computed = self.counts[1]
      self.entries = Map([])
      self.aside = Some(entries)
      () => {
        self.entries = entries
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
/// gives the module it gave in the first: that of the entry that a lookup
/// in the first run took or that the first run stored, which is the one
/// that is valid for the world at hand (the store may hold another for the
/// same source, of a scope around this one whose world answers
/// differently).
fn EvalMemos::original(
  self : EvalMemos,
  key : @library.U128,
  world : @library.TrackedWorld,
  source : @syntax.Source,
  library : @library.Library,
  traced : @library.Traced,
  route : @library.Route,
  depth : Int,
) -> Result[@library.Module, Array[@library.SourceDiagnostic]]? {
  guard @library.memo_check_running_now() && self.aside is Some(aside) else {
    return None
  }
  guard aside.get(key) is Some(entries) else { return None }
  let memoizing = @library.content_memo_enabled()
  for memo in entries {
    if memo.lives(memoizing) &&
      memo.matches(source, library, traced, route, depth) &&
      world.validate(memo.reads) {
      return Some(own_result(memo.result))
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
