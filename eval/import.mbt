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

  // Evaluate the file (memoized, see `eval_source_memoized`).
  eval_source_memoized(engine, source)
}

///|
/// A memoized module evaluation.
priv struct EvalMemo {
  world : &@library.World
  library : @library.Library
  text : String
  /// The outer route and the file ids it was queried for (comemo tracks
  /// `Route::contains` calls, so only those answers must match).
  route : @library.Route
  queried : Array[@syntax.FileId]
  /// The traced span and the files it was asked for (comemo tracks
  /// `Traced::get`: only those answers must match).
  traced : @library.Traced
  traced_files : Array[@syntax.FileId]
  result : Result[@library.Module, Array[@library.SourceDiagnostic]]
  sink : @library.Sink
}

///|
/// The memoized file evaluations of a compilation.
priv struct EvalMemos {
  /// The compilation the entries belong to
  /// ([@library.compilation_epoch]).
  mut epoch : Int
  /// The evaluations by file id.
  entries : Map[@syntax.FileId, Array[EvalMemo]]
}

///|
/// Memoized file evaluations by file id.
let eval_memo : EvalMemos = { epoch: 0, entries: Map([]), }

///|
/// The memoized evaluations of a file in the current compilation.
///
/// An entry is found again by the text of its file, but its module is also
/// made of what the evaluation read from the world: the files it imported
/// and loaded. Those are fixed during a compilation (`World`'s contract)
/// and may be different in the next one with the same world (`typst
/// watch`), so the entries of earlier compilations are dropped; outside of
/// a compilation, those of earlier evaluations (`eval_source` with the root
/// route; an evaluated string belongs to what came before it). (Upstream:
/// comemo validates the world accesses of a memoized `eval` and thereby
/// repeats them, which is also what makes these files dependencies of the
/// later compilation.)
fn EvalMemos::of(self : EvalMemos, id : @syntax.FileId) -> Array[EvalMemo] {
  let epoch = @library.compilation_epoch()
  if self.epoch != epoch {
    self.entries.clear()
    self.epoch = epoch
  }
  match self.entries.get(id) {
    Some(entries) => entries
    None => {
      let entries = []
      self.entries[id] = entries
      entries
    }
  }
}

///|
/// Evaluate a source file like `eval_source`, but return the same module for
/// repeated evaluations with identical inputs.
///
/// Upstream `typst_eval::eval` is memoized by comemo, so importing the same
/// file twice yields the same module (modules compare by identity). This
/// mirrors that: the result and the sink effects (warnings, ...) are cached
/// and replayed for the same world, library and source text, and for a
/// route and a traced span that give the answers the evaluation got (the
/// file ids it asked the route for, the files whose code ran in it), within
/// one compilation ([EvalMemos::of]).
fn eval_source_memoized(
  engine : @library.Engine,
  source : @syntax.Source,
) -> @library.Module raise @library.SourceError {
  let id = source.id()
  let entries = eval_memo.of(id)
  for memo in entries {
    if physical_equal(memo.world, engine.world) &&
      physical_equal(memo.library, engine.library) &&
      memo.text == source.text() &&
      memo.queried
      .iter()
      .all(q => memo.route.contains(q) == engine.route.contains(q)) &&
      @library.traced_answers_equal(
        memo.traced,
        engine.traced,
        memo.traced_files,
      ) {
      // The evaluations around this one asked the same of their routes
      // and of their traced spans.
      @library.note_route_queries(memo.queried)
      @library.note_traced_files(memo.traced_files)
      engine.sink.extend_from_sink(memo.sink)
      match memo.result {
        Ok(module_) => return module_
        Err(errors) => raise @library.SourceError(errors)
      }
    }
  }
  let sink = @library.Sink::new()
  let queries = @library.route_queries_begin()
  let traced_start = @library.traced_files_begin()
  @library.note_route_query(id)
  let result : Result[@library.Module, Array[@library.SourceDiagnostic]] = try
    eval_source(
      engine.world,
      engine.library,
      engine.traced,
      sink,
      engine.route,
      source,
    )
  catch {
    @library.SourceError(errors) => Err(errors)
  } noraise {
    module_ => Ok(module_)
  }
  // Queries made here are also made by the enclosing evaluations.
  let queried = @library.route_queries_end(queries)
  let traced_files = @library.traced_files_end(traced_start)
  entries.push({
    world: engine.world,
    library: engine.library,
    text: source.text(),
    route: engine.route,
    queried,
    traced: engine.traced,
    traced_files,
    result,
    sink,
  })
  engine.sink.extend_from_sink(sink)
  match result {
    Ok(module_) => module_
    Err(errors) => raise @library.SourceError(errors)
  }
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
