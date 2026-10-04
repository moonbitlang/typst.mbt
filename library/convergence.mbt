// Port of `typst-library/src/introspection/convergence.rs`.
//
// Upstream's `Introspect` is a trait with an associated `Output` type. MoonBit
// traits have no associated types, so an introspection is represented by an
// [Introspect] record of closures over the inquiry's data; the type-erased
// [Introspection] stored in the sink only keeps what `analyze` needs.

///|
pub let max_iters : Int = 5

///|
pub let iter_names : ReadOnlyArray[String] = [
  "iter (1)", "iter (2)", "iter (3)", "iter (4)", "iter (5)",
]

///|
let instances : Int = max_iters + 1

///|
/// Analyzes all introspections that were performed during compilation and
/// produces non-convergence diagnostics.
///
/// `introspectors` must hold `max_iters + 1` introspectors: the empty one,
/// followed by those of the documents built in each iteration.
pub fn analyze(
  world : &World,
  introspectors : Array[Introspector],
  introspections : ArrayView[Introspection],
) -> Array[SourceDiagnostic] {
  guard introspectors.length() == instances else {
    abort("analyze requires \{instances} introspectors")
  }
  let sink = Sink::new()
  for introspection in introspections {
    if (introspection.diagnose)(world, introspectors) is Some(warning) {
      sink.warn(warning)
    }
  }

  // Let's say you want to write some code that depends on the presence of an
  // element in the document. You could (1) use the `QueryIntrospection` and
  // then do your emptyness check afterwards or you could (2) write a new
  // [introspection](Introspect) that queries internally and returns a
  // boolean.
  //
  // In case (1), the introspection observes the same data as the recorded
  // introspector reads. Thus, the introspection will have converged if and
  // only if read validation also passed.
  //
  // However, in case (2) the introspection is filtering out data that the
  // recorder did observe. Thus, the validation may fail but the document
  // actually did converge! In this case, we reach `analyze` (because
  // validation failed), but we get zero diagnostics. In this case, we do
  // _not_ issue the convergence warning, since the document did in fact
  // converge.
  let diags = sink.warnings()
  if !diags.is_empty() {
    let summary = SourceDiagnostic::warning(
        @syntax.DiagSpan::detached(),
        "document did not converge within five attempts",
      )
      .with_hint(
        "see \{diags.length()} additional warning\{if diags.length() > 1 { "s" } else { "" }} for more details",
      )
      .with_hint("see https://typst.app/help/convergence for help")
    diags.insert(0, summary)
  }
  diags
}

///|
/// An inquiry for retrieving a piece of information from the document
/// (upstream trait `Introspect`).
///
/// This includes queries, counter retrievals, and various other things that
/// can be observed on a finished document.
///
/// Document iteration N+1 observes the `T` values from the document built by
/// iteration N. If the output values do not stabilize by the iteration limit,
/// a non-convergence warning will be created via `diagnose`.
///
/// Note that how much information you have in the output may affect
/// convergence behavior. For instance, if you reduce down the result of a
/// query introspection to a boolean specifying whether the query yielded at
/// least one element, this may converge one iteration sooner than a raw query
/// would have (even if you always reduce the query to the same bool
/// externally).
pub struct Introspect[T] {
  /// Resolves the output value.
  ///
  /// Will primarily use the introspector, but is passed the full engine in
  /// case user functions need to be called (as is the case for counters).
  introspect : (Engine, Introspector) -> T
  /// Produces a diagnostic for non-convergence given the history of its
  /// output values.
  diagnose : (History[T]) -> SourceDiagnostic
}

///|
/// Create an introspection from its two operations.
pub fn[T] Introspect::new(
  introspect : (Engine, Introspector) -> T,
  diagnose : (History[T]) -> SourceDiagnostic,
) -> Introspect[T] {
  { introspect, diagnose, }
}

///|
/// A type-erased representation of an [introspection](Introspect) that was
/// recorded during compilation.
pub struct Introspection {
  /// Computes the history of the introspection over the given introspectors
  /// and produces a diagnostic if it did not converge.
  priv diagnose : (&World, Array[Introspector]) -> SourceDiagnostic?
}

///|
/// Type erase a strongly-typed introspection.
pub fn[T : Fingerprint] Introspection::new(
  inner : Introspect[T],
) -> Introspection {
  {
    diagnose: (world, introspectors) => {
      let history = History::compute(world, introspectors, inner.introspect)
      if history.converged() {
        None
      } else {
        Some((inner.diagnose)(history))
      }
    },
  }
}

///|
/// A history of values that were observed throughout iterations, alongside
/// the introspectors they were observed for.
pub struct History[T] {
  priv entries : Array[(Introspector, T)]
}

///|
/// Create a history from introspector-value pairs (`max_iters + 1` of them).
pub fn[T] History::from_entries(
  entries : Array[(Introspector, T)],
) -> History[T] {
  { entries, }
}

///|
/// Computes the value for each introspector with an ad-hoc engine.
fn[T] History::compute(
  world : &World,
  introspectors : Array[Introspector],
  f : (Engine, Introspector) -> T,
) -> History[T] {
  {
    entries: introspectors.map(introspector => {
      let engine : Engine = {
        library: world.library(),
        world,
        introspector,
        traced: Traced::new(),
        sink: Sink::new(),
        route: Route::root(),
      }
      (introspector, f(engine, introspector))
    }),
  }
}

///|
/// Whether the values in this history converged, i.e. the final and
/// pre-final values are the same.
pub fn[T : Fingerprint] History::converged(self : History[T]) -> Bool {
  // We compare by hash because the values should be fully the same, i.e.
  // with no observable difference. When a state changes from `0.0` (float)
  // to `0` (int), that could be observed in the next iteration and should
  // not count as converged.
  hash128(self.entries[max_iters - 1].1) == hash128(self.entries[max_iters].1)
}

///|
/// Transforms the contained values with `f`.
pub fn[T, U] History::map(self : History[T], f : (T) -> U) -> History[U] {
  { entries: self.entries.map(pair => (pair.0, f(pair.1))), }
}

///|
/// The observed values.
pub fn[T] History::values(self : History[T]) -> Array[T] {
  self.entries.map(pair => pair.1)
}

///|
/// Accesses the final iteration's introspector.
pub fn[T] History::final_introspector(self : History[T]) -> Introspector {
  self.entries[max_iters].0
}

///|
/// Produces a hint with the observed values for each iteration.
pub fn[T] History::hint(
  self : History[T],
  what : String,
  f : (T) -> String,
) -> String {
  let hint = StringBuilder()
  hint.write_string("the following \{what} were observed:")
  for i, pair in self.entries {
    let attempt = if i < max_iters { "run \{i + 1}" } else { "final" }
    let output = f(pair.1)
    hint.write_string("\n- \{attempt}: \{output}")
  }
  hint.to_string()
}
