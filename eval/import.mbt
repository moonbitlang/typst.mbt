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
    vm.define(new_name, source)
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
  let module = match source {
    Str(path) =>
      @library.trace(
        s => @library.world_range(vm.engine.world, s),
        () => Include(path),
        inc.span(),
        () => import_(vm.engine, path, source_span),
      )
    Module(module) => module
    v =>
      @library.bail_at(source_span, "expected path or module, found \{v.ty()}")
  }
  module.content()
}

///|
/// Process an import of a package or file relative to the current location.
pub fn import_(
  engine : @library.Engine,
  from : String,
  span : @syntax.Span,
) -> @library.Module raise @library.SourceError {
  let id = @library.at(span, () => engine.world.resolve_path(span.id(), from))
  import_file(engine, id, span)
}

///|
/// Import a file from a path.
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
  if engine.route.contains(source.id()) {
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
