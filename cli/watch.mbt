// The `watch` command (upstream `typst-cli/src/watch.rs`; its `Status` is in
// `watch_status.mbt`), on the targets that can watch files (native, wasm).

///|
/// Execute a watching compilation command.
fn watch(command : WatchCommand) -> Unit raise HintedFailure {
  // (Upstream's `Timer`: `--timings` is not supported by this port, see
  // `CompileConfig::new_impl`.)
  let config = CompileConfig::watching(command)
  guard config.output is Path(output) else {
    raise bail("cannot write document to stdout in watch mode")
  }

  // Not upstream: the watcher gets its events from tasks of an event loop
  // (notify from a thread of its own), so the rest of the command runs
  // inside that loop. Only this command does.
  let result : Ref[Result[Unit, HintedFailure]] = { val: Ok(()), }
  @watcher.run(group => {
    watching(command, config, output, group) catch {
      err => result.val = Err(err)
    }
  })
  match result.val {
    Ok(_) => ()
    Err(err) => raise err
  }
}

///|
/// The body of [`watch`].
async fn watching(
  command : WatchCommand,
  config : CompileConfig,
  output : String,
  group : @watcher.Tasks,
) -> Unit raise HintedFailure {
  // Create a file system watcher.
  let watcher = @watcher.Watcher::new(Some(output), group) catch {
    @kit.StrError(msg) => raise bail(msg)
  }

  // Create the world that serves sources, files, and fonts.
  // Additionally, if any files do not exist, wait until they do.
  let world = for ;; {
    try
      SystemWorld::new(
        Some(command.args.input),
        command.args.world,
        command.args.process,
      )
    catch {
      InputNotFound(path) | RootNotFound(path) as err => {
        watcher.update([path]) catch {
          @kit.StrError(msg) => raise bail(msg)
        }
        Status::Error.print(config)
        print_error("\{err}")
        watcher.wait() catch {
          @kit.StrError(msg) => raise bail(msg)
        }
      }
      err => raise bail("\{err}")
    } noraise {
      world => break world
    }
  }

  // Eagerly scan fonts if we expect to need them so that it's not counted as
  // part of the displayed compilation time. The duration of font scanning is
  // heavily system-dependent, so it could result in confusion why compilation
  // is so much faster/slower.
  if config.output_format.is_paged() {
    world.scan_fonts()
  }

  // Perform initial compilation.
  compile_once(world, config)

  // Print warning when trying to watch stdin.
  if config.input is Stdin {
    warn_watching_std(world, config)
  }

  // Recompile whenever something relevant happens.
  for ;; {
    // Watch all dependencies of the most recent compilation.
    watcher.update(world.dependencies()) catch {
      @kit.StrError(msg) => raise bail(msg)
    }

    // Wait until anything relevant happens.
    watcher.wait() catch {
      @kit.StrError(msg) => raise bail(msg)
    }

    // Reset all dependencies.
    world.reset()

    // Recompile.
    compile_once(world, config)

    // Evict the cache.
    //
    // (Upstream's `comemo::evict(10)`. There is nothing to evict: this
    // port's memoization lives for one compilation, `library/memo.mbt`.)
  }
}

///|
/// Emits a warning when trying to watch stdin.
fn warn_watching_std(
  world : SystemWorld,
  config : CompileConfig,
) -> Unit raise HintedFailure {
  let warning = @library.SourceDiagnostic::warning(
      @syntax.DiagSpan::detached(),
      "cannot watch changes for stdin",
    )
    .with_hint("to recompile on changes, watch a regular file instead")
    .with_hint("to compile once and exit, please use `typst compile` instead")
  print_diagnostics(world, [], [warning], config.diagnostic_format) catch {
    err => raise bail("failed to print diagnostics (\{err})")
  }
}
