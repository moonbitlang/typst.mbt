// `CachedCell` (`flow_collect.mbt`): what it keeps is not what it hands out
// where that can be written to.

///|
/// Upstream's cell returns `output.clone()` of the `SourceResult` it holds.
/// A diagnostic is an object here: whoever catches one appends tracepoints
/// and hints to it (`@library.trace`), and the cell raised the errors it
/// kept, so a second layout with the same region reported what the first
/// caller had made of them.
test "cached cell: an error that it keeps is raised as a copy" {
  let cell : CachedCell[Int32, Int32] = CachedCell::new()
  let span = @syntax.Span::detached()
  let mut runs = 0
  let caught = () => {
    try
      cell.get_or_init(1, (a, b) => a == b, _ => {
        runs += 1
        raise @library.SourceError([
          @library.SourceDiagnostic::error_at(span, "failed"),
        ])
      })
    catch {
      @library.SourceError(errors) => {
        let seen = errors.map(error => {
          "\{error.message}: \{error.trace.length()} tracepoints, \{error.hints.length()} hints"
        })
        // What a caller does with an error it catches.
        for error in errors {
          error.trace.push({ v: @library.Tracepoint::Call(Some("f")), span, })
          error.hint("a hint")
        }
        errors.push(@library.SourceDiagnostic::error_at(span, "another"))
        seen.join("; ")
      }
    } noraise {
      _ => "no error"
    }
  }
  for _ in 0..<3 {
    inspect(caught(), content="failed: 0 tracepoints, 0 hints")
  }
  assert_eq(runs, 1)
  // A value is handed out as it is kept, and another input computes anew.
  let values : CachedCell[Int32, Int32] = CachedCell::new()
  let mut computed = 0
  let get = (input : Int32) => {
    values.get_or_init(input, (a, b) => a == b, input => {
      computed += 1
      input * 2
    }) catch {
      _ => -1
    }
  }
  assert_eq((get(1), get(1), get(2), get(1)), (2, 2, 4, 2))
  assert_eq(computed, 3)
}
